IMPLEMENTATION MODULE HttpSrv;

FROM Log IMPORT
   logger, dlcError, dlcWarning, dlcInfo;
   
IMPORT
   cphcommon,
   digest,
   httpapi,
   HttpConnection,
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
   TPHttpConnection = POINTER TO CHttpConnection;

//================================================================================

CLASS CHeaders IMPLEMENTS HttpCommon.IHttpHeaders;

   // IHttpHeaders
   PUBLIC VIRTUAL PROCEDURE Contains( Header : HttpCommon.TKnownHeader ) : BOOLEAN;
   PUBLIC VIRTUAL PROCEDURE Get( Header : HttpCommon.TKnownHeader; OUT Value : StringsO.IString ) : BOOLEAN;
   PUBLIC VIRTUAL PROCEDURE GetOA( Header : HttpCommon.TKnownHeader; OUT Value : ARRAY OF WCHAR ) : BOOLEAN;
   PUBLIC VIRTUAL PROCEDURE Add( Header : HttpCommon.TKnownHeader; CONST Value : StringsO.IString );
   PUBLIC VIRTUAL PROCEDURE AddOA( Header : HttpCommon.TKnownHeader; CONST Value : ARRAY OF WCHAR );
   
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
   
   PRIVATE PROCEDURE FromSysApi( sysapiHeader : httpapi.HTTP_HEADER_ID; OUT header : HttpCommon.TKnownHeader ) : BOOLEAN;
   PRIVATE PROCEDURE ToSysApi( header : HttpCommon.TKnownHeader; OUT sysapiHeader : httpapi.HTTP_HEADER_ID ) : BOOLEAN;
   
   PUBLIC PROCEDURE Dispose();
END CHeaders;

//--------------------------------------------------------------------------------

CLASS IMPLEMENTATION CHeaders;

//--------------------------------------------------------------------------------

   PUBLIC VIRTUAL PROCEDURE Contains( Header : HttpCommon.TKnownHeader ) : BOOLEAN;
   VAR
      s : StringsO.CString;
   BEGIN
      RETURN Get( Header, OUT s );
   END Contains;

//--------------------------------------------------------------------------------

   PUBLIC VIRTUAL PROCEDURE Get( Header : HttpCommon.TKnownHeader; OUT Value : StringsO.IString ) : BOOLEAN;
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

//--------------------------------------------------------------------------------

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
   
//--------------------------------------------------------------------------------

   PUBLIC VIRTUAL PROCEDURE AddOA( Header : HttpCommon.TKnownHeader; CONST Value : ARRAY OF WCHAR );
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

         ToSysApi( HttpCommon.TKnownHeader( KnownCache.Current ), OUT id );
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

CLASS CHttpApiStream( IOO.AStream ); // synchronous implementation only

   // AStream
   PUBLIC VIRTUAL READONLY PROPERTY
      CanRead : BOOLEAN;
      CanWrite : BOOLEAN;
      CanSeek : BOOLEAN;
      Long : BOOLEAN;
   PUBLIC VIRTUAL PROPERTY
      Length : CARD64;
      Position : CARD64;

   PUBLIC VIRTUAL PROCEDURE Seek( Origin : IOO.TSeekOrigin; Position : INT64 ); 
   PUBLIC VIRTUAL PROCEDURE Flush();
   PUBLIC VIRTUAL PROCEDURE Close( Persist : BOOLEAN );
  
   INTERNAL VIRTUAL PROCEDURE Start( Direction : IOO.TDirection; OperationTimeoutMS : CARDINAL ) : Sync.TAsyncResult;
   INTERNAL VIRTUAL PROCEDURE Abort( Direction : IOO.TDirection );

   // SELF
   PRIVATE VAR
      _HttpHandle : Sync.WAITABLE;
      _Request : httpapi.PHTTP_REQUEST;
      _Connection : TPHttpConnection;
      _ReadOut : BOOLEAN;
      _HeaderSent : BOOLEAN;
      _DataSent : BOOLEAN;

   PROCEDURE FromHttpApiRequest( httpHandle : Sync.WAITABLE; request : httpapi.PHTTP_REQUEST; connection : TPHttpConnection );
   
END CHttpApiStream;


(*================================================================================*)

CLASS IMPLEMENTATION CHttpApiStream;

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

   PUBLIC VIRTUAL PROCEDURE Seek( Origin : IOO.TSeekOrigin; Position : INT64 ); 
   BEGIN
      ASSERT( FALSE ); // not seekable      
   END Seek;
   
(*--------------------------------------------------------------------------------*)

   PUBLIC VIRTUAL PROCEDURE Flush();
   VAR
      FlushOutBuffer : ARRAY [0..4095] OF BYTE;
      l : CARDINAL;
   BEGIN
      // only read side can be flushed
      IF NOT _ReadOut THEN
         _ReadOut := TRUE;
         WHILE httpapi.HttpReceiveRequestEntityBody( _HttpHandle, _Request^.RequestId, 0, ADR( FlushOutBuffer ), SIZE( FlushOutBuffer ), OUT l, NIL ) = winerror.ERROR_MORE_DATA DO END;
      END;
   END Flush;

(*--------------------------------------------------------------------------------*)

   PUBLIC VIRTUAL PROCEDURE Close( Persist : BOOLEAN );
   BEGIN
      // persist takes no sense
      SendHeaders();
      IF NOT _DataSent THEN
         _DataSent := TRUE;
         httpapi.HttpSendHttpResponse( _HttpHandle, _Request^.RequestId, 0, ADR( _Response ), NIL, NIL, NIL, 0, NIL, NIL );
      END;
   END Close;
  
(*--------------------------------------------------------------------------------*)

   INTERNAL VIRTUAL PROCEDURE Start( Direction : IOO.TDirection; OperationTimeoutMS : CARDINAL ) : Sync.TAsyncResult;
   VAR
      Chunk : httpapi.HTTP_DATA_CHUNK;
      error : CARDINAL;
      L2 : CARDINAL;
      Result : Sync.TAsyncResult;
   BEGIN
      IF ( Direction = IOO.dirRead ) AND _ReadOut THEN
         Result := Sync.arNoData;
         
      ELSIF ( Direction = IOO.dirWrite ) AND _DataSent THEN
         Result := Sync.arCannotStart;

      ELSE
        Chunk.DataChunkType := httpapi.HttpDataChunkFromMemory;
         WHILE DevicePrepareData( Direction, OUT Chunk.pBuffer, OUT Chunk.BufferLength ) DO
            L2 := 0;
            IF Direction = IOO.dirRead THEN
               error := httpapi.HttpReceiveRequestEntityBody(
                           _HttpHandle, _Request^.RequestId, 0,
                           Chunk.pBuffer, Chunk.BufferLength, OUT L2,
                           NIL );
               IF L2 < Chunk.BufferLength THEN
                  IF ( error <> winerror.ERROR_SUCCESS ) AND ( error <> winerror.ERROR_HANDLE_EOF ) THEN
                     _ReadOut := TRUE;
                     Result := Sync.arAborted;
                  ELSIF L2 = 0 THEN
                     _ReadOut := TRUE;
                     Result := Sync.arNoData;
                  ELSE
                     Result := Sync.arCompleted;
                  END;
               ELSIF error = winerror.ERROR_MORE_DATA THEN
                  Result := Sync.arCompleted;
               ELSE
                  Result := Sync.arAborted;
               END;

            ELSE // write
               SendHeaders();
               error := httpapi.HttpSendResponseEntityBody(
                           _HttpHandle, _Request^.RequestId, httpapi.HTTP_SEND_RESPONSE_FLAG_MORE_DATA,
                           1, ADR( Chunk ), ADR( L2 ),
                           NIL, 0, NIL, NIL );
               IF ( error <> 0 ) OR ( L2 < Chunk.BufferLength ) THEN
                  Result := Sync.arAborted;
               END;

            END; // IF direction

            DeviceCompleteData( Direction, L2 );
            IF ( error <> 0 ) OR ( L2 < Chunk.BufferLength ) THEN
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

   INTERNAL VIRTUAL PROCEDURE Abort( Direction : IOO.TDirection );
   BEGIN
      DeviceFinish( Direction, Sync.arAborted );
   END Abort;

(*--------------------------------------------------------------------------------*)

   PROCEDURE FromHttpApiRequest( httpHandle : Sync.WAITABLE; request : httpapi.PHTTP_REQUEST; connection : TPHttpConnection );
   BEGIN
      _HttpHandle := httpHandle;
      _Request := request;
      _Connection := connection;
      _ReadOut := FALSE;
      _HeaderSent := FALSE;
      _DataSent := FALSE;
   END FromHttpApiRequest;
   
(*--------------------------------------------------------------------------------*)

BEGIN
   _HttpHandle := NIL;
   _Request := NIL;
   _Connection := NIL;
   _ReadOut := FALSE;
   _HeaderSent := FALSE;
   _DataSent := FALSE;
END CHttpApiStream;

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
   PRIVATE VAR
      _HttpHandle : Sync.WAITABLE;
      _Request : httpapi.PHTTP_REQUEST;
      _Stream : CHttpApiStream;
      _RequestHeaders : CHeaders;
      _ResponseHeaders : CHeaders;
   
   PROCEDURE FromHttpApiRequest( httpHandle : Sync.WAITABLE; request : httpapi.PHTTP_REQUEST );
      
END CHttpConnection;

//--------------------------------------------------------------------------------

CLASS IMPLEMENTATION CHttpConnection;

//--------------------------------------------------------------------------------

   VIRTUAL PROPERTY LocalAddress GET : inetaddr.INETADDR;
   BEGIN
   END LocalAddress;

//--------------------------------------------------------------------------------

   VIRTUAL PROPERTY RemoteAddress GET : inetaddr.INETADDR;
   BEGIN
   END RemoteAddress;

//--------------------------------------------------------------------------------
   
   VIRTUAL PROPERTY Stream GET : IOO.TPStream;
   BEGIN
      RETURN ADR( _Stream );
   END Stream;

//--------------------------------------------------------------------------------

   PUBLIC VIRTUAL PROPERTY RequestHeaders GET : HttpCommon.TPHttpHeaders;
   BEGIN
      RETURN ADR( _RequestHeaders );
   END RequestHeaders;
   
//--------------------------------------------------------------------------------

   PUBLIC VIRTUAL PROPERTY ResponseHeaders GET : HttpCommon.TPHttpHeaders;
   BEGIN
      RETURN ADR( _ResponseHeaders );
   END ResponseHeaders;
      
//--------------------------------------------------------------------------------

   PROCEDURE FromHttpApiRequest( httpHandle : Sync.WAITABLE; request : httpapi.PHTTP_REQUEST );
   BEGIN
      // TODO
   END FromHttpApiRequest;

//--------------------------------------------------------------------------------

BEGIN
   _HttpHandle := NIL;
   _Request := NIL;
END CHttpConnection;

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
   INTERNAL PROCEDURE PrepareResponse( Response : HttpCommon.THttpResponse; OUT response : httpapi.HTTP_RESPONSE );

   PRIVATE PROCEDURE FillStatus( REF response : httpapi.HTTP_RESPONSE; Response : HttpCommon.THttpResponse );
   PRIVATE PROCEDURE AddDefaultHeaders( REF headers : CHeaders );
END RequestWorker;      

//--------------------------------------------------------------------------------

TYPE
   TPSimpleResponseWorker = POINTER TO SimpleResponseWorker;

CLASS SimpleResponseWorker( RequestWorker );
   PRIVATE VAR
      Response : HttpCommon.THttpResponse := HttpCommon.httpres_200;
   LOCAL PROCEDURE Init( httpHandle : Sync.WAITABLE; request : httpapi.PHTTP_REQUEST; headers : TPHeaders; Response : HttpCommon.THttpResponse );
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

   INTERNAL PROCEDURE PrepareResponse( Response : HttpCommon.THttpResponse; OUT response : httpapi.HTTP_RESPONSE );
   VAR
      s : StringsO.CString;
   BEGIN
      response.Flags := 0;
      response.Version.MajorVersion := 1;
      response.Version.MinorVersion := 1;
      response.EntityChunkCount := 0;
      response.pEntityChunks := NIL;
      
      // status
      FillStatus( REF response, Response );
      
      // headers
      AddDefaultHeaders( REF responseHeaders );
      IF ( session <> NIL ) AND session^.New THEN
         responseHeaders.Add( HttpCommon.SetCookie, httptools.FormatSIDCookie( session^.SID, 0, session^.RootPath, s ));
      END;
      responseHeaders.ToResponse( REF response );
   END PrepareResponse;

//--------------------------------------------------------------------------------

   PRIVATE PROCEDURE FillStatus( REF response : httpapi.HTTP_RESPONSE; Response : HttpCommon.THttpResponse );
   BEGIN
      response.StatusCode := CARD16( Response );
      CASE Response OF
      | HttpCommon.httpres_200 :
         response.pReason := ADR( RESPONSE_200 );
         response.ReasonLength := SIZE( RESPONSE_200 )-1;
      | HttpCommon.httpres_404 :
         response.pReason := ADR( RESPONSE_404 );
         response.ReasonLength := SIZE( RESPONSE_404 )-1;
      | HttpCommon.httpres_501 :
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
      headers.Add( HttpCommon.Date, httptools.FormatDate( dt ));
      
      // Server
      headers.AddOA( HttpCommon.Server, L"SmartControl/1.0 (cfg)" );
      
      // Caching
      IF NOT headers.Contains( HttpCommon.CacheControl ) THEN
         headers.AddOA( HttpCommon.Pragma, L"no-cache" );
         headers.AddOA( HttpCommon.CacheControl, L"no-cache" );
      END;

      // Content
      IF NOT headers.Contains( HttpCommon.ContentType ) THEN
         headers.Add( HttpCommon.ContentType, httptools.FormatContentOA( httptools.contentTextPlain, L"utf-8" ));
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

   LOCAL PROCEDURE Init( httpHandle : Sync.WAITABLE; request : httpapi.PHTTP_REQUEST; headers : TPHeaders; response : HttpCommon.THttpResponse );
   BEGIN
      SUPER.Init( httpHandle, request, headers, NIL, NIL );
      SELF.Response := response;
   END Init;
   
//--------------------------------------------------------------------------------

   INTERNAL VIRTUAL PROCEDURE HandleRequest( httpHandle : Sync.WAITABLE; request : httpapi.PHTTP_REQUEST; headers : TPHeaders; session : POINTER TO CSession; controller : TPController );
   VAR
      response : httpapi.HTTP_RESPONSE;
   BEGIN
      PrepareResponse( Response, OUT response );
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
      status : HttpCommon.THttpResponse := HttpCommon.httpres_200;
   BEGIN
      IF controller = NIL THEN
         PrepareResponse( HttpCommon.httpres_500, OUT response );
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
      Status : HttpCommon.THttpResponse;
      Timeout : CARDINAL := Time.UptimeMS() + netsocket.FORSAFETY;
      Verb : HttpCommon.TVerb := HttpCommon.verbUnknown;
      Worker : POINTER TO RequestWorker := NIL;
   BEGIN
      CASE request^.Verb OF
      | httpapi.HttpVerbGET, httpapi.HttpVerbHEAD :
         Verb := HttpCommon.verbGET;
      | httpapi.HttpVerbPOST :
         Verb := HttpCommon.verbPOST;
      END;

      IF Verb = HttpCommon.verbUnknown THEN
         Status := HttpCommon.httpres_501; // unsupported
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
            Status := HttpCommon.httpres_404; // resource not found
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
   
      IF headers^.Get( HttpCommon.Cookie, OUT cookie ) THEN
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