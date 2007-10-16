MODULE StringReplaceInsert;

IMPORT
	Strings;

	#save, call( entry_point => on )
	PROCEDURE wmain() : INTEGER;
	#restore
	VAR
		s : ARRAY [0..15] OF WCHAR;
	BEGIN
		s := L'0123456789ABCDEF';
		Strings.InsertW( REF s, 10, L'XXX' );
		Strings.InsertW( REF s, 15, L'XXX' );
		Strings.ReplaceW( REF s, L'XX', L'.' );
		Strings.ReplaceW( REF s, L'X', L'::' );
		RETURN 0;
	END wmain;

BEGIN
END StringReplaceInsert.