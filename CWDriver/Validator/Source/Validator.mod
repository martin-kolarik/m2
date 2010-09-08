IMPLEMENTATION MODULE Validator;

(*================================================================================*)
(*/* changes:

*/*)
(*================================================================================*)

FROM Storage IMPORT
  REALLOCATE, ALLOCATE, DEALLOCATE;

IMPORT
  datetime,
  FIO,
  FIOO,
  IOO,
  Languages,
  Strings,
  StringsO;

IMPORT
  drv_str,
  INIFile,
  lec,
  log,
  Resources,
  TextReader;

IMPORT
  Texts;

(*================================================================================*)

VAR
  GR : Resources.CResources;

(*--------------------------------------------------------------------------------*)

CONST // device specific error codes
  ecDeviceStopped = 10001H;

(*--------------------------------------------------------------------------------*)

CONST // driver channels
  chStatus = 1;

(*================================================================================*)

TYPE
  TRStatusItem = (
    rsRunning
  );
  TRStatus = SET OF TRStatusItem;

CONST
  rssUser = TRStatus{rsRunning};

(*--------------------------------------------------------------------------------*)

TYPE
  TPDriver = POINTER TO CDriver;

CLASS CDriver;
  RStatus : TRStatus;
  Name : ARRAY [0..63] OF WCHAR;

  CallbackId : ADDRESS;
  CallbackProc : drv_def.TDriverCallbackW;
  RunMode : CARDINAL;
  
  StoragePath : FIO.PathStrW;
  Result : lec.CResult;

  // binding to procedural interface
  PROCEDURE Init( RunMode : CARDINAL; VAR SymbolicName : ARRAY OF WCHAR; CallbackId : ADDRESS; PCallback : drv_def.TDriverCallbackW ) : BOOLEAN;
  PROCEDURE ReadParameters( VAR ParFilePath, ErrorMessage : ARRAY OF WCHAR; VAR ErrorLine, ErrorColumn : CARDINAL; VAR HintOrHelp : ARRAY OF WCHAR ) : BOOLEAN;
  PROCEDURE EnumerateChannels(  VAR EnumerateState : LONGWORD; VAR Type : CARDINAL; VAR Direction : CARDINAL; VAR DriverIndex : CARDINAL; VAR Count : CARDINAL; VAR HaveDescription : BOOLEAN ): BOOLEAN;

  PROCEDURE Run();
  PROCEDURE Stop();
  PROCEDURE Done();

  PROCEDURE QueryProc( UFlag : BOOLEAN; InValue1, InValue2 : drv_def.TValue; VAR OutValue : drv_def.TValue );

  PROCEDURE InputRequestStart();
  PROCEDURE InputRequest( DriverIndex : CARDINAL );
  PROCEDURE InputRequestCompleted();
  PROCEDURE InputFinalized( DriverIndex : CARDINAL; VAR ErrorCode : CARDINAL ) : BOOLEAN;
  PROCEDURE InputOOBDataQuery( VAR EnumerateState : LONGWORD; VAR DriverIndex : CARDINAL ) : BOOLEAN;
  PROCEDURE GetInput( UFlag : BOOLEAN; DriverIndex : CARDINAL; VAR InValue : drv_def.TValue; VAR QoS : CARDINAL; VAR TimeStamp : drv_def.TUTCStamp; VAR ErrorCode : CARDINAL );

  PROCEDURE OutputRequestStart();
  PROCEDURE OutputRequest( UFlag : BOOLEAN; DriverIndex : CARDINAL; OutValue : drv_def.TValue; QoS : CARDINAL; TimeStamp : drv_def.TUTCStamp );
  PROCEDURE OutputRequestCompleted();
  PROCEDURE OutputFinalized( DriverIndex : CARDINAL; VAR ErrorCode : CARDINAL ) : BOOLEAN;

  // helpers
  PROCEDURE InitToDefault();
END CDriver;

(*================================================================================*)

CLASS IMPLEMENTATION CDriver;

(*--------------------------------------------------------------------------------*)

  PROCEDURE Init( _RunMode : CARDINAL; VAR SymbolicName : ARRAY OF WCHAR; _CallbackId : ADDRESS; PCallback : drv_def.TDriverCallbackW ) : BOOLEAN;
  BEGIN
    CallbackId := _CallbackId;
    CallbackProc := PCallback;
    RunMode := _RunMode;
    ASSIGN( Name, SymbolicName );
    
    FIO.GetModuleDirW( EMITW( %dll ), OUT StoragePath );

    RETURN TRUE;
  END Init;

(*--------------------------------------------------------------------------------*)

  PROCEDURE ReadParameters( VAR ParFilePath, ErrorMessage : ARRAY OF WCHAR; VAR ErrorLine, ErrorColumn : CARDINAL; VAR HintOrHelp : ARRAY OF WCHAR ) : BOOLEAN;
  LABEL
    Fail;
  CONST
    // .PAR key names
    knDebugMode            = L'debug_mode';
      kvDebugNone          = L'none';
      kvDebugFile          = L'file';
      kvDebugKernel        = L'windows';
    knDebugFile            = L'debug_file';
    knDebugLevel           = L'debug_level';
      kvDebugBasic         = L'basic';
      kvDebugExtended      = L'extended';
      kvDebugAllProtocol   = L'protocol';
      kvDebugAll           = L'all';

  //----------

  VAR
    cs : StringsO.CString;
    DebugFile : FIO.PathStrW;
    DebugLevel : log.TDebugLevel;
    DebugMode : log.TDebugMethod;
    fs : FIOO.CFileStream;
    l : CARDINAL;
    s : ARRAY [0..127] OF WCHAR;
    TS : INIFile.CINIFile;
    tr : TextReader.CTextReader;
  BEGIN
    HintOrHelp[0] := WCHAR( 0 );

      TRY
         fs.FromPath( ParFilePath, FIOO.imOpenRead );
      CATCH : IOO.CIOException DO
         ASSIGN( ErrorMessage, OAsz( GR[ Texts._CannotOpenPar ] ));
         GOTO Fail;
      END; // TRY
      tr.Stream := ADR( fs );
      IF NOT TS.Load( tr ) THEN
         ASSIGN( ErrorMessage, OAsz( GR[ Texts._CannotOpenPar ] ));
         GOTO Fail;
      END;
      fs.Close( FALSE );

    InitToDefault();
    DebugMode := log.dmNone;
    DebugLevel := log.dl1;

    IF NOT TS.SetSection( OAsz( GR[ Texts._StringId ] )) THEN
      IF RunMode = drv_def.drmRun THEN
        ASSIGN( ErrorMessage, OAsz( GR[ Texts._MissingDeviceSection ] ));
        GOTO Fail;
      ELSE
        RETURN TRUE;
      END;
    END;

    IF TS.GetKeyStr( knDebugMode, OUT l, OUT cs ) THEN
      cs.ToOA( OUT s );

      IF EQUALS( s, kvDebugNone ) THEN
        DebugMode := log.dmNone;
      ELSIF EQUALS( s, kvDebugFile ) THEN
        DebugMode := log.dmFile;
        IF NOT TS.GetKeyStr( knDebugFile, OUT l, OUT cs ) THEN
          ASSIGN( ErrorMessage, OAsz( GR[ Texts._FileDebugMissingFile ] ));
          GOTO Fail;
        END;
         cs.ToOA( OUT DebugFile );
      ELSIF EQUALS( s, kvDebugKernel ) THEN
        DebugMode := log.dmKernel;
      END;
      IF DebugMode <> log.dmNone THEN
        IF TS.GetKeyStr( knDebugLevel, OUT l, OUT cs ) THEN
            cs.ToOA( OUT s );
          IF EQUALS( s, kvDebugBasic ) THEN
            DebugLevel := log.dlpIO;
          ELSIF EQUALS( s, kvDebugExtended ) THEN
            DebugLevel := log.dlpCtrl;
          ELSIF EQUALS( s, kvDebugAllProtocol ) THEN
            DebugLevel := log.dlpProtocol;
          ELSIF EQUALS( s, kvDebugAll ) THEN
            DebugLevel := log.dlpAll;
          END;
        END;
      END;
    END;

    IF RunMode = drv_def.drmRun THEN
    END;
    RETURN TRUE;

  Fail:
    RETURN FALSE;
  END ReadParameters;

(*--------------------------------------------------------------------------------*)

  PROCEDURE EnumerateChannels( VAR EnumerateState : LONGWORD; VAR Type : CARDINAL; VAR Direction : CARDINAL; VAR DriverIndex : CARDINAL; VAR Count : CARDINAL; VAR HaveDescription : BOOLEAN ): BOOLEAN;
  BEGIN
    CASE CARDINAL( EnumerateState ) OF
    | 0 :
      // status channel
      Direction := CARDINAL( {drv_def.dirInput} );
      DriverIndex := chStatus;
      Type := CARDINAL( drv_def.vtLongCard );
    ELSE
      RETURN FALSE;
    END;

    Count := 1;
    HaveDescription := FALSE;
    INC( EnumerateState );
    RETURN TRUE;
  END EnumerateChannels;

(*--------------------------------------------------------------------------------*)

  PROCEDURE Run();
  BEGIN
    IF TRStatus{rsRunning} * RStatus <> TRStatus{} THEN
      RETURN;
    END;
    INCL( RStatus, rsRunning );
  END Run;

(*--------------------------------------------------------------------------------*)

  PROCEDURE Stop();
  BEGIN
    IF TRStatus{rsRunning} * RStatus = TRStatus{} THEN
      RETURN;
    END;
    EXCL( RStatus, rsRunning );
  END Stop;

(*--------------------------------------------------------------------------------*)

  PROCEDURE Done();
  BEGIN
  END Done;

(*--------------------------------------------------------------------------------*)

  PROCEDURE QueryProc( UFlag : BOOLEAN; InValue1, InValue2 : drv_def.TValue; VAR OutValue : drv_def.TValue );
  LABEL
    Return;
  VAR
    c : CARDINAL;
    dt : datetime.DateTime;
    s : ARRAY [0..63] OF WCHAR;
    so : StringsO.CString;
    SW : ARRAY [0..1] OF StringsO.CString;
  BEGIN
    drv_def.DrvValueToCStringW( InValue1, UFlag, OUT so );
    so.SplitS( StringsO.WCHARS{ L' ' }, 0, TRUE, OUT c, OUT SW );
    IF c <> 2 THEN
      so.FromOA( OAsz( GR[ Texts._ExpectedCommandAndParameter ] ));
      GOTO Return;
    END;

    IF SW[0].EqualsOA( L'query' ) THEN
    
      Result.Reset( lec.bhBestCase );
      lec.Query( StoragePath, OA( SW[1].Length-1, SW[1].Data ), REF Result );
      
      CASE Result.Info OF
      | lec.siDemo :
         so.FromOA( L"demo:1800" );
      | lec.siNotActivated :
         so.FromOA( L"not activated:" );
      | lec.siActivated :
         so.FromOA( L"activated:" );
      END;
      
      IF Result.Info <> lec.siDemo THEN
         dt := Result.Expires;
         IF dt.Year = 0 THEN
            so.AppendOA( L"infinite:infinite" );
         ELSE
            SW[1].FromCARD32(( Result.NextCheck + 999 ) DIV 1000, 10 );
            so.Append( SW[1] );
            dt.ToStringOA, L":yyyy.MM.dd", TRUE, FALSE, s );
            so.AppendOA( s );
         END;
      END;

    ELSE
      so.FromOA( OAsz( GR[ Texts._UnrecognizedCommand ] ));
    END;

  Return:
    drv_def.AssignDrvValueCStringW( REF OutValue, UFlag, FALSE, so );
  END QueryProc;

(*--------------------------------------------------------------------------------*)

  PROCEDURE InputRequestStart();
  BEGIN
  END InputRequestStart;

(*--------------------------------------------------------------------------------*)

  PROCEDURE InputRequest( DriverIndex : CARDINAL );
  BEGIN
  END InputRequest;

(*--------------------------------------------------------------------------------*)

  PROCEDURE InputRequestCompleted();
  BEGIN
  END InputRequestCompleted;

(*--------------------------------------------------------------------------------*)

  PROCEDURE InputFinalized( DriverIndex : CARDINAL; VAR ErrorCode : CARDINAL ) : BOOLEAN;
  VAR
    Finalized : BOOLEAN;
  BEGIN
    Finalized := TRUE;
    ErrorCode := 0;
    IF DriverIndex = chStatus THEN
      // fall down
    ELSIF TRStatus{rsRunning} * RStatus = TRStatus{} THEN
      ErrorCode := ecDeviceStopped;
    ELSE
      // fall down
    END;
    RETURN Finalized;
  END InputFinalized;

(*--------------------------------------------------------------------------------*)

  PROCEDURE InputOOBDataQuery( VAR EnumerateState : LONGWORD; VAR DriverIndex : CARDINAL ) : BOOLEAN;
  BEGIN
    RETURN FALSE;
  END InputOOBDataQuery;

(*--------------------------------------------------------------------------------*)

  PROCEDURE GetInput( UFlag : BOOLEAN; DriverIndex : CARDINAL; VAR InValue : drv_def.TValue; VAR QoS : CARDINAL; VAR TimeStamp : drv_def.TUTCStamp; VAR ErrorCode : CARDINAL );
  BEGIN
    ErrorCode := drv_def.ecSuccess;
    QoS := drv_def.qosGood;

    CASE DriverIndex OF
    | chStatus :
      drv_def.AssignValueCardinal( InValue, TRUE, CARDINAL( RStatus * rssUser ));
    ELSE
      ////
    END; // CASE
  END GetInput;

(*--------------------------------------------------------------------------------*)

  PROCEDURE OutputRequestStart();
  BEGIN
  END OutputRequestStart;

(*--------------------------------------------------------------------------------*)

  PROCEDURE OutputRequest( UFlag : BOOLEAN; DriverIndex : CARDINAL; OutValue : drv_def.TValue; QoS : CARDINAL; TimeStamp : drv_def.TUTCStamp );
  BEGIN
  END OutputRequest;

(*--------------------------------------------------------------------------------*)

  PROCEDURE OutputRequestCompleted();
  BEGIN
  END OutputRequestCompleted;

(*--------------------------------------------------------------------------------*)

  PROCEDURE OutputFinalized( DriverIndex : CARDINAL; VAR ErrorCode : CARDINAL ) : BOOLEAN;
  BEGIN
    ErrorCode := 0;
    RETURN TRUE;
  END OutputFinalized;

(*--------------------------------------------------------------------------------*)

  PROCEDURE InitToDefault();
  BEGIN
  END InitToDefault;

(*--------------------------------------------------------------------------------*)

BEGIN
  RStatus := TRStatus{};
  RunMode := drv_def.drmEdit;
  Name := L"";
  StoragePath := L"";
  CallbackId := NIL;
  CallbackProc := NIL;
END CDriver;

(*================================================================================*)
// procedural interface

PROCEDURE VersionW() : CARDINAL;
BEGIN
  RETURN 030000H;
END VersionW;

PROCEDURE GetDriverInfo( VAR DriverName : ARRAY OF CHAR );
BEGIN
  Strings.ToA( OAsz( GR[ Texts._DriverName ] ), 0, OUT DriverName );
END GetDriverInfo;

PROCEDURE GetDriverInfoW( VAR DriverNameW : ARRAY OF WCHAR );
BEGIN
  ASSIGN( DriverNameW, OAsz( GR[ Texts._DriverName ] ));
END GetDriverInfoW;

(*--------------------------------------------------------------------------------*)

PROCEDURE Check( VAR ErrorString : ARRAY OF CHAR; CWVersion, MajorVersion, MinorVersion, APIMajorVersion, APIMinorVersion : CARDINAL ): BOOLEAN;
VAR
  es : ARRAY [0..255] OF WCHAR;
  b : BOOLEAN;
BEGIN
  b := CheckW( es, CWVersion, MajorVersion, MinorVersion, APIMajorVersion, APIMinorVersion );
  Strings.ToA( es, 0, OUT ErrorString );
  RETURN b;
END Check;

PROCEDURE CheckW( VAR ErrorString : ARRAY OF WCHAR; CWVersion, MajorVersion, MinorVersion, APIMajorVersion, APIMinorVersion : CARDINAL ): BOOLEAN;
BEGIN
  RETURN TRUE;
END CheckW;

(*--------------------------------------------------------------------------------*)

PROCEDURE MakeDriverW() : ADDRESS;
VAR
  PDriver : TPDriver;
BEGIN
  NEW( PDriver );
  RETURN PDriver;
END MakeDriverW;

PROCEDURE DisposeDriverW( PData : ADDRESS );
BEGIN
  DISPOSE( TPDriver( PData ));
END DisposeDriverW;

(*--------------------------------------------------------------------------------*)

PROCEDURE InitCommon(    PData        : ADDRESS;
                         RunMode      : CARDINAL;
                     VAR SymbolicName : ARRAY OF WCHAR;
                         CallbackId   : ADDRESS;
                         PCallback    : drv_def.TDriverCallbackW;
                     VAR ErrorString  : ARRAY OF WCHAR ) : BOOLEAN;
BEGIN
  RETURN TPDriver( PData )^.Init( RunMode, SymbolicName, CallbackId, PCallback );
END InitCommon;

PROCEDURE Init(      PData        : ADDRESS;
                 VAR ParFilePath  : ARRAY OF CHAR;
                 VAR ErrorMessage : ARRAY OF CHAR;
                     UserLevel    : CARDINAL;
                     RunFlag      : BOOLEAN;
                     CallbackId   : ADDRESS;
                     PCallback    : drv_def.TDriverCallbackW ) : BOOLEAN;
VAR
  ec, el  : CARDINAL;
  em : ARRAY [0..255] OF WCHAR;
  hoh : ARRAY [0..3] OF CHAR;
  RunMode : CARDINAL;
  s : ARRAY [0..15] OF WCHAR;
BEGIN
  IF RunFlag THEN
    RunMode := drv_def.drmRun;
  ELSE
    RunMode := drv_def.drmEdit;
  END;
  ErrorMessage[0] := CHAR( 0 );
  ASSIGN( s, OAsz( GR[ Texts._StringId ] ));
  IF InitCommon( PData, RunMode, s, CallbackId, drv_def.TDriverCallbackW( PCallback ), em ) THEN
    IF NOT ReadParameters( PData, ParFilePath, ErrorMessage, el, ec, hoh ) THEN
      RETURN FALSE;
    END;
    RunW( PData );
  ELSIF em[0] = WCHAR( 0 ) THEN
    Strings.ToA( OAsz( GR[ Texts._InitError ] ), 0, OUT ErrorMessage );
    RETURN FALSE;
  ELSE
    Strings.ToA( em, 0, OUT ErrorMessage );
    RETURN FALSE;
  END;
  RETURN TRUE;
END Init;

PROCEDURE Init3(     PData        : ADDRESS;
                     RunMode      : CARDINAL;
                 VAR SymbolicName : ARRAY OF CHAR;
                     CallbackId   : ADDRESS;
                     PCallback    : drv_def.TDriverCallbackW ) : BOOLEAN;
VAR
  ES : ARRAY [0..3] OF WCHAR;
  sn : ARRAY [0..255] OF WCHAR;
BEGIN
  Strings.ToW( SymbolicName, 0, OUT sn );
  RETURN InitCommon( PData, RunMode, sn, CallbackId, PCallback, ES );
END Init3;

PROCEDURE InitW(     PData        : ADDRESS;
                 VAR ParFilePath  : ARRAY OF WCHAR;
                 VAR ErrorMessage : ARRAY OF WCHAR;
                     UserLevel    : CARDINAL;
                     RunFlag      : BOOLEAN;
                     CallbackId   : ADDRESS;
                     PCallback    : drv_def.TDriverCallbackW ) : BOOLEAN;
VAR
  ec, el  : CARDINAL;
  hoh     : ARRAY [0..3] OF WCHAR;
  RunMode : CARDINAL;
BEGIN
  IF RunFlag THEN
    RunMode := drv_def.drmRun;
  ELSE
    RunMode := drv_def.drmEdit;
  END;
  ErrorMessage[0] := WCHAR( 0 );
  IF InitCommon( PData, RunMode, hoh, CallbackId, PCallback, ErrorMessage ) THEN
    IF NOT ReadParametersW( PData, ParFilePath, ErrorMessage, el, ec, hoh ) THEN
      RETURN FALSE;
    END;
    RunW( PData );
  ELSIF ErrorMessage[0] = WCHAR( 0 ) THEN
    ASSIGN( ErrorMessage, OAsz( GR[ Texts._InitError ] ));
    RETURN FALSE;
  ELSE
    RETURN FALSE;
  END;
  RETURN TRUE;
END InitW;

PROCEDURE Init3W(    PData        : ADDRESS;
                     RunMode      : CARDINAL;
                 VAR SymbolicName : ARRAY OF WCHAR;
                     CallbackId   : ADDRESS;
                     PCallback    : drv_def.TDriverCallbackW ) : BOOLEAN;
VAR
  ES : ARRAY [0..3] OF WCHAR;
BEGIN
  RETURN InitCommon( PData, RunMode, SymbolicName, CallbackId, PCallback, ES );
END Init3W;

(*--------------------------------------------------------------------------------*)

PROCEDURE ReadParameters(             PData : ADDRESS;
                           VAR ParFilePath  : ARRAY OF CHAR;
                           VAR ErrorMessage : ARRAY OF CHAR;
                           VAR ErrorLine    : CARDINAL;
                           VAR ErrorColumn  : CARDINAL;
                           VAR HintOrHelp   : ARRAY OF CHAR ) : BOOLEAN;
VAR
  pf, em, hoh : ARRAY [0..287] OF WCHAR;
  b : BOOLEAN;
BEGIN
  Strings.ToW( ParFilePath, 0, OUT pf );
  b := TPDriver( PData )^.ReadParameters( pf, em, ErrorLine, ErrorColumn, hoh );
  Strings.ToA( em, 0, OUT ErrorMessage );
  Strings.ToA( hoh, 0, OUT HintOrHelp );
  RETURN b;
END ReadParameters;

PROCEDURE ReadParametersW(            PData : ADDRESS;
                           VAR ParFilePath  : ARRAY OF WCHAR;
                           VAR ErrorMessage : ARRAY OF WCHAR;
                           VAR ErrorLine    : CARDINAL;
                           VAR ErrorColumn  : CARDINAL;
                           VAR HintOrHelp   : ARRAY OF WCHAR ) : BOOLEAN;
BEGIN
  RETURN TPDriver( PData )^.ReadParameters( ParFilePath, ErrorMessage, ErrorLine, ErrorColumn, HintOrHelp );
END ReadParametersW;

PROCEDURE EnumerateChannelsW( PData : ADDRESS;
                              VAR EnumerateState : LONGWORD;
                              VAR Type : CARDINAL;
                              VAR Direction : CARDINAL;
                              VAR DriverIndex : CARDINAL;
                              VAR Count : CARDINAL;
                              VAR HaveDescription : BOOLEAN
                            ): BOOLEAN;
BEGIN
  RETURN TPDriver( PData )^.EnumerateChannels( EnumerateState, Type, Direction, DriverIndex, Count, HaveDescription );
END EnumerateChannelsW;

(*--------------------------------------------------------------------------------*)

PROCEDURE QueryErrorCode(          PData : ADDRESS;
                               ErrorCode : CARDINAL;
                           VAR ErrorText : ARRAY OF CHAR ) : BOOLEAN;
VAR
  et : ARRAY [0..255] OF WCHAR;
  b : BOOLEAN;
BEGIN
  b := QueryErrorCodeW( PData, ErrorCode, et );
  Strings.ToA( et, 0, OUT ErrorText );
  RETURN b;
END QueryErrorCode;

PROCEDURE QueryErrorCodeW(         PData : ADDRESS;
                               ErrorCode : CARDINAL;
                           VAR ErrorText : ARRAY OF WCHAR ) : BOOLEAN;
BEGIN
  CASE ErrorCode OF
  | ecDeviceStopped :
    ASSIGN( ErrorText, OAsz( GR[ Texts._E_DeviceStopped ] ));
  ////
  ELSE
    RETURN FALSE;
  END;
  RETURN TRUE;
END QueryErrorCodeW;

(*--------------------------------------------------------------------------------*)

PROCEDURE BufferInfoW( PData : ADDRESS; DriverIndex : CARDINAL; BType : CARD8; BLen : CARDINAL ) : BOOLEAN;
BEGIN
  RETURN FALSE;
END BufferInfoW;

PROCEDURE SetBufferAddrW( PData : ADDRESS; DriverIndex : CARDINAL; PBuffer : ADDRESS );
BEGIN
END SetBufferAddrW;

(*--------------------------------------------------------------------------------*)

PROCEDURE RunW( PData : ADDRESS );
BEGIN
  TPDriver( PData )^.Run();
END RunW;

PROCEDURE StopW( PData : ADDRESS );
BEGIN
  TPDriver( PData )^.Stop();
END StopW;

PROCEDURE DoneW( PData : ADDRESS );
BEGIN
  TPDriver( PData )^.Done();
END DoneW;

(*--------------------------------------------------------------------------------*)

PROCEDURE DriverProcW( PData : ADDRESS; Func, Param1, Param2, Param3, Param4 : CARDINAL );
BEGIN
END DriverProcW;

(*--------------------------------------------------------------------------------*)

PROCEDURE QueryProc( PData : ADDRESS; InValue : drv_def.TValue; VAR OutValue : drv_def.TValue );
BEGIN
  QueryProc3( PData, InValue, OutValue, OutValue );
END QueryProc;

PROCEDURE QueryProcW( PData : ADDRESS; InValue : drv_def.TValue; VAR OutValue : drv_def.TValue );
BEGIN
  QueryProc3W( PData, InValue, OutValue, OutValue );
END QueryProcW;

PROCEDURE QueryProc3( PData : ADDRESS; InValue1, InValue2 : drv_def.TValue; VAR OutValue : drv_def.TValue );
BEGIN
  TPDriver( PData )^.QueryProc( FALSE, InValue1, InValue2, OutValue );
END QueryProc3;

PROCEDURE QueryProc3W( PData : ADDRESS; InValue1, InValue2 : drv_def.TValue; VAR OutValue : drv_def.TValue );
BEGIN
  TPDriver( PData )^.QueryProc( TRUE, InValue1, InValue2, OutValue );
END QueryProc3W;

(*--------------------------------------------------------------------------------*)

PROCEDURE InputRequestStartW( PData : ADDRESS );
BEGIN
  TPDriver( PData )^.InputRequestStart();
END InputRequestStartW;

PROCEDURE InputRequestW( PData : ADDRESS; DriverIndex : CARDINAL );
BEGIN
  TPDriver( PData )^.InputRequest( DriverIndex );
END InputRequestW;

PROCEDURE InputRequestCompletedW( PData : ADDRESS );
BEGIN
  TPDriver( PData )^.InputRequestCompleted();
END InputRequestCompletedW;

PROCEDURE InputFinalizedW( PData : ADDRESS; DriverIndex : CARDINAL; VAR ErrorCode : CARDINAL ) : BOOLEAN;
BEGIN
  RETURN TPDriver( PData )^.InputFinalized( DriverIndex, ErrorCode );
END InputFinalizedW;

PROCEDURE InputOOBDataQueryW( PData : ADDRESS; VAR EnumerateState : LONGWORD; VAR DriverIndex : CARDINAL ) : BOOLEAN;
BEGIN
  RETURN TPDriver( PData )^.InputOOBDataQuery( EnumerateState, DriverIndex );
END InputOOBDataQueryW;

(*--------------------------------------------------------------------------------*)

PROCEDURE GetInput( PData : ADDRESS; DriverIndex : CARDINAL; VAR InValue : drv_def.TValue );
VAR
  ec : CARDINAL;
  QoS : CARDINAL;
  ts : drv_def.TUTCStamp;
BEGIN
  GetInput3( PData, DriverIndex, InValue, QoS, ts, ec );
END GetInput;

PROCEDURE GetInput3( PData : ADDRESS; DriverIndex : CARDINAL; VAR InValue : drv_def.TValue; VAR QoS : CARDINAL; VAR TimeStamp : drv_def.TUTCStamp; VAR ErrorCode : CARDINAL );
BEGIN
  TPDriver( PData )^.GetInput( FALSE, DriverIndex, InValue, QoS, TimeStamp, ErrorCode );
END GetInput3;

PROCEDURE GetInputW( PData : ADDRESS; DriverIndex : CARDINAL; VAR InValue : drv_def.TValue );
VAR
  ec : CARDINAL;
  QoS : CARDINAL;
  ts : drv_def.TUTCStamp;
BEGIN
  GetInput3W( PData, DriverIndex, InValue, QoS, ts, ec );
END GetInputW;

PROCEDURE GetInput3W( PData : ADDRESS; DriverIndex : CARDINAL; VAR InValue : drv_def.TValue; VAR QoS : CARDINAL; VAR TimeStamp : drv_def.TUTCStamp; VAR ErrorCode : CARDINAL );
BEGIN
  TPDriver( PData )^.GetInput( TRUE, DriverIndex, InValue, QoS, TimeStamp, ErrorCode );
END GetInput3W;

(*--------------------------------------------------------------------------------*)

PROCEDURE OutputRequestStartW( PData : ADDRESS );
BEGIN
  TPDriver( PData )^.OutputRequestStart();
END OutputRequestStartW;

PROCEDURE OutputRequest( PData : ADDRESS; DriverIndex : CARDINAL; OutValue : drv_def.TValue );
VAR
  ts : drv_def.TUTCStamp;
BEGIN
  OutputRequest3( PData, DriverIndex, OutValue, drv_def.qosGood, ts );
END OutputRequest;

PROCEDURE OutputRequest3( PData : ADDRESS; DriverIndex : CARDINAL; OutValue : drv_def.TValue; QoS : CARDINAL; VAR TimeStamp : drv_def.TUTCStamp );
BEGIN
  TPDriver( PData )^.OutputRequest( FALSE, DriverIndex, OutValue, QoS, TimeStamp );
END OutputRequest3;

PROCEDURE OutputRequestW( PData : ADDRESS; DriverIndex : CARDINAL; OutValue : drv_def.TValue );
VAR
  ts : drv_def.TUTCStamp;
BEGIN
  OutputRequest3W( PData, DriverIndex, OutValue, drv_def.qosGood, ts );
END OutputRequestW;

PROCEDURE OutputRequest3W( PData : ADDRESS; DriverIndex : CARDINAL; OutValue : drv_def.TValue; QoS : CARDINAL; VAR TimeStamp : drv_def.TUTCStamp );
BEGIN
  TPDriver( PData )^.OutputRequest( TRUE, DriverIndex, OutValue, QoS, TimeStamp );
END OutputRequest3W;

PROCEDURE OutputRequestCompletedW( PData : ADDRESS );
BEGIN
  TPDriver( PData )^.OutputRequestCompleted();
END OutputRequestCompletedW;

PROCEDURE OutputFinalizedW( PData : ADDRESS; DriverIndex : CARDINAL; VAR ErrorCode : CARDINAL ) : BOOLEAN;
BEGIN
  RETURN TPDriver( PData )^.OutputFinalized( DriverIndex, ErrorCode );
END OutputFinalizedW;

(*================================================================================*)

CLASS Cinit;
END Cinit;

CLASS IMPLEMENTATION Cinit;
BEGIN
  // global resources
  GR.LoadRES2( EMITW( %dll ), L'Validator.Texts' );
  GR.Lang := Languages.GetDefaultLanguage( Languages.dlUser );
END Cinit;

VAR
   Vinit : Cinit;

(*================================================================================*)

END Validator.