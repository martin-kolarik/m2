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
  sdap : 'sdapbridge.dll', '', 'sdapbridge.par';
end_driver;

data

  channel sdap_input {direction = input};
    status : longcard {driver = sdap; driver_index = 1};
    input_queue_length : longcard {driver = sdap; driver_index = 10};
    output_queue_length : longcard {driver = sdap; driver_index = 11};
  end_channel;

end_data;

instrument

  switch Test;
    owner = background;
    position = 75, 210, 125, 74;
    window = normal;
    
    procedure OnOutput( Output : boolean );
    begin
      SDAPClient.Ask( '2/0/0' );
    end_procedure;
    
  end_switch;

  switch Test;
    owner = background;
    position = 75, 95, 125, 74;
    window = normal;
    
    procedure OnOutput( Output : boolean );
    begin
      SDAPClient.Set( '3/1/21', 'true' );
    end_procedure;
    
  end_switch;

  panel panel_2;
    owner = background;
    position = 225, 95, 200, 120;
    window = normal;
  end_panel;

(*
  meter meter_1;
    timer = 0.001;
    owner = panel_2;
    position = 10, 45, 180, 30;
    expression = sdap_input.input_queue_length;
    mode = text_display;
    range_to = 100000000000;
    low_limit = 0;
    high_limit = 100000000000;
    dec_places = 0;
    font = font_text;
  end_meter;

  meter meter_1;
    timer = 0.001;
    owner = panel_2;
    position = 10, 80, 180, 30;
    expression = sdap_input.output_queue_length;
    mode = text_display;
    range_to = 100000000000;
    low_limit = 0;
    high_limit = 100000000000;
    dec_places = 0;
    font = font_text;
  end_meter;
*)

  meter meter_1;
    timer = 0.001;
    owner = panel_2;
    position = 10, 10, 180, 30;
    expression = sdap_input.status;
    mode = text_display;
    range_to = 100000000000;
    low_limit = 0;
    high_limit = 100000000000;
    dec_places = 0;
    font = font_text;
  end_meter;

  program SDAPHandler;
    driver_exception = sdap;
    
    procedure OnActivate();
    var
      address : string;
      value : string;
      command : string;
      event : string;
      space : longint;
    begin
      loop
        core.DriverQueryProc( 'sdap', 'event get', &event );
        if event = '' then (* no event read, queue is empty *)
          exit;
        end;

        (* analyze having no parameter *)
        if event = 'connected' then
          OnConnected();
          continue; (* this skips processing of events with parameters *)
        elsif event = 'disconnected' then
          OnDisconnected();
          continue; (* this skips processing of events with parameters *)
        end;
    
        (* analyze events having parameters *)
        space = pos( event, ' ' );
        if space = -1 then (* something strange, event has not form "<command> <par1> <par2>" *)
          continue;
        end;
    
        command = slice( event, 0, space );
        event = delete( event, 0, space+1 );
        if command = 'advise' then
    
          space = pos( event, ' ' );
          if space = -1 then (* something strange, event has not form "<command> <par1> <par2>" *)
            continue;
          end;
    
          address = slice( event, 0, space );
          value = delete( event, 0, space+1 );
    
          OnAdvise( address, value );
        end;
    
      end; (* loop *)
    end_procedure;
    
    procedure OnConnected();
    begin
      Command( 'advise' );
      SDAPClient.OnConnected();
    end_procedure;
    
    procedure OnDisconnected();
    begin
      SDAPClient.OnDisconnected();
    end_procedure;
    
    procedure OnAdvise( address, value : string );
    begin
      SDAPClient.OnAdvise( address, value );
    end_procedure;
    
    procedure Command( command : string );
    var
      result : string;
    begin
      core.DriverQueryProc( 'sdap', command, &result );
      if result <> '' then
        core.DebugOutput( 'SDAP command failed:', result );
      end;
    end_procedure;
    
  end_program;

  program SDAPClient;
    
    procedure OnConnected();
    begin
      core.DebugOutput( 'connected' );
    end_procedure;
    
    procedure OnDisconnected();
    begin
      core.DebugOutput( 'disconnected' );
    end_procedure;
    
    procedure OnAdvise( address, value : string );
    begin
      core.DebugOutput( 'received:', address + ' ' + value );
    end_procedure;
    
    procedure Set( address, value : string );
    begin
      SDAPHandler.Command( 'set ' + address + ' ' + value );
    end_procedure;
    
    procedure Ask( address : string );
    begin
      SDAPHandler.Command( 'ask ' + address );
    end_procedure;
    
    procedure Advise();
    begin
      SDAPHandler.Command( 'advise' );
    end_procedure;
    
    procedure Unadvise();
    begin
      SDAPHandler.Command( 'unadvise' );
    end_procedure;
    
  end_program;

  program SDAPStress;
    (*
    timer = 0.01;
    *)
    
    procedure OnActivate();
    begin
      SDAPClient.Set( '6/3/23', 'true' );
    end_procedure;
    
  end_program;

end_instrument;

