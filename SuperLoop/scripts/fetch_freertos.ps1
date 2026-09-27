# Fetch the FreeRTOS kernel sources (Windows).
[CmdletBinding()]
param()

$repoRoot = Split-Path $PSScriptRoot -Parent
$thirdParty = Join-Path $repoRoot 'freertos\third_party'
$kernel = Join-Path $thirdParty 'FreeRTOS-Kernel'

if (-not (Get-Command git -ErrorAction SilentlyContinue)) {
    Write-Host 'git not found. Install Git for Windows and re-run.' -ForegroundColor Red
    exit 1
}

New-Item -ItemType Directory -Force -Path $thirdParty | Out-Null

if (Test-Path (Join-Path $kernel '.git')) {
    Write-Host 'FreeRTOS-Kernel already present. Pulling latest changes.'
    & git -C $kernel pull
} else {
    Write-Host "Fetching FreeRTOS kernel into $kernel"
    & git clone --depth 1 https://github.com/FreeRTOS/FreeRTOS-Kernel.git $kernel
}

if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }

Write-Host 'Done. You can now build with .\scripts\deploy_freertos.ps1' -ForegroundColor Green
