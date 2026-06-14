@echo off
cd /d "%~dp0"
dotnet build TMSAsmBuilder.sln -c Release
pause
