MODULE iface;

(*===========================================================================*)

IMPORT
   objlib;

(*===========================================================================*)

CLASS CCreator( objlib.ACreator );
END CCreator;

(*---------------------------------------------------------------------------*)

CLASS IMPLEMENTATION CCreator;
END CCreator;

(*===========================================================================*)

VAR
   Creator : CCreator;

#save, call( convention => cdecl )
PROCEDURE GetObject( CONST ClassPath : ARRAY OF WCHAR; OUT Object : objlib.TPObject ) : objlib.TResult;
#restore
BEGIN
   RETURN Creator.GetObject( ClassPath, OUT Object );
END GetObject;

(*===========================================================================*)

END iface.