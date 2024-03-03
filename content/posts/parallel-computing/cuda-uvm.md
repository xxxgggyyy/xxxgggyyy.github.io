---
title: "cuda uvm"
date: 2023-03-18T12:34:56+08:00
topics: "parallel-computing"
draft: true
---

# UVM功能与基本原理

## UVA&UVM

统一虚拟地址（UVA）在CUDA4.0引入，这使得主机内存和所有设备内存被映射到同样的虚拟地址空间中.

![uva](/images/cuda/uva.png)

> CUDA4.0以前，需要程序员管理指向不同内存空间的地址

> 之后发布的Kepler和Fermi架构将虚拟地址空间扩展到了48bit

而统一虚拟内存(UVM)在CUDA6.0引入。UVM尽管基于UVA，但一个显著的不同在于UVM引入了自动内存迁移。

而UVA的关注点更多在统一不同的设备内存（多GPU）、片上共享内存和主机内存.
> `GPUDirect RDMA`相关文章中提到，尽管此时CPU和GPU内存被映射到了同一个地址空间，但GPU管理的虚拟空间（VA）始终只使用地址的前40bit，而该GPU管理的VA中，子空间还可以以页面为粒度划分类型：CPU、GPU、Free，CPU类型的页面可以由CPU和GPU同时访问，GPU类型页面只能由GPU访问，CPU访问该地址会出现段错误。

> 在UVA出现之后才有的上面提到的GPU虚拟空间地址只使用前40bit，并且还可划分页面类型。同时UVA出现后`cudaMemcpy()`出现了一个默认数据拷贝方向`cudaMemcpyDefault`自动根据给出的数据地址推测出传输方向。


在UVA出现之前，在CPU+GPU的异构环境的典型编程模型如下：

```cpp
void *data, *d_data;
// 在主机内存中分配内存
data = malloc(N);
// cuda运行时API，通知GPU分配内存
cudaMalloc(&d_data, N);

// 在主机内存中进行初始化
cpu_func1(data, N);

// 将主机内存拷贝到设备内存
cudaMemcpy(d_data, data, N, ...)
gpu_func2<<<...>>>(d_data, N);

// 计算完成后将结果拷贝到主机内存
cudaMemcpy(data, d_data, N, ...)
cudaFree(d_data);
cpu_func3(data, N);
free(data);
```

> CUDA C源码在编译时，由cuda的提供的编译工具从中抽离出设备代码，用nvcc编译，主机代码使用标准的C编译器编译。最后链接器在加入cuda运行时后，生成设备代码和主机代码混合的可执行文件

> 在引入UVA后，主机进程在执行时，除了需要向GPU传送设备代码还需传送页表信息


UVM简化的编程模型：
```cpp
void *data;
data = malloc(N);
cpu_func1(data, N);
// 不在需要显式的在CPU和GPU之间拷贝内存
cudaMemPrefetchAsync(data, N, GPU)
gpu_func2<<<...>>>(data, N);
cudaMemPrefetchAsync(data, N, CPU)
cudaDeviceSynchronize();
cpu_func3(data, N);
free(data);
```

使用UVM后不在需要显式的使用主机代码移动内存，而是由CUDA自动迁移内存。
> `cudaMemPrefetchAsync()`要求GPU提前预取内存数据，而不是等到发生Page Fault

## UVM机制基本原理

下图为按需页面迁移：
![uvm-basis](/images/cuda/uvm-basis.png)

> 由于Pascal架构之前的设备并不支持`GPU page fault`，所以尽管引入了UVM，但GPU需要访问内存数据时需要将所有的页面一次性全部迁移到GPU

#### 主机页面 --> GPU全局内存页面

    1. 在GPU中分配新页面
    2. Unmap在CPU对应的久页面
    3. 拷贝数据
    4. map GPU上的新页面
    5. 释放CPU上的久页面

> 这里假设未使用`cudaMemAdvise()`向GPU发送任何提示

首先由GPU产生一个Page Fault中断CPU进入内核，由内核调用cuda驱动程序实现上述过程。

GPU在生成Page Fault后会锁住GPU上对应SM的TLB，阻止该SM其他线程束进行地址转换，因为在此时GPU页表将可能会发生改变。

GPU是有可能同时产生对一个页面的多次页面故障的，cuda驱动负责移除重复的页面故障。
> 这是由GPU低层的执行模型导致，即所谓的`SIMT`(单指令多线程)

#### GPU页面 --> 主机页面
    1. 在CPU中分配新页面
    2. ......

和上面应该是一个大致相反的过程，只不过此时由CPU的缺页故障触发。

另一个不同在于CUDA驱动程序可能会介入到OS内核的缺页中断处理程序。

> 关于这个还没有找到具体的文档介绍，但在官方的开发者博客中，有提到要实现UVM的自动迁移功能，需要cuda运行时、cuda驱动甚至是OS内核的支持。
> 另外直到2017年windows上都不支持GPU的Page fault

## UVM提供的其他特性

除了上面提到的UVA和UVM这个相对基础的功能，还有一些其他特性:

* 按需页面迁移/页面预取
* 超额使用内存
* 并发访问

> 某些特性是特定于不同计算能力的GPU的

按需页面迁移就是上面提到的，具有产生Page Fault硬件的GPU能提供该功能。页面预取，则是对于接下来可能频繁产生缺页故障的应对方案，提前告诉GPU需要迁移一大块内存，避免大量缺页故障的开销。

> 其实cuda驱动本身就有一种启发式的页面预取策略，当检测到连续的缺页中断时，驱动会自动预取之后的一部分范围的页面，以期望减少页面故障的产生

超额使用内存，即是GPU可以使用比自身要大的内存空间（只要总的系统内存充足，不管是多GPU的还是CPU的）。其实按需页面迁移，本身就允许了超额使用，比如所有数据都放在主机（size比GPU的内存大），GPU可以在需要时产生缺页故障迁移内存页面即可。

对于GPU内存确实已经满了的情况，GPU同样使用页面置换算法，将页面换出，只不过不是换到硬盘，而是其他设备（主机）的剩余空间中。

这里所说的并发访问具有几种含义，并非一般意义的那种直接允许多设备之间的原子访问.

对于一般的情况（没有使用`cudaMemAdvise()`，没有特殊硬件支持），这里所谓的并发，仅仅指GPU和CPU都可以访问，对于同时访问不同页面来说确实如此，但访问同样的页面时，页面还是在不停的迁移，从而保持一致性。

对于使用了`cudaMemAdvise`设定了内存访问属性的内存来说，该并发访问的含义有所不同。

所谓的`MemAdvise`有一下几种：

1. Default: data migrates on first touch
2. ReadMostly: data duplicated on first touch
3. PreferredLocation: resist migrating away from the preferred location
4. AccessedBy: establish direct mapping and avoid faults

> 以下所说的`设备`，不仅指GPU，还可以表示CPU。

`ReadMostly`从名字就可知，该页面大部分时间是在仅被读取的。对于这种情况，cuda不是做实际的页面迁移，而是同时保持多个备份（每个设备一个），只有当其中某个设备对该内存写了之后，将会使所有的设备中对应的页表项和页失效，仅保留被写入的那个副本。

`PreferredLocation`则是告知GPU该部分内存页面应该优先存放在那个设备的内存中。当其他设备访问该页面出现缺页故障时，如果支持直接访问（一般来说没有特殊硬件的支持，CPU无法直接访问GPU内存），那么就只建立对应的内存映射，通过PCIe总线直接访问而不迁移页面。

> 在UVM出现之前，cuda提供一种叫做`zero-copy`的方案。采用该方案，直接在主机内存中分配一块固定内存(pinned，非可分页内存)，然后GPU通过PCIe总线访问。受限于PCIe的速率，延迟非常高

`AccessedBy`和`PreferredLocation`的作用类似，都是为了阻止页面进行迁移。但此时无需指定一个优先存放内存，而是由CUDA自身决定放在哪里（在Volta架构上可以使用访问计数器决定）。另外也不会等待发生缺页故障再建立内存映射，而是提前建立好的。

使用NVLINK的GPU, 提供对于同一页面访问的真正原子性控制。

附上NVIDIA显卡支持功能的“进化图”和支持的平台:

![uvm-evolution](/images/cuda/uvm-evolution.png)

![uvm-evolution](/images/cuda/suported-platform.png)

# 内存管理API

![cuda-api-level](/images/cuda/cuda-api-level.png)

CUDA提供了两类API：
* 运行时API
* 驱动API

驱动API是一种低级API，它相对来说较难编程，但是它对于在GPU设备使用上提供了
更多的控制。运行时API是一个高级API，它在驱动API的上层实现。每个运行时API函数
都被分解为更多传给驱动API的基本运算。

> 两种API是互斥的，同一时间只能选择使用一种

## 驱动API

cuda10.2引入了一组操作虚拟内存空间的低级驱动API，这几个API可以和运行时API同时使用。

引入的目的：解决扩容问题。

这里通过C++的容器vector来说明，当执行`vector::reserve(...)`扩大空间时，在主机中的一个简单方法，就是直接在内存中先分配一块请求大小的内存，然后再把数据复制过去就行了。这也是在引入之前CUDA提供API的局限性，其编程模型限制了程序员只能按这种方法处理。

但在GPU中存在一些问题，因为GPU的内存比较有限，比如在一个2GB的GPU中，如果此时该`vector`的容量为1GB，使用这种简单方法扩容是无法生效的，应为此时GPU的内存无法同时容纳两个副本进行拷贝。

所以在CUDA10.2引入了新的解决方案：

```cpp
// Allocating physical memory
size_t granularity = 0;
CUmemGenericAllocationHandle allocHandle;
CUmemAllocationProp prop = {};
prop.type = CU_MEM_ALLOCATION_TYPE_PINNED;
// 仅支持在GPU上分配一块物理内存
// 可能在以后的版本会支持在主机内存分配
prop.location.type = CU_MEM_LOCATION_TYPE_DEVICE;
prop.location.id = currentDev;
cuMemGetAllocationGranularity(&granularity, &prop,
                                         CU_MEM_ALLOC_GRANULARITY_MINIMUM);
padded_size = ROUND_UP(size, granularity);
cuMemCreate(&allocHandle, padded_size, &prop, 0); 

/* Reserve a virtual address range */
cuMemAddressReserve(&ptr, padded_size, 0, 0, 0);
/* Map the virtual address range
 * to the physical allocation */
cuMemMap(ptr, padded_size, 0, allocHandle, 0); 

// 映射完了还要设置该块内存的访问模式
CUmemAccessDesc accessDesc = {};
accessDesc.location.type = CU_MEM_LOCATION_TYPE_DEVICE;
accessDesc.location.id = currentDev;
accessDesc.flags = CU_MEM_ACCESS_FLAGS_PROT_READWRITE;

cuMemSetAccess(ptr, size, &accessDesc, 1); 

// 释放
cuMemUnmap(ptr, size);
cuMemRelease(allocHandle);
cuMemAddressFree(ptr, size); 
```

回到这个扩容问题，它提供的方案就是一开始类vector的结构就采用这种方式分配内存，并把使用的物理空间地址和虚拟空间地址记录下来。然后`reserve`扩容的时候，只需要在已分配的虚拟空间地址的后面紧跟着分配一块增加的(reserve要求的比原来大的增量部分)虚拟空间地址，然后再创建一块GPU的物理空间，映射上去就可以了。


要求GPu分配虚拟空间地址的函数，支持传递一个起始地址，故只需要传递已有地址空间的末尾地址+1即可
```cpp
// old_ptr是当前vector的起始地址
// reserve_size是当前容量
// algned_sz是reserve传递进来的参数
cuMemAddressReserve(&new_ptr, (aligned_sz - reserve_sz), 0ULL, old_ptr + reserve_sz, 0ULL);
```

但由于各种原因，比如该虚拟地址空间已经被分配掉了，该函数可能会执行失败，此时无法分配增量的虚拟地址空间。只需要重新分配一个完整的大的虚拟空间地址即可，然后把原来持有的物理地址块`unmap`掉，重新映射到新`map`的这个虚拟地址空间即可。

## 运行时API简介

```cpp
__host__​cudaError_t cudaArrayGetMemoryRequirements ( cudaArrayMemoryRequirements* memoryRequirements, cudaArray_t array, int  device )
//Returns the memory requirements of a CUDA array.
__host__​__device__​cudaError_t 	cudaFree ( void* devPtr )
//Frees memory on the device.
__host__​cudaError_t cudaFreeHost ( void* ptr )
//Frees page-locked memory.
__host__​cudaError_t cudaHostAlloc ( void** pHost, size_t size, unsigned int  flags )
//Allocates page-locked memory on the host.
__host__​cudaError_t cudaHostGetDevicePointer ( void** pDevice, void* pHost, unsigned int  flags )
//Passes back device pointer of mapped host memory allocated by cudaHostAlloc or registered by cudaHostRegister.
__host__​cudaError_t cudaHostRegister ( void* ptr, size_t size, unsigned int  flags )
//Registers an existing host memory range for use by CUDA.
__host__​cudaError_t cudaHostUnregister ( void* ptr )
//Unregisters a memory range that was registered with cudaHostRegister.
__host__​__device__​cudaError_t 	cudaMalloc ( void** devPtr, size_t size )
//Allocate memory on the device.
__host__​cudaError_t cudaMallocHost ( void** ptr, size_t size )
//Allocates page-locked memory on the host.
__host__​cudaError_t cudaMallocManaged ( void** devPtr, size_t size, unsigned int  flags = cudaMemAttachGlobal )
//Allocates memory that will be automatically managed by the Unified Memory system.
__host__​cudaError_t cudaMemAdvise ( const void* devPtr, size_t count, cudaMemoryAdvise advice, int  device )
//Advise about the usage of a given memory range.
__host__​cudaError_t cudaMemGetInfo ( size_t* free, size_t* total )
//Gets free and total device memory.
__host__​cudaError_t cudaMemPrefetchAsync ( const void* devPtr, size_t count, int  dstDevice, cudaStream_t stream = 0 )
//Prefetches memory to the specified destination device.
__host__​cudaError_t cudaMemRangeGetAttribute ( void* data, size_t dataSize, cudaMemRangeAttribute attribute, const void* devPtr, size_t count )
//Query an attribute of a given memory range.
__host__​cudaError_t cudaMemRangeGetAttributes ( void** data, size_t* dataSizes, cudaMemRangeAttribute ** attributes, size_t numAttributes, const void* devPtr, size_t count )
//Query attributes of a given memory range.
__host__​cudaError_t cudaMemcpy ( void* dst, const void* src, size_t count, cudaMemcpyKind kind )
//Copies data between host and device.
__host__​__device__​cudaError_t 	cudaMemcpyAsync ( void* dst, const void* src, size_t count, cudaMemcpyKind kind, cudaStream_t stream = 0 )
//Copies data between host and device.
__host__​cudaError_t cudaMemcpyPeer ( void* dst, int  dstDevice, const void* src, int  srcDevice, size_t count )
//Copies memory between two devices.
__host__​cudaError_t cudaMemcpyPeerAsync ( void* dst, int  dstDevice, const void* src, int  srcDevice, size_t count, cudaStream_t stream = 0 )
//Copies memory between two devices asynchronously.
__host__​cudaError_t cudaMemset ( void* devPtr, int  value, size_t count )
//Initializes or sets device memory to a value.
```

# Open Linux Kernel Modules

> NVIDIA开源驱动

Starting in the 515 driver release series, two "flavors" of these kernel modules are provided:

* Proprietary. This is the flavor that NVIDIA has historically shipped.

* Open, i.e. source-published, kernel modules that are dual licensed MIT/GPLv2. These are new starting in release 515. With every driver release, the source code to the open kernel modules will be published on <https://github.com/NVIDIA/open-gpu-kernel-modules> and a tarball will be provided on <https://download.nvidia.com/XFree86/>.

仅支持Turing架构及之后的GPU。

该驱动提供的Kernel API中应该存在直接操作页面和页表的函数。

# refs

- <http://download.nvidia.com/XFree86/Linux-x86_64/515.43.04/README/kernel_open.html>
- <https://docs.nvidia.com/cuda/gpudirect-rdma/index.html#basics-of-uva-cuda-memory-management>
- <https://developer.nvidia.com/blog/introducing-low-level-gpu-virtual-memory-management/>
- <https://docs.nvidia.com/cuda/cuda-driver-api/group__CUDA__MEM.html>
- <https://developer.nvidia.com/blog/maximizing-unified-memory-performance-cuda/>
- <https://developer.nvidia.com/blog/beyond-gpu-memory-limits-unified-memory-pascal/>
- <https://developer.nvidia.com/blog/unified-memory-cuda-beginners/>
- <https://on-demand.gputechconf.com/gtc/2018/presentation/s8430-everything-you-need-to-know-about-unified-memory.pdf>
- Professional CUDA C Programming, by John Cheng, MAX Grossman, Ty McKercher
- <https://docs.nvidia.com/cuda/gpudirect-rdma/index.html#basics-of-uva-cuda-memory-management>
