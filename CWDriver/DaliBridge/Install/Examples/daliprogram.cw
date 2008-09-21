directories
  '*.ico' = 'C:\Program Files\Moravian Instruments\Control Web 5 CZE\Ico\Symbol';
end_directories;

settings
  operation_mode = real_time;
  startup_options
    call_procedures = false;
    activate_receivers = false;
    output_action = set_local;
  end_startup_options;
  backup
    method = on_demand;
  end_backup;
  expression_exceptions
    string_conversion = false;
  end_expression_exceptions;
end_settings;

driver
  dali : 'dalibridge.dll', '', 'daliprogram.par';
end_driver;

data

  const
    DEVICE = 'Test';
  end_const;

  var GLOBAL {backuped = false};
    ActiveLinie : cardinal {init_value = 0};
  end_var;

  channel DALI {backuped = false};
    Status : longcard {driver = dali; driver_index = 1; direction = input};
    OutputQueueLength : longcard {driver = dali; driver_index = 10; direction = input};
  end_channel;

end_data;

instrument

  panel Addressing;
    owner = background;
    position = 95, 60, 845, 565;
    window = normal;
    win_title = 'Adresace DALI';
    win_disable = zoom;

    procedure OnStartup();
    var
       error : string;
    begin
      core.DriverQueryProc( 'dali', 'create ' + DEVICE + ' 10001 10.0.0.100', &error );
      if error = '' then
        error := '<ok>';
      end;
      core.DebugOutput( 'create device ' + DEVICE + ': ' + error );

      core.DriverQueryProc( 'dali', 'set_poll_period ' + DEVICE + '.0 250', &error );
      if error = '' then
        error := '<ok>';
      end;
      core.DebugOutput( 'set_poll_period: ' + error );
    end_procedure;

  end_panel;

  switch switch_scan_address;
    timer = 0.1;
    owner = Addressing;
    position = 150, 10, 70, 27;
    mode = text_button;
    init_value = true;
    font = font_caption;
    true_text = 'SCAN';
    logic = set_true;
    colors
      true_paper = green;
      true_ink = lyellow;
      true_tshadow = 99, 255, 99;
      true_bshadow = 1, 75, 1;
      false_paper = lgray;
    end_colors;
    
    procedure OnActivate();
    begin
       if bitget( DALI.Status, 3 ) = 1 then
         SetColor( 'true_ink', 'lred' );
         switch_readdress.SetColor( 'true_ink', 'lred' );
       else
         SetColor( 'true_ink', 'lyellow' );
         switch_readdress.SetColor( 'true_ink', 'lyellow' );
       end;
    end_procedure;
    
    procedure OnOutput( b : boolean );
    var
      error : string;
    begin
      ExceptionHandler.ResetStatus();
      core.DriverQueryProc( 'dali', 'program_scan ' + DEVICE + '.' + ActiveLinie:s, &error );
      if error = '' then
        error := '<ok>';
      end;
      core.DebugOutput( 'program_scan ' + DEVICE + '.' + ActiveLinie:s + ': ' + error );
    end_procedure;
    
  end_switch;

  switch switch_address_all;
    timer = 0.1;
    owner = Addressing;
    position = 225, 10, 70, 27;
    mode = text_button;
    init_value = true;
    font = font_caption;
    true_text = 'ADR ALL';
    logic = set_true;
    colors
      true_paper = green;
      true_ink = lyellow;
      true_tshadow = 99, 255, 99;
      true_bshadow = 1, 75, 1;
      false_paper = lgray;
    end_colors;
    
    procedure OnActivate();
    begin
       if bitget( DALI.Status, 3 ) = 1 then
         SetColor( 'true_ink', 'lred' );
         switch_readdress.SetColor( 'true_ink', 'lred' );
       else
         SetColor( 'true_ink', 'lyellow' );
         switch_readdress.SetColor( 'true_ink', 'lyellow' );
       end;
    end_procedure;
    
    procedure OnOutput( b : boolean );
    var
      error : string;
    begin
      ExceptionHandler.ResetStatus();
      core.DriverQueryProc( 'dali', 'program_all ' + DEVICE + '.' + ActiveLinie:s, &error );
      if error = '' then
        error := '<ok>';
      end;
      core.DebugOutput( 'program_all ' + DEVICE + '.' + ActiveLinie:s + ': ' + error );
    end_procedure;
    
  end_switch;

  switch switch_readdress;
    owner = Addressing;
    position = 300, 10, 70, 27;
    mode = text_button;
    init_value = true;
    font = font_caption;
    true_text = 'READR';
    logic = set_true;
    colors
      true_paper = green;
      true_ink = lyellow;
      true_tshadow = 99, 255, 99;
      true_bshadow = 1, 75, 1;
      false_paper = lgray;
    end_colors;
    
    procedure GetReaddressString( var result : string; var error : string ): boolean;
    var
      found : array [0..63] of boolean;
      s : string;
    begin
      result := '';
      error := '';
    
      s := new_00.GetValue();
      if s = '' then
      elsif not CheckAndAdd( s, found, result, error ) then
        return false;
      end;
    
      s := new_01.GetValue();
      if s = '' then
      elsif not CheckAndAdd( s, found, result, error ) then
        return false;
      end;
    
      s := new_02.GetValue();
      if s = '' then
      elsif not CheckAndAdd( s, found, result, error ) then
        return false;
      end;
    
      s := new_03.GetValue();
      if s = '' then
      elsif not CheckAndAdd( s, found, result, error ) then
        return false;
      end;
    
      s := new_04.GetValue();
      if s = '' then
      elsif not CheckAndAdd( s, found, result, error ) then
        return false;
      end;
    
      s := new_05.GetValue();
      if s = '' then
      elsif not CheckAndAdd( s, found, result, error ) then
        return false;
      end;
    
      s := new_06.GetValue();
      if s = '' then
      elsif not CheckAndAdd( s, found, result, error ) then
        return false;
      end;
    
      s := new_07.GetValue();
      if s = '' then
      elsif not CheckAndAdd( s, found, result, error ) then
        return false;
      end;
    
      s := new_08.GetValue();
      if s = '' then
      elsif not CheckAndAdd( s, found, result, error ) then
        return false;
      end;
    
      s := new_09.GetValue();
      if s = '' then
      elsif not CheckAndAdd( s, found, result, error ) then
        return false;
      end;
    
      s := new_10.GetValue();
      if s = '' then
      elsif not CheckAndAdd( s, found, result, error ) then
        return false;
      end;
    
      s := new_11.GetValue();
      if s = '' then
      elsif not CheckAndAdd( s, found, result, error ) then
        return false;
      end;
    
      s := new_12.GetValue();
      if s = '' then
      elsif not CheckAndAdd( s, found, result, error ) then
        return false;
      end;
    
      s := new_13.GetValue();
      if s = '' then
      elsif not CheckAndAdd( s, found, result, error ) then
        return false;
      end;
    
      s := new_14.GetValue();
      if s = '' then
      elsif not CheckAndAdd( s, found, result, error ) then
        return false;
      end;
    
      s := new_15.GetValue();
      if s = '' then
      elsif not CheckAndAdd( s, found, result, error ) then
        return false;
      end;
    
      s := new_16.GetValue();
      if s = '' then
      elsif not CheckAndAdd( s, found, result, error ) then
        return false;
      end;
    
      s := new_17.GetValue();
      if s = '' then
      elsif not CheckAndAdd( s, found, result, error ) then
        return false;
      end;
    
      s := new_18.GetValue();
      if s = '' then
      elsif not CheckAndAdd( s, found, result, error ) then
        return false;
      end;
    
      s := new_19.GetValue();
      if s = '' then
      elsif not CheckAndAdd( s, found, result, error ) then
        return false;
      end;
    
      s := new_20.GetValue();
      if s = '' then
      elsif not CheckAndAdd( s, found, result, error ) then
        return false;
      end;
    
      s := new_21.GetValue();
      if s = '' then
      elsif not CheckAndAdd( s, found, result, error ) then
        return false;
      end;
    
      s := new_22.GetValue();
      if s = '' then
      elsif not CheckAndAdd( s, found, result, error ) then
        return false;
      end;
    
      s := new_23.GetValue();
      if s = '' then
      elsif not CheckAndAdd( s, found, result, error ) then
        return false;
      end;
    
      s := new_24.GetValue();
      if s = '' then
      elsif not CheckAndAdd( s, found, result, error ) then
        return false;
      end;
    
      s := new_25.GetValue();
      if s = '' then
      elsif not CheckAndAdd( s, found, result, error ) then
        return false;
      end;
    
      s := new_26.GetValue();
      if s = '' then
      elsif not CheckAndAdd( s, found, result, error ) then
        return false;
      end;
    
      s := new_27.GetValue();
      if s = '' then
      elsif not CheckAndAdd( s, found, result, error ) then
        return false;
      end;
    
      s := new_28.GetValue();
      if s = '' then
      elsif not CheckAndAdd( s, found, result, error ) then
        return false;
      end;
    
      s := new_29.GetValue();
      if s = '' then
      elsif not CheckAndAdd( s, found, result, error ) then
        return false;
      end;
    
      s := new_30.GetValue();
      if s = '' then
      elsif not CheckAndAdd( s, found, result, error ) then
        return false;
      end;
    
      s := new_31.GetValue();
      if s = '' then
      elsif not CheckAndAdd( s, found, result, error ) then
        return false;
      end;
    
      s := new_32.GetValue();
      if s = '' then
      elsif not CheckAndAdd( s, found, result, error ) then
        return false;
      end;
    
      s := new_33.GetValue();
      if s = '' then
      elsif not CheckAndAdd( s, found, result, error ) then
        return false;
      end;
    
      s := new_34.GetValue();
      if s = '' then
      elsif not CheckAndAdd( s, found, result, error ) then
        return false;
      end;
    
      s := new_35.GetValue();
      if s = '' then
      elsif not CheckAndAdd( s, found, result, error ) then
        return false;
      end;
    
      s := new_36.GetValue();
      if s = '' then
      elsif not CheckAndAdd( s, found, result, error ) then
        return false;
      end;
    
      s := new_37.GetValue();
      if s = '' then
      elsif not CheckAndAdd( s, found, result, error ) then
        return false;
      end;
    
      s := new_38.GetValue();
      if s = '' then
      elsif not CheckAndAdd( s, found, result, error ) then
        return false;
      end;
    
      s := new_39.GetValue();
      if s = '' then
      elsif not CheckAndAdd( s, found, result, error ) then
        return false;
      end;
    
      s := new_40.GetValue();
      if s = '' then
      elsif not CheckAndAdd( s, found, result, error ) then
        return false;
      end;
    
      s := new_41.GetValue();
      if s = '' then
      elsif not CheckAndAdd( s, found, result, error ) then
        return false;
      end;
    
      s := new_42.GetValue();
      if s = '' then
      elsif not CheckAndAdd( s, found, result, error ) then
        return false;
      end;
    
      s := new_43.GetValue();
      if s = '' then
      elsif not CheckAndAdd( s, found, result, error ) then
        return false;
      end;
    
      s := new_44.GetValue();
      if s = '' then
      elsif not CheckAndAdd( s, found, result, error ) then
        return false;
      end;
    
      s := new_45.GetValue();
      if s = '' then
      elsif not CheckAndAdd( s, found, result, error ) then
        return false;
      end;
    
      s := new_46.GetValue();
      if s = '' then
      elsif not CheckAndAdd( s, found, result, error ) then
        return false;
      end;
    
      s := new_47.GetValue();
      if s = '' then
      elsif not CheckAndAdd( s, found, result, error ) then
        return false;
      end;
    
      s := new_48.GetValue();
      if s = '' then
      elsif not CheckAndAdd( s, found, result, error ) then
        return false;
      end;
    
      s := new_49.GetValue();
      if s = '' then
      elsif not CheckAndAdd( s, found, result, error ) then
        return false;
      end;
    
      s := new_50.GetValue();
      if s = '' then
      elsif not CheckAndAdd( s, found, result, error ) then
        return false;
      end;
    
      s := new_51.GetValue();
      if s = '' then
      elsif not CheckAndAdd( s, found, result, error ) then
        return false;
      end;
    
      s := new_52.GetValue();
      if s = '' then
      elsif not CheckAndAdd( s, found, result, error ) then
        return false;
      end;
    
      s := new_53.GetValue();
      if s = '' then
      elsif not CheckAndAdd( s, found, result, error ) then
        return false;
      end;
    
      s := new_54.GetValue();
      if s = '' then
      elsif not CheckAndAdd( s, found, result, error ) then
        return false;
      end;
    
      s := new_55.GetValue();
      if s = '' then
      elsif not CheckAndAdd( s, found, result, error ) then
        return false;
      end;
    
      s := new_56.GetValue();
      if s = '' then
      elsif not CheckAndAdd( s, found, result, error ) then
        return false;
      end;
    
      s := new_57.GetValue();
      if s = '' then
      elsif not CheckAndAdd( s, found, result, error ) then
        return false;
      end;
    
      s := new_58.GetValue();
      if s = '' then
      elsif not CheckAndAdd( s, found, result, error ) then
        return false;
      end;
    
      s := new_59.GetValue();
      if s = '' then
      elsif not CheckAndAdd( s, found, result, error ) then
        return false;
      end;
    
      s := new_60.GetValue();
      if s = '' then
      elsif not CheckAndAdd( s, found, result, error ) then
        return false;
      end;
    
      s := new_61.GetValue();
      if s = '' then
      elsif not CheckAndAdd( s, found, result, error ) then
        return false;
      end;
    
      s := new_62.GetValue();
      if s = '' then
      elsif not CheckAndAdd( s, found, result, error ) then
        return false;
      end;
    
      s := new_63.GetValue();
      if s = '' then
      elsif not CheckAndAdd( s, found, result, error ) then
        return false;
      end;
    
      return true;
    end_procedure;
    
    procedure CheckAndAdd( input : string; found : array of boolean; var result : string; var error : string ): boolean;
    var
      addr : longcard;
    begin
      if input = '' then
        return false;
      end;
      addr = val( input, 10 );
      if last_error() <> 0 then
        error := 'Adresa "' + input + '" není èíslo';
        return false;
      elsif found[addr] then
        error := 'Adresa "' + input + '" je zdvojená';
        return false;
      else
        found[addr] := true;
        result = result + input + ' ';
        return true;
      end;
    end_procedure;
    
    procedure OnOutput( b : boolean );
    var
      error : string;
      result : string;
    begin
      SetColor( 'true_ink', 'lred' );
      ExceptionHandler.ResetStatus();
    
      if GetReaddressString( result, error ) then
        core.DebugOutput( 'Readdress prepared string:', result );
    
        core.DriverQueryProc( 'dali', 'program_readdress ' + DEVICE + '.' + ActiveLinie:s + ' ' + result, &error );
    
        if error = '' then
          SetColor( 'true_ink', 'lyellow' );
        else
          core.DebugOutput( 'Readdress:', error );
        end;
    
      else
        core.DebugOutput( 'Readdress prepare:', error );
      end;
    end_procedure;
    
  end_switch;

  switch switch_new_address;
    timer = 0.1;
    owner = Addressing;
    position = 375, 10, 70, 27;
    mode = text_button;
    init_value = true;
    font = font_caption;
    true_text = 'ADR NEW';
    logic = set_true;
    colors
      true_paper = green;
      true_ink = lyellow;
      true_tshadow = 99, 255, 99;
      true_bshadow = 1, 75, 1;
      false_paper = lgray;
    end_colors;
    
    procedure OnActivate();
    begin
       if bitget( DALI.Status, 3 ) = 1 then
         SetColor( 'true_ink', 'lred' );
         switch_readdress.SetColor( 'true_ink', 'lred' );
       else
         SetColor( 'true_ink', 'lyellow' );
         switch_readdress.SetColor( 'true_ink', 'lyellow' );
       end;
    end_procedure;
    
    procedure OnOutput( b : boolean );
    var
      error : string;
    begin
      ExceptionHandler.ResetStatus();
      core.DriverQueryProc( 'dali', 'program_added ' + DEVICE + '.' + ActiveLinie:s, &error );
      if error = '' then
        error := '<ok>';
      end;
      core.DebugOutput( 'program_added ' + DEVICE + '.' + ActiveLinie:s + ': ' + error );
    end_procedure;
    
  end_switch;

  switch switch_clear_address;
    owner = Addressing;
    position = 450, 10, 70, 27;
    mode = text_button;
    init_value = true;
    font = font_caption;
    true_text = 'CLR ALL';
    logic = set_true;
    colors
      true_paper = green;
      true_ink = lyellow;
      true_tshadow = 99, 255, 99;
      true_bshadow = 1, 75, 1;
      false_paper = lgray;
    end_colors;
    
    procedure OnOutput( b : boolean );
    var
      error : string;
    begin
      core.DriverQueryProc( 'dali', 'reset_address ' + DEVICE + '.' + ActiveLinie:s + '.all', &error );
      SetColor( 'true_ink', 'lred' );
    
      if error = '' then
        SetColor( 'true_ink', 'lyellow' );
        ExceptionHandler.ResetStatus();
      else
        core.DebugOutput( 'Reset address:', error );
      end;
    end_procedure;
    
  end_switch;

  panel panel_97;
    owner = Addressing;
    position = 215, 500, 100, 60;
    colors
      color = green;
    end_colors;
  end_panel;

  string_display state_58;
    const
      ID = '58';
    end_const;

    timer = infinite;
    owner = panel_97;
    position = 5, 5, 90, 20;
    expression = ID;
    frame = 0;
    font = font_caption;
    justify = center;
    colors
      ink = lgray;
      paper = color_btnshadow;
    end_colors;
  end_string_display;

  string_control new_58;
    owner = panel_97;
    position = 35, 30, 60, 26;
    font = font_caption;
    colors
      top_shadow = lgray;
      bottom_shadow = lgray;
      ink = lyellow;
      paper = color_btnshadow;
    end_colors;
  end_string_control;

  switch switch_58;
    const
      ID = 58;
    end_const;
    var
      dummy : boolean;
    end_var;

    owner = panel_97;
    position = 5, 30, 26, 26;
    output = dummy;
    true_icon = 'sw20on.ico';
    false_icon = 'sw20off.ico';
    
    procedure OnOutput( Output : boolean );
    var
      adr : string;
      error : string;
    begin
       adr := DEVICE + '.' + ActiveLinie:s + '.' + ID:s;
       if Output then
         core.DriverQueryProc( 'dali', 'set ' + adr + ' on', &error );
       else
         core.DriverQueryProc( 'dali', 'set ' + adr + ' off', &error );
       end;
       if error = '' then
         error := '<ok>';
       end;
       core.DebugOutput( 'set ' + adr + ' result: ' + error );
    end_procedure;
    
  end_switch;

  panel panel_96;
    owner = Addressing;
    position = 110, 500, 100, 60;
    colors
      color = green;
    end_colors;
  end_panel;

  string_display state_57;
    const
      ID = '57';
    end_const;

    timer = infinite;
    owner = panel_96;
    position = 5, 5, 90, 20;
    expression = ID;
    frame = 0;
    font = font_caption;
    justify = center;
    colors
      ink = lgray;
      paper = color_btnshadow;
    end_colors;
  end_string_display;

  string_control new_57;
    owner = panel_96;
    position = 35, 30, 60, 26;
    font = font_caption;
    colors
      top_shadow = lgray;
      bottom_shadow = lgray;
      ink = lyellow;
      paper = color_btnshadow;
    end_colors;
  end_string_control;

  switch switch_57;
    const
      ID = 57;
    end_const;
    var
      dummy : boolean;
    end_var;

    owner = panel_96;
    position = 5, 30, 26, 26;
    output = dummy;
    true_icon = 'sw20on.ico';
    false_icon = 'sw20off.ico';
    
    procedure OnOutput( Output : boolean );
    var
      adr : string;
      error : string;
    begin
       adr := DEVICE + '.' + ActiveLinie:s + '.' + ID:s;
       if Output then
         core.DriverQueryProc( 'dali', 'set ' + adr + ' on', &error );
       else
         core.DriverQueryProc( 'dali', 'set ' + adr + ' off', &error );
       end;
       if error = '' then
         error := '<ok>';
       end;
       core.DebugOutput( 'set ' + adr + ' result: ' + error );
    end_procedure;
    
  end_switch;

  panel panel_95;
    owner = Addressing;
    position = 5, 500, 100, 60;
    colors
      color = green;
    end_colors;
  end_panel;

  string_display state_56;
    const
      ID = '56';
    end_const;

    timer = infinite;
    owner = panel_95;
    position = 5, 5, 90, 20;
    expression = ID;
    frame = 0;
    font = font_caption;
    justify = center;
    colors
      ink = lgray;
      paper = color_btnshadow;
    end_colors;
  end_string_display;

  string_control new_56;
    owner = panel_95;
    position = 35, 30, 60, 26;
    font = font_caption;
    colors
      top_shadow = lgray;
      bottom_shadow = lgray;
      ink = lyellow;
      paper = color_btnshadow;
    end_colors;
  end_string_control;

  switch switch_56;
    const
      ID = 56;
    end_const;
    var
      dummy : boolean;
    end_var;

    owner = panel_95;
    position = 5, 30, 26, 26;
    output = dummy;
    true_icon = 'sw20on.ico';
    false_icon = 'sw20off.ico';
    
    procedure OnOutput( Output : boolean );
    var
      adr : string;
      error : string;
    begin
       adr := DEVICE + '.' + ActiveLinie:s + '.' + ID:s;
       if Output then
         core.DriverQueryProc( 'dali', 'set ' + adr + ' on', &error );
       else
         core.DriverQueryProc( 'dali', 'set ' + adr + ' off', &error );
       end;
       if error = '' then
         error := '<ok>';
       end;
       core.DebugOutput( 'set ' + adr + ' result: ' + error );
    end_procedure;
    
  end_switch;

  panel panel_94;
    owner = Addressing;
    position = 635, 500, 100, 60;
    colors
      color = green;
    end_colors;
  end_panel;

  string_display state_62;
    const
      ID = '62';
    end_const;

    timer = infinite;
    owner = panel_94;
    position = 5, 5, 90, 20;
    expression = ID;
    frame = 0;
    font = font_caption;
    justify = center;
    colors
      ink = lgray;
      paper = color_btnshadow;
    end_colors;
  end_string_display;

  string_control new_62;
    owner = panel_94;
    position = 35, 30, 60, 26;
    font = font_caption;
    colors
      top_shadow = lgray;
      bottom_shadow = lgray;
      ink = lyellow;
      paper = color_btnshadow;
    end_colors;
  end_string_control;

  switch switch_62;
    const
      ID = 62;
    end_const;
    var
      dummy : boolean;
    end_var;

    owner = panel_94;
    position = 5, 30, 26, 26;
    output = dummy;
    true_icon = 'sw20on.ico';
    false_icon = 'sw20off.ico';
    
    procedure OnOutput( Output : boolean );
    var
      adr : string;
      error : string;
    begin
       adr := DEVICE + '.' + ActiveLinie:s + '.' + ID:s;
       if Output then
         core.DriverQueryProc( 'dali', 'set ' + adr + ' on', &error );
       else
         core.DriverQueryProc( 'dali', 'set ' + adr + ' off', &error );
       end;
       if error = '' then
         error := '<ok>';
       end;
       core.DebugOutput( 'set ' + adr + ' result: ' + error );
    end_procedure;
    
  end_switch;

  panel panel_93;
    owner = Addressing;
    position = 740, 500, 100, 60;
    colors
      color = green;
    end_colors;
  end_panel;

  string_display state_63;
    const
      ID = '63';
    end_const;

    timer = infinite;
    owner = panel_93;
    position = 5, 5, 90, 20;
    expression = ID;
    frame = 0;
    font = font_caption;
    justify = center;
    colors
      ink = lgray;
      paper = color_btnshadow;
    end_colors;
  end_string_display;

  string_control new_63;
    owner = panel_93;
    position = 35, 30, 60, 26;
    font = font_caption;
    colors
      top_shadow = lgray;
      bottom_shadow = lgray;
      ink = lyellow;
      paper = color_btnshadow;
    end_colors;
  end_string_control;

  switch switch_63;
    const
      ID = 63;
    end_const;
    var
      dummy : boolean;
    end_var;

    owner = panel_93;
    position = 5, 30, 26, 26;
    output = dummy;
    true_icon = 'sw20on.ico';
    false_icon = 'sw20off.ico';
    
    procedure OnOutput( Output : boolean );
    var
      adr : string;
      error : string;
    begin
       adr := DEVICE + '.' + ActiveLinie:s + '.' + ID:s;
       if Output then
         core.DriverQueryProc( 'dali', 'set ' + adr + ' on', &error );
       else
         core.DriverQueryProc( 'dali', 'set ' + adr + ' off', &error );
       end;
       if error = '' then
         error := '<ok>';
       end;
       core.DebugOutput( 'set ' + adr + ' result: ' + error );
    end_procedure;
    
  end_switch;

  panel panel_92;
    owner = Addressing;
    position = 320, 500, 100, 60;
    colors
      color = green;
    end_colors;
  end_panel;

  string_display state_59;
    const
      ID = '59';
    end_const;

    timer = infinite;
    owner = panel_92;
    position = 5, 5, 90, 20;
    expression = ID;
    frame = 0;
    font = font_caption;
    justify = center;
    colors
      ink = lgray;
      paper = color_btnshadow;
    end_colors;
  end_string_display;

  string_control new_59;
    owner = panel_92;
    position = 35, 30, 60, 26;
    font = font_caption;
    colors
      top_shadow = lgray;
      bottom_shadow = lgray;
      ink = lyellow;
      paper = color_btnshadow;
    end_colors;
  end_string_control;

  switch switch_59;
    const
      ID = 59;
    end_const;
    var
      dummy : boolean;
    end_var;

    owner = panel_92;
    position = 5, 30, 26, 26;
    output = dummy;
    true_icon = 'sw20on.ico';
    false_icon = 'sw20off.ico';
    
    procedure OnOutput( Output : boolean );
    var
      adr : string;
      error : string;
    begin
       adr := DEVICE + '.' + ActiveLinie:s + '.' + ID:s;
       if Output then
         core.DriverQueryProc( 'dali', 'set ' + adr + ' on', &error );
       else
         core.DriverQueryProc( 'dali', 'set ' + adr + ' off', &error );
       end;
       if error = '' then
         error := '<ok>';
       end;
       core.DebugOutput( 'set ' + adr + ' result: ' + error );
    end_procedure;
    
  end_switch;

  panel panel_91;
    owner = Addressing;
    position = 530, 500, 100, 60;
    colors
      color = green;
    end_colors;
  end_panel;

  string_display state_61;
    const
      ID = '61';
    end_const;

    timer = infinite;
    owner = panel_91;
    position = 5, 5, 90, 20;
    expression = ID;
    frame = 0;
    font = font_caption;
    justify = center;
    colors
      ink = lgray;
      paper = color_btnshadow;
    end_colors;
  end_string_display;

  string_control new_61;
    owner = panel_91;
    position = 35, 30, 60, 26;
    font = font_caption;
    colors
      top_shadow = lgray;
      bottom_shadow = lgray;
      ink = lyellow;
      paper = color_btnshadow;
    end_colors;
  end_string_control;

  switch switch_61;
    const
      ID = 61;
    end_const;
    var
      dummy : boolean;
    end_var;

    owner = panel_91;
    position = 5, 30, 26, 26;
    output = dummy;
    true_icon = 'sw20on.ico';
    false_icon = 'sw20off.ico';
    
    procedure OnOutput( Output : boolean );
    var
      adr : string;
      error : string;
    begin
       adr := DEVICE + '.' + ActiveLinie:s + '.' + ID:s;
       if Output then
         core.DriverQueryProc( 'dali', 'set ' + adr + ' on', &error );
       else
         core.DriverQueryProc( 'dali', 'set ' + adr + ' off', &error );
       end;
       if error = '' then
         error := '<ok>';
       end;
       core.DebugOutput( 'set ' + adr + ' result: ' + error );
    end_procedure;
    
  end_switch;

  panel panel_90;
    owner = Addressing;
    position = 425, 500, 100, 60;
    colors
      color = green;
    end_colors;
  end_panel;

  string_display state_60;
    const
      ID = '60';
    end_const;

    timer = infinite;
    owner = panel_90;
    position = 5, 5, 90, 20;
    expression = ID;
    frame = 0;
    font = font_caption;
    justify = center;
    colors
      ink = lgray;
      paper = color_btnshadow;
    end_colors;
  end_string_display;

  string_control new_60;
    owner = panel_90;
    position = 35, 30, 60, 26;
    font = font_caption;
    colors
      top_shadow = lgray;
      bottom_shadow = lgray;
      ink = lyellow;
      paper = color_btnshadow;
    end_colors;
  end_string_control;

  switch switch_60;
    const
      ID = 60;
    end_const;
    var
      dummy : boolean;
    end_var;

    owner = panel_90;
    position = 5, 30, 26, 26;
    output = dummy;
    true_icon = 'sw20on.ico';
    false_icon = 'sw20off.ico';
    
    procedure OnOutput( Output : boolean );
    var
      adr : string;
      error : string;
    begin
       adr := DEVICE + '.' + ActiveLinie:s + '.' + ID:s;
       if Output then
         core.DriverQueryProc( 'dali', 'set ' + adr + ' on', &error );
       else
         core.DriverQueryProc( 'dali', 'set ' + adr + ' off', &error );
       end;
       if error = '' then
         error := '<ok>';
       end;
       core.DebugOutput( 'set ' + adr + ' result: ' + error );
    end_procedure;
    
  end_switch;

  panel panel_89;
    owner = Addressing;
    position = 215, 435, 100, 60;
    colors
      color = green;
    end_colors;
  end_panel;

  string_display state_50;
    const
      ID = '50';
    end_const;

    timer = infinite;
    owner = panel_89;
    position = 5, 5, 90, 20;
    expression = ID;
    frame = 0;
    font = font_caption;
    justify = center;
    colors
      ink = lgray;
      paper = color_btnshadow;
    end_colors;
  end_string_display;

  string_control new_50;
    owner = panel_89;
    position = 35, 30, 60, 26;
    font = font_caption;
    colors
      top_shadow = lgray;
      bottom_shadow = lgray;
      ink = lyellow;
      paper = color_btnshadow;
    end_colors;
  end_string_control;

  switch switch_50;
    const
      ID = 50;
    end_const;
    var
      dummy : boolean;
    end_var;

    owner = panel_89;
    position = 5, 30, 26, 26;
    output = dummy;
    true_icon = 'sw20on.ico';
    false_icon = 'sw20off.ico';
    
    procedure OnOutput( Output : boolean );
    var
      adr : string;
      error : string;
    begin
       adr := DEVICE + '.' + ActiveLinie:s + '.' + ID:s;
       if Output then
         core.DriverQueryProc( 'dali', 'set ' + adr + ' on', &error );
       else
         core.DriverQueryProc( 'dali', 'set ' + adr + ' off', &error );
       end;
       if error = '' then
         error := '<ok>';
       end;
       core.DebugOutput( 'set ' + adr + ' result: ' + error );
    end_procedure;
    
  end_switch;

  panel panel_88;
    owner = Addressing;
    position = 110, 435, 100, 60;
    colors
      color = green;
    end_colors;
  end_panel;

  string_display state_49;
    const
      ID = '49';
    end_const;

    timer = infinite;
    owner = panel_88;
    position = 5, 5, 90, 20;
    expression = ID;
    frame = 0;
    font = font_caption;
    justify = center;
    colors
      ink = lgray;
      paper = color_btnshadow;
    end_colors;
  end_string_display;

  string_control new_49;
    owner = panel_88;
    position = 35, 30, 60, 26;
    font = font_caption;
    colors
      top_shadow = lgray;
      bottom_shadow = lgray;
      ink = lyellow;
      paper = color_btnshadow;
    end_colors;
  end_string_control;

  switch switch_49;
    const
      ID = 49;
    end_const;
    var
      dummy : boolean;
    end_var;

    owner = panel_88;
    position = 5, 30, 26, 26;
    output = dummy;
    true_icon = 'sw20on.ico';
    false_icon = 'sw20off.ico';
    
    procedure OnOutput( Output : boolean );
    var
      adr : string;
      error : string;
    begin
       adr := DEVICE + '.' + ActiveLinie:s + '.' + ID:s;
       if Output then
         core.DriverQueryProc( 'dali', 'set ' + adr + ' on', &error );
       else
         core.DriverQueryProc( 'dali', 'set ' + adr + ' off', &error );
       end;
       if error = '' then
         error := '<ok>';
       end;
       core.DebugOutput( 'set ' + adr + ' result: ' + error );
    end_procedure;
    
  end_switch;

  panel panel_87;
    owner = Addressing;
    position = 5, 435, 100, 60;
    colors
      color = green;
    end_colors;
  end_panel;

  string_display state_48;
    const
      ID = '48';
    end_const;

    timer = infinite;
    owner = panel_87;
    position = 5, 5, 90, 20;
    expression = ID;
    frame = 0;
    font = font_caption;
    justify = center;
    colors
      ink = lgray;
      paper = color_btnshadow;
    end_colors;
  end_string_display;

  string_control new_48;
    owner = panel_87;
    position = 35, 30, 60, 26;
    font = font_caption;
    colors
      top_shadow = lgray;
      bottom_shadow = lgray;
      ink = lyellow;
      paper = color_btnshadow;
    end_colors;
  end_string_control;

  switch switch_48;
    const
      ID = 48;
    end_const;
    var
      dummy : boolean;
    end_var;

    owner = panel_87;
    position = 5, 30, 26, 26;
    output = dummy;
    true_icon = 'sw20on.ico';
    false_icon = 'sw20off.ico';
    
    procedure OnOutput( Output : boolean );
    var
      adr : string;
      error : string;
    begin
       adr := DEVICE + '.' + ActiveLinie:s + '.' + ID:s;
       if Output then
         core.DriverQueryProc( 'dali', 'set ' + adr + ' on', &error );
       else
         core.DriverQueryProc( 'dali', 'set ' + adr + ' off', &error );
       end;
       if error = '' then
         error := '<ok>';
       end;
       core.DebugOutput( 'set ' + adr + ' result: ' + error );
    end_procedure;
    
  end_switch;

  panel panel_86;
    owner = Addressing;
    position = 635, 435, 100, 60;
    colors
      color = green;
    end_colors;
  end_panel;

  string_display state_54;
    const
      ID = '54';
    end_const;

    timer = infinite;
    owner = panel_86;
    position = 5, 5, 90, 20;
    expression = ID;
    frame = 0;
    font = font_caption;
    justify = center;
    colors
      ink = lgray;
      paper = color_btnshadow;
    end_colors;
  end_string_display;

  string_control new_54;
    owner = panel_86;
    position = 35, 30, 60, 26;
    font = font_caption;
    colors
      top_shadow = lgray;
      bottom_shadow = lgray;
      ink = lyellow;
      paper = color_btnshadow;
    end_colors;
  end_string_control;

  switch switch_54;
    const
      ID = 54;
    end_const;
    var
      dummy : boolean;
    end_var;

    owner = panel_86;
    position = 5, 30, 26, 26;
    output = dummy;
    true_icon = 'sw20on.ico';
    false_icon = 'sw20off.ico';
    
    procedure OnOutput( Output : boolean );
    var
      adr : string;
      error : string;
    begin
       adr := DEVICE + '.' + ActiveLinie:s + '.' + ID:s;
       if Output then
         core.DriverQueryProc( 'dali', 'set ' + adr + ' on', &error );
       else
         core.DriverQueryProc( 'dali', 'set ' + adr + ' off', &error );
       end;
       if error = '' then
         error := '<ok>';
       end;
       core.DebugOutput( 'set ' + adr + ' result: ' + error );
    end_procedure;
    
  end_switch;

  panel panel_85;
    owner = Addressing;
    position = 740, 435, 100, 60;
    colors
      color = green;
    end_colors;
  end_panel;

  string_display state_55;
    const
      ID = '55';
    end_const;

    timer = infinite;
    owner = panel_85;
    position = 5, 5, 90, 20;
    expression = ID;
    frame = 0;
    font = font_caption;
    justify = center;
    colors
      ink = lgray;
      paper = color_btnshadow;
    end_colors;
  end_string_display;

  string_control new_55;
    owner = panel_85;
    position = 35, 30, 60, 26;
    font = font_caption;
    colors
      top_shadow = lgray;
      bottom_shadow = lgray;
      ink = lyellow;
      paper = color_btnshadow;
    end_colors;
  end_string_control;

  switch switch_55;
    const
      ID = 55;
    end_const;
    var
      dummy : boolean;
    end_var;

    owner = panel_85;
    position = 5, 30, 26, 26;
    output = dummy;
    true_icon = 'sw20on.ico';
    false_icon = 'sw20off.ico';
    
    procedure OnOutput( Output : boolean );
    var
      adr : string;
      error : string;
    begin
       adr := DEVICE + '.' + ActiveLinie:s + '.' + ID:s;
       if Output then
         core.DriverQueryProc( 'dali', 'set ' + adr + ' on', &error );
       else
         core.DriverQueryProc( 'dali', 'set ' + adr + ' off', &error );
       end;
       if error = '' then
         error := '<ok>';
       end;
       core.DebugOutput( 'set ' + adr + ' result: ' + error );
    end_procedure;
    
  end_switch;

  panel panel_84;
    owner = Addressing;
    position = 320, 435, 100, 60;
    colors
      color = green;
    end_colors;
  end_panel;

  string_display state_51;
    const
      ID = '51';
    end_const;

    timer = infinite;
    owner = panel_84;
    position = 5, 5, 90, 20;
    expression = ID;
    frame = 0;
    font = font_caption;
    justify = center;
    colors
      ink = lgray;
      paper = color_btnshadow;
    end_colors;
  end_string_display;

  string_control new_51;
    owner = panel_84;
    position = 35, 30, 60, 26;
    font = font_caption;
    colors
      top_shadow = lgray;
      bottom_shadow = lgray;
      ink = lyellow;
      paper = color_btnshadow;
    end_colors;
  end_string_control;

  switch switch_51;
    const
      ID = 51;
    end_const;
    var
      dummy : boolean;
    end_var;

    owner = panel_84;
    position = 5, 30, 26, 26;
    output = dummy;
    true_icon = 'sw20on.ico';
    false_icon = 'sw20off.ico';
    
    procedure OnOutput( Output : boolean );
    var
      adr : string;
      error : string;
    begin
       adr := DEVICE + '.' + ActiveLinie:s + '.' + ID:s;
       if Output then
         core.DriverQueryProc( 'dali', 'set ' + adr + ' on', &error );
       else
         core.DriverQueryProc( 'dali', 'set ' + adr + ' off', &error );
       end;
       if error = '' then
         error := '<ok>';
       end;
       core.DebugOutput( 'set ' + adr + ' result: ' + error );
    end_procedure;
    
  end_switch;

  panel panel_83;
    owner = Addressing;
    position = 530, 435, 100, 60;
    colors
      color = green;
    end_colors;
  end_panel;

  string_display state_53;
    const
      ID = '53';
    end_const;

    timer = infinite;
    owner = panel_83;
    position = 5, 5, 90, 20;
    expression = ID;
    frame = 0;
    font = font_caption;
    justify = center;
    colors
      ink = lgray;
      paper = color_btnshadow;
    end_colors;
  end_string_display;

  string_control new_53;
    owner = panel_83;
    position = 35, 30, 60, 26;
    font = font_caption;
    colors
      top_shadow = lgray;
      bottom_shadow = lgray;
      ink = lyellow;
      paper = color_btnshadow;
    end_colors;
  end_string_control;

  switch switch_53;
    const
      ID = 53;
    end_const;
    var
      dummy : boolean;
    end_var;

    owner = panel_83;
    position = 5, 30, 26, 26;
    output = dummy;
    true_icon = 'sw20on.ico';
    false_icon = 'sw20off.ico';
    
    procedure OnOutput( Output : boolean );
    var
      adr : string;
      error : string;
    begin
       adr := DEVICE + '.' + ActiveLinie:s + '.' + ID:s;
       if Output then
         core.DriverQueryProc( 'dali', 'set ' + adr + ' on', &error );
       else
         core.DriverQueryProc( 'dali', 'set ' + adr + ' off', &error );
       end;
       if error = '' then
         error := '<ok>';
       end;
       core.DebugOutput( 'set ' + adr + ' result: ' + error );
    end_procedure;
    
  end_switch;

  panel panel_82;
    owner = Addressing;
    position = 425, 435, 100, 60;
    colors
      color = green;
    end_colors;
  end_panel;

  string_display state_52;
    const
      ID = '52';
    end_const;

    timer = infinite;
    owner = panel_82;
    position = 5, 5, 90, 20;
    expression = ID;
    frame = 0;
    font = font_caption;
    justify = center;
    colors
      ink = lgray;
      paper = color_btnshadow;
    end_colors;
  end_string_display;

  string_control new_52;
    owner = panel_82;
    position = 35, 30, 60, 26;
    font = font_caption;
    colors
      top_shadow = lgray;
      bottom_shadow = lgray;
      ink = lyellow;
      paper = color_btnshadow;
    end_colors;
  end_string_control;

  switch switch_52;
    const
      ID = 52;
    end_const;
    var
      dummy : boolean;
    end_var;

    owner = panel_82;
    position = 5, 30, 26, 26;
    output = dummy;
    true_icon = 'sw20on.ico';
    false_icon = 'sw20off.ico';
    
    procedure OnOutput( Output : boolean );
    var
      adr : string;
      error : string;
    begin
       adr := DEVICE + '.' + ActiveLinie:s + '.' + ID:s;
       if Output then
         core.DriverQueryProc( 'dali', 'set ' + adr + ' on', &error );
       else
         core.DriverQueryProc( 'dali', 'set ' + adr + ' off', &error );
       end;
       if error = '' then
         error := '<ok>';
       end;
       core.DebugOutput( 'set ' + adr + ' result: ' + error );
    end_procedure;
    
  end_switch;

  panel panel_81;
    owner = Addressing;
    position = 215, 370, 100, 60;
    colors
      color = green;
    end_colors;
  end_panel;

  string_display state_42;
    const
      ID = '42';
    end_const;

    timer = infinite;
    owner = panel_81;
    position = 5, 5, 90, 20;
    expression = ID;
    frame = 0;
    font = font_caption;
    justify = center;
    colors
      ink = lgray;
      paper = color_btnshadow;
    end_colors;
  end_string_display;

  string_control new_42;
    owner = panel_81;
    position = 35, 30, 60, 26;
    font = font_caption;
    colors
      top_shadow = lgray;
      bottom_shadow = lgray;
      ink = lyellow;
      paper = color_btnshadow;
    end_colors;
  end_string_control;

  switch switch_42;
    const
      ID = 42;
    end_const;
    var
      dummy : boolean;
    end_var;

    owner = panel_81;
    position = 5, 30, 26, 26;
    output = dummy;
    true_icon = 'sw20on.ico';
    false_icon = 'sw20off.ico';
    
    procedure OnOutput( Output : boolean );
    var
      adr : string;
      error : string;
    begin
       adr := DEVICE + '.' + ActiveLinie:s + '.' + ID:s;
       if Output then
         core.DriverQueryProc( 'dali', 'set ' + adr + ' on', &error );
       else
         core.DriverQueryProc( 'dali', 'set ' + adr + ' off', &error );
       end;
       if error = '' then
         error := '<ok>';
       end;
       core.DebugOutput( 'set ' + adr + ' result: ' + error );
    end_procedure;
    
  end_switch;

  panel panel_80;
    owner = Addressing;
    position = 110, 370, 100, 60;
    colors
      color = green;
    end_colors;
  end_panel;

  string_display state_41;
    const
      ID = '41';
    end_const;

    timer = infinite;
    owner = panel_80;
    position = 5, 5, 90, 20;
    expression = ID;
    frame = 0;
    font = font_caption;
    justify = center;
    colors
      ink = lgray;
      paper = color_btnshadow;
    end_colors;
  end_string_display;

  string_control new_41;
    owner = panel_80;
    position = 35, 30, 60, 26;
    font = font_caption;
    colors
      top_shadow = lgray;
      bottom_shadow = lgray;
      ink = lyellow;
      paper = color_btnshadow;
    end_colors;
  end_string_control;

  switch switch_41;
    const
      ID = 41;
    end_const;
    var
      dummy : boolean;
    end_var;

    owner = panel_80;
    position = 5, 30, 26, 26;
    output = dummy;
    true_icon = 'sw20on.ico';
    false_icon = 'sw20off.ico';
    
    procedure OnOutput( Output : boolean );
    var
      adr : string;
      error : string;
    begin
       adr := DEVICE + '.' + ActiveLinie:s + '.' + ID:s;
       if Output then
         core.DriverQueryProc( 'dali', 'set ' + adr + ' on', &error );
       else
         core.DriverQueryProc( 'dali', 'set ' + adr + ' off', &error );
       end;
       if error = '' then
         error := '<ok>';
       end;
       core.DebugOutput( 'set ' + adr + ' result: ' + error );
    end_procedure;
    
  end_switch;

  panel panel_79;
    owner = Addressing;
    position = 5, 370, 100, 60;
    colors
      color = green;
    end_colors;
  end_panel;

  string_display state_40;
    const
      ID = '40';
    end_const;

    timer = infinite;
    owner = panel_79;
    position = 5, 5, 90, 20;
    expression = ID;
    frame = 0;
    font = font_caption;
    justify = center;
    colors
      ink = lgray;
      paper = color_btnshadow;
    end_colors;
  end_string_display;

  string_control new_40;
    owner = panel_79;
    position = 35, 30, 60, 26;
    font = font_caption;
    colors
      top_shadow = lgray;
      bottom_shadow = lgray;
      ink = lyellow;
      paper = color_btnshadow;
    end_colors;
  end_string_control;

  switch switch_40;
    const
      ID = 40;
    end_const;
    var
      dummy : boolean;
    end_var;

    owner = panel_79;
    position = 5, 30, 26, 26;
    output = dummy;
    true_icon = 'sw20on.ico';
    false_icon = 'sw20off.ico';
    
    procedure OnOutput( Output : boolean );
    var
      adr : string;
      error : string;
    begin
       adr := DEVICE + '.' + ActiveLinie:s + '.' + ID:s;
       if Output then
         core.DriverQueryProc( 'dali', 'set ' + adr + ' on', &error );
       else
         core.DriverQueryProc( 'dali', 'set ' + adr + ' off', &error );
       end;
       if error = '' then
         error := '<ok>';
       end;
       core.DebugOutput( 'set ' + adr + ' result: ' + error );
    end_procedure;
    
  end_switch;

  panel panel_78;
    owner = Addressing;
    position = 635, 370, 100, 60;
    colors
      color = green;
    end_colors;
  end_panel;

  string_display state_46;
    const
      ID = '46';
    end_const;

    timer = infinite;
    owner = panel_78;
    position = 5, 5, 90, 20;
    expression = ID;
    frame = 0;
    font = font_caption;
    justify = center;
    colors
      ink = lgray;
      paper = color_btnshadow;
    end_colors;
  end_string_display;

  string_control new_46;
    owner = panel_78;
    position = 35, 30, 60, 26;
    font = font_caption;
    colors
      top_shadow = lgray;
      bottom_shadow = lgray;
      ink = lyellow;
      paper = color_btnshadow;
    end_colors;
  end_string_control;

  switch switch_46;
    const
      ID = 46;
    end_const;
    var
      dummy : boolean;
    end_var;

    owner = panel_78;
    position = 5, 30, 26, 26;
    output = dummy;
    true_icon = 'sw20on.ico';
    false_icon = 'sw20off.ico';
    
    procedure OnOutput( Output : boolean );
    var
      adr : string;
      error : string;
    begin
       adr := DEVICE + '.' + ActiveLinie:s + '.' + ID:s;
       if Output then
         core.DriverQueryProc( 'dali', 'set ' + adr + ' on', &error );
       else
         core.DriverQueryProc( 'dali', 'set ' + adr + ' off', &error );
       end;
       if error = '' then
         error := '<ok>';
       end;
       core.DebugOutput( 'set ' + adr + ' result: ' + error );
    end_procedure;
    
  end_switch;

  panel panel_77;
    owner = Addressing;
    position = 740, 370, 100, 60;
    colors
      color = green;
    end_colors;
  end_panel;

  string_display state_47;
    const
      ID = '47';
    end_const;

    timer = infinite;
    owner = panel_77;
    position = 5, 5, 90, 20;
    expression = ID;
    frame = 0;
    font = font_caption;
    justify = center;
    colors
      ink = lgray;
      paper = color_btnshadow;
    end_colors;
  end_string_display;

  string_control new_47;
    owner = panel_77;
    position = 35, 30, 60, 26;
    font = font_caption;
    colors
      top_shadow = lgray;
      bottom_shadow = lgray;
      ink = lyellow;
      paper = color_btnshadow;
    end_colors;
  end_string_control;

  switch switch_47;
    const
      ID = 47;
    end_const;
    var
      dummy : boolean;
    end_var;

    owner = panel_77;
    position = 5, 30, 26, 26;
    output = dummy;
    true_icon = 'sw20on.ico';
    false_icon = 'sw20off.ico';
    
    procedure OnOutput( Output : boolean );
    var
      adr : string;
      error : string;
    begin
       adr := DEVICE + '.' + ActiveLinie:s + '.' + ID:s;
       if Output then
         core.DriverQueryProc( 'dali', 'set ' + adr + ' on', &error );
       else
         core.DriverQueryProc( 'dali', 'set ' + adr + ' off', &error );
       end;
       if error = '' then
         error := '<ok>';
       end;
       core.DebugOutput( 'set ' + adr + ' result: ' + error );
    end_procedure;
    
  end_switch;

  panel panel_76;
    owner = Addressing;
    position = 320, 370, 100, 60;
    colors
      color = green;
    end_colors;
  end_panel;

  string_display state_43;
    const
      ID = '43';
    end_const;

    timer = infinite;
    owner = panel_76;
    position = 5, 5, 90, 20;
    expression = ID;
    frame = 0;
    font = font_caption;
    justify = center;
    colors
      ink = lgray;
      paper = color_btnshadow;
    end_colors;
  end_string_display;

  string_control new_43;
    owner = panel_76;
    position = 35, 30, 60, 26;
    font = font_caption;
    colors
      top_shadow = lgray;
      bottom_shadow = lgray;
      ink = lyellow;
      paper = color_btnshadow;
    end_colors;
  end_string_control;

  switch switch_43;
    const
      ID = 43;
    end_const;
    var
      dummy : boolean;
    end_var;

    owner = panel_76;
    position = 5, 30, 26, 26;
    output = dummy;
    true_icon = 'sw20on.ico';
    false_icon = 'sw20off.ico';
    
    procedure OnOutput( Output : boolean );
    var
      adr : string;
      error : string;
    begin
       adr := DEVICE + '.' + ActiveLinie:s + '.' + ID:s;
       if Output then
         core.DriverQueryProc( 'dali', 'set ' + adr + ' on', &error );
       else
         core.DriverQueryProc( 'dali', 'set ' + adr + ' off', &error );
       end;
       if error = '' then
         error := '<ok>';
       end;
       core.DebugOutput( 'set ' + adr + ' result: ' + error );
    end_procedure;
    
  end_switch;

  panel panel_75;
    owner = Addressing;
    position = 530, 370, 100, 60;
    colors
      color = green;
    end_colors;
  end_panel;

  string_display state_45;
    const
      ID = '45';
    end_const;

    timer = infinite;
    owner = panel_75;
    position = 5, 5, 90, 20;
    expression = ID;
    frame = 0;
    font = font_caption;
    justify = center;
    colors
      ink = lgray;
      paper = color_btnshadow;
    end_colors;
  end_string_display;

  string_control new_45;
    owner = panel_75;
    position = 35, 30, 60, 26;
    font = font_caption;
    colors
      top_shadow = lgray;
      bottom_shadow = lgray;
      ink = lyellow;
      paper = color_btnshadow;
    end_colors;
  end_string_control;

  switch switch_45;
    const
      ID = 45;
    end_const;
    var
      dummy : boolean;
    end_var;

    owner = panel_75;
    position = 5, 30, 26, 26;
    output = dummy;
    true_icon = 'sw20on.ico';
    false_icon = 'sw20off.ico';
    
    procedure OnOutput( Output : boolean );
    var
      adr : string;
      error : string;
    begin
       adr := DEVICE + '.' + ActiveLinie:s + '.' + ID:s;
       if Output then
         core.DriverQueryProc( 'dali', 'set ' + adr + ' on', &error );
       else
         core.DriverQueryProc( 'dali', 'set ' + adr + ' off', &error );
       end;
       if error = '' then
         error := '<ok>';
       end;
       core.DebugOutput( 'set ' + adr + ' result: ' + error );
    end_procedure;
    
  end_switch;

  panel panel_74;
    owner = Addressing;
    position = 425, 370, 100, 60;
    colors
      color = green;
    end_colors;
  end_panel;

  string_display state_44;
    const
      ID = '44';
    end_const;

    timer = infinite;
    owner = panel_74;
    position = 5, 5, 90, 20;
    expression = ID;
    frame = 0;
    font = font_caption;
    justify = center;
    colors
      ink = lgray;
      paper = color_btnshadow;
    end_colors;
  end_string_display;

  string_control new_44;
    owner = panel_74;
    position = 35, 30, 60, 26;
    font = font_caption;
    colors
      top_shadow = lgray;
      bottom_shadow = lgray;
      ink = lyellow;
      paper = color_btnshadow;
    end_colors;
  end_string_control;

  switch switch_44;
    const
      ID = 44;
    end_const;
    var
      dummy : boolean;
    end_var;

    owner = panel_74;
    position = 5, 30, 26, 26;
    output = dummy;
    true_icon = 'sw20on.ico';
    false_icon = 'sw20off.ico';
    
    procedure OnOutput( Output : boolean );
    var
      adr : string;
      error : string;
    begin
       adr := DEVICE + '.' + ActiveLinie:s + '.' + ID:s;
       if Output then
         core.DriverQueryProc( 'dali', 'set ' + adr + ' on', &error );
       else
         core.DriverQueryProc( 'dali', 'set ' + adr + ' off', &error );
       end;
       if error = '' then
         error := '<ok>';
       end;
       core.DebugOutput( 'set ' + adr + ' result: ' + error );
    end_procedure;
    
  end_switch;

  panel panel_73;
    owner = Addressing;
    position = 215, 305, 100, 60;
    colors
      color = green;
    end_colors;
  end_panel;

  string_display state_34;
    const
      ID = '34';
    end_const;

    timer = infinite;
    owner = panel_73;
    position = 5, 5, 90, 20;
    expression = ID;
    frame = 0;
    font = font_caption;
    justify = center;
    colors
      ink = lgray;
      paper = color_btnshadow;
    end_colors;
  end_string_display;

  string_control new_34;
    owner = panel_73;
    position = 35, 30, 60, 26;
    font = font_caption;
    colors
      top_shadow = lgray;
      bottom_shadow = lgray;
      ink = lyellow;
      paper = color_btnshadow;
    end_colors;
  end_string_control;

  switch switch_34;
    const
      ID = 34;
    end_const;
    var
      dummy : boolean;
    end_var;

    owner = panel_73;
    position = 5, 30, 26, 26;
    output = dummy;
    true_icon = 'sw20on.ico';
    false_icon = 'sw20off.ico';
    
    procedure OnOutput( Output : boolean );
    var
      adr : string;
      error : string;
    begin
       adr := DEVICE + '.' + ActiveLinie:s + '.' + ID:s;
       if Output then
         core.DriverQueryProc( 'dali', 'set ' + adr + ' on', &error );
       else
         core.DriverQueryProc( 'dali', 'set ' + adr + ' off', &error );
       end;
       if error = '' then
         error := '<ok>';
       end;
       core.DebugOutput( 'set ' + adr + ' result: ' + error );
    end_procedure;
    
  end_switch;

  panel panel_72;
    owner = Addressing;
    position = 110, 305, 100, 60;
    colors
      color = green;
    end_colors;
  end_panel;

  string_display state_33;
    const
      ID = '33';
    end_const;

    timer = infinite;
    owner = panel_72;
    position = 5, 5, 90, 20;
    expression = ID;
    frame = 0;
    font = font_caption;
    justify = center;
    colors
      ink = lgray;
      paper = color_btnshadow;
    end_colors;
  end_string_display;

  string_control new_33;
    owner = panel_72;
    position = 35, 30, 60, 26;
    font = font_caption;
    colors
      top_shadow = lgray;
      bottom_shadow = lgray;
      ink = lyellow;
      paper = color_btnshadow;
    end_colors;
  end_string_control;

  switch switch_33;
    const
      ID = 33;
    end_const;
    var
      dummy : boolean;
    end_var;

    owner = panel_72;
    position = 5, 30, 26, 26;
    output = dummy;
    true_icon = 'sw20on.ico';
    false_icon = 'sw20off.ico';
    
    procedure OnOutput( Output : boolean );
    var
      adr : string;
      error : string;
    begin
       adr := DEVICE + '.' + ActiveLinie:s + '.' + ID:s;
       if Output then
         core.DriverQueryProc( 'dali', 'set ' + adr + ' on', &error );
       else
         core.DriverQueryProc( 'dali', 'set ' + adr + ' off', &error );
       end;
       if error = '' then
         error := '<ok>';
       end;
       core.DebugOutput( 'set ' + adr + ' result: ' + error );
    end_procedure;
    
  end_switch;

  panel panel_71;
    owner = Addressing;
    position = 5, 305, 100, 60;
    colors
      color = green;
    end_colors;
  end_panel;

  string_display state_32;
    const
      ID = '32';
    end_const;

    timer = infinite;
    owner = panel_71;
    position = 5, 5, 90, 20;
    expression = ID;
    frame = 0;
    font = font_caption;
    justify = center;
    colors
      ink = lgray;
      paper = color_btnshadow;
    end_colors;
  end_string_display;

  string_control new_32;
    owner = panel_71;
    position = 35, 30, 60, 26;
    font = font_caption;
    colors
      top_shadow = lgray;
      bottom_shadow = lgray;
      ink = lyellow;
      paper = color_btnshadow;
    end_colors;
  end_string_control;

  switch switch_32;
    const
      ID = 32;
    end_const;
    var
      dummy : boolean;
    end_var;

    owner = panel_71;
    position = 5, 30, 26, 26;
    output = dummy;
    true_icon = 'sw20on.ico';
    false_icon = 'sw20off.ico';
    
    procedure OnOutput( Output : boolean );
    var
      adr : string;
      error : string;
    begin
       adr := DEVICE + '.' + ActiveLinie:s + '.' + ID:s;
       if Output then
         core.DriverQueryProc( 'dali', 'set ' + adr + ' on', &error );
       else
         core.DriverQueryProc( 'dali', 'set ' + adr + ' off', &error );
       end;
       if error = '' then
         error := '<ok>';
       end;
       core.DebugOutput( 'set ' + adr + ' result: ' + error );
    end_procedure;
    
  end_switch;

  panel panel_70;
    owner = Addressing;
    position = 635, 305, 100, 60;
    colors
      color = green;
    end_colors;
  end_panel;

  string_display state_38;
    const
      ID = '38';
    end_const;

    timer = infinite;
    owner = panel_70;
    position = 5, 5, 90, 20;
    expression = ID;
    frame = 0;
    font = font_caption;
    justify = center;
    colors
      ink = lgray;
      paper = color_btnshadow;
    end_colors;
  end_string_display;

  string_control new_38;
    owner = panel_70;
    position = 35, 30, 60, 26;
    font = font_caption;
    colors
      top_shadow = lgray;
      bottom_shadow = lgray;
      ink = lyellow;
      paper = color_btnshadow;
    end_colors;
  end_string_control;

  switch switch_38;
    const
      ID = 38;
    end_const;
    var
      dummy : boolean;
    end_var;

    owner = panel_70;
    position = 5, 30, 26, 26;
    output = dummy;
    true_icon = 'sw20on.ico';
    false_icon = 'sw20off.ico';
    
    procedure OnOutput( Output : boolean );
    var
      adr : string;
      error : string;
    begin
       adr := DEVICE + '.' + ActiveLinie:s + '.' + ID:s;
       if Output then
         core.DriverQueryProc( 'dali', 'set ' + adr + ' on', &error );
       else
         core.DriverQueryProc( 'dali', 'set ' + adr + ' off', &error );
       end;
       if error = '' then
         error := '<ok>';
       end;
       core.DebugOutput( 'set ' + adr + ' result: ' + error );
    end_procedure;
    
  end_switch;

  panel panel_69;
    owner = Addressing;
    position = 740, 305, 100, 60;
    colors
      color = green;
    end_colors;
  end_panel;

  string_display state_39;
    const
      ID = '39';
    end_const;

    timer = infinite;
    owner = panel_69;
    position = 5, 5, 90, 20;
    expression = ID;
    frame = 0;
    font = font_caption;
    justify = center;
    colors
      ink = lgray;
      paper = color_btnshadow;
    end_colors;
  end_string_display;

  string_control new_39;
    owner = panel_69;
    position = 35, 30, 60, 26;
    font = font_caption;
    colors
      top_shadow = lgray;
      bottom_shadow = lgray;
      ink = lyellow;
      paper = color_btnshadow;
    end_colors;
  end_string_control;

  switch switch_39;
    const
      ID = 39;
    end_const;
    var
      dummy : boolean;
    end_var;

    owner = panel_69;
    position = 5, 30, 26, 26;
    output = dummy;
    true_icon = 'sw20on.ico';
    false_icon = 'sw20off.ico';
    
    procedure OnOutput( Output : boolean );
    var
      adr : string;
      error : string;
    begin
       adr := DEVICE + '.' + ActiveLinie:s + '.' + ID:s;
       if Output then
         core.DriverQueryProc( 'dali', 'set ' + adr + ' on', &error );
       else
         core.DriverQueryProc( 'dali', 'set ' + adr + ' off', &error );
       end;
       if error = '' then
         error := '<ok>';
       end;
       core.DebugOutput( 'set ' + adr + ' result: ' + error );
    end_procedure;
    
  end_switch;

  panel panel_68;
    owner = Addressing;
    position = 320, 305, 100, 60;
    colors
      color = green;
    end_colors;
  end_panel;

  string_display state_35;
    const
      ID = '35';
    end_const;

    timer = infinite;
    owner = panel_68;
    position = 5, 5, 90, 20;
    expression = ID;
    frame = 0;
    font = font_caption;
    justify = center;
    colors
      ink = lgray;
      paper = color_btnshadow;
    end_colors;
  end_string_display;

  string_control new_35;
    owner = panel_68;
    position = 35, 30, 60, 26;
    font = font_caption;
    colors
      top_shadow = lgray;
      bottom_shadow = lgray;
      ink = lyellow;
      paper = color_btnshadow;
    end_colors;
  end_string_control;

  switch switch_35;
    const
      ID = 35;
    end_const;
    var
      dummy : boolean;
    end_var;

    owner = panel_68;
    position = 5, 30, 26, 26;
    output = dummy;
    true_icon = 'sw20on.ico';
    false_icon = 'sw20off.ico';
    
    procedure OnOutput( Output : boolean );
    var
      adr : string;
      error : string;
    begin
       adr := DEVICE + '.' + ActiveLinie:s + '.' + ID:s;
       if Output then
         core.DriverQueryProc( 'dali', 'set ' + adr + ' on', &error );
       else
         core.DriverQueryProc( 'dali', 'set ' + adr + ' off', &error );
       end;
       if error = '' then
         error := '<ok>';
       end;
       core.DebugOutput( 'set ' + adr + ' result: ' + error );
    end_procedure;
    
  end_switch;

  panel panel_67;
    owner = Addressing;
    position = 530, 305, 100, 60;
    colors
      color = green;
    end_colors;
  end_panel;

  string_display state_37;
    const
      ID = '37';
    end_const;

    timer = infinite;
    owner = panel_67;
    position = 5, 5, 90, 20;
    expression = ID;
    frame = 0;
    font = font_caption;
    justify = center;
    colors
      ink = lgray;
      paper = color_btnshadow;
    end_colors;
  end_string_display;

  string_control new_37;
    owner = panel_67;
    position = 35, 30, 60, 26;
    font = font_caption;
    colors
      top_shadow = lgray;
      bottom_shadow = lgray;
      ink = lyellow;
      paper = color_btnshadow;
    end_colors;
  end_string_control;

  switch switch_37;
    const
      ID = 37;
    end_const;
    var
      dummy : boolean;
    end_var;

    owner = panel_67;
    position = 5, 30, 26, 26;
    output = dummy;
    true_icon = 'sw20on.ico';
    false_icon = 'sw20off.ico';
    
    procedure OnOutput( Output : boolean );
    var
      adr : string;
      error : string;
    begin
       adr := DEVICE + '.' + ActiveLinie:s + '.' + ID:s;
       if Output then
         core.DriverQueryProc( 'dali', 'set ' + adr + ' on', &error );
       else
         core.DriverQueryProc( 'dali', 'set ' + adr + ' off', &error );
       end;
       if error = '' then
         error := '<ok>';
       end;
       core.DebugOutput( 'set ' + adr + ' result: ' + error );
    end_procedure;
    
  end_switch;

  panel panel_66;
    owner = Addressing;
    position = 425, 305, 100, 60;
    colors
      color = green;
    end_colors;
  end_panel;

  string_display state_36;
    const
      ID = '36';
    end_const;

    timer = infinite;
    owner = panel_66;
    position = 5, 5, 90, 20;
    expression = ID;
    frame = 0;
    font = font_caption;
    justify = center;
    colors
      ink = lgray;
      paper = color_btnshadow;
    end_colors;
  end_string_display;

  string_control new_36;
    owner = panel_66;
    position = 35, 30, 60, 26;
    font = font_caption;
    colors
      top_shadow = lgray;
      bottom_shadow = lgray;
      ink = lyellow;
      paper = color_btnshadow;
    end_colors;
  end_string_control;

  switch switch_36;
    const
      ID = 36;
    end_const;
    var
      dummy : boolean;
    end_var;

    owner = panel_66;
    position = 5, 30, 26, 26;
    output = dummy;
    true_icon = 'sw20on.ico';
    false_icon = 'sw20off.ico';
    
    procedure OnOutput( Output : boolean );
    var
      adr : string;
      error : string;
    begin
       adr := DEVICE + '.' + ActiveLinie:s + '.' + ID:s;
       if Output then
         core.DriverQueryProc( 'dali', 'set ' + adr + ' on', &error );
       else
         core.DriverQueryProc( 'dali', 'set ' + adr + ' off', &error );
       end;
       if error = '' then
         error := '<ok>';
       end;
       core.DebugOutput( 'set ' + adr + ' result: ' + error );
    end_procedure;
    
  end_switch;

  panel panel_65;
    owner = Addressing;
    position = 215, 240, 100, 60;
    colors
      color = green;
    end_colors;
  end_panel;

  string_display state_26;
    const
      ID = '26';
    end_const;

    timer = infinite;
    owner = panel_65;
    position = 5, 5, 90, 20;
    expression = ID;
    frame = 0;
    font = font_caption;
    justify = center;
    colors
      ink = lgray;
      paper = color_btnshadow;
    end_colors;
  end_string_display;

  string_control new_26;
    owner = panel_65;
    position = 35, 30, 60, 26;
    font = font_caption;
    colors
      top_shadow = lgray;
      bottom_shadow = lgray;
      ink = lyellow;
      paper = color_btnshadow;
    end_colors;
  end_string_control;

  switch switch_26;
    const
      ID = 26;
    end_const;
    var
      dummy : boolean;
    end_var;

    owner = panel_65;
    position = 5, 30, 26, 26;
    output = dummy;
    true_icon = 'sw20on.ico';
    false_icon = 'sw20off.ico';
    
    procedure OnOutput( Output : boolean );
    var
      adr : string;
      error : string;
    begin
       adr := DEVICE + '.' + ActiveLinie:s + '.' + ID:s;
       if Output then
         core.DriverQueryProc( 'dali', 'set ' + adr + ' on', &error );
       else
         core.DriverQueryProc( 'dali', 'set ' + adr + ' off', &error );
       end;
       if error = '' then
         error := '<ok>';
       end;
       core.DebugOutput( 'set ' + adr + ' result: ' + error );
    end_procedure;
    
  end_switch;

  panel panel_64;
    owner = Addressing;
    position = 110, 240, 100, 60;
    colors
      color = green;
    end_colors;
  end_panel;

  string_display state_25;
    const
      ID = '25';
    end_const;

    timer = infinite;
    owner = panel_64;
    position = 5, 5, 90, 20;
    expression = ID;
    frame = 0;
    font = font_caption;
    justify = center;
    colors
      ink = lgray;
      paper = color_btnshadow;
    end_colors;
  end_string_display;

  string_control new_25;
    owner = panel_64;
    position = 35, 30, 60, 26;
    font = font_caption;
    colors
      top_shadow = lgray;
      bottom_shadow = lgray;
      ink = lyellow;
      paper = color_btnshadow;
    end_colors;
  end_string_control;

  switch switch_25;
    const
      ID = 25;
    end_const;
    var
      dummy : boolean;
    end_var;

    owner = panel_64;
    position = 5, 30, 26, 26;
    output = dummy;
    true_icon = 'sw20on.ico';
    false_icon = 'sw20off.ico';
    
    procedure OnOutput( Output : boolean );
    var
      adr : string;
      error : string;
    begin
       adr := DEVICE + '.' + ActiveLinie:s + '.' + ID:s;
       if Output then
         core.DriverQueryProc( 'dali', 'set ' + adr + ' on', &error );
       else
         core.DriverQueryProc( 'dali', 'set ' + adr + ' off', &error );
       end;
       if error = '' then
         error := '<ok>';
       end;
       core.DebugOutput( 'set ' + adr + ' result: ' + error );
    end_procedure;
    
  end_switch;

  panel panel_63;
    owner = Addressing;
    position = 5, 240, 100, 60;
    colors
      color = green;
    end_colors;
  end_panel;

  string_display state_24;
    const
      ID = '24';
    end_const;

    timer = infinite;
    owner = panel_63;
    position = 5, 5, 90, 20;
    expression = ID;
    frame = 0;
    font = font_caption;
    justify = center;
    colors
      ink = lgray;
      paper = color_btnshadow;
    end_colors;
  end_string_display;

  string_control new_24;
    owner = panel_63;
    position = 35, 30, 60, 26;
    font = font_caption;
    colors
      top_shadow = lgray;
      bottom_shadow = lgray;
      ink = lyellow;
      paper = color_btnshadow;
    end_colors;
  end_string_control;

  switch switch_24;
    const
      ID = 24;
    end_const;
    var
      dummy : boolean;
    end_var;

    owner = panel_63;
    position = 5, 30, 26, 26;
    output = dummy;
    true_icon = 'sw20on.ico';
    false_icon = 'sw20off.ico';
    
    procedure OnOutput( Output : boolean );
    var
      adr : string;
      error : string;
    begin
       adr := DEVICE + '.' + ActiveLinie:s + '.' + ID:s;
       if Output then
         core.DriverQueryProc( 'dali', 'set ' + adr + ' on', &error );
       else
         core.DriverQueryProc( 'dali', 'set ' + adr + ' off', &error );
       end;
       if error = '' then
         error := '<ok>';
       end;
       core.DebugOutput( 'set ' + adr + ' result: ' + error );
    end_procedure;
    
  end_switch;

  panel panel_62;
    owner = Addressing;
    position = 635, 240, 100, 60;
    colors
      color = green;
    end_colors;
  end_panel;

  string_display state_30;
    const
      ID = '30';
    end_const;

    timer = infinite;
    owner = panel_62;
    position = 5, 5, 90, 20;
    expression = ID;
    frame = 0;
    font = font_caption;
    justify = center;
    colors
      ink = lgray;
      paper = color_btnshadow;
    end_colors;
  end_string_display;

  string_control new_30;
    owner = panel_62;
    position = 35, 30, 60, 26;
    font = font_caption;
    colors
      top_shadow = lgray;
      bottom_shadow = lgray;
      ink = lyellow;
      paper = color_btnshadow;
    end_colors;
  end_string_control;

  switch switch_30;
    const
      ID = 30;
    end_const;
    var
      dummy : boolean;
    end_var;

    owner = panel_62;
    position = 5, 30, 26, 26;
    output = dummy;
    true_icon = 'sw20on.ico';
    false_icon = 'sw20off.ico';
    
    procedure OnOutput( Output : boolean );
    var
      adr : string;
      error : string;
    begin
       adr := DEVICE + '.' + ActiveLinie:s + '.' + ID:s;
       if Output then
         core.DriverQueryProc( 'dali', 'set ' + adr + ' on', &error );
       else
         core.DriverQueryProc( 'dali', 'set ' + adr + ' off', &error );
       end;
       if error = '' then
         error := '<ok>';
       end;
       core.DebugOutput( 'set ' + adr + ' result: ' + error );
    end_procedure;
    
  end_switch;

  panel panel_61;
    owner = Addressing;
    position = 740, 240, 100, 60;
    colors
      color = green;
    end_colors;
  end_panel;

  string_display state_31;
    const
      ID = '31';
    end_const;

    timer = infinite;
    owner = panel_61;
    position = 5, 5, 90, 20;
    expression = ID;
    frame = 0;
    font = font_caption;
    justify = center;
    colors
      ink = lgray;
      paper = color_btnshadow;
    end_colors;
  end_string_display;

  string_control new_31;
    owner = panel_61;
    position = 35, 30, 60, 26;
    font = font_caption;
    colors
      top_shadow = lgray;
      bottom_shadow = lgray;
      ink = lyellow;
      paper = color_btnshadow;
    end_colors;
  end_string_control;

  switch switch_31;
    const
      ID = 31;
    end_const;
    var
      dummy : boolean;
    end_var;

    owner = panel_61;
    position = 5, 30, 26, 26;
    output = dummy;
    true_icon = 'sw20on.ico';
    false_icon = 'sw20off.ico';
    
    procedure OnOutput( Output : boolean );
    var
      adr : string;
      error : string;
    begin
       adr := DEVICE + '.' + ActiveLinie:s + '.' + ID:s;
       if Output then
         core.DriverQueryProc( 'dali', 'set ' + adr + ' on', &error );
       else
         core.DriverQueryProc( 'dali', 'set ' + adr + ' off', &error );
       end;
       if error = '' then
         error := '<ok>';
       end;
       core.DebugOutput( 'set ' + adr + ' result: ' + error );
    end_procedure;
    
  end_switch;

  panel panel_60;
    owner = Addressing;
    position = 320, 240, 100, 60;
    colors
      color = green;
    end_colors;
  end_panel;

  string_display state_27;
    const
      ID = '27';
    end_const;

    timer = infinite;
    owner = panel_60;
    position = 5, 5, 90, 20;
    expression = ID;
    frame = 0;
    font = font_caption;
    justify = center;
    colors
      ink = lgray;
      paper = color_btnshadow;
    end_colors;
  end_string_display;

  string_control new_27;
    owner = panel_60;
    position = 35, 30, 60, 26;
    font = font_caption;
    colors
      top_shadow = lgray;
      bottom_shadow = lgray;
      ink = lyellow;
      paper = color_btnshadow;
    end_colors;
  end_string_control;

  switch switch_27;
    const
      ID = 27;
    end_const;
    var
      dummy : boolean;
    end_var;

    owner = panel_60;
    position = 5, 30, 26, 26;
    output = dummy;
    true_icon = 'sw20on.ico';
    false_icon = 'sw20off.ico';
    
    procedure OnOutput( Output : boolean );
    var
      adr : string;
      error : string;
    begin
       adr := DEVICE + '.' + ActiveLinie:s + '.' + ID:s;
       if Output then
         core.DriverQueryProc( 'dali', 'set ' + adr + ' on', &error );
       else
         core.DriverQueryProc( 'dali', 'set ' + adr + ' off', &error );
       end;
       if error = '' then
         error := '<ok>';
       end;
       core.DebugOutput( 'set ' + adr + ' result: ' + error );
    end_procedure;
    
  end_switch;

  panel panel_59;
    owner = Addressing;
    position = 530, 240, 100, 60;
    colors
      color = green;
    end_colors;
  end_panel;

  string_display state_29;
    const
      ID = '29';
    end_const;

    timer = infinite;
    owner = panel_59;
    position = 5, 5, 90, 20;
    expression = ID;
    frame = 0;
    font = font_caption;
    justify = center;
    colors
      ink = lgray;
      paper = color_btnshadow;
    end_colors;
  end_string_display;

  string_control new_29;
    owner = panel_59;
    position = 35, 30, 60, 26;
    font = font_caption;
    colors
      top_shadow = lgray;
      bottom_shadow = lgray;
      ink = lyellow;
      paper = color_btnshadow;
    end_colors;
  end_string_control;

  switch switch_29;
    const
      ID = 29;
    end_const;
    var
      dummy : boolean;
    end_var;

    owner = panel_59;
    position = 5, 30, 26, 26;
    output = dummy;
    true_icon = 'sw20on.ico';
    false_icon = 'sw20off.ico';
    
    procedure OnOutput( Output : boolean );
    var
      adr : string;
      error : string;
    begin
       adr := DEVICE + '.' + ActiveLinie:s + '.' + ID:s;
       if Output then
         core.DriverQueryProc( 'dali', 'set ' + adr + ' on', &error );
       else
         core.DriverQueryProc( 'dali', 'set ' + adr + ' off', &error );
       end;
       if error = '' then
         error := '<ok>';
       end;
       core.DebugOutput( 'set ' + adr + ' result: ' + error );
    end_procedure;
    
  end_switch;

  panel panel_58;
    owner = Addressing;
    position = 425, 240, 100, 60;
    colors
      color = green;
    end_colors;
  end_panel;

  string_display state_28;
    const
      ID = '28';
    end_const;

    timer = infinite;
    owner = panel_58;
    position = 5, 5, 90, 20;
    expression = ID;
    frame = 0;
    font = font_caption;
    justify = center;
    colors
      ink = lgray;
      paper = color_btnshadow;
    end_colors;
  end_string_display;

  string_control new_28;
    owner = panel_58;
    position = 35, 30, 60, 26;
    font = font_caption;
    colors
      top_shadow = lgray;
      bottom_shadow = lgray;
      ink = lyellow;
      paper = color_btnshadow;
    end_colors;
  end_string_control;

  switch switch_28;
    const
      ID = 28;
    end_const;
    var
      dummy : boolean;
    end_var;

    owner = panel_58;
    position = 5, 30, 26, 26;
    output = dummy;
    true_icon = 'sw20on.ico';
    false_icon = 'sw20off.ico';
    
    procedure OnOutput( Output : boolean );
    var
      adr : string;
      error : string;
    begin
       adr := DEVICE + '.' + ActiveLinie:s + '.' + ID:s;
       if Output then
         core.DriverQueryProc( 'dali', 'set ' + adr + ' on', &error );
       else
         core.DriverQueryProc( 'dali', 'set ' + adr + ' off', &error );
       end;
       if error = '' then
         error := '<ok>';
       end;
       core.DebugOutput( 'set ' + adr + ' result: ' + error );
    end_procedure;
    
  end_switch;

  panel panel_57;
    owner = Addressing;
    position = 215, 175, 100, 60;
    colors
      color = green;
    end_colors;
  end_panel;

  string_display state_18;
    const
      ID = '18';
    end_const;

    timer = infinite;
    owner = panel_57;
    position = 5, 5, 90, 20;
    expression = ID;
    frame = 0;
    font = font_caption;
    justify = center;
    colors
      ink = lgray;
      paper = color_btnshadow;
    end_colors;
  end_string_display;

  string_control new_18;
    owner = panel_57;
    position = 35, 30, 60, 26;
    font = font_caption;
    colors
      top_shadow = lgray;
      bottom_shadow = lgray;
      ink = lyellow;
      paper = color_btnshadow;
    end_colors;
  end_string_control;

  switch switch_18;
    const
      ID = 18;
    end_const;
    var
      dummy : boolean;
    end_var;

    owner = panel_57;
    position = 5, 30, 26, 26;
    output = dummy;
    true_icon = 'sw20on.ico';
    false_icon = 'sw20off.ico';
    
    procedure OnOutput( Output : boolean );
    var
      adr : string;
      error : string;
    begin
       adr := DEVICE + '.' + ActiveLinie:s + '.' + ID:s;
       if Output then
         core.DriverQueryProc( 'dali', 'set ' + adr + ' on', &error );
       else
         core.DriverQueryProc( 'dali', 'set ' + adr + ' off', &error );
       end;
       if error = '' then
         error := '<ok>';
       end;
       core.DebugOutput( 'set ' + adr + ' result: ' + error );
    end_procedure;
    
  end_switch;

  panel panel_56;
    owner = Addressing;
    position = 110, 175, 100, 60;
    colors
      color = green;
    end_colors;
  end_panel;

  string_display state_17;
    const
      ID = '17';
    end_const;

    timer = infinite;
    owner = panel_56;
    position = 5, 5, 90, 20;
    expression = ID;
    frame = 0;
    font = font_caption;
    justify = center;
    colors
      ink = lgray;
      paper = color_btnshadow;
    end_colors;
  end_string_display;

  string_control new_17;
    owner = panel_56;
    position = 35, 30, 60, 26;
    font = font_caption;
    colors
      top_shadow = lgray;
      bottom_shadow = lgray;
      ink = lyellow;
      paper = color_btnshadow;
    end_colors;
  end_string_control;

  switch switch_17;
    const
      ID = 17;
    end_const;
    var
      dummy : boolean;
    end_var;

    owner = panel_56;
    position = 5, 30, 26, 26;
    output = dummy;
    true_icon = 'sw20on.ico';
    false_icon = 'sw20off.ico';
    
    procedure OnOutput( Output : boolean );
    var
      adr : string;
      error : string;
    begin
       adr := DEVICE + '.' + ActiveLinie:s + '.' + ID:s;
       if Output then
         core.DriverQueryProc( 'dali', 'set ' + adr + ' on', &error );
       else
         core.DriverQueryProc( 'dali', 'set ' + adr + ' off', &error );
       end;
       if error = '' then
         error := '<ok>';
       end;
       core.DebugOutput( 'set ' + adr + ' result: ' + error );
    end_procedure;
    
  end_switch;

  panel panel_55;
    owner = Addressing;
    position = 5, 175, 100, 60;
    colors
      color = green;
    end_colors;
  end_panel;

  string_display state_16;
    const
      ID = '16';
    end_const;

    timer = infinite;
    owner = panel_55;
    position = 5, 5, 90, 20;
    expression = ID;
    frame = 0;
    font = font_caption;
    justify = center;
    colors
      ink = lgray;
      paper = color_btnshadow;
    end_colors;
  end_string_display;

  string_control new_16;
    owner = panel_55;
    position = 35, 30, 60, 26;
    font = font_caption;
    colors
      top_shadow = lgray;
      bottom_shadow = lgray;
      ink = lyellow;
      paper = color_btnshadow;
    end_colors;
  end_string_control;

  switch switch_16;
    const
      ID = 16;
    end_const;
    var
      dummy : boolean;
    end_var;

    owner = panel_55;
    position = 5, 30, 26, 26;
    output = dummy;
    true_icon = 'sw20on.ico';
    false_icon = 'sw20off.ico';
    
    procedure OnOutput( Output : boolean );
    var
      adr : string;
      error : string;
    begin
       adr := DEVICE + '.' + ActiveLinie:s + '.' + ID:s;
       if Output then
         core.DriverQueryProc( 'dali', 'set ' + adr + ' on', &error );
       else
         core.DriverQueryProc( 'dali', 'set ' + adr + ' off', &error );
       end;
       if error = '' then
         error := '<ok>';
       end;
       core.DebugOutput( 'set ' + adr + ' result: ' + error );
    end_procedure;
    
  end_switch;

  panel panel_54;
    owner = Addressing;
    position = 635, 175, 100, 60;
    colors
      color = green;
    end_colors;
  end_panel;

  string_display state_22;
    const
      ID = '22';
    end_const;

    timer = infinite;
    owner = panel_54;
    position = 5, 5, 90, 20;
    expression = ID;
    frame = 0;
    font = font_caption;
    justify = center;
    colors
      ink = lgray;
      paper = color_btnshadow;
    end_colors;
  end_string_display;

  string_control new_22;
    owner = panel_54;
    position = 35, 30, 60, 26;
    font = font_caption;
    colors
      top_shadow = lgray;
      bottom_shadow = lgray;
      ink = lyellow;
      paper = color_btnshadow;
    end_colors;
  end_string_control;

  switch switch_22;
    const
      ID = 22;
    end_const;
    var
      dummy : boolean;
    end_var;

    owner = panel_54;
    position = 5, 30, 26, 26;
    output = dummy;
    true_icon = 'sw20on.ico';
    false_icon = 'sw20off.ico';
    
    procedure OnOutput( Output : boolean );
    var
      adr : string;
      error : string;
    begin
       adr := DEVICE + '.' + ActiveLinie:s + '.' + ID:s;
       if Output then
         core.DriverQueryProc( 'dali', 'set ' + adr + ' on', &error );
       else
         core.DriverQueryProc( 'dali', 'set ' + adr + ' off', &error );
       end;
       if error = '' then
         error := '<ok>';
       end;
       core.DebugOutput( 'set ' + adr + ' result: ' + error );
    end_procedure;
    
  end_switch;

  panel panel_53;
    owner = Addressing;
    position = 740, 175, 100, 60;
    colors
      color = green;
    end_colors;
  end_panel;

  string_display state_23;
    const
      ID = '23';
    end_const;

    timer = infinite;
    owner = panel_53;
    position = 5, 5, 90, 20;
    expression = ID;
    frame = 0;
    font = font_caption;
    justify = center;
    colors
      ink = lgray;
      paper = color_btnshadow;
    end_colors;
  end_string_display;

  string_control new_23;
    owner = panel_53;
    position = 35, 30, 60, 26;
    font = font_caption;
    colors
      top_shadow = lgray;
      bottom_shadow = lgray;
      ink = lyellow;
      paper = color_btnshadow;
    end_colors;
  end_string_control;

  switch switch_23;
    const
      ID = 23;
    end_const;
    var
      dummy : boolean;
    end_var;

    owner = panel_53;
    position = 5, 30, 26, 26;
    output = dummy;
    true_icon = 'sw20on.ico';
    false_icon = 'sw20off.ico';
    
    procedure OnOutput( Output : boolean );
    var
      adr : string;
      error : string;
    begin
       adr := DEVICE + '.' + ActiveLinie:s + '.' + ID:s;
       if Output then
         core.DriverQueryProc( 'dali', 'set ' + adr + ' on', &error );
       else
         core.DriverQueryProc( 'dali', 'set ' + adr + ' off', &error );
       end;
       if error = '' then
         error := '<ok>';
       end;
       core.DebugOutput( 'set ' + adr + ' result: ' + error );
    end_procedure;
    
  end_switch;

  panel panel_52;
    owner = Addressing;
    position = 320, 175, 100, 60;
    colors
      color = green;
    end_colors;
  end_panel;

  string_display state_19;
    const
      ID = '19';
    end_const;

    timer = infinite;
    owner = panel_52;
    position = 5, 5, 90, 20;
    expression = ID;
    frame = 0;
    font = font_caption;
    justify = center;
    colors
      ink = lgray;
      paper = color_btnshadow;
    end_colors;
  end_string_display;

  string_control new_19;
    owner = panel_52;
    position = 35, 30, 60, 26;
    font = font_caption;
    colors
      top_shadow = lgray;
      bottom_shadow = lgray;
      ink = lyellow;
      paper = color_btnshadow;
    end_colors;
  end_string_control;

  switch switch_19;
    const
      ID = 19;
    end_const;
    var
      dummy : boolean;
    end_var;

    owner = panel_52;
    position = 5, 30, 26, 26;
    output = dummy;
    true_icon = 'sw20on.ico';
    false_icon = 'sw20off.ico';
    
    procedure OnOutput( Output : boolean );
    var
      adr : string;
      error : string;
    begin
       adr := DEVICE + '.' + ActiveLinie:s + '.' + ID:s;
       if Output then
         core.DriverQueryProc( 'dali', 'set ' + adr + ' on', &error );
       else
         core.DriverQueryProc( 'dali', 'set ' + adr + ' off', &error );
       end;
       if error = '' then
         error := '<ok>';
       end;
       core.DebugOutput( 'set ' + adr + ' result: ' + error );
    end_procedure;
    
  end_switch;

  panel panel_51;
    owner = Addressing;
    position = 530, 175, 100, 60;
    colors
      color = green;
    end_colors;
  end_panel;

  string_display state_21;
    const
      ID = '21';
    end_const;

    timer = infinite;
    owner = panel_51;
    position = 5, 5, 90, 20;
    expression = ID;
    frame = 0;
    font = font_caption;
    justify = center;
    colors
      ink = lgray;
      paper = color_btnshadow;
    end_colors;
  end_string_display;

  string_control new_21;
    owner = panel_51;
    position = 35, 30, 60, 26;
    font = font_caption;
    colors
      top_shadow = lgray;
      bottom_shadow = lgray;
      ink = lyellow;
      paper = color_btnshadow;
    end_colors;
  end_string_control;

  switch switch_21;
    const
      ID = 21;
    end_const;
    var
      dummy : boolean;
    end_var;

    owner = panel_51;
    position = 5, 30, 26, 26;
    output = dummy;
    true_icon = 'sw20on.ico';
    false_icon = 'sw20off.ico';
    
    procedure OnOutput( Output : boolean );
    var
      adr : string;
      error : string;
    begin
       adr := DEVICE + '.' + ActiveLinie:s + '.' + ID:s;
       if Output then
         core.DriverQueryProc( 'dali', 'set ' + adr + ' on', &error );
       else
         core.DriverQueryProc( 'dali', 'set ' + adr + ' off', &error );
       end;
       if error = '' then
         error := '<ok>';
       end;
       core.DebugOutput( 'set ' + adr + ' result: ' + error );
    end_procedure;
    
  end_switch;

  panel panel_50;
    owner = Addressing;
    position = 425, 175, 100, 60;
    colors
      color = green;
    end_colors;
  end_panel;

  string_display state_20;
    const
      ID = '20';
    end_const;

    timer = infinite;
    owner = panel_50;
    position = 5, 5, 90, 20;
    expression = ID;
    frame = 0;
    font = font_caption;
    justify = center;
    colors
      ink = lgray;
      paper = color_btnshadow;
    end_colors;
  end_string_display;

  string_control new_20;
    owner = panel_50;
    position = 35, 30, 60, 26;
    font = font_caption;
    colors
      top_shadow = lgray;
      bottom_shadow = lgray;
      ink = lyellow;
      paper = color_btnshadow;
    end_colors;
  end_string_control;

  switch switch_20;
    const
      ID = 20;
    end_const;
    var
      dummy : boolean;
    end_var;

    owner = panel_50;
    position = 5, 30, 26, 26;
    output = dummy;
    true_icon = 'sw20on.ico';
    false_icon = 'sw20off.ico';
    
    procedure OnOutput( Output : boolean );
    var
      adr : string;
      error : string;
    begin
       adr := DEVICE + '.' + ActiveLinie:s + '.' + ID:s;
       if Output then
         core.DriverQueryProc( 'dali', 'set ' + adr + ' on', &error );
       else
         core.DriverQueryProc( 'dali', 'set ' + adr + ' off', &error );
       end;
       if error = '' then
         error := '<ok>';
       end;
       core.DebugOutput( 'set ' + adr + ' result: ' + error );
    end_procedure;
    
  end_switch;

  panel panel_48;
    owner = Addressing;
    position = 215, 110, 100, 60;
    colors
      color = green;
    end_colors;
  end_panel;

  string_display state_10;
    const
      ID = '10';
    end_const;

    timer = infinite;
    owner = panel_48;
    position = 5, 5, 90, 20;
    expression = ID;
    frame = 0;
    font = font_caption;
    justify = center;
    colors
      ink = lgray;
      paper = color_btnshadow;
    end_colors;
  end_string_display;

  string_control new_10;
    owner = panel_48;
    position = 35, 30, 60, 26;
    font = font_caption;
    colors
      top_shadow = lgray;
      bottom_shadow = lgray;
      ink = lyellow;
      paper = color_btnshadow;
    end_colors;
  end_string_control;

  switch switch_10;
    const
      ID = 10;
    end_const;
    var
      dummy : boolean;
    end_var;

    owner = panel_48;
    position = 5, 30, 26, 26;
    output = dummy;
    true_icon = 'sw20on.ico';
    false_icon = 'sw20off.ico';
    
    procedure OnOutput( Output : boolean );
    var
      adr : string;
      error : string;
    begin
       adr := DEVICE + '.' + ActiveLinie:s + '.' + ID:s;
       if Output then
         core.DriverQueryProc( 'dali', 'set ' + adr + ' on', &error );
       else
         core.DriverQueryProc( 'dali', 'set ' + adr + ' off', &error );
       end;
       if error = '' then
         error := '<ok>';
       end;
       core.DebugOutput( 'set ' + adr + ' result: ' + error );
    end_procedure;
    
  end_switch;

  panel panel_40;
    owner = Addressing;
    position = 110, 110, 100, 60;
    colors
      color = green;
    end_colors;
  end_panel;

  string_display state_09;
    const
      ID = '09';
    end_const;

    timer = infinite;
    owner = panel_40;
    position = 5, 5, 90, 20;
    expression = ID;
    frame = 0;
    font = font_caption;
    justify = center;
    colors
      ink = lgray;
      paper = color_btnshadow;
    end_colors;
  end_string_display;

  string_control new_09;
    owner = panel_40;
    position = 35, 30, 60, 26;
    font = font_caption;
    colors
      top_shadow = lgray;
      bottom_shadow = lgray;
      ink = lyellow;
      paper = color_btnshadow;
    end_colors;
  end_string_control;

  switch switch_09;
    const
      ID = 9;
    end_const;
    var
      dummy : boolean;
    end_var;

    owner = panel_40;
    position = 5, 30, 26, 26;
    output = dummy;
    true_icon = 'sw20on.ico';
    false_icon = 'sw20off.ico';
    
    procedure OnOutput( Output : boolean );
    var
      adr : string;
      error : string;
    begin
       adr := DEVICE + '.' + ActiveLinie:s + '.' + ID:s;
       if Output then
         core.DriverQueryProc( 'dali', 'set ' + adr + ' on', &error );
       else
         core.DriverQueryProc( 'dali', 'set ' + adr + ' off', &error );
       end;
       if error = '' then
         error := '<ok>';
       end;
       core.DebugOutput( 'set ' + adr + ' result: ' + error );
    end_procedure;
    
  end_switch;

  panel panel_08;
    owner = Addressing;
    position = 5, 110, 100, 60;
    colors
      color = green;
    end_colors;
  end_panel;

  string_display state_08;
    const
      ID = '08';
    end_const;

    timer = infinite;
    owner = panel_08;
    position = 5, 5, 90, 20;
    expression = ID;
    frame = 0;
    font = font_caption;
    justify = center;
    colors
      ink = lgray;
      paper = color_btnshadow;
    end_colors;
  end_string_display;

  string_control new_08;
    owner = panel_08;
    position = 35, 30, 60, 26;
    font = font_caption;
    colors
      top_shadow = lgray;
      bottom_shadow = lgray;
      ink = lyellow;
      paper = color_btnshadow;
    end_colors;
  end_string_control;

  switch switch_08;
    const
      ID = 8;
    end_const;
    var
      dummy : boolean;
    end_var;

    owner = panel_08;
    position = 5, 30, 26, 26;
    output = dummy;
    true_icon = 'sw20on.ico';
    false_icon = 'sw20off.ico';
    
    procedure OnOutput( Output : boolean );
    var
      adr : string;
      error : string;
    begin
       adr := DEVICE + '.' + ActiveLinie:s + '.' + ID:s;
       if Output then
         core.DriverQueryProc( 'dali', 'set ' + adr + ' on', &error );
       else
         core.DriverQueryProc( 'dali', 'set ' + adr + ' off', &error );
       end;
       if error = '' then
         error := '<ok>';
       end;
       core.DebugOutput( 'set ' + adr + ' result: ' + error );
    end_procedure;
    
  end_switch;

  panel panel_38;
    owner = Addressing;
    position = 635, 110, 100, 60;
    colors
      color = green;
    end_colors;
  end_panel;

  string_display state_14;
    const
      ID = '14';
    end_const;

    timer = infinite;
    owner = panel_38;
    position = 5, 5, 90, 20;
    expression = ID;
    frame = 0;
    font = font_caption;
    justify = center;
    colors
      ink = lgray;
      paper = color_btnshadow;
    end_colors;
  end_string_display;

  string_control new_14;
    owner = panel_38;
    position = 35, 30, 60, 26;
    font = font_caption;
    colors
      top_shadow = lgray;
      bottom_shadow = lgray;
      ink = lyellow;
      paper = color_btnshadow;
    end_colors;
  end_string_control;

  switch switch_14;
    const
      ID = 14;
    end_const;
    var
      dummy : boolean;
    end_var;

    owner = panel_38;
    position = 5, 30, 26, 26;
    output = dummy;
    true_icon = 'sw20on.ico';
    false_icon = 'sw20off.ico';
    
    procedure OnOutput( Output : boolean );
    var
      adr : string;
      error : string;
    begin
       adr := DEVICE + '.' + ActiveLinie:s + '.' + ID:s;
       if Output then
         core.DriverQueryProc( 'dali', 'set ' + adr + ' on', &error );
       else
         core.DriverQueryProc( 'dali', 'set ' + adr + ' off', &error );
       end;
       if error = '' then
         error := '<ok>';
       end;
       core.DebugOutput( 'set ' + adr + ' result: ' + error );
    end_procedure;
    
  end_switch;

  panel panel_37;
    owner = Addressing;
    position = 740, 110, 100, 60;
    colors
      color = green;
    end_colors;
  end_panel;

  string_display state_15;
    const
      ID = '15';
    end_const;

    timer = infinite;
    owner = panel_37;
    position = 5, 5, 90, 20;
    expression = ID;
    frame = 0;
    font = font_caption;
    justify = center;
    colors
      ink = lgray;
      paper = color_btnshadow;
    end_colors;
  end_string_display;

  string_control new_15;
    owner = panel_37;
    position = 35, 30, 60, 26;
    font = font_caption;
    colors
      top_shadow = lgray;
      bottom_shadow = lgray;
      ink = lyellow;
      paper = color_btnshadow;
    end_colors;
  end_string_control;

  switch switch_15;
    const
      ID = 15;
    end_const;
    var
      dummy : boolean;
    end_var;

    owner = panel_37;
    position = 5, 30, 26, 26;
    output = dummy;
    true_icon = 'sw20on.ico';
    false_icon = 'sw20off.ico';
    
    procedure OnOutput( Output : boolean );
    var
      adr : string;
      error : string;
    begin
       adr := DEVICE + '.' + ActiveLinie:s + '.' + ID:s;
       if Output then
         core.DriverQueryProc( 'dali', 'set ' + adr + ' on', &error );
       else
         core.DriverQueryProc( 'dali', 'set ' + adr + ' off', &error );
       end;
       if error = '' then
         error := '<ok>';
       end;
       core.DebugOutput( 'set ' + adr + ' result: ' + error );
    end_procedure;
    
  end_switch;

  panel panel_36;
    owner = Addressing;
    position = 320, 110, 100, 60;
    colors
      color = green;
    end_colors;
  end_panel;

  string_display state_11;
    const
      ID = '11';
    end_const;

    timer = infinite;
    owner = panel_36;
    position = 5, 5, 90, 20;
    expression = ID;
    frame = 0;
    font = font_caption;
    justify = center;
    colors
      ink = lgray;
      paper = color_btnshadow;
    end_colors;
  end_string_display;

  string_control new_11;
    owner = panel_36;
    position = 35, 30, 60, 26;
    font = font_caption;
    colors
      top_shadow = lgray;
      bottom_shadow = lgray;
      ink = lyellow;
      paper = color_btnshadow;
    end_colors;
  end_string_control;

  switch switch_11;
    const
      ID = 11;
    end_const;
    var
      dummy : boolean;
    end_var;

    owner = panel_36;
    position = 5, 30, 26, 26;
    output = dummy;
    true_icon = 'sw20on.ico';
    false_icon = 'sw20off.ico';
    
    procedure OnOutput( Output : boolean );
    var
      adr : string;
      error : string;
    begin
       adr := DEVICE + '.' + ActiveLinie:s + '.' + ID:s;
       if Output then
         core.DriverQueryProc( 'dali', 'set ' + adr + ' on', &error );
       else
         core.DriverQueryProc( 'dali', 'set ' + adr + ' off', &error );
       end;
       if error = '' then
         error := '<ok>';
       end;
       core.DebugOutput( 'set ' + adr + ' result: ' + error );
    end_procedure;
    
  end_switch;

  panel panel_35;
    owner = Addressing;
    position = 530, 110, 100, 60;
    colors
      color = green;
    end_colors;
  end_panel;

  string_display state_13;
    const
      ID = '13';
    end_const;

    timer = infinite;
    owner = panel_35;
    position = 5, 5, 90, 20;
    expression = ID;
    frame = 0;
    font = font_caption;
    justify = center;
    colors
      ink = lgray;
      paper = color_btnshadow;
    end_colors;
  end_string_display;

  string_control new_13;
    owner = panel_35;
    position = 35, 30, 60, 26;
    font = font_caption;
    colors
      top_shadow = lgray;
      bottom_shadow = lgray;
      ink = lyellow;
      paper = color_btnshadow;
    end_colors;
  end_string_control;

  switch switch_13;
    const
      ID = 13;
    end_const;
    var
      dummy : boolean;
    end_var;

    owner = panel_35;
    position = 5, 30, 26, 26;
    output = dummy;
    true_icon = 'sw20on.ico';
    false_icon = 'sw20off.ico';
    
    procedure OnOutput( Output : boolean );
    var
      adr : string;
      error : string;
    begin
       adr := DEVICE + '.' + ActiveLinie:s + '.' + ID:s;
       if Output then
         core.DriverQueryProc( 'dali', 'set ' + adr + ' on', &error );
       else
         core.DriverQueryProc( 'dali', 'set ' + adr + ' off', &error );
       end;
       if error = '' then
         error := '<ok>';
       end;
       core.DebugOutput( 'set ' + adr + ' result: ' + error );
    end_procedure;
    
  end_switch;

  panel panel_34;
    owner = Addressing;
    position = 425, 110, 100, 60;
    colors
      color = green;
    end_colors;
  end_panel;

  string_display state_12;
    const
      ID = '12';
    end_const;

    timer = infinite;
    owner = panel_34;
    position = 5, 5, 90, 20;
    expression = ID;
    frame = 0;
    font = font_caption;
    justify = center;
    colors
      ink = lgray;
      paper = color_btnshadow;
    end_colors;
  end_string_display;

  string_control new_12;
    owner = panel_34;
    position = 35, 30, 60, 26;
    font = font_caption;
    colors
      top_shadow = lgray;
      bottom_shadow = lgray;
      ink = lyellow;
      paper = color_btnshadow;
    end_colors;
  end_string_control;

  switch switch_12;
    const
      ID = 12;
    end_const;
    var
      dummy : boolean;
    end_var;

    owner = panel_34;
    position = 5, 30, 26, 26;
    output = dummy;
    true_icon = 'sw20on.ico';
    false_icon = 'sw20off.ico';
    
    procedure OnOutput( Output : boolean );
    var
      adr : string;
      error : string;
    begin
       adr := DEVICE + '.' + ActiveLinie:s + '.' + ID:s;
       if Output then
         core.DriverQueryProc( 'dali', 'set ' + adr + ' on', &error );
       else
         core.DriverQueryProc( 'dali', 'set ' + adr + ' off', &error );
       end;
       if error = '' then
         error := '<ok>';
       end;
       core.DebugOutput( 'set ' + adr + ' result: ' + error );
    end_procedure;
    
  end_switch;

  panel panel_06;
    owner = Addressing;
    position = 635, 45, 100, 60;
    colors
      color = green;
    end_colors;
  end_panel;

  string_display state_06;
    const
      ID = '06';
    end_const;

    timer = infinite;
    owner = panel_06;
    position = 5, 5, 90, 20;
    expression = ID;
    frame = 0;
    font = font_caption;
    justify = center;
    colors
      ink = lgray;
      paper = color_btnshadow;
    end_colors;
  end_string_display;

  string_control new_06;
    owner = panel_06;
    position = 35, 30, 60, 26;
    font = font_caption;
    colors
      top_shadow = lgray;
      bottom_shadow = lgray;
      ink = lyellow;
      paper = color_btnshadow;
    end_colors;
  end_string_control;

  switch switch_06;
    const
      ID = 6;
    end_const;
    var
      dummy : boolean;
    end_var;

    owner = panel_06;
    position = 5, 30, 26, 26;
    output = dummy;
    true_icon = 'sw20on.ico';
    false_icon = 'sw20off.ico';
    
    procedure OnOutput( Output : boolean );
    var
      adr : string;
      error : string;
    begin
       adr := DEVICE + '.' + ActiveLinie:s + '.' + ID:s;
       if Output then
         core.DriverQueryProc( 'dali', 'set ' + adr + ' on', &error );
       else
         core.DriverQueryProc( 'dali', 'set ' + adr + ' off', &error );
       end;
       if error = '' then
         error := '<ok>';
       end;
       core.DebugOutput( 'set ' + adr + ' result: ' + error );
    end_procedure;
    
  end_switch;

  panel panel_07;
    owner = Addressing;
    position = 740, 45, 100, 60;
    colors
      color = green;
    end_colors;
  end_panel;

  string_display state_07;
    const
      ID = '07';
    end_const;

    timer = infinite;
    owner = panel_07;
    position = 5, 5, 90, 20;
    expression = ID;
    frame = 0;
    font = font_caption;
    justify = center;
    colors
      ink = lgray;
      paper = color_btnshadow;
    end_colors;
  end_string_display;

  string_control new_07;
    owner = panel_07;
    position = 35, 30, 60, 26;
    font = font_caption;
    colors
      top_shadow = lgray;
      bottom_shadow = lgray;
      ink = lyellow;
      paper = color_btnshadow;
    end_colors;
  end_string_control;

  switch switch_07;
    const
      ID = 7;
    end_const;
    var
      dummy : boolean;
    end_var;

    owner = panel_07;
    position = 5, 30, 26, 26;
    output = dummy;
    true_icon = 'sw20on.ico';
    false_icon = 'sw20off.ico';
    
    procedure OnOutput( Output : boolean );
    var
      adr : string;
      error : string;
    begin
       adr := DEVICE + '.' + ActiveLinie:s + '.' + ID:s;
       if Output then
         core.DriverQueryProc( 'dali', 'set ' + adr + ' on', &error );
       else
         core.DriverQueryProc( 'dali', 'set ' + adr + ' off', &error );
       end;
       if error = '' then
         error := '<ok>';
       end;
       core.DebugOutput( 'set ' + adr + ' result: ' + error );
    end_procedure;
    
  end_switch;

  panel panel_02;
    owner = Addressing;
    position = 215, 45, 100, 60;
    colors
      color = green;
    end_colors;
  end_panel;

  string_display state_02;
    const
      ID = '02';
    end_const;

    timer = infinite;
    owner = panel_02;
    position = 5, 5, 90, 20;
    expression = ID;
    frame = 0;
    font = font_caption;
    justify = center;
    colors
      ink = lgray;
      paper = color_btnshadow;
    end_colors;
  end_string_display;

  string_control new_02;
    owner = panel_02;
    position = 35, 30, 60, 26;
    font = font_caption;
    colors
      top_shadow = lgray;
      bottom_shadow = lgray;
      ink = lyellow;
      paper = color_btnshadow;
    end_colors;
  end_string_control;

  switch switch_02;
    const
      ID = 2;
    end_const;
    var
      dummy : boolean;
    end_var;

    owner = panel_02;
    position = 5, 30, 26, 26;
    output = dummy;
    true_icon = 'sw20on.ico';
    false_icon = 'sw20off.ico';
    
    procedure OnOutput( Output : boolean );
    var
      adr : string;
      error : string;
    begin
       adr := DEVICE + '.' + ActiveLinie:s + '.' + ID:s;
       if Output then
         core.DriverQueryProc( 'dali', 'set ' + adr + ' on', &error );
       else
         core.DriverQueryProc( 'dali', 'set ' + adr + ' off', &error );
       end;
       if error = '' then
         error := '<ok>';
       end;
       core.DebugOutput( 'set ' + adr + ' result: ' + error );
    end_procedure;
    
  end_switch;

  panel panel_03;
    owner = Addressing;
    position = 320, 45, 100, 60;
    colors
      color = green;
    end_colors;
  end_panel;

  string_display state_03;
    const
      ID = '03';
    end_const;

    timer = infinite;
    owner = panel_03;
    position = 5, 5, 90, 20;
    expression = ID;
    frame = 0;
    font = font_caption;
    justify = center;
    colors
      ink = lgray;
      paper = color_btnshadow;
    end_colors;
  end_string_display;

  string_control new_03;
    owner = panel_03;
    position = 35, 30, 60, 26;
    font = font_caption;
    colors
      top_shadow = lgray;
      bottom_shadow = lgray;
      ink = lyellow;
      paper = color_btnshadow;
    end_colors;
  end_string_control;

  switch switch_03;
    const
      ID = 3;
    end_const;
    var
      dummy : boolean;
    end_var;

    owner = panel_03;
    position = 5, 30, 26, 26;
    output = dummy;
    true_icon = 'sw20on.ico';
    false_icon = 'sw20off.ico';
    
    procedure OnOutput( Output : boolean );
    var
      adr : string;
      error : string;
    begin
       adr := DEVICE + '.' + ActiveLinie:s + '.' + ID:s;
       if Output then
         core.DriverQueryProc( 'dali', 'set ' + adr + ' on', &error );
       else
         core.DriverQueryProc( 'dali', 'set ' + adr + ' off', &error );
       end;
       if error = '' then
         error := '<ok>';
       end;
       core.DebugOutput( 'set ' + adr + ' result: ' + error );
    end_procedure;
    
  end_switch;

  panel panel_05;
    owner = Addressing;
    position = 530, 45, 100, 60;
    colors
      color = green;
    end_colors;
  end_panel;

  string_display state_05;
    const
      ID = '05';
    end_const;

    timer = infinite;
    owner = panel_05;
    position = 5, 5, 90, 20;
    expression = ID;
    frame = 0;
    font = font_caption;
    justify = center;
    colors
      ink = lgray;
      paper = color_btnshadow;
    end_colors;
  end_string_display;

  string_control new_05;
    owner = panel_05;
    position = 35, 30, 60, 26;
    font = font_caption;
    colors
      top_shadow = lgray;
      bottom_shadow = lgray;
      ink = lyellow;
      paper = color_btnshadow;
    end_colors;
  end_string_control;

  switch switch_05;
    const
      ID = 5;
    end_const;
    var
      dummy : boolean;
    end_var;

    owner = panel_05;
    position = 5, 30, 26, 26;
    output = dummy;
    true_icon = 'sw20on.ico';
    false_icon = 'sw20off.ico';
    
    procedure OnOutput( Output : boolean );
    var
      adr : string;
      error : string;
    begin
       adr := DEVICE + '.' + ActiveLinie:s + '.' + ID:s;
       if Output then
         core.DriverQueryProc( 'dali', 'set ' + adr + ' on', &error );
       else
         core.DriverQueryProc( 'dali', 'set ' + adr + ' off', &error );
       end;
       if error = '' then
         error := '<ok>';
       end;
       core.DebugOutput( 'set ' + adr + ' result: ' + error );
    end_procedure;
    
  end_switch;

  panel panel_04;
    owner = Addressing;
    position = 425, 45, 100, 60;
    colors
      color = green;
    end_colors;
  end_panel;

  string_display state_04;
    const
      ID = '04';
    end_const;

    timer = infinite;
    owner = panel_04;
    position = 5, 5, 90, 20;
    expression = ID;
    frame = 0;
    font = font_caption;
    justify = center;
    colors
      ink = lgray;
      paper = color_btnshadow;
    end_colors;
  end_string_display;

  string_control new_04;
    owner = panel_04;
    position = 35, 30, 60, 26;
    font = font_caption;
    colors
      top_shadow = lgray;
      bottom_shadow = lgray;
      ink = lyellow;
      paper = color_btnshadow;
    end_colors;
  end_string_control;

  switch switch_04;
    const
      ID = 4;
    end_const;
    var
      dummy : boolean;
    end_var;

    owner = panel_04;
    position = 5, 30, 26, 26;
    output = dummy;
    true_icon = 'sw20on.ico';
    false_icon = 'sw20off.ico';
    
    procedure OnOutput( Output : boolean );
    var
      adr : string;
      error : string;
    begin
       adr := DEVICE + '.' + ActiveLinie:s + '.' + ID:s;
       if Output then
         core.DriverQueryProc( 'dali', 'set ' + adr + ' on', &error );
       else
         core.DriverQueryProc( 'dali', 'set ' + adr + ' off', &error );
       end;
       if error = '' then
         error := '<ok>';
       end;
       core.DebugOutput( 'set ' + adr + ' result: ' + error );
    end_procedure;
    
  end_switch;

  panel panel_01;
    owner = Addressing;
    position = 110, 45, 100, 60;
    colors
      color = green;
    end_colors;
  end_panel;

  string_display state_01;
    const
      ID = '01';
    end_const;

    timer = infinite;
    owner = panel_01;
    position = 5, 5, 90, 20;
    expression = ID;
    frame = 0;
    font = font_caption;
    justify = center;
    colors
      ink = lgray;
      paper = color_btnshadow;
    end_colors;
  end_string_display;

  string_control new_01;
    owner = panel_01;
    position = 35, 30, 60, 26;
    font = font_caption;
    colors
      top_shadow = lgray;
      bottom_shadow = lgray;
      ink = lyellow;
      paper = color_btnshadow;
    end_colors;
  end_string_control;

  switch switch_01;
    const
      ID = 1;
    end_const;
    var
      dummy : boolean;
    end_var;

    owner = panel_01;
    position = 5, 30, 26, 26;
    output = dummy;
    true_icon = 'sw20on.ico';
    false_icon = 'sw20off.ico';
    
    procedure OnOutput( Output : boolean );
    var
      adr : string;
      error : string;
    begin
       adr := DEVICE + '.' + ActiveLinie:s + '.' + ID:s;
       if Output then
         core.DriverQueryProc( 'dali', 'set ' + adr + ' on', &error );
       else
         core.DriverQueryProc( 'dali', 'set ' + adr + ' off', &error );
       end;
       if error = '' then
         error := '<ok>';
       end;
       core.DebugOutput( 'set ' + adr + ' result: ' + error );
    end_procedure;
    
  end_switch;

  panel panel_00;
    owner = Addressing;
    position = 5, 45, 100, 60;
    colors
      color = green;
    end_colors;
  end_panel;

  string_display state_00;
    const
      ID = '00';
    end_const;

    timer = infinite;
    owner = panel_00;
    position = 5, 5, 90, 20;
    expression = ID;
    frame = 0;
    font = font_caption;
    justify = center;
    colors
      ink = lgray;
      paper = color_btnshadow;
    end_colors;
  end_string_display;

  string_control new_00;
    owner = panel_00;
    position = 35, 30, 60, 26;
    font = font_caption;
    colors
      top_shadow = lgray;
      bottom_shadow = lgray;
      ink = lyellow;
      paper = color_btnshadow;
    end_colors;
  end_string_control;

  switch switch_00;
    const
      ID = 0;
    end_const;
    var
      dummy : boolean;
    end_var;

    owner = panel_00;
    position = 5, 30, 26, 26;
    output = dummy;
    true_icon = 'sw20on.ico';
    false_icon = 'sw20off.ico';
    
    procedure OnOutput( Output : boolean );
    var
      adr : string;
      error : string;
    begin
       adr := DEVICE + '.' + ActiveLinie:s + '.' + ID:s;
       if Output then
         core.DriverQueryProc( 'dali', 'set ' + adr + ' on', &error );
       else
         core.DriverQueryProc( 'dali', 'set ' + adr + ' off', &error );
       end;
       if error = '' then
         error := '<ok>';
       end;
       core.DebugOutput( 'set ' + adr + ' result: ' + error );
    end_procedure;
    
  end_switch;

  panel panel_top;
    owner = Addressing;
    position = 5, 5, 835, 35;
    gravity = right;
    colors
      color = green;
    end_colors;
  end_panel;

  switch switch_allon;
    owner = panel_top;
    position = 605, 5, 85, 27;
    mode = text_button;
    init_value = true;
    font = font_caption;
    true_text = 'Vše ON';
    logic = set_true;
    colors
      true_paper = green;
      true_ink = lyellow;
      true_tshadow = 99, 255, 99;
      true_bshadow = 1, 75, 1;
      false_paper = lgray;
    end_colors;
    
    procedure OnOutput( b : boolean );
    var
      error : string;
    begin
       core.DriverQueryProc( 'dali', 'set ' + DEVICE + '.' + ActiveLinie:s + '.all on', &error );
       if error = '' then
         error := '<ok>';
       end;
       core.DebugOutput( 'set ' + DEVICE + '.' + ActiveLinie:s + '.all result: ' + error );
    end_procedure;
    
  end_switch;

  switch switch_alloff;
    owner = panel_top;
    position = 695, 5, 85, 27;
    mode = text_button;
    init_value = true;
    font = font_caption;
    true_text = 'Vše OFF';
    logic = set_true;
    colors
      true_paper = green;
      true_ink = lyellow;
      true_tshadow = 99, 255, 99;
      true_bshadow = 1, 75, 1;
      false_paper = lgray;
    end_colors;
    
    procedure OnOutput( b : boolean );
    var
      error : string;
    begin
       core.DriverQueryProc( 'dali', 'set ' + DEVICE + '.' + ActiveLinie:s + '.all off', &error );
       if error = '' then
         error := '<ok>';
       end;
       core.DebugOutput( 'set ' + DEVICE + '.' + ActiveLinie:s + '.all result: ' + error );
    end_procedure;
    
  end_switch;

  meter meter_11;
    timer = 0.1;
    owner = panel_top;
    position = 785, 5, 45, 25;
    expression = DALI.OutputQueueLength;
    mode = text_display;
    range_to = 999999999999;
    low_limit = 0;
    high_limit = 100;
    dec_places = 0;
    frame = 2;
    font = font_caption;
    text_shift = -1;
    colors
      top_shadow = lgray;
      bottom_shadow = lgray;
      ink = lyellow;
      value = green;
      low_limit = color_btnshadow;
      high_limit = red;
    end_colors;
  end_meter;

  label state_top;
    owner = panel_top;
    position = 10, 9;
    win_disable = zoom, maximize;
    text_list
      font = font_caption;
      text = 'Aktivní linie';
    end_text_list;
    colors
      paper = green;
      ink = lyellow;
    end_colors;
  end_label;

  multi_switch multi_switch_8;
    owner = panel_top;
    position = 95, 5, 40, 25;
    mode = combo_box;
    font = font_caption;
    colors
      paper = dgray;
      ink = lyellow;
      top_shadow = lgray;
      bottom_shadow = lgray;
    end_colors;
    item
      text = '1';
    end_item;
    item
      text = '2';
    end_item;
    item
      text = '3';
    end_item;
    item
      text = '4';
    end_item;
    
    procedure OnIndex( Index : longint );
    begin
      ActiveLinie := Index - 1;
    end_procedure;
    
  end_multi_switch;

  program ExceptionHandler;
    driver_exception = dali;
    
    procedure OnActivate();
    var
       Event : string;
       error : boolean;
       failure : boolean;
       i : integer;
       j : integer;
       linie : string;
       on : boolean;
       s : string;
    begin
       loop
          core.DriverQueryProc( 'dali', 'event get', &Event );
          if Event = '' then
             exit;
          end;
          (*
          core.DebugOutput( 'Event: ', Event );
          *)

          i = pos( Event, ' ' );
          s = slice( Event, 0, i );
          if s = 'status' then
             Event = trim( delete( Event, 0, i ));
             j = pos( Event, ' ' );
             s = slice( Event, 0, j );
             i = pos( Event, '.' );
             Event = trim( delete( Event, 0, j ));

             s = slice( s, i+1, -1 );
             i = pos( s, '.' );
             linie = slice( s, 0, i-1 );

             if linie:value_real = ActiveLinie then
               s = delete( s, 0, i+1 );

               on := pos( Event, 'on ' ) <> -1;
               failure := pos( Event, 'failure' ) <> -1;
               error := ( pos( Event, 'error' ) <> -1 ) or ( pos( Event, 'timeout' ) <> -1 );

               SetLabel( s, on, failure, error );
             end;

          end;
       end;
    end_procedure;
    
    procedure SetLabel( addr : string; on, failure, error : boolean );
    var
      ink : string;
      paper : string;
    begin
       if on then
         ink := 'lyellow';
       else
         ink := 'lgray';
       end;
       if error then
         paper := 'dgray';
       elsif failure then
         paper := 'red';
       else
         paper := 'blue';
       end;

       switch addr of
       case '0';
         state_00.SetColor( 'ink', ink );
         state_00.SetColor( 'paper', paper );
         switch_00.SetValue( on, false );
       case '1';
         state_01.SetColor( 'ink', ink );
         state_01.SetColor( 'paper', paper );
         switch_01.SetValue( on, false );
       case '2';
         state_02.SetColor( 'ink', ink );
         state_02.SetColor( 'paper', paper );
         switch_02.SetValue( on, false );
       case '3';
         state_03.SetColor( 'ink', ink );
         state_03.SetColor( 'paper', paper );
         switch_03.SetValue( on, false );
       case '4';
         state_04.SetColor( 'ink', ink );
         state_04.SetColor( 'paper', paper );
         switch_04.SetValue( on, false );
       case '5';
         state_05.SetColor( 'ink', ink );
         state_05.SetColor( 'paper', paper );
         switch_05.SetValue( on, false );
       case '6';
         state_06.SetColor( 'ink', ink );
         state_06.SetColor( 'paper', paper );
         switch_06.SetValue( on, false );
       case '7';
         state_07.SetColor( 'ink', ink );
         state_07.SetColor( 'paper', paper );
         switch_07.SetValue( on, false );
       case '8';
         state_08.SetColor( 'ink', ink );
         state_08.SetColor( 'paper', paper );
         switch_08.SetValue( on, false );
       case '9';
         state_09.SetColor( 'ink', ink );
         state_09.SetColor( 'paper', paper );
         switch_09.SetValue( on, false );
       case '10';
         state_10.SetColor( 'ink', ink );
         state_10.SetColor( 'paper', paper );
         switch_10.SetValue( on, false );
       case '11';
         state_11.SetColor( 'ink', ink );
         state_11.SetColor( 'paper', paper );
         switch_11.SetValue( on, false );
       case '12';
         state_12.SetColor( 'ink', ink );
         state_12.SetColor( 'paper', paper );
         switch_12.SetValue( on, false );
       case '13';
         state_13.SetColor( 'ink', ink );
         state_13.SetColor( 'paper', paper );
         switch_13.SetValue( on, false );
       case '14';
         state_14.SetColor( 'ink', ink );
         state_14.SetColor( 'paper', paper );
         switch_14.SetValue( on, false );
       case '15';
         state_15.SetColor( 'ink', ink );
         state_15.SetColor( 'paper', paper );
         switch_15.SetValue( on, false );
       case '16';
         state_16.SetColor( 'ink', ink );
         state_16.SetColor( 'paper', paper );
         switch_16.SetValue( on, false );
       case '17';
         state_17.SetColor( 'ink', ink );
         state_17.SetColor( 'paper', paper );
         switch_17.SetValue( on, false );
       case '18';
         state_18.SetColor( 'ink', ink );
         state_18.SetColor( 'paper', paper );
         switch_18.SetValue( on, false );
       case '19';
         state_19.SetColor( 'ink', ink );
         state_19.SetColor( 'paper', paper );
         switch_19.SetValue( on, false );
       case '20';
         state_20.SetColor( 'ink', ink );
         state_20.SetColor( 'paper', paper );
         switch_20.SetValue( on, false );
       case '21';
         state_21.SetColor( 'ink', ink );
         state_21.SetColor( 'paper', paper );
         switch_21.SetValue( on, false );
       case '22';
         state_22.SetColor( 'ink', ink );
         state_22.SetColor( 'paper', paper );
         switch_22.SetValue( on, false );
       case '23';
         state_23.SetColor( 'ink', ink );
         state_23.SetColor( 'paper', paper );
         switch_23.SetValue( on, false );
       case '24';
         state_24.SetColor( 'ink', ink );
         state_24.SetColor( 'paper', paper );
         switch_24.SetValue( on, false );
       case '25';
         state_25.SetColor( 'ink', ink );
         state_25.SetColor( 'paper', paper );
         switch_25.SetValue( on, false );
       case '26';
         state_26.SetColor( 'ink', ink );
         state_26.SetColor( 'paper', paper );
         switch_26.SetValue( on, false );
       case '27';
         state_27.SetColor( 'ink', ink );
         state_27.SetColor( 'paper', paper );
         switch_27.SetValue( on, false );
       case '28';
         state_28.SetColor( 'ink', ink );
         state_28.SetColor( 'paper', paper );
         switch_28.SetValue( on, false );
       case '29';
         state_29.SetColor( 'ink', ink );
         state_29.SetColor( 'paper', paper );
         switch_29.SetValue( on, false );
       case '30';
         state_30.SetColor( 'ink', ink );
         state_30.SetColor( 'paper', paper );
         switch_30.SetValue( on, false );
       case '31';
         state_31.SetColor( 'ink', ink );
         state_31.SetColor( 'paper', paper );
         switch_31.SetValue( on, false );
       case '32';
         state_32.SetColor( 'ink', ink );
         state_32.SetColor( 'paper', paper );
         switch_32.SetValue( on, false );
       case '33';
         state_33.SetColor( 'ink', ink );
         state_33.SetColor( 'paper', paper );
         switch_33.SetValue( on, false );
       case '34';
         state_34.SetColor( 'ink', ink );
         state_34.SetColor( 'paper', paper );
         switch_34.SetValue( on, false );
       case '35';
         state_35.SetColor( 'ink', ink );
         state_35.SetColor( 'paper', paper );
         switch_35.SetValue( on, false );
       case '36';
         state_36.SetColor( 'ink', ink );
         state_36.SetColor( 'paper', paper );
         switch_36.SetValue( on, false );
       case '37';
         state_37.SetColor( 'ink', ink );
         state_37.SetColor( 'paper', paper );
         switch_37.SetValue( on, false );
       case '38';
         state_38.SetColor( 'ink', ink );
         state_38.SetColor( 'paper', paper );
         switch_38.SetValue( on, false );
       case '39';
         state_39.SetColor( 'ink', ink );
         state_39.SetColor( 'paper', paper );
         switch_39.SetValue( on, false );
       case '40';
         state_40.SetColor( 'ink', ink );
         state_40.SetColor( 'paper', paper );
         switch_40.SetValue( on, false );
       case '41';
         state_41.SetColor( 'ink', ink );
         state_41.SetColor( 'paper', paper );
         switch_41.SetValue( on, false );
       case '42';
         state_42.SetColor( 'ink', ink );
         state_42.SetColor( 'paper', paper );
         switch_42.SetValue( on, false );
       case '43';
         state_43.SetColor( 'ink', ink );
         state_43.SetColor( 'paper', paper );
         switch_43.SetValue( on, false );
       case '44';
         state_44.SetColor( 'ink', ink );
         state_44.SetColor( 'paper', paper );
         switch_44.SetValue( on, false );
       case '45';
         state_45.SetColor( 'ink', ink );
         state_45.SetColor( 'paper', paper );
         switch_45.SetValue( on, false );
       case '46';
         state_46.SetColor( 'ink', ink );
         state_46.SetColor( 'paper', paper );
         switch_46.SetValue( on, false );
       case '47';
         state_47.SetColor( 'ink', ink );
         state_47.SetColor( 'paper', paper );
         switch_47.SetValue( on, false );
       case '48';
         state_48.SetColor( 'ink', ink );
         state_48.SetColor( 'paper', paper );
         switch_48.SetValue( on, false );
       case '49';
         state_49.SetColor( 'ink', ink );
         state_49.SetColor( 'paper', paper );
         switch_49.SetValue( on, false );
       case '50';
         state_50.SetColor( 'ink', ink );
         state_50.SetColor( 'paper', paper );
         switch_50.SetValue( on, false );
       case '51';
         state_51.SetColor( 'ink', ink );
         state_51.SetColor( 'paper', paper );
         switch_51.SetValue( on, false );
       case '52';
         state_52.SetColor( 'ink', ink );
         state_52.SetColor( 'paper', paper );
         switch_52.SetValue( on, false );
       case '53';
         state_53.SetColor( 'ink', ink );
         state_53.SetColor( 'paper', paper );
         switch_53.SetValue( on, false );
       case '54';
         state_54.SetColor( 'ink', ink );
         state_54.SetColor( 'paper', paper );
         switch_54.SetValue( on, false );
       case '55';
         state_55.SetColor( 'ink', ink );
         state_55.SetColor( 'paper', paper );
         switch_55.SetValue( on, false );
       case '56';
         state_56.SetColor( 'ink', ink );
         state_56.SetColor( 'paper', paper );
         switch_56.SetValue( on, false );
       case '57';
         state_57.SetColor( 'ink', ink );
         state_57.SetColor( 'paper', paper );
         switch_57.SetValue( on, false );
       case '58';
         state_58.SetColor( 'ink', ink );
         state_58.SetColor( 'paper', paper );
         switch_58.SetValue( on, false );
       case '59';
         state_59.SetColor( 'ink', ink );
         state_59.SetColor( 'paper', paper );
         switch_59.SetValue( on, false );
       case '60';
         state_60.SetColor( 'ink', ink );
         state_60.SetColor( 'paper', paper );
         switch_60.SetValue( on, false );
       case '61';
         state_61.SetColor( 'ink', ink );
         state_61.SetColor( 'paper', paper );
         switch_61.SetValue( on, false );
       case '62';
         state_62.SetColor( 'ink', ink );
         state_62.SetColor( 'paper', paper );
         switch_62.SetValue( on, false );
       case '63';
         state_63.SetColor( 'ink', ink );
         state_63.SetColor( 'paper', paper );
         switch_63.SetValue( on, false );
       end;
    end_procedure;
    
    procedure ResetStatus();
    var
      i : integer;
    begin
      for i := 0 to 63 do
        SetLabel( i:s, false, false, true );
      end;
    end_procedure;
    
  end_program;

end_instrument;

