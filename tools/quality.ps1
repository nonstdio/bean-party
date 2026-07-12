[CmdletBinding()]
param(
	[Parameter(Position = 0)]
	[ValidateSet("check", "format")]
	[string]$Task = "check"
)

$ErrorActionPreference = "Stop"
$RepoRoot = Split-Path -Parent $PSScriptRoot

function Resolve-PythonCommand {
	$venvPython = Join-Path $RepoRoot ".venv\Scripts\python.exe"
	if (Test-Path -LiteralPath $venvPython -PathType Leaf) {
		return [pscustomobject]@{ Command = $venvPython; Prefix = @() }
	}

	$pyLauncher = Get-Command -Name "py" -CommandType Application -ErrorAction SilentlyContinue
	if ($null -ne $pyLauncher) {
		return [pscustomobject]@{ Command = $pyLauncher.Source; Prefix = @("-3") }
	}

	$python = Get-Command -Name "python" -CommandType Application -ErrorAction SilentlyContinue
	if ($null -ne $python) {
		return [pscustomobject]@{ Command = $python.Source; Prefix = @() }
	}

	throw "Python 3 was not found. Follow docs/guides/godot-setup.md to install the quality tools."
}

function Invoke-Python {
	param(
		[Parameter(Mandatory = $true)]
		[string[]]$Arguments
	)

	$command = $script:PythonCommand.Command
	$prefix = @($script:PythonCommand.Prefix)
	& $command @prefix @Arguments
	if ($LASTEXITCODE -ne 0) {
		throw "Python quality command failed with exit code $LASTEXITCODE."
	}
}

try {
	$script:PythonCommand = Resolve-PythonCommand
	Push-Location $RepoRoot
	try {
		$python = $script:PythonCommand.Command
		$pythonPrefix = @($script:PythonCommand.Prefix)
		& $python @pythonPrefix -c "import gdtoolkit"
		if ($LASTEXITCODE -ne 0) {
			throw "gdtoolkit is unavailable."
		}
		$paths = @("scripts", "minigames", "tests")
		if ($Task -eq "check") {
			Invoke-Python -Arguments (@("-m", "gdtoolkit.formatter", "--check") + $paths)
		}
		else {
			Invoke-Python -Arguments (@("-m", "gdtoolkit.formatter") + $paths)
		}
		Invoke-Python -Arguments (@("-m", "gdtoolkit.linter") + $paths)
		Invoke-Python -Arguments @("tools/check_file_sizes.py")
		Invoke-Python -Arguments @("-m", "unittest", "discover", "-s", "tools/tests", "-p", "test_*.py")
	}
	finally {
		Pop-Location
	}
}
catch {
	if ($_.Exception.Message -match "gdtoolkit") {
		Write-Error "gdtoolkit is unavailable. Install the pinned tools with '.\.venv\Scripts\python -m pip install -r requirements-dev.txt'."
	}
	else {
		Write-Error $_
	}
	exit 1
}
