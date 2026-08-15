[CmdletBinding()]
param(
    [ValidateSet('Plan', 'Release')]
    [string]$Mode = 'Plan',

    [Parameter(Mandatory = $true)]
    [string]$DeviceName,

    [string]$PackedBin,
    [string]$ProfilePath = (Join-Path $PSScriptRoot '..\tools\harness\eink-profile.json')
)

$ErrorActionPreference = 'Stop'

function Write-Blocked {
    param([Parameter(Mandatory = $true)][string]$Reason)
    Write-Output 'EINK HARNESS: BLOCKED'
    Write-Output 'ACTION: RELEASE-PIPELINE'
    Write-Output "REASON: $Reason"
}

function Invoke-GitText {
    param([Parameter(Mandatory = $true)][string[]]$Arguments)
    $previous = $ErrorActionPreference
    try {
        $ErrorActionPreference = 'Continue'
        $output = @(& git @Arguments 2>$null | ForEach-Object { $_.ToString() })
        $exitCode = $LASTEXITCODE
    }
    finally {
        $ErrorActionPreference = $previous
    }
    if ($exitCode -ne 0) { return $null }
    return ($output -join "`n").Trim()
}

function Invoke-Child {
    param(
        [Parameter(Mandatory = $true)][string]$Script,
        [string[]]$Arguments = @()
    )
    $previous = $ErrorActionPreference
    try {
        $ErrorActionPreference = 'Continue'
        $output = @(& powershell.exe -NoProfile -ExecutionPolicy Bypass -File $Script @Arguments 2>&1 | ForEach-Object { $_.ToString() })
        $exitCode = $LASTEXITCODE
    }
    finally {
        $ErrorActionPreference = $previous
    }
    [pscustomobject]@{ ExitCode = $exitCode; Output = $output }
}

function Get-Sha256Hex {
    param([Parameter(Mandatory = $true)][string]$Path)
    $stream = $null
    $sha = $null
    try {
        $stream = [System.IO.File]::OpenRead($Path)
        $sha = [System.Security.Cryptography.SHA256]::Create()
        $bytes = $sha.ComputeHash($stream)
        return ([System.BitConverter]::ToString($bytes)).Replace('-', '').ToUpperInvariant()
    }
    finally {
        if ($null -ne $sha) { $sha.Dispose() }
        if ($null -ne $stream) { $stream.Dispose() }
    }
}

function Get-OutputValue {
    param([string[]]$Output, [string]$Key)
    $line = @($Output | Where-Object { $_ -match ('^' + [regex]::Escape($Key) + ':\s*') } | Select-Object -Last 1)
    if ($line.Count -eq 0) { return $null }
    return ($line[0] -replace ('^' + [regex]::Escape($Key) + ':\s*'), '').Trim()
}

$profile = Get-Content -LiteralPath $ProfilePath -Raw | ConvertFrom-Json
$expectedWorkspace = [System.IO.Path]::GetFullPath([string]$profile.workspace.canonicalPath).TrimEnd('\')
$actualWorkspace = [System.IO.Path]::GetFullPath((Get-Location).Path).TrimEnd('\')
if (-not [string]::Equals($actualWorkspace, $expectedWorkspace, [System.StringComparison]::OrdinalIgnoreCase)) {
    Write-Output 'SAI PROJECT/WORKSPACE'
    exit 1
}

$gitRoot = Invoke-GitText -Arguments @('rev-parse', '--show-toplevel')
if ([string]::IsNullOrWhiteSpace($gitRoot) -or
    -not [string]::Equals(([System.IO.Path]::GetFullPath($gitRoot).TrimEnd('\')), $expectedWorkspace, [System.StringComparison]::OrdinalIgnoreCase)) {
    Write-Output 'SAI PROJECT/WORKSPACE'
    exit 1
}

$branch = Invoke-GitText -Arguments @('branch', '--show-current')
$head = Invoke-GitText -Arguments @('rev-parse', 'HEAD')
$origin = Invoke-GitText -Arguments @('remote', 'get-url', 'origin')
if ([string]::IsNullOrWhiteSpace($branch) -or [string]::IsNullOrWhiteSpace($head)) {
    Write-Blocked -Reason 'BRANCH_OR_HEAD_MISSING'
    exit 1
}
if ($origin -ne [string]$profile.workspace.origin) {
    Write-Blocked -Reason 'WRONG_REMOTE'
    exit 1
}

$trackedDirty = @(& git status --porcelain=v1 --untracked-files=all 2>$null | Where-Object { $_ -and -not $_.StartsWith('?? ') })
if ($trackedDirty.Count -gt 0) {
    Write-Blocked -Reason 'DIRTY_TRACKED_TREE'
    $trackedDirty | ForEach-Object { Write-Output "DIRTY: $_" }
    exit 1
}

$stamp = Get-Date -Format 'yyyyMMdd_HHmmss'
$evidenceDir = Join-Path ([string]$profile.releasePipeline.evidenceRoot) $stamp
[void](New-Item -ItemType Directory -Path $evidenceDir -Force)

if ([string]::IsNullOrWhiteSpace($PackedBin)) {
    $safeName = ($DeviceName -replace '[^A-Za-z0-9_-]', '_')
    $PackedBin = Join-Path ([string]$profile.releasePipeline.packedRoot) ("${safeName}_${stamp}.bin")
}
$packedPath = [System.IO.Path]::GetFullPath($PackedBin)
$packedRoot = [System.IO.Path]::GetFullPath([string]$profile.releasePipeline.packedRoot).TrimEnd('\') + '\'
if (-not $packedPath.StartsWith($packedRoot, [System.StringComparison]::OrdinalIgnoreCase)) {
    Write-Blocked -Reason 'PACKED_BIN_OUTSIDE_RELEASE_PACKED_ROOT'
    exit 1
}

Write-Output '=== RELEASE BUILD ==='
$build = Invoke-Child -Script (Join-Path $PSScriptRoot 'eink.ps1') -Arguments @('build')
$build.Output | ForEach-Object { Write-Output $_ }
if ($build.ExitCode -ne 0 -or -not ($build.Output -match 'NEXT_STATE: RAW_FIRMWARE_VERIFIED')) {
    Write-Blocked -Reason 'BUILD_FAILED'
    exit 1
}
$rawBin = Get-OutputValue -Output $build.Output -Key 'RAW_BIN'
$rawHash = Get-OutputValue -Output $build.Output -Key 'RAW_SHA256'
if ([string]::IsNullOrWhiteSpace($rawBin) -or -not (Test-Path -LiteralPath $rawBin -PathType Leaf)) {
    Write-Blocked -Reason 'BUILD_RAW_BIN_MISSING'
    exit 1
}

Write-Output ''
Write-Output '=== RELEASE PACK ==='
$packer = Join-Path ([string]$profile.workspace.canonicalPath) ([string]$profile.toolchain.packerScript)
$pack = Invoke-Child -Script $packer -Arguments @('-Raw', $rawBin, '-Out', $packedPath, '-Name', $DeviceName)
$pack.Output | ForEach-Object { Write-Output $_ }
if ($pack.ExitCode -ne 0 -or -not (Test-Path -LiteralPath $packedPath -PathType Leaf)) {
    Write-Blocked -Reason 'PACK_FAILED'
    exit 1
}
$packedFile = Get-Item -LiteralPath $packedPath
if ($packedFile.Length -ne [int64]$profile.artifactPolicy.packedSpiBytes) {
    Write-Blocked -Reason "PACKED_BIN_SIZE_$($packedFile.Length)"
    exit 1
}
$packedHash = Get-Sha256Hex -Path $packedPath

Write-Output ''
Write-Output '=== RELEASE IMAGE ==='
Write-Output "DEVICE_NAME: $DeviceName"
Write-Output "RAW_BIN: $rawBin"
Write-Output "RAW_SHA256: $rawHash"
Write-Output "PACKED_BIN: $packedPath"
Write-Output "PACKED_SIZE: $($packedFile.Length)"
Write-Output "PACKED_SHA256: $packedHash"

$plan = Invoke-Child -Script (Join-Path $PSScriptRoot 'eink-spi-burn.ps1') -Arguments @('-Mode', 'Plan', '-PackedBin', $packedPath, '-ProfilePath', $ProfilePath)
$plan.Output | ForEach-Object { Write-Output $_ }
if ($plan.ExitCode -ne 0 -or -not ($plan.Output -match 'NEXT_STATE: OWNER_BURN_CONFIRMATION_REQUIRED')) {
    Write-Blocked -Reason 'BURN_PLAN_FAILED'
    exit 1
}

if ($Mode -eq 'Plan') {
    $summary = @(
        'ACTION: RELEASE-PIPELINE-PLAN',
        "BRANCH: $branch",
        "HEAD: $head",
        "DEVICE_NAME: $DeviceName",
        "RAW_BIN: $rawBin",
        "RAW_SHA256: $rawHash",
        "PACKED_BIN: $packedPath",
        "PACKED_SIZE: $($packedFile.Length)",
        "PACKED_SHA256: $packedHash",
        'DESTRUCTIVE_ACTION: NOT_RUN',
        'NEXT_STATE: OWNER_RELEASE_BURN_CONFIRMATION_REQUIRED'
    )
    [System.IO.File]::WriteAllLines((Join-Path $evidenceDir 'release-plan.txt'), $summary, [System.Text.UTF8Encoding]::new($false))
    Write-Output ''
    Write-Output 'EINK HARNESS: PASS'
    Write-Output 'ACTION: RELEASE-PIPELINE-PLAN'
    Write-Output "EVIDENCE_DIR: $evidenceDir"
    Write-Output 'NEXT_STATE: OWNER_RELEASE_BURN_CONFIRMATION_REQUIRED'
    exit 0
}

$expectedPhrase = "$($profile.releasePipeline.destructivePhrasePrefix) $packedHash"
Write-Output ''
Write-Output '=== DESTRUCTIVE OWNER GATE ==='
Write-Output 'The exact packed image above will be written to Board #1 SPI.'
Write-Output "Type exactly: $expectedPhrase"
$confirmation = Read-Host 'Confirmation'
if ($confirmation.Trim().ToUpperInvariant() -ne $expectedPhrase.ToUpperInvariant()) {
    Write-Blocked -Reason 'HASH_BOUND_DESTRUCTIVE_CONFIRMATION_REQUIRED'
    Write-Output "EVIDENCE_DIR: $evidenceDir"
    exit 1
}

Write-Output ''
Write-Output '=== RELEASE BURN + FULL READBACK ==='
$burn = Invoke-Child -Script (Join-Path $PSScriptRoot 'eink-spi-burn.ps1') -Arguments @(
    '-Mode', 'Burn',
    '-PackedBin', $packedPath,
    '-ExpectedPackedSha256', $packedHash,
    '-ConfirmToken', [string]$profile.spiBurn.confirmationToken,
    '-ProfilePath', $ProfilePath
)
$burn.Output | ForEach-Object { Write-Output $_ }
if ($burn.ExitCode -ne 0 -or -not ($burn.Output -match 'NEXT_STATE: SPI_BURN_VERIFIED')) {
    Write-Blocked -Reason 'BURN_OR_READBACK_FAILED'
    Write-Output "EVIDENCE_DIR: $evidenceDir"
    exit 1
}
$burnEvidence = Get-OutputValue -Output $burn.Output -Key 'EVIDENCE_DIR'
if ([string]::IsNullOrWhiteSpace($burnEvidence)) {
    Write-Blocked -Reason 'BURN_EVIDENCE_MISSING'
    exit 1
}

Write-Output ''
Write-Output '=== RELEASE DEVICE VALIDATION ==='
$device = Invoke-Child -Script (Join-Path $PSScriptRoot 'eink-device-validate.ps1') -Arguments @('-BurnEvidenceDir', $burnEvidence, '-ProfilePath', $ProfilePath)
$device.Output | ForEach-Object { Write-Output $_ }
if ($device.ExitCode -ne 0 -or -not ($device.Output -match 'NEXT_STATE: DEVICE_VALIDATION_VERIFIED')) {
    Write-Blocked -Reason 'DEVICE_VALIDATION_FAILED'
    Write-Output "EVIDENCE_DIR: $evidenceDir"
    exit 1
}
$deviceEvidence = Get-OutputValue -Output $device.Output -Key 'EVIDENCE_DIR'

$summary = @(
    'ACTION: RELEASE-PIPELINE',
    "BRANCH: $branch",
    "HEAD: $head",
    "DEVICE_NAME: $DeviceName",
    "RAW_BIN: $rawBin",
    "RAW_SHA256: $rawHash",
    "PACKED_BIN: $packedPath",
    "PACKED_SIZE: $($packedFile.Length)",
    "PACKED_SHA256: $packedHash",
    "BURN_EVIDENCE_DIR: $burnEvidence",
    "DEVICE_EVIDENCE_DIR: $deviceEvidence",
    'COLD_BOOT: PASS',
    'BLE: PASS',
    'PHYSICAL_EINK_VISUAL: PASS',
    'NEXT_STATE: RELEASE_VALIDATION_VERIFIED'
)
$summaryPath = Join-Path $evidenceDir 'release-validation.txt'
[System.IO.File]::WriteAllLines($summaryPath, $summary, [System.Text.UTF8Encoding]::new($false))

Write-Output ''
Write-Output 'EINK HARNESS: PASS'
Write-Output 'ACTION: RELEASE-PIPELINE'
Write-Output "PACKED_SHA256: $packedHash"
Write-Output "BURN_EVIDENCE_DIR: $burnEvidence"
Write-Output "DEVICE_EVIDENCE_DIR: $deviceEvidence"
Write-Output "EVIDENCE_DIR: $evidenceDir"
Write-Output "EVIDENCE_FILE: $summaryPath"
Write-Output 'NEXT_STATE: RELEASE_VALIDATION_VERIFIED'
exit 0
