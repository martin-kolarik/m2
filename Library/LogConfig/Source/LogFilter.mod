IMPLEMENTATION MODULE LogFilter;

IMPORT
   collection,
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
      iterator : lists.CStringListIterator;
   BEGIN
      IF SUPER.FilteredFullCheck( Level, FilterData, Logger, Prefix, Message ) THEN
         RETURN TRUE;
      END;

      iterator.Init( _Filter, collection.dirForward );   
      WHILE iterator.MoveNext() DO
         IF Strings.MatchW( Prefix, OA( iterator.Value^.Length-1, iterator.Value^.Data ), TRUE ) THEN
            filter := iterator.Data = DENY;
         END;
      END; // WHILE
      
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
