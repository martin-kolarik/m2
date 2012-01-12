MODULE TAdviser;

FROM Storage IMPORT
   ALLOCATE, DEALLOCATE;

IMPORT
   IOO,
   iovalue,
   log,
   nsimpl,
   Strings,
   StringsO,
   sync,
   test,
   testimpl;
  
(*===========================================================================*)

VAR
   Test : CTest;

(*---------------------------------------------------------------------------*)

CLASS IMPLEMENTATION CTest;

(*---------------------------------------------------------------------------*)

   PUBLIC VIRTUAL PROCEDURE Run( CONST Host : test.TPHost; CONST Parameters : ARRAY OF PWCHAR ) : test.TTestResult;
   VAR
      Failure, SumFailure : BOOLEAN := FALSE;
      hash : ns.THash;
      is : StringO.CString;
      name : StringO.CString;
      nvp : nsimpl.NameValuePairs;
      pairs : TPNameValuePair;
      ps : StringsO.TPString;
      pvalue : iovalue.TPValue;
      s : StringsO.CString;
      value : iovalue.Value;
   BEGIN
      SELF.Host := Host;

      //----------

      Host^.StartPhase( L"Emptyclass/IHierarchicalMapper" );

      nvp.Dispose();

      s.FromOA( L"Test" );
      Failure := nvp.NameToHash( s, OUT hash ) OR Failure;
      s.Clear();
      Failure := nvp.NameToHash( s, OUT hash ) OR Failure;

      Failure := nvp.HashToName( 0, OUT name ) OR Failure;
      Failure := nvp.HashToName( ADR( nvp ), OUT name ) OR Failure;
      Failure := nvp.HashToName( ADR( value ), OUT name ) OR Failure;

      Failure := nvp.HashToValue( 0, OUT value ) OR Failure;
      Failure := nvp.HashToValue( ADR( nvp ), OUT pvalue ) OR Failure;
      Failure := NOT nvp.HashToValue( ADR( value ), OUT pvalue ) OR Failure;

      Failure := nvp.HashToParent( 0, OUT hash ) OR Failure;
      Failure := nvp.HashToParent( ADR( nvp ), OUT hash ) OR Failure;
      Failure := nvp.HashToParent( ADR( value ), OUT hash ) OR Failure;

      IF Failure THEN
         Host^.StopPhaseWithResult( test.trFailure );
      ELSE
         Host^.StopPhaseWithResult( test.trSuccess );
      END;
      SumFailure := SumFailure OR Failure;
      Failure := FALSE;

      //----------

      Host^.StartPhase( L"Emptyclass/INameValuePairs" );

      s.FromOA( L"Test" );
      Failure := nvp.Get( s, OUT pvalue ) OR Failure;
      s.FromOA( L"" );
      Failure := nvp.Get( s, OUT pvalue ) OR Failure;
      s.FromOA( L"2" );
      Failure := nvp.Get( s, OUT pvalue ) OR Failure;

      s.FromOA( L"Test" );
      Failure := nvp.Map( s, OUT pvalue ) OR Failure;
      s.FromOA( L"" );
      Failure := nvp.Map( s, OUT pvalue ) OR Failure;
      s.FromOA( L"2" );
      Failure := nvp.Map( s, OUT pvalue ) OR Failure;

      Failure := nvp.ElementAt( 0, OUT pvalue ) OR Failure;
      Failure := nvp.ElementAt( -1, OUT pvalue ) OR Failure;
      Failure := nvp.ElementAt( 1, OUT pvalue ) OR Failure;

      IF Failure THEN
         Host^.StopPhaseWithResult( test.trFailure );
      ELSE
         Host^.StopPhaseWithResult( test.trSuccess );
      END;
      SumFailure := SumFailure OR Failure;
      Failure := FALSE;

      //----------

      Host^.StartPhase( L"Emptyclass/CNameValuePair" );

      ps := nvp.Name;
      Failure := ( ps = NIL ) OR NOT ps^.Empty OR Failure;
      pairs := nvp.Parent;
      Failure := ( pairs <> NIL ) OR Failure;

      s.FromOA( L"Test" );
      Failure := nvp.Children( s, OUT pairs ) OR Failure;
      s.FromOA( L"" );
      Failure := nvp.Children( s, OUT pairs ) OR Failure;
      s.FromOA( L"0" );
      Failure := nvp.Children( s, OUT pairs ) OR Failure;

      IF Failure THEN
         Host^.StopPhaseWithResult( test.trFailure );
      ELSE
         Host^.StopPhaseWithResult( test.trSuccess );
      END;
      SumFailure := SumFailure OR Failure;
      Failure := FALSE;

      // SELF
      s.FromOA( L"Function" );
      is.FromOA( L"someInitialName" );
      Failure := NOT nvs.DefineValue( s, iovalue.vtString, iovalue.defaultFlagsRO, ADR( s ), is, NIL );
      // PUBLIC PROCEDURE DefineValue( CONST Name : StringsO.IString; Type : iovalue.TType; Flags : iovalue.TFlags; Data : PTR; CONST InitialValue : StringsO.TPString; Children : TPNameValuePairs ) : BOOLEAN;

      //----------

      IF SumFailure THEN
         RETURN test.trFailure;
      ELSE
         RETURN test.trSuccess;
      END;
   END Run;
   
(*---------------------------------------------------------------------------*)

BEGIN
   testimpl.tests()^.AddTest( L"NameValuePair", ADR( Test ));
END CTest;

(*===========================================================================*)

END TAdviser.