MODULE runtest;

FROM Storage IMPORT
  ALLOCATE, DEALLOCATE;

IMPORT
   datetime,
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
   TextWriter;
   
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
   
   TPTestOutput = POINTER TO CTestOutput;
   
(*--------------------------------------------------------------------------------*)

CLASS CTestOutput( log.AFormatter );

   // IOutput
   PUBLIC VIRTUAL PROCEDURE Append( Level : log.TLevel; FilterData : PTR; CONST Logger, Prefix, Message : ARRAY OF WCHAR );

   // AFormatter
   INTERNAL VIRTUAL PROCEDURE Output( CONST Message : ARRAY OF WCHAR );

   // SELF
   PRIVATE VAR
      stdout : TextWriter.TPTextWriter := TextWriter.stdout();
   LOCAL VAR
      Inside : TInside := insideSuite;

END CTestOutput;

(*--------------------------------------------------------------------------------*)

CLASS IMPLEMENTATION CTestOutput;

(*--------------------------------------------------------------------------------*)

   PUBLIC VIRTUAL PROCEDURE Append( Level : log.TLevel; FilterData : PTR; CONST Logger, Prefix, Message : ARRAY OF WCHAR );
   VAR
      Buffer : ARRAY [0..4095] OF WCHAR;
   BEGIN
      CASE Inside OF
      | insideSuite :
         SUPER.Append( Level, FilterData, Logger, Prefix, Message );
      | insideTest :
         Strings.ConcatW( OUT Buffer, L"  ", Message );
         SUPER.Append( Level, FilterData, Logger, Prefix, Buffer );
      | insidePhase :
         Strings.ConcatW( OUT Buffer, L"        ", Message );
         SUPER.Append( Level, FilterData, Logger, Prefix, Buffer );
      END;
   END Append;

(*--------------------------------------------------------------------------------*)

   INTERNAL VIRTUAL PROCEDURE Output( CONST Message : ARRAY OF WCHAR );
   BEGIN
      stdout^.WriteOA( Message, TRUE );
   END Output;

(*--------------------------------------------------------------------------------*)

BEGIN
END CTestOutput;
   
(*================================================================================*)
   
CLASS CHost IMPLEMENTS test.IHost, thread.IRunnable;
   PRIVATE VAR
      _Progress : CARDINAL := 0;
      _Logger : log.CPlainLogger;
      _Output : CTestOutput;
      _FastEvaluation : BOOLEAN := FALSE;
      _Test : test.TPTest := NIL;
      _TestResult : test.TTestResult := test.trFailure;

   // IHost
   PUBLIC VIRTUAL READONLY PROPERTY
      Log : log.TPILogger;
      Output : log.TPIOutput;
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
   PUBLIC READONLY PROPERTY
      TestOutput : TPTestOutput;
   LOCAL PROCEDURE StartSuite( CONST Name : ARRAY OF WCHAR; FastEvaluation : BOOLEAN );
   LOCAL PROCEDURE RunTest( CONST Name : ARRAY OF WCHAR; Test : test.TPTest ) : Sync.TAsyncResult;
END CHost;   

(*--------------------------------------------------------------------------------*)

CLASS IMPLEMENTATION CHost;

(*--------------------------------------------------------------------------------*)

   PUBLIC VIRTUAL PROPERTY Log GET : log.TPILogger;
   BEGIN
      RETURN ADR( _Logger );
   END Log;

(*--------------------------------------------------------------------------------*)

   PUBLIC VIRTUAL PROPERTY Output GET : log.TPIOutput;
   BEGIN
      RETURN ADR( _Logger );
   END Output;

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
      _Logger.LogSS( log.lcInfo, 0, L"", "    Phase: ", Name );
      _Output.Inside := insidePhase;
   END StartPhase;

(*--------------------------------------------------------------------------------*)

   PUBLIC VIRTUAL PROCEDURE StopPhase();
   BEGIN
      StopPhaseWithResult( test.trUnknown );
   END StopPhase;

(*--------------------------------------------------------------------------------*)

   PUBLIC VIRTUAL PROCEDURE StopPhaseWithResult( Result : test.TTestResult );
   BEGIN
      _Output.Inside := insideTest;
      IF Result = test.trFailure THEN
         _Logger.LogS( log.lcInfo, 0, L"", L"      Result: Failure" );
      END;
   END StopPhaseWithResult;

(*--------------------------------------------------------------------------------*)

   LOCAL PROCEDURE StartSuite( CONST Name : ARRAY OF WCHAR; FastEvaluation : BOOLEAN );
   BEGIN
      _FastEvaluation := FastEvaluation;
      _Logger.LogSS( log.lcInfo, 0, L"", "Suite: ", Name );
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

   PUBLIC PROPERTY TestOutput GET : TPTestOutput;
   BEGIN
      RETURN ADR( _Output );
   END TestOutput;

(*--------------------------------------------------------------------------------*)

   LOCAL PROCEDURE RunTest( CONST Name : ARRAY OF WCHAR; Test : test.TPTest ) : Sync.TAsyncResult;
   VAR
      asyncResult : Sync.TAsyncResult;
      Thread : thread.Thread;
      Time : CARDINAL;
   BEGIN
      _Test := Test;
      _TestResult := test.trFailure;

      _Output.Inside := insideTest;
      _Logger.LogSS( log.lcInfo, 0, L"", "Test: ", Name );
      
      asyncResult := Thread.RunWithRunnable( ADR( SELF ));
      IF asyncResult = Sync.arCompleted THEN
         Time := datetime.UptimeMS();

         Thread.Stop( FALSE );
         asyncResult := Thread.WaitStop( SLOW_TIMEOUT );

         IF asyncResult = Sync.arTimeout THEN
            // fall down, no need to evaluate timeout
         ELSIF _FastEvaluation THEN
            IF datetime.UptimeMS() > Time + FAST_TIMEOUT THEN
               asyncResult := Sync.arTimeout;
            END;
         ELSE
            IF datetime.UptimeMS() > Time + SLOW_TIMEOUT THEN
               asyncResult := Sync.arTimeout;
            END;
         END;

      END;
      IF asyncResult <> Sync.arCompleted THEN
         _TestResult := test.trFailure;
      END;

      _Output.Inside := insideTest;
      IF _TestResult = test.trSuccess THEN
         _Logger.LogS( log.lcInfo, 0, L"", L"  Result: Success" );
      ELSE
         _Logger.LogSR( log.lcInfo, 0, L"", L"  Result: Failure", asyncResult );
      END;
      _Output.Inside := insideSuite;

      RETURN asyncResult;
   END RunTest;

(*--------------------------------------------------------------------------------*)

BEGIN
   _Logger.Level := log.ldDebug;
   _Logger.Output := log.outsNone;
   _Logger.AddOutput( ADR( _Output ));
END CHost;

(*================================================================================*)
   
TYPE
  TParamStringArray  = ARRAY [0..0] OF POINTER TO ARRAY [0..511] OF WCHAR;
  TPParamStringArray = POINTER TO TParamStringArray;
  
# save, call( convention => cdecl )
PROCEDURE Main( argc : INTEGER; argp : TPParamStringArray ) : INTEGER;
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
   
   Host.TestOutput^.TimeStamps := TimeStamps;
   
   FOR rc := 1 TO RepeatCount DO
   
      ESl := 0;
      WHILE loader.ldr()^.EnumerateLibraries( REF ESl, OUT Name, OUT Path, OUT LibraryState ) DO
         Strings.ConcatW( OUT ClassPath, Name, L"/Development.Tests" );
         LoadResult := loader.ldr()^.CreateObject( ClassPath, OUT Tests );
         IF LoadResult <> iobject.lrSuccess THEN
            Host.Log^.LogSS( log.lcSysError, 0, L"", L"Error loading library: ", Name );
            Host.Log^.LogSC( log.lcSysError, 0, L"", L"          load result: ", CARDINAL( LoadResult ));
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
               Host.Log^.LogSS( log.lcSysError, 0, L"", L"Error getting test: ", Name );
               CONTINUE;
            END;
         
            IF NOT Filters.Empty THEN
               Found := FALSE;
               Filters.Reset();
               WHILE Filters.MoveNext() DO
                  IF Strings.MatchW( Name, OA( Filters.Current^.Length-1, Filters.Current^.Data ), FALSE ) THEN
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
END Main;
  
END runtest.
