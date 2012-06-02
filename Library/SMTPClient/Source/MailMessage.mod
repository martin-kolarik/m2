IMPLEMENTATION MODULE MailMessage;

FROM Debug IMPORT
   AssertionW;

IMPORT
   PersonsImpl,
   StorageO;

(*================================================================================*)

CLASS CMailMessage IMPLEMENTS IMailMessage;

   PUBLIC VIRTUAL PROPERTY
      Sender : MailPerson.Person;
      ReplyTo : MailPerson.Person; // until set, it shares the value with Sender
      Recipient : MailPerson.Person; // for fast access to single recipient
      Priority : TPriority;
      Subject : StringsO.CString;
      BodyMimeType : StringsO.CString;
      GrabFailedRecipients : BOOLEAN;

   PUBLIC VIRTUAL READONLY PROPERTY
      Created : datetime.DateTime;
      Recipients : MailPerson.TPPersons;
      CCs : MailPerson.TPPersons;
      BCCs : MailPerson.TPPersons;
      Body : IOO.TPStream;
      Attachments : lists.TPStringStringList; // list of paths

   PRIVATE VAR
      _Created : datetime.DateTime;
      _Sender : MailPerson.Person;
      _ReplyTo : MailPerson.Person;
      _Subject : StringsO.CString;
      _Priority : TPriority := PriorityNormal;
      _Recipients : PersonsImpl.CPersonsImpl;
      _CCs : PersonsImpl.CPersonsImpl;
      _BCCs : PersonsImpl.CPersonsImpl;
      _Body : StorageO.CMemoryBuffer;
      _BodyMimeType : StringsO.CString;
      _BodyStream : IOO.CMemoryBufferStream;
      _Attachments : lists.CStringStringList;
      _GrabFailedRecipients : BOOLEAN := FALSE;

END CMailMessage;

(*--------------------------------------------------------------------------------*)

CLASS IMPLEMENTATION CMailMessage;

(*--------------------------------------------------------------------------------*)

   PUBLIC VIRTUAL PROPERTY Sender GET : MailPerson.Person;
   BEGIN
      RETURN _Sender;
   END Sender;

(*--------------------------------------------------------------------------------*)

   PUBLIC VIRTUAL PROPERTY Sender SET( CONST Value : MailPerson.Person );
   BEGIN
      _Sender := Value;
   END Sender;

(*--------------------------------------------------------------------------------*)

   PUBLIC VIRTUAL PROPERTY ReplyTo GET : MailPerson.Person; // until set, it shares the value with Sender
   BEGIN
      IF _ReplyTo.Name.Empty AND _ReplyTo.Address.Empty THEN
         RETURN _Sender;
      ELSE
         RETURN _ReplyTo;
      END;
   END ReplyTo;

(*--------------------------------------------------------------------------------*)

   PUBLIC VIRTUAL PROPERTY ReplyTo SET( CONST Value : MailPerson.Person );
   BEGIN
      _ReplyTo := Value;
   END ReplyTo;

(*--------------------------------------------------------------------------------*)

   PUBLIC VIRTUAL PROPERTY Recipient GET : MailPerson.Person; // for fast access to single recipient
   VAR
      person : MailPerson.Person;
   BEGIN
      _Recipients.Reset();
      IF _Recipients.MoveNext() THEN
         RETURN _Recipients.Current;
      ELSE
         RETURN person;
      END;
   END Recipient;

(*--------------------------------------------------------------------------------*)

   PUBLIC VIRTUAL PROPERTY Recipient SET( CONST Value : MailPerson.Person ); // for fast access to single recipient
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

   PUBLIC VIRTUAL PROPERTY GrabFailedRecipients GET : BOOLEAN;
   BEGIN
      RETURN _GrabFailedRecipients;
   END GrabFailedRecipients;

(*--------------------------------------------------------------------------------*)

   PUBLIC VIRTUAL PROPERTY GrabFailedRecipients SET( Value : BOOLEAN );
   BEGIN
      _GrabFailedRecipients := Value;
   END GrabFailedRecipients;

(*--------------------------------------------------------------------------------*)

   PUBLIC VIRTUAL PROPERTY Created GET : datetime.DateTime;
   BEGIN
      RETURN _Created;
   END Created;

(*--------------------------------------------------------------------------------*)

   PUBLIC VIRTUAL PROPERTY Recipients GET : MailPerson.TPPersons;
   BEGIN
      RETURN ADR( _Recipients );
   END Recipients;

(*--------------------------------------------------------------------------------*)

   PUBLIC VIRTUAL PROPERTY CCs GET : MailPerson.TPPersons;
   BEGIN
      RETURN ADR( _CCs );
   END CCs;

(*--------------------------------------------------------------------------------*)

   PUBLIC VIRTUAL PROPERTY BCCs GET : MailPerson.TPPersons;
   BEGIN
      RETURN ADR( _BCCs );
   END BCCs;

(*--------------------------------------------------------------------------------*)

   PUBLIC VIRTUAL PROPERTY Body GET : IOO.TPStream;
   BEGIN
      RETURN ADR( _BodyStream );
   END Body;

(*--------------------------------------------------------------------------------*)

   PUBLIC VIRTUAL PROPERTY Attachments GET : lists.TPStringStringList; // list of paths
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