$ErrorActionPreference = "Stop"

. "$PSScriptRoot/online-staging-domain.ps1"

function Assert-OnlineStagingTest {
	param(
		[string]$Name,
		[scriptblock]$Test
	)

	try {
		& $Test
		Write-Host "PASS $Name"
	}
	catch {
		Write-Host "FAIL $Name"
		Write-Host "  $_"
		$script:Failed = $true
	}
}

$Failed = $false

Assert-OnlineStagingTest "accepts railway hostname" {
	$result = Test-OnlineStagingDomain -Value "bean-party-signaling.up.railway.app"
	if (-not $result.Valid) { throw $result.Reason }
	if ($result.Hostname -ne "bean-party-signaling.up.railway.app") {
		throw "Expected lowercase hostname preservation."
	}
}

Assert-OnlineStagingTest "rejects placeholder domain" {
	$result = Test-OnlineStagingDomain -Value "YOUR-RAILWAY-DOMAIN"
	if ($result.Valid) { throw "Expected placeholder rejection." }
}

Assert-OnlineStagingTest "rejects scheme prefix" {
	$result = Test-OnlineStagingDomain -Value "https://bean-party-signaling.up.railway.app"
	if ($result.Valid) { throw "Expected scheme rejection." }
}

Assert-OnlineStagingTest "rejects path suffix" {
	$result = Test-OnlineStagingDomain -Value "bean-party-signaling.up.railway.app/v1/ice"
	if ($result.Valid) { throw "Expected path rejection." }
}

Assert-OnlineStagingTest "rejects query suffix" {
	$result = Test-OnlineStagingDomain -Value "bean-party-signaling.up.railway.app?protocol=1"
	if ($result.Valid) { throw "Expected query rejection." }
}

Assert-OnlineStagingTest "rejects whitespace" {
	$result = Test-OnlineStagingDomain -Value "bean-party-signaling.up.railway.app "
	if ($result.Valid) { throw "Expected whitespace rejection." }
}

Assert-OnlineStagingTest "rejects malformed hostname" {
	$result = Test-OnlineStagingDomain -Value "-invalid-.example"
	if ($result.Valid) { throw "Expected malformed hostname rejection." }
}

Assert-OnlineStagingTest "builds staging endpoints" {
	$endpoints = New-OnlineStagingEndpoints -Hostname "bean-party-signaling.up.railway.app"
	if ($endpoints.SignalingUrl -ne "wss://bean-party-signaling.up.railway.app/v1/signal") {
		throw "Unexpected signaling URL."
	}
	if ($endpoints.IceConfigUrl -ne "https://bean-party-signaling.up.railway.app/v1/ice") {
		throw "Unexpected ICE URL."
	}
	if ($endpoints.HealthUrl -ne "https://bean-party-signaling.up.railway.app/healthz") {
		throw "Unexpected health URL."
	}
	if ($endpoints.ReadyUrl -ne "https://bean-party-signaling.up.railway.app/readyz") {
		throw "Unexpected ready URL."
	}
}

if ($Failed) {
	Write-Error "Online staging launcher tests failed."
	exit 1
}

Write-Host "All online staging launcher tests passed."
