---
title: "tee与重定向"
date: 2023-11-10T14:30:55+08:00
topics: "linux-basis"
draft: true
---

# tee

这里主要谈通过管道使用tee，如下：

```sh
./some_prg | tee a_file
```

>> 其中`some_prg`有可能是个脚本。

这里tee使用的是管道，那么只有在管道对端都关闭时才会产生EOF终止tee

# 问题描述

```sh
make 2>&1 | tee a_tmp_file

# 其中Makefile规则如下

main:
    @./run_server.sh 2>&1 1>/dev/null &
```

这里的怪异之处在于，执行`make 2>&1|tee a_tmp_file`和预期不符，这条命令会一致卡到`./run_server`这个后台程序程序结束才返回。

解决方案也很简单，Makefile中的规则中的重定向调换顺序：

```makefile
main:
    @./run_server.sh 1>/dev/null 2>&1 &
```

关于重定向原理的猜测，在执行`2>&1`时，很可能只是把fd为2的数组元素指向了fd为1的。那么这样一来，上面错误的用法，将会导致fd2->stdout, fd1->a_tmp_file，而由于外面使用了tee，所以这个stdout应该就是tee的写端，故导致tee不能释放。

而正确的用法下，fd1->a_tmp_file, fd2->a_tmp_file，不在引用tee的管道。
