MODULE thelel;

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
	CONST
		zlinLat  = ( 49.0 + 13.0 / 60.0 +  3.18 / 3600.0 ) * astro.degToRad;
		zlinLong = ( 17.0 + 41.0 / 60.0 + 34.44 / 3600.0 ) * astro.degToRad;
		zlinAlt  = 349.18;
	VAR
		body : astro.CAbstractBody;
		cm : astro.CCelestialMechanic;
		earth : astro.CPlanet;
		sun : astro.CPlanet; 
		venus : astro.CPlanet;
		refpar : astro.TRefractionParameters;
		cor : BOOLEAN;
		
		h, m : INTEGER;
		s, mf : LONGREAL;
		
		jd : LONGREAL;
	BEGIN
		IF argc < 7 THEN
			OutS( L"usage: thelel <a> <e> <i> <O> <o> <M0> <n> epoch [1/0] [jd]", TRUE );
			RETURN 0;
		END;

		Strings.ToLONGREALW( OAsz( argp^[1] ), OUT body.Elements.a );

		Strings.ToLONGREALW( OAsz( argp^[2] ), OUT body.Elements.e );

		Strings.ToLONGREALW( OAsz( argp^[3] ), OUT body.Elements.i );
		body.Elements.i := body.Elements.i * astro.pi / 180.0;
		
		Strings.ToLONGREALW( OAsz( argp^[4] ), OUT body.Elements.Omega );
		body.Elements.Omega := body.Elements.Omega * astro.pi / 180.0;

		Strings.ToLONGREALW( OAsz( argp^[5] ), OUT body.Elements.omega1 );
		body.Elements.omega1 := body.Elements.omega1 * astro.pi / 180.0;

		Strings.ToLONGREALW( OAsz( argp^[6] ), OUT body.Elements.M0 );
		body.Elements.M0 := body.Elements.M0 * astro.pi / 180.0;

		Strings.ToLONGREALW( OAsz( argp^[7] ), OUT body.Elements.n );
		body.Elements.n := body.Elements.n * astro.pi / 180.0;

		Strings.ToLONGREALW( OAsz( argp^[8] ), OUT body.Elements.Epoch );
		
		IF argc > 9 THEN
		  cor := argp^[9]^[0] = L"1";
		END;
		
		IF argc > 10 THEN
			Strings.ToLONGREALW( OAsz( argp^[10] ), OUT jd );
		ELSE
			jd := datetime.GetCurrentJD();
		END;
		
		refpar.tC := 15.0;
		refpar.phPa := 975.0;
		refpar.fipc := 50.0;

		body.Init( zlinAlt, zlinLong, zlinLat, refpar );
		body.PMechanic := ADR( cm );
		body.Elements.FKnownM0 := TRUE;
		body.Elements.FKnownT0 := FALSE;
		body.Elements.FKnownPeriod := FALSE;
		body.Elements.FOmegaInPath := FALSE;
		body.Elements.FKnownPerihelDistance := FALSE;
		IF cor THEN
			body.Corrections := astro.TCorrections{
											astro.corPrecession,
											astro.corNutation,
											astro.corAberation,
											astro.corParalax,
											astro.corRefraction};
		END;
		
		earth.Planet := 3;
		earth.Init( zlinAlt, zlinLong, zlinLat, refpar );
		earth.PMechanic := ADR( cm );
		IF cor THEN
			body.Corrections := astro.TCorrections{
											astro.corBarycenter,
											astro.corPrecession,
											astro.corNutation,
											astro.corAberation,
											astro.corParalax,
											astro.corRefraction};
		END;
		
		venus.Planet := 2;
		venus.Init( zlinAlt, zlinLong, zlinLat, refpar );
		venus.PMechanic := ADR( cm );
		IF cor THEN
			body.Corrections := astro.TCorrections{
											astro.corBarycenter,
											astro.corPrecession,
											astro.corNutation,
											astro.corAberation,
											astro.corParalax,
											astro.corRefraction};
		END;
		
		sun.Planet := 11;
		sun.Init( zlinAlt, zlinLong, zlinLat, refpar );
		sun.PMechanic := ADR( cm );
		IF cor THEN
			body.Corrections := astro.TCorrections{
											astro.corBarycenter,
											astro.corPrecession,
											astro.corNutation,
											astro.corAberation,
											astro.corParalax,
											astro.corRefraction};
		END;

		cm.SetJD( jd );
		cm.PEarth := ADR( earth );
		cm.Ephemeris( ADR( venus ));
		cm.Ephemeris( ADR( body ));
		cm.Ephemeris( ADR( sun ));
		
		OutS( "", TRUE );
		
		astro.RadToRA( sun.CoordsEquatoreal.lambda, h, m, s, mf );
		
		OutLR( "S RA h: ", LONGREAL( h ), FALSE );
		OutLR( " m: ", LONGREAL( m ), FALSE );
		OutLR( " s: ", s, TRUE );
		
		astro.RadToDE( sun.CoordsEquatoreal.beta, h, m, s, mf );
		
		OutLR( "S DE s: ", LONGREAL( h ), FALSE );
		OutLR( " m: ", LONGREAL( mf ), TRUE );
		// OutLR( "v: ", s, TRUE );

		OutS( "", TRUE );
		
		OutLR( "E XY x: ", earth.CoordsHeliocentricGeometric.x, FALSE );
		OutLR( " y: ", earth.CoordsHeliocentricGeometric.y, FALSE );
		OutLR( " z: ", earth.CoordsHeliocentricGeometric.z, TRUE );

		OutLR( "V XY x: ", venus.CoordsHeliocentricGeometric.x, FALSE );
		OutLR( " y: ", venus.CoordsHeliocentricGeometric.y, FALSE );
		OutLR( " z: ", venus.CoordsHeliocentricGeometric.z, TRUE );

		OutLR( "B XY x: ", body.CoordsHeliocentricGeometric.x, FALSE );
		OutLR( " y: ", body.CoordsHeliocentricGeometric.y, FALSE );
		OutLR( " z: ", body.CoordsHeliocentricGeometric.z, TRUE );
		
		OutS( "", TRUE );

		astro.RadToRA( body.CoordsEquatoreal.lambda, h, m, s, mf );
		
		OutLR( "B RA h: ", LONGREAL( h ), FALSE );
		OutLR( " m: ", LONGREAL( m ), FALSE );
		OutLR( " s: ", s, TRUE );
		
		astro.RadToDE( body.CoordsEquatoreal.beta, h, m, s, mf );
		
		OutLR( "B DE s: ", LONGREAL( h ), FALSE );
		OutLR( " m: ", LONGREAL( mf ), TRUE );
		// OutLR( "v: ", s, TRUE );
		OutLR( "B DE s: ", LONGREAL( h ), FALSE );
		OutLR( " m: ", LONGREAL( m ), FALSE );
		OutLR( " s: ", LONGREAL( s ), TRUE );

		OutLR( "B AZ A: ", LONGREAL( body.CoordsAzimutal.lambda ) * 180.0 / astro.pi, FALSE );
		OutLR( " h: ", LONGREAL( body.CoordsAzimutal.beta ) * 180.0 / astro.pi, TRUE );

		RETURN 0;
	END wmain;

END thelel.