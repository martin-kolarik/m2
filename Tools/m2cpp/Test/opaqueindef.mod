IMPLEMENTATION MODULE opaqueindef;

TYPE
  TPD = POINTER TO D;
  TOpq = POINTER TO Q;

  TR = RECORD
         A : CARDINAL;
         PD : TPD;
         PQ : TOpq;
       END;

CLASS C;
END C;

CLASS IMPLEMENTATION C;
END C;

CLASS D;
END D;

CLASS IMPLEMENTATION D;
END D;

CLASS Q;
END Q;

CLASS IMPLEMENTATION Q;
END Q;

VAR
  VR : TPR;
  PC : TPC;
  VC : C;

BEGIN
  IF VR^.A = 0 THEN END;
  IF ADR( VC ) = PC THEN END;
END opaqueindef.