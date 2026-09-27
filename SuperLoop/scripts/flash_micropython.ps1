# Flash the MicroPython firmware onto a Pico in BOOTSEL mode (Windows).
#
# Must be run BEFORE deploy_python.ps1. MicroPython is a self-contained firmware
# image providing the interpreter; the C++ and FreeRTOS variants replace it, so
# switching between the Python and native variants means reflashing this each time.
[CmdletBinding()]
param(
    # Board family. Use PICOW for a Pico W.
    [string]$Board = 'PICO',
    # Pin the release for class so everyone gets the same firmware.
    [string]$Version = '1.25.0'
)

. "$PSScriptRoot\common.ps1"

$url = "https://github.com/micropython/micropython/releases/download/v$Version/micropython-$Board-$Version.uf2"
$cacheDir = Join-Path $env:LOCALAPPDATA 'micropython-uf2'
$uf2 = Join-Path $cacheDir (Split-Path $url -Leaf)

if (-not (Test-Path $uf2)) {
    Write-Host "Downloading $(Split-Path $url -Leaf)..."
    New-Item -ItemType Directory -Force -Path $cacheDir | Out-Null
    try {
        Invoke-WebRequest -Uri $url -OutFile $uf2 -UseBasicParsing
    } catch {
        Write-Host "Download failed: $($_.Exception.Message)" -ForegroundColor Red
        Write-Host "Download it manually from $url" -ForegroundColor Yellow
        Write-Host "and save it to $uf2" -ForegroundColor Yellow
        exit 1
    }
}

$drive = Wait-ForRpiRp2Drive -TimeoutSeconds 5
if (-not $drive) { $drive = Find-RpiRp2Drive }
if (-not $drive) {
    Show-NoDeviceHelp
    exit 2
}

Write-Host "Flashing $uf2 to $drive"
Copy-Item $uf2 $drive -Force

# Windows may not have flushed the write before the bootloader reboots.
Start-Sleep -Seconds 2
Write-Host 'Copied. The Pico will now reboot into MicroPython.' -ForegroundColor Green
Write-Host 'Next:  .\scripts\deploy_python.ps1'
