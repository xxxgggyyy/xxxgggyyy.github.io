---
title: "nvm inner"
date: 2023-03-16T22:40:44+08:00
topics: "misc"
draft: true
---

# UVM原理


# 内存迁移API

CUDA驱动API和运行时API（cuda c）
驱动API是一种低级API，它相对来说较难编程，但是它对于在GPU设备使用上提供了
更多的控制。运行时API是一个高级API，它在驱动API的上层实现。每个运行时API函数
都被分解为更多传给驱动API的基本运算
这两种API是相互排斥的，你必须使用两者之一，从两者中混合函数调用是不可能
的。
 # unified-memory-in-cuda-6
 > <https://developer.nvidia.com/blog/unified-memory-in-cuda-6/>

 尽管有UVM，但cuda runtime不可能有开发者那么清除什么时候该迁移数据。可以适当的调用`cudaMecpyAsync`高效的重叠执行和数据迁移已提高性能。

UVA & UVM

UVA enables “Zero-Copy” memory, which is pinned host memory accessible by device code directly, over PCI-Express, without a memcpy

zero-copy仅仅利用PCIe访问数据，并非像UVM一样会自动迁移数据，由于PCIe很慢所以性能很低。

要提供UVM页面级别的迁移，需要cuda runtime、driver，even OS kernel支持

# CUDA C Programming
计算能力低于6.x的设备无法分配比显存的物理大小更多的托管内存。具有计算能力6.x的设备扩展了寻址模式以支持49位虚拟寻址。它的大小足以覆盖现代CPU的48位虚拟地址空间，以及GPU显存。巨大的虚拟地址空间和页面错误功能使应用程序能够访问整个系统虚拟内存，而不受任何一个处理器的物理内存大小的限制。
