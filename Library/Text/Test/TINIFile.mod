MODULE TINIFile;

FROM Storage IMPORT
   ALLOCATE, DEALLOCATE;

IMPORT
   INIFile,
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
  line1 = C"[section]";
  line2 = C"key1 = value1";
  line3 = C"  ";
  text1 = line1 + CR + LF + line2 + CR + LF + line3;
  text2 = text1 + CR + LF;
  text1 = text2 + line1 + CR + LF + line2 + CR + LF;

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
      INI : INIFile.CINIFile;
      Input : IOO.CMemoryStream;
      Reader : textreader.CTextReader;
      Result : test.TTestResult := test.trSuccess;
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
   testimpl.tests()^.AddTest( L"INIFile", ADR( Test ));
END CTest;

(*===========================================================================*)

END TINIFile.
