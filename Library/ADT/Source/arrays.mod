IMPLEMENTATION MODULE arrays;

FROM Storage IMPORT
   ALLOCATE, DEALLOCATE;

FROM Debug IMPORT
   Assertion, LogAssertionW;

FROM Exceptions IMPORT
   TestIfCatched, CModula2Exception;

(*=============================================================================*)

CLASS IMPLEMENTATION CIntegerArray;

(*-----------------------------------------------------------------------------*)

   PUBLIC INDEX CIntegerArray GET( Index : INTEGER ) : INTEGER;
   VAR
      self : array.TPArray := ADR( SELF ); // #246 shall allow RETURN SUPER[Index] and omit "self";
   BEGIN
      TRY
         RETURN PINTEGER( self^[Index] )^; // #246 shall allow RETURN SUPER[Index] and omit "self";
      CATCH : CModula2Exception DO
         // do nothing
      END;
      RETURN 0;
   END CIntegerArray;

(*-----------------------------------------------------------------------------*)

   PUBLIC INDEX CIntegerArray SET( Index : INTEGER; Value : INTEGER );
   VAR
      self : array.TPArray := ADR( SELF ); // #246 shall allow to use SUPER[Index] and omit "self";
   BEGIN
      TRY
         self^[Index] := ADR( Value );
      CATCH : CModula2Exception DO
         // do nothing
      END;
   END CIntegerArray;

(*-----------------------------------------------------------------------------*)

   PUBLIC PROCEDURE Contains( Value : INTEGER ) : BOOLEAN;
   BEGIN
      RETURN SUPER.Contains( Value );
   END Contains;

(*-----------------------------------------------------------------------------*)

   PUBLIC PROCEDURE Add( Value : INTEGER ) : INTEGER; // returns index
   BEGIN
      RETURN SUPER.Add( Value );
   END Add;

(*-----------------------------------------------------------------------------*)

   PUBLIC PROCEDURE Insert( ToIndex : INTEGER; Value : INTEGER );
   BEGIN
      SUPER.Insert( ToIndex, Value );
   END Insert;

(*-----------------------------------------------------------------------------*)

   PUBLIC PROCEDURE Remove( Value : INTEGER );
   BEGIN
      SUPER.Remove( Value );
   END Remove;

(*-----------------------------------------------------------------------------*)

   PUBLIC PROCEDURE ElementAt( Index : INTEGER; OUT Value : INTEGER ) : BOOLEAN;
   BEGIN
      RETURN SUPER.ElementAt( Index, OUT Value );
   END ElementAt;

(*-----------------------------------------------------------------------------*)

   PUBLIC PROCEDURE IndexOf( Value : INTEGER ) : INTEGER;
   BEGIN
      RETURN SUPER.IndexOf( Value );
   END IndexOf;

(*-----------------------------------------------------------------------------*)

   PUBLIC PROCEDURE GetIterator( Direction : collection.TDirection ) : TPIntegerArrayIterator;
   VAR
      iterator : TPIntegerArrayIterator := NEW( CIntegerArrayIterator );
   BEGIN
      iterator^.Init( ADR( SELF ), Direction );
      RETURN iterator;
   END GetIterator;

(*-----------------------------------------------------------------------------*)

   PUBLIC PROCEDURE Enqueue( Value : INTEGER );
   BEGIN
      SUPER.Enqueue( Value );
   END Enqueue;

(*-----------------------------------------------------------------------------*)

   PUBLIC PROCEDURE Dequeue( OUT Value : INTEGER ) : BOOLEAN; 
   BEGIN
      RETURN SUPER.Dequeue( OUT Value );
   END Dequeue;

(*-----------------------------------------------------------------------------*)

   PRIVATE PROCEDURE Init();
   BEGIN
      SUPER.Init( array.astrgSparseArray, 0, SIZE( INTEGER ));
   END Init;

(*-----------------------------------------------------------------------------*)

BEGIN
   Init();
END CIntegerArray;

(*=============================================================================*)

CLASS IMPLEMENTATION CIntegerArrayIterator;

(*-----------------------------------------------------------------------------*)

   PUBLIC PROPERTY Value GET : INTEGER;
   BEGIN
      RETURN PINTEGER( colCurrent )^;
   END Value;

(*-----------------------------------------------------------------------------*)

END CIntegerArrayIterator;

(*=============================================================================*)

CLASS IMPLEMENTATION CBaseArray;

(*-----------------------------------------------------------------------------*)

   PUBLIC INDEX CBaseArray GET( Index : INTEGER ) : baseobject.PIBASE;
   VAR
      self : array.TPArray := ADR( SELF );
   BEGIN
      TRY
         RETURN self^[Index]; // #246 shall allow RETURN SUPER[Index] and omit "self";
      CATCH : CModula2Exception DO
         // do nothing
      END;
      RETURN NIL;
   END CBaseArray;

(*-----------------------------------------------------------------------------*)

   PUBLIC INDEX CBaseArray SET( Index : INTEGER; Value : baseobject.PIBASE );
   VAR
      self : array.TPArray := ADR( SELF ); // #246 shall allow RETURN SUPER[Index] and omit "self";
   BEGIN
      TRY
         DisposeOwned( baseobject.PIBASE( self^[Index] )); // #246 shall allow RETURN SUPER[Index] and omit "self";
         self^[Index] := ADR( Value ); // #246 shall allow RETURN SUPER[Index] and omit "self";
      CATCH : CModula2Exception DO
         // do nothing
      END;
   END CBaseArray;

(*-----------------------------------------------------------------------------*)

   PUBLIC PROCEDURE Add( Value : baseobject.PIBASE ) : INTEGER; // returns index
   BEGIN
      RETURN SUPER.Add( Value );
   END Add;

(*-----------------------------------------------------------------------------*)

   PUBLIC PROCEDURE Contains( Value : baseobject.PIBASE ) : BOOLEAN;
   BEGIN
      RETURN SUPER.Contains( Value );
   END Contains;

(*-----------------------------------------------------------------------------*)

   PUBLIC PROCEDURE Insert( ToIndex : INTEGER; Value : baseobject.PIBASE );
   BEGIN
      SUPER.Insert( ToIndex, Value );
   END Insert;

(*-----------------------------------------------------------------------------*)

   PUBLIC PROCEDURE Remove( Value : baseobject.PIBASE );
   BEGIN
      DisposeOwned( Value );
      SUPER.Remove( Value );
   END Remove;

(*-----------------------------------------------------------------------------*)

   PUBLIC PROCEDURE ElementAt( Index : INTEGER; OUT Value : baseobject.PIBASE ) : BOOLEAN;
   BEGIN
      RETURN SUPER.ElementAt( Index, OUT Value );
   END ElementAt;

(*-----------------------------------------------------------------------------*)

   PUBLIC PROCEDURE IndexOf( Value : baseobject.PIBASE ) : INTEGER;
   BEGIN
      RETURN SUPER.IndexOf( Value );
   END IndexOf;

(*-----------------------------------------------------------------------------*)

   PUBLIC PROCEDURE GetIterator( Direction : collection.TDirection ) : TPBaseArrayIterator;
   VAR
      iterator : TPBaseArrayIterator := NEW( CBaseArrayIterator );
   BEGIN
      iterator^.Init( ADR( SELF ), Direction );
      RETURN iterator;
   END GetIterator;

(*-----------------------------------------------------------------------------*)

   PUBLIC PROCEDURE Enqueue( Value : baseobject.PIBASE );
   BEGIN
      SUPER.Enqueue( Value );
   END Enqueue;

(*-----------------------------------------------------------------------------*)

   PUBLIC PROCEDURE Dequeue( OUT Value : baseobject.PIBASE ) : BOOLEAN; 
   BEGIN
      RETURN SUPER.Dequeue( OUT Value );
   END Dequeue;

(*-----------------------------------------------------------------------------*)

   PUBLIC PROPERTY DataOwnership GET : BOOLEAN;
   BEGIN
      RETURN _DataOwnership;
   END DataOwnership;

(*-----------------------------------------------------------------------------*)

   PUBLIC PROPERTY DataOwnership SET( Value : BOOLEAN );
   BEGIN
      _DataOwnership := Value;
   END DataOwnership;

(*-----------------------------------------------------------------------------*)

   PRIVATE PROCEDURE Init();
   BEGIN
      SUPER.Init( array.astrgSparseArray, 0, SIZE( baseobject.PIBASE ));
   END Init;

(*-----------------------------------------------------------------------------*)

   PRIVATE PROCEDURE DisposeOwned( Data : baseobject.PIBASE );
   BEGIN
      IF ( Data <> NIL ) AND _DataOwnership THEN
         IF Data^ INHERITS baseobject.CRefcounted THEN
            baseobject.TPRefcounted( Data )^.Release();
         ELSIF Data^ INHERITS baseobject.CDisposable THEN 
            baseobject.TPDisposable( Data )^.Dispose();
            DISPOSE( baseobject.TPDisposable( Data ));
         ELSIF Data^ INHERITS baseobject.BASE THEN
            DISPOSE( baseobject.PBASE( Data ));
         ELSE
            ASSERTLOG( FALSE, L"Unable to deallocate array item -- unknown class" );
         END;
      END;
   END DisposeOwned;

(*-----------------------------------------------------------------------------*)

BEGIN
   Init();
END CBaseArray;

(*=============================================================================*)

CLASS IMPLEMENTATION CBaseArrayIterator;

(*-----------------------------------------------------------------------------*)

   PUBLIC PROPERTY Value GET : baseobject.PIBASE;
   BEGIN
      RETURN colCurrent;
   END Value;

(*-----------------------------------------------------------------------------*)

END CBaseArrayIterator;

(*=============================================================================*)

END arrays.