IMPLEMENTATION MODULE testimpl;

FROM Storage IMPORT
   ALLOCATE, DEALLOCATE;

(*================================================================================*)

CLASS CTests( test.ATests );
   PUBLIC VIRTUAL PROCEDURE LibraryInfo( OUT Library, LibraryVersionString : ARRAY OF WCHAR );
END CTests;

(*--------------------------------------------------------------------------------*)

CLASS IMPLEMENTATION CTests;

(*--------------------------------------------------------------------------------*)

   PUBLIC VIRTUAL PROCEDURE LibraryInfo( OUT Library, LibraryVersionString : ARRAY OF WCHAR );
   BEGIN
      Library := ProductId;
      LibraryVersionString := ProductVersion;
   END LibraryInfo;

(*---------------------------------------------------------------------------*)

END CTests;

(*================================================================================*)

VAR
   Tests : POINTER TO CTests := NIL;

(*---------------------------------------------------------------------------*)

PROCEDURE tests() : test.TPTests;
BEGIN
   IF Tests = NIL THEN
      NEW( Tests );
   END;
   RETURN Tests;
END tests;

(*================================================================================*)

END testimpl.