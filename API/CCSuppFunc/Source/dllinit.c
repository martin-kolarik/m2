/* entry points/dll initialization */

#pragma once

#include "initterm.h"

/* copy from windows.h */
#define DLL_PROCESS_DETACH 0
#define DLL_PROCESS_ATTACH 1

/* DefaultDllMain replaces DllMain if it does not exists */
#ifdef _WIN64
    #pragma comment(linker, "/alternatename:DllMain=_DefaultDllMain")
#else
    #pragma comment(linker, "/alternatename:_DllMain=__DefaultDllMain")
#endif

extern unsigned char __cdecl DllMain( unsigned long reason );

unsigned char __cdecl _DefaultDllMain( unsigned long reason )
{
    reason;
    return 1;
}

int __stdcall _DllMainCRTStartup( void* hInst, unsigned long reason, void* imp )
{
    int ret;
    hInst;
    imp;

	if( reason == DLL_PROCESS_ATTACH )
	{
        __initcrtl();
	}

	ret = (int)DllMain( reason );

	if( reason == DLL_PROCESS_DETACH )
	{
        __donecrtl();
	}

	return ret;
}