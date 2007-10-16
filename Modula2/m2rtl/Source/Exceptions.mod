IMPLEMENTATION MODULE Exceptions;
// Modula2 Exceptions handling module

IMPORT
   Strings;

//--------------------------------------------------------------------------------

CLASS IMPLEMENTATION Exception;
BEGIN
	Code := 0;
END Exception;

//--------------------------------------------------------------------------------

CLASS IMPLEMENTATION CException;

   PUBLIC PROCEDURE Init( NestedException : POINTER TO Exception; CONST Originator, Text : ARRAY OF WCHAR ) : CException;
   BEGIN
      SELF.NestedException := NestedException;
      ASSIGN( SELF.Text, Text );
      ASSIGN( SELF.Originator, Originator );
      RETURN SELF;
   END Init;

   PUBLIC VIRTUAL PROCEDURE ToString( OUT S : ARRAY OF WCHAR );
   VAR
      N : ARRAY [0..127] OF WCHAR;
   BEGIN
      IF NestedException = NIL THEN
         S := L"";
      ELSE
         NestedException^.ToString( OUT S );
         Strings.AppendW( REF S, L" in " );
      END;
      IF Originator[0] <> 0W THEN
         Strings.AppendW( REF S, L"[" );
         Strings.AppendW( REF S, Originator );
         Strings.AppendW( REF S, L"] " );
      END;
      Name( OUT N ); Strings.AppendW( REF S, N );
      IF Text[0] <> 0W THEN
         Strings.AppendW( REF S, L": " );
         Strings.AppendW( REF S, Text );
      END;
   END ToString;

   INTERNAL VIRTUAL PROCEDURE Name( OUT S : ARRAY OF WCHAR );
   BEGIN
      ASSIGN( S, EMITW( %class ));
   END Name;

END CException;

//--------------------------------------------------------------------------------

PROCEDURE GenericException( NestedException : POINTER TO Exception; CONST Originator, Text : ARRAY OF WCHAR ) : CException;
VAR
	CE : CException;
BEGIN
	RETURN CE.Init( NestedException, Originator, Text );
END GenericException;

//--------------------------------------------------------------------------------

CLASS IMPLEMENTATION CModula2Exception;

   PUBLIC PROCEDURE Init( NestedException : POINTER TO Exception; CONST Originator, Text : ARRAY OF WCHAR; Kind : TModula2Exception ) : CModula2Exception;
   BEGIN
      SELF.Kind := Kind;
      SUPER.Init( NestedException, Originator, Text );
      RETURN SELF;
   END Init;

   INTERNAL VIRTUAL PROCEDURE Name( OUT S : ARRAY OF WCHAR );
   BEGIN
      ASSIGN( S, EMITW( %class ));
   END Name;

BEGIN
   Kind := mexNotSupported;
END CModula2Exception;

//--------------------------------------------------------------------------------

PROCEDURE Modula2Exception( NestedException : POINTER TO Exception; CONST Originator, Text : ARRAY OF WCHAR; Exception : TModula2Exception ) : CModula2Exception;
VAR
	M2E : CModula2Exception;
BEGIN
	RETURN M2E.Init( NestedException, Originator, Text, Exception );
END Modula2Exception;

//--------------------------------------------------------------------------------

END Exceptions.
