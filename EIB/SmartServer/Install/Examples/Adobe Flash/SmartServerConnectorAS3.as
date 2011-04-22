package 
{	
	import flash.events.*;
	import flash.net.*;
	import flash.xml.*;
	import fl.events.*;
	import SmartServerDataEventAS3;

	// the connection class
	public class SmartServerConnectorAS3 extends EventDispatcher
	{
		// privates
		private var socket:XMLSocket = new XMLSocket();
		private var container:XMLDocument = new XMLDocument();
		private var xmlroot:XMLNode;
		private var connected:Boolean = false;

		public function SmartServerConnectorAS3()
		{
			socket.addEventListener( Event.CONNECT, onConnect );
			socket.addEventListener( Event.CLOSE, onClose );
			socket.addEventListener( DataEvent.DATA, onXML );
		}
		
		public function Connect( Server : String )
		{
			if (connected)
			{
				Close();
			}
			socket.connect( Server, 6006 );
		}

		private function onConnect( event : Event )
		{
			connected = true;
			dispatchEvent( new Event( Event.CONNECT ));
		}

		public function Close()
		{
			if (connected)
			{
				socket.close();
				HandleClose();
			}
		}

		private function onClose( event : Event )
		{
			HandleClose();
		}
		
		private function HandleClose()
		{
			connected = false;
			dispatchEvent( new Event( Event.CLOSE ));
		}

		public function Send( DataName, DataValue : String )
		{
			var I,N:XMLNode;

			if (! connected || DataName == "")
			{
				return;
			}

			if (xmlroot != null)
			{
				xmlroot.removeNode();
			}
			xmlroot = container.createElement("xmlsocket");
			container.appendChild( xmlroot );

			I = container.createElement("notify");
			xmlroot.appendChild( I );

			N = container.createElement("name");
			N.appendChild( container.createTextNode( DataName ));
			I.appendChild( N );

			N = container.createElement("value");
			N.appendChild( container.createTextNode( DataValue ));
			I.appendChild( N );

			socket.send( xmlroot.toString());
		}

		public function AskValue( DataName : String )
		{
			var I,N:XMLNode;

			if (! connected || DataName == "")
			{
				return;
			}

			if (xmlroot != null)
			{
				xmlroot.removeNode();
			}
			xmlroot = container.createElement("xmlsocket");
			container.appendChild( xmlroot );

			I = container.createElement("ask");
			xmlroot.appendChild( I );

			N = container.createElement("name");
			N.appendChild( container.createTextNode( DataName ));
			I.appendChild( N );

			socket.send( xmlroot.toString());
		}

		private function onXML( dataEvent : DataEvent )
		{
			var Data:XMLNode = new XMLDocument( dataEvent.data );
			var EO:Object;
			var Name,Value:String = "";
			var I:XMLNode = Data.firstChild;
			var N:XMLNode;

			if (I == null || I.nodeName != "xmlsocket")
			{
				return;
			}
			I = I.firstChild;
			while (I != null)
			{
				if (I.nodeName == "notify")
				{
					N = I.firstChild;
					if (N != null && N.nodeName == "name")
					{
						Name = N.firstChild.toString();
						N = N.nextSibling;
						if (N.firstChild == null)
						{
							Value = "";
						}
						else
						{
							Value = N.firstChild.toString();
						}
						N = N.nextSibling;

						dispatchEvent( new SmartServerDataEventAS3( Name, Value ));
					}
				}
				I = I.nextSibling;
			}
		}
	}
}