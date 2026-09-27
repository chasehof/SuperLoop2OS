# Flash the C++ superloop to a Pico in BOOTSEL mode (Windows).
[CmdletBinding()]
param()

. "$PSScriptRoot\common.ps1"

$repoRoot = Split-Path $PSScriptRoot -Parent
Set-Location $repoRoot
Initialize-SdkPath

$elf = 'build\SuperLoop.elf'
$uf2 = 'build\SuperLoop.uf2'

if (-not (Test-Path $elf)) {
    Write-Host "Build output $elf not found." -ForegroundColor Red
    Write-Host 'Run .\scripts\run_cpp.ps1 first.' -ForegroundColor Yellow
    exit 1
}

# Fast path: flash over USB with picotool (device already in BOOTSEL).
if ($script:Picotool) {
    & $script:Picotool load $elf -f
    if ($LASTEXITCODE -eq 0) {
        Write-Host 'Flashed via picotool.' -ForegroundColor Green
        & $script:Picotool reboot *>$null
        exit 0
    }
}

# Fallback: copy the UF2 to the RPI-RP2 drive.
if (-not (Test-Path $uf2)) {
    Write-Host "picotool unavailable and $uf2 not found." -ForegroundColor Red
    exit 1
}

$drive = Find-RpiRp2Drive
if (-not $drive) {
    Show-NoDeviceHelp
    Write-Host "You can also copy $uf2 to the RPI-RP2 drive by hand." -ForegroundColor Yellow
    exit 2
}

Write-Host "Copying $uf2 to $drive"
Copy-Item $uf2 $drive -Force
Start-Sleep -Seconds 2
Write-Host 'Done. The Pico will reboot into the new firmware.' -ForegroundColor Green
