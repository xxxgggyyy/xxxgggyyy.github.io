---
title: "STL中vector注意事项"
date: 2022-10-31T15:21:13+08:00
topics: "algorithms-and-data-structures"
draft: true
---

```cpp
vector<vector<int>> vv;
auto a = &vv.back();
auto b = &vv[0];
vv.push_back(other);
```
注意了，随着`push_back`的使用，此时很可能`b!=&vv[0]`，因为`vv[0]`始终是`vector`内部数组中某个元素的地址，
但`push_back`后如果不够用了，`vector`自动扩张时会复制。
>如果`vector<int>`是`int`可能一下就能反应过来