[CmdletBinding()]
param(
    [ValidateSet("VerifyEnv", "Pack")]
    [string]$Mode = "VerifyEnv",

    [string]$RawBinPath,

    [string]$OutputPath,

    [string]$BleName = "HINK213-CLOCK",

    [switch]$DryRun
)

$ErrorActionPreference = "Stop"

function Resolve-FullPath {
    param([Parameter(Mandatory = $true)][string]$Path)

    return [System.IO.Path]::GetFullPath($Path)
}

function Assert-File {
    param(
        [Parameter(Mandatory = $true)][string]$Path,
        [Parameter(Mandatory = $true)][string]$Label
    )

    if (-not (Test-Path -LiteralPath $Path -PathType Leaf)) {
        throw "$Label not found: $Path"
    }

    Write-Host "[OK] $Label`: $Path"
}

function Assert-Directory {
    param(
        [Parameter(Mandatory = $true)][string]$Path,
        [Parameter(Mandatory = $true)][string]$Label
    )

    if (-not (Test-Path -LiteralPath $Path -PathType Container)) {
        throw "$Label not found: $Path"
    }

    Write-Host "[OK] $Label`: $Path"
}

function Get-FileSha256 {
    param([Parameter(Mandatory = $true)][string]$Path)

    return (Get-FileHash -LiteralPath $Path -Algorithm SHA256).Hash.ToUpperInvariant()
}

$scriptRoot = Split-Path -Parent $MyInvocation.MyCommand.Path
$repoRoot = Resolve-FullPath (Join-Path $scriptRoot "..")
$expectedRepoRoot = Resolve-FullPath "D:\EINK\Clock"

$gitRoot = (& git -C $repoRoot rev-parse --show-toplevel 2>$null).Trim()
if ($LASTEXITCODE -ne 0) {
    throw "Cannot resolve Git root from $repoRoot"
}

$normalizedGitRoot = Resolve-FullPath ($gitRoot -replace "/", "\")
if ($normalizedGitRoot -ne $repoRoot -or $repoRoot -ne $expectedRepoRoot) {
    throw "SAI PROJECT/WORKSPACE: expected $expectedRepoRoot, found $normalizedGitRoot"
}

$profilePath = Join-Path $repoRoot "tools\harness\eink-profile.json"
$bootstrapPath = Join-Path $repoRoot "tools\bootstrap-hink213-clock22-base.ps1"
$packerPath = Join-Path $repoRoot "tools\pack-hink.ps1"
$artifactPolicyPath = Join-Path $repoRoot "tools\harness\artifact-policy.ps1"
$manifestPath = Join-Path $repoRoot "tools\HINK_GOLDEN_TEMPLATE_MANIFEST.json"
$templatePath = Join-Path $repoRoot "tools\packages\HINK213_CLOCK_CONNECT_GOOD_FULL_256KB.bin"
$canonicalSourcePath = Join-Path $repoRoot "firmware\active\HINK213_CLOCK_22_BASE"
$sdkRoot = "D:\EINK\DA14585_SDK_6.0.22.1401"
$sdkProjectPath = Join-Path $sdkRoot "projects\target_apps\ble_examples\HINK213_CLOCK_22_BASE\Keil_5\ble_app_peripheral.uvprojx"
$keilPath = "C:\Users\NHAT THIEN\AppData\Local\Keil_v5\UV4\UV4.exe"
$compilerPath = "C:\Users\NHAT THIEN\AppData\Local\Keil_v5\ARM\ARMCLANG\Bin\armclang.exe"

Assert-File -Path $profilePath -Label "Harness profile"
Assert-File -Path $bootstrapPath -Label "Canonical-to-SDK bootstrap"
Assert-File -Path $packerPath -Label "HINK packer"
Assert-File -Path $artifactPolicyPath -Label "Artifact policy"
Assert-File -Path $manifestPath -Label "Golden template manifest"
Assert-File -Path $templatePath -Label "Golden 256KB template"
Assert-Directory -Path $canonicalSourcePath -Label "Canonical firmware source"
Assert-Directory -Path $sdkRoot -Label "DA14585 SDK 6.0.22.1401"
Assert-File -Path $sdkProjectPath -Label "Keil DA14585 project"
Assert-File -Path $keilPath -Label "Keil uVision"
Assert-File -Path $compilerPath -Label "ARMCLANG compiler"

$manifest = Get-Content -LiteralPath $manifestPath -Raw | ConvertFrom-Json
$expectedTemplateHash = [string]$manifest.SHA256
$actualTemplateHash = Get-FileSha256 -Path $templatePath
if ($actualTemplateHash -ne $expectedTemplateHash.ToUpperInvariant()) {
    throw "Golden template SHA256 mismatch: expected $expectedTemplateHash, actual $actualTemplateHash"
}

$templateSize = (Get-Item -LiteralPath $templatePath).Length
if ($templateSize -ne 262144) {
    throw "Golden template size must be 262144 bytes, actual $templateSize"
}

Write-Host "[OK] Golden template SHA256: $actualTemplateHash"
Write-Host "[OWNER_GATE] SmartSnippets Toolbox + J-Link must be installed and verified manually."

if ($Mode -eq "VerifyEnv") {
    Write-Host "ENVIRONMENT PASS"
    exit 0
}

if ([string]::IsNullOrWhiteSpace($RawBinPath)) {
    throw "Pack mode requires -RawBinPath"
}
if ([string]::IsNullOrWhiteSpace($OutputPath)) {
    throw "Pack mode requires -OutputPath"
}
if (-not [System.IO.Path]::IsPathRooted($RawBinPath)) {
    throw "RawBinPath must be absolute: $RawBinPath"
}
if (-not [System.IO.Path]::IsPathRooted($OutputPath)) {
    throw "OutputPath must be absolute: $OutputPath"
}

$rawPath = Resolve-FullPath $RawBinPath
$packedPath = Resolve-FullPath $OutputPath
Assert-File -Path $rawPath -Label "Raw firmware BIN"

$rawSize = (Get-Item -LiteralPath $rawPath).Length
if ($rawSize -gt 65528) {
    throw "Raw BIN exceeds 65528-byte harness limit: $rawSize"
}

$outputParent = Split-Path -Parent $packedPath
Assert-Directory -Path $outputParent -Label "Packed output directory"

$rawHash = Get-FileSha256 -Path $rawPath
Write-Host "[OK] Raw BIN size: $rawSize"
Write-Host "[OK] Raw BIN SHA256: $rawHash"

if ($DryRun) {
    Write-Host "[DRY_RUN] Would run pack-hink.ps1 with name '$BleName'."
    Write-Host "[DRY_RUN] Packed output: $packedPath"
    Write-Host "PACK DRY-RUN PASS"
    exit 0
}

& powershell.exe -NoProfile -ExecutionPolicy Bypass -File $packerPath `
    -Raw $rawPath `
    -Out $packedPath `
    -Name $BleName
if ($LASTEXITCODE -ne 0) {
    throw "pack-hink.ps1 failed with exit code $LASTEXITCODE"
}

& powershell.exe -NoProfile -ExecutionPolicy Bypass -File $artifactPolicyPath `
    -RawBinPath $rawPath `
    -PackedBinPath $packedPath `
    -RequirePacked
if ($LASTEXITCODE -ne 0) {
    throw "Artifact policy failed with exit code $LASTEXITCODE"
}

$packedSize = (Get-Item -LiteralPath $packedPath).Length
$packedHash = Get-FileSha256 -Path $packedPath
Write-Host "[OK] Packed BIN size: $packedSize"
Write-Host "[OK] Packed BIN SHA256: $packedHash"
Write-Host "PACK PASS"
Write-Host "[OWNER_GATE] Burn and SPI Verify each board with SmartSnippets Toolbox."
Write-Host "[OWNER_GATE] Cold boot, BLE, and e-ink visual checks remain physical gates."
