widget("PBase").updating = false;
widget("PHeating").visible = false;
widget("PWindow").visible = false;
widget("PComfort").visible = false;
widget("PStandby").visible = false;
widget("PNight").visible = false;

current = new CO( "6/3/0", "value" );
base = new CO( "6/3/1", "value" );
comfort = new CO( "6/3/2", "switch" );
standby = new CO( "6/3/3", "switch" );
night = new CO( "6/3/4", "switch" );
window = new CO( "6/3/5", "switch" );
heating = new CO( "6/3/6", "switch" );
setpoint = new CO( "6/3/7", "value" );

System.ConnectionCheck = function( Connected ) {
  status = widget( "CommunicationStatus" );
  if( Connected ) {
    status.setImage( System.Image( "ConnectionStateOK" ));
  } else {
    status.setImage( System.Image( "ConnectionStateError" ));
  }
}

System.SetReadObjects( new Array(
  current, base, setpoint,
  heating,
  window, comfort, standby, night
);

System.PageUpdate = function( CO ) {
  switch( CO.address ) {
    case current.address:
      widget("PCurrent").label = System.NormalizeNumber( current.value );
      break;

    case base.address:
      if( !widget("PBase").updating ) {
        widget("PBase").label = System.NormalizeNumber( base.value );
      }
      break;

    case setpoint.address:
      widget("PSetpoint").label = System.NormalizeNumber( setpoint.value );
      break;

    case heating.address:
      widget("PHeating").visible = heating.value == "true";
      break;

    case window.address:
      widget("PWindow").visible = window.value == "true";
      break;

    case comfort.address:
    case standby.address:
    case night.address:
      widget("PComfort").visible = comfort.value == "true";
      widget("PStandby").visible = standby.value == "true";
      widget("PNight").visible = night.value == "true";
      break;
  }
}

if( System.DEBUG ) {
  System.print( "Temperatures.Enter" );
} else {
  CF.widget( "_PS_DEBUG_", "Main" ).visible = false;
}
