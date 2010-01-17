MODULE TXMLWriter;

	IMPORT
		FIOO,
		IOO,
		XMLWriter;

	PROCEDURE wmain01() : INTEGER;
	VAR
		S : FIOO.CFileStream;
		X : XMLWriter.CXMLWriter;
	BEGIN
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

		RETURN 0;
	END wmain01;

END TXMLWriter.