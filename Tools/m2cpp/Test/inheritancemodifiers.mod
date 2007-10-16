DEFINITION MODULE inheritancemodifiers;

CLASS C0;
  ABSTRACT PROCEDURE A();
END C0;

CLASS C0A( C0 ); // error without A
  VIRTUAL PROCEDURE A();
END C0A;

ABSTRACT CLASS C1( C0 );
  PROCEDURE P();
  VIRTUAL PROCEDURE V();
  FINAL PROCEDURE F();
END C1; // no error A is missing

CLASS C2( C1 );
  PROCEDURE P();
  VIRTUAL PROCEDURE V();
  VIRTUAL PROCEDURE A(); // error if it is ommited
  // FINAL PROCEDURE F(); // error
END C2;

CLASS C3( C2 );
  PROCEDURE P();
  VIRTUAL PROCEDURE V();
  FINAL PROCEDURE A(); // error if ABSTRACT
  // FINAL PROCEDURE F(); // error
END C3;

END inheritancemodifiers.