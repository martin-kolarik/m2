IMPLEMENTATION MODULE EquithermicCurve;

(*================================================================================*)

FROM Debug IMPORT
   Assertion, LogAssertionW;

IMPORT
   io,
   INIFile,
   StringsO,
   Texts;

(*================================================================================*)

CLASS CCurve;
   LOCAL VAR
      Slope : LONGREAL := 0.0;
      Offset : LONGREAL := 0.0;
      HInnerSetpointTemperature : ns.THash := NIL;
      HOuterActualTemperature : ns.THash := NIL;
      HOutputTemperature : ns.THash := NIL;
END CCurve;      

(*--------------------------------------------------------------------------------*)

CLASS IMPLEMENTATION CCurve;
BEGIN
END CCurve;

(*================================================================================*)

CONST
   LOGNAME = L"Equithermic";
   CFG_SECTION = L"equithermic_curve";
   DEFAULT_SLOPE = 1.3;
   DEFAULT_OFFSET = 0.0;

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
               IF ( curve^.HInnerSetpointTemperature = Item[i] ) OR ( curve^.HOuterActualTemperature = Item[i] ) THEN
                  Compute( curve );
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
      iniFile : INIFile.TPINIFile;
      Line : CARDINAL;
      key : ARRAY [0..255] OF WCHAR;
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

      IF Device <> NIL THEN
	      Log^.LogS( log.dlcError, LOGNAME, OAsz( R[ Texts._DeviceIsNotInitialized ] ));
         RETURN Sync.arCannotStart;
      
      ELSIF HIGH( Source ) < 0 THEN
	      Log^.LogS( log.dlcError, LOGNAME, OAsz( R[ Texts._BadParameterMissingSourceOfConfiguration ] ));
         RETURN Sync.arCannotStart;

      ELSIF Source[0].Type = device.citINIFile THEN
         iniFile := Source[0].iniFile;
         section.FromOA( CFG_SECTION ); // load default section

      ELSIF Source[0].Type = device.citINIFileSection THEN
         iniFile := Source[0].iniFile;
         section.Assign( Source[0].section^ ); // load ordered section

      ELSE
	      Log^.LogS( log.dlcError, LOGNAME, OAsz( R[ Texts._UnsupportedSourceOfConfiguration ] ));
         RETURN Sync.arCannotStart;
      END;
      
      IF NOT iniFile^.SetSection( OA( section.Length-1, section.rawData )) THEN
	      Log^.LogS( log.dlcInfo, LOGNAME, OAsz( R[ Texts._ConfigurationSectionNotFound ] ));
         RETURN Sync.arCompleted;
      END;
      // here the inifile has proper section set
      
      ES := 0;
      WHILE iniFile^.EnumerateKeys( REF ES, OUT Line, OUT key, OUT value ) DO
         // key/output = wish/input, outer/input [, slope/parameter [, offset/parameter]]
         s.FromOA( key );
         IF NOT Device^.NS()^.NameToHash( s, OUT hash[0] ) THEN
	         Log^.LogSS( log.dlcError, LOGNAME, OAsz( R[ Texts._OutputGroupAddressNotFound ] ), OA( s.Length-1, s.rawData ));
            CONTINUE;
         END;
         
         value.SplitS( StringsO.WCHARS{L","}, 0, FALSE, OUT pieces, OUT values );
         // check mandatory parameters (wish, outer)
         IF pieces < 2 THEN
	         Log^.LogS( log.dlcError, LOGNAME, OAsz( R[ Texts._InputValuesAreMissing ] ));
            CONTINUE;
         ELSIF NOT Device^.NS()^.NameToHash( values[0], OUT hash[1] ) THEN
	         Log^.LogSS( log.dlcError, LOGNAME, OAsz( R[ Texts._SetpointGroupAddressNotFound ] ), OA( values[0].Length-1, values[0].rawData ));
            CONTINUE;
         ELSIF NOT Device^.NS()^.NameToHash( values[1], OUT hash[2] ) THEN
	         Log^.LogSS( log.dlcError, LOGNAME, OAsz( R[ Texts._OuterGroupAddressNotFound ] ), OA( values[1].Length-1, values[1].rawData ));
            CONTINUE;
         END;
         
         // read optional parameters (slope, offset)
         slope := DEFAULT_SLOPE;
         IF ( pieces > 2 ) AND NOT values[2].ToLONGREAL( OUT slope ) THEN
	         Log^.LogSS( log.dlcError, LOGNAME, OAsz( R[ Texts._SlopeIsNotANumber ] ), OA( values[2].Length-1, values[2].rawData ));
            CONTINUE;
         END;
         offset := DEFAULT_OFFSET;
         IF ( pieces > 3 ) AND NOT s.ToLONGREAL( OUT offset ) THEN
	         Log^.LogSS( log.dlcError, LOGNAME, OAsz( R[ Texts._OffsetIsNotANumber ] ), OA( values[3].Length-1, values[3].rawData ));
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

   PRIVATE PROCEDURE Compute( curve : TPCurve );
   VAR 
   BEGIN
      
   END Compute;

(*--------------------------------------------------------------------------------*)

BEGIN FINALLY
   Dispose();
END CEquithermicCurveFunction;

(*================================================================================*)

END EquithermicCurve.