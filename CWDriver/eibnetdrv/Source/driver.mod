IMPLEMENTATION MODULE driver;

(*# call( o_a_copy => off ) *)

//================================================================================
(*/* changes:

23.12.2007 -- started to consolidate after split from srvcore/eibsrv.

*/*)
//================================================================================

IMPORT
   windows;

FROM Storage IMPORT
   ALLOCATE, DEALLOCATE;

IMPORT
   cllv,
   drv_str,
   eib_def,
   eib_user,
   eib_status,
   FIO,
   FIOO,
   INIFile,
   IOO,
   Log,
   Resources,
   Strings,
   StringsO,
   TextReader,
   Texts,
   Time;

//================================================================================

TYPE
   TStatusChannelItem = (
      schiUSBConnected,
      schiEIBConnected,
      schiInitReadPending,
      schiInputQueueOverflow,
      schiHavePromiscuousData,
      schiValid
   );
   TStatusChannel = SET OF TStatusChannelItem;

//-----

//================================================================================
// helpers

PROCEDURE LogNumber2Group( LogNumber : CARDINAL; VAR LongForm : BOOLEAN; VAR M, S, G : CARDINAL );
BEGIN
   IF LogNumber > 10000000 - 1 THEN
      LongForm := TRUE;
      LogNumber :=  LogNumber - 10000000;
   ELSE
      LongForm := FALSE;
   END;
   G := LogNumber MOD 1000;
   LogNumber := LogNumber DIV 1000;
   S := LogNumber MOD 100;
   M := LogNumber DIV 100;
   IF LongForm THEN
      G := 1000 * S + G;
      S := 0;
   END;
END LogNumber2Group;

//--------------------------------------------------------------------------------

PROCEDURE LogNumber2Address( LogNumber : CARDINAL; VAR Address : eib_def.CAddress );
VAR
   G, M, S : CARDINAL;
   LongForm : BOOLEAN;
BEGIN
   LogNumber2Group( LogNumber, LongForm, M, S, G );
   IF LongForm THEN
      Address.SetGroupAddress4( M, G );
   ELSE
      Address.SetGroupAddress2( M, S, G );
   END;
END LogNumber2Address;

//================================================================================

CLASS IMPLEMENTATION CEIBDriver;

//--------------------------------------------------------------------------------

   PUBLIC PROCEDURE Init( CONST SymbolicName : ARRAY OF WCHAR; CallbackId : ADDRESS; PCallback : drv_def.TDriverCallbackW ) : BOOLEAN;
   BEGIN
      SELF.CallbackId := CallbackId;
      SELF.CallbackProc := PCallback;

      SUPER.Init();
      RETURN TRUE;
   END Init;

//--------------------------------------------------------------------------------

   PUBLIC PROCEDURE ReadParameters( CONST ParFilePath : StringsO.CString; OUT ErrorMessage : StringsO.CString; OUT ErrorLine : CARDINAL ) : BOOLEAN;

   //----------
   
      PROCEDURE AppendErrorId( REF ErrorMessage : StringsO.CString; ErrorId : ARRAY OF WCHAR );
      BEGIN
         ErrorMessage.AppendOA( L" (" );
         ErrorMessage.AppendOA( ErrorId );
         ErrorMessage.AppendOA( L")" );
      END AppendErrorId;

   //----------
   
   CONST
      snDevice = L'device';
      knStatusChannel = L'status_channel';
      knIQChannel = L'input_queue_length_channel';
      knOQChannel = L'output_queue_length_channel';
      knWQChannel = L'write_queue_length_channel';
   VAR
      c : CARDINAL;
      fs : FIOO.CFileStream;
      tr : TextReader.CTextReader;
      TS : INIFile.CINIFile;
      b : BOOLEAN;
   BEGIN
      IF NOT LoadConfiguration( ParFilePath, OUT ErrorMessage, OUT ErrorLine ) THEN
         RETURN FALSE;
      END;
   
      TRY
         fs.FromPath( OA( ParFilePath.Length-1, ParFilePath.rawData ), FIOO.imOpenRead );
      CATCH e : IOO.CIOException DO
         ErrorMessage.FromOA( OAsz( R()^[ Texts._CannotOpenPar ] ));
         AppendErrorId( REF ErrorMessage, OA( ParFilePath.Length-1, ParFilePath.rawData ));
         RETURN FALSE;
      END; // try
      tr.Stream := ADR( fs );
      b := TS.Load( tr );
      fs.Close( FALSE );
      IF NOT b THEN
         ErrorMessage.FromOA( OAsz( R()^[ Texts._CannotOpenPar ] ));
         AppendErrorId( REF ErrorMessage, OA( ParFilePath.Length-1, ParFilePath.rawData ));
         RETURN FALSE;
      END;

      StatusChannel := MAX( CARDINAL );
      InputQueueLengthChannel := MAX( CARDINAL );
      OutputQueueLengthChannel := MAX( CARDINAL );
      WriteQueueLengthChannel := MAX( CARDINAL );
      IF TS.SetSection( snDevice ) THEN
         IF TS.GetKeyInt( knStatusChannel, OUT ErrorLine, OUT c ) THEN
            StatusChannel := c;
         END;
         IF TS.GetKeyInt( knIQChannel, OUT ErrorLine, OUT c ) THEN
            InputQueueLengthChannel := c;
         END;
         IF TS.GetKeyInt( knOQChannel, OUT ErrorLine, OUT c ) THEN
            OutputQueueLengthChannel := c;
         END;
         IF TS.GetKeyInt( knWQChannel, OUT ErrorLine, OUT c ) THEN
            WriteQueueLengthChannel := c;
         END;
      END; // IF snDevice

      RETURN TRUE;
   END ReadParameters;

//--------------------------------------------------------------------------------

   PUBLIC PROCEDURE EnumerateChannels( VAR EnumerateState : LONGWORD; VAR Type : CARDINAL; VAR Direction : CARDINAL; VAR DriverIndex : CARDINAL; VAR Count : CARDINAL; VAR HaveDescription : BOOLEAN ): BOOLEAN;
   LABEL
      Described;
   CONST
      directionInput = eib_def.TA_ObjectFlags{eib_def.aofUpdate, eib_def.aofWritable, eib_def.aofInitRead, eib_def.aofAdvise};
      directionOutput = eib_def.TA_ObjectFlags{eib_def.aofTransmit, eib_def.aofReadable};
   VAR
      Index : CARDINAL;
      OCount : CARDINAL := Objects.Count;
      PObject : srvcore.TPObject;
   BEGIN
      IF EnumerateState = LONGWORD( 0 ) THEN // start enumeration
         IF OCount = 0 THEN
            RETURN FALSE;
         ELSE
            Index := CARDINAL( EnumerateState );
         END;
      ELSE // continue enumeration
         Index := CARDINAL( EnumerateState );
         IF Index < OCount THEN
            // fall down
         ELSE
            Direction := CARDINAL( drv_def.dirInput );
            HaveDescription := TRUE;
            Type := CARDINAL( drv_def.vtLongCard );
            LOOP
               IF Index > OCount + 3 THEN
                  RETURN FALSE;
               ELSIF ( Index = OCount ) AND ( StatusChannel <> MAX( CARDINAL )) THEN
                  // enumerate status channel
                  DriverIndex := StatusChannel;
                  GOTO Described;
               ELSIF ( Index = OCount + 1 ) AND ( InputQueueLengthChannel <> MAX( CARDINAL )) THEN
                  // enumerate input_queue_length channel
                  DriverIndex := InputQueueLengthChannel;
                  GOTO Described;
               ELSIF ( Index = OCount + 2 ) AND ( OutputQueueLengthChannel <> MAX( CARDINAL )) THEN
                  // enumerate input_queue_length channel
                  DriverIndex := OutputQueueLengthChannel;
                  GOTO Described;
               ELSIF ( Index = OCount + 3 ) AND ( WriteQueueLengthChannel <> MAX( CARDINAL )) THEN
                  // enumerate input_queue_length channel
                  DriverIndex := WriteQueueLengthChannel;
                  GOTO Described;
               END;
               INC( Index );
            END; // LOOP
         END;
      END;

      PObject := srvcore.TPObject( Objects[ Index ] );
      CASE PObject^.Value.GetType() OF
      | eib_def.eitSwitch :     Type := CARDINAL( drv_def.vtBoolean );
      | eib_def.eitIncrease :   Type := CARDINAL( drv_def.vtShortInt );
      | eib_def.eitTime :       Type := CARDINAL( drv_def.vtLongCard );
      | eib_def.eitDate :       Type := CARDINAL( drv_def.vtLongReal );
      | eib_def.eitValue,
        eib_def.eitValueRange : Type := CARDINAL( drv_def.vtLongReal );
      | eib_def.eitScaling,
        eib_def.eitScaling255 : Type := CARDINAL( drv_def.vtShortCard );
      | eib_def.eitMove :       Type := CARDINAL( drv_def.vtBoolean );
      | eib_def.eitFloat :      Type := CARDINAL( drv_def.vtLongReal );
      | eib_def.eit16bit :      Type := CARDINAL( drv_def.vtLongCard );
      | eib_def.eit32bit :      Type := CARDINAL( drv_def.vtLongCard );
      | eib_def.eitChar :       Type := CARDINAL( drv_def.vtDString );
      | eib_def.eit8bit :       Type := CARDINAL( drv_def.vtShortCard );
      | eib_def.eitString :     Type := CARDINAL( drv_def.vtDString);
      END; // CASE EV.Type

      IF directionOutput * PObject^.Flags = eib_def.TA_ObjectFlags{} THEN
         Direction := CARDINAL( drv_def.TDirection{drv_def.dirInput} );
      ELSIF directionInput * PObject^.Flags = eib_def.TA_ObjectFlags{} THEN
         Direction := CARDINAL( drv_def.TDirection{drv_def.dirOutput} );
      ELSE
         Direction := CARDINAL( drv_def.TDirection{drv_def.dirInput, drv_def.dirOutput} );
      END;

      DriverIndex := PObject^.LogNumber();
      HaveDescription := NOT PObject^.Name.Empty OR NOT PObject^.Comment.Empty;

   Described:
      Count := 1;

      INC( Index );
      EnumerateState := Index;
      RETURN TRUE;
   END EnumerateChannels;

//--------------------------------------------------------------------------------

   PUBLIC PROCEDURE GetChannelDescription( DriverIndex : CARDINAL; VAR Description : ARRAY OF WCHAR; VAR Id : ARRAY OF WCHAR ) : BOOLEAN;
   CONST
      _StatusId            = L'drvStatus';
      _InputQueueLengthId  = L'drvInputQueueLength';
      _OutputQueueLengthId = L'drvOutputQueueLength';
      _WriteQueueLengthId  = L'drvWriteQueueLength';
   VAR
      PObject : srvcore.TPObject;
   BEGIN
      IF DriverIndex = StatusChannel THEN
         ASSIGN( Description, OAsz( R()^[ Texts._StatusComment ] ));
         ASSIGN( Id, _StatusId );
      ELSIF DriverIndex = InputQueueLengthChannel THEN
         ASSIGN( Description, OAsz( R()^[ Texts._InputQueueLengthComment ] ));
         ASSIGN( Id, _InputQueueLengthId );
      ELSIF DriverIndex = OutputQueueLengthChannel THEN
         ASSIGN( Description, OAsz( R()^[ Texts._OutputQueueLengthComment ] ));
         ASSIGN( Id, _OutputQueueLengthId );
      ELSIF DriverIndex = WriteQueueLengthChannel THEN
         ASSIGN( Description, OAsz( R()^[ Texts._WriteQueueLengthComment ] ));
         ASSIGN( Id, _WriteQueueLengthId );
      ELSIF LogNumber2Object( DriverIndex, PObject ) THEN
         PObject^.Name.ToOA( OUT Id );
         PObject^.Comment.ToOA( OUT Description );
      ELSE
         RETURN FALSE;
      END;
      RETURN TRUE;
   END GetChannelDescription;

//--------------------------------------------------------------------------------

   PUBLIC PROCEDURE InputRequestStart();
   BEGIN
   END InputRequestStart;

//--------------------------------------------------------------------------------

   PUBLIC PROCEDURE InputRequest( DriverIndex : CARDINAL );
   VAR
      EV : eib_def.TValue;
      PObject : srvcore.TPObject;
   BEGIN
      Result.Inc();
      IF ( DriverIndex = StatusChannel ) OR
          ( DriverIndex = InputQueueLengthChannel ) OR
          ( DriverIndex = OutputQueueLengthChannel ) OR
          ( DriverIndex = WriteQueueLengthChannel ) THEN
         // pass down
      ELSIF NOT LogNumber2Object( DriverIndex, PObject ) THEN
         // pass down
      ELSIF eib_user.TObjectState{eib_user.osInitReadPending, eib_user.osReading} * PObject^.State <> eib_user.TObjectState{} THEN
         // pass down
      ELSIF eib_def.aofForceRead IN PObject^.GetFlags() THEN
         IF ( PObject^.RecoveryExpiration <> 0 ) AND ( INTEGER( PObject^.RecoveryExpiration - CARDINAL( windows.GetTickCount())) < 0 ) THEN
            // still cannot read, pass away
            RETURN;
         END;
         // start reading itself
         PObject^.ReadRepeatCount := ReadDuringRun.RepeatCount;
         PObject^.GetValue( EV, FALSE, FALSE );
      END;
   END InputRequest;

//--------------------------------------------------------------------------------

   PUBLIC PROCEDURE InputRequestCompleted();
   BEGIN
   END InputRequestCompleted;

//--------------------------------------------------------------------------------

   PUBLIC PROCEDURE InputFinalized( DriverIndex : CARDINAL; VAR ErrorCode : CARDINAL ) : BOOLEAN;
   VAR
      PObject : srvcore.TPObject;
   BEGIN
      IF ( DriverIndex = StatusChannel ) OR
          ( DriverIndex = InputQueueLengthChannel ) OR
          ( DriverIndex = OutputQueueLengthChannel ) OR
          ( DriverIndex = WriteQueueLengthChannel ) THEN
         ErrorCode := drv_def.ecSuccess;
      ELSIF NOT LogNumber2Object( DriverIndex, PObject ) THEN
         ErrorCode := drv_def.ecUnknownElement;
      ELSIF NOT HWConnected( ErrorCode ) THEN
         PObject^.CancelIO();
      ELSIF eib_user.osReading IN PObject^.State THEN
         RETURN FALSE;
      ELSIF Result.Expired OR Result.Counted THEN
         RETURN FALSE;
      ELSIF PObject^.RSStatus = eib_status.essOK THEN
         ErrorCode := drv_def.ecSuccess;
      ELSE
         ErrorCode := EIBStatus2ErrorCode( PObject^.RSStatus );
      END;
      RETURN TRUE;
   END InputFinalized;

//--------------------------------------------------------------------------------

   PUBLIC PROCEDURE InputOOBDataQuery( VAR EnumerateState : LONGWORD; VAR DriverIndex : CARDINAL ) : BOOLEAN;
   BEGIN
      IF CARDINAL( EnumerateState ) >= oobData.Count THEN
         EXCL( RStatus, srvcore.rsProcessingOOB );
         oobData.Dispose();
         RETURN FALSE;
      ELSIF srvcore.rsProcessingOOB NOT IN RStatus THEN
         INCL( RStatus, srvcore.rsProcessingOOB );
         oobData.Reset();
      END;
      oobData.MoveNext();
      DriverIndex := srvcore.TPObject( oobData.CurrentData )^.LogNumber();
      EnumerateState := CARDINAL( EnumerateState ) + 1;
      RETURN TRUE;
   END InputOOBDataQuery;

//--------------------------------------------------------------------------------

   PUBLIC PROCEDURE GetInput( UFlag : BOOLEAN; DriverIndex : CARDINAL; VAR InValue : drv_def.TValue; VAR QoS : CARDINAL; VAR TimeStamp : drv_def.TUTCStamp; VAR ErrorCode : CARDINAL );
   VAR
      c : CARDINAL;
      Day : eib_def.TDay;
      EV : eib_def.TValue;
      PObject : srvcore.TPObject;
      s : ARRAY [0..31] OF WCHAR;
      Status : TStatusChannel;
      Y, M, D, H, S : CARDINAL;
      wch : WCHAR;
      b1 : BOOLEAN;
      b2 : BOOLEAN;
   BEGIN
      IF DriverIndex = StatusChannel THEN
         QoS := drv_def.qosGood;
         ErrorCode := drv_def.ecSuccess;

         Status := TStatusChannel{};
         IF EIB^.DeviceConnected() THEN
            INCL( Status, schiUSBConnected );
         END;
         IF PromiscuousMode THEN
            IF prData.Count >= InputQueueLength THEN
               INCL( Status, schiInputQueueOverflow );
            END;
         ELSE
            IF oobData.Count >= InputQueueLength THEN
               INCL( Status, schiInputQueueOverflow );
            END;
         END;
         IF EIB^.EIBConnected() THEN
            INCL( Status, schiEIBConnected );
         END;
         IF NOT( srvcore.rsInitReadFinished IN RStatus ) THEN
            INCL( Status, schiInitReadPending );
         END;
         IF srvcore.rsPromiscuousInQueue IN RStatus THEN
            INCL( Status, schiHavePromiscuousData );
         END;
         IF Result.Counted OR Result.Expired THEN
            EXCL( Status, schiValid );
         ELSE
            INCL( Status, schiValid );
         END;

         drv_def.AssignValueCardinal( InValue, TRUE, CARDINAL( Status ));

      ELSIF DriverIndex = InputQueueLengthChannel THEN
         QoS := drv_def.qosGood;
         ErrorCode := drv_def.ecSuccess;
         drv_def.AssignValueCardinal( InValue, TRUE, CARDINAL( oobData.Count ));

      ELSIF DriverIndex = OutputQueueLengthChannel THEN
         QoS := drv_def.qosGood;
         ErrorCode := drv_def.ecSuccess;
         drv_def.AssignValueCardinal( InValue, TRUE, CARDINAL( EIB^.OutputQueueLength() ));

      ELSIF DriverIndex = WriteQueueLengthChannel THEN
         QoS := drv_def.qosGood;
         ErrorCode := drv_def.ecSuccess;
         drv_def.AssignValueCardinal( InValue, TRUE, CARDINAL( EIB^.WriteQueueLength() ));

      ELSIF NOT LogNumber2Object( DriverIndex, PObject ) THEN
         QoS := drv_def.qosBad;
         ErrorCode := drv_def.ecUnknownElement;

      ELSE
         ErrorCode := EIBStatus2ErrorCode( PObject^.RSStatus );
         IF ErrorCode <> drv_def.ecSuccess THEN
            QoS := drv_def.qosBad;
            RETURN;
         ELSIF eib_def.aofEIBValue IN PObject^.GetFlags() THEN
            QoS := drv_def.qosGood;
         ELSE
            QoS := drv_def.qosBad;
         END;

         PObject^.GetValue( EV, TRUE, FALSE );
         IF srvcore.rsProcessingOOB IN RStatus THEN
            oobData.Current^.ToOA( OUT EV.Data, OUT c );
         END;

         CASE EV.GetType() OF
         | eib_def.eitUnknown :
            ErrorCode := drv_def.ecValueProcessing;
         | eib_def.eitSwitch :
            drv_def.AssignValueBoolean( InValue, TRUE, EV.GetSwitch() );
         | eib_def.eitIncrease :
            c := EV.GetIncrease( b1, b2 );
            IF b1 THEN
               drv_def.AssignValueInteger( InValue, TRUE, INTEGER( c ));
            ELSIF b2 THEN
               drv_def.AssignValueInteger( InValue, TRUE, -INTEGER( c ));
            ELSE
               drv_def.AssignValueInteger( InValue, TRUE, 0 );
            END;
         | eib_def.eitTime :
            EV.GetTime( Day, H, M, S );
            drv_def.AssignValueCardinal( InValue, TRUE, CARDINAL( Day ) * 100000 + ( H * 60 + M ) * 60 + S );
         | eib_def.eitDate :
            EV.GetDate( Y, M, D );
            drv_def.AssignValueLongReal( InValue, TRUE, Time.ToSJD( Time.JD( Y, M, D, 0 )));
         | eib_def.eitValue,
            eib_def.eitValueRange :
            drv_def.AssignValueLongReal( InValue, TRUE, EV.GetValue() );
         | eib_def.eitScaling :
            drv_def.AssignValueCardinal( InValue, TRUE, EV.GetScaling() );
         | eib_def.eitScaling255 :
            drv_def.AssignValueCardinal( InValue, TRUE, EV.GetScaling255() );
         | eib_def.eitMove :
            drv_def.AssignValueBoolean( InValue, TRUE, EV.GetMove() );
         | eib_def.eitFloat :
            drv_def.AssignValueLongReal( InValue, TRUE, EV.GetFloat() );
         | eib_def.eit16bit :
            drv_def.AssignValueCardinal( InValue, TRUE, EV.Get16bit() );
         | eib_def.eit32bit :
            drv_def.AssignValueCardinal( InValue, TRUE, EV.Get32bit() );
         | eib_def.eitChar :
            wch := EV.GetChar();
            InValue.ValDriverStringCharLength := 1;
            IF UFlag THEN
               Strings.MoveW( ADR( wch ), InValue.ValDriverStringAddress, 1 );
            ELSE
               Strings.ToA( OA( 0, ADR( wch )), 0, OUT OA( 0, PCHAR( InValue.ValDriverStringAddress )));
            END;
         | eib_def.eit8bit :
            drv_def.AssignValueCardinal( InValue, TRUE, EV.Get8bit() );
         | eib_def.eitString :
            EV.GetString( s );
            InValue.ValDriverStringCharLength := MIN2( InValue.ValDriverStringCharLength, LENGTH( s ));
            IF UFlag THEN
               Strings.MoveW( ADR( s ), InValue.ValDriverStringAddress, InValue.ValDriverStringCharLength );
            ELSE
               c := InValue.ValDriverStringCharLength-1;
               Strings.ToA( OA( c, ADR( s )), 0, OUT OA( c, PCHAR( InValue.ValDriverStringAddress )));
            END;
         END; // CASE EV.Type

      END;
   END GetInput;

//--------------------------------------------------------------------------------

   PUBLIC PROCEDURE OutputRequestStart();
   BEGIN
   END OutputRequestStart;

//--------------------------------------------------------------------------------

   PUBLIC PROCEDURE OutputRequest( UFlag : BOOLEAN; DriverIndex : CARDINAL; OutValue : drv_def.TValue; QoS : CARDINAL; TimeStamp : drv_def.TUTCStamp );
   VAR
      EV : eib_def.TValue;
      PObject : srvcore.TPObject;
   BEGIN
      Result.Inc();
      IF LogNumber2Object( DriverIndex, PObject ) THEN
         CWValue2EIBValue( UFlag, OutValue, PObject^.Value.GetType(), OUT EV );
         PObject^.SetValue( EV );
      END;
   END OutputRequest;

//--------------------------------------------------------------------------------

   PUBLIC PROCEDURE OutputRequestCompleted();
   BEGIN
   END OutputRequestCompleted;

//--------------------------------------------------------------------------------

   PUBLIC PROCEDURE OutputFinalized( DriverIndex : CARDINAL; VAR ErrorCode : CARDINAL ) : BOOLEAN;
   VAR
      PObject : srvcore.TPObject;
   BEGIN
      IF NOT LogNumber2Object( DriverIndex, PObject ) THEN
         ErrorCode := drv_def.ecUnknownElement;
      ELSIF NOT HWConnected( ErrorCode ) THEN
         PObject^.CancelIO();
      ELSIF eib_user.osWritting IN PObject^.State THEN
         RETURN FALSE;
      ELSIF Result.Expired OR Result.Counted THEN
         RETURN FALSE;
      ELSIF PObject^.WSStatus = eib_status.essOK THEN
         ErrorCode := drv_def.ecSuccess;
      ELSE
         ErrorCode := EIBStatus2ErrorCode( PObject^.WSStatus );
      END;
      RETURN TRUE;
   END OutputFinalized;

//--------------------------------------------------------------------------------

   PUBLIC PROCEDURE QueryProc( UFlag : BOOLEAN; InValue1, InValue2 : drv_def.TValue; VAR OutValue : drv_def.TValue );
   LABEL
      Error;
   VAR
      CS : StringsO.CString;
      EIT : eib_def.TEIBType;
      EV : eib_def.TValue;
      LValue : drv_def.TValue;
      N, V : ARRAY [0..63] OF WCHAR;
      s : ARRAY [0..15] OF WCHAR;
   BEGIN
      drv_def.DrvValueToCStringW( InValue1, UFlag, OUT CS );
      CS.ItemSOA( StringsO.WCHARS{ L' ' }, 0, 0, TRUE, OUT N );

      IF EQUALS( N, L'send' ) THEN
         CS.ItemSOA( StringsO.WCHARS{ L' ' }, 0, 1, TRUE, OUT N );
         IF N[0] = WCHAR( 0 ) THEN
            CS.FromOA( L'error: "send" procedure, missing group address' );
            GOTO Error;
         END;
         CS.ItemSOA( StringsO.WCHARS{ L' ' }, 0, 2, TRUE, OUT s );
         IF s[0] = WCHAR( 0 ) THEN
            CS.FromOA( L'error: "send" procedure, missing value type' );
            GOTO Error;
         END;
         CS.ItemSOA( StringsO.WCHARS{ L' ' }, 0, 3, TRUE, OUT V );
         IF V[0] = WCHAR( 0 ) THEN
            CS.FromOA( L'error: "send" procedure, missing value' );
            GOTO Error;
         END;

         IF Result.Counted THEN
            CS.Clear();
            GOTO Error;
         ELSIF NOT eib_def.StringToType( s, EIT ) THEN
            CS.FromOA( L'error: "send" procedure, bad type name (' );
            CS.AppendOA( s );
            CS.AppendOA( L')' );
            GOTO Error;
         ELSIF NOT prObjects[EIT].prAddress.SetGroupAddress3( N ) THEN
            CS.FromOA( L'error: "send" procedure, bad group address (' );
            CS.AppendOA( N );
            CS.AppendOA( L')' );
            GOTO Error;
         ELSIF Result.Expired THEN
            CS.Clear();
            GOTO Error;
         END;

         drv_def.InitValue( LValue );
         drv_def.SetValueString( LValue, V );
         CWValue2EIBValue( TRUE, LValue, EIT, OUT EV );
         prObjects[EIT].SetValue( EV );
         drv_def.DoneValue( LValue )

      ELSE
         CS.FromOA( L'error: unknown driver procedure' );
      END;

   Error:
      drv_def.AssignDrvValueCStringW( REF OutValue, UFlag, FALSE, CS );
      Result.Inc();
   END QueryProc;

//--------------------------------------------------------------------------------

   LOCAL PROCEDURE LogNumber2Object( LogNumber : CARDINAL; VAR PObject : srvcore.TPObject ) : BOOLEAN;
   VAR
      a : eib_def.CAddress;
      c : CARDINAL;
   BEGIN
      IF Objects.Count = 0 THEN
         RETURN FALSE;
      END;

      LogNumber2Address( LogNumber, a );
      c := a.GetGroupAddress1();
      IF Groups[ CARD16( c ) ] = 0FFFFH THEN
         RETURN FALSE;
      END;

      PObject := Objects[ CARDINAL( Groups[ CARD16( c ) ] ) ];
      RETURN TRUE;
   END LogNumber2Object;

//--------------------------------------------------------------------------------

   PROCEDURE EIBStatus2ErrorCode( Status : eib_status.TEIBStackStatus ) : CARDINAL;
   BEGIN 
      CASE Status OF
      | eib_status.essOK :
         RETURN drv_def.ecSuccess;
      | eib_status.essConError, eib_status.essL_Timeout :
         RETURN ceLCONError;
      | eib_status.essA_Timeout :
         RETURN ceRD_RES_Timeout;
      | eib_status.essLineBusy :
         RETURN ceLineBusy;
      | eib_status.essTransceiverFault :
         RETURN ceTransceiverFault;
      ELSE
         RETURN ceTransceiverFault; // drv_def.ecValueProcessing;
      END;
   END EIBStatus2ErrorCode;

//--------------------------------------------------------------------------------

   PROCEDURE HWConnected( VAR ErrorCode : CARDINAL ) : BOOLEAN;
   BEGIN
      IF NOT EIB^.DeviceConnected() THEN
         ErrorCode := ceDeviceUnplugged;
         RETURN FALSE;
      ELSE
         RETURN TRUE;
      END;
   END HWConnected;

//--------------------------------------------------------------------------------

   INTERNAL PROCEDURE CWValue2EIBValue( UFlag : BOOLEAN; CONST Value : drv_def.TValue; DestEVType : eib_def.TEIBType; OUT EV : eib_def.TValue );
   VAR
      c : CARDINAL;
      Day : eib_def.TDay;
      fd : CARDINAL;
      H, M, S, WD : CARDINAL;
      i : INTEGER;
      s : ARRAY [0..31] OF WCHAR;
      ST : windows.SYSTEMTIME;
      Y, MM, D : INTEGER;
   BEGIN
      EV.SetType( DestEVType );

      CASE EV.GetType() OF
      | eib_def.eitUnknown :
         RETURN;
      | eib_def.eitSwitch :
         EV.SetSwitch( drv_def.ValueToBoolean( Value, TRUE ));
      | eib_def.eitIncrease :
         i := drv_def.ValueToInteger( Value, TRUE );
         IF i = 0 THEN
            EV.SetIncrease( FALSE, FALSE, 0 );
         ELSIF i < 0 THEN
            EV.SetIncrease( FALSE, TRUE, CARDINAL( -i ));
         ELSE
            EV.SetIncrease( TRUE, FALSE, CARDINAL( i ));
         END;
      | eib_def.eitTime :
         c := drv_def.ValueToCardinal( Value, TRUE );
         WD := c DIV 100000;
         c := c - WD * 100000;
         H := c DIV 3600;
         c := c - H * 3600;
         M := c DIV 60;
         S := c MOD 60;
         CASE WD OF
         | 0 :
            windows.GetLocalTime( ADR( ST ));
            Day := eib_def.TDay( 1 + ( CARDINAL( ST.wDayOfWeek ) + 6 ) MOD 7 );
         | 1..7 :
            Day := eib_def.TDay( WD );
         ELSE
            Day := eib_def.dayNo;
         END;
         EV.SetTime( Day, H, M, S );
      | eib_def.eitDate :
         Time.iJD( Time.FromSJD( drv_def.ValueToLongReal( Value, TRUE )), OUT Y, OUT MM, OUT D, OUT fd );
         EV.SetDate( Y, MM, D );
      | eib_def.eitValue, eib_def.eitValueRange :
         EV.SetValue( drv_def.ValueToLongReal( Value, TRUE ));
      | eib_def.eitScaling :
         EV.SetScaling( CARDINAL( drv_def.ValueToCard8( Value, TRUE )) );
      | eib_def.eitScaling255 :
         EV.SetScaling255( drv_def.ValueToCard8( Value, TRUE ));
      | eib_def.eitMove :
         EV.SetMove( drv_def.ValueToBoolean( Value, TRUE ));
      | eib_def.eitFloat :
         EV.SetFloat( drv_def.ValueToLongReal( Value, TRUE ));
      | eib_def.eit16bit :
         c:= drv_def.ValueToCard32( Value, TRUE );
         IF c > MAX( CARD16 ) THEN
            c := MAX( CARD16 );
         END;
         EV.Set16bit( c );
      | eib_def.eit32bit :
         EV.Set32bit( drv_def.ValueToCardinal( Value, TRUE ));
      | eib_def.eitChar :
         IF UFlag THEN
            Strings.MoveW( Value.ValDriverStringAddress, ADR( s ), 1 );
         ELSE
            Strings.ToW( OA( 0, PCHAR( Value.ValDriverStringAddress )), 0, OUT OA( 0, ADR( s )) );
         END;
         EV.SetChar( s[0] );
      | eib_def.eit8bit :
         EV.Set8bit( CARDINAL( drv_def.ValueToCard8( Value, TRUE )) );
      | eib_def.eitString :
         c := MIN2( SIZE( eib_def.TEISString ), Value.ValDriverStringCharLength );
         IF UFlag THEN
            Strings.MoveW( Value.ValDriverStringAddress, ADR( s ), c );
         ELSE
            DEC( c );
            Strings.ToW( OA( c, PCHAR( Value.ValDriverStringAddress )), 0, OUT OA( c, ADR( s )) );
         END;
         s[c] := 0W;
         EV.SetString( s );
      END; // CASE EV.Type
   
   END CWValue2EIBValue;

//================================================================================

   PUBLIC VIRTUAL PROCEDURE OnConnect();
   BEGIN
      CallbackProc( CallbackId, drv_def.dcfException, NIL );
   END OnConnect;

//================================================================================

   PUBLIC VIRTUAL PROCEDURE OnDisconnect();
   BEGIN
      CallbackProc( CallbackId, drv_def.dcfInputFinalized, NIL );
      CallbackProc( CallbackId, drv_def.dcfOutputFinalized, NIL );
      CallbackProc( CallbackId, drv_def.dcfException, NIL );
   END OnDisconnect;

//================================================================================

   PUBLIC VIRTUAL PROCEDURE OnInitReadCompleted();
   BEGIN
      CallbackProc( CallbackId, drv_def.dcfException, NIL );
   END OnInitReadCompleted;

//================================================================================

   PUBLIC VIRTUAL PROCEDURE OnRead( PObject : srvcore.TPObject );
   BEGIN
      CallbackProc( CallbackId, drv_def.dcfInputFinalized, NIL );
   END OnRead;

//================================================================================

   PUBLIC VIRTUAL PROCEDURE OnWritten( PObject : srvcore.TPObject );
   BEGIN
      CallbackProc( CallbackId, drv_def.dcfOutputFinalized, NIL );
   END OnWritten;

//================================================================================

   PUBLIC VIRTUAL PROCEDURE OnInputQueueAdd();
   BEGIN
      IF PromiscuousMode THEN // promiscuous mode queueing
         CallbackProc( CallbackId, drv_def.dcfException, NIL );
      ELSE
         CallbackProc( CallbackId, drv_def.dcfOOBDataAdvise, NIL );
      END;
   END OnInputQueueAdd;

//================================================================================

   PUBLIC VIRTUAL PROCEDURE OnInputQueueOverflow();
   BEGIN
      CallbackProc( CallbackId, drv_def.dcfException, NIL );
   END OnInputQueueOverflow;

//================================================================================

BEGIN
   CallbackId := NIL;
   CallbackProc := NIL;

   EventSink := ADR( SELF );
   
   StatusChannel := MAX( CARDINAL );
   InputQueueLengthChannel := MAX( CARDINAL );   
   OutputQueueLengthChannel := MAX( CARDINAL );
   WriteQueueLengthChannel := MAX( CARDINAL );

   cllvData := ADR( cllv.data );
   cllvLength := cllv.length;
END CEIBDriver;

//================================================================================

VAR
   r : Resources.CResources;

PROCEDURE R() : Resources.TPResources;
BEGIN
   RETURN ADR( r );
END R;

//================================================================================

INITIALLY __I();
BEGIN
   // messages
   r.LoadRES2( EMITW( %dll ), L"eibnetdrv.Texts" );
   // logging
   Log.logger()^.SetUpByRegistry( LIBRARY );
END __I;

//================================================================================

END driver.