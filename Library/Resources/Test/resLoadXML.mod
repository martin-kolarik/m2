MODULE resLoadXML;

IMPORT
  com,
  Resources;

  # save, call( prefix => cdecl )
  PROCEDURE wmain();
  VAR
    E : ARRAY [0..3] OF WCHAR;
    R : Resources.CResourcesCreator;
  BEGIN
    com.COMInit();
    R.LoadXML( L"s:\TestRes.xrs", OUT E );
    R.SaveBIN( L"s:\TestRes.bin" );
    R.LoadBIN( L"s:\TestRes.bin" );
  END wmain;
  # restore

END resLoadXML.

