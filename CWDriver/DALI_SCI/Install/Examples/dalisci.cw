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
  dali : 'dali_sci.dll', '', 'test.par';
end_driver;

data
end_data;

instrument

end_instrument;

