IMPLEMENTATION MODULE list;

FROM Storage IMPORT
  ALLOCATE, DEALLOCATE;

(*===========================================================================*)
// Bidirectional list

CLASS IMPLEMENTATION CListElem;

  PUBLIC PROPERTY InList GET : BOOLEAN;
  BEGIN
    RETURN PNext <> NIL;
  END InList;

  PUBLIC PROPERTY PrevOf GET : TPListElem;
  BEGIN
    RETURN PPrev;
  END PrevOf;

  PUBLIC PROPERTY NextOf GET : TPListElem;
  BEGIN
    RETURN PNext;
  END NextOf;

  PUBLIC VIRTUAL FINALLY CListElem();
  BEGIN
  END CListElem;

BEGIN
  PPrev := NIL;
  PNext := NIL;
END CListElem;

(*===========================================================================*)

CLASS IMPLEMENTATION CList;

(*---------------------------------------------------------------------------*)

  PUBLIC PROPERTY CList.Empty GET : BOOLEAN;
  BEGIN
    RETURN PFirst = NIL;
  END CList.Empty;

(*---------------------------------------------------------------------------*)

  INDEX CList GET( Index : INTEGER ) : TPListElem;
  VAR
    PE : TPListElem;
  BEGIN
    IF ( Index < 0 ) OR ( Index >= INTEGER( Count )) THEN
      RETURN NIL;
    END;
    PE := PFirst;
    WHILE Index > 0 DO
      PE := PE^.PNext;
      DEC( Index );
    END;
    RETURN PE;
  END CList;

(*---------------------------------------------------------------------------*)

  PUBLIC PROCEDURE InsertFirst( PElem : TPListElem );
  BEGIN
    PElem^.PPrev := NIL;
    IF PFirst = NIL THEN
      PLast := PElem;
    ELSE
      PFirst^.PPrev := PElem;
    END;
    PElem^.PNext := PFirst;
    PFirst := PElem;
    INC( Count );
  END InsertFirst;

(*---------------------------------------------------------------------------*)

  PUBLIC PROCEDURE InsertBefore( PBefore, PElem : TPListElem );
  BEGIN
    IF CheckOwning AND NOT Contains( PBefore ) THEN
      RETURN;
    ELSIF PBefore = NIL THEN
      InsertFirst( PElem );
    ELSE
      PElem^.PPrev := PBefore^.PPrev;
      IF PElem^.PPrev = NIL THEN
        PFirst := PElem;
      ELSE
        PElem^.PPrev^.PNext := PElem;
      END;
      PElem^.PNext := PBefore;
      PBefore^.PPrev := PElem;
      INC( Count );
    END;
  END InsertBefore;

(*---------------------------------------------------------------------------*)

  PUBLIC PROCEDURE Append( PElem : TPListElem );
  BEGIN
    PElem^.PNext := NIL;
    IF PFirst = NIL THEN
      PFirst := PElem;
      PElem^.PPrev := NIL;
    ELSE
      PLast^.PNext := PElem;
      PElem^.PPrev := PLast;
    END;
    PLast := PElem;
    INC( Count );
  END Append;

(*---------------------------------------------------------------------------*)

  PUBLIC PROCEDURE Contains( CONST PElem : TPListElem ): BOOLEAN;
  VAR
    PE : TPListElem;
  BEGIN
    PE := PFirst;
    WHILE ( PE <> PElem ) AND ( PE <> NIL ) DO
      PE := PE^.PNext;
    END;
    RETURN PE <> NIL;
  END Contains;

(*---------------------------------------------------------------------------*)

  PUBLIC PROCEDURE Remove( PElem : TPListElem );
  BEGIN
    IF CheckOwning AND NOT Contains( PElem ) THEN
      RETURN;
    END;
    IF PElem^.PPrev = NIL THEN
      PFirst := PElem^.PNext;
      IF PFirst <> NIL THEN
        PFirst^.PPrev := NIL;
      END;
    ELSE
      PElem^.PPrev^.PNext := PElem^.PNext;
    END;
    IF PElem^.PNext = NIL THEN
      PLast := PElem^.PPrev;
      IF PLast <> NIL THEN
        PLast^.PNext := NIL;
      END;
    ELSE
      PElem^.PNext^.PPrev := PElem^.PPrev;
    END;
    DEC( Count );
  END Remove;

(*---------------------------------------------------------------------------*)

  PUBLIC PROCEDURE Delete( PElem : TPListElem );
  BEGIN
    Remove( PElem );
    DISPOSE( PElem );
  END Delete;

(*---------------------------------------------------------------------------*)

  PUBLIC PROCEDURE GetFirst( OUT PElem : TPListElem ) : BOOLEAN;
  BEGIN
    IF PFirst = NIL THEN
      RETURN FALSE;
    ELSE
      PElem := PFirst;
      RETURN TRUE;
    END;
  END GetFirst;

(*---------------------------------------------------------------------------*)

  PUBLIC PROCEDURE GetLast( OUT PElem : TPListElem ) : BOOLEAN;
  BEGIN
    IF PLast = NIL THEN
      RETURN FALSE;
    ELSE
      PElem := PLast;
      RETURN TRUE;
    END;
  END GetLast;

(*---------------------------------------------------------------------------*)

  PUBLIC PROCEDURE PrevOf( CONST Element : TPListElem; OUT Previous : TPListElem ) : BOOLEAN;
  BEGIN
    IF CheckOwning AND NOT Contains( Element ) THEN
      RETURN FALSE;
    ELSIF Element^.PPrev = NIL THEN
      RETURN FALSE;
    ELSE
      Previous := Element^.PPrev;
      RETURN TRUE;
    END;
  END PrevOf;

(*---------------------------------------------------------------------------*)

  PUBLIC PROCEDURE NextOf( CONST Element : TPListElem; OUT Next : TPListElem ): BOOLEAN;
  BEGIN
    IF CheckOwning AND NOT Contains( Element ) THEN
      RETURN FALSE;
    ELSIF Element^.PNext = NIL THEN
      RETURN FALSE;
    ELSE
      Next := Element^.PNext;
      RETURN TRUE;
    END;
  END NextOf;

(*---------------------------------------------------------------------------*)

  PUBLIC PROCEDURE IndexOf( CONST Element : TPListElem ): INTEGER;
  VAR
    I : INTEGER := 0;
    PE : TPListElem;
  BEGIN
    PE := PFirst;
    WHILE PE <> NIL DO
      IF PE = Element THEN
        RETURN I;
      END;
      PE := PE^.PNext;
      INC( I );
    END;
    RETURN -1;
  END IndexOf;

(*---------------------------------------------------------------------------*)

  PUBLIC PROCEDURE AppendList( REF List : CList );
  BEGIN
    Append( List.PFirst );
    INC( Count, List.Count );
    List.Clear();
  END AppendList;

(*---------------------------------------------------------------------------*)

  PUBLIC PROCEDURE Clear();
  BEGIN
    PFirst := NIL;
    PLast := NIL;
    Count := 0;
  END Clear;

(*---------------------------------------------------------------------------*)

  PUBLIC VIRTUAL PROCEDURE Dispose();
  VAR
    PE : TPListElem;
  BEGIN
    WHILE PFirst <> NIL DO
      PE := PFirst;
      PFirst := PFirst^.PNext;
      DISPOSE( PE );
    END; // WHILE
    Clear();
  END Dispose;

(*---------------------------------------------------------------------------*)

  PUBLIC PROCEDURE Enqueue( PElem : TPListElem );
  BEGIN
    Append( PElem );
  END Enqueue;

(*---------------------------------------------------------------------------*)

  PUBLIC PROCEDURE Dequeue( OUT PElem : TPListElem ) : BOOLEAN; 
  BEGIN
    IF NOT GetFirst( OUT PElem ) THEN
      RETURN FALSE;
    END;
    Remove( PElem );
    RETURN TRUE;
  END Dequeue;

(*---------------------------------------------------------------------------*)

BEGIN
  PFirst := NIL;
  PLast := NIL;
  Count := 0;
  CheckOwning := FALSE;
FINALLY
  Dispose();
END CList;

(*===========================================================================*)

CLASS IMPLEMENTATION CListWState;

(*---------------------------------------------------------------------------*)

  PUBLIC READONLY PROPERTY CListWState.Current GET : TPListElem;
  BEGIN
    IF _Current = -1 THEN
      RETURN NIL;
    ELSE
      RETURN TPListElem( _Current );
    END;
  END CListWState.Current;

(*---------------------------------------------------------------------------*)

  PUBLIC PROCEDURE Reset();
  BEGIN
    _Current := NIL;
  END Reset;

(*---------------------------------------------------------------------------*)

  PUBLIC PROCEDURE MoveNext() : BOOLEAN;
  BEGIN
    IF _Current = NIL THEN
      IF GetFirst( OUT _Current ) THEN
        RETURN TRUE;
      END;
    ELSIF _Current <> -1 THEN
      IF NextOf( _Current, OUT _Current ) THEN
        RETURN TRUE;
      END;
    END;
    _Current := -1;
    RETURN FALSE;
  END MoveNext;

(*---------------------------------------------------------------------------*)

BEGIN
  _Current := NIL;
END CListWState;

(*===========================================================================*)

END list.