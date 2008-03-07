IMPLEMENTATION MODULE dns;

(*===========================================================================*)

FROM Storage IMPORT
  ALLOCATE, DEALLOCATE;
  
IMPORT
  Delegate,
  Exceptions,
  msghandler,
  netpool,
  Storage,
  Strings,
  winerror;

(*---------------------------------------------------------------------------*)

TYPE
  TDNSAcquire  = ( dnsUnknown, dnsGetAddress, dnsGetName );

  TDNSBuffer   = ARRAY [0..winsock.MAXGETHOSTSTRUCT-1] OF CHAR;
  TPDNSBuffer  = POINTER TO TDNSBuffer;

  TPDNSRequest = POINTER TO CDNSRequest;

CLASS CDNSRequest( Delegate.ADelegate );
  // user
  WhatToAcquire : TDNSAcquire;
  RequestId     : PTR;
  // process
  RequestBuffer : TDNSBuffer;
  HTask         : ADDRESS;
END CDNSRequest;

(*---------------------------------------------------------------------------*)

CLASS IMPLEMENTATION CDNSRequest;
BEGIN
  WhatToAcquire := dnsUnknown;
  RequestId := 0;
  Storage.Zero( ADR( RequestBuffer ), SIZE( RequestBuffer ));
  HTask := NIL;
FINALLY
  IF HTask <> NIL THEN
    winsock.WSACancelAsyncRequest( HTask );
  END;
END CDNSRequest;

(*===========================================================================*)

CLASS IMPLEMENTATION ADNSNotifier;

  LOCAL FINAL PROCEDURE OnMessage( Result : Sync.TAsyncResult; PoolHandle : Sync.WAITABLE; UserId : PTR; CONST MSG : msghandler.IMessage );
  VAR
    Address : ARRAY [0..15] OF winsock.IN_ADDR;
    DNS : TPDNSRequest := TPDNSRequest( UserId );
    i : CARDINAL;
    Name : StringsO.CString;
    netResult : CARDINAL;
  BEGIN
    CASE Result OF
    | Sync.arCannotStart :
      netResult := winsock.WSAENOBUFS;
    | Sync.arCompleted :
      netResult := CARDINAL( winsock.WSAGETASYNCERROR( MSG[3] ));
    | Sync.arAborted :
      netResult := winsock.WSAECONNABORTED;
    | Sync.arTimeout :
      netResult := winsock.WSATRY_AGAIN;
    END; // CASE

    CASE DNS^.WhatToAcquire OF
    | dnsGetAddress :
      i := 0;
      IF netResult = 0 THEN
        WHILE winsock.PHOSTENT( ADR( DNS^.RequestBuffer ))^.h_addr_list[i] <> NIL DO
          Address[i] := winsock.Pin_addr( winsock.PHOSTENT( ADR( DNS^.RequestBuffer ))^.h_addr_list[i] )^;
          INC( i );
        END; // WHILE
      END;
      IF i = 0 THEN
        Address[0].s_addr := 0;
        i := 1;
      END;
      OnAddressFound( DNS^.RequestId, netResult, OA( i-1, ADR( Address[0] )) );
    | dnsGetName :
      IF ( netResult = 0 ) AND ( winsock.PHOSTENT( ADR( DNS^.RequestBuffer ))^.h_name <> NIL ) THEN
        Name.FromOAA( 0, OAsz( PCHAR( winsock.PHOSTENT( ADR( DNS^.RequestBuffer ))^.h_name )));
      END;
      OnNameFound( DNS^.RequestId, netResult, Name );
    ELSE
      ASSERT( FALSE );
    END; // CASE

    IF Result = Sync.arCompleted THEN
      DNS^.HTask := NIL;
    END;
    DNS^.Release();
  END OnMessage;

(*---------------------------------------------------------------------------*)

  LOCAL VIRTUAL PROCEDURE OnAddressFound( RequestId : PTR; Result : CARDINAL; CONST Address : ARRAY OF winsock.IN_ADDR );
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
  netpool.Pool()^.Abort( REF Handle );
END KillPending;

(*---------------------------------------------------------------------------*)

PROCEDURE KillAllPending( PNotifier : TPDNSNotifier );
BEGIN
  netpool.Pool()^.AbortAll( PNotifier );
END KillAllPending;

(*===========================================================================*)

PROCEDURE NameToAddress( PNotifier : TPDNSNotifier; RequestId : PTR; CONST Name : ARRAY OF WCHAR; TimeoutMS : CARDINAL; OUT Handle : PTR ) : BOOLEAN;
VAR
  Address : winsock.IN_ADDR;
  Handler : msghandler.TPMessageHandler;
  Message : msghandler.Message;
  Request : TPDNSRequest;
  StringA : ARRAY [0..511] OF CHAR;
BEGIN
  Strings.ToA( Name, 0, OUT StringA );
  Address.s_addr := winsock.inet_addr( ADR( StringA ));
  IF Address.s_addr <> winsock.INADDR_NONE THEN
    IF PNotifier <> NIL THEN
      PNotifier^.OnAddressFound( RequestId, 0, OA( 0, ADR( Address )) );
    END;
    RETURN TRUE;
  END;

  NEW( Request );
  Request^.WhatToAcquire := dnsGetAddress;
  Request^.RequestId := RequestId;
  Request^.AddRef();
 
  netpool.Pool()^.WaitMessage( PNotifier, Request, TimeoutMS, TRUE, OUT Handler, OUT Message, OUT Handle );

  Request^.HTask := winsock.WSAAsyncGetHostByName(
    Handler^.Handle, Message.Message,
    ADR( StringA ),
    ADR( Request^.RequestBuffer ), SIZE( Request^.RequestBuffer )
  );
  IF Request^.HTask = NIL THEN
    netpool.Pool()^.Abort( REF Handle );
    Request^.Release();
    RETURN FALSE;
  ELSE
    Request^.Release();
    RETURN TRUE;
  END;
END NameToAddress;

(*---------------------------------------------------------------------------*)

PROCEDURE AddressToName( PNotifier : TPDNSNotifier; RequestId : PTR; CONST Address : winsock.IN_ADDR; TimeoutMS : CARDINAL; OUT Handle : PTR ) : BOOLEAN;
VAR
  Handler : msghandler.TPMessageHandler;
  Message : msghandler.Message;
  Request : TPDNSRequest;
BEGIN
  NEW( Request );
  Request^.WhatToAcquire := dnsGetName;
  Request^.RequestId := RequestId;
  Request^.AddRef();

  netpool.Pool()^.WaitMessage( PNotifier, Request, TimeoutMS, TRUE, OUT Handler, OUT Message, OUT Handle );

  Request^.HTask := winsock.WSAAsyncGetHostByAddr(
     Handler^.Handle, Message.Message,
     PCHAR( ADR( Address )), SIZE( Address ),
     winsock.AF_INET,
     ADR( Request^.RequestBuffer ), SIZE( Request^.RequestBuffer )
  );
  IF Request^.HTask = NIL THEN
    netpool.Pool()^.Abort( REF Handle );
    Request^.Release();
    RETURN FALSE;
  ELSE
    Request^.Release();
    RETURN TRUE;
  END;
END AddressToName;

(*===========================================================================*)

CLASS CLocalDNSNotifier( ADNSNotifier );
  LOCAL VAR
    Address : POINTER TO winsock.IN_ADDR;
    Name : PWCHAR;
    NameHigh : CARDINAL;
    Result : Sync.TAsyncResult := Sync.arCompleted;
    Signal : Sync.SIGNAL;
  LOCAL VIRTUAL PROCEDURE OnAddressFound( RequestId : PTR; Result : CARDINAL; CONST Address : ARRAY OF winsock.IN_ADDR );
  LOCAL VIRTUAL PROCEDURE OnNameFound( RequestId : PTR; Result : CARDINAL; CONST Name : StringsO.CString );
END CLocalDNSNotifier;  

(*---------------------------------------------------------------------------*)

CLASS IMPLEMENTATION CLocalDNSNotifier;

(*---------------------------------------------------------------------------*)

  LOCAL VIRTUAL PROCEDURE OnAddressFound( RequestId : PTR; Result : CARDINAL; CONST Address : ARRAY OF winsock.IN_ADDR );
  BEGIN
    IF ( Result = 0 ) AND ( SELF.Address <> NIL ) THEN
      SELF.Address^ := Address[0];
    ELSE
      SELF.Result := Sync.arAborted;
    END;
    Sync.Signal( Signal );
  END OnAddressFound;

(*---------------------------------------------------------------------------*)

  LOCAL VIRTUAL PROCEDURE OnNameFound( RequestId : PTR; Result : CARDINAL; CONST Name : StringsO.CString );
  BEGIN
    IF ( Result = 0 ) AND ( SELF.Name <> NIL ) THEN
      Name.ToOA( OUT OA( NameHigh, SELF.Name ));
    ELSE
      SELF.Result := Sync.arAborted;
    END;
    Sync.Signal( Signal );
  END OnNameFound;

(*---------------------------------------------------------------------------*)

BEGIN
  Address := NIL;
  Name := NIL;
  NameHigh := 0;
  Signal := Sync.CreateSignal( FALSE, L"" );
FINALLY
	Sync.DeleteSignal( REF Signal );
END CLocalDNSNotifier;  

(*===========================================================================*)

PROCEDURE NameToAddressWait( CONST Name : ARRAY OF WCHAR; TimeoutMS : CARDINAL; OUT Address : winsock.IN_ADDR ) : BOOLEAN;
VAR
  LDNSN : CLocalDNSNotifier;
  H : PTR;
BEGIN
  LDNSN.Address := ADR( Address );
  IF NOT NameToAddress( ADR( LDNSN ), 0, Name, TimeoutMS, OUT H ) THEN
    RETURN FALSE;
  END;
  IF Sync.Wait( LDNSN.Signal, Sync.FORSAFETY ) = Sync.arTimeout THEN
    ASSERT( FALSE );
    RETURN FALSE; 
  ELSE
    RETURN LDNSN.Result = Sync.arCompleted;
  END;
END NameToAddressWait;

(*---------------------------------------------------------------------------*)

PROCEDURE AddressToNameWait( CONST Address : winsock.IN_ADDR; TimeoutMS : CARDINAL; OUT Name : ARRAY OF WCHAR ) : BOOLEAN;
VAR
  LDNSN : CLocalDNSNotifier;
  H : PTR;
BEGIN
  LDNSN.Name := ADR( Name );
  LDNSN.NameHigh := HIGH( Name );
  IF NOT AddressToName( ADR( LDNSN ), 0, Address, TimeoutMS, OUT H ) THEN
    RETURN FALSE;
  END;
  IF Sync.Wait( LDNSN.Signal, Sync.FORSAFETY ) = Sync.arTimeout THEN
    ASSERT( FALSE );
    RETURN FALSE; 
  ELSE
    RETURN LDNSN.Result = Sync.arCompleted;
  END;
END AddressToNameWait;

(*---------------------------------------------------------------------------*)

PROCEDURE GetLocalName( TimeoutMS : CARDINAL; OUT Result : StringsO.CString ) : BOOLEAN;
VAR
	Name : ARRAY [0..511] OF WCHAR;
BEGIN
	IF GetLocalNameOA( TimeoutMS, OUT Name ) THEN
		Result.FromOA( Name );
		RETURN TRUE;
	ELSE
		RETURN FALSE;
	END;
END GetLocalName;

(*---------------------------------------------------------------------------*)

PROCEDURE GetLocalNameOA( TimeoutMS : CARDINAL; OUT Result : ARRAY OF WCHAR ) : BOOLEAN;
VAR
	NameA : ARRAY [0..511] OF CHAR;
BEGIN
	winsock.gethostname( ADR( NameA ), SIZE( NameA ));
	Strings.ToW( NameA, 0, OUT Result );
	RETURN TRUE;
END GetLocalNameOA;

(*---------------------------------------------------------------------------*)

PROCEDURE GetLocalIPs( TimeoutMS : CARDINAL; OUT Address : ARRAY OF winsock.IN_ADDR; OUT Filled : CARDINAL ) : BOOLEAN;
VAR
	Name : ARRAY [0..511] OF WCHAR;
BEGIN
	IF NOT GetLocalNameOA( TimeoutMS DIV 2, OUT Name ) THEN
		RETURN FALSE;
	ELSIF NOT NameToAddressWait( Name, TimeoutMS DIV 2, OUT Address[0] ) THEN
	  RETURN FALSE;
	END;
	Filled := 1;
	RETURN TRUE;
END GetLocalIPs;

(*===========================================================================*)

END dns.