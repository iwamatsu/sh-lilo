# Configuration variables

#   BEEP	  Beep after displaying "LILO".
#   IGNORECASE    Image selection is case-insensitive. Passwords are still
#		  case-sensitive.
#   LARGE_EBDA	  Load at 8xxxx instead of 9xxxx to leave more room for the
#		  EBDA (Extended BIOS Data Area)
#   NO1STDIAG	  Don't show diagnostic on read errors in the first stage boot
#   NODRAIN	  Don't drain keyboard buffer after booting.
#   NOINSTDEF     Don't install a new boot sector if INSTALL is not specified.
#   ONE_SHOT      Disable the command-line and password timeout if any key is
#		  hit at the boot prompt.
#   READONLY	  Don't write to disk while booting, e.g. don't overwrite the
#		  default command line in the map file after reading it.
#   REWRITE_TABLE Enable rewriting the partition table at boot time.
#		  loader.
#   USE_TMPDIR	  Create temporary devices in $TMPDIR if set
#   VARSETUP	  Enables use of variable-size setup segments.
#   XL_SECS=n	  Support for extra large (non-standard) floppies.

CONFIG=-DIGNORECASE -DVARSETUP -DREWRITE_TABLE -DLARGE_EBDA -DONE_SHOT

# End of configuration variables

SBIN_DIR=/sbin
CFG_DIR=/etc
BOOT_DIR=/boot
USRSBIN_DIR=/usr/sbin

SHELL=/bin/sh

CROSS_COMPILE = sh3-linux-
CC	=$(CROSS_COMPILE)gcc
LD	=$(CROSS_COMPILE)ld
OBJCOPY =$(CROSS_COMPILE)objcopy
STRIP   =$(CROSS_COMPILE)strip

CFLAGS  = -O2 -I. -pipe -fPIC $(CONFIG) -DPATH_MAX=255
CPP=$(CC) -E -traditional

OBJS=lilo.o map.o geometry.o boot.o device.o common.o bsect.o cfg.o temp.o \
  partition.o identify.o

.SUFFIXES:	.b

all:		lilo boot.b

.c.o:
		$(CC) -c $(CFLAGS) $*.c

boot.b:		first.bin second.bin
		cat first.bin second.bin >boot.b

first.bin:	first.exe
		$(OBJCOPY) -S first.exe -O binary first.bin

second.bin:	second.exe
		$(OBJCOPY) -R .comment -S second.exe -O binary second.bin

first.exe:	first.o
		$(LD) -EL -e start first.o -o first.exe -Ttext 0x8c200000

second.exe:	second.o string.o
		$(LD) -T second.lds -EL second.o string.o -o second.exe -Ttext 0x8c201000

first.o:	first.S
		$(CC) $(CFLAGS) -c first.S

second.o:	second.c
		$(CC) $(CFLAGS) -c second.c

string.o:	string.c
		$(CC) $(CFLAGS) -c string.c

lilo:		$(OBJS)
		$(CC) -o lilo $(LDFLAGS) $(OBJS)

install:	all
		if [ ! -d $$ROOT$(SBIN_DIR) ]; then mkdir $$ROOT$(SBIN_DIR); fi
		if [ ! -d $$ROOT$(CFG_DIR) ]; then mkdir $$ROOT$(CFG_DIR); fi
		if [ ! -d $$ROOT$(BOOT_DIR) ]; then mkdir $$ROOT$(BOOT_DIR); fi
		if [ ! -d $$ROOT$(USRSBIN_DIR) ]; then \
		  mkdir $$ROOT$(USRSBIN_DIR); fi
		if [ -f $$ROOT$(BOOT_DIR)/boot.b ]; then \
		  mv $$ROOT$(BOOT_DIR)/boot.b $$ROOT$(BOOT_DIR)/boot.old; fi
		cp boot.b $$ROOT$(BOOT_DIR)
		cp lilo $$ROOT$(SBIN_DIR)
		$(STRIP) $$ROOT$(SBIN_DIR)/lilo

dep:
		sed '/\#\#\# Dependencies/q' <Makefile >tmp_make
		$(CPP) $(CFLAGS) -MM *.c >>tmp_make
		mv tmp_make Makefile

version:
		[ -r VERSION ] && [ -d ../lilo -a ! -d ../lilo-`cat VERSION` ]\
		  && mv ../lilo ../lilo-`cat VERSION`

clean:
		rm -f *.o *.exe *.bin tmp_make
		rm -f lilo boot.b

### Dependencies
activate.o : activate.c 
boot.o : boot.c config.h common.h lilo.h geometry.h cfg.h map.h partition.h \
  boot.h 
bsect.o : bsect.c config.h common.h lilo.h cfg.h device.h geometry.h map.h temp.h \
  partition.h boot.h bsect.h 
cfg.o : cfg.c common.h lilo.h temp.h cfg.h 
common.o : common.c common.h lilo.h 
device.o : device.c config.h common.h lilo.h temp.h device.h 
geometry.o : geometry.c config.h lilo.h common.h device.h geometry.h cfg.h 
identify.o : identify.c cfg.h 
lilo.o : lilo.c config.h common.h lilo.h temp.h geometry.h map.h bsect.h cfg.h \
  identify.h 
map.o : map.c lilo.h common.h geometry.h map.h 
partition.o : partition.c config.h lilo.h common.h cfg.h device.h geometry.h 
temp.o : temp.c common.h lilo.h temp.h 
