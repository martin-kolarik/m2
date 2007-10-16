IMPLEMENTATION MODULE sdio;

(*===========================================================================*)

CLASS IMPLEMENTATION CSDCallback;

(*---------------------------------------------------------------------------*)

  PUBLIC VIRTUAL PROCEDURE OnError( Direction : IOO.TDirection; Source : TPSDIO; Error : ARRAY OF CARDINAL; Item : ARRAY OF sdns.THash );
  BEGIN
  END OnError;
  
(*---------------------------------------------------------------------------*)

  PUBLIC VIRTUAL PROCEDURE OnIO( Direction : IOO.TDirection; Source : TPSDIO; Result : ARRAY OF Sync.TAsyncResult; Item : ARRAY OF sdns.THash; CONST Value : ARRAY OF sdvalue.Value );
  BEGIN
  END OnIO;

(*---------------------------------------------------------------------------*)

END CSDCallback;

(*===========================================================================*)

CLASS IMPLEMENTATION ASDItemizedIO;

(*---------------------------------------------------------------------------*)

	PUBLIC VIRTUAL PROPERTY Capabilities GET : TCapabilities;
	BEGIN
		RETURN TCapabilities{};
	END Capabilities;

(*---------------------------------------------------------------------------*)

	PUBLIC VIRTUAL PROCEDURE IOha( Direction : IOO.TDirection; Item : ARRAY OF sdns.THash; REF Value : ARRAY OF sdvalue.Value; Callback : TPSDCallback ) : Sync.TAsyncResult;
	BEGIN
		RETURN Sync.arCannotStart;
	END IOha;

(*---------------------------------------------------------------------------*)

END ASDItemizedIO;

(*===========================================================================*)

END sdio.