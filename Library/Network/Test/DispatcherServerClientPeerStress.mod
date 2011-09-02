MODULE DispatcherServerClientPeerStress;

FROM Storage IMPORT
   ALLOCATE, DEALLOCATE;

IMPORT
   inetaddr,
   log,
   netconndispatch,
   netinit,
   netpool,
   netsocket,
   netsrv,
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
   CONST
      count = 1000000;
   VAR
      a : ADDRESS := NIL;
      ca : inetaddr.INETADDR;
      ci : CCI;
      Failure : BOOLEAN := FALSE;
      i : CARDINAL;
      sa : inetaddr.INETADDR;
   BEGIN
      SELF.Host := Host;
      
      log.logger()^.Level := log.dldDebug;

      SCmsgqueuethread.Startup();
      threadpool.Startup();
      netinit.Startup();
      
      // global init
      NEW( Dispatcher );
      Dispatcher^.Init( TRUE );
      ci.BindDispatcher( Dispatcher );

      ca.SetAddressOA( L"127.0.0.1", 6587 );
      sa.SetAddressOA( L"127.0.0.1", 6586 );
      IF netsrv.StartListen( netsocket.stStream, sa, NIL, Dispatcher^.Listener, 0, NIL ) <> 0 THEN
         ca.SetAddressOA( L"127.0.0.1", 6586 );
         sa.SetAddressOA( L"127.0.0.1", 6587 );
         netsrv.StartListen( netsocket.stStream, sa, NIL, Dispatcher^.Listener, 0, NIL );
         NEW( a );
      END;
      
      a^ := 0;
      
      // start
      Host^.StartPhase( L"Repeated client join/connect and disconnect/leave" );

      FOR i := 0 TO count-1 DO      
         ci.Join( ca );
         ci.Connect( NIL );
         WaitForMessages( 10 );
         ci.Disconnect( NIL );
         ci.Leave( NIL );
      END;

      Host^.StopPhaseWithResult( test.trSuccess );
      
      WaitForMessages( 3000 );

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
   testimpl.tests()^.AddTest( L"Network::DispatcherServerClientPeerStress", ADR( Test ));
END CTest;

(*===========================================================================*)

END DispatcherServerClientPeerStress.