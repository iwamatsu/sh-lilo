/* $Id: second.c,v 1.16 2000-08-05 13:05:10 gniibe Exp $
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
static int load_sectors_with_maps (int, int, unsigned long *);

static int machine_type (void);
static int serial_type (void);
static int memory_size (void);
static int io_base (void);

static const char hexchars[] = "0123456789abcdef";
#define digits hexchars		/* 10base is same for 16base (up to 10) */
static inline char highhex (int x) {  return hexchars[(x >> 4) & 0xf];  }
static inline char lowhex (int x) {  return hexchars[x & 0xf];  }
static void printouthex (int);

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

#if 0
  load_sectors (SD_MSG, 0x3a00);
#endif
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
       rd_size    (4-byte)
       initrd     (5-byte sector desc)
       start      (5-byte sector desc)
       start_page (16-bit)
       flags      (16-bit)
       vga_mode   (16-bit)
      )
   ] * 19
  */

  put_string ("Loading ");
  put_string ((char *)(base_pointer+0x3200+2)); /* Image name */

  kernel_image = base_pointer + 0x10000;
  {
    int desc = 0x3200+2+16+16+4+5; /* kernel image */

    /* Skip two sectors: Fallback command line and options */
    desc = load_sectors_with_maps (desc, 2, &kernel_image);
    put_string (".");

    while (desc != 0)
      {
	desc = load_sectors_with_maps (desc, 0, &kernel_image);
	put_string (".");
      }
  }
  put_string ("done.\n");

#if 0
  {
    int i;

    put_string ("DUMP: ");
    for (i=0; i<16; i++)
      printouthex (*(unsigned char *)(base_pointer+0x10000+i));
    put_string ("\n");
  }
#endif

  /* XXX: kernel paramerter setting */
  {
    unsigned long parm = base_pointer - 0x200000 + 0x1000;
    char *cmdline = (char *)(parm+256);
    int mem_size;

    *(long *)parm      = 1;	/* Read only mount? */
    *(long *)(parm+4)  = 0;	/* RAMDISK Flags */
    *(long *)(parm+8)  = 0x0301; /* Root device: XXX should get from cls.. */
    *(long *)(parm+12) = 1;	/* Loader type (LILO = 1) */
    *(long *)(parm+16) = 0;	/* Initrd start */
    *(long *)(parm+20) = 0;	/* Initrd size */
    *(long *)(parm+24) = 0;	/* Not defined yet */

    /* XXX: Should take the line from command line sector... */

    /* Query to BIOS and build the command line string */
    /* Build string "mem=XXM" */
    mem_size = memory_size ();    
    mem_size >>= 20; /* In Mega-byte */
    *cmdline++ = 'm'; *cmdline++ = 'e'; *cmdline++ = 'm'; *cmdline++ = '=';
    if (mem_size >= 100)
      {
	*cmdline++ = digits[mem_size/100];
	mem_size = mem_size % 100;
      }
    if (mem_size >= 10)
      {
	*cmdline++ = digits[mem_size/10];
	mem_size = mem_size % 10;
      }
    *cmdline++ = digits[mem_size];
    *cmdline++ = 'M';
    *cmdline++ = ' ';

    if (machine_type () == 0)	/* Unknown board */
      {				/* Build string "sh_mv=unknown,0xXXXXXX,1" */
	unsigned int io = io_base ();
	int b31_24, b23_16, b15_08, b07_00;

	b31_24 = (io>>24)&0xff;
	b23_16 = (io>>16)&0xff;
	b15_08 = (io>>8)&0xff;
	b07_00 = (io>>0)&0xff;

	*cmdline++ = 's'; *cmdline++ = 'h'; *cmdline++ = '_'; *cmdline++ = 'm';
	*cmdline++ = 'v'; *cmdline++ = '='; *cmdline++ = 'u'; *cmdline++ = 'n';
	*cmdline++ = 'k'; *cmdline++ = 'n'; *cmdline++ = 'o'; *cmdline++ = 'w';
	*cmdline++ = 'n'; *cmdline++ = ','; *cmdline++ = '0'; *cmdline++ = 'x';
	*cmdline++ = highhex (b31_24); *cmdline++ = lowhex (b31_24);
	*cmdline++ = highhex (b23_16); *cmdline++ = lowhex (b23_16);
	*cmdline++ = highhex (b15_08); *cmdline++ = lowhex (b15_08);
	*cmdline++ = highhex (b07_00); *cmdline++ = lowhex (b07_00);
	*cmdline++ = ','; *cmdline++ = '1';
	*cmdline++ = ' ';
      }

    if (serial_type () == 0)
      memcpy (cmdline, "console=ttySC0,115200", 22);
    else
      memcpy (cmdline, "console=ttySC1,115200", 22);
  }

  asm volatile ("jmp @$r0; nop"
		: /* no output */
		: "z" (base_pointer + 0x10000));
}

static int
load_sectors_with_maps (int desc, int offset, unsigned long *buf_p)
{
  int dev;
  unsigned long lba;
  int i, count;

  /* Load the map at 0x3000 */
  if (load_sectors (desc, 0x3000) < 0)
    return 0;

  for (i = offset*5; i<505; i+=5)
    {
      if ((count = get_sector_address (0x3000+i, &dev, &lba)) == 0)
	return 0;

      read_sectors (dev, lba, (unsigned char *)*buf_p, count);
      *buf_p += count*512;
    }

  /* There's next map */
  return 0x3000+505;
}

static int
machine_type (void)
{
  register long __sc0 __asm__ ("$r0") = 3; /* FEATURE QUERY */

  asm volatile ("trapa	#0x3F"
		: "=z" (__sc0)
		: "0" (__sc0)
		: "memory");

  return (__sc0 >> 8);
}

static int
serial_type (void)
{
  register long __sc0 __asm__ ("$r0") = 3; /* FEATURE QUERY */

  asm volatile ("trapa	#0x3F"
		: "=z" (__sc0)
		: "0" (__sc0)
		: "memory");

  return (__sc0 & 0x07);
}

static int
memory_size (void)
{
  register long __sc0 __asm__ ("$r0") = 4; /* MEMORY SIZE */

  asm volatile ("trapa	#0x3F"
		: "=z" (__sc0)
		: "0" (__sc0)
		: "memory");

  return (__sc0);
}

static int
io_base (void)
{
  register long __sc0 __asm__ ("$r0") = 5; /* IO BASE */

  asm volatile ("trapa	#0x3F"
		: "=z" (__sc0)
		: "0" (__sc0)
		: "memory");

  return (__sc0);
}

static void inline
put_string_1 (unsigned char *str, long len)
{
  register long __sc0 __asm__ ("$r0") = 0; /* OUTPUT */
  register long __sc4 __asm__ ("$r4") = (long) str;
  register long __sc5 __asm__ ("$r5") = (long) len; /* For New BIOS */

  asm volatile ("trapa	#0x3F"
		: "=z" (__sc0)
		: "0" (__sc0), "r" (__sc4),  "r" (__sc5)
		: "memory");
}

static void
put_string (unsigned char *str)
{
  int len = strlen (str);
  put_string_1 (str, len);
}

static int
read_sectors (int dev, unsigned long lba, unsigned char *buf, int count)
{
  register long __sc0 __asm__ ("$r0") = 2; /* READ SECTORS */
  register long __sc4 __asm__ ("$r4") = (long) dev;
  register long __sc5 __asm__ ("$r5") = (long) lba;
  register long __sc6 __asm__ ("$r6") = (long) buf;
  register long __sc7 __asm__ ("$r7") = (long) count;

  asm volatile ("trapa	#0x3F"
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

#if 0
  {
    unsigned long lba = *lbap;

    put_string ("DEV= ");
    printouthex ((*devp)&0xff);
    put_string ("\n");
    put_string ("LBA= ");
    printouthex ((lba>>24)&0xff);
    printouthex ((lba>>16)&0xff);
    printouthex ((lba>>8)&0xff);
    printouthex (lba&0xff);
    put_string ("\n");
  }
#endif

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

  if (count)
    return read_sectors (dev, lba, buf, count);

  return -1;
}

static void
printouthex(int x)
{
  char z[4];

  z[0] = highhex (x);
  z[1] = lowhex (x);
  z[2] = ' ';
  z[3] = '\0';

  put_string (z);
}
