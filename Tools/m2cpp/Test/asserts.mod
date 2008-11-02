MODULE Asserts;

FROM Debug IMPORT
   Assertion, LogAssertionA, LogAssertionW;

PROCEDURE Test;
BEGIN
   ASSERT( FALSE );
   ASSERTLOG( FALSE, L"" );
   ASSERTLOG( FALSE, C"" );
   ASSERTLOG( FALSE );
END Test;

END Asserts.