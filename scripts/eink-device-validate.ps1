[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)][string]$BurnEvidenceDir,
    [string]$ProfilePath = (Join-Path $PSScriptRoot '..\tools\harness\eink-profile.json')
)

$ErrorActionPreference = 'Stop'

function Write-Blocked {
    param([Parameter(Mandatory = $true)][string]$Reason)
    Write-Output 'EINK HARNESS: BLOCKED'
    Write-Output 'ACTION: DEVICE-VALIDATION'
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

$statusLines = @(& git status --porcelain=v1 --untracked-files=all 2>$null)
$trackedDirty = @($statusLines | Where-Object { $_ -and -not $_.StartsWith('?? ') })
if ($trackedDirty.Count -gt 0) {
    Write-Blocked -Reason 'DIRTY_TRACKED_TREE'
    $trackedDirty | ForEach-Object { Write-Output "DIRTY: $_" }
    exit 1
}

$burnDir = [System.IO.Path]::GetFullPath($BurnEvidenceDir)
if (-not (Test-Path -LiteralPath $burnDir -PathType Container)) {
    Write-Blocked -Reason 'BURN_EVIDENCE_DIR_MISSING'
    exit 1
}
$readback = Join-Path $burnDir 'SPI_READBACK.bin'
if (-not (Test-Path -LiteralPath $readback -PathType Leaf)) {
    Write-Blocked -Reason 'BURN_READBACK_MISSING'
    exit 1
}
$readbackFile = Get-Item -LiteralPath $readback
if ($readbackFile.Length -ne [int64]$profile.deviceValidation.expectedSpiBytes) {
    Write-Blocked -Reason "BURN_READBACK_SIZE_$($readbackFile.Length)"
    exit 1
}

$stamp = Get-Date -Format 'yyyyMMdd_HHmmss'
$evidenceDir = Join-Path ([string]$profile.deviceValidation.evidenceRoot) $stamp
[void](New-Item -ItemType Directory -Path $evidenceDir -Force)

$summaryPath = Join-Path $evidenceDir 'device-validation.txt'
$lines = New-Object System.Collections.Generic.List[string]
$lines.Add("ACTION: DEVICE-VALIDATION")
$lines.Add("BRANCH: $branch")
$lines.Add("HEAD: $head")
$lines.Add("BURN_EVIDENCE_DIR: $burnDir")
$lines.Add("READBACK_SIZE: $($readbackFile.Length)")
$lines.Add("CANONICAL_WEB_URL: $($profile.deviceValidation.canonicalWebUrl)")
$lines.Add("CREATED_AT: $(Get-Date -Format o)")

Write-Output 'EINK HARNESS v0.6 DEVICE VALIDATION'
Write-Output "BURN_EVIDENCE_DIR: $burnDir"
Write-Output "CANONICAL_WEB_URL: $($profile.deviceValidation.canonicalWebUrl)"
Write-Output ''
Write-Output "1) Power Board #1 OFF for at least $($profile.deviceValidation.coldBootPowerOffSeconds) seconds, then power it ON."
$cold = Read-Host "Type PASS only if Board #1 cold-boots normally"
$coldPass = ($cold.Trim().ToUpperInvariant() -eq [string]$profile.deviceValidation.ownerPassToken)
$lines.Add("COLD_BOOT: $(if ($coldPass) { 'PASS' } else { 'FAIL' })")
if (-not $coldPass) {
    [System.IO.File]::WriteAllLines($summaryPath, $lines, [System.Text.UTF8Encoding]::new($false))
    Write-Blocked -Reason 'COLD_BOOT_NOT_APPROVED'
    Write-Output "EVIDENCE_DIR: $evidenceDir"
    exit 1
}

Write-Output ''
Write-Output "2) On phone, open $($profile.deviceValidation.canonicalWebUrl), connect Board #1 via Web Bluetooth, and confirm live connection/device response."
$ble = Read-Host 'Type PASS only if BLE connection/device response is confirmed'
$blePass = ($ble.Trim().ToUpperInvariant() -eq [string]$profile.deviceValidation.ownerPassToken)
$lines.Add("BLE: $(if ($blePass) { 'PASS' } else { 'FAIL' })")
if (-not $blePass) {
    [System.IO.File]::WriteAllLines($summaryPath, $lines, [System.Text.UTF8Encoding]::new($false))
    Write-Blocked -Reason 'BLE_NOT_APPROVED'
    Write-Output "EVIDENCE_DIR: $evidenceDir"
    exit 1
}

Write-Output ''
Write-Output '3) Inspect the physical e-ink display. Confirm the flashed image boots and the expected clock UI renders correctly.'
$visual = Read-Host 'Type PASS only if YOU approve the physical e-ink visual result'
$visualPass = ($visual.Trim().ToUpperInvariant() -eq [string]$profile.deviceValidation.ownerPassToken)
$lines.Add("PHYSICAL_EINK_VISUAL: $(if ($visualPass) { 'PASS' } else { 'FAIL' })")
if (-not $visualPass) {
    [System.IO.File]::WriteAllLines($summaryPath, $lines, [System.Text.UTF8Encoding]::new($false))
    Write-Blocked -Reason 'VISUAL_NOT_APPROVED'
    Write-Output "EVIDENCE_DIR: $evidenceDir"
    exit 1
}

$lines.Add('NEXT_STATE: DEVICE_VALIDATION_VERIFIED')
[System.IO.File]::WriteAllLines($summaryPath, $lines, [System.Text.UTF8Encoding]::new($false))

Write-Output ''
Write-Output 'EINK HARNESS: PASS'
Write-Output 'ACTION: DEVICE-VALIDATION'
Write-Output 'COLD_BOOT: PASS'
Write-Output 'BLE: PASS'
Write-Output 'PHYSICAL_EINK_VISUAL: PASS'
Write-Output "EVIDENCE_DIR: $evidenceDir"
Write-Output "EVIDENCE_FILE: $summaryPath"
Write-Output 'NEXT_STATE: DEVICE_VALIDATION_VERIFIED'
exit 0
