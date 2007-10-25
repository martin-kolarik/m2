IMPLEMENTATION MODULE sdvalue;

FROM Storage IMPORT
   ALLOCATE, DEALLOCATE;

IMPORT
   Strings;

(*================================================================================*)

TYPE
   #save, option( pack => 1 )
   TStorage  = RECORD
                  CASE : TSDValueType OF
                  | sdtUnknown  :
                  | sdtVoid     :
                  | sdtObject   : Object   : ADDRESS;
                  | sdtBoolean  : Boolean  : BOOLEAN;
                  | sdtTristate : Tristate : TRISTATE;
                  | sdtInteger  : Integer  : INT32;
                  | sdtLong     : Long     : INT64;
                  | sdtFloat    : Float    : LONGREAL;
                  | sdtString   : String   : POINTER TO StringsO.CString;
                  | sdtDate     : Date     : time.TJD;
                  END;
               END; // RECORD
   TPStorage = POINTER TO TStorage;
   #restore
   
CONST
   defaultTrue = L"true";
   defaultFalse = L"false";
   defaultTransportTrue = L"T";
   defaultTransportFalse = L"F";
   defaultDate = time.TJD( 2118134448000000 ); // 1.1.2000
   defaultDateTimeFormat = L"dd.MM.yyyy HH.mm.ss.fff";

(*================================================================================*)

CLASS IMPLEMENTATION Value;

(*--------------------------------------------------------------------------------*)

   PUBLIC PROPERTY Type GET : TSDValueType;
   BEGIN
      RETURN _Type;
   END Type;

(*--------------------------------------------------------------------------------*)

   PUBLIC PROPERTY Type SET( value : TSDValueType );
   VAR
      LFlags : TFlags;
      LValue : Value;
   BEGIN
      IF _Type <> value THEN
         LFlags := _Flags;

         IF ( value <> sdtUnknown ) AND ( value <> sdtVoid ) THEN
            // convert
            LValue._Type := value;
            LValue := SELF;
         END;

         // adopt new data
         Dispose();
         _Flags := LFlags;
         _Type := value;
         _Storage := LValue._Storage;

         // forget old
         LValue._Type := sdtUnknown;
         LValue._Storage := 0;
      END;
   END Type;

(*--------------------------------------------------------------------------------*)

   PUBLIC PROPERTY Undefined GET : BOOLEAN;
   BEGIN
      RETURN vfUndefined IN _Flags;
   END Undefined;

(*--------------------------------------------------------------------------------*)

   PUBLIC PROPERTY Undefined SET( Value : BOOLEAN );
   BEGIN
      IF Value THEN
         INCL( _Flags, vfUndefined );
         IF _Type = sdtString THEN
            TPStorage( ADR( _Storage ))^.String^.Clear();
         ELSE
            _Storage := 0;
         END;
      ELSE
         EXCL( _Flags, vfUndefined );
      END;
   END Undefined;

(*--------------------------------------------------------------------------------*)

   PUBLIC PROPERTY Saturate GET : BOOLEAN;
   BEGIN
      RETURN vfSaturate IN _Flags;
   END Saturate;

(*--------------------------------------------------------------------------------*)

   PUBLIC PROPERTY Saturate SET( Value : BOOLEAN );
   BEGIN
      IF Value THEN
         INCL( _Flags, vfSaturate );
      ELSE
         EXCL( _Flags, vfSaturate );
      END;
   END Saturate;

(*--------------------------------------------------------------------------------*)

   PUBLIC PROPERTY Boolean GET : BOOLEAN;
   VAR
      PS : StringsO.TPString;
      today, tomorrow : time.TJD;
   BEGIN
      IF vfUndefined IN _Flags THEN
         RETURN FALSE;
      END;
      CASE _Type OF
      | sdtUnknown :
      | sdtVoid :
      | sdtObject :
         ASSERT( FALSE );

      | sdtBoolean :
         RETURN TPStorage( ADR( _Storage ))^.Boolean;

      | sdtTristate :
         RETURN TPStorage( ADR( _Storage ))^.Tristate = 1;

      | sdtInteger :
         RETURN TPStorage( ADR( _Storage ))^.Integer <> 0;

      | sdtLong :
         RETURN TPStorage( ADR( _Storage ))^.Long <> 0;

      | sdtFloat :
         RETURN TPStorage( ADR( _Storage ))^.Float <> 0.0;

      | sdtString :
         PS := TPStorage( ADR( _Storage ))^.String;
         RETURN PS^.EqualsOA( L"TRUE" ) OR PS^.EqualsOA( defaultTrue ) OR PS^.EqualsOA( L"T" ) OR PS^.EqualsOA( L"1" );

      | sdtDate :
         today := time.TrimFD( time.GetCurrentJD());
         tomorrow := today + time.DaysToJDC( 1 );
         RETURN ( TPStorage( ADR( _Storage ))^.Date >= today ) AND ( TPStorage( ADR( _Storage ))^.Date < tomorrow );

      ELSE
         ASSERT( FALSE );
      END; // CASE
      RETURN FALSE;
   END Boolean;

(*--------------------------------------------------------------------------------*)

   PUBLIC PROPERTY Tristate GET : TRISTATE;
   VAR
      PS : StringsO.TPString;
      today, tomorrow : time.TJD;
   BEGIN
      IF vfUndefined IN _Flags THEN
         RETURN -1;
      END;
      CASE _Type OF
      | sdtUnknown :
      | sdtVoid :
      | sdtObject :
         ASSERT( FALSE );

      | sdtBoolean :
         IF TPStorage( ADR( _Storage ))^.Boolean THEN
            RETURN 1;
         ELSE
            RETURN 0;
         END;

      | sdtTristate :
         RETURN TPStorage( ADR( _Storage ))^.Tristate;

      | sdtInteger :
         IF TPStorage( ADR( _Storage ))^.Integer >= 1 THEN
            RETURN 1;
         ELSIF TPStorage( ADR( _Storage ))^.Integer <= -1 THEN
            RETURN -1;
         ELSE
            RETURN 0;
         END;
            
      | sdtLong :
         IF TPStorage( ADR( _Storage ))^.Long >= 1 THEN
            RETURN 1;
         ELSIF TPStorage( ADR( _Storage ))^.Long <= INT64( -1 ) THEN
            RETURN -1;
         ELSE
            RETURN 0;
         END;

      | sdtFloat :
         IF TPStorage( ADR( _Storage ))^.Float >= 1.0 THEN
            RETURN 1;
         ELSIF TPStorage( ADR( _Storage ))^.Float <= -1.0 THEN
            RETURN -1;
         ELSE
            RETURN 0;
         END;

      | sdtString :
         PS := TPStorage( ADR( _Storage ))^.String;
         IF PS^.EqualsOA( L"TRUE" ) OR PS^.EqualsOA( defaultTrue ) OR PS^.EqualsOA( L"T" ) OR PS^.EqualsOA( L"1" ) THEN
            RETURN 1;
         ELSIF PS^.EqualsOA( L"FALSE" ) OR PS^.EqualsOA( defaultFalse ) OR PS^.EqualsOA( L"F" ) OR PS^.EqualsOA( L"0" ) THEN
            RETURN 0;
         ELSE
            RETURN -1;
         END;

      | sdtDate :
         today := time.TrimFD( time.GetCurrentJD());
         tomorrow := today + time.DaysToJDC( 1 );
         IF ( TPStorage( ADR( _Storage ))^.Date >= today ) AND ( TPStorage( ADR( _Storage ))^.Date < tomorrow ) THEN
            RETURN 1;
         ELSE
            RETURN 0;
         END;

      ELSE
         ASSERT( FALSE );
      END; // CASE
      RETURN -1;
   END Tristate;

(*--------------------------------------------------------------------------------*)

   PUBLIC PROPERTY Integer GET : INT32;
   BEGIN
      IF vfUndefined IN _Flags THEN
         RETURN 0;
      END;
      CASE _Type OF
      | sdtUnknown :
      | sdtVoid :
      | sdtObject :
         ASSERT( FALSE );

      | sdtBoolean :
         IF TPStorage( ADR( _Storage ))^.Boolean THEN
            RETURN 1;
         ELSE
            RETURN 0;
         END;

      | sdtTristate :
         RETURN INT32( TPStorage( ADR( _Storage ))^.Tristate );

      | sdtInteger :
         RETURN TPStorage( ADR( _Storage ))^.Integer;

      | sdtLong :
         IF vfSaturate NOT IN _Flags THEN
            RETURN INTEGER( TPStorage( ADR( _Storage ))^.Long );
         ELSIF TPStorage( ADR( _Storage ))^.Long > MAX( INT32 ) THEN
            RETURN MAX( INT32 );
         ELSIF TPStorage( ADR( _Storage ))^.Long < MIN( INT32 ) THEN
            RETURN MIN( INT32 );
         ELSE
            RETURN INTEGER( TPStorage( ADR( _Storage ))^.Long );
         END;

      | sdtFloat :
         IF vfSaturate NOT IN _Flags THEN
            RETURN INTEGER( TPStorage( ADR( _Storage ))^.Float );
         ELSIF TPStorage( ADR( _Storage ))^.Float > LONGREAL( MAX( INT32 )) THEN
            RETURN MAX( INT32 );
         ELSIF TPStorage( ADR( _Storage ))^.Float < LONGREAL( MIN( INT32 )) THEN
            RETURN MIN( INT32 );
         ELSE
            RETURN INTEGER( TPStorage( ADR( _Storage ))^.Float );
         END;

      | sdtString :
         TRY
            RETURN TPStorage( ADR( _Storage ))^.String^.ToINT32( 10 );
         CATCH e : StringsO.CStringException DO
            RETURN 0;
         END;

      | sdtDate :
         RETURN time.fd( TPStorage( ADR( _Storage ))^.Date ) DIV CARDINAL( time.unitsInMillisecond );

      ELSE
         ASSERT( FALSE );
      END; // CASE
      RETURN 0;
   END Integer;

(*--------------------------------------------------------------------------------*)

   PUBLIC PROPERTY Long GET : INT64;
   BEGIN
      IF vfUndefined IN _Flags THEN
         RETURN 0;
      END;
      CASE _Type OF
      | sdtUnknown :
      | sdtVoid :
      | sdtObject :
         ASSERT( FALSE );

      | sdtBoolean :
         IF TPStorage( ADR( _Storage ))^.Boolean THEN
            RETURN 1;
         ELSE
            RETURN 0;
         END;

      | sdtTristate :
         RETURN INT64( TPStorage( ADR( _Storage ))^.Tristate );

      | sdtInteger :
         RETURN INT64( TPStorage( ADR( _Storage ))^.Integer );

      | sdtLong :
         RETURN TPStorage( ADR( _Storage ))^.Long;

      | sdtFloat :
         RETURN INT64( TPStorage( ADR( _Storage ))^.Float );

      | sdtString :
         TRY
            RETURN TPStorage( ADR( _Storage ))^.String^.ToINT64( 10 );
         CATCH e : StringsO.CStringException DO
            RETURN 0;
         END;

      | sdtDate :
         RETURN TPStorage( ADR( _Storage ))^.Date;

      ELSE
         ASSERT( FALSE );
      END; // CASE
      RETURN 0;
   END Long;

(*--------------------------------------------------------------------------------*)

   PUBLIC PROPERTY Float GET : LONGREAL;
   BEGIN
      IF vfUndefined IN _Flags THEN
         RETURN 0.0;
      END;
      CASE _Type OF
      | sdtUnknown :
      | sdtVoid :
      | sdtObject :
         ASSERT( FALSE );

      | sdtBoolean :
         IF TPStorage( ADR( _Storage ))^.Boolean THEN
            RETURN 1.0;
         ELSE
            RETURN 0.0;
         END;

      | sdtTristate :
         RETURN LONGREAL( TPStorage( ADR( _Storage ))^.Tristate );

      | sdtInteger :
         RETURN LONGREAL( TPStorage( ADR( _Storage ))^.Integer );

      | sdtLong :
         RETURN LONGREAL( TPStorage( ADR( _Storage ))^.Long );

      | sdtFloat :
         RETURN TPStorage( ADR( _Storage ))^.Float;

      | sdtString :
         TRY
            RETURN TPStorage( ADR( _Storage ))^.String^.ToLONGREAL();
         CATCH e : StringsO.CStringException DO
            RETURN 0.0;
         END;

      | sdtDate :
         RETURN time.ToSJD( TPStorage( ADR( _Storage ))^.Date );

      ELSE
         ASSERT( FALSE );
      END; // CASE
      RETURN 0.0;
   END Float;

(*--------------------------------------------------------------------------------*)

   PUBLIC PROPERTY String GET : StringsO.CString;
   VAR
      dt : time.TDateTime;
      s : ARRAY [0..63] OF WCHAR;
      S : StringsO.CString;
   BEGIN
      IF vfUndefined IN _Flags THEN
         RETURN S;
      END;
      CASE _Type OF
      | sdtUnknown :
      | sdtVoid :
      | sdtObject :
         ASSERT( FALSE );

      | sdtBoolean :
         IF TPStorage( ADR( _Storage ))^.Boolean THEN
            S.FromOA( defaultTrue );
         ELSE
            S.FromOA( defaultFalse );
         END;

      | sdtTristate :
         S.FromINT32( INT32( TPStorage( ADR( _Storage ))^.Tristate ), 10 );

      | sdtInteger :
         S.FromINT32( TPStorage( ADR( _Storage ))^.Integer, 10 );

      | sdtLong :
         S.FromINT64( TPStorage( ADR( _Storage ))^.Long, 10 );

      | sdtFloat :
         S.FromLONGREAL( TPStorage( ADR( _Storage ))^.Float, FALSE );

      | sdtString :
         RETURN TPStorage( ADR( _Storage ))^.String^;

      | sdtDate :
         time.JDToZonalDateTime( TPStorage( ADR( _Storage ))^.Date, OUT dt, 0, 0 );
         IF time.DateTimeToString( dt, defaultDateTimeFormat, TRUE, TRUE, s ) THEN
            S.FromOA( s );
         END;

      ELSE
         ASSERT( FALSE ); RETURN S;
      END; // CASE
      
      RETURN S;
   END String;

(*--------------------------------------------------------------------------------*)

   PUBLIC PROPERTY Date GET : time.TJD;
   VAR
      dt : time.TDateTime;
      t : time.TJD := time.GetCurrentJD();
   BEGIN
      IF vfUndefined IN _Flags THEN
         RETURN defaultDate;
      END;
      CASE _Type OF
      | sdtUnknown :
      | sdtVoid :
      | sdtObject :
         ASSERT( FALSE );

      | sdtBoolean :
         IF TPStorage( ADR( _Storage ))^.Boolean THEN
            RETURN t;
         ELSE
            RETURN defaultDate;
         END;

      | sdtTristate :
         IF TPStorage( ADR( _Storage ))^.Tristate = 1 THEN
            RETURN t;
         ELSE
            RETURN defaultDate;
         END;

      | sdtInteger :
         IF TPStorage( ADR( _Storage ))^.Integer < 0 THEN
            RETURN defaultDate;
         ELSE
            RETURN time.TrimFD( t ) + time.TJD( TPStorage( ADR( _Storage ))^.Integer * INTEGER( time.unitsInMillisecond ));
         END;

      | sdtLong :
         RETURN TPStorage( ADR( _Storage ))^.Long;

      | sdtFloat :
         RETURN time.FromSJD( TPStorage( ADR( _Storage ))^.Float );

      | sdtString :
         IF time.StringToDateTime( OA( TPStorage( ADR( _Storage ))^.String^.Length-1, TPStorage( ADR( _Storage ))^.String^.rawData ), defaultDateTimeFormat, dt ) THEN
            time.InitDateTime( OUT dt );
            RETURN time.ZonalDateTimeToJD( dt, 0, 0 );
         ELSE
            RETURN defaultDate;
         END;

      | sdtDate :
         RETURN TPStorage( ADR( _Storage ))^.Date;

      ELSE
         ASSERT( FALSE );
      END; // CASE
      RETURN defaultDate;
   END Date;

(*--------------------------------------------------------------------------------*)

   PUBLIC PROPERTY Boolean SET( value : BOOLEAN );
   BEGIN
      IF _Type = sdtUnknown THEN
         _Type := sdtBoolean;
      END;

      CASE _Type OF
      | sdtVoid :
      | sdtObject :
         ASSERT( FALSE );

      | sdtBoolean :
         TPStorage( ADR( _Storage ))^.Boolean := value;

      | sdtTristate :
         IF value THEN
            TPStorage( ADR( _Storage ))^.Tristate := 1;
         ELSE
            TPStorage( ADR( _Storage ))^.Tristate := 0;
         END;

      | sdtInteger :
         IF value THEN
            TPStorage( ADR( _Storage ))^.Integer := 1;
         ELSE
            TPStorage( ADR( _Storage ))^.Integer := 0;
         END;

      | sdtLong :
         IF value THEN
            TPStorage( ADR( _Storage ))^.Long := 1;
         ELSE
            TPStorage( ADR( _Storage ))^.Long := 0;
         END;

      | sdtFloat :
         IF value THEN
            TPStorage( ADR( _Storage ))^.Float := 1.0;
         ELSE
            TPStorage( ADR( _Storage ))^.Float := 0.0;
         END;

      | sdtString :
         IF value THEN
            TPStorage( ADR( _Storage ))^.String^.FromOA( defaultTrue );
         ELSE
            TPStorage( ADR( _Storage ))^.String^.FromOA( defaultFalse );
         END;

      | sdtDate :
         Undefined := TRUE;

      ELSE
         ASSERT( FALSE );
      END; // CASE
   END Boolean;

(*--------------------------------------------------------------------------------*)

   PUBLIC PROPERTY Tristate SET( value : TRISTATE );
   BEGIN
      IF _Type = sdtUnknown THEN
         _Type := sdtTristate;
      END;

      CASE _Type OF
      | sdtVoid :
      | sdtObject :
         ASSERT( FALSE );

      | sdtBoolean :
         TPStorage( ADR( _Storage ))^.Boolean := value = 1;

      | sdtTristate :
         TPStorage( ADR( _Storage ))^.Tristate := value;

      | sdtInteger :
         TPStorage( ADR( _Storage ))^.Integer := INT32( value );
            
      | sdtLong :
         TPStorage( ADR( _Storage ))^.Long := INT64( value );

      | sdtFloat :
         TPStorage( ADR( _Storage ))^.Float := LONGREAL( value );

      | sdtString :
         TPStorage( ADR( _Storage ))^.String^.FromINT32( INT32( value ), 10 );

      | sdtDate :
         Undefined := TRUE;

      ELSE
         ASSERT( FALSE );
      END; // CASE
   END Tristate;

(*--------------------------------------------------------------------------------*)

   PUBLIC PROPERTY Integer SET( value : INT32 );
   BEGIN
      IF _Type = sdtUnknown THEN
         _Type := sdtInteger;
      END;

      CASE _Type OF
      | sdtVoid :
      | sdtObject :
         ASSERT( FALSE );

      | sdtBoolean :
         TPStorage( ADR( _Storage ))^.Boolean := value <> 0;

      | sdtTristate :
         IF value >= 1 THEN
            TPStorage( ADR( _Storage ))^.Tristate := 1;
         ELSIF value <= -1 THEN
            TPStorage( ADR( _Storage ))^.Tristate := -1;
         ELSE
            TPStorage( ADR( _Storage ))^.Tristate := 0;
         END;

      | sdtInteger :
         TPStorage( ADR( _Storage ))^.Integer := value;
            
      | sdtLong :
         TPStorage( ADR( _Storage ))^.Long := INT64( value );

      | sdtFloat :
         TPStorage( ADR( _Storage ))^.Float := LONGREAL( value );

      | sdtString :
         TPStorage( ADR( _Storage ))^.String^.FromINT32( value, 10 );

      | sdtDate :
         TPStorage( ADR( _Storage ))^.Date := time.TrimFD( time.GetCurrentJD() ) + time.TJD( value ) * time.unitsInMillisecond;

      ELSE
         ASSERT( FALSE );
      END; // CASE
   END Integer;

(*--------------------------------------------------------------------------------*)

   PUBLIC PROPERTY Long SET( value : INT64 );
   BEGIN
      IF _Type = sdtUnknown THEN
         _Type := sdtLong;
      END;

      CASE _Type OF
      | sdtVoid :
      | sdtObject :
         ASSERT( FALSE );

      | sdtBoolean :
         TPStorage( ADR( _Storage ))^.Boolean := value <> 0;

      | sdtTristate :
         IF value >= 1 THEN
            TPStorage( ADR( _Storage ))^.Tristate := 1;
         ELSIF value <= -1 THEN
            TPStorage( ADR( _Storage ))^.Tristate := -1;
         ELSE
            TPStorage( ADR( _Storage ))^.Tristate := 0;
         END;

      | sdtInteger :
         IF vfSaturate NOT IN _Flags THEN
            TPStorage( ADR( _Storage ))^.Integer := INT32( value );
         ELSIF value > MAX( INT32 ) THEN
            TPStorage( ADR( _Storage ))^.Integer := MAX( INT32 );
         ELSIF value < MIN( INT32 ) THEN
            TPStorage( ADR( _Storage ))^.Integer := MIN( INT32 );
         ELSE
            TPStorage( ADR( _Storage ))^.Integer := INT32( value );
         END;
            
      | sdtLong :
         TPStorage( ADR( _Storage ))^.Long := value;

      | sdtFloat :
         TPStorage( ADR( _Storage ))^.Float := LONGREAL( value );

      | sdtString :
         TPStorage( ADR( _Storage ))^.String^.FromINT64( value, 10 );

      | sdtDate :
         TPStorage( ADR( _Storage ))^.Date := value;

      ELSE
         ASSERT( FALSE );
      END; // CASE
   END Long;

(*--------------------------------------------------------------------------------*)

   PUBLIC PROPERTY Float SET( value : LONGREAL );
   BEGIN
      IF _Type = sdtUnknown THEN
         _Type := sdtFloat;
      END;

      CASE _Type OF
      | sdtVoid :
      | sdtObject :
         ASSERT( FALSE );

      | sdtBoolean :
         TPStorage( ADR( _Storage ))^.Boolean := value <> 0.0;

      | sdtTristate :
         IF value >= 1.0 THEN
            TPStorage( ADR( _Storage ))^.Tristate := 1;
         ELSIF value <= -1.0 THEN
            TPStorage( ADR( _Storage ))^.Tristate := -1;
         ELSE
            TPStorage( ADR( _Storage ))^.Tristate := 0;
         END;

      | sdtInteger :
         IF vfSaturate NOT IN _Flags THEN
            TPStorage( ADR( _Storage ))^.Integer := INT32( value );
         ELSIF value > LONGREAL( MAX( INT32 )) THEN
            TPStorage( ADR( _Storage ))^.Integer := MAX( INT32 );
         ELSIF value < LONGREAL( MIN( INT32 )) THEN
            TPStorage( ADR( _Storage ))^.Integer := MIN( INT32 );
         ELSE
            TPStorage( ADR( _Storage ))^.Integer := INT32( value );
         END;
            
      | sdtLong :
         IF vfSaturate NOT IN _Flags THEN
            TPStorage( ADR( _Storage ))^.Long := INT64( value );
         ELSIF value > LONGREAL( MAX( INT64 )) THEN
            TPStorage( ADR( _Storage ))^.Long := MAX( INT64 );
         ELSIF value < LONGREAL( MIN( INT64 )) THEN
            TPStorage( ADR( _Storage ))^.Long := MIN( INT64 );
         ELSE
            TPStorage( ADR( _Storage ))^.Long := INT64( value );
         END;

      | sdtFloat :
         TPStorage( ADR( _Storage ))^.Float := value;

      | sdtString :
         TPStorage( ADR( _Storage ))^.String^.FromLONGREAL( value, FALSE );

      | sdtDate :
         TPStorage( ADR( _Storage ))^.Date := time.FromSJD( value );

      ELSE
         ASSERT( FALSE );
      END; // CASE
   END Float;

(*--------------------------------------------------------------------------------*)

   PUBLIC PROPERTY String SET( CONST value : StringsO.CString );
   VAR
      dt : time.TDateTime;
   BEGIN
      IF _Type = sdtUnknown THEN
         Type := sdtString; // using property allocates string
      END;

      CASE _Type OF
      | sdtVoid :
      | sdtObject :
         ASSERT( FALSE );

      | sdtBoolean :
         TPStorage( ADR( _Storage ))^.Boolean := value.EqualsOA( L"TRUE" ) OR value.EqualsOA( defaultTrue ) OR value.EqualsOA( L"T" ) OR value.EqualsOA( L"1" );

      | sdtTristate :
         IF value.EqualsOA( L"TRUE" ) OR value.EqualsOA( defaultTrue ) OR value.EqualsOA( L"T" ) OR value.EqualsOA( L"1" ) THEN
            TPStorage( ADR( _Storage ))^.Tristate := 1;
         ELSIF value.EqualsOA( L"FALSE" ) OR value.EqualsOA( defaultFalse ) OR value.EqualsOA( L"F" ) OR value.EqualsOA( L"0" ) THEN
            TPStorage( ADR( _Storage ))^.Tristate := 0;
         ELSE
            TPStorage( ADR( _Storage ))^.Tristate := -1;
         END;

      | sdtInteger :
         TRY
            TPStorage( ADR( _Storage ))^.Integer := value.ToINT32( 10 );
         CATCH e : StringsO.CStringException DO
            Undefined := TRUE;
         END;
            
      | sdtLong :
         TRY
            TPStorage( ADR( _Storage ))^.Long := value.ToINT64( 10 );
         CATCH e : StringsO.CStringException DO
            Undefined := TRUE;
         END;

      | sdtFloat :
         TRY
            TPStorage( ADR( _Storage ))^.Float := value.ToLONGREAL();
         CATCH e : StringsO.CStringException DO
            Undefined := TRUE;
         END;

      | sdtString :
         TPStorage( ADR( _Storage ))^.String^ := value;

      | sdtDate :
         IF time.StringToDateTime( OA( value.Length-1, value.rawData ), defaultDateTimeFormat, dt ) THEN
            time.InitDateTime( OUT dt );
            TPStorage( ADR( _Storage ))^.Date := time.ZonalDateTimeToJD( dt, 0, 0 );
         ELSE
            Undefined := TRUE;
         END;

      ELSE
         ASSERT( FALSE );
      END; // CASE
   END String;

(*--------------------------------------------------------------------------------*)

   PUBLIC PROPERTY Date SET( value : time.TJD );
   VAR
      today, tomorrow : time.TJD;
      dt : time.TDateTime;
      s : ARRAY [0..63] OF WCHAR;
   BEGIN
      IF _Type = sdtUnknown THEN
         _Type := sdtDate;
      END;

      CASE _Type OF
      | sdtVoid :
      | sdtObject :
         ASSERT( FALSE );

      | sdtBoolean :
         today := time.TrimFD( time.GetCurrentJD());
         tomorrow := today + time.DaysToJDC( 1 );
         TPStorage( ADR( _Storage ))^.Boolean := ( value >= today ) AND ( value < tomorrow );

      | sdtTristate :
         today := time.TrimFD( time.GetCurrentJD());
         tomorrow := today + time.DaysToJDC( 1 );
         TPStorage( ADR( _Storage ))^.Boolean := ( value >= today ) AND ( value < tomorrow );

      | sdtInteger :
         TPStorage( ADR( _Storage ))^.Integer := time.fd( value ) DIV CARDINAL( time.unitsInMillisecond );

      | sdtLong :
         TPStorage( ADR( _Storage ))^.Long := value;

      | sdtFloat :
         TPStorage( ADR( _Storage ))^.Float := time.ToSJD( value );

      | sdtString :
         time.JDToZonalDateTime( value, OUT dt, 0, 0 );
         IF time.DateTimeToString( dt, defaultDateTimeFormat, TRUE, TRUE, s ) THEN
            TPStorage( ADR( _Storage ))^.String^.FromOA( s );
         ELSE
            TPStorage( ADR( _Storage ))^.String^.Clear();
         END;

      | sdtDate :
         TPStorage( ADR( _Storage ))^.Date := value;

      ELSE
         ASSERT( FALSE );
      END; // CASE
   END Date;

(*--------------------------------------------------------------------------------*)

   PUBLIC PROPERTY PString GET: StringsO.TPString; // returns internal string for Type = dstString, otherwise it returns NIL
   BEGIN
      IF _Type = sdtString THEN
         RETURN TPStorage( ADR( _Storage ))^.String;
      ELSE
         RETURN NIL;
      END;
   END PString;

(*--------------------------------------------------------------------------------*)

   PUBLIC OPERATOR :=( CONST Source : Value );
   BEGIN
      _Flags := Source._Flags;
      IF _Type = sdtUnknown THEN
         _Type := Source._Type;
      END;

      CASE _Type OF
      | sdtUnknown :
      | sdtVoid :
      | sdtObject :
         ASSERT( FALSE );

      | sdtBoolean :
         TPStorage( ADR( _Storage ))^.Boolean := Source.Boolean;

      | sdtTristate :
         TPStorage( ADR( _Storage ))^.Tristate := Source.Tristate;

      | sdtInteger :
         TPStorage( ADR( _Storage ))^.Integer := Source.Integer;

      | sdtLong :
         TPStorage( ADR( _Storage ))^.Long := Source.Long;

      | sdtFloat :
         TPStorage( ADR( _Storage ))^.Float := Source.Float;

      | sdtString :
         IF TPStorage( ADR( _Storage ))^.String = NIL THEN
            TPStorage( ADR( _Storage ))^.String := NEW( StringsO.CString );
         END;
         TPStorage( ADR( _Storage ))^.String^ := Source.String;

      | sdtDate :
         TPStorage( ADR( _Storage ))^.Date := Source.Date;

      ELSE
         ASSERT( FALSE );
      END; // CASE
   END :=;

(*--------------------------------------------------------------------------------*)

   PUBLIC OPERATOR = ( CONST Source : Value ) : BOOLEAN; // hard, binary comparing
   BEGIN
      IF _Type <> Source._Type THEN
         RETURN FALSE;
      ELSIF _Flags * TFlags{vfUndefined} <> Source._Flags * TFlags{vfUndefined} THEN
         RETURN FALSE;
      ELSIF _Type = sdtString THEN
         RETURN TPStorage( ADR( _Storage ))^.String^ = TPStorage( ADR( Source._Storage ))^.String^;
      ELSE
         RETURN _Storage = Source._Storage;
      END;
   END =;

(*--------------------------------------------------------------------------------*)

   PUBLIC OPERATOR <>( CONST Source : Value ) : BOOLEAN; // hard, binary comparing
   BEGIN
      RETURN NOT( SELF = Source );
   END <>;

(*--------------------------------------------------------------------------------*)

   PUBLIC OPERATOR > ( CONST Source : Value ) : BOOLEAN;
   BEGIN
      IF ( vfUndefined IN _Flags ) OR ( vfUndefined IN Source._Flags ) THEN
         RETURN FALSE;
      ELSIF ( _Type <> Source._Type ) OR ( _Type = sdtString ) THEN
         RETURN String.Compare( Source.String ) > 0;
      END;
      CASE _Type OF
      | sdtBoolean :
         RETURN TPStorage( ADR( _Storage ))^.Boolean AND NOT Source.Boolean;
      | sdtTristate :
         RETURN TPStorage( ADR( _Storage ))^.Tristate > Source.Tristate;
      | sdtInteger :
         RETURN TPStorage( ADR( _Storage ))^.Integer > Source.Integer;
      | sdtLong :
         RETURN TPStorage( ADR( _Storage ))^.Long > Source.Long;
      | sdtFloat :
         RETURN TPStorage( ADR( _Storage ))^.Float > Source.Float;
      | sdtDate :
         RETURN TPStorage( ADR( _Storage ))^.Date > Source.Date;
      ELSE
         RETURN FALSE;
      END;
   END >;

(*--------------------------------------------------------------------------------*)

   PUBLIC OPERATOR >=( CONST Source : Value ) : BOOLEAN;
   BEGIN
      RETURN NOT( SELF < Source );
   END >=;

(*--------------------------------------------------------------------------------*)

   PUBLIC OPERATOR < ( CONST Source : Value ) : BOOLEAN;
   BEGIN
      IF ( vfUndefined IN _Flags ) OR ( vfUndefined IN Source._Flags ) THEN
         RETURN FALSE;
      ELSIF ( _Type <> Source._Type ) OR ( _Type = sdtString ) THEN
         RETURN String.Compare( Source.String ) < 0;
      END;
      CASE _Type OF
      | sdtBoolean :
         RETURN NOT TPStorage( ADR( _Storage ))^.Boolean AND Source.Boolean;
      | sdtTristate :
         RETURN TPStorage( ADR( _Storage ))^.Tristate < Source.Tristate;
      | sdtInteger :
         RETURN TPStorage( ADR( _Storage ))^.Integer < Source.Integer;
      | sdtLong :
         RETURN TPStorage( ADR( _Storage ))^.Long < Source.Long;
      | sdtFloat :
         RETURN TPStorage( ADR( _Storage ))^.Float < Source.Float;
      | sdtDate :
         RETURN TPStorage( ADR( _Storage ))^.Date < Source.Date;
      ELSE
         RETURN FALSE;
      END;
   END <;

(*--------------------------------------------------------------------------------*)

   PUBLIC OPERATOR <=( CONST Source : Value ) : BOOLEAN;
   BEGIN
      RETURN NOT( SELF > Source );
   END <=;

(*--------------------------------------------------------------------------------*)

   PUBLIC OPERATOR + ( CONST Source : Value ) : Value;
   VAR
      i1, i2 : INT32;
      l1, l2 : INT64;
      LValue : Value;
      t1, t2 : TRISTATE;
   BEGIN
      LValue._Flags := _Flags;
      LValue.Type := _Type;
      IF ( vfUndefined IN _Flags ) OR ( vfUndefined IN Source._Flags ) THEN
         LValue.Undefined := TRUE;
      ELSIF ( _Type <> Source._Type ) OR ( _Type = sdtString ) OR ( _Type = sdtDate ) THEN
         LValue.String := String + Source.String;
      ELSE
         CASE _Type OF
         | sdtBoolean :
            LValue.Boolean := Boolean OR Source.Boolean;
         | sdtTristate :
            t1 := Tristate;
            t2 := Source.Tristate;
            IF ( t1 = -1 ) OR ( t2 = -1 ) THEN
               LValue.Tristate := -1;
            ELSIF ( t1 = 1 ) OR ( t2 = 1 ) THEN
               LValue.Tristate := 1;
            ELSE
               LValue.Tristate := 0;
            END;
         | sdtInteger :
            i1 := Integer;
            i2 := i1 + Source.Integer;
            IF ( vfSaturate IN _Flags ) AND ( i2 < i1 ) THEN // overflow 
               LValue.Integer := MAX( INT32 );
            ELSE
               LValue.Integer := i2;
            END;
         | sdtLong :
            l1 := Long;
            l2 := l1 + Source.Long;
            IF ( vfSaturate IN _Flags ) AND ( l2 < l1 ) THEN // overflow 
               LValue.Long := MAX( INT64 );
            ELSE
               LValue.Long := l2;
            END;
         | sdtFloat :
            LValue.Float := Float + Source.Float;
         END;
      END;
      RETURN LValue;
   END +;

(*--------------------------------------------------------------------------------*)

   PUBLIC OPERATOR - ( CONST Source : Value ) : Value;
   VAR
      i1, i2 : INT32;
      l1, l2 : INT64;
      LValue : Value;
      t1, t2 : TRISTATE;
   BEGIN
      LValue._Flags := _Flags;
      LValue.Type := _Type;
      IF ( vfUndefined IN _Flags ) OR ( vfUndefined IN Source._Flags ) THEN
         LValue.Undefined := TRUE;
      ELSIF ( _Type <> Source._Type ) OR ( _Type = sdtString ) THEN
         LValue.Undefined := TRUE;
      ELSIF _Type = sdtDate THEN
         LValue.Type := sdtLong;
         LValue.Long := ( Date - Source.Date ) DIV time.unitsInMillisecond;
      ELSE
         CASE _Type OF
         | sdtBoolean :
            LValue.Boolean := Boolean AND NOT Source.Boolean;
         | sdtTristate :
            t1 := Tristate;
            t2 := Source.Tristate;
            IF ( t1 = -1 ) OR ( t2 = -1 ) THEN
               LValue.Tristate := -1;
            ELSIF t1 = 0 THEN
               LValue.Tristate := 0;
            ELSIF t2 = 1 THEN
               LValue.Tristate := 0;
            ELSE
               LValue.Tristate := 1;
            END;
         | sdtInteger :
            i1 := Integer;
            i2 := i1 - Source.Integer;
            IF ( vfSaturate IN _Flags ) AND ( i2 > i1 ) THEN // overflow 
               LValue.Integer := MIN( INT32 );
            ELSE
               LValue.Integer := i2;
            END;
         | sdtLong :
            l1 := Long;
            l2 := l1 - Source.Long;
            IF ( vfSaturate IN _Flags ) AND ( l2 > l1 ) THEN // overflow 
               LValue.Long := MIN( INT64 );
            ELSE
               LValue.Long := l2;
            END;
         | sdtFloat :
            LValue.Float := Float - Source.Float;
         END;
      END;
      RETURN LValue;
   END -;

(*--------------------------------------------------------------------------------*)

   PUBLIC OPERATOR * ( CONST Source : Value ) : Value;
   VAR
      i1, i2 : INT32;
      l1, l2 : INT64;
      LValue : Value;
      t1, t2 : TRISTATE;
   BEGIN
      LValue._Flags := _Flags;
      LValue.Type := _Type;
      IF ( vfUndefined IN _Flags ) OR ( vfUndefined IN Source._Flags ) THEN
         LValue.Undefined := TRUE;
      ELSIF ( _Type <> Source._Type ) OR ( _Type = sdtString ) OR ( _Type = sdtDate ) THEN
         LValue.Undefined := TRUE;
      ELSE
         CASE _Type OF
         | sdtBoolean :
            LValue.Boolean := Boolean AND Source.Boolean;
         | sdtTristate :
            t1 := Tristate;
            t2 := Source.Tristate;
            IF ( t1 = -1 ) OR ( t2 = -1 ) THEN
               LValue.Tristate := -1;
            ELSIF ( t1 = 0 ) OR ( t2 = 0 ) THEN
               LValue.Tristate := 0;
            ELSE
               LValue.Tristate := 1;
            END;
         | sdtInteger :
            i1 := Integer;
            i2 := i1 * Source.Integer;
            // TODO saturation
            LValue.Integer := i2;
         | sdtLong :
            l1 := Long;
            l2 := l1 * Source.Long;
            // TODO saturation
            LValue.Long := l2;
         | sdtFloat :
            LValue.Float := Float * Source.Float;
         END;
      END;
      RETURN LValue;
   END *;

(*--------------------------------------------------------------------------------*)

   PUBLIC OPERATOR / ( CONST Source : Value ) : Value;
   VAR
      f : LONGREAL;
      i1, i2 : INT32;
      l1, l2 : INT64;
      LValue : Value;
      t1, t2 : TRISTATE;
   BEGIN
      LValue._Flags := _Flags;
      LValue.Type := _Type;
      IF ( vfUndefined IN _Flags ) OR ( vfUndefined IN Source._Flags ) THEN
         LValue.Undefined := TRUE;
      ELSIF ( _Type <> Source._Type ) OR ( _Type = sdtString ) OR ( _Type = sdtDate ) THEN
         LValue.Undefined := TRUE;
      ELSE
         CASE _Type OF
         | sdtBoolean :
            LValue.Boolean := Boolean <> Source.Boolean;
         | sdtTristate :
            t1 := Tristate;
            t2 := Source.Tristate;
            IF ( t1 = -1 ) OR ( t2 = -1 ) THEN
               LValue.Tristate := -1;
            ELSIF ( t1 = 0 ) = ( t2 = 0 ) THEN
               LValue.Tristate := 0;
            ELSE
               LValue.Tristate := 1;
            END;
         | sdtInteger :
            i1 := Integer;
            i2 := Source.Integer;
            IF i2 = 0 THEN
               LValue.Undefined := TRUE;
            ELSE
               LValue.Integer := i1 DIV i2;
            END;
         | sdtLong :
            l1 := Long;
            l2 := Source.Long;
            IF l2 = 0 THEN
               LValue.Undefined := TRUE;
            ELSE
               LValue.Long := l1 DIV l2;
            END;
         | sdtFloat :
            f := Source.Float;
            IF f = 0.0 THEN
               LValue.Undefined := TRUE;
            ELSE
               LValue.Float := Float / Source.Float;
            END;
         END;
      END;
      RETURN LValue;
   END /;

(*--------------------------------------------------------------------------------*)

   PUBLIC PROCEDURE Dispose();
   BEGIN
      IF _Type = sdtString THEN
         DISPOSE( TPStorage( ADR( _Storage ))^.String );
      END;
      _Flags := TFlags{};
      _Type := sdtUnknown;
      _Storage := 0;
   END Dispose;

(*--------------------------------------------------------------------------------*)

   PUBLIC PROCEDURE Clone( OUT New : Value ); // New has the same type
   BEGIN
      New.Dispose();
      New._Type := _Type;
      New := SELF;
   END Clone;

(*--------------------------------------------------------------------------------*)

   PUBLIC PROCEDURE Equals( CONST Source : Value ) : BOOLEAN; // soft, respects different types
   BEGIN
      IF ( _Type = sdtString ) OR ( Source._Type = sdtString ) THEN
         RETURN String = Source.String;
      ELSE
         RETURN Float = Float;
      END;
   END Equals;

(*--------------------------------------------------------------------------------*)

   PUBLIC PROCEDURE ToString( OUT String : StringsO.IString; TransportFlag : BOOLEAN );
   BEGIN
      IF _Type <> sdtBoolean THEN
         String.Assign( SELF.String );
      ELSIF Boolean THEN
         String.FromOA( defaultTransportTrue );
      ELSE
         String.FromOA( defaultTransportFalse );
      END;
   END ToString;

(*--------------------------------------------------------------------------------*)

   PUBLIC PROCEDURE ToStringOA( OUT String : ARRAY OF WCHAR; TransportFlag : BOOLEAN );
   BEGIN
      IF _Type <> sdtBoolean THEN
         SELF.String.ToOA( OUT String );
      ELSIF Boolean THEN
         String := defaultTransportTrue;
      ELSE
         String := defaultTransportFalse;
      END;
   END ToStringOA;
   
(*--------------------------------------------------------------------------------*)

   PUBLIC PROCEDURE FromString( CONST String : StringsO.IString; TransportFlag : BOOLEAN );
   VAR
      S : StringsO.CString;
   BEGIN
      S.Assign( String );
      SELF.String := S;
   END FromString;

(*--------------------------------------------------------------------------------*)

   PUBLIC PROCEDURE FromStringOA( CONST String : ARRAY OF WCHAR; TransportFlag : BOOLEAN );
   VAR
      S : StringsO.CString;
   BEGIN
      S.FromOA( String );
      SELF.String := S;
   END FromStringOA;

(*--------------------------------------------------------------------------------*)

   PUBLIC PROCEDURE Limit( Bits : CARDINAL; Signed, Saturate : BOOLEAN ); // e.g. Limit( 8, TRUE, FALSE ) saturates to CARD8, limites only numbers (Integer, Long, Float)
   VAR
      fl, fh : LONGREAL;
      il, ih : INT32;
      ll, lh : INT64;
   BEGIN
      IF vfUndefined IN _Flags THEN
         RETURN;
      END;
      CASE _Type OF
      | sdtInteger :
         IF NOT Saturate THEN
            ih := 1 << Bits;
         ELSIF Signed THEN
            il := -( 1 << (Bits-1));
            ih := 1 << (Bits-1) - 1;
         ELSE
            il := 0;
            ih := 1 << Bits - 1;
         END;
         IF NOT Saturate THEN
            TPStorage( ADR( _Storage ))^.Integer := TPStorage( ADR( _Storage ))^.Integer MOD ih;
         ELSIF TPStorage( ADR( _Storage ))^.Integer > ih THEN
            TPStorage( ADR( _Storage ))^.Integer := ih;
         ELSIF TPStorage( ADR( _Storage ))^.Integer < il THEN
            TPStorage( ADR( _Storage ))^.Integer := il;
         END;
      | sdtLong :
         IF NOT Saturate THEN
            lh := 1 << Bits;
         ELSIF Signed THEN
            ll := -( 1 << (Bits-1));
            lh := 1 << (Bits-1) - 1;
         ELSE
            ll := 0;
            lh := 1 << Bits - 1;
         END;
         IF NOT Saturate THEN
            TPStorage( ADR( _Storage ))^.Long := TPStorage( ADR( _Storage ))^.Long MOD lh;
         ELSIF TPStorage( ADR( _Storage ))^.Long > lh THEN
            TPStorage( ADR( _Storage ))^.Long := lh;
         ELSIF TPStorage( ADR( _Storage ))^.Long < ll THEN
            TPStorage( ADR( _Storage ))^.Long := ll;
         END;
      | sdtFloat :
         IF NOT Saturate THEN
            fh := LONGREAL( 1 << Bits );
         ELSIF Signed THEN
            fl := LONGREAL( -( 1 << (Bits-1)) );
            fh := LONGREAL( 1 << (Bits-1) - 1 );
         ELSE
            fl := 0.0;
            fh := LONGREAL( 1 << Bits - 1 );
         END;
         IF NOT Saturate THEN
            TPStorage( ADR( _Storage ))^.Float := TPStorage( ADR( _Storage ))^.Float - fh * LONGREAL( INT64( TPStorage( ADR( _Storage ))^.Float / fh ));
         ELSIF TPStorage( ADR( _Storage ))^.Float > fh THEN
            TPStorage( ADR( _Storage ))^.Float := fh;
         ELSIF TPStorage( ADR( _Storage ))^.Float < fl THEN
            TPStorage( ADR( _Storage ))^.Float := fl;
         END;
      END;
   END Limit;

(*--------------------------------------------------------------------------------*)

   PUBLIC PROCEDURE LimitedInteger( Bits : CARDINAL; Signed, Saturate : BOOLEAN ) : INT32;
   VAR
      LValue : Value;
   BEGIN
      IF vfUndefined IN _Flags THEN
         RETURN 0;
      END;
      LValue.Type := sdtInteger;
      LValue := SELF;
      LValue.Limit( Bits, Signed, Saturate );
      RETURN LValue.Integer;
   END LimitedInteger;

(*--------------------------------------------------------------------------------*)

   PUBLIC PROCEDURE LimitedLong( Bits : CARDINAL; Signed, Saturate : BOOLEAN ) : INT64;
   VAR
      LValue : Value;
   BEGIN
      IF vfUndefined IN _Flags THEN
         RETURN 0;
      END;
      LValue.Type := sdtLong;
      LValue := SELF;
      LValue.Limit( Bits, Signed, Saturate );
      RETURN LValue.Long;
   END LimitedLong;

(*--------------------------------------------------------------------------------*)

   PUBLIC PROCEDURE LimitedFloat( Bits : CARDINAL; Signed, Saturate : BOOLEAN ) : LONGREAL;
   VAR
      LValue : Value;
   BEGIN
      IF vfUndefined IN _Flags THEN
         RETURN 0.0;
      END;
      LValue.Type := sdtFloat;
      LValue := SELF;
      LValue.Limit( Bits, Signed, Saturate );
      RETURN LValue.Float;
   END LimitedFloat;

(*--------------------------------------------------------------------------------*)

BEGIN
   _Flags := TFlags{};
   _Type := sdtUnknown;
   _Storage := 0;
FINALLY
   Dispose();
END Value;

(*================================================================================*)

END sdvalue.