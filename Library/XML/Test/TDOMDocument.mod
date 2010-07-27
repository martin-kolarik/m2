MODULE TDOMDocument;

FROM Storage IMPORT
   ALLOCATE, DEALLOCATE;

IMPORT
   com,
   DOM,
   FIOO,
   IOO,
   log,
   Strings,
   StringsO,
   sync,
   test,
   testimpl,
   xmlreader;
  
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
		D : DOM.TPXMLDocument;
		N : DOM.TPXMLElement;
		L : DOM.TPXMLNodeList;
   BEGIN
      SELF.Host := Host;

		com.COMInit();
		D := DOM.newXMLDocument();
		D^.Load( L"d:\work\buff\test.xml" );
		N := DOM.TPXMLElement( D^.SelectSingleNode( L"//name" ));
		L := D^.GetElementsByTagName( L"p" );
		IF L^.Count = 2 THEN END;
		// DISPOSE( N );
		// DISPOSE( D );
		com.COMDone();

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
   testimpl.tests()^.AddTest( L"XML::DOMDocument", ADR( Test ));
END CTest;

(*===========================================================================*)

END TDOMDocument.
