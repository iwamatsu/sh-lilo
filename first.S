/* $Id: first.S,v 1.8 2000-07-20 09:47:23 gniibe Exp $
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
	.word	20

timeout:.word	0		! input timeout
delay:	.word	0		! boot delay
port:	.byte	0		! COM port (0 = unused, 1 = COM1, etc.)
sparam:	.byte	0		! serial port parameters (0 = unused)

tstamp:	.long	0		! timestamp

d1_cx:	.word	0		! first descriptor sector address
d1_dx:	.word	0
d1_al:	.byte	0		! (unused)

d2_cx:	.word	0		! second descriptor sector address
d2_dx:	.word	0
d2_al:	.byte	0		! (unused)

dc_cx:	.word	0		! default command-line sector address
dc_dx:	.word	0
dc_al:	.byte	0		! (unused)

prompt:	.byte	0		! indicates whether to always enter prompt
				! (also used as alignment byte)

ms_len:	.word	0		! initial greeting message
ms_cx:	.word	0
ms_dx:	.word	0
ms_al:	.byte	0		! (unused)

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
	mova	message, $r0
	mov	$r0, $r4
	mov	#1, $r5			! So that this works new BIOS
	mov	#0, $r0			! Serial Output
	trapa	#0x3f
	 nop
	!
	mov	#52, $r11		! Second stage loader
loop:	mov	$r11, $r4
	bsr	load_sector_address	! set $r4 (=dev) and $r5 (=lba)
	 add	$r12, $r4
	bt	done
	mov	$r13, $r6
	shll8	$r6
	bsr	read_a_sector
	 add	$r12, $r6
	add	#2, $r13
	bra	loop
	 add	#5, $r11

done:
	! jump to the second loader
	mov	#0x10, $r0
	shll8	$r0
	add	$r12, $r0
	jmp	@r0
	 mov	$r12, $r4

	.align	2
message:
	.string "L"

	.align	2
/*
 * Clobbers: $r0, $r1, $r2, $r3
 * INPUT: $r4 (pointer to descripter (5-byte long, not aligned)
 * OUTPUT: $r4 (DEVICE #), $r5 (LBA) and T register (T when done)
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
	! /* XXX: Should check it's LBA... */
	shll8	$r3
	or	$r3, $r1
	shll8	$r1
	or	$r0, $r1
	mov	$r1, $r5
	mov.b	@$r4, $r0
	cmp/eq	#0, $r0
	and	#0x0F, $r0	! XXX: Should check > 0xc0
	rts
	 mov	$r0, $r4	! device number

/*
 * Clobbers $r0
 */
read_a_sector:
	mov	#2, $r0			! READ SECTORS
	mov	#1, $r7			! number of sectors
	trapa	#0x3f
	 nop
	! XXX: should check error

	rts
	 nop

	.align	9
next:
