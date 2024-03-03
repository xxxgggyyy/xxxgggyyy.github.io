---
title: "ssh原理归纳"
date: 2022-06-19T15:16:48+08:00
topics: "linux-basis"
draft: true
---

# SSH基本思想
利用非对称加密和数字摘要算法实现安全的数据传输（一定程度上）。
无论怎样，都必须要有两对公私钥（client和server各一对），实才能现加密的双向通信。
所以问题只剩下一个**如何安全的分发各自的公钥？**

### 如何生成和分发各自的公私钥？
生成直接使用`ssh-keygen`命令即可，可以指定使用的算法，私钥是否还要加密等。
> ssh-keygen -t rsa -P "" -f ~/.ssh/test_rsa
> 如果对私钥加了密，那么在使用ssh client进行连接时还需要输入该密钥，以让client可以使用该私钥。

而分发则采取一种折中的方法。服务端分发公钥是在client第一次对server发起请求时，此时server发送公钥pub回client，此时client会计算pub的指纹（摘要）显示在屏幕上，让用户自己确认是否正确，从而保证改公钥的安全性。
> 计算pub的指纹是因为一般非对称的公钥都较长，不易于人工比较。
> 如果使用证书来分发公钥肯定是更安全的，但私人生成的公私钥，每次都去申请证书先不说能不能申请，如果设备比较多那确实也比较麻烦。

客户端的公钥分发则和SSH的具体认证方式有关。（见下一节）

# SSH基本原理
> 假设此时client已经确认server的pub公钥是正确的了
### 使用口令登录
此时client使用server的pub（s_pub），对口令加密发送给server，server收到后用私钥解密，并执行linux的登录认证，登录成功则返回登录状态。
此时，client在真正建立通信前，还需要自己生成一对临时公私钥，用来实现server到client的加密通信。
此时由于client已可直接和server的加密通信（s_pub已人工认证正确），直接用s_pub分发公钥(c_pub)即可。（具体原理待验证，只是合理猜测）


### 使用公钥登录
client首先生成一对公私钥，然后把公钥手动添加到server的`~/.ssh/authorized_keys`。
> 手动添加，方法很多比如scp，ssh-copy-id

client在发起请求时，直接附带该公钥即可，server发现该公钥在已授权文件中，则转入对该client的自动认证，具体过程如下:
1. 产生一个随机数R使用c_pub加密后发送给client
2. client对其解密得到R后，在对R和sessionkey计算摘要发送给server
3. server也同样对R和sessionkey计算摘要
4. 对比两个摘要，相同则登录成功

> 计算sessionkey可能是避免重放攻击

> 每个机器即可是服务端也可是客户端。所以都有`known_hosts`和`authorized_keys`
