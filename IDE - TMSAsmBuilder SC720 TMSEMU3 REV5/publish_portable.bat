@echo off
setlocal
cd /d "%~dp0"

set OUTDIR=Release\TMSAsmBuilder_Portable
if exist "%OUTDIR%" rmdir /s /q "%OUTDIR%"

echo Publishing framework-dependent portable folder...
dotnet publish TMSAsmBuilder\TMSAsmBuilder.csproj -c Release -r win-x64 --self-contained false -o "%OUTDIR%"

if errorlevel 1 (
  echo.
  echo Publish failed.
  pause
  exit /b 1
)

echo.
echo Portable folder created:
echo   %CD%\%OUTDIR%
echo.
echo Run:
echo   %OUTDIR%\TMSAsmBuilder.exe
echo.
echo Note: framework-dependent publish needs .NET 8 Desktop Runtime on the target PC.
echo For a larger self-contained package, use:
echo   dotnet publish TMSAsmBuilder\TMSAsmBuilder.csproj -c Release -r win-x64 --self-contained true -p:PublishSingleFile=false -o "%OUTDIR%"
echo.
pause
