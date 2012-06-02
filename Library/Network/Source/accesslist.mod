IMPLEMENTATION MODULE AccessList;

IMPORT
   collection,
   Strings;

(*================================================================================*)

CLASS IMPLEMENTATION CAccessList;

(*--------------------------------------------------------------------------------*)

   PUBLIC PROPERTY Policy GET : TAccessType;
   BEGIN
      RETURN _Policy;
   END Policy;
   
(*--------------------------------------------------------------------------------*)

   PUBLIC PROPERTY Policy SET( Value : TAccessType );
   BEGIN
      _Policy := Value;
   END Policy;
   
(*--------------------------------------------------------------------------------*)

   PUBLIC PROCEDURE Reset();
   BEGIN
      _Rules.Dispose();
   END Reset;

(*--------------------------------------------------------------------------------*)

   PUBLIC PROCEDURE AddRule( Type : TAccessType; CONST IPAddress : inetaddr.INETADDR; MaskLen : CARDINAL );
   VAR
      addressOA : inetaddr.TRFC2553;
      filled : CARDINAL;
   BEGIN
      IPAddress.ToAddressBOA( OUT addressOA, OUT filled );
      Mask( REF addressOA, MaskLen );
      _Rules.AddOA( addressOA, ( PTR( Type ) << 31 ) OR PTR( MaskLen ));
   END AddRule;

(*--------------------------------------------------------------------------------*)

   PUBLIC PROCEDURE AddRuleOA( Type : TAccessType; CONST AddressPortPrefixLen : ARRAY OF WCHAR );
   VAR
      address : inetaddr.INETADDR;
      i : INTEGER;
      prefixLen : CARDINAL := SIZE( inetaddr.TRFC2553 ) * SIZE( BYTE );
   BEGIN
      i := Strings.IndexOfW( AddressPortPrefixLen, L"/", 0 );
      IF i > 0 THEN
         INC( i ); // i points after slash
         Strings.ToCARD32W( OA( HIGH( AddressPortPrefixLen ) - i, ADR( AddressPortPrefixLen[i] )), 10, OUT prefixLen );
         DEC( i, 2 ); // now i is high of address string without prefix length part
      ELSE
         i := HIGH( AddressPortPrefixLen );
      END;
      address.FromOA( OA( i, ADR( AddressPortPrefixLen )), 0, NIL );
      AddRule( Type, address, prefixLen );
   END AddRuleOA;

(*--------------------------------------------------------------------------------*)

   PUBLIC PROCEDURE AddRuleS( Type : TAccessType; CONST AddressPortPrefixLen : StringsO.IString );
   BEGIN
      AddRuleOA( Type, OA( AddressPortPrefixLen.Length-1, AddressPortPrefixLen.Data ));
   END AddRuleS;

(*--------------------------------------------------------------------------------*)

   PUBLIC PROCEDURE AllowedForConnection( Connection : connection.TPIConnection ) : BOOLEAN;
   BEGIN
      RETURN AllowedForAddress( Connection^.RemoteAddress );
   END AllowedForConnection;

(*--------------------------------------------------------------------------------*)
   
   PUBLIC PROCEDURE AllowedForAddress( CONST IPAddress : inetaddr.INETADDR ) : BOOLEAN;
   VAR
      addressOA : inetaddr.TRFC2553;
      filled : CARDINAL;
      i : CARDINAL;
      iterator : lists.CBufferListIterator;
      matches : BOOLEAN;
      patternOA : inetaddr.TRFC2553;
      result : TAccessType := _Policy;
   BEGIN
      iterator.Init( _Rules, collection.dirForward );
      WHILE iterator.MoveNext() DO
         IPAddress.ToBOA( OUT addressOA, OUT filled );
         Mask( REF addressOA, LOPTRLONGWORD( iterator.Data ) AND 07FFFFFFFH );
   
         iterator.Value^.ToOA( OUT patternOA, OUT filled );
         matches := TRUE;
         FOR i := 0 TO filled-1 DO
            IF patternOA[i] <> addressOA[i] THEN
               matches := FALSE;
               EXIT;
            END;
         END;
         IF matches THEN
            result := TAccessType( LOPTRLONGWORD( iterator.Data ) >> 31 );
         END;
      END; // WHILE
      
      RETURN result = actAllow;
   END AllowedForAddress;

(*--------------------------------------------------------------------------------*)

   PRIVATE PROCEDURE Mask( REF Data : inetaddr.TRFC2553; PrefixLen : CARDINAL ) : BOOLEAN;
   TYPE
      TBIT_MASK = ARRAY [0..7] OF BYTE;
   CONST
      BIT_MASK = TBIT_MASK( 000H, 080H, 0C0H, 0E0H, 0F0H, 0F8H, 0FCH, 0FEH );
   VAR
      i : INTEGER;
   BEGIN
      IF PrefixLen > SIZE( Data ) * SIZE( Data[0] ) THEN
         RETURN FALSE;
      END;
      
      i := PrefixLen DIV 8;
      Data[i] := Data[i] AND BIT_MASK[PrefixLen MOD 8];
      INC( i );
      WHILE i <= HIGH( Data ) DO
         Data[i] := 0;
         INC( i );
      END; // WHILE
      
      RETURN TRUE;
   END Mask;

(*--------------------------------------------------------------------------------*)

BEGIN
   _Policy := actAllow;
END CAccessList;

(*================================================================================*)

END AccessList.