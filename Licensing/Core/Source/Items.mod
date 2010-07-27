IMPLEMENTATION MODULE Items;

IMPORT
   cphcommon,
   Rijndael,
   SHA256,
   Languages,
   LanguagesO,
   StorageO;

(*================================================================================*)

CONST
   sepItemCh = 10W;
   sepKeyCh = 9W;

   sepVer = StringsO.WCHARS{ L'.' };
   sepKey = StringsO.WCHARS{ sepKeyCh };
   sepItem = StringsO.WCHARS{ sepItemCh };
   
   start = 02W + 02W;
   end = 03W + 03W;
   
   dateFormat = L"yyyy.MM.dd-HH.mm";

TYPE
   TK = ARRAY [0..31] OF BYTE;
CONST
   nk = TK( 08BH, 0BCH, 087H, 038H, 0C9H, 027H, 0D9H, 05DH, 0FEH, 074H, 003H, 0CDH, 029H, 001H, 017H, 0ABH, 02FH, 069H, 01FH, 041H, 054H, 031H, 0CDH, 0FDH, 0F9H, 052H, 013H, 081H, 06DH, 07DH, 0E3H, 0AAH );

TYPE
   TSalt = ARRAY [0..15] OF BYTE;
CONST
   salt = TSalt( 0D8H, 0B1H, 0C2H, 7FH, 0BH, 050H, 04AH, 0C1H, 0BEH, 07AH, 0ACH, 066H, 0F4H, 09CH, 08DH, 0D9H );

(*================================================================================*)

CLASS IMPLEMENTATION CItem;

(*--------------------------------------------------------------------------------*)

   PUBLIC PROPERTY Valid GET : BOOLEAN;
   BEGIN
      RETURN isValid IN State;
   END Valid;

(*--------------------------------------------------------------------------------*)

   PUBLIC PROPERTY IsStub GET : BOOLEAN;
   BEGIN
      RETURN Parent = NIL;
   END IsStub;

(*--------------------------------------------------------------------------------*)

   PUBLIC PROPERTY HasChilds GET : BOOLEAN;
   BEGIN
      RETURN NOT Childs.Empty;
   END HasChilds;

(*--------------------------------------------------------------------------------*)

   PUBLIC PROPERTY Dirty GET : BOOLEAN;
   BEGIN
      RETURN isDirty IN State;
   END Dirty;

(*--------------------------------------------------------------------------------*)

   PUBLIC PROPERTY Dirty SET( Value : BOOLEAN );
   BEGIN
      IF Value THEN
         INCL( State, isDirty );
      ELSE
         EXCL( State, isDirty );
      END;
   END Dirty;

(*--------------------------------------------------------------------------------*)

   PUBLIC PROPERTY ProductId GET : StringsO.CString;
   BEGIN
      RETURN _ProductId;
   END ProductId;

(*--------------------------------------------------------------------------------*)

   PUBLIC PROPERTY ProductId SET( CONST Value : StringsO.CString );
   BEGIN
      State := TItemState{isDirty};
      _ProductId := Value;
   END ProductId;

(*--------------------------------------------------------------------------------*)

   PUBLIC PROPERTY Created GET : time.DateTime;
   BEGIN
      RETURN _Created;
   END Created;

(*--------------------------------------------------------------------------------*)

   PUBLIC PROPERTY Created SET( CONST Value : time.DateTime );
   BEGIN
      State := TItemState{isDirty};
      _Created := Value;
   END Created;

(*--------------------------------------------------------------------------------*)

   PUBLIC PROPERTY TransportData GET : StringsO.CString;
   BEGIN
      RETURN _TransportData;
   END TransportData;

(*--------------------------------------------------------------------------------*)

   PUBLIC PROPERTY TransportData SET( CONST Value : StringsO.CString );
   BEGIN
      State := TItemState{isDirty};
      _TransportData := Value;
   END TransportData;

(*--------------------------------------------------------------------------------*)

   PUBLIC PROPERTY CreatedString GET : StringsO.CString;
   VAR
      s : ARRAY [0..23] OF WCHAR;
      S : StringsO.CString;
   BEGIN
      IF _Created.ToStringOA( dateFormat, TRUE, TRUE, OUT s ) THEN
         S.FromOA( s );
      END;
      RETURN S;
   END CreatedString;

(*--------------------------------------------------------------------------------*)

   PUBLIC PROPERTY CreatedString SET( CONST Value : StringsO.CString );
   BEGIN
      State := TItemState{isDirty};
      IF Value.Empty OR NOT _Created.FromStringOA( OA( Value.Length-1, Value.Data ), dateFormat ) THEN
         _Created.Clear();
      END;
   END CreatedString;

(*--------------------------------------------------------------------------------*)

   INTERNAL PROCEDURE EncodeTransportData();
   TYPE
      TD = POINTER TO SHA256.TDigest;
   VAR
      data : PBYTE;
      digest, dk, di : SHA256.TDigest;
      Hash : StringsO.CString;
      i, len, mlen : CARDINAL;
      M : StorageO.CMemoryBuffer;
      pdigest : TD;
   BEGIN
      CreateHash( OUT Hash );
      len := Hash.Length;
      IF len = 0 THEN
         SHA256.DigestSaltOA( SELF, salt, OUT digest ); // this products undecryptable data
      ELSE
         SHA256.DigestSaltOA( OA( 2*len-1, Hash.Data ), salt, OUT digest );
      END;
      
      LanguagesO.ToMB( _TransportData, Languages.cp_UTF8, FALSE, REF M );
      mlen := M.Length;
      len := mlen AND NOT 31 + 32; // extend source to multiple of 32
      M.Size := len + 32; // reserve extra space for hash
      M.Length := len + 32;
      data := M.Data;
      // clear space data, pad to rijndael modulus
      IF mlen < len THEN
         FOR i := mlen TO len-1 DO
            data@[i]^ :=0;
         END;
      END;

      // hash it
      FOR i := 0 TO HIGH( digest ) DO
         data@[i]^ := data@[i]^ XOR digest[i];
      END;
      // crypt it
      SHA256.DigestOA( nk, OUT dk );
      SHA256.DigestOA( digest, OUT di );
      Rijndael.Encrypt( Rijndael.cphmBlockEncrypt, Rijndael.rkl256, dk, di, OA( len-1, data ), OUT OA( len-1, data ), OUT len );
      
      // add transport digest
      pdigest := TD( M.Data@[len] );
      SHA256.DigestSaltOA( OA( len-1, data ), salt, OUT pdigest^ );
      INC( len, 32 );
      
      i := cphcommon.BASE64CharCount( len );
      _TransportData.Size := i;
      _TransportData.Length := i;
      data := PBYTE( _TransportData.Data );
      cphcommon.ToBASE64( OA( len-1, M.Data ), OUT OA( i-1, PWCHAR( data )));
   END EncodeTransportData;

(*--------------------------------------------------------------------------------*)

   INTERNAL PROCEDURE DecodeTransportData( OUT Decoded : StringsO.CString ) : BOOLEAN;
   TYPE
      TD = POINTER TO SHA256.TDigest;
   VAR
      data : PBYTE;
      digest, dk, di : SHA256.TDigest;
      Hash : StringsO.CString;
      i, len : CARDINAL;
      M : StorageO.CMemoryBuffer;
   BEGIN
      len := _TransportData.Length;
      IF len = 0 THEN
         RETURN FALSE;
      END;
      i := cphcommon.BASE64ByteCount( len );
      M.Size := i;
      M.Length := i;
      data := M.Data;
      IF NOT cphcommon.FromBASE64( OA( len-1, _TransportData.Data ), OUT OA( i-1, data ), OUT len ) THEN
         RETURN FALSE;
      END;
      
      // check transport digest
      DEC( len, 32 );
      SHA256.DigestSaltOA( OA( len-1, data ), salt, OUT digest );
      IF digest <> TD( data@[len] )^ THEN
         RETURN FALSE;
      END;
      
      CreateHash( OUT Hash );
      i := Hash.Length;
      IF i = 0 THEN
         RETURN FALSE;
      ELSE
         SHA256.DigestSaltOA( OA( 2*i-1, Hash.Data ), salt, OUT digest );
      END;

      // uncrypt it
      SHA256.DigestOA( nk, OUT dk );
      SHA256.DigestOA( digest, OUT di );
      IF NOT Rijndael.Decrypt( Rijndael.cphmBlockDecrypt, Rijndael.rkl256, dk, di, OA( len-1, data ), OUT OA( len-1, data ), OUT len ) THEN
         RETURN FALSE;
      END;
      // unhash it
      FOR i := 0 TO HIGH( digest ) DO
         data@[i]^ := data@[i]^ XOR digest[i];
      END;

      LanguagesO.FromMB( M, Languages.cp_UTF8, OUT Decoded );
      RETURN Decoded.StartsWithOA( start ) AND Decoded.EndsWithOA( end );
   END DecodeTransportData;

(*--------------------------------------------------------------------------------*)

BEGIN
   Parent := NIL;
END CItem;

(*================================================================================*)

CLASS IMPLEMENTATION CProduct;

(*--------------------------------------------------------------------------------*)

   PUBLIC PROPERTY Name GET : StringsO.CString;
   BEGIN
      RETURN _Name;
   END Name;

(*--------------------------------------------------------------------------------*)

   PUBLIC PROPERTY Name SET( CONST Value : StringsO.CString );
   BEGIN
      State := TItemState{isDirty};
      _Name := Value;
   END Name;

(*--------------------------------------------------------------------------------*)

   PUBLIC PROPERTY Version GET : TVersion;
   BEGIN
      RETURN _Version;
   END Version;

(*--------------------------------------------------------------------------------*)

   PUBLIC PROPERTY Version SET( CONST Value : TVersion );
   BEGIN
      State := TItemState{isDirty};
      _Version := Value;
   END Version;

(*--------------------------------------------------------------------------------*)

   PUBLIC PROPERTY VersionString GET : StringsO.CString;
   VAR
      S, LS : StringsO.CString;
   BEGIN
      S.FromCARD32( _Version[ viMajor ], 10 );
      S.AppendOA( L"." );

      LS.FromCARD32( _Version[ viMinor ], 10 );
      S.Append( LS );
      S.AppendOA( L"." );

      LS.FromCARD32( _Version[ viBuild ], 10 );
      S.Append( LS );
      S.AppendOA( L"." );

      LS.FromCARD32( _Version[ viPatch ], 10 );
      S.Append( LS );

      RETURN S;
   END VersionString;

(*--------------------------------------------------------------------------------*)

   PUBLIC PROPERTY VersionString SET( CONST Value : StringsO.CString );
   VAR
      l : CARDINAL;
      LS : ARRAY TVersionItem OF StringsO.CString;
      vi : TVersionItem;
   BEGIN
      State := TItemState{isDirty};
      Value.SplitS( sepVer, 0, FALSE, OUT l, OUT LS );
      FOR vi := viMajor TO viPatch DO
         IF NOT LS[vi].ToCARD32( 10, OUT _Version[vi] ) THEN
            _Version[viMajor] := 0;
            _Version[viMinor] := 0;
            _Version[viBuild] := 0;
            _Version[viPatch] := 0;
            RETURN;
         END;
      END;
   END VersionString;

(*--------------------------------------------------------------------------------*)

   PUBLIC PROPERTY Copyright GET : StringsO.CString;
   BEGIN
      RETURN _Copyright;
   END Copyright;

(*--------------------------------------------------------------------------------*)

   PUBLIC PROPERTY Copyright SET( CONST Value : StringsO.CString );
   BEGIN
      State := TItemState{isDirty};
      _Copyright := Value;
   END Copyright;

(*--------------------------------------------------------------------------------*)

   PUBLIC PROPERTY Legal GET : StringsO.CString;
   BEGIN
      RETURN _Legal;
   END Legal;

(*--------------------------------------------------------------------------------*)

   PUBLIC PROPERTY Legal SET( CONST Value : StringsO.CString );
   BEGIN
      State := TItemState{isDirty};
      _Legal := Value;
   END Legal;

(*--------------------------------------------------------------------------------*)

   PUBLIC PROPERTY Note GET : StringsO.CString;
   BEGIN
      RETURN _Note;
   END Note;

(*--------------------------------------------------------------------------------*)

   PUBLIC PROPERTY Note SET( CONST Value : StringsO.CString );
   BEGIN
      State := TItemState{isDirty};
      _Note := Value;
   END Note;

(*--------------------------------------------------------------------------------*)

   PUBLIC PROPERTY LicencesAndInfos GET : lists.TPPtrList;
   BEGIN
      RETURN ADR( Childs );
   END LicencesAndInfos;

(*--------------------------------------------------------------------------------*)

   PUBLIC VIRTUAL PROCEDURE Equals( CONST To : CItem ) : BOOLEAN;
   BEGIN
      RETURN ( To IS CProduct ) AND
             ( _ProductId = To.ProductId ) AND
             ( _Version[viMajor] = Items.TPProduct( ADR( To ))^.Version[viMajor] ) AND
             ( _Version[viMinor] = Items.TPProduct( ADR( To ))^.Version[viMinor] );
   END Equals;

(*--------------------------------------------------------------------------------*)

   PUBLIC PROCEDURE AddLicenceOrInfo( Item : TPItem );
   BEGIN
      Childs.Add( Item, 0 );
      Item^.Parent := ADR( SELF );
   END AddLicenceOrInfo;

(*--------------------------------------------------------------------------------*)

   PUBLIC PROCEDURE RemoveLicenceOrInfo( Item : TPItem );
   BEGIN
      Childs.Remove( Item );
      Item^.Parent := NIL;
   END RemoveLicenceOrInfo;

(*--------------------------------------------------------------------------------*)

   PUBLIC VIRTUAL PROCEDURE CreateTransportData(); // prepares Data
   BEGIN
      IF isDirty NOT IN State THEN
         RETURN;
      END;

      _TransportData.FromOA( start +
                               sepItemCh + L"pid" + sepKeyCh );
      _TransportData.Append( _ProductId );

      _TransportData.AppendOA( sepItemCh + L"nam" + sepKeyCh );
      _TransportData.Append( _Name );
      
      _TransportData.AppendOA( sepItemCh + L"ver" + sepKeyCh );
      _TransportData.Append( VersionString );

      _TransportData.AppendOA( sepItemCh + L"(c)" + sepKeyCh );
      _TransportData.Append( _Copyright );

      _TransportData.AppendOA( sepItemCh + L"leg" + sepKeyCh );
      _TransportData.Append( _Legal );

      _TransportData.AppendOA( sepItemCh + L"not" + sepKeyCh );
      _TransportData.Append( _Note );

      _TransportData.AppendOA( sepItemCh + end );

      EncodeTransportData();
      State := TItemState{isValid};
   END CreateTransportData;

(*--------------------------------------------------------------------------------*)

   PUBLIC VIRTUAL PROCEDURE ValidateByTransportData();
   VAR
      l : CARDINAL;
      LS : ARRAY [0..6] OF StringsO.CString;
      S, td : StringsO.CString;
   BEGIN
      EXCL( State, isValid );
      IF NOT DecodeTransportData( OUT td ) THEN
         RETURN;
      END;
   
      td.SplitS( sepItem, 0, FALSE, OUT l, OUT LS );

      // check
      LS[1].ItemS( sepKey, 0, 1, TRUE, OUT S );
      IF S <> _ProductId THEN
         RETURN;
      END;
      // check
      LS[2].ItemS( sepKey, 0, 1, FALSE, OUT S );
      IF S <> _Name THEN
         RETURN;
      END;
      // check
      LS[3].ItemS( sepKey, 0, 1, FALSE, OUT S );
      IF S <> VersionString THEN
         RETURN;
      END;
      // check
      LS[4].ItemS( sepKey, 0, 1, FALSE, OUT S );
      IF S <> _Copyright THEN
         RETURN;
      END;
      // check
      LS[5].ItemS( sepKey, 0, 1, FALSE, OUT S );
      IF S <> _Legal THEN
         RETURN;
      END;
      // check
      LS[6].ItemS( sepKey, 0, 1, FALSE, OUT S );
      IF S <> _Note THEN
         RETURN;
      END;

      INCL( State, isValid );
   END ValidateByTransportData;

(*--------------------------------------------------------------------------------*)

   INTERNAL VIRTUAL PROCEDURE CreateHash( OUT Hash : StringsO.CString );
   BEGIN
      Hash.Assign( _ProductId ); Hash.AppendOA( sepItemCh );
      Hash.Append( _Name ); Hash.AppendOA( sepItemCh );
      Hash.Append( VersionString ); Hash.AppendOA( sepItemCh );
      Hash.Append( _Copyright ); Hash.AppendOA( sepItemCh );
      Hash.Append( _Legal ); Hash.AppendOA( sepItemCh );
      Hash.Append( _Note );
   END CreateHash;

(*--------------------------------------------------------------------------------*)

BEGIN
   _Version[viMajor] := 0;
   _Version[viMinor] := 0;
   _Version[viBuild] := 0;
   _Version[viPatch] := 0;
END CProduct;

(*================================================================================*)

CLASS IMPLEMENTATION CLockedItem;

(*--------------------------------------------------------------------------------*)

   INTERNAL PROPERTY UIdString GET : StringsO.CString;
   VAR
      a : PWCHAR;
      c : CARDINAL;
      s : StringsO.CString;
   BEGIN
      c := cphcommon.BASE64CharCount( SIZE( Uniquer.TUId ));
      s.Size := c;
      s.Length := c;
      a := s.Data;
      cphcommon.ToBASE64( UId, OUT OA( s.Length-1, a ));
      RETURN s;
   END UIdString;

(*--------------------------------------------------------------------------------*)

   INTERNAL PROPERTY UIdString SET( CONST Value : StringsO.CString );
   VAR
      c : CARDINAL;
   BEGIN
      UId[0] := 0;
      IF Value.Length <> cphcommon.BASE64CharCount( SIZE( Uniquer.TUId )) THEN
         RETURN;
      END;
      cphcommon.FromBASE64( OA( Value.Length-1, Value.Data ), OUT UId, OUT c );
   END UIdString;

(*--------------------------------------------------------------------------------*)

BEGIN
   UId[0] := 0;
END CLockedItem;

(*================================================================================*)

CLASS IMPLEMENTATION CLicence;

(*--------------------------------------------------------------------------------*)

   INTERNAL PROPERTY TypeString GET : StringsO.CString;
   VAR
      s : StringsO.CString;
   BEGIN
      s.Size := 4;
      s.Length := 4;
      IF ltUnnamed IN Type THEN
         s[0] := L'-';
      ELSE
         s[0] := L'N';
      END;
      IF ltUpgrade IN Type THEN
         s[1] := L'U';
      ELSE
         s[1] := L'-';
      END;
      IF ltEducational IN Type THEN
         s[2] := L'E';
      ELSE
         s[2] := L'-';
      END;
      IF ltTrial IN Type THEN
         s[3] := L'T';
      ELSE
         s[3] := L'-';
      END;
      RETURN s;
   END TypeString;

(*--------------------------------------------------------------------------------*)

   INTERNAL PROPERTY TypeString SET( CONST Value : StringsO.CString );
   BEGIN
      Type := TLicenceType{};
      IF Value.Length < 4 THEN
         RETURN;
      END;

      IF Value[0] = L'-' THEN
         INCL( Type, ltUnnamed );
      END;
      IF Value[1] = L'U' THEN
         INCL( Type, ltUpgrade );
      END;
      IF Value[2] = L'E' THEN
         INCL( Type, ltEducational );
      END;
      IF Value[3] = L'T' THEN
         INCL( Type, ltTrial );
      END;
      // not to set dirty, this is internal
   END TypeString;

(*--------------------------------------------------------------------------------*)

   PUBLIC PROPERTY Serial GET : StringsO.CString;
   BEGIN
      RETURN _Serial;
   END Serial;

(*--------------------------------------------------------------------------------*)

   PUBLIC PROPERTY Serial SET( CONST Value : StringsO.CString );
   BEGIN
      State := TItemState{isDirty};
      _Serial := Value;
   END Serial;

(*--------------------------------------------------------------------------------*)

   PUBLIC PROPERTY Owner GET : StringsO.CString;
   BEGIN
      RETURN _Owner;
   END Owner;

(*--------------------------------------------------------------------------------*)

   PUBLIC PROPERTY Owner SET( CONST Value : StringsO.CString );
   BEGIN
      State := TItemState{isDirty};
      _Owner := Value;
   END Owner;

(*--------------------------------------------------------------------------------*)

   PUBLIC PROPERTY Type GET : TLicenceType;
   BEGIN
      RETURN _Type;
   END Type;

(*--------------------------------------------------------------------------------*)

   PUBLIC PROPERTY Type SET( Value : TLicenceType );
   BEGIN
      State := TItemState{isDirty};
      _Type := Value;
   END Type;

(*--------------------------------------------------------------------------------*)

   PUBLIC PROPERTY Activations GET : lists.TPPtrList;
   BEGIN
      RETURN ADR( Childs );
   END Activations;

(*--------------------------------------------------------------------------------*)

   PUBLIC VIRTUAL PROCEDURE Equals( CONST To : CItem ) : BOOLEAN;
   BEGIN
      RETURN ( To IS CLicence ) AND
             ( _ProductId = To.ProductId ) AND
             ( _Serial = TPLicence( ADR( To ))^.Serial ) AND
             ( UIdString = TPLicence( ADR( To ))^.UIdString );
   END Equals;

(*--------------------------------------------------------------------------------*)

   PUBLIC PROCEDURE AddActivation( Activation : TPActivation );
   BEGIN
      Childs.Add( Activation, 0 );
      Activation^.Parent := ADR( SELF );
   END AddActivation;

(*--------------------------------------------------------------------------------*)

   PUBLIC PROCEDURE RemoveActivation( Activation : TPActivation );
   BEGIN
      Childs.Remove( Activation );
      Activation^.Parent := NIL;
   END RemoveActivation;

(*--------------------------------------------------------------------------------*)

   PUBLIC VIRTUAL PROCEDURE CreateTransportData(); // prepares Data
   BEGIN
      IF isDirty NOT IN State THEN
         RETURN;
      END;

      _TransportData.FromOA( start +
                               sepItemCh + L"ser" + sepKeyCh );
      _TransportData.Append( _Serial );

      _TransportData.AppendOA( sepItemCh + L"own" + sepKeyCh );
      _TransportData.Append( _Owner );

      _TransportData.AppendOA( sepItemCh + L"crt" + sepKeyCh );
      _TransportData.Append( CreatedString );

      _TransportData.AppendOA( sepItemCh + L"typ" + sepKeyCh );
      _TransportData.Append( TypeString );

      _TransportData.AppendOA( sepItemCh + L"uid" + sepKeyCh );
      _TransportData.Append( UIdString );

      _TransportData.AppendOA( sepItemCh + L"pid" + sepKeyCh );
      _TransportData.Append( _ProductId );

      _TransportData.AppendOA( sepItemCh + end );
      
      EncodeTransportData();
      State := TItemState{isValid};
   END CreateTransportData;

(*--------------------------------------------------------------------------------*)

   PUBLIC VIRTUAL PROCEDURE ValidateByTransportData();
   VAR
      l : CARDINAL;
      LS : ARRAY [0..6] OF StringsO.CString;
      S, td : StringsO.CString;
   BEGIN
      EXCL( State, isValid );
      IF NOT DecodeTransportData( OUT td ) THEN
         RETURN;
      END;

      td.SplitS( sepItem, 0, FALSE, OUT l, OUT LS );

      // check
      LS[1].ItemS( sepKey, 0, 1, FALSE, OUT S );
      IF S <> _Serial THEN
         RETURN;
      END;
      // check
      LS[2].ItemS( sepKey, 0, 1, FALSE, OUT S );
      IF S <> _Owner THEN
         RETURN;
      END;
      // check
      LS[3].ItemS( sepKey, 0, 1, FALSE, OUT S );
      IF S <> CreatedString THEN
         RETURN;
      END;

      // apply
      LS[4].ItemS( sepKey, 0, 1, FALSE, OUT S );
      TypeString := S;
      // apply
      LS[5].ItemS( sepKey, 0, 1, FALSE, OUT S );
      UIdString := S;
      // apply
      LS[6].ItemS( sepKey, 0, 1, FALSE, OUT S );
      _ProductId := S;

      INCL( State, isValid );
   END ValidateByTransportData;

(*--------------------------------------------------------------------------------*)

   INTERNAL VIRTUAL PROCEDURE CreateHash( OUT Hash : StringsO.CString );
   BEGIN
      Hash.Assign( _Serial ); Hash.AppendOA( sepItemCh );
      Hash.Append( _Owner ); Hash.AppendOA( sepItemCh );
      Hash.Append( CreatedString );
   END CreateHash;

(*--------------------------------------------------------------------------------*)

BEGIN
END CLicence;

(*================================================================================*)

CLASS IMPLEMENTATION CActivation;

(*--------------------------------------------------------------------------------*)

   PUBLIC PROPERTY OfSerial GET : StringsO.CString;
   BEGIN
      RETURN _OfSerial;
   END OfSerial;

(*--------------------------------------------------------------------------------*)

   PUBLIC PROPERTY OfSerial SET( CONST Value : StringsO.CString );
   BEGIN
      State := TItemState{isDirty};
      _OfSerial := Value;
   END OfSerial;

(*--------------------------------------------------------------------------------*)

   PUBLIC PROPERTY Starts GET : time.DateTime;
   BEGIN
      RETURN _Starts;
   END Starts;

(*--------------------------------------------------------------------------------*)

   PUBLIC PROPERTY Starts SET( CONST Value : time.DateTime );
   BEGIN
      State := TItemState{isDirty};
      _Starts := Value;
      _Starts.TrimTime();
   END Starts;

(*--------------------------------------------------------------------------------*)

   PUBLIC PROPERTY StartsString GET : StringsO.CString;
   VAR
      s : ARRAY [0..23] OF WCHAR;
      S : StringsO.CString;
   BEGIN
      IF ( _Starts.Year > 0 ) AND _Starts.ToStringOA( dateFormat, TRUE, TRUE, OUT s ) THEN
         S.FromOA( s );
      END;
      RETURN S;
   END StartsString;

(*--------------------------------------------------------------------------------*)

   PUBLIC PROPERTY StartsString SET( CONST Value : StringsO.CString );
   BEGIN
      State := TItemState{isDirty};
      IF Value.Empty OR NOT _Starts.FromStringOA( OA( Value.Length-1, Value.Data ), dateFormat ) THEN
         _Starts.Clear();
      ELSE
         Starts := _Starts;
      END;
   END StartsString;

(*--------------------------------------------------------------------------------*)

   PUBLIC PROPERTY Expires GET : time.DateTime;
   BEGIN
      RETURN _Expires;
   END Expires;

(*--------------------------------------------------------------------------------*)

   PUBLIC PROPERTY Expires SET( CONST Value : time.DateTime );
   BEGIN
      State := TItemState{isDirty};
      _Expires := Value;
      _Expires.TrimTime();
   END Expires;

(*--------------------------------------------------------------------------------*)

   PUBLIC PROPERTY ExpiresString GET : StringsO.CString;
   VAR
      s : ARRAY [0..23] OF WCHAR;
      S : StringsO.CString;
   BEGIN
      IF ( _Expires.Year > 0 ) AND _Expires.ToStringOA( dateFormat, TRUE, TRUE, OUT s ) THEN
         S.FromOA( s );
      END;
      RETURN S;
   END ExpiresString;

(*--------------------------------------------------------------------------------*)

   PUBLIC PROPERTY ExpiresString SET( CONST Value : StringsO.CString );
   BEGIN
      State := TItemState{isDirty};
      IF Value.Empty OR NOT _Expires.FromStringOA( OA( Value.Length-1, Value.Data ), dateFormat ) THEN
         _Expires.Clear();
      ELSE
         Expires := _Expires;
      END;
   END ExpiresString;

(*--------------------------------------------------------------------------------*)

   PUBLIC VIRTUAL PROCEDURE Equals( CONST To : CItem ) : BOOLEAN;
   BEGIN
      RETURN ( To IS CActivation ) AND
             ( _ProductId = To._ProductId ) AND
             ( _OfSerial = TPActivation( ADR( To ))^._OfSerial ) AND
             ( _Starts = TPActivation( ADR( To ))^._Starts ) AND
             ( _Expires = TPActivation( ADR( To ))^._Expires ) AND
             ( UId = TPActivation( ADR( To ))^.UId );
   END Equals;

(*--------------------------------------------------------------------------------*)

   PUBLIC PROCEDURE ValidFor( CONST datetime : time.DateTime ) : BOOLEAN;
   BEGIN
      IF _Starts.Year = 0 THEN
         IF _Expires.Year = 0 THEN
            RETURN TRUE;
         END;
         // only expires
         RETURN _Expires >= datetime;
      ELSIF _Expires.Year = 0 THEN
         // only starts
         RETURN _Starts <= datetime;
      ELSE
         // starts and expires
         RETURN ( _Starts <= datetime ) AND ( _Expires >= datetime );
      END;
   END ValidFor;

(*--------------------------------------------------------------------------------*)

   PUBLIC VIRTUAL PROCEDURE CreateTransportData(); // prepares Data
   BEGIN
      IF isDirty NOT IN State THEN
         RETURN;
      END;

      _TransportData.FromOA( start +
                               sepItemCh + L"ser" + sepKeyCh );
      _TransportData.Append( _OfSerial );

      _TransportData.AppendOA( sepItemCh + L"crt" + sepKeyCh );
      _TransportData.Append( CreatedString );

      _TransportData.AppendOA( sepItemCh + L"beg" + sepKeyCh );
      _TransportData.Append( StartsString );

      _TransportData.AppendOA( sepItemCh + L"exp" + sepKeyCh );
      _TransportData.Append( ExpiresString );

      _TransportData.AppendOA( sepItemCh + L"uid" + sepKeyCh );
      _TransportData.Append( UIdString );

      _TransportData.AppendOA( sepItemCh + L"pid" + sepKeyCh );
      _TransportData.Append( _ProductId );

      _TransportData.AppendOA( sepItemCh + end );

      EncodeTransportData();
      State := TItemState{isValid};
   END CreateTransportData;

(*--------------------------------------------------------------------------------*)

   PUBLIC VIRTUAL PROCEDURE ValidateByTransportData();
   VAR
      l : CARDINAL;
      LS : ARRAY [0..6] OF StringsO.CString;
      S, td : StringsO.CString;
   BEGIN
      EXCL( State, isValid );
      IF NOT DecodeTransportData( OUT td ) THEN
         RETURN;
      END;

      td.SplitS( sepItem, 0, FALSE, OUT l, OUT LS );

      // check
      LS[1].ItemS( sepKey, 0, 1, FALSE, OUT S );
      IF S <> _OfSerial THEN
         RETURN;
      END;
      // check
      LS[2].ItemS( sepKey, 0, 1, FALSE, OUT S );
      IF S <> CreatedString THEN
         RETURN;
      END;
      // check
      LS[3].ItemS( sepKey, 0, 1, FALSE, OUT S );
      IF S <> StartsString THEN
         RETURN;
      END;
      // check
      LS[4].ItemS( sepKey, 0, 1, FALSE, OUT S );
      IF S <> ExpiresString THEN
         RETURN;
      END;

      // apply
      LS[5].ItemS( sepKey, 0, 1, FALSE, OUT S );
      UIdString := S;
      // apply
      LS[6].ItemS( sepKey, 0, 1, FALSE, OUT S );
      _ProductId := S;

      INCL( State, isValid );
   END ValidateByTransportData;

(*--------------------------------------------------------------------------------*)

   INTERNAL VIRTUAL PROCEDURE CreateHash( OUT Hash : StringsO.CString );
   BEGIN
      Hash.Assign( _OfSerial ); Hash.AppendOA( sepItemCh );
      Hash.Append( CreatedString ); Hash.AppendOA( sepItemCh );
      Hash.Append( StartsString ); Hash.AppendOA( sepItemCh );
      Hash.Append( ExpiresString );
   END CreateHash;

(*--------------------------------------------------------------------------------*)

END CActivation;

(*================================================================================*)

CLASS IMPLEMENTATION CInfo;

(*--------------------------------------------------------------------------------*)

   PUBLIC PROPERTY List GET : lists.TPStringStringList;
   BEGIN
      RETURN ADR( _List );
   END List;

(*--------------------------------------------------------------------------------*)

   PUBLIC VIRTUAL PROCEDURE Equals( CONST To : CItem ) : BOOLEAN;
   VAR
      _toList : lists.TPStringStringList;
   BEGIN
      IF NOT( To IS CInfo ) OR ( _ProductId <> To.ProductId ) THEN
         RETURN FALSE;
      END;

      _toList := TPInfo( ADR( To ))^.List;
      _List.Reset();
      _toList^.Reset();
      WHILE _List.MoveNext() AND _toList^.MoveNext() DO
         IF NOT _List.Current^.Equals( _toList^.Current^ ) OR NOT _List.CurrentData^.Equals( _toList^.CurrentData^ ) THEN
            RETURN FALSE;
         END;
      END; // WHILE
      IF _List.MoveNext() OR _toList^.MoveNext() THEN
         RETURN FALSE;
      ELSE
         RETURN TRUE;
      END;
   END Equals;

(*--------------------------------------------------------------------------------*)

   PUBLIC VIRTUAL PROCEDURE CreateTransportData(); // prepares Data, sets Valid
   BEGIN
      IF isDirty NOT IN State THEN
         RETURN;
      END;

      _TransportData.FromOA( start +
                               sepItemCh + L"uid" + sepKeyCh );
      _TransportData.Append( UIdString );

      _TransportData.AppendOA( sepItemCh + L"pid" + sepKeyCh );
      _TransportData.Append( _ProductId );
      
      _List.Reset();
      WHILE _List.MoveNext() DO
         _TransportData.AppendOA( sepItemCh );
         _TransportData.Append( _List.Current^ );
         _TransportData.AppendOA( sepKeyCh );
         _TransportData.Append( _List.CurrentData^ );
      END; // WHILE

      _TransportData.AppendOA( sepItemCh + end );

      EncodeTransportData();
      State := TItemState{isValid};
   END CreateTransportData;

(*--------------------------------------------------------------------------------*)

   PUBLIC VIRTUAL PROCEDURE ValidateByTransportData(); // gets transport data, sets Valid
   VAR
      nextIndex : CARDINAL := 0;
      pieces : CARDINAL;
      s : StringsO.CString;
      sa : ARRAY [0..1] OF StringsO.CString;
      td : StringsO.CString;
   BEGIN
      EXCL( State, isValid );
      IF NOT DecodeTransportData( OUT td ) THEN
         RETURN;
      END;

      // move over SOT
      nextIndex := td.ItemS( sepItem, nextIndex, 0, FALSE, OUT s );
      // data
      nextIndex := td.ItemS( sepItem, nextIndex, 0, FALSE, OUT s );
      IF s.Empty THEN // uid not found
         RETURN; 
      ELSE
         s.ItemS( sepKey, 0, 1, FALSE, OUT s );
         UIdString := s;
      END;

      nextIndex := td.ItemS( sepItem, nextIndex, 0, FALSE, OUT s );
      s.ItemS( sepKey, 0, 1, FALSE, OUT s );
      IF s <> ProductId THEN
         RETURN;
      END;

      _List.Reset();
      WHILE _List.MoveNext() AND ( nextIndex <> -1 ) DO
         nextIndex := td.ItemS( sepItem, nextIndex, 0, FALSE, OUT s );
         s.SplitS( sepKey, 0, FALSE, OUT pieces, OUT sa );
         IF NOT _List.Current^.Equals( sa[0] ) OR ( pieces > 1 ) AND  NOT _List.CurrentData^.Equals( sa[1] ) THEN
            RETURN;
         END;
      END; // WHILE
      
      // get after EOT (at first read EOT, then move next, which sets nextIndex to -1)
      nextIndex := td.ItemS( sepItem, nextIndex, 1, FALSE, OUT s );
      // check if both lists have the same length
      IF _List.MoveNext() OR ( nextIndex <> -1 ) THEN // different lists length
         RETURN;
      END;

      INCL( State, isValid );
   END ValidateByTransportData;

(*--------------------------------------------------------------------------------*)

   INTERNAL VIRTUAL PROCEDURE CreateHash( OUT Hash : StringsO.CString );
   BEGIN
      Hash.Clear();
      _List.Reset();
      WHILE _List.MoveNext() DO
         Hash.Append( _List.Current^ );
         Hash.Append( _List.CurrentData^ );
         Hash.AppendOA( sepItemCh );
      END; // WHILE      
   END CreateHash;
   
(*--------------------------------------------------------------------------------*)

END CInfo;

(*================================================================================*)

END Items.