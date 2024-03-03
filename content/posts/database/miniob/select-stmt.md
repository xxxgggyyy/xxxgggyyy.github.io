---
title: "select stmt"
date: 2024-03-01T19:20:59+08:00
topics: "database"
draft: true
---

---
author: "xgy"
date: "2023-12-22"
---

# MiniOB - Select语句实现

> 本文为2023年OceanBase大赛初赛中0x80队伍中对Select语句的完整实现总结。

截至2023年第三届OB大赛，MiniOB中Select的语句实现的功能非常单一，根据初赛要求我们实现了Select语句的以下功能：

1. group by、having、aggregation-func
2. 复杂表达式计算，包括函数、子查询、聚合函数、NULL在表达式中的使用
3. join，包括带多on条件、子查询，以及hash join优化
4. order by
5. alias
6. 复杂子查询

## || 语法分析与AST

词法分析使用flex工具实现，比较简单不再赘述。

语法分析使用yacc语法定义select语句的具体产生式，并使用bison生成解析代码。

为了更加方便的支持复杂表达式和复杂select（包括聚合、alias、复杂子查询等），我们重构了整个MiniOB的AST结构，并重写了大部分yacc_sql.y中的文法。

对于select语句的语法解析而言，难点主要有两个：表达式、select自身

先看表达式的文法：

```yacc
expr:
  positive_value {}
  | variable {}
  | LBRACE expr RBRACE {}
  | LBRACE select_stmt RBRACE {}
  // Unary
  | NOT expr {}
  | '-' expr %prec UMINUS {}
  | EXISTS LBRACE select_stmt RBRACE {}
  // Binary
  // 逻辑运算
  | expr AND expr {}
  | expr OR expr {}
  // 比较运算
  | expr EQ expr {}
  | expr NE expr {}
  | expr LT expr {}
  | expr LE expr {}
  | expr GT expr {}
  | expr GE expr {}
  | expr LIKE expr {}
  | expr NOT LIKE expr {}
  | expr IS NULL_TOKEN {}
  | expr IS NOT NULL_TOKEN {}
  | expr IN tuple {}
  | expr IN LBRACE select_stmt RBRACE {}
  | expr NOT IN tuple {}
  | expr NOT IN LBRACE select_stmt RBRACE {}
  // 算术运算
  | expr '+' expr {}
  | expr '-' expr {}
  | expr '*' expr {}
  | expr '/' expr {}
  // 聚合函数
  | MIN LBRACE agg_args RBRACE {}
  | MAX LBRACE agg_args RBRACE {}
  | COUNT LBRACE agg_args RBRACE {}
  | SUM LBRACE agg_args RBRACE {}
  | AVG LBRACE agg_args RBRACE {}
  // 普通函
  | LENGTH LBRACE expr RBRACE {}
  | ROUND LBRACE expr RBRACE {}
  | ROUND LBRACE expr COMMA expr RBRACE {}
  | DATE_FORMAT LBRACE expr COMMA expr RBRACE {}
  ;
```

以上为去掉AST构造逻辑的表达式产生式，其自解释性较好，就是SQL中允许的表达式的语法。

> 当然要完全了解以上文法，需要结合具体源码，可自行查看每个Token含义，以及对应的AST结构，比如LE就是小于

唯一需要说明的是`expr`中的`variable`，如下：

```yacc
variable: // 可能是单个变量、单个表、单个字段、表加字段
  ID {
    auto *ast = new VarSqlAST($1);
    $$ = ast;
    free($1);
  }
  | ID DOT ID {
    auto *ast = new DualVarSqlAST($1, $3);
    $$ = ast;
    free($1);
    free($3);
  }
```

其实就是表中的字段名的引用，如`select t.a, b from t`，其中`b`被解析为AST中的`VarSqlAST`，`t.a`被解析为`DualVarSqlAST`。

另外值得一提是该`expr`中直接支持子查询。

> 如果该子查询是简单子查询即不依赖外部查询的值，则该子查询显然可以用在任何expr中。
> 但如果依赖外部查询的值，则只有可能在join on、where、having中出现。此时才具有语义，这将在语义分析中被检查。

至于`expr`对应的AST结构在重构之后变得非常紧凑：

```cpp
/// Unary Operator
/// -1, -2, -3, NOT (expr), ...
class UnarySqlAST : public SqlAST
{
public:
  UnarySqlAST() : SqlAST(kUnary), opcode(OperType::UNDEFINED) {}
  ~UnarySqlAST() override { delete operand; }

  OperType opcode;
  SqlAST *operand;
};

/// Binary Operator
/// 1 + 2, 3 - 4, 5 * 6, ...
class BinarySqlAST : public SqlAST
{
public:
  BinarySqlAST() : SqlAST(kBinary), opcode(OperType::UNDEFINED) {}
  ~BinarySqlAST() override
  {
    delete lhs;
    delete rhs;
  }

  OperType opcode;
  SqlAST *lhs;
  SqlAST *rhs;
};

/// Variable
/// products, alias, ...
class VarSqlAST : public SqlAST
{
public:
  VarSqlAST(const std::string &var_name) : SqlAST(kVar), var_name(var_name) {}

  std::string var_name;
};

/// Dual Variable
/// products.id, alias.id, ...
class DualVarSqlAST : public SqlAST
{
public:
  DualVarSqlAST(const std::string &first_var_name, const std::string &second_var_name)
      : SqlAST(kDualVar), first_var_name(first_var_name), second_var_name(second_var_name)
  {}

  std::string first_var_name;
  std::string second_var_name;
};
```
将所有的操作符抽象为单目和双目运算AST，以及代表常量的`IntSqlAST`、`FloatSqlAST`、`StrSqlAST`、`TupleSqlAST`这足以构建一般的表达式

另外由于此时所有的AST结构都继承自`SqlAST`，这变得非常灵活，这使得`AggregrateSqlAST`、`FunctionSqlAST`代表的聚合函数和普通函数可以很容易的融入到表达式AST树中。

同理代表select语句自身的AST（子查询）同样非常容易的就整合到表达式AST中了。

接下来看select语句的AST：

```cpp
/// Select Statement
/// SELECT <select> FROM <from> WHERE <where>
class SelectSqlAST : public SqlAST
{
public:
  SelectSqlAST() : SqlAST(kSelect) {}
  ~SelectSqlAST() override
  {
    for (auto &[s, _] : select) {
      delete s;
    }
    // delete first_table.first;
    for (auto &[_, s, __, f] : joined_tables) {
      delete s;
      delete f;
    }
    delete where;
  }

  // select_expr alias, ...
  std::vector<std::pair<SqlAST *, std::string>> select;
  // tb/sub_select alias
  // std::pair<SqlAST *, std::string> first_table;
  // join_type tb/sub_select alias join_filter, ...
  std::vector<std::tuple<JoinType, SqlAST *, std::string, SqlAST *>> joined_tables;
  SqlAST *where;
  SqlAST *having;
  std::vector<SqlAST *> group_by;
  std::vector<std::pair<SqlAST *, OrderType>> order_by;
  std::string sql_string;
};
```

其中`select`成员表示投影单元，每个投影单元可以认为是一个`expr`，并可能会有用户执行的别名。

`joined_tables`则代表from子句中出现的表或者是子查询，`JoinType`代表前一个表和当前表join的类型，此时只支持`INNER JOIN`和`PRODUCT`（第一个元素的JoinType无意义）

同样在`joined_tables`中用户可以为给定的表或者子查询指定别名，即`std::tuple`中的第3个元素`std::string`。而最后一个`SqlAST*`表示的是当前join的`on expr`

`where`表示where从句的`expr`，`having`表示having从句的`expr`

`group_by`数组表示用来做聚合的字段，这里目前只支持为`VarSqlAST*`或`DualVarSqlAST*`

`order_by`数组用来指示用来进行排序的字段，此时支持表（子查询）字段和聚合函数。其中OrderType指明升序还是降序

`sql_string`用来表示该select语句的原始SQL字符串（可用在输出的title或者view之类的地方）

## || 语义分析与SelectStmt

在将sql字符串解析成AST后，第一步则是对该AST进行语义分析，筛选出不满足语义的sql语句。完成之后（或者过程中）生成该select sql对应的SelectStmt。

SelectStmt的目的是将相对比较的割裂的AST，转换数据库中内部表示。

比如AST中表名就是一个字符串，那么在SelectStmt中就是实际的`Table*`对象指针了，指向了实际数据库内部对象。

> 当然这里除了Table*好像就没有太多的内部表示需要转换了，反而主要是对于expr的建立比较麻烦

这显然是需要先做语义分析的，比如检查当前的数据库中是否存在该表。

在整个select语句实现过程中，最麻烦最耗时的地方就在这里。这里按照实现的顺序一个功能一个功能的分别介绍其语义分析以及SelectStmt生成与填充。

### >>> from子句

from子句中就是表和表或者表和子查询的join，在`SelectStmt`中使用成员`joined_units_`保存从AST中解析出来的表和子查询，相关结构如下：

```cpp
class SelectStmt: public Stmt{
    ......
private:
  // from子句中表或者子查询
  std::vector<JoinedUnit> joined_units_;
    ......
};

class JoinedUnit
{
public:
  JoinedUnit() = default;
  JoinedUnit(std::string name, Table *table) : name_(name), table_(table), is_sub_select_(false) {}
  JoinedUnit(std::string name, std::unique_ptr<SelectStmt> sub_select)
      : name_(name), sub_select_(std::move(sub_select)), is_sub_select_(true)
  {}
    ......

private:
  bool is_sub_select_;
  Table *table_ = nullptr;
  std::unique_ptr<SelectStmt> sub_select_;

  // or alias
  std::string name_ = "";
  JoinType join_type_ = JoinType::NONE;
  // 要明白，只要出现表达式的地方就有可能出现子查询甚至有可能是多个)
  ExprUnit<SelectStmt> filter_expr_unit_;
};
```

`JoinedUnit`要么是一个数据库中表，要么是一个子查询，通过`is_sub_select_`区分这两者。`name_`要么是表名要么是用户给的别名。

在`SelectStmt`中还是采用数组的方式存储，含义基本和对应的AST相同，`JoinedUnit::join_type_`代表当前`JoinedUnit`和前一个的join类型。

`filter_expr_unit_`代表当前这个join的on expr，expr的表示和执行再Select语句的实现中也相当重要。现在先来说明表达式的处理。

#### 表达式总览

通过语法分析得到的表达式AST，只拥有语法结构，并不能被实际执行，并且也没有进行正确性验证。

所以此时需要将该AST表达式转换为实际可执行的表达式树，并进行正确性检查。

对于SQL语句而言，其中的表达式和一般的数学表达式的区别在于，SQL中的表达式中存在对表字段的引用、聚合函数、子查询。

所以在一个表达式实际执行时，其中这三类元素必须提前将其物化赋予实际的值，这样表达式才能结合其他的常量和运算符计算出表达式最终的结果。

主要问题其实只有两个：

1. 表达式正确性和类型检查（设置）
2. 如何设置这三类未知的值(即表达式最终如何计算)。

我们采用的方案是为AST表达式树建立一套全新的中间表示树（见下文），其中这三类的未知值



#### 表达式详解

现在来说明对应的AST表达式如何转换为内部可计算表达式，毕竟在AST中表达式更多的还是只具有语法结构，并不能被执行，并且也没有进行正确验证（也没类型检查）。

另外AST表达式中的聚合函数和子查询也需要单独处理。

类似于AST表达式，实际的可执行表达式定义了另一套的可执行的中间表示：

```cpp
class Expr
{
public:
  enum ExprKind
  {
    kConstant,
    // For constant tuple
    kConstTuple,
    // For all field
    kStar,
    // For any field
    kField,
    // For subquery
    kColumn,
    // Aggregate
    kAggregate,
    // Operator
    kOperator,
    // Function
    kFunction,
  };

  Expr(ExprKind kind) : kind_(kind), parent_(nullptr) {}
  virtual ~Expr() = default;

  // 获取表达式计算结果的类型，不进行实际的计算
  virtual DataType ret_type() const = 0;

  // 表达式求值
  virtual RCOr<std::vector<Value>> eval() const = 0;

  Expr *parent_;
  std::vector<Expr *> child_;
  const ExprKind kind_;
};

// 字段表达
class TableFieldExpr : public Expr
{
......
};

// 列表达式
class ColumnExpr : public Expr
{
......
};

// 聚合表达
class AggregateExpr : public Expr
{
......
};

// 算子表达
class OperExpr : public Expr
{
.....
};

......

```

在拿到AST表达式的基础上可以执行`ExprContext::build_expr_tree`来转换为该新的expr表达式树。

对表字段的引用、子查询、聚合函数，此时仅将其在新的expr树中分别用`TableFieldExpr`、`ColumnExpr`、`AggregateExpr`来进行表示。

在转换的过程中会进行一部分的类型检查，但对于上面提到的三类（字段引用、子查询、聚合函数）此时还没法确定类型，并且对于NULL也只能在实际执行该表达式才能进行检查。

`ExprContext`对象在调用完`build_expr_tree`后其实已经将除了上面提到的三类节点，都建立完毕了，所以现在要来正确设置这三类expr节点。

> 这里所谓的设置主要就是设置这些Expr的类型
> 这三类表达式可以认为式表达式的输入，在表达式实际执行时，需要先用从数据库中拉出的元组填充对应的这三类Expr，然后就可以计算出表达式最终的结果了。

可以通过:
```cpp
  /**
   * @brief 获取表达式树中的未解析表达式，以及对应的 AST
   */
  const std::vector<std::pair<Expr *, SqlAST *>> &get_unresolved_asts() const { return unresolved_asts_; }
```
来获取到对应的还未处理`Expr`以及对应的AST树。通过遍历该数组即可递归的处理这些未处理的AST，比如如果是子查询，则还需要建立新的SelectStmt。

为了更好的管理这一系列的结构，定义了`ExprUnit`来管理转换后表达式：

```cpp
/**
 * @brief 对ExprCtx和其可能存在子查询进行封装 * @details T 可能是LogicalOperator/PhsycalOperator/Stmt
 */
template <typename T>
using ColExprSubSelectPair = std::pair<ColumnExpr *, std::unique_ptr<T>>;

template <typename T>
class ExprUnit
{
public:
  ExprUnit() = default;
  ExprUnit(const ExprUnit &) = delete;
  ......

  DataType ret_type()
  {
    if (expr_ctx_ == nullptr || expr_ctx_->get_root() == nullptr)
      return DataType::UNDEFINED;

    // 需要特殊处理子查询
    auto *root_expr = expr_ctx_->get_root();
    if (root_expr->kind_ == Expr::kColumn) {
      return dynamic_cast<ColumnExpr *>(root_expr)->elem_type_;
    }
    // 不需要特殊处理聚合函数    // if (root_expr->kind_ == Expr::kAggregate) {
    //   return dynamic_cast<AggregateExpr *>(root_expr)->ret_type();
    // }
    return expr_ctx_->get_root()->ret_type();
  }

  bool empty() const { return expr_ctx_ == nullptr || expr_ctx_->get_root() == nullptr; }

private:
  std::unique_ptr<ExprContext> expr_ctx_ = nullptr;
  std::vector<ColExprSubSelectPair<T>> sub_selects_;
  std::vector<AggregateExpr *> agg_exprs_;
};
```

如上所示，`expr_ctx_`对应一个`ExprContext`即新的Expr树，`sub_selects_`则是`ColumnExpr`和`SelectStmt`对的数组，用来表示新树中的子查询。`agg_exprs_`用来表示新树中的`AggregateExpr`

> 注意到ExprUnit<T>为模板，这里可以先把T认为是SelectStmt的情形。

`Stmt::build_expr_general`负责上面描述的建立表达式树的过程：

```cpp
RC Stmt::build_expr_general(const ScopeCheckFunc &scope_check_func, Db *db, SqlAST *sql_ast,
    ExprUnit<SelectStmt> &out_expr_unit, std::vector<std::pair<AggregateExpr *, SqlAST *>> &out_aggs,
    std::vector<ExprSqlASTPair> &out_unresolved)
{
  RC rc = RC::SUCCESS;
  auto expr_ctx = std::make_unique<ExprContext>();
  rc = expr_ctx->build_expr_tree(sql_ast);
  if (rc != RC::SUCCESS)
    return rc;
  auto &out_colexpr_subselects = out_expr_unit.get_sub_selects();

  // 检查和设置expr中的引用的表字段
  for (auto &[sub_expr, sub_ast] : expr_ctx->get_unresolved_asts()) {
    // epxr中出现了子查询
    if (sub_ast->kind() == SqlAST::kSelect) {
      SelectStmt *sub_select_stmt = nullptr;
      std::vector<ExprSqlASTPair> unresolved;
      // 先创建该子查询的stmt
      rc = SelectStmt::__create(db, ast_cast<SelectSqlAST>(sub_ast), sub_select_stmt, unresolved, SelectStmt::IN_EXPR);
      if (rc != RC::SUCCESS)
        return rc;
      // 在表达式中存在的sub select只能返回一列 
      if (sub_select_stmt->get_prj_units().size() != 1) {
        LOG_WARN("Subquery in expr can only return one column.");
        return RC::MORE_THAN_ONE_COLUMN;
      }
      // 该子查询中存在其自身名字空间无法处理的表达式
      if (unresolved.size() > 0) {
        // 那就再检查当前的名字空间是否存在
        // 如果还存在无法解析的值那就只能往外传递了
        for (auto &[sub_expr, sub_ast] : unresolved) {
          rc = scope_check_func(sub_expr, sub_ast, out_unresolved);
          if (rc != RC::SUCCESS)
            return rc;
        }
      }
      std::unique_ptr<SelectStmt> subs_stmt_ptr(sub_select_stmt);
      assert(sub_expr->kind_ == Expr::kColumn);
      auto *col_expr = dynamic_cast<ColumnExpr *>(sub_expr);
      col_expr->elem_type_ = subs_stmt_ptr->get_prj_units()[0].get_type();
      out_colexpr_subselects.emplace_back(col_expr, std::move(subs_stmt_ptr));
    } else if (sub_ast->kind() == SqlAST::kVar || sub_ast->kind() == SqlAST::kDualVar) {
      // 如果当前的名字空间中没有，只有往外传递      
      rc = scope_check_func(sub_expr, sub_ast, out_unresolved);
      if (rc != RC::SUCCESS)
        return rc;
    } else if (sub_ast->kind() == SqlAST::kAggregate) {
      // 给expr_u设置AggExpr*指针，并返回一个vec<ExprSqlASTPair>后面这个在建立group时再处理
      auto *agg_expr = dynamic_cast<AggregateExpr *>(sub_expr);
      out_expr_unit.add_agg_expr(agg_expr);
      out_aggs.emplace_back(agg_expr, sub_ast);
    } else {
      // assert(false);
      LOG_WARN("unknown ast type");
      return RC::UNRESOLVABLE_NAME;
    }
  }  // end for loop

  out_expr_unit.set_expr_ctx(std::move(expr_ctx));
  return RC::SUCCESS;
}
```

### >>> where从句

### >>> select投影单元

### >>> group by子句

### >>> having从句

### >>> order by子句

### >>> 处理聚合函数

## || 逻辑计划

## || 物理计划
