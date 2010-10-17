MODULE driver;

(*# call( o_a_copy => off ) *)

(*================================================================================*)

FROM Storage IMPORT
  ALLOCATE, DEALLOCATE;
  
FROM log IMPORT
  ldTrace, ldDebug, lcError;

IMPORT
   cllv,
   diface,
   drv_def,
   INIFile,
   iovalue,
   lec,
   log,
   MailMessage,
   MailPerson,
   Resources,
   SmtpClient,
   StringsO,
   Sync,
   TextReader,
   Texts;

(*================================================================================*)

CONST
   logPrefix = L"IBSCWSmtpClient";

TYPE
   TChannel = (
      chStatus    = 1,
      chServer    = 100,
      chLogin     = 101,
      chPassword  = 102,
      chSender    = 103,
      chReplyTo   = 104,
      chRecipient = 105,
      chSubject   = 106,
      chBody      = 107
   );

(*================================================================================*)

TYPE
   TPDriver = POINTER TO CDriver;

   TRStatusItem  = (
      rsRunning,
      rsEventsPending,
      rsValid,
      rsMailPending
   );
   TRStatus = SET OF TRStatusItem;

CONST
   rssUser = TRStatus{rsRunning, rsEventsPending, rsValid};
  
(*================================================================================*)

TYPE
   TEvent = (
      evUnknown,
      evSendSucceeded,
      evSendFailed
   );

   TEventData   = RECORD
                     MailId : CARDINAL;
                     CASE Event : TEvent OF
                     | evSendSucceeded :
                        // empty
                     | evSendFailed :
                        Result : Sync.TAsyncResult;
                        Phase : SmtpClient.TSmtpPhase;
                     END; // CASE
                  END; // RECORD
   TPEventData  = POINTER TO TEventData;

(*--------------------------------------------------------------------------------*)

CLASS CDriver IMPLEMENTS SmtpClient.INotifier, diface.ICWDriver;

   // INotifier
   PUBLIC VIRTUAL PROCEDURE OnMailMessageCompletion( Result : Sync.TAsyncResult; SmtpPhase : SmtpClient.TSmtpPhase; CONST message : MailMessage.TPMailMessage; CONST failedRecipientsList : MailPerson.TPPersons );

   // ICWDriver binding to procedural interface
   PUBLIC VIRTUAL PROCEDURE Initialize( RunMode : CARDINAL; CONST SymbolicName : StringsO.CString; CallbackId : ADDRESS; CallbackProc : drv_def.TDriverCallbackW );
   PUBLIC VIRTUAL PROCEDURE ReadParameters( CONST ParametersFilePath : StringsO.CString; CONST Logger : log.CLogger ) : BOOLEAN;
   PUBLIC VIRTUAL PROCEDURE QueryErrorCode( ErrorCode : CARDINAL; OUT ErrorText : StringsO.CString ) : BOOLEAN;
   PUBLIC VIRTUAL PROCEDURE EnumerateChannels( REF EnumerateState : LONGWORD; OUT Type : drv_def.TValueType; OUT Direction : drv_def.TDirection; OUT DriverIndex, Count : CARDINAL; OUT HaveDescription : BOOLEAN ) : BOOLEAN;
   PUBLIC VIRTUAL PROCEDURE GetChannelDescription( DriverIndex : CARDINAL; OUT Description : StringsO.CString; OUT Id : StringsO.CString ) : BOOLEAN;

   PUBLIC VIRTUAL PROCEDURE DriverRun();
   PUBLIC VIRTUAL PROCEDURE DriverStop();
   PUBLIC VIRTUAL PROCEDURE Dispose();

   PUBLIC VIRTUAL PROCEDURE DriverProc( Func, Param1, Param2, Param3, Param4 : CARDINAL );
   PUBLIC VIRTUAL PROCEDURE QueryProc( CONST InValue1, InValue2 : iovalue.Value; OutValueLimit : CARDINAL; OUT OutValue : iovalue.Value );

   PUBLIC VIRTUAL PROCEDURE InputRequestStart();
   PUBLIC VIRTUAL PROCEDURE InputRequest( DriverIndex : CARDINAL );
   PUBLIC VIRTUAL PROCEDURE InputRequestCompleted();
   PUBLIC VIRTUAL PROCEDURE InputFinalized( DriverIndex : CARDINAL; OUT ErrorCode : CARDINAL ) : BOOLEAN;
   PUBLIC VIRTUAL PROCEDURE InputOOBDataQuery( REF EnumerateState : LONGWORD; OUT DriverIndex : CARDINAL ) : BOOLEAN;
   PUBLIC VIRTUAL PROCEDURE GetInput( DriverIndex : CARDINAL; InValueLimit : CARDINAL; OUT InValue : iovalue.Value; OUT QoS : CARDINAL; OUT TimeStamp : drv_def.TUTCStamp; OUT ErrorCode : CARDINAL );

   PUBLIC VIRTUAL PROCEDURE OutputRequestStart();
   PUBLIC VIRTUAL PROCEDURE OutputRequest( DriverIndex : CARDINAL; CONST OutValue : iovalue.Value; QoS : CARDINAL; CONST TimeStamp : drv_def.TUTCStamp );
   PUBLIC VIRTUAL PROCEDURE OutputRequestCompleted();
   PUBLIC VIRTUAL PROCEDURE OutputFinalized( DriverIndex : CARDINAL; OUT ErrorCode : CARDINAL ) : BOOLEAN;

   // SELF
   PRIVATE VAR
      R                : Resources.CResources;
      RStatus          : TRStatus;
      Name             : StringsO.CString;
      Logger           : log.CLogger;

      CallbackId       : ADDRESS;
      CallbackProc     : drv_def.TDriverCallbackW;
      RunMode          : CARDINAL;
      Result           : lec.CResult;
      Events           : msgqueue.CPtrQueue;

      _Sender          : SmtpClient.TPSender;
      _ReplyTo         : StringsO.CString;
      _Sender          : StringsO.CString;
      _Recipient       : StringsO.CString;
      _Subject         : StringsO.CString;
      _Body            : StringsO.CString;

END CDriver;

(*================================================================================*)

CLASS IMPLEMENTATION CDriver;

(*--------------------------------------------------------------------------------*)

   PUBLIC VIRTUAL PROCEDURE OnMailMessageCompletion( Result : Sync.TAsyncResult; SmtpPhase : SmtpClient.TSmtpPhase; CONST message : MailMessage.TPMailMessage; CONST failedRecipientsList : MailPerson.TPPersons );
   BEGIN
   END OnMailMessageCompletion;

(*--------------------------------------------------------------------------------*)

   PUBLIC VIRTUAL PROCEDURE Initialize( _RunMode : CARDINAL; CONST SymbolicName : StringsO.CString; CallbackId : ADDRESS; CallbackProc : drv_def.TDriverCallbackW );
   BEGIN
      SELF.CallbackId := CallbackId;
      SELF.CallbackProc := CallbackProc;
      RunMode := _RunMode;
      Name := SymbolicName;
   END Initialize;

(*--------------------------------------------------------------------------------*)

   PUBLIC VIRTUAL PROCEDURE ReadParameters( CONST ParametersFilePath : StringsO.CString; CONST Logger : log.CLogger ) : BOOLEAN;
   LABEL
      Fail;
   CONST
      snDevice = L'IBSCWSmtpClient';

  //----------
  
      PROCEDURE Error( ErrorCode, ErrorLine : CARDINAL );
      BEGIN
         Logger.LogFilePos( log.lcError, 0, L"", OA( ParametersFilePath.Length-1, ParametersFilePath.Data ), OAsz( R[ ErrorCode ] ), ErrorLine, 0 );
      END Error;

  //----------

  VAR
    ErrorLine : CARDINAL;
    fs : FIOO.CFileStream;
    TS : INIFile.CINIFile;
    tr : TextReader.CTextReader;
  BEGIN
      TRY
         fs.FromPath( OA( ParametersFilePath.Length-1, ParametersFilePath.Data ), FIOO.imOpenRead );
      CATCH : IOO.CIOException DO
         Error( Texts._CannotOpenPar, 0 );
         GOTO Fail;
      END; // TRY
      tr.Stream := ADR( fs );
      IF NOT TS.Load( tr ) THEN
         Error( Texts._CannotOpenPar, 0 );
         GOTO Fail;
      END;
      fs.Close( FALSE );

      IF NOT TS.SetSection( snDevice ) THEN
         IF RunMode = drv_def.drmRun THEN
            Error( Texts._MissingDeviceSection, 0 );
            GOTO Fail;
         ELSE
            RETURN TRUE;
         END;
      END;

      CASE INIFile.ConfigureLog( TS, L"", REF SELF.Logger, OUT ErrorLine ) OF
      | INIFile.clrUnknownTarget :
         Error( Texts._UnknownDebugMode, ErrorLine );
      | INIFile.clrUnknownLevel :
         Error( Texts._UnknownDebugLevel, ErrorLine );
      | INIFile.clrTargetFileMissingFile :
         Error( Texts._FileDebugMissingFile, ErrorLine );
      END; // CASE
    
      RETURN TRUE;

   Fail:
      // remove temporary structures
      RETURN FALSE;
   END ReadParameters;

(*--------------------------------------------------------------------------------*)

   PUBLIC VIRTUAL PROCEDURE QueryErrorCode( ErrorCode : CARDINAL; OUT ErrorText : StringsO.CString ) : BOOLEAN;
   BEGIN
      CASE ErrorCode OF
      | ecDeviceStopped :
         ErrorText.FromOA( OAsz( R[ Texts._E_DeviceStopped ] ));
      ELSE
         RETURN FALSE;
      END; // CASE
      RETURN TRUE;
   END QueryErrorCode;

(*--------------------------------------------------------------------------------*)

   PUBLIC VIRTUAL PROCEDURE EnumerateChannels( REF EnumerateState : LONGWORD; OUT Type : drv_def.TValueType; OUT Direction : drv_def.TDirection; OUT DriverIndex, Count : CARDINAL; OUT HaveDescription : BOOLEAN ): BOOLEAN;
   BEGIN
      IF EnumerateState = 0 THEN
         // status channel
         Direction := drv_def.TDirection{drv_def.dirInput};
         DriverIndex := chStatus;
         Type := drv_def.vtLongCard;

      ELSE
         RETURN FALSE;
      END;

      Count := 1;
      HaveDescription := FALSE;
      INC( EnumerateState );

      RETURN TRUE;
   END EnumerateChannels;

(*--------------------------------------------------------------------------------*)

   PUBLIC VIRTUAL PROCEDURE GetChannelDescription( DriverIndex : CARDINAL; OUT Description : StringsO.CString; OUT Id : StringsO.CString ) : BOOLEAN;
   BEGIN
      RETURN FALSE;
   END GetChannelDescription;

(*--------------------------------------------------------------------------------*)

   PUBLIC VIRTUAL PROCEDURE DriverRun();
   VAR
      s : FIO.PathStrW;
   BEGIN
      IF TRStatus{rsRunning} * RStatus <> TRStatus{} THEN
         RETURN;
      END;
      INCL( RStatus, rsRunning );
      Mode := cmUnknown;

      Result.Reset( lec.bhBestCase );
      FIO.GetModuleDirW( EMITW( %dll ), OUT s );
      lec.QueryData( s, L"", ADR( cllv.data ), cllv.length, REF Result );
   END DriverRun;

(*--------------------------------------------------------------------------------*)

   PUBLIC VIRTUAL PROCEDURE DriverStop();
   BEGIN
      IF TRStatus{rsRunning} * RStatus = TRStatus{} THEN
         RETURN;
      END;
      
      Connection^.Close();
      IF ListeningSocket <> NIL THEN
         netsrv.StopListenSocket( REF ListeningSocket );
      END;      

      EXCL( RStatus, rsRunning );
   END DriverStop;

(*--------------------------------------------------------------------------------*)

   PUBLIC VIRTUAL PROCEDURE Dispose();
   VAR
      Event : POINTER TO TEventData;
   BEGIN
      WHILE Events.Dequeue( OUT Event ) DO
         DISPOSE( Event );
      END; // WHILE
   END Dispose;

(*--------------------------------------------------------------------------------*)

   PUBLIC VIRTUAL PROCEDURE QueryProc( CONST InValue1, InValue2 : iovalue.Value; OutValueLimit : CARDINAL; OUT OutValue : iovalue.Value );
   LABEL
      DoSend, Error, Success, DispatchFromServer;
   VAR
      c, l : CARDINAL;
      Event : POINTER TO TEventData;
      listenAddress : inetaddr.INETADDR;
      n : ARRAY [0..31] OF WCHAR;
      si : StringsO.CString;
      sw : StringsO.CString;
   BEGIN
      sw := InValue1.String;
      sw.ItemS( StringsO.WCHARS{ L' ' }, 0, 0, TRUE, OUT si );
      Result.Inc();

      IF si.EqualsOA( L'event' ) THEN
         sw.ItemS( StringsO.WCHARS{ L' ' }, 0, 1, TRUE, OUT si );

         IF si.EqualsOA( L'count' ) THEN
            c := Events.Count;
            Logger.LogSC( ldDebug, 0, logPrefix, L"Event.Count ", c );

            OutValue.Integer := c; 
            RETURN;
      
         ELSIF si.EqualsOA( L'get' ) THEN
            IF Result.Counted OR Result.Expired THEN
               Logger.LogS( ldDebug, 0, logPrefix, L"Event.Get clear buffer" );
               Events.Dispose();

               GOTO Success;

            ELSIF Events.Peek( OUT Event ) THEN
               Logger.LogSC( ldDebug, 0, logPrefix, L"Event.Peek ", CARDINAL( Event^.Event ));

               CASE Event^.Event OF
               //-----
               | evRxError :
                  sw.FromOA( L'rx_error' );
                  sw.AppendOA( Delimiter );
                  Strings.FromCARD32W( CARDINAL( Event^.ASCIIError ), 10, OUT n );
                  sw.AppendOA( n );
               //-----
               | evTxError :
                  sw.FromOA( L'tx_error' );
                  sw.AppendOA( Delimiter );
                  Strings.FromCARD32W( CARDINAL( Event^.ASCIIError ), 10, OUT n );
                  sw.AppendOA( n );
               //-----
               | evDriverError :
                  sw.FromOA( L'driver_error' );
                  sw.AppendOA( Delimiter );
                  Strings.FromCARD32W( CARDINAL( Event^.ASCIIError ), 10, OUT n );
                  sw.AppendOA( n );
               
               //-----
               | evConnect :
                  sw.FromOA( L'client_connect' );
                  sw.AppendOA( Delimiter );
                  Strings.FromCARD32W( Event^.NetError, 10, OUT n );
                  sw.AppendOA( n );
               //-----
               | evDisconnect :
                  IF Event^.Local THEN
                     sw.FromOA( L'client_disconnect' );
                  ELSE
                     sw.FromOA( L'server_disconnect' );
                  END;
                  sw.AppendOA( Delimiter );
                  Strings.FromCARD32W( Event^.NetError, 10, OUT n );
                  sw.AppendOA( n );
                  
                  Connection^.Close();
                  IF Mode = cmClient THEN
                     Mode := cmUnknown;
                  END;
               //-----
               | evAccept :
                  sw.FromOA( L'server_accept' );
                  sw.AppendOA( Delimiter );
                  Strings.FromCARD32W( Event^.NetError, 10, OUT n );
                  sw.AppendOA( n );

               //-----
               | evDataReceived :
                  sw.FromOA( L'server_data' );
                  sw.AppendOA( Delimiter );
                  Strings.FromCARD32W( Event^.Length, 10, OUT n );
                  sw.AppendOA( n );
               END;

               OutValue.String := sw;
               IF sw.Length < OutValueLimit THEN // OK
                  Events.Dequeue( OUT Event );
                  DISPOSE( Event );
               // ELSE // wait for longer string, leave event in queue
               END;
               RETURN;

            ELSE
               Logger.LogS( ldDebug, 0, logPrefix, L"Event.Emptied" );
            END; // IF Events.Dequeue

            GOTO Success;
        
         ELSE
            sw.FromOA( OAsz( R[ Texts._UnrecognizedEventCommand ] ));
            GOTO Error;
         END;

      ELSIF si.EqualsOA( L'server' ) THEN
         IF Mode = cmClient THEN
            Logger.LogS( dldDebug, logPrefix, L"Cmd.Server -- running as client" );

            sw.FromOA( OAsz( R[ Texts._StillRunningAsClient ] ));
            GOTO Error;
         END;
      
         sw.ItemS( StringsO.WCHARS{ L' ' }, 0, 1, TRUE, OUT si );

         IF si.EqualsOA( L'listen' ) THEN
            Logger.LogS( dldDebug, logPrefix, L"Cmd.Server.Listen" );

            Mode := cmServer;
            
            IF ListeningSocket <> NIL THEN
               sw.FromOA( OAsz( R[ Texts._AlreadyListening ] ));
               GOTO Error;
            END;
         
            sw.ItemS( StringsO.WCHARS{ L' ' }, 0, 2, TRUE, OUT si ); // port
            IF NOT si.ToCARD32( 10, OUT c ) THEN
               sw.FromOA( OAsz( R[ Texts._PortNotRecognized ] ));
               GOTO Error;
            END;

            listenAddress.Port := c;
            c := netsrv.StartListen( netsocket.stStream, listenAddress, NIL, ADR( Listener ), Sync.FOREVER, ADR( ListeningSocket ));
            IF c <> 0 THEN // listening error
               sw.FromOA( OAsz( R[ Texts._ListenError ] ));
               Strings.FromCARD32W( c, 10, OUT n );
               sw.AppendOA( L' ' );
               sw.AppendOA( n );
               GOTO Error;
            END;

         ELSIF si.EqualsOA( L'stop_listen' ) THEN
            Logger.LogS( dldDebug, logPrefix, L"Cmd.Server.StopListen" );

            netsrv.StopListenSocket( REF ListeningSocket );
            ServerConnection.Close(); // to be sure
            
            Mode := cmUnknown;

         ELSIF si.EqualsOA( L'disconnect' ) OR si.EqualsOA( L'send' ) OR si.EqualsOA( L'receive' ) OR si.EqualsOA( L'available' ) THEN
            // re-dispatch to client
            GOTO DispatchFromServer;

         ELSE
            sw.FromOA( OAsz( R[ Texts._UnrecognizedServerCommand ] ));
            GOTO Error;
         END;
         GOTO Success;

      ELSIF si.EqualsOA( L'client' ) THEN
         IF Mode = cmServer THEN
            Logger.LogS( dldDebug, logPrefix, L"Cmd.Server -- running as server" );

            sw.FromOA( OAsz( R[ Texts._StillRunningAsServer ] ));
            GOTO Error;
         END;
      
         sw.ItemS( StringsO.WCHARS{ L' ' }, 0, 1, TRUE, OUT si );

      DispatchFromServer:
         IF si.EqualsOA( L'connect' ) THEN
            Logger.LogS( dldDebug, logPrefix, L"Cmd.Server.Connect" );

            Mode := cmClient;
         
            IF ClientConnection.Connected THEN
               sw.FromOA( OAsz( R[ Texts._AlreadyConnected ] ));
               GOTO Error;
            END;
         
            sw.ItemS( StringsO.WCHARS{ L' ' }, 0, 2, TRUE, OUT si );
            ClientConnection.OpenS( si, FALSE, netsocket.FORSAFETY );

         ELSIF si.EqualsOA( L'disconnect' ) THEN
            Logger.LogS( dldDebug, logPrefix, L"Cmd.*.Disconnect" );

            Connection^.Close();
            IF Mode = cmClient THEN
               Mode := cmUnknown;
            END;

         ELSIF si.EqualsOA( L'send' ) THEN
            Logger.LogS( dldDebug, logPrefix, L"Cmd.*.Send" );

            IF NOT Connection^.Connected THEN
               sw.FromOA( OAsz( R[ Texts._NotConnected ] ));
               GOTO Error;
            END;
         
            sw.ItemS( StringsO.WCHARS{ L' ' }, 0, 2, TRUE, OUT si );

            l := WBuffer.Size - WBuffer.Length;
            IF si.Length MOD 2 = 1 THEN
               sw.FromOA( OAsz( R[ Texts._BadSendData ] ));
               GOTO Error;
            ELSIF si.Length DIV 2 > l THEN
               sw.FromOA( OAsz( R[ Texts._NotEnoughWriteSpace ] ));
               GOTO Error;
            ELSIF WBuffer.Length + si.Length DIV 2 > BufferedStream^.WriteSpace THEN
               sw.FromOA( OAsz( R[ Texts._NotEnoughWriteSpace ] ));
               GOTO Error;
            END;

            IF NOT cphcommon.FromHex( OA( si.Length-1, si.Data ), OUT OA( l-1, ADDRESS( WBuffer.Data@[WBuffer.Length] )), OUT c ) THEN
               sw.FromOA( OAsz( R[ Texts._BadCharacterInDataToSend ] ));
               GOTO Error;
            ELSE
               INC( WBuffer.Length, c );
               Connection^.Stream^.WriteBuffer( WBuffer, OUT c, netsocket.FORSAFETY );
               WBuffer.RemoveStart( c );
            END;

         ELSIF si.EqualsOA( L'receive' ) THEN
            Logger.LogS( dldDebug, logPrefix, L"Cmd.*.Receive" );

            RBufferLock.Lock();
            c := MIN2( OutValueLimit DIV 2, RBuffer.Length );
            l := c << 1;
            IF l > 0 THEN
               sw.Size := l;
               sw.Length := l;
               cphcommon.ToHex( OA( c-1, ADDRESS( RBuffer.Data )), OUT OA( l-1, PWCHAR( sw.Data )));
               RBuffer.RemoveStart( c );
            ELSE
               sw.Clear();
            END;
            RBufferLock.Unlock();
            
            OutValue.String := sw;
            RETURN;
         
         ELSIF si.EqualsOA( L'available' ) THEN
            c := RBuffer.Length;
            Logger.LogSC( ldDebug, 0, logPrefix, L"Cmd.*.Available ", c );

            OutValue.Integer := c; 
            RETURN;

         ELSE
            sw.FromOA( OAsz( R[ Texts._UnrecognizedClientCommand ] ));
            GOTO Error;
         END;
         GOTO Success;
         
      ELSIF ProcessASCIICommand( si, InValue2, OUT OutValue ) THEN
         RETURN;

      ELSE
         sw.FromOA( OAsz( R[ Texts._UnrecognizedCommand ] ));
      END;

   Error:
      OutValue.String := sw;
      RETURN;

   Success:
      sw.Clear();
      OutValue.String := sw;
   END QueryProc;

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
      Result.Inc(); // locked by self
   END InputRequest;

(*--------------------------------------------------------------------------------*)

   PUBLIC VIRTUAL PROCEDURE InputRequestCompleted();
   BEGIN
   END InputRequestCompleted;

(*--------------------------------------------------------------------------------*)

   PUBLIC VIRTUAL PROCEDURE InputFinalized( DriverIndex : CARDINAL; OUT ErrorCode : CARDINAL ) : BOOLEAN;
   BEGIN
      ErrorCode := 0;
      IF DriverIndex = chStatus THEN
         // return always OK
      ELSIF TRStatus{rsRunning} * RStatus = TRStatus{} THEN
         ErrorCode := ecDeviceStopped;
      ELSIF Result.Expired OR Result.Counted THEN // locked by self
         RETURN FALSE;
      ELSE
         ////
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
   BEGIN
      ErrorCode := drv_def.ecSuccess;
      QoS := drv_def.qosGood;

      IF DriverIndex = chStatus THEN
         IF Result.Counted OR Result.Expired THEN // locked by self
            EXCL( RStatus, rsValid );
         ELSE
            INCL( RStatus, rsValid );
         END;
         IF Events.Empty THEN
            EXCL( RStatus, rsEventsPending );
         ELSE
            INCL( RStatus, rsEventsPending );
         END;
         InValue.Integer := CARDINAL( RStatus * rssUser );

      ELSE
         ErrorCode := drv_def.ecUnknownElement;
      END;
   END GetInput;

(*--------------------------------------------------------------------------------*)

   PUBLIC VIRTUAL PROCEDURE OutputRequestStart();
   BEGIN
   END OutputRequestStart;

(*--------------------------------------------------------------------------------*)

   PUBLIC VIRTUAL PROCEDURE OutputRequest( DriverIndex : CARDINAL; CONST OutValue : iovalue.Value; QoS : CARDINAL; CONST TimeStamp : drv_def.TUTCStamp );
   BEGIN
      Result.Inc(); // locked by self
   END OutputRequest;

(*--------------------------------------------------------------------------------*)

  PUBLIC VIRTUAL PROCEDURE OutputRequestCompleted();
  BEGIN
  END OutputRequestCompleted;

(*--------------------------------------------------------------------------------*)

  PUBLIC VIRTUAL PROCEDURE OutputFinalized( DriverIndex : CARDINAL; OUT ErrorCode : CARDINAL ) : BOOLEAN;
  BEGIN
    ErrorCode := 0;
    RETURN NOT Result.Expired AND NOT Result.Counted; // locked by self
  END OutputFinalized;

(*--------------------------------------------------------------------------------*)

   PRIVATE PROCEDURE AddEvent( Event : POINTER TO TEventData );
   BEGIN
      Events.Enqueue( Event );
      IF Events.Produce^.State THEN
         Logger.LogSC( ldDebug, 0, logPrefix, L"Event.Queued, fire dcfException ", CARDINAL( Event^.Event ));
         CallbackProc( CallbackId, drv_def.dcfException, NIL );
      ELSE
         Logger.LogSC( ldDebug, 0, logPrefix, L"Event.Queued, NOT FIRED dcfException ", CARDINAL( Event^.Event ));
      END;
   END AddEvent;

(*--------------------------------------------------------------------------------*)

BEGIN
   // TODO
   R.LoadRES2( EMITW( %dll ), L'RemoteASCIIDrv.Texts' );
   R.Lang := Languages.GetDefaultLanguage( Languages.dlUser );
   RStatus := TRStatus{rsValid};
   RunMode := drv_def.drmEdit;
   CallbackId := NIL;
   CallbackProc := NIL;
   
   Events.Produce := Sync.CreateSignal( Sync.stEventAutoreset, L"", TRUE );
   LastError := erOK;
FINALLY
   Sync.DeleteSignal( REF Events.Produce );
END CDriver;

(*================================================================================*)

CLASS CFactory IMPLEMENTS diface.ICWDriverFactory;
   PRIVATE VAR
      R : Resources.CResources;
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
      Name.FromOA( OAsz( R[ Texts._DriverName ] ));
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

BEGIN
   R.LoadRES2( EMITW( %dll ), L'IBSCWSmtpClient.Texts' );
   R.Lang := Languages.GetDefaultLanguage( Languages.dlUser );
END CFactory;

(*--------------------------------------------------------------------------------*)

VAR
   Factory : CFactory;

(*--------------------------------------------------------------------------------*)

BEGIN
   diface.RegisterFactory( ADR( Factory ));
END driver.
