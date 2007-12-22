MODULE Match;

IMPORT
	Strings;

	#save, call( convention => cdecl )
	PROCEDURE wmain08() : INTEGER;
	#restore
	VAR
		b : BOOLEAN;
	BEGIN
		b := Strings.MatchW( L"abc.xyz", L"a?c*z", TRUE );
		b := Strings.MatchW( L"abc.xyz", L"a?c*x*", TRUE );
		b := Strings.MatchW( L"abc.xyz", L"a?c*x?", TRUE );
		b := Strings.MatchW( L"abc.xyz", L"*", TRUE );
		b := Strings.MatchW( L"abc.abc", L"*abc", TRUE );

		b := Strings.MatchW( L"Abc.xyz", L"a?c*z", TRUE );
		b := Strings.MatchW( L"Abc.xyz", L"a?c*x*", TRUE );
		b := Strings.MatchW( L"Abc.xyz", L"a?c*x?", TRUE );
		b := Strings.MatchW( L"Abc.xyz", L"*", TRUE );
		b := Strings.MatchW( L"Abc.abc", L"*abc", TRUE );

		b := Strings.MatchW( L"Abc.xyz", L"a?c*z", FALSE );
		b := Strings.MatchW( L"Abc.xyz", L"a?c*x*", FALSE );
		b := Strings.MatchW( L"Abc.xyz", L"a?c*x?", FALSE );
		b := Strings.MatchW( L"Abc.xyz", L"*", FALSE );
		b := Strings.MatchW( L"Abc.abc", L"*abc", FALSE );

		RETURN 0;
	END wmain08;

END Match.