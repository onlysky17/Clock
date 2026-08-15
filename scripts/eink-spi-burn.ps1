[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [string]$PackedBin,

    [ValidateSet('Plan', 'Burn')]
    [string]$Mode = 'Plan',

    [string]$ExpectedPackedSha256,
    [string]$ConfirmToken,
    [string]$JtagSerial,
    [string]$ProfilePath = (Join-Path $PSScriptRoot '..\tools\harness\eink-profile.json')
)

$ErrorActionPreference = 'Stop'

function Write-Blocked {
    param([Parameter(Mandatory = $true)][string]$Reason)
    Write-Output 'EINK HARNESS: BLOCKED'
    Write-Output 'ACTION: SPI-BURN'
    Write-Output "REASON: $Reason"
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

function Assert-Workspace {
    param([Parameter(Mandatory = $true)]$Profile)

    $expected = [System.IO.Path]::GetFullPath([string]$Profile.workspace.canonicalPath).TrimEnd('\')
    $actual = [System.IO.Path]::GetFullPath((Get-Location).Path).TrimEnd('\')
    if (-not [string]::Equals($actual, $expected, [System.StringComparison]::OrdinalIgnoreCase)) {
        Write-Output 'SAI PROJECT/WORKSPACE'
        return $false
    }

    $gitRoot = Invoke-GitText -Arguments @('rev-parse', '--show-toplevel')
    if ([string]::IsNullOrWhiteSpace($gitRoot) -or
        -not [string]::Equals(([System.IO.Path]::GetFullPath($gitRoot).TrimEnd('\')), $expected, [System.StringComparison]::OrdinalIgnoreCase)) {
        Write-Output 'SAI PROJECT/WORKSPACE'
        return $false
    }

    $origin = Invoke-GitText -Arguments @('remote', 'get-url', 'origin')
    if ($origin -ne [string]$Profile.workspace.origin) {
        Write-Blocked -Reason 'WRONG_REMOTE'
        return $false
    }

    $trackedDirty = @(& git status --porcelain=v1 --untracked-files=all 2>$null | Where-Object { $_ -and -not $_.StartsWith('?? ') })
    if ($trackedDirty.Count -gt 0) {
        Write-Blocked -Reason 'DIRTY_TRACKED_TREE'
        $trackedDirty | ForEach-Object { Write-Output "DIRTY: $_" }
        return $false
    }

    return $true
}

function Invoke-SmartSnippets {
    param(
        [Parameter(Mandatory = $true)][string]$Cli,
        [Parameter(Mandatory = $true)][string[]]$Arguments,
        [Parameter(Mandatory = $true)][string]$StdoutLog,
        [Parameter(Mandatory = $true)][string]$StderrLog
    )

    Remove-Item -LiteralPath $StdoutLog -Force -ErrorAction SilentlyContinue
    Remove-Item -LiteralPath $StderrLog -Force -ErrorAction SilentlyContinue

    try {
        $p = Start-Process `
            -FilePath $Cli `
            -ArgumentList $Arguments `
            -RedirectStandardOutput $StdoutLog `
            -RedirectStandardError $StderrLog `
            -WindowStyle Hidden `
            -Wait `
            -PassThru
    }
    catch {
        return [pscustomobject]@{ Passed = $false; ExitCode = -1; Reason = 'PROCESS_EXCEPTION' }
    }

    $stdout = if (Test-Path -LiteralPath $StdoutLog) { Get-Content -LiteralPath $StdoutLog -Raw } else { '' }
    $stderr = if (Test-Path -LiteralPath $StderrLog) { Get-Content -LiteralPath $StderrLog -Raw } else { '' }
    $combined = "$stdout`n$stderr"

    if ($p.ExitCode -ne 0) {
        return [pscustomobject]@{ Passed = $false; ExitCode = $p.ExitCode; Reason = "EXIT_$($p.ExitCode)" }
    }
    if ($combined -match '(?i)(failed|\berror:)') {
        return [pscustomobject]@{ Passed = $false; ExitCode = $p.ExitCode; Reason = 'TOOL_REPORTED_FAILURE' }
    }

    return [pscustomobject]@{ Passed = $true; ExitCode = $p.ExitCode; Reason = 'OK' }
}

$profile = Get-Content -LiteralPath $ProfilePath -Raw | ConvertFrom-Json
if (-not (Assert-Workspace -Profile $profile)) { exit 1 }

$packedPath = [System.IO.Path]::GetFullPath($PackedBin)
if (-not (Test-Path -LiteralPath $packedPath -PathType Leaf)) {
    Write-Blocked -Reason 'PACKED_BIN_MISSING'
    exit 1
}

$packedFile = Get-Item -LiteralPath $packedPath
if ($packedFile.Length -ne [int64]$profile.spiBurn.expectedBytes) {
    Write-Blocked -Reason "PACKED_BIN_SIZE_$($packedFile.Length)"
    exit 1
}

$packedHash = Get-Sha256Hex -Path $packedPath
Write-Output "PACKED_BIN: $packedPath"
Write-Output "PACKED_SIZE: $($packedFile.Length)"
Write-Output "PACKED_SHA256: $packedHash"

if ($Mode -eq 'Plan') {
    Write-Output 'EINK HARNESS: PASS'
    Write-Output 'ACTION: SPI-BURN-PLAN'
    Write-Output "CONFIRM_TOKEN_REQUIRED: $($profile.spiBurn.confirmationToken)"
    Write-Output 'NEXT_STATE: OWNER_BURN_CONFIRMATION_REQUIRED'
    exit 0
}

if ([string]::IsNullOrWhiteSpace($ExpectedPackedSha256) -or
    $ExpectedPackedSha256.Trim().ToUpperInvariant() -ne $packedHash) {
    Write-Blocked -Reason 'EXPECTED_PACKED_SHA256_MISMATCH'
    exit 1
}
if ($ConfirmToken -ne [string]$profile.spiBurn.confirmationToken) {
    Write-Blocked -Reason 'DESTRUCTIVE_CONFIRMATION_REQUIRED'
    exit 1
}

$config = $profile.spiBackup
$burn = $profile.spiBurn
$requiredPaths = @([string]$config.smartSnippetsCli, [string]$config.jtagProgrammer)
foreach ($requiredPath in $requiredPaths) {
    if ([string]::IsNullOrWhiteSpace($requiredPath) -or -not (Test-Path -LiteralPath $requiredPath -PathType Leaf)) {
        Write-Blocked -Reason "MISSING_DEPENDENCY: $requiredPath"
        exit 1
    }
}

$serial = if ([string]::IsNullOrWhiteSpace($JtagSerial)) { [string]$config.jtagSerial } else { $JtagSerial.Trim() }
if ([string]::IsNullOrWhiteSpace($serial)) {
    Write-Blocked -Reason 'JTAG_SERIAL_MISSING'
    exit 1
}

$stamp = Get-Date -Format 'yyyyMMdd_HHmmss'
$evidenceDir = Join-Path ([string]$burn.evidenceRoot) $stamp
[void](New-Item -ItemType Directory -Path $evidenceDir -Force)
[System.IO.File]::WriteAllText((Join-Path $evidenceDir 'packed.sha256.txt'), "$packedHash  $packedPath`r`n", [System.Text.UTF8Encoding]::new($false))

$backupRunner = Join-Path $PSScriptRoot 'eink-spi-backup.ps1'
$backupOutput = @(& powershell.exe -NoProfile -ExecutionPolicy Bypass -File $backupRunner -JtagSerial $serial 2>&1 | ForEach-Object { $_.ToString() })
$backupExit = $LASTEXITCODE
[System.IO.File]::WriteAllLines((Join-Path $evidenceDir 'fresh-backup.log'), $backupOutput, [System.Text.UTF8Encoding]::new($false))
if ($backupExit -ne 0 -or -not ($backupOutput -match 'NEXT_STATE: SPI_BACKUP_VERIFIED')) {
    Write-Blocked -Reason 'FRESH_BACKUP_FAILED'
    Write-Output "EVIDENCE_DIR: $evidenceDir"
    exit 1
}

$backupHashLines = @($backupOutput | Where-Object { $_ -match '^READ[12]_SHA256:\s+[0-9A-F]{64}$' })
if ($backupHashLines.Count -ne 2) {
    Write-Blocked -Reason 'FRESH_BACKUP_HASH_EVIDENCE_MISSING'
    Write-Output "EVIDENCE_DIR: $evidenceDir"
    exit 1
}

$common = @(
    '-type', 'spi',
    '-chip', [string]$config.chip,
    '-clk', [string]$config.clk,
    '-cs', [string]$config.cs,
    '-miso', [string]$config.miso,
    '-mosi', [string]$config.mosi,
    '-jtag', $serial,
    '-firmware', "`"$([string]$config.jtagProgrammer)`""
)

$eraseArgs = $common + @('-cmd', 'erase', '-verify', '-y')
$erase = Invoke-SmartSnippets -Cli ([string]$config.smartSnippetsCli) -Arguments $eraseArgs -StdoutLog (Join-Path $evidenceDir 'erase.stdout.log') -StderrLog (Join-Path $evidenceDir 'erase.stderr.log')
if (-not $erase.Passed) {
    Write-Blocked -Reason "SPI_ERASE_$($erase.Reason)"
    Write-Output "EVIDENCE_DIR: $evidenceDir"
    exit 1
}

$writeArgs = $common + @(
    '-cmd', 'write',
    '-file', "`"$packedPath`"",
    '-offset', [string]$burn.offset,
    '-max', [string]$burn.max,
    '-verify',
    '-y'
)
$write = Invoke-SmartSnippets -Cli ([string]$config.smartSnippetsCli) -Arguments $writeArgs -StdoutLog (Join-Path $evidenceDir 'write.stdout.log') -StderrLog (Join-Path $evidenceDir 'write.stderr.log')
if (-not $write.Passed) {
    Write-Blocked -Reason "SPI_WRITE_$($write.Reason)"
    Write-Output "EVIDENCE_DIR: $evidenceDir"
    exit 1
}

$readbackPath = Join-Path $evidenceDir 'SPI_READBACK.bin'
$readArgs = $common + @(
    '-cmd', 'read',
    '-file', "`"$readbackPath`"",
    '-offset', [string]$config.offset,
    '-length', [string]$config.length,
    '-max', [string]$config.max,
    '-y'
)
$read = Invoke-SmartSnippets -Cli ([string]$config.smartSnippetsCli) -Arguments $readArgs -StdoutLog (Join-Path $evidenceDir 'readback.stdout.log') -StderrLog (Join-Path $evidenceDir 'readback.stderr.log')
if (-not $read.Passed -or -not (Test-Path -LiteralPath $readbackPath -PathType Leaf)) {
    Write-Blocked -Reason "SPI_READBACK_$($read.Reason)"
    Write-Output "EVIDENCE_DIR: $evidenceDir"
    exit 1
}

$readbackFile = Get-Item -LiteralPath $readbackPath
if ($readbackFile.Length -ne [int64]$burn.expectedBytes) {
    Write-Blocked -Reason "SPI_READBACK_SIZE_$($readbackFile.Length)"
    Write-Output "EVIDENCE_DIR: $evidenceDir"
    exit 1
}

$readbackHash = Get-Sha256Hex -Path $readbackPath
if ($readbackHash -ne $packedHash) {
    Write-Blocked -Reason 'SPI_READBACK_HASH_MISMATCH'
    Write-Output "PACKED_SHA256: $packedHash"
    Write-Output "READBACK_SHA256: $readbackHash"
    Write-Output "EVIDENCE_DIR: $evidenceDir"
    exit 1
}

Write-Output 'EINK HARNESS: PASS'
Write-Output 'ACTION: SPI-BURN'
Write-Output "JTAG: $serial"
Write-Output "PACKED_BIN: $packedPath"
Write-Output "PACKED_SIZE: $($packedFile.Length)"
Write-Output "PACKED_SHA256: $packedHash"
Write-Output "READBACK: $readbackPath"
Write-Output "READBACK_SIZE: $($readbackFile.Length)"
Write-Output "READBACK_SHA256: $readbackHash"
Write-Output "EVIDENCE_DIR: $evidenceDir"
Write-Output 'NEXT_STATE: SPI_BURN_VERIFIED'
exit 0
