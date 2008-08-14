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
   TExceptionItemType = ( eitRead, eitWrite, eitPollStatus, eitParam, eitReset );
   TPExceptionItem = POINTER TO ExceptionItem;

CLASS ExceptionItem;
   LOCAL VAR
      Result : Sync.TAsyncResult := Sync.arCompleted;
      Command : DaliBridge.TDaliCommand := DaliBridge.cmdOff;
      Linie : CARDINAL := 0;
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

   PUBLIC VIRTUAL PROCEDURE Initialize( RunMode : CARDINAL; CONST SymbolicName : StringsO.CString; CallbackId : ADDRESS; PCallback : drv_def.TDriverCallbackW );
   BEGIN
      SymbolicName.ToOA( OUT ClientName );
      SELF.CallbackId := CallbackId;
      SELF.CallbackProc := PCallback;
   END Initialize;

//--------------------------------------------------------------------------------

   PUBLIC VIRTUAL PROCEDURE ReadParameters( CONST ParFilePath : StringsO.CString; CONST Log : log.CLogger ) : BOOLEAN;
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

      IF NOT Dali.LoadConfiguration( ClientName, OA( ParFilePath.Length-1, ParFilePath.rawData ), TS, Log ) THEN
         RETURN FALSE;
      END;
   
      RETURN TRUE;
   END ReadParameters;

//--------------------------------------------------------------------------------

   PUBLIC VIRTUAL PROCEDURE QueryErrorCode( ErrorCode : CARDINAL; OUT ErrorText : StringsO.CString ) : BOOLEAN;
   BEGIN
      CASE ErrorCode OF
      | driver.ceLine_Timeout :
         ErrorText.FromOA( OAsz( R()^[ Texts._E_Line_Timeout ] ));
      ELSE
         RETURN FALSE;
      END;
      RETURN TRUE;
   END QueryErrorCode;

//--------------------------------------------------------------------------------

   PUBLIC VIRTUAL PROCEDURE EnumerateChannels( REF EnumerateState : LONGWORD; OUT Type : drv_def.TValueType; OUT Direction : drv_def.TDirection; OUT DriverIndex, Count : CARDINAL; OUT HaveDescription : BOOLEAN ): BOOLEAN;
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
         Type := drv_def.vtLongCard;
         Direction := drv_def.TDirection{ drv_def.dirInput };
         DriverIndex := StatusChannel;

      ELSIF OutputQueueCountChannel <> MAX( CARDINAL ) THEN
         Type := drv_def.vtLongCard;
         Direction := drv_def.TDirection{ drv_def.dirInput };
         DriverIndex := OutputQueueCountChannel;

      ELSE
         RETURN FALSE;
      END; // CASE

      INC( Index );
      EnumerateState := Index;
      RETURN TRUE;
   END EnumerateChannels;

//--------------------------------------------------------------------------------

   PUBLIC VIRTUAL PROCEDURE GetChannelDescription( DriverIndex : CARDINAL; OUT Description, Id : StringsO.CString ) : BOOLEAN;
   CONST
      _StatusId = L'drvStatus';
      _OutputQueueCountId = L'drvOutputQueueCount';
   BEGIN
      IF DriverIndex = StatusChannel THEN
         Description.FromOA( OAsz( R()^[ Texts._StatusComment ] ));
         Id.FromOA( _StatusId );
      ELSIF DriverIndex = OutputQueueCountChannel THEN
         Description.FromOA( OAsz( R()^[ Texts._OutputQueueCountComment ] ));
         Id.FromOA( _OutputQueueCountId );
      ELSE
         RETURN FALSE;
      END;
      RETURN TRUE;
   END GetChannelDescription;

//--------------------------------------------------------------------------------

   PUBLIC VIRTUAL PROCEDURE DriverRun();
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
   END DriverRun;

//--------------------------------------------------------------------------------

   PUBLIC VIRTUAL PROCEDURE DriverStop();
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
   END DriverStop;

//--------------------------------------------------------------------------------

   PUBLIC VIRTUAL PROCEDURE Dispose();
   VAR
      Data : PTR;
      ExceptionItem : TPExceptionItem;
   BEGIN
      DriverStop();
      WHILE Queue.Dequeue( OUT ExceptionItem, OUT Data ) DO
         DISPOSE( ExceptionItem );
      END;
   END Dispose;

//--------------------------------------------------------------------------------

   PUBLIC VIRTUAL PROCEDURE DriverProc( Func, Param1, Param2, Param3, Param4 : CARDINAL );
   BEGIN
   END DriverProc;

//--------------------------------------------------------------------------------

   PUBLIC VIRTUAL PROCEDURE InputRequestStart();
   BEGIN
   END InputRequestStart;

//--------------------------------------------------------------------------------

   PUBLIC VIRTUAL PROCEDURE InputRequest( DriverIndex : CARDINAL );
   BEGIN
      Result.Inc();
   END InputRequest;

//--------------------------------------------------------------------------------

   PUBLIC VIRTUAL PROCEDURE InputRequestCompleted();
   BEGIN
   END InputRequestCompleted;

//--------------------------------------------------------------------------------

   PUBLIC VIRTUAL PROCEDURE InputFinalized( DriverIndex : CARDINAL; OUT ErrorCode : CARDINAL ) : BOOLEAN;
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

   PUBLIC VIRTUAL PROCEDURE InputOOBDataQuery( REF EnumerateState : LONGWORD; OUT DriverIndex : CARDINAL ) : BOOLEAN;
   BEGIN
      RETURN FALSE;
   END InputOOBDataQuery;

//--------------------------------------------------------------------------------

   PUBLIC VIRTUAL PROCEDURE GetInput( DriverIndex : CARDINAL; InValueLimit : CARDINAL; OUT InValue : iovalue.Value; OUT QoS : CARDINAL; OUT TimeStamp : drv_def.TUTCStamp; OUT ErrorCode : CARDINAL );
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

         InValue.Integer := CARDINAL( Status );

      ELSIF DriverIndex = OutputQueueCountChannel THEN
         QoS := drv_def.qosGood;
         ErrorCode := drv_def.ecSuccess;

         InValue.Integer := Dali.OutputQueueCount;
      END;
   END GetInput;

//--------------------------------------------------------------------------------

   PUBLIC VIRTUAL PROCEDURE OutputRequestStart();
   BEGIN
   END OutputRequestStart;

//--------------------------------------------------------------------------------

   PUBLIC VIRTUAL PROCEDURE OutputRequest( DriverIndex : CARDINAL; CONST OutValue : iovalue.Value; QoS : CARDINAL; CONST TimeStamp : drv_def.TUTCStamp );
   BEGIN
      Result.Inc();
   END OutputRequest;

//--------------------------------------------------------------------------------

   PUBLIC VIRTUAL PROCEDURE OutputRequestCompleted();
   BEGIN
   END OutputRequestCompleted;

//--------------------------------------------------------------------------------

   PUBLIC VIRTUAL PROCEDURE OutputFinalized( DriverIndex : CARDINAL; OUT ErrorCode : CARDINAL ) : BOOLEAN;
   BEGIN
      IF Result.Counted OR Result.Expired THEN
         RETURN FALSE;
      END;
      RETURN TRUE;
   END OutputFinalized;

//--------------------------------------------------------------------------------

   PUBLIC VIRTUAL PROCEDURE QueryProc( CONST InValue1, InValue2 : iovalue.Value; OutValueLimit : CARDINAL; OUT OutValue : iovalue.Value );
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
      i, index : CARDINAL;
      Level : CARDINAL;
      Linie : CARDINAL;
      N : ARRAY [0..15] OF WCHAR;
      ReaddressArray : DaliBridge.TAddresses;
      S1, S2, S3 : ARRAY [0..63] OF WCHAR;
      
      //-----
      
      PROCEDURE SplitAddress( GroupFlag, AllowGroup, AllowAll : BOOLEAN; REF S : ARRAY OF WCHAR; OUT Linie : CARDINAL; REF Address : DaliBridge.DaliAddress ) : BOOLEAN; // Linie = 0 is default
      VAR
         i : CARDINAL;
         PA : PWCHAR;
         PL : PWCHAR;
      BEGIN
         i := Strings.IndexOfCharW( S, L".", 0 );
         IF i = -1 THEN
            PL := NIL;
            PA := PWCHAR( ADR( S ));
         ELSE
            PL := PWCHAR( ADR( S ));
            PA := PWCHAR( ADR( S[i+1] ));
            S[i] := 0W;
         END;

         IF PL = NIL THEN
            Linie := 0;
         ELSE
            IF EQUALS( OAsz( PL ), L"all" ) THEN
               c := 7; // broadcast
            ELSIF NOT Strings.ToCARD32W( OAsz( PL ), 10, OUT c ) OR ( c > 3 ) THEN
               CS.FromOA( L'error: bad linie address' );
               RETURN FALSE;
            END;
            Linie := c;
         END;

         IF PA <> NIL THEN
            IF PA^ = L"g" THEN
               IF NOT AllowGroup THEN
                  CS.FromOA( L'error: group address is not allowed for the command' );
                  RETURN FALSE;
               END;
               GroupFlag := TRUE;
               INC( PA, SIZE( WCHAR ));
            END;
            IF EQUALS( OAsz( PA ), L"all" ) THEN
               IF AllowAll THEN
                  Address.Type := DaliBridge.adrAll;
               ELSE
                  CS.FromOA( L'error: all address is not allowed for the command' );
                  RETURN FALSE;
               END;
            ELSIF NOT Strings.ToCARD32W( OAsz( PA ), 10, OUT c ) THEN
               CS.FromOA( L'error: bad device address' );
               RETURN FALSE;
            ELSIF GroupFlag THEN
               IF c > 15 THEN
                  CS.FromOA( L'error: bad group address' );
                  RETURN FALSE;
               END;
               Address.Type := DaliBridge.adrGroup;
               Address.Address := c;
            ELSE // NOT GroupFlag
               IF c > 63 THEN
                  CS.FromOA( L'error: bad device address' );
                  RETURN FALSE;
               END;
               Address.Type := DaliBridge.adrSingle;
               Address.Address := c;
            END;
         END;

         RETURN TRUE;
      END SplitAddress;

      //-----

      PROCEDURE Send( type : TExceptionItemType; Linie : CARDINAL; CONST address : DaliBridge.DaliAddress; command : DaliBridge.TDaliCommand; value : CARDINAL ) : BOOLEAN;
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

         AsyncResult := Dali.Command( Linie, address, command, CARD8( value ), PTR( type ));
         IF ( AsyncResult = Sync.arPending ) OR ( AsyncResult = Sync.arAlreadyPending ) THEN
            RETURN TRUE; // OK
         ELSE
            CS.FromOA( L'error: unable to send command' );
            RETURN FALSE;
         END;
      END Send;
      
      //-----

      PROCEDURE ProgramItem( Linie : CARDINAL; command : DaliBridge.TDaliCommand; LimitTo15Steps : BOOLEAN; REF S3 : ARRAY OF WCHAR ) : BOOLEAN;
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
            IF NOT Send( eitParam, Linie, address, DaliBridge.cmdLoadDTR, c ) THEN
               RETURN FALSE;
            END;
            IF NOT Send( eitParam, Linie, address, command, 0 ) THEN
               RETURN FALSE;
            END;
            i := CS.ItemSOA( StringsO.WCHARS{ L' ' }, i, 0, TRUE, OUT S3 ); Strings.TrimW( REF S3 );
            RETURN TRUE;
         END;
      END ProgramItem;

      //-----

   BEGIN
      CS := InValue1.String;
      i := CS.ItemSOA( StringsO.WCHARS{ L' ' }, 0, 0, TRUE, OUT S1 ); Strings.TrimW( REF S1 );
      i := CS.ItemSOA( StringsO.WCHARS{ L' ' }, i, 0, TRUE, OUT S2 ); Strings.TrimW( REF S2 );
      i := CS.ItemSOA( StringsO.WCHARS{ L' ' }, i, 0, TRUE, OUT S3 ); Strings.TrimW( REF S3 );
      
      IF EQUALS( S1, L'event' ) THEN

         IF EQUALS( S2, L'count' ) THEN
            Lock.Lock();
            c := Queue.Count;
            Lock.Unlock();
            OutValue.Integer := c;

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
               Strings.FromCARD32W( ExceptionItem^.Linie, 10, OUT S1 );
               ExceptionItem^.Address.ToString( OUT S2 );
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
               | eitReset :
                  Dali.Logger.LogSS( dldDebug, logPrefix, L"Event.Dequeue ", L"reset" );
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
                  CS.AppendOA( S1 ); CS.AppendOA( L"." ); CS.AppendOA( S2 ); CS.AppendOA( L" " );
            
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
                  CS.FromOA( "set " );
                  CS.AppendOA( S1 ); CS.AppendOA( L"." ); CS.AppendOA( S2 ); CS.AppendOA( L" " );
                  IF ExceptionItem^.Result = Sync.arTimeout THEN
                     CS.AppendOA( L"timeout" );
                  ELSE
                     CS.AppendOA( L"error" );
                  END;

               | eitParam :
                  CS.FromOA( "param " );
                  CS.AppendOA( S1 ); CS.AppendOA( L"." ); CS.AppendOA( S2 ); CS.AppendOA( L" " );
                  IF ExceptionItem^.Result = Sync.arTimeout THEN
                     CS.AppendOA( L"timeout" );
                  ELSE
                     CS.AppendOA( L"error" );
                  END;

               | eitReset :
                  CS.FromOA( "reset " );
                  CS.AppendOA( S1 ); CS.AppendOA( L"." ); CS.AppendOA( S2 ); CS.AppendOA( L" " );
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
         IF NOT SplitAddress( FALSE, FALSE, FALSE, REF S2, OUT Linie, REF address ) THEN
            GOTO Error;
         END;

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

         IF NOT Send( eitRead, Linie, address, command, 0 ) THEN
            GOTO Error;
         END;
         CS.Clear(); // return value

      ELSIF EQUALS( S1, L'set' ) OR EQUALS( S1, L'dim' ) THEN
         dimFlag := S1[0] = L"d";

         IF NOT SplitAddress( FALSE, TRUE, TRUE, REF S2, OUT Linie, REF address ) THEN
            GOTO Error;
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
      
         IF NOT Send( eitWrite, Linie, address, command, Level ) THEN
            GOTO Error;
         END;
         CS.Clear(); // return value

      ELSIF EQUALS( S1, L'param' )  THEN
         IF NOT SplitAddress( FALSE, FALSE, FALSE, REF S2, OUT Linie, REF address ) THEN
            GOTO Error;
         END;

         // S3 already contains power on level
         IF NOT ProgramItem( Linie, DaliBridge.cmdDTRToPowerOn, FALSE, REF S3 ) THEN
            GOTO Error;
         END;
         IF NOT ProgramItem( Linie, DaliBridge.cmdDTRToFail, FALSE, REF S3 ) THEN
            GOTO Error;
         END;
         IF NOT ProgramItem( Linie, DaliBridge.cmdDTRToMin, FALSE, REF S3 ) THEN
            GOTO Error;
         END;
         IF NOT ProgramItem( Linie, DaliBridge.cmdDTRToMax, FALSE, REF S3 ) THEN
            GOTO Error;
         END;
         IF NOT ProgramItem( Linie, DaliBridge.cmdDTRToFadeRate, TRUE, REF S3 ) THEN
            GOTO Error;
         END;
         IF NOT ProgramItem( Linie, DaliBridge.cmdDTRToFadeTime, TRUE, REF S3 ) THEN
            GOTO Error;
         END;
         CS.Clear(); // return value

      ELSIF EQUALS( S1, L'reset' )  THEN
         IF NOT SplitAddress( FALSE, FALSE, FALSE, REF S2, OUT Linie, REF address ) THEN
            GOTO Error;
         END;

         IF NOT Send( eitReset, Linie, address, DaliBridge.cmdReset, 0 ) THEN
            GOTO Error;
         END;
         CS.Clear(); // return value

      ELSIF EQUALS( S1, L'program_addresses' )  THEN
         IF S2[0] = 0W THEN
            CS.FromOA( L'error: missing linie number' );
            GOTO Error;
         ELSIF NOT Strings.ToCARD32W( S2, 10, OUT Linie ) THEN
            CS.FromOA( L'error: bad linie number' );
            GOTO Error;
         END;

         Dali.StartProgramming( Linie, EQUALS( S3, L"use_verify" ));

      ELSIF EQUALS( S1, L'readdress' )  THEN
         IF S2[0] = 0W THEN
            CS.FromOA( L'error: missing linie number' );
            GOTO Error;
         ELSIF NOT Strings.ToCARD32W( S2, 10, OUT Linie ) THEN
            CS.FromOA( L'error: bad linie number' );
            GOTO Error;
         END;

         ReaddressArray := DaliBridge.addressesNone;
         index := 0;
         i := CS.ItemSOA( StringsO.WCHARS{ L' ' }, 0, 2, TRUE, OUT S3 ); Strings.TrimW( REF S3 );
         LOOP
            IF S3[0] = 0W THEN
               EXIT;
            END;
            IF NOT Strings.ToCARD32W( S3, 10, OUT ReaddressArray[index] ) OR ( ReaddressArray[index] > 63 ) THEN
               CS.FromOA( L'error: bad device address: ' );
               CS.AppendOA( S3 );
               GOTO Error;
            END;
            i := CS.ItemSOA( StringsO.WCHARS{ L' ' }, i, 0, TRUE, OUT S3 ); Strings.TrimW( REF S3 );
            INC( index );
         END; // LOOP
         
         Dali.Readdress( 0, ReaddressArray, TRUE );

      ELSE
         CS.FromOA( L'error: unknown driver procedure' );
      END;

   Error:
      Result.Inc();
      OutValue.String := CS;
      RETURN;

   Success:
      Result.Inc();
      CS.Clear();
      OutValue.String := CS;
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

         Dali.Command( 0, address, DaliBridge.cmdStatus, 0, PTR( eitPollStatus ));
      END; // FOR
   END OnTimeout;

//================================================================================

   LOCAL VIRTUAL PROCEDURE OnCompletion( Result : Sync.TAsyncResult; Command : DaliBridge.TDaliCommand; ClientId : PTR; Linie : CARDINAL; CONST daliAddress : DaliBridge.DaliAddress; Data : CARD8 );
   VAR
      address : CARDINAL;
      exceptionItem : TPExceptionItem;
   BEGIN
      CASE TExceptionItemType( LOPTRLONGWORD( ClientId )) OF
      | eitRead :
         // all reads are reported
      | eitWrite, eitParam, eitReset :
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
      exceptionItem^.Linie := Linie;
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
      PollSink^.TimeoutSink := NIL;
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
      Name.FromOA( OAsz( R()^[ Texts._DriverName ] ));
      RETURN Name;
   END DriverName;

(*--------------------------------------------------------------------------------*)

   PUBLIC VIRTUAL PROCEDURE CreateInstance( OUT Instance : diface.TPCWDriver ) : BOOLEAN;
   VAR
      Driver : TPDriver;
   BEGIN
      NEW( Driver );
      Instance := Driver;
      RETURN TRUE;
   END CreateInstance;

(*--------------------------------------------------------------------------------*)

   PUBLIC VIRTUAL PROCEDURE DeleteInstance( Instance : diface.TPCWDriver );
   VAR
      Driver : TPDriver := TPDriver( Instance );
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
   r.LoadRES2( EMITW( %dll ), L"DaliBridge.Texts" );
   diface.RegisterFactory( ADR( Factory ));
END driver.

(*================================================================================*)
