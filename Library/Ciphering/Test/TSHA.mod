MODULE TSHA;

IMPORT
	cphcommon,
	sha;
  
#save, call( convention => cdecl )
PROCEDURE wmain() : INTEGER;
#restore
VAR
	d : sha.CDigest;
	in : ARRAY [0..511] OF BYTE;
	s : ARRAY [0..1023] OF WCHAR;
	SHA : sha.CSHA256;
BEGIN
	SHA.Digest( C"The quick brown fox jumps over the lazy dog", OUT d );
	d.ToHex( OUT s );

	SHA.Digest( C"The quick brown fox jumps over the lazy cog", OUT d );
	d.ToHex( OUT s );

	SHA.Digest( OA( 0, NIL ), OUT d );
	d.ToHex( OUT s );

	// cphcommon.FromHex( L"6bc1bee22e409f96e93d7e117393172aae2d8a571e03ac9c9eb76fac45af8e5130c81c46a35ce411e5fbc1191a0a52eff69f2445df4f9b17ad2b417be66c3710", OUT in );
	// cphcommon.ToHex( in, OUT s );

	RETURN 0;
END wmain;

END TSHA.