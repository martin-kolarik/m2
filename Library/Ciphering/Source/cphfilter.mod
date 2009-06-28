IMPLEMENTATION MODULE cphfilter;

IMPORT
   Storage;

(*================================================================================*)

CLASS IMPLEMENTATION CRijndaelFilter;

(*--------------------------------------------------------------------------------*)

   PUBLIC VIRTUAL PROCEDURE Filter( CONST Source : ARRAY OF BYTE; OUT Consumed : CARDINAL; REF Destination : ARRAY OF BYTE; OUT Filled : CARDINAL ) : Sync.TAsyncResult;
   VAR
      i : CARDINAL;
   BEGIN
      Consumed := 0;
      Filled := 0;

      IF _Encrypt THEN
         IF _OnInit THEN
            Filled := MIN2( HIGH( Destination )+1, _Digest.size - _InitOffset );
            Storage.Move( _Digest.digest@[_InitOffset], ADR( Destination ), Filled );
            INC( _InitOffset, Filled );
            _OnInit := _InitOffset < _Digest.size;
         END;
         IF NOT _OnInit THEN
            Consumed := MIN2( HIGH( Source )+1, HIGH( Destination )+1-Filled );
            _Cipher.Encrypt( OA( Consumed-1, ADR( Source )), OUT OA( Consumed-1, ADR( Destination )@[Filled] ), OUT Consumed );
            INC( Filled, Consumed );
         END;

      ELSE // decrypt
         IF _OnInit THEN
            Consumed := MIN2( HIGH( Source )+1, _Digest.size - _InitOffset );
            FOR i := 0 TO Consumed-1 DO
               IF Source[i] <> _Digest.digest@[_InitOffset+i]^ THEN
                  RETURN Sync.arAborted;
               END;
            END;
            INC( _InitOffset, Consumed );
            _OnInit := _InitOffset < _Digest.size;
         END;
         IF NOT _OnInit THEN
            Filled := MIN2( HIGH( Source )+1-Consumed, HIGH( Destination )+1 );
            _Cipher.Decrypt( OA( Filled-1, ADR( Source )@[Consumed] ), OUT OA( Filled-1, ADR( Destination )), OUT Filled );
            INC( Consumed, Filled );
         END;

      END;
      RETURN Sync.arCompleted;
   END Filter;

(*--------------------------------------------------------------------------------*)

   PUBLIC VIRTUAL PROCEDURE CloseFilter( REF Destination : ARRAY OF BYTE; OUT Filled : CARDINAL ) : Sync.TAsyncResult;
   BEGIN
      Filled := 0;
      RETURN Sync.arCompleted;
   END CloseFilter;

(*--------------------------------------------------------------------------------*)

   PUBLIC PROCEDURE Init( Encrypt : BOOLEAN; CONST Key, IV : ARRAY OF BYTE );
   BEGIN
      _Encrypt := Encrypt;
      _OnInit := TRUE;
      _InitOffset := 0;
      IF _Encrypt THEN
         _Cipher.Init( rijndael.cphmStreamEncrypt, rijndael.rkl256, Key, IV );
      ELSE
         _Cipher.Init( rijndael.cphmStreamDecrypt, rijndael.rkl256, Key, IV );
      END;
      _MAC.Init();
      _MAC.Update( Key );
      _MAC.Update( IV );
      _MAC.Finish( OUT _Digest );
      _MAC.Init();
   END Init;

(*--------------------------------------------------------------------------------*)

BEGIN
   _Encrypt := TRUE;
   _OnInit := TRUE;
   _InitOffset := 0;
END CRijndaelFilter;

(*================================================================================*)

END cphfilter.
