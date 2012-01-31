IMPLEMENTATION MODULE io;

(*===========================================================================*)

CLASS IMPLEMENTATION CDataInfo;

(*---------------------------------------------------------------------------*)

   PUBLIC VIRTUAL PROCEDURE OnAdvise( Source : TPIO; CONST Result : ARRAY OF Sync.TAsyncResult; CONST Item : ARRAY OF ns.THash; CONST Value : ARRAY OF iovalue.Value );
   BEGIN
      IF AdviseSink <> NIL THEN
         AdviseSink^.OnAdvise( Source, Result, Item, Value );
      END;
      IF DataInfoSink <> NIL THEN
         DataInfoSink^.OnAdvise( Source, Result, Item, Value );
      END;
   END OnAdvise;

(*---------------------------------------------------------------------------*)

   PUBLIC VIRTUAL PROCEDURE OnError( Direction : IOO.TDirection; Source : TPIO; CONST Result : ARRAY OF Sync.TAsyncResult; CONST Item : ARRAY OF ns.THash; CONST DeviceSpecificError : ARRAY OF CARDINAL );
   BEGIN
      IF DataInfoSink <> NIL THEN
         DataInfoSink^.OnError( Direction, Source, Result, Item, DeviceSpecificError );
      END;
   END OnError;
  
(*---------------------------------------------------------------------------*)

   PUBLIC VIRTUAL PROCEDURE OnIOCompleted( Direction : IOO.TDirection; Source : TPIO; CONST Result : ARRAY OF Sync.TAsyncResult; CONST Item : ARRAY OF ns.THash; CONST DeviceSpecificError : ARRAY OF CARDINAL; CONST Value : ARRAY OF iovalue.Value );
   BEGIN
      IF DataInfoSink <> NIL THEN
         DataInfoSink^.OnIOCompleted( Direction, Source, Result, Item, DeviceSpecificError, Value );
      END;
   END OnIOCompleted;

(*---------------------------------------------------------------------------*)

BEGIN
   AdviseSink := NIL;
   DataInfoSink := NIL;
END CDataInfo;

(*===========================================================================*)

TYPE
   TPCompletionDataInfoSink = POINTER TO CCompletionDataInfoSink;

CLASS CCompletionDataInfoSink IMPLEMENTS IDataInfo;
   LOCAL VAR
      _CompletionDataInfo : POINTER TO CCompletionDataInfo;
      _Signal : Sync.SIGNAL;
      _Result : Sync.TAsyncResult;
      _Value : iovalue.Value;

   // IDataInfo      
   PUBLIC VIRTUAL PROCEDURE OnAdvise( Source : TPIO; CONST Result : ARRAY OF Sync.TAsyncResult; CONST Item : ARRAY OF ns.THash; CONST Value : ARRAY OF iovalue.Value );
   PUBLIC VIRTUAL PROCEDURE OnError( Direction : IOO.TDirection; Source : TPIO; CONST Result : ARRAY OF Sync.TAsyncResult; CONST Item : ARRAY OF ns.THash; CONST DeviceSpecificError : ARRAY OF CARDINAL );
   PUBLIC VIRTUAL PROCEDURE OnIOCompleted( Direction : IOO.TDirection; Source : TPIO; CONST Result : ARRAY OF Sync.TAsyncResult; CONST Item : ARRAY OF ns.THash; CONST DeviceSpecificError : ARRAY OF CARDINAL; CONST Value : ARRAY OF iovalue.Value );

   // SELF
   PUBLIC PROCEDURE Reset();
   PUBLIC PROCEDURE WaitCompletion( TimeoutMS : CARDINAL; OUT Value : iovalue.Value ) : Sync.TAsyncResult;
END CCompletionDataInfoSink;

(*---------------------------------------------------------------------------*)

CLASS IMPLEMENTATION CCompletionDataInfoSink;

(*---------------------------------------------------------------------------*)

   PUBLIC VIRTUAL PROCEDURE OnAdvise( Source : TPIO; CONST Result : ARRAY OF Sync.TAsyncResult; CONST Item : ARRAY OF ns.THash; CONST Value : ARRAY OF iovalue.Value );
   BEGIN
      // dummy
   END OnAdvise;

(*---------------------------------------------------------------------------*)

   PUBLIC VIRTUAL PROCEDURE OnError( Direction : IOO.TDirection; Source : TPIO; CONST Result : ARRAY OF Sync.TAsyncResult; CONST Item : ARRAY OF ns.THash; CONST DeviceSpecificError : ARRAY OF CARDINAL );
   BEGIN
      // dummy
   END OnError;

(*---------------------------------------------------------------------------*)

   PUBLIC VIRTUAL PROCEDURE OnIOCompleted( Direction : IOO.TDirection; Source : TPIO; CONST Result : ARRAY OF Sync.TAsyncResult; CONST Item : ARRAY OF ns.THash; CONST DeviceSpecificError : ARRAY OF CARDINAL; CONST Value : ARRAY OF iovalue.Value );
   BEGIN
      _Result := Result[0];
      IF ( _Result = Sync.arCompleted ) AND ( Direction = IOO.dirRead ) THEN
         _Value := Value[0];
      END;
      _Signal.Signal();
   END OnIOCompleted;

(*---------------------------------------------------------------------------*)

   PUBLIC PROCEDURE Reset();
   BEGIN
      _Result := Sync.arCannotStart;
      _Signal.Reset();
      _Value.Dispose();
   END Reset;

(*---------------------------------------------------------------------------*)

   PUBLIC PROCEDURE WaitCompletion( TimeoutMS : CARDINAL; OUT Value : iovalue.Value ) : Sync.TAsyncResult;
   VAR
      Result : Sync.TAsyncResult;
   BEGIN
      Result := _Signal.Wait( TimeoutMS );
      IF Result = Sync.arTimeout THEN
         _Result := Sync.arTimeout;
      ELSIF ( Result = Sync.arCompleted ) AND NOT Value.Undefined THEN
         Value := _Value;
      END;
      RETURN _Result;
   END WaitCompletion;

(*---------------------------------------------------------------------------*)

BEGIN
   _CompletionDataInfo := NIL;
   _Signal.Init( Sync.stEvent, L"", FALSE );
   _Result := Sync.arCannotStart;
END CCompletionDataInfoSink;

(*---------------------------------------------------------------------------*)

CLASS IMPLEMENTATION CCompletionDataInfo;

(*---------------------------------------------------------------------------*)

   PUBLIC PROCEDURE Reset();
   BEGIN
      TPCompletionDataInfoSink( DataInfoSink )^.Reset();
   END Reset;

(*---------------------------------------------------------------------------*)

   PUBLIC PROCEDURE WaitCompletion( TimeoutMS : CARDINAL; OUT Value : iovalue.Value ) : Sync.TAsyncResult;
   BEGIN
      RETURN TPCompletionDataInfoSink( DataInfoSink )^.WaitCompletion( TimeoutMS, OUT Value );
   END WaitCompletion;

(*---------------------------------------------------------------------------*)

BEGIN
   DataInfoSink := NEW( CCompletionDataInfoSink );
   TPCompletionDataInfoSink( DataInfoSink )^._CompletionDataInfo := ADR( SELF );
FINALLY
   DISPOSE( TPCompletionDataInfoSink( DataInfoSink ));
END CCompletionDataInfo;

(*===========================================================================*)

CLASS IMPLEMENTATION CSimpleOriginator;

(*---------------------------------------------------------------------------*)

   PUBLIC VIRTUAL PROPERTY Description GET : StringsO.CString;
   BEGIN
      RETURN _Description;
   END Description;

(*---------------------------------------------------------------------------*)

   PUBLIC PROCEDURE SetDescription( CONST Description : StringsO.CString );
   BEGIN
      _Description := Description;
   END SetDescription;
   
(*---------------------------------------------------------------------------*)

END CSimpleOriginator;

(*===========================================================================*)

CLASS IMPLEMENTATION AItemizedIO;

(*---------------------------------------------------------------------------*)

   PUBLIC VIRTUAL PROPERTY Capabilities GET : TCapabilities;
   BEGIN
      RETURN TCapabilities{};
   END Capabilities;

(*---------------------------------------------------------------------------*)

   PUBLIC VIRTUAL PROCEDURE IOha( CONST Originator : ns.TPOriginator; Direction : IOO.TDirection; Item : ARRAY OF ns.THash; REF Value : ARRAY OF iovalue.Value; Callback : TPDataInfo ) : Sync.TAsyncResult;
   BEGIN
      RETURN Sync.arCannotStart;
   END IOha;

(*---------------------------------------------------------------------------*)

END AItemizedIO;

(*===========================================================================*)

CLASS IMPLEMENTATION CSimpleStartStopHandler;

(*---------------------------------------------------------------------------*)

   PUBLIC FINAL PROPERTY Running GET : BOOLEAN;
   BEGIN
      RETURN _Running.State;
   END Running;

(*---------------------------------------------------------------------------*)

   PUBLIC FINAL PROCEDURE Start() : Sync.TAsyncResult;
   VAR
      Result : Sync.TAsyncResult;
   BEGIN
      IF NOT _Running.Signal() THEN
         RETURN Sync.arAlreadyCompleted;
      ELSIF StartStopSink = NIL THEN
         RETURN Sync.arCompleted;
      END;
      Result := StartStopSink^.OnStart();
      IF Result NOT IN Sync.arsCompletions THEN // in case of error revert signal back
         _Running.Reset();
      END;
      RETURN Result;
   END Start;

(*---------------------------------------------------------------------------*)

   PUBLIC FINAL PROCEDURE Stop();
   BEGIN
      IF NOT _Running.Reset() THEN
         RETURN;
      ELSIF StartStopSink = NIL THEN
         RETURN;
      END;
      StartStopSink^.OnStop();
   END Stop;

(*---------------------------------------------------------------------------*)

BEGIN
END CSimpleStartStopHandler;

(*===========================================================================*)

END io.