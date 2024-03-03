---
title: "nvidia显卡驱动造成的混乱"
date: 2023-05-16T15:41:18+08:00
topics: "misc"
draft: true
---

## 环境信息

-|version
:-:|:-:
OS|Ubuntu22.04
显卡|Nvidai MX 250
GCC|11
opend-jdk|11

## Chaos

为了偷懒直接使用`sudo apt instlal nvidia-cuda-toolkits`安装cuda的开发套件，但是用nvcc编译的时候出现了一些问题：

```
/usr/include/c++/11/bits/std_function.h:435:145: error: parameter packs not expanded with ‘...’:
  435 |         function(_Functor&& __f)
      |                                                                                                                                                 ^
/usr/include/c++/11/bits/std_function.h:435:145: note:         ‘_ArgTypes’
/usr/include/c++/11/bits/std_function.h:530:146: error: parameter packs not expanded with ‘...’:
  530 |         operator=(_Functor&& __f)
      |                                                                                                                                                  ^
/usr/include/c++/11/bits/std_function.h:530:146: note:         ‘_ArgTypes’
```
> 这不是c++标准版本的问题

在网上一顿找后，找到一个解决方案，说是CUDA的toolkit版本问题，需要从11.5升级到11.6，恰好我安装的就是11.5。所以我选择重装toolkit，然后2天就折腾没了。

## || Chaos1 内核混乱

根据官网的安装指令，发现要安装CUDA12.1需要把驱动更新到530

所以直接使用ubuntu自带的`update software`安装`additional driver`，但是安装失败了，直接原因是我的代理节点不稳点，安装到最后的时候突然失败了。

但最搞的是，他更新了内核，而且不知道是不是只更新了一半还是咋的，新内核里面wifi、鼠标、键盘得驱动都掉了。so，不得不把新内核卸载掉。

> ubuntu下卸载内核可以参考[这里](https://www.cnblogs.com/carle-09/p/11363020.html)

完了还需要把安装到一半的530相关的包全部卸载掉。

后来不死心又用`sudo apt install nvidia-driver-530`这次安装成功了，但是系统彻底启动不了了。so，所以又得重来一遍删除新内核、删除530

最后无赖之下换成525驱动。

## || Chaos2 jdk混乱

所以现在也没法装12.1的toolkit了，故选择安装12.0.

按照官方流程，此时安装成功了，nvcc也可以正常编译了。但是nvvp跑不了，报了个啥java得反射错误，我也不常用java，又是上网一顿搜索，发现可能是java版本问题。

好家伙，一看open-jdk转了三个版本，8、11、17都装上。最后一个个试，发现jdk-8才能正常打开nvvp。所以使用`update-alternatives`将java更新成8的

## || Chaos3 libstdc++错误

> 真是好家伙，都装了有一两天了，还搁着恶心我

这两天学llvm，装了clang，用clang++编译的时候，死活找不到C++的标准头文件，我还以为是标准版本的问题，结果`<iostream>`都找不到。

又是网上一顿找，使用`clang -v`查看编译输出，终于找到问题了。原来装nvidia的toolkit的时候它偷摸给我装了gcc-12但是tm的没装g++12，导致clang选择标准C++头文件的时候总是选择12的，但12对应的c++库有没有安装
