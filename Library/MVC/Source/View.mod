IMPLEMENTATION MODULE View;

FROM Debug IMPORT
   Assertion, LogAssertionW;

IMPORT
   FIO,
   FIOO,
   HttpCommon,
   HttpTools,
   IOO,
   Languages,
   LanguagesO,
   lists,
   maps,
   netsocket,
   NodeList,
   Strings,
   Sync,
   time;

(*================================================================================*)

CLASS IMPLEMENTATION CStatusCodeView;

(*--------------------------------------------------------------------------------*)

   PUBLIC PROPERTY OutputType GET : MVC.TViewOutputType;
   BEGIN
      RETURN MVC.votBuffer;
   END OutputType;

(*--------------------------------------------------------------------------------*)

   PUBLIC VIRTUAL PROCEDURE FormatToBuffer( CONST Request : MVC.IHttpRequest; REF Response : MVC.IHttpResponse; OUT Output : StorageO.CMemoryBuffer ) : BOOLEAN; // returning false means 500 response
   BEGIN
      Response.StatusCode := StatusCode;
      RETURN TRUE;
   END FormatToBuffer;

(*--------------------------------------------------------------------------------*)

   PUBLIC VIRTUAL PROCEDURE FormatToInputStream( CONST Request : MVC.IHttpRequest; REF Response : MVC.IHttpResponse; OUT InputStream : IOO.TPStream ) : BOOLEAN; // returning false means 500 response, Stream MUST be DISPOSED after usage
   BEGIN
      ASSERTLOG( FALSE );
      RETURN FALSE;
   END FormatToInputStream;

(*--------------------------------------------------------------------------------*)

   PUBLIC VIRTUAL PROCEDURE FormatToOutputStream( CONST Request : MVC.IHttpRequest; REF Response : MVC.IHttpResponse; OutputStream : IOO.TPStream ) : BOOLEAN; // returning false means 500 response
   BEGIN
      ASSERTLOG( FALSE );
      RETURN FALSE;
   END FormatToOutputStream;

(*--------------------------------------------------------------------------------*)

   PUBLIC VIRTUAL PROCEDURE Release();
   VAR
      a : TPStatusCodeView := ADR( SELF );
   BEGIN
      DISPOSE( a );
   END Release;

(*--------------------------------------------------------------------------------*)

   PUBLIC PROCEDURE Init( StatusCode : HttpCommon.THttpResponse );   
   BEGIN
      SELF.StatusCode := StatusCode;
   END Init;
   
(*--------------------------------------------------------------------------------*)

BEGIN
   StatusCode := HttpCommon.httpres_InternalServerError;
END CStatusCodeView;

(*================================================================================*)

CLASS IMPLEMENTATION CFileView;

(*--------------------------------------------------------------------------------*)

   PUBLIC PROPERTY OutputType GET : MVC.TViewOutputType;
   BEGIN
      RETURN MVC.votOutputStream;
   END OutputType;

(*--------------------------------------------------------------------------------*)

   PUBLIC VIRTUAL PROCEDURE FormatToBuffer( CONST Request : MVC.IHttpRequest; REF Response : MVC.IHttpResponse; OUT Output : StorageO.CMemoryBuffer ) : BOOLEAN; // returning false means 500 response, Output is empty on input
   BEGIN
      ASSERTLOG( FALSE );
      RETURN FALSE;
   END FormatToBuffer;

(*--------------------------------------------------------------------------------*)

   PUBLIC VIRTUAL PROCEDURE FormatToInputStream( CONST Request : MVC.IHttpRequest; REF Response : MVC.IHttpResponse; OUT InputStream : IOO.TPStream ) : BOOLEAN; // returning false means 500 response, Stream MUST be DISPOSED after usage
   BEGIN
      ASSERTLOG( FALSE );
      RETURN FALSE;
   END FormatToInputStream;

(*--------------------------------------------------------------------------------*)

   PUBLIC VIRTUAL PROCEDURE FormatToOutputStream( CONST Request : MVC.IHttpRequest; REF Response : MVC.IHttpResponse; OutputStream : IOO.TPStream ) : BOOLEAN; // returning false means 500 response
   VAR
      buffer : StorageO.CMemoryBuffer;
      Content : StringsO.CString;
      empty : StringsO.CString;
      fileName : ARRAY [0..299] OF WCHAR;
      filePath : StringsO.CString;
      fs : FIOO.CFileStream;
      l : CARDINAL;
      lastModified : time.DateTime;
      Result : Sync.TAsyncResult;
   BEGIN
      IF Resolver = NIL THEN
         Response.StatusCode := HttpCommon.httpres_404;
         RETURN TRUE;
      ELSIF NOT Resolver^.ResolvePath( ResolverContext, OA( PathRelativeToContext.Length-1, PathRelativeToContext.rawData ), OUT filePath ) THEN
         Response.StatusCode := HttpCommon.httpres_404;
         RETURN TRUE;
      END;

      TRY
         fs.FromPath( OA( filePath.Length-1, filePath.rawData ), FIOO.imOpenRead );
      CATCH e : IOO.CIOException DO
         Response.StatusCode := HttpCommon.httpres_404;
         RETURN TRUE;
      END;

      IF ( MIMEResolver = NIL ) OR NOT MIMEResolver^.ResolveMIME( MIMEResolverContext, filePath, OUT Content ) THEN
         HttpTools.FormatContent( HttpTools.contentUnknown, filePath, empty, TRUE, OUT Content );
      END;
      Response.ContentType := Content;
      Response.AllowCaching := TRUE;
      lastModified := FIO.GetFileTime( fs.Handle );
      Response.LastModified := lastModified;
      Response.StatusCode := Request.TestConditions( lastModified, empty );
      IF Response.StatusCode <> HttpCommon.httpres_200 THEN
         fs.Close( FALSE );
         RETURN TRUE;
      END;

      IF DispositionFlag THEN
         FIO.PathTailW( OA( filePath.Length-1, filePath.rawData ), OUT fileName );
         Strings.PrependW( REF fileName, L"attachment; filename=" );
         Response.ResponseHeaders^.AddUnknownOA( L"Content-Disposition", fileName );
      END;
      Response.Length := fs.Length;

      buffer.Size := MIN2( 2*65536, fs.Length32 );
      LOOP
         buffer.Clear();
         Result := fs.ReadBuffer( buffer.Size, REF buffer, Sync.FORSAFETY );
         ASSERTLOG( Result <> Sync.arTimeout );
         IF Result = Sync.arNoData THEN
            // fall down
         ELSIF Result NOT IN Sync.arsCompletions THEN
            Response.StatusCode := HttpCommon.httpres_500;
            EXIT;
         END;

         IF NOT buffer.Empty THEN
            Result := OutputStream^.WriteBuffer( buffer, OUT l, netsocket.FORSAFETY );
            ASSERTLOG( Result <> Sync.arTimeout );
            ASSERTLOG( l = buffer.Length );
         END;
         
         IF Result = Sync.arNoData THEN
            EXIT;
         END;
      END; // LOOP
      
      fs.Close( FALSE );
      RETURN TRUE;
   END FormatToOutputStream;

(*--------------------------------------------------------------------------------*)

   PUBLIC VIRTUAL PROCEDURE Release();
   VAR
      a : TPFileView := ADR( SELF );
   BEGIN
      DISPOSE( a );
   END Release;

(*--------------------------------------------------------------------------------*)

   PUBLIC PROCEDURE Init( CONST Resolver : FSO.TPFilePathResolver; ResolverContext : PTR; CONST PathRelativeToContext : ARRAY OF WCHAR; DispositionFlag : BOOLEAN; CONST MIMEResolver : MVC.TPMIMEResolver; MIMEResolverContext : PTR );
   BEGIN
      SELF.Resolver := Resolver;
      SELF.ResolverContext := ResolverContext;
      SELF.PathRelativeToContext.FromOA( PathRelativeToContext );
      SELF.DispositionFlag := DispositionFlag;
      SELF.MIMEResolver := MIMEResolver;
      SELF.MIMEResolverContext := MIMEResolverContext;
   END Init;
   
(*--------------------------------------------------------------------------------*)

BEGIN
   Resolver := NIL;
   ResolverContext := 0;
   DispositionFlag := FALSE;
   MIMEResolver := NIL;
   MIMEResolverContext := 0;
END CFileView;

(*================================================================================*)

CLASS IMPLEMENTATION CRedirectView;

(*--------------------------------------------------------------------------------*)

   PUBLIC PROPERTY OutputType GET : MVC.TViewOutputType;
   BEGIN
      RETURN MVC.votBuffer;
   END OutputType;

(*--------------------------------------------------------------------------------*)

   PUBLIC VIRTUAL PROCEDURE FormatToBuffer( CONST Request : MVC.IHttpRequest; REF Response : MVC.IHttpResponse; OUT Output : StorageO.CMemoryBuffer ) : BOOLEAN; // returning false means 500 response
   VAR
      i : CARDINAL;
      Location : StringsO.CString;
   BEGIN
      // set status and length
      Response.StatusCode := HttpTools.GetRedirectCode( HttpTools.redirectTemporarily, FALSE );
      Response.AllowCaching := FALSE;
      
      // set location
      IF AbsoluteFlag THEN
         Location := URIOrControllerName;
      ELSE
         Location := Request.FullURI;
         IF NOT Request.ControllerURI.Empty THEN
            i := Location.IndexOf( Request.ControllerURI, 0 );
            ASSERTLOG( i <> -1 );
            Location.Remove( i-1, -1 ); // remove trailing slash too
         ELSIF Location.EndsWithOA( L"/" ) THEN
            Location.Remove( Location.Length-1, -1 );            
         END;
         IF NOT URIOrControllerName.Empty THEN
            Location.AppendOA( L"/" );
            Location.Append( URIOrControllerName );
         END;
      END;
      Response.ResponseHeaders^.Add( HttpCommon.Location, Location );
      
      // generating textual page with help text about page moving is left to common server routines
      // Response.Length := 0;

      RETURN TRUE;
   END FormatToBuffer;

(*--------------------------------------------------------------------------------*)

   PUBLIC VIRTUAL PROCEDURE FormatToInputStream( CONST Request : MVC.IHttpRequest; REF Response : MVC.IHttpResponse; OUT InputStream : IOO.TPStream ) : BOOLEAN; // returning false means 500 response, Stream MUST be DISPOSED after usage
   BEGIN
      ASSERTLOG( FALSE );
      RETURN FALSE;
   END FormatToInputStream;

(*--------------------------------------------------------------------------------*)

   PUBLIC VIRTUAL PROCEDURE FormatToOutputStream( CONST Request : MVC.IHttpRequest; REF Response : MVC.IHttpResponse; OutputStream : IOO.TPStream ) : BOOLEAN; // returning false means 500 response
   BEGIN
      ASSERTLOG( FALSE );
      RETURN FALSE;
   END FormatToOutputStream;

(*--------------------------------------------------------------------------------*)

   PUBLIC VIRTUAL PROCEDURE Release();
   VAR
      a : TPRedirectView := ADR( SELF );
   BEGIN
      DISPOSE( a );
   END Release;

(*--------------------------------------------------------------------------------*)

   PUBLIC PROCEDURE Init( CONST URIIsAbsolute : BOOLEAN; URIOrControllerName : ARRAY OF WCHAR );   
   BEGIN
      AbsoluteFlag := URIIsAbsolute;
      SELF.URIOrControllerName.FromOA( URIOrControllerName );
   END Init;
   
(*--------------------------------------------------------------------------------*)

BEGIN
   AbsoluteFlag := FALSE;
END CRedirectView;

(*================================================================================*)

CLASS IMPLEMENTATION CRawHTMLView;

(*--------------------------------------------------------------------------------*)

   PUBLIC PROPERTY OutputType GET : MVC.TViewOutputType;
   BEGIN
      RETURN MVC.votBuffer;
   END OutputType;

(*--------------------------------------------------------------------------------*)

   PUBLIC VIRTUAL PROCEDURE FormatToBuffer( CONST Request : MVC.IHttpRequest; REF Response : MVC.IHttpResponse; OUT Output : StorageO.CMemoryBuffer ) : BOOLEAN; // returning false means 500 response
   VAR
      Content : StringsO.CString;
      now : time.DateTime;
   BEGIN
      now.SetNowUTC();
   
      HttpTools.FormatContentOA( HttpTools.contentTextHTML, L"", L"utf-8", FALSE, OUT Content );
      Response.ContentType := Content;
      Response.AllowCaching := FALSE;
      Response.LastModified := now;

      LanguagesO.ToMB( HTML, Languages.cp_UTF8, FALSE, REF Output );
      RETURN TRUE;
   END FormatToBuffer;

(*--------------------------------------------------------------------------------*)

   PUBLIC VIRTUAL PROCEDURE FormatToInputStream( CONST Request : MVC.IHttpRequest; REF Response : MVC.IHttpResponse; OUT InputStream : IOO.TPStream ) : BOOLEAN; // returning false means 500 response, Stream MUST be DISPOSED after usage
   BEGIN
      ASSERTLOG( FALSE );
      RETURN FALSE;
   END FormatToInputStream;

(*--------------------------------------------------------------------------------*)

   PUBLIC VIRTUAL PROCEDURE FormatToOutputStream( CONST Request : MVC.IHttpRequest; REF Response : MVC.IHttpResponse; OutputStream : IOO.TPStream ) : BOOLEAN; // returning false means 500 response
   BEGIN
      ASSERTLOG( FALSE );
      RETURN FALSE;
   END FormatToOutputStream;

(*--------------------------------------------------------------------------------*)

   PUBLIC VIRTUAL PROCEDURE Release();
   VAR
      a : TPRawHTMLView := ADR( SELF );
   BEGIN
      DISPOSE( a );
   END Release;

(*--------------------------------------------------------------------------------*)

   PUBLIC PROCEDURE Init( CONST HTML : ARRAY OF WCHAR );   
   BEGIN
      SELF.HTML.FromOA( HTML );
   END Init;
   
(*--------------------------------------------------------------------------------*)

END CRawHTMLView;

(*================================================================================*)

CLASS IMPLEMENTATION CRawTextView;

(*--------------------------------------------------------------------------------*)

   PUBLIC PROPERTY OutputType GET : MVC.TViewOutputType;
   BEGIN
      RETURN MVC.votBuffer;
   END OutputType;

(*--------------------------------------------------------------------------------*)

   PUBLIC VIRTUAL PROCEDURE FormatToBuffer( CONST Request : MVC.IHttpRequest; REF Response : MVC.IHttpResponse; OUT Output : StorageO.CMemoryBuffer ) : BOOLEAN; // returning false means 500 response
   VAR
      now : time.DateTime;
      s : StringsO.CString;
   BEGIN
      now.SetNowUTC();
   
      IF ContentType.Empty THEN
         HttpTools.FormatContentOA( HttpTools.contentTextPlain, L"", L"utf-8", FALSE, OUT ContentType );
      END;
      Response.ContentType := ContentType;
      Response.AllowCaching := FALSE;
      Response.LastModified := now;

      IF DispositionFlag THEN
         s.FromOA( L"attachment; filename=" );
         s.Append( Name );
         Response.ResponseHeaders^.AddUnknownOA( L"Content-Disposition", OA( s.Length-1, s.rawData ));
      END;

      LanguagesO.ToMB( Text, Languages.cp_UTF8, FALSE, REF Output );
      RETURN TRUE;
   END FormatToBuffer;

(*--------------------------------------------------------------------------------*)

   PUBLIC VIRTUAL PROCEDURE FormatToInputStream( CONST Request : MVC.IHttpRequest; REF Response : MVC.IHttpResponse; OUT InputStream : IOO.TPStream ) : BOOLEAN; // returning false means 500 response, Stream MUST be DISPOSED after usage
   BEGIN
      ASSERTLOG( FALSE );
      RETURN FALSE;
   END FormatToInputStream;

(*--------------------------------------------------------------------------------*)

   PUBLIC VIRTUAL PROCEDURE FormatToOutputStream( CONST Request : MVC.IHttpRequest; REF Response : MVC.IHttpResponse; OutputStream : IOO.TPStream ) : BOOLEAN; // returning false means 500 response
   BEGIN
      ASSERTLOG( FALSE );
      RETURN FALSE;
   END FormatToOutputStream;

(*--------------------------------------------------------------------------------*)

   PUBLIC VIRTUAL PROCEDURE Release();
   VAR
      a : TPRawTextView := ADR( SELF );
   BEGIN
      DISPOSE( a );
   END Release;

(*--------------------------------------------------------------------------------*)

   PUBLIC PROCEDURE Init( CONST text, name : ARRAY OF WCHAR; CONST content : StringsO.IString; dispositionFlag : BOOLEAN );
   BEGIN
      Text.FromOA( text );
      Name.FromOA( name );
      ContentType.Assign( content );
      DispositionFlag := dispositionFlag;
   END Init;
   
(*--------------------------------------------------------------------------------*)

BEGIN
   DispositionFlag := FALSE;
END CRawTextView;

(*================================================================================*)

CONST
   PT_XMLNS = L"xmlns";
   PT_NAMESPACE = L"http://www.smartcontrol.cz/2008/XML/Web/PageTemplate";
   PT_ROOTNAME = L"pagetemplate";
      PT_CONDITION = L"condition";
   PT_CHOOSE = L"choose";
      PT_WHEN = L"when";
      PT_OTHERWISE = L"otherwise";
   PT_FOR = L"for";
      PT_FROM = L"from";
      PT_TO = L"to";
      PT_BY = L"by";
      PT_INDEX = L"index";
      PT_ORDER = L"order";
      PT_ODD = L"odd";
   PT_FOREACH = L"foreach";
      PT_SOURCE = L"source";
      PT_ITEM = L"item";
   PT_FORM = L"form";
      PT_MODEL = L"model";
      PT_TEXT = L"text";
      PT_NAME = L"name";
      PT_FORMID = L"formid";
      PT_FORM_INPUT = L"input";
      PT_FORM_FILE = L"file";
      PT_FORM_CHECKBOX = L"checkbox";
      PT_FORM_RADIOBUTTON = L"radiobutton"; // pt:
      PT_FORM_RADIO = L"radio"; // html:
      PT_FORM_PASSWORD = L"password";
      PT_FORM_SELECT = L"select";
      PT_FORM_OPTION = L"option";
         PT_FORM_OPTION_SELECTED = L"selected";
      PT_FORM_TEXTAREA = L"textarea";
      PT_FORM_HIDDEN = L"hidden";
      PT_FORM_ERRORS = L"errors";

CLASS IMPLEMENTATION CPageTemplateView;

(*--------------------------------------------------------------------------------*)

   PUBLIC PROPERTY OutputType GET : MVC.TViewOutputType;
   BEGIN
      RETURN MVC.votBuffer;
   END OutputType;

(*--------------------------------------------------------------------------------*)

   PUBLIC VIRTUAL PROCEDURE FormatToBuffer( CONST Request : MVC.IHttpRequest; REF Response : MVC.IHttpResponse; OUT Output : StorageO.CMemoryBuffer ) : BOOLEAN; // returning false means 500 response
   LABEL
      Failure;
   VAR
      Content : StringsO.CString;
      empty : StringsO.CString;
      fs : FIOO.CFileStream;
      mbs : IOO.CMemoryBufferStream;
      now : time.DateTime;
      viewPath : StringsO.CString;
   BEGIN
      now.SetNowUTC();

      Response.ModelContainer^.ResetModelInViewNames( Request.ControllerURI );
      HttpTools.FormatContentOA( HttpTools.contentTextHTML, L"", L"utf-8", FALSE, OUT Content );
      Response.AllowCaching := FALSE;
      Response.LastModified := now;
      Response.ContentType := Content;

      IF Resolver = NIL THEN
         viewPath := ViewName;
      ELSIF NOT Resolver^.ResolvePath( 0, OA( ViewName.Length-1, ViewName.rawData ), OUT viewPath ) THEN
         SetError( empty, ADR( ViewName ), L"Unable to resolve view name." );
         GOTO Failure;
      END;
      SELF.Request := MVC.TPHttpRequest( ADR( Request ));

      TRY
         fs.FromPath( OA( viewPath.Length-1, viewPath.rawData ), FIOO.imOpenRead );
      CATCH e : IOO.CIOException DO
         SetError( empty, ADR( viewPath ), L"Unable to find or open view page template file." );
         GOTO Failure;
      END;
      Reader.Stream := ADR( fs );

      CurrentViewNameIndex := 1;
      mbs.Init( REF Output, IOO.accWrite );
      Writer.Stream := ADR( mbs );
      IF NOT ParseRoot() THEN
         GOTO Failure;
      END;
      Writer.Close( FALSE ); 
      RETURN TRUE;
      
   Failure:
      Output.Clear();
      mbs.Init( REF Output, IOO.accWrite );
      Writer.Stream := ADR( mbs );
      FormatError();
      Writer.Close( FALSE ); 
      RETURN TRUE;
   END FormatToBuffer;

(*--------------------------------------------------------------------------------*)

   PUBLIC VIRTUAL PROCEDURE FormatToInputStream( CONST Request : MVC.IHttpRequest; REF Response : MVC.IHttpResponse; OUT InputStream : IOO.TPStream ) : BOOLEAN; // returning false means 500 response, Stream MUST be DISPOSED after usage
   BEGIN
      ASSERTLOG( FALSE );
      RETURN FALSE;
   END FormatToInputStream;

(*--------------------------------------------------------------------------------*)

   PUBLIC VIRTUAL PROCEDURE FormatToOutputStream( CONST Request : MVC.IHttpRequest; REF Response : MVC.IHttpResponse; OutputStream : IOO.TPStream ) : BOOLEAN; // returning false means 500 response
   BEGIN
      ASSERTLOG( FALSE );
      RETURN FALSE;
   END FormatToOutputStream;

(*--------------------------------------------------------------------------------*)

   PUBLIC VIRTUAL PROCEDURE Release();
   VAR
      a : TPPageTemplateView := ADR( SELF );
   BEGIN
      DISPOSE( a );
   END Release;

(*--------------------------------------------------------------------------------*)

   PUBLIC PROCEDURE Init( CONST Resolver : FSO.TPFilePathResolver; CONST ViewName : ARRAY OF WCHAR );
   BEGIN
      SELF.Resolver := Resolver;
      SELF.ViewName.FromOA( ViewName );
   END Init;
   
(*--------------------------------------------------------------------------------*)

   PRIVATE PROCEDURE ParseRoot() : BOOLEAN;
   VAR
      rootName : StringsO.CString;
      xmle : xmlreader.TXMLError;
   BEGIN
      xmle := Reader.MoveNext();
      LOOP
         IF xmle = xmlreader.xmle_S_FALSE THEN
            RETURN TRUE;
         ELSIF xmle = xmlreader.xmle_PARSER_NOT_CREATED THEN
            SetError( rootName, NIL, L"Parser not created, maybe xmllite.dll is missing." );
            RETURN FALSE;
         ELSIF xmle <> xmlreader.xmle_S_OK THEN
            SetError( rootName, NIL, L"Error in template." );
            RETURN FALSE;
         END;
         
         CASE Reader.CurrentType OF
         | xmlreader.xntText :
            ASSERTLOG( FALSE ); // should not occur here

         | xmlreader.xntElementBegin :
            rootName := Reader.CurrentName;
            IF NOT rootName.EqualsIgnoreCaseOA( PT_ROOTNAME ) THEN
               SetError( rootName, NIL, L"Bad root name." );
               RETURN FALSE;
            ELSIF Reader.MoveToFirstAttribute() <> xmlreader.xmle_S_OK THEN
               SetError( rootName, NIL, L'"xmlns" attribute(s) not found.' );
               RETURN FALSE; // at least single attribute with xmlns:... must be present
            END;
            
            Prefix.Clear();
            REPEAT
               IF Reader.CurrentType <> xmlreader.xntAttribute THEN
                  ASSERTLOG( FALSE ); // should not occur here
                  CONTINUE;
               ELSIF Reader.CurrentPrefix.EqualsIgnoreCaseOA( PT_XMLNS ) AND Reader.CurrentValue.EqualsIgnoreCaseOA( PT_NAMESPACE ) THEN
                  Prefix := Reader.CurrentName;
               END;
            UNTIL Reader.MoveToNextAttribute() <> xmlreader.xmle_S_OK;
            
            IF Prefix.Empty THEN
               SetError( rootName, NIL, L"Page template namespace declaration not found." );
               RETURN FALSE;
            END;
            PrefixCondition := Prefix;
            PrefixCondition.AppendOA( L":" );
            PrefixCondition.AppendOA( PT_CONDITION );
            
            IF NOT Reader.CurrentEmpty THEN
               RETURN Parse( TRUE, FALSE, FALSE );
            END;

         | xmlreader.xntAttribute :
            ASSERTLOG( FALSE ); // should not occur here
         END; // CASE

         xmle := Reader.MoveNext();
      END; // WHILE
   END ParseRoot;

(*--------------------------------------------------------------------------------*)

   PRIVATE PROCEDURE Parse( emit, limitToPTOnly, balanced : BOOLEAN ) : BOOLEAN;
   VAR
      attributes : lists.CStringStringList;
      depth : INTEGER := 0;
      nodeName : StringsO.CString;
      nodePrefix : StringsO.CString;
      nodeType : xmlreader.TNodeType;
      nodeValue : StringsO.CString;
      isEmpty : BOOLEAN;
      value : StringsO.CString;
   BEGIN
      LOOP
         CASE MoveNext( OUT nodeType, OUT nodePrefix, OUT nodeName, OUT isEmpty, OUT nodeValue, OUT attributes ) OF
         | xmlreader.xmle_S_OK :
            // continue
         | xmlreader.xmle_S_FALSE :
            RETURN TRUE;
         ELSE
            nodeName.Clear();
            SetError( nodeName, NIL, L"Unexpected end of source." );
            RETURN FALSE;
         END;
        
         IF nodeType = xmlreader.xntElementBegin THEN
            INC( depth );
         ELSIF nodeType = xmlreader.xntElementEnd THEN
            IF depth = 0 THEN
               RETURN TRUE;
            END;
            DEC( depth );
         END;
         IF NOT emit THEN
            CONTINUE;
         END;

         CASE nodeType OF
         | xmlreader.xntText :
            IF limitToPTOnly THEN
               RETURN FALSE;
            ELSE
               ParseText( nodeValue, OUT value );
               Writer.WriteUnescapedString( value );
            END;

         | xmlreader.xntElementBegin :
            CASE HandleElementStart( isEmpty, nodePrefix.EqualsIgnoreCase( Prefix ), limitToPTOnly, nodeName, attributes ) OF
            | esaError :
               RETURN FALSE;
            | esaUnprocessedPT :
               SetError( nodeName, NIL, L"Unknown of forbidden page template element." );
               RETURN FALSE;
            | esaProcessedInDeep :
               // OK, but element has consumed self end, so I must not expect it, decrement depth
               DEC( depth );
            // ELSE continue
            END;

         | xmlreader.xntElementEnd :
            Writer.WriteElementEnd(); // writer does it itself
            
            IF balanced AND ( depth = 0 ) THEN
               RETURN TRUE;
            END;

         END; // CASE

      END; // WHILE
   END Parse;

(*--------------------------------------------------------------------------------*)

   PRIVATE PROCEDURE HandleElementStart( isEmpty, ptFlag, limitToPTOnly : BOOLEAN; CONST nodeName : StringsO.CString; CONST attributes : lists.CStringStringList ) : TElementStartAction;
   VAR
      b : BOOLEAN;
      condition : StringsO.CString;
      empty : StringsO.CString;
      pname : StringsO.TPString;
      ptype : POINTER TO CONST WCHAR;
      simpleInput : BOOLEAN;
   BEGIN
      // look for condition
      attributes.Reset();
      WHILE attributes.MoveNext() DO
         pname := StringsO.TPString( attributes.Current );
         IF ptFlag AND pname^.EqualsIgnoreCaseOA( PT_CONDITION ) OR pname^.EqualsIgnoreCase( PrefixCondition ) THEN
            ParseText( attributes.CurrentData^, OUT condition );
            IF NOT EvaluateBoolean( condition ) THEN
               IF isEmpty OR Parse( FALSE, limitToPTOnly, FALSE ) THEN
                  RETURN esaProcessedInDeep;
               ELSE
                  RETURN esaError;
               END;
            END;
         END;
      END; // WHILE
      
      IF ptFlag THEN // Page Template element
         b := FALSE;
         IF nodeName.EqualsIgnoreCaseOA( PT_CHOOSE ) THEN
            b := ParseChoose();
         ELSIF nodeName.EqualsIgnoreCaseOA( PT_FOR ) THEN
            b := ParseFor( attributes );
         ELSIF nodeName.EqualsIgnoreCaseOA( PT_FOREACH ) THEN
            b := ParseForeach( attributes );
         ELSIF TWhere{whInInput, whInOption} * Where <> TWhere{} THEN
            SetError( nodeName, NIL, L'Element is not allowed inside "pt:input" or "pt:option" context.' );
            b := FALSE;
         ELSIF nodeName.EqualsIgnoreCaseOA( PT_FORM ) THEN
            IF whInForm IN Where THEN
               SetError( nodeName, NIL, L'Element is not allowed inside "pt:form" context.' );
               b := FALSE;
            ELSE
               INCL( Where, whInForm );
               b := ParseForm( isEmpty, attributes );
               EXCL( Where, whInForm );
            END;
         ELSIF whInSelect IN Where THEN
            IF nodeName.EqualsIgnoreCaseOA( PT_FORM_OPTION ) THEN
               INCL( Where, whInOption );
               b := ParseFormOption( isEmpty, attributes );
               EXCL( Where, whInOption );
            END;
         ELSIF whInForm IN Where THEN
            simpleInput := TRUE;
            IF nodeName.EqualsIgnoreCaseOA( PT_FORM_INPUT ) THEN
               ptype := ADR( PT_TEXT );
            ELSIF nodeName.EqualsIgnoreCaseOA( PT_FORM_FILE ) THEN
               ptype := ADR( PT_FORM_FILE );
            ELSIF nodeName.EqualsIgnoreCaseOA( PT_FORM_CHECKBOX ) THEN
               ptype := ADR( PT_FORM_CHECKBOX );
            ELSIF nodeName.EqualsIgnoreCaseOA( PT_FORM_RADIOBUTTON ) THEN
               ptype := ADR( PT_FORM_RADIO );
            ELSIF nodeName.EqualsIgnoreCaseOA( PT_FORM_PASSWORD ) THEN
               ptype := ADR( PT_FORM_PASSWORD );
            ELSIF nodeName.EqualsIgnoreCaseOA( PT_FORM_TEXTAREA ) THEN
               ptype := ADR( PT_FORM_TEXTAREA );
            ELSIF nodeName.EqualsIgnoreCaseOA( PT_FORM_HIDDEN ) THEN
               ptype := ADR( PT_FORM_HIDDEN );
            ELSE
               simpleInput := FALSE;
            END;
            IF simpleInput THEN
               INCL( Where, whInInput );
               b := ParseFormInput( isEmpty, attributes, ptype );
               EXCL( Where, whInInput );
            ELSIF nodeName.EqualsIgnoreCaseOA( PT_FORMID ) THEN
               INCL( Where, whInInput );
               b := ParseFormId( isEmpty, attributes );
               EXCL( Where, whInInput );
            ELSIF nodeName.EqualsIgnoreCaseOA( PT_FORM_SELECT ) THEN
               IF whInSelect IN Where THEN
                  SetError( nodeName, NIL, L'Element is not allowed inside "pt:select" context.' );
                  b := FALSE;
               ELSE
                  INCL( Where, whInSelect );
                  b := ParseFormSelect( isEmpty, attributes );
                  EXCL( Where, whInSelect );
               END;
            ELSIF nodeName.EqualsIgnoreCaseOA( PT_FORM_ERRORS ) THEN
               SetError( nodeName, NIL, L'pt:errors is not supported yet.' );
               b := FALSE;
            ELSE
               SetError( nodeName, NIL, L'Unsupported page template element.' );
               b := FALSE;
            END;
         ELSE
            RETURN esaUnprocessedPT;
         END;
         IF b THEN
            RETURN esaProcessedInDeep;
         ELSE
            RETURN esaError;
         END;

      ELSIF limitToPTOnly THEN
         SetError( nodeName, NIL, L"Forbidden element in the context." );
         RETURN esaError;
      
      ELSE // another element
         Writer.WriteElementStartOA( OA( nodeName.Length-1, nodeName.rawData ));
         CopyAttributes( ptFlag, attributes, PT_CONDITION, L"" );
         IF isEmpty THEN
            Writer.WriteElementEnd();
            RETURN esaProcessedInDeep;
         ELSE
            Writer.WriteString( empty ); // terminate attributes forcibly
            RETURN esaProcessedHeader;
         END;

      END;
   END HandleElementStart;

(*--------------------------------------------------------------------------------*)

   PRIVATE PROCEDURE ParseElement( CONST attributes : lists.CStringStringList; isEmpty, limitToPTOnly : BOOLEAN; CONST ignoreOA1, ignoreOA2 : ARRAY OF WCHAR ) : BOOLEAN;
   BEGIN
      CopyAttributes( TRUE, attributes, ignoreOA1, ignoreOA2 );
      IF isEmpty THEN
         Writer.WriteElementEnd();
      ELSIF Parse( TRUE, limitToPTOnly, FALSE ) THEN // input can contain text
         Writer.WriteElementEnd();
      ELSE
         RETURN FALSE;
      END;
      RETURN TRUE;
   END ParseElement;

(*--------------------------------------------------------------------------------*)

   PRIVATE PROCEDURE ParseChoose() : BOOLEAN;
   VAR
      attributes : lists.CStringStringList;
      condition : StringsO.CString;
      done : BOOLEAN := FALSE;
      emit : TRISTATE;
      haveOtherwise : BOOLEAN := FALSE;
      isEmpty : BOOLEAN;
      nodeName : StringsO.CString;
      nodePrefix : StringsO.CString;
      nodeType : xmlreader.TNodeType;
      nodeValue : StringsO.CString;
      pname : StringsO.TPString;
   BEGIN
      LOOP
         CASE MoveNext( OUT nodeType, OUT nodePrefix, OUT nodeName, OUT isEmpty, OUT nodeValue, OUT attributes ) OF
         | xmlreader.xmle_S_OK :
            // continue
         | xmlreader.xmle_S_FALSE :
            RETURN TRUE;
         ELSE
            nodeName.Clear();
            SetError( nodeName, NIL, L"Unexpected end of source." );
            RETURN FALSE;
         END;

         IF nodeType = xmlreader.xntElementBegin THEN
            // ok, follow to processing
         ELSIF nodeType = xmlreader.xntElementEnd THEN // other ends are consumed inside
            RETURN TRUE;
         ELSE
            SetError( nodeName, NIL, L"Forbidden content in pt:case context." );
            RETURN FALSE; // nothing other we do not expect
         END;
         
         IF nodeType = xmlreader.xntElementBegin THEN
            IF NOT nodePrefix.EqualsIgnoreCase( Prefix ) THEN
               SetError( nodeName, NIL, L"Forbidden element in pt:case context." );
               RETURN FALSE;

            ELSIF nodeName.EqualsIgnoreCaseOA( PT_WHEN ) THEN

               IF done THEN
                  emit := 0;
               ELSE // look for condition
                  emit := -1;
                  attributes.Reset();
                  WHILE attributes.MoveNext() DO
                     pname := attributes.Current;
                     IF pname^.EqualsIgnoreCaseOA( PT_CONDITION ) OR pname^.EqualsIgnoreCase( PrefixCondition ) THEN
                        ParseText( attributes.CurrentData^, OUT condition );
                        IF EvaluateBoolean( condition ) THEN
                           emit := 1;
                        ELSE
                           emit := 0;
                        END;
                     END;
                  END; // WHILE
                  IF emit = -1 THEN
                     SetError( nodeName, NIL, L"pt:condition attribute is required." );
                     RETURN FALSE; // condition is required
                  ELSIF emit = 1 THEN
                     done := TRUE;
                  END;
               END;
               
               IF isEmpty OR Parse( emit = 1, FALSE, FALSE ) THEN
                  // continue
               ELSE
                  RETURN FALSE;
               END;
            
            ELSIF nodeName.EqualsIgnoreCaseOA( PT_OTHERWISE ) THEN
               IF haveOtherwise THEN
                  SetError( nodeName, NIL, L"Duplicite pt:otherwise." );
                  RETURN FALSE;
               END;
               haveOtherwise := TRUE;

               IF isEmpty OR Parse( NOT done, FALSE, FALSE ) THEN
                  // continue
               ELSE
                  RETURN FALSE;
               END;

            ELSE
               SetError( nodeName, NIL, L"Forbidden element in pt:case context." );
               RETURN FALSE; // nothing except when or otherwise is bad
            END;
         END;
         
      END; // WHILE
   END ParseChoose;

(*--------------------------------------------------------------------------------*)

   PRIVATE PROCEDURE ParseFor( CONST attributes : lists.CStringStringList ) : BOOLEAN;
   VAR
      attribute : StringsO.CString;
      by : INTEGER := 1;
      depth : INTEGER := 0;
      from : INTEGER;
      haveBy : BOOLEAN := FALSE;
      haveFrom : BOOLEAN := FALSE;
      haveTo : BOOLEAN := FALSE;
      i, iodd : INTEGER;
      index : StringsO.CString;
      inverted : BOOLEAN;
      isEmpty : BOOLEAN;
      lattributes : lists.CStringStringList;
      nl : NodeList.CNodeList;
      nodeName : StringsO.CString;
      nodePrefix : StringsO.CString;
      nodeType : xmlreader.TNodeType;
      nodeValue : StringsO.CString;
      odd : StringsO.CString;
      pname : StringsO.TPString;
      prefix : StringsO.CString;
      to : INTEGER;
      value : StringsO.CString;
   BEGIN
      prefix := Prefix;
      prefix.AppendOA( L":" );

      // first analyze attributes
      attributes.Reset();
      WHILE attributes.MoveNext() DO
         pname := StringsO.TPString( attributes.Current );

         attribute := prefix; attribute.AppendOA( PT_FROM );
         IF pname^.EqualsIgnoreCaseOA( PT_FROM ) OR pname^.EqualsIgnoreCase( attribute ) THEN
            ParseText( attributes.CurrentData^, OUT value );
            IF value.ToCARD32( 10, OUT from ) THEN
               haveFrom := TRUE;
            ELSE
               value.FromOA( L"pt:for" );
               SetError( value, NIL, L'Bad value of "from" attribute.' );
               RETURN FALSE;
            END;
            CONTINUE;
         END;
         
         attribute := prefix; attribute.AppendOA( PT_TO );
         IF pname^.EqualsIgnoreCaseOA( PT_TO ) OR pname^.EqualsIgnoreCase( attribute ) THEN
            ParseText( attributes.CurrentData^, OUT value );
            IF value.ToCARD32( 10, OUT to ) THEN
               haveTo := TRUE;
            ELSE
               value.FromOA( L"pt:for" );
               SetError( value, NIL, L'Bad value of "to" attribute.' );
               RETURN FALSE;
            END;
            CONTINUE;
         END;

         attribute := prefix; attribute.AppendOA( PT_BY );
         IF pname^.EqualsIgnoreCaseOA( PT_BY ) OR pname^.EqualsIgnoreCase( attribute ) THEN
            ParseText( attributes.CurrentData^, OUT value );
            IF value.ToCARD32( 10, OUT by ) THEN
               haveBy := TRUE;
            ELSE
               value.FromOA( L"pt:for" );
               SetError( nodeName, NIL, L'Bad value of "by" attribute.' );
               RETURN FALSE;
            END;
            CONTINUE;
         END;

         attribute := prefix; attribute.AppendOA( PT_INDEX );
         IF pname^.EqualsIgnoreCaseOA( PT_INDEX ) OR pname^.EqualsIgnoreCase( attribute ) THEN
            ParseText( attributes.CurrentData^, OUT index );
            CONTINUE;
         END;

         attribute := prefix; attribute.AppendOA( PT_ODD );
         IF pname^.EqualsIgnoreCaseOA( PT_ODD ) OR pname^.EqualsIgnoreCase( attribute ) THEN
            ParseText( attributes.CurrentData^, OUT odd );
            CONTINUE;
         END;

      END; // WHILE      
      
      IF NOT haveFrom THEN
         value.FromOA( L"pt:for" );
         SetError( nodeName, NIL, L'"from" attribute is missing.' );
         RETURN FALSE;
      ELSIF NOT haveTo THEN
         value.FromOA( L"pt:for" );
         SetError( nodeName, NIL, L'"to" attribute is missing.' );
         RETURN FALSE;
      ELSIF ( to < from ) AND ( by >= 0 ) THEN
         value.FromOA( L"pt:for" );
         SetError( nodeName, NIL, L'"to" is less than "from"' );
         RETURN FALSE;
      ELSIF ( to > from ) AND ( by <= 0 ) THEN
         value.FromOA( L"pt:for" );
         SetError( nodeName, NIL, L'"from" is less than "to"' );
         RETURN FALSE;
      END;
      
      // second buffer "for" content
      LOOP
         IF MoveNext( OUT nodeType, OUT nodePrefix, OUT nodeName, OUT isEmpty, OUT nodeValue, OUT lattributes ) <> xmlreader.xmle_S_OK THEN
            value.FromOA( L"pt:for" );
            SetError( nodeName, NIL, L'Unexpected end of buffered source.' );
            RETURN FALSE;
         END;
         IF nodeType = xmlreader.xntElementBegin THEN
            INC( depth );
         ELSIF nodeType = xmlreader.xntElementEnd THEN // other ends are consumed inside Parse
            IF depth = 0 THEN
               EXIT;
            END;
            DEC( depth );
         END;
         nl.Add( nodeType, nodePrefix, nodeName, isEmpty, nodeValue, REF lattributes );
      END; // WHILE
      
      // third switch sources and do "for"
      Sources.Push( ADR( nl ));
      inverted := from > to;
      i := from;
      iodd := 1;
      WHILE inverted AND ( i >= to ) OR NOT inverted AND ( i <= to ) DO
         IF NOT odd.Empty THEN
            SetModelBoolean( odd, iodd AND 1 = 1 );
         END;
         IF NOT index.Empty THEN
            value.FromCARD32( i, 10 );
            Request^.ModelContainer^.SetModelValue( index, value );
         END;
         nl.Reset(); // prepare parsing
         IF NOT Parse( TRUE, FALSE, TRUE ) THEN
            RETURN FALSE;
         END;
         INC( i, by );
         INC( iodd );
      END; // WHILE
      Sources.Pop();
      
      RETURN TRUE;
   END ParseFor;

(*--------------------------------------------------------------------------------*)

   PRIVATE PROCEDURE ParseForeach( CONST attributes : lists.CStringStringList ) : BOOLEAN;
   VAR
      attribute : StringsO.CString;
      depth : INTEGER := 0;
      haveSource : BOOLEAN := FALSE;
      haveList : BOOLEAN := FALSE;
      i : INTEGER;
      index : StringsO.CString;
      item : StringsO.CString;
      isEmpty : BOOLEAN;
      lattributes : lists.CStringStringList;
      list : lists.TPStringStringList;
      map : maps.TPStringStringMap;
      nl : NodeList.CNodeList;
      nodeName : StringsO.CString;
      nodePrefix : StringsO.CString;
      nodeType : xmlreader.TNodeType;
      nodeValue : StringsO.CString;
      odd : StringsO.CString;
      order : StringsO.CString;
      pname : StringsO.TPString;
      prefix : StringsO.CString;
      source : StringsO.CString;
      value : StringsO.CString;
   BEGIN
      prefix := Prefix;
      prefix.AppendOA( L":" );

      // first analyze attributes
      attributes.Reset();
      WHILE attributes.MoveNext() DO
         pname := StringsO.TPString( attributes.Current );

         attribute := prefix; attribute.AppendOA( PT_SOURCE );
         IF pname^.EqualsIgnoreCaseOA( PT_SOURCE ) OR pname^.EqualsIgnoreCase( attribute ) THEN
            ParseText( attributes.CurrentData^, OUT source );
            CONTINUE;
         END;
         
         attribute := prefix; attribute.AppendOA( PT_INDEX );
         IF pname^.EqualsIgnoreCaseOA( PT_INDEX ) OR pname^.EqualsIgnoreCase( attribute ) THEN
            ParseText( attributes.CurrentData^, OUT index );
            CONTINUE;
         END;

         attribute := prefix; attribute.AppendOA( PT_ORDER );
         IF pname^.EqualsIgnoreCaseOA( PT_ORDER ) OR pname^.EqualsIgnoreCase( attribute ) THEN
            ParseText( attributes.CurrentData^, OUT order );
            CONTINUE;
         END;

         attribute := prefix; attribute.AppendOA( PT_ITEM );
         IF pname^.EqualsIgnoreCaseOA( PT_ITEM ) OR pname^.EqualsIgnoreCase( attribute ) THEN
            ParseText( attributes.CurrentData^, OUT item );
            CONTINUE;
         END;

         attribute := prefix; attribute.AppendOA( PT_ODD );
         IF pname^.EqualsIgnoreCaseOA( PT_ODD ) OR pname^.EqualsIgnoreCase( attribute ) THEN
            ParseText( attributes.CurrentData^, OUT odd );
            CONTINUE;
         END;
      END; // WHILE
      
      // get list or map
      IF source.Empty THEN
         value.FromOA( L"pt:foreach" );
         SetError( value, NIL, L'Missing "source" attribute.' );
         RETURN FALSE;
      ELSIF Request^.ModelContainer^.GetListOA( OA( source.Length-1, source.rawData ), OUT list ) THEN
         haveList := TRUE;
      ELSIF Request^.ModelContainer^.GetMapOA( OA( source.Length-1, source.rawData ), OUT map ) THEN
         haveList := FALSE;
      ELSE
         value.FromOA( L"pt:foreach" );
         SetError( value, NIL, L'"source" attribute is not map either list.' );
         RETURN FALSE;
      END;

      // second buffer "for" content
      LOOP
         IF MoveNext( OUT nodeType, OUT nodePrefix, OUT nodeName, OUT isEmpty, OUT nodeValue, OUT lattributes ) <> xmlreader.xmle_S_OK THEN
            value.FromOA( L"pt:foreach" );
            SetError( value, NIL, L'Unexpected end of buffered source.' );
            RETURN FALSE;
         END;
         IF nodeType = xmlreader.xntElementBegin THEN
            INC( depth );
         ELSIF nodeType = xmlreader.xntElementEnd THEN // other ends are consumed inside Parse
            IF depth = 0 THEN
               EXIT;
            END;
            DEC( depth );
         END;
         nl.Add( nodeType, nodePrefix, nodeName, isEmpty, nodeValue, REF lattributes );
      END; // WHILE
      
      // third switch sources and do "for"
      Sources.Push( ADR( nl ));
      i := 1;
      IF haveList THEN
         list^.Reset();
         WHILE list^.MoveNext() DO
            IF NOT item.Empty THEN
               Request^.ModelContainer^.SetModelValue( item, list^.Current^ );
            END;
            IF NOT odd.Empty THEN
               SetModelBoolean( odd, i AND 1 = 1 );
            END;
            IF NOT index.Empty THEN
               value.FromCARD32( i-1, 10 );
               Request^.ModelContainer^.SetModelValue( index, value );
               INC( i );
            END;
            IF NOT order.Empty THEN
               value.FromCARD32( i, 10 );
               Request^.ModelContainer^.SetModelValue( order, value );
               INC( i );
            END;
            nl.Reset(); // prepare parsing
            IF NOT Parse( TRUE, FALSE, TRUE ) THEN
               RETURN FALSE;
            END;
         END; // WHILE
      ELSE
         map^.Reset();
         WHILE map^.MoveNext() DO
            IF NOT item.Empty THEN
               Request^.ModelContainer^.SetModelValue( item, map^.Current^ );
            END;
            IF NOT odd.Empty THEN
               SetModelBoolean( odd, i AND 1 = 1 );
            END;
            IF NOT index.Empty THEN
               value.FromCARD32( i, 10 );
               Request^.ModelContainer^.SetModelValue( index, value );
               INC( i );
            END;
            nl.Reset(); // prepare parsing
            IF NOT Parse( TRUE, FALSE, TRUE ) THEN
               RETURN FALSE;
            END;
         END; // WHILE
      END;
      Sources.Pop();
      
      RETURN TRUE;
   END ParseForeach;

(*--------------------------------------------------------------------------------*)

   PRIVATE PROCEDURE ParseForm( isEmpty : BOOLEAN; CONST attributes : lists.CStringStringList ) : BOOLEAN;
   VAR
      s : StringsO.CString;
   BEGIN
      IF NOT GetFormModel( attributes, OUT FormModel ) THEN
         FormModel.Clear();
      END;

      Writer.WriteElementStartOA( L"form" );

      s := Request^.ControllerURI;
      Writer.WriteAttributeStringOA( L"action", OA( s.Length-1, s.rawData ));

      RETURN ParseElement( attributes, isEmpty, FALSE, PT_MODEL, L"" );
   END ParseForm;

(*--------------------------------------------------------------------------------*)

   PRIVATE PROCEDURE ParseFormId( isEmpty : BOOLEAN; CONST attributes : lists.CStringStringList ) : BOOLEAN;
   VAR
      fullModel : StringsO.CString;
      id : StringsO.CString;
      model : StringsO.CString;
      value : StringsO.CString;
   BEGIN
      IF NOT GetFormModel( attributes, OUT model ) THEN
         value.FromOA( L"pt:formid" );
         SetError( value, NIL, L'Required "model" attribute is missing.' );
         RETURN FALSE;
      END;
      fullModel := FormModel;
      IF NOT fullModel.Empty THEN
         fullModel.AppendOA( L"." );
         fullModel.Append( model );
      END;

      IF NOT GetFormId( attributes, OUT id ) THEN
         value.FromOA( L"pt:formid" );
         SetError( value, NIL, L'Required "formid" attribute is missing.' );
         RETURN FALSE;
      END;

      Writer.WriteElementStartOA( L"input" );

      Writer.WriteAttributeStringOA( L"type", PT_FORM_HIDDEN );
      IF NOT fullModel.Empty THEN // model = form.item
         WriteFormNameAttribute( fullModel );
         Writer.WriteAttributeStringOA( L"value", OA( id.Length-1, id.rawData ));
      ELSE
         WriteFormNameAttribute( model );
         Writer.WriteAttributeStringOA( L"value", OA( id.Length-1, id.rawData ));
      END;

      RETURN ParseElement( attributes, isEmpty, FALSE, PT_MODEL, PT_FORMID );
   END ParseFormId;

(*--------------------------------------------------------------------------------*)

   PRIVATE PROCEDURE ParseFormInput( isEmpty : BOOLEAN; CONST attributes : lists.CStringStringList; ptype : POINTER TO CONST WCHAR ) : BOOLEAN;
   VAR
      fullModel : StringsO.CString;
      model : StringsO.CString;
      value : StringsO.CString;
   BEGIN
      IF NOT GetFormModel( attributes, OUT model ) THEN
         value.FromOA( L"pt:input" );
         SetError( value, NIL, L'Required "model" attribute is missing.' );
         RETURN FALSE;
      END;
      fullModel := FormModel;
      IF NOT fullModel.Empty THEN
         fullModel.AppendOA( L"." );
         fullModel.Append( model );
      END;

      Writer.WriteElementStartOA( L"input" );

      Writer.WriteAttributeStringOA( L"type", OAsz( ptype ));
      IF NOT fullModel.Empty AND Request^.ModelContainer^.GetModelValue( fullModel, OUT value ) THEN // model = form.item
         WriteFormNameAttribute( fullModel );
         Writer.WriteAttributeStringOA( L"value", OA( value.Length-1, value.rawData ));
      ELSIF Request^.ModelContainer^.GetModelValue( model, OUT value ) THEN // model = item
         WriteFormNameAttribute( model );
         Writer.WriteAttributeStringOA( L"value", OA( value.Length-1, value.rawData ));
      ELSE
         SetError( model, NIL, L'Model for element is unknown.' );
         RETURN FALSE;
      END;

      RETURN ParseElement( attributes, isEmpty, FALSE, PT_MODEL, L"" );
   END ParseFormInput;

(*--------------------------------------------------------------------------------*)

   PRIVATE PROCEDURE ParseFormSelect( isEmpty : BOOLEAN; CONST attributes : lists.CStringStringList ) : BOOLEAN;
   VAR
      model : StringsO.CString;
      value : StringsO.CString;
   BEGIN
      IF NOT GetFormModel( attributes, OUT model ) THEN
         value.FromOA( L"pt:form" );
         SetError( value, NIL, L'Required "model" attribute is missing.' );
         RETURN FALSE;
      END;

      Writer.WriteElementStartOA( L"select" );
      WriteFormNameAttribute( model );

      RETURN ParseElement( attributes, isEmpty, TRUE, PT_MODEL, L"" );
   END ParseFormSelect;

(*--------------------------------------------------------------------------------*)

   PRIVATE PROCEDURE ParseFormOption( isEmpty : BOOLEAN; CONST attributes : lists.CStringStringList ) : BOOLEAN;
   VAR
      attribute : StringsO.CString;
      fullModel : StringsO.CString;
      fullSelectedModel : StringsO.CString;
      model : StringsO.CString;
      pname : StringsO.TPString;
      selectedModel : StringsO.CString;
      value : StringsO.CString;
   BEGIN
      IF NOT GetFormModel( attributes, OUT model ) THEN
         value.FromOA( L"pt:form" );
         SetError( value, NIL, L'Required "model" attribute is missing.' );
         RETURN FALSE;
      END;
      fullModel := FormModel;
      IF NOT fullModel.Empty THEN
         fullModel.AppendOA( L"." );
         fullModel.Append( model );
      END;

      attribute := Prefix;
      attribute.AppendOA( L":" );
      attribute.AppendOA( PT_FORM_OPTION_SELECTED );
      attributes.Reset();
      WHILE attributes.MoveNext() DO
         pname := StringsO.TPString( attributes.Current );
         IF pname^.EqualsIgnoreCaseOA( PT_FORM_OPTION_SELECTED ) OR pname^.EqualsIgnoreCase( attribute ) THEN
            ParseText( attributes.CurrentData^, OUT selectedModel );
         END;
      END; // WHILE
      IF NOT selectedModel.Empty AND NOT FormModel.Empty THEN
         fullSelectedModel := FormModel;
         fullSelectedModel.AppendOA( L"." );
         fullSelectedModel.Append( model );
      END;

      Writer.WriteElementStartOA( L"option" );

      IF NOT fullModel.Empty AND Request^.ModelContainer^.GetModelValue( fullModel, OUT value ) THEN // model = form.item
         Writer.WriteAttributeStringOA( L"value", OA( value.Length-1, value.rawData ));
      ELSIF Request^.ModelContainer^.GetModelValue( model, OUT value ) THEN // model = item
         Writer.WriteAttributeStringOA( L"value", OA( value.Length-1, value.rawData ));
      ELSE
         SetError( model, NIL, L'Model for element is unknown.' );
         RETURN FALSE;
      END;
      IF NOT selectedModel.Empty AND EvaluateBoolean( selectedModel ) OR
         NOT fullSelectedModel.Empty AND EvaluateBoolean( fullSelectedModel ) THEN
         Writer.WriteAttributeStringOA( L"selected", L"selected" );
      END;

      RETURN ParseElement( attributes, isEmpty, FALSE, PT_MODEL, PT_FORM_OPTION_SELECTED );
   END ParseFormOption;

(*--------------------------------------------------------------------------------*)

   PRIVATE PROCEDURE ParseText( CONST Text : StringsO.IString; OUT Parsed : StringsO.IString );
   BEGIN
      // TODO: react to error
      Request^.ModelContainer^.Format( FALSE, Text, Request^.MessageSource, Request^.Language, OUT Parsed );
   END ParseText;

(*--------------------------------------------------------------------------------*)

   PRIVATE PROCEDURE GetFormModel( CONST attributes : lists.CStringStringList; OUT formModel : StringsO.IString ) : BOOLEAN;
   VAR
      attribute : StringsO.CString;
      pname : StringsO.TPString;
   BEGIN
      attribute := Prefix;
      attribute.AppendOA( L":" );
      attribute.AppendOA( PT_MODEL );

      attributes.Reset();
      WHILE attributes.MoveNext() DO
         pname := StringsO.TPString( attributes.Current );
         IF pname^.EqualsIgnoreCaseOA( PT_MODEL ) OR pname^.EqualsIgnoreCase( attribute ) THEN
            ParseText( attributes.CurrentData^, OUT formModel );
         END;
      END; // WHILE

      RETURN NOT formModel.Empty;
   END GetFormModel;

(*--------------------------------------------------------------------------------*)

   PRIVATE PROCEDURE GetFormId( CONST attributes : lists.CStringStringList; OUT formId : StringsO.IString ) : BOOLEAN;
   VAR
      attribute : StringsO.CString;
      pname : StringsO.TPString;
   BEGIN
      attribute := Prefix;
      attribute.AppendOA( L":" );
      attribute.AppendOA( PT_FORMID );

      attributes.Reset();
      WHILE attributes.MoveNext() DO
         pname := StringsO.TPString( attributes.Current );
         IF pname^.EqualsIgnoreCaseOA( PT_FORMID ) OR pname^.EqualsIgnoreCase( attribute ) THEN
            ParseText( attributes.CurrentData^, OUT formId );
         END;
      END; // WHILE

      RETURN NOT formId.Empty;
   END GetFormId;

(*--------------------------------------------------------------------------------*)

   PRIVATE PROCEDURE MoveNext( OUT nodeType : xmlreader.TNodeType; OUT nodePrefix : StringsO.IString; OUT nodeName : StringsO.IString; OUT empty : BOOLEAN; OUT nodeValue : StringsO.IString; OUT attributes : lists.CStringStringList ) : xmlreader.TXMLError;
   VAR
      al : lists.TPStringStringList;
      nl : NodeList.TPNodeList;
      nli : NodeList.TPNodeItem;
      xmle : xmlreader.TXMLError;
   BEGIN
      IF Sources.Empty THEN
         LOOP
            xmle := Reader.MoveNext();
            IF xmle <> xmlreader.xmle_S_OK THEN
               RETURN xmle;
            END;

            nodeType := Reader.CurrentType;
            CASE nodeType OF
            | xmlreader.xntText :
               nodeValue.Assign( Reader.CurrentValue );
               RETURN xmlreader.xmle_S_OK;

            | xmlreader.xntElementBegin :
               nodePrefix.Assign( Reader.CurrentPrefix );
               nodeName.Assign( Reader.CurrentName );
               empty := Reader.CurrentEmpty;

               // get attributes
               attributes.Dispose();
               IF Reader.MoveToFirstAttribute() = xmlreader.xmle_S_OK THEN
                  REPEAT
                     IF Reader.CurrentType <> xmlreader.xntAttribute THEN
                        ASSERTLOG( FALSE ); // should not occur here
                        CONTINUE;
                     END;
                     attributes.Add( Reader.CurrentQualifiedName, Reader.CurrentValue );
                  UNTIL Reader.MoveToNextAttribute() <> xmlreader.xmle_S_OK;
               END;
               RETURN xmlreader.xmle_S_OK;

            | xmlreader.xntElementEnd :
               nodePrefix.Assign( Reader.CurrentPrefix );
               nodeName.Assign( Reader.CurrentName );
               RETURN xmlreader.xmle_S_OK;

            END; // CASE
         END; // LOOP

      ELSE
         nl := NodeList.TPNodeList( Sources.Peek());
         IF NOT nl^.MoveNext() THEN
            ASSERTLOG( FALSE );
            RETURN xmlreader.xmle_S_FALSE; // should not occur
         END;
         
         nli := nl^.Current;
         nodeType := nli^.Type;
         nodePrefix.Assign( nli^.Prefix^ );
         nodeName.Assign( nli^.Name^ );
         empty := nli^.Empty;
         nodeValue.Assign( nli^.Value^ );

         attributes.Dispose();
         al := nli^.Attributes;
         IF al <> NIL THEN
            al^.Reset();
            WHILE al^.MoveNext() DO
               attributes.Add( al^.Current^, al^.CurrentData^ );
            END; // WHILE
         END; // IF al <> NIL
         
         RETURN xmlreader.xmle_S_OK;
      END;
   END MoveNext;

(*--------------------------------------------------------------------------------*)

   PRIVATE PROCEDURE CopyAttributes( ptFlag : BOOLEAN; CONST attributes : lists.CStringStringList; CONST ignoreOA1, ignoreOA2 : ARRAY OF WCHAR );
   VAR
      ignore1 : StringsO.CString;
      ignore2 : StringsO.CString;
      pname : StringsO.TPString;
      value : StringsO.CString;
   BEGIN
      ignore1 := Prefix;
      ignore1.AppendOA( L":" );
      ignore1.AppendOA( ignoreOA1 );

      ignore2 := Prefix;
      ignore2.AppendOA( L":" );
      ignore2.AppendOA( ignoreOA2 );

      attributes.Reset();
      WHILE attributes.MoveNext() DO
         pname := StringsO.TPString( attributes.Current );
         IF ptFlag AND pname^.EqualsIgnoreCaseOA( ignoreOA1 ) OR pname^.EqualsIgnoreCase( ignore1 ) THEN
            CONTINUE; // ignore pt:ignore
         ELSIF ignoreOA2[0] = 0W THEN
            // fall down
         ELSIF ptFlag AND pname^.EqualsIgnoreCaseOA( ignoreOA2 ) OR pname^.EqualsIgnoreCase( ignore2 ) THEN
            CONTINUE; // ignore pt:ignore
         END;
         ParseText( attributes.CurrentData^, OUT value );
         Writer.WriteAttributeStringOA( OA( pname^.Length-1, pname^.rawData ), OA( value.Length-1, value.rawData ));
      END; // WHILE
   END CopyAttributes;

(*--------------------------------------------------------------------------------*)

   PRIVATE PROCEDURE WriteFormNameAttribute( CONST model : StringsO.IString );
   VAR
      viewName : StringsO.CString;
   BEGIN
      viewName.FromCARD32( CurrentViewNameIndex, 10 );
      viewName.PrependOA( L"fx" );
      INC( CurrentViewNameIndex );

      Request^.ModelContainer^.SetModelInViewName( Request^.ControllerURI, model, viewName );
      Writer.WriteAttributeStringOA( L"name", OA( viewName.Length-1, viewName.rawData ));
   END WriteFormNameAttribute;

(*--------------------------------------------------------------------------------*)

   PRIVATE PROCEDURE SetModelBoolean( CONST model : StringsO.IString; value : BOOLEAN );
   BEGIN
      Request^.ModelContainer^.AddBooleanOA( OA( model.Length-1, model.rawData ), value );
   END SetModelBoolean;

(*--------------------------------------------------------------------------------*)

   PRIVATE PROCEDURE EvaluateBoolean( CONST Value : StringsO.IString ) : BOOLEAN;
   VAR
      modelValue : StringsO.CString;
   BEGIN
      IF Value.EqualsOA( L"false" ) OR Value.EqualsOA( L"0" ) OR Value.Empty THEN
         RETURN FALSE;
      ELSIF Value.EqualsOA( L"true" ) OR Value.EqualsOA( L"1" ) THEN
         RETURN TRUE;
      ELSIF NOT Request^.ModelContainer^.GetModelValue( Value, OUT modelValue ) THEN
         RETURN TRUE; // value not found, string is not empty
      ELSIF modelValue.EqualsOA( L"false" ) OR modelValue.EqualsOA( L"0" ) OR modelValue.Empty THEN
         RETURN FALSE;
      ELSE
         RETURN TRUE;
      END;
   END EvaluateBoolean;

(*--------------------------------------------------------------------------------*)

   PRIVATE PROCEDURE SetError( CONST Element : StringsO.IString; Model : StringsO.TPString; CONST Text : ARRAY OF WCHAR );
   BEGIN
      ErrorElement.Assign( Element );
      IF Model = NIL THEN
         ErrorModel.Clear();
      ELSE
         ErrorModel.Assign( Model^ );
      END;
      ErrorText.FromOA( Text );
   END SetError;

(*--------------------------------------------------------------------------------*)

   PRIVATE PROCEDURE FormatError();
   VAR
      n : ARRAY [0..63] OF WCHAR;
   BEGIN
      Writer.WriteElementStartOA( L"html" );
         Writer.WriteElementStartOA( L"body" );
            Writer.WriteElementStringOA( L"h1", L"Page template parse error" );
            Writer.WriteElementStartOA( L"dl" );
               IF Strings.FromCARD32W( Reader.CurrentLine, 10, OUT n ) THEN
                  Writer.WriteElementStringOA( L"dt", L"Line:" );
                  Writer.WriteElementStringOA( L"dd", n );
               END;
               Writer.WriteElementStringOA( L"dt", L"Element:" );
               Writer.WriteElementStringOA( L"dd", OA( ErrorElement.Length-1, ErrorElement.rawData ));
               IF NOT ErrorModel.Empty THEN
                  Writer.WriteElementStringOA( L"dt", L"Id/Model:" );
                  Writer.WriteElementStringOA( L"dd", OA( ErrorModel.Length-1, ErrorModel.rawData ));
               END;
               Writer.WriteElementStringOA( L"dt", L"Description:" );
               Writer.WriteElementStringOA( L"dd", OA( ErrorText.Length-1, ErrorText.rawData ));
            Writer.WriteElementEnd();
         Writer.WriteElementEnd();
      Writer.WriteElementEnd();
   END FormatError;

(*--------------------------------------------------------------------------------*)

BEGIN
   Request := NIL;
   Resolver := NIL;
   CurrentViewNameIndex := 1;
   Where := TWhere{};
END CPageTemplateView;

(*================================================================================*)

END View.