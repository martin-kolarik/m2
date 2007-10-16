MODULE lrconvround;

IMPORT
   lrconv,
   Strings,
   Time,
   windows;
   
   PROCEDURE Out( s : ARRAY OF WCHAR );
   CONST
      CRLF = 13W + 10W;
   BEGIN
      windows.OutputDebugString( ADR( s ));
      windows.OutputDebugString( ADR( CRLF ));
   END Out;
  
   #save, call( convention => cdecl )
   PROCEDURE wmain() : INTEGER;
   #restore
   TYPE
      TestA = ARRAY [0..41] OF LONGREAL;
   CONST
      testA = TestA(
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
   BEGIN

      FOR i := 0 TO HIGH( testA ) DO
         Out( L"==========" );
         Strings.FromLONGREALW( testA[i], -1, -1, OUT S ); Out( S );
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

      RETURN 0;
   END wmain;

END lrconvround.