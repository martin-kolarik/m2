IMPLEMENTATION MODULE SDAPClient;

FROM Storage IMPORT
   ALLOCATE, DEALLOCATE;

IMPORT
   netsocket,
   rawconnection,
   scinit,
   Strings,
   Sync,
   TextReader,
   TextWriter,
   winerror,
   winsock;

(*================================================================================*)

TYPE
   TPSDAPClient = POINTER TO CSDAPClient;

(*================================================================================*)

CLASS CNotifier( netsocket.ASocketNotifier );
   LOCAL VAR
      Client : TPSDAPClient;
   PUBLIC VIRTUAL PROCEDURE OnReadable( Length : CARDINAL; Source : ADDRESS );
   LOCAL VIRTUAL PROCEDURE OnConnect( Result : CARDINAL; CONST Socket : netsocket.TPDSocket; Local : BOOLEAN ); 
   LOCAL VIRTUAL PROCEDURE OnDisconnect( Result : CARDINAL; CONST Socket : netsocket.TPDSocket; Local : BOOLEAN ); // calling Socket^.Release is safe if OnDisconnect is called from OnHandle. Otherwise (when OnDisconnect is called synchronously from Disconnect) it can be dangerous.
END CNotifier;

(*--------------------------------------------------------------------------------*)

CLASS CSDAPClient IMPLEMENTS ISDAPClient;
   // ISDAPClient
   PUBLIC VIRTUAL PROCEDURE Dispose();

   PUBLIC VIRTUAL PROCEDURE Connect( Host : ARRAY OF WCHAR ) : CARDINAL;
   PUBLIC VIRTUAL PROCEDURE Close();
   PUBLIC VIRTUAL PROCEDURE SetAdvise( AdviseEnabled : BOOLEAN ) : CARDINAL;
   PUBLIC VIRTUAL PROCEDURE IsConnected() : BOOLEAN;

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
      _Reader : TextReader.CTextReader;
      _Writer : TextWriter.CTextWriter;
      
   PRIVATE PROCEDURE DoWrite( CONST s1, s2, s3 : ARRAY OF WCHAR ) : CARDINAL;
END CSDAPClient;

(*================================================================================*)

CLASS IMPLEMENTATION CNotifier;

(*--------------------------------------------------------------------------------*)

   PUBLIC VIRTUAL PROCEDURE OnReadable( Length : CARDINAL; Source : ADDRESS );
   BEGIN
      Client^.OnReadable( Length );
   END OnReadable;

(*--------------------------------------------------------------------------------*)

   LOCAL VIRTUAL PROCEDURE OnConnect( Result : CARDINAL; CONST Socket : netsocket.TPDSocket; Local : BOOLEAN ); 
   BEGIN
      Client^.OnConnect( Result );
   END OnConnect;

(*--------------------------------------------------------------------------------*)

   LOCAL VIRTUAL PROCEDURE OnDisconnect( Result : CARDINAL; CONST Socket : netsocket.TPDSocket; Local : BOOLEAN ); // calling Socket^.Release is safe if OnDisconnect is called from OnHandle. Otherwise (when OnDisconnect is called synchronously from Disconnect) it can be dangerous.
   BEGIN
      Client^.OnDisconnect( Result, Local );
   END OnDisconnect;

(*--------------------------------------------------------------------------------*)

BEGIN
   Client := NIL;
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
   BEGIN
      IF _Connection.Connected THEN
         RETURN winsock.WSAEALREADY;
      END;
      CASE _Connection.Open( Host, FALSE, Sync.FORSAFETY ) OF
      | Sync.arCompleted :
         RETURN 0;
      | Sync.arTimeout :
         RETURN winsock.WSAETIMEDOUT;
      | Sync.arPending :
         RETURN winsock.WSAEWOULDBLOCK;
      ELSE
         RETURN winsock.WSAEFAULT;
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
      RETURN DoWrite( L"advise", L"all", L"" );
   END SetAdvise;

(*--------------------------------------------------------------------------------*)

   PUBLIC VIRTUAL PROCEDURE IsConnected() : BOOLEAN;
   BEGIN
      RETURN _Connection.Connected;
   END IsConnected;

(*--------------------------------------------------------------------------------*)

   PUBLIC VIRTUAL PROCEDURE Write( CONST Data : ARRAY OF WCHAR; CONST Value : ARRAY OF WCHAR ) : CARDINAL;
   BEGIN
      RETURN DoWrite( L"set", Data, Value );
   END Write;

(*--------------------------------------------------------------------------------*)

   PUBLIC VIRTUAL PROCEDURE Ask( CONST Data : ARRAY OF WCHAR ) : CARDINAL;
   BEGIN
      RETURN DoWrite( L"ask", Data, L"" );
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

   PRIVATE PROCEDURE DoWrite( CONST s1, s2, s3 : ARRAY OF WCHAR ) : CARDINAL;
   VAR
      s : ARRAY [0..127] OF WCHAR;
   BEGIN
      IF NOT _Connection.Connected THEN
         RETURN winsock.WSAENOTCONN;
      END;
      Strings.ConcatW( OUT s, s1, L" " );
      Strings.AppendW( REF s, s2 );
      Strings.AppendW( REF s, L" " );
      Strings.AppendW( REF s, s3 );
      CASE _Writer.WriteTimeoutOA( s, TRUE, Sync.FORSAFETY ) OF
      | Sync.arCompleted :
         RETURN 0;
      | Sync.arTimeout :
         RETURN winsock.WSAETIMEDOUT;
      ELSE
         RETURN winsock.WSAEFAULT;
      END;   
   END DoWrite;

(*--------------------------------------------------------------------------------*)

BEGIN
   _NetworkNotifier.Client := ADR( SELF );
   _ClientNotifier := NIL;
   _Reader.Stream := _Connection.Stream;
   _Writer.Stream := _Connection.Stream;
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
   RETURN 0;
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
   IF Sync.IExchgAdd( REF StartCount, 0 ) > 0 THEN
      NEW( TPSDAPClient( client ));
      RETURN 0;
   ELSE
      RETURN winsock.WSAENETDOWN;
   END;
END newSDAPClient;

(*================================================================================*)

END SDAPClient.