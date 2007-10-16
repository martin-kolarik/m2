MODULE oaconstructor;

  PROCEDURE OAP1( s : ARRAY OF WCHAR );
  BEGIN
  END OAP1;

  (*# save, call( o_a_size => off ) *)
  PROCEDURE OAP2( s : ARRAY OF WCHAR );
  BEGIN
  END OAP2;
  (*# restore *)

  PROCEDURE OAP3( VAR s : ARRAY OF WCHAR );
  BEGIN
  END OAP3;

  (*# save, call( o_a_size => off ) *)
  PROCEDURE OAP4( VAR s : ARRAY OF WCHAR );
  BEGIN
  END OAP4;
  (*# restore *)

  PROCEDURE OAP5( CONST s : ARRAY OF WCHAR );
  BEGIN
  END OAP5;

  (*# save, call( o_a_size => off ) *)
  PROCEDURE OAP6( CONST s : ARRAY OF WCHAR );
  BEGIN
  END OAP6;
  (*# restore *)

VAR
  C : POINTER TO WCHAR;
  S : ARRAY [0..9] OF WCHAR;

PROCEDURE X;
BEGIN
  OAP1( OA( 1, ADR( S )));
  OAP2( OA( 1, ADR( S )));
  OAP3( OA( 1, ADR( S )));
  OAP4( OA( 1, ADR( S )));
  OAP5( OA( 1, ADR( S )));
  OAP6( OA( 1, ADR( S )));

  OAP1( OA( 0, C ));
  OAP2( OA( 0, C ));
  OAP3( OA( 0, C ));
  OAP4( OA( 0, C ));
  OAP5( OA( 0, C ));
  OAP6( OA( 0, C ));
  
  ASSIGN( OA( 0, C ), S );
END X;

END oaconstructor.