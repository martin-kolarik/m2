IMPLEMENTATION MODULE Folders;

FROM Debug IMPORT
   AssertionW;

IMPORT
   FIO,
   shlobjlite;

(*============================================================*)

PROCEDURE GetSpecialFolderW( specialFolder : TSpecialFolder; OUT folderPath : ARRAY OF WCHAR ) : BOOLEAN; // returns FALSE if folder is unknown
VAR
   folder : FIO.PathStrW;
BEGIN
   CASE specialFolder OF
   //-----
   | sfEXEDir :
      RETURN FIO.GetModuleDirW( L"", OUT folderPath );
   //-----
   | sfAppDataCommon :
      IF shlobjlite.SHGetFolderPath( NIL, shlobjlite.CSIDL_COMMON_APPDATA, NIL, shlobjlite.SHGFP_TYPE_CURRENT, ADR( folder )) <> 0 THEN
         RETURN FALSE;
      END;
   //-----
   | sfAppDataUser :
      IF shlobjlite.SHGetFolderPath( NIL, shlobjlite.CSIDL_APPDATA, NIL, shlobjlite.SHGFP_TYPE_CURRENT, ADR( folder )) <> 0 THEN
         RETURN FALSE;
      END;
   //-----
   | sfDocumentsCommon :
      IF shlobjlite.SHGetFolderPath( NIL, shlobjlite.CSIDL_COMMON_DOCUMENTS, NIL, shlobjlite.SHGFP_TYPE_CURRENT, ADR( folder )) <> 0 THEN
         RETURN FALSE;
      END;
   //-----
   | sfDocumentsUser :
      IF shlobjlite.SHGetFolderPath( NIL, shlobjlite.CSIDL_PERSONAL, NIL, shlobjlite.SHGFP_TYPE_CURRENT, ADR( folder )) <> 0 THEN
         RETURN FALSE;
      END;
   //-----
   | sfProgramsCommon :
      IF shlobjlite.SHGetFolderPath( NIL, shlobjlite.CSIDL_PROGRAM_FILES_COMMON, NIL, shlobjlite.SHGFP_TYPE_CURRENT, ADR( folder )) <> 0 THEN
         RETURN FALSE;
      END;
   //-----
   | sfPrograms :
      IF shlobjlite.SHGetFolderPath( NIL, shlobjlite.CSIDL_PROGRAM_FILES, NIL, shlobjlite.SHGFP_TYPE_CURRENT, ADR( folder )) <> 0 THEN
         RETURN FALSE;
      END;
   //-----
   ELSE
      ASSERTLOG( FALSE );
      RETURN FALSE;
   END; // CASE

   folderPath := folder;
   RETURN TRUE;
END GetSpecialFolderW;

(*============================================================*)

PROCEDURE GetManufacturerSpecialFolderW( specialFolder : TSpecialFolder; createIfItDoesNotExist : BOOLEAN; OUT folderPath : ARRAY OF WCHAR ) : BOOLEAN; // returns FALSE if folder is unknown
VAR
   folder : FIO.PathStrW;
BEGIN
   IF NOT GetSpecialFolderW( specialFolder, OUT folder ) THEN
      RETURN FALSE;
   END;
   FIO.MakePathW( folder, Manufacturer, OUT folderPath );
   IF createIfItDoesNotExist AND NOT FIO.CreateDirectoryW( folderPath ) THEN
      RETURN FALSE;
   ELSIF FIO.ExistsDirectoryW( folderPath ) THEN
      RETURN TRUE;
   ELSE
      RETURN FALSE;
   END;
END GetManufacturerSpecialFolderW;

(*============================================================*)

END Folders.
