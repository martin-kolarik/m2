MODULE TDiskInfo;

IMPORT
  DiskInfo;
  
#save, call( convention => cdecl )
PROCEDURE wmain6() : INTEGER;
#restore
VAR
  DI : DiskInfo.CDiskInfo;
  i : CARDINAL;
BEGIN
	FOR i := 0 TO 25 DO
		DiskInfo.LoadDiskInfo( i, OUT DI );
	END;
	RETURN 0;
END wmain6;

END TDiskInfo.