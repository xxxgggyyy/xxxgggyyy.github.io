---
title: "Leetcode Problems"
date: 2024-04-16T21:06:07+08:00
topics: "algorithms-and-data-structures"
draft: false
tags: ["leetcode"]
summary: "Leetcode Hot100题单，复习专用"
---

{{< katex >}}

# Leetcode Hot100

> 之前的题目比较简单，且看过多次，下次再来记录

### 42.接雨水

给定 n 个非负整数表示每个宽度为 1 的柱子的高度图，计算按此排列的柱子，下雨之后能接多少雨水。

*题解*

* 单调栈

使用单调栈一次遍历找出所有的可接水大小。

要形成水坑，一定是先变小，再变大，才有水坑。

故从左到右遍历，然后维护单调递减栈，再pop时计算。

但是这样计算，由于大水坑里的小水坑被计算过了，所以计算大水坑时需要减掉。

* 两次遍历计算

先从左到右遍历，将`i=0`作为边界，只需要找到第一个大于`height[0]`那么此为一个水坑（直接找出最终的大水坑）

但水坑也可能是从大到小的，所以此时再从右往左遍历即可。

```cpp
class Solution {
public:
    int trap(vector<int>& height) {
        int l = 0;
        int h_sum = 0;
        int ans = 0;
        while(l < height.size() && height[l] == 0) l++;
        for(int i = l + 1; i < height.size(); i++){
            if(height[i] >= height[l]){
                ans += (i - l - 1) * height[l] - h_sum;
                h_sum = 0;
                l = i;
                continue;
            }
            h_sum += height[i];
        }
        int r = height.size() - 1;
        while(r >= 0 && height[r] == 0) r--;
        h_sum = 0;
        for(int i = r - 1; i >= 0; i--){
            if(height[i] > height[r]){
                ans += (r - i - 1) * height[r] - h_sum;
                h_sum = 0;
                r = i;
                continue;
            }
            h_sum += height[i];
        }
        return ans;
    }
};
```

这里为了可读性写成两个循环，实际一个循环即可。

### 46.全排列

给定一个不含重复数字的数组 nums ，返回其 所有可能的全排列 。你可以 按任意顺序 返回答案。

*题解*

直观的做法是使用回溯遍历。但由于全排列的特殊性，每层回溯遍历时不能使用已使用的，可以使用一个标记数组。

但此时时间复杂度较大，可以通过在排列第i个元素时，维护`nums[0:i]`为已选择的，`nums[i+1:]`为未选择的。

只需要每次选择时交换`nums[i]和nums[j]`，回溯时撤销即可。



