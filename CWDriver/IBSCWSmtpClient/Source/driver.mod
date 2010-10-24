MODULE driver;

(*# call( o_a_copy => off ) *)

(*================================================================================*)

FROM Storage IMPORT
  ALLOCATE, DEALLOCATE;

FROM Debug IMPORT
   Assertion, LogAssertionW;
  
FROM log IMPORT
  ldTrace, ldDebug, lcError;

FROM Exceptions IMPORT
   TestIfCatched;

IMPORT
   diface,
   drv_def,
   FIO,
   FIOO,
   INIFile,
   IOO,
   iovalue,
   Languages,
   lists,
   log,
   LogConfig,
   MailMessage,
   MailPerson,
   Resources,
   SmtpSender,
   StringsO,
   Sync,
   TextReader,
   Texts;

(*================================================================================*)

CONST
   logPrefix = L"IBSCWSmtpClient";

TYPE
   TChannel = (
      chStatus        = 1,
      chTrigger       = 2, // trigger
      chMessageStatus = 3, // tristate
      chErrorPhase    = 4,
      chServer        = 100,
      chLogin         = 101,
      chPassword      = 102,
      chFrom          = 103,
      chReplyTo       = 104,
      chRecipient     = 105,
      chSubject       = 106,
      chBody          = 107
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

CLASS CDriver IMPLEMENTS SmtpSender.INotifier, diface.ICWDriver;

   // INotifier
   PUBLIC VIRTUAL PROCEDURE OnMailMessageCompletion( Result : Sync.TAsyncResult; SmtpPhase : SmtpSender.TSmtpPhase; CONST message : MailMessage.TPMailMessage; userId : PTR; CONST failedRecipientsList : MailPerson.TPPersons );

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
   PRIVATE PROCEDURE PhaseToString( Phase : SmtpSender.TSmtpPhase ) : StringsO.CString;

   PRIVATE VAR
      R                : Resources.CResources;
      RStatus          : TRStatus := TRStatus{rsValid};
      Logger           : log.CLogger;
      AppenderList     : lists.CPtrList;

      CallbackId       : ADDRESS := NIL;
      CallbackProc     : drv_def.TDriverCallbackW := NIL;
      RunMode          : CARDINAL := drv_def.drmEdit;

      _Id              : CARDINAL := 0;
      _Sender          : SmtpSender.TPSender := NIL;
      _ReplyTo         : StringsO.CString;
      _From            : StringsO.CString;
      _Recipient       : StringsO.CString;
      _Subject         : StringsO.CString;
      _Body            : StringsO.CString;

      _MessagePending  : INT32 := Sync.ivNOTSET;
      _Result          : Sync.TAsyncResult := Sync.arUnknown;
      _Phase           : SmtpSender.TSmtpPhase := SmtpSender.ClientConnect;

END CDriver;

(*================================================================================*)

CLASS IMPLEMENTATION CDriver;

(*--------------------------------------------------------------------------------*)

   PUBLIC VIRTUAL PROCEDURE OnMailMessageCompletion( Result : Sync.TAsyncResult; SmtpPhase : SmtpSender.TSmtpPhase; CONST message : MailMessage.TPMailMessage; userId : PTR; CONST failedRecipientsList : MailPerson.TPPersons );
   BEGIN
      Sync.IExchg( REF _MessagePending, Sync.ivNOTSET );
      _Result := Result;
      _Phase := SmtpPhase;

      Logger.LogSR( ldTrace, 0, logPrefix, L"Mail completed, fire dcfException ", Result );
      CallbackProc( CallbackId, drv_def.dcfException, NIL );
   END OnMailMessageCompletion;

(*--------------------------------------------------------------------------------*)

   PUBLIC VIRTUAL PROCEDURE Initialize( _RunMode : CARDINAL; CONST SymbolicName : StringsO.CString; CallbackId : ADDRESS; CallbackProc : drv_def.TDriverCallbackW );
   BEGIN
      SELF.CallbackId := CallbackId;
      SELF.CallbackProc := CallbackProc;
      RunMode := _RunMode;
      Logger.SetName( OA( SymbolicName.Length-1, SymbolicName.Data ));
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
      LogConfig.DisposeAppenderList( REF AppenderList );

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

      CASE LogConfig.ConfigureLog( TS, L"", REF SELF.Logger, REF AppenderList, OUT ErrorLine ) OF
      | LogConfig.clrUnknownTarget :
         Error( Texts._UnknownDebugMode, ErrorLine );
      | LogConfig.clrUnknownLevel :
         Error( Texts._UnknownDebugLevel, ErrorLine );
      | LogConfig.clrTargetFileMissingFile :
         Error( Texts._FileDebugMissingFile, ErrorLine );
      ELSE // OK
         RETURN TRUE;
      END; // CASE

   Fail:
      // remove temporary structures
      RETURN FALSE;
   END ReadParameters;

(*--------------------------------------------------------------------------------*)

   PUBLIC VIRTUAL PROCEDURE QueryErrorCode( ErrorCode : CARDINAL; OUT ErrorText : StringsO.CString ) : BOOLEAN;
   BEGIN
      RETURN FALSE;
   END QueryErrorCode;

(*--------------------------------------------------------------------------------*)

   PUBLIC VIRTUAL PROCEDURE EnumerateChannels( REF EnumerateState : LONGWORD; OUT Type : drv_def.TValueType; OUT Direction : drv_def.TDirection; OUT DriverIndex, Count : CARDINAL; OUT HaveDescription : BOOLEAN ): BOOLEAN;
   BEGIN
      CASE CARDINAL( EnumerateState ) OF
      | 0 : // status channel
         Direction := drv_def.TDirection{drv_def.dirInput};
         DriverIndex := CARDINAL( chStatus );
         Type := drv_def.vtLongCard;
      | 1 : // message trigger
         Direction := drv_def.TDirection{drv_def.dirOutput};
         DriverIndex := CARDINAL( chTrigger );
         Type := drv_def.vtBoolean;
      | 2 : // message status
         Direction := drv_def.TDirection{drv_def.dirInput};
         DriverIndex := CARDINAL( chMessageStatus );
         Type := drv_def.vtLongInt;
      | 3 : // error phase
         Direction := drv_def.TDirection{drv_def.dirInput};
         DriverIndex := CARDINAL( chErrorPhase );
         Type := drv_def.vtDString;
      | 4 : // server address
         Direction := drv_def.TDirection{drv_def.dirInput, drv_def.dirOutput};
         DriverIndex := CARDINAL( chServer );
         Type := drv_def.vtDString;
      | 5 : // server login
         Direction := drv_def.TDirection{drv_def.dirInput, drv_def.dirOutput};
         DriverIndex := CARDINAL( chLogin );
         Type := drv_def.vtDString;
      | 6 : // server password
         Direction := drv_def.TDirection{drv_def.dirInput, drv_def.dirOutput};
         DriverIndex := CARDINAL( chPassword );
         Type := drv_def.vtDString;
      | 7 : // from
         Direction := drv_def.TDirection{drv_def.dirInput, drv_def.dirOutput};
         DriverIndex := CARDINAL( chFrom );
         Type := drv_def.vtDString;
      | 8 : // reply-to
         Direction := drv_def.TDirection{drv_def.dirInput, drv_def.dirOutput};
         DriverIndex := CARDINAL( chReplyTo );
         Type := drv_def.vtDString;
      | 9 : // recipient
         Direction := drv_def.TDirection{drv_def.dirInput, drv_def.dirOutput};
         DriverIndex := CARDINAL( chRecipient );
         Type := drv_def.vtDString;
      | 10 : // subject
         Direction := drv_def.TDirection{drv_def.dirInput, drv_def.dirOutput};
         DriverIndex := CARDINAL( chSubject );
         Type := drv_def.vtDString;
      | 11 : // message body
         Direction := drv_def.TDirection{drv_def.dirInput, drv_def.dirOutput};
         DriverIndex := CARDINAL( chBody );
         Type := drv_def.vtDString;
      ELSE
         RETURN FALSE;
      END;

      Count := 1;
      HaveDescription := TRUE;
      INC( EnumerateState );

      RETURN TRUE;
   END EnumerateChannels;

(*--------------------------------------------------------------------------------*)

   PUBLIC VIRTUAL PROCEDURE GetChannelDescription( DriverIndex : CARDINAL; OUT Description : StringsO.CString; OUT Id : StringsO.CString ) : BOOLEAN;
   BEGIN
      CASE TChannel( DriverIndex ) OF
      | chStatus :
         Description.FromOA( OAsz( R[ Texts.ChannelStatusDescription ] ));
      | chTrigger :
         Description.FromOA( OAsz( R[ Texts.ChannelTriggerDescription ] ));
      | chMessageStatus :
         Description.FromOA( OAsz( R[ Texts.ChannelMessageStatusDescription ] ));
      | chErrorPhase :
         Description.FromOA( OAsz( R[ Texts.ChannelErrorPhaseDescription ] ));
      | chServer :
         Description.FromOA( OAsz( R[ Texts.ChannelServerDescription ] ));
      | chLogin :
         Description.FromOA( OAsz( R[ Texts.ChannelLoginDescription ] ));
      | chPassword :
         Description.FromOA( OAsz( R[ Texts.ChannelPasswordDescription ] ));
      | chFrom :
         Description.FromOA( OAsz( R[ Texts.ChannelFromDescription ] ));
      | chReplyTo :
         Description.FromOA( OAsz( R[ Texts.ChannelReplyToDescription ] ));
      | chRecipient :
         Description.FromOA( OAsz( R[ Texts.ChannelRecipientDescription ] ));
      | chSubject :
         Description.FromOA( OAsz( R[ Texts.ChannelSubjectDescription ] ));
      | chBody :
         Description.FromOA( OAsz( R[ Texts.ChannelBodyDescription ] ));
      ELSE
         RETURN FALSE;
      END; // CASE
      Id.Clear();
      RETURN TRUE;
   END GetChannelDescription;

(*--------------------------------------------------------------------------------*)

   PUBLIC VIRTUAL PROCEDURE DriverRun();
   BEGIN
      IF TRStatus{rsRunning} * RStatus <> TRStatus{} THEN
         RETURN;
      END;
      INCL( RStatus, rsRunning );

      ASSERTLOG( _Sender = NIL, L"Sender already (unexpectedly) exists" );
      IF SmtpSender.New( OUT _Sender, FALSE, FALSE ) THEN
         _Sender^.Notifier := ADR( SELF );
         _Sender^.Logger := ADR( Logger );
         _Sender^.TimeToLive := 0; // immediately remove the message from the queue, if anything fails
      ELSE
         EXCL( RStatus, rsRunning );
         ASSERTLOG( FALSE, L"Unable to create sender" );
      END;
   END DriverRun;

(*--------------------------------------------------------------------------------*)

   PUBLIC VIRTUAL PROCEDURE DriverStop();
   BEGIN
      IF TRStatus{rsRunning} * RStatus = TRStatus{} THEN
         RETURN;
      END;
      EXCL( RStatus, rsRunning );

      IF _Sender <> NIL THEN
         SmtpSender.Dispose( REF _Sender );
      END;
   END DriverStop;

(*--------------------------------------------------------------------------------*)

   PUBLIC VIRTUAL PROCEDURE Dispose();
   BEGIN
      LogConfig.DisposeAppenderList( REF AppenderList );
   END Dispose;

(*--------------------------------------------------------------------------------*)

   PUBLIC VIRTUAL PROCEDURE QueryProc( CONST InValue1, InValue2 : iovalue.Value; OutValueLimit : CARDINAL; OUT OutValue : iovalue.Value );
   BEGIN
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
   END InputRequest;

(*--------------------------------------------------------------------------------*)

   PUBLIC VIRTUAL PROCEDURE InputRequestCompleted();
   BEGIN
   END InputRequestCompleted;

(*--------------------------------------------------------------------------------*)

   PUBLIC VIRTUAL PROCEDURE InputFinalized( DriverIndex : CARDINAL; OUT ErrorCode : CARDINAL ) : BOOLEAN;
   BEGIN
      ErrorCode := 0;
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

      CASE TChannel( DriverIndex ) OF
      | chStatus :
         INCL( RStatus, rsValid );
         IF Sync.IGet( REF _MessagePending ) = Sync.ivSET THEN
            INCL( RStatus, rsMailPending );
         ELSE
            EXCL( RStatus, rsMailPending );
         END;
         InValue.Integer := CARDINAL( RStatus * rssUser );

      | chMessageStatus :
         IF Sync.IGet( REF _MessagePending ) = Sync.ivSET THEN
            InValue.Tristate := -1;
         ELSIF _Result = Sync.arCompleted THEN
            InValue.Tristate := 1;
         ELSE
            InValue.Tristate := 0;
         END;

      | chErrorPhase :
         IF Sync.IGet( REF _MessagePending ) = Sync.ivSET THEN
            InValue.String := StringsO.Empty();
         ELSIF _Result = Sync.arCompleted THEN // finished without an error
            InValue.String := StringsO.Empty();
         ELSE
            InValue.String := PhaseToString( _Phase );
         END;

      | chServer :
         InValue.String := _Sender^.Server;

      | chLogin :
         InValue.String := _Sender^.Login;

      | chPassword :
         InValue.String := _Sender^.Password;

      | chFrom :
         InValue.String := _From;

      | chReplyTo :
         InValue.String := _ReplyTo;

      | chRecipient :
         InValue.String := _Recipient;

      | chSubject :
         InValue.String := _Subject;

      | chBody :
         InValue.String := _Body;

      ELSE
         ErrorCode := drv_def.ecUnknownElement;
      END; // CASE
   END GetInput;

(*--------------------------------------------------------------------------------*)

   PUBLIC VIRTUAL PROCEDURE OutputRequestStart();
   BEGIN
   END OutputRequestStart;

(*--------------------------------------------------------------------------------*)

   PUBLIC VIRTUAL PROCEDURE OutputRequest( DriverIndex : CARDINAL; CONST OutValue : iovalue.Value; QoS : CARDINAL; CONST TimeStamp : drv_def.TUTCStamp );
   VAR
      c : CARDINAL;
      message : MailMessage.TPMailMessage;
      person : MailPerson.Person;
      result : Sync.TAsyncResult;
   BEGIN
      CASE TChannel( DriverIndex ) OF
      | chTrigger :
         IF Sync.IGet( REF _MessagePending ) = Sync.ivSET THEN // the message is still pending
            Logger.LogS( ldTrace, 0, logPrefix, L"Mail cannot be send, another mail is still pending" );
            RETURN;

         ELSIF NOT MailMessage.New( OUT message ) THEN
            _Result := Sync.arCannotStart;
            _Phase := SmtpSender.MessageCreation;

            Logger.LogS( ldTrace, 0, logPrefix, L"Mail send failed, unable to create message" );
            CallbackProc( CallbackId, drv_def.dcfException, NIL ); // notify about the failure
            RETURN;
         END;

         Sync.IExchg( REF _MessagePending, Sync.ivSET );

         person.Address := _From; message^.Sender := person;
         person.Address := _Recipient; message^.Recipient := person;
         person.Address := _ReplyTo; message^.ReplyTo := person;
         message^.Subject := _Subject;
         result := message^.Body^.WriteOA( OA( SIZE( WCHAR ) * _Body.Length-1, _Body.Data ), OUT c, Sync.FORSAFETY );
         IF result <> Sync.arCompleted THEN
            Sync.IExchg( REF _MessagePending, Sync.ivNOTSET );
            _Result := result;
            _Phase := SmtpSender.MessageCreation;
            MailMessage.Dispose( REF message );

            Logger.LogSR( ldTrace, 0, logPrefix, L"Mail send failed, unable to write body of the mail", result );
            CallbackProc( CallbackId, drv_def.dcfException, NIL ); // notify about the failure
            RETURN;
         END;
            
         INC( _Id );
         result := _Sender^.Send( message, _Id, TRUE );
         IF result IN Sync.arsStarts THEN
            Logger.LogS( ldDebug, 0, logPrefix, L"Mail queued" );

         ELSE
            Sync.IExchg( REF _MessagePending, Sync.ivNOTSET );
            _Result := result; // failed
            _Phase := SmtpSender.MessageValidation;
            MailMessage.Dispose( REF message );

            Logger.LogSR( ldTrace, 0, logPrefix, L"Mail send failed, Sender has rejected it", result );
            CallbackProc( CallbackId, drv_def.dcfException, NIL ); // notify about the failure
         END;

      | chServer :
         _Sender^.Server := OutValue.String;

      | chLogin :
         _Sender^.Login := OutValue.String;

      | chPassword :
         _Sender^.Password := OutValue.String;

      | chFrom :
         _From := OutValue.String;

      | chReplyTo :
         _ReplyTo := OutValue.String;

      | chRecipient :
         _Recipient := OutValue.String;

      | chSubject :
         _Subject := OutValue.String;

      | chBody :
         _Body := OutValue.String;

      END; // CASE
   END OutputRequest;

(*--------------------------------------------------------------------------------*)

  PUBLIC VIRTUAL PROCEDURE OutputRequestCompleted();
  BEGIN
  END OutputRequestCompleted;

(*--------------------------------------------------------------------------------*)

  PUBLIC VIRTUAL PROCEDURE OutputFinalized( DriverIndex : CARDINAL; OUT ErrorCode : CARDINAL ) : BOOLEAN;
  BEGIN
    ErrorCode := 0;
    RETURN TRUE;
  END OutputFinalized;

(*--------------------------------------------------------------------------------*)

   PRIVATE PROCEDURE PhaseToString( Phase : SmtpSender.TSmtpPhase ) : StringsO.CString;
   BEGIN
      CASE Phase OF
      | SmtpSender.MessageCreation :
         RETURN StringsO.FromOA( OAsz( R[ Texts.SmtpPhaseMessageCreation ] ));
      | SmtpSender.MessageValidation :
         RETURN StringsO.FromOA( OAsz( R[ Texts.SmtpPhaseMessageValidation ] ));
      | SmtpSender.ClientConnect :
         RETURN StringsO.FromOA( OAsz( R[ Texts.SmtpPhaseClientConnect ] ));
      | SmtpSender.ServerConnect :
         RETURN StringsO.FromOA( OAsz( R[ Texts.SmtpPhaseServerConnect ] ));
      | SmtpSender.Ehlo :
         RETURN StringsO.FromOA( OAsz( R[ Texts.SmtpPhaseEhlo ] ));
      | SmtpSender.AuthenticationFailed :
         RETURN StringsO.FromOA( OAsz( R[ Texts.SmtpPhaseAuthenticationFailed ] ));
      | SmtpSender.AuthenticationRequired :
         RETURN StringsO.FromOA( OAsz( R[ Texts.SmtpPhaseAuthenticationRequired ] ));
      | SmtpSender.MailFrom :
         RETURN StringsO.FromOA( OAsz( R[ Texts.SmtpPhaseMailFrom ] ));
      | SmtpSender.RcptTo :
         RETURN StringsO.FromOA( OAsz( R[ Texts.SmtpPhaseRcptTo ] ));
      | SmtpSender.RecipientsRejected :
         RETURN StringsO.FromOA( OAsz( R[ Texts.SmtpPhaseRecipientsRejected ] ));
      | SmtpSender.StartData :
         RETURN StringsO.FromOA( OAsz( R[ Texts.SmtpPhaseStartData ] ));
      | SmtpSender.Headers :
         RETURN StringsO.FromOA( OAsz( R[ Texts.SmtpPhaseHeaders ] ));
      | SmtpSender.MessageBody :
         RETURN StringsO.FromOA( OAsz( R[ Texts.SmtpPhaseMessageBody ] ));
      | SmtpSender.MessageAttachments :
         RETURN StringsO.FromOA( OAsz( R[ Texts.SmtpPhaseMessageAttachments ] ));
      | SmtpSender.MessageFinalization :
         RETURN StringsO.FromOA( OAsz( R[ Texts.SmtpPhaseMessageFinalization ] ));
      | SmtpSender.ConnectionFinalization :
         RETURN StringsO.FromOA( OAsz( R[ Texts.SmtpPhaseConnectionFinalization ] ));
      ELSE
         ASSERTLOG( FALSE, L"Unrecognized SMTP phase " );
         RETURN StringsO.Empty();
      END;
   END PhaseToString;

(*--------------------------------------------------------------------------------*)

BEGIN
   R.LoadRES2( EMITW( %dll ), L'IBSCWSmtpClient.Texts' );
   R.Lang := Languages.GetDefaultLanguage( Languages.dlUser );
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
