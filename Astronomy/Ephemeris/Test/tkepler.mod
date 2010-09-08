MODULE tkepler;

IMPORT
	astro,
   datetime,
	FIO,
	math,
	Strings,
	windows;
	
	TYPE
		TParamString       = ARRAY [0..0] OF WCHAR;
		TPParamString      = POINTER TO TParamString;
		TParamStringArray  = ARRAY [0..0] OF TPParamString;
		TPParamStringArray = POINTER TO TParamStringArray;
		
	VAR
		fout : FIO.File := windows.GetStdHandle( windows.STD_OUTPUT_HANDLE );
		
	PROCEDURE OutS( sw : ARRAY OF WCHAR; lf : BOOLEAN );
	VAR
		sa : ARRAY [0..511] OF CHAR;
	BEGIN
		Strings.ToA( sw, 0, OUT sa );
		FIO.WrStrA( fout, sa );

		IF lf THEN
			FIO.WrStrA( fout, CHAR( 10 ) + CHAR( 13 ));
		END;
	END OutS;

	PROCEDURE OutLR( sw : ARRAY OF WCHAR; lr : LONGREAL; lf : BOOLEAN );
	VAR
		lsw : ARRAY [0..511] OF WCHAR;
		sa : ARRAY [0..511] OF CHAR;
	BEGIN
		Strings.ToA( sw, 0, OUT sa );
		FIO.WrStrA( fout, sa );

		Strings.FromLONGREALW( lr, -1, -1, OUT lsw );
		Strings.ToA( lsw, 0, OUT sa );
		FIO.WrStrA( fout, sa );
		
		IF lf THEN
			FIO.WrStrA( fout, CHAR( 10 ) + CHAR( 13 ));
		END;
	END OutLR;

	#save, call( convention => cdecl, entry_point => on )
	PROCEDURE wmain( argc : INTEGER; argp : TPParamStringArray; enpv : TPParamStringArray ) : INTEGER;
	#restore
	VAR
		e, M, E : LONGREAL;
	BEGIN
		IF argc <> 3 THEN
			OutS( L"usage: tkepler <e> <M>", TRUE );
			RETURN 0;
		END;
		Strings.ToLONGREALW( OAsz( argp^[1] ), OUT e );
		Strings.ToLONGREALW( OAsz( argp^[2] ), OUT M );

		E := astro.Kepler( M, e );
		
		OutLR( L"e: ", e, TRUE );
		OutLR( L"M: ", M, TRUE );
		OutLR( L"E: ", E, TRUE );
		OutLR( L"v: ", 2.0 * math.atan( math.tan( E / 2.0 ) * math.sqrt(( 1.0 + e ) / ( 1.0 - e ))), TRUE );

		RETURN 0;
	END wmain;

END tkepler.