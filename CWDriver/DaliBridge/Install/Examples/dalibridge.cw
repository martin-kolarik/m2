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
  dali : 'dalibridge.dll', '', 'dalibridge.par';
end_driver;

data

  const
    DEVICE = 'Test';
  end_const;

end_data;

instrument

  switch switch_1;
    owner = background;
    position = 225, 290, 145, 110;
    window = normal;
    
    procedure OnStartup();
    var
       error : string;
    begin
      core.DriverQueryProc( 'dali', 'create ' + DEVICE + ' 10001 10.0.0.100', &error );
      if error = '' then
        error := '<ok>';
      end;
      core.DebugOutput( 'create device ' + DEVICE + ': ' + error );

      core.DriverQueryProc( 'dali', 'get_queue_count ' + DEVICE, &error );
      if error = '' then
        error := '<ok>';
      end;
      core.DebugOutput( 'get_queue_count ' + DEVICE + ': ' + error );
    end_procedure;
    
    procedure OnOutput( b : boolean );
    var
      s : string;
    begin
      core.DriverQueryProc( 'dali', 'get_addresses', &s );
      core.DebugOutput( 'res: ', s );
    end_procedure;
    
  end_switch;

  meter meter_1;
    owner = background;
    position = 500, 250, 395, 75;
    expression = dali.10;
    mode = text_display;
    range_to = 1E+016;
    font = 'Arial Rounded MT Bold (Western)', 36, normal;
  end_meter;

  string_control string_control_2;
    owner = background;
    position = 135, 155, 755, 80;
    window = normal;
    font = 'Candara (Central European)', 24, bold;
    
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
    timer = 10.01;
    
    procedure OnActivate();
    begin
      core.DebugOutput( 'ST: ', dali.1 );
    end_procedure;
    
  end_program;

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

