// assertions

# pragma once
# ifndef _M2ASSERT_H_
# define _M2ASSERT_H_

// prototypes to Win32 API
#define PROTOTYPE_IMPORT_C extern "C" __declspec(dllimport)
#define PROTOTYPE_IMPORT_W __declspec(dllimport)
PROTOTYPE_IMPORT_C void*         __stdcall GetCurrentProcess();
PROTOTYPE_IMPORT_C int           __stdcall TerminateProcess( void* hProcess, unsigned int uExitCode );
PROTOTYPE_IMPORT_C void          __stdcall DebugBreak();
PROTOTYPE_IMPORT_C unsigned long __stdcall GetModuleFileNameW( void* hModule, WCHAR* lpFilename, unsigned long nSize );
PROTOTYPE_IMPORT_C unsigned long __stdcall GetFullPathNameW( const WCHAR* lpFileName, unsigned long nBufferLength, WCHAR* lpBuffer, WCHAR** lpFilePart );
PROTOTYPE_IMPORT_C int           __stdcall MessageBoxW( void* hWnd, const WCHAR* lpText, const WCHAR* lpCaption, unsigned int uType );
PROTOTYPE_IMPORT_C WCHAR*        __stdcall lstrcatW( WCHAR* lpString1, const WCHAR* lpString2 );

#define PROTOTYPE_MB_ABORTRETRYIGNORE     0x00000002L
#define PROTOTYPE_MB_ICONHAND             0x00000010L
#define PROTOTYPE_MB_TASKMODAL            0x00002000L
#define PROTOTYPE_MB_SETFOREGROUND        0x00010000L
#define PROTOTYPE_MB_SERVICE_NOTIFICATION 0x00040000L

#define PROTOTYPE_IDABORT  3
#define PROTOTYPE_IDRETRY  4
#define PROTOTYPE_IDIGNORE 5

inline void M2AssertW( BOOLEAN expression, const WCHAR* file, const WCHAR* line )
{
    if( expression ) {
        return;
    }

    WCHAR szExeName[260] = L"\0";
    WCHAR szUnknownExeName[] = L"<program name unknown>";
    if( !GetModuleFileNameW( 0, szExeName, 260 )) {
        ASSIGNW_( 259, szExeName, sizeof( szUnknownExeName )-1, szUnknownExeName );
    }

    WCHAR szPath[260] = L"\0";
    WCHAR* szShortFile;
    GetFullPathNameW( file, 260, szPath, &szShortFile );

    WCHAR text[1024] = L"\0";
    lstrcatW( text, L"Debug assertion failed!\n\nProgram: " );
    lstrcatW( text, szExeName );
    lstrcatW( text, L"\nFile: " );
    lstrcatW( text, szShortFile );
    lstrcatW( text, L"\nLine: " );
    lstrcatW( text, line );
    lstrcatW( text, L"\n\n(Press \"Retry\" to debug the application.)" );

    int result = MessageBoxW( 0, text, L"Unexpected state of program execution", PROTOTYPE_MB_TASKMODAL | PROTOTYPE_MB_ICONHAND | PROTOTYPE_MB_ABORTRETRYIGNORE | PROTOTYPE_MB_SETFOREGROUND | PROTOTYPE_MB_SERVICE_NOTIFICATION );
    if( result == PROTOTYPE_IDABORT ) { // kill process
        TerminateProcess( GetCurrentProcess(), 3 ); // standard exit code for SIGABRT
    } else if( result == PROTOTYPE_IDRETRY ) { // allow to debug process
        DebugBreak();
    } else if( result == PROTOTYPE_IDIGNORE ) { // continue code

    }
}

inline void M2AssertLogW( bool expression, const WCHAR* file, const WCHAR* line )
{
    M2AssertW( expression, file, line );
    // TODO, use Log module
}

# endif // ifndef _M2ASSERT_H_
