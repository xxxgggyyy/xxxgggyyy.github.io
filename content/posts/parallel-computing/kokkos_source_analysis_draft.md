---
title: "kokkos source analysis draft"
date: 2023-02-19T21:10:58+08:00
topics: "parallel-computing"
draft: true
---

## 连接CMake配置

### core/src/Kokkos_Core.hpp

其中 `#include <Kokkos_Core_fwd.hpp>`, 包含`#include <KokkosCore_Config_FwdBackend.hpp>`,该头文件由CMake根据其配置的变量选择包含的具体的后端类比如`Serial`.

随后在`Kokkos_Core_fwd.hpp`中，根据CMake生成的宏，按照优先级分别指定默认执行空间别名和默认主机执行空间的类别名。

`Kokkos_Core_fwd.hpp`是比较关键的桥梁文件。

另`View` `ParallelFor`等的原始定义也在此处.

### `ParallelFor` `ParallelReduce` `ParallelScan`

通过模板特列来是实现对应的某个执行空间-执行策略的具体并行执行代码：

比如`Serial-RangePolicy-ParalleFor`，由下列模板特例实现：
#### `Serial/Kokkos_Serial_Parallel_Range.hpp`
```cpp
template <class FunctorType, class... Traits>
class ParallelFor<FunctorType, Kokkos::RangePolicy<Traits...>, Kokkos::Serial> {
 private:
  using Policy = Kokkos::RangePolicy<Traits...>;

  const FunctorType m_functor;
  const Policy m_policy;

  template <class TagType>
  std::enable_if_t<std::is_void<TagType>::value> exec() const {
    const typename Policy::member_type e = m_policy.end();
    for (typename Policy::member_type i = m_policy.begin(); i < e; ++i) {
      m_functor(i);
    }
  }

  // 对于Serial类型的执行空间，只需要简单的串行执行即可
  template <class TagType>
  std::enable_if_t<!std::is_void<TagType>::value> exec() const {
    const TagType t{};
    const typename Policy::member_type e = m_policy.end();
    for (typename Policy::member_type i = m_policy.begin(); i < e; ++i) {
      m_functor(t, i);
    }
  }

 public:
  inline void execute() const {
    this->template exec<typename Policy::work_tag>();
  }

  inline ParallelFor(const FunctorType& arg_functor, const Policy& arg_policy)
      : m_functor(arg_functor), m_policy(arg_policy) {}
};

```

而对于原始定义中`class ExecutionSpace = typename Impl::FunctorPolicyExecutionSpace<FunctorType, ExecPolicy>::execution_space>`

关键在于`Impl::FunctorPolicyExecutionSpace`该模板接受两个类别分别是Policy和Functor，其根据CXX的Detetion Idiom来判断这两个类中是否含有成员类型`execution_space`和`device_type`等，来推测具体执行空间类型。

首先查看Policy对象中是否含有成员类型，有则使用，无则在FunctorType中找是否存在`execution_space`，由于device_type也可以推测出执行空间，所以还要赵`device_tpye`是否存在然后检查其中是否具有`execution_space`,如果都没有指定，则直接使用`DefaultExecutionSpace`

实际使用Kokkos时，程序具体的ExecutionSpace均通过该类模板推倒。

## core/src/impl/Kokkos_ExecSpaceManager.hpp   

```cpp
namespace Kokkos {
namespace Impl {

struct ExecSpaceBase {
  virtual void initialize(InitializationSettings const&)           = 0;
  virtual void finalize()                                          = 0;
  virtual void static_fence(std::string const&)                    = 0;
  virtual void print_configuration(std::ostream& os, bool verbose) = 0;
  virtual ~ExecSpaceBase()                                         = default;
};

// 通过模板实例化来实现继承
template <class ExecutionSpace>
struct ExecSpaceDerived : ExecSpaceBase {
  static_assert(check_valid_execution_space<ExecutionSpace>(), "");
  void initialize(InitializationSettings const& settings) final {
    ExecutionSpace::impl_initialize(settings);
  }
  void finalize() final { ExecutionSpace::impl_finalize(); }
  void static_fence(std::string const& label) final {
    ExecutionSpace::impl_static_fence(label);
  }
  void print_configuration(std::ostream& os, bool verbose) final {
    ExecutionSpace().print_configuration(os, verbose);
  }
};

/* ExecSpaceManager - Responsible for initializing all the registered
 * backends. Backends are registered using the register_space_initializer()
 * function which should be called from a global context so that it is called
 * prior to initialize_spaces() which is called from Kokkos::initialize()
 */
class ExecSpaceManager {
  std::map<std::string, std::unique_ptr<ExecSpaceBase>> exec_space_factory_list;
  ExecSpaceManager() = default;

 public:
  void register_space_factory(std::string name,
                              std::unique_ptr<ExecSpaceBase> ptr);
  void initialize_spaces(const Kokkos::InitializationSettings& settings);
  void finalize_spaces();
  void static_fence(const std::string&);
  void print_configuration(std::ostream& os, bool verbose);
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
}  // namespace Kokkos
```


