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
   
TYPE
   TModelType = (
      mtUnknown,
      mtQualification,
      mtKey,
      mtValueKey,
      mtCall
   );

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
   PUBLIC VIRTUAL PROCEDURE AddFunctionHandlerOA( CONST Name : ARRAY OF WCHAR; Handler : TPFunctionHandler );

   PUBLIC VIRTUAL PROCEDURE AddVariable( CONST Name : ARRAY OF WCHAR; CONST Model : StringsO.IString ); // for in-view processing

   PUBLIC VIRTUAL PROCEDURE GetBooleanOA( CONST Name : ARRAY OF WCHAR; OUT Model : BOOLEAN ) : BOOLEAN;
   PUBLIC VIRTUAL PROCEDURE GetStringOA( CONST Name : ARRAY OF WCHAR; OUT Model : StringsO.IString ) : BOOLEAN;
   PUBLIC VIRTUAL PROCEDURE GetListOA( CONST Name : ARRAY OF WCHAR; OUT Model : lists.TPStringStringList ) : BOOLEAN;
   PUBLIC VIRTUAL PROCEDURE GetMapOA( CONST Name : ARRAY OF WCHAR; OUT Model : maps.TPStringStringMap ) : BOOLEAN;
   PUBLIC VIRTUAL PROCEDURE GetFunctionHandlerOA( CONST Name : ARRAY OF WCHAR; OUT Handler : TPFunctionHandler ) : BOOLEAN;

   PUBLIC VIRTUAL PROCEDURE SetModelValue( CONST Request : IHttpRequest; CONST Model, Value : StringsO.IString; PFunctionCalled : PBOOLEAN ) : BOOLEAN; // main methods for accessing, it solves indexes, points, etc. in names
   PUBLIC VIRTUAL PROCEDURE GetModelValue( CONST Request : IHttpRequest; CONST Model : StringsO.IString; OUT Value : StringsO.IString; PFunctionCalled : PBOOLEAN ) : BOOLEAN; // main methods for accessing, it solves indexes, points, etc. in names
   PUBLIC VIRTUAL PROCEDURE Format( CONST Request : IHttpRequest; FailOnError : BOOLEAN; CONST Source : StringsO.IString; MessageSource : TPMessageSource; language : Languages.TLanguage; OUT Formatted : StringsO.IString ) : BOOLEAN; // main format method, replaces view syntax with model data

   // There can be more active mappings, each identified by ControllerURI.
   PUBLIC VIRTUAL PROCEDURE ResetModelInViewNames( CONST ControllerURI : StringsO.IString ); // clears all mode-view bindings corresponding to SetId
   PUBLIC VIRTUAL PROCEDURE SetModelInViewName( CONST ControllerURI, FullModel, InViewName : StringsO.IString ); // stores logical name used in view output together with full model accessor
   PUBLIC VIRTUAL PROCEDURE GetModelByInViewName( CONST ControllerURI, InViewName : StringsO.IString; OUT FullModel : StringsO.IString ) : BOOLEAN; // gets model name by logical name used in view
   PUBLIC VIRTUAL PROCEDURE ResetModelValues( CONST Request : IHttpRequest; CONST ControllerURI : StringsO.IString );
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
         | L"s",
           L"v" :
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

   PUBLIC VIRTUAL PROCEDURE AddVariable( CONST Name : ARRAY OF WCHAR; CONST Model : StringsO.IString ); // for in-view processing
   VAR
      model : POINTER TO StringsO.CString;
      name : StringsO.CString;
   BEGIN
      name.FromOA( L"v." );
      name.AppendOA( Name );
      IF NOT Models.Get( name, OUT model ) THEN
         NEW( model );
         Models.Add( name, model );
      END;
      model^.Assign( Model );
   END AddVariable;

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
     // try model string
      name.FromOA( L"s." );
      name.AppendOA( Name );
      IF Models.Get( name, OUT model ) THEN
         Model.Assign( model^ );
         RETURN TRUE;
      END;
      // try variable
      name.FromOA( L"v." );
      name.AppendOA( Name );
      IF Models.Get( name, OUT model ) THEN
         Model.Assign( model^ );
         RETURN TRUE;
      END;
      // no variable nor string found
      RETURN FALSE;
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

   PUBLIC VIRTUAL PROCEDURE SetModelValue( CONST Request : IHttpRequest; CONST model, value : StringsO.IString; PFunctionCalled : PBOOLEAN ) : BOOLEAN; // main methods for accessing, it solves indexes, points, etc. in names
   LABEL
      Error;
   VAR
      boolean : BOOLEAN;
      empty : StringsO.CString;
      functionHandler : TPFunctionHandler;
      i, ii, index, j : INTEGER;
      lvalue : StringsO.CString;
      list : lists.TPStringStringList := NIL;
      map : maps.TPStringStringMap := NIL;
      modelType : TModelType := mtUnknown;
      parameter : StringsO.CString;
      parameters : lists.CStringStringList;
      ps : StringsO.TPString;
      sindex1, sindex2 : StringsO.CString;
   BEGIN
      IF PFunctionCalled <> NIL THEN
         PFunctionCalled^ := FALSE;
      END;
   
      i := model.IndexOfAnyS( StringsO.WCHARS{L".", L"[", L"<", L"("}, 0 );
      IF i <> -1 THEN // assign model kind
         CASE model[i] OF
         | L"." : modelType := mtQualification;
         | L"[" : modelType := mtKey;
         | L"<" : modelType := mtValueKey;
         | L"(" : modelType := mtCall;
         END; // CASE
      END;

      CASE modelType OF
      //-----
      | mtQualification : // ok, find in map or list by key
         IF GetMapOA( OA( i-1, model.Data ), OUT map ) THEN
            // fall down
         ELSIF GetListOA( OA( i-1, model.Data ), OUT list ) THEN
            // fall down
         END;
         IF ( map = NIL ) AND ( list = NIL ) THEN
            GOTO Error;
         END;
         model.Substring( i+1, -1, OUT sindex1 );            
         IF NOT GetModelValue( Request, sindex1, OUT sindex2, NIL ) THEN
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

      //-----
      | mtKey, mtValueKey :
         IF modelType = mtKey THEN
            j := model.IndexOfOA( L"]", i+1 );
         ELSE
            j := model.IndexOfOA( L">", i+1 );
         END;
         IF j = -1 THEN
            GOTO Error;
         END;

         model.Substring( i+1, j-i-1, OUT sindex1 );
         IF NOT GetModelValue( Request, sindex1, OUT sindex2, NIL ) THEN
            sindex2 := sindex1;
         END;
         sindex2.Trim();
         IF NOT Strings.ToINT32W( OA( sindex2.Length-1, sindex2.Data ), 10, OUT index ) THEN
            GOTO Error;

         ELSIF GetMapOA( OA( i-1, model.Data ), OUT map ) THEN
            IF modelType = mtValueKey THEN
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

         ELSIF GetListOA( OA( i-1, model.Data ), OUT list ) THEN
            IF modelType = mtKey THEN
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

         // ELSE fall down to error
         END;

      //-----
      | mtCall :
         j := model.IndexOfOA( L")", i+1 );
         IF j = -1 THEN
            GOTO Error;
         END;

         model.Substring( 0, i, OUT sindex1 );
         sindex1.Trim();
         IF GetFunctionHandlerOA( OA( sindex1.Length-1, sindex1.Data ), OUT functionHandler ) THEN
            ii := i+1;
            LOOP
               ii := model.ItemS( StringsO.WCHARS{L' ', L','}, ii, 0, TRUE, OUT sindex2 );
               IF NOT GetModelValue( Request, sindex2, OUT parameter, NIL ) THEN
                  parameter := sindex2;
               END;
               parameter.Trim();
               parameters.Add( empty, parameter );
               IF ii = -1 THEN
                  EXIT;
               END;
            END; // LOOP
            boolean := functionHandler^.Call( Request, sindex1, REF parameters, NIL ) IN crsCalled;
            IF PFunctionCalled <> NIL THEN
               PFunctionCalled^ := PFunctionCalled^ OR boolean;
            END;
            RETURN boolean;
            
         // ELSE fall to error
         END; // IF function found

      //-----
      ELSE // mtUnknown or others
         // try boolean      
         IF GetBooleanOA( OA( model.Length-1, model.Data ), OUT boolean ) THEN
            lvalue.Assign( value );
            lvalue.Lowerize();
            AddBooleanOA( OA( model.Length-1, model.Data ), value.EqualsOA( TRUE_STRING ) OR value.EqualsOA( L"1" ) OR value.EqualsOA( L"y" ) OR value.EqualsOA( L"yes" ));

         ELSE // fall to string
            AddStringOA( OA( model.Length-1, model.Data ), value );
         END;
         RETURN TRUE;

      //-----
      END; // CASE

      // emit error      
   Error:
      value.FromOA( L'##unknown model: ' );
      value.Append( model );
      value.AppendOA( L"" );
      RETURN FALSE;
   END SetModelValue;

(*--------------------------------------------------------------------------------*)

   PUBLIC VIRTUAL PROCEDURE GetModelValue( CONST Request : IHttpRequest; CONST model : StringsO.IString; OUT value : StringsO.IString; PFunctionCalled : PBOOLEAN ) : BOOLEAN; // main methods for accessing, it solves indexes, points, etc. in names
   LABEL
      Error;
   VAR
      boolean : BOOLEAN;
      empty : StringsO.CString;
      functionHandler : TPFunctionHandler;
      i, index, j : INTEGER;
      ii : CARDINAL;
      list : lists.TPStringStringList := NIL;
      map : maps.TPStringStringMap := NIL;
      modelType : TModelType := mtUnknown;
      parameter : StringsO.CString;
      parameters : lists.CStringStringList;
      ps : StringsO.TPString;
      sindex1, sindex2 : StringsO.CString;
   BEGIN
      IF PFunctionCalled <> NIL THEN
         PFunctionCalled^ := FALSE;
      END;
   
      i := model.IndexOfAnyS( StringsO.WCHARS{L".", L"[", L"<", L"("}, 0 );
      IF i <> -1 THEN // assign model kind
         CASE model[i] OF
         | L"." : modelType := mtQualification;
         | L"[" : modelType := mtKey;
         | L"<" : modelType := mtValueKey;
         | L"(" : modelType := mtCall;
         END; // CASE
      END;
   
      CASE modelType OF
      //-----
      | mtQualification : // ok, find in map or list by key
         IF GetMapOA( OA( i-1, model.Data ), OUT map ) THEN
            // fall down
         ELSIF GetListOA( OA( i-1, model.Data ), OUT list ) THEN
            // fall down
         END;
         IF ( map = NIL ) AND ( list = NIL ) THEN
            GOTO Error;
         END;
         model.Substring( i+1, -1, OUT sindex1 );            
         IF NOT GetModelValue( Request, sindex1, OUT sindex2, NIL ) THEN
            sindex2 := sindex1;
         END;
         sindex2.Trim();
         IF ( map <> NIL ) AND NOT map^.Get( sindex2, OUT value ) THEN
            GOTO Error;
         ELSIF ( list <> NIL ) AND NOT list^.Get( sindex2, OUT value ) THEN
            GOTO Error;
         END;
         RETURN TRUE;

      //-----
      | mtKey, mtValueKey :
         IF modelType = mtKey THEN
            j := model.IndexOfOA( L"]", i+1 );
         ELSE
            j := model.IndexOfOA( L">", i+1 );
         END;
         IF j = -1 THEN
            GOTO Error;
         END;

         model.Substring( i+1, j-i-1, OUT sindex1 );
         IF NOT GetModelValue( Request, sindex1, OUT sindex2, NIL ) THEN
            sindex2 := sindex1;
         END;
         sindex2.Trim();
         IF NOT Strings.ToINT32W( OA( sindex2.Length-1, sindex2.Data ), 10, OUT index ) THEN
            GOTO Error;

         ELSIF GetMapOA( OA( i-1, model.Data ), OUT map ) THEN
            IF modelType = mtValueKey THEN
               ps := map^[index];
               IF ps = NIL THEN
                  GOTO Error;
               END;
               value.Assign( ps^ );
            ELSIF NOT map^.ElementAt( index, OUT sindex1, OUT value ) THEN
               GOTO Error;
            END;
            RETURN TRUE;

         ELSIF GetListOA( OA( i-1, model.Data ), OUT list ) THEN
            IF modelType = mtKey THEN
               ps := list^[index];
               IF ps = NIL THEN
                  GOTO Error;
               END;
               value.Assign( ps^ );
            ELSIF NOT list^.ElementAt( index, OUT value, OUT sindex1 ) THEN
               GOTO Error;
            END;
            RETURN TRUE;

         // ELSE fall to error
         END;
      
      //-----
      | mtCall :
         j := model.IndexOfOA( L")", i+1 );
         IF j = -1 THEN
            GOTO Error;
         END;

         model.Remove( j, -1 );
         model.Substring( 0, i, OUT sindex1 );
         sindex1.Trim();
         IF GetFunctionHandlerOA( OA( sindex1.Length-1, sindex1.Data ), OUT functionHandler ) THEN
            ii := i+1;
            LOOP
               ii := model.ItemS( StringsO.WCHARS{L' ', L','}, ii, 0, TRUE, OUT sindex2 );
               IF NOT GetModelValue( Request, sindex2, OUT parameter, NIL ) THEN
                  parameter := sindex2;
               END;
               parameter.Trim();
               parameters.Add( empty, parameter );
               IF ii = model.Length THEN
                  EXIT;
               END;
            END; // LOOP
            boolean := functionHandler^.Call( Request, sindex1, REF parameters, ADR( value )) IN crsCalled;
            IF PFunctionCalled <> NIL THEN
               PFunctionCalled^ := PFunctionCalled^ OR boolean;
            END;
            RETURN boolean;
          
         // ELSE fall to error
         END;
   
      //-----
      ELSE // mtUnknown or others
         // test string
         IF GetStringOA( OA( model.Length-1, model.Data ), OUT value ) THEN
            RETURN TRUE;
         
         // test boolean
         ELSIF GetBooleanOA( OA( model.Length-1, model.Data ), OUT boolean ) THEN
            IF boolean THEN
               value.FromOA( TRUE_STRING );
            ELSE
               value.FromOA( FALSE_STRING );
            END;
            RETURN TRUE;

         END;
      //-----
      END; // CASE
      
      // emit error      
   Error:
      value.FromOA( L'##unknown model: ' );
      value.Append( model );
      RETURN FALSE;
   END GetModelValue;

(*--------------------------------------------------------------------------------*)

   PUBLIC VIRTUAL PROCEDURE Format( CONST Request : IHttpRequest; FailOnError : BOOLEAN; CONST Source : StringsO.IString; MessageSource : TPMessageSource; language : Languages.TLanguage; OUT Formatted : StringsO.IString ) : BOOLEAN; // main format method, replaces view syntax with model data
   VAR
      i, mi, j : INTEGER;
      model : StringsO.CString;
      value : StringsO.CString;
   BEGIN
      Formatted.Assign( Source );
      i := 0;
      LOOP
         // get ${
         i := Formatted.IndexOfOA( L"${", i );
         IF i = -1 THEN
            RETURN TRUE;
         ELSIF ( i > 0 ) AND ( Formatted[i-1] = L"\" ) THEN // not pattern
            CONTINUE;
         END;

         // get }
         mi := i + 2;
         j := Formatted.IndexOfOA( L"}", mi );
         IF j = mi THEN
            RETURN FALSE;
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
            IF NOT GetModelValue( Request, model, OUT value, NIL ) AND FailOnError THEN
               RETURN FALSE;
            END;
         END;
         Formatted.Remove( i, j-i+1 );
         Formatted.Insert( i, value );
      END; // LOOP
   END Format;

(*--------------------------------------------------------------------------------*)

   // There can be more active mappings, each identified by ControllerURI. It e.g. can be controller name, or so, always that way, to one would be easily able to identify to which controller/view the set and its data belongs.
   PUBLIC VIRTUAL PROCEDURE ResetModelInViewNames( CONST ControllerURI : StringsO.IString ); // clears all mode-view bindings corresponding to ControllerURI
   VAR
      LSetId : StringsO.CString;
   BEGIN
      LSetId.FromOA( VIEW_MAPPER );
      LSetId.Append( ControllerURI );
      RemoveOA( OA( LSetId.Length-1, LSetId.Data ));
   END ResetModelInViewNames;

(*--------------------------------------------------------------------------------*)

   PUBLIC VIRTUAL PROCEDURE SetModelInViewName( CONST ControllerURI, FullModel, InViewName : StringsO.IString ); // stores logical name used in view output together with full model accessor
   VAR
      LSetId : StringsO.CString;
      mapper : maps.TPStringStringMap;
   BEGIN
      LSetId.FromOA( VIEW_MAPPER );
      LSetId.Append( ControllerURI );
      IF NOT GetMapOA( OA( LSetId.Length-1, LSetId.Data ), OUT mapper ) THEN
         AddMapOA( OA( LSetId.Length-1, LSetId.Data ), OUT mapper );
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
      IF NOT GetMapOA( OA( LSetId.Length-1, LSetId.Data ), OUT mapper ) THEN
         RETURN FALSE;
      ELSIF NOT mapper^.Get( InViewName, OUT FullModel ) THEN
         RETURN FALSE;
      ELSE
         RETURN TRUE;
      END;
   END GetModelByInViewName;

(*--------------------------------------------------------------------------------*)

   PUBLIC VIRTUAL PROCEDURE ResetModelValues( CONST Request : IHttpRequest; CONST ControllerURI : StringsO.IString );
   VAR
      empty : StringsO.CString;
      LSetId : StringsO.CString;
      mapper : maps.TPStringStringMap;
   BEGIN
      LSetId.FromOA( VIEW_MAPPER );
      LSetId.Append( ControllerURI );
      IF GetMapOA( OA( LSetId.Length-1, LSetId.Data ), OUT mapper ) THEN
         mapper^.Reset();
         WHILE mapper^.MoveNext() DO
            SetModelValue( Request, mapper^.CurrentData^, empty, NIL ); // clear model value
         END; // WHILE
      END;
   END ResetModelValues;

(*--------------------------------------------------------------------------------*)

BEGIN FINALLY
   Dispose();
END CContainer;

(*================================================================================*)

CLASS CSynchronizedContainer IMPLEMENTS IContainer;
   PRIVATE VAR
      Container : CContainer;
      Lock : Sync.RWLOCK;

   PUBLIC VIRTUAL PROCEDURE Dispose();
   PUBLIC VIRTUAL PROCEDURE RemoveOA( CONST Name : ARRAY OF WCHAR ); // removes all types

   PUBLIC VIRTUAL PROCEDURE AddBooleanOA( CONST Name : ARRAY OF WCHAR; Model : BOOLEAN );
   PUBLIC VIRTUAL PROCEDURE AddStringOA( CONST Name : ARRAY OF WCHAR; CONST Model : StringsO.IString ); // creates string in model
   PUBLIC VIRTUAL PROCEDURE AddListOA( CONST Name : ARRAY OF WCHAR; OUT Model : lists.TPStringStringList ); // creates list in model
   PUBLIC VIRTUAL PROCEDURE AddMapOA( CONST Name : ARRAY OF WCHAR; OUT Model : maps.TPStringStringMap ); // creates map in model
   PUBLIC VIRTUAL PROCEDURE AddFunctionHandlerOA( CONST Name : ARRAY OF WCHAR; Handler : TPFunctionHandler );

   PUBLIC VIRTUAL PROCEDURE AddVariable( CONST Name : ARRAY OF WCHAR; CONST Model : StringsO.IString ); // for in-view processing

   PUBLIC VIRTUAL PROCEDURE GetBooleanOA( CONST Name : ARRAY OF WCHAR; OUT Model : BOOLEAN ) : BOOLEAN;
   PUBLIC VIRTUAL PROCEDURE GetStringOA( CONST Name : ARRAY OF WCHAR; OUT Model : StringsO.IString ) : BOOLEAN;
   PUBLIC VIRTUAL PROCEDURE GetListOA( CONST Name : ARRAY OF WCHAR; OUT Model : lists.TPStringStringList ) : BOOLEAN;
   PUBLIC VIRTUAL PROCEDURE GetMapOA( CONST Name : ARRAY OF WCHAR; OUT Model : maps.TPStringStringMap ) : BOOLEAN;
   PUBLIC VIRTUAL PROCEDURE GetFunctionHandlerOA( CONST Name : ARRAY OF WCHAR; OUT Handler : TPFunctionHandler ) : BOOLEAN;

   PUBLIC VIRTUAL PROCEDURE SetModelValue( CONST Request : IHttpRequest; CONST Model, Value : StringsO.IString; PFunctionCalled : PBOOLEAN ) : BOOLEAN; // main methods for accessing, it solves indexes, points, etc. in names
   PUBLIC VIRTUAL PROCEDURE GetModelValue( CONST Request : IHttpRequest; CONST Model : StringsO.IString; OUT Value : StringsO.IString; PFunctionCalled : PBOOLEAN ) : BOOLEAN; // main methods for accessing, it solves indexes, points, etc. in names
   PUBLIC VIRTUAL PROCEDURE Format( CONST Request : IHttpRequest; FailOnError : BOOLEAN; CONST Source : StringsO.IString; MessageSource : TPMessageSource; language : Languages.TLanguage; OUT Formatted : StringsO.IString ) : BOOLEAN; // main format method, replaces view syntax with model data

   // There can be more active mappings, each identified by ControllerURI.
   PUBLIC VIRTUAL PROCEDURE ResetModelInViewNames( CONST ControllerURI : StringsO.IString ); // clears all mode-view bindings corresponding to SetId
   PUBLIC VIRTUAL PROCEDURE SetModelInViewName( CONST ControllerURI, FullModel, InViewName : StringsO.IString ); // stores logical name used in view output together with full model accessor
   PUBLIC VIRTUAL PROCEDURE GetModelByInViewName( CONST ControllerURI, InViewName : StringsO.IString; OUT FullModel : StringsO.IString ) : BOOLEAN; // gets model name by logical name used in view
   PUBLIC VIRTUAL PROCEDURE ResetModelValues( CONST Request : IHttpRequest; CONST ControllerURI : StringsO.IString );
   
   PRIVATE PROCEDURE LockWrite() : BOOLEAN;
   PRIVATE PROCEDURE UnlockWrite();
   PRIVATE PROCEDURE LockRead() : BOOLEAN;
   PRIVATE PROCEDURE UnlockRead();
END CSynchronizedContainer;

(*--------------------------------------------------------------------------------*)

CLASS IMPLEMENTATION CSynchronizedContainer;

(*--------------------------------------------------------------------------------*)

   PUBLIC VIRTUAL PROCEDURE Dispose();
   BEGIN
      IF LockWrite() THEN
         Container.Dispose();
         UnlockWrite();
      END;
   END Dispose;

(*--------------------------------------------------------------------------------*)

   PUBLIC VIRTUAL PROCEDURE RemoveOA( CONST Name : ARRAY OF WCHAR );
   BEGIN
      IF LockWrite() THEN
         Container.RemoveOA( Name );
         UnlockWrite();
      END;
   END RemoveOA;

(*--------------------------------------------------------------------------------*)

   PUBLIC VIRTUAL PROCEDURE AddBooleanOA( CONST Name : ARRAY OF WCHAR; Model : BOOLEAN );
   BEGIN
      IF LockWrite() THEN
         Container.AddBooleanOA( Name, Model );
         UnlockWrite();
      END;
   END AddBooleanOA;

(*--------------------------------------------------------------------------------*)

   PUBLIC VIRTUAL PROCEDURE AddStringOA( CONST Name : ARRAY OF WCHAR; CONST Model : StringsO.IString ); // creates string in model
   BEGIN
      IF LockWrite() THEN
         Container.AddStringOA( Name, Model );
         UnlockWrite();
      END;
   END AddStringOA;

(*--------------------------------------------------------------------------------*)

   PUBLIC VIRTUAL PROCEDURE AddListOA( CONST Name : ARRAY OF WCHAR; OUT Model : lists.TPStringStringList ); // creates list in model
   BEGIN
      IF LockWrite() THEN
         Container.AddListOA( Name, OUT Model );
         UnlockWrite();
      END;
   END AddListOA;

(*--------------------------------------------------------------------------------*)

   PUBLIC VIRTUAL PROCEDURE AddMapOA( CONST Name : ARRAY OF WCHAR; OUT Model : maps.TPStringStringMap ); // creates map in model
   BEGIN
      IF LockWrite() THEN
         Container.AddMapOA( Name, OUT Model );
         UnlockWrite();
      END;
   END AddMapOA;

(*--------------------------------------------------------------------------------*)

   PUBLIC VIRTUAL PROCEDURE AddFunctionHandlerOA( CONST Name : ARRAY OF WCHAR; Handler : TPFunctionHandler );
   BEGIN
      IF LockWrite() THEN
         Container.AddFunctionHandlerOA( Name, Handler );
         UnlockWrite();
      END;
   END AddFunctionHandlerOA;

(*--------------------------------------------------------------------------------*)

   PUBLIC VIRTUAL PROCEDURE AddVariable( CONST Name : ARRAY OF WCHAR; CONST Model : StringsO.IString ); // for in-view processing
   BEGIN
      IF LockWrite() THEN
         Container.AddVariable( Name, Model );
         UnlockWrite();
      END;
   END AddVariable;

(*--------------------------------------------------------------------------------*)

   PUBLIC VIRTUAL PROCEDURE GetBooleanOA( CONST Name : ARRAY OF WCHAR; OUT Model : BOOLEAN ) : BOOLEAN;
   VAR
      b : BOOLEAN := FALSE;
   BEGIN
      IF LockRead() THEN
         b := Container.GetBooleanOA( Name, OUT Model );
         UnlockRead();
      END;
      RETURN b;
   END GetBooleanOA;

(*--------------------------------------------------------------------------------*)

   PUBLIC VIRTUAL PROCEDURE GetStringOA( CONST Name : ARRAY OF WCHAR; OUT Model : StringsO.IString ) : BOOLEAN;
   VAR
      b : BOOLEAN := FALSE;
   BEGIN
      IF LockRead() THEN
         b := Container.GetStringOA( Name, OUT Model );
         UnlockRead();
      END;
      RETURN b;
   END GetStringOA;

(*--------------------------------------------------------------------------------*)

   PUBLIC VIRTUAL PROCEDURE GetListOA( CONST Name : ARRAY OF WCHAR; OUT Model : lists.TPStringStringList ) : BOOLEAN;
   VAR
      b : BOOLEAN := FALSE;
   BEGIN
      IF LockRead() THEN
         b := Container.GetListOA( Name, OUT Model );
         UnlockRead();
      END;
      RETURN b;
   END GetListOA;

(*--------------------------------------------------------------------------------*)

   PUBLIC VIRTUAL PROCEDURE GetMapOA( CONST Name : ARRAY OF WCHAR; OUT Model : maps.TPStringStringMap ) : BOOLEAN;
   VAR
      b : BOOLEAN := FALSE;
   BEGIN
      IF LockRead() THEN
         b := Container.GetMapOA( Name, OUT Model );
         UnlockRead();
      END;
      RETURN b;
   END GetMapOA;

(*--------------------------------------------------------------------------------*)

   PUBLIC VIRTUAL PROCEDURE GetFunctionHandlerOA( CONST Name : ARRAY OF WCHAR; OUT Handler : TPFunctionHandler ) : BOOLEAN;
   VAR
      b : BOOLEAN := FALSE;
   BEGIN
      IF LockRead() THEN
         b := Container.GetFunctionHandlerOA( Name, OUT Handler );
         UnlockRead();
      END;
      RETURN b;
   END GetFunctionHandlerOA;

(*--------------------------------------------------------------------------------*)

   PUBLIC VIRTUAL PROCEDURE SetModelValue( CONST Request : IHttpRequest; CONST model, value : StringsO.IString; PFunctionCalled : PBOOLEAN ) : BOOLEAN; // main methods for accessing, it solves indexes, points, etc. in names
   VAR
      b : BOOLEAN := FALSE;
   BEGIN
      IF LockRead() THEN
         b := Container.SetModelValue( Request, model, value, PFunctionCalled  );
         UnlockRead();
      END;
      RETURN b;
   END SetModelValue;

(*--------------------------------------------------------------------------------*)

   PUBLIC VIRTUAL PROCEDURE GetModelValue( CONST Request : IHttpRequest; CONST model : StringsO.IString; OUT value : StringsO.IString; PFunctionCalled : PBOOLEAN ) : BOOLEAN; // main methods for accessing, it solves indexes, points, etc. in names
   VAR
      b : BOOLEAN := FALSE;
   BEGIN
      IF LockRead() THEN
         b := Container.GetModelValue( Request, model, OUT value, PFunctionCalled  );
         UnlockRead();
      END;
      RETURN b;
   END GetModelValue;

(*--------------------------------------------------------------------------------*)

   PUBLIC VIRTUAL PROCEDURE Format( CONST Request : IHttpRequest; FailOnError : BOOLEAN; CONST Source : StringsO.IString; MessageSource : TPMessageSource; language : Languages.TLanguage; OUT Formatted : StringsO.IString ) : BOOLEAN; // main format method, replaces view syntax with model data
   BEGIN
      RETURN Container.Format( Request, FailOnError, Source, MessageSource, language, OUT Formatted );
   END Format;

(*--------------------------------------------------------------------------------*)

   // There can be more active mappings, each identified by ControllerURI. It e.g. can be controller name, or so, always that way, to one would be easily able to identify to which controller/view the set and its data belongs.
   PUBLIC VIRTUAL PROCEDURE ResetModelInViewNames( CONST ControllerURI : StringsO.IString ); // clears all mode-view bindings corresponding to ControllerURI
   BEGIN
      IF LockWrite() THEN
         Container.ResetModelInViewNames( ControllerURI );
         UnlockWrite();
      END;
   END ResetModelInViewNames;

(*--------------------------------------------------------------------------------*)

   PUBLIC VIRTUAL PROCEDURE SetModelInViewName( CONST ControllerURI, FullModel, InViewName : StringsO.IString ); // stores logical name used in view output together with full model accessor
   BEGIN
      IF LockWrite() THEN
         Container.SetModelInViewName( ControllerURI, FullModel, InViewName );
         UnlockWrite();
      END;
   END SetModelInViewName;

(*--------------------------------------------------------------------------------*)

   PUBLIC VIRTUAL PROCEDURE GetModelByInViewName( CONST ControllerURI, InViewName : StringsO.IString; OUT FullModel : StringsO.IString ) : BOOLEAN; // gets model name by logical name used in view
   VAR
      b : BOOLEAN := FALSE;
   BEGIN
      IF LockRead() THEN
         b := Container.GetModelByInViewName( ControllerURI, InViewName, OUT FullModel );
         UnlockRead();
      END;
      RETURN b;
   END GetModelByInViewName;

(*--------------------------------------------------------------------------------*)

   PUBLIC VIRTUAL PROCEDURE ResetModelValues( CONST Request : IHttpRequest; CONST ControllerURI : StringsO.IString );
   BEGIN
      IF LockWrite() THEN
         Container.ResetModelValues( Request, ControllerURI );
         UnlockWrite();
      END;
   END ResetModelValues;

(*--------------------------------------------------------------------------------*)

   PRIVATE PROCEDURE LockWrite() : BOOLEAN;
   VAR
      locked : BOOLEAN;
   BEGIN
      locked := Lock.LockWrite( Sync.FORSAFETY ) = Sync.arCompleted;
      ASSERTLOG( locked, L"Unable to lock for write" );
      RETURN locked;
   END LockWrite;

(*--------------------------------------------------------------------------------*)

   PRIVATE PROCEDURE UnlockWrite();
   BEGIN
      Lock.UnlockWrite();
   END UnlockWrite;

(*--------------------------------------------------------------------------------*)

   PRIVATE PROCEDURE LockRead() : BOOLEAN;
   VAR
      locked : BOOLEAN;
   BEGIN
      locked := Lock.LockRead( Sync.FORSAFETY ) = Sync.arCompleted;
      ASSERTLOG( locked, L"Unable to lock for read" );
      RETURN locked;
   END LockRead;

(*--------------------------------------------------------------------------------*)

   PRIVATE PROCEDURE UnlockRead();
   BEGIN
      Lock.UnlockRead();
   END UnlockRead;

(*--------------------------------------------------------------------------------*)

END CSynchronizedContainer;

(*================================================================================*)

CLASS CHttpRequest IMPLEMENTS IHttpRequest;

   // IHttpRequest
   PUBLIC VIRTUAL READONLY PROPERTY
      RequestSource : inetaddr.INETADDR;
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
      FunctionCalled : BOOLEAN;
      
   PUBLIC VIRTUAL PROCEDURE TestConditions( CONST ResourceLastModified : time.DateTime; CONST ResourceName : StringsO.IString ) : HttpCommon.THttpResponse; // returns suggested status -- 200, 304 of 412

   // SELF
   PRIVATE VAR
      _Connection : HttpConnection.TPHttpSrvConnection;
      _Session : HttpSrv.TPSession;
      _ControllerURI : StringsO.CString;
      _Container : TPContainer;
      _MessageSource : TPMessageSource;
      _Language : Languages.TLanguage;
      _FunctionCalled : BOOLEAN;

   LOCAL PROCEDURE Init( CONST RequestURI : StringsO.CString; Connection : HttpConnection.TPHttpSrvConnection; CONST Session : HttpSrv.TPSession; CONST Container : TPContainer;  CONST MessageSource : TPMessageSource );
   
   LOCAL PROCEDURE SetFunctionCalled( FunctionCalled : BOOLEAN );

END CHttpRequest;

(*--------------------------------------------------------------------------------*)

CLASS IMPLEMENTATION CHttpRequest;

(*--------------------------------------------------------------------------------*)

   PUBLIC VIRTUAL PROPERTY RequestSource GET : inetaddr.INETADDR;
   BEGIN
      RETURN _Connection^.RemoteAddress;
   END RequestSource;

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

   PUBLIC VIRTUAL PROPERTY FunctionCalled GET : BOOLEAN;
   BEGIN
      RETURN _FunctionCalled;
   END FunctionCalled;

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

   LOCAL PROCEDURE SetFunctionCalled( _FunctionCalled : BOOLEAN );
   BEGIN
      SELF._FunctionCalled := _FunctionCalled;
   END SetFunctionCalled;

(*--------------------------------------------------------------------------------*)

BEGIN
   _Connection := NIL;
   _Session := NIL;
   _Container := NIL;
   _MessageSource := NIL;
   _Language := -1;
   _FunctionCalled := FALSE;
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
      SessionValidityMS : CARDINAL;
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
      SessionValidity : CARDINAL; // seconds
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
      _SessionValidity : CARDINAL := 30 * 60 * 1000; // 30 minutes
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

   PUBLIC VIRTUAL PROPERTY SessionValidityMS GET : CARDINAL;
   BEGIN
      IF _SessionValidity > Sync.FOREVER DIV 1000 THEN
         RETURN Sync.FOREVER;
      ELSE
         RETURN _SessionValidity * 1000;
      END;
   END SessionValidityMS;
      
//--------------------------------------------------------------------------------

   PUBLIC VIRTUAL PROCEDURE AppliesFor( Verb : HttpCommon.TVerb; CONST URL : ARRAY OF WCHAR; OUT WantsSession : BOOLEAN ) : BOOLEAN;
   VAR
      l : CARDINAL;
   BEGIN
      IF ( Verb <> HttpCommon.verbGET ) AND ( Verb <> HttpCommon.verbPOST ) THEN
         RETURN FALSE;
      END;
      
      l := _Context.Length;
      IF Strings.StartsWithW( URL, OA( l-1, _Context.Data )) THEN // URL = .../Context/...
         WantsSession := TRUE;
         RETURN TRUE;
      ELSIF l < 2 THEN
         RETURN FALSE;
      ELSIF Strings.EndsWithW( URL, OA( l-2, _Context.Data )) THEN // URL = .../Context
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
      container : POINTER TO CSynchronizedContainer;
      fallbackFlag : BOOLEAN := FALSE;
      functionCalled : BOOLEAN;
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

      IF LookupController( Connection^.RequestVerb, OA( controllerURI.Length-1, controllerURI.Data ), OUT controller ) THEN
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
         controller^.InitializeModelContainer( REF container^ );
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

      // prepare request data
      request.Init( controllerURI, Connection, Session, container, ADR( SELF ));

      // fill models, call functions
      functionCalled := FALSE;
      container^.ResetModelValues( request, controllerURI );
      connectionData.Reset();
      WHILE connectionData.MoveNext() DO
         IF container^.GetModelByInViewName( controllerURI, connectionData.Current^, OUT mappedName ) THEN
            container^.SetModelValue( request, mappedName, connectionData.CurrentData^, ADR( functionCalled ));
         ELSIF ( Connection^.RequestVerb <> HttpCommon.verbPOST ) AND // for GET driving by URI parameter is allowed...
               container^.GetModelValue( request, connectionData.Current^, OUT modelValue, ADR( functionCalled )) AND // ...only if the parameter is known
               NOT functionCalled THEN // ...and only if Get does not call -- then it cannot be set
            container^.SetModelValue( request, connectionData.Current^, connectionData.CurrentData^, ADR( functionCalled ));
         END;
      END; // WHILE
      connectionData.Dispose();
      container^.ResetModelInViewNames( controllerURI );
      request.SetFunctionCalled( functionCalled );
      
      // prepare response data
      response.Init( Connection, Session, container );
      buffer.Size := 16384; // initial size
      view := NIL;
      
      IF NOT controller^.ProcessRequest( fallbackFlag, REF request, OUT view ) THEN
         Connection^.StatusCode := HttpCommon.httpres_500;
      ELSIF view = NIL THEN
         Connection^.StatusCode := HttpCommon.httpres_500;
         _Logger^.LogS( Log.lcError, 0, L"MVC", L"Controller returned TRUE but it did not prepare View." );
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
                  _Logger^.LogS( Log.lcError, 0, L"MVC", L"Failure when writing output buffer to stream." );
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
               _Logger^.LogS( Log.lcError, 0, L"MVC", L"Failure when formatting View to output stream." );
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
      container : POINTER TO CSynchronizedContainer;
      controller : TPController;
   BEGIN
      IF NOT Session^.Get( SESSION_MVC, OUT containerMap ) THEN
         RETURN;
      END;
      
      containerMap^.Reset();
      WHILE containerMap^.MoveNext() DO
         controller := containerMap^.Current;
         container := containerMap^.CurrentData;

         controller^.CleanupModelContainer( REF container^ );

         DISPOSE( container );
      END; // WHILE

      DISPOSE( containerMap );
   END SessionExpired;

//--------------------------------------------------------------------------------

   PUBLIC VIRTUAL PROCEDURE GetMessage( language : Languages.TLanguage; CONST Key : StringsO.IString; OUT Message : StringsO.IString ) : BOOLEAN;
   VAR
      b : BOOLEAN := FALSE;
      e : ARRAY [0..3] OF WCHAR;
      english : Languages.TLanguage;
      length : CARDINAL;
      text : PWCHAR;
   BEGIN
      _MessagesLock.Lock();
      IF _Messages = NIL THEN
         NEW( _Messages );
         b := _Messages^.LoadXML( OA( _MessageSourcePath.Length-1, _MessageSourcePath.Data ), OUT e );
         IF b THEN
            IF Languages.RFC1766ToLanguage( L"en", OUT english ) THEN // if english exists, use it
               _Messages^.FallbackLang := english;
            ELSIF _Messages^.LanguageCount > 0 THEN // otherwise select first language
               _Messages^.GetLanguage( 0, OUT _Messages^.FallbackLang );
            ELSE // and as last resort, use as fallback resource native? language
               _Messages^.FallbackLang := _Messages^.Lang;
            END;
         END;
      ELSE
         b := TRUE;
      END;
      _MessagesLock.Unlock();

      IF b THEN
         b := _Messages^.GetTextByKeyL( language, Key, OUT text, OUT length );
      END;
      IF b THEN
         Message.FromOA( OA( length-1, text ));
      ELSE
         Message.Assign( Key );
      END;

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

   PUBLIC VIRTUAL PROPERTY SessionValidity GET : CARDINAL; // seconds
   BEGIN
      RETURN _SessionValidity;
   END SessionValidity;

//--------------------------------------------------------------------------------

   PUBLIC VIRTUAL PROPERTY SessionValidity SET( Value : CARDINAL ); // seconds
   BEGIN
      _SessionValidity := Value;
   END SessionValidity;

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
         Log.logger()^.LogS( Log.lcError, 0, L"MVC", L"Client requests unnamed context." );
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
      DISPOSE( MVCHolder );
   END;
END Cleanup;

(*================================================================================*)

PROCEDURE httpStatusCodeSystemView( StatusCode : HttpCommon.THttpResponse ) : TPView;
VAR
   view : View.TPStatusCodeView;
BEGIN
   NEW( view );
   view^.Init( StatusCode );
   RETURN view;
END httpStatusCodeSystemView;

//--------------------------------------------------------------------------------

PROCEDURE httpStatusCodeCustomView( CONST resolver : FSO.TPFilePathResolver; StatusCode : HttpCommon.THttpResponse ) : TPView; // specialized for error pages, looks for error.xxx.pt.xml files, if file is not found, default server error page is emitted
VAR
   view : View.TPErrorPageView;
BEGIN
   NEW( view );
   view^.Init( resolver, StatusCode );
   RETURN view;
END httpStatusCodeCustomView;

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

BEGIN
FINALLY
   Cleanup();
END MVC.
