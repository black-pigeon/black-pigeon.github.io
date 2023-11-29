---
title: cpp-11-字符串
date: 2023-11-29 09:47:04
tags: ["C++"]
categories: C++
comment: true
mathjax: true
---
# 1. C风格字符串
字符串处理在程序中应用广泛，C风格字符串是以'\0'（空字符）来结尾的字符数组。对字符串进行操作的C函数定义在头文件<string.h>或中。常用的库函数如下：
```cpp
//字符检查函数(非修改式操作)
size_t strlen( const char *str );//返回str的长度，不包括null结束符
//比较lhs和rhs是否相同。lhs等于rhs,返回0; lhs大于rhs，返回正数; lhs小于rhs，返回负数
int strcmp( const char *lhs, const char *rhs );
int strncmp( const char *lhs, const char *rhs, size_t count );
//在str中查找首次出现ch字符的位置；查找不到，返回空指针
char *strchr( const char *str, int ch );
//在str中查找首次出现子串substr的位置；查找不到，返回空指针
char *strstr( const char* str, const char* substr );
//字符控制函数(修改式操作)
char *strcpy(char *dest, const char *src);//将src复制给dest，返回dest
char *strncpy(char *dest, const char *src, size_t count);
char *strcat( char *dest, const char *src );//concatenates two strings
char *strncat( char *dest, const char *src, size_t count );
```
在使用时，程序员需要考虑字符数组大小的开辟，结尾空字符的处理，使用起来有诸多不便。
<!--more-->
```cpp
#include <string.h> //C风格字符串头文件
#include <iostream>
#include <string>   //C++风格字符串头文件
using std::cout;
using std::endl;
using std::string;
 
void test0() 
{
    char str [] = "hello";
    char * pstr = "world";
    
    // 求取字符串长度
    cout << "sizeof str: " << strlen(str) << endl;

    //字符串拼接
    char * tmp = (char *) malloc(strlen(str) + strlen(pstr) + 1);
    strcpy(tmp, str);
    strcat(tmp, pstr);
    cout << "tmp string: " << tmp << endl;

    char *p1=strstr(tmp, "wor");

    free(tmp); 
} 

 
int main(void)
{
	test0(); 
	// test1();

	return 0;
}

```

# 2. C++风格字符串
C++提供了std::string（后面简写为string）类用于字符串的处理。string类定义在C++头文件中，注意和头文件区分，其实是对C标准库中的<string.h>的封装，其定义的是一些对C风格字符串的处理函数。

尽管C++支持C风格字符串，但在C++程序中最好还是不要使用它们。这是因为C风格字符串不仅使用起来不太方便，而且极易引发程序漏洞，是诸多安全问题的根本原因。与C风格字符串相比，string不必担心内存是否足够、字符串长度，结尾的空白符等等。string作为一个类出现，其集成的成员操作函数功能强大，几乎能满足所有的需求。从另一个角度上说，完全可以string当成是C++的内置数据类型，放在和int、double等内置类型同等位置上。string类本质上其实是basic_string类模板关于char型的实例化。
```cpp
#include <string.h> //C风格字符串头文件
#include <iostream>
#include <string>   //C++风格字符串头文件
using std::cout;
using std::endl;
using std::string;
 
void test0() 
{
    string s1 = "hello";
    string s2("world");

    //求取长度
    cout << "size of s1: " << s1.size() << endl;
    cout << "length of s1: " << s1.length() << endl;

    //字符串拼接
    string s3 = s1 + s2;
    cout << "s3: " << s3 << endl;

    //转换为c风格字符串
    const char * s4 = s3.c_str();
    cout << "s4: " << s4 << endl;

    //查找子串
    size_t pos = s3.find("wor");

    //截取子串
    string substr = s3.substr(pos);
    cout << "pos: " << pos << " substr: "<< substr << endl;


 
} 

 
int main(void)
{
	test0(); 
	// test1();


	return 0;
}
```