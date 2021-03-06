| utility which dumps assembly-language as ready-to-paste "inline{" words
: X 'X emit ;
needs fasm
X
forth
: cr? 0; 16 mod 0if cr 9 emit then ;
: hexbytes 0do count .2x  space i cr?  loop drop ;
macro
::
	cr ." : "
	last @ >name ctype space
	." inline{ "
	lastxt here over - hexbytes
	." } ; " cr
	; alias ;
forth

: 1+ asm{ inc eax } ;
: 1- asm{ dec eax } ;
: 0; asm{ 
	or eax, eax
	jnz done
	lodsd
	ret
	done:
	} ;
: /char 
	asm{
	mov ebx, eax
	mov eax, [esi]
	lea esi, [esi+4]
	mov ecx, eax
	jecxz bad
	mov edi, [esi] ; ptr
next:	
    cmp byte [edi], bl	; matches?
	je match
	inc edi
	loop next
match: 
    ; edi -> matching character
	cmp byte [edi], bl
	jne bad
	jecxz bad
	mov eax, ecx
	mov [esi], edi
	ret
bad:	
    xor eax, eax
	mov [esi], eax
	} ;

: \char asm{
	mov ebx, eax
	mov eax, [esi]
	lea esi, [esi+4]
	mov ecx, eax
	jecxz bad
	mov edi, [esi] ; ptr
	add edi, ecx
	dec edi	; edi-> last character
next:	cmp byte [edi], bl	; matches?
	je match
	dec edi
	loop next
	jecxz bad
match: ; edi -> matching character
	cmp byte [edi], bl
	jne bad 
	sub eax, ecx
	inc eax
	mov [esi], edi
	ret
bad:	xor eax, eax
	mov [esi], eax
	} ;
: cmove> asm{
	; upop ecx
	mov ecx, eax	; N
	mov eax, [esi]
	lea esi, [esi+4]
	; upop edi
	mov edi, eax	; dest
	mov eax, [esi]
	lea esi, [esi+4]
	; upop edx
	mov edx, eax	; src
	mov eax, [esi]
	lea esi, [esi+4]
	jecxz c

a:	; overlap case
	add edx, ecx
	add edi, ecx
	align 4
b:
	dec edx
	dec edi

	mov bl, byte [edx] 
	nop
	mov byte [edi], bl

	loop b
c:
	} ;
| Look for a2 in a1; a3 is returned if flag is true
| Case-sensitive; Uses BRUTEFORCE algorithm
| ( a1 n1 a2 n2 -- a3 n3 1 | 0 )	
: search asm{
;	upop edx	; n2
	mov edx, eax
	mov eax, [esi]
	lea esi, [esi+4]

;	upop edi	; a2
	mov edi, eax
	mov eax, [esi]
	lea esi, [esi+4]

;	upop ecx	; n2
	mov ecx, eax
	mov eax, [esi]
	lea esi, [esi+4]

	; EAX:ECX ==> A1
	; EDI:EDX ==> A2
	; be unamused by zero-length or NULL strings:
	push eax
	push ecx
	jecxz failed
	or eax, eax
	jz failed
	or edx, edx
	jz failed
	or edi, edi
	jz failed

	; main loop: scan for possible match: first character matches:
	; EAX:ECX --> string to search in; we bump through it until we fall off
	; the end:
next:
	mov bh, byte [edi]	; first character of target - this won't change
findstart:
	mov bl, byte [eax]	; get first character of source string
	cmp bl, bh
	je maybe		; maybe we match; check it out
nomatch:	; nah, bump to next char
	inc eax
	loop findstart
	; if we made it here, we are big failures:
failed:
	xor eax, eax
	pop ecx		; drop n2
	pop ecx		; drop a2
	ret

maybe: ; EAX:ECX might be a match to EDI:EDX
	cmp ecx, edx
	jb failed	; string-to-match is longer than matchee
	mov ebp, edx	; save matcher length
	dec ebp
maybe2:
	mov bh, [edi+ebp]
	cmp bh, [eax+ebp]
	jne nomatch2
	dec ebp
	jns maybe2
	; fell off loop: we matched!
	;dup
	lea esi, [esi-4]
	mov [esi],eax

	pop eax		; N1
	sub eax, [esi]	; A1
	pop ebx
	add eax, ebx
	; upsh edx
	
	; dup
	lea esi, [esi-4]
	mov [esi],eax

success:
	mov eax, -1
	ret
nomatch2:
	inc eax
	dec ecx
	jmp next
	} ;
: do asm{
	mov ebx, eax
	lodsd
	push eax
	sub eax, ebx
	push eax
	lodsd
	} ;
: swap asm{
	mov ebx, eax
	mov eax, [esi]
	mov [esi], ebx
	} ;

: exec
	asm{
		lea ebx, [eax-4]
		mov ebx, [ebx]
		mov eax, [eax+4]
		jmp ebx
	}
	;
: outd ( value port -- ) asm{
	mov edx, eax
	lodsd
	out dx, eax
	lodsd
	} 
	;
: outw ( value port -- ) asm{
	mov edx, eax
	lodsd
	out dx, ax
	lodsd
	} 
	;
: outb ( value port -- ) asm{
	mov edx, eax
	lodsd
	out dx, al
	lodsd
	} 
	;

: ind ( port -- value ) asm{
	mov edx, eax
	in eax, dx
	} ;
: inw ( port -- value ) asm{
	mov edx, eax
	in ax, dx
	} ;
: inb ( port -- value ) asm{
	mov edx, eax
	in al, dx
	} ;
: xchg2 ( a1 a2 -- )
  asm{
    mov ebx, eax
    lodsd
    mov ecx, [ebx]
    mov edx, [eax]
    mov [ebx], edx
    mov [eax], ecx
    lodsd
  } ;
: -rot asm{
	push eax
	mov ebx, [esi+4]
	mov eax, [esi]
	mov [esi], ebx
	pop dword [esi+4]
	} ;
: rot asm{
	push eax
	mov eax, [esi+4]
	mov ebx, [esi]
	mov [esi+4], ebx
	pop dword [esi]
	} ;
: xchg asm{
	mov ebx, eax
	mov eax, [esi]
	lea esi, [esi+4]
	push eax
	mov eax, [ebx]
	pop dword [ebx]
	} ;
: d2/ asm{
	sar eax, 1
	sar dword [esi], 1
	} ;
: d2* asm{
	shl dword [esi], 1
	rcl eax,1
	} ;
: jmpto ( eax esi eip -- )
	asm{
		push eax
		mov eax, [esi+4]
		mov esi, [esi]
		ret
	} ;
: 0_ asm{
	xor eax, eax
	} ;
: 0__ asm{
	mov dword [esi], 0
	} ;
: 00 asm{
	xor ebx, ebx
	mov [esi], ebx
};
: rot6 asm{
	mov ecx, eax
	mov eax, [esi+4]
	mov ebx, [esi]
	mov [esi+4], ebx
	mov [esi], ecx
} ;
| 1 2 3	- ecx=1
| 3 2 3 = ecx=1
| 3 2 1
: -rot6 asm{
	mov ecx, [esi+4]
	mov [esi+4], eax
	mov ebx, [esi]
	mov [esi], ecx
	mov eax, ebx
} ;

: -swap asm{
	mov ebx,[esi+04]
	mov ecx,[esi]
	mov [esi],ebx
	mov [esi+04], ecx
} ;

: over2 | 2 pick
	dup
	asm{
	mov eax, [esi+8]
	} ;
: over3 | 3 pick
	dup
	asm{
	mov eax, [esi+12]
	} ;
: fover asm{
	fld st1
	} ;
: xchgc ( a1 a2 -- )
  asm{
    mov ebx, eax
    lodsd
    mov cl, [ebx]
    mov dl, [eax]
    mov [ebx], dl
    mov [eax], cl
    lodsd
  } ;
 
: _1- asm{
	dec dword [esi]
	} ;
: _1+ asm{
	inc dword [esi]
	} ;

: _+ asm{
	add dword [esi+4], eax
	lodsd
} ;

: d+!	asm{
		mov ebx, eax	; addr = EBX
		lodsd
		add dword [ebx+4], eax
		lodsd
		add dword [ebx], eax
		lodsd
	} ;

: 0;drop asm{
	or eax, eax
	lodsd
	jnz done
	ret
done:
	} ;

: + asm{
	add [esi] ,eax
	lodsd
	} ;
: - asm{
	sub [esi] ,eax
	lodsd
	neg eax
	} ;

: + asm{
	add [esi] ,eax
	} ;
: pop>eax asm{
	mov eax, [esi]
	lea esi, [esi+4] 
	} ;
: and asm{ 
	and [esi], eax 
	} ;
: or asm{ 
	or [esi], eax 
	} ;
: xor asm{ 
	xor [esi], eax 
	} ;
: over 
	dup
	asm{ 
		mov eax, [esi+4] 
	} ;
: lcount
	dup
	asm{
		add dword [esi], 4
	}
	@ ; 
: 0term asm{
	mov ebx, eax
	add ebx, [esi]
	mov byte [ebx], 0
	} ;

: ddo asm{
	mov ebx, eax
	lodsd
	push eax
	sub eax, ebx
	push eax
	lodsd
	} ;
: rot asm{
	push eax
	mov eax, [esi+4]
	mov ebx, [esi]
	mov [esi+4], ebx
	pop dword [esi]
	} ;
: -rot asm{
	push eax
	mov ebx, [esi+4]
	mov eax, [esi]
	mov [esi], ebx
	pop dword [esi+4]
	} ;
: xchg asm{
    mov ebx,[eax]
    mov ecx,[esi]
    mov [eax],ecx
    mov eax,ebx
    lea esi,[esi+4]
	} ;
: tuck asm{
    lea esi,[esi-4]
    mov ebx,[esi+4]
    mov [esi],ebx
    mov [esi+4],eax
	} ;
: bounds asm{
	mov ebx, [esi]
	add [esi], eax
	mov eax, ebx
	} ;
: >rr asm{
	pop ebx
	push eax
	push ebx
	lodsd
	} ;
: rr> 
	dup
	asm{
	pop ecx
	pop ebx
	pop eax
	push ebx
	push ecx
	} ;

: later asm{
	pop ebx 
	pop ecx
	push ebx
	push ecx
	} ;

: next^2 asm{
	mov ebx, eax
	bsr ebx,eax
	shl eax,2
} ;
: f2^ ( f:y f:x -- f:x^y )
	asm{
	;	fyl2x			;	st0 = log(st0) * st1 = y log(x)
		fld  st0			;   ylogx, ylogx
		frndint         ; round it to an integer
						; ylogx, int[ylogx]
		fsub st1, st0	; int[ylogx], ylogx-int[ylogx] (= z)
		fxch
		f2xm1			; get the fractional power of 2 (minus 1)
						; int[ylogx], 2^z-1
		fld1			; int[ylogx], 2^z-1, 1
		faddp st1,st0    ; int[ylogx], 2^z
		fscale			; add the integer in ST(1) to the exponent of ST(0)
						; effectively multiplying the content of ST(0) by 2int
						; and yielding the final result of xy:
						; int[ylogx], x^y
		fstp st1		; fnip 
	} ;

: f/2 ( f: a -- a/2 )  
  asm{ 
   fld1
   fadd  st0, st0
   fxch
   fdivrp
  } ;
: fln		| F: f -- ln(f) | Floating point log base e. 
 asm{
  fldln2
  fxch
  fyl2x
 } ;
: fdup asm{
	 fst st1 ;, st0
	} ;

: >sp asm{
	mov esi, eax
	lodsd
	} ;
: >spexec ( param sp xt -- )
	asm{
		mov ebx, eax		; EBX=xt
		lodsd
		push eax			 
		lodsd				; EAX=param
		push eax
		lodsd
		pop eax
		pop esi
		jmp ebx
	} ;
: edx>eax asm{
	mov eax, edx
	} ;


: /umod asm{
	mov ebx, eax
	mov eax, [esi]
	xor edx, edx
	div ebx
	mov [esi], edx
	} ;


: docb asm{
	pop eax
	pusha
	mov esi, esp
	sub esp, 40h
	call a
	add esp, 40h
	popa
	ret
a: jmp eax
	} ;

: ret ( n -- ) 
	asm{
	mov ecx, eax
	lodsd
	pop ebx
a: pop edx
	loop a
	jmp ebx
	} ;

: callback-std asm{
	pop eax
	push ebx
	mov ebx, eax
	mov eax, esp
	add eax, 4

	push ebp
	push esi
	push edi
	push edx
	push ecx

	mov esi, esp
	sub esp, 64*4
	call a
	add esp, 64*4

	; restore registers except EAX:
	pop ecx
	pop edx
	pop edi
	pop esi
	pop ebp
	pop ebx

	ret 0xdd
a: jmp ebx
	} ;

: callback asm{
	pop eax
	push ebx
	mov ebx, eax
	mov eax, esp
	add eax, 4

	push ebp
	push esi
	push edi
	push edx
	push ecx

	mov esi, esp
	sub esi, 4
	sub esp, 64*4
	call a
	add esp, 64*4

	; restore registers except EAX:
	pop ecx
	pop edx
	pop edi
	pop esi
	pop ebp
	pop ebx

	ret 
a: jmp ebx
	} ;

: ftst asm{
	ftst
	} ;

: callback asm{
	pop eax
	pusha
	mov esi, esp
	sub esp, 40h
	call a
	add esp, 40h
	popa
	ret
a: jmp eax
	} ;

: (callback) asm{
	xchg ebx, [esp]
	lea eax, [esp+4]
	push ebp
	push esi
	push edi
	lea esi, [esp-4]
	sub esp,0x1000
	call a
	add esp,0x1000
	pop edi
	pop esi
	pop ebp
	pop ebx
	ret
a: jmp ebx
} ;

: fwait asm{ fwait } ;

: ! asm{ 
	mov ebx, [esi]
	mov [eax], ebx
	lodsd
	lodsd
	}
	;


: rot asm{
	; esi+4 esi eax
	; esi eax esi+4
;	xchg eax, [esi]		; esi+4 eax esi
;	xchg eax, [esi+4]   ; esi  eax esi+4
	mov ebx, [esi]
	mov [esi], eax
	mov eax, [esi+4]
	mov [esi+4], ebx
	} ;
: -rot asm{
	; esi+4 esi eax
	; eax esi+4 esi
	mov ebx, [esi+4]
	mov [esi+4], eax
	mov eax, [esi]
	mov [esi], ebx
	} ;

: 2over asm{
	; [esi+8] [esi+4] [esi] eax
	; [esi+8] [esi+4] [esi] eax [esi+8] [esi+4]
	} ;

: && asm{
	mov ebx, eax
	lodsd
	mov ecx, eax

	xor eax, eax

	bsf ebx, ebx
	jz a
	bsf ebx, ecx
	jz a
	dec eax
a: 
 } ;

: && asm{
	mov ebx, eax
	lodsd
	or eax, eax
	jz a
	xor eax, eax
	or ebx, ebx
	jz a
	dec eax
a: 
 } ;
: && asm{
	mov ebx, eax
	lodsd
	neg ebx
	sbb ebx, ebx
	neg eax
	sbb eax, eax
	and eax, ebx
 } ;
: || asm{
	mov ebx, eax
	lodsd
	neg ebx
	sbb ebx, ebx
	neg eax
	sbb eax, eax
	or eax, ebx
	} ;

: 2over asm{
	; [esi+8] [esi+4] [esi] eax
	; [esi+8]  [esi+4]    [esi]     eax [esi+8] [esi+4]
	; [esi+16] [esi+12] [esi+8] [esi+4] [esi] eax

	; lea edi, [esi+8]
	sub esi, 8
	mov [esi+4], eax
	mov ebx, [esi+16]
	mov [esi], ebx
	mov eax, [esi+12]
	} ;


: swap asm{
	xor eax, [esi]
	xor [esi], eax
	xor eax, [esi]
} ;
: swap asm{
	mov ebx, eax
	mov eax, [esi]
	mov [esi], ebx
	} ;

: off asm{
	mov dword [eax],0
	} ;

: jmp@ asm{
	jmp dword [joe]
	nop
	joe: dd 123
	} ;
: swap asm{
	xchg [esi], eax
} ;

: third ( a b c -- a b c a ) | 2 pick
	dup
	asm{
		mov eax, [esi+8]
} ;
: fourth ( a b c d -- a b c d a ) | 3 pick
	dup
	asm{
		mov eax, [esi+12]
} ;

: callf asm{ call [1234] } ;
: jmpf asm{ jmp [1234] } ;

| EAX points to registers
| EIP ESP EBP EAX ECX EDX EBX ESI EDI 
|  0   4   8   12  16  20  24  28  32
|  pushad order: eax, ecx, edx, ebx, esp, ebp, esi, edi
: loadregs asm{
	; eax is base from which to start
	mov ebx, dword [eax]
	dec ebx
	mov ecx, dword [eax+4]
	sub ecx, 4
	mov dword [ecx], ebx
	mov dword [eax+4], ecx

	push dword [eax+12]
	push dword [eax+16]
	push dword [eax+20]
	push dword [eax+24]
	push dword [eax+4]
	push dword [eax+8]
	push dword [eax+28]
	push dword [eax+32]
	popad
	ret
} ;

| EAX points to registers
| EIP ESP EBP EAX ECX EDX EBX ESI EDI 
|  0   4   8   12  16  20  24  28  32
: loadregs2 asm{
	mov ebx, [eax]		; eip
	dec ebx
	mov esp, [eax+4]
	push ebx
	mov ebx, [eax+24]
	mov ecx, [eax+16]
	mov edx, [eax+20]
	mov esi, [eax+28]
	mov edi, [eax+32]
	mov ebp, [eax+8]
	mov eax, [eax+12]
	ret
	} ;

| x n
: <<< asm{
	mov ecx, eax
	lodsd
	rol eax, cl
	} ;
: >>> asm{
	mov ecx, eax
	lodsd
	ror eax, cl
	} ;

: 5lrot asm{
	rol eax, 5 
	} ;
: 30lrot asm{
	rol eax,  30
	} ;
: 1lrot asm{
	rol eax, 1 
	} ;
: >sp asm{
	mov esi, eax
	} ;

: _r@ 
	dup
	asm{
		mov eax, [esp+8]
	} ;

: 32>f 
	asm{
		push eax
		fld dword [esp]
		pop ebx
	}
	drop
	;
: 64>f 
	asm{
		push eax
		mov ebx, [esi]
		push ebx
		fld qword [esp]
		pop ebx
		pop ebx
	}
	drop
	drop
	;
| same as "over swap":
: _dup ( a b -- a a b ) asm{
	mov ebx, [esi]
	sub esi, 4	
	mov [esi], ebx
} ;

: __dup ( a b c -- a a b c ) 
	asm{
		sub esi,4
		mov ebx, [esi+4]
		mov [esi], ebx
		mov ebx, [esi+8]
		mov [esi+4], ebx
} ;
: ___dup ( a b c d -- a a b c d ) 
	asm{
		sub esi,4
		mov ebx, [esi+4]
		mov [esi], ebx
		mov ebx, [esi+8]
		mov [esi+4], ebx
		mov ebx, [esi+12]
		mov [esi+8], ebx
} ;
: _nip ( a b c d -- a c d ) 
	asm{
		mov ebx, [esi]
		add esi,4
		mov [esi], ebx
	}
	;
: (callback) asm{
	xchg ebx, [esp]
	lea eax, [esp+8]
	push ebp
	push esi
	push edi
	lea esi, [esp-4]
	sub esp,0x1000
	call ebx
	add esp,0x1000
	pop edi
	pop esi
	pop ebp
	pop ebx
	ret
} ;

: / asm{
	mov	ebx, eax
	lodsd
	cdq
	idiv ebx
	} ;
: mod asm{
	mov	ebx, eax
	lodsd
	cdq
	idiv ebx
	mov eax, edx
	} ;

: lcount
	dup
	asm{
		add dword [esi], 4
		mov [eax], eax
	}
	; 
: @++ asm{
	mov ebx, eax
	mov eax, [eax]
	inc dword [ebx]
	} ;

	;

: 0>00;
	asm{
		test eax, eax
		jnz ok
		; dup
		lea esi, [esi-4]
		mov [esi], eax
		pop ebx
		ret
		ok:
	} ;

: 15and asm{
	and eax, 511
	} ;
: put | x n put
	asm{
	mov ebx, eax
	lodsd
	mov [esi+4*ebx], eax
	lodsd
	} ;

	|    20 16 12  8  4  eax
: roll5 ( e  d  c  b  a  temp -- d c b a temp )
	asm{
		mov ebx, [esi+12]		; d=c
		mov [esi+16], ebx		
		mov ebx, [esi+8]		; c=b<<<30
		mov [esi+12], ebx		
		mov ebx, [esi+4]		; b=a
		rol ebx, 30
		mov [esi+8],ebx		; 
		mov ebx, [esi]		; b=a
		mov [esi+4],ebx		; 
		lea esi, [esi+4]
	} ;

| d c b -- bc or b'd
: F 
	dup
	| eax == b, 
	|
	asm{
		mov eax, [esi+4]
		mov ebx, eax
		not ebx
		and ebx, [esi+12]
		and eax, [esi+8]
		or eax, ebx
		add eax, 0x5a827999
} ;

| d c b -- bc or bd or cd
: G dup
	asm{
		mov eax, [esi+4]
		mov ebx, eax
		and ebx, [esi+8]
		and eax, [esi+12]
		or eax, ebx
		mov ebx, [esi+8]
		and ebx, [esi+12]
		or eax, ebx
		add eax, 0x8f1bbcdc
} ;
: H 
	dup asm{
		mov eax, [esi+4]
		xor eax, [esi+8]
		xor eax, [esi+12]
} ;

: @bswap ( a -- a@' )
	asm{
		mov ebx, eax
		mov eax, [eax]
		bswap eax
		mov [ebx], eax
	}
	;
: roll ( xn xn-1 ... x1 n -- xn-1 xn-2 ... x1 xn )
	asm{
		mov ecx, eax
		mov eax, [esi+4*ecx-4]
		push esi
		push edi
		std
		mov edi, esi
		sub esi, 4
		rep movsd
		cld
		pop edi
		pop esi
		add esi,4
	}
	;

: blk ( block i -- )
	asm{
		mov ebx, eax
		lodsd
		; eax->block, ebx->i
		add ebx, 2
		and ebx, 15
		mov ecx, [eax+ebx]

		add ebx, 6	; +8
		and ebx, 15
		mov edx, [eax+ebx]
		xor ecx, edx

		add ebx, 5	; +13
		and ebx, 15
		mov edx, [eax+ebx]
		xor ecx, edx

		add ebx, 2	; +15
		and ebx, 15
		mov edx, [eax+ebx]
		xor ecx, edx

		rol ecx, 1

		mov [eax+ebx], ecx
		lodsd
	}
	;

: x asm{ add [ebp], eax } ;
: x asm{ add eax, [ebp] } ;
: y asm{
		test eax, eax
		jz zzz
		inc eax
	zzz:
		dec eax
	} ;
bye
