MODULE CStringReferencing;

FROM Storage IMPORT
   ALLOCATE, DEALLOCATE;

IMPORT
   log,
   StringsO,
   test,
   testimpl,
   time;
  
(*===========================================================================*)

CLASS CTest IMPLEMENTS test.ITest;
   PRIVATE VAR
      Host : test.TPHost := NIL;
   PUBLIC VIRTUAL PROCEDURE Run( CONST Host : test.TPHost; CONST Parameters : ARRAY OF PWCHAR ) : test.TTestResult;
END CTest;

(*---------------------------------------------------------------------------*)

TYPE
   TPTest = POINTER TO CTest;
VAR
   Test : CTest;

(*===========================================================================*)

CLASS IMPLEMENTATION CTest;

(*---------------------------------------------------------------------------*)

   PUBLIC VIRTUAL PROCEDURE Run( CONST Host : test.TPHost; CONST Parameters : ARRAY OF PWCHAR ) : test.TTestResult;
   VAR
      i, t : CARDINAL;
      S, S1, S2, S3, S4 : StringsO.CString;
      Result : test.TTestResult := test.trSuccess;
   BEGIN
      SELF.Host := Host;
      
      S.FromOA( L"Lorem ipsum Lorem ipsum Lorem ipsum Lorem ipsum Lorem ipsum Lorem ipsum Lorem ipsum" );
   
      //----------------------------------------
      Host^.StartPhase( L"Speed of Copy to new (80 chars/5 M iterations)" );

      t := time.UptimeMS();
      FOR i := 0 TO 5000000-1 DO
         S1.Copy( S );
         S1.Dispose();
      END;
      
      t := time.UptimeMS() - t;
      Host^.Log^.LogSC( log.dlcInfo, L"", "Consumed: ", t );

      Host^.StopPhase();

      //----------------------------------------
      Host^.StartPhase( L"Speed of Copy to existing (80 chars/5 M iterations)" );

      t := time.UptimeMS();
      FOR i := 0 TO 5000000-1 DO
         S1.Copy( S );         
      END;
      
      t := time.UptimeMS() - t;
      Host^.Log^.LogSC( log.dlcInfo, L"", "Consumed: ", t );

      Host^.StopPhase();

      //----------------------------------------
      Host^.StartPhase( L"Speed of Assign (80 chars/5 M iterations)" );

      t := time.UptimeMS();
      FOR i := 0 TO 5000000-1 DO
         S1.Assign( S );         
      END;
      
      t := time.UptimeMS() - t;
      Host^.Log^.LogSC( log.dlcInfo, L"", "Consumed: ", t );

      Host^.StopPhase();

      //----------------------------------------

      S.FromOA( L"Lorem" );
   
      //----------------------------------------
      Host^.StartPhase( L"Speed of Copy to new (5 chars/5 M iterations)" );

      t := time.UptimeMS();
      FOR i := 0 TO 5000000-1 DO
         S1.Copy( S );
         S1.Dispose();
      END;
      
      t := time.UptimeMS() - t;
      Host^.Log^.LogSC( log.dlcInfo, L"", "Consumed: ", t );

      Host^.StopPhase();

      //----------------------------------------
      Host^.StartPhase( L"Speed of Copy to existing (5 chars/5 M iterations)" );

      t := time.UptimeMS();
      FOR i := 0 TO 5000000-1 DO
         S1.Copy( S );         
      END;
      
      t := time.UptimeMS() - t;
      Host^.Log^.LogSC( log.dlcInfo, L"", "Consumed: ", t );

      Host^.StopPhase();

      //----------------------------------------
      Host^.StartPhase( L"Speed of Assign (5 chars/5 M iterations)" );

      t := time.UptimeMS();
      FOR i := 0 TO 5000000-1 DO
         S1.Assign( S );         
      END;
      
      t := time.UptimeMS() - t;
      Host^.Log^.LogSC( log.dlcInfo, L"", "Consumed: ", t );

      Host^.StopPhase();

      //----------------------------------------

      S.FromOA( L"Template" );

      //----------------------------------------
      Host^.StartPhase( L"More Assigns, next Dispose" );

      S1 := S;
      S2 := S;
      S3 := S;
      S4 := S;
      IF ( S1.Data <> S.Data ) OR ( S2.Data <> S.Data ) OR ( S3.Data <> S.Data ) OR ( S4.Data <> S.Data ) THEN
         Host^.Log^.LogS( log.dlcError, L"", L"Data pointers mismatch" );
         Result := test.trFailure;
      END;

      S1.Dispose();
      S2.Dispose();
      S3.Dispose();
      S4.Dispose();

      S1 := S;
      S2 := S1;
      S3 := S2;
      S4 := S3;
      IF ( S1.Data <> S.Data ) OR ( S2.Data <> S.Data ) OR ( S3.Data <> S.Data ) OR ( S4.Data <> S.Data ) THEN
         Host^.Log^.LogS( log.dlcError, L"", L"Data pointers mismatch" );
         Result := test.trFailure;
      END;
      
      S3.Dispose();
      IF ( S1.Data <> S.Data ) OR ( S2.Data <> S.Data ) OR ( S3.Data <> NIL ) OR ( S4.Data <> S.Data ) THEN
         Host^.Log^.LogS( log.dlcError, L"", L"Data pointers mismatch" );
         Result := test.trFailure;
      END;

      Host^.StopPhase();

      //----------------------------------------
      Host^.StartPhase( L"Single Assign, next operation" );
      
      S1 := S;
      S1[2] := L"A";
      IF ( S1.Data = S.Data ) OR NOT S1.EqualsOA( L"TeAplate" ) THEN
         Host^.Log^.LogS( log.dlcError, L"", L"Index set error" );
         Result := test.trFailure;
      END;

      S1 := S;
      S1.Append( S );
      IF ( S1.Data = S.Data ) OR NOT S1.EqualsOA( L"TemplateTemplate" ) THEN
         Host^.Log^.LogS( log.dlcError, L"", L"Append error" );
         Result := test.trFailure;
      END;

      S1 := S;
      S1.AppendOA( L"Append" );
      IF ( S1.Data = S.Data ) OR NOT S1.EqualsOA( L"TemplateAppend" ) THEN
         Host^.Log^.LogS( log.dlcError, L"", L"AppendOA error" );
         Result := test.trFailure;
      END;

      S1 := S;
      S1.Prepend( S );
      IF ( S1.Data = S.Data ) OR NOT S1.EqualsOA( L"TemplateTemplate" ) THEN
         Host^.Log^.LogS( log.dlcError, L"", L"Prepend error" );
         Result := test.trFailure;
      END;

      S1 := S;
      S1.PrependOA( L"Prepend" );
      IF ( S1.Data = S.Data ) OR NOT S1.EqualsOA( L"PrependTemplate" ) THEN
         Host^.Log^.LogS( log.dlcError, L"", L"PrependOA error" );
         Result := test.trFailure;
      END;

      S1 := S;
      S1.Insert( 2, S );
      IF ( S1.Data = S.Data ) OR NOT S1.EqualsOA( L"TeTemplatemplate" ) THEN
         Host^.Log^.LogS( log.dlcError, L"", L"Insert error" );
         Result := test.trFailure;
      END;

      S1 := S;
      S1.InsertOA( 2, L"Insert" );
      IF ( S1.Data = S.Data ) OR NOT S1.EqualsOA( L"TeInsertmplate" ) THEN
         Host^.Log^.LogS( log.dlcError, L"", L"InsertOA error" );
         Result := test.trFailure;
      END;

      S1 := S;
      S1.Remove( 2, 2 );
      IF ( S1.Data = S.Data ) OR NOT S1.EqualsOA( L"Telate" ) THEN
         Host^.Log^.LogS( log.dlcError, L"", L"Remove error" );
         Result := test.trFailure;
      END;

      S1 := S;
      S2.FromOA( L"mpl" );
      S3.FromOA( L"nqm" );
      S1.Replace( S2, S3 );
      IF ( S1.Data = S.Data ) OR NOT S1.EqualsOA( L"Tenqmate" ) THEN
         Host^.Log^.LogS( log.dlcError, L"", L"Replace error" );
         Result := test.trFailure;
      END;

      S1 := S;
      S1.ReplaceOA( L"mpl", L"nqm" );
      IF ( S1.Data = S.Data ) OR NOT S1.EqualsOA( L"Tenqmate" ) THEN
         Host^.Log^.LogS( log.dlcError, L"", L"ReplaceOA error" );
         Result := test.trFailure;
      END;
      
      S1.FromOA( L" Template " );
      S1.Trim();
      IF ( S1.Data = S.Data ) OR NOT S1.EqualsOA( L"Template" ) THEN
         Host^.Log^.LogS( log.dlcError, L"", L"Trim error" );
         Result := test.trFailure;
      END;

      S1 := S;
      S1.Lowerize();
      IF ( S1.Data = S.Data ) OR NOT S1.EqualsOA( L"template" ) THEN
         Host^.Log^.LogS( log.dlcError, L"", L"Lowerize error" );
         Result := test.trFailure;
      END;
      
      S1 := S;
      S1.Capitalize();
      IF ( S1.Data = S.Data ) OR NOT S1.EqualsOA( L"TEMPLATE" ) THEN
         Host^.Log^.LogS( log.dlcError, L"", L"Capitalize error" );
         Result := test.trFailure;
      END;
      
      S1 := S;
      S1.FromOA( L"Ahoj" );
      IF ( S1.Data = S.Data ) OR NOT S1.EqualsOA( L"Ahoj" ) THEN
         Host^.Log^.LogS( log.dlcError, L"", L"FromOA error" );
         Result := test.trFailure;
      END;
      
      S1 := S;
      S1.FromOAA( 0, C"Ahoj" );
      IF ( S1.Data = S.Data ) OR NOT S1.EqualsOA( L"Ahoj" ) THEN
         Host^.Log^.LogS( log.dlcError, L"", L"FromOAA error" );
         Result := test.trFailure;
      END;
      
      S1 := S;
      S1.FromUTF8( C"Ahoj" );
      IF ( S1.Data = S.Data ) OR NOT S1.EqualsOA( L"Ahoj" ) THEN
         Host^.Log^.LogS( log.dlcError, L"", L"FromUTF8 error" );
         Result := test.trFailure;
      END;
      
      S1 := S;
      S1.FromINT32( -32, 16 );
      IF ( S1.Data = S.Data ) OR NOT S1.EqualsOA( L"-20" ) THEN
         Host^.Log^.LogS( log.dlcError, L"", L"FromINT32 error" );
         Result := test.trFailure;
      END;
      
      S1 := S;
      S1.FromCARD32( 32, 16 );
      IF ( S1.Data = S.Data ) OR NOT S1.EqualsOA( L"20" ) THEN
         Host^.Log^.LogS( log.dlcError, L"", L"FromCARD32 error" );
         Result := test.trFailure;
      END;
      
      S1 := S;
      S1.FromINT64( -32, 16 );
      IF ( S1.Data = S.Data ) OR NOT S1.EqualsOA( L"-20" ) THEN
         Host^.Log^.LogS( log.dlcError, L"", L"FromINT64 error" );
         Result := test.trFailure;
      END;
      
      S1 := S;
      S1.FromCARD64( 32, 16 );
      IF ( S1.Data = S.Data ) OR NOT S1.EqualsOA( L"20" ) THEN
         Host^.Log^.LogS( log.dlcError, L"", L"FromCARD64 error" );
         Result := test.trFailure;
      END;
      
      S1 := S;
      S1.FromLONGREAL( -3.2, FALSE );
      IF ( S1.Data = S.Data ) OR NOT S1.EqualsOA( L"-3.2" ) THEN
         Host^.Log^.LogS( log.dlcError, L"", L"FromLONGREAL error" );
         Result := test.trFailure;
      END;
      
      S1 := S;
      S1.FromLONGREALExt( -3.2, 5, -1, FALSE, L"," );
      IF ( S1.Data = S.Data ) OR NOT S1.EqualsOA( L"-3,2000" ) THEN
         Host^.Log^.LogS( log.dlcError, L"", L"FromLONGREALExt error" );
         Result := test.trFailure;
      END;
      
      Host^.StopPhase();

      //----------------------------------------
      Host^.StartPhase( L"Multiple Assign, next copy" );
      
      S1 := S;
      S2 := S1;
      S3.Copy( S1 );
      S4.Copy( S2 );
      IF ( S1.Data <> S2.Data ) OR ( S1.Data = S3.Data ) OR ( S1.Data = S4.Data ) OR ( S3.Data = S4.Data ) THEN
         Host^.Log^.LogS( log.dlcError, L"", L"Pointers in not expected state" );
         Result := test.trFailure;
      END;
      
      Host^.StopPhase();

      RETURN Result;
   END Run;
   
(*---------------------------------------------------------------------------*)

BEGIN
   testimpl.tests()^.AddTest( L"CStringReferencing", ADR( Test ));
END CTest;

(*===========================================================================*)

BEGIN
END CStringReferencing.