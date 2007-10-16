directories
  '*.par' = 'D:\Work\SmartControl\Code\CWDriver\Validator\~Debug';
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
  validator : 'validator.dll', '', 'validator.par';
end_driver;

data
end_data;

instrument

   program Run;
       timer = 5;

       procedure OnActivate();
       var
          out : string;
       begin
         system.DriverQueryProc( 'validator', 'query Inris.Tvrz', &out );
         core.DebugOutput( 'returned:', out );
       end_procedure;

   end_program;

end_instrument;

