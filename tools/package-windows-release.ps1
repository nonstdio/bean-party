param(
    [Parameter(Mandatory = $true)]
    [string]$ExportDirectory,
    [string]$ZipPath = (Join-Path (Split-Path -Parent $ExportDirectory) "BeanParty-Windows.zip")
)

$ErrorActionPreference = "Stop"

$exportDirectory = (Resolve-Path -LiteralPath $ExportDirectory).Path
$zipPath = [System.IO.Path]::GetFullPath($ZipPath)
$repoRoot = Split-Path -Parent $PSScriptRoot
$licenseOverview = Join-Path $repoRoot "LICENSE.md"
$licenseDirectory = Join-Path $repoRoot "LICENSES"
$thirdPartyNotices = Join-Path $repoRoot "THIRD_PARTY_NOTICES.md"

foreach ($requiredPath in @($licenseOverview, $licenseDirectory, $thirdPartyNotices)) {
    if (-not (Test-Path -LiteralPath $requiredPath)) {
        throw "Required release notice was not found at $requiredPath."
    }
}

Copy-Item -LiteralPath $licenseOverview -Destination (Join-Path $exportDirectory "LICENSE.md") -Force
Copy-Item -LiteralPath $thirdPartyNotices -Destination (Join-Path $exportDirectory "THIRD_PARTY_NOTICES.md") -Force
$exportLicenseDirectory = Join-Path $exportDirectory "LICENSES"
New-Item -ItemType Directory -Path $exportLicenseDirectory -Force | Out-Null
Copy-Item -Path (Join-Path $licenseDirectory "*") -Destination $exportLicenseDirectory -Force

if (Test-Path -LiteralPath $zipPath -PathType Leaf) {
    Remove-Item -LiteralPath $zipPath -Force
}

Add-Type -AssemblyName System.IO.Compression.FileSystem
[System.IO.Compression.ZipFile]::CreateFromDirectory($exportDirectory, $zipPath)

$hash = (Get-FileHash -LiteralPath $zipPath -Algorithm SHA256).Hash.ToLowerInvariant()
$checksumPath = "$zipPath.sha256"
"$hash  $(Split-Path -Leaf $zipPath)" | Out-File -FilePath $checksumPath -Encoding ascii -NoNewline

Write-Host "Created $zipPath"
Write-Host "SHA-256: $hash"
