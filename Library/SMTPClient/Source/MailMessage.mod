IMPLEMENTATION MODULE MailMessage;

FROM Debug IMPORT
   Assertion, LogAssertionW;

IMPORT
   StorageO;

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
   PUBLIC VIRTUAL PROCEDURE AddS( CONST Name, Address : StringsO.IString );
   PUBLIC VIRTUAL PROCEDURE Dispose();

   PUBLIC VIRTUAL READONLY PROPERTY
      Empty : BOOLEAN;
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

   PUBLIC VIRTUAL PROPERTY Empty GET : BOOLEAN;
   BEGIN
      RETURN _Persons.Empty;
   END Empty;

(*--------------------------------------------------------------------------------*)

   PUBLIC VIRTUAL PROPERTY Current GET : Person;
   VAR
      person : Person;
   BEGIN
      IF _Persons.Current <> NIL THEN
         person.Name.Assign( _Persons.Current^ );
         person.Address.Assign( _Persons.CurrentData^ );
      END;
      RETURN person;
   END Current;

(*--------------------------------------------------------------------------------*)

   PUBLIC VIRTUAL PROPERTY Current SET( CONST Value : Person );
   BEGIN
      IF _Persons.Current = NIL THEN
         ASSERTLOG( FALSE, L"Current value assigned when Current is not valid." );
      ELSE
         _Persons.Current^.Assign( Value.Name );
         _Persons.CurrentData^.Assign( Value.Address );
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
      BodyMimeType : StringsO.CString;

   PUBLIC VIRTUAL READONLY PROPERTY
      Created : datetime.DateTime;
      Recipients : TPPersons;
      CCs : TPPersons;
      BCCs : TPPersons;
      Body : IOO.TPStream;
      Attachments : lists.TPStringList; // list of paths

   PRIVATE VAR
      _Created : datetime.DateTime;
      _Sender : Person;
      _ReplyTo : Person;
      _Subject : StringsO.CString;
      _Priority : TPriority := PriorityNormal;
      _Recipients : CPersons;
      _CCs : CPersons;
      _BCCs : CPersons;
      _Body : StorageO.CMemoryBuffer;
      _BodyMimeType : StringsO.CString;
      _BodyStream : IOO.CMemoryBufferStream;
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

   PUBLIC VIRTUAL PROPERTY Sender SET( CONST Value : Person );
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

   PUBLIC VIRTUAL PROPERTY ReplyTo SET( CONST Value : Person );
   BEGIN
      _ReplyTo := Value;
   END ReplyTo;

(*--------------------------------------------------------------------------------*)

   PUBLIC VIRTUAL PROPERTY Recipient GET : Person; // for fast access to single recipient
   VAR
      person : Person;
   BEGIN
      _Recipients.Reset();
      IF _Recipients.MoveNext() THEN
         RETURN _Recipients.Current;
      ELSE
         RETURN person;
      END;
   END Recipient;

(*--------------------------------------------------------------------------------*)

   PUBLIC VIRTUAL PROPERTY Recipient SET( CONST Value : Person ); // for fast access to single recipient
   BEGIN
      _Recipients.Dispose();
      _Recipients.Add( Value );
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

   PUBLIC VIRTUAL PROPERTY Subject SET( CONST Value : StringsO.CString );
   BEGIN
      _Subject := Value;
   END Subject;

(*--------------------------------------------------------------------------------*)

   PUBLIC VIRTUAL PROPERTY BodyMimeType GET : StringsO.CString;
   BEGIN
      RETURN _BodyMimeType;
   END BodyMimeType;

(*--------------------------------------------------------------------------------*)

   PUBLIC VIRTUAL PROPERTY BodyMimeType SET( CONST Value : StringsO.CString );
   BEGIN
      _BodyMimeType := Value;
   END BodyMimeType;

(*--------------------------------------------------------------------------------*)

   PUBLIC VIRTUAL PROPERTY Created GET : datetime.DateTime;
   BEGIN
      RETURN _Created;
   END Created;

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

   PUBLIC VIRTUAL PROPERTY Body GET : IOO.TPStream;
   BEGIN
      RETURN ADR( _BodyStream );
   END Body;

(*--------------------------------------------------------------------------------*)

   PUBLIC VIRTUAL PROPERTY Attachments GET : lists.TPStringList; // list of paths
   BEGIN
      RETURN ADR( _Attachments );
   END Attachments;

(*--------------------------------------------------------------------------------*)

BEGIN
   _Created.SetNowUTC();
   _BodyStream.Init( REF _Body, IOO.accReadWrite );
END CMailMessage;

(*================================================================================*)

TYPE
   TPMessage = POINTER TO CMailMessage;

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
VAR
   message : TPMessage;
BEGIN
   IF Message = NIL THEN
      // do nothing
   ELSIF Message^ IS CMailMessage THEN
      message := TPMessage( Message );
      DISPOSE( message );
   ELSE
      ASSERTLOG( FALSE, L"Bad deallocation" );
   END;
END Dispose;

(*================================================================================*)

END MailMessage.