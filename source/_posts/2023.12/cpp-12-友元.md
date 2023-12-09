---
title: cpp-12-友元
date: 2023-12-09 10:56:50
tags: ["C++"]
categories: C++
comment: true
mathjax: true
---
一般来说，类的私有成员只能在类的内部访问，类之外是不能访问它们的。但如果将其他类或函数设置为类的友元（friend），就可以访问了。用这个比喻形容友元可能比较恰当：将类比作一个家庭，类的private成员相当于家庭的秘密，一般的外人是不允许探听这些秘密的，只有friend（朋友）才有能力探听这些秘密。
友元的形式可以分为**友元函数**和**友元类**.
在类中的生命方式如下：
```cpp
class 类名
{
//...
friend 函数原型;
friend class 类名;
//...
}
```
<!--more-->

友元一共有三种使用方式，如下面的代码所示：
```cpp
#include <iostream>
#include <string.h>
#include <math.h>
using std::cout;
using std::endl;
using std::hypot;

class Point; //类的前向声明
class Line{
public:
    float distance(const Point &lhs, const Point &rhs);
    float distance(const Point &lhs, int x1, int y1);
};



class Point{
    friend float distance(const Point &lhs, const Point rhs); // 全局函数友元
    friend float Line::distance(const Point &lhs, const Point &rhs); // 类成员函数为友元
    friend Line; // 类为友元
public:
    Point(int x, int y){
        cout << "Point With parameter" << endl;
        _x = x;
        _y = y;
    }

    Point(){
        cout << "Point Without parameter" << endl;
    }

    Point(const Point& p)
    :_x(p._x)
    ,_y(p._y){
        cout << "copy constructor" << endl;
    }

    ~Point(){
        cout << "destructor" << endl;
    }

    

    void set_loc(int x, int y){
        _x = x;
        _y = y;
    }

    void print_info(){
        cout << "(" << _x
             <<"," << _y
             <<")" << endl;
    }

private:
    int _x;
    int _y;
};



// 全局函数distance是Point类的友元函数
float distance(const Point &lhs, const Point rhs){
    return hypot(lhs._x-rhs._x, lhs._y-rhs._y); //友元函数可以访问到类中的私有成员
}

float Line::distance(const Point &lhs, const Point &rhs){
    return hypot(lhs._x-rhs._x, lhs._y-rhs._y); //友元函数可以访问到类中的私有成员
};

float Line::distance(const Point &lhs, int x1, int y1){
    return hypot(lhs._x-x1, lhs._y-y1); //友元函数可以访问到类中的私有成员
};



void test(){
    Point p1(0,1);
    p1.print_info();

    Point p2(1,2);

    float distance1 = distance(p1, p2);
    cout << "distance1: " << distance1 << endl;

    Line l1;
    float distance2 = l1.distance(p1, p2);
    cout << "distance2: " << distance2 << endl;

    Line l2;
    float distance3 = l2.distance(p1, 1, 5);
    cout << "distance3: " << distance3 << endl;
}

int main(int argc, char* argv[])
{
    test();


    return 0;
}
```

不可否认，友元在一定程度上将类的私有成员暴露出来，破坏了信息隐藏机制，似乎是种“副作用很大的药”，但俗话说“良药苦口”，好工具总是要付出点代价的，拿把锋利的刀砍瓜切菜，总是要注意不要割到手指的。
友元的存在，使得类的接口扩展更为灵活，使用友元进行运算符重载从概念上也更容易理解一些，而且，C++规则已经极力地将友元的使用限制在了一定范围内，它是单向的、不具备传递性、不能被继承，所以，应尽力合理使用友元。
**注意：友元的声明是不受public/protected/private关键字限制的。**