IMPLEMENTATION MODULE dns;

(*===========================================================================*)

IMPORT
   winsock;

FROM Debug IMPORT
   Assertion;

FROM Storage IMPORT
   ALLOCATE, DEALLOCATE;
  
IMPORT
   Delegate,
   Exceptions,
   msghandler,
   netpool,
   netsrv,
   Storage,
   Strings,
   threadpool,
   winerror,
   WS2TcpIp;

(*===========================================================================*)

CONST
   EMPTY_AI = WS2TcpIp.addrinfo( 0, 0, 0, 0, 0, NIL, NIL,NIL );
   
(*--------------------------------------------------------------------------------*)

TYPE
   TPRequest = POINTER TO CRequest;
   TPNameToAddressRequest = POINTER TO CNameToAddressRequest;
   TPAddressToNameRequest = POINTER TO CAddressToNameRequest;
  
(*===========================================================================*)

CLASS CDispatcher IMPLEMENTS threadpool.IWorkerSink;
   LOCAL VIRTUAL PROCEDURE OnWorker( Result : Sync.TAsyncResult; PoolHandle : threadpool.TPoolHandle; UserId : PTR );
END CDispatcher;

(*---------------------------------------------------------------------------*)

ABSTRACT CLASS CRequest( threadpool.APoolWorker );
   LOCAL VAR
      Result : CARDINAL := winerror.ERROR_INVALID_PARAMETER;
      PNotifier : TPDNSNotifier := NIL;
      RequestId : PTR := 0;
END CRequest;

(*---------------------------------------------------------------------------*)

CLASS CNameToAddressRequest( CRequest );
   LOCAL VAR
      Name : StringsO.CString;
      DefaultPort : CARDINAL := 0;
      AddrInfo : WS2TcpIp.Paddrinfo := NIL;
   LOCAL VIRTUAL PROCEDURE Run();
END CNameToAddressRequest;

(*---------------------------------------------------------------------------*)

CLASS CAddressToNameRequest( CRequest );
   LOCAL VAR
      Address : inetaddr.INETADDR;
      IncludePort : BOOLEAN := FALSE;
      Name : StringsO.CString;
   LOCAL VIRTUAL PROCEDURE Run();
END CAddressToNameRequest;

(*---------------------------------------------------------------------------*)

VAR
   SinkDelegate : threadpool.CSinkDelegate;
   Dispatcher : CDispatcher;

(*===========================================================================*)

CLASS IMPLEMENTATION CDispatcher;

(*---------------------------------------------------------------------------*)
 
   LOCAL VIRTUAL PROCEDURE OnWorker( Result : Sync.TAsyncResult; PoolHandle : threadpool.TPoolHandle; UserId : PTR );
   VAR
      Addresses : POINTER TO ARRAY [0..0] OF inetaddr.INETADDR := NIL;
      ai : WS2TcpIp.Paddrinfo;
      count : CARDINAL;
      netResult : CARDINAL;
      Request : TPRequest := TPRequest( UserId );
   BEGIN
      IF ( Request <> NIL ) AND ( Request^.PNotifier <> NIL ) THEN
         CASE Result OF
         | Sync.arCannotStart :
            netResult := winsock.WSAENOBUFS;
         | Sync.arCompleted :
            netResult := Request^.Result;
         | Sync.arAborted :
            netResult := winerror.ERROR_OPERATION_ABORTED;
         | Sync.arTimeout :
            netResult := winsock.WSATRY_AGAIN;
         ELSE
            ASSERT( FALSE );
         END; // CASE

         IF Request^ IS CNameToAddressRequest THEN
            IF netResult <> 0 THEN
               Request^.PNotifier^.OnAddressFound( Request^.RequestId, netResult, OA( -1, inetaddr.TPINETADDR( NIL )));

            ELSIF ( TPNameToAddressRequest( Request )^.AddrInfo <> NIL ) AND
                  ( TPNameToAddressRequest( Request )^.AddrInfo^.ai_addr <> NIL ) THEN
               count := 0;
               ai := TPNameToAddressRequest( Request )^.AddrInfo;
               REPEAT
                  INC( count );
                  ai := ai^.ai_next;
               UNTIL ai = NIL;
               
               ALLOCATE( Addresses, count * SIZE( Addresses^ ));
               Storage.Zero( Addresses, count * SIZE( Addresses^ ));
               count := 0;
               ai := TPNameToAddressRequest( Request )^.AddrInfo;
               REPEAT
                  Addresses^[count].FromOA( OA( ai^.ai_addrlen-1, ai^.ai_addr ));
                  INC( count );
                  ai := ai^.ai_next;
               UNTIL ai = NIL;
               
               (*?*)
               // IF serviceA[0] = 0C THEN
               //    Port := DefaultPort;
               // END;

               Request^.PNotifier^.OnAddressFound( Request^.RequestId, 0, OA( count-1, Addresses ));
               
               DEALLOCATE( Addresses );
            END;

         ELSIF Request^ IS CAddressToNameRequest THEN
            Request^.PNotifier^.OnNameFound( Request^.RequestId, netResult, TPAddressToNameRequest( Request )^.Name );

         END;
      END; // IF have notifier
      
      IF Request <> NIL THEN
         Request^.Release();
      END;
   END OnWorker;

(*---------------------------------------------------------------------------*)

END CDispatcher;

(*===========================================================================*)

CLASS IMPLEMENTATION CRequest;
BEGIN
END CRequest;

(*===========================================================================*)

CLASS IMPLEMENTATION CNameToAddressRequest;

(*---------------------------------------------------------------------------*)

   LOCAL VIRTUAL PROCEDURE Run();
   VAR
      hostA : ARRAY [0..511] OF CHAR;
      hints : WS2TcpIp.addrinfo := EMPTY_AI;
      host : ARRAY [0..511] OF WCHAR;
      service : ARRAY [0..15] OF WCHAR;
      serviceA : ARRAY [0..15] OF CHAR;
   BEGIN
      IF inetaddr.SplitAddressOA( OA( Name.Length-1, Name.rawData ), OUT host, OUT service ) THEN
         Strings.ToA( host, 0, OUT hostA );
         Strings.ToA( service, 0, OUT serviceA );

      (*?*) // DefaultPort

         Result := WS2TcpIp.getaddrinfo( ADR( hostA ), ADR( serviceA ), ADR( hints ), OUT AddrInfo );
      END;
   END Run;

(*---------------------------------------------------------------------------*)

BEGIN
FINALLY
   IF AddrInfo <> NIL THEN
      WS2TcpIp.freeaddrinfo( AddrInfo );
      AddrInfo := NIL;
   END;
END CNameToAddressRequest;

(*===========================================================================*)

CLASS IMPLEMENTATION CAddressToNameRequest;

(*---------------------------------------------------------------------------*)

   LOCAL VIRTUAL PROCEDURE Run();
   VAR
      hostA : ARRAY [0..511] OF CHAR;
      service : ARRAY [0..15] OF WCHAR;
      serviceA : ARRAY [0..15] OF CHAR;
   BEGIN
      Result := WS2TcpIp.getnameinfo(
         winsock.Psockaddr( Address.Data ), Address.Length,
         OUT hostA, SIZE( hostA ),
         OUT serviceA, SIZE( serviceA ),
         WS2TcpIp.NI_NUMERICSERV
      );
      IF Result = 0 THEN
         Name.FromOAA( 0, hostA );
         IF Name.IndexOfOA( L":", 0 ) <> -1 THEN // numerical form
            Name.PrependOA( L"[" );
            Name.AppendOA( L"]" );
         END;
         IF IncludePort AND ( serviceA[0] <> 0C ) AND ( serviceA[0] <> C"0" ) THEN
            Name.AppendOA( L":" );
            Strings.ToW( serviceA, 0, OUT service );
            Name.AppendOA( service );
         END; 
      ELSE
         Result := winsock.WSAGetLastError();
      END;
   END Run;

(*---------------------------------------------------------------------------*)

BEGIN
END CAddressToNameRequest;

(*===========================================================================*)

CLASS IMPLEMENTATION ADNSNotifier;

(*---------------------------------------------------------------------------*)

  LOCAL VIRTUAL PROCEDURE OnAddressFound( RequestId : PTR; Result : CARDINAL; CONST Address : ARRAY OF inetaddr.INETADDR );
  BEGIN
  END OnAddressFound;

(*---------------------------------------------------------------------------*)

  LOCAL VIRTUAL PROCEDURE OnNameFound( RequestId : PTR; Result : CARDINAL; CONST Name : StringsO.CString );
  BEGIN
  END OnNameFound;

(*---------------------------------------------------------------------------*)

END ADNSNotifier;

(*===========================================================================*)

PROCEDURE KillPending( REF Handle : PTR );
BEGIN
  netpool.pool()^.Abort( REF Handle );
END KillPending;

(*---------------------------------------------------------------------------*)

PROCEDURE KillAllPending( PNotifier : TPDNSNotifier );
BEGIN
  netpool.pool()^.AbortAll( PNotifier );
END KillAllPending;

(*===========================================================================*)

PROCEDURE NameToAddress( PNotifier : TPDNSNotifier; RequestId : PTR; CONST Name : ARRAY OF WCHAR; DefaultPort : CARDINAL; OUT Handle : threadpool.TPoolHandle ) : BOOLEAN;
VAR
   Address : inetaddr.INETADDR;
   Request : TPNameToAddressRequest;
BEGIN
   IF Address.SetAddressOA( Name, DefaultPort ) THEN
      IF PNotifier <> NIL THEN
         PNotifier^.OnAddressFound( RequestId, 0, OA( 0, ADR( Address )) );
      END;
      RETURN TRUE;
   END;

   SinkDelegate.WorkerSink := ADR( Dispatcher );
   PNotifier^.AddRef();

   NEW( Request );
   Request^.PNotifier := PNotifier;
   Request^.RequestId := RequestId;
   Request^.Name.FromOA( Name );
   Request^.DefaultPort := DefaultPort;
 
   IF netpool.pool()^.RunWorker( ADR( SinkDelegate ), Request, FALSE, Request, FALSE, OUT Handle ) THEN
      RETURN TRUE;
   ELSE
      Request^.Release();
      RETURN FALSE;
   END;
END NameToAddress;

(*---------------------------------------------------------------------------*)

PROCEDURE AddressToName( PNotifier : TPDNSNotifier; RequestId : PTR; CONST Address : inetaddr.INETADDR; IncludePort : BOOLEAN; OUT Handle : threadpool.TPoolHandle ) : BOOLEAN;
VAR
   Request : TPAddressToNameRequest;
BEGIN
   SinkDelegate.WorkerSink := ADR( Dispatcher );
   PNotifier^.AddRef();

   NEW( Request );
   Request^.PNotifier := PNotifier;
   Request^.RequestId := RequestId;
   Request^.Address := Address;
   Request^.IncludePort := IncludePort;

   IF netpool.pool()^.RunWorker( ADR( SinkDelegate ), Request, FALSE, Request, FALSE, OUT Handle ) THEN
      RETURN TRUE;
   ELSE
      Request^.Release();
      RETURN FALSE;
   END;
END AddressToName;

(*===========================================================================*)

CLASS CLocalDNSNotifier( ADNSNotifier );
  LOCAL VAR
    Addresses : POINTER TO ARRAY [0..0] OF inetaddr.INETADDR := NIL;
    AddressesHigh : CARDINAL := 0;
    Name : PWCHAR := NIL;
    NameHigh : CARDINAL := 0;
    Result : Sync.TAsyncResult := Sync.arCompleted;
    Signal : Sync.SIGNAL;
  LOCAL VIRTUAL PROCEDURE OnAddressFound( RequestId : PTR; Result : CARDINAL; CONST Address : ARRAY OF inetaddr.INETADDR );
  LOCAL VIRTUAL PROCEDURE OnNameFound( RequestId : PTR; Result : CARDINAL; CONST Name : StringsO.CString );
END CLocalDNSNotifier;  

(*---------------------------------------------------------------------------*)

CLASS IMPLEMENTATION CLocalDNSNotifier;

(*---------------------------------------------------------------------------*)

   LOCAL VIRTUAL PROCEDURE OnAddressFound( RequestId : PTR; Result : CARDINAL; CONST Addresses : ARRAY OF inetaddr.INETADDR );
   VAR
      i : CARDINAL;
  BEGIN
      IF ( Result = 0 ) AND ( SELF.Addresses <> NIL ) THEN
         FOR i := 0 TO MIN2( HIGH( Addresses ), AddressesHigh ) DO
            SELF.Addresses^[i] := Addresses[i];
         END;
      ELSE
         SELF.Result := Sync.arAborted;
      END;
      Signal.Signal();
   END OnAddressFound;

(*---------------------------------------------------------------------------*)

   LOCAL VIRTUAL PROCEDURE OnNameFound( RequestId : PTR; Result : CARDINAL; CONST Name : StringsO.CString );
   BEGIN
      IF ( Result = 0 ) AND ( SELF.Name <> NIL ) THEN
         Name.ToOA( OUT OA( NameHigh, SELF.Name ));
      ELSE
         SELF.Result := Sync.arAborted;
       END;
      Signal.Signal();
   END OnNameFound;

(*---------------------------------------------------------------------------*)

BEGIN
   Signal.Init( Sync.stEvent, L"", FALSE );
END CLocalDNSNotifier;  

(*===========================================================================*)

PROCEDURE NameToAddressWait( CONST Name : ARRAY OF WCHAR; DefaultPort : CARDINAL; TimeoutMS : CARDINAL; OUT Addresses : ARRAY OF inetaddr.INETADDR ) : BOOLEAN;
VAR
  LDNSN : CLocalDNSNotifier;
  H : PTR;
BEGIN
  LDNSN.Addresses := ADR( Addresses );
  LDNSN.AddressesHigh := HIGH( Addresses );
  IF NOT NameToAddress( ADR( LDNSN ), 0, Name, DefaultPort, OUT H ) THEN
    RETURN FALSE;
  END;
  IF LDNSN.Signal.Wait( Sync.FORSAFETY ) = Sync.arTimeout THEN
    ASSERT( FALSE );
    RETURN FALSE; 
  ELSE
    RETURN LDNSN.Result = Sync.arCompleted;
  END;
END NameToAddressWait;

(*---------------------------------------------------------------------------*)

PROCEDURE AddressToNameWait( CONST Address : inetaddr.INETADDR; IncludePort : BOOLEAN; TimeoutMS : CARDINAL; OUT Name : ARRAY OF WCHAR ) : BOOLEAN;
VAR
  LDNSN : CLocalDNSNotifier;
  H : PTR;
BEGIN
  LDNSN.Name := ADR( Name );
  LDNSN.NameHigh := HIGH( Name );
  IF NOT AddressToName( ADR( LDNSN ), 0, Address, IncludePort, OUT H ) THEN
    RETURN FALSE;
  END;
  IF LDNSN.Signal.Wait( Sync.FORSAFETY ) = Sync.arTimeout THEN
    ASSERT( FALSE );
    RETURN FALSE; 
  ELSE
    RETURN LDNSN.Result = Sync.arCompleted;
  END;
END AddressToNameWait;

(*---------------------------------------------------------------------------*)

PROCEDURE GetLocalName( OUT Result : StringsO.CString ) : BOOLEAN;
VAR
	Name : ARRAY [0..511] OF WCHAR;
BEGIN
	IF GetLocalNameOA( OUT Name ) THEN
		Result.FromOA( Name );
		RETURN TRUE;
	ELSE
		RETURN FALSE;
	END;
END GetLocalName;

(*---------------------------------------------------------------------------*)

PROCEDURE GetLocalNameOA( OUT Result : ARRAY OF WCHAR ) : BOOLEAN;
VAR
	NameA : ARRAY [0..511] OF CHAR;
BEGIN
	winsock.gethostname( ADR( NameA ), SIZE( NameA ));
	Strings.ToW( NameA, 0, OUT Result );
	RETURN TRUE;
END GetLocalNameOA;

(*---------------------------------------------------------------------------*)

PROCEDURE GetLocalIPsCount( IPV4, IPV6, IncludeDown : BOOLEAN ) : CARDINAL;
VAR
   address : inetaddr.INETADDR;
   count : CARDINAL;
   enumerator : netsrv.TPInterfaceEnumerator;
   i : CARDINAL;
   preferred : BOOLEAN;
   scope : inetaddr.TScope;
   assignment : netsrv.TAssignment;
BEGIN
   IF NOT netsrv.newInterfaceEnumerator( IPV4, IPV6, OUT enumerator ) THEN
      RETURN 0;
   END;
   count := 0;

   WHILE enumerator^.MoveNext() DO
      IF NOT IncludeDown AND ( enumerator^.State <> netsrv.stUp ) THEN
         CONTINUE;
      END;

      i := 0;
      WHILE enumerator^.InetAddress( i, OUT address, OUT preferred, OUT scope, OUT assignment ) DO
         IF ( scope = inetaddr.scoLocalSite ) OR ( scope = inetaddr.scoGlobal ) THEN
            INC( count );
         END;
         INC( i );
      END; // WHILE

   END; // WHILE

   DISPOSE( enumerator );
	RETURN count;
END GetLocalIPsCount;

(*---------------------------------------------------------------------------*)

PROCEDURE GetLocalIPs( IPV4, IPV6, IncludeDown : BOOLEAN; OUT Address : ARRAY OF inetaddr.INETADDR; OUT Filled : CARDINAL ) : BOOLEAN;
VAR
   address : inetaddr.INETADDR;
   enumerator : netsrv.TPInterfaceEnumerator;
   i : CARDINAL;
   preferred : BOOLEAN;
   scope : inetaddr.TScope;
   assignment : netsrv.TAssignment;
BEGIN
   IF ( HIGH( Address ) = -1 ) OR
      ( ADR( Address ) = NIL ) OR
      NOT netsrv.newInterfaceEnumerator( IPV4, IPV6, OUT enumerator ) THEN
      RETURN FALSE;
   END;
   Filled := 0;

   WHILE enumerator^.MoveNext() DO
      IF NOT IncludeDown AND ( enumerator^.State <> netsrv.stUp ) THEN
         CONTINUE;
      END;

      i := 0;
      WHILE enumerator^.InetAddress( i, OUT address, OUT preferred, OUT scope, OUT assignment ) DO
         IF ( scope = inetaddr.scoLocalSite ) OR ( scope = inetaddr.scoGlobal ) THEN
            Address[Filled] := address;
            INC( Filled );
            IF Filled > HIGH( Address ) THEN
               DISPOSE( enumerator );
               RETURN TRUE;
            END;
         END;
         INC( i );
      END; // WHILE

   END; // WHILE

   DISPOSE( enumerator );
	RETURN TRUE;
END GetLocalIPs;

(*===========================================================================*)

END dns.