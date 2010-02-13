IMPLEMENTATION MODULE TextReader;

FROM Debug IMPORT
   Assertion, LogAssertionW;

IMPORT
   FIOO,
   Languages,
   Sync,
   Strings;

(*================================================================================*)

CLASS IMPLEMENTATION CTextReader;

(*--------------------------------------------------------------------------------*)

   PUBLIC PROPERTY Stream GET : IOO.TPStream;
   BEGIN
      RETURN _Stream;
   END Stream;

(*--------------------------------------------------------------------------------*)

   PUBLIC PROPERTY Stream SET( Value : IOO.TPStream );
   BEGIN
      _SBuffer.Clear();
      _WBuffer.Clear();
      _Stream := Value;
      Line := 0;
   END Stream;

(*--------------------------------------------------------------------------------*)

   PUBLIC PROPERTY Encoding GET : CARDINAL;
   BEGIN
      RETURN _Encoding;
   END Encoding;

(*--------------------------------------------------------------------------------*)

   PUBLIC PROPERTY Encoding SET( Value : CARDINAL );
   BEGIN
      _Encoding := Value;
      BufferSize := BufferSize; // adjust input buffer
   END Encoding;

(*--------------------------------------------------------------------------------*)

   PUBLIC PROPERTY BufferSize GET : CARDINAL;
   BEGIN
      RETURN _WBuffer.Size DIV SIZE( WCHAR );
   END BufferSize;

(*--------------------------------------------------------------------------------*)

   PUBLIC PROPERTY BufferSize SET( Value : CARDINAL );
   VAR
      f : BOOLEAN;
      min, max : CARDINAL;
   BEGIN
      Languages.BytesPerCharacter( _Encoding, OUT f, OUT min, OUT max );
      _SBuffer.Size := Value * max;
      _WBuffer.Size := Value * SIZE( WCHAR );
   END BufferSize;

(*--------------------------------------------------------------------------------*)

   PUBLIC PROPERTY OmitCommentaries GET : BOOLEAN;
   BEGIN
      RETURN _OmitCommentaries;
   END OmitCommentaries;

(*--------------------------------------------------------------------------------*)

   PUBLIC PROPERTY OmitCommentaries SET( Value : BOOLEAN );
   BEGIN
      _OmitCommentaries := Value AND NOT _CommentaryStart.Empty;
   END OmitCommentaries;

(*--------------------------------------------------------------------------------*)

   PUBLIC PROPERTY CommentaryStart GET : StringsO.CString;
   BEGIN
      RETURN _CommentaryStart;
   END CommentaryStart;

(*--------------------------------------------------------------------------------*)

   PUBLIC PROPERTY CommentaryStart SET( CONST Value : StringsO.CString );
   BEGIN
      _CommentaryStart.Assign( Value );
      OmitCommentaries := NOT _CommentaryStart.Empty;
   END CommentaryStart;

(*--------------------------------------------------------------------------------*)

   PUBLIC PROCEDURE ReadChar( OUT Ch : WCHAR; TimeoutMS : CARDINAL; WaitForResult : BOOLEAN ) : Sync.TAsyncResult;
   VAR
      Result : Sync.TAsyncResult;
   BEGIN
      IF _Stream = NIL THEN
         RETURN Sync.arCannotStart;
      END;
      LOOP
         Feed();
         IF _WBuffer.Empty THEN
            Result := ReadFromStream( TimeoutMS, WaitForResult );
            IF Result NOT IN Sync.arsCompletions THEN
               RETURN Result;
            END;
         ELSE
            _WBuffer.ReadOA( OUT Ch );
            RETURN Sync.arCompleted;
         END;
      END; // LOOP
   END ReadChar;

(*--------------------------------------------------------------------------------*)

   PUBLIC PROCEDURE ReadLine( OUT Line : StringsO.IString; TimeoutMS : CARDINAL; WaitForResult : BOOLEAN ) : Sync.TAsyncResult;
   VAR
      a : PWCHAR;
      comment : CARDINAL;
      cl, dl : CARDINAL; // commit length, data length
      lineSkipped : BOOLEAN;
      Result : Sync.TAsyncResult;
   BEGIN
      Line.Clear();
      IF _Stream = NIL THEN
         RETURN Sync.arCannotStart;
      END;
      LOOP
         Feed();

         CASE ScanLine( MaskBOM, OUT a, OUT dl, OUT cl ) OF
         //-----
         | srNothing :
            Result := ReadFromStream( TimeoutMS, WaitForResult );
            IF Result IN Sync.arsCompletions THEN // fall down and continue
               cl := 0;
            ELSIF ( Result = Sync.arNoData ) AND NOT Line.Empty THEN // last line not ended with CR must be returned as valid, NoData must come hereafter
               RETURN Sync.arCompleted;
            ELSE
               RETURN Result;
            END;
         //-----
         | srBOM :
            // do nothing, if MaskBOM then BOM must not appear in output, if NOT MaskBOM, then srBOM does not occur
         //-----
         | srIncompleteLine, srIncompleteLineBufferFull :
            IF dl > 0 THEN
               Line.AppendOA( OA( dl-1, a ));
            END;
            // continue, try to feed again
         //-----
         | srCompleteLine : 
            INC( SELF.Line );
            
            IF dl > 0 THEN
               Line.AppendOA( OA( dl-1, a ));
            END;
            
            // realize, if there is not some commentary
            lineSkipped := FALSE;
            IF _OmitCommentaries THEN
               comment := Line.IndexOf( _CommentaryStart, 0 );
               IF comment = -1 THEN
                  // fall down, no comment found
               ELSIF comment = 0 THEN // drop whole line
                  Line.Clear(); 
                  lineSkipped := TRUE;
               ELSE // trim the line
                  Line.Length := comment;
               END;
            END;
            
            // return line found
            IF NOT lineSkipped THEN
               _WBuffer.CommitReading( cl<<1 );
               RETURN Sync.arCompleted;
            END;

         //-----
         END; // CASE

         _WBuffer.CommitReading( cl<<1 );
      END; // LOOP
   END ReadLine;

(*--------------------------------------------------------------------------------*)

   PUBLIC PROCEDURE ReadLineOA( OUT Line : ARRAY OF WCHAR; TimeoutMS : CARDINAL; WaitForResult : BOOLEAN; OUT Read : CARDINAL ) : Sync.TAsyncResult;
   VAR
      S : StringsO.CString;
      Result : Sync.TAsyncResult;
   BEGIN
      Result := ReadLine( OUT S, TimeoutMS, WaitForResult );
      Read := S.Length;
      RETURN Result;
   END ReadLineOA;

(*--------------------------------------------------------------------------------*)

   PUBLIC PROCEDURE ReadBlock( OUT Block : StringsO.IString; Length : CARDINAL; TimeoutMS : CARDINAL; WaitForResult : BOOLEAN ) : Sync.TAsyncResult;
   VAR
      a : PWCHAR;
      l : CARDINAL;
      Result : Sync.TAsyncResult;
   BEGIN
      Block.Clear();
      IF _Stream = NIL THEN
         RETURN Sync.arCannotStart;
      END;
      LOOP
         Feed();
         IF _WBuffer.Empty THEN
            Result := ReadFromStream( TimeoutMS, WaitForResult );
            IF Result NOT IN Sync.arsCompletions THEN
               RETURN Result;
            END;
         ELSE
            _WBuffer.Peek( OUT a, OUT l );
            l := MIN2( Length, l );
            Block.AppendOA( OA( l-1, a ));
            _WBuffer.CommitReading( l );
            DEC( Length, l );
            IF Length = 0 THEN
               RETURN Sync.arCompleted;
            END;
         END;
      END; // LOOP
   END ReadBlock;

(*--------------------------------------------------------------------------------*)

   PUBLIC PROCEDURE ReadBlockOA( OUT Block : ARRAY OF WCHAR; TimeoutMS : CARDINAL; WaitForResult : BOOLEAN; OUT Read : CARDINAL ) : Sync.TAsyncResult;
   VAR
      S : StringsO.CString;
      Result : Sync.TAsyncResult;
   BEGIN
      Result := ReadBlock( OUT S, HIGH( Block )+1, TimeoutMS, WaitForResult );
      Read := S.Length;
      RETURN Result;
   END ReadBlockOA;

(*--------------------------------------------------------------------------------*)

   PUBLIC PROCEDURE ReadCharS( OUT Ch : WCHAR ) : BOOLEAN;
   BEGIN
      RETURN ReadChar( OUT Ch, Sync.FOREVER, TRUE ) = Sync.arCompleted;
   END ReadCharS;

(*--------------------------------------------------------------------------------*)

   PUBLIC PROCEDURE ReadLineS( OUT Line : StringsO.IString ) : BOOLEAN;
   BEGIN
      RETURN ReadLine( OUT Line, Sync.FOREVER, TRUE ) = Sync.arCompleted;
   END ReadLineS;

(*--------------------------------------------------------------------------------*)

   PUBLIC VIRTUAL PROPERTY Notifier GET : IOO.TPDataInfo;
   BEGIN
      ASSERT( FALSE );
      RETURN NIL;
   END Notifier;

(*--------------------------------------------------------------------------------*)

   PUBLIC VIRTUAL PROPERTY Notifier SET( Value : IOO.TPDataInfo );
   BEGIN
      ASSERT( FALSE );
   END Notifier;

(*--------------------------------------------------------------------------------*)

   PUBLIC VIRTUAL PROCEDURE StartReading();
   BEGIN
      ReadFromStream( Sync.FOREVER, FALSE );
   END StartReading;

(*--------------------------------------------------------------------------------*)

   PUBLIC VIRTUAL PROCEDURE Peek( OUT Data : ADDRESS; OUT Length : CARDINAL ) : BOOLEAN; // peeks data from read buffer
   VAR
      dl : CARDINAL;
   BEGIN
      Feed();
      CASE ScanLine( FALSE, OUT Data, OUT dl, OUT Length ) OF
      | srCompleteLine, srIncompleteLineBufferFull :
         Length := Length << 1;
         RETURN TRUE;
      ELSE
         RETURN FALSE;
      END;
   END Peek;

(*--------------------------------------------------------------------------------*)

   PUBLIC VIRTUAL PROCEDURE ReadOut( Length : CARDINAL ); // consumes data from read buffer
   BEGIN
      _WBuffer.CommitReading( Length );
      // continue with reading
      ReadFromStream( Sync.FOREVER, FALSE );
   END ReadOut;

(*--------------------------------------------------------------------------------*)

   PRIVATE PROCEDURE ReadFromStream( TimeoutMS : CARDINAL; WaitForResult : BOOLEAN ) : Sync.TAsyncResult;
   BEGIN
      RETURN _Stream^.Read( ADR( _SProxy ), TimeoutMS, WaitForResult );
   END ReadFromStream;

(*--------------------------------------------------------------------------------*)

   PRIVATE PROCEDURE Feed();
   VAR
      da : PWCHAR;
      dl : CARDINAL;
      sa : PBYTE;
      sl : CARDINAL;
   BEGIN
      WHILE _SBuffer.StartReading( MAX( CARDINAL ), OUT sa, OUT sl ) DO // exhaust buffer
         IF NOT _WBuffer.StartWriting( MAX( CARDINAL ), OUT da, OUT dl ) THEN
            RETURN;
         END;
         dl := dl >> 1; // char count, the buffer is twice larger
         IF Strings.ToWStream( OA( sl-1, sa ), _Encoding, OUT OA( dl-1, da ), OUT sl, OUT dl ) THEN
            _SBuffer.CommitReading( sl );
            _WBuffer.CommitWriting( dl << 1 );
         ELSE
           RETURN; // unable to feed more
         END;
      END; // while
   END Feed;

(*--------------------------------------------------------------------------------*)

   PRIVATE PROCEDURE ScanLine( DetectBOM : BOOLEAN; OUT start : PWCHAR; OUT dataLength, commitLength : CARDINAL ) : TScanResult;
   VAR
      current : PWCHAR;
      CR : BOOLEAN;
      i : CARDINAL;
      l : CARDINAL := 0;
   BEGIN
      IF _WBuffer.Empty THEN
         RETURN srNothing;
      END;

      _WBuffer.Peek( OUT start, OUT l );
      l := l>>1; current := start; i := 0; CR := FALSE;
      LOOP
         IF DetectBOM AND ( current^ = WCHAR( 0FEFFH )) THEN
            dataLength := i;
            commitLength := i+1;
            RETURN srBOM;
         ELSIF current^ = 10W THEN
            IF CR THEN
               dataLength := i-1;
            ELSE
               dataLength := i;
            END;
            commitLength := i+1;
            RETURN srCompleteLine;
         END;
         CR := current^ = 13W;
         INC( i );
         IF i = l THEN
            dataLength := i;
            commitLength := i;
            IF l = BufferSize THEN
               RETURN srIncompleteLineBufferFull;
            ELSE
               RETURN srIncompleteLine;
            END;
         END;
         INC( current, SIZE( WCHAR ));
         DetectBOM := FALSE; // BOM can appear on start only
      END; // LOOP
   END ScanLine;

(*--------------------------------------------------------------------------------*)

BEGIN
   _Stream := NIL;
   _SProxy.RingBuffer := ADR( _SBuffer );
   _Encoding := Languages.cp_UTF8;
   Line := 0;
   BufferSize := 1024;
FINALLY
   Stream := NIL;
END CTextReader;

(*================================================================================*)

CLASS CStdTextReader( CTextReader ); END CStdTextReader;

CLASS IMPLEMENTATION CStdTextReader;
BEGIN FINALLY
   _Stream := NIL; // avoid closing of stdin
END CStdTextReader;

(*---------------------------------------------------------------------------*)

VAR
   trstdin : CStdTextReader;

(*---------------------------------------------------------------------------*)

PROCEDURE stdin() : TPTextReader;
BEGIN
   IF trstdin.Stream = NIL THEN
      trstdin.Stream := FIOO.stdin();
      trstdin.Encoding := Languages.cp_Console();
   END;
   RETURN ADR( trstdin );
END stdin;

(*================================================================================*)

END TextReader.
