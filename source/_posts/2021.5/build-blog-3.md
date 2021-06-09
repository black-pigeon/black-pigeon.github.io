---
title: 建立博客(3)
date: 2021-05-15 14:16:36
tags: 博客
categories: 博客
comments: true
---
在前面使用Next主题建立好博客之后，我们就有了一个用于搭建自己的博客的模板了，接下来就可以来发布文章了。hexo比较好的一点就是能够将markdown文件最终转换成静态的网页文件，这样，对于我这种小白就只需要知道markdown文件如何来写就行了。
<!--more-->
# 1. 新建文章
使用hexo创建一个新的文章十分简单。可以使用
```bash
hexo new post "postname"
```
来创建一个新的文章，使用该命令之后会在source/_post文件夹下面新建一个markdown文件，文件名就是刚才使用命令时的文件名。
在这里可以进行文件头的设置
![文件头](文件头.png)
在这个文件头中，title就是最终会显示到博客中的文章的题目，date就是博客创立的时间，tags和categories会该该博客收录到对应的tags和categories里面，这样能够很方便地来管理博客。
comments是一个附加的功能，需要有插件的支持，能够使其他人在看到你的博客后留下评论。
## 1.1 文章当中显示图片
在hexo生成的网页里面经常会出现图片无法查看的问题，但是当我们在本地编写markdown文件的时候又能够看到图片，这是因为hexo生成网页之后其中的资源的路径会发生变化的原因，为了解决图片无法查看的问题，我也在网上找了一些办法，最终找到一个博客里给出了面对这种问题的解决办法。其链接地址如下：
[解决办法](https://www.jianshu.com/p/f72aaad7b852)

  - 在根目录下执行以下命令
  ```bash
  npm install hexo-asset-image --save
  ```
  - 修改hexo的配置文件
 打开hexo的配置文件_config.yml,找到 `post_asset_folder `选项,将其属性更改为true。
 ![post_asset](post_asset.png)
 -  修改 `/node_modules/hexo-asset-image/index.js`文件的内容
找到上面的文件，使用以下内容进行替换
```js
'use strict';
var cheerio = require('cheerio');

// http://stackoverflow.com/questions/14480345/how-to-get-the-nth-occurrence-in-a-string
function getPosition(str, m, i) {
  return str.split(m, i).join(m).length;
}

var version = String(hexo.version).split('.');
hexo.extend.filter.register('after_post_render', function(data){
  var config = hexo.config;
  if(config.post_asset_folder){
        var link = data.permalink;
    if(version.length > 0 && Number(version[0]) == 3)
       var beginPos = getPosition(link, '/', 1) + 1;
    else
       var beginPos = getPosition(link, '/', 3) + 1;
    // In hexo 3.1.1, the permalink of "about" page is like ".../about/index.html".
    var endPos = link.lastIndexOf('/') + 1;
    link = link.substring(beginPos, endPos);

    var toprocess = ['excerpt', 'more', 'content'];
    for(var i = 0; i < toprocess.length; i++){
      var key = toprocess[i];
 
      var $ = cheerio.load(data[key], {
        ignoreWhitespace: false,
        xmlMode: false,
        lowerCaseTags: false,
        decodeEntities: false
      });

      $('img').each(function(){
        if ($(this).attr('src')){
            // For windows style path, we replace '\' to '/'.
            var src = $(this).attr('src').replace('\\', '/');
            if(!/http[s]*.*|\/\/.*/.test(src) &&
               !/^\s*\//.test(src)) {
              // For "about" page, the first part of "src" can't be removed.
              // In addition, to support multi-level local directory.
              var linkArray = link.split('/').filter(function(elem){
                return elem != '';
              });
              var srcArray = src.split('/').filter(function(elem){
                return elem != '' && elem != '.';
              });
              if(srcArray.length > 1)
                srcArray.shift();
              src = srcArray.join('/');
              $(this).attr('src', config.root + link + src);
              console.info&&console.info("update link as:-->"+config.root + link + src);
            }
        }else{
            console.info&&console.info("no src attr, skipped...");
            console.info&&console.info($(this));
        }
      });
      data[key] = $.html();
    }
  }
});
```
- 新建文件并显示图片
现在想要在文章中显示图片就比较简单了，使用`hexo new post `之后会在_post文件夹下生成一个和文章同名的文件夹，我们只需要把图片资源放到这个文件夹下面就可以了。
然后在引用的时候只需要在markdown当中使用如下格式进行引用就可以了。
`![图片名称](图片.jpeg)`

# 2. 文章评论功能与阅读统计
想要知道文章的阅读量和添加频率的功能是需要一些第三方插件的支持的。这里可以参考这个博客上写的，写得很详细了，直接查阅就行了。
[添加阅读统计和评论的方法](https://www.jianshu.com/p/a4300e2cb616)

# 3. FIN
博客搭建就告一段落了，接下来要开始干正事了。博客搭建网上很多，多找找总能搞到自己喜欢的，总归是能够进步的。
