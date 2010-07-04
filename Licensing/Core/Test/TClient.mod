MODULE TClient;

IMPORT
  windows,
  datetime,
  lec;
  
#save, call( convention => cdecl )
PROCEDURE wmain5() : INTEGER;
#restore
VAR
   res : lec.CResult;
   s : ARRAY [0..63] OF WCHAR;
BEGIN
   res.Reset( lec.bhBestCase );
   lec.Query( L"..\lictool\~debug", L"", L"Inris.Tvrz*", REF res );
   
   IF res.StateInfo = lec.siDemo THEN
      windows.OutputDebugStringW( "demo" + 13W+10W );
   ELSIF res.StateInfo = lec.siNotActivated THEN
      windows.OutputDebugStringW( "inactive" + 13W+10W );
   ELSIF res.StateInfo = lec.siActivated THEN
      windows.OutputDebugStringW( "active" + 13W+10W );
   END;
   
   IF res.Expires.Year = 0 THEN
      windows.OutputDebugStringW( "forever" + 13W+10W );
   ELSE
      windows.OutputDebugStringW( "expires: " + 13W+10W );
      // datetime.DateTimeToString( res.Expires, "yyyy-MM-dd HH.mm.ss,fff", TRUE, TRUE, s );
      windows.OutputDebugStringW( ADR( s ));
      windows.OutputDebugStringW( 13W+10W );
   END;
   
	RETURN 0;
END wmain5;

END TClient.