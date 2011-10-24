IMPLEMENTATION MODULE inetaddr;

IMPORT
   winsock;

FROM Debug IMPORT
   Assertion, LogAssertionW;

FROM Storage IMPORT
   Move;

IMPORT
   avltree,
   collection,
   Strings,
   WS2TcpIp;

(*================================================================================*)

CONST
   EMPTY_AI = WS2TcpIp.addrinfo( 0, 0, 0, 0, 0, NIL, NIL,NIL );
   
(*--------------------------------------------------------------------------------*)

INLINE PROCEDURE IN_ADDR4( CONST ai : INETADDR ) : winsock.Pin_addr;
BEGIN
   IF ai.V6 THEN
      RETURN NIL;
   ELSE
      RETURN ADR( winsock.Psockaddr_in( ai.Data )^.sin_addr );
   END;
END IN_ADDR4;

(*--------------------------------------------------------------------------------*)

INLINE PROCEDURE IN_ADDR6( CONST ai : INETADDR ) : WS2TcpIp.Pin_addr6;
BEGIN
   IF ai.V6 THEN
      RETURN ADR( WS2TcpIp.Psockaddr_in6( ai.Data )^.sin6_addr );
   ELSE
      RETURN NIL;
   END;
END IN_ADDR6;

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

   PUBLIC PROPERTY Empty GET : BOOLEAN;
   VAR
      i : CARDINAL;
      PV6 : WS2TcpIp.Pin_addr6;
   BEGIN
      IF V6 THEN
         PV6 := IN_ADDR6( SELF );
         FOR i := 0 TO HIGH( PV6^.Byte ) DO
            IF PBYTE( PV6@[i] )^ <> 0 THEN
               RETURN FALSE;
            END;
         END; // FOR
         RETURN TRUE;
      ELSE
         RETURN IN_ADDR4( SELF )^.s_addr = 0;
      END;
   END Empty;

(*--------------------------------------------------------------------------------*)

   PUBLIC PROPERTY Loopback GET : BOOLEAN;
   BEGIN
      IF V6 THEN
         RETURN WS2TcpIp.IN6_IS_ADDR_LOOPBACK( IN_ADDR6( SELF ));
      ELSE
         RETURN REVERSE( IN_ADDR4( SELF )^.s_addr ) = winsock.INADDR_LOOPBACK;
      END;
   END Loopback;

(*--------------------------------------------------------------------------------*)

   PUBLIC PROPERTY Broadcast GET : BOOLEAN;
   BEGIN
      IF V6 THEN
         RETURN FALSE;
      ELSE
         RETURN IN_ADDR4( SELF )^.s_addr = winsock.INADDR_BROADCAST;
      END;
   END Broadcast;

(*--------------------------------------------------------------------------------*)

   PUBLIC PROPERTY Multicast GET : BOOLEAN;
   BEGIN
      IF V6 THEN
         RETURN WS2TcpIp.IN6_IS_ADDR_MULTICAST( IN_ADDR6( SELF ));
      ELSE
         RETURN winsock.IN_MULTICAST( REVERSE( IN_ADDR4( SELF )^.s_addr ));
      END;
   END Multicast;

(*--------------------------------------------------------------------------------*)

   PUBLIC PROPERTY Scope GET : TScope;
   BEGIN
      IF Loopback THEN
         RETURN scoLoopback;
      ELSIF V6 THEN
         IF WS2TcpIp.IN6_IS_ADDR_LINKLOCAL( IN_ADDR6( SELF )) THEN
            RETURN scoLocalLink;
         ELSIF WS2TcpIp.IN6_IS_ADDR_SITELOCAL( IN_ADDR6( SELF )) THEN
            RETURN scoLocalSite;
         ELSE
            RETURN scoGlobal;
         END;
      ELSE
         RETURN scoGlobal;
      END;
   END Scope;

(*--------------------------------------------------------------------------------*)

   LOCAL PROPERTY Data GET : POINTER TO TRFC2553;
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

   PUBLIC OPERATOR =( CONST Operand : INETADDR ) : BOOLEAN;
   VAR
      a : ADDRESS := Operand.Data;
      i : CARDINAL;
      l : CARDINAL := Length;
   BEGIN
      IF l <> Operand.Length THEN
         RETURN FALSE;
      ELSIF l = 0 THEN
         RETURN TRUE;
      END;
      
      FOR i := 0 TO l-1 DO
         IF storage[i] <> PBYTE( a@[i] )^ THEN
            RETURN FALSE;
         END;
      END;
      
      RETURN TRUE;
   END =;

(*--------------------------------------------------------------------------------*)

   PUBLIC OPERATOR <>( CONST Operand : INETADDR ) : BOOLEAN;
   BEGIN
      RETURN NOT( SELF = Operand );
   END <>;

(*--------------------------------------------------------------------------------*)

   PUBLIC PROCEDURE ToOA( IncludePort : BOOLEAN; OUT Address : ARRAY OF WCHAR ); // numerical form in string
   VAR
      buffer : ARRAY [0..511] OF CHAR;
      result : CARDINAL;
      server : ARRAY [0..15] OF CHAR;
      serverU : ARRAY [0..15] OF WCHAR;
      v6 : BOOLEAN := V6;
   BEGIN
      result := WS2TcpIp.getnameinfo(
         winsock.Psockaddr( ADR( storage )), Length,
         OUT buffer, SIZE( buffer ),
         OUT server, SIZE( server ),
         WS2TcpIp.NI_NUMERICHOST OR WS2TcpIp.NI_NUMERICSERV
      );
      IF result <> 0 THEN
         Address := L"";
         ASSERTLOG( FALSE );
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
   END ToOA;

(*--------------------------------------------------------------------------------*)

   PUBLIC PROCEDURE FromOA( CONST Address : ARRAY OF WCHAR; DefaultPort : CARDINAL ) : BOOLEAN; // numerical form in string, FQDN will be refused, INETADDR class does not perform DNS operations
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
         IF ai^.ai_addrlen > SIZE( storage ) THEN
            ASSERTLOG( FALSE );
            RETURN FALSE;
         END;
         Move( ai^.ai_addr, ADR( storage ), ai^.ai_addrlen );
         IF serviceA[0] = 0C THEN
            Port := DefaultPort;
         END;
      END;

      WS2TcpIp.freeaddrinfo( ai );
      RETURN TRUE;
   END FromOA;
   
(*--------------------------------------------------------------------------------*)

   PUBLIC PROCEDURE Clear();
   VAR
      i : CARDINAL;
      v6 : BOOLEAN := V6;
   BEGIN
      FOR i := 0 TO HIGH( storage ) DO
         storage[i] := 0;
      END;
      V6 := v6;
   END Clear;

(*--------------------------------------------------------------------------------*)

   PUBLIC PROCEDURE SetV4( What : TSpecialAddress );
   BEGIN
      CASE What OF
      | saEmpty :
         FromOA( L"0.0.0.0", 0 );
      | saLoopback :
         FromOA( L"127.0.0.1", 0 );
      | saLocalLink :
         FromOA( L"127.0.0.1", 0 );
      | saLocalLinkRandom :
         FromOA( L"127.0.0.1", 0 );
      | saPrivateRandom :
         ASSERTLOG( FALSE );
      END; // CASE      
   END SetV4;

(*--------------------------------------------------------------------------------*)

   PUBLIC PROCEDURE SetV6( What : TSpecialAddress );
   BEGIN
      CASE What OF
      | saEmpty :
         FromOA( L"[::]", 0 );
      | saLoopback :
         FromOA( L"[::1]", 0 );
      | saLocalLink :
         FromOA( L"[fe80::1]", 0 );
      | saLocalLinkRandom :
         FromOA( L"[fe80::abcd:abcd]", 0 );
      | saPrivateRandom :
         FromOA( L"[fc00::1]", 0 );
      END; // CASE      
   END SetV6;

(*--------------------------------------------------------------------------------*)

   PUBLIC PROCEDURE FromV4( CONST IPAddr : ARRAY OF BYTE ); // IN_ADDR, network order
   BEGIN
      IF HIGH( IPAddr ) < SIZE( winsock.in_addr ) - 1 THEN
         SetV4( saEmpty );
      ELSE
         V6 := FALSE;
         Move( ADR( IPAddr ), IN_ADDR4( SELF ), SIZE( winsock.in_addr ));
      END;
   END FromV4;

(*--------------------------------------------------------------------------------*)

   PUBLIC PROCEDURE FromV6( CONST IPAddr : ARRAY OF BYTE ); // IN_ADDR6
   BEGIN
      IF HIGH( IPAddr ) < SIZE( WS2TcpIp.in_addr6 ) - 1 THEN
         SetV6( saEmpty );
      ELSE
         V6 := TRUE;
         Move( ADR( IPAddr ), IN_ADDR6( SELF ), SIZE( WS2TcpIp.in_addr6 ));
      END;
   END FromV6;

(*--------------------------------------------------------------------------------*)

   PUBLIC PROCEDURE FromBOA( CONST storage : ARRAY OF BYTE );
   VAR
      i : CARDINAL;
   BEGIN
      IF HIGH( storage ) = -1 THEN
         RETURN;
      END;
      FOR i := 0 TO MIN2( HIGH( SELF.storage ), HIGH( storage )) DO
         SELF.storage[i] := storage[i];
      END;
   END FromBOA;

(*--------------------------------------------------------------------------------*)

   PUBLIC PROCEDURE FromM( CONST storage : PBYTE ); // e.g. SOCKADDR_IN, SOCKADDR_IN6, length is determined by sa_family member
   VAR
      high : INTEGER;
   BEGIN
      IF PCARD16( storage )^ = winsock.AF_INET THEN
         high := SIZE( winsock.sockaddr_in )-1;
      ELSE
         high := SIZE( WS2TcpIp.sockaddr_in6 )-1;
      END;
      FromBOA( OA( high, storage ));
   END FromM;

(*--------------------------------------------------------------------------------*)

   PUBLIC PROCEDURE ToV4( OUT IPAddr : ARRAY OF BYTE ) : BOOLEAN; // IN_ADDR, 4 bytes
   BEGIN
      IF V6 THEN
         RETURN FALSE;
      ELSIF HIGH( IPAddr ) < SIZE( winsock.in_addr ) - 1 THEN
         RETURN FALSE;
      ELSE
         Move( IN_ADDR4( SELF ), ADR( IPAddr ), SIZE( winsock.in_addr ));
         RETURN TRUE;
      END;
   END ToV4;

(*--------------------------------------------------------------------------------*)

   PUBLIC PROCEDURE ToV6( OUT IPAddr : ARRAY OF BYTE ) : BOOLEAN; // IN_ADDR6, 16 bytes
   BEGIN
      IF NOT V6 THEN
         RETURN FALSE;
      ELSIF HIGH( IPAddr ) < SIZE( WS2TcpIp.in_addr6 ) - 1 THEN
         RETURN FALSE;
      ELSE
         Move( IN_ADDR6( SELF ), ADR( IPAddr ), SIZE( WS2TcpIp.in_addr6 ));
         RETURN TRUE;
      END;
   END ToV6;

(*--------------------------------------------------------------------------------*)

   PUBLIC PROCEDURE ToAddressBOA( OUT IPAddr : ARRAY OF BYTE; OUT filled : CARDINAL ) : BOOLEAN; // returns only address bytes, ignoring V4, V6 differences
   BEGIN
      IF V6 AND ToV6( OUT IPAddr ) THEN
         filled := SIZE( WS2TcpIp.in_addr6 );
         RETURN TRUE;
      ELSIF NOT V6 AND ToV4( OUT IPAddr ) THEN
         filled := SIZE( winsock.in_addr );
         RETURN TRUE;
      ELSE
         filled := 0;
         RETURN FALSE;
      END;
   END ToAddressBOA;

(*--------------------------------------------------------------------------------*)

   PUBLIC PROCEDURE ToBOA( OUT storage : ARRAY OF BYTE; OUT Length : CARDINAL ) : BOOLEAN;
   VAR
      i : CARDINAL;
      l : CARDINAL := SELF.Length;
   BEGIN
      IF HIGH( storage )+1 < l THEN
         RETURN FALSE;
      ELSE
         Length := l;
      END;
      FOR i := 0 TO l-1 DO
         storage[i] := SELF.storage[i];
      END;
      RETURN TRUE;
   END ToBOA;

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
      Strings.TrimW( REF Host );

      i := Strings.IndexOfCharW( HostWithService, L":", i );
      GOTO CheckPort;
   END;

   // try to find port
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

TYPE
  TPINETADDRPtrItem = POINTER TO CINETADDRPtrItem;

CLASS CINETADDRPtrItem( maps.CValueItem );

  LOCAL VAR
    Key  : INETADDR;

  PUBLIC VIRTUAL PROCEDURE Compare( i : CARDINAL; pelem : avltree.TPAVLTreeKey ) : TRISTATE;

END CINETADDRPtrItem;

(*--------------------------------------------------------------------------------*)

CLASS IMPLEMENTATION CINETADDRPtrItem;

   PUBLIC VIRTUAL PROCEDURE Compare( i : CARDINAL; pelem : avltree.TPAVLTreeKey ) : TRISTATE;
   VAR
      a1, a2 : ADDRESS;
      l1, l2 : CARDINAL;
   BEGIN
      l1 := Key.Length;
      l2 := TPINETADDRPtrItem( pelem )^.Key.Length;
      IF l1 < l2 THEN
         RETURN -1;
      ELSIF l1 > l2 THEN
         RETURN 1;
      ELSIF l1 = 0 THEN
         RETURN -1;
      END;
      a1 := Key.Data;
      a2 := TPINETADDRPtrItem( pelem )^.Key.Data;
      FOR i := 0 TO l1-1 DO
         IF PBYTE( a1@[i] )^ < PBYTE( a2@[i] )^ THEN
            RETURN -1;
         ELSIF PBYTE( a1@[i] )^ > PBYTE( a2@[i] )^ THEN
            RETURN 1;
         END;
      END;
      RETURN 0;
   END Compare;

END CINETADDRPtrItem;

(*--------------------------------------------------------------------------------*)

CLASS IMPLEMENTATION CINETADDRPtrMap;

(*--------------------------------------------------------------------------------*)

   PUBLIC READONLY INDEX CINETADDRPtrMap GET( Index : CARDINAL ) : PTR;
   VAR
      PI : TPINETADDRPtrItem;
   BEGIN
      IF SUPER.ElementAt( 0, Index, OUT PI ) THEN
         RETURN PI^.Value;
      ELSE
         RETURN NIL;
      END;
   END CINETADDRPtrMap;

(*--------------------------------------------------------------------------------*)

   PUBLIC PROCEDURE CINETADDRPtrMap.Add( CONST Key : INETADDR; Value, Data : PTR );
   VAR
      PI : TPINETADDRPtrItem;
   BEGIN
      NEW( PI );
      PI^.Key := Key;
      PI^.Value := Value;
      PI^.Data := Data;
      SUPER.Add( PI );
   END CINETADDRPtrMap.Add;
  
(*--------------------------------------------------------------------------------*)

   PUBLIC PROCEDURE CINETADDRPtrMap.Remove( CONST Key : INETADDR );
   VAR
      I : CINETADDRPtrItem;
   BEGIN
      I.Key := Key;
      Delete( 0, ADR( I ));
   END CINETADDRPtrMap.Remove;

(*--------------------------------------------------------------------------------*)

   PUBLIC PROCEDURE CINETADDRPtrMap.Contains( CONST Key : INETADDR ) : BOOLEAN;
   VAR
      I : CINETADDRPtrItem;
   BEGIN
      I.Key := Key;
      RETURN SUPER.Contains( 0, ADR( I ));
   END CINETADDRPtrMap.Contains;

(*--------------------------------------------------------------------------------*)

   PUBLIC PROCEDURE CINETADDRPtrMap.Get( CONST Key : INETADDR; OUT Value : PTR; OUT Data : PTR ) : BOOLEAN; // similar as []
   VAR
      I : CINETADDRPtrItem;
      PI : TPINETADDRPtrItem;
   BEGIN
      I.Key := Key;
      IF NOT SUPER.Get( 0, ADR( I ), OUT PI ) THEN
         RETURN FALSE;
      END;
      Value := PI^.Value;
      Data := PI^.Data;
      RETURN TRUE;  
   END CINETADDRPtrMap.Get;

(*--------------------------------------------------------------------------------*)

   PUBLIC PROCEDURE CINETADDRPtrMap.ElementAt( Index : CARDINAL; OUT Key : INETADDR; OUT Value : PTR; OUT Data : PTR ) : BOOLEAN;
   VAR
      PI : TPINETADDRPtrItem;
   BEGIN
      IF SUPER.ElementAt( 0, Index, OUT PI ) THEN
         Key := PI^.Key;
         Value := PI^.Value;
         Data := PI^.Data;
         RETURN TRUE;
      ELSE
         RETURN FALSE;
      END;
  END CINETADDRPtrMap.ElementAt;

(*--------------------------------------------------------------------------------*)

   PUBLIC PROCEDURE CINETADDRPtrMap.GetIterator() : TPINETADDRPtrMapIterator;
   VAR
      iterator : TPINETADDRPtrMapIterator := NEW( CINETADDRPtrMapIterator );
   BEGIN
      iterator^.Init( SELF, collection.dirForward );
      RETURN iterator;
   END CINETADDRPtrMap.GetIterator;

(*--------------------------------------------------------------------------------*)

END CINETADDRPtrMap;

(*================================================================================*)

CLASS IMPLEMENTATION CINETADDRPtrMapIterator;

(*--------------------------------------------------------------------------------*)

   PUBLIC PROPERTY Key GET : TPINETADDR;
   BEGIN
      IF Current = NIL THEN
         RETURN NIL;
      ELSE
         RETURN ADR( TPINETADDRPtrItem( Current )^.Key );
      END;
   END Key;

(*--------------------------------------------------------------------------------*)

   PUBLIC PROPERTY Value GET : PTR;
   BEGIN
      IF Current = NIL THEN
         RETURN NIL;
      ELSE
         RETURN TPINETADDRPtrItem( Current )^.Value;
      END;
   END Value;

(*--------------------------------------------------------------------------------*)

   PUBLIC PROPERTY Value SET( value : PTR );
   BEGIN
      IF Current <> NIL THEN
         TPINETADDRPtrItem( Current )^.Value := value;
      END;
   END Value;

(*--------------------------------------------------------------------------------*)

   PUBLIC PROPERTY Data GET : PTR;
   BEGIN
      IF Current = NIL THEN
         RETURN NIL;
      ELSE
         RETURN TPINETADDRPtrItem( Current )^.Data;
      END;
   END Data;

(*--------------------------------------------------------------------------------*)

   PUBLIC PROPERTY Data SET( Value : PTR );
   BEGIN
      IF Current <> NIL THEN
         TPINETADDRPtrItem( Current )^.Data := Value;
      END;
   END Data;

(*--------------------------------------------------------------------------------*)

END CINETADDRPtrMapIterator;

(*================================================================================*)

END inetaddr.