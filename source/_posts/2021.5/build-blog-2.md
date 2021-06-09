---
title: 建立博客-(2)
date: 2021-05-14 15:14:39
tags: 博客
categories: 博客
comments: true
---
在前面的博客当中介绍了如何使用hexo来创建一个博客，并使用github来部署博客。得到了一个最基础的博客模板，在这个文章当中会介绍如何使用和配置一下[NexT](https://github.com/theme-next/hexo-theme-next)主题。
本篇博客主要参考这位作者的：[Next主题配置](https://www.jianshu.com/p/e4db4f7ed45f)
<!--more-->
# 1. 安装next
在博客根目录下使用git命令将NexT主题可克隆到themes文件夹下面。
```bash
git clone https://github.com/theme-next/hexo-theme-next themes/next
```
可以在themes下面看到下载下来的next主题
![next](next.png)
然后可以将hexo的配置文件`_config.yml`中的主题设置为next。
![修改主题](修改主题.png)
然后我们就可以在本地调试当中，来看看更换主题之后的样子了。
```bash
hexo clean 
hexo g
hexo s
```
# 2. 主题配置
接下来就可以配置主题了。next主题的配置文件在`themes/next/_config.yml`下，我们的主题主要修改的地方也就在这个里面了。

## 2.1 page创建
使用hexo的时候，用于创建文章一般都是使用`hexo new post "blog-name"`, hexo也可以用来创建一个新的页面，也就我们点击对应的地方会跳转到一个新的页面当中，这需要使用到`hexo new page page_name`
在Next的配置主题当中，为我们提供了几个模板页面，需要使用到那些界面就使能对应的页面,下方的icon设置可以用来显示图标。
![menu设置](menu设置.png)

![页面](页面.png)
现在已经使能了这些页面了，那么如何在博客上反应出来，当点击了对应的位置会跳转到对应的页面当中呢。
这时候就需要使用`hexo new page page_name`来创建新的页面了。
```bash
hexo new page about
hexo new page  tags
hexo new page  categories
hexo new page  archives
```
这时候我们看到在source目录下面就新生成了几个文件夹，分别对应着page的名字。
![生成页面](生成页面.png)
在生成的这几个page中，需要在markdown文本中添加一些语句，让其能够和对应的归类联系起来。比如：
![页面分类.png](页面分类.png)

## 2.2 联系方式设置
next主题里面很贴心地准备了一些联系方式，这样当别人想要通过博客联系到你的时候就可以很轻松地找到你了。
找到social选项，然后使能对应的联系方式，没有的也可以自己添加，前面是显示的联系方式的名称后续是网址或者邮箱。
![联系方式](联系方式.png)

## 2.3 头像设置
在avatar中设置是否在侧边栏中显示头像，头像的源文件需要保存在`themes/next/source/images/`下面，这样才能正确地找到这个头像。
![头像设置](头像设置.png)

## 2.4 样式设置
Schemes方案设置有以下几种，选择一种你喜欢的就好。
```yml
# Schemes
#scheme: Muse
scheme: Mist
#scheme: Pisces
#scheme: Gemini
```
到这里我们就能够完成一个博客的基本的搭建了，其他什么需要设置的，可以参考其他人的设置，主要修改_config.yml文件就可以了。

# 3.部署文件
设置完成之后，就可以部署网站了。和前面的博客一样，使用hexo来部署网页。
```bash
hexo clean
hexo g
hexo d
```
这样就能够把生成的文件部署到github上了。
但是当前我们只是把生成的网页文件用github进行了部署，对于源文件，我们还没有部署。这个我们可以使用git，创建一个分支，然后把这个分支push上去就好了。
在这里创建一个`.gitignore`文件，把不需要管理的文件忽略掉。
.gitignore文件内容如下

```
.DS_Store
Thumbs.db
db.json
*.log
node_modules/
public/
.deploy*/
```
然后使用git来新建一个分支，把这个分支push到github对应的分支上。这样就能够完成管理，于此同时也就可以在不同的地方来完成博客的建立了。
```c
git branch hexo
git checkout hexo 
git add .
git commit -m "initial repo"
git push origin dev:dev
```
![新分支](新分支.png)
