IMPLEMENTATION MODULE lrconv;

(*================================================================================*)

IMPORT
   lr,
   Strings;

TYPE
   TBCD = ARRAY [0..23] OF INT8;

PROCEDURE LONGREALToBCD( R : LONGREAL ) : TBCD;
TYPE
   T2BCD = ARRAY [0..39] OF CARD8;
   TPBCD = POINTER TO TBCD;
   TC = RECORD
           L, H : CARD32;
        END;
CONST
   BCInit = T2BCD( 0 BY 40 );
VAR
   PB : PCARD8;
   BCD : T2BCD := BCInit;
   C : TC;
   Shf : INT32;
   VH : CARD32;
   VL : CARD32;
BEGIN
   C := TC( R );
   WITH C DO
      Shf := H >> lr.expShiftHi - lr.expBias;
      H := H AND 0FFFFFH OR 100000H;
      IF Shf > 52 THEN // mantissa is greater (.2^negative), very probable, as the previous algorithm creates number with Shf = -1
         Shf := Shf - 52;
         H := H << Shf;
         H := H OR ( L >> ( 32 - Shf ));
         L := L << Shf;
      ELSIF Shf < 52 THEN // mantissa is lower (.2^positive)
         Shf := 52 - Shf;
         L := L >> Shf;
         L := L OR ( H << ( 32 - Shf ));
         H := H >> Shf;
      // ELSE // Shf = 52, very unprobable, do nothing
      END;
   END; // WITH

   VH := CARD32( CARD64( C ) DIV 1000000000 );
   VL := CARD32( CARD64( C ) MOD 1000000000 );

   PB := ADR( BCD[18] );
   PB^ := -1;
   DEC( PB );
   LOOP
      IF VL = 0 THEN
         EXIT;
      END;
      PB^ := CARD8( VL MOD 10 );
      VL := VL DIV 10;
      DEC( PB );
   END; // LOOP
   IF VH = 0 THEN
      RETURN TPBCD( PB )^;
   END;

   PB := ADR( BCD[8] );
   LOOP
      PB^ := CARD8( VH MOD 10 );
      VH := VH DIV 10;
      IF VH = 0 THEN
         EXIT;
      END;
      DEC( PB );
   END; // LOOP

   RETURN TPBCD( PB )^;
END LONGREALToBCD;
  
PROCEDURE LONGREALToStrW( r : LONGREAL; ValidCiphers, FractionPlaces : CARDINAL; ExpFlag : BOOLEAN; PointChar : WCHAR; OUT S : ARRAY OF WCHAR ) : BOOLEAN;
VAR
   B : TBCD;
   DotPos : INTEGER;
   Exp10, ExpExp10 : INTEGER;
   FirstZero : INTEGER;
   i : INTEGER;
   RoundPos : INTEGER := -1; // roundup position
   s : INTEGER := 0;
   sExp : ARRAY [0..3] OF WCHAR;
BEGIN
   IF ValidCiphers = 0 THEN
      RETURN FALSE;
   END;
   IF r < 0.0 THEN
      r := -r;
      S[s] := L'-'; INC( s );
   END;
   IF PointChar = 0W THEN
      PointChar := L'.';
   END;

   // get exponent and normalize r to get maximal ten exponent for BCD conversion
   Exp10 := lr.TenExponent( r );
   r := r * lr.Pow10( 16-Exp10 ) + 0.5; // nearest to zero bias, exponent of two will be -1; and round it on the lowest order
   B := LONGREALToBCD( r );

   // check buffer and expflag
   IF ExpFlag THEN
      IF HIGH( S ) < 23 + MAX2( INTEGER( ValidCiphers ), INTEGER( FractionPlaces )) THEN
         RETURN FALSE;
      END;
      ExpExp10 := Exp10; // remember exponent
      Exp10 := 0; // single order
   ELSE
      IF HIGH( S ) < 3 + MAX2( ABS( Exp10 ), MAX2( INTEGER( ValidCiphers ), INTEGER( FractionPlaces ))) THEN
         RETURN FALSE;
      END;
   END;

   INC( Exp10 ); // convert ten exponent to order counts

   // prepare rounding
   IF INTEGER( ValidCiphers ) > 0 THEN // valid number count is crucial
      ValidCiphers := MIN2( 15, ValidCiphers ); // no more ciphers are valid
      RoundPos := MIN2( ValidCiphers, HIGH( B ));
   ELSIF INTEGER( FractionPlaces ) > -1 THEN
      RoundPos := MIN2( Exp10 + INTEGER( FractionPlaces ), HIGH( B ));
   ELSE // both ValidCiphers and FractionPlaces = -1, round to maximal valid ciphers
      RoundPos := MIN2( 15, HIGH( B ));
   END;

   // do rounding
   IF ( RoundPos > 0 ) AND ( B[RoundPos] >= 5 ) THEN
      i := RoundPos;
      LOOP
         DEC( i );
         IF i = 0 THEN
            IF B[0] < 9 THEN
               INC( B[i] );
            ELSE
               B[0] := 0;
               FOR i := 0 TO HIGH( B ) - 1 DO
                  B[i+1] := B[0];
               END;
               B[0] := 1;
               // order count has increased, correct it
               IF ExpFlag THEN
                  INC( ExpExp10 );
               ELSE
                  INC( Exp10 );
               END;
            END;
            EXIT;
         END;
         INC( B[i] );
         IF B[i] < 10 THEN
            EXIT;
         ELSIF B[i] = 10 THEN
            B[i] := 0;
         END;
      END; // LOOP
   END;

   // correct fraction places for valid number counts
   IF INTEGER( ValidCiphers ) > 0 THEN // do only if ValidCiphers should be set
      IF INTEGER( ValidCiphers ) > Exp10 + INTEGER( FractionPlaces ) THEN // extend fraction places if needed by fraction places
         FractionPlaces := INTEGER( ValidCiphers ) - Exp10;
      END;
   END; // IF for valid ciphers

   // apply valid ciphers and zeros after them and/or zeros after decimal point
   IF ValidCiphers = -1 THEN
      IF FractionPlaces = -1 THEN
         ValidCiphers := 15; // 15 valid digits + 0.6 not fully valid digit + binary 1 on the mantissa start = approx. 16 (15.95)
      ELSE
         ValidCiphers := RoundPos; // Exp10 + FractionPlaces
      END;
   END;
   IF Exp10 <= 0 THEN
      S[s] := L'0'; INC( s );
      DotPos := s;
      S[s] := PointChar; INC( s );
      WHILE Exp10 < 0 DO
         S[s] := L'0'; INC( s );
         INC( Exp10 );
      END; // WHILE
      i := 0;
      WHILE B[i] <> -1 DO
         IF i >= INTEGER( ValidCiphers ) THEN
            S[s] := L'0'; INC( s );
         ELSIF B[i] = 0 THEN
            S[s] := L'0'; INC( s );
         ELSE
            S[s] := WCHAR( B[i] + ORD( '0' )); INC( s );
            FirstZero := s;
         END;
         INC( i );
      END; // WHILE
   ELSE
      i := 0;
      WHILE B[i] <> -1 DO
         IF i >= INTEGER( ValidCiphers ) THEN
            S[s] := L'0'; INC( s );
         ELSIF B[i] = 0 THEN
            S[s] := L'0'; INC( s );
         ELSE
            S[s] := WCHAR( B[i] + ORD( '0' )); INC( s );
            FirstZero := s;
         END;
         INC( i );
         IF i = Exp10 THEN
            DotPos := s;
            FirstZero := s; // remember only zeros after decpoint, so here set FirstZero forcibly
            S[s] := PointChar; INC( s );
         END;
      END; // WHILE
      IF i < Exp10 THEN
         REPEAT
            S[s] := L'0'; INC( s );
            INC( i );
         UNTIL i >= Exp10;
         FirstZero := s;
         DotPos := s;
         S[s] := PointChar; INC( s );
      END;
      FOR i := 0 TO INTEGER( FractionPlaces ) DO
         S[s] := L'0'; INC( s );
      END;
   END;
    
   // end number
   IF FractionPlaces = -1 THEN
      s := FirstZero;
   ELSIF FractionPlaces = 0 THEN
      s := DotPos;
   ELSE
      s := DotPos+INTEGER( FractionPlaces )+1;
   END;

   // append exponent
   IF ExpFlag THEN
      S[s] := L'E'; INC( s );
      IF ExpExp10 > 0 THEN
         S[s] := L'+'; INC( s );
      END;
      S[s] := 0W;
      Strings.FromINT32W( ExpExp10, 10, OUT sExp );
      Strings.AppendW( REF OA( HIGH( S )-s, ADR( S[s] )), sExp );
      INC( s, LENGTH( sExp ));
   END;

   S[s] := 0W;
   RETURN TRUE;
END LONGREALToStrW;
  
(*================================================================================*)

PROCEDURE StrToLONGREALW( CONST String : ARRAY OF WCHAR; OUT V : LONGREAL ) : BOOLEAN;
VAR
   ch : WCHAR;
   i : CARDINAL;
   R : LONGREAL := +0.0;
   F : LONGREAL := +0.0;
   f : LONGREAL;
   E : INTEGER := 0;	
   sign : BOOLEAN := FALSE;
BEGIN
   IF HIGH( String ) < 0 THEN
      RETURN FALSE;
   END;
   i := 0;
   IF String[i] = L'+' THEN
      INC( i );
   ELSIF String[i] = '-' THEN
      sign := TRUE;
      INC( i );
   END;
   IF NOT INSIDE( i, String ) THEN
      RETURN FALSE;
   END;

   // get whole part
   LOOP
      IF NOT INSIDE( i, String ) THEN
         IF sign THEN
            V := -R;
         ELSE
            V := R;
         END;
         RETURN TRUE;
      END;
      ch := String[i];
      IF ( ch = L'.' ) OR ( ch = L',' ) THEN
         INC( i );
         EXIT;
      ELSIF ( ch > L'9' ) OR ( ch < L'0' ) THEN
         RETURN FALSE;
      END;
      R := 10.0 * R + LONGREAL( ORD( ch ) - ORD( '0' ));
      INC( i );
   END; // LOOP

   // get fraction part
   f := 0.1;
   LOOP
      IF NOT INSIDE( i, String ) THEN
         V := R + F;
         IF sign THEN
            V := -V;
         END;
         RETURN TRUE;
      END;
      ch := String[i];
      IF ch = L'E' THEN
         R := R + F;
         IF sign THEN
            R := -R;
         END;
         INC( i );
         EXIT;
      ELSIF ( ch > L'9' ) OR ( ch < L'0' ) THEN
         RETURN FALSE;
      END;
      F := F + f * LONGREAL( ORD( ch ) - ORD( '0' ));
      f := f * 0.1;
      INC( i );
   END; // LOOP

   // get exponent part
   sign := FALSE;
   ch := String[i];
   IF ch = L'+' THEN
      INC( i );
   ELSIF ch = L'-' THEN
      sign := TRUE;
      INC( i );
   END;
   LOOP
      IF NOT INSIDE( i, String ) THEN
         EXIT;
      END;
      ch := String[i];
      IF ( ch > L'9' ) OR ( ch < L'0' ) THEN
         RETURN FALSE;
      END;
      E := 10 * E + INTEGER( ORD( ch ) - ORD( '0' ));
      INC( i );
   END; // LOOP

   // apply exponent
   IF sign THEN
      WHILE E > 0 DO
         R := R * 0.1;
         DEC( E );
      END; 
   ELSE
      WHILE E > 0 DO
         R := R * 10.0;
         DEC( E );
      END; // WHILE
   END;

   // result
   V := R;
   RETURN TRUE;
END StrToLONGREALW;

(*================================================================================*)

END lrconv.