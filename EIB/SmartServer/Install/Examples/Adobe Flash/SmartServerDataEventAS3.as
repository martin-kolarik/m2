package 
{	
	import flash.events.*;

	// SmartServer data Event
	public class SmartServerDataEventAS3 extends Event
	{
		public static const SMARTSERVER_DATAEVENT : String = "SmartServerDataEvent"; // Event Name

		private var _address : String;
		private var _value : String;

		public function SmartServerDataEventAS3( Address : String, Value : String )
		{
			super( SMARTSERVER_DATAEVENT );
			_address = Address;
			_value = Value;
		}
		
		public function get Address() : String
		{
			return _address;
		}

		public function get Value() : String
		{
			return _value;
		}

	}
}