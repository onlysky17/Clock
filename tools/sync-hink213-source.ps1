[CmdletBinding(DefaultParameterSetName = 'Check')]
param(
    [Parameter(Mandatory = $true, ParameterSetName = 'ToSdk')]
    [switch]$ToSdk,

    [Parameter(Mandatory = $true, ParameterSetName = 'FromSdk')]
    [switch]$FromSdk,

    [Parameter(Mandatory = $true, ParameterSetName = 'Check')]
    [switch]$Check,

    [Parameter(ParameterSetName = 'FromSdk')]
    [switch]$ConfirmImport,

    [string]$RepoRoot = 'D:\EINK\Clock',
    [string]$SdkProjectRoot = 'D:\EINK\6.0.18.1182.1\projects\target_apps\ble_examples\HINK213_CLOCK_P3_EPD_SMOKE'
)

$ErrorActionPreference = 'Stop'

$relativeSource = 'src\user_custs1_impl.c'
$canonical = Join-Path $RepoRoot ('firmware\active\HINK213_CLOCK_P3_EPD_SMOKE\' + $relativeSource)
$sdk = Join-Path $SdkProjectRoot $relativeSource

function Get-Sha256([string]$Path) {
    if (-not (Test-Path -LiteralPath $Path)) { return $null }
    return (Get-FileHash -LiteralPath $Path -Algorithm SHA256).Hash
}

function Backup-File([string]$Path) {
    if (-not (Test-Path -LiteralPath $Path)) { return $null }
    $stamp = Get-Date -Format 'yyyyMMdd_HHmmss'
    $backup = "$Path.sync_$stamp.bak"
    Copy-Item -LiteralPath $Path -Destination $backup -Force
    return $backup
}

function Copy-And-Verify([string]$Source, [string]$Destination) {
    if (-not (Test-Path -LiteralPath $Source)) {
        throw "Source file not found: $Source"
    }

    $destDir = Split-Path -Parent $Destination
    New-Item -ItemType Directory -Force -Path $destDir | Out-Null

    $backup = Backup-File $Destination
    if ($backup) { Write-Host "Backup: $backup" }

    Copy-Item -LiteralPath $Source -Destination $Destination -Force

    $sourceHash = Get-Sha256 $Source
    $destinationHash = Get-Sha256 $Destination
    if ($sourceHash -ne $destinationHash) {
        throw "SHA256 mismatch after copy.`nSource: $sourceHash`nDestination: $destinationHash"
    }

    Write-Host "PASS: SHA256 match $sourceHash"
}

Write-Host "Canonical: $canonical"
Write-Host "SDK mirror: $sdk"

if ($Check) {
    $canonicalHash = Get-Sha256 $canonical
    $sdkHash = Get-Sha256 $sdk

    if (-not $canonicalHash) { Write-Host 'Canonical source: MISSING' }
    else { Write-Host "Canonical SHA256: $canonicalHash" }

    if (-not $sdkHash) { Write-Host 'SDK source: MISSING' }
    else { Write-Host "SDK SHA256:       $sdkHash" }

    if ($canonicalHash -and $sdkHash -and ($canonicalHash -eq $sdkHash)) {
        Write-Host 'PASS: canonical and SDK source are identical.'
        exit 0
    }

    Write-Host 'FAIL: canonical and SDK source are missing or different.'
    exit 2
}

if ($ToSdk) {
    Copy-And-Verify -Source $canonical -Destination $sdk
    Write-Host 'DONE: canonical repo source synced to SDK.'
    exit 0
}

if ($FromSdk) {
    if (-not $ConfirmImport) {
        throw 'Refusing SDK -> repo import without -ConfirmImport.'
    }

    Copy-And-Verify -Source $sdk -Destination $canonical
    Write-Host 'DONE: SDK source imported into canonical repo source. Review git diff before commit.'
    exit 0
}
