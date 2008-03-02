MODULE SendReceiveBufferedStream;

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
   netstream,
   IOO,
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

      ReadStream : netstream.CNetworkStream;
      WriteStream : netstream.CNetworkStream;
      
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
      Test^.ReadStream.FromSocket( ADR( Test^.ServerSocket ), FALSE, IOO.accRead );
      Test^.ReadStream.Read( ADR( Test^.Reader ), windows.INFINITE, FALSE );
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
      Buffer : ARRAY [0..1023] OF BYTE;
      Count : INTEGER;
      Failure : BOOLEAN := FALSE;
      WriteStream : netstream.CNetworkStream;
   BEGIN
      SELF.Host := Host;
      ServerListener.Test := ADR( SELF );
      Reader.Test := ADR( SELF );
      Writer.Test := ADR( SELF );

      netinit.Startup();

      // global init      
      Reader.Init( ADR( Buffer ), SIZE( CARDINAL ), FALSE );
      Reader.Persistent := TRUE;
      Writer.Persistent := TRUE;
      netsrv.SetCallbackMode( netsrv.cbmPooled );
      netsrv.StartListen( netsocket.stStream, 4444, NIL, ADR( ServerListener ), 0, NIL );

      //=====

      Host^.StartPhase( L"Socket, 100000 * 4 bytes, WAIT" );
      Reader.DetectPrevious := TRUE;
      Reader.PrevCount := 0;
      Reader.Summa := 0;
      
      // start
      WriteStream.FromServer( L"127.0.0.1", 4444 );
  
      // run
      Count := 1; // must start from 1, it is due to comparsion with PrevCount in receiver
      LOOP
         Writer.Init( ADR( Count ), SIZE( Count ), FALSE );
         IF WriteStream.Write( ADR( Writer ), windows.INFINITE, TRUE ) = sync.arCompleted THEN
            INC( Count );
          END;
          IF Count = 100000 THEN
            EXIT;
          END;
      END; // LOOP

      // flush receiving
      WaitForMessages( 50 );
      ServerSocket.AbortReceive();
      WriteStream.Close( FALSE );
      // flush disconnect
      // WaitForMessages( 250 );
      
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
      WriteStream.FromServer( L"127.0.0.1", 4444 );
  
      // run
      Count := 0; // must start from 0, it is due to comparsion with PrevCount in receiver, but here is Count incremented before send
      LOOP
         IF ( Count = 0 ) OR Writer.Completed THEN
            INC( Count );
            IF Count = 100000 THEN
              EXIT;
            END;

            Writer.Init( ADR( Count ), SIZE( Count ), FALSE );
            WriteStream.Write( ADR( Writer ), windows.INFINITE, FALSE );
         END;
      END; // LOOP

      // flush receiving
      WaitForMessages( 50 );
      ServerSocket.AbortReceive();
      WriteStream.Close( FALSE );
      // flush disconnect
      // WaitForMessages( 250 );
      
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
      WriteStream.FromServer( L"127.0.0.1", 4444 );
  
      // run
      Count := 1; // must start from 1, it is due to comparsion with PrevCount in receiver
      LOOP
         Writer.Init( ADR( Buffer ), SIZE( Buffer ), FALSE );
         IF WriteStream.Write( ADR( Writer ), windows.INFINITE, TRUE ) = sync.arCompleted THEN
            INC( Count );
          END;
          IF Count = 100000 THEN
            EXIT;
          END;
      END; // LOOP

      // flush receiving
      WaitForMessages( 50 );
      ServerSocket.AbortReceive();
      WriteStream.Close( FALSE );
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
      WriteStream.FromServer( L"127.0.0.1", 4444 );
  
      // run
      Count := 0; // must start from 0, it is due to comparsion with PrevCount in receiver, but here is Count incremented before send
      LOOP
         IF ( Count = 0 ) OR Writer.Completed THEN
            INC( Count );
            IF Count = 100000 THEN
              EXIT;
            END;

            Writer.Init( ADR( Buffer ), SIZE( Buffer ), FALSE );
            WriteStream.Write( ADR( Writer ), windows.INFINITE, FALSE );
         END;
      END; // LOOP

      // flush receiving
      WaitForMessages( 50 );
      ServerSocket.AbortReceive();
      WriteStream.Close( FALSE );
      // flush disconnect
      // WaitForMessages( 250 );
      
      // check
      IF Writer.Summa <> Reader.Summa THEN
         Failure := TRUE;
         Host^.StopPhaseWithResult( test.trFailure );
      ELSE
         Host^.StopPhaseWithResult( test.trSuccess );
      END;

      //=====

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
   testimpl.tests()^.AddTest( L"Network::SendReceiveBufferedStream", ADR( Test ));
END CTest;

(*===========================================================================*)

END SendReceiveBufferedStream.

  
  nRSX : netstream.CNetworkStream;
  RSX : IOO.CBufferedStream;
  nWRX : netstream.CNetworkStream;
  WRX : IOO.CBufferedStream;

CLASS IMPLEMENTATION RDR;

  PUBLIC VIRTUAL PROCEDURE CompleteData( Completed : CARDINAL );
  BEGIN
    // windows.Sleep( CARDINAL( LL MOD 2 ));
    INC( LL, Completed );
    SUPER.CompleteData( Completed );
    IF _Ptr < _Length THEN
      RETURN;
    END;
    // have all, check
    ASSERT( PCARDINAL( _Data )^ = PrevC+1 );
    _Ptr := 0;
    INC( PrevC );
  END CompleteData;

BEGIN
END RDR;
  
CLASS IMPLEMENTATION C_LN;

  LOCAL VIRTUAL PROCEDURE OnListen( CONST ServerSocket : netsocket.TPSSocket ); // stStream
  VAR
    DS : netsocket.TPDSocket;
    Error : CARDINAL;
  BEGIN
    NEW( DS )^.Accept( ServerSocket, OUT Error );
    nRSX.FromSocket( DS, FALSE, IOO.accRead );
    // nRSX.Read( ADR( RD ), windows.INFINITE, FALSE );
  END OnListen;

END C_LN;

PROCEDURE Test();
VAR
  C : CARDINAL := 1; // start with 1
  // CA : ARRAY [0..9999] OF BYTE;
  CA : ARRAY [0..9] OF BYTE;
  Result : Sync.TAsyncResult;
  Start : Time.TTime64;
  s : LONGREAL;
  SD : WRT;
BEGIN
  RSX.Stream := ADR( nRSX );
  RSX.BufferSize := 257;

  WRX.Stream := ADR( nWRX );
  WRX.BufferSize := 127;

  RD.Init( ADR( Buffer ), 4, FALSE ); // SIZE( Buffer ), FALSE );
  RD.Persistent := TRUE;

  netsrv.SetCallbackMode( netsrv.cbmPooled );
  netsrv.StartListen( netsocket.stStream, 4444, NIL, ADR( LN ), 0, NIL );
  Wait();
  nWRX.FromServer( L"127.0.0.1", 4444 );
  Wait();
  
  SD.Persistent := TRUE;
  Start := Time.time();
  LOOP
    // SD.Init( ADR( CA ), SIZE( CA ), FALSE );
    SD.Init( ADR( C ), SIZE( C ), FALSE );
    Result := WRX.Write( ADR( SD ), windows.INFINITE, TRUE );
    IF Result = Sync.arCompleted THEN
      INC( C );
      // windows.Sleep( 0 );
    ELSE
      ASSERT( FALSE );
    END;
    // IF C = 100000000 THEN
    IF C = 1000000 THEN
    // IF C = 100 THEN
      s := Time.difftime( Time.time(), Start );
      ASSERT( 1 = 2 );
      EXIT;
    END;
    // IF NOT RSX.Reading THEN
    //   RSX.Read( ADR( RD ), windows.INFINITE, FALSE );
    // END;
    Wait();
    IF NOT RSX.Reading THEN
      WHILE RSX.Read( ADR( RD ), windows.INFINITE, FALSE ) = Sync.arCompleted DO END;
    END;
  END; // LOOP

END Test;

(*========================================================================*)
