# Deploy the MicroPython SuperLoop package to a Pico running MicroPython (Windows).
[CmdletBinding()]
param(
    # Serial port. Leave blank to auto-detect, which is usually right on Windows.
    [string]$Port = ''
)

. "$PSScriptRoot\common.ps1"

$repoRoot = Split-Path $PSScriptRoot -Parent
Set-Location $repoRoot

if (-not (Get-Command mpremote -ErrorAction SilentlyContinue)) {
    Write-Host 'mpremote not found.' -ForegroundColor Red
    Write-Host 'Install it with:  pip install mpremote' -ForegroundColor Yellow
    exit 1
}

$target = if ($Port) { "serial://$Port" } else { 'serial://auto' }

# A C++ or FreeRTOS image has no MicroPython REPL, so mpremote will fail here.
# Check up front so the error is actionable.
& mpremote connect $target exec "print('ok')" *> $null
if ($LASTEXITCODE -ne 0) {
    Write-Host 'Could not reach a MicroPython REPL on the Pico.' -ForegroundColor Red
    Write-Host 'The board is probably still running the C++ or FreeRTOS firmware.' -ForegroundColor Yellow
    Write-Host 'Flash MicroPython first:  .\scripts\flash_micropython.ps1' -ForegroundColor Yellow
    exit 1
}

# Stage a clean copy. The repo contains CPython __pycache__ directories that are
# useless on MicroPython and can shadow modules, so never copy them.
$stage = Join-Path ([System.IO.Path]::GetTempPath()) ("superloop-stage-" + [System.Guid]::NewGuid().ToString('N'))
New-Item -ItemType Directory -Force -Path $stage | Out-Null
try {
    Copy-Item (Join-Path $repoRoot 'python\*') $stage -Recurse -Force
    Get-ChildItem $stage -Recurse -Directory -Filter '__pycache__' |
        Remove-Item -Recurse -Force -ErrorAction SilentlyContinue
    Get-ChildItem $stage -Recurse -File -Include '*.pyc' |
        Remove-Item -Force -ErrorAction SilentlyContinue

    # Upload file by file to an explicit remote path. Avoids mpremote's
    # directory/glob semantics and its local-vs-remote ':' parsing, which is
    # genuinely ambiguous when the local path is a Windows drive letter.
    $files = Get-ChildItem $stage -Recurse -File -Filter '*.py'
    if ($files.Count -eq 0) {
        Write-Host 'No .py files staged - nothing to upload.' -ForegroundColor Red
        exit 1
    }

    Write-Host "Deploying $($files.Count) file(s) to Pico root..."
    foreach ($f in $files) {
        $rel = $f.FullName.Substring($stage.Length).TrimStart('\', '/')
        $remote = ':' + ($rel -replace '\\', '/')
        Write-Host "  $rel  ->  $remote"
        & mpremote connect $target fs put $f.FullName $remote
        if ($LASTEXITCODE -ne 0) {
            Write-Host "Upload failed on $rel" -ForegroundColor Red
            Write-Host 'If the board is busy, open a REPL (mpremote connect) and press' -ForegroundColor Yellow
            Write-Host 'Ctrl-D to stop boot.py, then re-run this script.' -ForegroundColor Yellow
            exit 1
        }
    }

    Write-Host ''
    Write-Host 'Files now on the board:' -ForegroundColor Green
    & mpremote connect $target fs ls ':' | ForEach-Object { "  $_" }
} finally {
    Remove-Item $stage -Recurse -Force -ErrorAction SilentlyContinue
}

Write-Host ''
Write-Host 'Unplug and replug the Pico (or press Ctrl-D in the REPL) to run boot.py.' -ForegroundColor Green
