---
title: "openMP CUDA MPI简介"
date: 2023-01-08T14:33:32+08:00
topics: "parallel-computing"
draft: true
---

# openMP
OpenMP (Open Multi-Processing) 是一种支持跨平台共享内存系统的多线程程序设计方案。支持的语言包括C、C++、Fortran。

openMP对于原生线程编程模型有两个比较明显的优势：
1. 高度抽象的多线程编程模型，降低并行程序开发门槛
2. 支持跨平台。举例来说对于原生线程来说，UNIX下使用POSIX接口，而Windows下使用其自身的接口，增加程序迁移和维护的难度。

> 共享内存主要针对是SMP架构的单主机，而AMP和分布式计算均无法直接共享内存。参考文章：[NUMA架构详解](https://blog.csdn.net/qq_20817327/article/details/105925071)

openMP由能够影响程序运行期行为的三部分组成，包括一组编译期指令、库例程、环境变量。

OpenMP采用所谓的fork-join的执行模式。即在需要时启动多个线程执行并行代码，直到所有线程执行完毕，将重新在主线程会和继续向下执行。

## || 简单用法示例

**基础并行域**
```cpp
#include<iostream>
#include"omp.h"
using namespace std;

void main()
{
    // num_threads可省略，默认为CPU核数的线程数量
    #pragma omp parallel num_threads(6)
    {
        cout << "ThreadID: " << omp_get_thread_num() <<endl;
    }
    system("pause");
}
```
`#pragma omp parallel`标识的代码块将会使用线程自动并行执行，这里将会打印6次。

可以使用线程号、总线程数量等并行执行类似向量加法的运算。

**for循环并行**
```cpp
int main(int argc, char **argv)
{
    int a[100000];

    #pragma omp parallel for
    for (int i = 0; i < 100000; i++) {
        a[i] = 2 * i;
    }
    return 0;
}
```
`#pragma omp parallel for`将会根据`i`值自动拆解`for`循环，比如说如果这里有两个线程，那么`0-49999`可能有线程1执行，`50000-99999`由线程2执行。

由上两个例子可见，需要自己考虑并行域或者单次`for`迭代的独立性，或者说需要注意**竞争条件**。


> 参考：
> * [OpenMP基本概念](https://blog.csdn.net/yu132563/article/details/82704993)
> * [OpenMP - Wikipedia](https://en.wikipedia.org/wiki/OpenMP)

# CUDA
`CUDA`是NVIDIA开发的流行的并行计算平台和编程模型。

## || CUDA示例
下面通过将一个C++编写的简单向量加法程序迁移到GPU上来执行，来说明`CUDA`的基础概念。

**原始C++程序**
```cpp
#include <iostream>
#include <math.h>

// function to add the elements of two arrays
void add(int n, float *x, float *y)
{
  for (int i = 0; i < n; i++)
      y[i] = x[i] + y[i];
}

int main(void)
{
  int N = 1<<20; // 1M elements

  float *x = new float[N];
  float *y = new float[N];

  // initialize x and y arrays on the host
  for (int i = 0; i < N; i++) {
    x[i] = 1.0f;
    y[i] = 2.0f;
  }

  // Run kernel on 1M elements on the CPU
  add(N, x, y);

  // Check for errors (all values should be 3.0f)
  float maxError = 0.0f;
  for (int i = 0; i < N; i++)
    maxError = fmax(maxError, fabs(y[i]-3.0f));
  std::cout << "Max error: " << maxError << std::endl;

  // Free memory
  delete [] x;
  delete [] y;

  return 0;
}
```
> `Check Err`部分并非说迁移到GPU上执行会出现误差，而是用来说明CUDA的内存模型

### 迁移至GPU运行

为了使`add`函数能在GPU上运行，需要将`add`变为核函数。
```cpp
// CUDA Kernel function to add the elements of two arrays on the GPU
__global__
void add(int n, float *x, float *y)
{
  for (int i = 0; i < n; i++)
      y[i] = x[i] + y[i];
}
```
`__global__`属于`CUDA`的语法，使用专用的编译器`nvcc`。

为了能在GPU上运行，另一个需要考虑的问题是内存空间位置和分配。CUDA中提供所谓的统一内存(Unified Memory) ,这让分配一块CPU和GPU都能访问的内存空间变得很容易。

只要使用相应库函数代替`new和delete`即可。

```cpp
  // Allocate Unified Memory -- accessible from CPU or GPU
  float *x, *y;
  cudaMallocManaged(&x, N*sizeof(float));
  cudaMallocManaged(&y, N*sizeof(float));

  ...

  // Free memory
  cudaFree(x);
  cudaFree(y);
```

最后，为了在GPU上启动`add`函数，需要使用如下语法调用`add`

```cpp
add<<<1, 1>>>(N, x, y);
```
> 这里语法的含义是仅使用一个线程在GPU上运行。
> 更详细的用法稍后说明

以上就是将`add`迁移至GPU上运行需要的全部工作。

另外，GPU计算完成后CPU需要检查计算的误差，所以在GPU上启动`add`后，CPU上还需要执行`cudaDeviceSynchronize()`来等待GPU上的运算完成。

修改后的源程序如下：

```cpp
#include <iostream>
#include <math.h>
// Kernel function to add the elements of two arrays
__global__
void add(int n, float *x, float *y)
{
  for (int i = 0; i < n; i++)
    y[i] = x[i] + y[i];
}

int main(void)
{
  int N = 1<<20;
  float *x, *y;

  // Allocate Unified Memory – accessible from CPU or GPU
  cudaMallocManaged(&x, N*sizeof(float));
  cudaMallocManaged(&y, N*sizeof(float));

  // initialize x and y arrays on the host
  for (int i = 0; i < N; i++) {
    x[i] = 1.0f;
    y[i] = 2.0f;
  }

  // Run kernel on 1M elements on the GPU
  add<<<1, 1>>>(N, x, y);

  // Wait for GPU to finish before accessing on host
  cudaDeviceSynchronize();

  // Check for errors (all values should be 3.0f)
  float maxError = 0.0f;
  for (int i = 0; i < N; i++)
    maxError = fmax(maxError, fabs(y[i]-3.0f));
  std::cout << "Max error: " << maxError << std::endl;

  // Free memory
  cudaFree(x);
  cudaFree(y);
  
  return 0;
}
```
CUDA源程序的后缀为`.cu`,故将其保存后使用`nvcc`编译并执行。

```sh
> nvcc add.cu -o add_cuda
> ./add_cuda
Max error: 0.000000
```

这里虽然迁移到了GPU上运行，但仅仅使用了单个线程。另外由于GPU线程并行运行，所以需要考虑竞争条件。(当然这里不需要考虑)

CUDA Toolkil提供了一个工具`nvprof`能用来分析CUDA程序。

```sh
$ nvprof ./add_cuda
==3355== NVPROF is profiling process 3355, command: ./add_cuda
Max error: 0
==3355== Profiling application: ./add_cuda
==3355== Profiling result:
Time(%)      Time     Calls       Avg       Min       Max  Name
100.00%  463.25ms         1  463.25ms  463.25ms  463.25ms  add(int, float*, float*)
...
```

### 使用GPU上的多线程

在说明`add<<<1, 1>>>(N, x, y)`的语法之前，需要介绍一些概念。

CUDA GPUs上有很多可以并行运行的处理器，这些处理器被被分组为所谓的`流式多处理器(Streaming Multiprocessors,or SMs)`,而每个`SM`可以运行多个并发执行的线程块。一个线程块（组）可以包含多个线程。作为一个例子，基于`Pascal GPU Architecture`的Tesla P100 GPU包含56个SM，而每个SM支持2048个活动线程。

而`add<<<1, 1>>>`中两个参数分别代表运行该核函数的线程块个数，以及每个线程块中的线程个数。第二个参数一般为`32`的倍数。

所以为了使用GPU上的多线程运行，可以考虑执行:

```cpp
add<<<1, 256>>>(N, x, y);
```

但这仅告诉CUDA需要256个线程执行该核函数，而每个线程都会把整个数组加一遍，这显然不正确且存在竞争条件，所以我们需要拆分，每个线程仅处理部分即可。

```cpp
__global__
void add(int n, float *x, float *y)
{
  int index = threadIdx.x;
  int stride = blockDim.x;
  for (int i = index; i < n; i += stride)
      y[i] = x[i] + y[i];
}
```
`threadIdx.x`即当前线程ID，而`blockDim.x`则是一个线程块中线程的数量。

为了充分利用GPU的并行能力，还可以继续增加块数：

```cpp
__global__
void add(int n, float *x, float *y)
{
  int index = blockIdx.x * blockDim.x + threadIdx.x;
  int stride = blockDim.x * gridDim.x;
  for (int i = index; i < n; i += stride)
    y[i] = x[i] + y[i];
}

int blockSize = 256;
int numBlocks = (N + blockSize - 1) / blockSize;
add<<<numBlocks, blockSize>>>(N, x, y);
```

多个线程块被称为网格(CUDA grid)，所以`gridDim.x`表示线程块的个数。
> `(N+blockSize-1)/blockSize`其实就相当于`ceil()`，`N/blockSize`可能的余数为`[0,blockSize-1]`，故增加`blockSize-1`对余数为0没有影响，而对`[0,blockSize-1]`则刚好结果多1，不会多2。

此时在Tesla K80上执行只需要0.094ms，而单线程需要463ms。(具体比较见原文)

## || Unified Memory简介

在介绍Unified Memory之前先来看看，上文中的多线程块程序在基于Pascal GP 100 GPU的Tesla P100上的运行性能。

```cpp
> nvprof ./add_grid
...
Time(%)      Time     Calls       Avg       Min       Max  Name
100.00%  2.1192ms         1  2.1192ms  2.1192ms  2.1192ms  add(int, float*, float*)
```

令人惊奇的是，在性能更好，架构更新的Tesla P100上的执行时间反而变慢了。

实际上并没有变慢。

当CPU或者GPU访问这些CUDA所管理的内存时，实际上是由CUDA系统软硬件在实现内存页面迁移。
> 我们知道GPU有自己的显存

这里的关键在于Pascal GPU架构是第一代在硬件上支持虚拟内存缺页中断和页面迁移的架构（通过所谓的页面迁移引擎）。而更老的Kepler和Maxwell架构没有硬件上的支持，只能提供一些受限的统一内存服务。

### Kepler统一内存简介

在Kepler架构上，当我们调用`cudaMallocManaged()`时，CUDA会在GPU自身的内存分配空间即建立对应页表项。此时CUDA知道这部分内存页面时驻留在GPU内存里的。而当我们使用CPU对这些内存进行初始化时，会导致CPU产生缺页中断，导致内存页面从GPU不断迁移到CPU。当初始化循环结束时，所有的内存页面都迁移到了主机内存中（即CPU使用的内存）。而接下来我们执行核函数时，由于在Pascal架构之前GPU都没有硬件支持发送缺页中断，导致GPU运行核函数时，必须把之前迁移出去的内存一次性全部迁移回GPU内存中。所以此时在执行核函数之前会有一些内存迁移的开销。

如果使用`Tesla K80`运行有如下结果：

```sh
==15638== Profiling application: ./add_grid
==15638== Profiling result:
Time(%)      Time     Calls       Avg       Min       Max  Name
100.00%  93.471us         1  93.471us  93.471us  93.471us  add(int, float*, float*)

==15638== Unified Memory profiling result:
Device "Tesla K80 (0)"
   Count  Avg Size  Min Size  Max Size  Total Size  Total Time  Name
       6  1.3333MB  896.00KB  2.0000MB  8.000000MB  1.154720ms  Host To Device
     102  120.47KB  4.0000KB  0.9961MB  12.00000MB  1.895040ms  Device To Host
Total CPU Page faults: 51
```
需要注意的是，`nvprof`上半部分统计的运行时间仅仅是关于核函数在GPU上的运行时间，数据迁移的时间是在下半部分单独列出的。

而这也是为何在Tesla P100上统计时间比K80多的原因，P100支持硬件缺页中断，所以不会在运行核函数之前就迁移所有的页面，而是在运行过程中产生缺页中断来迁移内存，由于是在核函数执行过程中执行的，所以内存页面的迁移时间也被统计在内。

### Pascal架构Unified Memory简介

正如上所述，Pascal架构支持硬件缺页中断，所以执行核函数之前不会有任何的内存迁移开销。而在执行`cudaMallocManaged()`时，也不会立即分配页面，而是当CPU或GPU访问内存产生缺页中断时才分配或者迁移。

所以如上所属新架构并没有减少运行时间。所有该怎么改进才能减少GPU上的运行时间呢？（实际上如果必须CPU初始化的话，程序总时间其实没有太多的不同）

1. 考虑新增一个核函数，用来在GPU上并行对内存进行初始化。这样在执行`add`核函数时就不涉及内存迁移问题

2. 多执行几次`add`，当然就这个问题来说多执行几次没有实际意义，但除了第一次`add`会导致内存迁移变慢，其他`add`会和其应有的效率相当。

3. 使用预取库函数，如`cudaMemPrefetchAsync()`，预先把内存页面迁移到GPU后再执行程序。

> 这三种方法的具体代码见原文

### 在Pascal架构及之后的GPU上使用Unified Memory的优势

从Pascal架构开始，49bit的虚拟地址和按需的内存页面迁移，使得Unified Memory功能性被大幅提高了。49bit的地址空间足以使得GPU能够访问整个的系统内存和所有GPUs的内存。而增加的硬件缺页中断则使得页面按需迁移。这些功能的增加使得使用Unified Memory的程序无需任何修改，就可同时运行在单GPU或者多GPU的系统上。

这种按需页面迁移，对于某些访问内存属于**稀疏模式**的程序，更有效率。

另外，在Pascal和Volta GPU上，支持系统范围的原子内存访问。

### 关于并行程序的一些注意

我们必须小心安排并行程序对内存的访问，以免引起竞争条件。

在Pascal架构之前的GPU，由于没有硬件缺页中断的支持，在核函数执行时所也页面都在GPU中，此时如果CPU访问内存，由于内存一致性没法保证，将会导致段错误。

而在Pascal及之后的GPU中，由于都存在缺页中断，则可以同时访问。但需要开发者自己处理竞争条件。

> 原文: 
> * <https://developer.nvidia.com/blog/even-easier-introduction-cuda/>
> * <https://developer.nvidia.com/blog/unified-memory-cuda-beginners/>

# MPI

MPI(Message Passing Interface)是一个跨语言的通信协议，支持高效方便的点对点、广播、组播。是高性能计算常用的实现方式。

以下使用MPI的一个实现MPICH，的一个简单程序来说明其基本用法。

> 算了，以后再写。MPI的核心就是一份程序多处运行，然后之间可以通信。

> 参考：
> [MPI Guides](https://www.mpich.org/)
> <http://www.xtaohub.com/IT-neo/Parallel-programming-MPI.html>
