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
   thread,
   TextReader,
   TextWriter,
   time;
   
(*================================================================================*)

CONST
   FAST_TIMEOUT = 5000; // 5 seconds for test
   SLOW_TIMEOUT = 60*60*1000; // 1 hour

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
   INTERNAL VIRTUAL PROCEDURE Log( LoggedLevel : log.TDebugLevel; CONST Name, Prefix, S : ARRAY OF WCHAR );
   INTERNAL VIRTUAL PROCEDURE OnLogOutputString( CONST OutputString : ARRAY OF WCHAR );
END CTestLogger;

(*--------------------------------------------------------------------------------*)

CLASS IMPLEMENTATION CTestLogger;

(*--------------------------------------------------------------------------------*)

   INTERNAL VIRTUAL PROCEDURE Log( LoggedLevel : log.TDebugLevel; CONST Name, Prefix, S : ARRAY OF WCHAR );
   VAR
      Buffer : ARRAY [0..4095] OF WCHAR;
   BEGIN
      CASE Inside OF
      | insideSuite :
         SUPER.Log( LoggedLevel, Name, Prefix, S );
      | insideTest :
         Strings.ConcatW( OUT Buffer, L"  ", S );
         SUPER.Log( LoggedLevel, Name, Prefix, Buffer );
      | insidePhase :
         Strings.ConcatW( OUT Buffer, L"        ", S );
         SUPER.Log( LoggedLevel, Name, Prefix, Buffer );
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
   
CLASS CHost IMPLEMENTS test.IHost, thread.IRunnable;
   PRIVATE VAR
      _Progress : CARDINAL := 0;
      _Logger : CTestLogger;
      _FastEvaluation : BOOLEAN := FALSE;
      _Test : test.TPTest := NIL;
      _TestResult : test.TTestResult := test.trFailure;

   // IHost
   PUBLIC VIRTUAL READONLY PROPERTY
      Log : log.TPLogger;
      FastEvaluation : BOOLEAN;
   PUBLIC VIRTUAL PROPERTY
      Progress : CARDINAL; // percent
   // optional
   PUBLIC VIRTUAL PROCEDURE StartPhase( CONST Name : ARRAY OF WCHAR );
   PUBLIC VIRTUAL PROCEDURE StopPhase();
   PUBLIC VIRTUAL PROCEDURE StopPhaseWithResult( Result : test.TTestResult );
   
   // IRunnable
   INTERNAL VIRTUAL PROCEDURE OnRun( CONST Helper : thread.IRunnableHelper ) : CARDINAL;
   
   // self
   LOCAL PROCEDURE StartSuite( CONST Name : ARRAY OF WCHAR; FastEvaluation : BOOLEAN );
   LOCAL PROCEDURE RunTest( CONST Name : ARRAY OF WCHAR; Test : test.TPTest ) : Sync.TAsyncResult;
END CHost;   

(*--------------------------------------------------------------------------------*)

CLASS IMPLEMENTATION CHost;

(*--------------------------------------------------------------------------------*)

   PUBLIC VIRTUAL PROPERTY Log GET : log.TPLogger;
   BEGIN
      RETURN ADR( _Logger );
   END Log;

(*--------------------------------------------------------------------------------*)

   PUBLIC VIRTUAL PROPERTY FastEvaluation GET : BOOLEAN;
   BEGIN
      RETURN _FastEvaluation;
   END FastEvaluation;

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
      StopPhaseWithResult( test.trUnknown );
   END StopPhase;

(*--------------------------------------------------------------------------------*)

   PUBLIC VIRTUAL PROCEDURE StopPhaseWithResult( Result : test.TTestResult );
   BEGIN
      _Logger.Inside := insideTest;
      IF Result = test.trFailure THEN
         _Logger.LogS( log.dlcInfo, L"", L"      Result: Failure" );
      END;
   END StopPhaseWithResult;

(*--------------------------------------------------------------------------------*)

   LOCAL PROCEDURE StartSuite( CONST Name : ARRAY OF WCHAR; FastEvaluation : BOOLEAN );
   BEGIN
      _FastEvaluation := FastEvaluation;
      _Logger.LogSS( log.dlcInfo, L"", "Suite: ", Name );
   END StartSuite;

(*--------------------------------------------------------------------------------*)

   INTERNAL VIRTUAL PROCEDURE OnRun( CONST Helper : thread.IRunnableHelper ) : CARDINAL;
   TYPE
      PPWCHAR = POINTER TO PWCHAR;
   BEGIN
      _TestResult := _Test^.Run( ADR( SELF ), OA( -1, PPWCHAR( NIL )));
      RETURN 0;
   END OnRun;

(*--------------------------------------------------------------------------------*)

   LOCAL PROCEDURE RunTest( CONST Name : ARRAY OF WCHAR; Test : test.TPTest ) : Sync.TAsyncResult;
   VAR
      asyncResult : Sync.TAsyncResult;
      Thread : thread.Thread;
      Time : CARDINAL;
   BEGIN
      _Test := Test;
      _TestResult := test.trFailure;

      _Logger.Inside := insideTest;
      _Logger.LogSS( log.dlcInfo, L"", "Test: ", Name );
      
      asyncResult := Thread.RunWithRunnable( ADR( SELF ));
      IF asyncResult = Sync.arCompleted THEN
         Time := time.UptimeMS();

         Thread.Stop( FALSE );
         asyncResult := Thread.WaitStop( SLOW_TIMEOUT );

         IF asyncResult = Sync.arTimeout THEN
            // fall down, no need to evaluate timeout
         ELSIF _FastEvaluation THEN
            IF time.UptimeMS() > Time + FAST_TIMEOUT THEN
               asyncResult := Sync.arTimeout;
            END;
         ELSE
            IF time.UptimeMS() > Time + SLOW_TIMEOUT THEN
               asyncResult := Sync.arTimeout;
            END;
         END;

      END;
      IF asyncResult <> Sync.arCompleted THEN
         _TestResult := test.trFailure;
      END;

      _Logger.Inside := insideTest;
      IF _TestResult = test.trSuccess THEN
         _Logger.LogS( log.dlcInfo, L"", L"  Result: Success" );
      ELSE
         _Logger.LogSR( log.dlcInfo, L"", L"  Result: Failure", asyncResult );
      END;
      _Logger.Inside := insideSuite;

      RETURN asyncResult;
   END RunTest;

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
VAR
   ClassPath : ARRAY [0..255] OF WCHAR;
   ESl : PTR;
   ESt : PTR;
   Host : CHost;
   errout : TextWriter.TPTextWriter := TextWriter.errout();
   Filters : lists.CStringList;
   FastEvaluation : BOOLEAN := FALSE;
   Found : BOOLEAN;
   i : INTEGER;
   LibraryState : loader.TState;
   LoadResult : iobject.TResult;
   Name : ARRAY [0..127] OF WCHAR;
   Path : FIO.PathStrW;
   RepeatCount, rc : CARDINAL := 1;
   StdOutFlag : BOOLEAN := FALSE;
   Test : test.TPTest;
   Tests : test.TPTests;
   TimeStamps : BOOLEAN := FALSE;
   TotalResult : CARDINAL := 0;
BEGIN
   i := 1;
   WHILE i < argc DO
      IF ( argp^[i]^[0] = L'/' ) OR ( argp^[i]^[0] = L'-' ) THEN // option

         CASE argp^[i]^[1] OF
         | L'F' : // fast evaluation
            FastEvaluation := TRUE;
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
         | L'r' :
            INC( i );
            IF i = argc THEN
               errout^.WriteOA( L"runtest: missing repeat count for -r option ", TRUE );
               GOTO Error;
            END;
            IF NOT Strings.ToCARD32W( OAsz( argp^[i] ), 10, OUT RepeatCount ) THEN
               RepeatCount := 1;
            END;
         | L't' :
            TimeStamps := TRUE;
         ELSE
            errout^.WriteOA( L"runtest: invalid option ", FALSE ); errout^.WriteOA( argp^[i]^, TRUE );
            GOTO Error;
         END;

      ELSE // file
         loader.ldr()^.AddLibrary( OAsz( argp^[i] ), NIL );
      END;
      
      INC( i );
   END; // WHILE
   
   Host.Log^.TimeStamps := TimeStamps;
   
   FOR rc := 1 TO RepeatCount DO
   
      ESl := 0;
      WHILE loader.ldr()^.EnumerateLibraries( REF ESl, OUT Name, OUT Path, OUT LibraryState ) DO
         Strings.ConcatW( OUT ClassPath, Name, L"/Development.Tests" );
         LoadResult := loader.ldr()^.CreateObject( ClassPath, OUT Tests );
         IF LoadResult <> iobject.lrSuccess THEN
            Host.Log^.LogSS( log.dlcSysError, L"", L"Error loading library: ", Name );
            Host.Log^.LogSC( log.dlcSysError, L"", L"          load result: ", CARDINAL( LoadResult ));
            IF LoadResult = iobject.lrLibraryNotFound THEN
               CONTINUE;
            ELSE
               TotalResult := 1;
               EXIT;
            END;
         END;

         Host.StartSuite( Name, FastEvaluation );

         ESt := 0;
         WHILE Tests^.EnumerateTests( REF ESt, OUT Name, OUT Test ) DO
            IF Test = NIL THEN
               Host.Log^.LogSS( log.dlcSysError, L"", L"Error getting test: ", Name );
               CONTINUE;
            END;
         
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

            CASE Host.RunTest( Name, Test ) OF
            | Sync.arCompleted :
               // do nothing
            | Sync.arTimeout : // this is fatal error
               TotalResult := 2;
               EXIT;
            ELSE
               TotalResult := 3;
            END;
         END; // WHITE Tests
         
         loader.ldr()^.ReleaseObject( REF Tests );
      END; // WHILE Libraries
      
   END; // FOR RepeatCount

   RETURN TotalResult;

Error:
   errout^.WriteOA( L"  usage: runtest [-F] [-o] [-t] [-r <repeatcount>] [-f <filter>] <test-dll-list> [-h]", TRUE );
   RETURN -1;
END wmain;
  
END runtest.
