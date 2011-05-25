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

ABSTRACT CLASS CBaseItem( list.CListElem );

   // CDisposable
   PUBLIC VIRTUAL PROCEDURE Dispose();

   // SELF   
   LOCAL VAR
      Data : baseobject.PIBASE := NIL;
      OfDataOwnershipControlList : POINTER TO CDataOwnershipControlList := NIL;

END CBaseItem;

(*---------------------------------------------------------------------------*)

CLASS IMPLEMENTATION CBaseItem;

(*---------------------------------------------------------------------------*)

   PUBLIC VIRTUAL PROCEDURE Dispose();
   BEGIN
      ASSERT( OfDataOwnershipControlList <> NIL );
      IF ( Data <> NIL ) AND ( OfDataOwnershipControlList^.DataOwnership ) THEN
         IF Data^ INHERITS baseobject.CRefcounted THEN
            baseobject.TPRefcounted( Data )^.Release();
         ELSIF Data^ INHERITS baseobject.CDisposable THEN 
            baseobject.TPDisposable( Data )^.Dispose();
            DISPOSE( baseobject.TPDisposable( Data ));
         ELSIF Data^ INHERITS baseobject.BASE THEN
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
END CBaseItem;

(*==========================================================================*)

TYPE
   TPIntegerBaseItem = POINTER TO CIntegerBaseItem;

CLASS CIntegerBaseItem( CBaseItem );

   LOCAL VAR
      Value : INTEGER := 0;

END CIntegerBaseItem;

(*---------------------------------------------------------------------------*)

CLASS IMPLEMENTATION CIntegerBaseItem;
BEGIN
END CIntegerBaseItem;

(*===========================================================================*)

CLASS IMPLEMENTATION CIntegerBaseList;

(*---------------------------------------------------------------------------*)

   PUBLIC PROCEDURE CIntegerBaseList.Contains( Value : INTEGER ): BOOLEAN;
   VAR
      i : INTEGER;
      PE : TPIntegerBaseItem;
   BEGIN
      RETURN Lookup( Value, OUT PE, OUT i );
   END CIntegerBaseList.Contains;

(*---------------------------------------------------------------------------*)

   PUBLIC PROCEDURE CIntegerBaseList.Add( Value : INTEGER; Data : PTR );
   VAR
      PE : TPIntegerBaseItem;
   BEGIN
      NEW( PE );
      PE^.Value := Value;
      PE^.Data := Data;
      SUPER.Add( PE );
   END CIntegerBaseList.Add;

(*---------------------------------------------------------------------------*)

   PUBLIC PROCEDURE CIntegerBaseList.Get( Value : INTEGER; OUT Data : PTR ): BOOLEAN;
   VAR
      i : INTEGER;
      PE : TPIntegerBaseItem;
   BEGIN
      IF Lookup( Value, OUT PE, OUT i ) THEN
         Data := PE^.Data;
         RETURN TRUE;
      ELSE
         RETURN FALSE;
      END;
  END CIntegerBaseList.Get;

(*---------------------------------------------------------------------------*)

   PUBLIC PROCEDURE CIntegerBaseList.Remove( Value : INTEGER ); // removes all occurences
   VAR
      PE, PN : TPIntegerBaseItem;
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
   END CIntegerBaseList.Remove;

(*---------------------------------------------------------------------------*)

   PUBLIC PROCEDURE ElementAt( Index : INTEGER; OUT Value : INTEGER; OUT Data : PTR ) : BOOLEAN; // similar as []
   VAR
      PE : TPIntegerBaseItem;
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

   PUBLIC PROCEDURE CIntegerBaseList.InsertFirst( Value : INTEGER; Data : PTR );
   VAR
      PE : TPIntegerBaseItem;
   BEGIN
      NEW( PE );
      PE^.Value := Value;
      PE^.Data := Data;
      SUPER.InsertFirst( PE );
   END CIntegerBaseList.InsertFirst;

(*---------------------------------------------------------------------------*)

   PUBLIC PROCEDURE CIntegerBaseList.InsertBefore( Before, Value : INTEGER; Data : PTR );
   VAR
      i : INTEGER;
      PB, PE : TPIntegerBaseItem;
   BEGIN
      NEW( PE );
      PE^.Value := Value;
      PE^.Data := Data;
      IF Lookup( Before, OUT PB, OUT i ) THEN
         SUPER.InsertBefore( PB, PE );
      ELSE
         SUPER.InsertFirst( PE );
      END;
   END CIntegerBaseList.InsertBefore;

(*---------------------------------------------------------------------------*)

   PUBLIC PROCEDURE CIntegerBaseList.GetIterator( Direction : collection.TDirection ) : TPIntegerBaseListIterator;
   VAR
      iterator : TPIntegerBaseListIterator := NEW( CIntegerBaseListIterator );
   BEGIN
      iterator^.Init( ADR( SELF ), Direction );
      RETURN iterator;
   END CIntegerBaseList.GetIterator;

(*---------------------------------------------------------------------------*)

   PUBLIC PROCEDURE Enqueue( Value : INTEGER; Data : PTR );
   BEGIN
      Add( Value, Data );
   END Enqueue;

(*---------------------------------------------------------------------------*)

   PUBLIC PROCEDURE Dequeue( OUT Value : INTEGER; OUT Data : PTR ) : BOOLEAN; 
   VAR
      PE : TPIntegerBaseItem;
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

   PRIVATE PROCEDURE CIntegerBaseList.Lookup( Value : INTEGER; OUT Item : list.TPListElem; OUT Index : INTEGER ) : BOOLEAN;
   VAR
      i : INTEGER := 0;
      PE : TPIntegerBaseItem;
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
   END CIntegerBaseList.Lookup;

(*---------------------------------------------------------------------------*)

END CIntegerBaseList;

(*===========================================================================*)

CLASS IMPLEMENTATION CIntegerBaseListIterator;

(*---------------------------------------------------------------------------*)

   PUBLIC PROPERTY Value GET : INTEGER;
   BEGIN
      IF Current = NIL THEN
         RETURN 0;
      ELSE
         RETURN TPIntegerBaseItem( Current )^.Value;
      END;
   END Value;

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

END CIntegerBaseListIterator;

(*==========================================================================*)

TYPE
   TPBaseBaseItem = POINTER TO CBaseBaseItem;

CLASS CBaseBaseItem( CBaseItem );

   LOCAL VAR
      Value : PTR := 0;

END CBaseBaseItem;

(*---------------------------------------------------------------------------*)

CLASS IMPLEMENTATION CBaseBaseItem;
BEGIN
END CBaseBaseItem;

(*==========================================================================*)

CLASS IMPLEMENTATION CBaseBaseList;

(*---------------------------------------------------------------------------*)

   PUBLIC PROCEDURE CBaseBaseList.Contains( Value : PTR ): BOOLEAN;
   VAR
      i : INTEGER;
      PE : TPBaseBaseItem;
   BEGIN
      RETURN Lookup( Value, OUT PE, OUT i );
   END CBaseBaseList.Contains;

(*---------------------------------------------------------------------------*)

   PUBLIC PROCEDURE CBaseBaseList.Add( Value : PTR; Data : PTR );
   VAR
      PE : TPBaseBaseItem;
   BEGIN
      NEW( PE );
      PE^.Value := Value;
      PE^.Data := Data;
      SUPER.Add( PE );
   END CBaseBaseList.Add;

(*---------------------------------------------------------------------------*)

   PUBLIC PROCEDURE CBaseBaseList.Get( Value : PTR; OUT Data : PTR ): BOOLEAN;
   VAR
      i : INTEGER;
      PE : TPBaseBaseItem;
   BEGIN
      IF Lookup( Value, OUT PE, OUT i ) THEN
         Data := PE^.Data;
         RETURN TRUE;
      ELSE
         RETURN FALSE;
      END;
   END CBaseBaseList.Get;

(*---------------------------------------------------------------------------*)

   PUBLIC PROCEDURE CBaseBaseList.Remove( Value : PTR ); // removes all occurences
   VAR
      PE, PN : TPBaseBaseItem;
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
   END CBaseBaseList.Remove;

(*---------------------------------------------------------------------------*)

   PUBLIC PROCEDURE ElementAt( Index : INTEGER; OUT Value : PTR; OUT Data : PTR ) : BOOLEAN; // similar as []
   VAR
      PE : TPBaseBaseItem;
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

   PUBLIC PROCEDURE CBaseBaseList.InsertFirst( Value : PTR; Data : PTR );
   VAR
      PE : TPBaseBaseItem;
   BEGIN
      NEW( PE );
      PE^.Value := Value;
      PE^.Data := Data;
      SUPER.InsertFirst( PE );
   END CBaseBaseList.InsertFirst;

(*---------------------------------------------------------------------------*)

   PUBLIC PROCEDURE CBaseBaseList.InsertBefore( Before, Value : PTR; Data : PTR );
   VAR
      i : INTEGER;
      PB, PE : TPBaseBaseItem;
   BEGIN
      NEW( PE );
      PE^.Value := Value;
      PE^.Data := Data;
      IF Lookup( Before, OUT PB, OUT i ) THEN
         SUPER.InsertBefore( PB, PE );
      ELSE
         SUPER.InsertFirst( PE );
      END;
   END CBaseBaseList.InsertBefore;

(*---------------------------------------------------------------------------*)

   PUBLIC PROCEDURE CBaseBaseList.GetIterator( Direction : collection.TDirection ) : TPBaseBaseListIterator;
   VAR
      iterator : TPBaseBaseListIterator := NEW( CBaseBaseListIterator );
   BEGIN
      iterator^.Init( ADR( SELF ), Direction );
      RETURN iterator;
   END CBaseBaseList.GetIterator;

(*---------------------------------------------------------------------------*)

   PUBLIC PROCEDURE Enqueue( Value : PTR; Data : PTR );
   BEGIN
      Add( Value, Data );
   END Enqueue;

(*---------------------------------------------------------------------------*)

   PUBLIC PROCEDURE Dequeue( OUT Value : PTR; OUT Data : PTR ) : BOOLEAN; 
   VAR
      PE : TPBaseBaseItem;
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

   PRIVATE PROCEDURE CBaseBaseList.Lookup( Value : PTR; OUT Item : list.TPListElem; OUT Index : INTEGER ) : BOOLEAN;
   VAR
      i : INTEGER := 0;
      PE : TPBaseBaseItem;
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
   END CBaseBaseList.Lookup;

(*---------------------------------------------------------------------------*)

END CBaseBaseList;

(*==========================================================================*)

CLASS IMPLEMENTATION CBaseBaseListIterator;

(*---------------------------------------------------------------------------*)

   PUBLIC PROPERTY Value GET : baseobject.PIBASE;
   BEGIN
      IF Current = NIL THEN
         RETURN NIL;
      ELSE
         RETURN TPBaseBaseItem( Current )^.Value;
      END;
   END Value;

(*---------------------------------------------------------------------------*)

   PUBLIC PROPERTY Data GET : baseobject.PIBASE;
   BEGIN
      IF Current = NIL THEN
         RETURN NIL;
      ELSE
         RETURN TPBaseBaseItem( Current )^.Data;
      END;
   END Data;

(*---------------------------------------------------------------------------*)

   PUBLIC PROPERTY Data SET( Value : baseobject.PIBASE );
   BEGIN
      IF Current <> NIL THEN
         TPBaseBaseItem( Current )^.Data := Value;
      END;
   END Data;

(*---------------------------------------------------------------------------*)

END CBaseBaseListIterator;

(*==========================================================================*)

TYPE
   TPStringBaseItem = POINTER TO CStringBaseItem;

CLASS CStringBaseItem( CBaseItem );
      
   LOCAL VAR
      Value : StringsO.CString;

END CStringBaseItem;

(*---------------------------------------------------------------------------*)

CLASS IMPLEMENTATION CStringBaseItem;
BEGIN
END CStringBaseItem;

(*==========================================================================*)

CLASS IMPLEMENTATION CStringBaseList;

(*---------------------------------------------------------------------------*)

   PUBLIC PROCEDURE CStringBaseList.Add( CONST Value : IString; Data : PTR );
   VAR
      PE : TPStringBaseItem;
   BEGIN
      NEW( PE );
      PE^.Value.Assign( Value );
      PE^.Data := Data;
      SUPER.Add( PE );
   END CStringBaseList.Add;

(*---------------------------------------------------------------------------*)

   PUBLIC PROCEDURE CStringBaseList.Contains( CONST Value : IString ): BOOLEAN;
   VAR
      i : INTEGER;
      PE : TPStringBaseItem;
   BEGIN
      RETURN Lookup( Value, OUT PE, OUT i );
   END CStringBaseList.Contains;

(*---------------------------------------------------------------------------*)

   PUBLIC PROCEDURE CStringBaseList.Get( CONST Value : IString; OUT Data : PTR ): BOOLEAN;
   VAR
      i : INTEGER;
      PE : TPStringBaseItem;
   BEGIN
      IF Lookup( Value, OUT PE, OUT i ) THEN
         Value.Assign( PE^.Value );
          Data := PE^.Data;
         RETURN TRUE;
      ELSE
         RETURN FALSE;
      END;
   END CStringBaseList.Get;

(*---------------------------------------------------------------------------*)

   PUBLIC PROCEDURE CStringBaseList.Remove( CONST Value : IString ); // removes all occurences
   VAR
      PE, PN : TPStringBaseItem;
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
   END CStringBaseList.Remove;

(*---------------------------------------------------------------------------*)

   PUBLIC PROCEDURE ElementAt( Index : INTEGER; OUT Value : IString; OUT Data : PTR ) : BOOLEAN; // similar as []
   VAR
      PE : TPStringBaseItem;
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

   PUBLIC PROCEDURE CStringBaseList.InsertFirst( CONST Value : IString; Data : PTR );
   VAR
      PE : TPStringBaseItem;
   BEGIN
      NEW( PE );
      PE^.Value.Assign( Value );
      PE^.Data := Data;
      SUPER.InsertFirst( PE );
   END CStringBaseList.InsertFirst;

(*---------------------------------------------------------------------------*)

   PUBLIC PROCEDURE CStringBaseList.InsertBefore( CONST Before, Value : IString; Data : PTR );
   VAR
      i : INTEGER;
      PB, PE : TPStringBaseItem;
   BEGIN
      NEW( PE );
      PE^.Value.Assign( Value );
      PE^.Data := Data;
      IF Lookup( Before, OUT PB, OUT i ) THEN
         SUPER.InsertBefore( PB, PE );
      ELSE
         SUPER.InsertFirst( PE );
      END;
   END CStringBaseList.InsertBefore;

(*---------------------------------------------------------------------------*)

   PUBLIC PROCEDURE CStringBaseList.GetIterator( Direction : collection.TDirection ) : TPStringBaseListIterator;
   VAR
      iterator : TPStringBaseListIterator := NEW( CStringBaseListIterator );
   BEGIN
      iterator^.Init( ADR( SELF ), Direction );
      RETURN iterator;
   END CStringBaseList.GetIterator;

(*---------------------------------------------------------------------------*)

   PUBLIC PROCEDURE Enqueue( CONST Value : IString; Data : PTR );
   BEGIN
      Add( Value, Data );
   END Enqueue;

(*---------------------------------------------------------------------------*)

   PUBLIC PROCEDURE Dequeue( OUT Value : IString; OUT Data : PTR ) : BOOLEAN; 
   VAR
      PE : TPStringBaseItem;
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

  PRIVATE PROCEDURE CStringBaseList.Lookup( CONST Value : IString; OUT Item : list.TPListElem; OUT Index : INTEGER ) : BOOLEAN;
  VAR
    i : INTEGER := 0;
    PE : TPStringBaseItem;
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
  END CStringBaseList.Lookup;

(*---------------------------------------------------------------------------*)

END CStringBaseList;

(*==========================================================================*)

CLASS IMPLEMENTATION CStringBaseListIterator;

(*---------------------------------------------------------------------------*)

   PUBLIC PROPERTY Value GET : TPString;
   BEGIN
      IF Current = NIL THEN
         RETURN NIL;
      ELSE
         RETURN ADR( TPStringBaseItem( Current )^.Value );
      END;
   END Value;

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

END CStringBaseListIterator;

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
      iterator^.Init( ADR( SELF ), Direction );
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
  TPBufferBaseItem = POINTER TO ABufferBaseItem;
  
ABSTRACT CLASS ABufferBaseItem( CBaseItem );

   LOCAL ABSTRACT READONLY PROPERTY
      Value : POINTER TO AMemoryBuffer;

END ABufferBaseItem;

(*---------------------------------------------------------------------------*)

CLASS IMPLEMENTATION ABufferBaseItem;
END ABufferBaseItem;

(*==========================================================================*)

CLASS CDynamicItem( ABufferBaseItem );

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

CLASS CSlotItem32( ABufferBaseItem );

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

CLASS CSlotItem64( ABufferBaseItem );

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

CLASS CSlotItem256( ABufferBaseItem );

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

CLASS IMPLEMENTATION CBufferBaseList;

(*---------------------------------------------------------------------------*)

   PUBLIC PROCEDURE CBufferBaseList.Add( CONST Value : AMemoryBuffer; Data : PTR );
   VAR
      PE : TPBufferBaseItem;
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
   END CBufferBaseList.Add;

(*---------------------------------------------------------------------------*)

   PUBLIC PROCEDURE CBufferBaseList.Contains( CONST Value : AMemoryBuffer ): BOOLEAN;
   VAR
      i : INTEGER;
      PE : TPBufferBaseItem;
   BEGIN
      RETURN Lookup( Value, OUT PE, OUT i );
   END CBufferBaseList.Contains;

(*---------------------------------------------------------------------------*)

   PUBLIC PROCEDURE CBufferBaseList.Get( CONST Value : AMemoryBuffer; OUT Data : PTR ): BOOLEAN;
   VAR
      i : INTEGER;
      PE : TPBufferBaseItem;
   BEGIN
      IF Lookup( Value, OUT PE, OUT i ) THEN
         Data := PE^.Data;
         RETURN TRUE;
      ELSE
         RETURN FALSE;
      END;
   END CBufferBaseList.Get;

(*---------------------------------------------------------------------------*)

   PUBLIC PROCEDURE CBufferBaseList.Remove( CONST Value : AMemoryBuffer ); // removes all occurences
   VAR
      PE, PN : TPBufferBaseItem;
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
   END CBufferBaseList.Remove;

(*---------------------------------------------------------------------------*)

   PUBLIC PROCEDURE ElementAt( Index : INTEGER; OUT Value : AMemoryBuffer; OUT Data : PTR ) : BOOLEAN; // similar as []
   VAR
      PE : TPBufferBaseItem;
   BEGIN
      IF SUPER.ElementAt( Index, OUT PE ) THEN
         Value.Assign( TPBufferBaseItem( PE )^.Value^ );
         Data := TPBufferBaseItem( PE )^.Data;
         RETURN TRUE;
      ELSE
         RETURN FALSE;
      END;
   END ElementAt;

(*---------------------------------------------------------------------------*)

   PUBLIC PROCEDURE CBufferBaseList.AddOA( CONST Value : ARRAY OF BYTE; Data : PTR );
   VAR
      PE : TPBufferBaseItem;
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
   END CBufferBaseList.AddOA;

(*---------------------------------------------------------------------------*)

   PUBLIC PROCEDURE CBufferBaseList.ContainsOA( CONST Value : ARRAY OF BYTE ): BOOLEAN;
   VAR
      i : INTEGER;
      PE : TPBufferBaseItem;
      S : StorageO.CMemoryBuffer;
   BEGIN
      S.FromOA( Value, TRUE );
      RETURN Lookup( S, OUT PE, OUT i );
   END CBufferBaseList.ContainsOA;

(*---------------------------------------------------------------------------*)

   PUBLIC PROCEDURE CBufferBaseList.GetOA( CONST Value : ARRAY OF BYTE; OUT Data : PTR ): BOOLEAN;
   VAR
      i : INTEGER;
      PE : TPBufferBaseItem;
      S : StorageO.CMemoryBuffer;
   BEGIN
      S.FromOA( Value, TRUE );
      IF NOT Lookup( S, OUT PE, OUT i ) THEN
         RETURN FALSE;
      END;
      Data := PE^.Data;
      RETURN TRUE;
   END CBufferBaseList.GetOA;

(*---------------------------------------------------------------------------*)

   PUBLIC PROCEDURE CBufferBaseList.RemoveOA( CONST Value : ARRAY OF BYTE ); // removes all occurences
   VAR
      PE, PN : TPBufferBaseItem;
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
   END CBufferBaseList.RemoveOA;

(*---------------------------------------------------------------------------*)

   PUBLIC PROCEDURE CBufferBaseList.InsertFirst( CONST Value : AMemoryBuffer; Data : PTR );
   VAR
      PE : TPBufferBaseItem;
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
   END CBufferBaseList.InsertFirst;

(*---------------------------------------------------------------------------*)

   PUBLIC PROCEDURE CBufferBaseList.InsertBefore( CONST Before, Value : AMemoryBuffer; Data : PTR );
   VAR
      i : INTEGER;
      PB, PE : TPBufferBaseItem;
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
   END CBufferBaseList.InsertBefore;

(*---------------------------------------------------------------------------*)

   PUBLIC PROCEDURE CBufferBaseList.GetIterator( Direction : collection.TDirection ) : TPBufferBaseListIterator;
   VAR
      iterator : TPBufferBaseListIterator := NEW( CBufferBaseListIterator );
   BEGIN
      iterator^.Init( ADR( SELF ), Direction );
      RETURN iterator;
   END CBufferBaseList.GetIterator;

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
      PE : TPBufferBaseItem;
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

   PRIVATE PROCEDURE CBufferBaseList.Lookup( CONST Value : AMemoryBuffer; OUT Item : list.TPListElem; OUT Index : INTEGER ) : BOOLEAN;
   VAR
      i : INTEGER := 0;
      PE : TPBufferBaseItem;
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
   END CBufferBaseList.Lookup;

(*---------------------------------------------------------------------------*)

BEGIN
END CBufferBaseList;

(*==========================================================================*)

CLASS IMPLEMENTATION CBufferBaseListIterator;

(*---------------------------------------------------------------------------*)

   PUBLIC PROPERTY Value GET : POINTER TO AMemoryBuffer;
   BEGIN
      IF Current = NIL THEN
         RETURN NIL;
      ELSE
         RETURN TPBufferBaseItem( Current )^.Value;
      END;
   END Value;

(*---------------------------------------------------------------------------*)

   PUBLIC PROPERTY Data GET : baseobject.PIBASE;
   BEGIN
      IF Current = NIL THEN
         RETURN NIL;
      ELSE
         RETURN TPBufferBaseItem( Current )^.Data;
      END;
   END Data;

(*---------------------------------------------------------------------------*)

   PUBLIC PROPERTY Data SET( Value : baseobject.PIBASE );
   BEGIN
      IF Current <> NIL THEN
         TPBufferBaseItem( Current )^.Data := Value;
      END;
   END Data;

(*---------------------------------------------------------------------------*)

END CBufferBaseListIterator;

(*===========================================================================*)

END lists.