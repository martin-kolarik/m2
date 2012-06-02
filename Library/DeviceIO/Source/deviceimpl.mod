IMPLEMENTATION MODULE deviceimpl;

(*================================================================================*)

CLASS IMPLEMENTATION CSimpleDataSource;

(*--------------------------------------------------------------------------------*)

   PUBLIC VIRTUAL PROCEDURE Dispose();
   BEGIN
      _Namespace.Dispose();
      IF _AdviseSource <> NIL THEN
         // _AdviseSource^.Dispose();
         DISPOSE( _AdviseSource );
      END;
   END Dispose;

(*--------------------------------------------------------------------------------*)

   PUBLIC VIRTUAL PROCEDURE Configure( CONST Source : ARRAY OF device.TConfigureItem; CONST Log : log.TPLogger ) : Sync.TAsyncResult; // Log is mandatory
   BEGIN
      RETURN Sync.arCompleted;
   END Configure;

(*--------------------------------------------------------------------------------*)

   PUBLIC VIRTUAL PROPERTY DataSourceCapabilities GET : device.TCapabilities;
   BEGIN
      IF _AdviseSource = NIL THEN
         RETURN device.TCapabilities{};
      ELSE
         RETURN device.TCapabilities{ device.capAdviseSource };
      END;
   END DataSourceCapabilities;

(*--------------------------------------------------------------------------------*)

   PUBLIC VIRTUAL PROCEDURE NS() : ns.TPNamespace; // required, handles both naming and IO
   BEGIN
      RETURN ADR( _Namespace );
   END NS;

(*--------------------------------------------------------------------------------*)

   PUBLIC VIRTUAL PROCEDURE AdviseSource() : ns.TPAdviseSource; // optional
   BEGIN
      RETURN _AdviseSource;
   END AdviseSource;

(*--------------------------------------------------------------------------------*)

   PUBLIC PROCEDURE Init( CONST NamespaceRootName : StringsO.IString; AdviseSource : BOOLEAN );
   VAR
      s : StringsO.CString;
   BEGIN
      Dispose();

      s.Assign( NamespaceRootName );
      _Namespace.InitializeName := s;

      IF AdviseSource THEN
         NEW( _AdviseSource );
      END;
   END Init;

(*--------------------------------------------------------------------------------*)

BEGIN
FINALLY
   Dispose();
END CSimpleDataSource;

(*================================================================================*)

END deviceimpl.
