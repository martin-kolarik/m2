IMPLEMENTATION MODULE nsimpl;

(*===========================================================================*)

TYPE
  TPNameValuePairsElem = POINTER TO CNameValuePairsElem;

CLASS CNameValuePairsElem( avltree.CAVLTreeElem );

   // CAVLTreeElem
   PUBLIC VIRTUAL PROCEDURE Compare( i : CARDINAL; pelem : avltree.TPAVLTreeKey ) : TRISTATE;

   // SELF
   LOCAL VAR
      Name : StringsO.CString;
      Value : iovalue.Value;
      Parent : TPNameValuePairsElem;

END CNameValuePairsElem;

(*---------------------------------------------------------------------------*)

CLASS CSearchHelper( avltree.CAVLTreeElem );

   // CAVLTreeElem
   PUBLIC VIRTUAL PROCEDURE Compare( i : CARDINAL; pelem : avltree.TPAVLTreeKey ) : TRISTATE;

   // SELF
   LOCAL PROCEDURE Init( CONST Source : StringsO.IString );

   PRIVATE VAR
      Source : POINTER TO CONST StringsO.IString;

END CSearchHelper;

(*===========================================================================*)

CLASS IMPLEMENTATION CNameValuePairsElem;

(*---------------------------------------------------------------------------*)

   PUBLIC VIRTUAL PROCEDURE Compare( i : CARDINAL; pelem : avltree.TPAVLTreeKey ) : TRISTATE;
   BEGIN
      RETURN Name.Compare( TPNameValuePairsElem( pelem )^.Name );
   END Compare;

(*---------------------------------------------------------------------------*)

BEGIN
   Parent := NIL;
END CNameValuePairsElem;

(*===========================================================================*)

CLASS IMPLEMENTATION CSearchHelper;

(*---------------------------------------------------------------------------*)

   PUBLIC VIRTUAL PROCEDURE Compare( i : CARDINAL; pelem : avltree.TPAVLTreeKey ) : TRISTATE;
   BEGIN
      RETURN Source^.Compare( TPNameValuePairsElem( pelem )^.Name );
   END Compare;

(*---------------------------------------------------------------------------*)

   LOCAL PROCEDURE Init( CONST Source : StringsO.IString );
   BEGIN
      SELF.Source := ADR( Source );
   END Init;

(*---------------------------------------------------------------------------*)

BEGIN
   Source := NIL;
END CSearchHelper;

(*===========================================================================*)

CLASS IMPLEMENTATION NameValuePairs;

(*---------------------------------------------------------------------------*)

   PUBLIC VIRTUAL PROCEDURE Dispose();
   BEGIN
      _Storage.Dispose();
   END Dispose;

(*---------------------------------------------------------------------------*)

   PUBLIC VIRTUAL PROCEDURE NameToHash( CONST Name : StringsO.IString; OUT Hash : ns.THash ) : BOOLEAN;
   VAR
      elem : TPNameValuePairsElem;
      helper : CSearchHelper;
   BEGIN
      helper.Init( Name );
      IF _Storage.SearchI( 0, ADR( helper ), OUT elem ) THEN
         Hash := elem;
         RETURN TRUE;
      ELSE
         RETURN FALSE;
      END;
   END NameToHash;

(*---------------------------------------------------------------------------*)

   PUBLIC VIRTUAL PROCEDURE HashToName( CONST Hash : ns.THash; OUT Name : StringsO.IString ) : BOOLEAN;
   VAR
      elem : TPNameValuePairsElem := TPNameValuePairsElem( Hash );
   BEGIN
      IF elem = NIL THEN
         RETURN FALSE;
      ELSIF NOT( elem^ IS CNameValuePairsElem ) THEN
         RETURN FALSE;
      ELSE
         Name := elem^.Name;
         RETURN TRUE;
      END;
   END HashToName;

(*---------------------------------------------------------------------------*)

   PUBLIC VIRTUAL PROCEDURE HashToValue( CONST Hash : ns.THash; OUT Value : iovalue.TPValue ) : BOOLEAN;
   VAR
      elem : TPNameValuePairsElem := TPNameValuePairsElem( Hash );
   BEGIN
      IF elem = NIL THEN
         RETURN FALSE;
      ELSIF NOT( elem^ IS CNameValuePairsElem ) THEN
         RETURN FALSE;
      ELSE
         Value := ADR( elem^.Value );
         RETURN TRUE;
      END;
   END HashToValue;

(*---------------------------------------------------------------------------*)

   PUBLIC VIRTUAL PROCEDURE HashToParent( CONST Hash : ns.THash; OUT Parent : ns.THash ) : BOOLEAN;
   VAR
      elem : TPNameValuePairsElem := TPNameValuePairsElem( Hash );
   BEGIN
      IF elem = NIL THEN
         RETURN FALSE;
      ELSIF NOT( elem^ IS CNameValuePairsElem ) THEN
         RETURN FALSE;
      ELSE
         Parent := ADR( elem^.Parent );
         RETURN TRUE;
      END;
   END HashToParent;

(*---------------------------------------------------------------------------*)

   PUBLIC VIRTUAL PROCEDURE Get( CONST NameOrIndex : StringsO.IString; OUT Value : iovalue.TPValue ) : BOOLEAN; // tries to convert string to number, if it succeeds index is used
   VAR
      index : CARDINAL;
   BEGIN
      IF NameOrIndex.ToCARD32( 10, OUT index ) THEN
         RETURN ElementAt( index, OUT Value );
      ELSE
         RETURN Map( NameOrIndex, OUT Value );
      END;
   END Get;

(*---------------------------------------------------------------------------*)

   PUBLIC VIRTUAL PROCEDURE Map( CONST Name : StringsO.IString; OUT Value : iovalue.TPValue ) : BOOLEAN; // looks for string, does not try to convert name to index
   VAR
      elem : TPNameValuePairsElem;
      hash : ns.THash;
   BEGIN
      IF NameToHash( Name, OUT hash ) THEN
         elem := TPNameValuePairsElem( hash );
         Value := ADR( elem^.Value );
         RETURN TRUE;
      ELSE
         RETURN FALSE;
      END;
   END Map;

(*---------------------------------------------------------------------------*)

   PUBLIC VIRTUAL PROCEDURE ElementAt( Index : CARDINAL; OUT Value : iovalue.TPValue ) : BOOLEAN;
   VAR
      elem : TPNameValuePairsElem;
   BEGIN
      elem := TPNameValuePairsElem( _Storage[ Index ] );
      IF elem = NIL THEN
         RETURN FALSE;
      ELSE
         Value := ADR( elem^.Value );
         RETURN TRUE;
      END;
      (*
      IF _Storage.ElementAt( Index, OUT elem ) THEN
         Value := ADR( elem^.Value );
         RETURN TRUE;
      ELSE
         RETURN FALSE;
      END;
      *)
   END ElementAt;

(*---------------------------------------------------------------------------*)

   PUBLIC VIRTUAL PROCEDURE Children( CONST Name : StringsO.IString; OUT children : iovalue.TPINameValuePairs ) : BOOLEAN; // shorthand for Get[Name]->Value->Children
   VAR
      Value : iovalue.TPValue;
   BEGIN
      IF NOT Map( Name, OUT Value ) THEN
         RETURN FALSE;
      ELSIF Value^.Children = NIL THEN
         RETURN FALSE;
      ELSE
         children := Value^.Children;
         RETURN TRUE;
      END;
   END Children;

(*---------------------------------------------------------------------------*)

END NameValuePairs;

(*===========================================================================*)

CLASS IMPLEMENTATION Namespace;

(*---------------------------------------------------------------------------*)

   PUBLIC VIRTUAL PROCEDURE Dispose();
   BEGIN
      _Pairs.Dispose();
   END Dispose;

(*---------------------------------------------------------------------------*)

   PUBLIC VIRTUAL PROCEDURE NameToHash( CONST Name : StringsO.IString; OUT Hash : ns.THash ) : BOOLEAN;
   VAR
      hash : ns.THash;
      i : CARDINAL;
      pairs : TPNameValuePairs;
      toTest : StringsO.CString;
      value : iovalue.TPValue;
   BEGIN
      IF Name.Empty THEN
         RETURN FALSE;
      END;

      // Root, the first item, must be handled separatelly
      i := Name.ItemS( StringsO.WCHARS{L'.'}, 0, 0, TRUE, OUT toTest );
      IF toTest.Empty THEN
         RETURN FALSE;
      ELSIF Name <> toTest THEN
         RETURN FALSE;
      END;
      // then continue down pairs by pairs
      pairs := ADR( _Pairs );
      LOOP
         i := Name.ItemS( StringsO.WCHARS{L'.'}, i, 0, TRUE, OUT toTest );
         IF toTest.Empty THEN
            EXIT;
         ELSIF NOT pairs^.NameToHash( toTest, OUT hash ) OR NOT pairs^.HashToValue( hash, OUT value ) THEN
            RETURN FALSE;
         ELSIF value^.Children = NIL THEN
            RETURN FALSE;
         ELSIF value^.Children^ IS NameValuePairs THEN
            pairs := TPNameValuePairs( value^.Children );
         ELSE
            RETURN FALSE;
         END;
      END; // LOOP

      Hash := hash;
      RETURN TRUE;
   END NameToHash;

(*---------------------------------------------------------------------------*)

   PUBLIC VIRTUAL PROCEDURE HashToName( CONST Hash : ns.THash; OUT Name : StringsO.IString ) : BOOLEAN;
   VAR
      dot : StringsO.CString;
      name : StringsO.CString;
      hash : ns.THash := Hash;
      singleName : StringsO.CString;
   BEGIN
      IF NOT _Pairs.HashToName( Hash, OUT name ) THEN
         RETURN FALSE;
      END;
      dot := StringsO.FromOA( L"." );
      WHILE _Pairs.HashToParent( hash, OUT hash ) DO
         IF _Pairs.HashToName( hash, OUT singleName ) THEN
            name.Prepend( dot );
            name.Prepend( singleName );
         ELSE
            RETURN FALSE;
         END;
      END; // WHILE
      Name.Assign( name );
      RETURN TRUE;
   END HashToName;

(*---------------------------------------------------------------------------*)

   PUBLIC VIRTUAL PROCEDURE HashToValue( CONST Hash : ns.THash; OUT Value : iovalue.TPValue ) : BOOLEAN;
   BEGIN
      RETURN _Pairs.HashToValue( Hash, OUT Value );
   END HashToValue;

(*---------------------------------------------------------------------------*)

   PUBLIC VIRTUAL PROCEDURE Contains( CONST Name : StringsO.IString ) : BOOLEAN;
   VAR
      Value : iovalue.TPValue;
   BEGIN
      RETURN Get( Name, OUT Value );
   END Contains;

(*---------------------------------------------------------------------------*)

   PUBLIC VIRTUAL PROCEDURE Get( CONST NameOrIndex : StringsO.IString; OUT Value : iovalue.TPValue ) : BOOLEAN; // tries to convert string to number, if it succeeds index is used
   VAR
      index : CARDINAL;
   BEGIN
      IF Name.ToCARD32( 10, OUT index ) THEN
         RETURN ElementAt( index, OUT Value );
      ELSE
         RETURN Map( Name, OUT Value );
      END;
   END Get;

(*---------------------------------------------------------------------------*)

   PUBLIC VIRTUAL PROCEDURE Map( CONST Name : StringsO.IString; OUT Value : iovalue.TPValue ) : BOOLEAN; // looks for string, does not try to convert name to index
   VAR
      hash : ns.THash;
   BEGIN
      RETURN NameToHash( Name, OUT hash ) AND _Pairs.HashToValue( hash, OUT Value );
   END Map;

(*---------------------------------------------------------------------------*)

   PUBLIC VIRTUAL PROCEDURE ElementAt( Index : CARDINAL; OUT Value : iovalue.TPValue ) : BOOLEAN;
   BEGIN
      RETURN _Pairs.ElementAt( Index, OUT Value );
   END ElementAt;

(*---------------------------------------------------------------------------*)

   PUBLIC VIRTUAL PROCEDURE Children( CONST Name : StringsO.IString; OUT children : iovalue.TPINameValuePairs ) : BOOLEAN;
   VAR
      value : iovalue.TPValue;
   BEGIN
      IF Map( Name, OUT value ) THEN
         children := value^.Children;
         RETURN TRUE;
      ELSE
         RETURN FALSE;
      END;
   END Children;

(*---------------------------------------------------------------------------*)

   PUBLIC PROPERTY Root GET : iovalue.TPValue;
   BEGIN
      RETURN ADR( _Root );
   END Root;

(*---------------------------------------------------------------------------*)

   PUBLIC PROPERTY Name GET : StringsO.CString; // reads Root.String
   BEGIN
      RETURN _Root.String;
   END Name;

(*---------------------------------------------------------------------------*)

BEGIN
FINALLY
   Dispose();
END Namespace;

(*===========================================================================*)

END nsimpl.