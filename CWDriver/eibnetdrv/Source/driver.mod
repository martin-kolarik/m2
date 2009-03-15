MODULE driver;

(*# call( o_a_copy => off ) *)

//================================================================================
(*/* changes:

23.12.2007 -- started to consolidate after split from srvcore/eibsrv.

*/*)
//================================================================================

FROM Storage IMPORT
   ALLOCATE, DEALLOCATE;

IMPORT
   cllv,
   diface,
   drv_def,
   eib_def,
   eib_user,
   eib_status,
   FIO,
   FIOO,
   INIFile,
   IOO,
   iovalue,
   log,
   msgqueuethread,
   Resources,
   srvcore,
   Strings,
   StringsO,
   Sync,
   TextReader,
   Texts,
   threadcall,
   Time;

//================================================================================

VAR
   dr : Resources.CResources;

PROCEDURE DR() : Resources.TPResources;
BEGIN
   RETURN ADR( dr );
END DR;

//================================================================================

CONST
   OP_RUN = 1;
   OP_STOP = 2;
   OP_DISPOSE = 3;
   OP_FINALLY = 4;
   
   TIMER_WATCH_DOG = 1305;

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

CONST
   WD_TICK = 1000;

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

PROCEDURE EITToCWType( EIT : eib_def.TEIBType ) : drv_def.TValueType;
BEGIN
   CASE EIT OF
   | eib_def.eitSwitch :     RETURN drv_def.vtBoolean;
   | eib_def.eitIncrease :   RETURN drv_def.vtShortInt;
   | eib_def.eitTime :       RETURN drv_def.vtLongCard;
   | eib_def.eitDate :       RETURN drv_def.vtLongReal;
   | eib_def.eitValue,
     eib_def.eitValueRange : RETURN drv_def.vtLongReal;
   | eib_def.eitScaling,
     eib_def.eitScaling255 : RETURN drv_def.vtShortCard;
   | eib_def.eitMove :       RETURN drv_def.vtBoolean;
   | eib_def.eitFloat :      RETURN drv_def.vtLongReal;
   | eib_def.eit16bit :      RETURN drv_def.vtLongCard;
   | eib_def.eit32bit :      RETURN drv_def.vtLongCard;
   | eib_def.eitChar :       RETURN drv_def.vtDString;
   | eib_def.eit8bit :       RETURN drv_def.vtShortCard;
   | eib_def.eitString :     RETURN drv_def.vtDString;
   END; // CASE EV.Type
   RETURN drv_def.vtUnknown;
END EITToCWType;

//================================================================================

TYPE
   TPEIBDriver = POINTER TO CEIBDriver;

CONST // device specific error codes
   ceDeviceUnplugged                = 10001H;
   // ceNoEIBConnection                = 10002H;
   // ceBUSMONActive                   = 10003H;
   ceLCONError                      = 10004H;
   ceRD_RES_Timeout                 = 10005H;
   ceLineBusy                       = 10006H;
   ceTransceiverFault               = 10007H;
   ceOutputQueueOverflow            = 10008H;
   ceReadQueueOverflow              = 10009H;
   ceWriteQueueOverflow             = 1000AH;
   // cePromiscuousModeRunning         = 1000BH;

//--------------------------------------------------------------------------------

CLASS CEIBDriver( srvcore.CEIBServer ) IMPLEMENTS diface.ICWDriver, srvcore.IEIBServerSink, threadcall.IThreadProcedureCallTarget;
   CallbackId               : ADDRESS;
   CallbackProc             : drv_def.TDriverCallbackW;
   ClientName               : ARRAY [0..63] OF WCHAR;

   StatusChannel            : CARDINAL;
   WatchDogChannel          : CARDINAL;
   InputQueueLengthChannel  : CARDINAL;
   OutputQueueLengthChannel : CARDINAL;
   WriteQueueLengthChannel  : CARDINAL;
   
   WatchDogLock             : Sync.LOCK;
   WatchDogLeft             : CARDINAL;

   // ICWDriver
   PUBLIC VIRTUAL PROCEDURE Initialize( RunMode : CARDINAL; CONST SymbolicName : StringsO.CString; CallbackId : ADDRESS; CallbackProc : drv_def.TDriverCallbackW );
   PUBLIC VIRTUAL PROCEDURE ReadParameters( CONST ParFilePath : StringsO.CString; CONST Logger : log.CLogger ) : BOOLEAN;
   PUBLIC VIRTUAL PROCEDURE QueryErrorCode( ErrorCode : CARDINAL; OUT ErrorText : StringsO.CString ) : BOOLEAN;
   PUBLIC VIRTUAL PROCEDURE EnumerateChannels( REF EnumerateState : LONGWORD; OUT Type : drv_def.TValueType; OUT Direction : drv_def.TDirection; OUT DriverIndex, Count : CARDINAL; OUT HaveDescription : BOOLEAN ): BOOLEAN;
   PUBLIC VIRTUAL PROCEDURE GetChannelDescription( DriverIndex : CARDINAL; OUT Description, Id : StringsO.CString ) : BOOLEAN;
   
   PUBLIC VIRTUAL PROCEDURE DriverRun();
   PUBLIC VIRTUAL PROCEDURE DriverStop();
   PUBLIC VIRTUAL PROCEDURE Dispose();

   PUBLIC VIRTUAL PROCEDURE DriverProc( Func, Param1, Param2, Param3, Param4 : CARDINAL );
   PUBLIC VIRTUAL PROCEDURE QueryProc( CONST InValue1, InValue2 : iovalue.Value; OutValueStringLimit : CARDINAL; OUT OutValue : iovalue.Value );

   PUBLIC VIRTUAL PROCEDURE InputRequestStart();
   PUBLIC VIRTUAL PROCEDURE InputRequest( DriverIndex : CARDINAL );
   PUBLIC VIRTUAL PROCEDURE InputRequestCompleted();
   PUBLIC VIRTUAL PROCEDURE InputFinalized( DriverIndex : CARDINAL; OUT ErrorCode : CARDINAL ) : BOOLEAN;
   PUBLIC VIRTUAL PROCEDURE InputOOBDataQuery( REF EnumerateState : LONGWORD; OUT DriverIndex : CARDINAL ) : BOOLEAN;
   PUBLIC VIRTUAL PROCEDURE GetInput( DriverIndex : CARDINAL; InValueStringLimit : CARDINAL; OUT InValue : iovalue.Value; OUT QoS : CARDINAL; OUT TimeStamp : drv_def.TUTCStamp; OUT ErrorCode : CARDINAL );

   PUBLIC VIRTUAL PROCEDURE OutputRequestStart();
   PUBLIC VIRTUAL PROCEDURE OutputRequest( DriverIndex : CARDINAL; CONST OutValue : iovalue.Value; QoS : CARDINAL; CONST TimeStamp : drv_def.TUTCStamp );
   PUBLIC VIRTUAL PROCEDURE OutputRequestCompleted();
   PUBLIC VIRTUAL PROCEDURE OutputFinalized( DriverIndex : CARDINAL; OUT ErrorCode : CARDINAL ) : BOOLEAN;

   // index/log number management
   LOCAL PROCEDURE LogNumber2Object( LogNumber : CARDINAL; VAR PObject : srvcore.TPObject ) : BOOLEAN;
   PROCEDURE EIBStatus2ErrorCode( Status : eib_status.TEIBStackStatus ) : CARDINAL;
   PROCEDURE HWConnected( VAR ErrorCode : CARDINAL ) : BOOLEAN;

   // IThreadProcedureCallTarget
   PUBLIC VIRTUAL PROCEDURE Invoke( Operation : CARDINAL; CONST Parameters : ARRAY OF PTR ) : PTR;

   // IEIBServerSink
   PUBLIC VIRTUAL PROCEDURE OnConnect();
   PUBLIC VIRTUAL PROCEDURE OnDisconnect();
   PUBLIC VIRTUAL PROCEDURE OnInitReadCompleted();
   PUBLIC VIRTUAL PROCEDURE OnRead( PObject : srvcore.TPObject );
   PUBLIC VIRTUAL PROCEDURE OnWritten( PObject : srvcore.TPObject );
   PUBLIC VIRTUAL PROCEDURE OnInputQueueAdd( OOBQueue, PromiscuousQueue : BOOLEAN );
   PUBLIC VIRTUAL PROCEDURE OnInputQueueOverflow( OOBQueue, PromiscuousQueue : BOOLEAN );

   // MessageHandlers
   INTERNAL VIRTUAL PROCEDURE OnTimer( TimerId : PTR );
END CEIBDriver;

//================================================================================

CLASS IMPLEMENTATION CEIBDriver;

//--------------------------------------------------------------------------------

   PUBLIC VIRTUAL PROCEDURE Initialize( RunMode : CARDINAL; CONST SymbolicName : StringsO.CString; CallbackId : ADDRESS; CallbackProc : drv_def.TDriverCallbackW );
   BEGIN
      SELF.CallbackId := CallbackId;
      SELF.CallbackProc := CallbackProc;
      SymbolicName.ToOA( OUT ClientName );
      SUPER.Init( TRUE );
   END Initialize;

//--------------------------------------------------------------------------------

   PUBLIC VIRTUAL PROCEDURE ReadParameters( CONST ParFilePath : StringsO.CString; CONST Logger : log.CLogger ) : BOOLEAN;

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
      knWatchDogChannel = L'watchdog_channel';
      knIQChannel = L'input_queue_length_channel';
      knOQChannel = L'output_queue_length_channel';
      knWQChannel = L'write_queue_length_channel';
   VAR
      c : CARDINAL;
      fs : FIOO.CFileStream;
      ErrorLine : CARDINAL;
      ErrorMessage : StringsO.CString;
      tr : TextReader.CTextReader;
      TS : INIFile.CINIFile;
      b : BOOLEAN;
   BEGIN
      IF NOT LoadConfiguration( ParFilePath, OUT ErrorMessage, OUT ErrorLine ) THEN
         Logger.LogFilePos( log.dlcError, ClientName, OA( ParFilePath.Length-1, ParFilePath.rawData ), OA( ErrorMessage.Length-1, ErrorMessage.rawData ), ErrorLine, 0 );
         RETURN FALSE;
      END;
   
      TRY
         fs.FromPath( OA( ParFilePath.Length-1, ParFilePath.rawData ), FIOO.imOpenRead );
      CATCH e : IOO.CIOException DO
         ErrorMessage.FromOA( OAsz( DR()^[ Texts._CannotOpenPar ] ));
         AppendErrorId( REF ErrorMessage, OA( ParFilePath.Length-1, ParFilePath.rawData ));
         RETURN FALSE;
      END; // try
      tr.Stream := ADR( fs );
      b := TS.Load( tr );
      fs.Close( FALSE );
      IF NOT b THEN
         ErrorMessage.FromOA( OAsz( DR()^[ Texts._CannotOpenPar ] ));
         AppendErrorId( REF ErrorMessage, OA( ParFilePath.Length-1, ParFilePath.rawData ));
         RETURN FALSE;
      END;

      CASE INIFile.ConfigureLog( TS, L"", REF SELF.Logger, OUT ErrorLine ) OF
      | INIFile.clrUnknownTarget :
         Logger.LogFilePos( log.dlcError, ClientName, OA( ParFilePath.Length-1, ParFilePath.rawData ), OAsz( DR()^[ Texts._UnknownDebugMode ] ), ErrorLine, 0 );
         RETURN FALSE;
      | INIFile.clrUnknownLevel :
         Logger.LogFilePos( log.dlcError, ClientName, OA( ParFilePath.Length-1, ParFilePath.rawData ), OAsz( DR()^[ Texts._UnknownDebugLevel ] ), ErrorLine, 0 );
         RETURN FALSE;
      | INIFile.clrTargetFileMissingFile :
         Logger.LogFilePos( log.dlcError, ClientName, OA( ParFilePath.Length-1, ParFilePath.rawData ), OAsz( DR()^[ Texts._FileDebugMissingFile ] ), ErrorLine, 0 );
         RETURN FALSE;
      END;

      StatusChannel := MAX( CARDINAL );
      WatchDogChannel := MAX( CARDINAL );
      InputQueueLengthChannel := MAX( CARDINAL );
      OutputQueueLengthChannel := MAX( CARDINAL );
      WriteQueueLengthChannel := MAX( CARDINAL );

      IF TS.SetSection( snDevice ) THEN
         IF TS.GetKeyInt( knStatusChannel, OUT ErrorLine, OUT c ) THEN
            StatusChannel := c;
         END;
         IF TS.GetKeyInt( knWatchDogChannel, OUT ErrorLine, OUT c ) THEN
            WatchDogChannel := c;
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

   PUBLIC VIRTUAL PROCEDURE EnumerateChannels( REF EnumerateState : LONGWORD; OUT Type : drv_def.TValueType; OUT Direction : drv_def.TDirection; OUT DriverIndex, Count : CARDINAL; OUT HaveDescription : BOOLEAN ): BOOLEAN;
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
      Index := CARDINAL( EnumerateState );
      IF Index >= OCount THEN // process special channels, not objects
         Direction := drv_def.TDirection{ drv_def.dirInput };
         HaveDescription := TRUE;
         Type := drv_def.vtLongCard;
         LOOP
            IF Index > OCount + 4 THEN
               RETURN FALSE;
            ELSIF ( Index = OCount ) AND ( StatusChannel <> MAX( CARDINAL )) THEN
               // enumerate status channel
               DriverIndex := StatusChannel;
               GOTO Described;
            ELSIF ( Index = OCount + 1 ) AND ( WatchDogChannel <> MAX( CARDINAL )) THEN
               // enumerate watch dog channel
               Direction := drv_def.TDirection{drv_def.dirOutput};
               DriverIndex := WatchDogChannel;
               GOTO Described;
            ELSIF ( Index = OCount + 2 ) AND ( InputQueueLengthChannel <> MAX( CARDINAL )) THEN
               // enumerate input_queue_length channel
               DriverIndex := InputQueueLengthChannel;
               GOTO Described;
            ELSIF ( Index = OCount + 3 ) AND ( OutputQueueLengthChannel <> MAX( CARDINAL )) THEN
               // enumerate input_queue_length channel
               DriverIndex := OutputQueueLengthChannel;
               GOTO Described;
            ELSIF ( Index = OCount + 4 ) AND ( WriteQueueLengthChannel <> MAX( CARDINAL )) THEN
               // enumerate input_queue_length channel
               DriverIndex := WriteQueueLengthChannel;
               GOTO Described;
            END;
            INC( Index );
         END; // LOOP
      END;

      PObject := srvcore.TPObject( Objects[ Index ] );
      Type := EITToCWType( PObject^.Type );

      IF directionOutput * PObject^.Flags = eib_def.TA_ObjectFlags{} THEN
         Direction := drv_def.TDirection{drv_def.dirInput};
      ELSIF directionInput * PObject^.Flags = eib_def.TA_ObjectFlags{} THEN
         Direction := drv_def.TDirection{drv_def.dirOutput};
      ELSE
         Direction := drv_def.TDirection{drv_def.dirInput, drv_def.dirOutput};
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

   PUBLIC VIRTUAL PROCEDURE GetChannelDescription( DriverIndex : CARDINAL; OUT Description, Id : StringsO.CString ) : BOOLEAN;
   CONST
      _StatusId            = L'drvStatus';
      _WatchDogId          = L'drvWatchDog';
      _InputQueueLengthId  = L'drvInputQueueLength';
      _OutputQueueLengthId = L'drvOutputQueueLength';
      _WriteQueueLengthId  = L'drvWriteQueueLength';
   VAR
      PObject : srvcore.TPObject;
   BEGIN
      IF DriverIndex = StatusChannel THEN
         Description.FromOA( OAsz( DR()^[ Texts._StatusComment ] ));
         Id.FromOA( _StatusId );
      ELSIF DriverIndex = WatchDogChannel THEN
         Description.FromOA( OAsz( DR()^[ Texts._WatchDogComment ] ));
         Id.FromOA( _WatchDogId );
      ELSIF DriverIndex = InputQueueLengthChannel THEN
         Description.FromOA( OAsz( DR()^[ Texts._InputQueueLengthComment ] ));
         Id.FromOA( _InputQueueLengthId );
      ELSIF DriverIndex = OutputQueueLengthChannel THEN
         Description.FromOA( OAsz( DR()^[ Texts._OutputQueueLengthComment ] ));
         Id.FromOA( _OutputQueueLengthId );
      ELSIF DriverIndex = WriteQueueLengthChannel THEN
         Description.FromOA( OAsz( DR()^[ Texts._WriteQueueLengthComment ] ));
         Id.FromOA( _WriteQueueLengthId );
      ELSIF LogNumber2Object( DriverIndex, PObject ) THEN
         Id := PObject^.Name;
         Description := PObject^.Comment;
      ELSE
         RETURN FALSE;
      END;
      RETURN TRUE;
   END GetChannelDescription;

//--------------------------------------------------------------------------------

   PUBLIC VIRTUAL PROCEDURE QueryErrorCode( ErrorCode : CARDINAL; OUT ErrorText : StringsO.CString ) : BOOLEAN;
   BEGIN
      CASE ErrorCode OF
      | driver.ceDeviceUnplugged :
         ErrorText.FromOA( OAsz( DR()^[ Texts._E_DeviceUnplugged ] ));
      | driver.ceLCONError :
         ErrorText.FromOA( OAsz( DR()^[ Texts._E_LCONError ] ));
      | driver.ceRD_RES_Timeout :
         ErrorText.FromOA( OAsz( DR()^[ Texts._E_RD_RES_Timeout ] ));
      | driver.ceLineBusy :
         ErrorText.FromOA( OAsz( DR()^[ Texts._E_LineBusy ] ));
      | driver.ceTransceiverFault :
         ErrorText.FromOA( OAsz( DR()^[ Texts._E_TransceiverFault ] ));
      | driver.ceOutputQueueOverflow :
         ErrorText.FromOA( OAsz( DR()^[ Texts._E_OutputQueueOverflow ] ));
      | driver.ceReadQueueOverflow :
         ErrorText.FromOA( OAsz( DR()^[ Texts._E_ReadQueueOverflow ] ));
      | driver.ceWriteQueueOverflow :
         ErrorText.FromOA( OAsz( DR()^[ Texts._E_WriteQueueOverflow ] ));
      ELSE
         RETURN FALSE;
      END;
      RETURN TRUE;
   END QueryErrorCode;

//--------------------------------------------------------------------------------

   PUBLIC VIRTUAL PROCEDURE DriverRun();
   BEGIN
      msgqueuethread.global()^.ThreadCall( ADR( SELF ), OP_RUN, OA( -1, NIL ), NIL, TRUE, Sync.FORSAFETY );
   END DriverRun;

//--------------------------------------------------------------------------------

   PUBLIC VIRTUAL PROCEDURE DriverStop();
   BEGIN
      msgqueuethread.global()^.ThreadCall( ADR( SELF ), OP_STOP, OA( -1, NIL ), NIL, TRUE, Sync.FORSAFETY );
   END DriverStop;

//--------------------------------------------------------------------------------

   PUBLIC VIRTUAL PROCEDURE Dispose();
   BEGIN
      msgqueuethread.global()^.ThreadCall( ADR( SELF ), OP_DISPOSE, OA( -1, NIL ), NIL, TRUE, Sync.FORSAFETY );
   END Dispose;

//--------------------------------------------------------------------------------

   PUBLIC VIRTUAL PROCEDURE InputRequestStart();
   BEGIN
   END InputRequestStart;

//--------------------------------------------------------------------------------

   PUBLIC VIRTUAL PROCEDURE InputRequest( DriverIndex : CARDINAL );
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
      ELSIF Result.Counted OR Result.Expired THEN
         // pass down
      ELSIF NOT LogNumber2Object( DriverIndex, PObject ) THEN
         // pass down
      ELSIF PObject^.Reading THEN
         // pass down
      ELSIF eib_def.aofForceRead IN PObject^.GetFlags() THEN
         IF ( PObject^.RecoveryExpiration <> 0 ) AND ( INTEGER( PObject^.RecoveryExpiration - CARDINAL( Time.UptimeMS())) < 0 ) THEN
            // still cannot read, pass away
            RETURN;
         END;
         // start reading itself
         PObject^.ReadRepeatCount := ReadDuringRun.RepeatCount;
         PObject^.GetValue( OUT EV, FALSE, FALSE );
      END;
   END InputRequest;

//--------------------------------------------------------------------------------

   PUBLIC VIRTUAL PROCEDURE InputRequestCompleted();
   BEGIN
   END InputRequestCompleted;

//--------------------------------------------------------------------------------

   PUBLIC VIRTUAL PROCEDURE InputFinalized( DriverIndex : CARDINAL; OUT ErrorCode : CARDINAL ) : BOOLEAN;
   VAR
      PObject : srvcore.TPObject;
   BEGIN
      IF ( DriverIndex = StatusChannel ) OR
         ( DriverIndex = InputQueueLengthChannel ) OR
         ( DriverIndex = OutputQueueLengthChannel ) OR
         ( DriverIndex = WriteQueueLengthChannel ) THEN
         ErrorCode := drv_def.ecSuccess;
      ELSIF Result.Counted OR Result.Expired THEN
         RETURN FALSE;
      ELSIF NOT LogNumber2Object( DriverIndex, PObject ) THEN
         ErrorCode := drv_def.ecUnknownElement;
      ELSIF NOT HWConnected( ErrorCode ) THEN
         PObject^.CancelIO();
      ELSIF PObject^.Reading THEN
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

   PUBLIC VIRTUAL PROCEDURE InputOOBDataQuery( REF EnumerateState : LONGWORD; OUT DriverIndex : CARDINAL ) : BOOLEAN;
   BEGIN
      QueueLock.Lock();
      IF ( CARDINAL( EnumerateState ) >= oobData.Count ) OR Result.Counted OR Result.Expired THEN
         EXCL( RStatus, srvcore.rsProcessingOOB );
         oobData.Dispose();
         QueueLock.Unlock();
         RETURN FALSE;
      ELSIF srvcore.rsProcessingOOB NOT IN RStatus THEN
         INCL( RStatus, srvcore.rsProcessingOOB );
         oobData.Reset();
      END;
      oobData.MoveNext();
      QueueLock.Unlock();

      DriverIndex := srvcore.TPObject( oobData.CurrentData )^.LogNumber();
      EnumerateState := CARDINAL( EnumerateState ) + 1;

      RETURN TRUE;
   END InputOOBDataQuery;

//--------------------------------------------------------------------------------

   PUBLIC VIRTUAL PROCEDURE GetInput( DriverIndex : CARDINAL; InValueLimit : CARDINAL; OUT InValue : iovalue.Value; OUT QoS : CARDINAL; OUT TimeStamp : drv_def.TUTCStamp; OUT ErrorCode : CARDINAL );
   VAR
      c : CARDINAL;
      EV : eib_def.TValue;
      PObject : srvcore.TPObject;
      Status : TStatusChannel;
   BEGIN
      IF DriverIndex = StatusChannel THEN
         QoS := drv_def.qosGood;
         ErrorCode := drv_def.ecSuccess;

         Status := TStatusChannel{};
         IF EIB^.DeviceConnected() THEN
            INCL( Status, schiUSBConnected );
         END;

         QueueLock.Lock();
         IF PromiscuousMode THEN
            IF prData.Count >= InputQueueLength THEN
               INCL( Status, schiInputQueueOverflow );
            END;
         ELSE
            IF oobData.Count >= InputQueueLength THEN
               INCL( Status, schiInputQueueOverflow );
            END;
         END;
         IF srvcore.rsPromiscuousInQueue IN RStatus THEN
            INCL( Status, schiHavePromiscuousData );
         END;
         QueueLock.Unlock();

         IF EIB^.EIBConnected() THEN
            INCL( Status, schiEIBConnected );
         END;
         IF NOT( srvcore.rsInitReadFinished IN RStatus ) THEN
            INCL( Status, schiInitReadPending );
         END;
         IF Result.Counted OR Result.Expired THEN
            EXCL( Status, schiValid );
         ELSE
            INCL( Status, schiValid );
         END;

         InValue.Integer := CARDINAL( Status );

      ELSIF DriverIndex = InputQueueLengthChannel THEN
         QoS := drv_def.qosGood;
         ErrorCode := drv_def.ecSuccess;

         QueueLock.Lock();
         InValue.Integer := oobData.Count;
         QueueLock.Unlock();

      ELSIF DriverIndex = OutputQueueLengthChannel THEN
         QoS := drv_def.qosGood;
         ErrorCode := drv_def.ecSuccess;
         InValue.Integer := EIB^.OutputQueueLength();

      ELSIF DriverIndex = WriteQueueLengthChannel THEN
         QoS := drv_def.qosGood;
         ErrorCode := drv_def.ecSuccess;
         InValue.Integer := EIB^.WriteQueueLength();

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

         PObject^.GetValue( OUT EV, TRUE, FALSE );
         IF srvcore.rsProcessingOOB IN RStatus THEN
            oobData.Current^.ToOA( OUT EV.Data, OUT c ); // iteration depends on client (GetFirst/NextOf), no need for sync
         END;
         EIBValue2IOValue( EV, OUT InValue );

      END;
   END GetInput;

//--------------------------------------------------------------------------------

   PUBLIC VIRTUAL PROCEDURE OutputRequestStart();
   BEGIN
   END OutputRequestStart;

//--------------------------------------------------------------------------------

   PUBLIC VIRTUAL PROCEDURE OutputRequest( DriverIndex : CARDINAL; CONST OutValue : iovalue.Value; QoS : CARDINAL; CONST TimeStamp : drv_def.TUTCStamp );
   VAR
      EV : eib_def.TValue;
      IO : iovalue.Value;
      PObject : srvcore.TPObject;
   BEGIN
      Result.Inc();

      IF DriverIndex = WatchDogChannel THEN
         WatchDogLock.Lock();
         WatchDogLeft := 1000 * OutValue.Integer;
         WatchDogLock.Unlock();

      ELSIF Result.Counted OR Result.Expired THEN
         // do nothing

      ELSIF LogNumber2Object( DriverIndex, PObject ) THEN
         IF PObject^.Type = eib_def.eitDate THEN
            IO.Type := iovalue.vtDate;
            IO := OutValue;
            IOValue2EIBValue( IO, eib_def.eitDate, OUT EV );
         ELSE
            IOValue2EIBValue( OutValue, PObject^.Type, OUT EV );
         END;
         PObject^.SetValue( EV );

      END;
   END OutputRequest;

//--------------------------------------------------------------------------------

   PUBLIC VIRTUAL PROCEDURE OutputRequestCompleted();
   BEGIN
   END OutputRequestCompleted;

//--------------------------------------------------------------------------------

   PUBLIC VIRTUAL PROCEDURE OutputFinalized( DriverIndex : CARDINAL; OUT ErrorCode : CARDINAL ) : BOOLEAN;
   VAR
      PObject : srvcore.TPObject;
   BEGIN
      IF DriverIndex = WatchDogChannel THEN
         ErrorCode := drv_def.ecSuccess;
      ELSIF Result.Counted OR Result.Expired THEN
         RETURN FALSE;
      ELSIF NOT LogNumber2Object( DriverIndex, PObject ) THEN
         ErrorCode := drv_def.ecUnknownElement;
      ELSIF NOT HWConnected( ErrorCode ) THEN
         PObject^.CancelIO();
      ELSIF PObject^.Writing THEN
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

   PUBLIC VIRTUAL PROCEDURE DriverProc( Func, Param1, Param2, Param3, Param4 : CARDINAL );
   BEGIN
   END DriverProc;

//--------------------------------------------------------------------------------

   PUBLIC VIRTUAL PROCEDURE QueryProc( CONST InValue1, InValue2 : iovalue.Value; OutValueLimit : CARDINAL; OUT OutValue : iovalue.Value );
   LABEL
      Error;
   VAR
      Address : eib_def.TAddress;
      CS : StringsO.CString;
      d : PTR;
      EIT : eib_def.TEIBType;
      EV : eib_def.TValue;
      i : CARDINAL;
      IO : iovalue.Value;
      N, V : ARRAY [0..63] OF WCHAR;
      promiscuousData : srvcore.PromiscuousData;
      s : ARRAY [0..15] OF WCHAR;
   BEGIN
      CS := InValue1.String;
      CS.ItemSOA( StringsO.WCHARS{ L' ' }, 0, 0, TRUE, OUT N );

      //=====
      IF EQUALS( N, L'run' ) THEN
         Start();
         
      //=====
      ELSIF EQUALS( N, L'stop' ) THEN
         Stop();

      //=====
      ELSIF NOT PromiscuousMode THEN
         CS.FromOA( L'error: driver procedure requires promiscuous mode' );

      //=====
      ELSIF EQUALS( N, L'event' ) THEN
         CS.ItemSOA( StringsO.WCHARS{ L' ' }, 0, 1, TRUE, OUT N );

         //-----
         IF EQUALS( N, L'count' ) THEN
            QueueLock.Lock();
            CS.FromCARD32( prData.Count, 10 );
            QueueLock.Unlock();

         //-----
         ELSIF EQUALS( N, L'get' ) THEN
            QueueLock.Lock();
            IF prData.Count = 0 THEN
               QueueLock.Unlock();
               CS.Clear();
               GOTO Error;
            END;

            // check licensing           
            IF Result.Counted OR Result.Expired THEN
               prData.Dispose();
               EXCL( RStatus, srvcore.rsPromiscuousInQueue );

               QueueLock.Unlock();
               CS.Clear();
               GOTO Error;
            END;

            prData.DequeueOA( OUT promiscuousData, OUT i, OUT d );
            IF prData.Count = 0 THEN
               EXCL( RStatus, srvcore.rsPromiscuousInQueue );
            END;
            QueueLock.Unlock();

            IF promiscuousData.Status = eib_status.essOK THEN
               promiscuousData.Address.GetGroupAddress3( TRUE, s );
               CS.FromOA( s ); CS.AppendOA( L' ' );
               eib_def.TypeToString( promiscuousData.Value.GetType(), s );
               CS.AppendOA( s ); CS.AppendOA( L' ' );

               IF promiscuousData.Value.GetType() = eib_def.eitDate THEN
                  IO.Type := iovalue.vtFloat;
               END;
               EIBValue2IOValue( promiscuousData.Value, OUT IO );
               CS.Append( IO.String );
            ELSE
               CS.FromOA( L"error " );
               promiscuousData.Address.GetGroupAddress3( TRUE, s );
               CS.AppendOA( s ); CS.AppendOA( L' ' );
               eib_def.TypeToString( promiscuousData.Value.GetType(), s );
               CS.AppendOA( s );
            END;
            
         ELSE
           CS.FromOA( L'error: "event" procedure, unknown command' );
           GOTO Error;
         END;
         
      //=====
      ELSIF EQUALS( N, L'get' ) THEN
         i := CS.ItemSOA( StringsO.WCHARS{ L' ' }, 0, 1, TRUE, OUT N );
         IF N[0] = WCHAR( 0 ) THEN
            CS.FromOA( L'error: "get" procedure, missing group address' );
            GOTO Error;
         END;
         CS.ItemSOA( StringsO.WCHARS{ L' ' }, i, 0, TRUE, OUT s );
         IF s[0] = WCHAR( 0 ) THEN
            CS.FromOA( L'error: "get" procedure, missing value type' );
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
         ELSIF NOT Address.SetGroupAddress3( N ) THEN
            CS.FromOA( L'error: "send" procedure, bad group address (' );
            CS.AppendOA( N );
            CS.AppendOA( L')' );
            GOTO Error;
         ELSIF Result.Expired THEN
            CS.Clear();
            GOTO Error;
         END;

         // initiate read
         prObjects[EIT].InitiateGetValue( Address );

      //=====
      ELSIF EQUALS( N, L'send' ) THEN
         i := CS.ItemSOA( StringsO.WCHARS{ L' ' }, 0, 1, TRUE, OUT N );
         IF N[0] = WCHAR( 0 ) THEN
            CS.FromOA( L'error: "send" procedure, missing group address' );
            GOTO Error;
         END;
         i := CS.ItemSOA( StringsO.WCHARS{ L' ' }, i, 0, TRUE, OUT s );
         IF s[0] = WCHAR( 0 ) THEN
            CS.FromOA( L'error: "send" procedure, missing value type' );
            GOTO Error;
         END;
         CS.ItemSOA( StringsO.WCHARS{ L' ' }, i, 0, TRUE, OUT V );
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
         ELSIF NOT Address.SetGroupAddress3( N ) THEN
            CS.FromOA( L'error: "send" procedure, bad group address (' );
            CS.AppendOA( N );
            CS.AppendOA( L')' );
            GOTO Error;
         ELSIF Result.Expired THEN
            CS.Clear();
            GOTO Error;
         END;

         IF EIT = eib_def.eitDate THEN
            IO.Type := iovalue.vtFloat;
         END;
         IO.FromStringOA( V, FALSE );
         IOValue2EIBValue( IO, EIT, OUT EV );
         prObjects[EIT].InitiateTransmit( Address, EV );

      ELSE
         CS.FromOA( L'error: unknown driver procedure' );
      END;

   Error:
      OutValue.String := CS;
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

   PUBLIC VIRTUAL PROCEDURE Invoke( Operation : CARDINAL; CONST Parameters : ARRAY OF PTR ) : PTR;
   BEGIN
      CASE Operation OF
      //-----
      | OP_RUN :
         SUPER.Start();

         IF WatchDogChannel <> MAX( CARDINAL ) THEN
            WatchDogLock.Lock();
            WatchDogLeft := 10 * WD_TICK;
            WatchDogLock.Unlock();
            StartTimer( TIMER_WATCH_DOG, WD_TICK, TRUE );
         END;

      //-----         
      | OP_STOP :
         StopTimer( TIMER_WATCH_DOG );

         SUPER.Stop();

      //-----         
      | OP_DISPOSE :
         SUPER.Dispose();
         CEIBDriver.FINALLY();

      //-----         
      END;
      RETURN 0;
   END Invoke;

//--------------------------------------------------------------------------------

   PUBLIC VIRTUAL PROCEDURE OnConnect();
   BEGIN
      CallbackProc( CallbackId, drv_def.dcfException, NIL );
   END OnConnect;

//--------------------------------------------------------------------------------

   PUBLIC VIRTUAL PROCEDURE OnDisconnect();
   BEGIN
      CallbackProc( CallbackId, drv_def.dcfInputFinalized, NIL );
      CallbackProc( CallbackId, drv_def.dcfOutputFinalized, NIL );
      CallbackProc( CallbackId, drv_def.dcfException, NIL );
   END OnDisconnect;

//--------------------------------------------------------------------------------

   PUBLIC VIRTUAL PROCEDURE OnInitReadCompleted();
   BEGIN
      CallbackProc( CallbackId, drv_def.dcfException, NIL );
   END OnInitReadCompleted;

//--------------------------------------------------------------------------------

   PUBLIC VIRTUAL PROCEDURE OnRead( PObject : srvcore.TPObject );
   BEGIN
      CallbackProc( CallbackId, drv_def.dcfInputFinalized, NIL );
   END OnRead;

//--------------------------------------------------------------------------------

   PUBLIC VIRTUAL PROCEDURE OnWritten( PObject : srvcore.TPObject );
   BEGIN
      CallbackProc( CallbackId, drv_def.dcfOutputFinalized, NIL );
   END OnWritten;

//--------------------------------------------------------------------------------

   PUBLIC VIRTUAL PROCEDURE OnInputQueueAdd( OOBQueue, PromiscuousQueue : BOOLEAN );
   BEGIN
      IF PromiscuousQueue THEN
         CallbackProc( CallbackId, drv_def.dcfException, NIL );
      ELSIF OOBQueue THEN
         CallbackProc( CallbackId, drv_def.dcfOOBDataAdvise, NIL );
      END;
   END OnInputQueueAdd;

//--------------------------------------------------------------------------------

   PUBLIC VIRTUAL PROCEDURE OnInputQueueOverflow( OOBQueue, PromiscuousQueue : BOOLEAN );
   BEGIN
      CallbackProc( CallbackId, drv_def.dcfException, NIL );
   END OnInputQueueOverflow;

//--------------------------------------------------------------------------------

   INTERNAL VIRTUAL PROCEDURE OnTimer( TimerId : PTR );
   VAR
      stop : BOOLEAN := FALSE;
   BEGIN
      IF TimerId = TIMER_WATCH_DOG THEN

         WatchDogLock.Lock();
         IF WatchDogLeft <= WD_TICK THEN
            WatchDogLeft := 0;
            stop := TRUE;
         ELSE
            DEC( WatchDogLeft, WD_TICK );
         END;
         WatchDogLock.Unlock();
         
         IF stop THEN
            SUPER.Stop();
         END;
         
      ELSE
         SUPER.OnTimer( TimerId );
      END;
   END OnTimer;

//--------------------------------------------------------------------------------

BEGIN
   CallbackId := NIL;
   CallbackProc := NIL;
   ClientName := L"";

   EventSink := ADR( SELF );
   
   StatusChannel := MAX( CARDINAL );
   WatchDogChannel := MAX( CARDINAL );
   InputQueueLengthChannel := MAX( CARDINAL );   
   OutputQueueLengthChannel := MAX( CARDINAL );
   WriteQueueLengthChannel := MAX( CARDINAL );

   WatchDogLeft := MAX( CARDINAL );

   cllvData := ADR( cllv.data );
   cllvLength := cllv.length;
END CEIBDriver;

(*================================================================================*)

CLASS CFactory IMPLEMENTS diface.ICWDriverFactory;
   PUBLIC VIRTUAL READONLY PROPERTY
      DriverName : StringsO.CString;
   PUBLIC VIRTUAL PROCEDURE CreateInstance( OUT Instance : diface.TPCWDriver ) : BOOLEAN;
   PUBLIC VIRTUAL PROCEDURE DeleteInstance( Instance : diface.TPCWDriver );
END CFactory;   

(*--------------------------------------------------------------------------------*)

CLASS IMPLEMENTATION CFactory;

(*--------------------------------------------------------------------------------*)

   PUBLIC VIRTUAL PROPERTY DriverName GET : StringsO.CString;
   VAR
      Name : StringsO.CString;
   BEGIN
      Name.FromOA( OAsz( DR()^[ Texts._DriverName ] ));
      RETURN Name;
   END DriverName;

(*--------------------------------------------------------------------------------*)

   PUBLIC VIRTUAL PROCEDURE CreateInstance( OUT Instance : diface.TPCWDriver ) : BOOLEAN;
   VAR
      Driver : TPEIBDriver;
   BEGIN
      NEW( Driver );
      Instance := Driver;
      RETURN TRUE;
   END CreateInstance;

(*--------------------------------------------------------------------------------*)

   PUBLIC VIRTUAL PROCEDURE DeleteInstance( Instance : diface.TPCWDriver );
   VAR
      Driver : TPEIBDriver := TPEIBDriver( Instance );
   BEGIN
      DISPOSE( Driver );
   END DeleteInstance;

(*--------------------------------------------------------------------------------*)

END CFactory;

(*--------------------------------------------------------------------------------*)

VAR
   Factory : CFactory;

(*--------------------------------------------------------------------------------*)

BEGIN
   dr.LoadRES2( EMITW( %dll ), L"eibnetdrv.Texts" );
   diface.RegisterFactory( ADR( Factory ));
END driver.

(*================================================================================*)
