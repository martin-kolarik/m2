IMPLEMENTATION MODULE SrvCommon;

FROM Debug IMPORT
   Assertion, LogAssertionW;

FROM Log IMPORT
   lcError, lcWarning, lcInfo;
   
IMPORT
   cphcommon,
   datetime,
   digest,
   httpapi,
   HttpConnection,
   httptools,
   IOO,
   Languages,
   maps,
   netsocket,
   rijndael,
   Storage,
   StorageO,
   Strings,
   syncmaps,
   threadpool,
   windows,
   winerror,
   XMLWriter;
   
CONST
   LOG_HTTP = L"HTTP";

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
      s : StringsO.CString;
   BEGIN
      IF KnownCache.Get( INTEGER( Header ), OUT s ) THEN
         Value.Assign( s );
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
   BEGIN
      IF RequestFlag THEN
         RETURN;
      END;
      KnownCache.Remove( INTEGER( Header ));
      KnownCache.Add( INTEGER( Header ), Value );
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

   PUBLIC VIRTUAL PROCEDURE Remove( Header : HttpCommon.TKnownHeader );
   BEGIN
      IF RequestFlag THEN
         RETURN;
      END;
      KnownCache.Remove( INTEGER( Header ));
   END Remove;

(*--------------------------------------------------------------------------------*)

   PUBLIC VIRTUAL PROCEDURE Enumerate( Known, Uknown : BOOLEAN; REF ES : PTR; OUT Name, Value : StringsO.IString ) : BOOLEAN;
   BEGIN
      ASSERTLOG( FALSE );
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
      s : StringsO.CString;
   BEGIN
      n.FromOA( Name );
      n.Lowerize();
      IF UnknownCache.Get( n, OUT s ) THEN
         Value.Assign( s );
         RETURN TRUE;
      ELSE
         RETURN FALSE;
      END;
   END GetUnknown;

(*--------------------------------------------------------------------------------*)

   PUBLIC VIRTUAL PROCEDURE AddUnknown( CONST Name : ARRAY OF WCHAR; CONST Value : StringsO.IString );
   VAR
      n : StringsO.CString;
   BEGIN
      IF RequestFlag THEN
         RETURN;
      END;
      n.FromOA( Name );
      n.Lowerize();
      UnknownCache.Remove( n );
      UnknownCache.Add( n, Value );
   END AddUnknown;

(*--------------------------------------------------------------------------------*)

   PUBLIC VIRTUAL PROCEDURE AddUnknownOA( CONST Name : ARRAY OF WCHAR; CONST Value : ARRAY OF WCHAR );
   VAR
      s : StringsO.CString;
   BEGIN
      s.FromOA( Value );
      AddUnknown( Name, s );
   END AddUnknownOA;

(*--------------------------------------------------------------------------------*)

   PUBLIC VIRTUAL PROCEDURE RemoveUnknown( CONST Name : ARRAY OF WCHAR );
   VAR
      n : StringsO.CString;
   BEGIN
      IF RequestFlag THEN
         RETURN;
      END;

      n.FromOA( Name );
      n.Lowerize();
      UnknownCache.Remove( n );
   END RemoveUnknown;

(*--------------------------------------------------------------------------------*)

   PUBLIC VIRTUAL PROCEDURE Dispose();
   BEGIN
      KnownCache.Dispose();
      UnknownCache.Dispose();
   END Dispose;

(*--------------------------------------------------------------------------------*)

BEGIN
FINALLY
   Dispose();
END CHeaders;

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
      ASSERTLOG( FALSE ); // not seekable      
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
         WHILE ReceiveData( REF Data ) = Sync.arCompleted DO END;
      END;
   END Flush;

(*--------------------------------------------------------------------------------*)

   PUBLIC FINAL PROCEDURE Close( Persist : BOOLEAN ); // persist takes no sense
   CONST
      lastChunk = C"0" + 13C + 10C + 13C + 10C;
   VAR
      buffer : StorageO.CMemoryBuffer;
   BEGIN
      StartResponse();
      IF NOT _DataSent THEN
         _DataSent := TRUE;

         IF Chunked THEN // send last chunk
            buffer.FromOA( OA( SIZE( lastChunk )-2, ADR( lastChunk )), FALSE );
            SendData( buffer );
         END;

         EndResponse();
      END;
   END Close;
  
(*--------------------------------------------------------------------------------*)

   INTERNAL FINAL PROCEDURE Start( Direction : IOO.TDirection; OperationTimeoutMS : CARDINAL ) : Sync.TAsyncResult;
   LABEL
      Finish;
   CONST
      chunkEnd = 13C + 10C;
   VAR
      buffer : StorageO.CMemoryBuffer;
      chBuffer : StorageO.CMemoryBuffer;
      chLen : CARDINAL;
      chunked : BOOLEAN;
      Data : ADDRESS;
      HaveSome : BOOLEAN := FALSE;
      L : CARDINAL;
      Result : Sync.TAsyncResult;
   BEGIN
      IF ( Direction = IOO.dirRead ) AND _ReadOut THEN
         Result := Sync.arNoData;
         // fall down to Finish
         
      ELSIF ( Direction = IOO.dirWrite ) AND _DataSent THEN
         Result := Sync.arCannotStart;
         // fall down to Finish

      ELSE
         IF Direction = IOO.dirWrite THEN
            Result := StartResponse();
            IF Result = Sync.arCompleted THEN
               chunked := Chunked;
            ELSE
               _DataSent := TRUE;
               // fall down to solve result
               GOTO Finish;
            END;
         END;

         WHILE DevicePrepareData( Direction, OUT Data, OUT L ) DO
            IF L = 0 THEN
               CONTINUE;
            END;
            IF Direction = IOO.dirRead THEN
               buffer.FromOA( OA( L-1, Data ), FALSE );
               Result := ReceiveData( REF buffer );
               IF Result = Sync.arCompleted THEN
                  HaveSome := TRUE;
                  L := buffer.Length;
               ELSE
                  _ReadOut := TRUE;
                  L := 0;
               END;

            ELSE // write

               // send chunk start
               IF chunked THEN
                  Strings.FromCARD64A( CARD64( L ), 16, OUT _ChunkBuffer );
                  chLen := LENGTH( _ChunkBuffer );
                  chBuffer.FromOA( OA( chLen+1, ADR( _ChunkBuffer )), FALSE ); // chLen+1 automatically sets length to data + CR + LF
                  TRY
                     chBuffer[chLen] := 13; // add CR
                     chBuffer[chLen+1] := 10; // add LF
                  CATCH UNHANDLED DO
                     // impossible
                  END;
                  Result := SendData( chBuffer );
                  IF Result <> Sync.arCompleted THEN
                     _DataSent := TRUE;
                  END;
               END;
               // send data               
               buffer.FromOA( OA( L-1, Data ), FALSE );
               Result := SendData( buffer );
               IF Result <> Sync.arCompleted THEN
                  L := 0;
                  _DataSent := TRUE;
               END;
               // send chunk stop
               IF chunked THEN
                  buffer.FromOA( OA( SIZE( chunkEnd )-2, ADR( chunkEnd )), FALSE );
                  Result := SendData( buffer );
                  IF Result <> Sync.arCompleted THEN
                     _DataSent := TRUE;
                  END;
               END;

            END; // IF direction

            DeviceCompleteData( Direction, L );

            IF Result <> Sync.arCompleted THEN
               IF HaveSome AND ( Result = Sync.arNoData ) THEN
                  Result := Sync.arCompleted;
               END;
               EXIT; // fall down to Finish
            END;

         END; // WHILE
      END; // IF Direction
      
   Finish:
      CASE Result OF
      | Sync.arPending,
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

   PUBLIC PROPERTY Chunked GET : BOOLEAN;
   BEGIN
      RETURN ResponseHeaders^.Contains( HttpCommon.TransferEncoding ); // now it is only chunked
   END Chunked;

(*--------------------------------------------------------------------------------*)

   PUBLIC PROPERTY Chunked SET( Value : BOOLEAN );
   BEGIN
      IF Value THEN
         ResponseHeaders^.AddOA( HttpCommon.TransferEncoding, L"chunked" );
      ELSE
         ResponseHeaders^.Remove( HttpCommon.TransferEncoding );
      END;
   END Chunked;

(*--------------------------------------------------------------------------------*)

   PUBLIC PROPERTY ResponseLength GET : CARD64;
   VAR
      l : CARD64;
      s : ARRAY [0..31] OF WCHAR;
   BEGIN
      IF NOT ResponseHeaders^.GetOA( HttpCommon.ContentLength, OUT s ) THEN
         RETURN -1;
      ELSIF NOT Strings.ToCARD64W( s, 10, OUT l ) THEN
         RETURN 0;
      ELSE
         RETURN l;
      END;
   END ResponseLength;

(*--------------------------------------------------------------------------------*)

   PUBLIC PROPERTY ResponseLength SET( Value : CARD64 );
   VAR
      s : ARRAY [0..31] OF WCHAR;
   BEGIN
      Strings.FromCARD64W( Value, 10, OUT s );
      ResponseHeaders^.AddOA( HttpCommon.ContentLength, s );
   END ResponseLength;

(*--------------------------------------------------------------------------------*)

   PUBLIC PROPERTY OverrideStatusResponse GET : BOOLEAN;
   BEGIN
      RETURN _OverrideStatusResponse;
   END OverrideStatusResponse;

(*--------------------------------------------------------------------------------*)

   PUBLIC PROPERTY OverrideStatusResponse SET( Value : BOOLEAN );
   BEGIN
      _OverrideStatusResponse := Value;
   END OverrideStatusResponse;

(*--------------------------------------------------------------------------------*)

   PUBLIC PROPERTY AllowCaching GET : BOOLEAN;
   BEGIN
      RETURN NOT ResponseHeaders^.Contains( HttpCommon.CacheControl );
   END AllowCaching;

(*--------------------------------------------------------------------------------*)

   PUBLIC PROPERTY AllowCaching SET( Value : BOOLEAN );
   BEGIN
      IF Value THEN
         ResponseHeaders^.Remove( HttpCommon.Pragma );
         ResponseHeaders^.Remove( HttpCommon.CacheControl );
      ELSE
         ResponseHeaders^.AddOA( HttpCommon.Pragma, L"no-cache" );
         ResponseHeaders^.AddOA( HttpCommon.CacheControl, L"no-cache" );
      END;
   END AllowCaching;

(*--------------------------------------------------------------------------------*)

   PUBLIC PROPERTY LastModified GET : datetime.DateTime;
   VAR
      dt : datetime.DateTime;
      s : StringsO.CString;
   BEGIN
      IF NOT ResponseHeaders^.Get( HttpCommon.LastModified, OUT s ) THEN
         dt.Clear();
      ELSIF NOT httptools.DecodeDate( s, OUT dt ) THEN
         dt.Clear();
      END;
      RETURN dt;
   END LastModified;

(*--------------------------------------------------------------------------------*)

   PUBLIC PROPERTY LastModified SET( CONST Value : datetime.DateTime );
   BEGIN
      ResponseHeaders^.Add( HttpCommon.LastModified, httptools.FormatDate( Value ));
   END LastModified;

(*--------------------------------------------------------------------------------*)

   PUBLIC PROCEDURE TestConditions( CONST ResourceLastModified : datetime.DateTime; CONST ResourceName : StringsO.IString ) : HttpCommon.THttpResponse; // returns suggested status -- 200, 304 of 412
   VAR
      dt : datetime.DateTime;
      IfModifiedSince : StringsO.CString;
      ldt : datetime.DateTime;
   BEGIN
      IF RequestHeaders^.Get( HttpCommon.IfModifiedSince, OUT IfModifiedSince ) AND httptools.DecodeDate( IfModifiedSince, OUT dt ) THEN
         ldt := ResourceLastModified;
         ldt.Millisecond := 0; // HTTP date has resolution of seconds
         IF dt < ldt THEN
            RETURN HttpCommon.httpres_200;
         ELSE
            RETURN HttpCommon.httpres_304;
         END;

      ELSE
         RETURN HttpCommon.httpres_200;
      END;
   END TestConditions;

(*--------------------------------------------------------------------------------*)

   PRIVATE PROCEDURE NormalizeHeaders();
   VAR
      dt : datetime.DateTime;
      Content : StringsO.CString;
   BEGIN
      // Date
      dt.SetNowUTC();
      // _ResponseHeaders.Add( HttpCommon.Date, httptools.FormatDateJD( dt )); // driven by http.sys
      IF dt < LastModified THEN // RFC: LastModified MUST NOT be greater than Date
         LastModified := dt;
      END;
      
      // cleanup if error
      IF StatusCode > HttpCommon.httpres_400 THEN
         ResponseHeaders^.Remove( HttpCommon.SetCookie );
      END;
      
      // Server
      ResponseHeaders^.AddOA( HttpCommon.Server, L"SCWS/1.0 on" );
      
      // Caching, not controlled
      // IF NOT ResponseHeaders^.Contains( HttpCommon.CacheControl ) THEN
      //    ResponseHeaders^.AddOA( HttpCommon.Pragma, L"no-cache" );
      //    ResponseHeaders^.AddOA( HttpCommon.CacheControl, L"no-cache" );
      // END;

      // Content
      IF NOT ResponseHeaders^.Contains( HttpCommon.ContentType ) THEN
         httptools.FormatContentOA( httptools.contentDefault, L"", L"", TRUE, OUT Content );
         ResponseHeaders^.Add( HttpCommon.ContentType, Content );
      END;
      
      // Message length
      IF RequestVersion <> HttpCommon.httpver11 THEN
         ResponseHeaders^.Remove( HttpCommon.TransferEncoding );
      END;
      IF Chunked THEN
         ResponseHeaders^.Remove( HttpCommon.ContentLength );
      END;
   END NormalizeHeaders;

(*--------------------------------------------------------------------------------*)

   PUBLIC PROCEDURE StartResponse() : Sync.TAsyncResult;
   VAR
      BStream : IOO.CBufferedStream;
      Content : StringsO.CString;
      Result : Sync.TAsyncResult;
   BEGIN
      IF _HeaderSent THEN
         RETURN Sync.arCompleted;
      END;
      _HeaderSent := TRUE;
      
      Flush();
      NormalizeHeaders();
      
      IF CARDINAL( StatusCode ) < 300 THEN // only 1xx and 2xx responses, which are successes, NORMAL StartResponse
         RETURN SendHeaders();

      ELSIF _OverrideStatusResponse THEN // leave client to create self error page, CLIENT error processing
         RETURN SendHeaders();
      
      ELSE // send default error page
         BStream.WMode := IOO.bmCommited;
         FormatErrorPage( ADR( BStream ));
         
         httptools.FormatContentOA( httptools.contentTextHTML, L"", L"utf-8", FALSE, OUT Content );
         ResponseHeaders^.Add( HttpCommon.ContentType, Content );
         ResponseLength := CARD64( BStream.BufferSize - BStream.WriteSpace );
   
         Result := SendHeaders();
         IF Result <> Sync.arCompleted THEN
            RETURN Result;
         END;

         // do send formatted status error page
         BStream.Stream := ADR( SELF );
         BStream.CommitWrite();

         RETURN Sync.arCannotStart; // any next write is impossible
      END;
   END StartResponse;

(*--------------------------------------------------------------------------------*)

   PRIVATE PROCEDURE FormatErrorPage( StreamToSend : IOO.TPStream );
   VAR
      Location : StringsO.CString;
      n : ARRAY [0..63] OF WCHAR;
      Writer : XMLWriter.CXMLWriter;
   BEGIN
      IF StatusCode = HttpCommon.httpres_304 THEN // RFC forbids content for 304
         RETURN;
      END;
   
      Writer.Stream := StreamToSend;
      Writer.WriteElementStartOA( L"", L"html" );
         Writer.WriteElementStartOA( L"", L"body" );
         
            CASE StatusCode OF
            | HttpCommon.httpres_301, HttpCommon.httpres_302, HttpCommon.httpres_303, HttpCommon.httpres_304, HttpCommon.httpres_307 : // workaround m2cpp bug
               ResponseHeaders^.Get( HttpCommon.Location, OUT Location );

               Writer.WriteElementStringOA( L"", L"h1", L"Server notification" );
               Writer.WriteElementStartOA( L"", L"p" );
                  Writer.WriteStringOA( L"The page should be redirected by client to " );
                  Writer.WriteElementStartOA( L"", L"a" );
                     Writer.WriteAttributeStringOA( L"", L"href", OA( Location.Length-1, Location.Data ));
                     Writer.WriteString( Location );
                  Writer.WriteElementEnd();
                  Writer.WriteStringOA( L". Please, click the link to move to correct page." );
               Writer.WriteElementEnd();

            | HttpCommon.httpres_401 :
               Writer.WriteElementStringOA( L"", L"h1", L"Unauthorized access" );
               Writer.WriteElementStartOA( L"", L"p" );
                  Writer.WriteStringOA( L"The server responded with HTTP status code " );
                  Strings.FromCARD32W( CARDINAL( StatusCode ), 10, OUT n );
                  Writer.WriteStringOA( n );
                  Writer.WriteStringOA( L". Please, log in to server and repeat the request." );
               Writer.WriteElementEnd();

            ELSE
               Writer.WriteElementStringOA( L"", L"h1", L"Unable to handle HTTP request" );
               Writer.WriteElementStartOA( L"", L"p" );
                  Writer.WriteStringOA( L"The server responded with HTTP status code " );
                  Strings.FromCARD32W( CARDINAL( StatusCode ), 10, OUT n );
                  Writer.WriteStringOA( n );
                  Writer.WriteStringOA( L". Please, correct the request URL or repeat the request later." );
               Writer.WriteElementEnd();
                  
            END; // CASE

         Writer.WriteElementEnd();
      Writer.WriteElementEnd();
      
      Writer.Close( TRUE ); // leave stream persist
   END FormatErrorPage;

(*--------------------------------------------------------------------------------*)

BEGIN
   _ReadOut := FALSE;
   _HeaderSent := FALSE;
   _DataSent := FALSE;
   _ChunkBuffer[0] := 0C;
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
      FullURI : StringsO.CString; // absolute URI, with protocol and host part
      AbsoluteURI : StringsO.CString; // absolute URI, can contain "undistinguishable" prefixes
      URIData : StringsO.CString; // query data
      RequestHeaders : HttpCommon.TPHttpHeaders;
      RequestVerb : HttpCommon.TVerb;
      RequestURI : StringsO.CString;
      ResponseHeaders : HttpCommon.TPHttpHeaders;

   PUBLIC VIRTUAL PROPERTY
      StatusCode : HttpCommon.THttpResponse;
      OverrideStatusResponse : BOOLEAN;
      Chunked : BOOLEAN;
      ResponseLength : CARD64;
      AllowCaching : BOOLEAN;
      LastModified : datetime.DateTime;

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

   PUBLIC VIRTUAL PROPERTY FullURI GET : StringsO.CString;
   BEGIN
      RETURN _Stream^.FullURI;
   END FullURI;

(*--------------------------------------------------------------------------------*)

   PUBLIC VIRTUAL PROPERTY AbsoluteURI GET : StringsO.CString;
   BEGIN
      RETURN _Stream^.AbsoluteURI;
   END AbsoluteURI;

(*--------------------------------------------------------------------------------*)

   PUBLIC VIRTUAL PROPERTY URIData GET : StringsO.CString;
   BEGIN
      RETURN _Stream^.URIData;
   END URIData;

(*--------------------------------------------------------------------------------*)

   PUBLIC VIRTUAL PROPERTY RequestHeaders GET : HttpCommon.TPHttpHeaders;
   BEGIN
      RETURN _Stream^.RequestHeaders;
   END RequestHeaders;
   
(*--------------------------------------------------------------------------------*)

   PUBLIC VIRTUAL PROPERTY RequestVerb GET : HttpCommon.TVerb;
   BEGIN
      RETURN _Stream^.RequestVerb;
   END RequestVerb;

(*--------------------------------------------------------------------------------*)

   PUBLIC VIRTUAL PROPERTY RequestURI GET : StringsO.CString;
   BEGIN
      RETURN _Stream^.RequestURI;
   END RequestURI;

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

   PUBLIC VIRTUAL PROPERTY OverrideStatusResponse GET : BOOLEAN;
   BEGIN
      RETURN _Stream^.OverrideStatusResponse;
   END OverrideStatusResponse;

(*--------------------------------------------------------------------------------*)

   PUBLIC VIRTUAL PROPERTY OverrideStatusResponse SET( Value : BOOLEAN );
   BEGIN
      _Stream^.OverrideStatusResponse := Value;
   END OverrideStatusResponse;

(*--------------------------------------------------------------------------------*)

   PUBLIC VIRTUAL PROPERTY Chunked GET : BOOLEAN;
   BEGIN
      RETURN _Stream^.Chunked;
   END Chunked;

(*--------------------------------------------------------------------------------*)

   PUBLIC VIRTUAL PROPERTY Chunked SET( Value : BOOLEAN );
   BEGIN
      _Stream^.Chunked := Value;
   END Chunked;

(*--------------------------------------------------------------------------------*)

   PUBLIC VIRTUAL PROPERTY ResponseLength GET : CARD64;
   BEGIN
      RETURN _Stream^.ResponseLength;
   END ResponseLength;

(*--------------------------------------------------------------------------------*)

   PUBLIC VIRTUAL PROPERTY ResponseLength SET( Value : CARD64 );
   BEGIN
      _Stream^.ResponseLength := Value; 
   END ResponseLength;

(*--------------------------------------------------------------------------------*)

   PUBLIC VIRTUAL PROPERTY AllowCaching GET : BOOLEAN;
   BEGIN
      RETURN _Stream^.AllowCaching;
   END AllowCaching;

(*--------------------------------------------------------------------------------*)

   PUBLIC VIRTUAL PROPERTY AllowCaching SET( Value : BOOLEAN );
   BEGIN
      _Stream^.AllowCaching := Value;
   END AllowCaching;

(*--------------------------------------------------------------------------------*)

   PUBLIC VIRTUAL PROPERTY LastModified GET : datetime.DateTime;
   BEGIN
      RETURN _Stream^.LastModified;
   END LastModified;

(*--------------------------------------------------------------------------------*)

   PUBLIC VIRTUAL PROPERTY LastModified SET( CONST Value : datetime.DateTime );
   BEGIN
      _Stream^.LastModified := Value;
   END LastModified;

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
      SID : StringsO.CString;

   PUBLIC VIRTUAL PROCEDURE Invalidate();
   
   PUBLIC VIRTUAL PROCEDURE Add( CONST Key : ARRAY OF WCHAR; Data : PTR );
   PUBLIC VIRTUAL PROCEDURE Remove( CONST Key : ARRAY OF WCHAR );
   PUBLIC VIRTUAL PROCEDURE Contains( CONST Key : ARRAY OF WCHAR ) : BOOLEAN;
   PUBLIC VIRTUAL PROCEDURE Get( CONST Key : ARRAY OF WCHAR; OUT Data : PTR ) : BOOLEAN;

   // SELF
   PRIVATE VAR
      _Valid : BOOLEAN := TRUE;
      _RootPath : StringsO.CString;
      _Created : datetime.TJD;
      _New : BOOLEAN := TRUE;
      _SID : StringsO.CString;
      _Data : syncmaps.CStringSyncMap;
   PUBLIC PROPERTY
      New : BOOLEAN;
   PUBLIC READONLY PROPERTY
      Valid : BOOLEAN;   
      RootPath : StringsO.CString;
      
   PUBLIC PROCEDURE Init( CONST sid : StringsO.IString; CONST rootPath : StringsO.IString );

END CSession;

(*--------------------------------------------------------------------------------*)

CLASS IMPLEMENTATION CSession;

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

   PUBLIC VIRTUAL PROCEDURE Add( CONST Key : ARRAY OF WCHAR; Data : PTR );
   BEGIN
      _Data.AddOA( Key, Data );
   END Add;

(*--------------------------------------------------------------------------------*)

   PUBLIC VIRTUAL PROCEDURE Remove( CONST Key : ARRAY OF WCHAR );
   BEGIN
      _Data.RemoveOA( Key );
   END Remove;

(*--------------------------------------------------------------------------------*)

   PUBLIC VIRTUAL PROCEDURE Contains( CONST Key : ARRAY OF WCHAR ) : BOOLEAN;
   BEGIN
      RETURN _Data.ContainsOA( Key );
   END Contains;

(*--------------------------------------------------------------------------------*)

   PUBLIC VIRTUAL PROCEDURE Get( CONST Key : ARRAY OF WCHAR; OUT Data : PTR ) : BOOLEAN;
   BEGIN
      RETURN _Data.GetOA( Key, OUT Data );
   END Get;

(*--------------------------------------------------------------------------------*)

   PUBLIC PROPERTY New GET : BOOLEAN;
   BEGIN
      RETURN _New;
   END New;

(*--------------------------------------------------------------------------------*)

   PUBLIC PROPERTY New SET( Value : BOOLEAN );
   BEGIN
      _New := Value;
   END New;

(*--------------------------------------------------------------------------------*)

   PUBLIC PROPERTY Valid GET : BOOLEAN;
   BEGIN
      RETURN _Valid;
   END Valid;

(*--------------------------------------------------------------------------------*)

   PUBLIC PROPERTY RootPath GET : StringsO.CString;
   BEGIN
      RETURN _RootPath;
   END RootPath;

(*--------------------------------------------------------------------------------*)

   PUBLIC PROCEDURE Init( CONST sid : StringsO.IString; CONST rootPath : StringsO.IString );
   BEGIN
      _SID.Assign( sid );
      _RootPath.Assign( rootPath );
   END Init;

(*--------------------------------------------------------------------------------*)

BEGIN
   _Created := datetime.GetCurrentJD();
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

(*--------------------------------------------------------------------------------*)

CLASS IMPLEMENTATION HttpWorker;
   
(*--------------------------------------------------------------------------------*)

   LOCAL VIRTUAL PROCEDURE Run();
   CONST
      HTTP_COMMON_LOG_TIME_FORMAT = L"dd/MMM/yyyy:HH:mm:ss +0000";
   VAR
      Connection : CHttpConnection;
      dt : datetime.DateTime;
      logger : Log.TPILogger := NIL;
      s : StringsO.CString;
      sOA : ARRAY [0..255] OF WCHAR;
   BEGIN
      IF ( _Session <> NIL ) AND _Session^.New THEN
         _Stream^.ResponseHeaders^.Add( HttpCommon.SetCookie, httptools.FormatSIDCookie( _Session^.SID, dt, _Session^.RootPath, s ));
      END;

      IF _Processor = NIL THEN
         ASSERTLOG( _Stream^.StatusCode <> HttpCommon.httpres_200 );
      ELSE
         Connection.FromStream( _Stream );
         IF _Processor^.AllowedFor( ADR( Connection )) THEN
            _Processor^.ProcessRequest( ADR( Connection ), _Session );
         ELSE
            _Stream^.StatusCode := HttpCommon.httpres_403;
         END;
         logger := _Processor^.RequestLogger;
      END;
      IF logger = NIL THEN
         logger := Log.logger();
      END;
      
      IF NOT logger^.FilteredFastCheck( lcError, 0 ) THEN
         _Stream^.RemoteAddress.ToOA( FALSE, OUT sOA );
         s.FromOA( sOA );
         s.AppendOA( L" - - [" );

         dt.SetNowUTC();
         IF dt.ToLanguageStringOA( Languages.GetDefaultLanguage( Languages.dlNeutral ), HTTP_COMMON_LOG_TIME_FORMAT, TRUE, TRUE, OUT sOA ) THEN
            s.AppendOA( sOA );
         END;

         CASE _Stream^.RequestVerb OF
         | HttpCommon.verbPOST :
            s.AppendOA( L'] "POST ' );
         | HttpCommon.verbHEAD :
            s.AppendOA( L'] "HEAD ' );
         ELSE
            s.AppendOA( L'] "GET ' );
         END;
         s.Append( _Stream^.AbsoluteURI );
         _Stream^.URIData.ToOA( OUT sOA );
         IF sOA[0] <> 0W THEN
            s.AppendOA( L"?" );
            s.AppendOA( sOA );
         END;
         s.AppendOA( L'"' );

         Strings.FromCARD32W( CARDINAL( _Stream^.StatusCode ), 10, OUT sOA );
         s.AppendOA( L" " );
         s.AppendOA( sOA );

         IF _Stream^.Chunked THEN
            s.AppendOA( L" chunked" );
         ELSIF _Stream^.Length = -1 THEN
            s.AppendOA( L" 0" );
         ELSE
            Strings.FromCARD32W( CARDINAL( _Stream^.Length ), 10, OUT sOA );
            s.AppendOA( L" " );
            s.AppendOA( sOA );
         END; // IF chunked

         logger^.LogS( lcError, 0, LOG_HTTP, OA( s.Length-1, s.Data ));
      END;
      
      _Stream^.Close( FALSE );
      DISPOSE( _Stream );
   END Run;

(*--------------------------------------------------------------------------------*)

   LOCAL PROCEDURE Init( processor : HttpSrv.TPHttpProcessor; stream : TPSrvStream; session : TPSrvSession );
   BEGIN
      SELF._Processor := processor;
      SELF._Stream := stream;
      SELF._Session := session;
   END Init;

(*--------------------------------------------------------------------------------*)

BEGIN
END HttpWorker;

(*================================================================================*)

TYPE
   TPSessionHolder = POINTER TO CSessionHolder;

CLASS CSessionHolder;

   PUBLIC VAR
      Processor : HttpSrv.TPHttpProcessor;
      Sessions : maps.CStringMap; 
      Expiration : TimeoutableTwoPtrMap.CTimeoutableTwoPtrMapSimplified;
      Seed : sha256.TDigest;

   PUBLIC PROCEDURE Init( CONST seed : INT64; processor : HttpSrv.TPHttpProcessor );
   PUBLIC PROCEDURE GetSession( cookie : StringsO.TPString; CONST addr : inetaddr.INETADDR; CONST rootPath : StringsO.CString ) : TPSrvSession;
   PUBLIC PROCEDURE Dispose();   

   INTERNAL PROCEDURE OnSessionExpired( Session : TPSrvSession );
END CSessionHolder;

(*--------------------------------------------------------------------------------*)

CLASS IMPLEMENTATION CSessionHolder;

(*--------------------------------------------------------------------------------*)

   PUBLIC PROCEDURE Init( CONST seed : INT64; processor : HttpSrv.TPHttpProcessor );
   VAR
      lseed : INT64;
   BEGIN
      lseed := INT64( ADR( SELF )) * seed;
      digest.DigestOA( digest.sha256, lseed, OUT Seed );
      Processor := processor;
   END Init;

(*--------------------------------------------------------------------------------*)

   PUBLIC PROCEDURE GetSession( pcookie : StringsO.TPString; CONST addr : inetaddr.INETADDR; CONST rootPath : StringsO.CString ) : TPSrvSession;
   VAR
      c : CARDINAL;
      cookie : StringsO.CString;
      data : sha256.TDigest;
      iv : sha256.TDigest;
      l : CARDINAL;
      ptr : PTR;
      s : StringsO.CString;
      session : TPSrvSession;
      sessionid : sha256.TDigest;
      shorttime : CARDINAL;
      time : datetime.TTime64;
   BEGIN
      // sweepout old sessions
      shorttime := datetime.UptimeMS();
      WHILE Expiration.GetFirstElapsed( shorttime, TRUE, OUT session, OUT ptr ) DO
         Sessions.Remove( session^.SID );
         OnSessionExpired( session );
         DISPOSE( session );
      END; // WHILE
   
      IF ( pcookie <> NIL ) AND Sessions.Get( pcookie^, OUT session ) THEN
         session^.New := FALSE;
         Expiration.Remove( session );
         IF session^.Valid THEN // move expiration to the future
            Expiration.Add( shorttime, session, 0, Processor^.SessionValidityMS );
            RETURN session;
         ELSE // kill the session
            Sessions.Remove( s );
            OnSessionExpired( session );
            DISPOSE( session );
         END;
      END;

      // cookie not set or cookie not found, create new empty session
      time := datetime.time();
      digest.DigestOA( digest.sha256, time, OUT iv );
      digest.DigestOA( digest.sha256, OA( 31, addr.Data ), OUT data );
      rijndael.Encrypt( rijndael.cphmBlockEncrypt, rijndael.rkl256, Seed, iv, data, OUT sessionid, OUT c );
      
      l := cphcommon.BASE64CharCount( SIZE( sessionid ));
      cookie.Size := l;
      cookie.Length := l;
      cphcommon.ToBASE64( sessionid, OUT OA( l-1, PWCHAR( cookie.Data )));
      
      NEW( session );
      session^.Init( cookie, rootPath );
      Sessions.Add( cookie, session );
      Expiration.Add( shorttime, session, 0, Processor^.SessionValidityMS );
      
      RETURN session;      
   END GetSession;

(*--------------------------------------------------------------------------------*)

   PUBLIC PROCEDURE Dispose();   
   VAR
      Session : TPSrvSession;
   BEGIN
      Sessions.Reset();
      WHILE Sessions.MoveNext() DO
         Session := Sessions.CurrentData;
         OnSessionExpired( Session );
         DISPOSE( Session );
      END; // WHILE      
   END Dispose;

(*--------------------------------------------------------------------------------*)

   INTERNAL PROCEDURE OnSessionExpired( Session : TPSrvSession );
   BEGIN
      IF Processor <> NIL THEN
         Processor^.SessionExpired( Session );
      END;
   END OnSessionExpired;

(*--------------------------------------------------------------------------------*)

BEGIN
   Processor := NIL;
   Seed[0] := 0;
FINALLY
   Dispose();
END CSessionHolder;

(*================================================================================*)

CLASS IMPLEMENTATION ASrvCommon;

(*--------------------------------------------------------------------------------*)

   LOCAL VIRTUAL PROCEDURE OnHandle( Result : Sync.TAsyncResult; PoolHandle : threadpool.TPoolHandle; UserId : PTR );
   BEGIN
   END OnHandle;

(*--------------------------------------------------------------------------------*)

   PUBLIC VIRTUAL PROPERTY Mode GET : HttpSrv.TMode;
   BEGIN
      RETURN _Mode;
   END Mode;

(*--------------------------------------------------------------------------------*)

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

(*--------------------------------------------------------------------------------*)

   PUBLIC VIRTUAL PROPERTY Port GET : CARDINAL;
   BEGIN
      RETURN _Port;
   END Port;

(*--------------------------------------------------------------------------------*)

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

(*--------------------------------------------------------------------------------*)

   PUBLIC VIRTUAL PROPERTY SslPort GET : CARDINAL;
   BEGIN
      RETURN _SslPort;
   END SslPort;

(*--------------------------------------------------------------------------------*)

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

(*--------------------------------------------------------------------------------*)

   PUBLIC VIRTUAL PROPERTY RootPath GET : StringsO.CString;
   BEGIN
      RETURN _RootPath;
   END RootPath;

(*--------------------------------------------------------------------------------*)

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

(*--------------------------------------------------------------------------------*)

   PUBLIC FINAL PROCEDURE RegisterProcessor( Processor : HttpSrv.TPHttpProcessor );
   VAR
      holder : TPSessionHolder;
   BEGIN
      NEW( holder );
      holder^.Init( _Seed, Processor );
      _Processors.Add( Processor, holder );
   END RegisterProcessor;

(*--------------------------------------------------------------------------------*)

   PUBLIC FINAL PROCEDURE ForgetProcessor( Processor : HttpSrv.TPHttpProcessor );
   VAR
      holder : TPSessionHolder;
   BEGIN
      IF _Processors.Get( Processor, OUT holder ) THEN
         _Processors.Remove( Processor );
         DISPOSE( holder );
      END;
   END ForgetProcessor;

(*--------------------------------------------------------------------------------*)

   PUBLIC PROCEDURE Dispose();
   VAR
      holder : TPSessionHolder;
   BEGIN
      _Pool.FinishAndWait();

      _Processors.Reset();
      WHILE _Processors.MoveNext() DO
         holder := _Processors.CurrentData;
         DISPOSE( holder );
      END; // WHILE
      _Processors.Dispose();

      IF _PreparedStream <> NIL THEN
         DISPOSE( _PreparedStream );
      END;
   END Dispose;

(*--------------------------------------------------------------------------------*)

   INTERNAL PROPERTY PreparedStream GET : TPSrvStream;
   BEGIN
      RETURN _PreparedStream;
   END PreparedStream;

(*--------------------------------------------------------------------------------*)

   INTERNAL PROCEDURE PrepareStream(); // calls GetNewStream
   BEGIN
      _PreparedStream := GetNewStream();
   END PrepareStream;

(*--------------------------------------------------------------------------------*)

   INTERNAL PROCEDURE ProcessPreparedStream();
   VAR
      currentHolder : TPSessionHolder;
      currentProcessor : HttpSrv.TPHttpProcessor;
      foundProcessor : HttpSrv.TPHttpProcessor := NIL;
      ph : threadpool.TPoolHandle;
      Reported : BOOLEAN := FALSE;
      Result : Sync.TAsyncResult;
      Session : TPSrvSession;
      Timeout : CARDINAL := datetime.UptimeMS() + netsocket.FORSAFETY;
      uri : StringsO.CString;
      Verb : HttpCommon.TVerb;
      WantsSession : BOOLEAN := FALSE;
      Worker : POINTER TO HttpWorker;
   BEGIN
      IF _PreparedStream = NIL THEN
         ASSERTLOG( FALSE, L"Request to process not prepared stream." );
         RETURN;
      END;

      Result :=  _PreparedStream^.StartHandleRequest();
      Verb := _PreparedStream^.RequestVerb;
      IF Result = Sync.arAborted THEN
         _PreparedStream^.StatusCode := HttpCommon.httpres_503; // internal server error
   
      ELSIF Verb = HttpCommon.verbUnknown THEN
         _PreparedStream^.StatusCode := HttpCommon.httpres_501; // unsupported

      ELSE // verb OK, search processor
         _Processors.Reset();
         WHILE _Processors.MoveNext() DO
            uri := _PreparedStream^.RequestURI;
            currentProcessor := _Processors.Current;
            currentHolder := _Processors.CurrentData;
            IF currentProcessor^.AppliesFor( Verb, OA( uri.Length-1, uri.Data ), OUT WantsSession ) THEN
               foundProcessor := currentProcessor;
               EXIT;
            END;
         END; // WHILE

         IF foundProcessor = NIL THEN
            _PreparedStream^.StatusCode := HttpCommon.httpres_404; // resource not found
         END;
      END; // IF

      IF WantsSession THEN
         Session := GetSessionForPreparedStream( currentHolder );
      ELSE
         Session := NIL;
      END;
      NEW( Worker );
      Worker^.Init( foundProcessor, _PreparedStream, Session );
      LOOP
         IF _Pool.RunWorker( ADR( SELF ), 0, FALSE, Worker, FALSE, OUT ph ) THEN
            EXIT;
         END;
         IF NOT Reported THEN
            Reported := TRUE;
            Log.logger()^.LogS( lcInfo, 0, LOG_HTTP, L"Pool has no space, wait for a while" );
         END;

         Sync.Sleep( 100 );
         IF datetime.UptimeMS() - Timeout > 0 THEN // time elapsed
            Log.logger()^.LogS( lcWarning, 0, LOG_HTTP, L"Unable to process HTTP request, pool exhausted" );
            EXIT;
         END;
      END;

      Worker^.Release();
   END ProcessPreparedStream;

(*--------------------------------------------------------------------------------*)

   PRIVATE PROCEDURE GetSessionForPreparedStream( _holder : ADDRESS ) : TPSrvSession;
   VAR
      cookies : StringsO.CString;
      holder : TPSessionHolder := _holder;
      pcookie : StringsO.TPString;
      sid : StringsO.CString;
   BEGIN
      IF _PreparedStream = NIL THEN
         ASSERTLOG( FALSE, L"Request to get cookie for unknown stream" );
         RETURN NIL;
      ELSIF _PreparedStream^.RequestHeaders^.Get( HttpCommon.Cookie, OUT cookies ) AND httptools.DecodeSIDCookie( cookies, OUT sid ) THEN
         pcookie := ADR( sid );
      ELSE
         pcookie := NIL;
      END;
      RETURN holder^.GetSession( pcookie, _PreparedStream^.RemoteAddress, _RootPath );
   END GetSessionForPreparedStream;

(*--------------------------------------------------------------------------------*)

   INITIALLY ASrvCommon();
   BEGIN
      _RootPath.FromOA( L"/" );
      
      _Seed := datetime.time();
      Sync.Sleep( 17 );
      _Seed := _Seed * ( MAX( INT64 ) - datetime.time() );
      
      _Pool.MinThreads := 2;
      _Pool.MaxThreads := 32;

      _PreparedStream := NIL;
   END ASrvCommon;

(*--------------------------------------------------------------------------------*)

   FINALLY ASrvCommon();
   BEGIN
      Dispose();
   END ASrvCommon;

(*--------------------------------------------------------------------------------*)

END ASrvCommon;

(*================================================================================*)

END SrvCommon.
