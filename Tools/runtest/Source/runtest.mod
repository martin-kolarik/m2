MODULE runtest;

FROM Storage IMPORT
  ALLOCATE, DEALLOCATE;

IMPORT
   FIO,
   iobject,
   loader,
   log,
   Strings,
   StringsO,
   Sync,
   test,
   TextReader,
   TextWriter,
   time;
   
(*================================================================================*)
   
CLASS CTestLogger( log.CLogger );
   PRIVATE VAR
      stdout : TextWriter.TPTextWriter := TextWriter.stdout();
   LOCAL VAR
      InsideTest : BOOLEAN := FALSE;
   INTERNAL VIRTUAL PROCEDURE OnLogOutputString( CONST OutputString : ARRAY OF WCHAR );
END CTestLogger;

(*--------------------------------------------------------------------------------*)

CLASS IMPLEMENTATION CTestLogger;

(*--------------------------------------------------------------------------------*)

   INTERNAL VIRTUAL PROCEDURE OnLogOutputString( CONST OutputString : ARRAY OF WCHAR );
   VAR
      i : CARDINAL;
   BEGIN
      IF InsideTest THEN
         i := Strings.IndexOfCharW( OutputString, L"]", 0 );
         stdout^.WriteOA( OA( i+4, ADR( OutputString )), FALSE ); 
         stdout^.WriteOA( L"    ", FALSE );
         stdout^.WriteOA( OA( HIGH( OutputString )-i-5, ADR( OutputString[i+5] )), TRUE );
      ELSE
         stdout^.WriteOA( OutputString, TRUE );
      END;
   END OnLogOutputString;

(*--------------------------------------------------------------------------------*)

BEGIN
   Method := log.dmNone;
   Level := log.dlcInfo;
END CTestLogger;
   
(*================================================================================*)
   
CLASS CHost IMPLEMENTS test.IHost;
   PRIVATE VAR
      _Progress : CARDINAL := 0;
      _Logger : CTestLogger;

   // IHost
   PUBLIC VIRTUAL READONLY PROPERTY
      Log : log.TPLogger;
   PUBLIC VIRTUAL PROPERTY
      Progress : CARDINAL; // percent
   // optional
   PUBLIC VIRTUAL PROCEDURE StartPhase( CONST Name : ARRAY OF WCHAR );
   PUBLIC VIRTUAL PROCEDURE StopPhase();
   
   // self
   LOCAL PROCEDURE StartSuite( CONST Name : ARRAY OF WCHAR );
   LOCAL PROCEDURE StartTest( CONST Name : ARRAY OF WCHAR );
   LOCAL PROCEDURE StopTest( Result : test.TTestResult );
END CHost;   

(*--------------------------------------------------------------------------------*)

CLASS IMPLEMENTATION CHost;

(*--------------------------------------------------------------------------------*)

   PUBLIC VIRTUAL PROPERTY Log GET : log.TPLogger;
   BEGIN
      RETURN ADR( _Logger );
   END Log;

(*--------------------------------------------------------------------------------*)

   PUBLIC PROPERTY Progress GET : CARDINAL;
   BEGIN
      RETURN _Progress;
   END Progress;

(*--------------------------------------------------------------------------------*)

   PUBLIC PROPERTY Progress SET( Value : CARDINAL );
   BEGIN
      _Progress := Value;
   END Progress;

(*--------------------------------------------------------------------------------*)

   PUBLIC VIRTUAL PROCEDURE StartPhase( CONST Name : ARRAY OF WCHAR );
   BEGIN
   END StartPhase;

(*--------------------------------------------------------------------------------*)

   PUBLIC VIRTUAL PROCEDURE StopPhase();
   BEGIN
   END StopPhase;

(*--------------------------------------------------------------------------------*)

   LOCAL PROCEDURE StartSuite( CONST Name : ARRAY OF WCHAR );
   BEGIN
      _Logger.LogSS( log.dlcInfo, L"", "Suite: ", Name );
   END StartSuite;

(*--------------------------------------------------------------------------------*)

   LOCAL PROCEDURE StartTest( CONST Name : ARRAY OF WCHAR );
   BEGIN
      _Logger.LogSS( log.dlcInfo, L"", "  Test: ", Name );
      _Logger.InsideTest := TRUE;
   END StartTest;

(*--------------------------------------------------------------------------------*)

   LOCAL PROCEDURE StopTest( Result : test.TTestResult );
   BEGIN
      _Logger.InsideTest := FALSE;
      IF Result = test.trSuccess THEN
         _Logger.LogS( log.dlcInfo, L"", L"    Result: Success" );
      ELSE
         _Logger.LogS( log.dlcInfo, L"", L"    Result: Failure" );
      END;
   END StopTest;

(*--------------------------------------------------------------------------------*)

BEGIN
END CHost;

(*================================================================================*)
   
TYPE
  TParamStringArray  = ARRAY [0..0] OF POINTER TO ARRAY [0..511] OF WCHAR;
  TPParamStringArray = POINTER TO TParamStringArray;
  
# save, call( convention => cdecl )
PROCEDURE wmain( argc : INTEGER; argp : TPParamStringArray; enpv : TPParamStringArray ) : INTEGER;
# restore
LABEL
   Error;
TYPE
   PPWCHAR = POINTER TO PWCHAR;
VAR
   ClassPath : ARRAY [0..255] OF WCHAR;
   ESl : PTR;
   ESt : PTR;
   Host : CHost;
   errout : TextWriter.TPTextWriter := TextWriter.errout();
   i : INTEGER;
   LibraryState : loader.TState;
   LoadResult : iobject.TResult;
   Name : ARRAY [0..127] OF WCHAR;
   Path : FIO.PathStrW;
   StdOutFlag : BOOLEAN := FALSE;
   Test : test.TPTest;
   TestResult : test.TTestResult;
   Tests : test.TPTests;
BEGIN
   i := 1;
   WHILE i < argc DO
      IF ( argp^[i]^[0] = L'/' ) OR ( argp^[i]^[0] = L'-' ) THEN // option

         CASE argp^[i]^[1] OF
         | L'h' :
            GOTO Error;
         | L'o' :
            StdOutFlag := TRUE;
         ELSE
            errout^.WriteOA( L"runtest: invalid option ", FALSE ); errout^.WriteOA( argp^[i]^, TRUE );
            GOTO Error;
         END;

      ELSE // file
         loader.ldr()^.AddLibrary( OAsz( argp^[i] ));
      END;
      
      INC( i );
   END; // WHILE
   
   ESl := 0;
   WHILE loader.ldr()^.EnumerateLibraries( REF ESl, OUT Name, OUT Path, OUT LibraryState ) DO
      Strings.ConcatW( OUT ClassPath, Name, L"/Development.Tests" );
      LoadResult := loader.ldr()^.CreateObject( ClassPath, OUT Tests );
      IF LoadResult <> iobject.lrSuccess THEN
         errout^.WriteOA( L"  Error loading library: ", FALSE ); errout^.WriteOA( Name, TRUE );
         CONTINUE;
      END;

      Host.StartSuite( Name );

      ESt := 0;
      WHILE Tests^.EnumerateTests( REF ESt, OUT Name, OUT Test ) DO
         Host.StartTest( Name );
      
         TestResult := Test^.Run( ADR( Host ), OA( -1, PPWCHAR( NIL )));
         
         Host.StopTest( TestResult );
      END; // WHITE Tests
      
      loader.ldr()^.ReleaseObject( REF Tests );
   END; // WHILE Libraries

   RETURN 0;

Error:
   errout^.WriteOA( L"  usage: runtest [-o] <test-dll-list> [-h]", TRUE );
   RETURN -1;
END wmain;
  
END runtest.