#ifndef __CHRDEV_MOD_H
#define __CHRDEV_MOD_H

#define IOCTL_MAGIC          'r'

#define IOCTL_OP_WRITE_BUF      _IOW(IOCTL_MAGIC, 0, int)
#define IOCTL_OP_READ_BUF       _IOR(IOCTL_MAGIC, 0, int)

#endif