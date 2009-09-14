MODULE TXMLReader;

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
      fs : FIOO.CFileStream;
      reader : xmlreader.CXMLReader;
      s1, s2 : StringsO.CString;
      xmle : xmlreader.TXMLError;
   BEGIN
      SELF.Host := Host;

	   TRY
		   fs.FromPath( L"D:\Work\Buff\Test.xml", FIOO.imOpenRead );
		CATCH e : IOO.CIOException DO
		   // do nothing
		END;

      Host^.StartPhase( L"Copy XML to console" );
      
      reader.Stream := ADR( fs );
      xmle := reader.MoveNext();
      WHILE xmle = xmlreader.xmle_S_OK DO
         CASE reader.CurrentType OF
         | xmlreader.xntUnknown : Host^.Log^.LogS( log.dlcInfo, L"", L"?? unknown node" );
            Failure := TRUE;
            CONTINUE;
         | xmlreader.xntXMLDeclaration : Host^.Log^.LogS( log.dlcInfo, L"", L"DECLARATION" );
         | xmlreader.xntDocumentType : Host^.Log^.LogS( log.dlcInfo, L"", L"DOCTYPE" );
         | xmlreader.xntCDATA : Host^.Log^.LogS( log.dlcInfo, L"", L"CDATA" );
         | xmlreader.xntProcessingInstruction : Host^.Log^.LogS( log.dlcInfo, L"", L"PI" );
         | xmlreader.xntText : Host^.Log^.LogS( log.dlcInfo, L"", L"#text" );
         | xmlreader.xntComment : Host^.Log^.LogS( log.dlcInfo, L"", L"COMMENT" );
         | xmlreader.xntElementBegin : Host^.Log^.LogS( log.dlcInfo, L"", L"+ELEMENT" );
         | xmlreader.xntElementEnd : Host^.Log^.LogS( log.dlcInfo, L"", L"-ELEMENT" );
         | xmlreader.xntAttribute : Host^.Log^.LogS( log.dlcInfo, L"", L"ATTRIBUTE" );
         | xmlreader.xntWhitespace : Host^.Log^.LogS( log.dlcInfo, L"", L"WHITESPACE" );
         END; // CASE

         s1 := reader.CurrentName;         
         s2 := reader.CurrentValue;
         Host^.Log^.LogSSSS( log.dlcInfo, L"", L"  name: ", OA( s1.Length-1, s1.rawData ), L" = ", OA( s2.Length-1, s2.rawData ));
         
         IF ( reader.CurrentType = xmlreader.xntElementBegin ) AND ( reader.MoveToFirstAttribute() = xmlreader.xmle_S_OK ) THEN
            REPEAT
               IF reader.CurrentType = xmlreader.xntAttribute THEN
                  Host^.Log^.LogS( log.dlcInfo, L"", L"  ATTRIBUTE" );
               ELSE
                  Failure := TRUE;
                  Host^.Log^.LogS( log.dlcInfo, L"", L"?? expected attribute only" );
               END;
               s1 := reader.CurrentName;         
               s2 := reader.CurrentValue;
               Host^.Log^.LogSSSS( log.dlcInfo, L"", L"    name: ", OA( s1.Length-1, s1.rawData ), L" = ", OA( s2.Length-1, s2.rawData ));
            UNTIL reader.MoveToNextAttribute() <> xmlreader.xmle_S_FALSE;
         END;

         xmle := reader.MoveNext();
      END; // WHILE

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
   testimpl.tests()^.AddTest( L"XML::XMLReader", ADR( Test ));
END CTest;

(*===========================================================================*)

END TXMLReader.
