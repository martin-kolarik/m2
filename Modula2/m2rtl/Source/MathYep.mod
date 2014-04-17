IMPLEMENTATION MODULE MathYep;
// LONGREAL mathematics
// now based on yeppp! (http://www.yeppp.info/) to avoid using of MSVCRT's functions

FROM yepLibrary IMPORT
   Yep64f,
   YepStatus,
   YepStatusOk,
   yepLibrary_Init,
   yepLibrary_Release;
FROM yepMath IMPORT
   yepMath_Log_V64f_V64f,
   yepMath_Exp_V64f_V64f;

// packing support
// TODO: should not be needed for Yeppp! 1.0.1 (not released in the time of writting this code)
TYPE
   ARGS = RECORD
             in1 : Yep64f;
             in2 : Yep64f;
             out : Yep64f;
             tmp : Yep64f;
          END; // ARGS
   PARGS = POINTER TO ARGS;

PROCEDURE Power( base, exponent, fallback : LONGREAL ) : LONGREAL;
VAR
   args : ARRAY [0..5] OF LONGREAL;
   pargs : PARGS := PARGS( ADR( args ));
   yr : YepStatus;
BEGIN
   // parameters
   IF base <= 0.0 THEN
      RETURN fallback;
   END;

   // align
   IF PTR( pargs ) MOD 8 = 4 THEN
      INC( pargs, 4 );
   END;

   pargs^.in1 := base;
   yr := yepMath_Log_V64f_V64f( OA( 0, ADR( pargs^.in1 )), OUT OA( 0, ADR( pargs^.tmp )), 1 );
   IF yr <> YepStatusOk THEN
      RETURN fallback;
   END;
   pargs^.tmp := exponent * pargs^.tmp;
   yr := yepMath_Exp_V64f_V64f( OA( 0, ADR( pargs^.tmp )), OUT OA( 0, ADR( pargs^.out )), 1 );
   IF yr = YepStatusOk THEN
     RETURN pargs^.out;
   ELSE
      RETURN fallback;
   END;
END Power;

BEGIN
   yepLibrary_Init();
FINALLY
   yepLibrary_Release();
END MathYep.