IMPLEMENTATION MODULE delegate;

FROM Debug IMPORT
   AssertionW;

(*================================================================================*)

CLASS IMPLEMENTATION Delegate;

(*--------------------------------------------------------------------------------*)

   PUBLIC PROPERTY Value GET : PTR;
   BEGIN
      RETURN _Value;
   END Value;

(*--------------------------------------------------------------------------------*)

   PUBLIC PROPERTY Value SET( _Value : PTR );
   BEGIN
      SELF._Value := _Value;
   END Value;

(*--------------------------------------------------------------------------------*)

BEGIN
END Delegate;

(*================================================================================*)

END delegate.
