#ifndef _SVL_PVSTUB_SERVICE_H
#define _SVL_PVSTUB_SERVICE_H

typedef enum _svlError
{
	SVL_OK,								// Normal
	SVL_ALREADY_LOADED,					// Stub DLL already loaded into service
	SVL_LOAD_FAILED,					// Failed to load stub DLL into service
	SVL_FAILED_TO_ENABLE_STUB_SYMBOLS,	// Loaded DLL, but failed to enable stub symbols because couldn't find function
	SVL_NOT_LOADED,						// Couldn't unload DLL because DLL not loaded
	SVL_FAIL_UNLOAD,					// Couldn't unload DLL because couldn't find function
	SVL_FAIL_TO_CLEANUP_INTERNAL_HEAP,	// Couldn't get the internal stub heap and thus couldn't clean it up
	SVL_FAIL_MODULE_HANDLE				// Couldn't get the stub DLL handle so couldn't continue
} SVL_ERROR;

// IMPORTANT. 
// If you use svlPVStub_LoadPerformanceValidator() to load svlPerformanceValidatorStub.dll into your 
// application, you must also use svlPVStub_UnloadPerformanceValidator() to unload the DLL prior to
// your application being closed down. Failure to do so will almost certainly result in a crash.
// It does not matter how the application is closed down, you must ensure that you use
// svlPVStub_UnloadPerformanceValidator() to unload the DLL if you have loaded it.
//
// The DLL prepares itself in different ways and shuts itself down differently depending on if
// it is:-
// a) Directly linked to the application for use with the API or injected with Performance Validator.
//    When the DLL is used in this manner to DLL expects to oversee and manage the application
//    shutdown.
// b) Loaded by using svlPVStub_LoadPerformanceValidator().
//    When the DLL is used in this manner to DLL expects to be removed prior to application shutdown
//    and the behaviour of the DLL is undefined once you enter the program shutdown sequence. 
//
//	  This difference in behaviour is intentional and is done to allow the use of the stub DLL in
//	  services.

#ifdef __cplusplus
extern "C" {
#endif

SVL_ERROR __cdecl svlPVStub_LoadPerformanceValidator();

SVL_ERROR __cdecl svlPVStub_UnloadPerformanceValidator();

#ifdef __cplusplus
}
#endif

#endif
