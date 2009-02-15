IMPLEMENTATION MODULE SrvHttpApi;

FROM Debug IMPORT
   Assertion;

FROM Storage IMPORT
   ALLOCATE, DEALLOCATE;

FROM Log IMPORT
   logger, dlcError, dlcWarning, dlcInfo;
   
IMPORT
   httpapi,
   HttpCommon,
   inetaddr,
   LanguagesO,
   SrvCommon,
   Storage,
   StorageO,
   Strings,
   StringsO,
   Sync,
   threadpool,
   windows,
   winerror;

(*================================================================================*)

TYPE
   TPHttpApiSrv = POINTER TO CHttpApiSrv;

(*--------------------------------------------------------------------------------*)

CLASS CHttpApiHeaders( SrvCommon.CHeaders );
   PRIVATE VAR
      HeaderBuffer : StorageO.CMemoryBuffer; // buffer to construct headers in httpapi format

   LOCAL PROCEDURE FromRequest( Request : httpapi.PHTTP_REQUEST );
   LOCAL PROCEDURE ToResponse( REF Response : httpapi.HTTP_RESPONSE );

   PRIVATE PROCEDURE FromSysApi( sysapiHeader : httpapi.HTTP_HEADER_ID; OUT header : HttpCommon.TKnownHeader ) : BOOLEAN;
   PRIVATE PROCEDURE ToSysApi( header : HttpCommon.TKnownHeader; OUT sysapiHeader : httpapi.HTTP_HEADER_ID ) : BOOLEAN;
END CHttpApiHeaders;

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
      _HRequestSignal : Sync.SIGNAL;
      _HPoolHandle : threadpool.TPoolHandle;
   
   PRIVATE PROCEDURE StartWaitingRequest() : Sync.TAsyncResult;
   
   INITIALLY CHttpApiSrv();
   FINALLY CHttpApiSrv();
END CHttpApiSrv;

(*================================================================================*)

CLASS IMPLEMENTATION CHttpApiHeaders;

//--------------------------------------------------------------------------------

   LOCAL PROCEDURE FromRequest( Request : httpapi.PHTTP_REQUEST );
   VAR
      header : httpapi.PHTTP_UNKNOWN_HEADER;
      Header : HttpCommon.TKnownHeader;
      i : CARDINAL;
      n : StringsO.CString;
      s : StringsO.CString;
   BEGIN
      RequestFlag := TRUE;

      // adopt known headers
      FOR i := 0 TO CARDINAL( httpapi.HttpHeaderRequestMaximum )-1 DO
         IF Request^.Headers.KnownHeaders[i].RawValueLength = 0 THEN
            CONTINUE;
         END;
         s.FromOAA( 0, OA( CARDINAL( Request^.Headers.KnownHeaders[i].RawValueLength )-1, Request^.Headers.KnownHeaders[i].pRawValue ));

         IF FromSysApi( httpapi.HTTP_HEADER_ID( i ), OUT Header ) THEN
            KnownCache.Add( CARDINAL( Header ), s );
         END;
      END; // FOR


      // adopt unknown headers
      header := Request^.Headers.pUnknownHeaders;
      FOR i := 0 TO INTEGER( Request^.Headers.UnknownHeaderCount )-1 DO
         n.FromOAA( 0, OA( CARDINAL( header^.NameLength )-1, header^.pName ));
         n.Lowerize();
         s.FromOAA( 0, OA( CARDINAL( header^.RawValueLength )-1, header^.pRawValue ));

         UnknownCache.Add( n, s );

         INC( header, SIZE( httpapi.HTTP_UNKNOWN_HEADER ));
      END; // FOR
   END FromRequest;
   
//--------------------------------------------------------------------------------

   LOCAL PROCEDURE ToResponse( REF Response : httpapi.HTTP_RESPONSE );
   VAR
      a : ADDRESS;
      i : INTEGER;
      id : httpapi.HTTP_HEADER_ID;
      l : CARDINAL;
      s : StringsO.TPString;
   BEGIN
      HeaderBuffer.Clear();
      
      FOR i := 0 TO INTEGER( httpapi.HttpHeaderResponseMaximum )-1 DO
         Response.Headers.KnownHeaders[i].RawValueLength := 0;
         Response.Headers.KnownHeaders[i].pRawValue := NIL;
      END;
      
      KnownCache.Reset();
      WHILE KnownCache.MoveNext() DO
         s := KnownCache.CurrentData;
         l := HeaderBuffer.Length;
         LanguagesO.ToMB( s^, 0, TRUE, REF HeaderBuffer );
         HeaderBuffer.AppendByte( 0 );

         ToSysApi( HttpCommon.TKnownHeader( KnownCache.Current ), OUT id );
         Response.Headers.KnownHeaders[CARDINAL( id )].RawValueLength := CARD16( HeaderBuffer.Length - l - 1 ); // trailing byte
      END; // WHILE
      
      a := HeaderBuffer.Data;
      FOR i := 0 TO INTEGER( httpapi.HttpHeaderResponseMaximum )-1 DO
         l := CARDINAL( Response.Headers.KnownHeaders[i].RawValueLength );
         IF l > 0 THEN
            Response.Headers.KnownHeaders[i].pRawValue := a;
            INC( a, l + 1 ); // trailing byte
         END;
      END;

      Response.Headers.UnknownHeaderCount := 0;
      Response.Headers.pUnknownHeaders := NIL;

      Response.Headers.TrailerCount := 0;
      Response.Headers.pTrailers := NIL;
   END ToResponse;

//--------------------------------------------------------------------------------

   PRIVATE PROCEDURE FromSysApi( sysapiHeader : httpapi.HTTP_HEADER_ID; OUT header : HttpCommon.TKnownHeader ) : BOOLEAN;
   VAR
      found : BOOLEAN := TRUE;
   BEGIN
      CASE sysapiHeader OF
      | httpapi.HttpHeaderCacheControl :
         header := HttpCommon.CacheControl;
      | httpapi.HttpHeaderConnection :
         header := HttpCommon.Connection;
      | httpapi.HttpHeaderDate :
         header := HttpCommon.Date;
      | httpapi.HttpHeaderKeepAlive :
         header := HttpCommon.KeepAlive;
      | httpapi.HttpHeaderPragma :
         header := HttpCommon.Pragma;
      | httpapi.HttpHeaderTrailer :
         header := HttpCommon.Trailer;
      | httpapi.HttpHeaderTransferEncoding :
         header := HttpCommon.TransferEncoding;
      | httpapi.HttpHeaderUpgrade :
         header := HttpCommon.Upgrade;
      | httpapi.HttpHeaderVia :
         header := HttpCommon.Via;
      | httpapi.HttpHeaderWarning :
         header := HttpCommon.Warning;

      | httpapi.HttpHeaderAllow :
         header := HttpCommon.Allow;
      | httpapi.HttpHeaderContentLength :
         header := HttpCommon.ContentLength;
      | httpapi.HttpHeaderContentType :
         header := HttpCommon.ContentType;
      | httpapi.HttpHeaderContentEncoding :
         header := HttpCommon.ContentEncoding;
      | httpapi.HttpHeaderContentLanguage :
         header := HttpCommon.ContentLanguage;
      | httpapi.HttpHeaderContentLocation :
         header := HttpCommon.ContentLocation;
      | httpapi.HttpHeaderContentMd5 :
         header := HttpCommon.ContentMd5;
      | httpapi.HttpHeaderContentRange :
         header := HttpCommon.ContentRange;
      | httpapi.HttpHeaderExpires :
         header := HttpCommon.Expires;
      | httpapi.HttpHeaderLastModified :
         header := HttpCommon.LastModified;
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
            header := HttpCommon.Accept;
         | httpapi.HttpHeaderAcceptCharset :
            header := HttpCommon.AcceptCharset;
         | httpapi.HttpHeaderAcceptEncoding :
            header := HttpCommon.AcceptEncoding;
         | httpapi.HttpHeaderAcceptLanguage :
            header := HttpCommon.AcceptLanguage;
         | httpapi.HttpHeaderAuthorization :
            header := HttpCommon.Authorization;
         | httpapi.HttpHeaderCookie :
            header := HttpCommon.Cookie;
         | httpapi.HttpHeaderExpect :
            header := HttpCommon.Expect;
         | httpapi.HttpHeaderFrom :
            header := HttpCommon.From;
         | httpapi.HttpHeaderHost :
            header := HttpCommon.Host;
         | httpapi.HttpHeaderIfMatch :
            header := HttpCommon.IfMatch;

         | httpapi.HttpHeaderIfModifiedSince :
            header := HttpCommon.IfModifiedSince;
         | httpapi.HttpHeaderIfNoneMatch :
            header := HttpCommon.IfNoneMatch;
         | httpapi.HttpHeaderIfRange :
            header := HttpCommon.IfRange;
         | httpapi.HttpHeaderIfUnmodifiedSince :
            header := HttpCommon.IfUnmodifiedSince;
         | httpapi.HttpHeaderMaxForwards :
            header := HttpCommon.MaxForwards;
         | httpapi.HttpHeaderProxyAuthorization :
            header := HttpCommon.ProxyAuthorization;
         | httpapi.HttpHeaderReferer :
            header := HttpCommon.Referer;
         | httpapi.HttpHeaderRange :
            header := HttpCommon.Range;
         | httpapi.HttpHeaderTe :
            header := HttpCommon.Te;
         | httpapi.HttpHeaderTranslate :
            header := HttpCommon.Translate;

         | httpapi.HttpHeaderUserAgent :
            header := HttpCommon.UserAgent;
         ELSE
            RETURN FALSE;
         END;

      ELSE
         CASE sysapiHeader OF
         // Response Headers
         | httpapi.HttpHeaderAcceptRanges :
            header := HttpCommon.AcceptRanges;
         | httpapi.HttpHeaderAge :
            header := HttpCommon.Age;
         | httpapi.HttpHeaderEtag :
            header := HttpCommon.Etag;
         | httpapi.HttpHeaderLocation :
            header := HttpCommon.Location;
         | httpapi.HttpHeaderProxyAuthenticate :
            header := HttpCommon.ProxyAuthenticate;
         | httpapi.HttpHeaderRetryAfter :
            header := HttpCommon.RetryAfter;
         | httpapi.HttpHeaderServer :
            header := HttpCommon.Server;
         | httpapi.HttpHeaderSetCookie :
            header := HttpCommon.SetCookie;
         | httpapi.HttpHeaderVary :
            header := HttpCommon.Vary;
         | httpapi.HttpHeaderWwwAuthenticate :
            header := HttpCommon.WwwAuthenticate;
         ELSE
            RETURN FALSE;
         END;
      
      END;
      RETURN TRUE;
   END FromSysApi;

//--------------------------------------------------------------------------------

   PRIVATE PROCEDURE ToSysApi( header : HttpCommon.TKnownHeader; OUT sysapiHeader : httpapi.HTTP_HEADER_ID ) : BOOLEAN;
   BEGIN
      CASE header OF
      | HttpCommon.CacheControl :
         sysapiHeader := httpapi.HttpHeaderCacheControl;
      | HttpCommon.Connection :
         sysapiHeader := httpapi.HttpHeaderConnection;
      | HttpCommon.Date :
         sysapiHeader := httpapi.HttpHeaderDate;
      | HttpCommon.KeepAlive :
         sysapiHeader := httpapi.HttpHeaderKeepAlive;
      | HttpCommon.Pragma :
         sysapiHeader := httpapi.HttpHeaderPragma;
      | HttpCommon.Trailer :
         sysapiHeader := httpapi.HttpHeaderTrailer;
      | HttpCommon.TransferEncoding :
         sysapiHeader := httpapi.HttpHeaderTransferEncoding;
      | HttpCommon.Upgrade :
         sysapiHeader := httpapi.HttpHeaderUpgrade;
      | HttpCommon.Via :
         sysapiHeader := httpapi.HttpHeaderVia;
      | HttpCommon.Warning :
         sysapiHeader := httpapi.HttpHeaderWarning;

      | HttpCommon.Allow :
         sysapiHeader := httpapi.HttpHeaderAllow;
      | HttpCommon.ContentLength :
         sysapiHeader := httpapi.HttpHeaderContentLength;
      | HttpCommon.ContentType :
         sysapiHeader := httpapi.HttpHeaderContentType;
      | HttpCommon.ContentEncoding :
         sysapiHeader := httpapi.HttpHeaderContentEncoding;
      | HttpCommon.ContentLanguage :
         sysapiHeader := httpapi.HttpHeaderContentLanguage;
      | HttpCommon.ContentLocation :
         sysapiHeader := httpapi.HttpHeaderContentLocation;
      | HttpCommon.ContentMd5 :
         sysapiHeader := httpapi.HttpHeaderContentMd5;
      | HttpCommon.ContentRange :
         sysapiHeader := httpapi.HttpHeaderContentRange;
      | HttpCommon.Expires :
         sysapiHeader := httpapi.HttpHeaderExpires;
      | HttpCommon.LastModified :
         sysapiHeader := httpapi.HttpHeaderLastModified;
      
      // Request Headers
      | HttpCommon.Accept :
         sysapiHeader := httpapi.HttpHeaderAccept;
      | HttpCommon.AcceptCharset :
         sysapiHeader := httpapi.HttpHeaderAcceptCharset;
      | HttpCommon.AcceptEncoding :
         sysapiHeader := httpapi.HttpHeaderAcceptEncoding;
      | HttpCommon.AcceptLanguage :
         sysapiHeader := httpapi.HttpHeaderAcceptLanguage;
      | HttpCommon.Authorization :
         sysapiHeader := httpapi.HttpHeaderAuthorization;
      | HttpCommon.Cookie :
         sysapiHeader := httpapi.HttpHeaderCookie;
      | HttpCommon.Expect :
         sysapiHeader := httpapi.HttpHeaderExpect;
      | HttpCommon.From :
         sysapiHeader := httpapi.HttpHeaderFrom;
      | HttpCommon.Host :
         sysapiHeader := httpapi.HttpHeaderHost;
      | HttpCommon.IfMatch :
         sysapiHeader := httpapi.HttpHeaderIfMatch;

      | HttpCommon.IfModifiedSince :
         sysapiHeader := httpapi.HttpHeaderIfModifiedSince;
      | HttpCommon.IfNoneMatch :
         sysapiHeader := httpapi.HttpHeaderIfNoneMatch;
      | HttpCommon.IfRange :
         sysapiHeader := httpapi.HttpHeaderIfRange;
      | HttpCommon.IfUnmodifiedSince :
         sysapiHeader := httpapi.HttpHeaderIfUnmodifiedSince;
      | HttpCommon.MaxForwards :
         sysapiHeader := httpapi.HttpHeaderMaxForwards;
      | HttpCommon.ProxyAuthorization :
         sysapiHeader := httpapi.HttpHeaderProxyAuthorization;
      | HttpCommon.Referer :
         sysapiHeader := httpapi.HttpHeaderReferer;
      | HttpCommon.Range :
         sysapiHeader := httpapi.HttpHeaderRange;
      | HttpCommon.Te :
         sysapiHeader := httpapi.HttpHeaderTe;
      | HttpCommon.Translate :
         sysapiHeader := httpapi.HttpHeaderTranslate;

      | HttpCommon.UserAgent :
         sysapiHeader := httpapi.HttpHeaderUserAgent;

      // Response Headers
      | HttpCommon.AcceptRanges :
         sysapiHeader := httpapi.HttpHeaderAcceptRanges;
      | HttpCommon.Age :
         sysapiHeader := httpapi.HttpHeaderAge;
      | HttpCommon.Etag :
         sysapiHeader := httpapi.HttpHeaderEtag;
      | HttpCommon.Location :
         sysapiHeader := httpapi.HttpHeaderLocation;
      | HttpCommon.ProxyAuthenticate :
         sysapiHeader := httpapi.HttpHeaderProxyAuthenticate;
      | HttpCommon.RetryAfter :
         sysapiHeader := httpapi.HttpHeaderRetryAfter;
      | HttpCommon.Server :
         sysapiHeader := httpapi.HttpHeaderServer;
      | HttpCommon.SetCookie :
         sysapiHeader := httpapi.HttpHeaderSetCookie;
      | HttpCommon.Vary :
         sysapiHeader := httpapi.HttpHeaderVary;
      | HttpCommon.WwwAuthenticate :
         sysapiHeader := httpapi.HttpHeaderWwwAuthenticate;
      
      ELSE
         RETURN FALSE;
      END;
      RETURN TRUE;
   END ToSysApi;

//--------------------------------------------------------------------------------

END CHttpApiHeaders;

//================================================================================

TYPE
   TPHttpApiStream = POINTER TO CHttpApiStream;

CLASS CHttpApiStream( SrvCommon.ASrvStream );

   // ASrvStream
   PUBLIC VIRTUAL READONLY PROPERTY
      RequestVersion : HttpCommon.THttpVersion;
      RequestVerb : HttpCommon.TVerb;
      FullURI : StringsO.CString;
      AbsoluteURI : StringsO.CString;
      URIData : StringsO.CString; // query string, part after ? in URI
      RequestURI : StringsO.CString;
      RequestHeaders : HttpCommon.TPHttpHeaders;
      ResponseHeaders : HttpCommon.TPHttpHeaders;
      LocalAddress : inetaddr.INETADDR;
      RemoteAddress : inetaddr.INETADDR;
   PUBLIC VIRTUAL PROPERTY
      StatusCode : HttpCommon.THttpResponse;
   
   // all methods can return arCompleted, arNoData, arAbort, arTimeout
   INTERNAL VIRTUAL PROCEDURE ReceiveHeaders() : Sync.TAsyncResult;
   INTERNAL VIRTUAL PROCEDURE ReceiveData( REF Data : StorageO.AMemoryBuffer ) : Sync.TAsyncResult;
   INTERNAL VIRTUAL PROCEDURE SendHeaders() : Sync.TAsyncResult;
   INTERNAL VIRTUAL PROCEDURE SendData( CONST Data : StorageO.AMemoryBuffer ) : Sync.TAsyncResult;
   INTERNAL VIRTUAL PROCEDURE EndResponse() : Sync.TAsyncResult;
   
   // SELF
   LOCAL PROCEDURE Init( HttpQueue : Sync.WAITABLE; CONST RootPath : StringsO.IString );

   LOCAL READONLY PROPERTY
      Request : httpapi.PHTTP_REQUEST;
      RequestSpace : CARDINAL;
   
   PRIVATE VAR
      _HttpQueue : Sync.WAITABLE;
      _RootPath : StringsO.CString;
      _Request : StorageO.CMemoryBuffer;
      _Response : httpapi.HTTP_RESPONSE;
      _RequestHeaders : CHttpApiHeaders;
      _ResponseHeaders : CHttpApiHeaders;

END CHttpApiStream;

(*================================================================================*)

CLASS IMPLEMENTATION CHttpApiStream;

(*--------------------------------------------------------------------------------*)

   PUBLIC VIRTUAL PROPERTY RequestVersion GET : HttpCommon.THttpVersion;
   BEGIN
      IF Request^.Version.MajorVersion = 0 THEN
         RETURN HttpCommon.httpver09;
      ELSIF Request^.Version.MinorVersion = 0 THEN
         RETURN HttpCommon.httpver10;
      ELSE
         RETURN HttpCommon.httpver11;
      END;
   END RequestVersion;

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

   PUBLIC VIRTUAL PROPERTY FullURI GET : StringsO.CString;
   VAR
      s : StringsO.CString;
   BEGIN
      s.FromOA( OA( CARDINAL(( Request^.CookedUrl.FullUrlLength-Request^.CookedUrl.QueryStringLength ) >> 1 )-1, Request^.CookedUrl.pFullUrl ));
      RETURN s;
   END FullURI;

(*--------------------------------------------------------------------------------*)

   PUBLIC VIRTUAL PROPERTY AbsoluteURI GET : StringsO.CString;
   VAR
      s : StringsO.CString;
   BEGIN
      s.FromOA( OA( CARDINAL( Request^.CookedUrl.AbsPathLength >> 1 )-1, Request^.CookedUrl.pAbsPath ));
      RETURN s;
   END AbsoluteURI;

(*--------------------------------------------------------------------------------*)

   PUBLIC VIRTUAL PROPERTY URIData GET : StringsO.CString; // query string, part after ? in URI
   VAR
      l : CARDINAL;
      s : StringsO.CString;
   BEGIN
      l := CARDINAL( Request^.CookedUrl.QueryStringLength );
      IF l > 1 THEN
         s.FromOA( OA( CARDINAL( Request^.CookedUrl.QueryStringLength >> 1 )-2, INC( Request^.CookedUrl.pQueryString, SIZE( WCHAR ))));
      END;
      RETURN s;
   END URIData;

(*--------------------------------------------------------------------------------*)

   PUBLIC VIRTUAL PROPERTY RequestURI GET : StringsO.CString;
   VAR
      s : StringsO.CString;
   BEGIN
      s := AbsoluteURI;
      s.Remove( 0, _RootPath.Length );
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

   LOCAL PROCEDURE Init( HttpQueue : Sync.WAITABLE; CONST RootPath : StringsO.IString );
   BEGIN
      _HttpQueue := HttpQueue;
      _RootPath.Assign( RootPath );
   END Init;

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
      RESPONSE_301 = C"Moved Permanently";
      RESPONSE_302 = C"Moved Temporarily";
      RESPONSE_303 = C"See Other";
      RESPONSE_404 = C"Not Found";
      RESPONSE_409 = C"Conflict";
      RESPONSE_500 = C"Internal Server Error";
      RESPONSE_501 = C"Not Implemented";
   BEGIN
      CASE Value OF
      | HttpCommon.httpres_200 :
         _Response.pReason := ADR( RESPONSE_200 );
         _Response.ReasonLength := SIZE( RESPONSE_200 )-1;
      | HttpCommon.httpres_301 :
         _Response.pReason := ADR( RESPONSE_301 );
         _Response.ReasonLength := SIZE( RESPONSE_301 )-1;
      | HttpCommon.httpres_302 :
         _Response.pReason := ADR( RESPONSE_302 );
         _Response.ReasonLength := SIZE( RESPONSE_302 )-1;
      | HttpCommon.httpres_303 :
         _Response.pReason := ADR( RESPONSE_303 );
         _Response.ReasonLength := SIZE( RESPONSE_303 )-1;
      | HttpCommon.httpres_404 :
         _Response.pReason := ADR( RESPONSE_404 );
         _Response.ReasonLength := SIZE( RESPONSE_404 )-1;
      | HttpCommon.httpres_409 :
         _Response.pReason := ADR( RESPONSE_409 );
         _Response.ReasonLength := SIZE( RESPONSE_409 )-1;
      | HttpCommon.httpres_500 :
         _Response.pReason := ADR( RESPONSE_500 );
         _Response.ReasonLength := SIZE( RESPONSE_500 )-1;
      | HttpCommon.httpres_501 :
         _Response.pReason := ADR( RESPONSE_501 );
         _Response.ReasonLength := SIZE( RESPONSE_501 )-1;
      ELSE
         ASSERT( FALSE );
         Value := HttpCommon.httpres_500;
         _Response.pReason := ADR( RESPONSE_500 );
         _Response.ReasonLength := SIZE( RESPONSE_500 )-1;
      END;
      _Response.StatusCode := CARD16( Value );
   END StatusCode;

(*--------------------------------------------------------------------------------*)

   INTERNAL VIRTUAL PROCEDURE ReceiveHeaders() : Sync.TAsyncResult;
   BEGIN
      _RequestHeaders.FromRequest( Request ); // copy httpapi data to headers
      RETURN Sync.arCompleted;
   END ReceiveHeaders;

(*--------------------------------------------------------------------------------*)

   INTERNAL VIRTUAL PROCEDURE ReceiveData( REF Data : StorageO.AMemoryBuffer ) : Sync.TAsyncResult;
   VAR
      error : CARDINAL;
      L : CARDINAL := 0;
   BEGIN
      Data.Length := 0;
      error := httpapi.HttpReceiveRequestEntityBody( _HttpQueue, Request^.RequestId, 0, Data.Data, Data.Size, ADR( L ), NIL );
      IF L < Data.Size THEN
         IF ( error <> winerror.ERROR_SUCCESS ) AND ( error <> winerror.ERROR_HANDLE_EOF ) THEN
            RETURN Sync.arAborted;
         ELSIF L = 0 THEN
            RETURN Sync.arNoData;
         ELSE
            Data.Length := L;
            RETURN Sync.arCompleted;
         END;
      ELSIF ( error = winerror.ERROR_SUCCESS ) OR ( error = winerror.ERROR_MORE_DATA ) THEN
         Data.Length := L;
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

      error := httpapi.HttpSendHttpResponse( _HttpQueue, Request^.RequestId, httpapi.HTTP_SEND_RESPONSE_FLAG_MORE_DATA, ADR( _Response ), NIL, ADR( L ), NIL, 0, NIL, NIL );
      IF error = winerror.ERROR_SUCCESS THEN
         RETURN Sync.arCompleted;
      ELSE
         RETURN Sync.arAborted;
      END;
   END SendHeaders;

(*--------------------------------------------------------------------------------*)

   INTERNAL VIRTUAL PROCEDURE SendData( CONST Data : StorageO.AMemoryBuffer ) : Sync.TAsyncResult;
   VAR
      Chunk : httpapi.HTTP_DATA_CHUNK;
      error : CARDINAL;
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

//================================================================================

CLASS IMPLEMENTATION CHttpApiSrv;

//--------------------------------------------------------------------------------

   LOCAL VIRTUAL PROCEDURE OnHandle( Result : Sync.TAsyncResult; PoolHandle : threadpool.TPoolHandle; UserId : PTR );
   VAR
      EOF : BOOLEAN := FALSE;
      received : CARDINAL;
      s1 : ARRAY [0..255] OF WCHAR;
      s2 : ARRAY [0..255] OF WCHAR;
   BEGIN
      IF Result <> Sync.arCompleted THEN
         RETURN;

      ELSIF PreparedStream <> NIL THEN // we are waiting now
         IF NOT logger()^.Filtered( dlcInfo ) THEN
            PreparedStream^.AbsoluteURI.ToOA( OUT s1 );
            PreparedStream^.URIData.ToOA( OUT s2 );
            IF s2[0] = 0W THEN
               logger()^.LogSS( dlcInfo, L"HTTP", L"Request: ", s1 );
            ELSE
               logger()^.LogSSSS( dlcInfo, L"HTTP", L"Request: ", s1, L"?", s2 );
            END;
         END;

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
      
      IF NOT threadpool.pool()^.WaitHandle( ADR( SELF ), 0, Sync.FOREVER, FALSE, FALSE, _HRequestSignal.RawHandle, OUT _HPoolHandle ) THEN
         RETURN Sync.arCannotStart;
      END;
      // force switching to another thread (simulate request arriving), waiting will be starte from the another thread
      _HRequestSignal.Signal();
      
      _Running := TRUE;
      RETURN Sync.arCompleted;
   END Start;

//--------------------------------------------------------------------------------

   PUBLIC VIRTUAL PROCEDURE Stop();
   BEGIN
      IF NOT _Running THEN
         RETURN;
      END;
      _Running := FALSE;
      
      IF _HPoolHandle <> NIL THEN
         threadpool.pool()^.Abort( REF _HPoolHandle );
      END;
   END Stop;
   
//--------------------------------------------------------------------------------

   INTERNAL VIRTUAL PROCEDURE GetNewStream() : SrvCommon.TPSrvStream;
   VAR
      stream : TPHttpApiStream;
   BEGIN
      NEW( stream );
      RETURN stream;
   END GetNewStream;

//--------------------------------------------------------------------------------

   PRIVATE PROCEDURE StartWaitingRequest() : Sync.TAsyncResult;
   VAR
      Error : CARDINAL;
      Stream : TPHttpApiStream;
   BEGIN
      ASSERT( _HttpQueue <> NIL );
      Storage.Zero( ADR( _HttpOverlapped ), SIZE( _HttpOverlapped ));
      _HttpOverlapped.hEvent := _HRequestSignal.RawHandle;

      LOOP
         PrepareStream();
         Stream := TPHttpApiStream( PreparedStream );
         Stream^.Init( _HttpQueue, RootPath );
            
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
      _HPoolHandle := NIL;
      _HRequestSignal.Init( Sync.stEventAutoreset, L"", FALSE );

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
      Stop();
   
      IF _HttpQueue <> NIL THEN
         windows.CloseHandle( _HttpQueue );
         _HttpQueue := NIL;
      END;
      
      httpapi.HttpTerminate( httpapi.HTTP_INITIALIZE_SERVER, NIL );
      
      _HRequestSignal.Dispose();
   END CHttpApiSrv;

//--------------------------------------------------------------------------------

END CHttpApiSrv;

//================================================================================

VAR
   HttpServer : TPHttpApiSrv := NIL;

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
      HttpServer^.Release();
      HttpServer := NIL;
   END;
END Cleanup;

//================================================================================

END SrvHttpApi.