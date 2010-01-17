/* destructor/deinitializer chaining */

#pragma once

int __cdecl atexit( __crtl_cdtor_vv_proc function );

void __fastcall __exit();
