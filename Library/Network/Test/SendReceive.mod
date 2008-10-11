MODULE SendReceive;

FROM Storage IMPORT
   ALLOCATE, DEALLOCATE;

IMPORT
   IOO,
   inetaddr,
   log,
   netinit,
   netpool,
   netsocket,
   netsrv,
   IOO,
   sync,
   test,
   testimpl,
   threadpool,
   SCmsgqueuethread,
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

CLASS CReader( IOO.CMemoryProxy );
   PUBLIC VAR
      DetectPrevious : BOOLEAN;
      PrevCount : INTEGER := 0;
      Summa : CARD64 := 0;
      Test : TPTest;
   PUBLIC VIRTUAL PROCEDURE CompleteData( Completed : CARDINAL );
END CReader;

(*---------------------------------------------------------------------------*)

CLASS CWriter( IOO.CMemoryProxy );
   PUBLIC VAR
      Summa : CARD64 := 0;
      Test : TPTest;
   PUBLIC VIRTUAL PROCEDURE CompleteData( Completed : CARDINAL );
END CWriter;

(*---------------------------------------------------------------------------*)

CLASS CTest IMPLEMENTS test.ITest;
   PUBLIC VAR
      Host : test.TPHost := NIL;
      ServerListener : CServerListener;
      ServerSocket : netsocket.DSocket;
      
      Reader : CReader;
      Writer : CWriter;
      
   PUBLIC VIRTUAL PROCEDURE Run( CONST Host : test.TPHost; CONST Parameters : ARRAY OF PWCHAR ) : test.TTestResult;
   PRIVATE PROCEDURE WaitForMessages( count : CARDINAL );
END CTest;

(*===========================================================================*)

CLASS IMPLEMENTATION CServerListener;

(*---------------------------------------------------------------------------*)

   LOCAL VIRTUAL PROCEDURE OnListen( CONST ServerSocket : netsocket.TPSSocket );
   VAR
      Error : CARDINAL;
   BEGIN
      Test^.ServerSocket.Accept( ServerSocket, OUT Error );
      Test^.ServerSocket.Receive( ADR( Test^.Reader ), windows.INFINITE, FALSE );
   END OnListen;

(*---------------------------------------------------------------------------*)

BEGIN
   Test := NIL;
END CServerListener;

(*===========================================================================*)

CLASS IMPLEMENTATION CReader;

(*---------------------------------------------------------------------------*)

  PUBLIC VIRTUAL PROCEDURE CompleteData( Completed : CARDINAL );
  BEGIN
    INC( Summa, Completed );
    SUPER.CompleteData( Completed );
    _Ptr := 0; // reset reading

    IF DetectPrevious AND ( PINTEGER( _Data )^ <> PrevCount+1 ) THEN
       Test^.Host^.Log^.LogSC( log.dlcError, L"", L"Failed: ", PCARDINAL( _Data )^ );
    END;
    INC( PrevCount );
  END CompleteData;

(*---------------------------------------------------------------------------*)

BEGIN
   Test := NIL;
   DetectPrevious := FALSE;
END CReader;
  
(*===========================================================================*)

CLASS IMPLEMENTATION CWriter;

(*---------------------------------------------------------------------------*)

  PUBLIC VIRTUAL PROCEDURE CompleteData( Completed : CARDINAL );
  BEGIN
    INC( Summa, Completed );
    SUPER.CompleteData( Completed );
  END CompleteData;

(*---------------------------------------------------------------------------*)

BEGIN
   Test := NIL;
END CWriter;
  
(*===========================================================================*)

VAR
   Test : CTest;

(*---------------------------------------------------------------------------*)

CLASS IMPLEMENTATION CTest;

(*---------------------------------------------------------------------------*)

   PUBLIC VIRTUAL PROCEDURE Run( CONST Host : test.TPHost; CONST Parameters : ARRAY OF PWCHAR ) : test.TTestResult;
   VAR
      ai : inetaddr.INETADDR;
      Buffer : ARRAY [0..1023] OF BYTE;
      ClientSocket : netsocket.DSocket;
      Count : INTEGER;
      Failure : BOOLEAN := FALSE;
   BEGIN
      SELF.Host := Host;
      ServerListener.Test := ADR( SELF );
      Reader.Test := ADR( SELF );
      Writer.Test := ADR( SELF );

      SCmsgqueuethread.Startup();
      threadpool.Startup();
      netinit.Startup();

      // global init      
      Reader.Init( ADR( Buffer ), SIZE( CARDINAL ), FALSE );
      netsrv.SetCallbackMode( IOO.cbmPooled );
      
      ai.V6 := TRUE;
      ai.Port := 4444;
      netsrv.StartListen( netsocket.stStream, ai, NIL, ADR( ServerListener ), 0, NIL );

      //=====

      Host^.StartPhase( L"Socket, 100000 * 4 bytes, WAIT" );
      Reader.DetectPrevious := TRUE;
      Reader.PrevCount := 0;
      Reader.Summa := 0;
      
      // start
      ClientSocket.Waitable := TRUE;
      ai.SetV6( inetaddr.saLoopback );
      ai.Port := 4444;
      ClientSocket.ConnectAddress( ai, windows.INFINITE );
      ClientSocket.WaitCompletion( windows.INFINITE );
  
      // run
      Count := 1; // must start from 1, it is due to comparsion with PrevCount in receiver
      LOOP
         Writer.Init( ADR( Count ), SIZE( Count ), FALSE );
         IF ClientSocket.Send( ADR( Writer ), windows.INFINITE, TRUE ) = sync.arCompleted THEN
            INC( Count );
          END;
          IF Count = 100000 THEN
            EXIT;
          END;
      END; // LOOP

      // flush receiving
      WaitForMessages( 50 );
      ServerSocket.AbortReceive();
      ClientSocket.Disconnect( FALSE, windows.INFINITE );
      // flush disconnect
      WaitForMessages( 250 );
      
      // check
      IF Count <> Reader.PrevCount+1 THEN
         Failure := TRUE;
         Host^.StopPhaseWithResult( test.trFailure );
      ELSE
         Host^.StopPhaseWithResult( test.trSuccess );
      END;

      //=====

      Host^.StartPhase( L"Socket, 100000 * 4 bytes, POLL" );
      Reader.DetectPrevious := TRUE;
      Reader.PrevCount := 0;
      Reader.Summa := 0;
      
      // start
      ClientSocket.Waitable := TRUE;
      ClientSocket.ConnectAddress( ai, windows.INFINITE );
      ClientSocket.WaitCompletion( windows.INFINITE );
  
      // run
      Count := 0; // must start from 0, it is due to comparsion with PrevCount in receiver, but here is Count incremented before send
      LOOP
         IF ( Count = 0 ) OR Writer.Completed THEN
            INC( Count );
            IF Count = 100000 THEN
              EXIT;
            END;

            Writer.Init( ADR( Count ), SIZE( Count ), FALSE );
            ClientSocket.Send( ADR( Writer ), windows.INFINITE, FALSE );
         END;
      END; // LOOP

      // flush receiving
      WaitForMessages( 50 );
      ServerSocket.AbortReceive();
      ClientSocket.Disconnect( FALSE, windows.INFINITE );
      // flush disconnect
      WaitForMessages( 250 );
      
      // check
      IF Count <> Reader.PrevCount+1 THEN
         Failure := TRUE;
         Host^.StopPhaseWithResult( test.trFailure );
      ELSE
         Host^.StopPhaseWithResult( test.trSuccess );
      END;

      //=====

      // global
      Reader.Init( ADR( Buffer ), SIZE( Buffer ), FALSE );

      Host^.StartPhase( L"Socket, 100000 * 1024 bytes, WAIT" );
      Reader.DetectPrevious := FALSE;
      Reader.PrevCount := 0;
      Reader.Summa := 0;
      Writer.Summa := 0;
      
      // start
      ClientSocket.Waitable := TRUE;
      ClientSocket.ConnectAddress( ai, windows.INFINITE );
      ClientSocket.WaitCompletion( windows.INFINITE );
  
      // run
      Count := 1; // must start from 1, it is due to comparsion with PrevCount in receiver
      LOOP
         Writer.Init( ADR( Buffer ), SIZE( Buffer ), FALSE );
         IF ClientSocket.Send( ADR( Writer ), windows.INFINITE, TRUE ) = sync.arCompleted THEN
            INC( Count );
          END;
          IF Count = 100000 THEN
            EXIT;
          END;
      END; // LOOP

      // flush receiving
      WaitForMessages( 50 );
      ServerSocket.AbortReceive();
      ClientSocket.Disconnect( FALSE, windows.INFINITE );
      // flush disconnect
      WaitForMessages( 250 );
      
      // check
      IF Writer.Summa <> Reader.Summa THEN
         Failure := TRUE;
         Host^.StopPhaseWithResult( test.trFailure );
      ELSE
         Host^.StopPhaseWithResult( test.trSuccess );
      END;

      //=====

      Host^.StartPhase( L"Socket, 100000 * 1024 bytes, POLL" );
      Reader.DetectPrevious := FALSE;
      Reader.PrevCount := 0;
      Reader.Summa := 0;
      Writer.Summa := 0;
      
      // start
      ClientSocket.Waitable := TRUE;
      ClientSocket.ConnectAddress( ai, windows.INFINITE );
      ClientSocket.WaitCompletion( windows.INFINITE );
  
      // run
      Count := 0; // must start from 0, it is due to comparsion with PrevCount in receiver, but here is Count incremented before send
      LOOP
         IF ( Count = 0 ) OR Writer.Completed THEN
            INC( Count );
            IF Count = 100000 THEN
              EXIT;
            END;

            Writer.Init( ADR( Buffer ), SIZE( Buffer ), FALSE );
            ClientSocket.Send( ADR( Writer ), windows.INFINITE, FALSE );
         END;
      END; // LOOP

      // flush receiving
      WaitForMessages( 50 );
      ServerSocket.AbortReceive();
      ClientSocket.Disconnect( TRUE, windows.INFINITE );
      // flush disconnect
      WaitForMessages( 250 );
      
      // check
      IF Writer.Summa <> Reader.Summa THEN
         Failure := TRUE;
         Host^.StopPhaseWithResult( test.trFailure );
      ELSE
         Host^.StopPhaseWithResult( test.trSuccess );
      END;

      //=====
   
      ServerSocket.Disconnect( TRUE, netsocket.FORSAFETY );

      //=====

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
   testimpl.tests()^.AddTest( L"Network::SendReceive", ADR( Test ));
END CTest;

(*===========================================================================*)

END SendReceive.
