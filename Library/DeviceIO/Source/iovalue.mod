IMPLEMENTATION MODULE iovalue;

FROM Storage IMPORT
   ALLOCATE, DEALLOCATE;

IMPORT
   Strings;

(*================================================================================*)

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

   PUBLIC PROPERTY Type GET : TValueType;
   BEGIN
      RETURN _Type;
   END Type;

(*--------------------------------------------------------------------------------*)

   PUBLIC PROPERTY Type SET( value : TValueType );
   VAR
      LFlags : TFlags;
      LValue : Value;
   BEGIN
      IF _Type <> value THEN
         LFlags := _Flags;

         IF ( value <> vtUnknown ) AND ( value <> vtVoid ) THEN
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
         LValue._Type := vtUnknown;
         LValue._Storage.QW := 0;
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
         IF _Type = vtString THEN
            _Storage.String^.Clear();
         ELSE
            _Storage.QW := 0;
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
      | vtUnknown :
      | vtVoid :
      | vtObject :
         ASSERT( FALSE );

      | vtBoolean :
         RETURN _Storage.Boolean;

      | vtTristate :
         RETURN _Storage.Tristate = 1;

      | vtInteger :
         RETURN _Storage.Integer <> 0;

      | vtLong :
         RETURN _Storage.Long <> 0;

      | vtFloat :
         RETURN _Storage.Float <> 0.0;

      | vtString :
         PS := _Storage.String;
         RETURN PS^.EqualsOA( L"TRUE" ) OR PS^.EqualsOA( defaultTrue ) OR PS^.EqualsOA( L"T" ) OR PS^.EqualsOA( L"1" );

      | vtDate :
         today := time.TrimFD( time.GetCurrentJD());
         tomorrow := today + time.DaysToJDC( 1 );
         RETURN ( _Storage.Date >= today ) AND ( _Storage.Date < tomorrow );

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
      | vtUnknown :
      | vtVoid :
      | vtObject :
         ASSERT( FALSE );

      | vtBoolean :
         IF _Storage.Boolean THEN
            RETURN 1;
         ELSE
            RETURN 0;
         END;

      | vtTristate :
         RETURN _Storage.Tristate;

      | vtInteger :
         IF _Storage.Integer >= 1 THEN
            RETURN 1;
         ELSIF _Storage.Integer <= -1 THEN
            RETURN -1;
         ELSE
            RETURN 0;
         END;
            
      | vtLong :
         IF _Storage.Long >= 1 THEN
            RETURN 1;
         ELSIF _Storage.Long <= INT64( -1 ) THEN
            RETURN -1;
         ELSE
            RETURN 0;
         END;

      | vtFloat :
         IF _Storage.Float >= 1.0 THEN
            RETURN 1;
         ELSIF _Storage.Float <= -1.0 THEN
            RETURN -1;
         ELSE
            RETURN 0;
         END;

      | vtString :
         PS := _Storage.String;
         IF PS^.EqualsOA( L"TRUE" ) OR PS^.EqualsOA( defaultTrue ) OR PS^.EqualsOA( L"T" ) OR PS^.EqualsOA( L"1" ) THEN
            RETURN 1;
         ELSIF PS^.EqualsOA( L"FALSE" ) OR PS^.EqualsOA( defaultFalse ) OR PS^.EqualsOA( L"F" ) OR PS^.EqualsOA( L"0" ) THEN
            RETURN 0;
         ELSE
            RETURN -1;
         END;

      | vtDate :
         today := time.TrimFD( time.GetCurrentJD());
         tomorrow := today + time.DaysToJDC( 1 );
         IF ( _Storage.Date >= today ) AND ( _Storage.Date < tomorrow ) THEN
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
      | vtUnknown :
      | vtVoid :
      | vtObject :
         ASSERT( FALSE );

      | vtBoolean :
         IF _Storage.Boolean THEN
            RETURN 1;
         ELSE
            RETURN 0;
         END;

      | vtTristate :
         RETURN INT32( _Storage.Tristate );

      | vtInteger :
         RETURN _Storage.Integer;

      | vtLong :
         IF vfSaturate NOT IN _Flags THEN
            RETURN INTEGER( _Storage.Long );
         ELSIF _Storage.Long > MAX( INT32 ) THEN
            RETURN MAX( INT32 );
         ELSIF _Storage.Long < MIN( INT32 ) THEN
            RETURN MIN( INT32 );
         ELSE
            RETURN INTEGER( _Storage.Long );
         END;

      | vtFloat :
         IF vfSaturate NOT IN _Flags THEN
            RETURN INTEGER( _Storage.Float );
         ELSIF _Storage.Float > LONGREAL( MAX( INT32 )) THEN
            RETURN MAX( INT32 );
         ELSIF _Storage.Float < LONGREAL( MIN( INT32 )) THEN
            RETURN MIN( INT32 );
         ELSE
            RETURN INTEGER( _Storage.Float );
         END;

      | vtString :
         TRY
            RETURN _Storage.String^.ToINT32( 10 );
         CATCH e : StringsO.CStringException DO
            RETURN 0;
         END;

      | vtDate :
         RETURN time.fd( _Storage.Date ) DIV CARDINAL( time.unitsInMillisecond );

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
      | vtUnknown :
      | vtVoid :
      | vtObject :
         ASSERT( FALSE );

      | vtBoolean :
         IF _Storage.Boolean THEN
            RETURN 1;
         ELSE
            RETURN 0;
         END;

      | vtTristate :
         RETURN INT64( _Storage.Tristate );

      | vtInteger :
         RETURN INT64( _Storage.Integer );

      | vtLong :
         RETURN _Storage.Long;

      | vtFloat :
         RETURN INT64( _Storage.Float );

      | vtString :
         TRY
            RETURN _Storage.String^.ToINT64( 10 );
         CATCH e : StringsO.CStringException DO
            RETURN 0;
         END;

      | vtDate :
         RETURN _Storage.Date;

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
      | vtUnknown :
      | vtVoid :
      | vtObject :
         ASSERT( FALSE );

      | vtBoolean :
         IF _Storage.Boolean THEN
            RETURN 1.0;
         ELSE
            RETURN 0.0;
         END;

      | vtTristate :
         RETURN LONGREAL( _Storage.Tristate );

      | vtInteger :
         RETURN LONGREAL( _Storage.Integer );

      | vtLong :
         RETURN LONGREAL( _Storage.Long );

      | vtFloat :
         RETURN _Storage.Float;

      | vtString :
         TRY
            RETURN _Storage.String^.ToLONGREAL();
         CATCH e : StringsO.CStringException DO
            RETURN 0.0;
         END;

      | vtDate :
         RETURN time.ToSJD( _Storage.Date );

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
      | vtUnknown :
      | vtVoid :
      | vtObject :
         ASSERT( FALSE );

      | vtBoolean :
         IF _Storage.Boolean THEN
            S.FromOA( defaultTrue );
         ELSE
            S.FromOA( defaultFalse );
         END;

      | vtTristate :
         S.FromINT32( INT32( _Storage.Tristate ), 10 );

      | vtInteger :
         S.FromINT32( _Storage.Integer, 10 );

      | vtLong :
         S.FromINT64( _Storage.Long, 10 );

      | vtFloat :
         S.FromLONGREAL( _Storage.Float, FALSE );

      | vtString :
         RETURN _Storage.String^;

      | vtDate :
         time.JDToZonalDateTime( _Storage.Date, OUT dt, 0, 0 );
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
      | vtUnknown :
      | vtVoid :
      | vtObject :
         ASSERT( FALSE );

      | vtBoolean :
         IF _Storage.Boolean THEN
            RETURN t;
         ELSE
            RETURN defaultDate;
         END;

      | vtTristate :
         IF _Storage.Tristate = 1 THEN
            RETURN t;
         ELSE
            RETURN defaultDate;
         END;

      | vtInteger :
         IF _Storage.Integer < 0 THEN
            RETURN defaultDate;
         ELSE
            RETURN time.TrimFD( t ) + time.TJD( _Storage.Integer * INTEGER( time.unitsInMillisecond ));
         END;

      | vtLong :
         RETURN _Storage.Long;

      | vtFloat :
         RETURN time.FromSJD( _Storage.Float );

      | vtString :
         IF time.StringToDateTime( OA( _Storage.String^.Length-1, _Storage.String^.rawData ), defaultDateTimeFormat, dt ) THEN
            time.InitDateTime( OUT dt );
            RETURN time.ZonalDateTimeToJD( dt, 0, 0 );
         ELSE
            RETURN defaultDate;
         END;

      | vtDate :
         RETURN _Storage.Date;

      ELSE
         ASSERT( FALSE );
      END; // CASE
      RETURN defaultDate;
   END Date;

(*--------------------------------------------------------------------------------*)

   PUBLIC PROPERTY Boolean SET( value : BOOLEAN );
   BEGIN
      IF _Type = vtUnknown THEN
         _Type := vtBoolean;
      END;

      CASE _Type OF
      | vtVoid :
      | vtObject :
         ASSERT( FALSE );

      | vtBoolean :
         _Storage.Boolean := value;

      | vtTristate :
         IF value THEN
            _Storage.Tristate := 1;
         ELSE
            _Storage.Tristate := 0;
         END;

      | vtInteger :
         IF value THEN
            _Storage.Integer := 1;
         ELSE
            _Storage.Integer := 0;
         END;

      | vtLong :
         IF value THEN
            _Storage.Long := 1;
         ELSE
            _Storage.Long := 0;
         END;

      | vtFloat :
         IF value THEN
            _Storage.Float := 1.0;
         ELSE
            _Storage.Float := 0.0;
         END;

      | vtString :
         IF value THEN
            _Storage.String^.FromOA( defaultTrue );
         ELSE
            _Storage.String^.FromOA( defaultFalse );
         END;

      | vtDate :
         Undefined := TRUE;

      ELSE
         ASSERT( FALSE );
      END; // CASE
   END Boolean;

(*--------------------------------------------------------------------------------*)

   PUBLIC PROPERTY Tristate SET( value : TRISTATE );
   BEGIN
      IF _Type = vtUnknown THEN
         _Type := vtTristate;
      END;

      CASE _Type OF
      | vtVoid :
      | vtObject :
         ASSERT( FALSE );

      | vtBoolean :
         _Storage.Boolean := value = 1;

      | vtTristate :
         _Storage.Tristate := value;

      | vtInteger :
         _Storage.Integer := INT32( value );
            
      | vtLong :
         _Storage.Long := INT64( value );

      | vtFloat :
         _Storage.Float := LONGREAL( value );

      | vtString :
         _Storage.String^.FromINT32( INT32( value ), 10 );

      | vtDate :
         Undefined := TRUE;

      ELSE
         ASSERT( FALSE );
      END; // CASE
   END Tristate;

(*--------------------------------------------------------------------------------*)

   PUBLIC PROPERTY Integer SET( value : INT32 );
   BEGIN
      IF _Type = vtUnknown THEN
         _Type := vtInteger;
      END;

      CASE _Type OF
      | vtVoid :
      | vtObject :
         ASSERT( FALSE );

      | vtBoolean :
         _Storage.Boolean := value <> 0;

      | vtTristate :
         IF value >= 1 THEN
            _Storage.Tristate := 1;
         ELSIF value <= -1 THEN
            _Storage.Tristate := -1;
         ELSE
            _Storage.Tristate := 0;
         END;

      | vtInteger :
         _Storage.Integer := value;
            
      | vtLong :
         _Storage.Long := INT64( value );

      | vtFloat :
         _Storage.Float := LONGREAL( value );

      | vtString :
         _Storage.String^.FromINT32( value, 10 );

      | vtDate :
         _Storage.Date := time.TrimFD( time.GetCurrentJD() ) + time.TJD( value ) * time.unitsInMillisecond;

      ELSE
         ASSERT( FALSE );
      END; // CASE
   END Integer;

(*--------------------------------------------------------------------------------*)

   PUBLIC PROPERTY Long SET( value : INT64 );
   BEGIN
      IF _Type = vtUnknown THEN
         _Type := vtLong;
      END;

      CASE _Type OF
      | vtVoid :
      | vtObject :
         ASSERT( FALSE );

      | vtBoolean :
         _Storage.Boolean := value <> 0;

      | vtTristate :
         IF value >= 1 THEN
            _Storage.Tristate := 1;
         ELSIF value <= -1 THEN
            _Storage.Tristate := -1;
         ELSE
            _Storage.Tristate := 0;
         END;

      | vtInteger :
         IF vfSaturate NOT IN _Flags THEN
            _Storage.Integer := INT32( value );
         ELSIF value > MAX( INT32 ) THEN
            _Storage.Integer := MAX( INT32 );
         ELSIF value < MIN( INT32 ) THEN
            _Storage.Integer := MIN( INT32 );
         ELSE
            _Storage.Integer := INT32( value );
         END;
            
      | vtLong :
         _Storage.Long := value;

      | vtFloat :
         _Storage.Float := LONGREAL( value );

      | vtString :
         _Storage.String^.FromINT64( value, 10 );

      | vtDate :
         _Storage.Date := value;

      ELSE
         ASSERT( FALSE );
      END; // CASE
   END Long;

(*--------------------------------------------------------------------------------*)

   PUBLIC PROPERTY Float SET( value : LONGREAL );
   BEGIN
      IF _Type = vtUnknown THEN
         _Type := vtFloat;
      END;

      CASE _Type OF
      | vtVoid :
      | vtObject :
         ASSERT( FALSE );

      | vtBoolean :
         _Storage.Boolean := value <> 0.0;

      | vtTristate :
         IF value >= 1.0 THEN
            _Storage.Tristate := 1;
         ELSIF value <= -1.0 THEN
            _Storage.Tristate := -1;
         ELSE
            _Storage.Tristate := 0;
         END;

      | vtInteger :
         IF vfSaturate NOT IN _Flags THEN
            _Storage.Integer := INT32( value );
         ELSIF value > LONGREAL( MAX( INT32 )) THEN
            _Storage.Integer := MAX( INT32 );
         ELSIF value < LONGREAL( MIN( INT32 )) THEN
            _Storage.Integer := MIN( INT32 );
         ELSE
            _Storage.Integer := INT32( value );
         END;
            
      | vtLong :
         IF vfSaturate NOT IN _Flags THEN
            _Storage.Long := INT64( value );
         ELSIF value > LONGREAL( MAX( INT64 )) THEN
            _Storage.Long := MAX( INT64 );
         ELSIF value < LONGREAL( MIN( INT64 )) THEN
            _Storage.Long := MIN( INT64 );
         ELSE
            _Storage.Long := INT64( value );
         END;

      | vtFloat :
         _Storage.Float := value;

      | vtString :
         _Storage.String^.FromLONGREAL( value, FALSE );

      | vtDate :
         _Storage.Date := time.FromSJD( value );

      ELSE
         ASSERT( FALSE );
      END; // CASE
   END Float;

(*--------------------------------------------------------------------------------*)

   PUBLIC PROPERTY String SET( CONST value : StringsO.CString );
   VAR
      dt : time.TDateTime;
   BEGIN
      IF _Type = vtUnknown THEN
         Type := vtString; // using property allocates string
      END;

      CASE _Type OF
      | vtVoid :
      | vtObject :
         ASSERT( FALSE );

      | vtBoolean :
         _Storage.Boolean := value.EqualsOA( L"TRUE" ) OR value.EqualsOA( defaultTrue ) OR value.EqualsOA( L"T" ) OR value.EqualsOA( L"1" );

      | vtTristate :
         IF value.EqualsOA( L"TRUE" ) OR value.EqualsOA( defaultTrue ) OR value.EqualsOA( L"T" ) OR value.EqualsOA( L"1" ) THEN
            _Storage.Tristate := 1;
         ELSIF value.EqualsOA( L"FALSE" ) OR value.EqualsOA( defaultFalse ) OR value.EqualsOA( L"F" ) OR value.EqualsOA( L"0" ) THEN
            _Storage.Tristate := 0;
         ELSE
            _Storage.Tristate := -1;
         END;

      | vtInteger :
         TRY
            _Storage.Integer := value.ToINT32( 10 );
         CATCH e : StringsO.CStringException DO
            Undefined := TRUE;
         END;
            
      | vtLong :
         TRY
            _Storage.Long := value.ToINT64( 10 );
         CATCH e : StringsO.CStringException DO
            Undefined := TRUE;
         END;

      | vtFloat :
         TRY
            _Storage.Float := value.ToLONGREAL();
         CATCH e : StringsO.CStringException DO
            Undefined := TRUE;
         END;

      | vtString :
         _Storage.String^ := value;

      | vtDate :
         IF time.StringToDateTime( OA( value.Length-1, value.rawData ), defaultDateTimeFormat, dt ) THEN
            time.InitDateTime( OUT dt );
            _Storage.Date := time.ZonalDateTimeToJD( dt, 0, 0 );
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
      IF _Type = vtUnknown THEN
         _Type := vtDate;
      END;

      CASE _Type OF
      | vtVoid :
      | vtObject :
         ASSERT( FALSE );

      | vtBoolean :
         today := time.TrimFD( time.GetCurrentJD());
         tomorrow := today + time.DaysToJDC( 1 );
         _Storage.Boolean := ( value >= today ) AND ( value < tomorrow );

      | vtTristate :
         today := time.TrimFD( time.GetCurrentJD());
         tomorrow := today + time.DaysToJDC( 1 );
         _Storage.Boolean := ( value >= today ) AND ( value < tomorrow );

      | vtInteger :
         _Storage.Integer := time.fd( value ) DIV CARDINAL( time.unitsInMillisecond );

      | vtLong :
         _Storage.Long := value;

      | vtFloat :
         _Storage.Float := time.ToSJD( value );

      | vtString :
         time.JDToZonalDateTime( value, OUT dt, 0, 0 );
         IF time.DateTimeToString( dt, defaultDateTimeFormat, TRUE, TRUE, s ) THEN
            _Storage.String^.FromOA( s );
         ELSE
            _Storage.String^.Clear();
         END;

      | vtDate :
         _Storage.Date := value;

      ELSE
         ASSERT( FALSE );
      END; // CASE
   END Date;

(*--------------------------------------------------------------------------------*)

   PUBLIC PROPERTY PString GET: StringsO.TPString; // returns internal string for Type = dstString, otherwise it returns NIL
   BEGIN
      IF _Type = vtString THEN
         RETURN _Storage.String;
      ELSE
         RETURN NIL;
      END;
   END PString;

(*--------------------------------------------------------------------------------*)

   PUBLIC OPERATOR :=( CONST Source : Value );
   BEGIN
      _Flags := Source._Flags;
      IF _Type = vtUnknown THEN
         _Type := Source._Type;
      END;

      CASE _Type OF
      | vtUnknown :
      | vtVoid :
      | vtObject :
         ASSERT( FALSE );

      | vtBoolean :
         _Storage.Boolean := Source.Boolean;

      | vtTristate :
         _Storage.Tristate := Source.Tristate;

      | vtInteger :
         _Storage.Integer := Source.Integer;

      | vtLong :
         _Storage.Long := Source.Long;

      | vtFloat :
         _Storage.Float := Source.Float;

      | vtString :
         IF _Storage.String = NIL THEN
            _Storage.String := NEW( StringsO.CString );
         END;
         _Storage.String^ := Source.String;

      | vtDate :
         _Storage.Date := Source.Date;

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
      ELSIF _Type = vtString THEN
         RETURN _Storage.String^ = Source._Storage.String^;
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
      ELSIF ( _Type <> Source._Type ) OR ( _Type = vtString ) THEN
         RETURN String.Compare( Source.String ) > 0;
      END;
      CASE _Type OF
      | vtBoolean :
         RETURN _Storage.Boolean AND NOT Source.Boolean;
      | vtTristate :
         RETURN _Storage.Tristate > Source.Tristate;
      | vtInteger :
         RETURN _Storage.Integer > Source.Integer;
      | vtLong :
         RETURN _Storage.Long > Source.Long;
      | vtFloat :
         RETURN _Storage.Float > Source.Float;
      | vtDate :
         RETURN _Storage.Date > Source.Date;
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
      ELSIF ( _Type <> Source._Type ) OR ( _Type = vtString ) THEN
         RETURN String.Compare( Source.String ) < 0;
      END;
      CASE _Type OF
      | vtBoolean :
         RETURN NOT _Storage.Boolean AND Source.Boolean;
      | vtTristate :
         RETURN _Storage.Tristate < Source.Tristate;
      | vtInteger :
         RETURN _Storage.Integer < Source.Integer;
      | vtLong :
         RETURN _Storage.Long < Source.Long;
      | vtFloat :
         RETURN _Storage.Float < Source.Float;
      | vtDate :
         RETURN _Storage.Date < Source.Date;
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
      ELSIF ( _Type <> Source._Type ) OR ( _Type = vtString ) OR ( _Type = vtDate ) THEN
         LValue.String := String + Source.String;
      ELSE
         CASE _Type OF
         | vtBoolean :
            LValue.Boolean := Boolean OR Source.Boolean;
         | vtTristate :
            t1 := Tristate;
            t2 := Source.Tristate;
            IF ( t1 = -1 ) OR ( t2 = -1 ) THEN
               LValue.Tristate := -1;
            ELSIF ( t1 = 1 ) OR ( t2 = 1 ) THEN
               LValue.Tristate := 1;
            ELSE
               LValue.Tristate := 0;
            END;
         | vtInteger :
            i1 := Integer;
            i2 := i1 + Source.Integer;
            IF ( vfSaturate IN _Flags ) AND ( i2 < i1 ) THEN // overflow 
               LValue.Integer := MAX( INT32 );
            ELSE
               LValue.Integer := i2;
            END;
         | vtLong :
            l1 := Long;
            l2 := l1 + Source.Long;
            IF ( vfSaturate IN _Flags ) AND ( l2 < l1 ) THEN // overflow 
               LValue.Long := MAX( INT64 );
            ELSE
               LValue.Long := l2;
            END;
         | vtFloat :
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
      ELSIF ( _Type <> Source._Type ) OR ( _Type = vtString ) THEN
         LValue.Undefined := TRUE;
      ELSIF _Type = vtDate THEN
         LValue.Type := vtLong;
         LValue.Long := ( Date - Source.Date ) DIV time.unitsInMillisecond;
      ELSE
         CASE _Type OF
         | vtBoolean :
            LValue.Boolean := Boolean AND NOT Source.Boolean;
         | vtTristate :
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
         | vtInteger :
            i1 := Integer;
            i2 := i1 - Source.Integer;
            IF ( vfSaturate IN _Flags ) AND ( i2 > i1 ) THEN // overflow 
               LValue.Integer := MIN( INT32 );
            ELSE
               LValue.Integer := i2;
            END;
         | vtLong :
            l1 := Long;
            l2 := l1 - Source.Long;
            IF ( vfSaturate IN _Flags ) AND ( l2 > l1 ) THEN // overflow 
               LValue.Long := MIN( INT64 );
            ELSE
               LValue.Long := l2;
            END;
         | vtFloat :
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
      ELSIF ( _Type <> Source._Type ) OR ( _Type = vtString ) OR ( _Type = vtDate ) THEN
         LValue.Undefined := TRUE;
      ELSE
         CASE _Type OF
         | vtBoolean :
            LValue.Boolean := Boolean AND Source.Boolean;
         | vtTristate :
            t1 := Tristate;
            t2 := Source.Tristate;
            IF ( t1 = -1 ) OR ( t2 = -1 ) THEN
               LValue.Tristate := -1;
            ELSIF ( t1 = 0 ) OR ( t2 = 0 ) THEN
               LValue.Tristate := 0;
            ELSE
               LValue.Tristate := 1;
            END;
         | vtInteger :
            i1 := Integer;
            i2 := i1 * Source.Integer;
            // TODO saturation
            LValue.Integer := i2;
         | vtLong :
            l1 := Long;
            l2 := l1 * Source.Long;
            // TODO saturation
            LValue.Long := l2;
         | vtFloat :
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
      ELSIF ( _Type <> Source._Type ) OR ( _Type = vtString ) OR ( _Type = vtDate ) THEN
         LValue.Undefined := TRUE;
      ELSE
         CASE _Type OF
         | vtBoolean :
            LValue.Boolean := Boolean <> Source.Boolean;
         | vtTristate :
            t1 := Tristate;
            t2 := Source.Tristate;
            IF ( t1 = -1 ) OR ( t2 = -1 ) THEN
               LValue.Tristate := -1;
            ELSIF ( t1 = 0 ) = ( t2 = 0 ) THEN
               LValue.Tristate := 0;
            ELSE
               LValue.Tristate := 1;
            END;
         | vtInteger :
            i1 := Integer;
            i2 := Source.Integer;
            IF i2 = 0 THEN
               LValue.Undefined := TRUE;
            ELSE
               LValue.Integer := i1 DIV i2;
            END;
         | vtLong :
            l1 := Long;
            l2 := Source.Long;
            IF l2 = 0 THEN
               LValue.Undefined := TRUE;
            ELSE
               LValue.Long := l1 DIV l2;
            END;
         | vtFloat :
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
      IF _Type = vtString THEN
         DISPOSE( _Storage.String );
      END;
      _Flags := TFlags{};
      _Type := vtUnknown;
      _Storage.QW := 0;
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
      IF ( _Type = vtString ) OR ( Source._Type = vtString ) THEN
         RETURN String = Source.String;
      ELSE
         RETURN Float = Float;
      END;
   END Equals;

(*--------------------------------------------------------------------------------*)

   PUBLIC PROCEDURE EqualsS( CONST S : StringsO.IString ) : BOOLEAN;
   BEGIN
      IF _Type = vtString THEN
         RETURN PString^.Equals( S );
      ELSE
         RETURN String.Equals( S );
      END;
   END EqualsS;

(*--------------------------------------------------------------------------------*)

   PUBLIC PROCEDURE EqualsOA( CONST S : ARRAY OF WCHAR ) : BOOLEAN;
   BEGIN
      IF _Type = vtString THEN
         RETURN PString^.EqualsOA( S );
      ELSE
         RETURN String.EqualsOA( S );
      END;
   END EqualsOA;

(*--------------------------------------------------------------------------------*)

   PUBLIC PROCEDURE ToString( OUT String : StringsO.IString; TransportFlag : BOOLEAN );
   BEGIN
      IF _Type <> vtBoolean THEN
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
      IF _Type <> vtBoolean THEN
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
      | vtInteger :
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
            _Storage.Integer := _Storage.Integer MOD ih;
         ELSIF _Storage.Integer > ih THEN
            _Storage.Integer := ih;
         ELSIF _Storage.Integer < il THEN
            _Storage.Integer := il;
         END;
      | vtLong :
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
            _Storage.Long := _Storage.Long MOD lh;
         ELSIF _Storage.Long > lh THEN
            _Storage.Long := lh;
         ELSIF _Storage.Long < ll THEN
            _Storage.Long := ll;
         END;
      | vtFloat :
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
            _Storage.Float := _Storage.Float - fh * LONGREAL( INT64( _Storage.Float / fh ));
         ELSIF _Storage.Float > fh THEN
            _Storage.Float := fh;
         ELSIF _Storage.Float < fl THEN
            _Storage.Float := fl;
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
      LValue.Type := vtInteger;
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
      LValue.Type := vtLong;
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
      LValue.Type := vtFloat;
      LValue := SELF;
      LValue.Limit( Bits, Signed, Saturate );
      RETURN LValue.Float;
   END LimitedFloat;

(*--------------------------------------------------------------------------------*)

BEGIN
   _Flags := TFlags{};
   _Type := vtUnknown;
   _Storage.QW := 0;
FINALLY
   Dispose();
END Value;

(*================================================================================*)

END iovalue.