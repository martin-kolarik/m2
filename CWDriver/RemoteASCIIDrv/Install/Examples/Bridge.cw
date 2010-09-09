directories
  '*.log' = 'c:\';
end_directories;

settings
  operation_mode = real_time;
  startup_options
    call_procedures = false;
    activate_receivers = false;
    output_action = none;
  end_startup_options;
  independent_procedure_execution = true;
end_settings;

driver
  nms {driver = 'remoteasciidrv.dll'; parameter_file = 'RemoteASCIIDrv.par'};
  nmc {driver = 'remoteasciidrv.dll'; parameter_file = 'RemoteASCIIDrv.par'};
end_driver;

data
end_data;

instrument

  panel panel_2;
    gui
      owner = background;
      position = 215, 115, 320, 355;
      window
        type = normal;
      end_window;
    end_gui;
  end_panel;

  switch switch_1;
    gui
      owner = panel_2;
      position = 170, 95, 92, 30;
      window
        disable = zoom, maximize;
      end_window;
    end_gui;
    mode = text_button;
    true_text = 'server disconnect';
    false_text = 'server disconnect';

    procedure OnOutput( b : boolean );
    begin
      core.DriverQueryProc( 'nms', 'server disconnect', 0 );
    end_procedure;

  end_switch;

  string_control string_control_1;
    gui
      owner = panel_2;
      position = 15, 100, 135, 18;
    end_gui;
    init_value = '474554202F20485454502F312E300D0A0D0A';

    procedure OnOutput( s : string );
    var
      error : string;
    begin
      (*
      core.DriverQueryProc( 'nms', 'client send ' + s, &error );
      core.DebugOutput( 'Send error: ', error );
      *)

      core.DriverQueryProc( 'nms', 'ClearTxQueue', 0 );
      core.DriverQueryProc( 'nms', 'SetTxIndex', 10 );
      core.DriverQueryProc( 'nms', 'SetTxIndex', 0 );
      core.DriverQueryProc( 'nms', 'SetRxIndex', 10 );
      core.DriverQueryProc( 'nms', 'SetRxIndex', 0 );

      core.DriverQueryProc( 'nms', 'PutCharSeq', 71 );
      (*
      core.DriverQueryProc( 'nms', 'PutCharSeq', 'G' );
      *)
      core.DriverQueryProc( 'nms', 'PutCharSeq', 'E' );
      core.DriverQueryProc( 'nms', 'PutCharSeq', 'T' );
      core.DriverQueryProc( 'nms', 'PutCharSeq', ' ' );
      core.DriverQueryProc( 'nms', 'PutCharSeq', '/' );
      core.DriverQueryProc( 'nms', 'PutCharSeq', ' ' );
      core.DriverQueryProc( 'nms', 'PutCharSeq', 'H' );
      core.DriverQueryProc( 'nms', 'PutCharSeq', 'T' );
      core.DriverQueryProc( 'nms', 'PutCharSeq', 'T' );
      core.DriverQueryProc( 'nms', 'PutCharSeq', 'P' );
      core.DriverQueryProc( 'nms', 'PutCharSeq', '/' );
      core.DriverQueryProc( 'nms', 'PutCharSeq', '1' );
      core.DriverQueryProc( 'nms', 'PutCharSeq', '.' );
      core.DriverQueryProc( 'nms', 'PutCharSeq', '0' );
      core.DriverQueryProc( 'nms', 'PutCharSeq', '#0D' );
      core.DriverQueryProc( 'nms', 'PutCharSeq', '#0A' );
      core.DriverQueryProc( 'nms', 'PutCharSeq', '#0D' );
      core.DriverQueryProc( 'nms', 'PutCharSeq', '#0A' );

      core.DriverQueryProc( 'nms', 'SendAsync', 18 );
    end_procedure;

  end_string_control;

  switch switch_1;
    gui
      owner = panel_2;
      position = 170, 50, 90, 30;
      window
        disable = zoom, maximize;
      end_window;
    end_gui;
    mode = text_button;
    true_text = 'server stop_listen';
    false_text = 'server stop_listen';

    procedure OnOutput( b : boolean );
    begin
      core.DriverQueryProc( 'nms', 'server stop_listen', 0 );
    end_procedure;

  end_switch;

  switch switch_1;
    gui
      owner = panel_2;
      position = 70, 50, 80, 31;
      window
        disable = zoom, maximize;
      end_window;
    end_gui;
    mode = text_button;
    true_text = 'server listen';
    false_text = 'server listen';

    procedure OnOutput( b : boolean );
    var
      s : string;
    begin
      core.DriverQueryProc( 'nms', 'server listen 3001', &s );
      core.DebugOutput( 'listen:', s );
    end_procedure;

  end_switch;

  string_control string_control_1;
    gui
      owner = panel_2;
      position = 15, 210, 135, 18;
    end_gui;
    init_value = '474554202F20485454502F312E300D0A0D0A';

    procedure OnOutput( s : string );
    var
      error : string;
    begin
      (*
      core.DriverQueryProc( 'nmc', 'client send ' + s, &error );
      core.DebugOutput( 'Send error: ', error );
      *)

      core.DriverQueryProc( 'nmc', 'ClearTxQueue', 0 );
      core.DriverQueryProc( 'nmc', 'SetTxIndex', 10 );
      core.DriverQueryProc( 'nmc', 'SetTxIndex', 0 );
      core.DriverQueryProc( 'nmc', 'SetRxIndex', 10 );
      core.DriverQueryProc( 'nmc', 'SetRxIndex', 0 );

(*
      core.DriverQueryProc( 'nmc', 'PutCharSeq', 71 );
      core.DriverQueryProc( 'nmc', 'PutCharSeq', 'G' );
      core.DriverQueryProc( 'nmc', 'PutCharSeq', 'E' );
      core.DriverQueryProc( 'nmc', 'PutCharSeq', 'T' );
      core.DriverQueryProc( 'nmc', 'PutCharSeq', ' ' );
      core.DriverQueryProc( 'nmc', 'PutCharSeq', '/' );
      core.DriverQueryProc( 'nmc', 'PutCharSeq', ' ' );
      core.DriverQueryProc( 'nmc', 'PutCharSeq', 'H' );
      core.DriverQueryProc( 'nmc', 'PutCharSeq', 'T' );
      core.DriverQueryProc( 'nmc', 'PutCharSeq', 'T' );
      core.DriverQueryProc( 'nmc', 'PutCharSeq', 'P' );
      core.DriverQueryProc( 'nmc', 'PutCharSeq', '/' );
      core.DriverQueryProc( 'nmc', 'PutCharSeq', '1' );
      core.DriverQueryProc( 'nmc', 'PutCharSeq', '.' );
      core.DriverQueryProc( 'nmc', 'PutCharSeq', '0' );
      core.DriverQueryProc( 'nmc', 'PutCharSeq', '#0D' );
      core.DriverQueryProc( 'nmc', 'PutCharSeq', '#0A' );
      core.DriverQueryProc( 'nmc', 'PutCharSeq', '#0D' );
      core.DriverQueryProc( 'nmc', 'PutCharSeq', '#0A' );

      core.DriverQueryProc( 'nmc', 'SendAsync', 18 );
*)
      core.DriverQueryProc( 'nmc', 'PutCharSeq', '#1B' );
      core.DriverQueryProc( 'nmc', 'PutCharSeq', '#01' );
      core.DriverQueryProc( 'nmc', 'PutCharSeq', '#03' );
      core.DriverQueryProc( 'nmc', 'PutCharSeq', '#01' );
      core.DriverQueryProc( 'nmc', 'PutCharSeq', '#03' );
      core.DriverQueryProc( 'nmc', 'PutCharSeq', '#FC' );
      core.DriverQueryProc( 'nmc', 'SendAsync', 6 );
    end_procedure;

  end_string_control;

  switch switch_1;
    gui
      owner = panel_2;
      position = 170, 160, 88, 30;
      window
        disable = zoom, maximize;
      end_window;
    end_gui;
    mode = text_button;
    true_text = 'client disconnect';
    false_text = 'client disconnect';

    procedure OnOutput( b : boolean );
    begin
      core.DriverQueryProc( 'nmc', 'client disconnect', 0 );
    end_procedure;

  end_switch;

  switch switch_1;
    gui
      owner = panel_2;
      position = 70, 160, 80, 31;
      window
        disable = zoom, maximize;
      end_window;
    end_gui;
    mode = text_button;
    true_text = 'client connect';
    false_text = 'client connect';

    procedure OnOutput( b : boolean );
    var
      s : string;
    begin
    (*
      core.DriverQueryProc( 'nmc', 'client connect 10.78.0.8:6005', &s );
     *)
      core.DriverQueryProc( 'nmc', 'client connect 192.168.84.54:3001', &s );
      core.DebugOutput( 'connect: ', s );
    end_procedure;

  end_switch;

  program excptc;
    activity
      driver = nmc;
    end_activity;

    procedure OnActivate();
    const
      delimiter = ' ';
    var
      c : cardinal;
      ch : cardinal;
      error : cardinal;
      i : cardinal;
      s : string;
      t : string;
      T : string;
    begin
      core.DriverQueryProc( 'nmc', 'GetExcStatus', &c );

      switch c of
      case 0; (* ok *)
        core.DebugOutput( 'C AS OK' );

      case 1;
        core.DriverQueryProc( 'nmc', 'GetErrorCode', &c );
        core.DebugOutput( 'C AS RX Error: ', c );

      case 2;
        core.DriverQueryProc( 'nmc', 'GetErrorCode', &c );
        core.DebugOutput( 'C AS TX Error: ', c );

      case 3;
        core.DebugOutput( 'C AS Data Received' );

        core.DriverQueryProc( 'nmc', 'GetRxCount', &c );
        core.DebugOutput( '   C Count: ', c );
        if c >= 6 then

          core.DriverQueryProc( 'nmc', 'SetRxIndex', 0 );
          core.DriverQueryProc( 'nms', 'SetTxIndex', 0 );

          if c > 0 then
            s := '';
            for i := 0 to c-1 do
              core.DriverQueryProc( 'nmc', 'GetCharSeq', &t );
              core.DriverQueryProc( 'nms', 'PutCharSeq', t );
  
              core.DriverQueryProc( 'nmc', 'GetResult', &error );
              if error <> 0 then
                core.DebugOutput( 'C GetCharSeq error: ', error );
              end;
  
              s := s + t;
              if (i+1) % 100 = 0 then
                core.DebugOutput( 'C Data: ', s );
                s := '';
              end;
            end; (* for *)
            core.DebugOutput( 'C Data: ', s );
  
            core.DriverQueryProc( 'nms', 'SendAsync', c );
  
            core.DriverQueryProc( 'nmc', 'PopRxQueue', c );
          end;
  
        end;

      case 4;
        core.DriverQueryProc( 'nmc', 'GetErrorCode', &c );
        core.DebugOutput( 'C AS Driver Error:', c );

      case 100; (* connect *)
        core.DriverQueryProc( 'nmc', 'GetErrorCode', &c );
        core.DebugOutput( 'C AS Connect:', c );

      case 101; (* disconnect *)
        core.DriverQueryProc( 'nmc', 'GetErrorCode', &c );
        core.DebugOutput( 'C AS Disconnect:', c );

      case 102; (* accept *)
        core.DriverQueryProc( 'nmc', 'GetErrorCode', &c );
        core.DebugOutput( 'C AS Accept:', c );

      end; (* case *)

      core.DriverQueryProc( 'nmc', 'EnableException', 0 );

    end_procedure;
  end_program;

  program excpts;
    activity
      driver = nms;
    end_activity;

    procedure OnActivate();
    const
      delimiter = ' ';
    var
      c : cardinal;
      ch : cardinal;
      error : cardinal;
      i : cardinal;
      s : string;
      t : string;
      T : string;
    begin
      core.DriverQueryProc( 'nms', 'GetExcStatus', &c );

      switch c of
      case 0; (* ok *)
        core.DebugOutput( 'S AS OK' );

      case 1;
        core.DriverQueryProc( 'nms', 'GetErrorCode', &c );
        core.DebugOutput( 'S AS RX Error: ', c );

      case 2;
        core.DriverQueryProc( 'nms', 'GetErrorCode', &c );
        core.DebugOutput( 'S AS TX Error: ', c );

      case 3;
        core.DebugOutput( 'S AS Data Received' );

        core.DriverQueryProc( 'nms', 'GetRxCount', &c );
        core.DebugOutput( '   S Count: ', c );
        if c >= 6 then

          core.DriverQueryProc( 'nms', 'SetRxIndex', 0 );
          core.DriverQueryProc( 'nmc', 'SetTxIndex', 0 );
  
          if c > 0 then
            s := '';
            for i := 0 to c-1 do
              core.DriverQueryProc( 'nms', 'GetCharSeq', &t );
              core.DriverQueryProc( 'nmc', 'PutCharSeq', t );
  
              core.DriverQueryProc( 'nms', 'GetResult', &error );
              if error <> 0 then
                core.DebugOutput( 'S GetCharSeq error: ', error );
              end;
  
              s := s + t;
              if (i+1) % 100 = 0 then
                core.DebugOutput( 'S Data: ', s );
                s := '';
              end;
            end; (* for *)
            core.DebugOutput( 'S Data: ', s );
            
            core.DriverQueryProc( 'nmc', 'SendAsync', c );
  
            core.DriverQueryProc( 'nms', 'PopRxQueue', c );
          end;

        end;

      case 4;
        core.DriverQueryProc( 'nms', 'GetErrorCode', &c );
        core.DebugOutput( 'S AS Driver Error:', c );

      case 100; (* connect *)
        core.DriverQueryProc( 'nms', 'GetErrorCode', &c );
        core.DebugOutput( 'S AS Connect:', c );

      case 101; (* disconnect *)
        core.DriverQueryProc( 'nms', 'GetErrorCode', &c );
        core.DebugOutput( 'S AS Disconnect:', c );

      case 102; (* accept *)
        core.DriverQueryProc( 'nms', 'GetErrorCode', &c );
        core.DebugOutput( 'S AS Accept:', c );

      end; (* case *)

      core.DriverQueryProc( 'nms', 'EnableException', 0 );

    end_procedure;

  end_program;

end_instrument;

