param(
    [Parameter(Mandatory = $true)][string]$AppExecutable,
    [Parameter(Mandatory = $true)][string]$ProbeExecutable,
    [Parameter(Mandatory = $true)][string]$HelperExecutable,
    [string]$ResultDirectory = ""
)

$ErrorActionPreference = "Stop"
if ([string]::IsNullOrWhiteSpace($ResultDirectory)) {
    $ResultDirectory = Join-Path $PSScriptRoot "../test-results"
}
$ResultDirectory = [System.IO.Path]::GetFullPath($ResultDirectory)
New-Item -ItemType Directory -Force -Path $ResultDirectory | Out-Null

$originalZone = (tzutil /g).Trim()
if ([string]::IsNullOrWhiteSpace($originalZone)) { throw "Could not read the original Windows time zone." }
Set-Content -Path (Join-Path $ResultDirectory "original-time-zone.txt") -Value $originalZone

try {
    $startInfo = [System.Diagnostics.ProcessStartInfo]::new($AppExecutable)
    $startInfo.UseShellExecute = $false
    $startInfo.ArgumentList.Add($ProbeExecutable)
    $startInfo.ArgumentList.Add($HelperExecutable)
    $startInfo.ArgumentList.Add($ResultDirectory)
    $process = [System.Diagnostics.Process]::Start($startInfo)
    if (-not $process.WaitForExit(180000)) { throw "Integration harness exceeded the three-minute limit." }
    if ($process.ExitCode -ne 0) {
        $summary = Join-Path $ResultDirectory "integration-result.json"
        if (Test-Path $summary) { Get-Content $summary }
        throw "Time Traveler integration test failed with exit code $($process.ExitCode)."
    }
}
finally {
    $currentZone = (tzutil /g).Trim()
    if ($currentZone -ne $originalZone) {
        tzutil /s $originalZone
        if ($LASTEXITCODE -ne 0) { throw "Emergency time-zone restore failed." }
    }
}

$restoredZone = (tzutil /g).Trim()
if ($restoredZone -ne $originalZone) {
    throw "System time zone is '$restoredZone'; expected '$originalZone'."
}
Get-Content (Join-Path $ResultDirectory "integration-result.json")
