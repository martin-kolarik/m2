MODULE TXMLWriter;

FROM Storage IMPORT
   ALLOCATE, DEALLOCATE;
FROM Exceptions IMPORT
   TestIfCatched, RetrieveException;

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
		
		X.WriteElementStartOA( L"", L"shell" );
			X.WriteElementStartOA( L"", L"top" );
				X.WriteAttributeStringOA( L"", L"name", L"Krtecek" );
				X.WriteAttributeStartOA( L"", L"type" );
					X.WriteStringOA( L"some type" );
				X.WriteAttributeEnd();
				X.WriteElementStringOA( L"", "p", "and some animals..." );
			X.WriteElementEnd();
			X.WriteElementStringOA( L"", "p", 'and some more "animals"...' );
			X.WriteElementStringOA( L"", "p", 'and some more "animals"...' );
		X.WriteElementEnd();

		X.Close( FALSE );

      Host^.StopPhaseWithResult( NOT Failure);

      RETURN test.trUnknown;
   END Run;
   
(*---------------------------------------------------------------------------*)

BEGIN
   testimpl.tests()^.AddTest( L"XML::XMLWriter", ADR( Test ));
END CTest;

(*===========================================================================*)

END TXMLWriter.