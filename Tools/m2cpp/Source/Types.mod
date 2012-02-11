IMPLEMENTATION MODULE Types;

FROM Storage IMPORT
  ALLOCATE;

//============================================================

CLASS CUnknown( DOM.CType );
  VIRTUAL PROCEDURE Compatible( CM : DOM.TCompatibilityMode; PWith : DOM.TPType ) : BOOLEAN;
END CUnknown;

CLASS CAny( DOM.CType );
  VIRTUAL PROCEDURE Compatible( CM : DOM.TCompatibilityMode; PWith : DOM.TPType ) : BOOLEAN;
END CAny;

CLASS CStorage( DOM.CType );
  VIRTUAL PROCEDURE Compatible( CM : DOM.TCompatibilityMode; PWith : DOM.TPType ) : BOOLEAN;
END CStorage;

CLASS CFormalUnknown( DOM.CFormalType );
  VIRTUAL PROCEDURE Compatible( CM : DOM.TCompatibilityMode; PWith : DOM.TPType ) : BOOLEAN;
END CFormalUnknown;

CLASS COrdinalNumber( DOM.CType );
  VIRTUAL PROCEDURE Compatible( CM : DOM.TCompatibilityMode; PWith : DOM.TPType ) : BOOLEAN;
END COrdinalNumber;

CLASS COrdinalNumeric( DOM.CType );
  VIRTUAL PROCEDURE Compatible( CM : DOM.TCompatibilityMode; PWith : DOM.TPType ) : BOOLEAN;
END COrdinalNumeric;

CLASS COrdinal( DOM.CType );
  VIRTUAL PROCEDURE Compatible( CM : DOM.TCompatibilityMode; PWith : DOM.TPType ) : BOOLEAN;
END COrdinal;

CLASS COfAddOp( DOM.CType );
  VIRTUAL PROCEDURE Compatible( CM : DOM.TCompatibilityMode; PWith : DOM.TPType ) : BOOLEAN;
END COfAddOp;

CLASS COfMultOp( DOM.CType );
  VIRTUAL PROCEDURE Compatible( CM : DOM.TCompatibilityMode; PWith : DOM.TPType ) : BOOLEAN;
END COfMultOp;

CLASS COfNotOp( DOM.CType );
  VIRTUAL PROCEDURE Compatible( CM : DOM.TCompatibilityMode; PWith : DOM.TPType ) : BOOLEAN;
END COfNotOp;

CLASS CFloat( DOM.CType );
  VIRTUAL PROCEDURE Compatible( CM : DOM.TCompatibilityMode; PWith : DOM.TPType ) : BOOLEAN;
END CFloat;

CLASS CNumber( DOM.CType );
  VIRTUAL PROCEDURE Compatible( CM : DOM.TCompatibilityMode; PWith : DOM.TPType ) : BOOLEAN;
END CNumber;

CLASS CSet( DOM.CSet );
  VIRTUAL PROCEDURE Compatible( CM : DOM.TCompatibilityMode; PWith : DOM.TPType ) : BOOLEAN;
END CSet;

CLASS CSetNumber( DOM.CType );
  VIRTUAL PROCEDURE Compatible( CM : DOM.TCompatibilityMode; PWith : DOM.TPType ) : BOOLEAN;
END CSetNumber;

CLASS CNumericSet( DOM.CSet );
  VIRTUAL PROCEDURE Compatible( CM : DOM.TCompatibilityMode; PWith : DOM.TPType ) : BOOLEAN;
END CNumericSet;

// CLASS CINTPTR( DOM.CType );
//   VIRTUAL PROCEDURE Compatible( CM : DOM.TCompatibilityMode; PWith : DOM.TPType ) : BOOLEAN;
// END CINTPTR;

// CLASS CCARDPTR( DOM.CType );
//   VIRTUAL PROCEDURE Compatible( CM : DOM.TCompatibilityMode; PWith : DOM.TPType ) : BOOLEAN;
// END CCARDPTR;

CLASS CTCHAR( DOM.CType );
  VIRTUAL PROCEDURE Compatible( CM : DOM.TCompatibilityMode; PWith : DOM.TPType ) : BOOLEAN;
END CTCHAR;

CLASS CString( DOM.CType );
  VIRTUAL PROCEDURE Compatible( CM : DOM.TCompatibilityMode; PWith : DOM.TPType ) : BOOLEAN;
END CString;

CLASS CBYTE( DOM.CType );
  VIRTUAL PROCEDURE Compatible( CM : DOM.TCompatibilityMode; PWith : DOM.TPType ) : BOOLEAN;
END CBYTE;

CLASS CWORD( DOM.CType );
  VIRTUAL PROCEDURE Compatible( CM : DOM.TCompatibilityMode; PWith : DOM.TPType ) : BOOLEAN;
END CWORD;

CLASS CLONGWORD( DOM.CType );
  VIRTUAL PROCEDURE Compatible( CM : DOM.TCompatibilityMode; PWith : DOM.TPType ) : BOOLEAN;
END CLONGWORD;

CLASS CQUADWORD( DOM.CType );
  VIRTUAL PROCEDURE Compatible( CM : DOM.TCompatibilityMode; PWith : DOM.TPType ) : BOOLEAN;
END CQUADWORD;

// CLASS CSTOREPTR( DOM.CType );
//   VIRTUAL PROCEDURE Compatible( CM : DOM.TCompatibilityMode; PWith : DOM.TPType ) : BOOLEAN;
// END CSTOREPTR;

CLASS CADDRESS( DOM.CType );
  VIRTUAL PROCEDURE Compatible( CM : DOM.TCompatibilityMode; PWith : DOM.TPType ) : BOOLEAN;
END CADDRESS;

CLASS CPTR( DOM.CType );
  VIRTUAL PROCEDURE Compatible( CM : DOM.TCompatibilityMode; PWith : DOM.TPType ) : BOOLEAN;
END CPTR;

CLASS CSIZE( DOM.CType );
  VIRTUAL PROCEDURE Compatible( CM : DOM.TCompatibilityMode; PWith : DOM.TPType ) : BOOLEAN;
END CSIZE;

//============================================================

CLASS IMPLEMENTATION CUnknown;

  VIRTUAL PROCEDURE Compatible( CM : DOM.TCompatibilityMode; PWith : DOM.TPType ) : BOOLEAN;
  BEGIN
    RETURN PWith^.Unwrap() = TUnknown;
  END Compatible;

BEGIN
END CUnknown;

//============================================================

CLASS IMPLEMENTATION CAny;

  VIRTUAL PROCEDURE Compatible( CM : DOM.TCompatibilityMode; PWith : DOM.TPType ) : BOOLEAN;
  BEGIN
    RETURN PWith <> NIL;
  END Compatible;

BEGIN
  TypeKind := DOM.tkMorphable;
  N.FromOA( L'any type' );
END CAny;

//============================================================

CLASS IMPLEMENTATION CStorage;

  VIRTUAL PROCEDURE Compatible( CM : DOM.TCompatibilityMode; PWith : DOM.TPType ) : BOOLEAN;
  VAR
    PT : DOM.TPrimitiveType;
  BEGIN
    PWith := PWith^.Unwrap();
    PT := PWith^.PrimitiveType;
    RETURN ( PWith^.TypeKind = DOM.tkPrimitive ) AND
           (( PT = DOM.ptBYTE ) OR ( PT = DOM.ptWORD ) OR ( PT = DOM.ptLONGWORD ) OR ( PT = DOM.ptQUADWORD ));
  END Compatible;

BEGIN
  TypeKind := DOM.tkMorphable;
  N.FromOA( L'language storage' );
END CStorage;

//============================================================

CLASS IMPLEMENTATION CFormalUnknown;

  VIRTUAL PROCEDURE Compatible( CM : DOM.TCompatibilityMode; PWith : DOM.TPType ) : BOOLEAN;
  BEGIN
    RETURN PWith^.Unwrap() = TFormalUnknown;
  END Compatible;

BEGIN
END CFormalUnknown;

//============================================================

CLASS IMPLEMENTATION CFloat;

  VIRTUAL PROCEDURE Compatible( CM : DOM.TCompatibilityMode; PWith : DOM.TPType ) : BOOLEAN;
  VAR
    PT : DOM.TPrimitiveType;
  BEGIN
    PWith := PWith^.Unwrap();
    IF PWith = TFloat THEN
      RETURN TRUE;
    ELSE
      PT := PWith^.PrimitiveType;
      RETURN ( PWith^.TypeKind = DOM.tkPrimitive ) AND
             (( PT = DOM.ptREAL ) OR ( PT = DOM.ptLONGREAL ) OR ( PT = DOM.ptTEMPREAL ));
    END;
  END Compatible;

BEGIN
  TypeKind := DOM.tkMorphable;
  N.FromOA( L'decimal number' );
END CFloat;

//============================================================

CLASS IMPLEMENTATION COrdinalNumber;

  VIRTUAL PROCEDURE Compatible( CM : DOM.TCompatibilityMode; PWith : DOM.TPType ) : BOOLEAN;
  BEGIN
    PWith := PWith^.Unwrap();
    IF PWith^.TypeKind = DOM.tkRange THEN
      PWith := PWith^.T;
    END;
    IF PWith = TOrdinalNumber THEN
      RETURN TRUE;
    ELSIF PWith = TPTR THEN
      RETURN TRUE;
    ELSIF PWith = TTSIZE THEN
      RETURN TRUE;
    ELSIF PWith^.TypeKind <> DOM.tkPrimitive THEN
      RETURN FALSE;
    END;
    CASE PWith^.PrimitiveType OF
    | DOM.ptINT8, DOM.ptINT16, DOM.ptINT32, DOM.ptINT64,
      DOM.ptCARD8, DOM.ptCARD16, DOM.ptCARD32, DOM.ptCARD64 :
      RETURN TRUE;
    | DOM.ptBYTE, DOM.ptWORD, DOM.ptLONGWORD, DOM.ptQUADWORD :
      RETURN CM = DOM.cmOperation;
    ELSE
      RETURN FALSE;
    END;
  END Compatible;

BEGIN
  TypeKind := DOM.tkMorphable;
  N.FromOA( L'ordinal number' );
END COrdinalNumber;

//============================================================

CLASS IMPLEMENTATION COrdinalNumeric;

  VIRTUAL PROCEDURE Compatible( CM : DOM.TCompatibilityMode; PWith : DOM.TPType ) : BOOLEAN;
  BEGIN
    PWith := PWith^.Unwrap();
    IF PWith^.TypeKind = DOM.tkRange THEN
      PWith := PWith^.T;
    END;
    RETURN ( PWith = TOrdinalNumeric ) OR TOrdinalNumber^.Compatible( CM, PWith );
  END Compatible;

BEGIN
  TypeKind := DOM.tkMorphable;
  N.FromOA( L'ordinal numeric type' );
END COrdinalNumeric;

//============================================================

CLASS IMPLEMENTATION COrdinal;

  VIRTUAL PROCEDURE Compatible( CM : DOM.TCompatibilityMode; PWith : DOM.TPType ) : BOOLEAN;
  VAR
    PT : DOM.TPrimitiveType;
  BEGIN
    PWith := PWith^.Unwrap();
    IF PWith^.TypeKind = DOM.tkRange THEN
      PWith := PWith^.T;
    END;
    IF ( PWith = TOrdinal ) OR TOrdinalNumber^.Compatible( CM, PWith ) THEN
      RETURN TRUE;
    ELSIF PWith^.TypeKind = DOM.tkEnumeration THEN
      RETURN TRUE;
    ELSIF PWith^.TypeKind = DOM.tkPrimitive THEN
      PT := PWith^.PrimitiveType;
      RETURN ( PT = DOM.ptBOOLEAN ) OR ( PT = DOM.ptBCHAR ) OR ( PT = DOM.ptWCHAR );
    ELSE
      RETURN FALSE;
    END;
  END Compatible;

BEGIN
  TypeKind := DOM.tkMorphable;
  N.FromOA( L'ordinal' );
END COrdinal;

//============================================================

CLASS IMPLEMENTATION COfAddOp;

  VIRTUAL PROCEDURE Compatible( CM : DOM.TCompatibilityMode; PWith : DOM.TPType ) : BOOLEAN;
  BEGIN
    PWith := PWith^.Unwrap();
    RETURN TNumber^.Compatible( CM, PWith ) OR
           TStorage^.Compatible( CM, PWith ) OR
           TString^.Compatible( CM, PWith ) OR
           TSet^.Compatible( CM, PWith ) OR
           TPTR^.Compatible( CM, PWith );
  END Compatible;

BEGIN
  TypeKind := DOM.tkMorphable;
  N.FromOA( L'number, character or set' );
END COfAddOp;

//============================================================

CLASS IMPLEMENTATION COfMultOp;

  VIRTUAL PROCEDURE Compatible( CM : DOM.TCompatibilityMode; PWith : DOM.TPType ) : BOOLEAN;
  BEGIN
    PWith := PWith^.Unwrap();
    RETURN TNumber^.Compatible( CM, PWith ) OR
           TStorage^.Compatible( CM, PWith ) OR
           TSet^.Compatible( CM, PWith ) OR
           TPTR^.Compatible( CM, PWith );
  END Compatible;

BEGIN
  TypeKind := DOM.tkMorphable;
  N.FromOA( L'number or set' );
END COfMultOp;

//============================================================

CLASS IMPLEMENTATION COfNotOp;

  VIRTUAL PROCEDURE Compatible( CM : DOM.TCompatibilityMode; PWith : DOM.TPType ) : BOOLEAN;
  BEGIN
    RETURN TOrdinalNumber^.Compatible( CM, PWith ) OR
           TBOOLEAN^.Compatible( CM, PWith ) OR
           TStorage^.Compatible( CM, PWith ) OR
           TPTR^.Compatible( CM, PWith );
  END Compatible;

BEGIN
  TypeKind := DOM.tkMorphable;
  N.FromOA( L'BOOLEAN or ordinal number' );
END COfNotOp;

//============================================================

CLASS IMPLEMENTATION CNumber;

  VIRTUAL PROCEDURE Compatible( CM : DOM.TCompatibilityMode; PWith : DOM.TPType ) : BOOLEAN;
  BEGIN
    RETURN TOrdinalNumeric^.Compatible( CM, PWith ) OR TFloat^.Compatible( CM, PWith );
  END Compatible;

BEGIN
  TypeKind := DOM.tkMorphable;
  N.FromOA( L'number' );
END CNumber;

//============================================================

CLASS IMPLEMENTATION CSet;

  VIRTUAL PROCEDURE Compatible( CM : DOM.TCompatibilityMode; PWith : DOM.TPType ) : BOOLEAN;
  BEGIN
    PWith := PWith^.Unwrap();
    RETURN ( PWith^.TypeKind = DOM.tkSet ) OR ( PWith = TSet ) OR ( PWith = TNumericSet );
  END Compatible;

BEGIN
  TypeKind := DOM.tkMorphable;
  _Count := 8;
  N.FromOA( L'set' );
END CSet;

//============================================================

CLASS IMPLEMENTATION CSetNumber;

  VIRTUAL PROCEDURE Compatible( CM : DOM.TCompatibilityMode; PWith : DOM.TPType ) : BOOLEAN;
  BEGIN
    PWith := PWith^.Unwrap();
    IF PWith^.TypeKind = DOM.tkRange THEN
      PWith := PWith^.T;
    END;
    RETURN ( PWith = TSetNumber ) OR TOrdinalNumeric^.Compatible( CM, PWith ) OR TStorage^.Compatible( CM, PWith );
  END Compatible;

BEGIN
  TypeKind := DOM.tkMorphable;
  N.FromOA( L'number set member' );
END CSetNumber;

//============================================================

CLASS IMPLEMENTATION CNumericSet;

  VIRTUAL PROCEDURE Compatible( CM : DOM.TCompatibilityMode; PWith : DOM.TPType ) : BOOLEAN;
  BEGIN
    PWith := PWith^.Unwrap();
    RETURN ( PWith = TNumericSet ) OR (( PWith^.TypeKind = DOM.tkSet ) OR ( PWith = TSet )) AND T^.Compatible( CM, PWith^.T );
  END Compatible;

BEGIN
  TypeKind := DOM.tkMorphable;
  _Count := 8;
  N.FromOA( L'number set' );
END CNumericSet;

//============================================================

CLASS IMPLEMENTATION CTCHAR;

  VIRTUAL PROCEDURE Compatible( CM : DOM.TCompatibilityMode; PWith : DOM.TPType ) : BOOLEAN;
  BEGIN
    PWith := PWith^.Unwrap();
    IF PWith = TTCHAR THEN
      RETURN TRUE;
    ELSIF PWith^.TypeKind = DOM.tkPrimitive THEN
      RETURN ( PWith^.PrimitiveType = DOM.ptBCHAR ) OR ( PWith^.PrimitiveType = DOM.ptWCHAR );
    END;
    RETURN FALSE;
  END Compatible;

BEGIN
  TypeKind := DOM.tkMorphable;
  N.FromOA( L'TCHAR' );
END CTCHAR;

//============================================================

CLASS IMPLEMENTATION CString;

  VIRTUAL PROCEDURE Compatible( CM : DOM.TCompatibilityMode; PWith : DOM.TPType ) : BOOLEAN;
  VAR
    PT : DOM.TPrimitiveType;
  BEGIN
    PWith := PWith^.Unwrap();
    IF PWith = TString THEN
      RETURN TRUE;
    END;
    CASE PWith^.TypeKind OF
    | DOM.tkArray,
      DOM.tkStringArray,
      DOM.tkOpenArray :
      RETURN TTCHAR^.Compatible( CM, PWith^.T );
    | DOM.tkPrimitive :
      PT := PWith^.PrimitiveType;
      RETURN ( PT = DOM.ptBCHAR ) OR ( PT = DOM.ptWCHAR );
    END;
    RETURN FALSE;
  END Compatible;

BEGIN
  TypeKind := DOM.tkMorphable;
  N.FromOA( L'string' );
END CString;

//============================================================

CLASS IMPLEMENTATION CBYTE;

  VIRTUAL PROCEDURE Compatible( CM : DOM.TCompatibilityMode; PWith : DOM.TPType ) : BOOLEAN;
  VAR
    PT : DOM.TPrimitiveType;
  BEGIN
    PWith := PWith^.Unwrap();
    IF ( CM = DOM.cmExact ) AND ( PWith <> TBYTE ) THEN
      RETURN FALSE;
    ELSIF ( PWith = TBYTE ) OR ( PWith = TOrdinalNumber ) THEN
      RETURN TRUE;
    ELSIF PWith^.TypeKind = DOM.tkRange THEN
      RETURN Compatible( CM, PWith^.T );
    ELSIF ( PWith^.TypeKind = DOM.tkEnumeration ) AND ( PWith^.T <> NIL ) THEN
      RETURN Compatible( CM, PWith^.T );
    ELSE
      PT := PWith^.PrimitiveType;
      RETURN ( PWith^.TypeKind = DOM.tkPrimitive ) AND
             (( PT = DOM.ptBCHAR ) OR ( PT = DOM.ptINT8 ) OR ( PT = DOM.ptCARD8 ));
    END;
  END Compatible;

BEGIN
  TypeKind := DOM.tkPrimitive;
  PrimitiveType := DOM.ptBYTE;
  N.FromOA( L'BYTE' );
END CBYTE;

//============================================================

CLASS IMPLEMENTATION CWORD;

  VIRTUAL PROCEDURE Compatible( CM : DOM.TCompatibilityMode; PWith : DOM.TPType ) : BOOLEAN;
  VAR
    PT : DOM.TPrimitiveType;
  BEGIN
    PWith := PWith^.Unwrap();
    IF ( CM = DOM.cmExact ) AND ( PWith <> TWORD ) THEN
      RETURN FALSE;
    ELSIF ( PWith = TWORD ) OR ( PWith = TOrdinalNumber )THEN
      RETURN TRUE;
    ELSIF PWith^.TypeKind = DOM.tkRange THEN
      RETURN Compatible( CM, PWith^.T );
    ELSIF ( PWith^.TypeKind = DOM.tkEnumeration ) AND ( PWith^.T <> NIL ) THEN
      RETURN Compatible( CM, PWith^.T );
    ELSE
      PT := PWith^.PrimitiveType;
      RETURN ( PWith^.TypeKind = DOM.tkPrimitive ) AND
             (( PT = DOM.ptWCHAR ) OR ( PT = DOM.ptINT16 ) OR ( PT = DOM.ptCARD16 ));
    END;
  END Compatible;

BEGIN
  TypeKind := DOM.tkPrimitive;
  PrimitiveType := DOM.ptWORD;
  N.FromOA( L'WORD' );
END CWORD;

//============================================================

CLASS IMPLEMENTATION CLONGWORD;

  VIRTUAL PROCEDURE Compatible( CM : DOM.TCompatibilityMode; PWith : DOM.TPType ) : BOOLEAN;
  VAR
    PT : DOM.TPrimitiveType;
  BEGIN
    PWith := PWith^.Unwrap();
    IF ( CM = DOM.cmExact ) AND ( PWith <> TLONGWORD ) THEN
      RETURN FALSE;
    ELSIF ( PWith = TLONGWORD ) OR ( PWith = TOrdinalNumber )THEN
      RETURN TRUE;
    ELSIF PWith^.TypeKind = DOM.tkRange THEN
      RETURN Compatible( CM, PWith^.T );
    ELSIF PWith^.TypeKind = DOM.tkEnumeration THEN
      IF PWith^.T = TUnknown THEN
         RETURN DOM.TPEnumeration( PWith )^.OrdinalRange() <= MAX( CARD32 ); 
      ELSE
         RETURN Compatible( CM, PWith^.T );
      END;
    ELSIF PWith^.TypeKind = DOM.tkSet THEN
      RETURN DOM.TPSet( PWith )^.Count() <= 4;
    ELSE
      PT := PWith^.PrimitiveType;
      RETURN ( PWith^.TypeKind = DOM.tkPrimitive ) AND
             (( PT = DOM.ptINT32 ) OR ( PT = DOM.ptCARD32 ));
    END;
  END Compatible;

BEGIN
  TypeKind := DOM.tkPrimitive;
  PrimitiveType := DOM.ptLONGWORD;
  N.FromOA( L'LONGWORD' );
END CLONGWORD;

//============================================================

CLASS IMPLEMENTATION CQUADWORD;

  VIRTUAL PROCEDURE Compatible( CM : DOM.TCompatibilityMode; PWith : DOM.TPType ) : BOOLEAN;
  VAR
    PT : DOM.TPrimitiveType;
  BEGIN
    PWith := PWith^.Unwrap();
    IF ( CM = DOM.cmExact ) AND ( PWith <> TQUADWORD ) THEN
      RETURN FALSE;
    ELSIF ( PWith = TQUADWORD ) OR ( PWith = TOrdinalNumber ) THEN
      RETURN TRUE;
    ELSIF PWith^.TypeKind = DOM.tkRange THEN
      RETURN Compatible( CM, PWith^.T );
    ELSIF PWith^.TypeKind = DOM.tkEnumeration THEN
      IF PWith^.T = TUnknown THEN
         RETURN DOM.TPEnumeration( PWith )^.OrdinalRange() > MAX( CARD32 ); 
      ELSE
         RETURN Compatible( CM, PWith^.T );
      END;
    ELSIF PWith^.TypeKind = DOM.tkSet THEN
      RETURN DOM.TPSet( PWith )^.Count() <= 8;
    ELSE
      PT := PWith^.PrimitiveType;
      RETURN ( PWith^.TypeKind = DOM.tkPrimitive ) AND
             (( PT = DOM.ptINT64 ) OR ( PT = DOM.ptCARD64 ));
    END;
  END Compatible;

BEGIN
  TypeKind := DOM.tkPrimitive;
  PrimitiveType := DOM.ptQUADWORD;
  N.FromOA( L'QUADWORD' );
END CQUADWORD;

//============================================================

CLASS IMPLEMENTATION CADDRESS;

  VIRTUAL PROCEDURE Compatible( CM : DOM.TCompatibilityMode; PWith : DOM.TPType ) : BOOLEAN;
  BEGIN
    PWith := PWith^.Unwrap();
    IF ( CM = DOM.cmExact ) AND ( PWith <> TADDRESS ) THEN
      RETURN FALSE;
    ELSE
      RETURN ( PWith^.TypeKind = DOM.tkReference ) OR ( PWith = TPTR );
    END;
  END Compatible;

BEGIN
  TypeKind := DOM.tkReference;
  PrimitiveType := DOM.ptADDRESS;
  T := TCARDINAL;
  N.FromOA( L'M2ADDRESS' );
END CADDRESS;

//============================================================

CLASS IMPLEMENTATION CPTR;

  VIRTUAL PROCEDURE Compatible( CM : DOM.TCompatibilityMode; PWith : DOM.TPType ) : BOOLEAN;
  VAR
    PT : DOM.TPrimitiveType;
  BEGIN
    PWith := PWith^.Unwrap();
    IF ( CM = DOM.cmExact ) AND ( PWith <> TPTR ) THEN
      RETURN FALSE;
    ELSIF ( PWith = TPTR ) OR ( PWith = TOrdinalNumber ) OR ( PWith = TTSIZE ) THEN
      RETURN TRUE;
    ELSIF TADDRESS^.Compatible( CM, PWith ) THEN
      RETURN TRUE;
    ELSE
      PT := PWith^.PrimitiveType;
      RETURN ( PWith^.TypeKind = DOM.tkPrimitive ) AND
             (( PT = DOM.ptCARD8 ) OR
              ( PT = DOM.ptCARD16 ) OR
              ( PT = DOM.ptCARD32 ) OR
              ( PT = DOM.ptCARD64 ));
    END;
  END Compatible;

BEGIN
  TypeKind := DOM.tkPrimitive;
  PrimitiveType := DOM.ptPTR;
  N.FromOA( L'PTR' );
END CPTR;

//============================================================

CLASS IMPLEMENTATION CSIZE;

  VIRTUAL PROCEDURE Compatible( CM : DOM.TCompatibilityMode; PWith : DOM.TPType ) : BOOLEAN;
  VAR
    PT : DOM.TPrimitiveType;
  BEGIN
    PWith := PWith^.Unwrap();
    IF ( CM = DOM.cmExact ) AND ( PWith <> TTSIZE ) THEN
      RETURN FALSE;
    ELSIF ( PWith = TTSIZE ) OR ( PWith = TOrdinalNumber ) OR ( PWith = TPTR ) THEN
      RETURN TRUE;
    ELSE
      PT := PWith^.PrimitiveType;
      RETURN ( PWith^.TypeKind = DOM.tkPrimitive ) AND
             (( PT = DOM.ptCARD8 ) OR
              ( PT = DOM.ptCARD16 ) OR
              ( PT = DOM.ptCARD32 ) OR
              ( PT = DOM.ptCARD64 ));
    END;
  END Compatible;

BEGIN
  TypeKind := DOM.tkPrimitive;
  PrimitiveType := DOM.ptSIZE;
  N.FromOA( L'TSIZE' );
END CSIZE;

//============================================================

TYPE
  TPAny           = POINTER TO CAny;
  TPUnknown       = POINTER TO CUnknown;
  TPFormalUnknown = POINTER TO CFormalUnknown;
  TPStorage       = POINTER TO CStorage;
  TPFloat         = POINTER TO CFloat;
  TPOrdinal       = POINTER TO COrdinal;
  TPOrdinalNumeric= POINTER TO COrdinalNumeric;
  TPOrdinalNumber = POINTER TO COrdinalNumber;
  TPOfAddOp       = POINTER TO COfAddOp;
  TPOfMultOp      = POINTER TO COfMultOp;
  TPOfNotOp       = POINTER TO COfNotOp;
  TPNumber        = POINTER TO CNumber;
  TPCARDPTR       = POINTER TO CCARDPTR;
  TPINTPTR        = POINTER TO CINTPTR;
  TPSet           = POINTER TO CSet;
  TPSetNumber     = POINTER TO CSetNumber;
  TPNumericSet    = POINTER TO CNumericSet;
  TPTCHAR         = POINTER TO CTCHAR;
  TPString        = POINTER TO CString;
  TPBYTE          = POINTER TO CBYTE;
  TPWORD          = POINTER TO CWORD;
  TPLONGWORD      = POINTER TO CLONGWORD;
  TPQUADWORD      = POINTER TO CQUADWORD;
  TPSTOREPTR      = POINTER TO CSTOREPTR;
  TPADDRESS       = POINTER TO CADDRESS;
  TPPTR           = POINTER TO CPTR;
  TPSIZE          = POINTER TO CSIZE;

INITIALLY __I(); 
BEGIN
  // compiler types
  NEW( TPAny( TAny ));
  NEW( TPUnknown( TUnknown ));
  NEW( TPFormalUnknown( TFormalUnknown ));
  TUnknown^.N.FromOA( L'unknown type' );
  TUnknown^.T := TUnknown;
  NEW( TPStorage( TStorage ));

  NEW( TPFloat( TFloat ));
  NEW( TPOrdinal( TOrdinal ));
  NEW( TPOrdinalNumeric( TOrdinalNumeric ));
  NEW( TPOrdinalNumber( TOrdinalNumber ));
  NEW( TPOfAddOp( TOfAddOp ));
  NEW( TPOfMultOp( TOfMultOp ));
  NEW( TPOfNotOp( TOfNotOp ));
  NEW( TPNumber( TNumber ));
  NEW( TPSet( TSet ));
    TSet^.T := TOrdinal;
  NEW( TPSetNumber( TSetNumber ));
  NEW( TPNumericSet( TNumericSet ));
    TNumericSet^.T := TSetNumber;
  NEW( TPTCHAR( TTCHAR ));
  NEW( TPString( TString ));

  // language types
  NEW( TINT8 );     TINT8^.    Init3( L'INT8',        DOM.tkPrimitive,     DOM.ptINT8 );
  NEW( TINT16 );    TINT16^.   Init3( L'INT16',       DOM.tkPrimitive,     DOM.ptINT16 );
  NEW( TINT32 );    TINT32^.   Init3( L'INT32',       DOM.tkPrimitive,     DOM.ptINT32 );
  NEW( TINT64 );    TINT64^.   Init3( L'INT64',       DOM.tkPrimitive,     DOM.ptINT64 );
  // NEW( TPINTPTR( TINTPTR ));
  NEW( TSHORTINT ); TSHORTINT^.Init3( L'SHORTINT',    DOM.tkLink, DOM.ptUnknown );
       TSHORTINT^.T := TINT16;
  NEW( TINTEGER );  TINTEGER^. Init3( L'INTEGER',     DOM.tkLink, DOM.ptUnknown );
       TINTEGER^.T := TINT32;
  NEW( TLONGINT );  TLONGINT^. Init3( L'LONGINT',     DOM.tkLink, DOM.ptUnknown );
       TLONGINT^.T := TINT32;

  NEW( TCARD8 );    TCARD8^.   Init3( L'CARD8',       DOM.tkPrimitive,     DOM.ptCARD8 );
  NEW( TCARD16 );   TCARD16^.  Init3( L'CARD16',      DOM.tkPrimitive,     DOM.ptCARD16 );
  NEW( TCARD32 );   TCARD32^.  Init3( L'CARD32',      DOM.tkPrimitive,     DOM.ptCARD32 );
  NEW( TCARD64 );   TCARD64^.  Init3( L'CARD64',      DOM.tkPrimitive,     DOM.ptCARD64 );
  // NEW( TPCARDPTR( TCARDPTR ));
  NEW( TSHORTCARD ); TSHORTCARD^.Init3( L'SHORTCARD', DOM.tkLink, DOM.ptUnknown );
       TSHORTCARD^.T := TCARD16;
  NEW( TCARDINAL ); TCARDINAL^.Init3( L'CARDINAL',    DOM.tkLink, DOM.ptUnknown );
       TCARDINAL^.T := TCARD32;
  NEW( TLONGCARD ); TLONGCARD^.Init3( L'LONGCARD',    DOM.tkLink, DOM.ptUnknown );
       TLONGCARD^.T := TCARD32;

  NEW( TBOOLEAN );  TBOOLEAN^. Init3( L'BOOLEAN',     DOM.tkPrimitive,     DOM.ptBOOLEAN );
  NEW( TTRISTATE ); TTRISTATE^.Init3( L'TRISTATE',    DOM.tkRange,         DOM.ptUnknown );
    TTRISTATE^.T := TINT8;
    TTRISTATE^.Count := 3;
    TTRISTATE^.First := -1;
    TTRISTATE^.Last := 1;

  // strings...
  NEW( TBCHAR );    TBCHAR^.   Init3( L'CHAR',        DOM.tkPrimitive,     DOM.ptBCHAR );
  NEW( TBString );  TBString^. Init2( L'byte string', DOM.tkStringArray );
       TBString^.T := TBCHAR;
  
  NEW( TWCHAR );    TWCHAR^.   Init3( L'WCHAR',       DOM.tkPrimitive,     DOM.ptWCHAR );
  NEW( TWString );  TWString^. Init2( L'word string', DOM.tkStringArray );
       TWString^.T := TWCHAR;
  
  NEW( TTCHARB );   TTCHARB^.  Init2( L'TCHAR', DOM.tkLink );
       TTCHARB^.T := TBCHAR;
  NEW( TTStringB ); TTStringB^.Init2( L'string', DOM.tkStringArray );
       TTStringB^.T := TTCHARB;

  NEW( TTCHARW );   TTCHARW^.  Init2( L'TCHAR', DOM.tkLink );
       TTCHARW^.T := TWCHAR;
  NEW( TTStringW ); TTStringW^.Init2( L'string', DOM.tkStringArray );
       TTStringW^.T := TTCHARW;

  NEW( TBOAString ); TBOAString^.Init2( L'open array string', DOM.tkOpenArray );
       INCL( TBOAString^.Options, DOM.coOASize );
       TBOAString^.T := TBCHAR;
  NEW( TWOAString ); TWOAString^.Init2( L'open array string', DOM.tkOpenArray );
       INCL( TWOAString^.Options, DOM.coOASize );
       TWOAString^.T := TWCHAR;
  NEW( TBCONSTOAString ); TBCONSTOAString^.Init2( L'const open array string', DOM.tkOpenArray );
       INCL( TBCONSTOAString^.Options, DOM.coOASize );
       TBCONSTOAString^.T := TBCHAR;
       TBCONSTOAString^.TypeModifier := DOM.tmCONST;
  NEW( TBCONSTOAStringSZ ); TBCONSTOAStringSZ^.Init2( L'const open array string', DOM.tkOpenArray );
       EXCL( TBCONSTOAStringSZ^.Options, DOM.coOASize );
       TBCONSTOAStringSZ^.T := TBCHAR;
       TBCONSTOAStringSZ^.TypeModifier := DOM.tmCONST;
  NEW( TWCONSTOAString ); TWCONSTOAString^.Init2( L'const open array string', DOM.tkOpenArray );
       INCL( TWCONSTOAString^.Options, DOM.coOASize );
       TWCONSTOAString^.T := TWCHAR;
       TWCONSTOAString^.TypeModifier := DOM.tmCONST;
  NEW( TWCONSTOAStringSZ ); TWCONSTOAStringSZ^.Init2( L'const open array string', DOM.tkOpenArray );
       EXCL( TWCONSTOAStringSZ^.Options, DOM.coOASize );
       TWCONSTOAStringSZ^.T := TWCHAR;
       TWCONSTOAStringSZ^.TypeModifier := DOM.tmCONST;
  // ...strings

  NEW( TBITSET8 );  TBITSET8^. Init3( L'BITSET8',     DOM.tkSet,  DOM.ptUnknown );
       TBITSET8^.T := TOrdinalNumber;
       TBITSET8^._Count := 1;
  NEW( TBITSET16 ); TBITSET16^.Init3( L'BITSET16',    DOM.tkSet,  DOM.ptUnknown );
       TBITSET16^.T := TOrdinalNumber;
       TBITSET16^._Count := 2;
  NEW( TBITSET32 ); TBITSET32^.Init3( L'BITSET32',    DOM.tkSet,  DOM.ptUnknown );
       TBITSET32^.T := TOrdinalNumber;
       TBITSET32^._Count := 4;
  NEW( TBITSET64 ); TBITSET64^.Init3( L'BITSET64',    DOM.tkSet,  DOM.ptUnknown );
       TBITSET64^.T := TOrdinalNumber;
       TBITSET64^._Count := 8;
  NEW( TBITSET );   TBITSET^.  Init3( L'BITSET',      DOM.tkLink, DOM.ptUnknown );
       TBITSET^.T := TBITSET32;

  NEW( TPBYTE( TBYTE ));
  NEW( TPWORD( TWORD ));
  NEW( TPLONGWORD( TLONGWORD ));
  NEW( TPQUADWORD( TQUADWORD ));
  // NEW( TPSTOREPTR( TSTOREPTR ));

  NEW( TPADDRESS( TADDRESS ));
  NEW( TREFADDRESS );
       TREFADDRESS^.T := TADDRESS;
       TREFADDRESS^.TypeModifier := DOM.tmREF;
  NEW( TPPTR( TPTR ));
  NEW( TPSIZE( TTSIZE )); 
  NEW( TFormalSIZE );
    TFormalSIZE^.T := TTSIZE;

  NEW( TREAL );     TREAL^.        Init3( L'REAL',        DOM.tkPrimitive,     DOM.ptREAL );
  NEW( TLONGREAL ); TLONGREAL^.    Init3( L'LONGREAL',    DOM.tkPrimitive,     DOM.ptLONGREAL );
  NEW( TPROC );     TPROC^.        Init3( L'PROC',        DOM.tkProcedure,     DOM.ptPROC );
  NEW( TOBJECT );   TOBJECT^.      Init3( L'OBJECT',      DOM.tkClass,         DOM.ptOBJECT );
  NEW( TException );TException^.   Init3( L'Exceptions::Exception', DOM.tkClass, DOM.ptUnknown );

  // language pointer types
  NEW( TpINT8 );      TpINT8^.     Init3( L'PINT8',      DOM.tkReference, DOM.ptUnknown );
       TpINT8^.T := TINT8;
  NEW( TpINT16 );     TpINT16^.    Init3( L'PINT16',     DOM.tkReference, DOM.ptUnknown );
       TpINT16^.T := TINT16;
  NEW( TpINT32 );     TpINT32^.    Init3( L'PINT32',     DOM.tkReference, DOM.ptUnknown );
       TpINT32^.T := TINT32;
  NEW( TpINT64 );     TpINT64^.    Init3( L'PINT64',     DOM.tkReference, DOM.ptUnknown );
       TpINT64^.T := TINT64;
  // NEW( TpINTPTR );    TpINTPTR^.   Init3( L'PINTPTR',    DOM.tkReference, DOM.ptUnknown );
  //      TpINTPTR^.T := TINTPTR;
  NEW( TpSHORTINT );  TpSHORTINT^. Init3( L'PSHORTINT',  DOM.tkReference, DOM.ptUnknown );
       TpSHORTINT^.T := TSHORTINT;
  NEW( TpINTEGER );   TpINTEGER^.  Init3( L'PINTEGER',   DOM.tkReference, DOM.ptUnknown );
       TpINTEGER^.T := TINTEGER;
  NEW( TpLONGINT );   TpLONGINT^.  Init3( L'PLONGINT',   DOM.tkReference, DOM.ptUnknown );
       TpLONGINT^.T := TLONGINT;

  NEW( TpCARD8 );     TpCARD8^.    Init3( L'PCARD8',     DOM.tkReference, DOM.ptUnknown );
       TpCARD8^.T := TCARD8;
  NEW( TpCARD16 );    TpCARD16^.   Init3( L'PCARD16',    DOM.tkReference, DOM.ptUnknown );
       TpCARD16^.T := TCARD16;
  NEW( TpCARD32 );    TpCARD32^.   Init3( L'PCARD32',    DOM.tkReference, DOM.ptUnknown );
       TpCARD32^.T := TCARD32;
  NEW( TpCARD64 );    TpCARD64^.   Init3( L'PCARD64',    DOM.tkReference, DOM.ptUnknown );
       TpCARD64^.T := TCARD64;
  // NEW( TpCARDPTR );   TpCARDPTR^.  Init3( L'PCARDPTR',   DOM.tkReference, DOM.ptUnknown );
  //      TpCARDPTR^.T := TCARDPTR;
  NEW( TpSHORTCARD ); TpSHORTCARD^.Init3( L'PSHORTCARD', DOM.tkReference, DOM.ptUnknown );
       TpSHORTCARD^.T := TSHORTCARD;
  NEW( TpCARDINAL );  TpCARDINAL^. Init3( L'PCARDINAL',  DOM.tkReference, DOM.ptUnknown );
       TpCARDINAL^.T := TCARDINAL;
  NEW( TpLONGCARD );  TpLONGCARD^. Init3( L'PLONGCARD',  DOM.tkReference, DOM.ptUnknown );
       TpLONGCARD^.T := TLONGCARD;

  NEW( TpBOOLEAN );   TpBOOLEAN^.  Init3( L'PBOOLEAN',   DOM.tkReference, DOM.ptUnknown );
       TpBOOLEAN^.T := TBOOLEAN;
  NEW( TpTRISTATE );  TpTRISTATE^. Init3( L'PTRISTATE',  DOM.tkReference, DOM.ptUnknown );
       TpTRISTATE^.T := TTRISTATE;

  NEW( TpBCHAR );     TpBCHAR^.    Init3( L'PBCHAR',     DOM.tkReference, DOM.ptUnknown );
       TpBCHAR^.T := TBCHAR;
  NEW( TpWCHAR );     TpWCHAR^.    Init3( L'PWCHAR',     DOM.tkReference, DOM.ptUnknown );
       TpWCHAR^.T := TWCHAR;
  NEW( TpTCHARB );    TpTCHARB^.   Init3( L'PTCHARB',    DOM.tkReference, DOM.ptUnknown );
       TpTCHARB^.T := TTCHARB;
  NEW( TpTCHARW );    TpTCHARW^.   Init3( L'PTCHARW',    DOM.tkReference, DOM.ptUnknown );
       TpTCHARW^.T := TTCHARW;

  NEW( TpBITSET8 );   TpBITSET8^.  Init3( L'PBITSET8',   DOM.tkReference, DOM.ptUnknown );
       TpBITSET8^.T := TBITSET8;
  NEW( TpBITSET16 );  TpBITSET16^. Init3( L'PBITSET16',  DOM.tkReference, DOM.ptUnknown );
       TpBITSET16^.T := TBITSET16;
  NEW( TpBITSET32 );  TpBITSET32^. Init3( L'PBITSET32',  DOM.tkReference, DOM.ptUnknown );
       TpBITSET32^.T := TBITSET32;
  NEW( TpBITSET64 );  TpBITSET64^. Init3( L'PBITSET64',  DOM.tkReference, DOM.ptUnknown );
       TpBITSET64^.T := TBITSET64;
  NEW( TpBITSET );    TpBITSET^.   Init3( L'PBITSET',    DOM.tkReference, DOM.ptUnknown );
       TpBITSET^.T := TBITSET;

  NEW( TpBYTE );      TpBYTE^.     Init3( L'PBYTE',      DOM.tkReference, DOM.ptUnknown );
       TpBYTE^.T := TBYTE;
  NEW( TpWORD );      TpWORD^.     Init3( L'PWORD',      DOM.tkReference, DOM.ptUnknown );
       TpWORD^.T := TWORD;
  NEW( TpLONGWORD );  TpLONGWORD^. Init3( L'PLONGWORD',  DOM.tkReference, DOM.ptUnknown );
       TpLONGWORD^.T := TLONGWORD;
  NEW( TpQUADWORD );  TpQUADWORD^. Init3( L'PQUADWORD',  DOM.tkReference, DOM.ptUnknown );
       TpQUADWORD^.T := TQUADWORD;
  // NEW( TpSTOREPTR );  TpSTOREPTR^. Init3( L'PSTOREPTR',  DOM.tkReference, DOM.ptUnknown );
  //      TpSTOREPTR^.T := TSTOREPTR;

  NEW( TpADDRESS );   TpADDRESS^.  Init3( L'PADDRESS',   DOM.tkReference, DOM.ptUnknown );
       TpADDRESS^.T := TADDRESS;
  NEW( TpPTR );       TpPTR^.      Init3( L'PPTR',       DOM.tkReference, DOM.ptUnknown );
       TpPTR^.T := TPTR;
  NEW( TpTSIZE );     TpTSIZE^.    Init3( L'PTSIZE',     DOM.tkReference, DOM.ptUnknown );
       TpTSIZE^.T := TTSIZE;

  NEW( TpREAL );      TpREAL^.     Init3( L'PREAL',      DOM.tkReference, DOM.ptUnknown );
       TpREAL^.T := TREAL;
  NEW( TpLONGREAL );  TpLONGREAL^. Init3( L'PLONGREAL',  DOM.tkReference, DOM.ptUnknown );
       TpLONGREAL^.T := TLONGREAL;
  NEW( TpPROC );      TpPROC^.     Init3( L'PPROC',      DOM.tkReference, DOM.ptUnknown );
       TpPROC^.T := TPROC;
  NEW( TpOBJECT );    TpOBJECT^.   Init3( L'POBJECT',    DOM.tkReference, DOM.ptUnknown );
       TpOBJECT^.T := TOBJECT;
       
  NEW( TpException ); TpException^.Init3( L'Exceptions::Exception*', DOM.tkReference, DOM.ptUnknown );
       TpException^.T := TException;
END __I;

END Types.