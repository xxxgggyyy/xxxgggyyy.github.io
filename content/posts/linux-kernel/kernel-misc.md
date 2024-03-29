---
title: "kernel misc"
date: 2023-08-14T10:18:51+08:00
topics: "linux-kernel"
draft: true
---

# likely & unlikely

这两个宏生效的原理在于平台的分支预测。如：

```cpp
void func(int i)
{
    if(likely(i > 8))
    {
        ...
    }else{
        ...
    }
}
```

就x86而言，若其遇到的是无条件跳转，则此时流水线自动从跳转目标位置开始。若遇到的是条件跳转，此时x86采用一种简单的策略，如果条件跳转指令向后跳转则预测其不会跳转，
流水线继续从跳转指令下一条开始发射，而该条件跳转向前跳则预测其会跳转(可以考虑for循环，循环向前条一般都对的，除了最后一次)，流水线从跳转目标继续发射。

对于上述if语句，其对应的一般汇编格式为：

```asm
jle/jg ....
one-statement
ret
two-statement
```

故根据x86的分支预测规则，`jle/jb`都是向后跳转，故只需要将小概率的if执行体放在two-statement的位置即可，可以通过jle/jg的转换来合理的放置位置。

# initrd 

关于使用RAMDISK进行的原因或者说好处：

1. 将linux内核与其他的必要启动工具分开，保证内核的干净
3. linux启动需要的驱动和工具是多种多样的，依赖于机器具体有哪些设备以及设备类型。我们当然可以将这些编译到内核，但会污染内核（不够纯粹，每次都要重新编译），而且涉及的驱动类型太多显然没法全部编译到内核中，不然内核就太大了。
2. linux启动的必要驱动和工具无法放在文件系统里(文件系统在启动时都还没挂载，要挂载可能有需要这些工具，鸡生蛋蛋生鸡)，又不想污染内核，所以单独抽出来
3. 硬件限制，BIOS本身能够读取的磁盘范围有限。所以内核也不能太大

