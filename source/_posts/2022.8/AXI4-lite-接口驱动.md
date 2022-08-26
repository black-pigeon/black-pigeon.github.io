---
title: AXI4-lite 接口驱动
date: 2022-08-21 16:11:17
tags: ["zynq", "linux"]
categories: linux
comment: true
mathjax: true
---

# 1. 前言
对于FPGA开发人员来说，可能会开发一些自己自定义的IP，这些IP一般可以通过axi接口连接到处理器上，对于zynq来说，在FPGA这边编写一些axi4-lite的接口之后，zynq句能够通过axi4-lite接口来访问PL端的寄存器了。
这样就能够控制IP的一些参数。

在裸机下面，控制这些IP的驱动都是比较简单的，如果是需要在linux下面想要控制这些IP，就需要自己去实现这些IP的驱动了。

在本篇博客当中会记录，这种IP的接口驱动开发。
<!--more-->

# 2. 驱动开发
对于AXI4-Lite的FPGA实现，对于我这种还算是熟悉FPGA开发的人来说，就没有必要再去详细记录了。在之后可以对AXI接口专门出一个详细的介绍。

本次博客以一个最简单的驱动LED灯的工程来介绍AXI4-lite的接口驱动开发。zynq ps的操作系统需要能够访问当其中的一个寄存器，并且将值写入到寄存当中，这个寄存器的值的最低四位，将会去驱动板子上的4个led灯的亮灭。

首先可以看看这个驱动的头文件：
```c
#define AXI_LED_CTRL_DEVICE_NAME 		"my-axi-led-ctrl"
#define AXI_LED_CTRL_DRIVER_NAME 		"my-axi-led-ctrl"

// #define AXI_LED_CTRL_DEVICE_MAJOR_NUMBER 	232

#define MAGIC_AXI_LED_CTRL 't'

#define IOCTL_AXI_LED_CTRL_SET_VALUE		_IOW ( MAGIC_AXI_LED_CTRL, 1, int )
#define IOCTL_AXI_LED_CTRL_GET_VALUE		_IOR ( MAGIC_AXI_LED_CTRL, 2, int ) 
```
在这个驱动当中，实现了两个IOCTL的功能，一个用于向寄存器当中写入数据，一个用于从读取寄存器的值。

下面是设备树：
内核在启动之后，回去读取设备树当中的内容，并且会去检测设备树当中的compatible字段，如果内核的驱动当中有域设备树当中的compatible字段相同的字段，那么内核就会加载这个驱动，从而这个硬件设备就能够拥有自己的驱动程序了。
```c
/ {
	amba_pl: amba_pl {
		#address-cells = <1>;
		#size-cells = <1>;
		compatible = "simple-bus";
		ranges ;
		my_axi_led_ctrl_0: my_axi_led_ctrl@43c00000 {
			/* This is a place holder node for a custom IP, user may need to update the entries */
			clock-names = "s00_axi_aclk";
			clocks = <&clkc 15>;
			compatible = "xlnx,my-axi-led-ctrl-1.0";
			reg = <0x43c00000 0x10000>;
			xlnx,s00-axi-addr-width = <0x4>;
			xlnx,s00-axi-data-width = <0x20>;
		};
	};
};
```

下面是驱动程序：
```c
#include <linux/module.h>
#include <linux/kernel.h>
#include <linux/types.h>
#include <linux/ioport.h>
#include <linux/interrupt.h>
#include <linux/fcntl.h>
#include <linux/init.h>
#include <linux/poll.h>
#include <linux/proc_fs.h>
#include <linux/mutex.h>
#include <linux/sysctl.h>
#include <linux/fs.h>
#include <linux/cdev.h>
#include <linux/platform_device.h>
#include <linux/slab.h>
#include <linux/io.h>
#include <linux/uaccess.h>
#include <linux/dma-mapping.h>

#include <linux/of_address.h>
#include <linux/of_device.h>
#include <linux/of_platform.h>
#include "my-axi-led-ctrl.h"




struct my_axi_led_ctrl_local {
	unsigned long mem_start;
	unsigned long mem_end;
	void __iomem *base_addr;
	struct device * dev;
	struct cdev cdev;
	dev_t devt;
};

static struct class *driver_class;

static int 	__init my_module_init(void);
static void __exit my_module_exit(void);




//////////////////////////////////////////////////////////////////////////////////////////
//
// File Operations Open Character Device 
//
//////////////////////////////////////////////////////////////////////////////////////////
static int my_axi_led_ctrl_open (struct inode *inode, struct file *filp)
{
	struct my_axi_led_ctrl_local *lp;
	
	//printk ("my_axi_led_ctrl : driver_open \n");
	
	lp = container_of(inode->i_cdev, struct my_axi_led_ctrl_local, cdev);
	
	filp->private_data = lp;
	
	return 0; 
}

//////////////////////////////////////////////////////////////////////////////////////////
//
// File Operations Close Character Device
//
//////////////////////////////////////////////////////////////////////////////////////////
static int my_axi_led_ctrl_close (struct inode *inode, struct file *filp)
{
	printk ( KERN_INFO "axi_led_ctrl : device closed.\n" );

	return (0);
}

//////////////////////////////////////////////////////////////////////////////////////////////////////
//
// User Reads from Character Device
//
//////////////////////////////////////////////////////////////////////////////////////////////////////
static ssize_t my_axi_led_ctrl_read (struct file * filp, char *buff, size_t count, loff_t * ppos)  {
	
	//printk ( KERN_INFO "axi_led_ctrl : reading the output buffer\n" );
	
	return (count);
}

//////////////////////////////////////////////////////////////////////////////////////////////////////
//
// my_axi_led_ctrl_write
//
//////////////////////////////////////////////////////////////////////////////////////////////////////
// User Writes to Character Device
static ssize_t my_axi_led_ctrl_write (struct file * filp, __user const char *buff, size_t count, loff_t * ppos)  {
	
	//printk ( KERN_INFO "axi_led_ctrl : writing to input buffer .\n" );
	
	return ( count ); 

}

///////////////////////////////////////////////////////////////////////////////////////////////////////////////////
//
// character device ioctl 
//
///////////////////////////////////////////////////////////////////////////////////////////////////////////////////

long axi_led_ctrl_ioctl(struct file *filep, unsigned int cmd, unsigned long arg)  {
	
	struct my_axi_led_ctrl_local *lp = filep->private_data;
	unsigned int tmpVal; 
	unsigned int retValue; 
	
	retValue = 0;
	
	switch ( cmd )  {
		
		case IOCTL_AXI_LED_CTRL_SET_VALUE: 
			
			printk ( KERN_INFO "set pl led value...\n" ); 
			
			tmpVal = (unsigned int)arg; 
			iowrite32  ( tmpVal, lp->base_addr + 0x0 );
			
			break; 
			
		case IOCTL_AXI_LED_CTRL_GET_VALUE: 
			
			// read the register 
			printk ( KERN_INFO "%s:%i reading the status of pl led.\n", __FUNCTION__, __LINE__ ); 
			
			tmpVal = ioread32 ( lp->base_addr + 0x4 ); 
			__put_user ( tmpVal, (unsigned int __user *) arg ); 
			
			break; 
			
		default:;
	}
	return retValue;
}


static struct file_operations my_axi_led_ctrl_fops =
{
	.owner = THIS_MODULE,
	.read = my_axi_led_ctrl_read,
	.write = my_axi_led_ctrl_write,
	.open = my_axi_led_ctrl_open,
	.release = my_axi_led_ctrl_close,
	.unlocked_ioctl = axi_led_ctrl_ioctl, 
};


static int my_axi_led_ctrl_probe(struct platform_device *pdev)
{
	struct resource *r_irq; /* Interrupt resources */
	struct resource *r_mem; /* IO mem resources */
	struct device *dev = &pdev->dev;
	struct my_axi_led_ctrl_local *lp = NULL;

	int rc = 0;

	dev_t devt;
	int retval = 0;

	dev_info(dev, "Device Tree Probing\n");
	/* Get iospace for the device */
	r_mem = platform_get_resource(pdev, IORESOURCE_MEM, 0);
	if (!r_mem) {
		dev_err(dev, "invalid address\n");
		return -ENODEV;
	}
	lp = (struct my_axi_led_ctrl_local *) kmalloc(sizeof(struct my_axi_led_ctrl_local), GFP_KERNEL);
	if (!lp) {
		dev_err(dev, "Cound not allocate my-axi-led-ctrl device\n");
		return -ENOMEM;
	}
	dev_set_drvdata(dev, lp);
	lp->mem_start = r_mem->start;
	lp->mem_end = r_mem->end;

	if (!request_mem_region(lp->mem_start,
				lp->mem_end - lp->mem_start + 1,
				AXI_LED_CTRL_DRIVER_NAME)) {
		dev_err(dev, "Couldn't lock memory region at %p\n",
			(void *)lp->mem_start);
		rc = -EBUSY;
		goto error1;
	}

	lp->base_addr = ioremap(lp->mem_start, lp->mem_end - lp->mem_start + 1);
	if (!lp->base_addr) {
		dev_err(dev, "my-axi-led-ctrl: Could not allocate iomem\n");
		rc = -EIO;
		goto error2;
	}

	dev_info(dev,"my-axi-led-ctrl at 0x%08x mapped to 0x%08x\n",
		(unsigned int __force)lp->mem_start,
		(unsigned int __force)lp->base_addr);
	

	/***********************************************************************
	 * register character device	
	***********************************************************************/
	printk("my-axi-led-ctrl: register character device...\n");
	alloc_chrdev_region(&devt, 0, 0, AXI_LED_CTRL_DEVICE_NAME);
	lp->devt = devt;
	cdev_init(&lp->cdev, &my_axi_led_ctrl_fops);
	lp->cdev.owner = THIS_MODULE;

	retval = cdev_add(&lp->cdev, devt, 1);
	if (retval)
	{
		printk("my_axi_led_ctrl_of_probe: cdev_add() failed \n");
		goto error2;
	}

	return 0;
	
error2:
	release_mem_region(lp->mem_start, lp->mem_end - lp->mem_start + 1);
error1:
	kfree(lp);
	dev_set_drvdata(dev, NULL);
	return rc;
}

static int my_axi_led_ctrl_remove(struct platform_device *pdev)
{
	struct device *dev = &pdev->dev;
	struct my_axi_led_ctrl_local *lp = dev_get_drvdata(dev);

	cdev_del(&lp->cdev);

	iounmap(lp->base_addr);
	release_mem_region(lp->mem_start, lp->mem_end - lp->mem_start + 1);
	kfree(lp);
	dev_set_drvdata(dev, NULL);
	return 0;
}

static struct of_device_id my_axi_led_ctrl_of_match[] = {
	{ .compatible = "xlnx,my-axi-led-ctrl-1.0", },
	{ /* end of list */ },
};
MODULE_DEVICE_TABLE(of, my_axi_led_ctrl_of_match);



static struct platform_driver my_axi_led_ctrl_driver = {
	.driver = {
		.name = "my_axi_led_ctrl",
		.owner = THIS_MODULE,
		.of_match_table	= my_axi_led_ctrl_of_match,
	},
	.probe		= my_axi_led_ctrl_probe,
	.remove		= my_axi_led_ctrl_remove,
};


static int __init my_module_init(void)
{
	int ret_val; 
		
	platform_driver_register ( &my_axi_led_ctrl_driver );
	
	printk ( KERN_INFO "my-axi-led-ctrl : init ...\n"); 
	
	return 0;
}

//////////////////////////////////////////////////////////////////////////////////////////
//
// Exit The Driver
//
//////////////////////////////////////////////////////////////////////////////////////////
static void __exit my_module_exit(void)
{
	
	printk ( KERN_INFO "my-axi-led-ctrl: exit...\n" ); 
	
	return;
}

module_init( my_module_init );
module_exit( my_module_exit );

/* Standard module information, edit as appropriate */
MODULE_LICENSE("GPL");
MODULE_AUTHOR("Chaochen Wei.");
MODULE_DESCRIPTION("my-axi-led-ctrl - loadable module template generated by petalinux-create -t modules");

```
可以简单介绍一下这个驱动当中比较重要的一些东西：

- 设备结构体
    在platform 驱动里面，一般都会有一个和硬件设备相对应的结构体。下面这个结构体就是我们这个简单的驱动和PL的AXI-LED IP对应的结构体。
    首先有mem_start/mem_end这两个变量，这两个变量指的是该IP实际的物理地址。
    然后是一个指针 base_addr，这个指针的是该IP在经过映射之后在内存当中的虚拟地址。
    然后有一个struct device *dev这样一个成员，这个结构提的作用是platform driver里面常用的，可以用来打印消息，或者是用来进行dma映射的。
    最后还有一个字符设备的成员，这个成员的作用是能够给user level application 提供一个接口，这样用就能够通过通过操作字符设备提供的接口来控制我们的硬件设备了。
    ```c
    struct my_axi_led_ctrl_local {
        unsigned long mem_start;
        unsigned long mem_end;
        void __iomem *base_addr;
        struct device * dev;
        struct cdev cdev;
        dev_t devt;
    };
    ```
- probe函数与匹配表
    ```c
    static struct of_device_id my_axi_led_ctrl_of_match[] = {
        { .compatible = "xlnx,my-axi-led-ctrl-1.0", },
        { /* end of list */ }
    };
    MODULE_DEVICE_TABLE(of, my_axi_led_ctrl_of_match);

    static struct platform_driver my_axi_led_ctrl_driver = {
        .driver = {
            .name = "my_axi_led_ctrl",
            .owner = THIS_MODULE,
            .of_match_table	= my_axi_led_ctrl_of_match,
        },
        .probe		= my_axi_led_ctrl_probe,
        .remove		= my_axi_led_ctrl_remove,
    };

    static int __init my_module_init(void)
    {
        int ret_val; 
            
        platform_driver_register ( &my_axi_led_ctrl_driver );
        
        printk ( KERN_INFO "my-axi-led-ctrl : init ...\n"); 
        
        return 0;
    }
    ```
    一般驱动的入口都是 xx__init()，在我们的这个驱动当中也是如此，通过platform总线来注册驱动。在platform总线驱注册的时候，回去获取设备树当中的内容，并且和of_match_table进行一个比较，如果匹配上了，就会注册对应的驱动。
    在probe函数当中，一般的初始化操作当中都是放在这个里面的，比如获取这个设备的物理地址，完成地址的映射等等操作。我们的驱动在peobe函数里面还实现了一个字符设备的注册。
    在peobe函数当中，首先会根据设备树的内容获取到地址信息，然后为这个设备在完成地址的映射。这里面我们就可以把前面的那个设备结构体当中物理起始地址和虚拟地址填充进去了。
    ```c
    /* Get iospace for the device */
	r_mem = platform_get_resource(pdev, IORESOURCE_MEM, 0);
	if (!r_mem) {
		dev_err(dev, "invalid address\n");
		return -ENODEV;
	}
	lp = (struct my_axi_led_ctrl_local *) kmalloc(sizeof(struct my_axi_led_ctrl_local), GFP_KERNEL);
	if (!lp) {
		dev_err(dev, "Cound not allocate my-axi-led-ctrl device\n");
		return -ENOMEM;
	}
	dev_set_drvdata(dev, lp);
	lp->mem_start = r_mem->start;
	lp->mem_end = r_mem->end;

	if (!request_mem_region(lp->mem_start,
				lp->mem_end - lp->mem_start + 1,
				AXI_LED_CTRL_DRIVER_NAME)) {
		dev_err(dev, "Couldn't lock memory region at %p\n",
			(void *)lp->mem_start);
		rc = -EBUSY;
		goto error1;
	}

	lp->base_addr = ioremap(lp->mem_start, lp->mem_end - lp->mem_start + 1);
	if (!lp->base_addr) {
		dev_err(dev, "my-axi-led-ctrl: Could not allocate iomem\n");
		rc = -EIO;
		goto error2;
	}

	dev_info(dev,"my-axi-led-ctrl at 0x%08x mapped to 0x%08x\n",
		(unsigned int __force)lp->mem_start,
		(unsigned int __force)lp->base_addr);
	
    ```
    再这之后，我们实现了一个字符设备的驱动的添加，这样的目的是让这个IP能够提供一些接口给用户进行使用：
    ```c
    printk("my-axi-led-ctrl: register character device...\n");
	alloc_chrdev_region(&devt, 0, 0, AXI_LED_CTRL_DEVICE_NAME);
	lp->devt = devt;
	cdev_init(&lp->cdev, &my_axi_led_ctrl_fops);
	lp->cdev.owner = THIS_MODULE;

	retval = cdev_add(&lp->cdev, devt, 1);
	if (retval)
	{
		printk("my_axi_led_ctrl_of_probe: cdev_add() failed \n");
		goto error2;
	}

	return 0;
    ```

- 字符设备的操作函数
    对于字符设备，很自然地就会想到对字符设备的操作，在驱动当中我们也需要去完成对应的open，read，write，release，ioctl等操作。
    ```c
    //////////////////////////////////////////////////////////////////////////////////////////
    //
    // File Operations Open Character Device 
    //
    //////////////////////////////////////////////////////////////////////////////////////////
    static int my_axi_led_ctrl_open (struct inode *inode, struct file *filp)
    {
        struct my_axi_led_ctrl_local *lp;
        
        //printk ("my_axi_led_ctrl : driver_open \n");
        
        lp = container_of(inode->i_cdev, struct my_axi_led_ctrl_local, cdev);
        
        filp->private_data = lp;
        
        return 0; 
    }

    //////////////////////////////////////////////////////////////////////////////////////////
    //
    // File Operations Close Character Device
    //
    //////////////////////////////////////////////////////////////////////////////////////////
    static int my_axi_led_ctrl_close (struct inode *inode, struct file *filp)
    {
        printk ( KERN_INFO "axi_led_ctrl : device closed.\n" );

        return (0);
    }

    //////////////////////////////////////////////////////////////////////////////////////////////////////
    //
    // User Reads from Character Device
    //
    //////////////////////////////////////////////////////////////////////////////////////////////////////
    static ssize_t my_axi_led_ctrl_read (struct file * filp, char *buff, size_t count, loff_t * ppos)  {
        
        //printk ( KERN_INFO "axi_led_ctrl : reading the output buffer\n" );
        
        return (count);
    }

    //////////////////////////////////////////////////////////////////////////////////////////////////////
    //
    // my_axi_led_ctrl_write
    //
    //////////////////////////////////////////////////////////////////////////////////////////////////////
    // User Writes to Character Device
    static ssize_t my_axi_led_ctrl_write (struct file * filp, __user const char *buff, size_t count, loff_t * ppos)  {
        
        //printk ( KERN_INFO "axi_led_ctrl : writing to input buffer .\n" );
        
        return ( count ); 

    }

    ///////////////////////////////////////////////////////////////////////////////////////////////////////////////////
    //
    // character device ioctl 
    //
    ///////////////////////////////////////////////////////////////////////////////////////////////////////////////////

    long axi_led_ctrl_ioctl(struct file *filep, unsigned int cmd, unsigned long arg)  {
        
        struct my_axi_led_ctrl_local *lp = filep->private_data;
        unsigned int tmpVal; 
        unsigned int retValue; 
        
        retValue = 0;
        
        switch ( cmd )  {
            
            case IOCTL_AXI_LED_CTRL_SET_VALUE: 
                
                printk ( KERN_INFO "set pl led value...\n" ); 
                
                tmpVal = (unsigned int)arg; 
                iowrite32  ( tmpVal, lp->base_addr + 0x0 );
                
                break; 
                
            case IOCTL_AXI_LED_CTRL_GET_VALUE: 
                
                // read the register 
                printk ( KERN_INFO "%s:%i reading the status of pl led.\n", __FUNCTION__, __LINE__ ); 
                
                tmpVal = ioread32 ( lp->base_addr + 0x4 ); 
                __put_user ( tmpVal, (unsigned int __user *) arg ); 
                
                break; 
                
            default:;
        }
        return retValue;
    }


    static struct file_operations my_axi_led_ctrl_fops =
    {
        .owner = THIS_MODULE,
        .read = my_axi_led_ctrl_read,
        .write = my_axi_led_ctrl_write,
        .open = my_axi_led_ctrl_open,
        .release = my_axi_led_ctrl_close,
        .unlocked_ioctl = axi_led_ctrl_ioctl, 
    };
    ```
    在字符设备的驱动当中，我们主要关注的是提供给用户的这个IOCTL的操作函数，前面的头文件当中，我们定义了一系列的IOCTL命令，在IOCTL这个函数当中，我们就能够根据不同的命令来实现不同的功能了。


- 驱动卸载
    当要卸载驱动的时候，起始就是释放和关闭已经申请的资源的过程：
    ```c
    static int my_axi_led_ctrl_remove(struct platform_device *pdev)
    {
        struct device *dev = &pdev->dev;
        struct my_axi_led_ctrl_local *lp = dev_get_drvdata(dev);

        cdev_del(&lp->cdev);

        iounmap(lp->base_addr);
        release_mem_region(lp->mem_start, lp->mem_end - lp->mem_start + 1);
        kfree(lp);
        dev_set_drvdata(dev, NULL);
        return 0;
    }
    //////////////////////////////////////////////////////////////////////////////////////////
    //
    // Exit The Driver
    //
    //////////////////////////////////////////////////////////////////////////////////////////
    static void __exit my_module_exit(void)
    {
        
        printk ( KERN_INFO "my-axi-led-ctrl: exit...\n" ); 
        
        return;
    }

    ```

# 3. 用户程序编写
为了能够验证对这个的驱动，我们可以编写一个简单的用户程序来加载驱动，并且试着通过IOCTL来控制板子上的硬件，测试代码如下，该程序很简单，就是像操作字符设备一样去操作我们的IP的驱动就可以了，最终我们可以看到板子上的几个LED等在依次闪烁。
```c

#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <fcntl.h>
#include <errno.h>
#include <sys/socket.h>
#include <arpa/inet.h> 		//inet_addr
#include <unistd.h>    		//write
#include <time.h>
#include <sys/ioctl.h>		/* ioctl */
#include <sys/sendfile.h>
#include <sys/mman.h>
#include "my-axi-led-ctrl.h"

int main(int argc, char **argv)
{
    printf("Hello World!\n");
    unsigned int ret_val = 0; 
    unsigned char my_axi_led_ctrl_node[128] = "/dev/my-axi-led-ctrl";
    int my_axi_led_ctrl_handle = 0;

    my_axi_led_ctrl_handle = open ( my_axi_led_ctrl_node, O_RDWR );
	
	if ( my_axi_led_ctrl_handle < 0 ) {
		printf ("user level: %s can not be opened.\n", my_axi_led_ctrl_node ); 
		exit(-1);
	}
    while(1){
        ioctl ( my_axi_led_ctrl_handle, IOCTL_AXI_LED_CTRL_SET_VALUE, 0b1110 );
        sleep(1) ;
        ioctl ( my_axi_led_ctrl_handle, IOCTL_AXI_LED_CTRL_SET_VALUE, 0b1101 );
        sleep(1) ;
        ioctl ( my_axi_led_ctrl_handle, IOCTL_AXI_LED_CTRL_SET_VALUE, 0b1011 );
        sleep(1) ;
        ioctl ( my_axi_led_ctrl_handle, IOCTL_AXI_LED_CTRL_SET_VALUE, 0b0111 );
        sleep(1) ;
    }

    close(my_axi_led_ctrl_handle);
    
    return 0;
}


```