IMPLEMENTATION MODULE MVC;

FROM Storage IMPORT
   ALLOCATE, DEALLOCATE;

IMPORT
   HttpConnection,
   HttpTools,
   Languages,
   LanguagesO,
   lists,
   Log,
   netsocket,
   Storage,
   StorageO,
   Strings,
   Sync,
   syncmaps;

(*================================================================================*)

CONST
   SESSION_MVC = L"#mvc";

(*================================================================================*)

CLASS CContainer IMPLEMENTS IContainer;
   PRIVATE VAR
      Models : maps.CStringMap;
   PUBLIC VIRTUAL PROCEDURE Clear();
   PUBLIC VIRTUAL PROCEDURE AddModelOA( CONST Name : ARRAY OF WCHAR; REF Model : maps.CStringStringMap );
   PUBLIC VIRTUAL PROCEDURE RemoveModelOA( CONST Name : ARRAY OF WCHAR );
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

   PUBLIC VIRTUAL PROCEDURE AddModelOA( CONST Name : ARRAY OF WCHAR; REF Model : maps.CStringStringMap );
   BEGIN
      IF Models.ContainsOA( Name ) THEN
         RETURN;
      END;
      Models.AddOA( Name, ADR( Model ));
   END AddModelOA;

(*--------------------------------------------------------------------------------*)

   PUBLIC VIRTUAL PROCEDURE RemoveModelOA( CONST Name : ARRAY OF WCHAR );
   BEGIN
      Models.RemoveOA( Name );
   END RemoveModelOA;

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

CLASS CHttpRequest IMPLEMENTS IHttpRequest;

   // IHttpRequest
   PUBLIC VIRTUAL READONLY PROPERTY
      RequestHeaders : HttpCommon.TPHttpHeaders;
      ResponseHeaders : HttpCommon.TPHttpHeaders;
      ModelContainer : TPContainer; // there is model named "" and model named "session"
      Session : HttpSrv.TPSession;
      
   // SELF
   PRIVATE VAR
      _Connection : HttpConnection.TPHttpSrvConnection;
      _Session : HttpSrv.TPSession;
      _Container : TPContainer;

   LOCAL PROCEDURE Init( Connection : HttpConnection.TPHttpSrvConnection; CONST Session : HttpSrv.TPSession; CONST Container : TPContainer );

END CHttpRequest;

(*--------------------------------------------------------------------------------*)

CLASS IMPLEMENTATION CHttpRequest;

(*--------------------------------------------------------------------------------*)

   PUBLIC VIRTUAL PROPERTY RequestHeaders GET : HttpCommon.TPHttpHeaders;
   BEGIN
      RETURN _Connection^.RequestHeaders;
   END RequestHeaders;

(*--------------------------------------------------------------------------------*)

   PUBLIC VIRTUAL PROPERTY ResponseHeaders GET : HttpCommon.TPHttpHeaders;
   BEGIN
      RETURN _Connection^.ResponseHeaders;
   END ResponseHeaders;

(*--------------------------------------------------------------------------------*)

   PUBLIC VIRTUAL PROPERTY ModelContainer GET : TPContainer;
   BEGIN
      RETURN _Container;
   END ModelContainer;

(*--------------------------------------------------------------------------------*)

   PUBLIC VIRTUAL PROPERTY Session GET : HttpSrv.TPSession;
   BEGIN
      RETURN _Session;
   END Session;
      
(*--------------------------------------------------------------------------------*)

   LOCAL PROCEDURE Init( Connection : HttpConnection.TPHttpSrvConnection; CONST Session : HttpSrv.TPSession; CONST Container : TPContainer );
   BEGIN
      _Connection := Connection;
      _Session := Session;
      _Container := Container;
   END Init;

(*--------------------------------------------------------------------------------*)

BEGIN
   _Connection := NIL;
   _Session := NIL;
   _Container := NIL;
END CHttpRequest;

(*================================================================================*)

CLASS CMVC IMPLEMENTS HttpSrv.IHttpProcessor, IMVC;

   // IHttpProcessor
   PUBLIC VIRTUAL PROCEDURE AppliesFor( Verb : HttpCommon.TVerb; CONST URL : ARRAY OF WCHAR; OUT WantsSession : BOOLEAN ) : BOOLEAN;
   PUBLIC VIRTUAL PROCEDURE ProcessRequest( Connection : HttpConnection.TPHttpSrvConnection; CONST Session : HttpSrv.TPSession );
   PUBLIC VIRTUAL PROCEDURE SessionExpired( CONST Session : HttpSrv.TPSession );

   // IMVC
   PUBLIC VIRTUAL PROCEDURE RegisterController( Controller : TPController; ForVerb : HttpCommon.TVerb; CONST URL : ARRAY OF WCHAR ); // controller can be registered more times for different Verb and URI
   PUBLIC VIRTUAL PROCEDURE ForgetController( Controller : TPController; OfVerb : HttpCommon.TVerb; CONST URL : ARRAY OF WCHAR );
   PUBLIC VIRTUAL PROCEDURE ForgetControllerCompletely( Controller : TPController );

   // SELF
   PUBLIC PROCEDURE Init( CONST Context : StringsO.CString );
   
   PRIVATE VAR
      _Running : BOOLEAN := FALSE;
      _Context : StringsO.CString;
      _Controllers : syncmaps.CStringSyncMap;

   PUBLIC PROCEDURE Dispose();

   PRIVATE PROCEDURE LookupController( Verb : HttpCommon.TVerb; CONST URL : ARRAY OF WCHAR; OUT Controller : TPController ) : BOOLEAN;
   
   INITIALLY CMVC();
   FINALLY CMVC();
END CMVC;

(*================================================================================*)

CLASS IMPLEMENTATION CMVC;

//--------------------------------------------------------------------------------

   PUBLIC VIRTUAL PROCEDURE AppliesFor( Verb : HttpCommon.TVerb; CONST URL : ARRAY OF WCHAR; OUT WantsSession : BOOLEAN ) : BOOLEAN;
   BEGIN
      IF ( Verb <> HttpCommon.verbGET ) AND ( Verb <> HttpCommon.verbPOST ) THEN
         RETURN FALSE;
      ELSIF Strings.StartsWithW( URL, OA( _Context.Length-1, _Context.rawData )) THEN
         WantsSession := TRUE;
         RETURN TRUE;
      ELSE
         RETURN FALSE;
      END;
   END AppliesFor;

//--------------------------------------------------------------------------------

   PUBLIC VIRTUAL PROCEDURE ProcessRequest( Connection : HttpConnection.TPHttpSrvConnection; CONST Session : HttpSrv.TPSession );
   VAR
      buffer : StorageO.CMemoryBuffer;
      controller : TPController;
      containerMap : syncmaps.TPPtrSyncMap;
      container : POINTER TO CContainer;
      defaultMap : maps.TPStringStringMap;
      l : CARDINAL;
      request : CHttpRequest;
      s : StringsO.CString;
      view : TPView;
   BEGIN
      s := Connection^.RequestURI;
      s.Remove( 0, _Context.Length ); // remove context leading

      IF NOT LookupController( Connection^.RequestVerb, OA( s.Length-1, s.rawData ), OUT controller ) THEN
         Connection^.StatusCode := HttpCommon.httpres_404;
         RETURN;
      END;
      
      IF NOT Session^.Get( SESSION_MVC, OUT containerMap ) THEN
         NEW( containerMap );
         Session^.Add( SESSION_MVC, containerMap );
      END;
      IF NOT containerMap^.Get( controller, OUT container ) THEN
         NEW( container );
         containerMap^.Add( controller, container );
         NEW( defaultMap );
         container^.AddModelOA( DEFAULT_MODEL, REF defaultMap^ );
      END;
      
      request.Init( Connection, Session, container );
      buffer.Size := 16384; // initial size
      view := NIL;
      
      IF NOT controller^.ProcessRequest( ADR( request ), OUT view ) THEN
         Connection^.StatusCode := HttpCommon.httpres_500;
      ELSIF view = NIL THEN
         // LOG error
         ASSERT( FALSE );
         Connection^.StatusCode := HttpCommon.httpres_500;
      ELSIF NOT view^.Format( ADR( request ), OUT buffer ) THEN
         Connection^.StatusCode := HttpCommon.httpres_500;
      ELSE
         Connection^.Stream^.WriteBuffer( buffer, OUT l, netsocket.FORSAFETY );
         // LOG errors
      END;
   END ProcessRequest;

//--------------------------------------------------------------------------------

   PUBLIC VIRTUAL PROCEDURE SessionExpired( CONST Session : HttpSrv.TPSession );
   VAR
      containerMap : syncmaps.TPPtrSyncMap;
      container : POINTER TO CContainer;
      defaultMap : maps.TPStringStringMap;
   BEGIN
      IF NOT Session^.Get( SESSION_MVC, OUT containerMap ) THEN
         RETURN;
      END;
      
      containerMap^.Reset();
      WHILE containerMap^.MoveNext() DO
         container := containerMap^.CurrentData;
         IF container <> NIL THEN
            IF container^.GetModelOA( DEFAULT_MODEL, OUT defaultMap ) THEN // kill default map
               DISPOSE( defaultMap );
            END;
            DISPOSE( container );
         END;
      END; // WHILE

      DISPOSE( containerMap );
   END SessionExpired;

//--------------------------------------------------------------------------------

   PUBLIC VIRTUAL PROCEDURE RegisterController( controller : TPController; ForVerb : HttpCommon.TVerb; CONST URL : ARRAY OF WCHAR ); // controller can be registered more times for different Verb and URI
   VAR
      s : StringsO.CString;
   BEGIN
      IF ForVerb = HttpCommon.verbGET THEN
         s.FromOA( L"g" );
      ELSE
         s.FromOA( L"p" );
      END;
      s.AppendOA( URL );
      IF _Controllers.Get( s, OUT controller ) THEN
         ASSERT( FALSE );
         _Controllers.Remove( s );
      END;
      _Controllers.Add( s, controller );
   END RegisterController;

//--------------------------------------------------------------------------------

   PUBLIC VIRTUAL PROCEDURE ForgetController( Controller : TPController; OfVerb : HttpCommon.TVerb; CONST URL : ARRAY OF WCHAR );
   VAR
      s : StringsO.CString;
   BEGIN
      IF OfVerb = HttpCommon.verbGET THEN
         s.FromOA( L"g" );
      ELSE
         s.FromOA( L"p" );
      END;
      s.AppendOA( URL );
      _Controllers.Remove( s );
   END ForgetController;

//--------------------------------------------------------------------------------

   PUBLIC VIRTUAL PROCEDURE ForgetControllerCompletely( controller : TPController );
   VAR
      list : lists.CPtrList;
   BEGIN
      _Controllers.Reset();
      WHILE _Controllers.MoveNext() DO
         IF _Controllers.CurrentData = PTR( controller ) THEN
            list.Add( _Controllers.Current, 0 );
         END;
      END; // WHILE
      list.Reset();
      WHILE list.MoveNext() DO
         _Controllers.Remove( StringsO.TPString( list.Current )^ );
      END; // WHILE
   END ForgetControllerCompletely;

//--------------------------------------------------------------------------------

   PUBLIC PROCEDURE Init( CONST Context : StringsO.CString );
   BEGIN
      _Context := Context;
      // TODO
   END Init;

//--------------------------------------------------------------------------------

   PUBLIC PROCEDURE Dispose();
   BEGIN
      _Controllers.Dispose();
   END Dispose;

//--------------------------------------------------------------------------------

   PRIVATE PROCEDURE LookupController( Verb : HttpCommon.TVerb; CONST URL : ARRAY OF WCHAR; OUT controller : TPController ) : BOOLEAN;
   VAR
      b : BOOLEAN;
      s : StringsO.CString;
   BEGIN
      IF Verb = HttpCommon.verbGET THEN
         s.FromOA( L"g" );
      ELSE
         s.FromOA( L"p" );
      END;
      s.AppendOA( URL );
      RETURN _Controllers.Get( s, OUT controller );
   END LookupController;
   
//--------------------------------------------------------------------------------

BEGIN
FINALLY
   Dispose();
END CMVC;

(*================================================================================*)

CLASS CMVCHolder;
   PRIVATE VAR
      _MVC : maps.CStringMap;

   PUBLIC PROCEDURE GetMVC( CONST context : ARRAY OF WCHAR ) : TPMVC;

   PUBLIC PROCEDURE Dispose();
END CMVCHolder;

//--------------------------------------------------------------------------------

CLASS IMPLEMENTATION CMVCHolder;

//--------------------------------------------------------------------------------

   PUBLIC PROCEDURE GetMVC( CONST context : ARRAY OF WCHAR ) : TPMVC;
   VAR
      h : INTEGER;
      mvc : POINTER TO CMVC;
      s : StringsO.CString;
   BEGIN
      IF context[0] = 0W THEN
         ASSERT( FALSE );
         RETURN NIL;
      END;
      
      // remove leading and add trailing slashes
      s.FromOA( context );
      IF context[0] = L"/" THEN
         s.Remove( 0, 1 );
      END;
      h := s.Length-1;
      IF s[h] <> L"/" THEN
         s.AppendOA( L"/" );
      END;

      IF _MVC.Get( s, OUT mvc ) THEN
         RETURN mvc;
      END;
      NEW( mvc );
      mvc^.Init( s );
      _MVC.Add( s, mvc );

      HttpSrv.srv()^.RegisterProcessor( mvc );
      
      RETURN mvc;
   END GetMVC;

//--------------------------------------------------------------------------------

   PUBLIC PROCEDURE Dispose();
   VAR
      mvc : POINTER TO CMVC;
   BEGIN
      _MVC.Reset();
      WHILE _MVC.MoveNext() DO
         mvc := _MVC.CurrentData;

         HttpSrv.srv()^.ForgetProcessor( mvc );
         DISPOSE( mvc );
      END; // WHILE

      _MVC.Dispose();
   END Dispose;

//--------------------------------------------------------------------------------

BEGIN
FINALLY
   Dispose();
END CMVCHolder;

(*================================================================================*)

VAR
   MVCHolder : POINTER TO CMVCHolder := NIL;

//--------------------------------------------------------------------------------

PROCEDURE mvc( CONST context : ARRAY OF WCHAR ) : TPMVC;
BEGIN
   IF MVCHolder = NIL THEN
      NEW( MVCHolder );
   END;
   RETURN MVCHolder^.GetMVC( context );
END mvc;

//--------------------------------------------------------------------------------

PROCEDURE Cleanup();
BEGIN
   IF MVCHolder <> NIL THEN
      MVCHolder^.Dispose();
      MVCHolder := NIL;
   END;
END Cleanup;

(*================================================================================*)

CLASS CRawHTMLView IMPLEMENTS IView;
   // IView
   PUBLIC VIRTUAL PROCEDURE Format( CONST Request : TPHttpRequest; OUT Output : StorageO.CMemoryBuffer ) : BOOLEAN; // returning false means 500 response

   // SELF
   PUBLIC PROCEDURE Init( CONST HTML : ARRAY OF WCHAR );   
   
   PRIVATE VAR
      HTML : StringsO.CString;
END CRawHTMLView;

//--------------------------------------------------------------------------------

CLASS IMPLEMENTATION CRawHTMLView;

//--------------------------------------------------------------------------------

   PUBLIC VIRTUAL PROCEDURE Format( CONST Request : TPHttpRequest; OUT Output : StorageO.CMemoryBuffer ) : BOOLEAN; // returning false means 500 response
   BEGIN
      Request^.ResponseHeaders^.Add( HttpCommon.ContentType, HttpTools.FormatContentOA( HttpTools.contentTextHTML, L"utf-8" ));
      LanguagesO.ToMB( HTML, Languages.cp_UTF8, FALSE, REF Output );
      RETURN TRUE;
   END Format;

//--------------------------------------------------------------------------------

   PUBLIC PROCEDURE Init( CONST HTML : ARRAY OF WCHAR );   
   BEGIN
      SELF.HTML.FromOA( HTML );
   END Init;
   
//--------------------------------------------------------------------------------

END CRawHTMLView;

(*================================================================================*)

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

PROCEDURE rawHTMLView( CONST HTML : ARRAY OF WCHAR ) : TPView;
VAR
   view : POINTER TO CRawHTMLView;
BEGIN
   NEW( view );
   view^.Init( HTML );
   RETURN view;
END rawHTMLView;

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

(*================================================================================*)

END MVC.