MODULE TXMLWriter;

	IMPORT
		FIOO,
		XMLWriter;

	#save, call( entry_point => on )
	PROCEDURE wmain() : INTEGER;
	#restore
	VAR
		S : FIOO.CFileStream;
		X : XMLWriter.CXMLWriter;
	BEGIN
		S.FromPath( L"D:\buff\Test.xml", FIOO.imCreate );
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

		X.Close();

		RETURN 0;
	END wmain;

END TXMLWriter.