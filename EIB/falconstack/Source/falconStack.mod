IMPLEMENTATION MODULE falconStack;

(*================================================================================*)
(*/* UPDATES
*/*)
(*================================================================================*)

FROM Storage IMPORT
  ALLOCATE, DEALLOCATE;

FROM Strings IMPORT
  LowerizeW;

IMPORT
  oaidl,
  objbase,
  ocidl,
  oleauto,
  unknwn,
  windows,
  winerror,
  wtypes;
  
IMPORT
  Storage;

(*================================================================================*)

CLASS IMPLEMENTATION CGroupDataEvent;

  VIRTUAL PROCEDURE QueryInterface( CONST riid : guiddef.IID; ppvObject : PADDRESS ) : wtypes.HRESULT;
  BEGIN
    IF ppvObject = NIL THEN 
      RETURN winerror.E_INVALIDARG;
    ELSIF riid = guiddef.IID( falcon.IID_ICustomClientGroupDataEvent ) THEN
      AddRef();
      ppvObject^ := ADR( SELF );
      RETURN winerror.S_OK;
    ELSE
      RETURN SUPER.QueryInterface( riid, ppvObject );
    END;
  END QueryInterface;

  VIRTUAL PROCEDURE GroupDataIndicationRead( 
      GroupAddress : INTEGER;
      RoutingCnt   : INTEGER;
      Prio         : falcon.Priority;
      Data         : oaidl.VARIANT
  ) : wtypes.HRESULT;
  BEGIN
    GroupDataIndication( eib_def.directionRead, GroupAddress, RoutingCnt, Prio, Data );
    RETURN 0;
  END GroupDataIndicationRead;
  
  VIRTUAL PROCEDURE GroupDataIndicationWrite( 
      GroupAddress : INTEGER;
      RoutingCnt   : INTEGER;
      Prio         : falcon.Priority;
      Data         : oaidl.VARIANT
  ) : wtypes.HRESULT;
  BEGIN
    GroupDataIndication( eib_def.directionWrite, GroupAddress, RoutingCnt, Prio, Data );
    RETURN 0;
  END GroupDataIndicationWrite;
  
  VIRTUAL PROCEDURE GroupDataIndicationResponse( 
      GroupAddress : INTEGER;
      RoutingCnt   : INTEGER;
      Prio         : falcon.Priority;
      Data         : oaidl.VARIANT
  ) : wtypes.HRESULT;
  BEGIN
    GroupDataIndication( eib_def.directionResponse, GroupAddress, RoutingCnt, Prio, Data );
    RETURN 0;
  END GroupDataIndicationResponse;
  
  VIRTUAL PROCEDURE GroupDataConfirmationRead( 
      GroupAddress : INTEGER;
      RoutingCnt   : INTEGER;
      Prio         : falcon.Priority;
      Error        : wtypes.VARIANT_BOOL;
      Data         : oaidl.VARIANT
  ) : wtypes.HRESULT;
  BEGIN
    GroupDataConfirmation( eib_def.directionRead, GroupAddress, RoutingCnt, Prio, Error, Data );
    RETURN 0;
  END GroupDataConfirmationRead;
  
  VIRTUAL PROCEDURE GroupDataConfirmationWrite( 
      GroupAddress : INTEGER;
      RoutingCnt   : INTEGER;
      Prio         : falcon.Priority;
      Error        : wtypes.VARIANT_BOOL;
      Data         : oaidl.VARIANT
  ) : wtypes.HRESULT;
  BEGIN
    GroupDataConfirmation( eib_def.directionWrite, GroupAddress, RoutingCnt, Prio, Error, Data );
    RETURN 0;
  END GroupDataConfirmationWrite;
  
  VIRTUAL PROCEDURE GroupDataConfirmationResponse( 
      GroupAddress : INTEGER;
      RoutingCnt   : INTEGER;
      Prio         : falcon.Priority;
      Error        : wtypes.VARIANT_BOOL;
      Data         : oaidl.VARIANT
  ) : wtypes.HRESULT;
  BEGIN
    GroupDataConfirmation( eib_def.directionResponse, GroupAddress, RoutingCnt, Prio, Error, Data );
    RETURN 0;
  END GroupDataConfirmationResponse;

  PROCEDURE GroupDataConfirmation(
      Direction : eib_def.TValueDirection;
      GroupAddress : INTEGER;
      RoutingCount : INTEGER;
      Priority : falcon.Priority;
      Error : wtypes.VARIANT_BOOL;
      Data : oaidl.VARIANT
  );
  VAR
    Destination : eib_def.CAddress;
    L : CARDINAL;
    Packet : eib_def.TPacket;
    P : eib_def.TPriority;
  BEGIN
    CASE Priority OF
    | falcon.PriorityLow : P := eib_def.priorityNormal;
    | falcon.PriorityHigh : P := eib_def.priorityHigh;
    | falcon.PriorityAlarm : P := eib_def.priorityAlarm;
    | falcon.PrioritySystem :  P := eib_def.prioritySystem;
    END;
    Destination.SetGroupAddress1( GroupAddress );
    IF Data.vt = wtypes.VT_EMPTY THEN
      L := 0;
    END;

    Packet.SetValueDirection( Direction );
    Packet.SetDestinationAddress( Destination );
    Packet.SetPriority( P );
    Packet.SetRoutingCounter( RoutingCount );

    IF Error = windows.True THEN
      PTL^.T_Groupdata_Con( eib_stack.essConError, Destination, ADR( Packet ));
    ELSE
      PTL^.T_Groupdata_Con( eib_stack.essOK, Destination, ADR( Packet ));
    END;
  END GroupDataConfirmation;

  PROCEDURE GroupDataIndication(
      Direction : eib_def.TValueDirection;
      GroupAddress : INTEGER;
      RoutingCount : INTEGER;
      Priority : falcon.Priority;
      Data : oaidl.VARIANT
  );
  VAR
    AL, AH : LONGINT;
    Destination : eib_def.CAddress;
    L : CARDINAL;
    Packet : eib_def.TPacket;
    P : eib_def.TPriority;
    PB : POINTER TO ARRAY [0..0] OF CARD8;
  BEGIN
    CASE Priority OF
    | falcon.PriorityLow : P := eib_def.priorityNormal;
    | falcon.PriorityHigh : P := eib_def.priorityHigh;
    | falcon.PriorityAlarm : P := eib_def.priorityAlarm;
    | falcon.PrioritySystem :  P := eib_def.prioritySystem;
    END;
    Destination.SetGroupAddress1( GroupAddress );
    IF Data.vt = wtypes.VT_EMPTY THEN
      L := 0;
    ELSIF CARDINAL( Data.vt AND wtypes.VT_ARRAY ) <> 0 THEN
      oleauto.SafeArrayAccessData( Data.parray, PB );
      oleauto.SafeArrayGetLBound( Data.parray, 1, AL );
      oleauto.SafeArrayGetUBound( Data.parray, 1, AH );
      Packet.FromDataArray( PB^, AH-AL+1 );
      oleauto.SafeArrayUnaccessData( Data.parray );
    END;

    (*%T DEBUG *)
    // vwthread.DbgOutSH( 'Group: ', LONGWORD( GroupAddress ));
    // vwthread.DbgOutSH( 'Length: ', LONGWORD( AH-AL+1 ));
    (*%E DEBUG *)

    Packet.SetValueDirection( Direction );
    Packet.SetDestinationAddress( Destination );
    Packet.SetPriority( P );
    Packet.SetRoutingCounter( RoutingCount );

    PTL^.T_Groupdata_Ind( Destination, P, ADR( Packet ));
  END GroupDataIndication;

BEGIN
  PTL := NIL;
END CGroupDataEvent;

(*================================================================================*)

CLASS IMPLEMENTATION CFalconTransportLayer;

(*--------------------------------------------------------------------------------*)

  VIRTUAL PROCEDURE T_Groupdata_Req(
          Destination : eib_def.TAddress; // cr_id
          Class       : eib_def.TPriority;
      VAR Packet      : eib_def.TPacket
  );
  VAR
    Data : oaidl.PSAFEARRAY;
    DataInACPI : wtypes.VARIANT_BOOL;
    L : CARDINAL;
    VA : oaidl.VARIANTARG;
    VD : oaidl.VARIANTARG;
    P : falcon.Priority;
    PB : POINTER TO ARRAY [0..0] OF CARD8;
    S : ARRAY [0..31] OF WCHAR;
    WE : falcon.DeviceWriteError;
  BEGIN
    IF NOT COMFlag THEN // try connect
      ConnectBUS();
    END;
    
    L := Packet.GetDataLength();
    IF L = 1 THEN
      DataInACPI := windows.True;
    ELSE
      DEC( L );
      DataInACPI := windows.False;
    END;

    Destination.GetGroupAddress3( TRUE, S );
    VA.vt := wtypes.VT_BSTR;
    VA.bstrVal := oleauto.SysAllocString( ADR( S ));

    CASE Packet.GetPriority() OF
    | eib_def.priorityNormal : P := falcon.PriorityLow;
    | eib_def.priorityHigh : P := falcon.PriorityHigh;
    | eib_def.priorityAlarm : P := falcon.PriorityAlarm;
    | eib_def.prioritySystem : P := falcon.PrioritySystem;
    END;

    Data := oleauto.SafeArrayCreateVector( wtypes.VARTYPE( wtypes.VT_UI1 ), 0, L );
    oleauto.SafeArrayAccessData( Data, PB );
    Packet.ToDataArray( PB^, L );
    oleauto.SafeArrayUnaccessData( Data );
    VD.vt := wtypes.VT_UI1 OR wtypes.VT_ARRAY;
    VD.parray := Data;
    
    CASE Packet.GetValueDirection() OF
    | eib_def.directionRead :
      PGroupData^.Read( VA, P, Packet.GetRoutingCounter(), WE );

    | eib_def.directionResponse :
      PGroupData^.SendReadResponse( VA, P, Packet.GetRoutingCounter(), DataInACPI, VD, WE );

    | eib_def.directionWrite :
      PGroupData^.Write( VA, P, Packet.GetRoutingCounter(), DataInACPI, VD, WE );

    // ELSE unknown and unsupported ACPI are ignored
    END; // CASE

    (*%T DEBUG *)
    // vwthread.DbgOutSH( 'WriteError: ', LONGWORD( WE ));
    (*%E DEBUG *)

    oleauto.VariantClear( ADR( VA ));
    oleauto.VariantClear( ADR( VD ));
  END T_Groupdata_Req;

(*--------------------------------------------------------------------------------*)

  PROCEDURE ConnectBUS() : eib_stack.TEIBStackStatus;
  LABEL
    Error;
  VAR
    BS : wtypes.BSTR;
    devOpenError : falcon.DeviceOpenError;
    HR : wtypes.HRESULT;
    PFactory : ocidl.TPIClassFactory2;
    V : oaidl.VARIANTARG;
  BEGIN
    IF COMFlag THEN
      RETURN eib_stack.essOK;
    END;
    COMFlag := TRUE;

    // main init
    HR := objbase.CoInitialize( NIL );
    IF HR <> 0 THEN
      GOTO Error;
    END;
    // PConnection & licence
    HR := objbase.CoGetClassObject( guiddef.GUID( falcon.CLSID_CommunicationObject ), objbase.CLSCTX_ALL, NIL, ocidl.IID_IClassFactory2, PFactory );
    IF HR <> 0 THEN
      GOTO Error;
    END;
    IF PKey^[0] = WCHAR( 0 ) THEN
      BS := oleauto.SysAllocString( L"Demo" );
    ELSE
      BS := oleauto.SysAllocString( PKey );
    END;
    HR := PFactory^.CreateInstanceLic( NIL, NIL, guiddef.GUID( falcon.IID_IConnectionCustom ), BS, PConnection );
    oleauto.SysFreeString( BS );
    PFactory^.Release();
    IF HR <> 0 THEN
      GOTO Error;
    END;
    // and use connectionless mode
    PConnection^.put_Mode( falcon.ConnectionModeRemoteConnectionless );
    // group transfer container
    HR := objbase.CoCreateInstance( guiddef.GUID( falcon.CLSID_GroupTransfer ), NIL, objbase.CLSCTX_ALL, guiddef.GUID( falcon.IID_IGroupDataTransfer ), PGroupData );
    IF HR <> 0 THEN
      GOTO Error;
    END;
    // ...open connection
    V.vt := wtypes.VT_BSTR;
    V.bstrVal := oleauto.SysAllocString( ADR( PFalconConnection^.wszParameters ));
    HR := PConnection^.Open2( PFalconConnection^.guidEdi, V, devOpenError );
    oleauto.VariantClear( ADR( V ));
    IF devOpenError <> falcon.DeviceOpenErrorNoError THEN
      GOTO Error;
    END;
    // and connect it with group transfer container
    PGroupData^.putref_Connection( PConnection );
    // initialize callbacks
    HR := PGroupData^.QueryInterface( ocidl.IID_IConnectionPointContainer, ADR( PCPContainer ));
    IF HR = 0 THEN
      HR := PCPContainer^.FindConnectionPoint( guiddef.GUID( falcon.IID_ICustomClientGroupDataEvent ), PCPoint );
    END;
    IF HR = 0 THEN
      HR := PCPoint^.Advise( unknwn.TPIUnknown( ADR( GroupDataEvent )), AdviseCookie );
    END;

    // DONE
    IF HR = 0 THEN
      PStack^.OnDeviceConnected();
      RETURN eib_stack.essOK;
    END;

    // error
  Error:
    IF AdviseCookie <> 0 THEN
      PCPoint^.Unadvise( AdviseCookie );
    END;
    IF PCPoint <> NIL THEN
      PCPoint^.Release();
      PCPoint := NIL;
    END;
    IF PCPContainer <> NIL THEN
      PCPContainer^.Release();
      PCPContainer := NIL;
    END;
    IF PGroupData <> NIL THEN
      PGroupData^.Release();
      PGroupData := NIL;
    END;
    IF PConnection <> NIL THEN
      PConnection^.Release();
      PConnection := NIL;
    END;

    PStack^.OnDeviceDisconnected();
    RETURN eib_stack.essNotConnected;
  END ConnectBUS;

(*--------------------------------------------------------------------------------*)

  PROCEDURE DisconnectBUS() : eib_stack.TEIBStackStatus;
  BEGIN
    IF NOT COMFlag THEN
      RETURN eib_stack.essNotConnected;
    END;
    COMFlag := FALSE;

    IF AdviseCookie <> 0 THEN
      PCPoint^.Unadvise( AdviseCookie );
      AdviseCookie := 0;
    END;
    IF PCPoint <> NIL THEN
      PCPoint^.Release();
      PCPoint := NIL;
    END;
    IF PCPContainer <> NIL THEN
      PCPContainer^.Release();
      PCPContainer := NIL;
    END;
    IF PGroupData <> NIL THEN
      PGroupData^.Release();
      PGroupData := NIL;
    END;
    IF PConnection <> NIL THEN
      PConnection^.Release();
      PConnection := NIL;
    END;

    objbase.CoUninitialize();

    PStack^.OnDeviceDisconnected();
    RETURN eib_stack.essNotConnected;
  END DisconnectBUS;

(*--------------------------------------------------------------------------------*)

BEGIN
  COMFlag := FALSE;
  Connection := bcUnknown;
  GroupDataEvent.AddRef();
  GroupDataEvent.PTL := ADR( SELF );
  PFalconConnection := NIL;
  PKey := NIL;
  PConnection := NIL;
  PGroupData := NIL;
  PCPContainer := NIL;
  PCPoint := NIL;
  AdviseCookie := 0;
END CFalconTransportLayer;

(*================================================================================*)

CLASS IMPLEMENTATION CFalconStack;

(*--------------------------------------------------------------------------------*)

  INTERNAL VIRTUAL PROCEDURE Initialize() : eib_stack.TEIBStackStatus;
  BEGIN
    RETURN SUPER.Initialize();
  END Initialize;

(*--------------------------------------------------------------------------------*)

  INTERNAL VIRTUAL PROCEDURE ConnectBUS() : eib_stack.TEIBStackStatus;
  BEGIN
    RETURN TPFalconTransportLayer( Layers[ eib_stack.eltTransport ] )^.ConnectBUS();
  END ConnectBUS;

(*--------------------------------------------------------------------------------*)

  INTERNAL VIRTUAL PROCEDURE DisconnectBUS() : eib_stack.TEIBStackStatus;
  BEGIN
    RETURN TPFalconTransportLayer( Layers[ eib_stack.eltTransport ] )^.DisconnectBUS();
  END DisconnectBUS;

(*--------------------------------------------------------------------------------*)

  INTERNAL VIRTUAL PROCEDURE CreateLayer( Layer : eib_stack.TEIBStackLayerType; VAR PLayer : eib_stack.TPEIBStackLayer ) : BOOLEAN;
  BEGIN
    IF Layer = eib_stack.eltTransport THEN
      NEW( TPFalconTransportLayer( PLayer ));
      TPFalconTransportLayer( PLayer )^.PFalconConnection := ADR( FalconConnection );
      TPFalconTransportLayer( PLayer )^.PKey := ADR( Key );
      RETURN TRUE;
    ELSE
      RETURN SUPER.CreateLayer( Layer, PLayer );
    END;
  END CreateLayer;

(*--------------------------------------------------------------------------------*)

  INTERNAL VIRTUAL PROCEDURE ValidateParameters( OUT ErrorText : ARRAY OF WCHAR ) : BOOLEAN;
  LABEL
    Error;
  VAR
    HR : wtypes.HRESULT;
    LC : ARRAY [0..63] OF WCHAR;
    PManager : falcon.TPIConnectionManager;
    V : oaidl.VARIANTARG;
  BEGIN
    HR := objbase.CoInitialize( NIL );

    HR := objbase.CoCreateInstance(
      guiddef.GUID( falcon.CLSID_ConnectionManager ),
      NIL,
      objbase.CLSCTX_ALL,
      guiddef.GUID( falcon.IID_IConnectionManager ),
      PManager
    );
    IF HR <> 0 THEN
      ASSIGN( ErrorText, L'Unable to create Falcon Connection Manager' );
      GOTO Error;
    END;

    ASSIGN( LC, Connection );
    LOW( LC );
    IF EQUALS( LC, L'default' ) THEN
      HR := PManager^.GetDefaultConnection( FalconConnection );
    ELSIF EQUALS( LC, L'select' ) THEN
      HR := PManager^.GetConnection( NIL, windows.True, FalconConnection );
    ELSE
      V.vt := wtypes.VT_BSTR;
      V.bstrVal := oleauto.SysAllocString( ADR( Connection ));
      HR := PManager^.Item( V, FalconConnection );
      oleauto.VariantClear( ADR( V ));
    END;
    IF HR <> 0 THEN
      ASSIGN( ErrorText, L'Falcon connection is unknown' );
    END;

    PManager^.Release();
  Error:
    objbase.CoUninitialize();
    RETURN HR = 0;
  END ValidateParameters;

(*--------------------------------------------------------------------------------*)

  PUBLIC VIRTUAL PROCEDURE DeviceConnected() : BOOLEAN;
  BEGIN
    RETURN TPFalconTransportLayer( Layers[ eib_stack.eltTransport ] )^.COMFlag;
  END DeviceConnected;

(*--------------------------------------------------------------------------------*)

  PUBLIC VIRTUAL PROCEDURE EIBConnected() : BOOLEAN;
  BEGIN
    RETURN DeviceConnected();
  END EIBConnected;

(*--------------------------------------------------------------------------------*)

BEGIN
  Connection[0] := WCHAR( 0 );
  Storage.Fill( ADR( FalconConnection ), SIZE( FalconConnection ), 0 );
  Key := L'';
END CFalconStack;

(*================================================================================*)

END falconStack.