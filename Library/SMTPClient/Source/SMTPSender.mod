IMPLEMENTATION MODULE SMTPSender;

IMPORT
   threadpool;

(*================================================================================*)

CLASS CWorker( threadpool.APoolWorker );

   // APoolWorker
   LOCAL VIRTUAL PROCEDURE Run();

   // SELF
   PUBLIC PROCEDURE Init( sender : TPSender; CONST message : MailMessage.TPMessage );

   PRIVATE VAR
      _Sender : TPSender := NIL;
      _Message : MailMessage.TPMessage := NIL;
      _Connection : rawconnection.ClientTCPConnection;
      _Reader : TextReader.CTextReader;
      _Writer : TextWriter.CTextWriter;

   PRIVATE PROCEDURE DoSend();
   PRIVATE PROCEDURE NotifyCompletion( Result : Sync.TAsyncResult; SpecificCode : TSMTPResult );
   PRIVATE PROCEDURE ReadServer( OUT SMTPResponse : TSMTPResponse; OUT Response : StringsO.IString ) : Sync.TAsyncResult;
   INLINE PROCEDURE WriteServer( CONST Line : StringsO.IString ) : Sync.TAsyncResult;

END CWorker;

(*--------------------------------------------------------------------------------*)

CLASS IMPLEMENTATION CWorker;

(*--------------------------------------------------------------------------------*)

   LOCAL VIRTUAL PROCEDURE Run();
   VAR
      Result : Sync.TAsyncResult;
      SpecificCode : TSMTPResult := smtpConnectFailed;
   BEGIN
      Result := _Connection.OpenS( _Sender^, TRUE, netsocket.FORSAFETY );

      IF Result = Sync.arCompleted THEN
         Result := DoSend( OUT SpecificCode );
      END;

      NotifyCompletion( Result, SpecificCode );
   END Run;

(*--------------------------------------------------------------------------------*)

   PUBLIC PROCEDURE Init( sender : TPSender; CONST message : MailMessage.TPMessage );
   BEGIN
      _Sender := sender;
      _Message := message;
   END Init;

(*--------------------------------------------------------------------------------*)

   PRIVATE PROCEDURE DoSend( OUT SpecificCode : TSmtpError ) : Sync.TAsyncResult;
   VAR
      recipients : MailMessage.TPPersons;
      Result : Sync.TAsyncResult;
      smtpres : TSmtpResponse;
   BEGIN
      //----------
      SpecificCode := SmtpErrorServerNotReady;

      Result := ReadServer( OUT smtpres );
      IF Result <> Sync.arCompleted THEN
         RETURN Result;
      ELSIF smtpres <> smtpresult_220 THEN
         RETURN Sync.arAborted;
      END;

      //----------
      SpecificCode := SmtpErrorEhlo;

      s.FromOA( L"EHLO " );
      s.Append( _Sender.LocalName );
      Result := WriteServer( s );
      IF Result = Sync.arCompleted THEN
         Result := ReadServer( OUT smtpres );
      END;
      IF Result <> Sync.arCompleted THEN
         RETURN Result;
      ELSIF smtpres <> smtpresult_OK THEN
         RETURN Sync.arAborted;
      END;

      //----------
      IF NOT _Sender^.Login.Empty THEN

         SpecificCode := SmtpErrorAuthenticationFailed;

         s.FromOA( L"AUTH LOGIN" );
         Result := WriteServer( s );
         IF Result = Sync.arCompleted THEN
            Result := ReadServer( OUT smtpres );
         END;
         IF Result <> Sync.arCompleted THEN
            RETURN Result;
         ELSIF smtpres <> smtpresult_334 THEN // TODO: check if "UserName" is requested
            RETURN Sync.arAborted;
         END;
         // send login
         Result := WriteServerBase64( _Sender^.Login );
         IF Result = Sync.arCompleted THEN
            Result := ReadServer( OUT smtpres );
         END;
         IF smtpres <> smtpresult_334 THEN // TODO: check if "Password" is requested
            RETURN Sync.arAborted;
         END;
         // send password
         Result := WriteServerBase64( _Sender^.Password );
         IF Result = Sync.arCompleted THEN
            Result := ReadServer( OUT smtpres );
         END;
         CASE smtpres OF
         | smtpresult_235 : // OK, success
         | smtpresult_535 : // not authorized
            RETURN Sync.arFailed;
         ELSE
            RETURN Sync.arAborted;
         END;
      END;

      //----------
      SpecificCode := SmtpErrorMailFrom;

      // TODO, MailFrom nesmí být empty
      s.FromOA( L"MAIL FROM: " );
      s.Append( _Message^.Sender );
      Result := WriteServer( s );
      IF Result = Sync.arCompleted THEN
         Result := ReadServer( OUT smtpres );
      END;
      CASE smtpres OF
      | smtpresult_OK : // OK, success
      | smtpresult_530 : // authentication required
         SpecificCode := SmtpErrorAuthenticationRequired;
         RETURN Sync.arFailed;
      ELSE
         RETURN Sync.arAborted;
      END;

      //----------
      SpecificCode := SmtpErrorRcptTo;

      // TODO, at least one recipient must be known
      Result := WriteRecipients( _Message^.Recipients );
      IF Result = smtpres_OK THEN
         Result := WriteRecipients( _Message^.CCs );
      END;
      IF Result = smtpres_OK THEN
         Result := WriteRecipients( _Message^.BCCs );
      END;
      IF Result <> smtpres_OK THEN
         RETURN Result;
      END;

      //----------
      SpecificCode := SmtpErrorData;

      s.FromOA( L"DATA" );
      Result := WriteServer( s );
      IF Result = Sync.arCompleted THEN
         Result := ReadServer( OUT smtpres );
      END;
      IF Result <> Sync.arCompleted THEN
         RETURN Result;
      ELSIF smtpres <> smtpresult_354 THEN
         RETURN Sync.arAborted;
      END;

      //----------
      SpecificCode := SmtpErrorHeaders;

      Result := WriteHeaders();
      IF Result <> Sync.arCompleted THEN
         RETURN Result;   
      END;

      //----------
      SpecificCode := SmtpErrorMessageBody;

      Result := WriteStream( _Message^.Stream );
      IF Result <> Sync.arCompleted THEN
         RETURN Result;   
      END;

      //----------
      SpecificCode := SmtpErrorAttachments;

      IF NOT _Message.Attachments.Empty THEN
      END;

      //----------
      SpecificCode := SmtpErrorMessageFinalization;

      s.FromOA( 13W + 10W + L"." + 13W + 10W );
      Result := WriteServer( s );
      IF Result = Sync.arCompleted THEN
         Result := ReadServer( OUT smtpres );
      END;
      IF Result <> Sync.arCompleted THEN
         RETURN Result;
      ELSIF smtpres <> smtpresult_OK THEN
         RETURN Sync.arAborted;
      END;

      //----------
      SpecificCode := SmtpErrorConnectionFinalization;

      s.FromOA( L"QUIT" );
      Result := WriteServer( s );
      IF Result = Sync.arCompleted THEN
         Result := ReadServer( OUT smtpres );
      END;
      IF Result <> Sync.arCompleted THEN
         RETURN Result;
      ELSIF smtpres <> smtpresult_OK THEN
         RETURN Sync.arAborted;
      END;

   
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
   
      RETURN Sync.arCompleted;
   END DoSend;

(*--------------------------------------------------------------------------------*)

   PRIVATE PROCEDURE NotifyCompletion( Result : Sync.TAsyncResult; SpecificCode : TSMTPResult );
   BEGIN
      _Sender^.NotifyCompletion( _Message, Result, SpecificCode );
   END NotifyCompletion;

(*--------------------------------------------------------------------------------*)

   PRIVATE PROCEDURE ReadServer( OUT SMTPResponse : TSmtpResponse ) : Sync.TAsyncResult;
   VAR
      current : TSmtpResponse := smtpres_Unknown;
      lastline : BOOLEAN := FALSE;
      previous : TSmtpResponse := smtpres_Unknown;
   BEGIN
      REPEAT
         Result := ReadServerLine( OUT current, OUT response, OUT lastline );
         IF Result <> Sync.arCompleted THEN
            RETURN Result;
         ELSIF ( previous <> smtpres_Unknown ) AND ( current <> previous ) THEN // responses must be uniform for single command
            RETURN Sync.arAborted; 
         END;
      UNTIL lastline;

      SMTPResponse := current;
      RETURN Sync.arCompleted;
   END ReadServer;

(*--------------------------------------------------------------------------------*)

   PRIVATE PROCEDURE ReadServerLine( OUT SMTPResponse : TSmtpResponse; OUT Response : StringsO.IString; OUT LastLine : BOOLEAN ) : Sync.TAsyncResult;
   VAR
      Read : StringsO.CString;
      Result : Sync.TAsyncResult;
      StatusString : StringsO.CString;
   BEGIN
      Result := _Reader.ReadLine( OUT Read, netsocket.FORSAFETY, TRUE );
      IF Result <> Sync.arCompleted THEN
         RETURN Result;
      ELSIF Read.Length < 3 THEN // malformed response, too short
         RETURN Sync.arAborted;
      END;

      Read.Substring( OUT StatusString, 0, 3 );
      IF NOT StatusString.ToCARD32( 10, OUT statusCode ) THEN // malformed response, not a number
         RETURN Sync.arAborted;
      END;

      CASE statusCode OF
      | 211: SMTPResponse := smtpres_211;
      | 214: SMTPResponse := smtpres_214;
      | 220: SMTPResponse := smtpres_220;
      | 221: SMTPResponse := smtpres_221;
      | 250: SMTPResponse := smtpres_250;
      | 251: SMTPResponse := smtpres_251;
      | 334: SMTPResponse := smtpres_334;
      | 354: SMTPResponse := smtpres_354;
      | 421: SMTPResponse := smtpres_421;
      | 432: SMTPResponse := smtpres_432;
      | 450: SMTPResponse := smtpres_450;
      | 451: SMTPResponse := smtpres_451;
      | 452: SMTPResponse := smtpres_452;
      | 454: SMTPResponse := smtpres_454;
      | 500: SMTPResponse := smtpres_500;
      | 501: SMTPResponse := smtpres_501;
      | 502: SMTPResponse := smtpres_502;
      | 503: SMTPResponse := smtpres_503;
      | 504: SMTPResponse := smtpres_504;
      | 521: SMTPResponse := smtpres_521;
      | 530: SMTPResponse := smtpres_530;
      | 534: SMTPResponse := smtpres_534;
      | 538: SMTPResponse := smtpres_538;
      | 550: SMTPResponse := smtpres_550;
      | 551: SMTPResponse := smtpres_551;
      | 552: SMTPResponse := smtpres_552;
      | 553: SMTPResponse := smtpres_553;
      | 554: SMTPResponse := smtpres_554;
      ELSE // unknown response code
         RETURN Sync.arAborted;
      END;

      Response := Read;
      LastLine := ( Read.Length = 3 ) OR ( Read[3] = L" " ); // Space is a separator determining last of response lines
      RETURN Sync.arCompleted;
   END ReadServer;

(*--------------------------------------------------------------------------------*)

   INLINE PRIVATE PROCEDURE WriteServer( CONST Line : StringsO.IString ) : Sync.TAsyncResult;
   BEGIN
      RETURN _Writer.WriteTimeout( Line, TRUE, netsocket.FORSAFETY ); 
   END WriteServer;

(*--------------------------------------------------------------------------------*)

   PROCEDURE WriteRecipients( recipients : MailMessage.TPPersons ) : Sync.TAsyncResult; // TODO distinguish between complete send and send only some, grab failures to some list or so
   VAR
      Result : Sync.TAsyncResult;
      s : StringsO.CString;
   BEGIN
      recipients^.Reset();
      WHILE recipients^.MoveNext() DO
         s.FromOA( "RCPT TO: " );
         s.AppendOA( recipients^.Current.Address );
         Result := WriteServer( s );
         IF Result = Sync.arCompleted THEN
            Result := ReadServer( OUT smtpres );
         END;
         IF Result <> Sync.arCompleted THEN
            RETURN Result;
         ELSIF smtpres <> smtpres_OK THEN
            RETURN Sync.arAborted;
         END;
      END; // WHILE
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
      480 * 1440 * 60 * 1000
   );

(*--------------------------------------------------------------------------------*)

CLASS CSender( threadpool.APoolDelegate ) IMPLEMENTS ISender;

   // APoolDelegate
   LOCAL VIRTUAL PROCEDURE OnHandle( Result : Sync.TAsyncResult; PoolHandle : threadpool.TPoolHandle; UserId : PTR );

   // ISender
   PUBLIC VIRTUAL PROPERTY
      Dispatcher : threadcall.TPIThreadProcedureCallDispatcher; // default NIL, which means notifier is called directly from network thread
      Notifier : TPNotifier;

   PUBLIC VIRTUAL PROCEDURE SendAsync( CONST message : MailMessage.TPMessage; takeOwnership : BOOLEAN ) : Sync.TAsyncResult; // returns failure only if Server is empty

   PUBLIC VIRTUAL PROPERTY
      Server : inetaddr.INETADDR;
      Mailer : StringsO.CString;
      Login : StringsO.CString; 
      Password : StringsO.CString; 
      TimeToLive : CARDINAL; // milliseconds, the message will stay in the queue for the time

   // SELF
   LOCAL PROCEDURE NotifyCompletion( CONST message : MailMessage.TPMessage; Result : Sync.TAsyncResult; SpecificCode : TSMTPResult );
   PRIVATE PROCEDURE Send();

   PRIVATE VAR
      _QueueSignal : Sync.SIGNAL;
      _PoolHandle : threadpool.TPoolHandle := NIL;
      _Queue : msgqueue.CPtrQueue;
      _Pool : threadpool.CThreadPool;
      _PendingSends : CARDINAL := 0;
      _TimeToLive : CARDINAL := 2*86400; // two days
      _Dispatcher : threadcall.TPIThreadProcedureCallDispatcher := NIL;
      _Notifier : TPNotifier := NIL;

END CSender;

(*--------------------------------------------------------------------------------*)

CLASS IMPLEMENTATION CSender;

(*--------------------------------------------------------------------------------*)

   LOCAL VIRTUAL PROCEDURE OnHandle( Result : Sync.TAsyncResult; PoolHandle : threadpool.TPoolHandle; UserId : PTR );
   VAR
      ptr, stopptr : PTR;
      message
   BEGIN
      IF Sync.IGet( REF _Pending ) >= Sync.NumberOfProcessors() THEN
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

   PROCEDURE SendAsync( CONST message : MailMessage.TPMessage; takeOwnership : BOOLEAN ) : Sync.TAsyncResult;
   BEGIN
      IF _PoolHandle = NIL THEN
         RETURN Sync.arCannotStart;
      END;
      _Queue.Enqueue( message OR PTR( takeOwnership ));
   END SendAsync;

(*--------------------------------------------------------------------------------*)

   PROPERTY
      Server : inetaddr.INETADDR;
      Mailer : StringsO.CString;
      Login : StringsO.CString; 
      Password : StringsO.CString; 
      TimeToLive : CARDINAL; // milliseconds, the message will stay in the queue for the time

(*--------------------------------------------------------------------------------*)

   LOCAL PROCEDURE NotifyCompletion( CONST message : MailMessage.TPMessage; Result : Sync.TAsyncResult; SpecificCode : TSMTPResult );

(*--------------------------------------------------------------------------------*)

   PRIVATE PROCEDURE Send();

(*--------------------------------------------------------------------------------*)

BEGIN
   _QueueSignal.Init( Sync.stEventAutoreset, L"", FALSE );
   IF NOT threadpool.pool()^.WaitHandle( ADR( SELF ), 0, 60000, FALSE, FALSE, _QueueSignal.RawHandle, OUT _PoolHandle ) THEN
      ASSERTLOG( FALSE, L"Unable to start SMTP sender waiting" );
   END;
FINALLY
   IF _PoolHandle <> NIL THEN
      threadpool.pool()^.AbortHandle( REF _PoolHandle );
   END;
END CSender;

(*================================================================================*)

PROCEDURE New( OUT sender : TPSender ) : BOOLEAN;
PROCEDURE Dispose( REF sender : TPSender;

(*================================================================================*)

END SMTPSender.

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
   if(ioctl(hSocket,FIONBIO, (unsigned long*)&ul) == SOCKET_ERROR)
#else
   if(ioctlsocket(hSocket,FIONBIO, (unsigned long*)&ul) == SOCKET_ERROR)
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

