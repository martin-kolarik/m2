IMPLEMENTATION MODULE arrays;

FROM Storage IMPORT
   ALLOCATE, DEALLOCATE;

FROM Debug IMPORT
   AssertionW;

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
      iterator^.Init( SELF, Direction );
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

   PUBLIC PROPERTY Data GET : TPRawIntegerArray; 
   BEGIN
      RETURN SUPER.Data;
   END Data;

(*-----------------------------------------------------------------------------*)

   PRIVATE PROCEDURE Init();
   BEGIN
      Strategy := array.astrgSparseArray;
      LowBound := 0;
      ItemSize := SIZE( INTEGER );
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

   PUBLIC PROCEDURE Init( CONST OfCollection : CIntegerArray; Direction : collection.TDirection );
   BEGIN
      SUPER.Init( OfCollection, Direction );
   END Init;

(*-----------------------------------------------------------------------------*)

END CIntegerArrayIterator;

(*=============================================================================*)

CLASS IMPLEMENTATION CPtrArray;

(*-----------------------------------------------------------------------------*)

   PUBLIC INDEX CPtrArray GET( Index : INTEGER ) : PTR;
   VAR
      self : array.TPArray := ADR( SELF );
   BEGIN
      TRY
         RETURN PPTR( self^[Index] )^; // #246 shall allow RETURN SUPER[Index] and omit "self";
      CATCH : CModula2Exception DO
         // do nothing
      END;
      RETURN NIL;
   END CPtrArray;

(*-----------------------------------------------------------------------------*)

   PUBLIC INDEX CPtrArray SET( Index : INTEGER; Value : PTR );
   VAR
      self : array.TPArray := ADR( SELF ); // #246 shall allow RETURN SUPER[Index] and omit "self";
   BEGIN
      TRY
         DisposeOwned( PPTR( self^[Index] )^ ); // #246 shall allow RETURN SUPER[Index] and omit "self";
         self^[Index] := ADR( Value ); // #246 shall allow RETURN SUPER[Index] and omit "self";
      CATCH : CModula2Exception DO
         // do nothing
      END;
   END CPtrArray;

(*-----------------------------------------------------------------------------*)

   PUBLIC PROCEDURE Add( Value : PTR ) : INTEGER; // returns index
   BEGIN
      RETURN SUPER.Add( Value );
   END Add;

(*-----------------------------------------------------------------------------*)

   PUBLIC PROCEDURE Contains( Value : PTR ) : BOOLEAN;
   BEGIN
      RETURN SUPER.Contains( Value );
   END Contains;

(*-----------------------------------------------------------------------------*)

   PUBLIC PROCEDURE Insert( ToIndex : INTEGER; Value : PTR );
   BEGIN
      SUPER.Insert( ToIndex, Value );
   END Insert;

(*-----------------------------------------------------------------------------*)

   PUBLIC PROCEDURE Remove( Value : PTR );
   BEGIN
      DisposeOwned( Value );
      SUPER.Remove( Value );
   END Remove;

(*-----------------------------------------------------------------------------*)

   PUBLIC PROCEDURE ElementAt( Index : INTEGER; OUT Value : PTR ) : BOOLEAN;
   BEGIN
      RETURN SUPER.ElementAt( Index, OUT Value );
   END ElementAt;

(*-----------------------------------------------------------------------------*)

   PUBLIC PROCEDURE IndexOf( Value : PTR ) : INTEGER;
   BEGIN
      RETURN SUPER.IndexOf( Value );
   END IndexOf;

(*-----------------------------------------------------------------------------*)

   PUBLIC PROCEDURE GetIterator( Direction : collection.TDirection ) : TPPtrArrayIterator;
   VAR
      iterator : TPPtrArrayIterator := NEW( CPtrArrayIterator );
   BEGIN
      iterator^.Init( SELF, Direction );
      RETURN iterator;
   END GetIterator;

(*-----------------------------------------------------------------------------*)

   PUBLIC PROCEDURE Enqueue( Value : PTR );
   BEGIN
      SUPER.Enqueue( Value );
   END Enqueue;

(*-----------------------------------------------------------------------------*)

   PUBLIC PROCEDURE Dequeue( OUT Value : PTR ) : BOOLEAN; 
   BEGIN
      RETURN SUPER.Dequeue( OUT Value );
   END Dequeue;

(*-----------------------------------------------------------------------------*)

   PUBLIC PROPERTY Data GET : TPRawPtrArray; 
   BEGIN
      RETURN SUPER.Data;
   END Data;

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
      Strategy := array.astrgSparseArray;
      LowBound := 0;
      ItemSize := SIZE( PTR );
   END Init;

(*-----------------------------------------------------------------------------*)

   PRIVATE PROCEDURE DisposeOwned( Data : PTR );
   BEGIN
      IF ( Data <> NIL ) AND _DataOwnership THEN
         IF baseobject.PBASE( Data )^ INHERITS baseobject.CRefcounted THEN // dangerous, m2cpp has to define OBJECT
            baseobject.TPRefcounted( Data )^.Release();
         ELSIF baseobject.PBASE( Data )^ INHERITS baseobject.CDisposable THEN 
            baseobject.TPDisposable( Data )^.Dispose();
            DISPOSE( baseobject.TPDisposable( Data ));
         ELSIF baseobject.PBASE( Data )^ INHERITS baseobject.BASE THEN
            DISPOSE( baseobject.PBASE( Data ));
         ELSE
            ASSERTLOG( FALSE, L"Unable to deallocate array item -- unknown class" );
         END;
      END;
   END DisposeOwned;

(*-----------------------------------------------------------------------------*)

BEGIN
   Init();
END CPtrArray;

(*=============================================================================*)

CLASS IMPLEMENTATION CPtrArrayIterator;

(*-----------------------------------------------------------------------------*)

   PUBLIC PROPERTY Value GET : PTR;
   BEGIN
      RETURN colCurrent;
   END Value;

(*-----------------------------------------------------------------------------*)

   PUBLIC PROCEDURE Init( CONST OfCollection : CPtrArray; Direction : collection.TDirection );
   BEGIN
      SUPER.Init( OfCollection, Direction );
   END Init;

(*-----------------------------------------------------------------------------*)

END CPtrArrayIterator;

(*=============================================================================*)

END arrays.