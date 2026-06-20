param(
    [string]$Configuration = "Release",
    [string]$Runtime = "win-x64"
)

$ErrorActionPreference = "Stop"

$RepoRoot = Resolve-Path (Join-Path $PSScriptRoot "..")
$Project = Join-Path $RepoRoot "src\TMSAsmBuilder\TMSAsmBuilder.csproj"
$PublishDir = Join-Path $RepoRoot "TMSAsmBuilder_REV10_ready_to_run"

Write-Host "Publishing TMSAsmBuilder REV10..." -ForegroundColor Cyan
Write-Host "Project: $Project"
Write-Host "Output : $PublishDir"

if (Test-Path $PublishDir) {
    Remove-Item $PublishDir -Recurse -Force
}

New-Item -ItemType Directory -Force -Path $PublishDir | Out-Null

dotnet publish $Project `
    -c $Configuration `
    -r $Runtime `
    --self-contained false `
    -p:PublishSingleFile=false `
    -o $PublishDir

foreach ($folder in @("Assets", "Tools", "Libs", "Templates", "Work")) {
    $src = Join-Path $RepoRoot $folder
    $dst = Join-Path $PublishDir $folder
    if (Test-Path $src) {
        Copy-Item $src $dst -Recurse -Force
    }
}

foreach ($folder in @("Builds", "Out")) {
    New-Item -ItemType Directory -Force -Path (Join-Path $PublishDir $folder) | Out-Null
}

Copy-Item (Join-Path $RepoRoot "README.md") (Join-Path $PublishDir "README.md") -Force
Copy-Item (Join-Path $RepoRoot "CHANGELOG.md") (Join-Path $PublishDir "CHANGELOG.md") -Force

Write-Host ""
Write-Host "DONE: $PublishDir" -ForegroundColor Green
Write-Host "Run:  $PublishDir\TMSAsmBuilder.exe" -ForegroundColor Green
