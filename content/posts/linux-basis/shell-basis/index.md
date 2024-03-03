---
title: "shell基础"
date: 2022-06-19T15:16:48+08:00
topics: "linux-basis"
series: ["unix-unbounded"]
series_order: 3
summary: "shell脚本基础语法（不全）"
---

# shell简介

shell是unix/linux中最常用的用户接口程序，通过命令行的方式提供给用户访问和修改系统的能力。
shell属于用户态程序，不具有任何特权，甚至可以自己编写一个'shell'程序。

> 常见的shell
> 
> 1. Bourne Shell（sh），这是多数UNIX中的标准和默认shell
> 2. Korn Shell（ksh），这是sh的超集
> 3. C Shell（csh），具有c语言风格的shell，完全不同于sh和ksh。属于BSD UNIX的一部分
> 4. Bourne Again Shell（bash），bash是基于sh实现的，通常是linux的标准和默认shell

# Shell基础

shell是一个标准的c/c++程序，一般位于`/bin`或者`/usr/bin`下。用户登录后，自动启动shell。

> shell的基本功能（特征）
> 
> * 命令执行
> * 文件名替换
> * I/O重定向
> * 管道
> * 环境控制
> * 后台处理
> * shell脚本

## || Shell命令基本格式

```
$ cmd [-opts] [args]
```

shell会忽略多余的不可见字符。
shell中的命令实际有两种，shell的内部命令和可执行文件。可通过`type cmd`命令查看cmd命令是内建命令还是可执行文件。

> `[]`表示可选
> UNIX中区分大小写，且只接受小写的`cmd`

## || I/O重定向

在命令的最后使用`<`、`<<`、`>`、`>>`可实现将标准输出（`> file_name`）重定向到文件，将文件重定向到标准输入（`< file_name`)

> `>`表示输出覆盖，`>>`表示追加
> `<< str`表示仍然从标准输入读取数据，但当读取到str时结束
> 重定向的功能非常强大，因为很多程序都提供了从标准输入读取参数数据和将结果输出到标准输出的功能，比如cat、tail、head等等

在linux中一切的设备其实都是特殊的文件，对于标准输入设备（键盘）和标准输出设备（显示器）也是同理。所以其实标准输入和输出都是打开的文件，通过文件描述符表示。
描述符|文件|设备
:-:|:-:|:-:
0|stdin|键盘
1|stdout|显示器
2|stderr|显示器

所以上面直接使用`<`，`>`其实是对`0<`，`1>`的缩写。

> stderr和stdout是分开的，`>`只会重定向stdout，stderr仍显示在屏幕上不会定向到文件。
> 可以使用`2>&1`将stderr也定向到stdout，然后再使用`>`即可把stderr也定向到文件。因为`2>1`表示将stderr定向到文件1，所以必须要添加一个`&`

## || Shell变量

shell变量可分为shell标准变量和用户定义变量（局部变量）。标准变量拥有系统可知的名称，用来控制用户的环境信息，所以也叫环境变量（环境变量有一点歧义，统一成为标准变量）。
`set`命令可列出当前的所有变量，`unset`命令可删除不需要的变量。
用户可使用`var_name=value`定义变量，在需要使用变量时，可使用`$var_name`。
不管给出的value是字符还是数字，**都会被看作是字符串**。

> 变量定义时，等号两边不能有空格。

使用`export var_name`可导出变量，此时在所有的子shell进程（多重子shell）中都能访问到该变量。
`export`命令列出当前的所有导出变量。

### 变量替换

| 变量选项        | 含义                           |
|:-----------:|:---------------------------- |
| $var        | 变量的值                         |
| ${var}      | 变量的值。在字符串中使用时，{}可区分出变量名      |
| ${var:-str} | 变量不空为变量值，空为str               |
| ${var:+str} | 和-str相反，var不空为str，空为空        |
| ${var:=str} | 和-str类似，var空为str，但会将var设为str |
| ${var:?str} | 和-str类似，var空为str，但会直接退出      |

### 常见标准变量

| 变量名      | 含义                                                         |
|:--------:|:---------------------------------------------------------- |
| HOME     | 用户主目录，多个命令均使用该变量定位主目录，如无参cd进入主目录                           |
| IFS      | 内部域分隔符，解释为命令行元素分隔符。（bash中实测无效IFS=":"无效，倒是read的确使用IFS分割）    |
| PATH     | shell查找命令（可执行文件）的目录以`:`分隔。如`PATH=:/bin:/`，首字符`:`表示`.:`当前目录 |
| PS1      | 命令提示符1，sh中为`$`。PS1支持特殊字符自动替换，如`\u`替换为用户名，`\t`为当前时间等。       |
| PS2      | 未输入完整命令按下Enter后的提示符，默认未`>`                                 |
| CDPATH   | cd查找参数的目录，一般未定义CDPATH则在当前目录找                               |
| PWD      | 当前工作目录                                                     |
| SEHLL    | 当前shell可执行文件的位置                                            |
| TERM     | 终端类型                                                       |
| TZ       | 用户时区                                                       |
| HISTSIZE | 历史命令最大数量                                                   |
| TMOUT    | 用户不输入命令时，超过该时间则自动退出该用户                                     |
| VISUAL   | 某些命令使用的编辑器                                                 |
| EDITOR   | 类似VISUAL，某些命令使用其指定的编辑器                                     |

### PS1变量支持的特殊字符

| 字符   | 含义           |
|:----:|:------------ |
| \\\! | 命令序号         |
| \\\$ | 根目录显示#，非根显示$ |
| \\d  | 当前日期         |
| \\s  | 当前shell名称    |
| \\t  | 当前时间         |
| \\u  | 当前用户名        |
| \\h  | 主机名          |
| \\W  | 当前目录         |

## || 元字符

元字符既对shell有特殊含义的字符，可以用来实现文件名替换、管道、后台执行、变量引用、命令替换、命令序列等功能。

### 文件名替换

通过在命令的参数上使用`*`，`?`，`[]`，shell会根据输入参数和元字符自动匹配目录下的文件，并在执行该命令时将参数展开为所有匹配到的文件序列（以空格隔开）。
字符|功能
:-:|:--
?|匹配任意单个字符
\*|匹配任意个字符，可以为0个
[list]|匹配list中任意一个字符，其中list可以采用范围表示如：5-9，a-z等
[!list]|匹配不在list中的任意一个字符

> 类似正则表达式
> 不只匹配当前目录，可以给定其他目录的任意字面量前缀如`/root/*`

### 管道

`cmdA|cmdB`通过`|`将cmdA的标准输出连接到cmdB的标准输入。
管道自身其实也是一个特殊的文件。

### 执行命令（命令替换）

在命令前后使用重音符号（反引号）<code>\`</code>可以执行包裹的命令，并将命令的标准输出插入到命令所处的位置。如<code>ucount=`who|wc -l`</code>，ucount将包含当前登录的终端数量。

> bash中`$(cmd)`同重音符号含义一致

### 后台执行

在命令末尾添加`&`，命令将会被shell放在后台执行。也就是说shell会立即返回，重新开始命令提示符。后台执行的程序一般需要重定向输出，以免是屏幕显示混乱。
另外，一般当用户退出系统时，其后台进程也会被中止。可以使用`nohup`程序执行后台命令，此时将会忽略终端关闭时发出的SIGHUP信号。

```sh
nohup (sleep 10;echo ok) > nohup.out &
```

如果此时没有执行重定向的文件，则默认定向到nohup.out，毕竟此时连终端都没有了。

> bash中nohup程序并不支持命令序列和命令编组
> 可以将多条命令写成脚本后执行，`nohup sh sh_script &`

### 命令序列

通过`;`在一行将多个命令隔开，shell会按照顺序从左至右依次执行这些命令。

### 命令编组

将用`;`隔开的多条命令用`()`包裹，可以表现为单条命令，方便多条命令的同时后台执行和重定向。
`sleep 10; echo ok&`表示的是在前台执行完sleep后再在后台执行echo
`(sleep 10; echo ok)&`表示将整个命令序列都放在后台执行。

### 元字符转义

可以通过`"`、`'`、<code>\\</code> 对元字符进行转义
`"str"`，str中除`"`、`$`、<code>\`</code>外，其他字符均按照字面字符解释
`'str'`，str中除`'`外，其他字符均按字符字面含义解释
<code>\\</code> 后的任意字符按该字符字面意思解释

> `$' \t\n'`在单引号字符串前添加`$`表示将字符串立即转义，既`\t`转为制表符对应的编码而不是两个字符`\`和`t`

## || 特殊字符

UNIX支持多种终端，每种终端有自己的功能和特性，有一组特殊的字符代表了这些功能。只需要将这些字符打印到标准输出中（echo或tput）即可控制终端执行该功能。
如字符`\032`在vt100终端中表示清屏

> `\0`开头表示8进制的字符编码

系统支持的每一类终端都在终端数据库terminfo中，其是一个文本文件，包含了每个终端对应的功能列表。
任何包含terminfo数据库的系统，都包含一个`tput`实用程序。    通过`tput`可以直接打印出某个功能值，`tput`根据`TERM`标准变量得知当前终端类型，在结合terminfo即可得知某个功能的值并打印。

> 如`tput clear`可以在任意终端下清屏，而不用管该终端下的具体字符值是多少。
> 关于终端、控制台、GUI、X11等概念见[blog](https://blog.csdn.net/ZCShouCSDN/article/details/120974554)

**终端功能的简单列表**
参数|功能
:-:|:--
bel | 响铃
blink | 闪烁显示
bold | 粗体显示
clear | 清屏
cup r c | 移动光标到r行c列
dim | 显示变暗
ed | 从光标位置擦除到底部
el | 从光标位置擦除到行尾
smso | 启动凸显
rmso | 关闭凸显
smul | 启动下划线
rmul | 关闭下划线
rev | 反色显示
sgr 0 | 关闭所有属性，这是`tput blink`后关闭闪烁的唯一方式

> 还可以使用`stty`程序调整终端参数
> `stty -echo`关闭输入回显（`stty echo`打开）
> `stty eof \^D`[Ctrl+D]输入eof
> `stty sane`恢复默认设置

## || Shell选项

bash和ksh等shell提供很多的选项。要打开某个选项执行`set -o opt`，关闭某个选项`set +o opt`
如：
`set -o noclobber`禁止用户在重定向时覆盖某个已存在的文件
`set -o ignoreeof`防止[Ctrl+d]退出当前的登录的shell，[Ctrl+d]本身就表示输入eof
`set -o vi`在交互式shell中命令行编辑采用vi风格

> 此时`j`、`k`用来切换历史命令
> `v`进入`VISUAL`或`EDITOR`定义的编辑器编辑命令行

## || Shell别名

`alias new_name=cmd`命令定义命令的别名。

> `alias`命令仅在交互式shell中可用
> `alias`命令列出所有的别名

**常用alias**

```sh
alias ls="ls --color=auto"
alias echo="echo -e"
alias ll="ls -l"
alias r="fc -s" # 历史命令
alias rm=trash  # 避免误删
trash(){
    mv $@ $HOME/.trash/
}
```

## || Shell历史命令

shell会把使用过的命令保存到一个文件中，bash默认保存在主目录的`.bash_history`中，环境变量`HISTSIZE`和`HISTFILE`控制保存的命令数量和文件。

`history`命令查看历史命令列表

```shell
history 10 # 列出最近的10条命令
```

`fc`命令可用于列出、编辑、重复执行历史命令

```shell
fc -l # 同history
fc -e vim 225 # 先使用vim重新编辑序号为225的命令然后执行
fc -s # 执行最近一条命令
fc -s 225 # 执行225号命令
fc -s vim # 执行最近的以vim开头的一条指令
```

## || Shell配置文件

sh、ksh、bash中均有两类配置文件，系统配置文件（全局配置）和用户配置文件。
每次启动shell时都会读取系统配置文件，之后再读取当前登录用户主目录下的用户配置文件。

> bash的配置文件读取顺序如下：
> 
> * 交互式登录时，如直接通过终端输入账号和密码，或使用su - user_name或su -l user_name登录。此时的读取顺序`/etc/profile-->/etc/profile.d/*.sh-->~.bash_profile-->~/.bashrc-->/etc/bashrc`
> * 非交互式登录时，如使用su USERNAME或图形界面下打开的终端。此时的读取顺序为`~.bashrc-->/etc/bashrc-->/etc/profile.d/*.sh`

# Shell编程

UNIX shell提供一种解释型的命令语言，包含了许多计算机编程语言的一般特性，如顺序、循环、选择等结构。shell的程序文件一般称为shell脚本。

## || 执行脚本

1. 使用`sh script_name`命令执行

2. 将shell脚本设为可执行，然后直接使用文件名执行即可
   
   > chmod +x script_name
   > 详见UNIX文件系统操作

3. `. script_name`命令执行
   
   > 使用1和2的方式执行，shell都会产生一个shell子进程用于执行脚本
   > 使用3`.`执行，则直接使用当前的shell执行，不会产生子进程

## || shell编程基础

### 注释

shell中使用`#`作为注释开始，之后到行尾都会认为是注释

```sh
# program 3
date # comment
```

可以将`#!`开头的**特殊注释**放在脚本第一行，指定执行脚本的shell

```sh
#!/bin/bash
echo "using bash"
```

> 只有在shell脚本作为可执行文件执行直接执行时，才会根据`#!`选择执行的shell

### 变量

参见上文**|| Shell变量**节

> 可以使用变量保存命令输出
> <code>var1=\`date\`</code>
> <code>var2=\`tput clear\`</code>
> <code>s_bold=\`tput smso\`</code>
> <code>e_bold=\`tput rmso\`</code>

### 获取命令行参数

shell中通过特殊变量获取，shell脚本执行时的命令行参数
变量名|含义
:-:|:--
$0|脚本名，与命令行输入脚本一致
$1,$2...$9|第1到第9个参数，9个以上的参数将被忽略只能使用$@或$\*获取
$#|参数个数
$@|包含所有的1-9个参数
$\*|包含所有的1-9个参数
$?|上一次命令执行的返回值（结果）
\$$|执行脚本进程的PID

如果要对位置变量`$1-$9`赋值可以使用`set One Two Three`，对其依次赋值

> `exit n`表示退出当前shell，其中n就是返回值
> shell脚本的返回值是最后一条执行指令的返回值，故如果最后为`exit n`则可指定脚本返回值。

`$@`与`$*`区别在于用双引号括起来时的表现。不括起来含义相同。

```sh
for arg in "$@"
do
    echo $arg  # 将会依次打印每个参数
done

for arg in "$*"
do
    echo $arg # 循环只执行一次，一次打印全部参数
done
```

### 获取输入

使用`read`指令从输入设备中读取一行。第一个单词赋给第一个变量，第二个单词赋给第二个，如果给出的变量数量不够，则多余的全部赋给最后一个变量，如下。

```sh
read one two rest
# 假设输入为 1 2 3 4 5
# 则$one=1 $two=2 $rest=3 4 5
# read自动创建参数同名的变量
```

> `IFS`变量影响`read`对单词的划分
> 即若`IFS=:`，则输入可为`1:2:3:4`

### 简单函数

```sh
# 定义
[ function ] funname [()]
{
    action;
    [return int;]
}

# 像普通命令一样使用
funname 1 2 3 4 5
```

`retrun`可返回0-255作为函数的返回值，若无`return`则已最后一条指令执行结果为返回值。
在函数中使用特殊变量`$1-$9 $#`获取参数信息

## || 条件与测试

### 条件结构

UNIX中每条命令的执行都有返回值，UNIX通过对这个返回值测试提供了条件控制结构。

若返回值为0则为真此时执行`then`后的语句块，非0则为假则执行`else`的。

```sh
# 基础if-then结构
if cmd
then
    commands
fi

# if-then-else结构
if cmd
then
    true-commands
else
    false-commands
fi

# if-then-elif结构
if cmd
then
    true-commands
elif cmd
then
    commands
else
    commands
fi
```

### 测试指令

除一般sh命令外，shell还提供了专为条件测试使用的`test`内建命令，`test`根据参数进行比较后返回0或1。

> shell还提供了`true`，`false`的内建命令直接返回0和1

`test`提供了数值比较、字符串比较、文件测试

**数值比较**

| 比较参数 | 示例            | 含义              |
|:----:|:-------------:|:---------------:|
| -eq  | num1 -eq num2 | 数值是否相等          |
| -ne  | num1 -ne num2 | 是否不等            |
| -gt  | num1 -gt num2 | 大于，greater than |
| -ge  | num1 -ge num2 | 大于等于            |
| -lt  | num1 -lt num2 | 小于              |
| -le  | num1 -le num2 | 小于等于            |

> 纯数值比较也可以使用`let "12<13"`指令，此时是把比较表达式看作一个参数，`test`的则是表达式中所有元素均为参数（也就是均需要空格分隔）

**字符比较**

比较参数|含义
:-:|:-:
=|字符是否相等
!=|是否不等
-n|是否长度非0
-z|是否长度为0

> `test`使用方式是将操作数和比较符号均看作参数，所以`=`两边需要空格

**文件测试**
示列|含义
:-:|:-:
-r filename|文件是否存在并**可读**
-w filename|文件是否存在并**可写**
-s filename|文件是否存在并且大小非0
-f filename|文件是否存在且是普通文件
-d filename|文件是否存在且是目录

`test`指令还提供了**逻辑参数**，可以将多个比较表达式使用逻辑参数组合

| 逻辑参数 | 含义  |
|:----:|:---:|
| -a   | 与   |
| -o   | 或   |
| !    | 非   |

`[ contition ]`可**简写**`test condition`，如下

> 关于`[[ condition ]]`，`[[]]`是bash扩展的`[]`其功能类似，有以下区别
> 对于`[ -z "$b" ]` 可以直接使用 `[[ -z $b ]]`免去双引号
> 另外就是对于逻辑命令的引入`&&和||等`，`[[ cond1 && cond2]]`，但在其中不可使用`-a和-o等`。另外`&&和||等`可直接对任意命令的结果进行逻辑运算

```sh
# 为了避免$val为空导致参数错误，一般需要使用引号将变量括起来
if test "$val" -eq 1
then
    echo equal
fi

# []中前后必须要有空格
if [ "$val" -eq 1 ]
then
    echo equal
fi
```

## || 算数运算

shell本身并不直接支持算符运算，而是通过命令方式提供，包括`expr`、`let`

### expr

`expr`的使用方式类似`test`所有的元素均为参数需要空格隔开

```sh
# expr只支持整数运算
expr 1 + 1
expr 2 - 1
expr 10 / 2
expr 2 \* 3
expr 10 \% 3
```

> 注意`*`，`%`等元字符需要手动转义
> 在bash中`$((exp))`形式同样可进行算数运算

### let

`let`则是将整个表达式作为参数，且可直接赋值。

```sh
# x为变量，此时无需使用$
let x=x+1  # let "x=x+1"
let x=y*2

# let也可用作比较， x、y可为变量也可为整数字面量
let "x<y"
```

> 对于let的参数最好用`""`包裹，避免元字符带来麻烦

`(( exp ))`是`let exp`的简写

```sh
(( x=x+1 ))
(( "x=y*2" ))
```

> 同样`((  ))`中前后均需要空格

## || 循环结构

### for-in-do-done

for用于遍历序列

```sh
for varname in list
do
    commands
done
```

> list是以空格为分隔的序列

**break**
在循环中可以使用`break`指令跳出循环，`break n`表示跳出n重循环。

### while-do-done

while则是根据命令的执行结果决定是否执行循环，0则继续执行，非0则终止。

```sh
while cmd
do
    commands
done
```

> cmd可为任意命令，自然也可以使用`test`、`let`及其简写

**循环重定向**

```sh
while read a b c
do
    cmds
done < TMP
```

该重定向对于该循环（无论执行几次）只会打开一次文件，然后再循环中依次读取一行，知道文件尾，read返回非0结束。

### util-do-done

基本结构同`while`，只是`util`条件与`while`相反，0则终止，非0继续执行

```sh
util cmd
do
    commands
done
```

## || 多路分支结构case

```sh
case varname in
    pattern_1)
        cmds
        last-cmd;; # 最后一条指令必须用;;结束
    pattern_2)
        cmd;;
    *)             # 默认分支，必须在最后
        cmd;;
esac
```

这里的pattern和前面介绍的文件名替换类似，还可使用`|`做逻辑组合

```sh
case $hour in
    0?|1[01]) echo "Good Morning";;
    1[2-7]) echo "Good Afternoon";;
    *) echo "Good Evening";;
esac
```

## || 捕获内核信号

**内核信号**
编号|名称|含义
:-:|:-:|:-:
1|SIGHUP/挂起|终端断开时发送给该用户的所有进程
2|SIGINT/中断|按下中断建，如Ctrl+D、Ctrl+C
3|SIGQUIT/退出|按下退出键，如Ctrl+]，退出时会进行核心转储
9|SIGKILL/杀死|kill -9发出
15|SIGTERM/终止|kill -15发出
shell使用`trap`指令捕获信号，设置对于该信号的处理方式。

```sh
# 覆盖15信号的默认处理，转而执行echo
trap "echo I refuse to die" 15
# 忽略2 3信号
trap "" 2 3
# 2 3信号复位默认处理方式
trap 2 3
```

## || 调试shell程序

可以通过带选项的sh执行对脚本的调试
选项|功能
:-:|:--
-n|读取脚本但不执行，只进行语法检测
-v|每执行一条命令，都在stdout中显示原命令
-x|类似-v，但是显示的是变量替换完成后的命令
