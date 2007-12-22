MODULE wordlist;

IMPORT
   IOO,
	FIOO,
	Languages,
	StringsO,
	Sync,
	TextReader,
	TextWriter;

	#save, call( convention => cdecl )
	PROCEDURE wmain01() : INTEGER;
	#restore
	VAR
	   bw : IOO.CBufferedStream;
	   CH : WCHAR;
	   fr, fw : FIOO.CFileStream;
	   tr : TextReader.CTextReader;
	   tw : TextWriter.CTextWriter;
	   Line, Item : StringsO.CString;
	   i : CARDINAL;
	BEGIN
	   TRY
	      fr.FromPath( L"d:\buff\cs.wl", FIOO.imOpenRead );
	   CATCH e : IOO.CIOException DO
	   END;
	   tr.Stream := ADR( fr );
	   tr.BufferSize := 1 << 15;
	   tr.Encoding := Languages.cp_ISO8859_2;

	   TRY
	      fw.FromPath( L"d:\buff\cscrit.wl", FIOO.imCreate );
	   CATCH e : IOO.CIOException DO
	   END;
	   bw.Stream := ADR( fw );
	   bw.BufferSize := 1 << 15;
	   tw.Stream := ADR( bw );
	   tw.LineEndStyle := TextWriter.lesUNIX;
	   
	   WHILE tr.ReadChar( OUT CH, Sync.INFINITE_TIME, TRUE ) = Sync.arCompleted DO
	     CASE CH OF
	     | 13W : // ignore
	     | 10W, L" " :
	       tw.LineEnd();
	     | 'A'..'Z' :
	       CH := WCHAR( ORD( CH ) - ORD( 'A' ) + ORD( 'a' ));
	       tw.WriteOA( CH, FALSE );
	     | 'ì', 'Ì' : CH := 'e'; tw.WriteOA( CH, FALSE );
	     | 'š', 'Š' : CH := 's'; tw.WriteOA( CH, FALSE );
	     | 'è', 'È' : CH := 'c'; tw.WriteOA( CH, FALSE );
	     | 'ø', 'Ø' : CH := 'r'; tw.WriteOA( CH, FALSE );
	     | 'ž', 'Ž' : CH := 'z'; tw.WriteOA( CH, FALSE );
	     | 'ý', 'Ý' : CH := 'y'; tw.WriteOA( CH, FALSE );
	     | 'á', 'Á' : CH := 'a'; tw.WriteOA( CH, FALSE );
	     | 'í', 'Í' : CH := 'i'; tw.WriteOA( CH, FALSE );
	     | 'é', 'É' : CH := 'e'; tw.WriteOA( CH, FALSE );
	     | 'ú', 'Ú' : CH := 'u'; tw.WriteOA( CH, FALSE );
	     | 'ù' :      CH := 'u'; tw.WriteOA( CH, FALSE );
	     | 'ó', 'Ó' : CH := 'o'; tw.WriteOA( CH, FALSE );
	     | 'ò', 'Ò' : CH := 'n'; tw.WriteOA( CH, FALSE );
	     | '', '' : CH := 't'; tw.WriteOA( CH, FALSE );
	     | 'ï', 'Ï' : CH := 'd'; tw.WriteOA( CH, FALSE );
	     ELSE
	       tw.WriteOA( CH, FALSE );
	     END;
	   END; // WHILE
	   
	   fr.Close( FALSE );
	   bw.Close( FALSE );

		RETURN 0;
	END wmain01;

END wordlist.