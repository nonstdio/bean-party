[CmdletBinding()]
param(
	[Parameter(Position = 0)]
	[ValidateSet("build", "export", "check")]
	[string]$Task = "check"
)

$ErrorActionPreference = "Stop"
$RepoRoot = Split-Path -Parent $PSScriptRoot
$Source = Join-Path $RepoRoot "assets\source\standard\characters\bean-static-prototype.blend"
$Output = Join-Path $RepoRoot "assets\standard\characters\bean-static-prototype.glb"
$Script = Join-Path $RepoRoot "tools\blender\bean_static_prototype.py"

function Resolve-BlenderBinary {
	if (-not [string]::IsNullOrWhiteSpace($env:BLENDER_BIN)) {
		return $env:BLENDER_BIN
	}

	$pathCommand = Get-Command -Name "blender" -CommandType Application -ErrorAction SilentlyContinue
	if ($null -ne $pathCommand) {
		return $pathCommand.Source
	}

	$candidates = @(
		"G:\SteamLibrary\steamapps\common\Blender\blender.exe",
		"${env:ProgramFiles(x86)}\Steam\steamapps\common\Blender\blender.exe",
		"$env:ProgramFiles\Blender Foundation\Blender 5.1\blender.exe"
	)
	foreach ($candidate in $candidates) {
		if (Test-Path -LiteralPath $candidate -PathType Leaf) {
			return $candidate
		}
	}

	throw "Blender 5.1.x was not found. Set BLENDER_BIN to blender.exe."
}

function Invoke-BlenderExport {
	param(
		[Parameter(Mandatory = $true)]
		[string]$Mode,
		[Parameter(Mandatory = $true)]
		[string]$Target
	)

	$arguments = @("--background")
	if ($Mode -eq "export") {
		$arguments += $Source
	}
	$arguments += @("--python", $Script, "--", "--mode", $Mode, "--output", $Target)
	if ($Mode -eq "build") {
		$arguments += @("--source", $Source)
	}

	Remove-Item -LiteralPath $Target -Force -ErrorAction SilentlyContinue
	& $script:BlenderBinary @arguments
	if ($LASTEXITCODE -ne 0) {
		throw "Blender exited with code $LASTEXITCODE."
	}
	if (-not (Test-Path -LiteralPath $Target -PathType Leaf)) {
		throw "Blender did not create the expected export: $Target"
	}
}

$script:BlenderBinary = Resolve-BlenderBinary
$versionOutput = (& $script:BlenderBinary --version 2>&1 | Out-String).Trim()
$versionExitCode = $LASTEXITCODE
$version = ($versionOutput -split "`r?`n")[0]
if ($versionExitCode -ne 0 -or $version -notmatch "^Blender 5\.1\.") {
	throw "Standard assets currently require Blender 5.1.x. Found: $version"
}

switch ($Task) {
	"build" { Invoke-BlenderExport -Mode "build" -Target $Output }
	"export" { Invoke-BlenderExport -Mode "export" -Target $Output }
	"check" {
		if (-not (Test-Path -LiteralPath $Source -PathType Leaf)) {
			throw "Missing Blender source: $Source"
		}
		if (-not (Test-Path -LiteralPath $Output -PathType Leaf)) {
			throw "Missing committed GLB export: $Output"
		}
		$tempOutput = Join-Path ([System.IO.Path]::GetTempPath()) "bean-party-bean-static-prototype.glb"
		try {
			Invoke-BlenderExport -Mode "export" -Target $tempOutput
			$expected = (Get-FileHash -Algorithm SHA256 -LiteralPath $Output).Hash
			$actual = (Get-FileHash -Algorithm SHA256 -LiteralPath $tempOutput).Hash
			if ($expected -ne $actual) {
				throw "The committed GLB is stale. Run tools/assets.ps1 export."
			}
		}
		finally {
			Remove-Item -LiteralPath $tempOutput -Force -ErrorAction SilentlyContinue
		}
	}
}
