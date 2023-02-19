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

### Misc

`decltype(<expr>)`得到expr的声明类型
`declval(<expr>)`在编译期得道一个expr类型的对象


### 右值引用与智能指针

所谓右值即各种临时对象。
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

对于常量表达式cxx03本身就会在编译期计算，而constexpr则把常量的概念扩展到了常量函数和类上。

如:
```cpp
constexpr int get_v(){
    return 0;
}

// 如此一来编译器就知道了该像对待常量一样深入分析该函数是否是常量
static const int a = 1 + get_v();
```
