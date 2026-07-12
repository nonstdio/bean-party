[CmdletBinding()]
param(
	[Parameter(Mandatory = $true)]
	[string]$Path
)

$ErrorActionPreference = "Stop"

function ConvertTo-WorkflowCommandData {
	param([AllowEmptyString()][string]$Value)

	return $Value.Replace("%", "%25").Replace("`r", "%0D").Replace("`n", "%0A")
}

function ConvertTo-WorkflowCommandProperty {
	param([AllowEmptyString()][string]$Value)

	return (ConvertTo-WorkflowCommandData -Value $Value).Replace(":", "%3A").Replace(",", "%2C")
}

function ConvertTo-MarkdownCell {
	param([AllowEmptyString()][string]$Value)

	$singleLine = $Value.Replace("`r`n", "<br>").Replace("`r", "<br>").Replace("`n", "<br>")
	return $singleLine.Replace("|", "\|")
}

function Limit-Text {
	param(
		[AllowEmptyString()][string]$Value,
		[int]$MaximumLength = 1000
	)

	if ($Value.Length -le $MaximumLength) {
		return $Value
	}

	return $Value.Substring(0, $MaximumLength - 3) + "..."
}

if (-not (Test-Path -LiteralPath $Path -PathType Leaf)) {
	Write-Warning "GUT result file was not produced: $Path"
	exit 0
}

[xml]$results = Get-Content -LiteralPath $Path -Raw
$testCases = @($results.SelectNodes("//testcase"))
$failedCases = @($results.SelectNodes("//testcase[failure]"))
$skippedCases = @($results.SelectNodes("//testcase[skipped]"))
$passedCount = $testCases.Count - $failedCases.Count - $skippedCases.Count
$statusLine = "$passedCount passed, $($failedCases.Count) failed, $($skippedCases.Count) skipped"

Write-Output "GUT results: $statusLine"

$summaryLines = @(
	"### GUT results",
	"",
	"$statusLine on $env:RUNNER_OS."
)

if ($failedCases.Count -gt 0) {
	$summaryLines += @(
		"",
		"| Test | File | Failure |",
		"| --- | --- | --- |"
	)

	foreach ($testCase in $failedCases) {
		$testName = $testCase.GetAttribute("name")
		$file = $testCase.GetAttribute("classname")
		$message = Limit-Text -Value $testCase.SelectSingleNode("failure").InnerText.Trim()

		$annotationFile = ConvertTo-WorkflowCommandProperty -Value $file
		$annotationTitle = ConvertTo-WorkflowCommandProperty -Value "GUT: $testName"
		$annotationMessage = ConvertTo-WorkflowCommandData -Value $message
		Write-Output "::error file=$annotationFile,title=$annotationTitle::$annotationMessage"

		$summaryLines += "| $(ConvertTo-MarkdownCell -Value $testName) | $(ConvertTo-MarkdownCell -Value $file) | $(ConvertTo-MarkdownCell -Value $message) |"
	}
}

if (-not [string]::IsNullOrWhiteSpace($env:GITHUB_STEP_SUMMARY)) {
	$summary = ($summaryLines -join [Environment]::NewLine) + [Environment]::NewLine
	[System.IO.File]::AppendAllText(
		$env:GITHUB_STEP_SUMMARY,
		$summary,
		[System.Text.UTF8Encoding]::new($false)
	)
}
