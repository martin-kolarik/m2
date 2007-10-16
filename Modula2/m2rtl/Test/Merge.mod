MODULE Merge;

PROCEDURE DoAvgByMerge( Path1, Path2 : ARRAY OF WCHAR );
VAR
  f1, f2 : FIO.File;
BEGIN
  f1 := FIO.OpenRead( Path1 );
  f2 := FIO.OpenRead( Path2 );
  
  r1 := TRUE;
  r2 := TRUE;
  LOOP
    IF r1 THEN
      FIO.RdStrW( f1, OUT l1 );
      c := Strings.IndexOfCharW( l1, L' ' );
    END;
    IF r2 THEN
      FIO.RdStrA( f2, OUT l2 );
    
      
  END; // LOOP
END DoAvgByMerge;

END Merge.