IMPLEMENTATION MODULE Debug;

FROM Debug IMPORT
   Assertion;

FROM Storage IMPORT
   ALLOCATE, DEALLOCATE;

IMPORT
   FIO,
   Log,
   shlobjlite,
   Strings,
   windows;

//--------------------------------------------------------------------------------

PROCEDURE Assert( Expression : BOOLEAN; CONST Module : ARRAY OF WCHAR; ModuleLine, CPPLine : CARDINAL ) : BOOLEAN; // returns if debug break is required
CONST
   CRLF = 13W + 10W;
VAR
   exeName : ARRAY [0..windows.MAX_PATH-1] OF WCHAR := L"";
   n : ARRAY [0..31] OF WCHAR;
   result : CARDINAL;
   text : ARRAY [0..1023] OF WCHAR;
BEGIN
   IF Expression THEN
      RETURN FALSE;
   END;

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

   result := windows.MessageBoxW( NIL, ADR( text ), L"Unexpected state of program execution", windows.MB_TASKMODAL OR windows.MB_ICONHAND OR windows.MB_ABORTRETRYIGNORE OR windows.MB_SETFOREGROUND OR windows.MB_SERVICE_NOTIFICATION );
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
   folder : FIO.PathStrW;
   path : FIO.PathStrW;
   success : BOOLEAN := FALSE;
BEGIN
   NEW( AssertionLog );
   AssertionLog^.Method := Log.dmNone;
   
   // read data from registry
   IF AssertionLog^.SetUpByRegistry( REGISTRY_LIBRARY ) THEN
      IF AssertionLog^.Method = Log.dmFile THEN
         success := TRUE;
      END;
   ELSE
      AssertionLog^.Method := Log.dmFile;
      AssertionLog^.Level := Log.dlcSysError;
      AssertionLog^.Levels := FALSE;
      AssertionLog^.SetLogName( ProductId );
   END;

   // try common application data path
   IF NOT success AND ( shlobjlite.SHGetFolderPath( NIL, shlobjlite.CSIDL_COMMON_APPDATA, NIL, shlobjlite.SHGFP_TYPE_CURRENT, ADR( folder )) = 0 ) THEN
      FIO.MakePathW( folder, Manufacturer, OUT path );
      IF FIO.CreateDirectoryW( path ) THEN
         FIO.MakePathW( path, ASSERTIONS_FILE, OUT file );
         AssertionLog^.SetLogFile( file );
         success := TRUE;
      END;
   END;
   
   // try user application data path
   IF NOT success AND ( shlobjlite.SHGetFolderPath( NIL, shlobjlite.CSIDL_APPDATA, NIL, shlobjlite.SHGFP_TYPE_CURRENT, ADR( folder )) = 0 ) THEN
      FIO.MakePathW( folder, Manufacturer, OUT path );
      IF FIO.CreateDirectoryW( path ) THEN
         FIO.MakePathW( path, ASSERTIONS_FILE, OUT file );
         AssertionLog^.SetLogFile( file );
         success := TRUE;
      END;
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

PROCEDURE LogAssertW( CONST Text, Module : ARRAY OF WCHAR; ModuleLine : CARDINAL );
VAR
   Line : ARRAY [0..15] OF WCHAR;
BEGIN
   Strings.FromCARD32W( ModuleLine, 10, OUT Line );
   IF Text[0] = 0W THEN
      getLogger()^.LogS( Log.dlcSysError, Module, Line );
   ELSE
      getLogger()^.LogSSS( Log.dlcSysError, Module, Text, L" ", Line );
   END;
END LogAssertW;

//--------------------------------------------------------------------------------

BEGIN FINALLY
   IF AssertionLog <> NIL THEN
      DISPOSE( AssertionLog );
   END;
END Debug.
