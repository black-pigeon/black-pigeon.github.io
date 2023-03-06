#ifndef __CHRDEV_MOD_H
#define __CHRDEV_MOD_H

#define IOCTL_MAGIC          'r'

#define IOCTL_SET_0      _IOW(IOCTL_MAGIC, 0, int)
#define IOCTL_SET_1       _IOR(IOCTL_MAGIC, 0, int)

#endif