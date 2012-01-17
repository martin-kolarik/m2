MODULE TNameValuePair;

FROM Storage IMPORT
   ALLOCATE, DEALLOCATE;

IMPORT
   IOO,
   iovalue,
   log,
   ns,
   nsimpl,
   Strings,
   StringsO,
   sync,
   test,
   testimpl;
  
(*===========================================================================*)

CLASS CTest IMPLEMENTS test.ITest;
   PUBLIC VAR
      Host : test.TPHost := NIL;
   PUBLIC VIRTUAL PROCEDURE Run( CONST Host : test.TPHost; CONST Parameters : ARRAY OF PWCHAR ) : test.TTestResult;
END CTest;

(*---------------------------------------------------------------------------*)

VAR
   Test : CTest;

(*===========================================================================*)

CLASS IMPLEMENTATION CTest;

(*---------------------------------------------------------------------------*)

   PUBLIC VIRTUAL PROCEDURE Run( CONST Host : test.TPHost; CONST Parameters : ARRAY OF PWCHAR ) : test.TTestResult;
   VAR
      children : nsimpl.TPNameValuePairs;
      Failure, SumFailure : BOOLEAN := FALSE;
      hash : ns.THash;
      is : StringsO.CString;
      name : StringsO.CString;
      nvp : nsimpl.NameValuePairs;
      pairs : iovalue.TPNameValuePairs;
      parent : ns.THash;
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
      Failure := nvp.HashToName( ADR( value ), OUT name ) OR Failure;

      Failure := nvp.HashToValue( 0, OUT pvalue ) OR Failure;
      Failure := NOT nvp.HashToValue( ADR( value ), OUT pvalue ) OR Failure;

      Failure := nvp.HashToParent( 0, OUT hash ) OR Failure;
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
      Failure := ( ps <> NIL ) OR Failure;
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

      //----------

      Host^.StartPhase( L"Filling/CNameValuePair" );

      // SELF
      s.FromOA( L"Function" );
      is.FromOA( L"someInitialName" );
      Failure := NOT nvp.DefineValue( s, iovalue.vtString, iovalue.flagsDefaultRO, ADR( s ), ADR( is ), NIL ) OR Failure;
      Failure := nvp.DefineValue( s, iovalue.vtString, iovalue.flagsDefaultRO, ADR( s ), ADR( is ), NIL ) OR Failure;

      s.FromOA( L"Member" );
      is.FromOA( L"2" );
      Failure := NOT nvp.DefineValue( s, iovalue.vtLong, iovalue.flagsDefaultRW, ADR( s ), ADR( is ), NIL ) OR Failure;
      Failure := nvp.DefineValue( s, iovalue.vtString, iovalue.flagsDefaultRW, ADR( s ), ADR( is ), NIL ) OR Failure;

      NEW( children );
      s.FromOA( L"0" );
      is.FromOA( L"0" );
      Failure := NOT children^.DefineValue( s, iovalue.vtInteger, iovalue.flagsDefaultRW, ADR( s ), ADR( is ), NIL ) OR Failure;
      Failure := children^.DefineValue( s, iovalue.vtInteger, iovalue.flagsDefaultRW, ADR( s ), ADR( is ), NIL ) OR Failure;
      //---
      s.FromOA( L"1" );
      is.FromOA( L"10" );
      Failure := NOT children^.DefineValue( s, iovalue.vtInteger, iovalue.flagsDefaultRW, ADR( s ), ADR( is ), NIL ) OR Failure;
      Failure := children^.DefineValue( s, iovalue.vtInteger, iovalue.flagsDefaultRW, ADR( s ), ADR( is ), NIL ) OR Failure;
      //---
      s.FromOA( L"2" );
      is.FromOA( L"20" );
      Failure := NOT children^.DefineValue( s, iovalue.vtInteger, iovalue.flagsDefaultRW, ADR( s ), ADR( is ), NIL ) OR Failure;
      Failure := children^.DefineValue( s, iovalue.vtInteger, iovalue.flagsDefaultRW, ADR( s ), ADR( is ), NIL ) OR Failure;
      //---
      s.FromOA( L"ArrayOfValues" );
      Failure := NOT nvp.DefineValue( s, iovalue.vtObject, iovalue.flagsDefaultObject, ADR( s ), NIL, children ) OR Failure;
      Failure := nvp.DefineValue( s, iovalue.vtString, iovalue.flagsDefaultRW, ADR( s ), NIL, children ) OR Failure;

      // PUBLIC PROCEDURE DefineValue( CONST Name : StringsO.IString; Type : iovalue.TType; Flags : iovalue.TFlags; Data : PTR; CONST InitialValue : StringsO.TPString; Children : TPNameValuePairs ) : BOOLEAN;

      IF Failure THEN
         Host^.StopPhaseWithResult( test.trFailure );
      ELSE
         Host^.StopPhaseWithResult( test.trSuccess );
      END;
      SumFailure := SumFailure OR Failure;
      Failure := FALSE;

      //----------

      Host^.StartPhase( L"FilledClass/IHierarchicalMapper" );

      s.FromOA( L"Test" );
      Failure := nvp.NameToHash( s, OUT hash ) OR Failure;
      s.Clear();
      Failure := nvp.NameToHash( s, OUT hash ) OR Failure;
      s.FromOA( L"ArrayOfValues" );
      Failure := NOT nvp.NameToHash( s, OUT hash ) OR Failure;

      Failure := nvp.HashToName( 0, OUT name ) OR Failure;
      Failure := nvp.HashToName( ADR( value ), OUT name ) OR Failure;
      Failure := NOT nvp.HashToName( hash, OUT name ) OR Failure;

      Failure := nvp.HashToValue( 0, OUT pvalue ) OR Failure;
      Failure := NOT nvp.HashToValue( ADR( value ), OUT pvalue ) OR Failure;
      Failure := NOT nvp.HashToValue( hash, OUT pvalue ) OR Failure;

      Failure := nvp.HashToParent( 0, OUT hash ) OR Failure;
      Failure := nvp.HashToParent( ADR( value ), OUT hash ) OR Failure;
      Failure := NOT nvp.HashToParent( hash, OUT parent ) OR Failure;

      // toto uz je blbe
      s.FromOA( L"1" );
      Failure := NOT children^.NameToHash( s, OUT hash ) OR Failure;
      Failure := NOT nvp.HashToName( hash, OUT name ) OR Failure;
      Failure := nvp.HashToParent( hash, OUT parent ) OR Failure; // !! shall it be or not?

      IF Failure THEN
         Host^.StopPhaseWithResult( test.trFailure );
      ELSE
         Host^.StopPhaseWithResult( test.trSuccess );
      END;
      SumFailure := SumFailure OR Failure;
      Failure := FALSE;

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

END TNameValuePair.