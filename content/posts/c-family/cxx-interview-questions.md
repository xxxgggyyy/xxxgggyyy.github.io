---
title: "Cxx Interview Questions"
date: 2024-03-06T09:48:16+08:00
draft: true
summary: "C/Cxx常见面试问题"
---

## `new`与`malloc()`的区别

首先都是用来做堆内存分配的，但一个是C++提供的运算符一个是C标准库中提供的库函数。

就内存分配而言其实没有太多不同，甚至默认new的分配操作就是去调用`malloc`而已。

但`new`毕竟是C++提供的运算符，还具有其他的语义：

1. 自动计算需要分配的内存大小
2. 自动调用构造函数

这些特性由编译器实现。
