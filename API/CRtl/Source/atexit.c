/* destructor/deinitializer chaining */
/* functions prefixed with "x" are not used, as they are linked from ntdll.lib */

#pragma once

#include "cdtor.h"
#include "initterm.h"

#define ATEXIT_INITIAL 128
#define ATEXIT_INCREMENT 64

/* windows API */
extern void* __stdcall GetProcessHeap();
extern void* __stdcall HeapAlloc( void* heap, unsigned long flags, unsigned long size );
extern void* __stdcall HeapReAlloc( void* heap, unsigned long flags, void* pAddress, unsigned long newSize );
extern unsigned char __stdcall HeapFree( void* heap, unsigned long flags, void* address );

/* atexit itself */
static __crtl_cdtor_vv_proc* __atexit_list = 0;
static unsigned int __atexit_allocated = 0;
static unsigned int __atexit_occupied = 0;

int __cdecl atexit( __crtl_cdtor_vv_proc function )
{
    if( __atexit_allocated == 0 )
    {
        __atexit_allocated = ATEXIT_INITIAL;
        __atexit_list = HeapAlloc( GetProcessHeap(), 0, __atexit_allocated * sizeof( __crtl_cdtor_vv_proc ));
    }
    else if( __atexit_occupied == __atexit_allocated )
    {
        __atexit_allocated += ATEXIT_INCREMENT;
        __atexit_list = HeapReAlloc( GetProcessHeap(), 0, __atexit_list, __atexit_allocated * sizeof( __crtl_cdtor_vv_proc ));
    }
    __atexit_list[__atexit_occupied++] = function;
    return 0;
}

void __fastcall __exit()
{
    if( __atexit_occupied > 0 )
    {
        __initterm( __atexit_list, __atexit_list + __atexit_occupied ); /* pointer arithmetics */
        HeapFree( GetProcessHeap(), 0, __atexit_list );
    }
}