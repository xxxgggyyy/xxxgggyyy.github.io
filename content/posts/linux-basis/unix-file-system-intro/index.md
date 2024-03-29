---
title: "UNIX文件系统操作"
date: 2022-06-19T15:16:48+08:00
topics: "linux-basis"
series: ["unix-unbounded"]
series_order: 2
summary: "UNIX文件系统基本原理与简单使用"
tags: ["linux"]
---

# UNIX文件系统简介

## || 文件系统基本原理

UNIX文件系统采用索引节点（i节点）的方式实现。目录文件中仅包含文件名和i节点序号等基本信息，而i节点本身才包含文件存储物理位置、权限、时间戳等具体信息。
UNIX的i节点采用混合索引的方式，在缩影节点中包含10个直接地址项、1个一级简介地址项、1个二级简介地址项、1个三级间接地址项。

## || 文件系统安全

每个文件和目录都拥有3组9位访问控制位实现文件保护，分别是拥有者权限位、同组用户权限位、其他用户权限位，每一组都包含`rwx`3位分别控制该对象是否拥有读、写、执行的权限。
目录文件具有`x`权限表示可以使用`cd`进入该目录或使用该目录作为路劲名的一部分。

> 使用`chmod`可改变保护位，见下文
> 文件还有`s`权限，具体见`sudo权限提升原理`文档

## || 挂载文件系统
```sh
mount [opts] source dir
```

```sh
# 卸载文件系统
umount [opts] dir
```
此时属于临时挂载，需要开机自动挂载需要编辑`/etc/fstab`文件。
添加一行内容：
设备|挂载点|文件系统类型|挂载参数|是否备份|是否检测
:-:|:-:|:-:|:-:|:-:|:-:
/dev/sdb1|/mnt/newd|linux|defaults|0|0

执行`mount -a`可让文件立即生效。

# UNIX文件

## || UNIX文件简介

在UNIX中，文件就是字节序列，文件系统本身不支持带有结构的文件，这些是具体应用程序需要做的。

### UNIX文件类型
* 普通文件
* 目录文件
* 特殊文件，如系统中的设备均抽象为文件

### 隐藏文件
文件以`.`开头的为隐藏文件。
每个目录中都至少包含`.`当前目录和`..`上级目录

## || 文件操作

> 这里只显示最简单的用法和参数，具体使用`--help`参数或者`man`命令
### 创建&编辑文件
UNIX中创建文件的方式有多种如下，
1. `touch file`创建空文件，一般`touch`用于更新时间戳，故只在文件不存在时创建目录
2. `vim file`
3. `cat > file`，利用重定向和`cat`创建小文件（见下文）
编辑文件可使用`vim`、`emacs`等编辑器

### 复制/移动/删除文件：cp/mv/rm
**cp复制文件**
```sh
cp [option]... source dest
cp [option]... source... dir
```
选项|含义
:-:|:--
-b|若目标文件已存在，则创建备份
-i|若目标文件已存在，要求确认
-f|文件存在，不提示直接覆盖
-r|递归拷贝所有子目录和子文件

**mv移动文件**
```sh
mv [option]... source dest
mv [option]... source... dir
```
选项|含义
:-:|:--
-b|若目标文件已存在，则创建备份
-i|若目标文件已存在，要求确认
-f|若目标文件存在，不用确认直接覆盖
-r|递归移动所有子目录和子文件

> `mv`命令可用作文件重命名

**rm删除文件**

```sh
rm [option]... file...
```
选项|含义
:-:|:--
-i|删除是要求确认
-f|直接删除，忽略不存在文件，不提示
-r|递归删除目录

`rm`删除的文件不可恢复，需要谨慎使用
替代方案是将`rm`定义为`mv`的别名覆盖掉`rm`，如下
```sh
alias rrm="/usr/bin/rm"
alias srm=trash
alias rm=trash

trash(){
	mv $@ $HOME/.trash/	
}
```
### 显示文件：cat/head/tail
**cat(concatenate)拼接多个文件**
`cat`拼接多个文件（以及标准输入），并将结果输出到标准输出（所有文件内容）。
```sh
cat [option]... file...
```
无参`cat`从标准输入读取输入直到`eof`（Ctrl+D），输出到标准输出。故可以结合重定向使用`cat`创建小文件。
另外若要连接文件和标准输入，`cat file -`其中`-`表示从标准输入读取。

**head显示前多少项**
```sh
head [option]... file...
```
同样`-`以及无参表示从标准输入中读取。
选项|含义
:-:|:--
-n|`-n 10`即显示前10行，也可用`-10`替代，`-n -10`显示全部除了最后10行
-c|`-c 10`显示前10个字节

**tail显示后多少项**
```sh
tail [option]... file...
```
同样`-`以及无参表示从标准输入中读取。
选项|含义
:-:|:--
-n|`-n 10`即显示后10行，也可用`-10`替代，`-n +10`表示从第10行开始到文件尾
-c|`-c 10`显示后10个字节

### 分页显示文件：less/more

`less`和`more`指令都可以分页显示文件，特别对于查看大文件方便。
`more`只能往前查看，不能再倒回去
`less`可以向前后查看，操作方法类似`vim`

### 链接文件：ln
```sh
ln [option]... target link_name
```
创建名为link_name的对target的硬连接。
`-s`选项指定创建软连接。

> 硬连接则表示再link_name的目录项中直接插入名为linke_name的项，然后设置其i节点序号为target的
> 软连接则是创建名为link_name的链接文件，然后在该文件中存储traget的目录路径

### 按域显示文件：cut
```sh
cut -f 1-3 file
```
表示显示file的第1到3列的内容
选项|含义
:-:|:--
-f|指定显示的域`-f 1`、`-f 1,7`、`-f 1-7`
-c|指定字符位置
-d|指定域分隔符（默认为空格制表符）

### 按行链接文件：paste
```sh
paste [opt]... file...
```
所有输入的文件的的行，拼接成新行，分隔符通过`-d`指定默认为制表符。
### 文件内容计数：wc
```sh
wc -wlc test.c
# 12  18 180 test.c
```
选项|含义
:-:|:--
-w|统计单词数量
-c|统计字节数量
-l|统计行数
-m|统计字符数量

### 修改文件模式：chmod/chown/chgrp
**chmod修改文件保护位**
```sh
chmod u+x file	# 拥有者增加执行权限
chmod g+rw file	# 组增加读写权限
chmod o+w file	# 其他用户增加写权限
chmod o-r file	# 其他用户减少读权限
chmod a+w file	# 全部（三组）都增加写权限
chmod a=rwx file# 全部都设为rwx
chmod +s file	# 增加s权限

# 也可以采用八进制的方式
# 例如 u(rwx) g(r-x) o(r-x)
# 即u(111) g(101) o(101)
# 即u(7) g(5) o(5)
chmod 755 file
```
**chown修改拥有者**
```sh
# 修改拥有者为root，当然需要root权限
chown root file
```
**chgrp修改所属组**
```sh
# 修改组为root，当然需要root权限
chgrp root file
```
### 查找文件位置：find
```sh
find start_dir <opt>
```
选项|含义
:-:|:--
-name filename|根据指定文件名查找，filename可以使用通配符，含义和文件名替换类似，需要使用引号括起来避免被替换。
-size +-n|指定查找文件大小（块），`-size +10`表示大于10块的，`-10`表示小于10块的
-type ft|指定查找文件类型，ft可以为b块设备文件、c字符设备文件、d目录文件、f普通文件
-atime +-n|指定访问时间（天），同样可给出`+-`表示范围
-mtime +-n|指定修改时间（天），同样可给出`+-`表示范围
-newer filename|比filename更新的文件
-print|找到文件后打印文件路径（默认）
-exec cmd \;|找到（每个）文件后执行cmd
-ok cmd \;|找到（每个）文件后先询问，再执行cmd

### 查找文件内容：grep
该命令在文件中查找指定模式，找到则显示整行。
```sh
grep [option]... patterns [file]...
```
同样但不指定文件时从标准输入中读取内容并查找。
选项|含义
:-:|:--
-c|显示每个文件中匹配的行数
-i|匹配时忽略大小写
-l|只显示含有匹配模式的文件名，而不显示具体的匹配行
-n|每个输出行前显示行号
-v|显示与模式不匹配的行

### 文件归档&压缩
压缩和归档是两会事情。
`tar`指令可将多个文档归档（解开）为一个文件，此时并未进行压缩，只是为压缩提供了条件（因为有些压缩算法只支持对单个文件压缩如gzip）。
> `tar`为了方便使用也提供了参数，在归档完成后可以立即进行压缩

```sh
tar -cvf archive.tar file1 file2 dir
tar -xvf archive.tar -C dest_dir
# 对应加解档参数前添加需要的压缩算法参数即可
tar -zcf archive.tar.gz file1 file
tar -zxf archive.tar.gz
```
**tar部分参数**
选项|含义
:-:|:--
-c|创建归档
-f|指定归档文件
-r|增加文件到归档文件
-t|列出归档中的文件
-x|解开归档文件
-v|verbose显示详细创建/解档过程
-z|归档后用gzip算法压缩
-j|归档后用bzip2算法压缩

## || 文件名替换
使用shell元字符`*`、`[]`、`?`替换
> 见**shell基础&编程**文档中元字符一节

## || shell重定向
使用`>`、`>>`、`<`、`<<`重定向输入输出到文件
> 见**shell基础&编程**文档中I/O重定向一节

# UNIX目录

## || 目录相关概念

### UNIX重要目录

目录|说明
:-:|:--
/|根目录
/usr|面向用户的目录
/usr/bin/面向用户的可执行文件
/usr/sbin/系统管理文件
/bin|存放基本UNIX程序
/dev|存放设备文件
/sbin|存放系统文件，通常由UNIX自行运行
/etc|存放配置文件

### 用户主目录
每个用户都有一个自己的主目录

### 当前工作目录
shell当前工作的目录，可提供给相对路径使用。
`pwd`print work dir可打印当前的工作目录
`cd dir`切换工作目录到`dir`

### 绝对路径与相对路径
`/`开头的为绝对路径。
相对路径是为了用户使用方便以及减少目录的查询时间，即从当前的工作目录开始查找。

## || 目录操作

### 创建目录：mkdir
```
mkdir -p /usr/home/xui/new_dir
```
`-p`参数表示不存在的父目录也一同创建。
### 列出目录项：ls
选项|说明
:-:|:--
-a|列出全部，包括隐藏
-C|用多列格式列出，按**列**排序
-F|目录后加/，可执行文件后加\*
-l|长格式显示，即显示文件详细信息
-m|按页宽显示，用逗号隔开
-p|目录后加/
-r|字母反序排列
-R|递归列出子目录
-s|以块为单位
-x|以多列格式列出，以**行**排序
-h|人类可读的单位

### 删除空目录：rmdir
```
rmdir dir
```
>若dir不为空需要使用`rm`删除

