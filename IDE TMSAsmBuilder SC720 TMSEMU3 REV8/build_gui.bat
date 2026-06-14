@echo off
setlocal
cd /d "%~dp0"
where dotnet >nul 2>nul
if errorlevel 1 (
    echo .NET SDK was not found. Install .NET 8 SDK or newer.
    pause
    exit /b 1
)
dotnet build TMSAsmBuilder.sln -c Release
pause
