---
title: "nginx+uwsgi部署django"
date: 2022-10-31T15:21:13+08:00
topics: "misc"
draft: true
---

## || 前置要求

mysql，nginx，python，uwsgi默认已经安装完成

## || 迁移django

依照django文档，在`project/project/settting.py`中配置好数据库账号密码，上传文件目录，静态文件目录等

执行`python manage.py mkmigrations`和`python manage.py migrate`建立数据库

并执行`python manage.py collectstatic`收集静态文件到指定目录供`Nginx`使用

## || 配置uwsgi和nginx反向代理

`uwsgi.ini`的配置文件示例如下：
```ini
[uwsgi]
#服务端口
#http = :8888
 
#指定与Nginx通信的方式，不影响uwsgi本身运行。如果配置了需要到nginx中进行相关配置-才能通过nginx访问Django
socket = :9090
 
# 启动一个master进程，来管理其余的子进程
master = True
processes = 4
threads = 2
 
#python虚拟环境目录绝对路径。如果有的话，home是虚拟环境根目录，PYTHNONHOME是虚拟环境下的bin目录（放置了Python执行文件）
#home = /env
#PYTHONHOME = /env/bin
 
#django项目目录，与manager.py同级
chdir = /www/wwwroot/djangoProject1
 
#主应用中的wsgi，下面这种配法是在Django根目录下运行uwsgi有效，主APP名为有settings.py的那个目录名。如果是其他目录运行，下面建议写成绝对路径。
wsgi-file = /www/wwwroot/djangoProject1/djangoProject1/wsgi.py
 
#服务停止时自动移除unix Socket和pid文件
vacuum = true
 
#设置每个工作进程处理请求的上限，达到上限时，将回收（重启）进程，可以预防内存泄漏
max-requests=5000
 
#设置后台运行保存日志。只要配置了daemonize就会让uwsgi后台运行，同时将日志输出到指定目录
daemonize=/www/wwwroot/djangoProject1/uwsgi9090.log
 
#保存主进程的pid，用来控制uwsgi服务
pidfile=/www/wwwroot/djangoProject1/uwsgi9090.pid
#uwsgi --stop/reload xxx.pid 停止/重启uwsgi
 
#静态文件映射
#static-map = /static=Django下static目录的绝对路径

#socket = 127.0.0.1:9090
```

```nginx
server
{
    listen 80;
    server_name www.ayskjjbj.cn;
    location / {
        uwsgi_pass 127.0.0.1:9090;
        include uwsgi_params;
    }
    
    location /static {
        #root static文件夹所在绝对路径,示例如下:
        root /www/wwwroot/djangoProject1/; # 重定向,自动找到static目录
    }
    access_log  /www/wwwlogs/www.ayskjjbj.cn.log;
    error_log  /www/wwwlogs/www.ayskjjbj.cn.error.log;
}
```