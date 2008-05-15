MODULE workerdelegate;

FROM Storage IMPORT
   ALLOCATE, DEALLOCATE;

IMPORT
   log,
   msghandler,
   sync,
   test,
   testimpl,
   threadpool,
   windows;
  
(*===========================================================================*)

CONST
   count = 1500;

TYPE
   TPTest = POINTER TO CTest;

(*---------------------------------------------------------------------------*)

CLASS CDelegate( threadpool.APoolDelegate );
   PUBLIC VAR
      Test : TPTest;
      ThreadId : CARDINAL;

   LOCAL VIRTUAL PROCEDURE OnWorker( Result : sync.TAsyncResult; PoolHandle : threadpool.TPoolHandle; UserId : PTR );
END CDelegate;
  
(*---------------------------------------------------------------------------*)

CLASS CWorker( threadpool.APoolWorker );
   PUBLIC VAR
      Delay : CARDINAL;
   LOCAL VIRTUAL PROCEDURE Run();
END CWorker;

(*---------------------------------------------------------------------------*)

CLASS CTest IMPLEMENTS test.ITest;
   PUBLIC VAR
      Host : test.TPHost := NIL;
      Count : CARDINAL := 0;
      Delegate : CDelegate;
      Pool : threadpool.CThreadPool;

   PUBLIC VIRTUAL PROCEDURE Run( CONST Host : test.TPHost; CONST Parameters : ARRAY OF PWCHAR ) : test.TTestResult;
   PRIVATE PROCEDURE Round( CompletionInOwningThread : BOOLEAN ) : BOOLEAN;
   PRIVATE PROCEDURE WaitForMessages( count : CARDINAL );
END CTest;

VAR
   Test : CTest;

(*===========================================================================*)

CLASS IMPLEMENTATION CDelegate;

(*---------------------------------------------------------------------------*)

   LOCAL VIRTUAL PROCEDURE OnWorker( Result : sync.TAsyncResult; PoolHandle : threadpool.TPoolHandle; UserId : PTR );
   BEGIN
      IF ( ThreadId <> 0 ) AND ( ThreadId <> windows.GetCurrentThreadId()) THEN
         Test^.Host^.Log^.LogS( log.dlcError, L"", L"Completion in unexpected thread" );   
      END;
      sync.IInc( REF Test^.Count );
   END OnWorker;

(*---------------------------------------------------------------------------*)

BEGIN
   Test := NIL;
   ThreadId := 0;
END CDelegate;

(*===========================================================================*)

CLASS IMPLEMENTATION CWorker;

(*---------------------------------------------------------------------------*)

  LOCAL VIRTUAL PROCEDURE Run();
  BEGIN
    windows.Sleep( Delay );
  END Run;

(*---------------------------------------------------------------------------*)

BEGIN
  Delay := 0;
END CWorker;

(*===========================================================================*)

CLASS IMPLEMENTATION CTest;

(*---------------------------------------------------------------------------*)

   PUBLIC VIRTUAL PROCEDURE Run( CONST Host : test.TPHost; CONST Parameters : ARRAY OF PWCHAR ) : test.TTestResult;
   VAR
      Failure : BOOLEAN;
   BEGIN
      SELF.Host := Host;
      Delegate.Test := ADR( SELF );

      Failure := Round( FALSE );

      Failure := Round( TRUE ) OR Failure;

      Pool.FINALLY();
      IF Failure THEN
         RETURN test.trFailure;
      ELSE
         RETURN test.trSuccess;
      END;
   END Run;
   
(*---------------------------------------------------------------------------*)

   PRIVATE PROCEDURE Round( CompletionInOwningThread : BOOLEAN ) : BOOLEAN;
   VAR
      Failure : BOOLEAN := FALSE;
      i : CARDINAL;
      lcount : CARDINAL;
      PH : ARRAY [0..count-1] OF windows.HANDLE;
      WA : ARRAY [0..1499] OF CWorker;
   BEGIN
      PH[0] := NIL;

      IF CompletionInOwningThread THEN
         lcount := count DIV 10;
         Pool.CompletionInOwningThread := TRUE;
         Delegate.ThreadId := windows.GetCurrentThreadId();
      ELSE
         lcount := count;
         Pool.CompletionInOwningThread := FALSE;
         Delegate.ThreadId := 0;
      END;

      //==========
      IF CompletionInOwningThread THEN
         Host^.StartPhase( L"0150w, completed in own thread" );
      ELSE
         Host^.StartPhase( L"1500w" );
      END;
         // reset
         Count := 0;
         // initiate
         FOR i := 0 TO lcount-1 DO
            WA[i].Delay := (lcount-i) DIV 10;
            IF NOT Pool.RunWorker( ADR( Delegate ), i, FALSE, ADR( WA[i] ), FALSE, OUT PH[i] ) THEN
               Host^.Log^.LogSC( log.dlcError, L"", L"Unable to run worker of index: ", i );
               INC( Count ); // force failure reporting
            END;
         END; // FOR

         // test
         i := 100;
         WHILE sync.IGet( REF Count ) < INTEGER( lcount ) DO
            IF CompletionInOwningThread THEN
               WaitForMessages( 300 );
            ELSE
               windows.Sleep( 500 );
            END;
            DEC( i );
            IF i = 0 THEN
               EXIT;
            END;
         END; // WHILE

      // check
      IF Count = lcount THEN
         Host^.StopPhaseWithResult( test.trSuccess );
      ELSE
         Host^.StopPhaseWithResult( test.trFailure );
         Failure := TRUE;
      END;

      //==========
      IF CompletionInOwningThread THEN
         Host^.StartPhase( L"0150w Abort in reverted order, completed in own thread" );
      ELSE
         Host^.StartPhase( L"1500w Abort in reverted order" );
      END;
         // reset
         Count := 0;
         // initiate
         FOR i := 0 TO lcount-1 DO
            WA[i].Delay := (lcount-i) DIV 10;
            IF NOT Pool.RunWorker( ADR( Delegate ), i, FALSE, ADR( WA[i] ), FALSE, OUT PH[i] ) THEN
               Host^.Log^.LogSC( log.dlcError, L"", L"Unable to start wait for index: ", i );
               INC( Count ); // force failure reporting
            END;
         END; // FOR
         windows.Sleep( 2500 );

         // test
         FOR i := lcount-1 TO 0 BY -1 DO
            Pool.Abort( REF PH[i] );
            IF CompletionInOwningThread THEN
               WaitForMessages( 5 );
            END;
         END; // FOR

         i := 20;
         WHILE sync.IGet( REF Count ) < INTEGER( lcount ) DO
            IF CompletionInOwningThread THEN
               WaitForMessages( 300 );
            ELSE
               windows.Sleep( 500 );
            END;
            DEC( i );
            IF i = 0 THEN
               EXIT;
            END;
         END; // WHILE

      // check
      IF Count = lcount THEN
         Host^.StopPhaseWithResult( test.trSuccess );
      ELSE
         Host^.StopPhaseWithResult( test.trFailure );
         Failure := TRUE;
      END;

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
            IF Pool.UndeliveredMessagesPending THEN
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
   testimpl.tests()^.AddTest( L"ThreadPool::WorkerDelegate", ADR( Test ));
END CTest;

(*===========================================================================*)

END workerdelegate.
