;
; Loader for Volfied
;
; Copyright (c) 2017 Vitaly Sinilin
;
; 23 Jul 2017
;

; Volfied runs well on XTs, so the loader must do so.
cpu 8086
[map all volfload.map]

%macro res_fptr 0
.off		resw	1
.seg		resw	1
%endmacro

PSP_SZ		equ	100h
STACK_SZ	equ	64
RETN_OPCODE	equ	0C3h

struc prginfo
pi_cp_passed	resw	1
pi_cp_proc	resw	1
endstruc

section .text

		org	PSP_SZ

		jmp	short main
byemsg		db	"Visit http://sinil.in/mintware/volfied/$"

main:		mov	sp, __stktop
		mov	bx, sp
		mov	cl, 4
		shr	bx, cl				; new size in pars
		mov	ah, 4Ah				; resize memory block
		int	21h

		mov	bx, __bss_size
.zero_bss:	dec	bx
		mov	byte [__bss + bx], bh
		jnz	.zero_bss

		mov	[cmdtail.seg], cs		; pass cmd tail from
		mov	word [cmdtail.off], 80h		; our PSP

		mov	ax, 3521h			; read int 21h vector
		int	21h				; es:bx <- cur handler
		mov	[int21.seg], es			; save original
		mov	[int21.off], bx			; int 21h vector

		mov	dx, int_handler			; setup our own
		mov	ax, 2521h			; handler for int 21h
		int	21h				; ds:dx -> new handler

		mov	dx, exe
		push	ds
		pop	es
		mov	bx, parmblk
		mov	ax, 4B00h			; exec
		int	21h

		jnc	.success
		call	uninstall
		mov	dx, errmsg
		jmp	short .exit

.success:	mov	dx, byemsg
.exit:		mov	ah, 9
		int	21h
		mov	ah, 4Dh				; read errorlevel
		int	21h				; errorlevel => AL
		mov	ah, 4Ch				; exit
		int	21h

;------------------------------------------------------------------------------

int_handler:	pushf
		push	ax
		push	si

		cmp	ah, 3Dh
		jne	.malloc

		; volfied.exe reads one of cga.prg, ega.prg, tga.prg or vga.prg
		; with this call. We intercept it to take note of what program
		; will be actually loaded as each one has different offsets for
		; patch. DS:DX -> ASCIIZ filename
		mov	si, dx
		lodsb
		mov	[cs:prgletter], al
		jmp	short .legacy

.malloc:	cmp	ah, 48h
		jne	.legacy
		dec	byte [cs:intcnt]
		jnz	.legacy

		push	bx

		xor	bx, bx
		mov	al, [cs:prgletter]
		cmp	al, 'C'
		je	.patch

		inc	bx
		cmp	al, 'E'
		je	.patch

		inc	bx
		cmp	al, 'T'
		je	.patch

		inc	bx
.patch:		shl	bx, 1
		shl	bx, 1
		lea	bx, [prginfos + bx]
		mov	si, [cs:bx + pi_cp_proc]
		mov	byte [si], RETN_OPCODE	; skip prot. question
		mov	si, [cs:bx + pi_cp_passed]
		mov	byte [si], 1		; imitate correct answer

		push	dx
		call	uninstall	; restore original vector of int 21h
		pop	dx

		pop	bx

.legacy:	pop	si
		pop	ax
		popf
		jmp	far [cs:int21]

;------------------------------------------------------------------------------

uninstall:	push	ds
		lds	dx, [cs:int21]
		mov	ax, 2521h
		int	21h
		pop	ds
		ret

;------------------------------------------------------------------------------

prginfos:

cga_prginfo	istruc prginfo
	at	pi_cp_passed,	dw	7D4Ah
	at	pi_cp_proc,	dw	7EB4h
		iend

ega_prginfo	istruc prginfo
	at	pi_cp_passed,	dw	80F8h
	at	pi_cp_proc,	dw	8254h
		iend

tandy_prginfo	istruc prginfo
	at	pi_cp_passed,	dw	84D2h
	at	pi_cp_proc,	dw	863Ah
		iend

vga_prginfo	istruc prginfo
	at	pi_cp_passed,	dw	8280h
	at	pi_cp_proc,	dw	83DCh
		iend

intcnt		db	2
errmsg		db	"Unable to exec original "
exe		db	"volfied.exe",0,"$"


section .bss follows=.text nobits

__bss		equ	$
int21		res_fptr
prgletter	resb	1
parmblk		resw	1				; environment seg
cmdtail		res_fptr				; cmd tail
		resd	1				; first FCB address
		resd	1				; second FCB address
__bss_size	equ	$-__bss


section .stack align=16 follows=.bss nobits

		resb	(STACK_SZ+15) & ~15		; make sure __stktop
__stktop	equ	$				; is on segment boundary
