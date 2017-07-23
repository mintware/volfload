# Use Borland Make >= 3.6

NASM = nasm
PKZIP = pkzip

prog = volfload.com
dist = $(prog:.com=.zip)

.asm.com:
	$(NASM) -f bin -o $@ -l $&.lst $<

.com.zip:
	$(PKZIP) $@ $<

dist: $(dist)

clean:
	del *.lst
	del *.obj
	del *.map
	del $(prog)
	del $(dist)
