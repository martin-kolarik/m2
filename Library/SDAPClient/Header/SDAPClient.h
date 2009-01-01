// DEFINITION MODULE SDAPClient

// Source: SDAPClient.def

#pragma once

#define __IFACE __declspec(dllimport)
#define OUT

typedef unsigned char BOOLEAN;
typedef unsigned int CARDINAL;
# ifdef _WCHAR_T_DEFINED
    typedef wchar_t WCHAR;
# else
    typedef unsigned short WCHAR;
# endif

#pragma pack(push, 8)
namespace SDAPClient { 

	// forwarded opaque types
	class ISDAPClientEvents;
	class ISDAPClient;

	// module itself begin
	class __IFACE __declspec(novtable) ISDAPClientEvents { public:
		virtual void OnConnect( CARDINAL Error ) throw() = 0;
		virtual void OnClose( CARDINAL Error ) throw() = 0;
		virtual void OnReceive( CARDINAL Data_HIGH, const WCHAR* Data, CARDINAL Value_HIGH, const WCHAR* Value ) throw() = 0;
	}; // ISDAPClientEvents


	class __IFACE __declspec(novtable) ISDAPClient { public:
		virtual void Dispose() throw() = 0;
		virtual CARDINAL Connect( CARDINAL Host_HIGH, WCHAR* Host ) throw() = 0;
		virtual void Close() throw() = 0;
		virtual CARDINAL SetAdvise( BOOLEAN AdviseEnabled ) throw() = 0;
		virtual BOOLEAN IsConnected() throw() = 0;
		virtual CARDINAL Write( CARDINAL Data_HIGH, const WCHAR* Data, CARDINAL Value_HIGH, const WCHAR* Value ) throw() = 0;
		virtual CARDINAL Ask( CARDINAL Data_HIGH, const WCHAR* Data ) throw() = 0;
		virtual void SetEventListener( ISDAPClientEvents* Listener ) throw() = 0;
	}; // ISDAPClient

    __IFACE CARDINAL __fastcall Startup() throw();
	__IFACE void __fastcall Cleanup() throw();

    __IFACE CARDINAL __fastcall newSDAPClient( OUT ISDAPClient** client ) throw();

}
#pragma pack(pop)
// end of module: SDAPClient
