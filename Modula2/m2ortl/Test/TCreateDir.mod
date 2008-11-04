MODULE TCreateDir;

IMPORT
	FIO;

	#save, call( convention => cdecl )
	PROCEDURE wmain03() : INTEGER;
	#restore
	BEGIN
	   FIO.CreateDirectoryW( L"a" );
	   FIO.CreateDirectoryW( L"a\b\c\d" );
	   FIO.CreateDirectoryW( L"a\b" );

	   FIO.CreateDirectoryW( L"d:\buff\a\" );
	   FIO.CreateDirectoryW( L"d:\buff\a" );
	   FIO.CreateDirectoryW( L"d:\buff\b" );
	   FIO.CreateDirectoryW( L"d:\buff\a\b\c" );

		RETURN 0;
	END wmain03;

BEGIN
END TCreateDir.