IMPLEMENTATION MODULE SDAPBridge;

FROM Debug IMPORT
   Assertion, LogAssertionW;

FROM log IMPORT
   dldError, dldMessage, dldTrace, dldDebug;
  
FROM driver IMPORT
   R;
   
IMPORT
   Log,
   Strings,
   Sync;
   
CONST
   CRLF = 13W + 10W;
   RECONNECT_TIMEOUT = 10000; // 10 seconds
   LOG_NAME = L"NET";

(*===============================================================================*)

TYPE
   TRequestType = (
      reqUnknown,
      reqSet,
      reqAsk,
      reqAdvise,
      reqUnadvise
   );
   
   TPRequest = POINTER TO CRequest;

(*-------------------------------------------------------------------------------*)

CLASS CRequest;
   LOCAL VAR
      Type    : TRequestType;
      Address : StringsO.CString;
      Data    : StringsO.CString;
END CRequest;

(*-------------------------------------------------------------------------------*)

CLASS IMPLEMENTATION CRequest;
BEGIN
   Type := reqUnknown;
END CRequest;

(*===============================================================================*)

CLASS IMPLEMENTATION CSDAP;

(*-------------------------------------------------------------------------------*)

   PUBLIC PROPERTY Connected GET : BOOLEAN;
   BEGIN
      IF _Client = NIL THEN
         RETURN FALSE;
      ELSE
         RETURN _Client^.Connected;
      END;
   END Connected;

(*-------------------------------------------------------------------------------*)

   PUBLIC PROPERTY OutputQueueCount GET : CARDINAL;
   BEGIN
      RETURN _Queue.Count;
   END OutputQueueCount;

(*-------------------------------------------------------------------------------*)

   PUBLIC PROPERTY OutputQueueLength GET : CARDINAL;
   BEGIN
      RETURN _QueueLength;
   END OutputQueueLength;

(*-------------------------------------------------------------------------------*)

   PUBLIC PROPERTY OutputQueueLength SET( Value : CARDINAL );
   VAR
      request : TPRequest;
   BEGIN
      _QueueLength := MAX2( 2, Value );
      WHILE _Queue.Count > _QueueLength DO // if new queue length is greater than current, forget the first entries
         IF _Queue.Dequeue( OUT request ) THEN
            DISPOSE( request );
         END;
      END; // WHILE
   END OutputQueueLength;

(*-------------------------------------------------------------------------------*)

   PUBLIC VIRTUAL PROCEDURE Dispose();
   BEGIN
      DisposeQueue();
      _QueueSignal.Dispose();

      IF _Client <> NIL THEN
         _Client^.Dispose();
         _Client := NIL;
      END;
   END Dispose;

(*-------------------------------------------------------------------------------*)

   PUBLIC PROCEDURE SetConfiguration( CONST ClientName : ARRAY OF WCHAR; CONST LoggerToClone : log.CLogger; CONST Host : StringsO.CString );
   VAR
      LongName : ARRAY [0..255] OF WCHAR;
   BEGIN
      Strings.ConcatW( OUT LongName, L"SDAPBridge.", ClientName );
      _Logger.SetUpByLogger( LoggerToClone );
      _Logger.SetLogName( LongName );

      IF _Client <> NIL THEN
         _Client^.Disconnect();
      END;
      _Host := Host;
   END SetConfiguration;
      
(*-------------------------------------------------------------------------------*)

   PUBLIC PROCEDURE Run() : Sync.TAsyncResult;
   BEGIN
      IF _Running THEN
         RETURN Sync.arAlreadyPending;
      ELSIF _Client = NIL THEN
         RETURN Sync.arCannotStart;
      END;
      _Running := TRUE;

      IF NOT threadpool.pool()^.WaitHandle( ADR( _PoolSink ), 0, RECONNECT_TIMEOUT, FALSE, FALSE, _QueueSignal.RawHandle, OUT _QueueSignalPoolHandle ) THEN
         ASSERTLOG( FALSE );
      END;

      RETURN _Client^.Connect( _Host );
   END Run;

(*-------------------------------------------------------------------------------*)

   PUBLIC PROCEDURE Stop();
   BEGIN
      IF NOT _Running THEN
         RETURN;
      ELSIF _Client = NIL THEN
         RETURN;
      END;
      _Running := FALSE;
      
      _Client^.Disconnect();

      DisposeQueue();
   END Stop;

(*-------------------------------------------------------------------------------*)

   PUBLIC PROCEDURE Set( CONST Data, Value : StringsO.CString ) : Sync.TAsyncResult;
   VAR
      request : TPRequest;
   BEGIN
      NEW( request );
      request^.Type := reqSet;
      request^.Address := Data;
      request^.Data := Value;
      RETURN Enqueue( request );
   END Set;

(*-------------------------------------------------------------------------------*)

   PUBLIC PROCEDURE Ask( CONST Data : StringsO.CString ) : Sync.TAsyncResult;
   VAR
      request : TPRequest;
   BEGIN
      NEW( request );
      request^.Type := reqAsk;
      request^.Address := Data;
      RETURN Enqueue( request );
   END Ask;

(*-------------------------------------------------------------------------------*)

   PUBLIC PROCEDURE Advise() : Sync.TAsyncResult;
   VAR
      request : TPRequest;
   BEGIN
      NEW( request );
      request^.Type := reqAdvise;
      RETURN Enqueue( request );
   END Advise;

(*-------------------------------------------------------------------------------*)

   PUBLIC PROCEDURE Unadvise() : Sync.TAsyncResult;
   VAR
      request : TPRequest;
   BEGIN
      NEW( request );
      request^.Type := reqUnadvise;
      RETURN Enqueue( request );
   END Unadvise;

(*-------------------------------------------------------------------------------*)

   LOCAL VIRTUAL PROCEDURE OnHandle( Result : Sync.TAsyncResult; PoolHandle : threadpool.TPoolHandle; UserId : PTR );
   VAR
      request : TPRequest;
   BEGIN
      IF Result = Sync.arTimeout THEN
         IF NOT threadpool.pool()^.WaitHandle( ADR( _PoolSink ), 0, RECONNECT_TIMEOUT, FALSE, FALSE, _QueueSignal.RawHandle, OUT _QueueSignalPoolHandle ) THEN
            ASSERTLOG( FALSE );
         END;
         
         IF ( _Client <> NIL ) AND NOT _Client^.Connected THEN
            _Logger.LogS( Log.dldTrace, LOG_NAME, L"Not connected, try to connect again" );
            _Client^.Connect( _Host );                  
         END;
         
         RETURN;
      END;
   
      WHILE _Queue.Dequeue( OUT request ) DO

         IF _Client <> NIL THEN
            CASE request^.Type OF
            | reqSet :
               _Client^.Write( request^.Address, request^.Data );
            | reqAsk :
               _Client^.Ask( request^.Address );
            | reqAdvise :
               _Client^.SetAdvise( TRUE );
            | reqUnadvise :
               _Client^.SetAdvise( FALSE );
            END; // CASE
         END;
      
         DISPOSE( request );
      END; // WHILE
   END OnHandle;

(*-------------------------------------------------------------------------------*)

   PUBLIC VIRTUAL PROCEDURE OnConnect( Result : Sync.TAsyncResult; Error : CARDINAL );
   BEGIN
      IF Result = Sync.arCompleted THEN
         IF EventSink <> NIL THEN
            EventSink^.OnConnected();
         END;
      ELSE
         _Logger.LogSC( Log.dldTrace, LOG_NAME, L"Connect error:", Error );
      END;
   END OnConnect;

(*-------------------------------------------------------------------------------*)

   PUBLIC VIRTUAL PROCEDURE OnDisconnect( Result : Sync.TAsyncResult; Error : CARDINAL );
   BEGIN
      IF Result <> Sync.arCompleted THEN
         _Logger.LogSC( Log.dldTrace, LOG_NAME, L"Disconnect error:", Error );
      END;
      IF EventSink <> NIL THEN
         EventSink^.OnDisconnected( Result );
      END;
   END OnDisconnect;

(*-------------------------------------------------------------------------------*)

   PUBLIC VIRTUAL PROCEDURE OnReceive( CONST Address, Value : StringsO.IString );
   BEGIN
      IF EventSink <> NIL THEN
         EventSink^.OnData( Address, Value );
      END;
   END OnReceive;

(*-------------------------------------------------------------------------------*)

   PRIVATE PROCEDURE Enqueue( Request : ADDRESS ) : Sync.TAsyncResult;
   VAR
      dequeued : PTR;
   BEGIN
      IF _Queue.Count > _QueueLength THEN
         _Queue.Dequeue( OUT dequeued );
      END;
      _Queue.Enqueue( Request );

      RETURN Sync.arPending;
   END Enqueue;

(*-------------------------------------------------------------------------------*)

   PRIVATE PROCEDURE DisposeQueue();
   VAR
      request : TPRequest;
   BEGIN
      WHILE _Queue.Dequeue( OUT request ) DO
         DISPOSE( request );
      END; // WHILE
      IF _QueueSignalPoolHandle <> NIL THEN
         threadpool.pool()^.Abort( REF _QueueSignalPoolHandle );
      END;
   END DisposeQueue;

(*-------------------------------------------------------------------------------*)

BEGIN
   _Running := FALSE;
   _QueueLength := 1000;
   _QueueSignal.Init( Sync.stEventAutoreset, L"", FALSE );
   _Queue.Consume := ADR( _QueueSignal );
   _QueueSignalPoolHandle := NIL;
   _PoolSink.HandleSink := ADR( SELF );
   EventSink := NIL;

   IF SDAPClient.newSDAPClient( OUT _Client ) = Sync.arCompleted THEN
      _Client^.EventListener := ADR( SELF );
   ELSE
      ASSERTLOG( FALSE );
   END;

FINALLY
   Dispose();
END CSDAP;

(*===============================================================================*)

END SDAPBridge.