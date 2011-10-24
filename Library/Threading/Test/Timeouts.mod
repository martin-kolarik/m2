MODULE Timeouts;

FROM Storage IMPORT
   ALLOCATE, DEALLOCATE;

IMPORT
   log,
   msghandler,
   msgqueuethread,
   sync,
   test,
   testimpl,
   threadinit,
   threadpool,
   windows;
  
(*===========================================================================*)

CONST
   LIMIT = 10;
   PERIOD = 500;

TYPE
   TPTest = POINTER TO CTest;

(*---------------------------------------------------------------------------*)

CLASS CDelegate( threadpool.APoolDelegate );
   PUBLIC VAR
      Test : TPTest;
      CheckThread : BOOLEAN;

   LOCAL VIRTUAL PROCEDURE OnTimeout( Result : sync.TAsyncResult; PoolHandle : threadpool.TPoolHandle; UserId : PTR );
END CDelegate;
  
(*---------------------------------------------------------------------------*)

CLASS CTest IMPLEMENTS test.ITest;
   PUBLIC VAR
      Host : test.TPHost := NIL;
      Counts : ARRAY [0..LIMIT-1] OF CARDINAL;
      Delegate : CDelegate;
      Pool : threadpool.TPThreadPool;
      Limit : CARDINAL := 0;
      Period : CARDINAL := 0;

   PUBLIC VIRTUAL PROCEDURE Run( CONST Host : test.TPHost; CONST Parameters : ARRAY OF PWCHAR ) : test.TTestResult;
   PRIVATE PROCEDURE Round( CompletionInOwningThread : BOOLEAN ) : BOOLEAN;
   PRIVATE PROCEDURE WaitForMessages( count : CARDINAL );
END CTest;

VAR
   Test : CTest;

(*===========================================================================*)

CLASS IMPLEMENTATION CDelegate;

(*---------------------------------------------------------------------------*)

   LOCAL VIRTUAL PROCEDURE OnTimeout( Result : sync.TAsyncResult; PoolHandle : threadpool.TPoolHandle; UserId : PTR );
   BEGIN
      IF CheckThread AND NOT msgqueuethread.global()^.SelfContext THEN
         Test^.Host^.Log^.LogS( log.lcError, 0, L"", L"Completion in unexpected thread" );   
      END;
      sync.IInc( REF Test^.Counts[ CARDINAL( LOPTRLONGWORD( UserId )) ] );
   END OnTimeout;

(*---------------------------------------------------------------------------*)

BEGIN
   Test := NIL;
   CheckThread := FALSE;
END CDelegate;

(*===========================================================================*)

CLASS IMPLEMENTATION CTest;

(*---------------------------------------------------------------------------*)

   PUBLIC VIRTUAL PROCEDURE Run( CONST Host : test.TPHost; CONST Parameters : ARRAY OF PWCHAR ) : test.TTestResult;
   VAR
      Failure : BOOLEAN;
   BEGIN
      threadinit.Startup();
      NEW( Pool );
   
      SELF.Host := Host;
      Delegate.Test := ADR( SELF );
      
      IF Host^.FastEvaluation THEN
         Limit := LIMIT DIV 10;
         Period := PERIOD DIV 10;
      ELSE
         Limit := LIMIT;
         Period := PERIOD;
      END;

      Failure := Round( FALSE );

      Failure := Round( TRUE ) OR Failure;

      DISPOSE( Pool );
      threadinit.Cleanup();

      IF Failure THEN
         RETURN test.trFailure;
      ELSE
         RETURN test.trSuccess;
      END;
   END Run;
   
(*---------------------------------------------------------------------------*)

   PRIVATE PROCEDURE Round( CompletionInOwningThread : BOOLEAN ) : BOOLEAN;
   VAR
      FirstFailure, Failure : BOOLEAN := FALSE;
      i : CARDINAL;
      PH : ARRAY [0..LIMIT-1] OF windows.HANDLE;
   BEGIN
      PH[0] := NIL;

      IF CompletionInOwningThread THEN
         Pool^.CompletionInOwningThread := TRUE;
         Delegate.CheckThread := TRUE;
      ELSE
         Pool^.CompletionInOwningThread := FALSE;
         Delegate.CheckThread := FALSE;
      END;

      //==========
      IF CompletionInOwningThread THEN
         Host^.StartPhase( L"10t, completed in own thread" );
      ELSE
         Host^.StartPhase( L"10t" );
      END;
         // reset, initiate
         FOR i := 1 TO Limit-2 DO
            Counts[Limit-i-1] := 0;
            IF NOT Pool^.WaitTimeout( ADR( Delegate ), Limit-i-1, (Limit-i-1) * Period, FALSE, FALSE, OUT PH[i] ) THEN
               Host^.Log^.LogSC( log.lcError, 0, L"", L"Unable to run worker of index: ", i );
            END;
         END; // FOR

         // test
         IF CompletionInOwningThread THEN
            WaitForMessages( Limit + Limit DIV 50 );
         ELSE
            windows.Sleep( Limit + Limit DIV 50 );
         END;

      // check
      FOR i := 1 TO Limit-2 DO
         IF Counts[i] <> Limit DIV i THEN
            Failure := TRUE;
            Host^.Log^.LogSC( log.lcError, 0, L"", L"Failure with index: ", i );
            Host^.Log^.LogSC( log.lcError, 0, L"", L"  expected: ", Limit DIV i );
            Host^.Log^.LogSC( log.lcError, 0, L"", L"  found: ", Counts[i] );
         END;
      END;

      Host^.StopPhaseWithResult( NOT Failure );

      //==========
      IF CompletionInOwningThread THEN
         Host^.StartPhase( L"10t Abort in reverted order, completed in own thread" );
      ELSE
         Host^.StartPhase( L"10t Abort in reverted order" );
      END;
         // reset, initiate
         FOR i := 1 TO Limit-2 DO
            Counts[Limit-i-1] := 0;
         END; // FOR

         IF CompletionInOwningThread THEN
            WaitForMessages( Limit + Limit DIV 50 );
         ELSE
            windows.Sleep( Limit + Limit DIV 50 );
         END;

         // test
         FOR i := Limit-1 TO 0 BY -1 DO
            Pool^.Abort( REF PH[i] );
            IF CompletionInOwningThread THEN
               WaitForMessages( 5 );
            END;
         END; // FOR

         IF CompletionInOwningThread THEN
            WaitForMessages( 50 );
         ELSE
            windows.Sleep( 50 );
         END;

      // check
      FOR i := 1 TO Limit-2 DO
         IF Counts[i] <> Limit DIV i + 1 THEN // +1 is for Abort
            Failure := TRUE;
            Host^.Log^.LogSC( log.lcError, 0, L"", L"Failure with index: ", i );
            Host^.Log^.LogSC( log.lcError, 0, L"", L"  expected: ", Limit DIV i + 1 );
            Host^.Log^.LogSC( log.lcError, 0, L"", L"  found: ", Counts[i] );
         END;
      END;

      Host^.StopPhaseWithResult( NOT Failure );

      RETURN Failure;
   END Round;

(*---------------------------------------------------------------------------*)

   PRIVATE PROCEDURE WaitForMessages( count : CARDINAL );
   VAR
      i : CARDINAL := count;
      msg : windows.MSG;
   BEGIN
      IF i = 0 THEN
         i := 5; // set
         LOOP
            IF Pool^.UndeliveredMessagesPending THEN
               WHILE windows.PeekMessage( ADR( msg ), NIL, 0, 0, windows.PM_REMOVE ) = windows.True DO
                  windows.DispatchMessage( ADR( msg ));
               END; // WHILE
               i := 5; // reset
            ELSIF i = 0 THEN
               EXIT;
            END;
            DEC( i );
            windows.Sleep( 1 );
         END; // WHILE
      ELSE
         WHILE i > 0 DO
            WHILE windows.PeekMessage( ADR( msg ), NIL, 0, 0, windows.PM_REMOVE ) = windows.True DO
               windows.DispatchMessage( ADR( msg ));
            END; // WHILE
            DEC( i );
            windows.Sleep( 1 );
         END; // WHILE
      END;
   END WaitForMessages;

(*---------------------------------------------------------------------------*)

BEGIN
   Pool := NIL;
   Counts[0] := 0;
   testimpl.tests()^.AddTest( L"ThreadPool::Timeouts", ADR( Test ));
END CTest;

(*===========================================================================*)

END Timeouts.
