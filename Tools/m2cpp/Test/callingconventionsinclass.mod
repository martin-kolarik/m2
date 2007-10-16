MODULE callingconventionsinclass;

#save, call( prefix => stdcall )

CLASS C;
  PROCEDURE A();
  VIRTUAL PROCEDURE V();
END C;

#restore

CLASS IMPLEMENTATION C;

  PROCEDURE A();
  BEGIN
  END A;

  VIRTUAL PROCEDURE V();
  BEGIN
  END V;
  
END C;

END callingconventionsinclass.
