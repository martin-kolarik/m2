IMPLEMENTATION MODULE SMTPSender;

FROM Storage IMPORT
   ALLOCATE, DEALLOCATE;

FROM Debug IMPORT
   Assertion, LogAssertionW;

FROM Exceptions IMPORT
   StoreException, RetrieveException, TestIfCatched;

IMPORT
   cphcommon,
   cphcommonO,
   datetime,
   dns,
   Exceptions,
   FIO,
   FIOO,
   hash,
   IOO,
   languages,
   languagesO,
   lists,
   msgqueue,
   netsocket,
   PersonsImpl,
   rawconnection,
   SmtpTools,
   StorageO,
   Strings,
   StringsO,
   TextReader,
   TextWriter,
   thread,
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
   TPQueueItem = POINTER TO CQueueItem;

CLASS CQueueItem;
   LOCAL VAR
      Message : MailMessage.TPMailMessage := NIL;
      Ownership : BOOLEAN := FALSE;
      Status : Sync.TAsyncResult := Sync.arInitial;
      NextSendTime : datetime.DateTime;
END CQueueItem;

(*--------------------------------------------------------------------------------*)

CLASS IMPLEMENTATION CQueueItem;
BEGIN
END CQueueItem;

(*--------------------------------------------------------------------------------*)

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
      GenerateMessageId : BOOLEAN;

   // SELF
   LOCAL READONLY PROPERTY
      LocalName : StringsO.CString;
   LOCAL PROPERTY
      LightWeight : BOOLEAN;

   LOCAL PROCEDURE NotifyCompletion( CONST message : MailMessage.TPMailMessage; Result : Sync.TAsyncResult; SmtpPhase : SmtpTools.TSmtpPhase; CONST failedRecipients : MailPerson.IPersons );
   PRIVATE PROCEDURE DoSend( queueItem : TPQueueItem ) : Sync.TAsyncResult;
   PRIVATE PROCEDURE SendMessagesForFirst();
   PRIVATE PROCEDURE ResendMessagesAndCleanupQueue();

   PRIVATE VAR
      _LightWeight : BOOLEAN := TRUE;
      _GenerateMessageId : BOOLEAN := TRUE;
      _Server : StringsO.CString;
      _Mailer : StringsO.CString;
      _Login : StringsO.CString; 
      _Password : StringsO.CString; 
      _LocalName : StringsO.CString;
      _Lock : Sync.RWLOCK;
      _IncomingQueueSignal : Sync.SIGNAL;
      _IncomingQueue : msgqueue.CPtrQueue;
      _Queue : lists.CPtrList;
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
   PUBLIC PROCEDURE Init( sender : TPSenderImpl; CONST queueItem : TPQueueItem );
   PUBLIC PROCEDURE DoSend( OUT SmtpPhase : SmtpTools.TSmtpPhase ) : Sync.TAsyncResult;

   PRIVATE VAR
      _Sender : TPSenderImpl := NIL;
      _QueueItem : TPQueueItem := NIL;
      _Message : MailMessage.TPMailMessage := NIL;
      _Connection : rawconnection.ClientTCPConnection;
      _Reader : TextReader.CTextReader;
      _Writer : TextWriter.CTextWriter;
      _Boundary : StringsO.CString;
      _FailedRecipients : PersonsImpl.CPersonsImpl;

   PRIVATE PROCEDURE NotifyCompletion( Result : Sync.TAsyncResult; SmtpPhase : SmtpTools.TSmtpPhase );

   PRIVATE PROCEDURE ReadServer( lastResponseLine : StringsO.TPString ) : SmtpTools.TSmtpResponse THROWS CSmtpException; // lastResponseLine is optional
   PRIVATE PROCEDURE ReadServerLine( OUT SMTPResponse : SmtpTools.TSmtpResponse; OUT Response : StringsO.IString; OUT LastLine : BOOLEAN ) : Sync.TAsyncResult;
   PRIVATE PROCEDURE WriteServer( CONST Line : StringsO.IString ) THROWS CSmtpException;
   PRIVATE PROCEDURE WriteServerBase64( CONST Line : StringsO.IString ) THROWS CSmtpException;
   PRIVATE PROCEDURE Authenticate() THROWS CSmtpException;
   PRIVATE PROCEDURE WriteRecipients( recipients : MailPerson.TPPersons ) THROWS CSmtpException;
   PRIVATE PROCEDURE WriteHeaders() THROWS CSmtpException;
   PRIVATE PROCEDURE FillHeaderRecipients( CONST header : ARRAY OF WCHAR; recipients : MailPerson.TPPersons; OUT output : StringsO.IString );
   PRIVATE PROCEDURE AddPersonToHeader( REF header : StringsO.IString; CONST person : MailPerson.Person );
   PRIVATE PROCEDURE CorrectCharset( REF header : StringsO.IString ) : BOOLEAN;
   PRIVATE PROCEDURE WriteStreamBase64( Stream : IOO.TPStream; StreamIsText : BOOLEAN ) THROWS CSmtpException;
   PRIVATE PROCEDURE CreateMessageId( OUT messageId : StringsO.IString );
   PRIVATE PROCEDURE WriteMimeHeader( CONST givenHeader : StringsO.IString; CONST defaultHeader : ARRAY OF WCHAR; appendAlways : StringsO.TPString; correctCharset : BOOLEAN ) THROWS CSmtpException;
   PRIVATE PROCEDURE WriteAttachments() THROWS CSmtpException;

END CWorker;

(*================================================================================*)

CLASS IMPLEMENTATION CWorker;

(*--------------------------------------------------------------------------------*)

   LOCAL VIRTUAL PROCEDURE Run();
   VAR
      recipients : MailPerson.TPPersons;
      Result : Sync.TAsyncResult;
      SmtpPhase : SmtpTools.TSmtpPhase := SmtpTools.ClientConnect;
   BEGIN
      Result := DoSend( OUT SmtpPhase );

      IF _Message^.GrabFailedRecipients AND ( Result <> Sync.arCompleted ) THEN // fill failed recipients with all known recipients
         _FailedRecipients.Dispose();
         recipients := _Message^.Recipients;
         recipients^.Reset();
         WHILE recipients^.MoveNext() DO
            _FailedRecipients.Add( recipients^.Current );
         END;
         recipients := _Message^.CCs;
         recipients^.Reset();
         WHILE recipients^.MoveNext() DO
            _FailedRecipients.Add( recipients^.Current );
         END;
         recipients := _Message^.BCCs;
         recipients^.Reset();
         WHILE recipients^.MoveNext() DO
            _FailedRecipients.Add( recipients^.Current );
         END;
      END;

      NotifyCompletion( Result, SmtpPhase );
   END Run;

(*--------------------------------------------------------------------------------*)

   PUBLIC PROCEDURE Init( sender : TPSenderImpl; CONST queueItem : TPQueueItem );
   BEGIN
      _Sender := sender;
      _QueueItem := queueItem;
      _Message := queueItem^.Message;
   END Init;

(*--------------------------------------------------------------------------------*)

   PUBLIC PROCEDURE DoSend( OUT SmtpPhase : SmtpTools.TSmtpPhase ) : Sync.TAsyncResult;
   VAR
      recipients : MailPerson.TPPersons;
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
         IF ReadServer( NIL ) <> SmtpTools.smtpres_220 THEN
            RETURN Sync.arAborted;
         END;

         //----------
         SmtpPhase := SmtpTools.Ehlo;
         s.FromOA( L"EHLO " );
         s.Append( _Sender^.LocalName );
         WriteServer( s );
         IF ReadServer( NIL ) <> SmtpTools.smtpres_OK THEN
            RETURN Sync.arAborted;
         END;

         //----------
         SmtpPhase := SmtpTools.AuthenticationFailed;
         Authenticate(); // if authentication is not needed, the method does nothing

         //----------
         SmtpPhase := SmtpTools.MailFrom;
         s.FromOA( L"MAIL FROM: " );
         s.Append( _Message^.Sender.Address );
         WriteServer( s );
         smtpres := ReadServer( NIL );
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
         WriteRecipients( _Message^.Recipients );
         WriteRecipients( _Message^.CCs );
         WriteRecipients( _Message^.BCCs );

         //----------
         SmtpPhase := SmtpTools.StartData;
         s.FromOA( L"DATA" );
         WriteServer( s );
         IF ReadServer( NIL ) <> SmtpTools.smtpres_354 THEN
            RETURN Sync.arAborted;
         END;

         //----------
         // headers
         _Connection.BufferedStream^.WMode := IOO.bmCache; // construct the response inside memory, send by chunks

         SmtpPhase := SmtpTools.Headers;
         WriteHeaders();

         // header of body, write it always, it emits CRLF after header too -- data can immediately follow
         WriteMimeHeader( _Message^.BodyMimeType, L"text/plain; charset=utf-8; format=flowed; delsp=yes", NIL, TRUE );

         _Connection.BufferedStream^.WMode := IOO.bmChunked; // revert stream back
         _Connection.BufferedStream^.CommitWrite(); // and send all buffered now

         //----------
         SmtpPhase := SmtpTools.MessageBody;
         WriteStreamBase64( _Message^.Body, TRUE );

         //----------
         SmtpPhase := SmtpTools.MessageAttachments;
         WriteAttachments();

         //----------
         SmtpPhase := SmtpTools.MessageFinalization;
         s.FromOA( 13W + 10W + L"." ); // the second CRLF appends WriteServer
         WriteServer( s );
         IF ReadServer( NIL ) <> SmtpTools.smtpres_OK THEN
            RETURN Sync.arAborted;
         END;

         //----------
         SmtpPhase := SmtpTools.ConnectionFinalization;
         s.FromOA( L"QUIT" );
         WriteServer( s );
         IF ReadServer( NIL ) <> SmtpTools.smtpres_221 THEN
            RETURN Sync.arAborted;
         END;

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

   PRIVATE PROCEDURE ReadServer( lastResponseLine : StringsO.TPString ) : SmtpTools.TSmtpResponse;
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

      IF lastResponseLine <> NIL THEN
         lastResponseLine^.Assign( line );
      END;
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
      base64 : StringsO.CString;
      buffer : StorageO.CMemoryBuffer;
      s : StringsO.CString;
      smtpres : SmtpTools.TSmtpResponse;
   BEGIN
      IF _Sender^.Login.Empty THEN
         RETURN;
      END;

      TRY
         s.FromOA( L"AUTH LOGIN" );
         WriteServer( s );
         IF ReadServer( ADR( s )) <> SmtpTools.smtpres_334 THEN
            THROW SmtpException( Sync.arAborted );
         END;
         s.Substring( 4, -1, OUT base64 );
         cphcommonO.FromBASE64( base64, FALSE, REF buffer );
         languagesO.FromMB( buffer, languages.cp_UTF8, OUT s );
         IF NOT s.EqualsOA( L"Username:" ) THEN
            THROW SmtpException( Sync.arAborted );
         END;

         // send login
         WriteServerBase64( _Sender^.Login );
         IF ReadServer( ADR( s )) <> SmtpTools.smtpres_334 THEN
            THROW SmtpException( Sync.arAborted );
         END;
         s.Substring( 4, -1, OUT base64 );
         cphcommonO.FromBASE64( base64, FALSE, REF buffer );
         languagesO.FromMB( buffer, languages.cp_UTF8, OUT s );
         IF NOT s.EqualsOA( L"Password:" ) THEN
            THROW SmtpException( Sync.arAborted );
         END;

         // send password
         WriteServerBase64( _Sender^.Password );
         smtpres := ReadServer( NIL );
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

   PRIVATE PROCEDURE WriteRecipients( recipients : MailPerson.TPPersons );
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
            smtpres := ReadServer( NIL );
            IF _Message^.GrabFailedRecipients AND ( smtpres <> SmtpTools.smtpres_OK ) THEN
               _FailedRecipients.Add( recipients^.Current );
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
      messageId : StringsO.CString;
      person : MailPerson.Person;
      recipients : MailPerson.TPPersons;
      sOA : ARRAY [0..31] OF WCHAR;
   BEGIN
      TRY
         CreateMessageId( OUT messageId );

         IF _Sender^.GenerateMessageId THEN
            header.FromOA( L"Message-Id: " );
            header.Append( messageId );
            WriteServer( header );
         END;

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
            header.FromOA( L"X-Priority: 4" );
         | MailMessage.PriorityNormal :
            header.FromOA( L"X-Priority: 3" );
         | MailMessage.PriorityHigh :
            header.FromOA( L"X-Priority: 2" );
         ELSE
            ASSERTLOG( FALSE, L"Unrecognized priority" );
            header.FromOA( L"X-Priority: 3" );
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
            SmtpTools.AppendStringToHeader( REF header, data, SmtpTools.HintSubject );
         END;
         WriteServer( header );
   
         // MIME-Version: <SP> 1.0 <CRLF>
         header.FromOA( L"MIME-Version: 1.0" );
         WriteServer( header );

         // MIME headers -- prepare self for multipart messages
         _Boundary.FromOA( L"--_=_001.nxp_" );
         _Boundary.Append( messageId );
         _Boundary.AppendOA( L"_=_--" );

         IF NOT _Message^.Attachments^.Empty THEN // create a multipart header followed by header of message body
            header.FromOA( L"Content-Type: multipart/mixed;" + 13W + 10W + ' boundary="' );
            header.Append( _Boundary );
            header.AppendOA( L'"' );
            WriteServer( header );

            // write a boundary of message contents
            header.FromOA( 13W + 10W + L"--" ); 
            header.Append( _Boundary );
            WriteServer( header );
         END;

      CATCH e : CSmtpException DO
         THROW e;
      END;
   END WriteHeaders;

(*--------------------------------------------------------------------------------*)

   PRIVATE PROCEDURE FillHeaderRecipients( CONST header : ARRAY OF WCHAR; recipients : MailPerson.TPPersons; OUT output : StringsO.IString );
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

   PRIVATE PROCEDURE AddPersonToHeader( REF header : StringsO.IString; CONST person : MailPerson.Person );
   VAR
      s : StringsO.CString;
   BEGIN
      s := person.Name;
      IF NOT s.Empty THEN
         SmtpTools.AppendStringToHeader( REF header, s, SmtpTools.HintPersonName );
         header.AppendOA( L" " );
      END;
      SmtpTools.AppendStringToHeader( REF header, person.Address, SmtpTools.HintPersonAddress );
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

   PRIVATE PROCEDURE WriteStreamBase64( Stream : IOO.TPStream; StreamIsText : BOOLEAN );
   CONST
      RFC822_LINE_LENGTH = 78;
      RFC822_CHUNK = RFC822_LINE_LENGTH - 2; // 2 for CRLF
   VAR
      base64 : StringsO.CString;
      dstString : StringsO.CString; // dstString acts as a buffer which evens input against output flushed by whole lines
      dstStringSlice : StringsO.CString;
      granularity : CARDINAL := cphcommon.BASE64InputGranularity();
      index : CARDINAL;
      inputBufferSize : CARDINAL;
      length : CARDINAL;
      srcString : StringsO.CString;
      srcBuffer : StorageO.CMemoryBuffer; // srcBuffer buffers evens BINARY input against BASE64 output flushed by triples of bytes
      utf8Buffer : StorageO.CMemoryBuffer; // utf8Buffer buffers evens TEXTUAL input against BASE64 output flushed by triples of bytes
      pbuffer : StorageO.TPMemoryBuffer;
      Result : Sync.TAsyncResult;
   BEGIN
      inputBufferSize := MIN2( 2048, Stream^.Length32 );
      IF StreamIsText THEN
         srcString.Size := inputBufferSize DIV SIZE( WCHAR );
         srcBuffer.FromOA( OA( inputBufferSize-1, srcString.Data ), FALSE );
         pbuffer := ADR( utf8Buffer );
      ELSE
         srcBuffer.Size := inputBufferSize;
         pbuffer := ADR( srcBuffer );
      END;

      srcBuffer.Length := 0;
      Stream^.Seek( IOO.soBegin, 0 );

      TRY
         LOOP
            // srcBuffer.Clear(); -- do not clear, buffer is appened to avoid stitches in BASE64 encoding
            Result := Stream^.ReadBuffer( srcBuffer.Size - srcBuffer.Length, REF srcBuffer, Sync.FORSAFETY );
            ASSERTLOG( Result <> Sync.arTimeout, L"Unable to read mail data source stream" );
            IF Result = Sync.arNoData THEN
               // fall down
            ELSIF Result NOT IN Sync.arsCompletions THEN
               THROW SmtpException( Sync.arAborted );
            END;

            // convert text data to UTF8
            IF StreamIsText AND NOT srcBuffer.Empty THEN
               srcString.Length := srcBuffer.Length DIV SIZE( WCHAR );
               ASSERTLOG( srcBuffer.Data = srcString.Data, L"Unexpected reallocation" ); // reallocation could occur in ReadBuffer above
               languagesO.ToMB( srcString, languages.cp_UTF8, TRUE, REF utf8Buffer );
               srcBuffer.Clear(); // for text buffers srcBuffer does not play role in BASE64 stitching
            END;

            // convert bytes to BASE64, solve BASE64 3bytes chunks to not to produce stitches
            length := pbuffer^.Length;
            IF length > 0 THEN
               IF ( Result = Sync.arNoData ) AND ( length < 3 ) THEN
                  cphcommonO.ToBASE64( pbuffer^, OUT base64 ); // encode everything, we are on the end
               ELSE
                  index := ( length DIV granularity ) * granularity; // index to first incomplete triple
                  pbuffer^.Length := index;
                  cphcommonO.ToBASE64( pbuffer^, OUT base64 ); // encode each 3bytes from input, leave shorter chunks
                  pbuffer^.Length := length; // return the length
                  pbuffer^.Remove( 0, index ); // trim encoded bytes
               END;
               dstString.Append( base64 );
            END;

            // flush destination to lines of proper length
            index := 0;
            WHILE dstString.Length - index >= RFC822_CHUNK DO // 2 is for CRLF
               dstStringSlice.FromOA( OA( RFC822_CHUNK-1, dstString.Data@[index * SIZE(WCHAR)] ));
               WriteServer( dstStringSlice );
               INC( index, RFC822_CHUNK );
            END; // WHILE
            dstString.Remove( 0, index );
         
            // if no next data is present, stop
            IF Result = Sync.arNoData THEN
               IF dstString.Length > 0 THEN // flush last chunk (last not fully filled line)
                  WriteServer( dstString );
               END;
               EXIT;
            END;
         END; // LOOP

      CATCH e : CSmtpException DO
         THROW e;
      END;
   END WriteStreamBase64;

(*--------------------------------------------------------------------------------*)

   PRIVATE PROCEDURE CreateMessageId( OUT messageId : StringsO.IString );
   VAR
      hashed : INT64;
      unhashed : INT64;
      sOA : ARRAY [0..31] OF WCHAR;
   BEGIN
      _Message^.Created.ToLanguageStringOA( languages.GetDefaultLanguage( languages.dlNeutral ), L"yyyyMMddHHmmss.fff", TRUE, TRUE, OUT sOA );
      messageId.FromOA( sOA );

      unhashed := INT64( _Message ) * datetime.UptimeMS64();
      hash.hashb( unhashed, OUT hashed );
      Strings.FromCARD64W( hashed, 16, OUT sOA );
      messageId.AppendOA( sOA );
      
      messageId.AppendOA( L"@" );
      messageId.Append( _Sender^.LocalName );
   END CreateMessageId;

(*--------------------------------------------------------------------------------*)

   PRIVATE PROCEDURE WriteMimeHeader( CONST givenHeader : StringsO.IString; CONST defaultHeader : ARRAY OF WCHAR; appendAlways : StringsO.TPString; correctCharset : BOOLEAN );
   VAR
      header : StringsO.CString;
   BEGIN
      TRY
         header.FromOA( L"Content-Type: " );
         IF givenHeader.Empty THEN
            header.AppendOA( defaultHeader );
         ELSE
            header.Append( givenHeader );
            IF correctCharset AND NOT CorrectCharset( REF header ) THEN
               THROW SmtpException( Sync.arAborted );
            END;
         END;
         IF appendAlways <> NIL THEN
            header.AppendOA( L"; " );
            header.Append( appendAlways^ );
         END;
         WriteServer( header );
         header.FromOA( L"Content-Transfer-Encoding: base64" + 13W + 10W ); // mime header can be immediately followed by data
         WriteServer( header );

      CATCH e : CSmtpException DO
         THROW e;
      END;
   END WriteMimeHeader;

(*--------------------------------------------------------------------------------*)

   PRIVATE PROCEDURE WriteAttachments();
   VAR
      fileNameOA : FIO.PathStrW;
      fileName : StringsO.CString;
      fs : FIOO.CFileStream;
      header : StringsO.CString;
   BEGIN
      IF _Message^.Attachments^.Empty THEN
         RETURN;
      END;

      TRY
         _Message^.Attachments^.Reset();
         WHILE _Message^.Attachments^.MoveNext() DO

            header.FromOA( 13W + 10W + L"--" );  // leading of next multipart part
            header.Append( _Boundary );
            WriteServer( header );

            // get file name
            header.Assign( _Message^.Attachments^.Current^ );
            FIO.PathTailW( OA( header.Length-1, header.Data ), OUT fileNameOA );
            IF fileNameOA[0] = 0W THEN
               fileName := header;
            ELSE
               fileName.FromOA( fileNameOA );
            END;

            // header of the attachment, CRLF is included in WriteMimeHeader, directly continue with data
            header.FromOA( L"Content-Description: " );
            SmtpTools.AppendStringToHeader( REF header, fileName, SmtpTools.HintNone );
            WriteServer( header );

            header.FromOA( L"Content-Disposition: attachment; filename=" );
            SmtpTools.AppendStringToHeader( REF header, fileName, SmtpTools.HintMimeHeader );
            WriteServer( header );

            header.FromOA( L"name=" );
            SmtpTools.AppendStringToHeader( REF header, fileName, SmtpTools.HintMimeHeader );
            WriteMimeHeader( _Message^.Attachments^.CurrentData^, L"Content-Type: application/octet-stream", ADR( header ), FALSE );

            // write the file
            TRY
               fileName.Assign( _Message^.Attachments^.Current^ );
               fs.FromPath( OA( fileName.Length-1, fileName.Data ), FIOO.imOpenRead );
            CATCH e : IOO.CIOException DO
               THROW SmtpException( Sync.arAborted );
            END;
            WriteStreamBase64( ADR( fs ), FALSE );
            fs.Close( FALSE );

         END; // WHILE over attachments

         // terminate multipart message
         header.FromOA( 13W + 10W + L"--" ); // stop marker, no next part follows
         header.Append( _Boundary );
         header.AppendOA( L"--" ); 
         WriteServer( header );

      CATCH e : CSmtpException DO
         THROW e;
      END;
   END WriteAttachments;

(*--------------------------------------------------------------------------------*)

BEGIN
   _Reader.Stream := _Connection.Stream;
   _Writer.Stream := _Connection.BufferedStream;
END CWorker;

(*================================================================================*)

TYPE
   TRepeatSpan = ARRAY [0..7] OF datetime.TJDC;

CONST
   REPEAT_SPAN = TRepeatSpan(
         5 * 60 * 60 * datetime.unitsInSecond,
        30 * 60 * 60 * datetime.unitsInSecond,
       150 * 60 * 60 * datetime.unitsInSecond,
       270 * 60 * 60 * datetime.unitsInSecond,
       990 * 60 * 60 * datetime.unitsInSecond,
      2430 * 60 * 60 * datetime.unitsInSecond,
      3870 * 60 * 60 * datetime.unitsInSecond,
      5310 * 60 * 60 * datetime.unitsInSecond
   );

(*--------------------------------------------------------------------------------*)

CLASS IMPLEMENTATION CSender;

(*--------------------------------------------------------------------------------*)

   LOCAL VIRTUAL PROCEDURE OnHandle( Result : Sync.TAsyncResult; PoolHandle : threadpool.TPoolHandle; UserId : PTR );
   BEGIN
      IF Result = Sync.arTimeout THEN
         ResendMessagesAndCleanupQueue();
      ELSIF Result = Sync.arCompleted THEN
         SendMessagesForFirst();
      END;
   END OnHandle;

(*--------------------------------------------------------------------------------*)

   PUBLIC VIRTUAL PROPERTY Dispatcher GET : threadcall.TPIThreadProcedureCallDispatcher;
   VAR
      lock : Sync.AutoLock;
   BEGIN
      lock.TakeReadSafe( REF _Lock, L"Unable to lock Sender" );
      RETURN _Dispatcher;
   END Dispatcher;

(*--------------------------------------------------------------------------------*)

   PUBLIC VIRTUAL PROPERTY Dispatcher SET( Value : threadcall.TPIThreadProcedureCallDispatcher );
   VAR
      lock : Sync.AutoLock;
   BEGIN
      lock.TakeSafe( REF _Lock, L"Unable to lock Sender" );
      _Dispatcher := Value;
   END Dispatcher;

(*--------------------------------------------------------------------------------*)

   PUBLIC VIRTUAL PROPERTY Notifier GET : TPNotifier;
   VAR
      lock : Sync.AutoLock;
   BEGIN
      lock.TakeReadSafe( REF _Lock, L"Unable to lock Sender" );
      RETURN _Notifier;
   END Notifier;

(*--------------------------------------------------------------------------------*)

   PUBLIC VIRTUAL PROPERTY Notifier SET( Value : TPNotifier );
   VAR
      lock : Sync.AutoLock;
   BEGIN
      lock.TakeSafe( REF _Lock, L"Unable to lock Sender" );
      _Notifier := Value;
   END Notifier;

(*--------------------------------------------------------------------------------*)

   PUBLIC VIRTUAL PROCEDURE Send( CONST message : MailMessage.TPMailMessage; takeOwnership : BOOLEAN ) : Sync.TAsyncResult;
   VAR
      queueItem : TPQueueItem;
      Result : Sync.TAsyncResult;
   BEGIN
      IF message^.Sender.Address.Empty THEN
         RETURN Sync.arCannotStart;
      ELSIF message^.Recipients^.Empty AND message^.CCs^.Empty AND message^.BCCs^.Empty THEN
         RETURN Sync.arCannotStart;
      END;

      NEW( queueItem );
      queueItem^.Message := message;
      queueItem^.Ownership := takeOwnership;

      IF _LightWeight THEN
         Result := DoSend( queueItem );
         DISPOSE( queueItem );

      ELSE // not lightweight, asynchronous
         IF _PoolHandle = NIL THEN
            RETURN Sync.arCannotStart;
         END;
         _IncomingQueue.Enqueue( queueItem ); // enqueue and switch tasks
         Result := Sync.arPending;

      END;

      RETURN Result;
   END Send;

(*--------------------------------------------------------------------------------*)

   PUBLIC VIRTUAL PROPERTY Server GET : StringsO.CString;
   VAR
      lock : Sync.AutoLock;
   BEGIN
      lock.TakeReadSafe( REF _Lock, L"Unable to lock Sender" );
      RETURN _Server;
   END Server;

(*--------------------------------------------------------------------------------*)

   PUBLIC VIRTUAL PROPERTY Server SET( CONST Value : StringsO.CString );
   VAR
      lock : Sync.AutoLock;
   BEGIN
      lock.TakeSafe( REF _Lock, L"Unable to lock Sender" );
      _Server := Value;
   END Server;

(*--------------------------------------------------------------------------------*)

   PUBLIC VIRTUAL PROPERTY Mailer GET : StringsO.CString;
   VAR
      lock : Sync.AutoLock;
   BEGIN
      lock.TakeReadSafe( REF _Lock, L"Unable to lock Sender" );
      RETURN _Mailer;
   END Mailer;

(*--------------------------------------------------------------------------------*)

   PUBLIC VIRTUAL PROPERTY Mailer SET( CONST Value : StringsO.CString );
   VAR
      lock : Sync.AutoLock;
   BEGIN
      lock.TakeSafe( REF _Lock, L"Unable to lock Sender" );
      _Mailer := Value;
   END Mailer;

(*--------------------------------------------------------------------------------*)

   PUBLIC VIRTUAL PROPERTY Login GET : StringsO.CString; 
   VAR
      lock : Sync.AutoLock;
   BEGIN
      lock.TakeReadSafe( REF _Lock, L"Unable to lock Sender" );
      RETURN _Login;
   END Login;

(*--------------------------------------------------------------------------------*)

   PUBLIC VIRTUAL PROPERTY Login SET( CONST Value : StringsO.CString );
   VAR
      lock : Sync.AutoLock;
   BEGIN
      lock.TakeSafe( REF _Lock, L"Unable to lock Sender" );
      _Login := Value;
   END Login;

(*--------------------------------------------------------------------------------*)

   PUBLIC VIRTUAL PROPERTY Password GET : StringsO.CString; 
   VAR
      lock : Sync.AutoLock;
   BEGIN
      lock.TakeReadSafe( REF _Lock, L"Unable to lock Sender" );
      RETURN _Password;
   END Password;

(*--------------------------------------------------------------------------------*)

   PUBLIC VIRTUAL PROPERTY Password SET( CONST Value : StringsO.CString );
   VAR
      lock : Sync.AutoLock;
   BEGIN
      lock.TakeSafe( REF _Lock, L"Unable to lock Sender" );
      _Password := Value;
   END Password;

(*--------------------------------------------------------------------------------*)

   PUBLIC VIRTUAL PROPERTY TimeToLive GET : CARDINAL;
   VAR
      lock : Sync.AutoLock;
   BEGIN
      lock.TakeReadSafe( REF _Lock, L"Unable to lock Sender" );
      RETURN _TimeToLive;
   END TimeToLive;

(*--------------------------------------------------------------------------------*)

   PUBLIC VIRTUAL PROPERTY TimeToLive SET( Value : CARDINAL );
   VAR
      lock : Sync.AutoLock;
   BEGIN
      lock.TakeSafe( REF _Lock, L"Unable to lock Sender" );
      _TimeToLive := Value;
   END TimeToLive;

(*--------------------------------------------------------------------------------*)

   PUBLIC VIRTUAL PROPERTY GenerateMessageId GET : BOOLEAN;
   VAR
      lock : Sync.AutoLock;
   BEGIN
      lock.TakeReadSafe( REF _Lock, L"Unable to lock Sender" );
      RETURN _GenerateMessageId;
   END GenerateMessageId;

(*--------------------------------------------------------------------------------*)

   PUBLIC VIRTUAL PROPERTY GenerateMessageId SET( Value : BOOLEAN );
   VAR
      lock : Sync.AutoLock;
   BEGIN
      lock.TakeSafe( REF _Lock, L"Unable to lock Sender" );
      _GenerateMessageId := Value;
   END GenerateMessageId;

(*--------------------------------------------------------------------------------*)

   LOCAL PROPERTY LocalName GET : StringsO.CString;
   VAR
      s : StringsO.CString;
   BEGIN
      IF _LocalName.Empty THEN
         IF _Lock.LockWrite( Sync.FORSAFETY ) = Sync.arTimeout THEN
            ASSERTLOG( FALSE, L"Unable to lock Sender" );
         END;
         IF NOT dns.GetLocalName( OUT _LocalName ) THEN
            _LocalName.FromOA( L"scmailer" );
         END;
         s := _LocalName;
         _Lock.UnlockWrite();
      ELSE
         IF _Lock.LockRead( Sync.FORSAFETY ) = Sync.arTimeout THEN
            ASSERTLOG( FALSE, L"Unable to lock Sender" );
         END;
         s := _LocalName;
         _Lock.UnlockRead();
      END;
      RETURN s;
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

   LOCAL PROCEDURE NotifyCompletion( CONST message : MailMessage.TPMailMessage; Result : Sync.TAsyncResult; SmtpPhase : SmtpTools.TSmtpPhase; CONST failedRecipients : MailPerson.IPersons );
   BEGIN
   END NotifyCompletion;

(*--------------------------------------------------------------------------------*)

   PRIVATE PROCEDURE DoSend( queueItem : TPQueueItem ) : Sync.TAsyncResult;
   VAR
      ph : threadpool.TPoolHandle;
      reported : BOOLEAN;
      result : Sync.TAsyncResult;
      smtpPhase : SmtpTools.TSmtpPhase;
      worker : POINTER TO CWorker;
   BEGIN
      IF _LightWeight THEN // run directly
         NEW( worker );
         worker^.Init( ADR( SELF ), queueItem );
         result := worker^.DoSend( OUT smtpPhase );

      ELSE // run it in the pool
         IF CARDINAL( Sync.IGet( REF _Pending )) >= Sync.NumberOfProcessors() THEN
            RETURN Sync.arCannotStart;
         END;
         Sync.IInc( REF _Pending );
         queueItem^.Status := Sync.arPending;

         // run the worker in the pool
         NEW( worker );
         worker^.Init( ADR( SELF ), queueItem );
         IF _Pool.RunWorker( ADR( SELF ), 0, FALSE, worker, FALSE, OUT ph ) THEN
            result := Sync.arPending;
         ELSE
            queueItem^.Status := Sync.arInitial;
            result := Sync.arCannotStart;
         END;

      END;
      // cleanup, for _LightWeight the worker is disposed, if the worker was pooled, pool holds own reference
      worker^.Release();

      RETURN result;
   END DoSend;

(*--------------------------------------------------------------------------------*)

   PRIVATE PROCEDURE SendMessagesForFirst();
   VAR
      ptr : PTR;
      queueItem : TPQueueItem;
   BEGIN
      WHILE _IncomingQueue.Dequeue( OUT ptr ) DO
         queueItem := ptr;
         // arInitial already set from ctor
         _Queue.Add( queueItem, 0 );
         
         DoSend( queueItem );
      END; // WHILE
   END SendMessagesForFirst;

(*--------------------------------------------------------------------------------*)

   PRIVATE PROCEDURE ResendMessagesAndCleanupQueue();
   VAR
      now : datetime.DateTime;
      queueItem : TPQueueItem;
   BEGIN
      ASSERT( thread.Current()^.InfoType = thread.infoTypePool );
      now := datetime.NowUTC();

      _Queue.Reset();
      WHILE _Queue.MoveNext() DO
         queueItem := _Queue.Current;

         CASE Sync.TAsyncResult( Sync.IExchg( REF PINTEGER( ADR( queueItem^.Status ))^, INTEGER( Sync.arPending ))) OF
         | Sync.arPending :
            CONTINUE;
         | Sync.arCompleted : // sending has finished, remove the message from the queue
            _Queue.Remove( queueItem );
            _Queue.Reset(); // iterate again

            IF queueItem^.Ownership THEN
               MailMessage.Dispose( REF queueItem^.Message );
            END;
            DISPOSE( queueItem );

            CONTINUE;
         END;
         IF queueItem^.NextSendTime <= now THEN // time expired, resend the message
            CONTINUE;
         END;

         // resend the message
         DoSend( queueItem );
      END; // WHILE
   END ResendMessagesAndCleanupQueue;

(*--------------------------------------------------------------------------------*)

BEGIN
   _IncomingQueueSignal.Init( Sync.stEventAutoreset, L"", FALSE );
   IF NOT threadpool.pool()^.WaitHandle( ADR( SELF ), 0, 60000, FALSE, FALSE, _IncomingQueueSignal.RawHandle, OUT _PoolHandle ) THEN
      ASSERTLOG( FALSE, L"Unable to start SMTP sender waiting" );
   END;
FINALLY
   IF _PoolHandle <> NIL THEN
      threadpool.pool()^.Abort( REF _PoolHandle );
   END;
END CSender;

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