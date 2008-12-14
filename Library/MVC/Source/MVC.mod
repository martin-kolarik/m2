IMPLEMENTATION MODULE MVC;

FROM Debug IMPORT
   Assertion, LogAssertionW;

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
   VIEW_MAPPER = L"#viewmapper";

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

   PUBLIC VIRTUAL PROCEDURE SetModelValue( CONST Model, Value : StringsO.IString ) : BOOLEAN; // main methods for accessing, it solves indexes, points, etc. in names
   PUBLIC VIRTUAL PROCEDURE GetModelValue( CONST Model : StringsO.IString; OUT Value : StringsO.IString ) : BOOLEAN; // main methods for accessing, it solves indexes, points, etc. in names
   PUBLIC VIRTUAL PROCEDURE Format( FailOnError : BOOLEAN; CONST Source : StringsO.IString; OUT Formatted : StringsO.IString ) : BOOLEAN; // main format method, replaces view syntax with model data

   PUBLIC VIRTUAL PROCEDURE ResetModelViewMapping(); // clears all mode-view bindings
   PUBLIC VIRTUAL PROCEDURE SetModelViewMapping( CONST FullModel, ViewName : StringsO.IString ); // stores logical name used in view output together with full model accessor
   PUBLIC VIRTUAL PROCEDURE GetModelViewMapping( CONST ViewName : StringsO.IString; OUT FullModel : StringsO.IString ) : BOOLEAN; // gets model name by logical name used in view
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
         Models.Remove( name );
      END;

      name[0] := L"l";
      IF Models.Get( name, OUT l ) THEN
         DISPOSE( l );
         Models.Remove( name );
      END;

      name[0] := L"m";
      IF Models.Get( name, OUT m ) THEN
         DISPOSE( m );
         Models.Remove( name );
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

   PUBLIC VIRTUAL PROCEDURE SetModelValue( CONST model, value : StringsO.IString ) : BOOLEAN; // main methods for accessing, it solves indexes, points, etc. in names
   LABEL
      Error;
   VAR
      i, index, j : INTEGER;
      lvalue : StringsO.CString;
      keyIndex, valueIndex : BOOLEAN;
      list : lists.TPStringStringList;
      map : maps.TPStringStringMap;
      ps : StringsO.TPString;
      sindex1, sindex2 : StringsO.CString;
   BEGIN
      i := model.IndexOfOA( L".", 0 );
      IF i > 0 THEN // ok, find in map or list by key
         IF NOT GetMapOA( OA( i-1, model.rawData ), OUT map ) THEN
            map := NIL;
         ELSIF NOT GetListOA( OA( i-1, model.rawData ), OUT list ) THEN
            list := NIL;
         END;
         IF ( map = NIL ) AND ( list = NIL ) THEN
            GOTO Error;
         END;
         model.Substring( i+1, -1, OUT sindex1 );            
         Format( FALSE, sindex1, OUT sindex2 );
         IF map <> NIL THEN
            map^.Remove( sindex2 );
            map^.Add( sindex2, value );
         ELSIF list <> NIL THEN
            list^.Remove( sindex2 );
            list^.Add( sindex2, value );
         END;
         RETURN TRUE;
      END;

      valueIndex := FALSE;
      keyIndex := FALSE;
      i := model.IndexOfOA( L"[", 0 );
      IF i > 0 THEN // ok, find in map or list
         index := -1;
         j := model.IndexOfOA( L"]", i+1 );
         IF j = -1 THEN
            GOTO Error;
         END;
         valueIndex := TRUE;
      END;
      IF NOT valueIndex THEN
         i := model.IndexOfOA( L"{", 0 );
         IF i > 0 THEN // ok, find in map or list
            index := -1;
            j := model.IndexOfOA( L"}", i+1 );
            IF j = -1 THEN
               GOTO Error;
            END;
            keyIndex := TRUE;
         END;
      END;
      IF valueIndex OR keyIndex THEN
         model.Substring( i+1, j-i-1, OUT sindex1 );
         Format( FALSE, sindex1, OUT sindex2 );
         sindex2.Trim();
         IF NOT Strings.ToINT32W( OA( sindex2.Length-1, sindex2.rawData ), 10, OUT index ) THEN
            GOTO Error;
         ELSIF GetMapOA( OA( i-1, model.rawData ), OUT map ) THEN
            IF valueIndex THEN
               ps := map^[index];
               IF ps = NIL THEN
                  GOTO Error;
               END;
               ps^.Assign( value );
            ELSIF map^.ElementAt( index, OUT sindex1, OUT lvalue ) THEN
               map^.Remove( sindex1 );
               map^.Add( sindex1, value );
            ELSE
               GOTO Error;
            END;
            RETURN TRUE;
         ELSIF GetListOA( OA( i-1, model.rawData ), OUT list ) THEN
            IF keyIndex THEN
               ps := list^[index];
               IF ps = NIL THEN
                  GOTO Error;
               END;
               ps^.Assign( value );
            ELSIF list^.ElementAt( index, OUT sindex1, OUT lvalue ) THEN
               list^.Remove( sindex1 );
               list^.Add( sindex1, value );
            ELSE
               GOTO Error;
            END;
            RETURN TRUE;
         ELSE
            GOTO Error;
         END;
      END;
      
      // fall to string
      AddStringOA( OA( model.Length-1, model.rawData ), value );
      RETURN TRUE;

      // emit error      
   Error:
      value.FromOA( L'##unknown model: ' );
      value.Append( model );
      value.AppendOA( L"" );
      RETURN FALSE;
   END SetModelValue;

(*--------------------------------------------------------------------------------*)

   PUBLIC VIRTUAL PROCEDURE GetModelValue( CONST model : StringsO.IString; OUT value : StringsO.IString ) : BOOLEAN; // main methods for accessing, it solves indexes, points, etc. in names
   LABEL
      Error;
   VAR
      boolean : BOOLEAN;
      i, index, j : INTEGER;
      keyIndex, valueIndex : BOOLEAN;
      list : lists.TPStringStringList;
      map : maps.TPStringStringMap;
      ps : StringsO.TPString;
      sindex1, sindex2 : StringsO.CString;
   BEGIN
      i := model.IndexOfOA( L".", 0 );
      IF i > 0 THEN // ok, find in map or list by key
         IF NOT GetMapOA( OA( i-1, model.rawData ), OUT map ) THEN
            map := NIL;
         ELSIF NOT GetListOA( OA( i-1, model.rawData ), OUT list ) THEN
            list := NIL;
         END;
         IF ( map = NIL ) AND ( list = NIL ) THEN
            GOTO Error;
         END;
         model.Substring( i+1, -1, OUT sindex1 );            
         Format( FALSE, sindex1, OUT sindex2 );
         IF ( map <> NIL ) AND NOT map^.Get( sindex2, OUT value ) THEN
            GOTO Error;
         ELSIF ( list <> NIL ) AND NOT list^.Get( sindex2, OUT value ) THEN
            GOTO Error;
         END;
         RETURN TRUE;
      END;

      valueIndex := FALSE;
      keyIndex := FALSE;
      i := model.IndexOfOA( L"[", 0 );
      IF i > 0 THEN // ok, find in map or list
         index := -1;
         j := model.IndexOfOA( L"]", i+1 );
         IF j = -1 THEN
            GOTO Error;
         END;
         valueIndex := TRUE;
      END;
      IF NOT valueIndex THEN
         i := model.IndexOfOA( L"{", 0 );
         IF i > 0 THEN // ok, find in map or list
            index := -1;
            j := model.IndexOfOA( L"}", i+1 );
            IF j = -1 THEN
               GOTO Error;
            END;
            keyIndex := TRUE;
         END;
      END;
      IF valueIndex OR keyIndex THEN
         model.Substring( i+1, j-i-1, OUT sindex1 );
         Format( FALSE, sindex1, OUT sindex2 );
         sindex2.Trim();
         IF NOT Strings.ToINT32W( OA( sindex2.Length-1, sindex2.rawData ), 10, OUT index ) THEN
            GOTO Error;
         ELSIF GetMapOA( OA( i-1, model.rawData ), OUT map ) THEN
            IF valueIndex THEN
               ps := map^[index];
               IF ps = NIL THEN
                  GOTO Error;
               END;
               value.Assign( ps^ );
            ELSIF NOT map^.ElementAt( index, OUT sindex1, OUT value ) THEN
               GOTO Error;
            END;
            RETURN TRUE;
         ELSIF GetListOA( OA( i-1, model.rawData ), OUT list ) THEN
            IF keyIndex THEN
               ps := list^[index];
               IF ps = NIL THEN
                  GOTO Error;
               END;
               value.Assign( ps^ );
            ELSIF NOT list^.ElementAt( index, OUT value, OUT sindex1 ) THEN
               GOTO Error;
            END;
            RETURN TRUE;
         ELSE
            GOTO Error;
         END;
      END;
      
      // test string
      IF GetStringOA( OA( model.Length-1, model.rawData ), OUT value ) THEN
         RETURN TRUE;
      END;
      
      // test boolean
      IF GetBooleanOA( OA( model.Length-1, model.rawData ), OUT boolean ) THEN
         IF boolean THEN
            value.FromOA( L"true" );
         ELSE
            value.FromOA( L"false" );
         END;
         RETURN TRUE;
      END;

      // emit error      
   Error:
      value.FromOA( L'##unknown model: ' );
      value.Append( model );
      value.AppendOA( L"" );
      RETURN FALSE;
   END GetModelValue;

(*--------------------------------------------------------------------------------*)

   PUBLIC VIRTUAL PROCEDURE Format( FailOnError : BOOLEAN; CONST Source : StringsO.IString; OUT Formatted : StringsO.IString ) : BOOLEAN; // main format method, replaces view syntax with model data
   VAR
      i, mi, j : INTEGER;
      model : StringsO.CString;
      value : StringsO.CString;
   BEGIN
      Formatted.Assign( Source );
      i := -1;
      LOOP
         // get ${
         i := Formatted.IndexOfOA( L"${", i+1 );
         IF i = -1 THEN
            RETURN TRUE;
         ELSIF ( i > 0 ) AND ( Formatted[i-1] = L"\" ) THEN // not pattern
            CONTINUE;
         END;

         // get }
         mi := i + 2;
         j := Formatted.IndexOfOA( L"}", mi );
         IF j = mi+1 THEN
            CONTINUE;
         END;

         // resolve and replace model
         Formatted.Substring( mi, j-mi, OUT model );
         IF NOT GetModelValue( model, OUT value ) AND FailOnError THEN
            RETURN FALSE;
         END;
         Formatted.Remove( i, j-i+1 );
         Formatted.Insert( i, value );
      END; // LOOP
   END Format;

(*--------------------------------------------------------------------------------*)

   PUBLIC VIRTUAL PROCEDURE ResetModelViewMapping(); // clears all mode-view bindings
   BEGIN
      RemoveOA( VIEW_MAPPER );
   END ResetModelViewMapping;

(*--------------------------------------------------------------------------------*)

   PUBLIC VIRTUAL PROCEDURE SetModelViewMapping( CONST FullModel, ViewName : StringsO.IString ); // stores logical name used in view output together with full model accessor
   VAR
      mapper : maps.TPStringStringMap;
   BEGIN
      IF NOT GetMapOA( VIEW_MAPPER, OUT mapper ) THEN
         AddMapOA( VIEW_MAPPER, OUT mapper );
      END;
      mapper^.Add( ViewName, FullModel );
   END SetModelViewMapping;

(*--------------------------------------------------------------------------------*)

   PUBLIC VIRTUAL PROCEDURE GetModelViewMapping( CONST ViewName : StringsO.IString; OUT FullModel : StringsO.IString ) : BOOLEAN; // gets model name by logical name used in view
   VAR
      mapper : maps.TPStringStringMap;
   BEGIN
      IF NOT GetMapOA( VIEW_MAPPER, OUT mapper ) THEN
         RETURN FALSE;
      ELSIF NOT mapper^.Get( ViewName, OUT FullModel ) THEN
         RETURN FALSE;
      ELSE
         RETURN TRUE;
      END;
   END GetModelViewMapping;

(*--------------------------------------------------------------------------------*)

BEGIN FINALLY
   Dispose();
END CContainer;

(*================================================================================*)

CLASS CHttpRequest IMPLEMENTS IHttpRequest;

   // IHttpRequest
   PUBLIC VIRTUAL READONLY PROPERTY
      RequestVerb : HttpCommon.TVerb;
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

   PUBLIC VIRTUAL PROPERTY RequestVerb GET : HttpCommon.TVerb;
   BEGIN
      RETURN _Connection^.RequestVerb;
   END RequestVerb;

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
   PRIVATE PROCEDURE DecodeDataFromURI( Connection : HttpConnection.TPHttpSrvConnection; OUT list : lists.CStringStringList );
   PRIVATE PROCEDURE DecodeDataFromContent( Connection : HttpConnection.TPHttpSrvConnection; OUT list : lists.CStringStringList );
   
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
      connectionData : lists.CStringStringList;
      controller : TPController;
      containerMap : syncmaps.TPPtrSyncMap;
      container : POINTER TO CContainer;
      l : CARDINAL;
      mappedName : StringsO.CString;
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
      
      // decode URL or form, if present
      CASE Connection^.RequestVerb OF
      | HttpCommon.verbGET, HttpCommon.verbHEAD : // decode form data from URI
         DecodeDataFromURI( Connection, OUT connectionData );
      | HttpCommon.verbPOST : // decode form data from input
         DecodeDataFromContent( Connection, OUT connectionData );
      ELSE
         ASSERTLOG( FALSE, L"Unknown HTTP verb when processing MVC request" );
      END;
      connectionData.Reset();
      WHILE connectionData.MoveNext() DO
         IF container^.GetModelViewMapping( connectionData.Current^, OUT mappedName ) THEN
            container^.SetModelValue( mappedName, connectionData.CurrentData^ );
         ELSE
            Connection^.StatusCode := HttpCommon.httpres_500;
            // LOG errors
            ASSERT( FALSE );
         END;
      END; // WHILE
      connectionData.Dispose();
      
      // prepare controller data
      request.Init( s, Connection, Session, container );
      buffer.Size := 16384; // initial size
      view := NIL;
      
      IF NOT controller^.ProcessRequest( ADR( request ), OUT view ) THEN
         Connection^.StatusCode := HttpCommon.httpres_500;
      ELSIF view = NIL THEN
         Connection^.StatusCode := HttpCommon.httpres_500;
         // LOG error
         ASSERT( FALSE );
      ELSE
         container^.ResetModelViewMapping();
         IF view^.Format( ADR( request ), OUT buffer ) THEN
            Connection^.Stream^.WriteBuffer( buffer, OUT l, netsocket.FORSAFETY );
            // LOG errors
         ELSE
            Connection^.StatusCode := HttpCommon.httpres_500;
         END;
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

   PRIVATE PROCEDURE DecodeDataFromURI( Connection : HttpConnection.TPHttpSrvConnection; OUT list : lists.CStringStringList );
   VAR
      byteBuffer : StorageO.CMemoryBuffer;
      i : CARDINAL;
      URI : StringsO.CString;
   BEGIN
      URI := Connection^.RequestURI;
      i := URI.IndexOfOA( L"?", 0 );
      IF i = -1 THEN
         RETURN; // no data
      END;
      URI.Remove( 0, i );
      LanguagesO.ToMB( URI, 0, FALSE, REF byteBuffer );
      HttpTools.DecodeURLEncoding( FALSE, OA( byteBuffer.Length-1, byteBuffer.Data ), OUT list );
   END DecodeDataFromURI;

//--------------------------------------------------------------------------------

   PRIVATE PROCEDURE DecodeDataFromContent( Connection : HttpConnection.TPHttpSrvConnection; OUT list : lists.CStringStringList );
   VAR
      byteBuffer : StorageO.CMemoryBuffer;
      stream : IOO.TPStream := Connection^.Stream;
   BEGIN
      byteBuffer.Size := 16384;
      WHILE stream^.ReadBuffer( byteBuffer.Size, REF byteBuffer, Sync.FORSAFETY ) = Sync.arCompleted DO
         IF byteBuffer.Size > 2*1024*1024 THEN
            EXIT;
         END;
         IF byteBuffer.Length MOD 16384 = 0 THEN // filled up
            INC( byteBuffer.Size, 16384 );
         END;
      END; // WHILE

      HttpTools.DecodeURLEncoding( FALSE, OA( byteBuffer.Length-1, byteBuffer.Data ), OUT list );
   END DecodeDataFromContent;

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