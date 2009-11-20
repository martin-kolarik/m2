/* destructor/deinitializer chaining */
/* functions prefixed with "x" are not used, as they are linked from ntdll.lib */

#pragma once

#include "cdtor.h"
#include "initterm.h"

#define ATEXIT_LIMIT 64 /* maximal number of atexit registered functions */

static __crtl_cdtor_vv_proc __atexit_list[ATEXIT_LIMIT];
static unsigned int __atexit_occupied = 0;

int __cdecl atexit( __crtl_cdtor_vv_proc function )
{
    if( __atexit_occupied == ATEXIT_LIMIT )
    {
        return -1;
    }
    __atexit_list[__atexit_occupied++] = function;
    return 0;
}

void __fastcall __exit()
{
    if( __atexit_occupied > 0 )
    {
        __initterm( __atexit_list, __atexit_list + __atexit_occupied ); /* pointer arithmetics */
    }
}