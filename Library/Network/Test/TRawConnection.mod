MODULE TRawConnection;

FROM Storage IMPORT
   ALLOCATE, DEALLOCATE;

IMPORT
   inetaddr,
   log,
   netinit,
   netpool,
   netsocket,
   netsrv,
   rawconnection,
   sync,
   test,
   testimpl,
   threadpool,
   SCmsgqueuethread,
   windows;
  
(*===========================================================================*)

CONST
   LIMIT = 1000;

(*---------------------------------------------------------------------------*)

TYPE
   TPTest = POINTER TO CTest;

(*---------------------------------------------------------------------------*)

CLASS CServerListener( netsrv.AListener );
   PUBLIC VAR
      Test : TPTest;
   LOCAL VIRTUAL PROCEDURE OnListen( CONST ServerSocket : netsocket.TPSSocket );
END CServerListener;

(*---------------------------------------------------------------------------*)

CLASS CClientListener( netsocket.ASocketNotifier );
   PUBLIC VAR
      Test : TPTest;
  LOCAL VIRTUAL PROCEDURE OnConnect( Result : CARDINAL; CONST Socket : netsocket.TPDSocket; Local : BOOLEAN ); 
  LOCAL VIRTUAL PROCEDURE OnDisconnect( Result : CARDINAL; CONST Socket : netsocket.TPDSocket; Local : BOOLEAN ); 
END CClientListener;

(*---------------------------------------------------------------------------*)

CLASS CTest IMPLEMENTS test.ITest;
   PUBLIC VAR
      Host : test.TPHost := NIL;
      ServerListener : CServerListener;
      ClientListener : CClientListener;
      ClientConnection : rawconnection.TPClientTCPConnection := NIL;
      ClientCount : CARDINAL := 0;
      ServerCount : CARDINAL := 0;
      Limit : INTEGER := 0;

   PUBLIC VIRTUAL PROCEDURE Run( CONST Host : test.TPHost; CONST Parameters : ARRAY OF PWCHAR ) : test.TTestResult;
   PRIVATE PROCEDURE WaitForMessages( count : CARDINAL );
END CTest;

(*===========================================================================*)

CLASS IMPLEMENTATION CServerListener;

(*---------------------------------------------------------------------------*)

   LOCAL VIRTUAL PROCEDURE OnListen( CONST ServerSocket : netsocket.TPSSocket );
   VAR
      DS : netsocket.TPDSocket;
      Error : CARDINAL;
   BEGIN
      NEW( DS );
      DS^.AddRef();
      DS^.Notifier := ADR( Test^.ClientListener );
      DS^.Accept( ServerSocket, OUT Error );
      DS^.Release(); // prevent Release made during OnDisconnect when Accept is pending
   END OnListen;

(*---------------------------------------------------------------------------*)

BEGIN
   Test := NIL;
END CServerListener;

(*===========================================================================*)

CLASS IMPLEMENTATION CClientListener;

(*---------------------------------------------------------------------------*)

  LOCAL VIRTUAL PROCEDURE OnConnect( Result : CARDINAL; CONST Socket : netsocket.TPDSocket; Local : BOOLEAN ); 
  BEGIN
    IF Socket = NIL THEN
      sync.IInc( REF Test^.ClientCount );
      IF Result <> 0 THEN
        sync.IInc( REF Test^.ServerCount );
      END;
    ELSE
      sync.IInc( REF Test^.ServerCount );
    END;
  END OnConnect;

(*---------------------------------------------------------------------------*)

  LOCAL VIRTUAL PROCEDURE OnDisconnect( Result : CARDINAL; CONST Socket : netsocket.TPDSocket; Local : BOOLEAN ); 
  BEGIN
    IF Socket = NIL THEN
      // client is not released
    ELSE
      Socket^.Disconnect( FALSE, netsocket.FORSAFETY );
      sync.Sleep( 0 );
      Socket^.Release(); // release server socket
    END;
  END OnDisconnect;

(*---------------------------------------------------------------------------*)

BEGIN
   Test := NIL;
END CClientListener;

(*===========================================================================*)

VAR
   Test : CTest;

(*---------------------------------------------------------------------------*)

CLASS IMPLEMENTATION CTest;

(*---------------------------------------------------------------------------*)

   PUBLIC VIRTUAL PROCEDURE Run( CONST Host : test.TPHost; CONST Parameters : ARRAY OF PWCHAR ) : test.TTestResult;
   VAR
      ai : inetaddr.INETADDR;
      Failure : BOOLEAN := FALSE;
      lastCount : INTEGER;
   BEGIN
      SELF.Host := Host;
      ServerListener.Test := ADR( SELF );
      ClientListener.Test := ADR( SELF );
      
      IF Host^.FastEvaluation THEN
         Limit := LIMIT DIV 20;
      ELSE
         Limit := LIMIT;
      END;

      SCmsgqueuethread.Startup();
      threadpool.Startup();
      netinit.Startup();

      // global init      
      NEW( ClientConnection );
      ClientConnection^.Notifier := ADR( ClientListener );

      ai.Port := 4444;
      netsrv.StartListen( netsocket.stStream, ai, NIL, ADR( ServerListener ), 0, NIL );
      ai.V6 := TRUE;
      netsrv.StartListen( netsocket.stStream, ai, NIL, ADR( ServerListener ), 0, NIL );

      Host^.StartPhase( L"Connect/Disconnect on the same connection" );

      // start
      ClientCount := 0;
      ServerCount := 0;
      lastCount := 0;
      ClientConnection^.Open( L'iris:4444', 0, FALSE, sync.FORSAFETY );
      // wait
      LOOP
         IF lastCount >= Limit THEN
            EXIT;
         END;
         WaitForMessages( 10 );
         IF ( lastCount < sync.IGet( REF ClientCount )) AND ( lastCount < sync.IGet( REF ServerCount )) THEN // reconnect
            lastCount := sync.IGet( REF ClientCount );
            IF ClientConnection^.Open( L'iris:4444', 0, FALSE, sync.FORSAFETY ) = sync.arCannotStart THEN
               // this is returned if connection cannot start connecting due to pending disconnect
               Host^.Log^.LogS( log.lcError, 0, L"", L"Unexpected connection Open result" );   
               DEC( lastCount ); // force repeat Open
            END;
         END;
      END; // WHILE

      Host^.StopPhaseWithResult( test.trSuccess );

      ClientConnection^.Close();
      DISPOSE( ClientConnection );

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
   testimpl.tests()^.AddTest( L"Network::TCPConnection", ADR( Test ));
END CTest;

(*===========================================================================*)

END TRawConnection.