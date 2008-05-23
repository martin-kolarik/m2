IMPLEMENTATION MODULE LMS2xx;

(*# call( o_a_copy => off ) *)

//================================================================================
(*/* changes:


19.09.2004 -- V1.1, build

4.3.2006 (7)
6.3.2006 (2)
Blansko (9--17), z toho 2 PelcoD

19.4. (1), (2D)

FA 06-02 / 36,5 / 6 / 42,5

10.9.2007 started to SC codebase

1, 2, 2, 1, 21.9.8-12 Blansko + cesta

*/*)
//================================================================================

FROM Storage IMPORT
   ALLOCATE, DEALLOCATE, REALLOCATE, Fill, Zero;

FROM Strings IMPORT
   LowerizeW;

IMPORT
   windows,
   winerror;

IMPORT
   cllv,
   FIO,
   lec,
   list,
   INIFile,
   Languages,
   Log,
   msghandler,
   Resources,
   OSALmsg,
   scinit,
   serial,
   StorageO,
   Strings,
   StringsO,
   Sync,
   Texts,
   time;

//================================================================================

CONST
  tiRx   = 1;
  tiScan = 2;

//================================================================================

CONST // device specific error codes
  ceRxTimeout               = drv_def.ecCommunicationTimeout;
  ceDeviceStopped           = 10001H;
  ceDeviceNotFound          = 10002H;
  ceDeviceInUnsupportedMode = 10003H;

//================================================================================

CONST // driver channels
  chStatus        = 1;
  chMode          = 2;
  chFieldSet      = 3;
  chScanningAngle = 4;
  chResolution    = 5;

  chMean          = 10;
  chCurrent       = 11;

  chFS1A          = 100;
  chFS1B          = 101;
  chFS1C          = 102;

  chFS2A          = 200;
  chFS2B          = 201;
  chFS2C          = 202;

//================================================================================

TYPE
  TPDriver = POINTER TO CDriver;

  TRStatusItem  = (
    rsSerialInitialized,
    rsRunning,
    rsDeviceError,
    rsEventsReportPending,

    rsRxTimeout,
    rsWaitACK,
    rsWaitResponse,
    rsHaveData,
    rsOOBScan
  );
  TRStatus = SET OF TRStatusItem;

CONST
  rssPending = TRStatus{rsWaitACK, rsWaitResponse};
  rssUser    = TRStatus{rsSerialInitialized, rsRunning, rsDeviceError, rsEventsReportPending};

TYPE
  TEvent = (
    evUnknown,
    evSetOff,
    evMovement,
    evFinish
  );
  TEventType = (
    etUnknown,
    etField,
    etZone
  );

//--------------------------------------------------------------------------------

(*# save, option( pack => 1 ) *)
TYPE
  TFrame     = RECORD
                 Address : CARD8;
                 Len     : CARD16;
                 Cmd     : CARD8;
               END;
  TPFrame    = POINTER TO TFrame;

  TOutFrame  = RECORD
                 F : TFrame;
                 D : ARRAY [0..27] OF WORD;
               END;
  TPOutFrame = POINTER TO TOutFrame;

  TInFrame   = RECORD
                 F : TFrame;
                 D : ARRAY [0..1019] OF WORD;
               END;
  TPInFrame  = POINTER TO TInFrame;
(*# restore *)

CONST
  DataCount = 4*180+1;

TYPE
  TData = ARRAY [0..DataCount-1] OF INTEGER;

TYPE
  TOperationState = (
    osUnknown,
    osFailure,
    osTick,
    osInit,
    osHaveStatus,
    osRunning1,
    osRunning2,
    osIdle
  );

//--------------------------------------------------------------------------------

CLASS CCCTSerial( serial.CSerialHandler );
  PDriver : TPDriver;
  
  VIRTUAL PROCEDURE OnRxTick();
  INTERNAL VIRTUAL PROCEDURE DetectDataStart( CONST Data : StorageO.AMemoryBuffer; OUT FrameStart, DataStart : CARDINAL ) : BOOLEAN;
  INTERNAL VIRTUAL PROCEDURE DataComplete( CONST Data : StorageO.AMemoryBuffer; OUT FirstIndexAfterData, FirstIndexAfterFrame : CARDINAL; OUT ApplyCheckSum : BOOLEAN ) : BOOLEAN;

  VIRTUAL PROCEDURE OnRx( Result : Sync.TAsyncResult; CONST Data : StorageO.AMemoryBuffer );
  VIRTUAL PROCEDURE OnTx( Result : Sync.TAsyncResult );

  VIRTUAL PROCEDURE AddChkSum( REF Data : StorageO.AMemoryBuffer );
  VIRTUAL PROCEDURE TestChkSum( CONST Data : StorageO.AMemoryBuffer ) : BOOLEAN;

  PROCEDURE ComputeChkSum( A : ADDRESS; L : CARDINAL ) : CARD16;
END CCCTSerial;

//--------------------------------------------------------------------------------

TYPE
  TPZone = POINTER TO CZone;

CLASS CZone( list.CListElem );
  Id                : ARRAY [0..63] OF WCHAR;

  Active            : BOOLEAN;
  DoNear            : BOOLEAN;
  DoFar             : BOOLEAN;
  From              : INTEGER;
  To                : INTEGER;
  NearCutOff        : INTEGER;
  FarCutOff         : INTEGER;

  MeanCount         : INTEGER;
  NAVG              : INTEGER;

  FarLimit          : INTEGER;
  NearLimit         : INTEGER;
  ActiveThreshold   : INTEGER; // count of active beams which must be reached to set off alarm
  CountThreshold    : INTEGER; // count of consecutive beam alarms, which must be reached to set off this beam active
  GapThreshold      : INTEGER; // count of inactive samples, which cannot reset alarm
  MovementThreshold : INTEGER; // distance of alarm center, which makes new (another) alarm

  Data              : TData;
  C                 : TData; // count, for CountThreshold
  A                 : TData; // active id
END CZone;

//--------------------------------------------------------------------------------

CLASS CDriver( msghandler.MessageHandler );
  RStatus                  : TRStatus;
  OS                       : TOperationState;
  Name                     : ARRAY [0..63] OF WCHAR;
  _Lock					   : Sync.LOCK;

  CallbackId               : ADDRESS;
  CallbackProc             : drv_def.TDriverCallbackW;
  RunMode                  : CARDINAL;
  RateTimer                : CARDINAL;
  Result                   : lec.CResult;

  RxTimeoutPeriod          : CARDINAL;
  RxTimeoutTime            : CARDINAL;

  // driver data
  Serial                   : CCCTSerial;
  RxACKTimeout             : CARDINAL;
  RxSafetyTimeout          : CARDINAL;
  Expect                   : CARD8;
  LastErrorCode            : CARDINAL;
  // CurrentFieldSet          : CARDINAL;
  // CurrentFieldIndex        : CARDINAL;

  Address                  : CARD8;
  ScanPeriod               : CARDINAL;
  ScanFactor               : CARDINAL;
  FactorCount              : CARDINAL;

  ScanMode                 : CARDINAL;
  ValueMode                : CARDINAL;
  ScanningAngle            : CARDINAL;
  Resolution               : LONGREAL;
  ActiveFieldSet           : CARDINAL;
  Fields                   : ARRAY [1..2], ['A'..'C'] OF BOOLEAN;
  FieldsPrevious           : ARRAY [1..2], ['A'..'C'] OF BOOLEAN;

  CurrentData              : TData;
  DiffData                 : TData;
  MeanData                 : TData;
  NAVG                     : INTEGER;
  MeanCount                : INTEGER;
  CurrentId                : INTEGER;
  MeanLocked               : BOOLEAN;

  PCurrentDataChannel      : ADDRESS;
  PMeanDataChannel         : ADDRESS;
  Zones                    : list.CList;
  EditZone                 : CZone;
  CurrentZone              : TPZone;

  Events                   : list.CList;

  // inherited
  INTERNAL VIRTUAL PROCEDURE OnTimer( Timer : PTR );

  // binding to procedural interface
  PUBLIC PROCEDURE Init( RunMode : CARDINAL; VAR SymbolicName : ARRAY OF WCHAR; CallbackId : ADDRESS; PCallback : drv_def.TDriverCallbackW ) : BOOLEAN;
  PUBLIC PROCEDURE ReadParameters( VAR ParFilePath, ErrorMessage : ARRAY OF WCHAR; VAR ErrorLine, ErrorColumn : CARDINAL; VAR HintOrHelp : ARRAY OF WCHAR ) : BOOLEAN;
  PUBLIC PROCEDURE EnumerateChannels(  VAR EnumerateState : LONGWORD; VAR Type : CARDINAL; VAR Direction : CARDINAL; VAR DriverIndex : CARDINAL; VAR Count : CARDINAL; VAR HaveDescription : BOOLEAN ): BOOLEAN;

  PUBLIC PROCEDURE BufferInfo( DriverIndex : CARDINAL; BType : CARD8; BLen : CARDINAL ) : BOOLEAN;
  PUBLIC PROCEDURE SetBufferAddr( DriverIndex : CARDINAL; PBuffer : ADDRESS );
  
  PUBLIC PROCEDURE Lock();
  PUBLIC PROCEDURE Unlock();

  PUBLIC PROCEDURE Run();
  PUBLIC PROCEDURE Stop();
  PUBLIC PROCEDURE Done();

  PUBLIC PROCEDURE QueryProc( UFlag : BOOLEAN; InValue1, InValue2 : drv_def.TValue; VAR OutValue : drv_def.TValue );

  PUBLIC PROCEDURE InputRequestStart();
  PUBLIC PROCEDURE InputRequest( DriverIndex : CARDINAL );
  PUBLIC PROCEDURE InputRequestCompleted();
  PUBLIC PROCEDURE InputFinalized( DriverIndex : CARDINAL; VAR ErrorCode : CARDINAL ) : BOOLEAN;
  PUBLIC PROCEDURE InputOOBDataQuery( VAR EnumerateState : LONGWORD; VAR DriverIndex : CARDINAL ) : BOOLEAN;
  PUBLIC PROCEDURE GetInput( UFlag : BOOLEAN; DriverIndex : CARDINAL; VAR InValue : drv_def.TValue; VAR QoS : CARDINAL; VAR TimeStamp : drv_def.TUTCStamp; VAR ErrorCode : CARDINAL );

  PUBLIC PROCEDURE OutputRequestStart();
  PUBLIC PROCEDURE OutputRequest( UFlag : BOOLEAN; DriverIndex : CARDINAL; OutValue : drv_def.TValue; QoS : CARDINAL; TimeStamp : drv_def.TUTCStamp );
  PUBLIC PROCEDURE OutputRequestCompleted();
  PUBLIC PROCEDURE OutputFinalized( DriverIndex : CARDINAL; VAR ErrorCode : CARDINAL ) : BOOLEAN;

  // callbacks
  LOCAL PROCEDURE OnRxTick();
  LOCAL PROCEDURE OnReceive( Result : Sync.TAsyncResult; CONST Data : StorageO.AMemoryBuffer );
  LOCAL PROCEDURE OnSend( Result : Sync.TAsyncResult );

  // data
  PROCEDURE Automaton( NewState : TOperationState );
  PROCEDURE ParseData( PData : TPInFrame; L :  CARDINAL );
  PROCEDURE AddEvent( Zone : TPZone; Event : TEvent; Type : TEventType; Angle : CARDINAL; Id, Mean, Diff : INTEGER );

  // helpers
  PROCEDURE InitToDefault();
  PROCEDURE SetRxTimeout( RxDataTimeout, AddOn : CARDINAL );
  PROCEDURE ResetRxTimeout();
  PROCEDURE CopyToBuffers();
  PROCEDURE CheckZones();
END CDriver;

//--------------------------------------------------------------------------------

TYPE
  TPEventListElem = POINTER TO CEventListElem;

CLASS CEventListElem( list.CListElem );
  Zone  : TPZone;
  Event : TEvent;
  Type  : TEventType;
  Angle : CARDINAL;
  Id    : INTEGER;
  Mean  : INTEGER;
  Diff  : INTEGER;
END CEventListElem;

//================================================================================

CLASS IMPLEMENTATION CCCTSerial;

//--------------------------------------------------------------------------------

  VIRTUAL PROCEDURE OnRxTick();
  BEGIN
	PDriver^.Lock();
    PDriver^.OnRxTick();
	PDriver^.Unlock();
  END OnRxTick;

//--------------------------------------------------------------------------------

  INTERNAL VIRTUAL PROCEDURE DetectDataStart( CONST Data : StorageO.AMemoryBuffer; OUT FrameStart, DataStart : CARDINAL ) : BOOLEAN;
  VAR
    f1, f2, f3 : CARDINAL;
    L : CARDINAL := Data.Length;
  BEGIN
    IF L < 1 THEN
      RETURN FALSE;
    END;

    f1 := Data.IndexOfByte( 06H, 0 ); // ACK
    f2 := Data.IndexOfByte( 015H, 0 ); // NAK
    f3 := Data.IndexOfByte( 02H, 0 ); // STX

    IF ( f1 < f2 ) AND ( f1 < f3 ) THEN
      FrameStart := f1;
      DataStart := FrameStart;
    ELSIF ( f2 < f3 ) AND ( f2 < f1 ) THEN
      FrameStart := f2;
      DataStart := FrameStart;
    ELSIF ( f3 < f1 ) AND ( f3 < f2 ) THEN
      FrameStart := f3;
      DataStart := FrameStart + 1;
    ELSE
      RETURN FALSE;
    END;

    RETURN TRUE;
  END DetectDataStart;

//---------------------------------------------------------

  INTERNAL VIRTUAL PROCEDURE DataComplete( CONST Data : StorageO.AMemoryBuffer; OUT FirstIndexAfterData, FirstIndexAfterFrame : CARDINAL; OUT ApplyCheckSum : BOOLEAN ) : BOOLEAN;
  VAR
    A : ADDRESS := Data.Data;
    L : CARDINAL := Data.Length;
  BEGIN
    IF L > 0 THEN
      IF PCARD8( A )^ = 06H THEN // ACK
        ApplyCheckSum := FALSE;
        FirstIndexAfterData := 1;
        FirstIndexAfterFrame := 1;
        RETURN TRUE;
      ELSIF PCARD8( A )^ = 015H THEN // NAK
        ApplyCheckSum := FALSE;
        FirstIndexAfterData := 1;
        FirstIndexAfterFrame := 1;
        RETURN TRUE;
      ELSIF PCARD8( A )^ = 002H THEN // STX
        INC( A );
      ELSE
        RETURN FALSE;
      END;
    END;
    IF L < 4 THEN
      RETURN FALSE;
    ELSIF L < CARDINAL( TPFrame( A )^.Len ) + 6 THEN
      RETURN FALSE;
    END;
    ApplyCheckSum := TRUE;
    FirstIndexAfterData := CARDINAL( TPFrame( A )^.Len ) + 6;
    FirstIndexAfterFrame := FirstIndexAfterData;
    RETURN TRUE;
  END DataComplete;

//--------------------------------------------------------------------------------

  VIRTUAL PROCEDURE OnRx( Result : Sync.TAsyncResult; CONST Data : StorageO.AMemoryBuffer );
  BEGIN
	PDriver^.Lock();
    PDriver^.OnReceive( Result, Data );
	PDriver^.Unlock();
  END OnRx;

//--------------------------------------------------------------------------------

  VIRTUAL PROCEDURE OnTx( Result : Sync.TAsyncResult );
  BEGIN
	PDriver^.Lock();
    PDriver^.OnSend( Result );
	PDriver^.Unlock();
  END OnTx;

//--------------------------------------------------------------------------------

  VIRTUAL PROCEDURE AddChkSum( REF Data : StorageO.AMemoryBuffer );
  VAR
    A : ADDRESS := Data.Data;
    CRC : CARD16;
    L : CARDINAL := Data.Length;
  BEGIN
    CRC := ComputeChkSum( A, L );
    Data.AppendByte( CARD8( CRC AND 0FFH ));
    Data.AppendByte( CARD8( CRC >> 8 ));
  END AddChkSum;

//--------------------------------------------------------------------------------

  VIRTUAL PROCEDURE TestChkSum( CONST Data : StorageO.AMemoryBuffer ) : BOOLEAN; // success, ecChkSumFailure
  VAR
    A : ADDRESS := Data.Data;
    CRC : CARD16;
    L : CARDINAL := Data.Length;
  BEGIN
    DEC( L, 2 );
    CRC := ComputeChkSum( A, L );
    IF PCARD8( A@[L] )^ <> CARD8( CRC AND 0FFH ) THEN
      RETURN FALSE;
    ELSIF PCARD8( A@[L+1] )^ <> CARD8(( CRC AND 0FF00H ) >> 8 ) THEN
      RETURN FALSE;
    ELSE
      RETURN TRUE;
    END;
  END TestChkSum;

//--------------------------------------------------------------------------------

  PROCEDURE ComputeChkSum( A : ADDRESS; L : CARDINAL ) : CARD16;
  VAR
    CRC : CARD16;
    HI  : CARD8;
    LO  : CARD8;
  BEGIN
    CRC := 0;
    LO := 0;

    WHILE L > 0 DO
      HI := LO;
      LO := PCARD8( A )^;

      DEC( L );
      INC( A );

      IF CRC AND 08000H = 0 THEN
        CRC := CRC << 1;
      ELSE
        CRC := ( CRC AND 07FFFH ) << 1;
        CRC := CARD16( BITSET16( CRC ) / BITSET16( 08005H ));
      END;

      CRC := CARD16( BITSET16( CRC ) / BITSET16( CARD16( HI ) << 8 + CARD16( LO )));
    END; // WHILE

    RETURN CRC;
  END ComputeChkSum;

//--------------------------------------------------------------------------------

BEGIN
  PDriver := NIL;
END CCCTSerial;

//================================================================================

CLASS IMPLEMENTATION CZone;
BEGIN
  Active := FALSE;
  DoNear := TRUE;
  DoFar := TRUE;

  From := 0;
  To := DataCount-1;
  NearCutOff := 0;
  FarCutOff := MAX( INTEGER );
                                 
  Zero( ADR( Data ), SIZE( Data ));
  Zero( ADR( C ), SIZE( C ));
  Zero( ADR( A ), SIZE( A ));

  MeanCount := 1;
  NAVG := 0;

  FarLimit := 100;
  NearLimit := -50;
  Id := 0W;
  ActiveThreshold := 5;
  CountThreshold := 1;
  GapThreshold := 1;
  MovementThreshold := 15;
END CZone;

//--------------------------------------------------------------------------------

VAR
   GR : Resources.CResources;
   RefCount : CARDINAL;

//--------------------------------------------------------------------------------

CLASS IMPLEMENTATION CDriver;

//--------------------------------------------------------------------------------

   INTERNAL VIRTUAL PROCEDURE OnTimer( Timer : PTR );
   BEGIN
      CASE Timer OF
      | tiRx :
         IF ( rsRxTimeout IN RStatus ) AND ( INTEGER( time.UptimeMS() - RxTimeoutTime ) > 0 ) THEN
            OnReceive( Sync.arTimeout, StorageO.TPMemoryBuffer( NIL )^ );
         END;
      | tiScan :
         Automaton( osTick );
      END; // CASE
   END OnTimer;

//--------------------------------------------------------------------------------

  PUBLIC PROCEDURE Init( _RunMode : CARDINAL; VAR SymbolicName : ARRAY OF WCHAR; _CallbackId : ADDRESS; PCallback : drv_def.TDriverCallbackW ) : BOOLEAN;
  BEGIN
    SUPER.Init( TRUE );

    CallbackId := _CallbackId;
    CallbackProc := PCallback;
    RunMode := _RunMode;
    ASSIGN( Name, SymbolicName );

    RETURN TRUE;
  END Init;

//--------------------------------------------------------------------------------

  PUBLIC PROCEDURE ReadParameters( VAR ParFilePath, ErrorMessage : ARRAY OF WCHAR; VAR ErrorLine, ErrorColumn : CARDINAL; VAR HintOrHelp : ARRAY OF WCHAR ) : BOOLEAN;
  LABEL
    Fail;
  CONST
    // .PAR section names 
    snDevice               = L'LMS2xx';
    // .PAR key names
    knComDriver            = L'com_driver';
    knACKTimeout           = L'ACK_timeout';
    knSafetyTimeout        = L'timeout';
    knReadBack             = L'read_back';
    knAddress              = L'address';
    knScanRate             = L'scan_period';
    knScanFactor           = L'scan_factor';
    knMeanCount            = L'mean_count';
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
      Strings.AppendW( REF ErrorMessage, L' (' );
      Strings.AppendW( REF ErrorMessage, ErrorId );
      Strings.AppendW( REF ErrorMessage, L')' );
    END AppendErrorId;

  //----------

   CONST
      delimSC = StringsO.WCHARS{ L' ', L',' };
  VAR
    c : CARDINAL;
    ComChannel : ARRAY [0..63] OF WCHAR;
    ComDriver : ARRAY [0..63] OF WCHAR;
    DebugFile : FIO.PathStrW;
    DebugLevel : Log.TDebugLevel;
    DebugMode : Log.TDebugMethod;
    so : StringsO.CString;
    TS : INIFile.CINIFile;
    ReadBack : BOOLEAN;
  BEGIN
    HintOrHelp[0] := WCHAR( 0 );

    IF NOT TS.LoadPath( ParFilePath ) THEN
      ASSIGNsz( ErrorMessage, GR[Texts._CannotOpenPar] );
      AppendErrorId( ErrorMessage, ParFilePath );
      GOTO Fail;
    END;

    InitToDefault();
    ComChannel := L'';
    ComDriver := L'';
    DebugMode := Log.dmNone;
    DebugLevel := Log.dldError;
    ReadBack := FALSE;

    IF NOT TS.SetSection( snDevice ) THEN
      IF RunMode = drv_def.drmRun THEN
        ASSIGNsz( ErrorMessage, GR[Texts._MissingDeviceSection] );
        GOTO Fail;
      ELSE
        RETURN TRUE;
      END;
    END;

    IF NOT TS.GetKeyStr( knComDriver, OUT ErrorLine, OUT so ) THEN
      ASSIGNsz( ErrorMessage, GR[Texts._MissingDevice] );
      GOTO Fail;
    END;
    so.ItemSOA( delimSC, 0, 0, TRUE, OUT ComDriver );
    so.ItemSOA( delimSC, 0, 1, TRUE, OUT ComChannel );
    IF ( ComDriver[0] = WCHAR( 0 )) OR ( ComChannel[0] = WCHAR( 0 )) THEN
      ASSIGNsz( ErrorMessage, GR[Texts._DeviceDefinitionIsBad] );
      GOTO Fail;
    END;

    TS.GetKeyInt( knACKTimeout, OUT ErrorLine, OUT RxACKTimeout );
    TS.GetKeyInt( knSafetyTimeout, OUT ErrorLine, OUT RxSafetyTimeout );
    TS.GetKeyBool( knReadBack, OUT ErrorLine, OUT ReadBack );

    IF TS.GetKeyInt( knAddress, OUT ErrorLine, OUT c ) THEN
      Address := CARD8( c );
    END;
    IF TS.GetKeyInt( knScanRate, OUT ErrorLine, OUT c ) THEN
      ScanPeriod := c;
    END;
    IF TS.GetKeyInt( knScanFactor, OUT ErrorLine, OUT c ) THEN
      ScanFactor := c;
    END;

    IF TS.GetKeyInt( knMeanCount, OUT ErrorLine, OUT c ) AND ( c > 0 ) THEN
      MeanCount := c;
    END;

    IF TS.GetKeyStr( knDebugMode, OUT ErrorLine, OUT so ) THEN
      IF so.EqualsOA( kvDebugNone ) THEN
        DebugMode := Log.dmNone;
      ELSIF so.EqualsOA( kvDebugFile ) THEN
        DebugMode := Log.dmFile;
        IF NOT TS.GetKeyStr( knDebugFile, OUT ErrorLine, OUT so ) THEN
          ASSIGNsz( ErrorMessage, GR[Texts._FileDebugMissingFile] );
          GOTO Fail;
        END;
        so.ToOA( OUT DebugFile );
      ELSIF so.EqualsOA( kvDebugKernel ) THEN
        DebugMode := Log.dmKernel;
      END;
      IF DebugMode <> Log.dmNone THEN
        IF TS.GetKeyStr( knDebugLevel, OUT ErrorLine, OUT so ) THEN
          IF so.EqualsOA( kvDebugBasic ) THEN
            DebugLevel := Log.dldError;
          ELSIF so.EqualsOA( kvDebugExtended ) THEN
            DebugLevel := Log.dldTrace;
          ELSIF so.EqualsOA( kvDebugAll ) THEN
            DebugLevel := Log.dldDebug;
          END;
        END;
      END;
    END;

    IF RunMode = drv_def.drmRun THEN
      INCL( RStatus, rsSerialInitialized );

      Serial.ReadBack := ReadBack;
      // Serial.SetInBoundaryStrings( CHAR( 2 ), C'' );
      Serial.SetOutBoundaryStrings( CHAR( 2 ), C'' );

      Serial.Logger.SetLogFile( DebugFile );
      Serial.Logger.Method := DebugMode;
      Serial.Logger.Level := DebugLevel;

      RETURN Serial.Init( Name, ComChannel, ComDriver, ParFilePath, NIL );
    ELSE
      RETURN TRUE;
    END;

  Fail:
    RETURN FALSE;
  END ReadParameters;

//--------------------------------------------------------------------------------

  PUBLIC PROCEDURE EnumerateChannels( VAR EnumerateState : LONGWORD; VAR Type : CARDINAL; VAR Direction : CARDINAL; VAR DriverIndex : CARDINAL; VAR Count : CARDINAL; VAR HaveDescription : BOOLEAN ): BOOLEAN;
  BEGIN
    CASE CARDINAL( EnumerateState ) OF
    | 0 : // status channel
      Direction := CARDINAL( drv_def.TDirection{drv_def.dirInput} );
      DriverIndex := chStatus;
      Type := CARDINAL( drv_def.vtLongCard );
    | 1 : // status channel
      Direction := CARDINAL( drv_def.TDirection{drv_def.dirInput} );
      DriverIndex := chMode;
      Type := CARDINAL( drv_def.vtLongCard );
    | 2 : // active field set
      Direction := CARDINAL( drv_def.TDirection{drv_def.dirInput} );
      DriverIndex := chFieldSet;
      Type := CARDINAL( drv_def.vtLongCard );
    | 3 : // scanning angle
      Direction := CARDINAL( drv_def.TDirection{drv_def.dirInput} );
      DriverIndex := chScanningAngle;
      Type := CARDINAL( drv_def.vtLongCard );
    | 4 : // resolution
      Direction := CARDINAL( drv_def.TDirection{drv_def.dirInput} );
      DriverIndex := chResolution;
      Type := CARDINAL( drv_def.vtLongReal );
    | 5 : // mean value channel
      Direction := CARDINAL( drv_def.TDirection{drv_def.dirInput} );
      DriverIndex := chMean;
      Type := CARDINAL( drv_def.vtBuffer );
    | 6 : // current value channel
      Direction := CARDINAL( drv_def.TDirection{drv_def.dirInput} );
      DriverIndex := chCurrent;
      Type := CARDINAL( drv_def.vtBuffer );
    | 7 : // field set 1 field A status
      Direction := CARDINAL( drv_def.TDirection{drv_def.dirInput} );
      DriverIndex := chFS1A;
      Type := CARDINAL( drv_def.vtBoolean );
    | 8 : // field set 1 field B status
      Direction := CARDINAL( drv_def.TDirection{drv_def.dirInput} );
      DriverIndex := chFS1B;
      Type := CARDINAL( drv_def.vtBoolean );
    | 9 : // field set 1 field C status
      Direction := CARDINAL( drv_def.TDirection{drv_def.dirInput} );
      DriverIndex := chFS1C;
      Type := CARDINAL( drv_def.vtBoolean );
    | 10 : // field set 2 field A status
      Direction := CARDINAL( drv_def.TDirection{drv_def.dirInput} );
      DriverIndex := chFS2A;
      Type := CARDINAL( drv_def.vtBoolean );
    | 11 : // field set 2 field B status
      Direction := CARDINAL( drv_def.TDirection{drv_def.dirInput} );
      DriverIndex := chFS2B;
      Type := CARDINAL( drv_def.vtBoolean );
    | 12 : // field set 2 field C status
      Direction := CARDINAL( drv_def.TDirection{drv_def.dirInput} );
      DriverIndex := chFS2C;
      Type := CARDINAL( drv_def.vtBoolean );
    ELSE
      RETURN FALSE;
    END;

    Count := 1;
    HaveDescription := FALSE;
    INC( EnumerateState );

    RETURN TRUE;
  END EnumerateChannels;

//--------------------------------------------------------------------------------

  PUBLIC PROCEDURE BufferInfo( DriverIndex : CARDINAL; BType : CARD8; BLen : CARDINAL ) : BOOLEAN;
  BEGIN
    IF ( DriverIndex <> chMean ) AND ( DriverIndex <> chCurrent ) THEN
      RETURN FALSE;
    ELSIF BType <> CARD8( drv_def.vtLongCard ) THEN
      RETURN FALSE;
    ELSIF BLen < SIZE( TData ) + SIZE( drv_def.TBufferHeader ) THEN
      RETURN FALSE;
    END;
    RETURN TRUE;
  END BufferInfo;

//--------------------------------------------------------------------------------

  PUBLIC PROCEDURE SetBufferAddr( DriverIndex : CARDINAL; PBuffer : ADDRESS );
  BEGIN
    IF DriverIndex = chMean THEN
      PMeanDataChannel := PBuffer;
    ELSE
      PCurrentDataChannel := PBuffer;
    END;
  END SetBufferAddr;

//--------------------------------------------------------------------------------

  PUBLIC PROCEDURE Lock();
  BEGIN
	_Lock.Lock();
  END Lock;

//--------------------------------------------------------------------------------

  PUBLIC PROCEDURE Unlock();
  BEGIN
	_Lock.Unlock();
  END Unlock;

//--------------------------------------------------------------------------------

  PUBLIC PROCEDURE Run();
  VAR
    s : FIO.PathStrW;
  BEGIN
    Result.Reset( lec.bhBestCase );
    FIO.GetModuleDirW( EMITW( %dll ), OUT s );
    lec.QueryData( s, L"", ADR( cllv.data ), cllv.length, REF Result );

    Serial.Run();
    IF RateTimer = 0 THEN
      RateTimer := 1;
      StartTimer( tiScan, ScanPeriod, TRUE );
      FactorCount := ScanFactor;
    END;
    IF PMeanDataChannel <> NIL THEN
      drv_def.TPBufferHeader( PMeanDataChannel )^.NumSamples := DataCount;
    END;
    IF PCurrentDataChannel <> NIL THEN
      drv_def.TPBufferHeader( PCurrentDataChannel )^.NumSamples := DataCount;
    END;
    INCL( RStatus, rsRunning );

    Automaton( osInit );
  END Run;

//--------------------------------------------------------------------------------

  PUBLIC PROCEDURE Stop();
  BEGIN
    EXCL( RStatus, rsRunning );
    IF RateTimer <> 0 THEN
      StopTimer( tiScan );
      RateTimer := 0;
    END;
    Serial.Stop();
  END Stop;

//--------------------------------------------------------------------------------

  PUBLIC PROCEDURE Done();
  BEGIN
    Events.Dispose();
    Zones.Dispose();
    IF rsSerialInitialized IN RStatus THEN
      Serial.Dispose();
    END;
    SUPER.Dispose();
  END Done;

//--------------------------------------------------------------------------------

  PUBLIC PROCEDURE QueryProc( UFlag : BOOLEAN; InValue1, InValue2 : drv_def.TValue; VAR OutValue : drv_def.TValue );
  LABEL
    Error;
  CONST
    delimS = StringsO.WCHARS{ L' ' };
    delimSC = StringsO.WCHARS{ L' ', L',' };
  VAR
    A : LONGREAL;
    c : CARDINAL;
    d : INTEGER;
    DSW : StringsO.CString;
    i : CARDINAL;
    N : ARRAY [0..31] OF WCHAR;
    lr : LONGREAL;
    MSG : msghandler.Message;
    PELE : TPEventListElem;
    R : ARRAY [0..255] OF WCHAR;
    Zone : TPZone;
    b : BOOLEAN;
  BEGIN
    drv_def.DrvValueToCStringW( InValue1, UFlag, OUT DSW );
    DSW.ItemSOA( delimS, 0, 0, TRUE, OUT N );

    IF EQUALS( N, L'reset' ) THEN
      NAVG := 0;
      DSW.Clear();
	  GOTO Error;
    ELSIF EQUALS( N, L'scan' ) THEN
      INCL( RStatus, rsOOBScan );
      MSG.Message := msghandler.RAW_MSG_BASE + OSALmsg.RAW_MESSAGE_ONTIMER;
      Message( MSG, msghandler.delAsynchronous, NIL );
      DSW.Clear();
	  GOTO Error;
    ELSIF EQUALS( N, L'lock_mean' ) THEN
      DSW.ItemSOA( delimS, 0, 1, TRUE, OUT N ); LOW( N );
      MeanLocked := EQUALS( N, L'true' );
      DSW.Clear();
	  GOTO Error;
    ELSIF EQUALS( N, L'mean_locked' ) THEN
	  IF MeanLocked THEN
	    DSW.FromOA( L'true' );
	  ELSE
	    DSW.FromOA( L'false' );
	  END;
	  GOTO Error;
    
    ELSIF EQUALS( N, L'get_event' ) THEN
      // get event, fall down
      IF Result.Counted OR Result.Expired THEN
        Events.Dispose();
        DSW.Clear();
        GOTO Error;
      END;
      
    ELSIF EQUALS( N, L'debug' ) THEN
      // debug
      drv_def.DrvValueToCStringW( InValue2, UFlag, OUT DSW );
      FOR i := 0 TO DataCount-1 DO
        DSW.ItemSOA( delimSC, 0, i, TRUE, OUT N );
        IF Strings.ToINT32W( N, 10, OUT d ) THEN
          DiffData[i] := d;
        ELSE
          DiffData[i] := 0;
        END;
      END;
      i := Events.Count;
      CheckZones();
      IF ( i < Events.Count ) AND NOT( rsEventsReportPending IN RStatus ) THEN
        INCL( RStatus, rsEventsReportPending );
        CallbackProc( CallbackId, drv_def.dcfException, NIL );
      END;
      RETURN;
    ELSIF EQUALS( N, L'zone' ) THEN
      // zone
      DSW.ItemSOA( delimS, 0, 1, TRUE, OUT N ); LOW( N );
      DSW.ItemSOA( delimS, 0, 2, TRUE, OUT R ); LOW( R );

      IF EQUALS( N, L'create' ) THEN
        b := Zones.GetFirst( OUT Zone );
        LOOP
          IF NOT b THEN
            NEW( Zone );
            ASSIGN( Zone^.Id, R );
            Zones.Append( Zone );
            EditZone := Zone^;
            CurrentZone := Zone;
            EXIT;
          ELSIF EQUALS( Zone^.Id, R ) THEN
            DSW.FromOA( L'error: zone exists' );
            GOTO Error;
          END;
          b := Zones.NextOf( Zone, OUT Zone );
        END; // LOOP

      ELSIF EQUALS( N, L'change' ) THEN
        b := Zones.GetFirst( OUT Zone );
        LOOP
          IF NOT b THEN
            DSW.FromOA( L'error: zone not found' );
            GOTO Error;
          ELSIF EQUALS( Zone^.Id, R ) THEN
            EditZone := Zone^;
            CurrentZone := Zone;
            EXIT;
          END;
          b := Zones.NextOf( Zone, OUT Zone );
        END; // LOOP

      ELSIF EQUALS( N, L'remove' ) THEN
        CurrentZone := NIL;
        b := Zones.GetFirst( OUT Zone );
        LOOP
          IF NOT b THEN
            DSW.FromOA( L'error: zone not found' );
            GOTO Error;
          ELSIF EQUALS( Zone^.Id, R ) THEN
            Zones.Delete( Zone );
            EXIT;
          END;
          b := Zones.NextOf( Zone, OUT Zone );
        END; // LOOP

      ELSIF EQUALS( N, L'copy_from' ) THEN
        b := Zones.GetFirst( OUT Zone );
        LOOP
          IF NOT b THEN
            DSW.FromOA( L'error: zone to copy from not found' );
            GOTO Error;
          ELSIF EQUALS( Zone^.Id, R ) THEN
            EditZone := Zone^;
            EXIT;
          END;
          b := Zones.NextOf( Zone, OUT Zone );
        END; // LOOP

      ELSIF EQUALS( N, L'commit' ) THEN
        IF CurrentZone = NIL THEN
          DSW.FromOA( L'error: no zone is edited' );
          GOTO Error;
        END;
        EditZone.Id := CurrentZone^.Id;
        CurrentZone^ := EditZone;
        CurrentZone := NIL;

      ELSIF EQUALS( N, L'abort' ) THEN
        IF CurrentZone = NIL THEN
          DSW.FromOA( L'error: no zone is edited' );
          GOTO Error;
        END;
        CurrentZone := NIL;

      ELSIF EQUALS( N, L'switch' ) THEN
        IF CurrentZone = NIL THEN
          DSW.FromOA( L'error: no zone is edited' );
          GOTO Error;
        END;
        IF EQUALS( R, L'on' ) THEN
          EditZone.Active := TRUE;
        ELSE
          EditZone.Active := FALSE;
        END;

      ELSIF EQUALS( N, L'switch_near' ) THEN
        IF CurrentZone = NIL THEN
          DSW.FromOA( L'error: no zone is edited' );
          GOTO Error;
        END;
        IF EQUALS( R, L'on' ) THEN
          EditZone.DoNear := TRUE;
        ELSE
          EditZone.DoNear := FALSE;
        END;

      ELSIF EQUALS( N, L'switch_far' ) THEN
        IF CurrentZone = NIL THEN
          DSW.FromOA( L'error: no zone is edited' );
          GOTO Error;
        END;
        IF EQUALS( R, L'on' ) THEN
          EditZone.DoFar := TRUE;
        ELSE
          EditZone.DoFar := FALSE;
        END;

      ELSIF EQUALS( N, L'angle_from' ) THEN
        IF CurrentZone = NIL THEN
          DSW.FromOA( L'error: no zone is edited' );
          GOTO Error;
        END;
        IF NOT Strings.ToCARD32W( R, 10, OUT c ) OR ( c > 180 ) THEN
          DSW.FromOA( L'error: bad angle number' );
          GOTO Error;
        END;
        EditZone.From := 4 * c;

      ELSIF EQUALS( N, L'angle_to' ) THEN
        IF CurrentZone = NIL THEN
          DSW.FromOA( L'error: no zone is edited' );
          GOTO Error;
        END;
        IF NOT Strings.ToCARD32W( R, 10, OUT c ) OR ( c > 180 ) THEN
          DSW.FromOA( L'error: bad angle number' );
          GOTO Error;
        END;
        EditZone.To := 4 * c;

      ELSIF EQUALS( N, L'distance_from' ) THEN
        IF CurrentZone = NIL THEN
          DSW.FromOA( L'error: no zone is edited' );
          GOTO Error;
        END;
        IF NOT Strings.ToCARD32W( R, 10, OUT c ) THEN
          DSW.FromOA( L'error: bad distance from number' );
          GOTO Error;
        END;
        EditZone.NearCutOff := c;

      ELSIF EQUALS( N, L'distance_to' ) THEN
        IF CurrentZone = NIL THEN
          DSW.FromOA( L'error: no zone is edited' );
          GOTO Error;
        END;
        IF NOT Strings.ToCARD32W( R, 10, OUT c ) THEN
          DSW.FromOA( L'error: bad distance to number' );
          GOTO Error;
        END;
        EditZone.FarCutOff := c;

      ELSIF EQUALS( N, L'mean_count' ) THEN
        IF CurrentZone = NIL THEN
          DSW.FromOA( L'error: no zone is edited' );
          GOTO Error;
        END;
        IF NOT Strings.ToCARD32W( R, 10, OUT c ) THEN
          DSW.FromOA( L'error: bad mean count number' );
          GOTO Error;
        END;
        EditZone.MeanCount := INTEGER( c );

      ELSIF EQUALS( N, L'far_limit' ) THEN
        IF CurrentZone = NIL THEN
          DSW.FromOA( L'error: no zone is edited' );
          GOTO Error;
        END;
        IF NOT Strings.ToCARD32W( R, 10, OUT c ) THEN
          DSW.FromOA( L'error: bad far limit number' );
          GOTO Error;
        END;
        EditZone.FarLimit := INTEGER( c );

      ELSIF EQUALS( N, L'near_limit' ) THEN
        IF CurrentZone = NIL THEN
          DSW.FromOA( L'error: no zone is edited' );
          GOTO Error;
        END;
        IF NOT Strings.ToCARD32W( R, 10, OUT c ) THEN
          DSW.FromOA( L'error: bad near limit number' );
          GOTO Error;
        END;
        EditZone.NearLimit := -INTEGER( c );

      ELSIF EQUALS( N, L'beam_count' ) THEN
        IF CurrentZone = NIL THEN
          DSW.FromOA( L'error: no zone is edited' );
          GOTO Error;
        END;
        IF NOT Strings.ToCARD32W( R, 10, OUT c ) THEN
          DSW.FromOA( L'error: bad beam count number' );
          GOTO Error;
        END;
        EditZone.ActiveThreshold := INTEGER( c );

      ELSIF EQUALS( N, L'beam_scan' ) THEN
        IF CurrentZone = NIL THEN
          DSW.FromOA( L'error: no zone is edited' );
          GOTO Error;
        END;
        IF NOT Strings.ToCARD32W( R, 10, OUT c ) OR ( c < 1 ) THEN
          DSW.FromOA( L'error: bad beam scan number' );
          GOTO Error;
        END;
        EditZone.CountThreshold := INTEGER( c );

      ELSIF EQUALS( N, L'gap_count' ) THEN
        IF CurrentZone = NIL THEN
          DSW.FromOA( L'error: no zone is edited' );
          GOTO Error;
        END;
        IF NOT Strings.ToCARD32W( R, 10, OUT c ) THEN
          DSW.FromOA( L'error: bad gap count number' );
          GOTO Error;
        END;
        EditZone.GapThreshold := INTEGER( c );

      ELSIF EQUALS( N, L'movement_threshold' ) THEN
        IF CurrentZone = NIL THEN
          DSW.FromOA( L'error: no zone is edited' );
          GOTO Error;
        END;
        IF NOT Strings.ToLONGREALW( R, OUT lr ) THEN
          DSW.FromOA( L'error: bad movement threshold number' );
          GOTO Error;
        END;
        EditZone.MovementThreshold := INTEGER( lr * 4.0 );

      ELSE
        DSW.FromOA( L'error: unrecognized zone command' );
        GOTO Error;
      END;

      DSW.FromOA( L'' );
      GOTO Error;

    ELSE
      DSW.FromOA( L'error: unrecognized driver command' );
      GOTO Error;
    END;

    EXCL( RStatus, rsEventsReportPending );
    R[0] := WCHAR( 0 );
    IF Events.GetFirst( OUT PELE ) THEN
      Events.Remove( PELE );

      i := 0;
      CASE PELE^.Event OF
      | evSetOff :
        R[i] := L'S';
      | evMovement :
        R[i] := L'M';
      | evFinish :
        R[i] := L'F';
      END;
      INC( i );
      R[i] := L':';
      INC( i );
      CASE PELE^.Type OF
      | etField :
        R[i] := L'F';
      | etZone :
        R[i] := L'Z';
      END;
      INC( i );
      CASE PELE^.Type OF
      | etField :
        R[i] := L':';
        INC( i );
        R[i] := WCHAR( 0 );
        Strings.FromCARD32W( PELE^.Angle, 10, OUT N );
        Strings.AppendW( REF R, N  );
      | etZone :
        R[i] := L'[';
        INC( i );
        R[i] := WCHAR( 0 );
        Strings.FromINT32W( PELE^.Id, 10, OUT N ); Strings.AppendW( REF R, N  );
        Strings.AppendW( REF R, L']:' );
        A := LONGREAL( PELE^.Angle ) / 4.0;
        Strings.FromLONGREALW( A, FALSE, OUT N ); Strings.AppendW( REF R, N  );
        Strings.AppendW( REF R, L':' );
        Strings.FromINT32W( PELE^.Mean, 10, OUT N ); Strings.AppendW( REF R, N  ); 
        Strings.AppendW( REF R, L'[' );
        Strings.FromINT32W( PELE^.Diff, 10, OUT N ); Strings.AppendW( REF R, N  );
        Strings.AppendW( REF R, L'] (' );
        Strings.AppendW( REF R, PELE^.Zone^.Id );
        Strings.AppendW( REF R, L')' );
      ELSE
        R[i] := L':';
        INC( i );
        R[i] := L'*';
        INC( i );
        R[i] := WCHAR( 0 );
      END;

      DISPOSE( PELE );
    END;

    Result.Inc();
    drv_def.AssignDrvValueStringW( OutValue, UFlag, TRUE, R );
    RETURN;

  Error:
    Result.Inc();
    drv_def.AssignDrvValueCStringW( REF OutValue, UFlag, TRUE, DSW );
  END QueryProc;

//--------------------------------------------------------------------------------

  PUBLIC PROCEDURE InputRequestStart();
  BEGIN
  END InputRequestStart;

//--------------------------------------------------------------------------------

  PUBLIC PROCEDURE InputRequest( DriverIndex : CARDINAL );
  BEGIN
  END InputRequest;

//--------------------------------------------------------------------------------

  PUBLIC PROCEDURE InputRequestCompleted();
  BEGIN
  END InputRequestCompleted;

//--------------------------------------------------------------------------------

  PUBLIC PROCEDURE InputFinalized( DriverIndex : CARDINAL; VAR ErrorCode : CARDINAL ) : BOOLEAN;
  BEGIN
    IF DriverIndex = chStatus THEN
      ErrorCode := 0;
    ELSIF NOT Serial.Running THEN
      ErrorCode := ceDeviceStopped;
    ELSIF OS = osFailure THEN
      ErrorCode := ceDeviceInUnsupportedMode;
    ELSIF rsDeviceError IN RStatus THEN
      ErrorCode := LastErrorCode;
    ELSIF OS < osRunning1 THEN
      ErrorCode := ceDeviceNotFound;
    ELSE
      ErrorCode := drv_def.ecSuccess;
    END;
    RETURN TRUE;
  END InputFinalized;

//--------------------------------------------------------------------------------

  PUBLIC PROCEDURE InputOOBDataQuery( VAR EnumerateState : LONGWORD; VAR DriverIndex : CARDINAL ) : BOOLEAN;
  BEGIN
    RETURN FALSE;
  END InputOOBDataQuery;

//--------------------------------------------------------------------------------

  PUBLIC PROCEDURE GetInput( UFlag : BOOLEAN; DriverIndex : CARDINAL; VAR InValue : drv_def.TValue; VAR QoS : CARDINAL; VAR TimeStamp : drv_def.TUTCStamp; VAR ErrorCode : CARDINAL );
  BEGIN
    Result.Inc();

    ErrorCode := drv_def.ecSuccess;
    QoS := drv_def.qosGood;

    CASE DriverIndex OF
    | chStatus :
      drv_def.AssignValueCardinal( InValue, UFlag, TRUE, CARDINAL( RStatus * rssUser ));
    | chMode :
      drv_def.AssignValueCardinal( InValue, UFlag, TRUE, ScanMode );
    | chFieldSet :
      drv_def.AssignValueCardinal( InValue, UFlag, TRUE, ActiveFieldSet );
    | chScanningAngle :
      drv_def.AssignValueCardinal( InValue, UFlag, TRUE, ScanningAngle );
    | chResolution :
      drv_def.AssignValueLongReal( InValue, UFlag, TRUE, Resolution );
    | chMean, chCurrent :
    | chFS1A :
      drv_def.AssignValueBoolean( InValue, UFlag, TRUE, Fields[1]['A'] );
    | chFS1B :
      drv_def.AssignValueBoolean( InValue, UFlag, TRUE, Fields[1]['B'] );
    | chFS1C :
      drv_def.AssignValueBoolean( InValue, UFlag, TRUE, Fields[1]['C'] );
    | chFS2A :
      drv_def.AssignValueBoolean( InValue, UFlag, TRUE, Fields[2]['A'] );
    | chFS2B :
      drv_def.AssignValueBoolean( InValue, UFlag, TRUE, Fields[2]['B'] );
    | chFS2C :
      drv_def.AssignValueBoolean( InValue, UFlag, TRUE, Fields[2]['C'] );
    END; // CASE

  END GetInput;

//--------------------------------------------------------------------------------

  PUBLIC PROCEDURE OutputRequestStart();
  BEGIN
  END OutputRequestStart;

//--------------------------------------------------------------------------------

  PUBLIC PROCEDURE OutputRequest( UFlag : BOOLEAN; DriverIndex : CARDINAL; OutValue : drv_def.TValue; QoS : CARDINAL; TimeStamp : drv_def.TUTCStamp );
  BEGIN
  END OutputRequest;

//--------------------------------------------------------------------------------

  PUBLIC PROCEDURE OutputRequestCompleted();
  BEGIN
  END OutputRequestCompleted;

//--------------------------------------------------------------------------------

  PUBLIC PROCEDURE OutputFinalized( DriverIndex : CARDINAL; VAR ErrorCode : CARDINAL ) : BOOLEAN;
  BEGIN
    RETURN TRUE;
  END OutputFinalized;

//--------------------------------------------------------------------------------

  LOCAL PROCEDURE OnRxTick();
  BEGIN
    INC( RxTimeoutTime, RxTimeoutPeriod );
  END OnRxTick;

//--------------------------------------------------------------------------------

  LOCAL PROCEDURE OnReceive( Result : Sync.TAsyncResult; CONST Data : StorageO.AMemoryBuffer );
  VAR
    L : CARDINAL;
    PFrame : TPInFrame;
    Processed : BOOLEAN;
  BEGIN
    IF OS = osFailure THEN
      RETURN;

    ELSIF Result = Sync.arCompleted THEN
      L := Data.Length;
      PFrame := Data.Data;
      EXCL( RStatus, rsDeviceError );
      Processed := TRUE;

      IF L = 1 THEN // ACK or NAK
        CASE PCARD8( PFrame )^ OF
        | 006H :
          IF rsWaitACK IN RStatus THEN
            Serial.Logger.LogS( Log.dldTrace, Name, L'RX ACK during expect ACK' );
            RStatus := RStatus - TRStatus{rsWaitACK} + TRStatus{rsWaitResponse};
            CASE Expect OF
            | 0B1H, 0B0H, 0CAH :
              SetRxTimeout( 120, 0 );
            | 0C1H :
              SetRxTimeout( 600, 0 );
            END;
          END;
        | 015H :
          IF rsWaitACK IN RStatus THEN
            Serial.Logger.LogSC( Log.dldTrace, Name, L'RX NAK during expect ACK ', CARDINAL( PFrame^.F.Cmd ));
            RStatus := RStatus - TRStatus{rsWaitACK};
            ResetRxTimeout();
          END;
        ELSE
          Processed := FALSE;
        END;
        IF Processed THEN
          RETURN;
        END;
      END;
      
      CASE PFrame^.F.Cmd OF
      //-----
      | 092H : // NAK = NAK, NAK = unrecognized command
        Serial.Logger.LogSC( Log.dldTrace, Name, L'RX NAK during expect ACK ', CARDINAL( PFrame^.F.Cmd ));
      //-----
      | 090H, 091, 0A0H : // power-on message, reset confirmation, mode switched
        Automaton( osInit );
      //-----
      | 0B1H, 0C1H, 0B0H, 0CAH :
        IF ( rsWaitResponse IN RStatus ) AND ( PFrame^.F.Cmd = Expect ) THEN
          Serial.Logger.LogSC( Log.dldTrace, Name, L'RX DATA during expect DATA ', CARDINAL( Expect ));
          RStatus := RStatus - TRStatus{rsWaitResponse} + TRStatus{rsHaveData};
          ResetRxTimeout();
        END;
        CASE PFrame^.F.Cmd OF
        | 0B0H, 0CAH :
          IF OS >= osRunning1 THEN
            ParseData( PFrame, L );
          ELSE
            Serial.Logger.LogS( Log.dldDebug, Name, L'RX DATA before initialization finish' );
          END;
        ELSE
          ParseData( PFrame, L );
        END;
      //-----
      ELSE // log unparsed data
        Serial.Logger.LogSC( Log.dldDebug, Name, L'RX unparsed data ', CARDINAL( PFrame^.F.Cmd ));
      END;

    ELSE
      RStatus := RStatus - rssPending;
      ResetRxTimeout();
      INCL( RStatus, rsDeviceError );

      IF Result = Sync.arTimeout THEN
        LastErrorCode := ceRxTimeout;
        Serial.Logger.LogS( Log.dldError, Name, L'RX timeout' );
      ELSIF Result <> Sync.arCompleted THEN
        LastErrorCode := drv_def.ecValueProcessing;
        Serial.Logger.LogS( Log.dldError, Name, L'RX ? unknown error ' );
      END;

    END;
  END OnReceive;

//--------------------------------------------------------------------------------

  LOCAL PROCEDURE OnSend( Result : Sync.TAsyncResult );
  BEGIN
  END OnSend;

//--------------------------------------------------------------------------------

  PROCEDURE Automaton( NewOS : TOperationState );
  VAR
    Frame : TOutFrame;
    Length : CARDINAL;
  BEGIN
    CASE NewOS OF
    | osInit :
      RStatus := RStatus - rssPending;
      ResetRxTimeout();

      ScanMode := 025H;
      ValueMode := 0;
      ScanningAngle := 0;
      Resolution := 0.0;
      ActiveFieldSet := 0;
      Fill( ADR( Fields ), SIZE( Fields ), 1 );
      Fill( ADR( FieldsPrevious ), SIZE( FieldsPrevious ), 1 );

      Zero( ADR( MeanData ), SIZE( MeanData ));
      Zero( ADR( CurrentData ), SIZE( CurrentData ));
      Zero( ADR( DiffData ), SIZE( DiffData ));
      CopyToBuffers();

      NAVG := 0;
    END; // CASE

    IF NewOS <> osUnknown THEN
      IF NewOS <> osTick THEN
        OS := NewOS;
      ELSE
        OS := osRunning1;
      END;
    END;
    IF ( OS = osIdle ) OR ( OS = osFailure ) THEN
      RETURN;
    ELSIF Result.Counted OR Result.Expired THEN
      RETURN;
    ELSIF OS = osRunning1 THEN
      IF rsOOBScan IN RStatus THEN
        // pass down
      ELSIF ScanMode <> 025H THEN // device sends result itself, skip data acquire phase, they are pushed by device itself
        OS := osRunning2;
      ELSIF ScanFactor = 0 THEN // no scan, only fields will be evaluated
        OS := osRunning2;
      ELSE
        DEC( FactorCount );
        IF INTEGER( FactorCount ) <= 0 THEN
          FactorCount := ScanFactor;
        ELSE // skip scan phase, time did not elapsed yet
          OS := osRunning2; 
        END;
      END;
    END;
    IF rssPending * RStatus <> TRStatus{} THEN
      RETURN;
    END;
    RStatus := RStatus - TRStatus{rsHaveData, rsOOBScan} + TRStatus{rsWaitACK};

    CASE OS OF
    //-----
    | osInit :
      Frame.F.Address := Address;
      Frame.F.Len := 1;
      Frame.F.Cmd := 031H; // request LMS status
      Length := 4;
      Expect := 0B1H;
    //-----
    | osHaveStatus :
      Frame.F.Address := Address;
      Frame.F.Len := 2;
      Frame.F.Cmd := 041H; // request active field set
      Frame.D[0] := 00H; // only query set
      Length := 5;
      Expect := 0C1H;
    //-----
    | osRunning1 :
      Frame.F.Address := Address;
      Frame.F.Len := 2;
      Frame.F.Cmd := 030H; // request measured values
      Frame.D[0] := 01H; // all data
      Length := 5;
      Expect := 0B0H;
    //-----
    | osRunning2 :
      Frame.F.Address := Address;
      Frame.F.Len := 1;
      Frame.F.Cmd := 04AH; // request measured values
      Length := 4;
      Expect := 0CAH;
    END; // CASE OS

    Serial.Logger.LogSC( Log.dldError, Name, L'TX request ', CARDINAL( Frame.F.Cmd ));

    SetRxTimeout( RxACKTimeout, Length + 3 );
    Serial.Tx( OA( Length-1, ADR( Frame )), FALSE, 0, 0, RxSafetyTimeout );
  END Automaton;

//--------------------------------------------------------------------------------

  PROCEDURE ParseData( PData : TPInFrame; L :  CARDINAL );
  (*# save, option( pack => 1 ) *)
  TYPE
    TLMSStatus        = RECORD
                          F             : TFrame;
                          A             : ARRAY [0..6] OF CHAR;
                          OperatingMode : CARD8;
                          CtoA2         : ARRAY [0..92] OF BYTE;
                          ValueMode     : CARD8;
                          A3, A4        : WORD;
                          ScanningAngle : CARD16;
                          Resolution    : CARD16;
                        END;
    TPLMSStatus       = POINTER TO TLMSStatus;
    TQueryFieldSet    = RECORD
                          F             : TFrame;
                          ActiveField   : CARD8;
                        END;
    TPQueryFieldSet   = POINTER TO TQueryFieldSet;

    // TFieldsConfig     = RECORD
    //                       F : TFrame;
    //                     END;
    TCurrentResponse  = RECORD
                         F           : TFrame;
                         Description : CARD16;
                         Measured    : ARRAY [0..512] OF CARD16;
                       END;
    TPCurrentResponse = POINTER TO TCurrentResponse;
    // TMeanResponse     = RECORD
    //                       F : TFrame;
    //                     END;
    TFieldsStatus     = RECORD
                          F      : TFrame;
                          FieldA : BOOLEAN;
                          FieldB : BOOLEAN;
                          FieldC : BOOLEAN;
                        END;
    TPFieldsStatus    = POINTER TO TFieldsStatus;
  (*# restore *)
  VAR
    BV : INTEGER;
    Count : CARDINAL;
    i, j : CARDINAL;
    Mask : CARD16;
    Multiplier : CARDINAL;
    Nev : CARDINAL;
    Offset : CARDINAL;
    Overflow : INTEGER;
    Step : CARDINAL;
  BEGIN
    Serial.Logger.LogSC( Log.dldError, Name, L'RX parsing ', CARDINAL( PData^.F.Cmd ));

    CASE PData^.F.Cmd OF
    //-----
    | 0B1H : // LMS status
      ScanMode := CARDINAL( TPLMSStatus( PData )^.OperatingMode );
      ValueMode := CARDINAL( TPLMSStatus( PData )^.ValueMode );
      ScanningAngle := CARDINAL( TPLMSStatus( PData )^.ScanningAngle );
      Resolution := LONGREAL( TPLMSStatus( PData )^.Resolution ) / 100.0;

      CASE ScanMode OF
      | 020H..025H, 02AH :
        Automaton( osHaveStatus );
      ELSE
        Automaton( osFailure );
        Serial.Logger.LogSC( Log.dldError, Name, L'RX unsupported mode, switching OFF ', ScanMode );
      END;

    //-----
    | 0C1H : // query active field set
      ActiveFieldSet := CARDINAL( TPQueryFieldSet( PData )^.ActiveField );
      Automaton( osRunning1 );

    //-----
    // | 0C5H : // fields configuratuon

    //-----
    | 0B0H : // response to measured value request
      IF TPCurrentResponse( PData )^.Description AND 0C000H = 04000H THEN
        Multiplier := 1; // unit is mm
      ELSE
        Multiplier := 10; // unit is cm
      END;
      Count := CARDINAL( TPCurrentResponse( PData )^.Description AND 001FFH );
      IF Count = 0 THEN
        Serial.Logger.LogS( Log.dldError, Name, L'RX data zero count' );
        RETURN;
      END;
      IF ScanningAngle = 100 THEN
        Offset := 4*40; // only data from 40--140 degrees are read
      ELSE
        Offset := 0;
      END;
      IF TPCurrentResponse( PData )^.Description AND 02000H = 0 THEN
        IF Resolution = 1.0 THEN
          Step := 4;
        ELSIF Resolution = 0.5 THEN
          Step := 2;
        ELSE
          Step := 1;
        END;
      ELSE // interlaced scan
        Step := 4;
        CASE TPCurrentResponse( PData )^.Description AND 01800H OF
        | 00000H : // scan from 0.00 deg
        | 00800H : // scan from 0.25 deg
          INC( Offset );
        | 01000H : // scan from 0.50 deg
          INC( Offset, 2 );
        | 01800H : // scan from 0.75 deg
          INC( Offset, 3 );
        END;
      END;

      CASE ValueMode OF
      | 0, 1, 2 :
        Mask := 01FFFH;
        Overflow := 01FF7H;
      | 3, 4, 5 :
        Mask := 03FFFH;
        Overflow := 03FF7H;
      | 6, 15 :
        Mask := 07FFFH;
        Overflow := 07FF7H;
      END;
      Overflow := INTEGER( Multiplier ) * Overflow;

      Nev := Events.Count;
      FOR i := 0 TO Count - 1 DO
        j := Offset + i*Step;

        BV := Multiplier * CARDINAL( TPCurrentResponse( PData )^.Measured[Count-1-i] AND Mask );
        IF BV >= Overflow THEN
          BV := MeanData[j];
        ELSE
          CurrentData[j] := BV;
        END;

        IF NAVG > 0 THEN
          DiffData[j] := INTEGER( BV - MeanData[j] );
          IF ABS( DiffData[j] ) > ABS( MeanData[j] DIV 10 ) THEN
            BV := ( 2 * BV + MeanData[j] ) DIV 3;  // filter
          END;
        END;

		IF NOT MeanLocked THEN
          MeanData[j] := NAVG * MeanData[j] + BV;
          MeanData[j] := MeanData[j] DIV ( NAVG + 1 );
        END;
      END; // FOR
      
      IF NOT MeanLocked AND ( NAVG < MeanCount ) THEN
        INC( NAVG );
      END;

      CopyToBuffers();
      CheckZones();

      Automaton( osRunning2 );

      IF ( Nev < Events.Count ) AND NOT( rsEventsReportPending IN RStatus ) THEN
        INCL( RStatus, rsEventsReportPending );
        CallbackProc( CallbackId, drv_def.dcfException, NIL );
      END;

    //-----
    | 0CAH : // status of the fields
      Nev := Events.Count;

      Fields[ActiveFieldSet]['A'] := TPFieldsStatus( PData )^.FieldA;
      IF Fields[ActiveFieldSet]['A'] AND NOT FieldsPrevious[ActiveFieldSet]['A'] THEN
        Serial.Logger.LogS( Log.dldError, Name, L'RX field A FINISH' );
        AddEvent( NIL, evFinish, etField, 1, 0, 0, 0 );
      ELSIF NOT Fields[ActiveFieldSet]['A'] AND FieldsPrevious[ActiveFieldSet]['A'] THEN
        Serial.Logger.LogS( Log.dldError, Name, L'RX field A ALARM' );
        AddEvent( NIL, evSetOff, etField, 1, 0, 0, 0 );
      END;
      FieldsPrevious[ActiveFieldSet]['A'] := Fields[ActiveFieldSet]['A'];
      Fields[ActiveFieldSet]['B'] := TPFieldsStatus( PData )^.FieldB;
      IF Fields[ActiveFieldSet]['B'] AND NOT FieldsPrevious[ActiveFieldSet]['B'] THEN
        Serial.Logger.LogS( Log.dldError, Name, L'RX field B FINISH' );
        AddEvent( NIL, evFinish, etField, 2, 0, 0, 0 );
      ELSIF NOT Fields[ActiveFieldSet]['B'] AND FieldsPrevious[ActiveFieldSet]['B'] THEN
        Serial.Logger.LogS( Log.dldError, Name, L'RX field B ALARM' );
        AddEvent( NIL, evSetOff, etField, 2, 0, 0, 0 );
      END;
      FieldsPrevious[ActiveFieldSet]['B'] := Fields[ActiveFieldSet]['B'];
      Fields[ActiveFieldSet]['C'] := TPFieldsStatus( PData )^.FieldC;
      IF Fields[ActiveFieldSet]['C']  AND NOT FieldsPrevious[ActiveFieldSet]['C'] THEN
        Serial.Logger.LogS( Log.dldError, Name, L'RX field C FINISH' );
        AddEvent( NIL, evFinish, etField, 3, 0, 0, 0 );
      ELSIF NOT Fields[ActiveFieldSet]['C']  AND FieldsPrevious[ActiveFieldSet]['C'] THEN
        Serial.Logger.LogS( Log.dldError, Name, L'RX field C ALARM' );
        AddEvent( NIL, evSetOff, etField, 3, 0, 0, 0 );
      END;
      FieldsPrevious[ActiveFieldSet]['C'] := Fields[ActiveFieldSet]['C'];
      Automaton( osIdle );

      IF ( Nev < Events.Count ) AND NOT( rsEventsReportPending IN RStatus ) THEN
        INCL( RStatus, rsEventsReportPending );
        CallbackProc( CallbackId, drv_def.dcfException, NIL );
      END;

    END; // CASE Cmd
  END ParseData;

//--------------------------------------------------------------------------------

  PROCEDURE AddEvent( Zone : TPZone; Event : TEvent; Type : TEventType; Angle : CARDINAL; Id, Mean, Diff : INTEGER );
  VAR
    PELE : TPEventListElem;
  BEGIN
    NEW( PELE );
    PELE^.Zone := Zone;
    PELE^.Event := Event;
    PELE^.Type := Type;
    PELE^.Angle := Angle;
    PELE^.Id := Id;
    PELE^.Mean := Mean;
    PELE^.Diff := Diff;
    Events.Append( PELE );
  END AddEvent;

//--------------------------------------------------------------------------------

  PROCEDURE InitToDefault();
  BEGIN
    OS := osUnknown;
    Address := 0;
    RxACKTimeout := 75;
    RxSafetyTimeout := 5000;
    ScanPeriod := 250;
    ScanFactor := 8;
    MeanCount := 25;
    MeanLocked := FALSE;
  END InitToDefault;

//--------------------------------------------------------------------------------

  PROCEDURE SetRxTimeout( RxDataTimeout, AddOn : CARDINAL );
  BEGIN
    ResetRxTimeout();
    IF RxDataTimeout > 0 THEN
      INCL( RStatus, rsRxTimeout );
      Serial.Logger.LogSC( Log.dldTrace, Name, L'RX timeout set to: ', RxDataTimeout + AddOn );
      StartTimer( tiRx, RxDataTimeout, TRUE );
      RxTimeoutPeriod := RxDataTimeout + AddOn;
      RxTimeoutTime := time.UptimeMS() + RxTimeoutPeriod;
    END;
  END SetRxTimeout;

//--------------------------------------------------------------------------------

  PROCEDURE ResetRxTimeout();
  BEGIN
    IF rsRxTimeout IN RStatus THEN
      EXCL( RStatus, rsRxTimeout );
      Serial.Logger.LogS( Log.dldTrace, Name, L'RX timeout reset' );
      StopTimer( tiRx );
    END;
  END ResetRxTimeout;

//--------------------------------------------------------------------------------

  PROCEDURE CopyToBuffers();
  TYPE
    TPC = POINTER TO CARDINAL;
  VAR
    i : CARDINAL;
    pd : TPC;
  BEGIN
    IF PMeanDataChannel <> NIL THEN
      pd := TPC( CARDINAL( PMeanDataChannel ) + SIZE( drv_def.TBufferHeader ));
      FOR i := 0 TO DataCount - 1 DO
        pd^ := CARDINAL( MeanData[i] );
        INC( pd, SIZE( CARDINAL ));
      END;
    END;
    IF PCurrentDataChannel <> NIL THEN
      pd := TPC( CARDINAL( PCurrentDataChannel ) + SIZE( drv_def.TBufferHeader ));
      FOR i := 0 TO DataCount - 1 DO
        pd^ := CARDINAL( CurrentData[i] );
        INC( pd, SIZE( CARDINAL ));
      END;
    END;
  END CopyToBuffers;

//--------------------------------------------------------------------------------

  PROCEDURE CheckZones();
  VAR
    CandidateToFinish, CandidateToNew, Middle : INTEGER;
    EventFrom, EventTo : INTEGER := 0;
    ActiveCount, GapCount : INTEGER;
    LDiff, LMean, LNAVG : INTEGER;
    Step : INTEGER;
    SumDiff : INTEGER;
    i : INTEGER;
    Zone : TPZone;
    b : BOOLEAN;
    CheckEnd : BOOLEAN;
    EventPending : BOOLEAN;

    PROCEDURE DoCheckPending( SampleActive : BOOLEAN );
    BEGIN
      WITH Zone^ DO
        IF CandidateToNew = -1 THEN
          IF SampleActive THEN
            CandidateToFinish := i;
          END;
        ELSIF i - CandidateToNew > MovementThreshold THEN
          IF SampleActive THEN
            // STOP EVENT
            Serial.Logger.LogSS( Log.dldError, Name, L'EV finish 1 on zone: ', Zone^.Id );
            AddEvent( Zone, evFinish, etZone, i, A[i], MeanData[i], 0 );
            A[i] := 0;
          END;
          // NEW EVENT
          INC( CurrentId );
          A[CandidateToNew] := CurrentId;
          Serial.Logger.LogSS( Log.dldError, Name, L'EV set off 1 on zone: ', Zone^.Id );
          AddEvent( Zone, evSetOff, etZone, CandidateToNew, CurrentId, LMean, LDiff );
          CandidateToNew := -1;
          LMean := 0; LDiff := 0; LNAVG := 0;
        ELSIF SampleActive AND ( CandidateToNew <> i ) THEN
          // MOVED EVENT
          A[CandidateToNew] := A[i];
          Serial.Logger.LogSS( Log.dldError, Name, L'EV moved 1 on zone: ', Zone^.Id );
          AddEvent( Zone, evMovement, etZone, CandidateToNew, A[CandidateToNew], LMean, LDiff );
          CandidateToNew := -1;
          LMean := 0; LDiff := 0; LNAVG := 0;
          A[i] := 0; // reset previous center
        END;
      END; // WITH
    END DoCheckPending;

    PROCEDURE DoCheckEnd();
    BEGIN
      WITH Zone^ DO
        IF EventPending THEN // signalize event when end of peek found
          IF LNAVG > 0 THEN
            LMean := LMean DIV LNAVG;
            LDiff := LDiff DIV LNAVG;
          END;
          Middle := ( EventTo + EventFrom ) DIV 2;
          IF Middle > Step THEN
            Middle := Middle - Middle MOD Step;
          ELSE
            Middle := 0;
          END;
          IF CandidateToFinish = -1 THEN // new event candidate
            DoCheckPending( FALSE );
            CandidateToNew := Middle;
          ELSIF ABS( Middle - CandidateToFinish ) > MovementThreshold THEN // the event is new, stop previous
            // STOP EVENT
            Serial.Logger.LogSS( Log.dldError, Name, L'EV finish 2 on zone: ', Zone^.Id );
            AddEvent( Zone, evFinish, etZone, CandidateToFinish, A[CandidateToFinish], MeanData[CandidateToFinish], 0 );
            A[CandidateToFinish] := 0;
            // NEW EVENT
            INC( CurrentId );
            A[Middle] := CurrentId;
            Serial.Logger.LogSS( Log.dldError, Name, L'EV set off 2 on zone: ', Zone^.Id );
            AddEvent( Zone, evSetOff, etZone, Middle, CurrentId, LMean, LDiff );
          ELSIF CandidateToFinish <> Middle THEN
            // MOVED EVENT
            A[Middle] := A[CandidateToFinish];
            A[CandidateToFinish] := 0;
            Serial.Logger.LogSS( Log.dldError, Name, L'EV moved 2 on zone: ', Zone^.Id );
            AddEvent( Zone, evMovement, etZone, Middle, A[Middle], LMean, LDiff );
          END;
        ELSIF CandidateToFinish > -1 THEN
          // STOP EVENT
          Serial.Logger.LogSS( Log.dldError, Name, L'EV finish on 3 zone: ', Zone^.Id );
          AddEvent( Zone, evFinish, etZone, CandidateToFinish, A[CandidateToFinish], MeanData[CandidateToFinish], 0 );
          A[CandidateToFinish] := 0;
        END;
        IF CandidateToNew = -1 THEN
          LMean := 0; LDiff := 0; LNAVG := 0;
        END;
      END; // WITH
    END DoCheckEnd;

  BEGIN
    IF Resolution = 1.0 THEN
      Step := 4;
    ELSIF Resolution = 0.5 THEN
      Step := 2;
    ELSE
      Step := 1;
    END;

    b := Zones.GetFirst( OUT Zone );
    WHILE b DO
      WITH Zone^ DO IF Active THEN
        // prepare
        ActiveCount := 0;
        GapCount := 0;
        LMean := 0; LDiff := 0; LNAVG := 0;
        CandidateToNew := -1;
        CandidateToFinish := -1;
        EventPending := FALSE;
        
        // parse samples one by one
        i := From;
        WHILE i <= To DO
          // 1. count mean value
          Data[i] := Data[i] * NAVG + DiffData[i];
          Data[i] := Data[i] DIV ( NAVG + 1 );

          // 2. check pending event
          DoCheckPending( A[i] <> 0 );

          // 3. evaluate limits
          CheckEnd := FALSE;
          IF ( Data[i] + MeanData[i] > FarCutOff ) OR ( Data[i] + MeanData[i] < NearCutOff ) THEN
            // ignore 
          ELSIF DoFar AND ( Data[i] >= FarLimit ) OR DoNear AND ( Data[i] <= NearLimit ) THEN
            GapCount := 0;
            INC( C[i] );
            IF C[i] >= CountThreshold THEN // sample is active
              SumDiff := SumDiff + Data[i]; // beam is fully valid
              // local averages
              LMean := LMean + MeanData[i];
              LDiff := LDiff + Data[i];
              INC( LNAVG );

              INC( ActiveCount );
              IF EventFrom = 0 THEN
                EventFrom := i;
              END;
              EventTo := i;
            ELSE
              SumDiff := SumDiff + Data[i] * C[i] DIV CountThreshold; // beam is partially valid
            END;
          ELSIF ( ActiveCount > 1 ) AND ( GapCount < GapThreshold ) THEN
            C[i] := 0;
            INC( GapCount );
          ELSE
            CheckEnd := TRUE;
            C[i] := 0;
            ActiveCount := 0;
            GapCount := 0;
            SumDiff := 0;
          END;
          IF ( ActiveCount >= ActiveThreshold ) OR
             ( ActiveCount >= ActiveThreshold  DIV 2 ) AND
             (
               DoFar AND ( SumDiff >= ActiveThreshold * FarLimit ) OR
               DoNear AND ( SumDiff <= ActiveThreshold * NearLimit )
             ) THEN
            EventPending := TRUE;
          END;

          // 4. check events
          IF CheckEnd THEN
            DoCheckEnd();
            CandidateToFinish := -1;
            EventFrom := 0;
            EventPending := FALSE;
          END;

          INC( i, Step );
        END; // WHILE

        // solve delayed 4.
        DoCheckEnd();
        // solve delayed 2.
        IF CandidateToNew <> -1 THEN
          // NEW EVENT
          INC( CurrentId );
          A[CandidateToNew] := CurrentId;
          Serial.Logger.LogSS( Log.dldError, Name, L'EV set off 3 on zone: ', Zone^.Id );
          AddEvent( Zone, evSetOff, etZone, CandidateToNew, CurrentId, LMean, LDiff );
        END;

        // increment mean counter
        IF ( NAVG + 1 ) < MeanCount THEN
          INC( NAVG );
        END;
      END; END; // IF // WITH
      b := Zones.NextOf( Zone, OUT Zone );
    END;
  END CheckZones;

//================================================================================

BEGIN
  RStatus := TRStatus{};
  RunMode := drv_def.drmEdit;
  CallbackId := NIL;
  CallbackProc := NIL;
  Serial.PDriver := ADR( SELF );
  _Lock.Init( Sync.ltCS, L"", FALSE );

  RateTimer := 0;

  PCurrentDataChannel := NIL;
  PMeanDataChannel := NIL;
  CurrentId := 0;

  CurrentZone := NIL;
END CDriver;

//--------------------------------------------------------------------------------

CLASS IMPLEMENTATION CEventListElem;
BEGIN
  Zone := NIL;
  Event := evUnknown;
  Type := etUnknown;
  Angle := 0;
  Mean := 0;
  Diff := 0;
END CEventListElem;

//================================================================================
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

//--------------------------------------------------------------------------------

PROCEDURE MakeDriverW() : ADDRESS;
BEGIN
  IF RefCount = 0 THEN
    scinit.Startup();
  END;
  INC( RefCount );

  RETURN NEW( CDriver );
END MakeDriverW;

//--------------------------------------------------------------------------------

PROCEDURE DisposeDriverW( PData : ADDRESS );
BEGIN
   DISPOSE( TPDriver( PData ));

  DEC( RefCount );
  IF RefCount = 0 THEN
    scinit.Cleanup();
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
  | ceDeviceStopped :
    ASSIGNsz( ErrorText, GR[Texts._E_DeviceStopped] );
  | ceDeviceNotFound :
    ASSIGNsz( ErrorText, GR[Texts._E_DeviceNotFound] );
  | ceDeviceInUnsupportedMode :
    ASSIGNsz( ErrorText, GR[Texts._E_DeviceInUnsupportedMode] );
  ELSE
    RETURN FALSE;
  END;
  RETURN TRUE;
END QueryErrorCodeW;

(*--------------------------------------------------------------------------------*)

PROCEDURE BufferInfoW( PData : ADDRESS; DriverIndex : CARDINAL; BType : CARD8; BLen : CARDINAL ) : BOOLEAN;
BEGIN
  RETURN TPDriver( PData )^.BufferInfo( DriverIndex, BType, BLen );
END BufferInfoW;

//--------------------------------------------------------------------------------

PROCEDURE SetBufferAddrW( PData : ADDRESS; DriverIndex : CARDINAL; PBuffer : ADDRESS );
BEGIN
  TPDriver( PData )^.SetBufferAddr( DriverIndex, PBuffer );
END SetBufferAddrW;

(*--------------------------------------------------------------------------------*)

PROCEDURE RunW( PData : ADDRESS );
BEGIN
  TPDriver( PData )^.Lock();
  TPDriver( PData )^.Run();
  TPDriver( PData )^.Unlock();
END RunW;

PROCEDURE StopW( PData : ADDRESS );
BEGIN
  TPDriver( PData )^.Lock();
  TPDriver( PData )^.Stop();
  TPDriver( PData )^.Unlock();
END StopW;

PROCEDURE DoneW( PData : ADDRESS );
BEGIN
  TPDriver( PData )^.Lock();
  TPDriver( PData )^.Done();
  TPDriver( PData )^.Unlock();
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
  TPDriver( PData )^.Lock();
  TPDriver( PData )^.QueryProc( FALSE, InValue1, InValue2, OutValue );
  TPDriver( PData )^.Unlock();
END QueryProc3;

PROCEDURE QueryProc3W( PData : ADDRESS; InValue1, InValue2 : drv_def.TValue; VAR OutValue : drv_def.TValue );
BEGIN
  TPDriver( PData )^.Lock();
  TPDriver( PData )^.QueryProc( TRUE, InValue1, InValue2, OutValue );
  TPDriver( PData )^.Unlock();
END QueryProc3W;

(*--------------------------------------------------------------------------------*)

PROCEDURE InputRequestStartW( PData : ADDRESS );
BEGIN
  TPDriver( PData )^.Lock();
  TPDriver( PData )^.InputRequestStart();
  TPDriver( PData )^.Unlock();
END InputRequestStartW;

PROCEDURE InputRequestW( PData : ADDRESS; DriverIndex : CARDINAL );
BEGIN
  TPDriver( PData )^.Lock();
  TPDriver( PData )^.InputRequest( DriverIndex );
  TPDriver( PData )^.Unlock();
END InputRequestW;

PROCEDURE InputRequestCompletedW( PData : ADDRESS );
BEGIN
  TPDriver( PData )^.Lock();
  TPDriver( PData )^.InputRequestCompleted();
  TPDriver( PData )^.Unlock();
END InputRequestCompletedW;

PROCEDURE InputFinalizedW( PData : ADDRESS; DriverIndex : CARDINAL; VAR ErrorCode : CARDINAL ) : BOOLEAN;
VAR
  b : BOOLEAN;
BEGIN
  TPDriver( PData )^.Lock();
  b := TPDriver( PData )^.InputFinalized( DriverIndex, ErrorCode );
  TPDriver( PData )^.Unlock();
  RETURN b;
END InputFinalizedW;

PROCEDURE InputOOBDataQueryW( PData : ADDRESS; VAR EnumerateState : LONGWORD; VAR DriverIndex : CARDINAL ) : BOOLEAN;
VAR
  b : BOOLEAN;
BEGIN
  TPDriver( PData )^.Lock();
  b := TPDriver( PData )^.InputOOBDataQuery( EnumerateState, DriverIndex );
  TPDriver( PData )^.Unlock();
  RETURN b;
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
  TPDriver( PData )^.Lock();
  TPDriver( PData )^.GetInput( FALSE, DriverIndex, InValue, QoS, TimeStamp, ErrorCode );
  TPDriver( PData )^.Unlock();
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
  TPDriver( PData )^.Lock();
  TPDriver( PData )^.GetInput( TRUE, DriverIndex, InValue, QoS, TimeStamp, ErrorCode );
  TPDriver( PData )^.Unlock();
END GetInput3W;

(*--------------------------------------------------------------------------------*)

PROCEDURE OutputRequestStartW( PData : ADDRESS );
BEGIN
  TPDriver( PData )^.Lock();
  TPDriver( PData )^.OutputRequestStart();
  TPDriver( PData )^.Unlock();
END OutputRequestStartW;

PROCEDURE OutputRequest( PData : ADDRESS; DriverIndex : CARDINAL; OutValue : drv_def.TValue );
VAR
  ts : drv_def.TUTCStamp;
BEGIN
  OutputRequest3( PData, DriverIndex, OutValue, drv_def.qosGood, ts );
END OutputRequest;

PROCEDURE OutputRequest3( PData : ADDRESS; DriverIndex : CARDINAL; OutValue : drv_def.TValue; QoS : CARDINAL; VAR TimeStamp : drv_def.TUTCStamp );
BEGIN
  TPDriver( PData )^.Lock();
  TPDriver( PData )^.OutputRequest( FALSE, DriverIndex, OutValue, QoS, TimeStamp );
  TPDriver( PData )^.Unlock();
END OutputRequest3;

PROCEDURE OutputRequestW( PData : ADDRESS; DriverIndex : CARDINAL; OutValue : drv_def.TValue );
VAR
  ts : drv_def.TUTCStamp;
BEGIN
  OutputRequest3W( PData, DriverIndex, OutValue, drv_def.qosGood, ts );
END OutputRequestW;

PROCEDURE OutputRequest3W( PData : ADDRESS; DriverIndex : CARDINAL; OutValue : drv_def.TValue; QoS : CARDINAL; VAR TimeStamp : drv_def.TUTCStamp );
BEGIN
  TPDriver( PData )^.Lock();
  TPDriver( PData )^.OutputRequest( TRUE, DriverIndex, OutValue, QoS, TimeStamp );
  TPDriver( PData )^.Unlock();
END OutputRequest3W;

PROCEDURE OutputRequestCompletedW( PData : ADDRESS );
BEGIN
  TPDriver( PData )^.Lock();
  TPDriver( PData )^.OutputRequestCompleted();
  TPDriver( PData )^.Unlock();
END OutputRequestCompletedW;

PROCEDURE OutputFinalizedW( PData : ADDRESS; DriverIndex : CARDINAL; VAR ErrorCode : CARDINAL ) : BOOLEAN;
VAR
  b : BOOLEAN;
BEGIN
  TPDriver( PData )^.Lock();
  b := TPDriver( PData )^.OutputFinalized( DriverIndex, ErrorCode );
  TPDriver( PData )^.Unlock();
  RETURN b;
END OutputFinalizedW;

//================================================================================

BEGIN
  RefCount := 0;
  GR.LoadRES2( EMITW( %dll ), L'LMS2xx.Texts' );
  GR.Lang := Languages.GetDefaultLanguage( Languages.dlUser );
END LMS2xx.