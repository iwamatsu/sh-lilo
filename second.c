static void put_string (unsigned char *);

void
start (void)
{
  put_string ("LI\n");
  {
    while (1)
      {
	for (i=0; i<65536; i++)
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

  asm volatile  ("trapa	#0x3F"
		 : "=z" (__sc0)
		 : "0" (__sc0), "r" (__sc4)
		 : "memory");
}
