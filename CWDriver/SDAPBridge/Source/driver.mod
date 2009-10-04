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
   logName = L"SDAPBridge.";
   logPrefix = L"DRV";

(*================================================================================*)

TYPE
   TExceptionItemType = ( eitConnected, eitDisconnected, eitAdvise ); // data
   TPExceptionItem = POINTER TO ExceptionItem; // item

CLASS ExceptionItem;
   LOCAL VAR
      Result : Sync.TAsyncResult := Sync.arCompleted;
      Address : StringsO.CString;
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
   VAR
      LongName : ARRAY [0..255] OF WCHAR;
   BEGIN
      SymbolicName.ToOA( OUT ClientName );
      Strings.ConcatW( OUT LongName, logName, ClientName );
      Logger.SetLogName( LongName );

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
      snDevice = L'device';
         knHost = L'sdap_server';
   VAR
      c, line : CARDINAL;
      commentaryStart : StringsO.CString;
      Host : StringsO.CString;
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
      commentaryStart.FromOA( L";" );
      tr.CommentaryStart := commentaryStart;
      tr.OmitCommentaries := TRUE;
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
      InputQueueCountChannel := MAX( CARDINAL );
      OutputQueueCountChannel := MAX( CARDINAL );
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
      END; // IF snInterface
      
      IF TS.SetSection( snDevice ) THEN
         IF NOT TS.GetKeyStr( knHost, OUT line, OUT Host ) THEN
            Log.LogFilePos( log.dlcError, ClientName, OA( ParFilePath.Length-1, ParFilePath.rawData ), OAsz( R()^[ Texts._MissingHostKey ] ), 0, 0 );
            RETURN FALSE;
         END;
      ELSE
         Log.LogFilePos( log.dlcError, ClientName, OA( ParFilePath.Length-1, ParFilePath.rawData ), OAsz( R()^[ Texts._MissingDeviceSection ] ), 0, 0 );
         RETURN FALSE;
      END;
      
      SDAP.SetConfiguration( ClientName, Logger, Host );
      
      RETURN TRUE;
   END ReadParameters;

(*--------------------------------------------------------------------------------*)

   PUBLIC VIRTUAL PROCEDURE QueryErrorCode( ErrorCode : CARDINAL; OUT ErrorText : StringsO.CString ) : BOOLEAN;
   BEGIN
      RETURN FALSE;
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
         EnumerateState := Index+1;
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
      
      Logger.LogS( log.dldMessage, logPrefix, L"RUN" );

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

      Logger.LogS( log.dldMessage, logPrefix, L"STOP" );

      SDAP.Stop();
   END DriverStop;

(*--------------------------------------------------------------------------------*)

   PUBLIC VIRTUAL PROCEDURE Dispose();
   BEGIN
      DriverStop();
      DisposeQueue();
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
      // Result.Inc(); -- inputs are fully informative, they do not need licence blocking
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
      Return, Success;
   VAR
      c : CARDINAL;
      CS : StringsO.CString;
      data : PTR;
      exceptionItem : TPExceptionItem;
      exceptionType : TExceptionItemType;
      haveEvent : BOOLEAN;
      i : INTEGER;
      S1, S2, S3 : StringsO.CString;
   BEGIN
      CS := InValue1.String;
      i := CS.ItemS( StringsO.WCHARS{ L' ' }, 0, 0, TRUE, OUT S1 ); S1.Trim();
      i := CS.ItemS( StringsO.WCHARS{ L' ' }, i, 0, TRUE, OUT S2 ); S2.Trim();
      i := CS.ItemS( StringsO.WCHARS{ L' ' }, i, 0, TRUE, OUT S3 ); S3.Trim();
      
      IF S1.EqualsOA( L'event' ) THEN

         IF S2.EqualsOA( L'count' ) THEN
            Lock.Lock();
            c := Queue.Count;
            Lock.Unlock();
            OutValue.Integer := c;

            Logger.LogSC( dldDebug, logPrefix, L"Event.Count", c );
            GOTO Return;
            
         ELSIF S2.EqualsOA( L'get' ) THEN
            IF Result.Counted OR Result.Expired THEN
               Logger.LogS( dldDebug, logPrefix, L"Event.Get clear buffer" );
               Logger.LogS( dldDebug, logPrefix, L"RS- rsEventPending" );

               Lock.Lock();
               DisposeQueue();
               EXCL( RStatus, schiEventsPending );
               Lock.Unlock();
               
               GOTO Success;
            END;
         
            Lock.Lock();
            IF Queue.Dequeue( OUT exceptionItem, OUT data ) THEN
               haveEvent := TRUE;
            ELSE
               haveEvent := FALSE;
               Logger.LogS( dldDebug, logPrefix, L"RS- rsEventPending" );

               EXCL( RStatus, schiEventsPending );
            END;
            Lock.Unlock();

            IF haveEvent THEN
               exceptionType := TExceptionItemType( LOPTRLONGWORD( data ));

               CASE exceptionType OF
               | eitConnected :
                  Logger.LogSS( dldDebug, logPrefix, L"Event.Dequeue", L"'connected'" );
                  CS.FromOA( L"connected" );  
               | eitDisconnected :
                  Logger.LogSS( dldDebug, logPrefix, L"Event.Dequeue", L"'disconnected'" );
                  CS.FromOA( L"disconnected" );  
               | eitAdvise :
                  Logger.LogSS( dldDebug, logPrefix, L"Event.Dequeue", L"'advise'" );
                  CS.FromOA( L"advise " );
                  CS.Append( exceptionItem^.Address );
                  CS.AppendOA( L" " );
                  CS.Append( exceptionItem^.Value );
               END; // CASE ExceptionType

               DISPOSE( exceptionItem );
               GOTO Return;
               
            END;

         ELSE
            Logger.LogSSSS( dldTrace, logPrefix, L"DQP unknown event procedure '", OA( S2.Length-1, S2.rawData ), L"'", L"" );
            CS.FromOA( L'error: unknown driver procedure' );
            GOTO Return;
         END;

      ELSIF Result.Counted OR Result.Expired THEN
         GOTO Success; // allow nothing for unlicenced driver

      ELSIF S1.EqualsOA( L'set' ) THEN
         IF S2.Empty THEN
            Logger.LogS( dldTrace, logPrefix, L"DQP 'set', missing address" );
            CS.FromOA( L'error: missing address' );
            GOTO Return;
         END;
         IF S3.Empty THEN
            Logger.LogS( dldTrace, logPrefix, L"DQP 'set', missing value" );
            CS.FromOA( L'error: missing value' );
            GOTO Return;
         END;

         Logger.LogSSSS( dldDebug, logPrefix, L"DQP 'set',", OA( S2.Length-1, S2.rawData ), OA( S3.Length-1, S3.rawData ), L"" );
         SDAP.Set( S2, S3 );

      ELSIF S1.EqualsOA( L'ask' ) THEN
         IF S2.Empty THEN
            Logger.LogS( dldTrace, logPrefix, L"DQP 'ask', missing address" );
            CS.FromOA( L'error: missing address' );
            GOTO Return;
         END;
         
         Logger.LogSS( dldDebug, logPrefix, L"DQP 'ask',", OA( S2.Length-1, S2.rawData ));
         SDAP.Ask( S2 );

      ELSIF S1.EqualsOA( L'advise' ) THEN
         Logger.LogS( dldDebug, logPrefix, L"DQP 'advise'" );
         SDAP.Advise();

      ELSIF S1.EqualsOA( L'unadvise' ) THEN
         Logger.LogS( dldDebug, logPrefix, L"DQP 'unadvise'" );
         SDAP.Unadvise();

      ELSE
         Logger.LogSSSS( dldTrace, logPrefix, L"DQP unknown procedure '", OA( S1.Length-1, S1.rawData ), L"'", L"" );
         CS.FromOA( L'error: unknown driver procedure' );
         GOTO Return;
      END;

   Success:
      CS.Clear();
   Return:
      Result.Inc();
      OutValue.String := CS;
   END QueryProc;

(*--------------------------------------------------------------------------------*)

   LOCAL VIRTUAL PROCEDURE OnConnected();
   BEGIN
      Logger.LogS( dldTrace, logPrefix, L"'connected' event" );

      EnqueueEvent( NIL, PTR( eitConnected ));
   END OnConnected;

(*--------------------------------------------------------------------------------*)

   LOCAL VIRTUAL PROCEDURE OnDisconnected( Result : Sync.TAsyncResult );
   VAR
      exceptionItem : TPExceptionItem;
   BEGIN
      Logger.LogS( dldTrace, logPrefix, L"'disconnected' event" );

      NEW( exceptionItem );
      exceptionItem^.Result := Result;
      EnqueueEvent( exceptionItem, PTR( eitDisconnected ));
   END OnDisconnected;

(*--------------------------------------------------------------------------------*)

   LOCAL VIRTUAL PROCEDURE OnData( CONST Address, Value : StringsO.IString );
   VAR
      exceptionItem : TPExceptionItem;
   BEGIN
      Logger.LogSSSS( dldDebug, logPrefix, L"'advise' event,", OA( Address.Length-1, Address.rawData ), OA( Value.Length-1, Value.rawData ), L"" );

      NEW( exceptionItem );
      exceptionItem^.Address.Assign( Address );
      exceptionItem^.Value.Assign( Value );
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

   PRIVATE PROCEDURE DisposeQueue();
   VAR
      Data : PTR;
      ExceptionItem : TPExceptionItem;
   BEGIN
      WHILE Queue.Dequeue( OUT ExceptionItem, OUT Data ) DO
         IF ExceptionItem <> NIL THEN
            DISPOSE( ExceptionItem );
         END;
      END; // WHILE
   END DisposeQueue;

(*--------------------------------------------------------------------------------*)

BEGIN
   RStatus := TStatusChannel{};
   ClientName := L"";
   CallbackId := NIL;
   CallbackProc := NIL;

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
