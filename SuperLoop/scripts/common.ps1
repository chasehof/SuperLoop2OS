# Shared helpers for the Windows PowerShell scripts.
# Dot-source this:  . "$PSScriptRoot\common.ps1"

$ErrorActionPreference = 'Stop'

function Initialize-SdkPath {
    <#
      Puts the Pico SDK's bundled cmake/ninja/picotool on PATH for this session.
      The SDK installs them under %USERPROFILE%\.pico-sdk, which is not on PATH
      by default, so scripts fail with "cmake not found" without this.
    #>
    $sdk = Join-Path $env:USERPROFILE '.pico-sdk'
    if (-not (Test-Path $sdk)) {
        throw "Pico SDK not found at $sdk. Install it from https://github.com/raspberrypi/pico-sdk"
    }

    $paths = @(
        (Join-Path $sdk 'cmake\v4.3.4\bin')
        (Join-Path $sdk 'ninja\v1.13.2')
        (Join-Path $sdk 'toolchain\15_2_Rel1\bin')
    )
    foreach ($p in $paths) {
        if (Test-Path $p) { $env:PATH = "$p;$env:PATH" }
    }

    $script:Picotool = Join-Path $sdk 'picotool\2.3.0\picotool\picotool.exe'
    if (-not (Test-Path $script:Picotool)) {
        $cmd = Get-Command picotool -ErrorAction SilentlyContinue
        if ($cmd) { $script:Picotool = $cmd.Source } else { $script:Picotool = $null }
    }
    $script:SdkRoot = $sdk
}

function Find-RpiRp2Drive {
    <#
      Returns the drive root (e.g. "E:\") of a Pico in BOOTSEL mode, or $null.
      Matches on INFO_UF2.TXT containing "Board-ID: RPI-RP2" rather than on the
      drive letter, because the letter is assigned by Windows and varies.
    #>
    $vols = Get-Volume -ErrorAction SilentlyContinue | Where-Object { $_.DriveLetter }
    foreach ($v in $vols) {
        $root = "$($v.DriveLetter):\"
        $info = Join-Path $root 'INFO_UF2.TXT'
        if (Test-Path $info) {
            try {
                if ((Get-Content $info -Raw) -match 'Board-ID:\s*RPI-RP2') { return $root }
            } catch { }
        }
    }
    return $null
}

function Wait-ForRpiRp2Drive {
    param([int]$TimeoutSeconds = 20)
    $deadline = (Get-Date).AddSeconds($TimeoutSeconds)
    while ((Get-Date) -lt $deadline) {
        $d = Find-RpiRp2Drive
        if ($d) { return $d }
        Start-Sleep -Milliseconds 500
    }
    return $null
}

function Show-NoDeviceHelp {
    Write-Host ''
    Write-Host 'No Pico found in BOOTSEL mode.' -ForegroundColor Yellow
    Write-Host ''
    Write-Host 'To enter BOOTSEL mode:'
    Write-Host '  1. Unplug the Pico.'
    Write-Host '  2. Hold the BOOTSEL button (the small one on the top edge).'
    Write-Host '  3. Plug the Pico back in while still holding BOOTSEL.'
    Write-Host '  4. Release BOOTSEL. Windows will mount it as a removable drive.'
    Write-Host ''
    Write-Host 'If the drive never appears, try a different USB data cable -- many'
    Write-Host 'charge-only cables cannot carry data.'
}
