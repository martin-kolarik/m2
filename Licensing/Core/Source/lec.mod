IMPLEMENTATION MODULE lec;

FROM Storage IMPORT
   ALLOCATE, DEALLOCATE;

IMPORT
   arrays,
   Engine,
   Items,
   lists,
   StringsO,
   Validator;

(*================================================================================*)

VAR
   debugged : PBOOLEAN := NIL;

CONST
   expNotSet = MIN( INT64 );
   expNever = MAX( INT64 );
   
   #if #false #and DEBUG #then
      demoExp = time.unitsInDay * 3 DIV 1440; // 3 minutes
      unactExp = time.unitsInDay * 1;
   #else
      demoExp = time.unitsInDay * 6 DIV 240; // 0.6 hours
      unactExp = time.unitsInDay * 33;
   #endif
   countLimit = 10000;

(*================================================================================*)

CLASS IMPLEMENTATION CResult;

(*--------------------------------------------------------------------------------*)

   LOCAL PROCEDURE QueryStarted();
   BEGIN
   END QueryStarted;

(*--------------------------------------------------------------------------------*)

   LOCAL PROCEDURE QueryData( data : PTR );

   (*----------*)
   
      PROCEDURE ComputeInfo( behaviour : TBehaviour; current : TInfo; _new : TInfo ) : TInfo;
      BEGIN
         IF current = riUnknown THEN
            RETURN _new;
         ELSIF behaviour = bhWorstCase THEN
            RETURN MIN2( current, _new );
         ELSIF behaviour = bhBestCase THEN
            RETURN MAX2( current, _new );
         ELSE
            RETURN current;
         END;
      END ComputeInfo;

   (*----------*)
   
      PROCEDURE ComputeExpiration( behaviour : TBehaviour; current : time.TJD; _new : time.TJD ) : time.TJD;
      BEGIN
         IF current = expNotSet THEN
            RETURN _new;
         ELSIF behaviour = bhWorstCase THEN
            RETURN MIN2( current, _new );
         ELSIF behaviour = bhBestCase THEN
            RETURN MAX2( current, _new );
         ELSE
            RETURN current;
         END;
      END ComputeExpiration;

   (*----------*)

   LABEL
      Done;
   VAR
      dt, now : time.TDateTime;
      expires : time.TJD;
      item : Items.TPItem := data;
      items, jitems : lists.TPPtrList;
      info : TInfo := riUnknown;
      trialFlag : BOOLEAN;
   BEGIN
      IF item = NIL THEN
         RETURN;
      END;
      ASSERT( item^ IS Items.CProduct );

      IF item^.HasChilds THEN
         time.GetCurrentUTCDateTime( now );
         expires := expNotSet;
      ELSE
         info := riDemo;
         expires := _Start + demoExp;
         GOTO Done;
      END;

      // parse licences
      items := Items.TPProduct( item )^.Licences;
      items^.Reset();
      WHILE items^.MoveNext() DO
         item := items^.Current;
         trialFlag := Items.ltTrial IN Items.TPLicence( item )^.Type;
         
         IF item^.HasChilds THEN

            // parse activations
            jitems := Items.TPLicence( item )^.Activations;
            jitems^.Reset();
            WHILE jitems^.MoveNext() DO
               item := jitems^.Current;
               
               IF Items.TPActivation( item )^.ValidFor( now ) THEN
                  info := ComputeInfo( bhBestCase, info, riActivated );
                  dt := Items.TPActivation( item )^.Expires;
                  IF dt.Year > 0 THEN
                     expires := ComputeExpiration( bhBestCase, expires, time.DateTimeToJD( dt ));
                  ELSE
                     expires := expNever;
                  END;
               ELSIF trialFlag THEN
                  info := ComputeInfo( bhBestCase, info, riDemo );
                  expires := ComputeExpiration( bhBestCase, expires, _Start + demoExp );
               ELSE
                  info := ComputeInfo( bhBestCase, info, riNotActivated );
                  expires := ComputeExpiration( bhBestCase, expires, time.DateTimeToJD( Items.TPLicence( item )^.Created ) + unactExp );
               END;

            END; // WHILE activations
            
         ELSIF trialFlag THEN
            info := ComputeInfo( bhBestCase, info, riDemo );
            expires := ComputeExpiration( bhBestCase, expires, _Start + demoExp );

         ELSE
            info := ComputeInfo( bhBestCase, info, riNotActivated );
            expires := ComputeExpiration( bhBestCase, expires, time.DateTimeToJD( Items.TPLicence( item )^.Created ) + unactExp );
         END;

      END; // WHILE licences

   Done:
      _Lock.Lock();
      _Info := ComputeInfo( Behaviour, _Info, info );
      _Expires := ComputeExpiration( Behaviour, _Expires, expires );
      _Lock.Unlock();
   END QueryData;
   
(*--------------------------------------------------------------------------------*)

   LOCAL PROCEDURE QueryFinished();
   BEGIN
      _Lock.Lock();
      IF _Expires = expNotSet THEN
         _Expires := _Start + demoExp;
      END;
      _Lock.Unlock();
   END QueryFinished;
   
(*--------------------------------------------------------------------------------*)

   LOCAL PROPERTY Info GET : TInfo;
   VAR
      LInfo : TInfo;
   BEGIN
      LInfo := TInfo( _Lock.Get( REF _Info ));
      IF LInfo = riUnknown THEN
         RETURN riDemo;
      ELSIF ( debugged^ OR DEBUGGED()) AND ODD(( PTR( ADR( LInfo )) >> 3 ) MOD 117 ) THEN
         RETURN TInfo( CARDINAL( LOPTRLONGWORD( PTR( ADR( LInfo )) >> 3 )) MOD 2 + 1 );
      ELSE
         RETURN LInfo;
      END;
   END Info;

(*--------------------------------------------------------------------------------*)

   PUBLIC PROPERTY Expires GET : time.TDateTime;
   VAR
      LExpires : time.TJD;
      TExpires : time.TDateTime;
   BEGIN
      _Lock.Lock();
      LExpires := _Expires;
      _Lock.Unlock();
      IF ( LExpires = expNotSet ) OR ( LExpires = expNever ) THEN
         time.InitDateTime( OUT TExpires );
         IF ( debugged^ OR DEBUGGED()) AND ODD(( PTR( ADR( TExpires )) >> 3 ) MOD 117 ) THEN
            TExpires.Year := 117;
         END;
      ELSE
         time.JDToZonalDateTime( LExpires, TExpires, 0, 0 );
         // time.TrimTime( REF TExpires ); -- better is to not trim it, it allows use Expires as whole information
         IF ( debugged^ OR DEBUGGED()) AND ODD(( PTR( ADR( TExpires )) >> 3 ) MOD 117 ) THEN
            TExpires.Month := TExpires.Year;
            TExpires.Year := TExpires.Day;
         END;
      END;
      RETURN TExpires;
   END Expires;
   
(*--------------------------------------------------------------------------------*)

   PUBLIC PROPERTY Expired GET : BOOLEAN;
   BEGIN
      RETURN NextCheck = 0;
   END Expired;

(*--------------------------------------------------------------------------------*)

   PUBLIC PROPERTY NextCheck GET : CARDINAL;
   VAR
      expires : time.TJD;
      LExpires : time.TDateTime;
   BEGIN
      _Lock.Lock();
      expires := _Expires;
      _Lock.Unlock();
      // shortcut
      IF ( expires = expNotSet ) OR ( expires = expNever ) THEN
         IF ( debugged^ OR DEBUGGED()) AND ODD(( PTR( ADR( LExpires )) >> 3 ) MOD 117 ) THEN
            RETURN 0;
         END;
         RETURN -1;
      ELSE
         DEC( expires, time.GetCurrentJD());
         IF expires <= 0 THEN
            RETURN 0;
         ELSIF expires > 20 * time.unitsInDay THEN // days
            RETURN 20 * 86400 * 1000;
         ELSE
            RETURN time.JDCToMS( expires ); // now range expires is less than returned CARDINAL
         END;
      END;
   END NextCheck;

(*--------------------------------------------------------------------------------*)

   PUBLIC PROPERTY Counted GET : BOOLEAN;
   BEGIN
      RETURN _Counter >= countLimit;
   END Counted;

(*--------------------------------------------------------------------------------*)

   PUBLIC PROCEDURE Reset( _Behaviour : TBehaviour );
   BEGIN
      _Lock.Lock();
      Behaviour := _Behaviour;
      _Info := riUnknown;
      _Expires := expNotSet;
      _Lock.Unlock();
   END Reset;

(*--------------------------------------------------------------------------------*)

   PUBLIC PROCEDURE Inc();
   BEGIN
      IF _Info <= riDemo THEN
         _Counter := MIN2( _Counter + 1, countLimit );
      END;
   END Inc;

(*--------------------------------------------------------------------------------*)

BEGIN
   _Lock.Init( sync.ltSpin, L"", FALSE );
   _Info := riUnknown;
   _Expires := expNotSet;
   _Start := time.GetCurrentJD();
   _Counter := 0;
END CResult;

(*================================================================================*)

PROCEDURE Query( CONST Path1, Path2, ProductId : ARRAY OF WCHAR; REF Result : CResult );
VAR
   data : arrays.CPtrArray;
   i : CARDINAL;
BEGIN
   Engine.LoadProducts( Path1, Path2, ProductId, OUT data );

   Result.QueryStarted();
   FOR i := 0 TO data.Count-1 DO
      Result.QueryData( data[i] );
   END;
   Result.QueryFinished();

   Engine.DisposeProducts( REF data );
END Query;

(*--------------------------------------------------------------------------------*)

PROCEDURE QueryData( CONST Path1, Path2 : ARRAY OF WCHAR; Data : ADDRESS; Length : CARDINAL; REF Result : CResult );
VAR
   ProductId : StringsO.CString;
BEGIN
   Validator.UnwrapData( Data, Length, OUT ProductId );
   Query( Path1, Path2, OA( ProductId.Length-1, ProductId.rawData ), REF Result );
END QueryData;

(*================================================================================*)

PROCEDURE RegisterValidator( Data : ADDRESS; Length : CARDINAL; _Validator : ADDRESS );
BEGIN
   Validator.Register( Data, Length, _Validator );
END RegisterValidator;

(*--------------------------------------------------------------------------------*)

PROCEDURE UnregisterValidator( Data : ADDRESS );
BEGIN
   Validator.Unregister( Data );
END UnregisterValidator;

(*================================================================================*)

BEGIN
   NEW( debugged );
   debugged^ := DEBUGGED();
FINALLY
   DISPOSE( debugged );
END lec.