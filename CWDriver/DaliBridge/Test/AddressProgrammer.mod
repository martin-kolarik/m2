MODULE AddressProgrammer;

FROM Storage IMPORT
   ALLOCATE, DEALLOCATE;

IMPORT
   DaliBridge,
   log,
   sync,
   test,
   testimpl,
   time;
  
(*===========================================================================*)

TYPE
   TPTest = POINTER TO CTest;

(*---------------------------------------------------------------------------*)

CLASS CTest IMPLEMENTS test.ITest;
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
      address : DaliBridge.TProgramAddress;
      Failure : BOOLEAN := FALSE;
      i : CARDINAL;
      Prg : DaliBridge.CDaliAddressSeeker;
      Random : INTEGER;
   BEGIN

      FOR i := 0 TO 1<<24-1 DO
         Prg.Init();
         
         Random := i;
         
         LOOP
            CASE Prg.GetAddressToCheck( OUT address ) OF
            | DaliBridge.getTRUE :
               Prg.HandleResponse( Random <= address.C24 );
            | DaliBridge.getFALSE : // not found, failure
               Host^.Log^.LogSC( log.dlcError, L"", L"Not found, random: ", Random );
               Host^.Log^.LogSC( log.dlcError, L"", L"          address: ", address.C24 );
               EXIT;
            | DaliBridge.getFOUND : // ok

               IF Random = 1 * 256 + 2 * 256 * 256 + 3 * 256 * 256 * 256 THEN
                  IF address.L8 <> 1 THEN // failure
                     Host^.Log^.LogSC( log.dlcError, L"", L"Failure in L byte, expected 1, found: ", CARDINAL( address.L8 ));
                  END;
                  IF address.M8 <> 2 THEN // failure
                     Host^.Log^.LogSC( log.dlcError, L"", L"Failure in M byte, expected 1, found: ", CARDINAL( address.M8 ));
                  END;
                  IF address.H8 <> 3 THEN // failure
                     Host^.Log^.LogSC( log.dlcError, L"", L"Failure in H byte, expected 1, found: ", CARDINAL( address.H8 ));
                  END;
               END;

               EXIT;
            END;
         END; // LOOP   

      END; // FOR
   
      IF Failure THEN
         RETURN test.trFailure;
      ELSE
         RETURN test.trSuccess;
      END;
   END Run;
   
(*---------------------------------------------------------------------------*)

BEGIN
   testimpl.tests()^.AddTest( L"Programmer", ADR( Test ));
END CTest;

(*===========================================================================*)

END AddressProgrammer.
