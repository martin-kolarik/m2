IMPLEMENTATION MODULE EIBNetStack;

(*================================================================================*)
(*/* UPDATES
*/*)
(*================================================================================*)

FROM Storage IMPORT
   ALLOCATE, DEALLOCATE;
  
IMPORT
   core,
   dns,
   eib_def,
   eibnet,
   inetaddr,
   log,
   Strings,
   Sync;

(*================================================================================*)

TYPE
   TPEIBNetPhysicalLayer = POINTER TO EIBNetPhysicalLayer;

CLASS CStackConnection( eibnet.CConnection );
   LOCAL VAR
      Stack : TPEIBNetPhysicalLayer := NIL;

   INTERNAL VIRTUAL PROCEDURE OnConnect();
   INTERNAL VIRTUAL PROCEDURE OnDisconnect();

   INTERNAL VIRTUAL PROCEDURE On_P_Sent();
   INTERNAL VIRTUAL PROCEDURE On_L_CON( Status : eib_status.TEIBStackStatus );
   INTERNAL VIRTUAL PROCEDURE On_L_IND( CONST packet : eib_def.TPacket );

   INTERNAL VIRTUAL PROCEDURE TestSelfPacket( CONST packet : eib_def.TPacket ) : BOOLEAN;
END CStackConnection;

(*================================================================================*)

CLASS EIBNetPhysicalLayer( eib_stack.CEIBStackPhysicalLayer );
   PRIVATE VAR
      Connection : CStackConnection;
   PUBLIC PROPERTY
      Logger : log.TPLogger;
      Mode : eibnet.TConnectionMode;
      RemoteAddress : inetaddr.INETADDR; // routing or remote/tunneling address

   PUBLIC PROCEDURE Connect() : Sync.TAsyncResult;
   PUBLIC PROCEDURE Connected() : BOOLEAN;
   PUBLIC PROCEDURE Disconnect() : Sync.TAsyncResult;

   LOCAL VIRTUAL PROCEDURE Initialize_Req();
   LOCAL VIRTUAL PROCEDURE Done_Req();

   PUBLIC VIRTUAL PROCEDURE Ph_Reset_Req();
   PUBLIC VIRTUAL PROCEDURE Ph_Data_Req( VAR EMI : eib_def.TPacket );
END EIBNetPhysicalLayer;

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

   INTERNAL VIRTUAL PROCEDURE On_L_CON( Status : eib_status.TEIBStackStatus );
   BEGIN
      Stack^.Listener()^.Ph_Data_Con( Status );
   END On_L_CON;

(*--------------------------------------------------------------------------------*)

   INTERNAL VIRTUAL PROCEDURE On_L_IND( CONST packet : eib_def.TPacket );
   BEGIN
      Stack^.Listener()^.Ph_Data_Ind( eib_def.TPPacket( ADR( packet )));
   END On_L_IND;

(*--------------------------------------------------------------------------------*)

   INTERNAL VIRTUAL PROCEDURE TestSelfPacket( CONST packet : eib_def.TPacket ) : BOOLEAN;
   BEGIN
      RETURN Stack^.PStack^.IsSelfPacket( eib_def.TPPacket( ADR( packet )));
   END TestSelfPacket;

(*--------------------------------------------------------------------------------*)

BEGIN
END CStackConnection;

(*================================================================================*)

CLASS IMPLEMENTATION EIBNetPhysicalLayer;

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

   PUBLIC PROPERTY Mode GET : eibnet.TConnectionMode;
   BEGIN
      RETURN Connection.Mode;
   END Mode;

(*--------------------------------------------------------------------------------*)

   PUBLIC PROPERTY Mode SET( Value : eibnet.TConnectionMode );
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

   PUBLIC PROCEDURE Connect() : Sync.TAsyncResult;
   BEGIN
      Connection.AutoReconnectDelay := core.HEART_BEAT_TIMEOUT;
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
      Initialize_Con( eib_status.essOK );
   END Initialize_Req;

(*--------------------------------------------------------------------------------*)

   LOCAL VIRTUAL PROCEDURE Done_Req();
   BEGIN
      Connection.Disconnect( TRUE );
      Done_Con( eib_status.essOK );
   END Done_Req;

(*--------------------------------------------------------------------------------*)

   PUBLIC VIRTUAL PROCEDURE Ph_Reset_Req();
   BEGIN
      Done_Req();
      Initialize_Req();
   END Ph_Reset_Req;

(*--------------------------------------------------------------------------------*)

   PUBLIC VIRTUAL PROCEDURE Ph_Data_Req( VAR Packet : eib_def.TPacket );
   BEGIN
      IF NOT Connection.Connected THEN
         Listener()^.Ph_Data_Con( eib_status.essLineBusy );
      ELSIF Connection.SendPacket( Packet ) NOT IN Sync.arsStarts THEN
         Listener()^.Ph_Data_Con( eib_status.essLineBusy );
      END;
   END Ph_Data_Req;

(*--------------------------------------------------------------------------------*)

BEGIN
   Connection.Stack := ADR( SELF );
END EIBNetPhysicalLayer;

(*================================================================================*)

CLASS IMPLEMENTATION CEIBNetStack;

(*--------------------------------------------------------------------------------*)

   PUBLIC PROCEDURE SetLogger( Logger : log.TPLogger );
   BEGIN
      TPEIBNetPhysicalLayer( Layers[ eib_stack.eltPhysical ] )^.Logger := Logger;
   END SetLogger;

(*--------------------------------------------------------------------------------*)

   PUBLIC VIRTUAL PROCEDURE SetTimeout( TimeoutId : eib_stack.TTimeoutId; Timeout : CARDINAL; AuxiliarySpecification : LONGWORD );
   BEGIN
      CASE TimeoutId OF
      | eib_stack.tidL_ACKTimeout, eib_stack.tidL_BUSYDelay :
        // timeouts are fixed and cannot be changed
      ELSE
         SUPER.SetTimeout( TimeoutId, Timeout, AuxiliarySpecification );
      END; // CASE
   END SetTimeout;

(*--------------------------------------------------------------------------------*)

   INTERNAL VIRTUAL PROCEDURE Initialize() : eib_status.TEIBStackStatus;
   VAR
      res : eib_status.TEIBStackStatus;
   BEGIN
      res := SUPER.Initialize();
      IF res <> eib_status.essOK THEN
         RETURN res;
      END;

      // TUNNELING_REQUEST_TIME_OUT is counted twice, because send is tried twice; the coefficient 2.5 stands for
      // safety. And more, ACK timeout should never appear if connection and physical layer is correct.
      SUPER.SetTimeout( eib_stack.tidL_ACKTimeout, 25 * core.TUNNELING_REQUEST_TIME_OUT DIV 10, 0 );
      SUPER.SetTimeout( eib_stack.tidL_BUSYDelay, 25 * core.TUNNELING_REQUEST_TIME_OUT DIV 10, 0 );

      RETURN eib_status.essOK;
   END Initialize;

(*--------------------------------------------------------------------------------*)

   INTERNAL VIRTUAL PROCEDURE ConnectBUS() : eib_status.TEIBStackStatus;
   BEGIN
      IF TPEIBNetPhysicalLayer( Layers[ eib_stack.eltPhysical ] )^.Connect() IN Sync.arsStarts THEN
         RETURN eib_status.essOK;
      ELSE
         RETURN eib_status.essConnectError;
      END;
   END ConnectBUS;

(*--------------------------------------------------------------------------------*)

   INTERNAL VIRTUAL PROCEDURE DisconnectBUS() : eib_status.TEIBStackStatus;
   BEGIN
      IF TPEIBNetPhysicalLayer( Layers[ eib_stack.eltPhysical ] )^.Disconnect() IN Sync.arsStarts THEN
         RETURN eib_status.essOK;
      ELSE
         RETURN eib_status.essConnectError;
      END;
   END DisconnectBUS;

(*--------------------------------------------------------------------------------*)

  INTERNAL VIRTUAL PROCEDURE CreateLayer( Layer : eib_stack.TEIBStackLayerType; VAR PLayer : eib_stack.TPEIBStackLayer ) : BOOLEAN;
  BEGIN
    IF Layer = eib_stack.eltPhysical THEN
      NEW( TPEIBNetPhysicalLayer( PLayer ));
      RETURN TRUE;
    ELSE
      RETURN FALSE;
    END;
  END CreateLayer;

(*--------------------------------------------------------------------------------*)

   INTERNAL VIRTUAL PROCEDURE ParseParameter( CONST Parameter, Value : ARRAY OF WCHAR; OUT ErrorText : ARRAY OF WCHAR ) : TRISTATE; // -1 means unknown/unprocessed
   VAR
      Addr : inetaddr.INETADDR;
   BEGIN
      IF EQUALS( Parameter, L"link.mode" ) THEN
         IF EQUALS( Value, L"routing" ) THEN
            TPEIBNetPhysicalLayer( Layers[ eib_stack.eltPhysical ] )^.Mode := eibnet.cmRouting;
         ELSIF EQUALS( Value, L"tunneling" ) THEN
            TPEIBNetPhysicalLayer( Layers[ eib_stack.eltPhysical ] )^.Mode := eibnet.cmTunnelingHPAI;
         ELSIF EQUALS( Value, L"tunneling-NAT" ) THEN
            TPEIBNetPhysicalLayer( Layers[ eib_stack.eltPhysical ] )^.Mode := eibnet.cmTunnelingBlind;
         ELSE
            ErrorText := L"Expected routing | tunneling | tunneling-NAT ";
            RETURN 0;
         END;

      ELSIF EQUALS( Parameter, L"link.connection" ) THEN
         ErrorText := L"Expected DNS name | IP address optionally followed by colon and port number (like 10.0.0.1:3778)";
         IF NOT dns.NameToAddressWait( Value, core.EIBNET_IPPORT, 2000, OUT OA( 0, ADR( Addr ))) THEN
            RETURN 0;
         END;
         TPEIBNetPhysicalLayer( Layers[ eib_stack.eltPhysical ] )^.RemoteAddress := Addr;
         
      ELSE
         RETURN -1;
      END;
      RETURN 1;
   END ParseParameter;

(*--------------------------------------------------------------------------------*)

  PUBLIC VIRTUAL PROCEDURE DeviceConnected() : BOOLEAN;
  BEGIN
    RETURN TPEIBNetPhysicalLayer( Layers[ eib_stack.eltPhysical ] )^.Connected();
  END DeviceConnected;

(*--------------------------------------------------------------------------------*)

  PUBLIC VIRTUAL PROCEDURE EIBConnected() : BOOLEAN;
  BEGIN
    RETURN DeviceConnected();
  END EIBConnected;

(*--------------------------------------------------------------------------------*)

BEGIN
END CEIBNetStack;

(*================================================================================*)

END EIBNetStack.