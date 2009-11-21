/* destructor/deinitializer chaining */
/* functions prefixed with "x" are not used, as they are linked from ntdll.lib */

#pragma once

#include "cdtor.h"
#include "atexit.h"
#include "math.h"

#define __ALLOC_SECT(section) __declspec(allocate(section)) 

#pragma section( ".CRT$XIA", long, read )
#pragma section( ".CRT$XIZ", long, read )
#pragma section( ".CRT$XCA", long, read )
#pragma section( ".CRT$XCZ", long, read )
#pragma section( ".CRT$XPA", long, read )
#pragma section( ".CRT$XPZ", long, read )
#pragma section( ".CRT$XTA", long, read )
#pragma section( ".CRT$XTZ", long, read )

__ALLOC_SECT(".CRT$XIA") __crtl_cdtor_iv_proc __xi_a[] = { 0 }; /* C initializers */
__ALLOC_SECT(".CRT$XIZ") __crtl_cdtor_iv_proc __xi_z[] = { 0 }; /* C initializers */
__ALLOC_SECT(".CRT$XCA") __crtl_cdtor_vv_proc __xc_a[] = { 0 }; /* C++ initializers */
__ALLOC_SECT(".CRT$XCZ") __crtl_cdtor_vv_proc __xc_z[] = { 0 }; /* C++ initializers */
__ALLOC_SECT(".CRT$XPA") __crtl_cdtor_vv_proc __xp_a[] = { 0 }; /* C pre-terminators */
__ALLOC_SECT(".CRT$XPZ") __crtl_cdtor_vv_proc __xp_z[] = { 0 }; /* C pre-terminators */
__ALLOC_SECT(".CRT$XTA") __crtl_cdtor_vv_proc __xt_a[] = { 0 }; /* C terminators */
__ALLOC_SECT(".CRT$XTZ") __crtl_cdtor_vv_proc __xt_z[] = { 0 }; /* C terminators */

void __fastcall __initterm( __crtl_cdtor_vv_proc* pFirstFunction, __crtl_cdtor_vv_proc* pAfterLastFunction )
{
   while (pFirstFunction < pAfterLastFunction)
   {
      if (*pFirstFunction != 0)
      {
         (**pFirstFunction)();
      }
      pFirstFunction++;
   }
}

void __fastcall __initcrtl()
{
    __initmath();
    __initterm( __xi_a, __xi_z );
    __initterm( __xc_a, __xc_z );
}

void __fastcall __donecrtl()
{
    __exit();
    __initterm( __xp_a, __xp_z );
    __initterm( __xt_a, __xt_z );
}