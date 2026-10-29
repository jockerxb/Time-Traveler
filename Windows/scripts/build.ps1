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
$helperProject = Join-Path $repoRoot "Windows/TimeTraveler.Helper/TimeTraveler.Helper.csproj"

New-Item -ItemType Directory -Force -Path $OutputRoot | Out-Null

foreach ($runtime in @("win-x64", "win-arm64")) {
    $publish = Join-Path $OutputRoot $runtime
    dotnet publish $project -c $Configuration -r $runtime --self-contained true `
        -p:PublishSingleFile=true -p:IncludeNativeLibrariesForSelfExtract=true `
        -p:DebugType=None -p:DebugSymbols=false -o $publish
    if ($LASTEXITCODE -ne 0) { throw "dotnet publish failed for $runtime" }

    $helperPublish = Join-Path $OutputRoot "$runtime-helper"
    dotnet publish $helperProject -c $Configuration -r $runtime --self-contained true `
        -p:PublishSingleFile=true -p:IncludeNativeLibrariesForSelfExtract=true `
        -p:DebugType=None -p:DebugSymbols=false -o $helperPublish
    if ($LASTEXITCODE -ne 0) { throw "helper publish failed for $runtime" }
    Copy-Item (Join-Path $helperPublish "TimeTraveler.Helper.exe") (Join-Path $publish "TimeTraveler.Helper.exe") -Force
    Copy-Item (Join-Path $repoRoot "Windows/README.md") (Join-Path $publish "README.md") -Force
    Copy-Item (Join-Path $repoRoot "Windows/README_EN.md") (Join-Path $publish "README_EN.md") -Force
    Copy-Item (Join-Path $repoRoot "LICENSE") (Join-Path $publish "LICENSE") -Force
    Copy-Item (Join-Path $repoRoot "Windows/THIRD_PARTY_NOTICES.md") (Join-Path $publish "THIRD_PARTY_NOTICES.md") -Force

    $zip = Join-Path $OutputRoot "Time-Traveler-Windows-$($runtime.Replace('win-', ''))-portable.zip"
    if (Test-Path $zip) { Remove-Item $zip -Force }
    Compress-Archive -Path (Join-Path $publish "*") -DestinationPath $zip -CompressionLevel Optimal
}

Write-Host "Windows packages are ready in $OutputRoot"
