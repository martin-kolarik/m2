MODULE ConnectDisconnect;

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
      ClientSocket : netsocket.TPDSocket;
      Count : CARDINAL;

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
    IF Result = 0 THEN
      sync.IInc( REF Test^.Count );
    END;
  END OnConnect;

(*---------------------------------------------------------------------------*)

  LOCAL VIRTUAL PROCEDURE OnDisconnect( Result : CARDINAL; CONST Socket : netsocket.TPDSocket; Local : BOOLEAN ); 
  BEGIN
    IF Socket <> Test^.ClientSocket THEN
      Socket^.Close( FALSE );
      Socket^.Release();
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
      Failure : BOOLEAN := FALSE;
      lastCount : INTEGER;
   BEGIN
      SELF.Host := Host;
      ServerListener.Test := ADR( SELF );
      ClientListener.Test := ADR( SELF );
      netinit.Startup();

      // global init      
      NEW( ClientSocket );
      ClientSocket^.Notifier := ADR( ClientListener );
      netsrv.StartListen( netsocket.stStream, 4444, NIL, ADR( ServerListener ), 0, NIL );

      Host^.StartPhase( L"Connect/Disconnect on the same socket" );

      // start
      Count := 0;
      ClientSocket^.Connect( L'iris', 4444, windows.INFINITE );
      // wait
      LOOP
         lastCount := sync.IGet( REF Count );
         IF lastCount >= 10000 THEN
            EXIT;
         END;
         WaitForMessages( 2 );
         IF lastCount < sync.IGet( REF Count ) THEN // reconnect
            ClientSocket^.Connect( L'iris', 4444, windows.INFINITE );
         END;
      END; // WHILE

      Host^.StopPhaseWithResult( test.trSuccess );

      ClientSocket^.Release();
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
   testimpl.tests()^.AddTest( L"Network::ConnectDisconnect", ADR( Test ));
END CTest;

(*===========================================================================*)

END ConnectDisconnect.