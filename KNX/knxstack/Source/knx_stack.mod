IMPLEMENTATION MODULE knx_stack;

(*# warn( 4006 => off ) *) // exported symbol already defined

(*================================================================================*)
(*/* changes:

 2.06.2005 -- added spare between sending of packet in L layer (SendDelayer)
           -- enhanced A.Timeouter to array of pending operations, in the same manner 
              A.Parameters.Timeout/Delay were enhanced
           -- pendingGroupWrite was originated; Group_WR was established as pending operation to allow
              delay writes (to include a some time between write packets)
           -- PendingCount and A_PendingQueueOverflow and limit was created
           -- added priority queue for A_pending operations
15.03.2005 -- added clearing of osReading into errornenous ValueReadRequestSent -- such request stops reading
 3.02.2005 -- added CKNXStack.SetParameter & CKNXStack.OutputQueueLength
           -- corrected (using tidL_Communicate) error causing stack overflow for
              communications not emptying output queue for a long Time. The correction
              splits Con-Req-Con recursion into Con-MSG||MSG-Req sequention.
 1.02.2005 -- added BUSYDelayer
           -- blocked T_Connect_Ind for Source = Desctination
           -- added acceptation of repeated packet if it is the first found with new data
           -- added CKNXStack.IsSelfPacket
 2.11.2004 -- added LineBusy, TransceiverFault errors and OutputQueueLength parameter
27.10.2004 -- added delays between read operations
17.10.2004 -- L_Data_Ind corrected -- N_Groupdata_Ind should be called if GroupRepeatedAllowed,
              the bad code was: NOT IgnoreGroupRepeated
23.09.2004 -- added Status into ValueUpdated -- this is needed for proper error reporting.
           -- due to previous change removed ValueUpdated from reporting read error --
              modified A_GroupValueRead_Res.
19.09.2004 -- added A_GroupValueProcess removing of pending read if UNACKED CON appears.
              This forced driver to display both UNACK and TIMEOUT error. The correct
              behaviour is the driver displays only the first (UNACK) error.

*/*)
(*================================================================================*)

FROM Debug IMPORT
   AssertionW;

FROM Storage IMPORT
  ALLOCATE, DEALLOCATE;

FROM knx_def IMPORT
  do8, do9, do10, do11, do12, do13, do14, do15, do16, do17, do18, do19, do20, do21;

IMPORT
   datetime,
   msghandler,
   Storage,
   Strings,
   windows;

(*================================================================================*)

CLASS IMPLEMENTATION CKNXStackLayer;

(*--------------------------------------------------------------------------------*)

  INTERNAL VIRTUAL PROCEDURE IsSelf( CONST Address : knx_def.TAddress ) : BOOLEAN;
  BEGIN
    RETURN FALSE;
  END IsSelf;

(*--------------------------------------------------------------------------------*)

  LOCAL VIRTUAL PROCEDURE GetLayerType() : TKNXStackLayerType;
  BEGIN
    RETURN LayerType;
  END GetLayerType;

(*--------------------------------------------------------------------------------*)

  LOCAL VIRTUAL PROCEDURE Freeable() : BOOLEAN;
  BEGIN
    RETURN TRUE;
  END Freeable;

(*--------------------------------------------------------------------------------*)

  LOCAL VIRTUAL PROCEDURE SetExecutive(
          _PExecutive : TPKNXStackLayer
  );
  BEGIN
    IF _PExecutive = NIL THEN
      PExecutive := NIL;
    ELSIF _PExecutive^.GetLayerType() = knxExecutive[ LayerType ] THEN
      PExecutive := _PExecutive;
    ELSE
      PExecutive := NIL;
    END;
  END SetExecutive;

(*--------------------------------------------------------------------------------*)

  LOCAL VIRTUAL PROCEDURE SetListener(
          _PListener : TPKNXStackLayer
  );
  BEGIN
    IF _PListener = NIL THEN
      PListener := NIL;
    ELSIF _PListener^.GetLayerType() = knxListener[ LayerType ] THEN
      PListener := _PListener;
    ELSE
      PListener := NIL;
    END;
  END SetListener;

(*--------------------------------------------------------------------------------*)

  LOCAL VIRTUAL PROCEDURE Initialize_Req();
  BEGIN
    IF PExecutive <> NIL THEN
      PExecutive^.Initialize_Req();
    END;
  END Initialize_Req;

(*--------------------------------------------------------------------------------*)

  LOCAL VIRTUAL PROCEDURE Initialize_Con(
          Status      : knx_status.TKNXStackStatus
  );
  BEGIN
    IF PListener <> NIL THEN
      PListener^.Initialize_Con( Status );
    END;
  END Initialize_Con;

(*--------------------------------------------------------------------------------*)

  LOCAL VIRTUAL PROCEDURE Done_Req();
  BEGIN
    IF PExecutive = NIL THEN
      Done_Con( knx_status.essOK );
    ELSE
      PExecutive^.Done_Req();
    END;
  END Done_Req;

(*--------------------------------------------------------------------------------*)

  LOCAL VIRTUAL PROCEDURE Done_Con(
          Status      : knx_status.TKNXStackStatus
  );
  BEGIN
    IF PListener <> NIL THEN
      PListener^.Done_Con( Status );
    END;
  END Done_Con;

(*--------------------------------------------------------------------------------*)

  LOCAL VIRTUAL PROCEDURE TimeoutUpdated( TimeoutId : TTimeoutId; UserId : LONGWORD );
  BEGIN
  END TimeoutUpdated;

(*--------------------------------------------------------------------------------*)

  LOCAL VIRTUAL PROCEDURE Timeout( TimeoutId : TTimeoutId; UserId : LONGWORD );
  BEGIN
  END Timeout;

(*--------------------------------------------------------------------------------*)

  VIRTUAL FINALLY CKNXStackLayer();
  BEGIN
  END CKNXStackLayer;

(*--------------------------------------------------------------------------------*)

BEGIN
  LayerType := kltAbstract;
  PStack := NIL;
  PExecutive := NIL;
  PListener := NIL;
END CKNXStackLayer;

(*--------------------------------------------------------------------------------*)
(*--------------------------------------------------------------------------------*)

CLASS IMPLEMENTATION CTimeouter;

(*--------------------------------------------------------------------------------*)

  LOCAL PROCEDURE Init( _PLayer : TPKNXStackLayer; _TimeoutId : TTimeoutId; _TimeoutDelay : CARDINAL; _UserId : LONGWORD );
  BEGIN
    PLayer := _PLayer;
    TimeoutId := _TimeoutId;
    TimeoutDelay := _TimeoutDelay;
    UserId := _UserId;
    SUPER.Init( TRUE );
  END Init;

(*--------------------------------------------------------------------------------*)

  INTERNAL VIRTUAL PROCEDURE OnTimer( Timer : PTR );
  BEGIN
    PLayer^.Timeout( TimeoutId, UserId );
  END OnTimer;

(*--------------------------------------------------------------------------------*)

  LOCAL PROCEDURE Start();
  BEGIN
    StartEx( TimeoutId, TimeoutDelay );
  END Start;

(*--------------------------------------------------------------------------------*)

  LOCAL PROCEDURE StartEx( _TimeoutId : TTimeoutId; _TimeoutDelay : CARDINAL );
  VAR
    MSG : msghandler.Message;
  BEGIN
    TimeoutId := _TimeoutId;
    TimeoutDelay := _TimeoutDelay;
    IF _TimeoutDelay = 0 THEN
      MSG.Message := msghandler.MSG_ON_TIMER;
      Message( MSG, msghandler.delAsynchronous, NIL ); // tick over thread loop
    ELSE
      StartTimer( 1, TimeoutDelay, FALSE );
    END;
  END StartEx;

(*--------------------------------------------------------------------------------*)

  LOCAL PROCEDURE Stop();
  BEGIN
    StopTimer( 1 );
  END Stop;

(*--------------------------------------------------------------------------------*)

  LOCAL PROCEDURE Pending() : BOOLEAN;
  BEGIN
    RETURN TimerRunning( 1 );
  END Pending;

(*--------------------------------------------------------------------------------*)

BEGIN
  PLayer := NIL;
  TimeoutDelay := 50; // msec, overwritten in L_Layer init
  TimeoutId := tidU_Unknown;
  UserId := 0;
FINALLY
  Stop();
END CTimeouter;

(*================================================================================*)

CLASS IMPLEMENTATION CKNXStackPhysicalLayer;

(*--------------------------------------------------------------------------------*)

  LOCAL VIRTUAL PROCEDURE Initialize_Req();
  BEGIN
    Ph_Reset_Req();
    SUPER.Initialize_Req();
  END Initialize_Req;

(*--------------------------------------------------------------------------------*)

  PUBLIC PROCEDURE Listener() : TPKNXStackLinkLayer;
  BEGIN
    RETURN TPKNXStackLinkLayer( PListener );
  END Listener;

(*--------------------------------------------------------------------------------*)

  PUBLIC VIRTUAL PROCEDURE Ph_Reset_Req();
  BEGIN
  END Ph_Reset_Req;

(*--------------------------------------------------------------------------------*)

  PUBLIC VIRTUAL PROCEDURE Ph_Reset_Con(
  );
  BEGIN
    // Status : knx_status.TKNXStackStatus is generated inside
    Initialize_Con( knx_status.essOK );
  END Ph_Reset_Con;

(*--------------------------------------------------------------------------------*)

  PUBLIC VIRTUAL PROCEDURE Ph_Data_Req(
      VAR Packet      : knx_def.TPacket
  );
  BEGIN
  END Ph_Data_Req;

(*--------------------------------------------------------------------------------*)

  PUBLIC PROCEDURE Ph_Data_Sent( // extension, from the call LinkLayer starts to count timeouts, this is handshake/ACK to Ph_Data_Req
  );
  BEGIN
     Listener()^.Ph_Data_Sent();
  END Ph_Data_Sent;

(*--------------------------------------------------------------------------------*)

  PUBLIC VIRTUAL PROCEDURE Ph_Data_Ind(
  );
  BEGIN
    // there should be something like: Listener()^.Ph_Data_Ind( PPacket );
  END Ph_Data_Ind;

(*--------------------------------------------------------------------------------*)

  PUBLIC VIRTUAL PROCEDURE Ph_Data_Con(
  );
  BEGIN
    // there should be something like: Listener()^.Ph_Data_Con( Status );
  END Ph_Data_Con;

(*--------------------------------------------------------------------------------*)

BEGIN
  LayerType := kltPhysical;
END CKNXStackPhysicalLayer;

(*================================================================================*)

TYPE
  TPL_Request = POINTER TO CL_Request;

CLASS CL_Request( list.CListElem );
  PListener  : TPL_Data_Listener;
  Packet     : knx_def.TPacket; // packet assembled to send
  NAK_Retry  : CARDINAL;
  BUSY_Retry : CARDINAL;
  Pending    : BOOLEAN;
END CL_Request;

(*--------------------------------------------------------------------------------*)

CLASS IMPLEMENTATION CL_Request;
BEGIN
  PListener := NIL;
  Storage.Zero( ADR( Packet ), SIZE( Packet ));
  NAK_Retry := 0;
  BUSY_Retry := 0;
  Pending := FALSE;
END CL_Request;

(*--------------------------------------------------------------------------------*)

CLASS IMPLEMENTATION CL_Request_Queue;

(*--------------------------------------------------------------------------------*)

  LOCAL PROCEDURE Init( _PDistribution : TPPriorityDistribution );
  BEGIN
    PDistribution := _PDistribution;
  END Init;

(*--------------------------------------------------------------------------------*)

  LOCAL PROCEDURE Done();
  VAR
    Priority : knx_def.TPriority;
  BEGIN
    Priority := knx_def.priorityLowest;
    LOOP
      Requests[ Priority ].Dispose();
      IF Priority = knx_def.priorityHighest THEN
        EXIT;
      ELSE
        INC( Priority );
      END;
    END; // FOR
  END Done;

(*--------------------------------------------------------------------------------*)

  LOCAL PROCEDURE AppendPacket(
          PListener  : TPL_Data_Listener;
          PPacket    : knx_def.TPPacket;
          NAK_Retry  : CARDINAL;
          BUSY_Retry : CARDINAL
  );
  VAR
    PE : TPL_Request;
  BEGIN
    NEW( PE );
    PE^.PListener := PListener;
    PE^.Packet := PPacket^;
    PE^.NAK_Retry := NAK_Retry;
    PE^.BUSY_Retry := BUSY_Retry;
    PE^.Pending := FALSE;

    Requests[ PPacket^.GetPriority() ].Enqueue( PE );
  END AppendPacket;

(*--------------------------------------------------------------------------------*)

  LOCAL PROCEDURE GetActiveRequest(
      VAR PListener : TPL_Data_Listener;
      VAR Packet    : knx_def.TPacket;
      VAR Pending   : BOOLEAN
  ) : BOOLEAN; // gets top packet
  BEGIN
    IF ( PCurrent = NIL ) AND NOT GetPacketToSend( Packet, Pending ) THEN
      RETURN FALSE;
    ELSIF PCurrent = NIL THEN // PCurrent could not be set after GetPacketToSend
      ASSERT( FALSE );
      RETURN FALSE;
    ELSE
      PListener := TPL_Request( PCurrent )^.PListener;
      Packet := TPL_Request( PCurrent )^.Packet;
      Pending := TPL_Request( PCurrent )^.Pending;
      RETURN TRUE;
    END;
  END GetActiveRequest;

(*--------------------------------------------------------------------------------*)

  LOCAL PROCEDURE GetPacketToSend(
      VAR Packet  : knx_def.TPacket;
      VAR Pending : BOOLEAN
  ) : BOOLEAN; // gets top packet
  LABEL
    Found;
  VAR
    PE : TPL_Request;
    Priority : knx_def.TPriority;
  BEGIN
    IF PCurrent <> NIL THEN
      Packet := TPL_Request( PCurrent )^.Packet;
      Pending := TPL_Request( PCurrent )^.Pending;
      TPL_Request( PCurrent )^.Pending := TRUE;
      RETURN TRUE;
    END;
    Priority := knx_def.priorityHighest;

    LOOP
      IF Requests[ Priority ].Empty THEN
        // pass down to lower priority
      ELSIF PDistribution^[ Priority ] = -1 THEN
        GOTO Found;
      ELSIF Counts[ Priority ] >= PDistribution^[ Priority ] THEN
        Counts[ Priority ] := 0; // reset
      ELSE
        INC( Counts[ Priority ] );
        GOTO Found;
      END;
      IF Priority = knx_def.priorityLowest THEN
        EXIT;
      ELSE
        DEC( Priority );
      END;
    END; // LOOP

    RETURN FALSE;

  Found:
    Requests[ Priority ].colGetFirst( OUT PE );
    PCurrent := PE;
    Packet := TPL_Request( PCurrent )^.Packet;
    Pending := FALSE;
    TPL_Request( PCurrent )^.Pending := TRUE;

    RETURN TRUE;
  END GetPacketToSend;

(*--------------------------------------------------------------------------------*)

  LOCAL PROCEDURE PacketSent(
          Status    : knx_status.TKNXStackStatus
  ) : knx_status.TKNXStackStatus; // removes packet from queue
  LABEL
    Remove;
  VAR
    Priority : knx_def.TPriority;
  BEGIN
    IF PCurrent = NIL THEN
      RETURN knx_status.essOK;
    END;
    Priority := TPL_Request( PCurrent )^.Packet.GetPriority();

    IF Status = knx_status.essOK THEN
      GOTO Remove;
    ELSIF Status = knx_status.essConError THEN
      IF TPL_Request( PCurrent )^.NAK_Retry = 0 THEN
        GOTO Remove;
      ELSE
        DEC( TPL_Request( PCurrent )^.NAK_Retry );
        TPL_Request( PCurrent )^.Pending := FALSE;
      END;
    ELSE // ELSIF Status = knx_status.essTransceiverFault THEN and any other error
      IF TPL_Request( PCurrent )^.BUSY_Retry = 0 THEN
        GOTO Remove;
      ELSE
        DEC( TPL_Request( PCurrent )^.BUSY_Retry );
        TPL_Request( PCurrent )^.Pending := FALSE;
      END;
    END;
    RETURN Status;

  Remove:
    Requests[ Priority ].Delete( PCurrent );
    PCurrent := NIL;
    RETURN knx_status.essOK;
  END PacketSent;

(*--------------------------------------------------------------------------------*)

  LOCAL PROCEDURE PacketsPending() : CARDINAL;
  VAR
    c : CARDINAL;
    Priority : knx_def.TPriority;
  BEGIN
    c := 0;
    Priority := knx_def.priorityHighest;
    LOOP
      c := c + Requests[ Priority ].Count;
      IF Priority = knx_def.priorityLowest THEN
        EXIT;
      ELSE
        DEC( Priority );
      END;
    END; // LOOP
    RETURN c;
  END PacketsPending;

(*--------------------------------------------------------------------------------*)

BEGIN
  PDistribution := NIL;
  Storage.Zero( ADR( Counts ), SIZE( Counts ));
  PCurrent := NIL;
END CL_Request_Queue;

(*--------------------------------------------------------------------------------*)
(*--------------------------------------------------------------------------------*)

CLASS IMPLEMENTATION CL_Data_Listener;

(*--------------------------------------------------------------------------------*)

  LOCAL VIRTUAL PROCEDURE Freeable() : BOOLEAN;
  BEGIN
    RETURN TRUE;
  END Freeable;

(*--------------------------------------------------------------------------------*)

  LOCAL VIRTUAL PROCEDURE Done();
  BEGIN
  END Done;

(*--------------------------------------------------------------------------------*)

  LOCAL VIRTUAL PROCEDURE GetGroups( VAR Groups : TGroupInfo );
  BEGIN
    Groups := TGroupInfo{};
  END GetGroups;

(*--------------------------------------------------------------------------------*)

  LOCAL VIRTUAL PROCEDURE GroupsUpdated();
  BEGIN
    PExecutive^.ListenerGroupUpdated( ADR( SELF ));
  END GroupsUpdated;

(*--------------------------------------------------------------------------------*)

  LOCAL VIRTUAL PROCEDURE L_Data_Req(
          Destination : knx_def.TAddress; // physical or group
          Class       : knx_def.TPriority;
      VAR Packet      : knx_def.TPacket
  );
  BEGIN
    PExecutive^.L_Data_Req( ADR( SELF ), Destination, Class, Packet );
  END L_Data_Req;

(*--------------------------------------------------------------------------------*)

  LOCAL PROCEDURE Communicate( RequestType : TCommunicateRequestType );
  BEGIN
    PExecutive^.Communicate( RequestType );
  END Communicate;

(*--------------------------------------------------------------------------------*)

  LOCAL VIRTUAL PROCEDURE L_Data_Con(
          Status      : knx_status.TKNXStackStatus;
          Destination : knx_def.TAddress; // physical or group
          PPacket     : knx_def.TPPacket
  );
  BEGIN
  END L_Data_Con;

(*--------------------------------------------------------------------------------*)

  LOCAL VIRTUAL PROCEDURE L_Data_Ind(
          Source      : knx_def.TAddress; // physical
          Destination : knx_def.TAddress; // physical or group
          Class       : knx_def.TPriority;
          PPacket     : knx_def.TPPacket
  );
  BEGIN
  END L_Data_Ind;

(*--------------------------------------------------------------------------------*)

BEGIN
  PExecutive := NIL;
END CL_Data_Listener;

(*--------------------------------------------------------------------------------*)
(*--------------------------------------------------------------------------------*)

CLASS IMPLEMENTATION CKNXStackLinkLayer;

(*--------------------------------------------------------------------------------*)

  INTERNAL VIRTUAL PROCEDURE IsSelf( CONST Address : knx_def.TAddress ) : BOOLEAN;
  BEGIN
    RETURN L_Parameters.SelfAddress.Equals( Address );
  END IsSelf;

(*--------------------------------------------------------------------------------*)

  LOCAL PROCEDURE IsSelfPacket( PPacket : knx_def.TPPacket ) : BOOLEAN;
  VAR
    Address : knx_def.TAddress;
  BEGIN
    Address := PPacket^.GetSourceAddress();
    RETURN IsSelf( Address );
  END IsSelfPacket;

(*--------------------------------------------------------------------------------*)

  PRIVATE PROCEDURE Executive() : TPKNXStackPhysicalLayer;
  BEGIN
    RETURN TPKNXStackPhysicalLayer( PExecutive );
  END Executive;

(*--------------------------------------------------------------------------------*)

  PRIVATE PROCEDURE Listener() : TPKNXStackLayer;
  BEGIN
    RETURN NIL;
  END Listener;

(*--------------------------------------------------------------------------------*)

  LOCAL VIRTUAL PROCEDURE Initialize_Req();
  BEGIN
    ASSERT( L_Data.State <> lsWaitResetCon );
    L_Data.State := lsWaitResetCon;

    L_Data.Queue.Init( ADR( L_Parameters.PriorityDistribution ));

    SUPER.Initialize_Req();
  END Initialize_Req;

(*--------------------------------------------------------------------------------*)

  LOCAL VIRTUAL PROCEDURE Initialize_Con(
          Status      : knx_status.TKNXStackStatus
  );
  BEGIN // now, initialized
    ASSERT( L_Data.State = lsWaitResetCon );
    IF Status = knx_status.essOK THEN
      L_Data.State := lsNormalIdle;
    ELSE
      L_Data.State := lsStop;
      PStack^.OnError( LayerType, Status );
    END;
  END Initialize_Con;

(*--------------------------------------------------------------------------------*)

  LOCAL VIRTUAL PROCEDURE Done_Con(
          Status      : knx_status.TKNXStackStatus
  );
  BEGIN
    L_Data.Queue.Done();
    L_Data.ACKTimeouter.Stop();
    L_Data.BUSYDelayer.Stop();
    L_Data.SendDelayer.Stop();
    L_Data.Listeners.Dispose();
    SUPER.Done_Con( Status );
  END Done_Con;

(*--------------------------------------------------------------------------------*)

  LOCAL VIRTUAL PROCEDURE TimeoutUpdated( TimeoutId : TTimeoutId; UserId : LONGWORD );
  BEGIN
    CASE TimeoutId OF
    //-----
    | tidL_ACKTimeout :
      L_Data.ACKTimeouter.TimeoutDelay := L_Parameters.ACKTimeout;
    //-----
    | tidL_BUSYDelay :
      L_Data.BUSYDelayer.TimeoutDelay := L_Parameters.BUSYDelay;
    //-----
    | tidL_SendDelay :
      L_Data.SendDelayer.TimeoutDelay := L_Parameters.SendDelay;
    END; // CASE
  END TimeoutUpdated;

(*--------------------------------------------------------------------------------*)

  LOCAL VIRTUAL PROCEDURE Timeout( TimeoutId : TTimeoutId; UserId : LONGWORD );
  BEGIN
    CASE TimeoutId OF
    //-----
    | tidL_Communicate :
      Communicate( crtL_LayerContinueAfterCon2 );

    //-----
    | tidL_ACKTimeout :
      Ph_Data_Con( knx_status.essL_Timeout );

    //-----
    | tidL_BUSYDelay :
      Communicate( crtL_LayerAfterBUSYDelay );

    //-----
    | tidL_SendDelay :
      Communicate( crtL_LayerAfterSendDelay );

    END; // CASE
  END Timeout;

(*--------------------------------------------------------------------------------*)

  LOCAL PROCEDURE RegisterListener( PListener : TPL_Data_Listener );
  VAR
    ListenerGroups : TGroupInfo;
  BEGIN
    IF L_Data.Listeners.Contains( PListener ) THEN
      RETURN;
    END;
    L_Data.Listeners.Add( PListener );

    PListener^.PExecutive := ADR( SELF );
    PListener^.GetGroups( ListenerGroups );
    L_Data.Groups := L_Data.Groups + ListenerGroups;
  END RegisterListener;

(*--------------------------------------------------------------------------------*)

  LOCAL PROCEDURE ForgetListener( PListener : TPL_Data_Listener );
  VAR
    ListenerGroups : TGroupInfo;
  BEGIN
    IF NOT L_Data.Listeners.Contains( PListener ) THEN
      RETURN;
    END;
    L_Data.Listeners.Remove( PListener );
    L_Data.Groups := TGroupInfo{};
    IF NOT L_Data.Listeners.colGetFirst( OUT PListener ) THEN
      RETURN;
    END;
    REPEAT
      PListener^.GetGroups( ListenerGroups );
      L_Data.Groups := L_Data.Groups + ListenerGroups;
    UNTIL NOT L_Data.Listeners.colNextOf( PListener, OUT PListener );
  END ForgetListener;

(*--------------------------------------------------------------------------------*)

  LOCAL PROCEDURE ListenerGroupUpdated( PListener : TPL_Data_Listener );
  VAR
    ListenerGroups : TGroupInfo;
  BEGIN
    IF NOT L_Data.Listeners.Contains( PListener ) THEN
      RETURN;
    END;
    L_Data.Groups := TGroupInfo{};
    IF NOT L_Data.Listeners.colGetFirst( OUT PListener ) THEN
      RETURN;
    END;
    REPEAT
      PListener^.GetGroups( ListenerGroups );
      L_Data.Groups := L_Data.Groups + ListenerGroups;
    UNTIL NOT L_Data.Listeners.colNextOf( PListener, OUT PListener );
  END ListenerGroupUpdated;

(*--------------------------------------------------------------------------------*)

  PUBLIC PROCEDURE Ph_Data_Sent( // extension, from the call LinkLayer starts to count timeouts, this is handshake/ACK to Ph_Data_Req
  );
  BEGIN
     L_Data.ACKTimeouter.Start();
     L_Data.LastSend := datetime.UptimeMS();
  END Ph_Data_Sent;

(*--------------------------------------------------------------------------------*)

  PUBLIC PROCEDURE Ph_Data_Ind(
          PPacket      : knx_def.TPPacket
  );
  VAR
    Destination : knx_def.TAddress;
    Addressed : BOOLEAN;
  BEGIN
    IF L_Parameters.LinkMode = lmBusMonitor THEN
      L_Busmonitor_Ind( knx_status.essOK, datetime.UptimeMS64(), PPacket );
      RETURN;
    ELSIF IsSelfPacket( PPacket ) THEN
      L_Service_Information_Ind();
      RETURN;
    END;
    // now LinkMode = lmNormal
    
    // CHECK ADDRESS
    Destination := PPacket^.GetDestinationAddress();
    IF NOT L_Parameters.CheckAddressed THEN
      // assume I AM Addressed, as the lower layer check this
      Addressed := TRUE;
    ELSIF Destination.GetAddressType() = knx_def.addressPhysical THEN
      Addressed := IsSelf( Destination );
    ELSIF Destination.IsBroadcast() THEN
      Addressed := TRUE;
    ELSE // if all addrknx_status.esses are checked in device L_Data.Groups contains 
      Addressed := CARD16( Destination.GetGroupAddress1()) IN L_Data.Groups;
    END;

    // CHECK STATE AND PACKET
    IF NOT Addressed THEN
      L_Data_Ind_Res( larNOT_MINE );
      RETURN;
    ELSIF ssBusy IN PStack^.Status THEN // BUSY must be generated
      L_Data_Ind_Res( larBUSY );
      RETURN;
    ELSIF NOT L_Parameters.LL_ACK_and_ChkSum THEN // OK, checks are done in lower layer
      // pass on
    ELSIF PPacket^.ValidCheckSum() THEN // ACK must be generated
      L_Data_Ind_Res( larACK );
    ELSE
      L_Data_Ind_Res( larNAK );
      RETURN; // not to procknx_status.ess
    END;

    // pass to higer lever
    Process_L_Data_Ind(  
      PPacket^.GetSourceAddress(),
      PPacket^.GetDestinationAddress(),
      PPacket^.GetPriority(),
      PPacket
    );
  END Ph_Data_Ind;

(*--------------------------------------------------------------------------------*)

  PUBLIC PROCEDURE Ph_Data_Con(
          Status      : knx_status.TKNXStackStatus
  );
  VAR
    CRT : TCommunicateRequestType;
    LPacket : knx_def.TPacket;
    PListener : TPL_Data_Listener;
    Pending : BOOLEAN;
  BEGIN
    IF L_Parameters.SendDelay = 0 THEN
      CRT := crtL_LayerContinueAfterCon1;
    ELSE
      CRT := crtL_LayerWithSendDelay;
    END;

    IF L_Data.Queue.GetActiveRequest( PListener, LPacket, Pending ) AND Pending THEN
      L_Data.ACKTimeouter.Stop();
      L_Data.BUSYDelayer.Stop();
      // notify higher level only if packet is removed -- so only if it is NOT retransmitted
      IF L_Data.Queue.PacketSent( Status ) <> knx_status.essOK THEN // retransmit after some delay
        CRT := crtL_LayerWithBUSYDelay;
      ELSE
        L_Data_Con( PListener, Status, LPacket.GetDestinationAddress(), ADR( LPacket ));
      END;
    END; // IF

    Communicate( CRT );
  END Ph_Data_Con;

(*--------------------------------------------------------------------------------*)

  PUBLIC VIRTUAL PROCEDURE L_Data_Ind_Res( // EXTENSION
          AcceptResponse : TL_AcceptResponse
  );
  BEGIN
  END L_Data_Ind_Res;

(*--------------------------------------------------------------------------------*)

  LOCAL VIRTUAL PROCEDURE L_Data_Req(
          _PListener  : TPL_Data_Listener;
          Destination : knx_def.TAddress; // physical or group
          Class       : knx_def.TPriority;
      VAR Packet      : knx_def.TPacket
  );
  BEGIN
    Packet.SetPriority( Class );
    Packet.SetSourceAddress( L_Parameters.SelfAddress );
    Packet.SetDestinationAddress( Destination );

    IF ( L_Parameters.OutputQueueLength = 0 ) OR ( L_Parameters.OutputQueueLength = MAX( CARDINAL )) THEN
      L_Data.Queue.AppendPacket( _PListener, ADR( Packet ), L_Parameters.NAK_Retry, L_Parameters.BUSY_Retry );
    ELSIF L_Data.Queue.PacketsPending() < L_Parameters.OutputQueueLength THEN
      L_Data.Queue.AppendPacket( _PListener, ADR( Packet ), L_Parameters.NAK_Retry, L_Parameters.BUSY_Retry );
    ELSE
      L_Data_Con( _PListener, knx_status.essL_OutputQueueOverflow, Destination, ADR( Packet ));
    END;
  END L_Data_Req;

(*--------------------------------------------------------------------------------*)

  LOCAL VIRTUAL PROCEDURE Communicate( RequestType : TCommunicateRequestType );
  VAR
    delay : CARDINAL;
    Packet : knx_def.TPacket;
    Pending : BOOLEAN;
    Send : BOOLEAN;
  BEGIN
    Send := FALSE;
    // direct stack variant
    IF L_Data.Queue.GetPacketToSend( Packet, Pending ) THEN

      CASE RequestType OF
      | crtN_LayerRequest :
        IF Pending THEN
          // do not send packet again
        ELSIF L_Parameters.SendDelay = 0 THEN
          Send := TRUE;
        ELSE
          delay := datetime.UptimeMS() - L_Data.LastSend;
          IF L_Data.SendDelayer.Pending() THEN
            Send := FALSE;
            // do not send packet now as SendDelay is pending and send will continue after its elapsing
          ELSIF delay >= L_Parameters.SendDelay THEN
            Send := TRUE; // immediately send 
          ELSE // wait for elapsing rest time
            L_Data.SendDelayer.StartEx( tidL_SendDelay, delay + 1 ); // delay is rest of time
          END;
        END;
      | crtL_LayerContinueAfterCon1 :
        L_Data.SendDelayer.StartEx( tidL_Communicate, 0 ); // send next packed after a minimal delay to cut-off recursive Req/Con/Req calls during continuous writting
      | crtL_LayerContinueAfterCon2 :
        Send := TRUE;
      | crtL_LayerWithBUSYDelay :
        L_Data.BUSYDelayer.Start();
      | crtL_LayerAfterBUSYDelay :
        L_Data.BUSYDelayer.Stop();
        Send := TRUE;
      | crtL_LayerWithSendDelay :
        L_Data.SendDelayer.StartEx( tidL_SendDelay, L_Parameters.SendDelay );
      | crtL_LayerAfterSendDelay :
        L_Data.SendDelayer.Stop();
        Send := TRUE;
      ELSE
        ASSERT( FALSE );
      END;

      IF Send THEN
        // no timeout setup, all is done inside Ph_Data_Sent
        Executive()^.Ph_Data_Req( Packet );
      END;

    END;
  END Communicate;

(*--------------------------------------------------------------------------------*)

  INTERNAL VIRTUAL PROCEDURE L_Data_Con(
          PListener   : TPL_Data_Listener;
          Status      : knx_status.TKNXStackStatus;
          Destination : knx_def.TAddress; // physical or group
          PPacket     : knx_def.TPPacket
  );
  BEGIN
    PListener^.L_Data_Con( Status, PPacket^.GetDestinationAddress(), PPacket );
  END L_Data_Con;

(*--------------------------------------------------------------------------------*)

  PRIVATE PROCEDURE Process_L_Data_Ind(
          Source      : knx_def.TAddress; // physical
          Destination : knx_def.TAddress; // physical or group
          Class       : knx_def.TPriority;
          PPacket     : knx_def.TPPacket
  );
  VAR
    PListener : TPL_Data_Listener;
    b : BOOLEAN;
  BEGIN
    b := L_Data.Listeners.colGetFirst( OUT PListener );
    WHILE b DO
      L_Data_Ind( PListener, PPacket^.GetSourceAddress(), PPacket^.GetDestinationAddress(), PPacket^.GetPriority(), PPacket );
      b := L_Data.Listeners.colNextOf( PListener, OUT PListener );
    END; // WHILE
  END Process_L_Data_Ind;

(*--------------------------------------------------------------------------------*)

  VIRTUAL PROCEDURE L_Data_Ind(
          PListener   : TPL_Data_Listener;
          Source      : knx_def.TAddress; // physical
          Destination : knx_def.TAddress; // physical or group
          Class       : knx_def.TPriority;
          PPacket     : knx_def.TPPacket
  );
  BEGIN
    PListener^.L_Data_Ind( Source, Destination, Class, PPacket );
  END L_Data_Ind;

(*--------------------------------------------------------------------------------*)

  // :: service poll data
  // PROCEDURE L_Poll_Data$Req
  // VIRTUAL PROCEDURE L_Poll_Data$Con
  // PROCEDURE L_Poll_Data_Update$Req
  // VIRTUAL PROCEDURE L_Poll_Data_Update$Con

(*--------------------------------------------------------------------------------*)

  VIRTUAL PROCEDURE L_Busmonitor_Ind(
          Status      : knx_status.TKNXStackStatus;
          Time        : INT64;
          PPacket     : knx_def.TPPacket
  );
  BEGIN
  END L_Busmonitor_Ind;

(*--------------------------------------------------------------------------------*)

  VIRTUAL PROCEDURE L_Service_Information_Ind();
  BEGIN
  END L_Service_Information_Ind;

(*--------------------------------------------------------------------------------*)

BEGIN
  LayerType := kltLink;

  L_Parameters.LinkMode := lmNormal;
  L_Parameters.NAK_Retry := 3;
  L_Parameters.BUSY_Retry := 3;
  L_Parameters.PollResponseSlot := 0;
  L_Parameters.PriorityDistribution := defaultPriorityDistribution;
  L_Parameters.ACKTimeout := 500;
  L_Parameters.BUSYDelay := 200;
  L_Parameters.SendDelay := 0;
  L_Parameters.CheckAddressed := TRUE;
  L_Parameters.LL_ACK_and_ChkSum := FALSE;
  L_Parameters.OutputQueueLength := 0;

  L_Data.State := lsStop;
  Storage.Zero( ADR( L_Data.Groups ), SIZE( L_Data.Groups ));
  L_Data.ACKTimeouter.Init( ADR( SELF ), tidL_ACKTimeout, L_Parameters.ACKTimeout, 0 );
  L_Data.BUSYDelayer.Init( ADR( SELF ), tidL_BUSYDelay, L_Parameters.BUSYDelay, 0 );
  L_Data.SendDelayer.Init( ADR( SELF ), tidL_SendDelay, L_Parameters.SendDelay, 0 );
END CKNXStackLinkLayer;

(*================================================================================*)

CLASS IMPLEMENTATION CRoutingTable;

(*--------------------------------------------------------------------------------*)

  LOCAL VIRTUAL PROCEDURE EnumerateTargets( VAR EnumerateState : PTR; CONST Destination : knx_def.TAddress; VAR PInterface : TPKNXStackLinkLayer ) : BOOLEAN;
  BEGIN
    RETURN FALSE;
  END EnumerateTargets;

(*--------------------------------------------------------------------------------*)

BEGIN
END CRoutingTable;

(*--------------------------------------------------------------------------------*)
(*--------------------------------------------------------------------------------*)

CLASS IMPLEMENTATION CN_L_Data_Listener;

(*--------------------------------------------------------------------------------*)

  LOCAL VIRTUAL PROCEDURE GetGroups( VAR Groups : TGroupInfo );
  BEGIN
    Groups := PListener^.N_Data.Groups;
  END GetGroups;

(*--------------------------------------------------------------------------------*)

  LOCAL PROCEDURE AddGroup( CONST Address : knx_def.TAddress );
  BEGIN
    INCL( PListener^.N_Data.Groups, CARD16( Address.GetGroupAddress1()) );
  END AddGroup;

(*--------------------------------------------------------------------------------*)

  LOCAL PROCEDURE RemoveGroup( CONST Address : knx_def.TAddress );
  BEGIN
    EXCL( PListener^.N_Data.Groups, CARD16( Address.GetGroupAddress1()) );
  END RemoveGroup;

(*--------------------------------------------------------------------------------*)

  LOCAL VIRTUAL PROCEDURE L_Data_Con(
          Status      : knx_status.TKNXStackStatus;
          Destination : knx_def.TAddress; // physical or group
          PPacket     : knx_def.TPPacket
  );
  BEGIN
    PListener^.L_Data_Con( Status, Destination, PPacket );
  END L_Data_Con;

(*--------------------------------------------------------------------------------*)

  LOCAL VIRTUAL PROCEDURE L_Data_Ind(
          Source      : knx_def.TAddress; // physical
          Destination : knx_def.TAddress; // physical or group
          Class       : knx_def.TPriority;
          PPacket     : knx_def.TPPacket
  );
  BEGIN
    PListener^.L_Data_Ind( Source, Destination, Class, PPacket );
  END L_Data_Ind;

(*--------------------------------------------------------------------------------*)

BEGIN
  PListener := NIL;
END CN_L_Data_Listener;

(*--------------------------------------------------------------------------------*)
(*--------------------------------------------------------------------------------*)

CLASS IMPLEMENTATION CKNXStackNetworkLayer;

(*--------------------------------------------------------------------------------*)

  PRIVATE PROCEDURE Executive() : TPL_Data_Listener;
  BEGIN
    RETURN N_Data.PL_Listener;
  END Executive;

(*--------------------------------------------------------------------------------*)

  PRIVATE PROCEDURE Listener() : TPKNXStackTransportLayer;
  BEGIN
    RETURN TPKNXStackTransportLayer( PListener );
  END Listener;

(*--------------------------------------------------------------------------------*)

  LOCAL VIRTUAL PROCEDURE Initialize_Req();
  VAR
    PL_Data_Listener : TPL_Data_Listener;
  BEGIN
    IF N_Data.PL_Listener = NIL THEN // not initialized yet
      IF NOT PStack^.CreateL_Data_Listener( PL_Data_Listener ) THEN
        NEW( TPN_L_Data_Listener( PL_Data_Listener ));
        TPN_L_Data_Listener( PL_Data_Listener )^.PListener := ADR( SELF );
      END;
      N_Data.PL_Listener := PL_Data_Listener;
      TPKNXStackLinkLayer( PExecutive )^.RegisterListener( PL_Data_Listener );
    END;
    SUPER.Initialize_Req();
  END Initialize_Req;

(*--------------------------------------------------------------------------------*)

  LOCAL VIRTUAL PROCEDURE Done_Req();
  BEGIN
    IF N_Data.PL_Listener <> NIL THEN
      TPKNXStackLinkLayer( PExecutive )^.ForgetListener( N_Data.PL_Listener );
    END;
    SUPER.Done_Req();
  END Done_Req;

(*--------------------------------------------------------------------------------*)

  LOCAL VIRTUAL PROCEDURE Done_Con(
          Status      : knx_status.TKNXStackStatus
  );
  BEGIN
    IF N_Data.PL_Listener <> NIL THEN
      N_Data.PL_Listener^.Done();
      IF N_Data.PL_Listener^.Freeable() THEN
        DISPOSE( N_Data.PL_Listener );
      ELSE
        N_Data.PL_Listener := NIL;
      END;
    END;
    SUPER.Done_Con( Status );
  END Done_Con;

(*--------------------------------------------------------------------------------*)

  LOCAL PROCEDURE L_Data_Con(
          Status      : knx_status.TKNXStackStatus;
          Destination : knx_def.TAddress; // physical or group
          PPacket     : knx_def.TPPacket
  );
  BEGIN
    IF Destination.GetAddressType() = knx_def.addressPhysical THEN
      N_Data_Con( Status, Destination, PPacket );
    ELSIF Destination.IsBroadcast() THEN
      N_Broadcast_Con( Status );
    ELSE
      N_Groupdata_Con( Status, Destination, PPacket );
    END;
  END L_Data_Con;

(*--------------------------------------------------------------------------------*)

  LOCAL PROCEDURE L_Data_Ind(
          Source      : knx_def.TAddress; // physical
          Destination : knx_def.TAddress; // physical or group
          Class       : knx_def.TPriority;
          PPacket     : knx_def.TPPacket
  );
  LABEL
    EndDevice;
  VAR
    ES : PTR;
    LPacket : knx_def.TPacket;
    PInterface : TPKNXStackLinkLayer;
    RoutingCounter : CARDINAL;
  BEGIN
    CASE N_Parameters.DeviceType OF
    //----------
    | ndtEndDevice :
    EndDevice:
      IF Destination.GetAddressType() = knx_def.addressPhysical THEN
        N_Data_Ind( Source, Destination, Class, PPacket );

      ELSIF Destination.IsBroadcast() THEN
        N_Broadcast_Ind( Source, Class, PPacket );

      ELSIF N_Parameters.GroupRepeatedAllowed OR NOT PPacket^.GetRepeated() THEN
        N_Data.LastGroupPacket := PPacket^;
        N_Data.LastGroupPacket.SetRepeated( FALSE );
        // 1. NOT repeated or unfiltered
        N_Groupdata_Ind( Source, Destination, Class, PPacket );

      // check if received packet, EVEN IF IT IS REPEATED, differs from last received one -- it can be
      // the first packet with this data received from physical layer and such packet must be accepted
      ELSE
        LPacket := PPacket^;
        LPacket.SetRepeated( FALSE );
        IF N_Data.LastGroupPacket <> LPacket THEN // not known packet...
          N_Data.LastGroupPacket := LPacket;
          // 2. REPEATED
          N_Groupdata_Ind( Source, Destination, Class, PPacket );
        END;
      END;
    //----------
    | ndtBridge, ndtRouter :
      IF IsSelf( Destination ) THEN // self addrknx_status.ess is always physical, act as normal end device
        GOTO EndDevice;
      END;

      RoutingCounter := PPacket^.GetRoutingCounter();
      IF RoutingCounter = knx_def.ncRouteDiscard THEN // discard packet
        OnPacketDiscard( PPacket );
        RETURN;
      ELSIF RoutingCounter <> knx_def.ncRoutePassOn THEN
        DEC( RoutingCounter );
      END;

      // forward data to any other interfaces
      LPacket := PPacket^;
      LPacket.SetRoutingCounter( RoutingCounter );
      ES := 0;
      WHILE N_Parameters.PRoutingTable^.EnumerateTargets( ES, Destination, PInterface ) DO
        PInterface^.L_Data_Req( NIL, Destination, Class, LPacket );
      END; // WHILE
    END; // CASE
  END L_Data_Ind;

(*--------------------------------------------------------------------------------*)

  LOCAL VIRTUAL PROCEDURE N_Data_Req(
          Destination    : knx_def.TAddress; // physical
          Class          : knx_def.TPriority;
      VAR Packet         : knx_def.TPacket
  );
  BEGIN
    Packet.SetRoutingCounter( knx_def.ncRouteDefault );
    Executive()^.L_Data_Req( Destination, Class, Packet );
    Executive()^.Communicate( crtN_LayerRequest ); // start communication always
  END N_Data_Req;

(*--------------------------------------------------------------------------------*)

  VIRTUAL PROCEDURE N_Data_Con(
          Status      : knx_status.TKNXStackStatus;
          Destination : knx_def.TAddress; // physical
          PPacket     : knx_def.TPPacket
  );
  BEGIN
    Listener()^.N_Data_Con( Status, Destination, PPacket );
  END N_Data_Con;

(*--------------------------------------------------------------------------------*)

  VIRTUAL PROCEDURE N_Data_Ind(
          Source      : knx_def.TAddress; // physical
          Destination : knx_def.TAddress; // physical, self
          Class       : knx_def.TPriority;
          PPacket     : knx_def.TPPacket
  );
  BEGIN
    Listener()^.N_Data_Ind( Source, Destination, Class, PPacket );
  END N_Data_Ind;

(*--------------------------------------------------------------------------------*)

  LOCAL VIRTUAL PROCEDURE N_Groupdata_Req(
          Destination    : knx_def.TAddress; // logical
          Class          : knx_def.TPriority;
      VAR Packet         : knx_def.TPacket
  );
  BEGIN
    Packet.SetRoutingCounter( knx_def.ncRouteDefault );
    Executive()^.L_Data_Req( Destination, Class, Packet );
    Executive()^.Communicate( crtN_LayerRequest ); // start communication always
  END N_Groupdata_Req;

(*--------------------------------------------------------------------------------*)

  VIRTUAL PROCEDURE N_Groupdata_Con(
          Status      : knx_status.TKNXStackStatus;
          Destination : knx_def.TAddress; // logical
          PPacket     : knx_def.TPPacket
  );
  BEGIN
    Listener()^.N_Groupdata_Con( Status, Destination, PPacket );
  END N_Groupdata_Con;

(*--------------------------------------------------------------------------------*)

  VIRTUAL PROCEDURE N_Groupdata_Ind(
          Source      : knx_def.TAddress; // physical
          Destination : knx_def.TAddress; // group, one of self objects
          Class       : knx_def.TPriority;
          PPacket     : knx_def.TPPacket
  );
  BEGIN
    Listener()^.N_Groupdata_Ind( Source, Destination, Class, PPacket );
  END N_Groupdata_Ind;

(*--------------------------------------------------------------------------------*)

  LOCAL VIRTUAL PROCEDURE N_Broadcast_Req(
          Class          : knx_def.TPriority;
      VAR Packet         : knx_def.TPacket
  );
  VAR
    Destination : knx_def.TAddress;
  BEGIN
    Packet.SetRoutingCounter( knx_def.ncRouteDefault );
    Destination.SetBroadcast();
    Executive()^.L_Data_Req( Destination, Class, Packet );
    Executive()^.Communicate( crtN_LayerRequest ); // start communication always
  END N_Broadcast_Req;

(*--------------------------------------------------------------------------------*)

  VIRTUAL PROCEDURE N_Broadcast_Con(
          Status      : knx_status.TKNXStackStatus
  );
  BEGIN
    Listener()^.N_Broadcast_Con( Status );
  END N_Broadcast_Con;

(*--------------------------------------------------------------------------------*)

  VIRTUAL PROCEDURE N_Broadcast_Ind(
          Source      : knx_def.TAddress; // physical
          Class       : knx_def.TPriority;
          PPacket     : knx_def.TPPacket
  );
  BEGIN
    Listener()^.N_Broadcast_Ind( Source, Class, PPacket );
  END N_Broadcast_Ind;

(*--------------------------------------------------------------------------------*)

  VIRTUAL PROCEDURE OnPacketDiscard(
          PPacket        : knx_def.TPPacket
  );
  BEGIN
  END OnPacketDiscard;

(*--------------------------------------------------------------------------------*)

BEGIN
  LayerType := kltNetwork;
  Storage.Zero( ADR( N_Parameters ), SIZE( N_Parameters ));
  Storage.Zero( ADR( N_Data ), SIZE( N_Data ));
END CKNXStackNetworkLayer;

(*================================================================================*)

CLASS IMPLEMENTATION CKNXStackTransportLayer;

(*--------------------------------------------------------------------------------*)

  PRIVATE PROCEDURE Executive() : TPKNXStackNetworkLayer;
  BEGIN
    RETURN TPKNXStackNetworkLayer( PExecutive );
  END Executive;

(*--------------------------------------------------------------------------------*)

  PRIVATE PROCEDURE Listener() : TPKNXStackApplicationLayer;
  BEGIN
    RETURN TPKNXStackApplicationLayer( PListener );
  END Listener;

(*--------------------------------------------------------------------------------*)

  LOCAL PROCEDURE N_Data_Con(
          Status      : knx_status.TKNXStackStatus;
          Destination : knx_def.TAddress; // physical
          PPacket     : knx_def.TPPacket
  );
  BEGIN
  END N_Data_Con;

(*--------------------------------------------------------------------------------*)

  LOCAL PROCEDURE N_Data_Ind(
          Source      : knx_def.TAddress; // physical
          Destination : knx_def.TAddress; // physical, self
          Class       : knx_def.TPriority;
          PPacket     : knx_def.TPPacket
  );
  BEGIN
  END N_Data_Ind;

(*--------------------------------------------------------------------------------*)

  LOCAL PROCEDURE N_Groupdata_Con(
          Status      : knx_status.TKNXStackStatus;
          Destination : knx_def.TAddress; // logical
          PPacket     : knx_def.TPPacket
  );
  BEGIN
    T_Groupdata_Con( Status, Destination, PPacket );
  END N_Groupdata_Con;

(*--------------------------------------------------------------------------------*)

  LOCAL PROCEDURE N_Groupdata_Ind(
          Source      : knx_def.TAddress; // physical
          Destination : knx_def.TAddress; // group, one of self objects
          Class       : knx_def.TPriority;
          PPacket     : knx_def.TPPacket
  );
  BEGIN
    T_Groupdata_Ind( Destination, Class, PPacket );
  END N_Groupdata_Ind;

(*--------------------------------------------------------------------------------*)

  LOCAL PROCEDURE N_Broadcast_Con(
          Status      : knx_status.TKNXStackStatus
  );
  BEGIN
    T_Broadcast_Con( Status );
  END N_Broadcast_Con;

(*--------------------------------------------------------------------------------*)

  LOCAL PROCEDURE N_Broadcast_Ind(
          Source      : knx_def.TAddress; // physical
          Class       : knx_def.TPriority;
          PPacket     : knx_def.TPPacket
  );
  BEGIN
    T_Broadcast_Ind( Source, Class, PPacket );
  END N_Broadcast_Ind;

(*--------------------------------------------------------------------------------*)

  LOCAL PROCEDURE T_Data_Unack_Req(
          Destination : knx_def.TAddress;
          Class       : knx_def.TPriority;
      VAR Packet      : knx_def.TPacket
  );
  BEGIN
  END T_Data_Unack_Req;

(*--------------------------------------------------------------------------------*)

  INTERNAL VIRTUAL PROCEDURE T_Data_Unack_Con(
          Status      : knx_status.TKNXStackStatus;
          Destination : knx_def.TAddress
  );
  BEGIN
  END T_Data_Unack_Con;

(*--------------------------------------------------------------------------------*)

  INTERNAL VIRTUAL PROCEDURE T_Data_Unack_Ind(
          Source      : knx_def.TAddress;
          Class       : knx_def.TPriority;
          PPacket     : knx_def.TPPacket
  );
  BEGIN
  END T_Data_Unack_Ind;

(*--------------------------------------------------------------------------------*)

  LOCAL PROCEDURE T_Connect_Req(
          Destination : knx_def.TAddress; // physical
      VAR PConnection : TPConnection
  );
  BEGIN
  END T_Connect_Req;

(*--------------------------------------------------------------------------------*)

  INTERNAL VIRTUAL PROCEDURE T_Connect_Con(
          Status      : knx_status.TKNXStackStatus;
          PConnection : TPConnection
  );
  BEGIN
  END T_Connect_Con;

(*--------------------------------------------------------------------------------*)

  INTERNAL VIRTUAL PROCEDURE T_Connect_Ind(
          PConnection : TPConnection
  );
  BEGIN
  END T_Connect_Ind;

(*--------------------------------------------------------------------------------*)

  LOCAL PROCEDURE T_Disconnect_Req(
          PConnection : TPConnection
  );
  BEGIN
  END T_Disconnect_Req;

(*--------------------------------------------------------------------------------*)

  INTERNAL VIRTUAL PROCEDURE T_Disconnect_Con(
          Status      : knx_status.TKNXStackStatus;
          PConnection : TPConnection
  );
  BEGIN
  END T_Disconnect_Con;

(*--------------------------------------------------------------------------------*)

  INTERNAL VIRTUAL PROCEDURE T_Disconnect_Ind(
          PConnection : TPConnection
  );
  BEGIN
  END T_Disconnect_Ind;

(*--------------------------------------------------------------------------------*)

  LOCAL PROCEDURE T_Data_Req(
          PConnection : TPConnection;
          Class       : knx_def.TPriority;
      VAR Packet      : knx_def.TPacket
  );
  BEGIN
  END T_Data_Req;

(*--------------------------------------------------------------------------------*)

  INTERNAL VIRTUAL PROCEDURE T_Data_Con(
          Status      : knx_status.TKNXStackStatus;
          PConnection : TPConnection
  );
  BEGIN
  END T_Data_Con;

(*--------------------------------------------------------------------------------*)

  INTERNAL VIRTUAL PROCEDURE T_Data_Ind(
          PConnection : TPConnection
  );
  BEGIN
  END T_Data_Ind;

(*--------------------------------------------------------------------------------*)

  LOCAL VIRTUAL PROCEDURE T_Broadcast_Req(
          Class       : knx_def.TPriority;
      VAR Packet      : knx_def.TPacket
  );
  BEGIN
    SetTPDU( Packet, tpduBroadcastData_REQ );
    Executive()^.N_Broadcast_Req( Class, Packet );
  END T_Broadcast_Req;

(*--------------------------------------------------------------------------------*)

  INTERNAL VIRTUAL PROCEDURE T_Broadcast_Con(
          Status      : knx_status.TKNXStackStatus
  );
  BEGIN
    Listener()^.T_Broadcast_Con( Status );
  END T_Broadcast_Con;

(*--------------------------------------------------------------------------------*)

  INTERNAL VIRTUAL PROCEDURE T_Broadcast_Ind(
          Source      : knx_def.TAddress; // physical
          Class       : knx_def.TPriority;
          PPacket     : knx_def.TPPacket
  );
  BEGIN
    Listener()^.T_Broadcast_Ind( Source, Class, PPacket );
  END T_Broadcast_Ind;

(*--------------------------------------------------------------------------------*)

  LOCAL VIRTUAL PROCEDURE T_Groupdata_Req(
          Destination : knx_def.TAddress; // cr_id
          Class       : knx_def.TPriority;
      VAR Packet      : knx_def.TPacket
  );
  BEGIN
    IF Destination.GetAddressType() = knx_def.addressPhysical THEN
      T_Groupdata_Con( knx_status.essT_Bad_Address_Type, Destination, ADR( Packet ));
    ELSE
      SetTPDU( Packet, tpduGroupdata_REQ );
      Executive()^.N_Groupdata_Req( Destination, Class, Packet );
    END;
  END T_Groupdata_Req;

(*--------------------------------------------------------------------------------*)

  INTERNAL VIRTUAL PROCEDURE T_Groupdata_Con(
          Status      : knx_status.TKNXStackStatus;
          Destination : knx_def.TAddress;
          PPacket     : knx_def.TPPacket
  );
  BEGIN
    Listener()^.T_Groupdata_Con( Status, Destination, PPacket );
  END T_Groupdata_Con;

(*--------------------------------------------------------------------------------*)

  INTERNAL VIRTUAL PROCEDURE T_Groupdata_Ind(
          Destination : knx_def.TAddress;
          Class       : knx_def.TPriority;
          PPacket     : knx_def.TPPacket
  );
  BEGIN
    Listener()^.T_Groupdata_Ind( Destination, Class, PPacket );
  END T_Groupdata_Ind;

(*--------------------------------------------------------------------------------*)

  PRIVATE PROCEDURE SetTPDU( VAR Packet : knx_def.TPacket; TPDU : TT_PDU );
  BEGIN
    CASE TPDU OF
    | tpduConnect_REQ, tpduDisconnect_REQ :
      Packet.TransportControl := Packet.TransportControl - TT_PDU_ConnectMask + TT_PDU_Bits[ TPDU ];
    ELSE
      Packet.TransportControl := Packet.TransportControl - TT_PDU_Mask + TT_PDU_Bits[ TPDU ];
    END;
  END SetTPDU;

(*--------------------------------------------------------------------------------*)

BEGIN
  LayerType := kltTransport;
END CKNXStackTransportLayer;

(*================================================================================*)
(*================================================================================*)

TYPE
  TPA_PendingOperation = POINTER TO CA_PendingOperation;
  // in def TPA_Group            = POINTER TO CA_Group;

CLASS CA_PendingOperation( list.CListElem );
  WhatIsPending : TPendingOperation;
  Destination   : knx_def.TAddress;
  ObjectIndex   : CARDINAL;
  PropertyId    : CARDINAL;
END CA_PendingOperation;

(*--------------------------------------------------------------------------------*)

CLASS IMPLEMENTATION CA_PendingOperation;
BEGIN
  WhatIsPending := pendingGroupRead;
  ObjectIndex := 0;
  PropertyId := 0;
END CA_PendingOperation;

(*================================================================================*)

TYPE
  TPA_Object = POINTER TO CA_Object;

CLASS CA_Object( list.CListElem );
  PObject : TPObject;
END CA_Object;

(*--------------------------------------------------------------------------------*)

CLASS CA_Group( avltree.CAVLTreeElem );
  Address : knx_def.TAddress;
  Objects : list.CList;

  // inherited
  PUBLIC VIRTUAL PROCEDURE Compare( i : CARDINAL; pelem : avltree.TPAVLTreeKey ) : TRISTATE;
  LOCAL VIRTUAL PROCEDURE Done();

  // helpers
  LOCAL PROCEDURE EnumerateObjects( VAR EnumerateState : PTR; VAR PObject : TPObject ) : BOOLEAN;
END CA_Group;

(*--------------------------------------------------------------------------------*)

CLASS IMPLEMENTATION CA_Object;
BEGIN
  PObject := NIL;
END CA_Object;

(*--------------------------------------------------------------------------------*)

CLASS IMPLEMENTATION CA_Group;

(*--------------------------------------------------------------------------------*)

  PUBLIC VIRTUAL PROCEDURE Compare( i : CARDINAL; pelem : avltree.TPAVLTreeKey ) : TRISTATE;
  BEGIN
    IF Address.GetGroupAddress1() < TPA_Group( pelem )^.Address.GetGroupAddress1() THEN
      RETURN -1;
    ELSIF Address.GetGroupAddress1() > TPA_Group( pelem )^.Address.GetGroupAddress1() THEN
      RETURN 1;
    ELSE
      RETURN 0;
    END;
  END Compare;

(*--------------------------------------------------------------------------------*)

  LOCAL VIRTUAL PROCEDURE Done();
  BEGIN
    Objects.Dispose();
  END Done;

(*--------------------------------------------------------------------------------*)

  LOCAL PROCEDURE EnumerateObjects( VAR EnumerateState : PTR; VAR PObject : TPObject ) : BOOLEAN;
  VAR
    PA_Object : TPA_Object;
    b : BOOLEAN;
  BEGIN
    IF EnumerateState = 0 THEN
      b := Objects.colGetFirst( OUT PA_Object );
    ELSE
      PA_Object := EnumerateState;
      ASSERT( Objects.Contains( PA_Object ));
      b := Objects.colNextOf( PA_Object, OUT PA_Object );
    END;
    IF b THEN
      EnumerateState := PA_Object;
      PObject := PA_Object^.PObject;
    END;
    RETURN b;
  END EnumerateObjects;

(*--------------------------------------------------------------------------------*)

END CA_Group;

(*================================================================================*)

TYPE
  TPPendingData = POINTER TO CPendingData;

CLASS CPendingData( list.CListElem );
  WhatIsPending : TPendingOperation;
  POriginator   : TPSAP;
  Destination   : knx_def.TAddress;
  Class         : knx_def.TPriority;
  Packet        : knx_def.TPacket;
  Pending       : BOOLEAN;
END CPendingData;

(*--------------------------------------------------------------------------------*)

CLASS IMPLEMENTATION CPendingData;
BEGIN
  WhatIsPending := pendingGroupRead;
  POriginator := NIL;
  Class := knx_def.priorityNormal;
  Pending := FALSE;
END CPendingData;

(*================================================================================*)

CLASS IMPLEMENTATION CKNXStackApplicationLayer;

(*--------------------------------------------------------------------------------*)

  PRIVATE PROCEDURE Executive() : TPKNXStackTransportLayer;
  BEGIN
    RETURN TPKNXStackTransportLayer( PExecutive );
  END Executive;

(*--------------------------------------------------------------------------------*)

  PRIVATE PROCEDURE Listener() : TPKNXStackUserLayer;
  BEGIN
    RETURN NIL;
  END Listener;

(*--------------------------------------------------------------------------------*)

  LOCAL VIRTUAL PROCEDURE Done_Con(
          Status      : knx_status.TKNXStackStatus
  );
  VAR
    i : TPendingOperation;
    j : knx_def.TPriority;
  BEGIN
    A_Data.Groups.Dispose();

    IF A_Data.prGroup[prl1] <> NIL THEN
      A_Data.prGroup[prl1]^.Done();
      A_Data.prGroup[prl2]^.Done();
      A_Data.prGroup[prl3]^.Done();
      A_Data.prGroup[prl4]^.Done();
      A_Data.prGroup[prl5]^.Done();
      A_Data.prGroup[prl15]^.Done();
      DISPOSE( A_Data.prGroup[prl1] );
      DISPOSE( A_Data.prGroup[prl2] );
      DISPOSE( A_Data.prGroup[prl3] );
      DISPOSE( A_Data.prGroup[prl4] );
      DISPOSE( A_Data.prGroup[prl5] );
      DISPOSE( A_Data.prGroup[prl15] );
    END;

    i := pendingGroupRead;
    LOOP
      j := knx_def.priorityLowest;
      LOOP
        A_Data.Pending[i][j].Dispose();
        IF j = knx_def.priorityHighest THEN
          EXIT;
        ELSE
          INC( j );
        END;
      END;
      A_Data.Timeouter[i].Stop();
      IF i = pendingGroupWrite THEN
        EXIT;
      END;
      INC( i );
    END; // LOOP

    SUPER.Done_Con( Status );
  END Done_Con;

(*--------------------------------------------------------------------------------*)

  LOCAL VIRTUAL PROCEDURE Timeout( TimeoutId : TTimeoutId; UserId : LONGWORD );
  VAR
    PSPO : TPPendingData;
  BEGIN
    CASE TimeoutId OF
    | tidA_PendingTimeout :
      // bypass T_GroupData_Ind, which could be called here. The bypass is done to directly enter
      // A_GroupValue_Process parameters.
      IF ( TPendingOperation( UserId ) = pendingGroupRead ) AND A_GetFirstPending( pendingGroupRead, NIL, PSPO ) THEN
        A_GroupValue_Process( knx_status.essA_Timeout, NIL, pphIND, apduGroupValue_RS, PSPO^.Class, PSPO^.Destination, NIL ); // informs all SAPs
      END;
    | tidA_PendingDelay :
      A_StartPendingOperation( TPendingOperation( UserId ), FALSE, NIL );
    END;
  END Timeout;

(*--------------------------------------------------------------------------------*)

  LOCAL PROCEDURE T_Data_Unack_Con(
          Status      : knx_status.TKNXStackStatus;
          Destination : knx_def.TAddress
  );
  BEGIN
    // nothing to do, services are acknowledged remotelly
  END T_Data_Unack_Con;

(*--------------------------------------------------------------------------------*)

  LOCAL PROCEDURE T_Data_Unack_Ind(
          Source      : knx_def.TAddress;
          Class       : knx_def.TPriority;
          PPacket     : knx_def.TPPacket
  );
  BEGIN
  END T_Data_Unack_Ind;

(*--------------------------------------------------------------------------------*)
(*--------------------------------------------------------------------------------*)

  LOCAL PROCEDURE T_Connect_Con(
          Status      : knx_status.TKNXStackStatus;
          PConnection : TPConnection
  );
  BEGIN
  END T_Connect_Con;

(*--------------------------------------------------------------------------------*)

  LOCAL PROCEDURE T_Connect_Ind(
          PConnection : TPConnection
  );
  BEGIN
  END T_Connect_Ind;

(*--------------------------------------------------------------------------------*)

  LOCAL PROCEDURE T_Disconnect_Con(
          Status      : knx_status.TKNXStackStatus;
          PConnection : TPConnection
  );
  BEGIN
  END T_Disconnect_Con;

(*--------------------------------------------------------------------------------*)

  LOCAL PROCEDURE T_Disconnect_Ind(
          PConnection : TPConnection
  );
  BEGIN
  END T_Disconnect_Ind;

(*--------------------------------------------------------------------------------*)

  LOCAL PROCEDURE T_Data_Con(
          Status      : knx_status.TKNXStackStatus;
          PConnection : TPConnection
  );
  BEGIN
  END T_Data_Con;

(*--------------------------------------------------------------------------------*)

  LOCAL PROCEDURE T_Data_Ind(
          PConnection : TPConnection
  );
  BEGIN
  END T_Data_Ind;

(*--------------------------------------------------------------------------------*)
(*--------------------------------------------------------------------------------*)

  LOCAL PROCEDURE T_Broadcast_Con(
          Status      : knx_status.TKNXStackStatus
  );
  BEGIN
  END T_Broadcast_Con;

(*--------------------------------------------------------------------------------*)

  LOCAL PROCEDURE T_Broadcast_Ind(
          Source      : knx_def.TAddress; // physical
          Class       : knx_def.TPriority;
          PPacket     : knx_def.TPPacket
  );
  BEGIN
  END T_Broadcast_Ind;

(*--------------------------------------------------------------------------------*)
(*--------------------------------------------------------------------------------*)

  LOCAL PROCEDURE T_Groupdata_Con(
          Status      : knx_status.TKNXStackStatus;
          Destination : knx_def.TAddress;
          PPacket     : knx_def.TPPacket
  );
  BEGIN
    CASE GetAPDU( PPacket ) OF
    | apduGroupValue_RD :
      A_GroupValue_Process( Status, NIL, pphCON, apduGroupValue_RD, PPacket^.GetPriority(), Destination, PPacket ); // informs all SAPs
    | apduGroupValue_WR :
      A_GroupValue_Process( Status, NIL, pphCON, apduGroupValue_WR, PPacket^.GetPriority(), Destination, PPacket ); // informs all SAPs
    // ELSE unknown and unsupported ACPI are ignored
    END; // CASE
  END T_Groupdata_Con;

(*--------------------------------------------------------------------------------*)

  LOCAL PROCEDURE T_Groupdata_Ind(
          Destination : knx_def.TAddress;
          Class       : knx_def.TPriority;
          PPacket     : knx_def.TPPacket
  );
  BEGIN
    CASE GetAPDU( PPacket ) OF
    | apduGroupValue_RD :
      A_GroupValue_Process( knx_status.essOK, NIL, pphIND, apduGroupValue_RD, Class, Destination, PPacket ); // informs all SAPs
    | apduGroupValue_RS :
      A_GroupValue_Process( knx_status.essOK, NIL, pphIND, apduGroupValue_RS, Class, Destination, PPacket ); // informs all SAPs
    | apduGroupValue_WR :
      A_GroupValue_Process( knx_status.essOK, NIL, pphIND, apduGroupValue_WR, Class, Destination, PPacket ); // informs all SAPs
    // ELSE unknown and unsupported ACPI are ignored
    END; // CASE
  END T_Groupdata_Ind;

(*--------------------------------------------------------------------------------*)

  PUBLIC PROCEDURE A_GroupValue_Read_Req(
          POriginator : TPSAP;
          Destination : knx_def.TAddress;
          Class       : knx_def.TPriority
  );
  VAR
    LPacket : knx_def.TPacket;
  BEGIN
    SetAPDU( LPacket, apduGroupValue_RD );
    LPacket.SetDataLength( 1 );
    A_AppendPendingOperation( pendingGroupRead, POriginator, Class, Destination, LPacket );
  END A_GroupValue_Read_Req;

(*--------------------------------------------------------------------------------*)

  PUBLIC PROCEDURE A_GroupValue_Read_Res(
          POriginator : TPSAP;
          Destination : knx_def.TAddress;
          Class       : knx_def.TPriority;
      VAR Packet      : knx_def.TPacket
  );
  BEGIN
    SetAPDU( Packet, apduGroupValue_RS );
    // update remote objects
    Executive()^.T_Groupdata_Req( Destination, Class, Packet );
    // update local objects
    A_GroupValue_Process( knx_status.essOK, POriginator, pphRES, apduGroupValue_RS, Class, Destination, ADR( Packet ));
  END A_GroupValue_Read_Res;

(*--------------------------------------------------------------------------------*)

  PUBLIC PROCEDURE A_GroupValue_Write_Req(
          POriginator : TPSAP;
          Destination : knx_def.TAddress;
          Class       : knx_def.TPriority;
      VAR Packet      : knx_def.TPacket
  );
  BEGIN
    SetAPDU( Packet, apduGroupValue_WR );
    A_AppendPendingOperation( pendingGroupWrite, POriginator, Class, Destination, Packet );
  END A_GroupValue_Write_Req;

(*--------------------------------------------------------------------------------*)

  INTERNAL VIRTUAL PROCEDURE A_GroupValue_Process(
          Status      : knx_status.TKNXStackStatus; // if needed, e.g. for pphCON
          POriginator : TPSAP;
          Phase       : TProcessPhase;
          APDU        : TA_PDU;
          Class       : knx_def.TPriority;
          Destination : knx_def.TAddress;
    CONST PPacket     : knx_def.TPPacket
  );
  VAR
    PGroup : TPA_Group;
  BEGIN
    IF A_Group_SearchGroup( Destination, PGroup ) THEN
      A_GroupValue_Process_Single( Status, POriginator, Phase, APDU, Class, Destination, PPacket, FALSE, PGroup );
    END;
    IF A_Parameters.PromiscuousMode AND ( PPacket <> NIL ) AND A_Group_SearchPromiscuousGroupByLength( PPacket, OUT PGroup ) THEN // repeat processing for promiscuous mode
      A_GroupValue_Process_Single( Status, POriginator, Phase, APDU, Class, Destination, PPacket, TRUE, PGroup );
    END;
  END A_GroupValue_Process;

(*--------------------------------------------------------------------------------*)

  PRIVATE PROCEDURE A_GroupValue_Process_Single(
          Status      : knx_status.TKNXStackStatus; // if needed, e.g. for pphCON
          POriginator : TPSAP;
          Phase       : TProcessPhase;
          APDU        : TA_PDU;
          Class       : knx_def.TPriority;
          Destination : knx_def.TAddress;
    CONST PPacket     : knx_def.TPPacket;
          Promiscuous : BOOLEAN;
          PGroup      : TPA_Group
  );
  VAR
    ES : PTR;
    Found : BOOLEAN;
    PendingDestination : knx_def.TAddress;
    PendingObjectAddress : knx_def.TAddress;
    PObject : TPSAP;
    Registered : BOOLEAN;
    WhatIsPending : TPendingOperation;
  BEGIN
    Registered := FALSE;
    Found := TRUE;

    CASE Phase OF
    //-----
    | pphIND :
      IF APDU = apduGroupValue_RS THEN
        // IND, both KNX RS data and self Timeout appear here
        WhatIsPending := pendingGroupRead;
        Registered := TRUE;
        Found := FALSE;
      END;
    //-----
    | pphCON :
      CASE APDU OF
      | apduGroupValue_RD :
        IF Status <> knx_status.essOK THEN
          // errorneous CON (e.g. UNACKED), so the pending Read must be removed
          WhatIsPending := pendingGroupRead;
          Registered := TRUE;
          Found := FALSE;
        // ELSE do nothing and wait for pphIND (Timeout or proper Read_RS)
        END;
      | apduGroupValue_WR :
        // all forms of CON, WR is now finished, so pending one must be removed and sending can continue with the next write packet
        WhatIsPending := pendingGroupWrite;
        Registered := TRUE;
        Found := FALSE;
      END;
    //-----
    END; // CASE
    IF Registered AND NOT A_GetPendingDestination( WhatIsPending, Class, PendingDestination ) THEN
      Registered := FALSE;
    END;

    ES := 0;
    WHILE PGroup^.EnumerateObjects( ES, PObject ) DO IF POriginator <> PObject THEN

         IF Promiscuous THEN // for promiscuous mode only valid information is in packet
            PObject^.PromiscuousAddress := PPacket^.GetDestinationAddress();
         END;

         IF Registered AND NOT Found THEN // we did not find correspoding object yet
            IF PObject^.Promiscuous THEN
               PendingObjectAddress := PObject^.PromiscuousAddress;
            ELSIF WhatIsPending = pendingGroupRead THEN // check ReadAddress
               PendingObjectAddress := PObject^.ReadAddress;
            ELSE // check SendAddress
               PendingObjectAddress := PObject^.SendAddress;
            END;
            Found := ( PendingObjectAddress.GetAddressType() <> knx_def.addressUnknown ) AND ( PendingObjectAddress = PendingDestination );
         END;

      CASE Phase OF
      | pphIND :
        CASE APDU OF
        | apduGroupValue_RD :
          PObject^.AU_GroupValue_Read_Req();
        | apduGroupValue_RS :
          PObject^.AU_GroupValue_Read_Res( Status, PPacket );
        | apduGroupValue_WR :
          PObject^.AU_GroupValue_Write_Ind( PPacket );
        END; // CASE
      | pphCON :
        CASE APDU OF
        | apduGroupValue_RD :
          PObject^.AU_GroupValue_Read_Con( Status );
        | apduGroupValue_WR :
          PObject^.AU_GroupValue_Write_Con( Status );
        END; // CASE
      | pphRES :
        // notification of local response
        PObject^.AU_GroupValue_Read_Res( Status, PPacket );
      END; // CASE
    END; END; // IF not procknx_status.essing self // WHILE

    IF Registered AND Found THEN
      // this is a pending apduGroupRead operation, which needs further procknx_status.essing
      A_PendingOperationFinished( WhatIsPending, Status, Class, PendingDestination );
    END;
  END A_GroupValue_Process_Single;

(*--------------------------------------------------------------------------------*)

  PUBLIC PROCEDURE A_Subscribe(
          _Update_L_Layer : BOOLEAN;
    CONST Address         : knx_def.TAddress;
          PObject         : TPSAP
  ) : knx_status.TKNXStackStatus;
  VAR
    PA_Object : TPA_Object;
    PGroup : TPA_Group;
    b : BOOLEAN;
  BEGIN
    DataLock.Lock();
 
    IF NOT A_Group_SearchGroup( Address, PGroup ) THEN
      NEW( PGroup );
      PGroup^.Address := Address;
      A_Data.Groups.Add( PGroup );
      IF PStack^.Layers[ kltNetwork ] <> NIL THEN
        TPN_L_Data_Listener( TPKNXStackNetworkLayer( PStack^.Layers[ kltNetwork ] )^.N_Data.PL_Listener )^.AddGroup( Address );
      END;
      IF _Update_L_Layer THEN
        Update_L_Layer();
      END;
    END;

    b := PGroup^.Objects.colGetFirst( OUT PA_Object );
    WHILE b AND ( PA_Object^.PObject <> PObject ) DO
      b := PGroup^.Objects.colNextOf( PA_Object, OUT PA_Object );
    END; // WHILE
    IF NOT b THEN
      NEW( PA_Object );
      PA_Object^.PObject := PObject;
      PGroup^.Objects.Add( PA_Object );
    END;

    DataLock.Unlock();
    RETURN knx_status.essOK;
  END A_Subscribe;

(*--------------------------------------------------------------------------------*)

  PUBLIC PROCEDURE A_Unsubscribe(
          _Update_L_Layer : BOOLEAN;
    CONST Address         : knx_def.TAddress;
          PObject         : TPSAP
  ) : knx_status.TKNXStackStatus;
  VAR
    PA_Object : TPA_Object;
    PGroup : TPA_Group;
    b : BOOLEAN;
  BEGIN
    DataLock.Lock();

    IF NOT A_Group_SearchGroup( Address, PGroup ) THEN
       DataLock.Unlock();
       RETURN knx_status.essOK;
    END;

    b := PGroup^.Objects.colGetFirst( OUT PA_Object );
    WHILE b AND ( PA_Object^.PObject <> PObject ) DO
      b := PGroup^.Objects.colNextOf( PA_Object, OUT PA_Object );
    END; // WHILE
    IF b THEN
      PGroup^.Objects.Delete( PA_Object );
      IF PGroup^.Objects.Empty THEN
        A_Data.Groups.Delete( 0, PGroup );
        IF PStack^.Layers[ kltNetwork ] <> NIL THEN
          TPN_L_Data_Listener( TPKNXStackNetworkLayer( PStack^.Layers[ kltNetwork ] )^.N_Data.PL_Listener )^.RemoveGroup( Address );
        END;
        IF _Update_L_Layer THEN
          Update_L_Layer();
        END;
      END;
    END;

    DataLock.Unlock();
    RETURN knx_status.essOK;
  END A_Unsubscribe;

(*--------------------------------------------------------------------------------*)

  PUBLIC PROCEDURE A_SubscribePromiscuous(
          Length         : TprLength;
          PObject        : TPSAP
  ) : knx_status.TKNXStackStatus;
  VAR
    PA_Object : TPA_Object;
    PGroup : TPA_Group;
    b : BOOLEAN;
  BEGIN
    DataLock.Lock();

    IF NOT A_Parameters.PromiscuousMode THEN
       DataLock.Unlock();
       RETURN knx_status.essA_PromiscuousSubscribeDisallowed;
    END;

    PGroup := A_Data.prGroup[Length];

    b := PGroup^.Objects.colGetFirst( OUT PA_Object );
    WHILE b AND ( PA_Object^.PObject <> PObject ) DO
      b := PGroup^.Objects.colNextOf( PA_Object, OUT PA_Object );
    END; // WHILE
    IF NOT b THEN
      NEW( PA_Object );
      PA_Object^.PObject := PObject;
      PGroup^.Objects.Add( PA_Object );
    END;

    DataLock.Unlock();
    RETURN knx_status.essOK;
  END A_SubscribePromiscuous;

(*--------------------------------------------------------------------------------*)

  PUBLIC PROCEDURE A_UnsubscribePromiscuous(
          Length         : TprLength;
          PObject        : TPSAP
  ) : knx_status.TKNXStackStatus;
  VAR
    PA_Object : TPA_Object;
    PGroup : TPA_Group;
    b : BOOLEAN;
  BEGIN
    DataLock.Lock();

    IF NOT A_Parameters.PromiscuousMode THEN
       DataLock.Unlock();
       RETURN knx_status.essA_PromiscuousSubscribeDisallowed;
    END;

    PGroup := A_Data.prGroup[Length];

    b := PGroup^.Objects.colGetFirst( OUT PA_Object );
    WHILE b AND ( PA_Object^.PObject <> PObject ) DO
      b := PGroup^.Objects.colNextOf( PA_Object, OUT PA_Object );
    END; // WHILE
    IF b THEN
      PGroup^.Objects.Delete( PA_Object );
    END;

    DataLock.Unlock();
    RETURN knx_status.essOK;
  END A_UnsubscribePromiscuous;

(*--------------------------------------------------------------------------------*)

  PUBLIC PROCEDURE Update_L_Layer();
  BEGIN
    DataLock.Lock();

    IF PStack^.Layers[ kltNetwork ] <> NIL THEN
      TPKNXStackNetworkLayer( PStack^.Layers[ kltNetwork ] )^.N_Data.PL_Listener^.GroupsUpdated();
    END;

    DataLock.Unlock();
  END Update_L_Layer;

(*--------------------------------------------------------------------------------*)
(*--------------------------------------------------------------------------------*)

   PUBLIC VIRTUAL PROCEDURE OnMessage( CONST MSG : msghandler.IMessage; OUT Result : PTR ) : BOOLEAN;
   VAR
      PPendingData : TPPendingData;
   BEGIN
      IF MSG.Message = msgqueue.MSG_PROCESS_QUEUE THEN

         WHILE Queue.Dequeue( OUT PPendingData ) DO
            A_Data.Pending[ PPendingData^.WhatIsPending ][ PPendingData^.Class ].Add( PPendingData );
            A_StartPendingOperation( PPendingData^.WhatIsPending, PPendingData^.POriginator^.Promiscuous, ADR( PPendingData^.Class ));
         END; // while

         RETURN TRUE;
      ELSE
         RETURN FALSE;
      END; 
   END OnMessage;

(*--------------------------------------------------------------------------------*)

  PRIVATE PROCEDURE GetAPDU( PPacket : knx_def.TPPacket ) : TA_PDU;
  VAR
    Check : knx_def.TTransportControl;
  BEGIN
    Check := PPacket^.TransportControl * maskGroup;
    IF Check = acpis[ apduGroupValue_RD ].ACPI THEN
       RETURN apduGroupValue_RD;
    ELSIF Check = acpis[ apduGroupValue_RS ].ACPI THEN
       RETURN apduGroupValue_RS;
    ELSIF Check = acpis[ apduGroupValue_WR ].ACPI THEN
       RETURN apduGroupValue_WR;
    ELSE
       ASSERT( FALSE );
       RETURN apduGroupValue_RD;
    END;
  END GetAPDU;

(*--------------------------------------------------------------------------------*)

  PRIVATE PROCEDURE SetAPDU( VAR Packet : knx_def.TPacket; ACPI : TA_PDU );
  BEGIN
    Packet.TransportControl := Packet.TransportControl - acpis[ACPI].Mask + acpis[ACPI].ACPI;
  END SetAPDU;

(*--------------------------------------------------------------------------------*)

  PRIVATE PROCEDURE A_AppendPendingOperation( WhatIsPending : TPendingOperation; POriginator : TPSAP; Class : knx_def.TPriority; CONST Destination : knx_def.TAddress; CONST Packet : knx_def.TPacket );
  VAR
    PPendingData : TPPendingData;
  BEGIN
    IF ( A_Parameters.PendingCount[ WhatIsPending ] <> 0 ) AND
       ( A_Parameters.PendingCount[ WhatIsPending ] <> MAX( CARDINAL )) AND
       ( A_QueueLength( WhatIsPending ) >= A_Parameters.PendingCount[ WhatIsPending ] ) THEN
      // queue limit reached
      CASE WhatIsPending OF
      | pendingGroupRead :
        A_GroupValue_Process( knx_status.essA_ReadQueueOverflow, POriginator, pphCON, apduGroupValue_WR, Class, Destination, ADR( Packet ));
      | pendingGroupWrite :
        A_GroupValue_Process( knx_status.essA_WriteQueueOverflow, POriginator, pphCON, apduGroupValue_RD, Class, Destination, ADR( Packet ));
      END;
      RETURN;
    END;

    NEW( PPendingData );
    PPendingData^.WhatIsPending := WhatIsPending;
    PPendingData^.POriginator := POriginator;
    PPendingData^.Destination := Destination;
    PPendingData^.Class := Class;
    PPendingData^.Packet := Packet;
    
    Queue.Enqueue( PPendingData ); // dequeue is OnMessage
  END A_AppendPendingOperation;

(*--------------------------------------------------------------------------------*)

  PRIVATE PROCEDURE A_GetPendingDestination( WhatIsPending : TPendingOperation; Class : knx_def.TPriority; VAR Destination : knx_def.TAddress ) : BOOLEAN;
  VAR
    PSPO : TPPendingData;
  BEGIN
    IF A_Data.Pending[ WhatIsPending ][Class].colGetFirst( OUT PSPO ) THEN
      Destination := PSPO^.Destination;
      RETURN TRUE;
    ELSE
      RETURN FALSE;
    END;
  END A_GetPendingDestination;

(*--------------------------------------------------------------------------------*)

  PRIVATE PROCEDURE A_PendingOperationFinished( WhatIsPending : TPendingOperation; Status : knx_status.TKNXStackStatus; Class : knx_def.TPriority; CONST Destination : knx_def.TAddress );
  VAR
    PSPO : TPPendingData;
  BEGIN
    IF A_Data.Pending[ WhatIsPending ][Class].colGetFirst( OUT PSPO ) AND ( PSPO^.Destination = Destination ) THEN // PSPO^.Pending ignored
      A_Data.Timeouter[ WhatIsPending ].Stop();
      A_Data.Pending[ WhatIsPending ][Class].Delete( PSPO );
    END;
    IF NOT A_PendingIsTransactional( WhatIsPending ) THEN
      // pass down
    ELSIF A_Parameters.PendingDelay[ WhatIsPending ] = 0 THEN
      A_StartPendingOperation( WhatIsPending, FALSE, NIL );
    ELSE
      A_Data.Timeouter[ WhatIsPending ].StartEx( tidA_PendingDelay, A_Parameters.PendingDelay[ WhatIsPending ] );
    END;
  END A_PendingOperationFinished;

(*--------------------------------------------------------------------------------*)

  PRIVATE PROCEDURE A_StartPendingOperation( WhatIsPending : TPendingOperation; ForceConcurrency : BOOLEAN; PClass : knx_def.TPPriority ); // CAN be NIL, if start could select packet automatically
  VAR
    delay : CARDINAL;
    PSPO : TPPendingData;
  BEGIN
    IF NOT ForceConcurrency AND A_PendingIsTransactional( WhatIsPending ) THEN
      IF NOT A_GetFirstPending( WhatIsPending, PClass, PSPO ) THEN
        RETURN; // nothing to send
      ELSIF PSPO^.Pending THEN // already sent
        RETURN;
      ELSIF A_Parameters.PendingDelay[ WhatIsPending ] = 0 THEN
        // pass down
      ELSIF A_Data.Timeouter[ WhatIsPending ].Pending() THEN
        RETURN; // get out, a tidA_PendingDelay is pending, new send must not be initiated
      ELSE
        delay := datetime.UptimeMS() - A_Data.LastSend[ WhatIsPending ];
        IF delay < A_Parameters.PendingDelay[ WhatIsPending ] THEN // wait for send spare
          A_Data.Timeouter[ WhatIsPending ].StartEx( tidA_PendingDelay, delay );
          RETURN;
        END;
      END;
    ELSIF NOT A_GetLastStarted( WhatIsPending, PClass, PSPO ) THEN
      RETURN; // nothing to send
    END;

    PSPO^.Pending := TRUE;
    IF NOT ForceConcurrency AND ( A_Parameters.PendingTimeout[ WhatIsPending ] > 0 ) THEN
      A_Data.Timeouter[ WhatIsPending ].StartEx( tidA_PendingTimeout, A_Parameters.PendingTimeout[ WhatIsPending ] ); // timeouter MUST be three times !!!, now it is single, which is BAD !!!
    END;
    CASE WhatIsPending OF
    | pendingGroupRead :
      // ask remote objects
      Executive()^.T_Groupdata_Req( PSPO^.Destination, PSPO^.Class, PSPO^.Packet );
      // ask local objects
      A_GroupValue_Process( knx_status.essOK, PSPO^.POriginator, pphIND, apduGroupValue_RD, PSPO^.Class, PSPO^.Destination, ADR( PSPO^.Packet ));
    | pendingGroupWrite :
      // update remote objects
      Executive()^.T_Groupdata_Req( PSPO^.Destination, PSPO^.Class, PSPO^.Packet );
      // update local objects
      A_GroupValue_Process( knx_status.essOK, PSPO^.POriginator, pphIND, apduGroupValue_WR, PSPO^.Class, PSPO^.Destination, ADR( PSPO^.Packet ));
    ELSE
      ASSERT( FALSE );
    END;
  END A_StartPendingOperation;

(*--------------------------------------------------------------------------------*)

  PRIVATE PROCEDURE A_PendingIsTransactional( PendingOperation : TPendingOperation ) : BOOLEAN; // can run only as single, not in parallel
  BEGIN
    IF PendingOperation = pendingGroupRead THEN
      RETURN TRUE;
    END;
    RETURN ( A_Parameters.PendingDelay[ PendingOperation ] > 0 ) OR ( A_Parameters.PendingTimeout[ PendingOperation ] > 0 );
  END A_PendingIsTransactional;

(*--------------------------------------------------------------------------------*)

  PRIVATE PROCEDURE A_Group_SearchGroup( CONST Address : knx_def.TAddress; VAR PGroup : TPA_Group ) : BOOLEAN;
  VAR
    A_Group : CA_Group;
  BEGIN
    A_Group.Address := Address;
    RETURN A_Data.Groups.Get( 0, ADR( A_Group ), OUT PGroup );
  END A_Group_SearchGroup;

(*--------------------------------------------------------------------------------*)

  PRIVATE PROCEDURE A_Group_SearchPromiscuousGroupByLength( CONST PPacket : knx_def.TPPacket; OUT PGroup : TPA_Group ) : BOOLEAN;
  BEGIN
    IF A_Data.prGroup[prl1] = NIL THEN
      RETURN FALSE;
    END;
    CASE PPacket^.GetDataLength() OF
    | CARDINAL( knx_def.ncsDataLength1 ) : // eitSwitch, eitIncrease, eitPriority
      PGroup := A_Data.prGroup[prl1];
    | CARDINAL( knx_def.ncsDataLength2 ) : // eitScaling, eitScaling255, eitChar, eit8bit
      PGroup := A_Data.prGroup[prl2];
    | CARDINAL( knx_def.ncsDataLength3 ) : // eitValue, eit16bit
      PGroup := A_Data.prGroup[prl3];
    | CARDINAL( knx_def.ncsDataLength4 ) : // eitTime, eitDate
      PGroup := A_Data.prGroup[prl4];
    | CARDINAL( knx_def.ncsDataLength5 ) : // eitFloat, eit32bit
      PGroup := A_Data.prGroup[prl5];
    | CARDINAL( knx_def.ncsDataLength15 ) : // eitString
      PGroup := A_Data.prGroup[prl15];
    ELSE
      RETURN FALSE;
    END; // CASE
    RETURN TRUE;
  END A_Group_SearchPromiscuousGroupByLength;
     
(*--------------------------------------------------------------------------------*)

  PRIVATE PROCEDURE A_GetFirstPending( WhatIsPending : TPendingOperation; PClass : knx_def.TPPriority; VAR _PSPO : ADDRESS ) : BOOLEAN;
  VAR
    PSPO : TPPendingData;
    priority : knx_def.TPriority;
  BEGIN
    IF PClass = NIL THEN
      priority := knx_def.priorityHighest;
    ELSE
      priority := PClass^;
    END;
    LOOP
      IF A_Data.Pending[ WhatIsPending ][priority].colGetFirst( OUT PSPO ) THEN // have it
        _PSPO := PSPO;
        RETURN TRUE;
      ELSIF PClass <> NIL THEN
        RETURN FALSE; // restricted nothing to get
      ELSIF priority = knx_def.priorityLowest THEN
        RETURN FALSE; // nothing to get
      ELSE
        DEC( priority );
      END;
    END; // LOOP
  END A_GetFirstPending;

(*--------------------------------------------------------------------------------*)

  PRIVATE PROCEDURE A_GetLastStarted( WhatIsPending : TPendingOperation; PClass : knx_def.TPPriority; VAR _PSPO : ADDRESS ) : BOOLEAN;
  VAR
    PSPO : TPPendingData;
    priority : knx_def.TPriority;
  BEGIN
    IF PClass = NIL THEN
      priority := knx_def.priorityHighest;
    ELSE
      priority := PClass^;
    END;
    LOOP
      IF A_Data.Pending[ WhatIsPending ][priority].colGetLast( OUT PSPO ) THEN // have it
        _PSPO := PSPO;
        RETURN TRUE;
      ELSIF PClass <> NIL THEN
        RETURN FALSE; // restricted nothing to get
      ELSIF priority = knx_def.priorityLowest THEN
        RETURN FALSE; // nothing to get
      ELSE
        DEC( priority );
      END;
    END; // LOOP
  END A_GetLastStarted;

(*--------------------------------------------------------------------------------*)

  LOCAL PROCEDURE A_QueueLength( WhatIsPending : TPendingOperation ) : CARDINAL;
  VAR
    c : CARDINAL;
    j : knx_def.TPriority;
  BEGIN
    c := 0;
    j := knx_def.priorityLowest;
    LOOP
      c := c + A_Data.Pending[ WhatIsPending ][j].Count + Queue.Count;
      IF j = knx_def.priorityHighest THEN
        EXIT;
      ELSE
        INC( j );
      END;
    END;
    RETURN c;
  END A_QueueLength;

(*--------------------------------------------------------------------------------*)

  LOCAL PROCEDURE A_SetPromiscuousMode( PromiscuousMode : BOOLEAN );
  BEGIN
    A_Parameters.PromiscuousMode := PromiscuousMode;
    IF PromiscuousMode AND ( A_Data.prGroup[prl1] = NIL ) THEN // create dynamic data

      NEW( A_Data.prGroup[prl1] );
      NEW( A_Data.prGroup[prl2] );
      NEW( A_Data.prGroup[prl3] );
      NEW( A_Data.prGroup[prl4] );
      NEW( A_Data.prGroup[prl5] );
      NEW( A_Data.prGroup[prl15] );

      // is a part of normal subscribe
      // NEW( A_Data.prObject[plr] );
      // NEW( PA_Object );
      // PA_PObject := A_Data.prObject[plr];
      // A_Data.prGroup[plr]^.Object.Append( PA_Object );

    END;
  END A_SetPromiscuousMode;

(*--------------------------------------------------------------------------------*)

BEGIN
  LayerType := kltApplication;
  Storage.Zero( ADR( A_Parameters ), SIZE( A_Parameters ));
  A_Parameters.PendingTimeout[ pendingGroupRead ] := 2500;
  
   DataLock.Init( sync.ltSpin, L"", FALSE );
   Handler.Init( TRUE );
   Handler.MessageSink := ADR( SELF );
   Queue.Consumer := ADR( Handler );

  A_Data.Timeouter[ pendingGroupRead  ].Init( ADR( SELF ), tidA_PendingTimeout, A_Parameters.PendingTimeout[ pendingGroupRead  ], pendingGroupRead  );
  A_Data.Timeouter[ pendingGroupWrite ].Init( ADR( SELF ), tidA_PendingTimeout, A_Parameters.PendingTimeout[ pendingGroupWrite ], pendingGroupWrite );

  Storage.Zero( ADR( A_Data.LastSend ), SIZE( A_Data.LastSend ));

  Storage.Zero( ADR( A_Data.prGroup ), SIZE( A_Data.prGroup ));
  Storage.Zero( ADR( A_Data.prObject ), SIZE( A_Data.prObject ));
END CKNXStackApplicationLayer;

(*================================================================================*)

CLASS IMPLEMENTATION CKNXStack;

(*--------------------------------------------------------------------------------*)

  PUBLIC PROCEDURE Init( ConnectImmediatelly : BOOLEAN; InitLayerFrom, InitLayerTo : TKNXStackLayerType; PSink : TPKNXStackEventSink ) : knx_status.TKNXStackStatus;
  VAR
    Layer : TKNXStackLayerType;
    PLayer : TPKNXStackLayer;
    Result : knx_status.TKNXStackStatus;
  BEGIN
    PEventSink := PSink;

    IF InitLayerFrom = kltUndefined THEN
      InitLayerFrom := kltPhysical;
    END;
    IF InitLayerTo = kltUndefined THEN
      InitLayerTo := kltUser;
    END;

    Layer := InitLayerFrom;
    LOOP
      IF NOT CreateLayerInternal( Layer, PLayer ) THEN
        RETURN knx_status.essUnableToCreateLayer;
      END;
      Layers[ Layer ] := PLayer;

      IF Layer > kltPhysical THEN
        DEC( Layer );
        IF Layers[ Layer ] <> NIL THEN
          Layers[ Layer ]^.SetListener( PLayer );
          PLayer^.SetExecutive( Layers[ Layer ] );
        END; // IF Layer exists
        INC( Layer );
      ELSE
        PLayer^.SetExecutive( NIL );
      END;

      IF Layer = InitLayerTo THEN
        EXIT;
      ELSE
        INC( Layer );
      END;
    END; // LOOP
    
    Result := Initialize();
    IF Result = knx_status.essOK THEN
      INCL( Status, ssInitialized );
    ELSE
      RETURN Result;
    END;

    IF ConnectImmediatelly THEN
      RETURN Connect();
    ELSE
      RETURN knx_status.essOK;
    END;
  END Init;

(*--------------------------------------------------------------------------------*)

  PUBLIC PROCEDURE Connect() : knx_status.TKNXStackStatus;
  VAR
    Result : knx_status.TKNXStackStatus;
  BEGIN
    IF ssConnected IN Status THEN
      Result := knx_status.essAlreadyConnected;
    ELSE
      INCL( Status, ssConnected );
      Result := ConnectBUS();
    END;
    RETURN Result;
  END Connect;

(*--------------------------------------------------------------------------------*)

  PUBLIC PROCEDURE Disconnect() : knx_status.TKNXStackStatus;
  VAR
    Result : knx_status.TKNXStackStatus;
  BEGIN
    IF ssConnected IN Status THEN
      Result := DisconnectBUS();
      EXCL( Status, ssConnected );
    ELSE
      Result := knx_status.essNotConnected;
    END;
    RETURN Result;
  END Disconnect;

(*--------------------------------------------------------------------------------*)

  PUBLIC PROCEDURE Done() : knx_status.TKNXStackStatus;
  VAR
    Layer : TKNXStackLayerType;
    Result : knx_status.TKNXStackStatus;
  BEGIN
    Disconnect();
    IF ssFinalized IN Status THEN
      Result := knx_status.essAlreadyFinalized;
    ELSE
      Result := Dispose();
      INCL( Status, ssFinalized );

      // done layers
      Layer := kltPhysical;
      LOOP
        IF Layers[ Layer ] <> NIL THEN
          IF Layers[ Layer ]^.Freeable() THEN
            DISPOSE( Layers[ Layer ] );
          ELSE
            Layers[ Layer ] := NIL;
          END;
        END; // if layer exists
        IF Layer = kltUser THEN
          EXIT;
        ELSE
          INC( Layer );
        END;
      END; // LOOP
    END;
    RETURN Result;
  END Done;

(*--------------------------------------------------------------------------------*)

  PUBLIC PROCEDURE SetStackAddress( CONST Address : knx_def.TAddress ) : knx_status.TKNXStackStatus;
  BEGIN
    IF knx_def.TPAddress( ADR( Address ))^.GetAddressType() <> knx_def.addressPhysical THEN
      RETURN knx_status.essL_Bad_Address_Type;
    ELSIF Layers[ kltLink ] = NIL THEN
      RETURN knx_status.essL_Layer_Undefined;
    END;
    TPKNXStackLinkLayer( Layers[ kltLink ] )^.L_Parameters.SelfAddress := Address;
    RETURN knx_status.essOK;
  END SetStackAddress;

(*--------------------------------------------------------------------------------*)

  PUBLIC VIRTUAL PROCEDURE SetTimeout( TimeoutId : TTimeoutId; Timeout : CARDINAL; AuxiliarySpecification : LONGWORD );
  VAR
    Layer : TKNXStackLayerType;
  BEGIN
    CASE TimeoutId OF
    | tidL_ACKTimeout, tidL_BUSYDelay, tidL_SendDelay :
      Layer := kltLink;
    | tidA_PendingTimeout, tidA_PendingDelay :
      Layer := kltApplication;
    ELSE
      RETURN;
    END;
    IF Layers[ Layer ] = NIL THEN
      RETURN;
    END;
    CASE TimeoutId OF
    | tidL_ACKTimeout :
      TPKNXStackLinkLayer( Layers[ Layer ] )^.L_Parameters.ACKTimeout := Timeout;
    | tidL_BUSYDelay :
      TPKNXStackLinkLayer( Layers[ Layer ] )^.L_Parameters.BUSYDelay := Timeout;
    | tidL_SendDelay :
      TPKNXStackLinkLayer( Layers[ Layer ] )^.L_Parameters.SendDelay := Timeout;
    | tidA_PendingTimeout :
      TPKNXStackApplicationLayer( Layers[ Layer ] )^.A_Parameters.PendingTimeout[ TPendingOperation( AuxiliarySpecification ) ] := Timeout;
    | tidA_PendingDelay :
      TPKNXStackApplicationLayer( Layers[ Layer ] )^.A_Parameters.PendingDelay[ TPendingOperation( AuxiliarySpecification ) ] := Timeout;
    END;
    Layers[ Layer ]^.TimeoutUpdated( TimeoutId, AuxiliarySpecification );
  END SetTimeout;

(*--------------------------------------------------------------------------------*)

  PUBLIC PROCEDURE SetParameter( CONST Parameter, Value : ARRAY OF WCHAR; OUT ErrorText : ARRAY OF WCHAR ) : BOOLEAN;
  CONST
    kvNone  = L'none';
    kvKnown = L'known';
    kvAll   = L'all';
  VAR
    c : CARDINAL;
    t : TRISTATE;
  BEGIN
    IF EQUALS( L"link.outputQueueLength", Parameter ) THEN
      IF NOT Strings.ToCARD32W( Value, 10, OUT TPKNXStackLinkLayer( Layers[ kltLink ] )^.L_Parameters.OutputQueueLength ) THEN
         ErrorText := L"Expected number";
         RETURN FALSE;
      END;

    ELSIF EQUALS( L"link.retryCount", Parameter ) THEN
      IF NOT Strings.ToCARD32W( Value, 10, OUT c ) THEN
         ErrorText := L"Expected number";
         RETURN FALSE;
      END;
      c := MIN2( 10, c );
      TPKNXStackLinkLayer( Layers[ kltLink ] )^.L_Parameters.BUSY_Retry := c;
      TPKNXStackLinkLayer( Layers[ kltLink ] )^.L_Parameters.NAK_Retry := c;

    ELSIF EQUALS( L"application.pendingQueueLength.read", Parameter ) THEN
      IF NOT Strings.ToCARD32W( Value, 10, OUT TPKNXStackApplicationLayer( Layers[ kltApplication ] )^.A_Parameters.PendingCount[ pendingGroupRead ] ) THEN
         ErrorText := L"Expected number";
         RETURN FALSE;
      END;

    ELSIF EQUALS( L"application.pendingQueueLength.write", Parameter ) THEN
      IF NOT Strings.ToCARD32W( Value, 10, OUT TPKNXStackApplicationLayer( Layers[ kltApplication ] )^.A_Parameters.PendingCount[ pendingGroupWrite ] ) THEN
         ErrorText := L"Expected number";
         RETURN FALSE;
      END;

    ELSIF EQUALS( L"application.promiscuousMode", Parameter ) THEN
      IF EQUALS( L"false",  Value ) THEN
         TPKNXStackLinkLayer( Layers[ kltLink ] )^.L_Parameters.CheckAddressed := TRUE;
         TPKNXStackApplicationLayer( Layers[ kltApplication ] )^.A_SetPromiscuousMode( FALSE );
      ELSIF EQUALS( L"true",  Value ) THEN
         TPKNXStackLinkLayer( Layers[ kltLink ] )^.L_Parameters.CheckAddressed := FALSE;
         TPKNXStackApplicationLayer( Layers[ kltApplication ] )^.A_SetPromiscuousMode( TRUE );
      ELSE
         ErrorText := L"Expected true | false";
         RETURN FALSE;
      END;

    ELSE
      t := ParseParameter( Parameter, Value, OUT ErrorText );
      IF t = -1 THEN
         ErrorText := L"Unknown parameter";
         RETURN FALSE;
      ELSE
         RETURN t = 1;
      END;

    END;
    RETURN TRUE;
  END SetParameter;

(*--------------------------------------------------------------------------------*)

   PUBLIC PROCEDURE GetParameter( CONST Parameter : ARRAY OF WCHAR; OUT Value : ARRAY OF WCHAR ) : BOOLEAN;
   CONST
      kvFalse = L'false';
      kvKnown = L'known';
      kvTrue = L'true';
   BEGIN
      IF EQUALS( L"link.ackMethod", Parameter ) THEN
         Value := kvKnown;
      ELSIF EQUALS( L"link.outputQueueLength", Parameter ) THEN
         Strings.FromCARD32W( TPKNXStackLinkLayer( Layers[ kltLink ] )^.L_Parameters.OutputQueueLength, 10, OUT Value );
      ELSIF EQUALS( L"link.retryCount", Parameter ) THEN
         Strings.FromCARD32W( TPKNXStackLinkLayer( Layers[ kltLink ] )^.L_Parameters.BUSY_Retry, 10, OUT Value );
      ELSIF EQUALS( L"application.pendingQueueLength.read", Parameter ) THEN
         Strings.FromCARD32W( TPKNXStackApplicationLayer( Layers[ kltApplication ] )^.A_Parameters.PendingCount[ pendingGroupRead ], 10, OUT Value );
      ELSIF EQUALS( L"application.pendingQueueLength.write", Parameter ) THEN
         Strings.FromCARD32W( TPKNXStackApplicationLayer( Layers[ kltApplication ] )^.A_Parameters.PendingCount[ pendingGroupWrite ], 10, OUT Value );
      ELSIF EQUALS( L"application.promiscuousMode", Parameter ) THEN
         IF TPKNXStackApplicationLayer( Layers[ kltApplication ] )^.A_Parameters.PromiscuousMode THEN
            Value := kvTrue;
         ELSE
            Value := kvFalse;
         END;
      ELSE
         RETURN ConstructParameter( Parameter, OUT Value );
      END;
      RETURN TRUE;
   END GetParameter;

(*--------------------------------------------------------------------------------*)

  PUBLIC PROCEDURE IsSelfPacket( PPacket : knx_def.TPPacket ) : BOOLEAN;
  BEGIN
    RETURN TPKNXStackLinkLayer( Layers[ kltLink ] )^.IsSelfPacket( PPacket );
  END IsSelfPacket;

(*--------------------------------------------------------------------------------*)

  PUBLIC PROCEDURE OutputQueueLength() : CARDINAL;
  BEGIN
    RETURN TPKNXStackLinkLayer( Layers[ kltLink ] )^.L_Data.Queue.PacketsPending();
  END OutputQueueLength;

(*--------------------------------------------------------------------------------*)

  PUBLIC PROCEDURE WriteQueueLength() : CARDINAL;
  BEGIN
    RETURN TPKNXStackApplicationLayer( Layers[ kltApplication ] )^.A_QueueLength( pendingGroupWrite );
  END WriteQueueLength;

(*--------------------------------------------------------------------------------*)

  INTERNAL VIRTUAL PROCEDURE CreateLayer( Layer : TKNXStackLayerType; VAR PLayer : TPKNXStackLayer ) : BOOLEAN;
  BEGIN
    RETURN FALSE;
  END CreateLayer;

(*--------------------------------------------------------------------------------*)

  LOCAL VIRTUAL PROCEDURE CreateL_Data_Listener( VAR PL_Data_Listener : TPL_Data_Listener ) : BOOLEAN;
  BEGIN
    RETURN FALSE;
  END CreateL_Data_Listener;

(*--------------------------------------------------------------------------------*)

  INTERNAL VIRTUAL PROCEDURE ParseParameter( CONST Parameter, Value : ARRAY OF WCHAR; OUT ErrorText : ARRAY OF WCHAR ) : TRISTATE;
  BEGIN
    RETURN -1;
  END ParseParameter;

(*--------------------------------------------------------------------------------*)

  INTERNAL VIRTUAL PROCEDURE ConstructParameter( CONST Parameter : ARRAY OF WCHAR; OUT Value : ARRAY OF WCHAR ) : BOOLEAN;
  BEGIN
    RETURN FALSE;
  END ConstructParameter;

(*--------------------------------------------------------------------------------*)

  INTERNAL VIRTUAL PROCEDURE Initialize() : knx_status.TKNXStackStatus;
  VAR
    Layer : TKNXStackLayerType;
  BEGIN
    Layer := kltUser;
    LOOP // start initializing from most top level I know
      IF ( Layers[ Layer ] = NIL ) OR ( Layers[ Layer ]^.GetLayerType() = kltAbstract ) THEN
        DEC( Layer );
      ELSE
        Layers[ Layer ]^.Initialize_Req();
        EXIT;
      END;
      IF Layer = kltPhysical THEN
        EXIT;
      END;
    END; // LOOP
    RETURN knx_status.essOK;
  END Initialize;

(*--------------------------------------------------------------------------------*)

  INTERNAL VIRTUAL PROCEDURE ConnectBUS() : knx_status.TKNXStackStatus;
  BEGIN
    RETURN knx_status.essOK;
  END ConnectBUS;

(*--------------------------------------------------------------------------------*)

  INTERNAL VIRTUAL PROCEDURE DisconnectBUS() : knx_status.TKNXStackStatus;
  BEGIN
    RETURN knx_status.essOK;
  END DisconnectBUS;

(*--------------------------------------------------------------------------------*)

  INTERNAL VIRTUAL PROCEDURE Dispose() : knx_status.TKNXStackStatus;
  VAR
    Layer : TKNXStackLayerType;
  BEGIN
    // call Done_Req
    Layer := kltUser;
    LOOP // start initializing from most top level I know
      IF ( Layers[ Layer ] = NIL ) OR ( Layers[ Layer ]^.GetLayerType() = kltAbstract ) THEN
        DEC( Layer );
      ELSE
        Layers[ Layer ]^.Done_Req();
        EXIT;
      END;
      IF Layer = kltPhysical THEN
        EXIT;
      END;
    END; // LOOP
    RETURN Disconnect();
  END Dispose;

(*--------------------------------------------------------------------------------*)

  LOCAL VIRTUAL PROCEDURE OnError( Layer : TKNXStackLayerType; ErrorCode : knx_status.TKNXStackStatus );
  BEGIN
  END OnError;

(*--------------------------------------------------------------------------------*)

  PUBLIC VIRTUAL PROCEDURE DeviceConnected() : BOOLEAN;
  BEGIN
    RETURN FALSE;
  END DeviceConnected;

(*--------------------------------------------------------------------------------*)

  PUBLIC VIRTUAL PROCEDURE KNXConnected() : BOOLEAN;
  BEGIN
    RETURN FALSE;
  END KNXConnected;

(*--------------------------------------------------------------------------------*)

  PUBLIC PROCEDURE OnDeviceConnected();
  BEGIN
    IF PEventSink <> NIL THEN
      PEventSink^.OnDeviceConnected();
    END;
  END OnDeviceConnected;

(*--------------------------------------------------------------------------------*)

  PUBLIC PROCEDURE OnDeviceDisconnected();
  BEGIN
    IF PEventSink <> NIL THEN
      PEventSink^.OnDeviceDisconnected();
    END;
  END OnDeviceDisconnected;

(*--------------------------------------------------------------------------------*)

  PRIVATE PROCEDURE CreateLayerInternal( Layer : TKNXStackLayerType; VAR PLayer : TPKNXStackLayer ) : BOOLEAN;
  LABEL
    Created;
  BEGIN
    IF CreateLayer( Layer, PLayer ) THEN
      GOTO Created;
    END;

    CASE Layer OF
    | kltPhysical :
      NEW( TPKNXStackPhysicalLayer( PLayer ));
    | kltLink :
      NEW( TPKNXStackLinkLayer( PLayer ));
    | kltNetwork :
      NEW( TPKNXStackNetworkLayer( PLayer ));
    | kltTransport :
      NEW( TPKNXStackTransportLayer( PLayer ));
    | kltApplication :
      NEW( TPKNXStackApplicationLayer( PLayer ));
    | kltUser :
      NEW( TPKNXStackUserLayer( PLayer ));
    END;

  Created:
    PLayer^.PStack := ADR( SELF );
    RETURN TRUE;
  END CreateLayerInternal;

(*--------------------------------------------------------------------------------*)

BEGIN
  Status := TStackStatusSet{};
  PEventSink := NIL;
  Storage.Zero( ADR( Layers ), SIZE( Layers ));
END CKNXStack;

(*================================================================================*)

END knx_stack.