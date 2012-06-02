IMPLEMENTATION MODULE KNXStack_KNXnet;

(*================================================================================*)
(*/* UPDATES
*/*)
(*================================================================================*)

FROM Storage IMPORT
   ALLOCATE, DEALLOCATE;
  
IMPORT
   dns,
   knx_def,
   inetaddr,
   log,
   netsrv,
   protocol,
   Strings,
   Sync,
   transport;

(*================================================================================*)

TYPE
   TPKNXnetPhysicalLayer = POINTER TO KNXnetPhysicalLayer;

CLASS CStackConnection( protocol.CConnection );
   LOCAL VAR
      Stack : TPKNXnetPhysicalLayer := NIL;

   INTERNAL VIRTUAL PROCEDURE OnConnect();
   INTERNAL VIRTUAL PROCEDURE OnDisconnect();

   INTERNAL VIRTUAL PROCEDURE On_P_Sent();
   INTERNAL VIRTUAL PROCEDURE On_L_CON( Status : knx_status.TKNXStackStatus );
   INTERNAL VIRTUAL PROCEDURE On_L_IND( CONST packet : knx_def.TPacket );

   INTERNAL VIRTUAL PROCEDURE TestSelfPacket( CONST packet : knx_def.TPacket ) : BOOLEAN;
END CStackConnection;

(*================================================================================*)

CLASS KNXnetPhysicalLayer( knx_stack.CKNXStackPhysicalLayer );
   PRIVATE VAR
      Connection : CStackConnection;
   PUBLIC PROPERTY
      Logger : log.TPLogger;
      Mode : protocol.TConnectionMode;
      RemoteAddress : inetaddr.INETADDR; // routing or remote/tunneling address
      InterfaceAddress : inetaddr.INETADDR;

   PUBLIC PROCEDURE Connect() : Sync.TAsyncResult;
   PUBLIC PROCEDURE Connected() : BOOLEAN;
   PUBLIC PROCEDURE Disconnect() : Sync.TAsyncResult;

   LOCAL VIRTUAL PROCEDURE Initialize_Req();
   LOCAL VIRTUAL PROCEDURE Done_Req();

   PUBLIC VIRTUAL PROCEDURE Ph_Reset_Req();
   PUBLIC VIRTUAL PROCEDURE Ph_Data_Req( VAR EMI : knx_def.TPacket );
END KNXnetPhysicalLayer;

(*================================================================================*)

CLASS IMPLEMENTATION CStackConnection;

(*--------------------------------------------------------------------------------*)

   INTERNAL VIRTUAL PROCEDURE OnConnect();
   BEGIN
      Stack^.PStack^.OnDeviceConnected();
   END OnConnect;

(*--------------------------------------------------------------------------------*)

   INTERNAL VIRTUAL PROCEDURE OnDisconnect();
   BEGIN
      Stack^.PStack^.OnDeviceDisconnected();
   END OnDisconnect;

(*--------------------------------------------------------------------------------*)

   INTERNAL VIRTUAL PROCEDURE On_P_Sent();
   BEGIN
      Stack^.Ph_Data_Sent();
   END On_P_Sent;

(*--------------------------------------------------------------------------------*)

   INTERNAL VIRTUAL PROCEDURE On_L_CON( Status : knx_status.TKNXStackStatus );
   BEGIN
      Stack^.Listener()^.Ph_Data_Con( Status );
   END On_L_CON;

(*--------------------------------------------------------------------------------*)

   INTERNAL VIRTUAL PROCEDURE On_L_IND( CONST packet : knx_def.TPacket );
   BEGIN
      Stack^.Listener()^.Ph_Data_Ind( knx_def.TPPacket( ADR( packet )));
   END On_L_IND;

(*--------------------------------------------------------------------------------*)

   INTERNAL VIRTUAL PROCEDURE TestSelfPacket( CONST packet : knx_def.TPacket ) : BOOLEAN;
   BEGIN
      RETURN Stack^.PStack^.IsSelfPacket( knx_def.TPPacket( ADR( packet )));
   END TestSelfPacket;

(*--------------------------------------------------------------------------------*)

BEGIN
END CStackConnection;

(*================================================================================*)

CLASS IMPLEMENTATION KNXnetPhysicalLayer;

(*--------------------------------------------------------------------------------*)

   PUBLIC PROPERTY Logger GET : log.TPLogger;
   BEGIN
      RETURN Connection.Logger;
   END Logger;

(*--------------------------------------------------------------------------------*)

   PUBLIC PROPERTY Logger SET( Value : log.TPLogger );
   BEGIN
      Connection.Logger := Value;
   END Logger;

(*--------------------------------------------------------------------------------*)

   PUBLIC PROPERTY Mode GET : protocol.TConnectionMode;
   BEGIN
      RETURN Connection.Mode;
   END Mode;

(*--------------------------------------------------------------------------------*)

   PUBLIC PROPERTY Mode SET( Value : protocol.TConnectionMode );
   BEGIN
      Connection.Mode := Value;
   END Mode;

(*--------------------------------------------------------------------------------*)

   PUBLIC PROPERTY RemoteAddress GET : inetaddr.INETADDR;
   BEGIN
      RETURN Connection.RemoteAddress;
   END RemoteAddress;

(*--------------------------------------------------------------------------------*)

   PUBLIC PROPERTY RemoteAddress SET( CONST Value : inetaddr.INETADDR );
   BEGIN
      Connection.RemoteAddress := Value;
   END RemoteAddress;

(*--------------------------------------------------------------------------------*)

   PUBLIC PROPERTY InterfaceAddress GET : inetaddr.INETADDR;
   BEGIN
      RETURN Connection.InterfaceAddress;
   END InterfaceAddress;

(*--------------------------------------------------------------------------------*)

   PUBLIC PROPERTY InterfaceAddress SET( CONST Value : inetaddr.INETADDR );
   BEGIN
      Connection.InterfaceAddress := Value;
   END InterfaceAddress;

(*--------------------------------------------------------------------------------*)

   PUBLIC PROCEDURE Connect() : Sync.TAsyncResult;
   BEGIN
      Connection.AutoReconnectDelay := transport.HEART_BEAT_TIMEOUT;
      RETURN Connection.Connect( 0 );
   END Connect;

(*--------------------------------------------------------------------------------*)

   PUBLIC PROCEDURE Connected() : BOOLEAN;
   BEGIN
      RETURN Connection.Connected;
   END Connected;

(*--------------------------------------------------------------------------------*)

   PUBLIC PROCEDURE Disconnect() : Sync.TAsyncResult;
   BEGIN
      Connection.AutoReconnectDelay := 0;
      RETURN Connection.Disconnect( FALSE );
   END Disconnect;

(*--------------------------------------------------------------------------------*)

   LOCAL VIRTUAL PROCEDURE Initialize_Req();
   BEGIN
      Initialize_Con( knx_status.essOK );
   END Initialize_Req;

(*--------------------------------------------------------------------------------*)

   LOCAL VIRTUAL PROCEDURE Done_Req();
   BEGIN
      Connection.Disconnect( TRUE );
      Done_Con( knx_status.essOK );
   END Done_Req;

(*--------------------------------------------------------------------------------*)

   PUBLIC VIRTUAL PROCEDURE Ph_Reset_Req();
   BEGIN
      Done_Req();
      Initialize_Req();
   END Ph_Reset_Req;

(*--------------------------------------------------------------------------------*)

   PUBLIC VIRTUAL PROCEDURE Ph_Data_Req( VAR Packet : knx_def.TPacket );
   BEGIN
      IF NOT Connection.Connected THEN
         Listener()^.Ph_Data_Con( knx_status.essLineBusy );
      ELSIF Connection.SendPacket( Packet ) NOT IN Sync.arsStarts THEN
         Listener()^.Ph_Data_Con( knx_status.essLineBusy );
      END;
   END Ph_Data_Req;

(*--------------------------------------------------------------------------------*)

BEGIN
   Connection.Stack := ADR( SELF );
END KNXnetPhysicalLayer;

(*================================================================================*)

CLASS IMPLEMENTATION CKNXnetStack;

(*--------------------------------------------------------------------------------*)

   PUBLIC PROCEDURE SetLogger( Logger : log.TPLogger );
   BEGIN
      TPKNXnetPhysicalLayer( Layers[ knx_stack.kltPhysical ] )^.Logger := Logger;
   END SetLogger;

(*--------------------------------------------------------------------------------*)

   PUBLIC VIRTUAL PROCEDURE SetTimeout( TimeoutId : knx_stack.TTimeoutId; Timeout : CARDINAL; AuxiliarySpecification : LONGWORD );
   BEGIN
      CASE TimeoutId OF
      | knx_stack.tidL_ACKTimeout, knx_stack.tidL_BUSYDelay :
        // timeouts are fixed and cannot be changed
      ELSE
         SUPER.SetTimeout( TimeoutId, Timeout, AuxiliarySpecification );
      END; // CASE
   END SetTimeout;

(*--------------------------------------------------------------------------------*)

   INTERNAL VIRTUAL PROCEDURE Initialize() : knx_status.TKNXStackStatus;
   VAR
      res : knx_status.TKNXStackStatus;
   BEGIN
      res := SUPER.Initialize();
      IF res <> knx_status.essOK THEN
         RETURN res;
      END;

      // TUNNELING_REQUEST_TIME_OUT is counted twice, because send is tried twice; the coefficient 2.5 stands for
      // safety. And more, ACK timeout should never appear if connection and physical layer is correct.
      SUPER.SetTimeout( knx_stack.tidL_ACKTimeout, 25 * transport.TUNNELING_REQUEST_TIME_OUT DIV 10, 0 );
      SUPER.SetTimeout( knx_stack.tidL_BUSYDelay, 25 * transport.TUNNELING_REQUEST_TIME_OUT DIV 10, 0 );

      RETURN knx_status.essOK;
   END Initialize;

(*--------------------------------------------------------------------------------*)

   INTERNAL VIRTUAL PROCEDURE ConnectBUS() : knx_status.TKNXStackStatus;
   BEGIN
      IF TPKNXnetPhysicalLayer( Layers[ knx_stack.kltPhysical ] )^.Connect() IN Sync.arsStarts THEN
         RETURN knx_status.essOK;
      ELSE
         RETURN knx_status.essConnectError;
      END;
   END ConnectBUS;

(*--------------------------------------------------------------------------------*)

   INTERNAL VIRTUAL PROCEDURE DisconnectBUS() : knx_status.TKNXStackStatus;
   BEGIN
      IF TPKNXnetPhysicalLayer( Layers[ knx_stack.kltPhysical ] )^.Disconnect() IN Sync.arsStarts THEN
         RETURN knx_status.essOK;
      ELSE
         RETURN knx_status.essConnectError;
      END;
   END DisconnectBUS;

(*--------------------------------------------------------------------------------*)

  INTERNAL VIRTUAL PROCEDURE CreateLayer( Layer : knx_stack.TKNXStackLayerType; VAR PLayer : knx_stack.TPKNXStackLayer ) : BOOLEAN;
  BEGIN
    IF Layer = knx_stack.kltPhysical THEN
      NEW( TPKNXnetPhysicalLayer( PLayer ));
      RETURN TRUE;
    ELSE
      RETURN FALSE;
    END;
  END CreateLayer;

(*--------------------------------------------------------------------------------*)

   INTERNAL VIRTUAL PROCEDURE ParseParameter( CONST Parameter, Value : ARRAY OF WCHAR; OUT ErrorText : ARRAY OF WCHAR ) : TRISTATE; // -1 means unknown/unprocessed
   CONST
      kvRouting = L"routing";
      kvTunneling = L"tunneling";
      kvTunnelingNAT = L"tunneling-NAT";
   VAR
      Addr : inetaddr.INETADDR;
      Iface : inetaddr.INETADDR;
   BEGIN
      IF EQUALS( Parameter, L"link.mode" ) THEN
         IF EQUALS( Value, kvRouting ) THEN
            TPKNXnetPhysicalLayer( Layers[ knx_stack.kltPhysical ] )^.Mode := protocol.cmRouting;
         ELSIF EQUALS( Value, kvTunneling ) THEN
            TPKNXnetPhysicalLayer( Layers[ knx_stack.kltPhysical ] )^.Mode := protocol.cmTunnelingHPAI;
         ELSIF EQUALS( Value, kvTunnelingNAT ) THEN
            TPKNXnetPhysicalLayer( Layers[ knx_stack.kltPhysical ] )^.Mode := protocol.cmTunnelingBlind;
         ELSE
            ErrorText := L"Expected routing | tunneling | tunneling-NAT ";
            RETURN 0;
         END;

      ELSIF EQUALS( Parameter, L"link.connection" ) THEN
         IF NOT dns.NameToAddressWait( Value, transport.KNXNET_IPPORT, 2000, OUT OA( 0, ADR( Addr )), ADR( Iface )) THEN
            ErrorText := L"Expected DNS name | IP address optionally followed by colon with port number and interface to communicate through (like 10.0.0.1:3778->10.0.0.100)";
            RETURN 0;
         END;
         IF NOT Iface.Empty AND NOT netsrv.IsValidInterface( Iface ) THEN
            ErrorText := L"No interface with given address exists";
            RETURN 0;
         END;
         TPKNXnetPhysicalLayer( Layers[ knx_stack.kltPhysical ] )^.RemoteAddress := Addr;
         TPKNXnetPhysicalLayer( Layers[ knx_stack.kltPhysical ] )^.InterfaceAddress := Iface;
         
      ELSE
         RETURN -1;
      END;
      RETURN 1;
   END ParseParameter;

(*--------------------------------------------------------------------------------*)

   INTERNAL VIRTUAL PROCEDURE ConstructParameter( CONST Parameter : ARRAY OF WCHAR; OUT Value : ARRAY OF WCHAR ) : BOOLEAN;
   CONST
      kvRouting = L"routing";
      kvTunneling = L"tunneling";
      kvTunnelingNAT = L"tunneling-NAT";
   VAR
      Iface : inetaddr.INETADDR;
   BEGIN
      IF EQUALS( Parameter, L"link.mode" ) THEN
         CASE TPKNXnetPhysicalLayer( Layers[ knx_stack.kltPhysical ] )^.Mode OF
         | protocol.cmRouting :
            Value := kvRouting;
         | protocol.cmTunnelingHPAI :
            Value := kvTunneling;
         | protocol.cmTunnelingBlind :
            Value := kvTunnelingNAT;
         END;

      ELSIF EQUALS( Parameter, L"link.connection" ) THEN
         Iface := TPKNXnetPhysicalLayer( Layers[ knx_stack.kltPhysical ] )^.InterfaceAddress;
         TPKNXnetPhysicalLayer( Layers[ knx_stack.kltPhysical ] )^.RemoteAddress.ToOA( TRUE, ADR( Iface ), OUT Value );
         
      ELSE
         RETURN FALSE;
      END;
      RETURN TRUE;
   END ConstructParameter;

(*--------------------------------------------------------------------------------*)

  PUBLIC VIRTUAL PROCEDURE DeviceConnected() : BOOLEAN;
  BEGIN
    RETURN TPKNXnetPhysicalLayer( Layers[ knx_stack.kltPhysical ] )^.Connected();
  END DeviceConnected;

(*--------------------------------------------------------------------------------*)

  PUBLIC VIRTUAL PROCEDURE KNXConnected() : BOOLEAN;
  BEGIN
    RETURN DeviceConnected();
  END KNXConnected;

(*--------------------------------------------------------------------------------*)

BEGIN
END CKNXnetStack;

(*================================================================================*)

END KNXStack_KNXnet.