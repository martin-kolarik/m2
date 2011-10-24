IMPLEMENTATION MODULE knx_user;

(*================================================================================*)
(*/* changes:

24.07.2007 -- created

*/*)
(*================================================================================*)

FROM Storage IMPORT
   ALLOCATE, DEALLOCATE;

(*================================================================================*)

TYPE
  TPAU_Group = POINTER TO CAU_Group;

CLASS CAU_Group( list.CListElem );
  Address  : knx_def.TAddress;
  ReadFlag : BOOLEAN;
END CAU_Group;

(*--------------------------------------------------------------------------------*)

CLASS IMPLEMENTATION CAU_Group;
BEGIN
  ReadFlag := FALSE;
END CAU_Group;

(*--------------------------------------------------------------------------------*)
(*--------------------------------------------------------------------------------*)

CLASS IMPLEMENTATION CUserObject;

(*--------------------------------------------------------------------------------*)

  PUBLIC PROPERTY Type GET : knx_def.TKNXType;
  BEGIN
     RETURN Value.GetType();
  END Type;

(*--------------------------------------------------------------------------------*)

  PUBLIC PROCEDURE Init( POfStack : knx_stack.TPKNXStack; Type : knx_def.TKNXType; Behaviour : TObjectBehaviour );
  BEGIN
    PExecutive := knx_stack.TPKNXStackApplicationLayer( POfStack^.Layers[ knx_stack.kltApplication ] );
    Value.SetType( Type );
    CASE Behaviour OF
    | obTransmitter :
      SetFlags( knx_def.TA_ObjectFlags{knx_def.aofCommunicated, knx_def.aofTransmit} );
    | obTransmitterWithStatus :
      SetFlags( knx_def.TA_ObjectFlags{knx_def.aofCommunicated, knx_def.aofTransmit, knx_def.aofUpdate, knx_def.aofWritable} );
    | obTracker :
      SetFlags( knx_def.TA_ObjectFlags{knx_def.aofCommunicated, knx_def.aofUpdate, knx_def.aofWritable} );
    | obReader :
      SetFlags( knx_def.TA_ObjectFlags{knx_def.aofCommunicated, knx_def.aofUpdate, knx_def.aofForceRead} );
    END; // CASE
  END Init;

(*--------------------------------------------------------------------------------*)

  FINALLY CUserObject();
  VAR
    PGroup : TPAU_Group;
  BEGIN
    IF PExecutive = NIL THEN
      Groups.Dispose();
    ELSE
      WHILE Groups.GetFirst( OUT PGroup ) DO
        Groups.Remove( PGroup );
        PExecutive^.A_Unsubscribe( FALSE, PGroup^.Address, ADR( SELF ));
        DISPOSE( PGroup );
      END; // WHILE
      UpdateStack();
    END;
  END CUserObject;

(*--------------------------------------------------------------------------------*)

   INTERNAL VIRTUAL PROCEDURE Lock(); // hook to lock synchronized data, by default empty
   BEGIN
   END Lock;

(*--------------------------------------------------------------------------------*)

   INTERNAL VIRTUAL PROCEDURE Unlock(); // hook to lock synchronized data, by default empty
   BEGIN
   END Unlock;

(*--------------------------------------------------------------------------------*)

  PUBLIC PROCEDURE Executive() : knx_stack.TPKNXStackApplicationLayer;
  BEGIN
    RETURN PExecutive;
  END Executive;

(*--------------------------------------------------------------------------------*)

  PUBLIC VIRTUAL PROCEDURE AU_GroupValue_Read_Req();
  VAR
    LPacket : knx_def.TPacket;
    PGroup : TPAU_Group;
  BEGIN
    Lock();
    IF NOT Groups.GetFirst( OUT PGroup ) THEN
      Unlock();
      RETURN;
    ELSIF knx_def.TA_ObjectFlags{knx_def.aofCommunicated, knx_def.aofReadable} * Flags <> knx_def.TA_ObjectFlags{knx_def.aofCommunicated, knx_def.aofReadable} THEN
      Unlock();
      RETURN;
    END;
    LPacket.FromValue( Value );
    Unlock();

    // now, response is done to the first address
    Executive()^.A_GroupValue_Read_Res( ADR( SELF ), PGroup^.Address, Class, LPacket );
  END AU_GroupValue_Read_Req;

(*--------------------------------------------------------------------------------*)

  PUBLIC VIRTUAL PROCEDURE AU_GroupValue_Read_Con( Status : knx_status.TKNXStackStatus );
  VAR
    CurrentState : TObjectState;
  BEGIN
    IF knx_def.TA_ObjectFlags{knx_def.aofCommunicated, knx_def.aofUpdate} * Flags <> knx_def.TA_ObjectFlags{knx_def.aofCommunicated, knx_def.aofUpdate} THEN
      RETURN;
    END;

    Lock();
    State := State - TObjectState{osTransmitting} + TObjectState{osTransmitted};
    CurrentState := State;
    IF Status <> knx_status.essOK THEN // errorneous request kills reading
      State := State - TObjectState{osTransmitted, osReading};
    END;
    Unlock();

    ValueReadRequestSent( Status, CurrentState );
  END AU_GroupValue_Read_Con;

(*--------------------------------------------------------------------------------*)

  PUBLIC VIRTUAL PROCEDURE AU_GroupValue_Read_Res( Status : knx_status.TKNXStackStatus; CONST PPacket : knx_def.TPPacket );
  VAR
    CurrentInitReadState : TInitReadState;
    CurrentState : TObjectState;
    LValue : knx_def.TValue;
    eq : BOOLEAN;
  BEGIN
    IF knx_def.TA_ObjectFlags{knx_def.aofCommunicated, knx_def.aofUpdate} * Flags <> knx_def.TA_ObjectFlags{knx_def.aofCommunicated, knx_def.aofUpdate} THEN
      RETURN;

    ELSIF Status = knx_status.essOK THEN
      LValue.SetType( Value.GetType());
      PPacket^.ToValue( OUT LValue );

      Lock();
      eq := Value.Equals( LValue );
      IF eq THEN
        State := State - TObjectState{osTransmitting, osChanged} + TObjectState{osTransmitted, osUpdated};
      ELSE
        State := State - TObjectState{osTransmitting} + TObjectState{osTransmitted, osUpdated, osChanged};
        Value := LValue;
      END;
      CurrentState := State;
      CurrentInitReadState := InitReadState;
      State := State - TObjectState{osTransmitted, osReading, osUpdated, osChanged};
      Unlock();

      ValueRead( knx_status.essOK, CurrentState, CurrentInitReadState );
      ValueUpdated( knx_status.essOK, CurrentState );
    ELSE
      Lock();
      CurrentState := State;
      CurrentInitReadState := InitReadState;
      State := State - TObjectState{osTransmitted, osReading, osUpdated, osChanged};
      Unlock();

      ValueRead( Status, CurrentState, CurrentInitReadState );
    END;

  END AU_GroupValue_Read_Res;

(*--------------------------------------------------------------------------------*)

  PUBLIC VIRTUAL PROCEDURE AU_GroupValue_Write_Ind( CONST PPacket : knx_def.TPPacket );
  VAR
    CurrentState : TObjectState;
    LValue : knx_def.TValue;
    eq : BOOLEAN;
  BEGIN
    IF knx_def.TA_ObjectFlags{knx_def.aofCommunicated, knx_def.aofWritable} * Flags <> knx_def.TA_ObjectFlags{knx_def.aofCommunicated, knx_def.aofWritable} THEN
      RETURN;
    END;

    LValue.SetType( Value.GetType());
    PPacket^.ToValue( OUT LValue );

    Lock();
    eq := Value.Equals( LValue );
    IF eq THEN
      State := State - TObjectState{osChanged} + TObjectState{osUpdated};
    ELSE
      State := State + TObjectState{osUpdated, osChanged};
      Value := LValue;
    END;
    CurrentState := State;
    State := State - TObjectState{osUpdated, osChanged};
    Unlock();

    ValueUpdated( knx_status.essOK, CurrentState );
  END AU_GroupValue_Write_Ind;

(*--------------------------------------------------------------------------------*)

  PUBLIC VIRTUAL PROCEDURE AU_GroupValue_Write_Con( Status : knx_status.TKNXStackStatus );
  VAR
    CurrentState : TObjectState;
  BEGIN
    IF knx_def.TA_ObjectFlags{knx_def.aofCommunicated, knx_def.aofTransmit} * Flags <> knx_def.TA_ObjectFlags{knx_def.aofCommunicated, knx_def.aofTransmit} THEN
      RETURN;
    END;

    Lock();
    State := State - TObjectState{osTransmitting} + TObjectState{osTransmitted};
    CurrentState := State;
    State := State - TObjectState{osTransmitted, osWriting};
    Unlock();

    ValueWritten( Status, CurrentState );
  END AU_GroupValue_Write_Con;

(*--------------------------------------------------------------------------------*)

  PUBLIC VIRTUAL PROPERTY ReadAddress GET : knx_def.TAddress;
  VAR
    Address : knx_def.TAddress;
    PGroup : TPAU_Group;
    b : BOOLEAN;
  BEGIN
    b := Groups.GetFirst( OUT PGroup );
    WHILE b AND NOT PGroup^.ReadFlag DO
      b := Groups.NextOf( PGroup, OUT PGroup );
    END;
    IF b THEN
      Address := PGroup^.Address;
    ELSIF Groups.GetFirst( OUT PGroup ) THEN
      Address := PGroup^.Address;
    ELSE
      Address.SetAddressType( knx_def.addressUnknown );
    END;
    RETURN Address;
  END ReadAddress;

(*--------------------------------------------------------------------------------*)

  PUBLIC PROPERTY ReadAddress SET( CONST Address : knx_def.TAddress );
  BEGIN
    SetReadFlag( Address, TRUE );
  END ReadAddress;

(*--------------------------------------------------------------------------------*)

  PUBLIC PROPERTY SendAddress GET : knx_def.TAddress;
  VAR
    Address : knx_def.TAddress;
    PGroup : TPAU_Group;
  BEGIN
    IF Groups.GetFirst( OUT PGroup ) THEN
      Address := PGroup^.Address;
    ELSE
      Address.SetAddressType( knx_def.addressUnknown );
    END;
    RETURN Address;
  END SendAddress;

(*--------------------------------------------------------------------------------*)

  PUBLIC PROPERTY SendAddress SET( CONST Address : knx_def.TAddress );
  VAR
    PGroup : TPAU_Group;
    b : BOOLEAN;
  BEGIN
    b := Groups.GetFirst( OUT PGroup );
    IF b AND PGroup^.Address.Equals( Address ) THEN
      RETURN;
    END;
    WHILE b AND NOT PGroup^.Address.Equals( Address ) DO
      b := Groups.NextOf( PGroup, OUT PGroup );
    END; // WHILE
    IF b THEN // address found
      Groups.Remove( PGroup );
      Groups.InsertFirst( PGroup );
    END;
  END SendAddress;

(*--------------------------------------------------------------------------------*)

  PUBLIC PROPERTY PromiscuousAddress GET : knx_def.TAddress;
  BEGIN
    RETURN prAddress;
  END PromiscuousAddress;

(*--------------------------------------------------------------------------------*)

  PUBLIC PROPERTY PromiscuousAddress SET( CONST Address : knx_def.TAddress );
  BEGIN
    prAddress := Address;
  END PromiscuousAddress;

(*--------------------------------------------------------------------------------*)

  PUBLIC PROPERTY Promiscuous GET : BOOLEAN;
  BEGIN
    RETURN knx_def.aofPromiscuous IN Flags;
  END Promiscuous;

(*--------------------------------------------------------------------------------*)

  PUBLIC PROCEDURE GetFlags() : knx_def.TA_ObjectFlags;
  BEGIN
    RETURN Flags;
  END GetFlags;

(*--------------------------------------------------------------------------------*)

  PUBLIC PROCEDURE SetFlags( _Flags : knx_def.TA_ObjectFlags );
  BEGIN
    Flags := _Flags;
  END SetFlags;

(*--------------------------------------------------------------------------------*)

  PUBLIC PROCEDURE GetSendFlag( CONST Address : knx_def.TAddress; VAR SendFlag : BOOLEAN ) : BOOLEAN;
  VAR
    PGroup : TPAU_Group;
  BEGIN
    IF NOT Groups.GetFirst( OUT PGroup ) THEN
      RETURN FALSE;
    ELSIF PGroup^.Address.Equals( Address ) THEN
      SendFlag := TRUE;
    ELSE
      SendFlag := FALSE;
    END;
    RETURN TRUE;
  END GetSendFlag;

(*--------------------------------------------------------------------------------*)

  PUBLIC PROCEDURE SetSendFlag( CONST Address : knx_def.TAddress; SendFlag : BOOLEAN ) : BOOLEAN;
  VAR
    PGroup : TPAU_Group;
    b : BOOLEAN;
  BEGIN
    b := Groups.GetFirst( OUT PGroup );
    IF b AND PGroup^.Address.Equals( Address ) THEN
      IF NOT SendFlag THEN
        Groups.Remove( PGroup );
        Groups.Append( PGroup );
      END;
      RETURN TRUE;
    END;
    SendAddress := Address;
    RETURN TRUE;
  END SetSendFlag;

(*--------------------------------------------------------------------------------*)

  PUBLIC PROCEDURE GetReadFlag( CONST Address : knx_def.TAddress; VAR ReadFlag : BOOLEAN ) : BOOLEAN;
  VAR
    PGroup : TPAU_Group;
    b : BOOLEAN;
  BEGIN
    b := Groups.GetFirst( OUT PGroup );
    WHILE b AND NOT PGroup^.Address.Equals( Address ) DO
      b := Groups.NextOf( PGroup, OUT PGroup );
    END;
    IF b THEN
      ReadFlag := PGroup^.ReadFlag;
    END;
    RETURN b;
  END GetReadFlag;

(*--------------------------------------------------------------------------------*)

  PUBLIC PROCEDURE SetReadFlag( CONST Address : knx_def.TAddress; ReadFlag : BOOLEAN ) : BOOLEAN;
  VAR
    PGroup : TPAU_Group;
    PPrevious : TPAU_Group;
    b : BOOLEAN;
  BEGIN
    PPrevious := NIL;
    b := Groups.GetFirst( OUT PGroup );
    WHILE b AND NOT PGroup^.Address.Equals( Address ) DO
      IF PGroup^.ReadFlag THEN
        PPrevious := PGroup;
      END;
      PGroup^.ReadFlag := FALSE;
      b := Groups.NextOf( PGroup, OUT PGroup );
    END;
    IF b THEN
      PGroup^.ReadFlag := ReadFlag;
    ELSIF PPrevious <> NIL THEN
      PPrevious^.ReadFlag := TRUE;
    END;
    RETURN b;
  END SetReadFlag;

(*--------------------------------------------------------------------------------*)

  PUBLIC PROCEDURE GetClass() : knx_def.TPriority;
  BEGIN
    RETURN Class;
  END GetClass;

(*--------------------------------------------------------------------------------*)

  PUBLIC PROCEDURE SetClass( _Class : knx_def.TPriority );
  BEGIN
    Class := _Class;
  END SetClass;

(*--------------------------------------------------------------------------------*)

  PUBLIC PROCEDURE AddAddress( SendFlag : BOOLEAN; UpdateWholeStack : BOOLEAN; CONST Address : knx_def.TAddress );
  VAR
    PGroup : TPAU_Group;
    b : BOOLEAN;
  BEGIN
    b := Groups.GetFirst( OUT PGroup );
    WHILE b AND NOT PGroup^.Address.Equals( Address ) DO
      b := Groups.NextOf( PGroup, OUT PGroup );
    END; // WHILE
    IF NOT b THEN // address does not exist yet
      // create self data entry
      NEW( PGroup );
      PGroup^.Address := Address;
      IF SendFlag THEN
        Groups.InsertFirst( PGroup );
      ELSE
        Groups.Append( PGroup );
      END;
      // create application data entry
      IF PExecutive <> NIL THEN
        PExecutive^.A_Subscribe( UpdateWholeStack, Address, ADR( SELF ));
      END;
    END;
  END AddAddress;

(*--------------------------------------------------------------------------------*)

  PUBLIC PROCEDURE RemoveAddress( UpdateWholeStack : BOOLEAN; CONST Address : knx_def.TAddress );
  VAR
    PGroup : TPAU_Group;
    b : BOOLEAN;
  BEGIN
    b := Groups.GetFirst( OUT PGroup );
    WHILE b AND NOT PGroup^.Address.Equals( Address ) DO
      b := Groups.NextOf( PGroup, OUT PGroup );
    END; // WHILE
    IF b THEN // address found
      Groups.Delete( PGroup );
      // remove application data entry
      IF PExecutive <> NIL THEN
        PExecutive^.A_Unsubscribe( UpdateWholeStack, Address, ADR( SELF ));
      END;
    END;
  END RemoveAddress;

(*--------------------------------------------------------------------------------*)

  PUBLIC PROCEDURE HaveAddress( CONST Address : knx_def.TAddress ) : BOOLEAN;
  VAR
    PGroup : TPAU_Group;
    b : BOOLEAN;
  BEGIN
    b := Groups.GetFirst( OUT PGroup );
    WHILE b AND NOT PGroup^.Address.Equals( Address ) DO
      b := Groups.NextOf( PGroup, OUT PGroup );
    END; // WHILE
    RETURN b;
  END HaveAddress;

(*--------------------------------------------------------------------------------*)

  PUBLIC PROCEDURE SubscribePromiscuous();
  VAR
    prl : knx_stack.TprLength;
  BEGIN
    IF eit2prl( Value.GetType(), prl ) THEN
      PExecutive^.A_SubscribePromiscuous( prl, ADR( SELF ));
    END;
  END SubscribePromiscuous;

(*--------------------------------------------------------------------------------*)

  PUBLIC PROCEDURE UnsubscribePromiscuous();
  VAR
    prl : knx_stack.TprLength;
  BEGIN
    IF eit2prl( Value.GetType(), prl ) THEN
      PExecutive^.A_UnsubscribePromiscuous( prl, ADR( SELF ));
    END;
  END UnsubscribePromiscuous;

(*--------------------------------------------------------------------------------*)

  PUBLIC PROCEDURE EnumerateAddress( VAR EnumerationState : PTR; VAR Address : knx_def.TAddress ) : BOOLEAN;
  VAR
    PGroup : TPAU_Group;
  BEGIN
    IF EnumerationState = 0 THEN
      IF NOT Groups.GetFirst( OUT PGroup ) THEN
        RETURN FALSE;
      END;
    ELSIF NOT Groups.Contains( TPAU_Group( EnumerationState )) OR NOT Groups.NextOf( PGroup, OUT PGroup ) THEN
      RETURN FALSE;
    END;
    EnumerationState := PGroup;
    Address := PGroup^.Address;
    RETURN TRUE;
  END EnumerateAddress;

(*--------------------------------------------------------------------------------*)

  PUBLIC PROCEDURE SetValue( CONST _Value : knx_def.TValue; OUT Changed : BOOLEAN ) : knx_status.TKNXStackStatus;
  VAR
    Result : knx_status.TKNXStackStatus;
  BEGIN
    Lock();
    Changed := NOT Value.Equals( _Value );
    Value.CopyFrom( _Value );
    Result := Transmit();
    Unlock();
    RETURN Result;
  END SetValue;

(*--------------------------------------------------------------------------------*)

  PUBLIC PROCEDURE GetValue( OUT _Value : knx_def.TValue; UseCached, ForceReadIgnoringObjectFlags : BOOLEAN ) : knx_status.TKNXStackStatus;
  VAR
    b : BOOLEAN;
    PGroup : TPAU_Group;
    Result : knx_status.TKNXStackStatus := knx_status.essOK;
  BEGIN
    Lock();

    IF knx_def.aofPromiscuous IN Flags THEN
      _Value.CopyFrom( Value );

    ELSIF NOT Groups.GetFirst( OUT PGroup ) THEN
      Unlock();
      RETURN knx_status.essAU_NoAddress;

    ELSIF UseCached THEN
      _Value.CopyFrom( Value );

    ELSIF ForceReadIgnoringObjectFlags OR ( knx_def.TA_ObjectFlags{knx_def.aofCommunicated, knx_def.aofForceRead} * Flags = knx_def.TA_ObjectFlags{knx_def.aofCommunicated, knx_def.aofForceRead} ) THEN
      b := TRUE;
      WHILE b AND NOT PGroup^.ReadFlag DO
        b := Groups.NextOf( PGroup, OUT PGroup );
      END;
      IF NOT b THEN // ReadFlag not set, correct self
        Groups.GetFirst( OUT PGroup );
        PGroup^.ReadFlag := TRUE;
      END;
      IF ForceReadIgnoringObjectFlags THEN
        State := State + TObjectState{osTransmitting}; // this is NOT synchronous reading
      ELSE
        State := State + TObjectState{osTransmitting, osReading};
      END;
      Result := InitiateGetValue( PGroup^.Address );

    ELSE
      _Value.CopyFrom( Value );
    END;

    Unlock();
    RETURN Result;
  END GetValue;

(*--------------------------------------------------------------------------------*)

   PUBLIC PROCEDURE Transmit() : knx_status.TKNXStackStatus;
   VAR
      Address : knx_def.TAddress;
      PGroup : TPAU_Group;
      Result : knx_status.TKNXStackStatus;
   BEGIN
      Lock();
   
      IF knx_def.aofPromiscuous IN Flags THEN
         Address := PromiscuousAddress;
      ELSIF NOT Groups.GetFirst( OUT PGroup ) THEN
         Unlock();
         RETURN knx_status.essAU_NoAddress;
      ELSIF knx_def.TA_ObjectFlags{knx_def.aofCommunicated, knx_def.aofTransmit} * Flags <> knx_def.TA_ObjectFlags{knx_def.aofCommunicated, knx_def.aofTransmit} THEN
         Unlock();
         RETURN knx_status.essAU_TransmitDisallowed;
      ELSE
         Address := PGroup^.Address;
      END;

      State := State + TObjectState{osTransmitting, osWriting};
      Result := InitiateTransmit( Address, Value );

      Unlock();
      RETURN Result;
   END Transmit;

(*--------------------------------------------------------------------------------*)

  PUBLIC PROCEDURE InitiateTransmit( CONST Address : knx_def.TAddress; CONST Value : knx_def.TValue ) : knx_status.TKNXStackStatus;
  VAR
    LPacket : knx_def.TPacket;
  BEGIN
    LPacket.FromValue( Value );
    Executive()^.A_GroupValue_Write_Req( ADR( SELF ), Address, Class, LPacket );
    RETURN knx_status.essAU_Pending;
  END InitiateTransmit;

(*--------------------------------------------------------------------------------*)

  PUBLIC PROCEDURE InitiateGetValue( CONST Address : knx_def.TAddress ) : knx_status.TKNXStackStatus;
  BEGIN
      Executive()^.A_GroupValue_Read_Req( ADR( SELF ), Address, Class );
      RETURN knx_status.essAU_Pending;
  END InitiateGetValue;

(*--------------------------------------------------------------------------------*)

   PUBLIC PROPERTY InitReadState GET : TInitReadState; // should be sync
   BEGIN
      Lock();
      IF osInitReadPending IN State THEN
         Unlock();
         RETURN irsPending;
      ELSIF osInitReadRepeat IN State THEN
         Unlock();
         RETURN irsWillRepeat;
      ELSE
         Unlock();
         RETURN irsUnknown;
      END;
   END InitReadState;

(*--------------------------------------------------------------------------------*)

   PUBLIC PROPERTY InitReadState SET( Value : TInitReadState ); // should be sync
   BEGIN
      Lock();
      IF Value = irsPending THEN
         State := State - TObjectState{osInitReadRepeat} + TObjectState{osInitReadPending};
      ELSIF Value = irsWillRepeat THEN
         State := State - TObjectState{osInitReadPending} + TObjectState{osInitReadRepeat};
      ELSE
         State := State - TObjectState{osInitReadPending, osInitReadRepeat};
      END;
      Unlock();
   END InitReadState;

(*--------------------------------------------------------------------------------*)

   PUBLIC PROPERTY CommunicationState GET : TObjectState; // should be sync
   VAR
      Result : TObjectState;
   BEGIN
      Lock();
      Result := State;
      Unlock();
      RETURN Result;
   END CommunicationState;

(*--------------------------------------------------------------------------------*)

   PUBLIC PROPERTY Reading GET : BOOLEAN; // should be sync
   VAR
      Result : BOOLEAN;
   BEGIN
      Lock();
      Result := TObjectState{osInitReadPending, osReading} * State <> TObjectState{};
      Unlock();
      RETURN Result;
   END Reading;

(*--------------------------------------------------------------------------------*)

   PUBLIC PROPERTY Writing GET : BOOLEAN; // should be sync
   VAR
      Result : BOOLEAN;
   BEGIN
      Lock();
      Result := osWriting IN State;
      Unlock();
      RETURN Result;
   END Writing;

(*--------------------------------------------------------------------------------*)

   PUBLIC PROCEDURE CancelIO();
   BEGIN
      Lock();
      State := State - TObjectState{osTransmitting, osTransmitted, osReading, osWriting, osUpdated, osChanged};
      Unlock();
   END CancelIO;

(*--------------------------------------------------------------------------------*)

  INTERNAL VIRTUAL PROCEDURE ValueReadRequestSent( Status : knx_status.TKNXStackStatus; CurrentState : TObjectState );
  BEGIN
  END ValueReadRequestSent;

(*--------------------------------------------------------------------------------*)

  INTERNAL VIRTUAL PROCEDURE ValueRead( Status : knx_status.TKNXStackStatus; CurrentState : TObjectState; CurrentInitReadState : TInitReadState );
  BEGIN
  END ValueRead;

(*--------------------------------------------------------------------------------*)

  INTERNAL VIRTUAL PROCEDURE ValueUpdated( Status : knx_status.TKNXStackStatus; CurrentState : TObjectState );
  BEGIN
  END ValueUpdated;

(*--------------------------------------------------------------------------------*)

  INTERNAL VIRTUAL PROCEDURE ValueWritten( Status : knx_status.TKNXStackStatus; CurrentState : TObjectState );
  BEGIN
  END ValueWritten;

(*--------------------------------------------------------------------------------*)

  PRIVATE PROCEDURE eit2prl( eit : knx_def.TKNXType; VAR prl : knx_stack.TprLength ) : BOOLEAN;
  BEGIN
    CASE eit OF
    | knx_def.eitSwitch, knx_def.eitIncrease, knx_def.eitMove, knx_def.eitPriority :
      prl := knx_stack.prl1;
    | knx_def.eitScaling, knx_def.eitScaling255, knx_def.eitChar, knx_def.eit8bit :
      prl := knx_stack.prl2;
    | knx_def.eitValue, knx_def.eit16bit :
      prl := knx_stack.prl3;
    | knx_def.eitTime, knx_def.eitDate :
      prl := knx_stack.prl4;
    | knx_def.eitFloat, knx_def.eit32bit :
      prl := knx_stack.prl5;
    | knx_def.eitString :
      prl := knx_stack.prl15;
    ELSE
      RETURN FALSE;
    END;
    RETURN TRUE;
  END eit2prl;

(*--------------------------------------------------------------------------------*)

  PRIVATE PROCEDURE UpdateStack();
  BEGIN
    IF PExecutive <> NIL THEN
      PExecutive^.Update_L_Layer();
    END;
  END UpdateStack;

(*--------------------------------------------------------------------------------*)

BEGIN
  PExecutive := NIL;
  Class := knx_def.priorityNormal;
  State := TObjectState{osUnknown};
  Flags := knx_def.TA_ObjectFlags{};
END CUserObject;

(*================================================================================*)

END knx_user.