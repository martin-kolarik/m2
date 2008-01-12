MODULE runtest;

FROM Storage IMPORT
  ALLOCATE, DEALLOCATE;

IMPORT
   FIO,
   iobject,
   lists,
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

TYPE
   TInside = (
      insideSuite,
      insideTest,
      insidePhase
   );
   
(*--------------------------------------------------------------------------------*)

CLASS CTestLogger( log.CLogger );
   PRIVATE VAR
      stdout : TextWriter.TPTextWriter := TextWriter.stdout();
   LOCAL VAR
      Inside : TInside := insideSuite;
   INTERNAL VIRTUAL PROCEDURE Log( LoggedLevel : log.TDebugLevel; CONST Prefix, S : ARRAY OF WCHAR );
   INTERNAL VIRTUAL PROCEDURE OnLogOutputString( CONST OutputString : ARRAY OF WCHAR );
END CTestLogger;

(*--------------------------------------------------------------------------------*)

CLASS IMPLEMENTATION CTestLogger;

(*--------------------------------------------------------------------------------*)

   INTERNAL VIRTUAL PROCEDURE Log( LoggedLevel : log.TDebugLevel; CONST Prefix, S : ARRAY OF WCHAR );
   VAR
      Buffer : ARRAY [0..4095] OF WCHAR;
   BEGIN
      CASE Inside OF
      | insideSuite :
         SUPER.Log( LoggedLevel, Prefix, S );
      | insideTest :
         Strings.ConcatW( OUT Buffer, L"  ", S );
         SUPER.Log( LoggedLevel, Prefix, Buffer );
      | insidePhase :
         Strings.ConcatW( OUT Buffer, L"        ", S );
         SUPER.Log( LoggedLevel, Prefix, Buffer );
      END;
   END Log;

(*--------------------------------------------------------------------------------*)

   INTERNAL VIRTUAL PROCEDURE OnLogOutputString( CONST OutputString : ARRAY OF WCHAR );
   BEGIN
      stdout^.WriteOA( OutputString, TRUE );
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
      _Logger.LogSS( log.dlcInfo, L"", "    Phase: ", Name );
      _Logger.Inside := insidePhase;
   END StartPhase;

(*--------------------------------------------------------------------------------*)

   PUBLIC VIRTUAL PROCEDURE StopPhase();
   BEGIN
      _Logger.Inside := insideTest;
   END StopPhase;

(*--------------------------------------------------------------------------------*)

   LOCAL PROCEDURE StartSuite( CONST Name : ARRAY OF WCHAR );
   BEGIN
      _Logger.LogSS( log.dlcInfo, L"", "Suite: ", Name );
   END StartSuite;

(*--------------------------------------------------------------------------------*)

   LOCAL PROCEDURE StartTest( CONST Name : ARRAY OF WCHAR );
   BEGIN
      _Logger.Inside := insideTest;
      _Logger.LogSS( log.dlcInfo, L"", "Test: ", Name );
   END StartTest;

(*--------------------------------------------------------------------------------*)

   LOCAL PROCEDURE StopTest( Result : test.TTestResult );
   BEGIN
      IF Result = test.trSuccess THEN
         _Logger.LogS( log.dlcInfo, L"", L"  Result: Success" );
      ELSE
         _Logger.LogS( log.dlcInfo, L"", L"  Result: Failure" );
      END;
      _Logger.Inside := insideSuite;
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
   Filters : lists.CStringList;
   Found : BOOLEAN;
   i : INTEGER;
   LibraryState : loader.TState;
   LoadResult : iobject.TResult;
   Name : ARRAY [0..127] OF WCHAR;
   Path : FIO.PathStrW;
   StdOutFlag : BOOLEAN := FALSE;
   Test : test.TPTest;
   TestResult : test.TTestResult;
   Tests : test.TPTests;
   TimeStamps : BOOLEAN := FALSE;
   TotalResult : BOOLEAN := TRUE;
BEGIN
   i := 1;
   WHILE i < argc DO
      IF ( argp^[i]^[0] = L'/' ) OR ( argp^[i]^[0] = L'-' ) THEN // option

         CASE argp^[i]^[1] OF
         | L'f' : // filter test
            INC( i );
            IF i = argc THEN
               errout^.WriteOA( L"runtest: missing filter string for -f option ", TRUE );
               GOTO Error;
            END;
            Filters.AddOA( OAsz( argp^[i] ), 0 );
         | L'h' :
            GOTO Error;
         | L'o' :
            StdOutFlag := TRUE;
         | L't' :
            TimeStamps := TRUE;
         ELSE
            errout^.WriteOA( L"runtest: invalid option ", FALSE ); errout^.WriteOA( argp^[i]^, TRUE );
            GOTO Error;
         END;

      ELSE // file
         loader.ldr()^.AddLibrary( OAsz( argp^[i] ));
      END;
      
      INC( i );
   END; // WHILE
   
   Host.Log^.TimeStamps := TimeStamps;
   
   ESl := 0;
   WHILE loader.ldr()^.EnumerateLibraries( REF ESl, OUT Name, OUT Path, OUT LibraryState ) DO
      Strings.ConcatW( OUT ClassPath, Name, L"/Development.Tests" );
      LoadResult := loader.ldr()^.CreateObject( ClassPath, OUT Tests );
      IF LoadResult <> iobject.lrSuccess THEN
         Host.Log^.LogSS( log.dlcSysError, L"", L"Error loading library: ", Name );
         CONTINUE;
      END;

      Host.StartSuite( Name );

      ESt := 0;
      WHILE Tests^.EnumerateTests( REF ESt, OUT Name, OUT Test ) DO
         IF NOT Filters.Empty THEN
            Found := FALSE;
            Filters.Reset();
            WHILE Filters.MoveNext() DO
               IF Strings.MatchW( Name, OA( Filters.Current^.Length-1, Filters.Current^.rawData ), FALSE ) THEN
                  Found := TRUE;
                  EXIT;
               END;
            END; // WHILE
            IF NOT Found THEN
               CONTINUE;
            END;
         END;

         Host.StartTest( Name );
         TestResult := Test^.Run( ADR( Host ), OA( -1, PPWCHAR( NIL )));
         Host.StopTest( TestResult );
         
         TotalResult := TotalResult AND ( TestResult = test.trSuccess );
      END; // WHITE Tests
      
      loader.ldr()^.ReleaseObject( REF Tests );
   END; // WHILE Libraries

   IF TotalResult THEN
      RETURN 0;
   ELSE
      RETURN 1;
   END;

Error:
   errout^.WriteOA( L"  usage: runtest [-o] [-t] [-f <filter>] <test-dll-list> [-h]", TRUE );
   RETURN -1;
END wmain;
  
END runtest.