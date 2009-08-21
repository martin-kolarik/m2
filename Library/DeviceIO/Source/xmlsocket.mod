IMPLEMENTATION MODULE xmlsocket;

(*================================================================================*)

FROM Debug IMPORT
   Assertion, LogAssertionW;

IMPORT
   io,
   IOO,
   iovalue,
   Languages,
   LanguagesO,
   msghandler,
   netsocket,
   netsrv,
   ns,
   StorageO,
   Strings,
   StringsO,
   Sync;
   
CONST
   LOG_XMLS = L"xmls";   

(*================================================================================*)

TYPE
   TPClient = POINTER TO CClient;

CLASS CClient IMPLEMENTS io.IAdviseInfo;
   PRIVATE VAR
      BatchLock : Sync.LOCK;
   LOCAL VAR
      Server : TPXMLSocketServer;
      Connection : netconndispatch.TConnectionHandle;
      RBuffer : StorageO.CMemoryBuffer;
      WBuffer : StorageO.CMemoryBuffer;

   // IAdviseInfo
   PUBLIC VIRTUAL PROCEDURE OnAdvise( Source : io.TPIO; CONST Result : ARRAY OF Sync.TAsyncResult; CONST Item : ARRAY OF ns.THash; CONST Value : ARRAY OF iovalue.Value );
   
   // SELF
   PUBLIC PROCEDURE StartBatch();
   PUBLIC PROCEDURE AddItem( CONST Item : ns.THash; CONST Value : iovalue.Value );
   PUBLIC PROCEDURE StopAndSendBatch();
END CClient;

(*================================================================================*)

CONST
  LEAD_XMLSOCKET = C'<xmlsocket';
  TRAIL_XMLSOCKET = C'</xmlsocket';
  LEAD_NOTIFY = C'<notify';
  TRAIL_NOTIFY = C'</notify';
  LEAD_ASK = C'<ask';
  TRAIL_ASK = C'</ask';
  LEAD_NAME = C'<name';
  TRAIL_NAME = C'</name';
  LEAD_VALUE = C'<value';
  TRAIL_VALUE = C'</value';
  LEAD_CONNECT = C'<connect';
  TRAIL_CONNECT = C'/>';
  LEAD_DISCONNECT = C'<disconnect';
  TRAIL_DISCONNECT = C'/>';
  TRAIL = C'>';
  
CONST
   MSG_SCHEDULED_SEND = msghandler.MSG_BASE;

(*================================================================================*)

CLASS IMPLEMENTATION CXMLSocketServer;

(*--------------------------------------------------------------------------------*)

   INTERNAL VIRTUAL PROCEDURE OnMessage( CONST Message : msghandler.IMessage; OUT Result : PTR ) : BOOLEAN;
   VAR
      SendData : arrays.TPPtrArray;
   BEGIN
      IF SUPER.OnMessage( Message, OUT Result ) THEN
         RETURN TRUE;

      ELSIF Message.Message = MSG_SCHEDULED_SEND THEN
         WHILE _SendQueue.Dequeue( OUT SendData  ) DO
            RealizeSend( SendData );
            DISPOSE( SendData );
         END; // _SendQueue

         RETURN TRUE;
      
      ELSE
         RETURN FALSE;
      END;
   END OnMessage;

(*--------------------------------------------------------------------------------*)

   PUBLIC PROPERTY Device GET : adviser.TPAdvisedDevice;
   BEGIN
      RETURN _Device;
   END Device;

(*--------------------------------------------------------------------------------*)

   PUBLIC PROPERTY Device SET( Value : adviser.TPAdvisedDevice );
   BEGIN
      _Device := Value;
   END Device;

(*--------------------------------------------------------------------------------*)

   PUBLIC PROPERTY CommonLogger GET : log.TPILogger;
   BEGIN
      RETURN _CommonLogger;
   END CommonLogger;

(*--------------------------------------------------------------------------------*)

   PUBLIC PROPERTY CommonLogger SET( Value : log.TPILogger );
   BEGIN
      IF _CommonLogger = Value THEN
         RETURN;
      ELSIF Value = NIL THEN
         _CommonLogger := log.logger();
      ELSE
         _CommonLogger := Value;
      END;
   END CommonLogger;

(*--------------------------------------------------------------------------------*)

   PUBLIC PROPERTY NetworkLogger GET : log.TPILogger;
   BEGIN
      RETURN _NetworkLogger;
   END NetworkLogger;

(*--------------------------------------------------------------------------------*)

   PUBLIC PROPERTY NetworkLogger SET( Value : log.TPILogger );
   BEGIN
      IF _NetworkLogger = Value THEN
         RETURN;
      ELSIF Value = NIL THEN
         _NetworkLogger := log.logger();
      ELSE
         _NetworkLogger := Value;
      END;
   END NetworkLogger;

(*--------------------------------------------------------------------------------*)

   PUBLIC PROPERTY ListenAddress GET : inetaddr.INETADDR;
   BEGIN
      RETURN _ListenAddress;
   END ListenAddress;

(*--------------------------------------------------------------------------------*)

   PUBLIC PROPERTY ListenAddress SET( CONST Value : inetaddr.INETADDR );
   BEGIN
      IF _ListenAddress = Value THEN
         RETURN;
      END;
      IF _Running THEN
         Stop();
         _ListenAddress := Value;
         Start();
      ELSE
         _ListenAddress := Value;
      END;
   END ListenAddress;

(*--------------------------------------------------------------------------------*)

   PUBLIC VIRTUAL PROPERTY Running GET : BOOLEAN;
   BEGIN
      RETURN _Running;
   END Running;

(*--------------------------------------------------------------------------------*)

   PUBLIC VIRTUAL PROCEDURE Start() : Sync.TAsyncResult;
   BEGIN
      IF _Running THEN
         RETURN Sync.arCompleted;
      ELSE
         _Running := TRUE;
      END;
      netsrv.StartListen( netsocket.stStream, _ListenAddress, NIL, Listener, 0, NIL );
      RETURN Sync.arCompleted;
   END Start;

(*--------------------------------------------------------------------------------*)

   PUBLIC VIRTUAL PROCEDURE Stop();
   BEGIN
      IF _Running THEN
         _Running := FALSE;
      ELSE
         RETURN;
      END;
      netsrv.StopListenServer( netsocket.stStream, _ListenAddress );
      // kill all connections
   END Stop;

(*--------------------------------------------------------------------------------*)

   INTERNAL VIRTUAL PROCEDURE OnConnect( Connection : netconndispatch.TConnectionHandle; Local : BOOLEAN; Error : CARDINAL );
   VAR
      address : ARRAY [0..63] OF WCHAR;
      Client : TPClient;
   BEGIN
      ASSERTLOG( NOT _Clients.Contains( Connection ));
      
      IF NOT _NetworkLogger^.Filtered( log.dlcError, LOG_XMLS ) THEN
         Connection^.RemoteAddress.GetAddressOA( TRUE, OUT address );
         _NetworkLogger^.LogSS( log.dlcError, LOG_XMLS, "CONNECT:", address );
      END;

      NEW( Client );
      Client^.Server := ADR( SELF );
      Client^.Connection := Connection;

      _Device^.JoinClient( Client, io.advWithData );
      _Device^.AdviseAll( Client );

      _Clients.Add( Connection, Client );
   END OnConnect;

(*--------------------------------------------------------------------------------*)

   INTERNAL VIRTUAL PROCEDURE OnDisconnect( Connection : netconndispatch.TConnectionHandle; Local : BOOLEAN; Error : CARDINAL );
   VAR
      address : ARRAY [0..63] OF WCHAR;
      Client : TPClient;
   BEGIN
      IF NOT _NetworkLogger^.Filtered( log.dlcError, LOG_XMLS ) THEN
         Connection^.RemoteAddress.GetAddressOA( TRUE, OUT address );
         _NetworkLogger^.LogSS( log.dlcError, LOG_XMLS, "DISCONNECT:", address );
      END;

      IF _Clients.Get( Connection, OUT Client ) THEN
         _Clients.Remove( Connection );

         _Device^.UnadviseAll( Client );
         _Device^.LeaveClient( Client );

         DISPOSE( Client );
      END;
   END OnDisconnect;

(*--------------------------------------------------------------------------------*)

   INTERNAL VIRTUAL PROCEDURE OnReceive( Connection : netconndispatch.TConnectionHandle; Data : ADDRESS; DataLen : CARDINAL );
   VAR
      appendLength, i : INTEGER;
      Client : TPClient;
      sd : ARRAY [0..63] OF WCHAR;
   BEGIN
      Connection^.RemoteAddress.GetAddressOA( TRUE, OUT sd );
      _CommonLogger^.LogSS( log.dldDebug, LOG_XMLS, "RCV: ", sd );
      _CommonLogger^.LogSC( log.dldDebug, LOG_XMLS, "  length: ", DataLen );

      IF NOT _Clients.Get( Connection, OUT Client ) THEN
         _CommonLogger^.LogS( log.dldDebug, LOG_XMLS, "  to: unknown connection" );
         RETURN;
      END;
   
      appendLength := MIN2( DataLen, Client^.RBuffer.Size - Client^.RBuffer.Length ); // do not oversize buffer
      Client^.RBuffer.AppendOA( OA( appendLength-1, Data ));
      IF Client^.RBuffer.Length < SIZE( LEAD_XMLSOCKET )-1 THEN
         RETURN; // still not enough data
      END;

      LOOP // parse all input XMLs in buffer
         i := Client^.RBuffer.IndexOfOA( LEAD_XMLSOCKET, 0 );
         IF i = -1 THEN // remove everything except LEADING-1 bytes, which could contain new leading string
            Client^.RBuffer.RemoveStart( MAX2( 0, INTEGER( Client^.RBuffer.Length ) - SIZE( LEAD_XMLSOCKET )-1 + 1 ));
            RETURN; // wait more
         END;
         
         // look for trailing
         i := Client^.RBuffer.IndexOfOA( TRAIL_XMLSOCKET, i );
         IF i <> -1 THEN // have trailing
            // fall down
         ELSIF Client^.RBuffer.Size - Client^.RBuffer.Length < SIZE( TRAIL_XMLSOCKET )-1 THEN // not enough space to store whole XML (LEADING...TRAILING), XML is too big, throw everything
            Client^.RBuffer.RemoveStart( Client^.RBuffer.Length );
            RETURN;
         ELSE // OK, leave buffer, wait for more
            RETURN;
         END;
         
         Parse( Client, OA( i - SIZE( LEAD_XMLSOCKET ), PCHAR( Client^.RBuffer.Data@[SIZE( LEAD_XMLSOCKET )-1] ) )); // slice data inside LEADING and TRAILING
         
         Client^.RBuffer.RemoveStart( i + SIZE( TRAIL_XMLSOCKET )-1 );
      END; // LOOP
   END OnReceive;

(*--------------------------------------------------------------------------------*)

   PRIVATE PROCEDURE ScheduleSend( Client : ADDRESS; Items : arrays.TPPtrArray );
   BEGIN
      Items^.Insert( 0, TPClient( Client )^.Connection );      
      _SendQueue.Enqueue( Items );
   END ScheduleSend;

(*--------------------------------------------------------------------------------*)

   PRIVATE PROCEDURE RealizeSend( Items : arrays.TPPtrArray );
   VAR
      Client : TPClient;
      Connection : netconndispatch.TConnectionHandle;
      i, l : CARDINAL;
      IO : io.TPIO;
      name : StringsO.CString;
      value : iovalue.Value;
   BEGIN
      IO := Device^.IO();
      IF IO = NIL THEN
         ASSERT( FALSE );
         RETURN;
      END; // IF

      // client's presence must be recheck, because scheduled send can arrive after client disconnect
      Connection := Items^[0];
      IF NOT _Clients.Get( Connection, OUT Client ) THEN
         _CommonLogger^.LogS( log.dldDebug, LOG_XMLS, "SND: after disconnect" );
         RETURN;
      END;

      Client^.StartBatch();

      i := 1;
      l := Items^.Count;
      WHILE i < l DO
         IO^.IOh( IOO.dirRead, Items^[i], REF value, NIL );
         Client^.AddItem( Items^[i], value );
         INC( i );
      END; // WHILE
      
      Client^.StopAndSendBatch();
   END RealizeSend;

(*--------------------------------------------------------------------------------*)

   PRIVATE PROCEDURE Parse( Client : ADDRESS; Data : ARRAY OF CHAR );
   TYPE
      TOperation = ( opAsk, opConnect, opDisconnect, opNotify );
   VAR
      high : INTEGER;
      ia, ic, id, in, i, j, current : INTEGER;
      Name, Value : ARRAY [0..511] OF WCHAR;
      operation : TOperation;
      pos, nextpos : INTEGER := 0;
      readRequests : arrays.TPPtrArray := NIL;
   BEGIN
      LOOP

         pos := nextpos;
         high := HIGH( Data ) - pos;
         IF high < 0 THEN
            EXIT; // done
         END;

         ia := Strings.IndexOfA( OA( high, ADR( Data[pos] )), LEAD_ASK, pos );
         ic := Strings.IndexOfA( OA( high, ADR( Data[pos] )), LEAD_CONNECT, pos );
         id := Strings.IndexOfA( OA( high, ADR( Data[pos] )), LEAD_DISCONNECT, pos );
         in := Strings.IndexOfA( OA( high, ADR( Data[pos] )), LEAD_NOTIFY, pos );
         IF ( ia = -1 ) AND ( ic = -1 ) AND ( id = -1 ) AND ( in = -1 ) THEN
            EXIT; // done
         END;
         IF ic <> -1 THEN
            operation := opConnect;
            i := ic;
         ELSIF id <> -1 THEN
            operation := opDisconnect;
            i := id;
         ELSIF in <> -1 THEN
            operation := opNotify;
            i := in;
         ELSIF ia <> -1 THEN
            operation := opAsk;
            i := ia;
         END;
         
         CASE operation OF
         //-----
         | opAsk :
            j := Strings.IndexOfA( OA( high, ADR( Data[pos] )), TRAIL_ASK, ia );
            IF j = -1 THEN
               EXIT; // done
            END;
            current := i + SIZE( LEAD_ASK )-1;
            nextpos := j + SIZE( TRAIL_ASK )-1;

         //-----
         | opConnect :
            j := Strings.IndexOfA( OA( high, ADR( Data[pos] )), TRAIL_CONNECT, ic );
            IF j = -1 THEN
               EXIT; // done
            END;
            nextpos := j + SIZE( TRAIL_CONNECT )-1;

            // handle connect in a short way
            HandleConnect();
            CONTINUE;

         //-----
         | opDisconnect :
            j := Strings.IndexOfA( OA( high, ADR( Data[pos] )), TRAIL_DISCONNECT, id );
            IF j = -1 THEN
               EXIT; // done
            END;
            nextpos := j + SIZE( TRAIL_DISCONNECT )-1;

            // handle disconnect in a short way
            HandleDisconnect();
            CONTINUE;

         //-----
         | opNotify :
            j := Strings.IndexOfA( OA( high, ADR( Data[pos] )), TRAIL_NOTIFY, in );
            IF j = -1 THEN
               EXIT; // done
            END;
            current := i + SIZE( LEAD_NOTIFY )-1;
            nextpos := j + SIZE( TRAIL_NOTIFY )-1;

         //-----
         ELSE
            ASSERTLOG( FALSE );
         END; // CASE

         // parse NAME
         i := Strings.IndexOfA( OA( high, ADR( Data[pos] )), LEAD_NAME, current );
         IF ( i = -1 ) OR ( i >= nextpos ) THEN
            CONTINUE; // the item is empty
         END;
         j := Strings.IndexOfA( OA( high, ADR( Data[pos] )), TRAIL_NAME, i );
         IF ( j = -1 ) OR ( j >= nextpos ) THEN
            CONTINUE; // something bad
         END;
         INC( i, SIZE( LEAD_NAME )-1 );
         Strings.ToW( OA( j-i, ADR( Data[i] )), Languages.cp_UTF8, OUT Name );
         
         IF operation = opNotify THEN
            // parse VALUE
            i := Strings.IndexOfA( OA( high, ADR( Data[pos] )), LEAD_VALUE, current );
            IF ( i = -1 ) OR ( i >= nextpos ) THEN
               CONTINUE; // the item is empty
            END;
            j := Strings.IndexOfA( OA( high, ADR( Data[pos] )), TRAIL_VALUE, i );
            IF ( j = -1 ) OR ( j >= nextpos ) THEN
               CONTINUE; // something bad
            END;
            INC( i, SIZE( LEAD_VALUE )-1 );
            Strings.ToW( OA( j-i, ADR( Data[i] )), Languages.cp_UTF8, OUT Value );
         END;

         // correct strings
         i := Strings.IndexOfCharW( Name, L">", 0 );
         j := Strings.IndexOfCharW( Name, L"<", i );
         IF ( i = -1 ) OR ( j = -1 ) THEN // bad XML
            CONTINUE;
         END;
         Name[j] := 0W;
         Strings.RemoveW( REF Name, 0, i+1 );
         Strings.TrimW( REF Name );
         
         IF operation = opNotify THEN
            i := Strings.IndexOfCharW( Value, L">", 0 );
            j := Strings.IndexOfCharW( Value, L"<", i );
            IF ( i = -1 ) OR ( j = -1 ) THEN // bad XML
               CONTINUE;
            END;
            Value[j] := 0W;
            Strings.RemoveW( REF Value, 0, i+1 );
            Strings.TrimW( REF Value );
         END;
         
         // call back on name and value
         IF operation = opAsk THEN
            IF readRequests = NIL THEN
               NEW( readRequests );
            END;
            HandleRead( Name, REF readRequests );
         ELSE
            HandleWrite( Name, Value );
         END;
         
      END; // LOOP
      
      IF readRequests <> NIL THEN
         ScheduleSend( Client, readRequests );
      END;
   END Parse;
  
(*--------------------------------------------------------------------------------*)

   PRIVATE PROCEDURE HandleConnect();
   BEGIN
      Device^.IO()^.Start();
   END HandleConnect;

(*--------------------------------------------------------------------------------*)

   PRIVATE PROCEDURE HandleDisconnect();
   BEGIN
      Device^.IO()^.Stop();
   END HandleDisconnect;

(*--------------------------------------------------------------------------------*)

   PRIVATE PROCEDURE HandleRead( CONST NameOA : ARRAY OF WCHAR; REF readRequests : arrays.TPPtrArray );
   VAR
      Hash : ns.THash;
      io : iovalue.Value;
      Name : StringsO.CString;
   BEGIN
      Name.FromOA( NameOA );
      _CommonLogger^.LogSS( log.dldTrace, LOG_XMLS, "GET ", NameOA );

      IF NOT Device^.IO()^.Running THEN
         _CommonLogger^.LogS( log.dldDebug, LOG_XMLS, "  device is not running, nothing GET" );
         RETURN;

      ELSIF NOT Device^.Mapper()^.NameToHash( Name, OUT Hash ) THEN
         _CommonLogger^.LogSS( log.dldTrace, LOG_XMLS, "  unknown name, nothing GET: ", NameOA );
         RETURN;

      ELSE
         readRequests^.Add( Hash );

      END;         
   END HandleRead;

(*--------------------------------------------------------------------------------*)

   PRIVATE PROCEDURE HandleWrite( CONST NameOA, Value : ARRAY OF WCHAR );
   VAR
      Hash : ns.THash;
      io : iovalue.Value;
      Name : StringsO.CString;
   BEGIN
      Name.FromOA( NameOA );
      _CommonLogger^.LogSSSS( log.dldTrace, LOG_XMLS, "SET ", NameOA, L" ", Value );

      IF NOT Device^.IO()^.Running THEN
         _CommonLogger^.LogS( log.dldDebug, LOG_XMLS, "  device is not running, nothing SET" );
         RETURN;

      ELSIF NOT Device^.Mapper()^.NameToHash( Name, OUT Hash ) THEN
         _CommonLogger^.LogSS( log.dldTrace, LOG_XMLS, "  unknown name, nothing SET: ", NameOA );
         RETURN;

      ELSE
         io.FromStringOA( Value, FALSE );
         Device^.IO()^.IOh( IOO.dirWrite, Hash, REF io, NIL );
      END;         
   END HandleWrite;

(*--------------------------------------------------------------------------------*)

   LOCAL PROCEDURE Send( Client : ADDRESS; CONST Buffer : StorageO.AMemoryBuffer );
   BEGIN         
      SUPER.Send( NIL, TPClient( Client )^.Connection, 0, Buffer.Data, Buffer.Length );
   END Send;

(*--------------------------------------------------------------------------------*)

   INITIALLY CXMLSocketServer();
   VAR
      msg : msghandler.Message;
   BEGIN
      _CommonLogger := log.logger();
      _NetworkLogger := log.logger();

      msg.Message := MSG_SCHEDULED_SEND;
      _SendQueue.ConsumerMsg := ADR( msg );
      _SendQueue.Consumer := ADR( SELF );
   END CXMLSocketServer;

(*--------------------------------------------------------------------------------*)

   FINALLY CXMLSocketServer();
   BEGIN
      _Clients.Dispose();
      _SendQueue.Clear();
   END CXMLSocketServer;

(*--------------------------------------------------------------------------------*)

END CXMLSocketServer;

(*================================================================================*)

CLASS IMPLEMENTATION CClient;

(*--------------------------------------------------------------------------------*)

   PUBLIC VIRTUAL PROCEDURE OnAdvise( Source : io.TPIO; CONST Result : ARRAY OF Sync.TAsyncResult; CONST Item : ARRAY OF ns.THash; CONST Value : ARRAY OF iovalue.Value );
   VAR
      i : INTEGER;
      n : StringsO.CString;
      s : StringsO.CString;
   BEGIN
      StartBatch();
   
      FOR i := 0 TO HIGH( Item ) DO

         IF NOT Server^.CommonLogger^.Filtered( log.dldTrace, LOG_XMLS ) THEN
            Server^.Device^.Mapper()^.HashToName( Item[i], OUT n );
            s := Value[i].String;
            Server^.CommonLogger^.LogSSSS( log.dldTrace, LOG_XMLS, "ADV ", OA( n.Length-1, n.rawData ), L" ", OA( s.Length-1, s.rawData ));
         END;

         IF Result[i] IN Sync.arsCompletions THEN
            AddItem( Item[i], Value[i] );
         END;
      END; // FOR

      StopAndSendBatch();
   END OnAdvise;

(*--------------------------------------------------------------------------------*)

   PUBLIC PROCEDURE StartBatch();
   BEGIN
      BatchLock.Lock();
   
      WBuffer.Clear();
      WBuffer.AppendOA( OA( SIZE( LEAD_XMLSOCKET )-2, ADR( LEAD_XMLSOCKET ))); WBuffer.AppendByte( TRAIL );
   END StartBatch;

(*--------------------------------------------------------------------------------*)

   PUBLIC PROCEDURE AddItem( CONST Item : ns.THash; CONST Value : iovalue.Value );
   VAR
      S : StringsO.CString;
   BEGIN
      WBuffer.AppendOA( OA( SIZE( LEAD_NOTIFY )-2, ADR( LEAD_NOTIFY ))); WBuffer.AppendByte( TRAIL );

      WBuffer.AppendOA( OA( SIZE( LEAD_NAME )-2, ADR( LEAD_NAME ))); WBuffer.AppendByte( TRAIL );
      Server^.Device^.Mapper()^.HashToName( Item, OUT S );
      LanguagesO.ToMB( S, Languages.cp_UTF8, TRUE, REF WBuffer );
      WBuffer.AppendOA( OA( SIZE( TRAIL_NAME )-2, ADR( TRAIL_NAME ))); WBuffer.AppendByte( TRAIL );
      
      WBuffer.AppendOA( OA( SIZE( LEAD_VALUE )-2, ADR( LEAD_VALUE ))); WBuffer.AppendByte( TRAIL );
      S := Value.String;
      LanguagesO.ToMB( S, Languages.cp_UTF8, TRUE, REF WBuffer );
      WBuffer.AppendOA( OA( SIZE( TRAIL_VALUE )-2, ADR( TRAIL_VALUE ))); WBuffer.AppendByte( TRAIL );
      
      WBuffer.AppendOA( OA( SIZE( TRAIL_NOTIFY )-2, ADR( TRAIL_NOTIFY ))); WBuffer.AppendByte( TRAIL );
      
      IF WBuffer.Length > 9 * WBuffer.Size DIV 10 THEN // send block and create new one
         // like in StopAndSendBatch
         WBuffer.AppendOA( OA( SIZE( TRAIL_XMLSOCKET )-2, ADR( TRAIL_XMLSOCKET ))); WBuffer.AppendByte( TRAIL );
         WBuffer.AppendByte( 13 ); WBuffer.AppendByte( 10 ); WBuffer.AppendByte( 0 ); // XMLSocket requires trailing zero
         Server^.Send( ADR( SELF ), WBuffer );

         // like in StartBatch
         WBuffer.Clear();
         WBuffer.AppendOA( OA( SIZE( LEAD_XMLSOCKET )-2, ADR( LEAD_XMLSOCKET ))); WBuffer.AppendByte( TRAIL );
      END;
   END AddItem;

(*--------------------------------------------------------------------------------*)

   PUBLIC PROCEDURE StopAndSendBatch();
   BEGIN
      WBuffer.AppendOA( OA( SIZE( TRAIL_XMLSOCKET )-2, ADR( TRAIL_XMLSOCKET ))); WBuffer.AppendByte( TRAIL );
      WBuffer.AppendByte( 13 ); WBuffer.AppendByte( 10 ); WBuffer.AppendByte( 0 ); // XMLSocket requires trailing zero

      Server^.Send( ADR( SELF ), WBuffer );
      
      BatchLock.Unlock();
   END StopAndSendBatch;

(*--------------------------------------------------------------------------------*)

BEGIN
   Server := NIL;
   Connection := NIL;
   RBuffer.Size := 16384; // maximal input XML size, if size is greater the data is discarded
   WBuffer.Size := 4096; // outputs are chunked by 4096 characters
END CClient;

(*================================================================================*)

END xmlsocket.