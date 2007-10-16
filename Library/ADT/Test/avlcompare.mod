MODULE avlcompare;

FROM Storage IMPORT ALLOCATE;

IMPORT
  windows,
  vtree,
  vtree_ex,
  avltree;

VAR
  N1, N2 : CARDINAL := 0;
  
TYPE
  TPE1 = POINTER TO CE1;

CLASS CE1( vtree_ex.CAVLTreeElemO );
  Key : INTEGER;
  VIRTUAL PROCEDURE Compare( pelem : vtree.TPAVLTreeElem ) : INTEGER;
END CE1;

CLASS IMPLEMENTATION CE1;
  VIRTUAL PROCEDURE CE1.Compare( pelem : vtree.TPAVLTreeElem ) : INTEGER;
  BEGIN
    INC( N1 );
    IF TPE1( pelem )^.Key < Key THEN
      RETURN 1;
    ELSIF TPE1( pelem )^.Key > Key THEN
      RETURN -1;
    ELSE
      RETURN 0;
    END;
  END CE1.Compare;
END CE1;

TYPE
  TPE2 = POINTER TO CE2;

CLASS CE2( avltree.CAVLTreeElem );
  Key : INTEGER;
  VIRTUAL PROCEDURE Compare( pelem : avltree.TPAVLTreeElem ) : TRISTATE;
END CE2;

CLASS IMPLEMENTATION CE2;
  VIRTUAL PROCEDURE CE2.Compare( pelem : avltree.TPAVLTreeElem ) : TRISTATE;
  BEGIN
    INC( N2 );
    IF TPE2( pelem )^.Key < Key THEN
      RETURN 1;
    ELSIF TPE2( pelem )^.Key > Key THEN
      RETURN -1;
    ELSE
      RETURN 0;
    END;
  END CE2.Compare;
END CE2;

#save, call( prefix=>cdecl, entry_point=>on )
PROCEDURE wmain();
VAR
  c : CARDINAL;
  i : INTEGER;
  PE1, PE1x : TPE1;
  PE2, PE2x : TPE2;
  T1 : vtree_ex.CAVLTreeO;
  T2 : avltree.CAVLTree;
  ti1, ti2, tr1, tr2 : CARDINAL;
BEGIN

  ti1 := windows.GetTickCount();
  FOR i := 0 TO 999999 DO
    NEW( PE1 );
    PE1^.Key := i;
    T1.Insert( PE1 );
  END;
  ti1 := windows.GetTickCount() - ti1;

(*  
  NEW( PE1 );     
  tr1 := windows.GetTickCount();
  FOR i := 250000 TO 749999 DO
    PE1^.Key := i;
    T1.Remove( PE1, PE1x );
  END;
  tr1 := windows.GetTickCount() - tr1;
*)  
  
  T1.GetElemOfOrder( 250000, PE1x );
  T1.GetOrderOfElem( PE1x, c );

  ti2 := windows.GetTickCount();
  FOR i := 0 TO 999999 DO
    NEW( PE2 );
    PE2^.Key := i;
    T2.Insert( PE2 );
  END;
  ti2 := windows.GetTickCount() - ti2;

(*
  NEW( PE2 );
  tr2 := windows.GetTickCount();
  FOR i := 250000 TO 749999 DO
    PE2^.Key := i;
    T2.Remove( PE2, OUT PE2x );
  END;
  tr2 := windows.GetTickCount() - tr2;
*)
  
  PE2x := TPE2( T2[250000] );
  i := T2.IndexOf( PE2x );

END wmain;
#restore

BEGIN
END avlcompare.