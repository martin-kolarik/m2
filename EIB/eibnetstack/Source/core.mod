IMPLEMENTATION MODULE core;

(*================================================================================*)

CLASS IMPLEMENTATION V1Header;
BEGIN
END V1Header;

(*================================================================================*)

CLASS IMPLEMENTATION HostProtocolAddressInformation;

(*--------------------------------------------------------------------------------*)

   PUBLIC PROPERTY Address GET : winsock.IN_ADDR;
   BEGIN
      RETURN _IPAddress;
   END Address;

(*--------------------------------------------------------------------------------*)

   PUBLIC PROPERTY Address SET( CONST Value : winsock.IN_ADDR );
   BEGIN
      _IPAddress := Value;
   END Address;

(*--------------------------------------------------------------------------------*)

   PUBLIC PROPERTY Port GET : CARDINAL;
   BEGIN
      RETURN CARDINAL( REVERSE( _Port ));
   END Port;

(*--------------------------------------------------------------------------------*)

   PUBLIC PROPERTY Port SET( Value : CARDINAL );
   BEGIN
      _Port := REVERSE( CARD16( Value ));
   END Port;

(*--------------------------------------------------------------------------------*)

BEGIN
   _IPAddress.s_addr := 0;
END HostProtocolAddressInformation;

(*================================================================================*)

CLASS IMPLEMENTATION Packet;

(*--------------------------------------------------------------------------------*)

   PUBLIC PROPERTY Length GET : CARDINAL;
   BEGIN
      RETURN CARDINAL( REVERSE( _HDR._PktLength ));
   END Length;

(*--------------------------------------------------------------------------------*)

   PUBLIC PROPERTY Length SET( Value : CARDINAL );
   BEGIN
      _HDR._PktLength := REVERSE( CARD16( Value ));
   END Length;

(*--------------------------------------------------------------------------------*)

   PUBLIC PROPERTY Service GET : TService;
   BEGIN
      RETURN TService( REVERSE( _HDR._Service ));
   END Service;

(*--------------------------------------------------------------------------------*)

   PUBLIC PROPERTY Service SET( Value : TService );
   BEGIN
      _HDR._Service := TService( REVERSE( Value ));
   END Service;

(*--------------------------------------------------------------------------------*)

BEGIN
END Packet;

(*================================================================================*)

CLASS IMPLEMENTATION HPAIPacket;

(*--------------------------------------------------------------------------------*)

   PUBLIC PROPERTY HPAI GET : HostProtocolAddressInformation;
   BEGIN
      RETURN _HPAI;
   END HPAI;
   
(*--------------------------------------------------------------------------------*)

   PUBLIC PROPERTY HPAI SET( CONST Value : HostProtocolAddressInformation );
   BEGIN
      _HPAI := Value;
   END HPAI;

(*--------------------------------------------------------------------------------*)

   PUBLIC PROPERTY Address GET : winsock.IN_ADDR;
   BEGIN
      RETURN _HPAI.Address;
   END Address;

(*--------------------------------------------------------------------------------*)

   PUBLIC PROPERTY Address SET( CONST Value : winsock.IN_ADDR );
   BEGIN
      _HPAI.Address := Value;
   END Address;

(*--------------------------------------------------------------------------------*)

   PUBLIC PROPERTY Port GET : CARDINAL;
   BEGIN
      RETURN _HPAI.Port;
   END Port;

(*--------------------------------------------------------------------------------*)

   PUBLIC PROPERTY Port SET( Value : CARDINAL );
   BEGIN
      _HPAI.Port := Value;
   END Port;

(*--------------------------------------------------------------------------------*)

BEGIN
END HPAIPacket;

(*================================================================================*)

CLASS IMPLEMENTATION SearchRequest;
BEGIN
   Service := SEARCH_REQUEST;
   Length := HEADER_SIZE_10 + SIZE( _HPAI );
END SearchRequest;

(*================================================================================*)

CLASS IMPLEMENTATION SearchResponse;

(*--------------------------------------------------------------------------------*)

   PUBLIC PROPERTY Valid GET : BOOLEAN;
   BEGIN
      RETURN ( Service = SEARCH_RESPONSE ) AND ( Length = HEADER_SIZE_10 + SIZE( _HPAI ) + SIZE( _DIB ) + _SF.DIBLength );
   END Valid;

(*--------------------------------------------------------------------------------*)

   PUBLIC PROPERTY SupportedFamilies GET : TServiceFamilies;
   VAR
      i, items : CARDINAL;
      sf : TServiceFamilies := TServiceFamilies{};
   BEGIN
      IF _SF.DIBLength = 0 THEN
         RETURN TServiceFamilies{};
      END;
      items := CARDINAL( _SF.DIBLength ) - FIELDOFS( DIBServiceFamilies.Families );
      items := items DIV SIZE( _SF.Families[0] );
      FOR i := 0 TO items - 1 DO
         INCL( sf, _SF.Families[i].Family );
      END;
      RETURN sf;
   END SupportedFamilies;
   
(*--------------------------------------------------------------------------------*)

   PUBLIC PROPERTY Name GET : StringsO.CString;
   VAR
      s : StringsO.CString;
   BEGIN
      s.FromOAA( 0, _DIB.Name );
      RETURN s;
   END Name;

(*--------------------------------------------------------------------------------*)

   PUBLIC PROPERTY MAC GET : StringsO.CString;
   VAR
      i : CARDINAL;
      n : StringsO.CString;
      s : StringsO.CString;
   BEGIN
      FOR i := 0 TO HIGH( _DIB.MAC ) DO
         n.FromCARD32( CARDINAL( _DIB.MAC[i] ), 16 );
         IF n.Length = 1 THEN
            s.AppendOA( L"0" );
         END;
         s.Append( n );
         s.AppendOA( L"-" );
      END; // FOR
      RETURN s;
   END MAC;

(*--------------------------------------------------------------------------------*)

   PUBLIC PROPERTY PhysicalAddress GET : eib_def.TAddress;
   VAR
      Address : eib_def.TAddress;
   BEGIN
      Address.SetAddressType( eib_def.addressPhysical );
      Address.SetPacketAddress( _DIB.PhysicalAddress );
      RETURN Address;
   END PhysicalAddress;

(*--------------------------------------------------------------------------------*)

   PUBLIC PROPERTY RoutingAddress GET : winsock.IN_ADDR;
   BEGIN
      RETURN _DIB.RoutingAddress;
   END RoutingAddress;

(*--------------------------------------------------------------------------------*)

BEGIN
   _DIB.DIBLength := 0;
END SearchResponse;

(*================================================================================*)

CLASS IMPLEMENTATION DescriptionRequest;
BEGIN
   Service := DESCRIPTION_REQUEST;
   Length := HEADER_SIZE_10 + SIZE( _HPAI );
END DescriptionRequest;

(*================================================================================*)

CLASS IMPLEMENTATION DescriptionResponse;

(*--------------------------------------------------------------------------------*)

   PUBLIC PROPERTY Valid GET : BOOLEAN;
   BEGIN
      RETURN ( Service = DESCRIPTION_RESPONSE ) AND ( Length >= HEADER_SIZE_10 + SIZE( _DIB ) + _SF.DIBLength );
   END Valid;

(*--------------------------------------------------------------------------------*)

   PUBLIC PROPERTY SupportedFamilies GET : TServiceFamilies;
   VAR
      i, items : CARDINAL;
      sf : TServiceFamilies := TServiceFamilies{};
   BEGIN
      IF _DIB.DIBLength = 0 THEN
         RETURN TServiceFamilies{};
      END;
      items := CARDINAL( _DIB.DIBLength ) - FIELDOFS( DIBServiceFamilies.Families );
      items := items DIV SIZE( _SF.Families[0] );
      FOR i := 0 TO items - 1 DO
         INCL( sf, _SF.Families[i].Family );
      END;
      RETURN sf;
   END SupportedFamilies;
   
(*--------------------------------------------------------------------------------*)

   PUBLIC PROPERTY Name GET : StringsO.CString;
   VAR
      s : StringsO.CString;
   BEGIN
      s.FromOAA( 0, _DIB.Name );
      RETURN s;
   END Name;

(*--------------------------------------------------------------------------------*)

   PUBLIC PROPERTY MAC GET : StringsO.CString;
   VAR
      i : CARDINAL;
      n : StringsO.CString;
      s : StringsO.CString;
   BEGIN
      FOR i := 0 TO HIGH( _DIB.MAC ) DO
         n.FromCARD32( CARDINAL( _DIB.MAC[i] ), 16 );
         IF n.Length = 1 THEN
            s.AppendOA( L"0" );
         END;
         s.Append( n );
         s.AppendOA( L"-" );
      END; // FOR
      RETURN s;
   END MAC;

(*--------------------------------------------------------------------------------*)

   PUBLIC PROPERTY PhysicalAddress GET : eib_def.TAddress;
   VAR
      Address : eib_def.TAddress;
   BEGIN
      Address.SetAddressType( eib_def.addressPhysical );
      Address.SetPacketAddress( _DIB.PhysicalAddress );
      RETURN Address;
   END PhysicalAddress;

(*--------------------------------------------------------------------------------*)

   PUBLIC PROPERTY RoutingAddress GET : winsock.IN_ADDR;
   BEGIN
      RETURN _DIB.RoutingAddress;
   END RoutingAddress;

(*--------------------------------------------------------------------------------*)

   PUBLIC PROPERTY ManufacturerId GET : CARD16;
   BEGIN
      IF _MF = NIL THEN
         RETURN 0;
      ELSE
         RETURN REVERSE( _MF^.ManufacturerId );
      END;
   END ManufacturerId;

(*--------------------------------------------------------------------------------*)

BEGIN
   _DIB.DIBLength := 0;
   _MF := NIL;
END DescriptionResponse;

(*================================================================================*)

CLASS IMPLEMENTATION ConnectionPacket;

(*--------------------------------------------------------------------------------*)

   PUBLIC PROPERTY ChannelId GET : CARD8;
   BEGIN
      RETURN _ChannelId;
   END ChannelId;

(*--------------------------------------------------------------------------------*)

   PUBLIC PROPERTY ChannelId SET( Value : CARD8 );
   BEGIN
      _ChannelId := Value;
   END ChannelId;

(*--------------------------------------------------------------------------------*)

   PUBLIC PROPERTY Status GET : TStatus;
   BEGIN
      RETURN TStatus( _Data );
   END Status;

(*--------------------------------------------------------------------------------*)

BEGIN
END ConnectionPacket;

(*================================================================================*)

CLASS IMPLEMENTATION HPAIConnectionPacket;
BEGIN
END HPAIConnectionPacket;

(*================================================================================*)

CLASS IMPLEMENTATION CRI;
BEGIN
END CRI;

(*================================================================================*)

CLASS IMPLEMENTATION CRD;
BEGIN
END CRD;

(*================================================================================*)

CLASS IMPLEMENTATION ConnectRequest;

(*--------------------------------------------------------------------------------*)

   PUBLIC PROPERTY ControlHPAI SET( CONST Value : HostProtocolAddressInformation );
   BEGIN
      _HPAI := Value;
   END ControlHPAI;

(*--------------------------------------------------------------------------------*)

   PUBLIC PROPERTY DataHPAI SET( CONST Value : HostProtocolAddressInformation );
   BEGIN
      _DataHPAI := Value;
   END DataHPAI;

(*--------------------------------------------------------------------------------*)

BEGIN
   Service := CONNECT_REQUEST;
   Length := HEADER_SIZE_10 + SIZE( _HPAI ) + SIZE( _DataHPAI ) + SIZE( _CRI );
END ConnectRequest;
      
(*================================================================================*)

CLASS IMPLEMENTATION ConnectResponse;

(*--------------------------------------------------------------------------------*)

   PUBLIC PROPERTY Valid GET : BOOLEAN;
   VAR
      l : CARDINAL := Length;
   BEGIN
      RETURN ( Service = CONNECT_RESPONSE ) AND (( l = HEADER_SIZE_10 + 2 ) OR ( l = HEADER_SIZE_10 + 2 + SIZE( _HPAI ) + SIZE( _CRD )));
   END Valid;

(*--------------------------------------------------------------------------------*)

   PUBLIC PROPERTY DataHPAI GET : HostProtocolAddressInformation;
   BEGIN
      RETURN _HPAI;
   END DataHPAI;

(*--------------------------------------------------------------------------------*)

   PUBLIC PROPERTY PhysicalAddress GET : eib_def.TAddress;
   VAR
      Address : eib_def.TAddress;
   BEGIN
      Address.SetAddressType( eib_def.addressPhysical );
      Address.SetPacketAddress( _CRD._Address );
      RETURN Address;
   END PhysicalAddress;

(*--------------------------------------------------------------------------------*)

BEGIN
END ConnectResponse;

(*================================================================================*)

CLASS IMPLEMENTATION ConnectionStateRequest;

(*--------------------------------------------------------------------------------*)

   PUBLIC PROPERTY ControlHPAI SET( CONST Value : HostProtocolAddressInformation );
   BEGIN
      _HPAI := Value;
   END ControlHPAI;

(*--------------------------------------------------------------------------------*)

BEGIN
   Service := CONNECTIONSTATE_REQUEST;
   Length := HEADER_SIZE_10 + 2 + SIZE( _HPAI );
END ConnectionStateRequest;

(*================================================================================*)

CLASS IMPLEMENTATION ConnectionStateResponse;

(*--------------------------------------------------------------------------------*)

   PUBLIC PROPERTY Valid GET : BOOLEAN;
   BEGIN
      RETURN ( Service = CONNECTIONSTATE_RESPONSE ) AND ( Length = HEADER_SIZE_10 + 2 );
   END Valid;

(*--------------------------------------------------------------------------------*)

BEGIN
   Length := HEADER_SIZE_10 + 2;
END ConnectionStateResponse;

(*================================================================================*)

CLASS IMPLEMENTATION DisconnectRequest;

(*--------------------------------------------------------------------------------*)

   PUBLIC PROPERTY Valid GET : BOOLEAN;
   BEGIN
      RETURN ( Service = DISCONNECT_REQUEST ) AND ( Length = HEADER_SIZE_10 + 2 + SIZE( _HPAI ));
   END Valid;

(*--------------------------------------------------------------------------------*)

   PUBLIC PROPERTY ControlHPAI SET( CONST Value : HostProtocolAddressInformation );
   BEGIN
      _HPAI := Value;
   END ControlHPAI;

(*--------------------------------------------------------------------------------*)

BEGIN
   Service := DISCONNECT_REQUEST;
   Length := HEADER_SIZE_10 + 2 + SIZE( _HPAI );
END DisconnectRequest;

(*================================================================================*)

CLASS IMPLEMENTATION DisconnectResponse;

(*--------------------------------------------------------------------------------*)

   PUBLIC PROPERTY Valid GET : BOOLEAN;
   BEGIN
      RETURN ( Service = DISCONNECT_RESPONSE ) AND ( Length = HEADER_SIZE_10 + 2 );
   END Valid;

(*--------------------------------------------------------------------------------*)

BEGIN
   Length := HEADER_SIZE_10 + 2;
END DisconnectResponse;

(*================================================================================*)

CLASS IMPLEMENTATION ConnectionHeader;
BEGIN
   _ChannelId := 0;
END ConnectionHeader;

(*================================================================================*)

CLASS IMPLEMENTATION TunnelingPacket;

(*--------------------------------------------------------------------------------*)

   PUBLIC PROPERTY ChannelId GET : CARD8;
   BEGIN
      RETURN _CHDR._ChannelId;
   END ChannelId;

(*--------------------------------------------------------------------------------*)

   PUBLIC PROPERTY ChannelId SET( Value : CARD8 );
   BEGIN
      _CHDR._ChannelId := Value;
   END ChannelId;

(*--------------------------------------------------------------------------------*)

   PUBLIC PROPERTY Sequence GET : CARD8;
   BEGIN
      RETURN _CHDR._Sequence;
   END Sequence;

(*--------------------------------------------------------------------------------*)

   PUBLIC PROPERTY Sequence SET( Value : CARD8 );
   BEGIN
      _CHDR._Sequence := Value;
   END Sequence;

(*--------------------------------------------------------------------------------*)

BEGIN
END TunnelingPacket;

(*================================================================================*)

CLASS IMPLEMENTATION TunnelingRequest;

(*--------------------------------------------------------------------------------*)

   PUBLIC PROPERTY Valid GET : BOOLEAN;
   BEGIN
      RETURN ( Service = TUNNELING_REQUEST ) AND
             ( Length = HEADER_SIZE_10 + SIZE( _CHDR ) + _EMI.Length ) AND
             ( _CHDR._Length = SIZE( _CHDR ));
   END Valid;

(*--------------------------------------------------------------------------------*)

   PUBLIC PROPERTY EMI GET : eib_def.TPacket;
   VAR
      packet : eib_def.TPacket;
   BEGIN
      _EMI.ToEMI( OUT packet );
      RETURN packet;
   END EMI;

(*--------------------------------------------------------------------------------*)

   PUBLIC PROPERTY EMI SET( CONST Value : eib_def.TPacket );
   BEGIN
      _EMI.FromEMI( Value );
      Length := HEADER_SIZE_10 + SIZE( _CHDR ) + _EMI.Length;
   END EMI;

(*--------------------------------------------------------------------------------*)

BEGIN
   Service := TUNNELING_REQUEST;
END TunnelingRequest;

(*================================================================================*)

CLASS IMPLEMENTATION TunnelingACK;

(*--------------------------------------------------------------------------------*)

   PUBLIC PROPERTY Valid GET : BOOLEAN;
   BEGIN
      RETURN ( Service = TUNNELING_ACK ) AND
             ( Length = HEADER_SIZE_10 + SIZE( _CHDR )) AND
             ( _CHDR._Length = SIZE( _CHDR ));
   END Valid;

(*--------------------------------------------------------------------------------*)

   PUBLIC PROPERTY Success GET : BOOLEAN;
   BEGIN
      RETURN TStatus( _CHDR._Data ) = E_NO_ERROR;
   END Success;

(*--------------------------------------------------------------------------------*)

   PUBLIC PROPERTY Success SET( Value : BOOLEAN );
   BEGIN
      IF Value THEN
         _CHDR._Data := CARD8( E_NO_ERROR );
      ELSE
         _CHDR._Data := CARD8( 1 ); // ??? which error
      END;
   END Success;

(*--------------------------------------------------------------------------------*)

BEGIN
   Service := TUNNELING_ACK;
   Length := HEADER_SIZE_10 + SIZE( _CHDR );
END TunnelingACK;

(*================================================================================*)

CLASS IMPLEMENTATION RoutingIndication;

(*--------------------------------------------------------------------------------*)

   PUBLIC PROPERTY Valid GET : BOOLEAN;
   BEGIN
      RETURN ( Service = ROUTING_INDICATION ) AND ( Length = HEADER_SIZE_10 + _EMI.Length );
   END Valid;

(*--------------------------------------------------------------------------------*)

   PUBLIC PROPERTY EMI GET : eib_def.TPacket;
   VAR
      packet : eib_def.TPacket;
   BEGIN
      _EMI.ToEMI( OUT packet );
      RETURN packet;
   END EMI;

(*--------------------------------------------------------------------------------*)

   PUBLIC PROPERTY EMI SET( CONST Value : eib_def.TPacket );
   BEGIN
      _EMI.FromEMI( Value );
      Length := HEADER_SIZE_10 + _EMI.Length;
   END EMI;

(*--------------------------------------------------------------------------------*)

BEGIN
   Service := ROUTING_INDICATION;
END RoutingIndication;

(*================================================================================*)

CLASS IMPLEMENTATION RoutingLostMessage;

(*--------------------------------------------------------------------------------*)

   PUBLIC PROPERTY Valid GET : BOOLEAN;
   BEGIN
      RETURN ( Service = ROUTING_LOST_MESSAGE ) AND
             ( Length = HEADER_SIZE_10 + SIZE( _LMI )) AND
             ( _LMI._Length = SIZE( _LMI ));
   END Valid;

(*--------------------------------------------------------------------------------*)

   PUBLIC PROPERTY LostCount GET : CARDINAL;
   BEGIN
      RETURN CARDINAL( REVERSE( _LMI._Number ));
   END LostCount;
   
(*--------------------------------------------------------------------------------*)

BEGIN
   Service := ROUTING_LOST_MESSAGE;
   Length := HEADER_SIZE_10 + SIZE( _LMI );
END RoutingLostMessage;

(*================================================================================*)

END core.