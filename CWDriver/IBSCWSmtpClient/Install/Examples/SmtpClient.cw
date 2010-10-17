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
  nm {driver = 'remoteasciidrv.dll'; parameter_file = 'RemoteASCIIDrv.par'};
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
      core.DriverQueryProc( 'nm', 'server disconnect', 0 );
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
      core.DriverQueryProc( 'nm', 'client send ' + s, &error );
      core.DebugOutput( 'Send error: ', error );
      *)

      core.DriverQueryProc( 'nm', 'ClearTxQueue', 0 );
      core.DriverQueryProc( 'nm', 'SetTxIndex', 10 );
      core.DriverQueryProc( 'nm', 'SetTxIndex', 0 );
      core.DriverQueryProc( 'nm', 'SetRxIndex', 10 );
      core.DriverQueryProc( 'nm', 'SetRxIndex', 0 );

      core.DriverQueryProc( 'nm', 'PutCharSeq', 71 );
      (*
      core.DriverQueryProc( 'nm', 'PutCharSeq', 'G' );
      *)
      core.DriverQueryProc( 'nm', 'PutCharSeq', 'E' );
      core.DriverQueryProc( 'nm', 'PutCharSeq', 'T' );
      core.DriverQueryProc( 'nm', 'PutCharSeq', ' ' );
      core.DriverQueryProc( 'nm', 'PutCharSeq', '/' );
      core.DriverQueryProc( 'nm', 'PutCharSeq', ' ' );
      core.DriverQueryProc( 'nm', 'PutCharSeq', 'H' );
      core.DriverQueryProc( 'nm', 'PutCharSeq', 'T' );
      core.DriverQueryProc( 'nm', 'PutCharSeq', 'T' );
      core.DriverQueryProc( 'nm', 'PutCharSeq', 'P' );
      core.DriverQueryProc( 'nm', 'PutCharSeq', '/' );
      core.DriverQueryProc( 'nm', 'PutCharSeq', '1' );
      core.DriverQueryProc( 'nm', 'PutCharSeq', '.' );
      core.DriverQueryProc( 'nm', 'PutCharSeq', '0' );
      core.DriverQueryProc( 'nm', 'PutCharSeq', '#0D' );
      core.DriverQueryProc( 'nm', 'PutCharSeq', '#0A' );
      core.DriverQueryProc( 'nm', 'PutCharSeq', '#0D' );
      core.DriverQueryProc( 'nm', 'PutCharSeq', '#0A' );

      core.DriverQueryProc( 'nm', 'SendAsync', 18 );
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
      core.DriverQueryProc( 'nm', 'server stop_listen', 0 );
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
      core.DriverQueryProc( 'nm', 'server listen 3001', &s );
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
      core.DriverQueryProc( 'nm', 'client send ' + s, &error );
      core.DebugOutput( 'Send error: ', error );
      *)

      core.DriverQueryProc( 'nm', 'ClearTxQueue', 0 );
(*
      core.DriverQueryProc( 'nm', 'SetTxIndex', 10 );
*)
      core.DriverQueryProc( 'nm', 'SetTxIndex', 0 );
(*
      core.DriverQueryProc( 'nm', 'SetRxIndex', 10 );
*)
      core.DriverQueryProc( 'nm', 'SetRxIndex', 0 );

(*
      core.DriverQueryProc( 'nm', 'PutCharSeq', 71 );
      core.DriverQueryProc( 'nm', 'PutCharSeq', 'G' );
      core.DriverQueryProc( 'nm', 'PutCharSeq', 'E' );
      core.DriverQueryProc( 'nm', 'PutCharSeq', 'T' );
      core.DriverQueryProc( 'nm', 'PutCharSeq', ' ' );
      core.DriverQueryProc( 'nm', 'PutCharSeq', '/' );
      core.DriverQueryProc( 'nm', 'PutCharSeq', ' ' );
      core.DriverQueryProc( 'nm', 'PutCharSeq', 'H' );
      core.DriverQueryProc( 'nm', 'PutCharSeq', 'T' );
      core.DriverQueryProc( 'nm', 'PutCharSeq', 'T' );
      core.DriverQueryProc( 'nm', 'PutCharSeq', 'P' );
      core.DriverQueryProc( 'nm', 'PutCharSeq', '/' );
      core.DriverQueryProc( 'nm', 'PutCharSeq', '1' );
      core.DriverQueryProc( 'nm', 'PutCharSeq', '.' );
      core.DriverQueryProc( 'nm', 'PutCharSeq', '0' );
      core.DriverQueryProc( 'nm', 'PutCharSeq', '#0D' );
      core.DriverQueryProc( 'nm', 'PutCharSeq', '#0A' );
      core.DriverQueryProc( 'nm', 'PutCharSeq', '#0D' );
      core.DriverQueryProc( 'nm', 'PutCharSeq', '#0A' );

      core.DriverQueryProc( 'nm', 'SendAsync', 18 );
*)
      core.DriverQueryProc( 'nm', 'PutCharSeq', '#1B' );
      core.DriverQueryProc( 'nm', 'PutCharSeq', '#01' );
      core.DriverQueryProc( 'nm', 'PutCharSeq', '#03' );
      core.DriverQueryProc( 'nm', 'PutCharSeq', '#01' );
      core.DriverQueryProc( 'nm', 'PutCharSeq', '#03' );
      core.DriverQueryProc( 'nm', 'PutCharSeq', '#FC' );
      core.DriverQueryProc( 'nm', 'SendAsync', 6 );
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
      core.DriverQueryProc( 'nm', 'client disconnect', 0 );
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
      core.DriverQueryProc( 'nm', 'client connect 10.78.0.8:6005', &s );
     *)
      core.DriverQueryProc( 'nm', 'client connect 192.168.84.54:3001', &s );
      core.DebugOutput( 'connect: ', s );
    end_procedure;

  end_switch;

  program excpt;

    procedure OnActivate();
    const
      delimiter = ' ';
    var
      c : cardinal;
      s : string;
      t : string;
      T : string;
    begin
      loop
        core.DriverQueryProc( 'nm', 'event get', &s );
        core.DriverQueryProc( 'nm', 'event count', &c );
        if s = '' then
          exit;
        end;

        if s = 'client_connect' then
           core.DebugOutput( 'connect: ', s );

        elsif s = 'server_data' then
          loop
            core.DriverQueryProc( 'nm', 'client receive', &s );
            if s = '' then
              exit;
            end;

            core.DebugOutput( 'received: ', s );

            T := '';
            while s <> '' do
              t := slice( s, 0, 2 );
              if ( t = '0D' ) or ( t = '0A' ) then
                T := T + 'CRLF';
              else
                T := T + char( val( t, 16 ));
              end;
              s := delete( s, 0, 2 );
            end;

            core.DebugOutput( 'converted: ', T );
          end; (* loop *)

        else
          core.DebugOutput( 'exception: ', s );

        end;
      end;
    end_procedure;

  end_program;

  program excpt2;
    activity
      driver = nm;
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
      core.DriverQueryProc( 'nm', 'GetExcStatus', &c );

      switch c of
      case 0; (* ok *)
        core.DebugOutput( 'AS OK' );

      case 1;
        core.DriverQueryProc( 'nm', 'GetErrorCode', &c );
        core.DebugOutput( 'AS RX Error: ', c );

      case 2;
        core.DriverQueryProc( 'nm', 'GetErrorCode', &c );
        core.DebugOutput( 'AS TX Error: ', c );

      case 3;
        core.DebugOutput( 'AS Data Received' );

        core.DriverQueryProc( 'nm', 'SetRxIndex', 0 );

        core.DriverQueryProc( 'nm', 'GetRxCount', &c );
        core.DebugOutput( '   Count: ', c );

        if c > 0 then
          s := '';
          for i := 0 to c-1 do
            if i % 2 = 1 then
              core.DriverQueryProc( 'nm', 'GetCharSeq', &t );
            else
              core.DriverQueryProc( 'nm', 'GetCharSeq', &ch );
              if ch = 10 then
                t = '#0A';
              elsif ch = 13 then
                t = '#0D';
              else
                t = char( ch );
              end;
            end;
            core.DriverQueryProc( 'nm', 'GetResult', &error );
            if error <> 0 then
              core.DebugOutput( 'GetCharSeq error: ', error );
            end;

            s := s + t;
            if (i+1) % 100 = 0 then
              core.DebugOutput( 'Data: ', s );
              s := '';
            end;
          end; (* for *)
          core.DebugOutput( 'Data: ', s );

          core.DriverQueryProc( 'nm', 'ClearRxQueue', &c );
        end;

      case 4;
        core.DriverQueryProc( 'nm', 'GetErrorCode', &c );
        core.DebugOutput( 'AS Driver Error:', c );

      case 100; (* connect *)
        core.DriverQueryProc( 'nm', 'GetErrorCode', &c );
        core.DebugOutput( 'AS Connect:', c );

      case 101; (* disconnect *)
        core.DriverQueryProc( 'nm', 'GetErrorCode', &c );
        core.DebugOutput( 'AS Disconnect:', c );

      case 102; (* accept *)
        core.DriverQueryProc( 'nm', 'GetErrorCode', &c );
        core.DebugOutput( 'AS Accept:', c );

      end; (* case *)

      core.DriverQueryProc( 'nm', 'EnableException', 0 );

    end_procedure;

  end_program;

end_instrument;

