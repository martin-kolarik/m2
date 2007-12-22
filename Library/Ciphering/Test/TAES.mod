MODULE TAES;

IMPORT
	cphcommon,
	Rijndael;
  
#save, call( convention => cdecl )
PROCEDURE wmain03() : INTEGER;
#restore
VAR
	AES : Rijndael.CRijndael;
	b, iv : ARRAY [0..31] OF BYTE;
	i : CARDINAL;
	in, out : ARRAY [0..511] OF BYTE;
	s : ARRAY [0..1023] OF WCHAR;
BEGIN
	cphcommon.FromHex( L"6bc1bee22e409f96e93d7e117393172aae2d8a571e03ac9c9eb76fac45af8e5130c81c46a35ce411e5fbc1191a0a52eff69f2445df4f9b17ad2b417be66c3710", OUT in, OUT i );
	cphcommon.FromHex( L"000102030405060708090a0b0c0d0e0f", OUT iv, OUT i );

   (*
	// ECB
	cphcommon.FromHex( L"2b7e151628aed2a6abf7158809cf4f3c", OUT b, OUT i );
	AES.Init( Rijndael.cphmECBe, Rijndael.rkl128, b, OAsz( PBYTE( NIL )));
	AES.Encrypt( OA( 63, ADR( in )), OUT out, OUT i );
	cphcommon.ToHex( out, OUT s );
	AES.Init( Rijndael.cphmECBd, Rijndael.rkl128, b, OAsz( PBYTE( NIL )));
	AES.Decrypt( OA( 63, ADR( out )), OUT in, OUT i );
	cphcommon.ToHex( in, OUT s );

	cphcommon.FromHex( L"8e73b0f7da0e6452c810f32b809079e562f8ead2522c6b7b", OUT b, OUT i );
	AES.Init( Rijndael.cphmECBe, Rijndael.rkl192, b, OAsz( PBYTE( NIL )));
	AES.Encrypt( OA( 63, ADR( in )), OUT out, OUT i );
	cphcommon.ToHex( out, OUT s );
	AES.Init( Rijndael.cphmECBd, Rijndael.rkl192, b, OAsz( PBYTE( NIL )));
	AES.Decrypt( OA( 63, ADR( out )), OUT in, OUT i );
	cphcommon.ToHex( in, OUT s );

	cphcommon.FromHex( L"603deb1015ca71be2b73aef0857d77811f352c073b6108d72d9810a30914dff4", OUT b, OUT i );
	AES.Init( Rijndael.cphmECBe, Rijndael.rkl256, b, OAsz( PBYTE( NIL )));
	AES.Encrypt( OA( 63, ADR( in )), OUT out, OUT i );
	cphcommon.ToHex( out, OUT s );
	AES.Init( Rijndael.cphmECBd, Rijndael.rkl256, b, OAsz( PBYTE( NIL )));
	AES.Decrypt( OA( 63, ADR( out )), OUT in, OUT i );
	cphcommon.ToHex( in, OUT s );
	
	// CBC
	cphcommon.FromHex( L"2b7e151628aed2a6abf7158809cf4f3c", OUT b, OUT i );
	AES.Init( Rijndael.cphmCBCe, Rijndael.rkl128, b, iv );
	AES.Encrypt( OA( 63, ADR( in )), OUT out, OUT i );
	cphcommon.ToHex( out, OUT s );
	AES.Init( Rijndael.cphmCBCd, Rijndael.rkl128, b, iv );
	AES.Decrypt( OA( 63, ADR( out )), OUT in, OUT i );
	cphcommon.ToHex( in, OUT s );

	cphcommon.FromHex( L"8e73b0f7da0e6452c810f32b809079e562f8ead2522c6b7b", OUT b, OUT i );
	AES.Init( Rijndael.cphmCBCe, Rijndael.rkl192, b, iv );
	AES.Encrypt( OA( 63, ADR( in )), OUT out, OUT i );
	cphcommon.ToHex( out, OUT s );
	AES.Init( Rijndael.cphmCBCd, Rijndael.rkl192, b, iv );
	AES.Decrypt( OA( 63, ADR( out )), OUT in, OUT i );
	cphcommon.ToHex( in, OUT s );

	cphcommon.FromHex( L"603deb1015ca71be2b73aef0857d77811f352c073b6108d72d9810a30914dff4", OUT b, OUT i );
	AES.Init( Rijndael.cphmCBCe, Rijndael.rkl256, b, iv );
	AES.Encrypt( OA( 63, ADR( in )), OUT out, OUT i );
	cphcommon.ToHex( out, OUT s );
	AES.Init( Rijndael.cphmCBCd, Rijndael.rkl256, b, iv );
	AES.Decrypt( OA( 63, ADR( out )), OUT in, OUT i );
	cphcommon.ToHex( in, OUT s );
	
	// CFB8 by blocks
	cphcommon.FromHex( L"2b7e151628aed2a6abf7158809cf4f3c", OUT b, OUT i );
	AES.Init( Rijndael.cphmCFB8e, Rijndael.rkl128, b, iv );
	AES.Encrypt( OA( 63, ADR( in )), OUT out, OUT i );
	cphcommon.ToHex( out, OUT s );
	AES.Init( Rijndael.cphmCFB8d, Rijndael.rkl128, b, iv );
	AES.Decrypt( OA( 63, ADR( out )), OUT in, OUT i );
	cphcommon.ToHex( in, OUT s );

	cphcommon.FromHex( L"8e73b0f7da0e6452c810f32b809079e562f8ead2522c6b7b", OUT b, OUT i );
	AES.Init( Rijndael.cphmCFB8e, Rijndael.rkl192, b, iv );
	AES.Encrypt( OA( 63, ADR( in )), OUT out, OUT i );
	cphcommon.ToHex( out, OUT s );
	AES.Init( Rijndael.cphmCFB8d, Rijndael.rkl192, b, iv );
	AES.Decrypt( OA( 63, ADR( out )), OUT in, OUT i );
	cphcommon.ToHex( in, OUT s );

	cphcommon.FromHex( L"603deb1015ca71be2b73aef0857d77811f352c073b6108d72d9810a30914dff4", OUT b, OUT i );
	AES.Init( Rijndael.cphmCFB8e, Rijndael.rkl256, b, iv );
	AES.Encrypt( OA( 63, ADR( in )), OUT out, OUT i );
	cphcommon.ToHex( out, OUT s );
	AES.Init( Rijndael.cphmCFB8d, Rijndael.rkl256, b, iv );
	AES.Decrypt( OA( 63, ADR( out )), OUT in, OUT i );
	cphcommon.ToHex( in, OUT s );

	// CFB8 by pieces
	AES.Init( Rijndael.cphmCFB8e, Rijndael.rkl256, b, iv );
	
	AES.Encrypt( OA(  8, ADR( in[ 0] )), OUT out[ 0], OUT i );
	AES.Encrypt( OA( 47, ADR( in[ 9] )), OUT out[ 9], OUT i );
	AES.Encrypt( OA(  6, ADR( in[57] )), OUT out[57], OUT i );
	cphcommon.ToHex( out, OUT s );

	AES.Init( Rijndael.cphmCFB8d, Rijndael.rkl256, b, iv );
	AES.Decrypt( OA( 21, ADR( out[ 0] )), OUT in[ 0], OUT i );
	AES.Decrypt( OA( 17, ADR( out[22] )), OUT in[22], OUT i );
	AES.Decrypt( OA( 23, ADR( out[40] )), OUT in[40], OUT i );
	cphcommon.ToHex( in, OUT s );
	*)

	// CFB128 by blocks
	cphcommon.FromHex( L"2b7e151628aed2a6abf7158809cf4f3c", OUT b, OUT i );
	AES.Init( Rijndael.cphmCFB128e, Rijndael.rkl128, b, iv );
	AES.Encrypt( OA( 63, ADR( in )), OUT out, OUT i );
	cphcommon.ToHex( out, OUT s );
	AES.Init( Rijndael.cphmCFB128d, Rijndael.rkl128, b, iv );
	AES.Decrypt( OA( 63, ADR( out )), OUT in, OUT i );
	cphcommon.ToHex( in, OUT s );

	cphcommon.FromHex( L"8e73b0f7da0e6452c810f32b809079e562f8ead2522c6b7b", OUT b, OUT i );
	AES.Init( Rijndael.cphmCFB128e, Rijndael.rkl192, b, iv );
	AES.Encrypt( OA( 63, ADR( in )), OUT out, OUT i );
	cphcommon.ToHex( out, OUT s );
	AES.Init( Rijndael.cphmCFB128d, Rijndael.rkl192, b, iv );
	AES.Decrypt( OA( 63, ADR( out )), OUT in, OUT i );
	cphcommon.ToHex( in, OUT s );

	cphcommon.FromHex( L"603deb1015ca71be2b73aef0857d77811f352c073b6108d72d9810a30914dff4", OUT b, OUT i );
	AES.Init( Rijndael.cphmCFB128e, Rijndael.rkl256, b, iv );
	AES.Encrypt( OA( 63, ADR( in )), OUT out, OUT i );
	cphcommon.ToHex( out, OUT s );
	AES.Init( Rijndael.cphmCFB128d, Rijndael.rkl256, b, iv );
	AES.Decrypt( OA( 63, ADR( out )), OUT in, OUT i );
	cphcommon.ToHex( in, OUT s );

   // dtto in place
	AES.Init( Rijndael.cphmCFB128d, Rijndael.rkl256, b, iv );
	AES.Decrypt( OA( 63, ADR( out )), OUT out, OUT i );
	cphcommon.ToHex( in, OUT s );

	// CFB128 by pieces
	AES.Init( Rijndael.cphmCFB128e, Rijndael.rkl256, b, iv );
	
	AES.Encrypt( OA(  8, ADR( in[ 0] )), OUT out[ 0], OUT i );
	AES.Encrypt( OA( 47, ADR( in[ 9] )), OUT out[ 9], OUT i );
	AES.Encrypt( OA(  6, ADR( in[57] )), OUT out[57], OUT i );
	cphcommon.ToHex( out, OUT s );

	AES.Init( Rijndael.cphmCFB128d, Rijndael.rkl256, b, iv );
	AES.Decrypt( OA( 21, ADR( out[ 0] )), OUT in[ 0], OUT i );
	AES.Decrypt( OA( 17, ADR( out[22] )), OUT in[22], OUT i );
	AES.Decrypt( OA( 23, ADR( out[40] )), OUT in[40], OUT i );
	cphcommon.ToHex( in, OUT s );

   // dtto in place
	AES.Init( Rijndael.cphmCFB128d, Rijndael.rkl256, b, iv );
	AES.Decrypt( OA( 21, ADR( out[ 0] )), OUT out[ 0], OUT i );
	AES.Decrypt( OA( 17, ADR( out[22] )), OUT out[22], OUT i );
	AES.Decrypt( OA( 23, ADR( out[40] )), OUT out[40], OUT i );
	cphcommon.ToHex( in, OUT s );

	// OFB by blocks
	cphcommon.FromHex( L"2b7e151628aed2a6abf7158809cf4f3c", OUT b, OUT i );
	AES.Init( Rijndael.cphmOFBe, Rijndael.rkl128, b, iv );
	AES.Encrypt( OA( 63, ADR( in )), OUT out, OUT i );
	cphcommon.ToHex( out, OUT s );
	AES.Init( Rijndael.cphmOFBd, Rijndael.rkl128, b, iv );
	AES.Decrypt( OA( 63, ADR( out )), OUT in, OUT i );
	cphcommon.ToHex( in, OUT s );

	cphcommon.FromHex( L"8e73b0f7da0e6452c810f32b809079e562f8ead2522c6b7b", OUT b, OUT i );
	AES.Init( Rijndael.cphmOFBe, Rijndael.rkl192, b, iv );
	AES.Encrypt( OA( 63, ADR( in )), OUT out, OUT i );
	cphcommon.ToHex( out, OUT s );
	AES.Init( Rijndael.cphmOFBd, Rijndael.rkl192, b, iv );
	AES.Decrypt( OA( 63, ADR( out )), OUT in, OUT i );
	cphcommon.ToHex( in, OUT s );

	cphcommon.FromHex( L"603deb1015ca71be2b73aef0857d77811f352c073b6108d72d9810a30914dff4", OUT b, OUT i );
	AES.Init( Rijndael.cphmOFBe, Rijndael.rkl256, b, iv );
	AES.Encrypt( OA( 63, ADR( in )), OUT out, OUT i );
	cphcommon.ToHex( out, OUT s );
	AES.Init( Rijndael.cphmOFBd, Rijndael.rkl256, b, iv );
	AES.Decrypt( OA( 63, ADR( out )), OUT in, OUT i );
	cphcommon.ToHex( in, OUT s );

	// OFB by pieces
	AES.Init( Rijndael.cphmOFBe, Rijndael.rkl256, b, iv );
	
	AES.Encrypt( OA(  8, ADR( in[ 0] )), OUT out[ 0], OUT i );
	AES.Encrypt( OA( 47, ADR( in[ 9] )), OUT out[ 9], OUT i );
	AES.Encrypt( OA(  6, ADR( in[57] )), OUT out[57], OUT i );
	cphcommon.ToHex( out, OUT s );

	AES.Init( Rijndael.cphmOFBd, Rijndael.rkl256, b, iv );
	AES.Decrypt( OA( 21, ADR( out[ 0] )), OUT in[ 0], OUT i );
	AES.Decrypt( OA( 17, ADR( out[22] )), OUT in[22], OUT i );
	AES.Decrypt( OA( 23, ADR( out[40] )), OUT in[40], OUT i );
	cphcommon.ToHex( in, OUT s );

	RETURN 0;
END wmain03;

END TAES.