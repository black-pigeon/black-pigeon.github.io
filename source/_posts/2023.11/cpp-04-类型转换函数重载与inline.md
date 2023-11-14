---
title: cpp-04-类型转换函数重载与inline
date: 2023-11-14 19:38:39
tags: ["C++"]
categories: C++
comment: true
mathjax: true
---
# cpp的类型转换
在C当中，类型转换的风格很简单：
```cpp
TYPE a = （TYPE）EXPRESSION;
```
直接将要转换的变量前面加上需要的目标类型。
C风格的类型转换可以在任意类型之间转换。比如可以把一个指向const对象的指针转换成指向非const对象的指针，把一个指向基类对象的指针转换成指向一个派生类对象的指针。这在某些时候是比较危险的。

CPP引进了4个新的类型转换操作符，他们是static_cast，const_cast，dynamic_cast，reinterpret_cast。
在这几种类型转换当中使用得最多的应该是static_cast。
下面举个简单的例子来说明cpp当中的类型转换。
```cpp
#include <iostream>
using std::cout;
using std::endl;


void test0() 
{
    int i_data = 10;
    float f_data = 0.0;
    f_data = static_cast<float>(i_data);

    cout << "f_data:" << f_data << endl;

    int *intp = static_cast<int*>(malloc(sizeof(int)));
    *intp = 1;
    cout << "*intp:" << *intp << endl;
} 
 
int main(void)
{
	test0();
	return 0;
}

```
![](cpp-04-类型转换函数重载与inline/image1.png)

const_cast的作用是去除常量属性。可以将常量在进行传递给其他函数的时候进行常量属性的去除，这个在某些时候会导致一些问题。下面是一个简单的例子来说明这个问题。
```cpp
#include <iostream>
using std::cout;
using std::endl;

void display_info(int *p){
    *p = 10;
    cout <<"*p:" << *p << endl;
    cout <<"p:" << p << endl;
}

void test0() 
{
    const int a =1;

    display_info(const_cast<int *>(&a));
    cout <<"a:" << a << endl;
    cout <<"&a:" << &a << endl;
} 
 
int main(void)
{
	test0();
	return 0;
}

```
![](cpp-04-类型转换函数重载与inline/image2.png)
可以看到，在去除常量属性之后，我们可以在display_info这个函数当中修改传入指针所指向的值。但是比较逆天的一点就来了，我们可以看到两个地址一样的地方，得到的地址里面的值竟然不一样。。。还没有深入去研究这里有什么问题。