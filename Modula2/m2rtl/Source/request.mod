IMPLEMENTATION MODULE request;

(*================================================================================*)

CLASS IMPLEMENTATION Completable;

(*--------------------------------------------------------------------------------*)

   INTERNAL VIRTUAL PROCEDURE OnCompleted( Result : Sync.TAsyncResult; CONST Source : basecompletion.ICompletionSource; OperationHandle : PTR );
   BEGIN
   END OnCompleted;

(*--------------------------------------------------------------------------------*)

   PUBLIC VIRTUAL PROPERTY CompletionSink GET : basecompletion.TPICompletionSink;
   BEGIN
      RETURN _Completable.CompletionSink;
   END CompletionSink;

(*--------------------------------------------------------------------------------*)

   PUBLIC VIRTUAL PROPERTY CompletionSink SET( Value : basecompletion.TPICompletionSink );
   BEGIN
      _Completable.CompletionSink := Value;
   END CompletionSink;

(*--------------------------------------------------------------------------------*)

   PUBLIC VIRTUAL PROCEDURE Complete( Result : Sync.TAsyncResult; CONST Source : basecompletion.ICompletionSource; OperationHandle : PTR ); // Principal completion action, callable from any source. First calls OnCompleted, then calls Sink.
   BEGIN
      _Completable.Complete( Result, Source, OperationHandle );
   END Complete;

(*--------------------------------------------------------------------------------*)

END Completable;

(*================================================================================*)

CLASS IMPLEMENTATION WaitableCompletable;

(*--------------------------------------------------------------------------------*)

   INTERNAL VIRTUAL PROCEDURE OnCompleted( Result : Sync.TAsyncResult; CONST Source : basecompletion.ICompletionSource; OperationHandle : PTR );
   BEGIN
   END OnCompleted;

(*--------------------------------------------------------------------------------*)

   PUBLIC VIRTUAL PROPERTY CompletionSink GET : basecompletion.TPICompletionSink;
   BEGIN
      RETURN _WaitableCompletable.CompletionSink;
   END CompletionSink;

(*--------------------------------------------------------------------------------*)

   PUBLIC VIRTUAL PROPERTY CompletionSink SET( Value : basecompletion.TPICompletionSink );
   BEGIN
      _WaitableCompletable.CompletionSink := Value;
   END CompletionSink;

(*--------------------------------------------------------------------------------*)

   PUBLIC VIRTUAL PROCEDURE Complete( Result : Sync.TAsyncResult; CONST Source : basecompletion.ICompletionSource; OperationHandle : PTR ); // Principal completion action, callable from any source. First calls OnCompleted, then calls Sink.
   BEGIN
      _WaitableCompletable.Complete( Result, Source, OperationHandle );
   END Complete;

(*--------------------------------------------------------------------------------*)

   PUBLIC VIRTUAL PROPERTY Completed GET : BOOLEAN;
   BEGIN
      RETURN _WaitableCompletable.Completed;
   END Completed;

(*--------------------------------------------------------------------------------*)

   PUBLIC VIRTUAL PROPERTY Result GET : Sync.TAsyncResult;
   BEGIN
      RETURN _WaitableCompletable.Result;
   END Result;

(*--------------------------------------------------------------------------------*)

   PUBLIC VIRTUAL PROCEDURE Reset();
   BEGIN
      _WaitableCompletable.Reset();
   END Reset;

(*--------------------------------------------------------------------------------*)

   PUBLIC VIRTUAL PROCEDURE WaitForCompletion( Timeout : CARDINAL ) : Sync.TAsyncResult; // arTimeout or copies Result property
   BEGIN
      RETURN _WaitableCompletable.WaitForCompletion( Timeout );
   END WaitForCompletion;

(*--------------------------------------------------------------------------------*)

END WaitableCompletable;

(*================================================================================*)

CLASS IMPLEMENTATION AbortableWaitableCompletable;

(*--------------------------------------------------------------------------------*)

   PUBLIC VIRTUAL PROPERTY AbortSink GET : basecompletion.TPIAbortable;
   BEGIN
      RETURN Sync.IGetPtr( REF _AbortSink );
   END AbortSink;

(*--------------------------------------------------------------------------------*)

   PUBLIC VIRTUAL PROPERTY AbortSink SET( Value : basecompletion.TPIAbortable );
   BEGIN
      Sync.IExchgPtr( REF _AbortSink, Value );
   END AbortSink;

(*--------------------------------------------------------------------------------*)

   PUBLIC VIRTUAL PROCEDURE Abort( CONST Source : basecompletion.ICompletionSource; OperationHandle : PTR );
   BEGIN
      IF _AbortSink <> NIL THEN
         _AbortSink^.Abort( Source, OperationHandle );
      END;
      Complete( Sync.arAborted, Source, OperationHandle );
   END Abort;

(*--------------------------------------------------------------------------------*)

BEGIN
END AbortableWaitableCompletable;

(*================================================================================*)

END request.
