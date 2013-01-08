IMPLEMENTATION MODULE lists;

FROM Storage IMPORT
   ALLOCATE, DEALLOCATE;
  
FROM Debug IMPORT
   AssertionW;

IMPORT
   StorageO,
   StringsO;

(*===========================================================================*)

CLASS IMPLEMENTATION CDataOwnershipControlList;

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
END CDataOwnershipControlList;

(*===========================================================================*)
// common ancestor

ABSTRACT CLASS CDataItem( list.CListElem );

   // CDisposable
   PUBLIC VIRTUAL PROCEDURE Dispose();

   // SELF   
   LOCAL VAR
      Data : PTR := NIL;
      OfDataOwnershipControlList : POINTER TO CDataOwnershipControlList := NIL;

END CDataItem;

(*---------------------------------------------------------------------------*)

CLASS IMPLEMENTATION CDataItem;

(*---------------------------------------------------------------------------*)

   PUBLIC VIRTUAL PROCEDURE Dispose();
   BEGIN
      IF ( OfDataOwnershipControlList <> NIL ) AND ( Data <> NIL ) AND ( OfDataOwnershipControlList^.DataOwnership ) THEN
         IF baseobject.PBASE( Data )^ INHERITS baseobject.CRefcounted THEN // dangerous, m2cpp has to define OBJECT
            baseobject.TPRefcounted( Data )^.Release();
         ELSIF baseobject.PBASE( Data )^ INHERITS baseobject.CDisposable THEN 
            baseobject.TPDisposable( Data )^.Dispose();
            DISPOSE( baseobject.TPDisposable( Data ));
         ELSIF baseobject.PBASE( Data )^ INHERITS baseobject.BASE THEN
            DISPOSE( baseobject.PBASE( Data ));
         ELSE
            ASSERTLOG( FALSE, L"Unable to deallocate list item -- unknown class" );
         END;
         Data := NIL;
      END;
      SUPER.Dispose();
   END Dispose;

(*---------------------------------------------------------------------------*)

BEGIN FINALLY
   Dispose();
END CDataItem;

(*==========================================================================*)

TYPE
   TPIntegerItem = POINTER TO CIntegerItem;

CLASS CIntegerItem( CDataItem );

   LOCAL VAR
      Value : INTEGER := 0;

END CIntegerItem;

(*---------------------------------------------------------------------------*)

CLASS IMPLEMENTATION CIntegerItem;
BEGIN
END CIntegerItem;

(*===========================================================================*)

CLASS IMPLEMENTATION CIntegerList;

(*---------------------------------------------------------------------------*)

   PUBLIC PROCEDURE CIntegerList.Contains( Value : INTEGER ): BOOLEAN;
   VAR
      i : INTEGER;
      PE : TPIntegerItem;
   BEGIN
      RETURN Lookup( Value, OUT PE, OUT i );
   END CIntegerList.Contains;

(*---------------------------------------------------------------------------*)

   PUBLIC PROCEDURE CIntegerList.Add( Value : INTEGER; Data : PTR );
   VAR
      PE : TPIntegerItem;
   BEGIN
      NEW( PE );
      PE^.OfDataOwnershipControlList := ADR( SELF );
      PE^.Value := Value;
      PE^.Data := Data;
      SUPER.Add( PE );
   END CIntegerList.Add;

(*---------------------------------------------------------------------------*)

   PUBLIC PROCEDURE CIntegerList.Get( Value : INTEGER; OUT Data : PTR ): BOOLEAN;
   VAR
      i : INTEGER;
      PE : TPIntegerItem;
   BEGIN
      IF Lookup( Value, OUT PE, OUT i ) THEN
         Data := PE^.Data;
         RETURN TRUE;
      ELSE
         RETURN FALSE;
      END;
  END CIntegerList.Get;

(*---------------------------------------------------------------------------*)

   PUBLIC PROCEDURE CIntegerList.Set( Value : INTEGER; Data : PTR ): BOOLEAN;
   VAR
      i : INTEGER;
      PE : TPIntegerItem;
   BEGIN
      IF Lookup( Value, OUT PE, OUT i ) THEN
         PE^.Data := Data;
         RETURN TRUE;
      ELSE
         RETURN FALSE;
      END;
  END CIntegerList.Set;

(*---------------------------------------------------------------------------*)

   PUBLIC PROCEDURE CIntegerList.Remove( Value : INTEGER ); // removes all occurences
   VAR
      PE, PN : TPIntegerItem;
      b : BOOLEAN;
   BEGIN
      b := SUPER.colGetFirst( OUT PE );
      WHILE b DO
         b := SUPER.colNextOf( PE, OUT PN );
         IF PE^.Value = Value THEN 
            Delete( PE );
         END;
         PE := PN;
      END; // WHILE
   END CIntegerList.Remove;

(*---------------------------------------------------------------------------*)

   PUBLIC PROCEDURE ElementAt( Index : INTEGER; OUT Value : INTEGER; OUT Data : PTR ) : BOOLEAN; // similar as []
   VAR
      PE : TPIntegerItem;
   BEGIN
      IF SUPER.ElementAt( Index, OUT PE ) THEN
         Value := PE^.Value;
         Data := PE^.Data;
         RETURN TRUE;
      ELSE
         RETURN FALSE;
      END;
   END ElementAt;

(*---------------------------------------------------------------------------*)

   PUBLIC PROCEDURE CIntegerList.InsertFirst( Value : INTEGER; Data : PTR );
   VAR
      PE : TPIntegerItem;
   BEGIN
      NEW( PE );
      PE^.Value := Value;
      PE^.Data := Data;
      SUPER.InsertFirst( PE );
   END CIntegerList.InsertFirst;

(*---------------------------------------------------------------------------*)

   PUBLIC PROCEDURE CIntegerList.InsertBefore( Before, Value : INTEGER; Data : PTR );
   VAR
      i : INTEGER;
      PB, PE : TPIntegerItem;
   BEGIN
      NEW( PE );
      PE^.Value := Value;
      PE^.Data := Data;
      IF Lookup( Before, OUT PB, OUT i ) THEN
         SUPER.InsertBefore( PB, PE );
      ELSE
         SUPER.InsertFirst( PE );
      END;
   END CIntegerList.InsertBefore;

(*---------------------------------------------------------------------------*)

   PUBLIC PROCEDURE CIntegerList.GetIterator( Direction : collection.TDirection ) : TPIntegerListIterator;
   VAR
      iterator : TPIntegerListIterator;
   BEGIN
      iterator := NEW( CIntegerListIterator );
      iterator^.Init( SELF, Direction );
      RETURN iterator;
   END CIntegerList.GetIterator;

(*---------------------------------------------------------------------------*)

   PUBLIC PROCEDURE Enqueue( Value : INTEGER; Data : PTR );
   BEGIN
      Add( Value, Data );
   END Enqueue;

(*---------------------------------------------------------------------------*)

   PUBLIC PROCEDURE Dequeue( OUT Value : INTEGER; OUT Data : PTR ) : BOOLEAN; 
   VAR
      PE : TPIntegerItem;
   BEGIN
      IF colGetFirst( OUT PE ) THEN
         Value := PE^.Value;
         Data := PE^.Data;
         Delete( PE );
         RETURN TRUE;
      ELSE
         RETURN FALSE;
      END;
   END Dequeue;

(*---------------------------------------------------------------------------*)

   PRIVATE PROCEDURE CIntegerList.Lookup( Value : INTEGER; OUT Item : list.TPListElem; OUT Index : INTEGER ) : BOOLEAN;
   VAR
      i : INTEGER := 0;
      PE : TPIntegerItem;
      b : BOOLEAN;
   BEGIN
      b := colGetFirst( OUT PE );
      WHILE b DO
         IF PE^.Value = Value THEN
            Item := PE;
            Index := i;
            RETURN TRUE;
         END;
         b := colNextOf( PE, OUT PE );
         INC( i );
      END; // WHILE
      RETURN FALSE;
   END CIntegerList.Lookup;

(*---------------------------------------------------------------------------*)

END CIntegerList;

(*===========================================================================*)

CLASS IMPLEMENTATION CIntegerListIterator;

(*---------------------------------------------------------------------------*)

   PUBLIC PROPERTY Value GET : INTEGER;
   BEGIN
      IF Current = NIL THEN
         RETURN 0;
      ELSE
         RETURN TPIntegerItem( Current )^.Value;
      END;
   END Value;

(*---------------------------------------------------------------------------*)

   PUBLIC PROPERTY Data GET : PTR;
   BEGIN
      IF Current = NIL THEN
         RETURN NIL;
      ELSE
         RETURN TPIntegerItem( Current )^.Data;
      END;
   END Data;

(*---------------------------------------------------------------------------*)

   PUBLIC PROPERTY Data SET( Value : PTR );
   BEGIN
      IF Current <> NIL THEN
         TPIntegerItem( Current )^.Data := Value;
      END;
   END Data;

(*---------------------------------------------------------------------------*)

   PUBLIC PROCEDURE Init( CONST OfCollection : CIntegerList; Direction : collection.TDirection );
   BEGIN
      SUPER.Init( OfCollection, Direction );
   END Init;

(*-----------------------------------------------------------------------------*)

END CIntegerListIterator;

(*==========================================================================*)

TYPE
   TPPtrItem = POINTER TO CPtrItem;

CLASS CPtrItem( CDataItem );

   LOCAL VAR
      Value : PTR := NIL;

END CPtrItem;

(*---------------------------------------------------------------------------*)

CLASS IMPLEMENTATION CPtrItem;
BEGIN
END CPtrItem;

(*==========================================================================*)

CLASS IMPLEMENTATION CPtrList;

(*---------------------------------------------------------------------------*)

   PUBLIC PROCEDURE CPtrList.Contains( Value : PTR ): BOOLEAN;
   VAR
      i : INTEGER;
      PE : TPPtrItem;
   BEGIN
      RETURN Lookup( Value, OUT PE, OUT i );
   END CPtrList.Contains;

(*---------------------------------------------------------------------------*)

   PUBLIC PROCEDURE CPtrList.Add( Value : PTR; Data : PTR );
   VAR
      PE : TPPtrItem;
   BEGIN
      NEW( PE );
      PE^.OfDataOwnershipControlList := ADR( SELF );
      PE^.Value := Value;
      PE^.Data := Data;
      SUPER.Add( PE );
   END CPtrList.Add;

(*---------------------------------------------------------------------------*)

   PUBLIC PROCEDURE CPtrList.Get( Value : PTR; OUT Data : PTR ): BOOLEAN;
   VAR
      i : INTEGER;
      PE : TPPtrItem;
   BEGIN
      IF Lookup( Value, OUT PE, OUT i ) THEN
         Data := PE^.Data;
         RETURN TRUE;
      ELSE
         RETURN FALSE;
      END;
   END CPtrList.Get;

(*---------------------------------------------------------------------------*)

   PUBLIC PROCEDURE CPtrList.Set( Value : PTR; Data : PTR ): BOOLEAN;
   VAR
      i : INTEGER;
      PE : TPPtrItem;
   BEGIN
      IF Lookup( Value, OUT PE, OUT i ) THEN
         PE^.Data := Data;
         RETURN TRUE;
      ELSE
         RETURN FALSE;
      END;
   END CPtrList.Set;

(*---------------------------------------------------------------------------*)

   PUBLIC PROCEDURE CPtrList.Remove( Value : PTR ); // removes all occurences
   VAR
      PE, PN : TPPtrItem;
      b : BOOLEAN;
   BEGIN
      b := colGetFirst( OUT PE );
      WHILE b DO
         b := colNextOf( PE, OUT PN );
         IF PE^.Value = Value THEN 
            Delete( PE );
         END;
         PE := PN;
      END; // WHILE
   END CPtrList.Remove;

(*---------------------------------------------------------------------------*)

   PUBLIC PROCEDURE ElementAt( Index : INTEGER; OUT Value : PTR; OUT Data : PTR ) : BOOLEAN; // similar as []
   VAR
      PE : TPPtrItem;
   BEGIN
      IF SUPER.ElementAt( Index, OUT PE ) THEN
         Value := PE^.Value;
         Data := PE^.Data;
         RETURN TRUE;
      ELSE
         RETURN FALSE;
      END;
   END ElementAt;

(*---------------------------------------------------------------------------*)

   PUBLIC PROCEDURE CPtrList.InsertFirst( Value : PTR; Data : PTR );
   VAR
      PE : TPPtrItem;
   BEGIN
      NEW( PE );
      PE^.Value := Value;
      PE^.Data := Data;
      SUPER.InsertFirst( PE );
   END CPtrList.InsertFirst;

(*---------------------------------------------------------------------------*)

   PUBLIC PROCEDURE CPtrList.InsertBefore( Before, Value : PTR; Data : PTR );
   VAR
      i : INTEGER;
      PB, PE : TPPtrItem;
   BEGIN
      NEW( PE );
      PE^.Value := Value;
      PE^.Data := Data;
      IF Lookup( Before, OUT PB, OUT i ) THEN
         SUPER.InsertBefore( PB, PE );
      ELSE
         SUPER.InsertFirst( PE );
      END;
   END CPtrList.InsertBefore;

(*---------------------------------------------------------------------------*)

   PUBLIC PROCEDURE CPtrList.GetIterator( Direction : collection.TDirection ) : TPPtrListIterator;
   VAR
      iterator : TPPtrListIterator;
   BEGIN
      iterator := NEW( CPtrListIterator );
      iterator^.Init( SELF, Direction );
      RETURN iterator;
   END CPtrList.GetIterator;

(*---------------------------------------------------------------------------*)

   PUBLIC PROCEDURE Enqueue( Value : PTR; Data : PTR );
   BEGIN
      Add( Value, Data );
   END Enqueue;

(*---------------------------------------------------------------------------*)

   PUBLIC PROCEDURE Dequeue( OUT Value : PTR; OUT Data : PTR ) : BOOLEAN; 
   VAR
      PE : TPPtrItem;
   BEGIN
      IF colGetFirst( OUT PE ) THEN
         Value := PE^.Value;
         Data := PE^.Data;
         Delete( PE );
         RETURN TRUE;
      ELSE
         RETURN FALSE;
      END;
   END Dequeue;

(*---------------------------------------------------------------------------*)

   PRIVATE PROCEDURE CPtrList.Lookup( Value : PTR; OUT Item : list.TPListElem; OUT Index : INTEGER ) : BOOLEAN;
   VAR
      i : INTEGER := 0;
      PE : TPPtrItem;
      b : BOOLEAN;
   BEGIN
      b := colGetFirst( OUT PE );
      WHILE b DO
         IF PE^.Value = Value THEN
            Item := PE;
            Index := i;
            RETURN TRUE;
         END;
         b := colNextOf( PE, OUT PE );
         INC( i );
      END; // WHILE
      RETURN FALSE;
   END CPtrList.Lookup;

(*---------------------------------------------------------------------------*)

END CPtrList;

(*==========================================================================*)

CLASS IMPLEMENTATION CPtrListIterator;

(*---------------------------------------------------------------------------*)

   PUBLIC PROPERTY Value GET : PTR;
   BEGIN
      IF Current = NIL THEN
         RETURN NIL;
      ELSE
         RETURN TPPtrItem( Current )^.Value;
      END;
   END Value;

(*---------------------------------------------------------------------------*)

   PUBLIC PROPERTY Data GET : PTR;
   BEGIN
      IF Current = NIL THEN
         RETURN NIL;
      ELSE
         RETURN TPPtrItem( Current )^.Data;
      END;
   END Data;

(*---------------------------------------------------------------------------*)

   PUBLIC PROPERTY Data SET( Value : PTR );
   BEGIN
      IF Current <> NIL THEN
         TPPtrItem( Current )^.Data := Value;
      END;
   END Data;

(*---------------------------------------------------------------------------*)

   PUBLIC PROCEDURE Init( CONST OfCollection : CPtrList; Direction : collection.TDirection );
   BEGIN
      SUPER.Init( OfCollection, Direction );
   END Init;

(*-----------------------------------------------------------------------------*)

END CPtrListIterator;

(*==========================================================================*)

TYPE
   TPStringItem = POINTER TO CStringItem;

CLASS CStringItem( CDataItem );
      
   LOCAL VAR
      Value : StringsO.CString;

END CStringItem;

(*---------------------------------------------------------------------------*)

CLASS IMPLEMENTATION CStringItem;
BEGIN
END CStringItem;

(*==========================================================================*)

CLASS IMPLEMENTATION CStringList;

(*---------------------------------------------------------------------------*)

   PUBLIC PROCEDURE CStringList.Add( CONST Value : IString; Data : PTR );
   VAR
      PE : TPStringItem;
   BEGIN
      NEW( PE );
      PE^.OfDataOwnershipControlList := ADR( SELF );
      PE^.Value.Assign( Value );
      PE^.Data := Data;
      SUPER.Add( PE );
   END CStringList.Add;

(*---------------------------------------------------------------------------*)

   PUBLIC PROCEDURE CStringList.Contains( CONST Value : IString ): BOOLEAN;
   VAR
      i : INTEGER;
      PE : TPStringItem;
   BEGIN
      RETURN Lookup( Value, OUT PE, OUT i );
   END CStringList.Contains;

(*---------------------------------------------------------------------------*)

   PUBLIC PROCEDURE CStringList.Get( CONST Value : IString; OUT Data : PTR ): BOOLEAN;
   VAR
      i : INTEGER;
      PE : TPStringItem;
   BEGIN
      IF Lookup( Value, OUT PE, OUT i ) THEN
         Data := PE^.Data;
         RETURN TRUE;
      ELSE
         RETURN FALSE;
      END;
   END CStringList.Get;

(*---------------------------------------------------------------------------*)

   PUBLIC PROCEDURE CStringList.Set( CONST Value : IString; Data : PTR ): BOOLEAN;
   VAR
      i : INTEGER;
      PE : TPStringItem;
   BEGIN
      IF Lookup( Value, OUT PE, OUT i ) THEN
         PE^.Data := Data;
         RETURN TRUE;
      ELSE
         RETURN FALSE;
      END;
   END CStringList.Set;

(*---------------------------------------------------------------------------*)

   PUBLIC PROCEDURE CStringList.Remove( CONST Value : IString ); // removes all occurences
   VAR
      PE, PN : TPStringItem;
      b : BOOLEAN;
   BEGIN
      b := colGetFirst( OUT PE );
      WHILE b DO
         b := colNextOf( PE, OUT PN );
         IF PE^.Value = Value THEN 
            Delete( PE );
         END;
         PE := PN;
      END; // WHILE
   END CStringList.Remove;

(*---------------------------------------------------------------------------*)

   PUBLIC PROCEDURE ElementAt( Index : INTEGER; OUT Value : IString; OUT Data : PTR ) : BOOLEAN; // similar as []
   VAR
      PE : TPStringItem;
   BEGIN
      IF SUPER.ElementAt( Index, OUT PE ) THEN
         Value.Assign( PE^.Value );
         Data := PE^.Data;
         RETURN TRUE;
      ELSE
         RETURN FALSE;
      END;
   END ElementAt;

(*---------------------------------------------------------------------------*)

   PUBLIC PROCEDURE CStringList.InsertFirst( CONST Value : IString; Data : PTR );
   VAR
      PE : TPStringItem;
   BEGIN
      NEW( PE );
      PE^.Value.Assign( Value );
      PE^.Data := Data;
      SUPER.InsertFirst( PE );
   END CStringList.InsertFirst;

(*---------------------------------------------------------------------------*)

   PUBLIC PROCEDURE CStringList.InsertBefore( CONST Before, Value : IString; Data : PTR );
   VAR
      i : INTEGER;
      PB, PE : TPStringItem;
   BEGIN
      NEW( PE );
      PE^.Value.Assign( Value );
      PE^.Data := Data;
      IF Lookup( Before, OUT PB, OUT i ) THEN
         SUPER.InsertBefore( PB, PE );
      ELSE
         SUPER.InsertFirst( PE );
      END;
   END CStringList.InsertBefore;

(*---------------------------------------------------------------------------*)

   PUBLIC PROCEDURE CStringList.GetIterator( Direction : collection.TDirection ) : TPStringListIterator;
   VAR
      iterator : TPStringListIterator;
   BEGIN
      iterator := NEW( CStringListIterator );
      iterator^.Init( SELF, Direction );
      RETURN iterator;
   END CStringList.GetIterator;

(*---------------------------------------------------------------------------*)

   PUBLIC PROCEDURE Enqueue( CONST Value : IString; Data : PTR );
   BEGIN
      Add( Value, Data );
   END Enqueue;

(*---------------------------------------------------------------------------*)

   PUBLIC PROCEDURE Dequeue( OUT Value : IString; OUT Data : PTR ) : BOOLEAN; 
   VAR
      PE : TPStringItem;
   BEGIN
      IF colGetFirst( OUT PE ) THEN
         Value.Assign( PE^.Value );
         Data := PE^.Data;
         Delete( PE );
         RETURN TRUE;
      ELSE
         RETURN FALSE;
      END;
   END Dequeue;

(*---------------------------------------------------------------------------*)

  PRIVATE PROCEDURE CStringList.Lookup( CONST Value : IString; OUT Item : list.TPListElem; OUT Index : INTEGER ) : BOOLEAN;
  VAR
    i : INTEGER := 0;
    PE : TPStringItem;
    b : BOOLEAN;
  BEGIN
    b := colGetFirst( OUT PE );
    WHILE b DO
      IF PE^.Value = Value THEN
        Item := PE;
        Index := i;
        RETURN TRUE;
      END;
      b := colNextOf( PE, OUT PE );
      INC( i );
    END; // WHILE
    RETURN FALSE;
  END CStringList.Lookup;

(*---------------------------------------------------------------------------*)

END CStringList;

(*==========================================================================*)

CLASS IMPLEMENTATION CStringListIterator;

(*---------------------------------------------------------------------------*)

   PUBLIC PROPERTY Value GET : TPString;
   BEGIN
      IF Current = NIL THEN
         RETURN NIL;
      ELSE
         RETURN ADR( TPStringItem( Current )^.Value );
      END;
   END Value;

(*---------------------------------------------------------------------------*)

   PUBLIC PROPERTY Data GET : PTR;
   BEGIN
      IF Current = NIL THEN
         RETURN NIL;
      ELSE
         RETURN TPStringItem( Current )^.Data;
      END;
   END Data;

(*---------------------------------------------------------------------------*)

   PUBLIC PROPERTY Data SET( Value : PTR );
   BEGIN
      IF Current <> NIL THEN
         TPStringItem( Current )^.Data := Value;
      END;
   END Data;

(*---------------------------------------------------------------------------*)

   PUBLIC PROCEDURE Init( CONST OfCollection : CStringList; Direction : collection.TDirection );
   BEGIN
      SUPER.Init( OfCollection, Direction );
   END Init;

(*-----------------------------------------------------------------------------*)

END CStringListIterator;

(*===========================================================================*)

TYPE
   TPStringStringItem = POINTER TO CStringStringItem;

CLASS CStringStringItem( list.CListElem );

   LOCAL VAR
      Value : StringsO.CString;
      Data  : StringsO.CString;

END CStringStringItem;

(*---------------------------------------------------------------------------*)

CLASS IMPLEMENTATION CStringStringItem;
END CStringStringItem;

(*===========================================================================*)

CLASS IMPLEMENTATION CStringStringList;

(*---------------------------------------------------------------------------*)

   PUBLIC PROCEDURE CStringStringList.Add( CONST Value : IString; CONST Data : IString );
   VAR
      PE : TPStringStringItem;
   BEGIN
      NEW( PE );
      PE^.Value.Assign( Value );
      PE^.Data.Assign( Data );
      SUPER.Add( PE );
   END CStringStringList.Add;

(*---------------------------------------------------------------------------*)

   PUBLIC PROCEDURE CStringStringList.Contains( CONST Value : IString ): BOOLEAN;
   VAR
      i : INTEGER;
      PE : TPStringStringItem;
   BEGIN
      RETURN Lookup( Value, OUT PE, OUT i );
   END CStringStringList.Contains;

(*---------------------------------------------------------------------------*)

   PUBLIC PROCEDURE CStringStringList.Get( CONST Value : IString; OUT Data : IString ): BOOLEAN;
   VAR
      i : INTEGER;
      PE : TPStringStringItem;
   BEGIN
      IF Lookup( Value, OUT PE, OUT i ) THEN
         Data.Assign( PE^.Data );
         RETURN TRUE;
      ELSE
         RETURN FALSE;
      END;
   END CStringStringList.Get;

(*---------------------------------------------------------------------------*)

   PUBLIC PROCEDURE CStringStringList.Set( CONST Value : IString; CONST Data : IString ): BOOLEAN;
   VAR
      i : INTEGER;
      PE : TPStringStringItem;
   BEGIN
      IF Lookup( Value, OUT PE, OUT i ) THEN
         PE^.Data.Assign( Data );
         RETURN TRUE;
      ELSE
         RETURN FALSE;
      END;
   END CStringStringList.Set;

(*---------------------------------------------------------------------------*)

   PUBLIC PROCEDURE CStringStringList.Remove( CONST Value : IString ); // removes all occurences
   VAR
      PE, PN : TPStringStringItem;
      b : BOOLEAN;
   BEGIN
      b := colGetFirst( OUT PE );
      WHILE b DO
         b := colNextOf( PE, OUT PN );
         IF PE^.Value.Equals( Value ) THEN 
            Delete( PE );
         END;
         PE := PN;
      END; // WHILE
   END CStringStringList.Remove;

(*---------------------------------------------------------------------------*)

   PUBLIC PROCEDURE ElementAt( Index : INTEGER; OUT Value : IString; OUT Data : IString ) : BOOLEAN; // similar as []
   VAR
      PE : TPStringStringItem;
   BEGIN
      IF SUPER.ElementAt( Index, OUT PE ) THEN
         Value.Assign( TPStringStringItem( PE )^.Value );
         Data.Assign( TPStringStringItem( PE )^.Data );
         RETURN TRUE;
      ELSE
         RETURN FALSE;
      END;
   END ElementAt;

(*---------------------------------------------------------------------------*)

   PUBLIC PROCEDURE CStringStringList.InsertFirst( CONST Value : IString; CONST Data : IString );
   VAR
      PE : TPStringStringItem;
   BEGIN
      NEW( PE );
      PE^.Value.Assign( Value );
      PE^.Data.Assign( Data );
      SUPER.InsertFirst( PE );
   END CStringStringList.InsertFirst;

(*---------------------------------------------------------------------------*)

   PUBLIC PROCEDURE CStringStringList.InsertBefore( CONST Before, Value : IString; CONST Data : IString );
   VAR
      i : INTEGER;
      PB, PE : TPStringStringItem;
   BEGIN
      NEW( PE );
      PE^.Value.Assign( Value );
      PE^.Data.Assign( Data );
      IF Lookup( Before, OUT PB, OUT i ) THEN
         SUPER.InsertBefore( PB, PE );
      ELSE
         SUPER.InsertFirst( PE );
      END;
   END CStringStringList.InsertBefore;

(*---------------------------------------------------------------------------*)

   PUBLIC PROCEDURE CStringStringList.GetIterator( Direction : collection.TDirection ) : TPStringStringListIterator;
   VAR
      iterator : TPStringStringListIterator;
   BEGIN
      iterator := NEW( CStringStringListIterator );
      iterator^.Init( SELF, Direction );
      RETURN iterator;
   END CStringStringList.GetIterator;

(*---------------------------------------------------------------------------*)

   PUBLIC PROCEDURE Enqueue( CONST Value : IString; CONST Data : IString );
   BEGIN
      Add( Value, Data );
   END Enqueue;

(*---------------------------------------------------------------------------*)

   PUBLIC PROCEDURE Dequeue( OUT Value : IString; OUT Data : IString ) : BOOLEAN; 
   VAR
      PE : TPStringStringItem;
   BEGIN
      IF colGetFirst( OUT PE ) THEN
         Value.Assign( PE^.Value );
         Data.Assign( PE^.Data );
         Delete( PE );
         RETURN TRUE;
      ELSE
         RETURN FALSE;
      END;
   END Dequeue;

(*---------------------------------------------------------------------------*)

   PRIVATE PROCEDURE CStringStringList.Lookup( CONST Value : IString; OUT Item : list.TPListElem; OUT Index : INTEGER ) : BOOLEAN;
   VAR
      i : INTEGER := 0;
      PE : TPStringStringItem;
      b : BOOLEAN;
   BEGIN
      b := colGetFirst( OUT PE );
      WHILE b DO
         IF PE^.Value = Value THEN
            Item := PE;
            Index := i;
            RETURN TRUE;
         END;
         b := colNextOf( PE, OUT PE );
         INC( i );
      END; // WHILE
      RETURN FALSE;
   END CStringStringList.Lookup;

(*---------------------------------------------------------------------------*)

END CStringStringList;

(*==========================================================================*)

CLASS IMPLEMENTATION CStringStringListIterator;

(*---------------------------------------------------------------------------*)

   PUBLIC PROPERTY Value GET : TPString;
   BEGIN
      IF Current = NIL THEN
         RETURN NIL;
      ELSE
         RETURN ADR( TPStringStringItem( Current )^.Value );
      END;
   END Value;

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

   PUBLIC PROCEDURE Init( CONST OfCollection : CStringStringList; Direction : collection.TDirection );
   BEGIN
      SUPER.Init( OfCollection, Direction );
   END Init;

(*-----------------------------------------------------------------------------*)

END CStringStringListIterator;

(*===========================================================================*)

TYPE
  TPBufferItem = POINTER TO ABufferItem;
  
ABSTRACT CLASS ABufferItem( CDataItem );

   LOCAL ABSTRACT READONLY PROPERTY
      Value : POINTER TO AMemoryBuffer;

END ABufferItem;

(*---------------------------------------------------------------------------*)

CLASS IMPLEMENTATION ABufferItem;
END ABufferItem;

(*==========================================================================*)

CLASS CDynamicItem( ABufferItem );

   PRIVATE VAR
      _Value : StorageO.CMemoryBuffer;

   LOCAL VIRTUAL READONLY PROPERTY
      Value : POINTER TO AMemoryBuffer;

END CDynamicItem;

(*---------------------------------------------------------------------------*)

CLASS IMPLEMENTATION CDynamicItem;

   LOCAL PROPERTY Value GET : POINTER TO AMemoryBuffer;
   BEGIN
      RETURN ADR( _Value );
   END Value;

END CDynamicItem;

(*==========================================================================*)

CLASS CSlotItem32( ABufferItem );

   PRIVATE VAR
      _Value : StorageO.CMemorySlot32;

   LOCAL VIRTUAL READONLY PROPERTY
      Value : POINTER TO AMemoryBuffer;

END CSlotItem32;

(*---------------------------------------------------------------------------*)

CLASS IMPLEMENTATION CSlotItem32;

   LOCAL PROPERTY Value GET : POINTER TO AMemoryBuffer;
   BEGIN
      RETURN ADR( _Value );
   END Value;

END CSlotItem32;

(*==========================================================================*)

CLASS CSlotItem64( ABufferItem );

   PRIVATE VAR
      _Value : StorageO.CMemorySlot64;

   LOCAL VIRTUAL READONLY PROPERTY
      Value : POINTER TO AMemoryBuffer;

END CSlotItem64;

(*---------------------------------------------------------------------------*)

CLASS IMPLEMENTATION CSlotItem64;

   LOCAL PROPERTY Value GET : POINTER TO AMemoryBuffer;
   BEGIN
      RETURN ADR( _Value );
   END Value;

END CSlotItem64;

(*==========================================================================*)

CLASS CSlotItem256( ABufferItem );

   PRIVATE VAR
      _Value : StorageO.CMemorySlot256;

   LOCAL VIRTUAL READONLY PROPERTY
      Value : POINTER TO AMemoryBuffer;

END CSlotItem256;

(*---------------------------------------------------------------------------*)

CLASS IMPLEMENTATION CSlotItem256;

   LOCAL PROPERTY Value GET : POINTER TO AMemoryBuffer;
   BEGIN
      RETURN ADR( _Value );
   END Value;

END CSlotItem256;

(*==========================================================================*)

CLASS IMPLEMENTATION CBufferList;

(*---------------------------------------------------------------------------*)

   PUBLIC PROCEDURE CBufferList.Add( CONST Value : AMemoryBuffer; Data : PTR );
   VAR
      PE : TPBufferItem;
   BEGIN
      CASE ItemType OF
      | blitDynamic :
         PE := NEW( CDynamicItem );
      | blitSlot32 :
         PE := NEW( CSlotItem32 );
      | blitSlot64 :
         PE := NEW( CSlotItem64 );
      | blitSlot256 :
         PE := NEW( CSlotItem256 );
      END; // CASE
      PE^.OfDataOwnershipControlList := ADR( SELF );
      PE^.Value^.Assign( Value );
      PE^.Data := Data;
      SUPER.Add( PE );
   END CBufferList.Add;

(*---------------------------------------------------------------------------*)

   PUBLIC PROCEDURE CBufferList.Contains( CONST Value : AMemoryBuffer ): BOOLEAN;
   VAR
      i : INTEGER;
      PE : TPBufferItem;
   BEGIN
      RETURN Lookup( Value, OUT PE, OUT i );
   END CBufferList.Contains;

(*---------------------------------------------------------------------------*)

   PUBLIC PROCEDURE CBufferList.Get( CONST Value : AMemoryBuffer; OUT Data : PTR ): BOOLEAN;
   VAR
      i : INTEGER;
      PE : TPBufferItem;
   BEGIN
      IF Lookup( Value, OUT PE, OUT i ) THEN
         Data := PE^.Data;
         RETURN TRUE;
      ELSE
         RETURN FALSE;
      END;
   END CBufferList.Get;

(*---------------------------------------------------------------------------*)

   PUBLIC PROCEDURE CBufferList.Set( CONST Value : AMemoryBuffer; Data : PTR ): BOOLEAN;
   VAR
      i : INTEGER;
      PE : TPBufferItem;
   BEGIN
      IF Lookup( Value, OUT PE, OUT i ) THEN
         PE^.Data := Data;
         RETURN TRUE;
      ELSE
         RETURN FALSE;
      END;
   END CBufferList.Set;

(*---------------------------------------------------------------------------*)

   PUBLIC PROCEDURE CBufferList.Remove( CONST Value : AMemoryBuffer ); // removes all occurences
   VAR
      PE, PN : TPBufferItem;
      b : BOOLEAN;
   BEGIN
      b := colGetFirst( OUT PE );
      WHILE b DO
         b := colNextOf( PE, OUT PN );
         IF PE^.Value^ = Value THEN 
            Delete( PE );
         END;
         PE := PN;
      END; // WHILE
   END CBufferList.Remove;

(*---------------------------------------------------------------------------*)

   PUBLIC PROCEDURE ElementAt( Index : INTEGER; OUT Value : AMemoryBuffer; OUT Data : PTR ) : BOOLEAN; // similar as []
   VAR
      PE : TPBufferItem;
   BEGIN
      IF SUPER.ElementAt( Index, OUT PE ) THEN
         Value.Assign( TPBufferItem( PE )^.Value^ );
         Data := TPBufferItem( PE )^.Data;
         RETURN TRUE;
      ELSE
         RETURN FALSE;
      END;
   END ElementAt;

(*---------------------------------------------------------------------------*)

   PUBLIC PROCEDURE CBufferList.AddOA( CONST Value : ARRAY OF BYTE; Data : PTR );
   VAR
      PE : TPBufferItem;
   BEGIN
      CASE ItemType OF
      | blitDynamic :
         PE := NEW( CDynamicItem );
      | blitSlot32 :
         PE := NEW( CSlotItem32 );
      | blitSlot64 :
         PE := NEW( CSlotItem64 );
      | blitSlot256 :
         PE := NEW( CSlotItem256 );
      END; // CASE
      PE^.Value^.FromOA( Value, TRUE );
      PE^.Data := Data;
      SUPER.Add( PE );
   END CBufferList.AddOA;

(*---------------------------------------------------------------------------*)

   PUBLIC PROCEDURE CBufferList.ContainsOA( CONST Value : ARRAY OF BYTE ): BOOLEAN;
   VAR
      i : INTEGER;
      PE : TPBufferItem;
      S : StorageO.CMemoryBuffer;
   BEGIN
      S.FromOA( Value, TRUE );
      RETURN Lookup( S, OUT PE, OUT i );
   END CBufferList.ContainsOA;

(*---------------------------------------------------------------------------*)

   PUBLIC PROCEDURE CBufferList.GetOA( CONST Value : ARRAY OF BYTE; OUT Data : PTR ): BOOLEAN;
   VAR
      i : INTEGER;
      PE : TPBufferItem;
      S : StorageO.CMemoryBuffer;
   BEGIN
      S.FromOA( Value, TRUE );
      IF Lookup( S, OUT PE, OUT i ) THEN
         Data := PE^.Data;
         RETURN TRUE;
      ELSE
         RETURN FALSE;
      END;
   END CBufferList.GetOA;

(*---------------------------------------------------------------------------*)

   PUBLIC PROCEDURE CBufferList.SetOA( CONST Value : ARRAY OF BYTE; Data : PTR ): BOOLEAN;
   VAR
      i : INTEGER;
      PE : TPBufferItem;
      S : StorageO.CMemoryBuffer;
   BEGIN
      S.FromOA( Value, TRUE );
      IF Lookup( S, OUT PE, OUT i ) THEN
         PE^.Data := Data;
         RETURN TRUE;
      ELSE
         RETURN FALSE;
      END;
   END CBufferList.SetOA;

(*---------------------------------------------------------------------------*)

   PUBLIC PROCEDURE CBufferList.RemoveOA( CONST Value : ARRAY OF BYTE ); // removes all occurences
   VAR
      PE, PN : TPBufferItem;
      S : StorageO.CMemoryBuffer;
      b : BOOLEAN;
   BEGIN
      S.FromOA( Value, TRUE );
      b := colGetFirst( OUT PE );
      WHILE b DO
         b := colNextOf( PE, OUT PN );
         IF PE^.Value^ = S THEN 
            Delete( PE );
         END;
         PE := PN;
      END; // WHILE
   END CBufferList.RemoveOA;

(*---------------------------------------------------------------------------*)

   PUBLIC PROCEDURE CBufferList.InsertFirst( CONST Value : AMemoryBuffer; Data : PTR );
   VAR
      PE : TPBufferItem;
   BEGIN
      CASE ItemType OF
      | blitDynamic :
         PE := NEW( CDynamicItem );
      | blitSlot32 :
         PE := NEW( CSlotItem32 );
      | blitSlot64 :
         PE := NEW( CSlotItem64 );
      | blitSlot256 :
         PE := NEW( CSlotItem256 );
      END; // CASE
      PE^.Value^.Assign( Value );
      PE^.Data := Data;
      SUPER.InsertFirst( PE );
   END CBufferList.InsertFirst;

(*---------------------------------------------------------------------------*)

   PUBLIC PROCEDURE CBufferList.InsertBefore( CONST Before, Value : AMemoryBuffer; Data : PTR );
   VAR
      i : INTEGER;
      PB, PE : TPBufferItem;
   BEGIN
      CASE ItemType OF
      | blitDynamic :
         PE := NEW( CDynamicItem );
      | blitSlot32 :
         PE := NEW( CSlotItem32 );
      | blitSlot64 :
         PE := NEW( CSlotItem64 );
      | blitSlot256 :
         PE := NEW( CSlotItem256 );
      END; // CASE
      PE^.Value^.Assign( Value );
      PE^.Data := Data;
      IF Lookup( Before, OUT PB, OUT i ) THEN
         SUPER.InsertBefore( PB, PE );
      ELSE
         SUPER.InsertFirst( PE );
      END;
   END CBufferList.InsertBefore;

(*---------------------------------------------------------------------------*)

   PUBLIC PROCEDURE CBufferList.GetIterator( Direction : collection.TDirection ) : TPBufferListIterator;
   VAR
      iterator : TPBufferListIterator;
   BEGIN
      iterator := NEW( CBufferListIterator );
      iterator^.Init( SELF, Direction );
      RETURN iterator;
   END CBufferList.GetIterator;

(*---------------------------------------------------------------------------*)

   PUBLIC PROCEDURE Enqueue( CONST Value : AMemoryBuffer; Data : PTR );
   BEGIN
      Add( Value, Data );
   END Enqueue;

(*---------------------------------------------------------------------------*)

   PUBLIC PROCEDURE EnqueueOA( CONST Value : ARRAY OF BYTE; Data : PTR );
   BEGIN
      AddOA( Value, Data );
   END EnqueueOA;

(*---------------------------------------------------------------------------*)

   PUBLIC PROCEDURE Dequeue( OUT Value : AMemoryBuffer; OUT Data : PTR ) : BOOLEAN; 
   VAR
      PE : TPBufferItem;
   BEGIN
      IF colGetFirst( OUT PE ) THEN
         Value.Assign( PE^.Value^ );
         Data := PE^.Data;
         Delete( PE );
         RETURN TRUE;
      ELSE
         RETURN FALSE;
      END;
   END Dequeue;

(*---------------------------------------------------------------------------*)

   PRIVATE PROCEDURE CBufferList.Lookup( CONST Value : AMemoryBuffer; OUT Item : list.TPListElem; OUT Index : INTEGER ) : BOOLEAN;
   VAR
      i : INTEGER := 0;
      PE : TPBufferItem;
      b : BOOLEAN;
   BEGIN
      b := colGetFirst( OUT PE );
      WHILE b DO
         IF PE^.Value^ = Value THEN
            Item := PE;
            Index := i;
            RETURN TRUE;
         END;
         b := colNextOf( PE, OUT PE );
         INC( i );
      END; // WHILE
      RETURN FALSE;
   END CBufferList.Lookup;

(*---------------------------------------------------------------------------*)

BEGIN
END CBufferList;

(*==========================================================================*)

CLASS IMPLEMENTATION CBufferListIterator;

(*---------------------------------------------------------------------------*)

   PUBLIC PROPERTY Value GET : POINTER TO AMemoryBuffer;
   BEGIN
      IF Current = NIL THEN
         RETURN NIL;
      ELSE
         RETURN TPBufferItem( Current )^.Value;
      END;
   END Value;

(*---------------------------------------------------------------------------*)

   PUBLIC PROPERTY Data GET : PTR;
   BEGIN
      IF Current = NIL THEN
         RETURN NIL;
      ELSE
         RETURN TPBufferItem( Current )^.Data;
      END;
   END Data;

(*---------------------------------------------------------------------------*)

   PUBLIC PROPERTY Data SET( Value : PTR );
   BEGIN
      IF Current <> NIL THEN
         TPBufferItem( Current )^.Data := Value;
      END;
   END Data;

(*---------------------------------------------------------------------------*)

   PUBLIC PROCEDURE Init( CONST OfCollection : CBufferList; Direction : collection.TDirection );
   BEGIN
      SUPER.Init( OfCollection, Direction );
   END Init;

(*-----------------------------------------------------------------------------*)

END CBufferListIterator;

(*===========================================================================*)

END lists.