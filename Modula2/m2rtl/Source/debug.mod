IMPLEMENTATION MODULE Debug;

FROM Debug IMPORT
   Assertion;

FROM Storage IMPORT
   ALLOCATE, DEALLOCATE;

IMPORT
   windows, // must be imported before dbghelp
   excpt,
   dbghelp,
   FIO,
   Folders,
   Log,
   Strings,
   time;

//--------------------------------------------------------------------------------

PROCEDURE Assert( CONST Module : ARRAY OF WCHAR; ModuleLine, CPPLine : CARDINAL ) : BOOLEAN; // returns if debug break is required
CONST
   CRLF = 13W + 10W;
VAR
   exeName : FIO.PathStrW := L"";
   n : ARRAY [0..31] OF WCHAR;
   result : CARDINAL;
   text : ARRAY [0..1023] OF WCHAR;
BEGIN
   IF windows.GetModuleFileNameW( NIL, ADR( exeName ), HIGH( exeName ) + 1 ) = 0 THEN
      exeName := L"<unknown program>";   
   END;
   text := L"Debug assertion failed!" + CRLF + CRLF + L"Program: ";
   Strings.AppendW( REF text, exeName );
   Strings.AppendW( REF text, CRLF + L"File: " );
   Strings.AppendW( REF text, Module );
   Strings.AppendW( REF text, CRLF + L"Line: " );
   Strings.FromCARD32W( ModuleLine, 10, OUT n ); Strings.AppendW( REF text, n ); Strings.AppendW( REF text, L", " );
   Strings.FromCARD32W( CPPLine, 10, OUT n ); Strings.AppendW( REF text, n );
   Strings.AppendW( REF text, CRLF + CRLF + '(Press "Retry" to debug the application.)' );

   result := windows.MessageBoxW( NIL, ADR( text ), L"Unexpected state of program execution", windows.MB_TASKMODAL OR windows.MB_ICONHAND OR windows.MB_ABORTRETRYIGNORE OR windows.MB_SETFOREGROUND ); // MB_SERVICE_NOTIFICATION cannot be used as Vista does not open anything in the case. For XP if service is interactive, it opens dialog correctly.
   IF result = windows.IDABORT THEN // kill process
      windows.TerminateProcess( windows.GetCurrentProcess(), 3 ); // standard exit code for SIGABRT
   ELSIF result = windows.IDRETRY THEN // allow to debug process
      RETURN TRUE;
   END;
   RETURN FALSE;
END Assert;

//--------------------------------------------------------------------------------

CONST
   REGISTRY_LIBRARY = L"Assertions";
   ASSERTIONS_FILE = L"Assertions.log";

VAR
   AssertionLog : Log.TPLogger := NIL;

//--------------------------------------------------------------------------------

PROCEDURE CreateLogger() : Log.TPLogger;
VAR
   file : FIO.PathStrW;
   path : FIO.PathStrW;
   success : BOOLEAN := FALSE;
BEGIN
   NEW( AssertionLog );
   AssertionLog^.Output := Log.outsNone;
   
   // read data from registry
   IF Log.ConfigureByRegistry( REF AssertionLog^, REGISTRY_LIBRARY ) THEN
      IF Log.outFile IN AssertionLog^.Output THEN
         success := TRUE;
      END;
   ELSE
      AssertionLog^.Output := Log.outsFile;
      AssertionLog^.Level := Log.lcSysError;
      AssertionLog^.Levels := FALSE;
      AssertionLog^.SetName( ProductId );
   END;

   // try common application data path, should always succeed
   IF NOT success AND Folders.GetManufacturerSpecialFolderW( Folders.sfAppDataCommon, TRUE, OUT path ) THEN
      FIO.MakePathW( path, ASSERTIONS_FILE, OUT file );
      AssertionLog^.SetLogFile( file );
      success := TRUE;
   END;
   
   // try user application data path
   IF NOT success AND Folders.GetManufacturerSpecialFolderW( Folders.sfAppDataUser, TRUE, OUT path ) THEN
      FIO.MakePathW( path, ASSERTIONS_FILE, OUT file );
      AssertionLog^.SetLogFile( file );
      success := TRUE;
   END;

   RETURN AssertionLog;
END CreateLogger;

//--------------------------------------------------------------------------------

PROCEDURE getLogger() : Log.TPLogger;
BEGIN
   IF AssertionLog = NIL THEN
      AssertionLog := CreateLogger();
   END;
   RETURN AssertionLog;
END getLogger;

//--------------------------------------------------------------------------------

PROCEDURE LogAssertA( CONST Text, Module : ARRAY OF CHAR; ModuleLine : CARDINAL );
VAR
   ModuleW : ARRAY [0..63] OF WCHAR;
   TextW : ARRAY [0..255] OF WCHAR;
BEGIN
   Strings.ToW( Text, 0, OUT TextW );
   Strings.ToW( Module, 0, OUT ModuleW );
   LogAssertionW( TextW, ModuleW, ModuleLine );
END LogAssertA;

//--------------------------------------------------------------------------------

PROCEDURE DumpToFile( file : FIO.File; exceptionPointers : windows.PEXCEPTION_POINTERS );
VAR
   mdei : dbghelp.MINIDUMP_EXCEPTION_INFORMATION;
BEGIN
   mdei.ThreadId := windows.GetCurrentThreadId(); 
   mdei.ExceptionPointers := exceptionPointers; 
   mdei.ClientPointers := windows.False; 
   
   dbghelp.MiniDumpWriteDump(
      windows.GetCurrentProcess(), windows.GetCurrentProcessId(), file,
      dbghelp.MINIDUMP_TYPE( dbghelp.MiniDumpWithIndirectlyReferencedMemory OR dbghelp.MiniDumpScanMemory ),
      ADR( mdei ), NIL, NIL );
END DumpToFile; 

//--------------------------------------------------------------------------------

PROCEDURE GetDumpNameAndPath( CONST prefix : ARRAY OF WCHAR; OUT name, path : ARRAY OF WCHAR );
VAR
   Path, Head, Tail : FIO.PathStrW;
BEGIN
   // create logger
   getLogger();

   // prepare minidump path
   AssertionLog^.GetLogFile( OUT Path );
   FIO.SplitPathW( Path, OUT Head, OUT Tail );
   time.NowUTC().ToStringOA( L"yyyyMMddTHHmmssfff'.mdmp'", TRUE, TRUE, OUT Tail );
   Strings.PrependW( REF Tail, prefix );
   FIO.MakePathW( Head, Tail, OUT Path );
   
   ASSIGN( name, Tail );
   ASSIGN( path, Path );
END GetDumpNameAndPath;

//--------------------------------------------------------------------------------

PROCEDURE Dump( path : ARRAY OF WCHAR; exceptionPointers : ADDRESS ) : BOOLEAN;
VAR
   file : FIO.File;
   Name : ARRAY [0..3] OF WCHAR;
   Path : FIO.PathStrW;
BEGIN
   IF path[0] = 0W THEN
      GetDumpNameAndPath( L"ud", OUT Name, OUT Path );
      file := FIO.CreateW( Path, FIO.TFileShare{ FIO.fsRead } );
   ELSE
      file := FIO.CreateW( path, FIO.TFileShare{ FIO.fsRead } );
   END;
   IF file = NIL THEN
      RETURN FALSE;
   END;

   DumpToFile( file, exceptionPointers );

   FIO.Flush( file );
   FIO.Close( file );
   RETURN TRUE;  
END Dump;

//--------------------------------------------------------------------------------

#save, call( convention => stdcall )
PROCEDURE UnhandledExceptionFilter( ExceptionInfo : windows.PEXCEPTION_POINTERS ) : windows.LONG;
CONST
   CRLF = 13W + 10W;
VAR
   exeName : FIO.PathStrW := L"";
   n : ARRAY [0..31] OF WCHAR;
   Name, Path : FIO.PathStrW;
   text : ARRAY [0..1023] OF WCHAR;
BEGIN
   // prepare minidump path
   GetDumpNameAndPath( L"ue", OUT Name, OUT Path );
   Dump( Path, ExceptionInfo );

   IF windows.GetModuleFileNameW( NIL, ADR( exeName ), HIGH( exeName ) + 1 ) = 0 THEN
      exeName := L"<unknown program>";   
   END;
   text := L"Fatal exception occurred!" + CRLF + CRLF + L"Program: ";
   Strings.AppendW( REF text, exeName );
   Strings.AppendW( REF text, CRLF + L"Code: " );
   Strings.FromCARD32W( ExceptionInfo^.ExceptionRecord^.ExceptionCode, 16, OUT n ); Strings.AppendW( REF text, n ); Strings.AppendW( REF text, L"H" );
   Strings.AppendW( REF text, CRLF + L"Address: " );
   Strings.FromCARD64W( CARD64( ExceptionInfo^.ExceptionRecord^.ExceptionAddress ), 16, OUT n ); Strings.AppendW( REF text, n );  Strings.AppendW( REF text, L"H" );
   Strings.AppendW( REF text, CRLF + CRLF + 'Crash dump was written to file: ' ); Strings.AppendW( REF text, Path );

   windows.MessageBoxW( NIL, ADR( text ), L"Unrecoverable failure of program execution", windows.MB_TASKMODAL OR windows.MB_ICONHAND OR windows.MB_OK OR windows.MB_SETFOREGROUND ); // MB_SERVICE_NOTIFICATION cannot be used as Vista does not open anything in the case. For XP if service is interactive, it opens dialog correctly.
   windows.TerminateProcess( windows.GetCurrentProcess(), 3 ); // standard exit code for SIGABRT

   RETURN excpt.EXCEPTION_EXECUTE_HANDLER;
END UnhandledExceptionFilter;
#restore

//--------------------------------------------------------------------------------

VAR
   PreviousExceptionFilter : windows.PTOP_LEVEL_EXCEPTION_FILTER := NIL;

PROCEDURE InstallCrashHandler();
BEGIN
   IF PreviousExceptionFilter = NIL THEN
      PreviousExceptionFilter := windows.SetUnhandledExceptionFilter( windows.PTOP_LEVEL_EXCEPTION_FILTER( UnhandledExceptionFilter ));
   ELSE
      LogAssertW( L"Trial to install second exception filter", EMITW( %dll ), EMITW( %line ));
   END;
END InstallCrashHandler;

//--------------------------------------------------------------------------------

PROCEDURE UninstallCrashHandler();
BEGIN
   IF PreviousExceptionFilter = NIL THEN
      LogAssertW( L"Trial to uninstall second exception filter", EMITW( %dll ), EMITW( %line ));
   ELSE
      windows.SetUnhandledExceptionFilter( PreviousExceptionFilter );
      PreviousExceptionFilter := NIL;
   END;
END UninstallCrashHandler;

//--------------------------------------------------------------------------------

PROCEDURE DumpingHandler( path : ARRAY OF WCHAR; exceptionPointers : windows.PEXCEPTION_POINTERS ) : TRISTATE;
BEGIN
   Dump( path, exceptionPointers );
   RETURN excpt.EXCEPTION_EXECUTE_HANDLER;
END DumpingHandler;

//--------------------------------------------------------------------------------

PROCEDURE LogAssertW( CONST Text, Module : ARRAY OF WCHAR; ModuleLine : CARDINAL );
VAR
   Line : ARRAY [0..15] OF WCHAR;
   Name, Path : FIO.PathStrW;
BEGIN
   // prepare minidump path
   GetDumpNameAndPath( L"as", OUT Name, OUT Path );

   Strings.FromCARD32W( ModuleLine, 10, OUT Line );
   Strings.AppendW( REF Name, L")" );
   IF Text[0] = 0W THEN
      getLogger()^.LogSSS( Log.lcSysError, 0, Module, Line, L"(dump:", Name );
   ELSE
      getLogger()^.LogSSSS( Log.lcSysError, 0, Module, Text, Line, L"(dump:", Name );
   END;
   
   // write minidump
   TRY
      ADDRESS( 0 )^ := 0; // do an exception, minidump cannot dump stack of calling thread properly, the possibility is to create an execption and store the context to exception information
   EXCEPT DumpingHandler( Path, excpt.GetExceptionInformation()) DO
      // intentionally do nothing
   END;
END LogAssertW;

//--------------------------------------------------------------------------------

BEGIN FINALLY
   IF AssertionLog <> NIL THEN
      DISPOSE( AssertionLog );
   END;
END Debug.
