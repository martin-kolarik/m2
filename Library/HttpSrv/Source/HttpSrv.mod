IMPLEMENTATION MODULE HttpSrv;

FROM Log IMPORT
   logger, dlcError, dlcInfo;
   
IMPORT
   lists,
   Storage,
   StorageO,
   Strings,
   threadpool,
   windows,
   winerror;

//================================================================================

CLASS CHeaders IMPLEMENTS IHttpHeaders;

   // IHttpHeaders
   PUBLIC VIRTUAL PROCEDURE Contains( Header : TKnownHeader ) : BOOLEAN;
   PUBLIC VIRTUAL PROCEDURE Get( Header : TKnownHeader; OUT Value : ARRAY OF WCHAR ) : BOOLEAN;
   PUBLIC VIRTUAL PROCEDURE Add( Header : TKnownHeader; CONST Value : ARRAY OF WCHAR );
   
   PUBLIC VIRTUAL PROCEDURE Enumerate( Known, Uknown : BOOLEAN; REF ES : PTR; OUT Name, Value : ARRAY OF WCHAR ) : BOOLEAN;

   PUBLIC VIRTUAL PROCEDURE ContainsUnknown( CONST Name : ARRAY OF WCHAR ) : BOOLEAN;
   PUBLIC VIRTUAL PROCEDURE GetUnknown( CONST Name : ARRAY OF WCHAR; OUT Value : ARRAY OF WCHAR ) : BOOLEAN;
   PUBLIC VIRTUAL PROCEDURE AddUnknown( CONST Name : ARRAY OF WCHAR; CONST Value : ARRAY OF WCHAR ) : BOOLEAN;

   // CHeaders
   PRIVATE VAR
      Map : maps.CStringMap;
      
   LOCAL PROCEDURE FromRequest( Request : httpapi.TPHttpRequest );
   
   PRIVATE PROCEDURE FromSysApi( sysapiHeader : httpapi.HTTP_HEADER_ID; OUT header : THttpHeader ) : BOOLEAN;
   PRIVATE PROCEDURE ToSysApi( header : THttpHeader; OUT sysapiHeader : httpapi.HTTP_HEADER_ID ) : BOOLEAN;
END CHeaders;

//--------------------------------------------------------------------------------

CLASS CHeaders IMPLEMENTS IHttpHeaders;

//--------------------------------------------------------------------------------

   PUBLIC VIRTUAL PROCEDURE Contains( Header : TKnownHeader ) : BOOLEAN;
   BEGIN
      IF NOT ToSysApi( Header, OUT sysapiHeader ) THEN
         RETURN FALSE;
      END;
      RETURN TRUE;
   END Contains;

//--------------------------------------------------------------------------------

   PUBLIC VIRTUAL PROCEDURE Get( Header : TKnownHeader; OUT Value : ARRAY OF WCHAR ) : BOOLEAN;
   BEGIN
   END Get;

//--------------------------------------------------------------------------------

   PUBLIC VIRTUAL PROCEDURE Add( Header : TKnownHeader; CONST Value : ARRAY OF WCHAR );
   BEGIN
   END Add;
   
//--------------------------------------------------------------------------------

   PUBLIC VIRTUAL PROCEDURE Enumerate( Known, Uknown : BOOLEAN; REF ES : PTR; OUT Name, Value : ARRAY OF WCHAR ) : BOOLEAN;
   BEGIN
   END Enumerate;

//--------------------------------------------------------------------------------

   PUBLIC VIRTUAL PROCEDURE ContainsUnknown( CONST Name : ARRAY OF WCHAR ) : BOOLEAN;
   BEGIN
      RETURN FALSE;
   END ContainsUnknown;

//--------------------------------------------------------------------------------

   PUBLIC VIRTUAL PROCEDURE GetUnknown( CONST Name : ARRAY OF WCHAR; OUT Value : ARRAY OF WCHAR ) : BOOLEAN;
   BEGIN
      RETURN FALSE;
   END GetUnknown;

//--------------------------------------------------------------------------------

   PUBLIC VIRTUAL PROCEDURE AddUnknown( CONST Name : ARRAY OF WCHAR; CONST Value : ARRAY OF WCHAR );
   BEGIN
   END AddUnknown;

//--------------------------------------------------------------------------------

   PUBLIC PROCEDURE FromRequest( Request : httpapi.TPHttpRequest );
   VAR
      len : CARDINAL;
      pstr : PCHAR;
   BEGIN
      FOR hdr := httpapi.HttpHeaderCacheControl TO httpapi.HttpHeaderRequestMaximum-1 DO
         len := Request^.Headers.KnownHeaders[hdr].RawValueLength;
         IF len = 0 THEN
            CONTINUE;
         END;
         pstr := Request^.Headers.KnownHeaders[hdr].pRawValue;
         CASE hdr OF
         END; // CASE
      END;
   END FromRequest;
   
//--------------------------------------------------------------------------------

   PRIVATE PROCEDURE FromSysApi( sysapiHeader : httpapi.HTTP_HEADER_ID; OUT header : THttpHeader ) : BOOLEAN;
   BEGIN
      RETURN FALSE;
   END FromSysApi;

//--------------------------------------------------------------------------------

   PRIVATE PROCEDURE ToSysApi( header : THttpHeader; OUT sysapiHeader : httpapi.HTTP_HEADER_ID ) : BOOLEAN;
   BEGIN
      RETURN FALSE;
   END ToSysApi;

//--------------------------------------------------------------------------------

END CHeaders;

//================================================================================

CLASS IMPLEMENTATION CContainer;

//--------------------------------------------------------------------------------

   PUBLIC PROCEDURE Clear();
   BEGIN
      Models.Dispose();
   END Clear;

//--------------------------------------------------------------------------------

   PUBLIC PROCEDURE AddModel( CONST Name : ARRAY OF WCHAR; REF Model : maps.CStringMap );
   BEGIN
      IF Models.ContainsOA( Name ) THEN
         RETURN;
      END;
      Models.AddOA( Name, ADR( Model ));
   END AddModel;

//--------------------------------------------------------------------------------

   PUBLIC PROCEDURE RemoveModel( CONST Name : ARRAY OF WCHAR );
   BEGIN
      Models.RemoveOA( Name );
   END RemoveModel;

//--------------------------------------------------------------------------------

   PUBLIC PROCEDURE GetModelOA( CONST Name : ARRAY OF WCHAR; OUT PModel : maps.TPStringMap ) : BOOLEAN;
   BEGIN
      RETURN Models.GetOA( Name, OUT PModel );
   END GetModelOA;

//--------------------------------------------------------------------------------

   PUBLIC PROCEDURE GetModel( CONST Name : StringsO.CString; OUT PModel : maps.TPStringMap ) : BOOLEAN;
   BEGIN
      RETURN Models.Get( Name, OUT PModel );
   END GetModel;

//--------------------------------------------------------------------------------

BEGIN FINALLY
   Clear();
END CContainer;

//================================================================================

CLASS CHttpSrv( threadpool.APoolDelegate ) IMPLEMENTS IHttpServer;

   // APoolDelegate
   LOCAL VIRTUAL PROCEDURE OnHandle( Result : Sync.TAsyncResult; PoolHandle : Sync.WAITABLE; UserId : PTR );

   // IHttpSrv
   PUBLIC VIRTUAL READONLY PROPERTY
      Running : BOOLEAN;
   PUBLIC VIRTUAL PROPERTY
      Mode : TMode;
      Port : CARDINAL;
      SslPort : CARDINAL;
      RootName : StringsO.CString;

   PUBLIC VIRTUAL PROCEDURE Start() : Sync.TAsyncResult;
   PUBLIC VIRTUAL PROCEDURE Stop();
   
   PUBLIC VIRTUAL PROCEDURE RegisterController( Controller : TPController );
   PUBLIC VIRTUAL PROCEDURE ForgetController( Controller : TPController );

   // CHttpSrv
   PRIVATE VAR
      _Running : BOOLEAN := FALSE;
      _Mode : TMode := mdHttp;
      _Port : CARDINAL := 8080;
      _SslPort : CARDINAL := 8443;
      _RootName : StringsO.CString;
      _Controllers : lists.CPtrList;

      _HttpHandle : Sync.WAITABLE := NIL;
      _HttpRequest : StorageO.CMemoryBuffer;
      _HttpOverlapped : windows.OVERLAPPED;
      _HRequestSignal : Sync.WAITABLE := NIL;
      _HPoolHandle : Sync.WAITABLE := NIL;
   
   PUBLIC PROCEDURE Dispose();
   PROCEDURE StartWaitingRequest() : Sync.TAsyncResult;

   INITIALLY CHttpSrv();
   FINALLY CHttpSrv();
END CHttpSrv;

//================================================================================

CLASS IMPLEMENTATION CHttpSrv;

//--------------------------------------------------------------------------------

   LOCAL VIRTUAL PROCEDURE OnHandle( Result : Sync.TAsyncResult; PoolHandle : Sync.WAITABLE; UserId : PTR );
   VAR
      EOF : BOOLEAN := FALSE;
      request : httpapi.PHTTP_REQUEST;
      received : CARDINAL;
   BEGIN
      IF Result <> Sync.arCompleted THEN
         RETURN;
      END;
   
      logger()^.LogS( dlcInfo, L"HTTP", L"HTTP request received" );

      IF windows.GetOverlappedResult( _HttpHandle, ADR( _HttpOverlapped ), ADR( received ), windows.False ) = windows.False THEN
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
         request := _HttpRequest.Data;
      END;
      
      StartWaitingRequest();
   END OnHandle;

//--------------------------------------------------------------------------------

   PUBLIC VIRTUAL PROPERTY Running GET : BOOLEAN;
   BEGIN
      RETURN _Running;
   END Running;

//--------------------------------------------------------------------------------

   PUBLIC VIRTUAL PROPERTY Mode GET : TMode;
   BEGIN
      RETURN _Mode;
   END Mode;

//--------------------------------------------------------------------------------

   PUBLIC VIRTUAL PROPERTY Mode SET( Value : TMode );
   VAR
      b : BOOLEAN;
   BEGIN
      IF Value = _Mode THEN
         RETURN;
      END;
      IF _Running THEN
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
      IF _Running AND (( _Mode = mdHttp ) OR ( _Mode = mdBoth )) THEN
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
      IF _Running AND (( _Mode = mdHttps ) OR ( _Mode = mdBoth )) THEN
         Stop();
         _SslPort := Value;
         Start();
      ELSE
         _SslPort := Value;
      END;
   END SslPort;

//--------------------------------------------------------------------------------

   PUBLIC VIRTUAL PROPERTY RootName GET : StringsO.CString;
   BEGIN
      RETURN _RootName;
   END RootName;

//--------------------------------------------------------------------------------

   PUBLIC VIRTUAL PROPERTY RootName SET( CONST Value : StringsO.CString );
   VAR
      b : BOOLEAN;
   BEGIN
      IF _RootName = Value THEN
         RETURN;
      END;
      IF _Running THEN
         b := TRUE;
         Stop();
      END;

      _RootName := Value;
      IF _RootName[_RootName.Length-1] <> L"/" THEN
         _RootName.AppendOA( L"/" );
      END;

      IF b THEN
         Start();
      END;
   END RootName;

//--------------------------------------------------------------------------------

   PUBLIC VIRTUAL PROCEDURE Start() : Sync.TAsyncResult;
   VAR
      Error : CARDINAL;
      h : windows.HANDLE;
      Result : Sync.TAsyncResult;
      UrlPrefix : StringsO.CString;
      s : ARRAY [0..31] OF WCHAR;
   BEGIN
      IF _Running THEN
         RETURN Sync.arCompleted;
      END;
   
      IF ( _Mode = mdHttp ) OR ( _Mode = mdBoth ) THEN
         UrlPrefix := _RootName;
         Strings.FromCARD32W( _Port, 10, OUT s );
         UrlPrefix.PrependOA( s );
         UrlPrefix.PrependOA( L"http://+:" );
         Error := httpapi.HttpAddUrl( _HttpHandle, UrlPrefix.szData, NIL );
         IF Error <> 0 THEN
            RETURN Sync.arCannotStart;
         END;
      END;

      IF ( _Mode = mdHttps ) OR ( _Mode = mdBoth ) THEN
         UrlPrefix := _RootName;
         Strings.FromCARD32W( _SslPort, 10, OUT s );
         UrlPrefix.PrependOA( s );
         UrlPrefix.PrependOA( L"https://+:" );
         Error := httpapi.HttpAddUrl( _HttpHandle, UrlPrefix.szData, NIL );
         IF Error <> 0 THEN
            RETURN Sync.arCannotStart;
         END;
      END;
      
      IF NOT threadpool.pool()^.WaitHandle( ADR( SELF ), 0, Sync.FORSAFETY, FALSE, _HRequestSignal, OUT _HPoolHandle ) THEN
         RETURN Sync.arCannotStart;
      END;
      // force switching to another thread, waiting will be starte from the another thread
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

   PUBLIC VIRTUAL PROCEDURE RegisterController( Controller : TPController );
   BEGIN
      _Controllers.Add( Controller, 0 );
   END RegisterController;

//--------------------------------------------------------------------------------

   PUBLIC VIRTUAL PROCEDURE ForgetController( Controller : TPController );
   BEGIN
      _Controllers.Remove( Controller );
   END ForgetController;

//--------------------------------------------------------------------------------

   PUBLIC PROCEDURE Dispose();
   BEGIN
      Stop();
      _Controllers.Dispose();
   END Dispose;

//--------------------------------------------------------------------------------

   PROCEDURE StartWaitingRequest() : Sync.TAsyncResult;
   VAR
      Error : CARDINAL;
   BEGIN
      ASSERT( _HttpHandle <> NIL );
      Storage.Zero( ADR( _HttpOverlapped ), SIZE( _HttpOverlapped ));
      _HttpOverlapped.hEvent := _HRequestSignal;
      
      Error := httpapi.HttpReceiveHttpRequest( _HttpHandle, httpapi.HTTP_NULL_ID, 0, _HttpRequest.Data, _HttpRequest.Size, NIL, ADR( _HttpOverlapped ));

      IF Error = winerror.ERROR_IO_PENDING THEN
         RETURN Sync.arPending;
      ELSE
         logger()^.LogSC( dlcError, L"HTTP", L"Unable to receive HTTP request", Error );
         RETURN Sync.arCannotStart;
      END;
   END StartWaitingRequest;

//--------------------------------------------------------------------------------

   INITIALLY CHttpSrv();
   VAR
      Error : CARDINAL;
      httpAPIVersion : httpapi.HTTPAPI_VERSION := httpapi.HTTPAPI_VERSION_1;
   BEGIN
      _RootName.FromOA( L"/" );

      _HRequestSignal := Sync.CreateAutoresetSignal( FALSE, L"" );
      ASSERT( _HRequestSignal <> NIL );

      Error := httpapi.HttpInitialize( httpAPIVersion, httpapi.HTTP_INITIALIZE_SERVER, NIL );
      IF Error <> 0 THEN
         logger()^.LogSC( dlcError, L"HTTP", L"Unable to initialize HTTP server", Error );
         RETURN;
      END;
      
      Error := httpapi.HttpCreateHttpHandle( OUT _HttpHandle, 0 );
      IF Error <> 0 THEN
         logger()^.LogSC( dlcError, L"HTTP", L"Unable to create HTTP request queue: ", Error );
         RETURN;
      END;
      
      _HttpRequest.Size := 16384;
   END CHttpSrv;

//--------------------------------------------------------------------------------

   FINALLY CHttpSrv();
   BEGIN
      Dispose();
      
      IF _HttpHandle <> NIL THEN
         windows.CloseHandle( _HttpHandle );
         _HttpHandle := NIL;
      END;
      
      httpapi.HttpTerminate( httpapi.HTTP_INITIALIZE_SERVER, NIL );
      
      IF _HRequestSignal <> NIL THEN
         Sync.DeleteSignal( REF _HRequestSignal );
      END;
   END CHttpSrv;

//--------------------------------------------------------------------------------

END CHttpSrv;

//================================================================================

VAR
   Server : POINTER TO CHttpSrv := NIL;

//--------------------------------------------------------------------------------

PROCEDURE srv() : TPHttpServer;
BEGIN
   IF Server = NIL THEN
      NEW( Server );
   END;
   RETURN Server;
END srv;

//--------------------------------------------------------------------------------

PROCEDURE Cleanup();
BEGIN
   IF Server <> NIL THEN
      Server^.Dispose();
      Server^.Release();
      Server := NIL;
   END;
END Cleanup;

//================================================================================

PROCEDURE fileView( CONST Path : ARRAY OF WCHAR ) : TPView;
BEGIN
   RETURN NIL;
END fileView;

//--------------------------------------------------------------------------------

PROCEDURE redirectView( CONST URL : ARRAY OF WCHAR ) : TPView;
BEGIN
   RETURN NIL;
END redirectView;

//--------------------------------------------------------------------------------

PROCEDURE modelView( CONST viewName : ARRAY OF WCHAR; REF model : maps.CStringMap ) : TPView;
BEGIN
   RETURN NIL;
END modelView;

//--------------------------------------------------------------------------------

PROCEDURE modelViewStream( CONST viewName : ARRAY OF WCHAR; viewSource : IOO.TPStream; REF model : maps.CStringMap ) : TPView;
BEGIN
   RETURN NIL;
END modelViewStream;

//--------------------------------------------------------------------------------

PROCEDURE modelViewContainer( CONST viewName : ARRAY OF WCHAR; REF model : ARRAY OF maps.CStringMap ) : TPView;
BEGIN
   RETURN NIL;
END modelViewContainer;

//--------------------------------------------------------------------------------

PROCEDURE modelViewContainerStream( CONST viewName : ARRAY OF WCHAR; viewSource : IOO.TPStream; REF model : ARRAY OF maps.CStringMap ) : TPView;
BEGIN
   RETURN NIL;
END modelViewContainerStream;

//================================================================================

END HttpSrv.