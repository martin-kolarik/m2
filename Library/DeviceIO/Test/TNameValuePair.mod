MODULE TNameValuePair;

FROM Storage IMPORT
   ALLOCATE, DEALLOCATE;

IMPORT
   IOO,
   iovalue,
   log,
   ns,
   nsimpl,
   nsinternal,
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
      children, children2 : ns.TPNameValuePairs;
      Failure, SumFailure : BOOLEAN := FALSE;
      hash : ns.THash;
      is : StringsO.CString;
      iv : iovalue.Value;
      name : StringsO.CString;
      nvp : nsinternal.NameValuePairs;
      pairs : ns.TPNameValuePairs;
      ps : StringsO.TPString;
      pvalue : iovalue.TPValue;
      s : StringsO.CString;
   BEGIN
      SELF.Host := Host;

      //----------

      Host^.StartPhase( L"Emptyclass/IMapper" );

      nvp.Dispose();

      s.FromOA( L"Test" );
      Failure := nvp.NameToHash( s, OUT hash ) OR Failure;
      s.Clear();
      Failure := nvp.NameToHash( s, OUT hash ) OR Failure;

      Failure := nvp.HashToName( 0, OUT name ) OR Failure;
      Failure := NOT nvp.HashToName( ADR( nvp ), OUT name ) OR Failure;

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
      Failure := nvp.Child( s, OUT pairs ) OR Failure;
      s.FromOA( L"" );
      Failure := nvp.Child( s, OUT pairs ) OR Failure;
      s.FromOA( L"0" );
      Failure := nvp.Child( s, OUT pairs ) OR Failure;

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
      iv.String := is;
      Failure := NOT nvp.DefineValue( s, iovalue.vtString, iovalue.flagsDefaultRO, ADR( s ), ADR( iv ), OUT children ) OR Failure;
      Failure := nvp.DefineValue( s, iovalue.vtString, iovalue.flagsDefaultRO, ADR( s ), ADR( iv ), OUT children ) OR Failure;

      s.FromOA( L"Member" );
      iv.Long := 2;
      Failure := NOT nvp.DefineValue( s, iovalue.vtLong, iovalue.flagsDefaultRW - iovalue.TFlags{iovalue.vfUndefined}, ADR( s ), ADR( iv ), OUT children ) OR Failure;
      Failure := nvp.DefineValue( s, iovalue.vtString, iovalue.flagsDefaultRW - iovalue.TFlags{iovalue.vfUndefined}, ADR( s ), ADR( iv ), OUT children ) OR Failure;

      s.FromOA( L"ArrayOfValues" );
      Failure := NOT nvp.DefineValue( s, iovalue.vtObject, iovalue.flagsDefaultObject, ADR( s ), NIL, OUT children ) OR Failure;
      Failure := nvp.DefineValue( s, iovalue.vtString, iovalue.flagsDefaultRW, ADR( s ), NIL, OUT children ) OR Failure;
      //---
      s.FromOA( L"0" );
      iv.Integer := 0;
      Failure := NOT children^.DefineValue( s, iovalue.vtInteger, iovalue.flagsDefaultRW, ADR( s ), ADR( iv ), OUT children2 ) OR Failure;
      Failure := children^.DefineValue( s, iovalue.vtInteger, iovalue.flagsDefaultRW, ADR( s ), ADR( iv ), OUT children2 ) OR Failure;
      //---
      s.FromOA( L"1" );
      iv.Integer := 10;
      Failure := NOT children^.DefineValue( s, iovalue.vtInteger, iovalue.flagsDefaultRW, ADR( s ), ADR( iv ), OUT children2 ) OR Failure;
      Failure := children^.DefineValue( s, iovalue.vtInteger, iovalue.flagsDefaultRW, ADR( s ), ADR( iv ), OUT children2 ) OR Failure;
      //---
      s.FromOA( L"2" );
      iv.Integer := 20;
      Failure := NOT children^.DefineValue( s, iovalue.vtInteger, iovalue.flagsDefaultRW, ADR( s ), ADR( iv ), OUT children2 ) OR Failure;
      Failure := children^.DefineValue( s, iovalue.vtInteger, iovalue.flagsDefaultRW, ADR( s ), ADR( iv ), OUT children2 ) OR Failure;
      //---

      IF Failure THEN
         Host^.StopPhaseWithResult( test.trFailure );
      ELSE
         Host^.StopPhaseWithResult( test.trSuccess );
      END;
      SumFailure := SumFailure OR Failure;
      Failure := FALSE;

      //----------

      Host^.StartPhase( L"FilledClass/IMapper" );

      s.FromOA( L"Test" );
      Failure := nvp.NameToHash( s, OUT hash ) OR Failure;
      s.Clear();
      Failure := nvp.NameToHash( s, OUT hash ) OR Failure;
      s.FromOA( L"ArrayOfValues" );
      Failure := NOT nvp.NameToHash( s, OUT hash ) OR Failure;
      Failure := NOT nvp.Child( s, OUT children ) OR Failure;

      Failure := nvp.HashToName( 0, OUT name ) OR Failure;
      Failure := NOT nvp.HashToName( ADR( nvp ), OUT name ) OR NOT name.Empty OR Failure;
      Failure := NOT nvp.HashToName( hash, OUT name ) OR NOT name.Equals( StringsO.FromOA( L"ArrayOfValues" )) OR Failure;

      Failure := nsimpl.HashToValue( 0, OUT pvalue ) OR Failure;
      Failure := NOT nsimpl.HashToValue( ADR( nvp ), OUT pvalue ) OR Failure;
      Failure := NOT nsimpl.HashToValue( hash, OUT pvalue ) OR Failure;

      s.FromOA( L"1" );
      Failure := NOT children^.Child( s, OUT children2 ) OR Failure;
      Failure := ( children2^.Name = NIL ) OR NOT StringsO.FromOA( L"1" ).Equals( children2^.Name^ ) OR Failure;

      IF Failure THEN
         Host^.StopPhaseWithResult( test.trFailure );
      ELSE
         Host^.StopPhaseWithResult( test.trSuccess );
      END;
      SumFailure := SumFailure OR Failure;
      Failure := FALSE;

      //----------

      Host^.StartPhase( L"FilledClass/INameValuePairs" );

      s.Clear();
      Failure := nvp.Map( s, OUT pvalue ) OR Failure;
      s.FromOA( L"Member" );
      Failure := NOT nvp.Map( s, OUT pvalue ) OR ( pvalue^.Long <> 2 ) OR Failure;

      ps := nvp.Name;
      Failure := ( ps = NIL ) OR NOT ps^.Empty OR Failure;
      Failure := ( nvp.Parent <> NIL ) OR Failure;
      s.FromOA( L"ArrayOfValues" );
      Failure := NOT nvp.Child( s, OUT children ) OR Failure;
      ps := children^.Name;
      Failure := ( ps = NIL ) OR NOT ps^.Equals( StringsO.FromOA( L"ArrayOfValues" )) OR Failure;
      Failure := ( children^.Parent = NIL ) OR ( children^.Parent <> ADR( nvp.INameValuePairs )) OR Failure;

      IF Failure THEN
         Host^.StopPhaseWithResult( test.trFailure );
      ELSE
         Host^.StopPhaseWithResult( test.trSuccess );
      END;
      SumFailure := SumFailure OR Failure;
      Failure := FALSE;

      //----------

      Host^.StartPhase( L"FilledClass/NameValuePairs" );

      s.FromOA( L"ALink" );
      Failure := NOT nvp.DefineLink( s, iovalue.TFlags{iovalue.vfHidden}, ADR( nvp ), 0 ) OR Failure;
      Failure := nvp.DefineLink( s, iovalue.TFlags{iovalue.vfHidden}, ADR( nvp ), 0 ) OR Failure;
      Failure := NOT nvp.Map( s, OUT pvalue ) OR ( pvalue = NIL ) OR ( pvalue^.Type <> iovalue.vtLink ) OR ( pvalue^.Link <> PTR( ADR( nvp ))) OR Failure;

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