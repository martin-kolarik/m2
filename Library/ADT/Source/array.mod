IMPLEMENTATION MODULE array;

FROM Storage IMPORT
  DEALLOCATE, REALLOCATE;
  
IMPORT
  Storage;

(*=============================================================================*)

CLASS IMPLEMENTATION CArray;

(*-----------------------------------------------------------------------------*)

  PUBLIC PROPERTY Size GET : CARDINAL;
  BEGIN
    RETURN _Size;
  END Size;
  
(*-----------------------------------------------------------------------------*)

  PUBLIC PROPERTY Size SET( Value : CARDINAL );
  BEGIN
    IF _ItemSize = 0 THEN
      _Size := Value;
      RETURN;
    ELSE
      Value := Value AND NOT 0FH + 10H;
    END;
    REALLOCATE( REF _Data, Value * CARDINAL( _ItemSize ));
    IF Value > _Size THEN
      Storage.Zero( _Data@[ _Size * _ItemSize ], ( Value - _Size ) * _ItemSize );
    END;
    _Size := Value;
  END Size;

(*-----------------------------------------------------------------------------*)

  PUBLIC PROPERTY Count GET : CARDINAL;
  BEGIN
    RETURN _Count;
  END Count;
  
(*-----------------------------------------------------------------------------*)

  PUBLIC PROPERTY Count SET( Value : CARDINAL );
  BEGIN
    _Count := MIN2( Value, _Size );
  END Count;
  
(*-----------------------------------------------------------------------------*)

  PUBLIC PROPERTY Empty GET : BOOLEAN;
  BEGIN
    RETURN _Count = 0;
  END Empty;
  
(*-----------------------------------------------------------------------------*)

  PUBLIC PROPERTY Data GET : ADDRESS;
  BEGIN
    RETURN _Data;
  END Data;
  
(*-----------------------------------------------------------------------------*)

  PUBLIC INDEX CArray GET( Index : INTEGER ) : ADDRESS;
  VAR
    i : CARDINAL;
  BEGIN
    i := DEC( Index, LowBound );
    IF ( i < 0 ) OR ( i >= _Count ) THEN
      Exceptions.Modula2Exception( NIL, L"", L"", Exceptions.mexOutOfArrayIndex );
      RETURN NIL;
    ELSE
      RETURN _Data@[ i * _ItemSize ];
    END;
  END CArray;

(*-----------------------------------------------------------------------------*)

  PUBLIC INDEX CArray SET( Index : INTEGER; Value : ADDRESS );
  VAR
    i : CARDINAL;
  BEGIN
    i := DEC( Index, LowBound );
    IF ( i < 0 ) OR ( i >= _Count ) THEN
      Exceptions.Modula2Exception( NIL, L"", L"", Exceptions.mexOutOfArrayIndex );
    ELSE
      Storage.Move( Value, _Data@[ i * _ItemSize ], _ItemSize );
    END;
  END CArray;

(*-----------------------------------------------------------------------------*)

  PUBLIC PROCEDURE Init( Strategy : TStrategy; ItemSize : CARDINAL );
  VAR
    s : CARDINAL;
  BEGIN
    IF _Data <> NIL THEN
      RETURN;
    END;
    _ItemSize := ItemSize;
    SELF.Strategy := Strategy;
    IF _Size > 0 THEN // allocate space
      s := _Size;
      _Size := 0;
      Size := s;
    END;
  END Init;
  
(*-----------------------------------------------------------------------------*)

  PUBLIC PROCEDURE RemoveIndex( Index : INTEGER );
  VAR
    i : CARDINAL;
  BEGIN
    i := DEC( Index, LowBound );
    IF ( i < 0 ) OR ( i >= _Count ) THEN
      Exceptions.Modula2Exception( NIL, L"", L"", Exceptions.mexOutOfArrayIndex );
    ELSIF Strategy = astrgListInArray THEN
      Storage.Move( _Data@[ INC( i ) * _ItemSize ], _Data@[ i * _ItemSize ], ( _Count - i - 1 ) * _ItemSize );
      DEC( _Count );
    ELSE
      Storage.Zero( _Data@[ i * _ItemSize ], _ItemSize );
    END;
  END RemoveIndex;
  
(*-----------------------------------------------------------------------------*)

  PUBLIC PROCEDURE Add( Item : ADDRESS; Len : CARDINAL ) : INTEGER; // returns index
  BEGIN
    IF _Count = _Size THEN
      Size := _Size + 1;
    END;
    IF Len < _ItemSize THEN
      Storage.Zero( _Data@[ _Count * _ItemSize + Len ], _ItemSize-Len );
    END;
    Storage.Move( Item, _Data@[ _Count * _ItemSize ], Len );
    INC( _Count );
    RETURN _Count - 1;
  END Add;
  
(*-----------------------------------------------------------------------------*)

  PUBLIC PROCEDURE Contains( Item : ADDRESS; Len : CARDINAL ) : BOOLEAN;
  BEGIN
    RETURN IndexOf( Item, Len ) >= LowBound;
  END Contains;

(*-----------------------------------------------------------------------------*)

  PUBLIC PROCEDURE Insert( Index : INTEGER; Item : ADDRESS; Len : CARDINAL );
  VAR
    i : CARDINAL;
  BEGIN
    i := DEC( Index, LowBound );
    IF _Count = _Size THEN
      Size := _Size + 1;
    END;
    Storage.Move( _Data@[ i * _ItemSize ], _Data@[ INC( i ) * _ItemSize ], ( _Count - i ) * _ItemSize );
    IF Len < _ItemSize THEN
      Storage.Zero( _Data@[ i * _ItemSize + Len ], _ItemSize-Len );
    END;
    Storage.Move( Item, _Data@[ i * _ItemSize ], Len );
    INC( _Count );
  END Insert;

(*-----------------------------------------------------------------------------*)

  PUBLIC PROCEDURE Remove( Item : ADDRESS; Len : CARDINAL );
  VAR
    i : CARDINAL;
  BEGIN
    i := 0;
    WHILE i < _Count DO
      IF NOT Storage.Equals( _Data@[ i * _ItemSize ], Item, MIN2( Len, _ItemSize )) THEN
        INC( i );
      ELSIF Strategy = astrgListInArray THEN
        RemoveIndex( i );
      ELSE
        RemoveIndex( i );
        INC( i );
      END;
    END; // WHILE
  END Remove;

(*-----------------------------------------------------------------------------*)

  PUBLIC PROCEDURE AddOA( CONST Item : ARRAY OF BYTE ) : INTEGER; // returns index
  BEGIN
    RETURN Add( ADR( Item ), MIN2( _ItemSize, HIGH( Item ) + 1 ));
  END AddOA;

(*-----------------------------------------------------------------------------*)

  PUBLIC PROCEDURE ContainsOA( CONST Item : ARRAY OF BYTE ) : BOOLEAN;
  BEGIN
    RETURN IndexOfOA( Item ) >= LowBound;
  END ContainsOA;

(*-----------------------------------------------------------------------------*)

  PUBLIC PROCEDURE InsertOA( Index : INTEGER; CONST Item : ARRAY OF BYTE );
  BEGIN
    Insert( Index, ADR( Item ), MIN2( _ItemSize, HIGH( Item ) + 1 ));
  END InsertOA;

(*-----------------------------------------------------------------------------*)

  PUBLIC PROCEDURE RemoveOA( CONST Item : ARRAY OF BYTE );
  BEGIN
    Remove( ADR( Item ), MIN2( _ItemSize, HIGH( Item ) + 1 ));
  END RemoveOA;

(*-----------------------------------------------------------------------------*)

  PUBLIC PROCEDURE IndexOf( Item : ADDRESS; Len : CARDINAL ) : INTEGER; // if not found returns LowBound-1
  VAR
    i : CARDINAL;
  BEGIN
    i := 0;
    WHILE i < _Count DO
      IF Storage.Equals( _Data@[ i * _ItemSize ], Item, MIN2( Len, _ItemSize )) THEN
        RETURN INTEGER( i ) + LowBound;
      END;
      INC( i );
    END; // WHILE
    RETURN LowBound-1;
  END IndexOf;

(*-----------------------------------------------------------------------------*)

  PUBLIC PROCEDURE IndexOfOA( CONST Item : ARRAY OF BYTE ) : INTEGER; // if not found returns LowBound-1
  BEGIN
    RETURN IndexOf( ADR( Item ), MIN2( _ItemSize, HIGH( Item ) + 1 ));
  END IndexOfOA;

(*-----------------------------------------------------------------------------*)

  PUBLIC PROCEDURE Clear();
  BEGIN
		_Count := 0;
  END Clear;

(*-----------------------------------------------------------------------------*)

  PUBLIC PROCEDURE Dispose();
  BEGIN
		IF _Data <> NIL THEN
			DISPOSE( _Data );
		END;
		_Count := 0;
		_Size := 0;
	END Dispose;

(*-----------------------------------------------------------------------------*)

   VIRTUAL FINALLY CArray;
   BEGIN
      Dispose();
   END CArray;

(*-----------------------------------------------------------------------------*)

BEGIN
   _ItemSize := 0;
   _Size := 0;
   _Count := 0;
   _Data := NIL;
   Strategy := astrgUnknown;
   LowBound := 0;
END CArray;

(*=============================================================================*)

END array.