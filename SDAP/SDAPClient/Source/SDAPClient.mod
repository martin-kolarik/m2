IMPLEMENTATION MODULE SDAPClient;

FROM Storage IMPORT
   ALLOCATE, DEALLOCATE;
   
FROM Debug IMPORT
   Assertion, LogAssertionW;

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
   PUBLIC VIRTUAL READONLY PROPERTY
      Connected : BOOLEAN;
   PUBLIC VIRTUAL PROPERTY
      EventListener : TPISDAPClientEvents;
   
   PUBLIC VIRTUAL PROCEDURE Dispose();

   PUBLIC VIRTUAL PROCEDURE Connect( CONST Host : StringsO.IString ) : Sync.TAsyncResult;
   PUBLIC VIRTUAL PROCEDURE Disconnect();
   PUBLIC VIRTUAL PROCEDURE SetAdvise( AdviseEnabled : BOOLEAN ) : Sync.TAsyncResult;

   PUBLIC VIRTUAL PROCEDURE Write( CONST Data, Value : StringsO.IString ) : Sync.TAsyncResult;
   PUBLIC VIRTUAL PROCEDURE Ask( CONST Data : StringsO.IString ) : Sync.TAsyncResult;
   
   // callbacks
   LOCAL PROCEDURE OnConnect( Error : CARDINAL );
   LOCAL PROCEDURE OnDisconnect( Error : CARDINAL; Local : BOOLEAN );
   LOCAL PROCEDURE OnReadingPossible();
   LOCAL PROCEDURE OnDataReceived();
   
   // self
   PRIVATE VAR
      _Connection : rawconnection.ClientTCPConnection;
      _NetworkNotifier : CNotifier;
      _ClientNotifier : TPISDAPClientEvents;
      _Reader : TextReader.CTextReader;
      _Writer : TextWriter.CTextWriter;
      _ReadState : TReadState := rdsWaitStatus;
      _DataCount : CARDINAL := 0;
      
   PRIVATE PROCEDURE DoWriteOA( CONST cmd, s1, s2 : ARRAY OF WCHAR ) : Sync.TAsyncResult;
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

   PUBLIC VIRTUAL PROPERTY Connected GET : BOOLEAN;
   BEGIN
      RETURN _Connection.Connected;
   END Connected;

(*--------------------------------------------------------------------------------*)

   PUBLIC VIRTUAL PROPERTY EventListener GET : TPISDAPClientEvents;
   BEGIN
      RETURN _ClientNotifier;
   END EventListener;

(*--------------------------------------------------------------------------------*)

   PUBLIC VIRTUAL PROPERTY EventListener SET( Value : TPISDAPClientEvents );
   BEGIN
      _ClientNotifier := Value;
   END EventListener;

(*--------------------------------------------------------------------------------*)

   PUBLIC VIRTUAL PROCEDURE Dispose();
   VAR
      a : ADDRESS;
   BEGIN
      _Connection.Notifier := NIL;
      Disconnect();

      a := ADR( SELF );
      DISPOSE( a );
   END Dispose;

(*--------------------------------------------------------------------------------*)

   PUBLIC VIRTUAL PROCEDURE Connect( CONST Host : StringsO.IString ) : Sync.TAsyncResult;
   BEGIN
      IF _Connection.Connected THEN
         RETURN Sync.arAlreadyPending;
      ELSE
         RETURN _Connection.OpenS( Host, 6007, FALSE, Sync.FORSAFETY );
      END;
   END Connect;

(*--------------------------------------------------------------------------------*)

   PUBLIC VIRTUAL PROCEDURE Disconnect();
   BEGIN
      _Connection.Close();
   END Disconnect;

(*--------------------------------------------------------------------------------*)

   PUBLIC VIRTUAL PROCEDURE SetAdvise( AdviseEnabled : BOOLEAN ) : Sync.TAsyncResult;
   BEGIN
      RETURN DoWriteOA( L"advise", L"all", L"" );
   END SetAdvise;

(*--------------------------------------------------------------------------------*)

   PUBLIC VIRTUAL PROCEDURE Write( CONST Data, Value : StringsO.IString ) : Sync.TAsyncResult;
   BEGIN
      RETURN DoWriteOA( L"set", OA( Data.Length-1, Data.Data ), OA( Value.Length-1, Value.Data ));
   END Write;

(*--------------------------------------------------------------------------------*)

   PUBLIC VIRTUAL PROCEDURE Ask( CONST Data : StringsO.IString ) : Sync.TAsyncResult;
   BEGIN
      RETURN DoWriteOA( L"get", OA( Data.Length-1, Data.Data ), L"" );
   END Ask;
   
(*--------------------------------------------------------------------------------*)

   LOCAL PROCEDURE OnConnect( Error : CARDINAL );
   BEGIN
      IF _ClientNotifier <> NIL THEN
         IF Error = 0 THEN
            _ClientNotifier^.OnConnect( Sync.arCompleted, Error );
            _Reader.StartReading();
         ELSE
            _ClientNotifier^.OnConnect( Sync.arAborted, Error );
         END;
      END;
   END OnConnect;

(*--------------------------------------------------------------------------------*)

   LOCAL PROCEDURE OnDisconnect( Error : CARDINAL; Local : BOOLEAN );
   BEGIN
      IF _ClientNotifier <> NIL THEN
         IF Error = 0 THEN
            _ClientNotifier^.OnDisconnect( Sync.arCompleted, Error );
         ELSE
            _ClientNotifier^.OnDisconnect( Sync.arAborted, Error );
         END;
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
            _Reader.StartReading();
            EXIT;
         ELSIF _Reader.ReadLine( OUT Line, Sync.FORSAFETY, TRUE ) <> Sync.arCompleted THEN
            ASSERTLOG( FALSE );
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
            IF NOT s.Empty AND ( _ClientNotifier <> NIL ) THEN
               _ClientNotifier^.OnReceive( s, t );
            END;

            DEC( _DataCount );
            IF _DataCount = 0 THEN
               _ReadState := rdsWaitStatus;
            END;
         
         END; // CASE
      END; // LOOP
   END OnDataReceived;

(*--------------------------------------------------------------------------------*)

   PRIVATE PROCEDURE DoWriteOA( CONST cmd, s1, s2 : ARRAY OF WCHAR ) : Sync.TAsyncResult;
   VAR
      s : ARRAY [0..127] OF WCHAR;
   BEGIN
      IF NOT _Connection.Connected THEN
         RETURN Sync.arCannotStart;
      END;

      Strings.ConcatW( OUT s, cmd, L" " );
      Strings.AppendW( REF s, s1 );
      Strings.AppendW( REF s, L" " );
      Strings.AppendW( REF s, s2 );

      RETURN _Writer.WriteTimeoutOA( s, TRUE, Sync.FORSAFETY );
   END DoWriteOA;

(*--------------------------------------------------------------------------------*)

BEGIN
   _Connection.Notifier := ADR( _NetworkNotifier );
   _NetworkNotifier.Client := ADR( SELF );
   _ClientNotifier := NIL;
   _Reader.Stream := _Connection.BufferedStream;
   _Writer.Stream := _Connection.BufferedStream;
END CSDAPClient;

(*================================================================================*)

PROCEDURE newSDAPClient( OUT client : TPISDAPClient ) : Sync.TAsyncResult;
BEGIN
   NEW( TPSDAPClient( client ));
   RETURN Sync.arCompleted;
END newSDAPClient;

(*================================================================================*)

END SDAPClient.
