IMPLEMENTATION MODULE Delegate;

FROM Debug IMPORT
   AssertionW;

FROM Storage IMPORT
  ALLOCATE, DEALLOCATE;
  
IMPORT
  Sync;

//--------------------------------------------------------------------------------

CLASS IMPLEMENTATION CDelegateException;
END CDelegateException;

PROCEDURE DelegateException( NestedException : POINTER TO Exceptions.Exception; CONST Originator, Text : ARRAY OF WCHAR ) : CDelegateException;
VAR
	DE : CDelegateException;
BEGIN
	DE.Init( 0, NestedException, Originator, Text );
	RETURN DE;
END DelegateException;

//--------------------------------------------------------------------------------

CLASS IMPLEMENTATION ADelegate;

  PUBLIC PROPERTY References GET : CARDINAL;
  BEGIN
		RETURN Sync.IGet( REF _References );
	END References;

  PUBLIC PROPERTY Completed GET : BOOLEAN;
  BEGIN
    RETURN Sync.IGet( REF _Completed ) = 1;
  END Completed;

  PUBLIC PROPERTY Completed SET( Value : BOOLEAN );
  BEGIN
    IF Value THEN
      Sync.IExchg( REF _Completed, 1 );
    ELSE
      Sync.IExchg( REF _Completed, 0 );
    END;
  END Completed;

  PUBLIC PROCEDURE AddRef() : CARDINAL; // new count
  BEGIN
    RETURN Sync.IInc( REF _References );
  END AddRef;
  
  PUBLIC PROCEDURE Release() : CARDINAL; // new count
  VAR
    a : POINTER TO ADelegate;
    LReferences : CARDINAL;
  BEGIN
    IF _References = 0 THEN
      ASSERTLOG( FALSE );
      RETURN 0;
    END;
    LReferences := Sync.IDec( REF _References );
    IF LReferences > 0 THEN
      RETURN LReferences;
    END;
    a := ADR( SELF );
    DISPOSE( a );
    RETURN 0;
  END Release;
  
  PUBLIC VIRTUAL FINALLY ADelegate();
  BEGIN
  END ADelegate;

  PRIVATE OPERATOR DISPOSE( a : ADDRESS );
  BEGIN
    DEALLOCATE( REF a );
  END DISPOSE;
  
BEGIN
  _References := 1;
  _Completed := 0;
END ADelegate;

//--------------------------------------------------------------------------------

END Delegate.
