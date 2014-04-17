IMPLEMENTATION MODULE Mathematics;
// LONGREAL mathematics

IMPORT
   lr;

//--------------------------------------------------------------------------------

PROCEDURE IsNaN( CONST x : LONGREAL ) : BOOLEAN;
BEGIN
   RETURN lr.IsNaN( x );
END IsNaN;

//--------------------------------------------------------------------------------

PROCEDURE NaN() : LONGREAL;
BEGIN
   RETURN lr.NaN();
END NaN;

//--------------------------------------------------------------------------------

PROCEDURE CloseEnoughEps( x, y, eps : LONGREAL ) : BOOLEAN;
BEGIN
   RETURN ABS( x - y ) < eps;
END CloseEnoughEps;

//--------------------------------------------------------------------------------

PROCEDURE Equals( CONST x, y : LONGREAL ) : BOOLEAN; // Ulps = 4
BEGIN
   RETURN lr.Equals( x, y, lr.DEFAULT_EQUALS_ULPS );
END Equals;

//--------------------------------------------------------------------------------

PROCEDURE EqualsEps( CONST x, y, eps : LONGREAL ) : BOOLEAN;
BEGIN
   RETURN CloseEnoughEps( x, y, eps );
END EqualsEps;

//--------------------------------------------------------------------------------

PROCEDURE EqualsUlps( CONST x, y : LONGREAL; ulps : CARDINAL ) : BOOLEAN;
BEGIN
   RETURN lr.Equals( x, y, ulps );
END EqualsUlps;

//--------------------------------------------------------------------------------

PROCEDURE IsZero( CONST x : LONGREAL ) : BOOLEAN;
BEGIN
   RETURN lr.Equals( x, 0.0, lr.DEFAULT_EQUALS_ULPS );
END IsZero;

//--------------------------------------------------------------------------------

PROCEDURE IsZeroEps( CONST x, eps : LONGREAL ) : BOOLEAN;
BEGIN
   RETURN CloseEnoughEps( x, 0.0, eps );
END IsZeroEps;

//--------------------------------------------------------------------------------

PROCEDURE IsZeroUlps( CONST x : LONGREAL; ulps : CARDINAL ) : BOOLEAN;
BEGIN
   RETURN lr.Equals( x, 0.0, ulps );
END IsZeroUlps;

//--------------------------------------------------------------------------------

END Mathematics.