IMPLEMENTATION MODULE Engine;

FROM Debug IMPORT
   Assertion, LogAssertionW;

FROM Storage IMPORT
   DEALLOCATE;

IMPORT
   array,
   Items,
   lists,
   Store,
   Strings,
   Validator;

(*================================================================================*)

PROCEDURE ValidateByUQ( REF items : arrays.CPtrArray; CONST uq : Uniquer.CUniquer );
VAR
   guid, iuid : Uniquer.TUId;
   i : INTEGER;
   item : Items.TPItem;
   localItems : arrays.CPtrArray;
BEGIN
   FOR i := 0 TO items.Count-1 DO
      item := Items.TPItem( items[i] );
      IF item^ IS Items.CProduct THEN
         localItems.Add( item );
      ELSE
         guid := uq.UId( item^.ProductId );
         iuid := Items.TPLockedItem( item )^.UId;
         IF guid = iuid THEN
            localItems.Add( item );
         ELSE
            DISPOSE( item );
         END;
      END;
   END; // FOR
   items.Clear();
   FOR i := 0 TO localItems.Count-1 DO
      items.Add( localItems[i] );
   END; // FOR
END ValidateByUQ;

(*================================================================================*)

PROCEDURE EliminateDuplicates( REF items : arrays.CPtrArray );
VAR
   i, j : INTEGER;
   iitem, jitem : Items.TPItem;
BEGIN
   // eliminate duplicated products
   FOR i := 0 TO items.Count-1 DO
      iitem := Items.TPItem( items[i] );
      IF iitem = NIL THEN
         CONTINUE;
      END;
      FOR j := i+1 TO items.Count-1 DO
         jitem := Items.TPItem( items[j] );
         IF jitem = NIL THEN
            CONTINUE;
         ELSIF iitem^.Equals( jitem^ ) THEN
            items.RemoveIndex( j );
            DISPOSE( jitem );
         END;
      END; // WHILE
   END; // LOOP
END EliminateDuplicates;

(*--------------------------------------------------------------------------------*)

PROCEDURE Canonize( REF items : arrays.CPtrArray; CONST ProductIdFilter : ARRAY OF WCHAR; CreateBindings, OmitUnbound, FilterNotProducts : BOOLEAN );
VAR
   activations : arrays.CPtrArray;
   count : INTEGER;
   i, j : INTEGER;
   iitem, jitem : Items.TPItem;
   licences : arrays.CPtrArray;
   products : arrays.CPtrArray;
BEGIN
   count := items.Count;
   IF count = 0 THEN
      RETURN;
   END;
   
   OmitUnbound := OmitUnbound AND CreateBindings;
   FilterNotProducts := FilterNotProducts AND OmitUnbound AND CreateBindings;
   
   // split
   FOR i := 0 TO count-1 DO
      iitem := Items.TPItem( items[i] );
      IF NOT iitem^.ProductId.MatchOA( ProductIdFilter, TRUE ) THEN
         DISPOSE( iitem );
         CONTINUE;
      ELSIF iitem^ IS Items.CProduct THEN
         products.Add( iitem );
      ELSIF iitem^ IS Items.CLicence THEN
         licences.Add( iitem );
      ELSIF iitem^ IS Items.CActivation THEN
         activations.Add( iitem );
      ELSE
         ASSERTLOG( FALSE );
      END;
   END; // FOR

   // eliminate duplicates
   EliminateDuplicates( REF products );
   EliminateDuplicates( REF licences );
   EliminateDuplicates( REF activations );
   
   // bind
   IF CreateBindings THEN
      // bind licences to products
	   FOR i := 0 TO licences.Count-1 DO
		   iitem := Items.TPItem( licences[i] );
   	   IF iitem = NIL THEN
	         CONTINUE;
	      END;
		   FOR j := 0 TO products.Count-1 DO
			   jitem := Items.TPItem( products[j] );
			   IF jitem = NIL THEN
			      CONTINUE;
			   ELSIF iitem^.ProductId = jitem^.ProductId THEN
				   Items.TPProduct( jitem )^.AddLicence( Items.TPLicence( iitem ));
				   EXIT;
			   END;
		   END;
		   IF OmitUnbound AND iitem^.IsStub THEN // no product was found
		      licences.RemoveIndex( i );
		      DISPOSE( iitem );
		   END;
	   END; // FOR
      // bind activations to licences
	   FOR i := 0 TO activations.Count-1 DO
		   iitem := Items.TPItem( activations[i] );
   	   IF iitem = NIL THEN
	         CONTINUE;
	      END;
		   FOR j := 0 TO licences.Count-1 DO
			   jitem := Items.TPItem( licences[j] );
			   IF jitem = NIL THEN
			      CONTINUE;
			   ELSIF Items.TPActivation( iitem )^.OfSerial = Items.TPLicence( jitem )^.Serial THEN
				   Items.TPLicence( jitem )^.AddActivation( Items.TPActivation( iitem ));
			   END;
		   END;
		   IF OmitUnbound AND iitem^.IsStub THEN // no licence was found
		      activations.RemoveIndex( i );
		      DISPOSE( iitem );
		   END;
	   END; // FOR
   END;

   items.Dispose();
   // add products
   FOR i := 0 TO products.Count-1 DO
      IF products[i] <> NIL THEN
         items.Add( products[i] );
      END;
   END;
   // add licences
   FOR i := 0 TO licences.Count-1 DO
      IF licences[i] = NIL THEN
         CONTINUE;
      ELSIF NOT FilterNotProducts THEN
         items.Add( licences[i] );
      END;
   END;
   // add activations
   FOR i := 0 TO activations.Count-1 DO
      IF activations[i] = NIL THEN
         CONTINUE;
      ELSIF NOT FilterNotProducts THEN
         items.Add( activations[i] );
      END;
   END;
END Canonize;

(*================================================================================*)

PROCEDURE ValidateByValidator( REF items : arrays.CPtrArray );
VAR
   i : INTEGER;
   item : Items.TPItem;
   localItems : arrays.CPtrArray;
BEGIN
   FOR i := 0 TO items.Count-1 DO
      item := Items.TPItem( items[i] );
      IF NOT( item^ IS Items.CProduct ) THEN
         localItems.Add( item );
      ELSIF Validator.Check( Items.TPProduct( item )^.ProductId ) <> 0 THEN
         localItems.Add( item );
      ELSE
         DISPOSE( item );
      END;
   END; // FOR
   items.Clear();
   FOR i := 0 TO localItems.Count-1 DO
      items.Add( localItems[i] );
   END; // FOR
END ValidateByValidator;

(*--------------------------------------------------------------------------------*)

PROCEDURE LoadProducts( CONST Path1, Path2, ProductId : ARRAY OF WCHAR; OUT data : arrays.CPtrArray );
VAR
   ls : Store.CFileStorage;
   lsINI : Store.CINIFilter;
   uq : Uniquer.CUniquer;
   uqDisc : Uniquer.DiscSource;
   uqMAC : Uniquer.MACSource;
BEGIN
   data.Strategy := array.astrgListInArray;
   ls.Filters^.Add( ADR( lsINI ), 0 );

   IF Strings.IndexOfCharW( LicenceMachineId, L"M", 0 ) <> -1 THEN
      uq.Sources^.Add( ADR( uqMAC ), 0 );
   END;
   IF Strings.IndexOfCharW( LicenceMachineId, L"D", 0 ) <> -1 THEN
      uq.Sources^.Add( ADR( uqDisc ), 0 );
   END;
   IF uq.Sources^.Empty THEN
      uq.Sources^.Add( ADR( uqDisc ), 0 );
   END;

   // first load common storage
   ls.Load( L"*", REF data, FALSE, TRUE );
   IF Path1[0] <> 0W THEN // second load specified path
     ls.SetPathOA( Path1 );
     ls.Load( L"*", REF data, FALSE, TRUE );
   END;
   IF Path2[0] <> 0W THEN // third load specified auxiliary path
     ls.SetPathOA( Path2 );
     ls.Load( L"*", REF data, FALSE, TRUE );
   END;
   
   // at first items must be validated, because Validate does not parse tree made by Canonize (FilterNotProducts = TRUE)
   ValidateByUQ( REF data, uq );
   Canonize( REF data, ProductId, TRUE, TRUE, TRUE );
   ValidateByValidator( REF data ); // second validate is ok, because it examines only roots = products, which have some childs. And childs are assigned inside Canonize.
END LoadProducts;

(*================================================================================*)

PROCEDURE DisposeProducts( REF data : arrays.CPtrArray );
VAR
   i : CARDINAL;
   item, jitem : Items.TPItem;
   items, jitems : lists.TPPtrList;
BEGIN
   FOR i := 0 TO data.Count-1 DO
      items := Items.TPProduct( data[i] )^.LicencesAndInfos;
      IF items <> NIL THEN
         items^.Reset();
         WHILE items^.MoveNext() DO
            item := Items.TPItem( items^.Current );
            IF item^ IS Items.CLicence THEN
               jitems := Items.TPLicence( item )^.Activations;
               IF jitems <> NIL THEN
                  jitems^.Reset();
                  WHILE jitems^.MoveNext() DO
                     jitem := Items.TPItem( jitems^.Current );
                     DISPOSE( jitem );
                  END; // WHILE jitems
               END;
            END; // item is CLicence
            DISPOSE( item );
         END; // WHILE
      END;
      DISPOSE( Items.TPItem( data[i] ));
   END;
   data.Clear();
END DisposeProducts;

(*================================================================================*)

END Engine.