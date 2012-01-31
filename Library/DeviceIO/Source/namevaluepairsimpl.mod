IMPLEMENTATION MODULE namevaluepairsimpl;

FROM Debug IMPORT
   AssertionW;

(*===========================================================================*)

TYPE
   TPNameValuePairsElem = POINTER TO CNameValuePairsElem;

CLASS CNameValuePairsElem( avltree.CAVLTreeElem );

   // CAVLTreeElem
   PUBLIC VIRTUAL PROCEDURE Compare( i : CARDINAL; pelem : avltree.TPAVLTreeKey ) : TRISTATE;

   // SELF
   LOCAL VAR
      _Pairs : ns.TPNameValuePairs := NIL;

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

(*---------------------------------------------------------------------------*)

CLASS CNameValuePairsStorageElem( CNameValuePairsElem );

   // CAVLTreeElem
   PUBLIC VIRTUAL PROCEDURE Compare( i : CARDINAL; pelem : avltree.TPAVLTreeKey ) : TRISTATE;

   LOCAL VAR
      _Storage : NameValuePairsStorage;

END CNameValuePairsStorageElem;

(*===========================================================================*)

CLASS IMPLEMENTATION CNameValuePairsElem;

(*---------------------------------------------------------------------------*)

   PUBLIC VIRTUAL PROCEDURE Compare( i : CARDINAL; pelem : avltree.TPAVLTreeKey ) : TRISTATE;
   BEGIN
      RETURN _Pairs^.Name.Compare( TPNameValuePairsElem( pelem )^._Pairs^.Name );
   END Compare;

(*---------------------------------------------------------------------------*)

BEGIN
END CNameValuePairsElem;

(*===========================================================================*)

CLASS IMPLEMENTATION CSearchHelper;

(*---------------------------------------------------------------------------*)

   PUBLIC VIRTUAL PROCEDURE Compare( i : CARDINAL; pelem : avltree.TPAVLTreeKey ) : TRISTATE;
   BEGIN
      RETURN StringsO.TPString( Source )^.Compare( TPNameValuePairsElem( pelem )^._Pairs^.Name );
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

CLASS IMPLEMENTATION CNameValuePairsStorageElem;

(*---------------------------------------------------------------------------*)

   PUBLIC VIRTUAL PROCEDURE Compare( i : CARDINAL; pelem : avltree.TPAVLTreeKey ) : TRISTATE;
   BEGIN
      RETURN SUPER.Compare( i, pelem );
   END Compare;

(*---------------------------------------------------------------------------*)

BEGIN
   _Pairs := ADR( _Storage );
FINALLY
   _Storage.Dispose();
END CNameValuePairsStorageElem;

(*===========================================================================*)

CLASS IMPLEMENTATION ANameValuePairsStructurals;

(*---------------------------------------------------------------------------*)

   PUBLIC VIRTUAL PROCEDURE Dispose();
   BEGIN
      IF _Children <> NIL THEN
         _Children^.Dispose();
         DISPOSE( _Children );
      END;
   END Dispose;

(*---------------------------------------------------------------------------*)

   PUBLIC VIRTUAL PROCEDURE Get( CONST Name : StringsO.IString; OUT Child : ns.TPNameValuePairs ) : BOOLEAN;
   VAR
      elem : TPNameValuePairsElem;
      helper : CSearchHelper;
   BEGIN
      IF _Children = NIL THEN
         RETURN FALSE;
      ELSIF Name.Empty THEN
         RETURN FALSE;
      END;
      helper.Init( Name );
      IF _Children^.SearchI( 0, ADR( helper ), OUT elem ) THEN
         Child := elem^._Pairs;
         RETURN TRUE;
      ELSE
         RETURN FALSE;
      END;
   END Get;

(*---------------------------------------------------------------------------*)

   PUBLIC VIRTUAL PROPERTY Name GET : StringsO.CString;
   BEGIN
      RETURN _Name;
   END Name;

(*---------------------------------------------------------------------------*)

   PUBLIC VIRTUAL PROPERTY Parent GET : ns.TPNameValuePairs;
   BEGIN
      RETURN _Parent;
   END Parent;

(*---------------------------------------------------------------------------*)

   PUBLIC VIRTUAL PROPERTY Data GET : PTR;
   BEGIN
      RETURN _Data;
   END Data;

(*---------------------------------------------------------------------------*)

   PUBLIC VIRTUAL PROPERTY Data SET( Value : PTR );
   BEGIN
      _Data := Value;
   END Data;

(*---------------------------------------------------------------------------*)

   PUBLIC PROPERTY InitializeName SET( CONST Value : StringsO.CString );
   BEGIN
      _Name.Assign( Value );
   END InitializeName;

(*---------------------------------------------------------------------------*)

   PUBLIC VIRTUAL PROCEDURE Link( CONST Name : StringsO.IString; CONST Child : ns.TPNameValuePairs ) : BOOLEAN;
   VAR
      child : ns.TPNameValuePairs;
      elem : TPNameValuePairsElem;
   BEGIN
      IF _Children = NIL THEN
         NEW( _Children );
      END;

      IF Child = NIL THEN
         RETURN FALSE;
      ELSIF NOT Child^.Name.Equals( Name ) THEN
         RETURN FALSE;
      ELSIF Get( Name, OUT child ) THEN
         RETURN FALSE;
      END;

      NEW( elem );
      elem^._Pairs := Child;
      _Children^.Insert( elem );

      RETURN TRUE;
   END Link;

(*---------------------------------------------------------------------------*)

   PUBLIC VIRTUAL PROCEDURE Unlink( CONST Name : StringsO.IString; OUT Child : ns.TPNameValuePairs ) : BOOLEAN;
   VAR
      elem : TPNameValuePairsElem;
      helper : CSearchHelper;
   BEGIN
      IF _Children = NIL THEN
         RETURN FALSE;
      END;

      helper.Init( Name );
      IF NOT _Children^.SearchI( 0, ADR( helper ), OUT elem ) THEN
         RETURN FALSE;
      ELSIF ( elem^ IS NameValuePairsStorage ) OR ( elem^ IS NameValuePairsIO ) THEN // only link is possible to remove
         RETURN FALSE;
      END;

      Child := elem^._Pairs;
      _Children^.Delete( ADR( helper ));

      RETURN TRUE;
   END Unlink;

(*---------------------------------------------------------------------------*)

BEGIN
END ANameValuePairsStructurals;

(*===========================================================================*)

CLASS IMPLEMENTATION NameValuePairsIO;

(*---------------------------------------------------------------------------*)

   PUBLIC VIRTUAL PROCEDURE ValueIO( CONST Originator : ns.TPOriginator; Direction : IOO.TDirection; CONST NameValuePairs : ns.TPNameValuePairs; REF Value : iovalue.Value ) : Sync.TAsyncResult;
   BEGIN
      IF _ValueIODelegate = NIL THEN
         ASSERT( FALSE );
         RETURN Sync.arCannotStart;
      ELSE
         RETURN _ValueIODelegate^.ValueIO( Originator, Direction, NameValuePairs, REF Value );
      END;
   END ValueIO;

(*---------------------------------------------------------------------------*)

   PUBLIC VIRTUAL PROPERTY Value GET : iovalue.Value;
   VAR
      value : iovalue.Value;
   BEGIN
      IF ValueIO( NIL, IOO.dirRead, ADR( SELF ), REF value ) NOT IN Sync.arsCompletions THEN
         ASSERT( FALSE );
         value.Dispose();
      END;
      RETURN value;
   END Value;

(*---------------------------------------------------------------------------*)

   PUBLIC VIRTUAL PROPERTY Value SET( CONST value : iovalue.Value );
   BEGIN
      IF ValueIO( NIL, IOO.dirWrite, ADR( SELF ), REF iovalue.TPValue( ADR( value ))^ ) NOT IN Sync.arsCompletions THEN
         ASSERT( FALSE );
      END;
   END Value;

(*---------------------------------------------------------------------------*)

   PUBLIC VIRTUAL PROCEDURE DefineValue( CONST Name : StringsO.IString; Type : iovalue.TType; Flags : iovalue.TFlags; Data : PTR; CONST InitialValue : iovalue.TPValue; OUT Children : ns.TPNameValuePairs ) : BOOLEAN;
   BEGIN
      RETURN FALSE;
   END DefineValue;

(*---------------------------------------------------------------------------*)

   PUBLIC PROPERTY ValueIODelegate GET : ns.TPValueIO;
   BEGIN
      RETURN _ValueIODelegate;
   END ValueIODelegate;

(*---------------------------------------------------------------------------*)

   PUBLIC PROPERTY ValueIODelegate SET( Value : ns.TPValueIO );
   BEGIN
      _ValueIODelegate := Value;
   END ValueIODelegate;

(*---------------------------------------------------------------------------*)

BEGIN
END NameValuePairsIO;

(*===========================================================================*)

CLASS IMPLEMENTATION NameValuePairsStorage;

(*---------------------------------------------------------------------------*)

   PUBLIC VIRTUAL PROCEDURE ValueIO( CONST Originator : ns.TPOriginator; Direction : IOO.TDirection; CONST NameValuePairs : ns.TPNameValuePairs; REF Value : iovalue.Value ) : Sync.TAsyncResult;
   BEGIN
      CASE Direction OF
      | IOO.dirRead :
         Value := _Value;
      | IOO.dirWrite :
         _Value := Value;
      ELSE
         ASSERT( FALSE );
         RETURN Sync.arCannotStart;
      END;
      RETURN Sync.arCompleted;
   END ValueIO;

(*---------------------------------------------------------------------------*)

   PUBLIC VIRTUAL PROPERTY Value GET : iovalue.Value;
   BEGIN
      RETURN _Value;
   END Value;

(*---------------------------------------------------------------------------*)

   PUBLIC VIRTUAL PROPERTY Value SET( CONST value : iovalue.Value );
   BEGIN
      _Value := value;
   END Value;

(*---------------------------------------------------------------------------*)

   PUBLIC VIRTUAL PROCEDURE DefineValue( CONST Name : StringsO.IString; Type : iovalue.TType; Flags : iovalue.TFlags; Data : PTR; CONST InitialValue : iovalue.TPValue; OUT Children : ns.TPNameValuePairs ) : BOOLEAN;
   VAR
      child : ns.TPNameValuePairs;
      elem : POINTER TO CNameValuePairsStorageElem;
      pairs : TPNameValuePairsStorage;
   BEGIN
      IF _Children = NIL THEN
         NEW( _Children );
      END;

      // check input parameters
      IF Name.Empty THEN
         RETURN FALSE;
      ELSIF Get( Name, OUT child ) THEN // cannot define two items with same names
         RETURN FALSE;
      END;

      NEW( elem );
      pairs := ADR( elem^._Storage );
      // fill name
      pairs^._Name.Assign( Name );
      // fill value part
      pairs^._Value.InitializeFlags := Flags - iovalue.TFlags{iovalue.vfReadOnly};
      pairs^._Value.Type := Type;
      pairs^.Data := Data;
      IF InitialValue <> NIL THEN
         pairs^._Value := InitialValue^;
      END;
      pairs^._Value.InitializeFlags := Flags;
      // structurals
      pairs^._Parent := ADR( SELF );
      Children := elem^._Pairs;
      // add it
      _Children^.Insert( elem );

      // return value
      RETURN TRUE;
   END DefineValue;

(*---------------------------------------------------------------------------*)

   PUBLIC PROCEDURE DefineReference( CONST Name : StringsO.IString; Flags : iovalue.TFlags; Reference, Data : PTR ) : BOOLEAN;
   VAR
      iv : iovalue.Value;
      pairs : TPNameValuePairsStorage;
   BEGIN
      iv.Reference := Reference;
      RETURN DefineValue( Name, iovalue.vtReference, Flags, Data, ADR( iv ), OUT pairs );
   END DefineReference;

(*---------------------------------------------------------------------------*)

BEGIN
FINALLY
   _Value.Dispose();
END NameValuePairsStorage;

(*===========================================================================*)

END namevaluepairsimpl.