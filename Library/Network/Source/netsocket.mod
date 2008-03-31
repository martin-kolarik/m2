IMPLEMENTATION MODULE netsocket;

IMPORT
  dns,
  MSTcpIp,
  netpool,
  Storage,
  Strings,
  StringsO,
  windows,
  WS2TcpIp;
  
(*================================================================================*)

CONST
   EMPTY_AI = WS2TcpIp.addrinfo( 0, 0, 0, 0, 0, NIL, NIL,NIL );

(*================================================================================*)

CLASS IMPLEMENTATION INETADDR;

(*--------------------------------------------------------------------------------*)

   PUBLIC PROPERTY V6 GET : BOOLEAN;
   BEGIN
      RETURN PCARD16( ADR( storage ))^ = winsock.AF_INET6;
   END V6;

(*--------------------------------------------------------------------------------*)

   PUBLIC PROPERTY V6 SET( Value : BOOLEAN );
   BEGIN
      IF Value THEN
         PCARD16( ADR( storage ))^ := winsock.AF_INET6;
      ELSE
         PCARD16( ADR( storage ))^ := winsock.AF_INET; // 4
      END;
   END V6;

(*--------------------------------------------------------------------------------*)

   PUBLIC PROPERTY Port GET : CARDINAL;
   BEGIN
      RETURN CARDINAL( REVERSE( PCARD16( ADR( storage )@[2] )^ ));
   END Port;

(*--------------------------------------------------------------------------------*)

   PUBLIC PROPERTY Port SET( Value : CARDINAL );
   BEGIN
      PCARD16( ADR( storage )@[2] )^ := REVERSE( CARD16( Value ));
   END Port;

(*--------------------------------------------------------------------------------*)

   PUBLIC PROPERTY Loopback GET : BOOLEAN;
   BEGIN
      IF V6 THEN
         RETURN WS2TcpIp.IN6_IS_ADDR_LOOPBACK( WS2TcpIp.Pin_addr6( IN_ADDR6 ));
      ELSE
         RETURN REVERSE( winsock.Pin_addr( IN_ADDR4 )^.s_addr ) = winsock.INADDR_LOOPBACK;
      END;
   END Loopback;

(*--------------------------------------------------------------------------------*)

   PUBLIC PROPERTY Multicast GET : BOOLEAN;
   BEGIN
      IF V6 THEN
         RETURN WS2TcpIp.IN6_IS_ADDR_MULTICAST( WS2TcpIp.Pin_addr6( IN_ADDR6 ));
      ELSE
         RETURN winsock.IN_MULTICAST( REVERSE( winsock.Pin_addr( IN_ADDR4 )^.s_addr ));
      END;
   END Multicast;

(*--------------------------------------------------------------------------------*)

   PUBLIC PROPERTY Data GET : ADDRESS;
   BEGIN
      RETURN ADR( storage );
   END Data;

(*--------------------------------------------------------------------------------*)

   PUBLIC PROPERTY Length GET : CARDINAL;
   BEGIN
      IF V6 THEN
         RETURN SIZE( WS2TcpIp.sockaddr_in6 );
      ELSE
         RETURN SIZE( winsock.sockaddr_in );
      END;
   END Length;

(*--------------------------------------------------------------------------------*)

   PUBLIC PROCEDURE GetAddressOA( IncludePort : BOOLEAN; OUT Address : ARRAY OF WCHAR ); // numerical form in string
   VAR
      buffer : ARRAY [0..511] OF CHAR;
      result : CARDINAL;
      salen : CARDINAL;
      server : ARRAY [0..15] OF CHAR;
      serverU : ARRAY [0..15] OF WCHAR;
      v6 : BOOLEAN := V6;
   BEGIN
      IF v6 THEN
         salen := SIZE( WS2TcpIp.sockaddr_in6 );
      ELSE
         salen := SIZE( winsock.sockaddr_in );
      END;

      result := WS2TcpIp.getnameinfo(
         winsock.Psockaddr( ADR( storage )), salen,
         OUT buffer, SIZE( buffer ),
         OUT server, SIZE( server ),
         WS2TcpIp.NI_NUMERICHOST OR WS2TcpIp.NI_NUMERICSERV
      );
      IF result <> 0 THEN
         ASSERT( FALSE );
      ELSE
         Strings.ToW( buffer, 0, OUT Address );
         IF v6 THEN
            Strings.PrependW( REF Address, L"[" );
            Strings.AppendW( REF Address, L"]" );
         END;
         IF IncludePort AND ( server[0] <> 0C ) AND ( server[0] <> C"0" ) THEN
            Strings.AppendW( REF Address, L":" );
            Strings.ToW( server, 0, OUT serverU );
            Strings.AppendW( REF Address, serverU );
         END; 
      END;
   END GetAddressOA;

(*--------------------------------------------------------------------------------*)

   PUBLIC PROCEDURE SetAddressOA( CONST Address : ARRAY OF WCHAR ) : BOOLEAN; // numerical form in string, FQDN will be refused, INETADDR class does not perform DNS operations
   VAR
      ai : WS2TcpIp.Paddrinfo;
      hostA : ARRAY [0..511] OF CHAR;
      hints : WS2TcpIp.addrinfo := EMPTY_AI;
      host : ARRAY [0..511] OF WCHAR;
      result : CARDINAL;
      service : ARRAY [0..15] OF WCHAR;
      serviceA : ARRAY [0..15] OF CHAR;
   BEGIN
      IF NOT SplitAddressOA( Address, OUT host, OUT service ) THEN
         RETURN FALSE;
      END;
      Strings.ToA( host, 0, OUT hostA );
      Strings.ToA( service, 0, OUT serviceA );

      hints.ai_flags := WS2TcpIp.AI_NUMERICHOST;
      result := WS2TcpIp.getaddrinfo( ADR( hostA ), ADR( serviceA ), ADR( hints ), OUT ai );
      IF result <> 0 THEN
         RETURN FALSE;
      ELSIF ( ai <> NIL ) AND ( ai^.ai_addr <> NIL ) THEN
         ASSERT( ai^.ai_addrlen <= SIZE( storage ));
         Storage.Move( ai^.ai_addr, ADR( storage ), ai^.ai_addrlen );
      END;

      WS2TcpIp.freeaddrinfo( ai );
      RETURN TRUE;
   END SetAddressOA;
   
(*--------------------------------------------------------------------------------*)

   PUBLIC PROCEDURE SetV4( What : TSpecialAddress );
   BEGIN
      CASE What OF
      | saEmpty :
         SetAddressOA( L"0.0.0.0" );
      | saLoopback :
         SetAddressOA( L"127.0.0.1" );
      | saLocalLink :
         SetAddressOA( L"127.0.0.1" );
      | saLocalLinkRandom :
         SetAddressOA( L"127.0.0.1" );
      | saPrivateRandom :
         ASSERT( FALSE );
      END; // CASE      
   END SetV4;

(*--------------------------------------------------------------------------------*)

   PUBLIC PROCEDURE SetV6( What : TSpecialAddress );
   BEGIN
      CASE What OF
      | saEmpty :
         SetAddressOA( L"::" );
      | saLoopback :
         SetAddressOA( L"::1" );
      | saLocalLink :
         SetAddressOA( L"fe80::1" );
      | saLocalLinkRandom :
         SetAddressOA( L"fe80::abcd:abcd" );
      | saPrivateRandom :
         SetAddressOA( L"fc00::1" );
      END; // CASE      
   END SetV6;

(*--------------------------------------------------------------------------------*)

   PUBLIC PROCEDURE FromOA( CONST storage : ARRAY OF BYTE );
   VAR
      i : CARDINAL;
   BEGIN
      IF HIGH( storage ) = -1 THEN
         RETURN;
      END;
      FOR i := 0 TO MIN2( HIGH( SELF.storage ), HIGH( storage )) DO
         SELF.storage[i] := storage[i];
      END;
   END FromOA;

(*--------------------------------------------------------------------------------*)

   PUBLIC PROCEDURE ToOA( OUT storage : ARRAY OF BYTE );
   VAR
      i : CARDINAL;
   BEGIN
      FOR i := 0 TO MIN2( HIGH( SELF.storage ), HIGH( storage )) DO
         storage[i] := SELF.storage[i];
      END;
   END ToOA;

(*--------------------------------------------------------------------------------*)

   INITIALLY INETADDR();
   VAR
      i : CARDINAL;
   BEGIN
      FOR i := 0 TO HIGH( storage ) DO
         storage[i] := 0;
      END;
      V6 := FALSE;
   END INETADDR;
   
(*--------------------------------------------------------------------------------*)

   LOCAL PROPERTY IN_ADDR4 GET : ADDRESS;
   BEGIN
      IF V6 THEN
         RETURN NIL;
      ELSE
         RETURN ADR( winsock.PSOCKADDR_IN( ADR( storage ))^.sin_addr );
      END;
   END IN_ADDR4;

(*--------------------------------------------------------------------------------*)

   LOCAL PROPERTY IN_ADDR6 GET : ADDRESS;
   BEGIN
      IF V6 THEN
         RETURN ADR( WS2TcpIp.Psockaddr_in6( ADR( storage ))^.sin6_addr );
      ELSE
         RETURN NIL;
      END;
   END IN_ADDR6;

(*--------------------------------------------------------------------------------*)

END INETADDR;

(*================================================================================*)

PROCEDURE SplitAddressOA( CONST HostWithService : ARRAY OF WCHAR; OUT Host, Service : ARRAY OF WCHAR ) : BOOLEAN;
LABEL
   CheckPort;
VAR
   i : CARDINAL; 
BEGIN
   IF NOT INSIDE( 0, HostWithService ) THEN
      Host[0] := 0W;
      Service[0] := 0W;
      RETURN TRUE;
   END;

   // check explicitely numerical form
   IF HostWithService[0] = L"[" THEN // ok, search next ]
      i := Strings.LastIndexOfCharW( HostWithService, L"]", 0 );
      IF i = -1 THEN
         RETURN FALSE;
      END;
      Strings.SubstringW( HostWithService, 0, i+1, OUT Host );
      i := Strings.IndexOfCharW( HostWithService, L":", i );
      GOTO CheckPort;
   END;

   // check FQDN and implicitely noted IPV4 address
   // try to find ., if they are there, we can look for : (otherwise whole address is IPV6 and thus port cannot be delimited with :)
   i := Strings.IndexOfCharW( HostWithService, L".", 0 );
   IF i = -1 THEN
      Host := HostWithService;
      Strings.TrimW( REF Host );
      Service[0] := 0W;
      RETURN TRUE;
   END;
   
   // we have ., try to find port
   i := Strings.LastIndexOfCharW( HostWithService, L":", 0 );
   IF i = -1 THEN // no port
      Host := HostWithService;
      Strings.TrimW( REF Host );
      Service[0] := 0W;
      RETURN TRUE;
   END;
   
   // we have port, slice Host and continue with port
   Strings.SubstringW( HostWithService, 0, i, OUT Host );
   Strings.TrimW( REF Host );

CheckPort: // i is prepared here
   IF i = -1 THEN
      Service[0] := 0W;
   ELSE
      Strings.SubstringW( HostWithService, i+1, -1, OUT Service );
      Strings.TrimW( REF Service );
   END;
   RETURN TRUE;
END SplitAddressOA;

(*================================================================================*)

CONST
  FD_DNS     = MAX( CARD16 );
  FD_INIT    = MAX( CARD16 ) - 1;
  FD_TIMEOUT = MAX( CARD16 ) - 2;
  FD_ABORT   = MAX( CARD16 ) - 3;

(*================================================================================*)

CLASS IMPLEMENTATION ASocketNotifier;

  LOCAL VIRTUAL PROCEDURE OnListen( Result : CARDINAL; CONST Socket : TPSSocket );
  BEGIN
  END OnListen;

  LOCAL VIRTUAL PROCEDURE OnDataArrived( Result : CARDINAL; CONST Socket : TPSSocket );
  BEGIN
  END OnDataArrived;

  LOCAL VIRTUAL PROCEDURE OnAccept( Result : CARDINAL; CONST Socket : TPDSocket ); 
  BEGIN
  END OnAccept;

  LOCAL VIRTUAL PROCEDURE OnConnect( Result : CARDINAL; CONST Socket : TPDSocket; Local : BOOLEAN );
  BEGIN
  END OnConnect;

  LOCAL VIRTUAL PROCEDURE OnDisconnect( Result : CARDINAL; CONST Socket : TPDSocket; Local : BOOLEAN );
  BEGIN
  END OnDisconnect;

END ASocketNotifier;

(*================================================================================*)

CLASS IMPLEMENTATION SSocket;

(*--------------------------------------------------------------------------------*)

  PUBLIC PROPERTY Type GET : TSocketType;
  BEGIN
    RETURN _Type;
  END Type;
  
(*--------------------------------------------------------------------------------*)

  PUBLIC PROPERTY Type SET( Value : TSocketType );
  VAR
    Error : CARDINAL;
    Result : Sync.TAsyncResult;
  BEGIN
    IF Value = _Type THEN
      RETURN;
    END;
    _Type := Value;
    IF Socket = winsock.INVALID_SOCKET THEN
      RETURN;
    END;
    Result := Open( OUT Error );
    IF _Lock.In( REF _Pending, poListen ) AND ( Result = Sync.arCompleted ) THEN
      Result := Listen( OUT Error );
    END;
    IF ( Result NOT IN Sync.arsStarts ) AND ( _Notifier <> NIL ) THEN
      _Notifier^.OnListen( Error, ADR( SELF ));
      _Notifier^.OnError( IOO.dirUnknown, Error, ADR( SELF ), opListen );
    END;
  END Type;
  
(*--------------------------------------------------------------------------------*)

  PUBLIC PROPERTY Backlog GET : CARDINAL;
  BEGIN
    RETURN _Backlog;
  END Backlog;
  
(*--------------------------------------------------------------------------------*)

  PUBLIC PROPERTY Backlog SET( Value : CARDINAL );
  VAR
    Error : CARDINAL;
    Result : Sync.TAsyncResult;
  BEGIN
    IF Value = _Backlog THEN
      RETURN;
    END;
    _Backlog := Value;
    IF Socket = winsock.INVALID_SOCKET THEN
      RETURN;
    ELSIF NOT _Lock.In( REF _Pending, poListen ) THEN
      RETURN;
    END;
    Result := Listen( OUT Error );
    IF ( Result NOT IN Sync.arsStarts ) AND ( _Notifier <> NIL ) THEN
      _Notifier^.OnListen( Error, ADR( SELF ));
      _Notifier^.OnError( IOO.dirUnknown, Error, ADR( SELF ), opListen );
    END;
  END Backlog;
  
(*--------------------------------------------------------------------------------*)

  PUBLIC PROPERTY Waitable GET : BOOLEAN;
  BEGIN
    RETURN _HSignal = NIL;
  END Waitable;

(*--------------------------------------------------------------------------------*)

  PUBLIC PROPERTY Waitable SET( Value : BOOLEAN );
  BEGIN
    IF Value = ( _HSignal <> NIL ) THEN
      RETURN;
    END;
    IF Value THEN
      _HSignal := Sync.CreateSignal( FALSE, L'' );
    ELSE
      Sync.DeleteSignal( REF _HSignal );
    END;
  END Waitable;

(*--------------------------------------------------------------------------------*)

  PUBLIC PROPERTY Listening GET : BOOLEAN;
  BEGIN
    RETURN _Lock.In( REF _Pending, poListen );
  END Listening;

(*--------------------------------------------------------------------------------*)

  PUBLIC PROPERTY DataAvailable GET : CARDINAL;
  VAR
    L : CARDINAL;
  BEGIN
    IF _Type <> stDatagram THEN
      RETURN 0;
    ELSIF winsock.ioctlsocket( Socket, winsock.FIONREAD, winsock.Pu_long( ADR( L ))) = winsock.SOCKET_ERROR THEN
      RETURN 0;
    ELSE
      RETURN L;
    END;
  END DataAvailable;

(*--------------------------------------------------------------------------------*)

  PUBLIC PROPERTY Notifier GET : TPSocketNotifier;
  BEGIN
    RETURN _Notifier;
  END Notifier;

(*--------------------------------------------------------------------------------*)

  PUBLIC PROPERTY Notifier SET( Value : TPSocketNotifier );
  BEGIN
    IF _Notifier = Value THEN
      RETURN;
    END;
    IF Value <> NIL THEN
      Value^.AddRef();
    END;
    IF _Notifier <> NIL THEN
      _Notifier^.Release();
    END;
    _Notifier := Value;
  END Notifier;

(*--------------------------------------------------------------------------------*)

  PUBLIC PROPERTY LocalPort GET : CARDINAL;
  BEGIN
    RETURN CARDINAL( winsock.htons( Local.sin_port ));
  END LocalPort;

(*--------------------------------------------------------------------------------*)

  PUBLIC PROPERTY LocalPort SET( Value : CARDINAL );
  VAR
    Error : CARDINAL;
    NPort : CARD16;
    Result : Sync.TAsyncResult;
  BEGIN
    NPort := winsock.htons( CARD16( Value ));
    IF NPort = Local.sin_port THEN
      RETURN;
    END;
    Local.sin_port := NPort;
    IF Socket = winsock.INVALID_SOCKET THEN
      RETURN;
    END;
    Result := Open( OUT Error );
    IF _Lock.In( REF _Pending, poListen ) AND ( Result IN Sync.arsStarts ) THEN
      Result := Listen( OUT Error );
    END;
    IF ( Result NOT IN Sync.arsStarts ) AND ( _Notifier <> NIL ) THEN
      _Notifier^.OnListen( Error, ADR( SELF ));
      _Notifier^.OnError( IOO.dirUnknown, Error, ADR( SELF ), opListen );
    END;
  END LocalPort;
  
(*--------------------------------------------------------------------------------*)

  PUBLIC PROPERTY LocalAddress GET : winsock.IN_ADDR;
  BEGIN
    RETURN Local.sin_addr;
  END LocalAddress;
  
(*--------------------------------------------------------------------------------*)

  PUBLIC PROPERTY LocalAddress SET( CONST Value : winsock.IN_ADDR );
  VAR
    Error : CARDINAL;
    Result : Sync.TAsyncResult;
  BEGIN
    IF Value = Local.sin_addr THEN
      RETURN;
    END;
    Local.sin_addr := Value;
    IF Socket = winsock.INVALID_SOCKET THEN
      RETURN;
    END;
    Result := Open( OUT Error );
    IF _Lock.In( REF _Pending, poListen ) AND ( Result IN Sync.arsStarts ) THEN
      Result := Listen( OUT Error );
    END;
    IF ( Result NOT IN Sync.arsStarts ) AND ( _Notifier <> NIL ) THEN
      _Notifier^.OnListen( Error, ADR( SELF ));
      _Notifier^.OnError( IOO.dirUnknown, Error, ADR( SELF ), opListen );
    END;
  END LocalAddress;
  
(*--------------------------------------------------------------------------------*)

  PUBLIC PROPERTY MulticastGroup GET : INETADDR;
  VAR
    address : INETADDR; // TODO
  BEGIN
    // ...now Remote is V4
    IF winsock.IN_MULTICAST( REVERSE( Remote.sin_addr.s_addr )) THEN
      address.V6 := FALSE;
      address.FromOA( Remote );
    END;
    RETURN address;
  END MulticastGroup;
  
(*--------------------------------------------------------------------------------*)

  PUBLIC PROPERTY MulticastGroup SET( CONST Value : INETADDR );
  VAR
    Local : winsock.SOCKADDR_IN; // TODO
  BEGIN
    Value.ToOA( OUT Local );
    IF Local.sin_addr = Remote.sin_addr THEN
      RETURN;
    END;
    MulticastLeave();
    IF NOT winsock.IN_MULTICAST( REVERSE( Local.sin_addr.s_addr )) THEN
      Remote.sin_addr := winsock.IN_ADDR( 0, 0, 0, 0, 0 );
      RETURN;
    END;
    Remote.sin_addr := Local.sin_addr;
    IF Socket = winsock.INVALID_SOCKET THEN
      RETURN;
    END;
    MulticastJoin();
  END MulticastGroup;
  
(*--------------------------------------------------------------------------------*)

  PUBLIC PROPERTY MulticastPort GET : CARDINAL;
  BEGIN
    IF winsock.IN_MULTICAST( REVERSE( Remote.sin_addr.s_addr )) THEN
      RETURN CARDINAL( winsock.htons( Remote.sin_port ));
    ELSE
      RETURN 0;
    END;
  END MulticastPort;

(*--------------------------------------------------------------------------------*)

  PUBLIC PROPERTY MulticastPort SET( Value : CARDINAL );
  VAR
    NPort : CARD16;
  BEGIN
    NPort := winsock.htons( CARD16( Value ));
    IF NPort = Remote.sin_port THEN
      RETURN;
    END;
    Remote.sin_port := NPort;
  END MulticastPort;

(*--------------------------------------------------------------------------------*)

  PUBLIC PROCEDURE Open( OUT Error : CARDINAL ) : Sync.TAsyncResult;
  LABEL
    Failed;
  VAR
    len : CARDINAL;
    na : winsock.SOCKADDR_IN;
    Result : CARDINAL;
  BEGIN
    Close( TRUE );
    // create socket
    IF _Type = stDatagram THEN
      Socket := winsock.socket( winsock.AF_INET, winsock.SOCK_DGRAM, 0 );
    ELSE
      Socket := winsock.socket( winsock.AF_INET, winsock.SOCK_STREAM, 0 );
    END;
    IF Socket = winsock.INVALID_SOCKET THEN
      GOTO Failed;
    END;
    // bind it
    Storage.Zero( ADR( na ), SIZE( na ));
    WITH na DO
      sin_family := winsock.AF_INET;
      sin_port := Local.sin_port;
      sin_addr := Local.sin_addr;
    END;
    Result := winsock.bind( Socket, winsock.Psockaddr( ADR( na )), SIZE( na ));
    IF Result <> 0 THEN
      GOTO Failed;
    END;
    IF _Type = stDatagram THEN
      _Lock.Incl( REF _Pending, poConnection ); // allow reading data
      MulticastJoin();
    END;
    // obtain real port number
    IF Local.sin_port = 0 THEN
      len := SIZE( na );
      Result := winsock.getsockname( Socket, winsock.Psockaddr( ADR( na )), ADR( len ));
      IF Result <> 0 THEN
        GOTO Failed;
      END;
      Local.sin_port := na.sin_port;
    END;
    Error := 0;
    RETURN Sync.arCompleted;

  Failed:
    Error := winsock.WSAGetLastError();
    Close( TRUE );
    RETURN Sync.arAborted;
  END Open;

(*--------------------------------------------------------------------------------*)

  PUBLIC PROCEDURE Close( Persist : BOOLEAN );
  BEGIN
    IF Socket <> winsock.INVALID_SOCKET THEN
      IF _Type = stDatagram THEN
        MulticastLeave();
      END;
      Select( 0 );
      winsock.closesocket( Socket );
      Socket := winsock.INVALID_SOCKET;
    END;
    IF Persist THEN
      RETURN;
    END;
    _Lock.InclExcl( REF _Pending, BITSET32{}, BITSET32( NOT CARDINAL( TPendingOperation{poResolveName} )));
    IF _FDHandle <> NIL THEN
      netpool.Pool()^.Abort( REF _FDHandle );
    END;
  END Close;

(*--------------------------------------------------------------------------------*)

  PUBLIC PROCEDURE WaitCompletion( TimeoutMS : CARDINAL ) : Sync.TAsyncResult;
  VAR
    LResult : Sync.TAsyncResult;
  BEGIN
    LResult := Sync.Wait( _HSignal, TimeoutMS );
    IF Result = Sync.arUnknown THEN
      RETURN LResult;
    ELSIF LResult = Sync.arCompleted THEN
      RETURN Result;
    ELSE
      RETURN LResult;
    END;
  END WaitCompletion;

(*--------------------------------------------------------------------------------*)

  PUBLIC PROCEDURE Listen( OUT Error : CARDINAL ) : Sync.TAsyncResult;
  BEGIN
    IF Socket = winsock.INVALID_SOCKET THEN
      RETURN Sync.arCannotStart;
    END;

    // convert socket to asynchronous
    IF _Type = stDatagram THEN
      Error := Select( winsock.FD_READ );
    ELSE
      Error := Select( winsock.FD_ACCEPT );
      IF Error = 0 THEN
        Error := winsock.listen( Socket, _Backlog );
      END;
    END;
    IF Error = 0 THEN
      Sync.Reset( _HSignal );
      _Lock.Incl( REF _Pending, poListen );
      RETURN Sync.arCompleted;
    END;

    // error
    Error := winsock.WSAGetLastError();
    IF Socket <> winsock.INVALID_SOCKET THEN
      winsock.closesocket( Socket );
      Socket := winsock.INVALID_SOCKET;
    END;
    RETURN Sync.arAborted;
  END Listen;

(*--------------------------------------------------------------------------------*)

  PUBLIC PROCEDURE Flush(); // blind recv, accept depending on Type
  VAR
    dw : LONGWORD;
    socket : winsock.SOCKET;
  BEGIN
    IF _Type = stStream THEN
      socket := winsock.accept( Socket, NIL, NIL );
      IF socket <> winsock.INVALID_SOCKET THEN
        winsock.closesocket( socket );
      END;
    ELSE
      winsock.recv( Socket, PCHAR( ADR( dw )), SIZE( dw ), 0 );
    END;
  END Flush;

(*--------------------------------------------------------------------------------*)

  PUBLIC PROCEDURE ReceiveOA( OUT Data : ARRAY OF BYTE; OUT Filled : CARDINAL ) : Sync.TAsyncResult;
  VAR
    fa : winsock.SOCKADDR_IN;
    la : CARDINAL := SIZE( fa );
  BEGIN
    IF _Type <> stDatagram THEN
      RETURN Sync.arCannotStart;
    END;
    Filled := MIN2( HIGH( Data )+1, DataAvailable );
    Filled := winsock.recvfrom( Socket, windows.PSTR( ADR( Data )), Filled, 0, winsock.Psockaddr( ADR( fa )), ADR( la ));
    RETURN Sync.arCompleted;
  END ReceiveOA;

(*--------------------------------------------------------------------------------*)

  PUBLIC PROCEDURE SendOA( CONST Data : ARRAY OF BYTE ) : Sync.TAsyncResult; // uses multicast address
  VAR
    l : CARDINAL;
  BEGIN
    IF _Type <> stDatagram THEN
      RETURN Sync.arCannotStart;
    END;
    l := winsock.sendto( Socket, windows.PSTR( ADR( Data )), HIGH( Data )+1, 0, winsock.Psockaddr( ADR( Remote )), SIZE( Remote ));
    IF l = 0 THEN
      RETURN Sync.arCannotStart;
    ELSIF l = HIGH( Data )+1 THEN
      RETURN Sync.arCompleted;
    ELSE
      RETURN Sync.arPartCompleted;
    END;
  END SendOA;

(*--------------------------------------------------------------------------------*)

  PUBLIC PROCEDURE SendToOA( CONST Data : ARRAY OF BYTE; To : winsock.IN_ADDR; Port : CARDINAL ) : Sync.TAsyncResult; // uses given address
  VAR
    l : CARDINAL;
    r : winsock.SOCKADDR_IN;
  BEGIN
    IF _Type <> stDatagram THEN
      RETURN Sync.arCannotStart;
    END;
    WITH r DO
      sin_family := winsock.AF_INET;
      sin_addr := To;
      sin_port := winsock.htons( CARD16( Port ));
    END; // WITH
    l := winsock.sendto( Socket, windows.PSTR( ADR( Data )), HIGH( Data )+1, 0, winsock.Psockaddr( ADR( r )), SIZE( r ));
    IF l = 0 THEN
      RETURN Sync.arCannotStart;
    ELSIF l = HIGH( Data )+1 THEN
      RETURN Sync.arCompleted;
    ELSE
      RETURN Sync.arPartCompleted;
    END;
  END SendToOA;

(*--------------------------------------------------------------------------------*)

  PUBLIC PROCEDURE SendTo6OA( CONST Data : ARRAY OF BYTE; CONST Address : INETADDR ) : Sync.TAsyncResult; // uses given address
  VAR
    l : CARDINAL;
  BEGIN
    IF _Type <> stDatagram THEN
      RETURN Sync.arCannotStart;
    END;
    l := winsock.sendto( Socket, windows.PSTR( ADR( Data )), HIGH( Data )+1, 0, winsock.Psockaddr( Address.Data ), Address.Length );
    IF l = 0 THEN
      RETURN Sync.arCannotStart;
    ELSIF l = HIGH( Data )+1 THEN
      RETURN Sync.arCompleted;
    ELSE
      RETURN Sync.arPartCompleted;
    END;
  END SendTo6OA;

(*--------------------------------------------------------------------------------*)

  LOCAL VIRTUAL PROCEDURE OnMessage( Result : Sync.TAsyncResult; PoolHandle : Sync.WAITABLE; UserId : PTR; CONST MSG : msghandler.IMessage );
  VAR
    Event : CARDINAL;
  BEGIN
    CASE Result OF
    | Sync.arCompleted :
      Event := CARDINAL( winsock.WSAGETSELECTEVENT( MSG[3] ));
      IF ( _Type = stDatagram ) AND ( Event <> winsock.FD_READ ) THEN
        RETURN;
      ELSIF ( _Type = stStream ) AND ( Event <> winsock.FD_ACCEPT ) THEN
        RETURN;
      END;
    | Sync.arAborted :
      IF _Type = stDatagram THEN
        _Notifier^.OnDataArrived( winsock.WSAECONNABORTED, ADR( SELF ));
      ELSE
        _Notifier^.OnListen( winsock.WSAECONNABORTED, ADR( SELF ));
      END;
      _FDHandle := NIL;
      RETURN;
    ELSE
      RETURN;
    END;

    Sync.Signal( _HSignal ); Sync.Reset( _HSignal );
    IF _Notifier <> NIL THEN
      IF _Type = stDatagram THEN
        _Notifier^.OnDataArrived( CARDINAL( winsock.WSAGETASYNCERROR( MSG[3] )), ADR( SELF ));
      ELSE
        _Notifier^.OnListen( CARDINAL( winsock.WSAGETASYNCERROR( MSG[3] )), ADR( SELF ));
      END;
    END;
  END OnMessage;
  
(*--------------------------------------------------------------------------------*)

  INTERNAL PROCEDURE Select( Events : CARDINAL ) : CARDINAL;
  BEGIN
    IF Events = 0 THEN // chyba : WSAAsyncSelect neprojde, asi ten NIL, ci co, prozkoumat
      RETURN winsock.WSAAsyncSelect( Socket, NIL, 0, 0 );
    ELSIF _FDHandle = NIL THEN
      netpool.Pool()^.WaitMessage( ADR( SELF ), 0, Sync.FOREVER, FALSE, FALSE, OUT _FDMessager, OUT _FDMessage, OUT _FDHandle );
    END;
    RETURN winsock.WSAAsyncSelect( Socket, _FDMessager^.Handle, _FDMessage.Message, Events );
  END Select;

(*--------------------------------------------------------------------------------*)

  INTERNAL PROCEDURE MulticastJoin() : CARDINAL;
  VAR
    MReq : WS2TcpIp.ip_mreq;
    res : CARDINAL;
    ttl : CARDINAL;
  BEGIN
    IF NOT MulticastGroup.Multicast THEN
      RETURN 0;
    END;

    IF MulticastGroup.V6 THEN
      ASSERT( FALSE ); // TODO
    ELSE
      MReq.imr_multiaddr := winsock.Pin_addr( MulticastGroup.IN_ADDR4 )^;
      MReq.imr_interface.s_addr := winsock.INADDR_ANY;
    END;
    res := winsock.setsockopt( Socket, winsock.IPPROTO_IP, WS2TcpIp.IP_ADD_MEMBERSHIP, windows.PSTR( ADR( MReq )), SIZE( MReq ));
    IF res <> 0 THEN
      RETURN res;
    END;

    ttl := 32; // the same site
    RETURN winsock.setsockopt( Socket, winsock.IPPROTO_IP, WS2TcpIp.IP_MULTICAST_TTL, windows.PSTR( ADR( ttl )), SIZE( ttl ));
  END MulticastJoin;

(*--------------------------------------------------------------------------------*)

  INTERNAL PROCEDURE MulticastLeave() : CARDINAL;
  VAR
    MReq : WS2TcpIp.ip_mreq;
  BEGIN
    IF NOT MulticastGroup.Multicast THEN
      RETURN 0;
    END;
  
    IF MulticastGroup.V6 THEN
      ASSERT( FALSE ); // TODO
      RETURN 0;
    ELSE
      MReq.imr_multiaddr := winsock.Pin_addr( MulticastGroup.IN_ADDR4 )^;
      MReq.imr_interface.s_addr := winsock.INADDR_ANY;
      RETURN winsock.setsockopt( Socket, winsock.IPPROTO_IP, WS2TcpIp.IP_DROP_MEMBERSHIP, windows.PSTR( ADR( MReq )), SIZE( MReq ));
    END;
  END MulticastLeave;

(*--------------------------------------------------------------------------------*)

BEGIN
  _Type := stStream;
  _Backlog := winsock.SOMAXCONN; // default
  _Notifier := NIL;
  _Pending := TPendingOperation{};
  _FDHandle := NIL;
  _FDMessager := NIL;
  _HSignal := NIL;
  Result := Sync.arUnknown;
  Socket := winsock.INVALID_SOCKET;
  Storage.Zero( ADR( Local ), SIZE( Local ));  
  Local.sin_family := winsock.AF_INET;
  Storage.Zero( ADR( Remote ), SIZE( Remote ));
  Remote.sin_family := winsock.AF_INET;
FINALLY
  Close( FALSE );
  IF _Notifier <> NIL THEN
    _Notifier^.Release();
    _Notifier := NIL;
  END;
  Sync.DeleteSignal( REF _HSignal );
END SSocket;

(*================================================================================*)

CLASS CDNSNotifier( dns.ADNSNotifier );
  LOCAL VIRTUAL PROCEDURE OnAddressFound( RequestId : PTR; Result : CARDINAL; CONST Address : ARRAY OF winsock.IN_ADDR );
  LOCAL VIRTUAL PROCEDURE OnNameFound( RequestId : PTR; Result : CARDINAL; CONST Name : StringsO.CString );
END CDNSNotifier;

(*--------------------------------------------------------------------------------*)

CLASS IMPLEMENTATION CDNSNotifier;

  LOCAL VIRTUAL PROCEDURE OnAddressFound( RequestId : PTR; Result : CARDINAL; CONST Address : ARRAY OF winsock.IN_ADDR );
  BEGIN
    TPDSocket( RequestId )^.OnAddressFound( Result, Address );
  END OnAddressFound;

  LOCAL VIRTUAL PROCEDURE OnNameFound( RequestId : PTR; Result : CARDINAL; CONST Name : StringsO.CString );
  BEGIN
    TPDSocket( RequestId )^.OnNameFound( Result, Name );
  END OnNameFound;

END CDNSNotifier;

VAR
  DNS : CDNSNotifier;

(*================================================================================*)

CLASS IMPLEMENTATION DSocket;

(*--------------------------------------------------------------------------------*)

  PUBLIC PROPERTY RemoteAddress GET : winsock.IN_ADDR;
  BEGIN
    RETURN Remote.sin_addr;
  END RemoteAddress;
  
(*--------------------------------------------------------------------------------*)

  PUBLIC PROPERTY RemoteAddress SET( CONST Value : winsock.IN_ADDR );
  VAR
    Error : CARDINAL;
    Result : Sync.TAsyncResult;
  BEGIN
    IF Value = Remote.sin_addr THEN
      RETURN;
    END;
    Remote.sin_addr := Value;
    IF Socket = winsock.INVALID_SOCKET THEN
      RETURN;
    END;
    Result := ConnectAddress( Remote.sin_addr, RemotePort, FORSAFETY );
    IF ( Result NOT IN Sync.arsStarts ) AND ( _Notifier <> NIL ) THEN
      Error := winsock.WSAGetLastError();
      _Notifier^.OnConnect( Error, ADR( SELF ), TRUE );
      _Notifier^.OnError( IOO.dirUnknown, Error, ADR( SELF ), opConnect );
    END;
  END RemoteAddress;
  
(*--------------------------------------------------------------------------------*)

  PUBLIC PROPERTY RemotePort GET : CARDINAL;
  BEGIN
    RETURN CARDINAL( winsock.htons( Remote.sin_port ));
  END RemotePort;

(*--------------------------------------------------------------------------------*)

  PUBLIC PROPERTY RemotePort SET( Value : CARDINAL );
  VAR
    Error : CARDINAL;
    NPort : CARD16;
    Result : Sync.TAsyncResult;
  BEGIN
    NPort := winsock.htons( CARD16( Value ));
    IF NPort = Remote.sin_port THEN
      RETURN;
    END;
    Remote.sin_port := NPort;
    IF Socket = winsock.INVALID_SOCKET THEN
      RETURN;
    END;
    Result := ConnectAddress( Remote.sin_addr, Value, FORSAFETY );
    IF ( Result NOT IN Sync.arsStarts ) AND ( _Notifier <> NIL ) THEN
      Error := winsock.WSAGetLastError();
      _Notifier^.OnConnect( Error, ADR( SELF ), TRUE );
      _Notifier^.OnError( IOO.dirUnknown, Error, ADR( SELF ), opConnect );
    END;
  END RemotePort;

(*--------------------------------------------------------------------------------*)

  PUBLIC PROPERTY KeepAliveTime GET : CARDINAL;
  BEGIN
    RETURN KeepAlive;
  END KeepAliveTime;

(*--------------------------------------------------------------------------------*)

  PUBLIC PROPERTY KeepAliveTime SET( Value : CARDINAL );
  VAR
    Result : CARDINAL;
  BEGIN
    IF Value = KeepAlive THEN
      RETURN;
    END;
    KeepAlive := MAX2( Value, 1000 );
    IF Socket = winsock.INVALID_SOCKET THEN
      RETURN;
    ELSIF _Type = stDatagram THEN
      RETURN;
    END;
    Result := StartKeepAlive();
    IF Result <> 0 THEN
      Disconnect( FALSE, FORSAFETY );
    END;
  END KeepAliveTime;

(*--------------------------------------------------------------------------------*)

  PUBLIC PROPERTY Connecting GET : BOOLEAN;
  BEGIN
    RETURN _Lock.In( REF _Pending, poConnect );
  END Connecting;

(*--------------------------------------------------------------------------------*)

  PUBLIC PROPERTY Connected GET : BOOLEAN;
  BEGIN
    RETURN _Lock.In( REF _Pending, poConnection );
  END Connected;

(*--------------------------------------------------------------------------------*)

  PUBLIC PROPERTY Closed GET : BOOLEAN;
  BEGIN
    RETURN _Lock.NotInSet( REF _Pending, BITSET32( TPendingOperation{poConnect, poConnection, poDisconnect} ));
  END Closed;

(*--------------------------------------------------------------------------------*)

  PUBLIC PROPERTY DataAvailable GET : CARDINAL;
  VAR
    L : CARDINAL;
  BEGIN
    IF NOT _Lock.In( REF _Pending, poConnection ) THEN
      RETURN 0;
    ELSIF winsock.ioctlsocket( Socket, winsock.FIONREAD, winsock.Pu_long( ADR( L ))) = winsock.SOCKET_ERROR THEN
      RETURN 0;
    ELSE
      RETURN L;
    END;
  END DataAvailable;

(*--------------------------------------------------------------------------------*)

  PUBLIC PROCEDURE Open( OUT Error : CARDINAL ) : Sync.TAsyncResult; // socket -- modified variant of SSocket.Open
  VAR
    na : winsock.SOCKADDR_IN;
  BEGIN
    Close( TRUE );
    IF _Type = stDatagram THEN
      Socket := winsock.socket( winsock.AF_INET, winsock.SOCK_DGRAM, 0 );
    ELSE
      Socket := winsock.socket( winsock.AF_INET, winsock.SOCK_STREAM, 0 );
    END;
    IF Socket = winsock.INVALID_SOCKET THEN
      Error := winsock.WSAGetLastError();
      RETURN Sync.arAborted;
    END;

    IF _Type = stDatagram THEN // datagram socket shout be bind to allow multicasting and receiving
      Storage.Zero( ADR( na ), SIZE( na ));
      WITH na DO
        sin_family := winsock.AF_INET;
        sin_port := Local.sin_port;
        sin_addr := Local.sin_addr;
      END;
      Error := winsock.bind( Socket, winsock.Psockaddr( ADR( na )), SIZE( na ));
      IF Error <> 0 THEN
        Error := winsock.WSAGetLastError();
        RETURN Sync.arAborted;
      END;
    END;

    Error := 0;
    RETURN Sync.arCompleted;
  END Open;

(*--------------------------------------------------------------------------------*)

  PUBLIC PROCEDURE Connect( CONST Server : ARRAY OF WCHAR; Port : CARDINAL; TimeoutMS : CARDINAL ) : Sync.TAsyncResult;
  VAR
    Addr : winsock.IN_ADDR;
    Result : Sync.TAsyncResult;
    sa : ARRAY [0..511] OF CHAR;
  BEGIN
    IF poConnect IN TPendingOperation( _Lock.Incl( REF _Pending, poConnect )) THEN
      RETURN Sync.arAlreadyPending;
    END;
    Strings.ToA( Server, 0, OUT sa );
    Addr.s_addr := winsock.inet_addr( ADR( sa ));

    IF _Type = stStream THEN
      IF TimeoutMS < Sync.FOREVER THEN
        StartTimeout( poConnect, TimeoutMS );
        TimeoutMS := TimeoutMS DIV 2; // prepare for Disconnect
      ELSE
        StopTimeout( poConnect );
      END;
    END;
    SELF.Result := Sync.arUnknown;
    Sync.Reset( _HSignal );
    Result := Disconnect( FALSE, TimeoutMS );

    // set new connection parameters -- only port is known here
    Remote.sin_port := REVERSE( CARD16( Port ));

    IF Addr.s_addr = winsock.INADDR_NONE THEN
      IF poResolveAddress IN TPendingOperation( _Lock.Incl( REF _Pending, poResolveAddress )) THEN
        dns.KillPending( REF ResolveAddr );
      END;
      AddRef();
      dns.NameToAddress( ADR( DNS ), ADR( SELF ), Server, FORSAFETY, OUT ResolveAddr );
    ELSIF Result = Sync.arPending THEN
      // result from Disconnect
    ELSE
      Remote.sin_addr := Addr;
      SwitchContext( FD_INIT, poConnect, 0 );
    END;
    RETURN Sync.arPending;
  END Connect;

(*--------------------------------------------------------------------------------*)

  PUBLIC PROCEDURE ConnectAddress( CONST Server : winsock.IN_ADDR; Port : CARDINAL; TimeoutMS : CARDINAL ) : Sync.TAsyncResult;
  VAR
    Result : Sync.TAsyncResult;
  BEGIN
    IF poConnect IN TPendingOperation( _Lock.Incl( REF _Pending, poConnect )) THEN
      RETURN Sync.arAlreadyPending;
    END;

    IF _Type = stStream THEN
      IF TimeoutMS < Sync.FOREVER THEN
        StartTimeout( poConnect, TimeoutMS );
        TimeoutMS := TimeoutMS DIV 2; // prepare for Disconnect
      ELSE
        StopTimeout( poConnect );
      END;
    END;
    SELF.Result := Sync.arUnknown;
    Sync.Reset( _HSignal );
    Result := Disconnect( FALSE, TimeoutMS );

    // set new connection parameters
    Remote.sin_addr := Server;
    Remote.sin_port := REVERSE( CARD16( Port ));

    IF Result <> Sync.arPending THEN
      SwitchContext( FD_INIT, poConnect, 0 );
    END;
    RETURN Sync.arPending;
  END ConnectAddress;

(*--------------------------------------------------------------------------------*)

  PUBLIC PROCEDURE Accept( CONST ServerSocket : TPSSocket; OUT Error : CARDINAL ) : Sync.TAsyncResult;
  LABEL
    Failed;
  VAR
    L : CARDINAL;
    Result : CARDINAL;
  BEGIN
    IF _Type = stDatagram THEN
      RETURN Sync.arCannotStart;
    END;
    Disconnect( TRUE, FORSAFETY );

    L := SIZE( Remote ); 
    Socket := winsock.accept( ServerSocket^.Socket, winsock.Psockaddr( ADR( Remote )), ADR( L ));
    IF Socket = winsock.INVALID_SOCKET THEN
      GOTO Failed;
    END;
    L := SIZE( Local );
    Result := winsock.getsockname( Socket, winsock.Psockaddr( ADR( Local )), ADR( L ));
    IF Result <> 0 THEN
      GOTO Failed;
    END;

    _Lock.Incl( REF _Pending, poConnection );
    Result := Select( winsock.FD_READ OR winsock.FD_WRITE OR winsock.FD_CLOSE );
    IF Result = 0 THEN
      Result := StartKeepAlive();
    END;
    IF Result <> 0 THEN
      GOTO Failed;
    END;

    IF _Notifier <> NIL THEN
      _Notifier^.OnAccept( 0, ADR( SELF ));
      _Notifier^.OnConnect( 0, ADR( SELF ), FALSE );
    END;
    Error := 0;
    RETURN Sync.arCompleted;

  Failed:
    _Lock.Excl( REF _Pending, poConnection );
    Close( TRUE );
    Result := winsock.WSAGetLastError();
    IF _Notifier <> NIL THEN
      _Notifier^.OnAccept( Result, ADR( SELF ));
      _Notifier^.OnError( IOO.dirUnknown, Result, ADR( SELF ), opAccept );
    END;
    Error := Result;
    RETURN Sync.arAborted;
  END Accept;

(*--------------------------------------------------------------------------------*)

  PUBLIC PROCEDURE AcceptFrom( REF SourceSocket : TPDSocket; OUT Error : CARDINAL ) : Sync.TAsyncResult;
  LABEL
    Failed;
  VAR
    Result : CARDINAL;
  BEGIN
    IF _Type = stDatagram THEN
      RETURN Sync.arCannotStart;
    END;
    Disconnect( TRUE, FORSAFETY );

    Local := SourceSocket^.Local;
    Remote := SourceSocket^.Remote;
    Socket := SourceSocket^.Socket;

    SourceSocket^.Socket := winsock.INVALID_SOCKET;
    SourceSocket^.Disconnect( TRUE, FORSAFETY );

    _Lock.Incl( REF _Pending, poConnection );
    Result := Select( winsock.FD_READ OR winsock.FD_WRITE OR winsock.FD_CLOSE );
    IF Result = 0 THEN
      Result := StartKeepAlive();
    END;
    IF Result <> 0 THEN
      GOTO Failed;
    END;

    IF _Notifier <> NIL THEN
      _Notifier^.OnAccept( 0, ADR( SELF ));
      _Notifier^.OnConnect( 0, ADR( SELF ), FALSE );
    END;
    Error := 0;
    RETURN Sync.arCompleted;

  Failed:
    _Lock.Excl( REF _Pending, poConnection );
    Close( TRUE );
    Result := winsock.WSAGetLastError();
    IF _Notifier <> NIL THEN
      _Notifier^.OnAccept( Result, ADR( SELF ));
      _Notifier^.OnError( IOO.dirUnknown, Result, ADR( SELF ), opAccept );
    END;
    Error := Result;
    RETURN Sync.arAborted;
  END AcceptFrom;

(*--------------------------------------------------------------------------------*)

  PUBLIC PROCEDURE Disconnect( Abortive : BOOLEAN; TimeoutMS : CARDINAL ) : Sync.TAsyncResult;
  VAR
    Result : CARDINAL;
  BEGIN
    IF _Type = stDatagram THEN
      IF poConnection IN TPendingOperation( _Lock.Excl( REF _Pending, poConnection )) THEN
        MulticastLeave();
      END;
      RETURN Sync.arCompleted;

    ELSIF NOT Abortive AND _Lock.In( REF _Pending, poDisconnect ) THEN
      RETURN Sync.arAlreadyPending;
    ELSIF Socket = winsock.INVALID_SOCKET THEN
      RETURN Sync.arCannotStart;
    ELSE
      _Lock.Incl( REF _Pending, poDisconnect );
    END;

    IF NOT Abortive THEN
      StartTimeout( poDisconnect, TimeoutMS );
      IF NOT _Lock.In( REF _Pending, poConnect ) THEN
        SELF.Result := Sync.arUnknown;
        Sync.Reset( _HSignal );
      END;
      SwitchContext( FD_INIT, poDisconnect, 0 );
      RETURN Sync.arPending;
    END;

    _Lock.Excl( REF _Pending, poConnection );
    Close( TRUE );
    Result := winsock.WSAECONNABORTED;

    StopTimeout( poDisconnect );
    IF poConnect NOT IN TPendingOperation( _Lock.Excl( REF _Pending, poDisconnect )) THEN
      SELF.Result := Sync.arAborted;
      Sync.Signal( _HSignal );
    END;
    IF _Notifier <> NIL THEN
      _Notifier^.OnDisconnect( Result, ADR( SELF ), TRUE );
      _Notifier^.OnError( IOO.dirUnknown, Result, ADR( SELF ), opDisconnect );
    END;

    RETURN Sync.arCompleted;
  END Disconnect;

(*--------------------------------------------------------------------------------*)

  PUBLIC PROCEDURE Receive( Buffer : IOO.TPDataProxy; TimeoutMS : CARDINAL; WaitForCompletion : BOOLEAN ) : Sync.TAsyncResult;
  BEGIN
    RETURN StartFlow( poReceive, Buffer, TimeoutMS, WaitForCompletion );
  END Receive;

(*--------------------------------------------------------------------------------*)

  PUBLIC PROCEDURE ReceiveOA( OUT Data : ARRAY OF BYTE; TimeoutMS : CARDINAL ) : Sync.TAsyncResult;
  VAR
    Chunk : IOO.CMemoryProxy;
    R : Sync.TAsyncResult;
  BEGIN
    Chunk.Init( ADR( Data ), HIGH( Data )+1, FALSE );
    Chunk.Persistent := TRUE; // stack variable cannot be freed
    R := Receive( ADR( Chunk ), TimeoutMS, TRUE );
    WHILE Chunk.References > 1 DO
      Sync.Sleep( 0 );
    END; // WHILE
    RETURN R;
  END ReceiveOA;

(*--------------------------------------------------------------------------------*)

  PUBLIC PROCEDURE AbortReceive();
  BEGIN
    CompleteFlow( poReceive, FALSE, Sync.arAborted, 0 );
  END AbortReceive;

(*--------------------------------------------------------------------------------*)

  PUBLIC PROCEDURE Send( Buffer : IOO.TPDataProxy; TimeoutMS : CARDINAL; WaitForCompletion : BOOLEAN ) : Sync.TAsyncResult;
  BEGIN
    RETURN StartFlow( poSend, Buffer, TimeoutMS, WaitForCompletion );
  END Send;

(*--------------------------------------------------------------------------------*)

  PUBLIC PROCEDURE SendOA( CONST Data : ARRAY OF BYTE; TimeoutMS : CARDINAL ) : Sync.TAsyncResult;
  VAR
    Chunk : IOO.CMemoryProxy;
    R : Sync.TAsyncResult;
  BEGIN
    Chunk.Init( ADR( Data ), HIGH( Data )+1, TRUE );
    Chunk.Persistent := TRUE; // stack variable cannot be freed
    R := Send( ADR( Chunk ), TimeoutMS, TRUE );
    WHILE Chunk.References > 1 DO
      Sync.Sleep( 0 );
    END; // WHILE
    RETURN R;
  END SendOA;

(*--------------------------------------------------------------------------------*)

  PUBLIC PROCEDURE AbortSend();
  BEGIN
    CompleteFlow( poSend, FALSE, Sync.arAborted, 0 );
  END AbortSend;

(*--------------------------------------------------------------------------------*)

  LOCAL VIRTUAL PROCEDURE OnTimeout( Result : Sync.TAsyncResult; PoolHandle : Sync.WAITABLE; UserId : PTR );
  BEGIN
    IF Result = Sync.arCompleted THEN
      SwitchContext( FD_TIMEOUT, TPendingOperationItem( LOPTRLONGWORD( UserId )), winsock.WSAETIMEDOUT );
    END;
  END OnTimeout;

(*--------------------------------------------------------------------------------*)

  LOCAL VIRTUAL PROCEDURE OnMessage( Result : Sync.TAsyncResult; PoolHandle : Sync.WAITABLE; UserId : PTR; CONST MSG : msghandler.IMessage );
  LABEL
    DoConnect, DoFDConnect;
  VAR
    Error : CARDINAL;
    Event : CARDINAL;
    LPending : TPendingOperation;
    InDisconnect : BOOLEAN;
  BEGIN
    CASE Result OF
    | Sync.arCompleted :
      Event := CARDINAL( winsock.WSAGETSELECTEVENT( MSG[3] ));
      IF Event = winsock.FD_ACCEPT THEN
        SUPER.OnMessage( Result, PoolHandle, UserId, MSG );
        RETURN;
      END;
      Error := CARDINAL( winsock.WSAGETASYNCERROR( MSG[3] ));
    | Sync.arAborted :
      LPending := TPendingOperation( _Lock.Get( REF _Pending ));
      IF poListen IN LPending THEN
        SUPER.OnMessage( Result, PoolHandle, UserId, MSG );
        RETURN;
      ELSIF poConnect IN LPending THEN
        OnConnect( FD_ABORT, winsock.WSAECONNABORTED );
      ELSE
        OnDisconnect( FD_ABORT, winsock.WSAECONNABORTED, TRUE );
      END;
      _FDHandle := NIL;
      RETURN;
    ELSE
      RETURN;
    END;

    CASE Event OF
    //-----
    | FD_INIT :
      CASE TPendingOperationItem( LOPTRLONGWORD( MSG[2] )) OF
      | poConnect :
        StartConnect();
      | poDisconnect :
        Error := Dispose();
        IF Error <> 0 THEN
          OnDisconnect( FD_INIT, Error, TRUE );
        END;
      | poReceive :
        Sync.IExchgPtr( REF RPending, Reader );
        OnFlow( poReceive );
      | poSend :
        Sync.IExchgPtr( REF WPending, Writer );
        OnFlow( poSend );
      END; // CASE
    //-----
    | FD_TIMEOUT :
      CASE TPendingOperationItem( LOPTRLONGWORD( MSG[2] )) OF
      | poConnect :
        OnConnect( FD_TIMEOUT, Error );
      | poDisconnect :
        OnDisconnect( FD_TIMEOUT, Error, TRUE );
      | poReceive :
        CompleteFlow( poReceive, TRUE, Sync.arTimeout, 0 );
      | poSend :
        CompleteFlow( poSend, TRUE, Sync.arTimeout, 0 );
      END; // CASE
    //-----
    | winsock.FD_CONNECT :
      OnConnect( winsock.FD_CONNECT, Error );
    //-----
    | winsock.FD_CLOSE : // everything should be read out
      InDisconnect := _Lock.In( REF _Pending, poDisconnect );
      IF NOT InDisconnect AND ( Error = 0 ) THEN // remote side graceful close, send rest of my data and notify I am ended
        Dispose();
      END;
      OnDisconnect( winsock.FD_CLOSE, Error, InDisconnect );
    //-----
    | FD_DNS :
      CASE TPendingOperationItem( LOPTRLONGWORD( MSG[2] )) OF
      | poResolveAddress :
        LPending := TPendingOperation( _Lock.Excl( REF _Pending, poResolveAddress ));
        IF Error = winsock.WSAECONNABORTED THEN
          // request was aborted, I know this
        ELSIF Error <> 0 THEN
          OnConnect( FD_DNS, Error );
        ELSIF poConnect IN LPending THEN
          StartConnect();
        END;
      | poResolveName :
        _Lock.Excl( REF _Pending, poResolveName );
      END; // CASE
      Release();
    //-----
    | winsock.FD_READ :
      OnFlow( poReceive );
    //-----
    | winsock.FD_WRITE :
      OnFlow( poSend );
    //-----
    END; // CASE
  END OnMessage;

(*--------------------------------------------------------------------------------*)

  LOCAL PROCEDURE OnAddressFound( Result : CARDINAL; CONST Address : ARRAY OF winsock.IN_ADDR );
  BEGIN
    Remote.sin_addr := Address[0];
    SwitchContext( FD_DNS, poResolveAddress, Result );
  END OnAddressFound;

(*--------------------------------------------------------------------------------*)

  LOCAL PROCEDURE OnNameFound( Result : CARDINAL; CONST Name : StringsO.CString );
  BEGIN
    RemoteName := Name;
    SwitchContext( FD_DNS, poResolveName, Result );
  END OnNameFound;

(*--------------------------------------------------------------------------------*)

  PRIVATE PROCEDURE SwitchContext( FromContext : CARDINAL; Operation : TPendingOperationItem; Result : CARDINAL );
  VAR
    MSG : msghandler.Message;
  BEGIN
    IF _FDHandle = NIL THEN
      netpool.Pool()^.WaitMessage( ADR( SELF ), 0, Sync.FOREVER, FALSE, FALSE, OUT _FDMessager, OUT _FDMessage, OUT _FDHandle );
    END;
    MSG := _FDMessage;
    MSG[2] := PTR( Operation );
    MSG[3] := FromContext OR ( Result << 16 );
    _FDMessager^.Message( MSG, msghandler.delDefault, NIL );
  END SwitchContext;

(*--------------------------------------------------------------------------------*)

  PRIVATE PROCEDURE StartConnect();
  VAR
    Error : CARDINAL;
    Result : Sync.TAsyncResult;
    wb : windows.BOOL := windows.True;
  BEGIN
    Result := Open( OUT Error );
    
    IF Result NOT IN Sync.arsStarts THEN
      // fall down to process error
    
    ELSIF _Type = stDatagram THEN
      Error := Select( winsock.FD_READ OR winsock.FD_WRITE );
      IF Error = 0 THEN // join multicast group
        Error := MulticastJoin();
      END;
      IF ( Error = 0 ) AND ( Remote.sin_addr = INADDR_ALL ) THEN // set broadcast flag
        Error := winsock.setsockopt( Socket, winsock.SOL_SOCKET, winsock.SO_BROADCAST, windows.PSTR( ADR( wb )), SIZE( wb ));
      END;

    ELSE // _Type = stStream
      Error := StartKeepAlive();
      IF Error = 0 THEN
        Error := Select( winsock.FD_CONNECT OR winsock.FD_READ OR winsock.FD_WRITE OR winsock.FD_CLOSE );
      END;
      IF Error = 0 THEN
        Error := winsock.connect( Socket, winsock.Psockaddr( ADR( Remote )), SIZE( Remote ));
      END;
    END;

    IF Error <> 0 THEN
      Error := winsock.WSAGetLastError();
    END;
    IF _Type = stDatagram THEN // call OnConnect immediatelly
      OnConnect( FD_INIT, Error );
    ELSIF ( Error = 0 ) OR ( Error = winsock.WSAEWOULDBLOCK ) THEN
      RETURN;
    ELSE // stream error
      OnConnect( FD_INIT, Error );
    END;
  END StartConnect;

(*--------------------------------------------------------------------------------*)

  PRIVATE PROCEDURE OnConnect( Context : CARDINAL; Error : CARDINAL );
  VAR
    L : CARDINAL;
    LPending : TPendingOperation;
  BEGIN
    IF NOT _Lock.In( REF _Pending, poConnect ) THEN
      RETURN;
    ELSIF Error = 0 THEN
      LPending := TPendingOperation( _Lock.InclExcl( REF _Pending, BITSET32( TPendingOperation{poConnection} ), BITSET32( TPendingOperation{poConnect} )));
    ELSE
      LPending := TPendingOperation( _Lock.Excl( REF _Pending, poConnect ));
    END;

    IF poResolveAddress IN LPending THEN
      dns.KillPending( REF ResolveAddr );
    END;
    IF Context = FD_TIMEOUT THEN
      Timeout[poConnect] := NIL;
    ELSE
      StopTimeout( poConnect );
    END;
    IF Error = 0 THEN
      Result := Sync.arCompleted;
      winsock.getsockname( Socket, winsock.Psockaddr( ADR( Local )), ADR( L ));
    ELSE
      Result := Sync.arAborted;
      Close( TRUE );
    END;
    Sync.Signal( _HSignal );
    IF _Notifier <> NIL THEN
      _Notifier^.OnConnect( Error, ADR( SELF ), TRUE );
      IF Error <> 0 THEN
        _Notifier^.OnError( IOO.dirUnknown, Error, ADR( SELF ), opConnect );
      END;
    END;
  END OnConnect;

(*--------------------------------------------------------------------------------*)

  PRIVATE PROCEDURE OnDisconnect( Context : CARDINAL; Error : CARDINAL; Local : BOOLEAN );
  VAR
    LPending : TPendingOperation;
  BEGIN
    IF _Lock.NotInSet( REF _Pending, BITSET32( TPendingOperation{poConnection, poConnect, poDisconnect} )) THEN // not connecting nor connected
      RETURN;
    END;
    LPending := TPendingOperation( _Lock.InclExcl( REF _Pending, BITSET32{}, BITSET32( TPendingOperation{poConnection, poDisconnect} )));
    
    // abort pending IOs
    CompleteFlow( poSend, TRUE, Sync.arAborted, Error );
    CompleteFlow( poReceive, TRUE, Sync.arAborted, Error );
    
    IF Context = FD_TIMEOUT THEN
      Timeout[poDisconnect] := NIL;
    ELSE
      StopTimeout( poDisconnect );
    END;
    Close( poConnect IN LPending );
    IF poConnect NOT IN LPending THEN
      IF Error = 0 THEN
        Result := Sync.arCompleted;
      ELSE
        Result := Sync.arAborted;
      END;
      Sync.Signal( _HSignal );
    END;
    IF _Notifier <> NIL THEN
      _Notifier^.OnDisconnect( Error, ADR( SELF ), Local );
      IF Error <> 0 THEN
        _Notifier^.OnError( IOO.dirUnknown, Error, ADR( SELF ), opDisconnect );
      END;
    END;
    IF ( Context <> FD_ABORT ) AND ( TPendingOperation{poConnect, poResolveAddress} * LPending = TPendingOperation{poConnect} ) THEN // disconnect caused inside connect, connect is not waiting for DNS
      StartConnect();
    END;
  END OnDisconnect;

(*--------------------------------------------------------------------------------*)

  PRIVATE PROCEDURE StartFlow( Operation : TPendingOperationItem; Buffer : IOO.TPDataProxy; TimeoutMS : CARDINAL; WaitForCompletion : BOOLEAN ) : Sync.TAsyncResult;
  VAR
    LBuffer : IOO.TPDataProxy;
    Result : Sync.TAsyncResult;
  BEGIN
    IF NOT _Lock.In( REF _Pending, poConnection ) THEN
      RETURN Sync.arCannotStart;
    ELSIF Operation = poReceive THEN
      LBuffer := Sync.ICmpExchgPtr( REF Reader, Buffer, NIL );
    ELSE
      LBuffer := Sync.ICmpExchgPtr( REF Writer, Buffer, NIL );
    END;
    IF LBuffer <> NIL THEN // previous value
      RETURN Sync.arAlreadyPending;
    END;
    _Lock.Incl( REF _Pending, Operation );
    Buffer^.AddRef(); // use local Buffer, RBuffer can be after SwitchContext asynchronously cleared
    IF WaitForCompletion THEN
      Buffer^.Waitable := TRUE;
      Buffer^.Start();
      SwitchContext( FD_INIT, Operation, 0 );
      Result := Buffer^.WaitCompletion( TimeoutMS );
      IF Result = Sync.arTimeout THEN
        CompleteFlow( Operation, FALSE, Sync.arTimeout, 0 );
      END;
      RETURN Result;
    ELSE
      Buffer^.Start();
      StartTimeout( Operation, TimeoutMS );
      SwitchContext( FD_INIT, Operation, 0 );
      RETURN Sync.arPending;
    END;
  END StartFlow;

(*--------------------------------------------------------------------------------*)

  PRIVATE PROCEDURE OnFlow( Operation : TPendingOperationItem );
  VAR
    a : ADDRESS;
    AR : Sync.TAsyncResult := Sync.arCompleted;
    Buffer : IOO.TPDataProxy;
    fa : winsock.SOCKADDR_IN;
    l : CARDINAL;
    la : CARDINAL := SIZE( fa );
    Result : CARDINAL := 0;
  BEGIN
    IF Operation = poReceive THEN
      Buffer := Sync.IGetPtr( REF RPending );
    ELSE
      Buffer := Sync.IGetPtr( REF WPending );
    END;
    IF Buffer = NIL THEN
      CompleteFlow( Operation, TRUE, AR, 0 );
      RETURN;
    END;

    LOOP
      IF NOT Buffer^.PrepareData( OUT a, OUT l ) THEN
        EXIT;
      END;

      IF Operation = poReceive THEN
        IF _Type = stDatagram THEN
          l := winsock.recvfrom( Socket, a, l, 0, winsock.Psockaddr( ADR( fa )), ADR( la ));
        ELSE
          l := winsock.recv( Socket, a, l, 0 );
        END;
      ELSE
        IF _Type = stDatagram THEN
          l := winsock.sendto( Socket, a, l, 0, winsock.Psockaddr( ADR( Remote )), SIZE( Remote ));
        ELSE
          l := winsock.send( Socket, a, l, 0 );
        END;
      END;

      IF l = winsock.SOCKET_ERROR THEN // error for send/receive
        Result := winsock.WSAGetLastError();
        IF Result = winsock.WSAEWOULDBLOCK THEN
          RETURN;
        END;
        AR := Sync.arAborted;
        EXIT; // finish operation

      ELSIF Operation = poReceive THEN // receive requires some pre-receive check
        IF l = 0 THEN // read during graceful close, reading must finish
          AR := Sync.arAborted;
          EXIT; // finish operation

        ELSIF Type = stDatagram THEN // datagrams are accepted only if they are mine
          IF Remote.sin_addr = INADDR_ALL THEN
            // I am receiving broadcast, pass down
          ELSIF Remote = fa THEN
            // I am receiving from expected partner, pass down
          ELSIF winsock.IN_MULTICAST( REVERSE( RemoteAddress.s_addr )) THEN
            // I am receiving multicast data, where source is never the same
          ELSE // and here -- discard unexpected packet
            CONTINUE; // LOOP
          END;

        END;
      END; // IF errors and pre-receive check

      // first complete...
      Buffer^.CompleteData( l );

      // ...next notify
      IF _Notifier <> NIL THEN
        IF Operation = poReceive THEN
          _Notifier^.OnReadable( l, ADR( SELF ));
        ELSE
          _Notifier^.OnWritten( l, ADR( SELF ));
        END;
      END;

    END; // LOOP

    CompleteFlow( Operation, TRUE, AR, Result );
  END OnFlow;

(*--------------------------------------------------------------------------------*)

  PRIVATE PROCEDURE CompleteFlow( Operation : TPendingOperationItem; Device : BOOLEAN; Result : Sync.TAsyncResult; NResult : CARDINAL );
  VAR
    Buffer : IOO.TPDataProxy;
    SocketOperation : TOperation;
  BEGIN
    StopTimeout( Operation );
    IF Operation = poReceive THEN
      Buffer := Sync.IExchgPtr( REF RPending, NIL );
      IF ( Buffer <> NIL ) OR NOT Device THEN
        Buffer := Sync.IExchgPtr( REF Reader, NIL );
      END;
      SocketOperation := opReceive;
    ELSE
      Buffer := Sync.IExchgPtr( REF WPending, NIL );
      IF ( Buffer <> NIL ) OR NOT Device THEN
        Buffer := Sync.IExchgPtr( REF Writer, NIL );
      END;
      SocketOperation := opSend;
    END;
    _Lock.Excl( REF _Pending, Operation );
    IF Buffer <> NIL THEN
      Buffer^.DeviceFinish( Result );
      Buffer^.Release();
    END;
    IF _Notifier <> NIL THEN
      IF ( Buffer <> NIL ) AND ( Result NOT IN Sync.arsCompletions ) AND ( NResult <> 0 ) THEN
        IF Operation = poReceive THEN
          _Notifier^.OnError( IOO.dirRead, NResult, ADR( SELF ), SocketOperation );
        ELSE
          _Notifier^.OnError( IOO.dirWrite, NResult, ADR( SELF ), SocketOperation );
        END;
      END;
      IF Result IN Sync.arsCompletions THEN
        IF Operation = poReceive THEN
          _Notifier^.OnFlowPossible( IOO.dirRead, ADR( SELF ));
        ELSE
          _Notifier^.OnFlowPossible( IOO.dirWrite, ADR( SELF ));
        END;
      END;
    END;
  END CompleteFlow;

(*--------------------------------------------------------------------------------*)

  PRIVATE PROCEDURE StartKeepAlive() : CARDINAL;
  VAR
    KA : MSTcpIp.tcp_keepalive;
    L : CARDINAL;
  BEGIN
    IF ( KeepAlive = 0 ) OR ( KeepAlive = Sync.FOREVER ) THEN
      KA.onoff := 0;
    ELSE
      KA.onoff := 1;
      KA.keepalivetime := KeepAlive;
      KA.keepaliveinterval := 3000;
    END;
    RETURN winsock.WSAIoctl( Socket, MSTcpIp.SIO_KEEPALIVE_VALS, ADR( KA ), SIZE( KA ), NIL, 0, ADR( L ), NIL, NIL );
  END StartKeepAlive;

(*--------------------------------------------------------------------------------*)

  PRIVATE PROCEDURE Dispose() : CARDINAL;
  VAR
    Result : CARDINAL;
  BEGIN
    OnFlow( poSend );
    Result := winsock.shutdown( Socket, winsock.SD_SEND );
    IF Result <> 0 THEN
      Result := winsock.WSAGetLastError();
    END;
    RETURN Result;
  END Dispose;

(*--------------------------------------------------------------------------------*)

  PRIVATE PROCEDURE StartTimeout( Operation : TPendingOperationItem; _Timeout : CARDINAL );
  BEGIN
    IF Timeout[Operation] <> NIL THEN
      netpool.Pool()^.Abort( REF Timeout[Operation] );
    END;
    IF _Timeout <> Sync.FOREVER THEN
      netpool.Pool()^.WaitTimeout( ADR( SELF ), PTR( Operation ), _Timeout, TRUE, FALSE, OUT Timeout[Operation] );
    END;
  END StartTimeout;

(*--------------------------------------------------------------------------------*)

  PRIVATE PROCEDURE StopTimeout( Operation : TPendingOperationItem );
  BEGIN
    IF Timeout[Operation] <> NIL THEN
      netpool.Pool()^.Abort( REF Timeout[Operation] );
    END;
  END StopTimeout;

(*--------------------------------------------------------------------------------*)

BEGIN
  Storage.Zero( ADR( Remote ), SIZE( Remote ));
  Remote.sin_family := winsock.AF_INET;
  ResolveAddr := NIL;
  Storage.Zero( ADR( Timeout ), SIZE( Timeout ));
  KeepAlive := 120000;
  Reader := NIL;
  RPending := NIL;
  Writer := NIL;
  WPending := NIL;
FINALLY
  StopTimeout( poConnect );
  StopTimeout( poDisconnect );
  AbortReceive();
  AbortSend();
END DSocket;

(*================================================================================*)

END netsocket.