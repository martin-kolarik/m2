IMPLEMENTATION MODULE functionbase;

(*================================================================================*)

FROM Debug IMPORT
   AssertionW;

IMPORT
   device,
   FIO,
   Folders,
   IOO,
   iovalue,
   INIFile,
   ns,
   Texts;

(*================================================================================*)

CLASS IMPLEMENTATION CFunctionBase;

(*--------------------------------------------------------------------------------*)

   PUBLIC VIRTUAL PROPERTY Description GET : StringsO.CString;
   BEGIN
      RETURN _Description;
   END Description;

(*--------------------------------------------------------------------------------*)

   PUBLIC VIRTUAL PROPERTY Running GET : BOOLEAN;
   BEGIN
      RETURN _Running;
   END Running;

(*--------------------------------------------------------------------------------*)

   PUBLIC FINAL PROCEDURE Start() : Sync.TAsyncResult;
   BEGIN
      IF _Running THEN
         RETURN Sync.arAlreadyCompleted;
      ELSIF _DataSource = NIL THEN
         RETURN Sync.arCannotStart;
      END;
      _Running := TRUE;
      OnStart();
      RETURN Sync.arCompleted;
   END Start;

(*--------------------------------------------------------------------------------*)

   PUBLIC FINAL PROCEDURE Stop();
   BEGIN
      IF NOT _Running THEN
         RETURN;
      ELSIF _DataSource = NIL THEN
         RETURN;
      END;
      _Running := FALSE;
      OnStop();
   END Stop;
   
(*--------------------------------------------------------------------------------*)

   PUBLIC PROPERTY DataSource GET : adviser.TPAdvisedDataSource;
   BEGIN
      RETURN _DataSource;
   END DataSource;

(*--------------------------------------------------------------------------------*)

   PUBLIC PROPERTY DataSource SET( Value : adviser.TPAdvisedDataSource );
   BEGIN
      Dispose();
      _DataSource := Value;
   END DataSource;

(*--------------------------------------------------------------------------------*)

   PUBLIC PROPERTY Logger GET : log.TPILogger;
   BEGIN
      RETURN _Logger;
   END Logger;
      
(*--------------------------------------------------------------------------------*)

   PUBLIC PROPERTY Logger SET( Value : log.TPILogger );
   BEGIN
      IF Value = NIL THEN
         _Logger := log.logger();
      ELSE
         _Logger := Value;
      END;
   END Logger;
      
(*--------------------------------------------------------------------------------*)

   INTERNAL VIRTUAL PROCEDURE OnStart(); // called from Start
   BEGIN
   END OnStart;

(*--------------------------------------------------------------------------------*)

   INTERNAL VIRTUAL PROCEDURE OnStop(); // called from Stop
   BEGIN
   END OnStop;

(*--------------------------------------------------------------------------------*)

   INTERNAL PROPERTY R GET : Resources.TPResources;
   BEGIN
      RETURN ADR( _R );
   END R;

(*--------------------------------------------------------------------------------*)

   INTERNAL PROPERTY DescriptionSet SET( CONST Value : StringsO.CString );
   BEGIN
      _Description := Value;
   END DescriptionSet;

(*--------------------------------------------------------------------------------*)

   INTERNAL PROCEDURE SplitOutputAndCondition( CONST composite : StringsO.IString; OUT output : StringsO.IString; OUT conditionFound : BOOLEAN; OUT condition : StringsO.IString ) : BOOLEAN;
   VAR
      compositeCopy : StringsO.CString;
      i : CARDINAL;
   BEGIN
      compositeCopy.Assign( composite );

      i := compositeCopy.IndexOfOA( L"[", 0 );
      IF i = 0 THEN
         RETURN FALSE;

      ELSIF i = -1 THEN // string starts directly with condition, which is impossible
         conditionFound := FALSE;
         output.Assign( compositeCopy );

      ELSE
         // split by i to two parts
         compositeCopy.Substring( 0, i-1, OUT output );
         output.Trim();

         compositeCopy.Substring( i+1, -1, OUT condition );
         // look for trailing ]
         i := condition.IndexOfOA( L"]", 0 );
         IF i = -1 THEN // closing ] is missing, bad format
            RETURN FALSE;
         END;
         condition.Remove( i, -1 );
         condition.Trim();
         conditionFound := NOT condition.Empty;

      END;
      RETURN TRUE;
   END SplitOutputAndCondition;
(*--------------------------------------------------------------------------------*)

BEGIN
	IF NOT _R.LoadRES2( EMITW( %dll ), L"functions.Texts" ) THEN
	   _R.LoadRES2( L"", L"functions.Texts" );
   END;
   _Description.FromOA( L"Function Base" );
FINALLY
   Dispose();
END CFunctionBase;

(*================================================================================*)

END functionbase.