CROSS_COMPILE= sh-linux-gnu-

CC	=$(CROSS_COMPILE)gcc -I.
LD	=$(CROSS_COMPILE)ld
OBJCOPY=$(CROSS_COMPILE)objcopy

boot.b:	first.bin second.bin
	cat first.bin second.bin >boot.b

first.bin: first.exe
	$(OBJCOPY) -S first.exe -O binary first.bin

second.bin: second.exe
	$(OBJCOPY) -R .comment -S second.exe -O binary second.bin

first.exe: first.o
	$(LD) -EL -e start first.o -o first.exe -Ttext 0xac200000

second.exe: second.o string.o
	$(LD) -T second.lds -EL -e start second.o string.o -o second.exe -Ttext 0xac201000

first.o: first.S
	$(CC) -O2 -g -ml -m3 -pipe -c first.S

second.o: second.c
	$(CC) -O2 -g -ml -m3 -Wall -pipe -fpic -c second.c

string.o: string.c
	$(CC) -O2 -g -ml -m3 -Wall -pipe -c string.c

clean:
	rm -f *.o boot.b *.exe *.bin
