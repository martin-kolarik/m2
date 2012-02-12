MODULE TNamespace;

FROM Storage IMPORT
   ALLOCATE, DEALLOCATE;

IMPORT
   IOO,
   iovalue,
   log,
   namevaluepairsimpl,
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
      nss : nsimpl.Namespace;
      pairs : ns.TPNameValuePairs;
      s : StringsO.CString;
      subnvp : namevaluepairsimpl.NameValuePairsStorage;
   BEGIN
      SELF.Host := Host;

      //----------

      Host^.StartPhase( L"NameValuePairs.Emptyclass/INameValuePairs" );

      s := nss.Name;
      Failure := NOT s.Empty OR Failure;
      pairs := nss.Parent;
      Failure := ( pairs <> NIL ) OR Failure;

      s.FromOA( L"Test" );
      Failure := nss.Get( s, OUT pairs ) OR Failure;
      s.FromOA( L"" );
      Failure := nss.Get( s, OUT pairs ) OR Failure;
      s.FromOA( L"2" );
      Failure := nss.Get( s, OUT pairs ) OR Failure;

      IF Failure THEN
         Host^.StopPhaseWithResult( test.trFailure );
      ELSE
         Host^.StopPhaseWithResult( test.trSuccess );
      END;
      SumFailure := SumFailure OR Failure;
      Failure := FALSE;

      //----------

      Host^.StartPhase( L"NameValuePairs.Filling/CNameValuePair" );

      // SELF
      s.FromOA( L"Function" );
      is.FromOA( L"someInitialName" );
      iv.String := is;
      Failure := NOT nss.DefineStorageValue( s, iovalue.vtString, iovalue.flagsDefaultSWRO, ADR( iv ), ADR( s ), NIL, NIL, OUT children ) OR Failure;
      Failure := nss.DefineStorageValue( s, iovalue.vtString, iovalue.flagsDefaultSWRO, ADR( iv ), ADR( s ), NIL, NIL, OUT children ) OR Failure;

      s.FromOA( L"Member" );
      iv.Long := 2;
      Failure := NOT nss.DefineStorageValue( s, iovalue.vtLong, iovalue.flagsDefaultSWRW, ADR( iv ), ADR( s ), NIL, NIL, OUT children ) OR Failure;
      Failure := nss.DefineStorageValue( s, iovalue.vtString, iovalue.flagsDefaultSWRW, ADR( iv ), ADR( s ), NIL, NIL, OUT children ) OR Failure;

      s.FromOA( L"ArrayOfValues" );
      Failure := NOT nss.DefineStorageValue( s, iovalue.vtObject, iovalue.flagsDefaultObject, NIL, ADR( s ), NIL, NIL, OUT children ) OR Failure;
      Failure := nss.DefineStorageValue( s, iovalue.vtString, iovalue.flagsDefaultSWRW, NIL, ADR( s ), NIL, NIL, OUT children ) OR Failure;
      //---
      s.FromOA( L"0" );
      iv.Integer := 0;
      Failure := NOT children^.DefineStorageValue( s, iovalue.vtInteger, iovalue.flagsDefaultSWRW, ADR( iv ), ADR( s ), NIL, NIL, OUT children2 ) OR Failure;
      Failure := children^.DefineStorageValue( s, iovalue.vtInteger, iovalue.flagsDefaultSWRW, ADR( iv ), ADR( s ), NIL, NIL, OUT children2 ) OR Failure;
      //---
      s.FromOA( L"1" );
      iv.Integer := 10;
      Failure := NOT children^.DefineStorageValue( s, iovalue.vtInteger, iovalue.flagsDefaultSWRW, ADR( iv ), ADR( s ), NIL, NIL, OUT children2 ) OR Failure;
      Failure := children^.DefineStorageValue( s, iovalue.vtInteger, iovalue.flagsDefaultSWRW, ADR( iv ), ADR( s ), NIL, NIL, OUT children2 ) OR Failure;
      //---
      s.FromOA( L"2" );
      iv.Integer := 20;
      Failure := NOT children^.DefineStorageValue( s, iovalue.vtInteger, iovalue.flagsDefaultSWRW, ADR( iv ), ADR( s ), NIL, NIL, OUT children2 ) OR Failure;
      Failure := children^.DefineStorageValue( s, iovalue.vtInteger, iovalue.flagsDefaultSWRW, ADR( iv ), ADR( s ), NIL, NIL, OUT children2 ) OR Failure;
      //---

      subnvp.InitializeName := StringsO.FromOA( L"SubValues" );
      Failure := NOT nss.Link( subnvp.Name, ADR( subnvp )) OR Failure;
      Failure := nss.Link( subnvp.Name, ADR( subnvp )) OR Failure;

      IF Failure THEN
         Host^.StopPhaseWithResult( test.trFailure );
      ELSE
         Host^.StopPhaseWithResult( test.trSuccess );
      END;
      SumFailure := SumFailure OR Failure;
      Failure := FALSE;

      //----------

      Host^.StartPhase( L"NameValuePairs.FilledClass/INameValuePairs" );

      s.Clear();
      Failure := nss.Get( s, OUT pairs ) OR Failure;
      s.FromOA( L"Member" );
      Failure := NOT nss.Get( s, OUT pairs ) OR ( pairs^.Value.Long <> 2 ) OR Failure;

      s := nss.Name;
      Failure := NOT s.Empty OR Failure;
      Failure := ( nss.Parent <> NIL ) OR Failure;
      s.FromOA( L"ArrayOfValues" );
      Failure := NOT nss.Get( s, OUT children ) OR Failure;
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

      Host^.StartPhase( L"NameValuePairs.FilledClass/NameValuePairs" );

      s.FromOA( L"ALink" );
      Failure := NOT nss.DefineReference( s, iovalue.TFlags{iovalue.vfHidden}, ADR( nss ), 0 ) OR Failure;
      Failure := nss.DefineReference( s, iovalue.TFlags{iovalue.vfHidden}, ADR( nss ), 0 ) OR Failure;
      Failure := NOT nss.Get( s, OUT pairs ) OR ( pairs = NIL ) OR ( pairs^.Value.Type <> iovalue.vtReference ) OR ( pairs^.Value.Reference <> PTR( ADR( nss ))) OR Failure;

      IF Failure THEN
         Host^.StopPhaseWithResult( test.trFailure );
      ELSE
         Host^.StopPhaseWithResult( test.trSuccess );
      END;
      SumFailure := SumFailure OR Failure;
      Failure := FALSE;

      //----------

      Host^.StartPhase( L"Namespace.FilledClass/INameValuePairs" );

      s := StringsO.FromOA( L"NSS" );
      nss.InitializeName := s;
      Failure := NOT nss.Name.Equals( StringsO.FromOA( L"NSS" )) OR Failure;

      s.FromOA( L"ArrayOfValues" );
      Failure := NOT nss.Contains( s ) OR Failure;

      // hierarchical names
      s.FromOA( L"Class.SubClass.Method.ParameterA" );
      iv.Dispose();
      iv.Long := 3141592653589;
      Failure := NOT nss.DefineStorageValue( s, iovalue.vtLong, iovalue.flagsDefaultSWRW, NIL, ADR( iv ), NIL, NIL, OUT children ) OR Failure;

      s.FromOA( L"Class.SubClass.Method.ParameterB" );
      iv.Dispose();
      iv.Integer := -10000;
      Failure := NOT nss.DefineStorageValue( s, iovalue.vtInteger, iovalue.flagsDefaultSWRW, NIL, ADR( iv ), NIL, NIL, OUT children ) OR Failure;

      s.FromOA( L"Class.SubClass.Prototype" );
      iv.Dispose();
      iv.Reference := 1415;
      Failure := NOT nss.DefineStorageValue( s, iovalue.vtReference, iovalue.flagsDefaultSWRW, NIL, ADR( iv ), NIL, NIL, OUT children ) OR Failure;

      s.FromOA( L"Class.Prototype" );
      Failure := NOT nss.DefineReference( s, iovalue.flagsDefaultSWRW, ADR( iv ), NIL ) OR Failure;

      s.FromOA( L"Class.Prototype.Some" );
      Failure := nss.Contains( s ) OR Failure;

      s.FromOA( L"Class.SubClass.Method.ParameterB" );
      Failure := NOT nss.Contains( s ) OR Failure;

      Failure := NOT nss.Get( s, OUT pairs ) OR Failure;
      Failure := ( pairs = NIL ) OR ( pairs^.Value.Type <> iovalue.vtInteger ) OR ( pairs^.Value.Integer <> -10000 ) OR Failure;

      s.FromOA( L"Class.SubClass" );
      Failure := NOT nss.Get( s, OUT children ) OR Failure;
      s.FromOA( L"Prototype" );
      Failure := NOT children^.Get( s, OUT pairs ) OR Failure;
      Failure := ( pairs = NIL ) OR ( pairs^.Value.Type <> iovalue.vtReference ) OR ( pairs^.Value.Reference <> 1415 ) OR Failure;

      s.FromOA( L"Class.SubClass.Method.ParameterB.Specification" );
      Failure := nss.Get( s, OUT pairs ) OR Failure;

      s.FromOA( L"Class.SubClass.Method.ParameterB" );
      Failure := NOT nss.Get( s, OUT pairs ) OR Failure;
      Failure := NOT nss.GetFullName( pairs, OUT s ) OR Failure;
      Failure := NOT s.Equals( StringsO.FromOA( L"Class.SubClass.Method.ParameterB" )) OR Failure;

      s.FromOA( L"Class.SubClass.Method" );
      Failure := NOT nss.Get( s, OUT pairs ) OR Failure;
      Failure := NOT nss.GetFullName( pairs, OUT s ) OR Failure;
      Failure := NOT s.Equals( StringsO.FromOA( L"Class.SubClass.Method" )) OR Failure;

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
   testimpl.tests()^.AddTest( L"Namespace", ADR( Test ));
END CTest;

(*===========================================================================*)

END TNamespace.