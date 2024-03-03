---
title: "4 patterns in practice"
date: 2024-03-01T19:20:59+08:00
topics: "database"
draft: true
---

# [Patterns in practice](https://neo4j.com/docs/getting-started/cypher-intro/patterns-in-practice/)

## || Creating and returning data

添加数据可以直接使用上文介绍的Pattern，通过Pattern提供图的结构、标签、属性等信息。

然后使用`CREATE`从句创建该Pattern。如：

```cypher
CREATE (:Movie {title: 'The Matrix', released: 1997})
```

该Cypher语句创建了一个节点、一个Label、以及两个属性。其返回值如下：

```
Created Nodes: 1
Added Labels: 1
Set Properties: 2
Rows: 0
```

可以使用`RETURN`关键字在创建数据时，返回创建的数据，即通过上文提到的Pattern中的变量。

`RETURN`关键字在Cypher中用于指定Cypher查询的结果，可以返回节点、关系、属性甚至是Pattern

在写数据的Cypher中`RETURN`不是必须的，但读数据时是。

```cypher
CREATE (p:Person {name: 'Keanu Reeves', born: 1964})
RETURN p
```

而此时返回值变为了：

```
Created Nodes: 1
Added Labels: 1
Set Properties: 2
Rows: 1

+----------------------------------------------+
| p                                            |
+----------------------------------------------+
| (:Person {name: 'Keanu Reeves', born: 1964}) |
+----------------------------------------------+
```

如果想创建多个元素，可以使用逗号分隔或者使用多`CREATE`语句：

```cypher
 CREATE (:Person {name:"Sally"}), (:Person {name: "John"})
```

```cypher
CREATE (a:Person {name: 'Tom Hanks', born: 1956})-[r:ACTED_IN {roles: ['Forrest']}]->(m:Movie {title: 'Forrest Gump', released: 1994})
CREATE (d:Person {name: 'Robert Zemeckis', born: 1951})-[:DIRECTED]->(m)
RETURN a, d, r, m
```

这里分别创建了两个Person节点，一个Movie节点，并创建两个关系。

## || Matching patterns

使用`MATCH`语句能够匹配数据库中所有匹配该Pattern的的结果。每行返回一个匹配结果。

此时利用变量和`RETURN`来返回想要的匹配结果。

比如要查找上一节添加的Movie：

```cypher
MATCH (m:Movie)
RETURN m
```

或者查找具体某个人：

```cypher
MATCH (p:Person {name: 'Keanu Reeves'})
RETURN p
```

或者更复杂一点查找`Tom Hanks`参演过什么电影：

```
MATCH (p:Person {name: 'Tom Hanks'})-[r:ACTED_IN]->(m:Movie)
RETURN m.title, r.roles
```

这里通过形如`identifer.property`指返回了参演电影的名字和角色。

> 这些`MATCH`都足够简单和直观不在赘述

### >>> Cypher examples

现在我们来看一些更复杂的例子。

> 说是复杂一点，这到底哪里复杂了


* Example 1: Find the labeled Person nodes in the graph. Note that you must use a variable like p for the Person node if you want to retrieve the node in the RETURN clause.

```
MATCH (p:Person)
RETURN p
LIMIT 1
```

* Example 2: Find Person nodes in the graph that have a name of 'Tom Hanks'. Remember that you can name your variable anything you want, as long as you reference that same name later.

```cypher
MATCH (tom:Person {name: 'Tom Hanks'})
RETURN tom
```

* Example 3: Find which Movie Tom Hanks has directed.

```
MATCH (:Person {name: 'Tom Hanks'})-[:DIRECTED]->(movie:Movie)
RETURN movie
```

* Example 4: Find which Movie Tom Hanks has directed, but this time, return only the title of the movie.

```
MATCH (:Person {name: 'Tom Hanks'})-[:DIRECTED]->(movie:Movie)
RETURN movie.title
```

### >>> Aliasing return values

像SQL一样，Cypher的返回结果的title也可以使用别名：

```
//cleaner printed results with aliasing
MATCH (tom:Person {name:'Tom Hanks'})-[rel:DIRECTED]-(movie:Movie)
RETURN tom.name AS name, tom.born AS `Year Born`, movie.title AS title, movie.released AS `Year Released`
```

如果别名中存在空格，则需要使用反引号扩起来。

## || Attaching structures

如果想要扩展已有的图结果，可以先用`MATCH`匹配需要扩展的位置，然后再使用`CREATE`新增节点或者关系

```
MATCH (p:Person {name: 'Tom Hanks'})
CREATE (m:Movie {title: 'Cloud Atlas', released: 2012})
CREATE (p)-[r:ACTED_IN {roles: ['Zachry']}]->(m)
RETURN p, r, m
```

直接把两条`CREATE`放在一起也是可以的，为了可读性这里把一个pattern拆成了两个`CREATE`

还有一点需要注意的是，如这里先`MATCH`后`CREATE`，这里的`CREATE`会作用到`MATCH`的每一行匹配结果上。

如果这不是预期的行为，可以把`CREATE`放在`MATCH`前面，这样`CREATE`就只会创建一次。


## || Completing patterns

当不确定数据库中是否存在数据，又不想创建重复值时，可以使用`MERGE`从句，他组合了`MATCH`和`CREATE`的功能。

`MERGE`首先检查是否存在，如果不存在则创建。

```
MERGE (m:Movie {title: 'Cloud Atlas'})
ON CREATE SET m.released = 2012
RETURN m
```

如上代码所示，`MERGE`从句还有`ON CREATE SET`子句，即需要创建`MERGE`后的pattern时，再附加创建一些属性。

`MERGER`创建之前会先执行检查，这是需要开销的，可以创建索引来减少该开销。


对于关系，`MERGE`同理，存在则创建，这里同样是对所有匹配的记过都应用`MERGE`从句

```
MATCH (m:Movie {title: 'Cloud Atlas'})
MATCH (p:Person {name: 'Tom Hanks'})
MERGE (p)-[r:ACTED_IN]->(m)
ON CREATE SET r.roles =['Zachry']
RETURN p, r, m
```

同样`MERGE`可以同时混合创建节点和关系

```
CREATE (y:Year {year: 2014})
MERGE (y)<-[:IN_YEAR]-(m10:Month {month: 10})
MERGE (y)<-[:IN_YEAR]-(m11:Month {month: 11})
RETURN y, m10, m11
```
