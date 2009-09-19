MODULE lictool;

FROM Storage IMPORT
   ALLOCATE, DEALLOCATE;

IMPORT
   array,
   arrays,
   cphcommon,
   Defs,
   Engine,
   FIO,
   FIOO,
   FSO,
   hash,
   IOO,
   Items,
   lists,
   Number,
   rijndael,
   sha256,
   store,
   StorageO,
   Strings,
   StringsO,
   TextReader,
   TextWriter,
   Uniquer,
   time;

// target user is set by build system
// CONST
//   Target = L""; data are somehow separated special words: Supervisor, Builder, Licensor, Client

CONST
#if Target #contains L"Supervisor" #then
   Supervisor = TRUE;
   Builder = TRUE;
   Licensor = TRUE;
   Client = TRUE;
#else
   Supervisor = FALSE;
   #if Target #contains L"Builder" #then
      Builder = TRUE;
   #else
      Builder = FALSE;
   #endif
   #if Target #contains L"Licensor" #then
      Licensor = TRUE;
   #else
      Licensor = FALSE;
   #endif
   #if Target #contains L"Client" #then
      Client = TRUE;
   #else
      Client = FALSE;
   #endif
   #if Target #contains L"Activator" #then
      Activator = TRUE;
   #else
      Activator = FALSE;
   #endif
#endif

TYPE
   TOperation = (
      opUnknown
      #if Builder #then
         , opSignProduct
         , opGenerateM2Source
      #endif
      #if Licensor #then
         , opGenerateLicence
         , opRegisterFromCmdLine
         , opRegisterFromFile
      #endif
      #if Client #then
         , opApplyLicenceFromCmdLine // MSI
         , opApplyLicenceFromFile // MSI
         , opRemoveLicenceFromCmdLine // MSI/GUI tool
         , opRemoveLicenceFromFile // MSI/GUI tool
      #endif
      #if Client #or Activator #then
         , opQueryRegistration
         , opApplyActivationFromCmdLine
         , opApplyActivationFromFile
         , opInfo
      #endif
      #if Supervisor #then
         , opProductHash
         , opOwnerHash
         , opMachineHash
      #endif
   );

#if Client #or Activator #then
   TYPE
      TIdentityItem = (
         idDisc,
         idMAC
      );
      TIdentity = SET OF TIdentityItem;
      
   CONST
      idAll = TIdentity{idDisc, idMAC};
#endif   

CONST
   dateFormat = L"yyyy.MM.dd";
  
TYPE
   TPString = POINTER TO ARRAY [0..0] OF WCHAR;
   TPParameters = POINTER TO ARRAY [0..0] OF PWCHAR;

#save, call( convention => cdecl )
PROCEDURE wmain( argc : INTEGER; argp : TPParameters; enpv : TPParameters ) : INTEGER;
#restore
VAR
   args : lists.CStringList;
   count : INTEGER;
   err : TextWriter.TPTextWriter := TextWriter.errout();
   i : INTEGER;
   op : TOperation := opUnknown;
   outputToStdOut : BOOLEAN := FALSE;

   #if Builder #then
      di : FSO.CDirectoryInfo;
      outdir, path, tail : FIO.PathStrW := L"";
      pid : StringsO.CString;
   #endif

   #if Builder #or Client #or Activator #then
      data : arrays.CPtrArray;
      item : Items.TPItem;
      ls : store.CFileStorage;
      lsINI : store.CINIFilter;
   #endif
   
   #if Licensor #then
      expBegin : StringsO.CString;
      expEnd : StringsO.CString;
      flags : ARRAY [0..7] OF WCHAR := L"";
      jd : time.TJD;
      ps : StringsO.TPString;
      s : ARRAY [0..63] OF WCHAR;
   #endif
   
   #if Licensor #or Client #or Activator #then
      an : Number.CActivation;
      dtb : time.DateTime;
      dte : time.DateTime;
      out : TextWriter.TPTextWriter := TextWriter.stdout();
      owner : StringsO.CString;
      pathOrFilter : StringsO.CString;
      rn : Number.CRegistration;
      sn : Number.CSerial;
      sns : lists.CStringList;
      so : StringsO.CString;
   #endif

   #if Client #or Activator #then
      activationItem : Items.TPActivation;
      allFlag : BOOLEAN := FALSE;
      found : BOOLEAN;
      haveSome : BOOLEAN := FALSE;
      identity : TIdentity := TIdentity{idMAC};
      j : INTEGER;
      jlist, klist : lists.TPPtrList;
      licenceItem : Items.TPLicence;
      uid : Uniquer.TUId;
      uq : Uniquer.CUniquer;
      uqDisc : Uniquer.DiscSource;
      uqMAC : Uniquer.MACSource;
      uqNone : Uniquer.NullSource;
      useCommonStorage : BOOLEAN := FALSE;
   #endif

   #if Supervisor #then
      hMID : Defs.TMID;
      hOwner : Defs.TOwner;
      hPID : Defs.TPID;
      showGOrds : BOOLEAN := FALSE;
   #endif

   #if Client #or Licensor #or Activator #then
   PROCEDURE LoadFile( CONST path : StringsO.IString; OUT lines : lists.CStringList ) : CARDINAL;
   VAR
      fs : FIOO.CFileStream;
      tr : TextReader.CTextReader;
      so : StringsO.CString;
   BEGIN
      IF path.Empty THEN
         err^.WriteOA( L'  the file name was not specified', TRUE );
         RETURN 300;
      END;
      lines.Clear();
      TRY
         fs.FromPath( OA( path.Length-1, path.rawData ), FIOO.imOpenRead );
      CATCH e : IOO.CIOException DO
         err^.WriteOA( L'  the file "', FALSE ); err^.Write( path, FALSE ); err^.WriteOA( '" cannot be opened', TRUE );
         err^.WriteOA( L'  ', FALSE ); err^.WriteExc( e, TRUE );
         RETURN 301;
      END;
      so.FromOA( L"//" );
      tr.CommentaryStart := so;
      tr.Stream := ADR( fs );
      WHILE tr.ReadLineS( OUT so ) DO
         IF NOT so.Empty THEN
            lines.Add( so, 0 );
         END;
      END; // WHILE
      fs.Close( FALSE );
      RETURN 0;
   END LoadFile;
   #endif

   #if Client #or Activator #then
   PROCEDURE LoadData( bind, validate : BOOLEAN; OUT data : arrays.CPtrArray );
   BEGIN
      ls.Filters^.Add( ADR( lsINI ), 0 );
      data.Strategy := array.astrgListInArray;

      args.Reset();
      IF useCommonStorage THEN
         // do nothing
      ELSIF args.MoveNext() THEN 
         so.Assign( args.Current^ );
         ls.Path := so;
      ELSE
         ls.SetPathOA( L"." );
      END;

      ls.Load( L"", REF data, FALSE, TRUE );
      err^.WriteOA( L'  found ', FALSE ); err^.WriteINT32( data.Count, 10, FALSE ); err^.WriteOA( L' records', TRUE );

      Engine.Canonize( REF data, L"*", bind, NOT validate, FALSE );
      err^.WriteOA( L'  found ', FALSE ); err^.WriteINT32( data.Count, 10, FALSE ); err^.WriteOA( L' unique records', TRUE );

      IF validate THEN
         Engine.ValidateByUQ( REF data, uq );
         err^.WriteOA( L'  found ', FALSE ); err^.WriteINT32( data.Count, 10, FALSE ); err^.WriteOA( L' valid records', TRUE );
      END;
   END LoadData;
   #endif
   
   #if Builder #then
   PROCEDURE WriteM2Source( CONST owner : StringsO.CString ) : CARDINAL;
   TYPE
      TK = ARRAY [0..31] OF BYTE;
   CONST
      nk = TK( 0F9H, 0FAH, 0C2H, 076H, 080H, 062H, 0D3H, 086H, 009H, 013H, 024H, 090H, 0F4H, 015H, 060H, 0FFH, 00CH, 07BH, 033H, 06DH, 01EH, 0F4H, 0FFH, 0AFH, 090H, 038H, 0E0H, 0C6H, 01BH, 08EH, 04EH, 048H ); // sync this with licool
      ni = TK( 0C7H, 067H, 0D6H, 075H, 06EH, 090H, 048H, 094H, 07DH, 095H, 043H, 0ADH, 069H, 052H, 0B6H, 078H, 04FH, 023H, 07AH, 076H, 046H, 068H, 0BAH, 036H, 079H, 0B1H, 0C6H, 060H, 0FBH, 021H, 03BH, 033H ); // sync this with licool
      xorhPId = Defs.TPID( 0A8H, 011H, 078H, 028H, 03EH ); // sync this with core.Validator
   VAR
      a : ADDRESS;
      dk, di : sha256.TDigest;
      fs : FIOO.CFileStream;
      i : CARDINAL;
      hPId : Defs.TPID;
      mb : StorageO.CMemoryBuffer;
      s : ARRAY [0..31] OF WCHAR;
      tw : TextWriter.CTextWriter;
      anyBit : BOOLEAN := FALSE;
   BEGIN
      tw.Stream := ADR( fs );

      hash.hashs( OA( owner.Length-1, owner.rawData ), OUT hPId );

      cphcommon.ToHex( hPId, OUT s );
      err^.WriteOA( L'  phash "', FALSE ); err^.WriteOA( s, FALSE ); err^.WriteOA( L'"', TRUE );

      FOR i := 0 TO 4 DO
         hPId[i] := hPId[i] XOR xorhPId[i];
      END;
      mb.Size := ( owner.Length >> 3 + 1 ) << 4;
      mb.Length := mb.Size;
      mb.Zero();
      mb.Length := 0;
      mb.AppendOA( OA( owner.Length << 1 - 1, owner.rawData ));
      mb.Length := mb.Size;
      a := mb.Data;

      sha256.DigestOA( nk, OUT dk );
      sha256.DigestOA( ni, OUT di );
      rijndael.Encrypt( rijndael.cphmBlockEncrypt, rijndael.rklDefault, dk, di, OA( mb.Size-1, a ), OUT OA( mb.Size-1, a ), OUT i );

      cphcommon.ToHex( hPId, OUT s );
      err^.WriteOA( L'  phash "', FALSE ); err^.WriteOA( s, FALSE ); err^.WriteOA( L'"', TRUE );

      TRY
         fs.FromPath( L"cllv.def", FIOO.imCreate );
      CATCH e : IOO.CIOException DO
         err^.WriteOA( L'  the file "cllv.def" cannot be created', TRUE );
         err^.WriteOA( L'  ', FALSE ); err^.WriteExc( e, TRUE );
         RETURN 401;
      END;
      
      tw.WriteOA( L"DEFINITION MODULE cllv;", TRUE );
      tw.LineEnd();
      tw.WriteOA( L"CONST", TRUE );
      tw.WriteOA( L"   length = ", FALSE ); Strings.FromCARD32W( mb.Size, 10, OUT s ); tw.WriteOA( s, FALSE ); tw.WriteOA( L";", TRUE );
      tw.LineEnd();
      tw.WriteOA( L"TYPE", TRUE );
      tw.WriteOA( L"   Tdata = ARRAY [0..length-1] OF BYTE;", TRUE );
      tw.LineEnd();
      tw.WriteOA( L"CONST", TRUE );
      tw.WriteOA( L"   data = Tdata(", TRUE );
      
      FOR i := 0 TO mb.Size-1 DO
         IF i > 0 THEN
            tw.WriteOA( L", ", i MOD 16 = 0 );
         END;
         IF i MOD 16 = 0 THEN
            tw.WriteOA( L"      ", FALSE );
         END;
         Strings.FromCARD32W( CARDINAL( mb[i] ), 10, OUT s ); tw.WriteOA( s, FALSE ); 
      END;
      tw.LineEnd();
      tw.WriteOA( L"   );", TRUE );
      tw.LineEnd();
      tw.WriteOA( L"END cllv.", TRUE );

      fs.Close( FALSE );
      err^.WriteOA( L'  the file "cllv.def" was successfully generated', TRUE );

      TRY
         fs.FromPath( L"cllv.mod", FIOO.imCreate );
      CATCH e : IOO.CIOException DO
         err^.WriteOA( L'  the file "cllv.mod" cannot be created', TRUE );
         err^.WriteOA( L'  ', FALSE ); err^.WriteExc( e, TRUE );
         RETURN 402;
      END;

      tw.WriteOA( L"IMPLEMENTATION MODULE cllv;", TRUE );
      tw.LineEnd();
      tw.WriteOA( L"FROM Storage IMPORT", TRUE );
      tw.WriteOA( L"   ALLOCATE, DEALLOCATE;", TRUE );
      tw.LineEnd();
      tw.WriteOA( L"IMPORT", TRUE );
      tw.WriteOA( L"   lec;", TRUE );
      tw.LineEnd();
      tw.WriteOA( L"CLASS CValidator;", TRUE );
      tw.WriteOA( L"   VIRTUAL PROCEDURE query( bit : CARDINAL; OUT value : BOOLEAN );", TRUE );
      tw.WriteOA( L"END CValidator;", TRUE );
      tw.LineEnd();
      tw.WriteOA( L"VAR", TRUE );
      tw.WriteOA( L"   V : CValidator;", TRUE );
      tw.LineEnd();
      tw.WriteOA( L"CLASS IMPLEMENTATION CValidator;", TRUE );
      tw.LineEnd();
      tw.WriteOA( L"   VIRTUAL PROCEDURE query( bit : CARDINAL; OUT value : BOOLEAN );", TRUE );
      tw.WriteOA( L"   BEGIN", TRUE );
      tw.WriteOA( L"      CASE bit OF", TRUE );

      FOR i := 0 TO 39 DO
         IF i IN PBITSET64( ADR( hPId ))^ THEN
            IF anyBit THEN
               tw.WriteOA( L", ", FALSE );
            ELSE
               tw.WriteOA( L"      | ", FALSE );
            END;
            Strings.FromCARD32W( i, 10, OUT s );
            tw.WriteOA( s, FALSE );
            anyBit := TRUE;
         END;
      END; // FOR
      IF anyBit THEN
         tw.WriteOA( L" :", TRUE );
         tw.WriteOA( "         value := TRUE;", TRUE );
      END;
      
      tw.WriteOA( "      ELSE", TRUE );
      tw.WriteOA( "         value := FALSE;", TRUE );
      tw.WriteOA( "      END;", TRUE );
      tw.WriteOA( "   END query;", TRUE );
      tw.LineEnd();
      tw.WriteOA( "END CValidator;", TRUE );
      tw.LineEnd();
      tw.WriteOA( "BEGIN", TRUE );
      tw.WriteOA( "   lec.RegisterValidator( ADR( data ), length, ADR( V ));", TRUE );
      tw.WriteOA( "FINALLY", TRUE );
      tw.WriteOA( "   lec.UnregisterValidator( ADR( data ));", TRUE );
      tw.WriteOA( "END cllv.", TRUE );

      fs.Close( FALSE );
      err^.WriteOA( L'  the file "cllv.mod" was successfully generated', TRUE );

      RETURN 0;
   END WriteM2Source;
   #endif
     
BEGIN
   err^.WriteOA( L"Licence support tool", TRUE );
   err^.WriteOA( L"(c) ", FALSE ); err^.WriteOA( Manufacturer, FALSE ); err^.WriteOA( L" 2009", TRUE );
   err^.LineEnd();

   IF argc < 2 THEN
      err^.WriteOA( L"  missing parameters", TRUE );
      RETURN 100;
   END;

   i := 1;
   LOOP
      IF ( argp^[i]^ = L'/' ) OR ( argp^[i]^ = L'-' ) THEN
         CASE TPString( argp^[i] )^[1] OF
         | 'o' : // common
            outputToStdOut := TRUE;
         #if Client #or Activator #then
         | 'A' :
            op := opApplyActivationFromCmdLine;
            INC( i );
            IF i >= argc THEN
               err^.WriteOA( L'  "A" parameter requires activation number', TRUE );
               RETURN 101;
            END;
            sns.AddOA( OAsz( argp^[i] ), 0 );
         | 'a' :
            op := opApplyActivationFromFile;
            INC( i );
            IF i >= argc THEN
               err^.WriteOA( L'  "a" parameter requires path to file', TRUE );
               RETURN 106;
            END;
            pathOrFilter.FromOA( OAsz( argp^[i] ));
         | 'c' : // common
            useCommonStorage := TRUE;
         | 'C' : // computer identity
            CASE TPString( argp^[i] )^[2] OF
            | 'a' : identity := identity + idAll;
            | 'd' : identity := TIdentity{idDisc};
            | 'm' : identity := TIdentity{idMAC};
            | 'n' : identity := TIdentity{};
            END;
         #endif
         #if Licensor #then
         | 'G' :
            op := opGenerateLicence;
         | 'f' : // suboptions of G
            INC( i );
            IF i >= argc THEN
               err^.WriteOA( L'  "f" parameter requires flags', TRUE );
               RETURN 111;
            END;
            ASSIGN( flags, OAsz( argp^[i] ));
         | 'p' : // suboption of G
            INC( i );
            IF i >= argc THEN
               err^.WriteOA( L'  "p" parameter requires owner', TRUE );
               RETURN 115;
            END;
            owner.FromOA( OAsz( argp^[i] ));
         #endif
         #if Supervisor #then
         | 'h' :
            CASE TPString( argp^[i] )^[2] OF
            | 'o' : op := opOwnerHash;
            | 'm' : op := opMachineHash;
            ELSE
              op := opProductHash;
            END;
            INC( i );
            IF i >= argc THEN
               err^.WriteOA( L'  "h" parameter requires name', TRUE );
               RETURN 113;
            END;
            owner.FromOA( OAsz( argp^[i] ));
         | 'g' : // suboption of I
            showGOrds := TRUE;
         #endif
         #if Client #or Activator #then
         | 'I' :
            op := opInfo;
         #endif
         #if Client #then
         | 'L' :
            op := opApplyLicenceFromCmdLine;
            INC( i );
            IF i >= argc THEN
               err^.WriteOA( L'  "L" parameter requires licence number', TRUE );
               RETURN 102;
            END;
            sns.AddOA( OAsz( argp^[i] ), 0 );
         | 'l' :
            op := opApplyLicenceFromFile;
            INC( i );
            IF i >= argc THEN
               err^.WriteOA( L'  "l" parameter requires path to file', TRUE );
               RETURN 114;
            END;
            pathOrFilter.FromOA( OAsz( argp^[i] ));
         #endif
         #if Builder #then
         | 'M' :
            op := opGenerateM2Source;
            INC( i );
            IF i >= argc THEN
               err^.WriteOA( L'  "M" parameter requires product identifier', TRUE );
               RETURN 113;
            END;
            pid.FromOA( OAsz( argp^[i] ));
         #endif
         #if Client #or Activator #then
         | 'Q' :
            op := opQueryRegistration;
            INC( i );
            IF i >= argc THEN
               err^.WriteOA( L'  "Q" parameter requires product identifier', TRUE );
               RETURN 103;
            END;
            pathOrFilter.FromOA( OAsz( argp^[i] ));
         | 'x' : // suboption of Q
            allFlag := TRUE;
         #endif
         #if Licensor #then
         | 'R' :
            op := opRegisterFromCmdLine;
            INC( i );
            IF i >= argc THEN
               err^.WriteOA( L'  "R" parameter requires registration number', TRUE );
               RETURN 104;
            END;
            sns.AddOA( OAsz( argp^[i] ), 0 );
         | 'r' :
            op := opRegisterFromFile;
            INC( i );
            IF i >= argc THEN
               err^.WriteOA( L'  "r" parameter requires path to file', TRUE );
               RETURN 116;
            END;
            pathOrFilter.FromOA( OAsz( argp^[i] ));
         | 'b' : // suboption of R/r
            INC( i );
            IF i >= argc THEN
               err^.WriteOA( L'  "b" parameter requires date', TRUE );
               RETURN 107;
            END;
            expBegin.FromOA( OAsz( argp^[i] ));
         | 'e' : // suboption of R/r
            INC( i );
            IF i >= argc THEN
               err^.WriteOA( L'  "e" parameter requires date', TRUE );
               RETURN 110;
            END;
            expEnd.FromOA( OAsz( argp^[i] ));
         #endif
         #if Builder #then
         | 'S' :
            op := opSignProduct;
         | 'd' : // suboption of S
            INC( i );
            IF i >= argc THEN
               err^.WriteOA( L'  "d" requires directory path', TRUE );
               RETURN 108;
            END;
            ASSIGN( outdir, OAsz( argp^[i] ));
            Strings.TrimW( REF outdir );
            IF outdir[0] = 0W THEN
               err^.WriteOA( L'  bad output directory', TRUE );
               RETURN 109;
            END;
         #endif
         #if Client #then
         | 'U' :
            op := opRemoveLicenceFromCmdLine;
            INC( i );
            IF i >= argc THEN
               err^.WriteOA( L'  "U" parameter requires licence number', TRUE );
               RETURN 105;
            END;
            sns.AddOA( OAsz( argp^[i] ), 0 );
         | 'u' :
            op := opRemoveLicenceFromFile;
            INC( i );
            IF i >= argc THEN
               err^.WriteOA( L'  "u" parameter requires path to file', TRUE );
               RETURN 117;
            END;
            pathOrFilter.FromOA( OAsz( argp^[i] ));
         #endif
         ELSE
            err^.WriteOA( L'  unknown option: ', FALSE ); err^.WriteOA( OAsz( argp^[i] ), TRUE );
            RETURN 118;
         END;
      ELSE // paths
         args.AddOA( OAsz( argp^[i] ), 0 );
      END;

      INC( i );
      IF i >= argc THEN
         EXIT;
      END;
   END; // LOOP

   #if Client #or Activator #then
      IF idDisc IN identity THEN
         uq.Sources^.Add( ADR( uqDisc ), 0 );
      END;
      IF idMAC IN identity THEN
         uq.Sources^.Add( ADR( uqMAC ), 0 );
      END;
      IF identity = TIdentity{} THEN
         uq.Sources^.Add( ADR( uqNone ), 0 );
      END;
   #endif
   
   CASE op OF
   //-----
   | opUnknown :
      err^.WriteOA( L'  unknown operation mode', TRUE );
      RETURN 200;
   
   #if Builder #then
   //-----
   | opSignProduct :
      ls.Filters^.Add( ADR( lsINI ), 0 );
      IF args.Empty THEN
         args.AddOA( L".", 0 );
      END;
   
      args.Reset();
      WHILE args.MoveNext() DO
         IF NOT di.StartFromPath( args.Current^, FSO.soTopDirectoryOnly, FALSE, TRUE ) THEN
            err^.WriteOA( L'  nothing found for "', FALSE ); err^.Write( args.Current^, FALSE ); err^.WriteOA( L'"', TRUE );
            CONTINUE;
         END;
         REPEAT
         
            CASE op OF
            | opSignProduct :
               TRY
                  err^.WriteOA( L'  processing "', FALSE ); err^.Write( di.Path, FALSE ); err^.WriteOA( L'"', TRUE );

                  IF ls.LoadSingleFile( di.Path, REF data, TRUE, FALSE ) THEN
                     count := 0;
                     FOR i := 0 TO data.Count-1 DO
                        item := Items.TPItem( data[i] );
                        IF NOT item^.Valid AND ( item^ IS Items.CProduct ) THEN
                           err^.WriteOA( L'    found "', FALSE ); err^.Write( item^.ProductId, FALSE ); err^.WriteOA( L'"', TRUE );

                           item^.Dirty := TRUE;
                           INC( count );
                        END;
                     END; // FOR loaded items

                     err^.WriteOA( L'    total ', FALSE ); err^.WriteINT32( count, 10, FALSE ); err^.WriteOA( L' products', TRUE );
                     err^.LineEnd();

                     di.Path.ToOA( OUT path );
                     IF outdir[0] <> 0W THEN // do operation in place
                        FIO.PathTailW( path, OUT tail );
                        FIO.MakePathW( outdir, tail, OUT path );
                     END;
                     ls.StoreSingleFileOA( path, data );

                  ELSE
                     err^.WriteOA( L'    total 0 products', TRUE );
                     err^.LineEnd();
                  END;

               CATCH e : IOO.CIOException DO
                  err^.WriteOA( L'  error processing of ', FALSE ); err^.Write( di.Path, TRUE );
                  err^.WriteOA( L'  ', FALSE ); err^.WriteExc( e, TRUE );
               END;
            END;

         UNTIL NOT di.MoveNext(); // REPEAT found files
      END; // WHILE args
   #endif

   #if Licensor #then
   //-----
   | opGenerateLicence :
      args.Reset();

      IF NOT args.MoveNext() THEN
         err^.WriteOA( L'  expected gord', TRUE );
         RETURN 201;
      END;
      ps := args.Current;
      IF NOT ps^.ToCARD32( 10, OUT i ) THEN
         err^.WriteOA( L'  bad gord: ', FALSE ); err^.Write( ps^, TRUE );
         RETURN 202;
      END;
      IF i >= 1<<24 THEN
         err^.WriteOA( L'  bad gord: ', FALSE ); err^.Write( ps^, TRUE );
         RETURN 203;
      ELSE
         sn.GOrd := i;
      END;

      IF NOT args.MoveNext() THEN
         err^.WriteOA( L'  expected product', TRUE );
         RETURN 204;
      END;
      sn.SetPId( args.Current^ );

      IF owner.Empty THEN
         sn.Type := Items.TLicenceType{Items.ltUnnamed};
      ELSE
         sn.SetOwner( owner );
      END;

      i := 0;
      WHILE INSIDE( i, flags ) DO
         CASE flags[i] OF
         | 'U' : INCL( sn.Type, Items.ltUpgrade );
         | 'E' : INCL( sn.Type, Items.ltEducational );
         | 'T' : INCL( sn.Type, Items.ltTrial );
         ELSE
            err^.WriteOA( L'  unknown flag: ', FALSE ); err^.WriteOA( flags[i], TRUE );
            RETURN 205;
         END;
         INC( i );
      END; // WHILE

      Number.Code( sn, OUT so );
      IF outputToStdOut THEN
         out^.Write( so, TRUE );
      END;
      err^.WriteOA( L'  licence number: ', FALSE );
         err^.Write( so, FALSE );
         IF Items.ltUnnamed IN sn.Type THEN
            err^.WriteOA( L"/-", FALSE );
         ELSE
            err^.WriteOA( L"/N", FALSE );
         END;
         err^.WriteOA( flags, FALSE );
      err^.LineEnd();
   #endif

   #if Client #then
   //-----
   | opApplyLicenceFromCmdLine, opApplyLicenceFromFile :

      // check file
      IF op = opApplyLicenceFromFile THEN
         i := LoadFile( pathOrFilter, OUT sns );
         IF i <> 0 THEN
            RETURN i;
         END;
      END; // IF read from file
      IF sns.Empty THEN
         err^.WriteOA( L'  no licence number was found', TRUE );
         RETURN 206;
      END;
      
      LoadData( FALSE, FALSE, OUT data );
   
      sns.Reset();
      WHILE sns.MoveNext() DO
         err^.LineEnd();

         // get current licence
         err^.WriteOA( L'  processing licence "', FALSE ); err^.Write( sns.Current^, FALSE ); err^.WriteOA( L'"', TRUE );
         IF NOT Number.Decode( sns.Current^, REF sn ) THEN
            err^.WriteOA( L'    the licence is not valid', TRUE );
            CONTINUE;
         ELSIF Items.ltUnnamed IN sn.Type THEN
            // fall down
         ELSIF owner.Empty THEN
            err^.WriteOA( L'    the licence owner is not specified', TRUE );
            CONTINUE;
         ELSIF NOT sn.CheckOwner( owner ) THEN
            err^.WriteOA( L'    the specified licence owner is bad', TRUE );
            CONTINUE;
         END; 
         
         licenceItem := NIL;
         i := 0;
         count := data.Count;
         WHILE i < count DO
            item := Items.TPItem( data[i] );
            IF sn.CheckPId( item^.ProductId ) THEN
               IF item^ IS Items.CProduct THEN // apply
                  err^.WriteOA( L'  processing product "', FALSE ); err^.Write( item^.ProductId, FALSE ); err^.WriteOA( L'"', TRUE );

                  NEW( licenceItem );
                  licenceItem^.ProductId := item^.ProductId;
                  licenceItem^.Type := sn.Type;
                  licenceItem^.Created := time.NowUTC();
                  so.Assign( sns.Current^ );
                  licenceItem^.Serial := so;
                  licenceItem^.Owner := owner;
                  licenceItem^.UId := uq.UId( licenceItem^.ProductId );
                  data.Add( licenceItem );

               ELSIF item^ IS Items.CLicence THEN // remove now invalid items
                  err^.WriteOA( L'    removing old licence "', FALSE ); err^.Write( Items.TPLicence( item )^.Serial, FALSE );
                  err^.WriteOA( L'"', TRUE );

                  data.RemoveIndex( i );
                  DISPOSE( item );
                  DEC( count );

                  CONTINUE; // skip incrementing i
               END;
            END;

            INC( i );
         END; // WHILE items
         
         IF licenceItem = NIL THEN
            err^.WriteOA( L'  no appropriate product found', TRUE );
         END;

      END; // WHILE sns
      
      ls.Store( data, TRUE );

   //-----
   | opRemoveLicenceFromCmdLine, opRemoveLicenceFromFile :

      // check file
      IF op = opRemoveLicenceFromFile THEN
         i := LoadFile( pathOrFilter, OUT sns );
         IF i <> 0 THEN
            RETURN i;
         END;
      END; // IF read from file
      IF sns.Empty THEN
         err^.WriteOA( L'  no licence number was found', TRUE );
         RETURN 206;
      END;
      
      LoadData( FALSE, FALSE, OUT data );
   
      sns.Reset();
      WHILE sns.MoveNext() DO
         err^.LineEnd();

         // get current licence
         err^.WriteOA( L'  processing licence "', FALSE ); err^.Write( sns.Current^, FALSE ); err^.WriteOA( L'"', TRUE );
         IF NOT Number.Decode( sns.Current^, REF sn ) THEN
            err^.WriteOA( L'    the licence is not valid', TRUE );
            CONTINUE;
         END; 

         found := FALSE;
         i := 0;
         count := data.Count;
         WHILE i < count DO
            item := Items.TPItem( data[i] );
            IF sn.CheckPId( item^.ProductId ) THEN
               IF item^ IS Items.CLicence THEN // remove licence
                  found := TRUE;

                  // prepare number for deregistering
                  Number.Decode( Items.TPLicence( item )^.Serial, REF sn );
                  rn.GOrd := sn.GOrd;
                  rn.SetPId( item^.ProductId );
                  rn.SetMId( uq.UId( item^.ProductId ));
                  rn.SetOSVersionByMachine();
                  Number.Code( rn, OUT so );

                  IF outputToStdOut THEN
                     out^.Write( so, TRUE );
                  END;
                  err^.WriteOA( L'    number to deregister "', FALSE ); err^.Write( so, FALSE ); err^.WriteOA( L'"', TRUE );

                  // remove licence
                  err^.WriteOA( L'    removing licence...', TRUE );

                  data.RemoveIndex( i );
                  DISPOSE( item );
                  DEC( count );
                  CONTINUE; // skip incrementing i

               ELSIF item^ IS Items.CActivation THEN
                  err^.WriteOA( L'    removing activation...', TRUE );

                  data.RemoveIndex( i );
                  DISPOSE( item );
                  DEC( count );
                  CONTINUE; // skip incrementing i

               END;
            END;

            INC( i );
         END; // WHILE items
         
         IF NOT found THEN
            err^.WriteOA( L'  no appropriate licence found', TRUE );
         END;
      END; // WHILE sns
      
      ls.Store( data, FALSE );

   | opQueryRegistration :
      IF pathOrFilter.Empty THEN
         err^.WriteOA( L'  the product name was not specified', TRUE );
         RETURN 207;
      END;

      LoadData( TRUE, TRUE, OUT data );
      count := 0;

      FOR i := 0 TO data.Count-1 DO
         item := Items.TPItem( data[i] );
         IF NOT( item^ IS Items.CLicence ) THEN
            CONTINUE;
         ELSIF NOT item^.ProductId.Match( pathOrFilter, TRUE ) THEN
            CONTINUE;
         ELSIF NOT item^.HasChilds OR allFlag THEN
            INC( count );
            Number.Decode( Items.TPLicence( item )^.Serial, REF sn );
         
            err^.LineEnd();
            err^.WriteOA( L'  processing licence "', FALSE ); err^.Write( Items.TPLicence( item )^.Serial, FALSE ); err^.WriteOA( L'"', TRUE );
            err^.WriteOA( L'    for product "', FALSE ); err^.Write( item^.ProductId, FALSE ); err^.WriteOA( L'"', TRUE );

            rn.GOrd := sn.GOrd;
            rn.SetPId( item^.ProductId );
            rn.SetMId( uq.UId( item^.ProductId ));
            rn.SetOSVersionByMachine();
            Number.Code( rn, OUT so );

            IF outputToStdOut THEN
               out^.Write( so, TRUE );
            END;
            err^.WriteOA( L'    registration number "', FALSE ); err^.Write( so, FALSE ); err^.WriteOA( L'"', TRUE );
         END;
      END; // for

      IF count = 0 THEN
         err^.LineEnd();
         err^.WriteOA( L'  no unregistered licence found', TRUE );
      END;
   #endif

   #if Licensor #then
   //-----
   | opRegisterFromCmdLine, opRegisterFromFile :

      // check file
      IF op = opRegisterFromFile THEN
         i := LoadFile( pathOrFilter, OUT sns );
         IF i <> 0 THEN
            RETURN i;
         END;
      END; // IF read from file
      IF sns.Empty THEN
         err^.WriteOA( L'  no registration number was found', TRUE );
         RETURN 208;
      END;

      // common expiration settings
      IF NOT expBegin.Empty AND NOT dtb.FromStringOA( OA( expBegin.Length-1, expBegin.rawData ), dateFormat ) THEN
         err^.WriteOA( L'  the begin date is not valid', TRUE );
         RETURN 209;
      END;
      IF NOT expEnd.Empty THEN
         IF expEnd[0] = L'+' THEN
            expEnd.Remove( 0, 1 );
            IF NOT expEnd.ToCARD32( 10, OUT i ) THEN
               err^.WriteOA( L'  the month count is not valid', TRUE );
               RETURN 210;
            END;
            jd := time.GetCurrentJD() + time.DaysToJDC( i * 31 );
            dte.FromJD( jd, 0, 0 );
         ELSIF NOT dte.FromStringOA( OA( expEnd.Length-1, expEnd.rawData ), dateFormat ) THEN
            err^.WriteOA( L'  the end date is not valid', TRUE );
            RETURN 211;
         END;
      END;
      IF expBegin.Empty THEN
         an.Origin := dte;
         an.Months := 0;
      ELSIF expEnd.Empty THEN
         an.Origin := dtb;
         an.Months := -1;
      ELSE
         jd := MAX2( time.TJD( 2120500080000000 ), dtb.JulianDate ); // 2120500080000000 is minimal origin (see Number.mod)
         i := time.JDCToDays( dte.JulianDate - jd ) DIV 31 + 1;
         dte.FromJD( jd + time.DaysToJDC( i * 31 ), 0, 0 );
         dte.ToStringOA( dateFormat, TRUE, FALSE, OUT s );
         err^.WriteOA( L'  expiration counted to ', FALSE ); err^.WriteOA( s, TRUE );
         an.Origin := dtb; // dtbs sooner than 2120500080000000 are trimmed inside an.Origin.set
         an.Months := i;
      END;

      count := 0;
      sns.Reset();
      WHILE sns.MoveNext() DO
         IF count > 0 THEN
            err^.LineEnd();
         END;

         // get current licence
         err^.WriteOA( L'  processing registration "', FALSE ); err^.Write( sns.Current^, FALSE ); err^.WriteOA( L'"', TRUE );
         IF NOT Number.Decode( sns.Current^, REF rn ) THEN
            err^.WriteOA( L'    the registration is not valid', TRUE );
            CONTINUE;
         END;
         
         an.GOrd := rn.GOrd;
         an.PId := rn.PId;
         an.MId := rn.MId;
         // expirations already set
         Number.Code( an, OUT so );

         IF outputToStdOut THEN
            out^.Write( so, TRUE );
         END;
         err^.WriteOA( L'    activation number "', FALSE ); err^.Write( so, FALSE ); err^.WriteOA( L'"', TRUE );
         
         INC( count );
      END; // WHILE sns
   #endif

   #if Client #or Activator #then
   //-----
   | opApplyActivationFromCmdLine, opApplyActivationFromFile :

      // check file
      IF op = opApplyActivationFromFile THEN
         i := LoadFile( pathOrFilter, OUT sns );
         IF i <> 0 THEN
            RETURN i;
         END;
      END; // IF read from file
      IF sns.Empty THEN
         err^.WriteOA( L'  no activation number was found', TRUE );
         RETURN 212;
      END;
      
      LoadData( TRUE, TRUE, OUT data );
   
      sns.Reset();
      WHILE sns.MoveNext() DO
         err^.LineEnd();

         // get current licence
         err^.WriteOA( L'  processing activation "', FALSE ); err^.Write( sns.Current^, FALSE ); err^.WriteOA( L'"', TRUE );
         IF NOT Number.Decode( sns.Current^, REF an ) THEN
            err^.WriteOA( L'    the activation is not valid', TRUE );
            CONTINUE;
         END; 
         
         haveSome := FALSE;
         count := data.Count;
         FOR i := 0 TO count-1 DO
            item := Items.TPItem( data[i] );

            IF an.CheckPId( item^.ProductId ) AND ( item^ IS Items.CLicence ) THEN
               err^.WriteOA( L'  processing product "', FALSE ); err^.Write( item^.ProductId, FALSE ); err^.WriteOA( L'"', TRUE );

               Number.Decode( Items.TPLicence( item )^.Serial, REF sn );
               uid := uq.UId( item^.ProductId );
               
               IF an.GOrd <> sn.GOrd THEN
                  err^.WriteOA( L'    the activation is for another licence', TRUE );
                  CONTINUE;
               ELSIF NOT an.CheckMId( uid ) THEN
                  err^.WriteOA( L'    the activation is for another system', TRUE );
                  CONTINUE;
               ELSE
                  haveSome := TRUE;
               
                  // check if activation does not exists
                  NEW( activationItem );
                  activationItem^.ProductId := item^.ProductId;
                  activationItem^.Created := time.NowUTC();
                  activationItem^.OfSerial := Items.TPLicence( item )^.Serial;
                  activationItem^.UId := uid;
                  dte := an.Origin;
                  IF an.Months = 0 THEN
                     activationItem^.Expires := dte;
                  ELSIF an.Months = -1 THEN
                     activationItem^.Starts := dte;
                  ELSE
                     activationItem^.Starts := dte;
                     dte.FromJD( dte.JulianDate + time.DaysToJDC( an.Months * 31 ), 0, 0 );
                     activationItem^.Expires := dte;
                  END;

                  // check duplicities
                  found := FALSE;
                  FOR j := 0 TO data.Count-1 DO
                     item := Items.TPItem( data[j] );
                     IF item^.Equals( activationItem^ ) THEN
                        found := TRUE;
                        EXIT;
                     END;
                  END; // FOR
                  IF found THEN
                     err^.WriteOA( L'    activation already exists', TRUE );
                     DISPOSE( activationItem );
                  ELSE
                     data.Add( activationItem );
                  END;

               END;
            END;
         END; // FOR items
         
         IF NOT haveSome THEN
            err^.WriteOA( L'    activation not added', TRUE );
         END;

      END; // WHILE sns
      
      ls.Store( data, TRUE );
   #endif

   #if Supervisor #then
   //-----
   | opProductHash :
		hash.hashs( OA( owner.Length-1, owner.rawData ), OUT hPID );
      cphcommon.ToHex( hPID, OUT s );
      err^.WriteOA( L'  phash "', FALSE ); err^.WriteOA( s, FALSE ); err^.WriteOA( L'"', TRUE );

   //-----
   | opOwnerHash :
		hash.hashs( OA( owner.Length-1, owner.rawData ), OUT hOwner );
      cphcommon.ToHex( hOwner, OUT s );
      err^.WriteOA( L'  ohash "', FALSE ); err^.WriteOA( s, FALSE ); err^.WriteOA( L'"', TRUE );

   //-----
   | opMachineHash :
      uid := uq.UId( owner );
      hash.hashb( uid, OUT hMID );
      cphcommon.ToHex( hMID, OUT s );
      err^.WriteOA( L'  mhash "', FALSE ); err^.WriteOA( s, FALSE ); err^.WriteOA( L'"', TRUE );
   #endif

   #if Builder #then
   //-----
   | opGenerateM2Source :
      WriteM2Source( pid );
   #endif

   #if Client #or Activator #then
   //-----
   | opInfo :
      LoadData( TRUE, FALSE, OUT data );
   
      count := data.Count;
      
      // products with licences
      FOR i := 0 TO count-1 DO
         item := Items.TPItem( data[i] );
         IF item^ IS Items.CProduct THEN
            err^.LineEnd();
            err^.WriteOA( L'  product "', FALSE ); err^.Write( item^.ProductId, FALSE ); err^.WriteOA( L'"', TRUE );

            #if Supervisor #then
               hash.hashs( OA( item^.ProductId.Length-1, item^.ProductId.rawData ), OUT hPID );
               cphcommon.ToHex( hPID, OUT s );
               err^.WriteOA( L'  phash "', FALSE ); err^.WriteOA( s, FALSE ); err^.WriteOA( L'"', TRUE );
            #endif

            jlist := Items.TPProduct( item )^.LicencesAndInfos;
            jlist^.Reset();
            WHILE jlist^.MoveNext() DO
               IF NOT( Items.TPItem( jlist^.Current )^ IS Items.CLicence ) THEN
                  CONTINUE;
               END;
            
               item := Items.TPItem( jlist^.Current );
               err^.WriteOA( L'    licence "', FALSE ); err^.Write( Items.TPLicence( item )^.Serial, FALSE ); err^.WriteOA( L'"', TRUE );
               err^.WriteOA( L'    type "', FALSE ); err^.Write( Items.TPLicence( item )^.TypeString, FALSE ); err^.WriteOA( L'"', TRUE );

               Number.Decode( Items.TPLicence( item )^.Serial, REF sn );
               #if Supervisor #then
                  IF showGOrds THEN
                     Strings.FromCARD32W( sn.GOrd, 10, OUT s );
                     err^.WriteOA( L'    gord "', FALSE ); err^.WriteOA( s, FALSE ); err^.WriteOA( L'"', TRUE );
                  END;
               
                  hash.hashb( Items.TPLicence( item )^.UId, OUT hMID );
                  cphcommon.ToHex( hMID, OUT s );
                  err^.WriteOA( L'    mhash "', FALSE ); err^.WriteOA( s, FALSE ); err^.WriteOA( L'"', TRUE );

                  IF Items.ltUnnamed NOT IN Items.TPLicence( item )^.Type THEN
                     hash.hashs( OA( Items.TPLicence( item )^.Owner.Length-1, Items.TPLicence( item )^.Owner.rawData ), OUT hOwner );
                     cphcommon.ToHex( hOwner, OUT s );
                     err^.WriteOA( L'    ohash "', FALSE ); err^.WriteOA( s, FALSE ); err^.WriteOA( L'"', TRUE );
                     err^.WriteOA( L'    licence is bound to owner', TRUE );
                  END;
               #endif

               klist := Items.TPLicence( item )^.Activations;
               klist^.Reset();
               WHILE klist^.MoveNext() DO
                  item := Items.TPItem( klist^.Current );

                  dtb := Items.TPActivation( item )^.Starts;
                  dte := Items.TPActivation( item )^.Expires;
                  IF ( dtb.Year = 0 ) AND ( dte.Year = 0 ) THEN
                     err^.WriteOA( L'      activated permanently', TRUE );
                  ELSIF dtb.Year = 0 THEN
                     err^.WriteOA( L'      activated to "', FALSE ); err^.Write( Items.TPActivation( item )^.ExpiresString, FALSE ); err^.WriteOA( L'"', TRUE );
                  ELSIF dte.Year = 0 THEN
                     err^.WriteOA( L'      activated permanently from "', FALSE ); err^.Write( Items.TPActivation( item )^.StartsString, FALSE ); err^.WriteOA( L'"', TRUE );
                  ELSE
                     err^.WriteOA( L'      activated from "', FALSE ); err^.Write( Items.TPActivation( item )^.StartsString, FALSE );
                     err^.WriteOA( L'" to "', FALSE ); err^.Write( Items.TPActivation( item )^.ExpiresString, FALSE ); err^.WriteOA( L'"', TRUE );
                  END;

               END; // WHILE klist
            END; // WHILE jlist
         END; // if product
      END; // FOR items

      #if Supervisor #then
      // licences without products
      FOR i := 0 TO count-1 DO
         item := Items.TPItem( data[i] );
         IF ( item^ IS Items.CLicence ) AND ( item^.IsStub ) THEN
            err^.LineEnd();

            err^.WriteOA( L'    licence stub "', FALSE ); err^.Write( Items.TPLicence( item )^.Serial, FALSE ); err^.WriteOA( L'"', TRUE );
            err^.WriteOA( L'    type "', FALSE ); err^.Write( Items.TPLicence( item )^.TypeString, FALSE ); err^.WriteOA( L'"', TRUE );

            Number.Decode( Items.TPLicence( item )^.Serial, REF sn );
            IF showGOrds THEN
               Strings.FromCARD32W( sn.GOrd, 10, OUT s );
               err^.WriteOA( L'    gord "', FALSE ); err^.WriteOA( s, FALSE ); err^.WriteOA( L'"', TRUE );
            END;
            
            cphcommon.ToHex( sn.PId, OUT s );
            err^.WriteOA( L'    phash "', FALSE ); err^.WriteOA( s, FALSE ); err^.WriteOA( L'"', TRUE );

            hash.hashb( Items.TPLicence( item )^.UId, OUT hMID );
            cphcommon.ToHex( hMID, OUT s );
            err^.WriteOA( L'    mhash "', FALSE ); err^.WriteOA( s, FALSE ); err^.WriteOA( L'"', TRUE );

            IF Items.ltUnnamed NOT IN sn.Type THEN
               cphcommon.ToHex( sn.Owner, OUT s );
               err^.WriteOA( L'    ohash "', FALSE ); err^.WriteOA( s, FALSE ); err^.WriteOA( L'"', TRUE );
            END;

            klist := Items.TPLicence( item )^.Activations;
            klist^.Reset();
            WHILE klist^.MoveNext() DO
               item := Items.TPItem( klist^.Current );

               dtb := Items.TPActivation( item )^.Starts;
               dte := Items.TPActivation( item )^.Expires;
               IF ( dtb.Year = 0 ) AND ( dte.Year = 0 ) THEN
                  err^.WriteOA( L'      activated permanently', TRUE );
               ELSIF dtb.Year = 0 THEN
                  err^.WriteOA( L'      activated to "', FALSE ); err^.Write( Items.TPActivation( item )^.ExpiresString, FALSE ); err^.WriteOA( L'"', TRUE );
               ELSIF dte.Year = 0 THEN
                  err^.WriteOA( L'      activated permanently from "', FALSE ); err^.Write( Items.TPActivation( item )^.StartsString, FALSE ); err^.WriteOA( L'"', TRUE );
               ELSE
                  err^.WriteOA( L'      activated from "', FALSE ); err^.Write( Items.TPActivation( item )^.StartsString, FALSE );
                  err^.WriteOA( L'" to "', FALSE ); err^.Write( Items.TPActivation( item )^.ExpiresString, FALSE ); err^.WriteOA( L'"', TRUE );
               END;

            END; // WHILE klist
         END; // IF
      END; // FOR items

      // activations without licences
      FOR i := 0 TO count-1 DO
         item := Items.TPItem( data[i] );
         IF ( item^ IS Items.CActivation ) AND ( item^.IsStub ) THEN
            err^.LineEnd();

            err^.WriteOA( L'    activation stub of licence "', FALSE ); err^.Write( Items.TPActivation( item )^.OfSerial, FALSE ); err^.WriteOA( L'"', TRUE );

            Number.Decode( Items.TPActivation( item )^.OfSerial, REF sn );
            IF showGOrds THEN
               Strings.FromCARD32W( sn.GOrd, 10, OUT s );
               err^.WriteOA( L'    gord "', FALSE ); err^.WriteOA( s, FALSE ); err^.WriteOA( L'"', TRUE );
            END;
            
            cphcommon.ToHex( sn.PId, OUT s );
            err^.WriteOA( L'    phash "', FALSE ); err^.WriteOA( s, FALSE ); err^.WriteOA( L'"', TRUE );

            IF Items.ltUnnamed NOT IN sn.Type THEN
               cphcommon.ToHex( sn.Owner, OUT s );
               err^.WriteOA( L'    ohash "', FALSE ); err^.WriteOA( s, FALSE ); err^.WriteOA( L'"', TRUE );
            END;

            dtb := Items.TPActivation( item )^.Starts;
            dte := Items.TPActivation( item )^.Expires;
            IF ( dtb.Year = 0 ) AND ( dte.Year = 0 ) THEN
               err^.WriteOA( L'      activated permanently', TRUE );
            ELSIF dtb.Year = 0 THEN
               err^.WriteOA( L'      activated to "', FALSE ); err^.Write( Items.TPActivation( item )^.ExpiresString, FALSE ); err^.WriteOA( L'"', TRUE );
            ELSIF dte.Year = 0 THEN
               err^.WriteOA( L'      activated permanently from "', FALSE ); err^.Write( Items.TPActivation( item )^.StartsString, FALSE ); err^.WriteOA( L'"', TRUE );
            ELSE
               err^.WriteOA( L'      activated from "', FALSE ); err^.Write( Items.TPActivation( item )^.StartsString, FALSE );
               err^.WriteOA( L'" to "', FALSE ); err^.Write( Items.TPActivation( item )^.ExpiresString, FALSE ); err^.WriteOA( L'"', TRUE );
            END;

         END; // IF
      END; // FOR items
      #endif
   #endif

   //-----
   END; // CASE
   
   #if Builder #or Client #then
   FOR i := 0 TO data.Count-1 DO
      DISPOSE( Items.TPItem( data[i] ));
   END;
   #endif

   RETURN 0;
END wmain;

END lictool.