// Test.cpp : Defines the entry point for the console application.
//

#include "stdafx.h"

#include "SDAPClient.h"

#define HIGH(x) (sizeof(x)/sizeof((x)[0])-1)

class CEvents: public SDAPClient::ISDAPClientEvents
{
private:
	virtual void OnConnect( CARDINAL Error ) throw();
	virtual void OnClose( CARDINAL Error ) throw();
	virtual void OnReceive( CARDINAL Data_HIGH, const WCHAR* Data, CARDINAL Value_HIGH, const WCHAR* Value ) throw();

public:
    CEvents();
    bool ConnectPassed();

private:
    volatile LONG m_ConnectPassed;
};

void CEvents::OnConnect( CARDINAL Error ) throw()
{
    InterlockedExchange( &m_ConnectPassed, 1 );

    wprintf( L"Connect: %x\r\n", Error );
}

void CEvents::OnClose( CARDINAL Error ) throw()
{
    wprintf( L"Close: %x\r\n", Error );
}

void CEvents::OnReceive( CARDINAL Data_HIGH, const WCHAR* Data, CARDINAL Value_HIGH, const WCHAR* Value )
{
    wprintf( L"Data: %s %s\r\n", Data, Value );
}

CEvents::CEvents()
{
    m_ConnectPassed = 0;
}

bool CEvents::ConnectPassed()
{
    return InterlockedExchangeAdd( &m_ConnectPassed, 0 ) == 1;
}

int _tmain(int argc, _TCHAR* argv[])
{
    const WCHAR HOST[] = L"127.0.0.1:6007";
    const WCHAR DATA[] = L"3/1/21";

    CEvents events;
    SDAPClient::ISDAPClient* pClient;
    int error;
    
    error = SDAPClient::Startup();
    assert( error == 0 );

    error = SDAPClient::newSDAPClient( &pClient );
    assert( error == 0 );
    pClient->SetEventListener( &events );

    error = pClient->Connect( HIGH(HOST), (WCHAR*)HOST );
    while( !events.ConnectPassed())
    {
        Sleep( 5 );
    }

    for( int i = 0; i < 10; i++ )
    {
        pClient->Ask( HIGH(DATA), (WCHAR*)DATA );
    }

    Sleep( 10000 );

    pClient->Close();
    pClient->Dispose();

    SDAPClient::Cleanup();
	return 0;
}

