IMPLEMENTATION MODULE maps;

//===========================================================================
//
// simple AVL tree implementations
//
// version 1 (c) 1993-2006 mk
//
//===========================================================================

FROM Storage IMPORT
  ALLOCATE;
  
// FROM StorageO IMPORT
  // CSlotAllocator;

//---------------------------------------------------------------------------

// VAR
  // IntegerAllocator : CSlotAllocator;
  // CardinalAllocator : CSlotAllocator;
  // PtrAllocator : CSlotAllocator;

//---------------------------------------------------------------------------

TYPE
  TPIntegerItem = POINTER TO CIntegerItem;

CLASS CIntegerItem( avltree.CAVLTreeElem );
  PUBLIC VAR
    Key  : INTEGER;
    Data : PTR;

  PUBLIC VIRTUAL PROCEDURE Compare( i : CARDINAL; pelem : avltree.TPAVLTreeKey ) : TRISTATE;

  // OPERATOR NEW() : ADDRESS;
  // OPERATOR DISPOSE( a : ADDRESS );
END CIntegerItem;

//---------------------------------------------------------------------------

CLASS IMPLEMENTATION CIntegerItem;

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

BEGIN
  Key := -1;
  Data := NIL;
END CIntegerItem;

//---------------------------------------------------------------------------

CLASS IMPLEMENTATION CIntegerMap;

  PUBLIC READONLY PROPERTY CIntegerMap.Current GET : INTEGER;
  BEGIN
    IF _Current = -1 THEN
      RETURN 0;
    ELSE
      RETURN TPIntegerItem( _Current )^.Key;
    END;
  END CIntegerMap.Current;

//---------------------------------------------------------------------------

  PUBLIC READONLY PROPERTY CIntegerMap.CurrentData GET : PTR;
  BEGIN
    IF _Current = -1 THEN
      RETURN NIL;
    ELSE
      RETURN TPIntegerItem( _Current )^.Data;
    END;
  END CIntegerMap.CurrentData;

//---------------------------------------------------------------------------

  PUBLIC PROPERTY CIntegerMap.CurrentData SET( Data : PTR );
  BEGIN
    IF _Current = -1 THEN
      RETURN;
    ELSE
      TPIntegerItem( _Current )^.Data := Data;
    END;
  END CIntegerMap.CurrentData;

//---------------------------------------------------------------------------

  PUBLIC READONLY INDEX CIntegerMap GET ( Index : CARDINAL ) : PTR;
  VAR
    PI : TPIntegerItem;
  BEGIN
    PI := TPIntegerItem( SUPER[ Index ] );
    IF PI = NIL THEN
      RETURN NIL;
    ELSE
      RETURN PI^.Data;
    END;
  END CIntegerMap;

  PUBLIC PROCEDURE CIntegerMap.Add( Key : INTEGER; Data : PTR );
  VAR
    PI : TPIntegerItem;
  BEGIN
    NEW( PI );
    PI^.Key := Key;
    PI^.Data := Data;
    Insert( PI );
  END CIntegerMap.Add;
  
  PUBLIC PROCEDURE CIntegerMap.Remove( Key : INTEGER );
  VAR
    I : CIntegerItem;
  BEGIN
    I.Key := Key;
    Delete( ADR( I ));
  END CIntegerMap.Remove;

  PUBLIC PROCEDURE CIntegerMap.Contains( Key : INTEGER ) : BOOLEAN;
  VAR
    I : CIntegerItem;
  BEGIN
    I.Key := Key;
    RETURN SUPER.Contains( ADR( I ));
  END CIntegerMap.Contains;

  PUBLIC PROCEDURE CIntegerMap.Get( Key : INTEGER; OUT Data : PTR ) : BOOLEAN; // similar as []
  VAR
    I : CIntegerItem;
    PI : TPIntegerItem;
  BEGIN
    I.Key := Key;
    IF NOT Search( ADR( I ), OUT PI ) THEN
      RETURN FALSE;
    END;
    Data := PI^.Data;
    RETURN TRUE;  
  END CIntegerMap.Get;

  PUBLIC PROCEDURE CIntegerMap.ElementAt( Index : CARDINAL; OUT Key : INTEGER; OUT Data : PTR ) : BOOLEAN;
  VAR
    PI : TPIntegerItem;
  BEGIN
    PI := TPIntegerItem( SUPER[ Index ] );
    IF PI = NIL THEN
      RETURN FALSE;
    ELSE
      Key := PI^.Key;
      Data := PI^.Data;
    END;
    RETURN TRUE;
  END CIntegerMap.ElementAt;

END CIntegerMap;

//===========================================================================

TYPE
  TPCardinalItem = POINTER TO CCardinalItem;

CLASS CCardinalItem( avltree.CAVLTreeElem );
  PUBLIC VAR
    Key  : CARDINAL;
    Data : PTR;

  PUBLIC VIRTUAL PROCEDURE Compare( i : CARDINAL; pelem : avltree.TPAVLTreeKey ) : TRISTATE;

  // OPERATOR NEW() : ADDRESS;
  // OPERATOR DISPOSE( a : ADDRESS );
END CCardinalItem;

//---------------------------------------------------------------------------

CLASS IMPLEMENTATION CCardinalItem;

  PUBLIC VIRTUAL PROCEDURE Compare( i : CARDINAL; pelem : avltree.TPAVLTreeKey ) : TRISTATE;
  BEGIN
    IF Key < TPCardinalItem( pelem )^.Key THEN
      RETURN -1;
    ELSIF Key > TPCardinalItem( pelem )^.Key THEN
      RETURN 1;
    ELSE
      RETURN 0;
    END;
  END Compare;

  // OPERATOR CCardinalItem.NEW() : ADDRESS;
  // VAR
  //   a : ADDRESS;
  // BEGIN
  //   IF CardinalAllocator.Allocate( OUT a, SIZE( CCardinalItem )) THEN
  //     RETURN a;
  //   ELSE
  //     RETURN NIL;
  //   END;
  // END CCardinalItem.NEW;
  
  // OPERATOR CCardinalItem.DISPOSE( a : ADDRESS );
  // BEGIN
  //   CardinalAllocator.Deallocate( REF a );
  // END CCardinalItem.DISPOSE;

BEGIN
  Key := -1;
  Data := NIL;
END CCardinalItem;

//---------------------------------------------------------------------------

CLASS IMPLEMENTATION CCardinalMap;

  PUBLIC READONLY PROPERTY CCardinalMap.Current GET : CARDINAL;
  BEGIN
    IF _Current = -1 THEN
      RETURN 0;
    ELSE
      RETURN TPCardinalItem( _Current )^.Key;
    END;
  END CCardinalMap.Current;

//---------------------------------------------------------------------------

  PUBLIC READONLY PROPERTY CCardinalMap.CurrentData GET : PTR;
  BEGIN
    IF _Current = -1 THEN
      RETURN NIL;
    ELSE
      RETURN TPCardinalItem( _Current )^.Data;
    END;
  END CCardinalMap.CurrentData;

//---------------------------------------------------------------------------

  PUBLIC PROPERTY CCardinalMap.CurrentData SET( Data : PTR );
  BEGIN
    IF _Current = -1 THEN
      RETURN;
    ELSE
      TPCardinalItem( _Current )^.Data := Data;
    END;
  END CCardinalMap.CurrentData;

//---------------------------------------------------------------------------

  PUBLIC READONLY INDEX CCardinalMap GET ( Index : CARDINAL ) : PTR;
  VAR
    PI : TPCardinalItem;
  BEGIN
    PI := TPCardinalItem( SUPER[ Index ] );
    IF PI = NIL THEN
      RETURN NIL;
    ELSE
      RETURN PI^.Data;
    END;
  END CCardinalMap;

  PUBLIC PROCEDURE CCardinalMap.Add( Key : CARDINAL; Data : PTR );
  VAR
    PI : TPCardinalItem;
  BEGIN
    NEW( PI );
    PI^.Key := Key;
    PI^.Data := Data;
    Insert( PI );
  END CCardinalMap.Add;
  
  PUBLIC PROCEDURE CCardinalMap.Remove( Key : CARDINAL );
  VAR
    I : CCardinalItem;
  BEGIN
    I.Key := Key;
    Delete( ADR( I ));
  END CCardinalMap.Remove;

  PUBLIC PROCEDURE CCardinalMap.Contains( Key : CARDINAL ) : BOOLEAN;
  VAR
    I : CCardinalItem;
  BEGIN
    I.Key := Key;
    RETURN SUPER.Contains( ADR( I ));
  END CCardinalMap.Contains;

  PUBLIC PROCEDURE CCardinalMap.Get( Key : CARDINAL; OUT Data : PTR ) : BOOLEAN; // similar as []
  VAR
    I : CCardinalItem;
    PI : TPCardinalItem;
  BEGIN
    I.Key := Key;
    IF NOT Search( ADR( I ), OUT PI ) THEN
      RETURN FALSE;
    END;
    Data := PI^.Data;
    RETURN TRUE;  
  END CCardinalMap.Get;

  PUBLIC PROCEDURE CCardinalMap.ElementAt( Index : CARDINAL; OUT Key : CARDINAL; OUT Data : PTR ) : BOOLEAN;
  VAR
    PI : TPCardinalItem;
  BEGIN
    PI := TPCardinalItem( SUPER[ Index ] );
    IF PI = NIL THEN
      RETURN FALSE;
    ELSE
      Key := PI^.Key;
      Data := PI^.Data;
    END;
    RETURN TRUE;
  END CCardinalMap.ElementAt;

END CCardinalMap;

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

//---------------------------------------------------------------------------

CLASS IMPLEMENTATION CPtrMap;

  PUBLIC READONLY PROPERTY CPtrMap.Current GET : PTR;
  BEGIN
    IF _Current = -1 THEN
      RETURN 0;
    ELSE
      RETURN TPPtrItem( _Current )^.Key;
    END;
  END CPtrMap.Current;

//---------------------------------------------------------------------------

  PUBLIC READONLY PROPERTY CPtrMap.CurrentData GET : PTR;
  BEGIN
    IF _Current = -1 THEN
      RETURN NIL;
    ELSE
      RETURN TPPtrItem( _Current )^.Data;
    END;
  END CPtrMap.CurrentData;

//---------------------------------------------------------------------------

  PUBLIC PROPERTY CPtrMap.CurrentData SET( Data : PTR );
  BEGIN
    IF _Current = -1 THEN
      RETURN;
    ELSE
      TPPtrItem( _Current )^.Data := Data;
    END;
  END CPtrMap.CurrentData;

//---------------------------------------------------------------------------

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
  TPQuadwordItem = POINTER TO CQuadwordItem;

CLASS CQuadwordItem( avltree.CAVLTreeElem );
  PUBLIC VAR
    Key  : QUADWORD;
    Data : PTR;

  PUBLIC VIRTUAL PROCEDURE Compare( i : CARDINAL; pelem : avltree.TPAVLTreeKey ) : TRISTATE;

  // OPERATOR NEW() : ADDRESS;
  // OPERATOR DISPOSE( a : ADDRESS );
END CQuadwordItem;

//---------------------------------------------------------------------------

CLASS IMPLEMENTATION CQuadwordItem;

  PUBLIC VIRTUAL PROCEDURE Compare( i : CARDINAL; pelem : avltree.TPAVLTreeKey ) : TRISTATE;
  BEGIN
    IF Key < TPQuadwordItem( pelem )^.Key THEN
      RETURN -1;
    ELSIF Key > TPQuadwordItem( pelem )^.Key THEN
      RETURN 1;
    ELSE
      RETURN 0;
    END;
  END Compare;

  // OPERATOR CQuadwordItem.NEW() : ADDRESS;
  // VAR
  //   a : ADDRESS;
  // BEGIN
  //   IF QuadwordAllocator.Allocate( OUT a, SIZE( CQuadwordItem )) THEN
  //     RETURN a;
  //   ELSE
  //     RETURN NIL;
  //   END;
  // END CQuadwordItem.NEW;
  
  // OPERATOR CQuadwordItem.DISPOSE( a : ADDRESS );
  // BEGIN
  //   QuadwordAllocator.Deallocate( REF a );
  // END CQuadwordItem.DISPOSE;

BEGIN
  Key := -1;
  Data := NIL;
END CQuadwordItem;

//---------------------------------------------------------------------------

CLASS IMPLEMENTATION CQuadwordMap;

  PUBLIC READONLY PROPERTY CQuadwordMap.Current GET : QUADWORD;
  BEGIN
    IF _Current = -1 THEN
      RETURN 0;
    ELSE
      RETURN TPQuadwordItem( _Current )^.Key;
    END;
  END CQuadwordMap.Current;

//---------------------------------------------------------------------------

  PUBLIC READONLY PROPERTY CQuadwordMap.CurrentData GET : PTR;
  BEGIN
    IF _Current = -1 THEN
      RETURN NIL;
    ELSE
      RETURN TPQuadwordItem( _Current )^.Data;
    END;
  END CQuadwordMap.CurrentData;

//---------------------------------------------------------------------------

  PUBLIC PROPERTY CQuadwordMap.CurrentData SET( Data : PTR );
  BEGIN
    IF _Current = -1 THEN
      RETURN;
    ELSE
      TPQuadwordItem( _Current )^.Data := Data;
    END;
  END CQuadwordMap.CurrentData;

//---------------------------------------------------------------------------

  PUBLIC READONLY INDEX CQuadwordMap GET( Index : CARDINAL ) : PTR;
  VAR
    PI : TPQuadwordItem;
  BEGIN
    PI := TPQuadwordItem( SUPER[ Index ] );
    IF PI = NIL THEN
      RETURN NIL;
    ELSE
      RETURN PI^.Data;
    END;
  END CQuadwordMap;

  PUBLIC PROCEDURE CQuadwordMap.Add( Key : QUADWORD; Data : PTR );
  VAR
    PI : TPQuadwordItem;
  BEGIN
    NEW( PI );
    PI^.Key := Key;
    PI^.Data := Data;
    Insert( PI );
  END CQuadwordMap.Add;
  
  PUBLIC PROCEDURE CQuadwordMap.Remove( Key : QUADWORD );
  VAR
    I : CQuadwordItem;
  BEGIN
    I.Key := Key;
    Delete( ADR( I ));
  END CQuadwordMap.Remove;

  PUBLIC PROCEDURE CQuadwordMap.Contains( Key : QUADWORD ) : BOOLEAN;
  VAR
    I : CQuadwordItem;
  BEGIN
    I.Key := Key;
    RETURN SUPER.Contains( ADR( I ));
  END CQuadwordMap.Contains;

  PUBLIC PROCEDURE CQuadwordMap.Get( Key : QUADWORD; OUT Data : PTR ) : BOOLEAN; // similar as []
  VAR
    I : CQuadwordItem;
    PI : TPQuadwordItem;
  BEGIN
    I.Key := Key;
    IF NOT Search( ADR( I ), OUT PI ) THEN
      RETURN FALSE;
    END;
    Data := PI^.Data;
    RETURN TRUE;  
  END CQuadwordMap.Get;

  PUBLIC PROCEDURE CQuadwordMap.ElementAt( Index : CARDINAL; OUT Key : QUADWORD; OUT Data : PTR ) : BOOLEAN;
  VAR
    PI : TPQuadwordItem;
  BEGIN
    PI := TPQuadwordItem( SUPER[ Index ] );
    IF PI = NIL THEN
      RETURN FALSE;
    ELSE
      Key := PI^.Key;
      Data := PI^.Data;
    END;
    RETURN TRUE;
  END CQuadwordMap.ElementAt;

END CQuadwordMap;

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

  PUBLIC PROCEDURE CStringMap.Add( CONST Key : CString; Data : PTR );
  VAR
    PI : TPStringItem;
  BEGIN
    NEW( PI );
    PI^.Key := Key;
    PI^.Data := Data;
    Insert( PI );
  END CStringMap.Add;
  
  PUBLIC PROCEDURE CStringMap.Remove( CONST Key : CString );
  VAR
    I : CStringItem;
  BEGIN
    I.Key := Key;
    Delete( ADR( I ));
  END CStringMap.Remove;

  PUBLIC PROCEDURE CStringMap.Contains( CONST Key : CString ) : BOOLEAN;
  VAR
    I : CStringItem;
  BEGIN
    I.Key := Key;
    RETURN SUPER.Contains( ADR( I ));
  END CStringMap.Contains;

  PUBLIC PROCEDURE CStringMap.Get( CONST Key : CString; OUT Data : PTR ) : BOOLEAN; // similar as []
  VAR
    I : CStringItem;
    PI : TPStringItem;
  BEGIN
    I.Key := Key;
    IF NOT Search( ADR( I ), OUT PI ) THEN
      RETURN FALSE;
    END;
    Data := PI^.Data;
    RETURN TRUE;  
  END CStringMap.Get;

  PUBLIC PROCEDURE CStringMap.ElementAt( Index : CARDINAL; OUT Key : CString; OUT Data : PTR ) : BOOLEAN;
  VAR
    PI : TPStringItem;
  BEGIN
    PI := TPStringItem( SUPER[ Index ] );
    IF PI = NIL THEN
      RETURN FALSE;
    ELSE
      Key := PI^.Key;
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

// INITIALLY __I();
// BEGIN
  // IntegerAllocator.Init( SIZE( CIntegerItem ), 0 );
  // CardinalAllocator.Init( SIZE( CCardinalItem ), 0 );
  // PtrAllocator.Init( SIZE( CPtrItem ), 0 );
// END __I;

END maps.