IMPLEMENTATION MODULE WeekCalendar;

(*================================================================================*)

FROM Debug IMPORT
   AssertionW;

IMPORT
   datetime,
   device,
   FIO,
   Folders,
   IOO,
   iovalue,
   INIFile,
   maps,
   ns,
   Texts;

(*================================================================================*)

CLASS CItem;

   LOCAL PROCEDURE Initialize( CONST LastPassedWeekStart : datetime.DateTime; DayOfWeek, Hour, Minute : CARDINAL ); // DayOfWeek 0 = Sunday
   LOCAL PROCEDURE ShouldTick( CONST Now : datetime.DateTime ) : BOOLEAN;
   LOCAL PROCEDURE ToString() : StringsO.CString; // for debugging purposes, returns next tick time

   LOCAL VAR
      Address : StringsO.CString;
      Hash : ns.THash := ns.hashINVALID;
      Condition : BOOLEAN := TRUE;
      ConditionHash : ns.THash := ns.hashINVALID;
      Value : iovalue.Value;
      ShouldTickAt : datetime.DateTime;

END CItem;

(*--------------------------------------------------------------------------------*)

CLASS IMPLEMENTATION CItem;

(*-------------------------------------------------------------------------------*)

   LOCAL PROCEDURE Initialize( CONST LastPassedWeekStart : datetime.DateTime; DayOfWeek, Hour, Minute : CARDINAL );
   VAR
      ms : CARDINAL;
   BEGIN
      ShouldTickAt := LastPassedWeekStart;
      CASE DayOfWeek OF
      | 0 : ms := 6 * 86400;
      | 1 : ms := 0 * 86400;
      | 2 : ms := 1 * 86400;
      | 3 : ms := 2 * 86400;
      | 4 : ms := 3 * 86400;
      | 5 : ms := 4 * 86400;
      | 6 : ms := 5 * 86400;
      END; // CASE
      ShouldTickAt.Add( datetime.MSToJDC( 1000 * INC( ms, Hour * 3600 + Minute * 60 )));
   END Initialize;

(*-------------------------------------------------------------------------------*)

   LOCAL PROCEDURE ShouldTick( CONST Now : datetime.DateTime ) : BOOLEAN;
   BEGIN
      IF ShouldTickAt > Now THEN
         RETURN FALSE;
      END;

      ShouldTickAt.Add( datetime.DaysToJDC( 7 )); // move forward is done always, notwithstanding the condition

      RETURN Condition;
   END ShouldTick;

(*-------------------------------------------------------------------------------*)

   LOCAL PROCEDURE ToString() : StringsO.CString; // for debugging purposes
   VAR
      cs : StringsO.CString;
      s : ARRAY [0..15] OF WCHAR;
   BEGIN
      IF ShouldTickAt.ToStringOA( L"ddd, HH:mm", TRUE, TRUE, OUT s ) THEN
         cs.FromOA( s );
      ELSE
         cs.FromOA( L"<invalid_date>" );
      END;
      RETURN cs;
   END ToString;

(*-------------------------------------------------------------------------------*)

BEGIN
END CItem;

(*================================================================================*)

CONST
   LOGNAME = L"WeekCalendar";
   CALENDAR_PERIOD = 20000; // 20 second
   MSG_WRITE = msghandler.MSG_BASE;
   CFG_SECTION = L"week_calendar";

CLASS IMPLEMENTATION CWeekCalendarFunction;

(*--------------------------------------------------------------------------------*)

   INTERNAL VIRTUAL PROCEDURE OnMessage( CONST Message : msghandler.IMessage; OUT Result : PTR ) : BOOLEAN;
   BEGIN
      IF SUPER.OnMessage( Message, OUT Result ) THEN
         RETURN TRUE;

      ELSIF Message.Message = MSG_WRITE THEN
         Write();
         RETURN TRUE;
      
      ELSE
         RETURN FALSE;
      END;
   END OnMessage;

(*--------------------------------------------------------------------------------*)

   PUBLIC VIRTUAL PROCEDURE OnAdvise( Source : io.TPIO; CONST Result : ARRAY OF Sync.TAsyncResult; CONST Item : ARRAY OF ns.THash; CONST Value : ARRAY OF iovalue.Value );
   VAR
      item : TPItem;
      i : CARDINAL;
   BEGIN
      // check validity of input
      IF HIGH( Item ) < 0 THEN
         RETURN;
      END;
      
      // look for items and check if operation finished sucessfully
      FOR i := 0 TO HIGH( Item ) DO
         IF Result[i] IN Sync.arsCompletions THEN
            
            _Items.Reset();
            WHILE _Items.MoveNext() DO
               item := _Items.Current;
               IF item^.ConditionHash = Item[i] THEN
                  item^.Condition := Value[i].Boolean;
                  Reanalyze( item );
               END;
            END; // WHILE
            
         END;
      END;
   END OnAdvise;

(*--------------------------------------------------------------------------------*)

   LOCAL VIRTUAL PROCEDURE OnTimeout( Result : Sync.TAsyncResult; PoolHandle : threadpool.TPoolHandle; UserId : PTR );
   BEGIN
      IF PoolHandle = _CalendarPeriod THEN
         EvaluateItems();
      END;
   END OnTimeout;

(*--------------------------------------------------------------------------------*)

   PUBLIC VIRTUAL PROCEDURE Configure( CONST Source : ARRAY OF device.TConfigureItem; CONST Log : log.TPLogger ) : Sync.TAsyncResult;
   TYPE
      Day = ( Sunday, Monday, Tuesday, Wednesday, Thursday, Friday, Saturday );
      Days = SET OF Day;
   VAR
      condition : StringsO.CString;
      conditionFound : BOOLEAN;
      conditionHash : ns.THash;
      day : Day;
      days : Days;
      dt : datetime.DateTime;
      ES : PTR;
      hash : ns.THash;
      i : CARDINAL;
      iniFile : INIFile.TPINIFile;
      item : TPItem;
      key : StringsO.CString;
      Line : CARDINAL;
      pieces : CARDINAL;
      section : StringsO.CString;
      valueTime : ARRAY [0..15] OF WCHAR;
      value : StringsO.CString;
      values : ARRAY [0..11] OF StringsO.CString;
      weekStart : datetime.DateTime;
   BEGIN
      IF Device = NIL THEN
	      Log^.LogS( log.lcError, 0, LOGNAME, OAsz( R^[ Texts._DeviceIsNotInitialized ] ));
         RETURN Sync.arCannotStart;
      
      ELSIF HIGH( Source ) < 0 THEN
	      Log^.LogS( log.lcError, 0, LOGNAME, OAsz( R^[ Texts._BadParameterMissingSourceOfConfiguration ] ));
         RETURN Sync.arCannotStart;

      ELSIF Source[0].Type = device.citINIFile THEN
         iniFile := Source[0].iniFile;
         section.FromOA( CFG_SECTION ); // load default section

      ELSIF Source[0].Type = device.citINIFileSection THEN
         iniFile := Source[0].iniFile;
         section.Assign( Source[0].section^ ); // load ordered section

      ELSE
	      Log^.LogS( log.lcError, 0, LOGNAME, OAsz( R^[ Texts._UnsupportedSourceOfConfiguration ] ));
         RETURN Sync.arCannotStart;
      END;

      IF NOT iniFile^.SetSection( OA( section.Length-1, section.Data )) THEN
	      Log^.LogSS( log.lcInfo, 0, LOGNAME, OAsz( R^[ Texts._ConfigurationSectionNotFound ] ), OA( section.Length-1, section.Data ));
         RETURN Sync.arCompleted;
      END;
      // here the inifile has proper section set

      // compute value which will be reused more times      
      weekStart := DetermineLastPassedWeekStart();

      ES := 0;
      WHILE iniFile^.EnumerateKeys( REF ES, OUT Line, OUT key, OUT value ) DO

         // key/output = value, hh:mm [, days]
         IF NOT SplitOutputAndCondition( key, OUT key, OUT conditionFound, OUT condition ) THEN
            Log^.LogSS( log.lcError, 0, LOGNAME, OAsz( R^[ Texts._IncorrectOutputConditionFormat ] ), OA( key.Length-1, key.Data ));
            CONTINUE;
         ELSIF NOT Device^.NS()^.Get( key, OUT hash ) THEN
	         Log^.LogSS( log.lcError, 0, LOGNAME, OAsz( R^[ Texts._OutputGroupAddressNotFound ] ), OA( key.Length-1, key.Data ));
            CONTINUE;
         ELSIF conditionFound AND NOT Device^.NS()^.Get( condition, OUT conditionHash ) THEN
	         Log^.LogSS( log.lcError, 0, LOGNAME, OAsz( R^[ Texts._ConditionGroupAddressNotFound ] ), OA( key.Length-1, key.Data ));
            CONTINUE;
         END;
         
         value.SplitS( StringsO.WCHARS{L","}, 0, FALSE, OUT pieces, OUT values );
         FOR i := 0 TO pieces-1 DO
            values[i].Trim();
         END; // FOR
         
         // check mandatory parameters (value, time)
         IF pieces < 2 THEN
	         Log^.LogS( log.lcError, 0, LOGNAME, OAsz( R^[ Texts._InputValuesAreMissing ] ));
            CONTINUE;
         END;

         values[1].ToOA( OUT valueTime );
         IF NOT dt.FromStringOA( valueTime, L"H:mm" ) AND
            NOT dt.FromStringOA( valueTime, L"HH:mm" ) AND
            NOT dt.FromStringOA( valueTime, L"H:m" ) AND
            NOT dt.FromStringOA( valueTime, L"HH:m" ) THEN
            Log^.LogSS( log.lcError, 0, LOGNAME, OAsz( R^[ Texts._IncorrectTimeFormat ] ), OA( values[1].Length-1, values[1].Data ));
            CONTINUE;
         END;
         
         // read optional parameters (days)
         IF pieces = 2 THEN // no days, create item for each day
            days := Days{ Monday, Sunday, Tuesday, Wednesday, Thursday, Friday, Saturday, Sunday };

         ELSE // analyze items
            days := Days{};
            FOR i := 2 TO pieces-1 DO
               values[i].Lowerize();
               IF values[i].StartsWithOA( L"m" ) THEN
                  days := days + Days{ Monday };
               ELSIF values[i].StartsWithOA( L"tu" ) THEN
                  days := days + Days{ Tuesday };
               ELSIF values[i].StartsWithOA( L"wed" ) THEN
                  days := days + Days{ Wednesday };
               ELSIF values[i].StartsWithOA( L"th" ) THEN
                  days := days + Days{ Thursday };
               ELSIF values[i].StartsWithOA( L"f" ) THEN
                  days := days + Days{ Friday };
               ELSIF values[i].StartsWithOA( L"sa" ) THEN
                  days := days + Days{ Saturday };
               ELSIF values[i].StartsWithOA( L"su" ) THEN
                  days := days + Days{ Sunday };
               ELSIF values[i].StartsWithOA( L"wee" ) THEN // weekend
                  days := days + Days{ Saturday, Sunday };
               ELSIF values[i].StartsWithOA( L"wo" ) THEN // work
                  days := days + Days{ Monday, Tuesday, Wednesday, Thursday, Friday };
               ELSE // error
                  Log^.LogSS( log.lcError, 0, LOGNAME, OAsz( R^[ Texts._IncorrectDaySpecification ] ), OA( values[i].Length-1, values[i].Data ));
               END; // what has been found
            END; // FOR

         END; // IF analyze items

         FOR day := Sunday TO Saturday DO
            IF day IN days THEN
               NEW( item );
               item^.Initialize( weekStart, CARDINAL( day ), dt.Hour, dt.Minute );
               item^.Address := key;
               item^.Hash := hash;
               item^.Value.String := values[0];
               IF conditionFound THEN
                  item^.ConditionHash := conditionHash;
               END;
               _Items.Add( item, 0 );
            END;
         END;

      END; // WHILE line/key

      RETURN Sync.arCompleted;
   END Configure; 
   
(*--------------------------------------------------------------------------------*)

   PUBLIC VIRTUAL PROCEDURE Dispose();
   VAR
      item : TPItem;
   BEGIN
      StopTimeout( REF _CalendarPeriod );

      IF Device <> NIL THEN
         Device^.UnadviseAll( ADR( SELF ));
      END;
   
      _Items.Reset();
      WHILE _Items.MoveNext() DO
         item := _Items.Current;
         DISPOSE( item );
      END; // WHILE
      _Items.Dispose();
   END Dispose;

(*--------------------------------------------------------------------------------*)

   INTERNAL VIRTUAL PROCEDURE OnStart();
   VAR
      conditionValue : iovalue.Value;
      item, furthest : TPItem;
      now : datetime.DateTime := datetime.NowLocal();
      outputs : maps.CPtrMap;
      result : Sync.TAsyncResult;
   BEGIN
      // move all expired items to the future and simultaneously initialize Condition
      _Items.Reset();
      WHILE _Items.MoveNext() DO
         item := _Items.Current;
         item^.ShouldTick( now );

         // first evaluate condition
         IF item^.ConditionHash <> ns.hashINVALID THEN
            result := Device^.IO()^.IOh( ADR( SELF ), IOO.dirRead, item^.ConditionHash, REF conditionValue, NIL );
            IF result NOT IN Sync.arsCompletions THEN // log error
	            Logger^.LogSS( log.lcError, 0, LOGNAME, L"Unable to read condition value:", OA( item^.Address.Length-1, item^.Address.Data ));
	            Logger^.LogSR( log.lcInfo, 0, LOGNAME, L"    result", result );
               CONTINUE;
            END;
            item^.Condition := conditionValue.Boolean;
         END;
      END; // WHILE

      // construct map from items to look for the furthest item -- the furthest item is in the same time the last ticket, value of which shall be sent to KNX
      _Items.Reset();
      WHILE _Items.MoveNext() DO
         item := _Items.Current;
         IF NOT outputs.Contains( item^.Hash ) THEN
            outputs.Add( item^.Hash, 0 );
         END;
      END; // WHILE

      // for each item store the furthest time in the map
      _Items.Reset();
      WHILE _Items.MoveNext() DO
         item := _Items.Current;
         outputs.Get( item^.Hash, OUT furthest );
         IF furthest = NIL THEN
            furthest := item;
         ELSIF furthest^.ShouldTickAt >= item^.ShouldTickAt THEN
            CONTINUE;
         ELSIF NOT item^.Condition THEN
            CONTINUE;
         END;
         // take new furthest item
         furthest := item;
         outputs.Remove( item^.Hash ); // slow!!, but there is no way how to change DATA of some item in the map
         outputs.Add( item^.Hash, furthest );
      END; // WHILE

      // emit current values from outputs
      outputs.Reset();
      WHILE outputs.MoveNext() DO
         furthest := outputs.CurrentData;
         Enqueue( furthest );
      END; // WHILE

      _PoolDelegate.TimeoutSink := ADR( SELF );
      StartTimeout( CALENDAR_PERIOD, FALSE, REF _CalendarPeriod );

      // register advises from condition addresses
      Device^.JoinClient( ADR( SELF ), io.advWithData );
      
      _Items.Reset();
      WHILE _Items.MoveNext() DO
         item := _Items.Current;
         IF item^.ConditionHash <> ns.hashINVALID THEN
            Device^.AdviseHash( ADR( SELF ), item^.ConditionHash );
         END;
      END; // WHILE
   END OnStart;

(*--------------------------------------------------------------------------------*)

   INTERNAL VIRTUAL PROCEDURE OnStop();
   BEGIN
      _PoolDelegate.TimeoutSink := NIL;
      StopTimeout( REF _CalendarPeriod );

      Device^.UnadviseAll( ADR( SELF ));
      Device^.LeaveClient( ADR( SELF ));
   END OnStop;
   
(*--------------------------------------------------------------------------------*)

   PRIVATE PROCEDURE EvaluateItems();
   VAR
      item : TPItem;
      now : datetime.DateTime := datetime.NowLocal();
   BEGIN
      _Items.Reset();
      WHILE _Items.MoveNext() DO
         item := _Items.Current;
         IF item^.ShouldTick( now ) THEN
            Enqueue( item );
         END;
      END; // WHILE
   END EvaluateItems;

(*--------------------------------------------------------------------------------*)

   PRIVATE PROCEDURE Enqueue( item : TPItem );
   VAR
      s : StringsO.CString;
   BEGIN
      s := item^.ToString();
      Logger^.LogSSSS( log.lcInfo, 0, LOGNAME, L"Marking item for write:", OA( item^.Address.Length-1, item^.Address.Data ), L"at", OA( s.Length-1, s.Data ));

      _WriteQueue.Enqueue( item );
   END Enqueue;

(*--------------------------------------------------------------------------------*)

   PRIVATE PROCEDURE Write();
   VAR
      item : TPItem;
      result : Sync.TAsyncResult;
      value : StringsO.CString;
   BEGIN
      WHILE _WriteQueue.Dequeue( OUT item ) DO

         result := Device^.IO()^.IOh( ADR( SELF ), IOO.dirWrite, item^.Hash, REF item^.Value, NIL );
         IF result NOT IN Sync.arsCompletions THEN // log error
	         Logger^.LogSS( log.lcError, 0, LOGNAME, L"Unable to write value to device:", OA( item^.Address.Length-1, item^.Address.Data ));
	         Logger^.LogSR( log.lcInfo, 0, LOGNAME, L"    result", result );
            CONTINUE;
         END;

         value := item^.Value.String;
         Logger^.LogSSSS( log.lcInfo, 0, LOGNAME, L"Value written:", OA( item^.Address.Length-1, item^.Address.Data ), L"=", OA( value.Length-1, value.Data ));
      END; // _WriteQueue
   END Write;

(*--------------------------------------------------------------------------------*)

   PRIVATE PROCEDURE Reanalyze( analyzedItem : TPItem );
   // look for last previous item, the item keeps value which should be set to KNX just now
   VAR
      furthest : TPItem := NIL;
      item : TPItem;
   BEGIN
      // for each item store the furthest time in the map
      _Items.Reset();
      WHILE _Items.MoveNext() DO
         item := _Items.Current;
         IF item^.Hash <> analyzedItem^.Hash THEN
            CONTINUE;
         END;

         IF furthest = NIL THEN
            furthest := item;
         ELSIF furthest^.ShouldTickAt >= item^.ShouldTickAt THEN
            CONTINUE;
         ELSIF NOT item^.Condition THEN
            CONTINUE;
         END;

         // take new furthest item
         furthest := item;
      END; // WHILE

      IF furthest <> NIL THEN
         Enqueue( furthest );
      END; // WHILE
   END Reanalyze;

(*--------------------------------------------------------------------------------*)

   PRIVATE PROCEDURE DetermineLastPassedWeekStart() : datetime.DateTime;
   VAR
      dt : datetime.DateTime := datetime.NowLocal();
   BEGIN
      dt.Subtract( datetime.DaysToJDC(( dt.DayOfWeek + 6 ) MOD 7 ));
      dt.TrimTime();
      RETURN dt;
   END DetermineLastPassedWeekStart;

(*--------------------------------------------------------------------------------*)

   PRIVATE PROCEDURE StartTimeout( TimeoutMS : CARDINAL; WaitOnce : BOOLEAN; REF Handle : threadpool.TPoolHandle );
   BEGIN
      ASSERTLOG( Handle = NIL );
      threadpool.pool()^.WaitTimeout( ADR( _PoolDelegate ), 0, TimeoutMS, WaitOnce, FALSE, OUT Handle );
   END StartTimeout;

(*--------------------------------------------------------------------------------*)

   PRIVATE PROCEDURE StopTimeout( REF Handle : threadpool.TPoolHandle );
   BEGIN
      IF Handle = NIL THEN
         RETURN;
      END;
      threadpool.pool()^.Abort( REF Handle );
   END StopTimeout;

(*--------------------------------------------------------------------------------*)

   INITIALLY CWeekCalendarFunction();
   VAR
      msg : msghandler.Message;
   BEGIN
      DescriptionSet := StringsO.FromOA( L"Week calendar" );

      msg.Message := MSG_WRITE;
      _WriteQueue.ConsumerMsg := ADR( msg );
      _WriteQueue.Consumer := ADR( SELF );
   END CWeekCalendarFunction;

(*--------------------------------------------------------------------------------*)

   FINALLY CWeekCalendarFunction();
   BEGIN
      Dispose();
   END CWeekCalendarFunction;

(*--------------------------------------------------------------------------------*)

END CWeekCalendarFunction;

(*================================================================================*)

END WeekCalendar.