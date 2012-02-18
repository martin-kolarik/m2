@if "%PROCESSOR_ARCHITECTURE%" equ "AMD64" (set Framework=%windir%\Microsoft.NET\Framework64\v4.0.30319)
@if "%PROCESSOR_ARCHITECTURE%" neq "AMD64" (set Framework=%windir%\Microsoft.NET\Framework\v4.0.30319)

"%Framework%\msbuild" -nologo -v:m -clp:nosummary /l:FileLogger,Microsoft.Build.Engine;logfile=build.log %*