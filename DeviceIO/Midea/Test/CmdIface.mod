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
   LOCAL VAR
      tw : TextWriter.TPTextWriter := TextWriter.errout();
   PUBLIC VIRTUAL PROCEDURE OnIO( Direction : IOO.TDirection; Source : io.TPIO; CONST Result : ARRAY OF Sync.TAsyncResult; CONST Item : ARRAY OF ns.THash; CONST Value : ARRAY OF iovalue.Value );
END CDataInfo;

CLASS IMPLEMENTATION CDataInfo;

  PUBLIC VIRTUAL PROCEDURE OnIO( Direction : IOO.TDirection; Source : io.TPIO; CONST Result : ARRAY OF Sync.TAsyncResult; CONST Item : ARRAY OF ns.THash; CONST Value : ARRAY OF iovalue.Value );
  BEGIN
      tw^.Write( nsitem.TPnsItem( Item[0] )^.Name^, FALSE ); tw^.WriteOA( L": ", FALSE );
		IF Direction = IOO.dirRead THEN
		   tw^.Write( Value[0].String, TRUE );
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
   
   // midea^.NS()^.Dump( DI.tw );
   
   cfgparam[0] := ADR( sCOM );
   cfgparam[1] := ADR( sPAR );
	midea^.Configure( cfgparam, Log.logger() );
	Wait( 65 );

	V.FromStringOA( L"high", FALSE );
	b := midea^.NS()^.Map( L"MideaAC.Data.1.All.Fan", OUT h );
	r := midea^.IO()^.IOh( IOO.dirWrite, h, REF V, ADR( DI ));
	Wait( 20 );

	V.FromStringOA( L"heat", FALSE );
	b := midea^.NS()^.Map( L"MideaAC.Data.1.All.Mode", OUT h );
	r := midea^.IO()^.IOh( IOO.dirWrite, h, REF V, ADR( DI ));
	Wait( 20 );
   
   loader.ldr()^.ReleaseObject( REF midea );
   loader.ldr()^.Dispose();
   RETURN 0;
END wmain;

END cmdiface.