/* $Id: second.c,v 1.5 2000-07-20 12:02:55 gniibe Exp $
 *
 * Secondary boot loader
 *
 *  lilo/arch/sh/second.c
 *
 *  Copyright (C) 2000  Niibe Yutaka
 *
 * This file is subject to the terms and conditions of the GNU General
 * Public License.
 *
 */

#include "defs.h"

static void put_string (unsigned char *);
static int get_sector_address (unsigned long, int *, unsigned long *);
static int load_sectors (unsigned long, unsigned long);
static int read_sectors (int, unsigned long, unsigned char *, int);

static unsigned long base_pointer = 0;	/* Avoid BSS */
static unsigned long kernel_image = 0;	/* Avoid BSS */

/* Sector descriptor */
#define SD_DESCR1	24
#define SD_DESCR2	29
#define SD_DEFCMD	34
/* 39 prompt (byte) */
/* 40 length (word) */
#define SD_MSG		42
#define SD_KBDTBL	47

void
start (unsigned long base)
{
  base_pointer = base;

  put_string ("I");
  load_sectors (SD_DESCR1, 0x3200);
  load_sectors (SD_DESCR2, 0x3400);
  put_string ("L");
  /* XXX: checksum */

  load_sectors (SD_DEFCMD, 0x3600);
  load_sectors (SD_KBDTBL, 0x3800);
  put_string ("O ");

  load_sectors (SD_MSG, 0x3a00);
  /* XXX: delay, key check... */
  /* XXX: list up images */
  /* XXX: check signature */
  /* Input command line */
  /*
    Is there default command line?
    use it!
   */
  put_string ("boot: ");
  put_string ("first-image\n");	/* XXX: should handle commandline... */

  /* Structure of descriptor
   [ checksum 2byte ]
   [ DESCR_SIZE:52-byte
      (image-name (16-byte)
       passwd     (16-byte)
       rd_size    (32-bit)
       initrd     (5-byte sector desc)
       start      (5-byte sector desc)
       start_page (16-bit)
       flags      (16-bit)
       vga_mode   (16-bit)
      )
   ] * 19
  */

  put_string ((char *)(base_pointer+0x3200+2)); /* Image name */

  kernel_image = base_pointer + 0x10000;
  {
    int dev;
    unsigned long lba;
    int desc = 0x3200+2+16+16+4+5; /* kernel */

    while (desc != 0)
      {
	if (get_sector_address (desc, &dev, &lba) != 0)
	  {
	    int i, count;
	    read_sectors (dev, lba, (unsigned char *)base_pointer+0x3000, 1);
	    for (i=0; i<505; i+=5)
	      {
		if ((count = get_sector_address (0x3000+i, &dev, &lba)) == 0)
		  {
		    desc = 0;
		    break;
		  }
		read_sectors (dev, lba, (unsigned char *)kernel_image, count);
		kernel_image += count*512;
	      }
	    if (desc)
	      desc = 0x3000+i;
	  }
	else
	  {
	    put_string ("???\n");
	  }
	put_string (".");
      }
  }
  put_string ("done.\n");

  asm volatile ("jmp @$r0; nop"
		: /* no output */
		: "z" (base_pointer + 0x10000));
}

static void
put_string (unsigned char *str)
{
  register long __sc0 __asm__ ("$r0") = 0; /* OUTPUT */
  register long __sc4 __asm__ ("$r4") = (long) str;
  register long __sc5 __asm__ ("$r5") = (long) strlen (str); /* For New BIOS */

  asm volatile  ("trapa	#0x3F; nop"
		 : "=z" (__sc0)
		 : "0" (__sc0), "r" (__sc4),  "r" (__sc5)
		 : "memory");
}

static int
read_sectors (int dev, unsigned long lba, unsigned char *buf, int count)
{
  register long __sc0 __asm__ ("$r0") = 2; /* READ SECTORS */
  register long __sc4 __asm__ ("$r4") = (long) dev;
  register long __sc5 __asm__ ("$r5") = (long) lba;
  register long __sc6 __asm__ ("$r6") = (long) buf;
  register long __sc7 __asm__ ("$r7") = (long) count;

  asm volatile  ("trapa	#0x3F; nop"
		 : "=z" (__sc0)
		 : "0" (__sc0), "r" (__sc4),  "r" (__sc5),
		   "r" (__sc6),  "r" (__sc7)
		 : "memory");

  return __sc0;
}

static int
get_sector_address (unsigned long sector_desc, int *devp, unsigned long *lbap)
{
  unsigned long s;
  unsigned char *p = (unsigned char *)(sector_desc+base_pointer);

  /* p[2]: drive number */
  /* XXX: should check it's LBA (> 0xc0) */
  *devp = (int)p[2] - 0xc0;

  s = p[0] + (p[1]<<8) + (p[3]<<16);

  *lbap = s;

  /* Number of sectors */
  return (int)p[4];
}

static int
load_sectors (unsigned long sector_desc, unsigned long mem)
{
  int dev;
  unsigned long lba;
  int count;
  unsigned char *buf = (unsigned char *)(mem+base_pointer);

  count = get_sector_address (sector_desc, &dev, &lba);

  return read_sectors (dev, lba, buf, count);
}
