IMPLEMENTATION MODULE lec;

FROM Debug IMPORT
   AssertionW;

#if DEBUG #then
FROM log IMPORT
   CLogger, ldDebug, ldMessage;
#endif
   
IMPORT
   arrays,
   collection,
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
   #if #false #and DEBUG #then
      demoExp = 3.0 / 1440.0; // 3 minutes
      unactExp = 1.0;
   #else
      demoExp = 6.0 / 240.0; // 0.6 hours
      unactExp = 33.0;
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

   PUBLIC PROPERTY Expires GET : datetime.DateTime;
   VAR
      TExpires : datetime.DateTime;
   BEGIN
      IF _Expires.IsLowBound THEN
         TExpires.SetNowUTC();
         IF ( debugged^ OR DEBUGGED()) AND ODD(( PTR( ADR( TExpires )) >> 3 ) MOD 117 ) THEN
            TExpires.Year := 117;
         END;
      ELSIF _Expires.IsHighBound THEN
         IF ( debugged^ OR DEBUGGED()) AND ODD(( PTR( ADR( TExpires )) >> 3 ) MOD 297 ) THEN
            TExpires.Year := 297;
         END;
      ELSE
         TExpires.DayCount := _Expires;
         // datetime.TrimTime( REF TExpires ); -- better to not trim it, it allows use Expires as whole information
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
      RETURN datetime.NowUTC() > Expires;
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

   LOCAL PROCEDURE Construct( CONST Name, Id : StringsO.IString; stateInfo : TStateInfo; expires : datetime.DayCount );
   BEGIN
      _Name.Assign( Name );
      _Id.Assign( Id );
      _StateInfo := stateInfo;
      _Expires := expires;
   END Construct;

(*--------------------------------------------------------------------------------*)

BEGIN
   _StateInfo := siUnknown;
   _Expires.SetLowBound();
   Dispose();
END CProduct;

(*================================================================================*)

#if DEBUG #then

VAR
   Log : CLogger;

PROCEDURE DCToString( dc : datetime.DayCount; OUT dateString : ARRAY OF WCHAR );
VAR
   dt : datetime.DateTime;
BEGIN
   dt.DayCount := dc;
   dt.ToStringOA( L"yy-MM-dd HH:mm", TRUE, TRUE, OUT dateString );
END DCToString;

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
   
      PROCEDURE ComputeExpiration( behaviour : TBehaviour; current : datetime.DayCount; _new : datetime.DayCount ) : datetime.DayCount;
      BEGIN
         IF current.IsLowBound THEN
            RETURN _new;
         ELSIF behaviour = bhWorstCase THEN
            IF current < _new THEN
               RETURN current;
            ELSE
               RETURN _new;
            END;
         ELSIF behaviour = bhBestCase THEN
            IF current > _new THEN
               RETURN current;
            ELSE
               RETURN _new;
            END;
         ELSE
            RETURN current;
         END;
      END ComputeExpiration;

   (*----------*)

   LABEL
      Done;
   VAR
      ait, lit : lists.CPtrListIterator;
      aitem : Items.TPActivation;
      dt, now : datetime.DateTime;
      expires, nowDayCount : datetime.DayCount;
      linfo : Items.TPInfo;
      linfolit : lists.CStringStringListIterator;
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
         Log.Level := ldDebug;
      #endif

      IF pitem^.HasChilds THEN

         #if DEBUG #then      
            pitem^.ProductId.ToOA( OUT logs );
            Log.LogSS( ldDebug, 0, L"LEC", L"Product with licences: ", logs );
         #endif

         now.SetNowUTC();
         nowDayCount := now.DayCount;
         expires.SetLowBound();

      ELSE

         #if DEBUG #then      
            pitem^.ProductId.ToOA( OUT logs );
            Log.LogSS( ldDebug, 0, L"LEC", L"Product W/O licence: ", logs );
         #endif

         info := siDemo;
         expires := _Start + datetime.TimeSpanD( demoExp );
         GOTO Done;
      END;

      // parse licences
      lit.Init( Items.TPProduct( pitem )^.LicencesAndInfos^, collection.dirForward );
      WHILE lit.MoveNext() DO
         litem := lit.Value;

         IF litem^ IS Items.CInfo THEN // handle info
            linfo := Items.TPInfo( litem );
            IF linfo^.List <> NIL THEN
               linfolit.Init( linfo^.List^, collection.dirForward );
               WHILE linfolit.MoveNext() DO
                  product^.Info^.Add( linfolit.Value^, linfolit.Data^ );
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
            ait.Init( litem^.Activations^, collection.dirForward );
            WHILE ait.MoveNext() DO
               aitem := ait.Value;

               #if DEBUG #then      
                  aitem^.ExpiresString.ToOA( OUT logs );
                  Log.LogSS( ldDebug, 0, L"LEC", L"  Activation, computing best hit, expires: ", logs );
               #endif

               IF aitem^.ValidFor( now ) THEN
               
                  info := ComputeInfo( bhBestCase, info, siActivated );
                  dt := aitem^.Expires;
                  IF dt.Year > 0 THEN
                     expires := ComputeExpiration( bhBestCase, expires, dt.DayCount );

                     #if DEBUG #then      
                        Log.LogS( ldDebug, 0, L"LEC", L"    valid limitedly" );
                     #endif
                  ELSE
                     expires.SetHighBound();

                     #if DEBUG #then      
                        Log.LogS( ldDebug, 0, L"LEC", L"    valid forever" );
                     #endif
                  END;
                  
                  localActivated := TRUE; // according to bhBestCase approach
                  
               ELSIF trialFlag THEN
                  info := ComputeInfo( bhBestCase, info, siDemo );
                  expires := ComputeExpiration( bhBestCase, expires, _Start + datetime.TimeSpanD( demoExp ));
                  localExpired := localExpired OR ( expires < nowDayCount );

                  #if DEBUG #then      
                     DCToString( expires, OUT logs );
                     Log.LogSS( ldDebug, 0, L"LEC", L"    not valid, trial, expires: ", logs );
                  #endif
               ELSE
                  info := ComputeInfo( bhBestCase, info, siNotActivated );
                  expires := ComputeExpiration( bhBestCase, expires, litem^.Created.DayCount + datetime.TimeSpanD( unactExp ));
                  localExpired := localExpired OR ( expires < nowDayCount );

                  #if DEBUG #then      
                     DCToString( expires, OUT logs );
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
            expires := ComputeExpiration( bhBestCase, expires, _Start + datetime.TimeSpanD( demoExp ));
            localExpired := localExpired OR ( expires < nowDayCount );

            #if DEBUG #then      
               DCToString( expires, OUT logs );
               Log.LogSS( ldDebug, 0, L"LEC", L"    not activated, trial, expires: ", logs );
            #endif

         ELSE
            info := ComputeInfo( bhBestCase, info, siNotActivated );
            expires := ComputeExpiration( bhBestCase, expires, litem^.Created.DayCount + datetime.TimeSpanD( unactExp ));
            localExpired := localExpired OR ( expires < nowDayCount );

            #if DEBUG #then      
               DCToString( expires, OUT logs );
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
         DCToString( _Expires, OUT logs );
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
      IF _Expires.IsLowBound THEN
         _Expires := _Start + datetime.TimeSpanD( demoExp );
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

   PUBLIC PROPERTY Expires GET : datetime.DateTime;
   VAR
      LExpires : datetime.DayCount;
      TExpires : datetime.DateTime;
   BEGIN
      _Lock.Lock();
      LExpires := _Expires;
      _Lock.Unlock();
      IF LExpires.IsLowBound THEN
         TExpires.SetNowUTC();
         IF ( debugged^ OR DEBUGGED()) AND ODD(( PTR( ADR( TExpires )) >> 3 ) MOD 117 ) THEN
            TExpires.Year := 117;
         END;
      ELSIF LExpires.IsHighBound THEN
         IF ( debugged^ OR DEBUGGED()) AND ODD(( PTR( ADR( TExpires )) >> 3 ) MOD 297 ) THEN
            TExpires.Year := 297;
         END;
      ELSE
         TExpires.DayCount := LExpires;
         // datetime.TrimTime( REF TExpires ); -- better is to not trim it, it allows use Expires as whole information
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
      expires : datetime.DayCount;
      LExpires : datetime.DateTime;
      ts : datetime.TimeSpan;
   BEGIN
      _Lock.Lock();
      expires := _Expires;
      _Lock.Unlock();
      // shortcut
      IF expires.IsLowBound OR expires.IsHighBound THEN
         IF ( debugged^ OR DEBUGGED()) AND ODD(( PTR( ADR( LExpires )) >> 3 ) MOD 117 ) THEN
            RETURN 0;
         END;
         RETURN -1;
      ELSE
         ts := expires.Difference( datetime.NowDC());
         IF ts.Negative THEN
            RETURN 0;
         ELSIF ts.Days > 20.0 THEN // days
            RETURN 20 * 86400 * 1000;
         ELSE
            RETURN CARDINAL( ts.Milliseconds ); // now range of ts is less than returned CARDINAL
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

   PUBLIC PROPERTY Products GET : lists.TPPtrList;
   BEGIN
      RETURN ADR( _Products );
   END Products;

(*--------------------------------------------------------------------------------*)

   PUBLIC PROCEDURE Reset( _Behaviour : TBehaviour );
   BEGIN
      _Lock.Lock();
      Behaviour := _Behaviour;
      _Info := siUnknown;
      _Expires.SetLowBound();
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
      data : PTR;
      it : lists.CPtrListIterator;
      pit : lists.CStringListIterator;
   BEGIN
      list.Dispose();
      _Lock.Lock();
      it.Init( _Products, collection.dirForward );
      IF it.MoveNext() THEN
         pit.Init( TPProduct( it.Value )^.Licences^, collection.dirForward );
         WHILE pit.MoveNext() DO
            list.Add( pit.Value^, pit.Data );
         END;
      END;
      _Lock.Unlock();
   END GetLicences;

(*--------------------------------------------------------------------------------*)

   PUBLIC VIRTUAL PROCEDURE Dispose();
   VAR
      it : lists.CPtrListIterator;
      product : TPProduct;
   BEGIN
      it.Init( _Products, collection.dirForward );
      WHILE it.MoveNext() DO
         product := it.Value;
         DISPOSE( product );
      END; // WHILE
      _Products.Dispose();
   END Dispose;

(*--------------------------------------------------------------------------------*)

BEGIN
   _Lock.Init( sync.ltSpin, L"", FALSE );
   _Info := siUnknown;
   _Expires.SetLowBound();
   _Start := datetime.NowDC();
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
         Log.LogSSSS( ldMessage, 0, L"LEC", L"No products found in: ", Path1, Path2, ProductId );
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
   Query( Path1, Path2, OA( ProductId.Length-1, ProductId.Data ), REF Result );
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
   Engine.StoreInfo( Path, OA( pid.Length-1, pid.Data ), InfoKey, InfoValue );
END StoreInfo;

(*================================================================================*)

BEGIN
   NEW( debugged );
   debugged^ := DEBUGGED();
FINALLY
   DISPOSE( debugged );
END lec.
