IMPLEMENTATION MODULE eibnet;

FROM Storage IMPORT
   ALLOCATE, DEALLOCATE;
   
FROM Log IMPORT
   LOG, dldTrace, dldDebug;

IMPORT
   dns,
   eib_def;

(*================================================================================*)

CLASS IMPLEMENTATION EIBNetListener;

(*--------------------------------------------------------------------------------*)

   LOCAL VIRTUAL PROCEDURE OnDatagramReceived( CONST ServerSocket : netsocket.TPSSocket );
   BEGIN
      IF Connection <> NIL THEN
         Connection^.OnDatagramReceived( ServerSocket );
      END;
   END OnDatagramReceived;

(*--------------------------------------------------------------------------------*)

   LOCAL VIRTUAL PROCEDURE OnListenSocketClosed( CONST ServerSocket : netsocket.TPSSocket );
   BEGIN
      IF Connection <> NIL THEN
         Connection^.OnListenSocketClosed( ServerSocket );
      END;
   END OnListenSocketClosed;

(*--------------------------------------------------------------------------------*)

BEGIN
END EIBNetListener;

(*================================================================================*)

TYPE
   TTimers = (
      tiUnknown,
      tiConnect,
      tiDisconnect,
      tiHeartbeat,
      tiHeartbeatRepeat,
      tiACK,
      tiAutoReconnect
   );

(*--------------------------------------------------------------------------------*)

CLASS IMPLEMENTATION CConnection;

(*--------------------------------------------------------------------------------*)

   PUBLIC PROPERTY Mode GET : TConnectionMode;
   BEGIN
      RETURN _Mode;
   END Mode;

(*--------------------------------------------------------------------------------*)

   PUBLIC PROPERTY Mode SET( Value : TConnectionMode );
   VAR
      Address : winsock.IN_ADDR;
      l : CARDINAL;
      wasConnected : BOOLEAN := NOT Disconnected;
   BEGIN
      IF _Mode = Value THEN
         RETURN;
      ELSIF wasConnected THEN
         Disconnect( TRUE );
      END;

      // set itself
      _Mode := Value;
      IF _Mode = cmTunnelingHPAI THEN
         Address.s_addr := 0;
         dns.GetLocalIPs( 5000, OUT OA( 0, ADR( Address )), OUT l );
         HPAISelf.Address := Address;
      ELSIF _Mode = cmTunnelingBlind THEN
         HPAISelf.Address := netsocket.INADDR_EMPTY;
      END;

      IF wasConnected THEN // reconnect if it was connected
         Connect( 0 );
      END;
   END Mode;

(*--------------------------------------------------------------------------------*)

   PUBLIC PROPERTY RemoteAddress GET : winsock.IN_ADDR; // routing or remote address
   BEGIN
      RETURN HPAIData.Address;
   END RemoteAddress;

(*--------------------------------------------------------------------------------*)

   PUBLIC PROPERTY RemoteAddress SET( CONST Value : winsock.IN_ADDR ); // routing or remote address
   VAR
      Address : winsock.IN_ADDR;
      wasConnected : BOOLEAN := NOT Disconnected;
   BEGIN
      Address := HPAIData.Address;
      // IF HPAIData.Address = Value THEN // TO DO: equalsm negeneruje naèítání do pomocné promìnné
      IF Address = Value THEN
         RETURN;
      ELSIF wasConnected THEN
         Disconnect( TRUE );
      END;

      // set itself
      HPAIData.Address := Value;
      IF winsock.IN_MULTICAST( REVERSE( Value.s_addr )) THEN
         HPAIData.Port := core.EIBNET_IPPORT;
      ELSE
         HPAICtrl.Address := Value;
      END;

      IF wasConnected THEN // reconnect if it was connected
         Connect( 0 );
      END;
   END RemoteAddress;

(*--------------------------------------------------------------------------------*)

   PUBLIC PROPERTY RemotePort GET : CARDINAL;
   BEGIN
      RETURN HPAICtrl.Port;
   END RemotePort;

(*--------------------------------------------------------------------------------*)

   PUBLIC PROPERTY RemotePort SET( Value : CARDINAL ); // routing or remote address
   VAR
      wasConnected : BOOLEAN := NOT Disconnected;
   BEGIN
      IF HPAICtrl.Port = Value THEN
         RETURN;
      ELSIF wasConnected THEN
         Disconnect( TRUE );
      END;

      // set itself
      HPAICtrl.Port := Value;
      IF winsock.IN_MULTICAST( REVERSE( HPAIData.Address.s_addr )) THEN
         HPAIData.Port := core.EIBNET_IPPORT;
      ELSIF _Mode = cmTunnelingBlind THEN
         HPAIData.Port := HPAICtrl.Port;
      END;

      IF wasConnected THEN // reconnect if it was connected
         Connect( 0 );
      END;
   END RemotePort;

(*--------------------------------------------------------------------------------*)

   PUBLIC PROPERTY AutoReconnectDelay GET : CARDINAL;
   BEGIN
      RETURN _AutoReconnectDelay;
   END AutoReconnectDelay;

(*--------------------------------------------------------------------------------*)

   PUBLIC PROPERTY AutoReconnectDelay SET( Value : CARDINAL );
   BEGIN
      IF Value = _AutoReconnectDelay THEN
         RETURN;
      END;
      _AutoReconnectDelay := Value;
      IF _AutoReconnectDelay = 0 THEN
         StopTimer( PTR( tiAutoReconnect ));
      END;
   END AutoReconnectDelay;

(*--------------------------------------------------------------------------------*)

   PUBLIC PROPERTY Connected GET : BOOLEAN;
   BEGIN
      RETURN ( IOState = ioReady ) OR ( IOState = ioWaitACK1 ) OR ( IOState = ioWaitACK2 );
   END Connected;

(*--------------------------------------------------------------------------------*)

   PUBLIC PROPERTY Disconnected GET : BOOLEAN;
   BEGIN
      RETURN ( IOState = ioDisconnecting ) OR ( IOState = ioDisconnected );
   END Disconnected;

(*--------------------------------------------------------------------------------*)

   PUBLIC PROPERTY Pending GET : BOOLEAN;
   BEGIN
      RETURN ( IOState = ioWaitACK1 ) OR ( IOState = ioWaitACK2 );
   END Pending;

(*--------------------------------------------------------------------------------*)

   INTERNAL VIRTUAL PROCEDURE OnTimer( TimerId : PTR );
   BEGIN
      CASE TTimers( TimerId ) OF
      //----
      | tiConnect :
         LOG.LogS( dldTrace, L"EIBNet Connection", L"CONNECT timeout" );

         DeviceDisconnect();

      //----
      | tiDisconnect :
         LOG.LogSC( dldTrace, L"EIBNet Connection", L"DISCONNECT timeout: ", CARDINAL( ChannelId ));

         DeviceDisconnect();

      //-----
      | tiACK :
         IF IOState = ioWaitACK1 THEN // resend data
            LOG.LogSC( dldTrace, L"EIBNet Connection", L"R_CON timeout, repeat SEND: ", CARDINAL( ChannelId ));

            IOState := ioWaitACK2;
            DoSend();
         ELSIF IOState = ioWaitACK2 THEN
            LOG.LogSC( dldTrace, L"EIBNet Connection", L"R_CON timeout, kill SEND: ", CARDINAL( ChannelId ));

            // INC( OutSeq ); // prepare next writing -- unable to do, if remote peer does not ACKs packet, it expects ONLY the next one... Maybe, it should accept newer packets, but it does not do so
            INC( SendErr ); // increment connection recovery counter
            IOState := ioReady;

            On_L_CON( eib_status.essL_Timeout );

         ELSE
            ASSERT( FALSE );
         END;

      //-----
      | tiHeartbeat :
         ProcessHbFailure();

      //-----
      | tiHeartbeatRepeat :
         ProcessHbFailure();
         
      //-----
      | tiAutoReconnect :
         Connect( 0 );

      END;
   END OnTimer;

(*--------------------------------------------------------------------------------*)

   PUBLIC PROCEDURE Connect( Timeout : CARDINAL ) : Sync.TAsyncResult;
   VAR
      cr : core.ConnectRequest;
      timeout : CARDINAL := 0;
      b : BOOLEAN;
   BEGIN
      IF IOState = ioDisconnecting THEN
         RETURN Sync.arCannotStart;
      ELSIF IOState <> ioDisconnected THEN
         RETURN Sync.arAlreadyPending;
      END;

      IF _Mode = cmScanning THEN
         IF Timeout = 0 THEN
            timeout := BROWSE_TIMEOUT;
         ELSE
            timeout := Timeout;
         END;
         b := FALSE;
      ELSE
         b := netsrv.StartListen( netsocket.stDatagram, core.EIBNET_IPPORT, NIL, Listener, 0, ADR( Socket )) = 0;
      END;
      IF NOT b THEN
         b := netsrv.StartListen( netsocket.stDatagram, 0, NIL, Listener, timeout, ADR( Socket )) = 0;
      END;
      IF b THEN
         LOG.LogSP( dldTrace, L"EIBNet Connection", L"CONNECT request: ", Socket );
      ELSE
         LOG.LogS( dldTrace, L"EIBNet Connection", L"CONNECT (listen) cannot start" );
         Socket := NIL;
         RETURN Sync.arCannotStart;
      END;
      IF _Mode = cmTunnelingBlind THEN
        HPAISelf.Port := 0;
      ELSE
        HPAISelf.Port := Socket^.LocalPort;
      END;

      CASE _Mode OF
      //-----
      | cmScanning :
         Socket^.MulticastGroup := core.EIBNET_DISCOVERY_ADDRESS;
         Socket^.MulticastPort := core.EIBNET_IPPORT;
         IOState := ioReady;

         LOG.LogSP( dldTrace, L"EIBNet Connection", L"CONNECTed in SCANNING mode: ", Socket );
         RETURN Sync.arCompleted;
      //-----
      | cmRouting :
         Socket^.MulticastGroup := HPAIData.Address;
         Socket^.MulticastPort := core.EIBNET_IPPORT;
         IOState := ioReady;
         OnConnect();

         LOG.LogSP( dldTrace, L"EIBNet Connection", L"CONNECTed in ROUTING mode: ", Socket );
         RETURN Sync.arCompleted;
      //-----
      | cmTunnelingHPAI, cmTunnelingBlind :
         IOState := ioConnecting;
         StartTimer( PTR( tiConnect ), CONNECT_TIMEOUT, FALSE );
      END;
      
      cr.ControlHPAI := HPAISelf;
      cr.DataHPAI := HPAISelf;
      RETURN Socket^.SendToOA( OA( cr.Length-1, ADR( cr )), HPAICtrl.Address, HPAICtrl.Port );
   END Connect;

(*--------------------------------------------------------------------------------*)

   PUBLIC PROCEDURE Disconnect( Abortive : BOOLEAN ) : Sync.TAsyncResult;
   VAR
      dr : core.DisconnectRequest;
      abortive : BOOLEAN := FALSE;
   BEGIN
      IF Abortive AND ( IOState <> ioDisconnected ) THEN
         abortive := TRUE;
         LOG.LogS( dldTrace, L"EIBNet Connection", L"DISCONNECT forced as abortive" );
      ELSIF Disconnected THEN
         RETURN Sync.arCompleted;
      END;

      LOG.LogSCP( dldTrace, L"EIBNet Connection", L"DISCONNECT request: ", CARDINAL( ChannelId ), Socket );

      DataDisconnect();

      IF abortive THEN
         DeviceDisconnect();
      ELSIF ( _Mode = cmTunnelingHPAI ) OR ( _Mode = cmTunnelingBlind ) THEN
         StartTimer( PTR( tiDisconnect ), DISCONNECT_TIMEOUT, FALSE );
         dr.ControlHPAI := HPAISelf;
         dr.ChannelId := ChannelId;
         RETURN Socket^.SendToOA( OA( dr.Length-1, ADR( dr )), HPAICtrl.Address, HPAICtrl.Port );
      ELSE
         DeviceDisconnect();
      END;
      RETURN Sync.arCompleted;
   END Disconnect;

(*--------------------------------------------------------------------------------*)

   PUBLIC PROCEDURE SendPacket( CONST EMI : eib_def.TPacket ) : Sync.TAsyncResult;
   BEGIN
      IF ( IOState = ioDisconnected ) OR ( IOState = ioConnecting ) OR ( IOState = ioDisconnecting ) THEN
         LOG.LogS( dldTrace, L"EIBNet Connection", L"SEND request when disconnected" );
         RETURN Sync.arCannotStart;
      ELSIF _Mode = cmScanning THEN
         LOG.LogS( dldTrace, L"EIBNet Connection", L"SEND request in scanning mode" );
         RETURN Sync.arCannotStart;
      ELSIF IOState <> ioReady THEN
         LOG.LogSC( dldTrace, L"EIBNet Connection", L"SEND request when not ready: ", CARDINAL( ChannelId ));
         RETURN Sync.arAlreadyPending;
      END;
      SELF.EMI := EMI;

      IF _Mode = cmRouting THEN
         // IOState := ioReady; during routing stay in the state
      ELSIF ( _Mode = cmTunnelingHPAI ) OR ( _Mode = cmTunnelingBlind ) THEN
         IOState := ioWaitACK1;
      END;

      RETURN DoSend();
   END SendPacket;
   
(*--------------------------------------------------------------------------------*)

   LOCAL PROCEDURE OnDatagramReceived( CONST ServerSocket : netsocket.TPSSocket );
   VAR
      buffer : ARRAY [0..255] OF BYTE;
      l : CARDINAL;
      packet : core.TPPacket := core.TPPacket( ADR( buffer ));
   BEGIN
      l := ServerSocket^.DataAvailable;
      IF l = 0 THEN
         RETURN;
      END;
      ServerSocket^.ReceiveOA( OUT OA( l-1, ADR( buffer )), OUT l );
      
      CASE _Mode OF
      //-----
      | cmScanning :
         CASE packet^.Service OF
         | core.SEARCH_RESPONSE,
           core.DESCRIPTION_RESPONSE :
         ELSE
            LOG.LogSCP( dldDebug, L"EIBNet Connection", L"packet rejected in SCANNING mode: ", CARDINAL( ChannelId ), PTR( packet^.Service ));
            RETURN;
         END; // Service
      //-----
      | cmRouting :
         CASE packet^.Service OF
         | core.DESCRIPTION_RESPONSE,
           core.ROUTING_INDICATION,
           core.ROUTING_LOST_MESSAGE :
         ELSE
            LOG.LogSCP( dldDebug, L"EIBNet Connection", L"packet rejected in ROUTING mode: ", CARDINAL( ChannelId ), PTR( packet^.Service ));
            RETURN;
         END; // Service
      //-----
      | cmTunnelingHPAI, cmTunnelingBlind :
         CASE packet^.Service OF
         | core.DESCRIPTION_RESPONSE :
         | core.CONNECT_RESPONSE :
            IF IOState <> ioConnecting THEN
               LOG.LogSCP( dldDebug, L"EIBNet Connection", L"packet rejected as unexpected: ", CARDINAL( ChannelId ), PTR( packet^.Service ));
               RETURN;
            END;
         | core.CONNECTIONSTATE_RESPONSE,
           core.DISCONNECT_REQUEST,
           core.DISCONNECT_RESPONSE,
           core.TUNNELING_REQUEST,
           core.TUNNELING_ACK :
            IF IOState < ioReady THEN
               LOG.LogSCP( dldDebug, L"EIBNet Connection", L"packet rejected as unexpected: ", CARDINAL( ChannelId ), PTR( packet^.Service ));
               RETURN;
            END;
         ELSE
            LOG.LogSCP( dldDebug, L"EIBNet Connection", L"packet rejected in TUNNELING mode: ", CARDINAL( ChannelId ), PTR( packet^.Service ));
            RETURN;
         END;
      //-----
      END; // CASE
      
      CASE packet^.Service OF
      //-----
      | core.SEARCH_RESPONSE :
         IF core.TPSearchResponse( packet )^.Valid THEN
            OnSearchResponse( core.TPSearchResponse( packet )^ );
         ELSE
            LOG.LogSCB( dldDebug, L"EIBNet Connection", L"invalid packet ", CARDINAL( ChannelId ), packet, l );
         END;
      //-----
      | core.DESCRIPTION_RESPONSE :
         IF core.TPDescriptionResponse( packet )^.Valid THEN
            OnDescriptionResponse( core.TPDescriptionResponse( packet )^ );
         ELSE
            LOG.LogSCB( dldDebug, L"EIBNet Connection", L"invalid packet ", CARDINAL( ChannelId ), packet, l );
         END;
      //-----
      | core.ROUTING_INDICATION :
         IF core.TPRoutingIndication( packet )^.Valid THEN
            OnRoutingIndication( core.TPRoutingIndication( packet )^ );
         ELSE
            LOG.LogSCB( dldDebug, L"EIBNet Connection", L"invalid packet ", CARDINAL( ChannelId ), packet, l );
         END;
      //-----
      // | core.ROUTING_LOST_MESSAGE :
      //-----
      | core.CONNECT_RESPONSE :
         IF core.TPConnectResponse( packet )^.Valid THEN
            OnConnectResponse( core.TPConnectResponse( packet )^ );
         ELSE
            LOG.LogSCB( dldDebug, L"EIBNet Connection", L"invalid packet ", CARDINAL( ChannelId ), packet, l );
         END;
      //-----
      | core.CONNECTIONSTATE_RESPONSE :
         IF core.TPConnectionStateResponse( packet )^.Valid THEN
            OnConnectionStateResponse( core.TPConnectionStateResponse( packet )^ );
         ELSE
            LOG.LogSCB( dldDebug, L"EIBNet Connection", L"invalid packet ", CARDINAL( ChannelId ), packet, l );
         END;
      //-----
      | core.DISCONNECT_REQUEST :
         IF core.TPDisconnectRequest( packet )^.Valid THEN
            OnDisconnectRequest( core.TPDisconnectRequest( packet )^ );
         ELSE
            LOG.LogSCB( dldDebug, L"EIBNet Connection", L"invalid packet ", CARDINAL( ChannelId ), packet, l );
         END;
      //-----
      | core.DISCONNECT_RESPONSE :
         IF core.TPDisconnectResponse( packet )^.Valid THEN
            OnDisconnectResponse( core.TPDisconnectResponse( packet )^ );
         ELSE
            LOG.LogSCB( dldDebug, L"EIBNet Connection", L"invalid packet ", CARDINAL( ChannelId ), packet, l );
         END;
      //-----
      | core.TUNNELING_REQUEST :
         IF core.TPTunnelingRequest( packet )^.Valid THEN
            OnTunnelingRequest( core.TPTunnelingRequest( packet )^ );
         ELSE
            LOG.LogSCB( dldDebug, L"EIBNet Connection", L"invalid packet ", CARDINAL( ChannelId ), packet, l );
         END;
      //-----
      | core.TUNNELING_ACK :
         IF core.TPTunnelingACK( packet )^.Valid THEN
            OnTunnelingACK( core.TPTunnelingACK( packet )^ );
         ELSE
            LOG.LogSCB( dldDebug, L"EIBNet Connection", L"invalid packet ", CARDINAL( ChannelId ), packet, l );
         END;
      END; // main case
   END OnDatagramReceived;

(*--------------------------------------------------------------------------------*)

   LOCAL PROCEDURE OnListenSocketClosed( CONST ServerSocket : netsocket.TPSSocket );
   BEGIN
      LOG.LogSP( dldTrace, L"EIBNet Connection", L"socket closed: ", ServerSocket );
      
      IF Socket = ServerSocket THEN
         Socket := NIL;
      END;

      DataDisconnect();
      DeviceDisconnect();

      IF _Mode = cmScanning THEN
         OnScanCompleted();
      END;
   END OnListenSocketClosed;

(*--------------------------------------------------------------------------------*)

   INTERNAL VIRTUAL PROCEDURE OnScanCompleted();
   BEGIN
   END OnScanCompleted;

(*--------------------------------------------------------------------------------*)

   INTERNAL VIRTUAL PROCEDURE OnSearchResponse( CONST packet : core.SearchResponse );
   BEGIN
   END OnSearchResponse;

(*--------------------------------------------------------------------------------*)

   INTERNAL VIRTUAL PROCEDURE OnDescriptionResponse( CONST packet : core.DescriptionResponse );
   BEGIN
   END OnDescriptionResponse;

(*--------------------------------------------------------------------------------*)

   INTERNAL VIRTUAL PROCEDURE OnConnect();
   BEGIN
   END OnConnect;

(*--------------------------------------------------------------------------------*)

   INTERNAL VIRTUAL PROCEDURE OnDisconnect();
   BEGIN
   END OnDisconnect;

(*--------------------------------------------------------------------------------*)

   INTERNAL VIRTUAL PROCEDURE On_L_CON( Status : eib_status.TEIBStackStatus );
   BEGIN
   END On_L_CON;

(*--------------------------------------------------------------------------------*)

   INTERNAL VIRTUAL PROCEDURE On_L_IND( CONST packet : eib_def.TPacket );
   BEGIN
   END On_L_IND;

(*--------------------------------------------------------------------------------*)

   PRIVATE PROCEDURE OnRoutingIndication( CONST packet : core.RoutingIndication );
   BEGIN
      LOG.LogS( dldTrace, L"EIBNet Connection", L"ROUTED in" );
      LOG.LogSB( dldDebug, L"EIBNet Connection", L"ROUTED: ", ADR( packet ), packet.Length );

      On_L_IND( packet.EMI );
   END OnRoutingIndication;

(*--------------------------------------------------------------------------------*)

   PRIVATE PROCEDURE OnConnectResponse( CONST packet : core.ConnectResponse );
   BEGIN
      IF packet.Status = core.E_NO_ERROR THEN
         StopTimer( PTR( tiConnect ));
         
         IOState := ioReady;
         IF _Mode = cmTunnelingHPAI THEN
            HPAIData := packet.DataHPAI;
         // ELSE // cmTunnelingBlind -- data are set in RemoteAddress, RemotePort
         END;
         
         ChannelId := packet.ChannelId;
         InSeq := 0;
         OutSeq := 0;

         LOG.LogSCP( dldTrace, L"EIBNet Connection", L"CONNECTed in TUNNELING mode: ", CARDINAL( ChannelId ), Socket );

         HbRepeat := maximalHbRepeat;
         StartTimer( PTR( tiHeartbeat ), core.HEART_BEAT_PERIOD, TRUE );

         OnConnect();
      ELSE
         LOG.LogSHP( dldTrace, L"EIBNet Connection", L"CONNECT failure: ", CARDINAL( packet.Status ), Socket );

         DeviceDisconnect();
      END;
   END OnConnectResponse;

(*--------------------------------------------------------------------------------*)

   PRIVATE PROCEDURE OnConnectionStateResponse( CONST packet : core.ConnectionStateResponse );
   BEGIN
      IF packet.Status = core.E_NO_ERROR THEN
         LOG.LogSCP( dldDebug, L"EIBNet Connection", L"HEARTBEAT response: ", CARDINAL( ChannelId ), Socket );

         StopTimer( PTR( tiHeartbeatRepeat ));
         HbRepeat := maximalHbRepeat;
         
         IF SendErr > 0 THEN // server doed not ACKed anything, reset the connection
            Disconnect( FALSE );
         END;
      ELSE
         LOG.LogSHP( dldDebug, L"EIBNet Connection", L"HEARTBEAT error: ", CARDINAL( packet.Status ), Socket );

         ProcessHbFailure();
      END;
   END OnConnectionStateResponse;

(*--------------------------------------------------------------------------------*)

   PRIVATE PROCEDURE OnDisconnectRequest( CONST packet : core.DisconnectRequest );
   VAR
      dr : core.DisconnectResponse;
   BEGIN
      IF NOT Disconnected THEN
         LOG.LogSCP( dldTrace, L"EIBNet Connection", L"remote DISCONNECT request: ", CARDINAL( ChannelId ), Socket );

         DataDisconnect();

         dr.ChannelId := ChannelId;
         Socket^.SendToOA( OA( dr.Length-1, ADR( dr )), HPAICtrl.Address, HPAICtrl.Port );
      END;

      DeviceDisconnect();
   END OnDisconnectRequest;

(*--------------------------------------------------------------------------------*)

   PRIVATE PROCEDURE OnDisconnectResponse( CONST packet : core.DisconnectResponse );
   BEGIN
      DeviceDisconnect();
   END OnDisconnectResponse;

(*--------------------------------------------------------------------------------*)

   PRIVATE PROCEDURE OnTunnelingRequest( CONST packet : core.TunnelingRequest );
   VAR
      tack : core.TunnelingACK;
      pSeq : CARD8 := packet.Sequence;
   BEGIN
      IF pSeq + 1 < CARD8( InSeq ) THEN
         LOG.LogSCP( dldTrace, L"EIBNet Connection", L"RECEIVE out of order: ", CARDINAL( ChannelId ), PTR( pSeq ));
         RETURN; // ignore
      END;

      tack.ChannelId := ChannelId;
      tack.Sequence := CARD8( InSeq );
      tack.Success := TRUE;
      Socket^.SendToOA( OA( tack.Length-1, ADR( tack )), HPAIData.Address, HPAIData.Port );

      IF pSeq < CARD8( InSeq ) THEN
         LOG.LogSCP( dldTrace, L"EIBNet Connection", L"RECEIVE previous: ", CARDINAL( ChannelId ), PTR( pSeq ));
      ELSE
         LOG.LogSCP( dldTrace, L"EIBNet Connection", L"RECEIVE ok: ", CARDINAL( ChannelId ), PTR( pSeq ));
         LOG.LogSB( dldDebug, L"EIBNet Connection", L"RECEIVE: ", ADR( packet ), packet.Length );

         InSeq := CARDINAL( pSeq ) + 1;
         On_L_IND( packet.EMI );
      END;
   END OnTunnelingRequest;

(*--------------------------------------------------------------------------------*)

   PRIVATE PROCEDURE OnTunnelingACK( CONST packet : core.TunnelingACK );
   BEGIN
      LOG.LogSCP( dldTrace, L"EIBNet Connection", L"SEND R_CON: ", CARDINAL( ChannelId ), PTR( packet.Sequence ));

      StopTimer( PTR( tiACK ));
      IOState := ioReady;
      IF packet.Sequence = CARD8( OutSeq ) THEN
        INC( OutSeq ); // prepare next writing
      END;
      SendErr := 0; // reset connection recovery counter

      On_L_CON( eib_status.essOK );
   END OnTunnelingACK;

(*--------------------------------------------------------------------------------*)

   PRIVATE PROCEDURE DoSend() : Sync.TAsyncResult;
   VAR
      res : Sync.TAsyncResult;
      rr : core.RoutingIndication;
      tr : core.TunnelingRequest;
   BEGIN
      IF _Mode = cmRouting THEN
         rr.EMI := EMI;

         LOG.LogS( dldTrace, L"EIBNet Connection", L"ROUTED out" );
         LOG.LogSB( dldDebug, L"EIBNet Connection", L"ROUTED: ", ADR( rr ), rr.Length );

         res := Socket^.SendOA( OA( rr.Length-1, ADR( rr ))); // send to internal multicast group

      ELSIF _Mode = cmScanning THEN
         RETURN Sync.arCannotStart;

      ELSE // ELSIF ( _Mode = cmTunnelingHPAI ) OR ( _Mode = cmTunnelingBlind ) THEN
         tr.ChannelId := ChannelId;
         tr.Sequence := CARD8( OutSeq );
         tr.EMI := EMI;

         LOG.LogSCP( dldTrace, L"EIBNet Connection", L"SEND ok: ", CARDINAL( ChannelId ), PTR( OutSeq ));
         LOG.LogSB( dldDebug, L"EIBNet Connection", L"SEND: ", ADR( tr ), tr.Length );

         StartTimer( PTR( tiACK ), core.TUNNELING_REQUEST_TIME_OUT, FALSE );
         res := Socket^.SendToOA( OA( tr.Length-1, ADR( tr )), HPAIData.Address, HPAIData.Port ); // send to specified address
      END;

      IF res NOT IN Sync.arsStarts THEN
         RETURN res;
      ELSIF _Mode = cmRouting THEN // acknowledge packet immediatelly, routing has no ACK

         LOG.LogS( dldTrace, L"EIBNet Connection", L"ROUTING L_CON" );

         On_L_CON( eib_status.essOK );
         RETURN Sync.arCompleted;
      ELSE
         RETURN res;
      END;
   END DoSend;

(*--------------------------------------------------------------------------------*)

   PRIVATE PROCEDURE DataDisconnect();
   BEGIN
      IF Disconnected THEN
         RETURN;
      END;
   
      StopTimer( PTR( tiConnect ));
      StopTimer( PTR( tiACK ));
      StopTimer( PTR( tiHeartbeatRepeat ));
      StopTimer( PTR( tiHeartbeat ));
      SendErr := 0; // reset connection recovery counter

      IF ( IOState = ioWaitACK1 ) OR ( IOState = ioWaitACK2 ) THEN
         On_L_CON( eib_status.essTransceiverFault );
      END;
      
      IOState := ioDisconnecting;
   END DataDisconnect;

(*--------------------------------------------------------------------------------*)

   PRIVATE PROCEDURE DeviceDisconnect();
   VAR
      currentState : TIOState := IOState;
   BEGIN
      IF currentState = ioDisconnected THEN
         RETURN;
      END;
      LOG.LogSCP( dldTrace, L"EIBNet Connection", L"DISCONNECTed: ", CARDINAL( ChannelId ), Socket );

      StopTimer( PTR( tiDisconnect ));
      IF Socket <> NIL THEN
         netsrv.StopListenSocket( OUT Socket );
      END;
      IOState := ioDisconnected;

      IF currentState >= ioReady THEN
         OnDisconnect();
      END;
      IF _AutoReconnectDelay <> 0 THEN
         StartTimer( PTR( tiAutoReconnect ), _AutoReconnectDelay, FALSE );
      END;
   END DeviceDisconnect;

(*--------------------------------------------------------------------------------*)

   PRIVATE PROCEDURE ProcessHbFailure();
   VAR
      hb : core.ConnectionStateRequest;
   BEGIN
      IF HbRepeat = 0 THEN
         Disconnect( FALSE );
         RETURN;
      ELSE
         DEC( HbRepeat );
      END;

      LOG.LogSCP( dldDebug, L"EIBNet Connection", L"HEARTBEAT probe: ", CARDINAL( ChannelId ), Socket );

      hb.ControlHPAI := HPAISelf;
      hb.ChannelId := ChannelId;
      StartTimer( PTR( tiHeartbeatRepeat ), core.HEART_BEAT_TIMEOUT, FALSE );
      Socket^.SendToOA( OA( hb.Length-1, ADR( hb )), HPAICtrl.Address, HPAICtrl.Port );
   END ProcessHbFailure;

(*--------------------------------------------------------------------------------*)

   INITIALLY CConnection;
   VAR
      Address : winsock.IN_ADDR;
      l : CARDINAL;
   BEGIN
      Init();
   
      Socket := NIL;
      NEW( Listener );
      Listener^.Connection := ADR( SELF );
      
      Address.s_addr := 0;
      dns.GetLocalIPs( 5000, OUT OA( 0, ADR( Address )), OUT l );
      HPAISelf.Address := Address;
   END CConnection;

(*--------------------------------------------------------------------------------*)

   FINALLY CConnection;
   BEGIN
      Disconnect( TRUE );

      Listener^.Connection := NIL;
      Listener^.Release();
      Listener := NIL;
   END CConnection;

(*--------------------------------------------------------------------------------*)

END CConnection;

(*================================================================================*)

END eibnet.