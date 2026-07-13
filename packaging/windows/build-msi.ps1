[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [string]$Version,

    [Parameter(Mandatory = $true)]
    [string]$MsiVersion,

    [Parameter(Mandatory = $true)]
    [string]$SourceDir,

    [Parameter(Mandatory = $true)]
    [string]$OutDir
)

$ErrorActionPreference = 'Stop'

if ($MsiVersion -notmatch '^\d+\.\d+\.\d+$') {
    throw "MSI version must use major.minor.build: $MsiVersion"
}

if (-not (Test-Path -LiteralPath $SourceDir -PathType Container)) {
    throw "Windows release directory not found: $SourceDir"
}

$resolvedSource = (Resolve-Path -LiteralPath $SourceDir).Path
$executable = Join-Path $resolvedSource 'desktop.exe'
if (-not (Test-Path -LiteralPath $executable -PathType Leaf)) {
    throw "Windows release executable not found: $executable"
}

if (-not (Get-Command wix -ErrorAction SilentlyContinue)) {
    throw 'WiX Toolset is required. Install WiX 5.0.2 with: dotnet tool install --global wix --version 5.0.2'
}

New-Item -ItemType Directory -Force -Path $OutDir | Out-Null
$resolvedOut = (Resolve-Path -LiteralPath $OutDir).Path
$output = Join-Path $resolvedOut "MirrorStages-Desktop-$Version-windows-x64.msi"
$definition = Join-Path $PSScriptRoot 'Package.wxs'

& wix build `
    -arch x64 `
    -d "SourceDir=$resolvedSource" `
    -d "MsiVersion=$MsiVersion" `
    -o $output `
    $definition

if ($LASTEXITCODE -ne 0) {
    throw "WiX failed with exit code $LASTEXITCODE"
}

if (-not (Test-Path -LiteralPath $output -PathType Leaf)) {
    throw "WiX did not create the expected MSI: $output"
}

Write-Output "built: $output"
