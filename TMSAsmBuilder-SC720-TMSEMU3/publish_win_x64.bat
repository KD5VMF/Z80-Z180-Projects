@echo off
setlocal
cd /d "%~dp0"
where dotnet >nul 2>nul
if errorlevel 1 (
    echo .NET SDK was not found. Install .NET 8 SDK or newer.
    pause
    exit /b 1
)

echo Building a Windows x64 release folder...
dotnet publish TMSAsmBuilder\TMSAsmBuilder.csproj -c Release -r win-x64 --self-contained false -o Release\TMSAsmBuilder-win-x64
if errorlevel 1 (
    echo Publish failed.
    pause
    exit /b 1
)

echo.
echo Release folder created:
echo %cd%\Release\TMSAsmBuilder-win-x64
pause
