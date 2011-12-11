IMPLEMENTATION MODULE PersonsImpl;

FROM Debug IMPORT
   AssertionW;

IMPORT
   collection;

(*================================================================================*)

CLASS IMPLEMENTATION CPersonsImpl;

(*--------------------------------------------------------------------------------*)

   PUBLIC VIRTUAL PROCEDURE Add( CONST New : MailPerson.Person );
   BEGIN
      _Persons.Add( New.Name, New.Address );
   END Add;

(*--------------------------------------------------------------------------------*)

   PUBLIC VIRTUAL PROCEDURE AddS( CONST Name, Address : StringsO.IString );
   BEGIN
      _Persons.Add( Name, Address );
   END AddS;

(*--------------------------------------------------------------------------------*)

   PUBLIC VIRTUAL PROCEDURE Dispose();
   BEGIN
      _Persons.Dispose();
   END Dispose;

(*--------------------------------------------------------------------------------*)

   PUBLIC VIRTUAL PROPERTY Empty GET : BOOLEAN;
   BEGIN
      RETURN _Persons.Empty;
   END Empty;

(*--------------------------------------------------------------------------------*)

   PUBLIC VIRTUAL PROPERTY Current GET : MailPerson.Person;
   VAR
      person : MailPerson.Person;
   BEGIN
      IF _Iterator.Value <> NIL THEN
         person.Name.Assign( _Iterator.Value^ );
         person.Address.Assign( _Iterator.Data^ );
      END;
      RETURN person;
   END Current;

(*--------------------------------------------------------------------------------*)

   PUBLIC VIRTUAL PROPERTY Current SET( CONST Value : MailPerson.Person );
   BEGIN
      IF _Iterator.Value = NIL THEN
         ASSERTLOG( FALSE, L"Current value assigned when Current is not valid." );
      ELSE
         _Iterator.Value^.Assign( Value.Name );
         _Iterator.Data^.Assign( Value.Address );
      END;
   END Current;

(*--------------------------------------------------------------------------------*)

   PUBLIC VIRTUAL PROCEDURE Reset();
   BEGIN
      _Iterator.Reset();
   END Reset;

(*--------------------------------------------------------------------------------*)

   PUBLIC VIRTUAL PROCEDURE MoveNext() : BOOLEAN;
   BEGIN
      RETURN _Iterator.MoveNext();
   END MoveNext;

(*--------------------------------------------------------------------------------*)

BEGIN
   _Iterator.Init( _Persons, collection.dirForward );
END CPersonsImpl;

(*================================================================================*)

END PersonsImpl.