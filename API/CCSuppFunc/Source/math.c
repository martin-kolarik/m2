/* math functions */
/* functions prefixed with "x" are not used, as they are linked from ntdll.lib */

#ifdef _M_X64

void __fastcall __initmath()
{
    /* empty for x64 */
}

#elif _M_IX86

int _sse2_available = 0;

__declspec(naked) void __fastcall _get_sse2_info()
{
    __asm
    {
        push    ebx

        /* check Pentium+ ID bit */
        pushfd
        pop     eax
        mov     ebx, eax
        xor     eax, 200000h /* toggle the bit */
        push    eax
        popfd
        pushfd
        pop     eax
        xor     eax, ebx
        jz      get_sse2_info_no_SSE2 /* no Pentium+ ID bit found */

        xor     eax, eax
        inc     eax
        cpuid
        test    edx, 4000000h
        jz      short get_sse2_info_no_SSE2
        xor     eax, eax
        inc     eax
        
get_sse2_info_exit:
        pop     ebx
        retn

get_sse2_info_no_SSE2:
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

#else

#error Unsupported platform.

#endif
