---
title: "cxx模板元编程 cxx11补充"
date: 2023-02-19T21:10:58+08:00
topics: "c-family"
draft: true
---

# misc

### Detection Idiom

利用模板的最特化匹配和丢弃错误参数模板来实现对某个类是否存在某个字段或者函数。

示例：

```cpp

// 主模板
template <class T, class V=void>
struct HasAttr{
    using value_t = std::false_type;
};

// 特例模板
template <class T>
struct HasAttr<T, void_t<typename T::attr>>{
    // void_t<typename T::attr>是关键，如果T不具有属性attr,则会导致void_t本身出错
    // 从而导致该特例模板被丢弃
    using value_t = std::true_type;
};

template<class...>
using void_t = void;

struct TestC{
    using attr = int;
};

if(HasAttr<TestC>::value_t::value){
    // do something
}
```

基本原理：

1. 待检测的类含有某个属性，此时主模板和特化模板均可匹配，但根据规则匹配最特化的模板。
2. 不含有某个属性，特化模板参数出错被丢弃，使用主模板（前提主模板能匹配成功）

这里需要注意给出的`V`的默认模板参数为`void`，这意味着`HasAttr<TestC>`实际上是`HasAttr<TestC, void>`，所以为了匹配到特化模板，特化模板中使用了`void_t`来保证在具有`attr`时也是返回`void`，不用`void_t`是不行的。

### Misc

`decltype(<expr>)`得到expr的声明类型
`declval(<expr>)`在编译期得道一个expr类型的对象


### 右值引用与智能指针

> 补充：区分左值和右值的准则是是否具有名称，当我们将函数参数定义为了右值**引用**(和右值不同)时，在函数内部是可以见到其名字的故该参数此时在函数内部为左值。
> 而带右值引用和左值引用的函数重载是根据传入参数是否是左右值决定的，而不是左右值引用。

所谓右值即各种临时对象。
> 神奇的是字面常量可以被认为是右值
```cpp
AClass a = AClass(3);

AClass func(const AClass acl){
    return acl;
}

a = func(AClass(3));
```

比如这里在`AClass(3)`就是一个临时对象。又比如acl返回时，同样会产生临时对象然后拷贝到a.
> 因为函数可能在一个复杂表达式中使用，其中并没有一个`a = `故必须要产生临时对象。

为何现在要单独在cxx11中定义右值引用呢？(即T&&)
问题主要出在具有指针成员的类中:
```cpp
class ACl{
public:
    int* a; // a int array having dynamic mem
    ...
}
```

如果该类还定义了深拷贝，那么临时对象的各种拷贝（构造）会导致性能下降。

故cxx11中定义右值引用类型，如此可以对拷贝构造函数和赋值函数定义对于右值对象的重载函数。那么一种解决方案，就出现了，把这些具有右值类型的重载函数定义为单独的浅拷贝，即可解决该问题。

除此之外，还有其他的一些使用方式。

比如STL中某些容器提供了`emplace_`函数，该函数就使用的右值引用类型作为参数，如此一来就避免了临时对象的深拷贝。另`std::move()`函数可以对一个对象进行强制类型转换为右值应用，以匹配对应的重载函数。

最后，智能指针也和右值相关。比如`unique_ptr`,`shared_ptr`

主要是`unique_ptr`,从名字就可以看出来，其只允许一个`unique_ptr`对象指向同一块内存。但其可以调用相应的右值函数对指针进行移动。(浅拷贝)

### constexpr

在介绍之前先说明`const`，`const`声明的本身含义仅有某个变量是不可变的。至于其值能否在编译期计算这是没有关系的。就算动态初始化，编译器也接受，只是不能做一些优化了。

而`constexpr`是对`const`本身的进一步补充，他把表达式本身都扩展到了`const`的概念，这意味着`constexpr`声明的表达式必须在编译期被静态初始化掉。

如:
```cpp
constexpr int get_v(){
    return 0;
}

// 如此一来编译器就知道了该像对待常量一样深入分析该函数是否是常量
static const int a = 1 + get_v();
```

更进一步，不断表达式的对象是函数还是类对象，只要所有的元素都是常量（类对象则其属性是常量）,只要可在编译期计算出来都是可以的。

`constexpr`除了编译期初始化，还有`const`属性，即之后不在可变，被放在了程序的只读section.

> C++20引入了`constinit`关键字，其和`constexpr`的区别在，同样会导致编译期初始化，但其变量是在程序使用期间可变的.

另外注意`const`只是表示一个变量是不可变的，至于是否会在编译期被计算，这是不一定的，看具体的表达式和编译器的优化。

### reinterpret_cast与static_cast

简单来说`reinterpret_cast`和C语言的强制类型转换类似，就是将一个变量内容的含义告诉编译器让它按新类型解释，不要做任何的额外操作。操作的正确性完全有程序员的能力决定。

`static_cast`相对来说要安全一些，对于有一点点关系的类型之间的转换，可能会进行一些合理的截断、补齐等等。

### `[[noreture]]`与异常

C++的异常在我看来，是一个把错误处理解耦的一种方式。

如果没有异常处理支持，函数执行出现一些错误时，要么通过返回值返回，要么通过设置传入的参数，或者设置全局的errno（但一般仍要通过返回值表示出错了，再度errno确定具体错误）。

这种方式明显占用了函数的返回值，并且调用者需要时刻注意对函数执行结果的检查（所以往往需要对这种风格的错误处理进行函数封装），非常的不方便。

但有了异常处理，函数的参数和返回值只需要专注于业务本身，不在考虑错误处理。`try/catch`块也避免了每个函数调用都要进行错误检查，并且通过抛出不同的异常类型，可以轻松的为不同的异常定义的不同的处理方式。

`[[noreture]]`告诉编译器函数无需返回，用在`void`返回类型的函数上。

### mutable关键字

用该关键字修饰的变量，可在const函数中被修改。

成员函数后加const的函数，则该函数无法改变任何类成员状态，但有时需要在该函数中修改与类状态无关的成员，mutable修饰的变量则在其中被修改。

### std::vector<>::push_back & emplace_back

经过编程实验，`push_back()`效率稍低的原因在于始终需要一个构造出一个对象，才能执行拷贝构造或者移动构造。

```cpp
#include <vector> 
#include <iostream> 
using namespace std;
class testDemo
{
public:
    testDemo(int num):num(num){
        std::cout << "调用构造函数" << endl;
    }
    testDemo(const testDemo& other) :num(other.num) {
        std::cout << "调用拷贝构造函数" << endl;
    }
    testDemo(testDemo&& other) :num(other.num) {
        std::cout << "调用移动构造函数" << endl;
    }
private:
    int num;
};

int main()
{
    cout << "emplace_back:" << endl;
    std::vector<testDemo> demo1;
    demo1.emplace_back(2);  

    cout << "push_back:" << endl;
    std::vector<testDemo> demo2;
    demo2.push_back(2);
}
```

输出如下：

```sh
emplace_back:
调用构造函数
push_back:
调用构造函数
调用移动构造函数
```

可以看到`push_back()`多一次构造函数。

推测应该是整型2隐式构造的临时对象。因为如果，是均传入已构造好的对象（无论是左右值）这两个函数的结果均相同。`push_back`同样有右值重载函数，只需要一次移动构造即可。

确实如此，这是由`emplace_back`与`push_back`实现上的区别引起的，`emplace_back`使用变长模板参数，是得这里传入的2，直接传递到`emplace_back`内部，其再以`new placement`的方式调用构造函数直接构造即可。

但`push_back`没法直接传递到内部，只能有由编译器做隐式类型转换，构造一个临时对象传递。
