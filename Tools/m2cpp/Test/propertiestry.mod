MODULE propertiestry;

IMPORT
	Exceptions;

CLASS C;
	PUBLIC PROPERTY
		V : BOOLEAN THROWS Exceptions.CModula2Exception;
	PUBLIC PROPERTY
		B : BOOLEAN;
   PUBLIC INDEX( i : INTEGER ) : INTEGER THROWS Exceptions.CModula2Exception;
		
   PUBLIC OPERATOR NEW( s : CARDINAL ) : ADDRESS;
   PUBLIC OPERATOR DISPOSE( a : ADDRESS );
END C;

CLASS IMPLEMENTATION C;

	PROPERTY V GET : BOOLEAN;
	BEGIN
		RETURN FALSE;
	END V;

	PROPERTY V SET( Value : BOOLEAN );
	BEGIN
	END V;

	PROPERTY B GET : BOOLEAN;
	BEGIN
		RETURN FALSE;
	END B;

	PROPERTY B SET( Value : BOOLEAN );
	BEGIN
	END B;

	INDEX C GET( i : INTEGER ) : INTEGER;
	BEGIN
		RETURN 0;
	END C;

	INDEX C SET( i : INTEGER; Value : INTEGER );
	BEGIN
	END C;

   PUBLIC OPERATOR NEW( s : CARDINAL ) : ADDRESS;
   BEGIN
      RETURN NIL;
   END NEW;
   
   PUBLIC OPERATOR DISPOSE( a : ADDRESS );
   BEGIN
   END DISPOSE;

END C;

PROCEDURE X();
VAR
	b : BOOLEAN;
	i : INTEGER;
	V : C;
BEGIN
	b := V.B;
	V.B := b;
	i := V[0];
	V[0] := i;
	TRY
		b := V.V;
		V.V := b;
   	i := V[0];
   	V[0] := i;
	CATCH m : Exceptions.CModula2Exception DO
	END;
END X;

END propertiestry.