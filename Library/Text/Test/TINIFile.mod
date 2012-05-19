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
  text3 = text2 + line1 + CR + LF + line2 + CR + LF;

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

      Host^.StartPhase( L"Single section with last spaced line" );
      Input.Init( ADR( text1 ), LENGTH( text1 ), IOO.accRead );
      INI.Load( Reader );

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
