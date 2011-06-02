IMPLEMENTATION MODULE lists;

FROM Storage IMPORT
   ALLOCATE, DEALLOCATE;
  
FROM Debug IMPORT
   Assertion, LogAssertionW;

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

ABSTRACT CLASS CPtrItem( list.CListElem );

   // CDisposable
   PUBLIC VIRTUAL PROCEDURE Dispose();

   // SELF   
   LOCAL VAR
      Data : PTR := NIL;
      OfDataOwnershipControlList : POINTER TO CDataOwnershipControlList := NIL;

END CPtrItem;

(*---------------------------------------------------------------------------*)

CLASS IMPLEMENTATION CPtrItem;

(*---------------------------------------------------------------------------*)

   PUBLIC VIRTUAL PROCEDURE Dispose();
   BEGIN
      ASSERT( OfDataOwnershipControlList <> NIL );
      IF ( Data <> NIL ) AND ( OfDataOwnershipControlList^.DataOwnership ) THEN
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
END CPtrItem;

(*==========================================================================*)

TYPE
   TPIntegerPtrItem = POINTER TO CIntegerPtrItem;

CLASS CIntegerPtrItem( CPtrItem );

   LOCAL VAR
      Value : INTEGER := 0;

END CIntegerPtrItem;

(*---------------------------------------------------------------------------*)

CLASS IMPLEMENTATION CIntegerPtrItem;
BEGIN
END CIntegerPtrItem;

(*===========================================================================*)

CLASS IMPLEMENTATION CIntegerPtrList;

(*---------------------------------------------------------------------------*)

   PUBLIC PROCEDURE CIntegerPtrList.Contains( Value : INTEGER ): BOOLEAN;
   VAR
      i : INTEGER;
      PE : TPIntegerPtrItem;
   BEGIN
      RETURN Lookup( Value, OUT PE, OUT i );
   END CIntegerPtrList.Contains;

(*---------------------------------------------------------------------------*)

   PUBLIC PROCEDURE CIntegerPtrList.Add( Value : INTEGER; Data : PTR );
   VAR
      PE : TPIntegerPtrItem;
   BEGIN
      NEW( PE );
      PE^.Value := Value;
      PE^.Data := Data;
      SUPER.Add( PE );
   END CIntegerPtrList.Add;

(*---------------------------------------------------------------------------*)

   PUBLIC PROCEDURE CIntegerPtrList.Get( Value : INTEGER; OUT Data : PTR ): BOOLEAN;
   VAR
      i : INTEGER;
      PE : TPIntegerPtrItem;
   BEGIN
      IF Lookup( Value, OUT PE, OUT i ) THEN
         Data := PE^.Data;
         RETURN TRUE;
      ELSE
         RETURN FALSE;
      END;
  END CIntegerPtrList.Get;

(*---------------------------------------------------------------------------*)

   PUBLIC PROCEDURE CIntegerPtrList.Remove( Value : INTEGER ); // removes all occurences
   VAR
      PE, PN : TPIntegerPtrItem;
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
   END CIntegerPtrList.Remove;

(*---------------------------------------------------------------------------*)

   PUBLIC PROCEDURE ElementAt( Index : INTEGER; OUT Value : INTEGER; OUT Data : PTR ) : BOOLEAN; // similar as []
   VAR
      PE : TPIntegerPtrItem;
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

   PUBLIC PROCEDURE CIntegerPtrList.InsertFirst( Value : INTEGER; Data : PTR );
   VAR
      PE : TPIntegerPtrItem;
   BEGIN
      NEW( PE );
      PE^.Value := Value;
      PE^.Data := Data;
      SUPER.InsertFirst( PE );
   END CIntegerPtrList.InsertFirst;

(*---------------------------------------------------------------------------*)

   PUBLIC PROCEDURE CIntegerPtrList.InsertBefore( Before, Value : INTEGER; Data : PTR );
   VAR
      i : INTEGER;
      PB, PE : TPIntegerPtrItem;
   BEGIN
      NEW( PE );
      PE^.Value := Value;
      PE^.Data := Data;
      IF Lookup( Before, OUT PB, OUT i ) THEN
         SUPER.InsertBefore( PB, PE );
      ELSE
         SUPER.InsertFirst( PE );
      END;
   END CIntegerPtrList.InsertBefore;

(*---------------------------------------------------------------------------*)

   PUBLIC PROCEDURE CIntegerPtrList.GetIterator( Direction : collection.TDirection ) : TPIntegerPtrListIterator;
   VAR
      iterator : TPIntegerPtrListIterator := NEW( CIntegerPtrListIterator );
   BEGIN
      iterator^.Init( SELF, Direction );
      RETURN iterator;
   END CIntegerPtrList.GetIterator;

(*---------------------------------------------------------------------------*)

   PUBLIC PROCEDURE Enqueue( Value : INTEGER; Data : PTR );
   BEGIN
      Add( Value, Data );
   END Enqueue;

(*---------------------------------------------------------------------------*)

   PUBLIC PROCEDURE Dequeue( OUT Value : INTEGER; OUT Data : PTR ) : BOOLEAN; 
   VAR
      PE : TPIntegerPtrItem;
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

   PRIVATE PROCEDURE CIntegerPtrList.Lookup( Value : INTEGER; OUT Item : list.TPListElem; OUT Index : INTEGER ) : BOOLEAN;
   VAR
      i : INTEGER := 0;
      PE : TPIntegerPtrItem;
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
   END CIntegerPtrList.Lookup;

(*---------------------------------------------------------------------------*)

END CIntegerPtrList;

(*===========================================================================*)

CLASS IMPLEMENTATION CIntegerPtrListIterator;

(*---------------------------------------------------------------------------*)

   PUBLIC PROPERTY Value GET : INTEGER;
   BEGIN
      IF Current = NIL THEN
         RETURN 0;
      ELSE
         RETURN TPIntegerPtrItem( Current )^.Value;
      END;
   END Value;

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

END CIntegerPtrListIterator;

(*==========================================================================*)

TYPE
   TPPtrPtrItem = POINTER TO CPtrPtrItem;

CLASS CPtrPtrItem( CPtrItem );

   LOCAL VAR
      Value : PTR := NIL;

END CPtrPtrItem;

(*---------------------------------------------------------------------------*)

CLASS IMPLEMENTATION CPtrPtrItem;
BEGIN
END CPtrPtrItem;

(*==========================================================================*)

CLASS IMPLEMENTATION CPtrPtrList;

(*---------------------------------------------------------------------------*)

   PUBLIC PROCEDURE CPtrPtrList.Contains( Value : PTR ): BOOLEAN;
   VAR
      i : INTEGER;
      PE : TPPtrPtrItem;
   BEGIN
      RETURN Lookup( Value, OUT PE, OUT i );
   END CPtrPtrList.Contains;

(*---------------------------------------------------------------------------*)

   PUBLIC PROCEDURE CPtrPtrList.Add( Value : PTR; Data : PTR );
   VAR
      PE : TPPtrPtrItem;
   BEGIN
      NEW( PE );
      PE^.Value := Value;
      PE^.Data := Data;
      SUPER.Add( PE );
   END CPtrPtrList.Add;

(*---------------------------------------------------------------------------*)

   PUBLIC PROCEDURE CPtrPtrList.Get( Value : PTR; OUT Data : PTR ): BOOLEAN;
   VAR
      i : INTEGER;
      PE : TPPtrPtrItem;
   BEGIN
      IF Lookup( Value, OUT PE, OUT i ) THEN
         Data := PE^.Data;
         RETURN TRUE;
      ELSE
         RETURN FALSE;
      END;
   END CPtrPtrList.Get;

(*---------------------------------------------------------------------------*)

   PUBLIC PROCEDURE CPtrPtrList.Remove( Value : PTR ); // removes all occurences
   VAR
      PE, PN : TPPtrPtrItem;
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
   END CPtrPtrList.Remove;

(*---------------------------------------------------------------------------*)

   PUBLIC PROCEDURE ElementAt( Index : INTEGER; OUT Value : PTR; OUT Data : PTR ) : BOOLEAN; // similar as []
   VAR
      PE : TPPtrPtrItem;
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

   PUBLIC PROCEDURE CPtrPtrList.InsertFirst( Value : PTR; Data : PTR );
   VAR
      PE : TPPtrPtrItem;
   BEGIN
      NEW( PE );
      PE^.Value := Value;
      PE^.Data := Data;
      SUPER.InsertFirst( PE );
   END CPtrPtrList.InsertFirst;

(*---------------------------------------------------------------------------*)

   PUBLIC PROCEDURE CPtrPtrList.InsertBefore( Before, Value : PTR; Data : PTR );
   VAR
      i : INTEGER;
      PB, PE : TPPtrPtrItem;
   BEGIN
      NEW( PE );
      PE^.Value := Value;
      PE^.Data := Data;
      IF Lookup( Before, OUT PB, OUT i ) THEN
         SUPER.InsertBefore( PB, PE );
      ELSE
         SUPER.InsertFirst( PE );
      END;
   END CPtrPtrList.InsertBefore;

(*---------------------------------------------------------------------------*)

   PUBLIC PROCEDURE CPtrPtrList.GetIterator( Direction : collection.TDirection ) : TPPtrPtrListIterator;
   VAR
      iterator : TPPtrPtrListIterator := NEW( CPtrPtrListIterator );
   BEGIN
      iterator^.Init( SELF, Direction );
      RETURN iterator;
   END CPtrPtrList.GetIterator;

(*---------------------------------------------------------------------------*)

   PUBLIC PROCEDURE Enqueue( Value : PTR; Data : PTR );
   BEGIN
      Add( Value, Data );
   END Enqueue;

(*---------------------------------------------------------------------------*)

   PUBLIC PROCEDURE Dequeue( OUT Value : PTR; OUT Data : PTR ) : BOOLEAN; 
   VAR
      PE : TPPtrPtrItem;
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

   PRIVATE PROCEDURE CPtrPtrList.Lookup( Value : PTR; OUT Item : list.TPListElem; OUT Index : INTEGER ) : BOOLEAN;
   VAR
      i : INTEGER := 0;
      PE : TPPtrPtrItem;
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
   END CPtrPtrList.Lookup;

(*---------------------------------------------------------------------------*)

END CPtrPtrList;

(*==========================================================================*)

CLASS IMPLEMENTATION CPtrPtrListIterator;

(*---------------------------------------------------------------------------*)

   PUBLIC PROPERTY Value GET : PTR;
   BEGIN
      IF Current = NIL THEN
         RETURN NIL;
      ELSE
         RETURN TPPtrPtrItem( Current )^.Value;
      END;
   END Value;

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

END CPtrPtrListIterator;

(*==========================================================================*)

TYPE
   TPStringPtrItem = POINTER TO CStringPtrItem;

CLASS CStringPtrItem( CPtrItem );
      
   LOCAL VAR
      Value : StringsO.CString;

END CStringPtrItem;

(*---------------------------------------------------------------------------*)

CLASS IMPLEMENTATION CStringPtrItem;
BEGIN
END CStringPtrItem;

(*==========================================================================*)

CLASS IMPLEMENTATION CStringPtrList;

(*---------------------------------------------------------------------------*)

   PUBLIC PROCEDURE CStringPtrList.Add( CONST Value : IString; Data : PTR );
   VAR
      PE : TPStringPtrItem;
   BEGIN
      NEW( PE );
      PE^.Value.Assign( Value );
      PE^.Data := Data;
      SUPER.Add( PE );
   END CStringPtrList.Add;

(*---------------------------------------------------------------------------*)

   PUBLIC PROCEDURE CStringPtrList.Contains( CONST Value : IString ): BOOLEAN;
   VAR
      i : INTEGER;
      PE : TPStringPtrItem;
   BEGIN
      RETURN Lookup( Value, OUT PE, OUT i );
   END CStringPtrList.Contains;

(*---------------------------------------------------------------------------*)

   PUBLIC PROCEDURE CStringPtrList.Get( CONST Value : IString; OUT Data : PTR ): BOOLEAN;
   VAR
      i : INTEGER;
      PE : TPStringPtrItem;
   BEGIN
      IF Lookup( Value, OUT PE, OUT i ) THEN
         Value.Assign( PE^.Value );
          Data := PE^.Data;
         RETURN TRUE;
      ELSE
         RETURN FALSE;
      END;
   END CStringPtrList.Get;

(*---------------------------------------------------------------------------*)

   PUBLIC PROCEDURE CStringPtrList.Remove( CONST Value : IString ); // removes all occurences
   VAR
      PE, PN : TPStringPtrItem;
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
   END CStringPtrList.Remove;

(*---------------------------------------------------------------------------*)

   PUBLIC PROCEDURE ElementAt( Index : INTEGER; OUT Value : IString; OUT Data : PTR ) : BOOLEAN; // similar as []
   VAR
      PE : TPStringPtrItem;
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

   PUBLIC PROCEDURE CStringPtrList.InsertFirst( CONST Value : IString; Data : PTR );
   VAR
      PE : TPStringPtrItem;
   BEGIN
      NEW( PE );
      PE^.Value.Assign( Value );
      PE^.Data := Data;
      SUPER.InsertFirst( PE );
   END CStringPtrList.InsertFirst;

(*---------------------------------------------------------------------------*)

   PUBLIC PROCEDURE CStringPtrList.InsertBefore( CONST Before, Value : IString; Data : PTR );
   VAR
      i : INTEGER;
      PB, PE : TPStringPtrItem;
   BEGIN
      NEW( PE );
      PE^.Value.Assign( Value );
      PE^.Data := Data;
      IF Lookup( Before, OUT PB, OUT i ) THEN
         SUPER.InsertBefore( PB, PE );
      ELSE
         SUPER.InsertFirst( PE );
      END;
   END CStringPtrList.InsertBefore;

(*---------------------------------------------------------------------------*)

   PUBLIC PROCEDURE CStringPtrList.GetIterator( Direction : collection.TDirection ) : TPStringPtrListIterator;
   VAR
      iterator : TPStringPtrListIterator := NEW( CStringPtrListIterator );
   BEGIN
      iterator^.Init( SELF, Direction );
      RETURN iterator;
   END CStringPtrList.GetIterator;

(*---------------------------------------------------------------------------*)

   PUBLIC PROCEDURE Enqueue( CONST Value : IString; Data : PTR );
   BEGIN
      Add( Value, Data );
   END Enqueue;

(*---------------------------------------------------------------------------*)

   PUBLIC PROCEDURE Dequeue( OUT Value : IString; OUT Data : PTR ) : BOOLEAN; 
   VAR
      PE : TPStringPtrItem;
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

  PRIVATE PROCEDURE CStringPtrList.Lookup( CONST Value : IString; OUT Item : list.TPListElem; OUT Index : INTEGER ) : BOOLEAN;
  VAR
    i : INTEGER := 0;
    PE : TPStringPtrItem;
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
  END CStringPtrList.Lookup;

(*---------------------------------------------------------------------------*)

END CStringPtrList;

(*==========================================================================*)

CLASS IMPLEMENTATION CStringPtrListIterator;

(*---------------------------------------------------------------------------*)

   PUBLIC PROPERTY Value GET : TPString;
   BEGIN
      IF Current = NIL THEN
         RETURN NIL;
      ELSE
         RETURN ADR( TPStringPtrItem( Current )^.Value );
      END;
   END Value;

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

END CStringPtrListIterator;

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
      IF NOT Lookup( Value, OUT PE, OUT i ) THEN
         RETURN FALSE;
      END;
      Data.Assign( PE^.Data );
      RETURN TRUE;
   END CStringStringList.Get;

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
      iterator : TPStringStringListIterator := NEW( CStringStringListIterator );
   BEGIN
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

END CStringStringListIterator;

(*===========================================================================*)

TYPE
  TPBufferPtrItem = POINTER TO ABufferPtrItem;
  
ABSTRACT CLASS ABufferPtrItem( CPtrItem );

   LOCAL ABSTRACT READONLY PROPERTY
      Value : POINTER TO AMemoryBuffer;

END ABufferPtrItem;

(*---------------------------------------------------------------------------*)

CLASS IMPLEMENTATION ABufferPtrItem;
END ABufferPtrItem;

(*==========================================================================*)

CLASS CDynamicItem( ABufferPtrItem );

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

CLASS CSlotItem32( ABufferPtrItem );

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

CLASS CSlotItem64( ABufferPtrItem );

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

CLASS CSlotItem256( ABufferPtrItem );

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

CLASS IMPLEMENTATION CBufferPtrList;

(*---------------------------------------------------------------------------*)

   PUBLIC PROCEDURE CBufferPtrList.Add( CONST Value : AMemoryBuffer; Data : PTR );
   VAR
      PE : TPBufferPtrItem;
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
      SUPER.Add( PE );
   END CBufferPtrList.Add;

(*---------------------------------------------------------------------------*)

   PUBLIC PROCEDURE CBufferPtrList.Contains( CONST Value : AMemoryBuffer ): BOOLEAN;
   VAR
      i : INTEGER;
      PE : TPBufferPtrItem;
   BEGIN
      RETURN Lookup( Value, OUT PE, OUT i );
   END CBufferPtrList.Contains;

(*---------------------------------------------------------------------------*)

   PUBLIC PROCEDURE CBufferPtrList.Get( CONST Value : AMemoryBuffer; OUT Data : PTR ): BOOLEAN;
   VAR
      i : INTEGER;
      PE : TPBufferPtrItem;
   BEGIN
      IF Lookup( Value, OUT PE, OUT i ) THEN
         Data := PE^.Data;
         RETURN TRUE;
      ELSE
         RETURN FALSE;
      END;
   END CBufferPtrList.Get;

(*---------------------------------------------------------------------------*)

   PUBLIC PROCEDURE CBufferPtrList.Remove( CONST Value : AMemoryBuffer ); // removes all occurences
   VAR
      PE, PN : TPBufferPtrItem;
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
   END CBufferPtrList.Remove;

(*---------------------------------------------------------------------------*)

   PUBLIC PROCEDURE ElementAt( Index : INTEGER; OUT Value : AMemoryBuffer; OUT Data : PTR ) : BOOLEAN; // similar as []
   VAR
      PE : TPBufferPtrItem;
   BEGIN
      IF SUPER.ElementAt( Index, OUT PE ) THEN
         Value.Assign( TPBufferPtrItem( PE )^.Value^ );
         Data := TPBufferPtrItem( PE )^.Data;
         RETURN TRUE;
      ELSE
         RETURN FALSE;
      END;
   END ElementAt;

(*---------------------------------------------------------------------------*)

   PUBLIC PROCEDURE CBufferPtrList.AddOA( CONST Value : ARRAY OF BYTE; Data : PTR );
   VAR
      PE : TPBufferPtrItem;
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
   END CBufferPtrList.AddOA;

(*---------------------------------------------------------------------------*)

   PUBLIC PROCEDURE CBufferPtrList.ContainsOA( CONST Value : ARRAY OF BYTE ): BOOLEAN;
   VAR
      i : INTEGER;
      PE : TPBufferPtrItem;
      S : StorageO.CMemoryBuffer;
   BEGIN
      S.FromOA( Value, TRUE );
      RETURN Lookup( S, OUT PE, OUT i );
   END CBufferPtrList.ContainsOA;

(*---------------------------------------------------------------------------*)

   PUBLIC PROCEDURE CBufferPtrList.GetOA( CONST Value : ARRAY OF BYTE; OUT Data : PTR ): BOOLEAN;
   VAR
      i : INTEGER;
      PE : TPBufferPtrItem;
      S : StorageO.CMemoryBuffer;
   BEGIN
      S.FromOA( Value, TRUE );
      IF NOT Lookup( S, OUT PE, OUT i ) THEN
         RETURN FALSE;
      END;
      Data := PE^.Data;
      RETURN TRUE;
   END CBufferPtrList.GetOA;

(*---------------------------------------------------------------------------*)

   PUBLIC PROCEDURE CBufferPtrList.RemoveOA( CONST Value : ARRAY OF BYTE ); // removes all occurences
   VAR
      PE, PN : TPBufferPtrItem;
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
   END CBufferPtrList.RemoveOA;

(*---------------------------------------------------------------------------*)

   PUBLIC PROCEDURE CBufferPtrList.InsertFirst( CONST Value : AMemoryBuffer; Data : PTR );
   VAR
      PE : TPBufferPtrItem;
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
   END CBufferPtrList.InsertFirst;

(*---------------------------------------------------------------------------*)

   PUBLIC PROCEDURE CBufferPtrList.InsertBefore( CONST Before, Value : AMemoryBuffer; Data : PTR );
   VAR
      i : INTEGER;
      PB, PE : TPBufferPtrItem;
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
   END CBufferPtrList.InsertBefore;

(*---------------------------------------------------------------------------*)

   PUBLIC PROCEDURE CBufferPtrList.GetIterator( Direction : collection.TDirection ) : TPBufferPtrListIterator;
   VAR
      iterator : TPBufferPtrListIterator := NEW( CBufferPtrListIterator );
   BEGIN
      iterator^.Init( SELF, Direction );
      RETURN iterator;
   END CBufferPtrList.GetIterator;

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
      PE : TPBufferPtrItem;
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

   PRIVATE PROCEDURE CBufferPtrList.Lookup( CONST Value : AMemoryBuffer; OUT Item : list.TPListElem; OUT Index : INTEGER ) : BOOLEAN;
   VAR
      i : INTEGER := 0;
      PE : TPBufferPtrItem;
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
   END CBufferPtrList.Lookup;

(*---------------------------------------------------------------------------*)

BEGIN
END CBufferPtrList;

(*==========================================================================*)

CLASS IMPLEMENTATION CBufferPtrListIterator;

(*---------------------------------------------------------------------------*)

   PUBLIC PROPERTY Value GET : POINTER TO AMemoryBuffer;
   BEGIN
      IF Current = NIL THEN
         RETURN NIL;
      ELSE
         RETURN TPBufferPtrItem( Current )^.Value;
      END;
   END Value;

(*---------------------------------------------------------------------------*)

   PUBLIC PROPERTY Data GET : PTR;
   BEGIN
      IF Current = NIL THEN
         RETURN NIL;
      ELSE
         RETURN TPBufferPtrItem( Current )^.Data;
      END;
   END Data;

(*---------------------------------------------------------------------------*)

   PUBLIC PROPERTY Data SET( Value : PTR );
   BEGIN
      IF Current <> NIL THEN
         TPBufferPtrItem( Current )^.Data := Value;
      END;
   END Data;

(*---------------------------------------------------------------------------*)

END CBufferPtrListIterator;

(*===========================================================================*)

END lists.