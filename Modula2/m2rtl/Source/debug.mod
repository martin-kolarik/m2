IMPLEMENTATION MODULE Debug;

FROM Storage IMPORT
   ALLOCATE, DEALLOCATE;

IMPORT
   windows, // must be imported before dbghelp
   excpt,
   datetime,
   dbghelp,
   FIO,
   Folders,
   Log,
   Strings;

//--------------------------------------------------------------------------------

TYPE
   TAssertModeItem = (
      amDump,
      amWindow,
      amLoop
   );
   TAssertMode = SET OF TAssertModeItem;

VAR
   OpenWindow : BOOLEAN := TRUE;

PROCEDURE WaitUsingDialog();
BEGIN
   OpenWindow := TRUE;
END WaitUsingDialog;

//--------------------------------------------------------------------------------

PROCEDURE WaitUsingLoop();
BEGIN
   OpenWindow := FALSE;
END WaitUsingLoop;

//--------------------------------------------------------------------------------

VAR 
   AssertHook : TAssertHook := NIL;
   AssertHookUserData : PTR := 0;

PROCEDURE SetAssertHook( hook : TAssertHook; userData : PTR );
BEGIN
   AssertHook := hook;
   AssertHookUserData := userData;
END SetAssertHook;

//--------------------------------------------------------------------------------

PROCEDURE GetAssertHook() : TAssertHook;
BEGIN
   RETURN AssertHook;
END GetAssertHook;

//--------------------------------------------------------------------------------

PROCEDURE DoAssertW( Mode : TAssertMode; CONST Module, Text : ARRAY OF WCHAR; ModuleLine, CPPLine : CARDINAL ); FORWARD;

//--------------------------------------------------------------------------------

PROCEDURE AssertA( ContinueWithRun, Condition : BOOLEAN; ModuleLine, CPPLine : CARDINAL; CONST Module, Text : ARRAY OF CHAR );
VAR
   ModuleW : ARRAY [0..63] OF WCHAR;
   TextW : ARRAY [0..255] OF WCHAR;
BEGIN
   IF Condition THEN
      RETURN;
   END;
   Strings.ToW( Text, 0, OUT TextW );
   Strings.ToW( Module, 0, OUT ModuleW );
   AssertionW( ContinueWithRun, Condition, ModuleLine, CPPLine, ModuleW, TextW );
END AssertA;

//--------------------------------------------------------------------------------

PROCEDURE AssertW( ContinueWithRun, Condition : BOOLEAN; ModuleLine, CPPLine : CARDINAL; CONST Module, Text : ARRAY OF WCHAR );
VAR
   AssertMode : TAssertMode;
BEGIN
   IF Condition THEN
      RETURN;
   ELSIF ContinueWithRun THEN
      AssertMode := TAssertMode{amDump};
   ELSIF OpenWindow THEN
      AssertMode := TAssertMode{amWindow};
   ELSE
      AssertMode := TAssertMode{amLoop};
   END;
   DoAssertW( AssertMode, Module, Text, ModuleLine, CPPLine );
END AssertW;

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
   datetime.NowUTC().ToStringOA( L"yyyyMMddTHHmmssfff'.mdmp'", TRUE, TRUE, OUT Tail );
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
   IF INSIDE( 0, path ) AND ( path[0] <> 0W ) THEN
      file := FIO.CreateW( path, FIO.TFileShare{ FIO.fsRead } );
   ELSE
      GetDumpNameAndPath( L"ud", OUT Name, OUT Path );
      file := FIO.CreateW( Path, FIO.TFileShare{ FIO.fsRead } );
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
   IF windows.IsDebuggerPresent() THEN
      windows.DebugBreak();
   END;

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
      AssertionW( TRUE, FALSE, EMITW( %line ), EMITW( %line ), L"debug.cpp", L"Trial to install second exception filter" );
   END;
END InstallCrashHandler;

//--------------------------------------------------------------------------------

PROCEDURE UninstallCrashHandler();
BEGIN
   IF PreviousExceptionFilter = NIL THEN
      AssertionW( TRUE, FALSE, EMITW( %line ), EMITW( %line ), L"debug.cpp", L"Trial to uninstall second exception filter" );
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

PROCEDURE DoAssertW( Mode : TAssertMode; CONST Module, Text : ARRAY OF WCHAR; ModuleLine, CppLine : CARDINAL );
CONST
   CRLF = 13W + 10W;
VAR
   exeName : FIO.PathStrW := L"";
   Line, LineCpp : ARRAY [0..31] OF WCHAR;
   Name, Path : FIO.PathStrW;
   result : windows.DWORD;
   text : ARRAY [0..1023] OF WCHAR;
BEGIN
   Strings.FromCARD32W( ModuleLine, 10, OUT Line );
   Strings.AppendW( REF Line, L"m/" );
   Strings.FromCARD32W( CppLine, 10, OUT LineCpp );
   Strings.AppendW( REF LineCpp, L"c" );
   Strings.AppendW( REF Line, LineCpp );

   IF amDump IN Mode THEN
      // prepare minidump path
      GetDumpNameAndPath( L"as", OUT Name, OUT Path );

      // write log entry
      Strings.AppendW( REF Name, L")" );
      IF INSIDE( 0, Text ) AND ( Text[0] <> 0W ) THEN
         getLogger()^.LogSSSS( Log.lcSysError, 0, Module, Text, Line, L"(dump:", Name );
      ELSE
         getLogger()^.LogSSS( Log.lcSysError, 0, Module, Line, L"(dump:", Name );
      END;

      // write minidump
      TRY
         ADDRESS( 0 )^ := 0; // do an exception, minidump cannot dump stack of calling thread properly, the possibility is to create an execption and store the context to exception information
      EXCEPT DumpingHandler( Path, excpt.GetExceptionInformation()) DO
         // intentionally do nothing
      END;

   ELSE // no minidump
      // write log entry
      IF INSIDE( 0, Text ) AND ( Text[0] <> 0W ) THEN
         getLogger()^.LogSS( Log.lcSysError, 0, Module, Line, Text );
      ELSE
         getLogger()^.LogS( Log.lcSysError, 0, Module, Line );
      END;
   END;

   IF ( AssertHook <> NIL ) OR ( amWindow IN Mode ) THEN // prepare text of assert
      IF windows.GetModuleFileNameW( NIL, ADR( exeName ), HIGH( exeName ) + 1 ) = 0 THEN
         exeName := L"<unknown program>";   
      END;
      text := L"Debug assertion failed!" + CRLF + CRLF + L"Program: ";
      Strings.AppendW( REF text, exeName );
      Strings.AppendW( REF text, CRLF + L"File: " );
      Strings.AppendW( REF text, Module );
      Strings.AppendW( REF text, CRLF + L"Line: " );
      Strings.AppendW( REF text, Line );
   END;
   
   IF AssertHook <> NIL THEN
      CASE AssertHook( AssertHookUserData, text ) OF
      | -1 :
         windows.DebugBreak();
      | 1 :
         windows.TerminateProcess( windows.GetCurrentProcess(), 3 ); // standard exit code for SIGABRT
      // ELSE fall down silently, ignore
      END; // CASE

   ELSIF amWindow IN Mode THEN
      // ...continue with text
      Strings.AppendW( REF text, CRLF + CRLF + '(Press "Retry" to debug the application.)' );

      result := windows.MessageBoxW( NIL, ADR( text ), L"Unexpected state of program execution", windows.MB_TASKMODAL OR windows.MB_ICONHAND OR windows.MB_ABORTRETRYIGNORE OR windows.MB_SETFOREGROUND ); // MB_SERVICE_NOTIFICATION cannot be used as Vista does not open anything in the case. For XP if service is interactive, it opens dialog correctly.
      IF result = windows.IDABORT THEN // kill process
         windows.TerminateProcess( windows.GetCurrentProcess(), 3 ); // standard exit code for SIGABRT
      ELSIF result = windows.IDRETRY THEN // allow to debug process
         windows.DebugBreak();
      END;

   ELSIF amLoop IN Mode THEN
      WHILE NOT windows.IsDebuggerPresent() DO
         windows.Sleep( 100 );
      END;
      windows.DebugBreak();

   END;
END DoAssertW;

//--------------------------------------------------------------------------------

BEGIN FINALLY
   IF AssertionLog <> NIL THEN
      DISPOSE( AssertionLog );
   END;
END Debug.
