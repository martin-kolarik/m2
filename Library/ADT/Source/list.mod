IMPLEMENTATION MODULE list;

FROM Debug IMPORT
   Assertion, LogAssertionW;

IMPORT
   Sync;

(*===========================================================================*)
// Bidirectional list

CLASS IMPLEMENTATION CListElem;

(*---------------------------------------------------------------------------*)

   PUBLIC PROPERTY PrevOf GET : TPListElem;
   BEGIN
      RETURN PPrev;
   END PrevOf;

(*---------------------------------------------------------------------------*)

   PUBLIC PROPERTY NextOf GET : TPListElem;
   BEGIN
      RETURN PNext;
   END NextOf;

(*---------------------------------------------------------------------------*)

BEGIN
   PPrev := NIL;
   PNext := NIL;
END CListElem;

(*===========================================================================*)

CLASS IMPLEMENTATION CList;

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

   PUBLIC PROPERTY CList.Count GET : CARDINAL;
   BEGIN
      RETURN _Count;
   END CList.Count;

(*---------------------------------------------------------------------------*)

   PUBLIC PROPERTY CList.Empty GET : BOOLEAN;
   BEGIN
      RETURN PFirst = NIL;
   END CList.Empty;

(*---------------------------------------------------------------------------*)

   PUBLIC PROPERTY CList.Sequence GET : CARDINAL;
   BEGIN
      RETURN Sync.IGet( REF _Sequence );
   END CList.Sequence;

(*---------------------------------------------------------------------------*)

   PUBLIC VIRTUAL PROCEDURE colGetIterator( direction : collection.TDirection ) : collection.TPIterator;
   BEGIN
      RETURN GetIterator( direction );
   END colGetIterator;

(*---------------------------------------------------------------------------*)

   PUBLIC VIRTUAL PROCEDURE colGetFirst( OUT object : baseobject.PBASE ) : BOOLEAN;
   BEGIN
      IF PFirst = NIL THEN
         RETURN FALSE;
      ELSE
         object := PFirst;
         RETURN TRUE;
      END;
   END colGetFirst;

(*---------------------------------------------------------------------------*)

   PUBLIC VIRTUAL PROCEDURE colNextOf( CONST of : baseobject.PBASE; OUT object : baseobject.PBASE ) : BOOLEAN;
   BEGIN
      ASSERTLOG( of^ IS LOOSE CListElem, L"Unexpected class used" );
      IF TPListElem( of )^.PNext = NIL THEN
         RETURN FALSE;
      ELSE
         object := TPListElem( of )^.PNext;
         RETURN TRUE;
      END;
   END colNextOf;

(*---------------------------------------------------------------------------*)

   PUBLIC VIRTUAL PROCEDURE colGetLast( OUT object : baseobject.PBASE ) : BOOLEAN;
   BEGIN
      IF PLast = NIL THEN
         RETURN FALSE;
      ELSE
         object := PLast;
         RETURN TRUE;
      END;
   END colGetLast;

(*---------------------------------------------------------------------------*)

   PUBLIC VIRTUAL PROCEDURE colPrevOf( CONST of : baseobject.PBASE; OUT object : baseobject.PBASE ) : BOOLEAN;
   BEGIN
      ASSERTLOG( of^ IS LOOSE CListElem, L"Unexpected class used" );
      IF TPListElem( of )^.PPrev = NIL THEN
         RETURN FALSE;
      ELSE
         object := TPListElem( of )^.PPrev;
         RETURN TRUE;
      END;
   END colPrevOf;

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

   PUBLIC PROCEDURE Add( PElem : TPListElem );
   BEGIN
      Sync.IInc( REF _Sequence );
      PElem^.PNext := NIL;
      IF PFirst = NIL THEN
         PFirst := PElem;
         PElem^.PPrev := NIL;
      ELSE
         PLast^.PNext := PElem;
         PElem^.PPrev := PLast;
      END;
      PLast := PElem;
      INC( _Count );
   END Add;

(*---------------------------------------------------------------------------*)

   PUBLIC PROCEDURE Remove( PElem : TPListElem );
   BEGIN
      Sync.IInc( REF _Sequence );
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
      DEC( _Count );
   END Remove;

(*---------------------------------------------------------------------------*)

   PUBLIC PROCEDURE Delete( PElem : TPListElem );
   BEGIN
      Remove( PElem );
      DISPOSE( PElem );
   END Delete;

(*---------------------------------------------------------------------------*)

   PUBLIC PROCEDURE ElementAt( Index : CARDINAL; OUT PElem : TPListElem ) : BOOLEAN;
   BEGIN
      IF Index >= _Count THEN
         RETURN FALSE;
      END;
      PElem := PFirst;
      WHILE Index > 0 DO
         PElem := PElem^.PNext;
         DEC( Index );
      END;
      RETURN TRUE;
   END ElementAt;

(*---------------------------------------------------------------------------*)

   PUBLIC PROCEDURE InsertFirst( PElem : TPListElem );
   BEGIN
      Sync.IInc( REF _Sequence );
      PElem^.PPrev := NIL;
      IF PFirst = NIL THEN
         PLast := PElem;
      ELSE
         PFirst^.PPrev := PElem;
      END;
      PElem^.PNext := PFirst;
      PFirst := PElem;
      INC( _Count );
   END InsertFirst;

(*---------------------------------------------------------------------------*)

   PUBLIC PROCEDURE InsertBefore( PBefore, PElem : TPListElem );
   BEGIN
      IF PBefore = NIL THEN
         InsertFirst( PElem );
      ELSE
         Sync.IInc( REF _Sequence );
         PElem^.PPrev := PBefore^.PPrev;
         IF PElem^.PPrev = NIL THEN
            PFirst := PElem;
         ELSE
            PElem^.PPrev^.PNext := PElem;
         END;
         PElem^.PNext := PBefore;
         PBefore^.PPrev := PElem;
         INC( _Count );
      END;
   END InsertBefore;

(*---------------------------------------------------------------------------*)

   PUBLIC PROCEDURE AppendList( REF List : CList );
   BEGIN
      IF List.PFirst <> NIL THEN
         Sync.IInc( REF _Sequence );
         IF PFirst = NIL THEN
            PFirst := List.PFirst;
         ELSE
            PLast^.PNext := List.PFirst;
            List.PFirst^.PPrev := PLast;
         END;
         PLast := List.PLast;
         INC( _Count, List.Count );
         List.Clear();
      END;
   END AppendList;

(*---------------------------------------------------------------------------*)

   PUBLIC PROCEDURE IndexOf( CONST Element : TPListElem ): INTEGER;
   VAR
      I : CARDINAL := 0;
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

   PUBLIC PROCEDURE Clear();
   BEGIN
      PFirst := NIL;
      PLast := NIL;
      _Count := 0;
   END Clear;

(*---------------------------------------------------------------------------*)

   PUBLIC PROCEDURE GetIterator( Direction : collection.TDirection ) : TPListIterator;
   VAR
      iterator : TPListIterator := NEW( CListIterator );
   BEGIN
      iterator^.Init( ADR( SELF ), Direction );
      RETURN iterator;
   END GetIterator;

(*---------------------------------------------------------------------------*)

   PUBLIC PROCEDURE Enqueue( PElem : TPListElem );
   BEGIN
      Add( PElem );
   END Enqueue;

(*---------------------------------------------------------------------------*)

   PUBLIC PROCEDURE Dequeue( OUT PElem : TPListElem ) : BOOLEAN; 
   BEGIN
      IF NOT colGetFirst( OUT PElem ) THEN
         RETURN FALSE;
      END;
      Remove( PElem );
      RETURN TRUE;
   END Dequeue;

(*---------------------------------------------------------------------------*)

BEGIN FINALLY
   Dispose();
END CList;

(*===========================================================================*)

CLASS IMPLEMENTATION CListIterator;

(*---------------------------------------------------------------------------*)

   PUBLIC PROPERTY Current GET : TPListElem;
   BEGIN
      RETURN TPListElem( colCurrent );
   END Current;

(*---------------------------------------------------------------------------*)

END CListIterator;

(*===========================================================================*)

END list.