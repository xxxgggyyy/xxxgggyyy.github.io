---
title: "kokkos安装和使用"
date: 2023-01-11T19:47:17+08:00
topics: "parallel-computing"
draft: true
---

# Kokkos

Kokkos是一个跨平台（体系结构）的通用异构并行计算平台。

> Kokkos本身的目标在于单节点（主机）内部的并行计算，而对于主机之间的通信仍期望开发者自行使用MPI。

`Kokkos Core`是Kokkos提供的C++实现， 其通过C++的**模板元编程**实现了对异构设备的执行单元和内存空间的抽象，以提供一个高层的C++并行编程模型。通过该模型开发者专注于具有可移植性的并行算法本身的开发，而不需要过多关注底层不同架构的差异性。

就其C++实现`Kokkos Core`而言，Kokkos更像是一个兼容层或者说转换层。根据用户的配置，Kokkos在编译时将用户使用其提供的编程模型编写的程序转为具体的后端代码，然后使用特定于此后端的工具生成最终的可执行程序。

> 比如使用CUDA作为后段，本质上仍然在使用`nvcc`编译

Kokkos目前可以使用CUDA, HIP, SYCL, HPX, OpenMP和c++线程作为后端编程模型，还有其他几个后端正在开发中。

Kokkos除了实现编程模型的`Kokkos Core`，还提供其他的工具。

![Kokkos生态](/images/kokkos_imgs/ecosystem.png)

## || 抽象机器模型

为了保证Kokkos具有跨平台的代码和性能可移植性，Kokkos第一部是对异构计算节点的物理机器进行了抽象。

![抽象机器模型](/images/kokkos_imgs/abstract_mm.png)

如图所示，Kokkos假设的抽象机器模型中具有多种不同的异构计算单元和多种内存。在此图中其列出了两种可能的计算单元，第一种如图中`Core`所示，其基本类似当今的多核CPU，具有较强的串行执行能力和逻辑处理能力。第二种如途中`Acc`所示，基本类似与当今的具有大量较高延迟核心的GPU。每类计算单元都具有自己的内存，这些内存可能具有不同的属性，或许只能被某类计算单元访问，或许也可以被其他计算单元访问。

根据该抽象模型，Kokkos抽象出了两个核心概念，**执行空间**和**内存空间**。

* 执行空间表示一组具有相同属性的计算单元，能够提供一组并行的执行资源
* 内存空间用于表示可用于分配数据的逻辑上的内存资源。

## || 编程模型

Kokkos编程模型的特点是6个核心抽象：`Execution Spaces, Execution Patterns, Execution Policies, Memory Spaces, Memory Layout and Memory Traits`，这些抽象概念允许制定通用算法和数据结构，然后可以将其映射到不同类型的体系结构。实际上，它们允许对算法进行编译时转换，以适应不同程度的硬件并行性和内存层次结构。

![编程模型](/images/kokkos_imgs/pm.png)

`ExecutionSpace`和`MemorySpace`不再赘述。

`Execution Patterns`也就是计算单元的并行执行模式，主要由以下三类：

1. `parallel_for`类似与openMP的`#pragma omp for`，他会自动对每次迭代进行合理调度和分配。

2. `parallel_reduce`，功能其实也类似于`parallel_for`，只不过每个迭代中会提供一个中间值，该线程的某些计算结果可以放在里面，最后在调用`join`将所有的中间结果合并，非自定义的`join`就是简单的加法

3. `parallel_scan`，提供前缀扫描。默认不提供`join`和`init`的扫描为加法扫描，类似于计算前缀和。

`ExecutionPolices`即执行策略，比如`RangePoliy`提供一个一维的迭代空间，`TeamPolicy`不提供迭代空间，而是类似与CUDA的线程块和网格的概念。

`MemoryLayout`即内存布局，包括`LayoutLeft`和`LayoutRight`、`LayoutStide`等。前两个就是数组列主序和行主序的概念。`Stride`则是由于实际的一个数组存储可能还包括的额外的空间需要，比如对齐，比如体系结构相关的数据，所以其用于表示数组每个维度变化1需要跨越的数据量。

`MemoryTraits`则是该块空间是否具有原子访问的特定等。

> 这里只是及其简单的概述，详情见[Here](https://kokkos.github.io/kokkos-core-wiki/ProgrammingGuide/View.html)

# Kokkos安装&测试

## || 测试环境&安装

使用Kokkos需要的前置条件见[Here](https://kokkos.github.io/kokkos-core-wiki/ProgrammingGuide/Compiling.html)

测试环境如下：

名称|版本
:--|:--
OS|Ubuntu 20.04.1
GCC|9.4.0
GNU Make|4.2.1
CUDA|12.0
GPU|NVIDIA Geforce MX250 - Pascal61
CPU|Intel Core i7-10510U - Skylake-CometLake

Kokkos是通过独立的C++库的形式提供的，严格来说并不需要安装，只需要从github上下载到一个固定目录即可。

```shell
# that's all
cd ~
git clone https://github.com/kokkos/kokkos.git
```

接着运行`kokkos/example/tutorial/01_hello_world`，测试是否可用。

在运行`make`之前需要修改`Makefile`中相关变量，以配置Kokkos（主要是指定需要使用后端和硬件架构）

```makefile
KOKKOS_PATH = ../../..
KOKKOS_SRC_PATH = ${KOKKOS_PATH}
# 指定后端使用Cuda和OpenMP
KOKKOS_DEVICES="Cuda,OpenMP"
KOKKOS_ARCH = "SKL,Pascal61"
CXX = ${KOKKOS_PATH}/bin/nvcc_wrapper
CXXFLAGS = -O3
LINK = ${CXX}
LDFLAGS = 
EXE = 01_hello_world.cuda

SRC = $(wildcard ${KOKKOS_SRC_PATH}/example/tutorial/01_hello_world/*.cpp)
vpath %.cpp $(sort $(dir $(SRC)))

default: build
	echo "Start Build"

DEPFLAGS = -M

OBJ = $(notdir $(SRC:.cpp=.o))
LIB =

include $(KOKKOS_PATH)/Makefile.kokkos

build: $(EXE)

test: $(EXE)
	./$(EXE)

$(EXE): $(OBJ) $(KOKKOS_LINK_DEPENDS)
	$(LINK) $(KOKKOS_LDFLAGS) $(LDFLAGS) $(EXTRA_PATH) $(OBJ) $(KOKKOS_LIBS) $(LIB) -o $(EXE)

clean: kokkos-clean 
	rm -f *.o *.cuda *.host

# Compilation rules

%.o:%.cpp $(KOKKOS_CPP_DEPENDS)
	$(CXX) $(KOKKOS_CPPFLAGS) $(KOKKOS_CXXFLAGS) $(CXXFLAGS) $(EXTRA_INC) -c $< -o $(notdir $@)
```

> `KOKKOS_ARCH`需要根据硬件指定对应的架构，这里我的笔记本CPU为`SkyLake`架构，GPU为`Pascal`架构。完整的Kokkos支持架构见[Here](https://kokkos.github.io/kokkos-core-wiki/ProgrammingGuide/Compiling.html)

构建并执行

```sh
make && make test
```

```sh
./01_hello_world.cuda
Kokkos::OpenMP::initialize WARNING: OMP_PROC_BIND environment variable not set
  In general, for best performance with OpenMP 4.0 or better set OMP_PROC_BIND=spread and OMP_PLACES=threads
  For best performance with OpenMP 3.1 set OMP_PROC_BIND=true
  For unit testing set OMP_PROC_BIND=false
Hello World on Kokkos execution space N6Kokkos4CudaE
Hello from i = 0
Hello from i = 1
Hello from i = 2
Hello from i = 3
Hello from i = 4
Hello from i = 5
Hello from i = 6
Hello from i = 7
Hello from i = 8
Hello from i = 9
Hello from i = 10
Hello from i = 11
Hello from i = 12
Hello from i = 13
Hello from i = 14
```

根据配置`Kokkos::DefaultExecutionSpace`为Cuda，正确。

## || 测试

为了测试Kokkos分别使用OpenMP和CUDA作为后台的性能，以下修改了Kokkos自带的`kokkos/example/tutorial/05_simple_atomics`程序，然后分别使用CUDA和OpenMP作为后端编译。

原始程序是一个从给定数组中找出所有素数的例子。该数组共有`100000`个元素，先分别在主机内存和GPU内存中分配该数组，然后使用CPU初始化（串行的没有启用OpenMP)，然后将数组拷贝到GPU中，利用CUDA核心并行计算每个元素是否是素数并记录，然后将结果拷贝会主机内存并显示。

为了方便比较，修改过的程序不会把数据在不同的内存空间中移来移去，而是在指定的执行空间中初始化和计算。仅最后结果（一个`int`变量）拷贝到主机内存空间。

> 另外这里将Kokkos的`parallel_for`修改为使用`TeamPolicy`，方便指定具体的执行空间使用的`team`的size大小，以及`league`大小。（即CUDA中的线程块和网格大小）

代码如下：

```cpp
#include <Kokkos_Core.hpp>
#include <cstdio>
#include <cstdlib>
#include <cmath>
#include <cstring>

// Type of a one-dimensional length-N array of int.
using view_type      = Kokkos::View<int*>;
// using host_view_type = view_type::HostMirror;

// This is a "zero-dimensional" View, that is, a View of a single
// value (an int, in this case).  Access the value using operator()
// with no arguments: e.g., 'count()'.
//
// Zero-dimensional Views are useful for reduction results that stay
// resident in device memory, as well as for irregularly updated
// shared state.  We use it for the latter in this example.
using count_type      = Kokkos::View<int>;
using host_count_type = count_type::HostMirror;

// init view using the same ExecutionSpace as findprimes
struct initspace {
  view_type data;

  initspace(view_type data_)
      : data(data_){}

  KOKKOS_INLINE_FUNCTION
  void operator()(const Kokkos::TeamPolicy<>::member_type& team) const {
    const int index = team.league_rank() * team.team_size() + team.team_rank();
    const int stride = team.team_size() * team.league_size();
    const int len = data.extent(0);
    for(int i = index;i < len;i += stride){
      unsigned int _status = 214013u * (unsigned int)i + 2531011u;
      data(i) = (int)(_status >> 16u & 0x7fffu) % len;
    }
  }
};

// Functor for finding a list of primes in a given set of numbers.  If
// run in parallel, the order of results is nondeterministic, because
// hardware atomic updates do not guarantee an order of execution.
struct findprimes {
  view_type data;
  view_type result;
  count_type count;

  findprimes(view_type data_, view_type result_, count_type count_)
      : data(data_), result(result_), count(count_) {}

  // Test if data(i) is prime.  If it is, increment the count of
  // primes (stored in the zero-dimensional View 'count') and add the
  // value to the current list of primes 'result'.
  KOKKOS_INLINE_FUNCTION
  void operator()(const Kokkos::TeamPolicy<>::member_type& team) const {
    const int index = team.league_rank() * team.team_size() + team.team_rank();
    const int stride = team.team_size() * team.league_size();
    const int len = data.extent(0);
    for(int i = index;i < len;i += stride){
      const int number = data(i);  // the current number

      // Test all numbers from 3 to ceiling(sqrt(data(i))), to see if
      // they are factors of data(i).  It's not the most efficient prime
      // test, but it works.
      const int upper_bound = std::sqrt(1.0 * number) + 1;
      bool is_prime         = !(number % 2 == 0);
      int k                 = 3;
      while (k < upper_bound && is_prime) {
        is_prime = !(number % k == 0);
        k += 2;  // don't have to test even numbers
      }

      if (is_prime) {
        // Use an atomic update both to update the current count of
        // primes, and to find a place in the current list of primes for
        // the new result.
        //
        // atomic_fetch_add results the _current_ count, but increments
        // it (by 1 in this case).  The current count of primes indexes
        // into the first unoccupied position of the 'result' array.
        const int idx = Kokkos::atomic_fetch_add(&count(), 1);
        result(idx)   = number;
      }

    }
  }
};

int main(int argc, char** argv) {

  if(argc != 3){
    printf("argc must be 3. the_prg league_size team_size ");
    return -1; 
  }

  int team_size = atoi(argv[2]);
  int league_size = atoi(argv[1]);

  Kokkos::initialize();
  {
    printf("DefaultExecutionSpace:%s\n", typeid(Kokkos::DefaultExecutionSpace).name());
    printf("DefaultHostExecutionSpace:%s\n", typeid(Kokkos::DefaultHostExecutionSpace).name());
    // srand(61391);  // Set the random seed

    int nnumbers = 100000000;
    view_type data("RND", nnumbers);
    view_type result("Prime", nnumbers);
    count_type count("Count");

    // host_view_type h_data   = Kokkos::create_mirror_view(data);
    // host_view_type h_result = Kokkos::create_mirror_view(result);
    host_count_type h_count = Kokkos::create_mirror_view(count);

    Kokkos::parallel_for(Kokkos::TeamPolicy<>(league_size, team_size), initspace(data));
    Kokkos::parallel_for(Kokkos::TeamPolicy<>(league_size, team_size), findprimes(data, result, count));
    Kokkos::deep_copy(h_count, count);  // copy from device to host

    printf("Found %i prime numbers in %i random numbers\n", h_count(),
           nnumbers);
  }
  Kokkos::finalize();
}
```

`Makefile`文件类似于上面的`hello_world`程序。

分别编译后得到分别使用两个后端的程序`05_simple_atomics.cuda和05_simple_atomics.host `

并使用如下脚本分别计算其运行时间：
```sh
#!/bin/bash

cuda_flags="384 1024"
omp_flags="1 8"

function remove_prefix0(){
    val=`echo $1 | sed -E 's/^0+//g'`
    if [[ -z $val ]];then
        echo 0
    else
        echo $val
    fi
}

function time_diff(){
    start_s=`echo $1 | cut -d '.' -f 1 | sed -E 's/^0+//g'`
    start_s=`remove_prefix0 $start_s`
    start_us=`echo $1 | cut -d '.' -f 2`
    start_us=`remove_prefix0 $start_us`
    start_us=$(( $start_us/1000 ))
    end_s=`echo $2 | cut -d '.' -f 1`
    end_s=`remove_prefix0 $end_s`
    end_us=`echo $2 | cut -d '.' -f 2`
    end_us=`remove_prefix0 $end_us`
    end_us=$(( $end_us/1000 ))

    diff_s=$(( $end_s-$start_s-1 ))
    diff_us=$(( 1000000-$start_us+$end_us ))
    diff_s=$(( $diff_s+$diff_us/1000000 ))
    diff_us=$(( $diff_us%1000000  ))
    echo -e "${diff_s}s $(( $diff_us/1000 ))ms $(( $diff_us%1000 ))us\c"
}

start=$(date +%s.%N)
echo prg using cuda is running...
echo "./05_simple_atomics.cuda ${cuda_flags}"
./05_simple_atomics.cuda ${cuda_flags}
end=$(date +%s.%N)
take=`time_diff $start $end`
echo CUDA cost ${take} seconds.
echo

start=$(date +%s.%N)
echo prg using openMP is running...
echo "./05_simple_atomics.host ${omp_flags}"
./05_simple_atomics.host ${omp_flags}
end=$(date +%s.%N)
take=`time_diff $start $end`
echo OpenMP cost ${take} seconds.
```

输出如下：
```sh
$ ./compare_rtime.sh 
prg using cuda is running...
./05_simple_atomics.cuda 384 1024
DefaultExecutionSpace:N6Kokkos4CudaE
DefaultHostExecutionSpace:N6Kokkos6OpenMPE
Found 10717790 prime numbers in 100000000 random numbers
CUDA cost 0s 563ms 231us seconds.

prg using openMP is running...
./05_simple_atomics.host 1 8
DefaultExecutionSpace:N6Kokkos6OpenMPE
DefaultHostExecutionSpace:N6Kokkos6OpenMPE
Found 10717790 prime numbers in 100000000 random numbers
OpenMP cost 0s 856ms 424us seconds.
```
