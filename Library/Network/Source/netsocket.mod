IMPLEMENTATION MODULE netsocket;

IMPORT
   winsock;

FROM Storage IMPORT
   Move;

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

INLINE PROCEDURE IN_ADDR4( CONST ai : inetaddr.INETADDR ) : winsock.Pin_addr;
BEGIN
   IF ai.V6 THEN
      RETURN NIL;
   ELSE
      RETURN ADR( winsock.Psockaddr_in( ai.Data )^.sin_addr );
   END;
END IN_ADDR4;

(*--------------------------------------------------------------------------------*)

INLINE PROCEDURE IN_ADDR6( CONST ai : inetaddr.INETADDR ) : WS2TcpIp.Pin_addr6;
BEGIN
   IF ai.V6 THEN
      RETURN ADR( WS2TcpIp.Psockaddr_in6( ai.Data )^.sin6_addr );
   ELSE
      RETURN NIL;
   END;
END IN_ADDR6;

(*================================================================================*)

TYPE
   TSwitchMessage = RECORD
                       Context : CARDINAL;
                       Operation : TPendingOperationItem;
                       ErrorCode : CARDINAL;
                    END; // RECORD

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

  PUBLIC PROPERTY V6Mode GET : TV6Mode;
  BEGIN
    RETURN _V6Mode;
  END V6Mode;

(*--------------------------------------------------------------------------------*)

  PUBLIC PROPERTY V6Mode SET( Value : TV6Mode );
  VAR
    ai : inetaddr.INETADDR;
  BEGIN
    IF _V6Mode = Value THEN
      RETURN;
    END;
    ai := LocalAddress;
    CASE _V6Mode OF
    | v6mV4, v6mPreferV4 :
      ai.V6 := FALSE;
    | v6mPreferV6, v6mV6 :
      ai.V6 := TRUE;
    END; // CASE
    LocalAddress := ai;
  END V6Mode;

(*--------------------------------------------------------------------------------*)

  PUBLIC PROPERTY LocalAddress GET : inetaddr.INETADDR;
  BEGIN
    RETURN Local;
  END LocalAddress;
  
(*--------------------------------------------------------------------------------*)

  PUBLIC PROPERTY LocalAddress SET( CONST Value : inetaddr.INETADDR );
  VAR
    Error : CARDINAL;
    Result : Sync.TAsyncResult;
  BEGIN
    IF Local = Value THEN
      RETURN;
    END;
    Local := Value;
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

   PUBLIC PROPERTY MulticastGroup GET : inetaddr.INETADDR;
   VAR
      address : inetaddr.INETADDR;
   BEGIN
      IF Remote.Multicast THEN
         RETURN Remote;
      ELSE
         RETURN address;
      END;
   END MulticastGroup;
  
(*--------------------------------------------------------------------------------*)

   PUBLIC PROPERTY MulticastGroup SET( CONST Value : inetaddr.INETADDR );
   BEGIN
      IF Remote = Value THEN
         RETURN;
      END;
      MulticastLeave();
      IF NOT Value.Multicast THEN
         Remote.SetV6( inetaddr.saEmpty );
         RETURN;
      END;
      Remote := Value;
      IF Socket = winsock.INVALID_SOCKET THEN
         RETURN;
       END;
      MulticastJoin();
   END MulticastGroup;
  
(*--------------------------------------------------------------------------------*)

   PUBLIC PROCEDURE Open( OUT Error : CARDINAL ) : Sync.TAsyncResult;
   LABEL
      Failed;
   VAR
      len : CARDINAL;
      na : inetaddr.INETADDR;
      Result : CARDINAL;
   BEGIN
      Close( TRUE );
      // create socket
      IF _Type = stDatagram THEN
         IF Local.V6 THEN
            Socket := winsock.socket( winsock.AF_INET6, winsock.SOCK_DGRAM, 0 );
         ELSE
            Socket := winsock.socket( winsock.AF_INET, winsock.SOCK_DGRAM, 0 );
         END;
      ELSE
         IF Local.V6 THEN
            Socket := winsock.socket( winsock.AF_INET6, winsock.SOCK_STREAM, 0 );
         ELSE
            Socket := winsock.socket( winsock.AF_INET, winsock.SOCK_STREAM, 0 );
         END;
      END;
      IF Socket = winsock.INVALID_SOCKET THEN
         GOTO Failed;
      END;
      // bind it
      Result := winsock.bind( Socket, winsock.Psockaddr( Local.Data ), Local.Length );
      IF Result <> 0 THEN
         GOTO Failed;
      END;
      IF _Type = stDatagram THEN
         _Lock.InclExcl( REF _Pending, BITSET32( TPendingOperation{poConnection} ), BITSET32( posConnectPrerequisities )); // allow reading data
         MulticastJoin();
      END;
      // obtain real port number
      IF Local.Port = 0 THEN
         len := SIZE( na );
         Result := winsock.getsockname( Socket, winsock.Psockaddr( na.Data ), ADR( len ));
         IF Result <> 0 THEN
            GOTO Failed;
         END;
         Local.Port := na.Port;
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
        _Lock.Excl( REF _Pending, poConnection );
      END;
      Select( {} );
      winsock.closesocket( Socket );
      Socket := winsock.INVALID_SOCKET;
    END;
    IF Persist THEN
      RETURN;
    END;
    _Lock.InclExcl( REF _Pending, BITSET32{}, BITSET32( NOT CARDINAL( TPendingOperation{poResolveName} )));
    IF _FDHandle <> NIL THEN
      netpool.pool()^.Abort( REF _FDHandle );
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
      Error := Select( {winsock.FD_READ_BIT} );
    ELSE
      Error := Select( {winsock.FD_ACCEPT_BIT} );
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
    fa : inetaddr.INETADDR;
  BEGIN
    RETURN ReceiveFromOA( OUT Data, OUT Filled, OUT fa );
  END ReceiveOA;

(*--------------------------------------------------------------------------------*)

   PUBLIC PROCEDURE ReceiveFromOA( OUT Data : ARRAY OF BYTE; OUT Filled : CARDINAL; OUT Address : inetaddr.INETADDR ) : Sync.TAsyncResult;
   VAR
      la : CARDINAL := SIZE( Address );
      l : CARDINAL;
      Result : CARDINAL;
   BEGIN
      IF _Type <> stDatagram THEN
         RETURN Sync.arCannotStart;
      END;

      l := MIN2( HIGH( Data )+1, DataAvailable );
      l := winsock.recvfrom( Socket, windows.PSTR( ADR( Data )), l, 0, winsock.Psockaddr( Address.Data ), ADR( la ));
      IF l = winsock.SOCKET_ERROR THEN
         Filled := 0;
         IF winsock.WSAGetLastError() = winsock.WSAEWOULDBLOCK THEN // OK, no data
            RETURN Sync.arNoData;
         ELSE
            RETURN Sync.arAborted;
         END;

      ELSE // l contains data
         Filled := l;
         RETURN Sync.arCompleted;
      END;
   END ReceiveFromOA;

(*--------------------------------------------------------------------------------*)

  PUBLIC PROCEDURE SendOA( CONST Data : ARRAY OF BYTE ) : Sync.TAsyncResult; // uses multicast address
  VAR
    l : CARDINAL;
  BEGIN
    IF _Type <> stDatagram THEN
      RETURN Sync.arCannotStart;
    END;
    l := winsock.sendto( Socket, windows.PSTR( ADR( Data )), HIGH( Data )+1, 0, winsock.Psockaddr( Remote.Data ), Remote.Length );
    IF l = 0 THEN
      RETURN Sync.arCannotStart;
    ELSIF l = HIGH( Data )+1 THEN
      RETURN Sync.arCompleted;
    ELSE
      RETURN Sync.arPartCompleted;
    END;
  END SendOA;

(*--------------------------------------------------------------------------------*)

  PUBLIC PROCEDURE SendToOA( CONST Data : ARRAY OF BYTE; CONST Address : inetaddr.INETADDR ) : Sync.TAsyncResult; // uses given address
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
  END SendToOA;

(*--------------------------------------------------------------------------------*)

   LOCAL VIRTUAL PROCEDURE OnHandle( Result : Sync.TAsyncResult; PoolHandle : threadpool.TPoolHandle; UserId : PTR );
   VAR
      MSG : TSwitchMessage;
      NetworkEvents : winsock.WSANETWORKEVENTS;
      wsaResult : INTEGER;
   BEGIN
      CASE Result OF
      //-----
      | Sync.arCompleted :
         // network
         IF Socket <> winsock.INVALID_SOCKET THEN
            wsaResult := winsock.WSAEnumNetworkEvents( Socket, NIL, ADR( NetworkEvents ));
            IF ( wsaResult = 0 ) AND ( NetworkEvents.lNetworkEvents <> 0 ) THEN
               IF winsock.FD_ACCEPT_BIT IN BITSET( NetworkEvents.lNetworkEvents ) THEN
                  OnFD( winsock.FD_ACCEPT, poListen, NetworkEvents.iErrorCode[ winsock.FD_ACCEPT_BIT ] );
               END;
               IF winsock.FD_READ_BIT IN BITSET( NetworkEvents.lNetworkEvents ) THEN
                  OnFD( winsock.FD_READ, poReceive, NetworkEvents.iErrorCode[ winsock.FD_READ_BIT ] );
               END;
            END;
         END;
         
         // me         
         WHILE _FDSwitch.DequeueOA( OUT MSG, FALSE, 0 ) = Sync.arCompleted DO
            OnFD( MSG.Context, MSG.Operation, MSG.ErrorCode );
         END; // WHILE

      //-----
      | Sync.arAborted :
         IF _Notifier <> NIL THEN
            IF _Type = stDatagram THEN
               _Notifier^.OnDataArrived( winsock.WSAECONNABORTED, ADR( SELF ));
            ELSE
               _Notifier^.OnListen( winsock.WSAECONNABORTED, ADR( SELF ));
            END;
         END;
         _FDHandle := NIL;

      END; // CASE
   END OnHandle;
  
(*--------------------------------------------------------------------------------*)

   INTERNAL VIRTUAL PROCEDURE OnFD( Context : CARDINAL; Operation : TPendingOperationItem; ErrorCode : CARDINAL );
   BEGIN
      IF ( _Type = stDatagram ) AND ( Context <> winsock.FD_READ ) THEN
         RETURN;
      ELSIF ( _Type = stStream ) AND ( Context <> winsock.FD_ACCEPT ) THEN
         RETURN;
      END;
    
      Sync.SignalAndReset( _HSignal );
      IF _Notifier <> NIL THEN
         IF _Type = stDatagram THEN
            _Notifier^.OnDataArrived( ErrorCode, ADR( SELF ));
         ELSE
            _Notifier^.OnListen( ErrorCode, ADR( SELF ));
         END;
      END;
   END OnFD;

(*--------------------------------------------------------------------------------*)

  INTERNAL PROCEDURE Select( Events : BITSET ) : CARDINAL;
  BEGIN
    IF Events = {} THEN
      RETURN winsock.WSAEventSelect( Socket, _FDSignal, CARDINAL( Events ));
    ELSIF _FDHandle = 0 THEN
      netpool.pool()^.WaitHandle( ADR( SELF ), 0, Sync.FOREVER, FALSE, FALSE, _FDSignal, OUT _FDHandle );
    END;
    RETURN winsock.WSAEventSelect( Socket, _FDSignal, CARDINAL( Events ));
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
      MReq.imr_multiaddr := IN_ADDR4( MulticastGroup )^;
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
      MReq.imr_multiaddr := IN_ADDR4( MulticastGroup )^;
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
  _FDHandle := 0;
  _FDSignal := Sync.CreateAutoresetSignal( FALSE, L"" );
  _FDSwitch.Init( 32, SIZE( TSwitchMessage ));
  _FDSwitch.Consume := _FDSignal;
  _HSignal := NIL;
  Result := Sync.arUnknown;
  Socket := winsock.INVALID_SOCKET;
FINALLY
  Close( FALSE );
  IF _Notifier <> NIL THEN
    _Notifier^.Release();
    _Notifier := NIL;
  END;
  Sync.DeleteSignal( REF _FDSignal );
  Sync.DeleteSignal( REF _HSignal );
  _FDSwitch.Consume := NIL;
END SSocket;

(*================================================================================*)

CLASS CDNSNotifier( dns.ADNSNotifier );
  LOCAL VIRTUAL PROCEDURE OnAddressFound( RequestId : PTR; Result : CARDINAL; CONST Address : ARRAY OF inetaddr.INETADDR );
  LOCAL VIRTUAL PROCEDURE OnNameFound( RequestId : PTR; Result : CARDINAL; CONST Name : StringsO.CString );
END CDNSNotifier;

(*--------------------------------------------------------------------------------*)

CLASS IMPLEMENTATION CDNSNotifier;

  LOCAL VIRTUAL PROCEDURE OnAddressFound( RequestId : PTR; Result : CARDINAL; CONST Address : ARRAY OF inetaddr.INETADDR );
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

  PUBLIC PROPERTY RemoteAddress GET : inetaddr.INETADDR;
  BEGIN
    RETURN Remote;
  END RemoteAddress;
  
(*--------------------------------------------------------------------------------*)

  PUBLIC PROPERTY RemoteAddress SET( CONST Value : inetaddr.INETADDR );
  VAR
    Error : CARDINAL;
    Result : Sync.TAsyncResult;
  BEGIN
    IF Remote = Value THEN
      RETURN;
    END;
    IF Socket = winsock.INVALID_SOCKET THEN
      Remote := Value;
      RETURN;
    END;
    Result := ConnectAddress( Remote, FORSAFETY );
    IF ( Result NOT IN Sync.arsStarts ) AND ( _Notifier <> NIL ) THEN
      Error := winsock.WSAGetLastError();
      _Notifier^.OnConnect( Error, ADR( SELF ), TRUE );
      _Notifier^.OnError( IOO.dirUnknown, Error, ADR( SELF ), opConnect );
    END;
  END RemoteAddress;
  
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

   PRIVATE PROCEDURE Open( OUT Error : CARDINAL ) : Sync.TAsyncResult; // socket -- modified variant of SSocket.Open
   BEGIN
      IF _Type = stDatagram THEN
         RETURN SUPER.Open( OUT Error );
      END;
      // now solve stStream
      IF Remote.V6 THEN
         Socket := winsock.socket( winsock.AF_INET6, winsock.SOCK_STREAM, 0 );
      ELSE
         Socket := winsock.socket( winsock.AF_INET, winsock.SOCK_STREAM, 0 );
      END;
      IF Socket = winsock.INVALID_SOCKET THEN
         Error := winsock.WSAGetLastError();
         RETURN Sync.arAborted;
      ELSE
         Error := 0;
         RETURN Sync.arCompleted;
      END;
   END Open;

(*--------------------------------------------------------------------------------*)

   PRIVATE PROCEDURE Close( Persist : BOOLEAN );
   BEGIN
      SUPER.Close( Persist );
   END Close;

(*--------------------------------------------------------------------------------*)

   PUBLIC PROCEDURE Connect( CONST Server : ARRAY OF WCHAR; TimeoutMS : CARDINAL ) : Sync.TAsyncResult;
   VAR
      Addr : inetaddr.INETADDR;
      NumericAddress : BOOLEAN;
   BEGIN
      IF poConnect IN TPendingOperation( _Lock.InclExcl( REF _Pending, BITSET32( TPendingOperation{poConnect} ), BITSET32( posConnectPrerequisities ))) THEN
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

      NumericAddress := Addr.SetAddressOA( Server, 0 );
      IF NumericAddress THEN // we know where to connect immediatelly
         _Lock.Incl( REF _Pending, poConnectResolved ); // fulfill Connect prerequisity
         Remote := Addr;

         IF Disconnect( FALSE, TimeoutMS ) <> Sync.arPending THEN
            // ok, disconnect is immediate, we were not connect
            _Lock.Incl( REF _Pending, poConnectDisconnected ); // fulfill Connect prerequisity
            SwitchContext( FD_INIT, poConnect, 0 ); // ok, everything fulfilled
         END;
      
      ELSE // address is not numeric, it must be queried in DNS
         IF Disconnect( FALSE, TimeoutMS ) <> Sync.arPending THEN
            // ok, disconnect is immediate, we were not connect, probably, continue immedtiately
            _Lock.Incl( REF _Pending, poConnectDisconnected ); // fulfill Connect prerequisity
         END;

         IF poResolveAddress IN TPendingOperation( _Lock.Incl( REF _Pending, poResolveAddress )) THEN
            dns.KillPending( REF ResolveAddr );
         END;

         AddRef(); // allow DNS finish after my Release
         dns.NameToAddress( ADR( DNS ), ADR( SELF ), Server, 0, OUT ResolveAddr );
         // now, wait for DNS and connect after its response
      END;

      RETURN Sync.arPending;
   END Connect;

(*--------------------------------------------------------------------------------*)

  PUBLIC PROCEDURE ConnectAddress( CONST Server : inetaddr.INETADDR; TimeoutMS : CARDINAL ) : Sync.TAsyncResult;
  BEGIN
    IF poConnect IN TPendingOperation( _Lock.InclExcl( REF _Pending, BITSET32( TPendingOperation{poConnect} ), BITSET32( posConnectPrerequisities ))) THEN
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

    // set new connection parameters
    _Lock.Incl( REF _Pending, poConnectResolved ); // fulfill Connect prerequisity
    Remote := Server;

    // kill current connection after setting the address, Disconnect must not finish before assigning the address
    IF Disconnect( FALSE, TimeoutMS ) <> Sync.arPending THEN
       _Lock.Incl( REF _Pending, poConnectDisconnected ); // fulfill Connect prerequisity
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
    Socket := winsock.accept( ServerSocket^.Socket, winsock.Psockaddr( Remote.Data ), ADR( L ));
    IF Socket = winsock.INVALID_SOCKET THEN
      GOTO Failed;
    END;
    L := SIZE( Local );
    Result := winsock.getsockname( Socket, winsock.Psockaddr( Local.Data ), ADR( L ));
    IF Result <> 0 THEN
      GOTO Failed;
    END;

    _Lock.Incl( REF _Pending, poConnection );
    Result := Select( {winsock.FD_READ_BIT, winsock.FD_WRITE_BIT, winsock.FD_CLOSE_BIT} );
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
    Result := Select( {winsock.FD_READ_BIT, winsock.FD_WRITE_BIT, winsock.FD_CLOSE_BIT} );
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
      Close( TRUE );
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

  LOCAL VIRTUAL PROCEDURE OnTimeout( Result : Sync.TAsyncResult; PoolHandle : threadpool.TPoolHandle; UserId : PTR );
  BEGIN
    IF Result = Sync.arCompleted THEN
      SwitchContext( FD_TIMEOUT, TPendingOperationItem( LOPTRLONGWORD( UserId )), winsock.WSAETIMEDOUT );
    END;
  END OnTimeout;

(*--------------------------------------------------------------------------------*)

   LOCAL VIRTUAL PROCEDURE OnHandle( Result : Sync.TAsyncResult; PoolHandle : threadpool.TPoolHandle; UserId : PTR );
   VAR
      LPending : TPendingOperation;
      MSG : TSwitchMessage;
      NetworkEvents : winsock.WSANETWORKEVENTS;
      wsaResult : INTEGER;
   BEGIN
      CASE Result OF
      //-----
      | Sync.arCompleted :
         // network
         IF Socket <> winsock.INVALID_SOCKET THEN
            wsaResult := winsock.WSAEnumNetworkEvents( Socket, NIL, ADR( NetworkEvents ));
            IF ( wsaResult = 0 ) AND ( NetworkEvents.lNetworkEvents <> 0 ) THEN
               IF winsock.FD_ACCEPT_BIT IN BITSET( NetworkEvents.lNetworkEvents ) THEN
                  SUPER.OnFD( winsock.FD_ACCEPT, poListen, NetworkEvents.iErrorCode[ winsock.FD_ACCEPT_BIT ] );
               END;
               IF winsock.FD_CONNECT_BIT IN BITSET( NetworkEvents.lNetworkEvents ) THEN
                  OnFD( winsock.FD_CONNECT, poConnect, NetworkEvents.iErrorCode[ winsock.FD_CONNECT_BIT ] );
               END;
               IF winsock.FD_WRITE_BIT IN BITSET( NetworkEvents.lNetworkEvents ) THEN
                  OnFD( winsock.FD_WRITE, poSend, NetworkEvents.iErrorCode[ winsock.FD_WRITE_BIT ] );
               END;
               IF winsock.FD_READ_BIT IN BITSET( NetworkEvents.lNetworkEvents ) THEN
                  OnFD( winsock.FD_READ, poReceive, NetworkEvents.iErrorCode[ winsock.FD_READ_BIT ] );
               END;
               IF winsock.FD_CLOSE_BIT IN BITSET( NetworkEvents.lNetworkEvents ) THEN
                  OnFD( winsock.FD_CLOSE, poDisconnect, NetworkEvents.iErrorCode[ winsock.FD_CLOSE_BIT ] );
               END;
            END;
         END;

         // me         
         WHILE _FDSwitch.DequeueOA( OUT MSG, FALSE, 0 ) = Sync.arCompleted DO
            OnFD( MSG.Context, MSG.Operation, MSG.ErrorCode );
         END; // WHILE

      //-----
      | Sync.arAborted :
         LPending := TPendingOperation( _Lock.Get( REF _Pending ));
         IF poListen IN LPending THEN
            SUPER.OnHandle( Result, PoolHandle, UserId );
         ELSIF poConnect IN LPending THEN
            OnConnect( FD_ABORT, winsock.WSAECONNABORTED );
         ELSE
            OnDisconnect( FD_ABORT, winsock.WSAECONNABORTED, TRUE );
         END;
         _FDHandle := 0;

      //-----
      END; // CASE
   END OnHandle;

(*--------------------------------------------------------------------------------*)

   INTERNAL VIRTUAL PROCEDURE OnFD( Context : CARDINAL; Operation : TPendingOperationItem; ErrorCode : CARDINAL );
   VAR
      InDisconnect : BOOLEAN;
      LPending : TPendingOperation;
   BEGIN
      CASE Context OF
      //-----
      | FD_INIT :
         CASE Operation OF
         | poConnect :
            StartConnect();
         | poDisconnect :
            ErrorCode := Dispose();
            IF ErrorCode <> 0 THEN
               OnDisconnect( FD_INIT, ErrorCode, TRUE );
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
         CASE Operation OF
         | poConnect :
            OnConnect( FD_TIMEOUT, ErrorCode );
         | poDisconnect :
            OnDisconnect( FD_TIMEOUT, ErrorCode, TRUE );
         | poReceive :
            CompleteFlow( poReceive, TRUE, Sync.arTimeout, 0 );
         | poSend :
            CompleteFlow( poSend, TRUE, Sync.arTimeout, 0 );
         END; // CASE

      //-----
      | winsock.FD_CONNECT :
         OnConnect( winsock.FD_CONNECT, ErrorCode );

      //-----
      | winsock.FD_CLOSE : // everything should be read out
         InDisconnect := _Lock.In( REF _Pending, poDisconnect );
         IF NOT InDisconnect AND ( ErrorCode = 0 ) THEN // remote side graceful close, send rest of my data and notify I am ended
            Dispose();
         END;
         OnDisconnect( winsock.FD_CLOSE, ErrorCode, InDisconnect );

      //-----
      | FD_DNS :
         CASE Operation OF
         | poResolveAddress :
            LPending := TPendingOperation( _Lock.InclExcl( REF _Pending, BITSET32( TPendingOperation{poConnectResolved} ), BITSET32( TPendingOperation{poResolveAddress} )));
            LPending := LPending + TPendingOperation{poConnectResolved}; // local copy
            IF ErrorCode = winsock.WSAECONNABORTED THEN
               // request was aborted, I know this
            ELSIF ErrorCode <> 0 THEN
               OnConnect( FD_DNS, ErrorCode );
            ELSIF LPending * posConnectPrerequisities = posConnectPrerequisities THEN
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
   END OnFD;

(*--------------------------------------------------------------------------------*)

   LOCAL PROCEDURE OnAddressFound( Result : CARDINAL; CONST Address : ARRAY OF inetaddr.INETADDR );
   VAR
      aiV4, aiV6 : inetaddr.INETADDR;
      Filled : CARDINAL;
      haveV4, haveV6 : BOOLEAN := FALSE;
      i : CARDINAL;
   BEGIN
      IF Result = 0 THEN
         Result := winsock.WSAHOST_NOT_FOUND;
         FOR i := 0 TO HIGH( Address ) DO
            IF NOT haveV6 AND Address[i].V6 AND ( Address[i].Scope <> inetaddr.scoLocalLink ) THEN // TODO: address can be select by Local address too (use address by selected interface)
               haveV6 := TRUE;
               Address[i].ToOA( OUT aiV6, OUT Filled );
            ELSIF NOT haveV4 AND NOT Address[i].V6 THEN
               haveV4 := TRUE;
               Address[i].ToOA( OUT aiV4, OUT Filled );
            END;
         END;
         CASE _V6Mode OF
         | v6mV4 :
            IF haveV4 THEN
               Result := 0;
               Remote := aiV4;
            END;            
         | v6mPreferV4 :
            IF haveV4 THEN
               Result := 0;
               Remote := aiV4;
            ELSIF haveV6 THEN
               Result := 0;
               Remote := aiV6;
            END;            
         | v6mPreferV6 :
            IF haveV6 THEN
               Result := 0;
               Remote := aiV6;
            ELSIF haveV4 THEN
               Result := 0;
               Remote := aiV4;
            END;            
         | v6mV6 :
            IF haveV6 THEN
               Result := 0;
               Remote := aiV6;
            END;            
         END; // CASE
      END;
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
    AResult : Sync.TAsyncResult;
    MSG : TSwitchMessage;
  BEGIN
    IF _FDHandle = 0 THEN
      netpool.pool()^.WaitHandle( ADR( SELF ), 0, Sync.FOREVER, FALSE, FALSE, _FDSignal, OUT _FDHandle );
    END;
    
    MSG.Context := FromContext;
    MSG.Operation := Operation;
    MSG.ErrorCode := Result;
    
    AResult := _FDSwitch.EnqueueOA( MSG, TRUE, FORSAFETY );
    ASSERT( AResult <> Sync.arTimeout );
  END SwitchContext;

(*--------------------------------------------------------------------------------*)

   PRIVATE PROCEDURE StartConnect();
   VAR
      Error : CARDINAL;
      Result : Sync.TAsyncResult;
      wb : windows.BOOL := windows.True;
   BEGIN
      ASSERT( _Pending * posConnectPrerequisities = posConnectPrerequisities );
      Result := Open( OUT Error );
    
      IF Result NOT IN Sync.arsStarts THEN
         // fall down to process error
    
      ELSIF _Type = stDatagram THEN
         Error := Select( {winsock.FD_READ_BIT, winsock.FD_WRITE_BIT} );
         // multicast group already joined from Open
         IF ( Error = 0 ) AND Remote.Broadcast THEN // set broadcast flag
            Error := winsock.setsockopt( Socket, winsock.SOL_SOCKET, winsock.SO_BROADCAST, windows.PSTR( ADR( wb )), SIZE( wb ));
         END;
         IF Error = 0 THEN
            Error := winsock.connect( Socket, winsock.Psockaddr( Remote.Data ), Remote.Length );
         END;

      ELSE // _Type = stStream
         Error := StartKeepAlive();
         IF Error = 0 THEN
            Error := Select( {winsock.FD_CONNECT_BIT, winsock.FD_READ_BIT, winsock.FD_WRITE_BIT, winsock.FD_CLOSE_BIT} );
         END;
         IF Error = 0 THEN
            Error := winsock.connect( Socket, winsock.Psockaddr( Remote.Data ), Remote.Length );
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
      LPending := TPendingOperation( _Lock.InclExcl( REF _Pending, BITSET32( TPendingOperation{poConnection} ), BITSET32( posConnectPrerequisities )));
    ELSE
      LPending := TPendingOperation( _Lock.InclExcl( REF _Pending, {}, BITSET32( posConnectPrerequisities )));
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
      L := SIZE( Local );
      winsock.getsockname( Socket, winsock.Psockaddr( Local.Data ), ADR( L ));
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
    LPending := TPendingOperation( _Lock.InclExcl( REF _Pending, BITSET32( TPendingOperation{poConnectDisconnected} ), BITSET32( TPendingOperation{poConnection, poDisconnect} )));
    LPending := LPending + TPendingOperation{poConnectDisconnected};
    
    // abort pending IOs
    CompleteFlow( poSend, TRUE, Sync.arAborted, Error );
    CompleteFlow( poReceive, TRUE, Sync.arAborted, Error );
    SELF.Local.Clear();
    
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
    IF ( Context <> FD_ABORT ) AND ( posConnectPrerequisities * LPending = posConnectPrerequisities ) THEN // disconnect caused inside connect, connect is not waiting for DNS
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
    fa : inetaddr.INETADDR;
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
          l := winsock.recvfrom( Socket, a, l, 0, winsock.Psockaddr( fa.Data ), ADR( la ));
        ELSE
          l := winsock.recv( Socket, a, l, 0 );
        END;
      ELSE
        IF _Type = stDatagram THEN
          l := winsock.sendto( Socket, a, l, 0, winsock.Psockaddr( Remote.Data ), Remote.Length );
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
          IF Remote.Broadcast THEN
            // I am receiving broadcast, pass down
          ELSIF Remote = fa THEN
            // I am receiving from expected partner, pass down
          ELSIF RemoteAddress.Multicast THEN
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
      netpool.pool()^.Abort( REF Timeout[Operation] );
    END;
    IF _Timeout <> Sync.FOREVER THEN
      netpool.pool()^.WaitTimeout( ADR( SELF ), PTR( Operation ), _Timeout, TRUE, FALSE, OUT Timeout[Operation] );
    END;
  END StartTimeout;

(*--------------------------------------------------------------------------------*)

  PRIVATE PROCEDURE StopTimeout( Operation : TPendingOperationItem );
  BEGIN
    IF Timeout[Operation] <> NIL THEN
      netpool.pool()^.Abort( REF Timeout[Operation] );
    END;
  END StopTimeout;

(*--------------------------------------------------------------------------------*)

BEGIN
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