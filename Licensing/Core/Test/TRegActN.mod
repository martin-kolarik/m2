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
PROCEDURE wmain() : INTEGER;
#restore
CONST
   cpid = L"SmartControl.Test";
VAR
   dt : time.TDateTime;
	f : FIO.File := windows.GetStdHandle( windows.STD_OUTPUT_HANDLE );
	RN : Number.CRegistration;
	AN : Number.CActivation;
	sa : ARRAY [0..255] OF CHAR;
	uq : Uniquer.CUniquer;
	uqd : Uniquer.DiscSource;
	so : StringsO.CString;
BEGIN
   uq.Sources^.Add( ADR( uqd ), 0 );

   so.FromOA( cpid );
   RN.SetPId( so );
   RN.SetMId( uq.UId( so ));
   RN.GOrd := 10;
   RN.SetOSVersionByMachine();

   Number.Code( RN, OUT so ); so.ToOAA( 0, OUT sa ); FIO.WrStrA( f, sa ); FIO.WrStrA( f, CHAR(13)+CHAR(10) );
   Number.Decode( so, REF RN );

   time.GetCurrentLocalDateTime( dt );
   so.FromOA( cpid );
   AN.SetPId( so );
   AN.MId := RN.MId;
   AN.Origin := dt;
   AN.Months := 0;

   Number.Code( AN, OUT so ); so.ToOAA( 0, OUT sa ); FIO.WrStrA( f, sa ); FIO.WrStrA( f, CHAR(13)+CHAR(10) );
   Number.Decode( so, REF AN );

	RETURN 0;
END wmain;

END TRegActN.