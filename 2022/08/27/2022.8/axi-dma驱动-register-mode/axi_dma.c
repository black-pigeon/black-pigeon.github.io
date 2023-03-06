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
#include "axi_dma.h"




struct axi_dma_ctrl_local {
	int irq_mm2s;
	int irq_s2mm;
	unsigned long mem_start;
	unsigned long mem_end;
	void __iomem *base_addr;

    dma_addr_t dma_buffer_physical_address_mm2s[DRIVER_DMA_NUMBER_OF_BUFFERS_MM2S];
	void * dma_buffer_virtual_address_mm2s[DRIVER_DMA_NUMBER_OF_BUFFERS_MM2S];
	
	dma_addr_t dma_buffer_physical_address_s2mm[DRIVER_DMA_NUMBER_OF_BUFFERS_S2MM];
	void * dma_buffer_virtual_address_s2mm[DRIVER_DMA_NUMBER_OF_BUFFERS_S2MM];
	
	struct device *dev;
	struct cdev cdev;	/* Char device structure */
	dev_t devt;
	struct class *driver_class;
	
	unsigned int s2mm_pointer; 				// buffer pointer for s2mm transfers 
	unsigned int mm2s_pointer;				// buffer pointer for mm2s transfers
	
	unsigned int total_blocks_to_s2mm; 	    // total number of blocks to transfer in each s2mm transfer task
	unsigned int total_blocks_to_mm2s; 	    // total number of blocks to transfer in each mm2s transfer task
	
	unsigned int driver_dma_size_of_one_buffer; // size of one transfer buffer. max value is 4 mbytes
	
	unsigned int set_s2mm_mmap; 			// when 1, do mmap for s2mm buffers 
	unsigned int set_mm2s_mmap;				// when 1, do mmap for mm2s buffers
	unsigned int set_buffer_no_mmap; 		// which buffer number mmap should use for mapping?
	
	unsigned int dma_device_number; 		// device number for dma.
	unsigned int print_isr_messages;		// should we do debug printks when any of the 2 interrups happen?
	unsigned int number_of_buffers_mm2s; 	// total number of buffers that we allocate from dram memory to mm2s channel 
	unsigned int number_of_buffers_s2mm;	// total number of buffers that we allocate from dram memory to s2mm channel 
};

static struct class *driver_class;

static int 	__init my_module_init(void);
static void __exit my_module_exit(void);

static int probe_counter;


//////////////////////////////////////////////////////////////////////////////////////////
//
// File Operations Open Character Device 
//
//////////////////////////////////////////////////////////////////////////////////////////
static int axi_dma_ctrl_open (struct inode *inode, struct file *filp)
{
	struct axi_dma_ctrl_local *lp;
	
	//printk ("axi_dma_ctrl : driver_open \n");
	
	lp = container_of(inode->i_cdev, struct axi_dma_ctrl_local, cdev);
	
	filp->private_data = lp;
	
	return 0; 
}

//////////////////////////////////////////////////////////////////////////////////////////
//
// File Operations Close Character Device
//
//////////////////////////////////////////////////////////////////////////////////////////
static int axi_dma_ctrl_close (struct inode *inode, struct file *filp)
{
	printk ( KERN_INFO "axi_led_ctrl : device closed.\n" );

	return (0);
}

//////////////////////////////////////////////////////////////////////////////////////////////////////
//
// User Reads from Character Device
//
//////////////////////////////////////////////////////////////////////////////////////////////////////
static ssize_t axi_dma_ctrl_read (struct file * filp, char *buff, size_t count, loff_t * ppos)  {
	
	//printk ( KERN_INFO "axi_led_ctrl : reading the output buffer\n" );
	
	return (count);
}

//////////////////////////////////////////////////////////////////////////////////////////////////////
//
// axi_dma_ctrl_write
//
//////////////////////////////////////////////////////////////////////////////////////////////////////
// User Writes to Character Device
static ssize_t axi_dma_ctrl_write (struct file * filp, __user const char *buff, size_t count, loff_t * ppos)  {
	
	//printk ( KERN_INFO "axi_led_ctrl : writing to input buffer .\n" );
	
	return ( count ); 

}

///////////////////////////////////////////////////////////////////////////////////////////////////////////////////
//
// character device ioctl 
//
///////////////////////////////////////////////////////////////////////////////////////////////////////////////////

long axi_dma_ctrl_ioctl(struct file *filep, unsigned int cmd, unsigned long arg)  {
	
	struct axi_dma_ctrl_local *lp = filep->private_data;
	unsigned int tmpVal; 
	unsigned int retValue; 
	unsigned int buffer_counter;
	
	retValue = 0;
	
	switch ( cmd )  {
		
		/* in this example the buffer size is equal to block size */
		case IOCTL_DMA_SET_TRANSFER_BLOCK_SIZE: 
			lp->driver_dma_size_of_one_buffer = arg;
		break; 
			
		case IOCTL_DMA_SET_NUMBER_OF_BUFFERS_MM2S: 
			if (arg > DRIVER_DMA_NUMBER_OF_BUFFERS_MM2S){
				printk ("axi_dma_ctrl: the value of num_of_buffer_mm2s:%d is bigger than the max %d,
						 using the max value!\n", arg, DRIVER_DMA_NUMBER_OF_BUFFERS_MM2S);
				tmpVal = DRIVER_DMA_NUMBER_OF_BUFFERS_MM2S;
			}
			else {
				tmpVal = arg;
			}
			lp->number_of_buffers_mm2s
		break; 

		case IOCTL_DMA_SET_NUMBER_OF_BUFFERS_MM2S:
			if (arg > DRIVER_DMA_NUMBER_OF_BUFFERS_S2MM){
				printk ("axi_dma_ctrl: the value of num_of_buffer_mm2s:%d is bigger than the max %d, 
						using the max value!\n", arg, DRIVER_DMA_NUMBER_OF_BUFFERS_S2MM);
				tmpVal = DRIVER_DMA_NUMBER_OF_BUFFERS_S2MM;
			}
			else {
				tmpVal = arg;
			}
			lp->number_of_buffers_s2mm;

		break;

		/* this ioctl allocate ddr memory for axi dma in dram */
		case IOCTL_DMA_ALLOCATE_COHERENT_MEMORY:
			/* allocate memory for mm2s */
			for (int i = 0; i < lp->number_of_buffers_mm2s; i++)
			{
				lp->dma_buffer_virtual_address_mm2s[i] = dma_alloc_coherent(lp->dev, lp->driver_dma_size_of_one_buffer, 
																			&lp->dma_buffer_physical_address_mm2s[i], GPF_KERNEL);

				printk ("axi_dma_ctrl: dma_buffer_virtual_address_mm2s[%d] physical address: %d virtual address: %d \n",
						i,
						lp->dma_buffer_physical_address_mm2s[i],
						lp->dma_buffer_virtual_address_mm2s[i] );
			}

			/* allocate memory for s2mm */
			for (int i = 0; i < lp->number_of_buffers_s2mm; i++)
			{
				lp->dma_buffer_virtual_address_s2mm[i] = dma_alloc_coherent(lp->dev, lp->driver_dma_size_of_one_buffer, 
																			&lp->dma_buffer_physical_address_s2mm[i], GPF_KERNEL);

				printk ("axi_dma_ctrl: dma_buffer_virtual_address_s2mm[%d] physical address: %d virtual address: %d \n",
						i,
						lp->dma_buffer_physical_address_s2mm[i],
						lp->dma_buffer_virtual_address_s2mm[i] );
			}		

		break;

		case IOCTL_DMA_RELEASE_COHERENT_MEMORY:
			printk ("axi_dma_ctrl: release coherent memory");

			/* free mm2s buffer */
			for (int i = 0; i < lp->number_of_buffers_mm2s; i++)
			{
				dma_free_coherent(lp->dev, lp->driver_dma_size_of_one_buffer, lp->dma_buffer_virtual_address_mm2s[i],
								 lp->dma_buffer_physical_address_mm2s[i]);
			}

			/* free s2mm buffer */
			for (int i = 0; i < lp->number_of_buffers_s2mm; i++)
			{
				dma_free_coherent(lp->dev, lp->driver_dma_size_of_one_buffer, lp->dma_buffer_virtual_address_s2mm[i],
								 lp->dma_buffer_physical_address_s2mm[i]);
			}		
		break;
		
		/* set how many block to transfer in each transfer task */
		case IOCTL_DMA_SET_NUMBER_OF_BLOCKS_TO_MM2S:
			lp->total_blocks_to_mm2s = arg;
		break;

		/* set how many block to transfer in each transfer task */
		case IOCTL_DMA_SET_NUMBER_OF_BLOCKS_TO_S2MM:
			lp->total_blocks_to_s2mm = arg;
		break;

		/* start a axidma s2mm transfer by write to the dst address and length registers */
		case IOCTL_DMA_START_S2MM:
			
			lp->s2mm_pointer = 0; 
			
			iowrite32 ( 0, lp->base_addr + S2MM_DEST_ADDRESS_MSB ); 
			iowrite32 ( lp->dma_buffer_physical_address_s2mm[lp->s2mm_pointer] , lp->base_addr + S2MM_DEST_ADDRESS_LSB );
			iowrite32 ( lp->driver_dma_size_of_one_buffer, lp->base_addr + S2MM_LENGTH );

		break;

		/* start a axidma mm2s transfer by write to the src address and length registers */
		case IOCTL_DMA_START_MM2S:
			
			lp->mm2s_pointer = 0;
			
			iowrite32 ( 0, lp->base_addr + MM2S_SOURCE_ADDRESS_MSB ); 
			iowrite32 ( lp->dma_buffer_physical_address_mm2s[lp->mm2s_pointer], lp->base_addr + MM2S_SOURCE_ADDRESS_LSB );
			iowrite32 ( lp->driver_dma_size_of_one_buffer, lp->base_addr + MM2S_LENGTH );

		break; 

		/* get the pointer of s2mm buffer */
		case IOCTL_DMA_GET_S2MM_POINTER:
			tmpVal = lp->s2mm_pointer;
			__put_user ( tmpVal , (unsigned int __user *)arg);
			printk ( "axi_dma_ctrl: s2mm_pointer is pointing to buffer no. %d \n", lp->s2mm_pointer ); 
		break; 
		/* get the pointer of mm2s buffer */
		case IOCTL_DMA_GET_MM2S_POINTER:
			tmpVal = lp->mm2s_pointer;
			__put_user ( tmpVal , (unsigned int __user *)arg);
			printk ( "axi_dma_ctrl: mm2s_pointer is pointing to buffer no. %d \n", lp->mm2s_pointer ); 
		break;
		
		/* enable mmap s2mm channel */
		case IOCTL_DMA_SET_S2MM_MMAP:
			lp->set_s2mm_mmap = arg;
		break; 
		
		/* enable mmap mm2s channel */
		case IOCTL_DMA_SET_MM2S_MMAP:
			lp->set_mm2s_mmap = arg; 
		break; 
		
		/* choose which number buffer will be mmap */
		case IOCLT_DMA_SET_BUFFER_NO_MMAP:
			lp->set_buffer_no_mmap = arg;
		break; 
		
		case IOCTL_DMA_DISABLE_ISR_MESSAGES:
			lp->print_isr_messages = 0; 
		break; 
		
		/* get current dma status registers */
		case IOCTL_DMA_DUMP_REGS: 
			printk ( "axi_dma_ctrl: mm2s cr: %x\n", ioread32(lp->base_addr + MM2S_DMA_CR) ); 
			printk ( "axi_dma_ctrl: mm2s status: %x\n", ioread32(lp->base_addr + MM2S_DMA_SR) ); 
			printk ( "axi_dma_ctrl: mm2s addr lsb: %x\n", ioread32(lp->base_addr + MM2S_SOURCE_ADDRESS_LSB) ); 
			printk ( "axi_dma_ctrl: mm2s addr msb: %x\n", ioread32(lp->base_addr + MM2S_SOURCE_ADDRESS_MSB) ); 
			printk ( "axi_dma_ctrl: mm2s length: %x\n", ioread32(lp->base_addr + MM2S_LENGTH )); 
			
			printk ( "axi_dma_ctrl: s2mm cr: %x\n", ioread32(lp->base_addr + S2MM_DMA_CR) ); 
			printk ( "axi_dma_ctrl: s2mm status: %x\n", ioread32(lp->base_addr + S2MM_DMA_SR) ); 
			printk ( "axi_dma_ctrl: s2mm addr lsb: %x\n", ioread32(lp->base_addr + S2MM_DEST_ADDRESS_LSB) ); 
			printk ( "axi_dma_ctrl: s2mm addr msb: %x\n", ioread32(lp->base_addr + S2MM_DEST_ADDRESS_MSB) ); 
			printk ( "axi_dma_ctrl: s2mm length: %x\n", ioread32(lp->base_addr + S2MM_LENGTH )); 
		break; 
	
		case IOCTL_DMA_RESET:

			/* put both of the mm2s and s2mm channels in reset. */
			iowrite32 ( 0x4 , lp->base_addr  + S2MM_DMA_CR );
			iowrite32 ( 0x4 , lp->base_addr  + MM2S_DMA_CR );
			
			printk ( "axi_dma_ctrl: dma reset is done! \n"); 
			printk ( "axi_dma_ctrl: mm2s cr: %x\n", ioread32(lp->base_addr + MM2S_DMA_CR) ); 
			printk ( "axi_dma_ctrl: s2mm cr: %x\n", ioread32(lp->base_addr + S2MM_DMA_CR) ); 
			
			/* setup s2mm channel */
			tmpVal = ioread32 ( lp->base_addr + S2MM_DMA_CR ); 
			tmpVal = tmpVal | 0x1001;
			iowrite32  ( tmpVal, lp->base_addr  + S2MM_DMA_CR );
			
			/* double check if the value is set */
			tmpVal = ioread32 ( lp->base_addr  + S2MM_DMA_CR ); 
			printk ( "axi_dma_ctrl: value for dma config reg for s2mm is %x\n", tmpVal ); 
			
			/* setup mm2s channel */
			tmpVal = ioread32 ( lp->base_addr + MM2S_DMA_CR ); 
			tmpVal = tmpVal | 0x1001; 
			iowrite32 ( tmpVal, lp->base_addr + MM2S_DMA_CR ); 
					
			/* double check if the value is set */
			tmpVal = ioread32 ( lp->base_addr + MM2S_DMA_CR ); 
					
			printk ( "axi_dma_ctrl: value for dma config reg for mm2s is %x\n", tmpVal ); 
			
		break;
			
		default:
			printk ("axi_dma_ctrl: ioctl default case! should never happen!\n" );;
	}
	return retValue;
}



/************************************************************************************
 * mmap 
 * ***********************************************************************************/
static int axi_dma_ctrl_mmap (struct file * filep, struct vm_area_struct * vma)  {

	int result = 0; 
	unsigned int addr = 0; 
	unsigned int size = 0; 
	
	struct axi_dma_ctrl_local *lp = filep->private_data;

	if ( ( vma->vm_end - vma->vm_start ) > (DRIVER_DMA_SIZE_OF_ONE_BUFFER) )  {
		printk ( KERN_INFO "%s:%i requested mmap region size is bigger dma buffer. requested=%d, max buffer=%x\n", 
			__FUNCTION__, 
			__LINE__ , 
			vma->vm_end - vma->vm_start , 
			DRIVER_DMA_SIZE_OF_ONE_BUFFER );
		return -1;
	}
	
	if ( lp->set_s2mm_mmap )
		addr = lp->dma_buffer_physical_address_s2mm[lp->set_buffer_no_mmap];
	else if ( lp->set_mm2s_mmap )
		addr = lp->dma_buffer_physical_address_mm2s[lp->set_buffer_no_mmap];
	else 
		printk ("axi_dma_ctrl:mmap, either one of mm2s or s2mm should have been selected in user level app before running mmap. \n");
		
	size = vma->vm_end - vma->vm_start; 
	
	addr = vma->vm_pgoff + (addr >> PAGE_SHIFT);
	
	vma->vm_flags |= (VM_DONTEXPAND | VM_DONTDUMP);
	vma->vm_page_prot = pgprot_noncached(vma->vm_page_prot);

	result = io_remap_pfn_range( 	vma, 
					vma->vm_start, 
					addr, 
					size, vma->vm_page_prot); 
	
	if( result != 0 ){
		printk( KERN_INFO "%s:%i mmap failed.\n", __FUNCTION__, __LINE__);
		return -1;
	}

 	printk( KERN_INFO "%s:%i mmap done!, virt %lx, phys %x\n", __FUNCTION__, __LINE__,
 	vma->vm_start, addr << PAGE_SHIFT );

	return 0;
}


static struct file_operations axi_dma_ctrl_fops =
{
	.owner = THIS_MODULE,
	.read = axi_dma_ctrl_read,
	.write = axi_dma_ctrl_write,
	.open = axi_dma_ctrl_open,
	.release = axi_dma_ctrl_close,
	.unlocked_ioctl = axi_dma_ctrl_ioctl, 
	.mmap = axi_dma_ctrl_mmap,
};


/************************************************************************************
 * axi_dma_ctrl_irq_mm2s
 * ***********************************************************************************/

static irqreturn_t axi_dma_ctrl_irq_mm2s(int irq, void *lp)
{
	struct axi_dma_ctrl_local *lp_in_function = lp;
	
	/* clear interrupt */
	iowrite32 ( 0x1000, lp_in_function->base_addr + MM2S_DMA_SR );
	
	if ( lp_in_function->print_isr_messages )
		printk ( KERN_DEFAULT "%s:%i dma %d received mm2s interrupt. current mm2s pointer: %d \n", __FUNCTION__, __LINE__, lp_in_function->dma_device_number, lp_in_function->mm2s_pointer ); 
	/* mm2s is read from memory. update the read pointer */ 
	if ( lp_in_function->mm2s_pointer == (lp_in_function->number_of_buffers_mm2s-1) )
		lp_in_function->mm2s_pointer = 0; 
	else 
		lp_in_function->mm2s_pointer = lp_in_function->mm2s_pointer + 1; 
	
	/* determine if you should start a new mm2s operation. */ 
	lp_in_function->total_blocks_to_mm2s = lp_in_function->total_blocks_to_mm2s - 1; 
	if ( lp_in_function->total_blocks_to_mm2s > 0 ) {
		/* start the next dma block transfer */ 
		iowrite32 ( lp_in_function->dma_buffer_physical_address_mm2s[lp_in_function->mm2s_pointer], lp_in_function->base_addr + MM2S_SOURCE_ADDRESS_LSB );
		iowrite32 ( lp_in_function->driver_dma_size_of_one_buffer, lp_in_function->base_addr + MM2S_LENGTH );
		
	}
		
	return IRQ_HANDLED;
}

/************************************************************************************
 * axi_dma_ctrl_irq_s2mm
 * ***********************************************************************************/
static irqreturn_t axi_dma_ctrl_irq_s2mm(int irq, void *lp)
{
	struct axi_dma_ctrl_local *lp_in_function = lp;
	/* clear interrupt */ 
	iowrite32 ( 0x1000, lp_in_function->base_addr + S2MM_DMA_SR );
	if ( lp_in_function->print_isr_messages )
		printk ( KERN_DEFAULT "%s:%i dma %d received s2mm interrupt. current s2mm pointer: %d\n", __FUNCTION__, __LINE__, lp_in_function->dma_device_number, lp_in_function->s2mm_pointer ); 
	/* update the write pointer */ 
	if ( lp_in_function->s2mm_pointer == (lp_in_function->number_of_buffers_s2mm-1) )
		lp_in_function->s2mm_pointer = 0; 
	else 
		lp_in_function->s2mm_pointer = lp_in_function->s2mm_pointer + 1;

	/* check if we need to transfer more blocks, start a new transfer if yes. */ 
	lp_in_function->total_blocks_to_s2mm = lp_in_function->total_blocks_to_s2mm - 1; 
	if ( lp_in_function->total_blocks_to_s2mm > 0 )  {
		iowrite32 ( lp_in_function->dma_buffer_physical_address_s2mm[lp_in_function->s2mm_pointer] , lp_in_function->base_addr + S2MM_DEST_ADDRESS_LSB );
		iowrite32 ( lp_in_function->driver_dma_size_of_one_buffer, lp_in_function->base_addr + S2MM_LENGTH );
	}
	
	return IRQ_HANDLED;
}

static int axi_dma_ctrl_probe(struct platform_device *pdev)
{
	struct resource *r_irq_0, *r_irq_1; /* Interrupt resources */
	struct resource *r_mem; /* IO mem resources */
	struct device *dev = &pdev->dev;
	struct axi_dma_ctrl_local *lp = NULL;

	int rc = 0;

	dev_t devt;
	int retval = 0;

	char *driver_name_str;
	char *driver_name_str_intr_s2mm; 
	char *driver_name_str_intr_mm2s; 

	driver_name_str = kzalloc ( 32 , GFP_KERNEL );
	driver_name_str_intr_s2mm = kzalloc ( 32 , GFP_KERNEL );
	driver_name_str_intr_mm2s = kzalloc ( 32 , GFP_KERNEL );
	
	sprintf ( driver_name_str, "%s_%d", DRIVER_NAME, probe_counter ); 
	sprintf ( driver_name_str_intr_s2mm, "%s_%d_s2mm", DRIVER_NAME, probe_counter ); 
	sprintf ( driver_name_str_intr_mm2s, "%s_%d_mm2s", DRIVER_NAME, probe_counter ); 

	printk("Device Tree Probing\n");

	/* Get iospace for the device */
	r_mem = platform_get_resource(pdev, IORESOURCE_MEM, 0);
	if (!r_mem) {
		printk("invalid address\n");
		return -ENODEV;
	}
	lp = (struct axi_dma_ctrl_local *) kmalloc(sizeof(struct axi_dma_ctrl_local), GFP_KERNEL);
	if (!lp) {
		printk("Cound not allocate axi_dma_ctrl device\n");
		return -ENOMEM;
	}
	dev_set_drvdata(dev, lp);
	lp->mem_start = r_mem->start;
	lp->mem_end = r_mem->end;

	if (!request_mem_region(lp->mem_start,
				lp->mem_end - lp->mem_start + 1,
				DRIVER_NAME)) {
		printk("Couldn't lock memory region at %p\n",
			(void *)lp->mem_start);
		rc = -EBUSY;
		goto error1;
	}

	lp->base_addr = ioremap(lp->mem_start, lp->mem_end - lp->mem_start + 1);
	if (!lp->base_addr) {
		printk("axi_dma_ctrl: Could not allocate iomem\n");
		rc = -EIO;
		goto error2;
	}

	printk("axi_dma_ctrl at 0x%08x mapped to 0x%08x\n",
		(unsigned int __force)lp->mem_start,
		(unsigned int __force)lp->base_addr);

	/* Get irq resources */
	lp->irq_mm2s = 0;
	lp->irq_s2mm = 0;
	/* First axidma irq mm2s */
	r_irq_0 = platform_get_resource(pdev, IORESOURCE_IRQ, 0);
	if (!r_irq_0) {
		printk("no IRQ found\n");
		printk("axi-dma-ctrl at 0x%08x mapped to 0x%08x\n",
			(unsigned int __force)lp->mem_start,
			(unsigned int __force)lp->base_addr);
		return 0;
	}
	lp->irq_mm2s = r_irq_0->start;
	rc = request_irq(lp->irq_mm2s, &axi_dma_ctrl_irq_mm2s, 0, driver_name_str_intr_mm2s, lp);
	if (rc) {
		printk("testmodule: Could not allocate interrupt %d.\n",
			lp->r_irq_0);
		goto error3;
	}

	/* Second irq axidma s2mm */
	r_irq_1 = platform_get_resource(pdev, IORESOURCE_IRQ, 1);
	if (!r_irq_1) {
		printk("no IRQ found\n");
		printk("axi-dma-ctrl at 0x%08x mapped to 0x%08x\n",
			(unsigned int __force)lp->mem_start,
			(unsigned int __force)lp->base_addr);
		return 0;
	}
	lp->irq_s2mm = r_irq_1->start;
	rc = request_irq(lp->irq_s2mm, &axi_dma_ctrl_irq_s2mm, 0, driver_name_str_intr_s2mm, lp);
	if (rc) {
		printk("testmodule: Could not allocate interrupt %d.\n",
			lp->r_irq_1);
		goto error3;
	}


	/***********************************************************************
	 * register character device	
	***********************************************************************/
	printk("axi_dma_ctrl: register character device...\n");
	alloc_chrdev_region(&devt, 0, 0, driver_name_str);
	lp->devt = devt;
	cdev_init(&lp->cdev, &axi_dma_ctrl_fops);
	lp->cdev.owner = THIS_MODULE;

	retval = cdev_add(&lp->cdev, devt, 1);
	if (retval)
	{
		printk("axi_dma_ctrl_of_probe: cdev_add() failed \n");
		goto error2;
	}

	/* add this module into system */
	lp->driver_class = class_create(THIS_MODULE, driver_name_str );
	device_create(lp->driver_class, dev, devt, NULL, "%s%d", driver_name_str, 0);
	printk ("axi_dma_ctrl_probe: probe no %d axidma cdev , done creating character device: major : %d...\n", probe_counter, MAJOR(lp->devt) );

	lp->dma_device_number = probe_counter;

	/* if we have multiple device in the divcetree use this driver, using a probe counter to identity each other */
	probe_counter++;

	/* give some initial value for axi dma local*/
	lp->dev = dev;
	lp->s2mm_pointer = 0;
	lp->mm2s_pointer = 0;
	lp->driver_dma_size_of_one_buffer = DRIVER_DMA_SIZE_OF_ONE_BUFFER; // the size of driver dma buffer is 4MB 
	lp->number_of_buffers_mm2s = 0;
	lp->number_of_buffers_s2mm = 0;
	lp->total_blocks_to_mm2s = 1;
	lp->total_blocks_to_s2mm = 1;
	lp->set_buffer_no_mmap = 0;
	lp->set_mm2s_mmap = 0;
	lp->set_s2mm_mmap = 0;
	lp->print_isr_messages = 1;

	return 0;

error3:
	free_irq(lp->irq_mm2s, lp);
	free_irq(lp->irq_s2mm, lp);
	
error2:
	release_mem_region(lp->mem_start, lp->mem_end - lp->mem_start + 1);

error1:
	kfree(lp);
	dev_set_drvdata(dev, NULL);
	return rc;
}

static int axi_dma_ctrl_remove(struct platform_device *pdev)
{
	struct device *dev = &pdev->dev;
	struct axi_dma_ctrl_local *lp = dev_get_drvdata(dev);

	cdev_del(&lp->cdev);
	free_irq(lp->irq_mm2s, lp);
	free_irq(lp->irq_s2mm, lp);
	iounmap(lp->base_addr);
	release_mem_region(lp->mem_start, lp->mem_end - lp->mem_start + 1);
	kfree(lp);
	dev_set_drvdata(dev, NULL);
	return 0;
}

static struct of_device_id axi_dma_ctrl_of_match[] = {
	{ .compatible = "microphase,axi_dma_ctrl-1.0", },
	{ /* end of list */ },
};
MODULE_DEVICE_TABLE(of, axi_dma_ctrl_of_match);



static struct platform_driver axi_dma_ctrl_driver = {
	.driver = {
		.name = "axi_dma_ctrl",
		.owner = THIS_MODULE,
		.of_match_table	= axi_dma_ctrl_of_match,
	},
	.probe		= axi_dma_ctrl_probe,
	.remove		= axi_dma_ctrl_remove,
};


static int __init my_module_init(void)
{
	int ret_val; 
		
	platform_driver_register ( &axi_dma_ctrl_driver );
	
	printk ( KERN_INFO "axi_dma_ctrl : init ...\n"); 
	
	return 0;
}

//////////////////////////////////////////////////////////////////////////////////////////
//
// Exit The Driver
//
//////////////////////////////////////////////////////////////////////////////////////////
static void __exit my_module_exit(void)
{
	platform_driver_unregister(&axi_dma_ctrl_driver);

	printk ( KERN_INFO "axi_dma_ctrl: exit...\n" ); 
	
	return;
}

module_init( my_module_init );
module_exit( my_module_exit );

/* Standard module information, edit as appropriate */
MODULE_LICENSE("GPL");
MODULE_AUTHOR("Chaochen Wei.");
MODULE_DESCRIPTION("axi_dma_ctrl - loadable module template generated by petalinux-create -t modules");
