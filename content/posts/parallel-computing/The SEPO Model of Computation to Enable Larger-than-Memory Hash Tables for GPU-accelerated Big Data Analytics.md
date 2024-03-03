---
title: "The SEPO Model of Computation to Enable Larger than Memory Hash Tables for GPU accelerated Big Data Analytics"
date: 2023-04-12T14:32:42+08:00
topics: "parallel-computing"
draft: true
---

# The SEPO Model of Computation to Enable Larger-than-Memory Hash Tables for GPU-accelerated Big Data Analytics

## || Introduction

目的：开发利用GPU加速**大数据分析**应用程序性能的hash表。

潜在问题：

*   GPU内存有限，无法存放*大*的输入数据也无法存放大的运行（中间）结果。
*   受限与PCIe总线的低带宽和高延迟

该论文描述的hash表的总体特征：

*   超出GPU内存仍然可使用，且性能下降不会太严重
*   支持变长KV pair
*   支持对相同Key的聚合操作（on-the-fly）

> on-the-fly避免了单独使用一个阶段（大数据处理中）来进行聚合操作，从而避免了存储中间结果

> 为了方便描述这里称该hash表为SEPO-hash表

所谓的SEPO即选择性推迟执行(`Selective Postponement`)。

这里主要是由于GPU内存有限，当hash插入时内存已经耗尽，那么此时可以推迟（放弃）该插入，继续进行其他的插入操作。在完成一轮之后，重新插入。

> 更一般的描述是，当服务器在处理一个请求时，如果此时执行该请求效率将会很低下，不如放弃该请求，等待请求者再次提出请求，那时可能将会是高效的。

举个例子：

此时要插入的KV pair模式为`<Url, 1>`，对于相同Url采用的聚合操作为累加。那有可能插入新的URL时内存耗尽，但仍然可以插入已在hash表中URL，此时不需要分配新空间，直接累加即可。在一次遍历结束后，将GPU内存中所有内容拷贝到主机内存，释放GPU内存空间（此时GPU中URL将不会再被使用，一次遍历后所有存在与GPU中相同URL都已被累加）。对于上述不能插入的在插入失败时先做个记录（标记），下次遍历时需要重新插入(此时GPU内存已被释放)。所以该方案可能会导致多次遍历。

> 当然此时需要应用程序容忍不同的插入顺序，而不会破坏程序的正确性。

这里采用的SEPO模型减少了频繁CPU-GPU之间的数据传输。并且实现了在hash使用内存比GPU大四倍时才变得低效。

> SEPO-hash没有使用GPU提供的按需页面迁移，也没有使用Pinned CPU Mem 而是hash表本身在内存耗尽（或者且完成一次遍历后）手动迁移整个GPU内存到主机内存

另外该论文根据SEPO-hash设计了第一个可以处理数据超出GPU内存的基于GPU加速的MapReduce运行时

## || hash策略&内存布局

![\<img alt="" data-attachment-key="37CZI89Y" data-annotation="%7B%22attachmentURI%22%3A%22http%3A%2F%2Fzotero.org%2Fusers%2F11425600%2Fitems%2FTVFRH52I%22%2C%22annotationKey%22%3A%225UU68LZY%22%2C%22color%22%3A%22%23ffd400%22%2C%22pageLabel%22%3A%22868%22%2C%22position%22%3A%7B%22pageIndex%22%3A2%2C%22rects%22%3A%5B%5B308.077%2C563.538%2C557.308%2C727.962%5D%5D%7D%2C%22citationItem%22%3A%7B%22uris%22%3A%5B%22http%3A%2F%2Fzotero.org%2Fusers%2F11425600%2Fitems%2FZMEP3DNP%22%5D%2C%22locator%22%3A%22868%22%7D%7D" width="415" height="274" src="attachments/37CZI89Y.png" ztype="zimage">](attachments/37CZI89Y.png)\
<span class="citation" data-citation="%7B%22citationItems%22%3A%5B%7B%22uris%22%3A%5B%22http%3A%2F%2Fzotero.org%2Fusers%2F11425600%2Fitems%2FZMEP3DNP%22%5D%2C%22locator%22%3A%22868%22%7D%5D%2C%22properties%22%3A%7B%7D%7D" ztype="zcitation">(<span class="citation-item"><a href="zotero://select/library/items/ZMEP3DNP">Mokhtari and Stumm, 2017, p. 868</a></span>)</span>

SEPO-hash采用链表法处理冲突，通过动态分配每个链表节点支持可变长KV pair。

### 自定义内存分配器

由于hash表访问内存的无规则性，以及大量并发线程同时分配内存。需要自定义内存分配器。

在GPU初始化完成，以及其他必要数据结构分配完成后，查询GPU剩余内存，将其全部分配给自定义的内存分配器。分配器以pages pool的形式将这些内存组织起来。

为减少内存争用，将所有hash表的桶分成桶组，每个组包含连续的n个桶，为每个桶组中链表节点在同一个页上分配内存。（当页面耗尽从空闲page pool中在分配一个页）

尽管分为桶组，对于分配器的性能有了提升，但可能出现潜在的页内碎片。当空闲page pool耗尽，此时已经无法为该桶组分配空间，而其他桶组的页可能还有空余空间。其给出的方案是交由使用者自己根据应用程序的不同，来权衡合适的桶组大小。

> 原文关于为何要自定义分配器并未详述其原因，以下为我总结的一些可能的原因。
>
> *   就cuda而言本身不支持在核函数（设备代码）中分配内存的操作，只能提前由cpu分配好，而该SEPO-hash需要动态分配所以必须要一个支持在设备代码中分配内存的操作。
> *   这里采用链表法，那么最好将同一个链表的节点都分配到一个页面上
> *   大量线程同时分配内存，那么在不同的"空闲链表"（分配器保存的空闲内存空间的链表）上分配，可以减少分配器本身对内存的争用。

### 桶组织策略与SEPO

该SEPO-hash的实现提供三种不同`Bucket Organizations`

![\<img alt="" data-attachment-key="XZ4UWLRZ" data-annotation="%7B%22attachmentURI%22%3A%22http%3A%2F%2Fzotero.org%2Fusers%2F11425600%2Fitems%2FTVFRH52I%22%2C%22annotationKey%22%3A%22EAG7PL4I%22%2C%22color%22%3A%22%23ffd400%22%2C%22pageLabel%22%3A%22870%22%2C%22position%22%3A%7B%22pageIndex%22%3A4%2C%22rects%22%3A%5B%5B301.731%2C578.538%2C562.5%2C730.269%5D%5D%7D%2C%22citationItem%22%3A%7B%22uris%22%3A%5B%22http%3A%2F%2Fzotero.org%2Fusers%2F11425600%2Fitems%2FZMEP3DNP%22%5D%2C%22locator%22%3A%22870%22%7D%7D" width="435" height="253" src="attachments/XZ4UWLRZ.png" ztype="zimage">](attachments/XZ4UWLRZ.png)\
<span class="citation" data-citation="%7B%22citationItems%22%3A%5B%7B%22uris%22%3A%5B%22http%3A%2F%2Fzotero.org%2Fusers%2F11425600%2Fitems%2FZMEP3DNP%22%5D%2C%22locator%22%3A%22870%22%7D%5D%2C%22properties%22%3A%7B%7D%7D" ztype="zcitation">(<span class="citation-item"><a href="zotero://select/library/items/ZMEP3DNP">Mokhtari and Stumm, 2017, p. 870</a></span>)</span>

不同的`Bucket Organizations`对于SEPO的支持不同。

> 不同的组织方式分配内存的方式稍有不同，但区别不大。参见原文或者下面介绍的多值SEPO-hash方案

![\<img alt="" data-attachment-key="U3J34DY8" data-annotation="%7B%22attachmentURI%22%3A%22http%3A%2F%2Fzotero.org%2Fusers%2F11425600%2Fitems%2FTVFRH52I%22%2C%22annotationKey%22%3A%224QC29XJP%22%2C%22color%22%3A%22%23ffd400%22%2C%22pageLabel%22%3A%22871%22%2C%22position%22%3A%7B%22pageIndex%22%3A5%2C%22rects%22%3A%5B%5B51.34615384615385%2C468.923%2C299.423%2C730.269%5D%5D%7D%2C%22citationItem%22%3A%7B%22uris%22%3A%5B%22http%3A%2F%2Fzotero.org%2Fusers%2F11425600%2Fitems%2FZMEP3DNP%22%5D%2C%22locator%22%3A%22871%22%7D%7D" width="413" height="435" src="attachments/U3J34DY8.png" ztype="zimage">](attachments/U3J34DY8.png)\
<span class="citation" data-citation="%7B%22citationItems%22%3A%5B%7B%22uris%22%3A%5B%22http%3A%2F%2Fzotero.org%2Fusers%2F11425600%2Fitems%2FZMEP3DNP%22%5D%2C%22locator%22%3A%22871%22%7D%5D%2C%22properties%22%3A%7B%7D%7D" ztype="zcitation">(<span class="citation-item"><a href="zotero://select/library/items/ZMEP3DNP">Mokhtari and Stumm, 2017, p. 871</a></span>)</span>

由于基础方案相当于没有特殊对待重复Key，这里的策略是当出现了50%的插入请求被推迟时，将所有的页面迁移到CPU，释放GPU内存。然后再开始。

多值的方案，无论如何都需要先执行一次完整的遍历，以此来区分当前GPU内存中已插入的Key，哪些还需要，哪些已经不需要了。此时不能将所有的GPU内存都迁移到CPU内存，而是根据遍历结果，要么将values-page要么将不在需要的keys-page迁移到CPU内存。

> 多值内存方案内存分配的不同就在于这里，值链表是在单独的页面，Key是在单独的页面。

对于组合方案，典型的就是上面介绍的插入`<Url, 1>`的实例。内存耗尽也继续遍历，毕竟相同Key的组合是不需要分配新内存的。

> 原文仅介绍了插入hash表的情况，对于之后的使用SEPO模型应该同样能应用。比如类似的推迟访问失败的lookup操作，之后将CPU内存中部分迁移到GPU内存中，同样需要多次遍历。

## || 实验比较

该论文基于SEPO-hash设计了7个应用用来和使用CPU线程的方案进行比较。

![\<img alt="" data-attachment-key="UW7VAHES" data-annotation="%7B%22attachmentURI%22%3A%22http%3A%2F%2Fzotero.org%2Fusers%2F11425600%2Fitems%2FTVFRH52I%22%2C%22annotationKey%22%3A%22FF6GCADP%22%2C%22color%22%3A%22%23ffd400%22%2C%22pageLabel%22%3A%22873%22%2C%22position%22%3A%7B%22pageIndex%22%3A7%2C%22rects%22%3A%5B%5B53.65384615384615%2C550.846%2C302.308%2C734.3079999999999%5D%5D%7D%2C%22citationItem%22%3A%7B%22uris%22%3A%5B%22http%3A%2F%2Fzotero.org%2Fusers%2F11425600%2Fitems%2FZMEP3DNP%22%5D%2C%22locator%22%3A%22873%22%7D%7D" width="414" height="305" src="attachments/UW7VAHES.png" ztype="zimage">](attachments/UW7VAHES.png)\
<span class="citation" data-citation="%7B%22citationItems%22%3A%5B%7B%22uris%22%3A%5B%22http%3A%2F%2Fzotero.org%2Fusers%2F11425600%2Fitems%2FZMEP3DNP%22%5D%2C%22locator%22%3A%22873%22%7D%5D%2C%22properties%22%3A%7B%7D%7D" ztype="zcitation">(<span class="citation-item"><a href="zotero://select/library/items/ZMEP3DNP">Mokhtari and Stumm, 2017, p. 873</a></span>)</span>

PVC和Word Count表现不佳的主要原因是，有太多相同的Key，导致Lock争用，减低了并发性。（当然warp本身也会由于一个线程的阻塞导致整个warp被阻塞）

![\<img alt="" data-attachment-key="FW3GPYUF" data-annotation="%7B%22attachmentURI%22%3A%22http%3A%2F%2Fzotero.org%2Fusers%2F11425600%2Fitems%2FTVFRH52I%22%2C%22annotationKey%22%3A%22DWUGRN84%22%2C%22color%22%3A%22%23ffd400%22%2C%22pageLabel%22%3A%22874%22%2C%22position%22%3A%7B%22pageIndex%22%3A8%2C%22rects%22%3A%5B%5B81.92307692307692%2C561.8079999999999%2C274.03846153846155%2C732.577%5D%5D%7D%2C%22citationItem%22%3A%7B%22uris%22%3A%5B%22http%3A%2F%2Fzotero.org%2Fusers%2F11425600%2Fitems%2FZMEP3DNP%22%5D%2C%22locator%22%3A%22874%22%7D%7D" width="320" height="284" src="attachments/FW3GPYUF.png" ztype="zimage">](attachments/FW3GPYUF.png)\
<span class="citation" data-citation="%7B%22citationItems%22%3A%5B%7B%22uris%22%3A%5B%22http%3A%2F%2Fzotero.org%2Fusers%2F11425600%2Fitems%2FZMEP3DNP%22%5D%2C%22locator%22%3A%22874%22%7D%5D%2C%22properties%22%3A%7B%7D%7D" ztype="zcitation">(<span class="citation-item"><a href="zotero://select/library/items/ZMEP3DNP">Mokhtari and Stumm, 2017, p. 874</a></span>)</span>

以及和Pinned CPU Mem方案比较。该方案完全不使用GPU内存，GPU只能通过PCIe访问主机内存，所以会很慢。加上大量的small PCIe事务也增加了更多的开销。(大量小PCIe事务比少量的大PCIe事务开销更高)

![\<img alt="" data-attachment-key="G7NC8V8G" data-annotation="%7B%22attachmentURI%22%3A%22http%3A%2F%2Fzotero.org%2Fusers%2F11425600%2Fitems%2FTVFRH52I%22%2C%22annotationKey%22%3A%22UZF7ZW7Y%22%2C%22color%22%3A%22%23ffd400%22%2C%22pageLabel%22%3A%22874%22%2C%22position%22%3A%7B%22pageIndex%22%3A8%2C%22rects%22%3A%5B%5B309.8076923076923%2C607.3846153846154%2C558.462%2C731.9999999999999%5D%5D%7D%2C%22citationItem%22%3A%7B%22uris%22%3A%5B%22http%3A%2F%2Fzotero.org%2Fusers%2F11425600%2Fitems%2FZMEP3DNP%22%5D%2C%22locator%22%3A%22874%22%7D%7D" width="414" height="207" src="attachments/G7NC8V8G.png" ztype="zimage">](attachments/G7NC8V8G.png)\
<span class="citation" data-citation="%7B%22citationItems%22%3A%5B%7B%22uris%22%3A%5B%22http%3A%2F%2Fzotero.org%2Fusers%2F11425600%2Fitems%2FZMEP3DNP%22%5D%2C%22locator%22%3A%22874%22%7D%5D%2C%22properties%22%3A%7B%7D%7D" ztype="zcitation">(<span class="citation-item"><a href="zotero://select/library/items/ZMEP3DNP">Mokhtari and Stumm, 2017, p. 874</a></span>)</span>

以及和纯粹的GPU-UVM按需页迁移的实现的比较。

> 需要说明的是，该页迁移的实验数据是作者通过统计应用需要的页面迁移次数计算出来的一个下界（没考虑PCIe事务的初始化时间、页面中断处理时间，仅考虑了数据迁移的传输时间）

## || 可能存在的问题

*   整体迁移整个GPU内存到CPU的耗时如何
*   该hash表主要面向大数据分析应用，特别是SEPO模型是基于这些应用的某些特征设计的（比如无序的插入顺序，容许多次迭代）
