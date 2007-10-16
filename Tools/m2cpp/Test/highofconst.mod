MODULE highofconst;

  PROCEDURE OC( C : ARRAY OF CHAR );
  CONST
    cString = 'AAA';
  BEGIN
    OC( cString );
  END OC;

END highofconst.