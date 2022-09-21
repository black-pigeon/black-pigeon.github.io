obj-m += chrdev_mod.o
kmod = chrdev_mod.ko
TEST=tb_chrdev
KERNEL_SRC=/home/mp/sdr_opensource/kernel-source-e320

ARCH=arm
CROSS_COMPILE=arm-linux-gnueabihf-
export  ARCH  CROSS_COMPILE

all:
	make -C  $(KERNEL_SRC) M=$(PWD) modules
	$(CROSS_COMPILE)gcc -o $(TEST) $(PWD)/app/$(TEST).c

clean:
	make -C $(KERNEL_SRC) M=$(PWD) clean

copy:
	scp $(kmod) xilinx@192.168.10.2:
	scp $(TEST) xilinx@192.168.10.2:
	
