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
  dali : 'dali_sci.dll', '', 'dalisci.par';
end_driver;

data
end_data;

instrument

  program Status;
    timer = 10.01;

    procedure OnActivate();
    begin
      core.DebugOutput( 'ST: ', dali.1 );
    end_procedure;

  end_program;

  string_control string_control_2;
    owner = background;
    position = 135, 155, 755, 80;
    window = normal;
    font = 'Candara (Central European)', 24, bold;
    enter_button;
    
    procedure OnOutput( Output : string );
    var
       s : string;
    begin
       core.DebugOutput( 'Command: ', Output );
       core.DriverQueryProc( 'dali', Output, &s );
       core.DebugOutput( 'Result:  ', s );
    end_procedure;
    
  end_string_control;

  program ExceptionHandler;
    driver_exception = dali;

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

