IMPLEMENTATION MODULE driver;

(*# call( o_a_copy => off ) *)

FROM Storage IMPORT
   ALLOCATE, DEALLOCATE;

FROM log IMPORT
  dldTrace, dldDebug;

IMPORT
   cllv,
   cphcommon,
   FIO,
   FIOO,
   INIFile,
   IOO,
   lists,
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
   logName = L"Dali";
   logPrefix = L"DRV";

//================================================================================

TYPE
   TExceptionItemType = ( eitEvent, eitRead, eitWrite, eitPollStatus, eitParam, eitReset, eitProgram, eitAddressFound, eitResetInterface );
   TPExceptionItem = POINTER TO ExceptionItem;

CLASS ExceptionItem;
   LOCAL VAR
      Result : Sync.TAsyncResult := Sync.arCompleted;
      Command : DaliBridge.TDaliCommand := DaliBridge.cmdOff;
      Name : StringsO.CString;
      Linie : DaliBridge.TDaliLinie := DaliBridge.l1;
      Address : DaliBridge.DaliAddress;
      LongAddress : CARDINAL := 0;
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
         knSendDelay = L'send_delay';
   VAR
      c, line : CARDINAL;
      fs : FIOO.CFileStream;
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

      Logger.SetUpByRegistry( LIBRARY );
      CASE drv_def.ConfigureLog( TS, REF Logger, OUT line ) OF
      | drv_def.clrUnknownDebugMode :
         Log.LogFilePos( log.dlcError, ClientName, OA( ParFilePath.Length-1, ParFilePath.rawData ), OAsz( R()^[ Texts._UnknownDebugMode ] ), line, 0 );
         RETURN FALSE;
      | drv_def.clrUnknownDebugLevel :
         Log.LogFilePos( log.dlcError, ClientName, OA( ParFilePath.Length-1, ParFilePath.rawData ), OAsz( R()^[ Texts._UnknownDebugLevel ] ), line, 0 );
         RETURN FALSE;
      | drv_def.clrFileDebugMissingFile :
         Log.LogFilePos( log.dlcError, ClientName, OA( ParFilePath.Length-1, ParFilePath.rawData ), OAsz( R()^[ Texts._FileDebugMissingFile ] ), line, 0 );
         RETURN FALSE;
      END;

      StatusChannel := MAX( CARDINAL );
      IF TS.SetSection( snDevice ) THEN
         IF TS.GetKeyInt( knStatusChannel, OUT line, OUT c ) THEN
            StatusChannel := c;
         END;
         IF TS.GetKeyInt( knOutputQueueCountChannel, OUT line, OUT c ) THEN
            OutputQueueCountChannel := c;
         END;
         IF TS.GetKeyInt( knOutputQueueLength, OUT line, OUT c ) THEN
            OutputQueueLength := c;
         END;
         IF TS.GetKeyInt( knSendDelay, OUT line, OUT c ) THEN
            SendDelay := c;
         END;
      END; // IF snDevice
      
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
      Index : CARDINAL := EnumerateState;
   BEGIN
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
      s : FIO.PathStrW;
   BEGIN
      IF schiRunning IN RStatus THEN
         RETURN;
      END;
      INCL( RStatus, schiRunning );
      
      Logger.LogS( log.dldError, logPrefix, L"RUN" );

      Result.Reset( lec.bhBestCase );
      FIO.GetModuleDirW( EMITW( %dll ), OUT s );
      lec.QueryData( s, L"", ADR( cllv.data ), cllv.length, REF Result );

      Dali.Run();
   END DriverRun;

//--------------------------------------------------------------------------------

   PUBLIC VIRTUAL PROCEDURE DriverStop();
   BEGIN
      IF schiRunning NOT IN RStatus THEN
         RETURN;
      END;
      EXCL( RStatus, schiRunning );

      Logger.LogS( log.dldError, logPrefix, L"STOP" );

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
         IF Dali.ProgrammingInProgress THEN
            INCL( Status, schiProgramming );
         ELSE
            EXCL( Status, schiProgramming );
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
      AddressArray : DaliBridge.TAddresses;
      arResult : Sync.TAsyncResult;
      c : CARDINAL;
      ch : WCHAR;
      command : DaliBridge.TDaliCommand;
      CS, cs : StringsO.CString;
      data : PTR;
      daliDevice : PTR;
      dimFlag : BOOLEAN;
      ExceptionItem : TPExceptionItem;
      ExceptionType : TExceptionItemType;
      filedata : ARRAY [0..63] OF BYTE;
      FileToSend : lists.TPBufferList := NIL;
      fs : FIOO.CFileStream;
      haveEvent : BOOLEAN;
      haveSend : BOOLEAN;
      i, j, index : CARDINAL;
      Level : CARDINAL;
      Linie : DaliBridge.TDaliLinie;
      N : ARRAY [0..15] OF WCHAR;
      S1, S2, S3, S4 : ARRAY [0..63] OF WCHAR;
      tr : TextReader.CTextReader;
      
      //-----
      
      PROCEDURE SplitAddress( GroupFlag, AllowGroup, AllowAll, PreferLinie : BOOLEAN; REF S : ARRAY OF WCHAR; OUT DaliDevice : PTR; OUT Linie : DaliBridge.TDaliLinie; REF Address : DaliBridge.DaliAddress ) : BOOLEAN; // Linie = 0 is default
      VAR
         i, j : CARDINAL;
         PN : PWCHAR;
         PA : PWCHAR;
         PL : PWCHAR;
      BEGIN
         i := Strings.IndexOfCharW( S, L".", 0 );
         IF i = -1 THEN
            CS.FromOA( L'error: missing device name' );
            RETURN FALSE;
         END;

         PN := ADR( S );
         j := Strings.IndexOfCharW( S, L".", i+1 );
         S[i] := 0W;

         IF j = -1 THEN
            IF PreferLinie THEN
               PA := NIL;
               PL := PWCHAR( ADR( S[i+1] ));
            ELSE
               PL := NIL;
               PA := PWCHAR( ADR( S[i+1] ));
            END;
         ELSE
            PL := PWCHAR( ADR( S[i+1] ));
            PA := PWCHAR( ADR( S[j+1] ));
            S[j] := 0W;
         END;
         
         IF NOT Dali.GetDali( OAsz( PN ), OUT DaliDevice ) THEN
            CS.FromOA( L'error: unknown device' );
            RETURN FALSE;
         END; 

         IF PL = NIL THEN
            Linie := DaliBridge.l1;
         ELSE
            IF EQUALS( OAsz( PL ), L"all" ) THEN
               c := 7; // broadcast
            ELSIF NOT Strings.ToCARD32W( OAsz( PL ), 10, OUT c ) OR ( c > 3 ) THEN
               CS.FromOA( L'error: bad linie address' );
               RETURN FALSE;
            END;
            Linie := DaliBridge.TDaliLinie( c );
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

      PROCEDURE Send( type : TExceptionItemType; DaliDevice : PTR; Linie : DaliBridge.TDaliLinie; CONST address : DaliBridge.DaliAddress; command : DaliBridge.TDaliCommand; value : CARDINAL ) : BOOLEAN;
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

         AsyncResult := Dali.Command( DaliDevice, Linie, address, command, CARD8( value ), PTR( type ));
         IF ( AsyncResult = Sync.arPending ) OR ( AsyncResult = Sync.arAlreadyPending ) THEN
            RETURN TRUE; // OK
         ELSE
            CS.FromOA( L'error: unable to send command' );
            RETURN FALSE;
         END;
      END Send;
      
      //-----

      PROCEDURE ProgramItem( DaliDevice : PTR; Linie : DaliBridge.TDaliLinie; command : DaliBridge.TDaliCommand; LimitTo15Steps : BOOLEAN; REF S3 : ARRAY OF WCHAR ) : BOOLEAN;
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
            IF NOT Send( eitParam, DaliDevice, Linie, address, DaliBridge.cmdLoadDTR, c ) THEN
               RETURN FALSE;
            END;
            IF NOT Send( eitParam, DaliDevice, Linie, address, command, 0 ) THEN
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
      i := CS.ItemSOA( StringsO.WCHARS{ L' ' }, i, 0, TRUE, OUT S4 ); Strings.TrimW( REF S4 );
      
      IF EQUALS( S1, L'event' ) THEN

         IF EQUALS( S2, L'count' ) THEN
            Lock.Lock();
            c := Queue.Count;
            Lock.Unlock();
            OutValue.Integer := c;

            Logger.LogSC( dldDebug, logPrefix, L"Event.Count ", c );
            
         ELSIF EQUALS( S2, L'get' ) THEN
            IF Result.Counted OR Result.Expired THEN
               Logger.LogS( dldDebug, logPrefix, L"Event.Get clear buffer" );
               Logger.LogS( dldDebug, logPrefix, L"RS- rsEventPending" );

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
               Logger.LogS( dldDebug, logPrefix, L"RS- rsEventPending" );

               EXCL( RStatus, schiEventsPending );
            END;
            Lock.Unlock();

            IF haveEvent THEN
               ExceptionItem^.Name.ToOA( OUT S1 );
               Strings.FromCARD32W( CARD32( ExceptionItem^.Linie ), 10, OUT S2 );
               Strings.AppendW( REF S1, L"." );
               Strings.AppendW( REF S1, S2 );
               ExceptionItem^.Address.ToString( OUT S2 );
               ExceptionType := TExceptionItemType( LOPTRLONGWORD( data ));

               CASE ExceptionType OF
               | eitEvent :
                  Logger.LogSS( dldDebug, logPrefix, L"Event.Dequeue ", L"event" );
               | eitRead :
                  Logger.LogSS( dldDebug, logPrefix, L"Event.Dequeue ", L"read" );
               | eitPollStatus :
                  Logger.LogSS( dldDebug, logPrefix, L"Event.Dequeue ", L"poll status" );
               | eitWrite :
                  Logger.LogSS( dldDebug, logPrefix, L"Event.Dequeue ", L"write" );
               | eitParam :
                  Logger.LogSS( dldDebug, logPrefix, L"Event.Dequeue ", L"param" );
               | eitReset :
                  Logger.LogSS( dldDebug, logPrefix, L"Event.Dequeue ", L"reset" );
               | eitProgram :
                  Logger.LogSS( dldDebug, logPrefix, L"Event.Dequeue ", L"program" );
               | eitAddressFound :
                  Logger.LogSS( dldDebug, logPrefix, L"Event.Dequeue ", L"address found" );
               | eitResetInterface :
                  Logger.LogSS( dldDebug, logPrefix, L"Event.Dequeue ", L"reset interface" );
               END; // CASE ExceptionType

               CASE ExceptionType OF
               | eitEvent, eitRead, eitPollStatus :
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
                  | DaliBridge.cmdEvent :
                     CS.FromOA( L"value " );
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

               | eitProgram :
                  CS.FromOA( "program " );
                  CS.AppendOA( S1 ); CS.AppendOA( L" " );
                  IF ExceptionItem^.Result = Sync.arCompleted THEN
                     CS.AppendOA( L"success" );
                  ELSE
                     CS.AppendOA( L"error" );
                  END;

               | eitAddressFound :
                  CS.FromOA( "found " );
                  CS.AppendOA( S1 ); CS.AppendOA( L"." ); CS.AppendOA( S2 ); CS.AppendOA( L" " );
                  Strings.FromCARD32W( ExceptionItem^.LongAddress, 10, OUT S1 );
                  CS.AppendOA( S1 );

               | eitResetInterface :
                  CS.FromOA( "reset interface " );
                  CS.AppendOA( S1 ); CS.AppendOA( L" " );
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

      ELSIF EQUALS( S1, L'create' ) THEN
         IF S2[0] = 0W THEN
            CS.FromOA( L'error: unknown device name' );
            GOTO Error;
         END;
         IF S3[0] = 0W THEN
            CS.FromOA( L'error: unknown listen port' );
            GOTO Error;
         END;
         IF S4[0] = 0W THEN
            CS.FromOA( L'error: unknown device address' );
            GOTO Error;
         END;
         
         IF NOT Dali.CreateDali( Logger, S2, S4, S3, PTR( eitPollStatus ), OutputQueueLength, SendDelay, OUT CS ) THEN
            GOTO Error;
         END;
         CS.Clear(); // return value

      ELSIF EQUALS( S1, L'delete' ) THEN
         IF S2[0] = 0W THEN
            CS.FromOA( L'error: missing device name' );
            GOTO Error;
         END;
         
         IF NOT Dali.RemoveDali( S2 ) THEN
            CS.FromOA( L'error: unknown device' );
            GOTO Error;
         END;
         CS.Clear(); // return value

      ELSIF EQUALS( S1, L'get' ) THEN
         IF NOT SplitAddress( FALSE, FALSE, FALSE, FALSE, REF S2, OUT daliDevice, OUT Linie, REF address ) THEN
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

         IF NOT Send( eitRead, daliDevice, Linie, address, command, 0 ) THEN
            GOTO Error;
         END;
         CS.Clear(); // return value

      ELSIF EQUALS( S1, L'set' ) OR EQUALS( S1, L'dim' ) THEN
         dimFlag := S1[0] = L"d";

         IF NOT SplitAddress( FALSE, TRUE, TRUE, FALSE, REF S2, OUT daliDevice, OUT Linie, REF address ) THEN
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
      
         IF NOT Send( eitWrite, daliDevice, Linie, address, command, Level ) THEN
            GOTO Error;
         END;
         CS.Clear(); // return value

      ELSIF EQUALS( S1, L'param' )  THEN
         IF NOT SplitAddress( FALSE, FALSE, FALSE, FALSE, REF S2, OUT daliDevice, OUT Linie, REF address ) THEN
            GOTO Error;
         END;

         // S3 already contains power on level
         IF NOT ProgramItem( daliDevice, Linie, DaliBridge.cmdDTRToPowerOn, FALSE, REF S3 ) THEN
            GOTO Error;
         END;
         IF NOT ProgramItem( daliDevice, Linie, DaliBridge.cmdDTRToFail, FALSE, REF S3 ) THEN
            GOTO Error;
         END;
         IF NOT ProgramItem( daliDevice, Linie, DaliBridge.cmdDTRToMin, FALSE, REF S3 ) THEN
            GOTO Error;
         END;
         IF NOT ProgramItem( daliDevice, Linie, DaliBridge.cmdDTRToMax, FALSE, REF S3 ) THEN
            GOTO Error;
         END;
         IF NOT ProgramItem( daliDevice, Linie, DaliBridge.cmdDTRToFadeRate, TRUE, REF S3 ) THEN
            GOTO Error;
         END;
         IF NOT ProgramItem( daliDevice, Linie, DaliBridge.cmdDTRToFadeTime, TRUE, REF S3 ) THEN
            GOTO Error;
         END;
         CS.Clear(); // return value

      ELSIF EQUALS( S1, L'reset' )  THEN
         IF NOT SplitAddress( FALSE, FALSE, FALSE, FALSE, REF S2, OUT daliDevice, OUT Linie, REF address ) THEN
            GOTO Error;
         END;

         IF NOT Send( eitReset, daliDevice, Linie, address, DaliBridge.cmdReset, 0 ) THEN
            GOTO Error;
         END;
         CS.Clear(); // return value

      ELSIF EQUALS( S1, L'set_poll_period' ) THEN
         IF NOT SplitAddress( FALSE, FALSE, FALSE, TRUE, REF S2, OUT daliDevice, OUT Linie, REF address ) THEN
            GOTO Error;
         END;

         IF NOT Strings.ToCARD32W( S3, 10, OUT c ) THEN
            CS.FromOA( L'error: bad polling period' );
            GOTO Error;
         END;
         Dali.SetPollPeriod( daliDevice, Linie, c );
         CS.Clear(); // return value

      ELSIF EQUALS( S1, L'get_queue_count' ) THEN
         IF S2[0] = 0W THEN
            CS.FromOA( L'error: missing device name' );
            GOTO Error;
         END;
         IF NOT Dali.GetDali( S2, OUT daliDevice ) THEN
            CS.FromOA( L'error: unknown device: ' );
            CS.AppendOA( S2 );
            GOTO Error;
         END;
         Strings.FromCARD32W( Dali.GetOutputQueueCount( daliDevice ), 10, OUT S3 );
         CS.FromOA( S3 );

      ELSIF EQUALS( S1, L'reset_address' ) THEN
         IF NOT SplitAddress( FALSE, TRUE, TRUE, FALSE, REF S2, OUT daliDevice, OUT Linie, REF address ) THEN
            GOTO Error;
         END;

         IF NOT Send( eitReset, daliDevice, Linie, address, DaliBridge.cmdLoadDTR, 0FFH ) THEN
            GOTO Error;
         END;
         IF NOT Send( eitReset, daliDevice, Linie, address, DaliBridge.cmdDTRToAddress, 0 ) THEN
            GOTO Error;
         END;
         CS.Clear(); // return value

      ELSIF EQUALS( S1, L'program_all' )  THEN
         IF NOT SplitAddress( FALSE, FALSE, FALSE, TRUE, REF S2, OUT daliDevice, OUT Linie, REF address ) THEN
            GOTO Error;
         END;

         IF Dali.Address( daliDevice, Linie, FALSE, address ) THEN
            CS.Clear(); // return value
         ELSE
            CS.FromOA( L'error: addressing cannot start (maybe addressing is already running?)' );
            GOTO Error;
         END;

      ELSIF EQUALS( S1, L'program_added' )  THEN
         IF NOT SplitAddress( FALSE, FALSE, FALSE, TRUE, REF S2, OUT daliDevice, OUT Linie, REF address ) THEN
            GOTO Error;
         END;
         address.Type := DaliBridge.adrAll;

         IF Dali.Address( daliDevice, Linie, TRUE, address ) THEN
            CS.Clear(); // return value
         ELSE
            CS.FromOA( L'error: addressing cannot start (maybe addressing is already running?)' );
            GOTO Error;
         END;

      ELSIF EQUALS( S1, L'program_scan' )  THEN
         IF NOT SplitAddress( FALSE, FALSE, FALSE, TRUE, REF S2, OUT daliDevice, OUT Linie, REF address ) THEN
            GOTO Error;
         END;

         IF Dali.Scan( daliDevice, Linie, FALSE ) THEN
            CS.Clear(); // return value
         ELSE
            CS.FromOA( L'error: scanning cannot start (maybe addressing is already running?)' );
            GOTO Error;
         END;

      ELSIF EQUALS( S1, L'program_readdress' )  THEN
         IF NOT SplitAddress( FALSE, FALSE, FALSE, TRUE, REF S2, OUT daliDevice, OUT Linie, REF address ) THEN
            GOTO Error;
         END;

         AddressArray := DaliBridge.addressesNone;
         index := 0;
         i := CS.ItemSOA( StringsO.WCHARS{ L' ' }, 0, 2, TRUE, OUT S3 ); Strings.TrimW( REF S3 );
         LOOP
            IF S3[0] = 0W THEN
               EXIT;
            END;
            IF NOT Strings.ToCARD32W( S3, 10, OUT AddressArray[index] ) OR ( AddressArray[index] > 63 ) THEN
               CS.FromOA( L'error: bad device address: ' );
               CS.AppendOA( S3 );
               GOTO Error;
            END;
            i := CS.ItemSOA( StringsO.WCHARS{ L' ' }, i, 0, TRUE, OUT S3 ); Strings.TrimW( REF S3 );
            INC( index );
         END; // LOOP

         IF Dali.Readdress( daliDevice, Linie, AddressArray ) THEN
            CS.Clear();
         ELSE
            CS.FromOA( L'error: readdressing cannot start (maybe no addresses are known yet?)' );
            GOTO Error;
         END;

      ELSIF EQUALS( S1, L'get_addresses' )  THEN
         IF NOT SplitAddress( FALSE, FALSE, FALSE, TRUE, REF S2, OUT daliDevice, OUT Linie, REF address ) THEN
            GOTO Error;
         END;

         IF Dali.GetLongAddresses( daliDevice, Linie, OUT AddressArray ) THEN
            CS.Clear();
         ELSE
            CS.FromOA( L'error: addresses cannot be get (maybe no addresses are known yet?)' );
            GOTO Error;
         END;
         
         FOR j := 0 TO HIGH( AddressArray ) DO
            IF AddressArray[j] <> -1 THEN
               Strings.FromCARD32W( AddressArray[j], 10, OUT S1 );
               CS.AppendOA( S1 );
               CS.AppendOA( L" " );
            END;
         END; // WHILE

      ELSIF EQUALS( S1, L'load_addresses' )  THEN
         IF NOT SplitAddress( FALSE, FALSE, FALSE, TRUE, REF S2, OUT daliDevice, OUT Linie, REF address ) THEN
            GOTO Error;
         END;

         AddressArray := DaliBridge.addressesNone;
         index := 0;
         i := CS.ItemSOA( StringsO.WCHARS{ L' ' }, 0, 2, TRUE, OUT S3 ); Strings.TrimW( REF S3 );
         LOOP
            IF S3[0] = 0W THEN
               EXIT;
            END;
            IF NOT Strings.ToCARD32W( S3, 10, OUT AddressArray[index] ) THEN
               CS.FromOA( L'error: bad device long address: ' );
               CS.AppendOA( S3 );
               GOTO Error;
            END;
            i := CS.ItemSOA( StringsO.WCHARS{ L' ' }, i, 0, TRUE, OUT S3 ); Strings.TrimW( REF S3 );
            INC( index );
         END; // LOOP

         Dali.LoadLongAddresses( daliDevice, Linie, AddressArray );
         CS.Clear(); // return value

      ELSIF EQUALS( S1, L'reset_interface' )  THEN
         IF NOT SplitAddress( FALSE, FALSE, FALSE, TRUE, REF S2, OUT daliDevice, OUT Linie, REF address ) THEN
            GOTO Error;
         END;

         IF NOT Send( eitResetInterface, daliDevice, Linie, address, DaliBridge.cmdInterfaceReset, 0H ) THEN
            GOTO Error;
         END;
         
      ELSIF EQUALS( S1, L'program_file' ) THEN
         IF NOT SplitAddress( FALSE, FALSE, FALSE, TRUE, REF S2, OUT daliDevice, OUT Linie, REF address ) THEN
            GOTO Error;
         END;
         
         TRY
            fs.FromPath( S3, FIOO.imOpenRead );
         CATCH e : IOO.CIOException DO
            CS.FromOA( L'error: unable to load file' );
            GOTO Error;
         END; // CATCH
         tr.Stream := ADR( fs );
         
         NEW( FileToSend );
         FileToSend^.ItemType := lists.blitSlot64;
         
         arResult := tr.ReadLine( OUT cs, Sync.FORSAFETY, TRUE );
         haveSend := FALSE;
         filedata[0] := 0;
         WHILE arResult IN Sync.arsStarts DO
            ch := cs[0];
            cs.Remove( 0, 1 );
            cs.ReplaceOA( L" ", L"" );

            IF ch = L"S" THEN
               IF haveSend THEN
                  FileToSend^.AddOA( filedata, 0 );
               END;
               haveSend := TRUE;
               IF NOT cphcommon.FromHex( OA( cs.Length-1, cs.rawData ), OUT OA( 30, ADR( filedata[1] )), OUT i ) THEN
                  CS.FromOA( L'error: bad hex string: ' );
                  CS.AppendOA( ch );
                  CS.Append( cs );
                  GOTO Error;
               END;
               filedata[0] := BYTE( i );
               filedata[32] := 0;

            ELSIF ch = L"R" THEN
               IF NOT haveSend THEN
                  CS.FromOA( L'error: receive expectation without send' );
                  GOTO Error;
               END;
               IF NOT cphcommon.FromHex( OA( cs.Length-1, cs.rawData ), OUT OA( 30, ADR( filedata[33] )), OUT i ) THEN
                  CS.FromOA( L'error: bad hex string: ' );
                  CS.AppendOA( ch );
                  CS.Append( cs );
                  GOTO Error;
               END;
               filedata[32] := BYTE( i );
            END;

            arResult := tr.ReadLine( OUT cs, Sync.FORSAFETY, TRUE );
         END; // WHILE
         IF haveSend THEN
            FileToSend^.AddOA( filedata, 0 );
         END;
         
         IF Dali.SendFile( daliDevice, Linie, FileToSend ) THEN
            CS.Clear(); // return value
            GOTO Success; // leave FileToSend allocated
         ELSE
            CS.FromOA( L'error: file cannot be sent (maybe some file is already being sent or something is programmed?)' );
            GOTO Error;
         END;

      ELSE
         CS.FromOA( L'error: unknown driver procedure' );
      END;

   Error:
      DISPOSE( FileToSend );

      Result.Inc();
      OutValue.String := CS;
      RETURN;

   Success:
      Result.Inc();
      CS.Clear();
      OutValue.String := CS;
   END QueryProc;

//================================================================================

   LOCAL VIRTUAL PROCEDURE OnDeviceFound( CONST DaliName : StringsO.CString; Linie : DaliBridge.TDaliLinie; CONST Address : DaliBridge.DaliAddress; LongAddress : CARDINAL );
   VAR
      exceptionItem : TPExceptionItem;
   BEGIN
      NEW( exceptionItem );
      exceptionItem^.Name := DaliName;
      exceptionItem^.Linie := Linie;
      exceptionItem^.Address := Address;
      exceptionItem^.LongAddress := LongAddress;

      EnqueueEvent( exceptionItem, PTR( eitAddressFound ));
   END OnDeviceFound;

//================================================================================

   LOCAL VIRTUAL PROCEDURE OnProgrammingStopped( Result : Sync.TAsyncResult; CONST DaliName : StringsO.CString; Linie : DaliBridge.TDaliLinie );
   VAR
      exceptionItem : TPExceptionItem;
   BEGIN
      NEW( exceptionItem );
      exceptionItem^.Name := DaliName;
      exceptionItem^.Result := Result;
      exceptionItem^.Linie := Linie;

      EnqueueEvent( exceptionItem, PTR( eitProgram ));
   END OnProgrammingStopped;

//================================================================================

   LOCAL VIRTUAL PROCEDURE OnCompletion( Result : Sync.TAsyncResult; CONST DaliName : StringsO.CString; Linie : DaliBridge.TDaliLinie; CONST daliAddress : DaliBridge.DaliAddress;  Command : DaliBridge.TDaliCommand; Data : CARD8; ClientId : PTR );
   VAR
      exceptionItem : TPExceptionItem;
   BEGIN
      CASE TExceptionItemType( LOPTRLONGWORD( ClientId )) OF
      | eitRead :
         // all reads are reported
      | eitWrite, eitParam, eitReset :
         IF Result = Sync.arCompleted THEN // successfull set/program is not reported
            RETURN;
         END;
      | eitPollStatus, eitResetInterface :
         // pass everything, filtering is done in caller
      END; // CASE
      
      NEW( exceptionItem );
      exceptionItem^.Name := DaliName;
      exceptionItem^.Result := Result;
      exceptionItem^.Command := Command;
      exceptionItem^.Linie := Linie;
      exceptionItem^.Address := daliAddress;
      exceptionItem^.Value := Data;

      EnqueueEvent( exceptionItem, ClientId );      
   END OnCompletion;

//================================================================================

   PRIVATE PROCEDURE EnqueueEvent( exceptionItem : ADDRESS; ClientId : PTR );
   BEGIN
      Lock.Lock();
      Queue.Enqueue( exceptionItem, ClientId );

      IF schiEventsPending NOT IN RStatus THEN
         Logger.LogS( dldDebug, logPrefix, L"RS+ rsEventPending" );

         INCL( RStatus, schiEventsPending );
      END;
      Lock.Unlock();
      
      IF CallbackProc <> NIL THEN
         CallbackProc( CallbackId, drv_def.dcfException, NIL );
      END;
   END EnqueueEvent;

//================================================================================

BEGIN
   RStatus := TStatusChannel{};
   ClientName := L"";
   CallbackId := NIL;
   CallbackProc := NIL;

   Logger.SetLogName( logName );
   StatusChannel := MAX( CARDINAL );
   OutputQueueCountChannel := MAX( CARDINAL );
   OutputQueueLength := MAX( CARDINAL );
   SendDelay := 0;

   cllvData := ADR( cllv.data );
   cllvLength := cllv.length;
   
   Dali.EventSink := ADR( SELF );
FINALLY
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
