IMPLEMENTATION MODULE xmlsocket;

(*================================================================================*)

IMPORT
   netsocket,
   netsrv,
   Strings;

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

   VIRTUAL PROCEDURE OnReceive( Connection : netconndispatch.TConnectionHandle; Data : ADDRESS; DataLen : CARDINAL );
   VAR
      appendLength, i : INTEGER;
   BEGIN
      appendLength := MIN2( DataLen, _RBuffer.Size - _RBuffer.Length ); // do not oversize buffer
      _RBuffer.AppendOA( OA( appendLength-1, Data ));
      IF _RBuffer.Length < SIZE( LEAD_XMLSOCKET ) THEN
         RETURN; // still not enough data
      END;

      LOOP // parse all input XMLs in buffer
         i := _RBuffer.IndexOfOA( LEAD_XMLSOCKET, 0 );
         IF i = -1 THEN // remove everything except LEADING-1 bytes, which could contain new leading string
            _RBuffer.RemoveStart( MAX2( 0, INTEGER( _RBuffer.Length ) - SIZE( LEAD_XMLSOCKET ) + 1 ));
            RETURN; // wait more
         END;
         
         // look for trailing
         i := _RBuffer.IndexOfOA( TRAIL_XMLSOCKET, i );
         IF i <> -1 THEN // have trailing
            // fall down
         ELSIF _RBuffer.Size - _RBuffer.Length < SIZE( TRAIL_XMLSOCKET ) THEN // not enough space to store whole XML (LEADING...TRAILING), XML is too big, throw everything
            _RBuffer.RemoveStart( _RBuffer.Length );
            RETURN;
         ELSE // OK, leave buffer, wait for more
            RETURN;
         END;
         
         Parse( Connection, OA( i - SIZE( LEAD_XMLSOCKET ) - 1, PCHAR( _RBuffer.Data@[SIZE( LEAD_XMLSOCKET )] ) )); // slice data inside LEADING and TRAILING
         
         _RBuffer.RemoveStart( i + SIZE( TRAIL_XMLSOCKET ));      
      END; // LOOP
   END OnReceive;

(*--------------------------------------------------------------------------------*)

   PRIVATE PROCEDURE Parse( Connection : netconndispatch.TConnectionHandle; Data : ARRAY OF CHAR );
   VAR
      high : INTEGER;
      i, j, current : INTEGER;
      Name, Value : ARRAY [0..511] OF WCHAR;
      pos : INTEGER := 0;
   BEGIN
      LOOP
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
         current := i + SIZE( LEAD_ITEM );
         pos := j + SIZE( TRAIL_ITEM );

         i := Strings.IndexOfA( OA( high, ADR( Data[pos] )), LEAD_NAME, current );
         IF ( i = -1 ) OR ( i >= pos ) THEN
            CONTINUE; // the item is empty
         END;
         j := Strings.IndexOfA( OA( high, ADR( Data[pos] )), TRAIL_NAME, i );
         IF j >= pos THEN
            CONTINUE; // something bad
         END;
         INC( i, SIZE( LEAD_NAME ));
         Strings.ToW( OA( j-i, ADR( Data[i] )), 0, OUT Name );
         
         i := Strings.IndexOfA( OA( high, ADR( Data[pos] )), LEAD_VALUE, current );
         IF i >= pos THEN
            CONTINUE; // the item is empty
         END;
         j := Strings.IndexOfA( OA( high, ADR( Data[pos] )), TRAIL_VALUE, i );
         IF ( i = -1 ) OR ( j >= pos ) THEN
            CONTINUE; // something bad
         END;
         INC( i, SIZE( LEAD_VALUE ));
         Strings.ToW( OA( j-i, ADR( Data[i] )), 0, OUT Value );

         // correct strings
         i := Strings.IndexOfCharW( Name, L">", 0 );
         j := Strings.IndexOfCharW( Name, L"<", i );
         IF ( i = -1 ) OR ( j = -1 ) THEN // bad XML
            CONTINUE;
         END;
         Strings.RemoveW( REF Name, 0, i );
         Name[j] := 0W;
         Strings.TrimW( REF Name );
         
         i := Strings.IndexOfCharW( Value, L">", 0 );
         j := Strings.IndexOfCharW( Value, L"<", i );
         IF ( i = -1 ) OR ( j = -1 ) THEN // bad XML
            CONTINUE;
         END;
         Strings.RemoveW( REF Value, 0, i );
         Name[j] := 0W;
         Strings.TrimW( REF Value );
         
         // call back on name and value
         
      END;
   END Parse;
  
(*--------------------------------------------------------------------------------*)

BEGIN
   _RBuffer.Size := 16384; // maximal input XML size, if size is greater the data is discarded
   _WBuffer.Size := 16384;
END CXMLSocketServer;

(*================================================================================*)

END xmlsocket.