---
title: "Neo4j 简介"
date: 2024-03-01T19:20:59+08:00
topics: "database"
draft: true
---

# Neo4j简介

Neo4j是原生图数据库，由上到最底层的存储均是直接存储的图模型。其支持ACID事务、组集群、runtime failover.

> 备份、集群、容错等额外服务只在Enterprise版提供


## 为什么要使用图数据库？

```
We live in a connected world, and understanding most domains requires processing rich sets of 
connections to understand what’s really happening. Often, we find that the connections between 
items are as important as the items themselves.
```

简而言之，数据之间的关系往往更加重要。

但对于现在主流的关系型数据库，其只能通过昂贵的`JOIN`操作去查找元素之间的关系。

> `JOIN`操作的开销是非常大，往往至少都需要遍历一次整个表。


但如果数据以图的形式存储，对于关系的相关操作将会变得非常的自然、容易，如：

1. 浏览深层次关系层次结构
2. 寻找远距离元素之间的隐藏关系
3. 发现元素之间的相互关系

> 显而易见，对于传统关系型数据库要处理这些任务是很麻烦且低效的。
