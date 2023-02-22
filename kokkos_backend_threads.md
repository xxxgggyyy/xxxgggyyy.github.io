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

1. 概要说明大致原理
2. 相关数据结构说明
3. 线程的生成与执行
4. 线程同步

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

1. 使用hwloc检测当前设备的执行能力
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

}// Impl namespce
}// Kokkos

```

```cpp

void ThreadsExec::initialize(int thread_count){
  // legacy arguments
  unsigned thread_count       = thread_count_arg == -1 ? 0 : thread_count_arg;
  unsigned use_numa_count     = 0;
  unsigned use_cores_per_numa = 0;
  bool allow_asynchronous_threadpool = false;
  // need to provide an initializer for Intel compilers
  static const Sentinel sentinel = {};

  const bool is_initialized = 0 != s_thread_pool_size[0];

  unsigned thread_spawn_failed = 0;

  for (int i = 0; i < ThreadsExec::MAX_THREAD_COUNT; i++)
    s_threads_exec[i] = nullptr;

  if (!is_initialized) {
    // If thread_count, use_numa_count, or use_cores_per_numa are zero
    // then they will be given default values based upon hwloc detection
    // and allowed asynchronous execution.

    const bool hwloc_avail = Kokkos::hwloc::available();
    const bool hwloc_can_bind =
        hwloc_avail && Kokkos::hwloc::can_bind_threads();

    if (thread_count == 0) {
      thread_count = hwloc_avail
                         ? Kokkos::hwloc::get_available_numa_count() *
                               Kokkos::hwloc::get_available_cores_per_numa() *
                               Kokkos::hwloc::get_available_threads_per_core()
                         : 1;
    }

    const unsigned thread_spawn_begin = hwloc::thread_mapping(
        "Kokkos::Threads::initialize", allow_asynchronous_threadpool,
        thread_count, use_numa_count, use_cores_per_numa, s_threads_coord);

    const std::pair<unsigned, unsigned> proc_coord = s_threads_coord[0];

    if (thread_spawn_begin) {
      // Synchronous with s_threads_coord[0] as the process core
      // Claim entry #0 for binding the process core.
      s_threads_coord[0] = std::pair<unsigned, unsigned>(~0u, ~0u);
    }

    s_thread_pool_size[0] = thread_count;
    s_thread_pool_size[1] = s_thread_pool_size[0] / use_numa_count;
    s_thread_pool_size[2] = s_thread_pool_size[1] / use_cores_per_numa;
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
      ThreadsExec::spawn();
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
```
