IMPLEMENTATION MODULE avltree;

(*===========================================================================*)
//
// basic single and double AVL tree ADT 
//
// version 5 (base Honzik, removing of FREE during Delete mk, more keys mk)
//
(*===========================================================================*)

FROM Storage IMPORT
  REALLOCATE, DEALLOCATE, Fill;

(*===========================================================================*)

CLASS IMPLEMENTATION IAVLTreeElem;

(*---------------------------------------------------------------------------*)

  PUBLIC VIRTUAL FINALLY IAVLTreeElem();
  BEGIN
  END IAVLTreeElem;

(*---------------------------------------------------------------------------*)

END IAVLTreeElem;

(*===========================================================================*)

CLASS IMPLEMENTATION CAVLTreeElem1;

(*---------------------------------------------------------------------------*)

  LOCAL FINAL INDEX CAVLTreeElem1 GET( i : CARDINAL ) : TPAVLIndex;
  BEGIN
    RETURN ADR( _I );
  END CAVLTreeElem1;

(*---------------------------------------------------------------------------*)

BEGIN
  Fill( ADR( _I ), SIZE( _I ), 0 );
END CAVLTreeElem1;

(*===========================================================================*)

CLASS IMPLEMENTATION CAVLTreeElem2;

(*---------------------------------------------------------------------------*)

  LOCAL FINAL INDEX CAVLTreeElem2 GET( i : CARDINAL ) : TPAVLIndex;
  BEGIN
    RETURN ADR( _I[i] );
  END CAVLTreeElem2;

(*---------------------------------------------------------------------------*)

BEGIN
  Fill( ADR( _I ), SIZE( _I ), 0 );
END CAVLTreeElem2;

(*===========================================================================*)

CLASS IMPLEMENTATION CAVLTree;

(*---------------------------------------------------------------------------*)

  PUBLIC FINAL PROPERTY CAVLTree.Count GET : CARDINAL;
  BEGIN
    IF ( _Root = NIL ) OR ( _Root^[0] = NIL ) THEN
      RETURN 0;
    ELSE
      RETURN _Root^[0]^[0]^.Items + 1;
    END;
  END CAVLTree.Count;

(*---------------------------------------------------------------------------*)

  PUBLIC FINAL PROPERTY CAVLTree.Empty GET : BOOLEAN;
  BEGIN
    RETURN ( _Root = NIL ) OR ( _Root^[0] = NIL );
  END CAVLTree.Empty;

(*---------------------------------------------------------------------------*)

  PUBLIC FINAL PROPERTY CAVLTree.Indexes GET : CARDINAL;
  BEGIN
    RETURN _I;
  END CAVLTree.Indexes;

(*---------------------------------------------------------------------------*)

  PUBLIC FINAL PROPERTY CAVLTree.Indexes SET( Value : CARDINAL );
  VAR
    i : CARDINAL;
  BEGIN
    i := MAX2( 1, Value );
    IF i = _I THEN
      RETURN;
    END;
    REALLOCATE( _Root, i * SIZE( TAVLIndex ));
    IF i > _I THEN
      Fill( ADR( _Root^[_I] ), ( i-_I ) * SIZE( TAVLIndex ), 0 );
    END;
    _I := i;
  END CAVLTree.Indexes;

(*---------------------------------------------------------------------------*)

  INDEX CAVLTree GET( Index : INTEGER ) : TPAVLTreeElem;
  VAR
    e : TPAVLTreeElem;
  BEGIN
    IF OfIndexI( 0, Index, OUT e ) THEN
      RETURN e;
    ELSE
      RETURN NIL;
    END;
  END CAVLTree;

(*---------------------------------------------------------------------------*)

  PUBLIC PROCEDURE Insert( Inserted : TPAVLTreeElem );
  VAR
    w : BOOLEAN;

  (*----------*)

    PROCEDURE iInsert( i : CARDINAL; REF Element : TPAVLTreeElem );
    VAR
      res : TRISTATE;
    BEGIN
      IF Element = NIL THEN
        Element := Inserted;
        WITH Element^[i]^ DO
          R := NIL;
          L := NIL;
          Balance := tbNone;
        END;
        w := TRUE;
        RETURN;
      END;

      WITH Element^[i]^ DO
        INC( Items );

        res := Inserted^.Compare( i, Element );
        IF res = -1 THEN

          iInsert( i, REF L );
          IF NOT w THEN
            RETURN;
          END;
          CASE Balance OF
          | tbRight : 
            Balance := tbNone;
            w := FALSE;
          | tbNone :
            Balance := tbLeft;
          | tbLeft :
            iBalanceL( i, REF Element );
            w := FALSE;
          END;

        ELSIF res = 1 THEN

          iInsert( i, REF R );
          IF NOT w THEN
            RETURN;
          END;
          CASE Balance OF
          | tbLeft :
            Balance := tbNone;
            w := FALSE;
          | tbNone :
            Balance := tbRight;
          | tbRight :
            iBalanceR( i, REF Element );
            w := FALSE;
          END;

        ELSE // it is impossible to insert element with existing key
          ADDRESS( 0 )^ := 0;
        END;
      END; // WITH
    END iInsert;

  (*----------*)

  VAR
    i : CARDINAL;
  BEGIN
    FOR i := 0 TO _I - 1 DO
      iInsert( i, REF _Root^[i] );
    END;
  END Insert;

(*---------------------------------------------------------------------------*)

  PUBLIC VIRTUAL PROCEDURE Dispose();

  (*----------*)

    PROCEDURE iDispose( REF Element : TPAVLTreeElem );
    BEGIN
      IF Element = NIL THEN
        RETURN;
      END;
      iDispose( REF Element^[0]^.L );
      iDispose( REF Element^[0]^.R );
      DISPOSE( Element );
    END iDispose;

  (*----------*)

  BEGIN
    IF _Root <> NIL THEN
      iDispose( REF _Root^[0] );
    END;
  END Dispose;

(*---------------------------------------------------------------------------*)

  PUBLIC PROCEDURE Contains( CONST Key : TPAVLTreeKey ) : BOOLEAN;
  BEGIN
    RETURN ContainsI( 0, Key );
  END Contains;

(*---------------------------------------------------------------------------*)

  PUBLIC PROCEDURE Search( CONST Key : TPAVLTreeKey; OUT Found : TPAVLTreeElem ) : BOOLEAN;
  BEGIN
    RETURN SearchI( 0, Key, OUT Found );
  END Search;

(*---------------------------------------------------------------------------*)

  PUBLIC PROCEDURE Remove( CONST Key : TPAVLTreeKey; OUT Removed : TPAVLTreeElem ) : BOOLEAN;
  BEGIN
    RETURN RemoveI( 0, Key, OUT Removed );
  END Remove;

(*---------------------------------------------------------------------------*)

  PUBLIC PROCEDURE Delete( CONST Key : TPAVLTreeKey ) : BOOLEAN;
  BEGIN
    RETURN DeleteI( 0, Key );
  END Delete;

(*---------------------------------------------------------------------------*)

  PUBLIC PROCEDURE GetFirst( OUT First : TPAVLTreeElem ) : BOOLEAN;
  BEGIN
    RETURN GetFirstI( 0, OUT First );
  END GetFirst;

(*---------------------------------------------------------------------------*)

  PUBLIC PROCEDURE GetLast( OUT Last : TPAVLTreeElem ) : BOOLEAN;
  BEGIN
    RETURN GetLastI( 0, OUT Last );
  END GetLast;

(*---------------------------------------------------------------------------*)

  PUBLIC PROCEDURE PrevOf( CONST Element : TPAVLTreeElem; OUT Previous : TPAVLTreeElem ) : BOOLEAN;
  BEGIN
    RETURN PrevOfI( 0, Element, OUT Previous );
  END PrevOf;

(*---------------------------------------------------------------------------*)

  PUBLIC PROCEDURE NextOf( CONST Element : TPAVLTreeElem; OUT Next : TPAVLTreeElem ) : BOOLEAN;
  BEGIN
    RETURN NextOfI( 0, Element, OUT Next );
  END NextOf;

(*---------------------------------------------------------------------------*)

  PUBLIC PROCEDURE IndexOf( CONST Key : TPAVLTreeKey ) : INTEGER;
  BEGIN
    RETURN IndexOfI( 0, Key );
  END IndexOf;

(*---------------------------------------------------------------------------*)

  PUBLIC PROCEDURE ContainsI( i : CARDINAL; CONST Key : TPAVLTreeKey ) : BOOLEAN;
  VAR
    e : TPAVLTreeElem;
  BEGIN
    RETURN SearchI( i, Key, OUT e );
  END ContainsI;

(*---------------------------------------------------------------------------*)

  PUBLIC PROCEDURE SearchI( i : CARDINAL; CONST Key : TPAVLTreeKey; OUT Found : TPAVLTreeElem ) : BOOLEAN;

  (*----------*)

    PROCEDURE iSearch( i : CARDINAL; Element : TPAVLTreeElem ) : TPAVLTreeElem;
    VAR
      res : TRISTATE;
    BEGIN
      IF Element = NIL THEN
        RETURN NIL;
      END;
      res := Key^.Compare( i, Element );
      IF res = 1 THEN
        RETURN iSearch( i, Element^[i]^.R );
      ELSIF res = -1 THEN
        RETURN iSearch( i, Element^[i]^.L );
      ELSE
        RETURN Element;
      END;
    END iSearch;

  (*----------*)

  VAR
    lFound : TPAVLTreeElem;
  BEGIN
    lFound := iSearch( i, _Root^[i] );
    IF lFound = NIL THEN
      RETURN FALSE;
    END;
    Found := lFound;
    RETURN TRUE;
  END SearchI;

(*---------------------------------------------------------------------------*)

  PUBLIC PROCEDURE RemoveI( i : CARDINAL; CONST Key : TPAVLTreeKey; OUT Removed : TPAVLTreeElem ) : BOOLEAN;
  VAR
    pKey : TPAVLTreeKey := Key;
    pPredecessor : TPAVLTreeElem;
    pRemoved : TPAVLTreeElem := NIL;
    w : BOOLEAN := FALSE;

  (*----------*)

    PROCEDURE iRemove( i : CARDINAL; REF Element : TPAVLTreeElem; REF w : BOOLEAN );
    VAR
      res : TRISTATE;
    BEGIN
      IF Element = NIL THEN
        RETURN;
      END;

      res := pKey^.Compare( i, Element );
      IF res = -1 THEN
        iRemove( i, REF Element^[i]^.L, REF w );
        IF pRemoved <> NIL THEN
          DEC( Element^[i]^.Items );
        END;
        IF w THEN
          iRemoveBalanceL( i, REF Element, REF w );
        END;
      ELSIF res = 1 THEN
        iRemove( i, REF Element^[i]^.R, REF w );
        IF pRemoved <> NIL THEN
          DEC( Element^[i]^.Items );
        END;
        IF w THEN
          iRemoveBalanceR( i, REF Element, REF w );
        END;
      ELSE
        // disconnecting of deleting element, store it into pRemoved
        pRemoved := Element;
        WITH pRemoved^[i]^ DO

          IF R = NIL THEN
            Element := L;
            w := TRUE;
          ELSIF L = NIL THEN
            Element := R;
            w := TRUE;
          ELSE
            // search predecessor of pRemoved
            pPredecessor := iFindPredecessor( i, REF L, REF w );
            // now out of iFindPredecessor recursion replace pRemoved with pPredecessor
            pPredecessor^[i]^.L := L;
            pPredecessor^[i]^.R := R;
            pPredecessor^[i]^.Balance := Balance;
            // adjust caller's PL or PR
            Element := pPredecessor;
            IF w THEN
              iRemoveBalanceL( i, REF Element, REF w );
            END;
          END;

        END; // WITH
      END;
    END iRemove;

  (*----------*)

  VAR
    j : CARDINAL;
  BEGIN // Remove
    iRemove( i, REF _Root^[i], REF w );
    IF pRemoved = NIL THEN
      RETURN FALSE;
    ELSE
      Removed := pRemoved;
      pKey := Removed; // another keys need not be accesible in the Key passed into RemoveI
    END;
    FOR j := 0 TO _I - 1 DO
      IF i <> j THEN
        iRemove( j, REF _Root^[j], REF w );
      END;
    END;
    RETURN TRUE;
  END RemoveI;

(*---------------------------------------------------------------------------*)

  PUBLIC PROCEDURE DeleteI( i : CARDINAL; CONST Key : TPAVLTreeKey ) : BOOLEAN;
  VAR
    pDeleted : TPAVLTreeElem;
  BEGIN
    IF Remove( Key, OUT pDeleted ) THEN
      DISPOSE( pDeleted );
      RETURN TRUE;
    ELSE
      RETURN FALSE;
    END;
  END DeleteI;

(*---------------------------------------------------------------------------*)

  PUBLIC PROCEDURE PrevOfI( i : CARDINAL; CONST Element : TPAVLTreeElem; OUT Previous : TPAVLTreeElem ) : BOOLEAN;
  VAR
    pelem, pprev, ptemp : TPAVLTreeElem;
  BEGIN
    IF Element = NIL THEN
      RETURN FALSE;
    ELSE
      pelem := Element;
    END;

    pprev := NIL;
    IF pelem^[i]^.L = NIL THEN
      ptemp := _Root^[i];
      WHILE ptemp <> NIL  DO
        IF pelem^.Compare( i, ptemp ) > 0 THEN
          pprev := ptemp;
          ptemp := ptemp^[i]^.R;
        ELSE
          ptemp := ptemp^[i]^.L;
        END;
      END; // WHILE
    ELSE
      pelem := pelem^[i]^.L;
      WHILE pelem^[i]^.R <> NIL DO
        pelem := pelem^[i]^.R;
      END; // WHILE
      pprev := pelem;
    END;

    IF pprev = NIL THEN
      RETURN FALSE;
    END;
    Previous := pprev;
    RETURN TRUE;
  END PrevOfI;

(*---------------------------------------------------------------------------*)

  PUBLIC PROCEDURE NextOfI( i : CARDINAL; CONST Element : TPAVLTreeElem; OUT Next : TPAVLTreeElem ) : BOOLEAN;
  VAR
    pelem, pnext, ptemp : TPAVLTreeElem;
  BEGIN
    IF Element = NIL THEN
      RETURN FALSE;
    ELSE
      pelem := Element;
    END;

    pnext := NIL;
    IF pelem^[i]^.R = NIL THEN
      ptemp := _Root^[i];
      WHILE ptemp <> NIL DO
        IF pelem^.Compare( i, ptemp ) < 0 THEN
          pnext := ptemp;
          ptemp := ptemp^[i]^.L;
        ELSE
          ptemp := ptemp^[i]^.R;
        END;
      END;
    ELSE
      pelem := pelem^[i]^.R;
      WHILE pelem^[i]^.L <> NIL DO
        pelem := pelem^[i]^.L;
      END;
      pnext := pelem;
    END;

    IF pnext = NIL THEN
      RETURN FALSE;
    END;
    Next := pnext;
    RETURN TRUE;
  END NextOfI;

(*---------------------------------------------------------------------------*)

  PUBLIC PROCEDURE IndexOfI( i : CARDINAL; CONST Key : TPAVLTreeKey ) : INTEGER;
  VAR
    Index : INTEGER;

  (*----------*)

    PROCEDURE iGetOrderOfElem( i : CARDINAL; Element : TPAVLTreeElem ) : INTEGER;
    VAR
      res : TRISTATE;
    BEGIN
      IF Element = NIL THEN
        RETURN -1;
      END;
      WITH Element^[i]^ DO
        res := Key^.Compare( i, Element );
        IF res = -1 THEN
          DEC( Index );
          IF R <> NIL THEN
            DEC( Index, R^[i]^.Items + 1 );
          END;
          RETURN iGetOrderOfElem( i, L );
        ELSIF res = 1 THEN
          RETURN iGetOrderOfElem( i, R );
        ELSE
          IF R <> NIL THEN
            DEC( Index, R^[i]^.Items + 1 );
          END;
          RETURN Index;
        END;
      END; // WITH
    END iGetOrderOfElem;

  (*----------*)

  BEGIN
    IF Key = NIL THEN
      RETURN -1;
    END;
    Index := _Root^[i]^[i]^.Items;
    RETURN iGetOrderOfElem( i, _Root^[i] );
  END IndexOfI;

(*---------------------------------------------------------------------------*)

  PUBLIC PROCEDURE OfIndexI( i : CARDINAL; Index : INTEGER; OUT Element : TPAVLTreeElem ) : BOOLEAN;

  (*----------*)

    PROCEDURE iOfIndex( i : CARDINAL; Element : TPAVLTreeElem ) : TPAVLTreeElem;
    BEGIN
      IF Element = NIL THEN
        RETURN NIL;
      END;

      WITH Element^[i]^ DO
        IF L = NIL THEN
          DEC( Index );
        ELSIF Index <= INTEGER( L^[i]^.Items ) + 1 THEN // 1 = left
          RETURN iOfIndex( i, L );
        ELSE
          DEC( Index, L^[i]^.Items + 2 ); // 2 = self + left
        END;

        IF Index = 0 THEN
          RETURN Element;
        ELSE
          RETURN iOfIndex( i, R );
        END;
      END; // WITH
    END iOfIndex;

  (*----------*)

  VAR
    e : TPAVLTreeElem;
  BEGIN
    IF ( Index < 0 ) OR ( Index >= INTEGER( Count )) THEN
      RETURN FALSE;
    ELSE
      INC( Index );
    END;
    e := iOfIndex( i, _Root^[i] );
    IF e = NIL THEN
      RETURN FALSE;
    ELSE
      Element := e;
    END;
    RETURN TRUE;
  END OfIndexI;

(*---------------------------------------------------------------------------*)

  PUBLIC PROCEDURE GetFirstI( i : CARDINAL; OUT First : TPAVLTreeElem ) : BOOLEAN;
  VAR
    pfirst : TPAVLTreeElem;
  BEGIN
    IF _Root^[i] = NIL THEN
      RETURN FALSE;
    END;
    pfirst := _Root^[i];
    WHILE pfirst^[i]^.L <> NIL DO
      pfirst := pfirst^[i]^.L;
    END; // WHILE
    IF pfirst = NIL THEN
      RETURN FALSE;
    END;
    First := pfirst;
    RETURN TRUE;
  END GetFirstI;

(*---------------------------------------------------------------------------*)

  PUBLIC PROCEDURE GetLastI( i : CARDINAL; OUT Last : TPAVLTreeElem ) : BOOLEAN;
  VAR
    plast : TPAVLTreeElem;
  BEGIN
    IF _Root^[i] = NIL THEN
      RETURN FALSE;
    END;
    plast := _Root^[i];
    WHILE plast^[i]^.R <> NIL DO
      plast := plast^[i]^.R;
    END;
    IF plast = NIL THEN
      RETURN FALSE;
    END;
    Last := plast;
    RETURN TRUE;
  END GetLastI;

(*---------------------------------------------------------------------------*)

  INTERNAL PROCEDURE iBalanceL( i : CARDINAL; REF Element : TPAVLTreeElem );
  // BalanceL is called e.g. if left-weighty node get some another left node
  VAR
    p1, p2 : TPAVLTreeElem;
    p1i, p2i : TPAVLIndex;
  BEGIN
    WITH Element^[i]^ DO
      p1 := L;
      p1i := p1^[i];
      
      CASE p1i^.Balance OF

      | tbLeft :
        // single right rotation
        L := p1i^.R;
        p1i^.R := Element;

        p1i^.Items := Items;
        IF p1i^.L = NIL THEN
          DEC( Items, 1 );
        ELSE
          DEC( Items, p1i^.L^[i]^.Items + 2 );
        END;

        p1i^.Balance := tbNone;
        Balance := tbNone;
        Element := p1;

      | tbNone :
        // single right rotation
        L := p1i^.R;
        p1i^.R := Element;

        p1i^.Items := Items;
        IF p1i^.L = NIL THEN
          DEC( Items, 1 );
        ELSE
          DEC( Items, p1i^.L^[i]^.Items + 2 );
        END;

        p1i^.Balance := tbRight;
        Balance := tbLeft;
        Element := p1;

      | tbRight :
        // zig-zag left-right double rotation
        p2 := p1i^.R;
        p2i := p2^[i];
        
        p1i^.R := p2i^.L;
        p2i^.L := p1;
        L := p2i^.R;
        p2i^.R := Element;

        p2i^.Items := Items;
        IF L = NIL THEN
          DEC( Items, p1i^.Items + 1 );
          DEC( p1i^.Items, 1 );
        ELSE
          DEC( Items, p1i^.Items - L^[i]^.Items );
          DEC( p1i^.Items, L^[i]^.Items + 2 );
        END;

        IF p2i^.Balance = tbLeft THEN
          Balance := tbRight;
        ELSE
          Balance := tbNone;
        END;
        IF p2i^.Balance = tbRight THEN
          p1i^.Balance := tbLeft;
        ELSE
          p1i^.Balance := tbNone;
        END;
        p2i^.Balance := tbNone;
        Element := p2;

      END; // CASE
    END; // WITH
  END iBalanceL;

(*---------------------------------------------------------------------------*)

  INTERNAL PROCEDURE iBalanceR( i : CARDINAL; REF Element : TPAVLTreeElem );
  // BalanceR is called e.g. if right-weighty node get some another right node
  VAR
    p1, p2 : TPAVLTreeElem;
    p1i, p2i : TPAVLIndex;
  BEGIN
    WITH Element^[i]^ DO
      p1 := R;
      p1i := p1^[i];

      CASE p1i^.Balance OF
      | tbRight :

        // single left rotation
        R := p1i^.L;
        p1i^.L := Element;

        p1i^.Items := Items;
        IF p1i^.R = NIL THEN
          DEC( Items, 1 );
        ELSE
          DEC( Items, p1i^.R^[i]^.Items + 2 );
        END;

        p1i^.Balance := tbNone;
        Balance := tbNone;
        Element := p1;

      | tbNone :
        // single left rotation
        R := p1i^.L;
        p1i^.L := Element;

        p1i^.Items := Items;
        IF p1i^.R = NIL THEN
          DEC( Items, 1 );
        ELSE
          DEC( Items, p1i^.R^[i]^.Items + 2 );
        END;

        p1i^.Balance := tbLeft;
        Balance := tbRight;
        Element := p1;

      | tbLeft :
        // zig-zag right-left double rotation
        p2 := p1i^.L;
        p2i := p2^[i];
        
        p1i^.L := p2i^.R;
        p2i^.R := p1;
        R := p2i^.L;
        p2i^.L := Element;

        p2i^.Items := Items;
        IF R = NIL THEN
          DEC( Items, p1i^.Items + 1 );
          DEC( p1i^.Items, 1 );
        ELSE
          DEC( Items, p1i^.Items - R^[i]^.Items );
          DEC( p1i^.Items, R^[i]^.Items + 2 );
        END;

        IF p2i^.Balance = tbRight THEN
          Balance := tbLeft;
        ELSE
          Balance := tbNone;
        END;
        IF p2i^.Balance = tbLeft THEN
          p1i^.Balance := tbRight;
        ELSE
          p1i^.Balance := tbNone;
        END;
        p2i^.Balance := tbNone;
        Element := p2;

      END; // CASE
    END; // WITH
  END iBalanceR;

(*---------------------------------------------------------------------------*)

  INTERNAL PROCEDURE iRemoveBalanceL( i : CARDINAL; REF Element : TPAVLTreeElem; REF w : BOOLEAN );
  BEGIN
    WITH Element^[i]^ DO
      CASE Balance OF
      | tbLeft :
        Balance := tbNone;
      | tbNone :
        Balance := tbRight;
        w := FALSE;
      | tbRight :
        IF R^[i]^.Balance = tbNone THEN
          w :=  FALSE;
        END;
        iBalanceR( i, REF Element );
      END; // CASE
    END; // WITH
  END iRemoveBalanceL;

(*---------------------------------------------------------------------------*)

  INTERNAL PROCEDURE iRemoveBalanceR( i : CARDINAL; REF Element : TPAVLTreeElem; REF w : BOOLEAN );
  BEGIN
    WITH Element^[i]^ DO
      CASE Balance OF
      | tbRight :
        Balance := tbNone;
      | tbNone :
        Balance := tbLeft;
        w := FALSE;
      | tbLeft :
        IF L^[i]^.Balance = tbNone THEN
          w := FALSE;
        END;
        iBalanceL( i, REF Element );
      END; // CASE
    END; // WITH
  END iRemoveBalanceR;

(*---------------------------------------------------------------------------*)

  INTERNAL PROCEDURE iFindPredecessor( i : CARDINAL; REF Element : TPAVLTreeElem; REF w : BOOLEAN ) : TPAVLTreeElem;
  VAR
    Predecessor : TPAVLTreeElem;
    
  (*----------*)

    PROCEDURE iiFindPredecessor( i : CARDINAL; REF Element : TPAVLTreeElem );
    BEGIN
      WITH Element^[i]^ DO
        IF R = NIL THEN
          Predecessor := Element; // store predecessor...
          Element := L; // ...and adjust neighbours of it
          w := TRUE;
        ELSE
          iiFindPredecessor( i, REF R );
          IF w THEN
            iRemoveBalanceR( i, REF Element, REF w );
          END;
        END;
      END; // WITH
    END iiFindPredecessor;

  (*----------*)

  BEGIN
    iiFindPredecessor( i, REF Element );
    RETURN Predecessor;
  END iFindPredecessor;

(*---------------------------------------------------------------------------*)

BEGIN
  _Root := NIL;
  _I := 0;
  Indexes := 1;
FINALLY
  Dispose();
  DISPOSE( _Root );
END CAVLTree;

(*===========================================================================*)

CLASS IMPLEMENTATION CAVLTreeWState;

(*---------------------------------------------------------------------------*)

  PUBLIC READONLY PROPERTY CAVLTreeWState.Current GET : TPAVLTreeElem;
  BEGIN
    IF _Current = -1 THEN
      RETURN NIL;
    ELSE
      RETURN _Current;
    END;
  END CAVLTreeWState.Current;

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
END CAVLTreeWState;

(*===========================================================================*)

END avltree.