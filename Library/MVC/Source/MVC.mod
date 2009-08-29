IMPLEMENTATION MODULE MVC;

FROM Debug IMPORT
   Assertion, LogAssertionW;

FROM Storage IMPORT
   ALLOCATE, DEALLOCATE;

IMPORT
   accesslist,
   HttpConnection,
   HttpTools,
   LanguagesO,
   lists,
   Log,
   netsocket,
   Resources,
   SrvCommon,
   Storage,
   StorageO,
   Strings,
   Sync,
   syncmaps,
   View;

(*================================================================================*)

CONST
   SESSION_MVC = L"#mvc";
   VIEW_MAPPER = L"#viewmapper.";

(*================================================================================*)

CLASS CContainer IMPLEMENTS IContainer;
   PRIVATE VAR
      Models : maps.CStringMap;
      CallMemo : BOOLEAN := FALSE;

   PUBLIC VIRTUAL PROCEDURE Dispose();
   PUBLIC VIRTUAL PROCEDURE RemoveOA( CONST Name : ARRAY OF WCHAR ); // removes all types

   PUBLIC VIRTUAL PROCEDURE AddBooleanOA( CONST Name : ARRAY OF WCHAR; Model : BOOLEAN );
   PUBLIC VIRTUAL PROCEDURE AddStringOA( CONST Name : ARRAY OF WCHAR; CONST Model : StringsO.IString ); // creates string in model
   PUBLIC VIRTUAL PROCEDURE AddListOA( CONST Name : ARRAY OF WCHAR; OUT Model : lists.TPStringStringList ); // creates list in model
   PUBLIC VIRTUAL PROCEDURE AddMapOA( CONST Name : ARRAY OF WCHAR; OUT Model : maps.TPStringStringMap ); // creates map in model
   PUBLIC VIRTUAL PROCEDURE AddFunctionHandlerOA( CONST Name : ARRAY OF WCHAR; Handler : TPFunctionHandler );

   PUBLIC VIRTUAL PROCEDURE GetBooleanOA( CONST Name : ARRAY OF WCHAR; OUT Model : BOOLEAN ) : BOOLEAN;
   PUBLIC VIRTUAL PROCEDURE GetStringOA( CONST Name : ARRAY OF WCHAR; OUT Model : StringsO.IString ) : BOOLEAN;
   PUBLIC VIRTUAL PROCEDURE GetListOA( CONST Name : ARRAY OF WCHAR; OUT Model : lists.TPStringStringList ) : BOOLEAN;
   PUBLIC VIRTUAL PROCEDURE GetMapOA( CONST Name : ARRAY OF WCHAR; OUT Model : maps.TPStringStringMap ) : BOOLEAN;
   PUBLIC VIRTUAL PROCEDURE GetFunctionHandlerOA( CONST Name : ARRAY OF WCHAR; OUT Handler : TPFunctionHandler ) : BOOLEAN;

   PUBLIC VIRTUAL PROCEDURE ResetFunctionCallsMemo();
   PUBLIC VIRTUAL PROCEDURE GetFunctionCallsMemo() : BOOLEAN; // returns if some function was called after last ResetFunctionCallsMemo
   
   PUBLIC VIRTUAL PROCEDURE SetModelValue( CONST Model, Value : StringsO.IString ) : BOOLEAN; // main methods for accessing, it solves indexes, points, etc. in names
   PUBLIC VIRTUAL PROCEDURE GetModelValue( CONST Model : StringsO.IString; OUT Value : StringsO.IString ) : BOOLEAN; // main methods for accessing, it solves indexes, points, etc. in names
   PUBLIC VIRTUAL PROCEDURE Format( FailOnError : BOOLEAN; CONST Source : StringsO.IString; MessageSource : TPMessageSource; language : Languages.TLanguage; OUT Formatted : StringsO.IString ) : BOOLEAN; // main format method, replaces view syntax with model data

   // There can be more active mappings, each identified by ControllerURI.
   PUBLIC VIRTUAL PROCEDURE ResetModelInViewNames( CONST ControllerURI : StringsO.IString ); // clears all mode-view bindings corresponding to SetId
   PUBLIC VIRTUAL PROCEDURE SetModelInViewName( CONST ControllerURI, FullModel, InViewName : StringsO.IString ); // stores logical name used in view output together with full model accessor
   PUBLIC VIRTUAL PROCEDURE GetModelByInViewName( CONST ControllerURI, InViewName : StringsO.IString; OUT FullModel : StringsO.IString ) : BOOLEAN; // gets model name by logical name used in view
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
         | L"f" :
            // do nothing
         ELSE
            ASSERTLOG( FALSE );
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

   PUBLIC VIRTUAL PROCEDURE AddFunctionHandlerOA( CONST Name : ARRAY OF WCHAR; Handler : TPFunctionHandler );
   VAR
      name : StringsO.CString;
   BEGIN
      name.FromOA( L"f." );
      name.AppendOA( Name );
      IF Models.Contains( name ) THEN
         Models.Remove( name );
      END;
      Models.Add( name, PTR( Handler ));
   END AddFunctionHandlerOA;

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

   PUBLIC VIRTUAL PROCEDURE ResetFunctionCallsMemo();
   BEGIN
      CallMemo := FALSE;
   END ResetFunctionCallsMemo;

(*--------------------------------------------------------------------------------*)

   PUBLIC VIRTUAL PROCEDURE GetFunctionCallsMemo() : BOOLEAN; // returns if some function was called after last ResetFunctionCallsMemo
   BEGIN
      RETURN CallMemo;
   END GetFunctionCallsMemo;

(*--------------------------------------------------------------------------------*)

   PUBLIC VIRTUAL PROCEDURE GetFunctionHandlerOA( CONST Name : ARRAY OF WCHAR; OUT Handler : TPFunctionHandler ) : BOOLEAN;
   VAR
      model : TPFunctionHandler;
      name : StringsO.CString;
   BEGIN
      name.FromOA( L"f." );
      name.AppendOA( Name );
      IF NOT Models.Get( name, OUT model ) THEN
         RETURN FALSE;
      END;
      Handler := model;
      RETURN TRUE;
   END GetFunctionHandlerOA;

(*--------------------------------------------------------------------------------*)

   PUBLIC VIRTUAL PROCEDURE SetModelValue( CONST model, value : StringsO.IString ) : BOOLEAN; // main methods for accessing, it solves indexes, points, etc. in names
   LABEL
      Error;
   VAR
      boolean : BOOLEAN;
      empty : StringsO.CString;
      functionHandler : TPFunctionHandler;
      i, ii, index, j : INTEGER;
      lvalue : StringsO.CString;
      keyIndex, valueIndex : BOOLEAN;
      list : lists.TPStringStringList := NIL;
      map : maps.TPStringStringMap := NIL;
      parameter : StringsO.CString;
      parameters : lists.CStringStringList;
      ps : StringsO.TPString;
      sindex1, sindex2 : StringsO.CString;
   BEGIN
      i := model.IndexOfOA( L".", 0 );
      IF i > 0 THEN // ok, find in map or list by key
         IF GetMapOA( OA( i-1, model.rawData ), OUT map ) THEN
            // fall down
         ELSIF GetListOA( OA( i-1, model.rawData ), OUT list ) THEN
            // fall down
         END;
         IF ( map = NIL ) AND ( list = NIL ) THEN
            GOTO Error;
         END;
         model.Substring( i+1, -1, OUT sindex1 );            
         IF NOT GetModelValue( sindex1, OUT sindex2 ) THEN
            sindex2 := sindex1;
         END;
         sindex2.Trim();
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
         i := model.IndexOfOA( L"<", 0 );
         IF i > 0 THEN // ok, find in map or list
            index := -1;
            j := model.IndexOfOA( L">", i+1 );
            IF j = -1 THEN
               GOTO Error;
            END;
            keyIndex := TRUE;
         END;
      END;
      IF valueIndex OR keyIndex THEN
         model.Substring( i+1, j-i-1, OUT sindex1 );
         IF NOT GetModelValue( sindex1, OUT sindex2 ) THEN
            sindex2 := sindex1;
         END;
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

      // try function
      i := model.IndexOfOA( L"(", 0 );
      IF i > 0 THEN
         j := model.IndexOfOA( L")", i+1 );
         IF j = -1 THEN
            GOTO Error;
         END;
         model.Substring( 0, i, OUT sindex1 );
         sindex1.Trim();
         IF GetFunctionHandlerOA( OA( sindex1.Length-1, sindex1.rawData ), OUT functionHandler ) THEN
            ii := i+1;
            LOOP
               ii := model.ItemS( StringsO.WCHARS{L' ', L','}, ii, 0, TRUE, OUT sindex2 );
               IF NOT GetModelValue( sindex2, OUT parameter ) THEN
                  parameter := sindex2;
               END;
               parameter.Trim();
               parameters.Add( empty, parameter );
               IF ii = -1 THEN
                  EXIT;
               END;
            END; // LOOP
            boolean := functionHandler^.Call( sindex1, REF parameters, NIL );
            CallMemo := CallMemo OR boolean;
            RETURN boolean;
         END; // IF function found
      END;
      
      // try boolean      
      IF GetBooleanOA( OA( model.Length-1, model.rawData ), OUT boolean ) THEN
         lvalue.Assign( value );
         lvalue.Lowerize();
         AddBooleanOA( OA( model.Length-1, model.rawData ), value.EqualsOA( L"true" ) OR value.EqualsOA( L"1" ) OR value.EqualsOA( L"y" ) OR value.EqualsOA( L"yes" ));
         RETURN TRUE;
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
      empty : StringsO.CString;
      functionHandler : TPFunctionHandler;
      i, ii, index, j : INTEGER;
      keyIndex, valueIndex : BOOLEAN;
      list : lists.TPStringStringList := NIL;
      map : maps.TPStringStringMap := NIL;
      parameter : StringsO.CString;
      parameters : lists.CStringStringList;
      ps : StringsO.TPString;
      sindex1, sindex2 : StringsO.CString;
   BEGIN
      i := model.IndexOfOA( L".", 0 );
      IF i > 0 THEN // ok, find in map or list by key
         IF GetMapOA( OA( i-1, model.rawData ), OUT map ) THEN
            // fall down
         ELSIF GetListOA( OA( i-1, model.rawData ), OUT list ) THEN
            // fall down
         END;
         IF ( map = NIL ) AND ( list = NIL ) THEN
            GOTO Error;
         END;
         model.Substring( i+1, -1, OUT sindex1 );            
         IF NOT GetModelValue( sindex1, OUT sindex2 ) THEN
            sindex2 := sindex1;
         END;
         sindex2.Trim();
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
         i := model.IndexOfOA( L"<", 0 );
         IF i > 0 THEN // ok, find in map or list
            index := -1;
            j := model.IndexOfOA( L">", i+1 );
            IF j = -1 THEN
               GOTO Error;
            END;
            keyIndex := TRUE;
         END;
      END;
      IF valueIndex OR keyIndex THEN
         model.Substring( i+1, j-i-1, OUT sindex1 );
         IF NOT GetModelValue( sindex1, OUT sindex2 ) THEN
            sindex2 := sindex1;
         END;
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
      
      // test function
      i := model.IndexOfOA( L"(", 0 );
      IF i > 0 THEN
         j := model.IndexOfOA( L")", i+1 );
         IF j = -1 THEN
            GOTO Error;
         END;
         model.Remove( j, -1 );
         model.Substring( 0, i, OUT sindex1 );
         sindex1.Trim();
         IF GetFunctionHandlerOA( OA( sindex1.Length-1, sindex1.rawData ), OUT functionHandler ) THEN
            ii := i+1;
            LOOP
               ii := model.ItemS( StringsO.WCHARS{L' ', L','}, ii, 0, TRUE, OUT sindex2 );
               IF NOT GetModelValue( sindex2, OUT parameter ) THEN
                  parameter := sindex2;
               END;
               parameter.Trim();
               parameters.Add( empty, parameter );
               IF ii = -1 THEN
                  EXIT;
               END;
            END; // LOOP
            boolean := functionHandler^.Call( sindex1, REF parameters, ADR( value ));
            CallMemo := CallMemo OR boolean;
            RETURN boolean;
         END; // IF function found
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
      RETURN FALSE;
   END GetModelValue;

(*--------------------------------------------------------------------------------*)

   PUBLIC VIRTUAL PROCEDURE Format( FailOnError : BOOLEAN; CONST Source : StringsO.IString; MessageSource : TPMessageSource; language : Languages.TLanguage; OUT Formatted : StringsO.IString ) : BOOLEAN; // main format method, replaces view syntax with model data
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

         // message model
         IF ( MessageSource <> NIL ) AND model.StartsWithOA( L"msg." ) THEN
            model.Remove( 0, 4 ); // delete "msg."
            IF NOT MessageSource^.GetMessage( language, model, OUT value ) THEN
               IF FailOnError THEN
                  RETURN FALSE;
               ELSE
                  value.FromOA( L'##unknown message: ' ); value.Append( model );
               END;
            END;
         // generic model
         ELSE
            IF NOT GetModelValue( model, OUT value ) AND FailOnError THEN
               RETURN FALSE;
            END;
         END;
         Formatted.Remove( i, j-i+1 );
         Formatted.Insert( i, value );
      END; // LOOP
   END Format;

(*--------------------------------------------------------------------------------*)

   // There can be more active mappings, each identified by SetId. It e.g. can be controller name, or so, always that way, to one would be easily able to identify to which controller/view the set and its data belongs.
   PUBLIC VIRTUAL PROCEDURE ResetModelInViewNames( CONST ControllerURI : StringsO.IString ); // clears all mode-view bindings corresponding to SetId
   VAR
      LSetId : StringsO.CString;
   BEGIN
      LSetId.FromOA( VIEW_MAPPER );
      LSetId.Append( ControllerURI );
      RemoveOA( OA( LSetId.Length-1, LSetId.rawData ));
   END ResetModelInViewNames;

(*--------------------------------------------------------------------------------*)

   PUBLIC VIRTUAL PROCEDURE SetModelInViewName( CONST ControllerURI, FullModel, InViewName : StringsO.IString ); // stores logical name used in view output together with full model accessor
   VAR
      LSetId : StringsO.CString;
      mapper : maps.TPStringStringMap;
   BEGIN
      LSetId.FromOA( VIEW_MAPPER );
      LSetId.Append( ControllerURI );
      IF NOT GetMapOA( OA( LSetId.Length-1, LSetId.rawData ), OUT mapper ) THEN
         AddMapOA( OA( LSetId.Length-1, LSetId.rawData ), OUT mapper );
      END;
      mapper^.Add( InViewName, FullModel );
   END SetModelInViewName;

(*--------------------------------------------------------------------------------*)

   PUBLIC VIRTUAL PROCEDURE GetModelByInViewName( CONST ControllerURI, InViewName : StringsO.IString; OUT FullModel : StringsO.IString ) : BOOLEAN; // gets model name by logical name used in view
   VAR
      LSetId : StringsO.CString;
      mapper : maps.TPStringStringMap;
   BEGIN
      LSetId.FromOA( VIEW_MAPPER );
      LSetId.Append( ControllerURI );
      IF NOT GetMapOA( OA( LSetId.Length-1, LSetId.rawData ), OUT mapper ) THEN
         RETURN FALSE;
      ELSIF NOT mapper^.Get( InViewName, OUT FullModel ) THEN
         RETURN FALSE;
      ELSE
         RETURN TRUE;
      END;
   END GetModelByInViewName;

(*--------------------------------------------------------------------------------*)

BEGIN FINALLY
   Dispose();
END CContainer;

(*================================================================================*)

CLASS CHttpRequest IMPLEMENTS IHttpRequest;

   // IHttpRequest
   PUBLIC VIRTUAL READONLY PROPERTY
      RequestVerb : HttpCommon.TVerb;
      FullURI : StringsO.CString;
      AbsoluteURI : StringsO.CString;
      ControllerURI : StringsO.CString;
      RequestHeaders : HttpCommon.TPHttpHeaders;
      ResponseHeaders : HttpCommon.TPHttpHeaders;
      Language : Languages.TLanguage;
      ModelContainer : TPContainer;
      Session : HttpSrv.TPSession;
      MessageSource : TPMessageSource; // messages are loaded single time for MVC's context, can be NIL
      
   PUBLIC VIRTUAL PROCEDURE TestConditions( CONST ResourceLastModified : time.DateTime; CONST ResourceName : StringsO.IString ) : HttpCommon.THttpResponse; // returns suggested status -- 200, 304 of 412

   // SELF
   PRIVATE VAR
      _Connection : HttpConnection.TPHttpSrvConnection;
      _Session : HttpSrv.TPSession;
      _ControllerURI : StringsO.CString;
      _Container : TPContainer;
      _MessageSource : TPMessageSource;
      _Language : Languages.TLanguage;

   LOCAL PROCEDURE Init( CONST RequestURI : StringsO.CString; Connection : HttpConnection.TPHttpSrvConnection; CONST Session : HttpSrv.TPSession; CONST Container : TPContainer;  CONST MessageSource : TPMessageSource );

END CHttpRequest;

(*--------------------------------------------------------------------------------*)

CLASS IMPLEMENTATION CHttpRequest;

(*--------------------------------------------------------------------------------*)

   PUBLIC VIRTUAL PROPERTY RequestVerb GET : HttpCommon.TVerb;
   BEGIN
      RETURN _Connection^.RequestVerb;
   END RequestVerb;

(*--------------------------------------------------------------------------------*)

   PUBLIC VIRTUAL PROPERTY FullURI GET : StringsO.CString;
   BEGIN
      RETURN _Connection^.FullURI;
   END FullURI;

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

   PUBLIC VIRTUAL PROPERTY Language GET : Languages.TLanguage;
   VAR
      acceptLanguage : StringsO.CString;
   BEGIN
      IF _Language <> -1 THEN
         // fall down
      ELSIF NOT RequestHeaders^.Get( HttpCommon.AcceptLanguage, OUT acceptLanguage ) THEN
         _Language := 0;
      ELSIF NOT HttpTools.DecodeLanguage( acceptLanguage, OUT _Language ) THEN
         _Language := 0;
      END;
      RETURN _Language;
   END Language;

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

   PUBLIC VIRTUAL PROPERTY MessageSource GET : TPMessageSource;
   BEGIN
      RETURN _MessageSource;
   END MessageSource;

(*--------------------------------------------------------------------------------*)

   PUBLIC VIRTUAL PROCEDURE TestConditions( CONST ResourceLastModified : time.DateTime; CONST ResourceName : StringsO.IString ) : HttpCommon.THttpResponse; // returns suggested status -- 200, 304 of 412
   BEGIN
      IF _Connection^.Stream^ INHERITS SrvCommon.ASrvStream THEN
         RETURN SrvCommon.TPSrvStream( _Connection^.Stream )^.TestConditions( ResourceLastModified, ResourceName );
      END;
      ASSERTLOG( FALSE, L"Unable to test HTTP condition." );
      RETURN HttpCommon.httpres_500;
   END TestConditions;

(*--------------------------------------------------------------------------------*)

   LOCAL PROCEDURE Init( CONST ControllerURI : StringsO.CString; Connection : HttpConnection.TPHttpSrvConnection; CONST Session : HttpSrv.TPSession; CONST Container : TPContainer; CONST MessageSource : TPMessageSource );
   BEGIN
      _ControllerURI := ControllerURI;
      _Connection := Connection;
      _Session := Session;
      _Container := Container;
      _MessageSource := MessageSource;
   END Init;

(*--------------------------------------------------------------------------------*)

BEGIN
   _Connection := NIL;
   _Session := NIL;
   _Container := NIL;
   _MessageSource := NIL;
   _Language := -1;
END CHttpRequest;

(*================================================================================*)

CLASS CHttpResponse IMPLEMENTS IHttpResponse;

   // IHttpRequest
   PUBLIC VIRTUAL PROPERTY
      StatusCode : HttpCommon.THttpResponse;
      Length : CARD64; // default none
      ContentType : StringsO.CString; // default none
      Chunked : BOOLEAN; // default FALSE
      OverrideStatusResponse : BOOLEAN; // default FALSE
      AllowCaching : BOOLEAN;
      LastModified : time.DateTime;

   PUBLIC VIRTUAL READONLY PROPERTY
      ResponseHeaders : HttpCommon.TPHttpHeaders;
      ModelContainer : TPContainer;
      Session : HttpSrv.TPSession;
      
   // SELF
   PRIVATE VAR
      _Connection : HttpConnection.TPHttpSrvConnection;
      _Session : HttpSrv.TPSession;
      _Container : TPContainer;

   LOCAL PROCEDURE Init( Connection : HttpConnection.TPHttpSrvConnection; CONST Session : HttpSrv.TPSession; CONST Container : TPContainer );

END CHttpResponse;

(*--------------------------------------------------------------------------------*)

CLASS IMPLEMENTATION CHttpResponse;

(*--------------------------------------------------------------------------------*)

   PUBLIC VIRTUAL PROPERTY StatusCode GET : HttpCommon.THttpResponse;
   BEGIN
      RETURN _Connection^.StatusCode;
   END StatusCode;

(*--------------------------------------------------------------------------------*)

   PUBLIC VIRTUAL PROPERTY StatusCode SET( Value : HttpCommon.THttpResponse );
   BEGIN
      _Connection^.StatusCode := Value;
   END StatusCode;

(*--------------------------------------------------------------------------------*)

   PUBLIC VIRTUAL PROPERTY Length GET : CARD64;
   BEGIN
      RETURN _Connection^.ResponseLength;
   END Length;

(*--------------------------------------------------------------------------------*)

   PUBLIC VIRTUAL PROPERTY Length SET( Value : CARD64 );
   BEGIN
      _Connection^.ResponseLength := Value;
   END Length;

(*--------------------------------------------------------------------------------*)

   PUBLIC VIRTUAL PROPERTY ContentType GET : StringsO.CString;
   VAR
      Value : StringsO.CString;
   BEGIN
      _Connection^.ResponseHeaders^.Get( HttpCommon.ContentType, OUT Value );
      RETURN Value;
   END ContentType;

(*--------------------------------------------------------------------------------*)

   PUBLIC VIRTUAL PROPERTY ContentType SET( CONST Value : StringsO.CString );
   BEGIN
      _Connection^.ResponseHeaders^.Add( HttpCommon.ContentType, Value );
   END ContentType;

(*--------------------------------------------------------------------------------*)

   PUBLIC VIRTUAL PROPERTY Chunked GET : BOOLEAN;
   BEGIN
      RETURN _Connection^.Chunked;
   END Chunked;

(*--------------------------------------------------------------------------------*)

   PUBLIC VIRTUAL PROPERTY OverrideStatusResponse SET( Value : BOOLEAN );
   BEGIN
      _Connection^.OverrideStatusResponse := Value;
   END OverrideStatusResponse;

(*--------------------------------------------------------------------------------*)

   PUBLIC VIRTUAL PROPERTY OverrideStatusResponse GET : BOOLEAN;
   BEGIN
      RETURN _Connection^.OverrideStatusResponse;
   END OverrideStatusResponse;

(*--------------------------------------------------------------------------------*)

   PUBLIC VIRTUAL PROPERTY AllowCaching GET : BOOLEAN;
   BEGIN
      RETURN _Connection^.AllowCaching;
   END AllowCaching;

(*--------------------------------------------------------------------------------*)

   PUBLIC VIRTUAL PROPERTY AllowCaching SET( Value : BOOLEAN );
   BEGIN
      _Connection^.AllowCaching := Value;
   END AllowCaching;

(*--------------------------------------------------------------------------------*)

   PUBLIC VIRTUAL PROPERTY LastModified GET : time.DateTime;
   BEGIN
      RETURN _Connection^.LastModified;
   END LastModified;

(*--------------------------------------------------------------------------------*)

   PUBLIC VIRTUAL PROPERTY LastModified SET( CONST Value : time.DateTime );
   BEGIN
      _Connection^.LastModified := Value;
   END LastModified;

(*--------------------------------------------------------------------------------*)

   PUBLIC VIRTUAL PROPERTY Chunked SET( Value : BOOLEAN );
   BEGIN
      _Connection^.Chunked := Value;
   END Chunked;

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
END CHttpResponse;

(*================================================================================*)

CLASS CMVC IMPLEMENTS HttpSrv.IHttpProcessor, IMessageSource, IMVC;

   // IHttpProcessor
   PUBLIC VIRTUAL READONLY PROPERTY
      RequestLogger : Log.TPILogger;
   PUBLIC VIRTUAL PROCEDURE AppliesFor( Verb : HttpCommon.TVerb; CONST URL : ARRAY OF WCHAR; OUT WantsSession : BOOLEAN ) : BOOLEAN;
   PUBLIC VIRTUAL PROCEDURE AllowedFor( Connection : HttpConnection.TPHttpSrvConnection ) : BOOLEAN;
   PUBLIC VIRTUAL PROCEDURE ProcessRequest( Connection : HttpConnection.TPHttpSrvConnection; CONST Session : HttpSrv.TPSession );
   PUBLIC VIRTUAL PROCEDURE SessionExpired( CONST Session : HttpSrv.TPSession );
   
   // IMessageSource
   PUBLIC VIRTUAL PROCEDURE GetMessage( language : Languages.TLanguage; CONST Key : StringsO.IString; OUT Message : StringsO.IString ) : BOOLEAN;
   PUBLIC VIRTUAL PROCEDURE GetMessageOA( language : Languages.TLanguage; CONST Key : ARRAY OF WCHAR; OUT Message : StringsO.IString ) : BOOLEAN;

   // IMVC
   PUBLIC VIRTUAL PROCEDURE RegisterController( Controller : TPController; ForVerb : HttpCommon.TVerb; CONST URL : ARRAY OF WCHAR ); // controller can be registered more times for different Verb and URI
   PUBLIC VIRTUAL PROCEDURE ForgetController( Controller : TPController; OfVerb : HttpCommon.TVerb; CONST URL : ARRAY OF WCHAR );
   PUBLIC VIRTUAL PROCEDURE ForgetControllerCompletely( Controller : TPController );

   PUBLIC VIRTUAL PROCEDURE RegisterFallbackController( Controller : TPController ); // for GET only, for all URIs, intended mainlt for static sources like files etc.
   PUBLIC VIRTUAL PROCEDURE ForgetFallbackController();

   PUBLIC VIRTUAL PROPERTY
      MessageSourcePath : StringsO.CString;
      Logger : Log.TPILogger;
      AccessList : accesslist.TPAccessList;

   // SELF
   PUBLIC PROCEDURE Init( CONST Context : StringsO.CString );
   
   PRIVATE VAR
      _Running : BOOLEAN := FALSE;
      _Context : StringsO.CString;
      _Controllers : syncmaps.CStringSyncMap;
      _FallbackController : TPController;
      _MessageSourcePath : StringsO.CString;
      _Messages : Resources.TPPlainResources;
      _MessagesLock : Sync.LOCK;
      _Logger : Log.TPILogger := NIL;
      _AccessList : accesslist.TPAccessList := NIL;

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

   PUBLIC VIRTUAL PROPERTY RequestLogger GET : Log.TPILogger;
   BEGIN
      RETURN _Logger;
   END RequestLogger;

//--------------------------------------------------------------------------------

   PUBLIC VIRTUAL PROCEDURE AppliesFor( Verb : HttpCommon.TVerb; CONST URL : ARRAY OF WCHAR; OUT WantsSession : BOOLEAN ) : BOOLEAN;
   VAR
      l : CARDINAL;
   BEGIN
      IF ( Verb <> HttpCommon.verbGET ) AND ( Verb <> HttpCommon.verbPOST ) THEN
         RETURN FALSE;
      END;
      
      l := _Context.Length;
      IF Strings.StartsWithW( URL, OA( l-1, _Context.rawData )) THEN // URL = .../Context/...
         WantsSession := TRUE;
         RETURN TRUE;
      ELSIF l < 2 THEN
         RETURN FALSE;
      ELSIF Strings.EndsWithW( URL, OA( l-2, _Context.rawData )) THEN // URL = .../Context
         WantsSession := TRUE;
         RETURN TRUE;
      ELSE
         RETURN FALSE;
      END;
   END AppliesFor;

//--------------------------------------------------------------------------------

   PUBLIC VIRTUAL PROCEDURE AllowedFor( Connection : HttpConnection.TPHttpSrvConnection ) : BOOLEAN;
   BEGIN
      IF _AccessList = NIL THEN
         RETURN TRUE;
      ELSE
         RETURN _AccessList^.AllowedForConnection( Connection );
      END;
   END AllowedFor;

//--------------------------------------------------------------------------------

   PUBLIC VIRTUAL PROCEDURE ProcessRequest( Connection : HttpConnection.TPHttpSrvConnection; CONST Session : HttpSrv.TPSession );
   VAR
      buffer : StorageO.CMemoryBuffer;
      connectionData : lists.CStringStringList;
      controller : TPController;
      controllerURI : StringsO.CString;
      containerMap : syncmaps.TPPtrSyncMap;
      container : POINTER TO CContainer;
      fallbackFlag : BOOLEAN := FALSE;
      InputStream : IOO.TPStream;
      l : CARDINAL;
      mappedName : StringsO.CString;
      modelValue : StringsO.CString;
      request : CHttpRequest;
      response : CHttpResponse;
      Result : Sync.TAsyncResult;
      view : TPView;
   BEGIN
      controllerURI := Connection^.RequestURI;
      controllerURI.Remove( 0, _Context.Length ); // remove context leading

      IF LookupController( Connection^.RequestVerb, OA( controllerURI.Length-1, controllerURI.rawData ), OUT controller ) THEN
         // fall down
      ELSIF ( _FallbackController = NIL ) OR ( Connection^.RequestVerb = HttpCommon.verbPOST ) THEN // fallback works for POST only
         Connection^.StatusCode := HttpCommon.httpres_404;
         RETURN;
      ELSE
         fallbackFlag := TRUE;
         controller := _FallbackController;
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
      container^.ResetFunctionCallsMemo();
      connectionData.Reset();
      WHILE connectionData.MoveNext() DO
         IF container^.GetModelByInViewName( controllerURI, connectionData.Current^, OUT mappedName ) THEN
            container^.SetModelValue( mappedName, connectionData.CurrentData^ );
         ELSIF ( Connection^.RequestVerb <> HttpCommon.verbPOST ) AND // for GET driving by URI parameter is allowed...
               container^.GetModelValue( connectionData.Current^, OUT modelValue ) THEN // ...only if the parameter is known
            container^.SetModelValue( connectionData.Current^, connectionData.CurrentData^ );
         END;
      END; // WHILE
      connectionData.Dispose();
      
      // prepare controller data
      request.Init( controllerURI, Connection, Session, container, ADR( SELF ));
      response.Init( Connection, Session, container );
      buffer.Size := 16384; // initial size
      view := NIL;
      
      IF NOT controller^.ProcessRequest( fallbackFlag, request, OUT view ) THEN
         Connection^.StatusCode := HttpCommon.httpres_500;
      ELSIF view = NIL THEN
         Connection^.StatusCode := HttpCommon.httpres_500;
         _Logger^.LogS( Log.dlcError, L"MVC", L"Controller returned TRUE but it did not prepare View." );
         ASSERTLOG( FALSE, L"Controller returned TRUE but it did not prepare View." );
      ELSE
         Connection^.StatusCode := HttpCommon.httpres_200;
         
         CASE view^.OutputType OF
         //-----
         | votBuffer :
            IF NOT view^.FormatToBuffer( request, REF response, OUT buffer ) THEN
               Connection^.StatusCode := HttpCommon.httpres_500;
            ELSIF buffer.Empty THEN
               Connection^.ResponseLength := 0;
            ELSE
               Connection^.ResponseLength := CARD64( buffer.Length );
               Result := Connection^.Stream^.WriteBuffer( buffer, OUT l, netsocket.FORSAFETY );
               IF Result NOT IN Sync.arsCompletions THEN
                  _Logger^.LogS( Log.dlcError, L"MVC", L"Failure when writing output buffer to stream." );
               END;
            END;
         //-----
         | votInputStream :

            ASSERTLOG( FALSE ); // NOT IMPLEMENTED YET
            Connection^.StatusCode := HttpCommon.httpres_500;
            RETURN;

            IF NOT view^.FormatToInputStream( request, REF response, OUT InputStream ) OR ( InputStream = NIL ) THEN
               InputStream := NIL;
               Connection^.StatusCode := HttpCommon.httpres_500;
            ELSE
               // TODO copy streams
            END;
            IF InputStream <> NIL THEN
               InputStream^.Close( FALSE );
               DISPOSE( InputStream );
            END;
         //-----
         | votOutputStream :
            IF NOT view^.FormatToOutputStream( request, REF response, Connection^.Stream ) THEN
               Connection^.StatusCode := HttpCommon.httpres_500;
               _Logger^.LogS( Log.dlcError, L"MVC", L"Failure when formatting View to output stream." );
            END;
         ELSE
            ASSERTLOG( FALSE );
         END;         

         view^.Release();
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

   PUBLIC VIRTUAL PROCEDURE GetMessage( language : Languages.TLanguage; CONST Key : StringsO.IString; OUT Message : StringsO.IString ) : BOOLEAN;
   VAR
      b : BOOLEAN := FALSE;
      e : ARRAY [0..3] OF WCHAR;
      length : CARDINAL;
      text : PWCHAR;
   BEGIN
      _MessagesLock.Lock();
      IF _Messages = NIL THEN
         NEW( _Messages );
         b := _Messages^.LoadXML( OA( _MessageSourcePath.Length-1, _MessageSourcePath.rawData ), OUT e );
         IF b THEN
            _Messages^.FallbackLang := _Messages^.Lang;
         END;
      ELSE
         b := TRUE;
      END;
      IF b THEN
         b := _Messages^.GetTextByKeyL( language, Key, OUT text, OUT length );
      END;
      IF b THEN
         Message.FromOA( OA( length-1, text ));
      ELSE
         Message.Assign( Key );
      END;
      _MessagesLock.Unlock();

      RETURN b;
   END GetMessage;

//--------------------------------------------------------------------------------

   PUBLIC VIRTUAL PROCEDURE GetMessageOA( language : Languages.TLanguage; CONST Key : ARRAY OF WCHAR; OUT Message : StringsO.IString ) : BOOLEAN;
   VAR
      s : StringsO.CString;
   BEGIN
      s.FromOA( Key );
      RETURN GetMessage( language, s, OUT Message );
   END GetMessageOA;

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
         ASSERTLOG( FALSE );
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

   PUBLIC VIRTUAL PROCEDURE RegisterFallbackController( Controller : TPController );
   BEGIN
      _FallbackController := Controller;
   END RegisterFallbackController;

//--------------------------------------------------------------------------------

   PUBLIC VIRTUAL PROCEDURE ForgetFallbackController();
   BEGIN
      _FallbackController := NIL;
   END ForgetFallbackController;

//--------------------------------------------------------------------------------

   PUBLIC VIRTUAL PROPERTY MessageSourcePath GET : StringsO.CString;
   BEGIN
      RETURN _MessageSourcePath;
   END MessageSourcePath;

//--------------------------------------------------------------------------------

   PUBLIC VIRTUAL PROPERTY MessageSourcePath SET( CONST Value : StringsO.CString );
   BEGIN
      IF _MessageSourcePath = Value THEN
         RETURN;
      END;
      IF _Messages <> NIL THEN // messages will load on demand later
         DISPOSE( _Messages );
      END;
      _MessageSourcePath := Value;
   END MessageSourcePath;

//--------------------------------------------------------------------------------

   PUBLIC VIRTUAL PROPERTY Logger GET : Log.TPILogger;
   BEGIN
      RETURN _Logger;
   END Logger;

//--------------------------------------------------------------------------------

   PUBLIC VIRTUAL PROPERTY Logger SET( Value : Log.TPILogger );
   BEGIN
      IF _Logger = Value THEN
         RETURN;
      ELSIF Value = NIL THEN
         _Logger := Log.logger();
      ELSE
         _Logger := Value;
      END;
   END Logger;

//--------------------------------------------------------------------------------

   PUBLIC PROPERTY AccessList GET : accesslist.TPAccessList;
   BEGIN
      RETURN _AccessList;
   END AccessList;

//--------------------------------------------------------------------------------

   PUBLIC PROPERTY AccessList SET( Value : accesslist.TPAccessList );
   BEGIN
      _AccessList := Value;
   END AccessList;

//--------------------------------------------------------------------------------

   PUBLIC PROCEDURE Init( CONST Context : StringsO.CString );
   BEGIN
      _Context := Context;
   END Init;

//--------------------------------------------------------------------------------

   PUBLIC PROCEDURE Dispose();
   BEGIN
      _Controllers.Dispose();
      IF _Messages <> NIL THEN
         DISPOSE( _Messages );
      END;
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
      Data : StringsO.CString;
      i : CARDINAL;
   BEGIN
      Data := Connection^.URIData;
      IF Data.Empty THEN
         RETURN;
      END;
      LanguagesO.ToMB( Data, 0, FALSE, REF byteBuffer );

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

      HttpTools.DecodeURLEncoding( TRUE, OA( byteBuffer.Length-1, byteBuffer.Data ), OUT list );
   END DecodeDataFromContent;

//--------------------------------------------------------------------------------

BEGIN
   _FallbackController := NIL;
   _Messages := NIL;
   _Logger := Log.logger();
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
         Log.logger()^.LogS( Log.dlcError, L"MVC", L"Client requests unnamed context." );
         ASSERTLOG( FALSE );
         s.FromOA( L" bad context" );
      ELSE
         s.FromOA( context );
      END;
      
      // remove leading and add trailing slashes
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

PROCEDURE httpStatusCodeView( StatusCode : HttpCommon.THttpResponse ) : TPView;
VAR
   view : View.TPStatusCodeView;
BEGIN
   NEW( view );
   view^.Init( StatusCode );
   RETURN view;
END httpStatusCodeView;

//--------------------------------------------------------------------------------

PROCEDURE fileView( CONST resolver : FSO.TPFilePathResolver; resolverContext : PTR; CONST PathRelativeToContext : ARRAY OF WCHAR; dispositionFlag : BOOLEAN; CONST mimeResolver : TPMIMEResolver; mimeResolverContext : PTR ) : TPView;
VAR
   view : View.TPFileView;
BEGIN
   NEW( view );
   view^.Init( resolver, resolverContext, PathRelativeToContext, dispositionFlag, mimeResolver, mimeResolverContext );
   RETURN view;
END fileView;

//--------------------------------------------------------------------------------

PROCEDURE absoluteRedirectView( CONST FullURI : ARRAY OF WCHAR ) : TPView;
VAR
   view : View.TPRedirectView;
BEGIN
   NEW( view );
   view^.Init( TRUE, FullURI );
   RETURN view;
END absoluteRedirectView;

//--------------------------------------------------------------------------------

PROCEDURE redirectView( CONST ControllerName : ARRAY OF WCHAR ) : TPView;
VAR
   view : View.TPRedirectView;
BEGIN
   NEW( view );
   view^.Init( FALSE, ControllerName );
   RETURN view;
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

PROCEDURE rawTextView( CONST text, downloadName : ARRAY OF WCHAR; CONST content : StringsO.IString; dispositionFlag : BOOLEAN ) : TPView; // if content is empty, default one is used
VAR
   view : View.TPRawTextView;
BEGIN
   NEW( view );
   view^.Init( text, downloadName, content, dispositionFlag );
   RETURN view;
END rawTextView;

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