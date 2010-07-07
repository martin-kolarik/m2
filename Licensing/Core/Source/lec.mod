IMPLEMENTATION MODULE lec;

FROM Debug IMPORT
   Assertion, LogAssertionW;

#if DEBUG #then
FROM log IMPORT
   CLogger, dldDebug;
#endif
   
IMPORT
   arrays,
   Engine,
   Items,
   lists,
   Store,
   Strings,
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

CLASS IMPLEMENTATION CProduct;

(*--------------------------------------------------------------------------------*)

   PUBLIC PROPERTY Id GET : StringsO.CString;
   BEGIN
      RETURN _Id;
   END Id;

(*--------------------------------------------------------------------------------*)

   PUBLIC PROPERTY Name GET : StringsO.CString;
   BEGIN
      RETURN _Name;
   END Name;

(*--------------------------------------------------------------------------------*)

   PUBLIC PROPERTY StateInfo GET : TStateInfo;
   BEGIN
      IF _StateInfo = siUnknown THEN
         RETURN siDemo;
      ELSIF ( debugged^ OR DEBUGGED()) AND ODD(( PTR( ADR( _StateInfo )) >> 3 ) MOD 317 ) THEN
         RETURN TStateInfo( CARDINAL( LOPTRLONGWORD( PTR( ADR( _StateInfo )) >> 3 )) MOD 2 + 1 );
      ELSE
         RETURN _StateInfo;
      END;
   END StateInfo;

(*--------------------------------------------------------------------------------*)

   PUBLIC PROPERTY Expires GET : time.DateTime;
   VAR
      TExpires : time.DateTime;
   BEGIN
      IF ( _Expires = expNotSet ) OR ( _Expires = expNever ) THEN
         IF ( debugged^ OR DEBUGGED()) AND ODD(( PTR( ADR( TExpires )) >> 3 ) MOD 297 ) THEN
            TExpires.Year := 297;
         END;
      ELSE
         TExpires.JulianDate := _Expires;
         // time.TrimTime( REF TExpires ); -- better is to not trim it, it allows use Expires as whole information
         IF ( debugged^ OR DEBUGGED()) AND ODD(( PTR( ADR( TExpires )) >> 3 ) MOD 297 ) THEN
            TExpires.Month := TExpires.Year;
            TExpires.Year := TExpires.Day;
         END;
      END;
      RETURN TExpires;
   END Expires;

(*--------------------------------------------------------------------------------*)

   PUBLIC PROPERTY Expired GET : BOOLEAN;
   BEGIN
      RETURN time.NowUTC().Greater( Expires );
   END Expired;

(*--------------------------------------------------------------------------------*)

   PUBLIC PROPERTY Info GET : lists.TPStringStringList;
   BEGIN
      RETURN ADR( _Info );
   END Info;

(*--------------------------------------------------------------------------------*)

   PUBLIC PROPERTY Licences GET : lists.TPStringList;
   BEGIN
      RETURN ADR( _Licences );
   END Licences;

(*--------------------------------------------------------------------------------*)

   VIRTUAL PROCEDURE Dispose();
   BEGIN
      _Licences.Dispose();
      _Info.Dispose();
   END Dispose;

(*--------------------------------------------------------------------------------*)

   LOCAL PROCEDURE Construct( CONST Name, Id : StringsO.IString; stateInfo : TStateInfo; expires : time.TJD );
   BEGIN
      _Name.Assign( Name );
      _Id.Assign( Id );
      _StateInfo := stateInfo;
      _Expires := expires;
   END Construct;

(*--------------------------------------------------------------------------------*)

BEGIN
   _StateInfo := siUnknown;
   _Expires := expNotSet;
   Dispose();
END CProduct;

(*================================================================================*)

#if DEBUG #then

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

CLASS IMPLEMENTATION CResult;

(*--------------------------------------------------------------------------------*)

   LOCAL PROCEDURE QueryStarted();
   BEGIN
   END QueryStarted;

(*--------------------------------------------------------------------------------*)

   LOCAL PROCEDURE QueryData( data : PTR );

   (*----------*)
   
      PROCEDURE ComputeInfo( behaviour : TBehaviour; current : TStateInfo; _new : TStateInfo ) : TStateInfo;
      BEGIN
         IF current = siUnknown THEN
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
      linfo : Items.TPInfo;
      info : TStateInfo := siUnknown;
      litem : Items.TPLicence;
      localActivated : BOOLEAN;
      localExpired : BOOLEAN;
      #if DEBUG #then
         logs : ARRAY[0..255] OF WCHAR;
      #endif
      pitem : Items.TPItem := data;
      product : TPProduct;
      s : StringsO.CString;
      trialFlag : BOOLEAN;
   BEGIN
      IF pitem = NIL THEN
         RETURN;
      END;
      ASSERT( pitem^ IS Items.CProduct );
      NEW( product );

      #if DEBUG #then
         Log.Level := dldDebug;
      #endif

      IF pitem^.HasChilds THEN

         #if DEBUG #then      
            pitem^.ProductId.ToOA( OUT logs );
            Log.LogSS( ldDebug, 0, L"LEC", L"Product with licences: ", logs );
         #endif

         now.SetNowUTC();
         nowJulianDate := now.JulianDate;
         expires := expNotSet;

      ELSE

         #if DEBUG #then      
            pitem^.ProductId.ToOA( OUT logs );
            Log.LogSS( ldDebug, 0, L"LEC", L"Product W/O licence: ", logs );
         #endif

         info := siDemo;
         expires := _Start + demoExp;
         GOTO Done;
      END;

      // parse licences
      litems := Items.TPProduct( pitem )^.LicencesAndInfos;
      litems^.Reset();
      WHILE litems^.MoveNext() DO
         litem := litems^.Current;

         IF litem^ IS Items.CInfo THEN // handle info
            linfo := Items.TPInfo( litem );
            IF linfo^.List <> NIL THEN
               linfo^.List^.Reset();
               WHILE linfo^.List^.MoveNext() DO
                  product^.Info^.Add( linfo^.List^.Current^, linfo^.List^.CurrentData^ );
               END;
            END;
            CONTINUE;
         END; 
         
         //  ELSE here we work with licence
         trialFlag := Items.ltTrial IN litem^.Type;
         
         #if DEBUG #then      
            litem^.Serial.ToOA( OUT logs );
            Log.LogSS( ldDebug, 0, L"LEC", L"  Licence, computing best hit: ", logs );
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
                  Log.LogSS( ldDebug, 0, L"LEC", L"  Activation, computing best hit, expires: ", logs );
               #endif

               IF aitem^.ValidFor( now ) THEN
               
                  info := ComputeInfo( bhBestCase, info, siActivated );
                  dt := aitem^.Expires;
                  IF dt.Year > 0 THEN
                     expires := ComputeExpiration( bhBestCase, expires, dt.JulianDate );

                     #if DEBUG #then      
                        Log.LogS( ldDebug, 0, L"LEC", L"    valid limitedly" );
                     #endif
                  ELSE
                     expires := expNever;

                     #if DEBUG #then      
                        Log.LogS( ldDebug, 0, L"LEC", L"    valid forever" );
                     #endif
                  END;
                  
                  localActivated := TRUE; // according to bhBestCase approach
                  
               ELSIF trialFlag THEN
                  info := ComputeInfo( bhBestCase, info, siDemo );
                  expires := ComputeExpiration( bhBestCase, expires, _Start + demoExp );
                  localExpired := localExpired OR ( expires < nowJulianDate );

                  #if DEBUG #then      
                     JDCToDate( expires, OUT logs );
                     Log.LogSS( ldDebug, 0, L"LEC", L"    not valid, trial, expires: ", logs );
                  #endif
               ELSE
                  info := ComputeInfo( bhBestCase, info, siNotActivated );
                  expires := ComputeExpiration( bhBestCase, expires, litem^.Created.JulianDate + unactExp );
                  localExpired := localExpired OR ( expires < nowJulianDate );

                  #if DEBUG #then      
                     JDCToDate( expires, OUT logs );
                     Log.LogSS( ldDebug, 0, L"LEC", L"    not valid, not trial, expires: ", logs );
                  #endif
               END;

               #if DEBUG #then      
                  CASE info OF
                  | siUnknown :
                     Log.LogS( ldDebug, 0, L"LEC", L"  Partial activation result: unknown" );
                  | siDemo :
                     Log.LogS( ldDebug, 0, L"LEC", L"  Partial activation result: demo" );
                  | siNotActivated :
                     Log.LogS( ldDebug, 0, L"LEC", L"  Partial activation result: not activated" );
                  | siActivated :
                     Log.LogS( ldDebug, 0, L"LEC", L"  Partial activation result: activated" );
                  END; // CASE
               #endif

            END; // WHILE activations
            
         ELSIF trialFlag THEN
            info := ComputeInfo( bhBestCase, info, siDemo );
            expires := ComputeExpiration( bhBestCase, expires, _Start + demoExp );
            localExpired := localExpired OR ( expires < nowJulianDate );

            #if DEBUG #then      
               JDCToDate( expires, OUT logs );
               Log.LogSS( ldDebug, 0, L"LEC", L"    not activated, trial, expires: ", logs );
            #endif

         ELSE
            info := ComputeInfo( bhBestCase, info, siNotActivated );
            expires := ComputeExpiration( bhBestCase, expires, litem^.Created.JulianDate + unactExp );
            localExpired := localExpired OR ( expires < nowJulianDate );

            #if DEBUG #then      
               JDCToDate( expires, OUT logs );
               Log.LogSS( ldDebug, 0, L"LEC", L"    not activated, expires: ", logs );
            #endif

         END;
         
         s := litem^.Serial;
         IF Items.ltUnnamed NOT IN litem^.Type THEN
            s.AppendOA( L" (" );
            s.Append( litem^.Owner );
            s.AppendOA( L")" );
         END;
         IF localExpired THEN
            product^.Licences^.Add( s, PTR( litem^.Type + Items.TLicenceType( TLicenceType{ltExpired} )));
         ELSIF localActivated THEN
            product^.Licences^.Add( s, PTR( litem^.Type + Items.TLicenceType( TLicenceType{ltActivated} )));
         ELSE
            product^.Licences^.Add( s, PTR( litem^.Type ));
         END;

         #if DEBUG #then      
            CASE info OF
            | siUnknown :
               Log.LogS( ldDebug, 0, L"LEC", L"  Partial licence result: unknown" );
            | siDemo :
               Log.LogS( ldDebug, 0, L"LEC", L"  Partial licence result: demo" );
            | siNotActivated :
               Log.LogS( ldDebug, 0, L"LEC", L"  Partial licence result: not activated" );
            | siActivated :
               Log.LogS( ldDebug, 0, L"LEC", L"  Partial licence result: activated" );
            END; // CASE
         #endif

      END; // WHILE licences

   Done:
      product^.Construct( pitem^.ProductId, Items.TPProduct( pitem )^.Name, info, expires );
   
      _Lock.Lock();
      _Products.Add( product, 0 );
      _Info := ComputeInfo( Behaviour, _Info, info );
      _Expires := ComputeExpiration( Behaviour, _Expires, expires );
      _Lock.Unlock();

      #if DEBUG #then
         IF Behaviour = bhBestCase THEN
            Log.LogS( ldDebug, 0, L"LEC", L"Computing best hit" );
         ELSE
            Log.LogS( ldDebug, 0, L"LEC", L"Computing worst hit" );
         END;
         JDCToDate( _Expires, OUT logs );
         CASE info OF
         | siUnknown :
            Log.LogSS( ldDebug, 0, L"LEC", L"Result: unknown, expires: ", logs );
         | siDemo :
            Log.LogSS( ldDebug, 0, L"LEC", L"Result: demo, expires: ", logs );
         | siNotActivated :
            Log.LogSS( ldDebug, 0, L"LEC", L"Result: not activated, expires: ", logs );
         | siActivated :
            Log.LogS( ldDebug, 0, L"LEC", L"Result: activated" );
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

   LOCAL PROPERTY StateInfo GET : TStateInfo;
   VAR
      LInfo : TStateInfo;
   BEGIN
      LInfo := TStateInfo( _Lock.Get( REF _Info ));
      IF LInfo = siUnknown THEN
         RETURN siDemo;
      ELSIF ( debugged^ OR DEBUGGED()) AND ODD(( PTR( ADR( LInfo )) >> 3 ) MOD 117 ) THEN
         RETURN TStateInfo( CARDINAL( LOPTRLONGWORD( PTR( ADR( LInfo )) >> 3 )) MOD 2 + 1 );
      ELSE
         RETURN LInfo;
      END;
   END StateInfo;

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

   PUBLIC PROCEDURE Reset( _Behaviour : TBehaviour );
   BEGIN
      _Lock.Lock();
      Behaviour := _Behaviour;
      _Info := siUnknown;
      _Expires := expNotSet;
      Dispose();
      _Lock.Unlock();
   END Reset;

(*--------------------------------------------------------------------------------*)

   PUBLIC PROCEDURE Inc();
   BEGIN
      IF _Info <= siDemo THEN
         _Lock.Lock();
         _Counter := MIN2( _Counter + 1, countLimit );
         _Lock.Unlock();
      END;
   END Inc;

(*--------------------------------------------------------------------------------*)

   PUBLIC PROCEDURE GetLicences( OUT list : lists.CStringList ); // fills licences of the first product
   VAR
      product : TPProduct;
      data : PTR;
   BEGIN
      list.Dispose();
      _Lock.Lock();
      IF _Products.GetFirst( OUT product, OUT data ) THEN
         product^.Licences^.Reset();
         WHILE product^.Licences^.MoveNext() DO
            list.Add( product^.Licences^.Current^, product^.Licences^.CurrentData );
         END;
      END;
      _Lock.Unlock();
   END GetLicences;

(*--------------------------------------------------------------------------------*)

   PUBLIC PROCEDURE ProductsLock();
   BEGIN
      _Lock.Lock();
   END ProductsLock;

(*--------------------------------------------------------------------------------*)

   PUBLIC PROCEDURE ProductsUnlock();
   BEGIN
      _Lock.Unlock();
   END ProductsUnlock;

(*--------------------------------------------------------------------------------*)

   PUBLIC PROCEDURE ProductsReset();
   BEGIN
      _Products.Reset();
   END ProductsReset;

(*--------------------------------------------------------------------------------*)

   PUBLIC PROCEDURE ProductsMoveNext() : BOOLEAN;
   BEGIN
      RETURN _Products.MoveNext();
   END ProductsMoveNext;

(*--------------------------------------------------------------------------------*)

   PUBLIC PROPERTY CurrentProduct GET : TPProduct;
   BEGIN
      RETURN TPProduct( _Products.Current );
   END CurrentProduct;

(*--------------------------------------------------------------------------------*)

   PRIVATE PROCEDURE Dispose();
   VAR
      product : TPProduct;
   BEGIN
      _Products.Reset();
      WHILE _Products.MoveNext() DO
         product := _Products.Current;
         DISPOSE( product );
      END; // WHILE
      _Products.Dispose();
   END Dispose;

(*--------------------------------------------------------------------------------*)

BEGIN
   _Lock.Init( sync.ltSpin, L"", FALSE );
   _Info := siUnknown;
   _Expires := expNotSet;
   _Start := time.GetCurrentJD();
   _Counter := 0;
FINALLY
   Dispose();
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
         Log.LogSSSS( ldDebug, 0, L"LEC", L"No products found in: ", Path1, Path2, ProductId );
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

PROCEDURE StoreInfo( CONST Path : ARRAY OF WCHAR; Data : ADDRESS; Length : CARDINAL; CONST InfoKey, InfoValue : StringsO.IString );
VAR
   pid : StringsO.CString;
BEGIN
   Validator.UnwrapData( Data, Length, OUT pid );
   Engine.StoreInfo( Path, OA( pid.Length-1, pid.rawData ), InfoKey, InfoValue );
END StoreInfo;

(*================================================================================*)

BEGIN
   NEW( debugged );
   debugged^ := DEBUGGED();
FINALLY
   DISPOSE( debugged );
END lec.