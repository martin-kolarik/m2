MODULE sum;

FROM Storage IMPORT
  ALLOCATE;
  
FROM Exceptions IMPORT
  TestIfCatched, RetrieveException;

IMPORT
   FIO,
   FIOO,
   FSO,
   IOO,
   digest,
   md5,
   sha1,
   sha256,
   StringsO,
   Sync,
   TextReader,
   TextWriter;

TYPE
  TParamStringArray  = ARRAY [0..0] OF POINTER TO ARRAY [0..511] OF WCHAR;
  TPParamStringArray = POINTER TO TParamStringArray;
  
PROCEDURE CheckSum( file : IOO.TPStream; hashType : digest.TDigestType; binaryMode : TRISTATE; OUT D : digest.ADigest ); FORWARD;

# save, call( convention => cdecl )
PROCEDURE Main( argc : INTEGER; argp : TPParamStringArray ) : INTEGER;
# restore
LABEL
   Error;
VAR
   BinaryMode : TRISTATE := -1;
   CheckFile : FIO.PathStrW := L"";
   Dc, Df : digest.TPDigest;
   Dc1, Df1 : sha1.CDigest;
   Dc2, Df2 : sha256.CDigest;
   Dc5, Df5 : md5.CDigest;
   DI : FSO.CDirectoryInfo;
   DigestType : digest.TDigestType := digest.md5;
   errout : TextWriter.TPTextWriter := TextWriter.errout();
   file : FIOO.CFileStream;
   fs : FIOO.CFileStream;
   Hash : StringsO.CString;
   Hex : ARRAY [0..63] OF WCHAR;
   i : INTEGER;
   Line : StringsO.CString;
   Name : StringsO.CString;
   Path : FIO.PathStrW := L"";
   Result : CARDINAL := 0;
   stdout : TextWriter.TPTextWriter := TextWriter.stdout();
   tr : TextReader.CTextReader;
BEGIN
   i := 1;
   WHILE i < argc DO
      IF ( argp^[i]^[0] = L'/' ) OR ( argp^[i]^[0] = L'-' ) THEN // option

         CASE argp^[i]^[1] OF
         | L'b' :
            BinaryMode := 1;
         | L'c' :
            INC( i );
            IF i = argc THEN
               errout^.WriteOA( L"sum: missing file-with-sum", TRUE );
               GOTO Error;
            END;
            CheckFile := argp^[i]^;
         | L'h' :
            GOTO Error;
         | L't' :
            BinaryMode := 0;
         | L'1' :
            DigestType := digest.sha1;
         | L'2' :
            DigestType := digest.sha256;
         | L'5' :
            DigestType := digest.md5;
         ELSE
            errout^.WriteOA( L"sum: invalid option ", FALSE ); errout^.WriteOA( argp^[i]^, TRUE );
            GOTO Error;
         END;

      ELSE // file
         Path := argp^[i]^;
      END;
      
      INC( i );
   END; // WHILE

   CASE DigestType OF
   | digest.md5 :
      Dc := ADR( Dc5 );
      Df := ADR( Df5 );
   | digest.sha1 :
      Dc := ADR( Dc1 );
      Df := ADR( Df1 );
   | digest.sha256 :
      Dc := ADR( Dc2 );
      Df := ADR( Df2 );
   END;

   IF CheckFile[0] <> 0W THEN // use file and check
      TRY
         fs.FromPath( CheckFile, FIOO.imOpenRead );
      CATCH e : IOO.CIOException DO
         errout^.WriteOA( L"sum: check file open failed: ", FALSE ); 
         errout^.WriteExc( e, TRUE );
         GOTO Error;
      END;
      tr.Stream := ADR( fs );
      WHILE tr.ReadLine( OUT Line, Sync.FOREVER, TRUE ) = Sync.arCompleted DO

         i := Line.IndexOfOA( L" ", 0 );
         Line.Substring( 0, i, OUT Hash );
         Line.Substring( i+1, -1, OUT Name );

         Dc^.FromHex( OA( Hash.Length-1, Hash.rawData ));
         IF Name[0] = L"*" THEN
            BinaryMode := 1;
            Name.Remove( 0, 1 );
         ELSE
            BinaryMode := 0;
         END;

         TRY
            file.FromPath( OA( Name.Length-1, Name.rawData ), FIOO.imOpenRead );
         CATCH e : IOO.CIOException DO
            errout^.WriteOA( L"open failed: ", FALSE ); errout^.Write( Name, TRUE );
            CONTINUE;
         END;
         CheckSum( ADR( file ), DigestType, BinaryMode, OUT Df^ );
         file.Close( FALSE );

         IF Dc^ = Df^ THEN
            stdout^.Write( Name, FALSE ); stdout^.WriteOA( L": OK", TRUE );
         ELSE
            stdout^.Write( Name, FALSE ); stdout^.WriteOA( L": FAILED", TRUE );
         END;
      END; // WHILE
      fs.Close( FALSE );

   ELSIF Path[0] <> 0W THEN // create sum for all found files
      IF BinaryMode = -1 THEN
         BinaryMode := 1;
      END;
   
      IF DI.StartFromPathOA( Path, FSO.soTopDirectoryOnly, FALSE, TRUE ) THEN
         REPEAT
            Line := DI.Path;
            TRY
               file.FromPath( OA( Line.Length-1, Line.rawData ), FIOO.imOpenRead );
            CATCH e : IOO.CIOException DO
               errout^.WriteOA( L"open failed: ", FALSE ); errout^.Write( Line, TRUE );
               CONTINUE;
            END;
            CheckSum( ADR( file ), DigestType, BinaryMode, OUT Df^ );
            file.Close( FALSE );

            Df^.ToHex( OUT Hex );
            stdout^.WriteOA( Hex, FALSE );
            IF BinaryMode = 1 THEN
               stdout^.WriteOA( L" *", FALSE );
            ELSE
               stdout^.WriteOA( L" ", FALSE );
            END;
            stdout^.Write( Line, TRUE );
         UNTIL NOT DI.MoveNext();
      END;

   ELSE // create sum of std in
      IF BinaryMode = -1 THEN
         BinaryMode := 0;
      END;

      CheckSum( FIOO.stdin(), DigestType, BinaryMode, OUT Df^ );
      Df^.ToHex( OUT Hex );
      stdout^.WriteOA( Hex, FALSE );
      IF BinaryMode = 1 THEN
         stdout^.WriteOA( L" *-", TRUE );
      ELSE
         stdout^.WriteOA( L" -", TRUE );
      END;

   END; // IF main operation mode

   RETURN 0;

Error:
   errout^.WriteOA( L"  usage: sum [-b] [-1|-2|-5] [-c file-with-sums] [file-to-compute-sum] [-h]", TRUE );
   RETURN Result;
END Main;
  
PROCEDURE CheckSum( file : IOO.TPStream; hashType : digest.TDigestType; binaryMode : TRISTATE; OUT D : digest.ADigest );
VAR
   buffer : ARRAY [0..4095] OF BYTE;
   consumed : CARDINAL;
   digester : digest.TPDigester;
   Line : StringsO.CString;
   MD5 : md5.CMD5;
   SHA1 : sha1.CSHA1;
   SHA256 : sha256.CSHA256;
   tr : TextReader.CTextReader;
BEGIN
   CASE hashType OF
   | digest.md5 :
      digester := ADR( MD5 );
   | digest.sha1 :
      digester := ADR( SHA1 );
   | digest.sha256 :
      digester := ADR( SHA256 );
   END;

   digester^.Init();

   IF binaryMode = 1 THEN
      WHILE file^.ReadOA( REF buffer, OUT consumed, Sync.FOREVER ) = Sync.arCompleted DO
         IF consumed > 0 THEN
            digester^.Update( OA( consumed-1, ADR( buffer )));
         END;
      END;
   ELSE
      tr.Stream := file;
      WHILE tr.ReadLineS( OUT Line ) DO
         IF NOT Line.Empty THEN
            digester^.Update( OA( Line.Length-1, Line.rawData ));
         END;
      END; // WHILE
      tr.Stream := NIL;
   END;

   digester^.Finish( OUT D );
END CheckSum;

END sum.

