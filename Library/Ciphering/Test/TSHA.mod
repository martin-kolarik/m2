MODULE TSHA;

FROM Storage IMPORT
   ALLOCATE, DEALLOCATE;

IMPORT
   cphcommon,
   log,
   sha1,
   sha256,
   Strings,
   sync,
   test,
   testimpl;
  
(*===========================================================================*)

TYPE
   TSalt = ARRAY [0..5] OF BYTE;
CONST
   salt = TSalt( 35, 135, 195, 2, 240, 141 );

(*===========================================================================*)

TYPE
   TPTest = POINTER TO CTest;

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
      buffer : ARRAY [0..63] OF BYTE;
      dsha1 : sha1.TDigest;
      Failure : BOOLEAN := FALSE;
      filled : CARDINAL;
      i : CARDINAL;
   BEGIN
      SELF.Host := Host;

      Host^.StartPhase( L"SHA1 plain" );
      
      sha1.DigestOA( C"The quick brown fox jumps over the lazy dog", OUT dsha1 );
      cphcommon.FromHex( L"2fd4e1c67a2d28fced849ee1bb76e7391b93eb12", OUT buffer, OUT filled );
      FOR i := 0 TO HIGH( dsha1 ) DO
         IF dsha1[i] <> buffer[i] THEN
            Failure := TRUE;
            EXIT;
         END;
      END;
      
      sha1.DigestOA( C"The quick brown fox jumps over the lazy cog", OUT dsha1 );
      cphcommon.FromHex( L"de9f2c7fd25e1b3afad3e85a0bd17d9b100db4b3", OUT buffer, OUT filled );
      FOR i := 0 TO HIGH( dsha1 ) DO
         IF dsha1[i] <> buffer[i] THEN
            Failure := TRUE;
            EXIT;
         END;
      END;
      
      IF Failure THEN
         Host^.StopPhaseWithResult( test.trFailure );
      ELSE
         Host^.StopPhaseWithResult( test.trSuccess );
      END;

      Host^.StartPhase( L"SHA1 salted with null salt" );
      
      sha1.DigestSaltOA( C"The quick brown fox jumps over the lazy dog", OA( -1, NIL ), OUT dsha1 );
      cphcommon.FromHex( L"2fd4e1c67a2d28fced849ee1bb76e7391b93eb12", OUT buffer, OUT filled );
      FOR i := 0 TO HIGH( dsha1 ) DO
         IF dsha1[i] <> buffer[i] THEN
            Failure := TRUE;
            EXIT;
         END;
      END;
      
      sha1.DigestSaltOA( C"The quick brown fox jumps over the lazy cog", OA( -1, NIL ), OUT dsha1 );
      cphcommon.FromHex( L"de9f2c7fd25e1b3afad3e85a0bd17d9b100db4b3", OUT buffer, OUT filled );
      FOR i := 0 TO HIGH( dsha1 ) DO
         IF dsha1[i] <> buffer[i] THEN
            Failure := TRUE;
            EXIT;
         END;
      END;
      
      IF Failure THEN
         Host^.StopPhaseWithResult( test.trFailure );
      ELSE
         Host^.StopPhaseWithResult( test.trSuccess );
      END;

      Host^.StartPhase( L"SHA1 salted with some salt" );
      
      sha1.DigestSaltOA( C"The quick brown fox jumps over the lazy dog", salt, OUT dsha1 );
      cphcommon.FromHex( L"1a888abd8ed0fcf282f30fb6191ab89a26cc0b8e", OUT buffer, OUT filled );
      FOR i := 0 TO HIGH( dsha1 ) DO
         IF dsha1[i] <> buffer[i] THEN
            Failure := TRUE;
            EXIT;
         END;
      END;
      
      sha1.DigestSaltOA( C"The quick brown fox jumps over the lazy aog", salt, OUT dsha1 );
      cphcommon.FromHex( L"99328148d93dbe9c83dc04bc0d0073ccabbf1bcd", OUT buffer, OUT filled );
      FOR i := 0 TO HIGH( dsha1 ) DO
         IF dsha1[i] <> buffer[i] THEN
            Failure := TRUE;
            EXIT;
         END;
      END;
      
      IF Failure THEN
         Host^.StopPhaseWithResult( test.trFailure );
      ELSE
         Host^.StopPhaseWithResult( test.trSuccess );
      END;

      Host^.StartPhase( L"SHA1 salted with some long salt" );
      sha1.DigestSaltOA( C"The", salt, OUT dsha1 );
      cphcommon.FromHex( L"141b86831db5a64961d3f2c751794039a2a39b88", OUT buffer, OUT filled );
      FOR i := 0 TO HIGH( dsha1 ) DO
         IF dsha1[i] <> buffer[i] THEN
            Failure := TRUE;
            EXIT;
         END;
      END;
      
      sha1.DigestSaltOA( C"Yes", salt, OUT dsha1 );
      cphcommon.FromHex( L"67322e9221c380621fa282f77355ae3e98d9479c", OUT buffer, OUT filled );
      FOR i := 0 TO HIGH( dsha1 ) DO
         IF dsha1[i] <> buffer[i] THEN
            Failure := TRUE;
            EXIT;
         END;
      END;
      
      IF Failure THEN
         Host^.StopPhaseWithResult( test.trFailure );
      ELSE
         Host^.StopPhaseWithResult( test.trSuccess );
      END;

      IF Failure THEN
         RETURN test.trFailure;
      ELSE
         RETURN test.trSuccess;
      END;
   END Run;
   
(*---------------------------------------------------------------------------*)

BEGIN
   testimpl.tests()^.AddTest( L"Ciphering::SHA", ADR( Test ));
END CTest;

(*===========================================================================*)

END TSHA.
