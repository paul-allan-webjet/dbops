#!/usr/bin/env pwsh
<#
.SYNOPSIS
Builds the dbops solution and creates a release package

.DESCRIPTION
This script:
1. Builds the .NET solution (netstandard2.0)
2. Publishes all dependencies
3. Copies PowerShell module files
4. Updates configuration files
5. Creates the dbops-release directory ready for deployment

.PARAMETER Version
Optional version number to set in the module manifest (e.g., "0.9.4")

.EXAMPLE
./build-release.ps1

.EXAMPLE
./build-release.ps1 -Version "0.9.4"
#>

[CmdletBinding()]
param(
    [string]$Version
)

$ErrorActionPreference = 'Stop'
$PSScriptRoot = Split-Path -Parent $MyInvocation.MyCommand.Path

Write-Host "=== DBOps Release Build Script ===" -ForegroundColor Cyan
Write-Host ""

# Define paths
$sourceDir = Join-Path $PSScriptRoot "src"
$solutionFile = Join-Path $sourceDir "DBOps.sln"
$releaseDir = Join-Path $PSScriptRoot "dbops-release"
$tempPublishDir = Join-Path ([System.IO.Path]::GetTempPath()) "dbops-publish-temp"

# Clean up temp and release directories
Write-Host "Cleaning directories..." -ForegroundColor Yellow
if (Test-Path $releaseDir) {
    Remove-Item $releaseDir -Recurse -Force
}
if (Test-Path $tempPublishDir) {
    Remove-Item $tempPublishDir -Recurse -Force
}
New-Item -ItemType Directory -Path $releaseDir | Out-Null
New-Item -ItemType Directory -Path $tempPublishDir | Out-Null

# Build the solution
Write-Host "Building .NET solution..." -ForegroundColor Yellow
Push-Location $sourceDir
try {
    # Clean build
    dotnet clean $solutionFile -c Release | Out-Null
    
    # Build only the core and sqlserver projects (excluding tests which don't support netstandard2.0)
    dotnet build (Join-Path $sourceDir "dbops-core/dbops-core.csproj") -c Release -f netstandard2.0
    if ($LASTEXITCODE -ne 0) {
        throw "Build of dbops-core failed with exit code $LASTEXITCODE"
    }
    
    dotnet build (Join-Path $sourceDir "dbops-sqlserver/dbops-sqlserver.csproj") -c Release -f netstandard2.0
    if ($LASTEXITCODE -ne 0) {
        throw "Build of dbops-sqlserver failed with exit code $LASTEXITCODE"
    }
    
    # Publish with all dependencies
    Write-Host "Publishing dbops-sqlserver with dependencies..." -ForegroundColor Yellow
    dotnet publish (Join-Path $sourceDir "dbops-sqlserver/dbops-sqlserver.csproj") `
        -c Release `
        -f netstandard2.0 `
        -o $tempPublishDir `
        --self-contained false
    
    if ($LASTEXITCODE -ne 0) {
        throw "Publish failed with exit code $LASTEXITCODE"
    }
}
finally {
    Pop-Location
}

# Create directory structure in release
Write-Host "Creating release directory structure..." -ForegroundColor Yellow
$directories = @(
    "bin/lib/netstandard2.0",
    "functions",
    "internal/functions",
    "internal/classes",
    "internal/json",
    "internal/xml"
)

foreach ($dir in $directories) {
    New-Item -ItemType Directory -Path (Join-Path $releaseDir $dir) -Force | Out-Null
}

# Copy published assemblies
Write-Host "Copying assemblies and dependencies..." -ForegroundColor Yellow
$targetLibDir = Join-Path $releaseDir "bin/lib/netstandard2.0"

# Copy all DLLs from publish directory
Get-ChildItem -Path $tempPublishDir -Filter "*.dll" | ForEach-Object {
    Copy-Item $_.FullName -Destination $targetLibDir
}

# Replace Microsoft.Data.SqlClient.dll with the unix-specific version
Write-Host "Replacing with unix-specific Microsoft.Data.SqlClient.dll..." -ForegroundColor Yellow
$unixSqlClientPath = Join-Path $HOME ".nuget/packages/microsoft.data.sqlclient/5.2.2/runtimes/unix/lib/netstandard2.0/Microsoft.Data.SqlClient.dll"
if (Test-Path $unixSqlClientPath) {
    Copy-Item $unixSqlClientPath -Destination $targetLibDir -Force
    Write-Host "  ✓ Unix-specific SqlClient copied" -ForegroundColor Green
} else {
    Write-Warning "Unix-specific Microsoft.Data.SqlClient.dll not found at $unixSqlClientPath"
}

# Copy PowerShell files
Write-Host "Copying PowerShell module files..." -ForegroundColor Yellow

# Copy root module files
Copy-Item (Join-Path $PSScriptRoot "dbops.psm1") -Destination $releaseDir
Copy-Item (Join-Path $PSScriptRoot "dbops.psd1") -Destination $releaseDir
Copy-Item (Join-Path $PSScriptRoot "license.txt") -Destination $releaseDir -ErrorAction SilentlyContinue

# Copy functions
Get-ChildItem (Join-Path $PSScriptRoot "functions") -Filter "*.ps1" | ForEach-Object {
    Copy-Item $_.FullName -Destination (Join-Path $releaseDir "functions")
}

# Copy internal functions
Get-ChildItem (Join-Path $PSScriptRoot "internal/functions") -Filter "*.ps1" | ForEach-Object {
    Copy-Item $_.FullName -Destination (Join-Path $releaseDir "internal/functions")
}

# Copy internal classes
Get-ChildItem (Join-Path $PSScriptRoot "internal/classes") -Filter "*.ps1" | ForEach-Object {
    Copy-Item $_.FullName -Destination (Join-Path $releaseDir "internal/classes")
}

# Copy JSON files
Get-ChildItem (Join-Path $PSScriptRoot "internal/json") -Filter "*.json" | ForEach-Object {
    Copy-Item $_.FullName -Destination (Join-Path $releaseDir "internal/json")
}

# Copy XML files
Get-ChildItem (Join-Path $PSScriptRoot "internal/xml") -Filter "*.ps1xml" | ForEach-Object {
    Copy-Item $_.FullName -Destination (Join-Path $releaseDir "internal/xml")
}

# Copy bin/deploy.ps1 and mail_template.htm
$binDir = Join-Path $releaseDir "bin"
if (Test-Path (Join-Path $PSScriptRoot "bin/deploy.ps1")) {
    Copy-Item (Join-Path $PSScriptRoot "bin/deploy.ps1") -Destination $binDir
}
if (Test-Path (Join-Path $PSScriptRoot "bin/mail_template.htm")) {
    Copy-Item (Join-Path $PSScriptRoot "bin/mail_template.htm") -Destination $binDir
}

# Update version if specified
if ($Version) {
    Write-Host "Updating version to $Version..." -ForegroundColor Yellow
    $psd1Path = Join-Path $releaseDir "dbops.psd1"
    $psd1Content = Get-Content $psd1Path -Raw
    $psd1Content = $psd1Content -replace "ModuleVersion\s*=\s*'[^']*'", "ModuleVersion = '$Version'"
    # Generate new GUID for release version to avoid PowerShell module caching issues
    $newGuid = [guid]::NewGuid().ToString()
    $psd1Content = $psd1Content -replace "GUID\s*=\s*'[^']*'", "GUID = '$newGuid'"
    Set-Content -Path $psd1Path -Value $psd1Content -NoNewline
    Write-Host "  ✓ Version updated in dbops.psd1" -ForegroundColor Green
    Write-Host "  ✓ New GUID generated: $newGuid" -ForegroundColor Green
}

# Clean up temp directory
Write-Host "Cleaning up temporary files..." -ForegroundColor Yellow
Remove-Item $tempPublishDir -Recurse -Force

# Display summary
Write-Host ""
Write-Host "=== Build Complete ===" -ForegroundColor Green
Write-Host ""
Write-Host "Release directory: $releaseDir" -ForegroundColor Cyan

# Count files and calculate size
$dllCount = (Get-ChildItem (Join-Path $releaseDir "bin/lib/netstandard2.0") -Filter "*.dll").Count
$totalSize = (Get-ChildItem $releaseDir -Recurse -File | Measure-Object -Property Length -Sum).Sum / 1MB

Write-Host "DLLs: $dllCount" -ForegroundColor Cyan
Write-Host "Total size: $($totalSize.ToString('0.0')) MB" -ForegroundColor Cyan
Write-Host ""
Write-Host "To test the module, run:" -ForegroundColor Yellow
Write-Host "  Import-Module $releaseDir/dbops.psd1 -Force" -ForegroundColor White
Write-Host ""
