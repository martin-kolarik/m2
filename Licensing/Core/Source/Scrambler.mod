IMPLEMENTATION MODULE Scrambler;

(*================================================================================*)

IMPORT
	Strings;

(*--------------------------------------------------------------------------------*)

TYPE
	T5ToCh = ARRAY [0..31] OF WCHAR;
	TChTo5 = ARRAY [ORD(L'0')..ORD(L'Z')] OF CARD8;
CONST
	c5ToCh = T5ToCh(
		L'A', L'B', L'C', L'D', L'E', L'F', L'G', L'H', 
		L'2', L'3', L'4', L'5', L'6', L'7', L'8', L'9',
		L'R', L'S', L'T', L'U', L'W', L'X', L'Y', L'Z',
		L'I', L'J', L'K', L'L', L'M', L'N', L'O', L'P'
	);
	cChTo5 = TChTo5(
		30, 24,  8,  9, 10, 11, 12, 13, 14, 15, // numbers
		-1, -1, -1, -1, -1, -1, -1, // spare
		 0,  1,  2,  3,  4,  5,  6,  7, // A..H
		24, 25, 26, 27, 28, 29, 30, 31, // I..P
		30, 16, 17, 18, 19, 19, 20, 21, 22, 23 // Q, R..U,V..Z
	);

(*================================================================================*)

INLINE PROCEDURE ROTR8( x : CARD8; n : CARDINAL ) : CARD8;
BEGIN
	RETURN ( x >> n ) OR ( x << ( 8 - n ));
END ROTR8;

(*--------------------------------------------------------------------------------*)

INLINE PROCEDURE Rebit( srcbits, destbits : CARDINAL; CONST In : ARRAY OF BYTE; OUT Out : ARRAY OF BYTE; OUT Filled : CARDINAL );
VAR
	c : CARDINAL;
	last, mask : CARD8;
	di, dy, dl : CARDINAL := 0;
	si, sy, sl : CARDINAL := 0;
BEGIN
	sl := HIGH( In ) + 1;
	IF srcbits > destbits THEN
		dl := ( sl * srcbits + srcbits - 1 ) DIV destbits;
	ELSE
		dl := sl * srcbits DIV destbits;
	END;
	IF dl > HIGH( Out ) + 1 THEN
		Filled := 0;
		RETURN;
	END;
	Filled := dl;
	FOR c := 0 TO dl-1 DO
		Out[c] := 0;
	END;
	WHILE sy < sl DO
		c := MIN2( srcbits - si, destbits - di );
		IF si > di THEN
			Out[dy] := Out[dy] OR ( In[sy] >> ( si - di ));
		ELSE
			Out[dy] := Out[dy] OR ( In[sy] << ( di - si ));
		END;
		INC( si, c );
		IF si = srcbits THEN
			INC( sy );
			si := 0;
		END;
		INC( di, c );
		IF di = destbits THEN
			INC( dy );
			di := 0;
		END;
	END; // WHILE
	mask := 1 << destbits - 1;
	last := mask;
	FOR c := 0 TO dl-1 DO
		Out[c] := Out[c] AND mask;
		last := last XOR Out[c];
	END;
	IF sl < dl THEN // some bits are not filled
		Out[dy] := Out[dy] OR ( last << di ) AND mask;
	END;
END Rebit;

(*--------------------------------------------------------------------------------*)

INLINE PROCEDURE B2G( GroupWidth : CARDINAL; Separator : WCHAR; CONST In : ARRAY OF BYTE; Control : CARD8; OUT Out : ARRAY OF WCHAR );
VAR
	c : BITSET8;
	i, j : CARDINAL;
	v5ToCh : T5ToCh := c5ToCh;
BEGIN
   i := ( HIGH( In ) + 1 ) DIV GroupWidth + 1;
	IF HIGH( Out ) < i * GroupWidth + i - 1 THEN
		Out[0] := 0W;
		RETURN;
	END;
	j := 0;
	FOR i := 0 TO HIGH( In ) DO
		IF ( Separator <> 0W ) AND ( i > 0 ) AND ( i MOD GroupWidth = 0 ) THEN
			Out[j] := Separator;
			INC( j );
		END;
		c := BITSET8( ROTR8( Control, i ));
		IF 0 IN c THEN
			v5ToCh[19] := L'U';
		ELSE
			v5ToCh[19] := L'V';
		END;
		IF 1 IN c THEN
			v5ToCh[24] := L'I';
		ELSE
			v5ToCh[24] := L'1';
		END;
		IF 2 IN c THEN
			v5ToCh[30] := L'O';
		ELSIF 3 IN c THEN
			v5ToCh[30] := L'Q';
		ELSE
			v5ToCh[30] := L'0';
		END;
		Out[j] := v5ToCh[ In[i] ];
		INC( j );
	END; // FOR
	FOR i := 0 TO GroupWidth - 1 - HIGH( In ) MOD GroupWidth - 1 DO
		Out[j] := L'X';
		INC( j );
	END;
	IF j < HIGH( Out ) THEN
		Out[j] := 0W;
	END;
END B2G;

(*--------------------------------------------------------------------------------*)

INLINE PROCEDURE G2B( GroupWidth : CARDINAL; Separator : WCHAR; CONST In : ARRAY OF WCHAR; OUT Out : ARRAY OF BYTE; OUT Filled : CARDINAL ) : BOOLEAN;
VAR
	h, i, j, s : CARDINAL;
BEGIN
	Filled := 0;
	h := LENGTH( In ) - 1;
	IF HIGH( Out ) < h THEN
		RETURN FALSE;
	END;
	j := 0;
	s := GroupWidth;
	FOR i := 0 TO h DO
		CASE In[i] OF
		| '0'..'9' : Out[j] := cChTo5[ ORD( In[i] ) ]; INC( j );
		| 'a'..'z' : Out[j] := cChTo5[ ORD( In[i] ) - ORD( L'a' ) + ORD( L'A' ) ]; INC( j );
		| 'A'..'Z' : Out[j] := cChTo5[ ORD( In[i] ) ]; INC( j );
		ELSE
		   IF i <> s THEN
		      RETURN FALSE;
			ELSIF In[i] <> Separator THEN
				RETURN FALSE;
			ELSIF ( j = 0 ) OR ( j MOD GroupWidth > 0 ) THEN
				RETURN FALSE;
			END; // here proper positioned separator is detected
			INC( s, GroupWidth+1 );
		END;
	END; // FOR
	IF j % GroupWidth > 0 THEN
	   RETURN FALSE;
	END;
	Filled := j;
	RETURN TRUE;
END G2B;

(*================================================================================*)

PROCEDURE Scramble( CONST In : ARRAY OF BYTE; CONST Prefix : ARRAY OF WCHAR; Separator : WCHAR; OUT Out : ARRAY OF WCHAR ) : BOOLEAN;
VAR
	i, l : CARDINAL;
	wb : ARRAY [0..255] OF BYTE;
	ws : ARRAY [0..255] OF WCHAR;
BEGIN
	IF HIGH( In ) > 139 THEN
		RETURN FALSE;
	END;
	Rebit( 8, 5, In, OUT wb, OUT l );
	IF l < 5 THEN
	   RETURN FALSE;
	END;

	// mask and apply last uncomplete byte to checksum
	FOR i := 0 TO 2 DO
     wb[i] := wb[i] XOR wb[l-1];
   END;
	FOR i := 3 TO l-2 DO
	   wb[l-1] := wb[l-1] XOR wb[i];
	END;

	IF l > HIGH( Out )+1 THEN
		RETURN FALSE;
	ELSIF Separator = 0W THEN
		// fall down, space is sufficient
	ELSIF l + l DIV 5 > HIGH( Out )+1 THEN
		RETURN FALSE;
	END;
	B2G( 5, Separator, OA( l-1, ADR( wb )), In[0], OUT ws );
	Strings.ConcatW( OUT Out, Prefix, Separator );
	Strings.AppendW( REF Out, ws );
	RETURN TRUE;
END Scramble;

(*--------------------------------------------------------------------------------*)

PROCEDURE Unscramble( CONST In : ARRAY OF WCHAR; Separator : WCHAR; OUT Prefix : ARRAY OF WCHAR; OUT Out : ARRAY OF BYTE; OUT Filled : CARDINAL ) : BOOLEAN;
VAR
	i, l : CARDINAL;
	wb : ARRAY [0..255] OF BYTE;
	ws : ARRAY [0..255] OF WCHAR;
	wp : ARRAY [0..31] OF WCHAR;
BEGIN
	wp[0] := 0W;
	IF Separator = 0W THEN
		l := 0; // no prefix is detectable
	ELSE
		l := Strings.IndexOfCharW( In, Separator, 0 );
		IF l <> -1 THEN
			Strings.SubstringW( In, 0, l, OUT wp );
		END;
	END;
	Strings.SubstringW( In, l+1, -1, OUT ws );
	l := LENGTH( ws );
	IF ( l < 5 ) OR ( l > 250 ) THEN
		Filled := 0;
		RETURN FALSE;
	ELSIF NOT G2B( 5, Separator, ws, OUT wb, OUT l ) THEN
		Filled := 0;
		RETURN FALSE;
	END;

	// unmask and unapply last uncomplete byte to checksum
	FOR i := 3 TO l-2 DO
	   wb[l-1] := wb[l-1] XOR wb[i];
	END;
	FOR i := 0 TO 2 DO
     wb[i] := wb[i] XOR wb[l-1];
   END;
	
	Rebit( 5, 8, OA( l-1, ADR( wb )), OUT Out, OUT Filled );
	Prefix := wp;
	RETURN TRUE;
END Unscramble;

(*================================================================================*)

END Scrambler.