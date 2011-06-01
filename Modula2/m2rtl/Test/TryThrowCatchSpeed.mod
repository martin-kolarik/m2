MODULE TryThrowCatchSpeed;

FROM Storage IMPORT
   ALLOCATE, DEALLOCATE;
FROM Exceptions IMPORT
   Exception, StoreException, TestIfCatched, RetrieveException;

IMPORT
   datetime,
   Exceptions,
   log,
   Strings,
   Sync,
   test,
   testimpl;
  
(*===========================================================================*)

CLASS Exc1( Exceptions.Exception );
END Exc1;

(*---------------------------------------------------------------------------*)

CLASS IMPLEMENTATION Exc1;
END Exc1;

(*===========================================================================*)

CLASS Exc2( Exception );
END Exc2;

(*---------------------------------------------------------------------------*)

CLASS IMPLEMENTATION Exc2;
END Exc2;

(*===========================================================================*)

CLASS CTest IMPLEMENTS test.ITest;
   PRIVATE VAR
      Host : test.TPHost := NIL;

   PUBLIC VIRTUAL PROCEDURE Run( CONST Host : test.TPHost; CONST Parameters : ARRAY OF PWCHAR );

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

   PUBLIC VIRTUAL PROCEDURE Run( CONST Host : test.TPHost; CONST Parameters : ARRAY OF PWCHAR );
   VAR
      i, t : CARDINAL;
   BEGIN
      SELF.Host := Host;
   
      t := datetime.UptimeMS();
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
      
      t := datetime.UptimeMS() - t;
      Host^.Log^.LogSC( log.lcInfo, 0, L"", "Consumed: ", t );
   END Run;
   
(*---------------------------------------------------------------------------*)

   PRIVATE PROCEDURE Try();
   VAR
      VExc1 : Exc1;
      VExc2 : Exc2;
   BEGIN
      IF datetime.UptimeMS() MOD 2 = 0 THEN
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
