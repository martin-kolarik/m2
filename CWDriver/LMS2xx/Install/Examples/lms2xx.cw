directories
end_directories;

settings
  operation_mode = real_time;
  skip_init_outputs = true;
  send_same_data = on;
  startup_options
    call_procedures = false;
    activate_receivers = false;
    output_action = set_local;
  end_startup_options;
end_settings;

driver
  LMS : 'lms2xx.dll', '', 'lms2xx.PAR';
end_driver;

data

  channel
    Status : longcard {driver = LMS; driver_index = 1; direction = input};
    Mode : longcard {driver = LMS; driver_index = 2; direction = input};
    ActiveSet : longcard {driver = LMS; driver_index = 3; direction = input};
    F1 : array[ 100..102 ] of boolean {driver = LMS; direction = input};
    F2 : array[ 200..202 ] of boolean {driver = LMS; direction = input};
    M : buffer {buffer_type = longcard; buffer_length = 12; driver = LMS; driver_index = 10; direction = input};
    C : buffer {buffer_type = longcard; buffer_length = 12; driver = LMS; driver_index = 11; direction = input};
  end_channel;

  var
    CV : array[ 0..720 ] of longcard;
    MV : array[ 0..720 ] of longcard;
    offset : integer;
  end_var;

end_data;

instrument

  panel panel_6;
    owner = background;
    position = 105, 70, 800, 550;
    window = normal;
    colors
      color = black;
    end_colors;
  end_panel;

  label label_1;
    owner = panel_6;
    position = 105, 450;
    win_disable = zoom, maximize;
    text_list
      text = 'mean lock';
    end_text_list;
  end_label;

  switch switch_1;
    owner = panel_6;
    position = 110, 400, 46, 46;
    win_disable = zoom, maximize;
    
    procedure OnOutput( Output : boolean );
    var
      result : string;
    begin
      core.DriverQueryProc( 'LMS', 'lock_mean ' + Output:s, 0 );
      core.DriverQueryProc( 'LMS', 'mean_locked', &result );
      core.DebugOutput( 'Mean lock status: ', result );
    end_procedure;
    
  end_switch;

  label label_1;
    owner = panel_6;
    position = 70, 450;
    win_disable = zoom, maximize;
    text_list
      text = 'scan';
    end_text_list;
  end_label;

  label label_1;
    owner = panel_6;
    position = 25, 450;
    win_disable = zoom, maximize;
    text_list
      text = 'reset';
    end_text_list;
  end_label;

  control control_1;
    owner = panel_6;
    position = 275, 60, 465, 43;
    mode = horizontal_slider;
    content = med;
    range_from = -40;
    range_to = 40;
    dec_places = 0;
    
    procedure OnOutput( r : real );
    begin
      offset := r;
      DBG.OnOutput( false );
    end_procedure;
    
  end_control;

  switch DBG;
    const
      peek = '100,200,300,200,100,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,200,200,300,200,200,';
      base = 100;
    end_const;

    owner = panel_6;
    position = 695, 15, 46, 46;
    win_disable = zoom, maximize;
    
    procedure OnStartup();
    var
      s : string;
    begin
      core.DriverQueryProc( 'LMS', 'zone create Main', &s );
      core.DriverQueryProc( 'LMS', 'zone switch on', &s );
      core.DriverQueryProc( 'LMS', 'zone commit', &s );

      core.DriverQueryProc( 'LMS', 'zone change Main', &s );
      core.DriverQueryProc( 'LMS', 'zone copy_from Main', &s );
      core.DriverQueryProc( 'LMS', 'zone switch_far on', &s );
      core.DriverQueryProc( 'LMS', 'zone switch_near on', &s );
      core.DriverQueryProc( 'LMS', 'zone angle_from 10', &s );
      core.DriverQueryProc( 'LMS', 'zone angle_to 150', &s );
      core.DriverQueryProc( 'LMS', 'zone near_limit 50', &s );
      core.DriverQueryProc( 'LMS', 'zone far_limit 300', &s );
      core.DriverQueryProc( 'LMS', 'zone beam_count 10', &s );
      core.DriverQueryProc( 'LMS', 'zone gap_count 2', &s );
      core.DriverQueryProc( 'LMS', 'zone beam_scan 1', &s );
      core.DriverQueryProc( 'LMS', 'zone movement_threshold 25', &s );
      core.DriverQueryProc( 'LMS', 'zone abort', &s );
    end_procedure;
    
    procedure OnOutput( Output : boolean );
    var
      i : integer;
      s : string;
    begin
      for i := 0 to base + offset do
        s := s + '0,';
      end;
      s := s + peek + ',';
      for i := 0 to base - offset do
        s := s + '0,';
      end;
      core.DriverQueryProc( 'LMS', 'debug', s );
    end_procedure;
    
  end_switch;

  switch switch_1;
    owner = panel_6;
    position = 15, 400, 46, 46;
    win_disable = zoom, maximize;
    
    procedure OnOutput( Output : boolean );
    begin
      core.DriverQueryProc( 'LMS', 'reset', 0 );
    end_procedure;
    
  end_switch;

  switch switch_1;
    owner = panel_6;
    position = 60, 400, 46, 46;
    win_disable = zoom, maximize;
    
    procedure OnOutput( Output : boolean );
    begin
      core.DriverQueryProc( 'LMS', 'scan', 0 );
    end_procedure;
    
  end_switch;

  meter meter_1;
    timer = 1;
    owner = panel_6;
    position = 305, 15, 140, 35;
    expression = ActiveSet;
    mode = text_display;
    range_to = 1E+017;
    low_limit = 0;
    high_limit = 1E+017;
    dec_places = 0;
    frame = 2;
    font = 'Lucida Sans Typewriter (Western)', 16, semibold;
    colors
      top_shadow = lgray;
      bottom_shadow = lgray;
      value = black;
      low_limit = black;
    end_colors;
  end_meter;

  meter meter_1;
    timer = 1;
    owner = panel_6;
    position = 160, 15, 140, 35;
    expression = Mode;
    mode = text_display;
    range_to = 1E+017;
    low_limit = 0;
    high_limit = 1E+017;
    dec_places = 0;
    frame = 2;
    font = 'Lucida Sans Typewriter (Western)', 16, semibold;
    colors
      top_shadow = lgray;
      bottom_shadow = lgray;
      value = black;
      low_limit = black;
    end_colors;
  end_meter;

  meter meter_1;
    timer = 0.001;
    owner = panel_6;
    position = 15, 15, 140, 35;
    expression = Status;
    mode = text_display;
    range_to = 1E+017;
    low_limit = 0;
    high_limit = 1E+017;
    dec_places = 0;
    frame = 2;
    font = 'Lucida Sans Typewriter (Western)', 16, semibold;
    colors
      top_shadow = lgray;
      bottom_shadow = lgray;
      value = black;
      low_limit = black;
    end_colors;
  end_meter;

  panel panel_4;
    owner = panel_6;
    position = 200, 55, 65, 45;
    colors
      color = black;
    end_colors;
  end_panel;

  indicator indicator_3;
    timer = 0.1;
    owner = panel_4;
    position = 45, 25;
    win_disable = zoom, maximize;
    expression = F2[202];
    true_icon = 'led16gon.ico';
    false_icon = 'led16ron.ico';
  end_indicator;

  indicator indicator_3;
    timer = 0.1;
    owner = panel_4;
    position = 25, 25;
    win_disable = zoom, maximize;
    expression = F2[201];
    true_icon = 'led16gon.ico';
    false_icon = 'led16ron.ico';
  end_indicator;

  indicator indicator_3;
    timer = 0.1;
    owner = panel_4;
    position = 5, 25;
    win_disable = zoom, maximize;
    expression = F2[200];
    true_icon = 'led16gon.ico';
    false_icon = 'led16ron.ico';
  end_indicator;

  indicator indicator_3;
    timer = 0.1;
    owner = panel_4;
    position = 45, 5;
    win_disable = zoom, maximize;
    expression = F1[102];
    true_icon = 'led16gon.ico';
    false_icon = 'led16ron.ico';
  end_indicator;

  indicator indicator_3;
    timer = 0.1;
    owner = panel_4;
    position = 25, 5;
    win_disable = zoom, maximize;
    expression = F1[101];
    true_icon = 'led16gon.ico';
    false_icon = 'led16ron.ico';
  end_indicator;

  indicator indicator_3;
    timer = 0.1;
    owner = panel_4;
    position = 5, 5;
    win_disable = zoom, maximize;
    expression = F1[100];
    true_icon = 'led16gon.ico';
    false_icon = 'led16ron.ico';
  end_indicator;

  buffer_display buffer_display_2;
    timer = 1;
    owner = panel_6;
    position = 15, 250, 725, 140;
    input = M;
    range_from = 0;
    range_to = 40000;
    colors
      paper = black;
      ink = white;
      top_shadow = lgray;
      bottom_shadow = lgray;
    end_colors;
  end_buffer_display;

  buffer_display buffer_display_2;
    timer = 0.1;
    owner = panel_6;
    position = 15, 105, 725, 140;
    input = C;
    range_from = 0;
    range_to = 40000;
    show_all_samples = false;
    first_sample = 0;
    last_sample = 721;
    colors
      paper = black;
      ink = white;
      top_shadow = lgray;
      bottom_shadow = lgray;
    end_colors;
  end_buffer_display;

  program alrm;
    driver_exception = LMS;
    
    procedure OnActivate();
    var
      s : string;
    begin
      repeat
        core.DriverQueryProc( 'LMS', 'get_event', &s );
        core.DebugOutput( 'Event: ', s );
      until s = '';
    end_procedure;
    
  end_program;

  buffer_convertor buffer_convertor_1;
    timer = infinite;
    item
      condition = true;
      input_element = C;
      input_index_from = 0;
      input_index_to = 720;
      output_element = CV;
      output_index_from = 0;
      output_index_to = 720;
    end_item;
    item
      condition = true;
      input_element = M;
      input_index_from = 0;
      input_index_to = 720;
      output_element = MV;
      output_index_from = 0;
      output_index_to = 720;
    end_item;
    
    procedure OnActivate();
    var
      i : longcard;
      s : string;
    begin
      for i := 0 to 40 do
        s := s + strf( MV[i] / 1000, '****.##' ) + ' ';
      end;
      core.DebugOutput( 'AT 00: ', s );
      s := '';
      for i := 20*4 to 30*4 do
        s := s + strf(( CV[i]-MV[i] ) / 10, '****.##' ) + ' ';
      end;
      core.DebugOutput( 'AT 26: ', s );
    end_procedure;
    
  end_buffer_convertor;

end_instrument;

