MODULE TBridge;

FROM Storage IMPORT
   ALLOCATE, DEALLOCATE;

IMPORT
   device,
   DeviceIOSDAPBridge,
   INIFile,
   log,
   scinit,
   Sync,
   test,
   testimpl;
  
(*===========================================================================*)

TYPE
   TPTest = POINTER TO CTest;

(*---------------------------------------------------------------------------*)

CLASS CTest IMPLEMENTS test.ITest;
   PUBLIC VAR
      Host : test.TPHost := NIL;
      Bridge : DeviceIOSDAPBridge.TPBridge := NIL;

   // ITest
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
      Failure1, Failure2 : BOOLEAN := FALSE;
      ini : INIFile.CINIFile;
      Result : Sync.TAsyncResult;
      src : device.TConfigureItem;
   BEGIN
      SELF.Host := Host;

      scinit.Startup();
      Result := DeviceIOSDAPBridge.newDeviceIOSDAPBridge( OUT Bridge );

      Host^.StartPhase( L"Configure" );
      
      ini.LoadPath( L"bridge.cfg" );
      
      src.Type := device.citINIFile;
      src.iniFile := ADR( ini );
      Bridge^.Configure( OA( 0, ADR( src )), log.logger());
      
      IF Failure1 THEN
         Host^.StopPhaseWithResult( test.trFailure );
      ELSE
         Host^.StopPhaseWithResult( test.trSuccess );
      END;

      scinit.Cleanup();

      IF Failure1 OR Failure2 THEN
         RETURN test.trFailure;
      ELSE
         RETURN test.trSuccess;
      END;
   END Run;
   
(*---------------------------------------------------------------------------*)

BEGIN
   testimpl.tests()^.AddTest( L"SDAPBridge", ADR( Test ));
END CTest;

(*===========================================================================*)

END TBridge.
