MODULE TLightweightSender;

FROM Storage IMPORT
   ALLOCATE, DEALLOCATE;

IMPORT
   MailMessage,
   MailPerson,
   MIME,
   log,
   scinit,
   SmtpSender,
   StringsO,
   Sync,
   test,
   testimpl;
  
(*===========================================================================*)

CLASS CTest IMPLEMENTS test.ITest;
   PUBLIC VIRTUAL PROCEDURE Run( CONST Host : test.TPHost; CONST Parameters : ARRAY OF PWCHAR ) : test.TTestResult;
END CTest;

(*===========================================================================*)

VAR
   TestLightweightSender : CTest;

(*---------------------------------------------------------------------------*)

CLASS IMPLEMENTATION CTest;

(*---------------------------------------------------------------------------*)

   PUBLIC VIRTUAL PROCEDURE Run( CONST Host : test.TPHost; CONST Parameters : ARRAY OF PWCHAR ) : test.TTestResult;
   VAR
      c : CARDINAL;
      e, f : StringsO.CString;
      message : MailMessage.TPMailMessage;
      person1 : MailPerson.Person;
      person2 : MailPerson.Person;
      person3 : MailPerson.Person;
      sender : SmtpSender.TPSender;
      s : StringsO.CString;
   BEGIN
      scinit.Startup();

      //-----
      Host^.StartPhase( L"Create the sender" );
      IF SmtpSender.New( OUT sender, TRUE, FALSE ) THEN
         Host^.StopPhaseWithResult( test.trSuccess );
      ELSE
         Host^.StopPhaseWithResult( test.trFailure );
      END;

      //-----
      Host^.StartPhase( L"Fill simple data" );
      sender^.Mailer := StringsO.FromOA( L"sc" );
      // sender^.Server := StringsO.FromOA( L"smtp.netbox.cz:25" );
      sender^.Server := StringsO.FromOA( L"out.smtp.cz:25" );
      sender^.Login := StringsO.FromOA( L"martin@smartcontrol.cz" );
      sender^.Password := StringsO.FromOA( L"Tankem" );
      IF sender^.Server.EqualsOA( L"out.smtp.cz:25" ) AND
         sender^.Mailer.EqualsOA( L"sc" ) AND
         sender^.Login.EqualsOA( L"martin@smartcontrol.cz" ) AND
         sender^.Password.EqualsOA( L"Tankem" ) AND
         ( sender^.TimeToLive = 2*86400 ) THEN
         Host^.StopPhaseWithResult( test.trSuccess );
      ELSE
         Host^.StopPhaseWithResult( test.trFailure );
      END;

      //-----
      Host^.StartPhase( L"Try to send something" );
      MailMessage.New( OUT message );

      person1.Name := StringsO.FromOA( L"Martin Kolaøík" );
      person1.Address := StringsO.FromOA( L"martin@smartcontrol.cz" );
      message^.Sender := person1;
      message^.Recipient := person1;
      message^.Subject := StringsO.FromOA( L"[SINGLE] Testovací majlíèek mazlíèek pro Pifíèka" );
      message^.Body^.WriteOA( L"Obsah testovacího emailu", OUT c, 0 );

      IF sender^.Send( message, 0, FALSE ) = Sync.arCompleted THEN
         Host^.StopPhaseWithResult( test.trSuccess );
      ELSE
         Host^.StopPhaseWithResult( test.trFailure );
      END;

      MailMessage.Dispose( REF message );

      //-----
      Host^.StartPhase( L"Try to send something, +CC, +BCC" );
      MailMessage.New( OUT message );

      person1.Name := StringsO.FromOA( L"Martin Kolaøík" );
      person1.Address := StringsO.FromOA( L"martin@smartcontrol.cz" );
      person2.Name := StringsO.FromOA( L"Martin Kolaøík" );
      person2.Address := StringsO.FromOA( L"martin.kolarik@email.cz" );
      person3.Name := StringsO.FromOA( L"Martin Kolaøík" );
      person3.Address := StringsO.FromOA( L"martin.kolarik@smartcontrol.cz" );

      message^.Sender := person1;
      message^.ReplyTo := person1;
      message^.Recipients^.Add( person1 );
      message^.CCs^.Add( person2 );
      message^.BCCs^.Add( person3 );
      message^.Subject := StringsO.FromOA( L"[TO CC BCC] Testovací majlíèek mazlíèek pro Pifíèka" );
      message^.BodyMimeType := StringsO.FromOA( L"text/plain; charset = neco; format=flowed; delsp=yes" );

      IF sender^.Send( message, 0, FALSE ) = Sync.arCompleted THEN
         Host^.StopPhaseWithResult( test.trSuccess );
      ELSE
         Host^.StopPhaseWithResult( test.trFailure );
      END;

      MailMessage.Dispose( REF message );

      //-----
      Host^.StartPhase( L"Try to send something, BCC only" );
      MailMessage.New( OUT message );

      person1.Name := StringsO.FromOA( L"Martin Kolaøík" );
      person1.Address := StringsO.FromOA( L"martin@smartcontrol.cz" );
      person2.Name := StringsO.FromOA( L"Martin Kolaøík" );
      person2.Address := StringsO.FromOA( L"martin.kolarik@email.cz" );
      person3.Name := StringsO.FromOA( L"Martin Kolaøík" );
      person3.Address := StringsO.FromOA( L"martin.kolarik@smartcontrol.cz" );

      message^.Sender := person1;
      message^.ReplyTo := person1;
      message^.BCCs^.Add( person1 );
      message^.Subject := StringsO.FromOA( L"[BCC only] Testovací majlíèek mazlíèek pro Pifíèka" );
      message^.BodyMimeType := StringsO.FromOA( L"text/plain; charset = neco; format=flowed; delsp=yes" );

      IF sender^.Send( message, 0, FALSE ) = Sync.arCompleted THEN
         Host^.StopPhaseWithResult( test.trSuccess );
      ELSE
         Host^.StopPhaseWithResult( test.trFailure );
      END;

      MailMessage.Dispose( REF message );

      //-----
      Host^.StartPhase( L"Try to send something, TO, 2xCC" );
      MailMessage.New( OUT message );

      person1.Name := StringsO.FromOA( L"Martin Kolaøík" );
      person1.Address := StringsO.FromOA( L"martin@smartcontrol.cz" );
      person2.Name := StringsO.FromOA( L"Martin Kolaøík" );
      person2.Address := StringsO.FromOA( L"martin.kolarik@email.cz" );
      person3.Name := StringsO.FromOA( L"Martin Kolaøík" );
      person3.Address := StringsO.FromOA( L"martin.kolarik@smartcontrol.cz" );

      message^.Sender := person1;
      message^.ReplyTo := person1;
      message^.Recipient := person1;
      message^.CCs^.Add( person2 );
      message^.CCs^.Add( person3 );
      message^.Subject := StringsO.FromOA( L"[TO 2xCC] Testovací majlíèek mazlíèek pro Pifíèka" );
      message^.BodyMimeType := StringsO.FromOA( L"text/plain; charset = neco; format=flowed; delsp=yes" );

      IF sender^.Send( message, 0, FALSE ) = Sync.arCompleted THEN
         Host^.StopPhaseWithResult( test.trSuccess );
      ELSE
         Host^.StopPhaseWithResult( test.trFailure );
      END;

      MailMessage.Dispose( REF message );

      //-----
      Host^.StartPhase( L"Try to send long mail" );
      MailMessage.New( OUT message );

      person1.Name := StringsO.FromOA( L"Martin Kolaøík" );
      person1.Address := StringsO.FromOA( L"martin@smartcontrol.cz" );
      message^.Sender := person1;
      message^.Recipient := person1;
      message^.Subject := StringsO.FromOA( L"[SINGLE] Testovací majlíèek mazlíèek pro Pifíèka" );
      message^.Body^.WriteOA( L"Obsah testovacího emailu -- kromobyèejnì kulaoulinkatı nesmyslík všehoschopné ravé blátotlaèky z Traalu pøinesl text zvící asi sto dvaceti znaèíkù textíku, co by mìlo vydat na kopec a kopec øádkù." + 13W + 10W + 13W + 10W, OUT c, 0 );
      message^.Body^.WriteOA( L"Obsah testovacího emailu -- kromobyèejnì kulaoulinkatı nesmyslík všehoschopné ravé blátotlaèky z Traalu pøinesl text zvící asi sto dvaceti znaèíkù textíku, co by mìlo vydat na kopec a kopec øádkù." + 13W + 10W + 13W + 10W, OUT c, 0 );
      message^.Body^.WriteOA( L"Obsah testovacího emailu -- kromobyèejnì kulaoulinkatı nesmyslík všehoschopné ravé blátotlaèky z Traalu pøinesl text zvící asi sto dvaceti znaèíkù textíku, co by mìlo vydat na kopec a kopec øádkù." + 13W + 10W + 13W + 10W, OUT c, 0 );
      message^.Body^.WriteOA( L"Obsah testovacího emailu -- kromobyèejnì kulaoulinkatı nesmyslík všehoschopné ravé blátotlaèky z Traalu pøinesl text zvící asi sto dvaceti znaèíkù textíku, co by mìlo vydat na kopec a kopec øádkù." + 13W + 10W + 13W + 10W, OUT c, 0 );
      message^.Body^.WriteOA( L"Obsah testovacího emailu -- kromobyèejnì kulaoulinkatı nesmyslík všehoschopné ravé blátotlaèky z Traalu pøinesl text zvící asi sto dvaceti znaèíkù textíku, co by mìlo vydat na kopec a kopec øádkù." + 13W + 10W + 13W + 10W, OUT c, 0 );
      message^.Body^.WriteOA( L"Obsah testovacího emailu -- kromobyèejnì kulaoulinkatı nesmyslík všehoschopné ravé blátotlaèky z Traalu pøinesl text zvící asi sto dvaceti znaèíkù textíku, co by mìlo vydat na kopec a kopec øádkù." + 13W + 10W + 13W + 10W, OUT c, 0 );
      message^.Body^.WriteOA( L"Obsah testovacího emailu -- kromobyèejnì kulaoulinkatı nesmyslík všehoschopné ravé blátotlaèky z Traalu pøinesl text zvící asi sto dvaceti znaèíkù textíku, co by mìlo vydat na kopec a kopec øádkù." + 13W + 10W + 13W + 10W, OUT c, 0 );
      message^.Body^.WriteOA( L"Obsah testovacího emailu -- kromobyèejnì kulaoulinkatı nesmyslík všehoschopné ravé blátotlaèky z Traalu pøinesl text zvící asi sto dvaceti znaèíkù textíku, co by mìlo vydat na kopec a kopec øádkù." + 13W + 10W + 13W + 10W, OUT c, 0 );
      message^.Body^.WriteOA( L"Obsah testovacího emailu -- kromobyèejnì kulaoulinkatı nesmyslík všehoschopné ravé blátotlaèky z Traalu pøinesl text zvící asi sto dvaceti znaèíkù textíku, co by mìlo vydat na kopec a kopec øádkù." + 13W + 10W + 13W + 10W, OUT c, 0 );
      message^.Body^.WriteOA( L"Obsah testovacího emailu -- kromobyèejnì kulaoulinkatı nesmyslík všehoschopné ravé blátotlaèky z Traalu pøinesl text zvící asi sto dvaceti znaèíkù textíku, co by mìlo vydat na kopec a kopec øádkù." + 13W + 10W + 13W + 10W, OUT c, 0 );
      message^.Body^.WriteOA( L"Obsah testovacího emailu -- kromobyèejnì kulaoulinkatı nesmyslík všehoschopné ravé blátotlaèky z Traalu pøinesl text zvící asi sto dvaceti znaèíkù textíku, co by mìlo vydat na kopec a kopec øádkù." + 13W + 10W + 13W + 10W, OUT c, 0 );
      message^.Body^.WriteOA( L"Obsah testovacího emailu -- kromobyèejnì kulaoulinkatı nesmyslík všehoschopné ravé blátotlaèky z Traalu pøinesl text zvící asi sto dvaceti znaèíkù textíku, co by mìlo vydat na kopec a kopec øádkù." + 13W + 10W + 13W + 10W, OUT c, 0 );
      message^.Body^.WriteOA( L"Obsah testovacího emailu -- kromobyèejnì kulaoulinkatı nesmyslík všehoschopné ravé blátotlaèky z Traalu pøinesl text zvící asi sto dvaceti znaèíkù textíku, co by mìlo vydat na kopec a kopec øádkù." + 13W + 10W + 13W + 10W, OUT c, 0 );
      message^.Body^.WriteOA( L"Obsah testovacího emailu -- kromobyèejnì kulaoulinkatı nesmyslík všehoschopné ravé blátotlaèky z Traalu pøinesl text zvící asi sto dvaceti znaèíkù textíku, co by mìlo vydat na kopec a kopec øádkù." + 13W + 10W + 13W + 10W, OUT c, 0 );
      message^.Body^.WriteOA( L"Obsah testovacího emailu -- kromobyèejnì kulaoulinkatı nesmyslík všehoschopné ravé blátotlaèky z Traalu pøinesl text zvící asi sto dvaceti znaèíkù textíku, co by mìlo vydat na kopec a kopec øádkù." + 13W + 10W + 13W + 10W, OUT c, 0 );
      message^.Body^.WriteOA( L"Obsah testovacího emailu -- kromobyèejnì kulaoulinkatı nesmyslík všehoschopné ravé blátotlaèky z Traalu pøinesl text zvící asi sto dvaceti znaèíkù textíku, co by mìlo vydat na kopec a kopec øádkù." + 13W + 10W + 13W + 10W, OUT c, 0 );
      message^.Body^.WriteOA( L"Obsah testovacího emailu -- kromobyèejnì kulaoulinkatı nesmyslík všehoschopné ravé blátotlaèky z Traalu pøinesl text zvící asi sto dvaceti znaèíkù textíku, co by mìlo vydat na kopec a kopec øádkù." + 13W + 10W + 13W + 10W, OUT c, 0 );
      message^.Body^.WriteOA( L"Obsah testovacího emailu -- kromobyèejnì kulaoulinkatı nesmyslík všehoschopné ravé blátotlaèky z Traalu pøinesl text zvící asi sto dvaceti znaèíkù textíku, co by mìlo vydat na kopec a kopec øádkù." + 13W + 10W + 13W + 10W, OUT c, 0 );
      message^.Body^.WriteOA( L"Obsah testovacího emailu -- kromobyèejnì kulaoulinkatı nesmyslík všehoschopné ravé blátotlaèky z Traalu pøinesl text zvící asi sto dvaceti znaèíkù textíku, co by mìlo vydat na kopec a kopec øádkù." + 13W + 10W + 13W + 10W, OUT c, 0 );
      message^.Body^.WriteOA( L"Obsah testovacího emailu -- kromobyèejnì kulaoulinkatı nesmyslík všehoschopné ravé blátotlaèky z Traalu pøinesl text zvící asi sto dvaceti znaèíkù textíku, co by mìlo vydat na kopec a kopec øádkù." + 13W + 10W + 13W + 10W, OUT c, 0 );
      message^.Body^.WriteOA( L"Obsah testovacího emailu -- kromobyèejnì kulaoulinkatı nesmyslík všehoschopné ravé blátotlaèky z Traalu pøinesl text zvící asi sto dvaceti znaèíkù textíku, co by mìlo vydat na kopec a kopec øádkù." + 13W + 10W + 13W + 10W, OUT c, 0 );
      message^.Body^.WriteOA( L"Obsah testovacího emailu -- kromobyèejnì kulaoulinkatı nesmyslík všehoschopné ravé blátotlaèky z Traalu pøinesl text zvící asi sto dvaceti znaèíkù textíku, co by mìlo vydat na kopec a kopec øádkù." + 13W + 10W + 13W + 10W, OUT c, 0 );
      message^.Body^.WriteOA( L"Obsah testovacího emailu -- kromobyèejnì kulaoulinkatı nesmyslík všehoschopné ravé blátotlaèky z Traalu pøinesl text zvící asi sto dvaceti znaèíkù textíku, co by mìlo vydat na kopec a kopec øádkù." + 13W + 10W + 13W + 10W, OUT c, 0 );
      message^.Body^.WriteOA( L"Obsah testovacího emailu -- kromobyèejnì kulaoulinkatı nesmyslík všehoschopné ravé blátotlaèky z Traalu pøinesl text zvící asi sto dvaceti znaèíkù textíku, co by mìlo vydat na kopec a kopec øádkù." + 13W + 10W + 13W + 10W, OUT c, 0 );
      message^.Body^.WriteOA( L"Obsah testovacího emailu -- kromobyèejnì kulaoulinkatı nesmyslík všehoschopné ravé blátotlaèky z Traalu pøinesl text zvící asi sto dvaceti znaèíkù textíku, co by mìlo vydat na kopec a kopec øádkù." + 13W + 10W + 13W + 10W, OUT c, 0 );
      message^.Body^.WriteOA( L"Obsah testovacího emailu -- kromobyèejnì kulaoulinkatı nesmyslík všehoschopné ravé blátotlaèky z Traalu pøinesl text zvící asi sto dvaceti znaèíkù textíku, co by mìlo vydat na kopec a kopec øádkù." + 13W + 10W + 13W + 10W, OUT c, 0 );
      message^.Body^.WriteOA( L"Obsah testovacího emailu -- kromobyèejnì kulaoulinkatı nesmyslík všehoschopné ravé blátotlaèky z Traalu pøinesl text zvící asi sto dvaceti znaèíkù textíku, co by mìlo vydat na kopec a kopec øádkù." + 13W + 10W + 13W + 10W, OUT c, 0 );
      message^.Body^.WriteOA( L"Obsah testovacího emailu -- kromobyèejnì kulaoulinkatı nesmyslík všehoschopné ravé blátotlaèky z Traalu pøinesl text zvící asi sto dvaceti znaèíkù textíku, co by mìlo vydat na kopec a kopec øádkù." + 13W + 10W + 13W + 10W, OUT c, 0 );

      IF sender^.Send( message, 0, FALSE ) = Sync.arCompleted THEN
         Host^.StopPhaseWithResult( test.trSuccess );
      ELSE
         Host^.StopPhaseWithResult( test.trFailure );
      END;

      MailMessage.Dispose( REF message );

      //-----
      Host^.StartPhase( L"Try to send long HTML" );
      MailMessage.New( OUT message );

      person1.Name := StringsO.FromOA( L"Martin Kolaøík" );
      person1.Address := StringsO.FromOA( L"martin@smartcontrol.cz" );
      message^.Sender := person1;
      message^.Recipient := person1;
      message^.Subject := StringsO.FromOA( L"[SINGLE] Testovací majlíèek mazlíèek pro Pifíèka" );
      message^.BodyMimeType := StringsO.FromOA( L"text/html" );

      f.FromOA( L"d:\private\dokumenty\osud.pdf" );
      MIME.FormatContent( MIME.contentUnknown, f, e, FALSE, OUT s );
      message^.Attachments^.Add( f, s );
      message^.Attachments^.Add( f, s );

      message^.Body^.WriteOA( L"<html><body><p>Obsah testovacího emailu -- kromobyèejnì kulaoulinkatı nesmyslík všehoschopné ravé blátotlaèky z Traalu pøinesl text zvící asi sto dvaceti znaèíkù textíku, co by mìlo vydat na kopec a kopec øádkù.</p>", OUT c, 0 );
      message^.Body^.WriteOA( L"Obsah testovacího emailu -- kromobyèejnì kulaoulinkatı nesmyslík všehoschopné ravé blátotlaèky z Traalu pøinesl text zvící asi sto dvaceti znaèíkù textíku, co by mìlo vydat na kopec a kopec øádkù.</p>", OUT c, 0 );
      message^.Body^.WriteOA( L"Obsah testovacího emailu -- kromobyèejnì kulaoulinkatı nesmyslík všehoschopné ravé blátotlaèky z Traalu pøinesl text zvící asi sto dvaceti znaèíkù textíku, co by mìlo vydat na kopec a kopec øádkù.</p>", OUT c, 0 );
      message^.Body^.WriteOA( L"Obsah testovacího emailu -- kromobyèejnì kulaoulinkatı nesmyslík všehoschopné ravé blátotlaèky z Traalu pøinesl text zvící asi sto dvaceti znaèíkù textíku, co by mìlo vydat na kopec a kopec øádkù.</p>", OUT c, 0 );
      message^.Body^.WriteOA( L"Obsah testovacího emailu -- kromobyèejnì kulaoulinkatı nesmyslík všehoschopné ravé blátotlaèky z Traalu pøinesl text zvící asi sto dvaceti znaèíkù textíku, co by mìlo vydat na kopec a kopec øádkù.</p>", OUT c, 0 );
      message^.Body^.WriteOA( L"Obsah testovacího emailu -- kromobyèejnì kulaoulinkatı nesmyslík všehoschopné ravé blátotlaèky z Traalu pøinesl text zvící asi sto dvaceti znaèíkù textíku, co by mìlo vydat na kopec a kopec øádkù.</p>", OUT c, 0 );
      message^.Body^.WriteOA( L"Obsah testovacího emailu -- kromobyèejnì kulaoulinkatı nesmyslík všehoschopné ravé blátotlaèky z Traalu pøinesl text zvící asi sto dvaceti znaèíkù textíku, co by mìlo vydat na kopec a kopec øádkù.</p>", OUT c, 0 );
      message^.Body^.WriteOA( L"Obsah testovacího emailu -- kromobyèejnì kulaoulinkatı nesmyslík všehoschopné ravé blátotlaèky z Traalu pøinesl text zvící asi sto dvaceti znaèíkù textíku, co by mìlo vydat na kopec a kopec øádkù.</p>", OUT c, 0 );
      message^.Body^.WriteOA( L"Obsah testovacího emailu -- kromobyèejnì kulaoulinkatı nesmyslík všehoschopné ravé blátotlaèky z Traalu pøinesl text zvící asi sto dvaceti znaèíkù textíku, co by mìlo vydat na kopec a kopec øádkù.</p>", OUT c, 0 );
      message^.Body^.WriteOA( L"Obsah testovacího emailu -- kromobyèejnì kulaoulinkatı nesmyslík všehoschopné ravé blátotlaèky z Traalu pøinesl text zvící asi sto dvaceti znaèíkù textíku, co by mìlo vydat na kopec a kopec øádkù.</p>", OUT c, 0 );
      message^.Body^.WriteOA( L"Obsah testovacího emailu -- kromobyèejnì kulaoulinkatı nesmyslík všehoschopné ravé blátotlaèky z Traalu pøinesl text zvící asi sto dvaceti znaèíkù textíku, co by mìlo vydat na kopec a kopec øádkù.</p>", OUT c, 0 );
      message^.Body^.WriteOA( L"Obsah testovacího emailu -- kromobyèejnì kulaoulinkatı nesmyslík všehoschopné ravé blátotlaèky z Traalu pøinesl text zvící asi sto dvaceti znaèíkù textíku, co by mìlo vydat na kopec a kopec øádkù.</p>", OUT c, 0 );
      message^.Body^.WriteOA( L"Obsah testovacího emailu -- kromobyèejnì kulaoulinkatı nesmyslík všehoschopné ravé blátotlaèky z Traalu pøinesl text zvící asi sto dvaceti znaèíkù textíku, co by mìlo vydat na kopec a kopec øádkù.</p>", OUT c, 0 );
      message^.Body^.WriteOA( L"Obsah testovacího emailu -- kromobyèejnì kulaoulinkatı nesmyslík všehoschopné ravé blátotlaèky z Traalu pøinesl text zvící asi sto dvaceti znaèíkù textíku, co by mìlo vydat na kopec a kopec øádkù.</p>", OUT c, 0 );
      message^.Body^.WriteOA( L"Obsah testovacího emailu -- kromobyèejnì kulaoulinkatı nesmyslík všehoschopné ravé blátotlaèky z Traalu pøinesl text zvící asi sto dvaceti znaèíkù textíku, co by mìlo vydat na kopec a kopec øádkù.</p>", OUT c, 0 );
      message^.Body^.WriteOA( L"Obsah testovacího emailu -- kromobyèejnì kulaoulinkatı nesmyslík všehoschopné ravé blátotlaèky z Traalu pøinesl text zvící asi sto dvaceti znaèíkù textíku, co by mìlo vydat na kopec a kopec øádkù.</p>", OUT c, 0 );
      message^.Body^.WriteOA( L"Obsah testovacího emailu -- kromobyèejnì kulaoulinkatı nesmyslík všehoschopné ravé blátotlaèky z Traalu pøinesl text zvící asi sto dvaceti znaèíkù textíku, co by mìlo vydat na kopec a kopec øádkù.</p>", OUT c, 0 );
      message^.Body^.WriteOA( L"Obsah testovacího emailu -- kromobyèejnì kulaoulinkatı nesmyslík všehoschopné ravé blátotlaèky z Traalu pøinesl text zvící asi sto dvaceti znaèíkù textíku, co by mìlo vydat na kopec a kopec øádkù.</p>", OUT c, 0 );
      message^.Body^.WriteOA( L"Obsah testovacího emailu -- kromobyèejnì kulaoulinkatı nesmyslík všehoschopné ravé blátotlaèky z Traalu pøinesl text zvící asi sto dvaceti znaèíkù textíku, co by mìlo vydat na kopec a kopec øádkù.</p>", OUT c, 0 );
      message^.Body^.WriteOA( L"Obsah testovacího emailu -- kromobyèejnì kulaoulinkatı nesmyslík všehoschopné ravé blátotlaèky z Traalu pøinesl text zvící asi sto dvaceti znaèíkù textíku, co by mìlo vydat na kopec a kopec øádkù.</p>", OUT c, 0 );
      message^.Body^.WriteOA( L"Obsah testovacího emailu -- kromobyèejnì kulaoulinkatı nesmyslík všehoschopné ravé blátotlaèky z Traalu pøinesl text zvící asi sto dvaceti znaèíkù textíku, co by mìlo vydat na kopec a kopec øádkù.</p>", OUT c, 0 );
      message^.Body^.WriteOA( L"Obsah testovacího emailu -- kromobyèejnì kulaoulinkatı nesmyslík všehoschopné ravé blátotlaèky z Traalu pøinesl text zvící asi sto dvaceti znaèíkù textíku, co by mìlo vydat na kopec a kopec øádkù.</p>", OUT c, 0 );
      message^.Body^.WriteOA( L"Obsah testovacího emailu -- kromobyèejnì kulaoulinkatı nesmyslík všehoschopné ravé blátotlaèky z Traalu pøinesl text zvící asi sto dvaceti znaèíkù textíku, co by mìlo vydat na kopec a kopec øádkù.</p>", OUT c, 0 );
      message^.Body^.WriteOA( L"Obsah testovacího emailu -- kromobyèejnì kulaoulinkatı nesmyslík všehoschopné ravé blátotlaèky z Traalu pøinesl text zvící asi sto dvaceti znaèíkù textíku, co by mìlo vydat na kopec a kopec øádkù.</p>", OUT c, 0 );
      message^.Body^.WriteOA( L"Obsah testovacího emailu -- kromobyèejnì kulaoulinkatı nesmyslík všehoschopné ravé blátotlaèky z Traalu pøinesl text zvící asi sto dvaceti znaèíkù textíku, co by mìlo vydat na kopec a kopec øádkù.</p>", OUT c, 0 );
      message^.Body^.WriteOA( L"Obsah testovacího emailu -- kromobyèejnì kulaoulinkatı nesmyslík všehoschopné ravé blátotlaèky z Traalu pøinesl text zvící asi sto dvaceti znaèíkù textíku, co by mìlo vydat na kopec a kopec øádkù.</p>", OUT c, 0 );
      message^.Body^.WriteOA( L"Obsah testovacího emailu -- kromobyèejnì kulaoulinkatı nesmyslík všehoschopné ravé blátotlaèky z Traalu pøinesl text zvící asi sto dvaceti znaèíkù textíku, co by mìlo vydat na kopec a kopec øádkù.</p>", OUT c, 0 );
      message^.Body^.WriteOA( L"Obsah testovacího emailu -- kromobyèejnì kulaoulinkatı nesmyslík všehoschopné ravé blátotlaèky z Traalu pøinesl text zvící asi sto dvaceti znaèíkù textíku, co by mìlo vydat na kopec a kopec øádkù.</p></body></html>", OUT c, 0 );

      IF sender^.Send( message, 0, FALSE ) = Sync.arCompleted THEN
         Host^.StopPhaseWithResult( test.trSuccess );
      ELSE
         Host^.StopPhaseWithResult( test.trFailure );
      END;

      MailMessage.Dispose( REF message );

      SmtpSender.Dispose( REF sender );

      scinit.Cleanup();
      RETURN test.trSuccess;
   END Run;

(*---------------------------------------------------------------------------*)

BEGIN
   testimpl.tests()^.AddTest( L"LightweightSender", ADR( TestLightweightSender ));
END CTest;

(*===========================================================================*)

END TLightweightSender.