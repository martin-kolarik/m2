MODULE TSDValue;

IMPORT
   datetime,
   iovalue,
   StringsO;
   
   PROCEDURE TryAll( REF v : iovalue.Value );
   VAR
      S : StringsO.CString;
   BEGIN
      S.FromOA( L"2007.02.02 17.13.00" );
   
	   v.Boolean := TRUE;
	   v.Tristate := 1;
	   v.Integer := 1034;
	   v.Long := -257;
	   v.Float := 14.0;
	   v.String := S;
	   v.Date := datetime.GetCurrentJD();
   END TryAll;

	#save, call( convention => cdecl )
	PROCEDURE wmain() : INTEGER;
	#restore
	VAR
	   t : iovalue.TValueType;
	   v1, v2, v3 : iovalue.Value;
	   s : StringsO.CString;
	BEGIN
	   FOR t := iovalue.vtVoid TO iovalue.vtDate DO
	      IF t <> iovalue.vtObject THEN
	         v1.Type := t;
	         TryAll( REF v1 );
	         v1.Undefined := FALSE;
	      END;
	   END; // FOR

	   v2 := v1;

	   v1.Type := iovalue.vtLong;
	   v1.Long := 10;

      s.FromOA( L"10" );
	   v2.Type := iovalue.vtString;
	   v2.String := s;
	   
	   IF v1 > v2 THEN END;
	   IF v1 < v2 THEN END;
	   
	   v3.Type := iovalue.vtLong;
	   v3 := v1 + v1;
	   v3.Type := iovalue.vtString;
	   v3 := v2 + v2;
	   v3 := v1 + v2;

	   v3.Type := iovalue.vtLong;
	   v3 := v1 - v1;
	   v3.Type := iovalue.vtString;
	   v3 := v2 - v2;
	   v3 := v1 - v2;
	   
	   v3.Type := iovalue.vtLong;
	   v1.Long := 10;

	   v3 := v1 * v1;
	   v3 := v2 * v2;
	   v3 := v1 * v2;

	   v3 := v1 / v1;
	   v3 := v2 / v2;
	   v3 := v1 / v2;

	   v1.Long := 0FFFFFFFFFFFFFFFFH;
	   v1.Limit( 8, TRUE, TRUE );

	   v1.Long := 0FFFFFFFFFFFFFFFFH;
	   v1.Limit( 16, TRUE, FALSE );

	   v1.Long := -300;
	   v1.Limit( 8, TRUE, TRUE );

	   v1.Long := -300;
	   v1.Limit( 8, TRUE, FALSE );

	   v1.Long := -300;
	   v1.Limit( 8, FALSE, TRUE );

	   v1.Long := -300;
	   v1.Limit( 8, FALSE, FALSE );

	   v1.Long := 300;
	   v1.Limit( 8, TRUE, FALSE );

	   RETURN 0;
	END wmain;

END TSDValue.