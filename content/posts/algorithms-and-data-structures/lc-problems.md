---
title: "lc problems"
date: 2024-03-02T21:06:07+08:00
topics: "algorithms-and-data-structures"
draft: true
---

# Leetcode Problems

### [438. 找到字符串中所有字母异位词](https://leetcode.cn/problems/find-all-anagrams-in-a-string)

给定两个字符串 s 和 p，找到 s 中所有 p 的 异位词 的子串，返回这些子串的起始索引。不考虑答案输出的顺序。

异位词 指由相同字母重排列形成的字符串（包括相同的字符串）。

*题解*

经典滑动窗口问题。 这里先放个官方题解：

```cpp
class Solution {
public:
    vector<int> findAnagrams(string s, string p) {
        int sLen = s.size(), pLen = p.size();

        if (sLen < pLen) {
            return vector<int>();
        }

        vector<int> ans;
        vector<int> sCount(26);
        vector<int> pCount(26);
        for (int i = 0; i < pLen; ++i) {
            ++sCount[s[i] - 'a'];
            ++pCount[p[i] - 'a'];
        }

        if (sCount == pCount) {
            ans.emplace_back(0);
        }

        for (int i = 0; i < sLen - pLen; ++i) {
            --sCount[s[i] - 'a'];
            ++sCount[s[i + pLen] - 'a'];

            if (sCount == pCount) {
                ans.emplace_back(i + 1);
            }
        }

        return ans;
    }
};
```

其中`sCount`就表示在s上滑动窗口中字符串的情况，每次滑动一个去和p比较即可。当然这里的比较方法和滑动都比较原始。

> 官方题解还有一个去统计`differ`而不用维持两个数组的方法，这里没有再说了。

再来看我的，我最开始没想到什么滑动窗口，所以是直接写的。（但思想和滑动窗口一样）

但我和官解最不同的在于，我添加了快速滑动。主要思想也比较简单，就是不要一个一个去滑了，比如检测到一个不在p中的k字符，那么直接可以从k之后再开始比较。还有就是如果是在窗口内检测到字符m虽然在p内，但多了，那么再开始滑动从第一个m开始，并且重新计算统计状态。

当然这里的代码写得很烂，这么多变量非常容易出错。可以只做检测到不同的快速滑动，其他的干脆就让他重新统计，这样虽然会牺牲一些性能，但简单很多。

```cpp
class Solution {
public:
    vector<int> findAnagrams(string s, string p) {
        vector<int> ret;
        if(s.size() < p.size())
            return ret;
        // unordered_map<char, int> need, window;
        int need[26], window[26];
        memset(need, 0, sizeof(need));
        for (char c : p) {
            need[c - 'a']++;
        }
        // window = need;
        memcpy(window, need, sizeof(need));
        bool continueFlag = false;
        int j = -1;
        int count = 0;
        for(int i = 0; i < s.size();i++){
            if(need[s[i]-'a'] == 0){
                continue;
            }
            if(!continueFlag){
                j = i;
                count = 0;
            }
            continueFlag = false;
            for(; j < i + p.size(); j++){
                // not found
                if(need[s[j] - 'a'] == 0){
                    i = j;
                    memcpy(window, need, sizeof(need));
                    break;
                }
                // repeated character exceed the need
                if(window[s[j] - 'a'] == 0){
                    while(s[i] != s[j]){ 
                        window[s[i] - 'a']++;
                        i++; 
                        count--;
                    }
                    continueFlag = true;
                    j++;
                    // cur_start = i;
                    break;
                }
                window[s[j] - 'a']--;
                count++;
            }
            // using separate count var to avoid corner case which the j is the last character in continueFlag=true
            // if(j == i + p.size()){
            //     ret.push_back(i);
            //     window = need;
            // }
            if(count == p.size()){
                ret.push_back(i);
                continueFlag = true;
                window[s[i] - 'a']++;
                count--;
            }
        }
        return ret;
    }
};
```

### [448. 找到所有数组中消失的数字](https://leetcode.cn/problems/find-all-numbers-disappeared-in-an-array)

给你一个含 n 个整数的数组 nums ，其中 nums[i] 在区间 [1, n] 内。请你找出所有在 [1, n] 范围内但没有出现在 nums 中的数字，并以数组的形式返回结果。

*题解*

```cpp
class Solution {
public:
    vector<int> findDisappearedNumbers(vector<int>& nums) {
        for(int i = 0;i < nums.size();i++){
            if(nums[i] == 0)
                continue;
            int j = nums[i] - 1;
            while(nums[j] != 0){
                int tmp = nums[j];
                nums[j] = 0;
                j = tmp - 1;
            }
        }
        vector<int> ret;
        ret.reserve(nums.size() / 2);
        for(int i = 0;i < nums.size();i++){
            if(nums[i] != 0){
                ret.push_back(i+1);
            }
        }
        return ret;
    }
};
```

主要是要想到利用原地数组作为hash数组。对于复用原地数组的一个较好的方案不是想我这里去改成0，然后循环处理，而是可以存成负值。

### [461. 汉明距离](https://leetcode.cn/problems/hamming-distance)

两个整数之间的 汉明距离 指的是这两个数字对应二进制位不同的位置的数目。

给你两个整数 x 和 y，计算并返回它们之间的汉明距离。

*题解*

```cpp
class Solution {
public:
    int hammingDistance(int x, int y) {
        x = x ^ y;
        int count = 0;
        while(x){
            count += x & 1;
            x = x >> 1;
        }
        return count;
    }
};
```

异或加移位统计即可。
