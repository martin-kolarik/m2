IMPLEMENTATION MODULE SrvCommon;

FROM Log IMPORT
   logger, dlcError, dlcWarning, dlcInfo;
   
IMPORT
   cphcommon,
   digest,
   httpapi,
   HttpConnection,
   httptools,
   IOO,
   maps,
   netsocket,
   rijndael,
   Storage,
   StorageO,
   Strings,
   Time,
   threadpool,
   windows,
   winerror;

(*================================================================================*)

CLASS IMPLEMENTATION CHeaders;

(*--------------------------------------------------------------------------------*)

   PUBLIC VIRTUAL PROCEDURE Contains( Header : HttpCommon.TKnownHeader ) : BOOLEAN;
   VAR
      s : StringsO.CString;
   BEGIN
      RETURN Get( Header, OUT s );
   END Contains;

(*--------------------------------------------------------------------------------*)

   PUBLIC VIRTUAL PROCEDURE Get( Header : HttpCommon.TKnownHeader; OUT Value : StringsO.IString ) : BOOLEAN;
   VAR
      s : StringsO.TPString;
   BEGIN
      IF KnownCache.Get( CARDINAL( Header ), OUT s ) THEN
         Value.Assign( s^ );
         RETURN TRUE;
      ELSE
         RETURN FALSE;
      END;
   END Get;

(*--------------------------------------------------------------------------------*)

   PUBLIC VIRTUAL PROCEDURE GetOA( Header : HttpCommon.TKnownHeader; OUT Value : ARRAY OF WCHAR ) : BOOLEAN;
   VAR
      s : StringsO.CString;
   BEGIN
      IF Get( Header, OUT s ) THEN
         s.ToOA( OUT Value );
         RETURN TRUE;
      ELSE
         RETURN FALSE;
      END;
   END GetOA;

(*--------------------------------------------------------------------------------*)

   PUBLIC VIRTUAL PROCEDURE Add( Header : HttpCommon.TKnownHeader; CONST Value : StringsO.IString );
   VAR
      s : StringsO.TPString;
   BEGIN
      IF RequestFlag THEN
         RETURN;
      ELSIF KnownCache.Get( CARDINAL( Header ), OUT s ) THEN
         s^ := Value;
      ELSE
         s := NEW( StringsO.CString );
         s^.Assign( Value );
         KnownCache.Add( CARDINAL( Header ), s );
      END;
   END Add;
   
(*--------------------------------------------------------------------------------*)

   PUBLIC VIRTUAL PROCEDURE AddOA( Header : HttpCommon.TKnownHeader; CONST Value : ARRAY OF WCHAR );
   VAR
      s : StringsO.CString;
   BEGIN
      s.FromOA( Value );
      Add( Header, s );
   END AddOA;

(*--------------------------------------------------------------------------------*)

   PUBLIC VIRTUAL PROCEDURE Enumerate( Known, Uknown : BOOLEAN; REF ES : PTR; OUT Name, Value : StringsO.IString ) : BOOLEAN;
   BEGIN
      ASSERT( FALSE );
      RETURN FALSE;
   END Enumerate;

(*--------------------------------------------------------------------------------*)

   PUBLIC VIRTUAL PROCEDURE ContainsUnknown( CONST Name : ARRAY OF WCHAR ) : BOOLEAN;
   VAR
      s : StringsO.CString;
   BEGIN
      RETURN GetUnknown( Name, OUT s );
   END ContainsUnknown;

(*--------------------------------------------------------------------------------*)

   PUBLIC VIRTUAL PROCEDURE GetUnknown( CONST Name : ARRAY OF WCHAR; OUT Value : StringsO.IString ) : BOOLEAN;
   VAR
      n : StringsO.CString;
      s : StringsO.TPString;
   BEGIN
      n.FromOA( Name );
      n.Lowerize();
      IF UnknownCache.Get( n, OUT s ) THEN
         Value.Assign( s^ );
         RETURN TRUE;
      ELSE
         RETURN FALSE;
      END;
   END GetUnknown;

(*--------------------------------------------------------------------------------*)

   PUBLIC VIRTUAL PROCEDURE AddUnknown( CONST Name : ARRAY OF WCHAR; CONST Value : StringsO.IString );
   VAR
      n : StringsO.CString;
      s : StringsO.TPString;
   BEGIN
      IF RequestFlag THEN
         RETURN;
      END;

      n.FromOA( Name );
      n.Lowerize();
      IF UnknownCache.Get( n, OUT s ) THEN
         s^.Assign( Value );
      ELSE
         s := NEW( StringsO.CString );
         s^.Assign( Value );
         UnknownCache.Add( n, s );
      END;
   END AddUnknown;

(*--------------------------------------------------------------------------------*)

   PUBLIC PROCEDURE Dispose();
   BEGIN
      KnownCache.Dispose(); // TODO loop over inner strings
      UnknownCache.Dispose(); // TODO loop over inner strings
   END Dispose;

(*--------------------------------------------------------------------------------*)

BEGIN
FINALLY
   Dispose();
END CHeaders;

(*================================================================================*)

CLASS CContainer IMPLEMENTS HttpSrv.IContainer;
   PRIVATE VAR
      Models : maps.CStringMap;
   PUBLIC VIRTUAL PROCEDURE Clear();
   PUBLIC VIRTUAL PROCEDURE AddModel( CONST Name : ARRAY OF WCHAR; REF Model : maps.CStringStringMap );
   PUBLIC VIRTUAL PROCEDURE RemoveModel( CONST Name : ARRAY OF WCHAR );
   PUBLIC VIRTUAL PROCEDURE GetModelOA( CONST Name : ARRAY OF WCHAR; OUT PModel : maps.TPStringStringMap ) : BOOLEAN;
   PUBLIC VIRTUAL PROCEDURE GetModel( CONST Name : StringsO.CString; OUT PModel : maps.TPStringStringMap ) : BOOLEAN;
END CContainer;

(*--------------------------------------------------------------------------------*)

CLASS IMPLEMENTATION CContainer;

(*--------------------------------------------------------------------------------*)

   PUBLIC VIRTUAL PROCEDURE Clear();
   BEGIN
      Models.Dispose();
   END Clear;

(*--------------------------------------------------------------------------------*)

   PUBLIC VIRTUAL PROCEDURE AddModel( CONST Name : ARRAY OF WCHAR; REF Model : maps.CStringStringMap );
   BEGIN
      IF Models.ContainsOA( Name ) THEN
         RETURN;
      END;
      Models.AddOA( Name, ADR( Model ));
   END AddModel;

(*--------------------------------------------------------------------------------*)

   PUBLIC VIRTUAL PROCEDURE RemoveModel( CONST Name : ARRAY OF WCHAR );
   BEGIN
      Models.RemoveOA( Name );
   END RemoveModel;

(*--------------------------------------------------------------------------------*)

   PUBLIC VIRTUAL PROCEDURE GetModelOA( CONST Name : ARRAY OF WCHAR; OUT PModel : maps.TPStringStringMap ) : BOOLEAN;
   BEGIN
      RETURN Models.GetOA( Name, OUT PModel );
   END GetModelOA;

(*--------------------------------------------------------------------------------*)

   PUBLIC VIRTUAL PROCEDURE GetModel( CONST Name : StringsO.CString; OUT PModel : maps.TPStringStringMap ) : BOOLEAN;
   BEGIN
      RETURN Models.Get( Name, OUT PModel );
   END GetModel;

(*--------------------------------------------------------------------------------*)

BEGIN FINALLY
   Clear();
END CContainer;

(*================================================================================*)

CLASS IMPLEMENTATION ASrvStream;

(*--------------------------------------------------------------------------------*)

   PUBLIC VIRTUAL PROPERTY CanRead GET : BOOLEAN;
   BEGIN
      RETURN NOT _ReadOut;
   END CanRead;

(*--------------------------------------------------------------------------------*)

   PUBLIC VIRTUAL PROPERTY CanWrite GET : BOOLEAN;
   BEGIN
      RETURN NOT _DataSent;
   END CanWrite;

(*--------------------------------------------------------------------------------*)

   PUBLIC VIRTUAL PROPERTY CanSeek GET : BOOLEAN;
   BEGIN
      RETURN FALSE;
   END CanSeek;

(*--------------------------------------------------------------------------------*)

   PUBLIC VIRTUAL PROPERTY Long GET : BOOLEAN;
   BEGIN
      RETURN TRUE;
   END Long;

(*--------------------------------------------------------------------------------*)

   PUBLIC VIRTUAL PROPERTY Length GET : CARD64;
   BEGIN
      IF _ReadOut THEN
         RETURN 0;
      ELSE
         RETURN -1;
      END;
   END Length;

(*--------------------------------------------------------------------------------*)

   PUBLIC VIRTUAL PROPERTY Length SET( Value : CARD64 );
   BEGIN // unusable
   END Length;

(*--------------------------------------------------------------------------------*)

   PUBLIC VIRTUAL PROPERTY Position GET : CARD64;
   BEGIN
      RETURN -1;
   END Position;

(*--------------------------------------------------------------------------------*)

   PUBLIC VIRTUAL PROPERTY Position SET( Value : CARD64 );
   BEGIN
      Seek( IOO.soBegin, Value );
   END Position;

(*--------------------------------------------------------------------------------*)

   PUBLIC FINAL PROCEDURE Seek( Origin : IOO.TSeekOrigin; Position : INT64 ); 
   BEGIN
      ASSERT( FALSE ); // not seekable      
   END Seek;
   
(*--------------------------------------------------------------------------------*)

   PUBLIC FINAL PROCEDURE Flush();
   VAR
      Buffer : ARRAY [0..8191] OF BYTE;
      Data : StorageO.CMemoryBuffer;
   BEGIN
      // only read side can be flushed
      IF NOT _ReadOut THEN
         _ReadOut := TRUE;
         Data.FromOA( OA( SIZE( Buffer )-1, ADR( Buffer )), FALSE );
         WHILE ReceiveData( OUT Data ) = Sync.arCompleted DO END;
      END;
   END Flush;

(*--------------------------------------------------------------------------------*)

   PUBLIC FINAL PROCEDURE Close( Persist : BOOLEAN ); // persist takes no sense
   BEGIN
      StartResponse();
      IF NOT _DataSent THEN
         _DataSent := TRUE;
         EndResponse();
      END;
   END Close;
  
(*--------------------------------------------------------------------------------*)

   INTERNAL FINAL PROCEDURE Start( Direction : IOO.TDirection; OperationTimeoutMS : CARDINAL ) : Sync.TAsyncResult;
   VAR
      buffer : StorageO.CMemoryBuffer;
      Data : ADDRESS;
      L : CARDINAL;
      Result : Sync.TAsyncResult;
   BEGIN
      IF ( Direction = IOO.dirRead ) AND _ReadOut THEN
         Result := Sync.arNoData;
         
      ELSIF ( Direction = IOO.dirWrite ) AND _DataSent THEN
         Result := Sync.arCannotStart;

      ELSE
         WHILE DevicePrepareData( Direction, OUT Data, OUT L ) DO
            IF L = 0 THEN
               CONTINUE;
            END;
            IF Direction = IOO.dirRead THEN
               Result := ReceiveData( OUT buffer );
               CASE Result OF
               | Sync.arCompleted :
               | Sync.arNoData :
                  _ReadOut := TRUE;
               ELSE
                  _ReadOut := TRUE;
               END;

            ELSE // write
               StartResponse();
               buffer.FromOA( OA( L-1, Data ), FALSE );
               Result := SendData( buffer );
               IF Result <> Sync.arCompleted THEN
                  _DataSent := TRUE;
               END;

            END; // IF direction

            DeviceCompleteData( Direction, buffer.Length );
            IF Result <> Sync.arCompleted THEN
               EXIT;
            END;
         END; // WHILE
      END; // IF Direction
      
      CASE Result OF
      |  Sync.arPending,
         Sync.arAlreadyPending,
         Sync.arCannotStart :
      ELSE
         DeviceFinish( Direction, Result );
      END;
      RETURN Result;
   END Start;

(*--------------------------------------------------------------------------------*)

   INTERNAL FINAL PROCEDURE Abort( Direction : IOO.TDirection );
   BEGIN
      DeviceFinish( Direction, Sync.arAborted );
   END Abort;

(*--------------------------------------------------------------------------------*)

   LOCAL PROCEDURE StartHandleRequest() : Sync.TAsyncResult;
   BEGIN
      RETURN ReceiveHeaders();
   END StartHandleRequest;
   
(*--------------------------------------------------------------------------------*)

   PRIVATE PROCEDURE AddDefaultHeaders();
   VAR
      // dt : Time.TDateTime;
   BEGIN
      // Date
      // Time.GetCurrentUTCDateTime( dt );
      // _ResponseHeaders.Add( HttpCommon.Date, httptools.FormatDate( dt )); // driver by http.sys
      
      // Server
      ResponseHeaders^.AddOA( HttpCommon.Server, L"SmartControl/1.0" );
      
      // Caching
      IF NOT ResponseHeaders^.Contains( HttpCommon.CacheControl ) THEN
         ResponseHeaders^.AddOA( HttpCommon.Pragma, L"no-cache" );
         ResponseHeaders^.AddOA( HttpCommon.CacheControl, L"no-cache" );
      END;

      // Content
      IF NOT ResponseHeaders^.Contains( HttpCommon.ContentType ) THEN
         ResponseHeaders^.Add( HttpCommon.ContentType, httptools.FormatContentOA( httptools.contentTextPlain, L"utf-8" ));
      END;
      
      (*?*)
      // ResponseHeaders^AddOA( HttpCommon.ContentLength, L"10" );
   END AddDefaultHeaders;

(*--------------------------------------------------------------------------------*)

   PUBLIC PROCEDURE StartResponse() : Sync.TAsyncResult;
   BEGIN
      IF _HeaderSent THEN
         RETURN Sync.arCompleted;
      END;
      _HeaderSent := TRUE;
      
      Flush();
      AddDefaultHeaders();
      
      RETURN SendHeaders();
   END StartResponse;

(*--------------------------------------------------------------------------------*)

BEGIN
   _ReadOut := FALSE;
   _HeaderSent := FALSE;
   _DataSent := FALSE;
END ASrvStream;

(*================================================================================*)

CLASS CHttpConnection IMPLEMENTS HttpConnection.IHttpSrvConnection;

   // IServerConnection
   PUBLIC VIRTUAL READONLY PROPERTY
      LocalAddress : inetaddr.INETADDR;
      RemoteAddress : inetaddr.INETADDR;
      Stream : IOO.TPStream;

   // IHttpSrvConnection
   PUBLIC VIRTUAL READONLY PROPERTY
      RequestHeaders : HttpCommon.TPHttpHeaders;
      ResponseHeaders : HttpCommon.TPHttpHeaders;
      
   // SELF
   PUBLIC VIRTUAL PROPERTY
      StatusCode : HttpCommon.THttpResponse;
   
   PRIVATE VAR
      _Stream : TPSrvStream;
   
   LOCAL PROCEDURE FromStream( stream : TPSrvStream );
      
END CHttpConnection;

(*================================================================================*)

CLASS IMPLEMENTATION CHttpConnection;

(*--------------------------------------------------------------------------------*)

   VIRTUAL PROPERTY LocalAddress GET : inetaddr.INETADDR;
   BEGIN
      RETURN _Stream^.LocalAddress;
   END LocalAddress;

(*--------------------------------------------------------------------------------*)

   VIRTUAL PROPERTY RemoteAddress GET : inetaddr.INETADDR;
   BEGIN
      RETURN _Stream^.RemoteAddress;
   END RemoteAddress;

(*--------------------------------------------------------------------------------*)

   VIRTUAL PROPERTY Stream GET : IOO.TPStream;
   BEGIN
      RETURN _Stream;
   END Stream;

(*--------------------------------------------------------------------------------*)

   PUBLIC VIRTUAL PROPERTY RequestHeaders GET : HttpCommon.TPHttpHeaders;
   BEGIN
      RETURN _Stream^.RequestHeaders;
   END RequestHeaders;
   
(*--------------------------------------------------------------------------------*)

   PUBLIC VIRTUAL PROPERTY ResponseHeaders GET : HttpCommon.TPHttpHeaders;
   BEGIN
      RETURN _Stream^.ResponseHeaders;
   END ResponseHeaders;
      
(*--------------------------------------------------------------------------------*)

   PUBLIC VIRTUAL PROPERTY StatusCode GET : HttpCommon.THttpResponse;
   BEGIN
      RETURN _Stream^.StatusCode;
   END StatusCode;

(*--------------------------------------------------------------------------------*)

   PUBLIC VIRTUAL PROPERTY StatusCode SET( Value : HttpCommon.THttpResponse );
   BEGIN
      _Stream^.StatusCode := Value;
   END StatusCode;

(*--------------------------------------------------------------------------------*)

   LOCAL PROCEDURE FromStream( stream : TPSrvStream );
   BEGIN
      _Stream := stream;
   END FromStream;
      
(*--------------------------------------------------------------------------------*)

BEGIN
   _Stream := NIL;
END CHttpConnection;

(*================================================================================*)

CLASS CSession IMPLEMENTS HttpSrv.ISession;

   // ISession
   PUBLIC VIRTUAL READONLY PROPERTY
      Data : maps.TPStringMap; // the same as Container["session"]
      SID : StringsO.CString;
   PUBLIC VIRTUAL PROCEDURE Invalidate();
   
   // SELF
   PRIVATE VAR
      _Valid : BOOLEAN := TRUE;
      _Created : Time.TJD;
      _SID : StringsO.CString;
      _Data : maps.TPStringMap := NIL;
   LOCAL VAR // TODO property
      New : BOOLEAN := TRUE;
      RootPath : StringsO.CString;
   PUBLIC READONLY PROPERTY
      Valid : BOOLEAN;   
      
   PUBLIC PROCEDURE Init( CONST sid : StringsO.IString; CONST rootPath : StringsO.IString );
   PUBLIC PROCEDURE SetData( data : maps.TPStringMap );
END CSession;

(*--------------------------------------------------------------------------------*)

CLASS IMPLEMENTATION CSession;

(*--------------------------------------------------------------------------------*)

   PUBLIC VIRTUAL PROPERTY Data GET : maps.TPStringMap; // the same as Container["session"]
   BEGIN
      RETURN _Data;
   END Data;

(*--------------------------------------------------------------------------------*)

   PUBLIC VIRTUAL PROPERTY SID GET : StringsO.CString;
   BEGIN
      RETURN _SID;
   END SID;

(*--------------------------------------------------------------------------------*)

   PUBLIC VIRTUAL PROCEDURE Invalidate();
   BEGIN
      _Valid := FALSE;
      _Created := 0; // force sweep
      _SID.Clear();
   END Invalidate;
   
(*--------------------------------------------------------------------------------*)

   PUBLIC PROPERTY Valid GET : BOOLEAN;
   BEGIN
      RETURN _Valid;
   END Valid;

(*--------------------------------------------------------------------------------*)

   PUBLIC PROCEDURE Init( CONST sid : StringsO.IString; CONST rootPath : StringsO.IString );
   BEGIN
      _SID.Assign( sid );
      RootPath.Assign( rootPath );
   END Init;

(*--------------------------------------------------------------------------------*)

   PUBLIC PROCEDURE SetData( data : maps.TPStringMap );
   BEGIN
      _Data := data;
   END SetData;

(*--------------------------------------------------------------------------------*)

BEGIN
   _Created := Time.GetCurrentJD();
END CSession;

(*================================================================================*)

CLASS HttpWorker( threadpool.APoolWorker );

   // APoolWorker
   LOCAL VIRTUAL PROCEDURE Run();

   // SELF
   PRIVATE VAR
      _Processor : HttpSrv.TPHttpProcessor := NIL;
      _Stream : TPSrvStream := NIL;
      _Session : TPSrvSession := NIL;

   LOCAL PROCEDURE Init( processor : HttpSrv.TPHttpProcessor; stream : TPSrvStream; session : TPSrvSession );

END HttpWorker;

//--------------------------------------------------------------------------------

CLASS IMPLEMENTATION HttpWorker;
   
//--------------------------------------------------------------------------------

   LOCAL VIRTUAL PROCEDURE Run();
   VAR
      Connection : CHttpConnection;
      l : CARDINAL;
      s : StringsO.CString;
   BEGIN
      IF ( _Session <> NIL ) AND _Session^.New THEN
         _Stream^.ResponseHeaders^.Add( HttpCommon.SetCookie, httptools.FormatSIDCookie( _Session^.SID, 0, _Session^.RootPath, s ));
      END;

      IF _Processor = NIL THEN
         _Stream^.StatusCode := HttpCommon.httpres_500;
         _Stream^.WriteOA( C"Internal server error, unable to process request", OUT l, Sync.FORSAFETY );
      ELSE
         Connection.FromStream( _Stream );
         _Processor^.ProcessRequest( ADR( Connection ), _Session );
      END;
      
      _Stream^.Close( FALSE );
      DISPOSE( _Stream );
   END Run;

//--------------------------------------------------------------------------------

   LOCAL PROCEDURE Init( processor : HttpSrv.TPHttpProcessor; stream : TPSrvStream; session : TPSrvSession );
   BEGIN
      SELF._Processor := processor;
      SELF._Stream := stream;
      SELF._Session := session;
   END Init;

//--------------------------------------------------------------------------------

BEGIN
END HttpWorker;

//================================================================================

CLASS IMPLEMENTATION ASrvCommon;

//--------------------------------------------------------------------------------

   LOCAL VIRTUAL PROCEDURE OnHandle( Result : Sync.TAsyncResult; PoolHandle : threadpool.TPoolHandle; UserId : PTR );
   BEGIN
   END OnHandle;

//--------------------------------------------------------------------------------

   PUBLIC VIRTUAL PROPERTY Mode GET : HttpSrv.TMode;
   BEGIN
      RETURN _Mode;
   END Mode;

//--------------------------------------------------------------------------------

   PUBLIC VIRTUAL PROPERTY Mode SET( Value : HttpSrv.TMode );
   VAR
      b : BOOLEAN;
   BEGIN
      IF Value = _Mode THEN
         RETURN;
      END;
      IF Running THEN
         b := TRUE;
         Stop();
      END;

      _Mode := Value;

      IF b THEN
         Start();
      END;
   END Mode;

//--------------------------------------------------------------------------------

   PUBLIC VIRTUAL PROPERTY Port GET : CARDINAL;
   BEGIN
      RETURN _Port;
   END Port;

//--------------------------------------------------------------------------------

   PUBLIC VIRTUAL PROPERTY Port SET( Value : CARDINAL );
   BEGIN
      IF Value = _Port THEN
         RETURN;
      END;
      IF Running AND (( _Mode = HttpSrv.mdHttp ) OR ( _Mode = HttpSrv.mdBoth )) THEN
         Stop();
         _Port := Value;
         Start();
      ELSE
         _Port := Value;
      END;
   END Port;

//--------------------------------------------------------------------------------

   PUBLIC VIRTUAL PROPERTY SslPort GET : CARDINAL;
   BEGIN
      RETURN _SslPort;
   END SslPort;

//--------------------------------------------------------------------------------

   PUBLIC VIRTUAL PROPERTY SslPort SET( Value : CARDINAL );
   BEGIN
      IF Value = _SslPort THEN
         RETURN;
      END;
      IF Running AND (( _Mode = HttpSrv.mdHttps ) OR ( _Mode = HttpSrv.mdBoth )) THEN
         Stop();
         _SslPort := Value;
         Start();
      ELSE
         _SslPort := Value;
      END;
   END SslPort;

//--------------------------------------------------------------------------------

   PUBLIC VIRTUAL PROPERTY RootPath GET : StringsO.CString;
   BEGIN
      RETURN _RootPath;
   END RootPath;

//--------------------------------------------------------------------------------

   PUBLIC VIRTUAL PROPERTY RootPath SET( CONST Value : StringsO.CString );
   VAR
      b : BOOLEAN;
   BEGIN
      IF _RootPath = Value THEN
         RETURN;
      END;
      IF Running THEN
         b := TRUE;
         Stop();
      END;

      IF Value[0] <> L"/" THEN
         _RootPath.FromOA( L"/" );
         _RootPath.Append( Value );
      ELSE
         _RootPath := Value;
      END;
      IF _RootPath[_RootPath.Length-1] <> L"/" THEN
         _RootPath.AppendOA( L"/" );
      END;

      IF b THEN
         Start();
      END;
   END RootPath;

//--------------------------------------------------------------------------------

   PUBLIC FINAL PROCEDURE RegisterProcessor( Processor : HttpSrv.TPHttpProcessor );
   BEGIN
      _Processors.Add( Processor, 0 );
   END RegisterProcessor;

//--------------------------------------------------------------------------------

   PUBLIC FINAL PROCEDURE ForgetProcessor( Processor : HttpSrv.TPHttpProcessor );
   BEGIN
      _Processors.Remove( Processor );
   END ForgetProcessor;

//--------------------------------------------------------------------------------

   PUBLIC PROCEDURE Dispose();
   BEGIN
      Stop();
      _Processors.Dispose();
   END Dispose;

//--------------------------------------------------------------------------------

   INTERNAL PROPERTY PreparedStream GET : TPSrvStream;
   BEGIN
      RETURN _PreparedStream;
   END PreparedStream;

//--------------------------------------------------------------------------------

   INTERNAL PROCEDURE PrepareStream(); // calls GetNewStream
   BEGIN
      _PreparedStream := GetNewStream();
   END PrepareStream;

//--------------------------------------------------------------------------------

   INTERNAL PROCEDURE ProcessPreparedStream();
   VAR
      currentProcessor : HttpSrv.TPHttpProcessor;
      foundProcessor : HttpSrv.TPHttpProcessor := NIL;
      ph : threadpool.TPoolHandle;
      Reported : BOOLEAN := FALSE;
      Result : Sync.TAsyncResult;
      Session : TPSrvSession;
      Timeout : CARDINAL := Time.UptimeMS() + netsocket.FORSAFETY;
      uri : StringsO.CString;
      Verb : HttpCommon.TVerb := HttpCommon.verbUnknown;
      WantsSession : BOOLEAN := FALSE;
      Worker : POINTER TO HttpWorker;
   BEGIN
      IF _PreparedStream = NIL THEN
         ASSERT( FALSE );
         RETURN;
      END;

      Result :=  _PreparedStream^.StartHandleRequest();
      IF Result = Sync.arAborted THEN
         _PreparedStream^.StatusCode := HttpCommon.httpres_503; // internal server error
   
      ELSIF Verb = HttpCommon.verbUnknown THEN
         _PreparedStream^.StatusCode := HttpCommon.httpres_501; // unsupported

      ELSE // verb OK, search processor
         _Processors.Reset();
         WHILE _Processors.MoveNext() DO
            uri := _PreparedStream^.RequestURI;
            currentProcessor := _Processors.Current;
            IF currentProcessor^.AppliesFor( Verb, OA( uri.Length-1, uri.rawData ), OUT WantsSession ) THEN
               foundProcessor := currentProcessor;
               EXIT;
            END;
         END; // WHILE

         IF foundProcessor = NIL THEN
            _PreparedStream^.StatusCode := HttpCommon.httpres_404; // resource not found
         END;
      END; // IF Verb

      IF WantsSession THEN
         Session := GetSessionForPreparedStream();
      ELSE
         Session := NIL;
      END;
      NEW( Worker );
      Worker^.Init( foundProcessor, _PreparedStream, Session );

_PreparedStream^.StartResponse();      

      LOOP
         IF _Pool.RunWorker( ADR( SELF ), 0, FALSE, Worker, FALSE, OUT ph ) THEN
            EXIT;
         END;
         IF NOT Reported THEN
            Reported := TRUE;
            logger()^.LogS( dlcInfo, L"HTTP", L"Pool has no space, wait for a while" );
         END;

         Sync.Sleep( 250 );
         IF Time.UptimeMS() - Timeout > 0 THEN // time elapsed
            logger()^.LogS( dlcWarning, L"HTTP", L"Unable to process HTTP request, pool exhausted" );
            EXIT;
         END;
      END;

      Worker^.Release();
   END ProcessPreparedStream;

//--------------------------------------------------------------------------------

   PRIVATE PROCEDURE GetSessionForPreparedStream() : TPSrvSession;
   CONST
      SESSION_VALIDITY = 30*60*1000; // milliseconds, 30 minutes
   VAR
      c : CARDINAL;
      cookie : StringsO.CString;
      data : sha256.TDigest;
      i : INTEGER;
      iv : sha256.TDigest;
      l : CARDINAL;
      ptr : PTR;
      s : StringsO.CString;
      session : TPSrvSession;
      sessionid : sha256.TDigest;
      shorttime : CARDINAL;
      time : Time.TTime64;
   BEGIN
      IF _PreparedStream <> NIL THEN
         ASSERT( FALSE );
         RETURN NIL;
      END;
   
      shorttime := Time.UptimeMS();
      // sweepout old sessions
      WHILE _SessionsExpiration.GetFirstElapsed( shorttime, TRUE, OUT session, OUT ptr ) DO
         _Sessions.Remove( session^.SID );
         DISPOSE( session );
      END; // WHILE
   
      IF _PreparedStream^.RequestHeaders^.Get( HttpCommon.Cookie, OUT cookie ) THEN
         i := cookie.IndexOfOA( L"=", 0 );
         IF i <> -1 THEN
            cookie.Substring( i+1, -1, OUT s );
            IF _Sessions.Get( s, OUT session ) THEN
               _SessionsExpiration.Remove( session );
               session^.New := FALSE;

               IF session^.Valid THEN // move expiration to the future
                  _SessionsExpiration.Add( shorttime, session, 0, SESSION_VALIDITY );
                  RETURN session;
               ELSE // kill the session
                  _Sessions.Remove( s );
                  DISPOSE( session );
               END;
            END;
         END;
      END;

      // cookie not set or cookie not found, create new empty session
      time := Time.time();
      digest.DigestOA( digest.sha256, time, OUT iv );
      digest.DigestOA( digest.sha256, OA( 31, _PreparedStream^.RemoteAddress.Data ), OUT data );
      rijndael.Encrypt( rijndael.cphmBlockEncrypt, rijndael.rkl256, _SessionSeed, iv, data, OUT sessionid, OUT c );
      
      l := cphcommon.BASE64CharCount( SIZE( sessionid ));
      cookie.Size := l;
      cookie.Length := l;
      cphcommon.ToBASE64( sessionid, OUT OA( l-1, PWCHAR( cookie.rawData )));
      
      NEW( session );
      session^.Init( cookie, _RootPath );
      _Sessions.Add( cookie, session );
      _SessionsExpiration.Add( shorttime, session, 0, SESSION_VALIDITY );
      
      RETURN session;      
   END GetSessionForPreparedStream;

//--------------------------------------------------------------------------------

   INITIALLY ASrvCommon();
   VAR
      time : Time.TTime64;
   BEGIN
      _RootPath.FromOA( L"/" );
      
      time := Time.time();
      Sync.Sleep( 33 );
      time := time * MAX( INT64 ) - Time.time();
      digest.DigestOA( digest.sha256, time, OUT _SessionSeed );
      
      _Pool.MinThreads := 2;
      _Pool.MaxThreads := 32;

      _PreparedStream := NIL;
   END ASrvCommon;

//--------------------------------------------------------------------------------

   FINALLY ASrvCommon();
   BEGIN
      Dispose();
      _Pool.FinishAndWait();
   END ASrvCommon;

//--------------------------------------------------------------------------------

END ASrvCommon;

//================================================================================

END SrvCommon.