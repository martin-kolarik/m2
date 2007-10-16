MODULE SendReceiveStream;

IMPORT
  winsock;

FROM Storage IMPORT
  ALLOCATE, DEALLOCATE;
  
IMPORT
  IOO,
  netsocket,
  netsrv,
  netstream,
  Strings,
  Sync,
  windows;
  
CLASS RDR( IOO.CMemoryProxy );
  VAR
    LL : CARD64 := 0;
    PrevC : CARDINAL := 0;
  PUBLIC VIRTUAL PROCEDURE CompleteData( Completed : CARDINAL ); // TRUE == have next data
END RDR;

CLASS WRT( IOO.CMemoryProxy );
  VAR
    LL : CARD64 := 0;
  PUBLIC VIRTUAL PROCEDURE CompleteData( Completed : CARDINAL ); // TRUE == have next data
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
  LOCAL VIRTUAL PROCEDURE OnListen( CONST ServerSocket : netsocket.TPSSocket );
END C_LN;

VAR  
  // Buffer : ARRAY [0..9999] OF BYTE;
  Buffer : ARRAY [0..9] OF BYTE;
  LN : C_LN;
  RD : RDR;
  
  RSX : netstream.CNetworkStream;
  WRX : netstream.CNetworkStream;

CLASS IMPLEMENTATION RDR;

  PUBLIC VIRTUAL PROCEDURE CompleteData( Completed : CARDINAL ); // TRUE == have next data
  BEGIN
    INC( LL, Completed );
    SUPER.CompleteData( Completed );
    _Ptr := 0;
    // have all, check
    ASSERT( PCARDINAL( _Data )^ = PrevC+1 );
    INC( PrevC );
  END CompleteData;

BEGIN
END RDR;
  
CLASS IMPLEMENTATION WRT;

  PUBLIC VIRTUAL PROCEDURE CompleteData( Completed : CARDINAL ); // TRUE == have next data
  BEGIN
    INC( LL, Completed );
    SUPER.CompleteData( Completed );
  END CompleteData;

BEGIN
END WRT;
  
CLASS IMPLEMENTATION C_LN;

  LOCAL VIRTUAL PROCEDURE OnListen( CONST ServerSocket : netsocket.TPSSocket );
  VAR
    DS : netsocket.TPDSocket;
    Error : CARDINAL;
  BEGIN
    NEW( DS )^.Accept( ServerSocket, OUT Error );
    RSX.FromSocket( DS, FALSE, IOO.accRead );
    RSX.Read( ADR( RD ), windows.INFINITE, FALSE );
  END OnListen;

END C_LN;

PROCEDURE Test();
CONST
  S = L'Ahoj Martine.';
VAR
  AR : Sync.TAsyncResult;
  C : CARDINAL := 1; // start with 1
  // CA : ARRAY [0..9999] OF BYTE;
  CA : ARRAY [0..9] OF BYTE;
  SD : WRT;
BEGIN
  // RD.Init( ADR( Buffer ), SIZE( Buffer ), FALSE );
  RD.Init( ADR( Buffer ), 4, FALSE );
  RD.Persistent := TRUE;

  netsrv.SetCallbackMode( netsrv.cbmPooled );
  netsrv.StartListen( netsocket.stStream, 4444, NIL, ADR( LN ), 0, NIL );
  Wait();
  WRX.FromServer( L"127.0.0.1", 4444 );
  
  SD.Persistent := TRUE;
  LOOP
    // SD.Init( ADR( CA ), SIZE( CA ), FALSE );
    SD.Init( ADR( C ), 4, FALSE );
    IF WRX.Write( ADR( SD ), windows.INFINITE, TRUE ) = Sync.arCompleted THEN
      INC( C );
    END;
    IF C = 1000000 THEN
    // IF C = 1000000 THEN
    // IF C = 100 THEN
      EXIT;
    END;
  END; // LOOP

END Test;

(*========================================================================*)

PROCEDURE StartupSockets() : CARDINAL;
CONST
  majorVer = 2;
  minorVer = 2;
VAR
  RQVersion : CARD16;
  WSAData   : winsock.WSADATA;
BEGIN
  winsock.WSASetLastError( 0 );
  RQVersion := minorVer << 8 + majorVer; // low byte is major, high byte is minor ver number
  RETURN CARDINAL( winsock.WSAStartup( RQVersion, ADR( WSAData )));
END StartupSockets;

#save, call( convention => cdecl )
PROCEDURE wmain() : INTEGER;
#restore
VAR
  msg : windows.MSG;
BEGIN
  StartupSockets();
  Test();
  WHILE windows.GetMessage( ADR( msg ), NIL, 0, 0 ) = windows.True DO
    windows.DispatchMessage( ADR( msg ));
  END;
  RETURN 0;
END wmain;

END SendReceiveStream.