IMPLEMENTATION MODULE Tls;
// Modula2 ThreadLocalStorage

FROM Storage IMPORT
   ALLOCATE, DEALLOCATE;

FROM Debug IMPORT
   AssertionW;

IMPORT
   windows;

(*================================================================================*)

TYPE
   TPThreadLocalStorage = POINTER TO CThreadLocalStorage;

CLASS CThreadLocalStorage IMPLEMENTS IThreadLocalStorage;

   // IThreadLocalStorage
   PUBLIC VIRTUAL PROPERTY
      Value : PTR;

   // SELF
   PUBLIC READONLY PROPERTY
      Valid : BOOLEAN;

   PRIVATE VAR
      _TlsIndex : CARDINAL;

END CThreadLocalStorage;

(*--------------------------------------------------------------------------------*)

CLASS IMPLEMENTATION CThreadLocalStorage;

(*--------------------------------------------------------------------------------*)

   PUBLIC VIRTUAL PROPERTY Value GET : PTR;
   BEGIN
      IF Valid THEN
         RETURN windows.TlsGetValue( _TlsIndex );
      ELSE
         RETURN NIL;
      END;
   END Value;

(*--------------------------------------------------------------------------------*)

   PUBLIC VIRTUAL PROPERTY Value SET( value : PTR );
   BEGIN
      IF Valid THEN
         windows.TlsSetValue( _TlsIndex, value );
      END;
   END Value;

(*--------------------------------------------------------------------------------*)

   PUBLIC PROPERTY Valid GET : BOOLEAN;
   BEGIN
      RETURN _TlsIndex <> windows.TLS_OUT_OF_INDEXES;
   END Valid;

(*--------------------------------------------------------------------------------*)

BEGIN
   _TlsIndex := windows.TlsAlloc();
   ASSERTLOG( Valid, L"Unable to get TlsIndex" );
FINALLY
   IF Valid THEN
      windows.TlsFree( _TlsIndex );
      _TlsIndex := windows.TLS_OUT_OF_INDEXES;
   END;
END CThreadLocalStorage;

(*================================================================================*)

PROCEDURE Create( OUT Tls : TPIThreadLocalStorage ) : BOOLEAN;
VAR
   tls : TPThreadLocalStorage;
BEGIN
   NEW( tls );
   IF tls^.Valid THEN
      Tls := tls;
      RETURN TRUE;
   ELSE
      DISPOSE( tls );
      RETURN FALSE;
   END;
END Create;

(*--------------------------------------------------------------------------------*)

PROCEDURE Dispose( REF Tls : TPIThreadLocalStorage );
BEGIN
   IF Tls = NIL THEN
      RETURN;
   ELSIF Tls^ IS CThreadLocalStorage THEN
      DISPOSE( TPThreadLocalStorage( Tls ));
   ELSE
      ASSERTLOG( FALSE, L"Trial to deallocate Tls of improper type" );
   END;
END Dispose;

(*================================================================================*)

END Tls.
