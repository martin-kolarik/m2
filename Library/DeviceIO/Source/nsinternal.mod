IMPLEMENTATION MODULE nsinternal;

(*===========================================================================*)

TYPE
   TPNameValuePairsElem = POINTER TO CNameValuePairsElem;

CLASS CNameValuePairsElem( avltree.CAVLTreeElem );

   // CAVLTreeElem
   PUBLIC VIRTUAL PROCEDURE Compare( i : CARDINAL; pelem : avltree.TPAVLTreeKey ) : TRISTATE;

   // SELF
   LOCAL VAR
      _Pairs : NameValuePairs;

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
      RETURN StringsO.TPString( _Pairs.Name )^.Compare( TPNameValuePairsElem( pelem )^._Pairs.Name^ );
   END Compare;

(*---------------------------------------------------------------------------*)

BEGIN
FINALLY
   _Pairs.Dispose();
END CNameValuePairsElem;

(*===========================================================================*)

CLASS IMPLEMENTATION CSearchHelper;

(*---------------------------------------------------------------------------*)

   PUBLIC VIRTUAL PROCEDURE Compare( i : CARDINAL; pelem : avltree.TPAVLTreeKey ) : TRISTATE;
   BEGIN
      RETURN StringsO.TPString( Source )^.Compare( TPNameValuePairsElem( pelem )^._Pairs.Name^ );
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

PROCEDURE HashToValue( CONST Hash : ns.THash; OUT Value : iovalue.TPValue ) : BOOLEAN;
VAR
   pairs : TPNameValuePairs;
BEGIN
   IF Hash = ns.hashINVALID THEN
      RETURN FALSE;
   // ELSIF NOT( value^ IS LOOSE NameValuePairs ) THEN
   //    RETURN FALSE;
   END;
   pairs := TPNameValuePairs( ns.TPNameValuePairs( Hash ));
   Value := ADR( pairs^._Value );
   RETURN TRUE;
END HashToValue;

(*---------------------------------------------------------------------------*)

PROCEDURE hashToName( CONST Hash : ns.THash; OUT Name : StringsO.IString ) : BOOLEAN; // STATIC
VAR
   pairs : ns.TPNameValuePairs := ns.TPNameValuePairs( Hash );
BEGIN
   IF Hash = ns.hashINVALID THEN
      RETURN FALSE;
   // ELSIF NOT( value^ IS LOOSE NameValuePairs ) THEN
   //    RETURN FALSE;
   END;
   Name.Assign( pairs^.Name^ );
   RETURN TRUE;
END hashToName;

(*===========================================================================*)

CLASS IMPLEMENTATION NameValuePairs;

(*---------------------------------------------------------------------------*)

   PUBLIC VIRTUAL PROCEDURE Dispose();
   BEGIN
      _Children.Dispose();
   END Dispose;

(*---------------------------------------------------------------------------*)

   PUBLIC VIRTUAL PROCEDURE NameToHash( CONST Name : StringsO.IString; OUT Hash : ns.THash ) : BOOLEAN;
   VAR
      elem : TPNameValuePairsElem;
      helper : CSearchHelper;
      pairs : TPNameValuePairs;
   BEGIN
      helper.Init( Name );
      IF _Children.SearchI( 0, ADR( helper ), OUT elem ) THEN
         pairs := ADR( elem^._Pairs );
         Hash := ADR( pairs^.INameValuePairs );
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

   PUBLIC VIRTUAL PROCEDURE Map( CONST Name : StringsO.IString; OUT Value : iovalue.TPValue ) : BOOLEAN; // looks for string, does not try to convert name to index
   VAR
      hash : ns.THash;
   BEGIN
      RETURN NameToHash( Name, OUT hash ) AND HashToValue( hash, OUT Value );
   END Map;

(*---------------------------------------------------------------------------*)

   PUBLIC VIRTUAL PROPERTY Name GET : POINTER TO CONST StringsO.IString;
   BEGIN
      RETURN ADR( _Name );
   END Name;

(*---------------------------------------------------------------------------*)

   PUBLIC VIRTUAL PROPERTY Parent GET : ns.TPNameValuePairs;
   BEGIN
      RETURN ADR( _Parent^.INameValuePairs );
   END Parent;

(*---------------------------------------------------------------------------*)

   PUBLIC VIRTUAL PROCEDURE Child( CONST Name : StringsO.IString; OUT child : ns.TPNameValuePairs ) : BOOLEAN;
   VAR
      hash : ns.THash;
   BEGIN
      IF NOT NameToHash( Name, OUT hash ) THEN
         RETURN FALSE;
      END;
      child := ns.TPNameValuePairs( hash );
      RETURN TRUE;
   END Child;

(*---------------------------------------------------------------------------*)

   PUBLIC VIRTUAL PROCEDURE DefineValue( CONST Name : StringsO.IString; Type : iovalue.TType; Flags : iovalue.TFlags; Data : PTR; CONST InitialValue : iovalue.TPValue; OUT Children : ns.TPNameValuePairs ) : BOOLEAN;
   VAR
      elem : TPNameValuePairsElem;
      hash : ns.THash;
      pairs : TPNameValuePairs;
   BEGIN
      // check input parameters
      IF Name.Empty THEN
         RETURN FALSE;
      ELSIF NameToHash( Name, OUT hash ) THEN // cannot define two items with same names
         RETURN FALSE;
      END;

      NEW( elem );
      pairs := ADR( elem^._Pairs );
      // fill name
      pairs^._Name.Assign( Name );
      // fill value part
      pairs^._Value.InitializeFlags := Flags - iovalue.TFlags{iovalue.vfReadOnly};
      pairs^._Value.Type := Type;
      pairs^._Value.Tag := Data;
      IF InitialValue <> NIL THEN
         pairs^._Value := InitialValue^;
      END;
      pairs^._Value.InitializeFlags := Flags;
      // structurals
      pairs^._Parent := ADR( SELF );
      Children := ADR( pairs^.INameValuePairs );
      // add it
      _Children.Insert( elem );

      // return value
      RETURN TRUE;
   END DefineValue;

(*---------------------------------------------------------------------------*)

   PUBLIC PROCEDURE DefineLink( CONST Name : StringsO.IString; Flags : iovalue.TFlags; Link, Data : PTR ) : BOOLEAN;
   VAR
      elem : TPNameValuePairsElem;
      hash : ns.THash;
      pairs : TPNameValuePairs;
   BEGIN
      // check input parameters
      IF Name.Empty THEN
         RETURN FALSE;
      ELSIF NameToHash( Name, OUT hash ) THEN // cannot define two items with same names
         RETURN FALSE;
      END;

      NEW( elem );
      pairs := ADR( elem^._Pairs );
      // fill name
      pairs^._Name.Assign( Name );
      // fill value part
      pairs^._Value.InitializeFlags := Flags - iovalue.TFlags{iovalue.vfReadOnly};
      pairs^._Value.Type := iovalue.vtLink;
      pairs^._Value.Link := Link;
      pairs^._Value.Tag := Data;
      pairs^._Value.InitializeFlags := Flags;
      // structurals
      pairs^._Parent := ADR( SELF );
      // add it
      _Children.Insert( elem );

      // return value
      RETURN TRUE;
   END DefineLink;

(*---------------------------------------------------------------------------*)

BEGIN
END NameValuePairs;

(*===========================================================================*)

END nsinternal.