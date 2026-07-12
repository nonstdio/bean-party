param(
    [string]$RepoRoot = (Split-Path -Parent $PSScriptRoot),
    [string]$VersionFile = (Join-Path (Split-Path -Parent $PSScriptRoot) "config\webrtc_native.version.json")
)

$ErrorActionPreference = "Stop"

if (-not (Test-Path -LiteralPath $VersionFile -PathType Leaf)) {
    throw "WebRTC-native version pin was not found at $VersionFile."
}

$pin = Get-Content -LiteralPath $VersionFile -Raw | ConvertFrom-Json
$version = [string]$pin.version
$archiveName = [string]$pin.archive_name
$expectedSha256 = [string]$pin.archive_sha256

if ([string]::IsNullOrWhiteSpace($version) -or [string]::IsNullOrWhiteSpace($archiveName) -or [string]::IsNullOrWhiteSpace($expectedSha256)) {
    throw "WebRTC-native version pin is incomplete in $VersionFile."
}

$archive = Join-Path $env:TEMP "godot-extension-webrtc_native-$version.zip"
$url = "https://github.com/godotengine/webrtc-native/releases/download/$version/$archiveName"

Write-Host "Downloading webrtc-native $version..."
Invoke-WebRequest -Uri $url -OutFile $archive

$actualSha256 = (Get-FileHash -LiteralPath $archive -Algorithm SHA256).Hash.ToLowerInvariant()
if ($actualSha256 -ne $expectedSha256.ToLowerInvariant()) {
    throw "webrtc-native archive checksum mismatch. Expected $expectedSha256, got $actualSha256."
}

$staging = Join-Path $env:TEMP "godot-extension-webrtc_native-$version-staging"
if (Test-Path -LiteralPath $staging -PathType Container) {
    Remove-Item -LiteralPath $staging -Recurse -Force
}
New-Item -ItemType Directory -Path $staging -Force | Out-Null

Write-Host "Extracting into staging directory..."
Expand-Archive -LiteralPath $archive -DestinationPath $staging -Force

$sourceAddon = Join-Path $staging "addons\webrtc_native"
$destinationAddon = Join-Path $RepoRoot "addons\webrtc_native"
if (-not (Test-Path -LiteralPath $sourceAddon -PathType Container)) {
    throw "webrtc-native archive did not contain addons/webrtc_native."
}

New-Item -ItemType Directory -Path (Join-Path $RepoRoot "addons") -Force | Out-Null
if (Test-Path -LiteralPath $destinationAddon) {
	try {
		Remove-Item -LiteralPath $destinationAddon -Recurse -Force -ErrorAction Stop
	}
	catch {
		throw @(
			"Could not replace the existing webrtc-native install at $destinationAddon.",
			"Close Godot and any running Bean Party build, then rerun the installer.",
			$_.Exception.Message
		) -join " "
	}
}
Copy-Item -LiteralPath $sourceAddon -Destination (Join-Path $RepoRoot "addons") -Recurse -Force

$manifest = Join-Path $destinationAddon "webrtc_native.gdextension"
$nestedManifest = Join-Path $destinationAddon "webrtc_native\webrtc_native.gdextension"
if (-not (Test-Path -LiteralPath $manifest -PathType Leaf)) {
    throw "webrtc-native install did not produce $manifest."
}
if (Test-Path -LiteralPath $nestedManifest -PathType Leaf) {
    throw "Nested webrtc-native install detected at $nestedManifest."
}

$manifestMatches = @(Get-ChildItem -LiteralPath (Join-Path $RepoRoot "addons") -Recurse -Filter "webrtc_native.gdextension" -File)
if ($manifestMatches.Count -ne 1) {
    throw "Expected exactly one webrtc_native.gdextension under addons/, found $($manifestMatches.Count)."
}

Write-Host "Installed webrtc-native $version."
