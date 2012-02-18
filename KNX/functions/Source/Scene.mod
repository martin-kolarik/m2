IMPLEMENTATION MODULE Scene;

(*================================================================================*)

FROM Debug IMPORT
   AssertionW;

IMPORT
   collection,
   io,
   IOO,
   iovalue,
   INIFile,
   lists,
   Mathematics,
   nsimpl,
   StringsO,
   Texts;

(*================================================================================*)

CLASS COutput;

   LOCAL PROCEDURE Enqueue() : BOOLEAN; // returns FALSE if the object is already in the queue
   LOCAL PROCEDURE Dequeue();

   LOCAL VAR
      Input : ns.TPNameValuePairs := NIL;
      InputValues : lists.CStringList;
      Condition : ns.TPNameValuePairs := NIL;
      Output : ns.TPNameValuePairs := NIL;
      OutputValue : iovalue.Value;

   PRIVATE VAR
      _Signal : Sync.SIGNAL;

END COutput;

(*--------------------------------------------------------------------------------*)

CLASS IMPLEMENTATION COutput;

(*--------------------------------------------------------------------------------*)

   LOCAL PROCEDURE Enqueue() : BOOLEAN;
   BEGIN
      RETURN _Signal.Signal();
   END Enqueue;

(*--------------------------------------------------------------------------------*)

   LOCAL PROCEDURE Dequeue();
   BEGIN
      _Signal.Reset();
   END Dequeue;

(*--------------------------------------------------------------------------------*)

BEGIN
   _Signal.Init( Sync.stSpin, L"", FALSE );
END COutput;

(*================================================================================*)

CONST
   LOGNAME = L"Scenes";
   CFG_SECTION = L"scenes";
   CFG_CONTEXT = L"context";
   CFG_SCENE_PREFIX = L"scene_";
   MSG_SEND = msghandler.MSG_BASE;

CLASS IMPLEMENTATION CSceneFunction;

(*--------------------------------------------------------------------------------*)

   INTERNAL VIRTUAL PROCEDURE OnMessage( CONST Message : msghandler.IMessage; OUT Result : PTR ) : BOOLEAN;
   VAR
      output : TPOutput;
   BEGIN
      IF SUPER.OnMessage( Message, OUT Result ) THEN
         RETURN TRUE;

      ELSIF Message.Message = MSG_SEND THEN
         WHILE _SendQueue.Dequeue( OUT output  ) DO
            output^.Dequeue();
            Write( output );
         END; // _SendQueue

         RETURN TRUE;
      
      ELSE
         RETURN FALSE;
      END;
   END OnMessage;

(*--------------------------------------------------------------------------------*)

   PUBLIC VIRTUAL PROCEDURE OnAdvise( CONST Originator : ns.TPOriginator; CONST Result : ARRAY OF Sync.TAsyncResult; CONST Item : ARRAY OF ns.TPNameValuePairs; CONST Value : ARRAY OF iovalue.Value );
   VAR
      output : TPOutput;
      i : CARDINAL;
      it : lists.CPtrListIterator;
   BEGIN
      // check validity of input
      IF HIGH( Item ) < 0 THEN
         RETURN;
      END;
      
      // look for items and check if operation finished sucessfully
      FOR i := 0 TO HIGH( Item ) DO
         IF Result[i] IN Sync.arsCompletions THEN
            
            it.Init( _Outputs, collection.dirForward );
            WHILE it.MoveNext() DO
               output := it.Value;
               IF output^.Input = Item[i] THEN
                  Enqueue( output );
               END;
            END; // WHILE
            
         END;
      END;
   END OnAdvise;

(*--------------------------------------------------------------------------------*)

   PUBLIC VIRTUAL PROCEDURE Configure( CONST Source : ARRAY OF device.TConfigureItem; CONST Log : log.TPLogger ) : Sync.TAsyncResult;
   VAR
      condition : StringsO.CString;
      conditionFound : BOOLEAN;
      conditionPairs : ns.TPNameValuePairs;
      context : StringsO.CString;
      output : TPOutput;
      ES : PTR;
      i : CARDINAL;
      iniFile : INIFile.TPINIFile;
      key : StringsO.CString;
      Line : CARDINAL;
      lineString : ARRAY [0..63] OF WCHAR;
      pairs : ns.TPNameValuePairs;
      s : StringsO.CString;
      section : StringsO.CString;
      sections : lists.CStringList; // section name = pairs
      sit : lists.CStringListIterator;
      someError : BOOLEAN := FALSE;
      value : StringsO.CString;
   BEGIN
      // CHECKS
      IF DataSource = NIL THEN
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

      // LOOP OVER SECTIONS
      ES := 0;
      WHILE iniFile^.EnumerateKeys( REF ES, OUT Line, OUT key, OUT value ) DO

         IF key.EqualsOA( CFG_CONTEXT ) THEN
            IF DataSource^.NS()^.Contains( nsimpl.AddContext( context, value )) THEN
               context := value;
            ELSE
               AppendLineNumber( LOGNAME, Line, OUT lineString );
               Log^.LogSS( log.lcError, 0, lineString, OAsz( R^[ Texts._ContextNotFound ] ), OA( value.Length-1, value.Data ));
               someError := TRUE;
            END;
            CONTINUE;
         END;

         IF NOT DataSource^.NS()^.Get( nsimpl.AddContext( context, value ), OUT pairs ) THEN
            AppendLineNumber( LOGNAME, Line, OUT lineString );
            Log^.LogSS( log.lcError, 0, lineString, OAsz( R^[ Texts._InputAddressNotFound ] ), OA( s.Length-1, s.Data ));
            someError := TRUE;
            CONTINUE;
         END;

         // remember the section
         sections.Add( key, pairs );

      END; // WHILE over sections

      // LOOP OVER OUTPUTS IN SECTIONS
      sit.Init( sections, collection.dirForward );
      WHILE sit.MoveNext() DO

         section.Assign( sit.Value^ );
         section.Prepend( StringsO.FromOA( CFG_SCENE_PREFIX ));
         IF NOT iniFile^.SetSection( OA( section.Length-1, section.Data )) THEN
            AppendLineNumber( LOGNAME, Line, OUT lineString );
            Log^.LogSS( log.lcInfo, 0, lineString, OAsz( R^[ Texts._ConfigurationSectionNotFound ] ), OA( section.Length-1, section.Data ));
            someError := TRUE;
            CONTINUE;
         END;
            
         ES := 0;
         WHILE iniFile^.EnumerateKeys( REF ES, OUT Line, OUT key, OUT value ) DO

            IF key.EqualsOA( CFG_CONTEXT ) THEN
               IF DataSource^.NS()^.Contains( nsimpl.AddContext( context, value )) THEN
                  context := value;
               ELSE
                  AppendLineNumber( LOGNAME, Line, OUT lineString );
                  Log^.LogSS( log.lcError, 0, lineString, OAsz( R^[ Texts._ContextNotFound ] ), OA( value.Length-1, value.Data ));
                  someError := TRUE;
               END;
               CONTINUE;
            END;

            // output[cond] = value, input_value [, input_value]
            IF NOT SplitOutputAndCondition( key, OUT key, OUT conditionFound, OUT condition ) THEN
               AppendLineNumber( LOGNAME, Line, OUT lineString );
               Log^.LogSS( log.lcError, 0, lineString, OAsz( R^[ Texts._IncorrectOutputConditionFormat ] ), OA( key.Length-1, key.Data ));
               someError := TRUE;
               CONTINUE;
            ELSIF NOT DataSource^.NS()^.Get( nsimpl.AddContext( context, key ), OUT pairs ) THEN
               AppendLineNumber( LOGNAME, Line, OUT lineString );
               Log^.LogSS( log.lcError, 0, lineString, OAsz( R^[ Texts._OutputAddressNotFound ] ), OA( key.Length-1, key.Data ));
               someError := TRUE;
               CONTINUE;
            ELSIF conditionFound AND NOT DataSource^.NS()^.Get( nsimpl.AddContext( context, condition ), OUT conditionPairs ) THEN
               AppendLineNumber( LOGNAME, Line, OUT lineString );
               Log^.LogSS( log.lcError, 0, lineString, OAsz( R^[ Texts._ConditionAddressNotFound ] ), OA( key.Length-1, key.Data ));
               someError := TRUE;
               CONTINUE;
            END;

            // check mandatory output value
            i := value.ItemS( StringsO.WCHARS{L","}, 0, 0, FALSE, OUT s );
            IF ( i = -1 ) OR s.Empty THEN
               AppendLineNumber( LOGNAME, Line, OUT lineString );
               Log^.LogSS( log.lcError, 0, lineString, OAsz( R^[ Texts._OutputValueNotFound ] ), OA( value.Length-1, value.Data ));
               someError := TRUE;
               CONTINUE;
            END;

            // everything OK, create item in _Outputs
            NEW( output );
            output^.Input := sit.Data;
            output^.Output := pairs;
            output^.OutputValue.String := s;
            IF conditionFound THEN
               output^.Condition := conditionPairs;
            END;
            _Outputs.Add( output, 0 );

            // read values should math the input
            i := value.ItemS( StringsO.WCHARS{L","}, i, 0, FALSE, OUT s );
            WHILE i <> -1 DO
               s.Trim();
               output^.InputValues.Add( s, 0 );
            END; // WHILE

         END; // WHILE outputs in section

      END; // WHILE sections

      IF someError THEN
         RETURN Sync.arCannotStart;
      ELSE      
         RETURN Sync.arCompleted;
      END;
   END Configure; 
   
(*--------------------------------------------------------------------------------*)

   PUBLIC VIRTUAL PROCEDURE Dispose();
   VAR
      it : lists.CPtrListIterator;
      output : TPOutput;
   BEGIN
      IF DataSource <> NIL THEN
         DataSource^.UnadviseAll( ADR( SELF ));
      END;
   
      it.Init( _Outputs, collection.dirForward );
      WHILE it.MoveNext() DO
         output := it.Value;
         DISPOSE( output );
      END; // WHILE
      _Outputs.Dispose();
   END Dispose;

(*--------------------------------------------------------------------------------*)

   INTERNAL VIRTUAL PROCEDURE OnStart();
   VAR
      it : lists.CPtrListIterator;
      output : TPOutput;
   BEGIN
      DataSource^.JoinClient( ADR( SELF ), ns.advWithData );
      
      it.Init( _Outputs, collection.dirForward );
      WHILE it.MoveNext() DO
         output := it.Value;
         DataSource^.AdviseHash( ADR( SELF ), output^.Input );
      END; // WHILE
   END OnStart;

(*--------------------------------------------------------------------------------*)

   INTERNAL VIRTUAL PROCEDURE OnStop();
   BEGIN
      DataSource^.UnadviseAll( ADR( SELF ));
      DataSource^.LeaveClient( ADR( SELF ));
   END OnStop;
   
(*--------------------------------------------------------------------------------*)

   PRIVATE PROCEDURE Enqueue( output : TPOutput );
   VAR
      name : StringsO.CString;
      result : Sync.TAsyncResult;
      value : iovalue.Value;
   BEGIN
      IF output^.Enqueue() THEN // smart queueuing, the item has just put to the queue

         result := output^.Condition^.ValueIO( ADR( SELF ), output^.Condition, IOO.dirRead, REF value );
         IF result NOT IN Sync.arsCompletions THEN
            ASSERTLOG( FALSE, L"Unable to read condition value" );
            RETURN;
         END;

         DataSource^.NS()^.GetFullName( output^.Output, OUT name );

         IF value.Boolean THEN 
            Logger^.LogSS( log.lcInfo, 0, LOGNAME, L"Enquing item for output:", OA( name.Length-1, name.Data ));
            _SendQueue.Enqueue( output );
         ELSE // condition not satisfied, do nothing
            Logger^.LogSS( log.lcInfo, 0, LOGNAME, L"Not enquing item for output, condition is false:", OA( name.Length-1, name.Data ));
            output^.Dequeue();
         END;

      END; // IF output^.Enqueue
   END Enqueue;

(*--------------------------------------------------------------------------------*)

   PRIVATE PROCEDURE Write( output : TPOutput );
   VAR
      found : BOOLEAN := FALSE;
      it : lists.CStringListIterator;
      name : StringsO.CString;
      result : Sync.TAsyncResult;
      value : iovalue.Value;
      valueString : StringsO.CString;
   BEGIN
      WITH output^ DO

         // read input value
         result := Input^.ValueIO( ADR( SELF ), Input, IOO.dirRead, REF value );
         IF result NOT IN Sync.arsCompletions THEN
            ASSERTLOG( FALSE, L"Unable to read input value" );
            RETURN;
         END;
         valueString := value.String;

         // compute
         found := FALSE;
         it.Init( InputValues, collection.dirForward );
         WHILE it.MoveNext() DO
            IF it.Value^.Equals( valueString ) THEN
               found := TRUE;
               EXIT;
            END;
         END; // WHILE

         IF found THEN
            DataSource^.NS()^.GetFullName( Output, OUT name );
            result := Output^.ValueIO( ADR( SELF ), Output, IOO.dirWrite, REF OutputValue );
            IF result IN Sync.arsCompletions THEN
               Logger^.LogSSSS( log.lcInfo, 0, LOGNAME, L"Output written:", OA( name.Length-1, name.Data ), L"=", OA( OutputValue.String.Length-1, OutputValue.String.Data ));
            ELSE
               Logger^.LogSSSS( log.lcWarning, 0, LOGNAME, L"Unable to write output:", OA( name.Length-1, name.Data ), L"=", OA( OutputValue.String.Length-1, OutputValue.String.Data ));
            END;            
         END;

      END; // WITH
   END Write;

(*--------------------------------------------------------------------------------*)

   INITIALLY CSceneFunction();
   VAR
      msg : msghandler.Message;
   BEGIN
      DescriptionSet := StringsO.FromOA( L"Scenes" );
      
      msg.Message := MSG_SEND;
      _SendQueue.ConsumerMsg := ADR( msg );
      _SendQueue.Consumer := ADR( SELF );
   END CSceneFunction;

(*--------------------------------------------------------------------------------*)

   FINALLY CSceneFunction();
   BEGIN
      Dispose();
   END CSceneFunction;

(*--------------------------------------------------------------------------------*)

END CSceneFunction;

(*================================================================================*)

END Scene.