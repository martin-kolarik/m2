MODULE MessageDelegate;

FROM Storage IMPORT
   ALLOCATE, DEALLOCATE, Zero;

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
   LIMIT = 1500;

TYPE
   TPTest = POINTER TO CTest;

(*---------------------------------------------------------------------------*)

CLASS CDelegate( threadpool.APoolDelegate );
   PUBLIC VAR
      Test : TPTest;
      CheckThread : BOOLEAN;

   LOCAL VIRTUAL PROCEDURE OnMessage( Result : sync.TAsyncResult; PoolHandle : threadpool.TPoolHandle; UserId : PTR; CONST MSG : msghandler.IMessage );
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
   PRIVATE PROCEDURE Round( CompletionInOwningThread : BOOLEAN ) : BOOLEAN;
   PRIVATE PROCEDURE WaitForMessages( count : CARDINAL );
END CTest;

(*---------------------------------------------------------------------------*)

VAR
   Test : CTest;

(*===========================================================================*)

CLASS IMPLEMENTATION CDelegate;

(*---------------------------------------------------------------------------*)

   LOCAL VIRTUAL PROCEDURE OnMessage( Result : sync.TAsyncResult; PoolHandle : threadpool.TPoolHandle; UserId : PTR; CONST MSG : msghandler.IMessage );
   BEGIN
      IF CheckThread AND NOT msgqueuethread.global()^.SelfContext THEN
         Test^.Host^.Log^.LogS( log.lcError, 0, L"", L"Completion in unexpected thread" );   
      END;
      sync.IInc( REF Test^.Count );
   END OnMessage;

(*---------------------------------------------------------------------------*)

BEGIN
   Test := NIL;
   CheckThread := FALSE;
END CDelegate;

(*===========================================================================*)

CLASS CMessages;
   PRIVATE VAR
      _Messages : ARRAY [0..LIMIT-1] OF msghandler.Message;
   PUBLIC READONLY
      INDEX( Index : INTEGER ) : msghandler.TPIMessage;
END CMessages;

(*---------------------------------------------------------------------------*)

CLASS IMPLEMENTATION CMessages;

(*---------------------------------------------------------------------------*)

   PUBLIC INDEX CMessages GET( Index : INTEGER ) : msghandler.TPIMessage;
   BEGIN
      RETURN ADR( _Messages[ Index ] );
   END CMessages;

(*---------------------------------------------------------------------------*)

BEGIN
   _Messages[0].Message := 0;
END CMessages;

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
      ELSE
         Limit := LIMIT;
      END;

      Failure := Round( FALSE );

      Failure := Round( TRUE ) OR Failure;

      windows.Sleep( 100 );
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
      MH : ARRAY [0..LIMIT-1] OF msghandler.TPIMessageTarget;
      MSGS : POINTER TO CMessages := NEW( CMessages );
      Failure : BOOLEAN := FALSE;
      i : CARDINAL;
      lcount : CARDINAL;
      PH : ARRAY [0..LIMIT-1] OF windows.HANDLE;
   BEGIN
      PH[0] := NIL;

      IF CompletionInOwningThread THEN
         lcount := Limit DIV 5;
         Pool^.CompletionInOwningThread := TRUE;
         Delegate.CheckThread := TRUE;
      ELSE
         lcount := Limit;
         Pool^.CompletionInOwningThread := FALSE;
         Delegate.CheckThread := FALSE;
      END;

      //==========
      IF CompletionInOwningThread THEN
         Host^.StartPhase( L"0300m Post in reverted order, completed in own thread" );
      ELSE
         Host^.StartPhase( L"1500m Post in reverted order" );
      END;
         // reset
         Count := 0;
         // initiate
         FOR i := 0 TO lcount-1 DO
            IF NOT Pool^.WaitMessage( ADR( Delegate ), i, windows.INFINITE, TRUE, FALSE, OUT MH[i], OUT MSGS^[i]^, OUT PH[i] ) THEN
               Host^.Log^.LogSC( log.lcError, 0, L"", L"Unable to start wait for index: ", i );
               INC( Count ); // force failure reporting
            END;
         END; // FOR

         // test
         FOR i := lcount-1 TO 0 BY -1 DO
            MH[i]^.Message( MSGS^[i]^, msghandler.delAsynchronous, NIL );
            IF CompletionInOwningThread THEN
               WaitForMessages( 5 );
            END;
         END; // FOR
         IF CompletionInOwningThread THEN
            WaitForMessages( 0 );
         ELSE
            windows.Sleep( 100 );
         END;

      // check
      Host^.StopPhaseWithResult( Count = lcount );

      //==========
      IF CompletionInOwningThread THEN
         Host^.StartPhase( L"0300m Abort in reverted order, completed in own thread" );
      ELSE
         Host^.StartPhase( L"1500m Abort in reverted order" );
      END;
         // reset
         Count := 0;
         // initiate
         FOR i := 0 TO lcount-1 DO
            IF NOT Pool^.WaitMessage( ADR( Delegate ), i, windows.INFINITE, TRUE, FALSE, OUT MH[i], OUT MSGS^[i]^, OUT PH[i] ) THEN
               Host^.Log^.LogSC( log.lcError, 0, L"", L"Unable to start wait for index: ", i );
               INC( Count ); // force failure reporting
            END;
         END; // FOR
         windows.Sleep( 250 );

         // test
         FOR i := lcount-1 TO 0 BY -1 DO
            Pool^.Abort( REF PH[i] );
            IF CompletionInOwningThread THEN
               WaitForMessages( 5 );
            END;
         END; // FOR
         IF CompletionInOwningThread THEN
            WaitForMessages( 0 );
         ELSE
            windows.Sleep( 100 );
         END;

      // check
      Host^.StopPhaseWithResult( Count = lcount );

      DISPOSE( MSGS );

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
   testimpl.tests()^.AddTest( L"ThreadPool::MessageDelegate", ADR( Test ));
END CTest;

(*===========================================================================*)

END MessageDelegate.
