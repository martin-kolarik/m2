MODULE TDirInfo;

IMPORT
	FSO,
	StringsO,
	time;

	#save, call( convention => cdecl )
	PROCEDURE wmain04() : INTEGER;
	#restore
	VAR
		D : FSO.CDirectoryInfo;
		S : StringsO.CString;
		t : time.TDateTime;
		b : BOOLEAN;
	BEGIN
		b := D.StartOA( L"D:\x", L"", FSO.soTopDirectoryOnly, TRUE, FALSE );

		b := D.StartOA( L"D:\buff\", L"", FSO.soTopDirectoryOnly, TRUE, FALSE );
		D.Stop();

		b := D.StartOA( L"D:\buff\", L"", FSO.soTopDirectoryOnly, TRUE, FALSE );
		WHILE b DO
			S := D.Name;
			IF D.Attributes = FSO.TFileAttributes{} THEN END;
			IF D.Size = 0 THEN END;
			t := D.CreationTime;
			t := D.LastAccessTime;
			b := D.MoveNext();
		END; // WHILE

		b := D.StartOA( L"D:\buff\", L"*.rm", FSO.soTopDirectoryOnly, FALSE, TRUE );
		WHILE b DO
			S := D.Name;
			IF D.Attributes = FSO.TFileAttributes{} THEN END;
			IF D.Size = 0 THEN END;
			t := D.CreationTime;
			t := D.LastAccessTime;
			b := D.MoveNext();
		END; // WHILE
	
		RETURN 0;
	END wmain04;

BEGIN
END TDirInfo.