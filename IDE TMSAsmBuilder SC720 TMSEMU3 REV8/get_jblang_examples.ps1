$ErrorActionPreference = "Stop"
$Root = Split-Path -Parent $MyInvocation.MyCommand.Path
$Zip = Join-Path $Root "jblang_TMS9918A_master.zip"
$Extract = Join-Path $Root "_github_extract"
$Libs = Join-Path $Root "TMSAsmBuilder\Libs"
New-Item -ItemType Directory -Force -Path $Libs | Out-Null
Write-Host "Downloading J.B. Langston TMS9918A master zip..."
Invoke-WebRequest -Uri "https://github.com/jblang/TMS9918A/archive/refs/heads/master.zip" -OutFile $Zip
if (Test-Path $Extract) { Remove-Item -Recurse -Force $Extract }
New-Item -ItemType Directory -Path $Extract | Out-Null
Expand-Archive -Path $Zip -DestinationPath $Extract -Force
$Examples = Get-ChildItem -Path $Extract -Directory -Recurse | Where-Object { $_.Name -eq "examples" } | Select-Object -First 1
if (-not $Examples) { throw "examples folder not found" }
Copy-Item -Path (Join-Path $Examples.FullName "*.asm") -Destination $Libs -Force
Remove-Item -Recurse -Force $Extract
Write-Host "Copied ASM files into $Libs"
Get-ChildItem $Libs -Filter *.asm | Select-Object Name
