IMPLEMENTATION MODULE driver;

(*# call( o_a_copy => off ) *)

FROM Storage IMPORT
   ALLOCATE, DEALLOCATE;

IMPORT
   cllv,
   FIOO,
   INIFile,
   IOO,
   Log,
   Resources,
   Strings,
   StringsO,
   Sync,
   TextReader,
   Texts;

//================================================================================

TYPE
   TStatusChannelItem = (
      schiValid,
      schiRun
   );
   TStatusChannel = SET OF TStatusChannelItem;

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

      IF NOT Dali.LoadConfiguration( TS, REF Log ) THEN
         RETURN FALSE;
      END;
   
      StatusChannel := MAX( CARDINAL );
      IF TS.SetSection( snDevice ) THEN
         IF TS.GetKeyInt( knStatusChannel, OUT line, OUT c ) THEN
            StatusChannel := c;
         END;
      END; // IF snDevice

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
         Direction := CARDINAL( drv_def.dirInput );
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
   BEGIN
      Dali.Run();
   END Run;

//--------------------------------------------------------------------------------

   PUBLIC PROCEDURE Stop();
   BEGIN
      Dali.Stop();
   END Stop;

//--------------------------------------------------------------------------------

   PUBLIC PROCEDURE Dispose();
   VAR
      Data, Request : PTR;
   BEGIN
      WHILE Queue.Dequeue( OUT Request, OUT Data ) DO
         // TODO
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
      IF Result.Expired OR Result.Counted THEN
         RETURN FALSE;
      END;
      RETURN TRUE;
   END OutputFinalized;

//--------------------------------------------------------------------------------

   PUBLIC PROCEDURE QueryProc( UFlag : BOOLEAN; InValue1, InValue2 : drv_def.TValue; VAR OutValue : drv_def.TValue );
   LABEL
      Error;
   VAR
      address : DaliSci.DaliAddress;
      AsyncResult : Sync.TAsyncResult;
      c : CARDINAL;
      command : DaliSci.TDaliCommand;
      CS : StringsO.CString;
      data : PTR;
      dimFlag : BOOLEAN;
      i : CARDINAL;
      Request : PTR;
      S1, S2, S3 : ARRAY [0..63] OF WCHAR;
   BEGIN
      drv_def.DrvValueToCStringW( InValue1, UFlag, OUT CS );
      i := CS.ItemSOA( StringsO.WCHARS{ L' ' }, 0, 0, TRUE, OUT S1 ); Strings.TrimW( REF S1 );
      i := CS.ItemSOA( StringsO.WCHARS{ L' ' }, i, 0, TRUE, OUT S2 ); Strings.TrimW( REF S2 );
      i := CS.ItemSOA( StringsO.WCHARS{ L' ' }, i, 0, TRUE, OUT S3 ); Strings.TrimW( REF S3 );
      
      IF EQUALS( S1, L'event' ) THEN

         IF EQUALS( S2, L'count' ) THEN
            drv_def.AssignValueCardinal( REF OutValue, UFlag, TRUE, Queue.Count );
            
         ELSIF EQUALS( S2, L'get' ) THEN
            IF Queue.Dequeue( OUT Request, OUT data ) THEN
               DISPOSE( Request );
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
         address.Type := DaliSci.adrSingle;
         address.Address := c;

         IF EQUALS( S3, L'status' ) THEN
            command := DaliSci.cmdStatus;
         ELSIF EQUALS( S3, L'operating' ) THEN
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

         AsyncResult := Dali.Command( address, command, 0, 1 );
         IF AsyncResult <> Sync.arPending THEN
            CS.FromOA( L'error: unable to send command' );
            GOTO Error;
         END;

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
               IF Strings.ToCARD32W( S3, 10, OUT c ) AND ( c < 256 ) THEN
                  command := DaliSci.cmdDirect;
               ELSE
                  CS.FromOA( L'error: bad set command parameter' );
                  GOTO Error;
               END;
            END;
         END;
      
         AsyncResult := Dali.Command( address, command, 0, 0 );
         IF AsyncResult <> Sync.arPending THEN
            CS.FromOA( L'error: unable to send command' );
            GOTO Error;
         END;

         IF Result.Counted THEN
            CS.Clear();
            GOTO Error;

         ELSIF Result.Expired THEN
            CS.Clear();
            GOTO Error;
         END;

         // prObjects[EIT].SetValue( EV );

      ELSE
         CS.FromOA( L'error: unknown driver procedure' );
      END;

   Error:
      drv_def.AssignDrvValueCStringW( REF OutValue, UFlag, FALSE, CS );
      Result.Inc();
   END QueryProc;

//================================================================================

   LOCAL VIRTUAL PROCEDURE OnCompletion( Result : Sync.TAsyncResult; ClientId : PTR; CONST daliAddress : DaliSci.DaliAddress; Data : CARD8 );
   BEGIN
      IF Result <> Sync.arCompleted THEN
      
         IF CallbackProc <> NIL THEN
            CallbackProc( CallbackId, drv_def.dcfException, NIL );
         END;
      END;
   END OnCompletion;

//================================================================================

BEGIN
   ClientName := L"";
   CallbackId := NIL;
   CallbackProc := NIL;

   StatusChannel := MAX( CARDINAL );

   cllvData := ADR( cllv.data );
   cllvLength := cllv.length;
   
   Dali.EventSink := ADR( SELF );
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
   // logging
   Log.logger()^.SetUpByRegistry( LIBRARY );
END __I;

//================================================================================

END driver.