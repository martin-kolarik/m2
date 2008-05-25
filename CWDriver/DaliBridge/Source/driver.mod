IMPLEMENTATION MODULE driver;

(*# call( o_a_copy => off ) *)

FROM Storage IMPORT
   ALLOCATE, DEALLOCATE, Fill;

FROM log IMPORT
  dldTrace, dldDebug;

IMPORT
   cllv,
   FIO,
   FIOO,
   INIFile,
   IOO,
   Log,
   netpool,
   Resources,
   Strings,
   StringsO,
   Sync,
   TextReader,
   Texts;

//================================================================================

CONST
   logPrefix = L"Dali";

//================================================================================

TYPE
   TExceptionItemType = ( eitRead, eitWrite, eitPollStatus, eitParam );
   TPExceptionItem = POINTER TO ExceptionItem;

CLASS ExceptionItem;
   LOCAL VAR
      Result : Sync.TAsyncResult := Sync.arCompleted;
      Command : DaliBridge.TDaliCommand := DaliBridge.cmdOff;
      Address : DaliBridge.DaliAddress;
      Value : CARD8 := 0;
END ExceptionItem;

//--------------------------------------------------------------------------------

CLASS IMPLEMENTATION ExceptionItem;
BEGIN
END ExceptionItem;

//================================================================================

CLASS IMPLEMENTATION CDriver;

//--------------------------------------------------------------------------------

   PUBLIC PROCEDURE Init( CONST SymbolicName : ARRAY OF WCHAR; CallbackId : ADDRESS; PCallback : drv_def.TDriverCallbackW ) : BOOLEAN;
   BEGIN
      ClientName := SymbolicName;
      SELF.CallbackId := CallbackId;
      SELF.CallbackProc := PCallback;

      RETURN TRUE;
   END Init;

//--------------------------------------------------------------------------------

   PUBLIC PROCEDURE ReadParameters( CONST ParFilePath : StringsO.CString; REF Log : log.CLogger ) : BOOLEAN;
   CONST
      snDevice = L'device';
         knStatusChannel = L'status_channel';
         knOutputQueueCountChannel = L'output_queue_count_channel';
         knOutputQueueLength = L'output_queue_length';
      snPolling = L'polling';
         knPollPeriod = L'period';
         knDev = L'dev00';
         knAll = L'all';
   VAR
      c, i, line : CARDINAL;
      defaultPollingCount : CARDINAL;
      fs : FIOO.CFileStream;
      strDev : ARRAY [0..31] OF WCHAR;
      tr : TextReader.CTextReader;
      TS : INIFile.CINIFile;
      b : BOOLEAN;
   BEGIN
      TRY
         fs.FromPath( OA( ParFilePath.Length-1, ParFilePath.rawData ), FIOO.imOpenRead );
      CATCH e : IOO.CIOException DO
         Log.LogFilePos( log.dlcError, ClientName, OA( ParFilePath.Length-1, ParFilePath.rawData ), OAsz( R()^[ Texts._CannotOpenPar ] ), 0, 0 );
         RETURN FALSE;
      END; // try
      tr.Stream := ADR( fs );
      b := TS.Load( tr );
      fs.Close( FALSE );
      IF NOT b THEN
         Log.LogFilePos( log.dlcError, ClientName, OA( ParFilePath.Length-1, ParFilePath.rawData ), OAsz( R()^[ Texts._CannotOpenPar ] ), 0, 0 );
         RETURN FALSE;
      END;

      Dali.Logger.SetUpByRegistry( LIBRARY );
      CASE drv_def.ConfigureLog( TS, REF Dali.Logger, OUT line ) OF
      | drv_def.clrUnknownDebugMode :
         Log.LogFilePos( log.dlcError, ClientName, OA( ParFilePath.Length-1, ParFilePath.rawData ), OAsz( R()^[ Texts._UnknownDebugMode ] ), line, 0 );
      | drv_def.clrUnknownDebugLevel :
         Log.LogFilePos( log.dlcError, ClientName, OA( ParFilePath.Length-1, ParFilePath.rawData ), OAsz( R()^[ Texts._UnknownDebugLevel ] ), line, 0 );
      | drv_def.clrFileDebugMissingFile :
         Log.LogFilePos( log.dlcError, ClientName, OA( ParFilePath.Length-1, ParFilePath.rawData ), OAsz( R()^[ Texts._FileDebugMissingFile ] ), line, 0 );
         RETURN FALSE;
      END;

      StatusChannel := MAX( CARDINAL );
      OutputQueueCountChannel := MAX( CARDINAL );
      IF TS.SetSection( snDevice ) THEN
         IF TS.GetKeyInt( knStatusChannel, OUT line, OUT c ) THEN
            StatusChannel := c;
         END;
         IF TS.GetKeyInt( knOutputQueueCountChannel, OUT line, OUT c ) THEN
            OutputQueueCountChannel := c;
         END;
         IF TS.GetKeyInt( knOutputQueueLength, OUT line, OUT c ) THEN
            Dali.OutputQueueLength := c;
         END;
      END; // IF snDevice
      
      PollPeriod := Sync.FOREVER;
      IF TS.SetSection( snPolling ) THEN
         IF TS.GetKeyInt( knPollPeriod, OUT line, OUT c ) THEN
            IF c < 75 THEN
               Dali.Logger.LogS( log.dldTrace, logPrefix, L"Polling period too short, selecting 75" );
               PollPeriod := 75;
            ELSE
               PollPeriod := c;
            END;
         END;

         defaultPollingCount := -1;
         IF TS.GetKeyInt( knAll, OUT line, OUT c ) AND ( c > 0 ) THEN
            Dali.Logger.LogSC( log.dldTrace, logPrefix, L"Setting polling count for all devices to: ", c );
            defaultPollingCount := c;
         END;

         strDev := knDev;
         FOR i := 0 TO 63 DO
            strDev[3] := WCHAR( ORD( '0' ) + i DIV 10 );
            strDev[4] := WCHAR( ORD( '0' ) + i MOD 10 );
            IF TS.GetKeyInt( strDev, OUT line, OUT c ) AND ( c > 0 ) THEN
               PollInitArray[i] := c;
            ELSE
               PollInitArray[i] := defaultPollingCount;
            END;
         END;
      END;

      IF NOT Dali.LoadConfiguration( ClientName, OA( ParFilePath.Length-1, ParFilePath.rawData ), TS, REF Log ) THEN
         RETURN FALSE;
      END;
   
      RETURN TRUE;
   END ReadParameters;

//--------------------------------------------------------------------------------

   PUBLIC PROCEDURE EnumerateChannels( VAR EnumerateState : LONGWORD; VAR Type : CARDINAL; VAR Direction : CARDINAL; VAR DriverIndex : CARDINAL; VAR Count : CARDINAL; VAR HaveDescription : BOOLEAN ): BOOLEAN;
   VAR
      Index : CARDINAL;
   BEGIN
      IF EnumerateState = LONGWORD( 0 ) THEN // start enumeration
         Index := 0;
      END;
      Count := 1;
      HaveDescription := TRUE;
      
      IF Index > 1 THEN
         RETURN FALSE;

      ELSIF ( Index = 0 ) AND ( StatusChannel <> MAX( CARDINAL )) THEN
         Type := CARDINAL( drv_def.vtLongCard );
         Direction := CARDINAL( drv_def.TDirection{ drv_def.dirInput } );
         DriverIndex := StatusChannel;

      ELSIF OutputQueueCountChannel <> MAX( CARDINAL ) THEN
         Type := CARDINAL( drv_def.vtLongCard );
         Direction := CARDINAL( drv_def.TDirection{ drv_def.dirInput } );
         DriverIndex := OutputQueueCountChannel;

      ELSE
         RETURN FALSE;
      END; // CASE

      INC( Index );
      EnumerateState := Index;
      RETURN TRUE;
   END EnumerateChannels;

//--------------------------------------------------------------------------------

   PUBLIC PROCEDURE GetChannelDescription( DriverIndex : CARDINAL; VAR Description : ARRAY OF WCHAR; VAR Id : ARRAY OF WCHAR ) : BOOLEAN;
   CONST
      _StatusId = L'drvStatus';
      _OutputQueueCountId = L'drvOutputQueueCount';
   BEGIN
      IF DriverIndex = StatusChannel THEN
         ASSIGN( Description, OAsz( R()^[ Texts._StatusComment ] ));
         ASSIGN( Id, _StatusId );
      ELSIF DriverIndex = OutputQueueCountChannel THEN
         ASSIGN( Description, OAsz( R()^[ Texts._OutputQueueCountComment ] ));
         ASSIGN( Id, _OutputQueueCountId );
      ELSE
         RETURN FALSE;
      END;
      RETURN TRUE;
   END GetChannelDescription;

//--------------------------------------------------------------------------------

   PUBLIC PROCEDURE Run();
   VAR
      i : CARDINAL;
      s : FIO.PathStrW;
   BEGIN
      IF schiRunning IN RStatus THEN
         RETURN;
      END;
      INCL( RStatus, schiRunning );
      
      Dali.Logger.LogS( log.dldError, logPrefix, L"RUN" );

      Result.Reset( lec.bhBestCase );
      FIO.GetModuleDirW( EMITW( %dll ), OUT s );
      lec.QueryData( s, L"", ADR( cllv.data ), cllv.length, REF Result );

      Dali.Run();

      IF ( PollTimer = NIL ) AND ( PollPeriod <> Sync.FOREVER ) THEN
         FOR i := 0 TO HIGH( PollInitArray ) DO
            PollCountArray[i] := PollInitArray[i];
         END;
         threadpool.pool()^.WaitTimeout( PollSink, 0, PollPeriod, FALSE, TRUE, OUT PollTimer );
      ELSIF ( PollTimer <> NIL ) AND ( PollPeriod = Sync.FOREVER ) THEN
         threadpool.pool()^.Abort( REF PollTimer );
      END;
   END Run;

//--------------------------------------------------------------------------------

   PUBLIC PROCEDURE Stop();
   BEGIN
      IF schiRunning NOT IN RStatus THEN
         RETURN;
      END;
      EXCL( RStatus, schiRunning );

      Dali.Logger.LogS( log.dldError, logPrefix, L"STOP" );

      IF PollTimer <> NIL THEN
         threadpool.pool()^.Abort( REF PollTimer );
      END;

      Dali.Stop();
   END Stop;

//--------------------------------------------------------------------------------

   PUBLIC PROCEDURE Dispose();
   VAR
      Data : PTR;
      ExceptionItem : TPExceptionItem;
   BEGIN
      Stop();
      WHILE Queue.Dequeue( OUT ExceptionItem, OUT Data ) DO
         DISPOSE( ExceptionItem );
      END;
   END Dispose;

//--------------------------------------------------------------------------------

   PUBLIC PROCEDURE InputRequestStart();
   BEGIN
   END InputRequestStart;

//--------------------------------------------------------------------------------

   PUBLIC PROCEDURE InputRequest( DriverIndex : CARDINAL );
   BEGIN
      Result.Inc();
   END InputRequest;

//--------------------------------------------------------------------------------

   PUBLIC PROCEDURE InputRequestCompleted();
   BEGIN
   END InputRequestCompleted;

//--------------------------------------------------------------------------------

   PUBLIC PROCEDURE InputFinalized( DriverIndex : CARDINAL; VAR ErrorCode : CARDINAL ) : BOOLEAN;
   BEGIN
      IF DriverIndex = StatusChannel THEN
         ErrorCode := drv_def.ecSuccess;
      ELSIF DriverIndex = OutputQueueCountChannel THEN
         ErrorCode := drv_def.ecSuccess;
      ELSIF Result.Expired OR Result.Counted THEN
         RETURN FALSE;
      END;
      RETURN TRUE;
   END InputFinalized;

//--------------------------------------------------------------------------------

   PUBLIC PROCEDURE InputOOBDataQuery( VAR EnumerateState : LONGWORD; VAR DriverIndex : CARDINAL ) : BOOLEAN;
   BEGIN
      RETURN TRUE;
   END InputOOBDataQuery;

//--------------------------------------------------------------------------------

   PUBLIC PROCEDURE GetInput( UFlag : BOOLEAN; DriverIndex : CARDINAL; VAR InValue : drv_def.TValue; VAR QoS : CARDINAL; VAR TimeStamp : drv_def.TUTCStamp; VAR ErrorCode : CARDINAL );
   VAR
      Status : TStatusChannel := TStatusChannel{};
   BEGIN
      IF DriverIndex = StatusChannel THEN
         QoS := drv_def.qosGood;
         ErrorCode := drv_def.ecSuccess;

         Status := RStatus * schUser;
         IF Result.Counted OR Result.Expired THEN
            EXCL( Status, schiValid );
         ELSE
            INCL( Status, schiValid );
         END;

         drv_def.AssignValueCardinal( InValue, UFlag, TRUE, CARDINAL( Status ));

      ELSIF DriverIndex = OutputQueueCountChannel THEN
         QoS := drv_def.qosGood;
         ErrorCode := drv_def.ecSuccess;

         drv_def.AssignValueCardinal( InValue, UFlag, TRUE, CARDINAL( Dali.OutputQueueCount ));
      END;
   END GetInput;

//--------------------------------------------------------------------------------

   PUBLIC PROCEDURE OutputRequestStart();
   BEGIN
   END OutputRequestStart;

//--------------------------------------------------------------------------------

   PUBLIC PROCEDURE OutputRequest( UFlag : BOOLEAN; DriverIndex : CARDINAL; OutValue : drv_def.TValue; QoS : CARDINAL; TimeStamp : drv_def.TUTCStamp );
   BEGIN
      Result.Inc();
   END OutputRequest;

//--------------------------------------------------------------------------------

   PUBLIC PROCEDURE OutputRequestCompleted();
   BEGIN
   END OutputRequestCompleted;

//--------------------------------------------------------------------------------

   PUBLIC PROCEDURE OutputFinalized( DriverIndex : CARDINAL; VAR ErrorCode : CARDINAL ) : BOOLEAN;
   BEGIN
      IF Result.Counted OR Result.Expired THEN
         RETURN FALSE;
      END;
      RETURN TRUE;
   END OutputFinalized;

//--------------------------------------------------------------------------------

   PUBLIC PROCEDURE QueryProc( UFlag : BOOLEAN; InValue1, InValue2 : drv_def.TValue; VAR OutValue : drv_def.TValue );
   LABEL
      Error, Success;
   VAR
      address : DaliBridge.DaliAddress;
      c : CARDINAL;
      command : DaliBridge.TDaliCommand;
      CS : StringsO.CString;
      data : PTR;
      dimFlag : BOOLEAN;
      ExceptionItem : TPExceptionItem;
      ExceptionType : TExceptionItemType;
      haveEvent : BOOLEAN;
      i : CARDINAL;
      Level : CARDINAL;
      N : ARRAY [0..15] OF WCHAR;
      S1, S2, S3 : ARRAY [0..63] OF WCHAR;
      
      //-----

      PROCEDURE Send( type : TExceptionItemType; CONST address : DaliBridge.DaliAddress; command : DaliBridge.TDaliCommand; value : CARDINAL ) : BOOLEAN;
      VAR
         AsyncResult : Sync.TAsyncResult;
      BEGIN
         IF Result.Counted THEN
            CS.Clear();
            RETURN FALSE;
         ELSIF Result.Expired THEN
            CS.Clear();
            RETURN FALSE;
         END;

         AsyncResult := Dali.Command( address, command, CARD8( value ), PTR( type ));
         IF ( AsyncResult = Sync.arPending ) OR ( AsyncResult = Sync.arAlreadyPending ) THEN
            RETURN TRUE; // OK
         ELSE
            CS.FromOA( L'error: unable to send command' );
            RETURN FALSE;
         END;
      END Send;
      
      //-----

      PROCEDURE ProgramItem( command : DaliBridge.TDaliCommand; LimitTo15Steps : BOOLEAN; REF S3 : ARRAY OF WCHAR ) : BOOLEAN;
      VAR
         c : CARDINAL;
      BEGIN
         IF S3[0] = 0W THEN
            RETURN TRUE;
         ELSIF NOT Strings.ToCARD32W( S3, 10, OUT c ) THEN
            IF LimitTo15Steps THEN
               CS.FromOA( L'error: bad fade time/fade rate level' );
            ELSE
               CS.FromOA( L'error: bad light level' );
            END;
            RETURN FALSE;
         ELSIF LimitTo15Steps AND ( c > 15 ) THEN
            CS.FromOA( L'error: fade time/fade rate level too big' );
            RETURN FALSE;
         ELSIF NOT LimitTo15Steps AND ( c > 255 ) THEN
            CS.FromOA( L'error: light level too big' );
            RETURN FALSE;
         ELSE
            IF NOT Send( eitParam, address, DaliBridge.cmdLoadDTR, c ) THEN
               RETURN FALSE;
            END;
            IF NOT Send( eitParam, address, command, 0 ) THEN
               RETURN FALSE;
            END;
            i := CS.ItemSOA( StringsO.WCHARS{ L' ' }, i, 0, TRUE, OUT S3 ); Strings.TrimW( REF S3 );
            RETURN TRUE;
         END;
      END ProgramItem;

      //-----

   BEGIN
      drv_def.DrvValueToCStringW( InValue1, UFlag, OUT CS );
      i := CS.ItemSOA( StringsO.WCHARS{ L' ' }, 0, 0, TRUE, OUT S1 ); Strings.TrimW( REF S1 );
      i := CS.ItemSOA( StringsO.WCHARS{ L' ' }, i, 0, TRUE, OUT S2 ); Strings.TrimW( REF S2 );
      i := CS.ItemSOA( StringsO.WCHARS{ L' ' }, i, 0, TRUE, OUT S3 ); Strings.TrimW( REF S3 );
      
      IF EQUALS( S1, L'event' ) THEN

         IF EQUALS( S2, L'count' ) THEN
            Lock.Lock();
            c := Queue.Count;
            Lock.Unlock();
            drv_def.AssignValueCardinal( REF OutValue, UFlag, TRUE, c );

            Dali.Logger.LogSC( dldDebug, logPrefix, L"Event.Count ", c );
            
         ELSIF EQUALS( S2, L'get' ) THEN
            IF Result.Counted OR Result.Expired THEN
               Dali.Logger.LogS( dldDebug, logPrefix, L"Event.Get clear buffer" );
               Dali.Logger.LogS( dldDebug, logPrefix, L"RS- rsEventPending" );

               Lock.Lock();
               Queue.Dispose();
               EXCL( RStatus, schiEventsPending );
               Lock.Unlock();
               
               GOTO Success;
            END;
         
            Lock.Lock();
            IF Queue.Dequeue( OUT ExceptionItem, OUT data ) THEN
               haveEvent := TRUE;
            ELSE
               haveEvent := FALSE;
               Dali.Logger.LogS( dldDebug, logPrefix, L"RS- rsEventPending" );

               EXCL( RStatus, schiEventsPending );
            END;
            Lock.Unlock();

            IF haveEvent THEN
               ExceptionItem^.Address.ToString( OUT N );
               ExceptionType := TExceptionItemType( LOPTRLONGWORD( data ));

               CASE ExceptionType OF
               | eitRead :
                  Dali.Logger.LogSS( dldDebug, logPrefix, L"Event.Dequeue ", L"read" );
               | eitPollStatus :
                  Dali.Logger.LogSS( dldDebug, logPrefix, L"Event.Dequeue ", L"poll status" );
               | eitWrite :
                  Dali.Logger.LogSS( dldDebug, logPrefix, L"Event.Dequeue ", L"write" );
               | eitParam :
                  Dali.Logger.LogSS( dldDebug, logPrefix, L"Event.Dequeue ", L"param" );
               END; // CASE ExceptionType

               CASE ExceptionType OF
               | eitRead, eitPollStatus :
                  CASE ExceptionItem^.Command OF
                  | DaliBridge.cmdStatus :
                     CS.FromOA( L"status " );  
                  | DaliBridge.cmdWorking :
                     CS.FromOA( L"present " );
                  | DaliBridge.cmdDeviceType :
                     CS.FromOA( L"type " );
                  | DaliBridge.cmdVersion :
                     CS.FromOA( L"version " );
                  | DaliBridge.cmdCurrentLevel :
                     CS.FromOA( L"level " );
                  ELSE
                     CS.FromOA( L"value " );
                  END;
                  CS.AppendOA( N );
                  CS.AppendOA( L" " );
            
                  IF ExceptionItem^.Result = Sync.arCompleted THEN

                     IF ExceptionItem^.Command = DaliBridge.cmdStatus THEN
                        IF 040H AND ExceptionItem^.Value <> 0 THEN
                           CS.AppendOA( L"noaddress " );
                        END;
                        IF 004H AND ExceptionItem^.Value <> 0 THEN
                           CS.AppendOA( L"on " );
                        ELSE
                           CS.AppendOA( L"off " );
                        END;
                        IF 002H AND ExceptionItem^.Value <> 0 THEN
                           CS.AppendOA( L"lamp_failure " );
                        END;
                        IF 080H AND ExceptionItem^.Value <> 0 THEN
                           CS.AppendOA( L"power_failure " );
                        END;
                        IF 008H AND ExceptionItem^.Value <> 0 THEN
                           CS.AppendOA( L"limit_error " );
                        END;
                        IF 020H AND ExceptionItem^.Value <> 0 THEN
                           CS.AppendOA( L"init_state " );
                        END;
                        IF 010H AND ExceptionItem^.Value <> 0 THEN
                           CS.AppendOA( L"fading" );
                        END;

                     ELSE
                        Strings.FromCARD32W( CARD32( ExceptionItem^.Value ), 10, OUT N );
                        CS.AppendOA( N );
                     END;

                  ELSIF ExceptionItem^.Result = Sync.arTimeout THEN
                     CS.AppendOA( L"timeout" );
                  ELSE
                     CS.AppendOA( L"error" );
                  END;
                  
               | eitWrite :
                  CS.FromOA( "set " ); CS.AppendOA( N ); CS.AppendOA( L" " ); 
                  IF ExceptionItem^.Result = Sync.arTimeout THEN
                     CS.AppendOA( L"timeout" );
                  ELSE
                     CS.AppendOA( L"error" );
                  END;

               | eitParam :
                  CS.FromOA( "param " ); CS.AppendOA( N ); CS.AppendOA( L" " ); 
                  IF ExceptionItem^.Result = Sync.arTimeout THEN
                     CS.AppendOA( L"timeout" );
                  ELSE
                     CS.AppendOA( L"error" );
                  END;

               END; // CASE

               DISPOSE( ExceptionItem );
            ELSE
               CS.Clear();
            END;

         ELSE
            CS.FromOA( L'error: unknown driver procedure' );
         END;

      ELSIF EQUALS( S1, L'get' ) THEN
         IF NOT Strings.ToCARD32W( S2, 10, OUT c ) OR ( c > 63 ) THEN
            CS.FromOA( L'error: bad device address' );
            GOTO Error;
         END;
         address.Type := DaliBridge.adrSingle;
         address.Address := c;

         IF EQUALS( S3, L'status' ) THEN
            command := DaliBridge.cmdStatus;
         ELSIF EQUALS( S3, L'present' ) THEN
            command := DaliBridge.cmdWorking;
         ELSIF EQUALS( S3, L'type' ) THEN
            command := DaliBridge.cmdDeviceType;
         ELSIF EQUALS( S3, L'version' ) THEN
            command := DaliBridge.cmdVersion;
         ELSIF EQUALS( S3, L'level' ) THEN
            command := DaliBridge.cmdCurrentLevel;
         ELSE
            CS.FromOA( L'error: bad get command parameter' );
            GOTO Error;
         END;

         IF NOT Send( eitRead, address, command, 0 ) THEN
            GOTO Error;
         END;
         CS.Clear(); // return value

      ELSIF EQUALS( S1, L'set' ) OR EQUALS( S1, L'dim' ) THEN
         dimFlag := S1[0] = L"d";

         IF EQUALS( S2, L'all' ) THEN
            address.Type := DaliBridge.adrAll;
         ELSIF S2[0] = L"g" THEN
            Strings.RemoveW( REF S2, 0, 1 );
            IF NOT Strings.ToCARD32W( S2, 10, OUT c ) OR ( c > 15 ) THEN
               CS.FromOA( L'error: bad group address' );
               GOTO Error;
            END;
            address.Type := DaliBridge.adrGroup;
            address.Address := c;
         ELSE
            IF NOT Strings.ToCARD32W( S2, 10, OUT c ) OR ( c > 63 ) THEN
               CS.FromOA( L'error: bad device address' );
               GOTO Error;
            END;
            address.Type := DaliBridge.adrSingle;
            address.Address := c;
         END;

         IF dimFlag THEN
            IF EQUALS( S3, L"up" ) THEN
               command := DaliBridge.cmdDimUp;
            ELSIF EQUALS( S3, L"down" ) THEN
               command := DaliBridge.cmdDimDown;
            ELSIF EQUALS( S3, L"step_up" ) THEN
               command := DaliBridge.cmdStepUp;
            ELSIF EQUALS( S3, L"step_down" ) THEN
               command := DaliBridge.cmdStepDown;
            ELSIF EQUALS( S3, L"step_up_on" ) THEN
               command := DaliBridge.cmdStepUpOn;
            ELSIF EQUALS( S3, L"step_down_off" ) THEN
               command := DaliBridge.cmdStepDownOff;
            ELSE
               CS.FromOA( L'error: bad dim command parameter' );
               GOTO Error;
            END;
         ELSE         
            IF EQUALS( S3, L"on" ) THEN
               command := DaliBridge.cmdStepUpOn;
            ELSIF EQUALS( S3, L"off" ) THEN
               command := DaliBridge.cmdOff;
            ELSIF EQUALS( S3, L"min" ) THEN
               command := DaliBridge.cmdMin;
            ELSIF EQUALS( S3, L"max" ) THEN
               command := DaliBridge.cmdMax;
            ELSE
               IF Strings.ToCARD32W( S3, 10, OUT Level ) AND ( Level < 256 ) THEN
                  command := DaliBridge.cmdDirect;
               ELSE
                  CS.FromOA( L'error: bad set command parameter' );
                  GOTO Error;
               END;
            END;
         END;
      
         IF NOT Send( eitWrite, address, command, Level ) THEN
            GOTO Error;
         END;
         CS.Clear(); // return value

      ELSIF EQUALS( S1, L'param' )  THEN
         IF NOT Strings.ToCARD32W( S2, 10, OUT c ) OR ( c > 63 ) THEN
            CS.FromOA( L'error: bad device address' );
            GOTO Error;
         END;
         address.Type := DaliBridge.adrSingle;
         address.Address := c;

         // S3 already contains power on level
         IF NOT ProgramItem( DaliBridge.cmdDTRToPowerOn, FALSE, REF S3 ) THEN
            GOTO Error;
         END;
         IF NOT ProgramItem( DaliBridge.cmdDTRToFail, FALSE, REF S3 ) THEN
            GOTO Error;
         END;
         IF NOT ProgramItem( DaliBridge.cmdDTRToMin, FALSE, REF S3 ) THEN
            GOTO Error;
         END;
         IF NOT ProgramItem( DaliBridge.cmdDTRToMax, FALSE, REF S3 ) THEN
            GOTO Error;
         END;
         IF NOT ProgramItem( DaliBridge.cmdDTRToFadeRate, TRUE, REF S3 ) THEN
            GOTO Error;
         END;
         IF NOT ProgramItem( DaliBridge.cmdDTRToFadeTime, TRUE, REF S3 ) THEN
            GOTO Error;
         END;
         CS.Clear(); // return value

      ELSIF EQUALS( S1, L'reset' )  THEN
         IF NOT Strings.ToCARD32W( S2, 10, OUT c ) OR ( c > 63 ) THEN
            CS.FromOA( L'error: bad device address' );
            GOTO Error;
         END;
         address.Type := DaliBridge.adrSingle;
         address.Address := c;

         IF NOT Send( eitWrite, address, DaliBridge.cmdReset, 0 ) THEN
            GOTO Error;
         END;
         CS.Clear(); // return value

      ELSE
         CS.FromOA( L'error: unknown driver procedure' );
      END;

   Error:
      Result.Inc();
      drv_def.AssignDrvValueCStringW( REF OutValue, UFlag, FALSE, CS );
      RETURN;

   Success:
      Result.Inc();
      drv_def.AssignDrvValueStringW( REF OutValue, UFlag, FALSE, L'' );
   END QueryProc;

//================================================================================

   LOCAL VIRTUAL PROCEDURE OnTimeout( Result : Sync.TAsyncResult; PoolHandle : threadpool.TPoolHandle; UserId : PTR );
   VAR
      address : DaliBridge.DaliAddress;
      i : CARDINAL;
   BEGIN
      FOR i := 0 TO HIGH( PollCountArray ) DO
         IF PollCountArray[i] = -1 THEN // not polled
            CONTINUE;
         ELSIF PollCountArray[i] = 1 THEN // elapsed
            PollCountArray[i] := PollInitArray[i];
         ELSE
            DEC( PollCountArray[i] );
            CONTINUE;
         END;
         
         // now process elapsed item
         address.Type := DaliBridge.adrSingle;
         address.Address := i;

         Dali.Logger.LogSC( dldDebug, logPrefix, L"Poll status request for: ", i );

         Dali.Command( address, DaliBridge.cmdStatus, 0, PTR( eitPollStatus ));
      END; // FOR
   END OnTimeout;

//================================================================================

   LOCAL VIRTUAL PROCEDURE OnCompletion( Result : Sync.TAsyncResult; Command : DaliBridge.TDaliCommand; ClientId : PTR; CONST daliAddress : DaliBridge.DaliAddress; Data : CARD8 );
   VAR
      address : CARDINAL;
      exceptionItem : TPExceptionItem;
   BEGIN
      CASE TExceptionItemType( LOPTRLONGWORD( ClientId )) OF
      | eitRead :
         // all reads are reported
      | eitWrite, eitParam :
         IF Result = Sync.arCompleted THEN // successfull set/program is not reported
            RETURN;
         END;
      | eitPollStatus :
         IF Result <> Sync.arCompleted THEN // unsuccessfull status get is not reported
            RETURN;
         END;
         address := daliAddress.Address;
         IF StatusArray[ address ] = Data THEN // unchanged status is not reported
            RETURN;
         ELSE
            StatusArray[ address ] := Data;
         END;
      END; // CASE
      
      NEW( exceptionItem );
      exceptionItem^.Result := Result;
      exceptionItem^.Command := Command;
      exceptionItem^.Address := daliAddress;
      exceptionItem^.Value := Data;
      
      Lock.Lock();
      Queue.Enqueue( exceptionItem, ClientId );

      IF schiEventsPending NOT IN RStatus THEN
         Dali.Logger.LogS( dldDebug, logPrefix, L"RS+ rsEventPending" );

         INCL( RStatus, schiEventsPending );
      END;
      Lock.Unlock();
      
      IF CallbackProc <> NIL THEN
         CallbackProc( CallbackId, drv_def.dcfException, NIL );
      END;
   END OnCompletion;

//================================================================================

BEGIN
   RStatus := TStatusChannel{};
   ClientName := L"";
   CallbackId := NIL;
   CallbackProc := NIL;

   StatusChannel := MAX( CARDINAL );
   OutputQueueCountChannel := MAX( CARDINAL );
   Fill( ADR( StatusArray ), SIZE( StatusArray ), 0FFH );
   PollTimer := NIL;
   PollPeriod := Sync.FOREVER;
   PollCountArray[0] := -1;
   PollInitArray[0] := -1;

   cllvData := ADR( cllv.data );
   cllvLength := cllv.length;
   
   NEW( PollSink );
   PollSink^.TimeoutSink := ADR( SELF );

   Dali.Init( TRUE );
   Dali.EventSink := ADR( SELF );
FINALLY
   IF PollSink <> NIL THEN
      PollSink^.Release();
      PollSink := NIL;
   END;
   Dali.Dispose();
END CDriver;

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
   r.LoadRES2( EMITW( %dll ), L"DaliBridge.Texts" );
END __I;

//================================================================================

END driver.