MODULE ConnectDisconnect;

IMPORT
  winsock;

FROM Storage IMPORT
  ALLOCATE, DEALLOCATE;

IMPORT
  netsocket,
  netsrv,
  Strings,
  windows;
  
PROCEDURE Wait();
VAR
  C : CARDINAL := 100;
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
  LOCAL VIRTUAL PROCEDURE OnListenSocketClosed( CONST ServerSocket : netsocket.TPSSocket );
END C_LN;

CLASS C_SN( netsocket.ASocketNotifier );
  LOCAL VIRTUAL PROCEDURE OnConnect( Result : CARDINAL; CONST Socket : netsocket.TPDSocket; Local : BOOLEAN ); 
  LOCAL VIRTUAL PROCEDURE OnDisconnect( Result : CARDINAL; CONST Socket : netsocket.TPDSocket; Local : BOOLEAN ); 
END C_SN;

VAR  
  DC : netsocket.TPDSocket;
  LN : C_LN;
  SN : C_SN;

CLASS IMPLEMENTATION C_LN;

  LOCAL VIRTUAL PROCEDURE OnListen( CONST ServerSocket : netsocket.TPSSocket );
  VAR
    DS : netsocket.TPDSocket;
    e : CARDINAL;
  BEGIN
    NEW( DS );
    DS^.AddRef();
    DS^.Notifier := ADR( SN );
    DS^.Accept( ServerSocket, OUT e );
    DS^.Release(); // prevent Release made during OnDisconnect when Accept is pending
    // DS^.Close( FALSE );
    // DS^.Release();
  END OnListen;

  LOCAL VIRTUAL PROCEDURE OnListenSocketClosed( CONST ServerSocket : netsocket.TPSSocket );
  BEGIN
  END OnListenSocketClosed;

END C_LN;

CLASS IMPLEMENTATION C_SN;

  LOCAL VIRTUAL PROCEDURE OnConnect( Result : CARDINAL; CONST Socket : netsocket.TPDSocket; Local : BOOLEAN ); 
  BEGIN
    IF Result = winsock.WSAECONNABORTED THEN
      RETURN;
    ELSIF Socket = DC THEN
      windows.Sleep( 10 );
      Socket^.Connect( L'hermes', 4444, 2000 );
    // ELSIF Result <> 0 THEN
    //   Socket^.Disconnect( FALSE, windows.INFINITE );
    //   Socket^.Release();
    END;
  END OnConnect;

  LOCAL VIRTUAL PROCEDURE OnDisconnect( Result : CARDINAL; CONST Socket : netsocket.TPDSocket; Local : BOOLEAN ); 
  BEGIN
    IF Socket <> DC THEN
      Socket^.Close( FALSE );
      Socket^.Release();
    END;
  END OnDisconnect;

END C_SN;

PROCEDURE Test();
BEGIN
  netsrv.StartListen( netsocket.stStream, 4444, NIL, ADR( LN ), 0, NIL );
  Wait();

  NEW( DC );
  DC^.Notifier := ADR( SN );
  // DC^.ConnectAddress( winsock.IN_ADDR( 0, 07FH, 0, 0, 1 ), 4444, windows.INFINITE );
  DC^.Connect( L'hermes', 4444, windows.INFINITE );
  Wait();
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
PROCEDURE wmain06() : INTEGER;
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
END wmain06;

END ConnectDisconnect.