/* entry points/exe initialization */

#pragma once

#include "initterm.h"

/* from Win32 API */
extern unsigned short** __stdcall CommandLineToArgvW( unsigned short* lpCmdLine, int* pNumArgs );
extern unsigned short* __stdcall GetCommandLineW();
extern void* __stdcall LocalFree( void* hMem );
extern void __stdcall ExitProcess( unsigned int exitCode );
extern int __stdcall AttachConsole( unsigned int processId );

/* Main is a startup routine of program */
extern int __cdecl Main( int argc, unsigned short** argv ); 

int __fastcall __CRTStartup()
{
    int ret = 0;
    int argc = 0;
    unsigned short** argv = 0;

    __initcrtl();
    argv = CommandLineToArgvW( GetCommandLineW(), &argc ); /* allocates argv */
    if( argv == 0 )
    {
        argc = 0;
    }

	ret = Main( argc, argv );
    
    if( argv != 0 )
    {
        LocalFree( argv );
    }
    __donecrtl();

    ExitProcess( ret );
    return ret;
}

int __cdecl mainCRTStartup()
{
    return __CRTStartup();
}

int __cdecl WinMainCRTStartup()
{
    return __CRTStartup();
}
