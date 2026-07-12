[CmdletBinding()]
param(
	[Parameter(Mandatory = $true)]
	[string]$Domain,

	[Parameter(Mandatory = $true)]
	[ValidateSet("Editor", "Project", "Export")]
	[string]$Mode,

	[string]$ExecutablePath,

	[switch]$SkipHealthCheck
)

$ErrorActionPreference = "Stop"
$RepoRoot = Split-Path -Parent $PSScriptRoot

. (Join-Path $PSScriptRoot "online-staging-domain.ps1")

function Test-OnlineStagingServiceHealth {
	param(
		[Parameter(Mandatory = $true)]
		[string]$HealthUrl,

		[Parameter(Mandatory = $true)]
		[string]$ReadyUrl
	)

	$healthResponse = Invoke-WebRequest -Uri $HealthUrl -UseBasicParsing -TimeoutSec 20
	if ($healthResponse.StatusCode -ne 200) {
		throw "healthz returned HTTP $($healthResponse.StatusCode) from $HealthUrl"
	}

	$healthJson = $healthResponse.Content | ConvertFrom-Json
	if ($healthJson.status -ne "ok") {
		throw "healthz status is '$($healthJson.status)', expected 'ok'."
	}

	$readyResponse = Invoke-WebRequest -Uri $ReadyUrl -UseBasicParsing -TimeoutSec 20
	if ($readyResponse.StatusCode -ne 200) {
		throw "readyz returned HTTP $($readyResponse.StatusCode) from $ReadyUrl"
	}

	$readyJson = $readyResponse.Content | ConvertFrom-Json
	if ($readyJson.status -ne "ready") {
		throw "readyz status is '$($readyJson.status)', expected 'ready'."
	}
}

function Set-OnlineStagingProcessEnvironment {
	param(
		[Parameter(Mandatory = $true)]
		[string]$SignalingUrl,

		[Parameter(Mandatory = $true)]
		[string]$IceConfigUrl
	)

	$env:BEAN_PARTY_SIGNALING_URL = $SignalingUrl
	$env:BEAN_PARTY_ICE_CONFIG_URL = $IceConfigUrl
	$env:BEAN_PARTY_SIGNALING_PROTOCOL_VERSION = "1"
	$env:BEAN_PARTY_ONLINE_DEV_MODE = "false"
	$env:BEAN_PARTY_ALLOW_STUN_ONLY_FALLBACK = "false"
}

function Invoke-OnlineStagingLaunch {
	param(
		[Parameter(Mandatory = $true)]
		[ValidateSet("Editor", "Project", "Export")]
		[string]$LaunchMode,

		[string]$ExportExecutablePath
	)

	switch ($LaunchMode) {
		"Editor" {
			& (Join-Path $PSScriptRoot "godot.ps1") editor
		}
		"Project" {
			& (Join-Path $PSScriptRoot "godot.ps1") project
		}
		"Export" {
			if (-not (Test-Path -LiteralPath $ExportExecutablePath -PathType Leaf)) {
				throw "Executable not found: $ExportExecutablePath"
			}

			$resolvedExecutable = (Resolve-Path -LiteralPath $ExportExecutablePath).Path
			& $resolvedExecutable
		}
	}

	if ($LASTEXITCODE -ne 0) {
		throw "$LaunchMode launch failed with exit code $LASTEXITCODE."
	}
}

try {
	if (-not (Test-Path -LiteralPath (Join-Path $RepoRoot "project.godot") -PathType Leaf)) {
		throw "Run this script from a checkout that contains project.godot."
	}

	if ($Mode -eq "Export" -and [string]::IsNullOrWhiteSpace($ExecutablePath)) {
		throw "Export mode requires -ExecutablePath."
	}

	$domainResult = Test-OnlineStagingDomain -Value $Domain
	if (-not $domainResult.Valid) {
		throw $domainResult.Reason
	}

	$endpoints = New-OnlineStagingEndpoints -Hostname $domainResult.Hostname

	Write-Host "Online staging launcher"
	Write-Host "  Mode: $Mode"
	Write-Host "  Hostname: $($domainResult.Hostname)"
	Write-Host "  Signaling: $($endpoints.SignalingUrl)"
	Write-Host "  ICE config: $($endpoints.IceConfigUrl)"
	Write-Host "  Health: $($endpoints.HealthUrl)"
	Write-Host "  Readiness: $($endpoints.ReadyUrl)"
	if ($Mode -eq "Export") {
		Write-Host "  Executable: $ExecutablePath"
	}

	if (-not $SkipHealthCheck) {
		Write-Host "Checking signaling service health..."
		Test-OnlineStagingServiceHealth -HealthUrl $endpoints.HealthUrl -ReadyUrl $endpoints.ReadyUrl
		Write-Host "Health checks passed."
	}
	else {
		Write-Host "Skipping health checks (-SkipHealthCheck)."
	}

	Set-OnlineStagingProcessEnvironment `
		-SignalingUrl $endpoints.SignalingUrl `
		-IceConfigUrl $endpoints.IceConfigUrl

	Invoke-OnlineStagingLaunch -LaunchMode $Mode -ExportExecutablePath $ExecutablePath
}
catch {
	Write-Error $_
	exit 1
}
