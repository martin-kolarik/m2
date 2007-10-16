MODULE assignstructuredconst;

	PROCEDURE X();
	TYPE
		T1 = ARRAY [0..1] OF WCHAR;
		T2 = ARRAY [0..1] OF CARDINAL;
	CONST
		C1 = T1( L'A', L'B' );
		C2 = T2( 2, 1234567 );
	VAR
		V1 : T1 := C1;
		V2 : T2 := C2;
		V3 : T1 := L"Ah";
	BEGIN
	END X;

END assignstructuredconst.