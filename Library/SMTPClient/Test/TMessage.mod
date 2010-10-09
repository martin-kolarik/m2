MODULE TMessage;

FROM Storage IMPORT
   ALLOCATE, DEALLOCATE;

IMPORT
   datetime,
   MailMessage,
   log,
   StringsO,
   test,
   testimpl;
  
(*===========================================================================*)

CLASS CTest IMPLEMENTS test.ITest;
   PUBLIC VIRTUAL PROCEDURE Run( CONST Host : test.TPHost; CONST Parameters : ARRAY OF PWCHAR ) : test.TTestResult;
END CTest;

(*===========================================================================*)

VAR
   TestMessage : CTest;

(*---------------------------------------------------------------------------*)

CLASS IMPLEMENTATION CTest;

(*---------------------------------------------------------------------------*)

   PUBLIC VIRTUAL PROCEDURE Run( CONST Host : test.TPHost; CONST Parameters : ARRAY OF PWCHAR ) : test.TTestResult;
   VAR
      message : MailMessage.TPMailMessage;
      person : MailMessage.Person;
      personAssigned : MailMessage.Person;
   BEGIN
      //-----
      Host^.StartPhase( L"Person filling" );
      person.Name.FromOA( L"Martin Kolaøík" );
      person.Address.FromOA( L"martin.kolarik@smartcontrol.cz" );
      IF person.Name.EqualsOA( L"Martin Kolaøík" ) AND
         person.Address.EqualsOA( L"martin.kolarik@smartcontrol.cz" ) THEN
         Host^.StopPhaseWithResult( test.trSuccess );
      ELSE
         Host^.StopPhaseWithResult( test.trFailure );
      END;

      //-----
      Host^.StartPhase( L"Person assignment" );
      personAssigned := person;
      IF ( person.Name.Data = personAssigned.Name.Data ) AND
         ( person.Address.Data = personAssigned.Address.Data ) THEN
         Host^.StopPhaseWithResult( test.trSuccess );
      ELSE
         Host^.StopPhaseWithResult( test.trFailure );
      END;

      //-----
      Host^.StartPhase( L"Create the message" );
      IF MailMessage.New( OUT message ) THEN
         Host^.StopPhaseWithResult( test.trSuccess );
      ELSE
         Host^.StopPhaseWithResult( test.trFailure );
      END;

      //-----
      Host^.StartPhase( L"Check initial state" );
      IF ( message^.Created <= datetime.NowUTC()) AND
         ( message^.Recipients <> NIL ) AND
         ( message^.CCs <> NIL ) AND
         ( message^.BCCs <> NIL ) AND
         ( message^.Body <> NIL ) AND
         ( message^.Attachments <> NIL ) THEN
         Host^.StopPhaseWithResult( test.trSuccess );
      ELSE
         Host^.StopPhaseWithResult( test.trFailure );
      END;

      //-----
      Host^.StartPhase( L"Fill simple data" );
      message^.Sender := person;
      message^.ReplyTo := person;
      message^.Priority := MailMessage.PriorityHigh;
      message^.Subject := StringsO.FromOA( L"A subject of the test mail, with ìšèøž too" );
      message^.BodyMimeType := StringsO.FromOA( L"text/html" );
      IF ( message^.Sender.Name = person.Name ) AND
         ( message^.Sender.Address = person.Address ) AND
         ( message^.ReplyTo.Name = person.Name ) AND
         ( message^.ReplyTo.Address = person.Address ) AND
           message^.Subject.EqualsOA( L"A subject of the test mail, with ìšèøž too" ) AND
           message^.BodyMimeType.EqualsOA( L"text/html" ) THEN
         Host^.StopPhaseWithResult( test.trSuccess );
      ELSE
         Host^.StopPhaseWithResult( test.trFailure );
      END;

      //-----
      Host^.StartPhase( L"Single recipient in recipients" );
      message^.Recipient := person;
      message^.Recipients^.Reset();
      IF NOT message^.Recipients^.Empty AND
         message^.Recipients^.MoveNext() AND
         ( message^.Recipients^.Current.Name = person.Name ) AND
         ( message^.Recipients^.Current.Address = person.Address ) AND
         NOT message^.Recipients^.MoveNext() THEN
         Host^.StopPhaseWithResult( test.trSuccess );
      ELSE
         Host^.StopPhaseWithResult( test.trFailure );
      END;

      //-----
      Host^.StartPhase( L"More recipients" );
      message^.Recipients^.Dispose();
      message^.Recipients^.Add( person );
      message^.Recipients^.AddS( person.Name, person.Address );
      message^.Recipients^.Add( person );
      message^.Recipients^.Reset();
      IF NOT message^.Recipients^.Empty AND
         message^.Recipients^.MoveNext() AND
         message^.Recipients^.MoveNext() AND
         message^.Recipients^.MoveNext() AND
         ( message^.Recipients^.Current.Name = person.Name ) AND
         ( message^.Recipients^.Current.Address = person.Address ) AND
         NOT message^.Recipients^.MoveNext() THEN
         Host^.StopPhaseWithResult( test.trSuccess );
      ELSE
         Host^.StopPhaseWithResult( test.trFailure );
      END;

      //-----
      Host^.StartPhase( L"Single recipient resets recipients" );
      message^.Recipient := person;
      message^.Recipients^.Reset();
      IF NOT message^.Recipients^.Empty AND
         message^.Recipients^.MoveNext() AND
         ( message^.Recipients^.Current.Name = person.Name ) AND
         ( message^.Recipients^.Current.Address = person.Address ) AND
         NOT message^.Recipients^.MoveNext() THEN
         Host^.StopPhaseWithResult( test.trSuccess );
      ELSE
         Host^.StopPhaseWithResult( test.trFailure );
      END;

      //-----
      Host^.StartPhase( L"Dispose recipients" );
      message^.Recipients^.Dispose();
      IF message^.Recipients^.Empty THEN
         Host^.StopPhaseWithResult( test.trSuccess );
      ELSE
         Host^.StopPhaseWithResult( test.trFailure );
      END;

      RETURN test.trSuccess;
   END Run;

(*---------------------------------------------------------------------------*)

BEGIN
   testimpl.tests()^.AddTest( L"Message", ADR( TestMessage ));
END CTest;

(*===========================================================================*)

END TMessage.