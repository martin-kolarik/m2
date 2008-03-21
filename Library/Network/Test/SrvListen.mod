MODULE SrvListen;

IMPORT
   winsock;

FROM Storage IMPORT
   ALLOCATE, DEALLOCATE;

IMPORT
   log,
   netinit,
   netpool,
   netsocket,
   netsrv,
   sync,
   test,
   testimpl,
   windows;
  
(*===========================================================================*)

TYPE
   TPTest = POINTER TO CTest;

(*---------------------------------------------------------------------------*)

CLASS CListener( netsrv.AListener );
   PUBLIC VAR
      Test : TPTest;
   LOCAL VIRTUAL PROCEDURE OnListenSocketClosed( CONST ServerSocket : netsocket.TPSSocket );
END CListener;

(*---------------------------------------------------------------------------*)

CLASS CTest IMPLEMENTS test.ITest;
   PUBLIC VAR
      Host : test.TPHost := NIL;
      Listener : CListener;
      Count : CARDINAL;

   PUBLIC VIRTUAL PROCEDURE Run( CONST Host : test.TPHost; CONST Parameters : ARRAY OF PWCHAR ) : test.TTestResult;
   PRIVATE PROCEDURE WaitForMessages( count : CARDINAL );
END CTest;

(*===========================================================================*)

CLASS IMPLEMENTATION CListener;

(*---------------------------------------------------------------------------*)

   LOCAL VIRTUAL PROCEDURE OnListenSocketClosed( CONST ServerSocket : netsocket.TPSSocket );
   BEGIN
      sync.IInc( REF Test^.Count );
   END OnListenSocketClosed;

(*---------------------------------------------------------------------------*)

END CListener;

(*===========================================================================*)

VAR
   Test : CTest;

(*---------------------------------------------------------------------------*)

CLASS IMPLEMENTATION CTest;

(*---------------------------------------------------------------------------*)

   PUBLIC VIRTUAL PROCEDURE Run( CONST Host : test.TPHost; CONST Parameters : ARRAY OF PWCHAR ) : test.TTestResult;
   VAR
      Failure : BOOLEAN;
      S : netsocket.TPSSocket;
   BEGIN
      SELF.Host := Host;
      Listener.Test := ADR( SELF );
      netinit.Startup();

      Host^.StartPhase( L"Listen and stop listen -- pooled notification" );
      // init
      netsrv.SetCallbackMode( netsrv.cbmPooled );
      Count := 0;
      // run
      netsrv.StartListen( netsocket.stStream, 4444, NIL, ADR( Listener ), 0, NIL );
      netsrv.StartListen( netsocket.stDatagram, 4444, NIL, ADR( Listener ), 0, ADR( S ));
      netsrv.StopListenSocket( REF S );
      netsrv.StopListenPort( netsocket.stStream, 4444 );
      netsrv.StartListen( netsocket.stStream, 4445, NIL, ADR( Listener ), 500, ADR( S ));
      // wait
      WaitForMessages( 550 );
      // check
      IF Count = 3 THEN
         Host^.StopPhaseWithResult( test.trSuccess );
      ELSE
         Failure := TRUE;
         Host^.StopPhaseWithResult( test.trFailure );
      END;

      Host^.StartPhase( L"Listen and stop listen -- main thread notification" );
      // init
      netsrv.SetCallbackMode( netsrv.cbmMainThread );
      Count := 0;
      // run
      netsrv.StartListen( netsocket.stStream, 4444, NIL, ADR( Listener ), 0, NIL );
      netsrv.StartListen( netsocket.stDatagram, 4444, NIL, ADR( Listener ), 0, ADR( S ));
      netsrv.StopListenSocket( REF S );
      netsrv.StopListenPort( netsocket.stStream, 4444 );
      netsrv.StartListen( netsocket.stStream, 4445, NIL, ADR( Listener ), 500, ADR( S ));
      // wait
      WaitForMessages( 550 );
      // check
      IF Count = 3 THEN
         Host^.StopPhaseWithResult( test.trSuccess );
      ELSE
         Failure := TRUE;
         Host^.StopPhaseWithResult( test.trFailure );
      END;

      netinit.Cleanup();
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
            IF netpool.Pool()^.UndeliveredMessagesPending THEN
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
   testimpl.tests()^.AddTest( L"Network::NetSrvListen", ADR( Test ));
END CTest;

(*===========================================================================*)

END SrvListen.
