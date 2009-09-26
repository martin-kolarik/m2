MODULE FieldOfs;

TYPE
   TPacketType = (
      ptUnknown,
      ptDataRequest,
      ptData,
      ptFillBuffer,
      ptNoData,
      ptACK,
      ptNAK
   );
   
   TValueType = (
      vtAnalog,
      vtInteger,
      vtDigital
   );

TYPE
   TPacket  = RECORD
                 CASE : TPacketType OF
                 | ptUnknown :
                    FIRST       : CHAR;
                 | ptDataRequest :
                    ENQ         : CHAR;
                    rAddress    : CHAR;
                 | ptData :
                    dSTX        : CHAR;
                    dAddress    : CHAR;
                    ValueType   : TValueType;
                    ValueIndex  : CHAR;
                    CASE : TValueType OF
                    | vtAnalog,
                      vtInteger :
                       Number   : ARRAY [0..3] OF CHAR;
                       nETX     : CHAR;
                       nChkSum  : ARRAY [0..1] OF CHAR;
                    | vtDigital :
                       Digital  : CHAR;
                       dETX     : CHAR;
                       dChkSum  : ARRAY [0..1] OF CHAR;
                    END; // CASE
                 | ptFillBuffer :
                    fSTX        : CHAR;
                    fAddress    : CHAR;
                    F           : CHAR;
                    fETX        : CHAR;
                    fChkSum     : ARRAY [0..1] OF CHAR;
                 | ptNoData :
                    NUL         : CHAR;
                 | ptACK :
                    ACK         : CHAR;
                 | ptNAK :
                    BEL         : CHAR;
                 END; // CASE
              END; // RECORD

PROCEDURE A() : CARDINAL;
BEGIN
   IF TRUE THEN
      RETURN FIELDOFS( TPacket.nChkSum );
   ELSE
      RETURN FIELDOFS( TPacket.fChkSum );
   END;
END A;

END FieldOfs.