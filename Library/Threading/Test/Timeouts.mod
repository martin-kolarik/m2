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
   threadpool,
   threadpoolsink,
   windows;
  
(*===========================================================================*)

CONST
   count = 10;

TYPE
   TPTest = POINTER TO CTest;

(*---------------------------------------------------------------------------*)

CLASS CDelegate( threadpoolsink.APoolDelegate );
   PUBLIC VAR
      Test : TPTest;
      CheckThread : BOOLEAN;

   PUBLIC VIRTUAL PROCEDURE OnTimeout( Result : sync.TAsyncResult; PoolHandle : threadpool.TPoolHandle; UserId : PTR );
END CDelegate;
  
(*---------------------------------------------------------------------------*)

CLASS CTest IMPLEMENTS test.ITest;
   PUBLIC VAR
      Host : test.TPHost := NIL;
      Counts : ARRAY [0..count-1] OF CARDINAL;
      Delegate : CDelegate;
      Pool : threadpool.TPThreadPool;

   PUBLIC VIRTUAL PROCEDURE Run( CONST Host : test.TPHost; CONST Parameters : ARRAY OF PWCHAR ) : test.TTestResult;
   PRIVATE PROCEDURE Round( CompletionInOwningThread : BOOLEAN ) : BOOLEAN;
   PRIVATE PROCEDURE WaitForMessages( count : CARDINAL );
END CTest;

VAR
   Test : CTest;

(*===========================================================================*)

CLASS IMPLEMENTATION CDelegate;

(*---------------------------------------------------------------------------*)

   PUBLIC VIRTUAL PROCEDURE OnTimeout( Result : sync.TAsyncResult; PoolHandle : threadpool.TPoolHandle; UserId : PTR );
   BEGIN
      IF CheckThread AND NOT msgqueuethread.global()^.SelfContext THEN
         Test^.Host^.Log^.LogS( log.dlcError, L"", L"Completion in unexpected thread" );   
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
      NEW( Pool );
   
      SELF.Host := Host;
      Delegate.Test := ADR( SELF );

      Failure := Round( FALSE );

      Failure := Round( TRUE ) OR Failure;

      DISPOSE( Pool );
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
      PH : ARRAY [0..count-1] OF windows.HANDLE;
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
         FOR i := 1 TO count-2 DO
            Counts[count-i-1] := 0;
            IF NOT Pool^.WaitTimeout( ADR( Delegate ), count-i-1, ( count-i-1 ) * 500, FALSE, FALSE, OUT PH[i] ) THEN
               Host^.Log^.LogSC( log.dlcError, L"", L"Unable to run worker of index: ", i );
            END;
         END; // FOR

         // test
         IF CompletionInOwningThread THEN
            WaitForMessages( 5100 );
         ELSE
            windows.Sleep( 5100 );
         END;

      // check
      FOR i := 1 TO count-2 DO
         IF Counts[i] <> count DIV i THEN
            Failure := TRUE;
            Host^.Log^.LogSC( log.dlcError, L"", L"Failure with index: ", i );
            Host^.Log^.LogSC( log.dlcError, L"", L"  expected: ", count DIV i );
            Host^.Log^.LogSC( log.dlcError, L"", L"  found: ", Counts[i] );
         END;
      END;

      IF Failure THEN
         FirstFailure := TRUE;
         Host^.StopPhaseWithResult( test.trFailure );
      ELSE
         Host^.StopPhaseWithResult( test.trSuccess );
      END;
      Failure := FALSE;

      //==========
      IF CompletionInOwningThread THEN
         Host^.StartPhase( L"10t Abort in reverted order, completed in own thread" );
      ELSE
         Host^.StartPhase( L"10t Abort in reverted order" );
      END;
         // reset, initiate
         FOR i := 1 TO count-2 DO
            Counts[count-i-1] := 0;
         END; // FOR

         IF CompletionInOwningThread THEN
            WaitForMessages( 5100 );
         ELSE
            windows.Sleep( 5100 );
         END;

         // test
         FOR i := count-1 TO 0 BY -1 DO
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
      FOR i := 1 TO count-2 DO
         IF Counts[i] <> count DIV i + 1 THEN // +1 is for Abort
            Failure := TRUE;
            Host^.Log^.LogSC( log.dlcError, L"", L"Failure with index: ", i );
            Host^.Log^.LogSC( log.dlcError, L"", L"  expected: ", count DIV i + 1 );
            Host^.Log^.LogSC( log.dlcError, L"", L"  found: ", Counts[i] );
         END;
      END;

      IF Failure THEN
         Host^.StopPhaseWithResult( test.trFailure );
      ELSE
         Host^.StopPhaseWithResult( test.trSuccess );
      END;

      RETURN FirstFailure OR Failure;
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
   testimpl.tests()^.AddTest( L"ThreadPool::Timeouts", ADR( Test ));
END CTest;

(*===========================================================================*)

END Timeouts.
