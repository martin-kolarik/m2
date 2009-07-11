IMPLEMENTATION MODULE SDAPClient;

FROM Storage IMPORT
   ALLOCATE, DEALLOCATE;
   
FROM Debug IMPORT
   Assertion;

IMPORT
   IOO,
   netinit,
   netsocket,
   rawconnection,
   Strings,
   StringsO,
   Sync,
   TextReader,
   TextWriter,
   threadinit,
   winerror,
   winsock;

(*================================================================================*)

TYPE
   TPSDAPClient = POINTER TO CSDAPClient;

(*================================================================================*)

CLASS CNotifier( netsocket.ASocketNotifier );
   LOCAL VAR
      Client : TPSDAPClient;
   PUBLIC VIRTUAL PROCEDURE OnFlowPossible( Direction : IOO.TDirection; Source : ADDRESS );
   PUBLIC VIRTUAL PROCEDURE OnReadable( Length : CARDINAL; Source : ADDRESS );
   LOCAL VIRTUAL PROCEDURE OnConnect( Result : CARDINAL; CONST Socket : netsocket.TPDSocket; Local : BOOLEAN ); 
   LOCAL VIRTUAL PROCEDURE OnDisconnect( Result : CARDINAL; CONST Socket : netsocket.TPDSocket; Local : BOOLEAN ); // calling Socket^.Release is safe if OnDisconnect is called from OnHandle. Otherwise (when OnDisconnect is called synchronously from Disconnect) it can be dangerous.
END CNotifier;

(*--------------------------------------------------------------------------------*)

TYPE
   TReadState = (
      rdsWaitStatus,
      rdsWaitData
   );

CLASS CSDAPClient IMPLEMENTS ISDAPClient;
   // ISDAPClient
   PUBLIC VIRTUAL PROCEDURE Dispose();

   PUBLIC VIRTUAL PROCEDURE Connect( Host : ARRAY OF WCHAR ) : CARDINAL;
   PUBLIC VIRTUAL PROCEDURE Close();
   PUBLIC VIRTUAL PROCEDURE SetAdvise( AdviseEnabled : BOOLEAN ) : CARDINAL;
   PUBLIC VIRTUAL PROCEDURE IsConnected() : BOOLEAN;

   PUBLIC VIRTUAL PROCEDURE Write( CONST Data : ARRAY OF WCHAR; CONST Value : ARRAY OF WCHAR ) : CARDINAL;
   PUBLIC VIRTUAL PROCEDURE Ask( CONST Data : ARRAY OF WCHAR ) : CARDINAL;
   
   PUBLIC VIRTUAL PROCEDURE SetEventListener( Listener : TPISDAPClientEvents );
   
   // callbacks
   LOCAL PROCEDURE OnConnect( Error : CARDINAL );
   LOCAL PROCEDURE OnDisconnect( Error : CARDINAL; Local : BOOLEAN );
   LOCAL PROCEDURE OnReadingPossible();
   LOCAL PROCEDURE OnDataReceived();
   
   // self
   PRIVATE VAR
      _Connection : rawconnection.TCPConnection;
      _NetworkNotifier : CNotifier;
      _ClientNotifier : TPISDAPClientEvents;
      _Reader : TextReader.CTextReader;
      _Writer : TextWriter.CTextWriter;
      _ReadState : TReadState := rdsWaitStatus;
      _DataCount : CARDINAL := 0;
      
   PRIVATE PROCEDURE DoWrite( CONST s1, s2, s3 : ARRAY OF WCHAR ) : CARDINAL;
END CSDAPClient;

(*================================================================================*)

CLASS IMPLEMENTATION CNotifier;

(*--------------------------------------------------------------------------------*)

   PUBLIC VIRTUAL PROCEDURE OnFlowPossible( Direction : IOO.TDirection; Source : ADDRESS );
   BEGIN
      IF Direction = IOO.dirRead THEN
         Client^.OnReadingPossible();
      END;
   END OnFlowPossible;

(*--------------------------------------------------------------------------------*)

   PUBLIC VIRTUAL PROCEDURE OnReadable( Length : CARDINAL; Source : ADDRESS );
   BEGIN
      Client^.OnDataReceived();
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
      _Connection.Notifier := NIL;
      Close();

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
      RETURN DoWrite( L"get", Data, L"" );
   END Ask;
   
(*--------------------------------------------------------------------------------*)

   PUBLIC VIRTUAL PROCEDURE SetEventListener( Listener : TPISDAPClientEvents );
   BEGIN
      _ClientNotifier := Listener;
   END SetEventListener;

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

   LOCAL PROCEDURE OnReadingPossible();
   BEGIN
      _Reader.StartReading();
   END OnReadingPossible;

(*--------------------------------------------------------------------------------*)

   LOCAL PROCEDURE OnDataReceived();
   VAR
      a : ADDRESS;
      i, l : CARDINAL;
      Line : StringsO.CString;
      s, t : StringsO.CString;
   BEGIN
      LOOP
         IF NOT _Reader.Peek( OUT a, OUT l ) THEN
            EXIT;
         ELSIF _Reader.ReadLine( OUT Line, Sync.FORSAFETY, TRUE ) <> Sync.arCompleted THEN
            ASSERT( FALSE );
         END;
         
         CASE _ReadState OF
         //-----
         | rdsWaitStatus :
            IF Line.Length <= 3 THEN // only a status code without data, not interesting
               CONTINUE;
            END;
            Line.Substring( 4, -1, OUT s );
            IF NOT s.ToCARD32( 10, OUT _DataCount ) THEN
               _DataCount := 0;
            END;
            IF _DataCount > 0 THEN
               _ReadState := rdsWaitData;
            END;

         //-----
         | rdsWaitData : // now line contains data
            i := Line.ItemS( StringsO.WCHARS{L" "}, 0, 0, FALSE, OUT s );
            Line.ItemS( StringsO.WCHARS{L" "}, i, 0, FALSE, OUT t );
            IF NOT s.Empty AND NOT t.Empty AND ( _ClientNotifier <> NIL ) THEN
               _ClientNotifier^.OnReceive( OA( s.Length-1, s.szData ), OA( t.Length-1, t.szData ));
            END;

            DEC( _DataCount );
            IF _DataCount = 0 THEN
               _ReadState := rdsWaitStatus;
            END;
         
         END; // CASE
      END; // LOOP
   END OnDataReceived;

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
   _Connection.Notifier := ADR( _NetworkNotifier );
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
      threadinit.Startup();
      netinit.Startup();
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
      netinit.Cleanup();
      threadinit.Cleanup();
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