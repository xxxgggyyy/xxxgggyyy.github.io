---
title: "os"
date: 2024-03-01T19:20:59+08:00
topics: "cs-basis"
draft: true
---

# 操作系统基础

## 虚拟内存与分段、分页

多道程序的兴起，早期的物理内存使用方式具有一些问题：

> 即直接将整个程序直接加载物理内存中

1. 进程地址空间不隔离。

    直接使用物理地址，可以直接访问到对方的内容。

2. 对于内存的利用太低效了。

    局部性原理的存在，导致其实际不需要使用那么多内存。外部碎片无法利用，而原始换入换出需要太多的数据交换。

3. 程序每次装载地址不确定。

    这为程序编写带来一定的麻烦，需要重定位去解决。

增加中间层 - 即虚拟地址，是解决这几个问题的主要思路。

虚拟地址保证了进程地址空间的隔离，此时也可以在相同的虚拟地址开始编址。

此时剩下的主要问题就是该如何将虚拟地址映射到物理地址上，也就是分段和分页这两种内存映射方案。

最开始使用的方案是分段，即可以把进程（虚拟地址空间）分段，每一段映射到一段物理内存，这可以通过段表来完成。

分段可以一定程度的解决问题2，也方便共享和权限管理，但粒度还是太粗了：

1. 换入换出效率还是不高
2. 局部性原理也没有很好的利用
3. 还是存在外部碎片
4. 空间增长也不是很方便。（特别是超过了段的最大长度时）

所有又引入了分页管理机制，先把内存按页划分好，直接按页离散映射，直接杜绝了外部碎片。其次可以只加载一部分的页到内存中，特别是在用上缺页处理机制，这使得内存利用率显著提高，完美解决了问题2.

对于单级页表过大，引入多级页表。
