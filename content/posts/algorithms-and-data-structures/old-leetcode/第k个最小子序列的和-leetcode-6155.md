---
title: "第k个最小子序列的和 leetcode 6155"
date: 2022-08-22T10:48:16+08:00
topics: "algorithms-and-data-structures"
draft: true
---

# 第k个最小子序列的和

> leetcode-6155的前置简化题
> 此为`TsReaper`给出的[题解](https://leetcode.cn/problems/find-the-k-sum-of-an-array/solution/by-tsreaper-ps7w/)

首先考虑本题的简化问题：给定$n$个非负数$a_1, a_2, \dots, a_n$，求第$k$个最小的子序列和。

这是一个经典问题。我们先把所有数从小到大排序，记$(s, i)$表示一个总和为$s$，且最后一个元素是第$i$ 个元素的子序列。

我们用一个小根堆维护$(s, i)$，一开始堆中只有一个元素$(a_1, 1)$。当我们取出堆顶元素$(s, i)$时，我们可以进行以下操作：

* 把$a_{i + 1}$接到这个子序列的后面形成新的子序列，也就是将$(s + a_{i + 1}, i + 1)$放入堆中。
* 把子序列中的$a_i$直接换成$a_{i + 1}$，也就是将$(s - a_i + a_{i + 1}, i + 1)$放入堆中。

第$(k - 1)$次取出的$(s, i)$中的$s$就是答案（$k = 1$时答案为空集之和，也就是$0$）。

这个做法的正确性基于以下事实：

* 这种方法能不重不漏地生成所有子序列。
* 每次放进去的数不小于拿出来的数。

这里不予证明，请读者自行思考。

# 证明

1. **首先证明改方法能够不重不漏的生成所有子序列。**

根据数归法证明：

* 初始成立条件，以$a_1$结尾的所有子序列，采用该方法能生成以$a_2$结尾的所有子序列
  
  > $a_1$结尾的就$a_1$一种显而易见成立

* 需证明若已知所有以$a_i$结尾的子序列，该方法生成的以$a_{i+1}$结尾的所有子序列不重不漏
  
  > 若不重不漏的构造出了以数组中每一个$a_i$为结尾的所有子序列，则该数组的所有子序列都被构造

证明：

所有以$a_i$结尾的子序列形如，$\dots$ $a_i$，每个子序列各不相同，即$\dots$表示的序列不同。以该方法，每个子序列将生成两个以$a_{i+1}$结尾的子序列形如，$\dots$ $a_i$ $a_{i+1}$，$\dots$ $a_{i+1}$

这两个序列自身肯定不相同，而以$a_i$结尾的每个序列$\dots$肯定不相同，故该方法生成的所有以$a_{i+1}$结尾的子序列不重复。不重复得证，还须证明不漏序列

若存在一个以$a_{i+1}$结尾的序列，$s$ $a_m$ $a_{i+1}$不在以上生成的序列中。若$a_m$等于$a_i$，则$s$ $a_m$一定在以$a_i$的所以子序列中，$s$ $a_m$ $a_{i+1}$必然已被构造矛盾。

若$a_m$不等于$a_i$，意为着序列$s$ $a_m$不包含$a_i$，此时若$s$ $a_m$ $a_{i+1}$不在以上生成的序列中那么意为着$s$ $a_m$ $a_i$不在所有的$\dots$ $a_i$，矛盾

故得证，所有以$a_i$结尾的子序列形如，$\dots$ $a_i$，通过该方法可以不重不漏的生成所有以$a_{i+1}$结尾的子序列。

2. **其次需要证明，第k次出优先队列的就是第k小的子序列和**

首先每次放进优先队列中的值$m$，一定大于出队列的$s$。由上可知，$m$是$s$新生成的子序列，由于事先排序过，$m$肯定大于$s$。
> 一个子序列生成的两个子序列都更大

由于是小顶堆，故当前的队列顶一定是当前队列中所有子序列以及未来生成子序列中的最小的。再结合数归从$a_1$开始则第k次一定是第k小的。
> 原理就在于，当前出队列的$s$生成比其大的子序列，而小顶堆中其他的比$s$还大的子序列生成子序列比他们自身还大，自然比$s$大，所以之后生成的所有子序列就没有比$s$小的了