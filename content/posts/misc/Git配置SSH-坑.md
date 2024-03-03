---
title: "Git配置SSH 坑"
date: 2022-10-04T11:38:07+08:00
topics: "misc"
draft: true
---

## Git配置SSH

使用`ssh-keygen`生成公私钥，然后公钥放`github`或者`gitee`就完了

## 大坑

`gitee`的公钥配置分为`个人公钥`和`部署公钥`，部署公钥是只读的只能拉取

`git`命令没法指定私钥的位置，只能使用默认的`~/id_rsa`（名字都不能改）
> 也可能是我没找到指定的方法
