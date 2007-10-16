MODULE IntegerArray;

IMPORT
  array,
  arrays;
  
PROCEDURE ArrayTest();
VAR
  AR : arrays.CIntegerArray;  
  I : CARDINAL;
BEGIN
  AR.Strategy := array.astrgListInArray;
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

#save, call( convention => cdecl, entry_point => on ) *)  
PROCEDURE wmain() : INTEGER;
BEGIN
  ArrayTest();
  RETURN 0;
END wmain;
#restore
  
END IntegerArray.