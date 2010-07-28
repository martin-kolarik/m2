IMPLEMENTATION MODULE diface;

FROM Storage IMPORT
   ALLOCATE, DEALLOCATE;

IMPORT
   log,
   scinit,
   Strings;

(*================================================================================*)

VAR
   Factory : TPCWDriverFactory := NIL;
   RefCount : CARDINAL := 0;

(*================================================================================*)

PROCEDURE RegisterFactory( _Factory : TPCWDriverFactory );
BEGIN
   Factory := _Factory;
END RegisterFactory;

(*================================================================================*)
// procedural interface

PROCEDURE VersionW() : CARDINAL;
BEGIN
   RETURN 030000H;
END VersionW;

(*--------------------------------------------------------------------------------*)

PROCEDURE GetDriverInfo( VAR DriverName : ARRAY OF CHAR );
VAR
   c : CARDINAL;
BEGIN
   IF Factory = NIL THEN
      DriverName := C"";
   ELSE
      Factory^.DriverName.ToOAA( 0, OUT DriverName, OUT c );
   END;
END GetDriverInfo;

(*--------------------------------------------------------------------------------*)

PROCEDURE GetDriverInfoW( VAR DriverNameW : ARRAY OF WCHAR );
BEGIN
   IF Factory = NIL THEN
      DriverNameW := L"";
   ELSE
      Factory^.DriverName.ToOA( OUT DriverNameW );
   END;
END GetDriverInfoW;

(*--------------------------------------------------------------------------------*)

PROCEDURE Check( VAR ErrorString : ARRAY OF CHAR; CWVersion, MajorVersion, MinorVersion, APIMajorVersion, APIMinorVersion : CARDINAL ): BOOLEAN;
BEGIN
   RETURN TRUE;
END Check;

(*--------------------------------------------------------------------------------*)

PROCEDURE CheckW( VAR ErrorString : ARRAY OF WCHAR; CWVersion, MajorVersion, MinorVersion, APIMajorVersion, APIMinorVersion : CARDINAL ): BOOLEAN;
BEGIN
   RETURN TRUE;
END CheckW;

(*--------------------------------------------------------------------------------*)

PROCEDURE MakeDriverW() : ADDRESS;
VAR
   Driver : TPCWDriver := NIL;
BEGIN
   IF RefCount = 0 THEN
      scinit.Startup();
   END;
   
   IF Factory = NIL THEN
      // fall down
   ELSIF Factory^.CreateInstance( OUT Driver ) THEN
      INC( RefCount );
   END;

   RETURN Driver;
END MakeDriverW;

(*--------------------------------------------------------------------------------*)

PROCEDURE DisposeDriverW( PData : ADDRESS );
BEGIN
   IF PData = NIL THEN
      RETURN;
   ELSIF Factory = NIL THEN
      RETURN;
   END;

   Factory^.DeleteInstance( TPCWDriver( PData ));

   DEC( RefCount );
   IF RefCount = 0 THEN
     scinit.Cleanup();
   END;
END DisposeDriverW;

(*--------------------------------------------------------------------------------*)

PROCEDURE InitCommon( PData : ADDRESS; RunMode : CARDINAL; CONST SymbolicName : ARRAY OF WCHAR; CallbackId : ADDRESS; PCallback : drv_def.TDriverCallbackW );
VAR
   LSymbolicName : StringsO.CString;
BEGIN
   LSymbolicName.FromOA( SymbolicName );
   TPCWDriver( PData )^.Initialize( RunMode, LSymbolicName, CallbackId, PCallback );
END InitCommon;

PROCEDURE Init( PData : ADDRESS; VAR ParFilePath : ARRAY OF CHAR; VAR ErrorMessage : ARRAY OF CHAR; UserLevel : CARDINAL; RunFlag : BOOLEAN; CallbackId : ADDRESS; PCallback : drv_def.TDriverCallbackW ) : BOOLEAN;
VAR
   ec, el  : CARDINAL;
   hoh : ARRAY [0..3] OF CHAR;
   name : ARRAY [0..63] OF WCHAR;
   RunMode : CARDINAL;
BEGIN
   IF RunFlag THEN
      RunMode := drv_def.drmRun;
   ELSE
      RunMode := drv_def.drmEdit;
   END;
   IF Factory = NIL THEN
      name := L"";
   ELSE
      Factory^.DriverName.ToOA( OUT name );
   END;
   InitCommon( PData, RunMode, name, CallbackId, drv_def.TDriverCallbackW( PCallback ));

   ErrorMessage[0] := CHAR( 0 );
   IF NOT ReadParameters( PData, ParFilePath, ErrorMessage, el, ec, hoh ) THEN
      RETURN FALSE;
   END;
   RunW( PData );

   RETURN TRUE;
END Init;

PROCEDURE Init3( PData : ADDRESS; RunMode : CARDINAL; VAR SymbolicName : ARRAY OF CHAR; CallbackId : ADDRESS; PCallback : drv_def.TDriverCallbackW ) : BOOLEAN;
VAR
   sn : ARRAY [0..255] OF WCHAR;
BEGIN
   Strings.ToW( SymbolicName, 0, OUT sn );
   InitCommon( PData, RunMode, sn, CallbackId, drv_def.TDriverCallbackW( PCallback ));
   RETURN TRUE;
END Init3;

PROCEDURE InitW( PData : ADDRESS; VAR ParFilePath  : ARRAY OF WCHAR; VAR ErrorMessage : ARRAY OF WCHAR; UserLevel : CARDINAL; RunFlag : BOOLEAN; CallbackId : ADDRESS; PCallback : drv_def.TDriverCallbackW ) : BOOLEAN;
VAR
   ec, el : CARDINAL;
   hoh : ARRAY [0..3] OF WCHAR;
   name : ARRAY [0..63] OF WCHAR;
   RunMode : CARDINAL;
BEGIN
   IF RunFlag THEN
      RunMode := drv_def.drmRun;
   ELSE
      RunMode := drv_def.drmEdit;
   END;
   IF Factory = NIL THEN
      name := L"";
   ELSE
      Factory^.DriverName.ToOA( OUT name );
   END;
   InitCommon( PData, RunMode, name, CallbackId, PCallback );

   ErrorMessage[0] := 0W;
   IF NOT ReadParametersW( PData, ParFilePath, ErrorMessage, el, ec, hoh ) THEN
      RETURN FALSE;
   END;
   RunW( PData );

   RETURN TRUE;
END InitW;

PROCEDURE Init3W( PData : ADDRESS; RunMode : CARDINAL; VAR SymbolicName : ARRAY OF WCHAR; CallbackId : ADDRESS; PCallback : drv_def.TDriverCallbackW ) : BOOLEAN;
BEGIN
   InitCommon( PData, RunMode, SymbolicName, CallbackId, PCallback );
   RETURN TRUE;
END Init3W;

(*--------------------------------------------------------------------------------*)

PROCEDURE ReadParameters( PData : ADDRESS; VAR ParFilePath  : ARRAY OF CHAR; VAR ErrorMessage : ARRAY OF CHAR; VAR ErrorLine : CARDINAL; VAR ErrorColumn  : CARDINAL; VAR HintOrHelp   : ARRAY OF CHAR ) : BOOLEAN;
VAR
   b : BOOLEAN;
   em : ARRAY [0..511] OF WCHAR; 
   l : CARDINAL;
   lg : log.CBufferedLogger;
   pf : StringsO.CString;
BEGIN
   lg.TimeStamps := FALSE;
   lg.Levels := FALSE;
   lg.Names := FALSE;
   lg.Output := log.outsNone;
   lg.BufferSize := 1;
   lg.BufferMode := log.bmStoreFirst;

   ErrorColumn := 0;
   HintOrHelp := C'';
   
   pf.FromOAA( 0, ParFilePath );
   b := TPCWDriver( PData )^.ReadParameters( pf, lg );
   lg.BufferGetItem( 0, OUT em );
   Strings.ToA( em, 0, OUT ErrorMessage );
   
   RETURN b;
END ReadParameters;

PROCEDURE ReadParametersW( PData : ADDRESS; VAR ParFilePath  : ARRAY OF WCHAR; VAR ErrorMessage : ARRAY OF WCHAR; VAR ErrorLine    : CARDINAL; VAR ErrorColumn  : CARDINAL; VAR HintOrHelp   : ARRAY OF WCHAR ) : BOOLEAN;
VAR
   b : BOOLEAN;
   lg : log.CBufferedLogger;
   pf : StringsO.CString;
BEGIN
   lg.TimeStamps := FALSE;
   lg.Levels := FALSE;
   lg.Names := FALSE;
   lg.Output := log.outsNone;
   lg.BufferSize := 1;
   lg.BufferMode := log.bmStoreFirst;

   ErrorColumn := 0;
   HintOrHelp := L'';

   pf.FromOA( ParFilePath );
   b := TPCWDriver( PData )^.ReadParameters( pf, lg );
   lg.BufferGetItem( 0, OUT ErrorMessage );

   RETURN b;
END ReadParametersW;

(*--------------------------------------------------------------------------------*)

PROCEDURE EnumerateChannelsW( PData : ADDRESS; VAR EnumerateState : LONGWORD; VAR Type : CARDINAL; VAR Direction : CARDINAL; VAR DriverIndex : CARDINAL; VAR Count : CARDINAL; VAR HaveDescription : BOOLEAN ): BOOLEAN;
VAR
   b : BOOLEAN;
   ValueDirection : drv_def.TDirection;
   ValueType : drv_def.TValueType;
BEGIN
   b := TPCWDriver( PData )^.EnumerateChannels( REF EnumerateState, OUT ValueType, OUT ValueDirection, OUT DriverIndex, OUT Count, OUT HaveDescription );
   IF b THEN
      Type := CARDINAL( ValueType );
      Direction := CARDINAL( ValueDirection );
   END;
   RETURN b;
END EnumerateChannelsW;

(*--------------------------------------------------------------------------------*)

PROCEDURE GetChannelDescription( PData : ADDRESS; DriverIndex : CARDINAL; VAR Description : ARRAY OF CHAR; VAR Id : ARRAY OF CHAR ) : BOOLEAN;
VAR
   b : BOOLEAN;
   c : CARDINAL;
   desc : StringsO.CString;
   id : StringsO.CString;
BEGIN
   b := TPCWDriver( PData )^.GetChannelDescription( DriverIndex, OUT desc, OUT id );
   IF b THEN
      desc.ToOAA( 0, OUT Description, OUT c );
      id.ToOAA( 0, OUT Id, OUT c );
   END;
   RETURN b;
END GetChannelDescription;

PROCEDURE GetChannelDescriptionW( PData : ADDRESS; DriverIndex : CARDINAL; VAR Description : ARRAY OF WCHAR; VAR Id : ARRAY OF WCHAR ) : BOOLEAN;
VAR
   b : BOOLEAN;
   desc : StringsO.CString;
   id : StringsO.CString;
BEGIN
   b := TPCWDriver( PData )^.GetChannelDescription( DriverIndex, OUT desc, OUT id );
   IF b THEN
      desc.ToOA( OUT Description );
      id.ToOA( OUT Id );
   END;
   RETURN b;
END GetChannelDescriptionW;

(*--------------------------------------------------------------------------------*)

PROCEDURE QueryErrorCode( PData : ADDRESS; ErrorCode : CARDINAL; VAR ErrorText : ARRAY OF CHAR ) : BOOLEAN;
VAR
   b : BOOLEAN;
   c : CARDINAL;
   et : StringsO.CString;
BEGIN
   b := TPCWDriver( PData )^.QueryErrorCode( ErrorCode, OUT et );
   IF b THEN
      et.ToOAA( 0, OUT ErrorText, OUT c );
   END;
   RETURN b;
END QueryErrorCode;

PROCEDURE QueryErrorCodeW( PData : ADDRESS; ErrorCode : CARDINAL; VAR ErrorText : ARRAY OF WCHAR ) : BOOLEAN;
VAR
   b : BOOLEAN;
   et : StringsO.CString;
BEGIN
   b := TPCWDriver( PData )^.QueryErrorCode( ErrorCode, OUT et );
   IF b THEN
      et.ToOA( OUT ErrorText );
   END;
   RETURN b;
END QueryErrorCodeW;

(*--------------------------------------------------------------------------------*)

PROCEDURE RunW( PData : ADDRESS );
BEGIN
   TPCWDriver( PData )^.DriverRun();
END RunW;

PROCEDURE StopW( PData : ADDRESS );
BEGIN
   TPCWDriver( PData )^.DriverStop();
END StopW;

PROCEDURE DoneW( PData : ADDRESS );
BEGIN
   StopW( PData );
   TPCWDriver( PData )^.Dispose();
END DoneW;

(*--------------------------------------------------------------------------------*)

PROCEDURE DriverProcW( PData : ADDRESS; Func, Param1, Param2, Param3, Param4 : CARDINAL );
BEGIN
   TPCWDriver( PData )^.DriverProc( Func, Param1, Param2, Param3, Param4 );
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
VAR
   ioin1, ioin2, ioout : iovalue.Value;
   limit : CARDINAL := -1;
BEGIN
   drv_def.CWValueToIOValue( InValue1, FALSE, REF ioin1 );
   drv_def.CWValueToIOValue( InValue2, FALSE, REF ioin2 );
   IF OutValue.Type = drv_def.vtDriverString THEN
      limit := OutValue.ValDriverStringCharLength;
   END;
   TPCWDriver( PData )^.QueryProc( ioin1, ioin2, limit, OUT ioout );
   drv_def.IOValueToCWValue( ioout, FALSE, FALSE, REF OutValue );
END QueryProc3;

PROCEDURE QueryProc3W( PData : ADDRESS; InValue1, InValue2 : drv_def.TValue; VAR OutValue : drv_def.TValue );
VAR
   ioin1, ioin2, ioout : iovalue.Value;
   limit : CARDINAL := -1;
BEGIN
   drv_def.CWValueToIOValue( InValue1, TRUE, REF ioin1 );
   drv_def.CWValueToIOValue( InValue2, TRUE, REF ioin2 );
   IF OutValue.Type = drv_def.vtDriverString THEN
      limit := OutValue.ValDriverStringCharLength;
   END;
   TPCWDriver( PData )^.QueryProc( ioin1, ioin2, limit, OUT ioout );
   drv_def.IOValueToCWValue( ioout, TRUE, FALSE, REF OutValue );
END QueryProc3W;

(*--------------------------------------------------------------------------------*)

PROCEDURE InputRequestStartW( PData : ADDRESS );
BEGIN
   TPCWDriver( PData )^.InputRequestStart();
END InputRequestStartW;

(*--------------------------------------------------------------------------------*)

PROCEDURE InputRequestW( PData : ADDRESS; DriverIndex : CARDINAL );
BEGIN
   TPCWDriver( PData )^.InputRequest( DriverIndex );
END InputRequestW;

(*--------------------------------------------------------------------------------*)

PROCEDURE InputRequestCompletedW( PData : ADDRESS );
BEGIN
   TPCWDriver( PData )^.InputRequestCompleted();
END InputRequestCompletedW;

(*--------------------------------------------------------------------------------*)

PROCEDURE InputFinalizedW( PData : ADDRESS; DriverIndex : CARDINAL; VAR ErrorCode : CARDINAL ) : BOOLEAN;
BEGIN
   RETURN TPCWDriver( PData )^.InputFinalized( DriverIndex, OUT ErrorCode );
END InputFinalizedW;

(*--------------------------------------------------------------------------------*)

PROCEDURE InputOOBDataQueryW( PData : ADDRESS; VAR EnumerateState : LONGWORD; VAR DriverIndex : CARDINAL ) : BOOLEAN;
BEGIN
   RETURN TPCWDriver( PData )^.InputOOBDataQuery( REF EnumerateState, OUT DriverIndex );
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
VAR
   io : iovalue.Value;
   limit : CARDINAL := -1;
BEGIN
   IF InValue.Type = drv_def.vtDriverString THEN
      limit := InValue.ValDriverStringCharLength;
   END;
   TPCWDriver( PData )^.GetInput( DriverIndex, limit, OUT io, OUT QoS, OUT TimeStamp, OUT ErrorCode );
   drv_def.IOValueToCWValue( io, FALSE, FALSE, REF InValue );
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
VAR
   io : iovalue.Value;
   limit : CARDINAL := -1;
BEGIN
   IF InValue.Type = drv_def.vtDriverString THEN
      limit := InValue.ValDriverStringCharLength;
   END;
   TPCWDriver( PData )^.GetInput( DriverIndex, limit, OUT io, OUT QoS, OUT TimeStamp, OUT ErrorCode );
   drv_def.IOValueToCWValue( io, TRUE, FALSE, REF InValue );
END GetInput3W;

(*--------------------------------------------------------------------------------*)

PROCEDURE OutputRequestStartW( PData : ADDRESS );
BEGIN
   TPCWDriver( PData )^.OutputRequestStart();
END OutputRequestStartW;

(*--------------------------------------------------------------------------------*)

PROCEDURE OutputRequest( PData : ADDRESS; DriverIndex : CARDINAL; OutValue : drv_def.TValue );
VAR
   ts : drv_def.TUTCStamp;
BEGIN
   OutputRequest3( PData, DriverIndex, OutValue, drv_def.qosGood, ts );
END OutputRequest;

PROCEDURE OutputRequest3( PData : ADDRESS; DriverIndex : CARDINAL; OutValue : drv_def.TValue; QoS : CARDINAL; VAR TimeStamp : drv_def.TUTCStamp );
VAR
   out : iovalue.Value;
BEGIN
   drv_def.CWValueToIOValue( OutValue, FALSE, REF out );
   TPCWDriver( PData )^.OutputRequest( DriverIndex, out, QoS, TimeStamp );
END OutputRequest3;

PROCEDURE OutputRequestW( PData : ADDRESS; DriverIndex : CARDINAL; OutValue : drv_def.TValue );
VAR
   ts : drv_def.TUTCStamp;
BEGIN
   OutputRequest3W( PData, DriverIndex, OutValue, drv_def.qosGood, ts );
END OutputRequestW;

PROCEDURE OutputRequest3W( PData : ADDRESS; DriverIndex : CARDINAL; OutValue : drv_def.TValue; QoS : CARDINAL; VAR TimeStamp : drv_def.TUTCStamp );
VAR
   out : iovalue.Value;
BEGIN
   drv_def.CWValueToIOValue( OutValue, TRUE, REF out );
   TPCWDriver( PData )^.OutputRequest( DriverIndex, out, QoS, TimeStamp );
END OutputRequest3W;

(*--------------------------------------------------------------------------------*)

PROCEDURE OutputRequestCompletedW( PData : ADDRESS );
BEGIN
   TPCWDriver( PData )^.OutputRequestCompleted();
END OutputRequestCompletedW;

(*--------------------------------------------------------------------------------*)

PROCEDURE OutputFinalizedW( PData : ADDRESS; DriverIndex : CARDINAL; VAR ErrorCode : CARDINAL ) : BOOLEAN;
BEGIN
   RETURN TPCWDriver( PData )^.OutputFinalized( DriverIndex, OUT ErrorCode );
END OutputFinalizedW;

(*================================================================================*)

BEGIN FINALLY
   Factory := NIL;
END diface.