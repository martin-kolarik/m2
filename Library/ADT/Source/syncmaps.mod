IMPLEMENTATION MODULE syncmaps;

FROM Storage IMPORT
   ALLOCATE, DEALLOCATE;

FROM Debug IMPORT
   AssertionW;

IMPORT
   collection;

(*--------------------------------------------------------------------------------*)

CONST
   MESSAGE = L"Unable to lock map";

(*================================================================================*)

CLASS IMPLEMENTATION CPtrPtrSyncMap;
      
(*--------------------------------------------------------------------------------*)

   PUBLIC READONLY PROPERTY Lock GET : Sync.TPILockR;
   BEGIN
      RETURN ADR( _Lock );
   END Lock;

(*--------------------------------------------------------------------------------*)

   PUBLIC INDEX CPtrPtrSyncMap GET ( Index : CARDINAL ) : PTR;
   VAR
      lock : Sync.AutoLock;
   BEGIN
      lock.TakeReadSafe( REF _Lock, MESSAGE );
      RETURN SUPER[Index];
   END CPtrPtrSyncMap;

(*--------------------------------------------------------------------------------*)

   PUBLIC PROCEDURE Add( Key : PTR; Value, Data : PTR );
   VAR
      lock : Sync.AutoLock;
   BEGIN
      lock.TakeSafe( REF _Lock, MESSAGE );
      SUPER.Add( Key, Value, Data );
   END Add;

(*--------------------------------------------------------------------------------*)

   PUBLIC PROCEDURE Remove( Key : PTR );
   VAR
      lock : Sync.AutoLock;
   BEGIN
      lock.TakeSafe( REF _Lock, MESSAGE );
      SUPER.Remove( Key );
   END Remove;

(*--------------------------------------------------------------------------------*)

   PUBLIC PROCEDURE Contains( Key : PTR ) : BOOLEAN;
   VAR
      lock : Sync.AutoLock;
   BEGIN
      lock.TakeReadSafe( REF _Lock, MESSAGE );
      RETURN SUPER.Contains( Key );
   END Contains;

(*--------------------------------------------------------------------------------*)

   PUBLIC PROCEDURE Get( Key : PTR; OUT Value : PTR; OUT Data : PTR ) : BOOLEAN;
   VAR
      lock : Sync.AutoLock;
   BEGIN
      lock.TakeReadSafe( REF _Lock, MESSAGE );
      RETURN SUPER.Get( Key, OUT Value, OUT Data );
   END Get;

(*--------------------------------------------------------------------------------*)

   PUBLIC PROCEDURE Set( Key : PTR; Value, Data : PTR ) : BOOLEAN;
   VAR
      lock : Sync.AutoLock;
   BEGIN
      lock.TakeSafe( REF _Lock, MESSAGE );
      RETURN SUPER.Set( Key, Value, Data );
   END Set;

(*--------------------------------------------------------------------------------*)

   PUBLIC PROCEDURE ElementAt( Index : CARDINAL; OUT Key : PTR; OUT Value : PTR; OUT Data : PTR ) : BOOLEAN;
   VAR
      lock : Sync.AutoLock;
   BEGIN
      lock.TakeReadSafe( REF _Lock, MESSAGE );
      RETURN SUPER.ElementAt( Index, OUT Key, OUT Value, OUT Data );
   END ElementAt;

(*--------------------------------------------------------------------------------*)

   PUBLIC PROCEDURE GetIterator() : TPPtrPtrSyncMapIterator;
   VAR
      iterator : POINTER TO CPtrPtrSyncMapIterator := NEW( CPtrPtrSyncMapIterator );
   BEGIN
      iterator^.Init( SELF, collection.dirForward );
      RETURN iterator;
   END GetIterator;

(*--------------------------------------------------------------------------------*)

BEGIN
   _Lock.Init( Sync.ltSpin, L"" );
END CPtrPtrSyncMap;

(*================================================================================*)

CLASS IMPLEMENTATION CPtrPtrSyncMapIterator;

(*--------------------------------------------------------------------------------*)

   PUBLIC PROCEDURE Init( CONST OfCollection : CPtrPtrSyncMap; Direction : collection.TDirection );
   VAR
      result : Sync.TAsyncResult;
   BEGIN
      Stop();
      _Map := TPPtrPtrSyncMap( ADR( OfCollection ));

      result := _Map^.Lock^.LockRead( Sync.FORSAFETY );
      ASSERTLOG( result <> Sync.arTimeout, L"Unable to lock map for reading" );

      SUPER.Init( OfCollection, Direction );
   END Init;

(*--------------------------------------------------------------------------------*)

   PUBLIC PROCEDURE Stop();
   BEGIN
      IF _Map <> NIL THEN
         _Map^.Lock^.UnlockRead();
         _Map := NIL;
      END;
   END Stop;

(*--------------------------------------------------------------------------------*)

BEGIN FINALLY
   Stop();
END CPtrPtrSyncMapIterator;

(*================================================================================*)

CLASS IMPLEMENTATION CStringPtrSyncMap;
      
(*--------------------------------------------------------------------------------*)

   PUBLIC READONLY PROPERTY Lock GET : Sync.TPILockR;
   BEGIN
      RETURN ADR( _Lock );
   END Lock;

(*--------------------------------------------------------------------------------*)

   PUBLIC INDEX CStringPtrSyncMap GET ( Index : CARDINAL ) : PTR;
   VAR
      lock : Sync.AutoLock;
   BEGIN
      lock.TakeReadSafe( REF _Lock, MESSAGE );
      RETURN SUPER[Index];
   END CStringPtrSyncMap;

(*--------------------------------------------------------------------------------*)

   PUBLIC PROCEDURE Add( CONST Key : IString; Value, Data : PTR );
   VAR
      lock : Sync.AutoLock;
   BEGIN
      lock.TakeSafe( REF _Lock, MESSAGE );
      SUPER.Add( Key, Value, Data );
   END Add;

(*--------------------------------------------------------------------------------*)

   PUBLIC PROCEDURE Remove( CONST Key : IString );
   VAR
      lock : Sync.AutoLock;
   BEGIN
      lock.TakeSafe( REF _Lock, MESSAGE );
      SUPER.Remove( Key );
   END Remove;

(*--------------------------------------------------------------------------------*)

   PUBLIC PROCEDURE Contains( CONST Key : IString ) : BOOLEAN;
   VAR
      lock : Sync.AutoLock;
   BEGIN
      lock.TakeReadSafe( REF _Lock, MESSAGE );
      RETURN SUPER.Contains( Key );
   END Contains;

(*--------------------------------------------------------------------------------*)

   PUBLIC PROCEDURE Get( CONST Key : IString; OUT Value : PTR; OUT Data : PTR ) : BOOLEAN;
   VAR
      lock : Sync.AutoLock;
   BEGIN
      lock.TakeReadSafe( REF _Lock, MESSAGE );
      RETURN SUPER.Get( Key, OUT Value, OUT Data );
   END Get;

(*--------------------------------------------------------------------------------*)

   PUBLIC PROCEDURE Set( CONST Key : IString; Value, Data : PTR ) : BOOLEAN;
   VAR
      lock : Sync.AutoLock;
   BEGIN
      lock.TakeSafe( REF _Lock, MESSAGE );
      RETURN SUPER.Set( Key, Value, Data );
   END Set;

(*--------------------------------------------------------------------------------*)

   PUBLIC PROCEDURE ElementAt( Index : CARDINAL; OUT Key : IString; OUT Value : PTR; OUT Data : PTR ) : BOOLEAN;
   VAR
      lock : Sync.AutoLock;
   BEGIN
      lock.TakeReadSafe( REF _Lock, MESSAGE );
      RETURN SUPER.ElementAt( Index, OUT Key, OUT Value, OUT Data );
   END ElementAt;

(*--------------------------------------------------------------------------------*)

   PUBLIC PROCEDURE GetIterator() : TPStringPtrSyncMapIterator;
   VAR
      iterator : POINTER TO CStringPtrSyncMapIterator := NEW( CStringPtrSyncMapIterator );
   BEGIN
      iterator^.Init( SELF, collection.dirForward );
      RETURN iterator;
   END GetIterator;

(*--------------------------------------------------------------------------------*)

BEGIN
   _Lock.Init( Sync.ltSpin, L"" );
END CStringPtrSyncMap;

(*================================================================================*)

CLASS IMPLEMENTATION CStringPtrSyncMapIterator;

(*--------------------------------------------------------------------------------*)

   PUBLIC PROCEDURE Init( CONST OfCollection : CStringPtrSyncMap; Direction : collection.TDirection );
   VAR
      result : Sync.TAsyncResult;
   BEGIN
      Stop();
      _Map := TPStringPtrSyncMap( ADR( OfCollection ));

      result := _Map^.Lock^.LockRead( Sync.FORSAFETY );
      ASSERTLOG( result <> Sync.arTimeout, L"Unable to lock map for reading" );

      SUPER.Init( OfCollection, Direction );
   END Init;

(*--------------------------------------------------------------------------------*)

   PUBLIC PROCEDURE Stop();
   BEGIN
      IF _Map <> NIL THEN
         _Map^.Lock^.UnlockRead();
         _Map := NIL;
      END;
   END Stop;

(*--------------------------------------------------------------------------------*)

BEGIN FINALLY
   Stop();
END CStringPtrSyncMapIterator;

(*================================================================================*)

END syncmaps.