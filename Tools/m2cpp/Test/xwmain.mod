MODULE xwmain;

TYPE
  TParamString       = ARRAY[0..511] OF WCHAR;
  TPParamString      = POINTER TO TParamString;
  TParamStringArray  = ARRAY [0..0] OF TPParamString;
  TPParamStringArray = POINTER TO TParamStringArray;

(*# save, call( o_a_copy=>off, 
                prefix=>cdecl ),
                option( export => on ),
                call( entry_point => on ) *)
PROCEDURE wmain( argc : INTEGER; argp : TPParamStringArray; enpv : TPParamStringArray ) : BOOLEAN; FORWARD;
(*# restore *)

(*===========================================================================*)

PROCEDURE wmain( argc : INTEGER; argp : TPParamStringArray; enpv : TPParamStringArray ) : BOOLEAN;
BEGIN
  RETURN FALSE;
END wmain;

FINALLY Done();
BEGIN
END Done;

BEGIN
END xwmain.