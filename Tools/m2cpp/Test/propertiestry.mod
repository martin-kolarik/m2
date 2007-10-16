MODULE propertiestry;

IMPORT
	Exceptions;

CLASS C;
	READONLY PROPERTY
		V : BOOLEAN THROWS Exceptions.CModula2Exception;
		B : BOOLEAN;
END C;

CLASS IMPLEMENTATION C;

	PROPERTY V GET : BOOLEAN;
	BEGIN
		RETURN FALSE;
	END V;

	PROPERTY B GET : BOOLEAN;
	BEGIN
		RETURN FALSE;
	END B;

END C;

PROCEDURE X();
VAR
	V : C;
	b : BOOLEAN;
BEGIN
	b := V.B;
	TRY
		b := V.V;
	CATCH m : Exceptions.CModula2Exception DO
	END;
END X;

END propertiestry.