IMPLEMENTATION MODULE EquithermicCurve;

(*================================================================================*)

FROM Debug IMPORT
   Assertion, LogAssertionW;

IMPORT
  Storage,
  Strings;

(*================================================================================*)

TYPE
   TPCurve = POINTER TO CCurve;

CLASS CCurve;
   LOCAL VAR
      HInnerSetpointTemperature : ns.THash := NIL;
      HOuterActualTemperature : ns.THash := NIL;
      HOutputTemperature : ns.THash := NIL;
END CCurve;      

(*--------------------------------------------------------------------------------*)

CLASS IMPLEMENTATION CCurve;
BEGIN
END CCurve;

(*================================================================================*)

CLASS IMPLEMENTATION CEquithermicCurveFunction;

(*--------------------------------------------------------------------------------*)

   PUBLIC VIRTUAL PROPERTY Running GET : BOOLEAN;
   BEGIN
      RETURN _Running;
   END Running;

(*--------------------------------------------------------------------------------*)

   PUBLIC VIRTUAL PROCEDURE Start() : Sync.TAsyncResult;
   VAR
      curve : TPCurve;
   BEGIN
      IF _Running THEN
         RETURN Sync.arAlreadyCompleted;
      ELSIF _Device = NIL THEN
         RETURN Sync.arCannotStart;
      END;
      _Running := TRUE;
      
      _Curves.Reset();
      WHILE _Curves.MoveNext() DO
         curve := _Curves.Current;
         _Device^.AdviseHash( ADR( SELF ), curve^.HInnerSetpointTemperature );
         _Device^.AdviseHash( ADR( SELF ), curve^.HOuterActualTemperature );
      END; // WHILE
      
      RETURN _Sync.arCompleted;
   END Start;

(*--------------------------------------------------------------------------------*)

   PUBLIC VIRTUAL PROCEDURE Stop() : Sync.TAsyncResult;
   BEGIN
      IF NOT _Running THEN
         RETURN Sync.arCompleted;
      ELSIF _Device = NIL THEN
         RETURN Sync.arCompleted;
      END;
      _Running := FALSE;
      
      _Device^.UnadviseAll( ADR( SELF ));

      RETURN _Sync.arCompleted;
   END Stop;
   
(*--------------------------------------------------------------------------------*)

   PUBLIC VIRTUAL PROCEDURE OnAdvise( Source : io.TPIO; CONST Result : ARRAY OF Sync.TAsyncResult; CONST Item : ARRAY OF ns.THash; CONST Value : ARRAY OF iovalue.Value );

(*--------------------------------------------------------------------------------*)

   PUBLIC PROPERTY Device : adviser.TPAdvisedDevice;

(*--------------------------------------------------------------------------------*)

   PUBLIC PROPERTY Logger : log.TPILogger;
      
(*--------------------------------------------------------------------------------*)

   PUBLIC PROCEDURE Configure( CONST Source : ARRAY OF device.TConfigureItem; CONST Log : log.TPLogger ) : Sync.TAsyncResult;
   
(*--------------------------------------------------------------------------------*)

   PUBLIC VIRTUAL PROCEDURE Dispose();
   VAR
      curve : TPCurve;
   BEGIN
      IF _Device <> NIL THEN
         _Device^.UnadviseAll( ADR( SELF ));
         _Device := NIL;
      END;
   
      _Curves.Reset();
      WHILE _Curves.MoveNext() DO
         curve := _Curves.Current;
         DISPOSE( curve );
      END; // WHILE
      _Curves.DisposeList;
   END Dispose;

(*--------------------------------------------------------------------------------*)

BEGIN FINALLY
   Dispose();
END CEquithermicCurveFunction;

(*================================================================================*)

END eib_def.