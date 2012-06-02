IMPLEMENTATION MODULE Mathematics;

// LONGREAL mathematics

// stubs to NTDLL.DLL
(*# save, call( convention => cdecl ) *)
PROCEDURE pow( base, exponent : LONGREAL ) : LONGREAL; FORWARD;
(*# restore *)

PROCEDURE Power( base, exponent : LONGREAL ) : LONGREAL;
BEGIN
   RETURN pow( base, exponent );
END Power;

END Mathematics.