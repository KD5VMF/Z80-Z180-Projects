$ErrorActionPreference = "Stop"
$RepoRoot = Resolve-Path (Join-Path $PSScriptRoot "..")

foreach ($folder in @("Builds", "Out", "TMSAsmBuilder_REV10_ready_to_run")) {
    $path = Join-Path $RepoRoot $folder
    if (Test-Path $path) {
        Write-Host "Cleaning $path"
        Remove-Item $path -Recurse -Force
    }
}

New-Item -ItemType Directory -Force -Path (Join-Path $RepoRoot "Builds") | Out-Null
New-Item -ItemType Directory -Force -Path (Join-Path $RepoRoot "Out") | Out-Null
New-Item -ItemType File -Force -Path (Join-Path $RepoRoot "Builds\.gitkeep") | Out-Null
New-Item -ItemType File -Force -Path (Join-Path $RepoRoot "Out\.gitkeep") | Out-Null

Get-ChildItem -Path (Join-Path $RepoRoot "Work") -Directory -Filter "_build_tmp_*" -ErrorAction SilentlyContinue | Remove-Item -Recurse -Force
Write-Host "Clean complete." -ForegroundColor Green
