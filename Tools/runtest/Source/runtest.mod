MODULE runtest;

FROM Storage IMPORT
  ALLOCATE, DEALLOCATE;

IMPORT
   FIO,
   loader,
   log,
   objlib,
   Strings,
   StringsO,
   Sync,
   test,
   TextReader,
   TextWriter,
   time;
   
(*================================================================================*)
   
CLASS CTestLogger( log.CLogger );
   INTERNAL VIRTUAL PROCEDURE OnLogOutputString( CONST OutputString : ARRAY OF WCHAR );
END CTestLogger;

(*--------------------------------------------------------------------------------*)

CLASS IMPLEMENTATION CTestLogger;

(*--------------------------------------------------------------------------------*)

   INTERNAL VIRTUAL PROCEDURE OnLogOutputString( CONST OutputString : ARRAY OF WCHAR );
   BEGIN
      // log somewhere
   END OnLogOutputString;

(*--------------------------------------------------------------------------------*)

BEGIN
   Method := log.dmNone;
END CTestLogger;
   
(*================================================================================*)
   
CLASS CHost IMPLEMENTS test.IHost;
   PRIVATE VAR
      _Progress : CARDINAL := 0;
      _Logger : CTestLogger;
   LOCAL VAR
      stdout : TextWriter.TPTextWriter;

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

   PRIVATE PROCEDURE PrintTime();
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
      PrintTime(); stdout^.WriteOA( "  Suite: ", FALSE ); stdout^.WriteOA( Name, TRUE );
   END StartSuite;

(*--------------------------------------------------------------------------------*)

   LOCAL PROCEDURE StartTest( CONST Name : ARRAY OF WCHAR );
   BEGIN
      PrintTime(); stdout^.WriteOA( "  Test: ", FALSE ); stdout^.WriteOA( Name, FALSE );
   END StartTest;

(*--------------------------------------------------------------------------------*)

   LOCAL PROCEDURE StopTest( Result : test.TTestResult );
   BEGIN
      stdout^.LineEnd();
      PrintTime(); 
      IF Result = test.trSuccess THEN
         stdout^.WriteOA( "    Result: success", TRUE );
      ELSE
         stdout^.WriteOA( "    Result: failure", TRUE );
      END;
   END StopTest;

(*--------------------------------------------------------------------------------*)

   PRIVATE PROCEDURE PrintTime();
   VAR
      dt : time.TDateTime;
      SW : ARRAY [0..31] OF WCHAR;
   BEGIN
      time.GetCurrentUTCDateTime( dt );
      time.DateTimeToString( dt, L"[yyyy-MM-dd HH:mm:ss.f] ", TRUE, TRUE, OUT SW );
      stdout^.WriteOA( SW, FALSE );
   END PrintTime;

(*--------------------------------------------------------------------------------*)

BEGIN
   stdout := TextWriter.stdout();
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
   LoadResult : objlib.TResult;
   Name : ARRAY [0..127] OF WCHAR;
   Object : objlib.TPObject;
   Path : FIO.PathStrW;
   StdOutFlag : BOOLEAN := FALSE;
   Test : test.TPTest;
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
      LoadResult := loader.ldr()^.CreateObject( ClassPath, OUT Object );
      IF LoadResult <> objlib.lrSuccess THEN
         errout^.WriteOA( L"  Error loading library: ", FALSE ); errout^.WriteOA( Name, TRUE );
         CONTINUE;
      END;
      Tests := test.TPTests( Object );

      ESt := 0;
      WHILE Tests^.EnumerateTests( REF ESt, OUT Name, OUT Test ) DO
         Test^.Run( ADR( Host ), OA( -1, PPWCHAR( NIL )));
      END; // WHITE Tests
      
      Object^.Dispose();
   END; // WHILE Libraries

   RETURN 0;

Error:
   errout^.WriteOA( L"  usage: runtest [-o] <test-dll-list> [-h]", TRUE );
   RETURN -1;
END wmain;
  
END runtest.