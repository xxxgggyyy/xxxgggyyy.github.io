---
title: "windows下配置Apache+mod wsgi+django"
date: 2022-12-14T21:28:38+08:00
topics: "misc"
draft: true
---

# 下载Apache+mod_wsgi
<https://www.apachehaus.com/cgi-bin/download.plx#APACHE24VC09>
<https://www.lfd.uci.edu/~gohlke/pythonlibs/#mod_wsgi>

注意`mod_wsig`以及`apache`和`python`的版本关系，因为这里使用的预编译的版本

我这里下载的是：
[httpd-2.4.54-win64-VS16.zip](https://www.apachelounge.com/download/VS16/binaries/httpd-2.4.54-win64-VS16.zip)
[mod_wsgi‑4.9.0‑cp37‑cp37m‑win_amd64.whl](https://download.lfd.uci.edu/pythonlibs/archived/cp37/mod_wsgi-4.9.0-cp37-cp37m-win_amd64.whl)

> 友情提示需要vpn

# 配置

## 配置Python

在对应的虚拟环境中执行如下命令，安装`mod_wsgi`

```
pip install mod_wsgi‑4.9.0‑cp37‑cp37m‑win_amd64.whl
```
安装成功后执行如下命令查看模块位置`mod_wsgi-express module-config`

```
LoadFile "D:/anaconda3/envs/django/python37.dll"
LoadModule wsgi_module "D:/anaconda3/envs/django/lib/site-packages/mod_wsgi/server/mod_wsgi.cp37-win_amd64.pyd"
WSGIPythonHome "D:/anaconda3/envs/django"
```

然后设置环境变量`PYTHONHOME`为`D:\anaconda3\envs\django`,此时Apache在调用python时，其python才知道从哪里找python包和模块

但某些三方python包或者模块需要加载`dll`，但在windows下`dll`由环境变量`PATH`控制，故还需将在`conda activate django`后，新增的`PATH`的内容手动复制到全局环境变量中。

## 配置Apache

```
......
Define SRVROOT "D:/Apache24"   
ServerRoot "${SRVROOT}"
......
Listen 80
ServerName 0.0.0.0:8088
......

#添加mod_wsgi.so 模块  
LoadFile "D:/anaconda3/envs/django/python37.dll"
LoadModule wsgi_module "D:/anaconda3/envs/django/lib/site-packages/mod_wsgi/server/mod_wsgi.cp37-win_amd64.pyd"
WSGIPythonHome "D:/anaconda3/envs/django"

  
#指定myweb项目的wsgi.py配置文件路径  
WSGIScriptAlias / E:/PyCharmProjects/django_test/django_test/wsgi.py
  
#指定项目路径  
WSGIPythonPath E:/PyCharmProjects/django_test/django_test

# 注意，在配置文件的上面，也有一个<Directory />里面配置为拒绝所有访问
<Directory />  
    Require all granted
</Directory>  
  
#Alias /static D:/mysite/static   
#<Directory D:/mysite/static>   
#    AllowOverride None  
#    Options None  
#    Require all granted  
#</Directory>

```

## 修改wsgi.py
```python
import os
import sys

from django.core.wsgi import get_wsgi_application

# 添加这两行
# 将包含当前文件的文件夹包含到查找路径中
BASE_DIR = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
sys.path.append(BASE_DIR)

os.environ.setdefault('DJANGO_SETTINGS_MODULE', 'django_test.settings')

application = get_wsgi_application()
```







