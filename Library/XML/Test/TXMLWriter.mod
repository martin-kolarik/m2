MODULE TXMLWriter;

FROM Storage IMPORT
   ALLOCATE, DEALLOCATE;

IMPORT
   FIOO,
   IOO,
   log,
   Strings,
   StringsO,
   sync,
   test,
   testimpl,
   XMLWriter;
  
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
	   Failure : BOOLEAN := FALSE;
		S : FIOO.CFileStream;
		X : XMLWriter.CXMLWriter;
	BEGIN
      SELF.Host := Host;

      Host^.StartPhase( L"Try load a file" );
      
	   TRY
		   S.FromPath( L"D:\buff\Test.xml", FIOO.imCreate );
		CATCH e : IOO.CIOException DO
		END;
		X.Stream := ADR( S );
		
		X.WriteElementStartOA( L"shell" );
			X.WriteElementStartOA( L"top" );
				X.WriteAttributeStringOA( L"name", L"Krtecek" );
				X.WriteAttributeStartOA( L"type" );
					X.WriteStringOA( L"some type" );
				X.WriteAttributeEnd();
				X.WriteElementStringOA( "p", "and some animals..." );
			X.WriteElementEnd();
			X.WriteElementStringOA( "p", 'and some more "animals"...' );
			X.WriteElementStringOA( "p", 'and some more "animals"...' );
		X.WriteElementEnd();

		X.Close( FALSE );

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
   testimpl.tests()^.AddTest( L"XML::XMLWriter", ADR( Test ));
END CTest;

(*===========================================================================*)

END TXMLWriter.