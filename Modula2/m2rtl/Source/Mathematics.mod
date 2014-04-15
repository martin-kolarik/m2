IMPLEMENTATION MODULE Mathematics;
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

PROCEDURE Power( base, exponent : LONGREAL ) : LONGREAL;
VAR
   basealigned : Yep64f := base;
   lnbase : Yep64f;
   result : Yep64f := 0.0;
   yr : YepStatus;
BEGIN
   yr := yepMath_Log_V64f_V64f( OA( 0, ADR( basealigned )), OUT OA( 0, ADR( lnbase )), 1 );
   IF yr <> YepStatusOk THEN
      RETURN 0.0;
   END;
   lnbase := exponent * lnbase;
   yr := yepMath_Exp_V64f_V64f( OA( 0, ADR( lnbase )), OUT OA( 0, ADR( result )), 1 );
   IF yr = YepStatusOk THEN
     RETURN result;
   ELSE
      RETURN 0.0;
   END;
END Power;

BEGIN
   yepLibrary_Init();
FINALLY
   yepLibrary_Release();
END Mathematics.