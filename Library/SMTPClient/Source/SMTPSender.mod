IMPLEMENTATION MODULE SMTPSender;

FROM Storage IMPORT
   ALLOCATE, DEALLOCATE;

FROM Debug IMPORT
   Assertion, LogAssertionW;

FROM Exceptions IMPORT
   StoreException, RetrieveException, TestIfCatched;

IMPORT
   dns,
   Exceptions,
   msgqueue,
   netsocket,
   rawconnection,
   StringsO,
   TextReader,
   TextWriter,
   threadpool;

(*================================================================================*)

TYPE
   TSmtpResponse = (
      smtpres_Unknown = 0,

      smtpres_211 = 211,
      smtpres_214 = 214,
      smtpres_220 = 220,
      smtpres_221 = 221,
      smtpres_235 = 235,
      smtpres_250 = 250,
         smtpres_OK = smtpres_250,
      smtpres_251 = 251,
      smtpres_334 = 334,
      smtpres_354 = 354,
      smtpres_421 = 421,
      smtpres_432 = 432,
      smtpres_450 = 450,
      smtpres_451 = 451,
      smtpres_452 = 452,
      smtpres_454 = 454,
      smtpres_500 = 500,
         smtpres_Failure = smtpres_500,
      smtpres_501 = 501,
      smtpres_502 = 502,
      smtpres_503 = 503,
      smtpres_504 = 504,
      smtpres_521 = 521,
      smtpres_530 = 530,
      smtpres_534 = 534,
      smtpres_535 = 535,
      smtpres_538 = 538,
      smtpres_550 = 550,
      smtpres_551 = 551,
      smtpres_552 = 552,
      smtpres_553 = 553,
      smtpres_554 = 554
   );

   TSmtpError = (
      ConnectFailed,
      ServerNotReady,
      EhloPhase,
      AuthenticationFailed,
      AuthenticationRequired,
      MailFrom,
      Headers,
      MessageBody
   );

(*================================================================================*)

CLASS CSmtpException( Exceptions.CGenericException );

   PUBLIC READONLY PROPERTY
      Result : Sync.TAsyncResult;

END CSmtpException;

(*--------------------------------------------------------------------------------*)

CLASS IMPLEMENTATION CSmtpException;

(*--------------------------------------------------------------------------------*)

   PUBLIC PROPERTY Result GET : Sync.TAsyncResult;
   BEGIN
      RETURN Sync.TAsyncResult( Code );
   END Result;

(*--------------------------------------------------------------------------------*)

END CSmtpException;

(*--------------------------------------------------------------------------------*)

PROCEDURE SmtpException( Result : Sync.TAsyncResult ) : CSmtpException;
VAR
   exception : CSmtpException;
BEGIN
   exception.Init( CARDINAL( Result ), NIL, L"SmtpSender", L"" );
   RETURN exception;
END SmtpException;

(*================================================================================*)

TYPE
   TPSenderImpl = POINTER TO CSender;

CLASS CSender( threadpool.APoolDelegate ) IMPLEMENTS ISender;

   // APoolDelegate
   LOCAL VIRTUAL PROCEDURE OnHandle( Result : Sync.TAsyncResult; PoolHandle : threadpool.TPoolHandle; UserId : PTR );

   // ISender
   PUBLIC VIRTUAL PROPERTY
      Dispatcher : threadcall.TPIThreadProcedureCallDispatcher; // default NIL, which means notifier is called directly from network thread
      Notifier : TPNotifier;

   PUBLIC VIRTUAL PROCEDURE SendAsync( CONST message : MailMessage.TPMailMessage; takeOwnership : BOOLEAN ) : Sync.TAsyncResult; // returns failure only if Server is empty

   PUBLIC VIRTUAL PROPERTY
      Server : StringsO.CString;
      Mailer : StringsO.CString;
      Login : StringsO.CString; 
      Password : StringsO.CString; 
      TimeToLive : CARDINAL; // milliseconds, the message will stay in the queue for the time

   // SELF
   LOCAL READONLY PROPERTY
      LocalName : StringsO.CString;

   LOCAL PROCEDURE NotifyCompletion( CONST message : MailMessage.TPMailMessage; Result : Sync.TAsyncResult; SmtpError : TSmtpError );
   PRIVATE PROCEDURE Send();

   PRIVATE VAR
      _Server : StringsO.CString;
      _Mailer : StringsO.CString;
      _Login : StringsO.CString; 
      _Password : StringsO.CString; 
      _LocalName : StringsO.CString;
      _QueueSignal : Sync.SIGNAL;
      _Queue : msgqueue.CPtrQueue;
      _PoolHandle : threadpool.TPoolHandle := NIL;
      _Pending : CARDINAL := 0; // ILocked
      _Pool : threadpool.CThreadPool;
      _PendingSends : CARDINAL := 0;
      _TimeToLive : CARDINAL := 2*86400; // two days
      _Dispatcher : threadcall.TPIThreadProcedureCallDispatcher := NIL;
      _Notifier : TPNotifier := NIL;

END CSender;

(*--------------------------------------------------------------------------------*)

CLASS CWorker( threadpool.APoolWorker );

   // APoolWorker
   LOCAL VIRTUAL PROCEDURE Run();

   // SELF
   PUBLIC PROCEDURE Init( sender : TPSenderImpl; CONST message : MailMessage.TPMailMessage );

   PRIVATE VAR
      _Sender : TPSenderImpl := NIL;
      _Message : MailMessage.TPMailMessage := NIL;
      _Connection : rawconnection.ClientTCPConnection;
      _Reader : TextReader.CTextReader;
      _Writer : TextWriter.CTextWriter;

   PRIVATE PROCEDURE DoSend( OUT SmtpError : TSmtpError ) : Sync.TAsyncResult;
   PRIVATE PROCEDURE NotifyCompletion( Result : Sync.TAsyncResult; SmtpError : TSmtpError );

   PRIVATE PROCEDURE ReadServer() : TSmtpResponse THROWS CSmtpException;
   PRIVATE PROCEDURE ReadServerLine( OUT SMTPResponse : TSmtpResponse; OUT Response : StringsO.IString; OUT LastLine : BOOLEAN ) : Sync.TAsyncResult;
   PRIVATE PROCEDURE WriteServer( CONST Line : StringsO.IString ) THROWS CSmtpException;
   PRIVATE PROCEDURE WriteServerBase64( CONST Line : StringsO.IString ) THROWS CSmtpException;
   PRIVATE PROCEDURE WriteRecipients( recipients : MailMessage.TPPersons ) THROWS CSmtpException; // TODO distinguish between complete send and send only some, grab failures to some list or so

END CWorker;

(*================================================================================*)

CLASS IMPLEMENTATION CWorker;

(*--------------------------------------------------------------------------------*)

   LOCAL VIRTUAL PROCEDURE Run();
   VAR
      Result : Sync.TAsyncResult;
      SmtpError : TSmtpError := ConnectFailed;
   BEGIN
      Result := _Connection.OpenS( _Sender^.Server, TRUE, netsocket.FORSAFETY );

      IF Result = Sync.arCompleted THEN
         Result := DoSend( OUT SmtpError );
      END;

      NotifyCompletion( Result, SmtpError );
   END Run;

(*--------------------------------------------------------------------------------*)

   PUBLIC PROCEDURE Init( sender : TPSenderImpl; CONST message : MailMessage.TPMailMessage );
   BEGIN
      _Sender := sender;
      _Message := message;
   END Init;

(*--------------------------------------------------------------------------------*)

   PRIVATE PROCEDURE DoSend( OUT SmtpError : TSmtpError ) : Sync.TAsyncResult;
   VAR
      recipients : MailMessage.TPPersons;
      Result : Sync.TAsyncResult;
      s : StringsO.CString;
      smtpres : TSmtpResponse;
   BEGIN
      TRY
         //----------
         SmtpError := ServerNotReady;

         IF ReadServer() <> smtpres_220 THEN
            THROW SmtpException( Sync.arAborted );
         END;

         //----------
         SmtpError := EhloPhase;

         s.FromOA( L"EHLO " );
         s.Append( _Sender^.LocalName );
         WriteServer( s );
         IF ReadServer() <> smtpres_OK THEN
            THROW SmtpException( Sync.arAborted );
         END;

         //----------
         IF NOT _Sender^.Login.Empty THEN

            SmtpError := AuthenticationFailed;

            s.FromOA( L"AUTH LOGIN" );
            WriteServer( s );
            IF ReadServer() <> smtpres_334 THEN // TODO: check if "UserName" is requested
               THROW SmtpException( Sync.arAborted );
            END;
            // send login
            WriteServerBase64( _Sender^.Login );
            IF ReadServer() <> smtpres_334 THEN // TODO: check if "Password" is requested
               THROW SmtpException( Sync.arAborted );
            END;
            // send password
            WriteServerBase64( _Sender^.Password );
            smtpres := ReadServer();
            CASE smtpres OF
            | smtpres_235 : // OK, success
            | smtpres_535 : // not authorized
               THROW SmtpException( Sync.arFailed );
            ELSE
               THROW SmtpException( Sync.arAborted );
            END;
         END;

         //----------
         SmtpError := MailFrom;

         // TODO, MailFrom nesmí být empty
         s.FromOA( L"MAIL FROM: " );
         s.Append( _Message^.Sender.Address );
         WriteServer( s );
         smtpres := ReadServer();
         CASE smtpres OF
         | smtpres_OK : // OK, success
         | smtpres_530 : // authentication required
            SmtpError := AuthenticationRequired;
            THROW SmtpException( Sync.arFailed );
         ELSE
            THROW SmtpException( Sync.arAborted );
         END;

         //----------
         SmtpError := SmtpErrorRcptTo;

         // TODO, at least one recipient must be known
         WriteRecipients( _Message^.Recipients );
         WriteRecipients( _Message^.CCs );
         WriteRecipients( _Message^.BCCs );

         //----------
         SmtpError := SmtpErrorData;

         s.FromOA( L"DATA" );
         WriteServer( s );
         IF ReadServer() <> smtpresult_354 THEN
            THROW SmtpException( Sync.arAborted );
         END;

         //----------
         SmtpError := SmtpErrorHeaders;

         WriteHeaders();

         //----------
         SmtpError := MessageBody;

         WriteStream( _Message^.Stream );

         //----------
         SmtpError := SmtpErrorAttachments;

         IF NOT _Message.Attachments.Empty THEN
         END;

         //----------
         SmtpError := SmtpErrorMessageFinalization;

         s.FromOA( 13W + 10W + L"." + 13W + 10W );
         WriteServer( s );
         IF ReadServer() <> smtpresult_OK THEN
            THROW SmtpException( Sync.arAborted );
         END;

         //----------
         SmtpError := SmtpErrorConnectionFinalization;

         s.FromOA( L"QUIT" );
         Result := WriteServer( s );
         IF ReadServer() <> smtpresult_OK THEN
            THROW SmtpException( Sync.arAborted );
         END;

(*   
      // next goes attachments (if they are)
      if((FileBuf = new char[55]) == NULL)
         throw ECSmtp(ECSmtp::LACK_OF_MEMORY);

      if((FileName = new char[255]) == NULL)
         throw ECSmtp(ECSmtp::LACK_OF_MEMORY);

      TotalSize = 0;
      for(FileId=0;FileId<Attachments.size();FileId++)
      {
         strcpy(FileName,Attachments[FileId].c_str());

         sprintf(SendBuf,"--%s\r\n",BOUNDARY_TEXT);
         strcat(SendBuf,"Content-Type: application/x-msdownload; name=\"");
         strcat(SendBuf,&FileName[Attachments[FileId].find_last_of("\\") + 1]);
         strcat(SendBuf,"\"\r\n");
         strcat(SendBuf,"Content-Transfer-Encoding: base64\r\n");
         strcat(SendBuf,"Content-Disposition: attachment; filename=\"");
         strcat(SendBuf,&FileName[Attachments[FileId].find_last_of("\\") + 1]);
         strcat(SendBuf,"\"\r\n");
         strcat(SendBuf,"\r\n");

         SendData();

         // opening the file:
         hFile = fopen(FileName,"rb");
         if(hFile == NULL)
            throw ECSmtp(ECSmtp::FILE_NOT_EXIST);
      
         // checking file size:
         FileSize = 0;
         while(!feof(hFile))
            FileSize += fread(FileBuf,sizeof(char),54,hFile);
         TotalSize += FileSize;

         // sending the file:
         if(TotalSize/1024 > MSG_SIZE_IN_MB*1024)
            throw ECSmtp(ECSmtp::MSG_TOO_BIG);
         else
         {
            fseek (hFile,0,SEEK_SET);

            MsgPart = 0;
            for(i=0;i<FileSize/54+1;i++)
            {
               res = fread(FileBuf,sizeof(char),54,hFile);
               MsgPart ? strcat(SendBuf,base64_encode(reinterpret_cast<const unsigned char*>(FileBuf),res).c_str())
                        : strcpy(SendBuf,base64_encode(reinterpret_cast<const unsigned char*>(FileBuf),res).c_str());
               strcat(SendBuf,"\r\n");
               MsgPart += res + 2;
               if(MsgPart >= BUFFER_SIZE/2)
               { // sending part of the message
                  MsgPart = 0;
                  SendData(); // FileBuf, FileName, fclose(hFile);
               }
            }
            if(MsgPart)
            {
               SendData(); // FileBuf, FileName, fclose(hFile);
            }
         }
         fclose(hFile);
      }
      delete[] FileBuf;
      delete[] FileName;
   
      // sending last message block (if there is one or more attachments)
      if(Attachments.size())
      {
         sprintf(SendBuf,"\r\n--%s--\r\n",BOUNDARY_TEXT);
         SendData();
      }
*)

      CATCH e : CSmtpException DO
         RETURN e.Result;
      END;
   
      RETURN Sync.arCompleted;
   END DoSend;

(*--------------------------------------------------------------------------------*)

   PRIVATE PROCEDURE NotifyCompletion( Result : Sync.TAsyncResult; SmtpError : TSmtpError );
   BEGIN
      // _Sender^.NotifyCompletion( _Message, Result, SmtpError );
   END NotifyCompletion;

(*--------------------------------------------------------------------------------*)

   PRIVATE PROCEDURE ReadServer() : TSmtpResponse;
   VAR
      current : TSmtpResponse := smtpres_Unknown;
      first : TSmtpResponse := smtpres_Unknown;
      lastline : BOOLEAN := FALSE;
      line : StringsO.CString;
      Result : Sync.TAsyncResult;
   BEGIN
      REPEAT
         Result := ReadServerLine( OUT current, OUT line, OUT lastline );
         IF Result <> Sync.arCompleted THEN
            THROW SmtpException( Result );
         ELSIF first = smtpres_Unknown THEN
            first := current;
         ELSIF current <> first THEN // responses must be uniform for single command
            THROW SmtpException( Sync.arAborted );
         END;
      UNTIL lastline;

      RETURN current;
   END ReadServer;

(*--------------------------------------------------------------------------------*)

   PRIVATE PROCEDURE ReadServerLine( OUT SmtpResponse : TSmtpResponse; OUT Response : StringsO.IString; OUT LastLine : BOOLEAN ) : Sync.TAsyncResult;
   VAR
      Read : StringsO.CString;
      Result : Sync.TAsyncResult;
      statusCode : CARDINAL;
      StatusString : StringsO.CString;
   BEGIN
      Result := _Reader.ReadLine( OUT Read, netsocket.FORSAFETY, TRUE );
      IF Result <> Sync.arCompleted THEN
         RETURN Result;
      ELSIF Read.Length < 3 THEN // malformed response, too short
         RETURN Sync.arAborted;
      END;

      Read.Substring( 0, 3, OUT StatusString );
      IF NOT StatusString.ToCARD32( 10, OUT statusCode ) THEN // malformed response, not a number
         RETURN Sync.arAborted;
      END;

      CASE statusCode OF
      | 211: SmtpResponse := smtpres_211;
      | 214: SmtpResponse := smtpres_214;
      | 220: SmtpResponse := smtpres_220;
      | 221: SmtpResponse := smtpres_221;
      | 250: SmtpResponse := smtpres_250;
      | 251: SmtpResponse := smtpres_251;
      | 334: SmtpResponse := smtpres_334;
      | 354: SmtpResponse := smtpres_354;
      | 421: SmtpResponse := smtpres_421;
      | 432: SmtpResponse := smtpres_432;
      | 450: SmtpResponse := smtpres_450;
      | 451: SmtpResponse := smtpres_451;
      | 452: SmtpResponse := smtpres_452;
      | 454: SmtpResponse := smtpres_454;
      | 500: SmtpResponse := smtpres_500;
      | 501: SmtpResponse := smtpres_501;
      | 502: SmtpResponse := smtpres_502;
      | 503: SmtpResponse := smtpres_503;
      | 504: SmtpResponse := smtpres_504;
      | 521: SmtpResponse := smtpres_521;
      | 530: SmtpResponse := smtpres_530;
      | 534: SmtpResponse := smtpres_534;
      | 538: SmtpResponse := smtpres_538;
      | 550: SmtpResponse := smtpres_550;
      | 551: SmtpResponse := smtpres_551;
      | 552: SmtpResponse := smtpres_552;
      | 553: SmtpResponse := smtpres_553;
      | 554: SmtpResponse := smtpres_554;
      ELSE // unknown response code
         ASSERTLOG( FALSE, L"Unknown SMTP response code" );
         RETURN Sync.arAborted;
      END;

      Response := Read;
      LastLine := ( Read.Length = 3 ) OR ( Read[3] = L" " ); // Space is a separator determining last of response lines
      RETURN Sync.arCompleted;
   END ReadServerLine;

(*--------------------------------------------------------------------------------*)

   PRIVATE PROCEDURE WriteServer( CONST Line : StringsO.IString );
   VAR
      Result : Sync.TAsyncResult;
   BEGIN
      Result := _Writer.WriteTimeout( Line, TRUE, netsocket.FORSAFETY );
      IF Result <> Sync.arCompleted THEN
         THROW SmtpException( Result );
      END;
   END WriteServer;

(*--------------------------------------------------------------------------------*)

   PRIVATE PROCEDURE WriteServerBase64( CONST Line : StringsO.IString );
   BEGIN
   END WriteServerBase64;

(*--------------------------------------------------------------------------------*)

   PRIVATE PROCEDURE WriteRecipients( recipients : MailMessage.TPPersons ); // TODO distinguish between complete send and send only some, grab failures to some list or so
   VAR
      s : StringsO.CString;
      smtpres : TSmtpResponse;
   BEGIN
      TRY
         recipients^.Reset();
         WHILE recipients^.MoveNext() DO
            s.FromOA( "RCPT TO: " );
            s.Append( recipients^.Current.Address );
            WriteServer( s );
            smtpres := ReadServer();
            IF smtpres <> smtpres_OK THEN
               THROW SmtpException( Sync.arAborted );
            END;
         END; // WHILE
      CATCH e : CSmtpException DO
         THROW e;
      END;
   END WriteRecipients;

(*--------------------------------------------------------------------------------*)

BEGIN
   _Reader.Stream := _Connection.Stream;
   _Writer.Stream := _Connection.Stream;
END CWorker;

(*================================================================================*)

TYPE
   TRepeatSpan = ARRAY [0..15] OF CARDINAL;

CONST
   REPEAT_SPAN = TRepeatSpan(
               5 * 60 * 1000,
              30 * 60 * 1000,
             150 * 60 * 1000,
             270 * 60 * 1000,
             990 * 60 * 1000,
            2430 * 60 * 1000,
            3870 * 60 * 1000,
            5310 * 60 * 1000,
        7 * 1440 * 60 * 1000,
       13 * 1440 * 60 * 1000,
       26 * 1440 * 60 * 1000,
       60 * 1440 * 60 * 1000,
      120 * 1440 * 60 * 1000,
      240 * 1440 * 60 * 1000,
      480 * 1440 * 60 * 1000,
      960 * 1440 * 60 * 1000
   );

(*--------------------------------------------------------------------------------*)

CLASS IMPLEMENTATION CSender;

(*--------------------------------------------------------------------------------*)

   LOCAL VIRTUAL PROCEDURE OnHandle( Result : Sync.TAsyncResult; PoolHandle : threadpool.TPoolHandle; UserId : PTR );
   VAR
      ptr, stopptr : PTR;
   BEGIN
      IF CARDINAL( Sync.IGet( REF _Pending )) >= Sync.NumberOfProcessors() THEN
         RETURN;
      ELSIF NOT _Queue.Peek( OUT ptr ) THEN
         RETURN;
      END;

      stopptr := ptr;
      REPEAT
         _Queue.Dequeue( OUT ptr );  
         
         _Queue.Peek( OUT ptr );
      UNTIL ptr = stopptr;
   END OnHandle;

(*--------------------------------------------------------------------------------*)

   PUBLIC VIRTUAL PROPERTY Dispatcher GET : threadcall.TPIThreadProcedureCallDispatcher;
   BEGIN
      RETURN _Dispatcher;
   END Dispatcher;

(*--------------------------------------------------------------------------------*)

   PUBLIC VIRTUAL PROPERTY Dispatcher SET( Value : threadcall.TPIThreadProcedureCallDispatcher );
   BEGIN
      _Dispatcher := Value;
   END Dispatcher;

(*--------------------------------------------------------------------------------*)

   PUBLIC VIRTUAL PROPERTY Notifier GET : TPNotifier;
   BEGIN
      RETURN _Notifier;
   END Notifier;

(*--------------------------------------------------------------------------------*)

   PUBLIC VIRTUAL PROPERTY Notifier SET( Value : TPNotifier );
   BEGIN
      _Notifier := Value;
   END Notifier;

(*--------------------------------------------------------------------------------*)

   PUBLIC VIRTUAL PROCEDURE SendAsync( CONST message : MailMessage.TPMailMessage; takeOwnership : BOOLEAN ) : Sync.TAsyncResult;
   BEGIN
      IF _PoolHandle = NIL THEN
         RETURN Sync.arCannotStart;
      END;
      _Queue.Enqueue( message OR PTR( takeOwnership ));
      RETURN Sync.arPending;
   END SendAsync;

(*--------------------------------------------------------------------------------*)

   PUBLIC VIRTUAL PROPERTY Server GET : StringsO.CString;
   BEGIN
      RETURN _Server;
   END Server;

(*--------------------------------------------------------------------------------*)

   PUBLIC VIRTUAL PROPERTY Server SET( CONST Value : StringsO.CString );
   BEGIN
      _Server := Value;
   END Server;

(*--------------------------------------------------------------------------------*)

   PUBLIC VIRTUAL PROPERTY Mailer GET : StringsO.CString;
   BEGIN
      RETURN _Mailer;
   END Mailer;

(*--------------------------------------------------------------------------------*)

   PUBLIC VIRTUAL PROPERTY Mailer SET( CONST Value : StringsO.CString );
   BEGIN
      _Mailer := Value;
   END Mailer;

(*--------------------------------------------------------------------------------*)

   PUBLIC VIRTUAL PROPERTY Login GET : StringsO.CString; 
   BEGIN
      RETURN _Login;
   END Login;

(*--------------------------------------------------------------------------------*)

   PUBLIC VIRTUAL PROPERTY Login SET( CONST Value : StringsO.CString );
   BEGIN
      _Login := Value;
   END Login;

(*--------------------------------------------------------------------------------*)

   PUBLIC VIRTUAL PROPERTY Password GET : StringsO.CString; 
   BEGIN
      RETURN _Password;
   END Password;

(*--------------------------------------------------------------------------------*)

   PUBLIC VIRTUAL PROPERTY Password SET( CONST Value : StringsO.CString );
   BEGIN
      _Password := Value;
   END Password;

(*--------------------------------------------------------------------------------*)

   PUBLIC VIRTUAL PROPERTY TimeToLive GET : CARDINAL;
   BEGIN
      RETURN _TimeToLive;
   END TimeToLive;

(*--------------------------------------------------------------------------------*)

   PUBLIC VIRTUAL PROPERTY TimeToLive SET( Value : CARDINAL );
   BEGIN
      _TimeToLive := Value;
   END TimeToLive;

(*--------------------------------------------------------------------------------*)

   LOCAL PROPERTY LocalName GET : StringsO.CString;
   BEGIN
      IF _LocalName.Empty AND NOT dns.GetLocalName( OUT _LocalName ) THEN
         _LocalName.FromOA( L"scmailer" );
      END;
      RETURN _LocalName;
   END LocalName;

(*--------------------------------------------------------------------------------*)

   LOCAL PROCEDURE NotifyCompletion( CONST message : MailMessage.TPMailMessage; Result : Sync.TAsyncResult; SmtpError : TSmtpError );
   BEGIN
   END NotifyCompletion;

(*--------------------------------------------------------------------------------*)

   PRIVATE PROCEDURE Send();
   BEGIN
   END Send;

(*--------------------------------------------------------------------------------*)

BEGIN
   _QueueSignal.Init( Sync.stEventAutoreset, L"", FALSE );
   IF NOT threadpool.pool()^.WaitHandle( ADR( SELF ), 0, 60000, FALSE, FALSE, _QueueSignal.RawHandle, OUT _PoolHandle ) THEN
      ASSERTLOG( FALSE, L"Unable to start SMTP sender waiting" );
   END;
FINALLY
   IF _PoolHandle <> NIL THEN
      threadpool.pool()^.Abort( REF _PoolHandle );
   END;
END CSender;

(*
////////////////////////////////////////////////////////////////////////////////
//        NAME: Send
// DESCRIPTION: Sending the mail. .
//   ARGUMENTS: none
// USES GLOBAL: m_sSMTPSrvName, m_iSMTPSrvPort, SendBuf, RecvBuf, m_sLogin,
//              m_sPassword, m_sMailFrom, Recipients, CCRecipients,
//              BCCRecipients, m_sMsgBody, Attachments, 
// MODIFIES GL: SendBuf 
//     RETURNS: void
//      AUTHOR: Jakub Piwowarczyk
// AUTHOR/DATE: JP 2010-01-28
//							JP 2010-07-08
////////////////////////////////////////////////////////////////////////////////
void CSmtp::Send()
{
}

////////////////////////////////////////////////////////////////////////////////
//        NAME: ConnectRemoteServer
// DESCRIPTION: Connecting to the service running on the remote server. 
//   ARGUMENTS: const char *server - service name
//              const unsigned short port - service port
// USES GLOBAL: m_pcSMTPSrvName, m_iSMTPSrvPort, SendBuf, RecvBuf, m_pcLogin,
//              m_pcPassword, m_pcMailFrom, Recipients, CCRecipients,
//              BCCRecipients, m_pcMsgBody, Attachments, 
// MODIFIES GL: m_oError 
//     RETURNS: socket of the remote service
//      AUTHOR: Jakub Piwowarczyk
// AUTHOR/DATE: JP 2010-01-28
////////////////////////////////////////////////////////////////////////////////
SOCKET CSmtp::ConnectRemoteServer(const char *szServer,const unsigned short nPort_)
{
   unsigned short nPort = 0;
   LPSERVENT lpServEnt;
   SOCKADDR_IN sockAddr;
   unsigned long ul = 1;
   fd_set fdwrite,fdexcept;
   timeval timeout;
   int res = 0;

   timeout.tv_sec = TIME_IN_SEC;
   timeout.tv_usec = 0;

   SOCKET hSocket = INVALID_SOCKET;

   if((hSocket = socket(PF_INET, SOCK_STREAM,0)) == INVALID_SOCKET)
      throw ECSmtp(ECSmtp::WSA_INVALID_SOCKET);

   if(nPort_ != 0)
      nPort = htons(nPort_);
   else
   {
      lpServEnt = getservbyname("mail", 0);
      if (lpServEnt == NULL)
         nPort = htons(25);
      else 
         nPort = lpServEnt->s_port;
   }
         
   sockAddr.sin_family = AF_INET;
   sockAddr.sin_port = nPort;
   if((sockAddr.sin_addr.s_addr = inet_addr(szServer)) == INADDR_NONE)
   {
      LPHOSTENT host;
         
      host = gethostbyname(szServer);
      if (host)
         memcpy(&sockAddr.sin_addr,host->h_addr_list[0],host->h_length);
      else
      {
#ifdef LINUX
         close(hSocket);
#else
         closesocket(hSocket);
#endif
         throw ECSmtp(ECSmtp::WSA_GETHOSTBY_NAME_ADDR);
      }				
   }

   // start non-blocking mode for socket:
#ifdef LINUX
   if(ioctl(hSocket,FIONBIO, (unsigned long* )&ul) == SOCKET_ERROR)
#else
   if(ioctlsocket(hSocket,FIONBIO, (unsigned long* )&ul) == SOCKET_ERROR)
#endif
   {
#ifdef LINUX
      close(hSocket);
#else
      closesocket(hSocket);
#endif
      throw ECSmtp(ECSmtp::WSA_IOCTLSOCKET);
   }

   if(connect(hSocket,(LPSOCKADDR)&sockAddr,sizeof(sockAddr)) == SOCKET_ERROR)
   {
#ifdef LINUX
      if(errno != EINPROGRESS)
#else
      if(WSAGetLastError() != WSAEWOULDBLOCK)
#endif
      {
#ifdef LINUX
         close(hSocket);
#else
         closesocket(hSocket);
#endif
         throw ECSmtp(ECSmtp::WSA_CONNECT);
      }
   }
   else
      return hSocket;

   while(true)
   {
      FD_ZERO(&fdwrite);
      FD_ZERO(&fdexcept);

      FD_SET(hSocket,&fdwrite);
      FD_SET(hSocket,&fdexcept);

      if((res = select(hSocket+1,NULL,&fdwrite,&fdexcept,&timeout)) == SOCKET_ERROR)
      {
#ifdef LINUX
         close(hSocket);
#else
         closesocket(hSocket);
#endif
         throw ECSmtp(ECSmtp::WSA_SELECT);
      }

      if(!res)
      {
#ifdef LINUX
         close(hSocket);
#else
         closesocket(hSocket);
#endif
         throw ECSmtp(ECSmtp::SELECT_TIMEOUT);
      }
      if(res && FD_ISSET(hSocket,&fdwrite))
         break;
      if(res && FD_ISSET(hSocket,&fdexcept))
      {
#ifdef LINUX
         close(hSocket);
#else
         closesocket(hSocket);
#endif
         throw ECSmtp(ECSmtp::WSA_SELECT);
      }
   } // while

   FD_CLR(hSocket,&fdwrite);
   FD_CLR(hSocket,&fdexcept);

   return hSocket;
}

////////////////////////////////////////////////////////////////////////////////
//        NAME: FormatHeader
// DESCRIPTION: Prepares a header of the message.
//   ARGUMENTS: char* header - formated header string
// USES GLOBAL: Recipients, CCRecipients, BCCRecipients
// MODIFIES GL: none
//     RETURNS: void
//      AUTHOR: Jakub Piwowarczyk
// AUTHOR/DATE: JP 2010-01-28
//							JP 2010-07-07
////////////////////////////////////////////////////////////////////////////////
void CSmtp::FormatHeader(char* header)
{
   char month[][4] = {"Jan","Feb","Mar","Apr","May","Jun","Jul","Aug","Sep","Oct","Nov","Dec"};
   size_t i;
   std::string to;
   std::string cc;
   std::string bcc;
   time_t rawtime;
   struct tm* timeinfo;

   // date/time check
   if(time(&rawtime) > 0)
      timeinfo = localtime(&rawtime);
   else
      throw ECSmtp(ECSmtp::TIME_ERROR);

   // check for at least one recipient
   if(Recipients.size())
   {
      for (i=0;i<Recipients.size();i++)
      {
         if(i > 0)
            to.append(",");
         to += Recipients[i].Name;
         to.append("<");
         to += Recipients[i].Mail;
         to.append(">");
      }
   }
   else
      throw ECSmtp(ECSmtp::UNDEF_RECIPIENTS);

   if(CCRecipients.size())
   {
      for (i=0;i<CCRecipients.size();i++)
      {
         if(i > 0)
            cc. append(",");
         cc += CCRecipients[i].Name;
         cc.append("<");
         cc += CCRecipients[i].Mail;
         cc.append(">");
      }
   }

   if(BCCRecipients.size())
   {
      for (i=0;i<BCCRecipients.size();i++)
      {
         if(i > 0)
            bcc.append(",");
         bcc += BCCRecipients[i].Name;
         bcc.append("<");
         bcc += BCCRecipients[i].Mail;
         bcc.append(">");
      }
   }
   
   // Date: <SP> <dd> <SP> <mon> <SP> <yy> <SP> <hh> ":" <mm> ":" <ss> <SP> <zone> <CRLF>
   sprintf(header,"Date: %d %s %d %d:%d:%d\r\n",	timeinfo->tm_mday,
                                                                        month[timeinfo->tm_mon],
                                                                        timeinfo->tm_year+1900,
                                                                        timeinfo->tm_hour,
                                                                        timeinfo->tm_min,
                                                                        timeinfo->tm_sec); 
   
   // From: <SP> <sender>  <SP> "<" <sender-email> ">" <CRLF>
   if(!m_sMailFrom.size())
      throw ECSmtp(ECSmtp::UNDEF_MAIL_FROM);
   strcat(header,"From: ");
   if(m_sNameFrom.size())
      strcat(header, m_sNameFrom.c_str());
   strcat(header," <");
   if(m_sNameFrom.size())
      strcat(header,m_sMailFrom.c_str());
   else
      strcat(header,"mail@domain.com");
   strcat(header, ">\r\n");

   // X-Mailer: <SP> <xmailer-app> <CRLF>
   if(m_sXMailer.size())
   {
      strcat(header,"X-Mailer: ");
      strcat(header, m_sXMailer.c_str());
      strcat(header, "\r\n");
   }

   // Reply-To: <SP> <reverse-path> <CRLF>
   if(m_sReplyTo.size())
   {
      strcat(header, "Reply-To: ");
      strcat(header, m_sReplyTo.c_str());
      strcat(header, "\r\n");
   }

   // X-Priority: <SP> <number> <CRLF>
   switch(m_iXPriority)
   {
      case XPRIORITY_HIGH:
         strcat(header,"X-Priority: 2 (High)\r\n");
         break;
      case XPRIORITY_NORMAL:
         strcat(header,"X-Priority: 3 (Normal)\r\n");
         break;
      case XPRIORITY_LOW:
         strcat(header,"X-Priority: 4 (Low)\r\n");
         break;
      default:
         strcat(header,"X-Priority: 3 (Normal)\r\n");
   }

   // To: <SP> <remote-user-mail> <CRLF>
   strcat(header,"To: ");
   strcat(header, to.c_str());
   strcat(header, "\r\n");

   // Cc: <SP> <remote-user-mail> <CRLF>
   if(CCRecipients.size())
   {
      strcat(header,"Cc: ");
      strcat(header, cc.c_str());
      strcat(header, "\r\n");
   }

   if(BCCRecipients.size())
   {
      strcat(header,"Bcc: ");
      strcat(header, bcc.c_str());
      strcat(header, "\r\n");
   }

   // Subject: <SP> <subject-text> <CRLF>
   if(!m_sSubject.size()) 
      strcat(header, "Subject:  ");
   else
   {
     strcat(header, "Subject: ");
     strcat(header, m_sSubject.c_str());
   }
   strcat(header, "\r\n");
   
   // MIME-Version: <SP> 1.0 <CRLF>
   strcat(header,"MIME-Version: 1.0\r\n");
   if(!Attachments.size())
   { // no attachments
      strcat(header,"Content-type: text/plain; charset=US-ASCII\r\n");
      strcat(header,"Content-Transfer-Encoding: 7bit\r\n");
      strcat(SendBuf,"\r\n");
   }
   else
   { // there is one or more attachments
      strcat(header,"Content-Type: multipart/mixed; boundary=\"");
      strcat(header,BOUNDARY_TEXT);
      strcat(header,"\"\r\n");
      strcat(header,"\r\n");
      // first goes text message
      strcat(SendBuf,"--");
      strcat(SendBuf,BOUNDARY_TEXT);
      strcat(SendBuf,"\r\n");
      strcat(SendBuf,"Content-type: text/plain; charset=US-ASCII\r\n");
      strcat(SendBuf,"Content-Transfer-Encoding: 7bit\r\n");
      strcat(SendBuf,"\r\n");
   }

   // done
}

////////////////////////////////////////////////////////////////////////////////
//        NAME: ReceiveData
// DESCRIPTION: Receives a row terminated '\n'.
//   ARGUMENTS: none
// USES GLOBAL: RecvBuf
// MODIFIES GL: RecvBuf
//     RETURNS: void
//      AUTHOR: Jakub Piwowarczyk
// AUTHOR/DATE: JP 2010-01-28
//							JP 2010-07-07
////////////////////////////////////////////////////////////////////////////////
void CSmtp::ReceiveData()
{
   int res,i = 0;
   fd_set fdread;
   timeval time;

   time.tv_sec = TIME_IN_SEC;
   time.tv_usec = 0;

   assert(RecvBuf);

   if(RecvBuf == NULL)
      throw ECSmtp(ECSmtp::RECVBUF_IS_EMPTY);

   while(1)
   {
      FD_ZERO(&fdread);

      FD_SET(hSocket,&fdread);

      if((res = select(hSocket+1, &fdread, NULL, NULL, &time)) == SOCKET_ERROR)
      {
         FD_CLR(hSocket,&fdread);
         throw ECSmtp(ECSmtp::WSA_SELECT);
      }

      if(!res)
      {
         //timeout
         FD_CLR(hSocket,&fdread);
         throw ECSmtp(ECSmtp::SERVER_NOT_RESPONDING);
      }

      if(res && FD_ISSET(hSocket,&fdread))
      {
         if(i >= BUFFER_SIZE)
         {
            FD_CLR(hSocket,&fdread);
            throw ECSmtp(ECSmtp::LACK_OF_MEMORY);
         }
         if(recv(hSocket,&RecvBuf[i++],1,0) == SOCKET_ERROR)
         {
            FD_CLR(hSocket,&fdread);
            throw ECSmtp(ECSmtp::WSA_RECV);
         }
         if(RecvBuf[i-1]=='\n')
         {
            RecvBuf[i] = '\0';
            break;
         }
      }
   }

   FD_CLR(hSocket,&fdread);
}

////////////////////////////////////////////////////////////////////////////////
//        NAME: SendData
// DESCRIPTION: Sends data from SendBuf buffer.
//   ARGUMENTS: none
// USES GLOBAL: SendBuf
// MODIFIES GL: none
//     RETURNS: void
//      AUTHOR: Jakub Piwowarczyk
// AUTHOR/DATE: JP 2010-01-28
////////////////////////////////////////////////////////////////////////////////
void CSmtp::SendData()
{
   int idx = 0,res,nLeft = strlen(SendBuf);
   fd_set fdwrite;
   timeval time;

   time.tv_sec = TIME_IN_SEC;
   time.tv_usec = 0;

   assert(SendBuf);

   if(SendBuf == NULL)
      throw ECSmtp(ECSmtp::SENDBUF_IS_EMPTY);

   while(1)
   {
      FD_ZERO(&fdwrite);

      FD_SET(hSocket,&fdwrite);

      if((res = select(hSocket+1,NULL,&fdwrite,NULL,&time)) == SOCKET_ERROR)
      {
         FD_CLR(hSocket,&fdwrite);
         throw ECSmtp(ECSmtp::WSA_SELECT);
      }

      if(!res)
      {
         //timeout
         FD_CLR(hSocket,&fdwrite);
         throw ECSmtp(ECSmtp::SERVER_NOT_RESPONDING);
      }

      if(res && FD_ISSET(hSocket,&fdwrite))
      {
         if(nLeft > 0)
         {
            if((res = send(hSocket,&SendBuf[idx],nLeft,0)) == SOCKET_ERROR)
            {
               FD_CLR(hSocket,&fdwrite);
               throw ECSmtp(ECSmtp::WSA_SEND);
            }
            if(!res)
               break;
            nLeft -= res;
            idx += res;
         }
         else
            break;
      }
   }

   FD_CLR(hSocket,&fdwrite);
}

////////////////////////////////////////////////////////////////////////////////
//        NAME: GetErrorText (friend function)
// DESCRIPTION: Returns the string for specified error code.
//   ARGUMENTS: CSmtpError ErrorId - error code
// USES GLOBAL: none
// MODIFIES GL: none 
//     RETURNS: error string
//      AUTHOR: Jakub Piwowarczyk
// AUTHOR/DATE: JP 2010-01-28
////////////////////////////////////////////////////////////////////////////////
std::string ECSmtp::GetErrorText() const
{
   switch(ErrorCode)
   {
      case ECSmtp::CSMTP_NO_ERROR:
         return "";
      case ECSmtp::WSA_STARTUP:
         return "Unable to initialise winsock2";
      case ECSmtp::WSA_VER:
         return "Wrong version of the winsock2";
      case ECSmtp::WSA_SEND:
         return "Function send() failed";
      case ECSmtp::WSA_RECV:
         return "Function recv() failed";
      case ECSmtp::WSA_CONNECT:
         return "Function connect failed";
      case ECSmtp::WSA_GETHOSTBY_NAME_ADDR:
         return "Unable to determine remote server";
      case ECSmtp::WSA_INVALID_SOCKET:
         return "Invalid winsock2 socket";
      case ECSmtp::WSA_HOSTNAME:
         return "Function hostname() failed";
      case ECSmtp::WSA_IOCTLSOCKET:
         return "Function ioctlsocket() failed";
      case ECSmtp::BAD_IPV4_ADDR:
         return "Improper IPv4 address";
      case ECSmtp::UNDEF_MSG_HEADER:
         return "Undefined message header";
      case ECSmtp::UNDEF_MAIL_FROM:
         return "Undefined mail sender";
      case ECSmtp::UNDEF_SUBJECT:
         return "Undefined message subject";
      case ECSmtp::UNDEF_RECIPIENTS:
         return "Undefined at least one reciepent";
      case ECSmtp::UNDEF_RECIPIENT_MAIL:
         return "Undefined recipent mail";
      case ECSmtp::UNDEF_LOGIN:
         return "Undefined user login";
      case ECSmtp::UNDEF_PASSWORD:
         return "Undefined user password";
      case ECSmtp::COMMAND_MAIL_FROM:
         return "Server returned error after sending MAIL FROM";
      case ECSmtp::COMMAND_EHLO:
         return "Server returned error after sending EHLO";
      case ECSmtp::COMMAND_AUTH_LOGIN:
         return "Server returned error after sending AUTH LOGIN";
      case ECSmtp::COMMAND_DATA:
         return "Server returned error after sending DATA";
      case ECSmtp::COMMAND_QUIT:
         return "Server returned error after sending QUIT";
      case ECSmtp::COMMAND_RCPT_TO:
         return "Server returned error after sending RCPT TO";
      case ECSmtp::MSG_BODY_ERROR:
         return "Error in message body";
      case ECSmtp::CONNECTION_CLOSED:
         return "Server has closed the connection";
      case ECSmtp::SERVER_NOT_READY:
         return "Server is not ready";
      case ECSmtp::SERVER_NOT_RESPONDING:
         return "Server not responding";
      case ECSmtp::FILE_NOT_EXIST:
         return "File not exist";
      case ECSmtp::MSG_TOO_BIG:
         return "Message is too big";
      case ECSmtp::BAD_LOGIN_PASS:
         return "Bad login or password";
      case ECSmtp::UNDEF_XYZ_RESPONSE:
         return "Undefined xyz SMTP response";
      case ECSmtp::LACK_OF_MEMORY:
         return "Lack of memory";
      case ECSmtp::TIME_ERROR:
         return "time() error";
      case ECSmtp::RECVBUF_IS_EMPTY:
         return "RecvBuf is empty";
      case ECSmtp::SENDBUF_IS_EMPTY:
         return "SendBuf is empty";
      case ECSmtp::OUT_OF_MSG_RANGE:
         return "Specified line number is out of message size";
      default:
         return "Undefined error id";
   }
}

*)

(*================================================================================*)

PROCEDURE New( OUT sender : TPSender; lightWeight : BOOLEAN ) : BOOLEAN; // for lightWeight, synchronous not threaded ISender is created, otherwise timeouting, queued and threaded ISender is used
BEGIN
   RETURN FALSE;
END New;

(*--------------------------------------------------------------------------------*)

PROCEDURE Dispose( REF sender : TPSender );
BEGIN
END Dispose;

(*================================================================================*)

END SMTPSender.