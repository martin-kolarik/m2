IMPLEMENTATION MODULE rawconnection;

FROM Debug IMPORT
   Assertion, LogAssertionW;

(*================================================================================*)

TYPE
   TPConnectionNotifier = POINTER TO CConnectionNotifier;

CLASS CConnectionNotifier( netsocket.ASocketNotifier ) IMPLEMENTS threadcall.IThreadProcedureCallTarget;
   LOCAL VAR
      Connection : POINTER TO IPConnection := NIL;
      Dispatcher : threadcall.TPIThreadProcedureCallDispatcher := NIL;
      Notifier : netsocket.TPSocketNotifier := NIL;

   PUBLIC VIRTUAL PROCEDURE OnError( Direction : IOO.TDirection; Error : CARDINAL; Source : ADDRESS; SourceSpecificCode : LONGWORD );
   PUBLIC VIRTUAL PROCEDURE OnFlowPossible( Direction : IOO.TDirection; Source : ADDRESS );
   PUBLIC VIRTUAL PROCEDURE OnReadable( Length : CARDINAL; Source : ADDRESS );
   PUBLIC VIRTUAL PROCEDURE OnWritten( Length : CARDINAL; Source : ADDRESS );

   LOCAL VIRTUAL PROCEDURE OnListen( Result : CARDINAL; CONST Socket : netsocket.TPSSocket );
   LOCAL VIRTUAL PROCEDURE OnDataArrived( Result : CARDINAL; CONST Socket : netsocket.TPSSocket );
   LOCAL VIRTUAL PROCEDURE OnAccept( Result : CARDINAL; CONST Socket : netsocket.TPDSocket ); 
   LOCAL VIRTUAL PROCEDURE OnConnect( Result : CARDINAL; CONST Socket : netsocket.TPDSocket; Local : BOOLEAN ); 
   LOCAL VIRTUAL PROCEDURE OnDisconnect( Result : CARDINAL; CONST Socket : netsocket.TPDSocket; Local : BOOLEAN ); // calling Socket^.Release is safe if OnDisconnect is called from OnHandle. Otherwise (when OnDisconnect is called synchronously from Disconnect) it can be dangerous.

   PUBLIC VIRTUAL PROCEDURE Invoke( Operation : CARDINAL; CONST Parameters : ARRAY OF PTR ) : PTR;
END CConnectionNotifier;

(*--------------------------------------------------------------------------------*)

TYPE
   TOnErrorParameters = RECORD
      Direction : IOO.TDirection;
      Error : CARDINAL;
      SourceSpecificCode : LONGWORD;
   END; // RECORD
   TPOnErrorParameters = POINTER TO TOnErrorParameters;
   
   TOnDisconnectParameters = RECORD
      Result : CARDINAL;
      Local : BOOLEAN;
   END; // RECORD
   TPOnDisconnectParameters = POINTER TO TOnDisconnectParameters;
   
CONST
   opOnError = 1;
   opOnFlowPossible = 2;
   opOnReadable = 3;
   opOnWritten = 4;
   opOnConnect = 5;
   opOnDisconnect = 6;

(*--------------------------------------------------------------------------------*)

CLASS IMPLEMENTATION CConnectionNotifier;

(*--------------------------------------------------------------------------------*)

   PUBLIC VIRTUAL PROCEDURE OnError( Direction : IOO.TDirection; Error : CARDINAL; Source : ADDRESS; SourceSpecificCode : LONGWORD );
   VAR
      P : TOnErrorParameters;
      p : PTR := ADR( P );
   BEGIN
      IF Source <> Connection^._Socket THEN
         // accept only errors from socket
      ELSIF Notifier = NIL THEN
         // do nothing

      ELSIF Dispatcher = NIL THEN
         Notifier^.OnError( Direction, Error, NIL, SourceSpecificCode );

      ELSE
         P.Direction := Direction;
         P.Error := Error;
         P.SourceSpecificCode := SourceSpecificCode;
         IF Dispatcher^.DispatchCall( ADR( SELF ), opOnError, OA( 0, ADR( p )), NIL, TRUE, Sync.FORSAFETY ) = Sync.arTimeout THEN
            ASSERTLOG( FALSE );
         END;

      END;
   END OnError;

(*--------------------------------------------------------------------------------*)

   PUBLIC VIRTUAL PROCEDURE OnFlowPossible( Direction : IOO.TDirection; Source : ADDRESS );
   VAR
      p : PTR := ADR( Direction );
   BEGIN
      IF Source = Connection^._Socket THEN
         // accept only notifications from stream
      ELSIF Notifier = NIL THEN
         // do nothing

      ELSIF Dispatcher = NIL THEN
         Notifier^.OnFlowPossible( Direction, NIL );

      ELSE
         IF Dispatcher^.DispatchCall( ADR( SELF ), opOnFlowPossible, OA( 0, ADR( p )), NIL, TRUE, Sync.FORSAFETY ) = Sync.arTimeout THEN
            ASSERTLOG( FALSE );
         END;

      END;
   END OnFlowPossible;

(*--------------------------------------------------------------------------------*)

   PUBLIC VIRTUAL PROCEDURE OnReadable( Length : CARDINAL; Source : ADDRESS );
   VAR
      p : PTR := ADR( Length );
   BEGIN
      IF Source = Connection^._Socket THEN
         // accept only notifications from stream
      ELSIF Notifier = NIL THEN
         // do nothing

      ELSIF Dispatcher = NIL THEN
         Notifier^.OnReadable( Length, NIL );

      ELSE
         IF Dispatcher^.DispatchCall( ADR( SELF ), opOnReadable, OA( 0, ADR( p )), NIL, TRUE, Sync.FORSAFETY ) = Sync.arTimeout THEN
            ASSERTLOG( FALSE );
         END;

      END;
   END OnReadable;

(*--------------------------------------------------------------------------------*)

   PUBLIC VIRTUAL PROCEDURE OnWritten( Length : CARDINAL; Source : ADDRESS );
   VAR
      p : PTR := ADR( Length );
   BEGIN
      IF Source = Connection^._Socket THEN
         // accept only errors from stream
      ELSIF Notifier = NIL THEN
         // do nothing

      ELSIF Dispatcher = NIL THEN
         Notifier^.OnWritten( Length, NIL );

      ELSE
         IF Dispatcher^.DispatchCall( ADR( SELF ), opOnWritten, OA( 0, ADR( p )), NIL, TRUE, Sync.FORSAFETY ) = Sync.arTimeout THEN
            ASSERTLOG( FALSE );
         END;

      END;
   END OnWritten;

(*--------------------------------------------------------------------------------*)

   LOCAL VIRTUAL PROCEDURE OnListen( Result : CARDINAL; CONST Socket : netsocket.TPSSocket );
   BEGIN
   END OnListen;

(*--------------------------------------------------------------------------------*)

   LOCAL VIRTUAL PROCEDURE OnDataArrived( Result : CARDINAL; CONST Socket : netsocket.TPSSocket );
   BEGIN
   END OnDataArrived;

(*--------------------------------------------------------------------------------*)

   LOCAL VIRTUAL PROCEDURE OnAccept( Result : CARDINAL; CONST Socket : netsocket.TPDSocket ); 
   BEGIN
   END OnAccept;

(*--------------------------------------------------------------------------------*)

   LOCAL VIRTUAL PROCEDURE OnConnect( Result : CARDINAL; CONST Socket : netsocket.TPDSocket; Local : BOOLEAN ); 
   VAR
      p : PTR := ADR( Result );
   BEGIN
      IF Notifier = NIL THEN
         // do nothing

      ELSIF Dispatcher = NIL THEN
         Notifier^.OnConnect( Result, NIL, TRUE );

      ELSE
         IF Dispatcher^.DispatchCall( ADR( SELF ), opOnConnect, OA( 0, ADR( p )), NIL, TRUE, Sync.FORSAFETY ) = Sync.arTimeout THEN
            ASSERTLOG( FALSE );
         END;

      END;
   END OnConnect;

(*--------------------------------------------------------------------------------*)

   LOCAL VIRTUAL PROCEDURE OnDisconnect( Result : CARDINAL; CONST Socket : netsocket.TPDSocket; Local : BOOLEAN ); // calling Socket^.Release is safe if OnDisconnect is called from OnHandle. Otherwise (when OnDisconnect is called synchronously from Disconnect) it can be dangerous.
   VAR
      P : TOnDisconnectParameters;
      p : PTR := ADR( P );
   BEGIN
      IF Notifier = NIL THEN
         // do nothing

      ELSIF Dispatcher = NIL THEN
         Notifier^.OnDisconnect( Result, NIL, Local );

      ELSE
         P.Result := Result;
         P.Local := Local;
         IF Dispatcher^.DispatchCall( ADR( SELF ), opOnDisconnect, OA( 0, ADR( p )), NIL, TRUE, Sync.FORSAFETY ) = Sync.arTimeout THEN
            ASSERTLOG( FALSE );
         END;

      END;
   END OnDisconnect;

(*--------------------------------------------------------------------------------*)

   PUBLIC VIRTUAL PROCEDURE Invoke( Operation : CARDINAL; CONST Parameters : ARRAY OF PTR ) : PTR;
   TYPE
      TPDirection = POINTER TO IOO.TDirection;
   BEGIN
      CASE Operation OF
      | opOnError :
         Notifier^.OnError( TPOnErrorParameters( Parameters[0] )^.Direction, TPOnErrorParameters( Parameters[0] )^.Error, NIL, TPOnErrorParameters( Parameters[0] )^.SourceSpecificCode );

      | opOnFlowPossible : 
         Notifier^.OnFlowPossible( TPDirection( Parameters[0] )^, NIL );

      | opOnReadable :
         Notifier^.OnReadable( PCARDINAL( Parameters[0] )^, NIL );

      | opOnWritten :
         Notifier^.OnWritten( PCARDINAL( Parameters[0] )^, NIL );

      | opOnConnect :
         Notifier^.OnConnect( PCARDINAL( Parameters[0] )^, NIL, TRUE );
      
      | opOnDisconnect :
         Notifier^.OnDisconnect( TPOnDisconnectParameters( Parameters[0] )^.Result, NIL, TPOnDisconnectParameters( Parameters[0] )^.Local );
         
      END;
      RETURN 0;
   END Invoke;

(*--------------------------------------------------------------------------------*)

BEGIN
END CConnectionNotifier;

(*================================================================================*)

CLASS IMPLEMENTATION IPConnection;
BEGIN
   NEW( _Notifier );
   _Notifier^.Connection := ADR( SELF );
   
   _Socket := NIL;
   
   _BStream.Stream := ADR( _NStream );
   _BStream.Notifier := _Notifier;

FINALLY
   _BStream.Close( FALSE );
   _BStream.Stream := NIL;
   // _NStream is closed inside _BStream
   
   _Notifier^.Release();
   _Notifier := NIL;
END IPConnection;

(*================================================================================*)

CLASS IMPLEMENTATION ClientIPConnection;

(*--------------------------------------------------------------------------------*)

   PUBLIC VIRTUAL PROPERTY Connected GET : BOOLEAN;
   BEGIN
      RETURN _Socket^.Connected;
   END Connected;
   
(*--------------------------------------------------------------------------------*)

   PUBLIC VIRTUAL PROPERTY LocalAddress GET : inetaddr.INETADDR;
   BEGIN
      RETURN _Socket^.LocalAddress;
   END LocalAddress;

(*--------------------------------------------------------------------------------*)

   PUBLIC VIRTUAL PROPERTY RemoteAddress GET : inetaddr.INETADDR;
   BEGIN
      RETURN _Socket^.RemoteAddress;
   END RemoteAddress;

(*--------------------------------------------------------------------------------*)

   PUBLIC VIRTUAL PROPERTY Stream GET : IOO.TPStream;
   BEGIN
      RETURN ADR( _BStream );
   END Stream;
   
(*--------------------------------------------------------------------------------*)

   PUBLIC VIRTUAL PROCEDURE Close();
   BEGIN
      IF _Socket^.Connected THEN
         _Socket^.Disconnect( TRUE, netsocket.FORSAFETY );
      END;
      _BStream.Close( TRUE );
   END Close;

(*--------------------------------------------------------------------------------*)

   PUBLIC VIRTUAL PROCEDURE Open( Host : ARRAY OF WCHAR; WaitForResult : BOOLEAN; TimeoutMS : CARDINAL ) : Sync.TAsyncResult;
   VAR
      Result : Sync.TAsyncResult;
   BEGIN
      Close();
      
      _Socket^.Waitable := WaitForResult;
      Result := _Socket^.Connect( Host, TimeoutMS );
      
      IF NOT WaitForResult THEN
         RETURN Result;
      ELSIF TimeoutMS < Sync.FOREVER - 100 THEN
         RETURN _Socket^.WaitCompletion( TimeoutMS + 100 );
      ELSE
         RETURN _Socket^.WaitCompletion( Sync.FOREVER );
      END;
   END Open;

(*--------------------------------------------------------------------------------*)

   PUBLIC VIRTUAL PROPERTY Dispatcher GET : threadcall.TPIThreadProcedureCallDispatcher;
   BEGIN
      RETURN _Notifier^.Dispatcher;
   END Dispatcher;
   
(*--------------------------------------------------------------------------------*)

   PUBLIC VIRTUAL PROPERTY Dispatcher SET( Value : threadcall.TPIThreadProcedureCallDispatcher );
   BEGIN
      _Notifier^.Dispatcher := Value;
   END Dispatcher;

(*--------------------------------------------------------------------------------*)

   PUBLIC VIRTUAL PROPERTY Notifier GET : netsocket.TPSocketNotifier;
   BEGIN
      RETURN _Notifier^.Notifier;
   END Notifier;
   
(*--------------------------------------------------------------------------------*)

   PUBLIC VIRTUAL PROPERTY Notifier SET( Value: netsocket.TPSocketNotifier );
   BEGIN
      _Notifier^.Notifier := Value;
   END Notifier;
   
(*--------------------------------------------------------------------------------*)

   PUBLIC VIRTUAL PROPERTY BufferedStream GET : IOO.TPBufferedStream;
   BEGIN
      RETURN ADR( _BStream );
   END BufferedStream;
   
(*--------------------------------------------------------------------------------*)

   PUBLIC PROCEDURE OpenS( CONST Host : StringsO.IString; WaitForResult : BOOLEAN; TimeoutMS : CARDINAL ) : Sync.TAsyncResult;
   BEGIN
      RETURN Open( OA( Host.Length-1, Host.Data ), WaitForResult, TimeoutMS );
   END OpenS;

(*--------------------------------------------------------------------------------*)

END ClientIPConnection;

(*================================================================================*)

CLASS IMPLEMENTATION ClientTCPConnection;
BEGIN
   NEW( _Socket );
   _Socket^.Type := netsocket.stStream;

   _Socket^.Notifier := _Notifier;
   _NStream.FromSocket( _Socket, FALSE, IOO.accReadWrite );
FINALLY
   IF _Socket <> NIL THEN
      _Socket^.Notifier := NIL;
      _Socket^.Disconnect( TRUE, netsocket.FORSAFETY );
      _Socket^.Release();
      _Socket := NIL;
   END;
END ClientTCPConnection;

(*================================================================================*)

CLASS IMPLEMENTATION ClientUDPConnection;
BEGIN
   NEW( _Socket );
   _Socket^.Type := netsocket.stDatagram;

   _Socket^.Notifier := _Notifier;
   _NStream.FromSocket( _Socket, FALSE, IOO.accReadWrite );
FINALLY
   IF _Socket <> NIL THEN
      _Socket^.Notifier := NIL;
      _Socket^.Disconnect( TRUE, netsocket.FORSAFETY );
      _Socket^.Release();
      _Socket := NIL;
   END;
END ClientUDPConnection;

(*================================================================================*)

CLASS IMPLEMENTATION ServerTCPConnection;

(*--------------------------------------------------------------------------------*)

   PUBLIC VIRTUAL PROPERTY Connected GET : BOOLEAN;
   BEGIN
      RETURN _Socket^.Connected;
   END Connected;
   
(*--------------------------------------------------------------------------------*)

   PUBLIC VIRTUAL PROPERTY LocalAddress GET : inetaddr.INETADDR;
   BEGIN
      RETURN _Socket^.LocalAddress;
   END LocalAddress;

(*--------------------------------------------------------------------------------*)

   PUBLIC VIRTUAL PROPERTY RemoteAddress GET : inetaddr.INETADDR;
   BEGIN
      RETURN _Socket^.RemoteAddress;
   END RemoteAddress;

(*--------------------------------------------------------------------------------*)

   PUBLIC VIRTUAL PROPERTY Stream GET : IOO.TPStream;
   BEGIN
      RETURN ADR( _BStream );
   END Stream;
   
(*--------------------------------------------------------------------------------*)

   PUBLIC VIRTUAL PROCEDURE Close();
   BEGIN
      IF _Socket^.Connected THEN
         _Socket^.Disconnect( TRUE, netsocket.FORSAFETY );
      END;
      _BStream.Close( TRUE );
   END Close;

(*--------------------------------------------------------------------------------*)

   PUBLIC VIRTUAL PROPERTY Dispatcher GET : threadcall.TPIThreadProcedureCallDispatcher;
   BEGIN
      RETURN _Notifier^.Dispatcher;
   END Dispatcher;
   
(*--------------------------------------------------------------------------------*)

   PUBLIC VIRTUAL PROPERTY Dispatcher SET( Value : threadcall.TPIThreadProcedureCallDispatcher );
   BEGIN
      _Notifier^.Dispatcher := Value;
   END Dispatcher;

(*--------------------------------------------------------------------------------*)

   PUBLIC VIRTUAL PROPERTY Notifier GET : netsocket.TPSocketNotifier;
   BEGIN
      RETURN _Notifier^.Notifier;
   END Notifier;
   
(*--------------------------------------------------------------------------------*)

   PUBLIC VIRTUAL PROPERTY Notifier SET( Value: netsocket.TPSocketNotifier );
   BEGIN
      _Notifier^.Notifier := Value;
   END Notifier;
   
(*--------------------------------------------------------------------------------*)

   PUBLIC VIRTUAL PROPERTY BufferedStream GET : IOO.TPBufferedStream;
   BEGIN
      RETURN ADR( _BStream );
   END BufferedStream;
   
(*--------------------------------------------------------------------------------*)

   PUBLIC PROCEDURE Accept( CONST ListenSocket : netsocket.TPSSocket; WaitForResult : BOOLEAN; TimeoutMS : CARDINAL ) : Sync.TAsyncResult; // WaitForResult, TimeoutMS not implemented yet
   VAR
      Error : CARDINAL := 0;
      Result : Sync.TAsyncResult;
   BEGIN
      Result := _Socket^.Accept( ListenSocket, OUT Error );
      IF Result NOT IN Sync.arsCompletions THEN
         RETURN Result; // failure
      ELSIF Error <> 0 THEN
         RETURN Sync.arCannotStart; // strange
      ELSE
         RETURN Result; // success
      END;
   END Accept;

(*--------------------------------------------------------------------------------*)

BEGIN
   NEW( _Socket );
   _Socket^.Type := netsocket.stStream;

   _Socket^.Notifier := _Notifier;
   _NStream.FromSocket( _Socket, FALSE, IOO.accReadWrite );
FINALLY
   IF _Socket <> NIL THEN
      _Socket^.Notifier := NIL;
      _Socket^.Disconnect( TRUE, netsocket.FORSAFETY );
      _Socket^.Release();
      _Socket := NIL;
   END;
END ServerTCPConnection;

(*================================================================================*)

END rawconnection.