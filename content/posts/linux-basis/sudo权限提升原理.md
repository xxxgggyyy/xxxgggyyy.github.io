---
title: "sudo权限提升原理"
date: 2022-06-19T15:16:48+08:00
topics: "linux-basis"
draft: true
---

# 文件权限与进程权限

众所周知，文件具有三组用户权限(rwx即读/写/执行)，每组分别对应拥有者u、组g、其他o。
除此之外文件还具有s权限，拥有s权限的二进制可执行文件，在执行时具有该文件所有者的权限，而不是执行者的。
由此可知，进程必须要能区分出，执行者和有效权限者，所以进程其实具有两个用户ID权限。

名称|含义&权限
:-:|:--
ruid|真实用户id，即执行者的uid
euid|有效用户id，即该进程实际拥有的权限id。非s权限的可执行文件的euid一般等于ruid。

> 进程的权限用户id，就是用户的id。
> 具有该id，即表示具有该用户的权限。
> `chmod +s file`添加s权限。s权限好像与ugo无关，只有具有s即可。
> 注意shell脚本即使添加了s权限也是无用的，因为脚本是使用shell子进程执行的。而不是直接执行脚本本身。

# sudo权限提升原理

sudo本身是一个拥有s权限的可执行的二进制文件，而sudo的拥有者是root，所以就算其他用户通过sudo执行命令，即具有root权限。

> sudo自身会验证配置文件，并在必要的时候要求用户输入密码，来保证权限提升不会被滥用。