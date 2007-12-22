MODULE SrvListen;

IMPORT
  winsock;

FROM Storage IMPORT
  ALLOCATE, DEALLOCATE;

IMPORT
  FIO,
  netsocket,
  netsrv,
  netpool,
  Strings,
  windows;
  
CLASS C_LN( netsrv.AListener );
  LOCAL VIRTUAL PROCEDURE OnListen( CONST ServerSocket : netsocket.TPSSocket );
  LOCAL VIRTUAL PROCEDURE OnDatagramReceived( CONST ServerSocket : netsocket.TPSSocket );
  LOCAL VIRTUAL PROCEDURE OnListenSocketClosed( CONST ServerSocket : netsocket.TPSSocket );
END C_LN;

CLASS IMPLEMENTATION C_LN;

  LOCAL VIRTUAL PROCEDURE OnListen( CONST ServerSocket : netsocket.TPSSocket );
  BEGIN
    IF ServerSocket = NIL THEN
      OnDatagramReceived( NIL );
    END;
  END OnListen;

  LOCAL VIRTUAL PROCEDURE OnDatagramReceived( CONST ServerSocket : netsocket.TPSSocket );
  BEGIN
    IF TRUE THEN
    END;
  END OnDatagramReceived;

  LOCAL VIRTUAL PROCEDURE OnListenSocketClosed( CONST ServerSocket : netsocket.TPSSocket );
  BEGIN
    IF ServerSocket = NIL THEN
      OnListenSocketClosed( NIL );
    END;
  END OnListenSocketClosed;

END C_LN;

VAR  
  LN : C_LN;

PROCEDURE Test();
VAR
  S : netsocket.TPSSocket;
BEGIN
  // _LN.XOnListenSocketClosed( ADDRESS( 1 ));

  netsrv.StartListen( netsocket.stStream, 4444, NIL, ADR( LN ), 0, ADR( S ));
  netsrv.StartListen( netsocket.stDatagram, 4444, NIL, ADR( LN ), 0, ADR( S ));
  netsrv.StopListenSocket( OUT S );
  netsrv.StopListenPort( netsocket.stStream, 4444 );
  netsrv.StartListen( netsocket.stStream, 4445, NIL, ADR( LN ), 50000, ADR( S ));
END Test;

(*========================================================================*)

PROCEDURE StartupSockets() : CARDINAL;
CONST
  majorVer = 1;
  minorVer = 1;
VAR
  RQVersion : CARD16;
  WSAData   : winsock.WSADATA;
BEGIN
  winsock.WSASetLastError( 0 );
  RQVersion := minorVer << 8 + majorVer; // low byte is major, high byte is minor ver number
  RETURN CARDINAL( winsock.WSAStartup( RQVersion, ADR( WSAData )));
END StartupSockets;

#save, call( convention => cdecl )
PROCEDURE wmain01() : INTEGER;
#restore
VAR
  msg : windows.MSG;
BEGIN
  StartupSockets();
  Test();

  WHILE windows.GetMessage( ADR( msg ), NIL, 0, 0 ) = windows.True DO
    windows.DispatchMessage( ADR( msg ));
  END;
  
  netpool.Cleanup();
  RETURN 0;
END wmain01;

END SrvListen.