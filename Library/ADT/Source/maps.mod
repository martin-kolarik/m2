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

ABSTRACT CLASS CBaseItem( avltree.CAVLTreeElem );

   // CDisposable
   PUBLIC VIRTUAL PROCEDURE Dispose();

   // SELF   
   LOCAL VAR
      Data : baseobject.PIBASE := NIL;
      OfDataOwnershipControlMap : POINTER TO CDataOwnershipControlMap := NIL;

END CBaseItem;

(*---------------------------------------------------------------------------*)

CLASS IMPLEMENTATION CBaseItem;

(*---------------------------------------------------------------------------*)

   PUBLIC VIRTUAL PROCEDURE Dispose();
   BEGIN
      ASSERT( OfDataOwnershipControlMap <> NIL );
      IF ( Data <> NIL ) AND ( OfDataOwnershipControlMap^.DataOwnership ) THEN
         IF Data^ INHERITS baseobject.CRefcounted THEN
            baseobject.TPRefcounted( Data )^.Release();
         ELSIF Data^ INHERITS baseobject.CDisposable THEN 
            baseobject.TPDisposable( Data )^.Dispose();
            DISPOSE( baseobject.TPDisposable( Data ));
         ELSIF Data^ INHERITS baseobject.BASE THEN
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
END CBaseItem;

(*==========================================================================*)

TYPE
   TPIntegerBaseItem = POINTER TO CIntegerBaseItem;

CLASS CIntegerBaseItem( CBaseItem );

   LOCAL VAR
      Key : INTEGER;

   PUBLIC VIRTUAL PROCEDURE Compare( i : CARDINAL; pelem : avltree.TPAVLTreeKey ) : TRISTATE;

END CIntegerBaseItem;

(*---------------------------------------------------------------------------*)

CLASS IMPLEMENTATION CIntegerBaseItem;

(*---------------------------------------------------------------------------*)

   PUBLIC VIRTUAL PROCEDURE Compare( i : CARDINAL; pelem : avltree.TPAVLTreeKey ) : TRISTATE;
   BEGIN
      IF Key < TPIntegerBaseItem( pelem )^.Key THEN
         RETURN -1;
      ELSIF Key > TPIntegerBaseItem( pelem )^.Key THEN
         RETURN 1;
      ELSE
         RETURN 0;
      END;
   END Compare;

(*---------------------------------------------------------------------------*)

BEGIN
   Key := 0;
END CIntegerBaseItem;

(*==========================================================================*)

CLASS IMPLEMENTATION CIntegerBaseMap;

(*---------------------------------------------------------------------------*)

   PUBLIC READONLY INDEX CIntegerBaseMap GET( Index : CARDINAL ) : baseobject.PIBASE;
   VAR
      PI : TPIntegerBaseItem;
   BEGIN
      IF SUPER.ElementAt( 0, Index, OUT PI ) THEN
         RETURN PI^.Data;
      ELSE
         RETURN NIL;
      END;
   END CIntegerBaseMap;

(*---------------------------------------------------------------------------*)

   PUBLIC PROCEDURE CIntegerBaseMap.Add( Key : INTEGER; Data : baseobject.PIBASE );
   VAR
      PI : TPIntegerBaseItem;
   BEGIN
      NEW( PI );
      PI^.OfDataOwnershipControlMap := ADR( SELF );
      PI^.Key := Key;
      PI^.Data := Data;
      SUPER.Add( PI );
   END CIntegerBaseMap.Add;
  
(*---------------------------------------------------------------------------*)

   PUBLIC PROCEDURE CIntegerBaseMap.Remove( Key : INTEGER );
   VAR
      I : CIntegerBaseItem;
   BEGIN
      I.Key := Key;
      Delete( 0, ADR( I ));
   END CIntegerBaseMap.Remove;

(*---------------------------------------------------------------------------*)

   PUBLIC PROCEDURE CIntegerBaseMap.Contains( Key : INTEGER ) : BOOLEAN;
   VAR
      I : CIntegerBaseItem;
   BEGIN
      I.Key := Key;
      RETURN SUPER.Contains( 0, ADR( I ));
   END CIntegerBaseMap.Contains;

(*---------------------------------------------------------------------------*)

   PUBLIC PROCEDURE CIntegerBaseMap.Get( Key : INTEGER; OUT Data : baseobject.PIBASE ) : BOOLEAN;
   VAR
      I : CIntegerBaseItem;
      PI : TPIntegerBaseItem;
   BEGIN
      I.Key := Key;
      IF NOT SUPER.Get( 0, ADR( I ), OUT PI ) THEN
         RETURN FALSE;
      END;
      Data := PI^.Data;
      RETURN TRUE;  
   END CIntegerBaseMap.Get;

(*---------------------------------------------------------------------------*)

   PUBLIC PROCEDURE CIntegerBaseMap.ElementAt( Index : CARDINAL; OUT Key : INTEGER; OUT Data : baseobject.PIBASE ) : BOOLEAN;
   VAR
      PI : TPIntegerBaseItem;
   BEGIN
      IF SUPER.ElementAt( 0, Index, OUT PI ) THEN
         Key := PI^.Key;
         Data := PI^.Data;
         RETURN TRUE;
      ELSE
         RETURN FALSE;
      END;
   END CIntegerBaseMap.ElementAt;

(*---------------------------------------------------------------------------*)

   PUBLIC PROCEDURE CIntegerBaseMap.GetIterator() : TPIntegerBaseMapIterator;
   VAR
      iterator : TPIntegerBaseMapIterator := NEW( CIntegerBaseMapIterator );
   BEGIN
      iterator^.Init( ADR( SELF ), collection.dirForward );
      RETURN iterator;
   END CIntegerBaseMap.GetIterator;

(*---------------------------------------------------------------------------*)

END CIntegerBaseMap;

(*==========================================================================*)

CLASS IMPLEMENTATION CIntegerBaseMapIterator;

(*---------------------------------------------------------------------------*)

   PUBLIC PROPERTY Key GET : INTEGER;
   BEGIN
      IF Current = NIL THEN
         RETURN 0;
      ELSE
         RETURN TPIntegerBaseItem( Current )^.Key;
      END;
   END Key;

(*---------------------------------------------------------------------------*)

   PUBLIC PROPERTY Data GET : baseobject.PIBASE;
   BEGIN
      IF Current = NIL THEN
         RETURN NIL;
      ELSE
         RETURN TPIntegerBaseItem( Current )^.Data;
      END;
   END Data;

(*---------------------------------------------------------------------------*)

   PUBLIC PROPERTY Data SET( Value : baseobject.PIBASE );
   BEGIN
      IF Current <> NIL THEN
         TPIntegerBaseItem( Current )^.Data := Value;
      END;
   END Data;

(*---------------------------------------------------------------------------*)

END CIntegerBaseMapIterator;

(*==========================================================================*)

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
      iterator^.Init( ADR( SELF ), collection.dirForward );
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
   TPPtrBaseItem = POINTER TO CPtrBaseItem;

CLASS CPtrBaseItem( CBaseItem );

   PUBLIC VAR
      Key : PTR;

   PUBLIC VIRTUAL PROCEDURE Compare( i : CARDINAL; pelem : avltree.TPAVLTreeKey ) : TRISTATE;

END CPtrBaseItem;

(*---------------------------------------------------------------------------*)

CLASS IMPLEMENTATION CPtrBaseItem;

(*---------------------------------------------------------------------------*)

   PUBLIC VIRTUAL PROCEDURE Compare( i : CARDINAL; pelem : avltree.TPAVLTreeKey ) : TRISTATE;
   BEGIN
      IF Key < TPPtrBaseItem( pelem )^.Key THEN
         RETURN -1;
      ELSIF Key > TPPtrBaseItem( pelem )^.Key THEN
         RETURN 1;
      ELSE
         RETURN 0;
      END;
   END Compare;

(*---------------------------------------------------------------------------*)

BEGIN
   Key := 0;
END CPtrBaseItem;

(*==========================================================================*)

CLASS IMPLEMENTATION CPtrBaseMap;

(*---------------------------------------------------------------------------*)

   PUBLIC READONLY INDEX CPtrBaseMap GET( Index : CARDINAL ) : baseobject.PIBASE;
   VAR
      PI : TPPtrBaseItem;
   BEGIN
      IF SUPER.ElementAt( 0, Index, OUT PI ) THEN
         RETURN PI^.Data;
      ELSE
         RETURN NIL;
      END;
   END CPtrBaseMap;

(*---------------------------------------------------------------------------*)

   PUBLIC PROCEDURE CPtrBaseMap.Add( Key : PTR; Data : baseobject.PIBASE );
   VAR
      PI : TPPtrBaseItem;
   BEGIN
      NEW( PI );
      PI^.Key := Key;
      PI^.Data := Data;
      SUPER.Add( PI );
   END CPtrBaseMap.Add;
  
(*---------------------------------------------------------------------------*)

   PUBLIC PROCEDURE CPtrBaseMap.Remove( Key : PTR );
   VAR
      I : CPtrBaseItem;
   BEGIN
      I.Key := Key;
      Delete( 0, ADR( I ));
   END CPtrBaseMap.Remove;

(*---------------------------------------------------------------------------*)

   PUBLIC PROCEDURE CPtrBaseMap.Contains( Key : PTR ) : BOOLEAN;
   VAR
      I : CPtrBaseItem;
   BEGIN
      I.Key := Key;
      RETURN SUPER.Contains( 0, ADR( I ));
   END CPtrBaseMap.Contains;

(*---------------------------------------------------------------------------*)

   PUBLIC PROCEDURE CPtrBaseMap.Get( Key : PTR; OUT Data : baseobject.PIBASE ) : BOOLEAN;
   VAR
      I : CPtrBaseItem;
      PI : TPPtrBaseItem;
   BEGIN
      I.Key := Key;
      IF NOT SUPER.Get( 0, ADR( I ), OUT PI ) THEN
         RETURN FALSE;
      END;
      Data := PI^.Data;
      RETURN TRUE;  
   END CPtrBaseMap.Get;

(*---------------------------------------------------------------------------*)

   PUBLIC PROCEDURE CPtrBaseMap.ElementAt( Index : CARDINAL; OUT Key : PTR; OUT Data : baseobject.PIBASE ) : BOOLEAN;
   VAR
      PI : TPPtrBaseItem;
   BEGIN
      IF SUPER.ElementAt( 0, Index, OUT PI ) THEN
         Key := PI^.Key;
         Data := PI^.Data;
         RETURN TRUE;
      ELSE
         RETURN FALSE;
      END;
   END CPtrBaseMap.ElementAt;

(*---------------------------------------------------------------------------*)

   PUBLIC PROCEDURE CPtrBaseMap.GetIterator() : TPPtrBaseMapIterator;
   VAR
      iterator : TPPtrBaseMapIterator := NEW( CPtrBaseMapIterator );
   BEGIN
      iterator^.Init( ADR( SELF ), collection.dirForward );
      RETURN iterator;
   END CPtrBaseMap.GetIterator;

(*---------------------------------------------------------------------------*)

END CPtrBaseMap;

(*==========================================================================*)

CLASS IMPLEMENTATION CPtrBaseMapIterator;

(*---------------------------------------------------------------------------*)

   PUBLIC PROPERTY Key GET : PTR;
   BEGIN
      IF Current = NIL THEN
         RETURN 0;
      ELSE
         RETURN TPPtrBaseItem( Current )^.Key;
      END;
   END Key;

(*---------------------------------------------------------------------------*)

   PUBLIC PROPERTY Data GET : baseobject.PIBASE;
   BEGIN
      IF Current = NIL THEN
         RETURN NIL;
      ELSE
         RETURN TPPtrBaseItem( Current )^.Data;
      END;
   END Data;

(*---------------------------------------------------------------------------*)

   PUBLIC PROPERTY Data SET( Value : baseobject.PIBASE );
   BEGIN
      IF Current <> NIL THEN
         TPPtrBaseItem( Current )^.Data := Value;
      END;
   END Data;

(*---------------------------------------------------------------------------*)

END CPtrBaseMapIterator;

(*==========================================================================*)

TYPE
   TPStringBaseItem = POINTER TO CStringBaseItem;

CLASS CStringBaseItem( CBaseItem );

   PUBLIC VAR
      Key : CString;

   PUBLIC VIRTUAL PROCEDURE Compare( i : CARDINAL; pelem : avltree.TPAVLTreeKey ) : TRISTATE;

END CStringBaseItem;

(*---------------------------------------------------------------------------*)

CLASS IMPLEMENTATION CStringBaseItem;

(*---------------------------------------------------------------------------*)

   PUBLIC VIRTUAL PROCEDURE Compare( i : CARDINAL; pelem : avltree.TPAVLTreeKey ) : TRISTATE;
   BEGIN
      RETURN Key.Compare( TPStringBaseItem( pelem )^.Key );
   END Compare;

(*---------------------------------------------------------------------------*)

END CStringBaseItem;

(*==========================================================================*)

CLASS IMPLEMENTATION CStringBaseMap;

(*---------------------------------------------------------------------------*)

   PUBLIC READONLY INDEX CStringBaseMap GET( Index : CARDINAL ) : baseobject.PIBASE;
   VAR
      PI : TPStringBaseItem;
   BEGIN
      IF SUPER.ElementAt( 0, Index, OUT PI ) THEN
         RETURN PI^.Data;
      ELSE
         RETURN NIL;
      END;
   END CStringBaseMap;

(*---------------------------------------------------------------------------*)

   PUBLIC PROCEDURE CStringBaseMap.Add( CONST Key : IString; Data : baseobject.PIBASE );
   VAR
      PI : TPStringBaseItem;
   BEGIN
      NEW( PI );
      PI^.Key.Assign( Key );
      PI^.Data := Data;
      SUPER.Add( PI );
   END CStringBaseMap.Add;
  
(*---------------------------------------------------------------------------*)

   PUBLIC PROCEDURE CStringBaseMap.Remove( CONST Key : IString );
   VAR
      I : CStringBaseItem;
   BEGIN
      I.Key.Assign( Key );
      Delete( 0, ADR( I ));
   END CStringBaseMap.Remove;

(*---------------------------------------------------------------------------*)

   PUBLIC PROCEDURE CStringBaseMap.Contains( CONST Key : IString ) : BOOLEAN;
   VAR
      I : CStringBaseItem;
   BEGIN
      I.Key.Assign( Key );
      RETURN SUPER.Contains( 0, ADR( I ));
   END CStringBaseMap.Contains;

(*---------------------------------------------------------------------------*)

   PUBLIC PROCEDURE CStringBaseMap.Get( CONST Key : IString; OUT Data : baseobject.PIBASE ) : BOOLEAN;
   VAR
      I : CStringBaseItem;
      PI : TPStringBaseItem;
   BEGIN
      I.Key.Assign( Key );
      IF NOT SUPER.Get( 0, ADR( I ), OUT PI ) THEN
         RETURN FALSE;
      END;
      Data := PI^.Data;
      RETURN TRUE;  
   END CStringBaseMap.Get;

(*---------------------------------------------------------------------------*)

   PUBLIC PROCEDURE CStringBaseMap.ElementAt( Index : CARDINAL; OUT Key : IString; OUT Data : baseobject.PIBASE ) : BOOLEAN;
   VAR
      PI : TPStringBaseItem;
   BEGIN
      IF SUPER.ElementAt( 0, Index, OUT PI ) THEN
         Key := PI^.Key;
         Data := PI^.Data;
         RETURN TRUE;
      ELSE
         RETURN FALSE;
      END;
   END CStringBaseMap.ElementAt;

(*---------------------------------------------------------------------------*)

   PUBLIC PROCEDURE CStringBaseMap.GetIterator() : TPStringBaseMapIterator;
   VAR
      iterator : TPStringBaseMapIterator := NEW( CStringBaseMapIterator );
   BEGIN
      iterator^.Init( ADR( SELF ), collection.dirForward );
      RETURN iterator;
   END CStringBaseMap.GetIterator;

(*---------------------------------------------------------------------------*)

END CStringBaseMap;

(*==========================================================================*)

CLASS IMPLEMENTATION CStringBaseMapIterator;

(*---------------------------------------------------------------------------*)

   PUBLIC PROPERTY Key GET : TPString;
   BEGIN
      IF Current = NIL THEN
         RETURN NIL;
      ELSE
         RETURN ADR( TPStringBaseItem( Current )^.Key );
      END;
   END Key;

(*---------------------------------------------------------------------------*)

   PUBLIC PROPERTY Data GET : baseobject.PIBASE;
   BEGIN
      IF Current = NIL THEN
         RETURN NIL;
      ELSE
         RETURN TPStringBaseItem( Current )^.Data;
      END;
   END Data;

(*---------------------------------------------------------------------------*)

   PUBLIC PROPERTY Data SET( Value : baseobject.PIBASE );
   BEGIN
      IF Current <> NIL THEN
         TPStringBaseItem( Current )^.Data := Value;
      END;
   END Data;

(*---------------------------------------------------------------------------*)

END CStringBaseMapIterator;

(*==========================================================================*)

TYPE
   TPStringPtrItem = POINTER TO CStringPtrItem;

CLASS CStringPtrItem( avltree.CAVLTreeElem );

   PUBLIC VAR
      Key : CString;
      Data : PTR := 0;

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

BEGIN
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
         Key.Assign( PI^.Key );
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
      iterator^.Init( ADR( SELF ), collection.dirForward );
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
      iterator^.Init( ADR( SELF ), collection.dirForward );
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