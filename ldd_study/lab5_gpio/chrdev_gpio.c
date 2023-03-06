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
#include <linux/cdev.h>
#include <linux/of.h>
#include <linux/of_address.h>
#include <linux/of_gpio.h>

#include "chrdev_gpio.h"

#define DRIVER_NAME "my_chrdev_driver"
#define BUFF_SIZE 	128



/* Meta Information */
MODULE_LICENSE("GPL");
MODULE_AUTHOR("wcc");
MODULE_DESCRIPTION("A char device LKM");


struct chrdev_local{
	struct cdev cdev;
	dev_t dev_no;
	struct class *my_class ;
	struct device * my_device;
	struct device_node *nd;
	int gpio_num;
};

static struct chrdev_local my_chrdev_local;

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
	int ret;
	printk("my_chrdev: open ... \n");
	struct chrdev_local * lp;
	/* get the char device */
	lp =  container_of(inode->i_cdev, struct chrdev_local, cdev);
	filp->private_data = lp;
	
	/* get the gpio */
	lp->gpio_num = of_get_named_gpio(lp->nd, "led-gpio", 0);
	if(!gpio_is_valid(lp->gpio_num)) {
		printk(KERN_ERR "my_chrdev: Failed to get led-gpio\n");
		return -EINVAL;
	}

	/* gpio request */
	ret = gpio_request(lp->gpio_num, "GPIO_LED0");
	if (ret < 0) {
		printk("my_chrdev: Failed to request gpio\n");
		return ret;
	}

	/* set the gpio direction */
	gpio_direction_output(lp->gpio_num, 0);
	
	return 0;
}
int my_chrdev_close (struct inode *inode, struct file *filp)
{
	printk("my_chrdev: close ... \n");

	struct chrdev_local * lp;
	lp = filp->private_data;

	gpio_free(lp->gpio_num);
	return 0;
}


long my_chrdev_ioctl (struct file * filp, unsigned int cmd, unsigned long arg){

	struct chrdev_local * lp;
	lp = filp->private_data;

	switch (cmd) {
		case IOCTL_SET_0:
			gpio_set_value(lp->gpio_num, 0);
			printk("my_chrdev: ioctl set gpio to 0 \n");
			break;

		case IOCTL_SET_1:
			gpio_set_value(lp->gpio_num,1);
			printk("my_chrdev: ioctl set gpio to 1\n");
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
	const char *str;
	int ret;
	printk("my_chrdev: Hello, Kernel!\n");

	/* get device node from dts */
	my_chrdev_local.nd = of_find_node_by_path("/leds");
	if(NULL == my_chrdev_local.nd) {
		printk("leds node can not found!\r\n");
		return -EINVAL;
	}

	/* get device node status */
	ret = of_property_read_string(my_chrdev_local.nd, "status", &str);
	if(ret < 0) {
		printk("my_chrdev: dts does not have status property\n");
	}

	/* compatible driver */
	ret = of_property_read_string(my_chrdev_local.nd, "compatible", &str);
	if (ret < 0) {
		printk("my_chrdev: the device node don't have a compatible string\n");
		return -EINVAL;
	}

	if (strcmp(str, "microphase,gpio-led")) {
		printk("my_chrdev: current driver don't support the device node\n");
		return -EINVAL;
	}

	printk("my_chrdev: gpio led driver match!!!\n");

	/* alloc char device region */
	alloc_chrdev_region(&my_chrdev_local.dev_no, 0, 1, DRIVER_NAME);
	if (ret < 0) {
		printk("my_chrdev: alloc chrdev region failed \n");
		goto alloc_err;
	}

	/* init char device */
	cdev_init(&my_chrdev_local.cdev, &my_chrdev_ops);

	/* add chrdev to kernel */
	ret = cdev_add(&my_chrdev_local.cdev, my_chrdev_local.dev_no, 1);
	if (ret < 0) {
		printk("my_chrdev: add error\n");
		goto add_err;
	}
	
	/* create a class for auto create */
	my_chrdev_local.my_class = class_create(THIS_MODULE, DRIVER_NAME);
	if (IS_ERR(my_chrdev_local.my_class)) {
		printk("my_chrdev: create class erorr ...\n");
		ret = PTR_ERR(my_chrdev_local.my_class);
		goto class_err;
	}

	/* create device for auto create */
	my_chrdev_local.my_device = device_create(my_chrdev_local.my_class, NULL,
											 my_chrdev_local.dev_no, NULL, DRIVER_NAME);
	if (IS_ERR(my_chrdev_local.my_device)) {
		printk("my_chrdev: create device error... \n");
		ret = PTR_ERR(my_chrdev_local.my_device);
		goto device_err;
	}
	printk("my_chrdev: init driver success \n");
	return 0;
device_err: 
	class_destroy(my_chrdev_local.my_class);

class_err:
	cdev_del(&my_chrdev_local.cdev);

add_err:
	unregister_chrdev_region(my_chrdev_local.dev_no, 1);

alloc_err:
	return ret;
}

/**
 * @brief This function is called, when the module is removed from the kernel
 */
static void __exit my_exit(void) {
	cdev_del(&my_chrdev_local.cdev);
	unregister_chrdev_region(my_chrdev_local.dev_no, 1);
	device_destroy(my_chrdev_local.my_class, my_chrdev_local.dev_no);
	class_destroy(my_chrdev_local.my_class);
	printk("my_chrdev: Goodbye, Kernel\n");
}

module_init(my_init);
module_exit(my_exit);


