MODULE SendReceiveBufferedStream;

IMPORT
  winsock;

FROM Storage IMPORT
  ALLOCATE, DEALLOCATE;
  
IMPORT
  IOO,
  netsocket,
  netsrv,
  netstream,
  netinit,
  Strings,
  Sync,
  Time,
  windows;
  
CLASS RDR( IOO.CMemoryProxy );
  VAR
    LL : CARD64 := 0;
    PrevC : CARDINAL := 0;
  PUBLIC VIRTUAL PROCEDURE CompleteData( Completed : CARDINAL );
END RDR;

CLASS WRT( IOO.CMemoryProxy );
  VAR
    LL : CARD64 := 0;
  PUBLIC VIRTUAL PROCEDURE CompleteData( Completed : CARDINAL );
END WRT;

PROCEDURE Wait();
VAR
  C : CARDINAL := 2;
  msg : windows.MSG;
BEGIN
  WHILE C > 0 DO 
    windows.PeekMessage( ADR( msg ), NIL, 0, 0, windows.PM_REMOVE );
    windows.DispatchMessage( ADR( msg ));
    windows.Sleep( 0 );
    DEC( C );
  END; // WHILE
END Wait;
  
CLASS C_LN( netsrv.AListener );
  LOCAL VIRTUAL PROCEDURE OnListen( CONST ServerSocket : netsocket.TPSSocket ); // stStream
END C_LN;

VAR  
  // Buffer : ARRAY [0..9999] OF BYTE;
  Buffer : ARRAY [0..9] OF BYTE;
  LN : C_LN;
  RD : RDR;
  
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
  
CLASS IMPLEMENTATION WRT;

  PUBLIC VIRTUAL PROCEDURE CompleteData( Completed : CARDINAL );
  BEGIN
    INC( LL, Completed );
    SUPER.CompleteData( Completed );
  END CompleteData;

BEGIN
END WRT;
  
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

#save, call( convention => cdecl )
PROCEDURE wmain() : INTEGER;
#restore
VAR
  msg : windows.MSG;
BEGIN
  netinit.Startup();
  Test();
  WHILE windows.GetMessage( ADR( msg ), NIL, 0, 0 ) = windows.True DO
    windows.DispatchMessage( ADR( msg ));
  END;
  RETURN 0;
END wmain;

END SendReceiveBufferedStream.