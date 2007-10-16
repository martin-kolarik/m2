MODULE cases;

CONST
// Notification codes
  HHN_FIRST                   = CARDINAL( -860 );
  HHN_LAST                    = CARDINAL( -879 );

  HHN_NAVCOMPLETE             = CARDINAL( HHN_FIRST-0 );
  HHN_TRACK                   = CARDINAL( HHN_FIRST-1 );
  HHN_WINDOW_CREATE           = CARDINAL( HHN_FIRST-2 );

TYPE
  TEnum = ( ea, eb = CARDINAL(-20), ec = CARDINAL(-21) );
  TRecord = RECORD
              CASE E : TEnum OF
              | ea :
              | eb :
              | ec :
              END;
            END;

VAR
  A : CARDINAL;
  E : TEnum;
  I : INTEGER;
  I64 : INT64;

BEGIN
  CASE A OF
  | HHN_NAVCOMPLETE :
  | 1 :
  END; // CASE
  CASE I OF
  | HHN_NAVCOMPLETE :
  | 1 :
  END; // CASE
  CASE E OF
  | ea :
  | eb :
  | ec :
  END; // CASE
  CASE I64 OF
  | 0 :
  | 1 :
  END; // CASE
END cases.