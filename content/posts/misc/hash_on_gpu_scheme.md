---
title: "hash on gpu scheme"
date: 2023-03-05T14:21:55+08:00
topics: "misc"
draft: true
---

# 在GPU上部署hash表

基础要求：

- GPU的显存无法容纳整个hash表

## || 基础部署方案

初步考虑是只用使用CUDA提供的`UVM`直接就可将哈希表放置在主机内存。在核函数中访问该hash表时，由CUDA负责进行相关的内存页面的迁移。

可能存在的问题：

- PCIe总线速度太慢
- 内存以页面为单位的迁移粒度太大

参考：

* Awad, Muhammad A., et al. "Better GPU Hash Tables." arXiv preprint arXiv:2108.07232 (2021).

多GPUhash

## || 哈希表优化

> 可针对使用不同散列函数和冲突解决方案的哈希表进行特定与GPU的性能优化

参考：
- Lessley, Brenton, and Hank Childs. "Data-parallel hashing techniques for GPU architectures." IEEE Transactions on Parallel and Distributed Systems 31.1 (2019): 237-250.

## || GPU底层优化

> 在不改变已有hash结构的基础上，将其运行在GPU上

参考：
- Barlas, Gerassimos. Multicore and GPU Programming: An integrated approach. Elsevier, 2014.
