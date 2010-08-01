IMPLEMENTATION MODULE LogFilter;

IMPORT
   Strings;

(*===========================================================================*)

CONST
   ALLOW = 0;
   DENY = 1;

(*===========================================================================*)

CLASS IMPLEMENTATION CLogFilter;

(*---------------------------------------------------------------------------*)

   PUBLIC VIRTUAL PROCEDURE FilteredFullCheck( Level : iLog.TLevel; FilterData : PTR; CONST Logger, Prefix, Message : ARRAY OF WCHAR ) : BOOLEAN;
   VAR
      filter : BOOLEAN := FALSE;
      _List : lists.CStringList;
   BEGIN
      IF SUPER.FilteredFullCheck( Level, FilterData, Logger, Prefix, Message ) THEN
         RETURN TRUE;
      END;
   
      _List := _Filter;
      _List.Reset();
      WHILE _List.MoveNext() DO
         IF Strings.MatchW( Prefix, OA( _List.Current^.Length-1, _List.Current^.Data ), TRUE ) THEN
            filter := _List.CurrentData = DENY;
         END;
      END; // WHILE
      _List.Clear(); // do not dispose, _List is a enumerator copy
      
      RETURN filter;
   END FilteredFullCheck;

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

END CLogFilter;

(*===========================================================================*)

END LogFilter.
