IMPLEMENTATION MODULE sha1;

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
	sha1_padding = TProcessBuffer(
		080H, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
		0,    0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
		0,    0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
		0,    0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0
	);

(*================================================================================*)

CLASS IMPLEMENTATION CSHA1;
	
(*--------------------------------------------------------------------------------*)

   PUBLIC VIRTUAL PROCEDURE Init();
   BEGIN
      count[0] := 0;
      count[1] := 0;
      state[0] := 067452301H;
      state[1] := 0EFCDAB89H;
      state[2] := 098BADCFEH;
      state[3] := 010325476H;
      state[4] := 0C3D2E1F0H;
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
			sha1_process( inputbuffer );
		END;

		WHILE length >= 64 DO
			sha1_process( TPBuffer( in )^ );
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
		msglen[0] := REVERSE( hi );
		msglen[1] := REVERSE( lo );

		last := count[0] AND 03FH;
		IF last < 56 THEN
			padn := 56 - last;
		ELSE
			padn := 120 - last;
		END;
		IF padn > 0 THEN
			Update( OA( padn-1, ADR( sha1_padding )));
		END;
		Update( msglen );

		pdigest := TPDigestLW( _digest.digest );
		FOR i := 0 TO 4 DO
			pdigest^[i] := REVERSE( state[i] );
		END; // FOR
	END Finish;
	
(*--------------------------------------------------------------------------------*)

	PRIVATE PROCEDURE sha1_process( CONST data : TBuffer );

	(*----------*)

      INLINE PROCEDURE S( x : CARD32; n : CARD32 ) : CARD32; // ROTL
      BEGIN
         RETURN ( x << n ) OR ( x >> ( 32 - n ));
      END S;

	(*----------*)

		INLINE PROCEDURE F0( x, y, z : CARD32 ) : CARD32;
		BEGIN
			RETURN ( x AND y ) OR ( z AND ( x OR y ));
		END F0;

	(*----------*)

		INLINE PROCEDURE F1( x, y, z : CARD32 ) : CARD32;
		BEGIN
			RETURN z XOR ( x AND ( y XOR z ));
		END F1;

	(*----------*)

      INLINE PROCEDURE F2( x, y, z : CARD32 ) : CARD32;
      BEGIN
         RETURN x XOR y XOR z;
      END F2;

	(*----------*)

		INLINE PROCEDURE P( a : CARD32; REF b : CARD32; c, d : CARD32; REF e : CARD32; x, K, f : CARD32 );
		BEGIN
			e := e + S( a, 5 ) + K + x;
		   IF f = 0 THEN
		      e := e + F0( b, c, d );
		   ELSIF f = 1 THEN
		      e := e + F1( b, c, d );
		   ELSE
		      e := e + F2( b, c, d );
		   END;
			b := S( b, 30 );
		END P;

	(*----------*)

		INLINE PROCEDURE R( t : CARD32 ) : CARD32;
		VAR
		   temp : CARD32;
		BEGIN
         temp := processbuffer[ (t- 3) AND 0FH ] XOR
                 processbuffer[ (t- 8) AND 0FH ] XOR
                 processbuffer[ (t-14) AND 0FH ] XOR
                 processbuffer[  t     AND 0FH ];
         temp := S( temp, 1 );
         processbuffer[ t AND 0FH ] := temp;
         RETURN temp;
		END R;

	(*----------*)

	VAR
		A, B, C, D, E : CARD32;
		i : CARDINAL;
		pdata : TPBufferLW := TPBufferLW( ADR( data ));
	BEGIN
		FOR i := 0 TO 15 DO
			processbuffer[i] := REVERSE( pdata^[i] );
		END;

		A := state[0];
		B := state[1];
		C := state[2];
		D := state[3];
		E := state[4];

      P( A, REF B, C, D, REF E, processbuffer[0],  05A827999H, 1 );
      P( E, REF A, B, C, REF D, processbuffer[1],  05A827999H, 1 );
      P( D, REF E, A, B, REF C, processbuffer[2],  05A827999H, 1 );
      P( C, REF D, E, A, REF B, processbuffer[3],  05A827999H, 1 );
      P( B, REF C, D, E, REF A, processbuffer[4],  05A827999H, 1 );
      P( A, REF B, C, D, REF E, processbuffer[5],  05A827999H, 1 );
      P( E, REF A, B, C, REF D, processbuffer[6],  05A827999H, 1 );
      P( D, REF E, A, B, REF C, processbuffer[7],  05A827999H, 1 );
      P( C, REF D, E, A, REF B, processbuffer[8],  05A827999H, 1 );
      P( B, REF C, D, E, REF A, processbuffer[9],  05A827999H, 1 );
      P( A, REF B, C, D, REF E, processbuffer[10], 05A827999H, 1 );
      P( E, REF A, B, C, REF D, processbuffer[11], 05A827999H, 1 );
      P( D, REF E, A, B, REF C, processbuffer[12], 05A827999H, 1 );
      P( C, REF D, E, A, REF B, processbuffer[13], 05A827999H, 1 );
      P( B, REF C, D, E, REF A, processbuffer[14], 05A827999H, 1 );
      P( A, REF B, C, D, REF E, processbuffer[15], 05A827999H, 1 );
      P( E, REF A, B, C, REF D, R(16),             05A827999H, 1 );
      P( D, REF E, A, B, REF C, R(17),             05A827999H, 1 );
      P( C, REF D, E, A, REF B, R(18),             05A827999H, 1 );
      P( B, REF C, D, E, REF A, R(19),             05A827999H, 1 );
      P( A, REF B, C, D, REF E, R(20),             06ED9EBA1H, 2 );
      P( E, REF A, B, C, REF D, R(21),             06ED9EBA1H, 2 );
      P( D, REF E, A, B, REF C, R(22),             06ED9EBA1H, 2 );
      P( C, REF D, E, A, REF B, R(23),             06ED9EBA1H, 2 );
      P( B, REF C, D, E, REF A, R(24),             06ED9EBA1H, 2 );
      P( A, REF B, C, D, REF E, R(25),             06ED9EBA1H, 2 );
      P( E, REF A, B, C, REF D, R(26),             06ED9EBA1H, 2 );
      P( D, REF E, A, B, REF C, R(27),             06ED9EBA1H, 2 );
      P( C, REF D, E, A, REF B, R(28),             06ED9EBA1H, 2 );
      P( B, REF C, D, E, REF A, R(29),             06ED9EBA1H, 2 );
      P( A, REF B, C, D, REF E, R(30),             06ED9EBA1H, 2 );
      P( E, REF A, B, C, REF D, R(31),             06ED9EBA1H, 2 );
      P( D, REF E, A, B, REF C, R(32),             06ED9EBA1H, 2 );
      P( C, REF D, E, A, REF B, R(33),             06ED9EBA1H, 2 );
      P( B, REF C, D, E, REF A, R(34),             06ED9EBA1H, 2 );
      P( A, REF B, C, D, REF E, R(35),             06ED9EBA1H, 2 );
      P( E, REF A, B, C, REF D, R(36),             06ED9EBA1H, 2 );
      P( D, REF E, A, B, REF C, R(37),             06ED9EBA1H, 2 );
      P( C, REF D, E, A, REF B, R(38),             06ED9EBA1H, 2 );
      P( B, REF C, D, E, REF A, R(39),             06ED9EBA1H, 2 );
      P( A, REF B, C, D, REF E, R(40),             08F1BBCDCH, 0 );
      P( E, REF A, B, C, REF D, R(41),             08F1BBCDCH, 0 );
      P( D, REF E, A, B, REF C, R(42),             08F1BBCDCH, 0 );
      P( C, REF D, E, A, REF B, R(43),             08F1BBCDCH, 0 );
      P( B, REF C, D, E, REF A, R(44),             08F1BBCDCH, 0 );
      P( A, REF B, C, D, REF E, R(45),             08F1BBCDCH, 0 );
      P( E, REF A, B, C, REF D, R(46),             08F1BBCDCH, 0 );
      P( D, REF E, A, B, REF C, R(47),             08F1BBCDCH, 0 );
      P( C, REF D, E, A, REF B, R(48),             08F1BBCDCH, 0 );
      P( B, REF C, D, E, REF A, R(49),             08F1BBCDCH, 0 );
      P( A, REF B, C, D, REF E, R(50),             08F1BBCDCH, 0 );
      P( E, REF A, B, C, REF D, R(51),             08F1BBCDCH, 0 );
      P( D, REF E, A, B, REF C, R(52),             08F1BBCDCH, 0 );
      P( C, REF D, E, A, REF B, R(53),             08F1BBCDCH, 0 );
      P( B, REF C, D, E, REF A, R(54),             08F1BBCDCH, 0 );
      P( A, REF B, C, D, REF E, R(55),             08F1BBCDCH, 0 );
      P( E, REF A, B, C, REF D, R(56),             08F1BBCDCH, 0 );
      P( D, REF E, A, B, REF C, R(57),             08F1BBCDCH, 0 );
      P( C, REF D, E, A, REF B, R(58),             08F1BBCDCH, 0 );
      P( B, REF C, D, E, REF A, R(59),             08F1BBCDCH, 0 );
      P( A, REF B, C, D, REF E, R(60),             0CA62C1D6H, 2 );
      P( E, REF A, B, C, REF D, R(61),             0CA62C1D6H, 2 );
      P( D, REF E, A, B, REF C, R(62),             0CA62C1D6H, 2 );
      P( C, REF D, E, A, REF B, R(63),             0CA62C1D6H, 2 );
      P( B, REF C, D, E, REF A, R(64),             0CA62C1D6H, 2 );
      P( A, REF B, C, D, REF E, R(65),             0CA62C1D6H, 2 );
      P( E, REF A, B, C, REF D, R(66),             0CA62C1D6H, 2 );
      P( D, REF E, A, B, REF C, R(67),             0CA62C1D6H, 2 );
      P( C, REF D, E, A, REF B, R(68),             0CA62C1D6H, 2 );
      P( B, REF C, D, E, REF A, R(69),             0CA62C1D6H, 2 );
      P( A, REF B, C, D, REF E, R(70),             0CA62C1D6H, 2 );
      P( E, REF A, B, C, REF D, R(71),             0CA62C1D6H, 2 );
      P( D, REF E, A, B, REF C, R(72),             0CA62C1D6H, 2 );
      P( C, REF D, E, A, REF B, R(73),             0CA62C1D6H, 2 );
      P( B, REF C, D, E, REF A, R(74),             0CA62C1D6H, 2 );
      P( A, REF B, C, D, REF E, R(75),             0CA62C1D6H, 2 );
      P( E, REF A, B, C, REF D, R(76),             0CA62C1D6H, 2 );
      P( D, REF E, A, B, REF C, R(77),             0CA62C1D6H, 2 );
      P( C, REF D, E, A, REF B, R(78),             0CA62C1D6H, 2 );
      P( B, REF C, D, E, REF A, R(79),             0CA62C1D6H, 2 );

		INC( state[0], A );
		INC( state[1], B );
		INC( state[2], C );
		INC( state[3], D );
		INC( state[4], E );
	END sha1_process;

(*--------------------------------------------------------------------------------*)

BEGIN
	count[0] := 0;
	state[0] := 0;
	inputbuffer[0] := 0;
	processbuffer[0] := 0;
END CSHA1;

(*================================================================================*)

PROCEDURE Digest( CONST input : ARRAY OF BYTE; OUT D : digest.ADigest );
VAR
	S : CSHA1;
BEGIN
	S.Digest( input, OUT D );
END Digest;

(*--------------------------------------------------------------------------------*)

PROCEDURE DigestSalt( CONST input, salt : ARRAY OF BYTE; OUT D : digest.ADigest );
VAR
	S : CSHA1;
BEGIN
   S.DigestSalt( input, salt, OUT D );
END DigestSalt;

(*--------------------------------------------------------------------------------*)

PROCEDURE DigestOA( CONST input : ARRAY OF BYTE; OUT D : TDigest );
VAR
	S : CSHA1;
	_D : CDigest;
BEGIN
	S.Digest( input, OUT _D );
	_D.ToOA( OUT D );
END DigestOA;

(*--------------------------------------------------------------------------------*)

PROCEDURE DigestSaltOA( CONST input, salt : ARRAY OF BYTE; OUT D : TDigest );
VAR
	S : CSHA1;
	_D : CDigest;
BEGIN
   S.DigestSalt( input, salt, OUT _D );
	_D.ToOA( OUT D );
END DigestSaltOA;

(*================================================================================*)

END sha1.