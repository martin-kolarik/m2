IMPLEMENTATION MODULE PelcoD;

(*# call( o_a_copy => off ) *)

//================================================================================
(*/* changes:


19.09.2004 -- V1.1, build

FA 06-03 / 20 / 4 / 24

*/*)
//================================================================================

FROM Storage IMPORT
  REALLOCATE, ALLOCATE, DEALLOCATE;

IMPORT
  windows,
  winerror,
  wtypes;

IMPORT
  FIO,
  Strings;

IMPORT
  drv_str,
  lists,
  INIFile;

IMPORT
  Texts,
  serial;

//================================================================================

CONST
  WM_COMMUNICATE = windows.WM_USER + 1;

CONST
  ecSuccess      = winerror.ERROR_SUCCESS;
  ecFirst        = serial.ecLast + 1;

//================================================================================

CONST // device specific error codes
  ceRxTimeout               = drv_def.ecCommunicationTimeout;
  ceChkSumError             = drv_def.ecCheckSumError;
  ceDeviceStopped           = 10001H;
  ceBadInput                = 10002H;

//================================================================================

CONST // driver channels
  chStatus = 1;

//================================================================================

TYPE
  TPDriver = POINTER TO CDriver;

  TRStatusItem  = (
    rsSerialInitialized,
    rsRunning,

    rsWaitACK,
    rsWaitResponse,
    rsHaveData
  );
  TRStatus = SET OF TRStatusItem;

CONST
  rssPending = TRStatus{rsWaitACK, rsWaitResponse};
  rssUser    = TRStatus{rsSerialInitialized, rsRunning};

//--------------------------------------------------------------------------------

CLASS CSerial( serial.CSerialHandler );
  PDriver : TPDriver;
  
  VIRTUAL PROCEDURE DataComplete( Data : vdstr.TPDStringA; VAR FirstIndexAfterData, FirstIndexAfterFrame : CARDINAL; VAR ApplyCheckSum : BOOLEAN ) : BOOLEAN;

  VIRTUAL PROCEDURE OnRxA( Data : vdstr.TPDStringA; ErrorCode : CARDINAL );
  VIRTUAL PROCEDURE OnTx( ErrorCode : CARDINAL );

  VIRTUAL PROCEDURE AddChkSum( VAR Data : vdstr.TPDStringA );
  VIRTUAL PROCEDURE TestChkSum( Data : vdstr.TPDStringA ) : CARDINAL; // success, ecChkSumFailure

  PROCEDURE ComputeChkSum( A : ADDRESS; L : CARDINAL ) : CARD8;
END CSerial;

//--------------------------------------------------------------------------------

TYPE
  TChannel = (
    ch, // chUnknown
    chSwitch,
    chPresetSet, chPresetReset, chPresetGoto,
    chPanSet, chPanGet,
    chTiltSet, chTiltGet,
    // chZoomSet, chZoomGet,
    chMagnificationSet, chMagnificationGet,
    chZeroSet,
    chAuxSet, chAuxReset,
    chAFocusSwitch,
    chAIrisSwitch,
    chId
  );

  (*# save, option( pack => 1 ) *)
  TFrame  = RECORD
              Address : CARD8;
              CASE : CARDINAL OF
              | 0 : // request
                Cmd1      : CARD8;
                Cmd2      : CARD8;
                Data1     : CARD8;
                Data2     : CARD8;
              | 1 : // general response
                Alarm     : CARD8;
              | 2 : // query response
                IdS       : ARRAY [0..14] OF CHAR;
              | 3 : // extended response
                FutureUse : CARD8;
                RCmd1     : CARD8;
                RData1    : CARD8;
                RData2    : CARD8; 
              END;
            END;
  (*# restore *)
  TPFrame = POINTER TO TFrame;
  TIOItem = RECORD
              ChOfs     : CARD8;
              ChType    : drv_det.TValueType;
              ChDir     : drv_def.TDirectionItem;
              OutFrame  : TFrame;
              Expect    : CARD8;
              ExpectLen : CARDINAL;
            END;
  TIOs    = ARRAY TChannel OF TIOItem;

  TCommunicationStatusItem = (
    csPending1,
    csPending2,
    csTimeout,
    csBadInput
  );
  TCommunicationStatus = SET OF TCommunicationStatusItem;
  TChannelData  = RECORD
                    CS : TCommunicationStatus;
                    CASE : CARDINAL OF
                    | 0 : VC       : CARDINAL;
                    | 1 : VR       : LONGREAL;
                    | 2 : VB       : BOOLEAN;
                    | 3 : VS       : vdstr.TPDStringW;
                    END;
                  END;
  TPChannel     = POINTER TO TChannelData;
  TChannels     = ARRAY TChannel OF TChannelData;

  TCamera  = RECORD
               Present  : BOOLEAN;
               Channels : TChannels;
             END;
  TPCamera = POINTER TO TCamera;
  TCameras = ARRAY [0..255] OF TCamera;

  TNum2Channel = ARRAY [0..99] OF TChannel;

//--------------------------------------------------------------------------------

CONST
  n2ch = TNum2Channel(
    // 00--09
    chSwitch, chPresetGoto, chPresetSet, chPresetReset, ch, ch, ch, ch, ch, ch,
    // 10--19
    chPanSet, chTiltSet, chMagnificationSet, chZeroSet, ch, ch, ch, ch, ch, ch,
    // 20--29
    chPanGet, chTiltGet, chMagnificationGet, ch, ch, ch, ch, ch, ch, ch,
    // 30--39
    ch, ch, ch, ch, ch, ch, ch, ch, ch, ch,
    // 40--49
    ch, ch, ch, ch, ch, ch, ch, ch, ch, ch,
    // 50--59
    ch, ch, ch, ch, ch, ch, ch, ch, ch, ch,
    // 60--69
    ch, ch, ch, ch, ch, ch, ch, ch, ch, ch,
    // 70--79
    ch, ch, ch, ch, ch, ch, ch, ch, ch, ch,
    // 80--89
    chAuxSet, chAuxReset, ch, ch, ch, ch, ch, ch, ch, ch,
    // 90--99
    chAFocusSwitch, chAIrisSwitch, ch, ch, ch, ch, ch, ch, ch, chId
  );

  IOs = TIOs(
    TIOItem( 00, drv_def.vtNothing,   drv_def.dirInput,  TFrame( 0, 0, 000H, 000H, 000H, 000H ), 000H, 004H ), // ch
    TIOItem( 00, drv_def.vtBoolean,   drv_def.dirOutput, TFrame( 0, 0, 000H, 000H, 000H, 000H ), 000H, 004H ), // chSwitch
    TIOItem( 02, drv_def.vtShortCard, drv_def.dirOutput, TFrame( 0, 0, 000H, 003H, 000H, 000H ), 000H, 004H ), // chPresetSet
    TIOItem( 03, drv_def.vtShortCard, drv_def.dirOutput, TFrame( 0, 0, 000H, 005H, 000H, 000H ), 000H, 004H ), // chPresetReset
    TIOItem( 01, drv_def.vtShortCard, drv_def.dirOutput, TFrame( 0, 0, 000H, 007H, 000H, 000H ), 000H, 004H ), // chPresetGoto
    TIOItem( 10, drv_def.vtLongReal,  drv_def.dirOutput, TFrame( 0, 0, 000H, 04BH, 000H, 000H ), 000H, 004H ), // chPanSet
    TIOItem( 20, drv_def.vtLongReal,  drv_def.dirInput,  TFrame( 0, 0, 000H, 051H, 000H, 000H ), 059H, 007H ), // chPanGet
    TIOItem( 11, drv_def.vtLongReal,  drv_def.dirOutput, TFrame( 0, 0, 000H, 04DH, 000H, 000H ), 000H, 004H ), // chTiltSet
    TIOItem( 21, drv_def.vtLongReal,  drv_def.dirInput,  TFrame( 0, 0, 000H, 053H, 000H, 000H ), 05BH, 007H ), // chTiltGet
    // TIOItem( 12, drv_def.vtLongReal,  drv_def.dirOutput, TFrame( 0, 0, 000H, 04FH, 000H, 000H ), 000H, 004H ), // chZoomSet
    // TIOItem( 22, drv_def.vtLongReal,  drv_def.dirInput,  TFrame( 0, 0, 000H, 055H, 000H, 000H ), 05DH, 007H ), // chZoomGet
    TIOItem( 12, drv_def.vtLongReal,  drv_def.dirOutput, TFrame( 0, 0, 000H, 05FH, 000H, 000H ), 000H, 004H ), // chMagnificationSet
    TIOItem( 22, drv_def.vtLongReal,  drv_def.dirInput,  TFrame( 0, 0, 000H, 061H, 000H, 000H ), 063H, 007H ), // chMagnificationGet
    TIOItem( 13, drv_def.vtBoolean,   drv_def.dirOutput, TFrame( 0, 0, 000H, 049H, 000H, 000H ), 000H, 004H ), // chZeroSet
    TIOItem( 80, drv_def.vtShortCard, drv_def.dirOutput, TFrame( 0, 0, 000H, 009H, 000H, 000H ), 000H, 004H ), // chAuxSet
    TIOItem( 81, drv_def.vtShortCard, drv_def.dirOutput, TFrame( 0, 0, 000H, 00BH, 000H, 000H ), 000H, 004H ), // chAuxReset
    TIOItem( 90, drv_def.vtShortCard, drv_def.dirOutput, TFrame( 0, 0, 000H, 02BH, 000H, 000H ), 000H, 004H ), // chAFocusSwitch
    TIOItem( 91, drv_def.vtShortCard, drv_def.dirOutput, TFrame( 0, 0, 000H, 02DH, 000H, 000H ), 000H, 004H ), // chAIrisSwitch
    TIOItem( 99, drv_def.vtDString,   drv_def.dirInput,  TFrame( 0, 0, 000H, 045H, 000H, 000H ), 001H, 012H )  // chId
  );

//--------------------------------------------------------------------------------

TYPE
  TPRequest = POINTER TO CRequest;

CLASS CRequest( vlist.CListElem );
  Pending   : BOOLEAN;
  Camera    : CARDINAL;
  Channel   : TChannel;
  DeviceCmd : vdstr.TPDStringA;
  PROCEDURE Done();
END CRequest;

//--------------------------------------------------------------------------------

CLASS CDriver( vwthread.CMessageHandler );
  RStatus                  : TRStatus;
  Name                     : ARRAY [0..63] OF WCHAR;

  CallbackId               : ADDRESS;
  CallbackProc             : drv_def.TDriverCallbackW;
  RunMode                  : CARDINAL;

  // driver data
  Serial                   : CSerial;
  Requests                 : vlist_ex.CSynchronizedList;
  RxTimeout                : CARDINAL;

  // channels and presence
  Cameras                  : TCameras;
  NCameras                 : CARDINAL;

  // inherited
  VIRTUAL PROCEDURE ReceiveMsg(     Message : CARDINAL;
                                    wParam  : windows.WPARAM;
                                    lParam  : windows.LPARAM;
                                VAR lResult : windows.LRESULT ) : BOOLEAN;

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

  // callbacks
  PROCEDURE OnReceive( Data : vdstr.TPDStringA; ErrorCode : CARDINAL );
  PROCEDURE OnSend( ErrorCode : CARDINAL );

  // data
  PROCEDURE AddRequest( DriverIndex : CARDINAL ) : CARDINAL;
  PROCEDURE Communicate() : CARDINAL;
  // PROCEDURE ParseData( PData : TPInFrame; L :  CARDINAL );

  // helpers
  PROCEDURE InitToDefault();
  PROCEDURE Result2DriverError( Result : CARDINAL ) : CARDINAL;
  PROCEDURE ValidIndex( Input : BOOLEAN; DriverIndex : CARDINAL ) : BOOLEAN;
END CDriver;

//================================================================================

CLASS IMPLEMENTATION CSerial;

//--------------------------------------------------------------------------------

  VIRTUAL PROCEDURE DataComplete( Data : vdstr.TPDStringA; VAR FirstIndexAfterData, FirstIndexAfterFrame : CARDINAL; VAR ApplyCheckSum : BOOLEAN ) : BOOLEAN;
  VAR
    A : ADDRESS;
    FP : TPRequest;
    L : CARDINAL;
  BEGIN
    IF NOT PDriver^.Requests.GetFirst( FP ) OR NOT FP^.Pending THEN
      ApplyCheckSum := FALSE;
      FirstIndexAfterData := Data^.Len;
      FirstIndexAfterFrame := Data^.Len;
      RETURN TRUE;
    END;

    vdstr.GetDStrAddrLen( Data, A, L );
    IF L < IOs[FP^.Channel].ExpectLen THEN
      RETURN FALSE;
    END;

    ApplyCheckSum := TRUE;
    FirstIndexAfterFrame := IOs[FP^.Channel].ExpectLen;
    FirstIndexAfterData := FirstIndexAfterFrame - 1;
    RETURN TRUE;
  END DataComplete;

//--------------------------------------------------------------------------------

  VIRTUAL PROCEDURE OnRxA( Data : vdstr.TPDStringA; ErrorCode : CARDINAL );
  BEGIN
    PDriver^.OnReceive( Data, ErrorCode );
  END OnRxA;

//--------------------------------------------------------------------------------

  VIRTUAL PROCEDURE OnTx( ErrorCode : CARDINAL );
  BEGIN
    PDriver^.OnSend( ErrorCode );
  END OnTx;

//--------------------------------------------------------------------------------

  VIRTUAL PROCEDURE AddChkSum( VAR Data : vdstr.TPDStringA );
  TYPE
    TPC8 = POINTER TO CARD8;
  VAR
    A : ADDRESS;
    CRC : CARD8;
    L : CARDINAL;
  BEGIN
    vdstr.GetDStrAddrLenA( Data, A, L );
    CRC := ComputeChkSum( ADDRESS( CARDINAL( A ) + 1 ), L - 1 );
    vdstr.EnsureDStrLenA( Data, L + 1, A, L );
    TPC8( CARDINAL( A ) + L )^ := CARD8( CRC );

// LogSC( serial.dlIO, Name, L'Out ', CARDINAL( CRC ));

    Data^.Len := L + 1;
  END AddChkSum;

//--------------------------------------------------------------------------------

  VIRTUAL PROCEDURE TestChkSum( Data : vdstr.TPDStringA ) : CARDINAL; // success, ecChkSumFailure
  TYPE
    TPC8 = POINTER TO CARD8;
  VAR
    A : ADDRESS;
    CRC : CARD8;
    FP : TPRequest;
    L : CARDINAL;
    RCRC : CARD8;
  BEGIN
    IF NOT PDriver^.Requests.GetFirst( FP ) THEN
      RETURN 0;
    ELSIF FP^.DeviceCmd^.Len = 0 THEN
      RETURN serial.ecChkSumFailure;
    END;
    vdstr.GetDStrAddrLenA( Data, A, L );
    RCRC := TPC8( CARDINAL( A ) + L - 1 )^; // received CRC

// LogSC( serial.dlIO, Name, L'Rcv ', CARDINAL( RCRC ));

    CASE FP^.Channel OF
    | chPanGet, chTiltGet, chMagnificationGet : // extended response
      INC( A, 1 ); // sync
      DEC( L, 2 ); // sync + chksum
      CRC := ComputeChkSum( A, L );

// LogSC( serial.dlIO, Name, L'CmG ', CARDINAL( CRC ));

    | chId : // query id response
      INC( A, 1 ); // sync
      DEC( L, 2 ); // sync + chksum
      CRC := ComputeChkSum( A, L );
      vdstr.GetDStrAddrLenA( FP^.DeviceCmd, A, L );
      CRC := CRC + ComputeChkSum( A, L );
    ELSE // general response
      INC( A, 2 ); // sync + address
      CRC := TPC8( A )^;
      vdstr.GetDStrAddrLenA( FP^.DeviceCmd, A, L );

// LogSC( serial.dlIO, Name, L'Cm1 ', CARDINAL( ComputeChkSum( A, L ) ));

      CRC := CRC + ComputeChkSum( A, L );
    END;

    IF RCRC <> CRC THEN
      RETURN serial.ecChkSumFailure;
    ELSE
      RETURN 0;
    END;
  END TestChkSum;

//--------------------------------------------------------------------------------

  PROCEDURE ComputeChkSum( A : ADDRESS; L : CARDINAL ) : CARD8;
  TYPE
    TPC8 = POINTER TO CARD8;
  VAR
    CRC : CARD8;
  BEGIN
    CRC := 0;
    WHILE L > 0 DO
      CRC := CRC + TPC8( A )^;
      DEC( L );
      INC( A );
    END; // WHILE
    RETURN CRC;
  END ComputeChkSum;

//--------------------------------------------------------------------------------

BEGIN
  PDriver := NIL;
END CSerial;

//================================================================================

CLASS IMPLEMENTATION CRequest;

  PROCEDURE Done();
  BEGIN
    IF DeviceCmd <> NIL THEN
      FREE( DeviceCmd );
    END;
  END Done;

BEGIN
  Pending := FALSE;
  Camera := 0;
  Channel := ch;
  DeviceCmd := NIL;
END CRequest;

//================================================================================

CLASS IMPLEMENTATION CDriver;

//--------------------------------------------------------------------------------

  VIRTUAL PROCEDURE ReceiveMsg(     Message : CARDINAL;
                                    wParam  : windows.WPARAM;
                                    lParam  : windows.LPARAM;
                                VAR lResult : windows.LRESULT ) : BOOLEAN;
  BEGIN
    IF SUPER.ReceiveMsg( Message, wParam, lParam, lResult ) THEN
      RETURN TRUE;
    END;
    lResult := 0;

    CASE Message OF
    //-----
    | WM_COMMUNICATE :
      Communicate();
    //-----
    ELSE
      RETURN FALSE;
    END;

    RETURN TRUE;
  END ReceiveMsg;

//--------------------------------------------------------------------------------

  PROCEDURE Init( _RunMode : CARDINAL; VAR SymbolicName : ARRAY OF WCHAR; _CallbackId : ADDRESS; PCallback : drv_def.TDriverCallbackW ) : BOOLEAN;
  BEGIN
    SUPER.Init();

    CallbackId := _CallbackId;
    CallbackProc := PCallback;
    RunMode := _RunMode;
    ASSIGN( Name, SymbolicName );
    Requests.Init( NIL );

    RETURN TRUE;
  END Init;

//--------------------------------------------------------------------------------

  PROCEDURE ReadParameters( VAR ParFilePath, ErrorMessage : ARRAY OF WCHAR; VAR ErrorLine, ErrorColumn : CARDINAL; VAR HintOrHelp : ARRAY OF WCHAR ) : BOOLEAN;
  LABEL
    Fail;
  CONST
    // .PAR section names 
    snDevice               = L'PelcoD';
    // .PAR key names
    knComDriver            = L'com_driver';
    knTimeout              = L'timeout';
    knReadBack             = L'read_back';

    knAddress              = L'address';
    knAddresses            = L'addresses';

    knDebugMode            = L'debug_mode';
      kvDebugNone          = L'none';
      kvDebugFile          = L'file';
      kvDebugKernel        = L'windows';
    knDebugFile            = L'debug_file';
    knDebugLevel           = L'debug_level';
      kvDebugBasic         = L'basic';
      kvDebugExtended      = L'extended';
      kvDebugAll           = L'all';

  //----------

    PROCEDURE AppendErrorId( VAR ErrorMessage : ARRAY OF WCHAR; ErrorId : ARRAY OF WCHAR );
    BEGIN
      Str.AppendW( ErrorMessage, L' (' );
      Str.AppendW( ErrorMessage, ErrorId );
      Str.AppendW( ErrorMessage, L')' );
    END AppendErrorId;

  //----------

  VAR
    c, ch, cl : CARDINAL;
    ComChannel : ARRAY [0..63] OF WCHAR;
    ComDriver : ARRAY [0..63] OF WCHAR;
    DebugFile : FIO.PathStrW;
    DebugLevel : serial.TDebugLevel;
    DebugMode : serial.TDebugMethod;
    n : ARRAY [0..31] OF WCHAR;
    s : ARRAY [0..511] OF WCHAR;
    TS : vscan.CTextScannerW;
    b : BOOLEAN;
    ReadBack : BOOLEAN;
  BEGIN
    HintOrHelp[0] := WCHAR( 0 );

    IF NOT TS.Init( ParFilePath ) THEN
      ASSIGN( ErrorMessage, PelcoD_._CannotOpenPar );
      AppendErrorId( ErrorMessage, ParFilePath );
      GOTO Fail;
    END;

    InitToDefault();
    ComChannel := L'';
    ComDriver := L'';
    DebugMode := serial.dmNone;
    DebugLevel := serial.dlIO;
    ReadBack := FALSE;

    IF NOT TS.SetSection( snDevice ) THEN
      IF RunMode = drv_def.drmRun THEN
        ASSIGN( ErrorMessage, PelcoD_._MissingDeviceSection );
        GOTO Fail;
      ELSE
        RETURN TRUE;
      END;
    END;

    IF NOT TS.GetKeyStr( knComDriver, s ) THEN
      ASSIGN( ErrorMessage, PelcoD_._MissingDevice );
      GOTO Fail;
    END;
    Str.ItemSW( ComDriver, s, L' ,', 0 );
    Str.ItemSW( ComChannel, s, L' ,', 1 );
    IF ( ComDriver[0] = WCHAR( 0 )) OR ( ComChannel[0] = WCHAR( 0 )) THEN
      ASSIGN( ErrorMessage, PelcoD_._DeviceDefinitionIsBad );
      GOTO Fail;
    END;

    TS.GetKeyCard( knTimeout, RxTimeout );
    TS.GetKeyBool( knReadBack, ReadBack );

    // single address
    b := TS.GetFirstKeyStr( knAddress, s );
    WHILE b DO
      c := Str.StrToCardW( s, 10, b );
      IF NOT b THEN
        ASSIGN( ErrorMessage, PelcoD_._BadAddressNumber );
        GOTO Fail;
      ELSIF c >= 256 THEN
        ASSIGN( ErrorMessage, PelcoD_._BadAddressRange );
        GOTO Fail;
      ELSE
        Cameras[c].Present := TRUE;
        INC( NCameras );
      END;
      b := TS.GetNextKeyStr( knAddress, s );
    END;

    // groups
    b := TS.GetFirstKeyStr( knAddresses, s );
    WHILE b DO
      c := Str.PosW( s, L'..' );
      IF c = MAX( CARDINAL ) THEN
        ASSIGN( ErrorMessage, PelcoD_._BadAddressInterval );
        GOTO Fail;
      END;
      Str.SliceW( n, s, 0, c ); Str.TrimW( n );
      cl := Str.StrToCardW( n, 10, b );
      IF NOT b THEN
        ASSIGN( ErrorMessage, PelcoD_._BadAddressNumber );
        GOTO Fail;
      ELSIF cl >= 256 THEN
        ASSIGN( ErrorMessage, PelcoD_._BadAddressRange );
        GOTO Fail;
      END;
      Str.DeleteW( s, 0, c + 2 ); Str.TrimW( s );
      ch := Str.StrToCardW( s, 10, b );
      IF NOT b THEN
        ASSIGN( ErrorMessage, PelcoD_._BadAddressNumber );
        GOTO Fail;
      ELSIF ch >= 256 THEN
        ASSIGN( ErrorMessage, PelcoD_._BadAddressRange );
        GOTO Fail;
      END;
      FOR c := cl TO ch DO
        Cameras[c].Present := TRUE;
        INC( NCameras );
      END;
      b := TS.GetNextKeyStr( knAddresses, s );
    END;

    IF TS.GetKeyStr( knDebugMode, s ) THEN
      IF EQUALS( s, kvDebugNone ) = 0 THEN
        DebugMode := serial.dmNone;
      ELSIF EQUALS( s, kvDebugFile ) = 0 THEN
        DebugMode := serial.dmFile;
        IF NOT TS.GetKeyStr( knDebugFile, s ) THEN
          ASSIGN( ErrorMessage, PelcoD_._FileDebugMissingFile );
          GOTO Fail;
        END;
        ASSIGN( DebugFile, s );
      ELSIF EQUALS( s, kvDebugKernel ) = 0 THEN
        DebugMode := serial.dmKernel;
      END;
      IF DebugMode <> serial.dmNone THEN
        IF TS.GetKeyStr( knDebugLevel, s ) THEN
          IF EQUALS( s, kvDebugBasic ) = 0 THEN
            DebugLevel := serial.dlIO;
          ELSIF EQUALS( s, kvDebugExtended ) = 0 THEN
            DebugLevel := serial.dlCtrl;
          ELSIF EQUALS( s, kvDebugAll ) = 0 THEN
            DebugLevel := serial.dlAll;
          END;
        END;
      END;
    END;

    IF RunMode = drv_def.drmRun THEN
      INCL( RStatus, rsSerialInitialized );

      Serial.SetReadBack( ReadBack );
      Serial.SetInBoundaryStrings( WCHAR( 255 ), L'' );
      Serial.SetOutBoundaryStrings( WCHAR( 255 ), L'' );
      Serial.SetDebug( DebugMode, DebugLevel, DebugFile );

      RETURN Serial.Init( Name, ComChannel, ComDriver, ParFilePath, ErrorMessage );
    ELSE
      RETURN TRUE;
    END;

  Fail:
    RETURN FALSE;
  END ReadParameters;

//--------------------------------------------------------------------------------

  PROCEDURE EnumerateChannels( VAR EnumerateState : LONGWORD; VAR Type : CARDINAL; VAR Direction : CARDINAL; VAR DriverIndex : CARDINAL; VAR Count : CARDINAL; VAR HaveDescription : BOOLEAN ): BOOLEAN;
  VAR
    Channel : TChannel;
    i : CARDINAL;
  BEGIN
    IF CARDINAL( EnumerateState ) = -1 THEN
      RETURN FALSE;
    ELSIF EnumerateState = LONGWORD( 0 ) THEN // start
      i := 0;
      WHILE ( i < 256 ) AND NOT Cameras[i].Present DO
        INC( i );
      END;
      IF i = 256 THEN
        RETURN FALSE;
      END;
      EnumerateState := LONGWORD( 100000 + i * 100 + CARDINAL( chSwitch ));
    ELSE
      i := CARDINAL( EnumerateState ) DIV 100 - 1000;
    END;
    Channel := TChannel( CARDINAL( EnumerateState ) MOD 100 );

    DriverIndex := 100000 + i * 100 + CARDINAL( IOs[Channel].ChOfs );
    Type := CARDINAL( IOs[Channel].ChType );
    Direction := CARDINAL( IOs[Channel].ChDir );
    Count := 1;
    HaveDescription := FALSE;

    IF Channel = chId THEN // last channel in group
      i := CARDINAL( EnumerateState ) DIV 100 - 1000 + 1;
      WHILE ( i < 256 ) AND NOT Cameras[i].Present DO
        INC( i );
      END;
      IF i = 256 THEN
        EnumerateState := -1;
      ELSE
        EnumerateState := LONGWORD( 100000 + i * 100 + CARDINAL( chSwitch ));
      END;
    ELSE
      INC( EnumerateState );
    END;
    RETURN TRUE;
  END EnumerateChannels;

//--------------------------------------------------------------------------------

  PROCEDURE Run();
  BEGIN
    Serial.Run();
    INCL( RStatus, rsRunning );
  END Run;

//--------------------------------------------------------------------------------

  PROCEDURE Stop();
  BEGIN
    EXCL( RStatus, rsRunning );
    Serial.Stop();
  END Stop;

//--------------------------------------------------------------------------------

  PROCEDURE Done();
  BEGIN
    Requests.DisposeList();
    IF rsSerialInitialized IN RStatus THEN
      Serial.Done();
    END;
    Requests.Done();
    SUPER.Done();
  END Done;

//--------------------------------------------------------------------------------

  PROCEDURE QueryProc( UFlag : BOOLEAN; InValue1, InValue2 : drv_def.TValue; VAR OutValue : drv_def.TValue );
  LABEL
    Next;
  VAR
    A : ADDRESS;
    cmd : ARRAY [0..15] OF WCHAR;
    DSW : vdstr.TPDStringW;
    F : TFrame;
    i, l, r : CARDINAL;
    L : CARDINAL;
    PRequest : TPRequest;
    si : ARRAY [0..63] OF WCHAR;
    speed : CARDINAL;
    n : ARRAY [0..15] OF WCHAR;
    b : BOOLEAN;
    ok : BOOLEAN;
    okaddress : BOOLEAN;
  BEGIN
    DSW := NIL;
    drv_def.DrvValueToDStringW( InValue1, UFlag, DSW );
    IF vdEQUALSDStrToStrW( DSW, L'move' ) <> 0 THEN
      IF DSW <> NIL THEN
        FREE( DSW );
      END;
      RETURN;
    END;

    drv_def.DrvValueToDStringW( InValue2, UFlag, DSW );
    F.Cmd1 := 0;
    F.Cmd2 := 0;
    i := 0;
    ok := FALSE;
    okaddress := FALSE;
    LOOP
      vdstr.ItemSDStrToStrW( DSW, si, L' ,', i );
      IF si[0] = WCHAR( 0 ) THEN
        EXIT;
      END;
      l := Str.CharPosW( si, L'[' );
      IF l = MAX( CARDINAL ) THEN
        GOTO Next;
      END;
      Str.SliceW( cmd, si, l + 1, MAX( CARDINAL ));
      si[l] := WCHAR( 0 );
      Str.TrimW( si );
      r := Str.CharPosW( cmd, L']' );
      IF r = MAX( CARDINAL ) THEN
        GOTO Next;
      END;
      cmd[r] := WCHAR( 0 );
      l := Str.CharPosW( cmd, L':' );
      IF l = MAX( CARDINAL ) THEN
        n[0] := WCHAR( 0 );
      ELSE
        Str.SliceW( n, cmd, l + 1, MAX( CARDINAL ));
        cmd[l] := WCHAR( 0 );
      END;
      Str.TrimW( cmd );
      IF EQUALS( si, L'address' ) THEN
        IF cmd[0] = WCHAR( 0 ) THEN
          GOTO Next;
        END;
        speed := Str.StrToCardW( cmd, 10, b );
        IF speed > 256 THEN
          GOTO Next;
        END;
        okaddress := TRUE;
        F.Address := CARD8( speed );
      ELSIF EQUALS( si, L'pan' ) THEN
        IF EQUALS( cmd, L'stop' ) THEN
        ELSIF EQUALS( cmd, L'left' ) THEN
          F.Cmd2 := F.Cmd2 OR 004H;
        ELSIF EQUALS( cmd, L'right' ) THEN
          F.Cmd2 := F.Cmd2 OR 002H;
        ELSE
          GOTO Next;
        END;
        IF n[0] = WCHAR( 0 ) THEN
          speed := 0;
        ELSE
          speed := Str.StrToCardW( n, 10, b );
          IF speed > 100 THEN
            GOTO Next;
          END;
        END;
        ok := TRUE;
        speed := speed * 64 DIV 100;
        F.Data1 := CARD8( speed );
      ELSIF EQUALS( si, L'tilt' ) THEN
        IF EQUALS( cmd, L'stop' ) THEN
        ELSIF EQUALS( cmd, L'up' ) THEN
          F.Cmd2 := F.Cmd2 OR 008H;
        ELSIF EQUALS( cmd, L'down' ) THEN
          F.Cmd2 := F.Cmd2 OR 010H;
        ELSE
          GOTO Next;
        END;
        IF n[0] = WCHAR( 0 ) THEN
          speed := 0;
        ELSE
          speed := Str.StrToCardW( n, 10, b );
          IF speed > 100 THEN
            GOTO Next;
          END;
        END;
        ok := TRUE;
        speed := speed * 63 DIV 100;
        F.Data2 := CARD8( speed );
      ELSIF EQUALS( si, L'zoom' ) THEN
        IF EQUALS( cmd, L'stop' ) THEN
        ELSIF EQUALS( cmd, L'wide' ) THEN
          F.Cmd2 := F.Cmd2 OR 040H;
        ELSIF EQUALS( cmd, L'tele' ) THEN
          F.Cmd2 := F.Cmd2 OR 020H;
        ELSE
          GOTO Next;
        END;
        ok := TRUE;
      ELSIF EQUALS( si, L'focus' ) THEN
        IF EQUALS( cmd, L'stop' ) THEN
        ELSIF EQUALS( cmd, L'far' ) THEN
          F.Cmd2 := F.Cmd2 OR 080H;
        ELSIF EQUALS( cmd, L'near' ) THEN
          F.Cmd1 := F.Cmd1 OR 001H;
        ELSE
          GOTO Next;
        END;
        ok := TRUE;
      ELSIF EQUALS( si, L'iris' ) THEN
        IF EQUALS( cmd, L'stop' ) THEN
        ELSIF EQUALS( cmd, L'open' ) THEN
          F.Cmd1 := F.Cmd1 OR 002H;
        ELSIF EQUALS( cmd, L'close' ) THEN
          F.Cmd1 := F.Cmd1 OR 004H;
        ELSE
          GOTO Next;
        END;
        ok := TRUE;
      ELSE
        GOTO Next;
      END;
    Next:
      INC( i );
    END; // LOOP

    IF NOT okaddress THEN
    ELSIF ok THEN
      NEW( PRequest );
      vdstr.EnsureDStrLenA( PRequest^.DeviceCmd, SIZE( TFrame ), A, L );
      PRequest^.DeviceCmd^.Len := 5;
      Lib.Move( ADR( F ), A, 5 );
      PRequest^.Camera := CARDINAL( F.Address );
      PRequest^.Channel := ch;
      Requests.Append( PRequest );
      Communicate();
    ELSE
    END;

    IF DSW <> NIL THEN
      FREE( DSW );
    END;
    // drv_def.AssignValueStringW( OutValue, TRUE, R );
  END QueryProc;

//--------------------------------------------------------------------------------

  PROCEDURE InputRequestStart();
  BEGIN
  END InputRequestStart;

//--------------------------------------------------------------------------------

  PROCEDURE InputRequest( DriverIndex : CARDINAL );
  BEGIN
    IF ValidIndex( TRUE, DriverIndex ) THEN
      WITH Cameras[DriverIndex DIV 100 - 1000].Channels[n2ch[DriverIndex MOD 100]] DO
        IF csPending1 IN CS THEN
          INCL( CS, csPending2 );
        ELSE
          AddRequest( DriverIndex );
        END;
      END; // WITH
    END;
  END InputRequest;

//--------------------------------------------------------------------------------

  PROCEDURE InputRequestCompleted();
  BEGIN
    Communicate();
  END InputRequestCompleted;

//--------------------------------------------------------------------------------

  PROCEDURE InputFinalized( DriverIndex : CARDINAL; VAR ErrorCode : CARDINAL ) : BOOLEAN;
  VAR
    Finalized : BOOLEAN;
  BEGIN
    Finalized := TRUE;
    ErrorCode := 0;
    IF NOT ValidIndex( TRUE, DriverIndex ) THEN
      ErrorCode := drv_def.ecUnknownElement;
    ELSIF DriverIndex = chStatus THEN
      ErrorCode := 0;
    ELSIF {serial.rsRun} * Serial.RStatus = {} THEN
      ErrorCode := ceDeviceStopped;
    ELSE
      WITH Cameras[DriverIndex DIV 100 - 1000].Channels[n2ch[DriverIndex MOD 100]] DO
        IF csTimeout IN CS THEN
          ErrorCode := ceRxTimeout;
        ELSIF csPending1 IN CS THEN
          Finalized := FALSE;
        ELSIF csPending2 IN CS THEN
          _ASSERTE( FALSE );
          EXCL( CS, csPending2 );
          InputRequest( DriverIndex );
        END;
      END; // WITH
    END;
    RETURN Finalized;
  END InputFinalized;

//--------------------------------------------------------------------------------

  PROCEDURE InputOOBDataQuery( VAR EnumerateState : LONGWORD; VAR DriverIndex : CARDINAL ) : BOOLEAN;
  BEGIN
    RETURN FALSE;
  END InputOOBDataQuery;

//--------------------------------------------------------------------------------

  PROCEDURE GetInput( UFlag : BOOLEAN; DriverIndex : CARDINAL; VAR InValue : drv_def.TValue; VAR QoS : CARDINAL; VAR TimeStamp : drv_def.TUTCStamp; VAR ErrorCode : CARDINAL );
  BEGIN
    ErrorCode := drv_def.ecSuccess;
    QoS := drv_def.qosGood;

    CASE DriverIndex OF
    | chStatus :
      drv_def.AssignValueCardinal( InValue, TRUE, CARDINAL( RStatus * rssUser ));
    ELSE
      WITH Cameras[DriverIndex DIV 100 - 1000].Channels[n2ch[DriverIndex MOD 100]] DO
        drv_def.AssignValueType( InValue, TRUE, CARDINAL( IOs[n2ch[DriverIndex MOD 100]].ChType ), ADR( VC ));
      END;
    END; // CASE
  END GetInput;

//--------------------------------------------------------------------------------

  PROCEDURE OutputRequestStart();
  BEGIN
  END OutputRequestStart;

//--------------------------------------------------------------------------------

  PROCEDURE OutputRequest( UFlag : BOOLEAN; DriverIndex : CARDINAL; OutValue : drv_def.TValue; QoS : CARDINAL; TimeStamp : drv_def.TUTCStamp );
  BEGIN
    IF ValidIndex( FALSE, DriverIndex ) THEN
      WITH Cameras[DriverIndex DIV 100 - 1000].Channels[n2ch[DriverIndex MOD 100]] DO
        IF OutValue.Type = drv_def.vtNothing THEN
          // pass to request without setting a value
        ELSIF IOs[n2ch[DriverIndex MOD 100]].ChType = drv_def.vtLongReal THEN
          VR := drv_def.ValueToLongReal( OutValue, TRUE );
          Serial.LogSC( serial.dlCtrl, Name, L'OutRQ to ', CARDINAL( n2ch[DriverIndex MOD 100] ));
          Serial.LogSC( serial.dlCtrl, Name, L'   value ', CARDINAL( 100.0 * VR ));
        ELSIF IOs[n2ch[DriverIndex MOD 100]].ChType = drv_def.vtBoolean THEN
          VB := drv_def.ValueToBoolean( OutValue, TRUE );
        ELSE
          VC := drv_def.ValueToCardinal( OutValue, TRUE );
          Serial.LogSC( serial.dlCtrl, Name, L'OutRQ to ', CARDINAL( n2ch[DriverIndex MOD 100] ));
          Serial.LogSC( serial.dlCtrl, Name, L'   value ', VC );
        END;
        IF csPending1 IN CS THEN
          INCL( CS, csPending2 );
        ELSE
          AddRequest( DriverIndex );
        END;
      END; // WITH
    END;
  END OutputRequest;

//--------------------------------------------------------------------------------

  PROCEDURE OutputRequestCompleted();
  BEGIN
    Communicate();
  END OutputRequestCompleted;

//--------------------------------------------------------------------------------

  PROCEDURE OutputFinalized( DriverIndex : CARDINAL; VAR ErrorCode : CARDINAL ) : BOOLEAN;
  VAR
    OV : drv_def.TValue;
    TS : drv_def.TUTCStamp;
    Finalized : BOOLEAN;
  BEGIN
    Finalized := TRUE;
    ErrorCode := 0;
    IF NOT ValidIndex( FALSE, DriverIndex ) THEN
      ErrorCode := drv_def.ecUnknownElement;
    ELSIF {serial.rsRun} * Serial.RStatus = {} THEN
      ErrorCode := ceDeviceStopped;
    ELSE
      WITH Cameras[DriverIndex DIV 100 - 1000].Channels[n2ch[DriverIndex MOD 100]] DO
        IF csTimeout IN CS THEN
          ErrorCode := ceRxTimeout;
        ELSIF csBadInput IN CS THEN
          ErrorCode := ceBadInput;
        ELSIF csPending1 IN CS THEN
          Finalized := FALSE;
        ELSIF csPending2 IN CS THEN
          EXCL( CS, csPending2 );
          drv_def.InitValue( OV );
          Lib.Fill( ADR( TS ), SIZE( TS ), 0 );
          OutputRequest( FALSE, DriverIndex, OV, drv_def.qosGood, TS );
        END;
      END; // WITH
    END;
    RETURN Finalized;
  END OutputFinalized;

//--------------------------------------------------------------------------------

  PROCEDURE OnReceive( Data : vdstr.TPDStringA; ErrorCode : CARDINAL );
  TYPE
    TPPDS = POINTER TO vdstr.TPDStringA;
  VAR
    A : ADDRESS;
    c : CARDINAL;
    FP : TPRequest;
    L : CARDINAL;
    PPDS : TPPDS;
    SA : ADDRESS;
  BEGIN
    Requests.Enter();
    IF NOT Requests.GetFirst( FP ) OR NOT FP^.Pending THEN
      Serial.LogS( serial.dlAll, Name, L'RX unexpected, nothing is pending' );
      Requests.Leave();
      RETURN;
    END;

// Serial.LogSC( serial.dlIO, Name, L'Removed ', CARDINAL( FP^.Channel ));

    Requests.Remove();
    Requests.Leave();
    EXCL( Cameras[FP^.Camera].Channels[FP^.Channel].CS, csPending1 );

    CASE ErrorCode OF
    | 0 :
      vdstr.GetDStrAddrLen( Data, A, L );
      CASE FP^.Channel OF
      | chPanGet, chTiltGet, chMagnificationGet :
        c := CARDINAL( TPFrame( A )^.RData1 ) * 256 + CARDINAL( TPFrame( A )^.RData2 );
        Cameras[FP^.Camera].Channels[FP^.Channel].VR := LONGREAL( c ) / 100.0;
        Serial.LogSC( serial.dlCtrl, Name, L'RCV to ', CARDINAL( FP^.Channel ));
        Serial.LogSC( serial.dlCtrl, Name, L'   cam ', CARDINAL( FP^.Camera ));
        Serial.LogSC( serial.dlCtrl, Name, L' value ', CARDINAL( c ));
      | chId :
        PPDS := TPPDS( ADR( Cameras[FP^.Camera].Channels[FP^.Channel].VS ));
        vdstr.EnsureDStrLenA( PPDS^, 16, SA, L ); 
        PPDS^^.Len := 16;
        Lib.Move( ADR( TPFrame( A )^.IdS ), SA, 16 );
        vdstr.EnsureDStrZeroEndA( PPDS^, SA, L );
        PPDS^^.Len := Lib.ScanR( ADR( PPDS^^.Chars ), 17, 0 );
      END;
    | serial.ecRxTimeout :
      INCL( Cameras[FP^.Camera].Channels[FP^.Channel].CS, csTimeout );
      Serial.LogS( serial.dlIO, Name, L'RX timeout' );
    | serial.ecChkSumFailure :
      Serial.LogS( serial.dlIO, Name, L'RX checksum failure' );
    ELSE
      Serial.LogSC( serial.dlIO, Name, L'RX ? unknown error ', ErrorCode );
    END;

    IF FP^.Channel = ch THEN
      CallbackProc( CallbackId, drv_def.dcfException, NIL );
    ELSIF IOs[FP^.Channel].ChDir = drv_def.dirInput THEN
      CallbackProc( CallbackId, drv_def.dcfInputFinalized, NIL );
    ELSE
      CallbackProc( CallbackId, drv_def.dcfOutputFinalized, NIL );
    END;

    FP^.Done();
    FREE( FP );

    // go to another thread
    windows.PostMessage( HWND, WM_COMMUNICATE, 0, 0 );
  END OnReceive;

//--------------------------------------------------------------------------------

  PROCEDURE OnSend( ErrorCode : CARDINAL );
  BEGIN
  END OnSend;

//--------------------------------------------------------------------------------

  PROCEDURE AddRequest( DriverIndex : CARDINAL ) : CARDINAL;
  LABEL
    Failure;
  VAR
    A : ADDRESS;
    c : CARDINAL;
    L : CARDINAL;
    PRequest : TPRequest;
  BEGIN
    NEW( PRequest );

    PRequest^.Camera := DriverIndex DIV 100 - 1000;
    PRequest^.Channel := n2ch[DriverIndex MOD 100];

    vdstr.EnsureDStrLenA( PRequest^.DeviceCmd, SIZE( TFrame ), A, L );
    PRequest^.DeviceCmd^.Len := 5;

    Lib.Move( ADR( IOs[n2ch[DriverIndex MOD 100]].OutFrame ), A, 5 );
    WITH Cameras[PRequest^.Camera].Channels[PRequest^.Channel] DO WITH TPFrame( A )^ DO
      CS := CS - {csTimeout, csBadInput} + {csPending1};
      Address := CARD8( PRequest^.Camera );
      CASE PRequest^.Channel OF
      | chSwitch :
        IF VB THEN
          Cmd1 := 088H;
          Cmd2 := 0;
        ELSE
          Cmd1 := 008H;
          Cmd2 := 0;
        END;
      | chPresetSet :
        c := MAX2( 1, MIN2( VC, 32 ));
        IF c <> VC THEN GOTO Failure; END;
        Data2 := CARD8( c );
      | chPresetReset :
        c := MAX2( 1, MIN2( VC, 32 ));
        IF c <> VC THEN GOTO Failure; END;
        Data2 := CARD8( c );
      | chPresetGoto :
        c := MAX2( 1, MIN2( VC, 32 ));
        IF c <> VC THEN GOTO Failure; END;
        Data2 := CARD8( c );
      | chPanSet :
        c := MIN2( CARDINAL( VR * 100.0 ), 35999 );
        Data1 := CARD8( c DIV 256 );
        Data2 := CARD8( c MOD 256 );
      | chTiltSet :
        c := MIN2( CARDINAL( VR * 100.0 ), 35999 );
        Data1 := CARD8( c DIV 256 );
        Data2 := CARD8( c MOD 256 );
      // | chZoomSet :
      | chMagnificationSet :
        c := MAX2( 1, MIN2( CARDINAL( VR * 100.0 ), 30000 ));
        Data1 := CARD8( c DIV 256 );
        Data2 := CARD8( c MOD 256 );
      | chZeroSet :
      | chAuxSet :
        c := MAX2( 1, MIN2( VC, 8 ));
        IF c <> VC THEN GOTO Failure; END;
        Data2 := CARD8( c );
      | chAuxReset :
        c := MAX2( 1, MIN2( VC, 8 ));
        IF c <> VC THEN GOTO Failure; END;
        Data2 := CARD8( c );
      | chAFocusSwitch :
        c := MIN2( VC, 2 );
        IF c <> VC THEN GOTO Failure; END;
        Data2 := CARD8( c );
      | chAIrisSwitch :
        c := MIN2( VC, 2 );
        IF c <> VC THEN GOTO Failure; END;
        Data2 := CARD8( c );
      | chPanGet,
        chTiltGet,
        chMagnificationGet :
      | chId :
      ELSE
        ASSERT( FALSE );
      END;

      Requests.Append( PRequest );
      RETURN 0;

    Failure:
      CS := CS + {csBadInput} - {csPending1};
      FREE( PRequest );
      RETURN 0;

    END; END; // WITH // WITH
  END AddRequest;

//--------------------------------------------------------------------------------

  PROCEDURE Communicate() : CARDINAL;
  VAR
    PRequest : TPRequest;
  BEGIN
    IF NOT Requests.GetFirst( PRequest ) THEN
      RETURN winerror.ERROR_SUCCESS;
    ELSIF PRequest^.Pending THEN
      RETURN winerror.ERROR_IO_PENDING;
    END;

// Serial.LogSC( serial.dlIO, Name, L'Started ', CARDINAL( PRequest^.Channel ));

    Serial.LogSC( serial.dlCtrl, Name, L'REQ of ', CARDINAL( PRequest^.Channel ));
    Serial.LogSC( serial.dlCtrl, Name, L'   cam ', CARDINAL( PRequest^.Camera ));

    PRequest^.Pending := TRUE;
    Serial.TxA( PRequest^.DeviceCmd, FALSE, 0, 0, RxTimeout + 300 );
    RETURN winerror.ERROR_IO_PENDING;
  END Communicate;

//--------------------------------------------------------------------------------

  PROCEDURE InitToDefault();
  BEGIN
    RxTimeout := 5000;
    NCameras := 0;
  END InitToDefault;

//--------------------------------------------------------------------------------

  PROCEDURE Result2DriverError( Result : CARDINAL ) : CARDINAL;
  BEGIN
    CASE Result OF
    | 0 :
      RETURN drv_def.ecSuccess;
    | serial.ecRxTimeout :
      RETURN ceRxTimeout;
    END;
    RETURN drv_def.ecValueProcessing;
  END Result2DriverError;

//--------------------------------------------------------------------------------

  PROCEDURE ValidIndex( Input : BOOLEAN; DriverIndex : CARDINAL ) : BOOLEAN;
  BEGIN
    IF NOT Cameras[DriverIndex DIV 100 - 1000].Present THEN
      RETURN FALSE;
    ELSIF n2ch[DriverIndex MOD 100] = ch THEN
      RETURN FALSE;
    ELSIF ( NCameras > 1 ) AND ( n2ch[DriverIndex MOD 100] = chId ) THEN
      RETURN FALSE;
    ELSIF ( IOs[n2ch[DriverIndex MOD 100]].ChDir = drv_def.dirInput ) = Input THEN
      RETURN TRUE;
    ELSE
      RETURN NOT Input;
    END;
  END ValidIndex;

//================================================================================

BEGIN
  RStatus := TRStatus{};
  RunMode := drv_def.drmEdit;
  CallbackId := NIL;
  CallbackProc := NIL;
  Serial.PDriver := ADR( SELF );
  Lib.Fill( ADR( Cameras ), SIZE( Cameras ), 0 );
END CDriver;

//================================================================================
// procedural interface

CONST
  DriverName = C'Pelco-D Driver';

VAR
  HInstance : windows.HINSTANCE;
  RefCount  : CARDINAL;

PROCEDURE VersionW() : CARDINAL;
BEGIN
  RETURN 030000H;
END VersionW;

//--------------------------------------------------------------------------------

PROCEDURE GetDriverInfo( VAR DriverName : ARRAY OF CHAR );
BEGIN
  Str.U2A( PelcoD_._DriverName, DriverName );
END GetDriverInfo;

//--------------------------------------------------------------------------------

PROCEDURE GetDriverInfoW( VAR DriverNameW : ARRAY OF WCHAR );
BEGIN
  ASSIGN( DriverNameW, PelcoD_._DriverName );
END GetDriverInfoW;

//--------------------------------------------------------------------------------

PROCEDURE Check( VAR ErrorString : ARRAY OF CHAR; CWVersion, MajorVersion, MinorVersion, APIMajorVersion, APIMinorVersion : CARDINAL ): BOOLEAN;
VAR
  es : ARRAY [0..255] OF WCHAR;
  b : BOOLEAN;
BEGIN
  b := CheckW( es, CWVersion, MajorVersion, MinorVersion, APIMajorVersion, APIMinorVersion );
  Str.U2A( es, ErrorString );
  RETURN b;
END Check;

//--------------------------------------------------------------------------------

PROCEDURE CheckW( VAR ErrorString : ARRAY OF WCHAR; CWVersion, MajorVersion, MinorVersion, APIMajorVersion, APIMinorVersion : CARDINAL ): BOOLEAN;
BEGIN
  RETURN TRUE;
END CheckW;

//--------------------------------------------------------------------------------

PROCEDURE MakeDriverW() : ADDRESS;
VAR
  PDriver : TPDriver;
BEGIN
  IF RefCount = 0 THEN
    vwthread.__INIT( HInstance );
  END;
  INC( RefCount );
  NEW( PDriver );
  RETURN PDriver;
END MakeDriverW;

//--------------------------------------------------------------------------------

PROCEDURE DisposeDriverW( PData : ADDRESS );
BEGIN
  FREE( PData );
  DEC( RefCount );
  IF RefCount = 0 THEN
    vwthread.__DONE();
  END;
END DisposeDriverW;

//--------------------------------------------------------------------------------

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
                     PCallback    : drv_def.TDriverCallback ) : BOOLEAN;
VAR
  ec, el  : CARDINAL;
  em : ARRAY [0..255] OF WCHAR;
  hoh : ARRAY [0..3] OF CHAR;
  RunMode : CARDINAL;
  s : ARRAY [0..7] OF WCHAR;
BEGIN
  IF RunFlag THEN
    RunMode := drv_def.drmRun;
  ELSE
    RunMode := drv_def.drmEdit;
  END;
  ErrorMessage[0] := CHAR( 0 );
  ASSIGN( s, L'Pelco-D' );
  IF InitCommon( PData, RunMode, s, CallbackId, drv_def.TDriverCallbackW( PCallback ), em ) THEN
    IF NOT ReadParameters( PData, ParFilePath, ErrorMessage, el, ec, hoh ) THEN
      RETURN FALSE;
    END;
    RunW( PData );
  ELSIF em[0] = WCHAR( 0 ) THEN
    Str.U2A( PelcoD_._InitError, ErrorMessage );
    RETURN FALSE;
  ELSE
    Str.U2A( em, ErrorMessage );
    RETURN FALSE;
  END;
  RETURN TRUE;
END Init;

PROCEDURE Init3(     PData        : ADDRESS;
                     RunMode      : CARDINAL;
                 VAR SymbolicName : ARRAY OF CHAR;
                     CallbackId   : ADDRESS;
                     PCallback    : drv_def.TDriverCallback ) : BOOLEAN;
VAR
  ES : ARRAY [0..3] OF WCHAR;
  sn : ARRAY [0..255] OF WCHAR;
BEGIN
  Str.A2U( SymbolicName, sn );
  RETURN InitCommon( PData, RunMode, sn, CallbackId, drv_def.TDriverCallbackW( PCallback ), ES );
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
    ASSIGN( ErrorMessage, PelcoD_._InitError );
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

//--------------------------------------------------------------------------------

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
  Str.A2U( ParFilePath, pf );
  b := TPDriver( PData )^.ReadParameters( pf, em, ErrorLine, ErrorColumn, hoh );
  Str.U2A( em, ErrorMessage );
  Str.U2A( hoh, HintOrHelp );
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

//--------------------------------------------------------------------------------

PROCEDURE QueryErrorCode(          PData : ADDRESS;
                               ErrorCode : CARDINAL;
                           VAR ErrorText : ARRAY OF CHAR ) : BOOLEAN;
VAR
  et : ARRAY [0..255] OF WCHAR;
  b : BOOLEAN;
BEGIN
  b := QueryErrorCodeW( PData, ErrorCode, et );
  Str.U2A( et, ErrorText );
  RETURN b;
END QueryErrorCode;

PROCEDURE QueryErrorCodeW(         PData : ADDRESS;
                               ErrorCode : CARDINAL;
                           VAR ErrorText : ARRAY OF WCHAR ) : BOOLEAN;
BEGIN
  CASE ErrorCode OF
  | ceDeviceStopped :
    ASSIGN( ErrorText, PelcoD_._E_DeviceStopped );
  | ceBadInput :
    ASSIGN( ErrorText, PelcoD_._E_BadInput );
  ELSE
    RETURN FALSE;
  END;
  RETURN TRUE;
END QueryErrorCodeW;

//--------------------------------------------------------------------------------

PROCEDURE BufferInfoW( PData : ADDRESS; DriverIndex : CARDINAL; BType : CARD8; BLen : CARDINAL ) : BOOLEAN;
BEGIN
  RETURN FALSE;
END BufferInfoW;

//--------------------------------------------------------------------------------

PROCEDURE SetBufferAddrW( PData : ADDRESS; DriverIndex : CARDINAL; PBuffer : ADDRESS );
BEGIN
END SetBufferAddrW;

//--------------------------------------------------------------------------------

PROCEDURE RunW( PData : ADDRESS );
BEGIN
  TPDriver( PData )^.Run();
END RunW;

//--------------------------------------------------------------------------------

PROCEDURE StopW( PData : ADDRESS );
BEGIN
  TPDriver( PData )^.Stop();
END StopW;

//--------------------------------------------------------------------------------

PROCEDURE DoneW( PData : ADDRESS );
BEGIN
  TPDriver( PData )^.Done();
END DoneW;

//--------------------------------------------------------------------------------

PROCEDURE DriverProcW( PData : ADDRESS; Func, Param1, Param2, Param3, Param4 : CARDINAL );
BEGIN
END DriverProcW;

//--------------------------------------------------------------------------------

PROCEDURE QueryProc( PData : ADDRESS; InValue : drv_def.TValue; VAR OutValue : drv_def.TValue );
BEGIN
  QueryProc3( PData, InValue, OutValue, OutValue );
END QueryProc;

//--------------------------------------------------------------------------------

PROCEDURE QueryProcW( PData : ADDRESS; InValue : drv_def.TValue; VAR OutValue : drv_def.TValue );
BEGIN
  QueryProc3W( PData, InValue, OutValue, OutValue );
END QueryProcW;

//--------------------------------------------------------------------------------

PROCEDURE QueryProc3( PData : ADDRESS; InValue1, InValue2 : drv_def.TValue; VAR OutValue : drv_def.TValue );
BEGIN
  TPDriver( PData )^.QueryProc( FALSE, InValue1, InValue2, OutValue );
END QueryProc3;

//--------------------------------------------------------------------------------

PROCEDURE QueryProc3W( PData : ADDRESS; InValue1, InValue2 : drv_def.TValue; VAR OutValue : drv_def.TValue );
BEGIN
  TPDriver( PData )^.QueryProc( TRUE, InValue1, InValue2, OutValue );
END QueryProc3W;

//--------------------------------------------------------------------------------

PROCEDURE InputRequestStartW( PData : ADDRESS );
BEGIN
  TPDriver( PData )^.InputRequestStart();
END InputRequestStartW;

//--------------------------------------------------------------------------------

PROCEDURE InputRequestW( PData : ADDRESS; DriverIndex : CARDINAL );
BEGIN
  TPDriver( PData )^.InputRequest( DriverIndex );
END InputRequestW;

//--------------------------------------------------------------------------------

PROCEDURE InputRequestCompletedW( PData : ADDRESS );
BEGIN
  TPDriver( PData )^.InputRequestCompleted();
END InputRequestCompletedW;

//--------------------------------------------------------------------------------

PROCEDURE InputFinalizedW( PData : ADDRESS; DriverIndex : CARDINAL; VAR ErrorCode : CARDINAL ) : BOOLEAN;
BEGIN
  RETURN TPDriver( PData )^.InputFinalized( DriverIndex, ErrorCode );
END InputFinalizedW;

//--------------------------------------------------------------------------------

PROCEDURE InputOOBDataQueryW( PData : ADDRESS; VAR EnumerateState : LONGWORD; VAR DriverIndex : CARDINAL ) : BOOLEAN;
BEGIN
  RETURN TPDriver( PData )^.InputOOBDataQuery( EnumerateState, DriverIndex );
END InputOOBDataQueryW;

//--------------------------------------------------------------------------------

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

//--------------------------------------------------------------------------------

PROCEDURE OutputRequestStartW( PData : ADDRESS );
BEGIN
  TPDriver( PData )^.OutputRequestStart();
END OutputRequestStartW;

//--------------------------------------------------------------------------------

PROCEDURE OutputRequest( PData : ADDRESS; DriverIndex : CARDINAL; OutValue : drv_def.TValue );
VAR
  ts : drv_def.TUTCStamp;
BEGIN
  OutputRequest3( PData, DriverIndex, OutValue, drv_def.qosNormal, ts );
END OutputRequest;

PROCEDURE OutputRequest3( PData : ADDRESS; DriverIndex : CARDINAL; OutValue : drv_def.TValue; QoS : CARDINAL; VAR TimeStamp : drv_def.TUTCStamp );
BEGIN
  TPDriver( PData )^.OutputRequest( FALSE, DriverIndex, OutValue, QoS, TimeStamp );
END OutputRequest3;

PROCEDURE OutputRequestW( PData : ADDRESS; DriverIndex : CARDINAL; OutValue : drv_def.TValue );
VAR
  ts : drv_def.TUTCStamp;
BEGIN
  OutputRequest3W( PData, DriverIndex, OutValue, drv_def.qosNormal, ts );
END OutputRequestW;

PROCEDURE OutputRequest3W( PData : ADDRESS; DriverIndex : CARDINAL; OutValue : drv_def.TValue; QoS : CARDINAL; VAR TimeStamp : drv_def.TUTCStamp );
BEGIN
  TPDriver( PData )^.OutputRequest( TRUE, DriverIndex, OutValue, QoS, TimeStamp );
END OutputRequest3W;

//--------------------------------------------------------------------------------

PROCEDURE OutputRequestCompletedW( PData : ADDRESS );
BEGIN
  TPDriver( PData )^.OutputRequestCompleted();
END OutputRequestCompletedW;

//--------------------------------------------------------------------------------

PROCEDURE OutputFinalizedW( PData : ADDRESS; DriverIndex : CARDINAL; VAR ErrorCode : CARDINAL ) : BOOLEAN;
BEGIN
  RETURN TPDriver( PData )^.OutputFinalized( DriverIndex, ErrorCode );
END OutputFinalizedW;

//================================================================================

PROCEDURE __INIT( _HInstance : windows.HINSTANCE );
BEGIN
  // common linked module
  FIO.InitModule();
  Storage.InitModule();
  Str.InitModule();
  os.__INIT();
  Lib.RANDOMIZE();
  // self
  RefCount := 0;
  HInstance := _HInstance;
  // vwthread.__INIT( HInstance ); -- see MakeDriver
END __INIT;

PROCEDURE __DONE();
BEGIN
  // this cannot be called here -- see DisposeDriver
  // vwthread.__DONE( TRUE );
END __DONE;

//================================================================================

END PelcoD.