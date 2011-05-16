IMPLEMENTATION MODULE syncmaps;

FROM Storage IMPORT
   ALLOCATE, DEALLOCATE;

FROM Debug IMPORT
   Assertion;

(*--------------------------------------------------------------------------------*)

CONST
   MESSAGE = L"Unable to lock map";

(*================================================================================*)

CLASS CPtrBaseSyncMapIterator( maps.CPtrBaseMapIterator );

   LOCAL PROCEDURE Init( map : TPPtrBaseSyncMap );

   PRIVATE VAR
      _Map : TPPtrBaseSyncMap := NIL;

END CPtrBaseSyncMapIterator;

(*--------------------------------------------------------------------------------*)

CLASS IMPLEMENTATION CPtrBaseSyncMapIterator;

(*--------------------------------------------------------------------------------*)

   LOCAL PROCEDURE Init( map : TPPtrBaseSyncMap );
   BEGIN
      SUPER.Init( map );
      _Map := map;
   END Init;

(*--------------------------------------------------------------------------------*)

BEGIN FINALLY
   _Map^.Lock^.UnlockRead();
END CPtrBaseSyncMapIterator;

(*================================================================================*)

CLASS IMPLEMENTATION CPtrBaseSyncMap;
      
(*--------------------------------------------------------------------------------*)

   PUBLIC READONLY PROPERTY Lock GET : Sync.TPILockR;
   BEGIN
      RETURN ADR( _Lock );
   END Lock;

(*--------------------------------------------------------------------------------*)

   PUBLIC INDEX CPtrBaseSyncMap GET ( Index : CARDINAL ) : PTR;
   VAR
      lock : Sync.AutoLock;
   BEGIN
      lock.TakeReadSafe( REF _Lock, MESSAGE );
      RETURN SUPER[Index];
   END CPtrBaseSyncMap;

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

   PUBLIC PROCEDURE GetIterator() : maps.TPPtrBaseMapIterator;
   VAR
      iterator : POINTER TO CPtrBaseSyncMapIterator := NEW( CPtrBaseSyncMapIterator );
   BEGIN
      IF _Lock.LockRead( Sync.FORSAFETY ) <> Sync.arCompleted THEN
         ASSERT( FALSE );
      END;
      iterator^.Init( ADR( SELF ));
      RETURN iterator;
   END GetIterator;

(*--------------------------------------------------------------------------------*)

BEGIN
   _Lock.Init( Sync.ltSpin, L"" );
END CPtrBaseSyncMap;

(*================================================================================*)

CLASS CStringBaseSyncMapIterator( maps.CStringBaseMapIterator );

   LOCAL PROCEDURE Init( map : TPStringBaseSyncMap );

   PRIVATE VAR
      _Map : TPStringBaseSyncMap := NIL;

END CStringBaseSyncMapIterator;

(*--------------------------------------------------------------------------------*)

CLASS IMPLEMENTATION CStringBaseSyncMapIterator;

(*--------------------------------------------------------------------------------*)

   LOCAL PROCEDURE Init( map : TPStringBaseSyncMap );
   BEGIN
      SUPER.Init( map );
      _Map := map;
   END Init;

(*--------------------------------------------------------------------------------*)

BEGIN FINALLY
   _Map^.Lock^.UnlockRead();
END CStringBaseSyncMapIterator;

(*================================================================================*)

CLASS IMPLEMENTATION CStringBaseSyncMap;
      
(*--------------------------------------------------------------------------------*)

   PUBLIC READONLY PROPERTY Lock GET : Sync.TPILockR;
   BEGIN
      RETURN ADR( _Lock );
   END Lock;

(*--------------------------------------------------------------------------------*)

   PUBLIC INDEX CStringBaseSyncMap GET ( Index : CARDINAL ) : PTR;
   VAR
      lock : Sync.AutoLock;
   BEGIN
      lock.TakeReadSafe( REF _Lock, MESSAGE );
      RETURN SUPER[Index];
   END CStringBaseSyncMap;

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

   PUBLIC PROCEDURE GetIterator() : maps.TPStringBaseMapIterator;
   VAR
      iterator : POINTER TO CStringBaseSyncMapIterator := NEW( CStringBaseSyncMapIterator );
   BEGIN
      IF _Lock.LockRead( Sync.FORSAFETY ) <> Sync.arCompleted THEN
         ASSERT( FALSE );
      END;
      iterator^.Init( ADR( SELF ));
      RETURN iterator;
   END GetIterator;

(*--------------------------------------------------------------------------------*)

BEGIN
   _Lock.Init( Sync.ltSpin, L"" );
END CStringBaseSyncMap;

(*================================================================================*)

END syncmaps.