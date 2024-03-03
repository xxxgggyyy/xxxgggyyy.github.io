---
title: "arch linux下配置WordPress+Nginx+PHP"
date: 2022-08-22T10:48:16+08:00
topics: "misc"
draft: true
---

> 参考：<https://www.php.net/manual/en/install.unix.nginx.php>
> 环境：
> *  ArchLinux2022.6.01-x86_64 kernel-5.18.3
> *  PHP-8.0.22 
> * Nginx-1.22.0
> * WordPress-zh-6.0.1
> * MariaDB-10.8.3

# 安装PHP

## || 编译PHP

```sh
cd php-8.0.22
./configure --enable-fpm --with-mysqli --with-zlib --with-openssl --with-curl
make
sudo make install
```
其中`zlib`解决异常`Fatal error: Uncaught Error: Call to undefined function gzinflate()`

WordPress使用`openssl`和`curl`来更新和下载插件模板（不使用ftp的方式）。

## || PHP-其他处理

1. **拷贝配置文件和`fpm`到合适位置**
```sh
# 注意php.ini的位置，可以建立一个.php文件调用php_info();查看默认位置
# 不然就在执行php-fpm(-h里有指定方法）时手动指定
cp php.ini-development /usr/local/lib/php.ini
cp /usr/local/etc/php-fpm.d/www.conf.default /usr/local/etc/php-fpm.d/www.conf
cp sapi/fpm/php-fpm /usr/local/bin
```

2. **修改`/usr/local/php/php.ini`**
> php.ini的位置是否正确
> 最好在php-fpm.service中手动指定
> /usr/sbin/php-fpm -c /usr/local/lib/php.ini
```ini
# 取消如下注释即可
# 貌似不取消可以
extension=curl
extension=mysqli
extension=openssl

# 该项必须设置
# 用来防止脚本注入
cgi.fix_pathinfo=0

# 设置上传文件大小限制
upload_max_size = 10M
post_max_size = 10M
# 如果需要上传超大文件
# 还需要配置memory_limit和脚本运行时间等其他参数
```

3. **修改`/usr/local/etc/php-fpm.d/www.conf`，设置执行`php-fpm`子进程的用户**
```ini
user = www-data
group = www-data
```
>所有的`~\*.php`请求都会通过`nginx`发送到`php-fpm`处理，为了`php-fpm`执行`wordpress`代码时具有写和执行权限（直接更新和下载模板插件等），建议将wordpress放在`/home/www-data`目录中并设置其拥有者和组为`www-data`。

> 使用`useradd`命令自行创建`www-data`用户和其主目录

4. 设置`php-fpm`开机自启
php的源代码中提供了写好的`systemd service`文件，拷贝到相应位置。
```sh
sudo cp php-8.0.22/sapi/fpm/php-fpm.service /usr/lib/systemd/system
sudo systemctl enable php-fpm
```

若`php-fpm`无法通过`systemctl`启动，可以尝试修改`php-fpm.service`
```sh
# 默认为true，以只读的方式挂载相应的目录（/usr /boot /etc等）
# 由于php-fpm需要写入日志（/usr中）等，需要写入权限不能只读挂载
ProtectSystem=false
```

# 安装Nginx

>Nginx和Mysql通过pacman安装，直接通过`systemctl enable`相应的服务即可开机自启

通过`pacman`直接安装`nginx`。
```sh
sudo pacman -S nginx
```

## || 配置Nginx
默认配置文件为`/etc/nginx/nginx.conf`
修改如下：

```sh
server {
       	listen       80;
        server_name  localhost;
		set $wp_root /home/www-data/wordpress-zh;
		
		# 上传安装插件主题等，稍微大一点
		client_max_body_size 10m;

        location / {
            root   $wp_root;
            index  index.php index.html index.htm;
            # 必须被设置，不然前端无法访问wordpress的REST接口
            try_files $uri $uri/ /index.php?$args;
        }

        # pass the PHP scripts to FastCGI server listening on 127.0.0.1:9000
        location ~ \.php$ {
            fastcgi_pass   127.0.0.1:9000;
            fastcgi_index  index.php;
            fastcgi_param  SCRIPT_FILENAME  $wp_root$fastcgi_script_name;
            include        fastcgi_params;
        }
    }
```
> 此时`wordpress`已解压到`/home/www-data`目录
> `php-fpm`已开启并监听9000端口

# 安装Mysql（MariaDB）

> mariadb即为开源Mysql

通过`pacman`安装`mariadb`，并初始化数据库
```sh
sudo pacman -S mariadb
sudo mysql_install_db --user=mysql --basedir=/usr --datadir=/var/lib/mysql
```
注意阅读`mysql_install_db`的输出，里面有数据库的初始化用户信息（比如root账户及其密码 ）
> 这里10.8.3的mariadb默认创建具有全部权限的`root`和`mysql`用户
> 不设置密码，但需要当前Linux用户为`root`或者`mysql`时才可以相应的用户直接访问数据库

创建wordpress使用的数据库和账户
```sh
sudo su root
mysql -uroot # 无需密码，回车直接进入

# 以下为mysql客户端中输入
create user 'wp'@'localhost' identified by 'your passwd';
create database 'wp' default charset utf8;
grant ALL on wp.* to 'wp'@'localhost';
```

# 配置WordPress

修改`/home/www-data/wordpress-zh/wp-config.php`，如下
> 需要先`cp wp-config-sample.php wp-config.php`

```c

// 首先配置数据库链接
// ** Database settings - You can get this info from your web host ** //
/** The name of the database for WordPress */
define( 'DB_NAME', 'wp' );

/** Database username */
define( 'DB_USER', 'wp' );

/** Database password */
define( 'DB_PASSWORD', 'your password' );

/** Database hostname */
// 这里填写localhost无法链接数据库，必须写回环地址
define( 'DB_HOST', '127.0.0.1' );

/** Database charset to use in creating database tables. */
define( 'DB_CHARSET', 'utf8' );

/** The database collate type. Don't change this if in doubt. */
define( 'DB_COLLATE', '' );

// 再配置更新或者下载插件模板时，不用ftp，而是直接从网络下载到wordpredd-zh目录即可
// no using ftp to update
define('FS_METHOD', 'direct');

```

## || 修改WordPress用户密码的方法

若没有配置邮件的相关服务，可以直接修改数据库。
```
update wp.wp-users set user_pass=MD5('new_passwd') where id=yourid;
```

## || 修改相对路径

如果采用内网穿透的方法部署wordpress，会发现此时一个渲染好的`.php`中的脚本和图片全是带有内网地址的绝对路径，此时可以开启相对路径插件。

进入wordpress后台安装`Relative URL`插件并启用即可。

此时图片和脚本路径问题已解决，但页面跳转的链接地址仍会使用选项`siteurl`和`home`的值，默认为内网的ip地址，需要修改`wp-config.php`，如下
```sh
define('WP_SITEURL', 'http://' . $_SERVER['HTTP_HOST']);
define('WP_HOME', 'http://' . $_SERVER['HTTP_HOST']);
```

## || 内网穿透使用HTTPS

由于使用的内网穿透只支持https所以还需要在`wp-config.php`中做一些修改
```c
// 配置动态地址
// 此时支持了外网https，但内网无法访问了
define('WP_SITEURL', 'https://' . $_SERVER['HTTP_HOST']);
define('WP_HOME', 'https://' . $_SERVER['HTTP_HOST']);

// 必须被配置，不然上面的相对路径插件会失效
// 按这样配置后其实无需再使用相对路径插件
// 使用相对路径插件，是因为没有如下设置，导致仅设置sitrurl和home会导致重定向次数过多
$_SERVER['HTTPS'] = 'on';
define('FORCE_SSL_LOGIN', true);
define('FORCE_SSL_ADMIN', true);
```
> 注意：配置了动态地址之后，其实无需再使用相对路径插件

