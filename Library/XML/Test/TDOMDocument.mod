MODULE TDOMDocument;

	IMPORT
		com,
		DOM;

	#save, call( entry_point => on )
	PROCEDURE wmain() : INTEGER;
	#restore
	VAR
		D : DOM.TPXMLDocument;
		N : DOM.TPXMLElement;
		L : DOM.TPXMLNodeList;
	BEGIN
		com.COMInit();
		D := DOM.newXMLDocument();
		D^.Load( L"d:\buff\test.xml" );
		N := DOM.TPXMLElement( D^.SelectSingleNode( L"//p" ));
		L := D^.GetElementsByTagName( L"p" );
		IF L^.Count = 2 THEN END;
		// DISPOSE( N );
		// DISPOSE( D );
		com.COMDone();
		RETURN 0;
	END wmain;

END TDOMDocument.