IMPLEMENTATION MODULE cphcommon;

(*================================================================================*)

PROCEDURE FromHexByteW( CONST String : ARRAY OF WCHAR; OUT Bin : BYTE  ) : BOOLEAN; // expects event number of characters in String
VAR
   ch : WCHAR;
	lo, hi : CARD8;
BEGIN
   IF HIGH( String ) < 1 THEN
      RETURN FALSE;
   END;
   ch := String[0];
	CASE ch OF
	| L'0'..L'9' : hi := CARD8( ch ) - CARD8( L'0' );
	| L'a'..L'f' : hi := CARD8( ch ) - CARD8( L'a' ) + 10;
	| L'A'..L'F' : hi := CARD8( ch ) - CARD8( L'A' ) + 10;
	ELSE
	   RETURN FALSE;
	END; // CASE
   ch := String[1];
	CASE ch OF
	| L'0'..L'9' : lo := CARD8( ch ) - CARD8( L'0' );
	| L'a'..L'f' : lo := CARD8( ch ) - CARD8( L'a' ) + 10;
	| L'A'..L'F' : lo := CARD8( ch ) - CARD8( L'A' ) + 10;
	ELSE
	   RETURN FALSE;
	END; // CASE
	Bin := hi << 4 OR lo;
	RETURN TRUE;
END FromHexByteW;

(*--------------------------------------------------------------------------------*)

PROCEDURE FromHexByteA( CONST String : ARRAY OF CHAR; OUT Bin : BYTE  ) : BOOLEAN; // expects event number of characters in String
VAR
   ch : CHAR;
	lo, hi : CARD8;
BEGIN
   IF HIGH( String ) < 1 THEN
      RETURN FALSE;
   END;
   ch := String[0];
	CASE ch OF
	| C'0'..C'9' : hi := CARD8( ch ) - CARD8( C'0' );
	| C'a'..C'f' : hi := CARD8( ch ) - CARD8( C'a' ) + 10;
	| C'A'..C'F' : hi := CARD8( ch ) - CARD8( C'A' ) + 10;
	ELSE
	   RETURN FALSE;
	END; // CASE
   ch := String[1];
	CASE ch OF
	| C'0'..C'9' : lo := CARD8( ch ) - CARD8( C'0' );
	| C'a'..C'f' : lo := CARD8( ch ) - CARD8( C'a' ) + 10;
	| C'A'..C'F' : lo := CARD8( ch ) - CARD8( C'A' ) + 10;
	ELSE
	   RETURN FALSE;
	END; // CASE
	Bin := hi << 4 OR lo;
	RETURN TRUE;
END FromHexByteA;

(*--------------------------------------------------------------------------------*)

PROCEDURE ToHexByte( Bin : BYTE; OUT String : ARRAY OF WCHAR );
VAR
	b : CARD8;
BEGIN
   IF HIGH( String ) < 0 THEN
      RETURN;
   ELSIF HIGH( String ) = 0 THEN
      String[0] := 0W;
      RETURN;
   END;
	b := Bin >> 4;
	IF b < 10 THEN
		String[0] := WCHAR( ORD( '0' ) + b );
	ELSE
		String[0] := WCHAR( ORD( 'a' ) + b - 10 );
	END;
	b := Bin AND 0FH;
	IF b < 10 THEN
		String[1] := WCHAR( ORD( '0' ) + b );
	ELSE
		String[1] := WCHAR( ORD( 'a' ) + b - 10 );
	END;
	IF HIGH( String ) > 1 THEN
		String[2] := 0W;
	END;
END ToHexByte;

(*--------------------------------------------------------------------------------*)

PROCEDURE FromHex( CONST String : ARRAY OF WCHAR; OUT Bin : ARRAY OF BYTE; OUT Filled : CARDINAL ) : BOOLEAN; // expects even number of characters in String
VAR
	i, j, u : INTEGER;
	ch : WCHAR;
	lo, hi : CARD8;
BEGIN
   IF ( HIGH( String ) = -1 ) OR ( HIGH( Bin ) = -1 ) THEN
      Filled := 0;
      RETURN TRUE;
   END;
	u := MIN2( HIGH( String ) DIV 2, HIGH( Bin ));
	j := 0;
	FOR i := 0 TO u DO
		ch := String[j];
		CASE ch OF
		| L'0'..L'9' : hi := CARD8( ch ) - CARD8( L'0' );
		| L'a'..L'f' : hi := CARD8( ch ) - CARD8( L'a' ) + 10;
		| L'A'..L'F' : hi := CARD8( ch ) - CARD8( L'A' ) + 10;
		ELSE
		   RETURN FALSE;
		END; // CASE
		INC( j );
		ch := String[j];
		CASE ch OF
		| L'0'..L'9' : lo := CARD8( ch ) - CARD8( L'0' );
		| L'a'..L'f' : lo := CARD8( ch ) - CARD8( L'a' ) + 10;
		| L'A'..L'F' : lo := CARD8( ch ) - CARD8( L'A' ) + 10;
		ELSE
		   RETURN FALSE;
		END; // CASE
		INC( j );
		Bin[i] := hi << 4 OR lo;
	END; // WHILE
	Filled := u+1;
	RETURN TRUE;
END FromHex;

(*--------------------------------------------------------------------------------*)

PROCEDURE ToHex( CONST Bin : ARRAY OF BYTE; OUT String : ARRAY OF WCHAR );
VAR
	b : CARD8;
	i, j, u : CARDINAL;
BEGIN
   IF HIGH( String ) = -1 THEN
      RETURN;
   ELSIF HIGH( Bin ) = -1 THEN
      String[0] := 0W;
      RETURN;
   END;
	u := MIN2( HIGH( Bin ), HIGH( String ) DIV 2 );
	j := 0;
	FOR i := 0 TO u DO
		b := Bin[i] >> 4;
		IF b < 10 THEN
			String[j] := WCHAR( ORD( '0' ) + b );
		ELSE
			String[j] := WCHAR( ORD( 'a' ) + b - 10 );
		END;
		INC( j );
		b := Bin[i] AND 0FH;
		IF b < 10 THEN
			String[j] := WCHAR( ORD( '0' ) + b );
		ELSE
			String[j] := WCHAR( ORD( 'a' ) + b - 10 );
		END;
		INC( j );
	END; // FOR
	IF u < HIGH( String ) DIV 2 THEN
		String[(u+1)<<1] := 0W;
	END;
END ToHex;

(*================================================================================*)

PROCEDURE BASE64CharCount( SrcBytes : CARDINAL ) : CARDINAL;
BEGIN
   RETURN ( SrcBytes + 2 ) DIV 3 * 4;
END BASE64CharCount;

(*--------------------------------------------------------------------------------*)

PROCEDURE BASE64ByteCount( BASE64Chars : CARDINAL ) : CARDINAL; 
BEGIN
   RETURN BASE64Chars DIV 4 * 3;
END BASE64ByteCount;

(*--------------------------------------------------------------------------------*)

TYPE
   WCHARS = WCHAR[ WCHAR(0)..WCHAR(127) ];

CONST
   BASE64_CHARS = WCHARS{
      L"A", L"B", L"C", L"D", L"E", L"F", L"G", L"H", L"I", L"J", L"K", L"L", L"M", L"N", L"O", L"P", L"Q", L"R", L"S", L"T", L"U", L"V", L"W", L"X", L"Y", L"Z",
      L"a", L"b", L"c", L"d", L"e", L"f", L"g", L"h", L"i", L"j", L"k", L"l", L"m", L"n", L"o", L"p", L"q", L"r", L"s", L"t", L"u", L"v", L"w", L"x", L"y", L"z",
      L"0", L"1", L"2", L"3", L"4", L"5", L"6", L"7", L"8", L"9", L"+", L"/"
   };

TYPE
   Tibase64table = ARRAY [WCHAR(0)..WCHAR(255)] OF CARDINAL;

CONST
   ibase64table = Tibase64table(
      0,  0,  0,  0,  0,  0,  0,  0,  0,  0,  0,  0,  0,  0,  0,  0,
      0,  0,  0,  0,  0,  0,  0,  0,  0,  0,  0,  0,  0,  0,  0,  0,
      0,  0,  0,  0,  0,  0,  0,  0,  0,  0,  0, 62,  0,  0,  0, 63,
     52, 53, 54, 55, 56, 57, 58, 59, 60, 61,  0,  0,  0,  0,  0,  0,
      0,  0,  1,  2,  3,  4,  5,  6,  7,  8,  9, 10, 11, 12, 13, 14,
     15, 16, 17, 18, 19, 20, 21, 22, 23, 24, 25,  0,  0,  0,  0,  0,
      0, 26, 27, 28, 29, 30, 31, 32, 33, 34, 35, 36, 37, 38, 39, 40,
     41, 42, 43, 44, 45, 46, 47, 48, 49, 50, 51,  0,  0,  0,  0,  0,
     0 BY 128 );

PROCEDURE FromBASE64( CONST In : ARRAY OF WCHAR; OUT Out : ARRAY OF BYTE; OUT Filled : CARDINAL ) : BOOLEAN;
VAR
   i, ie : PWCHAR;
   len : CARDINAL;
   o, oe : PBYTE;
   u : CARDINAL;
   u1 : PBYTE := PBYTE( ADR( u )@[1] );
   u2 : PBYTE := PBYTE( ADR( u )@[2] );
BEGIN
   Filled := 0;
   len := LENGTH( In );
   IF len = 0 THEN
      RETURN TRUE;
   ELSIF len AND 3 <> 0 THEN
      RETURN FALSE;
   END;

	i := PWCHAR( ADR( In ));
	ie := INC( i, len * SIZE( WCHAR ));
   o := ADR( Out );
   oe := INC( o, HIGH( Out )+1 );

	WHILE ( i <> ie ) AND ( o <> oe ) DO
	   IF i^ > WCHAR( 255 ) THEN
   	   INC( i, 2 );
	      CONTINUE;
	   ELSIF i^ NOT IN BASE64_CHARS THEN
   	   INC( i, 2 );
	      CONTINUE;
	   END;

      // first six bits
	   u :=        ibase64table[i^] << 18;
	   INC( i, 2 );
      // second six bits
	   u := u OR ( ibase64table[i^] << 12 );
	   INC( i, 2 );
	   IF i^ = L"=" THEN // stop char
   	   o^ := u2^; // safe
	      INC( o );
	      EXIT;
	   END;
      // third six bits
	   u := u OR ( ibase64table[i^] << 06 );
	   INC( i, 2 );
	   IF i^ = L"=" THEN // stop char
   	   o^ := u2^; // safe
	      INC( o );
	      IF o = oe THEN 
	         EXIT;
	      END;
   	   o^ := u1^;
	      INC( o );
	      EXIT;
	   END;
      // fourth six bits
	   u := u OR   ibase64table[i^];
	   INC( i, 2 );

	   o^ := u2^; // safe
	   INC( o );
      IF o = oe THEN 
         EXIT;
      END;
	   o^ := u1^;
	   INC( o );
      IF o = oe THEN 
         EXIT;
      END;
	   o^ := BYTE( u );
	   INC( o );
	END; // WHILE
	
   Filled := CARDINAL( LOPTRLONGWORD( o - ADR( Out )));
   RETURN TRUE;
END FromBASE64;

(*--------------------------------------------------------------------------------*)

CONST
   base64Table = L"ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/";

PROCEDURE ToBASE64( CONST In : ARRAY OF BYTE; OUT Out : ARRAY OF WCHAR ) : BOOLEAN;
VAR
   i, il : PCARD8;
   o : PWCHAR;
   u : CARDINAL;
   x : CARD8;
BEGIN
   u := BASE64CharCount( HIGH( In ) + 1 );
   IF u > HIGH( Out )+1 THEN
      RETURN FALSE;
      // u := BASE64BytesCount( HIGH( Out ) + 1 );
   ELSE
      u := HIGH( In )+1;
   END;
   
   o := ADR( Out );
   i := PCARD8( ADR( In ));
   il := INC( i, u );
   LOOP
      IF i = il THEN
         EXIT;
      END;
      x := i^ >> 2;
      o^ := base64Table[x];
      INC( o, 2 );

      x := ( i^ AND 03H ) << 4;
      INC( i );
      IF i = il THEN
         o^ := base64Table[x];
         INC( o, 2 );
         EXIT;
      ELSE
         x := x OR ( i^ >> 4 );
         o^ := base64Table[x];
         INC( o, 2 );
      END;

      x := ( i^ AND 0FH ) << 2;
      INC( i );
      IF i = il THEN
         o^ := base64Table[x];
         INC( o, 2 );
         EXIT;
      ELSE
         x := x OR ( i^ >> 6 );
         o^ := base64Table[x];
         INC( o, 2 );
      END;

      x := i^ AND 03FH;
      INC( i );
      o^ := base64Table[x];
      INC( o, 2 );
   END; // WHILE

   CASE u MOD 3 OF
   | 2 : // ends with 16 bits
      o^ := L"=";
      INC( o, 2 );
   | 1 : // ends with 8 bits
      o^ := L"=";
      INC( o, 2 );
      o^ := L"=";
      INC( o, 2 );
   END;

   u := CARDINAL( LOPTRLONGWORD( o - ADR( Out )));
   IF u > HIGH( Out ) THEN
      RETURN TRUE;
   END;
   o^ := 0W;
   
   RETURN TRUE;
END ToBASE64;

(*================================================================================*)

PROCEDURE Salt( CONST salt, data : ARRAY OF BYTE; OUT salted : ARRAY OF BYTE; OUT saltedCount : CARDINAL ); // max salt bytes from data are salted
VAR
   i, l : INTEGER;
BEGIN
   IF ( ADR( salt ) = NIL ) OR ( ADR( data ) = NIL ) OR ( ADR( salted ) = NIL ) THEN
      saltedCount := 0;
      RETURN;
   END;
   l := MIN2( MIN2( HIGH( salt ), HIGH( salted )), HIGH( data )) + 1;
   FOR i := 0 TO l-1 DO
      salted[i] := data[i] XOR salt[i];
   END; // FOR
   saltedCount := l;
END Salt;

(*================================================================================*)

END cphcommon.

