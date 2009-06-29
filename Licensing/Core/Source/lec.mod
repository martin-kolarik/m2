IMPLEMENTATION MODULE lec;

FROM Debug IMPORT
   Assertion, LogAssertionW;

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

#if DEBUG #then
FROM log IMPORT
   CLogger, dldDebug;
   
VAR
   Log : CLogger;

PROCEDURE JDCToDate( date : time.TJDC; OUT dateString : ARRAY OF WCHAR );
VAR
   dt : time.DateTime;
BEGIN
   dt.JulianDate := date;
   dt.ToStringOA( L"yy-MM-dd HH:mm", TRUE, TRUE, OUT dateString );
END JDCToDate;

#endif   

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
      aitem : Items.TPActivation;
      dt, now : time.DateTime;
      expires, nowJulianDate : time.TJD;
      litems, aitems : lists.TPPtrList;
      info : TInfo := riUnknown;
      litem : Items.TPLicence;
      localActivated : BOOLEAN;
      localExpired : BOOLEAN;
      #if DEBUG #then
         logs : ARRAY[0..255] OF WCHAR;
      #endif
      pitem : Items.TPItem := data;
      s : StringsO.CString;
      trialFlag : BOOLEAN;
   BEGIN
      IF pitem = NIL THEN
         RETURN;
      END;
      ASSERT( pitem^ IS Items.CProduct );

      #if DEBUG #then
         Log.Level := dldDebug;
      #endif

      IF pitem^.HasChilds THEN

         #if DEBUG #then      
            pitem^.ProductId.ToOA( OUT logs );
            Log.LogSS( dldDebug, L"LEC", L"Product with licences: ", logs );
         #endif

         now.SetNowUTC();
         nowJulianDate := now.JulianDate;
         expires := expNotSet;

      ELSE

         #if DEBUG #then      
            pitem^.ProductId.ToOA( OUT logs );
            Log.LogSS( dldDebug, L"LEC", L"Product W/O licence: ", logs );
         #endif

         info := riDemo;
         expires := _Start + demoExp;
         GOTO Done;
      END;

      // parse licences
      litems := Items.TPProduct( pitem )^.LicencesAndInfos;
      litems^.Reset();
      WHILE litems^.MoveNext() DO
         litem := litems^.Current;
         IF NOT( litem^ IS Items.CLicence ) THEN // TODO: handle infos
            CONTINUE;
         END; 
         trialFlag := Items.ltTrial IN litem^.Type;
         
         #if DEBUG #then      
            litem^.Serial.ToOA( OUT logs );
            Log.LogSS( dldDebug, L"LEC", L"  Licence, computing best hit: ", logs );
         #endif

         localActivated := FALSE;
         localExpired := FALSE;

         IF litem^.HasChilds THEN

            // parse activations
            aitems := litem^.Activations;
            aitems^.Reset();
            WHILE aitems^.MoveNext() DO
               aitem := aitems^.Current;

               #if DEBUG #then      
                  aitem^.ExpiresString.ToOA( OUT logs );
                  Log.LogSS( dldDebug, L"LEC", L"  Activation, computing best hit, expires: ", logs );
               #endif

               IF aitem^.ValidFor( now ) THEN
               
                  info := ComputeInfo( bhBestCase, info, riActivated );
                  dt := aitem^.Expires;
                  IF dt.Year > 0 THEN
                     expires := ComputeExpiration( bhBestCase, expires, dt.JulianDate );

                     #if DEBUG #then      
                        Log.LogS( dldDebug, L"LEC", L"    valid limitedly" );
                     #endif
                  ELSE
                     expires := expNever;

                     #if DEBUG #then      
                        Log.LogS( dldDebug, L"LEC", L"    valid forever" );
                     #endif
                  END;
                  
                  localActivated := TRUE; // according to bhBestCase approach
                  
               ELSIF trialFlag THEN
                  info := ComputeInfo( bhBestCase, info, riDemo );
                  expires := ComputeExpiration( bhBestCase, expires, _Start + demoExp );
                  localExpired := localExpired OR ( expires < nowJulianDate );

                  #if DEBUG #then      
                     JDCToDate( expires, OUT logs );
                     Log.LogSS( dldDebug, L"LEC", L"    not valid, trial, expires: ", logs );
                  #endif
               ELSE
                  info := ComputeInfo( bhBestCase, info, riNotActivated );
                  expires := ComputeExpiration( bhBestCase, expires, litem^.Created.JulianDate + unactExp );
                  localExpired := localExpired OR ( expires < nowJulianDate );

                  #if DEBUG #then      
                     JDCToDate( expires, OUT logs );
                     Log.LogSS( dldDebug, L"LEC", L"    not valid, not trial, expires: ", logs );
                  #endif
               END;

               #if DEBUG #then      
                  CASE info OF
                  | riUnknown :
                     Log.LogS( dldDebug, L"LEC", L"  Partial activation result: unknown" );
                  | riDemo :
                     Log.LogS( dldDebug, L"LEC", L"  Partial activation result: demo" );
                  | riNotActivated :
                     Log.LogS( dldDebug, L"LEC", L"  Partial activation result: not activated" );
                  | riActivated :
                     Log.LogS( dldDebug, L"LEC", L"  Partial activation result: activated" );
                  END; // CASE
               #endif

            END; // WHILE activations
            
         ELSIF trialFlag THEN
            info := ComputeInfo( bhBestCase, info, riDemo );
            expires := ComputeExpiration( bhBestCase, expires, _Start + demoExp );
            localExpired := localExpired OR ( expires < nowJulianDate );

            #if DEBUG #then      
               JDCToDate( expires, OUT logs );
               Log.LogSS( dldDebug, L"LEC", L"    not activated, trial, expires: ", logs );
            #endif

         ELSE
            info := ComputeInfo( bhBestCase, info, riNotActivated );
            expires := ComputeExpiration( bhBestCase, expires, litem^.Created.JulianDate + unactExp );
            localExpired := localExpired OR ( expires < nowJulianDate );

            #if DEBUG #then      
               JDCToDate( expires, OUT logs );
               Log.LogSS( dldDebug, L"LEC", L"    not activated, expires: ", logs );
            #endif

         END;
         
         s := litem^.Serial;
         IF Items.ltUnnamed NOT IN litem^.Type THEN
            s.AppendOA( L" (" );
            s.Append( litem^.Owner );
            s.AppendOA( L")" );
         END;
         IF localExpired THEN
            _Licences.Add( s, PTR( litem^.Type + Items.TLicenceType( TLicenceType{ltExpired} )));
         ELSIF localActivated THEN
            _Licences.Add( s, PTR( litem^.Type + Items.TLicenceType( TLicenceType{ltActivated} )));
         ELSE
            _Licences.Add( s, PTR( litem^.Type ));
         END;

         #if DEBUG #then      
            CASE info OF
            | riUnknown :
               Log.LogS( dldDebug, L"LEC", L"  Partial licence result: unknown" );
            | riDemo :
               Log.LogS( dldDebug, L"LEC", L"  Partial licence result: demo" );
            | riNotActivated :
               Log.LogS( dldDebug, L"LEC", L"  Partial licence result: not activated" );
            | riActivated :
               Log.LogS( dldDebug, L"LEC", L"  Partial licence result: activated" );
            END; // CASE
         #endif

      END; // WHILE licences

   Done:
      _Lock.Lock();
      _Info := ComputeInfo( Behaviour, _Info, info );
      _Expires := ComputeExpiration( Behaviour, _Expires, expires );
      _Lock.Unlock();

      #if DEBUG #then
         IF Behaviour = bhBestCase THEN
            Log.LogS( dldDebug, L"LEC", L"Computing best hit" );
         ELSE
            Log.LogS( dldDebug, L"LEC", L"Computing worst hit" );
         END;
         JDCToDate( _Expires, OUT logs );
         CASE info OF
         | riUnknown :
            Log.LogSS( dldDebug, L"LEC", L"Result: unknown, expires: ", logs );
         | riDemo :
            Log.LogSS( dldDebug, L"LEC", L"Result: demo, expires: ", logs );
         | riNotActivated :
            Log.LogSS( dldDebug, L"LEC", L"Result: not activated, expires: ", logs );
         | riActivated :
            Log.LogS( dldDebug, L"LEC", L"Result: activated" );
         END; // CASE
      #endif

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

   PUBLIC PROPERTY Expires GET : time.DateTime;
   VAR
      LExpires : time.TJD;
      TExpires : time.DateTime;
   BEGIN
      _Lock.Lock();
      LExpires := _Expires;
      _Lock.Unlock();
      IF ( LExpires = expNotSet ) OR ( LExpires = expNever ) THEN
         IF ( debugged^ OR DEBUGGED()) AND ODD(( PTR( ADR( TExpires )) >> 3 ) MOD 117 ) THEN
            TExpires.Year := 117;
         END;
      ELSE
         TExpires.JulianDate := LExpires;
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
      LExpires : time.DateTime;
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
   VAR
      counted : BOOLEAN;
   BEGIN
      _Lock.Lock();
      counted := _Counter >= countLimit;
      _Lock.Unlock();
      RETURN counted;
   END Counted;

(*--------------------------------------------------------------------------------*)

   PUBLIC PROPERTY Licences GET : lists.TPStringList;
   BEGIN
      RETURN ADR( _Licences );
   END Licences;

(*--------------------------------------------------------------------------------*)

   PUBLIC PROCEDURE Reset( _Behaviour : TBehaviour );
   BEGIN
      _Lock.Lock();
      Behaviour := _Behaviour;
      _Info := riUnknown;
      _Expires := expNotSet;
      _Licences.Dispose();
      _Lock.Unlock();
   END Reset;

(*--------------------------------------------------------------------------------*)

   PUBLIC PROCEDURE Inc();
   BEGIN
      IF _Info <= riDemo THEN
         _Lock.Lock();
         _Counter := MIN2( _Counter + 1, countLimit );
         _Lock.Unlock();
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

   #if DEBUG #then
      IF data.Count = 0 THEN      
         Log.LogSSSS( dldDebug, L"LEC", L"No products found in: ", Path1, Path2, ProductId );
      END;
   #endif

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

PROCEDURE StoreData( Value : BOOLEAN );
BEGIN
END StoreData;

(*================================================================================*)

BEGIN
   NEW( debugged );
   debugged^ := DEBUGGED();
FINALLY
   DISPOSE( debugged );
END lec.