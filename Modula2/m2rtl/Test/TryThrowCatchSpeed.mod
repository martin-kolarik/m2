MODULE TryThrowCatchSpeed;

FROM Storage IMPORT
   ALLOCATE, DEALLOCATE;
FROM Exceptions IMPORT
   Exception, StoreException, TestIfCatched, RetrieveException;

IMPORT
   Exceptions,
   log,
   Strings,
   Sync,
   test,
   testimpl,
   time;
  
(*===========================================================================*)

CLASS Exc1( Exceptions.Exception );
   INTERNAL VIRTUAL PROCEDURE Name( OUT S : ARRAY OF WCHAR );
   PUBLIC VIRTUAL PROCEDURE ToString( OUT S : ARRAY OF WCHAR );
END Exc1;

(*---------------------------------------------------------------------------*)

CLASS IMPLEMENTATION Exc1;
   
(*---------------------------------------------------------------------------*)

   INTERNAL VIRTUAL PROCEDURE Name( OUT S : ARRAY OF WCHAR );
   BEGIN
      S := EMIT( %class );
   END Name;

(*---------------------------------------------------------------------------*)

   PUBLIC VIRTUAL PROCEDURE ToString( OUT S : ARRAY OF WCHAR );
   BEGIN
      S := L"";
   END ToString;

(*---------------------------------------------------------------------------*)

END Exc1;

(*===========================================================================*)

CLASS Exc2( Exception );
   INTERNAL VIRTUAL PROCEDURE Name( OUT S : ARRAY OF WCHAR );
   PUBLIC VIRTUAL PROCEDURE ToString( OUT S : ARRAY OF WCHAR );
END Exc2;

(*---------------------------------------------------------------------------*)

CLASS IMPLEMENTATION Exc2;
   
(*---------------------------------------------------------------------------*)

   INTERNAL VIRTUAL PROCEDURE Name( OUT S : ARRAY OF WCHAR );
   BEGIN
      S := EMIT( %class );
   END Name;

(*---------------------------------------------------------------------------*)

   PUBLIC VIRTUAL PROCEDURE ToString( OUT S : ARRAY OF WCHAR );
   BEGIN
      S := L"";
   END ToString;

(*---------------------------------------------------------------------------*)

END Exc2;

(*===========================================================================*)

CLASS CTest IMPLEMENTS test.ITest;
   PRIVATE VAR
      Host : test.TPHost := NIL;

   PUBLIC VIRTUAL PROCEDURE Run( CONST Host : test.TPHost; CONST Parameters : ARRAY OF PWCHAR ) : test.TTestResult;

   PRIVATE PROCEDURE Try() THROWS Exc1, Exc2;
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
      i, t : CARDINAL;
   BEGIN
      SELF.Host := Host;
   
      t := time.UptimeMS();
      FOR i := 0 TO 5000000-1 DO
         TRY
            Try();
         CATCH e : Exc1 DO
            IF e.Code = 0 THEN
               INC( t, 0 );
            END;
         CATCH e : Exc2 DO
            IF e.Code = 0 THEN
               INC( t, 0 );
            END;
         END;
      END;
      
      t := time.UptimeMS() - t;
      Host^.Log^.LogSC( log.lcInfo, 0, L"", "Consumed: ", t );

      RETURN test.trSuccess;
   END Run;
   
(*---------------------------------------------------------------------------*)

   PRIVATE PROCEDURE Try();
   VAR
      VExc1 : Exc1;
      VExc2 : Exc2;
   BEGIN
      IF time.UptimeMS() MOD 2 = 0 THEN
         THROW VExc1;
      ELSE
         THROW VExc2;
      END;
   END Try;

(*---------------------------------------------------------------------------*)

BEGIN
   testimpl.tests()^.AddTest( L"TryThrowCatchSpeed", ADR( Test ));
END CTest;

(*===========================================================================*)

END TryThrowCatchSpeed.