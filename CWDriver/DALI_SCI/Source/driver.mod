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
   logPrefix = L"DaliSci";

//================================================================================

TYPE
   TExceptionItemType = ( eitRead, eitWrite, eitPollStatus, eitParam );
   TPExceptionItem = POINTER TO ExceptionItem;

CLASS ExceptionItem;
   LOCAL VAR
      Result : Sync.TAsyncResult := Sync.arCompleted;
      Command : DaliSci.TDaliCommand := DaliSci.cmdOff;
      Address : DaliSci.DaliAddress;
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

      StatusChannel := MAX( CARDINAL );
      IF TS.SetSection( snDevice ) THEN
         IF TS.GetKeyInt( knStatusChannel, OUT line, OUT c ) THEN
            StatusChannel := c;
         END;
      END; // IF snDevice

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

      IF NOT Dali.LoadConfiguration( TS, REF Log ) THEN
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
      
      CASE Index OF
      | 0 :
         IF StatusChannel = MAX( CARDINAL ) THEN
            RETURN FALSE;
         END;
         Type := CARDINAL( drv_def.vtLongCard );
         Direction := CARDINAL( drv_def.TDirection{ drv_def.dirInput } );
         DriverIndex := StatusChannel;
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
   BEGIN
      IF DriverIndex = StatusChannel THEN
         ASSIGN( Description, OAsz( R()^[ Texts._StatusComment ] ));
         ASSIGN( Id, _StatusId );
      ELSE
         RETURN FALSE;
      END;
      RETURN TRUE;
   END GetChannelDescription;

//--------------------------------------------------------------------------------

   PUBLIC PROCEDURE Run();
   VAR
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

      IF PollTimer = NIL THEN
         netpool.Pool()^.WaitTimeout( PollSink, 0, 1000, FALSE, TRUE, OUT PollTimer );
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
         netpool.Pool()^.Abort( REF PollTimer );
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
      address : DaliSci.DaliAddress;
      c : CARDINAL;
      command : DaliSci.TDaliCommand;
      CS : StringsO.CString;
      data : PTR;
      dimFlag : BOOLEAN;
      ExceptionItem : TPExceptionItem;
      ExceptionType : TExceptionItemType;
      i : CARDINAL;
      Level : CARDINAL;
      N : ARRAY [0..15] OF WCHAR;
      S1, S2, S3 : ARRAY [0..63] OF WCHAR;
      
      //-----

      PROCEDURE Send( type : TExceptionItemType; CONST address : DaliSci.DaliAddress; command : DaliSci.TDaliCommand; value : CARDINAL ) : BOOLEAN;
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

      PROCEDURE ProgramItem( command : DaliSci.TDaliCommand; LimitTo15Steps : BOOLEAN; REF S3 : ARRAY OF WCHAR ) : BOOLEAN;
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
            IF NOT Send( eitParam, address, DaliSci.cmdLoadDTR, c ) THEN
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
            c := Queue.Count;
            drv_def.AssignValueCardinal( REF OutValue, UFlag, TRUE, c );

            Dali.Logger.LogSC( dldDebug, logPrefix, L"Event.Count ", c );
            
         ELSIF EQUALS( S2, L'get' ) THEN
            IF Result.Counted OR Result.Expired THEN
               Dali.Logger.LogS( dldDebug, logPrefix, L"Event.Get clear buffer" );
               Dali.Logger.LogS( dldDebug, logPrefix, L"RS- rsEventPending" );

               Queue.Dispose();
               EXCL( RStatus, schiEventsPending );
               GOTO Success;
            END;
         
            IF Queue.Dequeue( OUT ExceptionItem, OUT data ) THEN
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
                  IF ExceptionItem^.Command = DaliSci.cmdStatus THEN
                     CS.FromOA( "status " ); CS.AppendOA( N ); CS.AppendOA( L" " ); 
                  ELSE
                     CS.FromOA( "value " ); CS.AppendOA( N ); CS.AppendOA( L" " ); 
                  END;
                  IF ExceptionItem^.Result = Sync.arCompleted THEN

                     IF ExceptionItem^.Command = DaliSci.cmdStatus THEN
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
                           CS.AppendOA( L"initstate " );
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
               Dali.Logger.LogS( dldDebug, logPrefix, L"RS- rsEventPending" );

               EXCL( RStatus, schiEventsPending );
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
         address.Type := DaliSci.adrSingle;
         address.Address := c;

         IF EQUALS( S3, L'status' ) THEN
            command := DaliSci.cmdStatus;
         ELSIF EQUALS( S3, L'present' ) THEN
            command := DaliSci.cmdWorking;
         ELSIF EQUALS( S3, L'type' ) THEN
            command := DaliSci.cmdDeviceType;
         ELSIF EQUALS( S3, L'version' ) THEN
            command := DaliSci.cmdVersion;
         ELSIF EQUALS( S3, L'level' ) THEN
            command := DaliSci.cmdCurrentLevel;
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
            address.Type := DaliSci.adrAll;
         ELSIF S2[0] = L"g" THEN
            Strings.RemoveW( REF S2, 0, 1 );
            IF NOT Strings.ToCARD32W( S2, 10, OUT c ) OR ( c > 15 ) THEN
               CS.FromOA( L'error: bad group address' );
               GOTO Error;
            END;
            address.Type := DaliSci.adrGroup;
            address.Address := c;
         ELSE
            IF NOT Strings.ToCARD32W( S2, 10, OUT c ) OR ( c > 63 ) THEN
               CS.FromOA( L'error: bad device address' );
               GOTO Error;
            END;
            address.Type := DaliSci.adrSingle;
            address.Address := c;
         END;

         IF dimFlag THEN
            IF EQUALS( S3, L"up" ) THEN
               command := DaliSci.cmdDimUp;
            ELSIF EQUALS( S3, L"down" ) THEN
               command := DaliSci.cmdDimDown;
            ELSIF EQUALS( S3, L"step_up" ) THEN
               command := DaliSci.cmdStepUp;
            ELSIF EQUALS( S3, L"step_down" ) THEN
               command := DaliSci.cmdStepDown;
            ELSIF EQUALS( S3, L"step_up_on" ) THEN
               command := DaliSci.cmdStepUpOn;
            ELSIF EQUALS( S3, L"step_down_off" ) THEN
               command := DaliSci.cmdStepDownOff;
            ELSE
               CS.FromOA( L'error: bad dim command parameter' );
               GOTO Error;
            END;
         ELSE         
            IF EQUALS( S3, L"on" ) THEN
               command := DaliSci.cmdStepUpOn;
            ELSIF EQUALS( S3, L"off" ) THEN
               command := DaliSci.cmdOff;
            ELSIF EQUALS( S3, L"min" ) THEN
               command := DaliSci.cmdMin;
            ELSIF EQUALS( S3, L"max" ) THEN
               command := DaliSci.cmdMax;
            ELSE
               IF Strings.ToCARD32W( S3, 10, OUT Level ) AND ( Level < 256 ) THEN
                  command := DaliSci.cmdDirect;
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
         address.Type := DaliSci.adrSingle;
         address.Address := c;

         // S3 already contains power on level
         IF NOT ProgramItem( DaliSci.cmdDTRToPowerOn, FALSE, REF S3 ) THEN
            GOTO Error;
         END;
         IF NOT ProgramItem( DaliSci.cmdDTRToFail, FALSE, REF S3 ) THEN
            GOTO Error;
         END;
         IF NOT ProgramItem( DaliSci.cmdDTRToMin, FALSE, REF S3 ) THEN
            GOTO Error;
         END;
         IF NOT ProgramItem( DaliSci.cmdDTRToMax, FALSE, REF S3 ) THEN
            GOTO Error;
         END;
         IF NOT ProgramItem( DaliSci.cmdDTRToFadeRate, TRUE, REF S3 ) THEN
            GOTO Error;
         END;
         IF NOT ProgramItem( DaliSci.cmdDTRToFadeTime, TRUE, REF S3 ) THEN
            GOTO Error;
         END;
         CS.Clear(); // return value

      ELSIF EQUALS( S1, L'reset' )  THEN
         IF NOT Strings.ToCARD32W( S2, 10, OUT c ) OR ( c > 63 ) THEN
            CS.FromOA( L'error: bad device address' );
            GOTO Error;
         END;
         address.Type := DaliSci.adrSingle;
         address.Address := c;

         IF NOT Send( eitWrite, address, DaliSci.cmdReset, 0 ) THEN
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

   LOCAL VIRTUAL PROCEDURE OnTimeout( Result : Sync.TAsyncResult; PoolHandle : Sync.WAITABLE; UserId : PTR );
   VAR
      address : DaliSci.DaliAddress;
   BEGIN
      PollIndex := INC( PollIndex ) AND 63;
      address.Type := DaliSci.adrSingle;
      address.Address := PollIndex;

      Dali.Logger.LogSC( dldDebug, logPrefix, L"Poll status request for: ", PollIndex );

      Dali.Command( address, DaliSci.cmdStatus, 0, PTR( eitPollStatus ));
   END OnTimeout;

//================================================================================

   LOCAL VIRTUAL PROCEDURE OnCompletion( Result : Sync.TAsyncResult; Command : DaliSci.TDaliCommand; ClientId : PTR; CONST daliAddress : DaliSci.DaliAddress; Data : CARD8 );
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
      Queue.Enqueue( exceptionItem, ClientId );

      IF schiEventsPending NOT IN RStatus THEN
         Dali.Logger.LogS( dldDebug, logPrefix, L"RS+ rsEventPending" );

         INCL( RStatus, schiEventsPending );
      END;
      
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
   Fill( ADR( StatusArray ), SIZE( StatusArray ), 0FFH );
   PollTimer := NIL;

   cllvData := ADR( cllv.data );
   cllvLength := cllv.length;
   
   NEW( PollSink );
   PollSink^.TimeoutSink := ADR( SELF );
   PollIndex := 0;

   Dali.EventSink := ADR( SELF );
FINALLY
   IF PollSink <> NIL THEN
      PollSink^.Release();
      PollSink := NIL;
   END;
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
   r.LoadRES2( EMITW( %dll ), L"Dali_SCI.Texts" );
END __I;

//================================================================================

END driver.