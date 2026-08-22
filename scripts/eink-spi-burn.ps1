[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [string]$PackedBin,

    [ValidateSet('Plan', 'Burn')]
    [string]$Mode = 'Plan',

    [string]$ExpectedPackedSha256,
    [string]$ConfirmToken,
    [string]$JtagSerial,
    [string]$ProfilePath = '',
    [string]$PhaseStatePath = '',
    [switch]$AllowDirtyTrackedTree,
    [switch]$PreflightAcceptanceOnly,
    [switch]$BackupAcceptanceOnly,
    [switch]$PipelineAcceptanceOnly,
    [switch]$RecoveryWriteOnly,
    [string]$RecoveryConfirmToken = '',
    [string]$PreEraseBackupEvidenceDir = '',
    [string]$ExpectedPreEraseBackupSha256 = '',
    [string]$BackupRunnerPath = '',
    [ValidateRange(1, 600)][int]$BackupTimeoutSec = 180,
    [ValidateSet('Native', 'Null', 'Nonzero')][string]$AcceptanceBackupExitMode = 'Native',
    [ValidateSet('Native', 'Null', 'Nonzero')][string]$AcceptanceSmartSnippetsExitMode = 'Native',
    [ValidateRange(0, 600)][int]$AcceptanceSmartSnippetsTimeoutSec = 0
)

$ErrorActionPreference = 'Stop'

$scriptDirectory = Split-Path -Parent $MyInvocation.MyCommand.Path
if ([string]::IsNullOrWhiteSpace($ProfilePath)) {
    $ProfilePath = Join-Path `
        $scriptDirectory `
        '..\tools\harness\eink-profile.json'
}
$ProfilePath = [IO.Path]::GetFullPath($ProfilePath)

function Write-Blocked {
    param([Parameter(Mandatory = $true)][string]$Reason)
    Write-Output 'EINK HARNESS: BLOCKED'
    Write-Output 'ACTION: SPI-BURN'
    Write-Output "REASON: $Reason"
}

function Write-PhaseState {
    param(
        [Parameter(Mandatory = $true)][string]$Phase,
        [Parameter(Mandatory = $true)][string]$Status,
        [Parameter(Mandatory = $true)][bool]$DestructiveStarted,
        [string]$Reason = ''
    )

    if ([string]::IsNullOrWhiteSpace($PhaseStatePath)) { return }
    $fullPath = [IO.Path]::GetFullPath($PhaseStatePath)
    $parent = Split-Path -Parent $fullPath
    if (-not (Test-Path -LiteralPath $parent -PathType Container)) {
        [void](New-Item -ItemType Directory -Path $parent -Force)
    }
    $record = [ordered]@{
        schemaVersion = 1
        phase = $Phase
        status = $Status
        reason = $Reason
        destructiveStarted = $DestructiveStarted
        updatedUtc = (Get-Date).ToUniversalTime().ToString('o')
        workerPid = [int]$PID
    }
    $temporary = "$fullPath.$PID.tmp"
    [IO.File]::WriteAllText(
        $temporary,
        ($record | ConvertTo-Json -Depth 5),
        [Text.UTF8Encoding]::new($false)
    )
    Move-Item -LiteralPath $temporary -Destination $fullPath -Force
}

function Stop-ExactProcessTree {
    param(
        [Parameter(Mandatory = $true)][Diagnostics.Process]$Process,
        [Parameter(Mandatory = $true)][int64]$StartTicks,
        [Parameter(Mandatory = $true)][string]$ExecutablePath
    )

    $descendants = @()
    $queue = New-Object 'Collections.Generic.Queue[object]'
    $queue.Enqueue([pscustomobject]@{ Id = [int]$Process.Id; Depth = 0 })
    while ($queue.Count -gt 0) {
        $parent = $queue.Dequeue()
        $children = @(Get-CimInstance Win32_Process -Filter "ParentProcessId=$($parent.Id)" -ErrorAction SilentlyContinue)
        foreach ($child in $children) {
            $queue.Enqueue([pscustomobject]@{ Id = [int]$child.ProcessId; Depth = [int]$parent.Depth + 1 })
            try {
                $liveChild = Get-Process -Id ([int]$child.ProcessId) -ErrorAction Stop
                $descendants += [pscustomobject]@{
                    Id = [int]$liveChild.Id
                    StartTicks = [int64]$liveChild.StartTime.ToUniversalTime().Ticks
                    Path = [string]$liveChild.Path
                    Depth = [int]$parent.Depth + 1
                }
            }
            catch { }
        }
    }
    foreach ($child in @($descendants | Sort-Object Depth -Descending)) {
        try {
            $live = Get-Process -Id $child.Id -ErrorAction Stop
            if ($live.StartTime.ToUniversalTime().Ticks -eq $child.StartTicks -and
                [IO.Path]::GetFullPath($live.Path) -eq [IO.Path]::GetFullPath($child.Path)) {
                Stop-Process -Id $live.Id -Force
            }
        }
        catch { }
    }
    try {
        $liveParent = Get-Process -Id $Process.Id -ErrorAction Stop
        if ($liveParent.StartTime.ToUniversalTime().Ticks -eq $StartTicks -and
            [IO.Path]::GetFullPath($liveParent.Path) -eq [IO.Path]::GetFullPath($ExecutablePath)) {
            Stop-Process -Id $liveParent.Id -Force
        }
    }
    catch { }
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
    param(
        [Parameter(Mandatory = $true)]$Profile,
        [switch]$AllowDirtyTrackedTree
    )

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
        $trackedDirty | ForEach-Object { Write-Output "DIRTY: $_" }
        if (-not $AllowDirtyTrackedTree) {
            Write-Blocked -Reason 'DIRTY_TRACKED_TREE'
            return $false
        }
    }

    return $true
}

function Invoke-SmartSnippets {
    param(
        [Parameter(Mandatory = $true)][string]$Cli,
        [Parameter(Mandatory = $true)][string[]]$Arguments,
        [Parameter(Mandatory = $true)][string]$StdoutLog,
        [Parameter(Mandatory = $true)][string]$StderrLog,
        [Parameter(Mandatory = $true)][ValidateRange(1, 600)][int]$TimeoutSec
    )

    Remove-Item -LiteralPath $StdoutLog -Force -ErrorAction SilentlyContinue
    Remove-Item -LiteralPath $StderrLog -Force -ErrorAction SilentlyContinue

    try {
        $resolvedCli = if ([System.IO.Path]::IsPathRooted($Cli)) {
            [System.IO.Path]::GetFullPath($Cli)
        }
        else {
            [string](Get-Command -Name $Cli -CommandType Application -ErrorAction Stop).Source
        }
        if ([string]::IsNullOrWhiteSpace($resolvedCli)) {
            throw "Unable to resolve executable: $Cli"
        }
        $p = Start-Process `
            -FilePath $resolvedCli `
            -ArgumentList $Arguments `
            -RedirectStandardOutput $StdoutLog `
            -RedirectStandardError $StderrLog `
            -WindowStyle Hidden `
            -PassThru
    }
    catch {
        return [pscustomobject]@{ Passed = $false; ExitCode = -1; Reason = 'PROCESS_EXCEPTION'; TimedOut = $false }
    }

    $startTicks = $p.StartTime.ToUniversalTime().Ticks
    $executablePath = $resolvedCli
    if (-not $p.WaitForExit($TimeoutSec * 1000)) {
        Stop-ExactProcessTree -Process $p -StartTicks $startTicks -ExecutablePath $executablePath
        [void]$p.WaitForExit(5000)
        return [pscustomobject]@{ Passed = $false; ExitCode = -1; Reason = 'TIMEOUT'; TimedOut = $true }
    }
    $p.WaitForExit()
    $p.Refresh()

    $stdout = if (Test-Path -LiteralPath $StdoutLog) { Get-Content -LiteralPath $StdoutLog -Raw } else { '' }
    $stderr = if (Test-Path -LiteralPath $StderrLog) { Get-Content -LiteralPath $StderrLog -Raw } else { '' }
    $combined = "$stdout`n$stderr"

    if ($p.ExitCode -ne 0) {
        return [pscustomobject]@{ Passed = $false; ExitCode = $p.ExitCode; Reason = "EXIT_$($p.ExitCode)"; TimedOut = $false }
    }
    if ($combined -match '(?i)(failed|\berror:)') {
        return [pscustomobject]@{ Passed = $false; ExitCode = $p.ExitCode; Reason = 'TOOL_REPORTED_FAILURE'; TimedOut = $false }
    }

    return [pscustomobject]@{ Passed = $true; ExitCode = $p.ExitCode; Reason = 'OK'; TimedOut = $false }
}

function Invoke-PowerShellPhase {
    param(
        [Parameter(Mandatory = $true)][string[]]$Arguments,
        [Parameter(Mandatory = $true)][string]$StdoutLog,
        [Parameter(Mandatory = $true)][string]$StderrLog,
        [Parameter(Mandatory = $true)][ValidateRange(1, 600)][int]$TimeoutSec
    )
    Invoke-SmartSnippets -Cli 'powershell.exe' -Arguments $Arguments -StdoutLog $StdoutLog -StderrLog $StderrLog -TimeoutSec $TimeoutSec
}

function Wait-HardwarePreflightEvidence {
    param(
        [Parameter(Mandatory = $true)][string]$ReadPath,
        [Parameter(Mandatory = $true)][string]$StdoutLog,
        [ValidateRange(1, 10)][int]$TimeoutSec = 3
    )

    $deadline = [DateTime]::UtcNow.AddSeconds($TimeoutSec)
    do {
        $stdout = ''
        try {
            if (Test-Path -LiteralPath $StdoutLog -PathType Leaf) {
                $stdout = Get-Content -LiteralPath $StdoutLog -Raw -ErrorAction Stop
            }
        }
        catch { $stdout = '' }

        $fileExists = Test-Path -LiteralPath $ReadPath -PathType Leaf
        $fileSize = if ($fileExists) { [int64](Get-Item -LiteralPath $ReadPath).Length } else { -1 }
        $cortexDetected = $stdout -match '(?im)^Found Cortex-M0\b'
        $programmerSelected = $stdout -match '(?im)^Firmware File .*jtag_programmer\.bin has been selected for downloading\.\r?$'
        $programmerDownloaded = $stdout -match '(?im)^Successfully downloaded firmware file to the board\.\r?$'
        $gpioConfigured = $stdout -match '(?im)^Successfully set SPI Flash gpios:'
        $fileExported = $stdout -match '(?im)^Memory contents exported successfully to .+hardware-preflight\.bin\r?$'
        $readCompleted = $stdout -match '(?im)^SPI FLASH memory reading has finished\. Read 1 bytes\.\r?$'

        if ($cortexDetected -and $programmerSelected -and $programmerDownloaded -and
            $gpioConfigured -and $fileExported -and $readCompleted -and
            $fileExists -and $fileSize -eq 1) {
            return [pscustomobject]@{ Passed = $true; Reason = 'POSITIVE_EVIDENCE_COMPLETE' }
        }
        Start-Sleep -Milliseconds 100
    } while ([DateTime]::UtcNow -lt $deadline)

    $missing = @()
    if (-not $cortexDetected) { $missing += 'CORTEX_M0' }
    if (-not ($programmerSelected -and $programmerDownloaded)) { $missing += 'JTAG_PROGRAMMER_DOWNLOAD' }
    if (-not $gpioConfigured) { $missing += 'SPI_GPIO_CONFIG' }
    if (-not $fileExported) { $missing += 'READ_EXPORT' }
    if (-not $fileExists) { $missing += 'READ_FILE' }
    elseif ($fileSize -ne 1) { $missing += "READ_SIZE_$fileSize" }
    if (-not $readCompleted) { $missing += 'READ_COMPLETION' }
    [pscustomobject]@{ Passed = $false; Reason = 'MISSING_' + ($missing -join '_') }
}

function Get-EvidenceValue {
    param(
        [Parameter(Mandatory = $true)][string[]]$Lines,
        [Parameter(Mandatory = $true)][string]$Name
    )
    $matches = @($Lines | Where-Object { $_ -match ('^' + [regex]::Escape($Name) + ':\s+(.+)$') })
    if ($matches.Count -ne 1) { return '' }
    return ([regex]::Match($matches[0], '^' + [regex]::Escape($Name) + ':\s+(.+)$')).Groups[1].Value.Trim()
}

function Get-PhaseLogEvidence {
    param(
        [Parameter(Mandatory = $true)][string]$StdoutLog,
        [Parameter(Mandatory = $true)][string]$StderrLog
    )
    $stdoutLines = if (Test-Path -LiteralPath $StdoutLog -PathType Leaf) {
        @(Get-Content -LiteralPath $StdoutLog -ErrorAction SilentlyContinue | ForEach-Object { $_.ToString() })
    }
    else { @() }
    $stderrLines = if (Test-Path -LiteralPath $StderrLog -PathType Leaf) {
        @(Get-Content -LiteralPath $StderrLog -ErrorAction SilentlyContinue | ForEach-Object { $_.ToString() })
    }
    else { @() }
    $unexpectedStderr = @(
        $stderrLines | Where-Object {
            -not [string]::IsNullOrWhiteSpace($_) -and
            $_ -notmatch '^Aug .+ java\.util\.prefs\.WindowsPreferences <init>$' -and
            $_ -notmatch '^WARNING: Could not open/create prefs root node Software\\JavaSoft\\Prefs .+$'
        }
    )
    $failureLines = @(
        $stdoutLines | Where-Object {
            $_ -match '(?i)(^|\b)(failed|failure|unsuccessful|timed out|timeout)(\b|$)|^\s*(error|exception)\s*:'
        }
    )
    [pscustomobject]@{
        Stdout = $stdoutLines
        Stderr = $stderrLines
        UnexpectedStderr = $unexpectedStderr
        FailureLines = $failureLines
    }
}

function Test-ChunkEvidence {
    param(
        [Parameter(Mandatory = $true)][string[]]$Lines,
        [Parameter(Mandatory = $true)][ValidateSet('Read', 'Write')][string]$Operation,
        [Parameter(Mandatory = $true)][int64]$ExpectedBytes
    )
    $chunkBytes = 16384
    if ($ExpectedBytes -le 0 -or $ExpectedBytes % $chunkBytes -ne 0) { return $false }
    $offsets = New-Object 'Collections.Generic.List[int64]'
    $pattern = '^' + $Operation + ' 16384 bytes (?:from|at) offset 0x([0-9A-Fa-f]+)$'
    foreach ($line in $Lines) {
        $match = [regex]::Match($line, $pattern)
        if ($match.Success) {
            $offsets.Add([Convert]::ToInt64($match.Groups[1].Value, 16))
        }
    }
    $expectedOffsets = @(for ($offset = 0; $offset -lt $ExpectedBytes; $offset += $chunkBytes) { [int64]$offset })
    $actualOffsets = @($offsets | Sort-Object)
    return $actualOffsets.Count -eq $expectedOffsets.Count -and
        ($actualOffsets -join ',') -eq ($expectedOffsets -join ',')
}

function Wait-SmartSnippetsPhaseEvidence {
    param(
        [Parameter(Mandatory = $true)][ValidateSet('ERASE', 'WRITE', 'READBACK')][string]$Phase,
        [Parameter(Mandatory = $true)][string]$StdoutLog,
        [Parameter(Mandatory = $true)][string]$StderrLog,
        [Parameter(Mandatory = $true)][int64]$ExpectedBytes,
        [Parameter(Mandatory = $true)][bool]$TimedOut,
        [string]$ReadbackPath = '',
        [ValidateRange(1, 10)][int]$TimeoutSec = 3
    )
    if ($TimedOut) {
        return [pscustomobject]@{ Passed=$false; Reason='TIMEOUT' }
    }
    $deadline = [DateTime]::UtcNow.AddSeconds($TimeoutSec)
    do {
        $logs = Get-PhaseLogEvidence -StdoutLog $StdoutLog -StderrLog $StderrLog
        $lines = @($logs.Stdout)
        $commonEvidence =
            @($lines | Where-Object { $_ -match '^Found Cortex-M0\b' }).Count -ge 1 -and
            @($lines | Where-Object { $_ -match '^Firmware File .*jtag_programmer\.bin has been selected for downloading\.$' }).Count -eq 1 -and
            @($lines | Where-Object { $_ -eq 'Successfully downloaded firmware file to the board.' }).Count -eq 1 -and
            @($lines | Where-Object { $_ -match '^Successfully set SPI Flash gpios:' }).Count -eq 1
        $cleanEvidence = $logs.FailureLines.Count -eq 0 -and $logs.UnexpectedStderr.Count -eq 0
        $phaseEvidence = $false
        if ($Phase -eq 'ERASE') {
            $phaseEvidence =
                @($lines | Where-Object { $_ -eq 'SPI Flash memory erasing completed successfully.' }).Count -eq 1 -and
                @($lines | Where-Object { $_ -eq 'Reading memory to verify its contents after erase....' }).Count -eq 1 -and
                (Test-ChunkEvidence -Lines $lines -Operation Read -ExpectedBytes $ExpectedBytes) -and
                @($lines | Where-Object { $_ -eq 'Verification succeeded.' }).Count -eq 1
        }
        elseif ($Phase -eq 'WRITE') {
            $phaseEvidence =
                @($lines | Where-Object { $_ -eq "Started burning memory with $ExpectedBytes bytes of data at address 0x00000." }).Count -eq 1 -and
                (Test-ChunkEvidence -Lines $lines -Operation Write -ExpectedBytes $ExpectedBytes) -and
                @($lines | Where-Object { $_ -eq 'Memory burning completed successfully.' }).Count -eq 1 -and
                @($lines | Where-Object { $_ -eq 'Reading memory to verify its contents after burn....' }).Count -eq 1 -and
                (Test-ChunkEvidence -Lines $lines -Operation Read -ExpectedBytes $ExpectedBytes) -and
                @($lines | Where-Object { $_ -eq 'SPI memory verification succeeded.' }).Count -eq 1
        }
        else {
            $fileExists = -not [string]::IsNullOrWhiteSpace($ReadbackPath) -and
                (Test-Path -LiteralPath $ReadbackPath -PathType Leaf)
            $fileSize = if ($fileExists) { [int64](Get-Item -LiteralPath $ReadbackPath).Length } else { -1 }
            $escapedPath = if ([string]::IsNullOrWhiteSpace($ReadbackPath)) { '(?!)' } else { [regex]::Escape([IO.Path]::GetFullPath($ReadbackPath)) }
            $phaseEvidence =
                @($lines | Where-Object { $_ -eq "Started reading $ExpectedBytes bytes from SPI FLASH memory offset 0x0." }).Count -eq 1 -and
                (Test-ChunkEvidence -Lines $lines -Operation Read -ExpectedBytes $ExpectedBytes) -and
                @($lines | Where-Object { $_ -match "^Memory contents exported successfully to $escapedPath$" }).Count -eq 1 -and
                @($lines | Where-Object { $_ -eq "SPI FLASH memory reading has finished. Read $ExpectedBytes bytes." }).Count -eq 1 -and
                $fileExists -and $fileSize -eq $ExpectedBytes
        }
        if ($commonEvidence -and $cleanEvidence -and $phaseEvidence) {
            return [pscustomobject]@{ Passed=$true; Reason='POSITIVE_EVIDENCE_COMPLETE' }
        }
        Start-Sleep -Milliseconds 100
    } while ([DateTime]::UtcNow -lt $deadline)
    [pscustomobject]@{ Passed=$false; Reason='INCOMPLETE_OR_INVALID_POSITIVE_EVIDENCE' }
}

function Set-AcceptanceExitMetadata {
    param([Parameter(Mandatory = $true)]$Result)
    if (-not $PipelineAcceptanceOnly) { return $Result }
    if ($AcceptanceSmartSnippetsExitMode -eq 'Null') {
        $Result.ExitCode = $null
        $Result.Reason = 'EXIT_'
    }
    elseif ($AcceptanceSmartSnippetsExitMode -eq 'Nonzero') {
        $Result.ExitCode = 23
        $Result.Reason = 'EXIT_23'
    }
    return $Result
}

function Get-SmartSnippetsPhaseTimeout {
    param([Parameter(Mandatory = $true)][int]$DefaultSeconds)
    if ($PipelineAcceptanceOnly -and $AcceptanceSmartSnippetsTimeoutSec -gt 0) {
        return $AcceptanceSmartSnippetsTimeoutSec
    }
    return $DefaultSeconds
}

function Test-ImmutablePreEraseBackupEvidence {
    param(
        [Parameter(Mandatory = $true)][string]$EvidenceDir,
        [Parameter(Mandatory = $true)][string]$ExpectedSha256,
        [Parameter(Mandatory = $true)][int64]$ExpectedBytes
    )
    $expectedSha = $ExpectedSha256.Trim().ToUpperInvariant()
    if ($expectedSha -notmatch '^[0-9A-F]{64}$' -or
        -not (Test-Path -LiteralPath $EvidenceDir -PathType Container)) {
        return [pscustomobject]@{ Passed=$false; Reason='MISSING_OR_INVALID_BACKUP_REFERENCE' }
    }
    $read1 = Join-Path $EvidenceDir 'BOARD1_SPI_READ1.bin'
    $read2 = Join-Path $EvidenceDir 'BOARD1_SPI_READ2.bin'
    if (-not (Test-Path -LiteralPath $read1 -PathType Leaf) -or
        -not (Test-Path -LiteralPath $read2 -PathType Leaf)) {
        return [pscustomobject]@{ Passed=$false; Reason='READ1_OR_READ2_MISSING' }
    }
    $read1File = Get-Item -LiteralPath $read1
    $read2File = Get-Item -LiteralPath $read2
    if ($read1File.Length -ne $ExpectedBytes -or $read2File.Length -ne $ExpectedBytes) {
        return [pscustomobject]@{ Passed=$false; Reason='BACKUP_SIZE_MISMATCH' }
    }
    $read1Sha = Get-Sha256Hex -Path $read1
    $read2Sha = Get-Sha256Hex -Path $read2
    if ($read1Sha -ne $expectedSha -or $read2Sha -ne $expectedSha -or $read1Sha -ne $read2Sha) {
        return [pscustomobject]@{ Passed=$false; Reason='BACKUP_SHA_MISMATCH' }
    }
    [pscustomobject]@{
        Passed=$true
        Reason='IMMUTABLE_PRE_ERASE_BACKUP_VERIFIED'
        EvidenceDir=[IO.Path]::GetFullPath($EvidenceDir)
        Read1=$read1
        Read2=$read2
        Size=$ExpectedBytes
        Sha256=$expectedSha
    }
}

function Wait-FreshBackupEvidence {
    param(
        [Parameter(Mandatory = $true)][string]$StdoutLog,
        [Parameter(Mandatory = $true)][string]$StderrLog,
        [Parameter(Mandatory = $true)][int64]$ExpectedBytes,
        [Parameter(Mandatory = $true)][bool]$TimedOut,
        [ValidateRange(1, 10)][int]$TimeoutSec = 3
    )
    if ($TimedOut) {
        return [pscustomobject]@{ Passed=$false; Reason='TIMEOUT'; Lines=@() }
    }
    $deadline = [DateTime]::UtcNow.AddSeconds($TimeoutSec)
    do {
        $lines = @()
        foreach ($path in @($StdoutLog, $StderrLog)) {
            try {
                if (Test-Path -LiteralPath $path -PathType Leaf) {
                    $lines += @(Get-Content -LiteralPath $path -ErrorAction Stop | ForEach-Object { $_.ToString() })
                }
            }
            catch { }
        }
        $read1Path = Get-EvidenceValue -Lines $lines -Name 'READ1'
        $read2Path = Get-EvidenceValue -Lines $lines -Name 'READ2'
        $read1SizeText = Get-EvidenceValue -Lines $lines -Name 'READ1_SIZE'
        $read2SizeText = Get-EvidenceValue -Lines $lines -Name 'READ2_SIZE'
        $read1Sha = (Get-EvidenceValue -Lines $lines -Name 'READ1_SHA256').ToUpperInvariant()
        $read2Sha = (Get-EvidenceValue -Lines $lines -Name 'READ2_SHA256').ToUpperInvariant()
        $evidenceDir = Get-EvidenceValue -Lines $lines -Name 'EVIDENCE_DIR'
        $successMarker = @($lines | Where-Object { $_ -eq 'NEXT_STATE: SPI_BACKUP_VERIFIED' }).Count -eq 1
        $errorMarker = @($lines | Where-Object { $_ -match '(?i)^(EINK HARNESS: BLOCKED|REASON:)|\b(timeout|failed)\b|\berror:' }).Count -gt 0
        $pathsExist = -not [string]::IsNullOrWhiteSpace($read1Path) -and -not [string]::IsNullOrWhiteSpace($read2Path) -and
            (Test-Path -LiteralPath $read1Path -PathType Leaf) -and (Test-Path -LiteralPath $read2Path -PathType Leaf)
        if ($pathsExist) {
            $read1File = Get-Item -LiteralPath $read1Path
            $read2File = Get-Item -LiteralPath $read2Path
            $actualRead1Sha = Get-Sha256Hex -Path $read1Path
            $actualRead2Sha = Get-Sha256Hex -Path $read2Path
            $sameEvidenceDir = -not [string]::IsNullOrWhiteSpace($evidenceDir) -and
                [IO.Path]::GetFullPath((Split-Path -Parent $read1Path)).Equals([IO.Path]::GetFullPath($evidenceDir), [StringComparison]::OrdinalIgnoreCase) -and
                [IO.Path]::GetFullPath((Split-Path -Parent $read2Path)).Equals([IO.Path]::GetFullPath($evidenceDir), [StringComparison]::OrdinalIgnoreCase)
            if ($successMarker -and -not $errorMarker -and $sameEvidenceDir -and
                $read1File.Length -eq $ExpectedBytes -and $read2File.Length -eq $ExpectedBytes -and
                $read1SizeText -eq [string]$ExpectedBytes -and $read2SizeText -eq [string]$ExpectedBytes -and
                $read1Sha -match '^[0-9A-F]{64}$' -and $read2Sha -match '^[0-9A-F]{64}$' -and
                $read1Sha -eq $read2Sha -and $actualRead1Sha -eq $read1Sha -and $actualRead2Sha -eq $read2Sha) {
                return [pscustomobject]@{
                    Passed=$true; Reason='POSITIVE_EVIDENCE_COMPLETE'; Lines=$lines
                    Read1Path=$read1Path; Read2Path=$read2Path
                    Read1Size=[int64]$read1File.Length; Read2Size=[int64]$read2File.Length
                    Read1Sha=$read1Sha; Read2Sha=$read2Sha
                }
            }
        }
        Start-Sleep -Milliseconds 100
    } while ([DateTime]::UtcNow -lt $deadline)
    [pscustomobject]@{ Passed=$false; Reason='INCOMPLETE_OR_INVALID_POSITIVE_EVIDENCE'; Lines=$lines }
}

$profile = Get-Content -LiteralPath $ProfilePath -Raw | ConvertFrom-Json
$acceptanceModeCount = @(
    @($PreflightAcceptanceOnly, $BackupAcceptanceOnly, $PipelineAcceptanceOnly) |
        Where-Object { [bool]$_ }
).Count
if ($acceptanceModeCount -gt 1) {
    Write-Blocked -Reason 'MULTIPLE_ACCEPTANCE_MODES_FORBIDDEN'
    exit 1
}
if (($AcceptanceSmartSnippetsExitMode -ne 'Native' -or $AcceptanceSmartSnippetsTimeoutSec -ne 0) -and -not $PipelineAcceptanceOnly) {
    Write-Blocked -Reason 'PIPELINE_ACCEPTANCE_OPTIONS_FORBIDDEN'
    exit 1
}
if ($PipelineAcceptanceOnly) {
    $acceptanceRuntimePrefix = [IO.Path]::GetFullPath((Join-Path ([string]$profile.workspace.canonicalPath) '_incoming\EINK_HARNESS_CONTROL_CENTER_RUNTIME')).TrimEnd('\') + '\'
    foreach ($acceptancePath in @([string]$profile.spiBackup.smartSnippetsCli, [string]$profile.spiBackup.jtagProgrammer)) {
        if ([string]::IsNullOrWhiteSpace($acceptancePath) -or
            -not [IO.Path]::GetFullPath($acceptancePath).StartsWith($acceptanceRuntimePrefix, [StringComparison]::OrdinalIgnoreCase)) {
            Write-Blocked -Reason 'PIPELINE_ACCEPTANCE_DEPENDENCY_FORBIDDEN'
            exit 1
        }
    }
}
if (-not (Assert-Workspace `
    -Profile $profile `
    -AllowDirtyTrackedTree:($Mode -eq 'Plan' -or $AllowDirtyTrackedTree)
)) { exit 1 }

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
Write-Output "PROFILE_PATH: $ProfilePath"

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
if ($RecoveryWriteOnly) {
    $recoveryChallengeGuid = [Guid]::Empty
    if (-not [Guid]::TryParseExact($RecoveryConfirmToken, 'N', [ref]$recoveryChallengeGuid)) {
        Write-Blocked -Reason 'RECOVERY_OWNER_CONFIRMATION_REQUIRED'
        exit 1
    }
}
if (-not $RecoveryWriteOnly -and (
    -not [string]::IsNullOrWhiteSpace($RecoveryConfirmToken) -or
    -not [string]::IsNullOrWhiteSpace($PreEraseBackupEvidenceDir) -or
    -not [string]::IsNullOrWhiteSpace($ExpectedPreEraseBackupSha256)
)) {
    Write-Blocked -Reason 'RECOVERY_OPTIONS_FORBIDDEN_OUTSIDE_RECOVERY'
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

$recoveryBackupEvidence = $null
if ($RecoveryWriteOnly) {
    $requestedBackupDir = if ([string]::IsNullOrWhiteSpace($PreEraseBackupEvidenceDir)) { '' } else { [IO.Path]::GetFullPath($PreEraseBackupEvidenceDir) }
    $requestedBackupSha = $ExpectedPreEraseBackupSha256.Trim().ToUpperInvariant()
    if ($PipelineAcceptanceOnly) {
        $runtimePrefix = [IO.Path]::GetFullPath((Join-Path ([string]$profile.workspace.canonicalPath) '_incoming\EINK_HARNESS_CONTROL_CENTER_RUNTIME')).TrimEnd('\') + '\'
        if ([string]::IsNullOrWhiteSpace($requestedBackupDir) -or
            -not $requestedBackupDir.StartsWith($runtimePrefix, [StringComparison]::OrdinalIgnoreCase)) {
            Write-Blocked -Reason 'RECOVERY_ACCEPTANCE_BACKUP_PATH_FORBIDDEN'
            exit 1
        }
    }
    else {
        $canonicalBackupDir = [IO.Path]::GetFullPath((Join-Path ([string]$profile.workspace.canonicalPath) '_incoming\EINK_HARNESS_SPI_BACKUP\20260822_114022'))
        $canonicalBackupSha = '8824C5F9D6F99A1192770225EA14D4C7B861537D193CF77C632D0849FDBC58C1'
        if (-not $requestedBackupDir.Equals($canonicalBackupDir, [StringComparison]::OrdinalIgnoreCase) -or
            $requestedBackupSha -ne $canonicalBackupSha) {
            Write-Blocked -Reason 'RECOVERY_PRE_ERASE_BACKUP_REFERENCE_MISMATCH'
            exit 1
        }
    }
    $recoveryBackupEvidence = Test-ImmutablePreEraseBackupEvidence `
        -EvidenceDir $requestedBackupDir `
        -ExpectedSha256 $requestedBackupSha `
        -ExpectedBytes ([int64]$profile.spiBurn.expectedBytes)
    if (-not $recoveryBackupEvidence.Passed) {
        Write-Blocked -Reason 'RECOVERY_PRE_ERASE_BACKUP_INVALID'
        Write-Output "RECOVERY_BACKUP_EVIDENCE: $($recoveryBackupEvidence.Reason)"
        exit 1
    }
}

$stamp = Get-Date -Format 'yyyyMMdd_HHmmss'
$evidenceDir = Join-Path ([string]$burn.evidenceRoot) $stamp
[void](New-Item -ItemType Directory -Path $evidenceDir -Force)
[System.IO.File]::WriteAllText((Join-Path $evidenceDir 'packed.sha256.txt'), "$packedHash  $packedPath`r`n", [System.Text.UTF8Encoding]::new($false))

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

$preflightPhaseName = if ($RecoveryWriteOnly) { 'RECOVERY_PREFLIGHT' } else { 'HARDWARE_PREFLIGHT' }
Write-PhaseState -Phase $preflightPhaseName -Status 'RUNNING' -DestructiveStarted $false
$preflightPath = Join-Path $evidenceDir 'hardware-preflight.bin'
$preflightArgs = $common + @(
    '-cmd', 'read',
    '-file', "`"$preflightPath`"",
    '-offset', [string]$config.offset,
    '-length', '1',
    '-max', [string]$config.max,
    '-y'
)
$preflightStdout = Join-Path $evidenceDir 'hardware-preflight.stdout.log'
$preflightStderr = Join-Path $evidenceDir 'hardware-preflight.stderr.log'
$preflight = Invoke-SmartSnippets -Cli ([string]$config.smartSnippetsCli) -Arguments $preflightArgs -StdoutLog $preflightStdout -StderrLog $preflightStderr -TimeoutSec (Get-SmartSnippetsPhaseTimeout -DefaultSeconds 30)
$preflight = Set-AcceptanceExitMetadata -Result $preflight
$preflightEvidence = if ($preflight.TimedOut) {
    [pscustomobject]@{ Passed = $false; Reason = 'SMARTSNIPPETS_TIMEOUT' }
}
else {
    Wait-HardwarePreflightEvidence -ReadPath $preflightPath -StdoutLog $preflightStdout -TimeoutSec 3
}
if (-not $preflightEvidence.Passed) {
    Write-PhaseState -Phase $preflightPhaseName -Status 'FAIL' -DestructiveStarted $false -Reason 'BOARD_NOT_CONNECTED'
    Write-Blocked -Reason 'BOARD_NOT_CONNECTED'
    Write-Output "PREFLIGHT_EVIDENCE: $($preflightEvidence.Reason)"
    Write-Output "EVIDENCE_DIR: $evidenceDir"
    exit 1
}
Write-Output 'PREFLIGHT_EVIDENCE: POSITIVE_EVIDENCE_COMPLETE'
Write-PhaseState -Phase $preflightPhaseName -Status 'PASS' -DestructiveStarted $false
if ($PreflightAcceptanceOnly) {
    Write-Output 'EINK HARNESS: PASS'
    Write-Output 'ACTION: SPI-BURN-PREFLIGHT-ACCEPTANCE'
    Write-Output 'NEXT_STATE: PREFLIGHT_ACCEPTANCE_COMPLETE'
    exit 0
}

if ($RecoveryWriteOnly) {
    Write-Output 'RECOVERY_MODE: CURRENT_ARTIFACT'
    Write-Output 'NORMAL_FRESH_BACKUP: SKIPPED'
    Write-Output 'ERASE: SKIPPED'
    Write-Output "PRE_ERASE_BACKUP_EVIDENCE: $($recoveryBackupEvidence.EvidenceDir)"
    Write-Output "PRE_ERASE_BACKUP_SHA256: $($recoveryBackupEvidence.Sha256)"
}
else {
$canonicalBackupRunner = Join-Path $PSScriptRoot 'eink-spi-backup.ps1'
$backupRunner = if ([string]::IsNullOrWhiteSpace($BackupRunnerPath)) { $canonicalBackupRunner } else { [IO.Path]::GetFullPath($BackupRunnerPath) }
if (-not [string]::IsNullOrWhiteSpace($BackupRunnerPath)) {
    $runtimePrefix = [IO.Path]::GetFullPath((Join-Path ([string]$profile.workspace.canonicalPath) '_incoming\EINK_HARNESS_CONTROL_CENTER_RUNTIME')).TrimEnd('\') + '\'
    if ((-not $BackupAcceptanceOnly -and -not $PipelineAcceptanceOnly) -or
        -not $backupRunner.StartsWith($runtimePrefix, [StringComparison]::OrdinalIgnoreCase)) {
        Write-Blocked -Reason 'BACKUP_ACCEPTANCE_RUNNER_FORBIDDEN'
        exit 1
    }
}
if (($BackupTimeoutSec -ne 180 -or $AcceptanceBackupExitMode -ne 'Native') -and
    -not $BackupAcceptanceOnly -and -not $PipelineAcceptanceOnly) {
    Write-Blocked -Reason 'BACKUP_ACCEPTANCE_OPTIONS_FORBIDDEN'
    exit 1
}
Write-PhaseState -Phase 'SPI_BACKUP' -Status 'RUNNING' -DestructiveStarted $false
$backupStdout = Join-Path $evidenceDir 'fresh-backup.stdout.log'
$backupStderr = Join-Path $evidenceDir 'fresh-backup.stderr.log'
$backup = Invoke-PowerShellPhase -Arguments @('-NoProfile','-ExecutionPolicy','Bypass','-File',"`"$backupRunner`"",'-ProfilePath',"`"$ProfilePath`"",'-JtagSerial',$serial,'-AllowDirtyTrackedTree') -StdoutLog $backupStdout -StderrLog $backupStderr -TimeoutSec $BackupTimeoutSec
if ($AcceptanceBackupExitMode -eq 'Null') { $backup.ExitCode = $null; $backup.Reason = 'EXIT_' }
elseif ($AcceptanceBackupExitMode -eq 'Nonzero') { $backup.ExitCode = 23; $backup.Reason = 'EXIT_23' }
$backupEvidence = Wait-FreshBackupEvidence -StdoutLog $backupStdout -StderrLog $backupStderr -ExpectedBytes ([int64]$config.expectedBytes) -TimedOut ([bool]$backup.TimedOut) -TimeoutSec 3
[System.IO.File]::WriteAllLines((Join-Path $evidenceDir 'fresh-backup.log'), @($backupEvidence.Lines), [System.Text.UTF8Encoding]::new($false))
if (-not $backupEvidence.Passed) {
    Write-PhaseState -Phase 'SPI_BACKUP' -Status 'FAIL' -DestructiveStarted $false -Reason "FRESH_BACKUP_$($backupEvidence.Reason)"
    Write-Blocked -Reason 'FRESH_BACKUP_FAILED'
    Write-Output "FRESH_BACKUP_EVIDENCE: $($backupEvidence.Reason)"
    Write-Output "EVIDENCE_DIR: $evidenceDir"
    exit 1
}
Write-Output 'FRESH_BACKUP_EVIDENCE: POSITIVE_EVIDENCE_COMPLETE'
Write-PhaseState -Phase 'SPI_BACKUP' -Status 'PASS' -DestructiveStarted $false

$backupHashLines = @($backupEvidence.Lines | Where-Object { $_ -match '^READ[12]_SHA256:\s+[0-9A-F]{64}$' })
if ($backupHashLines.Count -ne 2) {
    Write-Blocked -Reason 'FRESH_BACKUP_HASH_EVIDENCE_MISSING'
    Write-Output "EVIDENCE_DIR: $evidenceDir"
    exit 1
}
if ($BackupAcceptanceOnly) {
    Write-Output 'EINK HARNESS: PASS'
    Write-Output 'ACTION: SPI-BURN-BACKUP-ACCEPTANCE'
    Write-Output "READ1_SIZE: $($backupEvidence.Read1Size)"
    Write-Output "READ1_SHA256: $($backupEvidence.Read1Sha)"
    Write-Output "READ2_SIZE: $($backupEvidence.Read2Size)"
    Write-Output "READ2_SHA256: $($backupEvidence.Read2Sha)"
    Write-Output 'NEXT_STATE: BACKUP_ACCEPTANCE_COMPLETE'
    exit 0
}

Write-PhaseState -Phase 'ERASE' -Status 'RUNNING' -DestructiveStarted $true
$eraseArgs = $common + @('-cmd', 'erase', '-verify', '-y')
$eraseStdout = Join-Path $evidenceDir 'erase.stdout.log'
$eraseStderr = Join-Path $evidenceDir 'erase.stderr.log'
$erase = Invoke-SmartSnippets -Cli ([string]$config.smartSnippetsCli) -Arguments $eraseArgs -StdoutLog $eraseStdout -StderrLog $eraseStderr -TimeoutSec (Get-SmartSnippetsPhaseTimeout -DefaultSeconds 90)
$erase = Set-AcceptanceExitMetadata -Result $erase
$eraseEvidence = Wait-SmartSnippetsPhaseEvidence -Phase ERASE -StdoutLog $eraseStdout -StderrLog $eraseStderr -ExpectedBytes ([int64]$burn.expectedBytes) -TimedOut ([bool]$erase.TimedOut)
if (-not $eraseEvidence.Passed) {
    Write-PhaseState -Phase 'ERASE' -Status 'FAIL' -DestructiveStarted $true -Reason "SPI_ERASE_$($eraseEvidence.Reason)"
    Write-Blocked -Reason "SPI_ERASE_$($eraseEvidence.Reason)"
    Write-Output "ERASE_EVIDENCE: $($eraseEvidence.Reason)"
    Write-Output "EVIDENCE_DIR: $evidenceDir"
    exit 1
}
Write-Output 'ERASE_EVIDENCE: POSITIVE_EVIDENCE_COMPLETE'
Write-PhaseState -Phase 'ERASE' -Status 'PASS' -DestructiveStarted $true
}

$writePhaseName = if ($RecoveryWriteOnly) { 'RECOVERY_WRITE' } else { 'WRITE' }
Write-PhaseState -Phase $writePhaseName -Status 'RUNNING' -DestructiveStarted $true
$writeArgs = $common + @(
    '-cmd', 'write',
    '-file', "`"$packedPath`"",
    '-offset', [string]$burn.offset,
    '-max', [string]$burn.max,
    '-verify',
    '-y'
)
$writeStdout = Join-Path $evidenceDir 'write.stdout.log'
$writeStderr = Join-Path $evidenceDir 'write.stderr.log'
$write = Invoke-SmartSnippets -Cli ([string]$config.smartSnippetsCli) -Arguments $writeArgs -StdoutLog $writeStdout -StderrLog $writeStderr -TimeoutSec (Get-SmartSnippetsPhaseTimeout -DefaultSeconds 180)
$write = Set-AcceptanceExitMetadata -Result $write
$writeEvidence = Wait-SmartSnippetsPhaseEvidence -Phase WRITE -StdoutLog $writeStdout -StderrLog $writeStderr -ExpectedBytes ([int64]$burn.expectedBytes) -TimedOut ([bool]$write.TimedOut)
if (-not $writeEvidence.Passed) {
    Write-PhaseState -Phase $writePhaseName -Status 'FAIL' -DestructiveStarted $true -Reason "SPI_WRITE_$($writeEvidence.Reason)"
    Write-Blocked -Reason "SPI_WRITE_$($writeEvidence.Reason)"
    Write-Output "WRITE_EVIDENCE: $($writeEvidence.Reason)"
    Write-Output "EVIDENCE_DIR: $evidenceDir"
    exit 1
}
Write-Output 'WRITE_EVIDENCE: POSITIVE_EVIDENCE_COMPLETE'
Write-PhaseState -Phase $writePhaseName -Status 'PASS' -DestructiveStarted $true

$readbackPhaseName = if ($RecoveryWriteOnly) { 'RECOVERY_READBACK' } else { 'READBACK' }
Write-PhaseState -Phase $readbackPhaseName -Status 'RUNNING' -DestructiveStarted $true
$readbackPath = Join-Path $evidenceDir 'SPI_READBACK.bin'
$readArgs = $common + @(
    '-cmd', 'read',
    '-file', "`"$readbackPath`"",
    '-offset', [string]$config.offset,
    '-length', [string]$config.length,
    '-max', [string]$config.max,
    '-y'
)
$readbackStdout = Join-Path $evidenceDir 'readback.stdout.log'
$readbackStderr = Join-Path $evidenceDir 'readback.stderr.log'
$read = Invoke-SmartSnippets -Cli ([string]$config.smartSnippetsCli) -Arguments $readArgs -StdoutLog $readbackStdout -StderrLog $readbackStderr -TimeoutSec (Get-SmartSnippetsPhaseTimeout -DefaultSeconds 180)
$read = Set-AcceptanceExitMetadata -Result $read
$readEvidence = Wait-SmartSnippetsPhaseEvidence -Phase READBACK -StdoutLog $readbackStdout -StderrLog $readbackStderr -ExpectedBytes ([int64]$burn.expectedBytes) -TimedOut ([bool]$read.TimedOut) -ReadbackPath $readbackPath
if (-not $readEvidence.Passed) {
    Write-PhaseState -Phase $readbackPhaseName -Status 'FAIL' -DestructiveStarted $true -Reason "SPI_READBACK_$($readEvidence.Reason)"
    Write-Blocked -Reason "SPI_READBACK_$($readEvidence.Reason)"
    Write-Output "READBACK_EVIDENCE: $($readEvidence.Reason)"
    Write-Output "EVIDENCE_DIR: $evidenceDir"
    exit 1
}

$readbackFile = Get-Item -LiteralPath $readbackPath
if ($readbackFile.Length -ne [int64]$burn.expectedBytes) {
    Write-PhaseState -Phase $readbackPhaseName -Status 'FAIL' -DestructiveStarted $true -Reason "SPI_READBACK_SIZE_$($readbackFile.Length)"
    Write-Blocked -Reason "SPI_READBACK_SIZE_$($readbackFile.Length)"
    Write-Output "EVIDENCE_DIR: $evidenceDir"
    exit 1
}
Write-PhaseState -Phase $readbackPhaseName -Status 'PASS' -DestructiveStarted $true
Write-Output 'READBACK_EVIDENCE: POSITIVE_EVIDENCE_COMPLETE'

$shaPhaseName = if ($RecoveryWriteOnly) { 'RECOVERY_SHA_VERIFY' } else { 'SHA_VERIFY' }
Write-PhaseState -Phase $shaPhaseName -Status 'RUNNING' -DestructiveStarted $true
$readbackHash = Get-Sha256Hex -Path $readbackPath
if ($readbackHash -ne $packedHash) {
    Write-PhaseState -Phase $shaPhaseName -Status 'FAIL' -DestructiveStarted $true -Reason 'SPI_READBACK_HASH_MISMATCH'
    Write-Blocked -Reason 'SPI_READBACK_HASH_MISMATCH'
    Write-Output "PACKED_SHA256: $packedHash"
    Write-Output "READBACK_SHA256: $readbackHash"
    Write-Output "EVIDENCE_DIR: $evidenceDir"
    exit 1
}
Write-PhaseState -Phase $shaPhaseName -Status 'PASS' -DestructiveStarted $true

if ($PipelineAcceptanceOnly) {
    Write-Output 'EINK HARNESS: PASS'
    Write-Output 'ACTION: SPI-BURN-PIPELINE-ACCEPTANCE'
    Write-Output "PACKED_SHA256: $packedHash"
    Write-Output "READBACK_SHA256: $readbackHash"
    Write-Output "EVIDENCE_DIR: $evidenceDir"
    Write-Output 'NEXT_STATE: PIPELINE_ACCEPTANCE_COMPLETE'
    exit 0
}

Write-Output 'EINK HARNESS: PASS'
Write-Output $(if ($RecoveryWriteOnly) { 'ACTION: SPI-RECOVERY-WRITE' } else { 'ACTION: SPI-BURN' })
Write-Output "JTAG: $serial"
Write-Output "PACKED_BIN: $packedPath"
Write-Output "PACKED_SIZE: $($packedFile.Length)"
Write-Output "PACKED_SHA256: $packedHash"
Write-Output "READBACK: $readbackPath"
Write-Output "READBACK_SIZE: $($readbackFile.Length)"
Write-Output "READBACK_SHA256: $readbackHash"
if ($RecoveryWriteOnly) {
    Write-Output "PRE_ERASE_BACKUP_SHA256: $($recoveryBackupEvidence.Sha256)"
    Write-Output 'RECOVERY_TARGET: CURRENT_ARTIFACT'
}
Write-Output "EVIDENCE_DIR: $evidenceDir"
Write-Output 'NEXT_STATE: SPI_BURN_VERIFIED'
exit 0
