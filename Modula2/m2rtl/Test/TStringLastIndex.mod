MODULE TStringLastIndex;

FROM Debug IMPORT
   AssertionW;

FROM Storage IMPORT
   ALLOCATE, DEALLOCATE;

IMPORT
   log,
   Strings,
   test,
   testimpl;
  
(*===========================================================================*)

CLASS CTest IMPLEMENTS test.ITest;
   PUBLIC VIRTUAL PROCEDURE Run( CONST Host : test.TPHost; CONST Parameters : ARRAY OF PWCHAR ) : test.TTestResult;
END CTest;

(*---------------------------------------------------------------------------*)

TYPE
   TPTest = POINTER TO CTest;
VAR
   Test : CTest;

(*===========================================================================*)

CLASS IMPLEMENTATION CTest;

(*---------------------------------------------------------------------------*)

   PUBLIC VIRTUAL PROCEDURE Run( CONST Host : test.TPHost; CONST Parameters : ARRAY OF PWCHAR ) : test.TTestResult;
   CONST
      TEMPLATE = L"ahaj ahaj ahahajhaj ahaj ahaj ahaj ahaj";
      ITEM = L"ahaj";
   VAR
      i : INTEGER;
   BEGIN
      Host^.StartPhase( L"FirstIndex" );
      
      i := Strings.IndexOfW( TEMPLATE, ITEM, 0 );
      Host^.ParticleWithResult( L"@0", i = 0 );

      i := Strings.IndexOfW( TEMPLATE, ITEM, 2 );
      Host^.ParticleWithResult( L"@2", i = 5 );

      i := Strings.IndexOfW( TEMPLATE, ITEM, 9 );
      Host^.ParticleWithResult( L"@9", i = 12 );

      i := Strings.IndexOfW( TEMPLATE, ITEM, 10 );
      Host^.ParticleWithResult( L"@10", i = 12 );

      i := Strings.IndexOfW( TEMPLATE, ITEM, 40 );
      Host^.ParticleWithResult( L"@40", i = -1 );

      i := Strings.IndexOfW( TEMPLATE, ITEM, 35 );
      Host^.ParticleWithResult( L"@35", i = 35 );

      i := Strings.IndexOfW( TEMPLATE, ITEM, 34 );
      Host^.ParticleWithResult( L"@34", i = 35 );

      i := Strings.IndexOfW( TEMPLATE, ITEM, 36 );
      Host^.ParticleWithResult( L"@36", i = -1 );

      i := Strings.IndexOfW( TEMPLATE, ITEM, 70 );
      Host^.ParticleWithResult( L"@70", i = -1 );

      i := Strings.IndexOfW( ITEM, TEMPLATE, 0 );
      Host^.ParticleWithResult( L"@0r", i = -1 );

      i := Strings.IndexOfW( TEMPLATE, TEMPLATE, 0 );
      Host^.ParticleWithResult( L"@00", i = 0 );

      i := Strings.IndexOfW( TEMPLATE, TEMPLATE, -1 );
      Host^.ParticleWithResult( L"@-1", i = -1 );

      Host^.StopPhase();

      Host^.StartPhase( L"LastIndex" );

      i := Strings.LastIndexOfW( TEMPLATE, ITEM, -1 );
      Host^.ParticleWithResult( L"@-1", i = -1 );

      i := Strings.LastIndexOfW( TEMPLATE, ITEM, 0 );
      Host^.ParticleWithResult( L"@0", i = 35 );

      i := Strings.LastIndexOfW( TEMPLATE, ITEM, 2 );
      Host^.ParticleWithResult( L"@2", i = 30 );

      i := Strings.LastIndexOfW( TEMPLATE, ITEM, 40 );
      Host^.ParticleWithResult( L"@40", i = -1 );

      i := Strings.LastIndexOfW( TEMPLATE, ITEM, 20 );
      Host^.ParticleWithResult( L"@20", i = 12 );

      i := Strings.LastIndexOfW( TEMPLATE, ITEM, 21 );
      Host^.ParticleWithResult( L"@21", i = 12 );

      i := Strings.LastIndexOfW( TEMPLATE, ITEM, 35 );
      Host^.ParticleWithResult( L"@35", i = 0 );

      i := Strings.LastIndexOfW( TEMPLATE, ITEM, 34 );
      Host^.ParticleWithResult( L"@34", i = 0 );

      i := Strings.LastIndexOfW( TEMPLATE, ITEM, 36 );
      Host^.ParticleWithResult( L"@36", i = -1 );

      i := Strings.LastIndexOfW( TEMPLATE, ITEM, 70 );
      Host^.ParticleWithResult( L"@70", i = -1 );

      i := Strings.LastIndexOfW( ITEM, TEMPLATE, 0 );
      Host^.ParticleWithResult( L"@0r", i = -1 );

      i := Strings.LastIndexOfW( TEMPLATE, TEMPLATE, 0 );
      Host^.ParticleWithResult( L"@00", i = 0 );

      i := Strings.LastIndexOfW( TEMPLATE, TEMPLATE, -1 );
      Host^.ParticleWithResult( L"@-1", i = -1 );

      Host^.StopPhase();

      RETURN test.trUnknown;
   END Run;
   
(*---------------------------------------------------------------------------*)

BEGIN
   testimpl.tests()^.AddTest( L"StringLastIndex", ADR( Test ));
END CTest;

(*===========================================================================*)

END TStringLastIndex.