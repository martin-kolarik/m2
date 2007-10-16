IMPLEMENTATION MODULE sha256;

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
	sha256_padding = TProcessBuffer(
		080H, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
		0,    0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
		0,    0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
		0,    0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0
	);

(*================================================================================*)

CLASS IMPLEMENTATION CSHA256;
	
(*--------------------------------------------------------------------------------*)

	PUBLIC VIRTUAL PROCEDURE Init();
	BEGIN
		count[0] := 0;
		count[1] := 0;
		state[0] := 06A09E667H;
		state[1] := 0BB67AE85H;
		state[2] := 03C6EF372H;
		state[3] := 0A54FF53AH;
		state[4] := 0510E527FH;
		state[5] := 09B05688CH;
		state[6] := 01F83D9ABH;
		state[7] := 05BE0CD19H;
	END Init;

(*--------------------------------------------------------------------------------*)

	PUBLIC VIRTUAL PROCEDURE Update( CONST input : ARRAY OF BYTE );
	VAR
		in : PCARD8 := PCARD8( ADR( input ));
		length : CARDINAL := HIGH( input ) + 1;
		left, fill : CARDINAL;
	BEGIN
		IF ADR( input ) = NIL THEN
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
			sha256_process( inputbuffer );
		END;

		WHILE length >= 64 DO
			sha256_process( TPBuffer( in )^ );
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
			Update( OA( padn-1, ADR( sha256_padding )));
		END;
		Update( msglen );

		pdigest := TPDigestLW( _digest.digest );
		FOR i := 0 TO 7 DO
			pdigest^[i] := REVERSE( state[i] );
		END; // FOR
	END Finish;
	
(*--------------------------------------------------------------------------------*)

	PRIVATE INLINE PROCEDURE sha256_process( CONST data : TBuffer );

	(*----------*)

		INLINE PROCEDURE SHR( x, n : CARD32 ) : CARD32;
		BEGIN
			RETURN x >> n;
		END SHR;

	(*----------*)

		INLINE PROCEDURE ROTR( x, n : CARD32 ) : CARD32;
		BEGIN
			RETURN ( x >> n ) OR ( x << ( 32 - n ));
		END ROTR;

	(*----------*)

		INLINE PROCEDURE S0( x : CARD32 ) : CARD32;
		BEGIN
			RETURN ROTR( x, 7 ) XOR ROTR( x, 18 ) XOR  SHR( x, 3 );
		END S0;

	(*----------*)

		INLINE PROCEDURE S1( x : CARD32 ) : CARD32;
		BEGIN
			RETURN ROTR( x, 17 ) XOR ROTR( x, 19 ) XOR SHR( x, 10 );
		END S1;

	(*----------*)

		INLINE PROCEDURE S2( x : CARD32 ) : CARD32;
		BEGIN
			RETURN ROTR( x, 2 ) XOR ROTR( x, 13 ) XOR ROTR( x, 22 );
		END S2;

	(*----------*)

		INLINE PROCEDURE S3( x : CARD32 ) : CARD32;
		BEGIN
			RETURN ROTR( x, 6 ) XOR ROTR( x, 11 ) XOR ROTR( x, 25 );
		END S3;

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

		INLINE PROCEDURE P( a, b, c : CARD32; REF d : CARD32; e, f, g : CARD32; REF h : CARD32; x, K : CARD32 );
		VAR
			A, B : CARD32;
		BEGIN
			A := F1( e, f, g ) + S3( e ) + h + x + K;
			B := F0( a, b, c ) + S2( a );
			INC( d, A );
			h := A + B;
		END P;

	(*----------*)

		INLINE PROCEDURE R( t : CARD32 ) : CARD32;
		BEGIN
			processbuffer[t] := S1( processbuffer[t-2] ) + processbuffer[t-7] + S0( processbuffer[t-15] ) + processbuffer[t-16];
			RETURN processbuffer[t];
		END R;

	(*----------*)

	VAR
		A, B, C, D, E, F, G, H : CARD32;
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
		F := state[5];
		G := state[6];
		H := state[7];

		P( A, B, C, REF D, E, F, G, REF H, processbuffer[ 0], 0428A2F98H );
		P( H, A, B, REF C, D, E, F, REF G, processbuffer[ 1], 071374491H );
		P( G, H, A, REF B, C, D, E, REF F, processbuffer[ 2], 0B5C0FBCFH );
		P( F, G, H, REF A, B, C, D, REF E, processbuffer[ 3], 0E9B5DBA5H );
		P( E, F, G, REF H, A, B, C, REF D, processbuffer[ 4], 03956C25BH );
		P( D, E, F, REF G, H, A, B, REF C, processbuffer[ 5], 059F111F1H );
		P( C, D, E, REF F, G, H, A, REF B, processbuffer[ 6], 0923F82A4H );
		P( B, C, D, REF E, F, G, H, REF A, processbuffer[ 7], 0AB1C5ED5H );
		P( A, B, C, REF D, E, F, G, REF H, processbuffer[ 8], 0D807AA98H );
		P( H, A, B, REF C, D, E, F, REF G, processbuffer[ 9], 012835B01H );
		P( G, H, A, REF B, C, D, E, REF F, processbuffer[10], 0243185BEH );
		P( F, G, H, REF A, B, C, D, REF E, processbuffer[11], 0550C7DC3H );
		P( E, F, G, REF H, A, B, C, REF D, processbuffer[12], 072BE5D74H );
		P( D, E, F, REF G, H, A, B, REF C, processbuffer[13], 080DEB1FEH );
		P( C, D, E, REF F, G, H, A, REF B, processbuffer[14], 09BDC06A7H );
		P( B, C, D, REF E, F, G, H, REF A, processbuffer[15], 0C19BF174H );
		P( A, B, C, REF D, E, F, G, REF H, R(16),             0E49B69C1H );
		P( H, A, B, REF C, D, E, F, REF G, R(17),             0EFBE4786H );
		P( G, H, A, REF B, C, D, E, REF F, R(18),             00FC19DC6H );
		P( F, G, H, REF A, B, C, D, REF E, R(19),             0240CA1CCH );
		P( E, F, G, REF H, A, B, C, REF D, R(20),             02DE92C6FH );
		P( D, E, F, REF G, H, A, B, REF C, R(21),             04A7484AAH );
		P( C, D, E, REF F, G, H, A, REF B, R(22),             05CB0A9DCH );
		P( B, C, D, REF E, F, G, H, REF A, R(23),             076F988DAH );
		P( A, B, C, REF D, E, F, G, REF H, R(24),             0983E5152H );
		P( H, A, B, REF C, D, E, F, REF G, R(25),             0A831C66DH );
		P( G, H, A, REF B, C, D, E, REF F, R(26),             0B00327C8H );
		P( F, G, H, REF A, B, C, D, REF E, R(27),             0BF597FC7H );
		P( E, F, G, REF H, A, B, C, REF D, R(28),             0C6E00BF3H );
		P( D, E, F, REF G, H, A, B, REF C, R(29),             0D5A79147H );
		P( C, D, E, REF F, G, H, A, REF B, R(30),             006CA6351H );
		P( B, C, D, REF E, F, G, H, REF A, R(31),             014292967H );
		P( A, B, C, REF D, E, F, G, REF H, R(32),             027B70A85H );
		P( H, A, B, REF C, D, E, F, REF G, R(33),             02E1B2138H );
		P( G, H, A, REF B, C, D, E, REF F, R(34),             04D2C6DFCH );
		P( F, G, H, REF A, B, C, D, REF E, R(35),             053380D13H );
		P( E, F, G, REF H, A, B, C, REF D, R(36),             0650A7354H );
		P( D, E, F, REF G, H, A, B, REF C, R(37),             0766A0ABBH );
		P( C, D, E, REF F, G, H, A, REF B, R(38),             081C2C92EH );
		P( B, C, D, REF E, F, G, H, REF A, R(39),             092722C85H );
		P( A, B, C, REF D, E, F, G, REF H, R(40),             0A2BFE8A1H );
		P( H, A, B, REF C, D, E, F, REF G, R(41),             0A81A664BH );
		P( G, H, A, REF B, C, D, E, REF F, R(42),             0C24B8B70H );
		P( F, G, H, REF A, B, C, D, REF E, R(43),             0C76C51A3H );
		P( E, F, G, REF H, A, B, C, REF D, R(44),             0D192E819H );
		P( D, E, F, REF G, H, A, B, REF C, R(45),             0D6990624H );
		P( C, D, E, REF F, G, H, A, REF B, R(46),             0F40E3585H );
		P( B, C, D, REF E, F, G, H, REF A, R(47),             0106AA070H );
		P( A, B, C, REF D, E, F, G, REF H, R(48),             019A4C116H );
		P( H, A, B, REF C, D, E, F, REF G, R(49),             01E376C08H );
		P( G, H, A, REF B, C, D, E, REF F, R(50),             02748774CH );
		P( F, G, H, REF A, B, C, D, REF E, R(51),             034B0BCB5H );
		P( E, F, G, REF H, A, B, C, REF D, R(52),             0391C0CB3H );
		P( D, E, F, REF G, H, A, B, REF C, R(53),             04ED8AA4AH );
		P( C, D, E, REF F, G, H, A, REF B, R(54),             05B9CCA4FH );
		P( B, C, D, REF E, F, G, H, REF A, R(55),             0682E6FF3H );
		P( A, B, C, REF D, E, F, G, REF H, R(56),             0748F82EEH );
		P( H, A, B, REF C, D, E, F, REF G, R(57),             078A5636FH );
		P( G, H, A, REF B, C, D, E, REF F, R(58),             084C87814H );
		P( F, G, H, REF A, B, C, D, REF E, R(59),             08CC70208H );
		P( E, F, G, REF H, A, B, C, REF D, R(60),             090BEFFFAH );
		P( D, E, F, REF G, H, A, B, REF C, R(61),             0A4506CEBH );
		P( C, D, E, REF F, G, H, A, REF B, R(62),             0BEF9A3F7H );
		P( B, C, D, REF E, F, G, H, REF A, R(63),             0C67178F2H );

		INC( state[0], A );
		INC( state[1], B );
		INC( state[2], C );
		INC( state[3], D );
		INC( state[4], E );
		INC( state[5], F );
		INC( state[6], G );
		INC( state[7], H );
	END sha256_process;

(*--------------------------------------------------------------------------------*)

BEGIN
	count[0] := 0;
	state[0] := 0;
	inputbuffer[0] := 0;
	processbuffer[0] := 0;
END CSHA256;

(*================================================================================*)

PROCEDURE Digest( CONST input : ARRAY OF BYTE; OUT D : digest.ADigest );
VAR
	S : CSHA256;
BEGIN
	S.Digest( input, OUT D );
END Digest;

(*--------------------------------------------------------------------------------*)

PROCEDURE DigestOA( CONST input : ARRAY OF BYTE; OUT D : TDigest );
VAR
	S : CSHA256;
	_D : CDigest;
BEGIN
	S.Digest( input, OUT _D );
	_D.ToOA( OUT D );
END DigestOA;

(*================================================================================*)

END sha256.