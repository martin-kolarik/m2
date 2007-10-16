IMPLEMENTATION MODULE netinit;

IMPORT
  winsock,
  netpool,
  netsrv;

(*===========================================================================*)

PROCEDURE Startup() : CARDINAL;
CONST
  majorVer = 2;
  minorVer = 2;
VAR
  Result : CARDINAL;
  RQVersion : CARD16;
  WSAData : winsock.WSADATA;
BEGIN
  winsock.WSASetLastError( 0 );
  RQVersion := minorVer << 8 + majorVer; // low byte is major, high byte is minor ver number
  Result := CARDINAL( winsock.WSAStartup( RQVersion, ADR( WSAData )));

  netpool.Startup();

  RETURN Result;
END Startup;

(*--------------------------------------------------------------------------------*)

PROCEDURE Cleanup();
BEGIN
  netsrv.Cleanup();
  netpool.Cleanup();
  winsock.WSACleanup();
END Cleanup;

(*===========================================================================*)

END netinit.