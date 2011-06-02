IMPLEMENTATION MODULE LogConfig;

FROM Storage IMPORT
   ALLOCATE, DEALLOCATE;
   
FROM Debug IMPORT
   Assertion, LogAssertionW;

IMPORT
   collection,
   lists,
   Log,
   StringsO;
   
(*================================================================================*)

PROCEDURE ReadFilterLine( REF filter : LogFilter.CLogFilter; CONST line : StringsO.IString ) : TConfigureLogResult;
BEGIN
   RETURN clfrUnknownPolicy;
END ReadFilterLine;

(*--------------------------------------------------------------------------------*)

PROCEDURE ConfigureLogBySection( CONST ini : INIFile.CINIFile; CONST SectionName : ARRAY OF WCHAR; REF _configured : iLog.IAppender; REF createdAppenderList : lists.CPtrPtrList; OUT errorLine : CARDINAL ) : TConfigureLogResult;
VAR
   AllowedBits : CARD64 := -1;
   Cached : CARDINAL;
   chainedAppender : Log.TPBaseAppender; // base appender
   configured : Log.TPBaseAppender;
   cs : StringsO.CString;
   EnumerateState : PTR;
   File : StringsO.CString;
   filter : iLog.TPIFilter;
   foundAppender : iLog.TPIAppender;
   haveAllowedBits : BOOLEAN := FALSE;
   haveCached : BOOLEAN := FALSE;
   haveFile : BOOLEAN := FALSE;
   haveLevel : BOOLEAN := FALSE;
   key : StringsO.CString;
   Level : Log.TLevel := Log.ldDebug;
   Levels : TRISTATE := -1;
   LocalTime : TRISTATE := -1;
   Names : TRISTATE := -1;
   Output : Log.TOutput := Log.outsNone;
   Result : TConfigureLogResult;
   TimeStamps : TRISTATE := -1;
BEGIN
   IF ( SectionName[0] = 0W ) OR NOT ini.SetSection( SectionName ) THEN
      RETURN clrUnknownSection;
   END;
   
   IF _configured INHERITS Log.CBaseAppender THEN
      configured := Log.TPAppender( ADR( _configured ));
      Level := configured^.Level;
   END;

   EnumerateState := 0;
   WHILE ini.EnumerateKeys( REF EnumerateState, OUT errorLine, OUT key, OUT cs ) DO

      // target, output
      IF key.EqualsOA( OAsz( Log.GetKeyword( Log.ckkTarget )) ) OR key.EqualsOA( OAsz( Log.GetKeyword( Log.ckkOutput )) ) THEN
         IF cs.EqualsOA( OAsz( Log.GetKeyword( Log.ckvFile )) ) THEN
            Output := Output + Log.outsFile;
         ELSIF cs.EqualsOA( OAsz( Log.GetKeyword( Log.ckvKernel )) ) THEN
            Output := Output + Log.outsKernel;
         ELSE
            IF NOT Log.GetAppender( OA( cs.Length-1, cs.Data ), OUT foundAppender ) THEN // appender does not exists, create and load new
               NEW( chainedAppender );
               Result := ConfigureLogBySection( ini, OA( cs.Length-1, cs.Data ), REF chainedAppender^, REF createdAppenderList, OUT errorLine );
               IF Result = clrSuccess THEN
                  createdAppenderList.Add( chainedAppender, 0 );
                  foundAppender := chainedAppender;
               ELSE
                  DISPOSE( chainedAppender );
                  RETURN Result;
               END;
            END;
            _configured.AddOutput( foundAppender );
         END;

      // file
      ELSIF key.EqualsOA( OAsz( Log.GetKeyword( Log.ckkFile )) ) THEN
         IF haveFile THEN
            RETURN clrKeyAlreadyKnown;
         END;
         haveFile := TRUE;
         File := cs;

      // level
      ELSIF key.EqualsOA( OAsz( Log.GetKeyword( Log.ckkLevel )) ) THEN
         IF haveLevel THEN
            RETURN clrKeyAlreadyKnown;
         END;
         IF cs.EqualsOA( OAsz( Log.GetKeyword( Log.ckvDebugFailure )) ) OR cs.EqualsOA( OAsz( Log.GetKeyword( Log.ckvFatal )) ) THEN
            Level := Log.ldError;
         ELSIF cs.EqualsOA( OAsz( Log.GetKeyword( Log.ckvDebugMessage )) ) OR cs.EqualsOA( OAsz( Log.GetKeyword( Log.ckvError )) ) THEN
            Level := Log.ldMessage;
         ELSIF cs.EqualsOA( OAsz( Log.GetKeyword( Log.ckvDebugTrace )) ) OR cs.EqualsOA( OAsz( Log.GetKeyword( Log.ckvWarning )) ) THEN
            Level := Log.ldTrace;
         ELSIF cs.EqualsOA( OAsz( Log.GetKeyword( Log.ckvDebugAll )) ) OR cs.EqualsOA( OAsz( Log.GetKeyword( Log.ckvInfo )) ) THEN
            Level := Log.ldDebug;
         ELSE
            RETURN clrUnknownLevel;
         END;
         haveLevel := TRUE;
         
      // filter
      ELSIF key.EqualsOA( OAsz( Log.GetKeyword( Log.ckkFilter )) ) THEN
         IF _configured INHERITS Log.CBaseAppender THEN
            filter := configured^.Filter;
            IF filter = NIL THEN
               NEW( LogFilter.TPLogFilter( filter ));
               configured^.Filter := filter;
            END;
            IF filter^ INHERITS LogFilter.CLogFilter THEN
               Result := ReadFilterLine( REF LogFilter.TPLogFilter( filter )^, cs );
               IF Result <> clrSuccess THEN
                  RETURN Result;
               END;
            END;
         END;

      // timestamps            
      ELSIF key.EqualsOA( OAsz( Log.GetKeyword( Log.ckkTimeStamps )) ) THEN
         IF TimeStamps <> -1 THEN
            RETURN clrKeyAlreadyKnown;
         END;
         cs.Lowerize();
         IF cs.EqualsOA( OAsz( Log.GetKeyword( Log.ckvTrue )) ) THEN
            TimeStamps := 1;
         ELSE
            TimeStamps := 0;
         END;

      // levels
      ELSIF key.EqualsOA( OAsz( Log.GetKeyword( Log.ckkLevels )) ) THEN
         IF Levels <> -1 THEN
            RETURN clrKeyAlreadyKnown;
         END;
         cs.Lowerize();
         IF cs.EqualsOA( OAsz( Log.GetKeyword( Log.ckvTrue )) ) THEN
            Levels := 1;
         ELSE
            Levels := 0;
         END;

      // names
      ELSIF key.EqualsOA( OAsz( Log.GetKeyword( Log.ckkNames )) ) THEN
         IF Names <> -1 THEN
            RETURN clrKeyAlreadyKnown;
         END;
         cs.Lowerize();
         IF cs.EqualsOA( OAsz( Log.GetKeyword( Log.ckvTrue )) ) THEN
            Names := 1;
         ELSE
            Names := 0;
         END;

      // localtime
      ELSIF key.EqualsOA( OAsz( Log.GetKeyword( Log.ckkLocalTime )) ) THEN
         IF LocalTime <> -1 THEN
            RETURN clrKeyAlreadyKnown;
         END;
         cs.Lowerize();
         IF cs.EqualsOA( OAsz( Log.GetKeyword( Log.ckvTrue )) ) THEN
            LocalTime := 1;
         ELSE
            LocalTime := 0;
         END;

      // allowedfilterdatabits
      ELSIF key.EqualsOA( OAsz( Log.GetKeyword( Log.ckkAllowedFilterBits )) ) THEN
         IF haveAllowedBits THEN
            RETURN clrKeyAlreadyKnown;
         END;
         IF NOT cs.ToCARD64( 16, OUT AllowedBits ) THEN
            RETURN clrBadAllowedBits;
         END;
         haveAllowedBits := TRUE;

      // cached
      ELSIF key.EqualsOA( OAsz( Log.GetKeyword( Log.ckkCached )) ) THEN
         IF haveCached THEN
            RETURN clrKeyAlreadyKnown;
         END;
         IF NOT cs.ToCARD32( 10, OUT Cached ) THEN
            RETURN clrBadCachedNumber;
         END;
         haveCached := TRUE;

      ELSE
         Log.logger()^.LogSS( Log.lcInfo, 0, EMITW( %class ), L"Unknown key:", OA( key.Length-1, key.Data ) );
      
      END;

   END; // WHILE

   IF _configured INHERITS Log.CBaseAppender THEN
      configured^.SetLogFile( OA( File.Length-1, File.Data ));
      IF Output <> Log.outsNone THEN
         configured^.Output := Output;
      END;
      IF haveLevel THEN
         configured^.Level := Level;
      END;
      IF haveAllowedBits THEN
         configured^.AllowedFilterDataBits := PTR( AllowedBits );
      END;
      IF TimeStamps <> -1 THEN
         configured^.TimeStamps := TimeStamps = 0;
      END;
      IF Levels <> -1 THEN
         configured^.Levels := Levels = 1;
      END;
      IF Names <> -1 THEN
         configured^.Names := Names = 1;
      END;
      IF LocalTime <> -1 THEN
         configured^.LocalTime := LocalTime = 1;
      END;
   END;
   IF _configured INHERITS Log.CBufferedLogger THEN
      Log.TPBufferedLogger( configured )^.BufferSize := Cached;
   END;
   
   RETURN clrSuccess;
END ConfigureLogBySection;

(*--------------------------------------------------------------------------------*)

PROCEDURE ConfigureLog( CONST ini : INIFile.CINIFile; CONST SectionName : ARRAY OF WCHAR; REF _appender : iLog.IAppender; REF createdAppenderList : lists.CPtrPtrList; OUT errorLine : CARDINAL ) : TConfigureLogResult;
VAR
   Result : TConfigureLogResult;
BEGIN
   IF ( SectionName[0] <> 0W ) AND ini.SetSection( SectionName ) THEN
      Result := ConfigureLogBySection( ini, SectionName, REF _appender, REF createdAppenderList, OUT errorLine );
   ELSIF ini.SetSection( OAsz( Log.GetKeyword( Log.cksLog ))) THEN
      Result := ConfigureLogBySection( ini, OAsz( Log.GetKeyword( Log.cksLog )), REF _appender, REF createdAppenderList, OUT errorLine );
   ELSE // no section found, but it is not a problem, because the configuration is optional
      RETURN clrSuccess;
   END;
   // ok, configuration found and read      
   IF Result <> clrSuccess THEN
      DisposeAppenderList( REF createdAppenderList );
   END;
   RETURN Result;
END ConfigureLog;

(*--------------------------------------------------------------------------------*)

PROCEDURE DisposeAppenderList( REF appenderList : lists.CPtrPtrList ); // to clear list returned by ConfigureLog
VAR
   appender : Log.TPBaseAppender;
   filter : iLog.TPIFilter;
   iterator : lists.CPtrPtrListIterator;
BEGIN
   iterator.Init( appenderList, collection.dirForward );
   WHILE iterator.MoveNext() DO
      appender := iterator.Value;
      ASSERT( appender^ IS Log.CBaseAppender );
      filter := appender^.Filter;
      IF filter <> NIL THEN
         ASSERT( filter^ INHERITS LogFilter.CLogFilter );
         DISPOSE( LogFilter.TPLogFilter( filter ));
      END;
      DISPOSE( appender );
   END; // WHILE
   appenderList.Dispose();
END DisposeAppenderList;

(*================================================================================*)

PROCEDURE ConfigureLogFilter( CONST ini : INIFile.CINIFile; CONST SectionName : ARRAY OF WCHAR; REF filter : LogFilter.CLogFilter; OUT errorLine : CARDINAL ) : TConfigureLogResult;
VAR
   AllowedBits : CARD64;
   cs : StringsO.CString;
   data : ARRAY [0..1] OF StringsO.CString;
   deny : BOOLEAN;
   es : PTR;
   key : StringsO.CString;
   pFilterKeyword : PWCHAR;
   pieces : CARDINAL;
   Result : TConfigureLogResult;
   value : StringsO.CString;
BEGIN
   filter.Reset();

   IF ( SectionName[0] <> 0W ) AND ini.SetSection( SectionName ) OR ini.SetSection( OAsz( Log.GetKeyword( Log.cksLog )) ) THEN

      // level
      IF ini.GetKeyStr( OAsz( Log.GetKeyword( Log.ckkLevel )), OUT errorLine, OUT cs ) THEN
         IF cs.EqualsOA( OAsz( Log.GetKeyword( Log.ckvDebugFailure )) ) OR cs.EqualsOA( OAsz( Log.GetKeyword( Log.ckvFatal )) ) THEN
            filter.Level := Log.ldError;
         ELSIF cs.EqualsOA( OAsz( Log.GetKeyword( Log.ckvDebugMessage )) ) OR cs.EqualsOA( OAsz( Log.GetKeyword( Log.ckvError )) ) THEN
            filter.Level := Log.ldMessage;
         ELSIF cs.EqualsOA( OAsz( Log.GetKeyword( Log.ckvDebugTrace )) ) OR cs.EqualsOA( OAsz( Log.GetKeyword( Log.ckvWarning )) ) THEN
            filter.Level := Log.ldTrace;
         ELSIF cs.EqualsOA( OAsz( Log.GetKeyword( Log.ckvDebugAll )) ) OR cs.EqualsOA( OAsz( Log.GetKeyword( Log.ckvInfo )) ) THEN
            filter.Level := Log.ldDebug;
         ELSE
            RETURN clrUnknownLevel;
         END;
      END;
         
      // allowedfilterdatabits
      IF ini.GetKeyStr( OAsz( Log.GetKeyword( Log.ckkAllowedFilterBits )), OUT errorLine, OUT cs ) THEN
         IF cs.ToCARD64( 16, OUT AllowedBits ) THEN
            filter.AllowedFilterDataBits := PTR( AllowedBits );
         ELSE
            RETURN clrBadAllowedBits;
         END;
      END;

      // filter
      pFilterKeyword := Log.GetKeyword( Log.ckkFilter );
      es := 0;
      WHILE ini.EnumerateKeys( REF es, OUT errorLine, OUT key, OUT value ) DO
         IF NOT key.EqualsOA( OAsz( pFilterKeyword )) THEN
            CONTINUE;
         END;

         Result := ReadFilterLine( REF filter, cs );
         IF Result <> clrSuccess THEN
            filter.Reset();
            RETURN Result;
         END;

(*
         value.SplitS( StringsO.WCHARS{L","}, 0, TRUE, OUT pieces, OUT data );
         IF pieces < 1 THEN
            RETURN clfrUnknownPolicy;
         ELSIF pieces < 2 THEN
            RETURN clfrMissingPattern;
         END;
         IF data[0].EqualsOA( kvDeny ) THEN
            deny := TRUE;
         ELSIF data[0].EqualsOA( kvAllow ) THEN
            deny := FALSE;
         ELSE
            RETURN clfrUnknownPolicy;
         END;

         data[1].Trim();
         filter.AddRule( NOT deny, deny, data[1] );
*)         

      END; // WHILE

   END; // IF section found
   
   RETURN clrSuccess;
END ConfigureLogFilter;

(*================================================================================*)

END LogConfig.
