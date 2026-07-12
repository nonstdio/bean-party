function Test-OnlineStagingDomain {
	param(
		[Parameter(Mandatory = $true)]
		[string]$Value
	)

	$result = [ordered]@{
		Valid = $false
		Hostname = ""
		Reason = ""
	}

	if ([string]::IsNullOrWhiteSpace($Value)) {
		$result.Reason = "Domain is required."
		return [pscustomobject]$result
	}

	$trimmed = $Value.Trim()
	if ($trimmed -ne $Value) {
		$result.Reason = "Domain must not include leading or trailing whitespace."
		return [pscustomobject]$result
	}

	if ($trimmed -match '\s') {
		$result.Reason = "Domain must not contain whitespace."
		return [pscustomobject]$result
	}

	if ($trimmed -match '://|[/?#&=%]') {
		$result.Reason = "Domain must be a hostname only. Do not include a scheme, path, or query."
		return [pscustomobject]$result
	}

	$placeholderPatterns = @(
		'YOUR[-_]?RAILWAY[-_]?DOMAIN'
		'YOUR[-_]?DOMAIN'
		'REPLACE[-_]?ME'
		'CHANGEME'
		'<[^>]+>'
	)
	foreach ($pattern in $placeholderPatterns) {
		if ($trimmed -match $pattern) {
			$result.Reason = "Domain looks like placeholder text: $trimmed"
			return [pscustomobject]$result
		}
	}

	if ($trimmed.Length -gt 253) {
		$result.Reason = "Domain is too long."
		return [pscustomobject]$result
	}

	$hostnamePattern = '^(?=.{1,253}$)(?!-)([A-Za-z0-9-]{1,63}(?<!-)\.)*[A-Za-z0-9-]{1,63}(?<!-)$'
	if ($trimmed -notmatch $hostnamePattern) {
		$result.Reason = "Domain is not a valid hostname."
		return [pscustomobject]$result
	}

	$result.Valid = $true
	$result.Hostname = $trimmed.ToLowerInvariant()
	return [pscustomobject]$result
}

function New-OnlineStagingEndpoints {
	param(
		[Parameter(Mandatory = $true)]
		[string]$Hostname
	)

	[pscustomobject]@{
		SignalingUrl = "wss://$Hostname/v1/signal"
		IceConfigUrl = "https://$Hostname/v1/ice"
		HealthUrl = "https://$Hostname/healthz"
		ReadyUrl = "https://$Hostname/readyz"
	}
}
