/* math functions */
/* functions prefixed with "x" are not used, as they are linked from ntdll.lib */

/* int _fltused = 0; -- in ntdll.lib too */
int _sse2_available = 0;

__declspec(naked) void __fastcall _get_sse2_info()
{
    __asm
    {
        mov     edi, edi
        push    ebp
        mov     ebp, esp
        sub     esp, 18h
        xor     eax, eax
        push    ebx
        mov     [ebp-04h], eax
        mov     [ebp-0Ch], eax
        mov     [ebp-08h], eax
        push    ebx
        pushf
        pop     eax
        mov     ecx, eax
        xor     eax, 200000h
        push    eax
        popf
        pushf
        pop     edx
        sub     edx, ecx
        jz      short get_sse2_info_no_SSE_POP
        push    ecx
        popf
        xor     eax, eax
        cpuid
        mov     [ebp-0Ch], eax
        mov     [ebp-18h], ebx
        mov     [ebp-14h], edx
        mov     [ebp-10h], ecx
        mov     eax, 1
        cpuid
        mov     [ebp-04h], edx
        mov     [ebp-08h], eax
get_sse2_info_no_SSE_POP:
        pop     ebx
        test    [ebp-04h], 4000000h
        jnz      short get_sse2_info_no_SSE
        xor     eax, eax
        inc     eax
        
get_sse2_info_exit:
        pop     ebx
        leave
        retn

get_sse2_info_no_SSE:
        xor     eax, eax
        jmp     short get_sse2_info_exit
    }
}

__declspec(naked) void __fastcall __initmath()
{
    __asm
    {
        call        _get_sse2_info
        mov         _sse2_available, eax
        xor         eax, eax
        retn
    }
}

__declspec(naked) void __cdecl _ftol2()
{
	__asm
	{
		push        ebp
		mov         ebp,esp
		sub         esp,20h
		and         esp,0FFFFFFF0h
		fld         st(0)
		fst         dword ptr [esp+18h]
		fistp       qword ptr [esp+10h]
		fild        qword ptr [esp+10h]
		mov         edx,dword ptr [esp+18h]
		mov         eax,dword ptr [esp+10h]
		test        eax,eax
		je          integer_QnaN_or_zero
	arg_is_not_integer_QnaN:
		fsubp       st(1),st
		test        edx,edx
		jns         positive
		fstp        dword ptr [esp]
		mov         ecx,dword ptr [esp]
		xor         ecx,80000000h
		add         ecx,7FFFFFFFh
		adc         eax,0
		mov         edx,dword ptr [esp+14h]
		adc         edx,0
		jmp         localexit
	positive:
		fstp        dword ptr [esp]
		mov         ecx,dword ptr [esp]
		add         ecx,7FFFFFFFh
		sbb         eax,0
		mov         edx,dword ptr [esp+14h]
		sbb         edx,0
		jmp         localexit
	integer_QnaN_or_zero:
		mov         edx,dword ptr [esp+14h]
		test        edx,7FFFFFFFh
		jne         arg_is_not_integer_QnaN
		fstp        dword ptr [esp+18h]
		fstp        dword ptr [esp+18h]
	localexit:
  		leave
  		retn
	}
}

__declspec(naked) void __cdecl _ftol2_sse()
{
    __asm
    {
        cmp         _sse2_available, 0
        jnz         do_ftol2_sse
        jmp         _ftol2
    do_ftol2_sse:
        push        ebp
        mov         ebp, esp
        sub         esp, 8
        and         esp, 0FFFFFFF8h
        fstp        qword ptr [esp]
        cvttsd2si   eax, [esp]
        leave
        retn
    }
}


/* Copyright (c) Microsoft Corporation. All rights reserved. */
/*
; allmul - long multiply routine
;
; Purpose:
;       Does a long multiply (same for signed/unsigned)
;       Parameters are not changed.
;
; Entry:
;       Parameters are passed on the stack:
;               1st pushed: multiplier (QWORD)
;               2nd pushed: multiplicand (QWORD)
;
; Exit:
;       EDX:EAX - product of multiplier and multiplicand
;       NOTE: parameters are removed from the stack
;
; Uses:
;       ECX
;
; Exceptions:
;
*/
__declspec(naked) void __cdecl x_allmul()
{
    __asm {
#define ALO     [esp + 4]       /* stack address of a loword */
#define AHI     [esp + 8]       /* stack address of a hiword */
#define BLO     [esp + 12]      /* stack address of b loword */
#define BHI     [esp + 16]      /* stack address of b hiword */

;             ALO * BLO
;       ALO * BHI
; +     BLO * AHI
; ---------------------
;

        mov     eax, AHI
        mov     ecx, BHI
        or      ecx, eax        ; test for both hiwords zero.
        mov     ecx, BLO
        jnz     short hard      ; both are zero, just mult ALO and BLO

        mov     eax, ALO
        mul     ecx

        ret     16              ; callee restores the stack

hard:
        push    ebx

; must redefine A and B since esp has been altered
#define A2LO    [esp + 8]       /* stack address of a loword */
#define A2HI    [esp + 12]      /* stack address of a hiword */
#define B2LO    [esp + 16]      /* stack address of b loword */
#define B2HI    [esp + 20]      /* stack address of b hiword */

        mul     ecx             ; eax has AHI, ecx has BLO, so AHI * BLO
        mov     ebx, eax        ; save result

        mov     eax, A2LO
        mul     dword ptr B2HI  ; ALO * BHI
        add     ebx, eax        ; ebx = ((ALO * BHI) + (AHI * BLO))

        mov     eax, A2LO       ; ecx = BLO
        mul     ecx             ; so edx:eax = ALO*BLO
        add     edx, ebx        ; now edx has all the LO*HI stuff

        pop     ebx

        ret     16              ; callee restores the stack
    }
}

/* Copyright (c) Microsoft Corporation. All rights reserved. */
/*
; alldiv - signed long divide
;
; Purpose:
;       Does a signed long divide of the arguments.  Arguments are
;       not changed.
;
; Entry:
;       Arguments are passed on the stack:
;               1st pushed: divisor (QWORD)
;               2nd pushed: dividend (QWORD)
;
; Exit:
;       EDX:EAX contains the quotient (dividend/divisor)
;       NOTE: this routine removes the parameters from the stack.
;
; Uses:
;       ECX
;
; Exceptions:
;
*/
__declspec(naked) void __cdecl x_alldiv()
{
    __asm {
        push    edi
        push    esi
        push    ebx

; Set up the local stack and save the index registers.  When this is done
; the stack frame will look as follows (assuming that the expression a/b will
; generate a call to lldiv(a, b)):
;
;               -----------------
;               |               |
;               |---------------|
;               |               |
;               |--divisor (b)--|
;               |               |
;               |---------------|
;               |               |
;               |--dividend (a)-|
;               |               |
;               |---------------|
;               | return addr** |
;               |---------------|
;               |      EDI      |
;               |---------------|
;               |      ESI      |
;               |---------------|
;       ESP---->|      EBX      |
;               -----------------
;

#define dDVNDLO  [esp + 16]      /* stack address of dividend (a) loword */
#define dDVNDHI  [esp + 20]      /* stack address of dividend (a) hiword */
#define dDVSRLO  [esp + 24]      /* stack address of divisor (b) loword */
#define dDVSRHI  [esp + 28]      /* stack address of divisor (b) hiword */


; Determine sign of the result (edi = 0 if result is positive, non-zero
; otherwise) and make operands positive.

        xor     edi,edi         ; result sign assumed positive

        mov     eax,dDVNDHI      ; hi word of a
        or      eax,eax         ; test to see if signed
        jge     short L1        ; skip rest if a is already positive
        inc     edi             ; complement result sign flag
        mov     edx,dDVNDLO      ; lo word of a
        neg     eax             ; make a positive
        neg     edx
        sbb     eax,0
        mov     dDVNDHI,eax      ; save positive value
        mov     dDVNDLO,edx
L1:
        mov     eax,dDVSRHI     ; hi word of b
        or      eax,eax         ; test to see if signed
        jge     short L2        ; skip rest if b is already positive
        inc     edi             ; complement the result sign flag
        mov     edx,dDVSRLO     ; lo word of a
        neg     eax             ; make b positive
        neg     edx
        sbb     eax,0
        mov     dDVSRHI,eax     ; save positive value
        mov     dDVSRLO,edx
L2:

;
; Now do the divide.  First look to see if the divisor is less than 4194304K.
; If so, then we can use a simple algorithm with word divides, otherwise
; things get a little more complex.
;
; NOTE - eax currently contains the high order word of DVSR
;

        or      eax,eax         ; check to see if divisor < 4194304K
        jnz     short L3        ; nope, gotta do this the hard way
        mov     ecx,dDVSRLO     ; load divisor
        mov     eax,dDVNDHI     ; load high word of dividend
        xor     edx,edx
        div     ecx             ; eax <- high order bits of quotient
        mov     ebx,eax         ; save high bits of quotient
        mov     eax,dDVNDLO     ; edx:eax <- remainder:lo word of dividend
        div     ecx             ; eax <- low order bits of quotient
        mov     edx,ebx         ; edx:eax <- quotient
        jmp     short L4        ; set sign, restore stack and return

;
; Here we do it the hard way.  Remember, eax contains the high word of DVSR
;

L3:
        mov     ebx,eax         ; ebx:ecx <- divisor
        mov     ecx,dDVSRLO
        mov     edx,dDVNDHI     ; edx:eax <- dividend
        mov     eax,dDVNDLO
L5:
        shr     ebx,1           ; shift divisor right one bit
        rcr     ecx,1
        shr     edx,1           ; shift dividend right one bit
        rcr     eax,1
        or      ebx,ebx
        jnz     short L5        ; loop until divisor < 4194304K
        div     ecx             ; now divide, ignore remainder
        mov     esi,eax         ; save quotient

;
; We may be off by one, so to check, we will multiply the quotient
; by the divisor and check the result against the orignal dividend
; Note that we must also check for overflow, which can occur if the
; dividend is close to 2**64 and the quotient is off by 1.
;

        mul     dword ptr dDVSRHI ; QUOT * DVSRHI
        mov     ecx,eax
        mov     eax,dDVSRLO
        mul     esi             ; QUOT * DVSRLO
        add     edx,ecx         ; EDX:EAX = QUOT * DVSR
        jc      short L6        ; carry means Quotient is off by 1

;
; do long compare here between original dividend and the result of the
; multiply in edx:eax.  If original is larger or equal, we are ok, otherwise
; subtract one (1) from the quotient.
;

        cmp     edx,dDVNDHI      ; compare hi words of result and original
        ja      short L6        ; if result > original, do subtract
        jb      short L7        ; if result < original, we are ok
        cmp     eax,dDVNDLO      ; hi words are equal, compare lo words
        jbe     short L7        ; if less or equal we are ok, else subtract
L6:
        dec     esi             ; subtract 1 from quotient
L7:
        xor     edx,edx         ; edx:eax <- quotient
        mov     eax,esi

;
; Just the cleanup left to do.  edx:eax contains the quotient.  Set the sign
; according to the save value, cleanup the stack, and return.
;

L4:
        dec     edi             ; check to see if result is negative
        jnz     short L8        ; if EDI == 0, result should be negative
        neg     edx             ; otherwise, negate the result
        neg     eax
        sbb     edx,0

;
; Restore the saved registers and return.
;

L8:
        pop     ebx
        pop     esi
        pop     edi

        ret     16
    }
}

/* Copyright (c) Microsoft Corporation. All rights reserved. */
/*
; allrem - signed long remainder
;
; Purpose:
;       Does a signed long remainder of the arguments.  Arguments are
;       not changed.
;
; Entry:
;       Arguments are passed on the stack:
;               1st pushed: divisor (QWORD)
;               2nd pushed: dividend (QWORD)
;
; Exit:
;       EDX:EAX contains the remainder (dividend%divisor)
;       NOTE: this routine removes the parameters from the stack.
;
; Uses:
;       ECX
;
; Exceptions:
;
*/
__declspec(naked) void __cdecl x_allrem()
{
    __asm {
        push    ebx
        push    edi

; Set up the local stack and save the index registers.  When this is done
; the stack frame will look as follows (assuming that the expression a%b will
; generate a call to lrem(a, b)):
;
;               -----------------
;               |               |
;               |---------------|
;               |               |
;               |--divisor (b)--|
;               |               |
;               |---------------|
;               |               |
;               |--dividend (a)-|
;               |               |
;               |---------------|
;               | return addr** |
;               |---------------|
;               |       EBX     |
;               |---------------|
;       ESP---->|       EDI     |
;               -----------------
;

#define rDVNDLO [esp + 12]      /* stack address of dividend (a) loword */
#define rDVNDHI [esp + 16]      /* stack address of dividend (a) hiword */
#define rDVSRLO [esp + 20]      /* stack address of divisor (b) loword */
#define rDVSRHI [esp + 24]      /* stack address of divisor (b) hiword */


; Determine sign of the result (edi = 0 if result is positive, non-zero
; otherwise) and make operands positive.

        xor     edi,edi         ; result sign assumed positive

        mov     eax,rDVNDHI     ; hi word of a
        or      eax,eax         ; test to see if signed
        jge     short L1        ; skip rest if a is already positive
        inc     edi             ; complement result sign flag bit
        mov     edx,rDVNDLO     ; lo word of a
        neg     eax             ; make a positive
        neg     edx
        sbb     eax,0
        mov     rDVNDHI,eax     ; save positive value
        mov     rDVNDLO,edx
L1:
        mov     eax,rDVSRHI     ; hi word of b
        or      eax,eax         ; test to see if signed
        jge     short L2        ; skip rest if b is already positive
        mov     edx,rDVSRLO     ; lo word of b
        neg     eax             ; make b positive
        neg     edx
        sbb     eax,0
        mov     rDVSRHI,eax     ; save positive value
        mov     rDVSRLO,edx
L2:

;
; Now do the divide.  First look to see if the divisor is less than 4194304K.
; If so, then we can use a simple algorithm with word divides, otherwise
; things get a little more complex.
;
; NOTE - eax currently contains the high order word of DVSR
;

        or      eax,eax         ; check to see if divisor < 4194304K
        jnz     short L3        ; nope, gotta do this the hard way
        mov     ecx,rDVSRLO     ; load divisor
        mov     eax,rDVNDHI     ; load high word of dividend
        xor     edx,edx
        div     ecx             ; edx <- remainder
        mov     eax,rDVNDLO     ; edx:eax <- remainder:lo word of dividend
        div     ecx             ; edx <- final remainder
        mov     eax,edx         ; edx:eax <- remainder
        xor     edx,edx
        dec     edi             ; check result sign flag
        jns     short L4        ; negate result, restore stack and return
        jmp     short L8        ; result sign ok, restore stack and return

;
; Here we do it the hard way.  Remember, eax contains the high word of DVSR
;

L3:
        mov     ebx,eax         ; ebx:ecx <- divisor
        mov     ecx,rDVSRLO
        mov     edx,rDVNDHI     ; edx:eax <- dividend
        mov     eax,rDVNDLO
L5:
        shr     ebx,1           ; shift divisor right one bit
        rcr     ecx,1
        shr     edx,1           ; shift dividend right one bit
        rcr     eax,1
        or      ebx,ebx
        jnz     short L5        ; loop until divisor < 4194304K
        div     ecx             ; now divide, ignore remainder

;
; We may be off by one, so to check, we will multiply the quotient
; by the divisor and check the result against the orignal dividend
; Note that we must also check for overflow, which can occur if the
; dividend is close to 2**64 and the quotient is off by 1.
;

        mov     ecx,eax         ; save a copy of quotient in ECX
        mul     dword ptr rDVSRHI
        xchg    ecx,eax         ; save product, get quotient in EAX
        mul     dword ptr rDVSRLO
        add     edx,ecx         ; EDX:EAX = QUOT * DVSR
        jc      short L6        ; carry means Quotient is off by 1

;
; do long compare here between original dividend and the result of the
; multiply in edx:eax.  If original is larger or equal, we are ok, otherwise
; subtract the original divisor from the result.
;

        cmp     edx,rDVNDHI     ; compare hi words of result and original
        ja      short L6        ; if result > original, do subtract
        jb      short L7        ; if result < original, we are ok
        cmp     eax,rDVNDLO     ; hi words are equal, compare lo words
        jbe     short L7        ; if less or equal we are ok, else subtract
L6:
        sub     eax,rDVSRLO     ; subtract divisor from result
        sbb     edx,rDVSRHI
L7:

;
; Calculate remainder by subtracting the result from the original dividend.
; Since the result is already in a register, we will do the subtract in the
; opposite direction and negate the result if necessary.
;

        sub     eax,rDVNDLO     ; subtract dividend from result
        sbb     edx,rDVNDHI

;
; Now check the result sign flag to see if the result is supposed to be positive
; or negative.  It is currently negated (because we subtracted in the 'wrong'
; direction), so if the sign flag is set we are done, otherwise we must negate
; the result to make it positive again.
;

        dec     edi             ; check result sign flag
        jns     short L8        ; result is ok, restore stack and return
L4:
        neg     edx             ; otherwise, negate the result
        neg     eax
        sbb     edx,0

;
; Just the cleanup left to do.  edx:eax contains the quotient.
; Restore the saved registers and return.
;

L8:
        pop     edi
        pop     ebx

        ret     16
    }
}

/* Copyright (c) Microsoft Corporation. All rights reserved. */
/*
;ulldiv - unsigned long divide
;
; Purpose:
;       Does a unsigned long divide of the arguments.  Arguments are
;       not changed.
;
; Entry:
;       Arguments are passed on the stack:
;               1st pushed: divisor (QWORD)
;               2nd pushed: dividend (QWORD)
;
; Exit:
;       EDX:EAX contains the quotient (dividend/divisor)
;       NOTE: this routine removes the parameters from the stack.
;
; Uses:
;       ECX
;
; Exceptions:
;
*/
__declspec(naked) void __cdecl x_aulldiv()
{
    __asm {
        push    ebx
        push    esi

; Set up the local stack and save the index registers.  When this is done
; the stack frame will look as follows (assuming that the expression a/b will
; generate a call to uldiv(a, b)):
;
;               -----------------
;               |               |
;               |---------------|
;               |               |
;               |--divisor (b)--|
;               |               |
;               |---------------|
;               |               |
;               |--dividend (a)-|
;               |               |
;               |---------------|
;               | return addr** |
;               |---------------|
;               |      EBX      |
;               |---------------|
;       ESP---->|      ESI      |
;               -----------------
;

#define uDVNDLO [esp + 12]      /* stack address of dividend (a) loword */
#define uDVNDHI [esp + 16]      /* stack address of dividend (a) hiword */
#define uDVSRLO [esp + 20]      /* stack address of divisor (b) loword */
#define uDVSRHI [esp + 24]      /* stack address of divisor (b) hiword */

;
; Now do the divide.  First look to see if the divisor is less than 4194304K.
; If so, then we can use a simple algorithm with word divides, otherwise
; things get a little more complex.
;

        mov     eax,uDVSRHI     ; check to see if divisor < 4194304K
        or      eax,eax
        jnz     short L1        ; nope, gotta do this the hard way
        mov     ecx,uDVSRLO     ; load divisor
        mov     eax,uDVNDHI     ; load high word of dividend
        xor     edx,edx
        div     ecx             ; get high order bits of quotient
        mov     ebx,eax         ; save high bits of quotient
        mov     eax,uDVNDLO     ; edx:eax <- remainder:lo word of dividend
        div     ecx             ; get low order bits of quotient
        mov     edx,ebx         ; edx:eax <- quotient hi:quotient lo
        jmp     short L2        ; restore stack and return

;
; Here we do it the hard way.  Remember, eax contains DVSRHI
;

L1:
        mov     ecx,eax         ; ecx:ebx <- divisor
        mov     ebx,uDVSRLO
        mov     edx,uDVNDHI     ; edx:eax <- dividend
        mov     eax,uDVNDLO
L3:
        shr     ecx,1           ; shift divisor right one bit; hi bit <- 0
        rcr     ebx,1
        shr     edx,1           ; shift dividend right one bit; hi bit <- 0
        rcr     eax,1
        or      ecx,ecx
        jnz     short L3        ; loop until divisor < 4194304K
        div     ebx             ; now divide, ignore remainder
        mov     esi,eax         ; save quotient

;
; We may be off by one, so to check, we will multiply the quotient
; by the divisor and check the result against the orignal dividend
; Note that we must also check for overflow, which can occur if the
; dividend is close to 2**64 and the quotient is off by 1.
;

        mul     dword ptr uDVSRHI ; QUOT * DVSRHI
        mov     ecx,eax
        mov     eax,uDVSRLO
        mul     esi             ; QUOT * DVSRLO
        add     edx,ecx         ; EDX:EAX = QUOT * DVSR
        jc      short L4        ; carry means Quotient is off by 1

;
; do long compare here between original dividend and the result of the
; multiply in edx:eax.  If original is larger or equal, we are ok, otherwise
; subtract one (1) from the quotient.
;

        cmp     edx,uDVNDHI     ; compare hi words of result and original
        ja      short L4        ; if result > original, do subtract
        jb      short L5        ; if result < original, we are ok
        cmp     eax,uDVNDLO     ; hi words are equal, compare lo words
        jbe     short L5        ; if less or equal we are ok, else subtract
L4:
        dec     esi             ; subtract 1 from quotient
L5:
        xor     edx,edx         ; edx:eax <- quotient
        mov     eax,esi

;
; Just the cleanup left to do.  edx:eax contains the quotient.
; Restore the saved registers and return.
;

L2:
        pop     esi
        pop     ebx

        ret     16
    }
}

/* Copyright (c) Microsoft Corporation. All rights reserved. */
/*
; ullrem - unsigned long remainder
;
; Purpose:
;       Does a unsigned long remainder of the arguments.  Arguments are
;       not changed.
;
; Entry:
;       Arguments are passed on the stack:
;               1st pushed: divisor (QWORD)
;               2nd pushed: dividend (QWORD)
;
; Exit:
;       EDX:EAX contains the remainder (dividend%divisor)
;       NOTE: this routine removes the parameters from the stack.
;
; Uses:
;       ECX
;
; Exceptions:
;
*/
__declspec(naked) void __cdecl x_aullrem()
{
    __asm {
        push    ebx

; Set up the local stack and save the index registers.  When this is done
; the stack frame will look as follows (assuming that the expression a%b will
; generate a call to ullrem(a, b)):
;
;               -----------------
;               |               |
;               |---------------|
;               |               |
;               |--divisor (b)--|
;               |               |
;               |---------------|
;               |               |
;               |--dividend (a)-|
;               |               |
;               |---------------|
;               | return addr** |
;               |---------------|
;       ESP---->|      EBX      |
;               -----------------
;

#define qDVNDLO [esp + 8]       /* stack address of dividend (a) loword */
#define qDVNDHI [esp + 12]      /* stack address of dividend (a) hiword */
#define qDVSRLO [esp + 16]      /* stack address of divisor (b) loword */
#define qDVSRHI [esp + 20]      /* stack address of divisor (b) hiword */

; Now do the divide.  First look to see if the divisor is less than 4194304K.
; If so, then we can use a simple algorithm with word divides, otherwise
; things get a little more complex.
;

        mov     eax,qDVSRHI      ; check to see if divisor < 4194304K
        or      eax,eax
        jnz     short L1        ; nope, gotta do this the hard way
        mov     ecx,qDVSRLO     ; load divisor
        mov     eax,qDVNDHI     ; load high word of dividend
        xor     edx,edx
        div     ecx             ; edx <- remainder, eax <- quotient
        mov     eax,qDVNDLO      ; edx:eax <- remainder:lo word of dividend
        div     ecx             ; edx <- final remainder
        mov     eax,edx         ; edx:eax <- remainder
        xor     edx,edx
        jmp     short L2        ; restore stack and return

;
; Here we do it the hard way.  Remember, eax contains DVSRHI
;

L1:
        mov     ecx,eax         ; ecx:ebx <- divisor
        mov     ebx,qDVSRLO
        mov     edx,qDVNDHI     ; edx:eax <- dividend
        mov     eax,qDVNDLO
L3:
        shr     ecx,1           ; shift divisor right one bit; hi bit <- 0
        rcr     ebx,1
        shr     edx,1           ; shift dividend right one bit; hi bit <- 0
        rcr     eax,1
        or      ecx,ecx
        jnz     short L3        ; loop until divisor < 4194304K
        div     ebx             ; now divide, ignore remainder

;
; We may be off by one, so to check, we will multiply the quotient
; by the divisor and check the result against the orignal dividend
; Note that we must also check for overflow, which can occur if the
; dividend is close to 2**64 and the quotient is off by 1.
;

        mov     ecx,eax         ; save a copy of quotient in ECX
        mul     dword ptr qDVSRHI
        xchg    ecx,eax         ; put partial product in ECX, get quotient in EAX
        mul     dword ptr qDVSRLO
        add     edx,ecx         ; EDX:EAX = QUOT * DVSR
        jc      short L4        ; carry means Quotient is off by 1

/*
; do long compare here between original dividend and the result of the
; multiply in edx:eax.  If original is larger or equal, we're ok, otherwise
; subtract the original divisor from the result.
*/

        cmp     edx,qDVNDHI     ; compare hi words of result and original
        ja      short L4        ; if result > original, do subtract
        jb      short L5        /* if result < original, we're ok */
        cmp     eax,qDVNDLO     ; hi words are equal, compare lo words
        jbe     short L5        /* if less or equal we're ok, else subtract */
L4:
        sub     eax,qDVSRLO     ; subtract divisor from result
        sbb     edx,qDVSRHI
L5:

;
; Calculate remainder by subtracting the result from the original dividend.
; Since the result is already in a register, we will perform the subtract in
; the opposite direction and negate the result to make it positive.
;

        sub     eax,qDVNDLO     ; subtract original dividend from result
        sbb     edx,qDVNDHI
        neg     edx             ; and negate it
        neg     eax
        sbb     edx,0

;
; Just the cleanup left to do.  dx:ax contains the remainder.
; Restore the saved registers and return.
;

L2:
        pop     ebx

        ret     16
    }
}


__declspec(naked) void __cdecl x_allshl()
{
    __asm
    {
        cmp     cl, 40h
        jnb     short allshl_noshift
        cmp     cl, 20h
        jnb     short allshl_longshift
        shld    edx, eax, cl
        shl     eax, cl
        retn
allshl_longshift:
        mov     edx, eax
        xor     eax, eax
        and     cl, 1Fh
        shl     edx, cl
        retn
allshl_noshift:
        xor     eax, eax
        xor     edx, edx
        retn
    }
}

__declspec(naked) void __cdecl x_aullshr()
{
    __asm
    {
        cmp     cl, 40h
        jnb     short aullshr_noshift
        cmp     cl, 20h
        jnb     short aullshr_longshift
        shrd    eax, edx, cl
        shr     edx, cl
        retn
aullshr_longshift:
        mov     eax, edx
        xor     edx, edx
        and     cl, 1Fh
        shr     eax, cl
        retn
aullshr_noshift:
        xor     eax, eax
        xor     edx, edx
        retn
    }
}
