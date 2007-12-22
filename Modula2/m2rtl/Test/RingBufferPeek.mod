MODULE ringbufferpeek;

IMPORT
  SyncQueue;
  
VAR
  R : SyncQueue.RingBuffer;
  
PROCEDURE Test();
CONST
  S1 = C'********************************************************************************';
  S2 = C'00010203040506070809101112131415161718192021222324252627282930313233343536373839';
VAR
  A : ADDRESS;
  L : CARDINAL;
  S3 : ARRAY [0..79] OF CHAR;
  b : BOOLEAN;
BEGIN
  R.Size := 100;
  R.WriteOA( S1 );
  b := R.Peek( OUT A, OUT L ); // full block
  R.ReadOA( OUT S3 );
  R.WriteOA( S2 );
  b := R.Peek( OUT A, OUT L ); // moved block
END Test;  

#save, call( convention => cdecl )
PROCEDURE wmain11() : INTEGER;
#restore
BEGIN
  Test();
  RETURN 0;
END wmain11;

END ringbufferpeek.