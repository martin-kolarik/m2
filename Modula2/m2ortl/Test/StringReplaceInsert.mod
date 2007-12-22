MODULE StringReplaceInsert;

IMPORT
	StringsO;

	#save, call( convention => cdecl )
	PROCEDURE wmain02() : INTEGER;
	#restore
	VAR
		S : StringsO.CString;
	BEGIN
		S.FromOA( L'0123456789ABCDEF' );
		S.InsertOA( 10, L'XXX' );
		S.InsertOA( 15, L'XXX' );
		S.ReplaceOA( L'XX', L'.' );
		S.ReplaceOA( L'X', L'::' );
		RETURN 0;
	END wmain02;

BEGIN
END StringReplaceInsert.