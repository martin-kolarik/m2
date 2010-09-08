MODULE CStringReferencing;

FROM Storage IMPORT
   ALLOCATE, DEALLOCATE;

IMPORT
   datetime,
   log,
   StringsO,
   test,
   testimpl,
   windows;
  
(*===========================================================================*)

CLASS CTest IMPLEMENTS test.ITest;
   PRIVATE VAR
      Host : test.TPHost := NIL;
   PUBLIC VIRTUAL PROCEDURE Run( CONST Host : test.TPHost; CONST Parameters : ARRAY OF PWCHAR ) : test.TTestResult;
   
   PRIVATE VAR
      SFromAssign : StringsO.CString;
   LOCAL PROCEDURE AssignInThreadTest();
END CTest;

(*---------------------------------------------------------------------------*)

TYPE
   TPTest = POINTER TO CTest;
VAR
   Test : CTest;

(*===========================================================================*)

#save, call( convention => stdcall )
PROCEDURE AssignThread( a : ADDRESS ) : windows.DWORD;
BEGIN
   TPTest( a )^.AssignInThreadTest();
   RETURN 0;
END AssignThread;
#restore

(*===========================================================================*)

CLASS IMPLEMENTATION CTest;

(*---------------------------------------------------------------------------*)

   PUBLIC VIRTUAL PROCEDURE Run( CONST Host : test.TPHost; CONST Parameters : ARRAY OF PWCHAR ) : test.TTestResult;
   VAR
      avg : LONGREAL;
      i, t : CARDINAL;
      NS1, NS2 : ARRAY [0..255] OF WCHAR;
      S, S1, S2, S3, S4 : StringsO.CString;
      Result : test.TTestResult := test.trSuccess;
      thread : windows.HANDLE;
   BEGIN
      SELF.Host := Host;
      
      S.FromOA( L"Lorem ipsum Lorem ipsum Lorem ipsum Lorem ipsum Lorem ipsum Lorem ipsum Lorem ipsum" );
      ASSIGN( NS1, OA( S.Length-1, S.Data ));
   
      //----------------------------------------
      Host^.StartPhase( L"Speed of Copy to existing (80 chars/5 M iterations) -- NATIVE STRING" );

      t := datetime.UptimeMS();
      FOR i := 0 TO 5000000-1 DO
         ASSIGN( NS2, NS1 );
      END;
      
      t := datetime.UptimeMS() - t;
      Host^.Log^.LogSC( log.lcInfo, 0, L"", "Consumed (ms): ", t );
      avg := LONGREAL( t ) / 5.0E3;
      S.FromLONGREAL( avg, FALSE );
      Host^.Log^.LogSS( log.lcInfo, 0, L"", "Average (us): ", OA( S.Length-1, S.Data ));

      Host^.StopPhase();

      //----------------------------------------
      Host^.StartPhase( L"Speed of Copy to new (80 chars/5 M iterations)" );

      t := datetime.UptimeMS();
      FOR i := 0 TO 5000000-1 DO
         S1.Copy( S );
         S1.Dispose();
      END;
      
      t := time.UptimeMS() - t;
      Host^.Log^.LogSC( log.lcInfo, 0, L"", "Consumed (ms): ", t );
      avg := LONGREAL( t ) / 5.0E3;
      S.FromLONGREAL( avg, FALSE );
      Host^.Log^.LogSS( log.lcInfo, 0, L"", "Average (us): ", OA( S.Length-1, S.Data ));

      Host^.StopPhase();

      //----------------------------------------
      Host^.StartPhase( L"Speed of Copy to existing (80 chars/5 M iterations)" );

      t := datetime.UptimeMS();
      FOR i := 0 TO 5000000-1 DO
         S1.Copy( S );         
      END;
      
      t := time.UptimeMS() - t;
      Host^.Log^.LogSC( log.lcInfo, 0, L"", "Consumed (ms): ", t );
      avg := LONGREAL( t ) / 5.0E3;
      S.FromLONGREAL( avg, FALSE );
      Host^.Log^.LogSS( log.lcInfo, 0, L"", "Average (us): ", OA( S.Length-1, S.Data ));

      Host^.StopPhase();

      //----------------------------------------
      Host^.StartPhase( L"Speed of Assign (80 chars/5 M iterations)" );

      t := datetime.UptimeMS();
      FOR i := 0 TO 5000000-1 DO
         S1.Assign( S );         
      END;
      
      t := time.UptimeMS() - t;
      Host^.Log^.LogSC( log.lcInfo, 0, L"", "Consumed (ms): ", t );
      avg := LONGREAL( t ) / 5.0E3;
      S.FromLONGREAL( avg, FALSE );
      Host^.Log^.LogSS( log.lcInfo, 0, L"", "Average (us): ", OA( S.Length-1, S.Data ));

      Host^.StopPhase();

      //----------------------------------------

      S.FromOA( L"Lorem" );
      ASSIGN( NS1, OA( S.Length-1, S.Data ));
   
      //----------------------------------------
      Host^.StartPhase( L"Speed of Copy to existing (5 chars/5 M iterations) -- NATIVE STRING" );

      t := datetime.UptimeMS();
      FOR i := 0 TO 5000000-1 DO
         ASSIGN( NS2, NS1 );
      END;
      
      t := time.UptimeMS() - t;
      Host^.Log^.LogSC( log.lcInfo, 0, L"", "Consumed (ms): ", t );
      avg := LONGREAL( t ) / 5.0E3;
      S.FromLONGREAL( avg, FALSE );
      Host^.Log^.LogSS( log.lcInfo, 0, L"", "Average (us): ", OA( S.Length-1, S.Data ));

      Host^.StopPhase();

      //----------------------------------------
      Host^.StartPhase( L"Speed of Copy to new (5 chars/5 M iterations)" );

      t := datetime.UptimeMS();
      FOR i := 0 TO 5000000-1 DO
         S1.Copy( S );
         S1.Dispose();
      END;
      
      t := time.UptimeMS() - t;
      Host^.Log^.LogSC( log.lcInfo, 0, L"", "Consumed (ms): ", t );
      avg := LONGREAL( t ) / 5.0E3;
      S.FromLONGREAL( avg, FALSE );
      Host^.Log^.LogSS( log.lcInfo, 0, L"", "Average (us): ", OA( S.Length-1, S.Data ));

      Host^.StopPhase();

      //----------------------------------------
      Host^.StartPhase( L"Speed of Copy to existing (5 chars/5 M iterations)" );

      t := datetime.UptimeMS();
      FOR i := 0 TO 5000000-1 DO
         S1.Copy( S );         
      END;
      
      t := time.UptimeMS() - t;
      Host^.Log^.LogSC( log.lcInfo, 0, L"", "Consumed (ms): ", t );
      avg := LONGREAL( t ) / 5.0E3;
      S.FromLONGREAL( avg, FALSE );
      Host^.Log^.LogSS( log.lcInfo, 0, L"", "Average (us): ", OA( S.Length-1, S.Data ));

      Host^.StopPhase();

      //----------------------------------------
      Host^.StartPhase( L"Speed of Assign (5 chars/5 M iterations)" );

      t := datetime.UptimeMS();
      FOR i := 0 TO 5000000-1 DO
         S1.Assign( S );         
      END;
      
      t := time.UptimeMS() - t;
      Host^.Log^.LogSC( log.lcInfo, 0, L"", "Consumed (ms): ", t );
      avg := LONGREAL( t ) / 5.0E3;
      S.FromLONGREAL( avg, FALSE );
      Host^.Log^.LogSS( log.lcInfo, 0, L"", "Average (us): ", OA( S.Length, S.Data ));

      Host^.StopPhase();

      //----------------------------------------
      Host^.StartPhase( L"Simple Assigns" );
      
      S1.Clear();
      S1 := S;
      IF ( S1.Data <> S.Data ) THEN
         Host^.Log^.LogS( log.lcError, 0, L"", L"Data pointers (1) mismatch" );
         Result := test.trFailure;
      END;
      
      S1.Clear();
      S2.Clear();
      S1 := S2;
      IF ( S1.Data <> S2.Data ) THEN
         Host^.Log^.LogS( log.lcError, 0, L"", L"Data pointers (2) mismatch" );
         Result := test.trFailure;
      END;
      
      S1.FromOA( L"Short string" );
      S2.FromOA( L"Long long very long string, over prealocated buffer size -- this is to replace S1" );
      S1 := S2;
      IF ( S1.Data <> S2.Data ) THEN
         Host^.Log^.LogS( log.lcError, 0, L"", L"Data pointers (3) mismatch" );
         Result := test.trFailure;
      END;
      
      S1.FromOA( L"Short string" );
      S2.FromOA( L"Long long very long string, over prealocated buffer size -- this is to replace S1" );
      S1.Copy( S2 );
      IF ( S1.Data = S2.Data ) THEN
         Host^.Log^.LogS( log.lcError, 0, L"", L"Data pointers (4) mismatch" );
         Result := test.trFailure;
      END;
      
      Host^.StopPhase();

      //----------------------------------------
      Host^.StartPhase( L"More Assigns, next Dispose" );

      S.FromOA( L"Template" );

      S1 := S;
      S2 := S;
      S3 := S;
      S4 := S;
      IF ( S1.Data <> S.Data ) OR ( S2.Data <> S.Data ) OR ( S3.Data <> S.Data ) OR ( S4.Data <> S.Data ) THEN
         Host^.Log^.LogS( log.lcError, 0, L"", L"Data pointers mismatch" );
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
         Host^.Log^.LogS( log.lcError, 0, L"", L"Data pointers mismatch" );
         Result := test.trFailure;
      END;
      
      S3.Dispose();
      IF ( S1.Data <> S.Data ) OR ( S2.Data <> S.Data ) OR ( S3.Data <> NIL ) OR ( S4.Data <> S.Data ) THEN
         Host^.Log^.LogS( log.lcError, 0, L"", L"Data pointers mismatch" );
         Result := test.trFailure;
      END;

      Host^.StopPhase();

      //----------------------------------------
      Host^.StartPhase( L"Single Assign, next operation" );
      
      S1 := S;
      S1[2] := L"A";
      IF ( S1.Data = S.Data ) OR NOT S1.EqualsOA( L"TeAplate" ) THEN
         Host^.Log^.LogS( log.lcError, 0, L"", L"Index set error" );
         Result := test.trFailure;
      END;

      S1 := S;
      S1.Append( S );
      IF ( S1.Data = S.Data ) OR NOT S1.EqualsOA( L"TemplateTemplate" ) THEN
         Host^.Log^.LogS( log.lcError, 0, L"", L"Append error" );
         Result := test.trFailure;
      END;

      S1 := S;
      S1.AppendOA( L"Append" );
      IF ( S1.Data = S.Data ) OR NOT S1.EqualsOA( L"TemplateAppend" ) THEN
         Host^.Log^.LogS( log.lcError, 0, L"", L"AppendOA error" );
         Result := test.trFailure;
      END;

      S1 := S;
      S1.Prepend( S );
      IF ( S1.Data = S.Data ) OR NOT S1.EqualsOA( L"TemplateTemplate" ) THEN
         Host^.Log^.LogS( log.lcError, 0, L"", L"Prepend error" );
         Result := test.trFailure;
      END;

      S1 := S;
      S1.PrependOA( L"Prepend" );
      IF ( S1.Data = S.Data ) OR NOT S1.EqualsOA( L"PrependTemplate" ) THEN
         Host^.Log^.LogS( log.lcError, 0, L"", L"PrependOA error" );
         Result := test.trFailure;
      END;

      S1 := S;
      S1.Insert( 2, S );
      IF ( S1.Data = S.Data ) OR NOT S1.EqualsOA( L"TeTemplatemplate" ) THEN
         Host^.Log^.LogS( log.lcError, 0, L"", L"Insert error" );
         Result := test.trFailure;
      END;

      S1 := S;
      S1.InsertOA( 2, L"Insert" );
      IF ( S1.Data = S.Data ) OR NOT S1.EqualsOA( L"TeInsertmplate" ) THEN
         Host^.Log^.LogS( log.lcError, 0, L"", L"InsertOA error" );
         Result := test.trFailure;
      END;

      S1 := S;
      S1.Remove( 2, 2 );
      IF ( S1.Data = S.Data ) OR NOT S1.EqualsOA( L"Telate" ) THEN
         Host^.Log^.LogS( log.lcError, 0, L"", L"Remove error" );
         Result := test.trFailure;
      END;

      S1 := S;
      S2.FromOA( L"mpl" );
      S3.FromOA( L"nqm" );
      S1.Replace( S2, S3 );
      IF ( S1.Data = S.Data ) OR NOT S1.EqualsOA( L"Tenqmate" ) THEN
         Host^.Log^.LogS( log.lcError, 0, L"", L"Replace error" );
         Result := test.trFailure;
      END;

      S1 := S;
      S1.ReplaceOA( L"mpl", L"nqm" );
      IF ( S1.Data = S.Data ) OR NOT S1.EqualsOA( L"Tenqmate" ) THEN
         Host^.Log^.LogS( log.lcError, 0, L"", L"ReplaceOA error" );
         Result := test.trFailure;
      END;
      
      S1.FromOA( L" Template " );
      S1.Trim();
      IF ( S1.Data = S.Data ) OR NOT S1.EqualsOA( L"Template" ) THEN
         Host^.Log^.LogS( log.lcError, 0, L"", L"Trim error" );
         Result := test.trFailure;
      END;

      S1 := S;
      S1.Lowerize();
      IF ( S1.Data = S.Data ) OR NOT S1.EqualsOA( L"template" ) THEN
         Host^.Log^.LogS( log.lcError, 0, L"", L"Lowerize error" );
         Result := test.trFailure;
      END;
      
      S1 := S;
      S1.Capitalize();
      IF ( S1.Data = S.Data ) OR NOT S1.EqualsOA( L"TEMPLATE" ) THEN
         Host^.Log^.LogS( log.lcError, 0, L"", L"Capitalize error" );
         Result := test.trFailure;
      END;
      
      S1 := S;
      S1.FromOA( L"Ahoj" );
      IF ( S1.Data = S.Data ) OR NOT S1.EqualsOA( L"Ahoj" ) THEN
         Host^.Log^.LogS( log.lcError, 0, L"", L"FromOA error" );
         Result := test.trFailure;
      END;
      
      S1 := S;
      S1.FromOAA( 0, C"Ahoj" );
      IF ( S1.Data = S.Data ) OR NOT S1.EqualsOA( L"Ahoj" ) THEN
         Host^.Log^.LogS( log.lcError, 0, L"", L"FromOAA error" );
         Result := test.trFailure;
      END;
      
      S1 := S;
      S1.FromUTF8( C"Ahoj" );
      IF ( S1.Data = S.Data ) OR NOT S1.EqualsOA( L"Ahoj" ) THEN
         Host^.Log^.LogS( log.lcError, 0, L"", L"FromUTF8 error" );
         Result := test.trFailure;
      END;
      
      S1 := S;
      S1.FromINT32( -32, 16 );
      IF ( S1.Data = S.Data ) OR NOT S1.EqualsOA( L"-20" ) THEN
         Host^.Log^.LogS( log.lcError, 0, L"", L"FromINT32 error" );
         Result := test.trFailure;
      END;
      
      S1 := S;
      S1.FromCARD32( 32, 16 );
      IF ( S1.Data = S.Data ) OR NOT S1.EqualsOA( L"20" ) THEN
         Host^.Log^.LogS( log.lcError, 0, L"", L"FromCARD32 error" );
         Result := test.trFailure;
      END;
      
      S1 := S;
      S1.FromINT64( -32, 16 );
      IF ( S1.Data = S.Data ) OR NOT S1.EqualsOA( L"-20" ) THEN
         Host^.Log^.LogS( log.lcError, 0, L"", L"FromINT64 error" );
         Result := test.trFailure;
      END;
      
      S1 := S;
      S1.FromCARD64( 32, 16 );
      IF ( S1.Data = S.Data ) OR NOT S1.EqualsOA( L"20" ) THEN
         Host^.Log^.LogS( log.lcError, 0, L"", L"FromCARD64 error" );
         Result := test.trFailure;
      END;
      
      S1 := S;
      S1.FromLONGREAL( -3.2, FALSE );
      IF ( S1.Data = S.Data ) OR NOT S1.EqualsOA( L"-3.2" ) THEN
         Host^.Log^.LogS( log.lcError, 0, L"", L"FromLONGREAL error" );
         Result := test.trFailure;
      END;
      
      S1 := S;
      S1.FromLONGREALExt( -3.2, 5, -1, FALSE, L"," );
      IF ( S1.Data = S.Data ) OR NOT S1.EqualsOA( L"-3,2000" ) THEN
         Host^.Log^.LogS( log.lcError, 0, L"", L"FromLONGREALExt error" );
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
         Host^.Log^.LogS( log.lcError, 0, L"", L"Pointers in not expected state" );
         Result := test.trFailure;
      END;
      
      Host^.StopPhase();

      //----------------------------------------
      Host^.StartPhase( L"Assigns from string to more threads" );
      
      SFromAssign.Copy( S );
      
      FOR i := 0 TO 99 DO
         thread := windows.CreateThread( NIL, 0, AssignThread, ADR( SELF ), 0, NIL );
         windows.CloseHandle( thread );
      END;
      
      windows.Sleep( 30000 );
      
      Host^.StopPhase();

      RETURN Result;
   END Run;
   
(*---------------------------------------------------------------------------*)

   LOCAL PROCEDURE AssignInThreadTest();
   VAR
      i : CARDINAL;
      S1, S2 : StringsO.CString;
   BEGIN
      FOR i := 0 TO 250000-1 DO
         S1.Assign( SFromAssign );
         S2.Assign( S1 );
         IF ( S1.Data <> SFromAssign.Data ) OR ( S2.Data <> S1.Data ) THEN
            Host^.Log^.LogS( log.lcError, 0, L"", L"Pointers in not expected state (1)" );
         END;
         S1.Dispose();
         S2.Dispose();
      END;

      FOR i := 0 TO 250000-1 DO
         S1.Copy( SFromAssign );
         S2.Assign( S1 );
         IF ( S1.Data = SFromAssign.Data ) OR ( S2.Data <> S1.Data ) THEN
            Host^.Log^.LogS( log.lcError, 0, L"", L"Pointers in not expected state (2)" );
         END;
         S1.Dispose();
         S2.Dispose();
      END;
   END AssignInThreadTest;

(*---------------------------------------------------------------------------*)

BEGIN
   testimpl.tests()^.AddTest( L"CStringReferencing", ADR( Test ));
END CTest;

(*===========================================================================*)

BEGIN
END CStringReferencing.
