IMPLEMENTATION MODULE Number;

(*================================================================================*)

IMPORT
	crc,
	datetime,
	hash,
	Rijndael,
	Scrambler,
	SHA256,
	Storage,
	windows;
	
(*================================================================================*)

TYPE
   TSalt = ARRAY [0..15] OF BYTE;
   
CONST
   salt = TSalt( 0ABH, 27H, 0E1H, 56H, 0F5H, 28H, 45H, 0EFH, 0A5H, 49H, 6EH, 0B9H, 7FH, 39H, 1CH, 0D1H );

(*================================================================================*)

TYPE
	T32 = ARRAY [0..31] OF BYTE;

(*--------------------------------------------------------------------------------*)

PROCEDURE Permute( C16 : CARD16; REF K, IV : T32 );
VAR
	C32 : CARD32;
	D : SHA256.CDigest;
	i : CARDINAL;
	pK : PCARD32 := PCARD32( ADR( K ));
	pIV : PCARD32 := PCARD32( ADR( IV ));
	S : SHA256.CSHA256;
BEGIN
   IF DEBUGGED() THEN
      C32 := CARD32( C16 ) << 15 OR CARD32( C16 );
   ELSE
      C32 := CARD32( C16 ) << 16 OR CARD32( C16 );
   END;
	FOR i := 0 TO SIZE( T32 ) DIV SIZE( CARD32 ) - 1 DO
		pK^ := pK^ XOR C32; INC( pK, SIZE( CARD32 ));
		pIV^ := pIV^ XOR C32; INC( pIV, SIZE( CARD32 ));
	END;
	S.Digest( K, OUT D ); D.ToOA( OUT K );
	S.Digest( IV, OUT D ); D.ToOA( OUT IV );
END Permute;

(*================================================================================*)

CLASS IMPLEMENTATION CNumber;

(*--------------------------------------------------------------------------------*)

   PUBLIC PROPERTY GOrd GET : CARDINAL;
   BEGIN
      RETURN _GOrd;
   END GOrd;

(*--------------------------------------------------------------------------------*)

   PUBLIC PROPERTY GOrd SET( Value : CARDINAL );
   BEGIN
      IF Value < 1 << 24 THEN
         _GOrd := Value;
      ELSE
         _GOrd := CARDINAL( datetime.NowHR().Value AND INT64( 0FFFFFFH ));
      END;
   END GOrd;

(*--------------------------------------------------------------------------------*)

	PUBLIC PROPERTY PId GET : Defs.TPID;
	BEGIN
		RETURN _PId;
	END PId;

(*--------------------------------------------------------------------------------*)

	PUBLIC PROPERTY PId SET( CONST Value : Defs.TPID );
	BEGIN
		_PId := Value;
	END PId;

(*--------------------------------------------------------------------------------*)

	PUBLIC PROCEDURE SetPId( CONST PId : StringsO.IString );
	BEGIN
		hash.hashs( OA( PId.Length-1, PId.Data ), OUT _PId );
   END SetPId;

(*--------------------------------------------------------------------------------*)

	PUBLIC PROCEDURE CheckPId( CONST PId : StringsO.IString ) : BOOLEAN;
	VAR
	   lhash : Defs.TPID;
	BEGIN
	   hash.hashs( OA( PId.Length-1, PId.Data ), OUT lhash );
		RETURN _PId = lhash;
	END CheckPId;

(*--------------------------------------------------------------------------------*)

BEGIN
	_PId := Defs.zeroPID;
   _GOrd := CARDINAL( datetime.NowHR().Value AND INT64( 0FFFFFFH ));
END CNumber;

(*================================================================================*)

TYPE
	#save, option( pack => 1 )
	TSerialPacket =	RECORD
	                     PId   : hash.TH40;
								Owner : hash.TH32;
								Type  : BITSET8;
								HOrd  : ARRAY [0..2] OF BYTE;
							END;
	#restore
CONST
	csi = T32(
		08DH, 085H, 0F0H, 0FCH, 0FFH, 0FFH, 050H, 068H, 0FFH, 000H, 000H, 000H, 08BH, 08DH, 0E8H, 0FCH,
		0FFH, 0FFH, 08AH, 011H, 052H, 08DH, 085H, 0F8H, 0FEH, 0FFH, 0FFH, 050H, 08BH, 08DH, 0F4H, 0FEH
	);
	csk = T32(
		08BH, 045H, 008H, 089H, 045H, 0F8H, 083H, 07DH, 0F8H, 000H, 076H, 013H, 083H, 07DH, 0F8H, 003H,
		076H, 002H, 0EBH, 00BH, 08BH, 04DH, 0FCH, 08BH, 055H, 008H, 089H, 051H, 004H, 0EBH, 00AH, 08BH
	);

(*--------------------------------------------------------------------------------*)

CLASS IMPLEMENTATION CSerial;

(*--------------------------------------------------------------------------------*)

	PUBLIC VIRTUAL PROPERTY Prefix GET : StringsO.CString;
	VAR
		p : StringsO.CString;
	BEGIN
		p.FromOA( L"SN" ); RETURN p;
	END Prefix;
	
(*--------------------------------------------------------------------------------*)

	PUBLIC VIRTUAL PROPERTY Separator GET : WCHAR;
	BEGIN
		RETURN '-';
	END Separator;
	
(*--------------------------------------------------------------------------------*)

	PUBLIC VIRTUAL PROPERTY Valid GET : BOOLEAN;
	BEGIN
		RETURN _PId <> Defs.zeroPID;
	END Valid;

(*--------------------------------------------------------------------------------*)

	PUBLIC PROPERTY Owner GET : Defs.TOwner;
	BEGIN
		RETURN _Owner;
	END Owner;

(*--------------------------------------------------------------------------------*)

	PUBLIC VIRTUAL PROCEDURE ToOA( OUT Out : ARRAY OF BYTE; OUT Filled : CARDINAL ) : BOOLEAN;
	VAR
		A : Rijndael.CRijndael;
		c : CARD16;
		d : SHA256.TDigest;
		IV : T32 := csi;
		K : T32 := csk;
		l : CARDINAL;
		P : TSerialPacket;
	BEGIN
		IF NOT Valid THEN
			RETURN FALSE;
		ELSIF SIZE( CARD16 ) + SIZE( TSerialPacket ) > HIGH( Out )+1 THEN
			RETURN FALSE;
		ELSE
			Filled := SIZE( CARD16 ) + SIZE( TSerialPacket );
		END;
		// create packet
		P.PId := _PId;
		P.Type := BITSET8( Type );
		P.Owner := _Owner;
		P.HOrd[0] := BYTE( _GOrd >> 16 );
		P.HOrd[1] := BYTE( _GOrd >> 08 );
		P.HOrd[2] := BYTE( _GOrd >> 00 );

		SHA256.DigestSaltOA( P, salt, OUT d );
		c := crc.crc16( crc.crc16i, d );
		// encrypt packet
		Permute( c, REF K, REF IV );
		A.Init( Rijndael.cphmOFBe, Rijndael.rkl256, K, IV );
		A.Encrypt( P, OUT P, OUT l );

		// fill output
		Out[0] := HIBYTE( c ); Out[1] := LOBYTE( c );
		Storage.Move( ADR( P ), ADR( Out[2] ), SIZE( TSerialPacket ));

		RETURN TRUE;
	END ToOA;

(*--------------------------------------------------------------------------------*)

	PUBLIC VIRTUAL PROCEDURE FromOA( CONST In : ARRAY OF BYTE ) : BOOLEAN;
	VAR
		A : Rijndael.CRijndael;
		c : CARD16;
		d : SHA256.TDigest;
		IV : T32 := csi;
		K : T32 := csk;
		l : CARDINAL;
		P : TSerialPacket;
	BEGIN
		IF SIZE( TSerialPacket ) + SIZE( CARD16 ) <> HIGH( In )+1 THEN
			RETURN FALSE;
		END;
		// grab input
		c := ( CARD16( In[0] ) << 8 ) OR CARD16( In[1] );
		Storage.Move( ADR( In[2] ), ADR( P ), SIZE( TSerialPacket ));
		// decrypt packet
		Permute( c, REF K, REF IV );
		A.Init( Rijndael.cphmOFBd, Rijndael.rkl256, K, IV );
		A.Decrypt( P, OUT P, OUT l );
		SHA256.DigestSaltOA( P, salt, OUT d );
		IF c <> crc.crc16( crc.crc16i, d ) THEN
			RETURN FALSE;
		END;
		// decompose packet
		_PId := P.PId;
		_Owner := P.Owner;
		Type := Items.TLicenceType( P.Type );
		_GOrd := ( CARDINAL( P.HOrd[0] ) << 16 ) OR ( CARDINAL( P.HOrd[1] ) << 8 ) OR CARDINAL( P.HOrd[2] );
		RETURN TRUE;
	END FromOA;
	
(*--------------------------------------------------------------------------------*)

	PUBLIC PROCEDURE SetOwner( CONST Owner : StringsO.IString );
	BEGIN
		hash.hashs( OA( Owner.Length-1, Owner.Data ), OUT _Owner );
	END SetOwner;
	
(*--------------------------------------------------------------------------------*)

	PUBLIC PROCEDURE CheckOwner( CONST Owner : StringsO.IString ) : BOOLEAN;
	VAR
	   lhash : Defs.TOwner;
	BEGIN
		hash.hashs( OA( Owner.Length-1, Owner.Data ), OUT lhash );
		RETURN _Owner = lhash;
	END CheckOwner;

(*--------------------------------------------------------------------------------*)

   INITIALLY CSerial;
   VAR
      owner : StringsO.CString;
   BEGIN
      
	   _Owner := Defs.zeroOwner;
	   Type := Items.TLicenceType{};
	   SetOwner( owner );
	END CSerial;

(*--------------------------------------------------------------------------------*)

END CSerial;

(*================================================================================*)

TYPE
	#save, option( pack => 1 )
	TRegistrationPacket = RECORD
                            PId   : hash.TH40;
                            MId   : hash.TH40;
                            OSVer : ARRAY [0..2] OF BYTE;
                            HOrd  : ARRAY [0..2] OF BYTE;
                         END;
	#restore
CONST
	cri = T32(
		0EBH, 04BH, 047H, 0A1H, 080H, 0BBH, 084H, 0FAH, 07DH, 0A3H, 0EDH, 011H, 0FCH, 01DH, 0E1H, 069H,
		000H, 0E4H, 052H, 08EH, 059H, 044H, 08BH, 057H, 08FH, 01DH, 072H, 0C5H, 0B4H, 0D3H, 0BEH, 000H
	);
	crk = T32(
		0D9H, 0BFH, 079H, 02AH, 0A3H, 097H, 0A5H, 0B8H, 02FH, 00AH, 037H, 052H, 071H, 0F1H, 09BH, 0AAH,
		087H, 06BH, 018H, 0BFH, 097H, 097H, 01AH, 088H, 091H, 007H, 06FH, 02EH, 00BH, 094H, 08CH, 07DH
	);

(*--------------------------------------------------------------------------------*)

CLASS IMPLEMENTATION CRegistration;

(*--------------------------------------------------------------------------------*)

	PUBLIC VIRTUAL PROPERTY Prefix GET : StringsO.CString;
	VAR
		p : StringsO.CString;
	BEGIN
		p.FromOA( L"REG" ); RETURN p;
	END Prefix;
	
(*--------------------------------------------------------------------------------*)

	PUBLIC VIRTUAL PROPERTY Separator GET : WCHAR;
	BEGIN
		RETURN '-';
	END Separator;
	
(*--------------------------------------------------------------------------------*)

	PUBLIC VIRTUAL PROPERTY Valid GET : BOOLEAN;
	BEGIN
		RETURN ( _PId <> Defs.zeroPID ) AND ( _MId <> Defs.zeroMID );
	END Valid;

(*--------------------------------------------------------------------------------*)

	PUBLIC PROPERTY MId GET : Defs.TMID;
	BEGIN
		RETURN _MId;
	END MId;

(*--------------------------------------------------------------------------------*)

	PUBLIC PROPERTY MId SET( CONST Value : Defs.TMID );
	BEGIN
		_MId := Value;
	END MId;

(*--------------------------------------------------------------------------------*)

	PUBLIC VIRTUAL PROCEDURE ToOA( OUT Out : ARRAY OF BYTE; OUT Filled : CARDINAL ) : BOOLEAN;
	VAR
		A : Rijndael.CRijndael;
		c : CARD16;
		d : SHA256.TDigest;
		IV : T32 := cri;
		K : T32 := crk;
		l : CARDINAL;
		P : TRegistrationPacket;
	BEGIN
		IF NOT Valid THEN
			RETURN FALSE;
		ELSIF SIZE( CARD16 ) + SIZE( TRegistrationPacket ) > HIGH( Out )+1 THEN
			RETURN FALSE;
		ELSE
			Filled := SIZE( CARD16 ) + SIZE( TRegistrationPacket );
		END;
		// create packet
		P.PId := _PId;
		P.MId := _MId;
		P.OSVer[0] := BYTE( OSVersion.Platform );
		P.OSVer[1] := BYTE( OSVersion.Major );
		P.OSVer[2] := BYTE( OSVersion.Minor );
		P.HOrd[0] := BYTE( _GOrd >> 16 );
		P.HOrd[1] := BYTE( _GOrd >> 08 );
		P.HOrd[2] := BYTE( _GOrd >> 00 );
		SHA256.DigestSaltOA( P, salt, OUT d );
		c := crc.crc16( crc.crc16i, d );
		// encrypt packet
		Permute( c, REF K, REF IV );
		A.Init( Rijndael.cphmOFBe, Rijndael.rkl256, K, IV );
		A.Encrypt( P, OUT P, OUT l );
		// fill output
		Out[0] := HIBYTE( c ); Out[1] := LOBYTE( c );
		Storage.Move( ADR( P ), ADR( Out[2] ), SIZE( TRegistrationPacket ));
		RETURN TRUE;
	END ToOA;

(*--------------------------------------------------------------------------------*)

	PUBLIC VIRTUAL PROCEDURE FromOA( CONST In : ARRAY OF BYTE ) : BOOLEAN;
	VAR
		A : Rijndael.CRijndael;
		c : CARD16;
		d : SHA256.TDigest;
		IV : T32 := cri;
		K : T32 := crk;
		l : CARDINAL;
		P : TRegistrationPacket;
	BEGIN
		IF SIZE( TRegistrationPacket ) + SIZE( CARD16 ) <> HIGH( In )+1 THEN
			RETURN FALSE;
		END;
		// grab input
		c := ( CARD16( In[0] ) << 8 ) OR CARD16( In[1] );
		Storage.Move( ADR( In[2] ), ADR( P ), SIZE( TRegistrationPacket ));
		// decrypt packet
		Permute( c, REF K, REF IV );
		A.Init( Rijndael.cphmOFBd, Rijndael.rkl256, K, IV );
		A.Decrypt( P, OUT P, OUT l );
		SHA256.DigestSaltOA( P, salt, OUT d );
		IF c <> crc.crc16( crc.crc16i, d ) THEN
			RETURN FALSE;
		END;
		// decompose packet
		_PId := P.PId;
		_MId := P.MId;
		OSVersion.Platform := CARDINAL( P.OSVer[0] );
		OSVersion.Major := CARDINAL( P.OSVer[1] );
		OSVersion.Minor := CARDINAL( P.OSVer[2] );
		_GOrd := ( CARDINAL( P.HOrd[0] ) << 16 ) OR ( CARDINAL( P.HOrd[1] ) << 8 ) OR CARDINAL( P.HOrd[2] );
		RETURN TRUE;
	END FromOA;
	
(*--------------------------------------------------------------------------------*)

	PUBLIC PROCEDURE SetMId( CONST UId : Uniquer.TUId );
	BEGIN
		hash.hashb( UId, OUT _MId );
	END SetMId;
	
(*--------------------------------------------------------------------------------*)

	PUBLIC PROCEDURE SetOSVersionByMachine();
   VAR
      OSVersionInfo : windows.OSVERSIONINFO;
   BEGIN
      OSVersionInfo.dwOSVersionInfoSize := SIZE( OSVersionInfo );
      IF windows.GetVersionEx( ADR( OSVersionInfo )) = windows.True THEN
         OSVersion.Platform := OSVersionInfo.dwPlatformId;
         OSVersion.Major := OSVersionInfo.dwMajorVersion;
         OSVersion.Minor := OSVersionInfo.dwMinorVersion;
      ELSE
         OSVersion.Platform := -1;
         OSVersion.Major := -1;
         OSVersion.Minor := -1;
      END;
	END SetOSVersionByMachine;

(*--------------------------------------------------------------------------------*)

   INITIALLY CRegistration;
   BEGIN
	   _MId := Defs.zeroMID;
	END CRegistration;

(*--------------------------------------------------------------------------------*)

END CRegistration;

(*================================================================================*)

TYPE
	#save, option( pack => 1 )
	TActivationPacket = RECORD
                            PId   : hash.TH40;
                            MId   : hash.TH40;
                            DTo   : CARD16;
                            DTl   : CARD8;
                            HOrd  : ARRAY [0..2] OF BYTE;
                         END;
	#restore
CONST
	cai = T32(
		025H, 001H, 090H, 019H, 0CFH, 0FBH, 0D9H, 099H, 01CH, 0B7H, 068H, 025H, 074H, 08DH, 094H, 05FH,
		030H, 093H, 095H, 042H, 077H, 00DH, 019H, 0B1H, 021H, 0FDH, 000H, 042H, 09CH, 03EH, 00CH, 0A5H
	);
	cak = T32(
		085H, 037H, 01CH, 0A6H, 0E5H, 050H, 014H, 03DH, 0CEH, 028H, 003H, 047H, 01BH, 0DEH, 03AH, 009H,
		0E8H, 0F8H, 077H, 00FH, 0A2H, 033H, 09BH, 04CH, 074H, 078H, 073H, 0D4H, 06CH, 0E7H, 0C1H, 0F3H
	);

(*--------------------------------------------------------------------------------*)

CLASS IMPLEMENTATION CActivation;

(*--------------------------------------------------------------------------------*)

	PUBLIC VIRTUAL PROPERTY Prefix GET : StringsO.CString;
	VAR
		p : StringsO.CString;
	BEGIN
		p.FromOA( L"VAN" ); RETURN p;
	END Prefix;
	
(*--------------------------------------------------------------------------------*)

	PUBLIC VIRTUAL PROPERTY Separator GET : WCHAR;
	BEGIN
		RETURN '-';
	END Separator;
	
(*--------------------------------------------------------------------------------*)

	PUBLIC VIRTUAL PROPERTY Valid GET : BOOLEAN;
	BEGIN
		RETURN ( _PId <> Defs.zeroPID ) AND ( _MId <> Defs.zeroMID );
	END Valid;

(*--------------------------------------------------------------------------------*)

   PUBLIC PROPERTY PId SET( CONST Value : Defs.TPID );
   BEGIN
      _PId := Value;
   END PId;

(*--------------------------------------------------------------------------------*)

	PUBLIC PROPERTY Origin GET : datetime.DateTime;
	CONST
	   sdc = INT64( 2120500080000000 );
	VAR
      dc : datetime.DayCount;
	   dt : datetime.DateTime;
	BEGIN
	   IF ( _Origin = -1 ) OR ( _Origin = 0 ) AND ( _Months = 0 ) THEN // months = 0 solves boundary case, when From is set exactly to SJD
	      // fall down
	   ELSE
         dc.Value := sdc;
	      dt.DayCount := dc + datetime.TimeSpanD( LONGREAL( _Origin ));
	   END;
	   RETURN dt;
	END Origin;

(*--------------------------------------------------------------------------------*)

	PUBLIC PROPERTY Origin SET( CONST Value : datetime.DateTime );
	CONST
	   sdc = INT64( 2120500080000000 );
	VAR
	   d : INTEGER;
      dc : datetime.DayCount;
      ts : datetime.TimeSpan;
	BEGIN
      dc.Value := sdc;
      ts := Value.DayCount.Difference( dc );
	   d := INTEGER( ts.Days );
	   IF d <= 0 THEN
	      _Origin := 0;
	   ELSIF d > MAX( CARD16 ) THEN
	      _Origin := -1;
	      _Months := 0;
	   ELSE
	      _Origin := d;
	   END;
	END Origin;

(*--------------------------------------------------------------------------------*)

   PUBLIC PROPERTY Months GET : CARDINAL;
   BEGIN
      RETURN CARDINAL( _Months );
   END Months;

(*--------------------------------------------------------------------------------*)

   PUBLIC PROPERTY Months SET( Value : CARDINAL );
   BEGIN
      IF Value > MAX( CARD8 ) THEN
         _Months := -1;
      ELSE
         _Months := Value;
      END;
   END Months;

(*--------------------------------------------------------------------------------*)

	PUBLIC PROPERTY MId GET : Defs.TMID;
	BEGIN
		RETURN _MId;
	END MId;

(*--------------------------------------------------------------------------------*)

	PUBLIC PROPERTY MId SET( CONST Value : Defs.TMID );
	BEGIN
		_MId := Value;
	END MId;

(*--------------------------------------------------------------------------------*)

	PUBLIC VIRTUAL PROCEDURE ToOA( OUT Out : ARRAY OF BYTE; OUT Filled : CARDINAL ) : BOOLEAN;
	VAR
		A : Rijndael.CRijndael;
		c : CARD16;
		d : SHA256.TDigest;
		IV : T32 := cai;
		K : T32 := cak;
		l : CARDINAL;
		P : TActivationPacket;
	BEGIN
		IF NOT Valid THEN
			RETURN FALSE;
		ELSIF SIZE( CARD16 ) + SIZE( TActivationPacket ) > HIGH( Out )+1 THEN
			RETURN FALSE;
		ELSE
			Filled := SIZE( CARD16 ) + SIZE( TActivationPacket );
		END;
		// create packet
		P.PId := _PId;
		P.MId := _MId;
		P.DTo := CARD16( _Origin );
		P.DTl := CARD8( _Months );
		P.HOrd[0] := BYTE( _GOrd >> 16 );
		P.HOrd[1] := BYTE( _GOrd >> 08 );
		P.HOrd[2] := BYTE( _GOrd >> 00 );
		SHA256.DigestSaltOA( P, salt, OUT d );
		c := crc.crc16( crc.crc16i, d );
		// encrypt packet
		Permute( c, REF K, REF IV );
		A.Init( Rijndael.cphmOFBe, Rijndael.rkl256, K, IV );
		A.Encrypt( P, OUT P, OUT l );
		// fill output
		Out[0] := HIBYTE( c ); Out[1] := LOBYTE( c );
		Storage.Move( ADR( P ), ADR( Out[2] ), SIZE( TRegistrationPacket ));
		RETURN TRUE;
	END ToOA;

(*--------------------------------------------------------------------------------*)

	PUBLIC VIRTUAL PROCEDURE FromOA( CONST In : ARRAY OF BYTE ) : BOOLEAN;
	VAR
		A : Rijndael.CRijndael;
		c : CARD16;
		d : SHA256.TDigest;
		IV : T32 := cai;
		K : T32 := cak;
		l : CARDINAL;
		P : TActivationPacket;
	BEGIN
		IF SIZE( TActivationPacket ) + SIZE( CARD16 ) <> HIGH( In )+1 THEN
			RETURN FALSE;
		END;
		// grab input
		c := ( CARD16( In[0] ) << 8 ) OR CARD16( In[1] );
		Storage.Move( ADR( In[2] ), ADR( P ), SIZE( TActivationPacket ));
		// decrypt packet
		Permute( c, REF K, REF IV );
		A.Init( Rijndael.cphmOFBd, Rijndael.rkl256, K, IV );
		A.Decrypt( P, OUT P, OUT l );
		SHA256.DigestSaltOA( P, salt, OUT d );
		IF c <> crc.crc16( crc.crc16i, d ) THEN
			RETURN FALSE;
		END;
		// decompose packet
		_PId := P.PId;
		_MId := P.MId;
		IF P.DTo = MAX( CARD16 ) THEN
		   _Origin := -1;
		ELSE
		   _Origin := CARDINAL( P.DTo );
		END;
		IF P.DTl = MAX( CARD8 ) THEN
		   _Months := -1;
		ELSE
		   _Months := CARDINAL( P.DTl );
		END;
		_GOrd := ( CARDINAL( P.HOrd[0] ) << 16 ) OR ( CARDINAL( P.HOrd[1] ) << 8 ) OR CARDINAL( P.HOrd[2] );
		RETURN TRUE;
	END FromOA;
	
(*--------------------------------------------------------------------------------*)

	PUBLIC PROCEDURE CheckMId( CONST UId : Uniquer.TUId ) : BOOLEAN;
	VAR
	   lhash : Defs.TMID;
	BEGIN
		hash.hashb( UId, OUT lhash );
		RETURN _MId = lhash;
	END CheckMId;

(*--------------------------------------------------------------------------------*)

   INITIALLY CActivation;
   BEGIN
	   _MId := Defs.zeroMID;
	END CActivation;

(*--------------------------------------------------------------------------------*)

END CActivation;

(*================================================================================*)

PROCEDURE Code( CONST Number : CNumber; OUT Text : StringsO.IString ) : BOOLEAN;
VAR
	l : CARDINAL;
	p : ARRAY [0..31] OF WCHAR;
	text : ARRAY [0..255] OF WCHAR;
	wb : ARRAY [0..255] OF BYTE;
BEGIN
	Number.Prefix.ToOA( OUT p );
	IF NOT Number.ToOA( OUT wb, OUT l ) THEN
		RETURN FALSE;
	END;
	IF NOT Scrambler.Scramble( OA( l-1, ADR( wb )), p, Number.Separator, OUT text ) THEN
	  RETURN FALSE;
	END;
	Text.FromOA( text );
	RETURN TRUE;
END Code;

(*--------------------------------------------------------------------------------*)

PROCEDURE Decode( CONST Text : StringsO.IString; REF Number : CNumber ) : BOOLEAN;
VAR
	l : CARDINAL;
	p : ARRAY [0..31] OF WCHAR;
	wb : ARRAY [0..255] OF BYTE;
BEGIN
	IF NOT Scrambler.Unscramble( OA( Text.Length-1, Text.Data ), Number.Separator, OUT p, OUT wb, OUT l ) THEN
		RETURN FALSE;
	ELSIF l = 0 THEN
		RETURN FALSE;
	ELSIF NOT Number.Prefix.EqualsIgnoreCaseOA( p ) THEN
		RETURN FALSE;
	END;
	RETURN Number.FromOA( OA( l-1, ADR( wb )));
END Decode;

(*================================================================================*)

END Number.