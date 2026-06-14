@echo off
setlocal
cd /d "%~dp0"
if not exist "Portable_Windows_App\TMSAsmBuilder.exe" (
    echo Portable_Windows_App\TMSAsmBuilder.exe was not found.
    pause
    exit /b 1
)
echo Starting TMS ASM Builder IDE...
start "" "Portable_Windows_App\TMSAsmBuilder.exe"
