IMPLEMENTATION MODULE MailMessage;

(*================================================================================*)

CLASS IMPLEMENTATION Person;

(*--------------------------------------------------------------------------------*)

   PUBLIC OPERATOR :=( CONST Source : Person );
   BEGIN
      Address := Source.Address;
      Name := Source.Name;
   END :=;

(*--------------------------------------------------------------------------------*)

END Person;

(*================================================================================*)

CLASS CPersons IMPLEMENTS IPersons;

   // IPersons
   PUBLIC VIRTUAL PROCEDURE Add( CONST New : Person );
   PUBLIC VIRTUAL PROCEDURE AddS( CONST Name, Address : StringsO.CString );
   PUBLIC VIRTUAL PROCEDURE Clear();

   PUBLIC VIRTUAL PROPERTY
      Current : Person;
   PUBLIC VIRTUAL PROCEDURE Reset();
   PUBLIC VIRTUAL PROCEDURE MoveNext() : BOOLEAN;

   // SELF
   PRIVATE VAR
      _Persons : lists.CStringStringList;

END CPersons;

(*--------------------------------------------------------------------------------*)

CLASS IMPLEMENTATION CPersons;

(*--------------------------------------------------------------------------------*)

   PUBLIC VIRTUAL PROCEDURE Add( CONST New : Person );
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

   PUBLIC VIRTUAL PROPERTY Current GET : Person;
   VAR
      person : Person;
   BEGIN
      IF _Persons.Current <> NIL THEN
         persons.Name.Assign( _Persons.Current^ );
         persons.Address.Assign( _Persons.CurrentData^ );
      END;
      RETURN person;
   END Current;

(*--------------------------------------------------------------------------------*)

   PUBLIC VIRTUAL PROPERTY Current SET( CONST Value : Person );
   BEGIN
      IF _Persons.Current = NIL THEN
         ASSERTLOG( FALSE, L"Current value assigned when Current is not valid." );
      ELSE
         _Persons.Current^.Assign( persons.Name );
         _Persons.CurrentData^.Assign( persons.Address );
      END;
   END Current;

(*--------------------------------------------------------------------------------*)

   PUBLIC VIRTUAL PROCEDURE Reset();
   BEGIN
      _Persons.Reset();
   END Reset;

(*--------------------------------------------------------------------------------*)

   PUBLIC VIRTUAL PROCEDURE MoveNext() : BOOLEAN;
   BEGIN
      RETURN _Persons.MoveNext();
   END MoveNext;

(*--------------------------------------------------------------------------------*)

END CPersons;

(*================================================================================*)

CLASS CMailMessage IMPLEMENTS IMailMessage;

   PUBLIC VIRTUAL PROPERTY
      Sender : Person;
      ReplyTo : Person; // until set, it shares the value with Sender
      Recipient : Person; // for fast access to single recipient
      Priority : TPriority;
      Subject : StringsO.CString;

   PUBLIC VIRTUAL READONLY PROPERTY
      Recipients : TPPersons;
      CCs : TPPersons;
      BCCs : TPPersons;
      Message : IOO.TPStream;
      Attachments : lists.TPStringList; // list of paths

   PRIVATE VAR
      _Sender : Person;
      _ReplyTo : StringsO.CString;
      _Subject : StringsO.CString;
      _Priority : TPriority := PriorityNormal;
      _Recipients : CPersons;
      _CCs : CPersons;
      _BCCs : CPersons;
      _Message : StorageO.CMemoryBuffer;
      _Stream : IOO.CMemoryBufferStream;
      _Attachments : lists.CStringList;

END CMailMessage;

(*--------------------------------------------------------------------------------*)

CLASS IMPLEMENTATION CMailMessage;

(*--------------------------------------------------------------------------------*)

   PUBLIC VIRTUAL PROPERTY Sender GET : Person;
   BEGIN
      RETURN _Sender;
   END Sender;

(*--------------------------------------------------------------------------------*)

   PUBLIC VIRTUAL PROPERTY Sender SET( Value : Person );
   BEGIN
      _Sender := Value;
   END Sender;

(*--------------------------------------------------------------------------------*)

   PUBLIC VIRTUAL PROPERTY ReplyTo GET : Person; // until set, it shares the value with Sender
   BEGIN
      IF _ReplyTo.Name.Empty AND _ReplyTo.Address.Empty THEN
         RETURN _Sender;
      ELSE
         RETURN _ReplyTo;
      END;
   END ReplyTo;

(*--------------------------------------------------------------------------------*)

   PUBLIC VIRTUAL PROPERTY _ReplyTo SET( Value : Person );
   BEGIN
      _ReplyTo := Value;
   END _ReplyTo;

(*--------------------------------------------------------------------------------*)

   PUBLIC VIRTUAL PROPERTY Recipient GET : Person; // for fast access to single recipient
   VAR
      person : Person;
   BEGIN
      _Recipients.GetFirst( OUT person.Name, OUT person.Address );
      RETURN person;
   END Recipient;

(*--------------------------------------------------------------------------------*)

   PUBLIC VIRTUAL PROPERTY Recipient SET( Value : Person ); // for fast access to single recipient
   BEGIN
      _Recipients.Dispose();
      _Recipients.Add( Value.Name, Value.Address );
   END Recipient;

(*--------------------------------------------------------------------------------*)

   PUBLIC VIRTUAL PROPERTY Priority GET : TPriority;
   BEGIN
      RETURN _Priority;
   END Priority;

(*--------------------------------------------------------------------------------*)

   PUBLIC VIRTUAL PROPERTY Priority SET( Value : TPriority );
   BEGIN
      _Priority := Value;
   END Priority;

(*--------------------------------------------------------------------------------*)

   PUBLIC VIRTUAL PROPERTY Subject GET : StringsO.CString;
   BEGIN
      RETURN _Subject;
   END Subject;

(*--------------------------------------------------------------------------------*)

   PUBLIC VIRTUAL PROPERTY Subject SET( Value : StringsO.CString );
   BEGIN
      _Subject := Value;
   END Subject;

(*--------------------------------------------------------------------------------*)

   PUBLIC VIRTUAL PROPERTY Recipients GET : TPPersons;
   BEGIN
      RETURN ADR( _Recipients );
   END Recipients;

(*--------------------------------------------------------------------------------*)

   PUBLIC VIRTUAL PROPERTY CCs GET : TPPersons;
   BEGIN
      RETURN ADR( _CCs );
   END CCs;

(*--------------------------------------------------------------------------------*)

   PUBLIC VIRTUAL PROPERTY BCCs GET : TPPersons;
   BEGIN
      RETURN ADR( _BCCs );
   END BCCs;

(*--------------------------------------------------------------------------------*)

   PUBLIC VIRTUAL PROPERTY Message GET : IOO.TPStream;
   BEGIN
      RETURN ADR( _Stream );
   END Message;

(*--------------------------------------------------------------------------------*)

   PUBLIC VIRTUAL PROPERTY Attachments GET : lists.TPStringList; // list of paths
   BEGIN
      RETURN ADR( _Attachments );
   END Attachments;

(*--------------------------------------------------------------------------------*)

BEGIN
   _Stream.Init( REF _Buffer, IOO.accReadWrite );
END CMailMessage;

(*================================================================================*)

PROCEDURE New( OUT Message : TPMailMessage ) : BOOLEAN;
VAR
   message : TPMessage;
BEGIN
   NEW( message );
   IF message = NIL THEN
      RETURN FALSE;
   ELSE
      Message := message;
      RETURN TRUE;
   END;
END New;

(*--------------------------------------------------------------------------------*)

PROCEDURE Dispose( REF Message : TPMailMessage );
BEGIN
   IF Message = NIL THEN
      // do nothing
   ELSIF NOT( Message IS CMessage ) THEN
      ASSERTLOG( FALSE, L"Bad deallocation" );
   ELSE
      DISPOSE( REF Message );
   END;
END Dispose;

(*================================================================================*)

END MailMessage.