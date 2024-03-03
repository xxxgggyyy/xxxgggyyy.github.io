---
title: "3 patterns"
date: 2024-03-01T19:20:59+08:00
topics: "database"
draft: true
---

# [Patterns](https://neo4j.com/docs/getting-started/cypher-intro/patterns/)

属性图模型真正的优势在于它具有编码模式的能力。单个节点或关系只能反应很少的信息，但节点和关系的模式可以编码任意复杂的想法。

Neo4j的查询语言Cypher强烈基于模式。具体来说，模式用于匹配所需的图形结构。一旦找到或创建了匹配的结构，Neo4j 就可以使用它进行进一步处理


## || Node syntax

```
()
(matrix)
(:Movie)
(matrix:Movie)
(matrix:Movie {title: 'The Matrix'})
(matrix:Movie {title: 'The Matrix', released: 1997})
```

前面的文档已经说明，这里不在赘述。


## || Relationship syntax

```
-->
-[role]->
-[:ACTED_IN]->
-[role:ACTED_IN]->
-[role:ACTED_IN {roles: ['Neo']}]->
```

前面的文档已经说明，这里不在赘述。

## || Pattern syntax

```
(keanu:Person:Actor {name: 'Keanu Reeves'})-[role:ACTED_IN {roles: ['Neo']}]->(matrix:Movie {title: 'The Matrix'})
```

注意`keanu:Person:Actor`后面的`Person`和`Actor`都表示Label，这意味着允许为一个Node指定多个Label。


## || Pattern variables

为了增加模块化并减少重复，Cypher 允许将模式分配给变量。这允许检查匹配路径、在其他表达式中使用等。

```
acted_in = (:Person)-[:ACTED_IN]->(:Movie)
```

可以使用函数访问改变量如：`nodes(path)`,`relationships(path)`,`length(path)`

如：

```
Match so = (s:Shipper)-[*1..3]->(o) return length(so)
```

注意`length`函数是作用到`so`中的每条path上的

## || Clauses

Cypher 语句通常有多个子句，每个子句执行特定的任务，例如：

* 创建并匹配图中的模式
* 对结果进行过滤、投影、排序或分页
* 构造局部语句

> 具体的从句内容请参见[Cypher Manual -> Clauses](https://neo4j.com/docs/cypher-manual/current/clauses/)
