IMPLEMENTATION MODULE array;

FROM Storage IMPORT
   REALLOCATE;
  
FROM Debug IMPORT
   Assertion, LogAssertionW;

FROM Exceptions IMPORT
   StoreException;

IMPORT
   Storage,
   Sync;

(*=============================================================================*)

CLASS IMPLEMENTATION CArray;

(*-----------------------------------------------------------------------------*)

   PUBLIC VIRTUAL PROCEDURE Dispose();
   BEGIN
      DISPOSE( _Data );
      _Count := 0;
      _Size := 0;
   END Dispose;

(*-----------------------------------------------------------------------------*)

   PUBLIC PROPERTY Empty GET : BOOLEAN;
   BEGIN
      RETURN _Count = 0;
   END Empty;
  
(*-----------------------------------------------------------------------------*)

   PUBLIC PROPERTY Count GET : CARDINAL;
   BEGIN
      RETURN _Count;
   END Count;
  
(*-----------------------------------------------------------------------------*)

   PUBLIC PROPERTY Sequence GET : CARDINAL;
   BEGIN
      RETURN Sync.IGet( REF _Sequence );
   END Sequence;
  
(*-----------------------------------------------------------------------------*)

   PUBLIC VIRTUAL PROCEDURE colGetIterator( direction : collection.TDirection ) : collection.TPIterator;
   BEGIN
      RETURN GetIterator( direction );
   END colGetIterator;

(*---------------------------------------------------------------------------*)

   PUBLIC VIRTUAL PROCEDURE colGetFirst( OUT object : baseobject.PBASE ) : BOOLEAN;
   BEGIN
      IF _Count = 0 THEN
         RETURN FALSE;
      ELSE
         object := baseobject.PBASE( _Data );
         RETURN TRUE;
      END;
   END colGetFirst;

(*---------------------------------------------------------------------------*)

   PUBLIC VIRTUAL PROCEDURE colNextOf( CONST of : baseobject.PBASE; OUT object : baseobject.PBASE ) : BOOLEAN;
   VAR
      lastItem : PTR := _Data@[ _Count * _ItemSize ];
   BEGIN
      ASSERTLOG(( PTR( of ) >= PTR( _Data )) AND ( PTR( of ) <= lastItem ), L"Unexpected array item" );
      object := baseobject.PBASE( of@[_ItemSize] );
      RETURN PTR( object ) <= lastItem;
   END colNextOf;

(*---------------------------------------------------------------------------*)

   PUBLIC VIRTUAL PROCEDURE colGetLast( OUT object : baseobject.PBASE ) : BOOLEAN;
   BEGIN
      IF _Count = 0 THEN
         RETURN FALSE;
      ELSE
         object := baseobject.PBASE( _Data@[ _Count * _ItemSize ] );
         RETURN TRUE;
      END;
   END colGetLast;

(*---------------------------------------------------------------------------*)

   PUBLIC VIRTUAL PROCEDURE colPrevOf( CONST of : baseobject.PBASE; OUT object : baseobject.PBASE ) : BOOLEAN;
   VAR
      lastItem : PTR := _Data@[ _Count * _ItemSize ];
   BEGIN
      ASSERTLOG(( PTR( of ) >= PTR( _Data )) AND ( PTR( of ) <= lastItem ), L"Unexpected array item" );
      object := baseobject.PBASE( of@[-_ItemSize] );
      RETURN PTR( object ) >= PTR( _Data );
   END colPrevOf;

(*---------------------------------------------------------------------------*)

   PUBLIC PROCEDURE Contains( CONST Item : ARRAY OF BYTE ) : BOOLEAN;
   BEGIN
      RETURN IndexOf( Item ) >= _LowBound;
   END Contains;

(*-----------------------------------------------------------------------------*)

   PUBLIC PROCEDURE Add( CONST Item : ARRAY OF BYTE ) : INTEGER; // returns index
   VAR
      insertSize : INTEGER := HIGH( Item ) + 1;
   BEGIN
      IF insertSize < 0 THEN
         insertSize := 0;
      END;
      Sync.IInc( REF _Sequence );
      IF _Count = _Size THEN
         Size := _Size + 1;
      END;
      IF CARDINAL( insertSize ) < _ItemSize THEN
         Storage.Zero( _Data@[ _Count * _ItemSize + CARDINAL( insertSize ) ], _ItemSize-CARDINAL( insertSize ));
      END;
      Storage.Move( ADR( Item ), _Data@[ _Count * _ItemSize ], insertSize );
      INC( _Count );
      RETURN _Count - 1;
   END Add;

(*-----------------------------------------------------------------------------*)

   PUBLIC PROCEDURE Remove( CONST Item : ARRAY OF BYTE );
   VAR
      i : CARDINAL;
      lookupSize : INTEGER := HIGH( Item ) + 1;
   BEGIN
      IF lookupSize <= 0 THEN
         RETURN;
      END;
      i := 0;
      WHILE i < _Count DO
         IF NOT Storage.Equals( _Data@[ i * _ItemSize ], ADR( Item ), MIN2( lookupSize, _ItemSize )) THEN
            INC( i );
         ELSIF _Strategy = astrgListInArray THEN
            RemoveIndex( i );
         ELSE
            RemoveIndex( i );
            INC( i );
         END;
      END; // WHILE
   END Remove;

(*-----------------------------------------------------------------------------*)

   PUBLIC PROCEDURE ElementAt( Index : INTEGER; OUT Item : ARRAY OF BYTE ) : BOOLEAN;
   VAR
      i : CARDINAL := DEC( Index, _LowBound );
      itemSize : INTEGER := HIGH( Item ) + 1;
   BEGIN
      IF ( i < 0 ) OR ( i >= _Count ) THEN
         RETURN FALSE;
      ELSIF itemSize < 0 THEN
         RETURN FALSE;
      ELSE
         Storage.Move( _Data@[ i * _ItemSize ], ADR( Item ), MIN2( itemSize, _ItemSize ));
         RETURN TRUE;
      END;
   END ElementAt;

(*-----------------------------------------------------------------------------*)

   PUBLIC PROCEDURE Insert( ToIndex : INTEGER; CONST Item : ARRAY OF BYTE );
   VAR
      i : CARDINAL := DEC( ToIndex, _LowBound );
      insertSize : INTEGER := HIGH( Item ) + 1;
   BEGIN
      Sync.IInc( REF _Sequence );
      IF insertSize < 0 THEN
         insertSize := 0;
      END;
      IF _Count = _Size THEN
         Size := _Size + 1;
      END;
      Storage.Move( _Data@[ i * _ItemSize ], _Data@[ INC( i ) * _ItemSize ], ( _Count - i ) * _ItemSize );
      IF CARDINAL( insertSize ) < _ItemSize THEN
         Storage.Zero( _Data@[ i * _ItemSize + CARDINAL( insertSize ) ], _ItemSize-CARDINAL( insertSize ));
      END;
      Storage.Move( ADR( Item ), _Data@[ i * _ItemSize ], insertSize );
      INC( _Count );
   END Insert;

(*-----------------------------------------------------------------------------*)

   PUBLIC PROCEDURE RemoveIndex( Index : INTEGER ) : BOOLEAN;
   VAR
      i : CARDINAL := DEC( Index, _LowBound );
   BEGIN
      IF ( i < 0 ) OR ( i >= _Count ) THEN
         RETURN FALSE;
      END;
      Sync.IInc( REF _Sequence );
      IF _Strategy = astrgListInArray THEN
         Storage.Move( _Data@[ INC( i ) * _ItemSize ], _Data@[ i * _ItemSize ], ( _Count - i - 1 ) * _ItemSize );
         DEC( _Count );
      ELSE
         Storage.Zero( _Data@[ i * _ItemSize ], _ItemSize );
      END;
      RETURN TRUE;
  END RemoveIndex;
  
(*-----------------------------------------------------------------------------*)

   PUBLIC PROCEDURE IndexOf( CONST Item : ARRAY OF BYTE ) : INTEGER; // if not found returns LowBound-1
   VAR
      i : CARDINAL;
      lookupSize : INTEGER := HIGH( Item ) + 1;
   BEGIN
      IF lookupSize < 0 THEN
         RETURN _LowBound - 1;
      END;
      i := 0;
      WHILE i < _Count DO
         IF Storage.Equals( _Data@[ i * _ItemSize ], ADR( Item ), MIN2( lookupSize, _ItemSize )) THEN
            RETURN INTEGER( i ) + _LowBound;
         END;
         INC( i );
      END; // WHILE
      RETURN _LowBound - 1;
   END IndexOf;

(*-----------------------------------------------------------------------------*)

   PUBLIC PROCEDURE Clear();
   BEGIN
      _Count := 0;
   END Clear;

(*-----------------------------------------------------------------------------*)

   PUBLIC PROCEDURE GetIterator( Direction : collection.TDirection ) : TPArrayIterator;
   VAR
      iterator : TPArrayIterator := NEW( CArrayIterator );
   BEGIN
      iterator^.Init( ADR( SELF ), Direction );
      RETURN iterator;
   END GetIterator;

(*---------------------------------------------------------------------------*)

   PUBLIC PROCEDURE Enqueue( CONST Item : ARRAY OF BYTE );
   BEGIN
      Add( Item );
   END Enqueue;

(*---------------------------------------------------------------------------*)

   PUBLIC PROCEDURE Dequeue( OUT Item : ARRAY OF BYTE ) : BOOLEAN; 
   BEGIN
      IF ElementAt( 0, OUT Item ) THEN
         RemoveIndex( 0 );
         RETURN TRUE;
      ELSE
         RETURN FALSE;
      END;
   END Dequeue;

(*---------------------------------------------------------------------------*)

   PUBLIC PROCEDURE Init( Strategy : TStrategy; LowBound : INTEGER; ItemSize : CARDINAL );
   VAR
      actualSize : CARDINAL := _Size;
   BEGIN
      Dispose();
      _LowBound := LowBound;
      _Strategy := Strategy;
      _ItemSize := ItemSize;
      IF actualSize > 0 THEN // allocate space
         Size := actualSize;
      END;
   END Init;
  
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
      Sync.IInc( REF _Sequence );
      REALLOCATE( REF _Data, Value * _ItemSize );
      IF Value > _Size THEN
         Storage.Zero( _Data@[ _Size * _ItemSize ], ( Value - _Size ) * _ItemSize );
      END;
      _Size := Value;
   END Size;

(*-----------------------------------------------------------------------------*)

   PUBLIC PROPERTY setCount SET( Value : CARDINAL );
   BEGIN
      Sync.IInc( REF _Sequence );
      _Count := MIN2( Value, _Size );
   END setCount;
  
(*-----------------------------------------------------------------------------*)

   PUBLIC PROPERTY ItemSize GET : CARDINAL;
   BEGIN
      RETURN _ItemSize;
   END ItemSize;

(*-----------------------------------------------------------------------------*)

   PUBLIC INDEX CArray GET( Index : INTEGER ) : ADDRESS;
   VAR
      i : CARDINAL := DEC( Index, _LowBound );
   BEGIN
      IF ( i < 0 ) OR ( i >= _Count ) THEN
         THROW Exceptions.Modula2Exception( NIL, L"", L"", Exceptions.mexOutOfArrayIndex );
      ELSE
         RETURN _Data@[ i * _ItemSize ];
      END;
   END CArray;

(*-----------------------------------------------------------------------------*)

   PUBLIC INDEX CArray SET( Index : INTEGER; Value : ADDRESS );
   VAR
      i : CARDINAL := DEC( Index, _LowBound );
   BEGIN
      IF ( i < 0 ) OR ( i >= _Count ) THEN
         THROW Exceptions.Modula2Exception( NIL, L"", L"", Exceptions.mexOutOfArrayIndex );
      ELSE
         Sync.IInc( REF _Sequence );
         Storage.Move( Value, _Data@[ i * _ItemSize ], _ItemSize );
      END;
   END CArray;

(*-----------------------------------------------------------------------------*)

BEGIN
FINALLY
   Dispose();
END CArray;

(*=============================================================================*)

CLASS IMPLEMENTATION CArrayIterator;

(*---------------------------------------------------------------------------*)

   PUBLIC PROPERTY Current GET : ADDRESS;
   BEGIN
      RETURN colCurrent;
   END Current;

(*---------------------------------------------------------------------------*)

END CArrayIterator;

(*===========================================================================*)

END array.