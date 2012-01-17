IMPLEMENTATION MODULE ns;
// exists to give a place for definitions

(*--------------------------------------------------------------------------------*)

FROM Storage IMPORT
   ALLOCATE, DEALLOCATE;

(*--------------------------------------------------------------------------------*)

VAR
   NameName : StringsO.CString;
   NameParent : StringsO.CString;
   NamePrototype : StringsO.CString;

(*--------------------------------------------------------------------------------*)

PROCEDURE nameName() : POINTER TO CONST StringsO.IString;
BEGIN
   IF NameName.Empty THEN
      NameName := StringsO.FromOA( L"#name" );
   END;
   RETURN ADR( NameName );
END nameName;

(*--------------------------------------------------------------------------------*)

PROCEDURE nameParent() : POINTER TO CONST StringsO.IString;
BEGIN
   IF NameParent.Empty THEN
      NameParent := StringsO.FromOA( L"#parent" );
   END;
   RETURN ADR( NameParent );
END nameParent;

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