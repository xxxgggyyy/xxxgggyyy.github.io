---
title: "Resume Notes"
date: 2024-03-02T21:06:07+08:00
topics: "algorithms-and-data-structures"
draft: false
tags: ["leetcode"]
summary: "简历注释"
---

# 简历注释

## 项目&竞赛分析

### OB-Bootstrap启动优化

#### 介绍

#### 问题

### MiniOB功能实现

#### 介绍

#### 问题

### 分布式一致性KV

#### 介绍

#### 问题

* 一致性怎么实现的？

一个假设：Client发完一个，服务返回成功后，才发送下一个。失败，则重新找Leader，发送请求，直到成功。

故在该简单假设下，只需为每个Client以及每个请求分配一个Id，

然后在服务端保存当前执行完成的请求的Id，以及执行结果，并将该信息同样利用Raft同步即可实现线性一致性。

* 读优化？

Read Index(避免同步日志那些操作，但是任然要经过一次心跳的RTT)

Lease Read(心跳更新确认自己是leader，则维护租约一直到now+elect_timeout, 但每台机器的时钟速度必须一致)

类似Zookeeper的减弱一致性，去实现从副本读。

### 分布式图存储引擎

#### 介绍

#### 问题

### 基于计算机视觉的交通场景应用

#### 介绍

#### 问题

## 专业技能若干

待续
