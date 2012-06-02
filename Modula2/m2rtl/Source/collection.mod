IMPLEMENTATION MODULE collection;

FROM Debug IMPORT
   AssertionW;

(*===========================================================================*)

CLASS IMPLEMENTATION CIterator;

(*---------------------------------------------------------------------------*)

   PUBLIC VIRTUAL PROPERTY colCurrent GET : baseobject.PBASE;
   BEGIN
      IF _Exhausted THEN
         RETURN NIL;
      ELSIF _StartSequence <> _OfCollection^.Sequence THEN
         _Exhausted := TRUE;
         ASSERTLOG( FALSE, L"Access to iterator whose collection has changed" );
         RETURN NIL;
      ELSE
         RETURN _Current;
      END;
   END colCurrent;

(*---------------------------------------------------------------------------*)

   PUBLIC VIRTUAL PROCEDURE Reset();
   BEGIN
      _Current := NIL;
      _Exhausted := FALSE;
      _StartSequence := _OfCollection^.Sequence;
   END Reset;

(*---------------------------------------------------------------------------*)

   PUBLIC VIRTUAL PROCEDURE MoveNext() : BOOLEAN;
   BEGIN
      IF _Exhausted THEN
         // fall down
      ELSIF _StartSequence <> _OfCollection^.Sequence THEN // owning collection has changed
         _Exhausted := TRUE;
         ASSERTLOG( FALSE, L"Access to iterator whose collection has changed" );
      ELSIF _Current = NIL THEN
         IF _Direction = dirForward THEN
            _Exhausted := NOT _OfCollection^.colGetFirst( OUT _Current );
         ELSE
            _Exhausted := NOT _OfCollection^.colGetLast( OUT _Current );
         END;
      ELSE
         IF _Direction = dirForward THEN
            _Exhausted := NOT _OfCollection^.colNextOf( _Current, OUT _Current );
         ELSE
            _Exhausted := NOT _OfCollection^.colPrevOf( _Current, OUT _Current );
         END;
      END;
      RETURN NOT _Exhausted;
   END MoveNext;

(*---------------------------------------------------------------------------*)

   PUBLIC VIRTUAL PROPERTY Implementor GET : baseobject.TPDisposable; // the object to be disposed, when TPIterator is to be disposed (interface cannot be disposed)
   BEGIN
      RETURN ADR( SELF );
   END Implementor;

(*---------------------------------------------------------------------------*)

   PUBLIC VIRTUAL PROPERTY OfCollection GET : TPCollection; // the object to be disposed, when TPIterator is to be disposed (interface cannot be disposed)
   BEGIN
      RETURN _OfCollection;
   END OfCollection;

(*---------------------------------------------------------------------------*)

   PUBLIC PROCEDURE Init( CONST ofCollection : ICollection; direction : TDirection ); // the collection must initialize the iterator with self
   BEGIN
      _OfCollection := TPCollection( ADR( ofCollection ));
      _Direction := direction;
      Reset();
   END Init;

(*---------------------------------------------------------------------------*)

BEGIN
END CIterator;

(*==========================================================================*)

END collection.