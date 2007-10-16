MODULE dnsstress;

IMPORT
  winsock;

IMPORT
  dns,
  FIO,
  Strings,
  StringsO,
  windows;
  
CLASS CDNS( dns.ADNSNotifier );
  INTERNAL VIRTUAL PROCEDURE OnAddressFound( RequestId : PTR; Result : CARDINAL; CONST Address : ARRAY OF winsock.IN_ADDR );
  INTERNAL VIRTUAL PROCEDURE OnNameFound( RequestId : PTR; Result : CARDINAL; CONST Name : StringsO.CString );
END CDNS;

CLASS IMPLEMENTATION CDNS;

  INTERNAL VIRTUAL PROCEDURE OnAddressFound( RequestId : PTR; Result : CARDINAL; CONST Address : ARRAY OF winsock.IN_ADDR );
  VAR
    f : FIO.File := windows.GetStdHandle( windows.STD_OUTPUT_HANDLE );
    i : CARDINAL;
  BEGIN
    IF Result = 0 THEN
      FOR i := 0 TO HIGH( Address ) DO
        FIO.WrStrA( f, OAsz( PCHAR( winsock.inet_ntoa( Address[i] )))); FIO.WrStrA( f, C', ' );
      END;
      FIO.WrLnA( f );
    ELSE
      FIO.WrStrA( f, C'<not found>' );
      FIO.WrLnA( f );
    END;
  END OnAddressFound;
  
  INTERNAL VIRTUAL PROCEDURE OnNameFound( RequestId : PTR; Result : CARDINAL; CONST Name : StringsO.CString );
  VAR
    f : FIO.File := windows.GetStdHandle( windows.STD_OUTPUT_HANDLE );
    n : ARRAY [0..255] OF CHAR;
    nw : ARRAY [0..15] OF WCHAR;
  BEGIN
    Strings.FromCARD32W( CARDINAL( RequestId ), 10, OUT nw );
    Strings.ToA( nw, 0, OUT n );
    FIO.WrStrA( f, n );
    FIO.WrStrA( f, C': ' );
    IF Result = winsock.WSAETIMEDOUT THEN
      FIO.WrStrA( f, C'<timed out>' );
    ELSE
      Name.ToOAA( OUT n );
      FIO.WrStrA( f, n );
    END;
    FIO.WrLnA( f );
  END OnNameFound;

END CDNS;

VAR  
  D : CDNS;

PROCEDURE Test();
VAR
  A : winsock.IN_ADDR;
  h : PTR;
  i : CARDINAL;
BEGIN
  // FOR i := 1 TO 254 DO
  //   A.s_addr := winsock.htonl( 10 << 24 + 128 << 16 + 1 << 8 + i );
  FOR i := 1 TO 62 DO
    A.s_addr := winsock.htonl( 217 << 24 + 115 << 16 + 241 << 8 + i );
    dns.AddressToName( ADR( D ), i, A, i*750, OUT h );
  END;

  dns.NameToAddress( ADR( D ), 1, L"a.mii.cz", 1*4000, OUT h );
  dns.NameToAddress( ADR( D ), 2, L"b.mii.cz", 2*4000, OUT h );
  dns.NameToAddress( ADR( D ), 15, L"ariel.mii.cz", 15*4000, OUT h );
  dns.NameToAddress( ADR( D ), 16, L"miranda.mii.cz", 16*4000, OUT h );
  dns.NameToAddress( ADR( D ), 17, L"belinda.mii.cz", 17*4000, OUT h );
  dns.NameToAddress( ADR( D ), 18, L"enceladus.mii.cz", 18*4000, OUT h );
  dns.NameToAddress( ADR( D ), 19, L"oberon.mii.cz", 19*4000, OUT h );
END Test;

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
  RETURN 0;
END wmain;

END dnsstress.