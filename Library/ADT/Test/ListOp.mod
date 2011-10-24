MODULE ListOp;

FROM Storage IMPORT
  ALLOCATE;

IMPORT
  list;
  
CLASS CILE( list.CListElem );
  I : INTEGER;
END CILE;

CLASS IMPLEMENTATION CILE;
BEGIN
  I := -1;
END CILE;
  
PROCEDURE ListTest();
VAR
  E1, E2, E3 : POINTER TO CILE;
  L : list.CList;
  b : BOOLEAN;
BEGIN
  NEW( E1 ); E1^.I := 3; L.Add( E1 );
  NEW( E1 ); E1^.I := 4; L.Add( E1 );
  NEW( E1 ); E1^.I := 5; L.Add( E1 );
  NEW( E1 ); E1^.I := 7; L.Add( E1 ); E3 := E1;
  NEW( E1 ); E1^.I := 8; L.Add( E1 );
  NEW( E1 ); E1^.I := 9; L.Add( E1 );
  
  NEW( E2 ); E2^.I := 2; L.InsertFirst( E2 );
  NEW( E1 ); E1^.I := 1; L.InsertBefore( E2, E1 );

  NEW( E1 ); E1^.I := 6; L.InsertBefore( E3, E1 );
  
  b := L.colGetFirst( OUT E1 );
  WHILE b DO
    IF E1^.I MOD 2 = 0 THEN
      b := L.colNextOf( E1, OUT E2 );
      L.Delete( E1 );
      E1 := E2;
    ELSE
      b := L.colNextOf( E1, OUT E1 );
    END;
  END;
END ListTest;

#save, call( convention => cdecl ) *)  
PROCEDURE wmain01() : INTEGER;
BEGIN
  ListTest();
  RETURN 0;
END wmain01;
#restore
  
END ListOp.