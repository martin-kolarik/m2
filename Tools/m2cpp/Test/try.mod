MODULE Try;

FROM Storage IMPORT
   ALLOCATE, DEALLOCATE;

FROM Exceptions IMPORT
   TestIfCatched, StoreException, RetrieveException;

IMPORT
	Exceptions;

  CLASS CB;
    READONLY PROPERTY
      CBA : WCHAR;
    PROCEDURE CBB( A : INT32 );
  END CB;
  
  CLASS IMPLEMENTATION CB;

    PROPERTY CBA GET : WCHAR;
    BEGIN
      RETURN L"A";
    END CBA;

    PROCEDURE CBB( A : INT32 );
    BEGIN
    END CBB;

  END CB;
  
  PROCEDURE CPPNORMAL();
  BEGIN
    TRY
      IF TRUE THEN END;
    CATCH a : Exceptions.CModula2Exception DO
    CATCH UNHANDLED DO
      IF FALSE THEN END;
    END;
  END CPPNORMAL;

  PROCEDURE CPPEXTENDED();
  BEGIN
    TRY
      IF TRUE THEN END;
    CATCH a : Exceptions.CModula2Exception DO
    CATCH UNHANDLED DO
      IF FALSE THEN END;
    FINALLY
      IF TRUE THEN END;
    END;
  END CPPEXTENDED;

  PROCEDURE CPPRETURN1();
  BEGIN
    TRY
      IF TRUE THEN END;
      RETURN;
    CATCH a : Exceptions.CModula2Exception DO
      RETURN;
    CATCH UNHANDLED DO
      IF FALSE THEN END;
      RETURN;
    FINALLY
      IF TRUE THEN END;
    END;
  END CPPRETURN1;

  PROCEDURE CPPRETURN2() : CARDINAL;
  BEGIN
    TRY
      IF TRUE THEN END;
      RETURN 0;
    CATCH a : Exceptions.CModula2Exception DO
      RETURN 1;
    CATCH UNHANDLED DO
      IF FALSE THEN END;
      RETURN 2;
    FINALLY
      IF TRUE THEN END;
    END;
    RETURN -1;
  END CPPRETURN2;

  PROCEDURE CPPRETURN3();
  BEGIN
    TRY
      IF TRUE THEN END;
      TRY
        IF TRUE THEN END;
      CATCH a : Exceptions.CModula2Exception DO
        RETURN;
      FINALLY
      END;
      RETURN;
    CATCH b : Exceptions.CModula2Exception DO
      RETURN;
    CATCH UNHANDLED DO
      IF FALSE THEN END;
      RETURN;
    FINALLY
      IF TRUE THEN END;
    END;
  END CPPRETURN3;
  
  PROCEDURE CPPRETURN4( A : INT32; B : CB );
  BEGIN
    TRY
      IF TRUE THEN
        RETURN;
      END;
    CATCH : Exceptions.CModula2Exception DO
    END;
  END CPPRETURN4;

  PROCEDURE SEH();
  VAR
    a : TRISTATE := 0;
  BEGIN
    TRY
      IF TRUE THEN END;
    EXCEPT a DO
      IF FALSE THEN END;
    END;
    TRY
      IF TRUE THEN END;
    FINALLY
      IF FALSE THEN END;
    END;
  END SEH;
  
  PROCEDURE THR1() : INTEGER THROWS Exceptions.Exception;
  BEGIN
    RETURN 0;
  END THR1;
  
  PROCEDURE THR2();
  BEGIN
    // THROW V; // error
    // THR1(); // error
  END THR2;

  PROCEDURE THR3();
  BEGIN
    TRY
      THR1(); // OK
    CATCH UNHANDLED DO
    END;
  END THR3;

  PROCEDURE THR4();
  BEGIN
    TRY
      // THR1(); // error
    CATCH e : Exceptions.CModula2Exception DO
    END;
  END THR4;

  PROCEDURE THR5();
  BEGIN
    TRY
      THR1(); // OK
    CATCH e : Exceptions.Exception DO
    END;
  END THR5;

  PROCEDURE THR6();
  BEGIN
    TRY
      THROW NEW( Exceptions.CModula2Exception )^; // OK
      THROW NEW( Exceptions.Exception )^; // OK
    CATCH e : Exceptions.Exception DO
    END;
  END THR6;

  PROCEDURE THR7() THROWS Exceptions.Exception;
  BEGIN
    THROW NEW( Exceptions.Exception )^;  
  END THR7;

  PROCEDURE THR8() : CARDINAL THROWS Exceptions.Exception;
  BEGIN
    THROW NEW( Exceptions.Exception )^;
    RETURN 0;
  END THR8;

  PROCEDURE THR9() : CARDINAL THROWS Exceptions.Exception;
  BEGIN
    TRY
      THR7();
      THROW NEW( Exceptions.Exception )^;  
    CATCH e : Exceptions.Exception DO
      THROW e;  
    END;
    RETURN 0;
  END THR9;

  PROCEDURE THR10() THROWS Exceptions.Exception;
  BEGIN
    TRY
      // THR7();
      THROW NEW( Exceptions.Exception )^;  
    CATCH e : Exceptions.Exception DO
      THROW e;  
    END;
  END THR10;

  PROCEDURE THR11() : CARDINAL THROWS Exceptions.Exception;
  BEGIN
    TRY
      IF THR8() = 0 THEN END;
      THROW NEW( Exceptions.Exception )^;  
    CATCH e : Exceptions.Exception DO
      THROW e;  
    END;
    RETURN 0;
  END THR11;

  PROCEDURE THR12() THROWS Exceptions.Exception;
  BEGIN
    TRY
      IF THR8() = 0 THEN END;
      THROW NEW( Exceptions.Exception )^;  
    CATCH e : Exceptions.Exception DO
      THROW e;  
    END;
  END THR12;

END Try.