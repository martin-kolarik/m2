MODULE busmon;

(*================================================================================*)

FROM Storage IMPORT
   ALLOCATE, DEALLOCATE;

IMPORT
   eib_def,
   eibnet,
   inetaddr,
   lists,
   Resources,
   scinit,
   StringsO,
   Sync,
   Texts,
   TextWriter;
   
(*================================================================================*)

CLASS CBusmonConnection( eibnet.CConnection );

   // CConnection
   INTERNAL VIRTUAL PROCEDURE OnConnect();
   INTERNAL VIRTUAL PROCEDURE OnDisconnect();
   INTERNAL VIRTUAL PROCEDURE On_L_IND_cEMI( CONST packet : eib_def.cEMIPacket );
   INTERNAL VIRTUAL PROCEDURE On_L_IND( CONST packet : eib_def.TPacket );

   // SELF
   PRIVATE PROCEDURE BytesToString( data : ARRAY OF BYTE; OUT s : StringsO.CString );

END CBusmonConnection;

(*--------------------------------------------------------------------------------*)

CLASS IMPLEMENTATION CBusmonConnection;

(*--------------------------------------------------------------------------------*)

   INTERNAL VIRTUAL PROCEDURE OnConnect();
   BEGIN
      TextWriter.errout()^.WriteOA( L"Connected", TRUE );
   END OnConnect;

(*--------------------------------------------------------------------------------*)

   INTERNAL VIRTUAL PROCEDURE OnDisconnect();
   BEGIN
      TextWriter.errout()^.WriteOA( L"Disconnected", TRUE );
   END OnDisconnect;

(*--------------------------------------------------------------------------------*)

   INTERNAL VIRTUAL PROCEDURE On_L_IND_cEMI( CONST packet : eib_def.cEMIPacket );
   VAR
      s : StringsO.CString;
   BEGIN
      BytesToString( OA( packet.Length-1, ADR( packet )), OUT s );
      TextWriter.errout()^.Write( s, TRUE );
   END On_L_IND_cEMI;

(*--------------------------------------------------------------------------------*)

   INTERNAL VIRTUAL PROCEDURE On_L_IND( CONST packet : eib_def.TPacket );
   VAR
      s : StringsO.CString;
   BEGIN
      BytesToString( OA( packet.Length-1, ADR( packet )), OUT s );
      TextWriter.errout()^.Write( s, TRUE );
   END On_L_IND;

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

END CBusmonConnection;

(*================================================================================*)

VAR
   R : Resources.CResources;

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
   Busmon : CBusmonConnection;  
   errout : TextWriter.TPTextWriter := TextWriter.errout();
   i : INTEGER;
   ia : inetaddr.INETADDR;
BEGIN
   R.LoadRES2( EMIT( %exe ), L"busmon.Texts" );

   i := 1;
   WHILE i < argc DO
      IF ( argp^[i]^[0] = L'/' ) OR ( argp^[i]^[0] = L'-' ) THEN // option
         CASE argp^[i]^[1] OF
         | 'h' :
            GOTO Error;
         ELSE
            errout^.WriteOA( OAsz( R[Texts._InvalidOption] ), FALSE ); errout^.WriteOA( argp^[i]^, TRUE );
            GOTO Error;
         END;
      END;
      INC( i );
   END; // WHILE

   ia.SetAddressOA( L"10.0.0.7:3671", 0 );

   Busmon.Mode := eibnet.cmTunnelingHPAI;
   Busmon.TunnelingMode := eibnet.tmEMI;
   Busmon.RemoteAddress := ia;
   
   Busmon.Connect( 0 );

   errout^.WriteOA( OAsz( R[Texts._Searching] ), FALSE );
   WHILE TRUE DO
      Sync.Sleep( 250 );
   END; // WHILE
   
   Busmon.Disconnect( TRUE );
   
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
