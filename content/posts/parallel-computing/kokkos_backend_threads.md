---
title: "kokkos backend threads"
date: 2023-02-22T18:56:41+08:00
topics: "parallel-computing"
draft: true
---

# Kokkos后端-C++线程实现原理分析

使用Kokkos的程序基本结构如下：

```cpp
#include <Kokkos_Core.hpp>
#include <cstdio>
#include <typeinfo>

// A "functor" is just a class or struct with a public operator()
// instance method.
struct hello_world {

  // KOKKOS_INLINE_FUNCTION is a macro for CUDA
  KOKKOS_INLINE_FUNCTION
  void operator()(const int i) const {
    printf("Hello from i = %i\n", i);
  }
};

int main(int argc, char* argv[]) {
  // You must call initialize() before you may call Kokkos.
  Kokkos::initialize(argc, argv);

  Kokkos::parallel_for("HelloWorld", 15, hello_world());

  // You must call finalize() after you are done using Kokkos.
  Kokkos::finalize();
}
```

之后的说明会结合该基本使用框架来阐述Kokkos是如何使用C++线程作为后端来执行并行计算的。

# || 概述

在介绍具体对应某个后端实现之前，先说明Kokkos的总体执行框架。

> 现目前的说明不涉及到内存空间的实现

一些相关的结构和函数：

```cpp
namespace Kokkos{

class Serial {
 public:
  //! \name Type declarations that all Kokkos devices must provide.

  //! Tag this class as an execution space:
  //! detected_t 配合 is_execution_space检测是否存在
  using execution_space = Serial;
  using memory_space = Kokkos::HostSpace;
  using size_type = memory_space::size_type;
  static void impl_initialize(InitializationSettings const&);
  static void impl_finalize();
  ......
};


/** \brief  Execution space for a pool of C++11 threads on a CPU. */
class Threads {
 public:
  //! \name Type declarations that all Kokkos devices must provide.
  //@{
  //! Tag this class as a kokkos execution space
  using execution_space = Threads;
  using memory_space    = Kokkos::HostSpace;
  static int in_parallel();
  /** \brief  Return the maximum amount of concurrency.  */
  static int concurrency();
  static void impl_finalize();
  static void impl_initialize(InitializationSettings const&);
  ......
};

namespace Impl {

struct ExecSpaceBase {
  virtual void initialize(InitializationSettings const&)           = 0;
  virtual void finalize()                                          = 0;
  ......
};

template <class ExecutionSpace>
struct ExecSpaceDerived : ExecSpaceBase {
  static_assert(check_valid_execution_space<ExecutionSpace>(), "");
  void initialize(InitializationSettings const& settings) final {
    // 调用具体Serial或者Threads的初始化
    ExecutionSpace::impl_initialize(settings);
  }
  ......
};

// 通过工厂模式管理所有的执行空间类
class ExecSpaceManager {
  std::map<std::string, std::unique_ptr<ExecSpaceBase>> exec_space_factory_list;
  ExecSpaceManager() = default;

 public:
  void register_space_factory(std::string name,
                              std::unique_ptr<ExecSpaceBase> ptr);
  void initialize_spaces(const Kokkos::InitializationSettings& settings){
    // 遍历map，执行所有已注册执行空间的初始化
    for (auto& to_init : exec_space_factory_list) {
      to_init.second->initialize(settings);
    }
  }
  ......
  // 单例
  static ExecSpaceManager& get_instance();
};

template <class ExecutionSpace>
int initialize_space_factory(std::string name) {
  auto space_ptr = std::make_unique<ExecSpaceDerived<ExecutionSpace>>();
  ExecSpaceManager::get_instance().register_space_factory(name,
                                                          std::move(space_ptr));
  return 1;
}

}  // namespace Impl

void initialize(InitializationSettings const& settings) {
  ......
  Kokkos::Impl::ExecSpaceManager::get_instance().initialize_spaces(settings);
  ......
}

namespace Impl {

// 利用C++在执行main函数之前初始化全局变量的特点
// 向ExecSpaceManager注册执行空间类
int g_serial_space_factory_initialized =
    initialize_space_factory<Serial>("100_Serial");
int g_threads_space_factory_initialized =
    initialize_space_factory<Threads>("050_Threads");
    ......

}  // namespace Impl

} // namespace Kokkos
```

可以看到其实在main函数执行之前，已经完成了所有指定后端的注册。采用工厂模式结合模板，极大的增强了程序的可扩展性，即便于开发各种后端。

之后并进入main函数执行，首先执行的是`Kokkos::initialize()`函数，其主要作用就是调用所有已注册的后端执行空间的`ExecutionSpace::impl_initialize()`。

然后执行`Kokkos::parallel_for("HelloWorld", 15, hello_world());`

```cpp
template <class FunctorType>
inline void parallel_for(const std::string& str, const size_t work_count,
                         const FunctorType& functor) {
  // FunctorPolicyExecutionSpace是一个辅助模板
  // 其利用Detection Idiom技术检测给出的Functor和Policy类型中是否存在execution_space类型
  // 若存在则定义execution_space作为结果。如果均没有，则通过DefaultExecSpace设置execution_space
  // 同时存在则使用Policy中的，当然这里的Policy指定为了void
  using execution_space =
      typename Impl::FunctorPolicyExecutionSpace<FunctorType,
                                                 void>::execution_space;
  // 在这里实例化一个RnagePolicy类型
  // RangePolicy本身表示的时Range的执行策略
  // 其次，其通过模板元编程技术（模板递归、部分特化、继承等）还实现了特性收集功能
  // 对RangePolicy<Properties...>中给出的Properties进行比对和收集
  // 如RangePolicy<Serial, TagA>则对应的RangePolicy::execution_space = Serial RangePolicy::work_tag=TagA
  // 而其他未明确指定的则使用默认值，如RangePolicy::index_type = int等
  // 具体实现参见PolicyTraits的自定义注释
  using policy = RangePolicy<execution_space>;

  policy execution_policy = policy(0, work_count);
  // 调用下面的通用函数
  ::Kokkos::parallel_for(str, execution_policy, functor);
}

template <
    class ExecPolicy, class FunctorType,
    class Enable = std::enable_if_t<is_execution_policy<ExecPolicy>::value>>
inline void parallel_for(const std::string& str, const ExecPolicy& policy,
                         const FunctorType& functor) {
  uint64_t kpID = 0;

  ExecPolicy inner_policy = policy;
  ......
  Impl::ParallelFor<FunctorType, ExecPolicy> closure(functor, inner_policy);
  ......

  closure.execute();
  ......
}
```

可见最终`parallel_for`的执行，转给了`ParallelFor::execute()`函数。

而ParallelFor类型采用特化模板的方式，来确定某个执行空间执行某个策略对应的代码，以这里的ParallelFor为例：

```cpp
template <class FunctorType, class ExecPolicy,
          class ExecutionSpace = typename Impl::FunctorPolicyExecutionSpace<
              FunctorType, ExecPolicy>::execution_space>
class ParallelFor;

template <class FunctorType, class... Traits>
class ParallelFor<FunctorType, Kokkos::RangePolicy<Traits...>, Kokkos::Serial> {
......
};


template <class FunctorType, class... Traits>
class ParallelFor<FunctorType, Kokkos::RangePolicy<Traits...>,
                  Kokkos::Threads> {
......
};
```

根据默认的执行空间参数，由此可见，`ParallelFor<FunctorType, RangePolicy<...>>`,最终匹配的即时`ParallelFor<Functor,RangePolicy<...>, DefaultExecSpace>`，其中`DefaultExecSpace`根据指定的后端不同而不同，这由CMake变量决定。

其中关于的`Serial`即串行执行空间的`ParallelFor`实现较为简单，可自行参见源代码。


# || Threads作为后端执行

同样还是以`ParallelFor`来进行说明。其实由上所述，可以知道在具体执行`ParallelFor`之前作了两部分初始化工作：

1. 利用全局变量初始化，对执行空间类进行注册
2. 用户调用`Kokkos::initialize()`执行具体的后端初始化

完了以后，执行`parallel_for`。

对于C++线程作为后端来说，Kokkos在`initialize()`函数执行时，大概进行了如下工作：

1. 使用hwloc检测当前设备拓扑结构以确定最佳线程数量
>主要检测NUMA数量、每个NUMA的Core数量、每个Core支持的线程数量

2. 建立线程池

> 还有一部分关于锁和共享内存的部分还未分析

一些相关的数据结构：

```cpp
namespace Kokkos {
namespace Impl {
class ThreadsExec {
 public:
  // Fan array has log_2(NT) reduction threads plus 2 scan threads
  // Currently limited to 16k threads.
  enum { MAX_FAN_COUNT = 16 };
  enum { MAX_THREAD_COUNT = 1 << (MAX_FAN_COUNT - 2) };
  enum { VECTOR_LENGTH = 8 };

  /** \brief States of a worker thread */
  enum {
    Terminating  ///<  Termination in progress
    ,
    Inactive  ///<  Exists, waiting for work
    ,
    Active  ///<  Exists, performing work
    ,
    Rendezvous  ///<  Exists, waiting in a barrier or reduce

    ,
    ScanCompleted,
    ScanAvailable,
    ReductionAvailable
  };

  int m_numa_rank;
  int m_numa_core_rank;
  int m_pool_rank;
  int m_pool_size;

  static bool is_process();

  static void verify_is_process(const std::string &, const bool initialized);

  static void initialize(int thread_count);

  static void wait_yield(volatile int &, const int);

  ......
  // 这里仅仅列出了和ParallelFor以及RangePolicy相关的一小部分内容
};

// 其代表主线程
ThreadsExec s_threads_process;
// 生成的子线程拥有的ThreadsExec结构的指针数组
ThreadsExec *s_threads_exec[ThreadsExec::MAX_THREAD_COUNT] = {nullptr};
// 同上，只不过是每个线程的id
std::thread::id s_threads_pid[ThreadsExec::MAX_THREAD_COUNT];
// 记录每个线程在CPU拓扑结构中的坐标
std::pair<unsigned, unsigned> s_threads_coord[ThreadsExec::MAX_THREAD_COUNT];

// 0: total_threads count
// 1: threads count per numa
// 2: threads count per core
int s_thread_pool_size[3] = {0, 0, 0};

// 每个线程实际要执行的函数，在该函数中执行用户定义的Functor()
void (*volatile s_current_function)(ThreadsExec &, const void *);
const void *volatile s_current_function_arg = nullptr;
}// Impl namespce
}// Kokkos
```
`ThreadExec`是每个线程都会首先构造的一个数据结构。Kokkos在其中存放每个线程的状态，和当前线程的rank以及在机器的处理器拓扑结构中的位置`（numa_coord, core_coord)`

而定义的全局变量含义见注释。

如前所述， `Kokkos::initialize()`在执行初始化C++线程后端时，会调用`static ThreadsExec::initialize()`,这是在`Threads::impl_initialize()`函数中调用的。

在`Threads::initialize()`中执行了上述的两个具体任务：

1. 要么使用用户指定的`thread_count`设置线程池的大小，要么在hwloc可用时，将线程池大小设置为物理线程的数量。
2. 创建线程池 
> 设计到hwloc的具体用法，这部分源码只能先大致分析一下原理

代码如下：
```cpp

void ThreadsExec::initialize(int thread_count){
  ......
  if (!is_initialized) {
    const bool hwloc_avail = Kokkos::hwloc::available();
    const bool hwloc_can_bind =
        hwloc_avail && Kokkos::hwloc::can_bind_threads();

    // 用户未指定线程数量，则使用hwloc设置为机器的物理线程数量
    if (thread_count == 0) {
      thread_count = hwloc_avail
                         ? Kokkos::hwloc::get_available_numa_count() *
                               Kokkos::hwloc::get_available_cores_per_numa() *
                               Kokkos::hwloc::get_available_threads_per_core()
                         : 1;
    }

    // 该mapping，为每个线程分配CPU拓扑结构坐标
    // 即每个线程应该运行那个numa上，有该运行在该numa上的core上
    // 如此，可以将线程利用hwloc绑定在具体的core上执行
    const unsigned thread_spawn_begin = hwloc::thread_mapping(
        "Kokkos::Threads::initialize", allow_asynchronous_threadpool,
        thread_count, use_numa_count, use_cores_per_numa, s_threads_coord);

    const std::pair<unsigned, unsigned> proc_coord = s_threads_coord[0];

    if (thread_spawn_begin) {
      // Synchronous with s_threads_coord[0] as the process core
      // Claim entry #0 for binding the process core.
      s_threads_coord[0] = std::pair<unsigned, unsigned>(~0u, ~0u);
    }

    // 设置线程池的大小
    s_thread_pool_size[0] = thread_count;
    s_thread_pool_size[1] = s_thread_pool_size[0] / use_numa_count;
    s_thread_pool_size[2] = s_thread_pool_size[1] / use_cores_per_numa;
    // 先设置所有的线程执行体为一个空函数
    s_current_function =
        &execute_function_noop;  // Initialization work function

    for (unsigned ith = thread_spawn_begin; ith < thread_count; ++ith) {
      s_threads_process.m_pool_state = ThreadsExec::Inactive;

      // If hwloc available then spawned thread will
      // choose its own entry in 's_threads_coord'
      // otherwise specify the entry.
      s_current_function_arg =
          reinterpret_cast<void *>(hwloc_can_bind ? ~0u : ith);

      // Make sure all outstanding memory writes are complete before spawning the new thread.
      memory_fence();

      // Spawn thread executing the 'driver()' function.
      // Wait until spawned thread has attempted to initialize.
      // If spawning and initialization is successful then
      // an entry in 's_threads_exec' will be assigned.
      // 在此处生成新线程
      // 这里直接展开了spawn函数
      ThreadsExec::spawn();{
          std::thread t(internal_cppthread_driver);
          t.detach();
      }
      wait_yield(s_threads_process.m_pool_state, ThreadsExec::Inactive);
      if (s_threads_process.m_pool_state == ThreadsExec::Terminating) break;
    }

    ......

    s_current_function             = nullptr;
    s_current_function_arg         = nullptr;
    s_threads_process.m_pool_state = ThreadsExec::Inactive;

    // desul实现的内存屏障
    memory_fence();

    ......
  }

void ThreadsExec::internal_cppthread_driver() {
    ......
    ThreadsExec::driver();
    ......
}

void ThreadsExec::driver() {
  SharedAllocationRecord<void, void>::tracking_enable();

  ThreadsExec this_thread;

  while (ThreadsExec::Active == this_thread.m_pool_state) {
    (*s_current_function)(this_thread, s_current_function_arg);

    // Deactivate thread and wait for reactivation
    this_thread.m_pool_state = ThreadsExec::Inactive;

    wait_yield(this_thread.m_pool_state, ThreadsExec::Inactive);
  }
}

void ThreadsExec::wait_yield(volatile int &flag, const int value) {
  while (value == flag) {
    std::this_thread::yield();
  }
}
```
注意到在`ThreadsExec::inititalize()`中执行了`ThreadsExec::spawn()`函数，该函数产生了一个新的线程，该线程实际运行`ThreadsExec::driver()`函数。

而在`driver()`函数中，首先定义了一个局部变量`ThreadsExec this_thread`,便进入了一个`while`循环中。

这里的重点时`ThreadsExec`的默认构造函数，其区分了主线程如何构造，和子线程如何构造：

```cpp
ThreadsExec::ThreadsExec()
    : m_pool_base(nullptr),
      m_scratch(nullptr),
      m_scratch_reduce_end(0),
      m_scratch_thread_end(0),
      m_numa_rank(0),
      m_numa_core_rank(0),
      m_pool_rank(0),
      m_pool_size(0),
      m_pool_fan_size(0),
      m_pool_state(ThreadsExec::Terminating) {
  // 通过全局变量来区分是否是子线程构造的
  if (&s_threads_process != this) {
    // A spawned thread

    ThreadsExec *const nil = nullptr;

    // Which entry in 's_threads_exec', possibly determined from hwloc binding
    const int entry = reinterpret_cast<size_t>(s_current_function_arg) <
                              size_t(s_thread_pool_size[0])
                          ? reinterpret_cast<size_t>(s_current_function_arg)
                          : size_t(Kokkos::hwloc::bind_this_thread(
                                s_thread_pool_size[0], s_threads_coord));

    // Given a good entry set this thread in the 's_threads_exec' array
    if (entry < s_thread_pool_size[0] &&
        nil == atomic_compare_exchange(s_threads_exec + entry, nil, this)) {
      const std::pair<unsigned, unsigned> coord =
          Kokkos::hwloc::get_this_thread_coordinate();

      // 设置各种rank和状态
      m_numa_rank      = coord.first;
      m_numa_core_rank = coord.second;
      m_pool_base      = s_threads_exec;
      m_pool_rank      = s_thread_pool_size[0] - (entry + 1);
      m_pool_rank_rev  = s_thread_pool_size[0] - (pool_rank() + 1);
      m_pool_size      = s_thread_pool_size[0];
      m_pool_fan_size  = fan_size(m_pool_rank, m_pool_size);
      // 注意构造成功后其状态被设置为了Active，即运行态
      m_pool_state     = ThreadsExec::Active;

      s_threads_pid[m_pool_rank] = std::this_thread::get_id();

      // Inform spawning process that the threads_exec entry has been set.
      // 而将主线程的状态也设置为了运行态
      s_threads_process.m_pool_state = ThreadsExec::Active;
    } else {
      // Inform spawning process that the threads_exec entry could not be set.
      s_threads_process.m_pool_state = ThreadsExec::Terminating;
    }
  } else {
    // Enables 'parallel_for' to execute on unitialized Threads device
    m_pool_rank  = 0;
    m_pool_size  = 1;
    m_pool_state = ThreadsExec::Inactive;

    s_threads_pid[m_pool_rank] = std::this_thread::get_id();
  }
}
```

再看`driver()`函数：
```cpp
void ThreadsExec::driver() {
  SharedAllocationRecord<void, void>::tracking_enable();

  ThreadsExec this_thread;

  // 若处于Active状态则执行一次s_current_function函数
  // 若是其他状态则直接退出线程结束
  while (ThreadsExec::Active == this_thread.m_pool_state) {
    (*s_current_function)(this_thread, s_current_function_arg);

    // Deactivate thread and wait for reactivation
    this_thread.m_pool_state = ThreadsExec::Inactive;

    // 若m_pool_state一直处于Inactive，则该线程会一直yield让出执行权,让其他线程运行
    wait_yield(this_thread.m_pool_state, ThreadsExec::Inactive);
  }
}
```

由于在`ThreadsExec::initialize()`中执行`spawn()`函数之前将`s_current_func`设置为了一个空函数，故`driver()`函数会一直在`wait_yield`中循环，直到`ThreadExec::m_pool_state`变化。

好了，现在继续回到`ThreadExec::initialize()`中继续执行：
```cpp
void ThreadsExec::initialize(int thread_count){
  ......
  if (!is_initialized) {
    ......
    for (unsigned ith = thread_spawn_begin; ith < thread_count; ++ith) {
      s_threads_process.m_pool_state = ThreadsExec::Inactive;

      // If hwloc available then spawned thread will
      // choose its own entry in 's_threads_coord'
      // otherwise specify the entry.
      s_current_function_arg =
          reinterpret_cast<void *>(hwloc_can_bind ? ~0u : ith);

      // Make sure all outstanding memory writes are complete before spawning the new thread.
      memory_fence();

      // Spawn thread executing the 'driver()' function.
      // Wait until spawned thread has attempted to initialize.
      // If spawning and initialization is successful then
      // an entry in 's_threads_exec' will be assigned.
      // 在此处生成新线程
      // 这里直接展开了spawn函数
      ThreadsExec::spawn();{
          std::thread t(internal_cppthread_driver);
          t.detach();
      }
      // 在spawn线程后，主线程陷入yield循环中
      // 直到刚才spawn的子线程，设置主线程为`Activate`状态，则返回
      // 继续生成下一个循环
      wait_yield(s_threads_process.m_pool_state, ThreadsExec::Inactive);
      // spawn的线程如果出错，则终止分配
      if (s_threads_process.m_pool_state == ThreadsExec::Terminating) break;
    }

    ......

    // 此时所有的子线程应该都处于wait_yield(m_pool_state, Inactive)循环中
    // 此时设置s_current_func是安全的
    s_current_function             = nullptr;
    s_current_function_arg         = nullptr;
    s_threads_process.m_pool_state = ThreadsExec::Inactive;

    // 当然或许由于地层的乱序执行(或许编译器也会交换内存访问顺序)，Kokkos使用了大量的内存屏障
    // desul实现的内存屏障
    memory_fence();

    ......
  }
```

在`Kokkos::initialize()`完成执行后，已经生成了一个线程池。之后的`ParallelFor`只需要指定需要并行执行的函数，即设置`s_current_function`和`s_current_args`，然后在把所有的线程状态设置为`Active`，则每个线程都会使用自己定义的`ThreadExec this_thread`调用`s_cuurent_function`函数。
```cpp
driver(){
    ......
    while(...){
        ......
        (*s_current_function)(this_thread, s_current_function_arg);
        .....
    }
    ......
}
```

终于初始化完成了，现在可以来看`HelloWorld`代码中的`parallel_for`函数了，上面已经分析过了，该函数实际生成了一个对应到`RangePolicy`和`Threads`的`ParallelFor`对象，并执行了其`execute()`函数。

```cpp
inline void ParallelFor::execute() const {
    ThreadsExec::start(&ParallelFor::exec, this);
    ThreadsExec::fence();
}
```

可以看到其执行了`ThreadsExec`的两个静态函数，在执行`start`时将`exec`函数和当前`ParallelFor`对象传递了进去。

应该可以猜到了，该`Threads::start`函数就是负责将`exec`函数设置为`s_current_function`，将`this`设置为`s_current_args`，并设置所有线程状态为`Active`开始并行执行:

```cpp
/** \brief  Begin execution of the asynchronous functor */
void ThreadsExec::start(void (*func)(ThreadsExec &, const void *),
                        const void *arg) {
  // 验证当前是否为主线程，true表示还需要验证是否执行了初始化，Kokkos::initialize间接初始化了ThreadsExec相关的变量
  verify_is_process("ThreadsExec::start", true);

  if (s_current_function || s_current_function_arg) {
    Kokkos::Impl::throw_runtime_exception(
        std::string("ThreadsExec::start() FAILED : already executing"));
  }

  s_current_function     = func;
  s_current_function_arg = arg;

  // Make sure function and arguments are written before activating threads.
  memory_fence();

  // Activate threads:
  for (int i = s_thread_pool_size[0]; 0 < i--;) {
    s_threads_exec[i]->m_pool_state = ThreadsExec::Active;
  }

  if (s_threads_process.m_pool_size) {
    // Master process is the root thread, run it:
    (*func)(s_threads_process, arg);
    s_threads_process.m_pool_state = ThreadsExec::Inactive;
  }
}
```

就实际的`RangePolicy`并行执行，现在就只剩最后一个问题了，`ParallelFor<Functor, RangePolicy, Threads>::exec`，该函数是怎样的，为何所有的线程都执行他就能实现对一个一维空间的并行执行。

```cpp
  // 经列出了带Tag的特化模板
  template <class TagType>
  inline static std::enable_if_t<!std::is_void<TagType>::value> exec_range(
      const FunctorType &functor, const Member ibeg, const Member iend) {
    const TagType t{};
    for (Member i = ibeg; i < iend; ++i) {
      functor(t, i);
    }
  }

  static void exec(ThreadsExec &exec, const void *arg) {
    // 实际执行exec_schedule
    exec_schedule<typename Policy::schedule_type::type>(exec, arg);
  }

  // 仅列出了一个特化模板
  template <class Schedule>
  static std::enable_if_t<std::is_same<Schedule, Kokkos::Static>::value>
  exec_schedule(ThreadsExec &exec, const void *arg) {
    const ParallelFor &self = *((const ParallelFor *)arg);

    // WorkRange是RangePolicy的一个内部类
    WorkRange range(self.m_policy, exec.pool_rank(), exec.pool_size());

    ParallelFor::template exec_range<WorkTag>(self.m_functor, range.begin(),
                                              range.end());

    exec.fan_in();
  }
```

经过分析可以知道，`exec`内部使用使用了`WorkRange`来分别执行不同部分。最初我们给`RangePolicy`指定一个范围如`[100, 10000]`，而`WorkRange`对象利用当前线程的`pool_rank`和`pool_size`,来计算每个线程负责`[100, 100000]`中的哪个范围。最后在通过`for`循环来执行该子范围，从里实现了每个线程并行执行一部分范围。


> 注意`ParallelFor::execute()`中在执行完`start`函数后，还执行了一个`ThreadsExec::fence`来等待所有的线程执行完成。所以，即使一个`parallefor()`后再跟一个`parallelfor`，并不会并行，而是一个一个执行。
