MODULE longsets;

TYPE
  TXS = SET CARD8 OF [0..7];

  TSS = SET OF [0..31];
  TMS = SET OF [0..63];
  TLS = SET OF [0..127];

VAR
  BT : BITSET;
  VSS : TSS;
  VMS : TMS;
  VLS, VLS1, VLS2, VLS3 : TLS;

PROCEDURE Test();  
BEGIN
  BT := BT + BT;
  BT := BT - BT;
  BT := BT * BT;
  BT := BT / BT;
  INCL( BT, 12 );

  VSS := VSS + VSS;
  VSS := VSS - VSS;
  VSS := VSS * VSS;
  VSS := VSS / VSS;
  INCL( VSS, 12 );

  VMS := VMS + VMS;
  VMS := VMS - VMS;
  VMS := VMS * VMS;
  VMS := VMS / VMS;
  INCL( VMS, 12 );

  VLS := VLS1 + VLS2;
  VLS := VLS1 - VLS2;
  VLS := VLS1 * VLS2;
  VLS := VLS1 / VLS2;
  INCL( VLS, 12 );

  VLS := VLS1 + VLS2 + VLS3;
  VLS := VLS1 - VLS2 + VLS3;
  VLS := VLS1 * VLS2 * VLS3;
  VLS := VLS1 / VLS2 / VLS3;
END Test;
  
END longsets.