#include <stdio.h>
#include <unistd.h>
#include <fcntl.h>
#include <string.h>
#include <sys/ioctl.h>
#include "chrdev_mod.h"

char *wbuf = "Hello World\n";
char rbuf[128];

int main(void)
{
    printf("EmbedCharDev test\n");
    //打开文件
    int fd = open("/dev/my_chrdev_driver", O_RDWR);
    //写入数据
    write(fd, wbuf, strlen(wbuf));
    /* ioctl write */
    ioctl(fd, IOCTL_OP_WRITE_BUF, 1);

    /* ioctl read */
    ioctl(fd, IOCTL_OP_READ_BUF, 1);

    //写入完毕，关闭文件
    close(fd);
    //打开文件
     fd = open("/dev/my_chrdev_driver", O_RDWR);
    //读取文件内容
    read(fd, rbuf, 128);
    //打印读取的内容
    printf("The content : %s\n", rbuf);
    //读取完毕，关闭文件
    close(fd);
    return 0;
}