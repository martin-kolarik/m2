IMPLEMENTATION MODULE collection;

(*===========================================================================*)

CLASS IMPLEMENTATION CIterator;

(*---------------------------------------------------------------------------*)

   PUBLIC FINAL PROPERTY colCurrent GET : baseobject.PBASE;
   BEGIN
      IF _Exhausted THEN
         RETURN NIL;
      ELSIF _StartSequence <> _OfCollection^.Sequence THEN
         _Exhausted := TRUE;
         RETURN NIL;
      ELSE
         RETURN _Current;
      END;
   END colCurrent;

(*---------------------------------------------------------------------------*)

   PUBLIC FINAL PROCEDURE Reset();
   BEGIN
      _Current := NIL;
      _Exhausted := FALSE;
      _StartSequence := _OfCollection^.Sequence;
   END Reset;

(*---------------------------------------------------------------------------*)

   PUBLIC FINAL PROCEDURE MoveNext() : BOOLEAN;
   BEGIN
      IF _Exhausted THEN
         // fall down
      ELSIF _StartSequence <> _OfCollection^.Sequence THEN // owning collection has changed
         _Exhausted := FALSE;
      ELSIF _Current = NIL THEN
         _Exhausted := NOT _OfCollection^.colGetFirst( OUT _Current );
      ELSE
         _Exhausted := NOT _OfCollection^.colNextOf( _Current, OUT _Current );
      END;
      RETURN _Exhausted;
   END MoveNext;

(*---------------------------------------------------------------------------*)

   PUBLIC FINAL PROPERTY Implementor GET : baseobject.TPDisposable; // the object to be disposed, when TPIterator is to be disposed (interface cannot be disposed)
   BEGIN
      RETURN ADR( SELF );
   END Implementor;

(*---------------------------------------------------------------------------*)

   PUBLIC FINAL PROPERTY OfCollection GET : TPCollection; // the object to be disposed, when TPIterator is to be disposed (interface cannot be disposed)
   BEGIN
      RETURN _OfCollection;
   END OfCollection;

(*---------------------------------------------------------------------------*)

   PUBLIC PROCEDURE Init( ofCollection : TPCollection ); // the collection must initialize the iterator with self
   BEGIN
      _OfCollection := ofCollection;
      _StartSequence := ofCollection^.Sequence;
   END Init;

(*---------------------------------------------------------------------------*)

BEGIN
END CIterator;

(*==========================================================================*)

END collection.