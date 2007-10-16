IMPLEMENTATION MODULE arrays;

(*=============================================================================*)

CLASS IMPLEMENTATION CIntegerArray;

(*-----------------------------------------------------------------------------*)

  PUBLIC INDEX CIntegerArray GET( Index : INTEGER ) : INTEGER;
  TYPE
    TPIA = POINTER TO ARRAY [0..0] OF INTEGER;
  VAR
    i : CARDINAL;
  BEGIN
    i := DEC( Index, LowBound );
    IF ( i < 0 ) OR ( i >= _Count ) THEN
      RETURN 0;
    ELSE
      RETURN TPIA( _Data )^[i];
    END;
  END CIntegerArray;

(*-----------------------------------------------------------------------------*)

  PUBLIC INDEX CIntegerArray SET( Index : INTEGER; Value : INTEGER );
  TYPE
    TPIA = POINTER TO ARRAY [0..0] OF INTEGER;
  VAR
    i : CARDINAL;
  BEGIN
    i := DEC( Index, LowBound );
    IF ( i < 0 ) OR ( i >= _Count ) THEN
      RETURN;
    ELSE
      TPIA( _Data )^[i] := Value;
    END;
  END CIntegerArray;

(*-----------------------------------------------------------------------------*)

  PUBLIC PROCEDURE Add( Value : INTEGER ) : INTEGER; // returns index
  BEGIN
    RETURN SUPER.Add( ADR( Value ), SIZE( Value ));
  END Add;

(*-----------------------------------------------------------------------------*)

  PUBLIC PROCEDURE Contains( Value : INTEGER ) : BOOLEAN;
  BEGIN
    RETURN SUPER.Contains( ADR( Value ), SIZE( Value ));
  END Contains;

(*-----------------------------------------------------------------------------*)

  PUBLIC PROCEDURE Insert( Index : INTEGER; Value : INTEGER );
  BEGIN
    SUPER.Insert( Index, ADR( Value ), SIZE( Value ));
  END Insert;

(*-----------------------------------------------------------------------------*)

  PUBLIC PROCEDURE Remove( Value : INTEGER );
  BEGIN
    SUPER.Remove( ADR( Value ), SIZE( Value ));
  END Remove;

(*-----------------------------------------------------------------------------*)

  PUBLIC PROCEDURE IndexOf( Value : INTEGER ) : INTEGER;
  BEGIN
    RETURN SUPER.IndexOf( ADR( Value ), SIZE( Value ));
  END IndexOf;

(*-----------------------------------------------------------------------------*)

  PRIVATE PROCEDURE Init();
  BEGIN
    SUPER.Init( array.astrgSparseArray, SIZE( INTEGER ));
  END Init;

(*-----------------------------------------------------------------------------*)

BEGIN
  Init();
END CIntegerArray;

(*=============================================================================*)

CLASS IMPLEMENTATION CPtrArray;

(*-----------------------------------------------------------------------------*)

  PUBLIC INDEX CPtrArray GET( Index : INTEGER ) : PTR;
  TYPE
    TPPA = POINTER TO ARRAY [0..0] OF PTR;
  VAR
    i : CARDINAL;
  BEGIN
    i := DEC( Index, LowBound );
    IF ( i < 0 ) OR ( i >= _Count ) THEN
      RETURN 0;
    ELSE
      RETURN TPPA( _Data )^[i];
    END;
  END CPtrArray;

(*-----------------------------------------------------------------------------*)

  PUBLIC INDEX CPtrArray SET( Index : INTEGER; Value : PTR );
  TYPE
    TPPA = POINTER TO ARRAY [0..0] OF PTR;
  VAR
    i : CARDINAL;
  BEGIN
    i := DEC( Index, LowBound );
    IF ( i < 0 ) OR ( i >= _Count ) THEN
      RETURN;
    ELSE
      TPPA( _Data )^[i] := Value;
    END;
  END CPtrArray;

(*-----------------------------------------------------------------------------*)

  PUBLIC PROCEDURE Add( Value : PTR ) : INTEGER; // returns index
  BEGIN
    RETURN SUPER.Add( ADR( Value ), SIZE( Value ));
  END Add;

(*-----------------------------------------------------------------------------*)

  PUBLIC PROCEDURE Contains( Value : PTR ) : BOOLEAN;
  BEGIN
    RETURN SUPER.Contains( ADR( Value ), SIZE( Value ));
  END Contains;

(*-----------------------------------------------------------------------------*)

  PUBLIC PROCEDURE Insert( Index : INTEGER; Value : PTR );
  BEGIN
    SUPER.Insert( Index, ADR( Value ), SIZE( Value ));
  END Insert;

(*-----------------------------------------------------------------------------*)

  PUBLIC PROCEDURE Remove( Value : PTR );
  BEGIN
    SUPER.Remove( ADR( Value ), SIZE( Value ));
  END Remove;

(*-----------------------------------------------------------------------------*)

  PUBLIC PROCEDURE IndexOf( Value : PTR ) : INTEGER;
  BEGIN
    RETURN SUPER.IndexOf( ADR( Value ), SIZE( Value ));
  END IndexOf;

(*-----------------------------------------------------------------------------*)

  PRIVATE PROCEDURE Init();
  BEGIN
    SUPER.Init( array.astrgSparseArray, SIZE( INTEGER ));
  END Init;

(*-----------------------------------------------------------------------------*)

BEGIN
  Init();
END CPtrArray;

(*=============================================================================*)

END arrays.