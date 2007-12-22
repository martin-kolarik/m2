MODULE TCreateDir;

IMPORT
	FSO;

	#save, call( convention => cdecl )
	PROCEDURE wmain03() : INTEGER;
	#restore
	BEGIN
	   FSO.CreateDirectoryOA( L"a" );
	   FSO.CreateDirectoryOA( L"a\b\c\d" );
	   FSO.CreateDirectoryOA( L"a\b" );

	   FSO.CreateDirectoryOA( L"d:\buff\a\" );
	   FSO.CreateDirectoryOA( L"d:\buff\a" );
	   FSO.CreateDirectoryOA( L"d:\buff\b" );
	   FSO.CreateDirectoryOA( L"d:\buff\a\b\c" );

		RETURN 0;
	END wmain03;

BEGIN
END TCreateDir.