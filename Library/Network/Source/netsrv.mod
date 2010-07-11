IMPLEMENTATION MODULE netsrv;

//================================================================================

FROM Debug IMPORT
   Assertion, LogAssertionW;

FROM Storage IMPORT
  ALLOCATE, DEALLOCATE;

IMPORT
  winsock;

IMPORT
  IOO,
  iphlpapi,
  iptypes,
  lists,
  log,
  msghandler,
  msgqueue,
  netpool,
  Storage,
  Strings,
  Sync,
  threadpool,
  winerror,
  WS2TcpIp;

CONST
   logPrefix = L"netsrv";

(*================================================================================*)

CLASS IMPLEMENTATION AInterfaceEnumerator;
END AInterfaceEnumerator;

(*--------------------------------------------------------------------------------*)

CLASS CInterfaceEnumerator( AInterfaceEnumerator );
   PRIVATE VAR
      _Index : CARDINAL;
      Buffer : iptypes.PIP_ADAPTER_ADDRESSES;
      Current : iptypes.PIP_ADAPTER_ADDRESSES;

   LOCAL PROCEDURE Init( IPV4 : BOOLEAN; IPV6 : BOOLEAN ) : POINTER TO AInterfaceEnumerator;

   PUBLIC VIRTUAL PROCEDURE Reset();
   PUBLIC VIRTUAL PROCEDURE MoveNext() : BOOLEAN;
   
   PUBLIC VIRTUAL READONLY PROPERTY
      Index : CARDINAL;
      State : TState;
      Medium : TMedium;
      Addresses : CARDINAL;
      
   PUBLIC VIRTUAL PROCEDURE HWAddress( OUT Address : ARRAY OF BYTE; OUT Filled : CARDINAL );
   PUBLIC VIRTUAL PROCEDURE InetAddress( Index : CARDINAL; OUT Address : inetaddr.INETADDR; OUT Preferred : BOOLEAN; OUT Scope : inetaddr.TScope; OUT Assignment : TAssignment ) : BOOLEAN;
END CInterfaceEnumerator;

(*================================================================================*)

CLASS IMPLEMENTATION CInterfaceEnumerator;

(*--------------------------------------------------------------------------------*)

   LOCAL PROCEDURE Init( IPV4 : BOOLEAN; IPV6 : BOOLEAN ) : POINTER TO AInterfaceEnumerator;
   VAR
      bufferSize : CARDINAL;
      family : CARDINAL;
      flags : CARDINAL;
   BEGIN
      DEALLOCATE( OUT Buffer );
      Reset();

      IF IPV4 AND IPV6 THEN
         family := winsock.AF_UNSPEC;
      ELSIF IPV4 THEN
         family := winsock.AF_INET;
      ELSIF IPV6 THEN
         family := winsock.AF_INET6;
      ELSE
         RETURN ADR( SELF );
      END;
      flags := iptypes.GAA_FLAG_INCLUDE_PREFIX OR
               iptypes.GAA_FLAG_SKIP_ANYCAST OR
               iptypes.GAA_FLAG_SKIP_MULTICAST OR
               iptypes.GAA_FLAG_SKIP_FRIENDLY_NAME OR
               iptypes.GAA_FLAG_SKIP_DNS_SERVER;
   
      IF iphlpapi.GetAdaptersAddresses( family, flags, NIL, Buffer, ADR( bufferSize )) <> winerror.ERROR_BUFFER_OVERFLOW THEN
         RETURN ADR( SELF );
      END;
      
      ALLOCATE( OUT Buffer, bufferSize );
      IF iphlpapi.GetAdaptersAddresses( family, flags, NIL, Buffer, ADR( bufferSize )) <> winerror.ERROR_SUCCESS THEN
         DEALLOCATE( OUT Buffer );
      END;

      RETURN ADR( SELF );
   END Init;

(*--------------------------------------------------------------------------------*)

   PUBLIC VIRTUAL PROCEDURE Reset();
   BEGIN
      Current := NIL;
      _Index := -1;
   END Reset;

(*--------------------------------------------------------------------------------*)

   PUBLIC VIRTUAL PROCEDURE MoveNext() : BOOLEAN;
   BEGIN
      IF Buffer = NIL THEN
         RETURN FALSE;
      ELSIF Current = NIL THEN
         Current := Buffer;
      ELSE
         Current := Current^.Next;
      END;
      IF Current = NIL THEN
         DEALLOCATE( OUT Buffer );
         RETURN FALSE;
      ELSE
         INC( _Index );
         RETURN TRUE;
      END;
   END MoveNext;

(*--------------------------------------------------------------------------------*)
   
   PUBLIC VIRTUAL PROPERTY Index GET : CARDINAL;
   BEGIN
      IF Current = NIL THEN
         RETURN -1;
      ELSE
         RETURN _Index;
      END;
   END Index;

(*--------------------------------------------------------------------------------*)

   PUBLIC VIRTUAL PROPERTY State GET : TState;
   BEGIN
      IF Current = NIL THEN
         RETURN stUnknown;
      ELSIF Current^.OperStatus = iptypes.IfOperStatusUp THEN
         RETURN stUp;
      ELSE
         RETURN stDown;
      END;
   END State;

(*--------------------------------------------------------------------------------*)

   PUBLIC VIRTUAL PROPERTY Medium GET : TMedium;
   BEGIN
      IF Current = NIL THEN
         RETURN medUnknown;
      END;
      CASE CARDINAL( Current^.IfType ) OF
      | iptypes.IF_TYPE_SOFTWARE_LOOPBACK :
         RETURN medLoopback;

      | iptypes.IF_TYPE_ETHERNET_CSMACD,
        iptypes.IF_TYPE_IS088023_CSMACD,
        iptypes.IF_TYPE_IEEE80212,
        iptypes.IF_TYPE_FIBRECHANNEL,
        iptypes.IF_TYPE_FASTETHER,
        iptypes.IF_TYPE_FASTETHER_FX,
        iptypes.IF_TYPE_GIGABITETHERNET :
         RETURN medCSMACD;

      | iptypes.IF_TYPE_IEEE80211 :
         RETURN med80211;

      | iptypes.IF_TYPE_PPP :
         RETURN medPPP;
      
      | iptypes.IF_TYPE_L2_VLAN,
        iptypes.IF_TYPE_L3_IPVLAN :
         RETURN medVLAN;

      | iptypes.IF_TYPE_TUNNEL :
         RETURN medTunnel;

      ELSE
         RETURN medOther;
      END; // CASE
   END Medium;

(*--------------------------------------------------------------------------------*)

   PUBLIC VIRTUAL PROPERTY Addresses GET : CARDINAL;
   VAR
      a : iptypes.PIP_ADAPTER_UNICAST_ADDRESS;
      count : CARDINAL := 0;
   BEGIN
      IF Current = NIL THEN
         RETURN 0;
      END;
      a := Current^.FirstUnicastAddress;
      WHILE a <> NIL DO
         a := a^.Next;
         INC( count );
      END;
      RETURN count;
   END Addresses;

(*--------------------------------------------------------------------------------*)

   PUBLIC VIRTUAL PROCEDURE HWAddress( OUT Address : ARRAY OF BYTE; OUT Filled : CARDINAL );
   VAR
      i, li : CARDINAL;
   BEGIN
      IF Current = NIL THEN
         Filled := 0;
         RETURN;
      END;
      li := MIN2( HIGH( Address ), Current^.PhysicalAddressLength-1 );
      FOR i := 0 TO li DO
         Address[i] := Current^.PhysicalAddress[i];
      END; // FOR
      Filled := li+1;
   END HWAddress;

(*--------------------------------------------------------------------------------*)

   PUBLIC VIRTUAL PROCEDURE InetAddress( Index : CARDINAL; OUT Address : inetaddr.INETADDR; OUT Preferred : BOOLEAN; OUT Scope : inetaddr.TScope; OUT Assignment : TAssignment ) : BOOLEAN;
   VAR
      a : iptypes.PIP_ADAPTER_UNICAST_ADDRESS;
      index : CARDINAL := 0;
   BEGIN
      IF Current = NIL THEN
         RETURN FALSE;
      END;
      a := Current^.FirstUnicastAddress;
      WHILE ( a <> NIL ) AND ( index < Index ) DO
         a := a^.Next;
         INC( index );
      END;
      IF a = NIL THEN
         RETURN FALSE;
      END;

      Address.FromBOA( OA( a^.Address.iSockaddrLength-1, a^.Address.lpSockaddr ));
      Preferred := a^.DadState = iptypes.IpDadStatePreferred;
      Scope := Address.Scope;
      
      CASE a^.PrefixOrigin OF
      | iptypes.IpPrefixOriginManual,
        iptypes.IpPrefixOriginWellKnown :
         Assignment := assFixed;
      | iptypes.IpPrefixOriginDhcp,
        iptypes.IpPrefixOriginRouterAdvertisement :
         Assignment := assDynamic;
      ELSE
         Assignment := assUnknown;
      END; // CASE

      RETURN TRUE;
   END InetAddress;

(*--------------------------------------------------------------------------------*)

BEGIN
   _Index := -1;
   Buffer := NIL;
   Current := NIL;
FINALLY   
   DEALLOCATE( OUT Buffer );
END CInterfaceEnumerator;

(*================================================================================*)

PROCEDURE newInterfaceEnumerator( IPV4 : BOOLEAN; IPV6 : BOOLEAN; OUT Enumerator : TPInterfaceEnumerator ) : BOOLEAN;
VAR
   IE : POINTER TO CInterfaceEnumerator;
BEGIN
   NEW( IE );
   IE^.Init( IPV4, IPV6 );
   Enumerator := IE;
   RETURN TRUE;
END newInterfaceEnumerator;
  
(*================================================================================*)

TYPE
  TPIPServer = POINTER TO CIPServer;

TYPE
  TCommand = (
    cmRegister,
    cmForgetServer,
    cmForgetSocket,
    cmAccept,
    cmDataArrived
  );

  TMessage  = RECORD
                CASE Command : TCommand OF
                | cmRegister, cmForgetSocket :
                  Socket    : netsocket.TPSSocket;
                  Creator   : TPListener;
                  CloseTime : CARDINAL;
                | cmForgetServer :
                  Server    : inetaddr.INETADDR;
                  Type      : netsocket.TSocketType;
                | cmAccept  :
                  __        : netsocket.TPSSocket;
                  Result    : CARDINAL;
                END; // CASE  
              END;
  TPMessage = POINTER TO TMessage;

//================================================================================

CLASS IMPLEMENTATION AListener;

  LOCAL VIRTUAL PROCEDURE OnListen( CONST ServerSocket : netsocket.TPSSocket );
  BEGIN
  END OnListen;

  LOCAL VIRTUAL PROCEDURE OnDatagramReceived( CONST ServerSocket : netsocket.TPSSocket );
  BEGIN
  END OnDatagramReceived;

  LOCAL VIRTUAL PROCEDURE OnListenSocketClosed( CONST ServerSocket : netsocket.TPSSocket );
  BEGIN
  END OnListenSocketClosed;

END AListener;

//================================================================================

CLASS CSocketNotifier( netsocket.ASocketNotifier );
  Server : TPIPServer;
  LOCAL VIRTUAL PROCEDURE OnListen( Result : CARDINAL; CONST Socket : netsocket.TPSSocket );
  LOCAL VIRTUAL PROCEDURE OnDataArrived( Result : CARDINAL; CONST Socket : netsocket.TPSSocket );
END CSocketNotifier;

//--------------------------------------------------------------------------------

CLASS CIPServer( msghandler.MessageHandler );
  _FDHandle : threadpool.TPoolHandle;
  _FDMessager : msghandler.TPMessageHandler;
  _FDMessage : msghandler.Message;
  _Delegate : threadpool.TPMessageHandlerDelegate;

  CBMode : IOO.TCallbackMode := IOO.cbmDefault;
  MQueue : msgqueue.CMessageQueue;
  SocketNotifier : CSocketNotifier;
  Sockets : lists.CPtrList;

  PUBLIC VIRTUAL PROCEDURE Dispose();

  INTERNAL VIRTUAL PROCEDURE OnMessage( CONST MSG : msghandler.IMessage; OUT Result : PTR ) : BOOLEAN;
  INTERNAL VIRTUAL PROCEDURE OnTimer( Timer : PTR );

  LOCAL PROCEDURE SetCallbackMode( Mode : IOO.TCallbackMode );
  LOCAL PROCEDURE StartListen( Type : netsocket.TSocketType; CONST LocalAddress : inetaddr.INETADDR; PMulticastGroup : inetaddr.TPINETADDR; PStreamCreator : TPListener; AutomaticCloseTimeMS : CARDINAL; PCreatedSocket : POINTER TO netsocket.TPSSocket ) : CARDINAL;
  LOCAL PROCEDURE StopListenServer( CONST LocalAddress : inetaddr.INETADDR; Type : netsocket.TSocketType );
  LOCAL PROCEDURE StopListenSocket( Socket : netsocket.TPSSocket );

  PRIVATE PROCEDURE CloseSocket( Socket : netsocket.TPSSocket; Creator : TPListener; Deregister : BOOLEAN );
  PRIVATE PROCEDURE SearchSocket( CONST Server : inetaddr.INETADDR; Type : netsocket.TSocketType; OUT Socket : netsocket.TPSSocket; OUT Creator : TPListener ) : BOOLEAN;
END CIPServer;

//================================================================================

CLASS IMPLEMENTATION CSocketNotifier;

  LOCAL VIRTUAL PROCEDURE OnListen( Result : CARDINAL; CONST Socket : netsocket.TPSSocket );
  VAR
    LResult : Sync.TAsyncResult;
    Message : TMessage;
  BEGIN
    IF Result = 0 THEN
      Message.Command := cmAccept;
      Message.Socket := Socket;
      Message.Result := Result;
      LResult := Server^.MQueue.EnqueueOA( Message, TRUE, Sync.FORSAFETY );
      ASSERTLOG( LResult <> Sync.arTimeout );
    END;
  END OnListen;

  LOCAL VIRTUAL PROCEDURE OnDataArrived( Result : CARDINAL; CONST Socket : netsocket.TPSSocket );
  VAR
    LResult : Sync.TAsyncResult;
    Message : TMessage;
  BEGIN
    IF Result = 0 THEN
      Message.Command := cmDataArrived;
      Message.Socket := Socket;
      Message.Result := Result;
      LResult := Server^.MQueue.EnqueueOA( Message, TRUE, Sync.FORSAFETY );
      ASSERTLOG( LResult <> Sync.arTimeout );
    END;
  END OnDataArrived;

BEGIN
  Server := NIL;
END CSocketNotifier;

//================================================================================

CLASS IMPLEMENTATION CIPServer;

//--------------------------------------------------------------------------------

  PUBLIC VIRTUAL PROCEDURE Dispose();
  VAR
    Socket : netsocket.TPSSocket;
  BEGIN
    IF NOT Sockets.Empty THEN
      Sockets.Reset();
      WHILE Sockets.MoveNext() DO
        Socket := netsocket.TPSSocket( Sockets.Current );
        CloseSocket( Socket, Sockets.CurrentData, FALSE );
      END; // WHILE
      Sockets.Dispose();
    END;
    IF _FDHandle <> NIL THEN
      netpool.pool()^.Abort( REF _FDHandle );
    END;
    IF _Delegate <> NIL THEN
      _Delegate^.Release();
      _Delegate := NIL;
    END;
    SUPER.Dispose();
  END Dispose;

//--------------------------------------------------------------------------------

  INTERNAL VIRTUAL PROCEDURE OnMessage( CONST MSG : msghandler.IMessage; OUT Result : PTR ) : BOOLEAN;
  VAR
    Creator : TPListener;
    Message : TMessage;
    Socket : netsocket.TPSSocket;
  BEGIN
    Result := 0;
    IF SUPER.OnMessage( MSG, OUT Result ) THEN
      RETURN TRUE;
    ELSIF (( _FDHandle = NIL ) OR ( _FDMessage.Message <> MSG.Message )) AND ( MSG.Message <> msgqueue.MSG_PROCESS_QUEUE ) THEN
      RETURN TRUE;
    END;

    WHILE MQueue.DequeueOA( OUT Message, FALSE, 0 ) = Sync.arCompleted DO
      CASE Message.Command OF
      //-----
      | cmRegister :
        Sockets.Add( Message.Socket, Message.Creator );
        IF ( Message.CloseTime <> 0 ) AND ( Message.CloseTime <> Sync.FOREVER ) THEN
          StartTimer( Message.Socket, Message.CloseTime, FALSE );
        END; // IF
      //-----
      | cmForgetServer :
        IF SearchSocket( Message.Server, Message.Type, OUT Socket, OUT Creator ) THEN
          CloseSocket( Socket, Creator, TRUE );
        END;
      //-----
      | cmForgetSocket :
        IF Sockets.Get( Message.Socket, OUT Creator ) THEN
          CloseSocket( Message.Socket, Creator, TRUE );
        END;
      //-----
      | cmAccept :
        IF Message.Result <> 0 THEN
          // skip
        ELSIF Sockets.Get( Message.Socket, OUT Creator ) THEN
          Creator^.OnListen( Message.Socket );
        ELSE
          // flush should not be called here as the socket has already been deallocated
          // Message.Socket^.Flush();
          log.logger()^.LogSP( log.ldMessage, 0, logPrefix, L"Socket not found for cmAccept", Message.Socket );
        END;
      //-----
      | cmDataArrived :
        IF Message.Result <> 0 THEN
          // skip
        ELSIF Sockets.Get( Message.Socket, OUT Creator ) THEN
          Creator^.OnDatagramReceived( Message.Socket );
        ELSE
          // flush should not be called here as the socket has already been deallocated
          // Message.Socket^.Flush();
          log.logger()^.LogSP( log.ldMessage, 0, logPrefix, L"Socket not found for cmDataArrived", Message.Socket );
        END;
      END; // CASE
    END; // WHILE
    
    RETURN TRUE;  
  END OnMessage;

//--------------------------------------------------------------------------------

  INTERNAL VIRTUAL PROCEDURE OnTimer( Timer : PTR );
  VAR
    Socket : netsocket.TPSSocket := netsocket.TPSSocket( Timer );
    Creator : TPListener;
  BEGIN
    IF NOT Sockets.Get( Socket, OUT Creator ) THEN
      RETURN;
    END;
    CloseSocket( Socket, Creator, TRUE );
  END OnTimer;

//--------------------------------------------------------------------------------

  LOCAL PROCEDURE SetCallbackMode( Mode : IOO.TCallbackMode );
  BEGIN
    IF CBMode = Mode THEN
      RETURN;
    END;
    CBMode := Mode;
    IF CBMode = IOO.cbmPooled THEN
      IF _Delegate = NIL THEN
         NEW( _Delegate );
         _Delegate^.Handler := ADR( SELF );
      END;
      IF _FDHandle = NIL THEN
        netpool.pool()^.WaitMessage( _Delegate, 0, Sync.FOREVER, FALSE, FALSE, OUT _FDMessager, OUT _FDMessage, OUT _FDHandle );
      END;
      MQueue.Consumer := _FDMessager;
      MQueue.ConsumerMsg := ADR( _FDMessage );
    ELSE
      MQueue.Consumer := ADR( SELF );
      MQueue.ConsumerMsg := NIL;
    END;
  END SetCallbackMode;

//--------------------------------------------------------------------------------

   LOCAL PROCEDURE StartListen( Type : netsocket.TSocketType; CONST LocalAddress : inetaddr.INETADDR; PMulticastGroup : inetaddr.TPINETADDR; PStreamCreator : TPListener; AutomaticCloseTimeMS : CARDINAL; PCreatedSocket : POINTER TO netsocket.TPSSocket ) : CARDINAL;
   VAR
      countString : ARRAY [0..31] OF WCHAR;
      Error : CARDINAL;
      Message : TMessage;
      Result : Sync.TAsyncResult;
      Socket : netsocket.TPSSocket;
   BEGIN
      IF PStreamCreator = NIL THEN
         RETURN -1;
      ELSE
         PStreamCreator^.AddRef();
      END;

      NEW( Socket );
      Socket^.Type := Type;
      Socket^.LocalAddress := LocalAddress;
      IF PMulticastGroup <> NIL THEN
         Socket^.MulticastGroup := PMulticastGroup^;
      END;
      Result := Socket^.Open( OUT Error );
      IF Result NOT IN Sync.arsStarts THEN
         Socket^.Release();
         RETURN Error;
      END;
      IF PCreatedSocket <> NIL THEN
         PCreatedSocket^ := Socket;
      END;

      Message.Command := cmRegister;
      Message.Creator := PStreamCreator;
      Message.Socket := Socket;
      Message.CloseTime := AutomaticCloseTimeMS;
      Result := MQueue.EnqueueOA( Message, TRUE, Sync.FORSAFETY );
      IF Result NOT IN Sync.arsStarts THEN
         Strings.FromCARD32W( MQueue.Count, 10, OUT countString );
         ASSERTLOG( Result <> Sync.arTimeout, countString );
         Socket^.Release();
         RETURN -1;
      END;
    
      // listen must be started synchronously, to assure that send/receivings done immediatelly after StartListen will be catched
      Socket^.Notifier := ADR( SocketNotifier );
      Result := Socket^.Listen( OUT Error );
      IF Result IN Sync.arsStarts THEN
         RETURN 0;
      ELSE
         StopListenSocket( Socket );
         RETURN Error;
      END;
   END StartListen;

//--------------------------------------------------------------------------------

  LOCAL PROCEDURE StopListenServer( CONST LocalAddress : inetaddr.INETADDR; Type : netsocket.TSocketType );
  VAR
    countString : ARRAY [0..31] OF WCHAR;
    Message : TMessage;
    Result : Sync.TAsyncResult;
  BEGIN
    Message.Command := cmForgetServer;
    Message.Server := LocalAddress;
    Message.Type := Type;
    Result := MQueue.EnqueueOA( Message, TRUE, Sync.FORSAFETY );
    IF Result NOT IN Sync.arsStarts THEN
      Strings.FromCARD32W( MQueue.Count, 10, OUT countString );
      ASSERTLOG( Result <> Sync.arTimeout );
    END;
  END StopListenServer;
  
//--------------------------------------------------------------------------------

  LOCAL PROCEDURE StopListenSocket( Socket : netsocket.TPSSocket );
  VAR
    countString : ARRAY [0..31] OF WCHAR;
    Message : TMessage;
    Result : Sync.TAsyncResult;
  BEGIN
    Message.Command := cmForgetSocket;
    Message.Socket := Socket;
    Result := MQueue.EnqueueOA( Message, TRUE, Sync.FORSAFETY );
    IF Result NOT IN Sync.arsStarts THEN
      Strings.FromCARD32W( MQueue.Count, 10, OUT countString );
      ASSERTLOG( Result <> Sync.arTimeout );
    END;
  END StopListenSocket;

//--------------------------------------------------------------------------------

  PRIVATE PROCEDURE CloseSocket( Socket : netsocket.TPSSocket; Creator : TPListener; Deregister : BOOLEAN );
  BEGIN
    IF Creator <> NIL THEN
      Creator^.OnListenSocketClosed( Socket );
      Creator^.Release();
    END;
    IF Deregister THEN
      Sockets.Remove( Socket );
      StopTimer( Socket );
    END;
    Socket^.Notifier := NIL;
    Socket^.Close( FALSE );
    Socket^.Release();
  END CloseSocket;

//--------------------------------------------------------------------------------

  PRIVATE PROCEDURE SearchSocket( CONST Server : inetaddr.INETADDR; Type : netsocket.TSocketType; OUT Socket : netsocket.TPSSocket; OUT Creator : TPListener ) : BOOLEAN;
  VAR
    LSocket : netsocket.TPSSocket;
  BEGIN
    Sockets.Reset();
    WHILE Sockets.MoveNext() DO
      LSocket := Sockets.Current;
      IF LSocket^.LocalAddress = Server THEN
        Socket := LSocket;
        Creator := Sockets.CurrentData;
        RETURN TRUE;
      END;
    END; // WHILE
    RETURN FALSE;
  END SearchSocket;

//--------------------------------------------------------------------------------

BEGIN
  _FDHandle := NIL;
  _FDMessager := NIL;
  _Delegate := NIL;
  MQueue.Init( 32, SIZE( TMessage ));
  MQueue.Consumer := ADR( SELF );
  SocketNotifier.Server := ADR( SELF );
FINALLY
  Dispose();
END CIPServer;

//================================================================================

VAR
  IPServer : POINTER TO CIPServer;

PROCEDURE SetCallbackMode(
            Mode : IOO.TCallbackMode
          );
BEGIN
   ASSERT( IPServer <> NIL );
   IPServer^.SetCallbackMode( Mode );
END SetCallbackMode;

PROCEDURE StartListen(
            Type : netsocket.TSocketType;
            CONST LocalAddress : inetaddr.INETADDR; // can be empty, can contain port only, can be exact address/port pair
            PMulticastGroup : inetaddr.TPINETADDR;  // can be NIL
            PStreamCreator : TPListener;
            AutomaticCloseTimeMS : CARDINAL;	// can be 0 or INFINITE
            PCreatedSocket : POINTER TO netsocket.TPSSocket // can be NIL
          ) : CARDINAL;
BEGIN
   ASSERT( IPServer <> NIL );
   RETURN IPServer^.StartListen( Type, LocalAddress, PMulticastGroup, PStreamCreator, AutomaticCloseTimeMS, PCreatedSocket );
END StartListen;

PROCEDURE StopListenServer( Type : netsocket.TSocketType; CONST LocalAddress : inetaddr.INETADDR );
BEGIN
   ASSERT( IPServer <> NIL );
   IPServer^.StopListenServer( LocalAddress, Type );
END StopListenServer;

PROCEDURE StopListenSocket( REF Socket : netsocket.TPSSocket );
BEGIN
   ASSERT( IPServer <> NIL );
   IPServer^.StopListenSocket( Socket );
   Socket := NIL;
END StopListenSocket;

PROCEDURE Startup();
BEGIN
   IF IPServer = NIL THEN
      NEW( IPServer );
      IPServer^.Init( TRUE );
   END;
END Startup;

PROCEDURE Cleanup();
BEGIN
   IF IPServer <> NIL THEN
      DISPOSE( IPServer );
   END;
END Cleanup;

//================================================================================

END netsrv.