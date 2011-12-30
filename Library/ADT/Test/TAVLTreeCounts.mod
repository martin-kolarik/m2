MODULE TAVLTreeCounts;

FROM Storage IMPORT
   ALLOCATE, DEALLOCATE;

IMPORT
   log,
   maps,
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
      TREE_SIZE = 30;
   VAR
      d : PTR;
      Failure : BOOLEAN := FALSE;
      i : INTEGER;
      j : INTEGER;
      map : maps.CIntegerPtrMap;
      n, s : StringsO.CString;
      value : INTEGER;
   BEGIN
      SELF.Host := Host;

      FOR i := 0 TO TREE_SIZE-1 DO

         Failure := FALSE;
         Host^.StartPhase( L"Iteration" );

         map.Dispose();
         FOR j := 0 TO TREE_SIZE-1 DO
            map.Add( j, 0, 0 );
         END; // FOR
         map.Remove( i );

         s.Clear();
         FOR j := 0 TO TREE_SIZE-2 DO
            IF NOT map.ElementAt( j, OUT value, OUT d, OUT d ) THEN
               Failure := TRUE;
               value := -1;
            ELSIF i <= j THEN
               Failure := Failure OR ( value <> j+1 );
            ELSE
               Failure := Failure OR ( value <> j );
            END;
            n.FromINT32( value, 10 );
            s.Append( n );
            s.AppendOA( L" " );
         END; // FOR
         Host^.Log^.LogS( log.lcInfo, 0, L"", OA( s.Length-1, s.Data ));

         Host^.StopPhaseWithResult( NOT Failure );

      END; // FOR

      RETURN test.trUnknown;
   END Run;
   
(*---------------------------------------------------------------------------*)

BEGIN
   testimpl.tests()^.AddTest( L"AVLCounts", ADR( Test ));
END CTest;

(*===========================================================================*)

END TAVLTreeCounts.
