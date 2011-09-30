IMPLEMENTATION MODULE EquithermicCurve;

(*================================================================================*)

FROM Debug IMPORT
   AssertionW;

IMPORT
   io,
   IOO,
   iovalue,
   INIFile,
   Mathematics,
   StringsO,
   Texts;

(*================================================================================*)

CLASS CCurve;

   LOCAL PROCEDURE Enqueue() : BOOLEAN; // returns FALSE if the object is already in the queue
   LOCAL PROCEDURE Dequeue();

   LOCAL VAR
      Slope : LONGREAL := 0.0;
      Offset : LONGREAL := 0.0;
      HInnerSetpointTemperature : ns.THash := NIL;
      HaveInnerSetpointTemperature : BOOLEAN := FALSE;
      HOuterActualTemperature : ns.THash := NIL;
      HaveOuterActualTemperature : BOOLEAN := FALSE;
      HOutputTemperature : ns.THash := NIL;

   PRIVATE VAR
      _Signal : Sync.SIGNAL;

END CCurve;

(*--------------------------------------------------------------------------------*)

CLASS IMPLEMENTATION CCurve;

(*--------------------------------------------------------------------------------*)

   LOCAL PROCEDURE Enqueue() : BOOLEAN;
   BEGIN
      RETURN _Signal.Signal();
   END Enqueue;

(*--------------------------------------------------------------------------------*)

   LOCAL PROCEDURE Dequeue();
   BEGIN
      _Signal.Reset();
   END Dequeue;

(*--------------------------------------------------------------------------------*)

BEGIN
   _Signal.Init( Sync.stSpin, L"", FALSE );
END CCurve;

(*================================================================================*)

CONST
   LOGNAME = L"Equithermic";
   CFG_SECTION = L"equithermic_curve";
   DEFAULT_SLOPE = 1.3;
   DEFAULT_OFFSET = 0.0;
   MSG_SEND = msghandler.MSG_BASE;

CLASS IMPLEMENTATION CEquithermicCurveFunction;

(*--------------------------------------------------------------------------------*)

   INTERNAL VIRTUAL PROCEDURE OnMessage( CONST Message : msghandler.IMessage; OUT Result : PTR ) : BOOLEAN;
   VAR
      curve : TPCurve;
   BEGIN
      IF SUPER.OnMessage( Message, OUT Result ) THEN
         RETURN TRUE;

      ELSIF Message.Message = MSG_SEND THEN
         WHILE _SendQueue.Dequeue( OUT curve  ) DO
            curve^.Dequeue();
            Compute( curve );
         END; // _SendQueue

         RETURN TRUE;
      
      ELSE
         RETURN FALSE;
      END;
   END OnMessage;

(*--------------------------------------------------------------------------------*)

   PUBLIC VIRTUAL PROPERTY Description GET : StringsO.CString;
   BEGIN
      RETURN _Description;
   END Description;

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

      _Device^.JoinClient( ADR( SELF ), io.advWithData );
      
      _Curves.Reset();
      WHILE _Curves.MoveNext() DO
         curve := _Curves.Current;
         _Device^.AdviseHash( ADR( SELF ), curve^.HInnerSetpointTemperature );
         _Device^.AdviseHash( ADR( SELF ), curve^.HOuterActualTemperature );
      END; // WHILE
      
      RETURN Sync.arCompleted;
   END Start;

(*--------------------------------------------------------------------------------*)

   PUBLIC VIRTUAL PROCEDURE Stop();
   BEGIN
      IF NOT _Running THEN
         RETURN;
      ELSIF _Device = NIL THEN
         RETURN;
      END;
      _Running := FALSE;
      _Device^.UnadviseAll( ADR( SELF ));
      _Device^.LeaveClient( ADR( SELF ));
   END Stop;
   
(*--------------------------------------------------------------------------------*)

   PUBLIC VIRTUAL PROCEDURE OnAdvise( Source : io.TPIO; CONST Result : ARRAY OF Sync.TAsyncResult; CONST Item : ARRAY OF ns.THash; CONST Value : ARRAY OF iovalue.Value );
   VAR
      curve : TPCurve;
      i : CARDINAL;
   BEGIN
      // check validity of input
      IF HIGH( Item ) < 0 THEN
         RETURN;
      END;
      
      // look for items and check if operation finished sucessfully
      FOR i := 0 TO HIGH( Item ) DO
         IF Result[i] IN Sync.arsCompletions THEN
            
            _Curves.Reset();
            WHILE _Curves.MoveNext() DO
               curve := _Curves.Current;
               IF curve^.HInnerSetpointTemperature = Item[i] THEN
                  curve^.HaveInnerSetpointTemperature := TRUE;
               ELSIF curve^.HOuterActualTemperature = Item[i] THEN
                  curve^.HaveOuterActualTemperature := TRUE;
               ELSE
                  CONTINUE; // no interesting for me
               END;

               IF curve^.HaveInnerSetpointTemperature AND curve^.HaveOuterActualTemperature THEN
                  Enqueue( curve );
               END;
            END; // WHILE
            
         END;
      END;
   END OnAdvise;

(*--------------------------------------------------------------------------------*)

   PUBLIC PROPERTY Device GET : adviser.TPAdvisedDevice;
   BEGIN
      RETURN _Device;
   END Device;

(*--------------------------------------------------------------------------------*)

   PUBLIC PROPERTY Device SET( Value : adviser.TPAdvisedDevice );
   BEGIN
      Dispose();
      _Device := Value;
   END Device;

(*--------------------------------------------------------------------------------*)

   PUBLIC PROPERTY Logger GET : log.TPILogger;
   BEGIN
      IF _Logger = log.TPILogger( log.logger()) THEN
         RETURN NIL;
      ELSE
         RETURN _Logger;
      END;
   END Logger;
      
(*--------------------------------------------------------------------------------*)

   PUBLIC PROPERTY Logger SET( Value : log.TPILogger );
   BEGIN
      IF Value = NIL THEN
         _Logger := log.logger();
      ELSE
         _Logger := Value;
      END;
   END Logger;
      
(*--------------------------------------------------------------------------------*)

   PUBLIC PROCEDURE Configure( CONST Source : ARRAY OF device.TConfigureItem; CONST Log : log.TPLogger ) : Sync.TAsyncResult;
   VAR
      curve : TPCurve;
      ES : PTR;
      hash : ARRAY [0..2] OF ns.THash;
      i : CARDINAL;
      iniFile : INIFile.TPINIFile;
      Line : CARDINAL;
      key : StringsO.CString;
      offset : LONGREAL;
      pieces : CARDINAL;
      s : StringsO.CString;
      section : StringsO.CString;
      slope : LONGREAL;
      value : StringsO.CString;
      values : ARRAY [0..3] OF StringsO.CString;
   BEGIN
	   IF NOT R.LoadRES2( EMITW( %dll ), L"functions.Texts" ) THEN
	      R.LoadRES2( L"", L"functions.Texts" );
      END;

      IF Device = NIL THEN
	      Log^.LogS( log.lcError, 0, LOGNAME, OAsz( R[ Texts._DeviceIsNotInitialized ] ));
         RETURN Sync.arCannotStart;
      
      ELSIF HIGH( Source ) < 0 THEN
	      Log^.LogS( log.lcError, 0, LOGNAME, OAsz( R[ Texts._BadParameterMissingSourceOfConfiguration ] ));
         RETURN Sync.arCannotStart;

      ELSIF Source[0].Type = device.citINIFile THEN
         iniFile := Source[0].iniFile;
         section.FromOA( CFG_SECTION ); // load default section

      ELSIF Source[0].Type = device.citINIFileSection THEN
         iniFile := Source[0].iniFile;
         section.Assign( Source[0].section^ ); // load ordered section

      ELSE
	      Log^.LogS( log.lcError, 0, LOGNAME, OAsz( R[ Texts._UnsupportedSourceOfConfiguration ] ));
         RETURN Sync.arCannotStart;
      END;
      
      IF NOT iniFile^.SetSection( OA( section.Length-1, section.Data )) THEN
	      Log^.LogSS( log.lcInfo, 0, LOGNAME, OAsz( R[ Texts._ConfigurationSectionNotFound ] ), OA( section.Length-1, section.Data ));
         RETURN Sync.arCompleted;
      END;
      // here the inifile has proper section set
      
      ES := 0;
      WHILE iniFile^.EnumerateKeys( REF ES, OUT Line, OUT key, OUT value ) DO
         // key/output = wish/input, outer/input [, slope/parameter [, offset/parameter]]
         IF NOT Device^.Mapper()^.NameToHash( key, OUT hash[0] ) THEN
	         Log^.LogSS( log.lcError, 0, LOGNAME, OAsz( R[ Texts._OutputGroupAddressNotFound ] ), OA( s.Length-1, s.Data ));
            CONTINUE;
         END;
         
         value.SplitS( StringsO.WCHARS{L","}, 0, FALSE, OUT pieces, OUT values );
         FOR i := 0 TO HIGH( values ) DO
            values[i].Trim();
         END;
         
         // check mandatory parameters (wish, outer)
         IF pieces < 2 THEN
	         Log^.LogS( log.lcError, 0, LOGNAME, OAsz( R[ Texts._InputValuesAreMissing ] ));
            CONTINUE;
         ELSIF NOT Device^.Mapper()^.NameToHash( values[0], OUT hash[1] ) THEN
	         Log^.LogSS( log.lcError, 0, LOGNAME, OAsz( R[ Texts._SetpointGroupAddressNotFound ] ), OA( values[0].Length-1, values[0].Data ));
            CONTINUE;
         ELSIF NOT Device^.Mapper()^.NameToHash( values[1], OUT hash[2] ) THEN
	         Log^.LogSS( log.lcError, 0, LOGNAME, OAsz( R[ Texts._OuterGroupAddressNotFound ] ), OA( values[1].Length-1, values[1].Data ));
            CONTINUE;
         END;
         
         // read optional parameters (slope, offset)
         slope := DEFAULT_SLOPE;
         IF pieces > 2 THEN
            IF NOT values[2].ToLONGREAL( OUT slope ) THEN
	            Log^.LogSS( log.lcError, 0, LOGNAME, OAsz( R[ Texts._SlopeIsNotANumber ] ), OA( values[2].Length-1, values[2].Data ));
               CONTINUE;
            ELSIF ( slope < 0.2 ) OR ( slope > 3.5 ) THEN
	            Log^.LogS( log.lcError, 0, LOGNAME, OAsz( R[ Texts._SlopeOutOfRange ] ));
               CONTINUE;
            END;
         END;
         offset := DEFAULT_OFFSET;
         IF ( pieces > 3 ) AND NOT values[3].ToLONGREAL( OUT offset ) THEN
	         Log^.LogSS( log.lcError, 0, LOGNAME, OAsz( R[ Texts._OffsetIsNotANumber ] ), OA( values[3].Length-1, values[3].Data ));
            CONTINUE;
         END;
         
         // everything OK, create item in _Curves
         NEW( curve );
         curve^.Slope := slope;
         curve^.Offset := offset;
         curve^.HOutputTemperature := hash[0];
         curve^.HInnerSetpointTemperature := hash[1];
         curve^.HOuterActualTemperature := hash[2];
         _Curves.Add( curve, 0 );
      END; // WHILE
      
      RETURN Sync.arCompleted;
   END Configure; 
   
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
      _Curves.Dispose();
   END Dispose;

(*--------------------------------------------------------------------------------*)

   PRIVATE PROCEDURE Enqueue( curve : TPCurve );
   BEGIN
      IF curve^.Enqueue() THEN // smart queueuing, the item has just put to the queue
         _SendQueue.Enqueue( curve );
      END;
   END Enqueue;

(*--------------------------------------------------------------------------------*)

   PRIVATE PROCEDURE Compute( curve : TPCurve );
   VAR
      outer : iovalue.Value;
      output : LONGREAL;
      result : Sync.TAsyncResult;
      value : iovalue.Value;
   BEGIN
      WITH curve^ DO

         // read inputs
         result := _Device^.IO()^.IOh( ADR( SELF ), IOO.dirRead, HInnerSetpointTemperature, REF value, NIL );
         IF result NOT IN Sync.arsCompletions THEN
            ASSERTLOG( FALSE, L"Unable to read setpoint temperature value" );
            RETURN;
         END;
         result := _Device^.IO()^.IOh( ADR( SELF ), IOO.dirRead, HOuterActualTemperature, REF outer, NIL );
         IF result NOT IN Sync.arsCompletions THEN
            ASSERTLOG( FALSE, L"Unable to read outer actual temperature value" );
            RETURN;
         END;

         // compute
         output := value.Float + Offset;
         IF value >= outer THEN
            output := output + 2.0 * Slope * Mathematics.Power( output - outer.Float, 0.8 );
         END;
         value.Float := output;

         // write output

         result := _Device^.IO()^.IOh( ADR( SELF ), IOO.dirWrite, HOutputTemperature, REF value, NIL );
         IF result NOT IN Sync.arsCompletions THEN
            ASSERTLOG( FALSE, L"Unable to write output temperature" );
            RETURN;
         END;

      END; // WITH
   END Compute;

(*--------------------------------------------------------------------------------*)

   INITIALLY CEquithermicCurveFunction();
   VAR
      msg : msghandler.Message;
   BEGIN
      _Description.FromOA( L"Equithermic Curve" );
      
      msg.Message := MSG_SEND;
      _SendQueue.ConsumerMsg := ADR( msg );
      _SendQueue.Consumer := ADR( SELF );
   END CEquithermicCurveFunction;

(*--------------------------------------------------------------------------------*)

   FINALLY CEquithermicCurveFunction();
   BEGIN
      Dispose();
   END CEquithermicCurveFunction;

(*--------------------------------------------------------------------------------*)

END CEquithermicCurveFunction;

(*================================================================================*)

END EquithermicCurve.