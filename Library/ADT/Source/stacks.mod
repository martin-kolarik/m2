IMPLEMENTATION MODULE stacks;

FROM Storage IMPORT
  ALLOCATE, DEALLOCATE;

IMPORT
  list;
  
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

CLASS IMPLEMENTATION CIntegerStack;

  PUBLIC READONLY PROPERTY Current GET : INTEGER;
  BEGIN
    IF ( _Current = NIL ) OR ( _Current = -1 ) THEN
      RETURN 0;
    ELSE
      RETURN TPIntegerItem( _Current )^.Value;
    END;
  END Current;

  PUBLIC PROPERTY CurrentData GET : PTR;
  BEGIN
    IF ( _Current = NIL ) OR ( _Current = -1 ) THEN
      RETURN 0;
    ELSE
      RETURN TPIntegerItem( _Current )^.Data;
    END;
  END CurrentData;

  PUBLIC PROPERTY CurrentData SET( Value : PTR );
  BEGIN
    IF ( _Current <> NIL ) AND ( _Current <> -1 ) THEN
      TPIntegerItem( _Current )^.Data := Value;
    END;
  END CurrentData;

  PUBLIC PROCEDURE Contains( Value : INTEGER ) : BOOLEAN;
  VAR
    PI : TPIntegerItem;
    b : BOOLEAN;
  BEGIN
    b := GetFirst( OUT PI );
    WHILE b DO
      IF PI^.Value = Value THEN
        RETURN TRUE;
      END;
      b := NextOf( PI, OUT PI );
    END; // WHILE
    RETURN FALSE;
  END Contains;

  PUBLIC PROCEDURE Push( Value : INTEGER );
  VAR
    PI : TPIntegerItem;
  BEGIN
    NEW( PI );
    PI^.Value := Value;
    SUPER.Push( PI );
  END Push;

  PUBLIC PROCEDURE PushEx( Value : INTEGER; Data : PTR );
  VAR
    PI : TPIntegerItem;
  BEGIN
    NEW( PI );
    PI^.Value := Value;
    PI^.Data := Data;
    SUPER.Push( PI );
  END PushEx;

  PUBLIC PROCEDURE Pop() : INTEGER;
  VAR
	 i : CARDINAL;
    PI : TPIntegerItem;
  BEGIN
    IF NOT SUPER.Pop( OUT PI ) THEN
      RETURN 0;
    END;
    i := PI^.Value;
    DISPOSE( PI );
    RETURN i;
  END Pop;

  PUBLIC PROCEDURE PopEx( OUT Value : INTEGER; OUT Data : PTR ) : BOOLEAN;
  VAR
    PI : TPIntegerItem;
  BEGIN
    IF NOT SUPER.Pop( OUT PI ) THEN
      RETURN FALSE;
    END;
    Value := PI^.Value;
    Data := PI^.Data;
    DISPOSE( PI );
    RETURN TRUE;
  END PopEx;
  
  PUBLIC PROCEDURE Peek() : INTEGER;
  VAR
    PI : TPIntegerItem;
  BEGIN
    IF SUPER.Peek( OUT PI ) THEN
      RETURN PI^.Value;
    ELSE
      RETURN 0;
    END;
  END Peek;

  PUBLIC PROCEDURE PeekEx( OUT Value : INTEGER; OUT Data : PTR ) : BOOLEAN;
  VAR
    PI : TPIntegerItem;
  BEGIN
    IF NOT SUPER.Peek( OUT PI ) THEN
      RETURN FALSE;
    END;
    Value := PI^.Value;
    Data := PI^.Data;
    RETURN TRUE;
  END PeekEx;

  PUBLIC PROCEDURE StoreData( Data : PTR );
  VAR
    PI : TPIntegerItem;
  BEGIN
    IF SUPER.Peek( OUT PI ) THEN
      PI^.Data := Data;
    END;
  END StoreData;

  PUBLIC PROCEDURE PeekData() : PTR;
  VAR
    PI : TPIntegerItem;
  BEGIN
    IF SUPER.Peek( OUT PI ) THEN
      RETURN PI^.Data;
    ELSE
      RETURN 0;
    END;
  END PeekData;

END CIntegerStack;

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

CLASS IMPLEMENTATION CPtrStack;

  PUBLIC READONLY PROPERTY Current GET : PTR;
  BEGIN
    IF ( _Current = NIL ) OR ( _Current = -1 ) THEN
      RETURN 0;
    ELSE
      RETURN TPPtrItem( _Current )^.Value;
    END;
  END Current;

  PUBLIC PROPERTY CurrentData GET : PTR;
  BEGIN
    IF ( _Current = NIL ) OR ( _Current = -1 ) THEN
      RETURN 0;
    ELSE
      RETURN TPPtrItem( _Current )^.Data;
    END;
  END CurrentData;

  PUBLIC PROPERTY CurrentData SET( Value : PTR );
  BEGIN
    IF ( _Current <> NIL ) AND ( _Current <> -1 ) THEN
      TPPtrItem( _Current )^.Data := Value;
    END;
  END CurrentData;

  PUBLIC PROCEDURE Contains( Value : PTR ) : BOOLEAN;
  VAR
    PI : TPPtrItem;
    b : BOOLEAN;
  BEGIN
    b := GetFirst( OUT PI );
    WHILE b DO
      IF PI^.Value = Value THEN
        RETURN TRUE;
      END;
      b := NextOf( PI, OUT PI );
    END; // WHILE
    RETURN FALSE;
  END Contains;

  PUBLIC PROCEDURE Push( Value : PTR );
  VAR
    PI : TPPtrItem;
  BEGIN
    NEW( PI );
    PI^.Value := Value;
    SUPER.Push( PI );
  END Push;

  PUBLIC PROCEDURE PushEx( Value : PTR; Data : PTR );
  VAR
    PI : TPPtrItem;
  BEGIN
    NEW( PI );
    PI^.Value := Value;
    PI^.Data := Data;
    SUPER.Push( PI );
  END PushEx;

  PUBLIC PROCEDURE Pop() : PTR;
  VAR
    PI : TPPtrItem;
    p : PTR;
  BEGIN
    IF NOT SUPER.Pop( OUT PI ) THEN
      RETURN 0;
    END;
    p := PI^.Value;
    DISPOSE( PI );
    RETURN p;
  END Pop;

  PUBLIC PROCEDURE PopEx( OUT Value : PTR; OUT Data : PTR ) : BOOLEAN;
  VAR
    PI : TPPtrItem;
  BEGIN
    IF NOT SUPER.Pop( OUT PI ) THEN
      RETURN FALSE;
    END;
    Value := PI^.Value;
    Data := PI^.Data;
    DISPOSE( PI );
    RETURN TRUE;
  END PopEx;

  PUBLIC PROCEDURE Peek() : PTR;
  VAR
    PI : TPPtrItem;
  BEGIN
    IF SUPER.Peek( OUT PI ) THEN
      RETURN PI^.Value;
    ELSE
      RETURN 0;
    END;
  END Peek;

  PUBLIC PROCEDURE PeekEx( OUT Value : PTR; OUT Data : PTR ) : BOOLEAN;
  VAR
    PI : TPPtrItem;
  BEGIN
    IF NOT SUPER.Peek( OUT PI ) THEN
      RETURN FALSE;
    END;
    Value := PI^.Value;
    Data := PI^.Data;
    RETURN TRUE;
  END PeekEx;

  PUBLIC PROCEDURE StoreData( Data : PTR );
  VAR
    PI : TPPtrItem;
  BEGIN
    IF SUPER.Peek( OUT PI ) THEN
      PI^.Data := Data;
    END;
  END StoreData;

  PUBLIC PROCEDURE PeekData() : PTR;
  VAR
    PI : TPIntegerItem;
  BEGIN
    IF SUPER.Peek( OUT PI ) THEN
      RETURN PI^.Data;
    ELSE
      RETURN 0;
    END;
  END PeekData;

END CPtrStack;

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

CLASS IMPLEMENTATION CStringStack;

  PUBLIC READONLY PROPERTY Current GET : POINTER TO CString;
  BEGIN
    IF ( _Current = NIL ) OR ( _Current = -1 ) THEN
      RETURN NIL;
    ELSE
      RETURN ADR( TPStringItem( _Current )^.Value );
    END;
  END Current;

  PUBLIC PROPERTY CurrentData GET : PTR;
  BEGIN
    IF ( _Current = NIL ) OR ( _Current = -1 ) THEN
      RETURN 0;
    ELSE
      RETURN TPStringItem( _Current )^.Data;
    END;
  END CurrentData;

  PUBLIC PROPERTY CurrentData SET( Value : PTR );
  BEGIN
    IF ( _Current <> NIL ) AND ( _Current <> -1 ) THEN
      TPStringItem( _Current )^.Data := Value;
    END;
  END CurrentData;

  PUBLIC PROCEDURE Contains( CONST Value : CString ) : BOOLEAN;
  VAR
    PI : TPStringItem;
    b : BOOLEAN;
  BEGIN
    b := GetFirst( OUT PI );
    WHILE b DO
      IF PI^.Value = Value THEN
        RETURN TRUE;
      END;
      b := NextOf( PI, OUT PI );
    END; // WHILE
    RETURN FALSE;
  END Contains;

  PUBLIC PROCEDURE ContainsOA( CONST Value : ARRAY OF WCHAR ) : BOOLEAN;
  VAR
		S : CString;
  BEGIN
		S.FromOA( Value );
		RETURN Contains( S );
  END ContainsOA;

  PUBLIC PROCEDURE Push( CONST Value : CString );
  VAR
    PI : TPStringItem;
  BEGIN
    NEW( PI );
    PI^.Value := Value;
    SUPER.Push( PI );
  END Push;

	PUBLIC PROCEDURE PushOA( CONST Value : ARRAY OF WCHAR );
	VAR
		S : CString;
	BEGIN
		S.FromOA( Value );
		Push( S );
	END PushOA;

  PUBLIC PROCEDURE PushEx( CONST Value : CString; Data : PTR );
  VAR
    PI : TPStringItem;
  BEGIN
    NEW( PI );
    PI^.Value := Value;
    PI^.Data := Data;
    SUPER.Push( PI );
  END PushEx;

	PUBLIC PROCEDURE PushExOA( CONST Value : ARRAY OF WCHAR; Data : PTR );
	VAR
		S : CString;
	BEGIN
		S.FromOA( Value );
		PushEx( S, Data );
	END PushExOA;

  PUBLIC PROCEDURE Pop( OUT Value : CString );
  VAR
    PI : TPStringItem;
  BEGIN
    IF SUPER.Pop( OUT PI ) THEN
      Value := PI^.Value;
      DISPOSE( PI );
    END;
  END Pop;

  PUBLIC PROCEDURE PopEx( OUT Value : CString; OUT Data : PTR ) : BOOLEAN;
  VAR
    PI : TPStringItem;
  BEGIN
    IF NOT SUPER.Pop( OUT PI ) THEN
      RETURN FALSE;
    END;
    Value := PI^.Value;
    Data := PI^.Data;
    DISPOSE( PI );
    RETURN TRUE;
  END PopEx;

  PUBLIC PROCEDURE Peek( OUT Value : CString );
  VAR
    PI : TPStringItem;
  BEGIN
    IF SUPER.Peek( OUT PI ) THEN
      Value := PI^.Value;
    ELSE
      Value.Clear();
    END;
  END Peek;

  PUBLIC PROCEDURE PeekEx( OUT Value : CString; OUT Data : PTR ) : BOOLEAN;
  VAR
    PI : TPStringItem;
  BEGIN
    IF NOT SUPER.Peek( OUT PI ) THEN
      RETURN FALSE;
    END;
    Value := PI^.Value;
    Data := PI^.Data;
    RETURN TRUE;
  END PeekEx;

  PUBLIC PROCEDURE StoreData( Data : PTR );
  VAR
    PI : TPStringItem;
  BEGIN
    IF SUPER.Peek( OUT PI ) THEN
      PI^.Data := Data;
    END;
  END StoreData;

  PUBLIC PROCEDURE PeekData() : PTR;
  VAR
    PI : TPStringItem;
  BEGIN
    IF SUPER.Peek( OUT PI ) THEN
      RETURN PI^.Data;
    ELSE
      RETURN 0;
    END;
  END PeekData;

END CStringStack;

//===========================================================================

END stacks.