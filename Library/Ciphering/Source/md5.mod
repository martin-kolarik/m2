IMPLEMENTATION MODULE md5;

(*================================================================================*)

CLASS IMPLEMENTATION CDigest;

(*--------------------------------------------------------------------------------*)

	PUBLIC VIRTUAL PROPERTY digest GET : PBYTE;
	BEGIN
	   RETURN ADR( _digest );
	END digest;

(*--------------------------------------------------------------------------------*)

	PUBLIC VIRTUAL PROPERTY size GET : CARDINAL;
	BEGIN
	   RETURN SIZE( _digest );
	END size;

(*--------------------------------------------------------------------------------*)

BEGIN
	_digest[0] := 0;
END CDigest;

(*================================================================================*)

TYPE
	TPBuffer = POINTER TO TBuffer;
	TPDigestLW = POINTER TO ARRAY [0..7] OF CARD32;
	TPBufferLW = POINTER TO ARRAY [0..15] OF CARD32;
	
CONST
	md5_padding = TProcessBuffer(
		080H, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
		0,    0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
		0,    0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
		0,    0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0
	);

(*================================================================================*)

CLASS IMPLEMENTATION CMD5;
	
(*--------------------------------------------------------------------------------*)

   PUBLIC VIRTUAL PROCEDURE Init();
   BEGIN
      count[0] := 0;
      count[1] := 0;
      state[0] := 067452301H;
      state[1] := 0EFCDAB89H;
      state[2] := 098BADCFEH;
      state[3] := 010325476H;
   END Init;

(*--------------------------------------------------------------------------------*)

	PUBLIC VIRTUAL PROCEDURE Update( CONST input : ARRAY OF BYTE );
	VAR
		in : PCARD8 := PCARD8( ADR( input ));
		length : CARDINAL := HIGH( input ) + 1;
		left, fill : CARDINAL;
	BEGIN
		IF ( HIGH( input ) = -1 ) OR ( ADR( input ) = NIL ) THEN
			RETURN;
		END;
		left := count[0] AND 03FH;
		fill := 64 - left;

		INC( count[0], length );
		IF count[0] < length THEN
			INC( count[1] );
		END;

		IF ( left > 0 ) AND ( length >= fill ) THEN
			WHILE left < 64 DO
				inputbuffer[left] := in^;
				INC( left );
				INC( in );
			END; // WHILE
			DEC( length, fill );
			left := 0;
			md5_process( inputbuffer );
		END;

		WHILE length >= 64 DO
			md5_process( TPBuffer( in )^ );
			DEC( length, 64 );
			INC( in, 64 );
		END; // WHILE

		WHILE length > 0 DO
			inputbuffer[left] := in^;
			INC( left );
			INC( in );
			DEC( length );
		END;
	END Update;

(*--------------------------------------------------------------------------------*)

	PUBLIC VIRTUAL PROCEDURE Finish( OUT _digest : digest.ADigest );
	VAR
		i : CARDINAL;
		last, padn : CARDINAL;
		hi, lo : CARD32;
		msglen : ARRAY [0..1] OF CARD32;
		pdigest : TPDigestLW;
	BEGIN
		hi := ( count[0] >> 29 ) OR ( count[1] << 3 ); // count in bits
		lo := ( count[0] << 3 ); // count in bits
		msglen[0] := lo;
		msglen[1] := hi;

		last := count[0] AND 03FH;
		IF last < 56 THEN
			padn := 56 - last;
		ELSE
			padn := 120 - last;
		END;
		IF padn > 0 THEN
			Update( OA( padn-1, ADR( md5_padding )));
		END;
		Update( msglen );

		pdigest := TPDigestLW( _digest.digest );
		FOR i := 0 TO 3 DO
			pdigest^[i] := state[i];
		END; // FOR
	END Finish;
	
(*--------------------------------------------------------------------------------*)

	PRIVATE INLINE PROCEDURE md5_process( CONST data : TBuffer );

	(*----------*)

      INLINE PROCEDURE S( x : CARD32; n : CARD32 ) : CARD32; // ROTL
      BEGIN
         RETURN ( x << n ) OR ( x >> ( 32 - n ));
      END S;

	(*----------*)

		INLINE PROCEDURE F0( x, y, z : CARD32 ) : CARD32;
		BEGIN
			RETURN z XOR ( x AND ( y XOR z ));
		END F0;

	(*----------*)

		INLINE PROCEDURE F1( x, y, z : CARD32 ) : CARD32;
		BEGIN
			RETURN y XOR ( z AND ( x XOR y ));
		END F1;

	(*----------*)

      INLINE PROCEDURE F2( x, y, z : CARD32 ) : CARD32;
      BEGIN
         RETURN x XOR y XOR z;
      END F2;

	(*----------*)

      INLINE PROCEDURE F3( x, y, z : CARD32 ) : CARD32;
      BEGIN
         RETURN y XOR ( x OR NOT z );
      END F3;

	(*----------*)

		INLINE PROCEDURE P( REF a : CARD32; b, c, d : CARD32; k, s, t, f : CARD32 );
		BEGIN
		   a := a + processbuffer[k] + t;
		   CASE f OF
		   | 0 : a := a + F0( b, c, d );
		   | 1 : a := a + F1( b, c, d );
		   | 2 : a := a + F2( b, c, d );
		   | 3 : a := a + F3( b, c, d );
		   END;
		   a := S( a, s ) + b;
		END P;

	(*----------*)

	VAR
		A, B, C, D : CARD32;
		i : CARDINAL;
		pdata : TPBufferLW := TPBufferLW( ADR( data ));
	BEGIN
		FOR i := 0 TO 15 DO
			processbuffer[i] := pdata^[i];
		END;

		A := state[0];
		B := state[1];
		C := state[2];
		D := state[3];

      P( REF A, B, C, D,  0,  7, 0D76AA478H, 0 );
      P( REF D, A, B, C,  1, 12, 0E8C7B756H, 0 );
      P( REF C, D, A, B,  2, 17, 0242070DBH, 0 );
      P( REF B, C, D, A,  3, 22, 0C1BDCEEEH, 0 );
      P( REF A, B, C, D,  4,  7, 0F57C0FAFH, 0 );
      P( REF D, A, B, C,  5, 12, 04787C62AH, 0 );
      P( REF C, D, A, B,  6, 17, 0A8304613H, 0 );
      P( REF B, C, D, A,  7, 22, 0FD469501H, 0 );
      P( REF A, B, C, D,  8,  7, 0698098D8H, 0 );
      P( REF D, A, B, C,  9, 12, 08B44F7AFH, 0 );
      P( REF C, D, A, B, 10, 17, 0FFFF5BB1H, 0 );
      P( REF B, C, D, A, 11, 22, 0895CD7BEH, 0 );
      P( REF A, B, C, D, 12,  7, 06B901122H, 0 );
      P( REF D, A, B, C, 13, 12, 0FD987193H, 0 );
      P( REF C, D, A, B, 14, 17, 0A679438EH, 0 );
      P( REF B, C, D, A, 15, 22, 049B40821H, 0 );
      P( REF A, B, C, D,  1,  5, 0F61E2562H, 1 );
      P( REF D, A, B, C,  6,  9, 0C040B340H, 1 );
      P( REF C, D, A, B, 11, 14, 0265E5A51H, 1 );
      P( REF B, C, D, A,  0, 20, 0E9B6C7AAH, 1 );
      P( REF A, B, C, D,  5,  5, 0D62F105DH, 1 );
      P( REF D, A, B, C, 10,  9, 002441453H, 1 );
      P( REF C, D, A, B, 15, 14, 0D8A1E681H, 1 );
      P( REF B, C, D, A,  4, 20, 0E7D3FBC8H, 1 );
      P( REF A, B, C, D,  9,  5, 021E1CDE6H, 1 );
      P( REF D, A, B, C, 14,  9, 0C33707D6H, 1 );
      P( REF C, D, A, B,  3, 14, 0F4D50D87H, 1 );
      P( REF B, C, D, A,  8, 20, 0455A14EDH, 1 );
      P( REF A, B, C, D, 13,  5, 0A9E3E905H, 1 );
      P( REF D, A, B, C,  2,  9, 0FCEFA3F8H, 1 );
      P( REF C, D, A, B,  7, 14, 0676F02D9H, 1 );
      P( REF B, C, D, A, 12, 20, 08D2A4C8AH, 1 );
      P( REF A, B, C, D,  5,  4, 0FFFA3942H, 2 );
      P( REF D, A, B, C,  8, 11, 08771F681H, 2 );
      P( REF C, D, A, B, 11, 16, 06D9D6122H, 2 );
      P( REF B, C, D, A, 14, 23, 0FDE5380CH, 2 );
      P( REF A, B, C, D,  1,  4, 0A4BEEA44H, 2 );
      P( REF D, A, B, C,  4, 11, 04BDECFA9H, 2 );
      P( REF C, D, A, B,  7, 16, 0F6BB4B60H, 2 );
      P( REF B, C, D, A, 10, 23, 0BEBFBC70H, 2 );
      P( REF A, B, C, D, 13,  4, 0289B7EC6H, 2 );
      P( REF D, A, B, C,  0, 11, 0EAA127FAH, 2 );
      P( REF C, D, A, B,  3, 16, 0D4EF3085H, 2 );
      P( REF B, C, D, A,  6, 23, 004881D05H, 2 );
      P( REF A, B, C, D,  9,  4, 0D9D4D039H, 2 );
      P( REF D, A, B, C, 12, 11, 0E6DB99E5H, 2 );
      P( REF C, D, A, B, 15, 16, 01FA27CF8H, 2 );
      P( REF B, C, D, A,  2, 23, 0C4AC5665H, 2 );
      P( REF A, B, C, D,  0,  6, 0F4292244H, 3 );
      P( REF D, A, B, C,  7, 10, 0432AFF97H, 3 );
      P( REF C, D, A, B, 14, 15, 0AB9423A7H, 3 );
      P( REF B, C, D, A,  5, 21, 0FC93A039H, 3 );
      P( REF A, B, C, D, 12,  6, 0655B59C3H, 3 );
      P( REF D, A, B, C,  3, 10, 08F0CCC92H, 3 );
      P( REF C, D, A, B, 10, 15, 0FFEFF47DH, 3 );
      P( REF B, C, D, A,  1, 21, 085845DD1H, 3 );
      P( REF A, B, C, D,  8,  6, 06FA87E4FH, 3 );
      P( REF D, A, B, C, 15, 10, 0FE2CE6E0H, 3 );
      P( REF C, D, A, B,  6, 15, 0A3014314H, 3 );
      P( REF B, C, D, A, 13, 21, 04E0811A1H, 3 );
      P( REF A, B, C, D,  4,  6, 0F7537E82H, 3 );
      P( REF D, A, B, C, 11, 10, 0BD3AF235H, 3 );
      P( REF C, D, A, B,  2, 15, 02AD7D2BBH, 3 );
      P( REF B, C, D, A,  9, 21, 0EB86D391H, 3 );

		INC( state[0], A );
		INC( state[1], B );
		INC( state[2], C );
		INC( state[3], D );
	END md5_process;

(*--------------------------------------------------------------------------------*)

BEGIN
	count[0] := 0;
	state[0] := 0;
	inputbuffer[0] := 0;
	processbuffer[0] := 0;
END CMD5;

(*================================================================================*)

PROCEDURE Digest( CONST input : ARRAY OF BYTE; OUT D : digest.ADigest );
VAR
	S : CMD5;
BEGIN
	S.Digest( input, OUT D );
END Digest;

(*--------------------------------------------------------------------------------*)

PROCEDURE DigestOA( CONST input : ARRAY OF BYTE; OUT D : TDigest );
VAR
	S : CMD5;
	_D : CDigest;
BEGIN
	S.Digest( input, OUT _D );
	_D.ToOA( OUT D );
END DigestOA;

(*================================================================================*)

END md5.