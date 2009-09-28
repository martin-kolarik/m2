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

(*================================================================================*)

CONST
   logName = L"SDAPBridge";
   logPrefix = L"DRV";

(*================================================================================*)

TYPE
   TExceptionItemType = ( eitConnected, eitDisconnected, eitAdvise ); // data
   TPExceptionItem = POINTER TO ExceptionItem; // item

CLASS ExceptionItem;
   LOCAL VAR
      Result : Sync.TAsyncResult := Sync.arCompleted;
      Data : StringsO.CString;
      Value : StringsO.CString;
END ExceptionItem;

(*--------------------------------------------------------------------------------*)

CLASS IMPLEMENTATION ExceptionItem;
BEGIN
END ExceptionItem;

(*================================================================================*)

CLASS IMPLEMENTATION CDriver;

(*--------------------------------------------------------------------------------*)

   PUBLIC VIRTUAL PROCEDURE Initialize( RunMode : CARDINAL; CONST SymbolicName : StringsO.CString; CallbackId : ADDRESS; PCallback : drv_def.TDriverCallbackW );
   BEGIN
      SymbolicName.ToOA( OUT ClientName );
      SELF.CallbackId := CallbackId;
      SELF.CallbackProc := PCallback;
   END Initialize;

(*--------------------------------------------------------------------------------*)

   PUBLIC VIRTUAL PROCEDURE ReadParameters( CONST ParFilePath : StringsO.CString; CONST Log : log.CLogger ) : BOOLEAN;
   CONST
      snInterface = L'interface';
         knStatusChannel = L'status_channel';
         knInputQueueCountChannel = L'input_queue_count_channel';
         knOutputQueueCountChannel = L'output_queue_count_channel';
         knOutputQueueLength = L'output_queue_length';
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
      CASE INIFile.ConfigureLog( TS, L"", REF Logger, OUT line ) OF
      | INIFile.clrUnknownTarget :
         Log.LogFilePos( log.dlcError, ClientName, OA( ParFilePath.Length-1, ParFilePath.rawData ), OAsz( R()^[ Texts._UnknownDebugMode ] ), line, 0 );
         RETURN FALSE;
      | INIFile.clrUnknownLevel :
         Log.LogFilePos( log.dlcError, ClientName, OA( ParFilePath.Length-1, ParFilePath.rawData ), OAsz( R()^[ Texts._UnknownDebugLevel ] ), line, 0 );
         RETURN FALSE;
      | INIFile.clrTargetFileMissingFile :
         Log.LogFilePos( log.dlcError, ClientName, OA( ParFilePath.Length-1, ParFilePath.rawData ), OAsz( R()^[ Texts._FileDebugMissingFile ] ), line, 0 );
         RETURN FALSE;
      END;

      StatusChannel := MAX( CARDINAL );
      IF TS.SetSection( snInterface ) THEN
         IF TS.GetKeyInt( knStatusChannel, OUT line, OUT c ) THEN
            StatusChannel := c;
         END;
         IF TS.GetKeyInt( knInputQueueCountChannel, OUT line, OUT c ) THEN
            InputQueueCountChannel := c;
         END;
         IF TS.GetKeyInt( knOutputQueueCountChannel, OUT line, OUT c ) THEN
            OutputQueueCountChannel := c;
         END;
         IF TS.GetKeyInt( knOutputQueueLength, OUT line, OUT c ) THEN
            OutputQueueLength := c;
         END;
      END; // IF snDevice
      
      RETURN TRUE;
   END ReadParameters;

(*--------------------------------------------------------------------------------*)

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

(*--------------------------------------------------------------------------------*)

   PUBLIC VIRTUAL PROCEDURE EnumerateChannels( REF EnumerateState : LONGWORD; OUT Type : drv_def.TValueType; OUT Direction : drv_def.TDirection; OUT DriverIndex, Count : CARDINAL; OUT HaveDescription : BOOLEAN ): BOOLEAN;
   VAR
      Index : CARDINAL := EnumerateState;
   BEGIN
      Count := 1;
      HaveDescription := TRUE;
      
      IF Index > 2 THEN
         RETURN FALSE;
      END;

      IF Index = 0 THEN
         IF StatusChannel = MAX( CARDINAL ) THEN
            Index := 1;
         ELSE
            Type := drv_def.vtLongCard;
            Direction := drv_def.TDirection{ drv_def.dirInput };
            DriverIndex := StatusChannel;
         END;
      END;

      IF Index = 1 THEN
         IF InputQueueCountChannel = MAX( CARDINAL ) THEN
            Index := 2;
         ELSE
            Type := drv_def.vtLongCard;
            Direction := drv_def.TDirection{ drv_def.dirInput };
            DriverIndex := InputQueueCountChannel;
         END;
      END;

      IF Index = 2 THEN
         IF OutputQueueCountChannel = MAX( CARDINAL ) THEN
            Index := 3;
         ELSE
            Type := drv_def.vtLongCard;
            Direction := drv_def.TDirection{ drv_def.dirInput };
            DriverIndex := OutputQueueCountChannel;
         END;
      END;

      IF Index = 3 THEN
         RETURN FALSE;
      ELSE
         EnumerateState := Index;
         RETURN TRUE;
      END;
   END EnumerateChannels;

(*--------------------------------------------------------------------------------*)

   PUBLIC VIRTUAL PROCEDURE GetChannelDescription( DriverIndex : CARDINAL; OUT Description, Id : StringsO.CString ) : BOOLEAN;
   CONST
      _StatusId = L'drvStatus';
      _InputQueueCountId = L'drvInputQueueCount';
      _OutputQueueCountId = L'drvOutputQueueCount';
   BEGIN
      IF DriverIndex = StatusChannel THEN
         Description.FromOA( OAsz( R()^[ Texts._StatusComment ] ));
         Id.FromOA( _StatusId );
      ELSIF DriverIndex = InputQueueCountChannel THEN
         Description.FromOA( OAsz( R()^[ Texts._InputQueueCountComment ] ));
         Id.FromOA( _InputQueueCountId );
      ELSIF DriverIndex = OutputQueueCountChannel THEN
         Description.FromOA( OAsz( R()^[ Texts._OutputQueueCountComment ] ));
         Id.FromOA( _OutputQueueCountId );
      ELSE
         RETURN FALSE;
      END;
      RETURN TRUE;
   END GetChannelDescription;

(*--------------------------------------------------------------------------------*)

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

      SDAP.Run();
   END DriverRun;

(*--------------------------------------------------------------------------------*)

   PUBLIC VIRTUAL PROCEDURE DriverStop();
   BEGIN
      IF schiRunning NOT IN RStatus THEN
         RETURN;
      END;
      EXCL( RStatus, schiRunning );

      Logger.LogS( log.dldError, logPrefix, L"STOP" );

      SDAP.Stop();
   END DriverStop;

(*--------------------------------------------------------------------------------*)

   PUBLIC VIRTUAL PROCEDURE Dispose();
   VAR
      Data : PTR;
      ExceptionItem : TPExceptionItem;
   BEGIN
      DriverStop();
      WHILE Queue.Dequeue( OUT ExceptionItem, OUT Data ) DO
         IF ExceptionItem <> NIL THEN
            DISPOSE( ExceptionItem );
         END;
      END; // WHILE
   END Dispose;

(*--------------------------------------------------------------------------------*)

   PUBLIC VIRTUAL PROCEDURE DriverProc( Func, Param1, Param2, Param3, Param4 : CARDINAL );
   BEGIN
   END DriverProc;

(*--------------------------------------------------------------------------------*)

   PUBLIC VIRTUAL PROCEDURE InputRequestStart();
   BEGIN
   END InputRequestStart;

(*--------------------------------------------------------------------------------*)

   PUBLIC VIRTUAL PROCEDURE InputRequest( DriverIndex : CARDINAL );
   BEGIN
      Result.Inc();
   END InputRequest;

(*--------------------------------------------------------------------------------*)

   PUBLIC VIRTUAL PROCEDURE InputRequestCompleted();
   BEGIN
   END InputRequestCompleted;

(*--------------------------------------------------------------------------------*)

   PUBLIC VIRTUAL PROCEDURE InputFinalized( DriverIndex : CARDINAL; OUT ErrorCode : CARDINAL ) : BOOLEAN;
   BEGIN
      IF DriverIndex = StatusChannel THEN
         ErrorCode := drv_def.ecSuccess;
      ELSIF Result.Expired OR Result.Counted THEN
         RETURN FALSE;
      ELSIF DriverIndex = InputQueueCountChannel THEN
         ErrorCode := drv_def.ecSuccess;
      ELSIF DriverIndex = OutputQueueCountChannel THEN
         ErrorCode := drv_def.ecSuccess;
      END;
      RETURN TRUE;
   END InputFinalized;

(*--------------------------------------------------------------------------------*)

   PUBLIC VIRTUAL PROCEDURE InputOOBDataQuery( REF EnumerateState : LONGWORD; OUT DriverIndex : CARDINAL ) : BOOLEAN;
   BEGIN
      RETURN FALSE;
   END InputOOBDataQuery;

(*--------------------------------------------------------------------------------*)

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

         IF SDAP.Connected THEN
            INCL( Status, schiConnected );
         ELSE
            EXCL( Status, schiConnected );
         END;

         InValue.Integer := CARDINAL( Status );

      ELSIF DriverIndex = InputQueueCountChannel THEN
         QoS := drv_def.qosGood;
         ErrorCode := drv_def.ecSuccess;

         InValue.Integer := Queue.Count;

      ELSIF DriverIndex = OutputQueueCountChannel THEN
         QoS := drv_def.qosGood;
         ErrorCode := drv_def.ecSuccess;

         InValue.Integer := SDAP.OutputQueueCount;

      END;
   END GetInput;

(*--------------------------------------------------------------------------------*)

   PUBLIC VIRTUAL PROCEDURE OutputRequestStart();
   BEGIN
   END OutputRequestStart;

(*--------------------------------------------------------------------------------*)

   PUBLIC VIRTUAL PROCEDURE OutputRequest( DriverIndex : CARDINAL; CONST OutValue : iovalue.Value; QoS : CARDINAL; CONST TimeStamp : drv_def.TUTCStamp );
   BEGIN
      Result.Inc();
   END OutputRequest;

(*--------------------------------------------------------------------------------*)

   PUBLIC VIRTUAL PROCEDURE OutputRequestCompleted();
   BEGIN
   END OutputRequestCompleted;

(*--------------------------------------------------------------------------------*)

   PUBLIC VIRTUAL PROCEDURE OutputFinalized( DriverIndex : CARDINAL; OUT ErrorCode : CARDINAL ) : BOOLEAN;
   BEGIN
      IF Result.Counted OR Result.Expired THEN
         RETURN FALSE;
      END;
      RETURN TRUE;
   END OutputFinalized;

(*--------------------------------------------------------------------------------*)

   PUBLIC VIRTUAL PROCEDURE QueryProc( CONST InValue1, InValue2 : iovalue.Value; OutValueLimit : CARDINAL; OUT OutValue : iovalue.Value );
   LABEL
      Error, Success;
      
      //-----

      PROCEDURE Send( reques : TRequest ) : BOOLEAN;
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

      ELSIF EQUALS( S1, L'set' ) THEN
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

      ELSIF EQUALS( S1, L'ask' ) THEN
         IF S2[0] = 0W THEN
            CS.FromOA( L'error: missing device name' );
            GOTO Error;
         END;
         
         IF NOT Dali.RemoveDali( S2 ) THEN
            CS.FromOA( L'error: unknown device' );
            GOTO Error;
         END;
         CS.Clear(); // return value

      ELSIF EQUALS( S1, L'advise' ) THEN
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

      ELSE
         CS.FromOA( L'error: unknown driver procedure' );
      END;

   Success:
      CS.Clear();
   Error:
      Result.Inc();
      OutValue.String := CS;
   END QueryProc;

(*--------------------------------------------------------------------------------*)

   LOCAL VIRTUAL PROCEDURE OnConnected();
   BEGIN
      EnqueueEvent( NIL, PTR( eitConnected ));
   END OnConnected;

(*--------------------------------------------------------------------------------*)

   LOCAL VIRTUAL PROCEDURE OnDisconnected( Result : Sync.TAsyncResult );
   VAR
      exceptionItem : TPExceptionItem;
   BEGIN
      NEW( exceptionItem );
      exceptionItem^.Result := Result;
      EnqueueEvent( exceptionItem, PTR( eitDisconnected ));
   END OnDisconnected;

(*--------------------------------------------------------------------------------*)

   LOCAL VIRTUAL PROCEDURE OnData( CONST Data, Value : StringsO.CString );
   VAR
      exceptionItem : TPExceptionItem;
   BEGIN
      NEW( exceptionItem );
      exceptionItem^.Data := Data;
      exceptionItem^.Value := Value;
      EnqueueEvent( exceptionItem, PTR( eitAdvise ));
   END OnData;

(*--------------------------------------------------------------------------------*)

   PRIVATE PROCEDURE EnqueueEvent( exceptionItem : ADDRESS; eventType : PTR );
   BEGIN
      Lock.Lock();
      Queue.Enqueue( exceptionItem, eventType );

      IF schiEventsPending NOT IN RStatus THEN
         Logger.LogS( dldDebug, logPrefix, L"RS+ rsEventPending" );

         INCL( RStatus, schiEventsPending );
      END;
      Lock.Unlock();
      
      IF CallbackProc <> NIL THEN
         CallbackProc( CallbackId, drv_def.dcfException, NIL );
      END;
   END EnqueueEvent;

(*--------------------------------------------------------------------------------*)

BEGIN
   RStatus := TStatusChannel{};
   ClientName := L"";
   CallbackId := NIL;
   CallbackProc := NIL;

   Logger.SetLogName( logName );
   StatusChannel := MAX( CARDINAL );
   InputQueueCountChannel := MAX( CARDINAL );
   OutputQueueCountChannel := MAX( CARDINAL );
   OutputQueueLength := MAX( CARDINAL );

   cllvData := ADR( cllv.data );
   cllvLength := cllv.length;
   
   SDAP.EventSink := ADR( SELF );
FINALLY
   SDAP.Dispose();
END CDriver;

(*================================================================================*)

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
   r.LoadRES2( EMITW( %dll ), L"SDAPBridge.Texts" );
   diface.RegisterFactory( ADR( Factory ));
END driver.

(*================================================================================*)
