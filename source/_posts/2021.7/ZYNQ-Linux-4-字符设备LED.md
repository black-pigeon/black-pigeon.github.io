---
title: ZYNQ-Linux--4-字符设备LED
date: 2021-07-28 22:25:59
tags: Linux
categories: Linux
comment: true
mathjax: true
---
## 1. Linux驱动LED
在前面学习了字符设备的驱动，当时实现的是一个虚拟的字符设备。能够完成简单的数据的发送和接收的工作。在实际的使用中LED在linux当中也属于字符设备。所以第一个点灯实验就可以在Linux的字符设备的基础上进行操作了。
在使用到实际的物理设备的时候，需要在linux当中使用到一个MMU设备，这个设备能够完成地址的映射等工作。

### 1.1 MMU 
MMU全称叫做Memory Manage Unit,也就是内存管理单元,其完成的功能主要有：
- 完成虚拟空间到物理空间的映射。
- 内存保护，设置存储器的访问权限，设置虚拟存储空间的缓冲特性

对于内存的映射，是相较于实际的物理内存和操作系统支持的最大的寻址范围来说的。对于32位处理器，最大的寻址范围是2^32=4GB。对于实际的物理设备，可能寻址空间没有这么大，比如ZYNQ上PS侧的DDR的最大容量为1GB，有了MMU这个工具，就能够完成这个１GB的物理内存到4GB的虚拟内存空间的一个转换。
完成物理地址到虚拟地址的映射需要使用的函数如下：

```c
/*
@param: paddr： 被映射的IO起始地址（物理地址）；
@param: size： 需要映射的空间大小，以字节为单位；
@return: 一个指向__iomem类型的指针，当映射成功后便返回一段虚拟地址空间的起始地址，我们可以通过访问这段虚拟地址来实现实际物理地址的读写操作
*/
void __iomem *ioremap(phys_addr_t paddr, unsigned long size)
```
当将物理地址映射为虚拟地址之后，我们就可以通过linux提供的一些函数来访问对应的地址了，常见的访问虚拟地址的函数是。
```c
u8 readb(const volatile void __iomem *addr)
u16 readw(const volatile void __iomem *addr)
u32 readl(const volatile void __iomem *addr)

void writeb(u8 value, volatile void __iomem *addr)
void writew(u16 value, volatile void __iomem *addr)
void writel(u32 value, volatile void __iomem *addr)
```
可以看到这些函数的作用分别是向对应的虚拟地址写入或读取一字节两字节和四字节长度的数据。

## 2. ZYNQ PS LED寄存器
使用在这里如果使用直接查找寄存器的方式来进行字符设备的驱动，其实和开发裸机程序没有什么太大的区别，只是在这里需要将物理地址进行一个映射才可以。
```c
#include <linux/types.h>
#include <linux/kernel.h>
#include <linux/delay.h>
#include <linux/ide.h>
#include <linux/init.h>
#include <linux/module.h>
#include <linux/errno.h>
#include <linux/gpio.h>
#include <asm/mach/map.h>
#include <asm/uaccess.h>
#include <asm/io.h>
#include <linux/fs.h>
#include <linux/cdev.h>
#include <linux/uaccess.h>

#define DEVICE_NAME     "ZynqLed"
#define DEVICE_NUM      (1)

/* 定义字符设备的设备号 */
static dev_t dev_no;
/* 定义字符设备结构体 */
static struct cdev char_dev;

/* 
 * GPIO相关寄存器地址定义
 */
#define ZYNQ_GPIO_REG_BASE			0xE000A000
#define DATA_OFFSET					0x00000044
#define DIRM_OFFSET					0x00000244
#define OUTEN_OFFSET				0x00000248
#define INTDIS_OFFSET				0x00000254
#define APER_CLK_CTRL				0xF800012C

/* 映射后的寄存器虚拟地址指针 */
static void __iomem *data_addr;
static void __iomem *dirm_addr;
static void __iomem *outen_addr;
static void __iomem *intdis_addr;
static void __iomem *aper_clk_ctrl_addr;


/*
 * @description		: 打开设备
 * @param – inode	: 传递给驱动的inode
 * @param - filp	: 设备文件，file结构体有个叫做private_data的成员变量
 * 					  一般在open的时候将private_data指向设备结构体。
 * @return			: 0 成功;其他 失败
 */
static int led_open(struct inode *inode, struct file *filp)
{
	return 0;
}

/*
 * @description		: 从设备读取数据 
 * @param - filp	: 要打开的设备文件(文件描述符)
 * @param - buf		: 返回给用户空间的数据缓冲区
 * @param - cnt		: 要读取的数据长度
 * @param - offt	: 相对于文件首地址的偏移
 * @return			: 读取的字节数，如果为负值，表示读取失败
 */
static ssize_t led_read(struct file *filp, char __user *buf,
			size_t cnt, loff_t *offt)
{
	return 0;
}

/*
 * @description		: 向设备写数据 
 * @param - filp	: 设备文件，表示打开的文件描述符
 * @param - buf		: 要写给设备写入的数据
 * @param - cnt		: 要写入的数据长度
 * @param - offt	: 相对于文件首地址的偏移
 * @return			: 写入的字节数，如果为负值，表示写入失败
 */
static ssize_t led_write(struct file *filp, const char __user *buf,
			size_t cnt, loff_t *offt)
{
	int ret;
	int val;
	char kern_buf[1];

	ret = copy_from_user(kern_buf, buf, cnt);	// 得到应用层传递过来的数据
	if(0 > ret) {
		printk(KERN_ERR "kernel write failed!\r\n");
		return -EFAULT;
	}

	val = readl(data_addr);
	if (0 == kern_buf[0])
		val &= ~(0x1U << 18);		// 如果传递过来的数据是0则关闭led
	else if (1 == kern_buf[0])
		val |= (0x1U << 18);			// 如果传递过来的数据是1则点亮led

	writel(val, data_addr);
	return 0;

}

/*
 * @description		: 关闭/释放设备
 * @param – filp	: 要关闭的设备文件(文件描述符)
 * @return			: 0 成功;其他 失败
 */
static int led_release(struct inode *inode, struct file *filp)
{
	return 0;
}

/* 设备操作函数 */
static struct file_operations led_fops = {
	.owner		= THIS_MODULE,
	.open		= led_open,
	.read		= led_read,
	.write		= led_write,
	.release	= led_release,
};

static int __init led_init(void)
{
	u32 val;
	int ret;

	/* 寄存器地址映射 */
	data_addr = ioremap(ZYNQ_GPIO_REG_BASE + DATA_OFFSET, 4);
	dirm_addr = ioremap(ZYNQ_GPIO_REG_BASE + DIRM_OFFSET, 4);
	outen_addr = ioremap(ZYNQ_GPIO_REG_BASE + OUTEN_OFFSET, 4);
	intdis_addr = ioremap(ZYNQ_GPIO_REG_BASE + INTDIS_OFFSET, 4);
	aper_clk_ctrl_addr = ioremap(APER_CLK_CTRL, 4);

	/* 使能GPIO时钟 */
	val = readl(aper_clk_ctrl_addr);
	val |= (0x1U << 22);
	writel(val, aper_clk_ctrl_addr);

	/* 关闭中断功能 */
	val |= (0x1U << 18);
	writel(val, intdis_addr);

	/* 设置GPIO为输出功能 */
	val = readl(dirm_addr);
	val |= (0x1U << 18);
	writel(val, dirm_addr);

	/* 使能GPIO输出功能 */
	val = readl(outen_addr);
	val |= (0x1U << 18);
	writel(val, outen_addr);

	/* 默认关闭LED */
	val = readl(data_addr);
	val &= ~(0x1U << 18);
	writel(val, data_addr);

    printk(KERN_EMERG "chrdev init!!!\n");
    /* 采用动态分配的方式获取设备号 */
    ret = alloc_chrdev_region(&dev_no, 0, DEVICE_NUM, DEVICE_NAME);
    if(ret < 0){
        printk(KERN_EMERG "fail to alloc devno\n");
        goto alloc_err;
    }

    /* 关联字符设备结构体与文件操作结构体 */
    cdev_init(&char_dev, &led_fops);

    /* 添加字符设备到哈希表当中 */
    ret = cdev_add(&char_dev, dev_no, DEVICE_NUM);
    if(ret <0)
    {
        printk(KERN_EMERG "failed to add char device\r\n");
        goto add_err;
    }
    return 0;

add_err:
    /* 如果添加字符设备失败，需要注销设备号 */
    unregister_chrdev_region(dev_no, DEVICE_NUM);

alloc_err:
    return ret;
}

static void __exit led_exit(void)
{
	/* 注销字符设备 */
    unregister_chrdev_region(dev_no, DEVICE_NUM);
    cdev_del(&char_dev);

	/* 2.取消内存映射 */
	iounmap(data_addr);
	iounmap(dirm_addr);
	iounmap(outen_addr);
	iounmap(intdis_addr);
	iounmap(aper_clk_ctrl_addr);
}

/* 驱动模块入口和出口函数注册 */
module_init(led_init);
module_exit(led_exit);

MODULE_AUTHOR("wcc");
MODULE_DESCRIPTION("char led");
MODULE_LICENSE("GPL");s
```

## 2.2测试程序
```c
#include <stdio.h>
#include <unistd.h>
#include <sys/types.h>
#include <sys/stat.h>
#include <fcntl.h>
#include <stdlib.h>
#include <string.h>

/*
 * @description		: main主程序
 * @param - argc	: argv数组元素个数
 * @param - argv	: 具体参数
 * @return			: 0 成功;其他 失败
 */
int main(int argc, char *argv[])
{
	int fd, ret;
	unsigned char buf[1];

	if(3 != argc) {
		printf("Usage:\n"
		"\t./ledApp /dev/led 1		@ close LED\n"
		"\t./ledApp /dev/led 0		@ open LED\n"
		);
		return -1;
	}

	/* 打开设备 */
	fd = open(argv[1], O_RDWR);
	if(0 > fd) {
		printf("file %s open failed!\r\n", argv[1]);
		return -1;
	}

	/* 将字符串转换为int型数据 */
	buf[0] = atoi(argv[2]);

	/* 向驱动写入数据 */
	ret = write(fd, buf, sizeof(buf));
	if(0 > ret){
		printf("LED Control Failed!\r\n");
		close(fd);
		return -1;
	}

	/* 关闭设备 */
	close(fd);
	return 0;
}
```

之后就和前面的字符设备的驱动测试是类似的，使用mknod创建一个设备节点之后，就可以进行led的亮灭的驱动了。
