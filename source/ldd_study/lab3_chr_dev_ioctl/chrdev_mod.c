#include <linux/module.h>
#include <linux/init.h>
#include <linux/kernel.h>
#include <linux/cdev.h>
#include <linux/fs.h>
#include <linux/uaccess.h>
#include "chrdev_mod.h"

#define DRIVER_NAME "my_chrdev_driver"
#define BUFF_SIZE 	128



/* Meta Information */
MODULE_LICENSE("GPL");
MODULE_AUTHOR("wcc");
MODULE_DESCRIPTION("A char device LKM");


static struct cdev my_chrdev;
dev_t dev_no;

static struct class *my_class = NULL;
static struct device * my_device = NULL;

static char vbuf[BUFF_SIZE];

ssize_t my_chrdev_read(struct file * inode, char __user * buf, size_t count, loff_t * ppos)
{
	printk("my_chrdev: read ... \n");
	unsigned long p = *ppos;
    int ret;
    int tmp = count ;
    static int i = 0;
    i++;
    if(p >= BUFF_SIZE)
        return 0;
    if(tmp > BUFF_SIZE - p)
        tmp = BUFF_SIZE - p;
    ret = copy_to_user(buf, vbuf+p, tmp);
    *ppos +=tmp;
    return tmp;
}

ssize_t my_chrdev_write(struct file * inode, const char __user * buf, size_t count, loff_t * ppos)
{
	printk("my_chrdev: write ...\n");
	unsigned long p = *ppos;
    int ret;
    int tmp = count ;
    if(p > BUFF_SIZE)
        return 0;
    if(tmp > BUFF_SIZE - p)
        tmp = BUFF_SIZE - p;
    ret = copy_from_user(vbuf, buf, tmp);
    *ppos += tmp;
    return tmp;
}

int my_chrdev_open (struct inode *inode, struct file *filp)
{
	printk("my_chrdev: open ... \n");
	
	return 0;
}
int my_chrdev_close (struct inode *inode, struct file *filp)
{
	printk("my_chrdev: close ... \n");
	return 0;
}


long my_chrdev_ioctl (struct file * filp, unsigned int cmd, unsigned long arg){

	switch (cmd) {
		case IOCTL_OP_WRITE_BUF:
			printk("my_chrdev: ioctl write buf \n");
			break;

		case IOCTL_OP_READ_BUF:
			printk("my_chrdev: ioctl read buf \n");
			break;

		default: break;
	}
	return 0;
}

static struct file_operations my_chrdev_ops = {
    .owner = THIS_MODULE,
    .open = my_chrdev_open,
    .release = my_chrdev_close,
    .write = my_chrdev_write,
    .read = my_chrdev_read,
	.unlocked_ioctl = my_chrdev_ioctl
};

/**
 * @brief This function is called, when the module is loaded into the kernel
 */
static int __init my_init(void) {

	printk("my_chrdev: Hello, Kernel!\n");
	/* alloc char device region */
	int ret = alloc_chrdev_region(&dev_no, 0, 1, DRIVER_NAME);
	if (ret < 0) {
		printk("my_chrdev: alloc chrdev region failed \n");
		goto alloc_err;
	}

	/* init char device */
	cdev_init(&my_chrdev, &my_chrdev_ops);

	/* add chrdev to kernel */
	ret = cdev_add(&my_chrdev, dev_no, 1);
	if (ret < 0) {
		printk("my_chrdev: add error\n");
		goto add_err;
	}
	
	/* create a class for auto create */
	my_class = class_create(THIS_MODULE, DRIVER_NAME);
	if (IS_ERR(my_class)) {
		printk("my_chrdev: create class erorr ...\n");
		ret = PTR_ERR(my_class);
		goto class_err;
	}

	/* create device for auto create */
	my_device = device_create(my_class, NULL, dev_no, NULL, DRIVER_NAME);
	if (IS_ERR(my_device)) {
		printk("my_chrdev: create device error... \n");
		ret = PTR_ERR(my_device);
		goto device_err;
	}
	printk("my_chrdev: init driver success \n");
	return 0;
device_err: 
	class_destroy(my_class);

class_err:
	cdev_del(&my_chrdev);

add_err:
	unregister_chrdev_region(dev_no, 1);

alloc_err:
	return ret;
}

/**
 * @brief This function is called, when the module is removed from the kernel
 */
static void __exit my_exit(void) {
	cdev_del(&my_chrdev);
	unregister_chrdev_region(dev_no, 1);
	device_destroy(my_class, dev_no);
	class_destroy(my_class);
	printk("my_chrdev: Goodbye, Kernel\n");
}

module_init(my_init);
module_exit(my_exit);


