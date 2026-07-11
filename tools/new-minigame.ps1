[CmdletBinding()]
param(
	[Parameter(Mandatory = $true)]
	[ValidatePattern("^[a-z0-9]+(?:-[a-z0-9]+)*$")]
	[string]$Slug,

	[Parameter(Mandatory = $true)]
	[ValidateNotNullOrEmpty()]
	[ValidateScript({ $_ -notmatch '["\\\r\n]' })]
	[string]$DisplayName
)

$ErrorActionPreference = "Stop"
$RepoRoot = Split-Path -Parent $PSScriptRoot
$TemplateRoot = Join-Path $RepoRoot "minigames\_template"
$TargetRoot = Join-Path $RepoRoot "minigames\$Slug"

if (-not (Test-Path -LiteralPath $TemplateRoot -PathType Container)) {
	throw "Minigame template was not found: $TemplateRoot"
}
if (Test-Path -LiteralPath $TargetRoot) {
	throw "A minigame folder already exists: $TargetRoot"
}

Copy-Item -LiteralPath $TemplateRoot -Destination $TargetRoot -Recurse
$ScriptSlug = $Slug.Replace("-", "_")
$NodeName = (($Slug -split "-") | ForEach-Object {
	if ($_.Length -eq 0) { return "" }
	$_.Substring(0, 1).ToUpperInvariant() + $_.Substring(1)
}) -join ""
$Utf8NoBom = New-Object System.Text.UTF8Encoding($false)

Get-ChildItem -LiteralPath $TargetRoot -Recurse -File -Filter "*.tmpl" | ForEach-Object {
	$content = [System.IO.File]::ReadAllText($_.FullName)
	$content = $content.Replace("__SLUG__", $Slug)
	$content = $content.Replace("__DISPLAY_NAME__", $DisplayName)
	$content = $content.Replace("__SCRIPT_SLUG__", $ScriptSlug)
	$content = $content.Replace("__NODE_NAME__", $NodeName)
	$outputPath = $_.FullName.Substring(0, $_.FullName.Length - ".tmpl".Length)
	if ($outputPath.EndsWith("scripts\main.gd")) {
		$outputPath = Join-Path (Split-Path -Parent $outputPath) "$ScriptSlug.gd"
	}
	[System.IO.File]::WriteAllText($outputPath, $content, $Utf8NoBom)
	Remove-Item -LiteralPath $_.FullName
}

Write-Host "Created minigame scaffold at minigames/$Slug"
