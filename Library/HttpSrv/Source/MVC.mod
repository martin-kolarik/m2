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
   syncmaps,
   View;

(*================================================================================*)

CONST
   SESSION_MVC = L"#mvc";

(*================================================================================*)

CLASS CContainer IMPLEMENTS IContainer;
   PRIVATE VAR
      Models : maps.CStringMap;

   PUBLIC VIRTUAL PROCEDURE Dispose();
   PUBLIC VIRTUAL PROCEDURE RemoveOA( CONST Name : ARRAY OF WCHAR ); // removes all types

   PUBLIC VIRTUAL PROCEDURE AddBooleanOA( CONST Name : ARRAY OF WCHAR; Model : BOOLEAN );
   PUBLIC VIRTUAL PROCEDURE AddStringOA( CONST Name : ARRAY OF WCHAR; CONST Model : StringsO.IString ); // creates string in model
   PUBLIC VIRTUAL PROCEDURE AddListOA( CONST Name : ARRAY OF WCHAR; OUT Model : lists.TPStringStringList ); // creates list in model
   PUBLIC VIRTUAL PROCEDURE AddMapOA( CONST Name : ARRAY OF WCHAR; OUT Model : maps.TPStringStringMap ); // creates map in model

   PUBLIC VIRTUAL PROCEDURE GetBooleanOA( CONST Name : ARRAY OF WCHAR; OUT Model : BOOLEAN ) : BOOLEAN;
   PUBLIC VIRTUAL PROCEDURE GetStringOA( CONST Name : ARRAY OF WCHAR; OUT Model : StringsO.IString ) : BOOLEAN;
   PUBLIC VIRTUAL PROCEDURE GetListOA( CONST Name : ARRAY OF WCHAR; OUT Model : lists.TPStringStringList ) : BOOLEAN;
   PUBLIC VIRTUAL PROCEDURE GetMapOA( CONST Name : ARRAY OF WCHAR; OUT Model : maps.TPStringStringMap ) : BOOLEAN;
END CContainer;

(*--------------------------------------------------------------------------------*)

CLASS IMPLEMENTATION CContainer;

(*--------------------------------------------------------------------------------*)

   PUBLIC VIRTUAL PROCEDURE Dispose();
   TYPE
      TPCString = POINTER TO StringsO.CString;
   VAR
      l : lists.TPStringList;
      m : maps.TPStringStringMap;
      s : TPCString;
   BEGIN
      Models.Reset();
      WHILE Models.MoveNext() DO
         CASE Models.Current^[0] OF
         | L"b" :
            // do nothing
         | L"s" :
            s := TPCString( Models.CurrentData );
            DISPOSE( s );
         | L"l" :
            l := lists.TPStringList( Models.CurrentData );
            DISPOSE( l );
         | L"m" :
            m := maps.TPStringStringMap( Models.CurrentData );
            DISPOSE( m );
         ELSE
            ASSERT( FALSE );
         END; // CASE
      END; // WHILE
      Models.Dispose();
   END Dispose;

(*--------------------------------------------------------------------------------*)

   PUBLIC VIRTUAL PROCEDURE RemoveOA( CONST Name : ARRAY OF WCHAR );
   VAR
      l : lists.TPStringList;
      m : maps.TPStringStringMap;
      name : StringsO.CString;
      s : POINTER TO StringsO.CString;
   BEGIN
      name.FromOA( L" ." );
      name.AppendOA( Name ); 

      name[0] := L"b";
      Models.Remove( name );

      name[0] := L"s";
      IF Models.Get( name, OUT s ) THEN
         DISPOSE( s );
      END;

      name[0] := L"l";
      IF Models.Get( name, OUT l ) THEN
         DISPOSE( l );
      END;

      name[0] := L"m";
      IF Models.Get( name, OUT m ) THEN
         DISPOSE( m );
      END;
   END RemoveOA;

(*--------------------------------------------------------------------------------*)

   PUBLIC VIRTUAL PROCEDURE AddBooleanOA( CONST Name : ARRAY OF WCHAR; Model : BOOLEAN );
   VAR
      name : StringsO.CString;
   BEGIN
      name.FromOA( L"b." );
      name.AppendOA( Name );
      IF Models.Contains( name ) THEN
         Models.Remove( name );
      END;
      Models.Add( name, PTR( Model ));
   END AddBooleanOA;

(*--------------------------------------------------------------------------------*)

   PUBLIC VIRTUAL PROCEDURE AddStringOA( CONST Name : ARRAY OF WCHAR; CONST Model : StringsO.IString ); // creates string in model
   VAR
      model : POINTER TO StringsO.CString;
      name : StringsO.CString;
   BEGIN
      name.FromOA( L"s." );
      name.AppendOA( Name );
      IF NOT Models.Get( name, OUT model ) THEN
         NEW( model );
         Models.Add( name, model );
      END;
      model^.Assign( Model );
   END AddStringOA;

(*--------------------------------------------------------------------------------*)

   PUBLIC VIRTUAL PROCEDURE AddListOA( CONST Name : ARRAY OF WCHAR; OUT Model : lists.TPStringStringList ); // creates list in model
   VAR
      name : StringsO.CString;
   BEGIN
      name.FromOA( L"l." );
      name.AppendOA( Name );
      IF Models.Get( name, OUT Model ) THEN
         Model^.Dispose();
      ELSE
         NEW( Model );
         Models.Add( name, Model );
      END;
   END AddListOA;

(*--------------------------------------------------------------------------------*)

   PUBLIC VIRTUAL PROCEDURE AddMapOA( CONST Name : ARRAY OF WCHAR; OUT Model : maps.TPStringStringMap ); // creates map in model
   VAR
      name : StringsO.CString;
   BEGIN
      name.FromOA( L"m." );
      name.AppendOA( Name );
      IF Models.Get( name, OUT Model ) THEN
         Model^.Dispose();
      ELSE
         NEW( Model );
         Models.Add( name, Model );
      END;
   END AddMapOA;

(*--------------------------------------------------------------------------------*)

   PUBLIC VIRTUAL PROCEDURE GetBooleanOA( CONST Name : ARRAY OF WCHAR; OUT Model : BOOLEAN ) : BOOLEAN;
   VAR
      model : PTR;
      name : StringsO.CString;
   BEGIN
      name.FromOA( L"b." );
      name.AppendOA( Name );
      IF NOT Models.Get( name, OUT model ) THEN
         RETURN FALSE;
      END;
      Model := BOOLEAN( LOPTRLONGWORD( model ));
      RETURN TRUE;
   END GetBooleanOA;

(*--------------------------------------------------------------------------------*)

   PUBLIC VIRTUAL PROCEDURE GetStringOA( CONST Name : ARRAY OF WCHAR; OUT Model : StringsO.IString ) : BOOLEAN;
   VAR
      model : StringsO.TPString;
      name : StringsO.CString;
   BEGIN
      name.FromOA( L"s." );
      name.AppendOA( Name );
      IF NOT Models.Get( name, OUT model ) THEN
         RETURN FALSE;
      END;
      Model.Assign( model^ );
      RETURN TRUE;
   END GetStringOA;

(*--------------------------------------------------------------------------------*)

   PUBLIC VIRTUAL PROCEDURE GetListOA( CONST Name : ARRAY OF WCHAR; OUT Model : lists.TPStringStringList ) : BOOLEAN;
   VAR
      model : lists.TPStringStringList;
      name : StringsO.CString;
   BEGIN
      name.FromOA( L"l." );
      name.AppendOA( Name );
      IF NOT Models.Get( name, OUT model ) THEN
         RETURN FALSE;
      END;
      Model := model;
      RETURN TRUE;
   END GetListOA;

(*--------------------------------------------------------------------------------*)

   PUBLIC VIRTUAL PROCEDURE GetMapOA( CONST Name : ARRAY OF WCHAR; OUT Model : maps.TPStringStringMap ) : BOOLEAN;
   VAR
      model : maps.TPStringStringMap;
      name : StringsO.CString;
   BEGIN
      name.FromOA( L"m." );
      name.AppendOA( Name );
      IF NOT Models.Get( name, OUT model ) THEN
         RETURN FALSE;
      END;
      Model := model;
      RETURN TRUE;
   END GetMapOA;

(*--------------------------------------------------------------------------------*)

BEGIN FINALLY
   Dispose();
END CContainer;

(*================================================================================*)

CLASS CHttpRequest IMPLEMENTS IHttpRequest;

   // IHttpRequest
   PUBLIC VIRTUAL READONLY PROPERTY
      AbsoluteURI : StringsO.CString;
      ControllerURI : StringsO.CString;
      RequestHeaders : HttpCommon.TPHttpHeaders;
      ResponseHeaders : HttpCommon.TPHttpHeaders;
      ModelContainer : TPContainer; // there is model named "" and model named "session"
      Session : HttpSrv.TPSession;
      
   // SELF
   PRIVATE VAR
      _Connection : HttpConnection.TPHttpSrvConnection;
      _Session : HttpSrv.TPSession;
      _ControllerURI : StringsO.CString;
      _Container : TPContainer;

   LOCAL PROCEDURE Init( CONST RequestURI : StringsO.CString; Connection : HttpConnection.TPHttpSrvConnection; CONST Session : HttpSrv.TPSession; CONST Container : TPContainer );

END CHttpRequest;

(*--------------------------------------------------------------------------------*)

CLASS IMPLEMENTATION CHttpRequest;

(*--------------------------------------------------------------------------------*)

   PUBLIC VIRTUAL PROPERTY AbsoluteURI GET : StringsO.CString;
   BEGIN
      RETURN _Connection^.AbsoluteURI;
   END AbsoluteURI;

(*--------------------------------------------------------------------------------*)

   PUBLIC VIRTUAL PROPERTY ControllerURI GET : StringsO.CString;
   BEGIN
      RETURN _ControllerURI;
   END ControllerURI;

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

   LOCAL PROCEDURE Init( CONST ControllerURI : StringsO.CString; Connection : HttpConnection.TPHttpSrvConnection; CONST Session : HttpSrv.TPSession; CONST Container : TPContainer );
   BEGIN
      _ControllerURI := ControllerURI;
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
      END;
      
      request.Init( s, Connection, Session, container );
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
   BEGIN
      IF NOT Session^.Get( SESSION_MVC, OUT containerMap ) THEN
         RETURN;
      END;
      
      containerMap^.Reset();
      WHILE containerMap^.MoveNext() DO
         container := containerMap^.CurrentData;
         DISPOSE( container );
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
   view : View.TPRawHTMLView;
BEGIN
   NEW( view );
   view^.Init( HTML );
   RETURN view;
END rawHTMLView;

//--------------------------------------------------------------------------------

PROCEDURE pageTemplateView( CONST resolver : FSO.TPFilePathResolver; CONST viewName : ARRAY OF WCHAR ) : TPView;
VAR
   view : View.TPPageTemplateView;
BEGIN
   NEW( view );
   view^.Init( resolver, viewName );
   RETURN view;
END pageTemplateView;

(*================================================================================*)

END MVC.