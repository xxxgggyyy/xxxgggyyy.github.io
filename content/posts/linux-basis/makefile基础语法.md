---
title: "makefile基础语法"
date: 2022-06-19T15:16:48+08:00
topics: "linux-basis"
draft: true
---

# makefile基本原理

## || 规则
```makefile
targets : prerequisites	
	command
...
```
一个规则由三部分组成：目标、先决条件（依赖）、命令。
通过`make target`执行规则，`make`默认执行第一个规则。
在执行规则时，无论是目标还是依赖，make都把它们认为是实际文件。所以如果目标文件还不存在那么需要执行命令来生成目标，如果目标文件存在了，但是比依赖文件更旧（比较目标和依赖的时间戳），说明依赖更新了，也需要重新执行命令生成目标。如下
```makefile
main.o: main.c
	gcc -c main.c -o main.o
```
有趣的是，**依赖也可以作为一个规则的目标**。
在make执行一个规则时，会逐个检查依赖，如果该依赖还是一个规则的目标，那么还会递归的检查和执行（如果需要重新生成该依赖）该规则。
```makefile
main: util.o main.o
	gcc -o main util.o main.o
util.o: util.c util.h
	gcc -c -o util.o util.c
main.o: main.c
	gcc -c main.c -o main.o
```
故此处直接执行`make main`则可自动构建main可执行文件。
这就是使用make能够自动构建的基本原理，并且make能保证只进行必要的重新编译。

### 假目标
目标最常见的用法则是如上所述-作为命令的生成目标文件名，然后再次执行make时会通过该文件的时间戳来确定是否需要重新生成。
但有时我们并不需要这种特性，如下
```makefile
clean:
	rm *.o
```
此时若存在一个文件名为clean，本身又没有依赖，下次执行`make clean`时反而由于clean文件存在，导致命令不会不执行。此时可以定义该目标为假目标，让make不把目标看成文件，而是直接执行。
```makefile
.PHONY: clean
clean:
	rm *.o
```

### 消除多余命显示
再命令执行时，make会先打印该命令，再执行，可以用`@`消除该打印
```makefile
main.o: main.c
	@gcc -c main.c -o main.o
```

### 规则的其他形式
```makefile
# 单独作为目标的简写形式
target1 target2: dep1 dep2
	cmds
# 等价于如下两条规则
target1: dep1 dep2
	cmds
target2: dep1 dep2
	cmds

```
这种方式其实是将`target1`和`target1`单独当作目标的简写。

在规则中**使用模式**简化规则编写
```makefile
%.o: %.c
	gcc -c $^ -o $@
```
此时如果目录下如果有两个文件`a.c`、`b.c`，则如上等价于
```makefile
a.o: a.c
	gcc -c $^ -o $@
b.o: b.c
	gcc -c $^ -o $@
```
> `$@`和`$^`为自动变量，分别表示目标和依赖，见下节变量


## || 变量
makefile中支持变量，可以大大提高makefile的灵活性。变量基本用法如下
```makefile
objs = util.o main.o
exe = main
$(exe): $(objs)
	gcc -o $(exe) $(objs)
util.o: util.c util.h
	gcc -c -o util.o util.c
main.o: main.c
	gcc -c main.c -o main.o
```
注意变量可以用在任何地方，包括双引号和单引号内。

### 自动变量
自动变量只能在规则中使用，含义如下
* `$@`表示目标
* `$^`表示所有依赖
* `$<`表示第一个依赖

此时使用`$$`对`$`转义。

### 特殊变量
* `MAKE`变量表示make程序名，便于makefile移植
* `MAKECMDGOALS`表示用户在make的命令行参数中输入的所有目标

### 变量的递归扩展性与简单变量
```makefile
var2 = one
var1 = $(var2)
var2 = two
```
如果此时在规则中`echo`变量`var1`，其值为`two`。这表示变量`var1`的值是在执行时自动递归扩展的。
也可使用简单变量（`:=`）取消这种特性，即变量的值只会替换一次。

```makefile
var2 = one
var1 := $(var2)
var2 = two
```
### 条件变量
```makefile
x = one
x ?= two
y ?= two
```
若变量已定义则忽略条件赋值，如果该变量未定义则正常赋值。

### 避免用户参数覆盖变量：override
```makefile
override foo = kkk
```
用户执行`make foo=ttt`foo的值也不会被修改。

## || makefile函数

### 通配符函数：wildcard
```makefile
src = $(wilcard *.c)
all:
	@echo $(src)
```
`wildcard`会根据给出的模式匹配出所有的文件，并通过空格构成字符串。

### 增加前/后缀函数：addprefix/addsuffix
```makefile
src = $(wilcard *.c)
dsrc = $(addprefix d/, $(src))
```
`addprefix`会为参数中所有**字串**都加上前缀

### 过滤字符串函数：filter/filter-out
```makefile
src = main.c main.h resource.r
src = $(filter %.c %.r, $(src))
other = $(filter-out %.r, $(src))
```
`filter`表示过滤出模式匹配的作为结果。
`filter`表示**过滤掉（去除掉）**模式匹配的结果后，将剩下的作为结果返回

### 字符串替换函数：patsubst
```makefile
src = $(wildcard *.c)
objs = $(patsubst *.c, *.o, $(src))
```
这里表示将前一个匹配的模式替换为后一个模式，这里替换了后缀名。

### 替换后缀：：
除了使用`patsubst`函数，冒号语法可以更简单的替换后缀。
```makefile
src = $(wildcard *.c)
objs = $(src:.c=.o)
```
注意src后不能有空格

### 空格去除函数：strip
如题去除多余的空格
```makefile
src = main.c      k.c
src := $(strip $(src))
```

## || 条件语法
条件语法`ifdef`、`ifndef`、`ifeq`、`ifneq`是被立即分析的，在所有操作之前。
```makefile
foo = kk

ifdef foo
	foo = defined
endif

ifndef foo
	foo = ndefined
endif

ifeq "a" $foo
	a = foo
endif

ifneq "a" "b"
	a = foo
endif
```

# 头文件依赖

对于C源文件来说，其依赖的头文件是复杂的且多变的。
但我们上面介绍的规则都只是依赖于`.c`的源文件的，如果头文件变化是无法检测到的。
并且由于头文件依赖的复杂多变，是无法通过makefile提供的通配符函数或者模式规则来定义每个源文件的头文件依赖的，所以需要使用其他工具来单独处理头文件依赖。
庆幸的是，`gcc`程序提供了解析源文件依赖头文件的功能。

> 这里介绍生成头文件依赖的基本原理，之后通过一个实例来说明在实际项目中使用

## || gcc生成头文件依赖规则
```sh
gcc -E -MM main.c
# output
main.o: main.c main.h
```
`-E`参数告诉gcc只进行预处理不需要编译
`-MM`参数告诉gcc只显示用户自定义的依赖
`-M`则包含所有的依赖，包含系统头文件
> 注意到这里生成的输出类似于makefile中规则的定义格式

## || 包含指令
使用gcc生成的依赖需要先保存到一个文件中才方便make使用。
```sh
gcc -E -MM main.c > main.dep
```
然后在makefile中使用`include`指令包含该文件
```makefile
-include main.dep
```
在`include`前添加`-`表示忽略`include`的报错，如不存在dep文件，或对应生成dep规则出错。
`include`在包含文件时若发现了包含文件的生成规则，则要自动检查和调用该规则自动生成对应的最新文件。
> include指令在规则执行之前就会执行
> 主要到gcc生成的输出就可以作为规则的定义，故只需要包含就自动定义了该规则
> 而之后我们再定义同名目标时，两个规则会自动合并依赖的（具体见下文的示例）

# makefile使用实例

简单C语言程序清单
* main.c，主函数入口，包含print.h
* print.c，print模块，重新封装printf
* print.h
* bin/ 可执行文件目录
* dep/ 头文件依赖目录
* objs/ obj文件目录

**print.h**
```c
#include <stdio.h>

int print(char* p);
```
**print.c**
```c
#include "print.h"

int print(char* p){
	return printf(p);
}
```

**main.c**
```c
#include "print.h"

int main(){
	print("Hello Make!!!");
	return 0;
}
```
** makefile **
```sh
make init  # 建立目标目录
make build
```
```makefile
exe		:= main
objs_dir:= objs
deps_dir:= deps
bin_dir := bin
srcs 	:= $(wildcard *.c)
objs 	:= $(srcs:.c=.o)
objs	:= $(addprefix $(objs_dir)/, $(objs))
deps	:= $(srcs:.c=.dep)
deps	:= $(addprefix $(deps_dir)/, $(deps))
cc		:= gcc
.PHONY: build clean init


# build
build: $(bin_dir)/$(exe)
init:
	test -d $(bin_dir) || mkdir $(bin_dir)
	test -d $(objs_dir) || mkdir $(objs_dir)
	test -d $(deps_dir) || mkdir $(deps_dir)

$(bin_dir)/$(exe): $(objs) 
	$(cc) -o $@ $(objs)

$(objs_dir)/%.o: %.c 
	$(cc) -c $< -o $@ 

# mkdir
$(objs_dir) $(bin_dir) $(deps_dir):
	mkdir $@

# head file deps
-include $(deps)

$(deps_dir)/%.dep: %.c
	$(cc) -E -MM $< > tmp
	echo -e "$(objs_dir)/\c"|cat - tmp > $@

clean:
	rm $(bin_dir)/$(exe) $(objs) $(deps) tmp

```
> 这里采用`init`假目标先建立目录
> 必须使用`-include`，因为其在任何规则执行前执行，自然包括`init`。此时`deps`目录尚未建立会报错，所以需要忽略。

**切忌把目录放在依赖中**，这样会比较目录依赖和目标的时间戳，导致莫名的重新生成。如下
```makefile
$(objs_dir)/%.o: %.c $(objs_dir)
	$(cc) -c $< -o $@
```
这样固然可以让`$(objs_dir)`目标自动生成（`deps_dir`和`bin_dir`同理，可省去`init`操作）。
但是不同的`*.o`生成的时间极有可能不同（有先后顺序），故后生成的`.o`文件会更新目录的时间戳，导致下次执行make时，先生成的`.o`会被认为需要重新生成（因为此时的目录时间戳被后生成的`.o`文件更新了）。
