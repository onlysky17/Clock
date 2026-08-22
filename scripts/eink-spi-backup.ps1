[CmdletBinding()]
param(
    [string]$ProfilePath = (Join-Path $PSScriptRoot '..\tools\harness\eink-profile.json'),
    [string]$JtagSerial,
    [switch]$AllowDirtyTrackedTree
)

$ErrorActionPreference = 'Stop'

function Write-Blocked {
    param([Parameter(Mandatory = $true)][string]$Reason)
    Write-Output 'EINK HARNESS: BLOCKED'
    Write-Output 'ACTION: SPI-BACKUP'
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

function Invoke-SpiRead {
    param(
        [Parameter(Mandatory = $true)]$Config,
        [Parameter(Mandatory = $true)][string]$Serial,
        [Parameter(Mandatory = $true)][string]$OutputFile,
        [Parameter(Mandatory = $true)][string]$StdoutLog,
        [Parameter(Mandatory = $true)][string]$StderrLog
    )

    Remove-Item -LiteralPath $OutputFile -Force -ErrorAction SilentlyContinue
    Remove-Item -LiteralPath $StdoutLog -Force -ErrorAction SilentlyContinue
    Remove-Item -LiteralPath $StderrLog -Force -ErrorAction SilentlyContinue

    $arguments = @(
        '-type', 'spi',
        '-chip', [string]$Config.chip,
        '-clk', [string]$Config.clk,
        '-cs', [string]$Config.cs,
        '-miso', [string]$Config.miso,
        '-mosi', [string]$Config.mosi,
        '-jtag', $Serial,
        '-firmware', "`"$([string]$Config.jtagProgrammer)`"",
        '-cmd', 'read',
        '-file', "`"$OutputFile`"",
        '-offset', [string]$Config.offset,
        '-length', [string]$Config.length,
        '-max', [string]$Config.max,
        '-y'
    )

    $argumentText = ($arguments -join ' ')
    if ($argumentText -match '(?i)(^|\s)-(cmd\s+(write|erase|write_field)|verify|bootable)(\s|$)') {
        throw 'DESTRUCTIVE_ARGUMENT_GUARD'
    }
    if ($argumentText -notmatch '(?i)-cmd\s+read(\s|$)') {
        throw 'READ_COMMAND_MISSING'
    }

    try {
        $process = Start-Process `
            -FilePath ([string]$Config.smartSnippetsCli) `
            -ArgumentList $arguments `
            -RedirectStandardOutput $StdoutLog `
            -RedirectStandardError $StderrLog `
            -WindowStyle Hidden `
            -Wait `
            -PassThru
    }
    catch {
        return [pscustomobject]@{ Passed = $false; Reason = 'SMARTSNIPPETS_PROCESS_EXCEPTION'; ExitCode = -1 }
    }

    $stdout = if (Test-Path -LiteralPath $StdoutLog) { Get-Content -LiteralPath $StdoutLog -Raw } else { '' }
    $stderr = if (Test-Path -LiteralPath $StderrLog) { Get-Content -LiteralPath $StderrLog -Raw } else { '' }
    $combined = "$stdout`n$stderr"

    if ($process.ExitCode -ne 0) {
        return [pscustomobject]@{ Passed = $false; Reason = "SMARTSNIPPETS_EXIT_$($process.ExitCode)"; ExitCode = $process.ExitCode }
    }
    if ($combined -match '(?i)(SPI\s+FLASH\s+memory\s+reading\s+has\s+failed|failed\s+reading|failed\s+configuring|\berror:)') {
        return [pscustomobject]@{ Passed = $false; Reason = 'SMARTSNIPPETS_READ_FAILED'; ExitCode = $process.ExitCode }
    }
    if (-not (Test-Path -LiteralPath $OutputFile -PathType Leaf)) {
        return [pscustomobject]@{ Passed = $false; Reason = 'SPI_READ_FILE_MISSING'; ExitCode = $process.ExitCode }
    }

    return [pscustomobject]@{ Passed = $true; Reason = 'READ_OK'; ExitCode = $process.ExitCode }
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
if ([string]::IsNullOrWhiteSpace($branch)) {
    Write-Blocked -Reason 'DETACHED_OR_UNKNOWN_BRANCH'
    exit 1
}

$origin = Invoke-GitText -Arguments @('remote', 'get-url', 'origin')
if ($origin -ne [string]$profile.workspace.origin) {
    Write-Blocked -Reason 'WRONG_REMOTE'
    exit 1
}

$statusLines = @(& git status --porcelain=v1 --untracked-files=all 2>$null)
$trackedDirty = @($statusLines | Where-Object { $_ -and -not $_.StartsWith('?? ') })
if ($trackedDirty.Count -gt 0) {
    $trackedDirty | ForEach-Object { Write-Output "DIRTY: $_" }
    if (-not $AllowDirtyTrackedTree) {
        Write-Blocked -Reason 'DIRTY_TRACKED_TREE'
        exit 1
    }
}

$config = $profile.spiBackup
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
$evidenceDir = Join-Path ([string]$config.evidenceRoot) $stamp
[void](New-Item -ItemType Directory -Path $evidenceDir -Force)

$read1 = Join-Path $evidenceDir 'BOARD1_SPI_READ1.bin'
$read2 = Join-Path $evidenceDir 'BOARD1_SPI_READ2.bin'
$out1 = Join-Path $evidenceDir 'read1.stdout.log'
$err1 = Join-Path $evidenceDir 'read1.stderr.log'
$out2 = Join-Path $evidenceDir 'read2.stdout.log'
$err2 = Join-Path $evidenceDir 'read2.stderr.log'

$result1 = Invoke-SpiRead -Config $config -Serial $serial -OutputFile $read1 -StdoutLog $out1 -StderrLog $err1
if (-not $result1.Passed) {
    Write-Blocked -Reason "READ1_$($result1.Reason)"
    Write-Output "EVIDENCE_DIR: $evidenceDir"
    exit 1
}

$file1 = Get-Item -LiteralPath $read1
if ($file1.Length -ne [int64]$config.expectedBytes) {
    Write-Blocked -Reason "READ1_SIZE_$($file1.Length)"
    Write-Output "EVIDENCE_DIR: $evidenceDir"
    exit 1
}
$hash1 = Get-Sha256Hex -Path $read1

$result2 = Invoke-SpiRead -Config $config -Serial $serial -OutputFile $read2 -StdoutLog $out2 -StderrLog $err2
if (-not $result2.Passed) {
    Write-Blocked -Reason "READ2_$($result2.Reason)"
    Write-Output "READ1_SHA256: $hash1"
    Write-Output "EVIDENCE_DIR: $evidenceDir"
    exit 1
}

$file2 = Get-Item -LiteralPath $read2
if ($file2.Length -ne [int64]$config.expectedBytes) {
    Write-Blocked -Reason "READ2_SIZE_$($file2.Length)"
    Write-Output "EVIDENCE_DIR: $evidenceDir"
    exit 1
}
$hash2 = Get-Sha256Hex -Path $read2

if ($hash1 -ne $hash2) {
    Write-Blocked -Reason 'SPI_BACKUP_HASH_MISMATCH'
    Write-Output "READ1_SHA256: $hash1"
    Write-Output "READ2_SHA256: $hash2"
    Write-Output "EVIDENCE_DIR: $evidenceDir"
    exit 1
}

Write-Output 'EINK HARNESS: PASS'
Write-Output 'ACTION: SPI-BACKUP'
Write-Output "BRANCH: $branch"
Write-Output "JTAG: $serial"
Write-Output "READ1: $read1"
Write-Output "READ1_SIZE: $($file1.Length)"
Write-Output "READ1_SHA256: $hash1"
Write-Output "READ2: $read2"
Write-Output "READ2_SIZE: $($file2.Length)"
Write-Output "READ2_SHA256: $hash2"
Write-Output "EVIDENCE_DIR: $evidenceDir"
Write-Output 'NEXT_STATE: SPI_BACKUP_VERIFIED'
exit 0
