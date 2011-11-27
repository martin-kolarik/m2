IMPLEMENTATION MODULE Uniquer;

IMPORT
   collection,
	DiskInfo,
	netsrv,
	Rijndael,
	sha256;

(*================================================================================*)

TYPE
   TSalt = ARRAY [0..15] OF BYTE;
   
CONST
   salt = TSalt( 0FH, 1CH, 14H, 10H, 1AH, 89H, 3AH, 4CH, 0BCH, 93H, 74H, 28H, 0E5H, 082H, 09BH, 0EAH );

(*================================================================================*)

CLASS IMPLEMENTATION CUniquer;

(*--------------------------------------------------------------------------------*)

   PUBLIC PROPERTY Sources GET : lists.TPPtrList;
   BEGIN
      RETURN ADR( _Sources );
   END Sources;

(*--------------------------------------------------------------------------------*)

   PUBLIC PROCEDURE UId( CONST S : StringsO.IString ) : TUId;
   CONST
      salt = C"";
   VAR
      i : INTEGER;
      it : lists.CPtrListIterator;
      uid, suid : TUId;
      seed : sha256.TDigest;
      source : POINTER TO IUniquerSource;
   BEGIN
      sha256.DigestSaltOA( OA( 2*S.Length-1, S.Data ), salt, OUT seed );
      FOR i := 0 TO HIGH( uid ) DO
         IF DEBUGGED() THEN
            uid[i] := 58 - i;
         ELSE
            uid[i] := 58 + i;
         END;
      END;

      it.Init( _Sources, collection.dirForward );
      WHILE it.MoveNext() DO
         source := it.Value;
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

#if #contains( LicenceMachineId, L"D" ) #then

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
		DI.Serial.ToOAA( 0, OUT s, OUT l );
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

#endif

(*================================================================================*)

#if #contains( LicenceMachineId, L"M" ) #then

CLASS IMPLEMENTATION MACSource;

(*--------------------------------------------------------------------------------*)

	PUBLIC VIRTUAL PROPERTY UId GET : TUId;
	VAR
		A : Rijndael.CRijndael;
	   Buffer : ARRAY [0..31] OF BYTE;
	   Enumerator : netsrv.TPInterfaceEnumerator;
	   l : CARDINAL;
	   Maximal, Number : CARD64 := 0;
	   uid : TUId;
	BEGIN
	   IF NOT netsrv.newInterfaceEnumerator( TRUE, FALSE, OUT Enumerator ) THEN
	      RETURN SUPER.UId;
	   END;

      Buffer[0] := 0;
      WHILE Enumerator^.MoveNext() DO
	      IF Enumerator^.Medium = netsrv.medCSMACD THEN
	         Enumerator^.HWAddress( OUT Number, OUT l );
	         IF Number AND 02H = 02H THEN // MAX is localy administered
	            CONTINUE;
	         ELSIF Number AND 0FF00H = 0FF00H THEN // MAC is software (TAP device, ...), no OIU has it
	            CONTINUE;
	         ELSIF Number > Maximal THEN
	            Maximal := Number;
	         END;
	      END;
	   END; // WHILE
	   DISPOSE( Enumerator );

      PCARD64( ADR( Buffer[00] ))^ := Maximal;
      PCARD64( ADR( Buffer[08] ))^ := Maximal;
      PCARD64( ADR( Buffer[16] ))^ := Maximal;
      PCARD64( ADR( Buffer[24] ))^ := Maximal;
		A.Init( Rijndael.cphmECBe, Rijndael.rkl256, _Seed, OA( 0, NIL ));
		A.Encrypt( Buffer, OUT uid, OUT l );

	   RETURN uid;
	END UId;

(*--------------------------------------------------------------------------------*)

	INITIALLY MACSource;
	VAR
	   Enumerator : netsrv.TPInterfaceEnumerator;
	   l : CARDINAL;
	   Number : CARD64 := 0;
	BEGIN
      _Valid := FALSE;
	   IF netsrv.newInterfaceEnumerator( TRUE, FALSE, OUT Enumerator ) THEN
         WHILE Enumerator^.MoveNext() DO
	         IF Enumerator^.Medium = netsrv.medCSMACD THEN
	            Enumerator^.HWAddress( OUT Number, OUT l );
	            IF Number AND 02H = 02H THEN // MAX is localy administered
	               CONTINUE;
	            ELSIF Number AND 0FF00H = 0FF00H THEN // MAC is software (TAP device, ...), no OIU has it
	               CONTINUE;
	            ELSE
	               _Valid := TRUE;
	               EXIT;
	            END;
	         END;
	      END; // WHILE
   	   DISPOSE( Enumerator );
	   END;
	END MACSource;

(*--------------------------------------------------------------------------------*)

END MACSource;

#endif

(*================================================================================*)

END Uniquer.