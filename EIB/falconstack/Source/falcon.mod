IMPLEMENTATION MODULE falcon;

//===== IConnection
CLASS IMPLEMENTATION IConnectionCustom;

  VIRTUAL PROCEDURE Open( 
          EdiGuid      : guiddef.CLSID;
      VAR DevOpenError : DeviceOpenError
  ) : wtypes.HRESULT;
  BEGIN
    RETURN 0;
  END Open;
  
  VIRTUAL PROCEDURE Open2( 
          EdiGuid      : guiddef.CLSID;
          Parameters   : oaidl.VARIANT;
      VAR DevOpenError : DeviceOpenError
  ) : wtypes.HRESULT;
  BEGIN
    RETURN 0;
  END Open2;
  
  VIRTUAL PROCEDURE Write( 
          Msg : FalconMessage;
      VAR DevWriteError : DeviceWriteError
  ) : wtypes.HRESULT;
  BEGIN
    RETURN 0;
  END Write;
        
  VIRTUAL PROCEDURE (*/* [helpstring][propget][id]*/*) get_Mode( 
      VAR pVal : ConnectionMode
  ) : wtypes.HRESULT;
  BEGIN
    RETURN 0;
  END get_Mode;
  
  VIRTUAL PROCEDURE (*/* [helpstring][propput][id]*/*) put_Mode( 
          pVal : ConnectionMode
  ) : wtypes.HRESULT;
  BEGIN
    RETURN 0;
  END put_Mode;
  
  VIRTUAL PROCEDURE (*/* [helpstring][propget][id]*/*) get_TargetAddress( 
      VAR pVal : oaidl.VARIANT
  ) : wtypes.HRESULT;
  BEGIN
    RETURN 0;
  END get_TargetAddress;
  
  VIRTUAL PROCEDURE (*/* [helpstring][propput][id]*/*) put_TargetAddress( 
          pVal : oaidl.VARIANT
  ) : wtypes.HRESULT;
  BEGIN
    RETURN 0;
  END put_TargetAddress;
  
  VIRTUAL PROCEDURE (*/* [helpstring][propget][id]*/*) get_State( 
      VAR pVal : ConnectionState
  ) : wtypes.HRESULT;
  BEGIN
    RETURN 0;
  END get_State;
  
  VIRTUAL PROCEDURE (*/* [helpstring][propget][id]*/*) get_FirmwareDescriptor( 
      VAR pVal : INTEGER
  ) : wtypes.HRESULT;
  BEGIN
    RETURN 0;
  END get_FirmwareDescriptor;
  
  VIRTUAL PROCEDURE (*/* [helpstring][propget][id]*/*) get_FirmwareDescriptor2( 
      VAR pVal : INTEGER
  ) : wtypes.HRESULT;
  BEGIN
    RETURN 0;
  END get_FirmwareDescriptor2;
  
  VIRTUAL PROCEDURE (*/* [helpstring][propget][id]*/*) get_AccessKey( 
      VAR pVal : INTEGER
  ) : wtypes.HRESULT;
  BEGIN
    RETURN 0;
  END get_AccessKey;
  
  VIRTUAL PROCEDURE (*/* [helpstring][propput][id]*/*) put_AccessKey( 
      pVal : INTEGER
  ) : wtypes.HRESULT;
  BEGIN
    RETURN 0;
  END put_AccessKey;
  
  VIRTUAL PROCEDURE (*/* [helpstring][propget][id]*/*) get_EdiGuid( 
      VAR pVal : wtypes.BSTR
  ) : wtypes.HRESULT;
  BEGIN
    RETURN 0;
  END get_EdiGuid;
  
  VIRTUAL PROCEDURE RequestAsyncLifeTimeInfo() : wtypes.HRESULT;
  BEGIN
    RETURN 0;
  END RequestAsyncLifeTimeInfo;

BEGIN
END IConnectionCustom;

//===== IGroupDataTransfer
CLASS IMPLEMENTATION IGroupDataTransfer;

  VIRTUAL PROCEDURE (*/* [helpstring][propget][id]*/*) get_Connection( 
      VAR pVal : TPIConnectionCustom
  ) : wtypes.HRESULT;
  BEGIN
    RETURN 0;
  END get_Connection;
  
  VIRTUAL PROCEDURE (*/* [helpstring][propputref][id]*/*) putref_Connection( 
          pVal : TPIConnectionCustom
  ) : wtypes.HRESULT;
  BEGIN
    RETURN 0;
  END putref_Connection;
  
  VIRTUAL PROCEDURE Read( 
          GroupAddress : oaidl.VARIANT;
          Prio         : Priority;
          RoutingCnt   : INTEGER;
      VAR WriteError   : DeviceWriteError
  ) : wtypes.HRESULT;
  BEGIN
    RETURN 0;
  END Read;
  
  VIRTUAL PROCEDURE Write( 
          GroupAddress : oaidl.VARIANT;
          Prio         : Priority;
          RoutingCnt   : INTEGER;
          Less7Bits    : wtypes.VARIANT_BOOL;
          Data         : oaidl.VARIANT;
      VAR WriteError   : DeviceWriteError
  ) : wtypes.HRESULT;
  BEGIN
    RETURN 0;
  END Write;
  
  VIRTUAL PROCEDURE ReadSync( 
          GroupAddress : oaidl.VARIANT;
          Prio         : Priority;
          RoutingCnt   : INTEGER;
      VAR Data         : oaidl.VARIANT
  ) : wtypes.HRESULT;
  BEGIN
    RETURN 0;
  END ReadSync;
  
  VIRTUAL PROCEDURE SendReadResponse( 
          GroupAddress : oaidl.VARIANT;
          Prio         : Priority;
          RoutingCnt   : INTEGER;
          Less7Bits    : wtypes.VARIANT_BOOL;
          Data         : oaidl.VARIANT;
      VAR WriteError   : DeviceWriteError
  ) : wtypes.HRESULT;
  BEGIN
    RETURN 0;
  END SendReadResponse;

BEGIN  
END IGroupDataTransfer;
    
//===== ICustomClientGroupDataEvent
CLASS IMPLEMENTATION ICustomClientGroupDataEvent;

  VIRTUAL PROCEDURE GroupDataIndicationRead( 
      GroupAddress : INTEGER;
      RoutingCnt   : INTEGER;
      Prio         : Priority;
      Data         : oaidl.VARIANT
  ) : wtypes.HRESULT;
  BEGIN
    RETURN 0;
  END GroupDataIndicationRead;
  
  VIRTUAL PROCEDURE GroupDataIndicationWrite( 
      GroupAddress : INTEGER;
      RoutingCnt   : INTEGER;
      Prio         : Priority;
      Data         : oaidl.VARIANT
  ) : wtypes.HRESULT;
  BEGIN
    RETURN 0;
  END GroupDataIndicationWrite;
  
  VIRTUAL PROCEDURE GroupDataIndicationResponse( 
      GroupAddress : INTEGER;
      RoutingCnt   : INTEGER;
      Prio         : Priority;
      Data         : oaidl.VARIANT
  ) : wtypes.HRESULT;
  BEGIN
    RETURN 0;
  END GroupDataIndicationResponse;
  
  VIRTUAL PROCEDURE GroupDataConfirmationRead( 
      GroupAddress : INTEGER;
      RoutingCnt   : INTEGER;
      Prio         : Priority;
      Error        : wtypes.VARIANT_BOOL;
      Data         : oaidl.VARIANT
  ) : wtypes.HRESULT;
  BEGIN
    RETURN 0;
  END GroupDataConfirmationRead;
  
  VIRTUAL PROCEDURE GroupDataConfirmationWrite( 
      GroupAddress : INTEGER;
      RoutingCnt   : INTEGER;
      Prio         : Priority;
      Error        : wtypes.VARIANT_BOOL;
      Data         : oaidl.VARIANT
  ) : wtypes.HRESULT;
  BEGIN
    RETURN 0;
  END GroupDataConfirmationWrite;
  
  VIRTUAL PROCEDURE GroupDataConfirmationResponse( 
      GroupAddress : INTEGER;
      RoutingCnt   : INTEGER;
      Prio         : Priority;
      Error        : wtypes.VARIANT_BOOL;
      Data         : oaidl.VARIANT
  ) : wtypes.HRESULT;
  BEGIN
    RETURN 0;
  END GroupDataConfirmationResponse;
  
  VIRTUAL PROCEDURE Status( 
      MsgType : InternalMessageType;
      Data    : INTEGER
  ) : wtypes.HRESULT;
  BEGIN
    RETURN 0;
  END Status;

BEGIN
END ICustomClientGroupDataEvent;

END falcon.
