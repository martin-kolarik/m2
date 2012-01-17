IMPLEMENTATION MODULE nsimpl;

(*===========================================================================*)

CONST
   flagsDefaultName = iovalue.TFlags{iovalue.vfReadOnly};
   flagsDefaultParent = iovalue.TFlags{iovalue.vfReadOnly, iovalue.vfHidden};

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

END CNameValuePairsElem;

(*---------------------------------------------------------------------------*)

CLASS CSearchHelper( avltree.CAVLTreeElem );

   // CAVLTreeElem
   PUBLIC VIRTUAL PROCEDURE Compare( i : CARDINAL; pelem : avltree.TPAVLTreeKey ) : TRISTATE;

   // SELF
   LOCAL PROCEDURE Init( CONST Source : StringsO.IString );

   PRIVATE VAR
      Source : POINTER TO CONST StringsO.IString := NIL;

END CSearchHelper;

(*===========================================================================*)

CLASS IMPLEMENTATION CNameValuePairsElem;

(*---------------------------------------------------------------------------*)

   PUBLIC VIRTUAL PROCEDURE Compare( i : CARDINAL; pelem : avltree.TPAVLTreeKey ) : TRISTATE;
   BEGIN
      RETURN Name.Compare( TPNameValuePairsElem( pelem )^.Name );
   END Compare;

(*---------------------------------------------------------------------------*)

END CNameValuePairsElem;

(*===========================================================================*)

CLASS IMPLEMENTATION CSearchHelper;

(*---------------------------------------------------------------------------*)

   PUBLIC VIRTUAL PROCEDURE Compare( i : CARDINAL; pelem : avltree.TPAVLTreeKey ) : TRISTATE;
   BEGIN
      RETURN StringsO.TPString( Source )^.Compare( TPNameValuePairsElem( pelem )^.Name );
   END Compare;

(*---------------------------------------------------------------------------*)

   LOCAL PROCEDURE Init( CONST Source : StringsO.IString );
   BEGIN
      SELF.Source := ADR( Source );
   END Init;

(*---------------------------------------------------------------------------*)

BEGIN
END CSearchHelper;

(*===========================================================================*)

PROCEDURE hashToValue( CONST Hash : ns.THash; OUT Value : iovalue.TPValue ) : BOOLEAN; // STATIC
VAR
   value : iovalue.TPValue := iovalue.TPValue( Hash );
BEGIN
   IF Hash = ns.hashINVALID THEN
      RETURN FALSE;
   // not appliable, casting to non-polymorphic class always gives correct RTTI
   // ELSIF NOT( value^ IS LOOSE iovalue.Value ) THEN
   //   RETURN FALSE;
   END;
   Value := value;
   RETURN TRUE;
END hashToValue;

(*---------------------------------------------------------------------------*)

PROCEDURE hashToChildren( CONST Hash : ns.THash; OUT Children : iovalue.TPNameValuePairs ) : BOOLEAN; // STATIC
VAR
   value : iovalue.TPValue;
BEGIN
   IF NOT hashToValue( Hash, OUT value ) THEN
      RETURN FALSE;
   ELSIF value^.Children = NIL THEN
      RETURN FALSE;
   END;
   Children := value^.Children;
   RETURN TRUE;
END hashToChildren;

(*---------------------------------------------------------------------------*)

PROCEDURE hashToName( CONST Hash : ns.THash; OUT Name : StringsO.IString ) : BOOLEAN; // STATIC
VAR
   children : iovalue.TPNameValuePairs;
   value : iovalue.TPValue;
BEGIN
   IF NOT hashToChildren( Hash, OUT children ) THEN
      RETURN FALSE;
   ELSIF NOT children^.Map( ns.nameName()^, OUT value ) THEN // could be children^.Name too
      RETURN FALSE;
   END;
   Name.Assign( value^.String );
   RETURN TRUE;
END hashToName;

(*---------------------------------------------------------------------------*)

PROCEDURE hashToParent( CONST Hash : ns.THash; OUT Parent : ns.THash ) : BOOLEAN; // STATIC
VAR
   children : iovalue.TPNameValuePairs;
   value : iovalue.TPValue;
BEGIN
   IF NOT hashToChildren( Hash, OUT children ) THEN
      RETURN FALSE;
   ELSIF NOT children^.Map( ns.nameParent()^, OUT value ) THEN // could be children^.Parent too
      RETURN FALSE;
   ELSIF value^.Link = NIL THEN
      RETURN FALSE;
   END;
   Parent := value^.Link;
   RETURN TRUE;
END hashToParent;

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
         Hash := ADR( elem^.Value );
         RETURN TRUE;
      ELSE
         RETURN FALSE;
      END;
   END NameToHash;

(*---------------------------------------------------------------------------*)

   PUBLIC VIRTUAL PROCEDURE HashToName( CONST Hash : ns.THash; OUT Name : StringsO.IString ) : BOOLEAN;
   BEGIN
      RETURN hashToName( Hash, OUT Name );
   END HashToName;

(*---------------------------------------------------------------------------*)

   PUBLIC VIRTUAL PROCEDURE HashToValue( CONST Hash : ns.THash; OUT Value : iovalue.TPValue ) : BOOLEAN;
   BEGIN
      RETURN hashToValue( Hash, OUT Value );
   END HashToValue;

(*---------------------------------------------------------------------------*)

   PUBLIC VIRTUAL PROCEDURE HashToParent( CONST Hash : ns.THash; OUT Parent : ns.THash ) : BOOLEAN;
   BEGIN
      RETURN hashToParent( Hash, OUT Parent );
   END HashToParent;

(*---------------------------------------------------------------------------*)

   PUBLIC VIRTUAL PROCEDURE Map( CONST Name : StringsO.IString; OUT Value : iovalue.TPValue ) : BOOLEAN; // looks for string, does not try to convert name to index
   VAR
      hash : ns.THash;
   BEGIN
      IF NameToHash( Name, OUT hash ) THEN
         Value := iovalue.TPValue( hash );
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

   PUBLIC VIRTUAL PROPERTY Name GET : POINTER TO CONST StringsO.IString;
   VAR
      value : iovalue.TPValue;
   BEGIN
      IF Map( ns.nameName()^, OUT value ) THEN
         RETURN value^.PString;
      ELSE
         RETURN NIL;
      END;
   END Name;

(*---------------------------------------------------------------------------*)

   PUBLIC VIRTUAL PROPERTY Parent GET : iovalue.TPNameValuePairs;
   VAR
      value : iovalue.TPValue;
   BEGIN
      IF Map( ns.nameParent()^, OUT value ) THEN
         RETURN value^.Link;
      ELSE
         RETURN NIL;
      END;
   END Parent;

(*---------------------------------------------------------------------------*)

   PUBLIC VIRTUAL PROCEDURE Children( CONST Name : StringsO.IString; OUT children : iovalue.TPNameValuePairs ) : BOOLEAN; // shorthand for Get[Name]->Value->Children
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

   PUBLIC PROCEDURE DefineValue( CONST Name : StringsO.IString; Type : iovalue.TType; Flags : iovalue.TFlags; Data : PTR; CONST InitialValue : StringsO.TPString; Children : TPNameValuePairs ) : BOOLEAN;
   VAR
      elem : TPNameValuePairsElem;
      hash : ns.THash;
      s : StringsO.CString;
   BEGIN
      // check input parameters
      IF Name.Empty THEN
         RETURN FALSE;
      ELSIF NameToHash( Name, OUT hash ) THEN // cannot define two items with same names
         RETURN FALSE;
      END;

      NEW( elem );
      // fill name
      elem^.Name.Assign( Name );
      // fill value part
      elem^.Value.InitializeFlags := Flags - iovalue.TFlags{iovalue.vfReadOnly};
      elem^.Value.Type := Type;
      elem^.Value.Tag := Data;
      IF InitialValue <> NIL THEN
         s.Assign( InitialValue^ );
         elem^.Value.String := s;
      END;
      elem^.Value.InitializeFlags := Flags;
      // fill structure part
      IF Children <> NIL THEN
         elem^.Value.InitializeChildren := Children;
         Children^.DefineValue( ns.nameName()^, iovalue.vtString, flagsDefaultName, NIL, ADR( Name ), NIL );
         Children^.DefineLink( ns.nameParent()^, flagsDefaultParent, ADR( SELF ), NIL );
      END;
      // add it
      _Storage.Insert( elem );

      // return value
      RETURN TRUE;
   END DefineValue;

(*---------------------------------------------------------------------------*)

   PUBLIC PROCEDURE DefineLink( CONST Name : StringsO.IString; Flags : iovalue.TFlags; Link, Data : PTR ) : BOOLEAN;
   VAR
      elem : TPNameValuePairsElem;
      hash : ns.THash;
   BEGIN
      // check input parameters
      IF Name.Empty THEN
         RETURN FALSE;
      ELSIF NameToHash( Name, OUT hash ) THEN // cannot define two items with same names
         RETURN FALSE;
      END;

      NEW( elem );
      // fill name
      elem^.Name.Assign( Name );
      // fill value part
      elem^.Value.InitializeFlags := Flags - iovalue.TFlags{iovalue.vfReadOnly};
      elem^.Value.Type := iovalue.vtLink;
      elem^.Value.Link := Link;
      elem^.Value.Tag := Data;
      elem^.Value.InitializeFlags := Flags;
      // add it
      _Storage.Insert( elem );

      // return value
      RETURN TRUE;
   END DefineLink;

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
      i : CARDINAL := 0;
      pairs : iovalue.TPNameValuePairs;
      toTest : StringsO.CString;
      value : iovalue.TPValue := NIL;
   BEGIN
      IF Name.Empty THEN
         RETURN FALSE;
      END;

      pairs := ADR( _Pairs );
      LOOP
         i := Name.ItemS( StringsO.WCHARS{L'.'}, i, 0, TRUE, OUT toTest );
         IF toTest.Empty THEN
            EXIT;
         ELSIF NOT pairs^.Map( toTest, OUT value ) THEN
            RETURN FALSE;
         ELSIF value^.Children = NIL THEN
            RETURN FALSE;
         ELSE
            pairs := value^.Children;
         END;
      END; // LOOP

      IF value = NIL THEN
         RETURN FALSE;
      ELSE
         Hash := value;
         RETURN TRUE;
      END;
   END NameToHash;

(*---------------------------------------------------------------------------*)

   PUBLIC VIRTUAL PROCEDURE HashToName( CONST Hash : ns.THash; OUT Name : StringsO.IString ) : BOOLEAN;
   VAR
      dot : StringsO.CString;
      name : StringsO.CString;
      hash : ns.THash := Hash;
      parentHash : ns.THash;
      singleName : StringsO.CString;
   BEGIN
      dot := StringsO.FromOA( L"." );

      LOOP
         IF NOT hashToParent( hash, OUT parentHash ) THEN
            EXIT;
         ELSIF NOT hashToName( hash, OUT singleName ) THEN
            RETURN FALSE;
         END;
         // construct
         IF name.Empty THEN
            name := singleName;
         ELSE
            name.Prepend( dot );
            name.Prepend( singleName );
         END;
         // move up
         hash := parentHash;
      END; // LOOP

      Name.Assign( name );
      RETURN TRUE;
   END HashToName;

(*---------------------------------------------------------------------------*)

   PUBLIC VIRTUAL PROCEDURE HashToValue( CONST Hash : ns.THash; OUT Value : iovalue.TPValue ) : BOOLEAN;
   BEGIN
      RETURN hashToValue( Hash, OUT Value );
   END HashToValue;

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

   PUBLIC VIRTUAL PROPERTY Name GET : POINTER TO CONST StringsO.IString;
   VAR
      value : iovalue.TPValue;
   BEGIN
      IF Map( ns.nameName()^, OUT value ) THEN
         RETURN value^.PString;
      ELSE
         RETURN NIL;
      END;
   END Name;

(*---------------------------------------------------------------------------*)

   PUBLIC VIRTUAL PROPERTY Parent GET : iovalue.TPNameValuePairs;
   VAR
      value : iovalue.TPValue;
   BEGIN
      IF Map( ns.nameParent()^, OUT value ) THEN
         RETURN value^.Link;
      ELSE
         RETURN NIL;
      END;
   END Parent;

(*---------------------------------------------------------------------------*)

   PUBLIC VIRTUAL PROCEDURE Children( CONST Name : StringsO.IString; OUT children : iovalue.TPNameValuePairs ) : BOOLEAN;
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

   PUBLIC VIRTUAL PROCEDURE Contains( CONST Name : StringsO.IString ) : BOOLEAN;
   VAR
      Value : iovalue.TPValue;
   BEGIN
      RETURN Map( Name, OUT Value );
   END Contains;

(*---------------------------------------------------------------------------*)

   PUBLIC PROCEDURE Init( CONST Name : StringsO.IString );
   VAR
      s : StringsO.CString;
   BEGIN
      // store name
      s.Assign( Name );
      _Root.String := s;
      // create mandatory keys
      DefineValue( ns.nameName()^, iovalue.vtString, flagsDefaultName, NIL, ADR( Name ), NIL );
      DefineValue( ns.nameParent()^, iovalue.vtLink, flagsDefaultParent, NIL, NIL, NIL );
   END Init;

(*---------------------------------------------------------------------------*)

   PUBLIC PROCEDURE DefineValue( CONST Name : StringsO.IString; Type : iovalue.TType; Flags : iovalue.TFlags; Data : PTR; CONST InitialValue : StringsO.TPString; Children : TPNameValuePairs ) : BOOLEAN;
   BEGIN
      RETURN _Pairs.DefineValue( Name, Type, Flags, Data, InitialValue, Children );
   END DefineValue;

(*---------------------------------------------------------------------------*)

   PUBLIC PROCEDURE DefineLink( CONST Name : StringsO.IString; Flags : iovalue.TFlags; Link, Data : PTR ) : BOOLEAN;
   BEGIN
      RETURN _Pairs.DefineLink( Name, Flags, Link, Data );
   END DefineLink;

(*---------------------------------------------------------------------------*)

BEGIN FINALLY
   Dispose();
END Namespace;

(*===========================================================================*)

END nsimpl.