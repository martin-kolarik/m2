MODULE TDiskInfo;

FROM Storage IMPORT
   ALLOCATE, DEALLOCATE;

IMPORT
   DiskInfo,
   log,
   Strings,
   StringsO,
   sync,
   test,
   testimpl,
   Uniquer;
  
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
   VAR
      DI : DiskInfo.CDiskInfo;
      i : CARDINAL;
      MACSource : Uniquer.MACSource;
      uid : Uniquer.TUId;
   BEGIN
      SELF.Host := Host;

      Host^.StartPhase( L"Check drives" );
      
      FOR i := 0 TO 25 DO
	      IF DiskInfo.LoadDiskInfo( i, OUT DI ) THEN
	         Host^.Log^.LogS( log.lcError, 0, L"", OA( DI.Model.Length-1, DI.Model.Data ));
	      END;
      END;
      
      Host^.StopPhaseWithResult( test.trSuccess );

      Host^.StartPhase( L"MAC Source" );

      uid := MACSource.UId;      
      
      Host^.StopPhaseWithResult( test.trSuccess );

      RETURN test.trSuccess;
   END Run;
   
(*---------------------------------------------------------------------------*)

BEGIN
   testimpl.tests()^.AddTest( L"UniqueSource", ADR( Test ));
END CTest;

(*===========================================================================*)

END TDiskInfo.
