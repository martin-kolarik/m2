IMPLEMENTATION MODULE protocol;

FROM Debug IMPORT
   Assertion, LogAssertionW;

FROM Storage IMPORT
   ALLOCATE, DEALLOCATE;
   
FROM Log IMPORT
   logger, ldMessage, ldTrace, ldDebug;

IMPORT
   dns,
   Log,
   Strings;

(*================================================================================*)

CONST
   DEBUG_PREFIX = L"KnxNet.Connection";

PROCEDURE LogSHPAI( Logger : log.TPLogger; Level : Log.TLevel; Prefix, S : ARRAY OF WCHAR; CONST HPAI : transport.HostProtocolAddressInformation );
VAR
   Address : ARRAY [0..63] OF WCHAR;
BEGIN
   HPAI.Address.ToOA( TRUE, OUT Address );
   Logger^.LogSS( ldTrace, 0, Prefix, S, Address );
END LogSHPAI;

(*--------------------------------------------------------------------------------*)

PROCEDURE LogSCHPAI( Logger : log.TPLogger; Level : Log.TLevel; Prefix, S : ARRAY OF WCHAR; C : CARDINAL; CONST HPAI : transport.HostProtocolAddressInformation );
VAR
   Address : ARRAY [0..63] OF WCHAR;
   n : ARRAY [0..15] OF WCHAR;
BEGIN
   HPAI.Address.ToOA( TRUE, OUT Address );
   Strings.PrependW( REF Address, L" " );
   Strings.FromCARD32W( C, 10, OUT n );
   Strings.PrependW( REF Address, n );
   Logger^.LogSS( ldTrace, 0, Prefix, S, Address );
END LogSCHPAI;         

(*================================================================================*)

CLASS IMPLEMENTATION KNXnetListener;

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
END KNXnetListener;

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

   PUBLIC PROPERTY TunnelingMode GET : TTunnelingMode;
   BEGIN
      RETURN _TunnelingMode;
   END TunnelingMode;

(*--------------------------------------------------------------------------------*)

   PUBLIC PROPERTY TunnelingMode SET( Value : TTunnelingMode );
   VAR
      wasConnected : BOOLEAN := NOT Disconnected;
   BEGIN
      IF _TunnelingMode = Value THEN
         RETURN;
      ELSIF ( _Mode <> cmTunnelingHPAI ) AND ( _Mode <> cmTunnelingBlind ) THEN
         _TunnelingMode := Value;
         RETURN;
      ELSIF wasConnected THEN
         Disconnect( TRUE );
      END;
      
      _TunnelingMode := Value;
      
      IF wasConnected THEN
         Connect( 0 );
      END;
   END TunnelingMode;

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
         HPAIData.Port := transport.KNXNET_IPPORT; // to be sure
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
         _Logger^.LogS( ldTrace, 0, DEBUG_PREFIX, L"CONNECT timeout" );

         DeviceDisconnect();

      //----
      | tiDisconnect :
         _Logger^.LogSC( ldTrace, 0, DEBUG_PREFIX, L"DISCONNECT timeout: ", CARDINAL( ChannelId ));

         DeviceDisconnect();

      //-----
      | tiACK :
         CASE IOState OF
         | ioWaitTCON1 :
            IF _Mode = cmRouting THEN // timeout elapsed without routing error notification, finish routing
               _Logger^.LogS( ldTrace, 0, DEBUG_PREFIX, L"ROUTING L_CON ok" );

               IOState := ioReady;
               On_L_CON( knx_status.essOK );
            
            ELSE  // resend data
               _Logger^.LogSC( ldTrace, 0, DEBUG_PREFIX, L"T_CON timeout, repeat SEND: ", CARDINAL( ChannelId ));

               IOState := ioWaitTCON2;
               DoSend();
            END;

         | ioWaitTCON2 :
            _Logger^.LogSC( ldTrace, 0, DEBUG_PREFIX, L"T_CON timeout, kill SEND: ", CARDINAL( ChannelId ));

            // INC( OutSeq ); // prepare next writing -- unable to do, if remote peer does not ACKs packet, it expects ONLY the next one... Maybe, it should accept newer packets, but it does not do so
            INC( SendErr ); // increment connection recovery counter
            IOState := ioReady;
            On_L_CON( knx_status.essL_Timeout );

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
      cr : transport.ConnectRequest;
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
         b := netsrv.StartListen( netsocket.stDatagram, ai, NIL, _Listener, timeout, ADR( _Socket )) = 0;
      | cmRouting :
         ai.Port := transport.KNXNET_IPPORT;
         b := netsrv.StartListen( netsocket.stDatagram, ai, NIL, _Listener, 0, ADR( _Socket )) = 0;
      ELSE
         b := netsrv.StartListen( netsocket.stDatagram, ai, NIL, _Listener, timeout, ADR( _Socket )) = 0;
      END;
      IF b THEN
         _Logger^.LogSC( ldTrace, 0, DEBUG_PREFIX, L"LISTENing on port: ", _Socket^.LocalAddress.Port );
         LogSHPAI( _Logger, ldTrace, DEBUG_PREFIX, L"CONNECT request: ", HPAIData );
      ELSE
         _Logger^.LogS( ldTrace, 0, DEBUG_PREFIX, L"CONNECT (listen) cannot start" );
         _Socket := NIL;

         // #100, tiAutoReconnect starts in OnDisconnect. But OnDisconnect is not called if Connect is not called (as here when returning).
         // The conditions described caused that automatic reconnection was not functional, because it stops with first returning
         // by this RETURN (below).
         IF _AutoReconnectDelay <> 0 THEN
            StartTimer( PTR( tiAutoReconnect ), _AutoReconnectDelay, FALSE );
         END;

         RETURN Sync.arCannotStart;
      END;
      IF _Mode = cmTunnelingBlind THEN
        HPAISelf.Port := 0;
      ELSE
        HPAISelf.Port := _Socket^.LocalAddress.Port;
      END;

      CASE _Mode OF
      //-----
      | cmScanning :
         dns.GetLocalIPs( TRUE, FALSE, FALSE, OUT OA( 0, ADR( ai )), OUT l );
         ai.Port := _Socket^.LocalAddress.Port;
         HPAISelf.Address := ai;

         ai.FromOA( transport.KNXNET_DISCOVERY_ADDRESS, transport.KNXNET_IPPORT );
         _Socket^.MulticastGroup := ai;
         IOState := ioReady;

         LogSHPAI( _Logger, ldTrace, DEBUG_PREFIX, L"CONNECTed in SCANNING mode: ", HPAIData );
         RETURN Sync.arCompleted;

      //-----
      | cmRouting :
         _Socket^.MulticastGroup := HPAIData.Address;
         IOState := ioReady;
         OnConnect();

         LogSHPAI( _Logger, ldTrace, DEBUG_PREFIX, L"CONNECTed in ROUTING mode: ", HPAIData );
         RETURN Sync.arCompleted;

      //-----
      | cmTunnelingHPAI :
         dns.GetLocalIPs( TRUE, FALSE, FALSE, OUT OA( 0, ADR( ai )), OUT l );
         ai.Port := _Socket^.LocalAddress.Port;
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

      // here we are always in tunneling mode
      CASE _TunnelingMode OF
      | tmEMI :
         cr.KNXLayer := transport.TUNNEL_LINKLAYER;
      | tmRaw :
         cr.KNXLayer := transport.TUNNEL_RAW;
      | tmBusmonitor :
         cr.KNXLayer := transport.TUNNEL_BUSMONITOR;
      ELSE
         ASSERTLOG( FALSE );
      END;
      cr.ControlHPAI := HPAISelf;
      cr.DataHPAI := HPAISelf;
      RETURN _Socket^.SendToOA( OA( cr.Length-1, ADR( cr )), HPAICtrl.Address );
   END Connect;

(*--------------------------------------------------------------------------------*)

   PUBLIC PROCEDURE Disconnect( Abortive : BOOLEAN ) : Sync.TAsyncResult;
   VAR
      dr : transport.DisconnectRequest;
      abortive : BOOLEAN := FALSE;
   BEGIN
      IF Abortive AND ( IOState <> ioDisconnected ) THEN
         abortive := TRUE;
         _Logger^.LogS( ldTrace, 0, DEBUG_PREFIX, L"DISCONNECT forced as abortive" );
      ELSIF Disconnected THEN
         RETURN Sync.arCompleted;
      END;

      LogSCHPAI( _Logger, ldTrace, DEBUG_PREFIX, L"DISCONNECT request: ", CARDINAL( ChannelId ), HPAIData );

      DataDisconnect();

      IF abortive THEN
         DeviceDisconnect();
      ELSIF ( _Mode = cmTunnelingHPAI ) OR ( _Mode = cmTunnelingBlind ) THEN
         StartTimer( PTR( tiDisconnect ), DISCONNECT_TIMEOUT, FALSE );
         dr.ControlHPAI := HPAISelf;
         dr.ChannelId := ChannelId;
         RETURN _Socket^.SendToOA( OA( dr.Length-1, ADR( dr )), HPAICtrl.Address );
      ELSE
         DeviceDisconnect();
      END;
      RETURN Sync.arCompleted;
   END Disconnect;

(*--------------------------------------------------------------------------------*)

   PUBLIC PROCEDURE SendPacket( CONST EMI : knx_def.TPacket ) : Sync.TAsyncResult;
   BEGIN
      IF ( IOState = ioDisconnected ) OR ( IOState = ioConnecting ) OR ( IOState = ioDisconnecting ) THEN
         _Logger^.LogS( ldTrace, 0, DEBUG_PREFIX, L"SEND request when disconnected" );
         RETURN Sync.arCannotStart;
      ELSIF _Mode = cmScanning THEN
         _Logger^.LogS( ldTrace, 0, DEBUG_PREFIX, L"SEND request in scanning mode" );
         RETURN Sync.arCannotStart;
      ELSIF IOState <> ioReady THEN
         _Logger^.LogSC( ldTrace, 0, DEBUG_PREFIX, L"SEND request when not ready: ", CARDINAL( ChannelId ));
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
      packet : transport.TPPacket := transport.TPPacket( ADR( buffer ));
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
            _Logger^.LogSH( ldMessage, 0, DEBUG_PREFIX, L"Packet from unexpected source, REJECTED: ", CARDINAL( packet^.Service ));
            _Logger^.LogSB( ldMessage, 0, DEBUG_PREFIX, L"  rejected data: ", packet, packet^.Length );
         END;
      END; // CASE
      
      CASE _Mode OF
      //-----
      | cmScanning :
         CASE packet^.Service OF
         | transport.SEARCH_RESPONSE,
           transport.DESCRIPTION_RESPONSE :
         ELSE
            _Logger^.LogSCP( ldMessage, 0, DEBUG_PREFIX, L"packet rejected in SCANNING mode: ", CARDINAL( ChannelId ), PTR( packet^.Service ));
            _Logger^.LogSB( ldMessage, 0, DEBUG_PREFIX, L"  rejected data: ", packet, packet^.Length );
            RETURN;
         END; // Service
      //-----
      | cmRouting :
         CASE packet^.Service OF
         | transport.DESCRIPTION_RESPONSE,
           transport.ROUTING_INDICATION,
           transport.ROUTING_LOST_MESSAGE :
         ELSE
            _Logger^.LogSCP( ldMessage, 0, DEBUG_PREFIX, L"packet rejected in ROUTING mode: ", CARDINAL( ChannelId ), PTR( packet^.Service ));
            _Logger^.LogSB( ldMessage, 0, DEBUG_PREFIX, L"  rejected data: ", packet, packet^.Length );
            RETURN;
         END; // Service
      //-----
      | cmTunnelingHPAI, cmTunnelingBlind :
         CASE packet^.Service OF
         | transport.DESCRIPTION_RESPONSE :
         | transport.CONNECT_RESPONSE :
            IF IOState <> ioConnecting THEN
               _Logger^.LogSCP( ldMessage, 0, DEBUG_PREFIX, L"packet rejected as unexpected: ", CARDINAL( ChannelId ), PTR( packet^.Service ));
               _Logger^.LogSB( ldMessage, 0, DEBUG_PREFIX, L"  rejected data: ", packet, packet^.Length );
               RETURN;
            END;
         | transport.CONNECTIONSTATE_RESPONSE,
           transport.DISCONNECT_REQUEST,
           transport.TUNNELING_REQUEST,
           transport.TUNNELING_ACK :
            IF IOState NOT IN iosConnected THEN
               _Logger^.LogSCP( ldMessage, 0, DEBUG_PREFIX, L"packet rejected as unexpected: ", CARDINAL( ChannelId ), PTR( packet^.Service ));
               _Logger^.LogSB( ldMessage, 0, DEBUG_PREFIX, L"  rejected data: ", packet, packet^.Length );
               RETURN;
            END;
         | transport.DISCONNECT_RESPONSE :
            IF IOState <> ioDisconnecting THEN
               _Logger^.LogSCP( ldMessage, 0, DEBUG_PREFIX, L"packet rejected as unexpected: ", CARDINAL( ChannelId ), PTR( packet^.Service ));
               _Logger^.LogSB( ldMessage, 0, DEBUG_PREFIX, L"  rejected data: ", packet, packet^.Length );
               RETURN;
            END;
         ELSE
            _Logger^.LogSCP( ldMessage, 0, DEBUG_PREFIX, L"packet rejected in TUNNELING mode: ", CARDINAL( ChannelId ), PTR( packet^.Service ));
            _Logger^.LogSB( ldMessage, 0, DEBUG_PREFIX, L"  rejected data: ", packet, packet^.Length );
            RETURN;
         END;
      //-----
      END; // CASE
      
      CASE packet^.Service OF
      //-----
      | transport.SEARCH_RESPONSE :
         IF transport.TPSearchResponse( packet )^.Valid THEN
            OnSearchResponse( transport.TPSearchResponse( packet )^ );
         ELSE
            _Logger^.LogSCB( ldMessage, 0, DEBUG_PREFIX, L"invalid packet ", CARDINAL( ChannelId ), packet, l );
         END;
      //-----
      | transport.DESCRIPTION_RESPONSE :
         IF transport.TPDescriptionResponse( packet )^.Valid THEN
            OnDescriptionResponse( transport.TPDescriptionResponse( packet )^ );
         ELSE
            _Logger^.LogSCB( ldMessage, 0, DEBUG_PREFIX, L"invalid packet ", CARDINAL( ChannelId ), packet, l );
         END;
      //-----
      | transport.ROUTING_INDICATION :
         IF transport.TPRoutingIndication( packet )^.Valid THEN
            OnRoutingIndication( transport.TPRoutingIndication( packet )^ );
         ELSE
            _Logger^.LogSCB( ldMessage, 0, DEBUG_PREFIX, L"invalid packet ", CARDINAL( ChannelId ), packet, l );
         END;
      //-----
      | transport.ROUTING_LOST_MESSAGE :
         IF transport.TPRoutingLostMessage( packet )^.Valid THEN
            OnRoutingLostMessage( transport.TPRoutingLostMessage( packet )^ );
         ELSE
            _Logger^.LogSCB( ldMessage, 0, DEBUG_PREFIX, L"invalid packet ", CARDINAL( ChannelId ), packet, l );
         END;
      //-----
      | transport.CONNECT_RESPONSE :
         IF transport.TPConnectResponse( packet )^.Valid THEN
            OnConnectResponse( transport.TPConnectResponse( packet )^ );
         ELSE
            _Logger^.LogSCB( ldMessage, 0, DEBUG_PREFIX, L"invalid packet ", CARDINAL( ChannelId ), packet, l );
         END;
      //-----
      | transport.CONNECTIONSTATE_RESPONSE :
         IF transport.TPConnectionStateResponse( packet )^.Valid THEN
            OnConnectionStateResponse( transport.TPConnectionStateResponse( packet )^ );
         ELSE
            _Logger^.LogSCB( ldMessage, 0, DEBUG_PREFIX, L"invalid packet ", CARDINAL( ChannelId ), packet, l );
         END;
      //-----
      | transport.DISCONNECT_REQUEST :
         IF transport.TPDisconnectRequest( packet )^.Valid THEN
            OnDisconnectRequest( transport.TPDisconnectRequest( packet )^ );
         ELSE
            _Logger^.LogSCB( ldMessage, 0, DEBUG_PREFIX, L"invalid packet ", CARDINAL( ChannelId ), packet, l );
         END;
      //-----
      | transport.DISCONNECT_RESPONSE :
         IF transport.TPDisconnectResponse( packet )^.Valid THEN
            OnDisconnectResponse( transport.TPDisconnectResponse( packet )^ );
         ELSE
            _Logger^.LogSCB( ldMessage, 0, DEBUG_PREFIX, L"invalid packet ", CARDINAL( ChannelId ), packet, l );
         END;
      //-----
      | transport.TUNNELING_REQUEST :
         IF transport.TPTunnelingRequest( packet )^.Valid THEN
            OnTunnelingRequest( transport.TPTunnelingRequest( packet )^ );
         ELSE
            _Logger^.LogSCB( ldMessage, 0, DEBUG_PREFIX, L"invalid packet ", CARDINAL( ChannelId ), packet, l );
         END;
      //-----
      | transport.TUNNELING_ACK :
         IF transport.TPTunnelingACK( packet )^.Valid THEN
            OnTunnelingACK( transport.TPTunnelingACK( packet )^ );
         ELSE
            _Logger^.LogSCB( ldMessage, 0, DEBUG_PREFIX, L"invalid packet ", CARDINAL( ChannelId ), packet, l );
         END;
      END; // main case
   END OnDatagramReceived;

(*--------------------------------------------------------------------------------*)

   LOCAL PROCEDURE OnListenSocketClosed( CONST ServerSocket : netsocket.TPSSocket );
   BEGIN
      _Logger^.LogSC( ldTrace, 0, DEBUG_PREFIX, L"Stop LISTENing on port: ", ServerSocket^.LocalAddress.Port );
      
      IF _Socket = ServerSocket THEN
         _Socket := NIL;
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

   INTERNAL VIRTUAL PROCEDURE OnSearchResponse( CONST packet : transport.SearchResponse );
   BEGIN
   END OnSearchResponse;

(*--------------------------------------------------------------------------------*)

   INTERNAL VIRTUAL PROCEDURE OnDescriptionResponse( CONST packet : transport.DescriptionResponse );
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

   INTERNAL VIRTUAL PROCEDURE On_L_CON( Status : knx_status.TKNXStackStatus );
   BEGIN
   END On_L_CON;

(*--------------------------------------------------------------------------------*)

   INTERNAL VIRTUAL PROCEDURE On_L_IND( CONST packet : knx_def.TPacket );
   BEGIN
   END On_L_IND;

(*--------------------------------------------------------------------------------*)

   INTERNAL VIRTUAL PROCEDURE TestSelfPacket( CONST packet : knx_def.TPacket ) : BOOLEAN;
   BEGIN
      RETURN TRUE;
   END TestSelfPacket;

(*--------------------------------------------------------------------------------*)

   PRIVATE PROCEDURE OnRoutingIndication( CONST packet : transport.RoutingIndication );
   VAR
      EMI : knx_def.TPacket;
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

   PRIVATE PROCEDURE OnRoutingLostMessage( CONST packet : transport.RoutingLostMessage );
   BEGIN
      _Logger^.LogSC( ldTrace, 0, DEBUG_PREFIX, L"ROUTING L_CON error, lost: ", CARDINAL( packet.LostCount ));

      StopTimer( PTR( tiACK ));
      IOState := ioReady;
      
      On_L_CON( knx_status.essLineBusy );
   END OnRoutingLostMessage;

(*--------------------------------------------------------------------------------*)

   PRIVATE PROCEDURE OnConnectResponse( CONST packet : transport.ConnectResponse );
   BEGIN
      IF packet.Status = transport.E_NO_ERROR THEN
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

         LogSCHPAI( _Logger, ldTrace, DEBUG_PREFIX, L"CONNECTed in TUNNELING mode: ", CARDINAL( ChannelId ), HPAIData );

         HbRepeat := maximalHbRepeat;
         StartTimer( PTR( tiHeartbeat ), transport.HEART_BEAT_PERIOD, TRUE );

         OnConnect();
      ELSE
         LogSCHPAI( _Logger, ldTrace, DEBUG_PREFIX, L"CONNECT failure: ", CARDINAL( packet.Status ), HPAIData );

         DeviceDisconnect();
      END;
   END OnConnectResponse;

(*--------------------------------------------------------------------------------*)

   PRIVATE PROCEDURE OnConnectionStateResponse( CONST packet : transport.ConnectionStateResponse );
   BEGIN
      IF packet.Status = transport.E_NO_ERROR THEN
         LogSCHPAI( _Logger, ldDebug, DEBUG_PREFIX, L"HEARTBEAT response: ", CARDINAL( ChannelId ), HPAIData );

         StopTimer( PTR( tiHeartbeatRepeat ));
         HbRepeat := maximalHbRepeat;
         
         IF SendErr > 0 THEN // server does not ACKed anything, reset the connection
            Disconnect( FALSE );
         END;
      ELSE
         LogSCHPAI( _Logger, ldDebug, DEBUG_PREFIX, L"HEARTBEAT error: ", CARDINAL( packet.Status ), HPAIData );

         ProcessHbFailure();
      END;
   END OnConnectionStateResponse;

(*--------------------------------------------------------------------------------*)

   PRIVATE PROCEDURE OnDisconnectRequest( CONST packet : transport.DisconnectRequest );
   VAR
      dr : transport.DisconnectResponse;
   BEGIN
      IF NOT Disconnected THEN
         LogSCHPAI( _Logger, ldTrace, DEBUG_PREFIX, L"remote DISCONNECT request: ", CARDINAL( ChannelId ), HPAIData );

         DataDisconnect();

         dr.ChannelId := ChannelId;
         _Socket^.SendToOA( OA( dr.Length-1, ADR( dr )), HPAICtrl.Address );
      END;

      DeviceDisconnect();
   END OnDisconnectRequest;

(*--------------------------------------------------------------------------------*)

   PRIVATE PROCEDURE OnDisconnectResponse( CONST packet : transport.DisconnectResponse );
   BEGIN
      DeviceDisconnect();
   END OnDisconnectResponse;

(*--------------------------------------------------------------------------------*)

   PRIVATE PROCEDURE OnTunnelingRequest( CONST packet : transport.TunnelingRequest );
   VAR
      EMI : knx_def.TPacket;
      Error : BOOLEAN;
      tack : transport.TunnelingACK;
      pSeq : CARD8 := packet.Sequence;
   BEGIN
      IF packet.ChannelId <> ChannelId THEN
         _Logger^.LogSC( ldMessage, 0, DEBUG_PREFIX, L"RECEIVE unexpected channel: ", CARDINAL( ChannelId ));
         _Logger^.LogSB( ldMessage, 0, DEBUG_PREFIX, L"RECEIVE unexpected data: ", ADR( packet ), packet.Length );
         RETURN; // ignore

      ELSIF pSeq + 1 < CARD8( AltInSeq ) THEN
         _Logger^.LogSCP( ldMessage, 0, DEBUG_PREFIX, L"RECEIVE out of order: ", CARDINAL( ChannelId ), PTR( pSeq ));
         RETURN; // ignore
      END;

      tack.ChannelId := ChannelId;
      tack.Sequence := pSeq;
      tack.Success := TRUE;
      _Socket^.SendToOA( OA( tack.Length-1, ADR( tack )), HPAIData.Address );

      IF pSeq < CARD8( AltInSeq ) THEN
         _Logger^.LogSCP( ldTrace, 0, DEBUG_PREFIX, L"RECEIVE previous: ", CARDINAL( ChannelId ), PTR( pSeq ));
         RETURN;
      END;

      EMI := packet.EMI;
      CASE EMI.Code OF
      | knx_def.L_Data_CON, knx_def.L_Data_CON_EMI2 : // L_CON
         Error := EMI.GetError();
         IF Error THEN
            LogPacket( FALSE, L"SEND R_CON error", EMI, ADR( packet ), packet.Length, FALSE );
         ELSE
            LogPacket( FALSE, L"SEND R_CON ok", EMI, ADR( packet ), packet.Length, FALSE );
         END;
         _Logger^.LogSCP( ldDebug, 0, DEBUG_PREFIX, L"SEND R_CON status: ", CARDINAL( ChannelId ), PTR( EMI.GetError() ));

         // IOState := ioReady; -- not to set here, CConnection is ready after T_CON, L_ACK is matter of KNX and stack itself (and ACKTimeout is set there, of course)
         // ioReady is set in OnTunnelingACK.
         IF Error THEN
            On_L_CON( knx_status.essConError );
         ELSE
            On_L_CON( knx_status.essOK );
         END;

      | knx_def.L_Data_IND, knx_def.L_Data_IND_EMI2 : // L_IND
         LogPacket( FALSE, L"RECEIVE", EMI, ADR( packet ), packet.Length, FALSE );
         On_L_IND( EMI );

      ELSE // L_REQ???
         _Logger^.LogSCP( ldTrace, 0, DEBUG_PREFIX, L"RECEIVE unexpected code: ", CARDINAL( ChannelId ), PTR( EMI.Code ));
      END;

      AltInSeq := InSeq + 1; // use self -- this could be less in case of error
      InSeq := CARDINAL( pSeq ) + 1; // use packet's -- this could skip missing packets
      AltInSeq := MIN2( AltInSeq, InSeq ); // AltInSeq must be always less than InSeq
   END OnTunnelingRequest;

(*--------------------------------------------------------------------------------*)

   PRIVATE PROCEDURE OnTunnelingACK( CONST packet : transport.TunnelingACK );
   VAR
      Status : transport.TStatus;
   BEGIN
      IF packet.ChannelId <> ChannelId THEN
         _Logger^.LogSC( ldMessage, 0, DEBUG_PREFIX, L"SEND T_CON unexpected channel: ", CARDINAL( ChannelId ));
         _Logger^.LogSB( ldMessage, 0, DEBUG_PREFIX, L"SEND T_CON unexpected data: ", ADR( packet ), packet.Length );
         RETURN; // ignore
      END;
         
      Status := packet.Status;
      IF NOT _Logger^.FilteredFastCheck( ldDebug, 0 ) THEN
         _Logger^.LogSCP( ldDebug, 0, DEBUG_PREFIX, L"SEND T_CON status: ", CARDINAL( ChannelId ), PTR( Status ));
         _Logger^.LogSH( ldDebug, 0, DEBUG_PREFIX, L"SEND T_CON seq: ", CARDINAL( packet.Sequence ));
      END;

      IF packet.Sequence = CARD8( OutSeq ) THEN
        INC( OutSeq ); // prepare next writing
      END;

      // stop TCON timeouting
      StopTimer( PTR( tiACK ));
      SendErr := 0; // reset connection recovery counter

      // Set ioReady here, CConnection is ready after T_CON. L_ACK is matter of KNX and stack itself (and ACKTimeout is set there, of course, and counted too).
      IOState := ioReady;

      // notify stack about mine job finish   
      On_P_Sent();

      // and handle error
      CASE Status OF
      | transport.E_NO_ERROR :
         // no L_CON must be done here, L_CON is received and processed when cEMI frame carries it, only notify send and leave timeouting etc. to Stack
      | transport.E_SEQUENCE_NUMBER : // error in seq numbers, this is not recoverable
         On_L_CON( knx_status.essTransceiverFault );
         Disconnect( FALSE );
      | transport.E_DATA_CONNECTION, transport.E_KNX_CONNECTION :
         On_L_CON( knx_status.essTransceiverFault );
      ELSE
         On_L_CON( knx_status.essLineBusy );
      END;
   END OnTunnelingACK;

(*--------------------------------------------------------------------------------*)

   PRIVATE PROCEDURE DoSend() : Sync.TAsyncResult;
   VAR
      address : knx_def.TAddress;
      res : Sync.TAsyncResult;
      rr : transport.RoutingIndication;
      tr : transport.TunnelingRequest;
      s : ARRAY [0..31] OF WCHAR;
   BEGIN
      IF _Mode = cmRouting THEN
         rr.EMI := EMI;

         LogPacket( TRUE, L"ROUTED out", EMI, ADR( rr ), rr.Length, FALSE );

         StartTimer( PTR( tiACK ), transport.ROUTING_L_CON_TIME_OUT, FALSE );
         res := _Socket^.SendOA( OA( rr.Length-1, ADR( rr ))); // send to internal multicast group

      ELSIF _Mode = cmScanning THEN
         RETURN Sync.arCannotStart;

      ELSE // ELSIF ( _Mode = cmTunnelingHPAI ) OR ( _Mode = cmTunnelingBlind ) THEN
         tr.ChannelId := ChannelId;
         tr.Sequence := CARD8( OutSeq );
         tr.EMI := EMI;
         
         LogPacket( TRUE, L"SEND", EMI, ADR( tr ), tr.Length, FALSE );

         StartTimer( PTR( tiACK ), transport.TUNNELING_REQUEST_TIME_OUT, FALSE );
         res := _Socket^.SendToOA( OA( tr.Length-1, ADR( tr )), HPAIData.Address ); // send to specified address
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
         On_L_CON( knx_status.essTransceiverFault );
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
      LogSCHPAI( _Logger, ldTrace, DEBUG_PREFIX, L"DISCONNECTed: ", CARDINAL( ChannelId ), HPAIData );

      StopTimer( PTR( tiDisconnect ));
      IF _Socket <> NIL THEN
         netsrv.StopListenSocket( REF _Socket );
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
      hb : transport.ConnectionStateRequest;
   BEGIN
      IF HbRepeat = 0 THEN
         Disconnect( FALSE );
         RETURN;
      ELSE
         DEC( HbRepeat );
      END;

      LogSCHPAI( _Logger, ldDebug, DEBUG_PREFIX, L"HEARTBEAT probe: ", CARDINAL( ChannelId ), HPAIData );

      hb.ControlHPAI := HPAISelf;
      hb.ChannelId := ChannelId;
      StartTimer( PTR( tiHeartbeatRepeat ), transport.HEART_BEAT_TIMEOUT, FALSE );
      _Socket^.SendToOA( OA( hb.Length-1, ADR( hb )), HPAICtrl.Address );
   END ProcessHbFailure;

(*--------------------------------------------------------------------------------*)

   PRIVATE PROCEDURE LogPacket( outputFlag : BOOLEAN; CONST text : ARRAY OF WCHAR; CONST packet : knx_def.TPacket; data : ADDRESS; dataLen : CARDINAL; selfPacket : BOOLEAN );
   VAR
      address : knx_def.TAddress;
      s : ARRAY [0..31] OF WCHAR;
      seq : CARDINAL;
      out : ARRAY [0..63] OF WCHAR;
   BEGIN
      IF NOT _Logger^.FilteredFastCheck( ldTrace, 0 ) THEN
         out := text;
         IF selfPacket THEN
            Strings.AppendW( REF out, L" [S]" ); 
         END;

         // channel id
         Strings.FromCARD32W( CARDINAL( ChannelId ), 10, OUT s );
         Strings.AppendW( REF out, L" " ); 
         Strings.AppendW( REF out, s ); 
      
         address := packet.GetDestinationAddress();
         IF address.GetAddressType() = knx_def.addressGroup THEN
            address.GetGroupAddress3( TRUE, OUT s );
            Strings.AppendW( REF out, L" group: " ); _Logger^.LogSS( ldTrace, 0, DEBUG_PREFIX, out, s );
         ELSE
            Strings.AppendW( REF out, L" not group" ); _Logger^.LogS( ldTrace, 0, DEBUG_PREFIX, out );
         END;
         IF NOT outputFlag AND ( InSeq <> AltInSeq ) THEN
            Strings.ConcatW( OUT out, text, L" altseq: " ); _Logger^.LogSH( ldTrace, 0, DEBUG_PREFIX, out, AltInSeq );
         END;

         IF NOT _Logger^.FilteredFastCheck( ldDebug, 0 ) THEN
            IF outputFlag THEN
               seq := CARDINAL( CARD8( OutSeq ));
            ELSE
               seq := CARDINAL( CARD8( InSeq ));
            END;
            Strings.ConcatW( OUT out, text, L" seq: " ); _Logger^.LogSH( ldDebug, 0, DEBUG_PREFIX, out, seq );
            Strings.ConcatW( OUT out, text, L" data: " ); _Logger^.LogSB( ldDebug, 0, DEBUG_PREFIX, out, data, dataLen );
         END;
      END;
   END LogPacket;

(*--------------------------------------------------------------------------------*)

   INITIALLY CConnection;
   BEGIN
      _Logger := log.logger();

      Init( TRUE );
   
      _Socket := NIL;
      NEW( _Listener );
      _Listener^.Connection := ADR( SELF );
   END CConnection;

(*--------------------------------------------------------------------------------*)

   FINALLY CConnection;
   BEGIN
      StopTimer( PTR( tiConnect )); // tiAutoReconnect timer can alive -- it is started in Connect. But, device is not connected and outer (KnxStack's) call to Disconnect is skipped as Disconnect is not needed. tiConnect is not stopped for that case. It must be done here.
      StopTimer( PTR( tiAutoReconnect )); // tiAutoReconnect timer can alive -- after Connect, when time elapses, tiAutoConnect is started. But device is not connected and outer (KnxStack's) call to Disconnect is skipped as Disconnect is not needed. tiAutoConnect is not stopped for that case. It must be done here.

      Disconnect( TRUE );

      IF _Listener <> NIL THEN // this occurs in case of multiple FINALLY calls
         _Listener^.Connection := NIL;
         _Listener^.Release();
      END;
      _Listener := NIL;
   END CConnection;

(*--------------------------------------------------------------------------------*)

END CConnection;

(*================================================================================*)

END protocol.