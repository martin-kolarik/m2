IMPLEMENTATION MODULE LanguagesO;

IMPORT
   Languages,
   Storage;

(*================================================================================*)

PROCEDURE ToMB( CONST String : StringsO.IString; CodePage : CARDINAL; BufferAppendFlag : BOOLEAN; REF Buffer : StorageO.AMemoryBuffer );
VAR
   a : PBYTE;
   bl : CARDINAL;
   l, min, max, s : CARDINAL;
   f : BOOLEAN;
BEGIN
   IF BufferAppendFlag THEN
      bl := Buffer.Length;
   ELSE
      Buffer.Clear();
      bl := 0;
   END;

   l := String.Length;
   IF l = 0 THEN
      // do nothing
   ELSIF ( CodePage = Languages.cp_UTF16 ) OR ( CodePage = Languages.cp_UTF16_BIG_ENDIAN ) THEN
      Buffer.Size := bl + l << 1;
      Buffer.Length := bl + l << 1;
      Storage.Move( String.Data, Buffer.Data@[bl], l );
   ELSE
      Languages.BytesPerCharacter( CodePage, OUT f, OUT min, OUT max );
      s := l * max; // the worst case
      Buffer.Size := bl + s;
      a := Buffer.Data@[bl];
      IF Languages.ToAStream( OA( l-1, String.Data ), CodePage, OUT OA( s-1, a ), OUT s, OUT l ) THEN
         Buffer.Length := bl + l;
      ELSE // reset buffer back to previous length
         Buffer.Length := bl;
      END;
   END;
END ToMB;

(*--------------------------------------------------------------------------------*)

PROCEDURE FromMB( CONST Buffer : StorageO.AMemoryBuffer; CodePage : CARDINAL; OUT String : StringsO.IString );
VAR
   a : PWCHAR;
   c, l : CARDINAL;
BEGIN
   l := Buffer.Length;
   IF l = 0 THEN
      String.Clear();
   ELSIF ( CodePage = Languages.cp_UTF16 ) OR ( CodePage = Languages.cp_UTF16_BIG_ENDIAN ) THEN
      String.Size := l >> 1;
      String.Length := l >> 1;
      Storage.Move( Buffer.Data, String.Data, l );
   ELSE
      String.Size := l; // the worst case
      String.Length := 1; // some not empty string
      a := String.Data;
      IF Languages.ToWStream( OA( l-1, Buffer.Data ), CodePage, OUT OA( l-1, a ), OUT c, OUT l ) THEN
         String.Length := l;
      ELSE
         String.Clear();
      END;
   END;
END FromMB;

(*================================================================================*)

END LanguagesO.
