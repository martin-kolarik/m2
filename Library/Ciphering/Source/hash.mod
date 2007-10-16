IMPLEMENTATION MODULE hash;

IMPORT
   crc,
   SHA256;

(*--------------------------------------------------------------------------------*)

PROCEDURE hashb( CONST in : ARRAY OF BYTE; OUT hash : ARRAY OF BYTE ) : BOOLEAN;
VAR
   c1, c2 : CARD32;
   d : SHA256.TDigest;
   h : CARDINAL := HIGH( in );
BEGIN
   CASE INTEGER( HIGH( hash )) OF
   | 3..5, 7 :
   ELSE
      RETURN FALSE;
   END; // CASE
   
   IF ( h = -1 ) OR ( ADR( in ) = NIL ) THEN
      SHA256.DigestOA( OA( 0, NIL ), OUT d );
   ELSE
      SHA256.DigestOA( OA( h, ADR( in )), OUT d );
   END;
   
   c1 := crc.crc32( crc.crc32i, OA( 15, ADR( d[0] )));
   c2 := crc.crc32( crc.crc32i, OA( 15, ADR( d[16] )));
   
   CASE INTEGER( HIGH( hash )) OF
   | 3 :
      PCARD32( ADR( hash ))^ := c1 XOR c2;
   | 4 :
      PCARD32( ADR( hash ))^ := c2;
      hash[4] := 0;
      PCARD32( ADR( hash[1] ))^ := PCARD32( ADR( hash[1] ))^ XOR c1;
   | 5 :
      PCARD32( ADR( hash ))^ := c2;
      hash[4] := 0;
      hash[5] := 0;
      PCARD32( ADR( hash[2] ))^ := PCARD32( ADR( hash[2] ))^ XOR c1;
   | 7 :
      PCARD32( ADR( hash[0] ))^ := c2;
      PCARD32( ADR( hash[4] ))^ := c1;
   END;

   RETURN TRUE;
END hashb;

(*--------------------------------------------------------------------------------*)

PROCEDURE hashs( CONST in : ARRAY OF WCHAR; OUT hash : ARRAY OF BYTE ) : BOOLEAN;
BEGIN
   RETURN hashb( OA( LENGTH( in ) << 1 - 1, ADR( in )), OUT hash );
END hashs;

(*--------------------------------------------------------------------------------*)

END hash.