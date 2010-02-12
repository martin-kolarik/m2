MODULE Asserts;

FROM Debug IMPORT
   Assertion, LogAssertionA, LogAssertionW;

PROCEDURE Test;
BEGIN
   ASSERT( FALSE );
   ASSERTLOG( FALSE, L"Ahoj" );
   ASSERTLOG( FALSE, C"Ahoj" );
   ASSERTLOG( FALSE );
END Test;

(*# save, call( convention => cdecl ) *)
PROCEDURE wmain();
(*# restore *)
BEGIN
   Test();
END wmain;

END Asserts.