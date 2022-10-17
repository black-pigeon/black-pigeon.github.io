obj-m += chrdev_gpio.o
kmod = chrdev_gpio.ko
TEST=app/tb_chrdev
KERNEL_SRC=/home/mp/wcc_demo/firmware_update/plutosdr-fw-e310/linux

ARCH=arm
CROSS_COMPILE=arm-linux-gnueabihf-
export  ARCH  CROSS_COMPILE




all:
	make -C  $(KERNEL_SRC) M=$(CURDIR) modules
	$(CROSS_COMPILE)gcc -o $(TEST) $(CURDIR)/$(TEST).c

.PHONE: clean copy
clean:
	make -C $(KERNEL_SRC) M=$(PWD) clean
	rm $(TEST)

copy:
	scp $(kmod) ubuntu@192.168.1.10:
	scp $(TEST) ubuntu@192.168.1.10:
	
