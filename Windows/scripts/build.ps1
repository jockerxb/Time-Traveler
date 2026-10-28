param(
    [string]$Configuration = "Release",
    [string]$OutputRoot = ""
)

$ErrorActionPreference = "Stop"
$repoRoot = Resolve-Path (Join-Path $PSScriptRoot "../..")
if ([string]::IsNullOrWhiteSpace($OutputRoot)) {
    $OutputRoot = Join-Path $repoRoot "Windows/artifacts"
}
$OutputRoot = [System.IO.Path]::GetFullPath($OutputRoot)
$project = Join-Path $repoRoot "Windows/TimeTraveler.Windows/TimeTraveler.Windows.csproj"

New-Item -ItemType Directory -Force -Path $OutputRoot | Out-Null

foreach ($runtime in @("win-x64", "win-arm64")) {
    $publish = Join-Path $OutputRoot $runtime
    dotnet publish $project -c $Configuration -r $runtime --self-contained true `
        -p:PublishSingleFile=true -p:IncludeNativeLibrariesForSelfExtract=true `
        -p:DebugType=None -p:DebugSymbols=false -o $publish
    if ($LASTEXITCODE -ne 0) { throw "dotnet publish failed for $runtime" }

    $zip = Join-Path $OutputRoot "Time-Traveler-Windows-$($runtime.Replace('win-', ''))-portable.zip"
    if (Test-Path $zip) { Remove-Item $zip -Force }
    Compress-Archive -Path (Join-Path $publish "*") -DestinationPath $zip -CompressionLevel Optimal
}

Write-Host "Windows packages are ready in $OutputRoot"
