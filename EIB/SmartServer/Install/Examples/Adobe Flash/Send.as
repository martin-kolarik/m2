var Connection : SmartServerConnector = new SmartServerConnector();
Connection.Connect( "10.0.0.100" );

Connection.Send( "3/1/0", "false" );
