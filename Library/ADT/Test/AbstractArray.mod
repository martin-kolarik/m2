MODULE abstractarray;

IMPORT
  array;
  
VAR
  AR : array.CArray;  

PROCEDURE ArrayTest();
VAR
  I : CARDINAL;
BEGIN
  AR.Init( array.astrgListInArray, 4 );
  FOR I := 0 TO 1499 DO
    AR.Add( ADR( I ), 4 );
  END;
  FOR I := 0 TO 1499 DO
    AR.Remove( ADR( I ), 4 );
  END;
  FOR I := 0 TO 1499 DO
    AR.Add( ADR( I ), 4 );
  END;
  FOR I := 1499 TO 0 BY -1 DO
    AR.Remove( ADR( I ), 4 );
  END;
  FOR I := 0 TO 1499 DO
    AR.Insert( 0, ADR( I ), 4 );
  END;
  FOR I := 0 TO 1499 DO
    AR.Remove( ADR( I ), 4 );
  END;
END ArrayTest;

#save, call( convention => cdecl ) *)  
PROCEDURE wmain() : INTEGER;
BEGIN
  ArrayTest();
  RETURN 0;
END wmain;
#restore
  
END abstractarray.