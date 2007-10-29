MODULE cmdiface;

IMPORT
   device,
   io,
   iovalue,
   IOO,
   loader,
   Log,
   ns,
   nsitem,
   Sync,
   StringsO,
   TextWriter,
   windows;

CLASS CDataInfo( io.CDataInfo );
   VAR
      tw : TextWriter.TPTextWriter := TextWriter.errout();
   PUBLIC VIRTUAL PROCEDURE OnIO( Direction : IOO.TDirection; Source : io.TPIO; CONST Result : ARRAY OF Sync.TAsyncResult; CONST Item : ARRAY OF ns.THash; CONST Value : ARRAY OF iovalue.Value );
END CDataInfo;

CLASS IMPLEMENTATION CDataInfo;

  PUBLIC VIRTUAL PROCEDURE OnIO( Direction : IOO.TDirection; Source : io.TPIO; CONST Result : ARRAY OF Sync.TAsyncResult; CONST Item : ARRAY OF ns.THash; CONST Value : ARRAY OF iovalue.Value );
  VAR
     S : StringsO.CString;
  BEGIN
      tw^.Write( nsitem.TPnsItem( Item[0] )^.Name^, FALSE ); tw^.WriteOA( L": ", FALSE );
		IF Direction = IOO.dirRead THEN
		   // S := Value[0].String; TODO m2
		   tw^.Write( S, TRUE );
		ELSE
		   tw^.WriteOA( L"OK", TRUE );
		END;
  END OnIO;

BEGIN
END CDataInfo;

PROCEDURE Wait( i : CARDINAL );
VAR
	msg : windows.MSG;
BEGIN
	LOOP
      WHILE windows.PeekMessage( ADR( msg ), NIL, 0, 0, windows.PM_REMOVE ) = windows.True DO
			windows.DispatchMessage( ADR( msg ));
		END;
		windows.Sleep( 10 );
		IF i > 0 THEN
			DEC( i );
			IF i = 0 THEN
				EXIT;
			END;
		END;
	END; // LOOP
END Wait;

#save, call( convention => cdecl )
PROCEDURE wmain() : INTEGER;
#restore
CONST
   sCOM = L"COM2";
   sPAR = L"D:\Work\SmartControl\Code\DeviceIO\Midea\~Debug\com.par";
VAR
   b : BOOLEAN;
   cfgparam : ARRAY [0..1] OF PTR;
   DI : CDataInfo;
   h : ns.THash;
   midea : device.TPDevice;
   V : iovalue.Value;
   r : Sync.TAsyncResult;
BEGIN
   loader.ldr()^.SetHostInfo( L"CmdIfaceTest", L"0.0.1" );
   loader.ldr()^.AddLibrary( L"~Debug\midea.dll" );
   loader.ldr()^.CreateObject( L"midea.IO.Device", OUT midea );
   
   cfgparam[0] := ADR( sCOM );
   cfgparam[1] := ADR( sPAR );
	midea^.Configure( cfgparam, Log.logger() );
	Wait( 65 );

	V.FromStringOA( L"normal", FALSE );
	b := midea^.NS()^.Map( L"MideaAC.Data.Common.Fan", OUT h );
	LOOP
		r := midea^.IO()^.IOh( IOO.dirWrite, h, REF V, ADR( DI ));
		IF r <> Sync.arPending THEN
			EXIT;
		END;
		Wait( 2 );
	END;
   
   loader.ldr()^.ReleaseObject( REF midea );
   loader.ldr()^.Dispose();
   RETURN 0;
END wmain;

END cmdiface.