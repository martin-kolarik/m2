MODULE TxtReader;

FROM Storage IMPORT
   ALLOCATE, DEALLOCATE;

IMPORT
   IOO,
   log,
   Strings,
   StringsO,
   Sync,
   test,
   testimpl,
   textreader;
  
(*===========================================================================*)

CONST
  CR = 13C;
  LF = 10C;
  line1 = C"line1" + CR + C"line1";
  line2 = C"";
  line3 = C"// line3";
  line4 = C"line4";
  text1 = line1 + CR + LF + line2 + CR + LF + line3 + CR + LF + line4;
  text2 = text1 + CR + LF;
  text3 = line1 + LF + line2 + LF + line3 + LF + line4;
  text4 = text3 + LF;

(*---------------------------------------------------------------------------*)

CLASS CTest IMPLEMENTS test.ITest;
   PUBLIC VAR
      Host : test.TPHost := NIL;
   PUBLIC VIRTUAL PROCEDURE Run( CONST Host : test.TPHost; CONST Parameters : ARRAY OF PWCHAR ) : test.TTestResult;
END CTest;

(*===========================================================================*)

VAR
   Test : CTest;

(*---------------------------------------------------------------------------*)

CLASS IMPLEMENTATION CTest;

(*---------------------------------------------------------------------------*)

   PUBLIC VIRTUAL PROCEDURE Run( CONST Host : test.TPHost; CONST Parameters : ARRAY OF PWCHAR ) : test.TTestResult;
   VAR
      Input : IOO.CMemoryStream;
      Reader : textreader.CTextReader;
      Result : test.TTestResult := test.trSuccess;
      
      //-----
      
      PROCEDURE CharLoop( Template : ARRAY OF CHAR ) : test.TTestResult;
      VAR
         Ch : WCHAR;
         Index : CARDINAL;
         Result : test.TTestResult := test.trSuccess;
      BEGIN
         Index := 0;

         WHILE Reader.ReadChar( OUT Ch, Sync.FOREVER, TRUE ) = Sync.arCompleted DO
            IF Ch <> WCHAR( Template[Index] ) THEN
               Host^.Log^.LogS( log.dlcError, L"", L"Unexpected char found" );
               Result := test.trFailure;
            END;
            INC( Index );
         END;
         IF Index < HIGH( Template ) + 1 THEN
            Host^.Log^.LogS( log.dlcError, L"", L"Some char unread" );
         END;
         
         RETURN Result;
      END CharLoop;
      
      //-----
      
      PROCEDURE CharSLoop( Template : ARRAY OF CHAR ) : test.TTestResult;
      VAR
         Ch : WCHAR;
         Index : CARDINAL;
         Result : test.TTestResult := test.trSuccess;
      BEGIN
         Index := 0;

         WHILE Reader.ReadCharS( OUT Ch ) DO
            IF Ch <> WCHAR( Template[Index] ) THEN
               Host^.Log^.LogS( log.dlcError, L"", L"Unexpected char found" );
               Result := test.trFailure;
            END;
            INC( Index );
         END;
         IF Index < HIGH( Template ) + 1 THEN
            Host^.Log^.LogS( log.dlcError, L"", L"Some char unread" );
         END;
         
         RETURN Result;
      END CharSLoop;
      
      //-----
      
      PROCEDURE LineLoop( SFlag : BOOLEAN ) : test.TTestResult;
      VAR
         Line : StringsO.CString;
         line : StringsO.CString;
         Result : test.TTestResult := test.trSuccess;
      BEGIN
         line.FromOAA( 0, line1 );
         IF SFlag THEN
            Reader.ReadLineS( OUT Line );
         ELSE
            Reader.ReadLine( OUT Line, Sync.FOREVER, TRUE );
         END;
         IF NOT Line.Equals( line ) THEN
            Host^.Log^.LogS( log.dlcError, L"", L"line1 differs" );
            Result := test.trFailure;
         END;

         line.FromOAA( 0, line2 );
         IF SFlag THEN
            Reader.ReadLineS( OUT Line );
         ELSE
            Reader.ReadLine( OUT Line, Sync.FOREVER, TRUE );
         END;
         IF NOT Line.Equals( line ) THEN
            Host^.Log^.LogS( log.dlcError, L"", L"line2 differs" );
            Result := test.trFailure;
         END;

         line.FromOAA( 0, line3 );
         IF SFlag THEN
            Reader.ReadLineS( OUT Line );
         ELSE
            Reader.ReadLine( OUT Line, Sync.FOREVER, TRUE );
         END;
         IF NOT Line.Equals( line ) THEN
            Host^.Log^.LogS( log.dlcError, L"", L"line3 differs" );
            Result := test.trFailure;
         END;
         
         line.FromOAA( 0, line4 );
         IF SFlag THEN
            Reader.ReadLineS( OUT Line );
         ELSE
            Reader.ReadLine( OUT Line, Sync.FOREVER, TRUE );
         END;
         IF NOT Line.Equals( line ) THEN
            Host^.Log^.LogS( log.dlcError, L"", L"line4 differs" );
            Result := test.trFailure;
         END;

         RETURN Result;
      END LineLoop;

      //-----

   BEGIN
      SELF.Host := Host;
      Reader.Stream := ADR( Input );

      //=====

      Host^.StartPhase( L"ReadChar W / 1" );
      Input.Init( ADR( text1 ), LENGTH( text1 ), IOO.accRead );
      Result := CharLoop( text1 );
      Host^.StopPhaseWithResult( Result );
      
      //=====

      Host^.StartPhase( L"ReadChar W / 3" );
      Input.Init( ADR( text3 ), LENGTH( text3 ), IOO.accRead );
      Result := CharLoop( text3 );
      Host^.StopPhaseWithResult( Result );
      
      //=====

      Host^.StartPhase( L"ReadCharS W / 1" );
      Input.Init( ADR( text1 ), LENGTH( text1 ), IOO.accRead );
      Result := CharSLoop( text1 );
      Host^.StopPhaseWithResult( Result );
      
      //=====

      Host^.StartPhase( L"ReadCharS W / 3" );
      Input.Init( ADR( text3 ), LENGTH( text3 ), IOO.accRead );
      Result := CharSLoop( text3 );
      Host^.StopPhaseWithResult( Result );
      
      //=====

      Host^.StartPhase( L"ReadLine W / 1" );
      Input.Init( ADR( text1 ), LENGTH( text1 ), IOO.accRead );
      Result := LineLoop( FALSE );
      Host^.StopPhaseWithResult( Result );
      
      //=====

      Host^.StartPhase( L"ReadLine W / 2" );
      Input.Init( ADR( text2 ), LENGTH( text2 ), IOO.accRead );
      Result := LineLoop( FALSE );
      Host^.StopPhaseWithResult( Result );
      
      //=====

      Host^.StartPhase( L"ReadLine W / 3" );
      Input.Init( ADR( text3 ), LENGTH( text3 ), IOO.accRead );
      Result := LineLoop( FALSE );
      Host^.StopPhaseWithResult( Result );
      
      //=====

      Host^.StartPhase( L"ReadLine W / 4" );
      Input.Init( ADR( text4 ), LENGTH( text4 ), IOO.accRead );
      Result := LineLoop( FALSE );
      Host^.StopPhaseWithResult( Result );
      
      //=====

      Host^.StartPhase( L"ReadLineS W / 1" );
      Input.Init( ADR( text1 ), LENGTH( text1 ), IOO.accRead );
      Result := LineLoop( TRUE );
      Host^.StopPhaseWithResult( Result );
      
      //=====

      Host^.StartPhase( L"ReadLineS W / 2" );
      Input.Init( ADR( text2 ), LENGTH( text2 ), IOO.accRead );
      Result := LineLoop( TRUE );
      Host^.StopPhaseWithResult( Result );
      
      //=====

      Host^.StartPhase( L"ReadLineS W / 3" );
      Input.Init( ADR( text3 ), LENGTH( text3 ), IOO.accRead );
      Result := LineLoop( TRUE );
      Host^.StopPhaseWithResult( Result );
      
      //=====

      Host^.StartPhase( L"ReadLineS W / 4" );
      Input.Init( ADR( text4 ), LENGTH( text4 ), IOO.accRead );
      Result := LineLoop( TRUE );
      Host^.StopPhaseWithResult( Result );
      
      //=====

      RETURN Result;
   END Run;
   
(*---------------------------------------------------------------------------*)

BEGIN
   testimpl.tests()^.AddTest( L"TextReader", ADR( Test ));
END CTest;

(*===========================================================================*)

(*
  TRY
    F.FromPath( L'Test\TxtReaderUTF8.txt', FIOO.imOpenRead );
  CATCH : IOO.CIOException DO
  END;
  R.Stream := ADR( F );
  WHILE R.ReadLine( OUT S, Sync.INFINITE_TIME, TRUE ) = Sync.arCompleted DO
    FIO.WrStrW( f, OAsz( S.szData )); FIO.WrLnW( f );
  END; // WHILE

  TRY
    F.FromPath( L'Test\TxtReaderUTF8.txt', FIOO.imOpenRead );
  CATCH : IOO.CIOException DO
  END;
  S.FromOA( L"//" );
  R.Stream := ADR( F );
  R.CommentaryStart := S;
  WHILE R.ReadLine( OUT S, Sync.INFINITE_TIME, TRUE ) = Sync.arCompleted DO
    FIO.WrStrW( f, OAsz( S.szData )); FIO.WrLnW( f );
  END; // WHILE

  TRY
    F.FromPath( L'Test\TxtReaderUTF8.txt', FIOO.imOpenRead );
  CATCH : IOO.CIOException DO
  END;
  R.Stream := ADR( F );
  R.StartReading();
  WHILE R.Peek( OUT a, OUT l ) DO
    FIO.WrStrW( f, OA( l>>1-1, a )); FIO.WrLnW( f );
    R.ReadOut( l );
  END; // WHILE

  TRY
    F.FromPath( L'Test\TxtReaderUTF8.txt', FIOO.imOpenRead );
  CATCH : IOO.CIOException DO
  END;
  R.Stream := ADR( F );
  R.StartReading();
  WHILE R.Peek( OUT a, OUT l ) DO
    R.ReadLine( OUT S, Sync.INFINITE_TIME, TRUE );
    FIO.WrStrW( f, OAsz( S.szData )); FIO.WrLnW( f );
  END; // WHILE
END Test;
*)

END TxtReader.
