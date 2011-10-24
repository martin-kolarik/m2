livingRoomState = new CO( "3/0/12", "switch", widget( "BLight1" ));
eatingRoomState = new CO( "3/0/9", "switch", widget( "BLight2" ));
kitchenState = new CO( "3/0/2", "switch", widget( "BLight3" ));

livingRoom = new CO( "3/1/33", "switch" );
eatingRoom = new CO( "3/1/9", "switch" );
kitchen = new CO( "3/1/2", "switch" );

System.ConnectionCheck = function( Connected ) {
  status = widget( "CommunicationStatus" );
  if( Connected ) {
    status.setImage( System.Image( "ConnectionStateOK" ));
  } else {
    status.setImage( System.Image( "ConnectionStateError" ));
  }
}

System.SetReadObjects( new Array(
  livingRoomState,
  eatingRoomState,
  kitchenState
));

System.PageUpdate = function( CO ) {
  if( CO.widget == null ) {
    // do nothing
  } else if( CO.value == "true" ) {
    CO.widget.setImage( CF.widget( "SmallIOn1", "PResources", "System" ).getImage(), 0 );
    CO.widget.setImage( CF.widget( "SmallIOn2", "PResources", "System" ).getImage(), 1 );
  } else {
    CO.widget.setImage( CF.widget( "SmallIOff1", "PResources", "System" ).getImage(), 0 );
    CO.widget.setImage( CF.widget( "SmallIOff2", "PResources", "System" ).getImage(), 1 );
  }
}

if( System.DEBUG ) {
  System.print( "Lights.Enter" );
} else {
  CF.widget( "_PS_DEBUG_", "Main" ).visible = false;
}
