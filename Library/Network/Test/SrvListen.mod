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
  
CLASS C_LN( netsrv.AStreamCreator );
  LOCAL VIRTUAL PROCEDURE OnListen( ServerSocket : netsocket.TPSSocket );
  LOCAL VIRTUAL PROCEDURE OnDatagramReceived( ServerSocket : netsocket.TPSSocket );
  LOCAL VIRTUAL PROCEDURE OnListenSocketClosed( ServerSocket : netsocket.TPSSocket );
END C_LN;

CLASS IMPLEMENTATION C_LN;

  LOCAL VIRTUAL PROCEDURE OnListen( ServerSocket : netsocket.TPSSocket );
  BEGIN
    IF ServerSocket = NIL THEN
      OnDatagramReceived( NIL );
    END;
  END OnListen;

  LOCAL VIRTUAL PROCEDURE OnDatagramReceived( ServerSocket : netsocket.TPSSocket );
  BEGIN
    IF TRUE THEN
    END;
  END OnDatagramReceived;

  LOCAL VIRTUAL PROCEDURE OnListenSocketClosed( ServerSocket : netsocket.TPSSocket );
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

  netsrv.StartListen( 4444, netsocket.stStream, ADR( LN ), 0, ADR( S ));
  netsrv.StartListen( 4444, netsocket.stDatagram, ADR( LN ), 0, ADR( S ));
  netsrv.StopListenSocket( S );
  netsrv.StopListenPort( 4444, netsocket.stStream );
  netsrv.StartListen( 4445, netsocket.stStream, ADR( LN ), 50000, ADR( S ));
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
  
  netpool.Cleanup();
  RETURN 0;
END wmain;

END SrvListen.