IMPLEMENTATION MODULE digest;

FROM Debug IMPORT
   AssertionW;

IMPORT
	cphcommon,
	Md5,
	Sha1,
	Sha256;

(*================================================================================*)

CLASS IMPLEMENTATION ADigest;

(*--------------------------------------------------------------------------------*)

	PUBLIC OPERATOR ADigest.=( CONST Operand : ADigest ) : BOOLEAN;
	VAR
	   a1, a2, as : PBYTE;
	   s : CARDINAL := size;
	BEGIN
	   IF s <> Operand.size THEN
	      RETURN FALSE;
	   END;
	   
	   a1 := digest;
	   a2 := Operand.digest;
	   as := a1@[s];
	   WHILE a1 <> as DO
	      IF a1^ <> a2^ THEN
	         RETURN FALSE;
	      END;
	      INC( a1 );
	      INC( a2 );
	   END; // WHILE

      RETURN TRUE;
	END ADigest.=;

(*--------------------------------------------------------------------------------*)

	PUBLIC PROCEDURE FromOA( CONST Data : ARRAY OF BYTE );
	VAR
		i, l : CARDINAL;
	BEGIN
		l := MIN2( size, HIGH( Data )+1 );
		FOR i := 0 TO l-1 DO
			digest@[i]^ := Data[i];
		END;
		FOR i := l TO size-1 DO
			digest@[i]^ := 0;
		END;
	END FromOA;

(*--------------------------------------------------------------------------------*)

	PUBLIC PROCEDURE ToOA( OUT Data : ARRAY OF BYTE );
	VAR
		i, l : CARDINAL;
	BEGIN
		l := MIN2( size, HIGH( Data )+1 );
		FOR i := 0 TO l-1 DO
			Data[i] := digest@[i]^;
		END;
	END ToOA;

(*--------------------------------------------------------------------------------*)

	PUBLIC PROCEDURE FromHex( CONST String : ARRAY OF WCHAR );
	VAR
	   a : PBYTE := digest;
	   h : CARDINAL := size-1;
		i : CARDINAL;
	BEGIN
		cphcommon.FromHex( String, OUT OA( h, a ), OUT i );
		FOR i := HIGH( String )+1 TO h DO
			digest@[i]^ := 0;
		END;
	END FromHex;

(*--------------------------------------------------------------------------------*)

	PUBLIC PROCEDURE ToHex( OUT String : ARRAY OF WCHAR );
	BEGIN
		cphcommon.ToHex( OA( size-1, digest ), OUT String );
	END ToHex;

(*--------------------------------------------------------------------------------*)

END ADigest;

(*================================================================================*)

CLASS IMPLEMENTATION Digester;
	
(*--------------------------------------------------------------------------------*)

	PUBLIC PROCEDURE Digest( CONST input : ARRAY OF BYTE; OUT digest : ADigest );
	BEGIN
		Init();
		Update( input );
		Finish( OUT digest );
	END Digest;

(*--------------------------------------------------------------------------------*)

	PUBLIC PROCEDURE DigestSalt( CONST input, salt : ARRAY OF BYTE; OUT digest : ADigest );
	VAR
	   salted : ARRAY [0..31] OF BYTE;
	   saltedCount : CARDINAL;
	BEGIN
		Init();
	   cphcommon.Salt( input, salt, OUT salted, OUT saltedCount );
		IF saltedCount > 0 THEN
         Update( OA( saltedCount-1, ADR( salted )));
      END;
      IF HIGH( input )+1 > saltedCount THEN
	      Update( OA( HIGH( input )-saltedCount, ADR( input[saltedCount] )));
	   END;
		Finish( OUT digest );
	END DigestSalt;

(*--------------------------------------------------------------------------------*)

END Digester;

(*================================================================================*)

PROCEDURE Digest( Type : TDigestType; CONST input : ARRAY OF BYTE; OUT digest : ADigest );
BEGIN
   CASE Type OF
   | md5 :
      Md5.Digest( input, OUT digest );
   | sha1 :
      Sha1.Digest( input, OUT digest );
   | sha256 :
      Sha256.Digest( input, OUT digest );
   END;
END Digest;

(*--------------------------------------------------------------------------------*)

PROCEDURE DigestSalt( Type : TDigestType; CONST input, salt : ARRAY OF BYTE; OUT digest : ADigest );
BEGIN
   CASE Type OF
   | md5 :
      Md5.DigestSalt( input, salt, OUT digest );
   | sha1 :
      Sha1.DigestSalt( input, salt, OUT digest );
   | sha256 :
      Sha256.DigestSalt( input, salt, OUT digest );
   END;
END DigestSalt;

(*--------------------------------------------------------------------------------*)

PROCEDURE DigestOA( Type : TDigestType; CONST input : ARRAY OF BYTE; OUT digest : ARRAY OF BYTE );
TYPE
   TPmd5digest = POINTER TO Md5.TDigest;
   TPsha1digest = POINTER TO Sha1.TDigest;
   TPsha256digest = POINTER TO Sha256.TDigest;
BEGIN
   CASE Type OF
   | md5 :
      IF HIGH( digest ) < SIZE( Md5.TDigest )-1 THEN
         ASSERT( FALSE );
      ELSE
         Md5.DigestOA( input, OUT TPmd5digest( ADR( digest ))^ );
      END;
   | sha1 :
      IF HIGH( digest ) < SIZE( Sha1.TDigest )-1 THEN
         ASSERT( FALSE );
      ELSE
         Sha1.DigestOA( input, OUT TPsha1digest( ADR( digest ))^ );
      END;
   | sha256 :
      IF HIGH( digest ) < SIZE( Sha256.TDigest )-1 THEN
         ASSERT( FALSE );
      ELSE
         Sha256.DigestOA( input, OUT TPsha256digest( ADR( digest ))^ );
      END;
   END;
END DigestOA;

(*--------------------------------------------------------------------------------*)

PROCEDURE DigestSaltOA( Type : TDigestType; CONST input, salt : ARRAY OF BYTE; OUT digest : ARRAY OF BYTE );
TYPE
   TPmd5digest = POINTER TO Md5.TDigest;
   TPsha1digest = POINTER TO Sha1.TDigest;
   TPsha256digest = POINTER TO Sha256.TDigest;
BEGIN
   CASE Type OF
   | md5 :
      IF HIGH( digest ) < SIZE( Md5.TDigest )-1 THEN
         ASSERT( FALSE );
      ELSE
         Md5.DigestSaltOA( input, salt, OUT TPmd5digest( ADR( digest ))^ );
      END;
   | sha1 :
      IF HIGH( digest ) < SIZE( Sha1.TDigest )-1 THEN
         ASSERT( FALSE );
      ELSE
         Sha1.DigestSaltOA( input, salt, OUT TPsha1digest( ADR( digest ))^ );
      END;
   | sha256 :
      IF HIGH( digest ) < SIZE( Sha256.TDigest )-1 THEN
         ASSERT( FALSE );
      ELSE
         Sha256.DigestSaltOA( input, salt, OUT TPsha256digest( ADR( digest ))^ );
      END;
   END;
END DigestSaltOA;

(*================================================================================*)

END digest.