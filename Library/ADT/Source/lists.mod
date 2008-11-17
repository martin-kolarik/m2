IMPLEMENTATION MODULE lists;

FROM Storage IMPORT
   ALLOCATE;
  
FROM StringsO IMPORT
   CString;

FROM StorageO IMPORT
   CMemoryBuffer, CMemorySlot32, CMemorySlot64, CMemorySlot256;

//===========================================================================

TYPE
  TPIntegerItem = POINTER TO CIntegerItem;

CLASS CIntegerItem( list.CListElem );
  Value : INTEGER;
  Data  : PTR;
END CIntegerItem;

CLASS IMPLEMENTATION CIntegerItem;
BEGIN
  Value := 0;
  Data := 0;
END CIntegerItem;

//---------------------------------------------------------------------------

CLASS IMPLEMENTATION CIntegerList;

//---------------------------------------------------------------------------

  PUBLIC READONLY PROPERTY CIntegerList.Current GET : INTEGER;
  BEGIN
    IF _Current = -1 THEN
      RETURN 0;
    ELSE
      RETURN TPIntegerItem( _Current )^.Value;
    END;
  END CIntegerList.Current;

//---------------------------------------------------------------------------

  PUBLIC READONLY PROPERTY CIntegerList.CurrentData GET : PTR;
  BEGIN
    IF _Current = -1 THEN
      RETURN NIL;
    ELSE
      RETURN TPIntegerItem( _Current )^.Data;
    END;
  END CIntegerList.CurrentData;

//---------------------------------------------------------------------------

  PUBLIC PROPERTY CIntegerList.CurrentData SET( Value : PTR );
  BEGIN
    IF _Current = -1 THEN
      RETURN;
    ELSE
      TPIntegerItem( _Current )^.Data := Value;
    END;
  END CIntegerList.CurrentData;

//---------------------------------------------------------------------------

  PUBLIC READONLY INDEX CIntegerList GET( Index : INTEGER ) : INTEGER;
  VAR
    PE : TPIntegerItem;
  BEGIN
    PE := TPIntegerItem( SUPER[Index] );
    IF PE = NIL THEN
      RETURN -1;
    ELSE
      RETURN TPIntegerItem( PE )^.Value;
    END;
  END CIntegerList;

//---------------------------------------------------------------------------

  PUBLIC PROCEDURE CIntegerList.Add( Value : INTEGER; Data : PTR );
  VAR
    PE : TPIntegerItem;
  BEGIN
    NEW( PE );
    PE^.Value := Value;
    PE^.Data := Data;
    SUPER.Append( PE );
  END CIntegerList.Add;

//---------------------------------------------------------------------------

  PUBLIC PROCEDURE CIntegerList.Contains( Value : INTEGER ): BOOLEAN;
  VAR
    i : INTEGER;
    PE : TPIntegerItem;
  BEGIN
    RETURN Lookup( Value, OUT PE, OUT i );
  END CIntegerList.Contains;

//---------------------------------------------------------------------------

  PUBLIC PROCEDURE CIntegerList.Get( Value : INTEGER; OUT Data : PTR ): BOOLEAN;
  VAR
    i : INTEGER;
    PE : TPIntegerItem;
  BEGIN
    IF NOT Lookup( Value, OUT PE, OUT i ) THEN
      RETURN FALSE;
    END;
    Data := PE^.Data;
    RETURN TRUE;
  END CIntegerList.Get;

//---------------------------------------------------------------------------

  PUBLIC PROCEDURE CIntegerList.Remove( Value : INTEGER ); // removes all occurences
  VAR
    PE, PN : TPIntegerItem;
    b : BOOLEAN;
  BEGIN
    b := SUPER.GetFirst( OUT PE );
    WHILE b DO
      b := SUPER.NextOf( PE, OUT PN );
      IF PE^.Value = Value THEN 
        Delete( PE );
      END;
      PE := PN;
    END; // WHILE
  END CIntegerList.Remove;

//---------------------------------------------------------------------------

  PUBLIC PROCEDURE ElementAt( Index : INTEGER; OUT Value : INTEGER; OUT Data : PTR ) : BOOLEAN; // similar as []
  VAR
    PE : TPIntegerItem;
  BEGIN
    PE := TPIntegerItem( SUPER[Index] );
    IF PE = NIL THEN
      RETURN FALSE;
    END;
    Value := TPIntegerItem( PE )^.Value;
    Data := TPIntegerItem( PE )^.Data;
    RETURN TRUE;
  END ElementAt;

//---------------------------------------------------------------------------

  PUBLIC PROCEDURE CIntegerList.InsertFirst( Value : INTEGER; Data : PTR );
  VAR
    PE : TPIntegerItem;
  BEGIN
    NEW( PE );
    PE^.Value := Value;
    PE^.Data := Data;
    SUPER.InsertFirst( PE );
  END CIntegerList.InsertFirst;

//---------------------------------------------------------------------------

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

//---------------------------------------------------------------------------

  PUBLIC PROCEDURE CIntegerList.Append( Value : INTEGER; Data : PTR );
  BEGIN
    Add( Value, Data );
  END CIntegerList.Append;

//---------------------------------------------------------------------------

  PUBLIC PROCEDURE CIntegerList.GetFirst( OUT Value : INTEGER; OUT Data : PTR ) : BOOLEAN;
  VAR
    PE : TPIntegerItem;
  BEGIN
    IF NOT SUPER.GetFirst( OUT PE ) THEN
      RETURN FALSE;
    END;
    Value := TPIntegerItem( PE )^.Value;
    Data := TPIntegerItem( PE )^.Data;
    RETURN TRUE;
  END CIntegerList.GetFirst;

//---------------------------------------------------------------------------

  PUBLIC PROCEDURE CIntegerList.GetLast( OUT Value : INTEGER; OUT Data : PTR ) : BOOLEAN;
  VAR
    PE : TPIntegerItem;
  BEGIN
    IF NOT SUPER.GetLast( OUT PE ) THEN
      RETURN FALSE;
    END;
    Value := TPIntegerItem( PE )^.Value;
    Data := TPIntegerItem( PE )^.Data;
    RETURN TRUE;
  END CIntegerList.GetLast;

//---------------------------------------------------------------------------

  PUBLIC PROCEDURE CIntegerList.PrevOf( Value : INTEGER; OUT Previous : INTEGER; OUT Data : PTR ): BOOLEAN; // SLOW
  VAR
    i : INTEGER;
    PE : TPIntegerItem;
  BEGIN
    IF NOT Lookup( Value, OUT PE, OUT i ) OR NOT SUPER.PrevOf( PE, OUT PE ) THEN
      RETURN FALSE;
    END;
    Previous := TPIntegerItem( PE )^.Value;
    Data := TPIntegerItem( PE )^.Data;
    RETURN TRUE;
  END CIntegerList.PrevOf;

//---------------------------------------------------------------------------

  PUBLIC PROCEDURE CIntegerList.NextOf( Value : INTEGER; OUT Next : INTEGER; OUT Data : PTR ): BOOLEAN; // SLOW
  VAR
    i : INTEGER;
    PE : TPIntegerItem;
  BEGIN
    IF NOT Lookup( Value, OUT PE, OUT i ) OR NOT SUPER.NextOf( PE, OUT PE ) THEN
      RETURN FALSE;
    END;
    Next := TPIntegerItem( PE )^.Value;
    Data := TPIntegerItem( PE )^.Data;
    RETURN TRUE;
  END CIntegerList.NextOf;

//---------------------------------------------------------------------------

  PUBLIC PROCEDURE CIntegerList.IndexOf( Value : INTEGER ) : INTEGER; // SLOW
  VAR
    Index : INTEGER;
    PE : TPIntegerItem;
  BEGIN
    IF Lookup( Value, OUT PE, OUT Index ) THEN
      RETURN Index;
    ELSE
      RETURN -1;
    END;
  END CIntegerList.IndexOf;

//---------------------------------------------------------------------------

  PRIVATE PROCEDURE CIntegerList.Lookup( Value : INTEGER; OUT Item : list.TPListElem; OUT Index : INTEGER ) : BOOLEAN;
  VAR
    i : INTEGER := 0;
    PE : TPIntegerItem;
    b : BOOLEAN;
  BEGIN
    b := SUPER.GetFirst( OUT PE );
    WHILE b DO
      IF PE^.Value = Value THEN
        Item := PE;
        Index := i;
        RETURN TRUE;
      END;
      b := SUPER.NextOf( PE, OUT PE );
      INC( i );
    END; // WHILE
    RETURN FALSE;
  END CIntegerList.Lookup;

//---------------------------------------------------------------------------

   PUBLIC PROCEDURE Enqueue( Value : INTEGER; Data : PTR );
   BEGIN
      Add( Value, Data );
   END Enqueue;

//---------------------------------------------------------------------------

   PUBLIC PROCEDURE Dequeue( OUT Value : INTEGER; OUT Data : PTR ) : BOOLEAN; 
   BEGIN
      IF NOT GetFirst( OUT Value, OUT Data ) THEN
         RETURN FALSE;
      END;
      SUPER.Delete( PFirst );
      RETURN TRUE;
   END Dequeue;

//---------------------------------------------------------------------------

END CIntegerList;

//===========================================================================

TYPE
  TPPtrItem = POINTER TO CPtrItem;

CLASS CPtrItem( list.CListElem );
  Value : PTR;
  Data  : PTR;
END CPtrItem;

CLASS IMPLEMENTATION CPtrItem;
BEGIN
  Value := 0;
  Data := 0;
END CPtrItem;

//---------------------------------------------------------------------------

CLASS IMPLEMENTATION CPtrList;

//---------------------------------------------------------------------------

  PUBLIC READONLY PROPERTY CPtrList.Current GET : PTR;
  BEGIN
    IF _Current = -1 THEN
      RETURN 0;
    ELSE
      RETURN TPPtrItem( _Current )^.Value;
    END;
  END CPtrList.Current;

//---------------------------------------------------------------------------

  PUBLIC READONLY PROPERTY CPtrList.CurrentData GET : PTR;
  BEGIN
    IF _Current = -1 THEN
      RETURN NIL;
    ELSE
      RETURN TPPtrItem( _Current )^.Data;
    END;
  END CPtrList.CurrentData;

//---------------------------------------------------------------------------

  PUBLIC PROPERTY CPtrList.CurrentData SET( Value : PTR );
  BEGIN
    IF _Current = -1 THEN
      RETURN;
    ELSE
      TPIntegerItem( _Current )^.Data := Value;
    END;
  END CPtrList.CurrentData;

//---------------------------------------------------------------------------

  PUBLIC READONLY INDEX CPtrList GET( Index : INTEGER ) : PTR;
  VAR
    PE : TPPtrItem;
  BEGIN
    PE := TPPtrItem( SUPER[Index] );
    IF PE = NIL THEN
      RETURN -1;
    ELSE
      RETURN TPPtrItem( PE )^.Value;
    END;
  END CPtrList;

//---------------------------------------------------------------------------

  PUBLIC PROCEDURE CPtrList.Add( Value : PTR; Data : PTR );
  VAR
    PE : TPPtrItem;
  BEGIN
    NEW( PE );
    PE^.Value := Value;
    PE^.Data := Data;
    SUPER.Append( PE );
  END CPtrList.Add;

//---------------------------------------------------------------------------

  PUBLIC PROCEDURE CPtrList.Contains( Value : PTR ): BOOLEAN;
  VAR
    i : INTEGER;
    PE : TPPtrItem;
  BEGIN
    RETURN Lookup( Value, OUT PE, OUT i );
  END CPtrList.Contains;

//---------------------------------------------------------------------------

  PUBLIC PROCEDURE CPtrList.Get( Value : PTR; OUT Data : PTR ): BOOLEAN;
  VAR
    i : INTEGER;
    PE : TPPtrItem;
  BEGIN
    IF NOT Lookup( Value, OUT PE, OUT i ) THEN
      RETURN FALSE;
    END;
    Data := PE^.Data;
    RETURN TRUE;
  END CPtrList.Get;

//---------------------------------------------------------------------------

  PUBLIC PROCEDURE CPtrList.Remove( Value : PTR ); // removes all occurences
  VAR
    PE, PN : TPPtrItem;
    b : BOOLEAN;
  BEGIN
    b := SUPER.GetFirst( OUT PE );
    WHILE b DO
      b := SUPER.NextOf( PE, OUT PN );
      IF PE^.Value = Value THEN 
        Delete( PE );
      END;
      PE := PN;
    END; // WHILE
  END CPtrList.Remove;

//---------------------------------------------------------------------------

  PUBLIC PROCEDURE ElementAt( Index : INTEGER; OUT Value : PTR; OUT Data : PTR ) : BOOLEAN; // similar as []
  VAR
    PE : TPPtrItem;
  BEGIN
    PE := TPPtrItem( SUPER[Index] );
    IF PE = NIL THEN
      RETURN FALSE;
    END;
    Value := TPPtrItem( PE )^.Value;
    Data := TPPtrItem( PE )^.Data;
    RETURN TRUE;
  END ElementAt;

//---------------------------------------------------------------------------

  PUBLIC PROCEDURE CPtrList.InsertFirst( Value : PTR; Data : PTR );
  VAR
    PE : TPPtrItem;
  BEGIN
    NEW( PE );
    PE^.Value := Value;
    PE^.Data := Data;
    SUPER.InsertFirst( PE );
  END CPtrList.InsertFirst;

//---------------------------------------------------------------------------

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

//---------------------------------------------------------------------------

  PUBLIC PROCEDURE CPtrList.Append( Value : PTR; Data : PTR );
  BEGIN
    Add( Value, Data );
  END CPtrList.Append;

//---------------------------------------------------------------------------

  PUBLIC PROCEDURE CPtrList.GetFirst( OUT Value : PTR; OUT Data : PTR ) : BOOLEAN;
  VAR
    PE : TPPtrItem;
  BEGIN
    IF NOT SUPER.GetFirst( OUT PE ) THEN
      RETURN FALSE;
    END;
    Value := TPPtrItem( PE )^.Value;
    Data := TPPtrItem( PE )^.Data;
    RETURN TRUE;
  END CPtrList.GetFirst;

//---------------------------------------------------------------------------

  PUBLIC PROCEDURE CPtrList.GetLast( OUT Value : PTR; OUT Data : PTR ) : BOOLEAN;
  VAR
    PE : TPPtrItem;
  BEGIN
    IF NOT SUPER.GetLast( OUT PE ) THEN
      RETURN FALSE;
    END;
    Value := TPPtrItem( PE )^.Value;
    Data := TPPtrItem( PE )^.Data;
    RETURN TRUE;
  END CPtrList.GetLast;

//---------------------------------------------------------------------------

  PUBLIC PROCEDURE CPtrList.PrevOf( Value : PTR; OUT Previous : PTR; OUT Data : PTR ): BOOLEAN; // SLOW
  VAR
    i : INTEGER;
    PE : TPPtrItem;
  BEGIN
    IF NOT Lookup( Value, OUT PE, OUT i ) OR NOT SUPER.PrevOf( PE, OUT PE ) THEN
      RETURN FALSE;
    END;
    Previous := TPPtrItem( PE )^.Value;
    Data := TPPtrItem( PE )^.Data;
    RETURN TRUE;
  END CPtrList.PrevOf;

//---------------------------------------------------------------------------

  PUBLIC PROCEDURE CPtrList.NextOf( Value : PTR; OUT Next : PTR; OUT Data : PTR ): BOOLEAN; // SLOW
  VAR
    i : INTEGER;
    PE : TPPtrItem;
  BEGIN
    IF NOT Lookup( Value, OUT PE, OUT i ) OR NOT SUPER.NextOf( PE, OUT PE ) THEN
      RETURN FALSE;
    END;
    Next := TPPtrItem( PE )^.Value;
    Data := TPPtrItem( PE )^.Data;
    RETURN TRUE;
  END CPtrList.NextOf;

//---------------------------------------------------------------------------

  PUBLIC PROCEDURE CPtrList.IndexOf( Value : PTR ) : INTEGER; // SLOW
  VAR
    Index : INTEGER;
    PE : TPPtrItem;
  BEGIN
    IF Lookup( Value, OUT PE, OUT Index ) THEN
      RETURN Index;
    ELSE
      RETURN -1;
    END;
  END CPtrList.IndexOf;

//---------------------------------------------------------------------------

  PRIVATE PROCEDURE CPtrList.Lookup( Value : PTR; OUT Item : list.TPListElem; OUT Index : INTEGER ) : BOOLEAN;
  VAR
    i : INTEGER := 0;
    PE : TPPtrItem;
    b : BOOLEAN;
  BEGIN
    b := SUPER.GetFirst( OUT PE );
    WHILE b DO
      IF PE^.Value = Value THEN
        Item := PE;
        Index := i;
        RETURN TRUE;
      END;
      b := SUPER.NextOf( PE, OUT PE );
      INC( i );
    END; // WHILE
    RETURN FALSE;
  END CPtrList.Lookup;

//---------------------------------------------------------------------------

   PUBLIC PROCEDURE Enqueue( Value : PTR; Data : PTR );
   BEGIN
      Add( Value, Data );
   END Enqueue;

//---------------------------------------------------------------------------

   PUBLIC PROCEDURE Dequeue( OUT Value : PTR; OUT Data : PTR ) : BOOLEAN; 
   BEGIN
      IF NOT GetFirst( OUT Value, OUT Data ) THEN
         RETURN FALSE;
      END;
      SUPER.Delete( PFirst );
      RETURN TRUE;
   END Dequeue;

//---------------------------------------------------------------------------

END CPtrList;

//===========================================================================

TYPE
  TPStringItem = POINTER TO CStringItem;

CLASS CStringItem( list.CListElem );
  Value : CString;
  Data  : PTR;
END CStringItem;

CLASS IMPLEMENTATION CStringItem;
BEGIN
  Data := 0;
END CStringItem;

//---------------------------------------------------------------------------

CLASS IMPLEMENTATION CStringList;

//---------------------------------------------------------------------------

  PUBLIC READONLY PROPERTY CStringList.Current GET : POINTER TO IString;
  BEGIN
    IF _Current = -1 THEN
      RETURN NIL;
    ELSE
      RETURN ADR( TPStringItem( _Current )^.Value );
    END;
  END CStringList.Current;

//---------------------------------------------------------------------------

  PUBLIC READONLY PROPERTY CStringList.CurrentData GET : PTR;
  BEGIN
    IF _Current = -1 THEN
      RETURN NIL;
    ELSE
      RETURN TPStringItem( _Current )^.Data;
    END;
  END CStringList.CurrentData;

//---------------------------------------------------------------------------

  PUBLIC PROPERTY CStringList.CurrentData SET( Value : PTR );
  BEGIN
    IF _Current = -1 THEN
      RETURN;
    ELSE
      TPStringItem( _Current )^.Data := Value;
    END;
  END CStringList.CurrentData;

//---------------------------------------------------------------------------

  PUBLIC READONLY INDEX CStringList GET( Index : INTEGER ) : POINTER TO IString;
  VAR
    PE : TPStringItem;
  BEGIN
    PE := TPStringItem( SUPER[Index] );
    IF PE = NIL THEN
      RETURN NIL;
    ELSE
      RETURN ADR( TPStringItem( PE )^.Value );
    END;
  END CStringList;

//---------------------------------------------------------------------------

  PUBLIC PROCEDURE CStringList.Add( CONST Value : IString; Data : PTR );
  VAR
    PE : TPStringItem;
  BEGIN
    NEW( PE );
    PE^.Value.Assign( Value );
    PE^.Data := Data;
    SUPER.Append( PE );
  END CStringList.Add;

//---------------------------------------------------------------------------

  PUBLIC PROCEDURE CStringList.Contains( CONST Value : IString ): BOOLEAN;
  VAR
    i : INTEGER;
    PE : TPStringItem;
  BEGIN
    RETURN Lookup( Value, OUT PE, OUT i );
  END CStringList.Contains;

//---------------------------------------------------------------------------

  PUBLIC PROCEDURE CStringList.Get( CONST Value : IString; OUT Data : PTR ): BOOLEAN;
  VAR
    i : INTEGER;
    PE : TPStringItem;
  BEGIN
    IF NOT Lookup( Value, OUT PE, OUT i ) THEN
      RETURN FALSE;
    END;
    Data := PE^.Data;
    RETURN TRUE;
  END CStringList.Get;

//---------------------------------------------------------------------------

  PUBLIC PROCEDURE CStringList.Remove( CONST Value : IString ); // removes all occurences
  VAR
    PE, PN : TPStringItem;
    b : BOOLEAN;
  BEGIN
    b := SUPER.GetFirst( OUT PE );
    WHILE b DO
      b := SUPER.NextOf( PE, OUT PN );
      IF PE^.Value = Value THEN 
        Delete( PE );
      END;
      PE := PN;
    END; // WHILE
  END CStringList.Remove;

//---------------------------------------------------------------------------

  PUBLIC PROCEDURE ElementAt( Index : INTEGER; OUT Value : IString; OUT Data : PTR ) : BOOLEAN; // similar as []
  VAR
    PE : TPStringItem;
  BEGIN
    PE := TPStringItem( SUPER[Index] );
    IF PE = NIL THEN
      RETURN FALSE;
    END;
    Value.Assign( TPStringItem( PE )^.Value );
    Data := TPStringItem( PE )^.Data;
    RETURN TRUE;
  END ElementAt;

//---------------------------------------------------------------------------

  PUBLIC PROCEDURE CStringList.AddOA( CONST Value : ARRAY OF WCHAR; Data : PTR );
  VAR
    PE : TPStringItem;
  BEGIN
    NEW( PE );
    PE^.Value.FromOA( Value );
    PE^.Data := Data;
    SUPER.Append( PE );
  END CStringList.AddOA;

//---------------------------------------------------------------------------

  PUBLIC PROCEDURE CStringList.ContainsOA( CONST Value : ARRAY OF WCHAR ): BOOLEAN;
  VAR
    i : INTEGER;
    PE : TPStringItem;
    S : CString;
  BEGIN
    S.FromOA( Value );
    RETURN Lookup( S, OUT PE, OUT i );
  END CStringList.ContainsOA;

//---------------------------------------------------------------------------

  PUBLIC PROCEDURE CStringList.GetOA( CONST Value : ARRAY OF WCHAR; OUT Data : PTR ): BOOLEAN;
  VAR
    i : INTEGER;
    PE : TPStringItem;
    S : CString;
  BEGIN
    S.FromOA( Value );
    IF NOT Lookup( S, OUT PE, OUT i ) THEN
      RETURN FALSE;
    END;
    Data := PE^.Data;
    RETURN TRUE;
  END CStringList.GetOA;

//---------------------------------------------------------------------------

  PUBLIC PROCEDURE CStringList.RemoveOA( CONST Value : ARRAY OF WCHAR ); // removes all occurences
  VAR
    PE, PN : TPStringItem;
    S : CString;
    b : BOOLEAN;
  BEGIN
    S.FromOA( Value );
    b := SUPER.GetFirst( OUT PE );
    WHILE b DO
      b := SUPER.NextOf( PE, OUT PN );
      IF PE^.Value = S THEN 
        Delete( PE );
      END;
      PE := PN;
    END; // WHILE
  END CStringList.RemoveOA;

//---------------------------------------------------------------------------

  PUBLIC PROCEDURE CStringList.InsertFirst( CONST Value : IString; Data : PTR );
  VAR
    PE : TPStringItem;
  BEGIN
    NEW( PE );
    PE^.Value.Assign( Value );
    PE^.Data := Data;
    SUPER.InsertFirst( PE );
  END CStringList.InsertFirst;

//---------------------------------------------------------------------------

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

//---------------------------------------------------------------------------

  PUBLIC PROCEDURE CStringList.Append( CONST Value : IString; Data : PTR );
  BEGIN
    Add( Value, Data );
  END CStringList.Append;

//---------------------------------------------------------------------------

  PUBLIC PROCEDURE CStringList.GetFirst( OUT Value : IString; OUT Data : PTR ) : BOOLEAN;
  VAR
    PE : TPStringItem;
  BEGIN
    IF NOT SUPER.GetFirst( OUT PE ) THEN
      RETURN FALSE;
    END;
    Value.Assign( TPStringItem( PE )^.Value );
    Data := TPStringItem( PE )^.Data;
    RETURN TRUE;
  END CStringList.GetFirst;

//---------------------------------------------------------------------------

  PUBLIC PROCEDURE CStringList.GetLast( OUT Value : IString; OUT Data : PTR ) : BOOLEAN;
  VAR
    PE : TPStringItem;
  BEGIN
    IF NOT SUPER.GetLast( OUT PE ) THEN
      RETURN FALSE;
    END;
    Value.Assign( TPStringItem( PE )^.Value );
    Data := TPStringItem( PE )^.Data;
    RETURN TRUE;
  END CStringList.GetLast;

//---------------------------------------------------------------------------

  PUBLIC PROCEDURE CStringList.PrevOf( CONST Value : IString; OUT Previous : IString; OUT Data : PTR ): BOOLEAN; // SLOW
  VAR
    i : INTEGER;
    PE : TPStringItem;
  BEGIN
    IF NOT Lookup( Value, OUT PE, OUT i ) OR NOT SUPER.PrevOf( PE, OUT PE ) THEN
      RETURN FALSE;
    END;
    Previous.Assign( TPStringItem( PE )^.Value );
    Data := TPStringItem( PE )^.Data;
    RETURN TRUE;
  END CStringList.PrevOf;

//---------------------------------------------------------------------------

  PUBLIC PROCEDURE CStringList.NextOf( CONST Value : IString; OUT Next : IString; OUT Data : PTR ): BOOLEAN; // SLOW
  VAR
    i : INTEGER;
    PE : TPStringItem;
  BEGIN
    IF NOT Lookup( Value, OUT PE, OUT i ) OR NOT SUPER.NextOf( PE, OUT PE ) THEN
      RETURN FALSE;
    END;
    Next.Assign( TPStringItem( PE )^.Value );
    Data := TPStringItem( PE )^.Data;
    RETURN TRUE;
  END CStringList.NextOf;

//---------------------------------------------------------------------------

  PUBLIC PROCEDURE CStringList.IndexOf( CONST Value : IString ) : INTEGER; // SLOW
  VAR
    Index : INTEGER;
    PE : TPStringItem;
  BEGIN
    IF Lookup( Value, OUT PE, OUT Index ) THEN
      RETURN Index;
    ELSE
      RETURN -1;
    END;
  END CStringList.IndexOf;

//---------------------------------------------------------------------------

  PRIVATE PROCEDURE CStringList.Lookup( CONST Value : IString; OUT Item : list.TPListElem; OUT Index : INTEGER ) : BOOLEAN;
  VAR
    i : INTEGER := 0;
    PE : TPStringItem;
    b : BOOLEAN;
  BEGIN
    b := SUPER.GetFirst( OUT PE );
    WHILE b DO
      IF PE^.Value = Value THEN
        Item := PE;
        Index := i;
        RETURN TRUE;
      END;
      b := SUPER.NextOf( PE, OUT PE );
      INC( i );
    END; // WHILE
    RETURN FALSE;
  END CStringList.Lookup;

//---------------------------------------------------------------------------

   PUBLIC PROCEDURE Enqueue( CONST Value : IString; Data : PTR );
   BEGIN
      Add( Value, Data );
   END Enqueue;

//---------------------------------------------------------------------------

   PUBLIC PROCEDURE EnqueueOA( CONST Value : ARRAY OF WCHAR; Data : PTR );
   BEGIN
      AddOA( Value, Data );
   END EnqueueOA;

//---------------------------------------------------------------------------

   PUBLIC PROCEDURE Dequeue( OUT Value : IString; OUT Data : PTR ) : BOOLEAN; 
   VAR
      PE : TPStringItem;
   BEGIN
      IF NOT SUPER.GetFirst( OUT PE ) THEN
         RETURN FALSE;
      END;
      Value.Assign( PE^.Value );
      Data := PE^.Data;
      SUPER.Delete( PE );
      RETURN TRUE;
   END Dequeue;

//---------------------------------------------------------------------------

   PUBLIC PROCEDURE DequeueOA( OUT Value : ARRAY OF WCHAR; OUT Data : PTR ) : BOOLEAN; 
   VAR
      PE : TPStringItem;
   BEGIN
      IF NOT SUPER.GetFirst( OUT PE ) THEN
         RETURN FALSE;
      END;
      PE^.Value.ToOA( OUT Value );
      Data := PE^.Data;
      SUPER.Delete( PE );
      RETURN TRUE;
   END DequeueOA;

//---------------------------------------------------------------------------

END CStringList;

//===========================================================================

TYPE
  TPStringStringItem = POINTER TO CStringStringItem;

CLASS CStringStringItem( list.CListElem );
  Value : CString;
  Data  : CString;
END CStringStringItem;

CLASS IMPLEMENTATION CStringStringItem;
END CStringStringItem;

//---------------------------------------------------------------------------

CLASS IMPLEMENTATION CStringStringList;

//---------------------------------------------------------------------------

  PUBLIC READONLY PROPERTY CStringStringList.Current GET : POINTER TO IString;
  BEGIN
    IF _Current = -1 THEN
      RETURN NIL;
    ELSE
      RETURN ADR( TPStringStringItem( _Current )^.Value );
    END;
  END CStringStringList.Current;

//---------------------------------------------------------------------------

  PUBLIC READONLY PROPERTY CStringStringList.CurrentData GET : POINTER TO IString;
  BEGIN
    IF _Current = -1 THEN
      RETURN NIL;
    ELSE
      RETURN ADR( TPStringStringItem( _Current )^.Data );
    END;
  END CStringStringList.CurrentData;

//---------------------------------------------------------------------------

  PUBLIC PROPERTY CStringStringList.CurrentData SET( Value : POINTER TO IString );
  BEGIN
    IF _Current = -1 THEN
      RETURN;
    ELSE
      TPStringStringItem( _Current )^.Data.Assign( Value^ );
    END;
  END CStringStringList.CurrentData;

//---------------------------------------------------------------------------

  PUBLIC READONLY INDEX CStringStringList GET( Index : INTEGER ) : POINTER TO IString;
  VAR
    PE : TPStringStringItem;
  BEGIN
    PE := TPStringStringItem( SUPER[Index] );
    IF PE = NIL THEN
      RETURN NIL;
    ELSE
      RETURN ADR( TPStringStringItem( PE )^.Value );
    END;
  END CStringStringList;

//---------------------------------------------------------------------------

  PUBLIC PROCEDURE CStringStringList.Add( CONST Value : IString; CONST Data : IString );
  VAR
    PE : TPStringStringItem;
  BEGIN
    NEW( PE );
    PE^.Value.Assign( Value );
    PE^.Data.Assign( Data );
    SUPER.Append( PE );
  END CStringStringList.Add;

//---------------------------------------------------------------------------

  PUBLIC PROCEDURE CStringStringList.Contains( CONST Value : IString ): BOOLEAN;
  VAR
    i : INTEGER;
    PE : TPStringStringItem;
  BEGIN
    RETURN Lookup( Value, OUT PE, OUT i );
  END CStringStringList.Contains;

//---------------------------------------------------------------------------

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

//---------------------------------------------------------------------------

  PUBLIC PROCEDURE CStringStringList.Remove( CONST Value : IString ); // removes all occurences
  VAR
    PE, PN : TPStringStringItem;
    b : BOOLEAN;
  BEGIN
    b := SUPER.GetFirst( OUT PE );
    WHILE b DO
      b := SUPER.NextOf( PE, OUT PN );
      IF PE^.Value.Equals( Value ) THEN 
        Delete( PE );
      END;
      PE := PN;
    END; // WHILE
  END CStringStringList.Remove;

//---------------------------------------------------------------------------

  PUBLIC PROCEDURE ElementAt( Index : INTEGER; OUT Value : IString; OUT Data : IString ) : BOOLEAN; // similar as []
  VAR
    PE : TPStringStringItem;
  BEGIN
    PE := TPStringStringItem( SUPER[Index] );
    IF PE = NIL THEN
      RETURN FALSE;
    END;
    Value.Assign( TPStringStringItem( PE )^.Value );
    Data.Assign( TPStringStringItem( PE )^.Data );
    RETURN TRUE;
  END ElementAt;

//---------------------------------------------------------------------------

  PUBLIC PROCEDURE CStringStringList.AddOA( CONST Value : ARRAY OF WCHAR; CONST Data : IString );
  VAR
    PE : TPStringStringItem;
  BEGIN
    NEW( PE );
    PE^.Value.FromOA( Value );
    PE^.Data.Assign( Data );
    SUPER.Append( PE );
  END CStringStringList.AddOA;

//---------------------------------------------------------------------------

  PUBLIC PROCEDURE CStringStringList.ContainsOA( CONST Value : ARRAY OF WCHAR ): BOOLEAN;
  VAR
    i : INTEGER;
    PE : TPStringStringItem;
    S : CString;
  BEGIN
    S.FromOA( Value );
    RETURN Lookup( S, OUT PE, OUT i );
  END CStringStringList.ContainsOA;

//---------------------------------------------------------------------------

  PUBLIC PROCEDURE CStringStringList.GetOA( CONST Value : ARRAY OF WCHAR; OUT Data : IString ): BOOLEAN;
  VAR
    i : INTEGER;
    PE : TPStringStringItem;
    S : CString;
  BEGIN
    S.FromOA( Value );
    IF NOT Lookup( S, OUT PE, OUT i ) THEN
      RETURN FALSE;
    END;
    Data.Assign( PE^.Data );
    RETURN TRUE;
  END CStringStringList.GetOA;

//---------------------------------------------------------------------------

  PUBLIC PROCEDURE CStringStringList.RemoveOA( CONST Value : ARRAY OF WCHAR ); // removes all occurences
  VAR
    PE, PN : TPStringStringItem;
    S : CString;
    b : BOOLEAN;
  BEGIN
    S.FromOA( Value );
    b := SUPER.GetFirst( OUT PE );
    WHILE b DO
      b := SUPER.NextOf( PE, OUT PN );
      IF PE^.Value.Equals( S ) THEN 
        Delete( PE );
      END;
      PE := PN;
    END; // WHILE
  END CStringStringList.RemoveOA;

//---------------------------------------------------------------------------

  PUBLIC PROCEDURE CStringStringList.InsertFirst( CONST Value : IString; CONST Data : IString );
  VAR
    PE : TPStringStringItem;
  BEGIN
    NEW( PE );
    PE^.Value.Assign( Value );
    PE^.Data.Assign( Data );
    SUPER.InsertFirst( PE );
  END CStringStringList.InsertFirst;

//---------------------------------------------------------------------------

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

//---------------------------------------------------------------------------

  PUBLIC PROCEDURE CStringStringList.Append( CONST Value : IString; CONST Data : IString );
  BEGIN
    Add( Value, Data );
  END CStringStringList.Append;

//---------------------------------------------------------------------------

  PUBLIC PROCEDURE CStringStringList.GetFirst( OUT Value : IString; OUT Data : IString ) : BOOLEAN;
  VAR
    PE : TPStringStringItem;
  BEGIN
    IF NOT SUPER.GetFirst( OUT PE ) THEN
      RETURN FALSE;
    END;
    Value.Assign( TPStringStringItem( PE )^.Value );
    Data.Assign( TPStringStringItem( PE )^.Data );
    RETURN TRUE;
  END CStringStringList.GetFirst;

//---------------------------------------------------------------------------

  PUBLIC PROCEDURE CStringStringList.GetLast( OUT Value : IString; OUT Data : IString ) : BOOLEAN;
  VAR
    PE : TPStringStringItem;
  BEGIN
    IF NOT SUPER.GetLast( OUT PE ) THEN
      RETURN FALSE;
    END;
    Value.Assign( TPStringStringItem( PE )^.Value );
    Data.Assign( TPStringStringItem( PE )^.Data );
    RETURN TRUE;
  END CStringStringList.GetLast;

//---------------------------------------------------------------------------

  PUBLIC PROCEDURE CStringStringList.PrevOf( CONST Value : IString; OUT Previous : IString; OUT Data : IString ): BOOLEAN; // SLOW
  VAR
    i : INTEGER;
    PE : TPStringStringItem;
  BEGIN
    IF NOT Lookup( Value, OUT PE, OUT i ) OR NOT SUPER.PrevOf( PE, OUT PE ) THEN
      RETURN FALSE;
    END;
    Previous.Assign( TPStringStringItem( PE )^.Value );
    Data.Assign( TPStringStringItem( PE )^.Data );
    RETURN TRUE;
  END CStringStringList.PrevOf;

//---------------------------------------------------------------------------

  PUBLIC PROCEDURE CStringStringList.NextOf( CONST Value : IString; OUT Next : IString; OUT Data : IString ): BOOLEAN; // SLOW
  VAR
    i : INTEGER;
    PE : TPStringStringItem;
  BEGIN
    IF NOT Lookup( Value, OUT PE, OUT i ) OR NOT SUPER.NextOf( PE, OUT PE ) THEN
      RETURN FALSE;
    END;
    Next.Assign( TPStringStringItem( PE )^.Value );
    Data.Assign( TPStringStringItem( PE )^.Data );
    RETURN TRUE;
  END CStringStringList.NextOf;

//---------------------------------------------------------------------------

  PUBLIC PROCEDURE CStringStringList.IndexOf( CONST Value : IString ) : INTEGER; // SLOW
  VAR
    Index : INTEGER;
    PE : TPStringStringItem;
  BEGIN
    IF Lookup( Value, OUT PE, OUT Index ) THEN
      RETURN Index;
    ELSE
      RETURN -1;
    END;
  END CStringStringList.IndexOf;

//---------------------------------------------------------------------------

  PRIVATE PROCEDURE CStringStringList.Lookup( CONST Value : IString; OUT Item : list.TPListElem; OUT Index : INTEGER ) : BOOLEAN;
  VAR
    i : INTEGER := 0;
    PE : TPStringStringItem;
    b : BOOLEAN;
  BEGIN
    b := SUPER.GetFirst( OUT PE );
    WHILE b DO
      IF PE^.Value = Value THEN
        Item := PE;
        Index := i;
        RETURN TRUE;
      END;
      b := SUPER.NextOf( PE, OUT PE );
      INC( i );
    END; // WHILE
    RETURN FALSE;
  END CStringStringList.Lookup;

//---------------------------------------------------------------------------

   PUBLIC PROCEDURE Enqueue( CONST Value : IString; CONST Data : IString );
   BEGIN
      Add( Value, Data );
   END Enqueue;

//---------------------------------------------------------------------------

   PUBLIC PROCEDURE EnqueueOA( CONST Value : ARRAY OF WCHAR; CONST Data : IString );
   BEGIN
      AddOA( Value, Data );
   END EnqueueOA;

//---------------------------------------------------------------------------

   PUBLIC PROCEDURE Dequeue( OUT Value : IString; OUT Data : IString ) : BOOLEAN; 
   VAR
      PE : TPStringStringItem;
   BEGIN
      IF NOT SUPER.GetFirst( OUT PE ) THEN
         RETURN FALSE;
      END;
      Value.Assign( PE^.Value );
      Data.Assign( PE^.Data );
      SUPER.Delete( PE );
      RETURN TRUE;
   END Dequeue;

//---------------------------------------------------------------------------

   PUBLIC PROCEDURE DequeueOA( OUT Value : ARRAY OF WCHAR; OUT Data : IString ) : BOOLEAN; 
   VAR
      PE : TPStringStringItem;
   BEGIN
      IF NOT SUPER.GetFirst( OUT PE ) THEN
         RETURN FALSE;
      END;
      PE^.Value.ToOA( OUT Value );
      Data.Assign( PE^.Data );
      SUPER.Delete( PE );
      RETURN TRUE;
   END DequeueOA;

//---------------------------------------------------------------------------

END CStringStringList;

//===========================================================================

TYPE
  TPBufferItem = POINTER TO ABufferItem;
  TPDynamicItem = POINTER TO CDynamicItem;
  TPSlotItem32 = POINTER TO CSlotItem32;
  TPSlotItem64 = POINTER TO CSlotItem64;
  TPSlotItem256 = POINTER TO CSlotItem256;
  
ABSTRACT CLASS ABufferItem( list.CListElem );
   LOCAL VAR
      Data : PTR;
   LOCAL ABSTRACT READONLY PROPERTY
      Value : POINTER TO AMemoryBuffer;
END ABufferItem;

CLASS IMPLEMENTATION ABufferItem;
BEGIN
   Data := 0;
END ABufferItem;

//---------------------------------------------------------------------------

CLASS CDynamicItem( ABufferItem );
   PRIVATE VAR
      _Value : CMemoryBuffer;
   LOCAL VIRTUAL READONLY PROPERTY
      Value : POINTER TO AMemoryBuffer;
END CDynamicItem;

CLASS IMPLEMENTATION CDynamicItem;
   LOCAL PROPERTY Value GET : POINTER TO AMemoryBuffer;
   BEGIN
      RETURN ADR( _Value );
   END Value;
END CDynamicItem;

//---------------------------------------------------------------------------

CLASS CSlotItem32( ABufferItem );
   PRIVATE VAR
      _Value : CMemorySlot32;
   LOCAL VIRTUAL READONLY PROPERTY
      Value : POINTER TO AMemoryBuffer;
END CSlotItem32;

CLASS IMPLEMENTATION CSlotItem32;
   LOCAL PROPERTY Value GET : POINTER TO AMemoryBuffer;
   BEGIN
      RETURN ADR( _Value );
   END Value;
END CSlotItem32;

//---------------------------------------------------------------------------

CLASS CSlotItem64( ABufferItem );
   PRIVATE VAR
      _Value : CMemorySlot64;
   LOCAL VIRTUAL READONLY PROPERTY
      Value : POINTER TO AMemoryBuffer;
END CSlotItem64;

CLASS IMPLEMENTATION CSlotItem64;
   LOCAL PROPERTY Value GET : POINTER TO AMemoryBuffer;
   BEGIN
      RETURN ADR( _Value );
   END Value;
END CSlotItem64;

//---------------------------------------------------------------------------

CLASS CSlotItem256( ABufferItem );
   PRIVATE VAR
      _Value : CMemorySlot256;
   LOCAL VIRTUAL READONLY PROPERTY
      Value : POINTER TO AMemoryBuffer;
END CSlotItem256;

CLASS IMPLEMENTATION CSlotItem256;
   LOCAL PROPERTY Value GET : POINTER TO AMemoryBuffer;
   BEGIN
      RETURN ADR( _Value );
   END Value;
END CSlotItem256;

//===========================================================================

CLASS IMPLEMENTATION CBufferList;

//---------------------------------------------------------------------------

  PUBLIC READONLY PROPERTY CBufferList.Current GET : POINTER TO AMemoryBuffer;
  BEGIN
    IF _Current = -1 THEN
      RETURN NIL;
    ELSE
      RETURN TPBufferItem( _Current )^.Value;
    END;
  END CBufferList.Current;

//---------------------------------------------------------------------------

  PUBLIC READONLY PROPERTY CBufferList.CurrentData GET : PTR;
  BEGIN
    IF _Current = -1 THEN
      RETURN NIL;
    ELSE
      RETURN TPBufferItem( _Current )^.Data;
    END;
  END CBufferList.CurrentData;

//---------------------------------------------------------------------------

  PUBLIC PROPERTY CBufferList.CurrentData SET( Value : PTR );
  BEGIN
    IF _Current = -1 THEN
      RETURN;
    ELSE
      TPBufferItem( _Current )^.Data := Value;
    END;
  END CBufferList.CurrentData;

//---------------------------------------------------------------------------

  PUBLIC READONLY INDEX CBufferList GET( Index : INTEGER ) : POINTER TO AMemoryBuffer;
  VAR
    PE : TPBufferItem;
  BEGIN
    PE := TPBufferItem( SUPER[Index] );
    IF PE = NIL THEN
      RETURN NIL;
    ELSE
      RETURN TPBufferItem( PE )^.Value;
    END;
  END CBufferList;

//---------------------------------------------------------------------------

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
    PE^.Value^.Assign( Value );
    PE^.Data := Data;
    SUPER.Append( PE );
  END CBufferList.Add;

//---------------------------------------------------------------------------

  PUBLIC PROCEDURE CBufferList.Contains( CONST Value : AMemoryBuffer ): BOOLEAN;
  VAR
    i : INTEGER;
    PE : TPBufferItem;
  BEGIN
    RETURN Lookup( Value, OUT PE, OUT i );
  END CBufferList.Contains;

//---------------------------------------------------------------------------

  PUBLIC PROCEDURE CBufferList.Get( CONST Value : AMemoryBuffer; OUT Data : PTR ): BOOLEAN;
  VAR
    i : INTEGER;
    PE : TPBufferItem;
  BEGIN
    IF NOT Lookup( Value, OUT PE, OUT i ) THEN
      RETURN FALSE;
    END;
    Data := PE^.Data;
    RETURN TRUE;
  END CBufferList.Get;

//---------------------------------------------------------------------------

  PUBLIC PROCEDURE CBufferList.Remove( CONST Value : AMemoryBuffer ); // removes all occurences
  VAR
    PE, PN : TPBufferItem;
    b : BOOLEAN;
  BEGIN
    b := SUPER.GetFirst( OUT PE );
    WHILE b DO
      b := SUPER.NextOf( PE, OUT PN );
      IF PE^.Value^ = Value THEN 
        Delete( PE );
      END;
      PE := PN;
    END; // WHILE
  END CBufferList.Remove;

//---------------------------------------------------------------------------

  PUBLIC PROCEDURE ElementAt( Index : INTEGER; OUT Value : AMemoryBuffer; OUT Data : PTR ) : BOOLEAN; // similar as []
  VAR
    PE : TPBufferItem;
  BEGIN
    PE := TPBufferItem( SUPER[Index] );
    IF PE = NIL THEN
      RETURN FALSE;
    END;
    Value.Assign( TPBufferItem( PE )^.Value^ );
    Data := TPBufferItem( PE )^.Data;
    RETURN TRUE;
  END ElementAt;

//---------------------------------------------------------------------------

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
    SUPER.Append( PE );
  END CBufferList.AddOA;

//---------------------------------------------------------------------------

  PUBLIC PROCEDURE CBufferList.ContainsOA( CONST Value : ARRAY OF BYTE ): BOOLEAN;
  VAR
    i : INTEGER;
    PE : TPBufferItem;
    S : CMemoryBuffer;
  BEGIN
    S.FromOA( Value, TRUE );
    RETURN Lookup( S, OUT PE, OUT i );
  END CBufferList.ContainsOA;

//---------------------------------------------------------------------------

  PUBLIC PROCEDURE CBufferList.GetOA( CONST Value : ARRAY OF BYTE; OUT Data : PTR ): BOOLEAN;
  VAR
    i : INTEGER;
    PE : TPBufferItem;
    S : CMemoryBuffer;
  BEGIN
    S.FromOA( Value, TRUE );
    IF NOT Lookup( S, OUT PE, OUT i ) THEN
      RETURN FALSE;
    END;
    Data := PE^.Data;
    RETURN TRUE;
  END CBufferList.GetOA;

//---------------------------------------------------------------------------

  PUBLIC PROCEDURE CBufferList.RemoveOA( CONST Value : ARRAY OF BYTE ); // removes all occurences
  VAR
    PE, PN : TPBufferItem;
    S : CMemoryBuffer;
    b : BOOLEAN;
  BEGIN
    S.FromOA( Value, TRUE );
    b := SUPER.GetFirst( OUT PE );
    WHILE b DO
      b := SUPER.NextOf( PE, OUT PN );
      IF PE^.Value^ = S THEN 
        Delete( PE );
      END;
      PE := PN;
    END; // WHILE
  END CBufferList.RemoveOA;

//---------------------------------------------------------------------------

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

//---------------------------------------------------------------------------

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

//---------------------------------------------------------------------------

  PUBLIC PROCEDURE CBufferList.Append( CONST Value : AMemoryBuffer; Data : PTR );
  BEGIN
    Add( Value, Data );
  END CBufferList.Append;

//---------------------------------------------------------------------------

  PUBLIC PROCEDURE CBufferList.GetFirst( OUT Value : AMemoryBuffer; OUT Data : PTR ) : BOOLEAN;
  VAR
    PE : TPBufferItem;
  BEGIN
    IF NOT SUPER.GetFirst( OUT PE ) THEN
      RETURN FALSE;
    END;
    Value.Assign( TPBufferItem( PE )^.Value^ );
    Data := TPBufferItem( PE )^.Data;
    RETURN TRUE;
  END CBufferList.GetFirst;

//---------------------------------------------------------------------------

  PUBLIC PROCEDURE CBufferList.GetLast( OUT Value : AMemoryBuffer; OUT Data : PTR ) : BOOLEAN;
  VAR
    PE : TPBufferItem;
  BEGIN
    IF NOT SUPER.GetLast( OUT PE ) THEN
      RETURN FALSE;
    END;
    Value.Assign( TPBufferItem( PE )^.Value^ );
    Data := TPBufferItem( PE )^.Data;
    RETURN TRUE;
  END CBufferList.GetLast;

//---------------------------------------------------------------------------

  PUBLIC PROCEDURE CBufferList.PrevOf( CONST Value : AMemoryBuffer; OUT Previous : AMemoryBuffer; OUT Data : PTR ): BOOLEAN; // SLOW
  VAR
    i : INTEGER;
    PE : TPBufferItem;
  BEGIN
    IF NOT Lookup( Value, OUT PE, OUT i ) OR NOT SUPER.PrevOf( PE, OUT PE ) THEN
      RETURN FALSE;
    END;
    Previous.Assign( TPBufferItem( PE )^.Value^ );
    Data := TPBufferItem( PE )^.Data;
    RETURN TRUE;
  END CBufferList.PrevOf;

//---------------------------------------------------------------------------

  PUBLIC PROCEDURE CBufferList.NextOf( CONST Value : AMemoryBuffer; OUT Next : AMemoryBuffer; OUT Data : PTR ): BOOLEAN; // SLOW
  VAR
    i : INTEGER;
    PE : TPBufferItem;
  BEGIN
    IF NOT Lookup( Value, OUT PE, OUT i ) OR NOT SUPER.NextOf( PE, OUT PE ) THEN
      RETURN FALSE;
    END;
    Next.Assign( TPBufferItem( PE )^.Value^ );
    Data := TPBufferItem( PE )^.Data;
    RETURN TRUE;
  END CBufferList.NextOf;

//---------------------------------------------------------------------------

  PUBLIC PROCEDURE CBufferList.IndexOf( CONST Value : AMemoryBuffer ) : INTEGER; // SLOW
  VAR
    Index : INTEGER;
    PE : TPBufferItem;
  BEGIN
    IF Lookup( Value, OUT PE, OUT Index ) THEN
      RETURN Index;
    ELSE
      RETURN -1;
    END;
  END CBufferList.IndexOf;

//---------------------------------------------------------------------------

  PRIVATE PROCEDURE CBufferList.Lookup( CONST Value : AMemoryBuffer; OUT Item : list.TPListElem; OUT Index : INTEGER ) : BOOLEAN;
  VAR
    i : INTEGER := 0;
    PE : TPBufferItem;
    b : BOOLEAN;
  BEGIN
    b := SUPER.GetFirst( OUT PE );
    WHILE b DO
      IF PE^.Value^ = Value THEN
        Item := PE;
        Index := i;
        RETURN TRUE;
      END;
      b := SUPER.NextOf( PE, OUT PE );
      INC( i );
    END; // WHILE
    RETURN FALSE;
  END CBufferList.Lookup;

//---------------------------------------------------------------------------

   PUBLIC PROCEDURE Enqueue( CONST Value : AMemoryBuffer; Data : PTR );
   BEGIN
      Add( Value, Data );
   END Enqueue;

//---------------------------------------------------------------------------

   PUBLIC PROCEDURE EnqueueOA( CONST Value : ARRAY OF BYTE; Data : PTR );
   BEGIN
      AddOA( Value, Data );
   END EnqueueOA;

//---------------------------------------------------------------------------

   PUBLIC PROCEDURE Dequeue( OUT Value : AMemoryBuffer; OUT Data : PTR ) : BOOLEAN; 
   VAR
      PE : TPBufferItem;
   BEGIN
      IF NOT SUPER.GetFirst( OUT PE ) THEN
         RETURN FALSE;
      END;
      Value.Assign( PE^.Value^ );
      Data := PE^.Data;
      SUPER.Delete( PE );
      RETURN TRUE;
   END Dequeue;

//---------------------------------------------------------------------------

   PUBLIC PROCEDURE DequeueOA( OUT Value : ARRAY OF BYTE; OUT Filled : CARDINAL; OUT Data : PTR ) : BOOLEAN; 
   VAR
      PE : TPBufferItem;
   BEGIN
      IF NOT SUPER.GetFirst( OUT PE ) THEN
         RETURN FALSE;
      END;
      PE^.Value^.ToOA( OUT Value, OUT Filled );
      Data := PE^.Data;
      SUPER.Delete( PE );
      RETURN TRUE;
   END DequeueOA;

//---------------------------------------------------------------------------

BEGIN
END CBufferList;

//===========================================================================

END lists.