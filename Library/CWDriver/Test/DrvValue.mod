MODULE DrvValue;

FROM Storage IMPORT
   ALLOCATE, DEALLOCATE;

IMPORT
   drv_def,
   drv_str,
   log,
   Strings,
   StringsO,
   test,
   testimpl;
  
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
   CONST
      string = L"0123456789012345678901234567890123456789012345678901234567890123456789012345678901234567890123456789012345678901234567890123456789012345678901234567890123456789012345678901234567890123456789012345678901234567890123456789012345678901234567890123456789012345";
   VAR
      C : CARDINAL;
      Result : test.TTestResult := test.trSuccess;
      V1 : drv_def.TValue;

      S : ARRAY [0..255] OF WCHAR;
      SA : ARRAY [0..255] OF CHAR;
   BEGIN
      SELF.Host := Host;
      
      drv_def.InitValue( V1 );
      
      Host^.StartPhase( L"A PString Set" );
         drv_def.SetValuePString256StringW( V1, FALSE, string );
         drv_def.ValueToStringW( V1, FALSE, S );
         IF EQUALS( string, S ) THEN
            Result := test.trSuccess;
         ELSE
            Result := test.trFailure;
         END;
      Host^.StopPhaseWithResult( Result );

      Host^.StartPhase( L"U PString Set" );
         drv_def.SetValuePString256StringW( V1, TRUE, string );
         drv_def.ValueToStringW( V1, TRUE, S );
         IF EQUALS( string, S ) THEN
            Result := test.trSuccess;
         ELSE
            Result := test.trFailure;
         END;
      Host^.StopPhaseWithResult( Result );

      Host^.StartPhase( L"A DString Set" );
         drv_def.SetValueStringW( V1, FALSE, string );
         drv_def.ValueToStringW( V1, FALSE, S );
         IF EQUALS( string, S ) THEN
            Result := test.trSuccess;
         ELSE
            Result := test.trFailure;
         END;
      Host^.StopPhaseWithResult( Result );

      Host^.StartPhase( L"U DString Set" );
         drv_def.SetValueStringW( V1, TRUE, string );
         drv_def.ValueToStringW( V1, TRUE, S );
         IF EQUALS( string, S ) THEN
            Result := test.trSuccess;
         ELSE
            Result := test.trFailure;
         END;
      Host^.StopPhaseWithResult( Result );

      Host^.StartPhase( L"A PString Assign/Get CARD32" );
         drv_def.SetValuePString256StringW( V1, FALSE, string );
         drv_def.AssignValueCardinal( V1, FALSE, TRUE, 134 );
         C := drv_def.ValueToCardinal( V1, FALSE, TRUE );
         IF C = 134 THEN
            Result := test.trSuccess;
         ELSE
            Result := test.trFailure;
         END;
      Host^.StopPhaseWithResult( Result );

      Host^.StartPhase( L"U PString Assign/Get CARD32" );
         drv_def.SetValuePString256StringW( V1, TRUE, string );
         drv_def.AssignValueCardinal( V1, TRUE, TRUE, 134 );
         C := drv_def.ValueToCardinal( V1, TRUE, TRUE );
         IF C = 134 THEN
            Result := test.trSuccess;
         ELSE
            Result := test.trFailure;
         END;
      Host^.StopPhaseWithResult( Result );

      Host^.StartPhase( L"A DString Assign/Get CARD32" );
         drv_def.SetValueStringW( V1, FALSE, string );
         drv_def.AssignValueCardinal( V1, FALSE, TRUE, 134 );
         C := drv_def.ValueToCardinal( V1, FALSE, TRUE );
         IF C = 134 THEN
            Result := test.trSuccess;
         ELSE
            Result := test.trFailure;
         END;
      Host^.StopPhaseWithResult( Result );

      Host^.StartPhase( L"U DString Assign/Get CARD32" );
         drv_def.SetValueStringW( V1, TRUE, string );
         drv_def.AssignValueCardinal( V1, TRUE, TRUE, 134 );
         C := drv_def.ValueToCardinal( V1, TRUE, TRUE );
         IF C = 134 THEN
            Result := test.trSuccess;
         ELSE
            Result := test.trFailure;
         END;
      Host^.StopPhaseWithResult( Result );

      drv_def.DoneValue( V1 );

      S := string;
      Strings.ToA( S, 0, OUT SA );

      Host^.StartPhase( L"A DrvString Get String" );
         V1.Type := drv_def.vtDriverString;
         V1.ValDriverStringAddress := ADR( SA );
         V1.ValDriverStringCharLength := LENGTH( SA );
         
         drv_def.ValueToStringW( V1, FALSE, S );
         IF EQUALS( string, S ) THEN
            Result := test.trSuccess;
         ELSE
            Result := test.trFailure;
         END;
      Host^.StopPhaseWithResult( Result );

      Host^.StartPhase( L"U DrvString Get String" );
         V1.Type := drv_def.vtDriverString;
         V1.ValDriverStringAddress := ADR( S );
         V1.ValDriverStringCharLength := LENGTH( S );
         
         drv_def.ValueToStringW( V1, TRUE, S );
         IF EQUALS( string, S ) THEN
            Result := test.trSuccess;
         ELSE
            Result := test.trFailure;
         END;
      Host^.StopPhaseWithResult( Result );

      Host^.StartPhase( L"A DrvString Assign/Get String" );
         V1.Type := drv_def.vtDriverString;
         V1.ValDriverStringAddress := ADR( SA );
         V1.ValDriverStringCharLength := 256;
         
         drv_def.AssignValueStringW( V1, FALSE, TRUE, S );
         drv_def.ValueToStringW( V1, FALSE, S );
         IF EQUALS( string, S ) THEN
            Result := test.trSuccess;
         ELSE
            Result := test.trFailure;
         END;
      Host^.StopPhaseWithResult( Result );

      Host^.StartPhase( L"U DrvString Assign/Get String" );
         V1.Type := drv_def.vtDriverString;
         V1.ValDriverStringAddress := ADR( S );
         V1.ValDriverStringCharLength := 256;
         
         drv_def.AssignValueStringW( V1, TRUE, TRUE, S );
         drv_def.ValueToStringW( V1, TRUE, S );
         IF EQUALS( string, S ) THEN
            Result := test.trSuccess;
         ELSE
            Result := test.trFailure;
         END;
      Host^.StopPhaseWithResult( Result );

      Host^.StartPhase( L"A DrvString Assign/Get CARD32" );
         V1.Type := drv_def.vtDriverString;
         V1.ValDriverStringAddress := ADR( SA );
         V1.ValDriverStringCharLength := 256;
         
         drv_def.AssignValueCardinal( V1, FALSE, TRUE, 134 );
         C := drv_def.ValueToCardinal( V1, FALSE, TRUE );
         IF C = 134 THEN
            Result := test.trSuccess;
         ELSE
            Result := test.trFailure;
         END;
      Host^.StopPhaseWithResult( Result );

      Host^.StartPhase( L"U DrvString Assign/Get CARD32" );
         V1.Type := drv_def.vtDriverString;
         V1.ValDriverStringAddress := ADR( S );
         V1.ValDriverStringCharLength := 256;
         
         drv_def.AssignValueCardinal( V1, TRUE, TRUE, 134 );
         C := drv_def.ValueToCardinal( V1, TRUE, TRUE );
         IF C = 134 THEN
            Result := test.trSuccess;
         ELSE
            Result := test.trFailure;
         END;
      Host^.StopPhaseWithResult( Result );

      RETURN Result;
   END Run;
   
(*---------------------------------------------------------------------------*)

BEGIN
   testimpl.tests()^.AddTest( L"DriverValue", ADR( Test ));
END CTest;

(*===========================================================================*)

END DrvValue.
