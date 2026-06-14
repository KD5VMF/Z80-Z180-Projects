@echo off
setlocal
cd /d "%~dp0"
echo ============================================================
echo TMS ASM Builder IDE - First Run
echo ============================================================
echo.
where dotnet >nul 2>nul
if errorlevel 1 (
    echo .NET SDK was not found.
    echo.
    echo Install the .NET 8 SDK or newer, then run this again.
    echo Official download: https://dotnet.microsoft.com/download
    echo.
    pause
    exit /b 1
)
echo Found dotnet:
dotnet --version
echo.
echo Starting IDE...
dotnet run --project TMSAsmBuilder\TMSAsmBuilder.csproj
pause
