IMPLEMENTATION MODULE cphcommonO;

IMPORT
   cphcommon;

(*================================================================================*)

PROCEDURE FromBASE64( CONST String : StringsO.IString; BinAppendFlag : BOOLEAN; REF Bin : StorageO.AMemoryBuffer ) : BOOLEAN;
VAR
   filled : CARDINAL;
   size : CARDINAL;
   startIndex : CARDINAL;
BEGIN
   IF NOT BinAppendFlag THEN
      Bin.Clear();
   END;
   size := cphcommon.BASE64ByteCount( String.Length );
   IF size = 0 THEN
      RETURN TRUE;
   END;
   startIndex := Bin.Length;
   Bin.Size := startIndex + size;
   IF NOT cphcommon.FromBASE64( OA( String.Length-1, String.Data ), OUT OA( size-1, Bin.Data@[startIndex] ), OUT filled ) THEN
      RETURN FALSE;
   END;
   Bin.Length := Bin.Length + filled;
   RETURN TRUE;
END FromBASE64;

(*--------------------------------------------------------------------------------*)

PROCEDURE FromBASE64OA( CONST String : StringsO.IString; OUT Bin : ARRAY OF BYTE; OUT Filled : CARDINAL ) : BOOLEAN;
VAR
   bin : StorageO.CMemoryBuffer;
BEGIN
   IF NOT FromBASE64( String, FALSE, REF bin ) THEN
      RETURN FALSE;
   END;
   bin.ToOA( OUT Bin, OUT Filled );
   RETURN TRUE;
END FromBASE64OA;

(*--------------------------------------------------------------------------------*)

PROCEDURE ToBASE64( CONST Bin : StorageO.AMemoryBuffer; OUT String : StringsO.IString );
VAR
   size : CARDINAL;
BEGIN
   size := cphcommon.BASE64CharCount( Bin.Length );
   IF size = 0 THEN
      String.Clear();
      RETURN;
   END;
   String.Size := size;
   IF cphcommon.ToBASE64( OA( Bin.Length-1, Bin.Data ), OUT OA( size-1, PWCHAR( String.Data ))) THEN
      String.Length := size;
   ELSE
      String.Clear();
   END;
END ToBASE64;

(*--------------------------------------------------------------------------------*)

PROCEDURE ToBASE64OA( CONST Bin : ARRAY OF BYTE; OUT String : StringsO.IString );
VAR
   bin : StorageO.CMemoryBuffer;
BEGIN
   bin.FromOA( Bin, FALSE );
   ToBASE64( bin, OUT String );
END ToBASE64OA;

(*================================================================================*)

END cphcommonO.

