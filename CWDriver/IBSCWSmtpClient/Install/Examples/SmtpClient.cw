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
  smtp {driver = 'IBSCWSmtpClient.dll'; parameter_file = 'SmtpClient.par'};
end_driver;

data

  channel
    Server : string {driver = smtp; driver_index = 100; direction = bidirectional};
    Sender : string {driver = smtp; driver_index = 103; direction = bidirectional};
    ReplyTo : string {driver = smtp; driver_index = 104; direction = bidirectional};
    Recipient : string {driver = smtp; driver_index = 105; direction = bidirectional};
    Subject : string {driver = smtp; driver_index = 106; direction = bidirectional};
    Body : string {driver = smtp; driver_index = 107; direction = bidirectional};
    ErrorText : string {driver = smtp; driver_index = 4; direction = input};
    SendTrigger : boolean {driver = smtp; driver_index = 2; direction = output};
    MessageState : longint {driver = smtp; driver_index = 3; direction = input};
  end_channel;

end_data;

instrument

  panel panel_2;
    gui
      owner = background;
      position = 215, 115, 415, 410;
      window
        type = normal;
        title = 'Send mail';
        disable = zoom, maximize;
      end_window;
    end_gui;
  end_panel;

  label label_1;
    gui
      owner = panel_2;
      position = 24, 206;
      window
        disable = zoom, maximize;
      end_window;
    end_gui;
    text_list
      font = font_caption;
      text = 'Result:';
    end_text_list;
  end_label;

  string_control TResult;
    gui
      owner = panel_2;
      position = 75, 201, 315, 25;
    end_gui;
    font = font_caption;

    procedure OnStartup();
    begin
      Disable();
    end_procedure;

  end_string_control;

  label label_1;
    gui
      owner = panel_2;
      position = 30, 376;
      window
        disable = zoom, maximize;
      end_window;
    end_gui;
    text_list
      text = 'Server:';
    end_text_list;
  end_label;

  string_control TServer;
    gui
      owner = panel_2;
      position = 74, 370, 315, 25;
    end_gui;
    output = Server;
    init_value = 'smtp.provider.com';
  end_string_control;

  switch switch_2;
    gui
      owner = panel_2;
      position = 280, 145, 110, 46;
      window
        disable = zoom, maximize;
      end_window;
    end_gui;
    send_same_data = on;
    mode = text_button;
    init_value = true;
    font = font_caption;
    true_text = 'Send';
    logic = set_true;

    procedure OnOutput( Output : boolean );
    begin
      TResult.SetValue( '...sending...' );
      SendTrigger = true;
    end_procedure;

  end_switch;

  label label_1;
    gui
      owner = panel_2;
      position = 31, 14;
      window
        disable = zoom, maximize;
      end_window;
    end_gui;
    text_list
      font = font_caption;
      text = 'From:';
    end_text_list;
  end_label;

  label label_1;
    gui
      owner = panel_2;
      position = 47, 44;
      window
        disable = zoom, maximize;
      end_window;
    end_gui;
    text_list
      font = font_caption;
      text = 'To:';
    end_text_list;
  end_label;

  label label_1;
    gui
      owner = panel_2;
      position = 18, 84;
      window
        disable = zoom, maximize;
      end_window;
    end_gui;
    text_list
      font = font_caption;
      text = 'Subject:';
    end_text_list;
  end_label;

  label label_1;
    gui
      owner = panel_2;
      position = 10, 114;
      window
        disable = zoom, maximize;
      end_window;
    end_gui;
    text_list
      font = font_caption;
      text = 'Message:';
    end_text_list;
  end_label;

  string_control TSender;
    gui
      owner = panel_2;
      position = 75, 10, 315, 25;
    end_gui;
    output = Sender;
    init_value = 'my.email@address.com';
    font = font_caption;
  end_string_control;

  string_control TRecipient;
    gui
      owner = panel_2;
      position = 75, 40, 315, 25;
    end_gui;
    output = Recipient;
    init_value = 'your.email@address.com';
    font = font_caption;
  end_string_control;

  string_control TSubject;
    gui
      owner = panel_2;
      position = 75, 80, 315, 25;
    end_gui;
    output = Subject;
    init_value = 'A message subject';
    font = font_caption;
  end_string_control;

  string_control TBody;
    gui
      owner = panel_2;
      position = 75, 110, 315, 25;
    end_gui;
    output = Body;
    init_value = '...anything going into the text';
    font = font_caption;
  end_string_control;

  program excpt;
    activity
      driver = smtp;
    end_activity;

    procedure OnActivate();
    begin
      if MessageState = -1 then
        TResult.SetValue( '...sending...' );
      elsif MessageState = 0 then
        core.DebugOutput( 'Send failed: ', ErrorText );
        TResult.SetValue( ErrorText );
      else
        core.DebugOutput( 'Send succeeded' );
        TResult.SetValue( 'OK' );
      end;
    end_procedure;

  end_program;

end_instrument;

