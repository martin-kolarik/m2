/* destructor/deinitializer chaining */

#pragma once

#include "cdtor.h"

void __fastcall __initterm( __crtl_cdtor_vv_proc* pFirstFunction, __crtl_cdtor_vv_proc* pAfterLastFunction );

void __fastcall __initcrtl();
void __fastcall __donecrtl();