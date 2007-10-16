MODULE TScrambler;

IMPORT
  Scrambler;
  
#save, call( convention => cdecl )
PROCEDURE wmain() : INTEGER;
#restore
VAR
	b, c : ARRAY [0..11] OF BYTE;
	p, s : ARRAY [0..63] OF WCHAR;
	i, j, l : CARDINAL;
BEGIN
	FOR i := 0 TO 11 DO
		b[i] := 055H;
	END;
	Scrambler.Scramble( b, L"", L'', OUT s );
	Scrambler.Unscramble( s, L'', OUT p, OUT c, OUT i );

	FOR i := 0 TO 255 DO
		FOR j := 0 TO 11 DO
			b[j] := BYTE( i );
		END;
		Scrambler.Scramble( b, L"XX", L'-', OUT s );
		Scrambler.Unscramble( s, L'-', OUT p, OUT c, OUT l );
		FOR j := 0 TO 11 DO
			IF b[j] <> c[j] THEN
				ADDRESS( 0 )^ := 0;
			END;
		END;
	END;

	RETURN 0;
END wmain;

END TScrambler.