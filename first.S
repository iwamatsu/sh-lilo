/* $Id: first.S,v 1.14 2000-09-09 12:37:25 gniibe Exp $
 *
 * Primary boot loader
 *
 *  lilo/arch/sh/first.S
 *
 *  Copyright (C) 2000  Niibe Yutaka
 *
 * This file is subject to the terms and conditions of the GNU General
 * Public License.
 *
 */

/*
 * NOTE: Keep this code "position independent", so that this works well
 *       among machines with different memory map.
 *
 *       Some machine starts its memmory at 0x08000000 (Area2),
 *       while others starts at 0x0c000000 (Area3).
 */

/*
 * Memory map:
 *  [ First Loader         ] 512
 *  [ Stack                ] 4096-512
 *  [ Second Loader        ] 4KB
 *  [ Reserved             ] 4KB
 *  [ MAP load area        ] 512
 *  [ Descriptor table 1/2 ] 512
 *  [ Descriptor table 2/2 ] 512
 *  [ Default Command Line ] 512
 *  [ Keyboard Translation ] 512
 *  [ Greeting Message     ] 512
 *  [ Reserved             ]
 *  [ Reserved             ]
 *
 */
	.global start
start:
	bra	real_start
	.byte	3	! This becomes "mov $r0, $r12" with next "l"
	!
	.ascii  "lba"	! special marker for LBA32
	!
	.ascii	"LILO"
	.word	1
#if 0
	/* EDIT HERE ! */
			! Depends LILO's version
	.word	20
#else
		      /* v--- Major Version */
	.word	4*256 + 21
	!    /* ^--- Minor Version*/     
#endif

/* x86 LILO parameters (Not used for SuperH... yet) */
timeout:.word	0		! input timeout
delay:	.word	0		! boot delay
port:	.byte	0		! COM port (0 = unused, 1 = COM1, etc.)
sparam:	.byte	0		! serial port parameters (0 = unused)

/* Timestamp (Filled by LILO command) */
tstamp:	.long	0

/* First descripter sector (Filled by LILO command) */
d1_cx:	.word	0
d1_dx:	.word	0
d1_al:	.byte	0

/* Second descripter sector (Filled by LILO command) */
d2_cx:	.word	0
d2_dx:	.word	0
d2_al:	.byte	0

/* Default command-line sector (Filled by LILO command) */
dc_cx:	.word	0
dc_dx:	.word	0
dc_al:	.byte	0

/* Prompt? (Filled by LILO command) */
prompt:	.byte	0		! indicates whether to always enter prompt
				! (also used as alignment byte)

/* Greeting message length & sector (Filled by LILO command) */
ms_len:	.word	0		! initial greeting message
ms_cx:	.word	0
ms_dx:	.word	0
ms_al:	.byte	0

/* Second descripter sector (Filled by LILO command) */
kt_cx:	.word	0		! keyboard translation table
kt_dx:	.word	0
kt_al:	.byte	0

d_addr:				! second stage sector addresses

	.long	0xffffffff
	.long	0xffffffff
	.long	0xffffffff
	.long	0xffffffff
	.long	0xffffffff
	.long	0xffffffff
	.long	0xffffffff
	.long	0xffffffff
	.long	0xffffffff
	.long	0xffffffff
	.long	0xffffffff

	.word	0xffff

	.align	2
real_start:
	/* Get base pointer, to be position independent */
	mova	next, $r0
	mov	#0x02, $r1
	shll8	$r1
	sub	$r1, $r0
	mov	$r0, $r12		! Base pointer
	!
	mov	#0x10, $r1
	shll8	$r1
	mov	$r12, $r15
	add	$r1, $r15		! Setup stack pointer
	!
	mov	#0x10, $r13		! buffer number
	!
	/* Enable cache */
	mov	#6, $r0			! Cache "on"
	mov	#0, $r4
	trapa	#0x3f
	!
	/* Output message "L" */
	mova	message, $r0
	mov	$r0, $r4
	mov	#1, $r5
	mov	#0, $r0			! Serial Output
	trapa	#0x3f
	!
	/* Load second stage loader */
	mov	#52, $r11	! #52: desc# of second stage loader
loop:	mov	$r11, $r4
	bsr	load_sector_address	! get $r4 (=dev) and $r5 (=lba)
	 add	$r12, $r4		! desc# --> address of descriptor
	bt	done
	!
	mov	$r13, $r6
	shll8	$r6
	bsr	read_a_sector
	 add	$r12, $r6	! buffer number -> buffer address
	!
	add	#2, $r13	! buffer # += 2
	bra	loop
	 add	#5, $r11	! next desc# is +5

done:
	/* Jump to the second loader */
	mov	#0x10, $r0
	shll8	$r0
	add	$r12, $r0	! Get the address into $r0
	jmp	@r0
	 mov	$r12, $r4	! First argument is base pointer

	.align	2
message:
	.string "L"

	.align	2
/*
 * LOAD_SECTOR_ADDRESS:
 *     Read the sector descripter (5-byte tuple), and translate
 *     it as device number and lba.  Set T flag if it's NULL.
 *
 * INPUT: $r4 (pointer to descripter (5-byte long, not aligned)
 * OUTPUT: $r4 (DEVICE #), $r5 (LBA) and T register (T when done)
 * Clobbers: $r0, $r1, $r2, $r3
 */
load_sector_address:
	mov.b	@$r4+, $r0
	extu.b	$r0, $r0
	mov.b	@$r4+, $r1
	extu.b	$r1, $r1
	mov.b	@$r4+, $r2
	extu.b	$r2, $r2
	mov.b	@$r4+, $r3
	extu.b	$r3, $r3
	!
	shll8	$r3
	or	$r3, $r1
	shll8	$r1
	or	$r0, $r1
	mov	$r1, $r5
	mov.b	@$r4, $r0
	cmp/eq	#0, $r0
	bt	1f		! NULL (end of descriptor)
	!
	/* Check if it's really LBA... */
	mov	$r2, $r0
	and	#0x0F, $r0	! Get device number
	mov	#0xc0, $r3
	extu.b	$r3, $r3
	cmp/hi	$r2, $r3
	bf	1f		! Unset T
	!
	/* It's not LBA!! */
	mova	not_lba_message, $r0
	mov	$r0, $r4
	mov	#36, $r5
	mov	#0, $r0			! Serial Output
	trapa	#0x3f
	sett			! End of descriptor
	!
1:	rts
	 mov	$r0, $r4	! device number

/*
 * READ a sector
 * INPUT: $r4 (DEVICE #), $r5 (LBA), $r6 (BUFFER ADDRESS)
 * OUTPUT: $r0 (RESULT)
 *
 * Invoke BIOS call READ_SECTORS with number_of_sectors=1.
 */
read_a_sector:
	mov	#2, $r0			! READ SECTORS
	mov	#1, $r7			! number of sectors
	trapa	#0x3f
	!
	tst	$r0, $r0
	bt	1f
	! /* ERROR */
	mova	read_error_message, $r0
	mov	$r0, $r4
	mov	#19, $r5
	mov	#0, $r0			! Serial Output
	trapa	#0x3f
	! /* Go to the monitor */
	mov	#0, $r0
	jmp	@$r0
	 nop
	!
1:	rts
	 nop

	.align	2
not_lba_message:
	.string "ERROR: Sector address is not in LBA\n"
	.align	2
read_error_message:
	.string "ERROR: Sector read\n"

	.align	9
next:
