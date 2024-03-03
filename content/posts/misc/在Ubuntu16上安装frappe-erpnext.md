---
title: "在Ubuntu16上安装frappe erpnext"
date: 2022-10-04T11:38:07+08:00
topics: "misc"
draft: true
---

# frappe-erpnext介绍

> [frappe-doc](https://frappeframework.com/docs/v13/user/en/introduction)

## || Introduction

Frappe, pronounced fra-pay, is a full stack, batteries-included, **web framework written in Python and Javascript with MariaDB as the database**. It is the framework which powers ERPNext, is pretty generic and can be used to build database driven apps.

Why Frappe? 
The key difference in Frappe compared to other frameworks is that **meta-data is also treated as data**. This enables you **to build front-ends very easily**. We believe in a monolithic architecture, so **Frappe comes with almost everything you need to build a modern web application**. It has a full featured Admin UI called the Desk that handles forms, navigation, lists, menus, permissions, file attachment and much more out of the box.

> 通俗说就是一个`python`写的web框架，但和传统框架非常不同的是，**meta-data is also treated as data**，也就是说可以可视化的建立web的前后端。

## || 基本概念

> 只是为了使用erpnext而了解frappe,而不是使用frappe开发程序

这里只介绍两个主要概念：

1. `site`
2. `app`

`site`主要对应一个站点的后端存储，其实主要是数据库配置和可能的用户上传的文件等

`app`是一个基于`frappe`框架编写的Web应用，包含了所有的前后端代码

可以将一个`app`安装到一个`site`上，那么这个web应用就使用对应的数据库和文件夹。

# 安装frappe

## || 安装依赖

### MiniConda-Python37

从镜像站下载[`MiniConda`](https://mirrors.tuna.tsinghua.edu.cn/anaconda/miniconda/)，按照`frappe-version-13`的要求这里选择`python3.7`及以上的版本。

下载`Miniconda3-py37_4.10.3-Linux-x86_64.sh`完成后安装即可。

> 要关闭登录shell时自动激活base环境可执行`conda config --set auto_activate_base false`

### MariaDB and Redis

`Redis`直接执行`sudo apt install redis-server`安装即可

`MariaDB`需要安装`10.3`版本的，还是使用`apt`安装

```sh
apt-get install software-properties-common
apt-key adv --recv-keys --keyserver hkp://keyserver.ubuntu.com:80 0xF1656F24C74CD1D8
add-apt-repository 'deb [arch=amd64,i386,ppc64el] http://ftp.ubuntu-tw.org/mirror/mariadb/repo/10.3/ubuntu xenial main'

apt install mariadb-server-10.3
```

按照`MariaDB`的提示设置`root`密码

> 注意`root`密码是必须要设置的
> 新增具有完全特权的用户是不行的，因为frappe本身要使用特权来新建数据库，而非root用户无法立刻拥有新建的数据库的特权
> 注意MariaDB的认证策略，如果只被配置为了使用`unix_socket`插件将无法使用账号密码登录
>`update mysql.user set authentication_string=PASSWORD("123456"),plugin='mysql_native_password' where user='root';`
>`flush privileges;`

> 友情提示：最好把VPN挂着

配置`/etc/mysql/my.cnf`

```ini
[mysqld]
character-set-client-handshake = FALSE
character-set-server = utf8mb4
collation-server = utf8mb4_unicode_ci

[mysql]
default-character-set = utf8mb4
```

### Nvm and Node.js

通过`Nvm`安装`Node.js`，方便管理不同版本的`Node.js`，下载该脚本并执行

```sh
curl -o- https://raw.githubusercontent.com/creationix/nvm/v0.33.11/install.sh | bash
```

> `nvm`安装好后，注意`source`一下相应的`bashrc`

然后安装`Node.js 14`

```sh
nvm install 14

# 检查一下
node --v

# 安装yarn
npm install -g yarn
```

### wkhtmltopdf

```sh
apt-get install xvfb libfontconfig wkhtmltopdf
```

## || 安装frappy-bench

`frappe-bench`是`frappe`的CLI

```sh
pip3 install frappe-bench
bench --version
```

# 安装erpnext

建立一个`bench`实例，并运行`bench`

```sh
bench init --version version-13 frappe-bench
# 在第一次建立site和app时最好保持bench server处于开启状态
cd frappe-bench
bench start &
```

安装`erpnext`

```sh
cd frappe-bench
# 保证后台运行
bench start &
bench get-app --branch version-13 https://github.com/frappe/erpnext.git

# 建立一个site
# 会要求你输入Mariadb的root密码
bench new-site retail.site

# 将erpnext安装在retail.site上
# 注意erpnext要求是未完成初始化步骤的site
bench --site retail.site install-app erpnext

# 设置当前站点
# 这样HTTP请求才会到这个site
bench use retail.site

# 如果此时访问http://localhost:8000出现404
# 重新执行bench server
fg # 然后 ctrl-c终止
bench start &
```

> `erpnext`的中文翻译是真的不靠谱，可以修改`frappe-bench/apps/erpnext/erpnext/translations/zh.csv`修改相应的翻译

若要修改`erpnext`中的Workspace需要设置`bench set-config -g developer_mode true`为开发者模式

# 产品模式

即要以非开发模式运行，还需安装`nginx`和`supervisor`

```sh
sudo apt install nginx
sudo apt install supervisor
```

生成对应的配置文件，保存在`~/frappe-bench/config`目录下
```sh
bench setup nginx
bench setup supervisor
```

此时`nginx`用来提供静态资源以及转发请求
`supervisor`则负责所有的`frappe-erpnext`组件的启动和崩溃重启

```sh
# 拷贝配置
cd ~/frappe-bench
# 软链接的源参数必须采用绝对路径
ln -sf `pwd`/config/supervisor.conf /etc/supervisor/conf.d/frappe-bench.conf
ln -sf `pwd`/config/nginx.conf /etc/ngin/conf.d/frappe-benc.conf
```
`nginx`可能默认占用`80`端口，需要自行删除该`server`，可能是`/etc/nginx/conf.d/default.conf`也可能是`/etc/nginx/sites-available`


# 问题

## || wkhtmltopdf无法使用以及中文无法显示

`wkhtmltopdf`报错

```sh
Wkhtmltopdf failed (error code: -6). Message: The switch --header-spacing, is not support using unpatched qt, and will be ignored.The switch --header-html, is not support using unpatched qt, and will be ignored.The switch --footer-html, is not support using unpatched qt, and will be ignored.QXcbConnection: Could not connect to display.
````

### 解决方案-更新`wkhtmltopdf`版本
在使用`apt`安装好`wkhtmltopdf`的基础上，更换其版本为`0.12.4`

```sh
wget https://github.com/wkhtmltopdf/wkhtmltopdf/releases/download/0.12.4/wkhtmltox-0.12.4_linux-generic-amd64.tar.xz
tar xvf wkhtmltox-0.12.4_linux-generic-amd64.tar.xz
sudo mv wkhtmltox/bin/wkhtmlto* /usr/bin/
```

安装好后可以使用，但中文乱码，需要安装中文字体

```sh
# 检查已安装的字体
fc-list
```

将`C:\Windows\fonts\simsun.ttc`拷贝到`/usr/share/fonts/zh`目录，刷新字体缓存`fc-cache`
> `zh`可以手动建立
