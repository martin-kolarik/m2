IMPLEMENTATION MODULE Debug;

IMPORT
  Log,
  Strings,
  windows;

//--------------------------------------------------------------------------------

PROCEDURE Assertion( Expression : BOOLEAN; CONST Module : ARRAY OF WCHAR; ModuleLine, CPPLine : CARDINAL ) : BOOLEAN; // returns if debug break is required
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
END Assertion;

//--------------------------------------------------------------------------------

PROCEDURE LogAssertionA( CONST Text, Module : ARRAY OF CHAR; ModuleLine : CARDINAL );
BEGIN
END LogAssertionA;

//--------------------------------------------------------------------------------

PROCEDURE LogAssertionW( CONST Text, Module : ARRAY OF WCHAR; ModuleLine : CARDINAL );
BEGIN
END LogAssertionW;

//--------------------------------------------------------------------------------

END Debug.
