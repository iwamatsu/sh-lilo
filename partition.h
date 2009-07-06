/* partition.h  -  Partition table handling */

/* Copyright 1992-1996 Werner Almesberger. See file COPYING for details. */


#ifndef PARTITION_H
#define PARTITION_H

/* Copy from old linux kernel header (linux/partition.h)*/
struct partition {
	unsigned char boot_ind;		/* 0x80 - active */
	unsigned char head;			/* starting head */
	unsigned char sector;		/* starting sector */
	unsigned char cyl;			/* starting cylinder */
	unsigned char sys_ind;		/* What partition type */
	unsigned char end_head;		/* end head */
	unsigned char end_sector;	/* end sector */
	unsigned char end_cyl;		/* end cylinder */
	unsigned int start_sect;	/* starting sector counting from 0 */
	unsigned int nr_sects;		/* nr of sectors in partition */
};

/* Copy from linux kernel header (include/linux/genhd.h)*/
enum {
	/* These three have identical behaviour; use the second one if DOS FDISK gets
	   confused about extended/logical partitions starting past cylinder 1023. */
	DOS_EXTENDED_PARTITION = 5,
	LINUX_EXTENDED_PARTITION = 0x85,
	WIN98_EXTENDED_PARTITION = 0x0f,

	SUN_WHOLE_DISK = DOS_EXTENDED_PARTITION,

	LINUX_SWAP_PARTITION = 0x82,
	LINUX_DATA_PARTITION = 0x83,
	LINUX_LVM_PARTITION = 0x8e,
	LINUX_RAID_PARTITION = 0xfd,    /* autodetect RAID partition */

	SOLARIS_X86_PARTITION = LINUX_SWAP_PARTITION,
	NEW_SOLARIS_X86_PARTITION = 0xbf,

	DM6_AUX1PARTITION = 0x51,   /* no DDO:  use xlated geom */
	DM6_AUX3PARTITION = 0x53,   /* no DDO:  use xlated geom */
	DM6_PARTITION = 0x54,       /* has DDO: use xlated geom & offset */
	EZD_PARTITION = 0x55,       /* EZ-DRIVE */

	FREEBSD_PARTITION = 0xa5,   /* FreeBSD Partition ID */
	OPENBSD_PARTITION = 0xa6,   /* OpenBSD Partition ID */
	NETBSD_PARTITION = 0xa9,    /* NetBSD Partition ID */
	BSDI_PARTITION = 0xb7,      /* BSDI Partition ID */
	MINIX_PARTITION = 0x81,     /* Minix Partition ID */
	UNIXWARE_PARTITION = 0x63,  /* Same as GNU_HURD and SCO Unix */
};

void part_verify(int dev_nr,int type);

/* Verify the partition table of the disk of which dev_nr is a partition. May
   also try to "fix" a partition table. Fail on non-Linux partitions if the
   TYPE flag is non-zero (unless IGNORE-TABLE is set too). */

void preload_types(void);

/* Preload some partition types for convenience */

#endif
