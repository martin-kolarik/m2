IMPLEMENTATION MODULE StorageO;

FROM Debug IMPORT
   Assertion;

FROM Storage IMPORT
	ALLOCATE, DEALLOCATE, REALLOCATE;

IMPORT
	Storage,
	windows;
	
//================================================================================

VAR
   GPageSize : CARDINAL := 0;	
	
//================================================================================
// Memory buffers

CLASS IMPLEMENTATION AMemoryBuffer;

	PUBLIC PROPERTY Empty GET : BOOLEAN;
	BEGIN
		RETURN Length = 0;
	END Empty;

	PUBLIC INDEX AMemoryBuffer GET( Index : CARDINAL ) : BYTE;
	BEGIN
		IF ( Data = NIL ) OR ( Index >= Length ) THEN
			THROW Exceptions.Modula2Exception( NIL, EMITW( %lprocedure ), L"", Exceptions.mexOutOfArrayIndex );
		ELSE
			RETURN PBYTE( Data@[Index] )^;
		END;
	END AMemoryBuffer;
	
	PUBLIC INDEX AMemoryBuffer SET( Index : CARDINAL; Value : BYTE );
	BEGIN
		IF ( Data = NIL ) OR ( Index >= Length ) THEN
			THROW Exceptions.Modula2Exception( NIL, EMITW( %lprocedure ), L"", Exceptions.mexOutOfArrayIndex );
		ELSE
			PBYTE( Data@[Index] )^ := Value;
		END;
	END AMemoryBuffer;
	
	PUBLIC OPERATOR =( CONST Buffer : AMemoryBuffer ) : BOOLEAN;
	VAR
		l : CARDINAL := Length;
		pd, pe, ps : PBYTE;
	BEGIN
		IF l <> Buffer.Length THEN
			RETURN FALSE;
		END;
		ps := Data;
		pe := ps@[ l ];
		pd := Buffer.Data;
		WHILE ps <> pe DO
			IF ps^ <> pd^ THEN
				RETURN FALSE;
			END;
			INC( ps );
			INC( pd );
		END; // WHILE
		RETURN TRUE;
	END =;

	PUBLIC PROCEDURE Clear();
	BEGIN
		Length := 0;
	END Clear;
	
	PUBLIC PROCEDURE Zero();
	BEGIN
		Storage.Zero( Data, Length );
	END Zero;
	
	PUBLIC PROCEDURE Fill( Value : BYTE );
	BEGIN
		Storage.Fill( Data, Length, Value );
	END Fill;
	
	PUBLIC PROCEDURE ToOA( OUT Buffer : ARRAY OF BYTE; OUT Filled : CARDINAL );
	BEGIN
		Filled := MIN2( HIGH( Buffer )+1, Length );
		IF ( Data = NIL ) OR ( Filled = 0 ) THEN
			RETURN;
		ELSE
			Storage.Move( Data, ADR( Buffer ), Filled );
		END;
	END ToOA;

	PUBLIC PROCEDURE Append( CONST Buffer : AMemoryBuffer );
	VAR
		l : CARDINAL := Buffer.Length;
	BEGIN
		IF l = 0 THEN
			RETURN;
		ELSE
			AppendOA( OA( l-1, Buffer.Data ));
		END;
	END Append;

	PUBLIC PROCEDURE AppendByte( Byte : BYTE );
	BEGIN
		AppendOA( OA( 0, ADR( Byte )));
	END AppendByte;

	PUBLIC PROCEDURE Prepend( CONST Buffer : AMemoryBuffer );
	VAR
		l : CARDINAL := Buffer.Length;
	BEGIN
		IF l = 0 THEN
			RETURN;
		ELSE
			PrependOA( OA( l-1, Buffer.Data ));
		END;
	END Prepend;

	PUBLIC PROCEDURE PrependByte( Byte : BYTE );
	BEGIN
		PrependOA( OA( 0, ADR( Byte )));
	END PrependByte;

	PUBLIC PROCEDURE RemoveStart( Count : CARDINAL );
	BEGIN
		Remove( 0, Count );
	END RemoveStart;

	PUBLIC PROCEDURE RemoveEnd( Count : CARDINAL );
	BEGIN
		Count := MIN2( Count, Length );
		Remove( Length-Count, Count );
	END RemoveEnd;

	PUBLIC PROCEDURE Subbuffer( From, Count : CARDINAL; OUT Buffer : AMemoryBuffer );
	BEGIN
		Buffer.Clear();
		IF From >= Length THEN
			RETURN;
		END;
		Count := MIN2( Count, Length-From );
		IF Count > 0 THEN
			Buffer.AppendOA( OA( Count-1, Data@[From] ));
		END;
	END Subbuffer;

	PUBLIC PROCEDURE SubbufferOA( From, Count : CARDINAL; OUT Buffer : ARRAY OF BYTE; OUT Filled : CARDINAL );
	BEGIN
		IF From >= Length THEN
			Filled := 0;
			RETURN;
		END;
		Filled := MIN2( HIGH( Buffer ) + 1, MIN2( Count, Length-From ));
		IF Filled > 0 THEN
			Storage.Move( Data@[From], ADR( Buffer ), Filled );
		END;
	END SubbufferOA;


	PUBLIC PROCEDURE IndexOf( CONST Buffer : AMemoryBuffer; FromIndex : CARDINAL ) : CARDINAL;
	VAR
		l : CARDINAL := Buffer.Length;
	BEGIN
		IF l = 0 THEN
			RETURN -1;
		ELSE
			RETURN IndexOfOA( OA( l-1, Buffer.Data ), FromIndex );
		END;
	END IndexOf;
	
	PUBLIC PROCEDURE IndexOfByte( Byte : BYTE; FromIndex : CARDINAL ) : CARDINAL;
	VAR
		a : PBYTE := Data@[FromIndex];
		i : CARDINAL;
		l : CARDINAL := Length;
	BEGIN
		IF l = 0 THEN
			RETURN -1;
		END;
		FOR i := FromIndex TO l-1 DO
			IF a^ = Byte THEN
				RETURN i;
			END;
			INC( a );
		END;
		RETURN -1;
	END IndexOfByte;
	
	PUBLIC PROCEDURE IndexOfOA( CONST Buffer : ARRAY OF BYTE; FromIndex : CARDINAL ) : CARDINAL;
	VAR
		i, j, nexti : CARDINAL;
		l : CARDINAL := Length;
		lb : CARDINAL := HIGH( Buffer ) + 1;
		a : PBYTE := Data;
		b : PBYTE := ADR( Buffer );
	BEGIN
		IF HIGH( Buffer ) = 0 THEN
			RETURN IndexOfByte( Buffer[0], FromIndex );
		END;
		IF l = 0 THEN
			RETURN -1;
		ELSIF FromIndex+lb > l THEN
			RETURN -1;
		END;
		i := FromIndex;
		LOOP
			IF i > l-lb THEN
				EXIT;
			ELSIF a@[i]^ = b^ THEN // have first char, check whole string
				nexti := 0;
				j := 1;
				LOOP
					IF j >= lb THEN
						RETURN i;
					ELSIF a@[i+j]^ <> b@[j]^ THEN // not found
						IF nexti > 0 THEN
							i := nexti; // use hint
						END;
						EXIT;
					END;
					IF ( nexti = 0 ) AND ( a@[i+j]^ = b^ ) THEN // hint
						nexti := i+j-1; // after assignment (see "use hint") i is incremented
					END;
					INC( j );
				END; // LOOP
			END;
			INC( i );
		END; // LOOP
		RETURN -1;
	END IndexOfOA;
	
	PUBLIC PROCEDURE IndexOfAny( CONST Bytes : SET OF BYTE; FromIndex : CARDINAL ) : CARDINAL;
	VAR
		a : PBYTE := Data@[FromIndex];
		i : CARDINAL;
		l : CARDINAL := Length;
	BEGIN
		IF l = 0 THEN
			RETURN -1;
		END;
		FOR i := FromIndex TO l-1 DO
			IF a^ IN Bytes THEN
				RETURN i;
			END;
			INC( a );
		END;
		RETURN -1;
	END IndexOfAny;
	
	PUBLIC PROCEDURE LastIndexOf( CONST Buffer : AMemoryBuffer; IndexFromRight : CARDINAL ) : CARDINAL;
	VAR
		l : CARDINAL := Buffer.Length;
	BEGIN
		IF l = 0 THEN
			RETURN -1;
		ELSE
			RETURN LastIndexOfOA( OA( l-1, Buffer.Data ), IndexFromRight );
		END;
	END LastIndexOf;

	PUBLIC PROCEDURE LastIndexOfByte( Byte : BYTE; IndexFromRight : CARDINAL ) : CARDINAL;
	VAR
		i : CARDINAL;
		l : CARDINAL := Length;
		a : PBYTE := Data@[l-1-IndexFromRight];
	BEGIN
		IF l = 0 THEN
			RETURN -1;
		END;
		FOR i := l-1-IndexFromRight TO 0 BY -1 DO
			IF a^ = Byte THEN
				RETURN i;
			END;
			DEC( a );
		END;
		RETURN -1;
	END LastIndexOfByte;

	PUBLIC PROCEDURE LastIndexOfOA( CONST Buffer : ARRAY OF BYTE; IndexFromRight : CARDINAL ) : CARDINAL;
	VAR
		l : CARDINAL := Length;
	BEGIN
		IF HIGH( Buffer ) = 0 THEN
			RETURN LastIndexOfByte( Buffer[0], IndexFromRight );
		END;
		IF l = 0 THEN
			RETURN -1;
		ELSE
			ADDRESS( 0 )^ := 0;
			RETURN -1;
		END;
	END LastIndexOfOA;

	PUBLIC PROCEDURE LastIndexOfAny( CONST Bytes : SET OF BYTE; IndexFromRight : CARDINAL ) : CARDINAL;
	VAR
		i : CARDINAL;
		l : CARDINAL := Length;
		a : PBYTE := Data@[l-1-IndexFromRight];
	BEGIN
		IF l = 0 THEN
			RETURN -1;
		END;
		FOR i := l-1-IndexFromRight TO 0 BY -1 DO
			IF a^ IN Bytes THEN
				RETURN i;
			END;
			DEC( a );
		END;
		RETURN -1;
	END LastIndexOfAny;

	PUBLIC PROCEDURE StartsWith( CONST Buffer : ARRAY OF BYTE ) : BOOLEAN;
	VAR
		a : PBYTE := Data;
		i : CARDINAL := 0;
		l : CARDINAL := Length;
	BEGIN
		LOOP
			IF i >= l THEN
				RETURN FALSE;
			ELSIF i > HIGH( Buffer ) THEN
				RETURN TRUE;
			ELSIF a^ <> Buffer[i] THEN
				RETURN FALSE;
			END;
			INC( i );
			INC( a );
		END; // LOOP
	END StartsWith;
	
	PUBLIC PROCEDURE EndsWith( CONST Buffer : ARRAY OF BYTE ) : BOOLEAN;
	VAR
		i : INTEGER := Length - 1;
		j : INTEGER := HIGH( Buffer );
		a : PBYTE := Data@[i];
	BEGIN
		LOOP
			IF i < 0 THEN
				RETURN FALSE;
			ELSIF j < 0 THEN
				RETURN TRUE;
			ELSIF a^ <> Buffer[j] THEN
				RETURN FALSE;
			END;
			DEC( i );
			DEC( j );
			DEC( a );
		END; // LOOP
	END EndsWith;

END AMemoryBuffer;

//--------------------------------------------------------------------------------

TYPE
	TPMemoryBuffer = POINTER TO CMemoryBuffer;

CLASS IMPLEMENTATION CMemoryBuffer;

	PUBLIC VIRTUAL PROPERTY Length GET : CARDINAL;
	BEGIN
		RETURN _Length;
	END Length;
	
	PUBLIC VIRTUAL PROPERTY Length SET( Value : CARDINAL );
	BEGIN
		_Length := MIN2( Value, _Size );
	END Length;
	
	PUBLIC VIRTUAL PROPERTY Size GET : CARDINAL;
	BEGIN
		RETURN _Size;
	END Size;
	
	PUBLIC VIRTUAL PROPERTY Size SET( Value : CARDINAL );
	BEGIN
		Reallocate( Value );
	END Size;
	
	PUBLIC VIRTUAL PROPERTY Data GET : ADDRESS;
	BEGIN
		RETURN _Data;
	END Data;
		
	PUBLIC PROCEDURE Dispose();
	BEGIN
		Clear();
		IF OwnMemory THEN
			Deallocate();
			OwnMemory := FALSE;
		END;
	END Dispose;
	
	PUBLIC OPERATOR :=( CONST Buffer : CMemoryBuffer );
	BEGIN
		Assign( Buffer );
	END :=;

	PUBLIC VIRTUAL PROCEDURE Assign( CONST Buffer : AMemoryBuffer );
	BEGIN
		_Length := Buffer.Length;
		IF _Length = 0 THEN
			RETURN;
		ELSIF _Size < _Length THEN
			Reallocate( _Length );
		END;
		Storage.Move( Buffer.Data, _Data, _Length );
	END Assign;

	PUBLIC VIRTUAL PROCEDURE FromOA( CONST Buffer : ARRAY OF BYTE; CopyFlag : BOOLEAN ); // IF NOT CopyFlag then reference to Buffer is used
	BEGIN
		Deallocate();
		IF HIGH( Buffer ) = -1 THEN
		   // do nothing
		ELSIF CopyFlag THEN
			Reallocate( HIGH( Buffer ) + 1 );
			Storage.Move( ADR( Buffer ), _Data, HIGH( Buffer ) + 1 );
		ELSE
			_Data := ADR( Buffer );
			_Size := HIGH( Buffer ) + 1;
		END;
		_Length := _Size;
	END FromOA;

	PUBLIC VIRTUAL PROCEDURE AppendOA( CONST Buffer : ARRAY OF BYTE );
	VAR
		bl : CARDINAL := HIGH( Buffer ) + 1;
	BEGIN
		IF HIGH( Buffer ) = -1 THEN
		   // do nothing
		   RETURN;
		END;
		Reallocate( _Length + bl );
		Storage.Move( ADR( Buffer ), _Data@[_Length], bl );
		INC( _Length, bl );
	END AppendOA;
	
	PUBLIC VIRTUAL PROCEDURE PrependOA( CONST Buffer : ARRAY OF BYTE );
	VAR
		bl : CARDINAL := HIGH( Buffer ) + 1;
	BEGIN
		IF HIGH( Buffer ) = -1 THEN
		   // do nothing
		   RETURN;
		END;
		Reallocate( _Length + bl );
		Storage.Move( _Data, _Data@[bl], _Length );
		Storage.Move( ADR( Buffer ), _Data, bl );
		INC( _Length, bl );
	END PrependOA;
	
	PUBLIC VIRTUAL PROCEDURE Remove( FromIndex, Count : CARDINAL );
	VAR
		rl : CARDINAL;
	BEGIN
	   IF Count = 0 THEN
	      RETURN;
		ELSIF FromIndex >= _Length THEN
			RETURN;
		ELSIF Count > MAX( INTEGER ) THEN
			Count := _Length;
		END;
		rl := FromIndex + Count;
		IF rl >= _Length THEN
			_Length := FromIndex;
		ELSE
			Storage.Move( _Data@[rl], _Data@[FromIndex], _Length-rl );
			DEC( _Length, Count );
		END;
	END Remove;
	
	INTERNAL VIRTUAL PROCEDURE Reallocate( Bytes : CARDINAL );
	VAR
		LData : ADDRESS;
	BEGIN
		IF Bytes < _Size THEN
			RETURN;
		END;
		IF OwnMemory THEN
			REALLOCATE( REF _Data, Bytes );
		ELSE
			OwnMemory := TRUE;
			LData := _Data;
			_Data := NIL;
			REALLOCATE( REF _Data, Bytes );
			Storage.Move( LData, _Data, MIN2( _Size, Bytes ));
		END;
		_Size := Bytes;
	END Reallocate;
	
	INTERNAL VIRTUAL PROCEDURE Deallocate();
	BEGIN
		IF OwnMemory THEN
			OwnMemory := FALSE;
			DISPOSE( _Data );
		ELSE
			_Data := NIL;
		END;
		_Size := 0;
		_Length := 0;
	END Deallocate;

BEGIN
	_Data := NIL;
	_Length := 0;
	_Size := 0;
FINALLY
	Dispose();
END CMemoryBuffer;

//================================================================================

CLASS IMPLEMENTATION AMemorySlot;

	PUBLIC VIRTUAL PROPERTY Length GET : CARDINAL;
	BEGIN
		RETURN _Length;
	END Length;
	
	PUBLIC VIRTUAL PROPERTY Length SET( Value : CARDINAL );
	BEGIN
		_Length := MIN2( Value, Size );
	END Length;
	
	PUBLIC OPERATOR :=( CONST Buffer : CMemoryBuffer );
	BEGIN
		Assign( Buffer );
	END :=;

	PUBLIC VIRTUAL PROCEDURE Assign( CONST Buffer : AMemoryBuffer );
	BEGIN
		Length := Buffer.Length;
		IF _Length = 0 THEN
			RETURN;
		END;
		Storage.Move( Buffer.Data, Data, _Length );
	END Assign;

	PUBLIC VIRTUAL PROCEDURE FromOA( CONST Buffer : ARRAY OF BYTE; CopyFlag : BOOLEAN ); // IF NOT CopyFlag then reference to Buffer is used
	BEGIN
	   Length := HIGH( Buffer ) + 1;
	   IF _Length = 0 THEN
	      RETURN;
	   END;
   	Storage.Move( ADR( Buffer ), Data, _Length );
	END FromOA;

	PUBLIC VIRTUAL PROCEDURE AppendOA( CONST Buffer : ARRAY OF BYTE );
	VAR
		bl : CARDINAL;
	BEGIN
	   bl := MIN2( Size-_Length, HIGH( Buffer ) + 1 );
		Storage.Move( ADR( Buffer ), Data@[_Length], bl );
		INC( _Length, bl );
	END AppendOA;
	
	PUBLIC VIRTUAL PROCEDURE PrependOA( CONST Buffer : ARRAY OF BYTE );
	VAR
		bl, bs : CARDINAL;
		d : ADDRESS := Data;
		s : CARDINAL := Size;
	BEGIN
	   bl := HIGH( Buffer ) + 1;
	   bs := MIN2( bl, s-_Length );
	   IF bl < s THEN
         Storage.Move( d, d@[bl], bl + _Length - s );
      END;
   	Storage.Move( ADR( Buffer ), d, bs );
	  	INC( _Length, bs );
	END PrependOA;
	
	PUBLIC VIRTUAL PROCEDURE Remove( FromIndex, Count : CARDINAL );
	VAR
	   d : ADDRESS := Data;
	BEGIN
		IF FromIndex >= _Length THEN
			RETURN;
		END;
		IF Count >= _Length-FromIndex THEN
			_Length := FromIndex;
		ELSE
			DEC( _Length, Count );
			Storage.Move( d@[FromIndex+Count], d@[FromIndex], _Length-FromIndex );
		END;
	END Remove;
	
BEGIN
   _Length := 0;
END AMemorySlot;

//================================================================================

CLASS IMPLEMENTATION CMemorySlot32;

	PUBLIC VIRTUAL PROPERTY Size GET : CARDINAL;
	BEGIN
		RETURN SIZE( _Data );
	END Size;
	
	PUBLIC VIRTUAL PROPERTY Size SET( Value : CARDINAL );
	BEGIN
	   ASSERT( FALSE );
	END Size;
	
	PUBLIC VIRTUAL PROPERTY Data GET : ADDRESS;
	BEGIN
		RETURN ADR( _Data );
	END Data;

BEGIN
   _Data[0] := 0;
END CMemorySlot32;

//================================================================================

CLASS IMPLEMENTATION CMemorySlot64;

	PUBLIC VIRTUAL PROPERTY Size GET : CARDINAL;
	BEGIN
		RETURN SIZE( _Data );
	END Size;
	
	PUBLIC VIRTUAL PROPERTY Size SET( Value : CARDINAL );
	BEGIN
	   ASSERT( FALSE );
	END Size;
	
	PUBLIC VIRTUAL PROPERTY Data GET : ADDRESS;
	BEGIN
		RETURN ADR( _Data );
	END Data;

BEGIN
   _Data[0] := 0;
END CMemorySlot64;

//================================================================================

CLASS IMPLEMENTATION CMemorySlot256;

	PUBLIC VIRTUAL PROPERTY Size GET : CARDINAL;
	BEGIN
		RETURN SIZE( _Data );
	END Size;
	
	PUBLIC VIRTUAL PROPERTY Size SET( Value : CARDINAL );
	BEGIN
	   ASSERT( FALSE );
	END Size;
	
	PUBLIC VIRTUAL PROPERTY Data GET : ADDRESS;
	BEGIN
		RETURN ADR( _Data );
	END Data;

BEGIN
   _Data[0] := 0;
END CMemorySlot256;

//================================================================================

CLASS IMPLEMENTATION CAllocatorException;

	PUBLIC PROCEDURE Init( NestedException : POINTER TO Exceptions.Exception; CONST Originator, Text : ARRAY OF WCHAR; Kind : TAllocatorException ) : CAllocatorException;
	BEGIN
	   SELF.Kind := Kind;
	   SUPER.Init( NestedException, Originator, Text );
		RETURN SELF;
	END Init;

   INTERNAL VIRTUAL PROCEDURE Name( OUT S : ARRAY OF WCHAR );
   BEGIN
      ASSIGN( S, EMITW( %class ));
   END Name;

BEGIN
   Kind := aexNotEnoughMemory;
END CAllocatorException;

PROCEDURE AllocatorException( NestedException : POINTER TO Exceptions.Exception; CONST Originator, Text : ARRAY OF WCHAR; Kind : TAllocatorException ) : CAllocatorException;
VAR
	AE : CAllocatorException;
BEGIN
	AE.Init( NestedException, Originator, Text, Kind );
	RETURN AE;
END AllocatorException;

//================================================================================

TYPE
	TPage  = RECORD
						 Page : ADDRESS;
						 Data : CARDINAL; // whatever user wants
					 END;
	TPages = POINTER TO ARRAY [0..0] OF TPage;
																					 
CLASS IMPLEMENTATION CAAllocator;

	PUBLIC PROPERTY CAAllocator.Debug GET : BOOLEAN;
	BEGIN
		RETURN _Debug;
	END CAAllocator.Debug;

	PUBLIC PROPERTY CAAllocator.Debug SET( V : BOOLEAN );
	BEGIN
		_Debug := V;
	END CAAllocator.Debug;

	PUBLIC PROPERTY CAAllocator.Strategy GET : TAllocatorStrategy;
	BEGIN
		RETURN _Strategy;
	END CAAllocator.Strategy;

	PUBLIC PROPERTY CAAllocator.Strategy SET( V : TAllocatorStrategy );
	BEGIN
		_Strategy := V;
	END CAAllocator.Strategy;

	PUBLIC PROPERTY CAAllocator.Backlog GET : CARDINAL;
	BEGIN
		RETURN _Backlog;
	END CAAllocator.Backlog;

	PUBLIC PROPERTY CAAllocator.Backlog SET( V : CARDINAL );
	BEGIN
		TRY

			IF _Backlog < V THEN
				CommitPages( ( V - _Backlog  + GPageSize - 1 ) DIV GPageSize );
			END;
			_Backlog := V;
		
		CATCH : CAllocatorException DO
			// ignore
		END;
	END CAAllocator.Backlog;

	PUBLIC PROPERTY CAAllocator.Limit GET : CARDINAL;
	BEGIN
		RETURN _Limit;
	END CAAllocator.Limit;

	PUBLIC PROPERTY CAAllocator.Limit SET( V : CARDINAL );
	BEGIN
		_Limit := V;
	END CAAllocator.Limit;

	INTERNAL PROCEDURE CAAllocator.CommitPages( Count : CARDINAL ) : BOOLEAN;
	VAR
		c, i : CARDINAL;
	BEGIN
		IF ( _PageCount + Count ) * GPageSize > _Limit THEN
			THROW AllocatorException( NIL, EMITW( %lprocedure ), L"", aexLimitExceeded );
		END;

		LOOP
			IF Count = 0 THEN
				EXIT;
			END;
			IF _FirstEmptyPage = -1 THEN
				CASE _Strategy OF
				| asCommitVirtual :
					RETURN FALSE;
				| asAllocatePages :
					c := _PageCount + Count;
					REALLOCATE( REF _Pages, c * SIZE( TPage ));
					FOR i := _PageCount TO c-1 DO
						_Pages^[i].Page := NIL;
						_Pages^[i].Data := _FirstEmptyPage;
						_FirstEmptyPage := i;
					END;
					INC( _PageCount, Count );
				END;
			ELSE
				c := _FirstEmptyPage;
				_FirstEmptyPage := _Pages^[_FirstEmptyPage].Data;

				ALLOCATE( OUT _Pages^[c].Page, GPageSize );
				IF _Debug THEN
					Storage.Fill( _Pages^[c].Page, GPageSize, 0CDH );
				END;
				_Pages^[c].Data := 0;
				PageCommitted( c );

				DEC( Count );
			END;
		END; // LOOP

		RETURN TRUE;
	END CAAllocator.CommitPages;
	
	INTERNAL PROCEDURE CAAllocator.ReleasePage( Index : CARDINAL );
	BEGIN
		IF Index >= _PageCount THEN // bad index
			RETURN;
		ELSIF _Pages^[Index].Page = NIL THEN // already released
			RETURN;
		ELSIF Occupied + Empty - GPageSize < _Backlog THEN
			RETURN;
		END;

		CASE _Strategy OF
		| asCommitVirtual :
		| asAllocatePages :
			DISPOSE( _Pages^[Index].Page );
		END;
		PageReleased( Index );

		IF Index = _PageCount-1 THEN
			DEC( _PageCount );
			REALLOCATE( REF _Pages, _PageCount * SIZE( TPage ));
		ELSE
			_Pages^[Index].Data := _FirstEmptyPage;
			_FirstEmptyPage := Index;
		END;
	END CAAllocator.ReleasePage;

	INTERNAL VIRTUAL PROCEDURE CAAllocator.PageCommitted( Index : CARDINAL );
	BEGIN
	END CAAllocator.PageCommitted;

	INTERNAL VIRTUAL PROCEDURE CAAllocator.PageReleased( Index : CARDINAL );
	BEGIN
	END CAAllocator.PageReleased;

	INTERNAL PROCEDURE Address2Page( a : ADDRESS; OUT Index : CARDINAL ) : BOOLEAN;
	VAR
		i : CARDINAL;
	BEGIN
		IF _PageCount = 0 THEN
			RETURN FALSE;
		END;
		FOR i := 0 TO _PageCount-1 DO
			IF ( PTR( a ) >= PTR( _Pages^[i].Page )) AND ( PTR( a ) <= PTR( _Pages^[i].Page ) + GPageSize - 1 ) THEN
				Index := i;
				RETURN TRUE;
			END;
		END;
		RETURN FALSE;
	END Address2Page;

BEGIN
	_Debug := FALSE;
	_Strategy := asDefault;
	_Backlog := 0;
	_Limit := -1;
	_FirstEmptyPage := -1;
	_PageCount := 0;
	_Pages := NIL;
END CAAllocator;

//================================================================================

TYPE
	TEmptySlots = POINTER TO ARRAY [0..0] OF CARDINAL;
	// SlotIndex = PageIndex * SlotsByPage + Slot

CLASS IMPLEMENTATION CSlotAllocator; // allocates slots of equal size

	PUBLIC PROCEDURE CSlotAllocator.Init( SlotSize, Backlog : CARDINAL );
	BEGIN
		IF SlotSize > GPageSize DIV 2 THEN
			THROW AllocatorException( NIL, EMITW( %lprocedure ), L"", aexUnitTooBig );
		END;
		_SlotSize := SlotSize;
		SELF.Backlog := Backlog;
	END CSlotAllocator.Init;
	
	PUBLIC VIRTUAL PROPERTY CSlotAllocator.Occupied GET : CARDINAL;
	BEGIN
		RETURN _Occupied * _SlotSize;
	END CSlotAllocator.Occupied;
		
	PUBLIC VIRTUAL PROPERTY CSlotAllocator.Empty GET : CARDINAL;
	BEGIN
		RETURN ( _PageCount DIV _SlotSize - _Occupied ) * _SlotSize;
	END CSlotAllocator.Empty;

	PUBLIC VIRTUAL PROCEDURE CSlotAllocator.Allocate( OUT a : ADDRESS; size : CARDINAL ) : BOOLEAN;
	VAR
		g : CARDINAL;
	BEGIN
		TRY
		
			IF size > _SlotSize THEN
				THROW AllocatorException( NIL, EMITW( %lprocedure ), L"", aexAllocateLengthTooBig );
			ELSIF ( _FirstEmptySlot = -1 ) AND NOT CommitPages( 1 ) THEN
				a := NIL;
				RETURN FALSE;
			END;
		
		CATCH e : CAllocatorException DO
			THROW e;
		END;

		g := GPageSize DIV _SlotSize;
		WITH _Pages^[ _FirstEmptySlot DIV g ] DO
			a := INC( Page, ( _FirstEmptySlot MOD g ) * _SlotSize );
			INC( Data );
		END; // WITH

		_FirstEmptySlot := _EmptySlots^[ _FirstEmptySlot ];
		INC( _Occupied );
		RETURN TRUE;
	END CSlotAllocator.Allocate;
	
	PUBLIC VIRTUAL PROCEDURE CSlotAllocator.Deallocate( REF a : ADDRESS );
	VAR
		PageIndex : CARDINAL;
		Slot : CARDINAL;
	BEGIN
		IF NOT Address2Page( a, OUT PageIndex ) THEN
			THROW AllocatorException( NIL, EMITW( %lprocedure ), L"", aexUnknownAddress );
		END;

		Slot := ( GPageSize DIV _SlotSize ) * PageIndex;
		WITH _Pages^[PageIndex] DO
			a := DEC( a, PTR( Page ));
			IF PTR( a ) MOD _SlotSize <> 0 THEN
				THROW AllocatorException( NIL, EMITW( %lprocedure ), L"", aexUnknownAddress );
			END;

			// solve slots
			INC( Slot, PTR( a ) DIV _SlotSize );
			_EmptySlots^[ Slot ] := _FirstEmptySlot;
			_FirstEmptySlot := Slot;
			DEC( _Occupied );

			// if needed release page
			IF Data = 1 THEN
				ReleasePage( PageIndex );
			ELSE
				DEC( Data );
			END;
		END; // WITH
	END CSlotAllocator.Deallocate;

	PUBLIC VIRTUAL PROCEDURE Reallocate( REF a : ADDRESS; size : CARDINAL ) : BOOLEAN;
	BEGIN
		THROW AllocatorException( NIL, EMITW( %lprocedure ), L"", aexUnableToReallocate );
	END Reallocate;

	INTERNAL VIRTUAL PROCEDURE CSlotAllocator.PageCommitted( Index : CARDINAL );
	VAR
		i, g : CARDINAL;
	BEGIN
		g := GPageSize DIV _SlotSize;
		IF Index + 1 > _KnownPages THEN
			_KnownPages := Index + 1;
			REALLOCATE( REF _EmptySlots, _KnownPages * g * SIZE( CARDINAL ));
		END;
		FOR i := Index * g TO ( Index + 1 ) * g - 1 DO
			_EmptySlots^[i] := _FirstEmptySlot;
			_FirstEmptySlot := i;
		END;
	END CSlotAllocator.PageCommitted;
	
	INTERNAL VIRTUAL PROCEDURE CSlotAllocator.PageReleased( Index : CARDINAL );
	VAR
		current, previous : CARDINAL;
		firstinpage : CARDINAL;
		g, max : CARDINAL;
	BEGIN
		g := GPageSize DIV _SlotSize;
		max := g;
		firstinpage := Index * g;
		previous := -1;
		current := _FirstEmptySlot;
		WHILE current <> -1 DO
			IF ( current < firstinpage ) OR ( current >= firstinpage + g ) THEN // out of released page
				previous := current;
				current := _EmptySlots^[current];
			ELSIF previous = -1 THEN
				current := _EmptySlots^[current];
				_FirstEmptySlot := current;
				DEC( max );
			ELSE
				current := _EmptySlots^[current];
				_EmptySlots^[previous] := current;
				DEC( max );
			END;
			IF max = 0 THEN
				EXIT;
			END;
		END; // WHILE
		IF Index + 1 = _KnownPages THEN
			_KnownPages := Index;
			REALLOCATE( REF _EmptySlots, _KnownPages * ( GPageSize DIV _SlotSize ) * SIZE( CARDINAL ));
		END;
	END CSlotAllocator.PageReleased;

BEGIN
	_SlotSize := 0;
	_Occupied := 0; // in slots
	_KnownPages := 0;
	_FirstEmptySlot := -1; // index to slot array
	_EmptySlots := NIL;
END CSlotAllocator;

//================================================================================

BEGIN
   GPageSize := Storage.PageSize();
END StorageO.
