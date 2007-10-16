MODULE StringReplaceInsert;

IMPORT
	StringsO;

	#save, call( entry_point => on )
	PROCEDURE wmain() : INTEGER;
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
	END wmain;

BEGIN
END StringReplaceInsert.