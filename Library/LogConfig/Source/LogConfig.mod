IMPLEMENTATION MODULE LogConfig;

IMPORT
   Log,
   StringsO;
   
(*================================================================================*)

PROCEDURE ConfigureLog( CONST ini : INIFile.CINIFile; CONST SectionName : ARRAY OF WCHAR; REF _appender : iLog.IAppender; OUT errorLine : CARDINAL ) : TConfigureLogResult;
VAR
   AllowedBits : CARD64;
   appender : Log.TPAppender;
   Cached : CARDINAL;
   cs : StringsO.CString;
   EnumerateState : PTR;
   File : StringsO.CString;
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
   TimeStamps : TRISTATE := -1;
BEGIN
   IF ( SectionName[0] <> 0W ) AND ini.SetSection( SectionName ) OR ini.SetSection( OAsz( Log.GetKeyword( Log.cksLog )) ) THEN
   
      IF _appender INHERITS Log.CBaseAppender THEN
         appender := Log.TPAppender( ADR( _appender ));
         Level := appender^.Level;
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
               RETURN clrSuccess; // TODO
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
            // OK, opaque for reading

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

   END;
   
   IF _appender INHERITS Log.CBaseAppender THEN
      appender^.SetLogFile( OA( File.Length-1, File.Data ));
      IF Output <> Log.outsNone THEN
         appender^.Output := Output;
      END;
      appender^.Level := Level;
      appender^.TimeStamps := TimeStamps = 1;
      appender^.Levels := Levels = 1;
      appender^.Names := Names = 1;
      appender^.LocalTime := LocalTime = 1;
   END;
   IF _appender INHERITS Log.CBufferedLogger THEN
      Log.TPBufferedLogger( appender )^.BufferSize := Cached;
   END;
   
   RETURN clrSuccess;
END ConfigureLog;

(*================================================================================*)

PROCEDURE ConfigureLogFilter( CONST ini : INIFile.CINIFile; CONST SectionName : ARRAY OF WCHAR; REF filter : LogFilter.CLogFilter; OUT errorLine : CARDINAL ) : TConfigureLoggerFilterResult;
VAR
   cs : StringsO.CString;
   data : ARRAY [0..1] OF StringsO.CString;
   deny : BOOLEAN;
   es : PTR;
   key : ARRAY [0..31] OF WCHAR;
   line : CARDINAL;
   pieces : CARDINAL;
   value : StringsO.CString;
BEGIN
(*
   filter.Reset();

   IF ( SectionName[0] <> 0W ) AND ini.SetSection( SectionName ) OR ini.SetSection( snLog ) THEN

      IF ini.GetKeyStr( knLevel, OUT errorLine, OUT cs ) THEN
         IF cs.EqualsOA( kvDebugFailure ) OR cs.EqualsOA( kvFatal ) THEN
            filter.Level := Log.dldError;
         ELSIF cs.EqualsOA( kvDebugMessage ) OR cs.EqualsOA( kvError ) THEN
            filter.Level := Log.dldMessage;
         ELSIF cs.EqualsOA( kvDebugTrace ) OR cs.EqualsOA( kvWarning ) THEN
            filter.Level := Log.dldTrace;
         ELSIF cs.EqualsOA( kvDebugAll ) OR cs.EqualsOA( kvInfo ) THEN
            filter.Level := Log.dldDebug;
         ELSE
            RETURN clfrUnknownLevel;
         END;
      END;
      
      es := 0;
      WHILE ini.EnumerateKeys( REF es, OUT line, OUT key, OUT value ) DO
         IF NOT EQUALS( key, knFilter ) THEN
            CONTINUE;
         END;

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
      END; // WHILE

   END;
*)   
   
   RETURN clfrSuccess;
END ConfigureLogFilter;

(*================================================================================*)

END LogConfig.
