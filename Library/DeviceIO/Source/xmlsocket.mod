IMPLEMENTATION MODULE xmlsocket;

(*================================================================================*)

IMPORT
   io,
   IOO,
   iovalue,
   Languages,
   LanguagesO,
   netsocket,
   netsrv,
   ns,
   StorageO,
   Strings,
   StringsO,
   Sync;

(*================================================================================*)

TYPE
   TPClient = POINTER TO CClient;

CLASS CClient IMPLEMENTS io.IAdviseInfo;
   LOCAL VAR
      Server : TPXMLSocketServer;
      Connection : netconndispatch.TConnectionHandle;
      RBuffer : StorageO.CMemoryBuffer;
      WBuffer : StorageO.CMemoryBuffer;

   // IAdviseInfo
   PUBLIC VIRTUAL PROCEDURE OnAdvise( Source : io.TPIO; CONST Result : ARRAY OF Sync.TAsyncResult; CONST Item : ARRAY OF ns.THash; CONST Value : ARRAY OF iovalue.Value );

END CClient;

(*================================================================================*)

CONST
  LEAD_XMLSOCKET = C'<xmlsocket';
  TRAIL_XMLSOCKET = C'</xmlsocket';
  LEAD_ITEM = C'<item';
  TRAIL_ITEM = C'</item';
  LEAD_NAME = C'<name';
  TRAIL_NAME = C'</name';
  LEAD_VALUE = C'<value';
  TRAIL_VALUE = C'</value';

(*================================================================================*)

CLASS IMPLEMENTATION CXMLSocketServer;

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

   PUBLIC PROPERTY Logger GET : log.TPLogger;
   BEGIN
      RETURN _Logger;
   END Logger;

(*--------------------------------------------------------------------------------*)

   PUBLIC PROPERTY Logger SET( Value : log.TPLogger );
   BEGIN
      _Logger := Value;
   END Logger;

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

   PUBLIC PROPERTY Running GET : BOOLEAN;
   BEGIN
      RETURN _Running;
   END Running;

(*--------------------------------------------------------------------------------*)

   PUBLIC PROCEDURE Start();
   BEGIN
      IF _Running THEN
         RETURN;
      ELSE
         _Running := TRUE;
      END;
      netsrv.StartListen( netsocket.stStream, _ListenAddress, NIL, Listener, 0, NIL );
   END Start;

(*--------------------------------------------------------------------------------*)

   PUBLIC PROCEDURE Stop();
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
      Client : TPClient;
      sd : ARRAY [0..63] OF WCHAR;
   BEGIN
      Connection^.RemoteAddress.GetAddressOA( TRUE, OUT sd );
      Logger^.LogSS( log.dldDebug, L"xmls", "CONNECT: ", sd );

      ASSERT( NOT _Clients.Contains( Connection ));
      
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
      Client : TPClient;
      sd : ARRAY [0..63] OF WCHAR;
   BEGIN
      Connection^.RemoteAddress.GetAddressOA( TRUE, OUT sd );
      Logger^.LogSS( log.dldDebug, L"xmls", "DISCONNECT: ", sd );

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
      Logger^.LogSS( log.dldDebug, L"xmls", "RCV: ", sd );
      Logger^.LogSC( log.dldDebug, L"xmls", "  length: ", DataLen );

      IF NOT _Clients.Get( Connection, OUT Client ) THEN
         Logger^.LogS( log.dldDebug, L"xmls", "  to: unknown connection" );
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
         
         Parse( OA( i - SIZE( LEAD_XMLSOCKET )-1, PCHAR( Client^.RBuffer.Data@[SIZE( LEAD_XMLSOCKET )-1] ) )); // slice data inside LEADING and TRAILING
         
         Client^.RBuffer.RemoveStart( i + SIZE( TRAIL_XMLSOCKET )-1 );
      END; // LOOP
   END OnReceive;

(*--------------------------------------------------------------------------------*)

   PRIVATE PROCEDURE Parse( Data : ARRAY OF CHAR );
   VAR
      high : INTEGER;
      i, j, current : INTEGER;
      Name, Value : ARRAY [0..511] OF WCHAR;
      pos, nextpos : INTEGER := 0;
   BEGIN
      LOOP

         pos := nextpos;
         high := HIGH( Data ) - pos;
         IF high < 0 THEN
            EXIT; // done
         END;

         i := Strings.IndexOfA( OA( high, ADR( Data[pos] )), LEAD_ITEM, pos );
         IF i = -1 THEN
            EXIT; // done
         END;
         j := Strings.IndexOfA( OA( high, ADR( Data[pos] )), TRAIL_ITEM, i );
         IF j = -1 THEN
            EXIT; // done
         END;
         current := i + SIZE( LEAD_ITEM )-1;
         nextpos := j + SIZE( TRAIL_ITEM )-1;

         // get NAME
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
         
         // get VALUE
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

         // correct strings
         i := Strings.IndexOfCharW( Name, L">", 0 );
         j := Strings.IndexOfCharW( Name, L"<", i );
         IF ( i = -1 ) OR ( j = -1 ) THEN // bad XML
            CONTINUE;
         END;
         Name[j] := 0W;
         Strings.RemoveW( REF Name, 0, i+1 );
         Strings.TrimW( REF Name );
         
         i := Strings.IndexOfCharW( Value, L">", 0 );
         j := Strings.IndexOfCharW( Value, L"<", i );
         IF ( i = -1 ) OR ( j = -1 ) THEN // bad XML
            CONTINUE;
         END;
         Value[j] := 0W;
         Strings.RemoveW( REF Value, 0, i+1 );
         Strings.TrimW( REF Value );
         
         // call back on name and value
         HandleItem( Name, Value );
         
      END;
   END Parse;
  
(*--------------------------------------------------------------------------------*)

   PRIVATE PROCEDURE HandleItem( CONST NameOA, Value : ARRAY OF WCHAR );
   VAR
      Hash : ns.THash;
      io : iovalue.Value;
      Name : StringsO.CString;
   BEGIN
      Name.FromOA( NameOA );
      Logger^.LogSSSS( log.dldTrace, L"xmls", "SET ", NameOA, L" ", Value );

      IF NOT Device^.IO()^.Running THEN
         Logger^.LogS( log.dldDebug, L"xmls", "  device is not running, nothing SET" );
         RETURN;

      ELSIF NOT Device^.Mapper()^.NameToHash( Name, OUT Hash ) THEN
         Logger^.LogSS( log.dldTrace, L"xmls", "  unknown name, nothing SET: ", NameOA );
         RETURN;

      ELSE
         io.FromStringOA( Value, FALSE );
         Device^.IO()^.IOh( IOO.dirWrite, Hash, REF io, NIL );
      END;         
   END HandleItem;

(*--------------------------------------------------------------------------------*)

   LOCAL PROCEDURE Send( Client : ADDRESS; CONST Buffer : StorageO.AMemoryBuffer );
   BEGIN         
      SUPER.Send( NIL, TPClient( Client )^.Connection, 0, Buffer.Data, Buffer.Length );
   END Send;

(*--------------------------------------------------------------------------------*)

BEGIN
   Logger := log.logger();
END CXMLSocketServer;

(*================================================================================*)

CLASS IMPLEMENTATION CClient;

(*--------------------------------------------------------------------------------*)

   PUBLIC VIRTUAL PROCEDURE OnAdvise( Source : io.TPIO; CONST Result : ARRAY OF Sync.TAsyncResult; CONST Item : ARRAY OF ns.THash; CONST Value : ARRAY OF iovalue.Value );
   CONST
      TCL = C'>';
   VAR
      i : INTEGER;
      S : StringsO.CString;
   BEGIN
      // INIT..
      WBuffer.Clear();
      WBuffer.AppendOA( OA( SIZE( LEAD_XMLSOCKET )-2, ADR( LEAD_XMLSOCKET ))); WBuffer.AppendByte( TCL );
      // ..INIT
   
      FOR i := 0 TO HIGH( Item ) DO
         IF Result[i] IN Sync.arsCompletions THEN
            WBuffer.AppendOA( OA( SIZE( LEAD_ITEM )-2, ADR( LEAD_ITEM ))); WBuffer.AppendByte( TCL );

            WBuffer.AppendOA( OA( SIZE( LEAD_NAME )-2, ADR( LEAD_NAME ))); WBuffer.AppendByte( TCL );
            Server^.Device^.Mapper()^.HashToName( Item[i], OUT S );
            LanguagesO.ToMB( S, Languages.cp_UTF8, TRUE, REF WBuffer );
            WBuffer.AppendOA( OA( SIZE( TRAIL_NAME )-2, ADR( TRAIL_NAME ))); WBuffer.AppendByte( TCL );
            
            WBuffer.AppendOA( OA( SIZE( LEAD_VALUE )-2, ADR( LEAD_VALUE ))); WBuffer.AppendByte( TCL );
            S := Value[i].String;
            LanguagesO.ToMB( S, Languages.cp_UTF8, TRUE, REF WBuffer );
            WBuffer.AppendOA( OA( SIZE( TRAIL_VALUE )-2, ADR( TRAIL_VALUE ))); WBuffer.AppendByte( TCL );
            
            WBuffer.AppendOA( OA( SIZE( TRAIL_ITEM )-2, ADR( TRAIL_ITEM ))); WBuffer.AppendByte( TCL );
            
            IF WBuffer.Length > 9 * WBuffer.Size DIV 10 THEN // send block and create new one
               // SEND..
               WBuffer.AppendOA( OA( SIZE( TRAIL_XMLSOCKET )-2, ADR( TRAIL_XMLSOCKET ))); WBuffer.AppendByte( TCL );
               WBuffer.AppendByte( 13 ); WBuffer.AppendByte( 10 );
               Server^.Send( ADR( SELF ), WBuffer );
               // ..SEND

               // INIT..
               WBuffer.Clear();
               WBuffer.AppendOA( OA( SIZE( LEAD_XMLSOCKET )-2, ADR( LEAD_XMLSOCKET ))); WBuffer.AppendByte( TCL );
               // ..INIT
            END;

         END;
      END; // FOR

      // SEND..
      WBuffer.AppendOA( OA( SIZE( TRAIL_XMLSOCKET )-2, ADR( TRAIL_XMLSOCKET ))); WBuffer.AppendByte( TCL );
      WBuffer.AppendByte( 13 ); WBuffer.AppendByte( 10 );
      Server^.Send( ADR( SELF ), WBuffer );
      // ..SEND
   END OnAdvise;

(*--------------------------------------------------------------------------------*)

BEGIN
   Server := NIL;
   Connection := NIL;
   RBuffer.Size := 16384; // maximal input XML size, if size is greater the data is discarded
   WBuffer.Size := 4096; // outputs are chunked by 4096 characters
END CClient;

(*================================================================================*)

END xmlsocket.