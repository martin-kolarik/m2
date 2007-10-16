MODULE TDirInfo;

IMPORT
	FSO,
	StringsO,
	time;

	#save, call( entry_point => on )
	PROCEDURE wmain() : INTEGER;
	#restore
	VAR
		D : FSO.CDirectoryInfo;
		S : StringsO.CString;
		t : time.TDateTime;
		b : BOOLEAN;
	BEGIN
		b := D.Start( L"D:\x", L"", FSO.soTopDirectoryOnly, TRUE, FALSE );

		b := D.Start( L"D:\buff\", L"", FSO.soTopDirectoryOnly, TRUE, FALSE );
		D.Stop();

		b := D.Start( L"D:\buff\", L"", FSO.soTopDirectoryOnly, TRUE, FALSE );
		WHILE b DO
			S := D.Name;
			IF D.Attributes = {} THEN END;
			IF D.Size = 0 THEN END;
			t := D.CreationTime;
			t := D.LastAccessTime;
			b := D.MoveNext();
		END; // WHILE

		b := D.Start( L"D:\buff\", L"*.rm", FSO.soTopDirectoryOnly, FALSE, TRUE );
		WHILE b DO
			S := D.Name;
			IF D.Attributes = {} THEN END;
			IF D.Size = 0 THEN END;
			t := D.CreationTime;
			t := D.LastAccessTime;
			b := D.MoveNext();
		END; // WHILE
	
		RETURN 0;
	END wmain;

BEGIN
END TDirInfo.