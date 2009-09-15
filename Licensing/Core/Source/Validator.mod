IMPLEMENTATION MODULE Validator;

FROM Storage IMPORT
   ALLOCATE, DEALLOCATE;

IMPORT
   Defs,
   hash,
   rijndael,
   sha256,
   lists;

(*================================================================================*)

TYPE
   TPValidatorSource = POINTER TO ValidatorSource;

INTERFACE ValidatorSource; // must correspond with class generated using lictool
   VIRTUAL PROCEDURE query( bit : CARDINAL; OUT value : BOOLEAN );
END ValidatorSource;

(*--------------------------------------------------------------------------------*)

CLASS Validator;
   Items : lists.CBufferList;
   
   LOCAL PROCEDURE Register( CONST Data : ADDRESS; Length : CARDINAL; Source : TPValidatorSource );
   LOCAL PROCEDURE Unregister( CONST Data : ADDRESS );
   
   LOCAL PROCEDURE IsValid( CONST Product : StringsO.IString ) : TRISTATE;
END Validator;

(*================================================================================*)

TYPE
   TItem  = RECORD
              PId     : Defs.TPID;
              Address : ADDRESS;
              Length  : CARDINAL;
            END;
   TPItem = POINTER TO TItem;

(*--------------------------------------------------------------------------------*)

CLASS IMPLEMENTATION Validator;
   
(*--------------------------------------------------------------------------------*)

   LOCAL PROCEDURE Register( CONST Data : ADDRESS; Length : CARDINAL; Source : TPValidatorSource );
   CONST
      xorPID = Defs.TPID( 0A8H, 011H, 078H, 028H, 03EH ); // sync this with licool
   VAR
      item : TItem;
      i : CARDINAL;
      PId : Defs.TPID;
      Unwrapped : StringsO.CString;
      b : BOOLEAN;
   BEGIN
      Unregister( Data );
   
      FOR i := 0 TO 5 DO
         item.PId[i] := 0;
      END;
      FOR i := 0 TO 39 DO
         Source^.query( i, OUT b );
         IF b THEN
            INCL( PBITSET64( ADR( item.PId ))^, i );
         END;
      END; // FOR
      FOR i := 0 TO 5 DO
         item.PId[i] := item.PId[i] XOR xorPID[i];
      END;

      // check for first
      UnwrapData( Data, Length, OUT Unwrapped );
      hash.hashs( OA( Unwrapped.Length-1, Unwrapped.Data ), OUT PId );

      item.Address := Data;
      IF PId = item.PId THEN
         item.Length := Length;
      ELSE
         item.Length := 0;
      END;
      
      Items.AddOA( item, 0 );
   END Register;

(*--------------------------------------------------------------------------------*)

   LOCAL PROCEDURE Unregister( CONST Data : ADDRESS );
   VAR
      Item : TPItem;
   BEGIN
      Items.Reset();
      WHILE Items.MoveNext() DO
         Item := TPItem( Items.Current^.Data );
         IF Item^.Address = Data THEN
            Items.Delete( Items.CListWState.Current );
            RETURN;
         END;
      END; // WHILE
   END Unregister;
   
(*--------------------------------------------------------------------------------*)

   LOCAL PROCEDURE IsValid( CONST Product : StringsO.IString ) : TRISTATE;
   VAR
      dataPId : Defs.TPID;
      Item : TPItem;
      queryPId : Defs.TPID;
      Unwrapped : StringsO.CString;
   BEGIN
      hash.hashs( OA( Product.Length-1, Product.Data ), OUT queryPId );
   
      Items.Reset();
      WHILE Items.MoveNext() DO
         Item := TPItem( Items.Current^.Data );
         IF Item^.PId <> queryPId THEN
            CONTINUE;
         ELSIF Item^.Length = 0 THEN // damaged from start -- product withount any licence
            RETURN 0;
         END;
         UnwrapData( Item^.Address, Item^.Length, OUT Unwrapped );
         hash.hashs( OA( Unwrapped.Length-1, Unwrapped.Data ), OUT dataPId );
         IF DEBUGGED() OR ( Item^.PId <> dataPId ) THEN
            RETURN 0;
         ELSE
            RETURN 1;
         END;
      END; // WHILE
      
      RETURN -1;
   END IsValid;
   
(*--------------------------------------------------------------------------------*)

BEGIN
   Items.ItemType := lists.blitSlot32;
END Validator;

(*================================================================================*)

VAR
   V : Validator;

(*--------------------------------------------------------------------------------*)

PROCEDURE Register( CONST Data : ADDRESS; Length : CARDINAL; Source : ADDRESS );
BEGIN
   V.Register( Data, Length, TPValidatorSource( Source ));
END Register;

(*--------------------------------------------------------------------------------*)

PROCEDURE Unregister( CONST Data : ADDRESS );
BEGIN
   V.Unregister( Data );
END Unregister;

(*--------------------------------------------------------------------------------*)

PROCEDURE Check( CONST Product : StringsO.IString ) : TRISTATE;
BEGIN
   RETURN V.IsValid( Product );
END Check;

(*--------------------------------------------------------------------------------*)

PROCEDURE UnwrapData( CONST Data : ADDRESS; Length : CARDINAL; OUT Unwrapped : StringsO.IString );
TYPE
   TK = ARRAY [0..31] OF BYTE;
CONST
   nk = TK( 0F9H, 0FAH, 0C2H, 076H, 080H, 062H, 0D3H, 086H, 009H, 013H, 024H, 090H, 0F4H, 015H, 060H, 0FFH, 00CH, 07BH, 033H, 06DH, 01EH, 0F4H, 0FFH, 0AFH, 090H, 038H, 0E0H, 0C6H, 01BH, 08EH, 04EH, 048H ); // sync this with licool
   ni = TK( 0C7H, 067H, 0D6H, 075H, 06EH, 090H, 048H, 094H, 07DH, 095H, 043H, 0ADH, 069H, 052H, 0B6H, 078H, 04FH, 023H, 07AH, 076H, 046H, 068H, 0BAH, 036H, 079H, 0B1H, 0C6H, 060H, 0FBH, 021H, 03BH, 033H ); // sync this with licool
VAR
   a : ADDRESS;
   i : INTEGER;
   dk, di : sha256.TDigest;
BEGIN
   Unwrapped.Size := Length DIV 2;
   Unwrapped.Length := 1;
   a := Unwrapped.Data;

   sha256.DigestOA( nk, OUT dk );
   sha256.DigestOA( ni, OUT di );
   rijndael.Decrypt( rijndael.cphmBlockDecrypt, rijndael.rklDefault, dk, di, OA( Length-1, Data ), OUT OA( Length-1, a ), OUT i );

   Unwrapped.Length := LENGTHsz( PWCHAR( a ));
END UnwrapData;

(*================================================================================*)

END Validator.