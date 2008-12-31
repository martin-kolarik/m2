IMPLEMENTATION MODULE SDAPClient;

IMPORT
   rawconnection,
   winerror;

(*================================================================================*)

TYPE
   TPSDAPClient = POINTER TO CSDAPClient;

(*================================================================================*)

CLASS CNotifier( netsocket.CSocketNotifier );
   LOCAL VAR
      Client : TPSDAPClient;
   PUBLIC VIRTUAL PROCEDURE OnReadable( Length : CARDINAL; Source : ADDRESS );
   LOCAL VIRTUAL PROCEDURE OnConnect( Result : CARDINAL; CONST Socket : TPDSocket; Local : BOOLEAN ); 
   LOCAL VIRTUAL PROCEDURE OnDisconnect( Result : CARDINAL; CONST Socket : TPDSocket; Local : BOOLEAN ); // calling Socket^.Release is safe if OnDisconnect is called from OnHandle. Otherwise (when OnDisconnect is called synchronously from Disconnect) it can be dangerous.
END CNotifier;

(*--------------------------------------------------------------------------------*)

CLASS CSDAPClient IMPLEMENTS ISDAPClient;
   // ISDAPClient
   PUBLIC VIRTUAL PROCEDURE Dispose();

   PUBLIC VIRTUAL PROCEDURE Connect( Host : ARRAY OF WCHAR ) : CARDINAL;
   PUBLIC VIRTUAL PROCEDURE Close();
   PUBLIC VIRTUAL PROCEDURE SetAdvise( AdviseEnabled : BOOLEAN ) : CARDINAL;

   PUBLIC VIRTUAL PROCEDURE Write( CONST Data : ARRAY OF WCHAR; CONST Value : ARRAY OF WCHAR ) : CARDINAL;
   PUBLIC VIRTUAL PROCEDURE Ask( CONST Data : ARRAY OF WCHAR ) : CARDINAL;
   
   PUBLIC VIRTUAL PROCEDURE SetNotifier( Notifier : TPISDAPClientEvents );
   
   // callbacks
   LOCAL PROCEDURE OnConnect( Error : CARDINAL );
   LOCAL PROCEDURE OnDisconnect( Error : CARDINAL; Local : BOOLEAN );
   LOCAL PROCEDURE OnReadable( Length : CARDINAL );
   
   // self
   PRIVATE VAR
      _Connection : rawconnection.TCPConnection;
      _NetworkNotifier : CNotifier;
      _ClientNotifier : TPISDAPClientEvents;
END CSDAPClient;

(*================================================================================*)

CLASS IMPLEMENTATION CNotifier;

(*--------------------------------------------------------------------------------*)

   PUBLIC VIRTUAL PROCEDURE OnReadable( Length : CARDINAL; Source : ADDRESS );
   BEGIN
      Client^.OnReadable( Length );
   END OnReadable;

(*--------------------------------------------------------------------------------*)

   LOCAL VIRTUAL PROCEDURE OnConnect( Result : CARDINAL; CONST Socket : TPDSocket; Local : BOOLEAN ); 
   BEGIN
      Client^.OnConnect( Result );
   END OnConnect;

(*--------------------------------------------------------------------------------*)

   LOCAL VIRTUAL PROCEDURE OnDisconnect( Result : CARDINAL; CONST Socket : TPDSocket; Local : BOOLEAN ); // calling Socket^.Release is safe if OnDisconnect is called from OnHandle. Otherwise (when OnDisconnect is called synchronously from Disconnect) it can be dangerous.
   BEGIN
      Client^.OnDisconnect( Result, Local );
   END OnDisconnect;

(*--------------------------------------------------------------------------------*)

END CNotifier;

(*================================================================================*)

CLASS IMPLEMENTATION CSDAPClient;

(*--------------------------------------------------------------------------------*)

   PUBLIC VIRTUAL PROCEDURE Dispose();
   VAR
      a : ADDRESS;
   BEGIN
      a := ADR( SELF );
      DISPOSE( a );
   END Dispose;

(*--------------------------------------------------------------------------------*)

   PUBLIC VIRTUAL PROCEDURE Connect( Host : ARRAY OF WCHAR ) : CARDINAL;
   VAR
      Result : Sync.TAsyncResult;
   BEGIN
      IF _Connection.Connected THEN
         RETURN winerror.WSAEALREADY;
      END;
      CASE _Connection.Open( Host, Sync.FORSAFETY, FALSE ) OF
      | Sync.arCompleted :
         RETURN winerror.S_OK;
      | Sync.arTimeout :
         RETURN winerror.WSAETIMEDOUT;
      | Sync.arPending :
         RETURN winerror.WSAEWOULDBLOCK;
      ELSE
         RETURN winerror.WSAEABORTED;
      END;   
   END Connect;

(*--------------------------------------------------------------------------------*)

   PUBLIC VIRTUAL PROCEDURE Close();
   BEGIN
      _Connection.Close();
   END Close;

(*--------------------------------------------------------------------------------*)

   PUBLIC VIRTUAL PROCEDURE SetAdvise( AdviseEnabled : BOOLEAN ) : CARDINAL;
   BEGIN
      IF NOT _Connection.Connected THEN
         RETURN winerror.WSAENOTCONN;
      END;
      _Connection.Stream^.WriteOA( L"advise all", Sync.FORSAFETY, FALSE );
      RETURN winerror.S_OK;
   END SetAdvise;

(*--------------------------------------------------------------------------------*)

   PUBLIC VIRTUAL PROCEDURE Write( CONST Data : ARRAY OF WCHAR; CONST Value : ARRAY OF WCHAR ) : CARDINAL;
   BEGIN
   END Write;

(*--------------------------------------------------------------------------------*)

   PUBLIC VIRTUAL PROCEDURE Ask( CONST Data : ARRAY OF WCHAR ) : CARDINAL;
   BEGIN
   END Ask;
   
(*--------------------------------------------------------------------------------*)

   PUBLIC VIRTUAL PROCEDURE SetNotifier( Notifier : TPISDAPClientEvents );
   BEGIN
      _ClientNotifier := Notifier;
   END SetNotifier;

(*--------------------------------------------------------------------------------*)

   LOCAL PROCEDURE OnConnect( Error : CARDINAL );
   BEGIN
      IF _ClientNotifier <> NIL THEN
         _ClientNotifier^.OnConnect( Error );
      END;
   END OnConnect;

(*--------------------------------------------------------------------------------*)

   LOCAL PROCEDURE OnDisconnect( Error : CARDINAL; Local : BOOLEAN );
   BEGIN
      IF _ClientNotifier <> NIL THEN
         _ClientNotifier^.OnClose( Error );
      END;
   END OnDisconnect;

(*--------------------------------------------------------------------------------*)

   LOCAL PROCEDURE OnReadable( Length : CARDINAL );
   BEGIN
      
   END OnReadable;

(*--------------------------------------------------------------------------------*)

BEGIN
   _ClientNotifier := NIL;
END CSDAPClient;

(*================================================================================*)

VAR
   StartCount : INTEGER := 0;

(*--------------------------------------------------------------------------------*)

PROCEDURE Startup() : CARDINAL;
VAR
   count : INTEGER;
BEGIN
   count := Sync.IInc( REF StartCount );
   IF count = 1 THEN
      scinit.Startup();
   END;
END Startup;

(*--------------------------------------------------------------------------------*)

PROCEDURE Cleanup();
VAR
   count : INTEGER;
BEGIN
   count := Sync.IDec( REF StartCount );
   IF count = 0 THEN
      scinit.Cleanup();
   END;
END Cleanup;

(*--------------------------------------------------------------------------------*)

PROCEDURE newSDAPClient( OUT client : TPISDAPClient ) : CARDINAL;
BEGIN
   IF Sync.IExcghAdd( REF StartCount, 0 ) > 0 THEN
      NEW( TPSDAPClient( client ));
      RETURN winerror.S_OK;
   ELSE
      RETURN winerror.not initialized
   END;
END newSDAPClient;

(*================================================================================*)

END SDAPClient;