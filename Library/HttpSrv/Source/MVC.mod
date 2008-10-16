IMPLEMENTATION MODULE MVC;

FROM Storage IMPORT
   ALLOCATE, DEALLOCATE;

IMPORT
   HttpConnection,
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

CLASS CHttpRequest IMPLEMENTS IHttpRequest;

   // IHttpRequest
   PUBLIC VIRTUAL READONLY PROPERTY
      RequestHeaders : HttpCommon.TPHttpHeaders;
      ResponseHeaders : HttpCommon.TPHttpHeaders;
      Container : HttpSrv.TPContainer; // there is model named "" and model named "session"
      Session : HttpSrv.TPSession;
      
   // SELF
   PRIVATE VAR
      _Connection : HttpConnection.TPHttpSrvConnection;
      _Session : HttpSrv.TPSession;

   LOCAL PROCEDURE Init( Connection : HttpConnection.TPHttpSrvConnection; CONST Session : HttpSrv.TPSession );

END CHttpRequest;

(*================================================================================*)

CLASS CMVC IMPLEMENTS HttpSrv.IHttpProcessor, IMVC;

   // IHttpProcessor
   PUBLIC VIRTUAL PROCEDURE AppliesFor( Verb : HttpCommon.TVerb; CONST URL : ARRAY OF WCHAR; OUT WantsSession : BOOLEAN ) : BOOLEAN;
   PUBLIC VIRTUAL PROCEDURE ProcessRequest( Connection : HttpConnection.TPHttpSrvConnection; CONST Session : HttpSrv.TPSession );
   PUBLIC VIRTUAL PROCEDURE SessionExpired( CONST Session : HttpSrv.TPSession );

   // IMVC
   PUBLIC VIRTUAL READONLY PROPERTY
      Running : BOOLEAN;

   PUBLIC VIRTUAL PROCEDURE Start() : Sync.TAsyncResult;
   PUBLIC VIRTUAL PROCEDURE Stop();
   
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
      l : CARDINAL;
      request : CHttpRequest;
      s : StringsO.CString;
      view : TPView;
   BEGIN
      s := Connection^.RequestURI;
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
      END;
      
      request.Init( Connection, Session );
      buffer.Size := 16384; // initial size
      
      IF NOT controller^.ProcessRequest( ADR( request ), container, OUT view ) THEN
         Connection^.StatusCode := HttpCommon.httpres_500;
      ELSIF NOT view^.Format( container, REF buffer ) THEN
         Connection^.StatusCode := HttpCommon.httpres_500;
      ELSE
         Connection^.Stream^.WriteBuffer( buffer, OUT l, netsocket.FORSAFETY );
         // LOG errors
      END;
   END ProcessRequest;

//--------------------------------------------------------------------------------

   PUBLIC PROCEDURE Dispose();
   BEGIN
      _Controllers.Dispose();
   END Dispose;

//--------------------------------------------------------------------------------

   PRIVATE PROCEDURE LookupController( Verb : HttpCommon.TVerb; CONST URL : ARRAY OF WCHAR; OUT Controller : TPController ) : BOOLEAN;
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
      RETURN _Controllers.Get( s, OUT Controller );
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
      mvc : POINTER TO CMVC;
      s : StringsO.CString;
   BEGIN
      IF context[0] = L"/" THEN
         s.FromOA( context );
      ELSE
         s.FromOA( L"/" );
         s.AppendOA( context );
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

(*================================================================================*)

END MVC.