IMPLEMENTATION MODULE maps;

//===========================================================================
//
// simple AVL tree implementations
//
// version 1 (c) 1993-2006 mk
//
//===========================================================================

FROM Debug IMPORT
   Assertion, LogAssertionW;

// FROM StorageO IMPORT
   // CSlotAllocator;

//---------------------------------------------------------------------------

// VAR
   // IntegerAllocator : CSlotAllocator;
   // CardinalAllocator : CSlotAllocator;
   // PtrAllocator : CSlotAllocator;

(*==========================================================================*)
// common ancestor

ABSTRACT CLASS CBaseItem( avltree.CAVLTreeElem );

   // CDisposable
   PUBLIC VIRTUAL PROCEDURE Dispose();

   // SELF   
   LOCAL VAR
      Data : baseobject.PBASE := NIL;
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
      Key  : INTEGER;

   PUBLIC VIRTUAL PROCEDURE Compare( i : CARDINAL; pelem : avltree.TPAVLTreeKey ) : TRISTATE;

   // OPERATOR NEW() : ADDRESS;
   // OPERATOR DISPOSE( a : ADDRESS );
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

   // OPERATOR CIntegerItem.NEW() : ADDRESS;
   // VAR
   //   a : ADDRESS;
   // BEGIN
   //   IF IntegerAllocator.Allocate( OUT a, SIZE( CIntegerItem )) THEN
   //     RETURN a;
   //   ELSE
   //     RETURN NIL;
   //   END;
   // END CIntegerItem.NEW;
  
   // OPERATOR CIntegerItem.DISPOSE( a : ADDRESS );
   // BEGIN
   //   IntegerAllocator.Deallocate( REF a );
   // END CIntegerItem.DISPOSE;

(*---------------------------------------------------------------------------*)

BEGIN
   Key := -1;
END CIntegerBaseItem;

(*==========================================================================*)

CLASS IMPLEMENTATION CIntegerBaseMap;

(*---------------------------------------------------------------------------*)

   PUBLIC READONLY INDEX CIntegerBaseMap GET( Index : CARDINAL ) : baseobject.PBASE;
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

   PUBLIC PROCEDURE CIntegerBaseMap.Add( Key : INTEGER; Data : baseobject.PBASE );
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

   PUBLIC PROCEDURE CIntegerBaseMap.Get( Key : INTEGER; OUT Data : baseobject.PBASE ) : BOOLEAN; // similar as []
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

   PUBLIC PROCEDURE CIntegerBaseMap.ElementAt( Index : CARDINAL; OUT Key : INTEGER; OUT Data : baseobject.PBASE ) : BOOLEAN;
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
      iterator^.Init( ADR( SELF ));
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

   PUBLIC PROPERTY Data GET : baseobject.PBASE;
   BEGIN
      IF Current = NIL THEN
         RETURN NIL;
      ELSE
         RETURN TPIntegerBaseItem( Current )^.Data;
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

   // OPERATOR NEW() : ADDRESS;
   // OPERATOR DISPOSE( a : ADDRESS );

END CIntegerStringItem;

(*---------------------------------------------------------------------------*)

CLASS IMPLEMENTATION CIntegerStringItem;

(*---------------------------------------------------------------------------*)

   PUBLIC VIRTUAL PROCEDURE Compare( i : CARDINAL; pelem : avltree.TPAVLTreeKey ) : TRISTATE;
   BEGIN
      IF Key < TPIntegerItem( pelem )^.Key THEN
         RETURN -1;
      ELSIF Key > TPIntegerItem( pelem )^.Key THEN
         RETURN 1;
      ELSE
         RETURN 0;
      END;
   END Compare;

   // OPERATOR CIntegerItem.NEW() : ADDRESS;
   // VAR
   //   a : ADDRESS;
   // BEGIN
   //   IF IntegerAllocator.Allocate( OUT a, SIZE( CIntegerItem )) THEN
   //     RETURN a;
   //   ELSE
   //     RETURN NIL;
   //   END;
   // END CIntegerItem.NEW;
  
   // OPERATOR CIntegerItem.DISPOSE( a : ADDRESS );
   // BEGIN
   //   IntegerAllocator.Deallocate( REF a );
   // END CIntegerItem.DISPOSE;

(*---------------------------------------------------------------------------*)

BEGIN
   Key := -1;
END CIntegerStringItem;

(*==========================================================================*)

CLASS IMPLEMENTATION CIntegerStringMap;

(*---------------------------------------------------------------------------*)

  PUBLIC READONLY INDEX CIntegerStringMap GET ( Index : CARDINAL ) : POINTER TO CString;
  VAR
    PI : TPIntegerStringItem;
  BEGIN
    PI := TPIntegerStringItem( SUPER[ Index ] );
    IF PI = NIL THEN
      RETURN NIL;
    ELSE
      RETURN ADR( PI^.Data );
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
    Insert( PI );
  END CIntegerStringMap.Add;
  
(*---------------------------------------------------------------------------*)

  PUBLIC PROCEDURE CIntegerStringMap.Remove( Key : INTEGER );
  VAR
    I : CIntegerStringItem;
  BEGIN
    I.Key := Key;
    Delete( ADR( I ));
  END CIntegerStringMap.Remove;

(*---------------------------------------------------------------------------*)

  PUBLIC PROCEDURE CIntegerStringMap.Contains( Key : INTEGER ) : BOOLEAN;
  VAR
    I : CIntegerStringItem;
  BEGIN
    I.Key := Key;
    RETURN SUPER.Contains( ADR( I ));
  END CIntegerStringMap.Contains;

(*---------------------------------------------------------------------------*)

  PUBLIC PROCEDURE CIntegerStringMap.Get( Key : INTEGER; OUT Data : IString ) : BOOLEAN; // similar as []
  VAR
    I : CIntegerStringItem;
    PI : TPIntegerStringItem;
  BEGIN
    I.Key := Key;
    IF NOT Search( ADR( I ), OUT PI ) THEN
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
    PI := TPIntegerStringItem( SUPER[ Index ] );
    IF PI = NIL THEN
      RETURN FALSE;
    ELSE
      Key := PI^.Key;
      Data.Assign( PI^.Data );
    END;
    RETURN TRUE;
  END CIntegerStringMap.ElementAt;

END CIntegerStringMap;

//===========================================================================

TYPE
  TPPtrItem = POINTER TO CPtrItem;

CLASS CPtrItem( avltree.CAVLTreeElem );
  PUBLIC VAR
    Key  : PTR;
    Data : PTR;

  PUBLIC VIRTUAL PROCEDURE Compare( i : CARDINAL; pelem : avltree.TPAVLTreeKey ) : TRISTATE;

  // OPERATOR NEW() : ADDRESS;
  // OPERATOR DISPOSE( a : ADDRESS );
END CPtrItem;

//---------------------------------------------------------------------------

CLASS IMPLEMENTATION CPtrItem;

(*---------------------------------------------------------------------------*)

  PUBLIC VIRTUAL PROCEDURE Compare( i : CARDINAL; pelem : avltree.TPAVLTreeKey ) : TRISTATE;
  BEGIN
    IF Key < TPPtrItem( pelem )^.Key THEN
      RETURN -1;
    ELSIF Key > TPPtrItem( pelem )^.Key THEN
      RETURN 1;
    ELSE
      RETURN 0;
    END;
  END Compare;

  // OPERATOR CPtrItem.NEW() : ADDRESS;
  // VAR
  //   a : ADDRESS;
  // BEGIN
  //   IF PtrAllocator.Allocate( OUT a, SIZE( CPtrItem )) THEN
  //     RETURN a;
  //   ELSE
  //     RETURN NIL;
  //   END;
  // END CPtrItem.NEW;
  
  // OPERATOR CPtrItem.DISPOSE( a : ADDRESS );
  // BEGIN
  //   PtrAllocator.Deallocate( REF a );
  // END CPtrItem.DISPOSE;

BEGIN
  Key := -1;
  Data := NIL;
END CPtrItem;

(*---------------------------------------------------------------------------*)

CLASS IMPLEMENTATION CPtrMap;

  PUBLIC READONLY INDEX CPtrMap GET( Index : CARDINAL ) : PTR;
  VAR
    PI : TPPtrItem;
  BEGIN
    PI := TPPtrItem( SUPER[ Index ] );
    IF PI = NIL THEN
      RETURN NIL;
    ELSE
      RETURN PI^.Data;
    END;
  END CPtrMap;

  PUBLIC PROCEDURE CPtrMap.Add( Key : PTR; Data : PTR );
  VAR
    PI : TPPtrItem;
  BEGIN
    NEW( PI );
    PI^.Key := Key;
    PI^.Data := Data;
    Insert( PI );
  END CPtrMap.Add;
  
  PUBLIC PROCEDURE CPtrMap.Remove( Key : PTR );
  VAR
    I : CPtrItem;
  BEGIN
    I.Key := Key;
    Delete( ADR( I ));
  END CPtrMap.Remove;

  PUBLIC PROCEDURE CPtrMap.Contains( Key : PTR ) : BOOLEAN;
  VAR
    I : CPtrItem;
  BEGIN
    I.Key := Key;
    RETURN SUPER.Contains( ADR( I ));
  END CPtrMap.Contains;

  PUBLIC PROCEDURE CPtrMap.Get( Key : PTR; OUT Data : PTR ) : BOOLEAN; // similar as []
  VAR
    I : CPtrItem;
    PI : TPPtrItem;
  BEGIN
    I.Key := Key;
    IF NOT Search( ADR( I ), OUT PI ) THEN
      RETURN FALSE;
    END;
    Data := PI^.Data;
    RETURN TRUE;  
  END CPtrMap.Get;

  PUBLIC PROCEDURE CPtrMap.ElementAt( Index : CARDINAL; OUT Key : PTR; OUT Data : PTR ) : BOOLEAN;
  VAR
    PI : TPPtrItem;
  BEGIN
    PI := TPPtrItem( SUPER[ Index ] );
    IF PI = NIL THEN
      RETURN FALSE;
    ELSE
      Key := PI^.Key;
      Data := PI^.Data;
    END;
    RETURN TRUE;
  END CPtrMap.ElementAt;

END CPtrMap;

//===========================================================================

TYPE
  TPStringItem = POINTER TO CStringItem;

CLASS CStringItem( avltree.CAVLTreeElem );
  PUBLIC VAR
    Key  : CString;
    Data : PTR;

  PUBLIC VIRTUAL PROCEDURE Compare( i : CARDINAL; pelem : avltree.TPAVLTreeKey ) : TRISTATE;

  // OPERATOR NEW() : ADDRESS;
  // OPERATOR DISPOSE( a : ADDRESS );
END CStringItem;

//---------------------------------------------------------------------------

CLASS IMPLEMENTATION CStringItem;

  PUBLIC VIRTUAL PROCEDURE Compare( i : CARDINAL; pelem : avltree.TPAVLTreeKey ) : TRISTATE;
  BEGIN
    RETURN Key.Compare( TPStringItem( pelem )^.Key );
  END Compare;

  // OPERATOR CPtrItem.NEW() : ADDRESS;
  // VAR
  //   a : ADDRESS;
  // BEGIN
  //   IF PtrAllocator.Allocate( OUT a, SIZE( CPtrItem )) THEN
  //     RETURN a;
  //   ELSE
  //     RETURN NIL;
  //   END;
  // END CPtrItem.NEW;
  
  // OPERATOR CPtrItem.DISPOSE( a : ADDRESS );
  // BEGIN
  //   PtrAllocator.Deallocate( REF a );
  // END CPtrItem.DISPOSE;

BEGIN
  Data := NIL;
END CStringItem;

//---------------------------------------------------------------------------

CLASS IMPLEMENTATION CStringMap;

  PUBLIC READONLY PROPERTY CStringMap.Current GET : POINTER TO CString;
  BEGIN
    IF _Current = -1 THEN
      RETURN NIL;
    ELSE
      RETURN ADR( TPStringItem( _Current )^.Key );
    END;
  END CStringMap.Current;

//---------------------------------------------------------------------------

  PUBLIC READONLY PROPERTY CStringMap.CurrentData GET : PTR;
  BEGIN
    IF _Current = -1 THEN
      RETURN NIL;
    ELSE
      RETURN TPStringItem( _Current )^.Data;
    END;
  END CStringMap.CurrentData;

//---------------------------------------------------------------------------

  PUBLIC PROPERTY CStringMap.CurrentData SET( Data : PTR );
  BEGIN
    IF _Current = -1 THEN
      RETURN;
    ELSE
      TPStringItem( _Current )^.Data := Data;
    END;
  END CStringMap.CurrentData;

//---------------------------------------------------------------------------

  PUBLIC READONLY INDEX CStringMap GET( Index : CARDINAL ) : PTR;
  VAR
    PI : TPStringItem;
  BEGIN
    PI := TPStringItem( SUPER[ Index ] );
    IF PI = NIL THEN
      RETURN NIL;
    ELSE
      RETURN PI^.Data;
    END;
  END CStringMap;

  PUBLIC PROCEDURE CStringMap.Add( CONST Key : IString; Data : PTR );
  VAR
    PI : TPStringItem;
  BEGIN
    NEW( PI );
    PI^.Key.Assign( Key );
    PI^.Data := Data;
    Insert( PI );
  END CStringMap.Add;
  
  PUBLIC PROCEDURE CStringMap.Remove( CONST Key : IString );
  VAR
    I : CStringItem;
  BEGIN
    I.Key.Assign( Key );
    Delete( ADR( I ));
  END CStringMap.Remove;

  PUBLIC PROCEDURE CStringMap.Contains( CONST Key : IString ) : BOOLEAN;
  VAR
    I : CStringItem;
  BEGIN
    I.Key.Assign( Key );
    RETURN SUPER.Contains( ADR( I ));
  END CStringMap.Contains;

  PUBLIC PROCEDURE CStringMap.Get( CONST Key : IString; OUT Data : PTR ) : BOOLEAN; // similar as []
  VAR
    I : CStringItem;
    PI : TPStringItem;
  BEGIN
    I.Key.Assign( Key );
    IF NOT Search( ADR( I ), OUT PI ) THEN
      RETURN FALSE;
    END;
    Data := PI^.Data;
    RETURN TRUE;  
  END CStringMap.Get;

  PUBLIC PROCEDURE CStringMap.ElementAt( Index : CARDINAL; OUT Key : IString; OUT Data : PTR ) : BOOLEAN;
  VAR
    PI : TPStringItem;
  BEGIN
    PI := TPStringItem( SUPER[ Index ] );
    IF PI = NIL THEN
      RETURN FALSE;
    ELSE
      Key.Assign( PI^.Key );
      Data := PI^.Data;
    END;
    RETURN TRUE;
  END CStringMap.ElementAt;

  PUBLIC PROCEDURE AddOA( CONST Key : ARRAY OF WCHAR; Data : PTR );
  VAR
    PI : TPStringItem;
  BEGIN
    NEW( PI );
    PI^.Key.FromOA( Key );
    PI^.Data := Data;
    Insert( PI );
  END CStringMap.AddOA;
  
  PUBLIC PROCEDURE RemoveOA( CONST Key : ARRAY OF WCHAR );
  VAR
    I : CStringItem;
  BEGIN
    I.Key.FromOA( Key );
    Delete( ADR( I ));
  END CStringMap.RemoveOA;

  PUBLIC PROCEDURE ContainsOA( CONST Key : ARRAY OF WCHAR ) : BOOLEAN;
  VAR
    I : CStringItem;
  BEGIN
    I.Key.FromOA( Key );
    RETURN SUPER.Contains( ADR( I ));
  END CStringMap.ContainsOA;

  PUBLIC PROCEDURE GetOA( CONST Key : ARRAY OF WCHAR; OUT Data : PTR ) : BOOLEAN; // similar as []
  VAR
    I : CStringItem;
    PI : TPStringItem;
  BEGIN
    I.Key.FromOA( Key );
    IF NOT Search( ADR( I ), OUT PI ) THEN
      RETURN FALSE;
    END;
    Data := PI^.Data;
    RETURN TRUE;  
  END CStringMap.GetOA;

  PUBLIC PROCEDURE CStringMap.ElementAtOA( Index : CARDINAL; OUT Key : ARRAY OF WCHAR; OUT Data : PTR ) : BOOLEAN;
  VAR
    PI : TPStringItem;
  BEGIN
    PI := TPStringItem( SUPER[ Index ] );
    IF PI = NIL THEN
      RETURN FALSE;
    ELSE
      PI^.Key.ToOA( OUT Key );
      Data := PI^.Data;
    END;
    RETURN TRUE;
  END CStringMap.ElementAtOA;

END CStringMap;

//===========================================================================

TYPE
  TPStringStringItem = POINTER TO CStringStringItem;

CLASS CStringStringItem( avltree.CAVLTreeElem );
  PUBLIC VAR
    Key  : CString;
    Data : CString;

  PUBLIC VIRTUAL PROCEDURE Compare( i : CARDINAL; pelem : avltree.TPAVLTreeKey ) : TRISTATE;

  // OPERATOR NEW() : ADDRESS;
  // OPERATOR DISPOSE( a : ADDRESS );
END CStringStringItem;

//---------------------------------------------------------------------------

CLASS IMPLEMENTATION CStringStringItem;

  PUBLIC VIRTUAL PROCEDURE Compare( i : CARDINAL; pelem : avltree.TPAVLTreeKey ) : TRISTATE;
  BEGIN
    RETURN Key.Compare( TPStringStringItem( pelem )^.Key );
  END Compare;

  // OPERATOR CPtrItem.NEW() : ADDRESS;
  // VAR
  //   a : ADDRESS;
  // BEGIN
  //   IF PtrAllocator.Allocate( OUT a, SIZE( CPtrItem )) THEN
  //     RETURN a;
  //   ELSE
  //     RETURN NIL;
  //   END;
  // END CPtrItem.NEW;
  
  // OPERATOR CPtrItem.DISPOSE( a : ADDRESS );
  // BEGIN
  //   PtrAllocator.Deallocate( REF a );
  // END CPtrItem.DISPOSE;

END CStringStringItem;

//---------------------------------------------------------------------------

CLASS IMPLEMENTATION CStringStringMap;

  PUBLIC READONLY PROPERTY CStringStringMap.Current GET : POINTER TO CString;
  BEGIN
    IF _Current = -1 THEN
      RETURN NIL;
    ELSE
      RETURN ADR( TPStringStringItem( _Current )^.Key );
    END;
  END CStringStringMap.Current;

//---------------------------------------------------------------------------

  PUBLIC READONLY PROPERTY CStringStringMap.CurrentData GET : POINTER TO CString;
  BEGIN
    IF _Current = -1 THEN
      RETURN NIL;
    ELSE
      RETURN ADR( TPStringStringItem( _Current )^.Data );
    END;
  END CStringStringMap.CurrentData;

//---------------------------------------------------------------------------

  PUBLIC PROPERTY CStringStringMap.CurrentData SET( Data : POINTER TO CString );
  BEGIN
    IF _Current = -1 THEN
      RETURN;
    ELSE
      TPStringStringItem( _Current )^.Data := Data^;
    END;
  END CStringStringMap.CurrentData;

//---------------------------------------------------------------------------

  PUBLIC READONLY INDEX CStringStringMap GET( Index : CARDINAL ) : POINTER TO CString;
  VAR
    PI : TPStringStringItem;
  BEGIN
    PI := TPStringStringItem( SUPER[ Index ] );
    IF PI = NIL THEN
      RETURN NIL;
    ELSE
      RETURN ADR( PI^.Data );
    END;
  END CStringStringMap;

  PUBLIC PROCEDURE CStringStringMap.Add( CONST Key : IString; CONST Data : IString );
  VAR
    PI : TPStringStringItem;
  BEGIN
    NEW( PI );
    PI^.Key.Assign( Key );
    PI^.Data.Assign( Data );
    Insert( PI );
  END CStringStringMap.Add;
  
  PUBLIC PROCEDURE CStringStringMap.Remove( CONST Key : IString );
  VAR
    I : CStringStringItem;
  BEGIN
    I.Key.Assign( Key );
    Delete( ADR( I ));
  END CStringStringMap.Remove;

  PUBLIC PROCEDURE CStringStringMap.Contains( CONST Key : IString ) : BOOLEAN;
  VAR
    I : CStringStringItem;
  BEGIN
    I.Key.Assign( Key );
    RETURN SUPER.Contains( ADR( I ));
  END CStringStringMap.Contains;

  PUBLIC PROCEDURE CStringStringMap.Get( CONST Key : IString; OUT Data : IString ) : BOOLEAN; // similar as []
  VAR
    I : CStringStringItem;
    PI : TPStringStringItem;
  BEGIN
    I.Key.Assign( Key );
    IF NOT Search( ADR( I ), OUT PI ) THEN
      RETURN FALSE;
    END;
    Data.Assign( PI^.Data );
    RETURN TRUE;  
  END CStringStringMap.Get;

  PUBLIC PROCEDURE CStringStringMap.ElementAt( Index : CARDINAL; OUT Key : IString; OUT Data : IString ) : BOOLEAN;
  VAR
    PI : TPStringStringItem;
  BEGIN
    PI := TPStringStringItem( SUPER[ Index ] );
    IF PI = NIL THEN
      RETURN FALSE;
    ELSE
      Key.Assign( PI^.Key );
      Data.Assign( PI^.Data );
    END;
    RETURN TRUE;
  END CStringStringMap.ElementAt;

  PUBLIC PROCEDURE AddOA( CONST Key : ARRAY OF WCHAR; CONST Data : IString );
  VAR
    PI : TPStringStringItem;
  BEGIN
    NEW( PI );
    PI^.Key.FromOA( Key );
    PI^.Data.Assign( Data );
    Insert( PI );
  END CStringStringMap.AddOA;
  
  PUBLIC PROCEDURE RemoveOA( CONST Key : ARRAY OF WCHAR );
  VAR
    I : CStringStringItem;
  BEGIN
    I.Key.FromOA( Key );
    Delete( ADR( I ));
  END CStringStringMap.RemoveOA;

  PUBLIC PROCEDURE ContainsOA( CONST Key : ARRAY OF WCHAR ) : BOOLEAN;
  VAR
    I : CStringStringItem;
  BEGIN
    I.Key.FromOA( Key );
    RETURN SUPER.Contains( ADR( I ));
  END CStringStringMap.ContainsOA;

  PUBLIC PROCEDURE GetOA( CONST Key : ARRAY OF WCHAR; OUT Data : IString ) : BOOLEAN; // similar as []
  VAR
    I : CStringStringItem;
    PI : TPStringStringItem;
  BEGIN
    I.Key.FromOA( Key );
    IF NOT Search( ADR( I ), OUT PI ) THEN
      RETURN FALSE;
    END;
    Data.Assign( PI^.Data );
    RETURN TRUE;  
  END CStringStringMap.GetOA;

  PUBLIC PROCEDURE CStringStringMap.ElementAtOA( Index : CARDINAL; OUT Key : ARRAY OF WCHAR; OUT Data : IString ) : BOOLEAN;
  VAR
    PI : TPStringStringItem;
  BEGIN
    PI := TPStringStringItem( SUPER[ Index ] );
    IF PI = NIL THEN
      RETURN FALSE;
    ELSE
      PI^.Key.ToOA( OUT Key );
      Data.Assign( PI^.Data );
    END;
    RETURN TRUE;
  END CStringStringMap.ElementAtOA;

END CStringStringMap;

//===========================================================================

// INITIALLY __I();
// BEGIN
  // IntegerAllocator.Init( SIZE( CIntegerItem ), 0 );
  // CardinalAllocator.Init( SIZE( CCardinalItem ), 0 );
  // PtrAllocator.Init( SIZE( CPtrItem ), 0 );
// END __I;

END maps.