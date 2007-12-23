IMPLEMENTATION MODULE io;

(*===========================================================================*)

CLASS IMPLEMENTATION CDataInfo;

(*---------------------------------------------------------------------------*)

   PUBLIC VIRTUAL PROCEDURE OnError( Direction : IOO.TDirection; Source : TPIO; CONST Result : ARRAY OF Sync.TAsyncResult; CONST Item : ARRAY OF ns.THash; CONST DeviceSpecificError : ARRAY OF CARDINAL );
   BEGIN
   END OnError;
  
(*---------------------------------------------------------------------------*)

   PUBLIC VIRTUAL PROCEDURE OnIO( Direction : IOO.TDirection; Source : TPIO; CONST Result : ARRAY OF Sync.TAsyncResult; CONST Item : ARRAY OF ns.THash; CONST DeviceSpecificError : ARRAY OF CARDINAL; CONST Value : ARRAY OF iovalue.Value );
   BEGIN
   END OnIO;

(*---------------------------------------------------------------------------*)

   PUBLIC VIRTUAL PROCEDURE OnAdvise( Source : TPIO; CONST Result : ARRAY OF Sync.TAsyncResult; CONST Item : ARRAY OF ns.THash; CONST Value : ARRAY OF iovalue.Value );
   BEGIN
   END OnAdvise;

(*---------------------------------------------------------------------------*)

END CDataInfo;

(*===========================================================================*)

CLASS IMPLEMENTATION AItemizedIO;

(*---------------------------------------------------------------------------*)

	PUBLIC VIRTUAL PROPERTY Capabilities GET : TCapabilities;
	BEGIN
		RETURN TCapabilities{};
	END Capabilities;

(*---------------------------------------------------------------------------*)

	PUBLIC VIRTUAL PROCEDURE IOha( Direction : IOO.TDirection; Item : ARRAY OF ns.THash; REF Value : ARRAY OF iovalue.Value; Callback : TPDataInfo ) : Sync.TAsyncResult;
	BEGIN
		RETURN Sync.arCannotStart;
	END IOha;

(*---------------------------------------------------------------------------*)

END AItemizedIO;

(*===========================================================================*)

END io.