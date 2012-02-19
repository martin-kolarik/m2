IMPLEMENTATION MODULE basecompletion;

(*================================================================================*)

CLASS IMPLEMENTATION CSimpleCompletable;

(*--------------------------------------------------------------------------------*)

   INTERNAL VIRTUAL PROCEDURE OnCompleted( Result : Sync.TAsyncResult; CONST Source : basecompletion.ICompletionSource; OperationHandle : PTR );
   VAR
      client : TPICompletionSink := Client;
   BEGIN
      IF client <> NIL THEN
         client^.OnCompleted( Result, Source, OperationHandle );
      END;
   END OnCompleted;

(*--------------------------------------------------------------------------------*)

   PUBLIC VIRTUAL PROPERTY CompletionSink GET : TPICompletionSink;
   BEGIN
      RETURN Sync.IGetPtr( REF _CompletionSink );
   END CompletionSink;

(*--------------------------------------------------------------------------------*)

   PUBLIC VIRTUAL PROPERTY CompletionSink SET( Value : TPICompletionSink );
   BEGIN
      Sync.IExchgPtr( REF _CompletionSink, Value );
   END CompletionSink;

(*--------------------------------------------------------------------------------*)

   PUBLIC VIRTUAL PROCEDURE Complete( Result : Sync.TAsyncResult; CONST Source : basecompletion.ICompletionSource; OperationHandle : PTR );
   VAR
      sink : TPICompletionSink := CompletionSink;
   BEGIN
      OnCompleted( Result, Source, OperationHandle );
      IF sink <> NIL THEN
         sink^.OnCompleted( Result, Source, OperationHandle );
      END;
   END Complete;

(*--------------------------------------------------------------------------------*)

   PUBLIC PROPERTY Client GET : TPICompletionSink;
   BEGIN
      RETURN Sync.IGetPtr( REF _Client );
   END Client;

(*--------------------------------------------------------------------------------*)

   PUBLIC PROPERTY Client SET( Value : TPICompletionSink );
   BEGIN
      Sync.IExchgPtr( REF _Client, Value );
   END Client;

(*--------------------------------------------------------------------------------*)

BEGIN
END CSimpleCompletable;

(*================================================================================*)

CLASS IMPLEMENTATION CSimpleWaitableCompletable;

(*--------------------------------------------------------------------------------*)

   INTERNAL VIRTUAL PROCEDURE OnCompleted( Result : Sync.TAsyncResult; CONST Source : basecompletion.ICompletionSource; OperationHandle : PTR );
   BEGIN
   END OnCompleted;

(*--------------------------------------------------------------------------------*)

   PUBLIC VIRTUAL PROPERTY CompletionSink GET : TPICompletionSink;
   BEGIN
      RETURN SUPER.CompletionSink;
   END CompletionSink;

(*--------------------------------------------------------------------------------*)

   PUBLIC VIRTUAL PROPERTY CompletionSink SET( Value : TPICompletionSink );
   BEGIN
      SUPER.CompletionSink := Value;
   END CompletionSink;

(*--------------------------------------------------------------------------------*)

   PUBLIC VIRTUAL PROCEDURE Complete( Result : Sync.TAsyncResult; CONST Source : basecompletion.ICompletionSource; OperationHandle : PTR );
   BEGIN
      IF Completed THEN
         RETURN;
      END;
      Sync.ISetAR( REF _Result, Result );
      SUPER.Complete( Result, Source, OperationHandle );
      _Signal.Signal();
   END Complete;

(*--------------------------------------------------------------------------------*)

   PUBLIC VIRTUAL PROPERTY Completed GET : BOOLEAN;
   BEGIN
      RETURN Sync.IGetAR( REF _Result ) <> Sync.arUnknown;
   END Completed;

(*--------------------------------------------------------------------------------*)

   PUBLIC VIRTUAL PROPERTY Result GET : Sync.TAsyncResult;
   BEGIN
      RETURN Sync.IGetAR( REF _Result );
   END Result;

(*--------------------------------------------------------------------------------*)

   PUBLIC VIRTUAL PROCEDURE Reset();
   BEGIN
      Sync.ISetAR( REF _Result, Sync.arUnknown );
      _Signal.Reset();
   END Reset;

(*--------------------------------------------------------------------------------*)

   PUBLIC VIRTUAL PROCEDURE WaitForCompletion( Timeout : CARDINAL ) : Sync.TAsyncResult; // arTimeout or copies Result property
   BEGIN
      IF Completed THEN
         RETURN Sync.arAlreadyCompleted;
      ELSIF _Signal.Wait( Timeout ) = Sync.arTimeout THEN
         RETURN Sync.arTimeout;
      ELSE
         RETURN Result;
      END;
   END WaitForCompletion;

(*--------------------------------------------------------------------------------*)

   PUBLIC VIRTUAL PROPERTY SignalType GET : Sync.TSignalType;
   BEGIN
      RETURN _Signal.Type;
   END SignalType;

(*--------------------------------------------------------------------------------*)

   PUBLIC VIRTUAL PROPERTY SignalType SET( Value : Sync.TSignalType );
   BEGIN
      _Signal.Dispose();
      _Signal.Init( Value, L"", FALSE );
   END SignalType;

(*--------------------------------------------------------------------------------*)

BEGIN
   _Signal.Init( Sync.stSpin, L"", FALSE );
END CSimpleWaitableCompletable;

(*================================================================================*)

END basecompletion.
