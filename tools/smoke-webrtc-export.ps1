param(
    [Parameter(Mandatory = $true)]
    [string]$ExportDirectory
)

$ErrorActionPreference = "Stop"

$exportDirectory = (Resolve-Path -LiteralPath $ExportDirectory).Path
$executable = Join-Path $exportDirectory "BeanParty.exe"
$releaseDll = Join-Path $exportDirectory "libwebrtc_native.windows.template_release.x86_64.dll"

$requiredPaths = @($executable, $releaseDll)
foreach ($requiredPath in $requiredPaths) {
    if (-not (Test-Path -LiteralPath $requiredPath -PathType Leaf)) {
        throw "WebRTC export smoke prerequisite missing: $requiredPath"
    }
}

Write-Host "Running exported-build WebRTC smoke test from $exportDirectory..."
$process = Start-Process `
    -FilePath $executable `
    -ArgumentList @("--headless", "--webrtc-export-smoke") `
    -WorkingDirectory $exportDirectory `
    -Wait `
    -PassThru `
    -NoNewWindow

if ($process.ExitCode -ne 0) {
    throw "WebRTC export smoke test failed with exit code $($process.ExitCode)."
}

Write-Host "WebRTC export smoke test passed."
