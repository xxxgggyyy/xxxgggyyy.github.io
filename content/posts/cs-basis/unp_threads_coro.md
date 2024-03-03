---
title: "unp threads coro"
date: 2023-03-24T20:05:38+08:00
topics: "cs-basis"
draft: true
---

# 线程与线程池
> unp 26章线程、30章线程池

## || 线程

在网络编程中，使用线程代替进程的原因：

1. 线程更加轻量级，创建和切换的开销更小
2. 共享进程空间资源，易于传递信息，简化编程模型

### Pthread

```cpp
// 创建pthread线程
// 唯一需要注意的是，成功返回0，出错返回非0值，但并不设置errno
int pthread_create(pthread_t* tid, const pthread_attr_t* attr, void *(*func)(void*), void *arg);

// 在某个线程中等待某个线程tid结束
// status为等待某个线程的返回值
int pthread_join(pthread* tid, void **status);

// 返回当前线程自身的tid
pthread_t pthread_self(void);

// 终止线程
// status指向要返回的值
void pthread_exit(void *status);

// 线程分离
int pthread_detach(pthread_t tid);
```

一个线程要么是可汇合的（默认）要么是分离的。可汇合的，其实有点类似linux下子进程退出后要保留退出状态和相关资源直到父进程执行`waitpid()`。这里同理，可汇合函数退出后它的线程ID和退出状态将留存到另一个线程对其执行`pthread_join`获得。

如果执行了`pthread_detach()`，id和退出状态在线程退出后不会被保存。

#### 使用线程的`str_cli`

此时不需要多路复用，可以使用多线程分别等待不同的文件描述符。

![str_cli](/home/xui/Pictures/screenshots/unp/str_cli_using_thread.png)

#### 使用线程的回射服务器程序

![echo_server](/home/xui/Pictures/screenshots/unp/echo_server_using_thread.png)

这里直接使用，`*arg`传递了整型的文件描述符，这在指针占用空间大于等于整型变量时才能生效。

> 尽管在大多数的类UNIX上都满足该特征，但ANSI C并不保证这么做能生效

另外C提供的`malloc()/free()`函数由于使用了一些静态数据结构并不能保证是可重入的，所以这里如果要使用`malloc`来分配一块整型空间来传递，那么在每个子线程中释放该内存空间时需要注意该问题。

### 线程特定数据

上面用线程改写的回射服务器有个问题，其在子线程中使用的`readline()`函数（`str_echo()`中），使用了静态数据结构，该函数并非线程安全的。

![readline](/home/xui/Pictures/screenshots/unp/readline1.png)
![readline2](/home/xui/Pictures/screenshots/unp/readline2.png)

将这类函数改造为线程安全的方法之一是使用线程特定数据。

> 仅在支持线程特定数据的系统中使用。该方法只需修改函数内部实现，无需改变接口。

线程特定数据，类似于为每个函数提供了特定于线程的静态数据一样。

线程特定数据的一种可能的实现形式如下：

![thread_spec_data](/home/xui/Pictures/screenshots/unp/thread_spec_data1.png)

线程库（系统）在**进程**范围内维护一个称之为Key结构的结构数组。每个Key有两个字段，其中标志字段标示该数组元素是否可用。析构函数指针的作用稍后讨论。

> 每个系统支持的线程特定数据有限，POSIX要求这个限制不小于128

![thread_spec_data](/home/xui/Pictures/screenshots/unp/thread_spec_data2.png)

除了上述的Key结构数据，系统（线程库）还为每个**线程**维护多条信息，如图所示。这里称之为pkey数组。

通过`pthread_key_create()`在Key结构数组中获取未使用的索引`i`，然后在所有线程中就可以使用`pkey[i]`条目，用于存放指向一块实际数据的指针。

而Key结构中析构函数指针字段，就是在线程结束时自动执行来回收所有`pkey[i]`不为空的数据。

> 简单来说就是为每个线程提供了至少128个特定于线程的静态指针变量，通过该方法赋予了用户创建自己的特定于线程的""静态数据"

使用线程特定数据改造的`readline()`函数如下：


![ts_readline1](/home/xui/Pictures/screenshots/unp/ts_readline1.png)
![ts_readline2](/home/xui/Pictures/screenshots/unp/ts_readline2.png)

使用`pthread_once()`保证在所有线程中只执行唯一一次`readline_once()`，其中执行`pthread_key_create()`向系统申请Key结构数组中的一个索引。然后在每个线程中现在都可以使用一个特定于线程的静态指针变量了`pkey[i]`。

之后每个线程在第一次执行`readline()`函数时，检查`pkey[i]`是否为空，为空就分配数据（对于readline来说就是一块缓存和一些计数器变量这里封装为了`Rline`结构）,不为空就直接使用。

> `pthread_get_specific()`和`pthread_set_specific()`就是用来获取或者设置对应的`pkey[i]`条目的值的。


### pthread线程同步

```cpp
pthread_mutex_t mutext = PTHREAD_MUTEX_INITIALIZER;
int pthread_mutex_lock(pthread_mutex_t* mptr);
int pthread_mutex_unlock(pthread_mutex_t* mptr);

int pthread_cond_wait(pthread_cond_t* cptr, pthread_mutex_t* mptr);
int pthread_cond_signal(pthread_cond_t* cptr);
```

`pthread_cond_wait()`需要结合一个互斥锁使用，其需要在获取到该互斥锁的基础上执行等待，不然可能导致`pthread_cond_singal()`信号丢失。

`pthread_cond_wait()`在条件不满足时，除了将该线程陷入等待，还会释放获取到的锁。直到重新被唤醒，会再次尝试加锁。

> 获取锁成功才重新执行

比如`pthread_cond_singal()`，如果在`pthread_cond_wait()`执行之前（线程陷入等待之前）就执行了，那么该信号就丢失了。

典型的用法如下：

```cpp
int ndone = 0;
pthread_mutex_t ndone_mutex = PTHREAD_MUTEX_INITIALIZER;
pthread_cond_t ndone_cond = PTHREAD_COND_INITIALIZER;

void thread0(){
    ......
    pthread_mutex_lock(&ndone_mutex);
    ndone++;
    pthread_cond_signal(&nodone_cond);
    pthread_mutex_unlock(&ndone_mutex)
}


void main_thread(){

    ......
    pthread_mutex_lock(&ndone_mutex);
    // 如果不加锁，在cond_wait之前信号到来，该信号将丢失。
    while(ndone == 0)
        pthread_cond_wait(&ndone_cond, &ndone_mutex);
    ......
    pthread_mutex_unlock(&ndone_mutex);
}

```

> 这章还有个Web客户程序开启多线程同时获取多个文件的例子。它使用的就是条件变量，感觉没有直接使用信号量好，同时也比较简单，这里就没有再列出来。


## || 线程池

这里的线程池参考的UNP30章的`预先创建线程服务器`。

该章节关于线程池在服务器中的简单使用，介绍了两种方案。

1. 预先创建多个线程，在每个线程中都执行`accept()`函数，这些线程使用一个互斥锁保证同一时间只有一个线程陷入`accept()`阻塞。

> 因为某些操作系统并不保证`accept()`是可重入的。


2. 在主线程统一执行`accept()`，然后将得到的套接字fd放入一个循环队列（数组实现）中。结合条件变量，所有子线程都等待在某个条件变量上，在主线程新接受连接后，发送信号唤醒某个线程，该线程从队列中取一个fd处理。

> 比较简单没有再列出代码。

# 协程

协程是一种类似多线程的**用户级**的一种并发方案。但他实际上是单线程执行的，并且需要用户手动`yield()`让出执行权给其他协程，以此在各个协程中流转执行。

协程可以用来解决IO密集型应用。对比传统的多线程方案，使用协程要轻量级得多。

传统多线程方案，在线程暴增的情况下，不仅线程本身需要占用大量的系统资源，线程之间切换的开销也是不可接受的。

使用协程可以解决这些问题，虽然牺牲了公平性（只能在执行非阻塞IO后`yield`让其他协程执行）。

> 协程是用户级的，不能用来执行阻塞IO
> 只能执行非阻塞IO，发出IO请求后

并且协程实际上是"串行"执行的，减少了同步锁，整体上提高了性能。

协程再细分可以分为有栈协程和无栈协程，并且在C/C++上的实现方式有很多种：

* 利用 glibc 的 ucontext 组件(skynet)
* 使用汇编代码来切换上下文(libco)
* 利用 C 语言语法switch-case的奇淫技巧来实现（Protothreads)
* 利用了 C 语言的 setjmp 和 longjmp（ 一种协程的 C/C++ 实现,要求函数里面使用 static local 的变量来保存协程内部的数据）

下面通过一个简单有栈协程的实现来具体说明协程：
> 该代码为云风大神在10年前编写，基于ucontext实现
> <https://github.com/cloudwu/coroutine>

```cpp
#include "coroutine.h"
#include <stdio.h>
#include <stdlib.h>
#include <assert.h>
#include <stddef.h>
#include <string.h>
#include <stdint.h>

#if __APPLE__ && __MACH__
	#include <sys/ucontext.h>
#else 
	#include <ucontext.h>
#endif 

#define STACK_SIZE (1024*1024)
#define DEFAULT_COROUTINE 16

struct coroutine;

struct schedule {
	char stack[STACK_SIZE];
	ucontext_t main;
	int nco;
	int cap;
	int running;
	struct coroutine **co;
};

struct coroutine {
	coroutine_func func;
	void *ud;
	ucontext_t ctx;
	struct schedule * sch;
	ptrdiff_t cap;
	ptrdiff_t size;
	int status;
	char *stack;
};

struct coroutine * 
_co_new(struct schedule *S , coroutine_func func, void *ud) {
	struct coroutine * co = malloc(sizeof(*co));
	co->func = func;
	co->ud = ud;
	co->sch = S;
	co->cap = 0;
	co->size = 0;
	co->status = COROUTINE_READY;
	co->stack = NULL;
	return co;
}

void
_co_delete(struct coroutine *co) {
	free(co->stack);
	free(co);
}

struct schedule * 
coroutine_open(void) {
	struct schedule *S = malloc(sizeof(*S));
	S->nco = 0;
	S->cap = DEFAULT_COROUTINE;
	S->running = -1;
	S->co = malloc(sizeof(struct coroutine *) * S->cap);
	memset(S->co, 0, sizeof(struct coroutine *) * S->cap);
	return S;
}

void 
coroutine_close(struct schedule *S) {
	int i;
	for (i=0;i<S->cap;i++) {
		struct coroutine * co = S->co[i];
		if (co) {
			_co_delete(co);
		}
	}
	free(S->co);
	S->co = NULL;
	free(S);
}

int 
coroutine_new(struct schedule *S, coroutine_func func, void *ud) {
	struct coroutine *co = _co_new(S, func , ud);
	if (S->nco >= S->cap) {
		int id = S->cap;
		S->co = realloc(S->co, S->cap * 2 * sizeof(struct coroutine *));
		memset(S->co + S->cap , 0 , sizeof(struct coroutine *) * S->cap);
		S->co[S->cap] = co;
		S->cap *= 2;
		++S->nco;
		return id;
	} else {
		int i;
		for (i=0;i<S->cap;i++) {
			int id = (i+S->nco) % S->cap;
			if (S->co[id] == NULL) {
				S->co[id] = co;
				++S->nco;
				return id;
			}
		}
	}
	assert(0);
	return -1;
}

static void
mainfunc(uint32_t low32, uint32_t hi32) {
	uintptr_t ptr = (uintptr_t)low32 | ((uintptr_t)hi32 << 32);
	struct schedule *S = (struct schedule *)ptr;
	int id = S->running;
	struct coroutine *C = S->co[id];
	C->func(S,C->ud);
	_co_delete(C);
	S->co[id] = NULL;
	--S->nco;
	S->running = -1;
}

void 
coroutine_resume(struct schedule * S, int id) {
	assert(S->running == -1);
	assert(id >=0 && id < S->cap);
	struct coroutine *C = S->co[id];
	if (C == NULL)
		return;
	int status = C->status;
	switch(status) {
	case COROUTINE_READY:
		getcontext(&C->ctx);
		C->ctx.uc_stack.ss_sp = S->stack;
		C->ctx.uc_stack.ss_size = STACK_SIZE;
		C->ctx.uc_link = &S->main;
		S->running = id;
		C->status = COROUTINE_RUNNING;
		uintptr_t ptr = (uintptr_t)S;
		makecontext(&C->ctx, (void (*)(void)) mainfunc, 2, (uint32_t)ptr, (uint32_t)(ptr>>32));
		swapcontext(&S->main, &C->ctx);
		break;
	case COROUTINE_SUSPEND:
		memcpy(S->stack + STACK_SIZE - C->size, C->stack, C->size);
		S->running = id;
		C->status = COROUTINE_RUNNING;
		swapcontext(&S->main, &C->ctx);
		break;
	default:
		assert(0);
	}
}

static void
_save_stack(struct coroutine *C, char *top) {
	char dummy = 0;
	assert(top - &dummy <= STACK_SIZE);
	if (C->cap < top - &dummy) {
		free(C->stack);
		C->cap = top-&dummy;
		C->stack = malloc(C->cap);
	}
	C->size = top - &dummy;
	memcpy(C->stack, &dummy, C->size);
}

void
coroutine_yield(struct schedule * S) {
	int id = S->running;
	assert(id >= 0);
	struct coroutine * C = S->co[id];
	assert((char *)&C > S->stack);
	_save_stack(C,S->stack + STACK_SIZE);
	C->status = COROUTINE_SUSPEND;
	S->running = -1;
	swapcontext(&C->ctx , &S->main);
}

int 
coroutine_status(struct schedule * S, int id) {
	assert(id>=0 && id < S->cap);
	if (S->co[id] == NULL) {
		return COROUTINE_DEAD;
	}
	return S->co[id]->status;
}

int 
coroutine_running(struct schedule * S) {
	return S->running;
}
```
