param(
    [Parameter(Mandatory = $true)]
    [string]$ExportDirectory,
    [string]$ZipPath = (Join-Path (Split-Path -Parent $ExportDirectory) "BeanParty-Windows.zip")
)

$ErrorActionPreference = "Stop"

$exportDirectory = (Resolve-Path -LiteralPath $ExportDirectory).Path
$zipPath = [System.IO.Path]::GetFullPath($ZipPath)

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
