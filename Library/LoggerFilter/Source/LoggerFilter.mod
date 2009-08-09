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

   PUBLIC VIRTUAL PROCEDURE Filtered( Level : iLog.TDebugLevel ) : BOOLEAN;
   BEGIN
      IF _Logger = NIL THEN
         RETURN TRUE;
      ELSE
         RETURN _Logger^.Filtered( Level );
      END;
   END Filtered;

(*---------------------------------------------------------------------------*)

   PUBLIC VIRTUAL PROCEDURE LogS( Level : iLog.TDebugLevel; Prefix, S : ARRAY OF WCHAR );
   BEGIN
      IF Filtered( Level ) OR FilteredByRule( Prefix ) THEN
         RETURN;
      ELSE
         _Logger^.LogS( Level, Prefix, S );
      END;
   END LogS;

(*---------------------------------------------------------------------------*)

   PUBLIC VIRTUAL PROCEDURE LogSS( Level : iLog.TDebugLevel; Prefix, S1, S2 : ARRAY OF WCHAR );
   BEGIN
      IF Filtered( Level ) OR FilteredByRule( Prefix ) THEN
         RETURN;
      ELSE
         _Logger^.LogSS( Level, Prefix, S1, S2 );
      END;
   END LogSS;

(*---------------------------------------------------------------------------*)

   PUBLIC VIRTUAL PROCEDURE LogSSC( Level : iLog.TDebugLevel; Prefix, S1, S2 : ARRAY OF WCHAR; C : CARDINAL );
   BEGIN
      IF Filtered( Level ) OR FilteredByRule( Prefix ) THEN
         RETURN;
      ELSE
         _Logger^.LogSSC( Level, Prefix, S1, S2, C );
      END;
   END LogSSC;

(*---------------------------------------------------------------------------*)

   PUBLIC VIRTUAL PROCEDURE LogSC( Level : iLog.TDebugLevel; Prefix, S1 : ARRAY OF WCHAR; C : CARDINAL );
   BEGIN
      IF Filtered( Level ) OR FilteredByRule( Prefix ) THEN
         RETURN;
      ELSE
         _Logger^.LogSC( Level, Prefix, S1, C );
      END;
   END LogSC;

(*---------------------------------------------------------------------------*)

   PUBLIC VIRTUAL PROCEDURE LogSCC( Level : iLog.TDebugLevel; Prefix, S1 : ARRAY OF WCHAR; C1, C2 : CARDINAL );
   BEGIN
      IF Filtered( Level ) OR FilteredByRule( Prefix ) THEN
         RETURN;
      ELSE
         _Logger^.LogSCC( Level, Prefix, S1, C1, C2 );
      END;
   END LogSCC;

(*---------------------------------------------------------------------------*)

   PUBLIC VIRTUAL PROCEDURE LogSH( Level : iLog.TDebugLevel; Prefix, S1 : ARRAY OF WCHAR; H : CARDINAL );
   BEGIN
      IF Filtered( Level ) OR FilteredByRule( Prefix ) THEN
         RETURN;
      ELSE
         _Logger^.LogSH( Level, Prefix, S1, H );
      END;
   END LogSH;

(*---------------------------------------------------------------------------*)

   PUBLIC VIRTUAL PROCEDURE LogSP( Level : iLog.TDebugLevel; Prefix, S1 : ARRAY OF WCHAR; P : PTR );
   BEGIN
      IF Filtered( Level ) OR FilteredByRule( Prefix ) THEN
         RETURN;
      ELSE
         _Logger^.LogSP( Level, Prefix, S1, P );
      END;
   END LogSP;

(*---------------------------------------------------------------------------*)

   PUBLIC VIRTUAL PROCEDURE LogSCP( Level : iLog.TDebugLevel; Prefix, S1 : ARRAY OF WCHAR; C : CARDINAL; P : PTR );
   BEGIN
      IF Filtered( Level ) OR FilteredByRule( Prefix ) THEN
         RETURN;
      ELSE
         _Logger^.LogSCP( Level, Prefix, S1, C, P );
      END;
   END LogSCP;

(*---------------------------------------------------------------------------*)

   PUBLIC VIRTUAL PROCEDURE LogSHP( Level : iLog.TDebugLevel; Prefix, S1 : ARRAY OF WCHAR; H : CARDINAL; P : PTR );
   BEGIN
      IF Filtered( Level ) OR FilteredByRule( Prefix ) THEN
         RETURN;
      ELSE
         _Logger^.LogSHP( Level, Prefix, S1, H, P );
      END;
   END LogSHP;

(*---------------------------------------------------------------------------*)

   PUBLIC VIRTUAL PROCEDURE LogSB( Level : iLog.TDebugLevel; Prefix, S1 : ARRAY OF WCHAR; A : ADDRESS; Bytes : CARDINAL );
   BEGIN
      IF Filtered( Level ) OR FilteredByRule( Prefix ) THEN
         RETURN;
      ELSE
         _Logger^.LogSB( Level, Prefix, S1, A, Bytes );
      END;
   END LogSB;

(*---------------------------------------------------------------------------*)

   PUBLIC VIRTUAL PROCEDURE LogSCB( Level : iLog.TDebugLevel; Prefix, S1 : ARRAY OF WCHAR; C : CARDINAL; A : ADDRESS; Bytes : CARDINAL );
   BEGIN
      IF Filtered( Level ) OR FilteredByRule( Prefix ) THEN
         RETURN;
      ELSE
         _Logger^.LogSCB( Level, Prefix, S1, C, A, Bytes );
      END;
   END LogSCB;

(*---------------------------------------------------------------------------*)

   PUBLIC VIRTUAL PROCEDURE LogSSS( Level : iLog.TDebugLevel; Prefix, S1, S2, S3 : ARRAY OF WCHAR );
   BEGIN
      IF Filtered( Level ) OR FilteredByRule( Prefix ) THEN
         RETURN;
      ELSE
         _Logger^.LogSSS( Level, Prefix, S1, S2, S3 );
      END;
   END LogSSS;

(*---------------------------------------------------------------------------*)

   PUBLIC VIRTUAL PROCEDURE LogSSSS( Level : iLog.TDebugLevel; Prefix, S1, S2, S3, S4 : ARRAY OF WCHAR );
   BEGIN
      IF Filtered( Level ) OR FilteredByRule( Prefix ) THEN
         RETURN;
      ELSE
         _Logger^.LogSSSS( Level, Prefix, S1, S2, S3, S4 );
      END;
   END LogSSSS;
  
(*---------------------------------------------------------------------------*)

   PUBLIC VIRTUAL PROCEDURE LogSE( Level : iLog.TDebugLevel; Prefix, S1 : ARRAY OF WCHAR; ErrorCode : CARDINAL );
   BEGIN
      IF Filtered( Level ) OR FilteredByRule( Prefix ) THEN
         RETURN;
      ELSE
         _Logger^.LogSE( Level, Prefix, S1, ErrorCode );
      END;
   END LogSE;

(*---------------------------------------------------------------------------*)

   PUBLIC VIRTUAL PROCEDURE LogSR( Level : iLog.TDebugLevel; Prefix, S1 : ARRAY OF WCHAR; Result : Sync.TAsyncResult );
   BEGIN
      IF Filtered( Level ) OR FilteredByRule( Prefix ) THEN
         RETURN;
      ELSE
         _Logger^.LogSR( Level, Prefix, S1, Result );
      END;
   END LogSR;

(*---------------------------------------------------------------------------*)

   PUBLIC VIRTUAL PROCEDURE LogExc( Level : iLog.TDebugLevel; Prefix : ARRAY OF WCHAR; CONST e : Exceptions.CException );
   BEGIN
      IF Filtered( Level ) OR FilteredByRule( Prefix ) THEN
         RETURN;
      ELSE
         _Logger^.LogExc( Level, Prefix, e );
      END;
   END LogExc;

(*---------------------------------------------------------------------------*)

   PUBLIC VIRTUAL PROCEDURE LogFilePos( Level : iLog.TDebugLevel; Prefix : ARRAY OF WCHAR; Path, S1 : ARRAY OF WCHAR; Line, Col : CARDINAL ); // Line, Col = 0/-1 means unused, unknown
   BEGIN
      IF Filtered( Level ) OR FilteredByRule( Prefix ) THEN
         RETURN;
      ELSE
         _Logger^.LogFilePos( Level, Prefix, Path, S1, Line, Col );
      END;
   END LogFilePos;

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

   PUBLIC PROPERTY Output GET : log.TPALogger;
   BEGIN
      RETURN _Logger;
   END Output;
   
(*---------------------------------------------------------------------------*)

   PUBLIC PROPERTY Output SET( Value : log.TPALogger );
   BEGIN
      _Logger := Value;
   END Output;
   
(*---------------------------------------------------------------------------*)

   PRIVATE PROCEDURE FilteredByRule( CONST Prefix : ARRAY OF WCHAR ) : BOOLEAN;
   VAR
      allow : BOOLEAN := TRUE;
      _List : lists.CStringList;
   BEGIN
      IF _Logger = NIL THEN
         RETURN TRUE;
      END;
      
      _List := _Filter;
      _List.Reset();
      WHILE _List.MoveNext() DO
         IF Strings.MatchW( Prefix, OA( _List.Current^.Length-1, _List.Current^.rawData ), TRUE ) THEN
            allow := _List.CurrentData = ALLOW;
         END;
      END; // WHILE
      _List.Clear();
      
      RETURN allow;
   END FilteredByRule;

(*---------------------------------------------------------------------------*)

BEGIN
   _Logger := NIL;
END CLoggerFilter;

(*===========================================================================*)

END LoggerFilter.