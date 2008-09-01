import mx.events.*;

class SmartServerConnector extends XMLSocket {

    private var Container : XML;
    private var Root : XMLNode;
    private var Connected : Boolean = false;
    private var Dispatcher : EventDispatcher;
    private var Event : Object;

    function SmartServerConnector() {
        Container = new XML( "" );
        Dispatcher = new EventDispatcher();
        Event = new Object();
        Event.target = this;
    }
    
    function addEventListener( EventName : String, Listener : Object ) {
        Dispatcher.addEventListener( EventName, Listener );
    }
    
    function Connect( Server : String ) {
        if( Connected ) {
            Close();
        }
        super.connect( Server, 6006 ); 
    }
    
    function onConnect( Success : Boolean ) {
        Connected = Success;

        Event.type = "onConnect";
        Event.Success = Success;
        Dispatcher.dispatchEvent( Event );
    }
    
    function Close() {
        if( Connected ) {
            super.close();
            onClose();
        }
    }
    
    function onClose() {
        Connected = false;

        Event.type = "onClose";
        Dispatcher.dispatchEvent( Event );
    }
    
    function Send( DataName, DataValue : String ) {
        var I, N : XMLNode;
        
        if( !Connected || DataName == "" ) {
          return;
        }

        if( Root != null ) {
            Root.removeNode();
        }
        Root = Container.createElement( "xmlsocket" );
        Container.appendChild( Root );

        I = Container.createElement( "item" );
        Root.appendChild( I );

        N = Container.createElement( "name" );
        N.appendChild( Container.createTextNode( DataName ));  
        I.appendChild( N );  

        N = Container.createElement( "value" );
        N.appendChild( Container.createTextNode( DataValue ));
        I.appendChild( N );  

        super.send( Root.toString());
    }
    
    function onXML( Data : XMLNode ) {
        var EO : Object;
        var Name, Value : String = "";
        var I : XMLNode = Data.firstChild;
        var N : XMLNode;
        
        if( I == null || I.nodeName != "xmlsocket" ) {
            return;
        };
        I = I.firstChild;
        while (I != null) {
            if( I.nodeName == "item" ) {
                N = I.firstChild;
                if( N != null && N.nodeName == "name" ) {
                    Name = N.firstChild.toString();
                    N = N.nextSibling;
                    Value = N.firstChild.toString();
                    N = N.nextSibling;

                    Event.type = "onReceive";
                    Event.Name = Name;
                    Event.Value = Value;
                    Dispatcher.dispatchEvent( Event );
                }
            }
            I = I.nextSibling;
        }
    }
}
