MODULE TNameValuePair;

FROM Storage IMPORT
   ALLOCATE, DEALLOCATE;

IMPORT
   IOO,
   iovalue,
   log,
   namevaluepairsbase,
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
      children, children2 : ns.TPNameValuePairs;
      Failure, SumFailure : BOOLEAN := FALSE;
      is : StringsO.CString;
      iv : iovalue.Value;
      nvp : namevaluepairsbase.NameValuePairsStorage;
      pairs : ns.TPNameValuePairs;
      s : StringsO.CString;
      subnvp : namevaluepairsbase.NameValuePairsStorage;
   BEGIN
      SELF.Host := Host;

      //----------

      Host^.StartPhase( L"Emptyclass/INameValuePairs" );

      s := nvp.Name;
      Failure := NOT s.Empty OR Failure;
      pairs := nvp.Parent;
      Failure := ( pairs <> NIL ) OR Failure;

      s.FromOA( L"Test" );
      Failure := nvp.Get( s, OUT pairs ) OR Failure;
      s.FromOA( L"" );
      Failure := nvp.Get( s, OUT pairs ) OR Failure;
      s.FromOA( L"0" );
      Failure := nvp.Get( s, OUT pairs ) OR Failure;

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

      subnvp.InitializeName := StringsO.FromOA( L"SubValues" );
      Failure := NOT nvp.Link( subnvp.Name, ADR( subnvp )) OR Failure;
      Failure := nvp.Link( subnvp.Name, ADR( subnvp )) OR Failure;

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
      Failure := nvp.Get( s, OUT pairs ) OR Failure;
      s.FromOA( L"Member" );
      Failure := NOT nvp.Get( s, OUT pairs ) OR ( pairs^.Value.Long <> 2 ) OR Failure;

      s := nvp.Name;
      Failure := NOT s.Empty OR Failure;
      Failure := ( nvp.Parent <> NIL ) OR Failure;
      s.FromOA( L"ArrayOfValues" );
      Failure := NOT nvp.Get( s, OUT children ) OR Failure;
      s := children^.Name;
      Failure := NOT s.Equals( StringsO.FromOA( L"ArrayOfValues" )) OR Failure;
      Failure := ( children^.Parent = NIL ) OR Failure;

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
      Failure := NOT nvp.DefineReference( s, iovalue.TFlags{iovalue.vfHidden}, ADR( nvp ), 0 ) OR Failure;
      Failure := nvp.DefineReference( s, iovalue.TFlags{iovalue.vfHidden}, ADR( nvp ), 0 ) OR Failure;
      Failure := NOT nvp.Get( s, OUT pairs ) OR ( pairs = NIL ) OR ( pairs^.Value.Type <> iovalue.vtReference ) OR ( pairs^.Value.Reference <> PTR( ADR( nvp ))) OR Failure;

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