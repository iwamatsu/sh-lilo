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
	mov	$r0, $r12	! base pointer
	mov	#0x02, $r13	! buffer number
	!
	mov	#24, $r4	! First descriptor
	bsr	load_sector_address
	 add	$r12, $r4
	mov	$r13, $r6
	shll8	$r6
	bsr	read_a_sector
	 add	$r12, $r6
	add	#2, $r13
	!
	mov	#29, $r4	! Second descriptor
	bsr	load_sector_address
	 add	$r12, $r4
	mov	$r13, $r6
	shll8	$r6
	bsr	read_a_sector
	 add	$r12, $r6
	add	#2, $r13
	!
	mov	#34, $r4	! Default command line
	bsr	load_sector_address
	 add	$r12, $r4
	mov	$r13, $r6
	shll8	$r6
	bsr	read_a_sector
	 add	$r12, $r6
	add	#2, $r13
	!
	! Check length & prompt
	!
	mov	#39, $r4
	add	$r12, $r4
	mov.b	@$r4, $r0	! prompt
	! XXX: emit prompt...
	mov	#40, $r4
	add	$r12, $r4
	mov.w	@$r4, $r0	! greeting message length
	cmp/eq	#0, $r0
	bt	no_message
	!
	mov	#42, $r4	! Greeting message
	bsr	load_sector_address	! set $r4 (=dev) and $r5 (=lba)
	 add	$r12, $r4
	mov	$r13, $r6
	shll8	$r6
	bsr	read_a_sector
	 add	$r12, $r6
no_message:
	add	#2, $r13
	!
	mov	#47, $r4	! Keyboad translation table
	bsr	load_sector_address	! set $r4 (=dev) and $r5 (=lba)
	 add	$r12, $r4
	mov	$r13, $r6
	shll8	$r6
	bsr	read_a_sector
	 add	$r12, $r6
	add	#8, $r13
	!
	mov	#52, $r11	! second stage loader
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
	mova	m4, $r0
	mov	$r0, $r4
	mov	#0, $r0			! Serial Output
	trapa	#0x3f
	 nop
	!

	! jump to the second loader
	mov	#16, $r0
	shll8	$r0
	add	$r12, $r0
	jmp	@r0
	 nop

	.align	2
m4:
	.string "XXX!\n"
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
	rts
	 mov	#0, $r4		! hard coded now

/*
 * Clobbers $r0
 */
read_a_sector:
	mov	#2, $r0			! READ SECTORS
	mov	#1, $r7			! number of sectors
	trapa	#0x3f
	 nop
	! XXX: should check error

	mova	m2, $r0
	mov	$r0, $r4
	mov	#0, $r0			! Serial Output
	trapa	#0x3f
	 nop

	rts
	 nop

	.align	2
m2:
	.string "X!\n"

	.align	9
next:
2:
	mov	#6, $r1
	mov.l	led2, $r2
	mov.b	$r1, @$r2

	mova	message2, $r0
	mov	$r0, $r4
	mov	#0, $r0			! Serial Output
	trapa	#0x3f
	 nop
	mov	#127, $r0
	shll8	$r0
	shll8	$r0
	tst	$r0, $r0
1:
	bf/s	1b
	 dt	$r0
	bra	2b
	 nop

	.align	2
message2:
	.string "Hello World!!\n"
	.align	2
led2:	.long	0xa8000000
