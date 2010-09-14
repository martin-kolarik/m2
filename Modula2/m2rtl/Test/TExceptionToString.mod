MODULE TExceptionToString;

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
      M2Ex : Exceptions.CModula2Exception;

   PUBLIC VIRTUAL PROCEDURE Run( CONST Host : test.TPHost; CONST Parameters : ARRAY OF PWCHAR ) : test.TTestResult;

   PRIVATE PROCEDURE Try( Which : BOOLEAN ) THROWS Exc1, Exc2;
   PRIVATE PROCEDURE TryM2( Inner : BOOLEAN ) THROWS Exceptions.CModula2Exception;
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
   BEGIN
      SELF.Host := Host;
      
      Host^.StartPhase( L"Exception.ToString" );

      TRY
         Try( FALSE );   
      CATCH e : Exceptions.Exception DO
         Host^.Log^.LogExc( log.lcError, 0, L"", e );
      END;

      TRY
         Try( TRUE );   
      CATCH e : Exceptions.Exception DO
         Host^.Log^.LogExc( log.lcError, 0, L"", e );
      END;

      Host^.StopPhase();

      Host^.StartPhase( L"M2Exception.ToString" );

      TRY
         TryM2( FALSE );
      CATCH e : Exceptions.Exception DO
         Host^.Log^.LogExc( log.lcError, 0, L"", e );
      END;

      TRY
         TryM2( TRUE );
      CATCH e : Exceptions.Exception DO
         Host^.Log^.LogExc( log.lcError, 0, L"", e );
      END;

      Host^.StopPhase();

      RETURN test.trSuccess;
   END Run;
   
(*---------------------------------------------------------------------------*)

   PRIVATE PROCEDURE Try( Which : BOOLEAN );
   VAR
      VExc1 : Exc1;
      VExc2 : Exc2;
   BEGIN
      IF Which THEN
         THROW VExc1;
      ELSE
         THROW VExc2;
      END;
   END Try;

(*---------------------------------------------------------------------------*)

   PRIVATE PROCEDURE TryM2( Inner : BOOLEAN );
   BEGIN
      IF Inner THEN
         M2Ex.Init( NIL, L"TryM2", L"Text of inner exception", Exceptions.mexMethodNotImplemented );
         THROW Exceptions.Modula2Exception( ADR( M2Ex ), L"Test", L"Text of test exception.", Exceptions.mexNotSupported );
      ELSE
         THROW Exceptions.Modula2Exception( NIL, L"Test", L"Text of test exception.", Exceptions.mexNotSupported );
      END;
   END TryM2;

(*---------------------------------------------------------------------------*)

BEGIN
   testimpl.tests()^.AddTest( L"ExceptionToString", ADR( Test ));
END CTest;

(*===========================================================================*)

END TExceptionToString.