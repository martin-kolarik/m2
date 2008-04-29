IMPLEMENTATION MODULE eibnet;

FROM Storage IMPORT
   ALLOCATE, DEALLOCATE;
   
FROM Log IMPORT
   logger, dldTrace, dldDebug;

IMPORT
   dns,
   Strings;

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
      wasConnected : BOOLEAN := NOT Disconnected;
   BEGIN
      IF _Mode = Value THEN
         RETURN;
      ELSIF wasConnected THEN
         Disconnect( TRUE );
      END;

      _Mode := Value;

      IF wasConnected THEN // reconnect if it was connected
         Connect( 0 );
      END;
   END Mode;

(*--------------------------------------------------------------------------------*)

   PUBLIC PROPERTY RemoteAddress GET : netsocket.INETADDR; // routing or remote address
   BEGIN
      RETURN HPAIData.Address;
   END RemoteAddress;

(*--------------------------------------------------------------------------------*)

   PUBLIC PROPERTY RemoteAddress SET( CONST Value : netsocket.INETADDR ); // routing or remote address
   VAR
      Address : netsocket.INETADDR;
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
      IF Value.Multicast THEN
         HPAIData.Port := core.EIBNET_IPPORT;
      ELSE
         HPAICtrl.Address := Value;
      END;

      IF wasConnected THEN // reconnect if it was connected
         Connect( 0 );
      END;
   END RemoteAddress;

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
      RETURN IOState IN iosConnected;
   END Connected;

(*--------------------------------------------------------------------------------*)

   PUBLIC PROPERTY Disconnected GET : BOOLEAN;
   BEGIN
      RETURN ( IOState = ioDisconnecting ) OR ( IOState = ioDisconnected );
   END Disconnected;

(*--------------------------------------------------------------------------------*)

   PUBLIC PROPERTY Pending GET : BOOLEAN;
   BEGIN
      RETURN IOState IN iosPending;
   END Pending;

(*--------------------------------------------------------------------------------*)

   INTERNAL VIRTUAL PROCEDURE OnTimer( TimerId : PTR );
   BEGIN
      CASE TTimers( LOPTRLONGWORD( TimerId )) OF
      //----
      | tiConnect :
         logger()^.LogS( dldTrace, L"EIBNet Connection", L"CONNECT timeout" );

         DeviceDisconnect();

      //----
      | tiDisconnect :
         logger()^.LogSC( dldTrace, L"EIBNet Connection", L"DISCONNECT timeout: ", CARDINAL( ChannelId ));

         DeviceDisconnect();

      //-----
      | tiACK :
         CASE IOState OF
         | ioWaitTCON1 :
            IF _Mode = cmRouting THEN // timeout elapsed without routing error notification, finish routing
               logger()^.LogS( dldTrace, L"EIBNet Connection", L"ROUTING L_CON ok" );

               IOState := ioReady;
               On_L_CON( eib_status.essOK );
            
            ELSE  // resend data
               logger()^.LogSC( dldTrace, L"EIBNet Connection", L"T_CON timeout, repeat SEND: ", CARDINAL( ChannelId ));

               IOState := ioWaitTCON2;
               DoSend();
            END;

         | ioWaitTCON2 :
            logger()^.LogSC( dldTrace, L"EIBNet Connection", L"T_CON timeout, kill SEND: ", CARDINAL( ChannelId ));

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
      ai : netsocket.INETADDR;
      cr : core.ConnectRequest;
      l : CARDINAL;
      timeout : CARDINAL := 0;
      b : BOOLEAN;
   BEGIN
      IF IOState = ioDisconnecting THEN
         RETURN Sync.arCannotStart;
      ELSIF IOState <> ioDisconnected THEN
         RETURN Sync.arAlreadyPending;
      END;
      
      CASE _Mode OF
      | cmScanning :
         IF Timeout = 0 THEN
            timeout := BROWSE_TIMEOUT;
         ELSE
            timeout := Timeout;
         END;
         b := netsrv.StartListen( netsocket.stDatagram, 0, NIL, Listener, timeout, ADR( Socket )) = 0;
      | cmRouting :
         b := netsrv.StartListen( netsocket.stDatagram, core.EIBNET_IPPORT, NIL, Listener, 0, ADR( Socket )) = 0;
      ELSE
         b := netsrv.StartListen( netsocket.stDatagram, 0, NIL, Listener, timeout, ADR( Socket )) = 0;
      END;
      IF b THEN
         logger()^.LogSP( dldTrace, L"EIBNet Connection", L"CONNECT request: ", Socket );
      ELSE
         logger()^.LogS( dldTrace, L"EIBNet Connection", L"CONNECT (listen) cannot start" );
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
         ai.SetAddressOA( core.EIBNET_DISCOVERY_ADDRESS );
         Socket^.MulticastGroup := ai;
         Socket^.MulticastPort := core.EIBNET_IPPORT;
         IOState := ioReady;

         logger()^.LogSP( dldTrace, L"EIBNet Connection", L"CONNECTed in SCANNING mode: ", Socket );
         RETURN Sync.arCompleted;
      //-----
      | cmRouting :
         Socket^.MulticastGroup := HPAIData.Address;
         Socket^.MulticastPort := core.EIBNET_IPPORT;
         IOState := ioReady;
         OnConnect();

         logger()^.LogSP( dldTrace, L"EIBNet Connection", L"CONNECTed in ROUTING mode: ", Socket );
         RETURN Sync.arCompleted;
      //-----
      | cmTunnelingHPAI, cmTunnelingBlind :
         IOState := ioConnecting;
         StartTimer( PTR( tiConnect ), CONNECT_TIMEOUT, FALSE );
      END;

      IF _Mode = cmTunnelingHPAI THEN
         dns.GetLocalIPs( TRUE, FALSE, OUT OA( 0, ADR( ai )), OUT l );
         ai.Port := Socket^.LocalPort;
         HPAISelf.Address := ai;
      ELSIF _Mode = cmTunnelingBlind THEN
         ai.SetV4( netsocket.saEmpty );
         HPAISelf.Address := ai;
      ELSE // TODO, FIXME, how to handle/check ports?
         HPAISelf.Port := Socket^.LocalPort;
      END;
      
      cr.ControlHPAI := HPAISelf;
      cr.DataHPAI := HPAISelf;
      RETURN Socket^.SendToOA( OA( cr.Length-1, ADR( cr )), HPAICtrl.Address );
   END Connect;

(*--------------------------------------------------------------------------------*)

   PUBLIC PROCEDURE Disconnect( Abortive : BOOLEAN ) : Sync.TAsyncResult;
   VAR
      dr : core.DisconnectRequest;
      abortive : BOOLEAN := FALSE;
   BEGIN
      IF Abortive AND ( IOState <> ioDisconnected ) THEN
         abortive := TRUE;
         logger()^.LogS( dldTrace, L"EIBNet Connection", L"DISCONNECT forced as abortive" );
      ELSIF Disconnected THEN
         RETURN Sync.arCompleted;
      END;

      logger()^.LogSCP( dldTrace, L"EIBNet Connection", L"DISCONNECT request: ", CARDINAL( ChannelId ), Socket );

      DataDisconnect();

      IF abortive THEN
         DeviceDisconnect();
      ELSIF ( _Mode = cmTunnelingHPAI ) OR ( _Mode = cmTunnelingBlind ) THEN
         StartTimer( PTR( tiDisconnect ), DISCONNECT_TIMEOUT, FALSE );
         dr.ControlHPAI := HPAISelf;
         dr.ChannelId := ChannelId;
         RETURN Socket^.SendToOA( OA( dr.Length-1, ADR( dr )), HPAICtrl.Address );
      ELSE
         DeviceDisconnect();
      END;
      RETURN Sync.arCompleted;
   END Disconnect;

(*--------------------------------------------------------------------------------*)

   PUBLIC PROCEDURE SendPacket( CONST EMI : eib_def.TPacket ) : Sync.TAsyncResult;
   BEGIN
      IF ( IOState = ioDisconnected ) OR ( IOState = ioConnecting ) OR ( IOState = ioDisconnecting ) THEN
         logger()^.LogS( dldTrace, L"EIBNet Connection", L"SEND request when disconnected" );
         RETURN Sync.arCannotStart;
      ELSIF _Mode = cmScanning THEN
         logger()^.LogS( dldTrace, L"EIBNet Connection", L"SEND request in scanning mode" );
         RETURN Sync.arCannotStart;
      ELSIF IOState <> ioReady THEN
         logger()^.LogSC( dldTrace, L"EIBNet Connection", L"SEND request when not ready: ", CARDINAL( ChannelId ));
         RETURN Sync.arAlreadyPending;
      END;
      SELF.EMI := EMI;

      IOState := ioWaitTCON1;

      RETURN DoSend();
   END SendPacket;
   
(*--------------------------------------------------------------------------------*)

   LOCAL PROCEDURE OnDatagramReceived( CONST ServerSocket : netsocket.TPSSocket );
   VAR
      buffer : ARRAY [0..255] OF BYTE;
      l : CARDINAL := 0;
      packet : core.TPPacket := core.TPPacket( ADR( buffer ));
   BEGIN
      // not to test L before recvfrom, recvfrom is re-enabling function and should be called after notification even if dataavailable = 0
      ServerSocket^.ReceiveOA( OUT buffer, OUT l );
      IF l = 0 THEN
         RETURN;
      END;
      
      CASE _Mode OF
      //-----
      | cmScanning :
         CASE packet^.Service OF
         | core.SEARCH_RESPONSE,
           core.DESCRIPTION_RESPONSE :
         ELSE
            logger()^.LogSCP( dldDebug, L"EIBNet Connection", L"packet rejected in SCANNING mode: ", CARDINAL( ChannelId ), PTR( packet^.Service ));
            RETURN;
         END; // Service
      //-----
      | cmRouting :
         CASE packet^.Service OF
         | core.DESCRIPTION_RESPONSE,
           core.ROUTING_INDICATION,
           core.ROUTING_LOST_MESSAGE :
         ELSE
            logger()^.LogSCP( dldDebug, L"EIBNet Connection", L"packet rejected in ROUTING mode: ", CARDINAL( ChannelId ), PTR( packet^.Service ));
            RETURN;
         END; // Service
      //-----
      | cmTunnelingHPAI, cmTunnelingBlind :
         CASE packet^.Service OF
         | core.DESCRIPTION_RESPONSE :
         | core.CONNECT_RESPONSE :
            IF IOState <> ioConnecting THEN
               logger()^.LogSCP( dldDebug, L"EIBNet Connection", L"packet rejected as unexpected: ", CARDINAL( ChannelId ), PTR( packet^.Service ));
               RETURN;
            END;
         | core.CONNECTIONSTATE_RESPONSE,
           core.DISCONNECT_REQUEST,
           core.DISCONNECT_RESPONSE,
           core.TUNNELING_REQUEST,
           core.TUNNELING_ACK :
            IF IOState NOT IN iosConnected THEN
               logger()^.LogSCP( dldDebug, L"EIBNet Connection", L"packet rejected as unexpected: ", CARDINAL( ChannelId ), PTR( packet^.Service ));
               RETURN;
            END;
         ELSE
            logger()^.LogSCP( dldDebug, L"EIBNet Connection", L"packet rejected in TUNNELING mode: ", CARDINAL( ChannelId ), PTR( packet^.Service ));
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
            logger()^.LogSCB( dldDebug, L"EIBNet Connection", L"invalid packet ", CARDINAL( ChannelId ), packet, l );
         END;
      //-----
      | core.DESCRIPTION_RESPONSE :
         IF core.TPDescriptionResponse( packet )^.Valid THEN
            OnDescriptionResponse( core.TPDescriptionResponse( packet )^ );
         ELSE
            logger()^.LogSCB( dldDebug, L"EIBNet Connection", L"invalid packet ", CARDINAL( ChannelId ), packet, l );
         END;
      //-----
      | core.ROUTING_INDICATION :
         IF core.TPRoutingIndication( packet )^.Valid THEN
            OnRoutingIndication( core.TPRoutingIndication( packet )^ );
         ELSE
            logger()^.LogSCB( dldDebug, L"EIBNet Connection", L"invalid packet ", CARDINAL( ChannelId ), packet, l );
         END;
      //-----
      | core.ROUTING_LOST_MESSAGE :
         IF core.TPRoutingLostMessage( packet )^.Valid THEN
            OnRoutingLostMessage( core.TPRoutingLostMessage( packet )^ );
         ELSE
            logger()^.LogSCB( dldDebug, L"EIBNet Connection", L"invalid packet ", CARDINAL( ChannelId ), packet, l );
         END;
      //-----
      | core.CONNECT_RESPONSE :
         IF core.TPConnectResponse( packet )^.Valid THEN
            OnConnectResponse( core.TPConnectResponse( packet )^ );
         ELSE
            logger()^.LogSCB( dldDebug, L"EIBNet Connection", L"invalid packet ", CARDINAL( ChannelId ), packet, l );
         END;
      //-----
      | core.CONNECTIONSTATE_RESPONSE :
         IF core.TPConnectionStateResponse( packet )^.Valid THEN
            OnConnectionStateResponse( core.TPConnectionStateResponse( packet )^ );
         ELSE
            logger()^.LogSCB( dldDebug, L"EIBNet Connection", L"invalid packet ", CARDINAL( ChannelId ), packet, l );
         END;
      //-----
      | core.DISCONNECT_REQUEST :
         IF core.TPDisconnectRequest( packet )^.Valid THEN
            OnDisconnectRequest( core.TPDisconnectRequest( packet )^ );
         ELSE
            logger()^.LogSCB( dldDebug, L"EIBNet Connection", L"invalid packet ", CARDINAL( ChannelId ), packet, l );
         END;
      //-----
      | core.DISCONNECT_RESPONSE :
         IF core.TPDisconnectResponse( packet )^.Valid THEN
            OnDisconnectResponse( core.TPDisconnectResponse( packet )^ );
         ELSE
            logger()^.LogSCB( dldDebug, L"EIBNet Connection", L"invalid packet ", CARDINAL( ChannelId ), packet, l );
         END;
      //-----
      | core.TUNNELING_REQUEST :
         IF core.TPTunnelingRequest( packet )^.Valid THEN
            OnTunnelingRequest( core.TPTunnelingRequest( packet )^ );
         ELSE
            logger()^.LogSCB( dldDebug, L"EIBNet Connection", L"invalid packet ", CARDINAL( ChannelId ), packet, l );
         END;
      //-----
      | core.TUNNELING_ACK :
         IF core.TPTunnelingACK( packet )^.Valid THEN
            OnTunnelingACK( core.TPTunnelingACK( packet )^ );
         ELSE
            logger()^.LogSCB( dldDebug, L"EIBNet Connection", L"invalid packet ", CARDINAL( ChannelId ), packet, l );
         END;
      END; // main case
   END OnDatagramReceived;

(*--------------------------------------------------------------------------------*)

   LOCAL PROCEDURE OnListenSocketClosed( CONST ServerSocket : netsocket.TPSSocket );
   BEGIN
      logger()^.LogSP( dldTrace, L"EIBNet Connection", L"socket closed: ", ServerSocket );
      
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

   INTERNAL VIRTUAL PROCEDURE On_P_Sent();
   BEGIN
   END On_P_Sent;

(*--------------------------------------------------------------------------------*)

   INTERNAL VIRTUAL PROCEDURE On_L_CON( Status : eib_status.TEIBStackStatus );
   BEGIN
   END On_L_CON;

(*--------------------------------------------------------------------------------*)

   INTERNAL VIRTUAL PROCEDURE On_L_IND( CONST packet : eib_def.TPacket );
   BEGIN
   END On_L_IND;

(*--------------------------------------------------------------------------------*)

   INTERNAL VIRTUAL PROCEDURE TestSelfPacket( CONST packet : eib_def.TPacket ) : BOOLEAN;
   BEGIN
      RETURN TRUE;
   END TestSelfPacket;

(*--------------------------------------------------------------------------------*)

   PRIVATE PROCEDURE OnRoutingIndication( CONST packet : core.RoutingIndication );
   VAR
      EMI : eib_def.TPacket;
   BEGIN
      EMI := packet.EMI;
      IF TestSelfPacket( EMI ) THEN // not to accept telegram from self
         LogPacket( FALSE, L"ROUTED in", EMI, ADR( packet ), packet.Length, TRUE );
      ELSE
         LogPacket( FALSE, L"ROUTED in", EMI, ADR( packet ), packet.Length, FALSE );
         On_L_IND( EMI );
      END;
   END OnRoutingIndication;

(*--------------------------------------------------------------------------------*)

   PRIVATE PROCEDURE OnRoutingLostMessage( CONST packet : core.RoutingLostMessage );
   BEGIN
      logger()^.LogSC( dldTrace, L"EIBNet Connection", L"ROUTING L_CON error, lost: ", CARDINAL( packet.LostCount ));

      StopTimer( PTR( tiACK ));
      IOState := ioReady;
      
      On_L_CON( eib_status.essLineBusy );
   END OnRoutingLostMessage;

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

         logger()^.LogSCP( dldTrace, L"EIBNet Connection", L"CONNECTed in TUNNELING mode: ", CARDINAL( ChannelId ), Socket );

         HbRepeat := maximalHbRepeat;
         StartTimer( PTR( tiHeartbeat ), core.HEART_BEAT_PERIOD, TRUE );

         OnConnect();
      ELSE
         logger()^.LogSHP( dldTrace, L"EIBNet Connection", L"CONNECT failure: ", CARDINAL( packet.Status ), Socket );

         DeviceDisconnect();
      END;
   END OnConnectResponse;

(*--------------------------------------------------------------------------------*)

   PRIVATE PROCEDURE OnConnectionStateResponse( CONST packet : core.ConnectionStateResponse );
   BEGIN
      IF packet.Status = core.E_NO_ERROR THEN
         logger()^.LogSCP( dldDebug, L"EIBNet Connection", L"HEARTBEAT response: ", CARDINAL( ChannelId ), Socket );

         StopTimer( PTR( tiHeartbeatRepeat ));
         HbRepeat := maximalHbRepeat;
         
         IF SendErr > 0 THEN // server doed not ACKed anything, reset the connection
            Disconnect( FALSE );
         END;
      ELSE
         logger()^.LogSHP( dldDebug, L"EIBNet Connection", L"HEARTBEAT error: ", CARDINAL( packet.Status ), Socket );

         ProcessHbFailure();
      END;
   END OnConnectionStateResponse;

(*--------------------------------------------------------------------------------*)

   PRIVATE PROCEDURE OnDisconnectRequest( CONST packet : core.DisconnectRequest );
   VAR
      dr : core.DisconnectResponse;
   BEGIN
      IF NOT Disconnected THEN
         logger()^.LogSCP( dldTrace, L"EIBNet Connection", L"remote DISCONNECT request: ", CARDINAL( ChannelId ), Socket );

         DataDisconnect();

         dr.ChannelId := ChannelId;
         Socket^.SendToOA( OA( dr.Length-1, ADR( dr )), HPAICtrl.Address );
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
      EMI : eib_def.TPacket;
      Error : BOOLEAN;
      tack : core.TunnelingACK;
      pSeq : CARD8 := packet.Sequence;
   BEGIN
      IF pSeq + 1 < CARD8( InSeq ) THEN
         logger()^.LogSCP( dldTrace, L"EIBNet Connection", L"RECEIVE out of order: ", CARDINAL( ChannelId ), PTR( pSeq ));
         RETURN; // ignore
      END;

      tack.ChannelId := ChannelId;
      tack.Sequence := CARD8( InSeq );
      tack.Success := TRUE;
      Socket^.SendToOA( OA( tack.Length-1, ADR( tack )), HPAIData.Address );

      IF pSeq < CARD8( InSeq ) THEN
         logger()^.LogSCP( dldTrace, L"EIBNet Connection", L"RECEIVE previous: ", CARDINAL( ChannelId ), PTR( pSeq ));
         RETURN;
      END;

      EMI := packet.EMI;
      CASE EMI.Code OF
      | eib_def.L_Data_CON, eib_def.L_Data_CON_EMI2 : // L_CON
         Error := EMI.GetError();
         IF Error THEN
            LogPacket( FALSE, L"SEND R_CON error", EMI, ADR( packet ), packet.Length, FALSE );
         ELSE
            LogPacket( FALSE, L"SEND R_CON ok", EMI, ADR( packet ), packet.Length, FALSE );
         END;
         logger()^.LogSCP( dldDebug, L"EIBNet Connection", L"SEND R_CON status: ", CARDINAL( ChannelId ), PTR( EMI.GetError() ));

         IOState := ioReady;
         IF Error THEN
            On_L_CON( eib_status.essTransceiverFault );
         ELSE
            On_L_CON( eib_status.essOK );
         END;

      | eib_def.L_Data_IND, eib_def.L_Data_IND_EMI2 : // L_IND
         LogPacket( FALSE, L"RECEIVE", EMI, ADR( packet ), packet.Length, FALSE );
         On_L_IND( EMI );

      ELSE // L_REQ???
         logger()^.LogSCP( dldTrace, L"EIBNet Connection", L"RECEIVE unexpected code: ", CARDINAL( ChannelId ), PTR( EMI.Code ));
      END;

      InSeq := CARDINAL( pSeq ) + 1;
   END OnTunnelingRequest;

(*--------------------------------------------------------------------------------*)

   PRIVATE PROCEDURE OnTunnelingACK( CONST packet : core.TunnelingACK );
   VAR
      Status : core.TStatus;
   BEGIN
      Status := packet.Status;
      IF NOT logger()^.Filtered( dldDebug ) THEN
         logger()^.LogSCP( dldDebug, L"EIBNet Connection", L"SEND T_CON status: ", CARDINAL( ChannelId ), PTR( Status ));
         logger()^.LogSCP( dldDebug, L"EIBNet Connection", L"SEND T_CON seq: ", CARDINAL( ChannelId ), PTR( packet.Sequence ));
      END;

      IF packet.Sequence = CARD8( OutSeq ) THEN
        INC( OutSeq ); // prepare next writing
      END;

      // stop TCON timeouting
      StopTimer( PTR( tiACK ));
      SendErr := 0; // reset connection recovery counter
   
      // notify stack about mine job finish   
      On_P_Sent();

      // and handle error
      CASE Status OF
      | core.E_NO_ERROR :
         // no L_CON must be done here, L_CON is received and processed when cEMI frame carries it, only notify send and leave timeouting etc. to Stack
      | core.E_SEQUENCE_NUMBER : // error in seq numbers, this is not recoverable
         On_L_CON( eib_status.essTransceiverFault );
         Disconnect( FALSE );
      | core.E_DATA_CONNECTION, core.E_KNX_CONNECTION :
         On_L_CON( eib_status.essTransceiverFault );
      ELSE
         On_L_CON( eib_status.essLineBusy );
      END;
   END OnTunnelingACK;

(*--------------------------------------------------------------------------------*)

   PRIVATE PROCEDURE DoSend() : Sync.TAsyncResult;
   VAR
      address : eib_def.TAddress;
      res : Sync.TAsyncResult;
      rr : core.RoutingIndication;
      tr : core.TunnelingRequest;
      s : ARRAY [0..31] OF WCHAR;
   BEGIN
      IF _Mode = cmRouting THEN
         rr.EMI := EMI;

         LogPacket( TRUE, L"ROUTED out", EMI, ADR( rr ), rr.Length, FALSE );

         StartTimer( PTR( tiACK ), core.ROUTING_L_CON_TIME_OUT, FALSE );
         res := Socket^.SendOA( OA( rr.Length-1, ADR( rr ))); // send to internal multicast group

      ELSIF _Mode = cmScanning THEN
         RETURN Sync.arCannotStart;

      ELSE // ELSIF ( _Mode = cmTunnelingHPAI ) OR ( _Mode = cmTunnelingBlind ) THEN
         tr.ChannelId := ChannelId;
         tr.Sequence := CARD8( OutSeq );
         tr.EMI := EMI;
         
         LogPacket( TRUE, L"SEND", EMI, ADR( tr ), tr.Length, FALSE );

         StartTimer( PTR( tiACK ), core.TUNNELING_REQUEST_TIME_OUT, FALSE );
         res := Socket^.SendToOA( OA( tr.Length-1, ADR( tr )), HPAIData.Address ); // send to specified address
      END;

      RETURN res;
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

      IF IOState IN iosPending THEN
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
      logger()^.LogSCP( dldTrace, L"EIBNet Connection", L"DISCONNECTed: ", CARDINAL( ChannelId ), Socket );

      StopTimer( PTR( tiDisconnect ));
      IF Socket <> NIL THEN
         netsrv.StopListenSocket( REF Socket );
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

      logger()^.LogSCP( dldDebug, L"EIBNet Connection", L"HEARTBEAT probe: ", CARDINAL( ChannelId ), Socket );

      hb.ControlHPAI := HPAISelf;
      hb.ChannelId := ChannelId;
      StartTimer( PTR( tiHeartbeatRepeat ), core.HEART_BEAT_TIMEOUT, FALSE );
      Socket^.SendToOA( OA( hb.Length-1, ADR( hb )), HPAICtrl.Address );
   END ProcessHbFailure;

(*--------------------------------------------------------------------------------*)

   PRIVATE PROCEDURE LogPacket( outputFlag : BOOLEAN; CONST text : ARRAY OF WCHAR; CONST packet : eib_def.TPacket; data : ADDRESS; dataLen : CARDINAL; selfPacket : BOOLEAN );
   VAR
      address : eib_def.TAddress;
      s : ARRAY [0..31] OF WCHAR;
      seq : PTR;
      out : ARRAY [0..31] OF WCHAR;
   BEGIN
      IF NOT logger()^.Filtered( dldTrace ) THEN
         out := text;
         IF selfPacket THEN
            Strings.AppendW( REF out, L" [S]" ); 
         END;
      
         address := packet.GetDestinationAddress();
         IF address.GetAddressType() = eib_def.addressGroup THEN
            EMI.GetDestinationAddress().GetGroupAddress3( TRUE, OUT s );
            Strings.AppendW( REF out, L" group: " ); logger()^.LogSS( dldTrace, L"EIBNet Connection", out, s );
         ELSE
            Strings.AppendW( REF out, L" not group" ); logger()^.LogS( dldTrace, L"EIBNet Connection", out );
         END;

         IF NOT logger()^.Filtered( dldDebug ) THEN
            IF outputFlag THEN
               seq := PTR( CARD8( OutSeq ));
            ELSE
               seq := PTR( CARD8( InSeq ));
            END;
            Strings.ConcatW( OUT out, text, L" seq: " ); logger()^.LogSCP( dldDebug, L"EIBNet Connection", out, CARDINAL( ChannelId ), seq );
            Strings.ConcatW( OUT out, text, L" data: " ); logger()^.LogSB( dldDebug, L"EIBNet Connection", out, data, dataLen );
         END;
      END;
   END LogPacket;

(*--------------------------------------------------------------------------------*)

   INITIALLY CConnection;
   BEGIN
      Init();
   
      Socket := NIL;
      NEW( Listener );
      Listener^.Connection := ADR( SELF );
   END CConnection;

(*--------------------------------------------------------------------------------*)

   FINALLY CConnection;
   BEGIN
      Disconnect( TRUE );

      IF Listener <> NIL THEN // this occurs in case of multiple FINALLY calls
         Listener^.Connection := NIL;
         Listener^.Release();
      END;
      Listener := NIL;
   END CConnection;

(*--------------------------------------------------------------------------------*)

END CConnection;

(*================================================================================*)

END eibnet.