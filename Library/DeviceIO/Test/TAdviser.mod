MODULE TAdviser;

FROM Storage IMPORT
   ALLOCATE, DEALLOCATE;

IMPORT
   adviser,
   device,
   io,
   IOO,
   iovalue,
   iplugin,
   log,
   ns,
   Strings,
   StringsO,
   sync,
   test,
   testimpl;
  
(*===========================================================================*)

TYPE
   TPClient = POINTER TO CClient;
   TPTest = POINTER TO CTest;

(*===========================================================================*)

CLASS CSimulator IMPLEMENTS io.IIO, ns.IMapper, device.IDevice;

   PRIVATE VAR
      _AdviseListener : io.TPIAdviseInfo := NIL;

   // IPluginObject
   PUBLIC VIRTUAL READONLY PROPERTY
      Type : iplugin.TObjectType;
      OfPlugin : iplugin.TPPlugin;
      OwnerHandle : PTR;

   // IDevice
   PUBLIC VIRTUAL READONLY PROPERTY
      DeviceCapabilities : device.TCapabilities;

	PUBLIC VIRTUAL PROCEDURE Configure( CONST Source : ARRAY OF device.TConfigureItem; CONST Log : log.TPLogger ) : sync.TAsyncResult;

   PUBLIC VIRTUAL PROCEDURE Mapper() : ns.TPMapper; // required
	PUBLIC VIRTUAL PROCEDURE NS() : ns.TPns; // optional

	PUBLIC VIRTUAL PROCEDURE IO() : io.TPIO; // required
	
	// IIO
   PUBLIC VIRTUAL READONLY PROPERTY
      IOCapabilities : io.TCapabilities;
      Pending : BOOLEAN;
      Running : BOOLEAN;
   PUBLIC VIRTUAL PROPERTY
      Advise : io.TAdvise;
      AdviseListener : io.TPIAdviseInfo; // for Advise <> advNone

   PUBLIC VIRTUAL PROCEDURE Start() : sync.TAsyncResult;
   PUBLIC VIRTUAL PROCEDURE Stop();

   PUBLIC VIRTUAL PROCEDURE IOh( CONST Originator : io.TPOriginator; Direction : IOO.TDirection; Item : ns.THash; REF Value : iovalue.Value; Callback : io.TPDataInfo ) : sync.TAsyncResult;
   PUBLIC VIRTUAL PROCEDURE IOha( CONST Originator : io.TPOriginator; Direction : IOO.TDirection; Item : ARRAY OF ns.THash; REF Value : ARRAY OF iovalue.Value; Callback : io.TPDataInfo ) : sync.TAsyncResult;

   PUBLIC VIRTUAL PROCEDURE AbortAll(); // As IIO is allowed to run single operation only Abort does not need more parameters. But because ancestors
	
	// IMapper
   PUBLIC VIRTUAL PROCEDURE NameToHash( CONST Name : StringsO.IString; OUT Hash : ns.THash ) : BOOLEAN;
   PUBLIC VIRTUAL PROCEDURE HashToName( CONST Hash : ns.THash; OUT Name : StringsO.IString ) : BOOLEAN;
   
   // SELF
   LOCAL PROCEDURE Simulate();

END CSimulator;

(*---------------------------------------------------------------------------*)

CLASS CTest IMPLEMENTS test.ITest, io.IAdviseInfo;
   PUBLIC VAR
      Host : test.TPHost := NIL;
      Count : CARDINAL := 0;

   PUBLIC VIRTUAL PROCEDURE Run( CONST Host : test.TPHost; CONST Parameters : ARRAY OF PWCHAR ) : test.TTestResult;

   PUBLIC VIRTUAL PROCEDURE OnAdvise( Source : io.TPIO; CONST Result : ARRAY OF sync.TAsyncResult; CONST Item : ARRAY OF ns.THash; CONST Value : ARRAY OF iovalue.Value );
END CTest;

(*---------------------------------------------------------------------------*)

CLASS CClient IMPLEMENTS io.IAdviseInfo;
   LOCAL VAR
      Test : TPTest := NIL;
   PUBLIC VIRTUAL PROCEDURE OnAdvise( Source : io.TPIO; CONST Result : ARRAY OF sync.TAsyncResult; CONST Item : ARRAY OF ns.THash; CONST Value : ARRAY OF iovalue.Value );
END CClient;

(*===========================================================================*)

CLASS IMPLEMENTATION CSimulator;

(*---------------------------------------------------------------------------*)

   PUBLIC VIRTUAL PROPERTY Type GET : iplugin.TObjectType;
   BEGIN
      RETURN iplugin.otSingleton;
   END Type;

(*---------------------------------------------------------------------------*)

   PUBLIC VIRTUAL PROPERTY OfPlugin GET : iplugin.TPPlugin;
   BEGIN
      RETURN NIL;
   END OfPlugin;

(*---------------------------------------------------------------------------*)

   PUBLIC VIRTUAL PROPERTY OwnerHandle GET : PTR;
   BEGIN
      RETURN NIL;
   END OwnerHandle;

(*---------------------------------------------------------------------------*)

   PUBLIC VIRTUAL PROPERTY DeviceCapabilities GET : device.TCapabilities;
   BEGIN
      RETURN device.TCapabilities{};
   END DeviceCapabilities;

(*---------------------------------------------------------------------------*)

	PUBLIC VIRTUAL PROCEDURE Configure( CONST Source : ARRAY OF device.TConfigureItem; CONST Log : log.TPLogger ) : sync.TAsyncResult;
	BEGIN
	   RETURN sync.arCompleted;
	END Configure;
	
(*---------------------------------------------------------------------------*)

   PUBLIC VIRTUAL PROCEDURE Mapper() : ns.TPMapper;
   BEGIN
      RETURN ADR( SELF );
   END Mapper;

(*---------------------------------------------------------------------------*)

	PUBLIC VIRTUAL PROCEDURE NS() : ns.TPns;
   BEGIN
      RETURN NIL;
   END NS;

(*---------------------------------------------------------------------------*)

	PUBLIC VIRTUAL PROCEDURE IO() : io.TPIO;
   BEGIN
      RETURN ADR( SELF );
   END IO;

(*---------------------------------------------------------------------------*)

   PUBLIC VIRTUAL PROPERTY IOCapabilities GET : io.TCapabilities;
   BEGIN
      RETURN io.TCapabilities{io.capAdvise};
   END IOCapabilities;

(*---------------------------------------------------------------------------*)

   PUBLIC VIRTUAL PROPERTY Pending GET : BOOLEAN;
   BEGIN
      RETURN FALSE;
   END Pending;

(*---------------------------------------------------------------------------*)

   PUBLIC VIRTUAL PROPERTY Running GET : BOOLEAN;
   BEGIN
      RETURN TRUE;
   END Running;

(*---------------------------------------------------------------------------*)

   PUBLIC VIRTUAL PROPERTY Advise GET : io.TAdvise;
   BEGIN
      RETURN io.advWithData;
   END Advise;

(*---------------------------------------------------------------------------*)

   PUBLIC VIRTUAL PROPERTY Advise SET( Value : io.TAdvise );
   BEGIN
   END Advise;

(*---------------------------------------------------------------------------*)

   PUBLIC VIRTUAL PROPERTY AdviseListener GET : io.TPIAdviseInfo;
   BEGIN
      RETURN _AdviseListener;
   END AdviseListener;

(*---------------------------------------------------------------------------*)

   PUBLIC VIRTUAL PROPERTY AdviseListener SET( Value : io.TPIAdviseInfo );
   BEGIN
      _AdviseListener := Value;
   END AdviseListener;

(*---------------------------------------------------------------------------*)

   PUBLIC VIRTUAL PROCEDURE Start() : sync.TAsyncResult;
   BEGIN
      RETURN sync.arCompleted;
   END Start;

(*---------------------------------------------------------------------------*)

   PUBLIC VIRTUAL PROCEDURE Stop();
   BEGIN
   END Stop;

(*---------------------------------------------------------------------------*)

   PUBLIC VIRTUAL PROCEDURE IOh( CONST Originator : io.TPOriginator; Direction : IOO.TDirection; Item : ns.THash; REF Value : iovalue.Value; Callback : io.TPDataInfo ) : sync.TAsyncResult;
   BEGIN
      RETURN sync.arCannotStart;
   END IOh;

(*---------------------------------------------------------------------------*)

   PUBLIC VIRTUAL PROCEDURE IOha( CONST Originator : io.TPOriginator; Direction : IOO.TDirection; Item : ARRAY OF ns.THash; REF Value : ARRAY OF iovalue.Value; Callback : io.TPDataInfo ) : sync.TAsyncResult;
   BEGIN
      RETURN sync.arCannotStart;
   END IOha;

(*---------------------------------------------------------------------------*)

   PUBLIC VIRTUAL PROCEDURE AbortAll(); // As IIO is allowed to run single operation only Abort does not need more parameters. But because ancestors
   BEGIN
   END AbortAll;

(*---------------------------------------------------------------------------*)

   PUBLIC VIRTUAL PROCEDURE NameToHash( CONST Name : StringsO.IString; OUT Hash : ns.THash ) : BOOLEAN;
   BEGIN
      IF Name.EqualsOA( L"N1" ) THEN
         Hash := 1;
      ELSIF Name.EqualsOA( L"N2" ) THEN
         Hash := 2;
      ELSIF Name.EqualsOA( L"N3" ) THEN
         Hash := 3;
      ELSIF Name.EqualsOA( L"N4" ) THEN
         Hash := 4;
      ELSIF Name.EqualsOA( L"N1000" ) THEN
         Hash := 1000;
      ELSIF Name.EqualsOA( L"N1001" ) THEN
         Hash := 1001;
      ELSIF Name.EqualsOA( L"N1002" ) THEN
         Hash := 1002;
      ELSIF Name.EqualsOA( L"N1003" ) THEN
         Hash := 1003;
      ELSE
         RETURN FALSE;
      END;
      RETURN TRUE;
   END NameToHash;

(*---------------------------------------------------------------------------*)

   PUBLIC VIRTUAL PROCEDURE HashToName( CONST Hash : ns.THash; OUT Name : StringsO.IString ) : BOOLEAN;
   BEGIN
      CASE CARDINAL( LOPTRLONGWORD( Hash )) OF
      | 1 : Name.FromOA( L"N1" );
      | 2 : Name.FromOA( L"N2" );
      | 3 : Name.FromOA( L"N3" );
      | 4 : Name.FromOA( L"N4" );
      | 1000 : Name.FromOA( L"N1000" );
      | 1001 : Name.FromOA( L"N1001" );
      | 1002 : Name.FromOA( L"N1002" );
      | 1003 : Name.FromOA( L"N1003" );
      ELSE
         RETURN FALSE;
      END;
      RETURN TRUE;
   END HashToName;

(*---------------------------------------------------------------------------*)

   LOCAL PROCEDURE Simulate();
   VAR
      ios : ARRAY [0..3] OF iovalue.Value;
      Items : ARRAY [0..3] OF ns.THash;
      Results : ARRAY [0..3] OF sync.TAsyncResult;
   BEGIN
      IF _AdviseListener = NIL THEN
         RETURN;
      END;
      
      Results[0] := sync.arCompleted;
      Results[1] := sync.arAborted;
      Results[2] := sync.arCompleted;
      Results[3] := sync.arAborted;
      
      Items[0] := 2;
      Items[1] := 1001;
      Items[2] := 3;
      Items[3] := 1002;

      ios[0].FromStringOA( L"simval1", FALSE );
      ios[1].FromStringOA( L"simval2", FALSE );
      ios[2].FromStringOA( L"simval3", FALSE );
      ios[3].FromStringOA( L"simval4", FALSE );
      
      _AdviseListener^.OnAdvise( ADR( SELF ), Results, Items, OA( 3, ADR( ios[0] )));

      _AdviseListener^.OnAdvise( ADR( SELF ), OA( 0, ADR( Results[0] )), OA( 0, ADR( Items[0] )), OA( 0, ADR( ios[0] )));
   END Simulate;

(*---------------------------------------------------------------------------*)

BEGIN
END CSimulator;

(*===========================================================================*)

CLASS IMPLEMENTATION CClient;

(*---------------------------------------------------------------------------*)

   PUBLIC VIRTUAL PROCEDURE OnAdvise( Source : io.TPIO; CONST Result : ARRAY OF sync.TAsyncResult; CONST Item : ARRAY OF ns.THash; CONST Value : ARRAY OF iovalue.Value );
   BEGIN
      IF Test <> NIL THEN
         Test^.OnAdvise( Source, Result, Item, Value );
      END;
   END OnAdvise;

(*---------------------------------------------------------------------------*)

BEGIN
END CClient;

(*===========================================================================*)

VAR
   Test : CTest;

(*---------------------------------------------------------------------------*)

CLASS IMPLEMENTATION CTest;

(*---------------------------------------------------------------------------*)

   PUBLIC VIRTUAL PROCEDURE Run( CONST Host : test.TPHost; CONST Parameters : ARRAY OF PWCHAR ) : test.TTestResult;
   VAR
      Adviser : POINTER TO adviser.CAdviser;
      c1, c2, c3, c4, c5 : TPClient;
      s : StringsO.CString;
      Failure1, Failure2 : BOOLEAN := FALSE;
      Simulator : CSimulator;
   BEGIN
      SELF.Host := Host;

      (*==========*)

      Host^.StartPhase( L"Register single client more times" );
      
      NEW( Adviser );
      Adviser^.JoinClient( ADR( SELF ), io.advWithData );
      Adviser^.JoinClient( ADR( SELF ), io.advWithData );
      Adviser^.JoinClient( ADR( SELF ), io.advWithData );
      Adviser^.JoinClient( ADR( SELF ), io.advWithData );
      Adviser^.JoinClient( ADR( SELF ), io.advWithData );
      Adviser^.LeaveClient( ADR( SELF )); // should stay empty
      Failure1 := NOT Adviser^.Empty;
      
      Adviser^.JoinClient( ADR( SELF ), io.advWithData );
      Adviser^.LeaveClient( ADR( SELF ));
      Failure2 := NOT Adviser^.Empty;

      Adviser^.LeaveClient( ADR( SELF )); // abundant
      DISPOSE( Adviser );

      Host^.StopPhaseWithResult( NOT Failure1 AND NOT Failure2 );
      Failure1 := FALSE;
      Failure2 := FALSE;

      (*==========*)

      Host^.StartPhase( L"Repeated registration" );
      
      NEW( Adviser );
      Adviser^.JoinClient( ADR( SELF ), io.advWithData );
      Adviser^.LeaveClient( ADR( SELF ));
      Adviser^.JoinClient( ADR( SELF ), io.advWithData );
      Adviser^.LeaveClient( ADR( SELF ));
      Adviser^.JoinClient( ADR( SELF ), io.advWithData );
      Adviser^.LeaveClient( ADR( SELF ));
      Adviser^.JoinClient( ADR( SELF ), io.advWithData );
      Adviser^.LeaveClient( ADR( SELF ));
      Adviser^.JoinClient( ADR( SELF ), io.advWithData );
      Adviser^.LeaveClient( ADR( SELF ));
      
      Failure1 := NOT Adviser^.Empty;
      DISPOSE( Adviser );

      Host^.StopPhaseWithResult( NOT Failure1 );
      Failure1 := FALSE;

      (*==========*)

      Host^.StartPhase( L"Register more clients" );
      
      NEW( c1 );
      NEW( c2 );
      NEW( c3 );
      NEW( c4 );
      NEW( c5 );
      NEW( Adviser );
      Adviser^.JoinClient( c1, io.advWithData );
      Adviser^.JoinClient( c2, io.advWithData );
      Adviser^.JoinClient( c3, io.advWithData );
      Adviser^.JoinClient( c4, io.advWithData );
      Adviser^.JoinClient( c5, io.advWithData );
      Adviser^.LeaveClient( c3 );
      Adviser^.LeaveClient( c1 );
      Adviser^.LeaveClient( c5 );
      Adviser^.LeaveClient( c4 );
      Adviser^.LeaveClient( c2 );

      Failure1 := NOT Adviser^.Empty;
      DISPOSE( c1 );
      DISPOSE( c2 );
      DISPOSE( c3 );
      DISPOSE( c4 );
      DISPOSE( c5 );
      DISPOSE( Adviser );

      Host^.StopPhaseWithResult( NOT Failure1 );

      (*==========*)

      Host^.StartPhase( L"Two clients, advise all, no unadvise" );
      
      NEW( Adviser );
      Adviser^.Device := ADR( Simulator );

      NEW( c1 );
      NEW( c2 );
      c1^.Test := ADR( SELF );
      c2^.Test := ADR( SELF );

      Adviser^.JoinClient( c1, io.advWithData );
      Adviser^.JoinClient( c2, io.advWithData );
      Adviser^.AdviseAll( c1 );
      Adviser^.AdviseAll( c2 );
      
      Count := 0;
      Adviser^.Start();
      Simulator.Simulate();
      
      Adviser^.LeaveClient( c1 );
      Adviser^.LeaveClient( c2 );

      DISPOSE( c1 );
      DISPOSE( c2 );
      DISPOSE( Adviser );
      
      Failure1 := Count <> 10;

      Host^.StopPhaseWithResult( NOT Failure1 AND NOT Failure2 );
      Failure1 := FALSE;
      Failure2 := FALSE;

      (*==========*)

      Host^.StartPhase( L"Two clients, advise all, unadvise all" );
      
      NEW( Adviser );
      Adviser^.Device := ADR( Simulator );

      NEW( c1 );
      NEW( c2 );
      c1^.Test := ADR( SELF );
      c2^.Test := ADR( SELF );

      Adviser^.JoinClient( c1, io.advWithData );
      Adviser^.JoinClient( c2, io.advWithData );
      Adviser^.AdviseAll( c1 );
      Adviser^.AdviseAll( c2 );
      
      Count := 0;
      Adviser^.Start();
      Simulator.Simulate();

      Adviser^.UnadviseAll( c1 );
      Adviser^.UnadviseAll( c2 );
      
      Adviser^.LeaveClient( c1 );
      Adviser^.LeaveClient( c2 );

      DISPOSE( c1 );
      DISPOSE( c2 );
      DISPOSE( Adviser );
      
      Failure1 := Count <> 10;

      Host^.StopPhaseWithResult( NOT Failure1 AND NOT Failure2 );
      Failure1 := FALSE;
      Failure2 := FALSE;

      (*==========*)

      Host^.StartPhase( L"Two clients, advise some, no unadvise" );
      
      NEW( Adviser );
      Adviser^.Device := ADR( Simulator );

      NEW( c1 );
      NEW( c2 );
      c1^.Test := ADR( SELF );
      c2^.Test := ADR( SELF );

      Adviser^.JoinClient( c1, io.advWithData );
      Adviser^.JoinClient( c2, io.advWithData );

      s.FromOA( L"N1" ); Adviser^.Advise( c1, s );
      s.FromOA( L"N2" ); Adviser^.Advise( c1, s ); // 2x
      s.FromOA( L"N5" ); Adviser^.Advise( c1, s );

      s.FromOA( L"N1000" ); Adviser^.Advise( c2, s );
      s.FromOA( L"N1002" ); Adviser^.Advise( c2, s ); // 1x
      s.FromOA( L"N1005" ); Adviser^.Advise( c2, s );

      Count := 0;
      Adviser^.Start();
      Simulator.Simulate();
      
      Adviser^.LeaveClient( c1 );
      Adviser^.LeaveClient( c2 );

      DISPOSE( c1 );
      DISPOSE( c2 );
      DISPOSE( Adviser );
      
      Failure1 := Count <> 3;

      Host^.StopPhaseWithResult( NOT Failure1 OR NOT Failure2 );
      Failure1 := FALSE;
      Failure2 := FALSE;

      (*==========*)

      Host^.StartPhase( L"Two clients, advise some, unadvise some" );
      
      NEW( Adviser );
      Adviser^.Device := ADR( Simulator );

      NEW( c1 );
      NEW( c2 );
      c1^.Test := ADR( SELF );
      c2^.Test := ADR( SELF );

      Adviser^.JoinClient( c1, io.advWithData );
      Adviser^.JoinClient( c2, io.advWithData );

      s.FromOA( L"N1" ); Adviser^.Advise( c1, s );
      s.FromOA( L"N4" ); Adviser^.Advise( c1, s );
      s.FromOA( L"N4" ); Adviser^.Advise( c1, s );
      s.FromOA( L"N5" ); Adviser^.Advise( c1, s );

      s.FromOA( L"N1000" ); Adviser^.Advise( c2, s );
      s.FromOA( L"N1000" ); Adviser^.Advise( c2, s );
      s.FromOA( L"N1001" ); Adviser^.Advise( c2, s ); // 1x
      s.FromOA( L"N1005" ); Adviser^.Advise( c2, s );

      Count := 0;
      Adviser^.Start();
      Simulator.Simulate();
      
      s.FromOA( L"N1" ); Adviser^.Unadvise( c1, s );
      s.FromOA( L"N1" ); Adviser^.Unadvise( c1, s );
      s.FromOA( L"N4" ); Adviser^.Unadvise( c1, s );
      s.FromOA( L"N5" ); Adviser^.Unadvise( c1, s );

      s.FromOA( L"N1000" ); Adviser^.Unadvise( c2, s );
      s.FromOA( L"N1001" ); Adviser^.Unadvise( c2, s );
      s.FromOA( L"N1001" ); Adviser^.Unadvise( c2, s );
      s.FromOA( L"N1005" ); Adviser^.Unadvise( c2, s );

      Adviser^.LeaveClient( c1 );
      Adviser^.LeaveClient( c2 );

      DISPOSE( c1 );
      DISPOSE( c2 );
      DISPOSE( Adviser );
      
      Failure1 := Count <> 1;

      Host^.StopPhaseWithResult( NOT Failure1 AND NOT Failure2 );
      Failure1 := FALSE;
      Failure2 := FALSE;

      (*==========*)

      IF Failure1 OR Failure2 THEN
         RETURN test.trFailure;
      ELSE
         RETURN test.trSuccess;
      END;
   END Run;
   
(*---------------------------------------------------------------------------*)

   PUBLIC VIRTUAL PROCEDURE OnAdvise( Source : io.TPIO; CONST Result : ARRAY OF sync.TAsyncResult; CONST Item : ARRAY OF ns.THash; CONST Value : ARRAY OF iovalue.Value );
   BEGIN
      INC( Count );
   END OnAdvise;

(*---------------------------------------------------------------------------*)

BEGIN
   testimpl.tests()^.AddTest( L"Adviser", ADR( Test ));
END CTest;

(*===========================================================================*)

END TAdviser.