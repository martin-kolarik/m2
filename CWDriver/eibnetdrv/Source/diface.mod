IMPLEMENTATION MODULE diface;

FROM Storage IMPORT
   ALLOCATE, DEALLOCATE;

FROM driver IMPORT
   CEIBDriver, TPEIBDriver;
   
IMPORT
   driver,
   netinit,
   Strings,
   StringsO,
   Texts,
   threadinit;

//================================================================================
// procedural interface

VAR
   RefCount : CARDINAL := 0;

PROCEDURE VersionW() : CARDINAL;
BEGIN
   RETURN 030000H;
END VersionW;

//--------------------------------------------------------------------------------

PROCEDURE GetDriverInfo( VAR DriverName : ARRAY OF CHAR );
BEGIN
   Strings.ToA( OAsz( driver.R()^[ Texts._DriverName ] ), 0, OUT DriverName );
END GetDriverInfo;

//--------------------------------------------------------------------------------

PROCEDURE GetDriverInfoW( VAR DriverNameW : ARRAY OF WCHAR );
BEGIN
   ASSIGN( DriverNameW, OAsz( driver.R()^[ Texts._DriverName ] ));
END GetDriverInfoW;

//--------------------------------------------------------------------------------

PROCEDURE Check( VAR ErrorString : ARRAY OF CHAR; CWVersion, MajorVersion, MinorVersion, APIMajorVersion, APIMinorVersion : CARDINAL ): BOOLEAN;
BEGIN
   RETURN TRUE;
END Check;

//--------------------------------------------------------------------------------

PROCEDURE CheckW( VAR ErrorString : ARRAY OF WCHAR; CWVersion, MajorVersion, MinorVersion, APIMajorVersion, APIMinorVersion : CARDINAL ): BOOLEAN;
BEGIN
   RETURN TRUE;
END CheckW;

//--------------------------------------------------------------------------------

PROCEDURE MakeDriverW() : ADDRESS;
BEGIN
   IF RefCount = 0 THEN
     netinit.Startup();
     threadinit.Startup();
   END;
   INC( RefCount );

   RETURN NEW( CEIBDriver );
END MakeDriverW;

//--------------------------------------------------------------------------------

PROCEDURE DisposeDriverW( PData : ADDRESS );
BEGIN
   DISPOSE( TPEIBDriver( PData ));

   DEC( RefCount );
   IF RefCount = 0 THEN
     threadinit.Cleanup();
     netinit.Cleanup();
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
   RETURN TPEIBDriver( PData )^.Init( SymbolicName, CallbackId, PCallback );
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
   s : ARRAY [0..3] OF WCHAR;
BEGIN
   IF RunFlag THEN
      RunMode := drv_def.drmRun;
   ELSE
      RunMode := drv_def.drmEdit;
   END;
   ErrorMessage[0] := CHAR( 0 );
   IF InitCommon( PData, RunMode, s, CallbackId, drv_def.TDriverCallbackW( PCallback ), em ) THEN
      IF NOT ReadParameters( PData, ParFilePath, ErrorMessage, el, ec, hoh ) THEN
         RETURN FALSE;
      END;
      RunW( PData );
   ELSIF em[0] = 0W THEN
      Strings.ToA( OAsz( driver.R()^[ Texts._InitError ] ), 0, OUT ErrorMessage );
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
   ErrorMessage[0] := 0W;
   IF InitCommon( PData, RunMode, hoh, CallbackId, PCallback, ErrorMessage ) THEN
      IF NOT ReadParametersW( PData, ParFilePath, ErrorMessage, el, ec, hoh ) THEN
         RETURN FALSE;
      END;
      RunW( PData );
   ELSIF ErrorMessage[0] = 0W THEN
      ASSIGN( ErrorMessage, OAsz( driver.R()^[ Texts._InitError ] ));
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
   em, pf : StringsO.CString;
   l : CARDINAL;
   b : BOOLEAN;
BEGIN
   ErrorColumn := 0;
   HintOrHelp := C'';
   
   pf.FromOAA( 0, ParFilePath );
   b := TPEIBDriver( PData )^.ReadParameters( pf, OUT em, OUT ErrorLine );
   em.ToOAA( 0, OUT ErrorMessage, OUT l );
   
   RETURN b;
END ReadParameters;

PROCEDURE ReadParametersW(            PData : ADDRESS;
                                        VAR ParFilePath  : ARRAY OF WCHAR;
                                        VAR ErrorMessage : ARRAY OF WCHAR;
                                        VAR ErrorLine    : CARDINAL;
                                        VAR ErrorColumn  : CARDINAL;
                                        VAR HintOrHelp   : ARRAY OF WCHAR ) : BOOLEAN;
VAR
   em, pf : StringsO.CString;
   b : BOOLEAN;
BEGIN
   ErrorColumn := 0;
   HintOrHelp := L'';

   pf.FromOA( ParFilePath );
   b := TPEIBDriver( PData )^.ReadParameters( pf, OUT em, OUT ErrorLine );
   em.ToOA( OUT ErrorMessage );

   RETURN b;
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
   RETURN TPEIBDriver( PData )^.EnumerateChannels( EnumerateState, Type, Direction, DriverIndex, Count, HaveDescription );
END EnumerateChannelsW;

PROCEDURE GetChannelDescription( PData : ADDRESS;
                                                 DriverIndex : CARDINAL;
                                                 VAR Description : ARRAY OF CHAR;
                                                 VAR Id : ARRAY OF CHAR
                                                ) : BOOLEAN;
VAR
   desc : ARRAY [0..255] OF WCHAR;
   id : ARRAY [0..64] OF WCHAR;
   b : BOOLEAN;
BEGIN
   b := TPEIBDriver( PData )^.GetChannelDescription( DriverIndex, desc, id );
   IF b THEN
      Strings.ToA( desc, 0, OUT Description );
      Strings.ToA( id, 0, OUT Id );
   END;
   RETURN b;
END GetChannelDescription;

PROCEDURE GetChannelDescriptionW( PData : ADDRESS;
                                                   DriverIndex : CARDINAL;
                                                   VAR Description : ARRAY OF WCHAR;
                                                   VAR Id : ARRAY OF WCHAR
                                                ) : BOOLEAN;
BEGIN
   RETURN TPEIBDriver( PData )^.GetChannelDescription( DriverIndex, Description, Id );
END GetChannelDescriptionW;

//--------------------------------------------------------------------------------

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
   | driver.ceDeviceUnplugged :
      ASSIGN( ErrorText, OAsz( driver.R()^[ Texts._E_DeviceUnplugged ] ));
   | driver.ceLCONError :
      ASSIGN( ErrorText, OAsz( driver.R()^[ Texts._E_LCONError ] ));
   | driver.ceRD_RES_Timeout :
      ASSIGN( ErrorText, OAsz( driver.R()^[ Texts._E_RD_RES_Timeout ] ));
   | driver.ceLineBusy :
      ASSIGN( ErrorText, OAsz( driver.R()^[ Texts._E_LineBusy ] ));
   | driver.ceTransceiverFault :
      ASSIGN( ErrorText, OAsz( driver.R()^[ Texts._E_TransceiverFault ] ));
   | driver.ceOutputQueueOverflow :
      ASSIGN( ErrorText, OAsz( driver.R()^[ Texts._E_OutputQueueOverflow ] ));
   | driver.ceReadQueueOverflow :
      ASSIGN( ErrorText, OAsz( driver.R()^[ Texts._E_ReadQueueOverflow ] ));
   | driver.ceWriteQueueOverflow :
      ASSIGN( ErrorText, OAsz( driver.R()^[ Texts._E_WriteQueueOverflow ] ));
   ELSE
      RETURN FALSE;
   END;
   RETURN TRUE;
END QueryErrorCodeW;

//--------------------------------------------------------------------------------

PROCEDURE RunW( PData : ADDRESS );
BEGIN
   TPEIBDriver( PData )^.Run();
END RunW;

//--------------------------------------------------------------------------------

PROCEDURE StopW( PData : ADDRESS );
BEGIN
   TPEIBDriver( PData )^.Stop();
END StopW;

//--------------------------------------------------------------------------------

PROCEDURE DoneW( PData : ADDRESS );
BEGIN
   TPEIBDriver( PData )^.Dispose();
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
   TPEIBDriver( PData )^.QueryProc( FALSE, InValue1, InValue2, OutValue );
END QueryProc3;

//--------------------------------------------------------------------------------

PROCEDURE QueryProc3W( PData : ADDRESS; InValue1, InValue2 : drv_def.TValue; VAR OutValue : drv_def.TValue );
BEGIN
   TPEIBDriver( PData )^.QueryProc( FALSE, InValue1, InValue2, OutValue );
END QueryProc3W;

//--------------------------------------------------------------------------------

PROCEDURE InputRequestStartW( PData : ADDRESS );
BEGIN
   TPEIBDriver( PData )^.InputRequestStart();
END InputRequestStartW;

//--------------------------------------------------------------------------------

PROCEDURE InputRequestW( PData : ADDRESS; DriverIndex : CARDINAL );
BEGIN
   TPEIBDriver( PData )^.InputRequest( DriverIndex );
END InputRequestW;

//--------------------------------------------------------------------------------

PROCEDURE InputRequestCompletedW( PData : ADDRESS );
BEGIN
   TPEIBDriver( PData )^.InputRequestCompleted();
END InputRequestCompletedW;

//--------------------------------------------------------------------------------

PROCEDURE InputFinalizedW( PData : ADDRESS; DriverIndex : CARDINAL; VAR ErrorCode : CARDINAL ) : BOOLEAN;
BEGIN
   RETURN TPEIBDriver( PData )^.InputFinalized( DriverIndex, ErrorCode );
END InputFinalizedW;

//--------------------------------------------------------------------------------

PROCEDURE InputOOBDataQueryW( PData : ADDRESS; VAR EnumerateState : LONGWORD; VAR DriverIndex : CARDINAL ) : BOOLEAN;
BEGIN
   RETURN TPEIBDriver( PData )^.InputOOBDataQuery( EnumerateState, DriverIndex );
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
   TPEIBDriver( PData )^.GetInput( FALSE, DriverIndex, InValue, QoS, TimeStamp, ErrorCode );
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
   TPEIBDriver( PData )^.GetInput( TRUE, DriverIndex, InValue, QoS, TimeStamp, ErrorCode );
END GetInput3W;

//--------------------------------------------------------------------------------

PROCEDURE OutputRequestStartW( PData : ADDRESS );
BEGIN
   TPEIBDriver( PData )^.OutputRequestStart();
END OutputRequestStartW;

//--------------------------------------------------------------------------------

PROCEDURE OutputRequest( PData : ADDRESS; DriverIndex : CARDINAL; OutValue : drv_def.TValue );
VAR
   ts : drv_def.TUTCStamp;
BEGIN
   OutputRequest3( PData, DriverIndex, OutValue, drv_def.qosGood, ts );
END OutputRequest;

PROCEDURE OutputRequest3( PData : ADDRESS; DriverIndex : CARDINAL; OutValue : drv_def.TValue; QoS : CARDINAL; VAR TimeStamp : drv_def.TUTCStamp );
BEGIN
   TPEIBDriver( PData )^.OutputRequest( FALSE, DriverIndex, OutValue, QoS, TimeStamp );
END OutputRequest3;

PROCEDURE OutputRequestW( PData : ADDRESS; DriverIndex : CARDINAL; OutValue : drv_def.TValue );
VAR
   ts : drv_def.TUTCStamp;
BEGIN
   OutputRequest3W( PData, DriverIndex, OutValue, drv_def.qosGood, ts );
END OutputRequestW;

PROCEDURE OutputRequest3W( PData : ADDRESS; DriverIndex : CARDINAL; OutValue : drv_def.TValue; QoS : CARDINAL; VAR TimeStamp : drv_def.TUTCStamp );
BEGIN
   TPEIBDriver( PData )^.OutputRequest( TRUE, DriverIndex, OutValue, QoS, TimeStamp );
END OutputRequest3W;

//--------------------------------------------------------------------------------

PROCEDURE OutputRequestCompletedW( PData : ADDRESS );
BEGIN
   TPEIBDriver( PData )^.OutputRequestCompleted();
END OutputRequestCompletedW;

//--------------------------------------------------------------------------------

PROCEDURE OutputFinalizedW( PData : ADDRESS; DriverIndex : CARDINAL; VAR ErrorCode : CARDINAL ) : BOOLEAN;
BEGIN
   RETURN TPEIBDriver( PData )^.OutputFinalized( DriverIndex, ErrorCode );
END OutputFinalizedW;

//================================================================================

END diface.