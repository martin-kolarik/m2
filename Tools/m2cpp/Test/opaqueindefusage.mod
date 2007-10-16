MODULE opaqueindefusage;

FROM Storage IMPORT ALLOCATE;

IMPORT
  opaqueindef;

VAR
  R : opaqueindef.TR2;
  PR : opaqueindef.TPR2;

TYPE
  TR = RECORD
         A : opaqueindef.TPR;
       END;
       
PROCEDURE X();
BEGIN
  NEW( PR );
END X;

END opaqueindefusage.