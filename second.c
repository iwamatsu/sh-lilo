static void put_string (unsigned char *);
static int load_sectors (unsigned long, unsigned long);
static unsigned long base_pointer = 0;	/* Avoid BSS */

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
  /* XXX: delay, key check... */
  /* XXX: list up images */
  /* XXX: check signature */
  /*
    is there default command line?
    use it!
  */
  put_string ("boot: ");
  /*   put_string (cmdline); */
  load_sectors (SD_MSG, 0x3a00);

  {
    while (1)
      {
	int i;

	for (i=0; i<65536*100; i++)
	  ;
	put_string ("Hello world!\n");
      }
  }
}

static void
put_string (unsigned char *str)
{
  register long __sc0 __asm__ ("$r0") = 0; /* OUTPUT */
  register long __sc4 __asm__ ("$r4") = (long) str;

  asm volatile  ("trapa	#0x3F; nop"
		 : "=z" (__sc0)
		 : "0" (__sc0), "r" (__sc4)
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
