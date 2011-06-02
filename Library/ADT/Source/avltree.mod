IMPLEMENTATION MODULE avltree;

(*===========================================================================*)
//
// basic single and double AVL tree ADT 
//
// version 5 (base Honzik, removing of FREE during Delete mk, more keys mk)
//
(*===========================================================================*)

FROM Storage IMPORT
   REALLOCATE, Fill;

FROM Debug IMPORT
   Assertion, LogAssertionW;

IMPORT
   Sync;

(*===========================================================================*)

CLASS IMPLEMENTATION AAVLTreeElem;
END AAVLTreeElem;

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

   PUBLIC FINAL PROPERTY CAVLTree.KeyCount GET : CARDINAL;
   BEGIN
      RETURN _KeyCount;
   END CAVLTree.KeyCount;

(*---------------------------------------------------------------------------*)

   PUBLIC FINAL PROPERTY CAVLTree.Sequence GET : CARDINAL;
   BEGIN
      RETURN Sync.IGet( REF _Sequence );
   END CAVLTree.Sequence;

(*---------------------------------------------------------------------------*)

   PUBLIC FINAL PROPERTY CAVLTree.KeyCount SET( Value : CARDINAL );
   VAR
      i : CARDINAL;
   BEGIN
      i := MAX2( 1, Value );
      IF i = _KeyCount THEN
         RETURN;
      END;
      REALLOCATE( REF _Root, i * SIZE( TAVLIndex ));
      IF i > _KeyCount THEN
         Fill( ADR( _Root^[_KeyCount] ), ( i-_KeyCount ) * SIZE( TAVLIndex ), 0 );
      END;
      _KeyCount := i;
   END CAVLTree.KeyCount;

(*---------------------------------------------------------------------------*)

   PUBLIC VIRTUAL PROCEDURE colGetIterator( direction : collection.TDirection ) : collection.TPIterator;
   BEGIN
      RETURN GetIterator( direction );
   END colGetIterator;

(*---------------------------------------------------------------------------*)

   PUBLIC VIRTUAL PROCEDURE colGetFirst( OUT object : baseobject.PBASE ) : BOOLEAN;
   VAR
      element : TPAVLTreeElem;
   BEGIN
      IF GetFirst( 0, OUT element ) THEN
         object := element;
         RETURN TRUE;
      ELSE
         RETURN FALSE;
      END;
   END colGetFirst;

(*---------------------------------------------------------------------------*)

   PUBLIC VIRTUAL PROCEDURE colNextOf( CONST of : baseobject.PBASE; OUT object : baseobject.PBASE ) : BOOLEAN;
   VAR
      element : TPAVLTreeElem;
   BEGIN
      ASSERTLOG( of^ IS LOOSE AAVLTreeElem, L"Unexpected class used" );
      IF NextOf( 0, TPAVLTreeElem( of ), OUT element ) THEN
         object := element;
         RETURN TRUE;
      ELSE
         RETURN FALSE;
      END;
   END colNextOf;

(*---------------------------------------------------------------------------*)

   PUBLIC VIRTUAL PROCEDURE colGetLast( OUT object : baseobject.PBASE ) : BOOLEAN;
   VAR
      element : TPAVLTreeElem;
   BEGIN
      IF GetLast( 0, OUT element ) THEN
         object := element;
         RETURN TRUE;
      ELSE
         RETURN FALSE;
      END;
   END colGetLast;

(*---------------------------------------------------------------------------*)

   PUBLIC VIRTUAL PROCEDURE colPrevOf( CONST of : baseobject.PBASE; OUT object : baseobject.PBASE ) : BOOLEAN;
   VAR
      element : TPAVLTreeElem;
   BEGIN
      ASSERTLOG( of^ IS LOOSE AAVLTreeElem, L"Unexpected class used" );
      IF PrevOf( 0, TPAVLTreeElem( of ), OUT element ) THEN
         object := element;
         RETURN TRUE;
      ELSE
         RETURN FALSE;
      END;
   END colPrevOf;

(*---------------------------------------------------------------------------*)

   PUBLIC PROCEDURE Add( Inserted : TPAVLTreeElem );
   VAR
      w : BOOLEAN;

   (*----------*)

      PROCEDURE iAdd( i : CARDINAL; REF Element : TPAVLTreeElem );
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

               iAdd( i, REF L );
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

               iAdd( i, REF R );
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
               ASSERTLOG( FALSE, L"Existing key inserted" );
            END;
         END; // WITH
      END iAdd;

   (*----------*)

   VAR
      i : CARDINAL;
   BEGIN
      Sync.IInc( REF _Sequence );
      FOR i := 0 TO _KeyCount - 1 DO
         iAdd( i, REF _Root^[i] );
      END;
   END Add;

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
         Element^.Dispose();
         DISPOSE( Element );
      END iDispose;

   (*----------*)

   BEGIN
      IF _Root <> NIL THEN
         Sync.IInc( REF _Sequence );
         iDispose( REF _Root^[0] );
      END;
   END Dispose;

(*---------------------------------------------------------------------------*)

   PUBLIC PROCEDURE Contains( i : CARDINAL; CONST Key : TPAVLTreeKey ) : BOOLEAN;
   VAR
      e : TPAVLTreeElem;
   BEGIN
       RETURN Get( i, Key, OUT e );
   END Contains;

(*---------------------------------------------------------------------------*)

  PUBLIC PROCEDURE Get( i : CARDINAL; CONST Key : TPAVLTreeKey; OUT Found : TPAVLTreeElem ) : BOOLEAN;

  (*----------*)

      PROCEDURE iGet( i : CARDINAL; Element : TPAVLTreeElem ) : TPAVLTreeElem;
      VAR
         res : TRISTATE;
      BEGIN
         IF Element = NIL THEN
            RETURN NIL;
         END;
         res := Key^.Compare( i, Element );
         IF res = 1 THEN
            RETURN iGet( i, Element^[i]^.R );
         ELSIF res = -1 THEN
            RETURN iGet( i, Element^[i]^.L );
         ELSE
            RETURN Element;
         END;
      END iGet;

   (*----------*)

   VAR
      lFound : TPAVLTreeElem;
   BEGIN
      lFound := iGet( i, _Root^[i] );
      IF lFound = NIL THEN
         RETURN FALSE;
      END;
      Found := lFound;
      RETURN TRUE;
   END Get;

(*---------------------------------------------------------------------------*)

   PUBLIC PROCEDURE Remove( i : CARDINAL; CONST Key : TPAVLTreeKey; OUT Removed : TPAVLTreeElem ) : BOOLEAN;
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
      Sync.IInc( REF _Sequence );
      iRemove( i, REF _Root^[i], REF w );
      IF pRemoved = NIL THEN
         RETURN FALSE;
      ELSE
         Removed := pRemoved;
         pKey := Removed; // another keys need not be accesible in the Key passed into RemoveI
      END;
      FOR j := 0 TO _KeyCount - 1 DO
         IF i <> j THEN
            iRemove( j, REF _Root^[j], REF w );
         END;
      END;
      RETURN TRUE;
   END Remove;

(*---------------------------------------------------------------------------*)

  PUBLIC PROCEDURE Delete( i : CARDINAL; CONST Key : TPAVLTreeKey ) : BOOLEAN;
  VAR
    pDeleted : TPAVLTreeElem;
  BEGIN
    IF Remove( i, Key, OUT pDeleted ) THEN
      pDeleted^.Dispose();
      DISPOSE( pDeleted );
      RETURN TRUE;
    ELSE
      RETURN FALSE;
    END;
  END Delete;

(*---------------------------------------------------------------------------*)

   PUBLIC PROCEDURE ElementAt( i : CARDINAL; Index : CARDINAL; OUT Element : TPAVLTreeElem ) : BOOLEAN;

   (*----------*)

      PROCEDURE iElementAt( i : CARDINAL; Element : TPAVLTreeElem ) : TPAVLTreeElem;
      BEGIN
         IF Element = NIL THEN
            RETURN NIL;
         END;
         WITH Element^[i]^ DO
            IF L = NIL THEN
               DEC( Index );
            ELSIF Index <= L^[i]^.Items + 1 THEN // 1 = left
               RETURN iElementAt( i, L );
            ELSE
               DEC( Index, L^[i]^.Items + 2 ); // 2 = self + left
            END;

            IF Index = 0 THEN
               RETURN Element;
            ELSE
               RETURN iElementAt( i, R );
            END;
         END; // WITH
      END iElementAt;

   (*----------*)

   VAR
      e : TPAVLTreeElem;
   BEGIN
      IF Index >= Count THEN
         RETURN FALSE;
      ELSE
         INC( Index );
      END;
      e := iElementAt( i, _Root^[i] );
      IF e = NIL THEN
         RETURN FALSE;
      ELSE
         Element := e;
      END;
      RETURN TRUE;
   END ElementAt;

(*---------------------------------------------------------------------------*)

  PUBLIC PROCEDURE PrevOf( i : CARDINAL; CONST Element : TPAVLTreeElem; OUT Previous : TPAVLTreeElem ) : BOOLEAN;
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
  END PrevOf;

(*---------------------------------------------------------------------------*)

  PUBLIC PROCEDURE NextOf( i : CARDINAL; CONST Element : TPAVLTreeElem; OUT Next : TPAVLTreeElem ) : BOOLEAN;
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
  END NextOf;

(*---------------------------------------------------------------------------*)

  PUBLIC PROCEDURE IndexOf( i : CARDINAL; CONST Key : TPAVLTreeKey ) : CARDINAL;
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
  END IndexOf;

(*---------------------------------------------------------------------------*)

   PUBLIC PROCEDURE GetIterator( Direction : collection.TDirection ) : TPAVLTreeIterator;
   VAR
      iterator : TPAVLTreeIterator := NEW( CAVLTreeIterator );
   BEGIN
      iterator^.Init( SELF, Direction );
      RETURN iterator;
   END GetIterator;

(*---------------------------------------------------------------------------*)

  PUBLIC PROCEDURE GetFirst( i : CARDINAL; OUT First : TPAVLTreeElem ) : BOOLEAN;
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
  END GetFirst;

(*---------------------------------------------------------------------------*)

  PUBLIC PROCEDURE GetLast( i : CARDINAL; OUT Last : TPAVLTreeElem ) : BOOLEAN;
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
  END GetLast;

(*---------------------------------------------------------------------------*)

   PRIVATE PROCEDURE iBalanceL( i : CARDINAL; REF Element : TPAVLTreeElem );
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

   PRIVATE PROCEDURE iBalanceR( i : CARDINAL; REF Element : TPAVLTreeElem );
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

   PRIVATE PROCEDURE iRemoveBalanceL( i : CARDINAL; REF Element : TPAVLTreeElem; REF w : BOOLEAN );
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

   PRIVATE PROCEDURE iRemoveBalanceR( i : CARDINAL; REF Element : TPAVLTreeElem; REF w : BOOLEAN );
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

   PRIVATE PROCEDURE iFindPredecessor( i : CARDINAL; REF Element : TPAVLTreeElem; REF w : BOOLEAN ) : TPAVLTreeElem;
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
   _KeyCount := 0;
   KeyCount := 1;
FINALLY
   Dispose();
   DISPOSE( _Root );
END CAVLTree;

(*===========================================================================*)

CLASS IMPLEMENTATION CAVLTreeIterator;

(*---------------------------------------------------------------------------*)

   PUBLIC PROPERTY Current GET : TPAVLTreeElem;
   BEGIN
      RETURN TPAVLTreeElem( colCurrent );
   END Current;

(*---------------------------------------------------------------------------*)

END CAVLTreeIterator;

(*===========================================================================*)

END avltree.