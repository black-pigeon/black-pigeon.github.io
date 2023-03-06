KERN_DIR := /home/mp/wcc_demo/axi/linux-xlnx

obj-m := my-axi-led-ctrl.o

all:
	make ARCH=arm CROSS_COMPILE=arm-linux-gnueabihf- -C $(KERN_DIR) M=`pwd` modules

clean:
	make -C $(KERN_DIR) M=`pwd` clean
