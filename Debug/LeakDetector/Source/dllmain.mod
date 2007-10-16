IMPLEMENTATION MODULE dllmain;

//==============================================================
// DllMain module
//==============================================================

IMPORT
  windows;

IMPORT
  ld;

PROCEDURE DllMain( Instance : windows.HINSTANCE;
                   Reason   : windows.DWORD;
                   Reserved : windows.PVOID ): windows.BOOL;
BEGIN
  ld.DllMain( Reason );
  RETURN windows.True;
END DllMain;

END dllmain.
