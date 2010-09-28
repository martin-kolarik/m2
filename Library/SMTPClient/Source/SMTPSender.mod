IMPLEMENTATION MODULE SMTPSender;

IMPORT
   threadpool;

(*================================================================================*)

CLASS CWorker( threadpool.APoolWorker );

   // APoolWorker
   LOCAL ABSTRACT PROCEDURE Run();

   // SELF
   PUBLIC PROCEDURE Init( sender : TPSender; CONST message : MailMessage.TPMessage );

   PRIVATE VAR
      _Sender : TPSender;
      _Message : MailMessage.TPMessage;
      _Connection : rawconnection.ClientTCPConnection;

   PRIVATE PROCEDURE DoSend();
   PRIVATE PROCEDURE NotifyCompletion( Result : Sync.TAsyncResult; SpecificCode : TSMTPResult );

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
   unsigned int i,rcpt_count,res,FileId;
   char *FileBuf = NULL, *FileName = NULL;
   FILE* hFile = NULL;
   unsigned long int FileSize,TotalSize,MsgPart;
   bool bAccepted;

   // ***** CONNECTING TO SMTP SERVER *****

   // connecting to remote host:
   if( (hSocket = ConnectRemoteServer(m_sSMTPSrvName.c_str(), m_iSMTPSrvPort)) == INVALID_SOCKET ) 
      throw ECSmtp(ECSmtp::WSA_INVALID_SOCKET);

   bAccepted = false;
   do
   {
      ReceiveData();
      switch(SmtpXYZdigits())
      {
         case 220:
            bAccepted = true;
            break;
         default:
            throw ECSmtp(ECSmtp::SERVER_NOT_READY);
      }
   }while(!bAccepted);

   // EHLO <SP> <domain> <CRLF>
   sprintf(SendBuf,"EHLO %s\r\n",GetLocalHostName()!=NULL ? m_sLocalHostName.c_str() : "domain");
   SendData();
   bAccepted = false;
   do
   {
      ReceiveData();
      switch(SmtpXYZdigits())
      {
         case 250:
            bAccepted = true;
            break;
         default:
            throw ECSmtp(ECSmtp::COMMAND_EHLO);
      }
   }while(!bAccepted);

   // AUTH <SP> LOGIN <CRLF>
   strcpy(SendBuf,"AUTH LOGIN\r\n");
   SendData();
   bAccepted = false;
   do
   {
      ReceiveData();
      switch(SmtpXYZdigits())
      {
         case 250:
            break;
         case 334:
            bAccepted = true;
            break;
         default:
            throw ECSmtp(ECSmtp::COMMAND_AUTH_LOGIN);
      }
   }while(!bAccepted);

   // send login:
   if(!m_sLogin.size())
      throw ECSmtp(ECSmtp::UNDEF_LOGIN);
   std::string encoded_login = base64_encode(reinterpret_cast<const unsigned char*>(m_sLogin.c_str()),m_sLogin.size());
   sprintf(SendBuf,"%s\r\n",encoded_login.c_str());
   SendData();
   bAccepted = false;
   do
   {
      ReceiveData();
      switch(SmtpXYZdigits())
      {
         case 334:
            bAccepted = true;
            break;
         default:
            throw ECSmtp(ECSmtp::UNDEF_XYZ_RESPONSE);
      }
   }while(!bAccepted);
   
   // send password:
   if(!m_sPassword.size())
      throw ECSmtp(ECSmtp::UNDEF_PASSWORD);
   std::string encoded_password = base64_encode(reinterpret_cast<const unsigned char*>(m_sPassword.c_str()),m_sPassword.size());
   sprintf(SendBuf,"%s\r\n",encoded_password.c_str());
   SendData();
   bAccepted = false;
   do
   {
      ReceiveData();
      switch(SmtpXYZdigits())
      {
         case 235:
            bAccepted = true;
            break;
         case 334:
            break;
         case 535:
            throw ECSmtp(ECSmtp::BAD_LOGIN_PASS);
         default:
            throw ECSmtp(ECSmtp::UNDEF_XYZ_RESPONSE);
      }
   }while(!bAccepted);

   // ***** SENDING E-MAIL *****
   
   // MAIL <SP> FROM:<reverse-path> <CRLF>
   if(!m_sMailFrom.size())
      throw ECSmtp(ECSmtp::UNDEF_MAIL_FROM);
   sprintf(SendBuf,"MAIL FROM:<%s>\r\n",m_sMailFrom.c_str());
   SendData();
   bAccepted = false;
   do
   {
      ReceiveData();
      switch(SmtpXYZdigits())
      {
         case 250:
            bAccepted = true;
            break;
         default:
            throw ECSmtp(ECSmtp::COMMAND_MAIL_FROM);
      }
   }while(!bAccepted);

   // RCPT <SP> TO:<forward-path> <CRLF>
   if(!(rcpt_count = Recipients.size()))
      throw ECSmtp(ECSmtp::UNDEF_RECIPIENTS);
   for(i=0;i<Recipients.size();i++)
   {
      sprintf(SendBuf,"RCPT TO:<%s>\r\n",(Recipients.at(i).Mail).c_str());
      SendData();
      bAccepted = false;
      do
      {
         ReceiveData();
         switch(SmtpXYZdigits())
         {
            case 250:
               bAccepted = true;
               break;
            default:
               rcpt_count--;
         }
      }while(!bAccepted);
   }
   if(rcpt_count <= 0)
      throw ECSmtp(ECSmtp::COMMAND_RCPT_TO);

   for(i=0;i<CCRecipients.size();i++)
   {
      sprintf(SendBuf,"RCPT TO:<%s>\r\n",(CCRecipients.at(i).Mail).c_str());
      SendData();
      bAccepted = false;
      do
      {
         ReceiveData();
         switch(SmtpXYZdigits())
         {
            case 250:
               bAccepted = true;
               break;
            default:
               ; // not necessary to throw
         }
      }while(!bAccepted);
   }

   for(i=0;i<BCCRecipients.size();i++)
   {
      sprintf(SendBuf,"RCPT TO:<%s>\r\n",(BCCRecipients.at(i).Mail).c_str());
      SendData();
      bAccepted = false;
      do
      {
         ReceiveData();
         switch(SmtpXYZdigits())
         {
            case 250:
               bAccepted = true;
               break;
            default:
               ; // not necessary to throw
         }
      }while(!bAccepted);
   }
   
   // DATA <CRLF>
   strcpy(SendBuf,"DATA\r\n");
   SendData();
   bAccepted = false;
   do
   {
      ReceiveData();
      switch(SmtpXYZdigits())
      {
         case 354:
            bAccepted = true;
            break;
         case 250:
            break;
         default:
            throw ECSmtp(ECSmtp::COMMAND_DATA);
      }
   }while(!bAccepted);
   
   // send header(s)
   FormatHeader(SendBuf);
   SendData();

   // send text message
   if(GetMsgLines())
   {
      for(i=0;i<GetMsgLines();i++)
      {
         sprintf(SendBuf,"%s\r\n",GetMsgLineText(i));
         SendData();
      }
   }
   else
   {
      sprintf(SendBuf,"%s\r\n"," ");
      SendData();
   }

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
   
   // <CRLF> . <CRLF>
   strcpy(SendBuf,"\r\n.\r\n");
   SendData();
   bAccepted = false;
   do
   {
      ReceiveData();
      switch(SmtpXYZdigits())
      {
         case 250:
            bAccepted = true;
            break;
         default:
            throw ECSmtp(ECSmtp::MSG_BODY_ERROR);
      }
   }while(!bAccepted);

   // ***** CLOSING CONNECTION *****
   
   // QUIT <CRLF>
   strcpy(SendBuf,"QUIT\r\n");
   SendData();
   bAccepted = false;
   do
   {
      ReceiveData();
      switch(SmtpXYZdigits())
      {
         case 221:
            bAccepted = true;
            break;
         default:
            throw ECSmtp(ECSmtp::COMMAND_QUIT);
      }
   }while(!bAccepted);

#ifdef LINUX
   close(hSocket);
#else
   closesocket(hSocket);
#endif
   hSocket = NULL;
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
//        NAME: SmtpXYZdigits
// DESCRIPTION: Converts three letters from RecvBuf to the number.
//   ARGUMENTS: none
// USES GLOBAL: RecvBuf
// MODIFIES GL: none
//     RETURNS: integer number
//      AUTHOR: Jakub Piwowarczyk
// AUTHOR/DATE: JP 2010-01-28
////////////////////////////////////////////////////////////////////////////////
int CSmtp::SmtpXYZdigits()
{
   assert(RecvBuf);
   if(RecvBuf == NULL)
      return 0;
   return (RecvBuf[0]-'0')*100 + (RecvBuf[1]-'0')*10 + RecvBuf[2]-'0';
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

