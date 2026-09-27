# Build and flash the FreeRTOS variant (Windows).
[CmdletBinding()]
param()

. "$PSScriptRoot\common.ps1"

$repoRoot = Split-Path $PSScriptRoot -Parent
Set-Location $repoRoot
Initialize-SdkPath

if (-not (Test-Path 'freertos\third_party\FreeRTOS-Kernel')) {
    Write-Host 'FreeRTOS kernel missing.' -ForegroundColor Red
    Write-Host 'Run .\scripts\fetch_freertos.ps1 first.' -ForegroundColor Yellow
    exit 1
}

# FreeRTOS is an add_subdirectory() of the top-level CMakeLists, so build the one
# tree rather than configuring a second one under freertos\build.
Write-Host 'Building SuperLoop_FreeRTOS...'
& cmake -S . -B build -G Ninja
if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }
& cmake --build build --target SuperLoop_FreeRTOS
if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }

$uf2 = 'build\freertos\SuperLoop_FreeRTOS.uf2'
$elf = 'build\freertos\SuperLoop_FreeRTOS.elf'
if (-not (Test-Path $uf2)) {
    Write-Host "Build did not produce $uf2" -ForegroundColor Red
    exit 1
}

# Fast path: device already in BOOTSEL, flash over USB with picotool.
if ($script:Picotool) {
    & $script:Picotool load $elf -f *>$null
    if ($LASTEXITCODE -eq 0) {
        Write-Host 'Flashed via picotool. Rebooting into the new firmware...' -ForegroundColor Green
        & $script:Picotool reboot *>$null
        Write-Host 'Done. Watch it with a serial terminal on the USB CDC port (115200 baud).' -ForegroundColor Green
        exit 0
    }
}

# Fallback: copy the UF2 to the RPI-RP2 drive.
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
