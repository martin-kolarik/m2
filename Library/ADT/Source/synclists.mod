IMPLEMENTATION MODULE synclists;

IMPORT
   lists,
   Sync;
  
(*================================================================================*)

CONST
   MESSAGE = L"Unable to lock list";

CLASS IMPLEMENTATION CPtrSyncList;

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

   PUBLIC PROCEDURE Reset();
   VAR
      lock : Sync.AutoLock;
   BEGIN
      lock.TakeSafe( REF _Lock, MESSAGE );
      SUPER.Reset();
   END Reset;

(*---------------------------------------------------------------------------*)

   PUBLIC PROCEDURE MoveNext() : BOOLEAN;
   VAR
      lock : Sync.AutoLock;
   BEGIN
      lock.TakeSafe( REF _Lock, MESSAGE );
      RETURN SUPER.MoveNext();
   END MoveNext;

(*---------------------------------------------------------------------------*)

   PUBLIC PROPERTY Current GET : PTR;
   VAR
      lock : Sync.AutoLock;
   BEGIN
      lock.TakeReadSafe( REF _Lock, MESSAGE );
      RETURN SUPER.Current;
   END Current;

(*---------------------------------------------------------------------------*)

   PUBLIC PROPERTY CurrentData GET : PTR;
   VAR
      lock : Sync.AutoLock;
   BEGIN
      lock.TakeReadSafe( REF _Lock, MESSAGE );
      RETURN SUPER.CurrentData;
   END CurrentData;

(*---------------------------------------------------------------------------*)

   PUBLIC PROPERTY CurrentData SET( Value : PTR );
   VAR
      lock : Sync.AutoLock;
   BEGIN
      lock.TakeSafe( REF _Lock, MESSAGE );
      SUPER.CurrentData := Value;
   END CurrentData;

(*---------------------------------------------------------------------------*)

   INDEX CPtrSyncList GET( Index : INTEGER ) : PTR; // SLOW, O(n)!!
   VAR
      lock : Sync.AutoLock;
   BEGIN
      lock.TakeReadSafe( REF _Lock, MESSAGE );
      RETURN SUPER[ Index ];
   END CPtrSyncList;

(*---------------------------------------------------------------------------*)

   PUBLIC PROCEDURE Add( Value : PTR; Data : PTR );
   VAR
      lock : Sync.AutoLock;
   BEGIN
      lock.TakeSafe( REF _Lock, MESSAGE );
      SUPER.Add( Value, Data );
   END Add;

(*---------------------------------------------------------------------------*)

   PUBLIC PROCEDURE Contains( Value : PTR ): BOOLEAN;
   VAR
      lock : Sync.AutoLock;
   BEGIN
      lock.TakeReadSafe( REF _Lock, MESSAGE );
      RETURN SUPER.Contains( Value );
   END Contains;

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

   PUBLIC PROCEDURE Append( Value : PTR; Data : PTR );
   VAR
      lock : Sync.AutoLock;
   BEGIN
      lock.TakeSafe( REF _Lock, MESSAGE );
      SUPER.Append( Value, Data );
   END Append;

(*---------------------------------------------------------------------------*)

   PUBLIC PROCEDURE GetFirst( OUT Value : PTR; OUT Data : PTR ) : BOOLEAN;
   VAR
      lock : Sync.AutoLock;
   BEGIN
      lock.TakeReadSafe( REF _Lock, MESSAGE );
      RETURN SUPER.GetFirst( OUT Value, OUT Data );
   END GetFirst;

(*---------------------------------------------------------------------------*)

   PUBLIC PROCEDURE GetLast( OUT Value : PTR; OUT Data : PTR ) : BOOLEAN;
   VAR
      lock : Sync.AutoLock;
   BEGIN
      lock.TakeReadSafe( REF _Lock, MESSAGE );
      RETURN SUPER.GetLast( OUT Value, OUT Data );
   END GetLast;

(*---------------------------------------------------------------------------*)

   PUBLIC PROCEDURE PrevOf( Value : PTR; OUT Previous : PTR; OUT Data : PTR ) : BOOLEAN; // SLOW
   VAR
      lock : Sync.AutoLock;
   BEGIN
      lock.TakeReadSafe( REF _Lock, MESSAGE );
      RETURN SUPER.PrevOf( Value, OUT Previous, OUT Data );
   END PrevOf;

(*---------------------------------------------------------------------------*)

   PUBLIC PROCEDURE NextOf( Value : PTR; OUT Next : PTR; OUT Data : PTR ) : BOOLEAN; // SLOW
   VAR
      lock : Sync.AutoLock;
   BEGIN
      lock.TakeReadSafe( REF _Lock, MESSAGE );
      RETURN SUPER.NextOf( Value, OUT Next, OUT Data );
   END NextOf;

(*---------------------------------------------------------------------------*)

   PUBLIC PROCEDURE IndexOf( Value : PTR ) : INTEGER; // SLOW
   VAR
      lock : Sync.AutoLock;
   BEGIN
      lock.TakeReadSafe( REF _Lock, MESSAGE );
      RETURN SUPER.IndexOf( Value );
   END IndexOf;
  
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

END CPtrSyncList;

(*================================================================================*)

END synclists.