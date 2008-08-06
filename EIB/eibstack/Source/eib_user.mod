IMPLEMENTATION MODULE eib_user;

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
  Address  : eib_def.TAddress;
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

  PUBLIC PROPERTY Type GET : eib_def.TEIBType;
  BEGIN
     RETURN Value.GetType();
  END Type;

(*--------------------------------------------------------------------------------*)

  PUBLIC PROCEDURE Init( POfStack : eib_stack.TPEIBStack; Type : eib_def.TEIBType; Behaviour : TObjectBehaviour );
  BEGIN
    PExecutive := eib_stack.TPEIBStackApplicationLayer( POfStack^.Layers[ eib_stack.eltApplication ] );
    Value.SetType( Type );
    CASE Behaviour OF
    | obTransmitter :
      SetFlags( eib_def.TA_ObjectFlags{eib_def.aofCommunicated, eib_def.aofTransmit} );
    | obTransmitterWithStatus :
      SetFlags( eib_def.TA_ObjectFlags{eib_def.aofCommunicated, eib_def.aofTransmit, eib_def.aofUpdate, eib_def.aofWritable} );
    | obTracker :
      SetFlags( eib_def.TA_ObjectFlags{eib_def.aofCommunicated, eib_def.aofUpdate, eib_def.aofWritable} );
    | obReader :
      SetFlags( eib_def.TA_ObjectFlags{eib_def.aofCommunicated, eib_def.aofUpdate, eib_def.aofForceRead} );
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

  PUBLIC PROCEDURE Executive() : eib_stack.TPEIBStackApplicationLayer;
  BEGIN
    RETURN PExecutive;
  END Executive;

(*--------------------------------------------------------------------------------*)

  PUBLIC VIRTUAL PROCEDURE AU_GroupValue_Read_Req();
  VAR
    LPacket : eib_def.TPacket;
    PGroup : TPAU_Group;
  BEGIN
    Lock();
    IF NOT Groups.GetFirst( OUT PGroup ) THEN
      Unlock();
      RETURN;
    ELSIF eib_def.TA_ObjectFlags{eib_def.aofCommunicated, eib_def.aofReadable} * Flags <> eib_def.TA_ObjectFlags{eib_def.aofCommunicated, eib_def.aofReadable} THEN
      Unlock();
      RETURN;
    END;
    LPacket.FromValue( Value );
    Unlock();

    // now, response is done to the first address
    Executive()^.A_GroupValue_Read_Res( ADR( SELF ), PGroup^.Address, Class, LPacket );
  END AU_GroupValue_Read_Req;

(*--------------------------------------------------------------------------------*)

  PUBLIC VIRTUAL PROCEDURE AU_GroupValue_Read_Con( Status : eib_status.TEIBStackStatus );
  VAR
    CurrentState : TObjectState;
  BEGIN
    IF eib_def.TA_ObjectFlags{eib_def.aofCommunicated, eib_def.aofUpdate} * Flags <> eib_def.TA_ObjectFlags{eib_def.aofCommunicated, eib_def.aofUpdate} THEN
      RETURN;
    END;

    Lock();
    State := State - TObjectState{osTransmitting} + TObjectState{osTransmitted};
    CurrentState := State;
    IF Status <> eib_status.essOK THEN // errorneous request kills reading
      State := State - TObjectState{osTransmitted, osReading};
    END;
    Unlock();

    ValueReadRequestSent( Status, CurrentState );
  END AU_GroupValue_Read_Con;

(*--------------------------------------------------------------------------------*)

  PUBLIC VIRTUAL PROCEDURE AU_GroupValue_Read_Res( Status : eib_status.TEIBStackStatus; CONST PPacket : eib_def.TPPacket );
  VAR
    CurrentInitReadState : TInitReadState;
    CurrentState : TObjectState;
    LValue : eib_def.TValue;
    eq : BOOLEAN;
  BEGIN
    IF eib_def.TA_ObjectFlags{eib_def.aofCommunicated, eib_def.aofUpdate} * Flags <> eib_def.TA_ObjectFlags{eib_def.aofCommunicated, eib_def.aofUpdate} THEN
      RETURN;

    ELSIF Status = eib_status.essOK THEN
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

      ValueRead( eib_status.essOK, CurrentState, CurrentInitReadState );
      ValueUpdated( eib_status.essOK, CurrentState );
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

  PUBLIC VIRTUAL PROCEDURE AU_GroupValue_Write_Ind( CONST PPacket : eib_def.TPPacket );
  VAR
    CurrentState : TObjectState;
    LValue : eib_def.TValue;
    eq : BOOLEAN;
  BEGIN
    IF eib_def.TA_ObjectFlags{eib_def.aofCommunicated, eib_def.aofWritable} * Flags <> eib_def.TA_ObjectFlags{eib_def.aofCommunicated, eib_def.aofWritable} THEN
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

    ValueUpdated( eib_status.essOK, CurrentState );
  END AU_GroupValue_Write_Ind;

(*--------------------------------------------------------------------------------*)

  PUBLIC VIRTUAL PROCEDURE AU_GroupValue_Write_Con( Status : eib_status.TEIBStackStatus );
  VAR
    CurrentState : TObjectState;
  BEGIN
    IF eib_def.TA_ObjectFlags{eib_def.aofCommunicated, eib_def.aofTransmit} * Flags <> eib_def.TA_ObjectFlags{eib_def.aofCommunicated, eib_def.aofTransmit} THEN
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

  PUBLIC VIRTUAL PROPERTY ReadAddress GET : eib_def.TAddress;
  VAR
    Address : eib_def.TAddress;
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
      Address.SetAddressType( eib_def.addressUnknown );
    END;
    RETURN Address;
  END ReadAddress;

(*--------------------------------------------------------------------------------*)

  PUBLIC PROPERTY ReadAddress SET( CONST Address : eib_def.TAddress );
  BEGIN
    SetReadFlag( Address, TRUE );
  END ReadAddress;

(*--------------------------------------------------------------------------------*)

  PUBLIC PROPERTY SendAddress GET : eib_def.TAddress;
  VAR
    Address : eib_def.TAddress;
    PGroup : TPAU_Group;
  BEGIN
    IF Groups.GetFirst( OUT PGroup ) THEN
      Address := PGroup^.Address;
    ELSE
      Address.SetAddressType( eib_def.addressUnknown );
    END;
    RETURN Address;
  END SendAddress;

(*--------------------------------------------------------------------------------*)

  PUBLIC PROPERTY SendAddress SET( CONST Address : eib_def.TAddress );
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

  PUBLIC PROPERTY PromiscuousAddress GET : eib_def.TAddress;
  BEGIN
    RETURN prAddress;
  END PromiscuousAddress;

(*--------------------------------------------------------------------------------*)

  PUBLIC PROPERTY PromiscuousAddress SET( CONST Address : eib_def.TAddress );
  BEGIN
    prAddress := Address;
  END PromiscuousAddress;

(*--------------------------------------------------------------------------------*)

  PUBLIC PROPERTY Promiscuous GET : BOOLEAN;
  BEGIN
    RETURN eib_def.aofPromiscuous IN Flags;
  END Promiscuous;

(*--------------------------------------------------------------------------------*)

  PUBLIC PROCEDURE GetFlags() : eib_def.TA_ObjectFlags;
  BEGIN
    RETURN Flags;
  END GetFlags;

(*--------------------------------------------------------------------------------*)

  PUBLIC PROCEDURE SetFlags( _Flags : eib_def.TA_ObjectFlags );
  BEGIN
    Flags := _Flags;
  END SetFlags;

(*--------------------------------------------------------------------------------*)

  PUBLIC PROCEDURE GetSendFlag( CONST Address : eib_def.TAddress; VAR SendFlag : BOOLEAN ) : BOOLEAN;
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

  PUBLIC PROCEDURE SetSendFlag( CONST Address : eib_def.TAddress; SendFlag : BOOLEAN ) : BOOLEAN;
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

  PUBLIC PROCEDURE GetReadFlag( CONST Address : eib_def.TAddress; VAR ReadFlag : BOOLEAN ) : BOOLEAN;
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

  PUBLIC PROCEDURE SetReadFlag( CONST Address : eib_def.TAddress; ReadFlag : BOOLEAN ) : BOOLEAN;
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

  PUBLIC PROCEDURE GetClass() : eib_def.TPriority;
  BEGIN
    RETURN Class;
  END GetClass;

(*--------------------------------------------------------------------------------*)

  PUBLIC PROCEDURE SetClass( _Class : eib_def.TPriority );
  BEGIN
    Class := _Class;
  END SetClass;

(*--------------------------------------------------------------------------------*)

  PUBLIC PROCEDURE AddAddress( SendFlag : BOOLEAN; UpdateWholeStack : BOOLEAN; CONST Address : eib_def.TAddress );
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

  PUBLIC PROCEDURE RemoveAddress( UpdateWholeStack : BOOLEAN; CONST Address : eib_def.TAddress );
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

  PUBLIC PROCEDURE HaveAddress( CONST Address : eib_def.TAddress ) : BOOLEAN;
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
    prl : eib_stack.TprLength;
  BEGIN
    IF eit2prl( Value.GetType(), prl ) THEN
      PExecutive^.A_SubscribePromiscuous( prl, ADR( SELF ));
    END;
  END SubscribePromiscuous;

(*--------------------------------------------------------------------------------*)

  PUBLIC PROCEDURE UnsubscribePromiscuous();
  VAR
    prl : eib_stack.TprLength;
  BEGIN
    IF eit2prl( Value.GetType(), prl ) THEN
      PExecutive^.A_UnsubscribePromiscuous( prl, ADR( SELF ));
    END;
  END UnsubscribePromiscuous;

(*--------------------------------------------------------------------------------*)

  PUBLIC PROCEDURE EnumerateAddress( VAR EnumerationState : PTR; VAR Address : eib_def.TAddress ) : BOOLEAN;
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

  PUBLIC PROCEDURE SetValue( CONST _Value : eib_def.TValue ) : eib_status.TEIBStackStatus;
  VAR
    Result : eib_status.TEIBStackStatus;
  BEGIN
    Lock();
    Value.CopyFrom( _Value );
    Result := Transmit();
    Unlock();
    RETURN Result;
  END SetValue;

(*--------------------------------------------------------------------------------*)

  PUBLIC PROCEDURE GetValue( OUT _Value : eib_def.TValue; UseCached, ForceReadIgnoringObjectFlags : BOOLEAN ) : eib_status.TEIBStackStatus;
  VAR
    b : BOOLEAN;
    PGroup : TPAU_Group;
    Result : eib_status.TEIBStackStatus := eib_status.essOK;
  BEGIN
    Lock();

    IF eib_def.aofPromiscuous IN Flags THEN
      _Value.CopyFrom( Value );

    ELSIF NOT Groups.GetFirst( OUT PGroup ) THEN
      Unlock();
      RETURN eib_status.essAU_NoAddress;

    ELSIF UseCached THEN
      _Value.CopyFrom( Value );

    ELSIF ForceReadIgnoringObjectFlags OR ( eib_def.TA_ObjectFlags{eib_def.aofCommunicated, eib_def.aofForceRead} * Flags = eib_def.TA_ObjectFlags{eib_def.aofCommunicated, eib_def.aofForceRead} ) THEN
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

   PUBLIC PROCEDURE Transmit() : eib_status.TEIBStackStatus;
   VAR
      Address : eib_def.TAddress;
      PGroup : TPAU_Group;
      Result : eib_status.TEIBStackStatus;
   BEGIN
      Lock();
   
      IF eib_def.aofPromiscuous IN Flags THEN
         Address := PromiscuousAddress;
      ELSIF NOT Groups.GetFirst( OUT PGroup ) THEN
         Unlock();
         RETURN eib_status.essAU_NoAddress;
      ELSIF eib_def.TA_ObjectFlags{eib_def.aofCommunicated, eib_def.aofTransmit} * Flags <> eib_def.TA_ObjectFlags{eib_def.aofCommunicated, eib_def.aofTransmit} THEN
         Unlock();
         RETURN eib_status.essAU_TransmitDisallowed;
      ELSE
         Address := PGroup^.Address;
      END;

      State := State + TObjectState{osTransmitting, osWriting};
      Result := InitiateTransmit( Address, Value );

      Unlock();
      RETURN Result;
   END Transmit;

(*--------------------------------------------------------------------------------*)

  PUBLIC PROCEDURE InitiateTransmit( CONST Address : eib_def.TAddress; CONST Value : eib_def.TValue ) : eib_status.TEIBStackStatus;
  VAR
    LPacket : eib_def.TPacket;
  BEGIN
    LPacket.FromValue( Value );
    Executive()^.A_GroupValue_Write_Req( ADR( SELF ), Address, Class, LPacket );
    RETURN eib_status.essAU_Pending;
  END InitiateTransmit;

(*--------------------------------------------------------------------------------*)

  PUBLIC PROCEDURE InitiateGetValue( CONST Address : eib_def.TAddress ) : eib_status.TEIBStackStatus;
  BEGIN
      Executive()^.A_GroupValue_Read_Req( ADR( SELF ), Address, Class );
      RETURN eib_status.essAU_Pending;
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

  INTERNAL VIRTUAL PROCEDURE ValueReadRequestSent( Status : eib_status.TEIBStackStatus; CurrentState : TObjectState );
  BEGIN
  END ValueReadRequestSent;

(*--------------------------------------------------------------------------------*)

  INTERNAL VIRTUAL PROCEDURE ValueRead( Status : eib_status.TEIBStackStatus; CurrentState : TObjectState; CurrentInitReadState : TInitReadState );
  BEGIN
  END ValueRead;

(*--------------------------------------------------------------------------------*)

  INTERNAL VIRTUAL PROCEDURE ValueUpdated( Status : eib_status.TEIBStackStatus; CurrentState : TObjectState );
  BEGIN
  END ValueUpdated;

(*--------------------------------------------------------------------------------*)

  INTERNAL VIRTUAL PROCEDURE ValueWritten( Status : eib_status.TEIBStackStatus; CurrentState : TObjectState );
  BEGIN
  END ValueWritten;

(*--------------------------------------------------------------------------------*)

  PRIVATE PROCEDURE eit2prl( eit : eib_def.TEIBType; VAR prl : eib_stack.TprLength ) : BOOLEAN;
  BEGIN
    CASE eit OF
    | eib_def.eitSwitch, eib_def.eitIncrease, eib_def.eitMove, eib_def.eitPriority :
      prl := eib_stack.prl1;
    | eib_def.eitScaling, eib_def.eitScaling255, eib_def.eitChar, eib_def.eit8bit :
      prl := eib_stack.prl2;
    | eib_def.eitValue, eib_def.eit16bit :
      prl := eib_stack.prl3;
    | eib_def.eitTime, eib_def.eitDate :
      prl := eib_stack.prl4;
    | eib_def.eitFloat, eib_def.eit32bit :
      prl := eib_stack.prl5;
    | eib_def.eitString :
      prl := eib_stack.prl15;
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
  Class := eib_def.priorityNormal;
  State := TObjectState{osUnknown};
  Flags := eib_def.TA_ObjectFlags{};
END CUserObject;

(*================================================================================*)

END eib_user.