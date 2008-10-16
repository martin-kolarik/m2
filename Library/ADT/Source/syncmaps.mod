IMPLEMENTATION MODULE syncmaps;

(*================================================================================*)

CLASS IMPLEMENTATION CPtrSyncMap;
      
(*--------------------------------------------------------------------------------*)

   PUBLIC READONLY PROPERTY Lock GET : Sync.PRWLOCK;
   BEGIN
      RETURN ADR( LOCK );
   END Lock;

(*--------------------------------------------------------------------------------*)

   PUBLIC INDEX CPtrSyncMap GET ( Index : CARDINAL ) : PTR;
   VAR
      ptr : PTR;
   BEGIN
      LOCK.LockRead( Sync.FORSAFETY );
      ptr := SUPER[Index];
      LOCK.UnlockRead();
      RETURN ptr;
   END CPtrSyncMap;

(*--------------------------------------------------------------------------------*)

   PUBLIC PROCEDURE Add( Key : PTR; Data : PTR );
   BEGIN
      LOCK.LockWrite( Sync.FORSAFETY );
      SUPER.Add( Key, Data );
      LOCK.UnlockWrite();
   END Add;

(*--------------------------------------------------------------------------------*)

   PUBLIC PROCEDURE Remove( Key : PTR );
   BEGIN
      LOCK.LockWrite( Sync.FORSAFETY );
      SUPER.Remove( Key );
      LOCK.UnlockWrite();
   END Remove;

(*--------------------------------------------------------------------------------*)

   PUBLIC PROCEDURE Contains( Key : PTR ) : BOOLEAN;
   VAR
      b : BOOLEAN;
   BEGIN
      LOCK.LockRead( Sync.FORSAFETY );
      b := SUPER.Contains( Key );
      LOCK.UnlockRead();
      RETURN b;
   END Contains;

(*--------------------------------------------------------------------------------*)

   PUBLIC PROCEDURE Get( Key : PTR; OUT Data : PTR ) : BOOLEAN;
   VAR
      b : BOOLEAN;
   BEGIN
      LOCK.LockRead( Sync.FORSAFETY );
      b := SUPER.Get( Key, OUT Data );
      LOCK.UnlockRead();
      RETURN b;
   END Get;

(*--------------------------------------------------------------------------------*)

   PUBLIC PROCEDURE ElementAt( Index : CARDINAL; OUT Key : PTR; OUT Data : PTR ) : BOOLEAN; // similar as []
   VAR
      b : BOOLEAN;
   BEGIN
      LOCK.LockRead( Sync.FORSAFETY );
      b := SUPER.ElementAt( Index, OUT Key, OUT Data );
      LOCK.UnlockRead();
      RETURN b;
   END ElementAt;

(*--------------------------------------------------------------------------------*)

BEGIN
   LOCK.Init( Sync.ltSpin, L"" );
END CPtrSyncMap;

(*================================================================================*)

CLASS IMPLEMENTATION CStringSyncMap;
      
(*--------------------------------------------------------------------------------*)

   PUBLIC READONLY PROPERTY Lock GET : Sync.PRWLOCK;
   BEGIN
      RETURN ADR( LOCK );
   END Lock;

(*--------------------------------------------------------------------------------*)

   PUBLIC INDEX CStringSyncMap GET ( Index : CARDINAL ) : PTR;
   VAR
      ptr : PTR;
   BEGIN
      LOCK.LockRead( Sync.FORSAFETY );
      ptr := SUPER[Index];
      LOCK.UnlockRead();
      RETURN ptr;
   END CStringSyncMap;

(*--------------------------------------------------------------------------------*)

   PUBLIC PROCEDURE Add( CONST Key : IString; Data : PTR );
   BEGIN
      LOCK.LockWrite( Sync.FORSAFETY );
      SUPER.Add( Key, Data );
      LOCK.UnlockWrite();
   END Add;

(*--------------------------------------------------------------------------------*)

   PUBLIC PROCEDURE Remove( CONST Key : IString );
   BEGIN
      LOCK.LockWrite( Sync.FORSAFETY );
      SUPER.Remove( Key );
      LOCK.UnlockWrite();
   END Remove;

(*--------------------------------------------------------------------------------*)

   PUBLIC PROCEDURE Contains( CONST Key : IString ) : BOOLEAN;
   VAR
      b : BOOLEAN;
   BEGIN
      LOCK.LockRead( Sync.FORSAFETY );
      b := SUPER.Contains( Key );
      LOCK.UnlockRead();
      RETURN b;
   END Contains;

(*--------------------------------------------------------------------------------*)

   PUBLIC PROCEDURE Get( CONST Key : IString; OUT Data : PTR ) : BOOLEAN;
   VAR
      b : BOOLEAN;
   BEGIN
      LOCK.LockRead( Sync.FORSAFETY );
      b := SUPER.Get( Key, OUT Data );
      LOCK.UnlockRead();
      RETURN b;
   END Get;

(*--------------------------------------------------------------------------------*)

   PUBLIC PROCEDURE ElementAt( Index : CARDINAL; OUT Key : IString; OUT Data : PTR ) : BOOLEAN; // similar as []
   VAR
      b : BOOLEAN;
   BEGIN
      LOCK.LockRead( Sync.FORSAFETY );
      b := SUPER.ElementAt( Index, OUT Key, OUT Data );
      LOCK.UnlockRead();
      RETURN b;
   END ElementAt;

(*--------------------------------------------------------------------------------*)

   PUBLIC PROCEDURE AddOA( CONST Key : ARRAY OF WCHAR; Data : PTR );
   BEGIN
      LOCK.LockWrite( Sync.FORSAFETY );
      SUPER.AddOA( Key, Data );
      LOCK.UnlockWrite();
   END AddOA;

(*--------------------------------------------------------------------------------*)

   PUBLIC PROCEDURE RemoveOA( CONST Key : ARRAY OF WCHAR );
   BEGIN
      LOCK.LockWrite( Sync.FORSAFETY );
      SUPER.RemoveOA( Key );
      LOCK.UnlockWrite();
   END RemoveOA;

(*--------------------------------------------------------------------------------*)

   PUBLIC PROCEDURE ContainsOA( CONST Key : ARRAY OF WCHAR ) : BOOLEAN;
   VAR
      b : BOOLEAN;
   BEGIN
      LOCK.LockRead( Sync.FORSAFETY );
      b := SUPER.ContainsOA( Key );
      LOCK.UnlockRead();
      RETURN b;
   END ContainsOA;

(*--------------------------------------------------------------------------------*)

   PUBLIC PROCEDURE GetOA( CONST Key : ARRAY OF WCHAR; OUT Data : PTR ) : BOOLEAN;
   VAR
      b : BOOLEAN;
   BEGIN
      LOCK.LockRead( Sync.FORSAFETY );
      b := SUPER.GetOA( Key, OUT Data );
      LOCK.UnlockRead();
      RETURN b;
   END GetOA;

(*--------------------------------------------------------------------------------*)

   PUBLIC PROCEDURE ElementAtOA( Index : CARDINAL; OUT Key : ARRAY OF WCHAR; OUT Data : PTR ) : BOOLEAN; // similar as []
   VAR
      b : BOOLEAN;
   BEGIN
      LOCK.LockRead( Sync.FORSAFETY );
      b := SUPER.ElementAtOA( Index, OUT Key, OUT Data );
      LOCK.UnlockRead();
      RETURN b;
   END ElementAtOA;

(*--------------------------------------------------------------------------------*)

BEGIN
   LOCK.Init( Sync.ltSpin, L"" );
END CStringSyncMap;

(*================================================================================*)

END syncmaps.