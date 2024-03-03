---
title: "cxx完美转发与左右值引用再梳理"
date: 2023-02-26T21:06:38+08:00
topics: "c-family"
draft: true
---

> 由于初学C++时CXX11标准还未大量使用，大量的新特性断断续续的被学习
> 但由于以前一些的固有影响，对左右值的理解出现了很大的偏差，故有该篇文章做个梳理

## || 左右值与左右值引用

区分左右值的标准是某个对象是否具有名字：

```cpp
// 以下均为左值
int a;
const int a;
int&& a;
int& a;
const int& a;
const int&& a;

// 以下均为右值, 这里单独列出来了，但更多的是在表达式中作为临时对象使用
3 // 以及其他字面常量
func(args); // 返回值为非左值引用
AClass();

```

可以看到一个明显的关键在于`int&& a`是有名字的，他是**左值**。更深入一点来说，引用的底层就是使用指针实现的，那么对一个临时对象进行了应用，那么就需要一个指针空间来存储该地址，故说是左值问题不大。

> 更多的误解就是来自这个有名的右值引用是一个左值

另一件事是关于重载的:

```cpp
void test(int&& a);
void test(int& a);
```

编译器具体调用哪个函数，是使用传入参数是左值还是右值来判断的，而不是左值还是右值引用。
> 当然一个左值引用无论如何都是一个左值

故：
```cpp
void test(int&& a){
    std::cout << "rvalue func" << std::endl;
}

void test(int& a){
    std::cout << "lvalue func" << std::endl;
}

int&& a = 3;
test(a);
```
其输出的`lvalue func`。

> 如果再加一个重载函数`void test(int a);`, 那么在使用左值的时候，编译器无法区分具体使用哪个函数

## || 完美转发

这是一个关于使用模板时传递引用参数出现的一个问题。

```cpp
template<class T>
void wrapper(T&& args){
    other_func(args);
}
```

此时`args`有名字了，那么根据上面所说`args`将总是左值，即使传入右值，故如果`other_func`有右值引用版本的重载的话，此时将无法按照预期的调用的右值函数

要解决这个问题首先要介绍CXX所谓的引用折叠规则。

一个伪代码说明如下：

```cpp
using lv = int&;
using rv = int&&;

lv& a; // 仍然为int&类型
lv&& a; // int&
rv& a; // int&
rv&& a; // int&&
```

故除了"右值应用的右值应用"这种情况被折叠为右值应用后，其他情况仍然为左值引用。

有了引用折叠的概念再来看`wrapper`模板函数，根据传入参数有如下几种情况：

1. 使用右值调用`wrapper`，此时是比较符合直觉的，`T`被推断为`int`类型。（这里假设一个int型的右值）
2. 使用一个常量左值调用，根据引用折叠，此时只要`T`被推断为`const int&`类型，该模板就可以被实例化为一个左值引用函数，符合要求。
3. 使用一个非常量左值调用，同理`T`被推断为`int&`即可

> 如果同时存在`T&&`和`T&`两类模板（甚至同时存在`T`）是，此时不会优先考虑引用折叠，而是先直接匹配。比如，右值就匹配`T&&`，左值就匹配`T&`
> 如果同时存在`T`类型模板可能会导致编译器不知道匹配哪个出现编译错误（归根结底不是模板匹配的问题，而是函数模板展开称函数后，不知道使用哪个函数的问题）
> 但注意如果是类模板，同时存在三类是可以的

所以了解了引用折叠后该如何解决该问题呢？解决方案其实落在了`T`的推断类型上。

直接来看C++标准库给出的解决方案：

```cpp
// 注意这里不会出现上面的说的编译器不知道匹配哪个的问题，因为其并非是函数而是类模板，直接按对最佳匹配实例化即可
// remove_reference这里将去除T的所有引用,变为非引用的原始类型
template< class T > struct remove_reference      { typedef T type; };
template< class T > struct remove_reference<T&>  { typedef T type; };
template< class T > struct remove_reference<T&&> { typedef T type; };

// 该模板用来解决问题
template< class T >
T&& forward( typename std::remove_reference<T>::type& t ) noexcept;

// 这里解决该问题无需该模板
// 该模板内部用来了static_assert来检查，T是否是左值应用，如果是则出错
// 因为该模板总是被右值t匹配，如果T还是左值，将会导致一个右值转换为左值
template< class T >
T&& forward( typename std::remove_reference<T>::type&& t ) noexcept;
```

修改`wrapper`函数如下：

```cpp

template<class T>
void wrapper(T&& args){
    other_func(std::forward<T>(args));
}
```

对应于`warpper`的输入参数与`T`的类型推导结果可知：

1. 使用右值调用`wrapper`，`T`被推断为`int`类型，则`forward`返回右值
2. 使用一个常量左值调用，`T`被推断为`const int&`类型,则`forward`返回左值
3. 使用一个非常量左值调用，同理`T`被推断为`int&`,则`forward`返回左值

故`forward`用来保证传递的参数的左右值属性不变。
> 其实主要是解决右值传递进来变左值的问题
