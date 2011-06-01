IMPLEMENTATION MODULE synclists;

IMPORT
   lists,
   Sync;
  
(*================================================================================*)

CONST
   MESSAGE = L"Unable to lock list";

CLASS IMPLEMENTATION CPtrPtrSyncList;

(*---------------------------------------------------------------------------*)

   PUBLIC PROPERTY Count GET : CARDINAL;
   VAR
      lock : Sync.AutoLock;
   BEGIN
      lock.TakeReadSafe( REF _Lock, MESSAGE );
      RETURN SUPER.Count;
   END Count;

(*---------------------------------------------------------------------------*)

   PUBLIC PROPERTY Empty GET : BOOLEAN;
   VAR
      lock : Sync.AutoLock;
   BEGIN
      lock.TakeReadSafe( REF _Lock, MESSAGE );
      RETURN SUPER.Empty;
   END Empty;

(*---------------------------------------------------------------------------*)

   PUBLIC PROCEDURE Contains( Value : PTR ): BOOLEAN;
   VAR
      lock : Sync.AutoLock;
   BEGIN
      lock.TakeReadSafe( REF _Lock, MESSAGE );
      RETURN SUPER.Contains( Value );
   END Contains;

(*---------------------------------------------------------------------------*)

   PUBLIC PROCEDURE Add( Value : PTR; Data : PTR );
   VAR
      lock : Sync.AutoLock;
   BEGIN
      lock.TakeSafe( REF _Lock, MESSAGE );
      SUPER.Add( Value, Data );
   END Add;

(*---------------------------------------------------------------------------*)

   PUBLIC PROCEDURE Get( Value : PTR; OUT Data : PTR ): BOOLEAN;
   VAR
      lock : Sync.AutoLock;
   BEGIN
      lock.TakeReadSafe( REF _Lock, MESSAGE );
      RETURN SUPER.Get( Value, OUT Data );
   END Get;

(*---------------------------------------------------------------------------*)

   PUBLIC PROCEDURE Remove( Value : PTR ); // removes all occurences
   VAR
      lock : Sync.AutoLock;
   BEGIN
      lock.TakeSafe( REF _Lock, MESSAGE );
      SUPER.Remove( Value );
   END Remove;

(*---------------------------------------------------------------------------*)

   PUBLIC PROCEDURE ElementAt( Index : INTEGER; OUT Value : PTR; OUT Data : PTR ) : BOOLEAN; // similar as []
   VAR
      lock : Sync.AutoLock;
   BEGIN
      lock.TakeReadSafe( REF _Lock, MESSAGE );
      RETURN SUPER.ElementAt( Index, OUT Value, OUT Data );
   END ElementAt;

(*---------------------------------------------------------------------------*)

   PUBLIC PROCEDURE InsertFirst( Value : PTR; Data : PTR );
   VAR
      lock : Sync.AutoLock;
   BEGIN
      lock.TakeSafe( REF _Lock, MESSAGE );
      SUPER.InsertFirst( Value, Data );
   END InsertFirst;

(*---------------------------------------------------------------------------*)

   PUBLIC PROCEDURE InsertBefore( Before, Value : PTR; Data : PTR );
   VAR
      lock : Sync.AutoLock;
   BEGIN
      lock.TakeSafe( REF _Lock, MESSAGE );
      SUPER.InsertBefore( Before, Value, Data );
   END InsertBefore;

(*---------------------------------------------------------------------------*)

   PUBLIC PROCEDURE Enqueue( Value : PTR; Data : PTR );
   VAR
      lock : Sync.AutoLock;
   BEGIN
      lock.TakeSafe( REF _Lock, MESSAGE );
      SUPER.Enqueue( Value, Data );
   END Enqueue;

(*---------------------------------------------------------------------------*)

   PUBLIC PROCEDURE Dequeue( OUT Value : PTR; OUT Data : PTR ) : BOOLEAN; 
   VAR
      lock : Sync.AutoLock;
   BEGIN
      lock.TakeSafe( REF _Lock, MESSAGE );
      RETURN SUPER.Dequeue( OUT Value, OUT Data );
   END Dequeue;

(*---------------------------------------------------------------------------*)

   PUBLIC PROPERTY Lock GET : Sync.PRWLOCK;
   BEGIN
      RETURN ADR( _Lock );
   END Lock;

(*---------------------------------------------------------------------------*)

END CPtrPtrSyncList;

(*================================================================================*)

END synclists.