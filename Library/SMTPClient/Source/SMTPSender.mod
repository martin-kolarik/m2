IMPLEMENTATION MODULE SMTPSender;

FROM Storage IMPORT
   ALLOCATE, DEALLOCATE;

FROM Debug IMPORT
   Assertion, LogAssertionW;

FROM Exceptions IMPORT
   StoreException, RetrieveException, TestIfCatched;

IMPORT
   cphcommonO,
   dns,
   Exceptions,
   IOO,
   languages,
   languagesO,
   msgqueue,
   netsocket,
   rawconnection,
   SmtpTools,
   StorageO,
   StringsO,
   TextReader,
   TextWriter,
   threadpool;

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

   PUBLIC VIRTUAL PROCEDURE Send( CONST message : MailMessage.TPMailMessage; takeOwnership : BOOLEAN ) : Sync.TAsyncResult;

   PUBLIC VIRTUAL PROPERTY
      Server : StringsO.CString;
      Mailer : StringsO.CString;
      Login : StringsO.CString; 
      Password : StringsO.CString; 
      TimeToLive : CARDINAL; // milliseconds, the message will stay in the queue for the time

   // SELF
   LOCAL READONLY PROPERTY
      LocalName : StringsO.CString;
   LOCAL PROPERTY
      LightWeight : BOOLEAN;

   LOCAL PROCEDURE NotifyCompletion( CONST message : MailMessage.TPMailMessage; Result : Sync.TAsyncResult; SmtpPhase : SmtpTools.TSmtpPhase );
   PRIVATE PROCEDURE DoSend( CONST message : MailMessage.TPMailMessage ) : Sync.TAsyncResult;

   PRIVATE VAR
      _LightWeight : BOOLEAN := TRUE;
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
   PUBLIC PROCEDURE DoSend( OUT SmtpPhase : SmtpTools.TSmtpPhase ) : Sync.TAsyncResult;

   PRIVATE VAR
      _Sender : TPSenderImpl := NIL;
      _Message : MailMessage.TPMailMessage := NIL;
      _Connection : rawconnection.ClientTCPConnection;
      _Reader : TextReader.CTextReader;
      _Writer : TextWriter.CTextWriter;

   PRIVATE PROCEDURE NotifyCompletion( Result : Sync.TAsyncResult; SmtpPhase : SmtpTools.TSmtpPhase );

   PRIVATE PROCEDURE ReadServer() : SmtpTools.TSmtpResponse THROWS CSmtpException;
   PRIVATE PROCEDURE ReadServerLine( OUT SMTPResponse : SmtpTools.TSmtpResponse; OUT Response : StringsO.IString; OUT LastLine : BOOLEAN ) : Sync.TAsyncResult;
   PRIVATE PROCEDURE WriteServer( CONST Line : StringsO.IString ) THROWS CSmtpException;
   PRIVATE PROCEDURE WriteServerBase64( CONST Line : StringsO.IString ) THROWS CSmtpException;
   PRIVATE PROCEDURE Authenticate() THROWS CSmtpException;
   PRIVATE PROCEDURE WriteRecipients( recipients : MailMessage.TPPersons ) THROWS CSmtpException; // TODO distinguish between complete send and send only some, grab failures to some list or so
   PRIVATE PROCEDURE WriteHeaders() THROWS CSmtpException;
   PRIVATE PROCEDURE FillHeaderRecipients( CONST header : ARRAY OF WCHAR; recipients : MailMessage.TPPersons; OUT output : StringsO.IString );
   PRIVATE PROCEDURE AddPersonToHeader( REF header : StringsO.IString; CONST person : MailMessage.Person );
   PRIVATE PROCEDURE CorrectCharset( REF header : StringsO.IString ) : BOOLEAN;
   PRIVATE PROCEDURE WriteStreamBase64( Stream : IOO.TPStream ) THROWS CSmtpException;

END CWorker;

(*================================================================================*)

CLASS IMPLEMENTATION CWorker;

(*--------------------------------------------------------------------------------*)

   LOCAL VIRTUAL PROCEDURE Run();
   VAR
      Result : Sync.TAsyncResult;
      SmtpPhase : SmtpTools.TSmtpPhase := SmtpTools.ClientConnect;
   BEGIN
      Result := DoSend( OUT SmtpPhase );
      NotifyCompletion( Result, SmtpPhase );
   END Run;

(*--------------------------------------------------------------------------------*)

   PUBLIC PROCEDURE Init( sender : TPSenderImpl; CONST message : MailMessage.TPMailMessage );
   BEGIN
      _Sender := sender;
      _Message := message;
   END Init;

(*--------------------------------------------------------------------------------*)

   PUBLIC PROCEDURE DoSend( OUT SmtpPhase : SmtpTools.TSmtpPhase ) : Sync.TAsyncResult;
   VAR
      recipients : MailMessage.TPPersons;
      Result : Sync.TAsyncResult;
      s : StringsO.CString;
      smtpres : SmtpTools.TSmtpResponse;
   BEGIN
      TRY
         //----------
         SmtpPhase := SmtpTools.ClientConnect;
         Result := _Connection.OpenS( _Sender^.Server, TRUE, netsocket.FORSAFETY );
         IF Result <> Sync.arCompleted THEN
            RETURN Sync.arAborted;
         END;

         //----------
         SmtpPhase := SmtpTools.ServerConnect;
         IF ReadServer() <> SmtpTools.smtpres_220 THEN
            RETURN Sync.arAborted;
         END;

         //----------
         SmtpPhase := SmtpTools.Ehlo;
         s.FromOA( L"EHLO " );
         s.Append( _Sender^.LocalName );
         WriteServer( s );
         IF ReadServer() <> SmtpTools.smtpres_OK THEN
            RETURN Sync.arAborted;
         END;

         //----------
         SmtpPhase := SmtpTools.AuthenticationFailed;
         Authenticate(); // if authentication is not needed, the method does nothing

         //----------
         SmtpPhase := SmtpTools.MailFrom;

         // TODO, MailFrom nesmí být empty
         s.FromOA( L"MAIL FROM: " );
         s.Append( _Message^.Sender.Address );
         WriteServer( s );
         smtpres := ReadServer();
         CASE smtpres OF
         | SmtpTools.smtpres_OK : // OK, success
         | SmtpTools.smtpres_530 : // authentication required
            SmtpPhase := SmtpTools.AuthenticationRequired;
            RETURN Sync.arFailed;
         ELSE
            RETURN Sync.arAborted;
         END;

         //----------
         SmtpPhase := SmtpTools.RcptTo;
         // TODO, at least one recipient must be known
         WriteRecipients( _Message^.Recipients );
         WriteRecipients( _Message^.CCs );
         WriteRecipients( _Message^.BCCs );

         //----------
         SmtpPhase := SmtpTools.StartData;
         s.FromOA( L"DATA" );
         WriteServer( s );
         IF ReadServer() <> SmtpTools.smtpres_354 THEN
            RETURN Sync.arAborted;
         END;

         //----------
         _Connection.BufferedStream^.WMode := IOO.bmCache; // construct the response inside memory, send by chunks

         SmtpPhase := SmtpTools.Headers;
         WriteHeaders();
         // finish headers
         s.Clear();
         WriteServer( s );

         _Connection.BufferedStream^.WMode := IOO.bmChunked; // revert stream back
         _Connection.BufferedStream^.CommitWrite(); // and send all buffered now

         //----------
         SmtpPhase := SmtpTools.MessageBody;
         WriteStreamBase64( _Message^.Body );

         //----------
         SmtpPhase := SmtpTools.MessageAttachments;
         IF NOT _Message^.Attachments^.Empty THEN
         END;

         //----------
         SmtpPhase := SmtpTools.MessageFinalization;
         s.FromOA( 13W + 10W + L"." ); // the second CRLF appends WriteServer
         WriteServer( s );
         IF ReadServer() <> SmtpTools.smtpres_OK THEN
            RETURN Sync.arAborted;
         END;

         //----------
         SmtpPhase := SmtpTools.ConnectionFinalization;
         s.FromOA( L"QUIT" );
         WriteServer( s );
         IF ReadServer() <> SmtpTools.smtpres_221 THEN
            RETURN Sync.arAborted;
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

      FINALLY
         _Connection.Close();
      END;
   
      RETURN Sync.arCompleted;
   END DoSend;

(*--------------------------------------------------------------------------------*)

   PRIVATE PROCEDURE NotifyCompletion( Result : Sync.TAsyncResult; SmtpPhase : SmtpTools.TSmtpPhase );
   BEGIN
      // _Sender^.NotifyCompletion( _Message, Result, SmtpPhase );
   END NotifyCompletion;

(*--------------------------------------------------------------------------------*)

   PRIVATE PROCEDURE ReadServer() : SmtpTools.TSmtpResponse;
   VAR
      current : SmtpTools.TSmtpResponse := SmtpTools.smtpres_Unknown;
      first : SmtpTools.TSmtpResponse := SmtpTools.smtpres_Unknown;
      lastline : BOOLEAN := FALSE;
      line : StringsO.CString;
      Result : Sync.TAsyncResult;
   BEGIN
      REPEAT
         Result := ReadServerLine( OUT current, OUT line, OUT lastline );
         IF Result <> Sync.arCompleted THEN
            THROW SmtpException( Result );
         ELSIF first = SmtpTools.smtpres_Unknown THEN
            first := current;
         ELSIF current <> first THEN // responses must be uniform for single command
            THROW SmtpException( Sync.arAborted );
         END;
      UNTIL lastline;

      RETURN current;
   END ReadServer;

(*--------------------------------------------------------------------------------*)

   PRIVATE PROCEDURE ReadServerLine( OUT SmtpResponse : SmtpTools.TSmtpResponse; OUT Response : StringsO.IString; OUT LastLine : BOOLEAN ) : Sync.TAsyncResult;
   VAR
      Read : StringsO.CString;
      Result : Sync.TAsyncResult;
   BEGIN
      Result := _Reader.ReadLine( OUT Read, netsocket.FORSAFETY, TRUE );
      IF Result <> Sync.arCompleted THEN
         RETURN Result;
      END;

      SmtpResponse := SmtpTools.StringToResponse( Read );
      IF SmtpResponse = SmtpTools.smtpres_Unknown THEN
         RETURN Sync.arAborted;
      END;

      Response.Assign( Read );
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
   VAR
      base64Line : StringsO.CString;
      buffer : StorageO.CMemoryBuffer;
   BEGIN
      languagesO.ToMB( Line, languages.cp_UTF8, FALSE, REF buffer );
      cphcommonO.ToBASE64( buffer, OUT base64Line );
      TRY
         WriteServer( base64Line );
      CATCH e : CSmtpException DO
         THROW e;
      END;
   END WriteServerBase64;

(*--------------------------------------------------------------------------------*)

   PRIVATE PROCEDURE Authenticate();
   VAR
      s : StringsO.CString;
      smtpres : SmtpTools.TSmtpResponse;
   BEGIN
      IF _Sender^.Login.Empty THEN
         RETURN;
      END;

      TRY
         s.FromOA( L"AUTH LOGIN" );
         WriteServer( s );
         IF ReadServer() <> SmtpTools.smtpres_334 THEN // TODO: check if "UserName" is requested
            THROW SmtpException( Sync.arAborted );
         END;

         // send login
         WriteServerBase64( _Sender^.Login );
         IF ReadServer() <> SmtpTools.smtpres_334 THEN // TODO: check if "Password" is requested
            THROW SmtpException( Sync.arAborted );
         END;

         // send password
         WriteServerBase64( _Sender^.Password );
         smtpres := ReadServer();
         CASE smtpres OF
         | SmtpTools.smtpres_235 : // OK, success
         | SmtpTools.smtpres_535 : // not authorized
            THROW SmtpException( Sync.arFailed );
         ELSE
            THROW SmtpException( Sync.arAborted );
         END;

      CATCH e : CSmtpException DO
         THROW e;
      END;
   END Authenticate;

(*--------------------------------------------------------------------------------*)

   PRIVATE PROCEDURE WriteRecipients( recipients : MailMessage.TPPersons ); // TODO distinguish between complete send and send only some, grab failures to some list or so
   VAR
      s : StringsO.CString;
      smtpres : SmtpTools.TSmtpResponse;
   BEGIN
      TRY
         recipients^.Reset();
         WHILE recipients^.MoveNext() DO
            s.FromOA( "RCPT TO: " );
            s.Append( recipients^.Current.Address );
            WriteServer( s );
            smtpres := ReadServer();
            IF smtpres <> SmtpTools.smtpres_OK THEN
               THROW SmtpException( Sync.arAborted );
            END;
         END; // WHILE
      CATCH e : CSmtpException DO
         THROW e;
      END;
   END WriteRecipients;

(*--------------------------------------------------------------------------------*)

   PRIVATE PROCEDURE WriteHeaders();
   VAR
      data : StringsO.CString;
      header : StringsO.CString;
      person : MailMessage.Person;
      recipients : MailMessage.TPPersons;
      sOA : ARRAY [0..31] OF WCHAR;
   BEGIN
      TRY
         WriteServer( StringsO.FromOA( L"Message-Id: xxx@email.cz" ));

         // Date: <SP> <dd> <SP> <mon> <SP> <yy> <SP> <hh> ":" <mm> ":" <ss> <SP> <zone> <CRLF>
         IF NOT _Message^.Created.ToLanguageStringOA( languages.GetDefaultLanguage( languages.dlNeutral ), L"ddd, d MMM yyyy HH:mm:ss", TRUE, TRUE, OUT sOA ) THEN
            THROW SmtpException( Sync.arAborted );
         END;
         header.FromOA( L"Date: " ); header.AppendOA( sOA ); header.AppendOA( L" +0000" );
         WriteServer( header );
   
         // From: <SP> <sender>  <SP> "<" <sender-email> ">" <CRLF>
         header.FromOA( L"From: " );
         AddPersonToHeader( REF header, _Message^.Sender );
         WriteServer( header );

         // Reply-To: <SP> <reverse-path> <CRLF>
         person := _Message^.ReplyTo;
         IF NOT person.Address.Empty THEN
            header.FromOA( L"Reply-To: " );
            AddPersonToHeader( REF header, person );
            WriteServer( header );
         END;

         // X-Mailer: <SP> <xmailer-app> <CRLF>
         data := _Sender^.Mailer;
         IF NOT data.Empty THEN
            header.FromOA( L"X-Mailer: " );
            header.Append( data );
            WriteServer( header );
         END;

         // X-Priority: <SP> <number> <CRLF>
         CASE _Message^.Priority OF
         | MailMessage.PriorityLow :
            header.FromOA( L"X-Priority: 4 (Low)" );
         | MailMessage.PriorityNormal :
            header.FromOA( L"X-Priority: 3 (Normal)" );
         | MailMessage.PriorityHigh :
            header.FromOA( L"X-Priority: 2 (High)" );
         ELSE
            ASSERTLOG( FALSE, L"Unrecognized priority" );
            header.FromOA( L"X-Priority: 3 (Normal)" );
         END;
         WriteServer( header );

         // To: <SP> <remote-user-mail> <CRLF>
         recipients := _Message^.Recipients;
         IF NOT recipients^.Empty THEN
            FillHeaderRecipients( L"To: ", recipients, OUT data );
            WriteServer( data );
         END;

         // Cc: <SP> <remote-user-mail> <CRLF>
         recipients := _Message^.CCs;
         IF NOT recipients^.Empty THEN
            FillHeaderRecipients( L"Cc: ", recipients, OUT data );
            WriteServer( data );
         END;

         // Bcc: <SP> <remote-user-mail> <CRLF>
         recipients := _Message^.BCCs;
         IF NOT recipients^.Empty THEN
            FillHeaderRecipients( L"Bcc: ", recipients, OUT data );
            WriteServer( data );
         END;

         // Subject: <SP> <subject-text> <CRLF>
         header.FromOA( L"Subject: " );
         data := _Message^.Subject;
         IF data.Empty THEN
            header.AppendOA( L" " );
         ELSE
            SmtpTools.AppendStringToHeader( REF header, data, SmtpTools.StringTypeHintNone );
         END;
         WriteServer( header );
   
         // MIME-Version: <SP> 1.0 <CRLF>
         header.FromOA( L"MIME-Version: 1.0" );
         WriteServer( header );

         // MIME headers
         data := _Message^.BodyMimeType;
         IF data.Empty THEN
            header.FromOA( L"Content-Type: text/plain; charset=utf-8; format=flowed" );
         ELSE
            header.FromOA( L"Content-Type: " );
            header.Append( data );
            IF NOT CorrectCharset( REF header ) THEN
               THROW SmtpException( Sync.arAborted );
            END;
         END;
         WriteServer( header );
         header.FromOA( L"Content-Transfer-Encoding: base64" );
         WriteServer( header );

         (*
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
         *)

      CATCH e : CSmtpException DO
         THROW e;
      END;
   END WriteHeaders;

(*--------------------------------------------------------------------------------*)

   PRIVATE PROCEDURE FillHeaderRecipients( CONST header : ARRAY OF WCHAR; recipients : MailMessage.TPPersons; OUT output : StringsO.IString );
   BEGIN
      output.Clear();
      recipients^.Reset();
      WHILE recipients^.MoveNext() DO
         IF output.Empty THEN
            output.FromOA( header );
         ELSE
            output.AppendOA( L"," );
         END;
         AddPersonToHeader( REF output, recipients^.Current );
      END; // WHILE
   END FillHeaderRecipients;

(*--------------------------------------------------------------------------------*)

   PRIVATE PROCEDURE AddPersonToHeader( REF header : StringsO.IString; CONST person : MailMessage.Person );
   VAR
      s : StringsO.CString;
   BEGIN
      s := person.Name;
      IF NOT s.Empty THEN
         SmtpTools.AppendStringToHeader( REF header, s, SmtpTools.StringTypeHintQuoted );
         header.AppendOA( L" " );
      END;
      SmtpTools.AppendStringToHeader( REF header, person.Address, SmtpTools.StringTypeHintAddress );
   END AddPersonToHeader;

(*--------------------------------------------------------------------------------*)

   PRIVATE PROCEDURE CorrectCharset( REF header : StringsO.IString ) : BOOLEAN;
   VAR
      i, j : CARDINAL;
   BEGIN
      i := header.IndexOfOA( L"charset", 0 );
      IF i = -1 THEN
         header.AppendOA( L"; charset=utf-8" );
      ELSE
         j := header.IndexOfOA( L";", i );
         IF j = -1 THEN // malformed, reject the header
            RETURN FALSE;
         END;
         i := header.IndexOfOA( L"=", i );
         IF i = -1 THEN // malformed, reject the header
            RETURN FALSE;
         ELSIF i > j THEN // malformed, reject the header
            RETURN FALSE;
         END;
         header.Remove( i+1, j-i-1 );
         header.InsertOA( i+1, L"utf-8" );
      END;
      RETURN TRUE;
   END CorrectCharset;

(*--------------------------------------------------------------------------------*)

   PRIVATE PROCEDURE WriteStreamBase64( Stream : IOO.TPStream );
   BEGIN
      TRY
         // WriteServerBase64( StringsO.FromOA( L"Ahoj" ));
      CATCH e : CSmtpException DO
         THROW e;
      END;
   END WriteStreamBase64;

(*--------------------------------------------------------------------------------*)

BEGIN
   _Reader.Stream := _Connection.BufferedStream;
   _Writer.Stream := _Connection.BufferedStream;
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

   PUBLIC VIRTUAL PROCEDURE Send( CONST message : MailMessage.TPMailMessage; takeOwnership : BOOLEAN ) : Sync.TAsyncResult;
   BEGIN
      IF _LightWeight THEN
         RETURN DoSend( message );
      ELSE
         IF _PoolHandle = NIL THEN
            RETURN Sync.arCannotStart;
         END;
         _Queue.Enqueue( message OR PTR( takeOwnership ));
         RETURN Sync.arPending;
      END;
   END Send;

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

   LOCAL PROPERTY LightWeight GET : BOOLEAN;
   BEGIN
      RETURN _LightWeight;
   END LightWeight;

(*--------------------------------------------------------------------------------*)

   LOCAL PROPERTY LightWeight SET( Value : BOOLEAN );
   BEGIN
      _LightWeight := Value;
   END LightWeight;

(*--------------------------------------------------------------------------------*)

   LOCAL PROCEDURE NotifyCompletion( CONST message : MailMessage.TPMailMessage; Result : Sync.TAsyncResult; SmtpPhase : SmtpTools.TSmtpPhase );
   BEGIN
   END NotifyCompletion;

(*--------------------------------------------------------------------------------*)

   PRIVATE PROCEDURE DoSend( CONST message : MailMessage.TPMailMessage ) : Sync.TAsyncResult;
   VAR
      result : Sync.TAsyncResult;
      smtpPhase : SmtpTools.TSmtpPhase;
      worker : POINTER TO CWorker;
   BEGIN
      NEW( worker );
      worker^.Init( ADR( SELF ), message );
      IF _LightWeight THEN
         result := worker^.DoSend( OUT smtpPhase );
      ELSE // run it in the pool
         // result := 
      END;
      RETURN result;
   END DoSend;

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
//        NAME: GetErrorText (friend function)
// DESCRIPTION: Returns the string for specified error code.
//   ARGUMENTS: CSmtpPhase ErrorId - error code
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
VAR
   senderImpl : TPSenderImpl;
BEGIN
   NEW( senderImpl );
   senderImpl^.LightWeight := lightWeight;
   sender := senderImpl;
   RETURN TRUE;
END New;

(*--------------------------------------------------------------------------------*)

PROCEDURE Dispose( REF sender : TPSender );
VAR
   senderImpl : TPSenderImpl;
BEGIN
   IF sender = NIL THEN
      // do nothing
   ELSIF sender^ IS CSender THEN
      senderImpl := TPSenderImpl( sender );
      senderImpl^.Release();
      senderImpl := NIL;
   ELSE
      ASSERTLOG( FALSE, L"Bad deallocation" );
   END;
END Dispose;

(*================================================================================*)

END SMTPSender.