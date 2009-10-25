MODULE EventDelegate;

FROM Storage IMPORT
   ALLOCATE, DEALLOCATE;

IMPORT
   log,
   msgqueuethread,
   sync,
   test,
   testimpl,
   threadinit,
   threadpool,
   windows;
  
(*===========================================================================*)

CONST
   LIMIT = 1500;

TYPE
   TPTest = POINTER TO CTest;

(*---------------------------------------------------------------------------*)

CLASS CDelegate( threadpool.APoolDelegate );
   PUBLIC VAR
      Test : TPTest;
      CheckThread : BOOLEAN;

   LOCAL VIRTUAL PROCEDURE OnHandle( Result : sync.TAsyncResult; PoolHandle : threadpool.TPoolHandle; UserId : PTR );
END CDelegate;
  
(*---------------------------------------------------------------------------*)

CLASS CTest IMPLEMENTS test.ITest;
   PUBLIC VAR
      Host : test.TPHost := NIL;
      Count : CARDINAL := 0;
      Delegate : CDelegate;
      Pool : threadpool.TPThreadPool;
      Limit : CARDINAL := 0;

   PUBLIC VIRTUAL PROCEDURE Run( CONST Host : test.TPHost; CONST Parameters : ARRAY OF PWCHAR ) : test.TTestResult;
   PRIVATE PROCEDURE Round( CompletionInOwningThread : BOOLEAN; CONST EA : ARRAY OF windows.HANDLE; REF PH : ARRAY OF threadpool.TPoolHandle ) : BOOLEAN;
   PRIVATE PROCEDURE WaitForMessages( count : CARDINAL );
END CTest;

(*---------------------------------------------------------------------------*)

VAR
   Test : CTest;

(*===========================================================================*)

CLASS IMPLEMENTATION CDelegate;

(*---------------------------------------------------------------------------*)

   LOCAL VIRTUAL PROCEDURE OnHandle( Result : sync.TAsyncResult; PoolHandle : threadpool.TPoolHandle; UserId : PTR );
   BEGIN
      IF CheckThread AND NOT msgqueuethread.global()^.SelfContext THEN
         Test^.Host^.Log^.LogS( log.dlcError, L"", L"Completion in unexpected thread" );   
      END;
      sync.IInc( REF Test^.Count );
   END OnHandle;

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
      EA : ARRAY [0..LIMIT-1] OF windows.HANDLE;
      Failure : BOOLEAN;
      i : CARDINAL;
      PH : ARRAY [0..10*LIMIT-1] OF windows.HANDLE;
   BEGIN
      threadinit.Startup();
      NEW( Pool );
      
      PH[0] := NIL;
      SELF.Host := Host;
      Delegate.Test := ADR( SELF );

      IF Host^.FastEvaluation THEN
         Limit := LIMIT DIV 10;
      ELSE
         Limit := LIMIT;
      END;

      // create handles
      FOR i := 0 TO Limit-1 DO
         EA[i] := windows.CreateEvent( NIL, windows.True, windows.False, NIL );
      END; // FOR
      
      Failure := Round( FALSE, EA, REF PH );

      Failure := Round( TRUE, EA, REF PH ) OR Failure;

      // done handles
      FOR i := 0 TO Limit-1 DO
          windows.CloseHandle( EA[i] );
      END; // FOR
   
      DISPOSE( Pool );
      threadinit.Cleanup();

      IF Failure THEN
         RETURN test.trFailure;
      ELSE
         RETURN test.trSuccess;
      END;
   END Run;
   
(*---------------------------------------------------------------------------*)

   PRIVATE PROCEDURE Round( CompletionInOwningThread : BOOLEAN; CONST EA : ARRAY OF windows.HANDLE; REF PH : ARRAY OF threadpool.TPoolHandle ) : BOOLEAN;
   VAR
      Failure : BOOLEAN := FALSE;
      i, j : CARDINAL;
      lcount : CARDINAL;
   BEGIN
      IF CompletionInOwningThread THEN
         lcount := Limit DIV 10;
         Pool^.CompletionInOwningThread := TRUE;
         Delegate.CheckThread := TRUE;
      ELSE
         lcount := Limit;
         Pool^.CompletionInOwningThread := FALSE;
         Delegate.CheckThread := FALSE;
      END;

      //==========
      IF CompletionInOwningThread THEN
         Host^.StartPhase( L"150e/01x SetEvent in reverted order, completed in own thread" );
      ELSE
         Host^.StartPhase( L"1500e/01x SetEvent in reverted order" );
      END;
         // reset
         Count := 0;
         // initiate
         FOR i := 0 TO lcount-1 DO
            IF NOT Pool^.WaitHandle( ADR( Delegate ), i, windows.INFINITE, TRUE, FALSE, EA[i], OUT PH[i] ) THEN
               Host^.Log^.LogSC( log.dlcError, L"", L"Unable to start wait for index: ", i );
               INC( Count ); // force failure reporting
            END;
         END; // FOR

         // test
         FOR i := lcount-1 TO 0 BY -1 DO
            windows.SetEvent( EA[i] );
            IF CompletionInOwningThread THEN
               WaitForMessages( 2 );
            END;
         END; // FOR
         IF CompletionInOwningThread THEN
            WaitForMessages( 0 );
         ELSE
            windows.Sleep( 100 );
         END;

      // check
      IF Count = lcount THEN
         Host^.StopPhaseWithResult( test.trSuccess );
      ELSE
         Host^.StopPhaseWithResult( test.trFailure );
         Failure := TRUE;
      END;

      //==========
      IF CompletionInOwningThread THEN
         Host^.StartPhase( L"150e/01x Abort in reverted order, completed in own thread" );
      ELSE
         Host^.StartPhase( L"1500e/01x Abort in reverted order" );
      END;
         // reset
         Count := 0;
         FOR i := 0 TO lcount-1 DO
            windows.ResetEvent( EA[i] );
         END; // FOR
         // initiate
         FOR i := 0 TO lcount-1 DO
            IF NOT Pool^.WaitHandle( ADR( Delegate ), i, windows.INFINITE, TRUE, FALSE, EA[i], OUT PH[i] ) THEN
               Host^.Log^.LogSC( log.dlcError, L"", L"Unable to start wait for index: ", i );
               INC( Count ); // force failure reporting
            END;
         END; // FOR
         windows.Sleep( 250 );

         // test
         FOR i := lcount-1 TO 0 BY -1 DO
            Pool^.Abort( REF PH[i] );
            IF CompletionInOwningThread THEN
               WaitForMessages( 2 );
            END;
         END; // FOR
         IF CompletionInOwningThread THEN
            WaitForMessages( 0 );
         ELSE
            windows.Sleep( 100 );
         END;

      // check
      IF Count = lcount THEN
         Host^.StopPhaseWithResult( test.trSuccess );
      ELSE
         Host^.StopPhaseWithResult( test.trFailure );
         Failure := TRUE;
      END;

      //==========
      IF CompletionInOwningThread THEN
         Host^.StartPhase( L"150e/10x SetEvent in reverted order, completed in own thread" );
      ELSE
         Host^.StartPhase( L"1500e/10x SetEvent in reverted order" );
      END;
         // reset
         Count := 0;
         FOR i := 0 TO lcount-1 DO
            windows.ResetEvent( EA[i] );
         END; // FOR
         // initiate
         FOR i := 0 TO lcount-1 DO
            FOR j := 0 TO 10-1 DO
               IF NOT Pool^.WaitHandle( ADR( Delegate ), i, windows.INFINITE, TRUE, FALSE, EA[i], OUT PH[i*10+j] ) THEN
                  Host^.Log^.LogSC( log.dlcError, L"", L"Unable to start wait for index: ", i*10+j );
                  INC( Count ); // force failure reporting
               END;
            END; // FOR
         END; // FOR

         // test
         FOR i := lcount-1 TO 0 BY -1 DO
            windows.SetEvent( EA[i] );
            IF CompletionInOwningThread THEN
               WaitForMessages( 2 );
            END;
         END; // FOR
         IF CompletionInOwningThread THEN
            WaitForMessages( 0 );
         ELSE
            windows.Sleep( 100 );
         END;

      // check
      IF Count = 10*lcount THEN
         Host^.StopPhaseWithResult( test.trSuccess );
      ELSE
         Host^.StopPhaseWithResult( test.trFailure );
         Failure := TRUE;
      END;

      //==========
      IF CompletionInOwningThread THEN
         Host^.StartPhase( L"150e/10x Abort in reverted order, completed in own thread" );
      ELSE
         Host^.StartPhase( L"1500e/10x Abort in reverted order" );
      END;
         // reset
         Count := 0;
         FOR i := 0 TO lcount-1 DO
            windows.ResetEvent( EA[i] );
         END; // FOR
         // initiate
         FOR i := 0 TO lcount-1 DO
            FOR j := 0 TO 10-1 DO
               IF NOT Pool^.WaitHandle( ADR( Delegate ), i, windows.INFINITE, TRUE, FALSE, EA[i], OUT PH[i*10+j] ) THEN
                  Host^.Log^.LogSC( log.dlcError, L"", L"Unable to start wait for index: ", i*10+j );
                  INC( Count ); // force failure reporting
               END;
            END; // FOR
         END; // FOR
         windows.Sleep( 250 );

         // test
         FOR i := 10*lcount-1 TO 0 BY -1 DO
            Pool^.Abort( REF PH[i] );
            IF CompletionInOwningThread THEN
               WaitForMessages( 2 );
            END;
         END; // FOR
         IF CompletionInOwningThread THEN
            WaitForMessages( 0 );
         ELSE
            windows.Sleep( 100 );
         END;

      // check
      IF Count = 10*lcount THEN
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
   testimpl.tests()^.AddTest( L"ThreadPool::EventDelegate", ADR( Test ));
END CTest;

(*===========================================================================*)

END EventDelegate.
