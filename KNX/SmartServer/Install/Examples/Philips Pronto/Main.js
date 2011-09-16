// ==== GLOBAL SETTINGS
var DEBUG = true;
var CORE_PERIOD = 200;
var COMMUNICATE_EACH = 4; // count of periods

var IP_ADDRESS = "10.0.1.133";
var IP_PORT = "6007";

// ==== COMMUNICATION STATES
var DISCONNECTED = 0;
var WAIT_CONNECT = 1;
var RESPONDED = 2;
var EXPECT_RESPONSE_1 = 3;
var EXPECT_RESPONSE_2 = 4;
var WAIT_DISCONNECT = 5;

// ==== INITIALIZATION
if( System.initialized == undefined ) {
  InitSystem();
  System.initialized = true;
}

function InitSystem() {
  System.DEBUG = DEBUG;
  System.IPAddress = IP_ADDRESS;

  System.CO = CO;
  System.LogE = LogE;
  System.LogS = LogS;
  System.Image = Image;
  System.Connect = Connect;
  System.Disconnect = Disconnect;
  System.SetReadObjects  = SetReadObjects;
  System.NormalizeNumber = NormalizeNumber;

  System.corePeriodCount = 1;
  System.connection = null;
  System.connectionState = DISCONNECTED;
  System.waitConnectCount = COMMUNICATE_EACH;
  System.waitConnectRecoverCount = 0;

  scheduleAfter( CORE_PERIOD, Core );
}

// ===== MAIN COMMUNICATION LOOP
function Core() {
  scheduleAfter( CORE_PERIOD, Core );

  var communicate = System.corePeriodCount == 1;
  System.corePeriodCount = System.corePeriodCount - 1;
  if( System.corePeriodCount == 0 ) {
    System.corePeriodCount = COMMUNICATE_EACH;
  } 

  if( communicate && System.pageCOs != null ) {
    CommunicatePage();
  }
  CheckConnection();
  
  if( System.ConnectionCheck != null ) {
    System.ConnectionCheck( System.connectionState != DISCONNECTED && System.connectionState != WAIT_CONNECT );
  }
}

function CommunicatePage() {
  Connect();
  for( i = 0; i < System.pageCOs.length; i++ ) {
    System.pageCOs[i].Read();
  }
}

// ===== CLIENT INTERFACE TO SET COMMUNICATED OBJECTS
function SetReadObjects( pageCOs ) {
  System.pageCOs = pageCOs;
}

// ===== COMMUNICATION OBJECT AND ITS METHODS
function CO( address, type, widget, imageName ) {
  this.address = address;
  this.type = type;
  this.widget = widget;
  this.imageName = imageName;
  this.Read = Read;
  this.Write = Write;
  this.Set = Set;
  this.Reset = Reset;
  this.SetSynchronous = SetSynchronous;
  this.ResetSynchronous = ResetSynchronous;
}

function Read() {
  Connect();
  Send( "get " + this.address + "\r\n" );
}

function Write( value ) {
  Connect();
  Send( "set " + this.address + " " + value + "\r\n" );
}

function Set() {
  if( this.type = "switch" ) {
    this.Write( true );
  }
}

function Reset() {
  if( this.type = "switch" ) {
    this.Write( false );
  }
}

function SetSynchronous() {
  ConnectSynchronous();
  this.Set();
  Disconnect();
}

function ResetSynchronous() {
  ConnectSynchronous();
  this.Reset();
  Disconnect();
}

// ===== GLOBAL HELPERS
function Image( name ) {
  return CF.widget( name, "PResources", "KNX" ).getImage();
}

function NormalizeNumber( n ) {
  if( n == null ) {
    return n;
  } else if( n.indexOf( "." ) == -1 ) {
    return n + ".0";
  } else {
    return n;
  }
}

function LogS( originator, text ) {
  Diagnostics.log( originator + ": " + text );
}

function LogE( originator, error ) {
  Diagnostics.log( originator + ": " + error.name + " [" + error.message + "]" );
}

// ===== INTERNAL COMMUNICATION ROUTINES
function Connect() {
  if( System.connection == null ) {

    var socket = new TCPSocket( false );
    socket.onConnect = OnConnect;
    socket.onData = OnData;
    socket.onIOError = OnError;
    socket.onClose = OnClose;

    try {
      socket.connect( System.IPAddress, IP_PORT, 2 * CORE_PERIOD );
      
      System.connectionState = WAIT_CONNECT;
      System.waitConnectCount = COMMUNICATE_EACH;
      System.connection = socket;

      if( System.connection.connected ) { // socket can connect immediately?
        OnConnect();
      }

    } catch( error ) {
      LogE( "C", error );
      socket.close();
      System.connectionState = DISCONNECTED;

    }
  }
}

function ConnectSynchronous() {
  if( System.connection == null) {
    var socket = new TCPSocket( true );

    try {
      socket.connect( System.IPAddress, IP_PORT, 2 * CORE_PERIOD );
      if( socket.connected ) {
        System.connection = socket;
      }

    } catch( error ) {
      LogE( "Cs", error );
      socket.close();

    }
  }
}

function Send( data ) {
  if( data == null ) {
    // fall down and try to send current
  } else if( System.toSend == null ) {
    System.toSend = "" + data;
  } else {
    System.toSend = System.toSend + data;
  }
  if( System.connection != null && System.connection.connected && System.toSend != null && System.toSend != "" ) {

    try {
      System.connection.write( System.toSend );

      System.connectionState = EXPECT_RESPONSE_1;

    } catch( error ) {
      LogE( "W", error );
      Disconnect();
    }

    System.toSend = null;
  }
}

function CheckConnection() {
  // cleanup connection if nothing was received after request or if timeout expired
  switch( System.connectionState ) {
    case DISCONNECTED:
      break;

    case WAIT_CONNECT:
      // handle timeout by self
      System.waitConnectCount = System.waitConnectCount - 1;
      if( System.waitConnectCount == 0 ) {
        System.waitConnectRecoverCount = System.waitConnectRecoverCount + 1;
        Disconnect();
      }
      break; 
  
    case RESPONDED: // OK, check for idle delay
      System.connectionState = WAIT_DISCONNECT;      
      break;

    case EXPECT_RESPONSE_1: // give more time to responder
      System.connectionState = EXPECT_RESPONSE_2;
      break;

    case EXPECT_RESPONSE_2: // nothing responded, check for idle delay
      System.connectionState = WAIT_DISCONNECT;      
      break;

    case WAIT_DISCONNECT:
      Disconnect();
      break;
  }
}

function Disconnect() {
  if( System.connection == null) {
    return;
  }
  System.connection.close();
  System.connection = null;
  System.connectionState = DISCONNECTED;
  System.toSend = null;
  System.readData = null;
}

function OnConnect() {
  System.connectionState = WAIT_DISCONNECT;
  Send( null );
}

function OnError( error ) {
  LogE( "E", error );
  Disconnect();
}

function OnClose() {
  Disconnect();
}

function OnData() {
  if( System.readData == null ) {
    System.readData = "";
  }
  try {
    System.readData = System.readData + System.connection.read();
    ParseResponse();

    System.connectionState = RESPONDED;

  } catch( error ) {
    LogE( "R", error );
    Disconnect();
  }
}

function ParseResponse() {
  // check system conditions
  if( System.readData == null ) {
    return;
  } else if( System.pageCOs == null ) {
    System.readData = null;
    return;
  }

  // check response
  var response = System.readData.split( "\n" );
  if( response.length == 0 ) {
    return;
  } else if( response[response.length-1].indexOf( "\r" ) == -1 ) { // last string is not complete
    System.readData = response[response.length-1];
    response.length--;
  } else { // last string is complete too, clear read buffer
    System.readData = null;
  }

  // parse response, if needed return data back
  for( gi = 0; gi < response.length; ) {
    if( response[gi].indexOf( "200" ) == -1 ) {
      gi++;
    } else if( gi == response.length-1 ) { // 200 received without data, push it back
      if( System.readData == null ) {
        System.readData = "";
      }
      System.readData = response[gi] + "\n" + System.readData;
      break;
    } else {
      gi++;

      var data = response[gi].split( /[ \r]/, 2 );
      var foundCO = null;      
      for( gj = 0; gj < System.pageCOs.length; gj++ ) {
        if( System.pageCOs[gj].address == data[0] ) {
          foundCO = System.pageCOs[gj];
          foundCO.value = data[1];
          break;
        }
      }
      if( System.PageUpdate != null && foundCO != null ) {
        System.PageUpdate( foundCO );
      }

      gi++;
    } // if, elsif 200...
  }
}
// ===== END OF PRONTO MAIN SCRIPT
