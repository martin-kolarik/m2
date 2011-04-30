IMPLEMENTATION MODULE baseobject; // dummy, for CONST cidPlugin and interfaces/RTTI

(*===========================================================================*)

CLASS IMPLEMENTATION CDisposable;

(*---------------------------------------------------------------------------*)

   PUBLIC VIRTUAL PROCEDURE Dispose();
   BEGIN
   END Dispose;

(*---------------------------------------------------------------------------*)

   PUBLIC VIRTUAL FINALLY CDisposable();
   BEGIN
      Dispose();
   END CDisposable;

(*---------------------------------------------------------------------------*)

END CDisposable;

(*===========================================================================*)

END baseobject.
