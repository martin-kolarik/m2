MODULE busmon;

(*================================================================================*)

FROM Storage IMPORT
   ALLOCATE, DEALLOCATE;

IMPORT
   eib_def,
   eibnet,
   FIOO,
   inetaddr,
   lists,
   Resources,
   scinit,
   StringsO,
   Sync,
   Texts,
   TextWriter;
   
(*================================================================================*)

VAR
   R : Resources.CResources;
   Verbose : BOOLEAN := FALSE;

(*================================================================================*)

CLASS CBusmonConnection( eibnet.CConnection );

   // CConnection
   INTERNAL VIRTUAL PROCEDURE OnConnect();
   INTERNAL VIRTUAL PROCEDURE OnConnectError( Result : Sync.TAsyncResult; Code : CARDINAL );
   INTERNAL VIRTUAL PROCEDURE OnDisconnect();
   INTERNAL VIRTUAL PROCEDURE On_L_IND_cEMI( CONST packet : eib_def.cEMIPacket );

   // SELF
   PRIVATE PROCEDURE BytesToString( data : ARRAY OF BYTE; OUT s : StringsO.CString );
   PRIVATE PROCEDURE DumpValue( data : ARRAY OF BYTE );

END CBusmonConnection;

(*--------------------------------------------------------------------------------*)

CLASS IMPLEMENTATION CBusmonConnection;

(*--------------------------------------------------------------------------------*)

   INTERNAL VIRTUAL PROCEDURE OnConnect();
   BEGIN
      Sync.Sleep( 500 );
      TextWriter.errout()^.WriteOA( OAsz( R[Texts._Connected] ), TRUE );
   END OnConnect;

(*--------------------------------------------------------------------------------*)

   INTERNAL VIRTUAL PROCEDURE OnConnectError( Result : Sync.TAsyncResult; Code : CARDINAL );
   BEGIN
      Sync.Sleep( 500 );
      IF Result = Sync.arTimeout THEN
         TextWriter.errout()^.WriteOA( OAsz( R[Texts._ConnectTimeout] ), TRUE );
      ELSE
         TextWriter.errout()^.WriteOA( OAsz( R[Texts._ConnectError] ), FALSE );
         TextWriter.errout()^.WriteINT32( Code, 10, FALSE );
         TextWriter.errout()^.WriteOA( OAsz( R[Texts._ConnectNextTrie] ), TRUE );
      END;
   END OnConnectError;

(*--------------------------------------------------------------------------------*)

   INTERNAL VIRTUAL PROCEDURE OnDisconnect();
   BEGIN
      TextWriter.errout()^.WriteOA( OAsz( R[Texts._Disconnected] ), TRUE );
   END OnDisconnect;

(*--------------------------------------------------------------------------------*)

   INTERNAL VIRTUAL PROCEDURE On_L_IND_cEMI( CONST packet : eib_def.cEMIPacket );
   VAR
      data : ARRAY [0..255] OF BYTE;
      emi : eib_def.EMIPacket;
      frameType : eib_def.TFrameType;
      i, len : CARDINAL;
      s : ARRAY [0..127] OF WCHAR;
      so : StringsO.CString;
   BEGIN
      IF Verbose THEN
         BytesToString( OA( packet.Length-1, ADR( packet )), OUT so );
         TextWriter.stdout()^.Write( so, TRUE );
      END;
      
      packet.ToEMI( OUT emi );

      frameType := packet.FrameType;
      CASE frameType OF
      | eib_def.ftStandard :
         TextWriter.stdout()^.WriteOA( L"STD ", FALSE );
      | eib_def.ftLTE :
         TextWriter.stdout()^.WriteOA( L"LTE ", FALSE );
      | eib_def.ftUser :
         TextWriter.stdout()^.WriteOA( L"USR ", FALSE );
      ELSE
         TextWriter.stdout()^.WriteOA( L"??? ", FALSE );
      END;
      
      CASE emi.GetPriority() OF
      | eib_def.priorityNormal :
         TextWriter.stdout()^.WriteOA( L"L ", FALSE );
      | eib_def.priorityHigh :
         TextWriter.stdout()^.WriteOA( L"N ", FALSE );
      | eib_def.priorityAlarm :
         TextWriter.stdout()^.WriteOA( L"U ", FALSE );
      | eib_def.prioritySystem :
         TextWriter.stdout()^.WriteOA( L"S ", FALSE );
      ELSE
         TextWriter.stdout()^.WriteOA( L"? ", FALSE );
      END;      
      
      IF packet.Long THEN
         TextWriter.stdout()^.WriteOA( L"L[", FALSE );
      ELSE
         TextWriter.stdout()^.WriteOA( L"S[", FALSE );
      END;
      TextWriter.stdout()^.WriteINT32( packet.Length, 10, FALSE );
      TextWriter.stdout()^.WriteOA( L",", FALSE );
      TextWriter.stdout()^.WriteINT32( packet.DataLength, 10, FALSE );
      TextWriter.stdout()^.WriteOA( L"] ", FALSE );
      
      emi.GetSourceAddress().GetPhysicalAddress3( s );
      TextWriter.stdout()^.WriteOA( s, FALSE );
      TextWriter.stdout()^.WriteOA( L" ", FALSE );
      
      packet.GetDestinationAddress( OUT s );
      TextWriter.stdout()^.WriteOA( s, FALSE );
      TextWriter.stdout()^.WriteOA( L" ", FALSE );
      
      CASE emi.GetValueDirection() OF // for LTE this is different
      | eib_def.directionRead :
         TextWriter.stdout()^.WriteOA( L"rd ", FALSE );
      | eib_def.directionResponse :
         TextWriter.stdout()^.WriteOA( L"rs ", FALSE );
      | eib_def.directionWrite :
         TextWriter.stdout()^.WriteOA( L"wr ", FALSE );
      END;

      packet.ToDataArray( data, len );
      CASE frameType OF
      //-----
      | eib_def.ftStandard :
         // dump data
         IF len > 0 THEN
            IF len = 1 THEN
               BytesToString( OA( 0, ADR( data )), OUT so );
               TextWriter.stdout()^.Write( so, FALSE );
            ELSE
               BytesToString( OA( len-2, ADR( data )), OUT so );
               TextWriter.stdout()^.Write( so, FALSE );
            END;

            DumpValue( OA( len-1, ADR( data )));
         END;

      //-----
      | eib_def.ftLTE :
         // interpret LTE addressing data
         IF len >= 4 THEN
            TextWriter.stdout()^.WriteOA( L"P[", FALSE );
            // object id
            i := CARDINAL( data[0] << 8 ) OR CARDINAL( data[1] );
            TextWriter.stdout()^.WriteINT32( i, 10, FALSE );
            TextWriter.stdout()^.WriteOA( L"/", FALSE );
            // interface id
            TextWriter.stdout()^.WriteINT32( CARDINAL( data[2] ), 10, FALSE );
            TextWriter.stdout()^.WriteOA( L"/", FALSE );
            // property id
            IF data[3] < 255 THEN // standard property
               TextWriter.stdout()^.WriteINT32( CARDINAL( data[3] ), 10, FALSE );
               TextWriter.stdout()^.WriteOA( L"] ", FALSE );
               
               i := 4; // prepare data index;
            ELSIF len >= 7 THEN // private property
               // company id
               TextWriter.stdout()^.WriteOA( L"C[", FALSE );
               i := CARDINAL( data[4] << 8 ) OR CARDINAL( data[5] );
               TextWriter.stdout()^.WriteINT32( i, 10, FALSE );
               TextWriter.stdout()^.WriteOA( L"]/", FALSE );
               // property id
               TextWriter.stdout()^.WriteINT32( CARDINAL( data[6] ), 10, FALSE );
               TextWriter.stdout()^.WriteOA( L"] ", FALSE );

               i := 7; // prepare data index;
            END;

            // dump data
            IF len > i THEN
               IF len-i-1 = 1 THEN
                  BytesToString( OA( 0, ADR( data[i] )), OUT so );
                  TextWriter.stdout()^.Write( so, FALSE );
               ELSE
                  BytesToString( OA( len-i-2, ADR( data[i] )), OUT so );
                  TextWriter.stdout()^.Write( so, FALSE );
               END;
               
               DumpValue( OA( len-i-1, ADR( data[i] )));
            END;
         END;

      END; // CASE
      
      TextWriter.stdout()^.LineEnd();
   END On_L_IND_cEMI;

(*--------------------------------------------------------------------------------*)

   PRIVATE PROCEDURE BytesToString( data : ARRAY OF BYTE; OUT s : StringsO.CString );
   VAR
      a : PCARD8 := PCARD8( ADR( data ));
      i : INTEGER := 0;
      l : INTEGER := HIGH( data ) + 1;
      c8 : CARD8;
   BEGIN
      IF ( l <= 0 ) OR ( ADR( data ) = NIL ) THEN
         s.Clear();
         RETURN;
      END;

      l := 3 * l; // space + two characters per byte
      s.Size := l;
      s.Length := l;

      WHILE i < l DO
         c8 := a^ >> 4;
         IF c8 < 10 THEN
            s[i] := WCHAR( 48 + c8 );
         ELSE
            s[i] := WCHAR( 65 + c8 - 10 );
         END;
         INC( i );

         c8 := a^ AND 0FH;
         IF c8 < 10 THEN
            s[i] := WCHAR( 48 + c8 );
         ELSE
            s[i] := WCHAR( 65 + c8 - 10 );
         END;
         INC( i );

         s[i] := L' ';
         INC( i );

         INC( a );
      END; // WHILE
   END BytesToString;

(*--------------------------------------------------------------------------------*)

   PRIVATE PROCEDURE DumpValue( data : ARRAY OF BYTE );
   VAR
      i : CARDINAL;
      len : INTEGER;
      packet : eib_def.TPacket;
      real : REAL := 0.0;
      up, down : BOOLEAN;
      value : eib_def.TValue;
      so : StringsO.CString;
   BEGIN
      len := HIGH( data ) + 1;
      IF len <= 0 THEN
         RETURN;
      END;
      packet.FromDataArray( data, len );

      TextWriter.stdout()^.WriteOA( L"(", FALSE );

      CASE len OF
      | 1 :
         value.SetType( eib_def.eitSwitch );
         packet.ToValue( OUT value );
         IF value.GetSwitch() THEN
            TextWriter.stdout()^.WriteOA( L"on|open|", FALSE );
         ELSE
            TextWriter.stdout()^.WriteOA( L"off|close|", FALSE );
         END;

         value.SetType( eib_def.eitIncrease );
         packet.ToValue( OUT value );
         so.FromCARD32( value.GetIncrease( up, down ), 10 );
         IF up THEN
            TextWriter.stdout()^.WriteOA( L"+", FALSE );
            TextWriter.stdout()^.Write( so, FALSE );
            TextWriter.stdout()^.WriteOA( L" %", FALSE ); 
         ELSIF down THEN
            TextWriter.stdout()^.WriteOA( L"-", FALSE );
            TextWriter.stdout()^.Write( so, FALSE );
            TextWriter.stdout()^.WriteOA( L" %", FALSE );
         ELSE
            TextWriter.stdout()^.WriteOA( L"dim stop", FALSE );
         END;
         
      | 2 :
         value.SetType( eib_def.eitScaling );
         packet.ToValue( OUT value );
         so.FromCARD32( value.GetScaling(), 10 );
         TextWriter.stdout()^.Write( so, FALSE );
         TextWriter.stdout()^.WriteOA( L" %|0x", FALSE ); 

         value.SetType( eib_def.eitScaling255 );
         packet.ToValue( OUT value );
         so.FromCARD32( value.GetScaling255(), 16 );
         TextWriter.stdout()^.Write( so, FALSE );
         
      | 3 :
         value.SetType( eib_def.eitValue );
         packet.ToValue( OUT value );
         so.FromLONGREALExt( LONGREAL( value.GetValue()), 5, -1, FALSE, L"." );
         TextWriter.stdout()^.Write( so, FALSE );
         
      | 5 :
         PCARD32( ADR( real ))^ := REVERSE( PCARD32( ADR( data ))^ );
         so.FromLONGREALExt( LONGREAL( real ), 5, -1, FALSE, L"." );
         TextWriter.stdout()^.Write( so, FALSE ); TextWriter.stdout()^.WriteOA( L"|", FALSE );

         so.FromCARD32( REVERSE( PCARD32( ADR( data ))^ ), 10 );
         TextWriter.stdout()^.Write( so, FALSE );
      END; // CASE
      
      TextWriter.stdout()^.WriteOA( L") ", FALSE );

   END DumpValue;

(*--------------------------------------------------------------------------------*)

END CBusmonConnection;

(*================================================================================*)

TYPE
   TParamStringArray  = ARRAY [0..0] OF POINTER TO ARRAY [0..511] OF WCHAR;
   TPParamStringArray = POINTER TO TParamStringArray;
  
# save, call( convention => cdecl )
PROCEDURE wmain( argc : INTEGER; argp : TPParamStringArray; enpv : TPParamStringArray ) : INTEGER;
# restore
LABEL
   Error, Stop;
VAR
   address : ARRAY[0..255] OF WCHAR;
   Busmon : CBusmonConnection;  
   ch : CHAR;
   errout : TextWriter.TPTextWriter := TextWriter.errout();
   i : INTEGER;
   ia : inetaddr.INETADDR;
BEGIN
   R.LoadRES2( EMIT( %exe ), L"busmon.Texts" );
   
   IF ( argc < 2 ) OR ( argp^[1]^[0] = L"-" ) THEN
      errout^.WriteOA( OAsz( R[Texts._MissingAddress] ), TRUE );
      errout^.LineEnd();
      GOTO Error;
   ELSE
      ASSIGN( address, argp^[1]^ );
   END;

   i := 2;
   WHILE i < argc DO
      IF ( argp^[i]^[0] = L'/' ) OR ( argp^[i]^[0] = L'-' ) THEN // option
         CASE argp^[i]^[1] OF
         | 'h' :
            GOTO Error;
         | 'v' :
            Verbose := TRUE;
         ELSE
            errout^.WriteOA( OAsz( R[Texts._InvalidOption] ), FALSE ); errout^.WriteOA( argp^[i]^, TRUE );
            GOTO Error;
         END;
      END;
      INC( i );
   END; // WHILE

   ia.SetAddressOA( address, 3671 );

   Busmon.Mode := eibnet.cmTunnelingHPAI;
   Busmon.TunnelingMode := eibnet.tmEMI;
   Busmon.RemoteAddress := ia;
   Busmon.AutoReconnectDelay := 10000;
   
   Busmon.Connect( 0 );

   errout^.WriteOA( OAsz( R[Texts._Connecting] ), TRUE );
   
   FIOO.stdin()^.ReadOA( REF ch, OUT i, Sync.FOREVER );
   
   Busmon.Disconnect( FALSE );
   Sync.Sleep( 100 );
   Busmon.Dispose();

   RETURN 0;

Error:
   errout^.WriteOA( OAsz( R[Texts._UsageInfo] ), TRUE );

Stop:
   RETURN -1;
END wmain;
  
(*================================================================================*)

BEGIN
   scinit.Startup();
FINALLY
   scinit.Cleanup();
END busmon.
