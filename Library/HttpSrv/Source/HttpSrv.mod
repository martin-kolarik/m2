IMPLEMENTATION MODULE HttpSrv;

FROM Log IMPORT
   logger, dlcError, dlcWarning, dlcInfo;
   
IMPORT
   cphcommon,
   digest,
   httptools,
   LanguagesO,
   inetaddr,
   lists,
   netsocket,
   rijndael,
   sha256,
   Storage,
   StorageO,
   Strings,
   Time,
   TimeoutableTwoPtrMap,
   threadpool,
   windows,
   winerror;

//================================================================================

TYPE
   TPHeaders = POINTER TO CHeaders;

//================================================================================

CLASS CHeaders IMPLEMENTS IHttpHeaders;

   // IHttpHeaders
   PUBLIC VIRTUAL PROCEDURE Contains( Header : TKnownHeader ) : BOOLEAN;
   PUBLIC VIRTUAL PROCEDURE Get( Header : TKnownHeader; OUT Value : StringsO.IString ) : BOOLEAN;
   PUBLIC VIRTUAL PROCEDURE GetOA( Header : TKnownHeader; OUT Value : ARRAY OF WCHAR ) : BOOLEAN;
   PUBLIC VIRTUAL PROCEDURE Add( Header : TKnownHeader; CONST Value : StringsO.IString );
   PUBLIC VIRTUAL PROCEDURE AddOA( Header : TKnownHeader; CONST Value : ARRAY OF WCHAR );
   
   PUBLIC VIRTUAL PROCEDURE Enumerate( Known, Uknown : BOOLEAN; REF ES : PTR; OUT Name, Value : StringsO.IString ) : BOOLEAN;

   PUBLIC VIRTUAL PROCEDURE ContainsUnknown( CONST Name : ARRAY OF WCHAR ) : BOOLEAN;
   PUBLIC VIRTUAL PROCEDURE GetUnknown( CONST Name : ARRAY OF WCHAR; OUT Value : StringsO.IString ) : BOOLEAN;
   PUBLIC VIRTUAL PROCEDURE AddUnknown( CONST Name : ARRAY OF WCHAR; CONST Value : StringsO.IString );

   // SELF
   PRIVATE VAR
      RequestFlag : BOOLEAN := FALSE; // by default headers are output
      Request : httpapi.PHTTP_REQUEST := NIL;
      KnownCache : maps.CCardinalMap; // cache for known headers
      UnknownCache : maps.CStringMap; // cache for unknown headers
      HeaderBuffer : StorageO.CMemoryBuffer; // buffer to construct headers in httpapi format
      
   LOCAL PROCEDURE FromRequest( Request : httpapi.PHTTP_REQUEST );
   LOCAL PROCEDURE ToResponse( REF Response : httpapi.HTTP_RESPONSE );
   
   PRIVATE PROCEDURE FromSysApi( sysapiHeader : httpapi.HTTP_HEADER_ID; OUT header : TKnownHeader ) : BOOLEAN;
   PRIVATE PROCEDURE ToSysApi( header : TKnownHeader; OUT sysapiHeader : httpapi.HTTP_HEADER_ID ) : BOOLEAN;
   
   PUBLIC PROCEDURE Dispose();
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

      Value.Assign( s^ );
      RETURN TRUE;
   END Get;

//--------------------------------------------------------------------------------

   PUBLIC VIRTUAL PROCEDURE GetOA( Header : TKnownHeader; OUT Value : ARRAY OF WCHAR ) : BOOLEAN;
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
         s^.Assign( Value );
         KnownCache.Add( CARDINAL( Header ), s );
      END;
   END Add;
   
//--------------------------------------------------------------------------------

   PUBLIC VIRTUAL PROCEDURE AddOA( Header : TKnownHeader; CONST Value : ARRAY OF WCHAR );
   VAR
      s : StringsO.CString;
   BEGIN
      s.FromOA( Value );
      Add( Header, s );
   END AddOA;

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
         Value.Assign( s^ );
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

         Value.Assign( s^ );
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
         s^.Assign( Value );
      ELSE
         s := NEW( StringsO.CString );
         s^.Assign( Value );
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

         ToSysApi( TKnownHeader( KnownCache.Current ), OUT id );
         Response.Headers.KnownHeaders[CARDINAL( id )].RawValueLength := CARD16( HeaderBuffer.Length - l );
      END; // WHILE
      
      a := HeaderBuffer.Data;
      FOR i := 0 TO INTEGER( httpapi.HttpHeaderResponseMaximum )-1 DO
         l := CARDINAL( Response.Headers.KnownHeaders[i].RawValueLength );
         IF l > 0 THEN
            Response.Headers.KnownHeaders[i].pRawValue := a;
            INC( a, l )
         END;
      END;

      Response.Headers.UnknownHeaderCount := 0;
      Response.Headers.pUnknownHeaders := NIL;

      Response.Headers.TrailerCount := 0;
      Response.Headers.pTrailers := NIL;
   END ToResponse;

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

   PUBLIC PROCEDURE Dispose();
   BEGIN
      KnownCache.Dispose(); // TODO loop over inner strings
      UnknownCache.Dispose(); // TODO loop over inner strings
      HeaderBuffer.Dispose();
   END Dispose;

//--------------------------------------------------------------------------------

BEGIN
FINALLY
   Dispose();
END CHeaders;

//================================================================================

CLASS CSession IMPLEMENTS ISession;

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

//--------------------------------------------------------------------------------

CLASS IMPLEMENTATION CSession;

//--------------------------------------------------------------------------------

   PUBLIC VIRTUAL PROPERTY Data GET : maps.TPStringMap; // the same as Container["session"]
   BEGIN
      RETURN _Data;
   END Data;

//--------------------------------------------------------------------------------

   PUBLIC VIRTUAL PROPERTY SID GET : StringsO.CString;
   BEGIN
      RETURN _SID;
   END SID;

//--------------------------------------------------------------------------------

   PUBLIC VIRTUAL PROCEDURE Invalidate();
   BEGIN
      _Valid := FALSE;
      _Created := 0; // force sweep
      _SID.Clear();
   END Invalidate;
   
//--------------------------------------------------------------------------------

   PUBLIC PROPERTY Valid GET : BOOLEAN;
   BEGIN
      RETURN _Valid;
   END Valid;

//--------------------------------------------------------------------------------

   PUBLIC PROCEDURE Init( CONST sid : StringsO.IString; CONST rootPath : StringsO.IString );
   BEGIN
      _SID.Assign( sid );
      RootPath.Assign( rootPath );
   END Init;

//--------------------------------------------------------------------------------

   PUBLIC PROCEDURE SetData( data : maps.TPStringMap );
   BEGIN
      _Data := data;
   END SetData;

//--------------------------------------------------------------------------------

BEGIN
   _Created := Time.GetCurrentJD();
END CSession;

//================================================================================

CLASS IMPLEMENTATION CContainer;

//--------------------------------------------------------------------------------

   PUBLIC PROCEDURE Clear();
   BEGIN
      Models.Dispose();
   END Clear;

//--------------------------------------------------------------------------------

   PUBLIC PROCEDURE AddModel( CONST Name : ARRAY OF WCHAR; REF Model : maps.CStringStringMap );
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

   PUBLIC PROCEDURE GetModelOA( CONST Name : ARRAY OF WCHAR; OUT PModel : maps.TPStringStringMap ) : BOOLEAN;
   BEGIN
      RETURN Models.GetOA( Name, OUT PModel );
   END GetModelOA;

//--------------------------------------------------------------------------------

   PUBLIC PROCEDURE GetModel( CONST Name : StringsO.CString; OUT PModel : maps.TPStringStringMap ) : BOOLEAN;
   BEGIN
      RETURN Models.Get( Name, OUT PModel );
   END GetModel;

//--------------------------------------------------------------------------------

BEGIN FINALLY
   Clear();
END CContainer;

//================================================================================

CONST
  RESPONSE_100 = C"Continue";
  RESPONSE_101 = C"Switching Protocols";
  // success
  RESPONSE_200 = C"OK";
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
  RESPONSE_404 = C"Not Found";
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
  RESPONSE_500 = C"Internal Server Error";
  RESPONSE_501 = C"Not Implemented";
  RESPONSE_502 = C"Bad Gateway";
  RESPONSE_503 = C"Service Unavailable";
  RESPONSE_504 = C"Gateway Timeout";
  RESPONSE_505 = C"HTTP Version Not Supported";

//--------------------------------------------------------------------------------

ABSTRACT CLASS RequestWorker( threadpool.APoolWorker );

   // APoolWorker
   LOCAL VIRTUAL PROCEDURE Run();

   // SELF
   PRIVATE VAR
      httpHandle : Sync.WAITABLE := NIL;
      request : httpapi.PHTTP_REQUEST := NIL;
      requestHeaders : TPHeaders := NIL;
      responseHeaders : CHeaders;
      session : POINTER TO CSession := NIL;
      controller : TPController := NIL;

   LOCAL PROCEDURE Init( httpHandle : Sync.WAITABLE; request : httpapi.PHTTP_REQUEST; headers : TPHeaders; session : POINTER TO CSession; controller : TPController ); // headers are cleared by SELF!!
   INTERNAL ABSTRACT PROCEDURE HandleRequest( httpHandle : Sync.WAITABLE; request : httpapi.PHTTP_REQUEST; headers : TPHeaders; session : POINTER TO CSession; controller : TPController );
   
   // helpers
   INTERNAL PROCEDURE PrepareResponse( status : CARDINAL; OUT response : httpapi.HTTP_RESPONSE );

   PRIVATE PROCEDURE FillStatus( REF response : httpapi.HTTP_RESPONSE; status : CARDINAL );
   PRIVATE PROCEDURE AddDefaultHeaders( REF headers : CHeaders );
END RequestWorker;      

//--------------------------------------------------------------------------------

TYPE
   TPSimpleResponseWorker = POINTER TO SimpleResponseWorker;

CLASS SimpleResponseWorker( RequestWorker );
   PRIVATE VAR
      status : CARDINAL := 200;
   LOCAL PROCEDURE Init( httpHandle : Sync.WAITABLE; request : httpapi.PHTTP_REQUEST; headers : TPHeaders; status : CARDINAL );
   INTERNAL VIRTUAL PROCEDURE HandleRequest( httpHandle : Sync.WAITABLE; request : httpapi.PHTTP_REQUEST; headers : TPHeaders; session : POINTER TO CSession; controller : TPController );
END SimpleResponseWorker;

//--------------------------------------------------------------------------------

TYPE
   TPMVCWorker = POINTER TO MVCWorker;

CLASS MVCWorker( RequestWorker );
   INTERNAL VIRTUAL PROCEDURE HandleRequest( httpHandle : Sync.WAITABLE; request : httpapi.PHTTP_REQUEST; headers : TPHeaders; session : POINTER TO CSession; controller : TPController );
END MVCWorker;

//================================================================================

CLASS IMPLEMENTATION RequestWorker;
   
//--------------------------------------------------------------------------------

   LOCAL VIRTUAL PROCEDURE Run();
   BEGIN
      HandleRequest( httpHandle, request, requestHeaders, session, controller );            
   END Run;

//--------------------------------------------------------------------------------

   LOCAL PROCEDURE Init( httpHandle : Sync.WAITABLE; request : httpapi.PHTTP_REQUEST; headers : TPHeaders; session : POINTER TO CSession; controller : TPController );
   BEGIN
      SELF.httpHandle := httpHandle;
      SELF.request := request;
      SELF.requestHeaders := headers;
      SELF.session := session;
      SELF.controller := controller;
   END Init;

//--------------------------------------------------------------------------------

   INTERNAL PROCEDURE PrepareResponse( status : CARDINAL; OUT response : httpapi.HTTP_RESPONSE );
   VAR
      s : StringsO.CString;
   BEGIN
      response.Flags := 0;
      response.Version.MajorVersion := 1;
      response.Version.MinorVersion := 1;
      response.EntityChunkCount := 0;
      response.pEntityChunks := NIL;
      
      // status
      FillStatus( REF response, status );
      
      // headers
      AddDefaultHeaders( REF responseHeaders );
      IF ( session <> NIL ) AND session^.New THEN
         responseHeaders.Add( SetCookie, httptools.FormatSIDCookie( session^.SID, 0, session^.RootPath, s ));
      END;
      responseHeaders.ToResponse( REF response );
   END PrepareResponse;

//--------------------------------------------------------------------------------

   PRIVATE PROCEDURE FillStatus( REF response : httpapi.HTTP_RESPONSE; status : CARDINAL );
   BEGIN
      response.StatusCode := CARD16( status );
      CASE status OF
      | 200 :
         response.pReason := ADR( RESPONSE_200 );
         response.ReasonLength := SIZE( RESPONSE_200 )-1;
      | 404 :
         response.pReason := ADR( RESPONSE_404 );
         response.ReasonLength := SIZE( RESPONSE_404 )-1;
      | 501 :
         response.pReason := ADR( RESPONSE_501 );
         response.ReasonLength := SIZE( RESPONSE_501 )-1;
      ELSE
         response.pReason := NIL;
         response.ReasonLength := 0;
      END;
   END FillStatus;

//--------------------------------------------------------------------------------

   PRIVATE PROCEDURE AddDefaultHeaders( REF headers : CHeaders );
   VAR
      dt : Time.TDateTime;
   BEGIN
      // Date
      Time.GetCurrentUTCDateTime( dt );
      headers.Add( Date, httptools.FormatDate( dt ));
      
      // Server
      headers.AddOA( Server, L"SmartControl/1.0 (cfg)" );
      
      // Caching
      IF NOT headers.Contains( CacheControl ) THEN
         headers.AddOA( Pragma, L"no-cache" );
         headers.AddOA( CacheControl, L"no-cache" );
      END;

      // Content
      IF NOT headers.Contains( ContentType ) THEN
         headers.Add( ContentType, httptools.FormatContentOA( httptools.contentTextPlain, L"utf-8" ));
      END;
   END AddDefaultHeaders;

//--------------------------------------------------------------------------------

BEGIN
FINALLY
   DISPOSE( requestHeaders );
END RequestWorker;

//================================================================================

CLASS IMPLEMENTATION SimpleResponseWorker;

//--------------------------------------------------------------------------------

   LOCAL PROCEDURE Init( httpHandle : Sync.WAITABLE; request : httpapi.PHTTP_REQUEST; headers : TPHeaders; status : CARDINAL );
   BEGIN
      SUPER.Init( httpHandle, request, headers, NIL, NIL );
      SELF.status := status;
   END Init;
   
//--------------------------------------------------------------------------------

   INTERNAL VIRTUAL PROCEDURE HandleRequest( httpHandle : Sync.WAITABLE; request : httpapi.PHTTP_REQUEST; headers : TPHeaders; session : POINTER TO CSession; controller : TPController );
   VAR
      response : httpapi.HTTP_RESPONSE;
   BEGIN
      PrepareResponse( status, OUT response );
      httpapi.HttpSendHttpResponse( httpHandle, request^.RequestId, 0, ADR( response ), NIL, NIL, NIL, 0, NIL, NIL );
   END HandleRequest;

//--------------------------------------------------------------------------------

BEGIN   
END SimpleResponseWorker;

//================================================================================

CLASS IMPLEMENTATION MVCWorker;

//--------------------------------------------------------------------------------

   INTERNAL VIRTUAL PROCEDURE HandleRequest( httpHandle : Sync.WAITABLE; request : httpapi.PHTTP_REQUEST; headers : TPHeaders; session : POINTER TO CSession; controller : TPController );
   VAR
      response : httpapi.HTTP_RESPONSE;
      status : CARDINAL := 200;
   BEGIN
      IF controller = NIL THEN
         PrepareResponse( 500, OUT response );
         httpapi.HttpSendHttpResponse( httpHandle, request^.RequestId, 0, ADR( response ), NIL, NIL, NIL, 0, NIL, NIL );
      END;
      
      PrepareResponse( status, OUT response );
      httpapi.HttpSendHttpResponse( httpHandle, request^.RequestId, 0, ADR( response ), NIL, NIL, NIL, 0, NIL, NIL );
   END HandleRequest;

//--------------------------------------------------------------------------------

BEGIN   
END MVCWorker;

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
      RootPath : StringsO.CString;

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
      _RootPath : StringsO.CString;
      _Controllers : lists.CPtrList;

      _Sessions : maps.CStringMap; 
      _SessionsExpiration : TimeoutableTwoPtrMap.CTimeoutableTwoPtrMapSimplified;
      _SessionSeed : sha256.TDigest;

      _Pool : threadpool.CThreadPool;

      _HttpHandle : Sync.WAITABLE := NIL;
      _HttpRequest : StorageO.CMemoryBuffer;
      _HttpOverlapped : windows.OVERLAPPED;
      _HRequestSignal : Sync.WAITABLE := NIL;
      _HPoolHandle : Sync.WAITABLE := NIL;
   
   PUBLIC PROCEDURE Dispose();

   PRIVATE PROCEDURE StartWaitingRequest() : Sync.TAsyncResult;
   PRIVATE PROCEDURE ProcessRequest( request : httpapi.PHTTP_REQUEST );
   PRIVATE PROCEDURE GetSession( request : httpapi.PHTTP_REQUEST; headers : TPHeaders ) : POINTER TO CSession;
   
   INITIALLY CHttpSrv();
   FINALLY CHttpSrv();
END CHttpSrv;

//================================================================================

CLASS IMPLEMENTATION CHttpSrv;

//--------------------------------------------------------------------------------

   LOCAL VIRTUAL PROCEDURE OnHandle( Result : Sync.TAsyncResult; PoolHandle : threadpool.TPoolHandle; UserId : PTR );
   VAR
      EOF : BOOLEAN := FALSE;
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
         ProcessRequest( _HttpRequest.Data );
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
      IF _Running THEN
         b := TRUE;
         Stop();
      END;

      _RootPath := Value;
      IF _RootPath[_RootPath.Length-1] <> L"/" THEN
         _RootPath.AppendOA( L"/" );
      END;

      IF b THEN
         Start();
      END;
   END RootPath;

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
         UrlPrefix := _RootPath;
         Strings.FromCARD32W( _Port, 10, OUT s );
         UrlPrefix.PrependOA( s );
         UrlPrefix.PrependOA( L"http://+:" );
         Error := httpapi.HttpAddUrl( _HttpHandle, UrlPrefix.szData, NIL );
         IF Error <> 0 THEN
            RETURN Sync.arCannotStart;
         END;
      END;

      IF ( _Mode = mdHttps ) OR ( _Mode = mdBoth ) THEN
         UrlPrefix := _RootPath;
         Strings.FromCARD32W( _SslPort, 10, OUT s );
         UrlPrefix.PrependOA( s );
         UrlPrefix.PrependOA( L"https://+:" );
         Error := httpapi.HttpAddUrl( _HttpHandle, UrlPrefix.szData, NIL );
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

   PRIVATE PROCEDURE StartWaitingRequest() : Sync.TAsyncResult;
   VAR
      Error : CARDINAL;
   BEGIN
      ASSERT( _HttpHandle <> NIL );
      Storage.Zero( ADR( _HttpOverlapped ), SIZE( _HttpOverlapped ));
      _HttpOverlapped.hEvent := _HRequestSignal;

      LOOP      
         Error := httpapi.HttpReceiveHttpRequest( _HttpHandle, httpapi.HTTP_NULL_ID, 0, _HttpRequest.Data, _HttpRequest.Size, NIL, ADR( _HttpOverlapped ));

         CASE Error OF
         | winerror.NO_ERROR : // OK, have request
            ProcessRequest( _HttpRequest.Data );

         | winerror.ERROR_IO_PENDING :
            RETURN Sync.arPending;
         ELSE
            logger()^.LogSC( dlcError, L"HTTP", L"Unable to receive HTTP request", Error );
            RETURN Sync.arCannotStart;
         END;
      END; // LOOP
   END StartWaitingRequest;

//--------------------------------------------------------------------------------

   PRIVATE PROCEDURE ProcessRequest( request : httpapi.PHTTP_REQUEST );
   VAR
      controller : TPController;
      headers : TPHeaders := NIL;
      ph : threadpool.TPoolHandle;
      Reported : BOOLEAN := FALSE;
      Status : CARDINAL;
      Timeout : CARDINAL := Time.UptimeMS() + netsocket.FORSAFETY;
      Verb : TVerb := verbUnknown;
      Worker : POINTER TO RequestWorker := NIL;
   BEGIN
      CASE request^.Verb OF
      | httpapi.HttpVerbGET, httpapi.HttpVerbHEAD :
         Verb := verbGET;
      | httpapi.HttpVerbPOST :
         Verb := verbPOST;
      END;

      IF Verb = verbUnknown THEN
         Status := 501; // unsupported
      ELSE
         // prepare headers
         headers := NEW( CHeaders );
         headers^.FromRequest( request );
      
         // search controller
         _Controllers.Reset();
         WHILE _Controllers.MoveNext() DO
            controller := _Controllers.Current;
            IF controller^.AppliesFor( Verb, OA( CARDINAL( request^.CookedUrl.AbsPathLength >> 1 )-1, request^.CookedUrl.pAbsPath )) THEN
               NEW( TPMVCWorker( Worker ));
               EXIT;
            END;
         END; // WHILE

         IF Worker = NIL THEN
            Status := 404; // resource not found
         ELSE // search session, init worker
            Worker^.Init( _HttpHandle, request, headers, GetSession( request, headers ), controller );
         END;
      END; // IF Verb

      IF Worker = NIL THEN
         NEW( TPSimpleResponseWorker( Worker ));
         TPSimpleResponseWorker( Worker )^.Init( _HttpHandle, request, headers, Status );
      END;

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
   END ProcessRequest;

//--------------------------------------------------------------------------------

   PRIVATE PROCEDURE GetSession( request : httpapi.PHTTP_REQUEST; headers : TPHeaders ) : POINTER TO CSession;
   CONST
      SESSION_VALIDITY = 30*60*1000; // milliseconds, 30 minutes
   VAR
      c : CARDINAL;
      cookie : StringsO.CString;
      data : sha256.TDigest;
      i : INTEGER;
      ia : inetaddr.INETADDR;
      iv : sha256.TDigest;
      l : CARDINAL;
      ptr : PTR;
      s : StringsO.CString;
      session : POINTER TO CSession;
      sessionid : sha256.TDigest;
      shorttime : CARDINAL;
      time : Time.TTime64;
   BEGIN
      shorttime := Time.UptimeMS();
      // sweepout old sessions
      WHILE _SessionsExpiration.GetFirstElapsed( shorttime, TRUE, OUT session, OUT ptr ) DO
         _Sessions.Remove( session^.SID );
         DISPOSE( session );
      END; // WHILE
   
      IF headers^.Get( Cookie, OUT cookie ) THEN
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
      ia.FromM( PBYTE( request^.Address.pRemoteAddress ));
      digest.DigestOA( digest.sha256, OA( 31, ia.Data ), OUT data );
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
   END GetSession;

//--------------------------------------------------------------------------------

   INITIALLY CHttpSrv();
   VAR
      Error : CARDINAL;
      httpAPIVersion : httpapi.HTTPAPI_VERSION := httpapi.HTTPAPI_VERSION_1;
      time : Time.TTime64;
   BEGIN
      _RootPath.FromOA( L"/" );
      
      time := Time.time();
      Sync.Sleep( 33 );
      time := time * MAX( INT64 ) - Time.time();
      digest.DigestOA( digest.sha256, time, OUT _SessionSeed );
      
      _Pool.MinThreads := 2;
      _Pool.MaxThreads := 32;

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
      
      _Pool.FinishAndWait();
      
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

PROCEDURE modelView( CONST viewName : ARRAY OF WCHAR; REF model : maps.CStringStringMap ) : TPView;
BEGIN
   RETURN NIL;
END modelView;

//--------------------------------------------------------------------------------

PROCEDURE modelViewStream( CONST viewName : ARRAY OF WCHAR; viewSource : IOO.TPStream; REF model : maps.CStringStringMap ) : TPView;
BEGIN
   RETURN NIL;
END modelViewStream;

//--------------------------------------------------------------------------------

PROCEDURE modelViewContainer( CONST viewName : ARRAY OF WCHAR; REF model : ARRAY OF maps.CStringStringMap ) : TPView;
BEGIN
   RETURN NIL;
END modelViewContainer;

//--------------------------------------------------------------------------------

PROCEDURE modelViewContainerStream( CONST viewName : ARRAY OF WCHAR; viewSource : IOO.TPStream; REF model : ARRAY OF maps.CStringStringMap ) : TPView;
BEGIN
   RETURN NIL;
END modelViewContainerStream;

//================================================================================

END HttpSrv.