IMPLEMENTATION MODULE LoggerFilter;

IMPORT
   Strings;

(*===========================================================================*)

CONST
   ALLOW = 0;
   DENY = 1;

(*===========================================================================*)

CLASS IMPLEMENTATION CLoggerFilter;

(*---------------------------------------------------------------------------*)

   PUBLIC VIRTUAL PROCEDURE Filtered( Level : iLog.TDebugLevel; CONST Prefix : ARRAY OF WCHAR ) : BOOLEAN;
   VAR
      filter : BOOLEAN := FALSE;
      _List : lists.CStringList;
   BEGIN
      IF Level > _Level THEN
         RETURN TRUE;
      END;
   
      _List := _Filter;
      _List.Reset();
      WHILE _List.MoveNext() DO
         IF Strings.MatchW( Prefix, OA( _List.Current^.Length-1, _List.Current^.rawData ), TRUE ) THEN
            filter := _List.CurrentData = DENY;
         END;
      END; // WHILE
      _List.Clear();
      
      RETURN filter;
   END Filtered;

(*---------------------------------------------------------------------------*)

   PUBLIC PROCEDURE Reset();
   BEGIN
      _Filter.Dispose();
   END Reset;

(*---------------------------------------------------------------------------*)

   PUBLIC PROCEDURE AddRule( Allow, Deny : BOOLEAN; CONST Pattern : StringsO.IString ); // if allow/deny conflicts, deny wins
   BEGIN
      IF Deny OR ( Allow = Deny ) THEN
         _Filter.Add( Pattern, DENY );
      ELSE
         _Filter.Add( Pattern, ALLOW );
      END;
   END AddRule;
   
(*---------------------------------------------------------------------------*)

   PUBLIC PROPERTY Level GET : log.TDebugLevel;
   BEGIN
      RETURN _Level;
   END Level;

(*---------------------------------------------------------------------------*)

   PUBLIC PROPERTY Level SET( Value : log.TDebugLevel );
   BEGIN
      _Level := Value;
   END Level;

(*---------------------------------------------------------------------------*)

BEGIN
   #if DEBUG #then
      _Level := log.dldTrace;
   #else
      _Level := log.dldMessage;
   #endif
END CLoggerFilter;

(*===========================================================================*)

END LoggerFilter.