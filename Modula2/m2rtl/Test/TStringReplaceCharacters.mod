MODULE TStringReplaceCharacters;

FROM Debug IMPORT
   Assertion;

FROM Storage IMPORT
   ALLOCATE, DEALLOCATE;

IMPORT
   log,
   Strings,
   Sync,
   SyncQueue,
   test,
   testimpl,
   time,
   windows;
  
(*===========================================================================*)

CLASS CTest IMPLEMENTS test.ITest;
   PRIVATE VAR
      Host : test.TPHost := NIL;

   PUBLIC VIRTUAL PROCEDURE Run( CONST Host : test.TPHost; CONST Parameters : ARRAY OF PWCHAR ) : test.TTestResult;
   
   INITIALLY CTest;
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
   VAR
      Failure : BOOLEAN := FALSE;
      s0, s1, sr : ARRAY [0..225] OF WCHAR;
   BEGIN
      SELF.Host := Host;
      s0 := L"abcdefghijklmnopqrstuvwxyz";
      
      s1 := s0;
      sr := L"aaaaaaaaaaaaaaaaaaaaaaaaaa";
      Strings.ReplaceCharactersW( REF s1, L"bcdefghijklmnopqrstuvwxyz", L"aaaaaaaaaaaaaaaaaaaaaaaaa" );
      IF NOT EQUALS( s1, sr ) THEN
         Failure := TRUE;
      END;
   
      s1 := s0;
      sr := s0;
      Strings.ReplaceCharactersW( REF s1, s0, L"a" );
      IF NOT EQUALS( s1, sr ) THEN
         Failure := TRUE;
      END;

      s1 := s0;
      sr := L"AbcdEfghIjklmnOpqrstUvwxYz";
      Strings.ReplaceCharactersW( REF s1, L"aeiouy", L"AEIOUY" );
      IF NOT EQUALS( s1, sr ) THEN
         Failure := TRUE;
      END;

      s1 := L"ûluùouËk˝ k˘Ú ˙pÏl Ô·belskÈ Ûdy éLUçOU»K› KŸ“ ⁄PÃL œ¡BELSK… ”DY";
      sr := L"zlutoucky kun upel dabelske ody ZLUTOUCKY KUN UPEL DABELSKE ODY";
      Strings.TrimAccentsW( REF s1 );
      IF NOT EQUALS( s1, sr ) THEN
         Failure := TRUE;
      END;

      IF Failure THEN
         RETURN test.trFailure;
      ELSE
         RETURN test.trSuccess;
      END;
   END Run;
   
(*---------------------------------------------------------------------------*)

   INITIALLY CTest;
   BEGIN
      testimpl.tests()^.AddTest( L"String::ReplaceCharacters", ADR( Test ));
   END CTest;
      
(*---------------------------------------------------------------------------*)

END CTest;

(*===========================================================================*)

END TStringReplaceCharacters.