MODULE TStore;

IMPORT
  arrays,
  com,
  Items,
  Store,
  StringsO;
  
#save, call( convention => cdecl )
PROCEDURE wmain3() : INTEGER;
#restore
VAR
(*
	i, j : CARDINAL;
	item : Items.TPItem;
	items : arrays.CPtrArray;
	licence : Items.TPLicence;
	Licences : arrays.CPtrArray;
	product : Items.TPProduct;
	Products : arrays.CPtrArray;
	S : Store.CFileStorage;
	I : Store.CINIFilter;
	X : Store.CXMLFilter;
*)	
BEGIN
(*
	com.COMInit();
	
	S.Filters^.Add( ADR( I ), 0 );
	S.Filters^.Add( ADR( X ), 0 );

   S.SetPathOA( L"" );
	S.Load( L"SmartControl", REF items, TRUE, FALSE );
	
   S.SetRootOA( L"SmartControl" );
   S.SetPathOA( L"D:\Buff" );
	S.Load( L"Licence*", REF items, TRUE, FALSE );

	FOR i := 0 TO items.Count-1 DO
		item := Items.TPItem( items[i] );
		IF item^ IS Items.CProduct THEN
			Products.Add( item );
		ELSIF item^ IS Items.CLicence THEN
			Licences.Add( item );
		END;
	END; // FOR

	FOR i := 0 TO Licences.Count-1 DO
		item := Items.TPItem( Licences[i] );
		IF item^ IS Items.CLicence THEN
			FOR j := 0 TO Products.Count-1 DO
				product := Items.TPProduct( Products[j] );
				IF product^.ProductId = item^.ProductId THEN
					product^.AddLicence( Items.TPLicence( item ));
				END;
			END;
		END;
	END; // FOR

	FOR i := 0 TO items.Count-1 DO
		item := Items.TPItem( items[i] );
		IF item^ IS Items.CActivation THEN
			FOR j := 0 TO Licences.Count-1 DO
				licence := Items.TPLicence( Licences[j] );
				IF licence^.Serial = Items.TPActivation( item )^.OfSerial THEN
					item^.ProductId := licence^.ProductId;
					licence^.AddActivation( Items.TPActivation( item ));
				END;
			END;
		END;
	END; // FOR
	
	S.SetPathOA( "" );
	S.FilterToStore := ADR( X );

	S.Store( items );
	
	S.OperationMode := Store.fomSingleFile;
	S.Store( items );

	S.OperationMode := Store.fomFileByItem;
	S.Store( items );

	S.FilterToStore := ADR( I );
	S.Store( items );
	
	S.OperationMode := Store.fomSingleFile;
	S.Store( items );

	S.OperationMode := Store.fomFileByItem;
	S.Store( items );

	com.COMDone();
*)	
	
	RETURN 0;
END wmain3;

END TStore.