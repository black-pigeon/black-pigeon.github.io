---
title: cpp-09-特殊数据成员与成员函数
date: 2023-11-27 09:40:27
tags: ["C++"]
categories: C++
comment: true
mathjax: true
---
# 1. 特殊的数据成员
在C++的类中，有4种比较特殊的数据成员，他们分别是**常量成员**、**引用成员**、**类对象成员**和**静态成员**，他们的初始化与普通数据成员有所不同。
<!--more-->
## 1.1 常量数据成员
当数据成员用const关键字进行修饰以后，就成为常量成员。一经初始化，该数据成员便具有“**只读属性**”，在程序中无法对其值修改。事实上，在构造函数体内初始化const数据成员是**非法的**，它们**只能在构造函数初始化列表**中进行初始化。
如下所示：
```cpp
#include <iostream>

using std::cout;
using std::endl;

class Point{
public:
    Point(int x, int y, int z)
    :_x(10)
    ,_y(10){
        cout << "Point With parameter" << endl;
        _z = z;
    }

    Point(const Point& p)
    :_x(p._x)
    ,_y(p._y)
    ,_z(p._z){
        cout << "copy constructor" << endl;
    }

    ~Point(){
        cout << "destructor" << endl;
    }
    
    void print_info(){
        cout << "(" << _x
             <<"," << _y
             <<"," << _z
             <<")" << endl;
    }

private:
    const int _x;
    const int _y;
    int _z;
};


void test(){
    Point p1(0,1,1);
    p1.print_info();

    Point p2 = p1;
    p2.print_info();
}

int main(int argc, char* argv[])
{
    test();


    return 0;
}

```


## 1.2 引用数据成员
和常量数据成员相同，引用数据成员也必须在构造函数的初始化列表当中进行初始化，否则编译会报错。这需要考虑到引用的定义，需要进行绑定。


## 1.3 类对象成员
当数据成员本身也是自定义类类型对象时，比如一个直线类Line对象中包含两个Point类对象，对Point对象的创建就必须要放在Line的构造函数的初始化列表中进行。
```cpp
#include <iostream>

using std::cout;
using std::endl;

class Point{
public:
    Point(int x, int y)
    :_x(x)
    ,_y(y){
        cout << "Point With parameter" << endl;
    }

    Point(const Point& p)
    :_x(p._x)
    ,_y(p._y){
        cout << "copy constructor" << endl;
    }

    ~Point(){
        cout << "destructor" << endl;
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

class Line{
public:
    Line(int x1, int y1, int x2, int y2)
    :p1(x1, y1)
    ,p2(x2, y2){
        cout << "Constructor of line" << endl;

    }
    ~Line(){
        cout << "Deconstructor of line" << endl;
    }

    void print_info(){
        p1.print_info();
        p2.print_info();
    }

private:
    Point p1;
    Point p2;

};


void test(){
    Line l1(1,1,2,2);
    l1.print_info();
}

int main(int argc, char* argv[])
{
    test();


    return 0;
}
```
当Line的构造函数没有在其初始化列表中初始化对象_pt1和_pt2时，系统也会自动调用Point类的默认构造函数，此时就会与预期的构造不一致。因此需要显式在Line的构造函数初始化列表中初始化_pt1和_pt2对象。

## 1.4 静态数据成员
C++允许使用static（静态存储）修饰数据成员，这样的成员在编译时就被创建并初始化的（与之相比，对象是在运行时被创建的），且其实例只有一个，被所有该类的对象共享，静态数据成员和之前介绍的静态变量一样，当程序执行时，该成员已经存在，一直到程序结束，**任何该类对象都可对其进行访问**，静态数据成员存储在**全局/静态区**，并不占据对象的存储空间。

因为静态数据成员不属于类的任何一个对象，所以它们并不是在创建类对象时被定义的。这意味着它们不是由类的的构造函数初始化的，一般来说，我们不能在类的内部初始化静态数据成员，必须在类的外部定义和初始化静态数据成员，且不再包含static关键字，格式如下:
静态成员被整个类的所有对象共享。
```cpp
类型 类名::变量名 = 初始化表达式; //普通变量
类型 类名::对象名(构造参数); //对象变量
```

```cpp
#include <iostream>
#include <string.h>
using std::cout;
using std::endl;

class Computer{
public:
    Computer(const char * brand, float price)
    :_brand(new char[strlen(brand)+1]())
    ,_price(price){
        cout << "Computer(const char*, float) :" <<  this << endl;
	    strcpy(_brand, brand);
        _totle_price += price;
    }

    Computer(const Computer & p)
    :_brand(p._brand)
    ,_price(p._price){
        cout << "Copy comstructor: " <<  this << endl;
    }

    ~Computer(){
        cout << "Destructor resource free" << this << endl;
        if (_brand) {
            cout << "brand:" <<_brand <<" price:" << _price << endl;
            delete [] _brand;
            _brand=nullptr;
            cout << "Destructor ~Computer()" << endl;
        }
       
    }

    void set_price(float price);

    void print_info();

private:
    char * _brand;
    float _price;
    static float _totle_price;
};


void Computer::set_price(float price){
    _price = price;
}

void Computer::print_info(){
    cout << "brand: " << _brand << endl;
    cout << "price: " << _price << endl;
    cout << "totle_price: " << _totle_price << endl;
}

float Computer::_totle_price = 0;

void test(){
    Computer c1("ccc", 300);
    c1.print_info();

    Computer c2("ddd", 300);
    c2.print_info();
    cout << "test end" << endl;

}

int main(int argc, char* argv[])
{
    test();
    cout << "program finished" <<endl;

    return 0;
}
```


# 2. 特殊的成员函数
除了特殊的数据成员以外，C++类中还有两种特殊的成员函数：静态成员函数和 const 成员函数。

## 2.1 静态成员函数
成员函数也可以定义成静态的，静态成员函数的特点:
1. 静态成员函数内部不能使用非静态的数据成员和非静态的成员函数
2. 静态成员函数内部只能调用静**态数据成员和静态的成员函数**
3. 静态成员函数没有this指针存在
4. 静态成员函数可以直接通过类名调用，不需要对象存在
5. 不能是析构函数/构造函数/赋值运算符函数
原因在于静态成员函数的参数列表中不含有隐含的 this 指针。
```cpp
#include <iostream>
#include <string.h>
using std::cout;
using std::endl;

class Computer{
public:
    Computer(const char * brand, float price)
    :_brand(new char[strlen(brand)+1]())
    ,_price(price){
        cout << "Computer(const char*, float) :" <<  this << endl;
	    strcpy(_brand, brand);
        _totle_price += price;
    }

    Computer(const Computer & p)
    :_brand(p._brand)
    ,_price(p._price){
        cout << "Copy comstructor: " <<  this << endl;
    }

    ~Computer(){
        cout << "Destructor resource free" << this << endl;
        if (_brand) {
            cout << "brand:" <<_brand <<" price:" << _price << endl;
            delete [] _brand;
            _brand=nullptr;
            cout << "Destructor ~Computer()" << endl;
        }
       
    }
    static void print_total_price(){
        cout << "total proce is: " << _totle_price << endl;
    }

    void set_price(float price);

    void print_info();

private:
    char * _brand;
    float _price;
    static float _totle_price;
};


void Computer::set_price(float price){
    _price = price;
}

void Computer::print_info(){
    cout << "brand: " << _brand << endl;
    cout << "price: " << _price << endl;
    cout << "totle_price: " << _totle_price << endl;
}

float Computer::_totle_price = 0;

void test(){
    Computer c1("ccc", 300);

    Computer c2("ddd", 300);

    Computer::print_total_price();

}

int main(int argc, char* argv[])
{
    test();
    cout << "program finished" <<endl;

    return 0;
}
```

## 2.2 const 成员函数
之前已经介绍了const在函数中的应用，实际上，const在类成员函数中还有种特殊的用法，把const关键字放在函数的参数表和函数体之间（与之前介绍的const放在函数前修饰返回值不同），称为const成员函数，其具有以下特点:
1. 只能读取类数据成员，而不能修改之。
2. 只能调用const成员函数，不能调用非const成员函数。

```cpp
类型 函数名(参数列表) const
{
函数体
}
```

```cpp
class Computer
{
public:
//...
void print() const
{
cout << "品牌:" << _brand << endl
     << "价格:" << _price << endl;
}
//...
};
```

const对象只能调用const成员函数，只有const成员函数不会改变数据成员的值，只读

```cpp
#include <iostream>
#include <string.h>
using std::cout;
using std::endl;

class Computer{
public:
    Computer(const char * brand, float price)
    :_brand(new char[strlen(brand)+1]())
    ,_price(price){
        cout << "Computer(const char*, float) :" <<  this << endl;
	    strcpy(_brand, brand);
        _totle_price += price;
    }

    Computer(const Computer & p)
    :_brand(p._brand)
    ,_price(p._price){
        cout << "Copy comstructor: " <<  this << endl;
    }

    ~Computer(){
        cout << "Destructor resource free" << this << endl;
        if (_brand) {
            cout << "brand:" <<_brand <<" price:" << _price << endl;
            delete [] _brand;
            _brand=nullptr;
            cout << "Destructor ~Computer()" << endl;
        }
       
    }

    void set_price(float price);

    void print_info() const{
        cout << "brand: " << _brand << endl;
        cout << "price: " << _price << endl;
        cout << "totle_price: " << _totle_price << endl;
    }


private:
    char * _brand;
    float _price;
    static float _totle_price;
};


void Computer::set_price(float price){
    _price = price;
}


float Computer::_totle_price = 0;

void test(){
    const Computer c1("ccc", 300);

    // c1.set_price(100) // error
    c1.print_info();


}

int main(int argc, char* argv[])
{
    test();
    cout << "program finished" <<endl;

    return 0;
}
```