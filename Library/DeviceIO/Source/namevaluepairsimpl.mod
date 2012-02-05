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

CLASS CNameValuePairsIOElem( CNameValuePairsElem );

   // CAVLTreeElem
   PUBLIC VIRTUAL PROCEDURE Compare( i : CARDINAL; pelem : avltree.TPAVLTreeKey ) : TRISTATE;

   LOCAL VAR
      _Storage : NameValuePairsIO;

END CNameValuePairsIOElem;

(*---------------------------------------------------------------------------*)

CLASS CNameValuePairsStorageElem( CNameValuePairsElem );

   // CAVLTreeElem
   PUBLIC VIRTUAL PROCEDURE Compare( i : CARDINAL; pelem : avltree.TPAVLTreeKey ) : TRISTATE;

   LOCAL VAR
      _Storage : NameValuePairsStorage;

END CNameValuePairsStorageElem;

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
      RETURN _Pairs^.Name.Compare( TPNameValuePairsElem( pelem )^._Pairs^.Name );
   END Compare;

(*---------------------------------------------------------------------------*)

BEGIN
END CNameValuePairsElem;

(*===========================================================================*)

CLASS IMPLEMENTATION CNameValuePairsIOElem;

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
END CNameValuePairsIOElem;

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

   PUBLIC FINAL PROPERTY Name GET : StringsO.CString;
   BEGIN
      RETURN _Name;
   END Name;

(*---------------------------------------------------------------------------*)

   PUBLIC FINAL PROPERTY Parent GET : ns.TPNameValuePairs;
   BEGIN
      RETURN _Parent;
   END Parent;

(*---------------------------------------------------------------------------*)

   PUBLIC VIRTUAL PROPERTY AdviseSource GET : ns.TPAdviseSource;
   BEGIN
      RETURN _AdviseSource;
   END AdviseSource;

(*---------------------------------------------------------------------------*)

   PUBLIC FINAL PROPERTY Value GET : iovalue.Value;
   VAR
      value : iovalue.Value;
   BEGIN
      IF ValueIO( NIL, ADR( SELF ), IOO.dirRead, REF value ) NOT IN Sync.arsCompletions THEN
         ASSERT( FALSE );
         value.Dispose();
      END;
      RETURN value;
   END Value;

(*---------------------------------------------------------------------------*)

   PUBLIC FINAL PROPERTY Value SET( CONST value : iovalue.Value );
   BEGIN
      IF ValueIO( NIL, ADR( SELF ), IOO.dirWrite, REF iovalue.TPValue( ADR( value ))^ ) NOT IN Sync.arsCompletions THEN
         ASSERT( FALSE );
      END;
   END Value;

(*---------------------------------------------------------------------------*)

   PUBLIC FINAL PROPERTY Data GET : PTR;
   BEGIN
      RETURN _Data;
   END Data;

(*---------------------------------------------------------------------------*)

   PUBLIC FINAL PROPERTY Data SET( Value : PTR );
   BEGIN
      _Data := Value;
   END Data;

(*---------------------------------------------------------------------------*)

   PUBLIC PROPERTY InitializeName SET( CONST Value : StringsO.CString );
   BEGIN
      _Name.Assign( Value );
   END InitializeName;

(*---------------------------------------------------------------------------*)

   PUBLIC PROPERTY InitializeAdviseSource SET( Value : ns.TPAdviseSource );
   BEGIN
      _AdviseSource := Value;
   END InitializeAdviseSource;

(*---------------------------------------------------------------------------*)

   PUBLIC VIRTUAL PROCEDURE DefineStorageValue( CONST Name : StringsO.IString; Type : iovalue.TType; Flags : iovalue.TFlags; CONST InitialValue : iovalue.TPValue; Data : PTR; CONST AdviseSource : ns.TPAdviseSource; OUT Children : ns.TPNameValuePairs ) : BOOLEAN;
   VAR
      child : ns.TPNameValuePairs;
      elem : POINTER TO CNameValuePairsStorageElem;
      pairs : TPNameValuePairsStorage;
   BEGIN
      IF _Children = NIL THEN
         NEW( _Children );
      ELSIF Name.Empty THEN
         RETURN FALSE;
      ELSIF Get( Name, OUT child ) THEN // cannot define two items with same names
         RETURN FALSE;
      END;
      
      // create it
      NEW( elem );
      pairs := ADR( elem^._Storage );
      // name
      pairs^._Name.Assign( Name );
      // value part
      pairs^._Value.InitializeFlags := Flags - iovalue.TFlags{iovalue.vfReadOnly};
      pairs^._Value.Type := Type;
      IF InitialValue <> NIL THEN
         pairs^._Value := InitialValue^;
      END;
      pairs^._Value.InitializeFlags := Flags;
      // infos
      pairs^._Data := Data;
      pairs^._AdviseSource := AdviseSource;
      // structurals
      pairs^._Parent := ADR( SELF );
      Children := elem^._Pairs;
      // add it
      _Children^.Insert( elem );

      RETURN TRUE;
   END DefineStorageValue;

(*---------------------------------------------------------------------------*)

   PUBLIC VIRTUAL PROCEDURE DefineIOValue( CONST Name : StringsO.IString; REF ValueIO : ns.IValueIO; Data : PTR; CONST AdviseSource : ns.TPAdviseSource; OUT Children : ns.TPNameValuePairs ) : BOOLEAN;
   VAR
      child : ns.TPNameValuePairs;
      elem : POINTER TO CNameValuePairsIOElem;
      pairs : TPNameValuePairsIO;
   BEGIN
      IF _Children = NIL THEN
         NEW( _Children );
      ELSIF Name.Empty THEN
         RETURN FALSE;
      ELSIF Get( Name, OUT child ) THEN // cannot define two items with same names
         RETURN FALSE;
      END;
      
      // create it
      NEW( elem );
      pairs := ADR( elem^._Storage );
      // name
      pairs^._Name.Assign( Name );
      // infos
      pairs^._Data := Data;
      pairs^._AdviseSource := AdviseSource;
      pairs^.ValueIODelegate := ADR( ValueIO );
      // structurals
      pairs^._Parent := ADR( SELF );
      Children := elem^._Pairs;
      // add it
      _Children^.Insert( elem );

      RETURN TRUE;
   END DefineIOValue;

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

   PUBLIC VIRTUAL PROCEDURE ValueIO( CONST Originator : ns.TPOriginator; CONST NameValuePairs : ns.TPNameValuePairs; Direction : IOO.TDirection; REF Value : iovalue.Value ) : Sync.TAsyncResult;
   VAR
      Result : Sync.TAsyncResult;
   BEGIN
      IF _ValueIODelegate = NIL THEN
         ASSERT( FALSE );
         RETURN Sync.arCannotStart;
      END;

      Result := _ValueIODelegate^.ValueIO( Originator, NameValuePairs, Direction, REF Value );
      IF _AdviseSource <> NIL THEN
         CASE _AdviseSource^.Advise OF
         | ns.advWithoutData :
            _AdviseSource^.AdviseListener^.OnAdvise( Originator, OA( 0, ADR( Result )), OA( 0, ADR( NameValuePairs )), OA( -1, iovalue.TPValue( NIL )));
         | ns.advWithData :
            _AdviseSource^.AdviseListener^.OnAdvise( Originator, OA( 0, ADR( Result )), OA( 0, ADR( NameValuePairs )), OA( 0, ADR( Value )));
         END;
      END;
      
      RETURN Result;
   END ValueIO;

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

   PUBLIC VIRTUAL PROCEDURE ValueIO( CONST Originator : ns.TPOriginator; CONST NameValuePairs : ns.TPNameValuePairs; Direction : IOO.TDirection; REF Value : iovalue.Value ) : Sync.TAsyncResult;
   VAR
      Result : Sync.TAsyncResult := Sync.arCompleted;
   BEGIN
      CASE Direction OF
      | IOO.dirRead :
         Value := _Value;
      | IOO.dirWrite :
         _Value := Value;

         IF _AdviseSource <> NIL THEN
            CASE _AdviseSource^.Advise OF
            | ns.advWithoutData :
               _AdviseSource^.AdviseListener^.OnAdvise( Originator, OA( 0, ADR( Result )), OA( 0, ADR( NameValuePairs )), OA( -1, iovalue.TPValue( NIL )));
            | ns.advWithData :
               _AdviseSource^.AdviseListener^.OnAdvise( Originator, OA( 0, ADR( Result )), OA( 0, ADR( NameValuePairs )), OA( 0, ADR( Value )));
            END;
         END;

      ELSE
         ASSERT( FALSE );
         RETURN Sync.arCannotStart;
      END;
      RETURN Sync.arCompleted;
   END ValueIO;

(*---------------------------------------------------------------------------*)

   PUBLIC PROCEDURE DefineReference( CONST Name : StringsO.IString; Flags : iovalue.TFlags; Reference, Data : PTR ) : BOOLEAN;
   VAR
      iv : iovalue.Value;
      pairs : TPNameValuePairsStorage;
   BEGIN
      iv.Reference := Reference;
      RETURN DefineStorageValue( Name, iovalue.vtReference, Flags, ADR( iv ), Data, NIL, OUT pairs );
   END DefineReference;

(*---------------------------------------------------------------------------*)

BEGIN
FINALLY
   _Value.Dispose();
END NameValuePairsStorage;

(*===========================================================================*)

END namevaluepairsimpl.