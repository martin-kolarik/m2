IMPLEMENTATION MODULE syncmaps;

FROM Storage IMPORT
   ALLOCATE, DEALLOCATE;

FROM Debug IMPORT
   Assertion;

IMPORT
   collection;

(*--------------------------------------------------------------------------------*)

CONST
   MESSAGE = L"Unable to lock map";

(*================================================================================*)

CLASS CPtrPtrSyncMapIterator( maps.CPtrPtrMapIterator );

   LOCAL PROCEDURE Init( map : TPPtrPtrSyncMap; direction : collection.TDirection );

   PRIVATE VAR
      _Map : TPPtrPtrSyncMap := NIL;

END CPtrPtrSyncMapIterator;

(*--------------------------------------------------------------------------------*)

CLASS IMPLEMENTATION CPtrPtrSyncMapIterator;

(*--------------------------------------------------------------------------------*)

   LOCAL PROCEDURE Init( map : TPPtrPtrSyncMap; direction : collection.TDirection );
   BEGIN
      SUPER.Init( map^, direction );
      _Map := map;
   END Init;

(*--------------------------------------------------------------------------------*)

BEGIN FINALLY
   _Map^.Lock^.UnlockRead();
END CPtrPtrSyncMapIterator;

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

   PUBLIC PROCEDURE Add( Key : PTR; Data : PTR );
   VAR
      lock : Sync.AutoLock;
   BEGIN
      lock.TakeSafe( REF _Lock, MESSAGE );
      SUPER.Add( Key, Data );
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

   PUBLIC PROCEDURE Get( Key : PTR; OUT Data : PTR ) : BOOLEAN;
   VAR
      lock : Sync.AutoLock;
   BEGIN
      lock.TakeReadSafe( REF _Lock, MESSAGE );
      RETURN SUPER.Get( Key, OUT Data );
   END Get;

(*--------------------------------------------------------------------------------*)

   PUBLIC PROCEDURE ElementAt( Index : CARDINAL; OUT Key : PTR; OUT Data : PTR ) : BOOLEAN;
   VAR
      lock : Sync.AutoLock;
   BEGIN
      lock.TakeReadSafe( REF _Lock, MESSAGE );
      RETURN SUPER.ElementAt( Index, OUT Key, OUT Data );
   END ElementAt;

(*--------------------------------------------------------------------------------*)

   PUBLIC PROCEDURE GetIterator() : maps.TPPtrPtrMapIterator;
   VAR
      iterator : POINTER TO CPtrPtrSyncMapIterator := NEW( CPtrPtrSyncMapIterator );
   BEGIN
      IF _Lock.LockRead( Sync.FORSAFETY ) <> Sync.arCompleted THEN
         ASSERT( FALSE );
      END;
      iterator^.Init( ADR( SELF ), collection.dirForward );
      RETURN iterator;
   END GetIterator;

(*--------------------------------------------------------------------------------*)

BEGIN
   _Lock.Init( Sync.ltSpin, L"" );
END CPtrPtrSyncMap;

(*================================================================================*)

CLASS CStringPtrSyncMapIterator( maps.CStringPtrMapIterator );

   LOCAL PROCEDURE Init( map : TPStringPtrSyncMap; direction : collection.TDirection );

   PRIVATE VAR
      _Map : TPStringPtrSyncMap := NIL;

END CStringPtrSyncMapIterator;

(*--------------------------------------------------------------------------------*)

CLASS IMPLEMENTATION CStringPtrSyncMapIterator;

(*--------------------------------------------------------------------------------*)

   LOCAL PROCEDURE Init( map : TPStringPtrSyncMap; direction : collection.TDirection );
   BEGIN
      SUPER.Init( map^, direction );
      _Map := map;
   END Init;

(*--------------------------------------------------------------------------------*)

BEGIN FINALLY
   _Map^.Lock^.UnlockRead();
END CStringPtrSyncMapIterator;

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

   PUBLIC PROCEDURE Add( CONST Key : IString; Data : PTR );
   VAR
      lock : Sync.AutoLock;
   BEGIN
      lock.TakeSafe( REF _Lock, MESSAGE );
      SUPER.Add( Key, Data );
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

   PUBLIC PROCEDURE Get( CONST Key : IString; OUT Data : PTR ) : BOOLEAN;
   VAR
      lock : Sync.AutoLock;
   BEGIN
      lock.TakeReadSafe( REF _Lock, MESSAGE );
      RETURN SUPER.Get( Key, OUT Data );
   END Get;

(*--------------------------------------------------------------------------------*)

   PUBLIC PROCEDURE ElementAt( Index : CARDINAL; OUT Key : IString; OUT Data : PTR ) : BOOLEAN;
   VAR
      lock : Sync.AutoLock;
   BEGIN
      lock.TakeReadSafe( REF _Lock, MESSAGE );
      RETURN SUPER.ElementAt( Index, OUT Key, OUT Data );
   END ElementAt;

(*--------------------------------------------------------------------------------*)

   PUBLIC PROCEDURE GetIterator() : maps.TPStringPtrMapIterator;
   VAR
      iterator : POINTER TO CStringPtrSyncMapIterator := NEW( CStringPtrSyncMapIterator );
   BEGIN
      IF _Lock.LockRead( Sync.FORSAFETY ) <> Sync.arCompleted THEN
         ASSERT( FALSE );
      END;
      iterator^.Init( ADR( SELF ), collection.dirForward );
      RETURN iterator;
   END GetIterator;

(*--------------------------------------------------------------------------------*)

BEGIN
   _Lock.Init( Sync.ltSpin, L"" );
END CStringPtrSyncMap;

(*================================================================================*)

END syncmaps.