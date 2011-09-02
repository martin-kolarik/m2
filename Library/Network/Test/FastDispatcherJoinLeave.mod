MODULE FastDispatcherJoinLeave;

FROM Storage IMPORT
   ALLOCATE, DEALLOCATE;

IMPORT
   inetaddr,
   log,
   netconndispatch,
   netinit,
   netpool,
   netsocket,
   sync,
   test,
   testimpl,
   threadpool,
   SCmsgqueuethread,
   windows;
  
(*===========================================================================*)

CLASS CCI( netconndispatch.CClientInterface );
   PUBLIC VAR
      Connection : netsocket.TPDSocket := NIL;
   LOCAL VIRTUAL PROCEDURE OnJoin( Connection : netconndispatch.TConnectionHandle );
END CCI;

(*---------------------------------------------------------------------------*)

CLASS IMPLEMENTATION CCI;

(*---------------------------------------------------------------------------*)

   LOCAL VIRTUAL PROCEDURE OnJoin( Connection : netconndispatch.TConnectionHandle );
   BEGIN
      SELF.Connection := netsocket.TPDSocket( Connection );
   END OnJoin;

(*---------------------------------------------------------------------------*)

BEGIN
END CCI;

(*===========================================================================*)

TYPE
   TPTest = POINTER TO CTest;

(*---------------------------------------------------------------------------*)

CLASS CTest IMPLEMENTS test.ITest;
   PUBLIC VAR
      Host : test.TPHost := NIL;
      Dispatcher : netconndispatch.TPDispatcher := NIL;

   PUBLIC VIRTUAL PROCEDURE Run( CONST Host : test.TPHost; CONST Parameters : ARRAY OF PWCHAR ) : test.TTestResult;
   PRIVATE PROCEDURE WaitForMessages( count : CARDINAL );
END CTest;

(*===========================================================================*)

VAR
   Test : CTest;

(*---------------------------------------------------------------------------*)

CLASS IMPLEMENTATION CTest;

(*---------------------------------------------------------------------------*)

   PUBLIC VIRTUAL PROCEDURE Run( CONST Host : test.TPHost; CONST Parameters : ARRAY OF PWCHAR ) : test.TTestResult;
   VAR
      ai : inetaddr.INETADDR;
      ci : CCI;
      Failure : BOOLEAN := FALSE;
   BEGIN
      SELF.Host := Host;

      SCmsgqueuethread.Startup();
      threadpool.Startup();
      netinit.Startup();
      
      // global init      
      NEW( Dispatcher );
      Dispatcher^.Init( TRUE );
      ci.BindDispatcher( Dispatcher );
      
      // start
      Host^.StartPhase( L"Client join/connect and immediate leave" );
      
      ai.SetAddressOA( L"191.253.252.251", 6587 );
      ci.Join( ai );
      ci.Connect( NIL );
      // ci.Leave( NIL );

      WaitForMessages( 1000 );

      ci.Connection^.Disconnect( TRUE, 0 );
      Dispatcher^.Dispose();
      DISPOSE( Dispatcher );

      WaitForMessages( 300000 );

      Host^.StopPhaseWithResult( test.trSuccess );
      
      Dispatcher^.Dispose();
      DISPOSE( Dispatcher );

      netinit.Cleanup();
      threadpool.Cleanup();
      SCmsgqueuethread.Cleanup();

      IF Failure THEN
         RETURN test.trFailure;
      ELSE
         RETURN test.trSuccess;
      END;
   END Run;
   
(*---------------------------------------------------------------------------*)

   PRIVATE PROCEDURE WaitForMessages( count : CARDINAL );
   VAR
      i : CARDINAL := count;
      msg : windows.MSG;
   BEGIN
      IF i = 0 THEN
         i := 5; // set
         LOOP
            IF netpool.pool()^.UndeliveredMessagesPending THEN
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
   testimpl.tests()^.AddTest( L"Network::FastDispatcherJoinLeave", ADR( Test ));
END CTest;

(*===========================================================================*)

END FastDispatcherJoinLeave.