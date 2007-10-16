IMPLEMENTATION MODULE seriallinki;

(* ====================================================== *)

(*# call( o_a_size=>off,
          o_a_copy=>off,
          convention=>stdcall ) *)

IMPORT
  windows;

IMPORT
  seriallink;

PROCEDURE DllMain( Instance : windows.HINSTANCE;
                   Reason   : windows.DWORD;
                   Reserved : windows.PVOID ): windows.BOOL;
BEGIN
  IF Reason = windows.DLL_PROCESS_ATTACH THEN
  (* Init *)
    seriallink.POpenLinkList := NIL;
  ELSIF Reason = windows.DLL_PROCESS_DETACH THEN
  (* Done *)
  END;
  RETURN windows.True;
END DllMain;

END seriallinki.