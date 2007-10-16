MODULE TCoder;

IMPORT
  FIO,
  Coder,
  Strings,
  windows;
  
#save, call( convention => cdecl )
PROCEDURE wmain() : INTEGER;
#restore
CONST
   cpid = L"SmartControl.NetMsg.CWDriver";
VAR
	f : FIO.File := windows.GetStdHandle( windows.STD_OUTPUT_HANDLE );
	i : CARDINAL;
	SN : Coder.CSerial;
	s : ARRAY [0..255] OF WCHAR;
	sa : ARRAY [0..255] OF CHAR;
	pid : ARRAY [0..63] OF WCHAR;
BEGIN

   pid := cpid;
	FOR i := 67 TO 87 DO
	   pid[0] := WCHAR( i );
		SN.SetPId( pid );

		Coder.Code( SN, OUT s ); Strings.ToA( s, 0, OUT sa ); FIO.WrStrA( f, sa );
		FIO.WrLnA( f );
		
		SN.SetOwner( L'Martin' );
		Coder.Code( SN, OUT s ); Strings.ToA( s, 0, OUT sa ); FIO.WrStrA( f, sa );
		FIO.WrLnA( f );
		Coder.Decode( s, OUT SN );
		SN.CheckOwner( L'Martin' );
		SN.CheckOwner( L'martin' );
		SN.SetOwner( L'' );
		
		FIO.WrLnA( f );
	END; // FOR

   pid := cpid;	
	FOR i := 67 TO 87 DO
		SN.GOrd := i;

		Coder.Code( SN, OUT s ); Strings.ToA( s, 0, OUT sa ); FIO.WrStrA( f, sa );
		FIO.WrLnA( f );
		
		SN.SetOwner( L'Martin' );
		Coder.Code( SN, OUT s ); Strings.ToA( s, 0, OUT sa ); FIO.WrStrA( f, sa );
		FIO.WrLnA( f );
		Coder.Decode( s, OUT SN );
		SN.CheckOwner( L'Martin' );
		SN.CheckOwner( L'martin' );
		SN.SetOwner( L'' );
		
		FIO.WrLnA( f );
	END; // FOR
	
	RETURN 0;
END wmain;

END TCoder.