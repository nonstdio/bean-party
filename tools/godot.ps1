[CmdletBinding()]
param(
	[Parameter(Position = 0)]
	[ValidateSet("validate", "test", "all")]
	[string]$Task = "all"
)

$ErrorActionPreference = "Stop"
$RepoRoot = Split-Path -Parent $PSScriptRoot

function Resolve-GodotBinary {
	if (-not [string]::IsNullOrWhiteSpace($env:GODOT_BIN)) {
		return $env:GODOT_BIN
	}

	$pathCommand = Get-Command -Name "godot_console" -CommandType Application -ErrorAction SilentlyContinue
	if ($null -eq $pathCommand) {
		$pathCommand = Get-Command -Name "godot" -CommandType Application -ErrorAction SilentlyContinue
	}
	if ($null -ne $pathCommand) {
		return $pathCommand.Source
	}

	$packageRoot = Join-Path $env:LOCALAPPDATA "Microsoft\WinGet\Packages"
	if (Test-Path -LiteralPath $packageRoot -PathType Container) {
		$candidates = Get-ChildItem -LiteralPath $packageRoot -Directory -Filter "GodotEngine.GodotEngine_*" |
			ForEach-Object {
				Get-ChildItem -LiteralPath $_.FullName -Filter "Godot_v4.7-stable_win64_console.exe" -File -Recurse
			} |
			Sort-Object -Property LastWriteTime -Descending

		if ($candidates.Count -gt 0) {
			return $candidates[0].FullName
		}
	}

	throw "Godot 4.7 stable was not found. Install it with WinGet or set GODOT_BIN to the executable path."
}

function Get-ConsoleVariant {
	param(
		[Parameter(Mandatory = $true)]
		[string]$Path
	)

	if ($Path -match "_console\.exe$") {
		return $Path
	}

	$consolePath = $Path -replace "\.exe$", "_console.exe"
	if (Test-Path -LiteralPath $consolePath -PathType Leaf) {
		return $consolePath
	}

	return $Path
}

function Invoke-Godot {
	param(
		[Parameter(Mandatory = $true)]
		[string[]]$Arguments
	)

	& $script:GodotBinary @Arguments
	if ($LASTEXITCODE -ne 0) {
		throw "Godot exited with code $LASTEXITCODE while running '$Task'."
	}
}

try {
	if (-not (Test-Path -LiteralPath (Join-Path $RepoRoot "project.godot") -PathType Leaf)) {
		throw "Run this script from a checkout that contains project.godot."
	}

	$script:GodotBinary = Get-ConsoleVariant -Path (Resolve-GodotBinary)
	if (-not (Test-Path -LiteralPath $script:GodotBinary -PathType Leaf)) {
		throw "Godot executable does not exist: $script:GodotBinary"
	}

	$version = (& $script:GodotBinary --version 2>&1 | Out-String).Trim()
	$versionExitCode = $LASTEXITCODE
	if ($versionExitCode -ne 0 -or $version -notmatch "^4\.7\.stable(\.|$)") {
		throw "Bean Party requires the standard Godot 4.7 stable release. Found: $version"
	}

	function Invoke-Validation {
		Invoke-Godot -Arguments @("--headless", "--path", $RepoRoot, "--editor", "--quit")
	}

	function Invoke-Tests {
		Invoke-Godot -Arguments @("--headless", "--path", $RepoRoot, "-s", "res://addons/gut/gut_cmdln.gd", "-gconfig=res://.gutconfig.json", "-gexit")
	}

	switch ($Task) {
		"validate" { Invoke-Validation }
		"test" { Invoke-Tests }
		"all" {
			Invoke-Validation
			Invoke-Tests
		}
	}
}
catch {
	Write-Error $_
	exit 1
}
