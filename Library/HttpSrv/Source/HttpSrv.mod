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
   PUBLIC VIRTUAL PROCEDURE Get( Header : TKnownHeader; OUT Value : StringsO.IString ) : BOOLEAN;
   PUBLIC VIRTUAL PROCEDURE Add( Header : TKnownHeader; CONST Value : StringsO.IString );
   
   PUBLIC VIRTUAL PROCEDURE Enumerate( Known, Uknown : BOOLEAN; REF ES : PTR; OUT Name, Value : StringsO.IString ) : BOOLEAN;

   PUBLIC VIRTUAL PROCEDURE ContainsUnknown( CONST Name : ARRAY OF WCHAR ) : BOOLEAN;
   PUBLIC VIRTUAL PROCEDURE GetUnknown( CONST Name : ARRAY OF WCHAR; OUT Value : StringsO.IString ) : BOOLEAN;
   PUBLIC VIRTUAL PROCEDURE AddUnknown( CONST Name : ARRAY OF WCHAR; CONST Value : StringsO.IString );

   // CHeaders
   PRIVATE VAR
      RequestFlag : BOOLEAN := FALSE; // by default headers are output
      Request : httpapi.PHTTP_REQUEST := NIL;
      KnownCache : maps.CCardinalMap; // cache for known headers
      UnknownCache : maps.CStringMap; // cache for unknown headers
      
   LOCAL PROCEDURE FromRequest( Request : httpapi.PHTTP_REQUEST );
   
   PRIVATE PROCEDURE FromSysApi( sysapiHeader : httpapi.HTTP_HEADER_ID; OUT header : TKnownHeader ) : BOOLEAN;
   PRIVATE PROCEDURE ToSysApi( header : TKnownHeader; OUT sysapiHeader : httpapi.HTTP_HEADER_ID ) : BOOLEAN;
END CHeaders;

//--------------------------------------------------------------------------------

CLASS IMPLEMENTATION CHeaders;

//--------------------------------------------------------------------------------

   PUBLIC VIRTUAL PROCEDURE Contains( Header : TKnownHeader ) : BOOLEAN;
   VAR
      s : StringsO.CString;
   BEGIN
      RETURN Get( Header, OUT s );
   END Contains;

//--------------------------------------------------------------------------------

   PUBLIC VIRTUAL PROCEDURE Get( Header : TKnownHeader; OUT Value : StringsO.IString ) : BOOLEAN;
   VAR
      sysapiHeader : httpapi.HTTP_HEADER_ID;
      s : StringsO.TPString;
   BEGIN
      IF KnownCache.Get( CARDINAL( Header ), OUT s ) THEN
         // fall down
      ELSIF NOT RequestFlag THEN
         RETURN FALSE;
      ELSIF NOT ToSysApi( Header, OUT sysapiHeader ) THEN
         RETURN FALSE;
      ELSIF Request^.Headers.KnownHeaders[CARDINAL( sysapiHeader )].RawValueLength = 0 THEN
         RETURN FALSE;
      ELSE
         s := NEW( StringsO.CString );
         s^.FromOAA(
            0,
            OA( CARDINAL( Request^.Headers.KnownHeaders[CARDINAL( sysapiHeader )].RawValueLength )-1, Request^.Headers.KnownHeaders[CARDINAL( sysapiHeader )].pRawValue ));
         KnownCache.Add( CARDINAL( Header ), s );
         // fall down
      END;

      Value := s^;
      RETURN TRUE;
   END Get;

//--------------------------------------------------------------------------------

   PUBLIC VIRTUAL PROCEDURE Add( Header : TKnownHeader; CONST Value : StringsO.IString );
   VAR
      s : StringsO.TPString;
   BEGIN
      IF RequestFlag THEN
         RETURN;
      ELSIF KnownCache.Get( CARDINAL( Header ), OUT s ) THEN
         s^ := Value;
      ELSE
         s := NEW( StringsO.CString );
         KnownCache.Add( CARDINAL( Header ), s );
      END;
   END Add;
   
//--------------------------------------------------------------------------------

   PUBLIC VIRTUAL PROCEDURE Enumerate( Known, Uknown : BOOLEAN; REF ES : PTR; OUT Name, Value : StringsO.IString ) : BOOLEAN;
   BEGIN
      ASSERT( FALSE );
      RETURN FALSE;
   END Enumerate;

//--------------------------------------------------------------------------------

   PUBLIC VIRTUAL PROCEDURE ContainsUnknown( CONST Name : ARRAY OF WCHAR ) : BOOLEAN;
   VAR
      s : StringsO.CString;
   BEGIN
      RETURN GetUnknown( Name, OUT s );
   END ContainsUnknown;

//--------------------------------------------------------------------------------

   PUBLIC VIRTUAL PROCEDURE GetUnknown( CONST Name : ARRAY OF WCHAR; OUT Value : StringsO.IString ) : BOOLEAN;
   VAR
      c : CARDINAL;
      found : BOOLEAN := FALSE;
      header : httpapi.PHTTP_UNKNOWN_HEADER;
      i : INTEGER;
      n : StringsO.CString;
      na : ARRAY [0..255] OF CHAR;      
      s : StringsO.TPString;
   BEGIN
      n.FromOA( Name );
      n.Lowerize();

      IF UnknownCache.Get( n, OUT s ) THEN
         Value := s^;
         RETURN TRUE;

      ELSIF NOT RequestFlag THEN
         RETURN FALSE;
      END;

      n.ToOAA( 0, OUT na, OUT c );
      header := Request^.Headers.pUnknownHeaders;
      FOR i := 0 TO INTEGER( Request^.Headers.UnknownHeaderCount )-1 DO
         IF EQUALS( na, OA( CARDINAL( header^.NameLength )-1, header^.pName )) THEN
            found := TRUE;
            EXIT;
         END;
         INC( header, SIZE( httpapi.HTTP_UNKNOWN_HEADER ));
      END; // FOR
      IF NOT found THEN
         RETURN FALSE;

      ELSE
         s := NEW( StringsO.CString );
         s^.FromOAA( 0, OA( CARDINAL( header^.RawValueLength )-1, header^.pRawValue ));
         UnknownCache.Add( n, s );

         Value := s^;
         RETURN TRUE;
      END;
   END GetUnknown;

//--------------------------------------------------------------------------------

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
         s^ := Value;
      ELSE
         s := NEW( StringsO.CString );
         UnknownCache.Add( n, s );
      END;
   END AddUnknown;

//--------------------------------------------------------------------------------

   LOCAL PROCEDURE FromRequest( Request : httpapi.PHTTP_REQUEST );
   BEGIN
      RequestFlag := TRUE;
      SELF.Request := Request;
   END FromRequest;
   
//--------------------------------------------------------------------------------

   PRIVATE PROCEDURE FromSysApi( sysapiHeader : httpapi.HTTP_HEADER_ID; OUT header : TKnownHeader ) : BOOLEAN;
   VAR
      found : BOOLEAN := TRUE;
   BEGIN
      CASE sysapiHeader OF
      | httpapi.HttpHeaderCacheControl :
         header := CacheControl;
      | httpapi.HttpHeaderConnection :
         header := Connection;
      | httpapi.HttpHeaderDate :
         header := Date;
      | httpapi.HttpHeaderKeepAlive :
         header := KeepAlive;
      | httpapi.HttpHeaderPragma :
         header := Pragma;
      | httpapi.HttpHeaderTrailer :
         header := Trailer;
      | httpapi.HttpHeaderTransferEncoding :
         header := TransferEncoding;
      | httpapi.HttpHeaderUpgrade :
         header := Upgrade;
      | httpapi.HttpHeaderVia :
         header := Via;
      | httpapi.HttpHeaderWarning :
         header := Warning;

      | httpapi.HttpHeaderAllow :
         header := Allow;
      | httpapi.HttpHeaderContentLength :
         header := ContentLength;
      | httpapi.HttpHeaderContentType :
         header := ContentType;
      | httpapi.HttpHeaderContentEncoding :
         header := ContentEncoding;
      | httpapi.HttpHeaderContentLanguage :
         header := ContentLanguage;
      | httpapi.HttpHeaderContentLocation :
         header := ContentLocation;
      | httpapi.HttpHeaderContentMd5 :
         header := ContentMd5;
      | httpapi.HttpHeaderContentRange :
         header := ContentRange;
      | httpapi.HttpHeaderExpires :
         header := Expires;
      | httpapi.HttpHeaderLastModified :
         header := LastModified;
      ELSE
         found := FALSE;
      END;
      IF found THEN
         RETURN TRUE;
      END;
      
      IF RequestFlag THEN
         CASE sysapiHeader OF
         // Request Headers
         | httpapi.HttpHeaderAccept :
            header := Accept;
         | httpapi.HttpHeaderAcceptCharset :
            header := AcceptCharset;
         | httpapi.HttpHeaderAcceptEncoding :
            header := AcceptEncoding;
         | httpapi.HttpHeaderAcceptLanguage :
            header := AcceptLanguage;
         | httpapi.HttpHeaderAuthorization :
            header := Authorization;
         | httpapi.HttpHeaderCookie :
            header := Cookie;
         | httpapi.HttpHeaderExpect :
            header := Expect;
         | httpapi.HttpHeaderFrom :
            header := From;
         | httpapi.HttpHeaderHost :
            header := Host;
         | httpapi.HttpHeaderIfMatch :
            header := IfMatch;

         | httpapi.HttpHeaderIfModifiedSince :
            header := IfModifiedSince;
         | httpapi.HttpHeaderIfNoneMatch :
            header := IfNoneMatch;
         | httpapi.HttpHeaderIfRange :
            header := IfRange;
         | httpapi.HttpHeaderIfUnmodifiedSince :
            header := IfUnmodifiedSince;
         | httpapi.HttpHeaderMaxForwards :
            header := MaxForwards;
         | httpapi.HttpHeaderProxyAuthorization :
            header := ProxyAuthorization;
         | httpapi.HttpHeaderReferer :
            header := Referer;
         | httpapi.HttpHeaderRange :
            header := Range;
         | httpapi.HttpHeaderTe :
            header := Te;
         | httpapi.HttpHeaderTranslate :
            header := Translate;

         | httpapi.HttpHeaderUserAgent :
            header := UserAgent;
         ELSE
            RETURN FALSE;
         END;

      ELSE
         CASE sysapiHeader OF
         // Response Headers
         | httpapi.HttpHeaderAcceptRanges :
            header := AcceptRanges;
         | httpapi.HttpHeaderAge :
            header := Age;
         | httpapi.HttpHeaderEtag :
            header := Etag;
         | httpapi.HttpHeaderLocation :
            header := Location;
         | httpapi.HttpHeaderProxyAuthenticate :
            header := ProxyAuthenticate;
         | httpapi.HttpHeaderRetryAfter :
            header := RetryAfter;
         | httpapi.HttpHeaderServer :
            header := Server;
         | httpapi.HttpHeaderSetCookie :
            header := SetCookie;
         | httpapi.HttpHeaderVary :
            header := Vary;
         | httpapi.HttpHeaderWwwAuthenticate :
            header := WwwAuthenticate;
         ELSE
            RETURN FALSE;
         END;
      
      END;
      RETURN TRUE;
   END FromSysApi;

//--------------------------------------------------------------------------------

   PRIVATE PROCEDURE ToSysApi( header : TKnownHeader; OUT sysapiHeader : httpapi.HTTP_HEADER_ID ) : BOOLEAN;
   BEGIN
      CASE header OF
      | CacheControl :
         sysapiHeader := httpapi.HttpHeaderCacheControl;
      | Connection :
         sysapiHeader := httpapi.HttpHeaderConnection;
      | Date :
         sysapiHeader := httpapi.HttpHeaderDate;
      | KeepAlive :
         sysapiHeader := httpapi.HttpHeaderKeepAlive;
      | Pragma :
         sysapiHeader := httpapi.HttpHeaderPragma;
      | Trailer :
         sysapiHeader := httpapi.HttpHeaderTrailer;
      | TransferEncoding :
         sysapiHeader := httpapi.HttpHeaderTransferEncoding;
      | Upgrade :
         sysapiHeader := httpapi.HttpHeaderUpgrade;
      | Via :
         sysapiHeader := httpapi.HttpHeaderVia;
      | Warning :
         sysapiHeader := httpapi.HttpHeaderWarning;

      | Allow :
         sysapiHeader := httpapi.HttpHeaderAllow;
      | ContentLength :
         sysapiHeader := httpapi.HttpHeaderContentLength;
      | ContentType :
         sysapiHeader := httpapi.HttpHeaderContentType;
      | ContentEncoding :
         sysapiHeader := httpapi.HttpHeaderContentEncoding;
      | ContentLanguage :
         sysapiHeader := httpapi.HttpHeaderContentLanguage;
      | ContentLocation :
         sysapiHeader := httpapi.HttpHeaderContentLocation;
      | ContentMd5 :
         sysapiHeader := httpapi.HttpHeaderContentMd5;
      | ContentRange :
         sysapiHeader := httpapi.HttpHeaderContentRange;
      | Expires :
         sysapiHeader := httpapi.HttpHeaderExpires;
      | LastModified :
         sysapiHeader := httpapi.HttpHeaderLastModified;
      
      // Request Headers
      | Accept :
         sysapiHeader := httpapi.HttpHeaderAccept;
      | AcceptCharset :
         sysapiHeader := httpapi.HttpHeaderAcceptCharset;
      | AcceptEncoding :
         sysapiHeader := httpapi.HttpHeaderAcceptEncoding;
      | AcceptLanguage :
         sysapiHeader := httpapi.HttpHeaderAcceptLanguage;
      | Authorization :
         sysapiHeader := httpapi.HttpHeaderAuthorization;
      | Cookie :
         sysapiHeader := httpapi.HttpHeaderCookie;
      | Expect :
         sysapiHeader := httpapi.HttpHeaderExpect;
      | From :
         sysapiHeader := httpapi.HttpHeaderFrom;
      | Host :
         sysapiHeader := httpapi.HttpHeaderHost;
      | IfMatch :
         sysapiHeader := httpapi.HttpHeaderIfMatch;

      | IfModifiedSince :
         sysapiHeader := httpapi.HttpHeaderIfModifiedSince;
      | IfNoneMatch :
         sysapiHeader := httpapi.HttpHeaderIfNoneMatch;
      | IfRange :
         sysapiHeader := httpapi.HttpHeaderIfRange;
      | IfUnmodifiedSince :
         sysapiHeader := httpapi.HttpHeaderIfUnmodifiedSince;
      | MaxForwards :
         sysapiHeader := httpapi.HttpHeaderMaxForwards;
      | ProxyAuthorization :
         sysapiHeader := httpapi.HttpHeaderProxyAuthorization;
      | Referer :
         sysapiHeader := httpapi.HttpHeaderReferer;
      | Range :
         sysapiHeader := httpapi.HttpHeaderRange;
      | Te :
         sysapiHeader := httpapi.HttpHeaderTe;
      | Translate :
         sysapiHeader := httpapi.HttpHeaderTranslate;

      | UserAgent :
         sysapiHeader := httpapi.HttpHeaderUserAgent;

      // Response Headers
      | AcceptRanges :
         sysapiHeader := httpapi.HttpHeaderAcceptRanges;
      | Age :
         sysapiHeader := httpapi.HttpHeaderAge;
      | Etag :
         sysapiHeader := httpapi.HttpHeaderEtag;
      | Location :
         sysapiHeader := httpapi.HttpHeaderLocation;
      | ProxyAuthenticate :
         sysapiHeader := httpapi.HttpHeaderProxyAuthenticate;
      | RetryAfter :
         sysapiHeader := httpapi.HttpHeaderRetryAfter;
      | Server :
         sysapiHeader := httpapi.HttpHeaderServer;
      | SetCookie :
         sysapiHeader := httpapi.HttpHeaderSetCookie;
      | Vary :
         sysapiHeader := httpapi.HttpHeaderVary;
      | WwwAuthenticate :
         sysapiHeader := httpapi.HttpHeaderWwwAuthenticate;
      
      ELSE
         RETURN FALSE;
      END;
      RETURN TRUE;
   END ToSysApi;

//--------------------------------------------------------------------------------

BEGIN
FINALLY
   KnownCache.Dispose(); // TODO loop over inner strings
   UnknownCache.Dispose(); // TODO loop over inner strings
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
   LOCAL VIRTUAL PROCEDURE OnHandle( Result : Sync.TAsyncResult; PoolHandle : threadpool.TPoolHandle; UserId : PTR );

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

   LOCAL VIRTUAL PROCEDURE OnHandle( Result : Sync.TAsyncResult; PoolHandle : threadpool.TPoolHandle; UserId : PTR );
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
      
      IF NOT threadpool.pool()^.WaitHandle( ADR( SELF ), 0, Sync.FORSAFETY, FALSE, FALSE, _HRequestSignal, OUT _HPoolHandle ) THEN
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
   HttpServer : POINTER TO CHttpSrv := NIL;

//--------------------------------------------------------------------------------

PROCEDURE srv() : TPHttpServer;
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