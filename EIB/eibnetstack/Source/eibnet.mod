IMPLEMENTATION MODULE eibnet;

FROM Storage IMPORT
   ALLOCATE, DEALLOCATE;
   
FROM Log IMPORT
   logger, TDebugLevel, dldMessage, dldTrace, dldDebug;

IMPORT
   dns,
   Strings;

(*================================================================================*)

CONST
   DEBUG_PREFIX = L"EibNet.Connection";

PROCEDURE LogSHPAI( Logger : log.TPLogger; Level : TDebugLevel; Prefix, S : ARRAY OF WCHAR; CONST HPAI : core.HostProtocolAddressInformation );
VAR
   Address : ARRAY [0..63] OF WCHAR;
BEGIN
   HPAI.Address.GetAddressOA( TRUE, OUT Address );
   Logger^.LogSS( dldTrace, Prefix, S, Address );
END LogSHPAI;

(*--------------------------------------------------------------------------------*)

PROCEDURE LogSCHPAI( Logger : log.TPLogger; Level : TDebugLevel; Prefix, S : ARRAY OF WCHAR; C : CARDINAL; CONST HPAI : core.HostProtocolAddressInformation );
VAR
   Address : ARRAY [0..63] OF WCHAR;
   n : ARRAY [0..15] OF WCHAR;
BEGIN
   HPAI.Address.GetAddressOA( TRUE, OUT Address );
   Strings.PrependW( REF Address, L" " );
   Strings.FromCARD32W( C, 10, OUT n );
   Strings.PrependW( REF Address, n );
   Logger^.LogSS( dldTrace, Prefix, S, Address );
END LogSCHPAI;         

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

   PUBLIC PROPERTY Logger GET : log.TPLogger;
   BEGIN
      RETURN _Logger;
   END Logger;

(*--------------------------------------------------------------------------------*)

   PUBLIC PROPERTY Logger SET( Value : log.TPLogger );
   BEGIN
      IF Value = NIL THEN
         _Logger := log.logger();
      ELSE
         _Logger := Value;
      END;
   END Logger;

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

   PUBLIC PROPERTY RemoteAddress GET : inetaddr.INETADDR; // routing or remote address
   BEGIN
      RETURN HPAIData.Address;
   END RemoteAddress;

(*--------------------------------------------------------------------------------*)

   PUBLIC PROPERTY RemoteAddress SET( CONST Value : inetaddr.INETADDR ); // routing or remote address
   VAR
      Address : inetaddr.INETADDR;
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
         HPAIData.Port := core.EIBNET_IPPORT; // to be sure
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
         _Logger^.LogS( dldTrace, DEBUG_PREFIX, L"CONNECT timeout" );

         DeviceDisconnect();

      //----
      | tiDisconnect :
         _Logger^.LogSC( dldTrace, DEBUG_PREFIX, L"DISCONNECT timeout: ", CARDINAL( ChannelId ));

         DeviceDisconnect();

      //-----
      | tiACK :
         CASE IOState OF
         | ioWaitTCON1 :
            IF _Mode = cmRouting THEN // timeout elapsed without routing error notification, finish routing
               _Logger^.LogS( dldTrace, DEBUG_PREFIX, L"ROUTING L_CON ok" );

               IOState := ioReady;
               On_L_CON( eib_status.essOK );
            
            ELSE  // resend data
               _Logger^.LogSC( dldTrace, DEBUG_PREFIX, L"T_CON timeout, repeat SEND: ", CARDINAL( ChannelId ));

               IOState := ioWaitTCON2;
               DoSend();
            END;

         | ioWaitTCON2 :
            _Logger^.LogSC( dldTrace, DEBUG_PREFIX, L"T_CON timeout, kill SEND: ", CARDINAL( ChannelId ));

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
      ai : inetaddr.INETADDR;
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
      
      ChannelId := 0;
      CASE _Mode OF
      | cmScanning :
         IF Timeout = 0 THEN
            timeout := BROWSE_TIMEOUT;
         ELSE
            timeout := Timeout;
         END;
         b := netsrv.StartListen( netsocket.stDatagram, ai, NIL, Listener, timeout, ADR( Socket )) = 0;
      | cmRouting :
         ai.Port := core.EIBNET_IPPORT;
         b := netsrv.StartListen( netsocket.stDatagram, ai, NIL, Listener, 0, ADR( Socket )) = 0;
      ELSE
         b := netsrv.StartListen( netsocket.stDatagram, ai, NIL, Listener, timeout, ADR( Socket )) = 0;
      END;
      IF b THEN
         _Logger^.LogSC( dldTrace, DEBUG_PREFIX, L"LISTENing on port: ", Socket^.LocalAddress.Port );
         LogSHPAI( _Logger, dldTrace, DEBUG_PREFIX, L"CONNECT request: ", HPAIData );
      ELSE
         _Logger^.LogS( dldTrace, DEBUG_PREFIX, L"CONNECT (listen) cannot start" );
         Socket := NIL;
         RETURN Sync.arCannotStart;
      END;
      IF _Mode = cmTunnelingBlind THEN
        HPAISelf.Port := 0;
      ELSE
        HPAISelf.Port := Socket^.LocalAddress.Port;
      END;

      CASE _Mode OF
      //-----
      | cmScanning :
         dns.GetLocalIPs( TRUE, FALSE, FALSE, OUT OA( 0, ADR( ai )), OUT l );
         ai.Port := Socket^.LocalAddress.Port;
         HPAISelf.Address := ai;

         ai.SetAddressOA( core.EIBNET_DISCOVERY_ADDRESS, core.EIBNET_IPPORT );
         Socket^.MulticastGroup := ai;
         IOState := ioReady;

         LogSHPAI( _Logger, dldTrace, DEBUG_PREFIX, L"CONNECTed in SCANNING mode: ", HPAIData );
         RETURN Sync.arCompleted;
      //-----
      | cmRouting :
         Socket^.MulticastGroup := HPAIData.Address;
         IOState := ioReady;
         OnConnect();

         LogSHPAI( _Logger, dldTrace, DEBUG_PREFIX, L"CONNECTed in ROUTING mode: ", HPAIData );
         RETURN Sync.arCompleted;

      //-----
      | cmTunnelingHPAI :
         dns.GetLocalIPs( TRUE, FALSE, FALSE, OUT OA( 0, ADR( ai )), OUT l );
         ai.Port := Socket^.LocalAddress.Port;
         HPAISelf.Address := ai;

         IOState := ioConnecting;
         StartTimer( PTR( tiConnect ), CONNECT_TIMEOUT, FALSE );
      //-----
      | cmTunnelingBlind :
         ai.SetV4( inetaddr.saEmpty );
         HPAISelf.Address := ai;

         IOState := ioConnecting;
         StartTimer( PTR( tiConnect ), CONNECT_TIMEOUT, FALSE );
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
         _Logger^.LogS( dldTrace, DEBUG_PREFIX, L"DISCONNECT forced as abortive" );
      ELSIF Disconnected THEN
         RETURN Sync.arCompleted;
      END;

      LogSCHPAI( _Logger, dldTrace, DEBUG_PREFIX, L"DISCONNECT request: ", CARDINAL( ChannelId ), HPAIData );

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
         _Logger^.LogS( dldTrace, DEBUG_PREFIX, L"SEND request when disconnected" );
         RETURN Sync.arCannotStart;
      ELSIF _Mode = cmScanning THEN
         _Logger^.LogS( dldTrace, DEBUG_PREFIX, L"SEND request in scanning mode" );
         RETURN Sync.arCannotStart;
      ELSIF IOState <> ioReady THEN
         _Logger^.LogSC( dldTrace, DEBUG_PREFIX, L"SEND request when not ready: ", CARDINAL( ChannelId ));
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
      ia : inetaddr.INETADDR;
      l : CARDINAL := 0;
      packet : core.TPPacket := core.TPPacket( ADR( buffer ));
      Result : Sync.TAsyncResult;
   BEGIN
      // not to test L before recvfrom, recvfrom is re-enabling function and should be called after notification even if dataavailable = 0
      Result := ServerSocket^.ReceiveFromOA( OUT buffer, OUT l, OUT ia );
      IF Result NOT IN Sync.arsCompletions THEN
         RETURN;
      END;
      
      // check sender
      CASE _Mode OF
      | cmScanning, cmRouting : // do nohing, unfortunately, for routing source of UDP packet contains unicast address, not multicast, so checking cannot be done
      ELSE // some tunneling mode
         IF DEBUG AND ( ia <> HPAIData.Address ) THEN // check for error
            _Logger^.LogSH( dldMessage, DEBUG_PREFIX, L"Packet from unexpected source, REJECTED: ", CARDINAL( packet^.Service ));
            _Logger^.LogSB( dldMessage, DEBUG_PREFIX, L"  rejected data: ", packet, packet^.Length );
         END;
      END; // CASE
      
      CASE _Mode OF
      //-----
      | cmScanning :
         CASE packet^.Service OF
         | core.SEARCH_RESPONSE,
           core.DESCRIPTION_RESPONSE :
         ELSE
            _Logger^.LogSCP( dldMessage, DEBUG_PREFIX, L"packet rejected in SCANNING mode: ", CARDINAL( ChannelId ), PTR( packet^.Service ));
            _Logger^.LogSB( dldMessage, DEBUG_PREFIX, L"  rejected data: ", packet, packet^.Length );
            RETURN;
         END; // Service
      //-----
      | cmRouting :
         CASE packet^.Service OF
         | core.DESCRIPTION_RESPONSE,
           core.ROUTING_INDICATION,
           core.ROUTING_LOST_MESSAGE :
         ELSE
            _Logger^.LogSCP( dldMessage, DEBUG_PREFIX, L"packet rejected in ROUTING mode: ", CARDINAL( ChannelId ), PTR( packet^.Service ));
            _Logger^.LogSB( dldMessage, DEBUG_PREFIX, L"  rejected data: ", packet, packet^.Length );
            RETURN;
         END; // Service
      //-----
      | cmTunnelingHPAI, cmTunnelingBlind :
         CASE packet^.Service OF
         | core.DESCRIPTION_RESPONSE :
         | core.CONNECT_RESPONSE :
            IF IOState <> ioConnecting THEN
               _Logger^.LogSCP( dldMessage, DEBUG_PREFIX, L"packet rejected as unexpected: ", CARDINAL( ChannelId ), PTR( packet^.Service ));
               _Logger^.LogSB( dldMessage, DEBUG_PREFIX, L"  rejected data: ", packet, packet^.Length );
               RETURN;
            END;
         | core.CONNECTIONSTATE_RESPONSE,
           core.DISCONNECT_REQUEST,
           core.TUNNELING_REQUEST,
           core.TUNNELING_ACK :
            IF IOState NOT IN iosConnected THEN
               _Logger^.LogSCP( dldMessage, DEBUG_PREFIX, L"packet rejected as unexpected: ", CARDINAL( ChannelId ), PTR( packet^.Service ));
               _Logger^.LogSB( dldMessage, DEBUG_PREFIX, L"  rejected data: ", packet, packet^.Length );
               RETURN;
            END;
         | core.DISCONNECT_RESPONSE :
            IF IOState <> ioDisconnecting THEN
               _Logger^.LogSCP( dldMessage, DEBUG_PREFIX, L"packet rejected as unexpected: ", CARDINAL( ChannelId ), PTR( packet^.Service ));
               _Logger^.LogSB( dldMessage, DEBUG_PREFIX, L"  rejected data: ", packet, packet^.Length );
               RETURN;
            END;
         ELSE
            _Logger^.LogSCP( dldMessage, DEBUG_PREFIX, L"packet rejected in TUNNELING mode: ", CARDINAL( ChannelId ), PTR( packet^.Service ));
            _Logger^.LogSB( dldMessage, DEBUG_PREFIX, L"  rejected data: ", packet, packet^.Length );
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
            _Logger^.LogSCB( dldMessage, DEBUG_PREFIX, L"invalid packet ", CARDINAL( ChannelId ), packet, l );
         END;
      //-----
      | core.DESCRIPTION_RESPONSE :
         IF core.TPDescriptionResponse( packet )^.Valid THEN
            OnDescriptionResponse( core.TPDescriptionResponse( packet )^ );
         ELSE
            _Logger^.LogSCB( dldMessage, DEBUG_PREFIX, L"invalid packet ", CARDINAL( ChannelId ), packet, l );
         END;
      //-----
      | core.ROUTING_INDICATION :
         IF core.TPRoutingIndication( packet )^.Valid THEN
            OnRoutingIndication( core.TPRoutingIndication( packet )^ );
         ELSE
            _Logger^.LogSCB( dldMessage, DEBUG_PREFIX, L"invalid packet ", CARDINAL( ChannelId ), packet, l );
         END;
      //-----
      | core.ROUTING_LOST_MESSAGE :
         IF core.TPRoutingLostMessage( packet )^.Valid THEN
            OnRoutingLostMessage( core.TPRoutingLostMessage( packet )^ );
         ELSE
            _Logger^.LogSCB( dldMessage, DEBUG_PREFIX, L"invalid packet ", CARDINAL( ChannelId ), packet, l );
         END;
      //-----
      | core.CONNECT_RESPONSE :
         IF core.TPConnectResponse( packet )^.Valid THEN
            OnConnectResponse( core.TPConnectResponse( packet )^ );
         ELSE
            _Logger^.LogSCB( dldMessage, DEBUG_PREFIX, L"invalid packet ", CARDINAL( ChannelId ), packet, l );
         END;
      //-----
      | core.CONNECTIONSTATE_RESPONSE :
         IF core.TPConnectionStateResponse( packet )^.Valid THEN
            OnConnectionStateResponse( core.TPConnectionStateResponse( packet )^ );
         ELSE
            _Logger^.LogSCB( dldMessage, DEBUG_PREFIX, L"invalid packet ", CARDINAL( ChannelId ), packet, l );
         END;
      //-----
      | core.DISCONNECT_REQUEST :
         IF core.TPDisconnectRequest( packet )^.Valid THEN
            OnDisconnectRequest( core.TPDisconnectRequest( packet )^ );
         ELSE
            _Logger^.LogSCB( dldMessage, DEBUG_PREFIX, L"invalid packet ", CARDINAL( ChannelId ), packet, l );
         END;
      //-----
      | core.DISCONNECT_RESPONSE :
         IF core.TPDisconnectResponse( packet )^.Valid THEN
            OnDisconnectResponse( core.TPDisconnectResponse( packet )^ );
         ELSE
            _Logger^.LogSCB( dldMessage, DEBUG_PREFIX, L"invalid packet ", CARDINAL( ChannelId ), packet, l );
         END;
      //-----
      | core.TUNNELING_REQUEST :
         IF core.TPTunnelingRequest( packet )^.Valid THEN
            OnTunnelingRequest( core.TPTunnelingRequest( packet )^ );
         ELSE
            _Logger^.LogSCB( dldMessage, DEBUG_PREFIX, L"invalid packet ", CARDINAL( ChannelId ), packet, l );
         END;
      //-----
      | core.TUNNELING_ACK :
         IF core.TPTunnelingACK( packet )^.Valid THEN
            OnTunnelingACK( core.TPTunnelingACK( packet )^ );
         ELSE
            _Logger^.LogSCB( dldMessage, DEBUG_PREFIX, L"invalid packet ", CARDINAL( ChannelId ), packet, l );
         END;
      END; // main case
   END OnDatagramReceived;

(*--------------------------------------------------------------------------------*)

   LOCAL PROCEDURE OnListenSocketClosed( CONST ServerSocket : netsocket.TPSSocket );
   BEGIN
      _Logger^.LogSC( dldTrace, DEBUG_PREFIX, L"Stop LISTENing on port: ", ServerSocket^.LocalAddress.Port );
      
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
      _Logger^.LogSC( dldTrace, DEBUG_PREFIX, L"ROUTING L_CON error, lost: ", CARDINAL( packet.LostCount ));

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
         AltInSeq := 0;
         OutSeq := 0;

         LogSCHPAI( _Logger, dldTrace, DEBUG_PREFIX, L"CONNECTed in TUNNELING mode: ", CARDINAL( ChannelId ), HPAIData );

         HbRepeat := maximalHbRepeat;
         StartTimer( PTR( tiHeartbeat ), core.HEART_BEAT_PERIOD, TRUE );

         OnConnect();
      ELSE
         LogSCHPAI( _Logger, dldTrace, DEBUG_PREFIX, L"CONNECT failure: ", CARDINAL( packet.Status ), HPAIData );

         DeviceDisconnect();
      END;
   END OnConnectResponse;

(*--------------------------------------------------------------------------------*)

   PRIVATE PROCEDURE OnConnectionStateResponse( CONST packet : core.ConnectionStateResponse );
   BEGIN
      IF packet.Status = core.E_NO_ERROR THEN
         LogSCHPAI( _Logger, dldDebug, DEBUG_PREFIX, L"HEARTBEAT response: ", CARDINAL( ChannelId ), HPAIData );

         StopTimer( PTR( tiHeartbeatRepeat ));
         HbRepeat := maximalHbRepeat;
         
         IF SendErr > 0 THEN // server does not ACKed anything, reset the connection
            Disconnect( FALSE );
         END;
      ELSE
         LogSCHPAI( _Logger, dldDebug, DEBUG_PREFIX, L"HEARTBEAT error: ", CARDINAL( packet.Status ), HPAIData );

         ProcessHbFailure();
      END;
   END OnConnectionStateResponse;

(*--------------------------------------------------------------------------------*)

   PRIVATE PROCEDURE OnDisconnectRequest( CONST packet : core.DisconnectRequest );
   VAR
      dr : core.DisconnectResponse;
   BEGIN
      IF NOT Disconnected THEN
         LogSCHPAI( _Logger, dldTrace, DEBUG_PREFIX, L"remote DISCONNECT request: ", CARDINAL( ChannelId ), HPAIData );

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
      IF packet.ChannelId <> ChannelId THEN
         _Logger^.LogSC( dldMessage, DEBUG_PREFIX, L"RECEIVE unexpected channel: ", CARDINAL( ChannelId ));
         _Logger^.LogSB( dldMessage, DEBUG_PREFIX, L"RECEIVE unexpected data: ", ADR( packet ), packet.Length );
         RETURN; // ignore

      ELSIF pSeq + 1 < CARD8( AltInSeq ) THEN
         _Logger^.LogSCP( dldMessage, DEBUG_PREFIX, L"RECEIVE out of order: ", CARDINAL( ChannelId ), PTR( pSeq ));
         RETURN; // ignore
      END;

      tack.ChannelId := ChannelId;
      tack.Sequence := pSeq;
      tack.Success := TRUE;
      Socket^.SendToOA( OA( tack.Length-1, ADR( tack )), HPAIData.Address );

      IF pSeq < CARD8( AltInSeq ) THEN
         _Logger^.LogSCP( dldTrace, DEBUG_PREFIX, L"RECEIVE previous: ", CARDINAL( ChannelId ), PTR( pSeq ));
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
         _Logger^.LogSCP( dldDebug, DEBUG_PREFIX, L"SEND R_CON status: ", CARDINAL( ChannelId ), PTR( EMI.GetError() ));

         // IOState := ioReady; -- not to set here, CConnection is ready after T_CON, L_ACK is matter of EIB and stack itself (and ACKTimeout is set there, of course)
         // ioReady is set in OnTunnelingACK.
         IF Error THEN
            On_L_CON( eib_status.essTransceiverFault );
         ELSE
            On_L_CON( eib_status.essOK );
         END;

      | eib_def.L_Data_IND, eib_def.L_Data_IND_EMI2 : // L_IND
         LogPacket( FALSE, L"RECEIVE", EMI, ADR( packet ), packet.Length, FALSE );
         On_L_IND( EMI );

      ELSE // L_REQ???
         _Logger^.LogSCP( dldTrace, DEBUG_PREFIX, L"RECEIVE unexpected code: ", CARDINAL( ChannelId ), PTR( EMI.Code ));
      END;

      AltInSeq := InSeq + 1; // use self -- this could be less in case of error
      InSeq := CARDINAL( pSeq ) + 1; // use packet's -- this could skip missing packets
      AltInSeq := MIN2( AltInSeq, InSeq ); // AltInSeq must be always less than InSeq
   END OnTunnelingRequest;

(*--------------------------------------------------------------------------------*)

   PRIVATE PROCEDURE OnTunnelingACK( CONST packet : core.TunnelingACK );
   VAR
      Status : core.TStatus;
   BEGIN
      IF packet.ChannelId <> ChannelId THEN
         _Logger^.LogSC( dldMessage, DEBUG_PREFIX, L"SEND T_CON unexpected channel: ", CARDINAL( ChannelId ));
         _Logger^.LogSB( dldMessage, DEBUG_PREFIX, L"SEND T_CON unexpected data: ", ADR( packet ), packet.Length );
         RETURN; // ignore
      END;
         
      Status := packet.Status;
      IF NOT _Logger^.Filtered( dldDebug ) THEN
         _Logger^.LogSCP( dldDebug, DEBUG_PREFIX, L"SEND T_CON status: ", CARDINAL( ChannelId ), PTR( Status ));
         _Logger^.LogSH( dldDebug, DEBUG_PREFIX, L"SEND T_CON seq: ", CARDINAL( packet.Sequence ));
      END;

      IF packet.Sequence = CARD8( OutSeq ) THEN
        INC( OutSeq ); // prepare next writing
      END;

      // stop TCON timeouting
      StopTimer( PTR( tiACK ));
      SendErr := 0; // reset connection recovery counter

      // Set ioReady here, CConnection is ready after T_CON. L_ACK is matter of EIB and stack itself (and ACKTimeout is set there, of course, and counted too).
      IOState := ioReady;

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
      LogSCHPAI( _Logger, dldTrace, DEBUG_PREFIX, L"DISCONNECTed: ", CARDINAL( ChannelId ), HPAIData );

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

      LogSCHPAI( _Logger, dldDebug, DEBUG_PREFIX, L"HEARTBEAT probe: ", CARDINAL( ChannelId ), HPAIData );

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
      seq : CARDINAL;
      out : ARRAY [0..63] OF WCHAR;
   BEGIN
      IF NOT _Logger^.Filtered( dldTrace ) THEN
         out := text;
         IF selfPacket THEN
            Strings.AppendW( REF out, L" [S]" ); 
         END;

         // channel id
         Strings.FromCARD32W( CARDINAL( ChannelId ), 10, OUT s );
         Strings.AppendW( REF out, L" " ); 
         Strings.AppendW( REF out, s ); 
      
         address := packet.GetDestinationAddress();
         IF address.GetAddressType() = eib_def.addressGroup THEN
            address.GetGroupAddress3( TRUE, OUT s );
            Strings.AppendW( REF out, L" group: " ); _Logger^.LogSS( dldTrace, DEBUG_PREFIX, out, s );
         ELSE
            Strings.AppendW( REF out, L" not group" ); _Logger^.LogS( dldTrace, DEBUG_PREFIX, out );
         END;
         IF NOT outputFlag AND ( InSeq <> AltInSeq ) THEN
            Strings.ConcatW( OUT out, text, L" altseq: " ); _Logger^.LogSH( dldTrace, DEBUG_PREFIX, out, AltInSeq );
         END;

         IF NOT _Logger^.Filtered( dldDebug ) THEN
            IF outputFlag THEN
               seq := CARDINAL( CARD8( OutSeq ));
            ELSE
               seq := CARDINAL( CARD8( InSeq ));
            END;
            Strings.ConcatW( OUT out, text, L" seq: " ); _Logger^.LogSH( dldDebug, DEBUG_PREFIX, out, seq );
            Strings.ConcatW( OUT out, text, L" data: " ); _Logger^.LogSB( dldDebug, DEBUG_PREFIX, out, data, dataLen );
         END;
      END;
   END LogPacket;

(*--------------------------------------------------------------------------------*)

   INITIALLY CConnection;
   BEGIN
      _Logger := log.logger();

      Init( TRUE );
   
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