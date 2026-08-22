[CmdletBinding()]
param(
    [switch]$TargetedBackupOnly,
    [switch]$TargetedPipelineOnly,
    [switch]$TargetedRecoveryOnly
)

$ErrorActionPreference = 'Stop'
$repoRoot = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path
$serverPath = Join-Path $repoRoot 'tools\harness\control-center\server.ps1'
$burnPath = Join-Path $repoRoot 'scripts\eink-spi-burn.ps1'
$profilePath = Join-Path $repoRoot 'tools\harness\eink-profile.json'
$prepareStatePath = Join-Path $repoRoot '_incoming\EINK_HARNESS_PREPARE_TEST\control-center-prepare-state.json'
$burnStatePath = Join-Path $repoRoot '_incoming\EINK_HARNESS_CONTROL_CENTER_FINALIZE\burn-verification-state.json'
$indexPath = Join-Path $repoRoot 'tools\harness\control-center\index.html'
$launcherPath = Join-Path $repoRoot 'scripts\eink-control-center.ps1'
$runtimeRoot = Join-Path $repoRoot '_incoming\EINK_HARNESS_CONTROL_CENTER_RUNTIME'
$acceptanceRunId = '{0}_{1}_{2}' -f (
    (Get-Date).ToUniversalTime().ToString('yyyyMMddTHHmmssfffZ'),
    $PID,
    [Guid]::NewGuid().ToString('N')
)
$temporaryLogPaths = New-Object 'Collections.Generic.List[string]'

function Write-AcceptancePhase {
    param(
        [Parameter(Mandatory=$true)][string]$Name,
        [Parameter(Mandatory=$true)][string]$State,
        [string]$Detail = ''
    )

    $suffix = if ([string]::IsNullOrWhiteSpace($Detail)) {
        ''
    }
    else {
        " $Detail"
    }
    Write-Host ('ACCEPTANCE_PHASE [{0}] {1} {2}{3}' -f (
        (Get-Date).ToUniversalTime().ToString('o'),
        $Name,
        $State,
        $suffix
    ))
}

function Stop-ExactStartedProcess {
    param(
        [Parameter(Mandatory=$true)][Diagnostics.Process]$Process,
        [Parameter(Mandatory=$true)][int64]$StartTicks,
        [Parameter(Mandatory=$true)][string]$ExecutablePath,
        [Parameter(Mandatory=$true)][string]$Label
    )

    try {
        $running = Get-Process -Id $Process.Id -ErrorAction Stop
        if (
            $running.StartTime.ToUniversalTime().Ticks -ne $StartTicks -or
            [IO.Path]::GetFullPath($running.Path) -ne
                [IO.Path]::GetFullPath($ExecutablePath)
        ) {
            throw "$Label exact process identity mismatch."
        }
        Stop-Process -Id $running.Id -Force
        Write-AcceptancePhase -Name $Label -State 'CLEANUP_PASS' -Detail "PID=$($running.Id)"
    }
    catch [Microsoft.PowerShell.Commands.ProcessCommandException] {
        Write-AcceptancePhase -Name $Label -State 'CLEANUP_ALREADY_EXITED'
    }
}

function Invoke-PowerShellChild {
    param(
        [Parameter(Mandatory=$true)][string]$Label,
        [Parameter(Mandatory=$true)][string[]]$Arguments,
        [ValidateRange(1, 120)][int]$TimeoutSec = 30,
        [switch]$BackgroundDescendant
    )

    if (-not (Test-Path -LiteralPath $runtimeRoot -PathType Container)) {
        [void](New-Item -ItemType Directory -Path $runtimeRoot -Force)
    }
    $safeLabel = $Label -replace '[^A-Za-z0-9_-]', '_'
    $stdoutPath = Join-Path $runtimeRoot "$acceptanceRunId.$safeLabel.stdout.log"
    $stderrPath = Join-Path $runtimeRoot "$acceptanceRunId.$safeLabel.stderr.log"
    if (-not $BackgroundDescendant) {
        $temporaryLogPaths.Add($stdoutPath)
        $temporaryLogPaths.Add($stderrPath)
    }

    Write-AcceptancePhase -Name $Label -State 'PROCESS_START_BEGIN'
    $startProcessParameters = @{
        FilePath = 'powershell.exe'
        ArgumentList = $Arguments
        WindowStyle = 'Hidden'
        PassThru = $true
    }
    if (-not $BackgroundDescendant) {
        $startProcessParameters.RedirectStandardOutput = $stdoutPath
        $startProcessParameters.RedirectStandardError = $stderrPath
    }
    $process = Start-Process @startProcessParameters
    $startTicks = $process.StartTime.ToUniversalTime().Ticks
    $processExecutablePath = $process.Path
    $processClosed = $false
    Write-AcceptancePhase -Name $Label -State 'PROCESS_START_PASS' -Detail "PID=$($process.Id)"

    try {
        Write-AcceptancePhase -Name $Label -State 'PROCESS_WAIT_BEGIN' -Detail "TIMEOUT_SEC=$TimeoutSec"
        if (-not $process.WaitForExit($TimeoutSec * 1000)) {
            throw "$Label process wait timed out after $TimeoutSec seconds."
        }
        $process.WaitForExit()
        $process.Refresh()
        $childExitCode = [int]$process.ExitCode
        $process.Close()
        $processClosed = $true
        Write-AcceptancePhase -Name $Label -State 'PROCESS_WAIT_PASS' -Detail "EXIT_CODE=$childExitCode"

        Write-AcceptancePhase -Name $Label -State 'STDOUT_READ_BEGIN'
        $stdout = if ($BackgroundDescendant) {
            Write-AcceptancePhase -Name $Label -State 'STDOUT_READ_SKIPPED' -Detail 'BACKGROUND_DESCENDANT_HANDLE_RACE'
            @()
        }
        else {
            $captured = @()
            for ($readAttempt = 0; $readAttempt -lt 20 -and $captured.Count -eq 0; $readAttempt++) {
                if (Test-Path -LiteralPath $stdoutPath -PathType Leaf) {
                    $captured = @(Read-SharedUtf8Lines -Path $stdoutPath)
                }
                if ($captured.Count -eq 0) { Start-Sleep -Milliseconds 100 }
            }
            $captured
        }
        if (-not $BackgroundDescendant) {
            Write-AcceptancePhase -Name $Label -State 'STDOUT_READ_PASS' -Detail "LINES=$($stdout.Count)"
        }

        Write-AcceptancePhase -Name $Label -State 'STDERR_READ_BEGIN'
        $stderr = if ($BackgroundDescendant) {
            Write-AcceptancePhase -Name $Label -State 'STDERR_READ_SKIPPED' -Detail 'BACKGROUND_DESCENDANT_HANDLE_RACE'
            @()
        }
        else {
            if (Test-Path -LiteralPath $stderrPath -PathType Leaf) {
                @(Read-SharedUtf8Lines -Path $stderrPath)
            }
            else { @() }
        }
        if (-not $BackgroundDescendant) {
            Write-AcceptancePhase -Name $Label -State 'STDERR_READ_PASS' -Detail "LINES=$($stderr.Count)"
        }

        [PSCustomObject]@{
            ExitCode = $childExitCode
            Stdout = $stdout
            Stderr = $stderr
            Pid = $process.Id
            StartTicks = $startTicks
        }
    }
    finally {
        if (-not $processClosed -and -not $process.HasExited) {
            Stop-ExactStartedProcess `
                -Process $process `
                -StartTicks $startTicks `
                -ExecutablePath $processExecutablePath `
                -Label $Label
        }
    }
}

function Invoke-CapturedPowerShellChild {
    param(
        [Parameter(Mandatory=$true)][string]$Label,
        [Parameter(Mandatory=$true)][string[]]$Arguments,
        [ValidateRange(1,120)][int]$TimeoutSec = 30
    )
    Write-AcceptancePhase -Name $Label -State 'PROCESS_START_BEGIN'
    $startInfo = New-Object Diagnostics.ProcessStartInfo
    $startInfo.FileName = 'powershell.exe'
    $startInfo.Arguments = $Arguments -join ' '
    $startInfo.UseShellExecute = $false
    $startInfo.CreateNoWindow = $true
    $startInfo.RedirectStandardOutput = $true
    $startInfo.RedirectStandardError = $true
    $process = New-Object Diagnostics.Process
    $process.StartInfo = $startInfo
    [void]$process.Start()
    $startTicks = $process.StartTime.ToUniversalTime().Ticks
    $processExecutablePath = $process.Path
    $stdoutTask = $process.StandardOutput.ReadToEndAsync()
    $stderrTask = $process.StandardError.ReadToEndAsync()
    Write-AcceptancePhase -Name $Label -State 'PROCESS_START_PASS' -Detail "PID=$($process.Id)"
    try {
        if (-not $process.WaitForExit($TimeoutSec * 1000)) {
            Stop-ExactStartedProcess -Process $process -StartTicks $startTicks -ExecutablePath $processExecutablePath -Label $Label
            throw "$Label process wait timed out after $TimeoutSec seconds."
        }
        $process.WaitForExit()
        $stdout = $stdoutTask.GetAwaiter().GetResult()
        $stderr = $stderrTask.GetAwaiter().GetResult()
        [pscustomobject]@{
            ExitCode = [int]$process.ExitCode
            Stdout = @($stdout -split "`r?`n" | Where-Object { $_ })
            Stderr = @($stderr -split "`r?`n" | Where-Object { $_ })
            Pid = [int]$process.Id
            StartTicks = [int64]$startTicks
        }
    }
    finally {
        if (-not $process.HasExited) {
            Stop-ExactStartedProcess -Process $process -StartTicks $startTicks -ExecutablePath $processExecutablePath -Label $Label
        }
        $process.Dispose()
    }
}

function Get-FreeLoopbackPort {
    $listener = New-Object Net.Sockets.TcpListener(
        [Net.IPAddress]::Loopback,
        0
    )
    try {
        $listener.Start()
        ([Net.IPEndPoint]$listener.LocalEndpoint).Port
    }
    finally {
        $listener.Stop()
    }
}

function Read-SharedUtf8Lines {
    param([Parameter(Mandatory=$true)][string]$Path)

    $stream = $null
    $reader = $null
    try {
        $stream = New-Object IO.FileStream(
            $Path,
            [IO.FileMode]::Open,
            [IO.FileAccess]::Read,
            ([IO.FileShare]::ReadWrite -bor [IO.FileShare]::Delete)
        )
        $reader = New-Object IO.StreamReader(
            $stream,
            [Text.Encoding]::UTF8,
            $true
        )
        @($reader.ReadToEnd() -split "`r?`n" | Where-Object { $_ })
    }
    finally {
        if ($reader) { $reader.Dispose() }
        elseif ($stream) { $stream.Dispose() }
    }
}

$profile = [IO.File]::ReadAllText($profilePath, [Text.Encoding]::UTF8) |
    ConvertFrom-Json
$burnState = [IO.File]::ReadAllText($burnStatePath, [Text.Encoding]::UTF8) |
    ConvertFrom-Json
$packedBin = [string]$burnState.artifactPath

if ([string]::IsNullOrWhiteSpace($packedBin)) {
    $prepareState = [IO.File]::ReadAllText($prepareStatePath, [Text.Encoding]::UTF8) |
        ConvertFrom-Json
    $prepareManifest = [IO.File]::ReadAllText(
        [string]$prepareState.manifestPath,
        [Text.Encoding]::UTF8
    ) | ConvertFrom-Json
    $packedBin = [string]$prepareManifest.packed.path
}
if (-not (Test-Path -LiteralPath $packedBin -PathType Leaf)) {
    throw 'Locked prepare artifact is missing.'
}

$serverText = [IO.File]::ReadAllText($serverPath, [Text.Encoding]::UTF8)
$burnText = [IO.File]::ReadAllText($burnPath, [Text.Encoding]::UTF8)
$indexText = [IO.File]::ReadAllText($indexPath, [Text.Encoding]::UTF8)
$launcherText = [IO.File]::ReadAllText($launcherPath, [Text.Encoding]::UTF8)

if ($burnText -match '(?s)param\s*\(.*?ProfilePath\s*=\s*\(\s*Join-Path\s+\$PSScriptRoot') {
    throw 'ProfilePath still relies on PSScriptRoot during parameter binding.'
}
if (-not $burnText.Contains('$scriptDirectory = Split-Path -Parent $MyInvocation.MyCommand.Path')) {
    throw 'Burn script does not resolve its directory after parameter binding.'
}
if (
    -not $serverText.Contains('function Invoke-EinkSpiBurnScript') -or
    $serverText -notmatch "'-ProfilePath',\s*\r?\n\s*\`$profilePath"
) {
    throw 'Control Center burn execution path does not pass the canonical profile explicitly.'
}
foreach ($phase in @('HARDWARE_PREFLIGHT','SPI_BACKUP','ERASE','WRITE','READBACK','SHA_VERIFY')) {
    if (-not $burnText.Contains("'$phase'") -or -not $serverText.Contains("'$phase'")) {
        throw "Burn phase is not represented end-to-end: $phase"
    }
}
foreach ($phase in @('RECOVERY_PREFLIGHT','RECOVERY_WRITE','RECOVERY_READBACK','RECOVERY_SHA_VERIFY')) {
    if (-not $burnText.Contains("'$phase'") -or -not $serverText.Contains("'$phase'")) {
        throw "Recovery phase is not represented end-to-end: $phase"
    }
}
foreach ($marker in @(
    'function Start-EinkBurnWorker',
    'function Sync-BurnRuntimeState',
    'BOARD_NOT_CONNECTED',
    'RECOVERY_REQUIRED',
    'PreflightAcceptanceOnly',
    'COPY SHA',
    'readyBurnBanner',
    'burnProgress'
)) {
    if (-not $serverText.Contains($marker) -and
        -not $burnText.Contains($marker) -and
        -not $indexText.Contains($marker)) {
        throw "Burn safety/UX marker missing: $marker"
    }
}
foreach ($marker in @(
    'function Wait-FreshBackupEvidence',
    'READ1_SIZE',
    'READ2_SIZE',
    'READ1_SHA256',
    'READ2_SHA256',
    'NEXT_STATE: SPI_BACKUP_VERIFIED',
    'FRESH_BACKUP_EVIDENCE: POSITIVE_EVIDENCE_COMPLETE'
)) {
    if (-not $burnText.Contains($marker)) {
        throw "Fresh-backup positive evidence marker missing: $marker"
    }
}
foreach ($marker in @(
    'function Wait-HardwarePreflightEvidence',
    'Found Cortex-M0',
    'jtag_programmer\.bin has been selected for downloading',
    'Successfully downloaded firmware file to the board',
    'Successfully set SPI Flash gpios',
    'Memory contents exported successfully',
    'POSITIVE_EVIDENCE_COMPLETE'
)) {
    if (-not $burnText.Contains($marker)) {
        throw "Strict positive preflight evidence marker missing: $marker"
    }
}
if ($serverText -notmatch "Synchronous real burn execution is forbidden" -or
    $burnText -notmatch 'WaitForExit\(\$TimeoutSec \* 1000\)') {
    throw 'Real burn path is not asynchronous with bounded external process waits.'
}

if (
    $indexText -notmatch 'const feedback = \$\("einkPhysicalFeedback"\)\.value\.trim\(\);' -or
    $indexText -notmatch 'post\("/api/projects/eink/actions/physical-pass", \{ feedback, evidence \}\)'
) {
    throw 'PHYSICAL PASS UI does not send textarea feedback in the server feedback field.'
}

$stopHarnessMarker = [Text.Encoding]::UTF8.GetString(
    [Convert]::FromBase64String('ROG7qk5HIEhBUk5FU1M=')
)
foreach ($marker in @(
    'START HARNESS',
    'RESTART HARNESS',
    $stopHarnessMarker,
    '/api/lifecycle/start',
    '/api/lifecycle/restart',
    '/api/lifecycle/stop'
)) {
    if (-not $indexText.Contains($marker) -and -not $serverText.Contains($marker)) {
        throw "Lifecycle marker missing: $marker"
    }
}

if (
    -not $launcherText.Contains('-WindowStyle Hidden') -or
    -not $launcherText.Contains('Test-TrackedProcessIdentity') -or
    $launcherText.Contains('-WindowStyle Minimized')
) {
    throw 'Launcher is not using hidden exact-process lifecycle control.'
}

$firmwarePath = Join-Path $repoRoot 'firmware\active\HINK213_CLOCK_22_BASE\src\user_custs1_impl.c'
$firmwareHashBefore = (Get-FileHash -LiteralPath $firmwarePath -Algorithm SHA256).Hash
$artifactHashBefore = (Get-FileHash -LiteralPath $packedBin -Algorithm SHA256).Hash
$evidenceRoot = [string]$profile.spiBurn.evidenceRoot
$evidenceBefore = @(
    if (Test-Path -LiteralPath $evidenceRoot -PathType Container) {
        Get-ChildItem -LiteralPath $evidenceRoot -Recurse -File |
            ForEach-Object { $_.FullName + '|' + $_.Length + '|' + $_.LastWriteTimeUtc.Ticks }
    }
) | Sort-Object

$port = Get-FreeLoopbackPort
$burnPlanProcess = Invoke-CapturedPowerShellChild `
    -Label 'BURN_PLAN' `
    -TimeoutSec 30 `
    -Arguments @(
        '-NoProfile', '-ExecutionPolicy', 'Bypass',
        '-File', "`"$serverPath`"",
        '-Port', [string]$port,
        '-NoBrowser', '-BurnPlanAcceptance',
        '-BurnPlanPackedBin', "`"$packedBin`""
    )
$output = @($burnPlanProcess.Stdout) + @($burnPlanProcess.Stderr)
$exitCode = $burnPlanProcess.ExitCode

if (
    $exitCode -ne 0 -or
    -not ($output -match '^EINK HARNESS: PASS$') -or
    -not ($output -match '^ACTION: SPI-BURN-PLAN$') -or
    -not ($output -match '^NEXT_STATE: OWNER_BURN_CONFIRMATION_REQUIRED$')
) {
    throw "Control Center burn PLAN path failed.`n$($output -join "`n")"
}

if ($output -match '(?i)SmartSnippets|SPI_ERASE|SPI_WRITE|SPI_READBACK') {
    throw 'PLAN output indicates that a hardware operation was reached.'
}

$evidenceAfter = @(
    if (Test-Path -LiteralPath $evidenceRoot -PathType Container) {
        Get-ChildItem -LiteralPath $evidenceRoot -Recurse -File |
            ForEach-Object { $_.FullName + '|' + $_.Length + '|' + $_.LastWriteTimeUtc.Ticks }
    }
) | Sort-Object

if (@(Compare-Object $evidenceBefore $evidenceAfter).Count -ne 0) {
    throw 'PLAN path changed SPI burn evidence; hardware path may have been entered.'
}
if ((Get-FileHash -LiteralPath $firmwarePath -Algorithm SHA256).Hash -ne $firmwareHashBefore) {
    throw 'Firmware source changed during burn PLAN acceptance.'
}
if ((Get-FileHash -LiteralPath $packedBin -Algorithm SHA256).Hash -ne $artifactHashBefore) {
    throw 'Locked artifact changed during burn PLAN acceptance.'
}

$absentPort = Get-FreeLoopbackPort
$absentRoot = Join-Path $runtimeRoot "$acceptanceRunId.board-absent"
[void](New-Item -ItemType Directory -Path $absentRoot -Force)
$fakeCliPath = Join-Path $absentRoot 'fake-smartsnippets.cmd'
$fakeInvocationPath = Join-Path $absentRoot 'invocations.log'
$fakeProfilePath = Join-Path $absentRoot 'eink-profile.board-absent.json'
$fixtureProfile = [IO.File]::ReadAllText($profilePath, [Text.Encoding]::UTF8) | ConvertFrom-Json
$fixtureProfile.spiBackup.smartSnippetsCli = $fakeCliPath
[IO.File]::WriteAllLines($fakeCliPath, @(
    '@echo off',
    "echo %*>>`"$fakeInvocationPath`"",
    'echo Failed openning JLink DLL:Can not connect to J-Link via USB.',
    'exit /b 7'
), [Text.Encoding]::ASCII)
[IO.File]::WriteAllText(
    $fakeProfilePath,
    ($fixtureProfile | ConvertTo-Json -Depth 20),
    [Text.UTF8Encoding]::new($false)
)
$prepareStateHashBefore = if (Test-Path -LiteralPath $prepareStatePath -PathType Leaf) {
    (Get-FileHash -LiteralPath $prepareStatePath -Algorithm SHA256).Hash
} else { '' }
$artifactHashBeforeAbsent = (Get-FileHash -LiteralPath $packedBin -Algorithm SHA256).Hash
Write-AcceptancePhase -Name 'BOARD_ABSENT_PREFLIGHT' -State 'BEGIN' -Detail "PORT=$absentPort"
$absentResult = Invoke-CapturedPowerShellChild -Label 'BOARD_ABSENT_PREFLIGHT' -TimeoutSec 45 -Arguments @(
    '-NoProfile','-ExecutionPolicy','Bypass','-File',"`"$serverPath`"",
    '-Port',[string]$absentPort,'-NoBrowser','-BurnSafetyAcceptance',
    '-BurnSafetyProfilePath',"`"$fakeProfilePath`"",
    '-BurnSafetyPackedBin',"`"$packedBin`""
)
$absentOutput = @($absentResult.Stdout) + @($absentResult.Stderr)
if ($absentResult.ExitCode -ne 0 -or -not ($absentOutput -match '^BURN_SAFETY_ACCEPTANCE_JSON:')) {
    throw "Board-absent burn safety acceptance failed.`n$($absentOutput -join "`n")"
}
$invocations = @(
    if (Test-Path -LiteralPath $fakeInvocationPath -PathType Leaf) {
        [IO.File]::ReadAllLines($fakeInvocationPath, [Text.Encoding]::ASCII)
    }
)
if ($invocations.Count -ne 1 -or $invocations[0] -notmatch '(?i)-cmd\s+read' -or
    $invocations -match '(?i)-cmd\s+(erase|write)') {
    throw 'Board-absent regression reached a command other than the single hardware preflight read.'
}
$burnWorkerRecordPath = Join-Path $runtimeRoot "burn-$absentPort.json"
$burnWorkerRecord = [IO.File]::ReadAllText($burnWorkerRecordPath, [Text.Encoding]::UTF8) | ConvertFrom-Json
$trackedWorkerAlive = $false
try {
    $liveWorker = Get-Process -Id ([int]$burnWorkerRecord.pid) -ErrorAction Stop
    if ($liveWorker.StartTime.ToUniversalTime().Ticks -eq [int64]$burnWorkerRecord.processStartTicks) {
        $trackedWorkerAlive = $true
    }
} catch { }
if ($trackedWorkerAlive) {
    throw 'Board-absent regression left the tracked burn worker alive.'
}
if ((Get-FileHash -LiteralPath $packedBin -Algorithm SHA256).Hash -ne $artifactHashBeforeAbsent) {
    throw 'Board-absent regression changed the locked artifact.'
}
if (-not [string]::IsNullOrWhiteSpace($prepareStateHashBefore) -and
    (Get-FileHash -LiteralPath $prepareStatePath -Algorithm SHA256).Hash -ne $prepareStateHashBefore) {
    throw 'Board-absent regression changed prepare lock/fingerprint state.'
}
Write-AcceptancePhase -Name 'BOARD_ABSENT_PREFLIGHT' -State 'PASS' -Detail 'READY_TO_BURN NO_ERASE NO_WRITE NO_ORPHAN'

$connectedRoot = Join-Path $runtimeRoot "$acceptanceRunId.board-connected"
[void](New-Item -ItemType Directory -Path $connectedRoot -Force)
$connectedCliPath = Join-Path $connectedRoot 'fake-smartsnippets-connected.cmd'
$connectedInvocationPath = Join-Path $connectedRoot 'invocations.log'
$connectedProfilePath = Join-Path $connectedRoot 'eink-profile.board-connected.json'
$connectedPhasePath = Join-Path $connectedRoot 'phase.json'
$connectedProfile = [IO.File]::ReadAllText($profilePath, [Text.Encoding]::UTF8) | ConvertFrom-Json
$connectedProfile.spiBackup.smartSnippetsCli = $connectedCliPath
[IO.File]::WriteAllLines($connectedCliPath, @(
    '@echo off',
    'set "OUT="',
    "echo %*>>`"$connectedInvocationPath`"",
    ':args',
    'if "%~1"=="" goto output',
    'if /I "%~1"=="-file" set "OUT=%~2"',
    'shift',
    'goto args',
    ':output',
    '>"%OUT%" <nul set /p "=P"',
    'echo Found Cortex-M0 r0p0, Little endian.',
    'echo Firmware File C:\fixture\jtag_programmer.bin has been selected for downloading.',
    'echo Successfully downloaded firmware file to the board.',
    'echo Successfully set SPI Flash gpios: CLK=P0_0, CS=P0_3, MISO=P0_5, MOSI=P0_6.',
    'echo Memory contents exported successfully to %OUT%',
    'echo SPI FLASH memory reading has finished. Read 1 bytes.',
    'exit /b 23'
), [Text.Encoding]::ASCII)
[IO.File]::WriteAllText(
    $connectedProfilePath,
    ($connectedProfile | ConvertTo-Json -Depth 20),
    [Text.UTF8Encoding]::new($false)
)
Write-AcceptancePhase -Name 'BOARD_CONNECTED_PREFLIGHT' -State 'BEGIN' -Detail 'FAKE_EXIT_CODE=23'
$connectedResult = Invoke-CapturedPowerShellChild -Label 'BOARD_CONNECTED_PREFLIGHT' -TimeoutSec 45 -Arguments @(
    '-NoProfile','-ExecutionPolicy','Bypass','-File',"`"$burnPath`"",
    '-PackedBin',"`"$packedBin`"",'-Mode','Burn',
    '-ExpectedPackedSha256',$artifactHashBefore,
    '-ConfirmToken',[string]$connectedProfile.spiBurn.confirmationToken,
    '-ProfilePath',"`"$connectedProfilePath`"",
    '-PhaseStatePath',"`"$connectedPhasePath`"",
    '-AllowDirtyTrackedTree','-PreflightAcceptanceOnly'
)
$connectedOutput = @($connectedResult.Stdout) + @($connectedResult.Stderr)
if ($connectedResult.ExitCode -ne 0 -or
    -not ($connectedOutput -match '^PREFLIGHT_EVIDENCE: POSITIVE_EVIDENCE_COMPLETE$') -or
    -not ($connectedOutput -match '^NEXT_STATE: PREFLIGHT_ACCEPTANCE_COMPLETE$')) {
    throw "Board-connected positive-evidence preflight failed.`n$($connectedOutput -join "`n")"
}
$connectedInvocations = @([IO.File]::ReadAllLines($connectedInvocationPath, [Text.Encoding]::ASCII))
if ($connectedInvocations.Count -ne 1 -or
    $connectedInvocations[0] -notmatch '(?i)-cmd\s+read' -or
    $connectedInvocations -match '(?i)-cmd\s+(erase|write)') {
    throw 'Board-connected regression reached anything beyond the single preflight read.'
}
$connectedPhase = [IO.File]::ReadAllText($connectedPhasePath, [Text.Encoding]::UTF8) | ConvertFrom-Json
if ([string]$connectedPhase.phase -ne 'HARDWARE_PREFLIGHT' -or
    [string]$connectedPhase.status -ne 'PASS' -or
    [bool]$connectedPhase.destructiveStarted) {
    throw 'Board-connected regression did not stop at a non-destructive preflight PASS.'
}
if ((Get-FileHash -LiteralPath $packedBin -Algorithm SHA256).Hash -ne $artifactHashBeforeAbsent -or
    (-not [string]::IsNullOrWhiteSpace($prepareStateHashBefore) -and
     (Get-FileHash -LiteralPath $prepareStatePath -Algorithm SHA256).Hash -ne $prepareStateHashBefore)) {
    throw 'Board-connected regression changed artifact or prepare lock state.'
}
Write-AcceptancePhase -Name 'BOARD_CONNECTED_PREFLIGHT' -State 'PASS' -Detail 'POSITIVE_EVIDENCE EXIT_CODE_IGNORED NO_DESTRUCTIVE_PHASE'

$backupCases = @(
    [pscustomobject]@{ Name='A_NULL_EXIT'; ExitMode='Null'; ExitCode=0; MissingRead2=$false; Mismatch=$false; WrongSize=$false; Timeout=$false; ExpectPass=$true },
    [pscustomobject]@{ Name='B_NONZERO_EXIT'; ExitMode='Nonzero'; ExitCode=23; MissingRead2=$false; Mismatch=$false; WrongSize=$false; Timeout=$false; ExpectPass=$true },
    [pscustomobject]@{ Name='C_MISSING_READ2'; ExitMode='Native'; ExitCode=0; MissingRead2=$true; Mismatch=$false; WrongSize=$false; Timeout=$false; ExpectPass=$false },
    [pscustomobject]@{ Name='D_MISMATCHED_SHA'; ExitMode='Native'; ExitCode=0; MissingRead2=$false; Mismatch=$true; WrongSize=$false; Timeout=$false; ExpectPass=$false },
    [pscustomobject]@{ Name='E_WRONG_SIZE'; ExitMode='Native'; ExitCode=0; MissingRead2=$false; Mismatch=$false; WrongSize=$true; Timeout=$false; ExpectPass=$false },
    [pscustomobject]@{ Name='F_TIMEOUT'; ExitMode='Native'; ExitCode=0; MissingRead2=$false; Mismatch=$false; WrongSize=$false; Timeout=$true; ExpectPass=$false }
)
$invocationCountBeforeBackupMatrix = @([IO.File]::ReadAllLines($connectedInvocationPath, [Text.Encoding]::ASCII)).Count
foreach ($case in $backupCases) {
    $caseRoot = Join-Path $connectedRoot $case.Name
    [void](New-Item -ItemType Directory -Path $caseRoot -Force)
    $runner = Join-Path $caseRoot 'fake-backup.ps1'
    $runnerLines = @(
        '[CmdletBinding()]',
        'param([string]$ProfilePath,[string]$JtagSerial,[switch]$AllowDirtyTrackedTree)',
        '$ErrorActionPreference = ''Stop''',
        $(if ($case.Timeout) { 'Start-Sleep -Seconds 5' } else { '' }),
        '$read1 = Join-Path $PSScriptRoot ''READ1.bin''',
        '$read2 = Join-Path $PSScriptRoot ''READ2.bin''',
        $(if ($case.WrongSize) { '$size = 262143' } else { '$size = 262144' }),
        '$bytes1 = New-Object byte[] $size',
        '$bytes1[0] = 17',
        '[IO.File]::WriteAllBytes($read1, $bytes1)',
        $(if ($case.MissingRead2) { '' } else { '$bytes2 = New-Object byte[] $size' }),
        $(if ($case.MissingRead2) { '' } elseif ($case.Mismatch) { '$bytes2[0] = 18' } else { '$bytes2[0] = 17' }),
        $(if ($case.MissingRead2) { '' } else { '[IO.File]::WriteAllBytes($read2, $bytes2)' }),
        '$sha256 = [System.Security.Cryptography.SHA256]::Create()',
        '$stream1 = [System.IO.File]::OpenRead($read1)',
        'try { $sha1 = ([System.BitConverter]::ToString($sha256.ComputeHash($stream1))).Replace(''-'','''') } finally { $stream1.Dispose(); $sha256.Dispose() }',
        $(if ($case.MissingRead2) {
            '$sha2 = $sha1'
        } else {
            '$sha256 = [System.Security.Cryptography.SHA256]::Create(); $stream2 = [System.IO.File]::OpenRead($read2); try { $sha2 = ([System.BitConverter]::ToString($sha256.ComputeHash($stream2))).Replace(''-'','''') } finally { $stream2.Dispose(); $sha256.Dispose() }'
        }),
        'Write-Output ''EINK HARNESS: PASS''',
        'Write-Output ''ACTION: SPI-BACKUP''',
        'Write-Output "READ1: $read1"',
        'Write-Output "READ1_SIZE: $size"',
        'Write-Output "READ1_SHA256: $sha1"',
        'Write-Output "READ2: $read2"',
        'Write-Output "READ2_SIZE: $size"',
        'Write-Output "READ2_SHA256: $sha2"',
        'Write-Output "EVIDENCE_DIR: $PSScriptRoot"',
        'Write-Output ''NEXT_STATE: SPI_BACKUP_VERIFIED''',
        $(if ([int]$case.ExitCode -ne 0) { "exit $($case.ExitCode)" } else { 'exit 0' })
    ) | Where-Object { -not [string]::IsNullOrWhiteSpace($_) }
    [IO.File]::WriteAllLines($runner, $runnerLines, [Text.UTF8Encoding]::new($false))
    $casePhase = Join-Path $caseRoot 'phase.json'
    Write-AcceptancePhase -Name "BACKUP_$($case.Name)" -State 'BEGIN'
    $caseResult = Invoke-CapturedPowerShellChild -Label "BACKUP_$($case.Name)" -TimeoutSec 45 -Arguments @(
        '-NoProfile','-ExecutionPolicy','Bypass','-File',"`"$burnPath`"",
        '-PackedBin',"`"$packedBin`"",'-Mode','Burn',
        '-ExpectedPackedSha256',$artifactHashBefore,
        '-ConfirmToken',[string]$connectedProfile.spiBurn.confirmationToken,
        '-ProfilePath',"`"$connectedProfilePath`"",
        '-PhaseStatePath',"`"$casePhase`"",
        '-AllowDirtyTrackedTree','-BackupAcceptanceOnly',
        '-BackupRunnerPath',"`"$runner`"",
        '-BackupTimeoutSec',$(if ($case.Timeout) { '1' } else { '10' }),
        '-AcceptanceBackupExitMode',[string]$case.ExitMode
    )
    $caseOutput = @($caseResult.Stdout) + @($caseResult.Stderr)
    $phase = [IO.File]::ReadAllText($casePhase, [Text.Encoding]::UTF8) | ConvertFrom-Json
    if ($case.ExpectPass) {
        if ($caseResult.ExitCode -ne 0 -or
            -not ($caseOutput -match '^FRESH_BACKUP_EVIDENCE: POSITIVE_EVIDENCE_COMPLETE$') -or
            -not ($caseOutput -match '^NEXT_STATE: BACKUP_ACCEPTANCE_COMPLETE$') -or
            [string]$phase.status -ne 'PASS') {
            throw "Backup acceptance case $($case.Name) should PASS.`n$($caseOutput -join "`n")"
        }
    }
    else {
        if ($caseResult.ExitCode -eq 0 -or
            -not ($caseOutput -match '^REASON: FRESH_BACKUP_FAILED$') -or
            [string]$phase.status -ne 'FAIL' -or [bool]$phase.destructiveStarted) {
            throw "Backup acceptance case $($case.Name) should fail safely.`n$($caseOutput -join "`n")"
        }
    }
    Write-AcceptancePhase -Name "BACKUP_$($case.Name)" -State 'PASS' -Detail $(if ($case.ExpectPass) { 'EXPECTED_PASS' } else { 'EXPECTED_FAIL_SAFE' })
}
$matrixInvocations = @([IO.File]::ReadAllLines($connectedInvocationPath, [Text.Encoding]::ASCII))
$newMatrixInvocations = @($matrixInvocations | Select-Object -Skip $invocationCountBeforeBackupMatrix)
if ($newMatrixInvocations.Count -ne $backupCases.Count -or
    $newMatrixInvocations -match '(?i)-cmd\s+(erase|write)') {
    throw 'Backup matrix invoked erase/write or an unexpected number of SmartSnippets commands.'
}
Write-AcceptancePhase -Name 'BACKUP_G_NO_DESTRUCTIVE_ON_FAIL' -State 'PASS' -Detail "PREFLIGHT_READS=$($newMatrixInvocations.Count) ERASE_WRITE=0"
if ($TargetedBackupOnly) {
    Write-Output 'EINK CONTROL CENTER TARGETED BACKUP PATH ACCEPTANCE: PASS'
    Write-Output 'CASE_A_NULL_EXIT: PASS'
    Write-Output 'CASE_B_NONZERO_IRRELEVANT_EXIT: PASS'
    Write-Output 'CASE_C_MISSING_READ2: BLOCKED'
    Write-Output 'CASE_D_MISMATCHED_SHA: BLOCKED'
    Write-Output 'CASE_E_WRONG_SIZE: BLOCKED'
    Write-Output 'CASE_F_TIMEOUT: BLOCKED'
    Write-Output 'CASE_G_ERASE_WRITE_COUNT: 0'
    exit 0
}

$pipelineCases = @(
    [pscustomobject]@{ Name='FULL_SUCCESS_NULL_EXIT'; Mode='SUCCESS'; ExpectedPhase='SHA_VERIFY'; ExpectPass=$true; Destructive=$true },
    [pscustomobject]@{ Name='PREFLIGHT_ZERO_FAILED'; Mode='PREFLIGHT_FAIL'; ExpectedPhase='HARDWARE_PREFLIGHT'; ExpectPass=$false; Destructive=$false },
    [pscustomobject]@{ Name='PREFLIGHT_MISSING_OUTPUT'; Mode='PREFLIGHT_MISSING'; ExpectedPhase='HARDWARE_PREFLIGHT'; ExpectPass=$false; Destructive=$false },
    [pscustomobject]@{ Name='PREFLIGHT_TIMEOUT'; Mode='PREFLIGHT_TIMEOUT'; ExpectedPhase='HARDWARE_PREFLIGHT'; ExpectPass=$false; Destructive=$false },
    [pscustomobject]@{ Name='ERASE_ZERO_FAILED'; Mode='ERASE_FAIL'; ExpectedPhase='ERASE'; ExpectPass=$false; Destructive=$true },
    [pscustomobject]@{ Name='ERASE_MISSING_OUTPUT'; Mode='ERASE_MISSING'; ExpectedPhase='ERASE'; ExpectPass=$false; Destructive=$true },
    [pscustomobject]@{ Name='ERASE_TIMEOUT'; Mode='ERASE_TIMEOUT'; ExpectedPhase='ERASE'; ExpectPass=$false; Destructive=$true },
    [pscustomobject]@{ Name='WRITE_ZERO_FAILED'; Mode='WRITE_FAIL'; ExpectedPhase='WRITE'; ExpectPass=$false; Destructive=$true },
    [pscustomobject]@{ Name='WRITE_MISSING_OUTPUT'; Mode='WRITE_MISSING'; ExpectedPhase='WRITE'; ExpectPass=$false; Destructive=$true },
    [pscustomobject]@{ Name='WRITE_TIMEOUT'; Mode='WRITE_TIMEOUT'; ExpectedPhase='WRITE'; ExpectPass=$false; Destructive=$true },
    [pscustomobject]@{ Name='READBACK_ZERO_FAILED'; Mode='READBACK_FAIL'; ExpectedPhase='READBACK'; ExpectPass=$false; Destructive=$true },
    [pscustomobject]@{ Name='READBACK_MISSING_OUTPUT'; Mode='READBACK_MISSING'; ExpectedPhase='READBACK'; ExpectPass=$false; Destructive=$true },
    [pscustomobject]@{ Name='READBACK_WRONG_SIZE'; Mode='READBACK_WRONG_SIZE'; ExpectedPhase='READBACK'; ExpectPass=$false; Destructive=$true },
    [pscustomobject]@{ Name='READBACK_TIMEOUT'; Mode='READBACK_TIMEOUT'; ExpectedPhase='READBACK'; ExpectPass=$false; Destructive=$true },
    [pscustomobject]@{ Name='SHA_MISMATCH'; Mode='SHA_MISMATCH'; ExpectedPhase='SHA_VERIFY'; ExpectPass=$false; Destructive=$true },
    [pscustomobject]@{ Name='RECOVERY_SUCCESS_NULL_EXIT'; Mode='SUCCESS'; ExpectedPhase='RECOVERY_SHA_VERIFY'; ExpectPass=$true; Destructive=$true; Recovery=$true },
    [pscustomobject]@{ Name='RECOVERY_WRITE_FAILED'; Mode='WRITE_FAIL'; ExpectedPhase='RECOVERY_WRITE'; ExpectPass=$false; Destructive=$true; Recovery=$true },
    [pscustomobject]@{ Name='RECOVERY_SHA_MISMATCH'; Mode='SHA_MISMATCH'; ExpectedPhase='RECOVERY_SHA_VERIFY'; ExpectPass=$false; Destructive=$true; Recovery=$true }
)
if ($TargetedRecoveryOnly) {
    $pipelineCases = @($pipelineCases | Where-Object { [bool]$_.Recovery })
}
$pipelineRoot = Join-Path $runtimeRoot "$acceptanceRunId.pipeline-contract"
[void](New-Item -ItemType Directory -Path $pipelineRoot -Force)
$expectedOffsets = @(for ($offset = 0; $offset -lt 262144; $offset += 16384) { $offset })
$readChunkLines = @($expectedOffsets | ForEach-Object { 'echo Read 16384 bytes from offset 0x{0:X}' -f $_ })
$writeChunkLines = @($expectedOffsets | ForEach-Object { 'echo Write 16384 bytes at offset 0x{0:X}' -f $_ })

foreach ($case in $pipelineCases) {
    $caseRoot = Join-Path $pipelineRoot $case.Name
    $caseEvidenceRoot = Join-Path $caseRoot 'evidence'
    [void](New-Item -ItemType Directory -Path $caseEvidenceRoot -Force)
    $fakeJtag = Join-Path $caseRoot 'jtag_programmer.bin'
    [IO.File]::WriteAllBytes($fakeJtag, [byte[]](1,2,3,4))
    $invocationPath = Join-Path $caseRoot 'smart-snippets-invocations.txt'
    $fakeCli = Join-Path $caseRoot 'fake-smart-snippets.cmd'
    $wrongSizePath = Join-Path $caseRoot 'wrong-size.bin'
    [IO.File]::WriteAllBytes($wrongSizePath, (New-Object byte[] 262143))
    $mismatchPath = Join-Path $caseRoot 'mismatch.bin'
    $mismatchBytes = New-Object byte[] 262144
    $mismatchBytes[0] = 165
    [IO.File]::WriteAllBytes($mismatchPath, $mismatchBytes)
    $recoveryBackupDir = Join-Path $caseRoot 'immutable-pre-erase-backup'
    [void](New-Item -ItemType Directory -Path $recoveryBackupDir -Force)
    $recoveryBackupBytes = New-Object byte[] 262144
    $recoveryBackupBytes[0] = 91
    [IO.File]::WriteAllBytes((Join-Path $recoveryBackupDir 'BOARD1_SPI_READ1.bin'), $recoveryBackupBytes)
    [IO.File]::WriteAllBytes((Join-Path $recoveryBackupDir 'BOARD1_SPI_READ2.bin'), $recoveryBackupBytes)
    $recoveryShaProvider = [Security.Cryptography.SHA256]::Create()
    $recoveryStream = [IO.File]::OpenRead((Join-Path $recoveryBackupDir 'BOARD1_SPI_READ1.bin'))
    try { $recoveryBackupSha = ([BitConverter]::ToString($recoveryShaProvider.ComputeHash($recoveryStream))).Replace('-','') }
    finally { $recoveryStream.Dispose(); $recoveryShaProvider.Dispose() }

    $commonEvidenceLines = @(
        'echo Found Cortex-M0 r0p0, Little endian.',
        "echo Firmware File $fakeJtag has been selected for downloading.",
        'echo Successfully downloaded firmware file to the board.',
        'echo Successfully set SPI Flash gpios: CLK=P0_0, CS=P0_3, MISO=P0_5, MOSI=P0_6.'
    )
    $cliLines = @(
        '@echo off',
        'setlocal',
        "echo %*>>`"$invocationPath`"",
        'set "ACTION="',
        'set "OUT="',
        'set "LENGTH="',
        ':parse',
        'if "%~1"=="" goto dispatch',
        'if /I "%~1"=="-cmd" set "ACTION=%~2"',
        'if /I "%~1"=="-file" set "OUT=%~2"',
        'if /I "%~1"=="-length" set "LENGTH=%~2"',
        'shift',
        'goto parse',
        ':dispatch',
        'if /I "%ACTION%"=="erase" goto erase',
        'if /I "%ACTION%"=="write" goto write',
        'if /I "%ACTION%"=="read" if "%LENGTH%"=="1" goto preflight',
        'if /I "%ACTION%"=="read" goto readback',
        'echo ERROR: unexpected command',
        'exit /b 0',
        ':preflight'
    )
    if ($case.Mode -eq 'PREFLIGHT_TIMEOUT') {
        $cliLines += 'powershell.exe -NoProfile -Command "Start-Sleep -Seconds 5"'
    }
    elseif ($case.Mode -eq 'PREFLIGHT_MISSING') {
        $cliLines += $commonEvidenceLines
    }
    elseif ($case.Mode -eq 'PREFLIGHT_FAIL') {
        $cliLines += $commonEvidenceLines
        $cliLines += 'echo ERROR: target handshake failed'
    }
    else {
        $cliLines += $commonEvidenceLines
        $cliLines += @(
            '>"%OUT%" <nul set /p "=P"',
            'echo Started reading 1 bytes from SPI FLASH memory offset 0x0.',
            'echo Read 1 bytes from offset 0x00',
            'echo Memory contents exported successfully to %OUT%',
            'echo SPI FLASH memory reading has finished. Read 1 bytes.'
        )
    }
    $cliLines += @('exit /b 0', ':erase')
    if ($case.Mode -eq 'ERASE_TIMEOUT') {
        $cliLines += 'powershell.exe -NoProfile -Command "Start-Sleep -Seconds 5"'
    }
    else {
        $cliLines += $commonEvidenceLines
        if ($case.Mode -eq 'ERASE_FAIL') {
            $cliLines += 'echo Verification failed.'
        }
        elseif ($case.Mode -ne 'ERASE_MISSING') {
            $cliLines += @('echo SPI Flash memory erasing completed successfully.','echo Reading memory to verify its contents after erase....')
            $cliLines += $readChunkLines
            $cliLines += 'echo Verification succeeded.'
        }
    }
    $cliLines += @('exit /b 0', ':write')
    if ($case.Mode -eq 'WRITE_TIMEOUT') {
        $cliLines += 'powershell.exe -NoProfile -Command "Start-Sleep -Seconds 5"'
    }
    else {
        $cliLines += $commonEvidenceLines
        if ($case.Mode -eq 'WRITE_FAIL') {
            $cliLines += 'echo Memory burning failed.'
        }
        elseif ($case.Mode -ne 'WRITE_MISSING') {
            $cliLines += 'echo Started burning memory with 262144 bytes of data at address 0x00000.'
            $cliLines += $writeChunkLines
            $cliLines += @('echo Memory burning completed successfully.','echo Reading memory to verify its contents after burn....')
            $cliLines += $readChunkLines
            $cliLines += 'echo SPI memory verification succeeded.'
        }
    }
    $cliLines += @('exit /b 0', ':readback')
    if ($case.Mode -eq 'READBACK_TIMEOUT') {
        $cliLines += 'powershell.exe -NoProfile -Command "Start-Sleep -Seconds 5"'
    }
    else {
        $cliLines += $commonEvidenceLines
        if ($case.Mode -eq 'READBACK_FAIL') {
            $cliLines += 'echo SPI FLASH memory reading failed.'
        }
        elseif ($case.Mode -ne 'READBACK_MISSING') {
            if ($case.Mode -eq 'READBACK_WRONG_SIZE') {
                $cliLines += "copy /b /y `"$wrongSizePath`" `"%OUT%`" >nul"
            }
            elseif ($case.Mode -eq 'SHA_MISMATCH') {
                $cliLines += "copy /b /y `"$mismatchPath`" `"%OUT%`" >nul"
            }
            else {
                $cliLines += "copy /b /y `"$packedBin`" `"%OUT%`" >nul"
            }
            $cliLines += 'echo Started reading 262144 bytes from SPI FLASH memory offset 0x0.'
            $cliLines += $readChunkLines
            $cliLines += @('echo Memory contents exported successfully to %OUT%','echo SPI FLASH memory reading has finished. Read 262144 bytes.')
        }
    }
    $cliLines += 'exit /b 0'
    [IO.File]::WriteAllLines($fakeCli, $cliLines, [Text.Encoding]::ASCII)

    $backupRunner = Join-Path $caseRoot 'fake-backup.ps1'
    $backupLines = @(
        '[CmdletBinding()]',
        'param([string]$ProfilePath,[string]$JtagSerial,[switch]$AllowDirtyTrackedTree)',
        '$read1 = Join-Path $PSScriptRoot ''READ1.bin''',
        '$read2 = Join-Path $PSScriptRoot ''READ2.bin''',
        '$bytes = New-Object byte[] 262144; $bytes[0] = 17',
        '[IO.File]::WriteAllBytes($read1, $bytes)',
        '[IO.File]::WriteAllBytes($read2, $bytes)',
        '$sha = [Security.Cryptography.SHA256]::Create(); $stream = [IO.File]::OpenRead($read1)',
        'try { $hash = ([BitConverter]::ToString($sha.ComputeHash($stream))).Replace(''-'','''') } finally { $stream.Dispose(); $sha.Dispose() }',
        'Write-Output ''EINK HARNESS: PASS''',
        'Write-Output ''ACTION: SPI-BACKUP''',
        'Write-Output "READ1: $read1"',
        'Write-Output ''READ1_SIZE: 262144''',
        'Write-Output "READ1_SHA256: $hash"',
        'Write-Output "READ2: $read2"',
        'Write-Output ''READ2_SIZE: 262144''',
        'Write-Output "READ2_SHA256: $hash"',
        'Write-Output "EVIDENCE_DIR: $PSScriptRoot"',
        'Write-Output ''NEXT_STATE: SPI_BACKUP_VERIFIED''',
        'exit 0'
    )
    [IO.File]::WriteAllLines($backupRunner, $backupLines, [Text.UTF8Encoding]::new($false))

    $caseProfile = $connectedProfile | ConvertTo-Json -Depth 20 | ConvertFrom-Json
    $caseProfile.spiBackup.smartSnippetsCli = $fakeCli
    $caseProfile.spiBackup.jtagProgrammer = $fakeJtag
    $caseProfile.spiBurn.evidenceRoot = $caseEvidenceRoot
    $caseProfilePath = Join-Path $caseRoot 'eink-profile.pipeline.json'
    [IO.File]::WriteAllText($caseProfilePath, ($caseProfile | ConvertTo-Json -Depth 20), [Text.UTF8Encoding]::new($false))
    $casePhasePath = Join-Path $caseRoot 'phase.json'

    Write-AcceptancePhase -Name "PIPELINE_$($case.Name)" -State 'BEGIN'
    $caseArguments = @(
        '-NoProfile','-ExecutionPolicy','Bypass','-File',"`"$burnPath`"",
        '-PackedBin',"`"$packedBin`"",'-Mode','Burn',
        '-ExpectedPackedSha256',$artifactHashBefore,
        '-ConfirmToken',[string]$caseProfile.spiBurn.confirmationToken,
        '-ProfilePath',"`"$caseProfilePath`"",
        '-PhaseStatePath',"`"$casePhasePath`"",
        '-AllowDirtyTrackedTree','-PipelineAcceptanceOnly',
        '-BackupRunnerPath',"`"$backupRunner`"",
        '-BackupTimeoutSec','10',
        '-AcceptanceSmartSnippetsTimeoutSec','2',
        '-AcceptanceSmartSnippetsExitMode',$(if ($case.ExpectPass) { 'Null' } else { 'Native' })
    )
    if ([bool]$case.Recovery) {
        $caseArguments += @(
            '-RecoveryWriteOnly',
            '-RecoveryConfirmToken',[Guid]::NewGuid().ToString('N'),
            '-PreEraseBackupEvidenceDir',"`"$recoveryBackupDir`"",
            '-ExpectedPreEraseBackupSha256',$recoveryBackupSha
        )
    }
    $caseResult = Invoke-CapturedPowerShellChild -Label "PIPELINE_$($case.Name)" -TimeoutSec 60 -Arguments $caseArguments
    $caseOutput = @($caseResult.Stdout) + @($caseResult.Stderr)
    $casePhase = [IO.File]::ReadAllText($casePhasePath, [Text.Encoding]::UTF8) | ConvertFrom-Json
    if ([string]$casePhase.phase -ne $case.ExpectedPhase -or [bool]$casePhase.destructiveStarted -ne [bool]$case.Destructive) {
        throw "Pipeline case $($case.Name) stopped at an incorrect safety phase.`n$($caseOutput -join "`n")"
    }
    if ($case.ExpectPass) {
        $destructiveEvidenceValid = if ([bool]$case.Recovery) {
            ($caseOutput -match '^NORMAL_FRESH_BACKUP: SKIPPED$') -and
            ($caseOutput -match '^ERASE: SKIPPED$') -and
            ($caseOutput -match '^PRE_ERASE_BACKUP_SHA256: [0-9A-F]{64}$')
        }
        else {
            $caseOutput -match '^ERASE_EVIDENCE: POSITIVE_EVIDENCE_COMPLETE$'
        }
        if ($caseResult.ExitCode -ne 0 -or [string]$casePhase.status -ne 'PASS' -or
            -not ($caseOutput -match '^NEXT_STATE: PIPELINE_ACCEPTANCE_COMPLETE$') -or
            -not $destructiveEvidenceValid -or
            -not ($caseOutput -match '^WRITE_EVIDENCE: POSITIVE_EVIDENCE_COMPLETE$') -or
            -not ($caseOutput -match '^READBACK_EVIDENCE: POSITIVE_EVIDENCE_COMPLETE$')) {
            throw "Pipeline case $($case.Name) should PASS.`n$($caseOutput -join "`n")"
        }
    }
    elseif ($caseResult.ExitCode -eq 0 -or [string]$casePhase.status -ne 'FAIL') {
        throw "Pipeline case $($case.Name) should fail closed.`n$($caseOutput -join "`n")"
    }
    if ([bool]$case.Recovery) {
        $recoveryInvocations = if (Test-Path -LiteralPath $invocationPath) { @([IO.File]::ReadAllLines($invocationPath, [Text.Encoding]::ASCII)) } else { @() }
        if ($recoveryInvocations -match '(?i)-cmd\s+erase' -or
            (Test-Path -LiteralPath (Join-Path $caseRoot 'READ1.bin')) -or
            (Test-Path -LiteralPath (Join-Path $caseRoot 'READ2.bin'))) {
            throw "Recovery case $($case.Name) invoked forbidden backup/erase behavior."
        }
        if ($case.ExpectPass -and ($recoveryInvocations.Count -ne 3 -or
            $recoveryInvocations[0] -notmatch '(?i)-cmd\s+read.+-length\s+1' -or
            $recoveryInvocations[1] -notmatch '(?i)-cmd\s+write' -or
            $recoveryInvocations[2] -notmatch '(?i)-cmd\s+read.+-length\s+(?:262144|0x40000)')) {
            throw 'Recovery success did not execute exact preflight -> write -> readback sequence.'
        }
    }
    Write-AcceptancePhase -Name "PIPELINE_$($case.Name)" -State 'PASS' -Detail $(if ($case.ExpectPass) { 'EXPECTED_PASS' } else { 'EXPECTED_FAIL_CLOSED' })
}

$invalidRecoveryPhase = Join-Path $caseRoot 'invalid-recovery-backup.phase.json'
$invalidInvocationCount = if (Test-Path -LiteralPath $invocationPath) { @([IO.File]::ReadAllLines($invocationPath, [Text.Encoding]::ASCII)).Count } else { 0 }
Write-AcceptancePhase -Name 'RECOVERY_INVALID_PRE_ERASE_BACKUP' -State 'BEGIN'
$invalidRecovery = Invoke-CapturedPowerShellChild -Label 'RECOVERY_INVALID_PRE_ERASE_BACKUP' -TimeoutSec 30 -Arguments @(
    '-NoProfile','-ExecutionPolicy','Bypass','-File',"`"$burnPath`"",
    '-PackedBin',"`"$packedBin`"",'-Mode','Burn',
    '-ExpectedPackedSha256',$artifactHashBefore,
    '-ConfirmToken',[string]$caseProfile.spiBurn.confirmationToken,
    '-ProfilePath',"`"$caseProfilePath`"",
    '-PhaseStatePath',"`"$invalidRecoveryPhase`"",
    '-AllowDirtyTrackedTree','-PipelineAcceptanceOnly','-RecoveryWriteOnly',
    '-RecoveryConfirmToken',[Guid]::NewGuid().ToString('N'),
    '-PreEraseBackupEvidenceDir',"`"$recoveryBackupDir`"",
    '-ExpectedPreEraseBackupSha256',('0' * 64),
    '-AcceptanceSmartSnippetsTimeoutSec','2'
)
$invalidOutput = @($invalidRecovery.Stdout) + @($invalidRecovery.Stderr)
$invalidInvocationCountAfter = if (Test-Path -LiteralPath $invocationPath) { @([IO.File]::ReadAllLines($invocationPath, [Text.Encoding]::ASCII)).Count } else { 0 }
if ($invalidRecovery.ExitCode -eq 0 -or
    -not ($invalidOutput -match '^REASON: RECOVERY_PRE_ERASE_BACKUP_INVALID$') -or
    (Test-Path -LiteralPath $invalidRecoveryPhase) -or
    $invalidInvocationCountAfter -ne $invalidInvocationCount) {
    throw "Invalid immutable recovery backup was not blocked before hardware invocation.`n$($invalidOutput -join "`n")"
}
Write-AcceptancePhase -Name 'RECOVERY_INVALID_PRE_ERASE_BACKUP' -State 'PASS' -Detail 'BLOCKED_BEFORE_HARDWARE'

Write-Output 'EINK FULL BURN PIPELINE CONTRACT ACCEPTANCE: PASS'
Write-Output 'PIPELINE_SEQUENCE: PREFLIGHT -> BACKUP -> ERASE -> WRITE -> READBACK -> SHA_VERIFY'
Write-Output 'FULL_SUCCESS_NULL_EXIT: PASS'
Write-Output 'MISLEADING_ZERO_FAILED_EVIDENCE: BLOCKED'
Write-Output 'TIMEOUTS: BLOCKED'
Write-Output 'MISSING_OUTPUT: BLOCKED'
Write-Output 'WRONG_SIZE: BLOCKED'
Write-Output 'MISMATCHED_SHA: BLOCKED'
Write-Output 'PRE_DESTRUCTIVE_FAILURE: SAFE'
Write-Output 'POST_DESTRUCTIVE_FAILURE: RECOVERY_REQUIRED'
Write-Output 'RECOVERY_SEQUENCE: PREFLIGHT -> WRITE -> READBACK -> SHA_VERIFY'
Write-Output 'RECOVERY_FRESH_BACKUP: NOT INVOKED'
Write-Output 'RECOVERY_ERASE: NOT INVOKED'
Write-Output 'RECOVERY_FAILURE_STATE: RECOVERY_REQUIRED'
if ($TargetedPipelineOnly -or $TargetedRecoveryOnly) { exit 0 }

$feedbackText = [Text.Encoding]::UTF8.GetString(
    [Convert]::FromBase64String(
        'UEFTUzogS2ltIHBow7p0IG5ow61jaCDEkcO6bmcgbeG7l2kgcGjDunQgdHJvbmcgNCBwaMO6dCBGTFkuLi4='
    )
)
$feedbackPort = Get-FreeLoopbackPort
Write-AcceptancePhase -Name 'UTF8_SERVER_START' -State 'BEGIN' -Detail "PORT=$feedbackPort"
$feedbackProcess = Start-Process `
    -FilePath 'powershell.exe' `
    -ArgumentList @(
        '-NoProfile', '-ExecutionPolicy', 'Bypass',
        '-File', "`"$serverPath`"",
        '-Port', [string]$feedbackPort,
        '-NoBrowser', '-FeedbackTransportAcceptance'
    ) `
    -WindowStyle Hidden `
    -PassThru
$feedbackStartTicks = $feedbackProcess.StartTime.ToUniversalTime().Ticks
$feedbackExecutablePath = $feedbackProcess.Path
Write-AcceptancePhase -Name 'UTF8_SERVER_START' -State 'PASS' -Detail "PID=$($feedbackProcess.Id)"

try {
    $feedbackHub = $null
    for ($attempt = 0; $attempt -lt 10; $attempt++) {
        Start-Sleep -Milliseconds 250
        if ($feedbackProcess.HasExited) { break }
        Write-AcceptancePhase -Name 'UTF8_STATUS_HTTP' -State 'BEGIN' -Detail "ATTEMPT=$($attempt + 1) TIMEOUT_SEC=15"
        try {
            $feedbackHub = Invoke-RestMethod `
                -Uri "http://127.0.0.1:$feedbackPort/api/status" `
                -Method Get `
                -DisableKeepAlive `
                -TimeoutSec 15
            Write-AcceptancePhase -Name 'UTF8_STATUS_HTTP' -State 'PASS' -Detail "ATTEMPT=$($attempt + 1)"
            break
        }
        catch {
            Write-AcceptancePhase -Name 'UTF8_STATUS_HTTP' -State 'RETRY' -Detail $_.Exception.Message
        }
    }

    if (-not $feedbackHub) {
        throw 'Feedback transport acceptance server did not start.'
    }

    Add-Type -AssemblyName System.Net.Http
    $client = New-Object Net.Http.HttpClient
    try {
        $client.Timeout = [TimeSpan]::FromSeconds(15)
        $client.DefaultRequestHeaders.ExpectContinue = $false
        $client.DefaultRequestHeaders.Add(
            'X-Eink-Control-Token',
            [string]$feedbackHub.sessionToken
        )
        $json = @{
            feedback = $feedbackText
            evidence = @()
        } | ConvertTo-Json -Compress
        $content = New-Object Net.Http.StringContent(
            $json,
            [Text.Encoding]::UTF8,
            'application/json'
        )
        Write-AcceptancePhase -Name 'UTF8_FEEDBACK_HTTP' -State 'BEGIN' -Detail 'TIMEOUT_SEC=15'
        $response = $client.PostAsync(
            "http://127.0.0.1:$feedbackPort/api/projects/eink/actions/physical-pass",
            $content
        ).GetAwaiter().GetResult()
        $responseText = $response.Content.ReadAsStringAsync().GetAwaiter().GetResult()
        Write-AcceptancePhase -Name 'UTF8_FEEDBACK_HTTP' -State 'PASS' -Detail "STATUS=$([int]$response.StatusCode)"
    }
    finally {
        $client.Dispose()
    }

    if (-not $response.IsSuccessStatusCode) {
        throw "Feedback transport endpoint returned HTTP $([int]$response.StatusCode)."
    }

    $feedbackResult = $responseText | ConvertFrom-Json
    if (
        [string]$feedbackResult.action -ne 'physical-pass' -or
        [string]$feedbackResult.receivedFeedback -cne $feedbackText -or
        [int]$feedbackResult.evidenceCount -ne 0 -or
        -not [bool]$feedbackResult.accepted
    ) {
        throw 'Text-only PHYSICAL PASS feedback was not transported exactly.'
    }
    Write-AcceptancePhase -Name 'UTF8_FEEDBACK_VERIFY' -State 'PASS'
}
finally {
    Write-AcceptancePhase -Name 'UTF8_SERVER_CLEANUP' -State 'BEGIN'
    if ($feedbackProcess -and -not $feedbackProcess.HasExited) {
        Stop-ExactStartedProcess `
            -Process $feedbackProcess `
            -StartTicks $feedbackStartTicks `
            -ExecutablePath $feedbackExecutablePath `
            -Label 'UTF8_SERVER'
    }
    Write-AcceptancePhase -Name 'UTF8_SERVER_CLEANUP' -State 'PASS'
}

$lifecyclePort = Get-FreeLoopbackPort
$lifecycleUrl = "http://127.0.0.1:$lifecyclePort/"
$lifecycleLockPath = Join-Path $repoRoot (
    "_incoming\EINK_HARNESS_CONTROL_CENTER_RUNTIME\server-$lifecyclePort.json"
)
$lifecycleTracePath = Join-Path $runtimeRoot (
    "$acceptanceRunId.lifecycle.trace.log"
)
$temporaryLogPaths.Add($lifecycleTracePath)
Remove-Item -LiteralPath $lifecycleTracePath -Force -ErrorAction SilentlyContinue
$previousLifecycleTrace = [Environment]::GetEnvironmentVariable(
    'EINK_CONTROL_CENTER_ACCEPTANCE_TRACE',
    'Process'
)
[Environment]::SetEnvironmentVariable(
    'EINK_CONTROL_CENTER_ACCEPTANCE_TRACE',
    $lifecycleTracePath,
    'Process'
)
$knownLifecycleIdentities = New-Object 'Collections.Generic.List[object]'

function Get-LifecycleStatus {
    param([ValidateRange(1, 15)][int]$TimeoutSec = 5)

    Write-AcceptancePhase -Name 'LIFECYCLE_STATUS_HTTP' -State 'BEGIN' -Detail "TIMEOUT_SEC=$TimeoutSec"
    try {
        $status = Invoke-RestMethod `
            -Uri ($lifecycleUrl + 'api/status') `
            -Method Get `
            -DisableKeepAlive `
            -TimeoutSec $TimeoutSec
        Write-AcceptancePhase -Name 'LIFECYCLE_STATUS_HTTP' -State 'PASS' -Detail "PID=$($status.lifecycle.pid)"
        $status
    }
    catch {
        Write-AcceptancePhase -Name 'LIFECYCLE_STATUS_HTTP' -State 'NO_RESPONSE' -Detail $_.Exception.Message
        $null
    }
}

function Wait-LifecycleStatus {
    param(
        [Parameter(Mandatory=$true)][string]$Phase,
        [int]$DifferentFromPid = 0,
        [ValidateRange(1, 60)][int]$TimeoutSec = 30
    )

    Write-AcceptancePhase -Name $Phase -State 'BEGIN' -Detail "TIMEOUT_SEC=$TimeoutSec DIFFERENT_FROM_PID=$DifferentFromPid"
    $stopwatch = [Diagnostics.Stopwatch]::StartNew()
    while ($stopwatch.Elapsed.TotalSeconds -lt $TimeoutSec) {
        Start-Sleep -Milliseconds 250
        $remaining = [Math]::Max(1, [Math]::Floor($TimeoutSec - $stopwatch.Elapsed.TotalSeconds))
        $status = Get-LifecycleStatus -TimeoutSec ([Math]::Min(5, $remaining))
        if (
            $status -and
            ($DifferentFromPid -eq 0 -or [int]$status.lifecycle.pid -ne $DifferentFromPid)
        ) {
            Write-AcceptancePhase -Name $Phase -State 'PASS' -Detail "PID=$($status.lifecycle.pid) ELAPSED_MS=$($stopwatch.ElapsedMilliseconds)"
            return $status
        }
    }
    Write-AcceptancePhase -Name $Phase -State 'TIMEOUT' -Detail "ELAPSED_MS=$($stopwatch.ElapsedMilliseconds)"
    $null
}

function Assert-LifecycleIdentity {
    param(
        [Parameter(Mandatory=$true)]$Status,
        [Parameter(Mandatory=$true)][string]$Phase
    )

    Write-AcceptancePhase -Name $Phase -State 'BEGIN'
    if (-not (Test-Path -LiteralPath $lifecycleLockPath -PathType Leaf)) {
        throw "$Phase lifecycle lock is missing."
    }
    $lock = [IO.File]::ReadAllText(
        $lifecycleLockPath,
        [Text.Encoding]::UTF8
    ) | ConvertFrom-Json
    if (
        [string]$lock.schema -ne 'eink-control-center-server-lock-v1' -or
        [int]$lock.port -ne $lifecyclePort -or
        [IO.Path]::GetFullPath([string]$lock.scriptPath) -ne
            [IO.Path]::GetFullPath($serverPath) -or
        [IO.Path]::GetFullPath([string]$lock.repoRoot) -ne
            [IO.Path]::GetFullPath($repoRoot) -or
        [int]$lock.pid -ne [int]$Status.lifecycle.pid -or
        [int64]$lock.processStartTicks -ne
            [int64]$Status.lifecycle.processStartTicks
    ) {
        throw "$Phase lifecycle lock/status identity mismatch."
    }
    $process = Get-Process -Id ([int]$lock.pid) -ErrorAction Stop
    if (
        $process.StartTime.ToUniversalTime().Ticks -ne
            [int64]$lock.processStartTicks -or
        [IO.Path]::GetFullPath($process.Path) -ne
            [IO.Path]::GetFullPath([string]$lock.executablePath)
    ) {
        throw "$Phase process PID/start-time/executable identity mismatch."
    }
    $identity = [PSCustomObject]@{
        Pid = [int]$lock.pid
        StartTicks = [int64]$lock.processStartTicks
        ExecutablePath = [string]$lock.executablePath
    }
    $knownLifecycleIdentities.Add($identity)
    Write-AcceptancePhase -Name $Phase -State 'PASS' -Detail "PID=$($identity.Pid) START_TICKS=$($identity.StartTicks)"
    $identity
}

try {
    $firstLaunchProcess = Invoke-PowerShellChild `
        -Label 'LIFECYCLE_HIDDEN_START_HANDSHAKE' `
        -TimeoutSec 45 `
        -BackgroundDescendant `
        -Arguments @(
            '-NoProfile', '-ExecutionPolicy', 'Bypass',
            '-File', "`"$launcherPath`"",
            '-Port', [string]$lifecyclePort,
            '-NoBrowser'
        )
    if ($firstLaunchProcess.ExitCode -ne 0) {
        throw 'Hidden launcher start process failed.'
    }

    $firstStatus = Wait-LifecycleStatus `
        -Phase 'LIFECYCLE_INITIAL_STATUS_WAIT' `
        -TimeoutSec 30
    if (-not $firstStatus) {
        throw 'Lifecycle server did not answer initial status probe.'
    }
    $firstIdentity = Assert-LifecycleIdentity `
        -Status $firstStatus `
        -Phase 'LIFECYCLE_INITIAL_IDENTITY'
    $firstPid = $firstIdentity.Pid

    Write-AcceptancePhase -Name 'LIFECYCLE_IDLE_CLIENT_RECOVERY' -State 'BEGIN' -Detail 'CONNECT_TIMEOUT_SEC=5 STATUS_TIMEOUT_SEC=12'
    $idleClient = New-Object Net.Sockets.TcpClient
    try {
        $connectTask = $idleClient.ConnectAsync(
            [Net.IPAddress]::Loopback,
            $lifecyclePort
        )
        if (-not $connectTask.Wait(5000)) {
            throw 'Idle-client regression connect timed out.'
        }
        $connectTask.GetAwaiter().GetResult()
        Start-Sleep -Milliseconds 250
        $idleRecoveryStatus = Get-LifecycleStatus -TimeoutSec 12
        if (
            -not $idleRecoveryStatus -or
            [int]$idleRecoveryStatus.lifecycle.pid -ne $firstPid
        ) {
            throw 'Server did not recover from an idle accepted HTTP client.'
        }
        [void](Assert-LifecycleIdentity `
            -Status $idleRecoveryStatus `
            -Phase 'LIFECYCLE_IDLE_CLIENT_IDENTITY')
        Write-AcceptancePhase -Name 'LIFECYCLE_IDLE_CLIENT_RECOVERY' -State 'PASS'
    }
    finally {
        $idleClient.Close()
    }

    $duplicateLaunchProcess = Invoke-PowerShellChild `
        -Label 'LIFECYCLE_DUPLICATE_START_HANDSHAKE' `
        -TimeoutSec 30 `
        -BackgroundDescendant `
        -Arguments @(
            '-NoProfile', '-ExecutionPolicy', 'Bypass',
            '-File', "`"$launcherPath`"",
            '-Port', [string]$lifecyclePort,
            '-NoBrowser'
        )
    $duplicateStatus = Get-LifecycleStatus -TimeoutSec 5
    if (
        $duplicateLaunchProcess.ExitCode -ne 0 -or
        -not $duplicateStatus -or
        [int]$duplicateStatus.lifecycle.pid -ne $firstPid
    ) {
        throw 'Duplicate launcher did not preserve the exact running process.'
    }
    [void](Assert-LifecycleIdentity `
        -Status $duplicateStatus `
        -Phase 'LIFECYCLE_DUPLICATE_IDENTITY')

    $currentStatus = $firstStatus
    $currentIdentity = $firstIdentity

    for ($cycle = 1; $cycle -le 5; $cycle++) {
        $oldIdentity = $currentIdentity
        $oldPid = $oldIdentity.Pid
        $headers = @{
            'X-Eink-Control-Token' = [string]$currentStatus.sessionToken
        }
        Write-AcceptancePhase -Name 'LIFECYCLE_RESTART_HTTP' -State 'BEGIN' -Detail "CYCLE=$cycle TIMEOUT_SEC=10 PID=$oldPid"
        $restart = Invoke-RestMethod `
            -Uri ($lifecycleUrl + 'api/lifecycle/restart') `
            -Method Post `
            -Headers $headers `
            -ContentType 'application/json' `
            -Body '{}' `
            -DisableKeepAlive `
            -TimeoutSec 10
        Write-AcceptancePhase -Name 'LIFECYCLE_RESTART_HTTP' -State 'PASS' -Detail "CYCLE=$cycle PID=$($restart.pid)"
        if (
            [string]$restart.result -ne 'RESTARTING' -or
            [int]$restart.pid -ne $oldPid
        ) {
            throw "Lifecycle restart cycle $cycle did not target the tracked PID."
        }

        Write-AcceptancePhase -Name 'OLD_EXIT' -State 'BEGIN' -Detail "CYCLE=$cycle TIMEOUT_SEC=15 PID=$oldPid"
        $oldExitStopwatch = [Diagnostics.Stopwatch]::StartNew()
        $oldProcessExited = $false
        while ($oldExitStopwatch.Elapsed.TotalSeconds -lt 15) {
            Start-Sleep -Milliseconds 50
            $oldProcess = Get-Process `
                -Id $oldPid `
                -ErrorAction SilentlyContinue
            if (-not $oldProcess) {
                $oldProcessExited = $true
                break
            }
            try {
                if (
                    $oldProcess.StartTime.ToUniversalTime().Ticks -ne
                        $oldIdentity.StartTicks -or
                    [IO.Path]::GetFullPath($oldProcess.Path) -ne
                        [IO.Path]::GetFullPath($oldIdentity.ExecutablePath)
                ) {
                    throw "Lifecycle restart cycle $cycle observed old PID reuse."
                }
            }
            catch {
                if (Get-Process -Id $oldPid -ErrorAction SilentlyContinue) {
                    throw
                }
                $oldProcessExited = $true
                break
            }
        }
        if (-not $oldProcessExited) {
            throw "Lifecycle restart cycle $cycle old process did not exit."
        }
        Write-AcceptancePhase -Name 'OLD_EXIT' -State 'PASS' -Detail "CYCLE=$cycle ELAPSED_MS=$($oldExitStopwatch.ElapsedMilliseconds)"

        Write-AcceptancePhase -Name 'LOCK_READY' -State 'BEGIN' -Detail "CYCLE=$cycle TIMEOUT_SEC=30"
        $replacementLockStopwatch = [Diagnostics.Stopwatch]::StartNew()
        $replacementLock = $null
        while ($replacementLockStopwatch.Elapsed.TotalSeconds -lt 30) {
            Start-Sleep -Milliseconds 50
            if (-not (Test-Path -LiteralPath $lifecycleLockPath -PathType Leaf)) {
                continue
            }
            try {
                $candidateLock = [IO.File]::ReadAllText(
                    $lifecycleLockPath,
                    [Text.Encoding]::UTF8
                ) | ConvertFrom-Json
            }
            catch {
                continue
            }
            if ([int]$candidateLock.pid -eq $oldPid) {
                continue
            }
            if (
                [string]$candidateLock.schema -ne
                    'eink-control-center-server-lock-v1' -or
                [int]$candidateLock.port -ne $lifecyclePort -or
                [IO.Path]::GetFullPath([string]$candidateLock.scriptPath) -ne
                    [IO.Path]::GetFullPath($serverPath) -or
                [IO.Path]::GetFullPath([string]$candidateLock.repoRoot) -ne
                    [IO.Path]::GetFullPath($repoRoot)
            ) {
                throw "Lifecycle restart cycle $cycle replacement lock is invalid."
            }
            $replacementProcess = Get-Process `
                -Id ([int]$candidateLock.pid) `
                -ErrorAction Stop
            if (
                $replacementProcess.StartTime.ToUniversalTime().Ticks -ne
                    [int64]$candidateLock.processStartTicks -or
                [IO.Path]::GetFullPath($replacementProcess.Path) -ne
                    [IO.Path]::GetFullPath(
                        [string]$candidateLock.executablePath
                    )
            ) {
                throw "Lifecycle restart cycle $cycle replacement identity mismatch."
            }
            $replacementLock = $candidateLock
            break
        }
        if (-not $replacementLock) {
            throw "Lifecycle restart cycle $cycle replacement lock timed out."
        }
        Write-AcceptancePhase -Name 'LOCK_READY' -State 'PASS' -Detail "CYCLE=$cycle PID=$($replacementLock.pid) ELAPSED_MS=$($replacementLockStopwatch.ElapsedMilliseconds)"

        Write-AcceptancePhase -Name 'STATUS_READY' -State 'BEGIN' -Detail "CYCLE=$cycle TIMEOUT_SEC=30"
        $statusStopwatch = [Diagnostics.Stopwatch]::StartNew()
        $replacementStatus = Wait-LifecycleStatus `
            -Phase "LIFECYCLE_REPLACEMENT_STATUS_WAIT_CYCLE_$cycle" `
            -DifferentFromPid $oldPid `
            -TimeoutSec 30
        if (
            -not $replacementStatus -or
            [int]$replacementStatus.lifecycle.pid -ne
                [int]$replacementLock.pid
        ) {
            throw "Lifecycle restart cycle $cycle status handshake failed."
        }
        Write-AcceptancePhase -Name 'STATUS_READY' -State 'PASS' -Detail "CYCLE=$cycle PID=$($replacementLock.pid) ELAPSED_MS=$($statusStopwatch.ElapsedMilliseconds)"
        $currentIdentity = Assert-LifecycleIdentity `
            -Status $replacementStatus `
            -Phase "LIFECYCLE_RESTART_IDENTITY_CYCLE_$cycle"
        $currentStatus = $replacementStatus

        $restartTracePath = Join-Path $runtimeRoot (
            "restart-$oldPid.stdout.log"
        )
        Write-AcceptancePhase -Name 'LIFECYCLE_LAUNCHER_TRACE' -State 'BEGIN' -Detail "CYCLE=$cycle TIMEOUT_SEC=10"
        $traceWatch = [Diagnostics.Stopwatch]::StartNew()
        $restartTrace = @()
        while ($traceWatch.Elapsed.TotalSeconds -lt 10) {
            if (Test-Path -LiteralPath $restartTracePath -PathType Leaf) {
                try {
                    $restartTrace = @(Read-SharedUtf8Lines `
                        -Path $restartTracePath)
                }
                catch [IO.IOException] {
                    Start-Sleep -Milliseconds 50
                    continue
                }
                if (@($restartTrace | Where-Object {
                    $_ -match '\sSTATUS_READY\sPASS\s'
                }).Count -gt 0) {
                    break
                }
            }
            Start-Sleep -Milliseconds 50
        }
        $requiredLauncherPhases = @(
            'OLD_EXIT',
            'PORT_FREE',
            'REPLACEMENT_STARTED',
            'LOCK_READY',
            'STATUS_READY'
        )
        $lastPhaseIndex = -1
        foreach ($requiredPhase in $requiredLauncherPhases) {
            $phaseIndex = -1
            for ($lineIndex = 0; $lineIndex -lt $restartTrace.Count; $lineIndex++) {
                if (
                    $restartTrace[$lineIndex] -match
                        ("\s{0}\sPASS\s" -f $requiredPhase)
                ) {
                    $phaseIndex = $lineIndex
                    break
                }
            }
            if ($phaseIndex -le $lastPhaseIndex) {
                throw "Lifecycle restart cycle $cycle launcher phase order failed at $requiredPhase."
            }
            $lastPhaseIndex = $phaseIndex
        }
        $restartTrace | Where-Object {
            $_ -match '\s(OLD_EXIT|PORT_FREE|REPLACEMENT_STARTED|LOCK_READY|STATUS_READY)\sPASS\s'
        } | ForEach-Object {
            Write-Host "LIFECYCLE_LAUNCHER_TRACE CYCLE=$cycle $_"
        }
        Write-AcceptancePhase -Name 'LIFECYCLE_LAUNCHER_TRACE' -State 'PASS' -Detail "CYCLE=$cycle"
    }

    $secondStatus = $currentStatus
    $secondIdentity = $currentIdentity

    $stopHeaders = @{
        'X-Eink-Control-Token' = [string]$secondStatus.sessionToken
    }
    Write-AcceptancePhase -Name 'LIFECYCLE_STOP_HTTP' -State 'BEGIN' -Detail 'TIMEOUT_SEC=10'
    $stop = Invoke-RestMethod `
        -Uri ($lifecycleUrl + 'api/lifecycle/stop') `
        -Method Post `
        -Headers $stopHeaders `
        -ContentType 'application/json' `
        -Body '{}' `
        -DisableKeepAlive `
        -TimeoutSec 10
    Write-AcceptancePhase -Name 'LIFECYCLE_STOP_HTTP' -State 'PASS' -Detail "PID=$($stop.pid)"
    if (
        [string]$stop.result -ne 'STOPPING' -or
        [int]$stop.pid -ne $secondIdentity.Pid
    ) {
        throw 'Lifecycle stop did not target the tracked replacement PID.'
    }

    Write-AcceptancePhase -Name 'LIFECYCLE_STOP_WAIT' -State 'BEGIN' -Detail 'TIMEOUT_SEC=30'
    $stopwatch = [Diagnostics.Stopwatch]::StartNew()
    $stopped = $false
    while ($stopwatch.Elapsed.TotalSeconds -lt 30) {
        Start-Sleep -Milliseconds 250
        $running = Get-Process -Id $secondIdentity.Pid -ErrorAction SilentlyContinue
        if (-not $running) {
            $stopped = $true
            break
        }
        if (
            $running.StartTime.ToUniversalTime().Ticks -ne
            $secondIdentity.StartTicks
        ) {
            throw 'Lifecycle stop wait observed PID reuse.'
        }
    }
    if (-not $stopped) {
        throw 'Lifecycle exact replacement process did not stop before timeout.'
    }
    Write-AcceptancePhase -Name 'LIFECYCLE_STOP_WAIT' -State 'PASS' -Detail "ELAPSED_MS=$($stopwatch.ElapsedMilliseconds)"

    Write-AcceptancePhase -Name 'LIFECYCLE_LOCK_CLEANUP_WAIT' -State 'BEGIN' -Detail 'TIMEOUT_SEC=10'
    $lockStopwatch = [Diagnostics.Stopwatch]::StartNew()
    while (
        $lockStopwatch.Elapsed.TotalSeconds -lt 10 -and
        (Test-Path -LiteralPath $lifecycleLockPath)
    ) {
        Start-Sleep -Milliseconds 100
    }
    if (Test-Path -LiteralPath $lifecycleLockPath) {
        throw 'Lifecycle identity lock was not removed before timeout.'
    }
    Write-AcceptancePhase -Name 'LIFECYCLE_LOCK_CLEANUP_WAIT' -State 'PASS' -Detail "ELAPSED_MS=$($lockStopwatch.ElapsedMilliseconds)"

    $serverTraceLines = @([IO.File]::ReadAllLines(
        $lifecycleTracePath,
        [Text.Encoding]::UTF8
    ))
    $listenerStopCount = @($serverTraceLines | Where-Object {
        $_ -match '\sLISTENER_STOP_PASS\s'
    }).Count
    $lockRemoveCount = @($serverTraceLines | Where-Object {
        $_ -match '\sLOCK_REMOVE_PASS\s'
    }).Count
    if ($listenerStopCount -lt 6 -or $lockRemoveCount -lt 6) {
        throw "Lifecycle shutdown trace incomplete: listener=$listenerStopCount lock=$lockRemoveCount."
    }
    Write-AcceptancePhase -Name 'LIFECYCLE_SHUTDOWN_TRACE' -State 'PASS' -Detail "LISTENER_STOP_COUNT=$listenerStopCount LOCK_REMOVE_COUNT=$lockRemoveCount"
}
finally {
    Write-AcceptancePhase -Name 'LIFECYCLE_FINALLY_CLEANUP' -State 'BEGIN'
    foreach ($identity in @($knownLifecycleIdentities | Sort-Object Pid -Unique)) {
        try {
            $running = Get-Process -Id $identity.Pid -ErrorAction Stop
            if (
                $running.StartTime.ToUniversalTime().Ticks -ne
                    $identity.StartTicks -or
                [IO.Path]::GetFullPath($running.Path) -ne
                    [IO.Path]::GetFullPath($identity.ExecutablePath)
            ) {
                throw 'Lifecycle cleanup exact process identity mismatch.'
            }
            Stop-Process -Id $running.Id -Force
            Write-AcceptancePhase -Name 'LIFECYCLE_FINALLY_CLEANUP' -State 'PROCESS_STOPPED' -Detail "PID=$($running.Id)"
        }
        catch [Microsoft.PowerShell.Commands.ProcessCommandException] {
        }
    }
    if (Test-Path -LiteralPath $lifecycleLockPath -PathType Leaf) {
        $remainingLock = [IO.File]::ReadAllText(
            $lifecycleLockPath,
            [Text.Encoding]::UTF8
        ) | ConvertFrom-Json
        $knownRemainingIdentity = @($knownLifecycleIdentities | Where-Object {
            $_.Pid -eq [int]$remainingLock.pid -and
            $_.StartTicks -eq [int64]$remainingLock.processStartTicks -and
            [IO.Path]::GetFullPath($_.ExecutablePath) -eq
                [IO.Path]::GetFullPath([string]$remainingLock.executablePath)
        } | Select-Object -First 1)
        if (
            [int]$remainingLock.port -eq $lifecyclePort -and
            [IO.Path]::GetFullPath([string]$remainingLock.scriptPath) -eq
                [IO.Path]::GetFullPath($serverPath) -and
            $knownRemainingIdentity.Count -eq 1
        ) {
            try {
                $remainingProcess = Get-Process `
                    -Id ([int]$remainingLock.pid) `
                    -ErrorAction Stop
                if (
                    $remainingProcess.StartTime.ToUniversalTime().Ticks -ne
                        [int64]$remainingLock.processStartTicks -or
                    [IO.Path]::GetFullPath($remainingProcess.Path) -ne
                        [IO.Path]::GetFullPath(
                            [string]$remainingLock.executablePath
                        )
                ) {
                    throw 'Lifecycle remaining lock process identity mismatch.'
                }
                Stop-Process -Id $remainingProcess.Id -Force
                Write-AcceptancePhase -Name 'LIFECYCLE_FINALLY_CLEANUP' -State 'LOCKED_PROCESS_STOPPED' -Detail "PID=$($remainingProcess.Id)"
            }
            catch [Microsoft.PowerShell.Commands.ProcessCommandException] {
            }
            catch {
                if (
                    Get-Process `
                        -Id ([int]$remainingLock.pid) `
                        -ErrorAction SilentlyContinue
                ) {
                    throw
                }
            }
            Remove-Item -LiteralPath $lifecycleLockPath -Force
            Write-AcceptancePhase -Name 'LIFECYCLE_FINALLY_CLEANUP' -State 'LOCK_REMOVED'
        }
    }
    Write-AcceptancePhase -Name 'LIFECYCLE_SERVER_TRACE_READ' -State 'BEGIN'
    if (Test-Path -LiteralPath $lifecycleTracePath -PathType Leaf) {
        [IO.File]::ReadAllLines(
            $lifecycleTracePath,
            [Text.Encoding]::UTF8
        ) | ForEach-Object {
            Write-Host "LIFECYCLE_SERVER_TRACE $_"
        }
    }
    Write-AcceptancePhase -Name 'LIFECYCLE_SERVER_TRACE_READ' -State 'PASS'
    [Environment]::SetEnvironmentVariable(
        'EINK_CONTROL_CENTER_ACCEPTANCE_TRACE',
        $previousLifecycleTrace,
        'Process'
    )
    Write-AcceptancePhase -Name 'LIFECYCLE_FINALLY_CLEANUP' -State 'PASS'
}

$output | ForEach-Object { Write-Output $_ }
Write-Output 'EINK CONTROL CENTER BURN PATH PLAN ACCEPTANCE: PASS'
Write-Output 'CONTROL_CENTER_EXECUTION_PATH: PASS'
Write-Output 'PROFILE_PATH_AFTER_BINDING: PASS'
Write-Output 'SMARTSNIPPETS_ERASE_WRITE: NOT REACHED'
Write-Output 'FIRMWARE_SOURCE: PRESERVED'
Write-Output 'LOCKED_ARTIFACT: PRESERVED'
Write-Output 'PHYSICAL_PASS_TEXT_ONLY_FEEDBACK: ACCEPTED'
Write-Output 'PHYSICAL_PASS_FEEDBACK_UTF8_EXACT: PASS'
Write-Output 'LIFECYCLE_HIDDEN_START: PASS'
Write-Output 'LIFECYCLE_DUPLICATE_SPAWN: BLOCKED'
Write-Output 'LIFECYCLE_EXACT_RESTART: PASS'
Write-Output 'LIFECYCLE_RESTART_CYCLES: 5'
Write-Output 'LIFECYCLE_EXACT_STOP: PASS'
