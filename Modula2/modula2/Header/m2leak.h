// Memory Leak m2cpp stub

# pragma once
# ifndef _M2LEAK_H_
# define _M2LEAK_H_

#include "m2cpp.h"

// # pragma comment(lib, "leakdetector.lib")
// # pragma comment(linker, "/include:_Mark")

// prototype for LeakDetector
extern "C" __DLL_IMPORT void __cdecl SwitchOn();
extern "C" __DLL_IMPORT void __cdecl SwitchOff();
extern "C" __DLL_IMPORT void __cdecl Reset();

extern "C" __DLL_IMPORT void __cdecl Mark( BOOLEAN Enter, INTEGER Source_HIGH, const WCHAR* Source, CARDINAL Line );

extern "C" __DLL_IMPORT void __cdecl AllocateHook( const ADDRESS A, const CARDINAL S );
extern "C" __DLL_IMPORT void __cdecl DeallocateHook( const ADDRESS A );
extern "C" __DLL_IMPORT void __cdecl ReallocateHook( const ADDRESS O, const ADDRESS N, const CARDINAL S );

// m2cpp emitted macro
# define LEAKSTART_()                       SwitchOn()
# define LEAKSTOP_()                        SwitchOff()
# define LEAKRESET_()                       SwitchOn()

# define LEAKINFOPUSH_(High, Source, Line)  Mark( TRUE, High, Source, Line )
# define LEAKINFOPOP_()                     Mark( FALSE, 0, NIL, 0 )

# define LEAKALLOCATE_( N, S )              AllocateHook( N, S )
# define LEAKDEALLOCATE_( O )               DeallocateHook( O )
# define LEAKREALLOCATE_( O, N, S )         ReallocateHook( O, N, S )

# endif // ifndef _M2LEAK_H_
