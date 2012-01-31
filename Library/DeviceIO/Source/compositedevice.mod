IMPLEMENTATION MODULE compositedevice;

FROM Storage IMPORT
   ALLOCATE, DEALLOCATE;

(*===========================================================================*)

CLASS IMPLEMENTATION CCompositeDevice;

(*---------------------------------------------------------------------------*)

   PUBLIC VIRTUAL PROCEDURE Dispose();
   VAR
      d : device.TPDevice;
   BEGIN
      _Devices.Reset();
      WHILE _Devices.MoveNext() DO
         d := _Devices.Current;
         IF device.capAdviseSource IN d^.DeviceCapabilities THEN
            d^.AdviseSource()^.Advise := io.advNone;
            d^.AdviseSource()^.AdviseListener := NIL;
         END;
      END; // WHILE

      _Namespace.Dispose();
      _Devices.Dispose();
   END Dispose;

(*---------------------------------------------------------------------------*)

   PUBLIC VIRTUAL PROCEDURE OnAdvise( Source : io.TPIO; CONST Result : ARRAY OF Sync.TAsyncResult; CONST Item : ARRAY OF ns.THash; CONST Value : ARRAY OF iovalue.Value );
   BEGIN
      IF _AdviseListener <> NIL THEN
         _AdviseListener^.OnAdvise( Source, Result, Item, Value );
      END;
   END OnAdvise;

(*---------------------------------------------------------------------------*)

   PUBLIC VIRTUAL PROPERTY Advise GET : io.TAdvise;
   BEGIN
      RETURN _Advise;
   END Advise;

(*---------------------------------------------------------------------------*)

   PUBLIC VIRTUAL PROPERTY Advise SET( Value : io.TAdvise );
   VAR
      d : device.TPDevice;
   BEGIN
      _Advise := Value;

      // update advising in nested devices
      _Devices.Reset();
      WHILE _Devices.MoveNext() DO
         d := _Devices.Current;
         IF device.capAdviseSource IN d^.DeviceCapabilities THEN
            d^.AdviseSource()^.Advise := _Advise;
         END;
      END; // WHILE
   END Advise;

(*---------------------------------------------------------------------------*)

   PUBLIC VIRTUAL PROPERTY AdviseListener GET : io.TPAdviseInfo;
   BEGIN
      RETURN _AdviseListener;
   END AdviseListener;

(*---------------------------------------------------------------------------*)

   PUBLIC VIRTUAL PROPERTY AdviseListener SET( Value : io.TPAdviseInfo );
   VAR
      d : device.TPDevice;
   BEGIN
      _AdviseListener := Value;

      // update advising in nested devices
      _Devices.Reset();
      WHILE _Devices.MoveNext() DO
         d := _Devices.Current;
         IF device.capAdviseSource IN d^.DeviceCapabilities THEN
            IF _AdviseListener = NIL THEN
               d^.AdviseSource()^.AdviseListener := NIL;
               d^.AdviseSource()^.Advise := io.advNone;
            ELSE
               d^.AdviseSource()^.AdviseListener := ADR( SELF );
               d^.AdviseSource()^.Advise := io.advWithData;
            END;
         END;
      END; // WHILE
   END AdviseListener;

(*---------------------------------------------------------------------------*)

   PUBLIC VIRTUAL PROCEDURE Configure( CONST Source : ARRAY OF device.TConfigureItem; CONST Log : log.TPLogger ) : Sync.TAsyncResult; // Log is mandatory
   VAR
      d : device.TPDevice;
      deviceName : ARRAY [0..127] OF WCHAR;
      name : ARRAY [0..127] OF WCHAR;
      result : Sync.TAsyncResult;
      totalResult : Sync.TAsyncResult := Sync.arCompleted;
   BEGIN
      _Namespace.Name.ToOA( OUT name );

      _Devices.Reset();
      WHILE _Devices.MoveNext() DO
         d := _Devices.Current;
         d^.NS()^.Name.ToOA( OUT deviceName );

         Log^.LogSS( log.lcError, 0, name, L"Configuring device: ", deviceName );
         result := d^.Configure( Source, Log );
         Log^.LogSR( log.lcError, 0, name, L"Result: ", result );
   
         IF result NOT IN Sync.arsCompletions THEN
            totalResult := Sync.arCannotStart;
         END;
      END; // WHILE

      RETURN totalResult;
   END Configure;

(*---------------------------------------------------------------------------*)

   PUBLIC VIRTUAL PROPERTY DeviceCapabilities GET : device.TCapabilities;
   BEGIN
      RETURN device.TCapabilities{ device.capAdviseSource };
   END DeviceCapabilities;

(*---------------------------------------------------------------------------*)

   PUBLIC VIRTUAL PROCEDURE NS() : ns.TPNamespace; // required, handles both naming and IO
   BEGIN
      RETURN ADR( _Namespace );
   END NS;

(*---------------------------------------------------------------------------*)

   PUBLIC VIRTUAL PROCEDURE StartStop() : io.TPStartStopControl; // optional
   BEGIN
      RETURN NIL;
      // TODO -- start and stop all devices RETURN ADR( _StartStopHandler );
   END StartStop;

(*---------------------------------------------------------------------------*)

   PUBLIC VIRTUAL PROCEDURE IO() : io.TPIO; // optional, NS items itself can be able to use IO
   BEGIN
      RETURN NIL;
   END IO;

(*---------------------------------------------------------------------------*)

   PUBLIC VIRTUAL PROCEDURE AdviseSource() : io.TPAdviseSource; // optional
   BEGIN
      RETURN ADR( SELF );
   END AdviseSource;

(*---------------------------------------------------------------------------*)

   PUBLIC PROCEDURE Init( CONST Name : StringsO.IString );
   VAR
      name : StringsO.CString;
   BEGIN
      name.Assign( Name );
      _Namespace.InitializeName := name;
   END Init;

(*---------------------------------------------------------------------------*)

   PUBLIC PROCEDURE JoinDevice( CONST Device : device.TPDevice );
   BEGIN
      IF _Devices.Contains( Device ) THEN
         RETURN;
      END;
      OnJoinDevice( Device );
      _Devices.Add( Device, 0 );
   END JoinDevice;

(*---------------------------------------------------------------------------*)

   PUBLIC PROCEDURE LeaveDevice( CONST Device : device.TPDevice );
   BEGIN
      IF _Devices.Contains( Device ) THEN
         _Devices.Remove( Device );
         OnLeaveDevice( Device );
      END;
   END LeaveDevice;

(*---------------------------------------------------------------------------*)

   INTERNAL VIRTUAL PROCEDURE OnJoinDevice( CONST Device : device.TPDevice );
   BEGIN
      // connect to namespace
      _Namespace.Link( Device^.NS()^.Name, Device^.NS());
      // link advising
      IF device.capAdviseSource IN Device^.DeviceCapabilities THEN
         Device^.AdviseSource()^.Advise := _Advise;
         Device^.AdviseSource()^.AdviseListener := ADR( SELF );
      END;
   END OnJoinDevice;

(*---------------------------------------------------------------------------*)

   INTERNAL VIRTUAL PROCEDURE OnLeaveDevice( CONST Device : device.TPDevice );
   VAR
      child : ns.TPNameValuePairs;
   BEGIN
      // disconnect from namespace
      _Namespace.Unlink( Device^.NS()^.Name, OUT child );
      // unlink advising
      IF device.capAdviseSource IN Device^.DeviceCapabilities THEN
         Device^.AdviseSource()^.Advise := io.advNone;
         Device^.AdviseSource()^.AdviseListener := NIL;
      END;
   END OnLeaveDevice;

(*---------------------------------------------------------------------------*)

BEGIN
FINALLY
   Dispose();
END CCompositeDevice;

(*===========================================================================*)

END compositedevice.