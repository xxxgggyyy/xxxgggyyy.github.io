---
title: "kokkos core源码结构注释对照"
date: 2023-05-16T15:41:18+08:00
topics: "parallel-computing"
draft: true
---

# Kokkos core 源码结构分析

本文档主要梳理Kokkos-core的源码结构。包括源码之间之间的关系，大致内容等

> 具体含义需要自行查阅源码

## || 入口

file|desc
---|---
Kokkos_Core_fwd.hpp|执行空间、内存空间、View、ParallelFor等等，基本上包含了kokkos中所有重要类型前向声明 
Kokkos_Core.hpp|该文件中引用了Kokkos_Core_fwd.hpp，或者说该文件拆分出的上一个fwd.hpp，还有一些全局函数的声明
${binary_dir}/KokkosCore_config.h|包含用户指定的开启相关后端的宏等，在Kokkos_Macros.hpp中引入该文件
${binary_dir}/KokkosCore_Config_FwdBackend.hpp|包含用户指定的后端执行空间和内存空间声明，在Kokkos_Core_fwd.hpp中被引入
${binary_dir}/Kokkos_Config_DeclareBackend.hpp|在该文件中引入指定后端需要的其他头文件

> ${binary_dir}指CMake的构建目录，里面的文件是根据用户指定的后端生成的。整个kokkos-core的声明应该都在这里了

### kokkos_Core.hpp

![kokkos_core](/images/kokkos_imgs/kokkos-core/kokkos_core_hpp_overview.png)

`${Kokkos_Path}/core/src/Kokkos_Core.hpp`主要负责对Kokkos-core涉及到的所有Class和全局函数进行前向声明。

> 前向声明就是简单的C++类或者函数声明，只不过全部放到一块了，避免一些类型和函数之间的一些互相依赖关系编译器无法处理

整体可以分为以下几个部分：

1. 涉及用户指定后端的相关前向声明
2. 涉及的一些全局函数声明，如`Kokkos::initialize()` `Kokkos::finalize()`
3. ScopeGuard类型声明
4. 一些实验性的类型声明

**具体后端声明**

涉及具体后端的声明内容比较多，并且需要和CMake生成的文件交互（由用户指定特定后端后CMake生成具有指定后端类型声明的C++头文件）,这部分单独由引入的两个头文件处理：

1. `Kokkos_Core_fwd.hpp`
2. `Kokkos_Config_DeclareBackend.hpp`

首先看`Kokkos_Core_fwd.hpp`，其包括的主要内容如下：

0. 定义后端相关宏，通过头文`Kokkos_Macros.hpp`间接引入`KokkosCore_config.h`后者由CMAKE生成开启某些后端的宏
1. 主机内存空间类型声明、设备类型声明等
2. 后端执行空间声明、某个后端对应的内存空间声明
3. 根据用户配置的可用执行空间，根据优先级设定`DefaultHostExecuionSpace`和`DefaultExecutionSpace`的类型
4. 声明一些内存空间访问辅助类型（模板元编程），比如检查某个用户指定的并行函数，所在的执行空间是否能访问对应的内存空间。
5. fence()操作声明
6. `View`相关类型声明
7. 并行执行类模板声明，如`ParallelFor`、`ParallelReduce`、`ParallelScan`等，实际的`parallel_for()`函数最终会映射到这些类型上。
8. 一些常用的基础的并行算子定义，如`Sum`、`Max`等

其中除了主机内存空间直接在头文件中声明，其他后端执行空间和其对应的内存空间，被其引入的头文件`KokkosCore_Config_FwdBackend.hpp`声明。该头文件由CMake根据用户配置生成。(内容比较简单就是对应执行空间类和内存空间类的简单声明)

其次剩下的`Kokkos_Config_DeclareBackend.hpp`负责把除执行空间和内存空间类型声明外，还需要的其他对应后端头文件引入。该文件也是CMake生成，也比较简单，就是引入对应后端需要的其他头文件


## || Cuda后端

> 参见kokkos-core-cuda-backend.md里面有详细介绍

> pwd: ${kokkos_src}/core/src

file|desc
---|---
Kokkos_Cuda.hpp|主要是`Cuda`执行空间声明
Kokkos_CudaSpace.hpp|主要是cuda对应的内存空间声明
Cuda/Kokkos_Cuda_Instance.hpp|主要是`CudaInternal`类型的声明，`Cuda`执行空间更多的像是`CudaInternal`实例的一个代理，或者说`Cuda`的内部实现是通过`CudaInternal`

### Kokkos_Cuda.hpp

该头文件主要包括对执行空间的`Cuda`的声明

> 一个Class是否为执行空间，通过detection idiom判断其是否具有成员类型`execution_space`决定
> 除此之外还需要声明每个执行空间类型必须实现的接口


另外还有一些辅助类：

* MemorySpaceAccess
* ZeroMemset
* CudaLaunchMechanism

> 这些结构仅在内部定义了一些枚举类型。具体用法暂不明

### Kokkos_CudaSpace.hpp

该文件中主要包括`Cuda`执行空间对应的几种内存空间。

* `CudaSpace`
* `CudaUVMSpace`
* `CudaHostPinnedSpace`

这些内存空间的名字是非常直观的，对应与Cuda编程模型中的几种内存。

> 具体成员含义暂不明

除此之外，还定义了三类模板结构：

1. `MemorySpaceAcess`

```cpp
template <>
struct MemorySpaceAccess<Kokkos::HostSpace, Kokkos::CudaSpace> {
  enum : bool { assignable = false };
  enum : bool { accessible = false };
  enum : bool { deepcopy = true };
};
```

从这里看`MemorySpaceAccess`是用于定义不同内存空间之间的某些访问权限

> 同`Kokkos_Cuda.hpp`中一样，不同的模板特化参数

2. `DeepCopy`

个人感觉应该是类似于`cudaMemcpy()`的，但由于该函数本身的参数是`void*`，所以这里定义一些模板用来限制可以copy的内存空间。

```cpp

template <class MemSpace>
struct DeepCopy<MemSpace, HostSpace, Cuda,
                std::enable_if_t<is_cuda_type_space<MemSpace>::value>> {
  DeepCopy(void* dst, const void* src, size_t n) { DeepCopyCuda(dst, src, n); }
  DeepCopy(const Cuda& instance, void* dst, const void* src, size_t n) {
    DeepCopyAsyncCuda(instance, dst, src, n);
  }
};

// 就是cudaMemcpy
void DeepCopyCuda(void *dst, const void *src, size_t n) {
  KOKKOS_IMPL_CUDA_SAFE_CALL(cudaMemcpy(dst, src, n, cudaMemcpyDefault));
}

void DeepCopyAsyncCuda(const Cuda &instance, void *dst, const void *src,
                       size_t n) {
  KOKKOS_IMPL_CUDA_SAFE_CALL(
      cudaMemcpyAsync(dst, src, n, cudaMemcpyDefault, instance.cuda_stream()));
}

void DeepCopyAsyncCuda(void *dst, const void *src, size_t n) {
  cudaStream_t s = cuda_get_deep_copy_stream();
  KOKKOS_IMPL_CUDA_SAFE_CALL(
      cudaMemcpyAsync(dst, src, n, cudaMemcpyDefault, s));
  Impl::cuda_stream_synchronize(
      s,
      Kokkos::Tools::Experimental::SpecialSynchronizationCases::
          DeepCopyResourceSynchronization,
      "Kokkos::Impl::DeepCopyAsyncCuda: Deep Copy Stream Sync");
}
```

3. `SharedAllocationRecord`

暂不明

### Cuda/Kokkos_Cuda_Instance.hpp

主要是`CudaInteral`和`CudaTraits`类型的声明。

`CudaInternal`是`Cuda`执行空间实现的一个核心数据结构，`Cuda`只有一个属性(成员字段)即`CudaInternal`类型的一个智能指针。

`CudaInternal`主要定义了一些gpu属性，和一些用于reduction的ScratchSpace相关的字段和属性。

`CudaTraits`定义了cuda中的一些常量，比如warpsize、常量内存的使用量等

### Cuda/Kokkos_Cuda_Instance.cpp

`CudaInternal`和`Cuda`的具体定义。

> 这一部分需要先看`CudaSpace`，明白如何管理内存后再看


