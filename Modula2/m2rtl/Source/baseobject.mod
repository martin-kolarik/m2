IMPLEMENTATION MODULE baseobject; // dummy, for CONST cidPlugin and interfaces/RTTI

(*---------------------------------------------------------------------------*)

FROM Debug IMPORT
   AssertionW;

IMPORT
   Sync;

(*===========================================================================*)

CLASS IMPLEMENTATION BASE;
END BASE;

(*===========================================================================*)

CLASS IMPLEMENTATION CDisposable;

(*---------------------------------------------------------------------------*)

   PUBLIC VIRTUAL PROCEDURE Dispose();
   BEGIN
   END Dispose;

(*---------------------------------------------------------------------------*)

   PUBLIC VIRTUAL FINALLY CDisposable();
   BEGIN
      // Dispose(); -- not needed, no implementation inside Dispose
   END CDisposable;

(*---------------------------------------------------------------------------*)

END CDisposable;

(*===========================================================================*)

CLASS IMPLEMENTATION CRefcounterImplHelper;

(*---------------------------------------------------------------------------*)

   PUBLIC FINAL PROPERTY References GET : CARDINAL;
   BEGIN
		RETURN Sync.IGet( REF _References );
   END References;

(*---------------------------------------------------------------------------*)

   PUBLIC FINAL PROCEDURE AddRef() : CARDINAL;
   VAR
      references : CARDINAL := Sync.IInc( REF _References );
   BEGIN
      IF ( references = 1 ) AND ( _Client <> NIL ) THEN // first AddRef
         _Client^.OnFirstAddRef( ADR( IRefcounter ));
      END;
      RETURN references;
   END AddRef;

(*---------------------------------------------------------------------------*)

   PUBLIC FINAL PROCEDURE Release() : CARDINAL;
   VAR
      references : CARDINAL := Sync.IDec( REF _References );
   BEGIN
      IF references = -1 THEN // underflow, errorneous state
         ASSERTLOG( FALSE );
         RETURN 0;

      ELSIF references > 0 THEN // not released yet
         RETURN references;

      ELSE // released just now
         IF _Client <> NIL THEN
            _Client^.OnLastRelease( ADR( IRefcounter ));
         END;
         RETURN 0;

      END; // IF
   END Release;

(*---------------------------------------------------------------------------*)

   PUBLIC PROPERTY Client GET : TPIRefcounterClient;
   BEGIN
      RETURN _Client;
   END Client;

(*---------------------------------------------------------------------------*)

   PUBLIC PROPERTY Client SET( Value : TPIRefcounterClient );
   BEGIN
      _Client := Value;
   END Client;

(*---------------------------------------------------------------------------*)

BEGIN
END CRefcounterImplHelper;

(*===========================================================================*)

CLASS IMPLEMENTATION CRefcounted;

(*---------------------------------------------------------------------------*)

   PUBLIC FINAL PROPERTY References GET : CARDINAL;
   BEGIN
		RETURN _Refcounter.References;
   END References;

(*---------------------------------------------------------------------------*)

   PUBLIC FINAL PROCEDURE AddRef() : CARDINAL;
   BEGIN
      RETURN _Refcounter.AddRef();
   END AddRef;

(*---------------------------------------------------------------------------*)

   PUBLIC FINAL PROCEDURE Release() : CARDINAL;
   BEGIN 
      RETURN _Refcounter.Release();
   END Release;

(*---------------------------------------------------------------------------*)

   LOCAL FINAL PROCEDURE OnFirstAddRef( CONST Source : TPIRefcounter );
   BEGIN
      // intentionally left empty
   END OnFirstAddRef;

(*---------------------------------------------------------------------------*)

   LOCAL FINAL PROCEDURE OnLastRelease( CONST Source : TPIRefcounter );
   VAR
      a : TPRefcounted := ADR( SELF );
   BEGIN
      a^.Dispose();
      DISPOSE( a );
   END OnLastRelease;

(*---------------------------------------------------------------------------*)

   PRIVATE OPERATOR DISPOSE( a : ADDRESS );
   BEGIN
      DEALLOCATE( REF a );
   END DISPOSE;

(*---------------------------------------------------------------------------*)

BEGIN
   _Refcounter.AddRef(); // initialize counter to 1
END CRefcounted;

(*===========================================================================*)

END baseobject.
