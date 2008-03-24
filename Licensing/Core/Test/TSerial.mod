MODULE TSerial;

IMPORT
  FIO,
  Number,
  Strings,
  StringsO,
  windows;
  
#save, call( convention => cdecl )
PROCEDURE wmain2() : INTEGER;
#restore
CONST
   cpid = L"SmartControl.NetMsg.CWDriver";
VAR
   E : StringsO.CString;
	f : FIO.File := windows.GetStdHandle( windows.STD_OUTPUT_HANDLE );
	i : CARDINAL;
	SN : Number.CSerial;
	s : ARRAY [0..255] OF WCHAR;
	S : StringsO.CString;
	sa : ARRAY [0..255] OF CHAR;
	pid : StringsO.CString;
BEGIN
(*
   S.FromOA( L"Martin" );

   pid.FromOA( cpid );
	FOR i := 67 TO 87 DO
	   pid[0] := WCHAR( i );
		SN.SetPId( pid );

		Number.Code( SN, OUT s ); Strings.ToA( s, 0, OUT sa ); FIO.WrStrA( f, sa );
		FIO.WrLnA( f );
	
		SN.SetOwner( S );
		Number.Code( SN, OUT s ); Strings.ToA( s, 0, OUT sa ); FIO.WrStrA( f, sa );
		FIO.WrLnA( f );
		Number.Decode( s, OUT SN );
		SN.CheckOwner( S );
		SN.CheckOwner( S );
		SN.SetOwner( E );
		
		FIO.WrLnA( f );
	END; // FOR

   pid := cpid;	
	FOR i := 67 TO 87 DO
		SN.GOrd := i;

		Number.Code( SN, OUT s ); Strings.ToA( s, 0, OUT sa ); FIO.WrStrA( f, sa );
		FIO.WrLnA( f );
		
		SN.SetOwner( S );
		Number.Code( SN, OUT s ); Strings.ToA( s, 0, OUT sa ); FIO.WrStrA( f, sa );
		FIO.WrLnA( f );
		Number.Decode( s, OUT SN );
		SN.CheckOwner( S );
		SN.CheckOwner( S );
		SN.SetOwner( E );
		
		FIO.WrLnA( f );
	END; // FOR
*)
	
	RETURN 0;
END wmain2;

END TSerial.