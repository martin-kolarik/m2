MODULE ttime;

IMPORT
	astro,
	FIO,
	Strings,
	datetime,,
	windows;
	
	TYPE
		TParamString       = ARRAY [0..0] OF WCHAR;
		TPParamString      = POINTER TO TParamString;
		TParamStringArray  = ARRAY [0..0] OF TPParamString;
		TPParamStringArray = POINTER TO TParamStringArray;
		
	VAR
		fout : FIO.File := windows.GetStdHandle( windows.STD_OUTPUT_HANDLE );
		
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
		cm : astro.CCelestialMechanic;
		jd : LONGREAL;
		
		h, m, s, ms : CARDINAL;
	BEGIN
		IF argc = 1 THEN
			jd := datetime.GetCurrentJD();
		ELSE
			Strings.ToLONGREALW( OAsz( argp^[1] ), OUT jd );
		END;
		cm.SetJD( jd );
		
		OutLR( L"JD:           ", jd, TRUE );
		OutLR( L"Sideral time: ", cm.SideralTimeUT(), TRUE );
		
		datetime.fd2HMS( cm.SideralTimeUT() / 24.0, h, m, s, ms );

		OutLR( "  h: ", LONGREAL( h ), TRUE );
		OutLR( "  m: ", LONGREAL( m ), TRUE );
		OutLR( "  s: ", LONGREAL( s ), TRUE );

		RETURN 0;
	END wmain;

END ttime.