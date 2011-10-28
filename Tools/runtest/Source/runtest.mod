MODULE runtest;

FROM Storage IMPORT
  ALLOCATE, DEALLOCATE;

IMPORT
   baseobject,
   collection,
   datetime,
   debug,
   FIO,
   iplugin,
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

   // IHost
   PUBLIC VIRTUAL READONLY PROPERTY
      Log : log.TPILogger;
      Output : log.TPIOutput;
      FastEvaluation : BOOLEAN;
   PUBLIC VIRTUAL PROPERTY
      Progress : CARDINAL; // percent
   PUBLIC VIRTUAL PROCEDURE StartPhase( CONST Name : ARRAY OF WCHAR );
   PUBLIC VIRTUAL PROCEDURE StopPhase();
   PUBLIC VIRTUAL PROCEDURE StopPhaseWithResult( result : BOOLEAN ); // expression = TRUE and no ASSERT means success
   PUBLIC VIRTUAL PROCEDURE ParticleWithResult( CONST Description : ARRAY OF WCHAR; result : BOOLEAN ); // expression = TRUE and no ASSERT means success
   PUBLIC VIRTUAL PROCEDURE ParticleWithAssert( CONST Description : ARRAY OF WCHAR ); // found means success
   
   // IRunnable
   INTERNAL VIRTUAL PROCEDURE OnRun( Restarted : BOOLEAN; CONST Helper : thread.IRunnableHelper ) : CARDINAL;
   
   // self
   PUBLIC READONLY PROPERTY
      TestOutput : TPTestOutput;
   LOCAL PROCEDURE StartSuite( CONST Name : ARRAY OF WCHAR; FastEvaluation : BOOLEAN );
   LOCAL PROCEDURE RunTest( CONST Name : ARRAY OF WCHAR; Test : test.TPTest ) : Sync.TAsyncResult;

   LOCAL PROCEDURE AssertHook( CONST AssertText : StringsO.CString );

   // SELF
   PRIVATE VAR
      _Progress : CARDINAL := 0;
      _Logger : log.CBaseLogger;
      _Output : CTestOutput;
      _FastEvaluation : BOOLEAN := FALSE;
      _Test : test.TPTest := NIL;
      _ParticleAssert : BOOLEAN := FALSE;
      _ParticleAssertText : StringsO.CString;
      _PhaseResult : test.TTestResult := test.trFailure;
      _TestResult : test.TTestResult := test.trFailure;
      _SuiteResult : test.TTestResult := test.trFailure;

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
      _PhaseResult := test.trUnknown;
      _ParticleAssert := FALSE;
      _ParticleAssertText.Clear();
   END StartPhase;

(*--------------------------------------------------------------------------------*)

   PUBLIC VIRTUAL PROCEDURE StopPhase();
   BEGIN
      _Output.Inside := insideTest;
      IF _PhaseResult = test.trFailure THEN
         _Logger.LogS( log.lcInfo, 0, L"", L"      Result: Failure" );
         _TestResult := test.trFailure;
      ELSIF _TestResult = test.trUnknown THEN
         _TestResult := _PhaseResult;
      END;
   END StopPhase;

(*--------------------------------------------------------------------------------*)

   PUBLIC VIRTUAL PROCEDURE StopPhaseWithResult( result : BOOLEAN ); // expression = TRUE
   BEGIN
      IF result THEN
         _PhaseResult := test.trSuccess;
      ELSE
         _PhaseResult := test.trFailure;
      END;
      StopPhase();
   END StopPhaseWithResult;

(*--------------------------------------------------------------------------------*)

   PUBLIC VIRTUAL PROCEDURE ParticleWithResult( CONST FailureText : ARRAY OF WCHAR; result : BOOLEAN ); // expression = TRUE and no ASSERT means success
   BEGIN
      IF NOT result THEN // TRUE expected
         _Logger.LogSS( log.lcInfo, 0, L"", L"        failure: ", FailureText );
         _PhaseResult := test.trFailure;
         _TestResult := test.trFailure;
      ELSIF _ParticleAssert THEN // unexpected
         _Logger.LogSS( log.lcInfo, 0, L"", L"        failure (assert): ", FailureText );
         _PhaseResult := test.trFailure;
         _TestResult := test.trFailure;
      ELSIF _PhaseResult = test.trUnknown THEN
         _PhaseResult := test.trSuccess;
         IF _TestResult = test.trUnknown THEN
            _TestResult := test.trSuccess;
         END;
      END;
      _ParticleAssert := FALSE;
      _ParticleAssertText.Clear();
   END ParticleWithResult;

(*--------------------------------------------------------------------------------*)

   PUBLIC VIRTUAL PROCEDURE ParticleWithAssert( CONST FailureText : ARRAY OF WCHAR ); // found means success
   BEGIN
      IF NOT _ParticleAssert THEN // assert expected, but did not occur
         _Logger.LogSS( log.lcInfo, 0, L"", L"        failure: ", FailureText );
         _PhaseResult := test.trFailure;
      ELSIF _PhaseResult = test.trUnknown THEN
         _PhaseResult := test.trSuccess; 
         IF _TestResult = test.trUnknown THEN
            _TestResult := test.trSuccess;
         END;
      END;
      _ParticleAssert := FALSE;
      _ParticleAssertText.Clear();
   END ParticleWithAssert;

(*--------------------------------------------------------------------------------*)

   LOCAL PROCEDURE StartSuite( CONST Name : ARRAY OF WCHAR; FastEvaluation : BOOLEAN );
   BEGIN
      _Logger.LogSS( log.lcInfo, 0, L"", "Suite: ", Name );
      _FastEvaluation := FastEvaluation;
      _SuiteResult := test.trUnknown;
      _TestResult := test.trUnknown;
   END StartSuite;

(*--------------------------------------------------------------------------------*)

   INTERNAL VIRTUAL PROCEDURE OnRun( Restarted : BOOLEAN; CONST Helper : thread.IRunnableHelper ) : CARDINAL;
   TYPE
      PPWCHAR = POINTER TO PWCHAR;
   VAR
      result : test.TTestResult;
   BEGIN
      result := _Test^.Run( ADR( SELF ), OA( -1, PPWCHAR( NIL )));
      IF result = test.trFailure THEN
         _TestResult := test.trFailure;
      ELSIF _TestResult = test.trUnknown THEN
         _TestResult := result;
      END;
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
      _TestResult := test.trUnknown;
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
         IF _SuiteResult = test.trUnknown THEN
            _SuiteResult := test.trSuccess;
         END;
      ELSIF _TestResult = test.trFailure THEN
         _Logger.LogSR( log.lcInfo, 0, L"", L"  Result: Failure", asyncResult );
         _SuiteResult := test.trFailure;
      ELSE
         _Logger.LogS( log.lcInfo, 0, L"", L"  Result: unknown" );
      END;
      _Output.Inside := insideSuite;

      RETURN asyncResult;
   END RunTest;

(*--------------------------------------------------------------------------------*)

   LOCAL PROCEDURE AssertHook( CONST AssertText : StringsO.CString );
   BEGIN
      _ParticleAssert := TRUE;
      _ParticleAssertText := AssertText;
   END AssertHook;

(*--------------------------------------------------------------------------------*)

BEGIN
   _Logger.Level := log.ldDebug;
   _Logger.Output := log.outsNone;
   _Logger.AddOutput( ADR( _Output ));
END CHost;

(*--------------------------------------------------------------------------------*)

PROCEDURE AssertHook( UserData : PTR; AssertMessage : ARRAY OF WCHAR );
TYPE
   TPHost = POINTER TO CHost;
BEGIN
   TPHost( UserData )^.AssertHook( StringsO.FromOA( AssertMessage ));
END AssertHook;

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
   disposable : baseobject.TPDisposable;
   errout : TextWriter.TPTextWriter := TextWriter.errout();
   Filters : lists.CStringList;
   filtersIterator : lists.CStringListIterator;
   FastEvaluation : BOOLEAN := FALSE;
   Found : BOOLEAN;
   Host : CHost;
   i : INTEGER;
   LoadResult : iplugin.TLoadResult;
   Name : ARRAY [0..127] OF WCHAR;
   pluginIterator : loader.CLoaderPluginIterator;
   RepeatCount, rc : CARDINAL := 1;
   s : StringsO.CString;
   StdOutFlag : BOOLEAN := FALSE;
   Test : test.TPTest;
   testIterator : POINTER TO test.ITestIterator;
   Tests : test.TPTests;
   TimeStamps : BOOLEAN := FALSE;
   TotalResult : CARDINAL := 0;
BEGIN

   // analyze parameters
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
            Filters.Add( StringsO.FromOA( OAsz( argp^[i] )), 0 );
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
         loader.ldr()^.AddPlugin( OAsz( argp^[i] ), NIL );
      END;
      
      INC( i );
   END; // WHILE
   
   Host.TestOutput^.TimeStamps := TimeStamps;
   debug.SetAssertHook( debug.TAssertHook( AssertHook ), ADR( Host ));
   
   // run tests
   FOR rc := 1 TO RepeatCount DO
   
      loader.ldr()^.InitializePluginIterator( REF pluginIterator );
      WHILE pluginIterator.MoveNext() DO
         pluginIterator.Name.ToOA( OUT Name );

         Strings.ConcatW( OUT ClassPath, Name, L"/Development.Tests" );
         LoadResult := loader.ldr()^.CreateObject( ClassPath, OUT Tests );
         IF LoadResult <> iplugin.lrSuccess THEN
            Host.Log^.LogSS( log.lcSysError, 0, L"", L"Error loading library: ", Name );
            Host.Log^.LogSC( log.lcSysError, 0, L"", L"          load result: ", CARDINAL( LoadResult ));
            IF LoadResult = iplugin.lrPluginNotFound THEN
               CONTINUE;
            ELSE
               TotalResult := 1;
               EXIT;
            END;
         END;

         Host.StartSuite( Name, FastEvaluation );

         testIterator := Tests^.GetIterator();
         WHILE testIterator^.MoveNext() DO
            testIterator^.Name( OUT Name );
            Test := testIterator^.Test;

            IF Test = NIL THEN
               Host.Log^.LogSS( log.lcSysError, 0, L"", L"Error getting test: ", Name );
               CONTINUE;
            END;
         
            IF NOT Filters.Empty THEN
               Found := FALSE;
               filtersIterator.Init( Filters, collection.dirForward );
               WHILE filtersIterator.MoveNext() DO
                  s.FromOA( Name );
                  IF s.Match( filtersIterator.Value^, FALSE ) THEN
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
         disposable := testIterator^.Implementor;
         DISPOSE( disposable );
         
         loader.ldr()^.ReleaseObject( REF Tests );
      END; // WHILE Libraries
      
   END; // FOR RepeatCount

   RETURN TotalResult;

Error:
   errout^.WriteOA( L"  usage: runtest [-F] [-o] [-t] [-r <repeatcount>] [-f <filter>] <test-dll-list> [-h]", TRUE );
   RETURN -1;
END Main;
  
END runtest.
