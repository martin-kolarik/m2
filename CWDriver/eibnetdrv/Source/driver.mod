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
   eib_def,
   eib_user,
   eib_status,
   FIO,
   FIOO,
   INIFile,
   IOO,
   iovalue,
   Log,
   msgqueuethread,
   Resources,
   Strings,
   StringsO,
   Sync,
   TextReader,
   Texts,
   threadpool,
   Time;

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

CLASS IMPLEMENTATION CEIBDriver;

//--------------------------------------------------------------------------------

   PUBLIC PROCEDURE Init( CONST SymbolicName : ARRAY OF WCHAR; CallbackId : ADDRESS; PCallback : drv_def.TDriverCallbackW ) : BOOLEAN;
   BEGIN
      SELF.CallbackId := CallbackId;
      SELF.CallbackProc := PCallback;

      SUPER.Init( TRUE );
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
      knWatchDogChannel = L'watchdog_channel';
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

   PUBLIC PROCEDURE Run();
   BEGIN
      msgqueuethread.global()^.ThreadCall( ADR( SELF ), OP_RUN, OA( -1, NIL ), NIL, TRUE, Sync.FORSAFETY );
   END Run;

//--------------------------------------------------------------------------------

   PUBLIC PROCEDURE Stop();
   BEGIN
      msgqueuethread.global()^.ThreadCall( ADR( SELF ), OP_STOP, OA( -1, NIL ), NIL, TRUE, Sync.FORSAFETY );
   END Stop;

//--------------------------------------------------------------------------------

   PUBLIC PROCEDURE Dispose();
   BEGIN
      msgqueuethread.global()^.ThreadCall( ADR( SELF ), OP_DISPOSE, OA( -1, NIL ), NIL, TRUE, Sync.FORSAFETY );
   END Dispose;

//--------------------------------------------------------------------------------

   PUBLIC PROCEDURE Finally();
   BEGIN
      msgqueuethread.global()^.ThreadCall( ADR( SELF ), OP_FINALLY, OA( -1, NIL ), NIL, TRUE, Sync.FORSAFETY );
   END Finally;

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
            Direction := CARDINAL( drv_def.TDirection{ drv_def.dirInput } );
            HaveDescription := TRUE;
            Type := CARDINAL( drv_def.vtLongCard );
            LOOP
               IF Index > OCount + 3 THEN
                  RETURN FALSE;
               ELSIF ( Index = OCount ) AND ( StatusChannel <> MAX( CARDINAL )) THEN
                  // enumerate status channel
                  DriverIndex := StatusChannel;
                  GOTO Described;
               ELSIF ( Index = OCount + 1 ) AND ( WatchDogChannel <> MAX( CARDINAL )) THEN
                  // enumerate watch dog channel
                  Direction := CARDINAL( drv_def.TDirection{drv_def.dirOutput} );
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
      END;

      PObject := srvcore.TPObject( Objects[ Index ] );
      Type := CARDINAL( EITToCWType( PObject^.Value.GetType() ));

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
      _WatchDogId          = L'drvWatchDog';
      _InputQueueLengthId  = L'drvInputQueueLength';
      _OutputQueueLengthId = L'drvOutputQueueLength';
      _WriteQueueLengthId  = L'drvWriteQueueLength';
   VAR
      PObject : srvcore.TPObject;
   BEGIN
      IF DriverIndex = StatusChannel THEN
         ASSIGN( Description, OAsz( R()^[ Texts._StatusComment ] ));
         ASSIGN( Id, _StatusId );
      ELSIF DriverIndex = WatchDogChannel THEN
         ASSIGN( Description, OAsz( R()^[ Texts._WatchDogComment ] ));
         ASSIGN( Id, _WatchDogId );
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
      QueueLock.Lock();
      IF CARDINAL( EnumerateState ) >= oobData.Count THEN
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

   PUBLIC PROCEDURE GetInput( UFlag : BOOLEAN; DriverIndex : CARDINAL; VAR InValue : drv_def.TValue; VAR QoS : CARDINAL; VAR TimeStamp : drv_def.TUTCStamp; VAR ErrorCode : CARDINAL );
   VAR
      c : CARDINAL;
      EV : eib_def.TValue;
      IO : iovalue.Value;
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

         drv_def.AssignValueCardinal( InValue, UFlag, TRUE, CARDINAL( Status ));

      ELSIF DriverIndex = InputQueueLengthChannel THEN
         QoS := drv_def.qosGood;
         ErrorCode := drv_def.ecSuccess;

         QueueLock.Lock();
         drv_def.AssignValueCardinal( InValue, UFlag, TRUE, CARDINAL( oobData.Count ));
         QueueLock.Unlock();

      ELSIF DriverIndex = OutputQueueLengthChannel THEN
         QoS := drv_def.qosGood;
         ErrorCode := drv_def.ecSuccess;
         drv_def.AssignValueCardinal( InValue, UFlag, TRUE, CARDINAL( EIB^.OutputQueueLength() ));

      ELSIF DriverIndex = WriteQueueLengthChannel THEN
         QoS := drv_def.qosGood;
         ErrorCode := drv_def.ecSuccess;
         drv_def.AssignValueCardinal( InValue, UFlag, TRUE, CARDINAL( EIB^.WriteQueueLength() ));

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
            oobData.Current^.ToOA( OUT EV.Data, OUT c ); // iteration depends on client (GetFirst/NextOf), no need for sync
         END;
         EIBValue2IOValue( EV, OUT IO );
         drv_def.IOValueToCWValue( IO, UFlag, TRUE, REF InValue );

      END;
   END GetInput;

//--------------------------------------------------------------------------------

   PUBLIC PROCEDURE OutputRequestStart();
   BEGIN
   END OutputRequestStart;

//--------------------------------------------------------------------------------

   PUBLIC PROCEDURE OutputRequest( UFlag : BOOLEAN; DriverIndex : CARDINAL; OutValue : drv_def.TValue; QoS : CARDINAL; TimeStamp : drv_def.TUTCStamp );
   VAR
      c : CARDINAL;
      EV : eib_def.TValue;
      IO : iovalue.Value;
      PObject : srvcore.TPObject;
   BEGIN
      Result.Inc();

      IF DriverIndex = WatchDogChannel THEN
         WatchDogLock.Lock();
         WatchDogLeft := 1000 * drv_def.ValueToCardinal( OutValue, UFlag, TRUE );
         WatchDogLock.Unlock();

      ELSIF LogNumber2Object( DriverIndex, PObject ) THEN
         IF PObject^.Value.GetType() = eib_def.eitDate THEN
            IO.Type := iovalue.vtDate;
         END;
         drv_def.CWValueToIOValue( OutValue, UFlag, REF IO );
         IOValue2EIBValue( IO, PObject^.Value.GetType(), OUT EV );
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
      d : PTR;
      EIT : eib_def.TEIBType;
      EV : eib_def.TValue;
      i : CARDINAL;
      IO : iovalue.Value;
      N, V : ARRAY [0..63] OF WCHAR;
      promiscuousData : srvcore.PromiscuousData;
      s : ARRAY [0..15] OF WCHAR;
   BEGIN
      drv_def.DrvValueToCStringW( InValue1, UFlag, OUT CS );
      CS.ItemSOA( StringsO.WCHARS{ L' ' }, 0, 0, TRUE, OUT N );

      //=====
      IF EQUALS( N, L'run' ) THEN
         Run();
         
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
           
            prData.DequeueOA( OUT promiscuousData, OUT i, OUT d );
            IF prData.Count = 0 THEN
               EXCL( RStatus, srvcore.rsPromiscuousInQueue );
            END;
            QueueLock.Unlock();

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
         ELSIF NOT prObjects[EIT].prAddress.SetGroupAddress3( N ) THEN
            CS.FromOA( L'error: "send" procedure, bad group address (' );
            CS.AppendOA( N );
            CS.AppendOA( L')' );
            GOTO Error;
         ELSIF Result.Expired THEN
            CS.Clear();
            GOTO Error;
         END;

         // initiate read
         prObjects[EIT].InitiateGetValue( prObjects[EIT].prAddress );

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
         ELSIF NOT prObjects[EIT].prAddress.SetGroupAddress3( N ) THEN
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
         prObjects[EIT].SetValue( EV );

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

   PUBLIC VIRTUAL PROCEDURE Invoke( Operation : CARDINAL; CONST Parameters : ARRAY OF PTR ) : PTR;
   BEGIN
      CASE Operation OF
      //-----
      | OP_RUN :
         SUPER.Run( TRUE, FALSE );

         IF WatchDogChannel <> MAX( CARDINAL ) THEN
            WatchDogLock.Lock();
            WatchDogLeft := 10 * WD_TICK;
            WatchDogLock.Unlock();
            StartTimer( TIMER_WATCH_DOG, WD_TICK, TRUE );
         END;

      //-----         
      | OP_STOP :
         StopTimer( TIMER_WATCH_DOG );

         SUPER.Stop( TRUE, FALSE );

      //-----         
      | OP_DISPOSE :
         SUPER.Dispose();
      //-----         
      | OP_FINALLY :
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
            SUPER.Stop( TRUE, FALSE );
         END;
         
      ELSE
         SUPER.OnTimer( TimerId );
      END;
   END OnTimer;

//--------------------------------------------------------------------------------

BEGIN
   CallbackId := NIL;
   CallbackProc := NIL;

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