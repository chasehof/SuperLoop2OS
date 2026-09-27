# Build the C++ superloop (bare metal, no RTOS) -- Windows.
[CmdletBinding()]
param()

. "$PSScriptRoot\common.ps1"

$repoRoot = Split-Path $PSScriptRoot -Parent
Set-Location $repoRoot
Initialize-SdkPath

if (-not (Get-Command cmake -ErrorAction SilentlyContinue)) {
    Write-Host 'cmake not found on PATH.' -ForegroundColor Red
    Write-Host 'Install the Pico SDK, or adjust Initialize-SdkPath in common.ps1.' -ForegroundColor Yellow
    exit 1
}

# -G Ninja is required: this script builds with Ninja, but a build dir created
# with a different generator has no build.ninja.
Write-Host 'Building C++ SuperLoop...'
& cmake -S . -B build -G Ninja
if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }
& cmake --build build
if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }

Write-Host ''
Write-Host 'Built:' -ForegroundColor Green
Write-Host '  build\SuperLoop.uf2'
Write-Host 'Flash it with .\scripts\deploy_cpp.ps1'
