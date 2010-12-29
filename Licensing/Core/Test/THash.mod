MODULE THash;

IMPORT
  FIO,
  hash,
  Strings,
  windows;
  
#save, call( convention => cdecl )
PROCEDURE wmain4() : INTEGER;
#restore
VAR
   c : CARD64;
	
	PROCEDURE out( h : CARD64 );
	BEGIN
	(*
     Strings.FromCARD64W( h, 16, OUT s ); Strings.ToA( s, 0, OUT sa ); FIO.WrStrA( f, sa ); FIO.WrLnA( f );
   *)     
	END out;

BEGIN

   hash.hashs( L"", OUT c ); out( c );

   hash.hashs( L"0", OUT c ); out( c );
   hash.hashs( L"1", OUT c ); out( c );
   hash.hashs( L"2", OUT c ); out( c );
   hash.hashs( L"3", OUT c ); out( c );
   hash.hashs( L"4", OUT c ); out( c );
   hash.hashs( L"5", OUT c ); out( c );
   hash.hashs( L"6", OUT c ); out( c );
   hash.hashs( L"7", OUT c ); out( c );
   hash.hashs( L"8", OUT c ); out( c );
   hash.hashs( L"9", OUT c ); out( c );

   hash.hashs( L"SmartControl.NetMsg", OUT c  ); out( c );
   hash.hashs( L"SmartControl.NetMsg.CWDriver", OUT c  ); out( c );
   hash.hashs( L"SmartControl.NetMsg.ActiveX", OUT c  ); out( c );
   hash.hashs( L"SmartControl.NetMsg.Plain", OUT c  ); out( c );
   hash.hashs( L"SmartControl.NetMsg.Common", OUT c  ); out( c );

	RETURN 0;
END wmain4;

END THash.