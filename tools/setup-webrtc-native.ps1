param(
    [string]$Version = "1.2.1-stable"
)

$ErrorActionPreference = "Stop"
$repoRoot = Split-Path -Parent $PSScriptRoot
$archive = Join-Path $env:TEMP "godot-extension-webrtc_native-$Version.zip"
$url = "https://github.com/godotengine/webrtc-native/releases/download/$Version/godot-extension-webrtc_native.zip"

Write-Host "Downloading webrtc-native $Version..."
Invoke-WebRequest -Uri $url -OutFile $archive

Write-Host "Extracting into $repoRoot..."
Expand-Archive -Path $archive -DestinationPath $repoRoot -Force

Write-Host "Done. Re-run tools/godot.ps1 all to validate the project."
