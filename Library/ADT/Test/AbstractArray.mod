MODULE abstractarray;

IMPORT
  array;
  
VAR
  AR : array.CArray;  

PROCEDURE ArrayTest();
VAR
  I : CARDINAL;
BEGIN
  AR.Strategy := array.astrgListInArray;
  AR.ItemSize := 4;
  FOR I := 0 TO 1499 DO
    AR.Add( I );
  END;
  FOR I := 0 TO 1499 DO
    AR.Remove( I );
  END;
  FOR I := 0 TO 1499 DO
    AR.Add( I );
  END;
  FOR I := 1499 TO 0 BY -1 DO
    AR.Remove( I );
  END;
  FOR I := 0 TO 1499 DO
    AR.Insert( 0, I );
  END;
  FOR I := 0 TO 1499 DO
    AR.Remove( I );
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