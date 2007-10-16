MODULE structuredconstex;

TYPE
  TInk = RECORD
           Color     : CARDINAL;
           LineStyle : CARDINAL;
           LineWidth : CARDINAL;
         END;

CONST
  ptPatternPaper  = 0;
  ptSolidPaper    = 1;

TYPE
  TPattern  = ARRAY [ 0..7 ] OF CARD8;
  TPaper = RECORD
             CASE PaperType : CARDINAL OF
             | ptPatternPaper:
               Color   : CARDINAL;
               FColor  : CARDINAL;
               Pattern : TPattern;
             | ptSolidPaper:
               PaperColor : CARDINAL;
             | 2:
               ColorL    : CARDINAL;
               FColorL   : CARDINAL;
               PatternL0 : CARD32;
               PatternL1 : CARD32;
             END;
             OrgX : CARD16;
             OrgY : CARD16;
           END;

  TGContext = RECORD
                Ink         : TInk;
                Paper       : TPaper;
                TShadow     : CARDINAL;
                BShadow     : CARDINAL;
                TShadowAlt  : CARDINAL;
                BShadowAlt  : CARDINAL;
                Font        : ADDRESS;
                TextJustify : BITSET;
                TextColor   : CARDINAL;
                WriteMode   : CARDINAL;
                Private     : BOOLEAN;
              END;
  TPGContext = POINTER TO TGContext;              

  TGCArray  = ARRAY [ 0..0 ] OF TGContext;

  CONST
    DefaultGCArray = TGCArray(
      TGContext(
        TInk( 0FFFFFFH, 0, 0 ),
        TPaper( ptPatternPaper,
                    07F7F00H, 07F0000H,
                    TPattern( 0AAH, 055H, 0AAH, 055H, 0AAH, 055H, 0AAH, 055H ),
                    0, 0 ),
        0,
        0,
        0,
        0,
        NIL,
        {0, 1},
        0,
        1,
        FALSE )
    );

VAR
  P : TPGContext;
BEGIN
  P := ADR( DefaultGCArray[0] );
END structuredconstex.