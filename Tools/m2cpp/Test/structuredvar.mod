MODULE structuredvar;

  TYPE
    T1 = ARRAY [0..1] OF BOOLEAN;
    T2 = ARRAY [0..1] OF T1;

  VAR
    V : T2;

BEGIN
  V := T2( T1( FALSE, FALSE ), T1( TRUE, TRUE ));
END structuredvar.