IMPLEMENTATION MODULE Request;

FROM Debug IMPORT
   AssertionW;

(*================================================================================*)

CLASS IMPLEMENTATION CRequest;

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

   PUBLIC PROCEDURE Complete( Result : Sync.TAsyncResult ); // principal completion action, callable from any source
   BEGIN
      IF Completed THEN
         RETURN;
      END;
      Sync.ISetAR( REF _Result, Result );
      IF Sink <> NIL THEN
         Sink^.OnCompleted( ICompletable );
      END;
      _Signal.Signal();
   END Complete;

(*--------------------------------------------------------------------------------*)

   PUBLIC PROPERTY SignalType GET : Sync.TSignalType;
   BEGIN
      RETURN _Signal.Type;
   END SignalType;

(*--------------------------------------------------------------------------------*)

   PUBLIC PROPERTY SignalType SET( Value : Sync.TSignalType );
   BEGIN
      Complete( Sync.arAborted );
      _Signal.Dispose();
      _Signal.Init( Value, L"", FALSE );
   END SignalType;

(*--------------------------------------------------------------------------------*)

   PUBLIC PROPERTY Sink GET : TPICompletionSink;
   BEGIN
      RETURN _Sink;
   END Sink;

(*--------------------------------------------------------------------------------*)

   PUBLIC PROPERTY Sink SET( Value : TPICompletionSink );
   BEGIN
      _Sink := Value;
   END Sink;

(*--------------------------------------------------------------------------------*)

   PUBLIC PROPERTY Value GET : PTR;
   BEGIN
      RETURN _Value;
   END Value;

(*--------------------------------------------------------------------------------*)

   PUBLIC PROPERTY Value SET( _Value : PTR );
   BEGIN
      SELF._Value := _Value;
   END Value;

(*--------------------------------------------------------------------------------*)

BEGIN
   _Signal.Init( Sync.stSpin, L"", FALSE );
END CRequest;

(*================================================================================*)

CLASS IMPLEMENTATION CAbortableRequest;

(*--------------------------------------------------------------------------------*)

   PUBLIC VIRTUAL PROCEDURE Abort();
   BEGIN
      Complete( Sync.arAborted );
   END Abort;

(*--------------------------------------------------------------------------------*)

END CAbortableRequest;

(*================================================================================*)

END Request.
