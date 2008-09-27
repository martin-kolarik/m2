IMPLEMENTATION MODULE SrvHttpApi;

FROM Storage IMPORT
   ALLOCATE, DEALLOCATE;

FROM Log IMPORT
   logger, dlcError, dlcWarning, dlcInfo;
   
IMPORT
   httpapi,
   HttpCommon,
   inetaddr,
   SrvCommon,
   Storage,
   StorageO,
   Strings,
   StringsO,
   Sync,
   threadpool,
   windows,
   winerror;


//================================================================================

CLASS CHttpApiHeaders( SrvCommon.CHeaders );
END CHttpApiHeaders;

//================================================================================

TYPE
   TPHttpApiStream = POINTER TO CHttpApiStream;

CLASS CHttpApiStream( SrvCommon.ASrvStream );

   // ASrvStream
   PUBLIC VIRTUAL READONLY PROPERTY
      RequestVerb : HttpCommon.TVerb;
      RequestURI : StringsO.CString;
      RequestHeaders : HttpCommon.TPHttpHeaders;
      ResponseHeaders : HttpCommon.TPHttpHeaders;
      LocalAddress : inetaddr.INETADDR;
      RemoteAddress : inetaddr.INETADDR;
   PUBLIC VIRTUAL PROPERTY
      StatusCode : HttpCommon.THttpResponse;
   
   // all methods can return arCompleted, arNoData, arAbort, arTimeout
   INTERNAL VIRTUAL PROCEDURE ReceiveHeaders() : Sync.TAsyncResult;
   INTERNAL VIRTUAL PROCEDURE ReceiveData( OUT Data : StorageO.AMemoryBuffer ) : Sync.TAsyncResult;
   INTERNAL VIRTUAL PROCEDURE SendHeaders() : Sync.TAsyncResult;
   INTERNAL VIRTUAL PROCEDURE SendData( CONST Data : StorageO.AMemoryBuffer ) : Sync.TAsyncResult;
   INTERNAL VIRTUAL PROCEDURE EndResponse() : Sync.TAsyncResult;
   
   // SELF
   LOCAL WRITEONLY PROPERTY
      HttpQueue : Sync.WAITABLE;
   LOCAL READONLY PROPERTY
      Request : httpapi.PHTTP_REQUEST;
      RequestSpace : CARDINAL;
   
   PRIVATE VAR
      _HttpQueue : Sync.WAITABLE;
      _Request : StorageO.CMemoryBuffer;
      _Response : httpapi.HTTP_RESPONSE;
      _RequestHeaders : CHttpApiHeaders;
      _ResponseHeaders : CHttpApiHeaders;

END CHttpApiStream;

(*================================================================================*)

CLASS IMPLEMENTATION CHttpApiStream;

(*--------------------------------------------------------------------------------*)

   PUBLIC VIRTUAL PROPERTY RequestVerb GET : HttpCommon.TVerb;
   BEGIN
      CASE Request^.Verb OF
      | httpapi.HttpVerbHEAD :
         RETURN HttpCommon.verbHEAD;
      | httpapi.HttpVerbGET :
         RETURN HttpCommon.verbGET;
      | httpapi.HttpVerbPOST :
         RETURN HttpCommon.verbPOST;
      ELSE
         RETURN HttpCommon.verbUnknown;
      END;
   END RequestVerb;

(*--------------------------------------------------------------------------------*)

   PUBLIC VIRTUAL PROPERTY RequestURI GET : StringsO.CString;
   VAR
      s : StringsO.CString;
   BEGIN
      s.FromOA( OA( CARDINAL( Request^.CookedUrl.AbsPathLength >> 1 )-1, Request^.CookedUrl.pAbsPath ));
      RETURN s;
   END RequestURI;

(*--------------------------------------------------------------------------------*)

   PUBLIC VIRTUAL PROPERTY RequestHeaders GET : HttpCommon.TPHttpHeaders;
   BEGIN
      RETURN ADR( _RequestHeaders );
   END RequestHeaders;
   
(*--------------------------------------------------------------------------------*)

   PUBLIC VIRTUAL PROPERTY ResponseHeaders GET : HttpCommon.TPHttpHeaders;
   BEGIN
      RETURN ADR( _ResponseHeaders );
   END ResponseHeaders;
      
(*--------------------------------------------------------------------------------*)

   PUBLIC VIRTUAL PROPERTY LocalAddress GET : inetaddr.INETADDR;
   VAR
      ia : inetaddr.INETADDR;
   BEGIN
      ia.FromM( PBYTE( Request^.Address.pLocalAddress ));
      RETURN ia;
   END LocalAddress;

(*--------------------------------------------------------------------------------*)

   PUBLIC VIRTUAL PROPERTY RemoteAddress GET : inetaddr.INETADDR;
   VAR
      ia : inetaddr.INETADDR;
   BEGIN
      ia.FromM( PBYTE( Request^.Address.pRemoteAddress ));
      RETURN ia;
   END RemoteAddress;

(*--------------------------------------------------------------------------------*)

   PUBLIC PROPERTY StatusCode GET : HttpCommon.THttpResponse;
   BEGIN
      RETURN HttpCommon.THttpResponse( _Response.StatusCode );
   END StatusCode;

(*--------------------------------------------------------------------------------*)

   LOCAL PROPERTY HttpQueue SET( Value : Sync.WAITABLE );
   BEGIN
      _HttpQueue := Value;
   END HttpQueue;
   
(*--------------------------------------------------------------------------------*)

   LOCAL PROPERTY Request GET : httpapi.PHTTP_REQUEST;
   BEGIN
      RETURN _Request.Data;
   END Request;

(*--------------------------------------------------------------------------------*)

   LOCAL PROPERTY RequestSpace GET : CARDINAL;
   BEGIN
      RETURN _Request.Size;
   END RequestSpace;
   
(*--------------------------------------------------------------------------------*)

   PUBLIC PROPERTY StatusCode SET( Value : HttpCommon.THttpResponse );
   CONST
   (*
      RESPONSE_100 = C"Continue";
      RESPONSE_101 = C"Switching Protocols";
      // success
      RESPONSE_201 = C"Created";
      RESPONSE_202 = C"Accepted";
      RESPONSE_203 = C"Non-Authoritative Information";
      RESPONSE_204 = C"No Content";
      RESPONSE_205 = C"Reset Content";
      RESPONSE_206 = C"Partial Content";
      // redirection
      RESPONSE_300 = C"Multiple Choices";
      RESPONSE_301 = C"Moved Permanently";
      RESPONSE_302 = C"Moved Temporarily";
      RESPONSE_303 = C"See Other";
      RESPONSE_304 = C"Not Modified";
      RESPONSE_305 = C"Use Proxy";
      // client error
      RESPONSE_400 = C"Bad Request";
      RESPONSE_401 = C"Unauthorized";
      RESPONSE_402 = C"Payment Required";
      RESPONSE_403 = C"Forbidden";
      RESPONSE_405 = C"Method Not Allowed";
      RESPONSE_406 = C"Not Acceptable";
      RESPONSE_407 = C"Proxy Authentication Required";
      RESPONSE_408 = C"Request Time-out";
      RESPONSE_409 = C"Conflict";
      RESPONSE_410 = C"Gone";
      RESPONSE_411 = C"Length Required";
      RESPONSE_412 = C"Precondition Failed";
      RESPONSE_413 = C"Request Entity Too Large";
      RESPONSE_414 = C"Request-URI Too Large";
      RESPONSE_415 = C"Unsupported Media Type";
      // server error
      RESPONSE_502 = C"Bad Gateway";
      RESPONSE_503 = C"Service Unavailable";
      RESPONSE_504 = C"Gateway Timeout";
      RESPONSE_505 = C"HTTP Version Not Supported";
   *)
      RESPONSE_200 = C"OK";
      RESPONSE_404 = C"Not Found";
      RESPONSE_500 = C"Internal Server Error";
      RESPONSE_501 = C"Not Implemented";
   BEGIN
      CASE Value OF
      | HttpCommon.httpres_200 :
         _Response.pReason := ADR( RESPONSE_200 );
         _Response.ReasonLength := SIZE( RESPONSE_200 )-1;
      | HttpCommon.httpres_404 :
         _Response.pReason := ADR( RESPONSE_404 );
         _Response.ReasonLength := SIZE( RESPONSE_404 )-1;
      | HttpCommon.httpres_500 :
         _Response.pReason := ADR( RESPONSE_500 );
         _Response.ReasonLength := SIZE( RESPONSE_500 )-1;
      | HttpCommon.httpres_501 :
         _Response.pReason := ADR( RESPONSE_501 );
         _Response.ReasonLength := SIZE( RESPONSE_501 )-1;
      ELSE
         ASSERT( FALSE );
         _Response.pReason := NIL;
         _Response.ReasonLength := 0;
      END;
      _Response.StatusCode := CARD16( Value );
   END StatusCode;

(*--------------------------------------------------------------------------------*)

   INTERNAL VIRTUAL PROCEDURE ReceiveHeaders() : Sync.TAsyncResult;
   BEGIN
      _RequestHeaders.FromRequest( Request.Data ); // copy httpapi data to headers
      RETURN Sync.arCompleted;
   END ReceiveHeaders;

(*--------------------------------------------------------------------------------*)

   INTERNAL VIRTUAL PROCEDURE ReceiveData( OUT Data : StorageO.AMemoryBuffer ) : Sync.TAsyncResult;
   VAR
      error : CARDINAL;
      L : CARDINAL;
   BEGIN
      Data.Clear();
      error := httpapi.HttpReceiveRequestEntityBody( _HttpQueue, Request^.RequestId, 0, Data.Data, Data.Size, ADR( L ), NIL );
      IF L < Data.Size THEN
         IF ( error <> winerror.ERROR_SUCCESS ) AND ( error <> winerror.ERROR_HANDLE_EOF ) THEN
            RETURN Sync.arAborted;
         ELSIF L = 0 THEN
            RETURN Sync.arNoData;
         ELSE
            RETURN Sync.arCompleted;
         END;
      ELSIF ( error = winerror.ERROR_SUCCESS ) OR ( error = winerror.ERROR_MORE_DATA ) THEN
         RETURN Sync.arCompleted;
      ELSE
         RETURN Sync.arAborted;
      END;
   END ReceiveData;                           

(*--------------------------------------------------------------------------------*)

   INTERNAL VIRTUAL PROCEDURE SendHeaders() : Sync.TAsyncResult;
   VAR
      error : CARDINAL;
      L : CARDINAL;
   BEGIN
      _Response.Flags := 0;
      _Response.Version.MajorVersion := Request^.Version.MajorVersion;
      _Response.Version.MinorVersion := Request^.Version.MinorVersion;
      _Response.EntityChunkCount := 0;
      _Response.pEntityChunks := NIL;

      _ResponseHeaders.ToResponse( REF _Response );

      error := httpapi.HttpSendHttpResponse( _HttpQueue, Request^.RequestId, 0, ADR( _Response ), NIL, ADR( L ), NIL, 0, NIL, NIL );
      IF error = winerror.ERROR_SUCCESS THEN
         RETURN Sync.arCompleted;
      ELSE
         RETURN Sync.arAborted;
      END;
   END SendHeaders;

(*--------------------------------------------------------------------------------*)

   INTERNAL VIRTUAL PROCEDURE SendData( CONST Data : StorageO.AMemoryBuffer ) : Sync.TAsyncResult;
   VAR
      error : CARDINAL;
      Chunk : httpapi.HTTP_DATA_CHUNK;
      L : CARDINAL;
   BEGIN
      Chunk.DataChunkType := httpapi.HttpDataChunkFromMemory;
      Chunk.FromMemory.pBuffer := Data.Data;
      Chunk.FromMemory.BufferLength := Data.Length;

      error := httpapi.HttpSendResponseEntityBody( _HttpQueue, Request^.RequestId, httpapi.HTTP_SEND_RESPONSE_FLAG_MORE_DATA, 1, ADR( Chunk ), ADR( L ), NIL, 0, NIL, NIL );
      IF error = winerror.ERROR_SUCCESS THEN
         RETURN Sync.arCompleted;
      ELSE
         RETURN Sync.arAborted;
      END;
   END SendData;

(*--------------------------------------------------------------------------------*)

   INTERNAL VIRTUAL PROCEDURE EndResponse() : Sync.TAsyncResult;
   VAR
      error : CARDINAL;
      L : CARDINAL;
   BEGIN
      IF _ResponseHeaders.Contains( HttpCommon.ContentLength ) OR _ResponseHeaders.Contains( HttpCommon.TransferEncoding ) THEN // length is known, suppose data are sent correctly
         error := httpapi.HttpSendResponseEntityBody( _HttpQueue, Request^.RequestId, 0, 0, NIL, ADR( L ), NIL, 0, NIL, NIL );
      ELSE // length is unknown, close connection explicitly
         error := httpapi.HttpSendResponseEntityBody( _HttpQueue, Request^.RequestId, httpapi.HTTP_SEND_RESPONSE_FLAG_DISCONNECT, 0, NIL, ADR( L ), NIL, 0, NIL, NIL );
      END;
      IF error = winerror.ERROR_SUCCESS THEN
         RETURN Sync.arCompleted;
      ELSE
         RETURN Sync.arAborted;
      END;
   END EndResponse;

(*--------------------------------------------------------------------------------*)

BEGIN
   _HttpQueue := NIL;
   _Request.Size := 16384;
   Storage.Fill( ADR( _Response ), SIZE( _Response ), 0 );
   StatusCode := HttpCommon.httpres_200; // at least StatusCode must be filled, it is used in outer property StatusCode
END CHttpApiStream;

(*================================================================================*)

CLASS CHttpApiSrv( SrvCommon.ASrvCommon );

   // APoolDelegate
   LOCAL VIRTUAL PROCEDURE OnHandle( Result : Sync.TAsyncResult; PoolHandle : threadpool.TPoolHandle; UserId : PTR );

   // IHttpSrv
   PUBLIC VIRTUAL READONLY PROPERTY
      Running : BOOLEAN;

   PUBLIC VIRTUAL PROCEDURE Start() : Sync.TAsyncResult;
   PUBLIC VIRTUAL PROCEDURE Stop();
   
   // SELF
   INTERNAL VIRTUAL PROCEDURE GetNewStream() : SrvCommon.TPSrvStream;

   PRIVATE VAR
      _Running : BOOLEAN := FALSE;
      _HttpQueue : Sync.WAITABLE := NIL;
      _HttpOverlapped : windows.OVERLAPPED;
      _HRequestSignal : Sync.WAITABLE := NIL;
      _HPoolHandle : Sync.WAITABLE := NIL;
   
   PRIVATE PROCEDURE StartWaitingRequest() : Sync.TAsyncResult;
   
   INITIALLY CHttpApiSrv();
   FINALLY CHttpApiSrv();
END CHttpApiSrv;

//================================================================================

CLASS IMPLEMENTATION CHttpApiSrv;

//--------------------------------------------------------------------------------

   LOCAL VIRTUAL PROCEDURE OnHandle( Result : Sync.TAsyncResult; PoolHandle : threadpool.TPoolHandle; UserId : PTR );
   VAR
      EOF : BOOLEAN := FALSE;
      received : CARDINAL;
   BEGIN
      IF Result <> Sync.arCompleted THEN
         RETURN;

      ELSIF PreparedStream <> NIL THEN // we are waiting now
         logger()^.LogS( dlcInfo, L"HTTP", L"HTTP request received" );

         IF windows.GetOverlappedResult( _HttpQueue, ADR( _HttpOverlapped ), ADR( received ), windows.False ) = windows.False THEN
            CASE CARDINAL( windows.GetLastError()) OF
            | winerror.ERROR_HANDLE_EOF : // OK
               EOF := TRUE;
            | winerror.ERROR_IO_PENDING : // nothing received yet
               RETURN;
            ELSE
               // Start or some error, start operation again
            END;
         ELSE
            EOF := TRUE;
         END;
         
         // TODO long request
         IF EOF THEN // OK, process
            ProcessPreparedStream();
         END;
      END;
      
      StartWaitingRequest();
   END OnHandle;

//--------------------------------------------------------------------------------

   PUBLIC VIRTUAL PROPERTY Running GET : BOOLEAN;
   BEGIN
      RETURN _Running;
   END Running;

//--------------------------------------------------------------------------------

   PUBLIC VIRTUAL PROCEDURE Start() : Sync.TAsyncResult;
   VAR
      Error : CARDINAL;
      UrlPrefix : StringsO.CString;
      s : ARRAY [0..31] OF WCHAR;
   BEGIN
      IF _Running THEN
         RETURN Sync.arCompleted;
      END;
   
      IF ( Mode = HttpSrv.mdHttp ) OR ( Mode = HttpSrv.mdBoth ) THEN
         UrlPrefix := RootPath;
         Strings.FromCARD32W( Port, 10, OUT s );
         UrlPrefix.PrependOA( s );
         UrlPrefix.PrependOA( L"http://+:" );
         Error := httpapi.HttpAddUrl( _HttpQueue, UrlPrefix.szData, NIL );
         IF Error <> 0 THEN
            RETURN Sync.arCannotStart;
         END;
      END;

      IF ( Mode = HttpSrv.mdHttps ) OR ( Mode = HttpSrv.mdBoth ) THEN
         UrlPrefix := RootPath;
         Strings.FromCARD32W( SslPort, 10, OUT s );
         UrlPrefix.PrependOA( s );
         UrlPrefix.PrependOA( L"https://+:" );
         Error := httpapi.HttpAddUrl( _HttpQueue, UrlPrefix.szData, NIL );
         IF Error <> 0 THEN
            RETURN Sync.arCannotStart;
         END;
      END;
      
      IF NOT threadpool.pool()^.WaitHandle( ADR( SELF ), 0, Sync.FOREVER, FALSE, FALSE, _HRequestSignal, OUT _HPoolHandle ) THEN
         RETURN Sync.arCannotStart;
      END;
      // force switching to another thread (simulate request arriving), waiting will be starte from the another thread
      Sync.Signal( _HRequestSignal );
      
      _Running := TRUE;
      RETURN Sync.arCompleted;
   END Start;

//--------------------------------------------------------------------------------

   PUBLIC VIRTUAL PROCEDURE Stop();
   BEGIN
      IF NOT _Running THEN
         RETURN;
      END;
      
      IF _HPoolHandle <> NIL THEN
         threadpool.pool()^.Abort( REF _HPoolHandle );
      END;
   END Stop;
   
//--------------------------------------------------------------------------------

   INTERNAL VIRTUAL PROCEDURE GetNewStream() : SrvCommon.TPSrvStream;
   BEGIN
      RETURN NEW( CHttpApiStream );
   END GetNewStream;

//--------------------------------------------------------------------------------

   PRIVATE PROCEDURE StartWaitingRequest() : Sync.TAsyncResult;
   VAR
      Error : CARDINAL;
      Stream : TPHttpApiStream;
   BEGIN
      ASSERT( _HttpQueue <> NIL );
      Storage.Zero( ADR( _HttpOverlapped ), SIZE( _HttpOverlapped ));
      _HttpOverlapped.hEvent := _HRequestSignal;

      LOOP
         PrepareStream();
         Stream := TPHttpApiStream( PreparedStream );
         Stream^.HttpQueue := _HttpQueue;
            
         Error := httpapi.HttpReceiveHttpRequest( _HttpQueue, httpapi.HTTP_NULL_ID, 0, Stream^.Request, Stream^.RequestSpace, NIL, ADR( _HttpOverlapped ));

         CASE Error OF
         | winerror.NO_ERROR : // OK, have request
            ProcessPreparedStream();

         | winerror.ERROR_IO_PENDING :
            RETURN Sync.arPending;
         ELSE
            logger()^.LogSC( dlcError, L"HTTP", L"Unable to receive HTTP request", Error );
            RETURN Sync.arCannotStart;
         END;
      END; // LOOP
   END StartWaitingRequest;

//--------------------------------------------------------------------------------

   INITIALLY CHttpApiSrv();
   VAR
      Error : CARDINAL;
      httpAPIVersion : httpapi.HTTPAPI_VERSION := httpapi.HTTPAPI_VERSION_1;
   BEGIN
      _HRequestSignal := Sync.CreateAutoresetSignal( FALSE, L"" );
      ASSERT( _HRequestSignal <> NIL );

      Error := httpapi.HttpInitialize( httpAPIVersion, httpapi.HTTP_INITIALIZE_SERVER, NIL );
      IF Error <> 0 THEN
         logger()^.LogSC( dlcError, L"HTTP", L"Unable to initialize HTTP server", Error );
         RETURN;
      END;
      
      Error := httpapi.HttpCreateHttpHandle( OUT _HttpQueue, 0 );
      IF Error <> 0 THEN
         logger()^.LogSC( dlcError, L"HTTP", L"Unable to create HTTP request queue: ", Error );
         RETURN;
      END;
   END CHttpApiSrv;

//--------------------------------------------------------------------------------

   FINALLY CHttpApiSrv();
   BEGIN
      Dispose();
      
      IF _HttpQueue <> NIL THEN
         windows.CloseHandle( _HttpQueue );
         _HttpQueue := NIL;
      END;
      
      httpapi.HttpTerminate( httpapi.HTTP_INITIALIZE_SERVER, NIL );
      
      IF _HRequestSignal <> NIL THEN
         Sync.DeleteSignal( REF _HRequestSignal );
      END;
   END CHttpApiSrv;

//--------------------------------------------------------------------------------

END CHttpApiSrv;

//================================================================================

VAR
   HttpServer : POINTER TO CHttpApiSrv := NIL;

//--------------------------------------------------------------------------------

PROCEDURE srv() : HttpSrv.TPHttpServer;
BEGIN
   IF HttpServer = NIL THEN
      NEW( HttpServer );
   END;
   RETURN HttpServer;
END srv;

//--------------------------------------------------------------------------------

PROCEDURE Cleanup();
BEGIN
   IF HttpServer <> NIL THEN
      HttpServer^.Dispose();
      HttpServer^.Release();
      HttpServer := NIL;
   END;
END Cleanup;

//================================================================================

END SrvHttpApi.