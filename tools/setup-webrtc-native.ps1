$ErrorActionPreference = "Stop"

& (Join-Path $PSScriptRoot "install-webrtc-native.ps1")
if ($LASTEXITCODE -ne 0) {
    exit $LASTEXITCODE
}

Write-Host "Done. Re-run tools/godot.ps1 all to validate the project."
