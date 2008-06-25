IMPLEMENTATION MODULE xmlsocket;

//================================================================================
(*/* changes:

9.2.2006 (1, 2/3, 2, 2, 1/2, 3, 2) -- created, makefile, empty classes

28.2.2006 (1.5)
-- opravena chyba kódování, znaky s háèky apod. se nepøenesly, protože Flash oèekával jiný kód,
-- opravena chyba posílání více zpráv -- uvnitø se jednotlivé požadavky na odeslání dat scházejí ve frontì, fronta se pak posílá najednou. Fronta je vìtšinou prázdná (to odpovídá jednomu odeslání), a když se v ní sešlo více požadavkù, již se žádný nezpracoval,
-- chyba s mezerami -- možná souvisí s chybou kódování, já jsem ji již nepozoroval,

12.3.2006 (2)
-- opravena chyba fronty -- test na fullness byl ostry, takze fronta po prvnim preplneni a pak vycteni zustala ve stavu T = H+1, a nasledne cteni pak casto z domnele alokovaneho prvku H vracelo FALSE protoze MLen = 0 (toto se nesmi menit, to resi asynchroniciu plneni: item s MLen = 0 je alokovany, ale necommitnuty)
-- do fronty pridano flushovani pri plnosti
-- opravena chyba fronty, hranice typu pro T, H -- misto H+L>T je nyni T-L-H>=0 (viz prvni chyba)
-- opravena chyba fronty, pocitani ItemsPower vybiralo dvojnasobne delky

20.12.2006
-- zavedení do nového build systému

*/*)
//================================================================================

IMPORT
  winsock;

FROM Storage IMPORT
  REALLOCATE, ALLOCATE, DEALLOCATE;

IMPORT
  guiddef,
  windows,
  winerror,
  winnls,
  wtypes,
  oaidl,
  oleauto;

IMPORT
  Languages,
  Resources,
  Strings,
  Storage,
  Texts;

IMPORT
  com,
  ax_automation;

IMPORT
  netinit,
  netsocket,
  netsrv,
  netconndispatch;

//================================================================================

TYPE
  TPIMMFlashSrv_Event  = POINTER TO CIMMFlashSrv_Event;
  TPIMMFlashSrv_Native = POINTER TO CIMMFlashSrv_Native;
  TPFlashConnectorAX   = POINTER TO CFlashConnectorAX;

//--------------------------------------------------------------------------------

CLASS IMPLEMENTATION CXMLSocket( netconndispatch.CDispatcher );

  RBuffer : ADDRESS;
  RPos : CARDINAL;
  RSize : CARDINAL;
  RMax : CARDINAL;

  SBuffer : ADDRESS;
  SPos : CARDINAL;
  SSize : CARDINAL;

  // inherited from Dispatcher
  VIRTUAL PROCEDURE OnConnect( PConnection : netconndispatch.TConnectionHandle; Local : BOOLEAN; Error : CARDINAL );
  VIRTUAL PROCEDURE OnDisconnect( PConnection : netconndispatch.TConnectionHandle; Local : BOOLEAN; ErrorCode : CARDINAL );
  VIRTUAL PROCEDURE OnReceive( PConnection : netconndispatch.TConnectionHandle; Data : ADDRESS; DataLen : CARDINAL );

  PUBLIC PROCEDURE Parse( PConection : netconndispatch.TConnectionHandle; Data : ADDRESS; Len : CARDINAL );
  PUBLIC PROCEDURE SendMMFData( PConnection : netconndispatch.TConnectionHandle; StartBatch, StopBatch : BOOLEAN; DataName, DataValue, DataAddOn : wtypes.BSTR );
END CServer;

//--------------------------------------------------------------------------------

VAR
  R : Resources.CResources;
  RefCount : CARDINAL;

CONST
  leading = C'<flashconn>';
  trailing = C'</flashconn>';
  flashconnt = C'/flashconn';
  iteml = C'item';
  itemt = C'/item';
  namel = C'name';
  namet = C'/name';
  valuel = C'value';
  valuet = C'/value';
  addonl = C'addon';
  addont = C'/addon';

CLASS IMPLEMENTATION CServer;

//--------------------------------------------------------------------------------

  VIRTUAL PROCEDURE OnConnect( PConnection : netconndispatch.TConnectionHandle; Local : BOOLEAN; ErrorCode : CARDINAL );
  BEGIN
    IF NOT Local THEN
      PAX^.OnRemoteConnect( PConnection );
    END;
  END OnConnect;

//--------------------------------------------------------------------------------

  VIRTUAL PROCEDURE OnDisconnect( PConnection : netconndispatch.TConnectionHandle; Local : BOOLEAN; ErrorCode : CARDINAL );
  BEGIN
    IF NOT Local THEN
      PAX^.OnRemoteDisconnect( PConnection, ErrorCode );
    END;
  END OnDisconnect;

//--------------------------------------------------------------------------------

  VIRTUAL PROCEDURE OnReceive( PConnection : netconndispatch.TConnectionHandle; PData : ADDRESS; DataLen : CARDINAL );
  TYPE
    TPCH = POINTER TO CHAR;
    TS = ARRAY [0..4095] OF CHAR;
    TPS = POINTER TO TS;
  VAR
    c : CARDINAL;
    DPos : CARDINAL;
    EPos : CARDINAL;
    TrailingZero : BOOLEAN;
  BEGIN
    c := RPos + DataLen + 1;
    IF c > RMax THEN
      RPos := 0;
      // PAX^.OnRemoteReceive( PConnection, NIL, 0, -1 );
      RETURN;
    ELSIF c > RSize THEN
      RSize := (( RSize + c ) << 10 + 1 ) >> 10;
      REALLOCATE( RBuffer, RSize );
    END;

    Storage.Move( PData, ADDRESS( CARDINAL( RBuffer ) + RPos ), DataLen );
    INC( RPos, DataLen-1 );
    TrailingZero := TPCH( ADDRESS( CARDINAL( RBuffer ) + RPos ))^ = CHAR( 0 );
    INC( RPos );
    IF NOT TrailingZero THEN
      TPCH( ADDRESS( CARDINAL( RBuffer ) + RPos ))^ := CHAR( 0 );
    END;

    LOOP
      IF RPos < SIZE( leading )-1 THEN
        RETURN;
      END;

      DPos := Strings.IndexOfA( TPS( RBuffer )^, leading, 0 );
      IF DPos = MAX( CARDINAL ) THEN // strange
        c := Strings.IndexOfCharA( TPS( RBuffer )^, C'<', 0 );
        IF c = MAX( CARDINAL ) THEN
          RPos := 0;
        ELSIF c = 0 THEN // first is tag, but it is not leading
          DEC( RPos, 1 );
          Storage.Move( ADDRESS( CARDINAL( RBuffer ) + 1 ), RBuffer, RPos );
        ELSE
          DEC( RPos, c );
          Storage.Move( ADDRESS( CARDINAL( RBuffer ) + c ), RBuffer, RPos );
        END;
        RETURN;
      ELSIF DPos > 0 THEN
        DEC( RPos, DPos );
        Storage.Move( ADDRESS( CARDINAL( RBuffer ) + DPos ), RBuffer, RPos );
      END;
      EPos := Strings.IndexOfA( TPS( RBuffer )^, trailing, 0 );
      IF EPos = MAX( CARDINAL ) THEN
        RETURN;
      END;
      INC( EPos, SIZE( trailing )-1 );
    
      Parse( PConnection, RBuffer, EPos );

      DEC( RPos, EPos ); 
      IF TrailingZero THEN
        DEC( RPos );
      END;
      Storage.Move( ADDRESS( CARDINAL( RBuffer ) + EPos ), RBuffer, RPos );
    END; // LOOP
  END OnReceive;

//--------------------------------------------------------------------------------

  PROCEDURE Parse( PConnection : netconndispatch.TConnectionHandle; Data : ADDRESS; Len : CARDINAL );
  TYPE
    TPCH = POINTER TO CHAR;
    TS = ARRAY [0..4095] OF CHAR;
    TPS = POINTER TO TS;
  VAR
    i : CARDINAL;
    Tag, Name, Value : ARRAY [0..127] OF CHAR;
    AddOn : ARRAY [0..1023] OF CHAR;
    NameW, ValueW : ARRAY [0..127] OF WCHAR;
    AddOnW : ARRAY [0..1023] OF WCHAR;
    X : ADDRESS;
    InItem : BOOLEAN;
  BEGIN
    X := NIL;
    LOOP
      IF Len = 0 THEN
        EXIT;
      END;
      IF TPCH( Data )^ = C'<' THEN
        INC( Data ); DEC( Len );

        i := 0;
        LOOP
          IF Len = 0 THEN
            RETURN;
          ELSIF i+1 >= SIZE( Tag ) THEN
            RETURN;
          ELSIF TPCH( Data )^ = C'>' THEN
            Tag[i] := CHAR( 0 );

            IF EQUALS( Tag, flashconnt ) THEN
              RETURN;
            ELSIF EQUALS( Tag, iteml ) THEN
              InItem := TRUE;
              Name[0] := CHAR( 0 ); Value[0] := CHAR( 0 ); AddOn[0] := CHAR( 0 );
            ELSIF EQUALS( Tag, itemt ) THEN
              InItem := FALSE;
              IF Name[0] <> CHAR( 0 ) THEN
                Strings.ToW( Name, winnls.CP_UTF8, OUT NameW );
                Strings.ToW( Value, winnls.CP_UTF8, OUT ValueW );
                Strings.ToW( AddOn, winnls.CP_UTF8, OUT AddOnW );
                PAX^.OnRemoteData( PConnection, NameW, ValueW, AddOnW );
              END;
            ELSIF NOT InItem THEN
              // pass down
            ELSIF EQUALS( Tag, namel ) THEN
              X := Data; INC( X );
            ELSIF EQUALS( Tag, valuel ) THEN
              X := Data; INC( X );
            ELSIF EQUALS( Tag, addonl ) THEN
              X := Data; INC( X );
            ELSIF X = NIL THEN
              // pass down
            ELSIF EQUALS( Tag, namet ) THEN
              i := MIN2( SIZE( Name )-1, CARDINAL( Data ) - CARDINAL( X ) - SIZE( namet ));
              Storage.Move( X, ADR( Name ), i );
              Name[i] := CHAR( 0 );
            ELSIF EQUALS( Tag, valuet ) THEN
              i := MIN2( SIZE( Value )-1, CARDINAL( Data ) - CARDINAL( X ) - SIZE( valuet ));
              Storage.Move( X, ADR( Value ), i );
              Value[i] := CHAR( 0 );
            ELSIF EQUALS( Tag, addont ) THEN
              i := MIN2( SIZE( AddOn )-1, CARDINAL( Data ) - CARDINAL( X ) - SIZE( addont ));
              Storage.Move( X, ADR( AddOn ), i );
              AddOn[i] := CHAR( 0 );
            END;

            EXIT;
          ELSIF TPCH( Data )^ IN CHAR{ CHAR( 9 ), CHAR( 10 ), CHAR( 13 ), C' ' } THEN
            // skip blanks
          ELSE
            Tag[i] := TPCH( Data )^;
            INC( i );
          END;   

          INC( Data ); DEC( Len );
        END; // LOOP
      END;

      INC( Data ); DEC( Len );
    END; // LOOP
  END Parse;
  
//--------------------------------------------------------------------------------

  PROCEDURE SendMMFData( PConnection : netconndispatch.TConnectionHandle; StartBatch, StopBatch : BOOLEAN; DataName, DataValue, DataAddOn : wtypes.BSTR );
  CONST
    c1 = C'<flashconn>';
    c2 = C'<item><name>';
    c3 = C'</name><value>';
    c4 = C'</value></item>';
    c5 = C'</value><addon>';
    c6 = C'</addon></item>';
    c7 = C'</flashconn>';
  VAR
    DName, DValue : ARRAY [0..511] OF CHAR;
    DAddOn : ARRAY [0..1099] OF CHAR;
    l : CARDINAL;
  BEGIN
    IF SPos + 1024 + 1024 + 64 > SSize THEN
      SUPER.Send( NIL, PConnection, 0, SBuffer, SPos );
      SPos := 0;
    END;

    IF StartBatch THEN
      Storage.Move( ADR( c1 ), ADDRESS( CARDINAL( SBuffer ) + SPos ), SIZE( c1 )-1 );
      INC( SPos, SIZE( c1 )-1 );
    END;
    IF ( DataName <> NIL ) AND ( DataName^ <> WCHAR( 0 )) THEN
      Strings.ToA( OA( HIGH( DName ), DataName ), winnls.CP_UTF8, OUT DName );
      Strings.ToA( OA( HIGH( DValue ), DataValue ), winnls.CP_UTF8, OUT DValue );

      Storage.Move( ADR( c2 ), ADDRESS( CARDINAL( SBuffer ) + SPos ), SIZE( c2 )-1 );
      INC( SPos, SIZE( c2 )-1 );
      //..
      l := LENGTH( DName );
      Storage.Move( ADR( DName ), ADDRESS( CARDINAL( SBuffer ) + SPos ), l );
      INC( SPos, l );
      //..
      Storage.Move( ADR( c3 ), ADDRESS( CARDINAL( SBuffer ) + SPos ), SIZE( c3 )-1 );
      INC( SPos, SIZE( c3 )-1 );
      //..
      l := LENGTH( DValue );
      Storage.Move( ADR( DValue ), ADDRESS( CARDINAL( SBuffer ) + SPos ), l );
      INC( SPos, l );

      IF DataAddOn^ = WCHAR( 0 ) THEN
        Storage.Move( ADR( c4 ), ADDRESS( CARDINAL( SBuffer ) + SPos ), SIZE( c4 )-1 );
        INC( SPos, SIZE( c4 )-1 );
      ELSE
        Storage.Move( ADR( c5 ), ADDRESS( CARDINAL( SBuffer ) + SPos ), SIZE( c5 )-1 );
        INC( SPos, SIZE( c5 )-1 );
        //..
        Strings.ToA( OA( 1023, DataAddOn ), winnls.CP_UTF8, OUT DAddOn );
        l := LENGTH( DAddOn );
        Storage.Move( ADR( DAddOn ), ADDRESS( CARDINAL( SBuffer ) + SPos ), l );
        INC( SPos, l );
        //..
        Storage.Move( ADR( c6 ), ADDRESS( CARDINAL( SBuffer ) + SPos ), SIZE( c6 )-1 );
        INC( SPos, SIZE( c6 )-1 );
      END;
    END;

    IF StopBatch THEN
      Storage.Move( ADR( c7 ), ADDRESS( CARDINAL( SBuffer ) + SPos ), SIZE( c7 )-1 );
      INC( SPos, SIZE( c7 )-1 );
      PCHAR( SBuffer@[SPos] )^ := 0C;
      INC( SPos );

      SUPER.Send( NIL, PConnection, 0, SBuffer, SPos );
      SPos := 0;
    END;
  END SendMMFData;
  
//--------------------------------------------------------------------------------
  
BEGIN
  PAX := NIL;
  RPos := 0;
  RSize := 4096;
  RMax := 65536;
  ALLOCATE( RBuffer, RSize );
  SPos := 0;
  SSize := 8192;
  ALLOCATE( SBuffer, SSize );
END CServer;

//================================================================================

  PUBLIC PROCEDURE Start();
  BEGIN
    IF NOT Listening THEN
      Listening := TRUE;
      netsrv.StartListen( 6006, netsocket.stStream, SRV.Listener, 0, NIL );
    END;
  END Start;

//--------------------------------------------------------------------------------

  PUBLIC PROCEDURE Stop();
  BEGIN
    IF Listening THEN
      Listening := FALSE;
      netsrv.StopListenPort( netsocket.stStream, 6006 );
    END;
  END Stop;

//--------------------------------------------------------------------------------

  PUBLIC PROCEDURE Send( Client : windows.LONG; DataName, DataValue, DataAddOn : wtypes.BSTR );
  BEGIN
    SRV.SendMMFData( netconndispatch.TConnectionHandle( Client ), TRUE, TRUE, DataName, DataValue, DataAddOn );
  END Send;

//--------------------------------------------------------------------------------

  PUBLIC PROCEDURE StartBatch( Client : windows.LONG );
  BEGIN
    BatchClient := netconndispatch.TConnectionHandle( Client );
    SRV.SendMMFData( BatchClient, TRUE, FALSE, NIL, NIL, NIL );
  END StartBatch;

//--------------------------------------------------------------------------------

  PUBLIC PROCEDURE AddToBatch( DataName, DataValue, DataAddOn : wtypes.BSTR );
  BEGIN
    SRV.SendMMFData( BatchClient, FALSE, FALSE, DataName, DataValue, DataAddOn );
  END AddToBatch;

//--------------------------------------------------------------------------------

  PUBLIC PROCEDURE SendBatch();
  BEGIN
    SRV.SendMMFData( BatchClient, FALSE, TRUE, NIL, NIL, NIL );
  END SendBatch;

//--------------------------------------------------------------------------------

  PUBLIC PROCEDURE Disconnect( Client : windows.LONG );
  BEGIN
  END Disconnect;

//--------------------------------------------------------------------------------

BEGIN
  SRV.PAX := ADR( SELF );
  Listening := FALSE;
END CXMLSocket;

//================================================================================
// procedural interface

INITIALLY __I();
BEGIN
  R.LoadRES2( EMITW( %dll ), L'FlashConnector.Texts' );
  R.Lang := Languages.GetDefaultLanguage( Languages.dlUser );
END __I;

//================================================================================

END xmlsocket.