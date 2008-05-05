IMPLEMENTATION MODULE FlashConnector;

//================================================================================
(*/* changes:

9.2.2006 (1, 2/3, 2, 2, 1/2, 3, 2) -- created, makefile, empty classes

28.2.2006 (1.5)
-- opravena chyba kódování, znaky s háèky apod. se nepøenesly, protože Flash oèekával jiný kód,
-- opravena chyba posílání více zpráv -- uvnitø se jednotlivé požadavky na odeslání dat scházejí ve frontì, fronta se pak posílá najednou. Fronta je vìtšinou prázdná (to odpovídá jednomu odeslání), a když se v ní sešlo více požadavkù, již se žádný nezpracoval,
-- chyba s mezerami -- možná souvisí s chybou kódování, já jsem ji již nepozoroval,

12.3.2006 (2)
-- opravena chyba fronty -- test na fullness byl ostry, takze fronta po prvnim preplneni a pak vycteni zustala ve stavu T = H+1, a nasledne cteni pak casto z domnele alokovaneho prvku H vracelo FALSE protoze MLen = 0 (toto se nesmi menit, to resi asynchroniciu plneni: item s MLen = 0 je alokovany, ale necommitnuty)
-- do fronty pridano flushovani pri plnosti
-- opravena chyba fronty, hranice typu pro T, H -- misto H+L>T je nyni T-L-H>=0 (viz prvni chyba)
-- opravena chyba fronty, pocitani ItemsPower vybiralo dvojnasobne delky

20.12.2006
-- zavedení do nového build systému

*/*)
//================================================================================

IMPORT
  winsock;

FROM Storage IMPORT
  REALLOCATE, ALLOCATE, DEALLOCATE;

IMPORT
  guiddef,
  windows,
  winerror,
  winnls,
  wtypes,
  oaidl,
  oleauto;

IMPORT
  Languages,
  Resources,
  Strings,
  Storage,
  Texts;

IMPORT
  com,
  ax_automation;

IMPORT
  netinit,
  netsocket,
  netsrv,
  netconndispatch;

//================================================================================

TYPE
  TPIMMFlashSrv_Event  = POINTER TO CIMMFlashSrv_Event;
  TPIMMFlashSrv_Native = POINTER TO CIMMFlashSrv_Native;
  TPFlashConnectorAX   = POINTER TO CFlashConnectorAX;

//--------------------------------------------------------------------------------

CONST
  // {EFD40B3D-C450-4E1D-9B30-159AD7606E0C}
  IID_Control = com.TGUID( 0EFD40B3DH, 0C450H, 04E1DH, 09BH, 030H, 015H, 09AH, 0D7H, 060H, 06EH, 00CH );
  // {F69DAC96-A671-4F76-9571-A0F0E086C755}
  IID_TypeLib = com.TGUID( 0F69DAC96H, 0A671H, 04F76H, 095H, 071H, 0A0H, 0F0H, 0E0H, 086H, 0C7H, 055H );
  // {4B9F1D00-479E-474D-807C-B1B11C1E5F2F}
  IID_INative = com.TGUID( 04B9F1D00H, 0479EH, 0474DH, 080H, 07CH, 0B1H, 0B1H, 01CH, 01EH, 05FH, 02FH );
  // {963B0F3B-6C5D-449B-9E72-75DE9D82E06C}
  IID_IEvent  = com.TGUID( 0963B0F3BH, 06C5DH, 0449BH, 09EH, 072H, 075H, 0DEH, 09DH, 082H, 0E0H, 06CH );

CLASS CClientConstructor IMPLEMENTS ax_automation.CAbstractClientConstructor;
  PUBLIC VIRTUAL PROCEDURE CreateInstance( VAR PInstance : ax_automation.TPActiveXControl ) : wtypes.HRESULT;
  PUBLIC VIRTUAL PROCEDURE QueryControlIIDs( VAR ControlIID, TypeLibIID, IDispatch_Native_IID, IDispatch_Event_IID : guiddef.IID );
  PUBLIC VIRTUAL PROCEDURE QueryControlNames( VAR DLLName, ControlName, ProgId : ARRAY OF WCHAR; VAR ProgIdCurrentVersion : CARDINAL );
  PUBLIC VIRTUAL PROCEDURE QueryTypeLibIndexes( VAR IControl, IDispatch_Native, IDispatch_Event : CARDINAL );
END CClientConstructor;

//--------------------------------------------------------------------------------

CLASS CServer( netconndispatch.CDispatcher );
  PAX : TPFlashConnectorAX;

  RBuffer : ADDRESS;
  RPos : CARDINAL;
  RSize : CARDINAL;
  RMax : CARDINAL;

  SBuffer : ADDRESS;
  SPos : CARDINAL;
  SSize : CARDINAL;

  // inherited from Dispatcher
  VIRTUAL PROCEDURE OnConnect( PConnection : netconndispatch.TConnectionHandle; Local : BOOLEAN; Error : CARDINAL );
  VIRTUAL PROCEDURE OnDisconnect( PConnection : netconndispatch.TConnectionHandle; Local : BOOLEAN; ErrorCode : CARDINAL );
  VIRTUAL PROCEDURE OnReceive( PConnection : netconndispatch.TConnectionHandle; Data : ADDRESS; DataLen : CARDINAL );

  PUBLIC PROCEDURE Parse( PConection : netconndispatch.TConnectionHandle; Data : ADDRESS; Len : CARDINAL );
  PUBLIC PROCEDURE SendMMFData( PConnection : netconndispatch.TConnectionHandle; StartBatch, StopBatch : BOOLEAN; DataName, DataValue, DataAddOn : wtypes.BSTR );
END CServer;

//--------------------------------------------------------------------------------

(*# save, call( convention=>stdcall ) *)

CLASS CIMMFlashSrv_Native( ax_automation.CActiveXDispatch );
  PAX : TPFlashConnectorAX;

  // MMFlashSrv_Native
  VIRTUAL PROCEDURE Start() : wtypes.HRESULT;
  VIRTUAL PROCEDURE Stop() : wtypes.HRESULT;
  VIRTUAL PROCEDURE Send( Client : windows.LONG; DataName, DataValue, DataAddOn : wtypes.BSTR ) : wtypes.HRESULT;
  VIRTUAL PROCEDURE StartBatch( Client : windows.LONG ) : wtypes.HRESULT;
  VIRTUAL PROCEDURE AddToBatch( DataName, DataValue, DataAddOn : wtypes.BSTR ) : wtypes.HRESULT;
  VIRTUAL PROCEDURE SendBatch() : wtypes.HRESULT;
  VIRTUAL PROCEDURE Disconnect( Client : windows.LONG ) : wtypes.HRESULT;
END CIMMFlashSrv_Native;

//--------------------------------------------------------------------------------

TYPE
  TEventDispatchId = (
    eidNone,
    eidOnConnect, // = 1
    eidOnDisconnect, // = 2
    eidOnReceive // = 3
  );

CLASS CIMMFlashSrv_Event( ax_automation.CActiveXDispatch );
  // MMFlashSrv_Event
  VIRTUAL PROCEDURE OnConnect( Client : windows.LONG; From : wtypes.BSTR ) : wtypes.HRESULT;
  VIRTUAL PROCEDURE OnDisconnect( Client : windows.LONG ) : wtypes.HRESULT;
  VIRTUAL PROCEDURE OnReceive( Client : windows.LONG; DataName, DataValue, DataAddOn : wtypes.BSTR ) : wtypes.HRESULT;
END CIMMFlashSrv_Event;

//--------------------------------------------------------------------------------

VAR
  AXConstructor : CClientConstructor;
  R : Resources.CResources;
  RefCount : CARDINAL;

CLASS CFlashConnectorAX( ax_automation.CActiveXControl );
  SRV         : CServer;
  Listening   : BOOLEAN;
  BatchClient : netconndispatch.TConnectionHandle := NIL;

  PUBLIC VIRTUAL PROCEDURE AddRef() : windows.ULONG;
  PUBLIC VIRTUAL PROCEDURE Release() : windows.ULONG;
  // ActiveX inherited
  VIRTUAL PROCEDURE CreateNativeIDispatch( VAR PIDispatch : ax_automation.TPActiveXDispatch ) : BOOLEAN;
  INTERNAL VIRTUAL PROCEDURE EnumerateEventIDispatch( VAR EnumerateState : LONGWORD; VAR IID : guiddef.IID; VAR TypeLibIndex : CARDINAL ) : BOOLEAN;
  // connection handling
  LOCAL PROCEDURE OnRemoteConnect( PConnection : netconndispatch.TConnectionHandle );
  LOCAL PROCEDURE OnRemoteDisconnect( PConnection : netconndispatch.TConnectionHandle; ErrorCode : CARDINAL );
  LOCAL PROCEDURE OnRemoteData( PConnection : netconndispatch.TConnectionHandle; Name, Value, AddOn : ARRAY OF WCHAR );
  // client handling
  PUBLIC PROCEDURE Start();
  PUBLIC PROCEDURE Stop();
  PUBLIC PROCEDURE Send( Client : windows.LONG; DataName, DataValue, DataAddOn : wtypes.BSTR );
  PUBLIC PROCEDURE StartBatch( Client : windows.LONG );
  PUBLIC PROCEDURE AddToBatch( DataName, DataValue, DataAddOn : wtypes.BSTR );
  PUBLIC PROCEDURE SendBatch();
  PUBLIC PROCEDURE Disconnect( Client : windows.LONG );
END CFlashConnectorAX;

(*# restore *)

//================================================================================

CLASS IMPLEMENTATION CClientConstructor;

//--------------------------------------------------------------------------------

  PUBLIC VIRTUAL PROCEDURE CreateInstance( VAR PInstance : ax_automation.TPActiveXControl ) : wtypes.HRESULT;
  VAR
    ControlIID, IIDx : guiddef.IID;
    PAX : TPFlashConnectorAX;
  BEGIN
    QueryControlIIDs( ControlIID, IIDx, IIDx, IIDx );

    NEW( PAX );
    PAX^.IID := ControlIID;
    PAX^.AddRef();
    PAX^.Init();

    PInstance := PAX;
    RETURN winerror.S_OK;
  END CreateInstance;

(*---------------------------------------------------------------------------*)

  PUBLIC VIRTUAL PROCEDURE QueryControlIIDs( VAR ControlIID, TypeLibIID, IDispatch_Native_IID, IDispatch_Event_IID : guiddef.IID );
  BEGIN
    ControlIID := guiddef.IID( IID_Control );
    TypeLibIID := guiddef.IID( IID_TypeLib );
    IDispatch_Native_IID := guiddef.IID( IID_INative );
    IDispatch_Event_IID := guiddef.IID( IID_IEvent );
  END QueryControlIIDs;

//--------------------------------------------------------------------------------

  PUBLIC VIRTUAL PROCEDURE QueryControlNames( VAR DLLName, ControlName, ProgId : ARRAY OF WCHAR; VAR ProgIdCurrentVersion : CARDINAL );
  BEGIN
    ASSIGN( DLLName, EMITW( %dll ));
    ASSIGN( ControlName, OAsz( R[Texts._ProductName] ));
    ASSIGN( ProgId, L'SmartControl.MMFlashSrv' );
    ProgIdCurrentVersion := 1;
  END QueryControlNames;

//--------------------------------------------------------------------------------

  PUBLIC VIRTUAL PROCEDURE QueryTypeLibIndexes( VAR IControl, IDispatch_Native, IDispatch_Event : CARDINAL );
  BEGIN
    IControl := 2;
    IDispatch_Native := 0;
    IDispatch_Event := 1;
  END QueryTypeLibIndexes;

//--------------------------------------------------------------------------------

BEGIN
END CClientConstructor;

//================================================================================

CONST
  leading = C'<flashconn>';
  trailing = C'</flashconn>';
  flashconnt = C'/flashconn';
  iteml = C'item';
  itemt = C'/item';
  namel = C'name';
  namet = C'/name';
  valuel = C'value';
  valuet = C'/value';
  addonl = C'addon';
  addont = C'/addon';

CLASS IMPLEMENTATION CServer;

//--------------------------------------------------------------------------------

  VIRTUAL PROCEDURE OnConnect( PConnection : netconndispatch.TConnectionHandle; Local : BOOLEAN; ErrorCode : CARDINAL );
  BEGIN
    IF NOT Local THEN
      PAX^.OnRemoteConnect( PConnection );
    END;
  END OnConnect;

//--------------------------------------------------------------------------------

  VIRTUAL PROCEDURE OnDisconnect( PConnection : netconndispatch.TConnectionHandle; Local : BOOLEAN; ErrorCode : CARDINAL );
  BEGIN
    IF NOT Local THEN
      PAX^.OnRemoteDisconnect( PConnection, ErrorCode );
    END;
  END OnDisconnect;

//--------------------------------------------------------------------------------

  VIRTUAL PROCEDURE OnReceive( PConnection : netconndispatch.TConnectionHandle; PData : ADDRESS; DataLen : CARDINAL );
  TYPE
    TPCH = POINTER TO CHAR;
    TS = ARRAY [0..4095] OF CHAR;
    TPS = POINTER TO TS;
  VAR
    c : CARDINAL;
    DPos : CARDINAL;
    EPos : CARDINAL;
    TrailingZero : BOOLEAN;
  BEGIN
    c := RPos + DataLen + 1;
    IF c > RMax THEN
      RPos := 0;
      // PAX^.OnRemoteReceive( PConnection, NIL, 0, -1 );
      RETURN;
    ELSIF c > RSize THEN
      RSize := (( RSize + c ) << 10 + 1 ) >> 10;
      REALLOCATE( RBuffer, RSize );
    END;

    Storage.Move( PData, ADDRESS( CARDINAL( RBuffer ) + RPos ), DataLen );
    INC( RPos, DataLen-1 );
    TrailingZero := TPCH( ADDRESS( CARDINAL( RBuffer ) + RPos ))^ = CHAR( 0 );
    INC( RPos );
    IF NOT TrailingZero THEN
      TPCH( ADDRESS( CARDINAL( RBuffer ) + RPos ))^ := CHAR( 0 );
    END;

    LOOP
      IF RPos < SIZE( leading )-1 THEN
        RETURN;
      END;

      DPos := Strings.IndexOfA( TPS( RBuffer )^, leading, 0 );
      IF DPos = MAX( CARDINAL ) THEN // strange
        c := Strings.IndexOfCharA( TPS( RBuffer )^, C'<', 0 );
        IF c = MAX( CARDINAL ) THEN
          RPos := 0;
        ELSIF c = 0 THEN // first is tag, but it is not leading
          DEC( RPos, 1 );
          Storage.Move( ADDRESS( CARDINAL( RBuffer ) + 1 ), RBuffer, RPos );
        ELSE
          DEC( RPos, c );
          Storage.Move( ADDRESS( CARDINAL( RBuffer ) + c ), RBuffer, RPos );
        END;
        RETURN;
      ELSIF DPos > 0 THEN
        DEC( RPos, DPos );
        Storage.Move( ADDRESS( CARDINAL( RBuffer ) + DPos ), RBuffer, RPos );
      END;
      EPos := Strings.IndexOfA( TPS( RBuffer )^, trailing, 0 );
      IF EPos = MAX( CARDINAL ) THEN
        RETURN;
      END;
      INC( EPos, SIZE( trailing )-1 );
    
      Parse( PConnection, RBuffer, EPos );

      DEC( RPos, EPos ); 
      IF TrailingZero THEN
        DEC( RPos );
      END;
      Storage.Move( ADDRESS( CARDINAL( RBuffer ) + EPos ), RBuffer, RPos );
    END; // LOOP
  END OnReceive;

//--------------------------------------------------------------------------------

  PROCEDURE Parse( PConnection : netconndispatch.TConnectionHandle; Data : ADDRESS; Len : CARDINAL );
  TYPE
    TPCH = POINTER TO CHAR;
    TS = ARRAY [0..4095] OF CHAR;
    TPS = POINTER TO TS;
  VAR
    i : CARDINAL;
    Tag, Name, Value : ARRAY [0..127] OF CHAR;
    AddOn : ARRAY [0..1023] OF CHAR;
    NameW, ValueW : ARRAY [0..127] OF WCHAR;
    AddOnW : ARRAY [0..1023] OF WCHAR;
    X : ADDRESS;
    InItem : BOOLEAN;
  BEGIN
    X := NIL;
    LOOP
      IF Len = 0 THEN
        EXIT;
      END;
      IF TPCH( Data )^ = C'<' THEN
        INC( Data ); DEC( Len );

        i := 0;
        LOOP
          IF Len = 0 THEN
            RETURN;
          ELSIF i+1 >= SIZE( Tag ) THEN
            RETURN;
          ELSIF TPCH( Data )^ = C'>' THEN
            Tag[i] := CHAR( 0 );

            IF EQUALS( Tag, flashconnt ) THEN
              RETURN;
            ELSIF EQUALS( Tag, iteml ) THEN
              InItem := TRUE;
              Name[0] := CHAR( 0 ); Value[0] := CHAR( 0 ); AddOn[0] := CHAR( 0 );
            ELSIF EQUALS( Tag, itemt ) THEN
              InItem := FALSE;
              IF Name[0] <> CHAR( 0 ) THEN
                Strings.ToW( Name, winnls.CP_UTF8, OUT NameW );
                Strings.ToW( Value, winnls.CP_UTF8, OUT ValueW );
                Strings.ToW( AddOn, winnls.CP_UTF8, OUT AddOnW );
                PAX^.OnRemoteData( PConnection, NameW, ValueW, AddOnW );
              END;
            ELSIF NOT InItem THEN
              // pass down
            ELSIF EQUALS( Tag, namel ) THEN
              X := Data; INC( X );
            ELSIF EQUALS( Tag, valuel ) THEN
              X := Data; INC( X );
            ELSIF EQUALS( Tag, addonl ) THEN
              X := Data; INC( X );
            ELSIF X = NIL THEN
              // pass down
            ELSIF EQUALS( Tag, namet ) THEN
              i := MIN2( SIZE( Name )-1, CARDINAL( Data ) - CARDINAL( X ) - SIZE( namet ));
              Storage.Move( X, ADR( Name ), i );
              Name[i] := CHAR( 0 );
            ELSIF EQUALS( Tag, valuet ) THEN
              i := MIN2( SIZE( Value )-1, CARDINAL( Data ) - CARDINAL( X ) - SIZE( valuet ));
              Storage.Move( X, ADR( Value ), i );
              Value[i] := CHAR( 0 );
            ELSIF EQUALS( Tag, addont ) THEN
              i := MIN2( SIZE( AddOn )-1, CARDINAL( Data ) - CARDINAL( X ) - SIZE( addont ));
              Storage.Move( X, ADR( AddOn ), i );
              AddOn[i] := CHAR( 0 );
            END;

            EXIT;
          ELSIF TPCH( Data )^ IN CHAR{ CHAR( 9 ), CHAR( 10 ), CHAR( 13 ), C' ' } THEN
            // skip blanks
          ELSE
            Tag[i] := TPCH( Data )^;
            INC( i );
          END;   

          INC( Data ); DEC( Len );
        END; // LOOP
      END;

      INC( Data ); DEC( Len );
    END; // LOOP
  END Parse;
  
//--------------------------------------------------------------------------------

  PROCEDURE SendMMFData( PConnection : netconndispatch.TConnectionHandle; StartBatch, StopBatch : BOOLEAN; DataName, DataValue, DataAddOn : wtypes.BSTR );
  CONST
    c1 = C'<flashconn>';
    c2 = C'<item><name>';
    c3 = C'</name><value>';
    c4 = C'</value></item>';
    c5 = C'</value><addon>';
    c6 = C'</addon></item>';
    c7 = C'</flashconn>';
  VAR
    DName, DValue : ARRAY [0..511] OF CHAR;
    DAddOn : ARRAY [0..1099] OF CHAR;
    l : CARDINAL;
  BEGIN
    IF SPos + 1024 + 1024 + 64 > SSize THEN
      SUPER.Send( NIL, PConnection, 0, SBuffer, SPos );
      SPos := 0;
    END;

    IF StartBatch THEN
      Storage.Move( ADR( c1 ), ADDRESS( CARDINAL( SBuffer ) + SPos ), SIZE( c1 )-1 );
      INC( SPos, SIZE( c1 )-1 );
    END;
    IF ( DataName <> NIL ) AND ( DataName^ <> WCHAR( 0 )) THEN
      Strings.ToA( OA( HIGH( DName ), DataName ), winnls.CP_UTF8, OUT DName );
      Strings.ToA( OA( HIGH( DValue ), DataValue ), winnls.CP_UTF8, OUT DValue );

      Storage.Move( ADR( c2 ), ADDRESS( CARDINAL( SBuffer ) + SPos ), SIZE( c2 )-1 );
      INC( SPos, SIZE( c2 )-1 );
      //..
      l := LENGTH( DName );
      Storage.Move( ADR( DName ), ADDRESS( CARDINAL( SBuffer ) + SPos ), l );
      INC( SPos, l );
      //..
      Storage.Move( ADR( c3 ), ADDRESS( CARDINAL( SBuffer ) + SPos ), SIZE( c3 )-1 );
      INC( SPos, SIZE( c3 )-1 );
      //..
      l := LENGTH( DValue );
      Storage.Move( ADR( DValue ), ADDRESS( CARDINAL( SBuffer ) + SPos ), l );
      INC( SPos, l );

      IF DataAddOn^ = WCHAR( 0 ) THEN
        Storage.Move( ADR( c4 ), ADDRESS( CARDINAL( SBuffer ) + SPos ), SIZE( c4 )-1 );
        INC( SPos, SIZE( c4 )-1 );
      ELSE
        Storage.Move( ADR( c5 ), ADDRESS( CARDINAL( SBuffer ) + SPos ), SIZE( c5 )-1 );
        INC( SPos, SIZE( c5 )-1 );
        //..
        Strings.ToA( OA( 1023, DataAddOn ), winnls.CP_UTF8, OUT DAddOn );
        l := LENGTH( DAddOn );
        Storage.Move( ADR( DAddOn ), ADDRESS( CARDINAL( SBuffer ) + SPos ), l );
        INC( SPos, l );
        //..
        Storage.Move( ADR( c6 ), ADDRESS( CARDINAL( SBuffer ) + SPos ), SIZE( c6 )-1 );
        INC( SPos, SIZE( c6 )-1 );
      END;
    END;

    IF StopBatch THEN
      Storage.Move( ADR( c7 ), ADDRESS( CARDINAL( SBuffer ) + SPos ), SIZE( c7 )-1 );
      INC( SPos, SIZE( c7 )-1 );
      PCHAR( SBuffer@[SPos] )^ := 0C;
      INC( SPos );

      SUPER.Send( NIL, PConnection, 0, SBuffer, SPos );
      SPos := 0;
    END;
  END SendMMFData;
  
//--------------------------------------------------------------------------------
  
BEGIN
  PAX := NIL;
  RPos := 0;
  RSize := 4096;
  RMax := 65536;
  ALLOCATE( RBuffer, RSize );
  SPos := 0;
  SSize := 8192;
  ALLOCATE( SBuffer, SSize );
END CServer;

//================================================================================

CLASS IMPLEMENTATION CIMMFlashSrv_Native;

//--------------------------------------------------------------------------------

  VIRTUAL PROCEDURE Start() : wtypes.HRESULT;
  BEGIN
    PAX^.Start();
    RETURN winerror.S_OK;
  END Start;

//--------------------------------------------------------------------------------

  VIRTUAL PROCEDURE Stop() : wtypes.HRESULT;
  BEGIN
    PAX^.Stop();
    RETURN winerror.S_OK;
  END Stop;

//--------------------------------------------------------------------------------

  VIRTUAL PROCEDURE Send( Client : windows.LONG; DataName, DataValue, DataAddOn : wtypes.BSTR ) : wtypes.HRESULT;
  BEGIN
    PAX^.Send( Client, DataName, DataValue, DataAddOn );
    RETURN winerror.S_OK;
  END Send;

//--------------------------------------------------------------------------------
 
  VIRTUAL PROCEDURE StartBatch( Client : windows.LONG ) : wtypes.HRESULT;
  BEGIN
    PAX^.StartBatch( Client );
    RETURN winerror.S_OK;
  END StartBatch;

//--------------------------------------------------------------------------------
 
  VIRTUAL PROCEDURE AddToBatch( DataName, DataValue, DataAddOn : wtypes.BSTR ) : wtypes.HRESULT;
  BEGIN
    PAX^.AddToBatch( DataName, DataValue, DataAddOn );
    RETURN winerror.S_OK;
  END AddToBatch;

//--------------------------------------------------------------------------------
 
  VIRTUAL PROCEDURE SendBatch() : wtypes.HRESULT;
  BEGIN
    PAX^.SendBatch();
    RETURN winerror.S_OK;
  END SendBatch;

//--------------------------------------------------------------------------------
 
  VIRTUAL PROCEDURE Disconnect( Client : windows.LONG ) : wtypes.HRESULT;
  BEGIN
    PAX^.Disconnect( Client );
    RETURN winerror.S_OK;
  END Disconnect;

//--------------------------------------------------------------------------------
 
BEGIN
  PAX := NIL;
END CIMMFlashSrv_Native;

//================================================================================

CLASS IMPLEMENTATION CIMMFlashSrv_Event;

//--------------------------------------------------------------------------------

  VIRTUAL PROCEDURE OnConnect( Client : windows.LONG; From : wtypes.BSTR ) : wtypes.HRESULT;
  BEGIN
    RETURN winerror.E_NOTIMPL;
  END OnConnect;

//--------------------------------------------------------------------------------

  VIRTUAL PROCEDURE OnDisconnect( Client : windows.LONG ) : wtypes.HRESULT;
  BEGIN
    RETURN winerror.E_NOTIMPL;
  END OnDisconnect;

//--------------------------------------------------------------------------------

  VIRTUAL PROCEDURE OnReceive( Client : windows.LONG; DataName, DataValue, DataAddOn : wtypes.BSTR ) : wtypes.HRESULT;
  BEGIN
    RETURN winerror.E_NOTIMPL;
  END OnReceive;

//--------------------------------------------------------------------------------

BEGIN
END CIMMFlashSrv_Event;

//================================================================================

CLASS IMPLEMENTATION CFlashConnectorAX;

//--------------------------------------------------------------------------------

  PUBLIC VIRTUAL PROCEDURE AddRef() : windows.ULONG;
  BEGIN
    IF RefCount = 0 THEN
      netinit.Startup();
    END;
    INC( RefCount );
    IF ReferenceCount = 0 THEN
      SRV.Init();
    END;
    RETURN SUPER.AddRef();
  END AddRef;

//--------------------------------------------------------------------------------

  PUBLIC VIRTUAL PROCEDURE Release() : windows.ULONG;
  BEGIN
    IF ReferenceCount = 1 THEN
      Stop();
      SRV.FINALLY();
    END;
    IF RefCount = 1 THEN
      netinit.Cleanup();
    END;
    DEC( RefCount );
    RETURN SUPER.Release();
  END Release;

//--------------------------------------------------------------------------------

  VIRTUAL PROCEDURE CreateNativeIDispatch( VAR PIDispatch : ax_automation.TPActiveXDispatch ) : BOOLEAN; // must call AddRef to PIDispatch
  VAR
    c : CARDINAL;
    IID, IIDx : guiddef.IID;
    Index : CARDINAL;
    HR : wtypes.HRESULT;
  BEGIN
    NEW( TPIMMFlashSrv_Native( PIDispatch ));
    PIDispatch^.AddRef();
    TPIMMFlashSrv_Native( PIDispatch )^.PAX := ADR( SELF );

    ax_automation.GetClientConstructor()^.QueryControlIIDs( IIDx, IIDx, IID, IIDx );
    ax_automation.GetClientConstructor()^.QueryTypeLibIndexes( c, Index, c );
    HR := PIDispatch^.Init( IID, ADR( SELF ), Index );

    IF HR = winerror.S_OK THEN
      RETURN TRUE;
    ELSE
      RETURN FALSE;
    END;
  END CreateNativeIDispatch;

(*---------------------------------------------------------------------------*)

  VIRTUAL PROCEDURE EnumerateEventIDispatch( VAR EnumerateState : LONGWORD; VAR IID : guiddef.IID; VAR TypeLibIndex : CARDINAL ) : BOOLEAN;
  VAR
    c : CARDINAL;
    IIDx : guiddef.IID;
  BEGIN
    IF EnumerateState = LONGWORD( 0 ) THEN
      EnumerateState := 1;
      ax_automation.GetClientConstructor()^.QueryControlIIDs( IIDx, IIDx, IIDx, IID );
      ax_automation.GetClientConstructor()^.QueryTypeLibIndexes( c, c, TypeLibIndex );
    ELSE
      RETURN FALSE;
    END;
    RETURN TRUE;
  END EnumerateEventIDispatch;

//--------------------------------------------------------------------------------

  LOCAL PROCEDURE OnRemoteConnect( PConnection : netconndispatch.TConnectionHandle );
  VAR
    IID, IIDx : guiddef.IID;
    Parameters : ARRAY [0..1] OF oaidl.VARIANT;
    ValueS : ARRAY [0..255] OF WCHAR;
  BEGIN
    // parameters are of reveresed order
    oleauto.VariantInit( ADR( Parameters[1] ));
    Parameters[1].vt := wtypes.VT_I4;
    Parameters[1].lVal := windows.LONG( PConnection );

    ValueS := L'';
    oleauto.VariantInit( ADR( Parameters[0] ));
    Parameters[0].vt := wtypes.VT_BSTR;
    Parameters[0].bstrVal := oleauto.SysAllocString( ADR( ValueS ));

    ax_automation.GetClientConstructor()^.QueryControlIIDs( IIDx, IIDx, IIDx, IID );
    DispatchEvent( IID, LONGWORD( eidOnConnect ), Parameters );

    oleauto.VariantClear( ADR( Parameters[0] ));
    oleauto.VariantClear( ADR( Parameters[1] ));
  END OnRemoteConnect;

//--------------------------------------------------------------------------------

  LOCAL PROCEDURE OnRemoteDisconnect( PConnection : netconndispatch.TConnectionHandle; ErrorCode : CARDINAL );
  VAR
    IID, IIDx : guiddef.IID;
    Parameters : ARRAY [0..0] OF oaidl.VARIANT;
  BEGIN
    // parameters are of reveresed order
    oleauto.VariantInit( ADR( Parameters[0] ));
    Parameters[0].vt := wtypes.VT_I4;
    Parameters[0].lVal := windows.LONG( PConnection );

    ax_automation.GetClientConstructor()^.QueryControlIIDs( IIDx, IIDx, IIDx, IID );
    DispatchEvent( IID, LONGWORD( eidOnDisconnect ), Parameters );

    oleauto.VariantClear( ADR( Parameters[0] ));
  END OnRemoteDisconnect;

//--------------------------------------------------------------------------------

  LOCAL PROCEDURE OnRemoteData( PConnection : netconndispatch.TConnectionHandle; Name, Value, AddOn : ARRAY OF WCHAR );
  VAR
    IID, IIDx : guiddef.IID;
    Parameters : ARRAY [0..3] OF oaidl.VARIANT;
  BEGIN
    // parameters are of reveresed order
    oleauto.VariantInit( ADR( Parameters[3] ));
    Parameters[3].vt := wtypes.VT_I4;
    Parameters[3].lVal := windows.LONG( PConnection );

    oleauto.VariantInit( ADR( Parameters[2] ));
    Parameters[2].vt := wtypes.VT_BSTR;
    Parameters[2].bstrVal := oleauto.SysAllocString( ADR( Name ));

    oleauto.VariantInit( ADR( Parameters[1] ));
    Parameters[1].vt := wtypes.VT_BSTR;
    Parameters[1].bstrVal := oleauto.SysAllocString( ADR( Value ));

    oleauto.VariantInit( ADR( Parameters[0] ));
    Parameters[0].vt := wtypes.VT_BSTR;
    Parameters[0].bstrVal := oleauto.SysAllocString( ADR( AddOn ));

    ax_automation.GetClientConstructor()^.QueryControlIIDs( IIDx, IIDx, IIDx, IID );
    DispatchEvent( IID, LONGWORD( eidOnReceive ), Parameters );

    oleauto.VariantClear( ADR( Parameters[0] ));
    oleauto.VariantClear( ADR( Parameters[1] ));
    oleauto.VariantClear( ADR( Parameters[2] ));
    oleauto.VariantClear( ADR( Parameters[3] ));
  END OnRemoteData;

//--------------------------------------------------------------------------------

  PUBLIC PROCEDURE Start();
  BEGIN
    IF NOT Listening THEN
      Listening := TRUE;
      netsrv.StartListen( 6006, netsocket.stStream, SRV.Listener, 0, NIL );
    END;
  END Start;

//--------------------------------------------------------------------------------

  PUBLIC PROCEDURE Stop();
  BEGIN
    IF Listening THEN
      Listening := FALSE;
      netsrv.StopListenPort( netsocket.stStream, 6006 );
    END;
  END Stop;

//--------------------------------------------------------------------------------

  PUBLIC PROCEDURE Send( Client : windows.LONG; DataName, DataValue, DataAddOn : wtypes.BSTR );
  BEGIN
    SRV.SendMMFData( netconndispatch.TConnectionHandle( Client ), TRUE, TRUE, DataName, DataValue, DataAddOn );
  END Send;

//--------------------------------------------------------------------------------

  PUBLIC PROCEDURE StartBatch( Client : windows.LONG );
  BEGIN
    BatchClient := netconndispatch.TConnectionHandle( Client );
    SRV.SendMMFData( BatchClient, TRUE, FALSE, NIL, NIL, NIL );
  END StartBatch;

//--------------------------------------------------------------------------------

  PUBLIC PROCEDURE AddToBatch( DataName, DataValue, DataAddOn : wtypes.BSTR );
  BEGIN
    SRV.SendMMFData( BatchClient, FALSE, FALSE, DataName, DataValue, DataAddOn );
  END AddToBatch;

//--------------------------------------------------------------------------------

  PUBLIC PROCEDURE SendBatch();
  BEGIN
    SRV.SendMMFData( BatchClient, FALSE, TRUE, NIL, NIL, NIL );
  END SendBatch;

//--------------------------------------------------------------------------------

  PUBLIC PROCEDURE Disconnect( Client : windows.LONG );
  BEGIN
  END Disconnect;

//--------------------------------------------------------------------------------

BEGIN
  SRV.PAX := ADR( SELF );
  Listening := FALSE;
END CFlashConnectorAX;

//================================================================================
// procedural interface

INITIALLY __I();
BEGIN
  RefCount := 0;
  ax_automation.RegisterClientConstructor( ADR( AXConstructor ));
  R.LoadRES2( EMITW( %dll ), L'FlashConnector.Texts' );
  R.Lang := Languages.GetDefaultLanguage( Languages.dlUser );
END __I;

FINALLY __F();
BEGIN
  ax_automation.ForgetClientConstructor();
END __F;

//================================================================================

END FlashConnector.