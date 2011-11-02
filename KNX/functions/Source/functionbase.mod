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
      ELSIF _Device = NIL THEN
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
      ELSIF _Device = NIL THEN
         RETURN;
      END;
      _Running := FALSE;
      OnStop();
   END Stop;
   
(*--------------------------------------------------------------------------------*)

   PUBLIC PROPERTY Device GET : adviser.TPAdvisedDevice;
   BEGIN
      RETURN _Device;
   END Device;

(*--------------------------------------------------------------------------------*)

   PUBLIC PROPERTY Device SET( Value : adviser.TPAdvisedDevice );
   BEGIN
      Dispose();
      _Device := Value;
   END Device;

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
(*
   INTERNAL PROCEDURE SplitOutputAndCondition( CONST composite : StringsO.IString; OUT output : StringsO.IString; OUT conditionFound : BOOLEAN; OUT condition : StringsO.IString ) : BOOLEAN;
   BEGIN
      IF composite.IndexOfChar( 0, L"[" ) = -1 THEN
         conditionFound := FALSE;
         output.Assign( composite );
      RETURN FALSE;
   END SplitOutputAndCondition;
*)
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