---
title: "ArangoDB简介"
date: 2024-05-05T14:20:59+08:00
topics: "database"
draft: true
summary: "ArangoDB基础概念、分布式架构简析"
---

# ArangoDB

本文参考自[ArangoDB v3.12文档](https://docs.arangodb.com/stable/about-arangodb/)

共分三个部分：

1. ArangoDB中组织用户数据的基础数据结构（概念）
2. 基于基础数据结构的三种数据模型：KV、Graph、Document
3. ArangoDB分布式集群架构

## Data Structure

ArangoDB中将图和文档数据均存储为类Json对象。

其存储层次有三层，从低到高为：

1. Documents
2. Collections
3. Database

Documents存储在Collections中，Collections存储在Database中。

> 类比关系型数据库就是：记录、表、数据库

### Documents

ArangoDB中一条记录也叫做Document，其对应一个Json对象。

```json
{
  "name": "ArangoDB",
  "tags": ["graph", "database", "NoSQL"],
  "scalable": true,
  "company": {
    "name": "ArangoDB Inc.",
    "founded": 2015
  }
}
```

这意味着，每个Collections是Schemaless的，每条记录都一个拥有自己的Schema。

但可以为Collections设置Schema validation。

Document在ArangoDB内部存储为二进制格式-VelocyPack

> VelocyPack是自包含的、紧凑的、可直接访问成员的（不用先解析）、可快速转换为Json

### Collections

Documents存在Collections中，可以在Collections上为Document建立索引。

三种类型的Collections：

1. `document collection`即普通的Collections，在图模型中也被称为`vertex collection`
2. `edge collection`，用于图模型中存储边，其中的Document具有`_from`和`_to`属性用来指向顶点Document
3. `system collection`，以下划线开头的是系统Collections，既可以是`document collection`也可以是`edge collection`

在创建Collections时可指定其类型。

在分布式场景下，可在Collection-Level上进行分片（shard），并可指定每个Shard的副本数量。

*事务一致性*


### Database

每个Collections都是Database的一部分，`_system`Database是系统数据。

## Data Models

AQL统一

## Cluster
