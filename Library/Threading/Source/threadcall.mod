IMPLEMENTATION MODULE threadcall;

(*===========================================================================*)

CLASS IMPLEMENTATION ThreadProcedureCall;
   
(*---------------------------------------------------------------------------*)

   PUBLIC PROPERTY ReturnValue GET : PTR;
   BEGIN
      RETURN _ReturnValue;
   END ReturnValue;

(*---------------------------------------------------------------------------*)

   PUBLIC PROCEDURE Init( Target : TPIThreadProcedureCallTarget; Operation : CARDINAL; CONST Parameters : ARRAY OF PTR );
   VAR
      Size : CARDINAL;
   BEGIN
      _Target := Target;
      _Operation := Operation;
      _High := HIGH( Parameters );
      IF ( _High <> -1 ) AND ( ADR( Parameters ) <> NIL ) THEN
         Size := INC( _High, 1 ) * SIZE( PTR );
         ALLOCATE( _Parameters, Size );
         Move( ADR( Parameters ), _Parameters, Size );
      END;
   END Init;

(*---------------------------------------------------------------------------*)

   PUBLIC PROCEDURE WaitCompletion( WaitForResult : BOOLEAN; WaitTimeoutMS : CARDINAL ) : Sync.TAsyncResult;
   BEGIN
      IF WaitForResult THEN
         RETURN _Sync._Wait( WaitTimeoutMS );
      ELSE
         RETURN Sync.arPending;
      END;
   END WaitCompletion;

(*---------------------------------------------------------------------------*)

   PUBLIC PROCEDURE Do();
   BEGIN
      _ReturnValue := _Target^.Invoke( _Operation, OA( _High, _Parameters ));
      _Sync._Signal();
   END Do;

(*---------------------------------------------------------------------------*)

BEGIN
   _Sync.Init( Sync.stSetReset, L"", FALSE );
FINALLY
   IF _Parameters <> NIL THEN  
      DISPOSE( _Parameters );
   END;
END ThreadProcedureCall;

(*===========================================================================*)

END threadcall.
