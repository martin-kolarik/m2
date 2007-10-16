MODULE MSIStub;

#name( decoration => c )

FROM Storage IMPORT
   ALLOCATE, DEALLOCATE;

IMPORT
   windows,
   array,
   arrays,
   Engine,
   IOO,
   Items,
   Msi,
   MsiQuery,
   Number,
   Store,
   StringsO,
   time,
   Uniquer,
   winerror;

(*# save, call( convention => stdcall ) *)
PROCEDURE Check( hInstall : Msi.MSIHANDLE ) : CARDINAL; FORWARD;
PROCEDURE Apply( hInstall : Msi.MSIHANDLE ) : CARDINAL; FORWARD;
(*#restore *)

PROCEDURE Check( hInstall : Msi.MSIHANDLE ) : CARDINAL;
VAR
   buffer : ARRAY[0..511] OF WCHAR;
   owner : StringsO.CString;
   pid : StringsO.CString;
   serial : StringsO.CString;
   l : CARDINAL;
   sn : Number.CSerial;
   Valid : BOOLEAN := TRUE;
BEGIN
   l := HIGH( buffer ) + 1;
   MsiQuery.MsiGetPropertyW( hInstall, L"PID", ADR( buffer ), REF l );
   IF l > 0 THEN
     pid.FromOA( OA( l-1, ADR( buffer )));
   END;

   l := HIGH( buffer ) + 1;
   MsiQuery.MsiGetPropertyW( hInstall, L"PIDKEY", ADR( buffer ), REF l );
   IF l > 0 THEN
     serial.FromOA( OA( l-1, ADR( buffer )));
   END;

   l := HIGH( buffer ) + 1;
   MsiQuery.MsiGetPropertyW( hInstall, L"POWNER", ADR( buffer ), REF l );
   IF l > 0 THEN
     owner.FromOA( OA( l-1, ADR( buffer )));
   END;

   Valid := Number.Decode( serial, REF sn );
   Valid := Valid AND sn.CheckPId( pid );
   IF NOT Valid THEN
     // fall down
   ELSIF Items.ltUnnamed IN sn.Type THEN
     // fall down
   ELSIF owner.Empty THEN
     Valid := FALSE;
   ELSE
     Valid := sn.CheckOwner( owner );
   END;
   IF Valid THEN
      MsiQuery.MsiSetPropertyW( hInstall, L"PIDACCEPTED", L"1"+0W );
   ELSE
      MsiQuery.MsiSetPropertyW( hInstall, L"PIDACCEPTED", L"0"+0W );
   END;

   RETURN 0;
END Check;

PROCEDURE Apply( hInstall : Msi.MSIHANDLE ) : CARDINAL;
CONST
   propPID = 0;
   propPIDKey = 1;
   propPIDOwner = 2;
   propPIDLicence = 3;
VAR
   buffer : ARRAY[0..1023] OF WCHAR;
   count : CARDINAL;
   data : arrays.CPtrArray;
   i : CARDINAL;
   item : Items.TPItem;
   licenceItem : Items.TPLicence;
   ls : Store.CFileStorage;
   lsINI : Store.CINIFilter;
   properties : ARRAY [0..3] OF StringsO.CString;
   s : StringsO.CString;
   l : CARDINAL;
   sn : Number.CSerial;
   uq : Uniquer.CUniquer;
   uqDisc : Uniquer.DiscSource;
   Valid : BOOLEAN := TRUE;
BEGIN
   l := HIGH( buffer ) + 1;
   MsiQuery.MsiGetPropertyW( hInstall, L"CustomActionData", ADR( buffer ), REF l );
   IF l > 0 THEN
     s.FromOA( OA( l-1, ADR( buffer )));
   END;
   s.SplitS( StringsO.WCHARS{L';'}, 0, FALSE, OUT l, OUT properties );

   Valid := Number.Decode( properties[propPIDKey], REF sn );
   Valid := Valid AND sn.CheckPId( properties[propPID] );
   IF NOT Valid THEN
     // fall down
   ELSIF Items.ltUnnamed IN sn.Type THEN
     // fall down
   ELSIF properties[propPIDOwner].Empty THEN
     Valid := FALSE;
   ELSE
     Valid := sn.CheckOwner( properties[propPIDOwner] );
   END;

   IF Valid THEN
      data.Strategy := array.astrgListInArray;
      ls.Filters^.Add( ADR( lsINI ), 0 );
      TRY
         Valid := ls.LoadSingleFile( properties[propPIDLicence], REF data, FALSE, TRUE );
      CATCH : IOO.CIOException DO
         Valid := FALSE;
      END;
   END;
   IF Valid THEN
      Engine.Canonize( REF data, L"*", FALSE, TRUE, TRUE );

      uq.Sources^.Add( ADR( uqDisc ), 0 );

      licenceItem := NIL;
      i := 0;
      count := data.Count;
      WHILE i < count DO
         item := Items.TPItem( data[i] );
         IF sn.CheckPId( item^.ProductId ) THEN
            IF item^ IS Items.CProduct THEN // apply

               NEW( licenceItem );
               licenceItem^.ProductId := item^.ProductId;
               licenceItem^.Type := sn.Type;
               time.GetCurrentUTCDateTime( licenceItem^.Created );
               licenceItem^.Serial := properties[propPIDKey];
               licenceItem^.Owner := properties[propPIDOwner];
               licenceItem^.UId := uq.UId( licenceItem^.ProductId );
               data.Add( licenceItem );

            ELSIF item^ IS Items.CLicence THEN // remove now invalid items

               data.RemoveIndex( i );
               DISPOSE( item );
               DEC( count );

               CONTINUE; // skip incrementing i
            END;
         END;

         INC( i );
      END; // WHILE items
      
      ls.StoreSingleFile( properties[propPIDLicence], data );
   END;

   IF Valid THEN
      RETURN 0;
   ELSE
      RETURN winerror.ERROR_INVALID_PARAMETER;
   END;
END Apply;

END MSIStub.