MODULE proctype;

  TYPE
(*# save, call( prefix=>stdcall, o_a_size=>off ) *)
    P = PROCEDURE( ADDRESS, REAL ) : REAL;
(*# restore *)

  VAR
    V : P;

BEGIN
  V := P( NIL );
  V( NIL, 2.0 );
END proctype.