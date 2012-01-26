IMPLEMENTATION MODULE ns;
// exists to give a place for definitions

(*--------------------------------------------------------------------------------*)

FROM Storage IMPORT
   ALLOCATE, DEALLOCATE;

(*--------------------------------------------------------------------------------*)

VAR
   NamePrototype : StringsO.CString;

(*--------------------------------------------------------------------------------*)

PROCEDURE namePrototype() : POINTER TO CONST StringsO.IString;
BEGIN
   IF NamePrototype.Empty THEN
      NamePrototype := StringsO.FromOA( L"#prototype" );
   END;
   RETURN ADR( NamePrototype );
END namePrototype;

(*--------------------------------------------------------------------------------*)

END ns.