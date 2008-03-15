IMPLEMENTATION MODULE DaliSci;

CLASS IMPLEMENTATION CDaliSci;

   PUBLIC PROCEDURE LoadConfiguration( CONST INI : INIFile.CINIFile; REF logger : log.CLogger ) : BOOLEAN;
   BEGIN
      RETURN TRUE;
   END LoadConfiguration;
      
   PUBLIC PROCEDURE Run();
   BEGIN
   END Run;

   PUBLIC PROCEDURE Stop();
   BEGIN
   END Stop;

END CDaliSci;

END DaliSci.