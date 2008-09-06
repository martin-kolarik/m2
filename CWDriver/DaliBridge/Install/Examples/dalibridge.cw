directories
end_directories;

settings
  operation_mode = real_time;
  startup_options
    call_procedures = false;
    activate_receivers = false;
    output_action = set_local;
  end_startup_options;
end_settings;

driver
  dali {driver = 'dalibridge.dll'; parameter_file = 'dalibridge.par'};
end_driver;

data
end_data;

instrument

  switch switch_1;
    gui
      owner = background;
      position = 225, 290, 145, 110;
      window
        type = normal;
        disable = zoom, maximize;
      end_window;
    end_gui;

    procedure OnOutput( b : boolean );
    var
      s : string;
    begin
    (*
      core.DriverQueryProc( 'dali', 'program_addresses 0 use_verify', '' );
      core.DriverQueryProc( 'dali', 'program_addresses 0', '' );
      core.DriverQueryProc( 'dali', 'program_missing_addresses 0', &s );
    *)

      core.DriverQueryProc( 'dali', 'load_addresses 25868 25596 121 122121 20000 14', &s );
      core.DebugOutput( 'res: ', s );

      core.DriverQueryProc( 'dali', 'get_addresses', &s );
      core.DebugOutput( 'res: ', s );

      core.DriverQueryProc( 'dali', 'program_missing_addresses 0', &s );
      core.DebugOutput( 'res: ', s );
    end_procedure;

  end_switch;

  meter meter_1;
    gui
      owner = background;
      position = 500, 250, 395, 75;
    end_gui;
    expression = dali.10;
    mode = text_display;
    range_to = 1E+016;
    font = 'Arial Rounded MT Bold (Western)', 36, normal;
  end_meter;

  string_control string_control_2;
    gui
      owner = background;
      position = 135, 155, 755, 80;
      window
        type = normal;
      end_window;
    end_gui;
    font = 'Candara (Central European)', 24, bold;
    enter_button = true;

    procedure OnOutput( Output : string );
    var
       s : string;
    begin
       core.DebugOutput( 'Command: ', Output );
       core.DriverQueryProc( 'dali', Output, &s );
       core.DebugOutput( 'Result:  ', s );
    end_procedure;

  end_string_control;

  program Status;
    activity
      period = 10.01;
    end_activity;

    procedure OnActivate();
    begin
      core.DebugOutput( 'ST: ', dali.1 );
    end_procedure;

  end_program;

  program ExceptionHandler;
    activity
      driver = dali;
    end_activity;

    procedure OnActivate();
    var
       Event : string;
    begin
       loop
          core.DriverQueryProc( 'dali', 'event get', &Event );
          if Event = '' then
             exit;
          end;
          core.DebugOutput( 'Event: ', Event );
       end;
    end_procedure;

  end_program;

end_instrument;

