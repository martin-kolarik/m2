IMPLEMENTATION MODULE compositedatasource;

FROM Storage IMPORT
   ALLOCATE, DEALLOCATE;

(*===========================================================================*)

CLASS IMPLEMENTATION CCompositeDataSource;

(*---------------------------------------------------------------------------*)

   PUBLIC VIRTUAL PROCEDURE Dispose();
   VAR
      d : device.TPDataSource;
   BEGIN
      _DataSources.Reset();
      WHILE _DataSources.MoveNext() DO
         d := _DataSources.Current;
         IF device.capAdviseSource IN d^.DataSourceCapabilities THEN
            d^.AdviseSource()^.Advise := ns.advNone;
            d^.AdviseSource()^.AdviseListener := NIL;
         END;
      END; // WHILE

      _Namespace.Dispose();
      _DataSources.Dispose();
   END Dispose;

(*---------------------------------------------------------------------------*)

   PUBLIC VIRTUAL PROCEDURE OnAdvise( CONST Originator : ns.TPOriginator; CONST Result : ARRAY OF Sync.TAsyncResult; CONST Item : ARRAY OF ns.TPNameValuePairs; CONST Value : ARRAY OF iovalue.Value );
   BEGIN
      IF _AdviseListener <> NIL THEN
         _AdviseListener^.OnAdvise( Originator, Result, Item, Value );
      END;
   END OnAdvise;

(*---------------------------------------------------------------------------*)

   PUBLIC VIRTUAL PROPERTY Advise GET : ns.TAdvise;
   BEGIN
      RETURN _Advise;
   END Advise;

(*---------------------------------------------------------------------------*)

   PUBLIC VIRTUAL PROPERTY Advise SET( Value : ns.TAdvise );
   VAR
      d : device.TPDataSource;
   BEGIN
      _Advise := Value;

      // update advising in nested devices
      _DataSources.Reset();
      WHILE _DataSources.MoveNext() DO
         d := _DataSources.Current;
         IF device.capAdviseSource IN d^.DataSourceCapabilities THEN
            d^.AdviseSource()^.Advise := _Advise;
         END;
      END; // WHILE
   END Advise;

(*---------------------------------------------------------------------------*)

   PUBLIC VIRTUAL PROPERTY AdviseListener GET : ns.TPAdviseInfo;
   BEGIN
      RETURN _AdviseListener;
   END AdviseListener;

(*---------------------------------------------------------------------------*)

   PUBLIC VIRTUAL PROPERTY AdviseListener SET( Value : ns.TPAdviseInfo );
   VAR
      d : device.TPDataSource;
   BEGIN
      _AdviseListener := Value;

      // update advising in nested devices
      _DataSources.Reset();
      WHILE _DataSources.MoveNext() DO
         d := _DataSources.Current;
         IF device.capAdviseSource IN d^.DataSourceCapabilities THEN
            IF _AdviseListener = NIL THEN
               d^.AdviseSource()^.AdviseListener := NIL;
               d^.AdviseSource()^.Advise := ns.advNone;
            ELSE
               d^.AdviseSource()^.AdviseListener := ADR( SELF );
               d^.AdviseSource()^.Advise := ns.advWithData;
            END;
         END;
      END; // WHILE
   END AdviseListener;

(*---------------------------------------------------------------------------*)

   PUBLIC VIRTUAL PROCEDURE Configure( CONST Source : ARRAY OF device.TConfigureItem; CONST Log : log.TPLogger ) : Sync.TAsyncResult; // Log is mandatory
   VAR
      d : device.TPDataSource;
      deviceName : ARRAY [0..127] OF WCHAR;
      name : ARRAY [0..127] OF WCHAR;
      result : Sync.TAsyncResult;
      totalResult : Sync.TAsyncResult := Sync.arCompleted;
   BEGIN
      _Namespace.Name.ToOA( OUT name );

      _DataSources.Reset();
      WHILE _DataSources.MoveNext() DO
         d := _DataSources.Current;
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

   PUBLIC VIRTUAL PROPERTY DataSourceCapabilities GET : device.TCapabilities;
   BEGIN
      RETURN device.TCapabilities{ device.capAdviseSource };
   END DataSourceCapabilities;

(*---------------------------------------------------------------------------*)

   PUBLIC VIRTUAL PROCEDURE NS() : ns.TPNamespace; // required, handles both naming and IO
   BEGIN
      RETURN ADR( _Namespace );
   END NS;

(*---------------------------------------------------------------------------*)

   PUBLIC VIRTUAL PROCEDURE AdviseSource() : ns.TPAdviseSource; // optional
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

   PUBLIC PROCEDURE JoinDataSource( CONST DataSource : device.TPDataSource );
   BEGIN
      IF _DataSources.Contains( DataSource ) THEN
         RETURN;
      END;
      OnJoinDataSource( DataSource );
      _DataSources.Add( DataSource, 0 );
   END JoinDataSource;

(*---------------------------------------------------------------------------*)

   PUBLIC PROCEDURE LeaveDataSource( CONST DataSource : device.TPDataSource );
   BEGIN
      IF _DataSources.Contains( DataSource ) THEN
         _DataSources.Remove( DataSource );
         OnLeaveDataSource( DataSource );
      END;
   END LeaveDataSource;

(*---------------------------------------------------------------------------*)

   INTERNAL VIRTUAL PROCEDURE OnJoinDataSource( CONST DataSource : device.TPDataSource );
   BEGIN
      // connect to namespace
      _Namespace.Link( DataSource^.NS()^.Name, DataSource^.NS());
      // link advising
      IF device.capAdviseSource IN DataSource^.DataSourceCapabilities THEN
         DataSource^.AdviseSource()^.Advise := _Advise;
         DataSource^.AdviseSource()^.AdviseListener := ADR( SELF );
      END;
   END OnJoinDataSource;

(*---------------------------------------------------------------------------*)

   INTERNAL VIRTUAL PROCEDURE OnLeaveDataSource( CONST DataSource : device.TPDataSource );
   VAR
      child : ns.TPNameValuePairs;
   BEGIN
      // disconnect from namespace
      _Namespace.Unlink( DataSource^.NS()^.Name, OUT child );
      // unlink advising
      IF device.capAdviseSource IN DataSource^.DataSourceCapabilities THEN
         DataSource^.AdviseSource()^.Advise := ns.advNone;
         DataSource^.AdviseSource()^.AdviseListener := NIL;
      END;
   END OnLeaveDataSource;

(*---------------------------------------------------------------------------*)

BEGIN
FINALLY
   Dispose();
END CCompositeDataSource;

(*===========================================================================*)

END compositedatasource.