IMPLEMENTATION MODULE Uniquer;

IMPORT
	DiskInfo,
	Rijndael,
	sha256;

(*================================================================================*)

CLASS IMPLEMENTATION CUniquer;

(*--------------------------------------------------------------------------------*)

   PUBLIC PROPERTY Sources GET : lists.TPPtrList;
   BEGIN
      RETURN ADR( _Sources );
   END Sources;

(*--------------------------------------------------------------------------------*)

   PUBLIC PROCEDURE UId( CONST S : StringsO.IString ) : TUId;
   VAR
      i : INTEGER;
      uid, suid : TUId;
      seed : sha256.TDigest;
      source : POINTER TO IUniquerSource;
   BEGIN
      sha256.DigestOA( OA( 2*S.Length-1, S.rawData ), OUT seed );
      FOR i := 0 TO HIGH( uid ) DO
         IF DEBUGGED() THEN
            uid[i] := 58 - i;
         ELSE
            uid[i] := 58 + i;
         END;
      END;

      _Sources.Reset();
      WHILE _Sources.MoveNext() DO
         source := _Sources.Current;
         IF source^.Valid THEN
            source^.Seed := TUId( seed );
            suid := source^.UId;
            FOR i := 0 TO HIGH( uid ) DO
               uid[i] := uid[i] XOR suid[i];
            END;
         END;
      END; // WHILE

      RETURN uid;
   END UId;

(*--------------------------------------------------------------------------------*)

END CUniquer;

(*================================================================================*)

CLASS IMPLEMENTATION NullSource;

(*--------------------------------------------------------------------------------*)

	PUBLIC VIRTUAL PROPERTY Seed SET( CONST Value : TUId );
	VAR
		A : Rijndael.CRijndael;
		l : CARDINAL;
	BEGIN
		_Seed := Value;
		A.Init( Rijndael.cphmECBe, Rijndael.rkl256, _Seed, OA( 0, NIL ));
		A.Encrypt( _Seed, OUT _Seed, OUT l );
	END Seed;

(*--------------------------------------------------------------------------------*)

	PUBLIC VIRTUAL PROPERTY UId GET : TUId;
	BEGIN
		RETURN _Seed;
	END UId;

(*--------------------------------------------------------------------------------*)

	PUBLIC VIRTUAL PROPERTY Valid GET : BOOLEAN;
	BEGIN
		RETURN _Valid;
	END Valid;

(*--------------------------------------------------------------------------------*)

BEGIN
	_Valid := TRUE;
	_Seed[0] := 0;
END NullSource;

(*================================================================================*)

CLASS IMPLEMENTATION DiscSource;

(*--------------------------------------------------------------------------------*)

	PUBLIC VIRTUAL PROPERTY UId GET : TUId;
	VAR
		A : Rijndael.CRijndael;
		DI : DiskInfo.CDiskInfo;
		l : CARDINAL;
		s : ARRAY [0..31] OF CHAR;
		uid : TUId;
	BEGIN
		IF NOT DiskInfo.LoadDiskInfo( 0, OUT DI ) THEN
			RETURN SUPER.UId;
		END;
		FOR l := 0 TO HIGH( s ) DO
		   s[l] := CHAR( 75 + l );
		END;
		DI.Serial.ToOAA( 0, OUT s );
		A.Init( Rijndael.cphmECBe, Rijndael.rkl256, _Seed, OA( 0, NIL ));
		A.Encrypt( s, OUT uid, OUT l );
		RETURN uid;
	END UId;

(*--------------------------------------------------------------------------------*)

	INITIALLY DiscSource;
	VAR
		DI : DiskInfo.CDiskInfo;
	BEGIN
		_Valid := DiskInfo.LoadDiskInfo( 0, OUT DI );
	END DiscSource;

(*--------------------------------------------------------------------------------*)

END DiscSource;

(*================================================================================*)

END Uniquer.