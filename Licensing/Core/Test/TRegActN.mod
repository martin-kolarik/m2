MODULE TRegActN;

IMPORT
  FIO,
  Number,
  Strings,
  StringsO,
  time,
  Uniquer,
  windows;
  
#save, call( convention => cdecl )
PROCEDURE wmain7() : INTEGER;
#restore
CONST
   cpid = L"SmartControl.Test";
VAR
   dt : time.DateTime;
	f : FIO.File := windows.GetStdHandle( windows.STD_OUTPUT_HANDLE );
	l : CARDINAL;
	RN : Number.CRegistration;
	AN : Number.CActivation;
	sa : ARRAY [0..255] OF CHAR;
	uq : Uniquer.CUniquer;
   #if #contains( LicenceMachineId, L"D" ) #then
	   uqd : Uniquer.DiscSource;
   #endif
	so : StringsO.CString;
BEGIN
   #if #contains( LicenceMachineId, L"D" ) #then
      uq.Sources^.Add( ADR( uqd ), 0 );
   #endif

   so.FromOA( cpid );
   RN.SetPId( so );
   RN.SetMId( uq.UId( so ));
   RN.GOrd := 10;
   RN.SetOSVersionByMachine();

   Number.Code( RN, OUT so ); so.ToOAA( 0, OUT sa, OUT l ); FIO.WrStrA( f, sa ); FIO.WrStrA( f, CHAR(13)+CHAR(10) );
   Number.Decode( so, REF RN );

   dt.SetNowLocal();
   so.FromOA( cpid );
   AN.SetPId( so );
   AN.MId := RN.MId;
   AN.Origin := dt;
   AN.Months := 0;

   Number.Code( AN, OUT so ); so.ToOAA( 0, OUT sa, OUT l ); FIO.WrStrA( f, sa ); FIO.WrStrA( f, CHAR(13)+CHAR(10) );
   Number.Decode( so, REF AN );

	RETURN 0;
END wmain7;

END TRegActN.