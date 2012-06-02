MODULE lrconvround;

FROM Debug IMPORT
   AssertionW;

FROM Storage IMPORT
   ALLOCATE, DEALLOCATE;

IMPORT
   log,
   lrconv,
   Strings,
   test,
   testimpl;
  
(*===========================================================================*)

CLASS CTest IMPLEMENTS test.ITest;
   PUBLIC VIRTUAL PROCEDURE Run( CONST Host : test.TPHost; CONST Parameters : ARRAY OF PWCHAR ) : test.TTestResult;
END CTest;

(*---------------------------------------------------------------------------*)

TYPE
   TPTest = POINTER TO CTest;
VAR
   Test : CTest;

(*===========================================================================*)

CLASS IMPLEMENTATION CTest;

(*---------------------------------------------------------------------------*)

   PUBLIC VIRTUAL PROCEDURE Run( CONST Host : test.TPHost; CONST Parameters : ARRAY OF PWCHAR ) : test.TTestResult;
   TYPE
      TestA = ARRAY [0..42] OF LONGREAL;
   CONST
      testA = TestA(
                  1372.0/5000.0,
                  123456.7788997788,
                  12.34,
                  999.999,
                  0.999999,
                  0.1,
                  0.100009,
                  0.0009998765432,
                  -123456.7788997788,
                  -12.34,
                  -999.999,
                  -0.999999,
                  -0.1,
                  -0.100009,
                  -0.0009998765432,
                  123456.7788997788E20,
                  12.34E20,
                  999.999E20,
                  0.999999E20,
                  0.1E20,
                  0.100009E20,
                  0.0009998765432E20,
                  -123456.7788997788E20,
                  -12.34E20,
                  -999.999E20,
                  -0.999999E20,
                  -0.1E20,
                  -0.100009E20,
                  -0.0009998765432E20,
                  123456.7788997788E-20,
                  12.34E-20,
                  999.999E-20,
                  0.999999E-20,
                  0.1E-20,
                  0.100009E-20,
                  0.0009998765432E-20,
                  -123456.7788997788E-20,
                  -12.34E-20,
                  -999.999E-20,
                  -0.999999E-20,
                  -0.1E-20,
                  -0.100009E-20,
                  -0.0009998765432E-20
               );
   VAR
      i, j : CARDINAL;
      S : ARRAY [0..255] OF WCHAR;

      PROCEDURE Out( s : ARRAY OF WCHAR );
      BEGIN
         Host^.Log^.LogS( log.lcError, 0, L"", s );
      END Out;

   BEGIN
      Host^.StartPhase( L"LONGREAL rounding" );

      FOR i := 0 TO HIGH( testA ) DO
         Out( L"==========" );
         Strings.FromLONGREALExtW( testA[i], -1, -1, FALSE, L"", OUT S ); Out( S );
         lrconv.LONGREALToStrW( testA[i], -1, -1, FALSE, 0W, OUT S ); Out( S );
         FOR j := 0 TO 15 DO
            Out( L"----------" );
            lrconv.LONGREALToStrW( testA[i], -1, j, FALSE, 0W, OUT S ); Out( S );
            lrconv.LONGREALToStrW( testA[i], j, -1, FALSE, 0W, OUT S ); Out( S );
            lrconv.LONGREALToStrW( testA[i], j, 3, FALSE, 0W, OUT S ); Out( S );
            // lrconv.LONGREALToStrW( testA[i], -1, j, TRUE, 0W, OUT S ); Out( S );
            // lrconv.LONGREALToStrW( testA[i], j, -1, TRUE, 0W, OUT S ); Out( S );
            lrconv.LONGREALToStrW( testA[i], j, 3, TRUE, 0W, OUT S ); Out( S );
         END;
      END;

      Host^.StopPhase();

      RETURN test.trSuccess;
   END Run;
   
(*---------------------------------------------------------------------------*)

BEGIN
   testimpl.tests()^.AddTest( L"LONGREALRounding", ADR( Test ));
END CTest;

(*===========================================================================*)

END lrconvround.