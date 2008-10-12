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
  nm : 'remoteasciidrv.dll', '', 'RemoteASCIIDrv.par';
end_driver;

data
end_data;

instrument

  panel panel_2;
    owner = background;
    position = 215, 115, 320, 355;
    window = normal;
  end_panel;

  string_control string_control_1;
    owner = panel_2;
    position = 15, 210, 135, 18;
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
    owner = panel_2;
    position = 170, 160, 88, 30;
    mode = text_button;
    true_text = 'client disconnect';
    false_text = 'client disconnect';
    
    procedure OnOutput( b : boolean );
    begin
      core.DriverQueryProc( 'nm', 'client disconnect', 0 );
    end_procedure;
    
  end_switch;

  switch switch_1;
    owner = panel_2;
    position = 70, 160, 80, 31;
    mode = text_button;
    true_text = 'client connect';
    false_text = 'client connect';
    
    procedure OnOutput( b : boolean );
    var
      s : string;
    begin
      core.DriverQueryProc( 'nm', 'client connect 10.0.0.52:9038', &s );
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
    driver_exception = nm;
    
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
              t = char( ch );
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
        core.DebugOutput( 'AS Connect: ', c );

      case 101; (* disconnect *)
        core.DriverQueryProc( 'nm', 'GetErrorCode', &c );
        core.DebugOutput( 'AS Disconnect: ', c );

      end; (* case *)

      core.DriverQueryProc( 'nm', 'EnableException', 0 );
    end_procedure;
    
  end_program;

end_instrument;

