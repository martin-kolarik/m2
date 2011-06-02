IMPLEMENTATION MODULE maps;

(*==========================================================================*)

FROM Debug IMPORT
   Assertion, LogAssertionW;

FROM StringsO IMPORT
   CString;

IMPORT
   collection;

(*==========================================================================*)

CLASS IMPLEMENTATION CDataOwnershipControlMap;

(*---------------------------------------------------------------------------*)

   PUBLIC PROPERTY DataOwnership GET : BOOLEAN;
   BEGIN
      RETURN _DataOwnership;
   END DataOwnership;

(*---------------------------------------------------------------------------*)

   PUBLIC PROPERTY DataOwnership SET( Value : BOOLEAN );
   BEGIN
      _DataOwnership := Value;
   END DataOwnership;

(*---------------------------------------------------------------------------*)

BEGIN
END CDataOwnershipControlMap;

(*==========================================================================*)
// common ancestor

ABSTRACT CLASS CPtrItem( avltree.CAVLTreeElem );

   // CDisposable
   PUBLIC VIRTUAL PROCEDURE Dispose();

   // SELF   
   LOCAL VAR
      Data : PTR := NIL;
      OfDataOwnershipControlMap : POINTER TO CDataOwnershipControlMap := NIL;

END CPtrItem;

(*---------------------------------------------------------------------------*)

CLASS IMPLEMENTATION CPtrItem;

(*---------------------------------------------------------------------------*)

   PUBLIC VIRTUAL PROCEDURE Dispose();
   BEGIN
      ASSERT( OfDataOwnershipControlMap <> NIL );
      IF ( Data <> NIL ) AND ( OfDataOwnershipControlMap^.DataOwnership ) THEN
         IF baseobject.PBASE( Data )^ INHERITS baseobject.CRefcounted THEN
            baseobject.TPRefcounted( Data )^.Release();
         ELSIF baseobject.PBASE( Data )^ INHERITS baseobject.CDisposable THEN 
            baseobject.TPDisposable( Data )^.Dispose();
            DISPOSE( baseobject.TPDisposable( Data ));
         ELSIF baseobject.PBASE( Data )^ INHERITS baseobject.BASE THEN
            DISPOSE( baseobject.PBASE( Data ));
         ELSE
            ASSERTLOG( FALSE, L"Unable to deallocate map item -- unknown class" );
         END;
         Data := NIL;
      END;
      SUPER.Dispose();
   END Dispose;

(*---------------------------------------------------------------------------*)

BEGIN FINALLY
   Dispose();
END CPtrItem;

(*==========================================================================*)

TYPE
   TPIntegerPtrItem = POINTER TO CIntegerPtrItem;

CLASS CIntegerPtrItem( CPtrItem );

   LOCAL VAR
      Key : INTEGER;

   PUBLIC VIRTUAL PROCEDURE Compare( i : CARDINAL; pelem : avltree.TPAVLTreeKey ) : TRISTATE;

END CIntegerPtrItem;

(*---------------------------------------------------------------------------*)

CLASS IMPLEMENTATION CIntegerPtrItem;

(*---------------------------------------------------------------------------*)

   PUBLIC VIRTUAL PROCEDURE Compare( i : CARDINAL; pelem : avltree.TPAVLTreeKey ) : TRISTATE;
   BEGIN
      IF Key < TPIntegerPtrItem( pelem )^.Key THEN
         RETURN -1;
      ELSIF Key > TPIntegerPtrItem( pelem )^.Key THEN
         RETURN 1;
      ELSE
         RETURN 0;
      END;
   END Compare;

(*---------------------------------------------------------------------------*)

BEGIN
   Key := 0;
END CIntegerPtrItem;

(*==========================================================================*)

CLASS IMPLEMENTATION CIntegerPtrMap;

(*---------------------------------------------------------------------------*)

   PUBLIC READONLY INDEX CIntegerPtrMap GET( Index : CARDINAL ) : PTR;
   VAR
      PI : TPIntegerPtrItem;
   BEGIN
      IF SUPER.ElementAt( 0, Index, OUT PI ) THEN
         RETURN PI^.Data;
      ELSE
         RETURN NIL;
      END;
   END CIntegerPtrMap;

(*---------------------------------------------------------------------------*)

   PUBLIC PROCEDURE CIntegerPtrMap.Add( Key : INTEGER; Data : PTR );
   VAR
      PI : TPIntegerPtrItem;
   BEGIN
      NEW( PI );
      PI^.OfDataOwnershipControlMap := ADR( SELF );
      PI^.Key := Key;
      PI^.Data := Data;
      SUPER.Add( PI );
   END CIntegerPtrMap.Add;
  
(*---------------------------------------------------------------------------*)

   PUBLIC PROCEDURE CIntegerPtrMap.Remove( Key : INTEGER );
   VAR
      I : CIntegerPtrItem;
   BEGIN
      I.Key := Key;
      Delete( 0, ADR( I ));
   END CIntegerPtrMap.Remove;

(*---------------------------------------------------------------------------*)

   PUBLIC PROCEDURE CIntegerPtrMap.Contains( Key : INTEGER ) : BOOLEAN;
   VAR
      I : CIntegerPtrItem;
   BEGIN
      I.Key := Key;
      RETURN SUPER.Contains( 0, ADR( I ));
   END CIntegerPtrMap.Contains;

(*---------------------------------------------------------------------------*)

   PUBLIC PROCEDURE CIntegerPtrMap.Get( Key : INTEGER; OUT Data : PTR ) : BOOLEAN;
   VAR
      I : CIntegerPtrItem;
      PI : TPIntegerPtrItem;
   BEGIN
      I.Key := Key;
      IF NOT SUPER.Get( 0, ADR( I ), OUT PI ) THEN
         RETURN FALSE;
      END;
      Data := PI^.Data;
      RETURN TRUE;  
   END CIntegerPtrMap.Get;

(*---------------------------------------------------------------------------*)

   PUBLIC PROCEDURE CIntegerPtrMap.ElementAt( Index : CARDINAL; OUT Key : INTEGER; OUT Data : PTR ) : BOOLEAN;
   VAR
      PI : TPIntegerPtrItem;
   BEGIN
      IF SUPER.ElementAt( 0, Index, OUT PI ) THEN
         Key := PI^.Key;
         Data := PI^.Data;
         RETURN TRUE;
      ELSE
         RETURN FALSE;
      END;
   END CIntegerPtrMap.ElementAt;

(*---------------------------------------------------------------------------*)

   PUBLIC PROCEDURE CIntegerPtrMap.GetIterator() : TPIntegerPtrMapIterator;
   VAR
      iterator : TPIntegerPtrMapIterator := NEW( CIntegerPtrMapIterator );
   BEGIN
      iterator^.Init( SELF, collection.dirForward );
      RETURN iterator;
   END CIntegerPtrMap.GetIterator;

(*---------------------------------------------------------------------------*)

END CIntegerPtrMap;

(*===========================================================================*)

CLASS IMPLEMENTATION CIntegerPtrMapIterator;

(*---------------------------------------------------------------------------*)

   PUBLIC PROPERTY Key GET : INTEGER;
   BEGIN
      IF Current = NIL THEN
         RETURN 0;
      ELSE
         RETURN TPIntegerPtrItem( Current )^.Key;
      END;
   END Key;

(*---------------------------------------------------------------------------*)

   PUBLIC PROPERTY Data GET : PTR;
   BEGIN
      IF Current = NIL THEN
         RETURN NIL;
      ELSE
         RETURN TPIntegerPtrItem( Current )^.Data;
      END;
   END Data;

(*---------------------------------------------------------------------------*)

   PUBLIC PROPERTY Data SET( Value : PTR );
   BEGIN
      IF Current <> NIL THEN
         TPIntegerPtrItem( Current )^.Data := Value;
      END;
   END Data;

(*---------------------------------------------------------------------------*)

END CIntegerPtrMapIterator;

(*===========================================================================*)

TYPE
   TPIntegerStringItem = POINTER TO CIntegerStringItem;

CLASS CIntegerStringItem( avltree.CAVLTreeElem );

   LOCAL VAR
      Key  : INTEGER;
      Data : CString;

   PUBLIC VIRTUAL PROCEDURE Compare( i : CARDINAL; pelem : avltree.TPAVLTreeKey ) : TRISTATE;

END CIntegerStringItem;

(*---------------------------------------------------------------------------*)

CLASS IMPLEMENTATION CIntegerStringItem;

(*---------------------------------------------------------------------------*)

   PUBLIC VIRTUAL PROCEDURE Compare( i : CARDINAL; pelem : avltree.TPAVLTreeKey ) : TRISTATE;
   BEGIN
      IF Key < TPIntegerStringItem( pelem )^.Key THEN
         RETURN -1;
      ELSIF Key > TPIntegerStringItem( pelem )^.Key THEN
         RETURN 1;
      ELSE
         RETURN 0;
      END;
   END Compare;

(*---------------------------------------------------------------------------*)

BEGIN
   Key := 0;
END CIntegerStringItem;

(*==========================================================================*)

CLASS IMPLEMENTATION CIntegerStringMap;

(*---------------------------------------------------------------------------*)

   PUBLIC READONLY INDEX CIntegerStringMap GET ( Index : CARDINAL ) : TPString;
   VAR
      PI : TPIntegerStringItem;
   BEGIN
      IF SUPER.ElementAt( 0, Index, OUT PI ) THEN
         RETURN ADR( PI^.Data );
      ELSE
         RETURN NIL;
      END;
   END CIntegerStringMap;

(*---------------------------------------------------------------------------*)

   PUBLIC PROCEDURE CIntegerStringMap.Add( Key : INTEGER; CONST Data : IString );
   VAR
      PI : TPIntegerStringItem;
   BEGIN
      NEW( PI );
      PI^.Key := Key;
      PI^.Data.Assign( Data );
      SUPER.Add( PI );
   END CIntegerStringMap.Add;
  
(*---------------------------------------------------------------------------*)

   PUBLIC PROCEDURE CIntegerStringMap.Remove( Key : INTEGER );
   VAR
      I : CIntegerStringItem;
   BEGIN
      I.Key := Key;
      Delete( 0, ADR( I ));
   END CIntegerStringMap.Remove;

(*---------------------------------------------------------------------------*)

   PUBLIC PROCEDURE CIntegerStringMap.Contains( Key : INTEGER ) : BOOLEAN;
   VAR
      I : CIntegerStringItem;
   BEGIN
      I.Key := Key;
      RETURN SUPER.Contains( 0, ADR( I ));
   END CIntegerStringMap.Contains;

(*---------------------------------------------------------------------------*)

   PUBLIC PROCEDURE CIntegerStringMap.Get( Key : INTEGER; OUT Data : IString ) : BOOLEAN;
   VAR
      I : CIntegerStringItem;
      PI : TPIntegerStringItem;
   BEGIN
      I.Key := Key;
      IF NOT SUPER.Get( 0, ADR( I ), OUT PI ) THEN
         RETURN FALSE;
      END;
      Data.Assign( PI^.Data );
      RETURN TRUE;  
   END CIntegerStringMap.Get;

(*---------------------------------------------------------------------------*)

   PUBLIC PROCEDURE CIntegerStringMap.ElementAt( Index : CARDINAL; OUT Key : INTEGER; OUT Data : IString ) : BOOLEAN;
   VAR
      PI : TPIntegerStringItem;
   BEGIN
      IF SUPER.ElementAt( 0, Index, OUT PI ) THEN
         Key := PI^.Key;
         Data.Assign( PI^.Data );
         RETURN TRUE;
      ELSE
         RETURN FALSE;
      END;
   END CIntegerStringMap.ElementAt;

(*---------------------------------------------------------------------------*)

   PUBLIC PROCEDURE CIntegerStringMap.GetIterator() : TPIntegerStringMapIterator;
   VAR
      iterator : TPIntegerStringMapIterator := NEW( CIntegerStringMapIterator );
   BEGIN
      iterator^.Init( SELF, collection.dirForward );
      RETURN iterator;
   END CIntegerStringMap.GetIterator;

(*---------------------------------------------------------------------------*)

END CIntegerStringMap;

(*==========================================================================*)

CLASS IMPLEMENTATION CIntegerStringMapIterator;

(*---------------------------------------------------------------------------*)

   PUBLIC PROPERTY Key GET : INTEGER;
   BEGIN
      IF Current = NIL THEN
         RETURN 0;
      ELSE
         RETURN TPIntegerStringItem( Current )^.Key;
      END;
   END Key;

(*---------------------------------------------------------------------------*)

   PUBLIC PROPERTY Data GET : TPString;
   BEGIN
      IF Current = NIL THEN
         RETURN NIL;
      ELSE
         RETURN ADR( TPIntegerStringItem( Current )^.Data );
      END;
   END Data;

(*---------------------------------------------------------------------------*)

END CIntegerStringMapIterator;

(*==========================================================================*)

TYPE
   TPPtrPtrItem = POINTER TO CPtrPtrItem;

CLASS CPtrPtrItem( CPtrItem );

   PUBLIC VAR
      Key : PTR;

   PUBLIC VIRTUAL PROCEDURE Compare( i : CARDINAL; pelem : avltree.TPAVLTreeKey ) : TRISTATE;

END CPtrPtrItem;

(*---------------------------------------------------------------------------*)

CLASS IMPLEMENTATION CPtrPtrItem;

(*---------------------------------------------------------------------------*)

   PUBLIC VIRTUAL PROCEDURE Compare( i : CARDINAL; pelem : avltree.TPAVLTreeKey ) : TRISTATE;
   BEGIN
      IF Key < TPPtrPtrItem( pelem )^.Key THEN
         RETURN -1;
      ELSIF Key > TPPtrPtrItem( pelem )^.Key THEN
         RETURN 1;
      ELSE
         RETURN 0;
      END;
   END Compare;

(*---------------------------------------------------------------------------*)

BEGIN
   Key := 0;
END CPtrPtrItem;

(*==========================================================================*)

CLASS IMPLEMENTATION CPtrPtrMap;

(*---------------------------------------------------------------------------*)

   PUBLIC READONLY INDEX CPtrPtrMap GET( Index : CARDINAL ) : PTR;
   VAR
      PI : TPPtrPtrItem;
   BEGIN
      IF SUPER.ElementAt( 0, Index, OUT PI ) THEN
         RETURN PI^.Data;
      ELSE
         RETURN NIL;
      END;
   END CPtrPtrMap;

(*---------------------------------------------------------------------------*)

   PUBLIC PROCEDURE CPtrPtrMap.Add( Key : PTR; Data : PTR );
   VAR
      PI : TPPtrPtrItem;
   BEGIN
      NEW( PI );
      PI^.Key := Key;
      PI^.Data := Data;
      SUPER.Add( PI );
   END CPtrPtrMap.Add;
  
(*---------------------------------------------------------------------------*)

   PUBLIC PROCEDURE CPtrPtrMap.Remove( Key : PTR );
   VAR
      I : CPtrPtrItem;
   BEGIN
      I.Key := Key;
      Delete( 0, ADR( I ));
   END CPtrPtrMap.Remove;

(*---------------------------------------------------------------------------*)

   PUBLIC PROCEDURE CPtrPtrMap.Contains( Key : PTR ) : BOOLEAN;
   VAR
      I : CPtrPtrItem;
   BEGIN
      I.Key := Key;
      RETURN SUPER.Contains( 0, ADR( I ));
   END CPtrPtrMap.Contains;

(*---------------------------------------------------------------------------*)

   PUBLIC PROCEDURE CPtrPtrMap.Get( Key : PTR; OUT Data : PTR ) : BOOLEAN;
   VAR
      I : CPtrPtrItem;
      PI : TPPtrPtrItem;
   BEGIN
      I.Key := Key;
      IF NOT SUPER.Get( 0, ADR( I ), OUT PI ) THEN
         RETURN FALSE;
      END;
      Data := PI^.Data;
      RETURN TRUE;  
   END CPtrPtrMap.Get;

(*---------------------------------------------------------------------------*)

   PUBLIC PROCEDURE CPtrPtrMap.ElementAt( Index : CARDINAL; OUT Key : PTR; OUT Data : PTR ) : BOOLEAN;
   VAR
      PI : TPPtrPtrItem;
   BEGIN
      IF SUPER.ElementAt( 0, Index, OUT PI ) THEN
         Key := PI^.Key;
         Data := PI^.Data;
         RETURN TRUE;
      ELSE
         RETURN FALSE;
      END;
   END CPtrPtrMap.ElementAt;

(*---------------------------------------------------------------------------*)

   PUBLIC PROCEDURE CPtrPtrMap.GetIterator() : TPPtrPtrMapIterator;
   VAR
      iterator : TPPtrPtrMapIterator := NEW( CPtrPtrMapIterator );
   BEGIN
      iterator^.Init( SELF, collection.dirForward );
      RETURN iterator;
   END CPtrPtrMap.GetIterator;

(*---------------------------------------------------------------------------*)

END CPtrPtrMap;

(*==========================================================================*)

CLASS IMPLEMENTATION CPtrPtrMapIterator;

(*---------------------------------------------------------------------------*)

   PUBLIC PROPERTY Key GET : PTR;
   BEGIN
      IF Current = NIL THEN
         RETURN 0;
      ELSE
         RETURN TPPtrPtrItem( Current )^.Key;
      END;
   END Key;

(*---------------------------------------------------------------------------*)

   PUBLIC PROPERTY Data GET : PTR;
   BEGIN
      IF Current = NIL THEN
         RETURN NIL;
      ELSE
         RETURN TPPtrPtrItem( Current )^.Data;
      END;
   END Data;

(*---------------------------------------------------------------------------*)

   PUBLIC PROPERTY Data SET( Value : PTR );
   BEGIN
      IF Current <> NIL THEN
         TPPtrPtrItem( Current )^.Data := Value;
      END;
   END Data;

(*---------------------------------------------------------------------------*)

END CPtrPtrMapIterator;

(*==========================================================================*)

TYPE
   TPStringPtrItem = POINTER TO CStringPtrItem;

CLASS CStringPtrItem( CPtrItem );

   PUBLIC VAR
      Key : CString;

   PUBLIC VIRTUAL PROCEDURE Compare( i : CARDINAL; pelem : avltree.TPAVLTreeKey ) : TRISTATE;

END CStringPtrItem;

(*---------------------------------------------------------------------------*)

CLASS IMPLEMENTATION CStringPtrItem;

(*---------------------------------------------------------------------------*)

   PUBLIC VIRTUAL PROCEDURE Compare( i : CARDINAL; pelem : avltree.TPAVLTreeKey ) : TRISTATE;
   BEGIN
      RETURN Key.Compare( TPStringPtrItem( pelem )^.Key );
   END Compare;

(*---------------------------------------------------------------------------*)

END CStringPtrItem;

(*==========================================================================*)

CLASS IMPLEMENTATION CStringPtrMap;

(*---------------------------------------------------------------------------*)

   PUBLIC READONLY INDEX CStringPtrMap GET( Index : CARDINAL ) : PTR;
   VAR
      PI : TPStringPtrItem;
   BEGIN
      IF SUPER.ElementAt( 0, Index, OUT PI ) THEN
         RETURN PI^.Data;
      ELSE
         RETURN NIL;
      END;
   END CStringPtrMap;

(*---------------------------------------------------------------------------*)

   PUBLIC PROCEDURE CStringPtrMap.Add( CONST Key : IString; Data : PTR );
   VAR
      PI : TPStringPtrItem;
   BEGIN
      NEW( PI );
      PI^.Key.Assign( Key );
      PI^.Data := Data;
      SUPER.Add( PI );
   END CStringPtrMap.Add;
  
(*---------------------------------------------------------------------------*)

   PUBLIC PROCEDURE CStringPtrMap.Remove( CONST Key : IString );
   VAR
      I : CStringPtrItem;
   BEGIN
      I.Key.Assign( Key );
      Delete( 0, ADR( I ));
   END CStringPtrMap.Remove;

(*---------------------------------------------------------------------------*)

   PUBLIC PROCEDURE CStringPtrMap.Contains( CONST Key : IString ) : BOOLEAN;
   VAR
      I : CStringPtrItem;
   BEGIN
      I.Key.Assign( Key );
      RETURN SUPER.Contains( 0, ADR( I ));
   END CStringPtrMap.Contains;

(*---------------------------------------------------------------------------*)

   PUBLIC PROCEDURE CStringPtrMap.Get( CONST Key : IString; OUT Data : PTR ) : BOOLEAN;
   VAR
      I : CStringPtrItem;
      PI : TPStringPtrItem;
   BEGIN
      I.Key.Assign( Key );
      IF NOT SUPER.Get( 0, ADR( I ), OUT PI ) THEN
         RETURN FALSE;
      END;
      Data := PI^.Data;
      RETURN TRUE;  
   END CStringPtrMap.Get;

(*---------------------------------------------------------------------------*)

   PUBLIC PROCEDURE CStringPtrMap.ElementAt( Index : CARDINAL; OUT Key : IString; OUT Data : PTR ) : BOOLEAN;
   VAR
      PI : TPStringPtrItem;
   BEGIN
      IF SUPER.ElementAt( 0, Index, OUT PI ) THEN
         Key := PI^.Key;
         Data := PI^.Data;
         RETURN TRUE;
      ELSE
         RETURN FALSE;
      END;
   END CStringPtrMap.ElementAt;

(*---------------------------------------------------------------------------*)

   PUBLIC PROCEDURE CStringPtrMap.GetIterator() : TPStringPtrMapIterator;
   VAR
      iterator : TPStringPtrMapIterator := NEW( CStringPtrMapIterator );
   BEGIN
      iterator^.Init( SELF, collection.dirForward );
      RETURN iterator;
   END CStringPtrMap.GetIterator;

(*---------------------------------------------------------------------------*)

END CStringPtrMap;

(*==========================================================================*)

CLASS IMPLEMENTATION CStringPtrMapIterator;

(*---------------------------------------------------------------------------*)

   PUBLIC PROPERTY Key GET : TPString;
   BEGIN
      IF Current = NIL THEN
         RETURN NIL;
      ELSE
         RETURN ADR( TPStringPtrItem( Current )^.Key );
      END;
   END Key;

(*---------------------------------------------------------------------------*)

   PUBLIC PROPERTY Data GET : PTR;
   BEGIN
      IF Current = NIL THEN
         RETURN NIL;
      ELSE
         RETURN TPStringPtrItem( Current )^.Data;
      END;
   END Data;

(*---------------------------------------------------------------------------*)

   PUBLIC PROPERTY Data SET( Value : PTR );
   BEGIN
      IF Current <> NIL THEN
         TPStringPtrItem( Current )^.Data := Value;
      END;
   END Data;

(*---------------------------------------------------------------------------*)

END CStringPtrMapIterator;

(*==========================================================================*)

TYPE
   TPStringStringItem = POINTER TO CStringStringItem;

CLASS CStringStringItem( avltree.CAVLTreeElem );

   PUBLIC VAR
      Key : CString;
      Data : CString;

  PUBLIC VIRTUAL PROCEDURE Compare( i : CARDINAL; pelem : avltree.TPAVLTreeKey ) : TRISTATE;

END CStringStringItem;

(*---------------------------------------------------------------------------*)

CLASS IMPLEMENTATION CStringStringItem;

(*---------------------------------------------------------------------------*)

  PUBLIC VIRTUAL PROCEDURE Compare( i : CARDINAL; pelem : avltree.TPAVLTreeKey ) : TRISTATE;
  BEGIN
    RETURN Key.Compare( TPStringStringItem( pelem )^.Key );
  END Compare;

(*---------------------------------------------------------------------------*)

END CStringStringItem;

(*==========================================================================*)

CLASS IMPLEMENTATION CStringStringMap;

(*---------------------------------------------------------------------------*)

   PUBLIC READONLY INDEX CStringStringMap GET( Index : CARDINAL ) : TPString;
   VAR
      PI : TPStringStringItem;
   BEGIN
      IF SUPER.ElementAt( 0, Index, OUT PI ) THEN
         RETURN ADR( PI^.Data );
      ELSE
         RETURN NIL;
      END;
   END CStringStringMap;

(*---------------------------------------------------------------------------*)

   PUBLIC PROCEDURE CStringStringMap.Add( CONST Key : IString; CONST Data : IString );
   VAR
      PI : TPStringStringItem;
   BEGIN
      NEW( PI );
      PI^.Key.Assign( Key );
      PI^.Data.Assign( Data );
      SUPER.Add( PI );
   END CStringStringMap.Add;
  
(*---------------------------------------------------------------------------*)

   PUBLIC PROCEDURE CStringStringMap.Remove( CONST Key : IString );
   VAR
      I : CStringStringItem;
   BEGIN
      I.Key.Assign( Key );
      Delete( 0, ADR( I ));
   END CStringStringMap.Remove;

(*---------------------------------------------------------------------------*)

   PUBLIC PROCEDURE CStringStringMap.Contains( CONST Key : IString ) : BOOLEAN;
   VAR
      I : CStringStringItem;
   BEGIN
      I.Key.Assign( Key );
      RETURN SUPER.Contains( 0, ADR( I ));
   END CStringStringMap.Contains;

(*---------------------------------------------------------------------------*)

   PUBLIC PROCEDURE CStringStringMap.Get( CONST Key : IString; OUT Data : IString ) : BOOLEAN;
   VAR
      I : CStringStringItem;
      PI : TPStringStringItem;
   BEGIN
      I.Key.Assign( Key );
      IF NOT SUPER.Get( 0, ADR( I ), OUT PI ) THEN
         RETURN FALSE;
      END;
      Data.Assign( PI^.Data );
      RETURN TRUE;  
   END CStringStringMap.Get;

(*---------------------------------------------------------------------------*)

   PUBLIC PROCEDURE CStringStringMap.ElementAt( Index : CARDINAL; OUT Key : IString; OUT Data : IString ) : BOOLEAN;
   VAR
      PI : TPStringStringItem;
   BEGIN
      IF SUPER.ElementAt( 0, Index, OUT PI ) THEN
         Key.Assign( PI^.Key );
         Data.Assign( PI^.Data );
         RETURN TRUE;
      ELSE
         RETURN FALSE;
      END;
   END CStringStringMap.ElementAt;

(*---------------------------------------------------------------------------*)

   PUBLIC PROCEDURE CStringStringMap.GetIterator() : TPStringStringMapIterator;
   VAR
      iterator : TPStringStringMapIterator := NEW( CStringStringMapIterator );
   BEGIN
      iterator^.Init( SELF, collection.dirForward );
      RETURN iterator;
   END CStringStringMap.GetIterator;

(*---------------------------------------------------------------------------*)

END CStringStringMap;

(*==========================================================================*)

CLASS IMPLEMENTATION CStringStringMapIterator;

(*---------------------------------------------------------------------------*)

   PUBLIC PROPERTY Key GET : TPString;
   BEGIN
      IF Current = NIL THEN
         RETURN NIL;
      ELSE
         RETURN ADR( TPStringStringItem( Current )^.Key );
      END;
   END Key;

(*---------------------------------------------------------------------------*)

   PUBLIC PROPERTY Data GET : TPString;
   BEGIN
      IF Current = NIL THEN
         RETURN NIL;
      ELSE
         RETURN ADR( TPStringStringItem( Current )^.Data );
      END;
   END Data;

(*---------------------------------------------------------------------------*)

END CStringStringMapIterator;

(*==========================================================================*)

END maps.