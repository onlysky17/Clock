[CmdletBinding()]
param(
    [ValidateRange(1024, 65535)]
    [int]$Port = 5175,

    [switch]$NoBrowser,

    [switch]$AcceptanceMode,

    [string]$AcceptanceWorkspace = '',

    [string]$AcceptanceFixturePath = '',

    [switch]$BurnPlanAcceptance,

    [string]$BurnPlanPackedBin = '',

    [switch]$BurnSafetyAcceptance,

    [string]$BurnSafetyProfilePath = '',

    [string]$BurnSafetyPackedBin = '',

    [switch]$FeedbackTransportAcceptance,

    [string]$BrainAcceptanceRoot = ''
)

$ErrorActionPreference = 'Stop'

$repoRoot = if ($AcceptanceMode) {
    if (
        $Port -eq 5175 -or
        [string]::IsNullOrWhiteSpace($AcceptanceWorkspace) -or
        [string]::IsNullOrWhiteSpace($AcceptanceFixturePath)
    ) {
        throw 'Acceptance mode requires an isolated workspace, fixture, and non-production port.'
    }

    (Resolve-Path $AcceptanceWorkspace).Path
}
else {
    if (
        -not [string]::IsNullOrWhiteSpace($AcceptanceWorkspace) -or
        -not [string]::IsNullOrWhiteSpace($AcceptanceFixturePath)
    ) {
        throw 'Acceptance fixture parameters are forbidden in production mode.'
    }

    (
        Resolve-Path (
            Join-Path $PSScriptRoot '..\..\..'
        )
    ).Path
}

Set-Location $repoRoot

$profilePath = Join-Path $repoRoot 'tools\harness\eink-profile.json'
$indexPath   = Join-Path $PSScriptRoot 'index.html'
$registryPath = Join-Path $PSScriptRoot 'projects.json'
$prepareScript = Join-Path $repoRoot 'scripts\eink.ps1'
$burnScript    = Join-Path $repoRoot 'scripts\eink-spi-burn.ps1'
$launcherPath  = Join-Path $repoRoot 'scripts\eink-control-center.ps1'
$prepareEvidenceRoot = Join-Path $repoRoot '_incoming\EINK_HARNESS_PREPARE_TEST'
$prepareTrustStatePath = Join-Path $prepareEvidenceRoot 'control-center-prepare-state.json'
$ownerFinalizeRoot = Join-Path $repoRoot '_incoming\EINK_HARNESS_CONTROL_CENTER_FINALIZE'
$burnVerificationStatePath = Join-Path $ownerFinalizeRoot 'burn-verification-state.json'
$ownerFinalizeStatePath = Join-Path $ownerFinalizeRoot 'owner-finalize-state.json'
$activeFinalizeTaskPath = Join-Path $ownerFinalizeRoot 'active-task.json'

$brainDefaultRoot = Join-Path $repoRoot '_incoming\EINK_HARNESS_BRAIN'
$brainRoot = if (-not [string]::IsNullOrWhiteSpace($BrainAcceptanceRoot)) {
    if ($Port -eq 5175 -or -not $NoBrowser) {
        throw 'Brain acceptance storage override requires non-production port and -NoBrowser.'
    }

    $candidateBrainRoot = [IO.Path]::GetFullPath($BrainAcceptanceRoot)
    $incomingPrefix = [IO.Path]::GetFullPath(
        (Join-Path $repoRoot '_incoming')
    ).TrimEnd('\') + '\'

    if (-not $candidateBrainRoot.StartsWith(
        $incomingPrefix,
        [StringComparison]::OrdinalIgnoreCase
    )) {
        throw 'Brain acceptance storage must stay inside repository _incoming.'
    }

    $candidateBrainRoot
}
else {
    $brainDefaultRoot
}

$brainCurrentTaskPath = Join-Path $brainRoot 'current-task.json'
$brainHistoryPath = Join-Path $brainRoot 'history.jsonl'

$runtimeRoot = Join-Path $repoRoot '_incoming\EINK_HARNESS_CONTROL_CENTER_RUNTIME'
$preEraseBackupEvidenceDir = Join-Path $repoRoot '_incoming\EINK_HARNESS_SPI_BACKUP\20260822_114022'
$preEraseBackupSha256 = '8824C5F9D6F99A1192770225EA14D4C7B861537D193CF77C632D0849FDBC58C1'
$script:AcceptancePrepareCandidate = $null
if ($BurnSafetyAcceptance) {
    if ($AcceptanceMode -or $Port -eq 5175 -or -not $NoBrowser -or
        [string]::IsNullOrWhiteSpace($BurnSafetyProfilePath) -or
        [string]::IsNullOrWhiteSpace($BurnSafetyPackedBin)) {
        throw 'Burn safety acceptance requires production workspace, non-production port, -NoBrowser, fixture profile, and packed BIN.'
    }
    $fixtureProfile = [IO.Path]::GetFullPath($BurnSafetyProfilePath)
    $runtimePrefix = [IO.Path]::GetFullPath($runtimeRoot).TrimEnd('\') + '\'
    if (-not $fixtureProfile.StartsWith($runtimePrefix, [StringComparison]::OrdinalIgnoreCase)) {
        throw 'Burn safety fixture profile must stay inside the Control Center runtime root.'
    }
    $profilePath = $fixtureProfile
}
$runtimeLockPath = Join-Path $runtimeRoot ("server-$Port.json")
$burnRuntimePath = Join-Path $runtimeRoot ("burn-$Port.json")
$currentProcess = Get-Process -Id $PID
$serverStartUtc = $currentProcess.StartTime.ToUniversalTime().ToString('o')
$serverStartTicks = $currentProcess.StartTime.ToUniversalTime().Ticks
$acceptanceTracePath = [Environment]::GetEnvironmentVariable(
    'EINK_CONTROL_CENTER_ACCEPTANCE_TRACE',
    'Process'
)
if (-not [string]::IsNullOrWhiteSpace($acceptanceTracePath)) {
    $acceptanceTracePath = [IO.Path]::GetFullPath($acceptanceTracePath)
    $runtimePrefix = [IO.Path]::GetFullPath($runtimeRoot).TrimEnd('\') + '\'
    if (
        $Port -eq 5175 -or
        -not $acceptanceTracePath.StartsWith(
            $runtimePrefix,
            [StringComparison]::OrdinalIgnoreCase
        )
    ) {
        $acceptanceTracePath = ''
    }
}

function Write-AcceptanceLifecycleTrace {
    param(
        [Parameter(Mandatory=$true)][string]$Phase,
        [string]$Detail = ''
    )

    if ([string]::IsNullOrWhiteSpace($acceptanceTracePath)) {
        return
    }
    $line = '{0} PID={1} PORT={2} {3} {4}{5}' -f (
        (Get-Date).ToUniversalTime().ToString('o'),
        $PID,
        $Port,
        $Phase,
        $Detail,
        [Environment]::NewLine
    )
    [IO.File]::AppendAllText(
        $acceptanceTracePath,
        $line,
        [Text.UTF8Encoding]::new($false)
    )
}

$profile = [IO.File]::ReadAllText(
    $profilePath,
    [Text.Encoding]::UTF8
) | ConvertFrom-Json

if (-not (Test-Path -LiteralPath $registryPath -PathType Leaf)) {
    throw 'Harness Hub project registry is missing.'
}

$projectRegistry = [IO.File]::ReadAllText(
    $registryPath,
    [Text.Encoding]::UTF8
) | ConvertFrom-Json

if ([int]$projectRegistry.version -ne 2) {
    throw 'Unsupported Harness Hub project registry version.'
}

$sessionToken = [Guid]::NewGuid().ToString('N')
$writeTokenHeaderName = 'X-Eink-Control-Token'
$writeTokenHeaderKey = $writeTokenHeaderName.ToLowerInvariant()

$script:Busy = $false
$script:StopRequested = $false
$script:LastAction = 'START'
$script:LastResult = 'IDLE'
$script:PrepareTrustFailureOverride = $null
$script:BurnVerificationOverride = $null
$script:BurnRecoveryRequired = $false
$script:RecoveryChallengeHash = ''
$script:RecoveryChallengeExpiresUtc = [DateTime]::MinValue
$script:RecoveryChallengeArtifactSha = ''
$script:LastLog = @(
    'Harness Control Center Multiproject v0.4 started.',
    'Waiting for action.'
)

function Invoke-NativeText {
    param(
        [Parameter(Mandatory=$true)]
        [string]$FilePath,

        [Parameter(Mandatory=$true)]
        [string[]]$Arguments
    )

    $previous = $ErrorActionPreference

    try {
        $ErrorActionPreference = 'Continue'

        $output = @(
            & $FilePath @Arguments 2>&1 |
            ForEach-Object { $_.ToString() }
        )

        $exitCode = $LASTEXITCODE
    }
    finally {
        $ErrorActionPreference = $previous
    }

    [PSCustomObject]@{
        ExitCode = $exitCode
        Output = $output
    }
}

function Invoke-EinkSpiBurnScript {
    param(
        [Parameter(Mandatory=$true)]
        [ValidateSet('Plan', 'Burn')]
        [string]$Mode,

        [Parameter(Mandatory=$true)]
        [string]$PackedBin,

        [string]$ExpectedPackedSha256 = ''
    )

    $arguments = @(
        '-NoProfile',
        '-ExecutionPolicy',
        'Bypass',
        '-File',
        $burnScript,
        '-PackedBin',
        $PackedBin,
        '-Mode',
        $Mode,
        '-ProfilePath',
        $profilePath
    )

    if ($Mode -eq 'Burn') { throw 'Synchronous real burn execution is forbidden.' }

    Invoke-NativeText `
        -FilePath 'powershell.exe' `
        -Arguments $arguments
}

function Test-BurnWorkerIdentity {
    param($Record)
    if (-not $Record -or [string]$Record.schema -ne 'eink-control-center-burn-worker-v1') {
        return $false
    }
    try {
        $process = Get-Process -Id ([int]$Record.pid) -ErrorAction Stop
        return (
            $process.StartTime.ToUniversalTime().Ticks -eq [int64]$Record.processStartTicks -and
            [IO.Path]::GetFullPath($process.Path) -eq [IO.Path]::GetFullPath([string]$Record.executablePath)
        )
    }
    catch { return $false }
}

function Get-BurnPhaseState {
    param($Record)
    if (-not $Record -or [string]::IsNullOrWhiteSpace([string]$Record.phaseStatePath)) {
        return $null
    }
    Read-Utf8JsonFile -Path ([string]$Record.phaseStatePath)
}

function Start-EinkBurnWorker {
    param(
        [Parameter(Mandatory=$true)]$Candidate,
        [Parameter(Mandatory=$true)]$RepoState,
        [switch]$RecoveryWrite,
        [string]$RecoveryChallenge = ''
    )
    if (-not (Test-Path -LiteralPath $runtimeRoot -PathType Container)) {
        [void](New-Item -ItemType Directory -Path $runtimeRoot -Force)
    }
    $attemptId = [Guid]::NewGuid().ToString('N')
    $phasePath = Join-Path $runtimeRoot ("burn-$attemptId.phase.json")
    $stdoutPath = Join-Path $runtimeRoot ("burn-$attemptId.stdout.log")
    $stderrPath = Join-Path $runtimeRoot ("burn-$attemptId.stderr.log")
    foreach ($path in @($phasePath, $stdoutPath, $stderrPath)) {
        Remove-Item -LiteralPath $path -Force -ErrorAction SilentlyContinue
    }
    $arguments = @(
        '-NoProfile','-ExecutionPolicy','Bypass','-File',"`"$burnScript`"",
        '-PackedBin',"`"$($Candidate.Path)`"",'-Mode','Burn',
        '-ProfilePath',"`"$profilePath`"",
        '-ExpectedPackedSha256',$Candidate.Sha256,
        '-ConfirmToken',[string]$profile.spiBurn.confirmationToken,
        '-PhaseStatePath',"`"$phasePath`"",
        '-AllowDirtyTrackedTree'
    )
    if ($BurnSafetyAcceptance) {
        $arguments += '-PreflightAcceptanceOnly'
    }
    if ($RecoveryWrite) {
        if ([string]::IsNullOrWhiteSpace($RecoveryChallenge)) {
            throw 'Consumed recovery Owner challenge is required.'
        }
        $arguments += @(
            '-RecoveryWriteOnly',
            '-RecoveryConfirmToken',$RecoveryChallenge,
            '-PreEraseBackupEvidenceDir',"`"$preEraseBackupEvidenceDir`"",
            '-ExpectedPreEraseBackupSha256',$preEraseBackupSha256
        )
    }
    $process = Start-Process -FilePath 'powershell.exe' -ArgumentList $arguments `
        -RedirectStandardOutput $stdoutPath -RedirectStandardError $stderrPath `
        -WindowStyle Hidden -PassThru
    $record = [ordered]@{
        schema = 'eink-control-center-burn-worker-v1'
        operation = if ($RecoveryWrite) { 'RECOVERY_WRITE' } else { 'NORMAL_BURN' }
        attemptId = $attemptId
        status = 'RUNNING'
        handled = $false
        pid = [int]$process.Id
        processStartTicks = [int64]$process.StartTime.ToUniversalTime().Ticks
        executablePath = [string]$process.Path
        createdUtc = [DateTime]::UtcNow.ToString('o')
        completedUtc = ''
        reason = ''
        phaseStatePath = $phasePath
        stdoutPath = $stdoutPath
        stderrPath = $stderrPath
        artifactPath = [string]$Candidate.Path
        artifactSha256 = [string]$Candidate.Sha256
        workspaceFingerprint = [string]$Candidate.WorkspaceFingerprint
        approvedFilesFingerprint = Get-ApprovedFilesFingerprint
        branch = [string]$RepoState.Branch
        head = [string]$RepoState.Head
        taskId = [string]$einkRegistryProject.finalize.taskId
    }
    Write-Utf8JsonFile -Path $burnRuntimePath -Value $record
    $record
}

function Sync-BurnRuntimeState {
    $record = Read-Utf8JsonFile -Path $burnRuntimePath
    if (-not $record) { return $null }
    $phase = Get-BurnPhaseState -Record $record
    $isRecoveryWrite = [string]$record.operation -eq 'RECOVERY_WRITE'
    if ([string]$record.status -eq 'RUNNING') {
        if (Test-BurnWorkerIdentity -Record $record) { return [pscustomobject]@{ Record=$record; Phase=$phase; Running=$true } }
        $pidCollision = $false
        try { [void](Get-Process -Id ([int]$record.pid) -ErrorAction Stop); $pidCollision = $true } catch { }
        if ($pidCollision) {
            $record.status = 'RECOVERY_REQUIRED'
            $record.handled = $true
            $record.completedUtc = [DateTime]::UtcNow.ToString('o')
            $record.reason = 'BURN_WORKER_IDENTITY_MISMATCH'
            $script:BurnRecoveryRequired = $true
            Set-LastLog -Action 'SPI_BURN' -Result 'RECOVERY_REQUIRED' -Lines @('BLOCKED: BURN_WORKER_IDENTITY_MISMATCH')
        }
        elseif ($phase -and [string]$phase.phase -in @('SHA_VERIFY','RECOVERY_SHA_VERIFY') -and [string]$phase.status -eq 'PASS') {
            $candidate = Get-LatestPrepareCandidate -RepoState (Get-RepoState)
            $stdout = Get-Utf8TextTail -Path ([string]$record.stdoutPath) -MaxLines 80
            $recoveryEvidenceValid = -not $isRecoveryWrite -or (
                $stdout -match 'ACTION: SPI-RECOVERY-WRITE' -and
                $stdout -match 'NORMAL_FRESH_BACKUP: SKIPPED' -and
                $stdout -match 'ERASE: SKIPPED' -and
                $stdout -match ('PRE_ERASE_BACKUP_SHA256: ' + [regex]::Escape($preEraseBackupSha256)) -and
                $stdout -match 'RECOVERY_TARGET: CURRENT_ARTIFACT'
            )
            if ($candidate -and $candidate.Sha256 -eq [string]$record.artifactSha256 -and
                $stdout -match 'NEXT_STATE: SPI_BURN_VERIFIED' -and $recoveryEvidenceValid) {
                [void](Set-BurnVerificationState -Candidate $candidate)
                $record.status = 'SPI_BURN_VERIFIED'
                $record.handled = $true
                $record.completedUtc = [DateTime]::UtcNow.ToString('o')
                $script:BurnRecoveryRequired = $false
                Set-LastLog -Action 'SPI_BURN' -Result 'SPI_BURN_VERIFIED' -Lines @($stdout)
            }
            else {
                $record.status = 'RECOVERY_REQUIRED'
                $record.handled = $true
                $record.reason = 'BURN_SUCCESS_EVIDENCE_INVALID'
                $script:BurnRecoveryRequired = $true
                Set-LastLog -Action 'SPI_BURN' -Result 'RECOVERY_REQUIRED' -Lines @('BLOCKED: BURN_SUCCESS_EVIDENCE_INVALID')
            }
        }
        elseif ($isRecoveryWrite) {
            $record.status = 'RECOVERY_REQUIRED'
            $record.handled = $true
            $record.completedUtc = [DateTime]::UtcNow.ToString('o')
            $record.reason = if ($phase -and -not [string]::IsNullOrWhiteSpace([string]$phase.reason)) { [string]$phase.reason } else { 'RECOVERY_WORKER_FAILED' }
            $script:BurnRecoveryRequired = $true
            Set-LastLog -Action 'SPI_RECOVERY_WRITE' -Result 'RECOVERY_REQUIRED' -Lines @("BLOCKED: $($record.reason)")
        }
        elseif ($phase -and -not [bool]$phase.destructiveStarted) {
            $record.status = 'FAILED_SAFE'
            $record.handled = $true
            $record.completedUtc = [DateTime]::UtcNow.ToString('o')
            $record.reason = if ([string]::IsNullOrWhiteSpace([string]$phase.reason)) { 'FAILED_SAFE' } else { [string]$phase.reason }
            $stdout = Get-Utf8TextTail -Path ([string]$record.stdoutPath) -MaxLines 80
            Set-LastLog -Action 'SPI_BURN' -Result $record.reason -Lines @($stdout, "SAFE_RETURN: READY_TO_BURN", "REASON: $($record.reason)")
        }
        else {
            $record.status = 'RECOVERY_REQUIRED'
            $record.handled = $true
            $record.completedUtc = [DateTime]::UtcNow.ToString('o')
            $record.reason = if ($phase) { [string]$phase.reason } else { 'BURN_WORKER_EXITED_WITHOUT_PHASE_EVIDENCE' }
            $script:BurnRecoveryRequired = $true
            Set-LastLog -Action 'SPI_BURN' -Result 'RECOVERY_REQUIRED' -Lines @("BLOCKED: $($record.reason)")
        }
        Write-Utf8JsonFile -Path $burnRuntimePath -Value $record
    }
    [pscustomobject]@{ Record=$record; Phase=$phase; Running=$false }
}

function Invoke-Git {
    param(
        [Parameter(Mandatory=$true)]
        [string[]]$Arguments
    )

    Invoke-NativeText -FilePath 'git' -Arguments $Arguments
}

function Get-Sha256Hex {
    param(
        [Parameter(Mandatory=$true)]
        [string]$Path
    )

    $stream = $null
    $sha = $null

    try {
        $stream = [IO.File]::OpenRead($Path)
        $sha = [Security.Cryptography.SHA256]::Create()
        $bytes = $sha.ComputeHash($stream)

        (
            [BitConverter]::ToString($bytes)
        ).Replace('-', '').ToUpperInvariant()
    }
    finally {
        if ($sha) {
            $sha.Dispose()
        }

        if ($stream) {
            $stream.Dispose()
        }
    }
}

function Get-PreEraseBackupStatus {
    $read1 = Join-Path $preEraseBackupEvidenceDir 'BOARD1_SPI_READ1.bin'
    $read2 = Join-Path $preEraseBackupEvidenceDir 'BOARD1_SPI_READ2.bin'
    $valid = $false
    $reason = 'MISSING'
    $read1Size = -1
    $read2Size = -1
    $read1Sha = ''
    $read2Sha = ''
    try {
        if ((Test-Path -LiteralPath $read1 -PathType Leaf) -and
            (Test-Path -LiteralPath $read2 -PathType Leaf)) {
            $read1Size = [int64](Get-Item -LiteralPath $read1).Length
            $read2Size = [int64](Get-Item -LiteralPath $read2).Length
            $read1Sha = Get-Sha256Hex -Path $read1
            $read2Sha = Get-Sha256Hex -Path $read2
            $valid = $read1Size -eq 262144 -and $read2Size -eq 262144 -and
                $read1Sha -eq $preEraseBackupSha256 -and
                $read2Sha -eq $preEraseBackupSha256 -and
                $read1Sha -eq $read2Sha
            $reason = if ($valid) { 'IMMUTABLE_PRE_ERASE_BACKUP_VERIFIED' } else { 'SIZE_OR_SHA_MISMATCH' }
        }
    }
    catch {
        $reason = 'BACKUP_VALIDATION_EXCEPTION'
    }
    [pscustomobject]@{
        valid = [bool]$valid
        reason = $reason
        evidenceDir = $preEraseBackupEvidenceDir
        sha256 = $preEraseBackupSha256
        read1Size = $read1Size
        read2Size = $read2Size
        read1Sha256 = $read1Sha
        read2Sha256 = $read2Sha
        restoreAvailable = [bool]$valid
    }
}

function Get-TextSha256 {
    param(
        [Parameter(Mandatory=$true)]
        [string]$Text
    )

    $sha = [Security.Cryptography.SHA256]::Create()

    try {
        $bytes = [Text.Encoding]::UTF8.GetBytes($Text)
        $hash = $sha.ComputeHash($bytes)

        (
            [BitConverter]::ToString($hash)
        ).Replace('-', '').ToUpperInvariant()
    }
    finally {
        $sha.Dispose()
    }
}

function New-RecoveryOwnerChallenge {
    param([Parameter(Mandatory=$true)][string]$ArtifactSha256)
    $challenge = [Guid]::NewGuid().ToString('N')
    $script:RecoveryChallengeHash = Get-TextSha256 -Text $challenge
    $script:RecoveryChallengeExpiresUtc = [DateTime]::UtcNow.AddMinutes(2)
    $script:RecoveryChallengeArtifactSha = $ArtifactSha256.Trim().ToUpperInvariant()
    [pscustomobject]@{
        challenge = $challenge
        expiresUtc = $script:RecoveryChallengeExpiresUtc.ToString('o')
        artifactSha256 = $script:RecoveryChallengeArtifactSha
    }
}

function Test-AndConsumeRecoveryOwnerChallenge {
    param(
        [Parameter(Mandatory=$true)][string]$Challenge,
        [Parameter(Mandatory=$true)][string]$ArtifactSha256
    )
    $valid = -not [string]::IsNullOrWhiteSpace($Challenge) -and
        [DateTime]::UtcNow -le $script:RecoveryChallengeExpiresUtc -and
        (Get-TextSha256 -Text $Challenge) -eq $script:RecoveryChallengeHash -and
        $ArtifactSha256.Trim().ToUpperInvariant() -eq $script:RecoveryChallengeArtifactSha
    $script:RecoveryChallengeHash = ''
    $script:RecoveryChallengeExpiresUtc = [DateTime]::MinValue
    $script:RecoveryChallengeArtifactSha = ''
    return [bool]$valid
}

function Read-Utf8JsonFile {
    param(
        [Parameter(Mandatory=$true)]
        [string]$Path
    )

    if (-not (Test-Path -LiteralPath $Path -PathType Leaf)) {
        return $null
    }

    try {
        return (
            [IO.File]::ReadAllText(
                $Path,
                [Text.Encoding]::UTF8
            ) | ConvertFrom-Json
        )
    }
    catch {
        return $null
    }
}

function Get-Utf8TextTail {
    param(
        [Parameter(Mandatory=$true)]
        [string]$Path,

        [int]$MaxLines = 40,

        [int]$MaxChars = 8000
    )

    if (-not (Test-Path -LiteralPath $Path -PathType Leaf)) {
        return ''
    }

    try {
        $lines = [IO.File]::ReadAllLines(
            $Path,
            [Text.Encoding]::UTF8
        )

        if ($lines.Length -eq 0) {
            return ''
        }

        $start = [Math]::Max(0, $lines.Length - $MaxLines)
        $text = ($lines[$start..($lines.Length - 1)] -join "`n")

        if ($text.Length -gt $MaxChars) {
            return $text.Substring($text.Length - $MaxChars)
        }

        return $text
    }
    catch {
        return "Unable to read log: $($_.Exception.Message)"
    }
}

function Get-RegistryProject {
    param(
        [Parameter(Mandatory=$true)]
        [string]$ProjectId
    )

    @(
        $projectRegistry.projects |
        Where-Object {
            [string]$_.id -eq $ProjectId
        }
    ) | Select-Object -First 1
}

function Test-ProjectActionAllowed {
    param(
        [Parameter(Mandatory=$true)]
        $Project,

        [Parameter(Mandatory=$true)]
        [string]$ActionId,

        [Parameter(Mandatory=$true)]
        [string]$Method
    )

    foreach ($action in @($Project.actions)) {
        if (
            [string]$action.id -eq $ActionId -and
            [string]$action.method -eq $Method
        ) {
            return $true
        }
    }

    return $false
}

function Get-ElectronicFileStatus {
    param(
        [Parameter(Mandatory=$true)]
        $Project
    )

    $workspace = [IO.Path]::GetFullPath([string]$Project.workspace)
    $harnessRoot = Join-Path $workspace '.harness'

    if (-not (Test-Path -LiteralPath $harnessRoot -PathType Container)) {
        return [ordered]@{
            projectId = [string]$Project.id
            projectName = [string]$Project.name
            version = '0.2'
            adapter = [string]$Project.adapter
            readOnly = $true
            available = $false
            state = 'PLUGIN_UNAVAILABLE'
            message = 'Optional Harness Brain plugin is not available.'
            actions = @()
            sessionToken = $sessionToken
        }
    }

    $projectConfig = Read-Utf8JsonFile (
        Join-Path $harnessRoot 'project.json'
    )
    $state = Read-Utf8JsonFile (
        Join-Path $harnessRoot 'state.json'
    )
    $runtime = Read-Utf8JsonFile (
        Join-Path $harnessRoot 'runtime.json'
    )
    $queue = Read-Utf8JsonFile (
        Join-Path $harnessRoot 'queue.json'
    )

    $taskRoot = Join-Path $harnessRoot 'tasks'
    $taskFiles = if (Test-Path -LiteralPath $taskRoot -PathType Container) {
        @(
            Get-ChildItem -LiteralPath $taskRoot -File -Filter '*.json' |
            Sort-Object LastWriteTime -Descending |
            Select-Object -First 12
        )
    }
    else {
        @()
    }

    $tasks = @(
        foreach ($taskFile in $taskFiles) {
            $task = Read-Utf8JsonFile $taskFile.FullName

            if (-not $task) {
                continue
            }

            [ordered]@{
                taskId = [string]$task.task_id
                objective = [string]$task.objective
                createdAt = [string]$task.created_at
                modifiedAt = $taskFile.LastWriteTime.ToString('o')
                fileName = $taskFile.Name
            }
        }
    )

    $runRoot = Join-Path $harnessRoot 'runs'
    $runDirs = if (Test-Path -LiteralPath $runRoot -PathType Container) {
        @(
            Get-ChildItem -LiteralPath $runRoot -Directory |
            Sort-Object Name -Descending |
            Select-Object -First 12
        )
    }
    else {
        @()
    }

    $runs = @(
        foreach ($runDir in $runDirs) {
            $oracleSnapshotPath = Join-Path (
                Join-Path $runDir.FullName 'oracle-lock'
            ) 'snapshot.json'

            [ordered]@{
                runId = $runDir.Name
                modifiedAt = $runDir.LastWriteTime.ToString('o')
                oracleLocked = [bool](
                    Test-Path -LiteralPath $oracleSnapshotPath -PathType Leaf
                )
                validationLog = Get-Utf8TextTail `
                    -Path (Join-Path $runDir.FullName 'validation.stdout.log') `
                    -MaxLines 8 `
                    -MaxChars 1800
            }
        }
    )

    $agentRoot = Join-Path $harnessRoot 'agent-packets'
    $agentFiles = if (Test-Path -LiteralPath $agentRoot -PathType Container) {
        @(
            Get-ChildItem -LiteralPath $agentRoot -File |
            Sort-Object LastWriteTime -Descending |
            Select-Object -First 10
        )
    }
    else {
        @()
    }

    $agentRuns = @(
        foreach ($agentFile in $agentFiles) {
            [ordered]@{
                id = $agentFile.BaseName
                fileName = $agentFile.Name
                size = [int64]$agentFile.Length
                modifiedAt = $agentFile.LastWriteTime.ToString('o')
                preview = Get-Utf8TextTail `
                    -Path $agentFile.FullName `
                    -MaxLines 10 `
                    -MaxChars 2200
            }
        }
    )

    $latestRun = $runDirs | Select-Object -First 1
    $oracleSnapshot = $null
    $liveLogParts = New-Object Collections.Generic.List[string]

    if ($latestRun) {
        $oracleSnapshot = Read-Utf8JsonFile (
            Join-Path (
                Join-Path $latestRun.FullName 'oracle-lock'
            ) 'snapshot.json'
        )

        foreach ($logName in @(
            'validation.stdout.log',
            'validation.stderr.log'
        )) {
            $logPath = Join-Path $latestRun.FullName $logName
            $tail = Get-Utf8TextTail `
                -Path $logPath `
                -MaxLines 35 `
                -MaxChars 5500

            if (-not [string]::IsNullOrWhiteSpace($tail)) {
                $liveLogParts.Add("[$($latestRun.Name) / $logName]")
                $liveLogParts.Add($tail)
            }
        }
    }

    $brainGlobalRoot = ''

    if ($projectConfig -and $projectConfig.brain) {
        $brainGlobalRoot = [string]$projectConfig.brain.global_root
    }

    $brainLogPath = if ([string]::IsNullOrWhiteSpace($brainGlobalRoot)) {
        ''
    }
    else {
        Join-Path $brainGlobalRoot 'logs\harness-control.log'
    }

    if (-not [string]::IsNullOrWhiteSpace($brainLogPath)) {
        $brainTail = Get-Utf8TextTail `
            -Path $brainLogPath `
            -MaxLines 30 `
            -MaxChars 5500

        if (-not [string]::IsNullOrWhiteSpace($brainTail)) {
            $liveLogParts.Add('[Harness Brain / harness-control.log]')
            $liveLogParts.Add($brainTail)
        }
    }

    [ordered]@{
        projectId = [string]$Project.id
        projectName = [string]$Project.name
        version = '0.2'
        adapter = [string]$Project.adapter
        readOnly = $true
        available = $true
        workspace = $workspace
        branch = [string]$projectConfig.branch
        head = [string]$projectConfig.head
        state = if ($state) {
            [string]$state.state
        }
        else {
            'UNKNOWN'
        }
        currentTask = if ($state) {
            [ordered]@{
                taskId = [string]$state.taskId
                runId = [string]$state.runId
                result = [string]$state.result
                nextAction = [string]$state.nextAction
                ownerIntentStatus = [string]$state.ownerIntentStatus
                visualMachineGate = [string]$state.visualMachineGate
                agentResult = [string]$state.agentResult
                agentSummary = [string]$state.agentSummary
                completedAt = [string]$state.completedAt
            }
        }
        else {
            $null
        }
        runtime = $runtime
        queue = $queue
        tasks = $tasks
        runs = $runs
        agentRuns = $agentRuns
        oracle = [ordered]@{
            locked = [bool](
                $state -and [bool]$state.oracleLocked
            )
            snapshot = $oracleSnapshot
        }
        brain = [ordered]@{
            optional = $true
            enabled = [bool](
                $projectConfig -and
                $projectConfig.brain -and
                [bool]$projectConfig.brain.enabled
            )
            harnessBuild = [string]$projectConfig.harness_build
            logAvailable = [bool](
                -not [string]::IsNullOrWhiteSpace($brainLogPath) -and
                (Test-Path -LiteralPath $brainLogPath -PathType Leaf)
            )
        }
        liveLog = ($liveLogParts -join "`n`n")
        actions = @()
        sessionToken = $sessionToken
    }
}

function Invoke-HarnessCoreRequest {
    param(
        [Parameter(Mandatory=$true)]
        $Project,

        [Parameter(Mandatory=$true)]
        [ValidateSet('GET', 'POST')]
        [string]$Method,

        [Parameter(Mandatory=$true)]
        [string]$Route,

        $Body = $null,

        [int]$TimeoutSec = 10
    )

    $baseUrl = ([string]$Project.core.baseUrl).TrimEnd('/')

    if (
        $baseUrl -ne 'http://127.0.0.1:5174' -or
        -not $Route.StartsWith('/')
    ) {
        throw 'Harness Core endpoint is not an approved local route.'
    }

    $parameters = @{
        Uri = $baseUrl + $Route
        Method = $Method
        TimeoutSec = $TimeoutSec
    }

    if ($Method -eq 'POST') {
        $parameters.ContentType = 'application/json'
        $parameters.Body = if ($null -eq $Body) {
            '{}'
        }
        else {
            $Body | ConvertTo-Json -Depth 20 -Compress
        }
    }

    try {
        return Invoke-RestMethod @parameters
    }
    catch {
        $message = $_.Exception.Message
        $response = $_.Exception.Response

        if ($response) {
            try {
                $reader = New-Object IO.StreamReader(
                    $response.GetResponseStream(),
                    [Text.Encoding]::UTF8
                )

                try {
                    $responseBody = $reader.ReadToEnd()
                    $errorObject = $responseBody | ConvertFrom-Json

                    if (-not [string]::IsNullOrWhiteSpace([string]$errorObject.error)) {
                        $message = [string]$errorObject.error
                    }
                }
                finally {
                    $reader.Dispose()
                }
            }
            catch {
            }
        }

        throw "ELECTRIC_HARNESS_CORE: $message"
    }
}

function Convert-CoreEvidenceReferences {
    param($Evidence)

    @(
        foreach ($item in @($Evidence)) {
            $assetId = [string]$item.assetId

            if ([string]::IsNullOrWhiteSpace($assetId)) {
                continue
            }

            [ordered]@{
                assetId = $assetId
                kind = [string]$item.kind
                mime = [string]$item.mime
                filename = [string]$item.filename
                size = [int64]$item.size
                note = [string]$item.note
                taskId = [string]$item.taskId
                projectId = [string]$item.projectId
                derivedFrom = [string]$item.derivedFrom
                timestampSec = $item.timestampSec
                groupId = [string]$item.groupId
                derivativeType = [string]$item.derivativeType
                at = [string]$item.at
            }
        }
    )
}

function Start-ElectronicHarnessCore {
    param(
        [Parameter(Mandatory=$true)]
        $Project
    )

    try {
        [void](
            Invoke-HarnessCoreRequest `
                -Project $Project `
                -Method 'GET' `
                -Route '/api/state' `
                -TimeoutSec 2
        )

        return [ordered]@{
            ok = $true
            alreadyRunning = $true
        }
    }
    catch {
    }

    $scriptPath = [IO.Path]::GetFullPath(
        [string]$Project.core.script
    )
    $workingDirectory = [IO.Path]::GetFullPath(
        [string]$Project.core.workingDirectory
    )

    if (
        $scriptPath -ne 'D:\Private\APP\Electronic\tools\ElectricHarness\harness-core.mjs' -or
        $workingDirectory -ne 'D:\Private\APP\Electronic' -or
        -not (Test-Path -LiteralPath $scriptPath -PathType Leaf) -or
        -not (Test-Path -LiteralPath $workingDirectory -PathType Container)
    ) {
        throw 'Electronic Harness Core launch profile is invalid.'
    }

    $process = Start-Process `
        -FilePath 'node.exe' `
        -ArgumentList @(
            $scriptPath,
            'serve'
        ) `
        -WorkingDirectory $workingDirectory `
        -WindowStyle Hidden `
        -PassThru

    for ($i = 0; $i -lt 30; $i++) {
        Start-Sleep -Milliseconds 250

        try {
            $state = Invoke-HarnessCoreRequest `
                -Project $Project `
                -Method 'GET' `
                -Route '/api/state' `
                -TimeoutSec 1

            return [ordered]@{
                ok = $true
                alreadyRunning = $false
                processId = $process.Id
                buildId = [string]$state.buildId
            }
        }
        catch {
        }
    }

    throw 'Electronic Harness Core did not become ready on 127.0.0.1:5174.'
}

function Get-ElectronicStatus {
    param(
        [Parameter(Mandatory=$true)]
        $Project
    )

    try {
        $core = Invoke-HarnessCoreRequest `
            -Project $Project `
            -Method 'GET' `
            -Route '/api/state' `
            -TimeoutSec 4

        if (
            [string]$core.project.id -ne
            [string]$Project.core.projectId
        ) {
            throw (
                'Core active project mismatch. Expected=' +
                [string]$Project.core.projectId +
                ' Actual=' +
                [string]$core.project.id
            )
        }

        $brainStatus = Invoke-HarnessCoreRequest `
            -Project $Project `
            -Method 'GET' `
            -Route '/api/brain/status' `
            -TimeoutSec 6

        return [ordered]@{
            projectId = [string]$Project.id
            projectName = [string]$Project.name
            version = '0.2'
            adapter = 'harness-core'
            readOnly = [bool]$Project.readOnly
            paused = [bool]$Project.paused
            available = $true
            coreOnline = $true
            coreBuildId = [string]$core.buildId
            state = [string]$core.state.state
            status = $core.status
            busy = [bool]$core.busy
            phase = $core.phase
            runReservation = $core.runReservation
            currentTask = [ordered]@{
                taskId = [string]$core.state.taskId
                runId = [string]$core.state.runId
                result = [string]$core.state.result
                nextAction = [string]$core.state.nextAction
                ownerIntentStatus = [string]$core.ownerIntentStatus
                visualMachineGate = [string]$core.selfHeal.visualMachineGate
                agentResult = [string]$core.state.agentResult
                agentSummary = [string]$core.state.agentSummary
                validationCommand = [string]$core.state.validationCommand
                validationExitCode = $core.state.validationExitCode
                completedAt = [string]$core.state.completedAt
            }
            taskSpec = $core.task
            recentTasks = @($core.recentTasks)
            strategy = $core.selfHeal.strategy
            progress = [ordered]@{
                status = $core.status
                phase = $core.phase
                attempt = $core.selfHeal.attempt
                validationMetrics = $core.selfHeal.validationMetrics
                bestFailedCount = $core.selfHeal.bestFailedCount
                visualFailureRepeatCount = $core.selfHeal.visualFailureRepeatCount
                ownerRejectionStreak = $core.selfHeal.ownerRejectionStreak
            }
            runtime = [ordered]@{
                profile = $core.project.runtime
                appUrl = [string]$core.appUrl
                managedRuntimePid = $core.process.managedRuntimePid
                process = $core.process
                gate = $core.selfHeal.runtimeGate
            }
            oracle = [ordered]@{
                locked = [bool]$core.selfHeal.oracleLocked
                ownerContract = $core.task.owner_visual_contract
                visualMachineGate = [string]$core.selfHeal.visualMachineGate
            }
            brain = [ordered]@{
                optional = $true
                enabled = [bool]$core.project.brain.enabled
                supervisor = $core.supervisor
                status = $brainStatus
                root = [string]$core.brain.root
            }
            costQuota = $brainStatus.costGuard
            history = @($core.brain.history)
            memory = @($core.brain.memory)
            skills = @($core.brain.skills)
            evidence = Convert-CoreEvidenceReferences `
                -Evidence $core.storedEvidence
            liveLog = (@($core.logs) -join "`n")
            updater = [ordered]@{
                projectRediscoverApi = $true
                coreRestartApi = $true
                softwareUpdateApi = $false
            }
            actions = @($Project.actions)
            sessionToken = $sessionToken
        }
    }
    catch {
        $fallback = Get-ElectronicFileStatus -Project $Project
        $fallback['version'] = '0.2'
        $fallback['adapter'] = 'harness-core'
        $fallback['readOnly'] = $true
        $fallback['paused'] = [bool]$Project.paused
        $fallback['available'] = $false
        $fallback['coreOnline'] = $false
        $fallback['coreError'] = $_.Exception.Message
        $fallback['actions'] = @(
            $Project.actions |
            Where-Object {
                [string]$_.id -eq 'core-start'
            }
        )
        return $fallback
    }
}

function Invoke-ElectronicCoreAction {
    param(
        [Parameter(Mandatory=$true)]
        $Project,

        [Parameter(Mandatory=$true)]
        [string]$ActionId,

        $Body
    )

    if ($ActionId -eq 'core-start') {
        return Start-ElectronicHarnessCore -Project $Project
    }

    $coreState = Invoke-HarnessCoreRequest `
        -Project $Project `
        -Method 'GET' `
        -Route '/api/state' `
        -TimeoutSec 4

    if (
        [string]$coreState.project.id -ne
        [string]$Project.core.projectId
    ) {
        throw 'Electronic action blocked because Harness Core has another active project.'
    }

    switch ($ActionId) {
        'task-create' {
            $request = [string]$Body.request

            if ([string]::IsNullOrWhiteSpace($request)) {
                throw 'Task request is empty.'
            }

            return Invoke-HarnessCoreRequest `
                -Project $Project `
                -Method 'POST' `
                -Route '/api/task/create' `
                -Body ([ordered]@{
                    request = $request.Trim()
                    evidence = Convert-CoreEvidenceReferences `
                        -Evidence $Body.evidence
                }) `
                -TimeoutSec 30
        }

        'evidence-upload' {
            $base64 = [string]$Body.dataBase64

            if (
                [string]::IsNullOrWhiteSpace($base64) -or
                $base64.Length -gt 72MB
            ) {
                throw 'Evidence payload is empty or exceeds the Core upload limit.'
            }

            return Invoke-HarnessCoreRequest `
                -Project $Project `
                -Method 'POST' `
                -Route '/api/evidence/upload' `
                -Body ([ordered]@{
                    filename = ([string]$Body.filename).Substring(
                        0,
                        [Math]::Min(240, ([string]$Body.filename).Length)
                    )
                    mime = ([string]$Body.mime).Substring(
                        0,
                        [Math]::Min(120, ([string]$Body.mime).Length)
                    )
                    dataBase64 = $base64
                    note = [string]$Body.note
                    taskId = [string]$Body.taskId
                    derivedFrom = [string]$Body.derivedFrom
                    timestampSec = $Body.timestampSec
                    groupId = [string]$Body.groupId
                    derivativeType = [string]$Body.derivativeType
                }) `
                -TimeoutSec 120
        }

        'task-run' {
            return Invoke-HarnessCoreRequest `
                -Project $Project `
                -Method 'POST' `
                -Route '/api/task/run' `
                -Body @{
                    taskId = [string]$Body.taskId
                } `
                -TimeoutSec 10
        }

        'task-recover' {
            return Invoke-HarnessCoreRequest `
                -Project $Project `
                -Method 'POST' `
                -Route '/api/task/recover' `
                -Body @{
                    taskId = [string]$Body.taskId
                } `
                -TimeoutSec 20
        }

        'task-cancel' {
            return Invoke-HarnessCoreRequest `
                -Project $Project `
                -Method 'POST' `
                -Route '/api/task/cancel' `
                -Body @{} `
                -TimeoutSec 10
        }

        'review-fail' {
            $feedback = [string]$Body.feedback

            if ([string]::IsNullOrWhiteSpace($feedback)) {
                throw 'FAIL requires Owner feedback.'
            }

            return Invoke-HarnessCoreRequest `
                -Project $Project `
                -Method 'POST' `
                -Route '/api/review' `
                -Body ([ordered]@{
                    decision = 'FAIL'
                    feedback = $feedback.Trim()
                    evidence = Convert-CoreEvidenceReferences `
                        -Evidence $Body.evidence
                }) `
                -TimeoutSec 900
        }

        'review-pass' {
            return Invoke-HarnessCoreRequest `
                -Project $Project `
                -Method 'POST' `
                -Route '/api/review' `
                -Body @{
                    decision = 'PASS'
                    feedback = ''
                    evidence = @()
                } `
                -TimeoutSec 900
        }

        'skill-promote' {
            return Invoke-HarnessCoreRequest `
                -Project $Project `
                -Method 'POST' `
                -Route '/api/skills/promote' `
                -Body ([ordered]@{
                    taskId = [string]$Body.taskId
                    name = [string]$Body.name
                    instruction = [string]$Body.instruction
                }) `
                -TimeoutSec 120
        }

        'project-rediscover' {
            return Invoke-HarnessCoreRequest `
                -Project $Project `
                -Method 'POST' `
                -Route '/api/project/rediscover' `
                -Body @{} `
                -TimeoutSec 30
        }

        'core-restart' {
            return Invoke-HarnessCoreRequest `
                -Project $Project `
                -Method 'POST' `
                -Route '/api/core/restart' `
                -Body @{} `
                -TimeoutSec 10
        }

        default {
            throw 'Electronic action is not implemented.'
        }
    }
}

function Get-WorkspaceFingerprint {
    $headResult = Invoke-Git -Arguments @(
        'rev-parse',
        'HEAD'
    )

    if ($headResult.ExitCode -ne 0) {
        throw 'Unable to resolve HEAD.'
    }

    $head = $headResult.Output[-1].Trim()

    $diffResult = Invoke-Git -Arguments @(
        'diff',
        '--binary',
        'HEAD',
        '--'
    )

    if ($diffResult.ExitCode -ne 0) {
        throw 'Unable to generate workspace diff.'
    }

    $untrackedResult = Invoke-Git -Arguments @(
        'ls-files',
        '--others',
        '--exclude-standard',
        '--',
        'firmware/active/HINK213_CLOCK_22_BASE'
    )

    if ($untrackedResult.ExitCode -ne 0) {
        throw 'Unable to enumerate untracked firmware files.'
    }

    $builder = New-Object Text.StringBuilder

    [void]$builder.AppendLine("HEAD=$head")
    [void]$builder.AppendLine('=== TRACKED DIFF ===')

    foreach ($line in $diffResult.Output) {
        [void]$builder.AppendLine($line)
    }

    [void]$builder.AppendLine('=== UNTRACKED FIRMWARE ===')

    foreach ($relativePath in @($untrackedResult.Output | Sort-Object)) {
        if ([string]::IsNullOrWhiteSpace($relativePath)) {
            continue
        }

        $absolutePath = Join-Path $repoRoot $relativePath

        if (-not (Test-Path -LiteralPath $absolutePath -PathType Leaf)) {
            continue
        }

        $fileHash = Get-Sha256Hex -Path $absolutePath
        [void]$builder.AppendLine("$relativePath|$fileHash")
    }

    Get-TextSha256 -Text $builder.ToString()
}

function Get-RepoState {
    $branchResult = Invoke-Git -Arguments @(
        'branch',
        '--show-current'
    )

    $headResult = Invoke-Git -Arguments @(
        'rev-parse',
        'HEAD'
    )

    $statusResult = Invoke-Git -Arguments @(
        'status',
        '--porcelain=v1',
        '--untracked-files=normal'
    )

    $stagedResult = Invoke-Git -Arguments @(
        'diff',
        '--cached',
        '--name-only'
    )

    $dirtyResult = Invoke-Git -Arguments @(
        'diff',
        '--name-only'
    )

    $branch = if (
        $branchResult.ExitCode -eq 0 -and
        $branchResult.Output.Count -gt 0
    ) {
        $branchResult.Output[-1].Trim()
    }
    else {
        ''
    }

    $head = if (
        $headResult.ExitCode -eq 0 -and
        $headResult.Output.Count -gt 0
    ) {
        $headResult.Output[-1].Trim()
    }
    else {
        ''
    }

    $statusLines = @(
        $statusResult.Output |
        Where-Object { $_ -match '^.{2} ' }
    )

    $untracked = @(
        $statusLines |
        Where-Object { $_.StartsWith('?? ') }
    )

    $trackedStatus = @(
        $statusLines |
        Where-Object {
            $_ -and
            -not $_.StartsWith('?? ')
        }
    )

    [PSCustomObject]@{
        Branch = $branch
        Head = $head
        TrackedStatus = $trackedStatus
        DirtyTrackedFiles = @(
            $dirtyResult.Output |
            Where-Object {
                $_ -and
                $_ -notmatch '^(warning|hint):'
            }
        )
        StagedFiles = @(
            $stagedResult.Output |
            Where-Object {
                $_ -and
                $_ -notmatch '^(warning|hint):'
            }
        )
        Untracked = $untracked
    }
}

function Write-Utf8JsonFile {
    param(
        [Parameter(Mandatory=$true)]
        [string]$Path,

        [Parameter(Mandatory=$true)]
        $Value
    )

    $parent = Split-Path -Parent $Path

    if (-not (Test-Path -LiteralPath $parent -PathType Container)) {
        [void](New-Item -ItemType Directory -Path $parent -Force)
    }

    [IO.File]::WriteAllText(
        $Path,
        ($Value | ConvertTo-Json -Depth 12),
        (New-Object Text.UTF8Encoding($false))
    )
}

function Get-ServerLifecycleIdentity {
    [ordered]@{
        schema = 'eink-control-center-server-lock-v1'
        pid = [int]$PID
        processStartUtc = $serverStartUtc
        processStartTicks = [int64]$serverStartTicks
        executablePath = [Diagnostics.Process]::GetCurrentProcess().MainModule.FileName
        scriptPath = [IO.Path]::GetFullPath($PSCommandPath)
        repoRoot = [IO.Path]::GetFullPath($repoRoot)
        port = [int]$Port
        createdUtc = [DateTime]::UtcNow.ToString('o')
    }
}

function Write-ServerLifecycleLock {
    Write-Utf8JsonFile `
        -Path $runtimeLockPath `
        -Value (Get-ServerLifecycleIdentity)
}

function Remove-OwnServerLifecycleLock {
    $lock = Read-Utf8JsonFile -Path $runtimeLockPath

    if (
        $lock -and
        [int]$lock.pid -eq [int]$PID -and
        [int64]$lock.processStartTicks -eq [int64]$serverStartTicks -and
        [string]$lock.scriptPath -eq [IO.Path]::GetFullPath($PSCommandPath)
    ) {
        Remove-Item -LiteralPath $runtimeLockPath -Force -ErrorAction SilentlyContinue
    }
}

function Test-ServerLifecycleLockProcess {
    param($Lock)

    if (
        -not $Lock -or
        [string]$Lock.schema -ne 'eink-control-center-server-lock-v1' -or
        [int]$Lock.port -ne [int]$Port -or
        [string]$Lock.scriptPath -ne [IO.Path]::GetFullPath($PSCommandPath)
    ) {
        return $false
    }

    try {
        $process = Get-Process -Id ([int]$Lock.pid) -ErrorAction Stop
        return (
            $process.StartTime.ToUniversalTime().Ticks -eq
                [int64]$Lock.processStartTicks -and
            [IO.Path]::GetFullPath($process.Path) -eq
                [IO.Path]::GetFullPath([string]$Lock.executablePath)
        )
    }
    catch {
        return $false
    }
}

function Start-ControlCenterReplacement {
    $restartStdout = Join-Path $runtimeRoot ("restart-$PID.stdout.log")
    $restartStderr = Join-Path $runtimeRoot ("restart-$PID.stderr.log")
    Remove-Item -LiteralPath $restartStdout -Force -ErrorAction SilentlyContinue
    Remove-Item -LiteralPath $restartStderr -Force -ErrorAction SilentlyContinue

    $arguments = @(
        '-NoProfile',
        '-ExecutionPolicy',
        'Bypass',
        '-File',
        "`"$launcherPath`"",
        '-Port',
        [string]$Port,
        '-NoBrowser',
        '-RestartFromPid',
        [string]$PID,
        '-RestartFromStartTicks',
        [string]$serverStartTicks,
        '-RestartFromExecutablePath',
        "`"$([Diagnostics.Process]::GetCurrentProcess().MainModule.FileName)`""
    )

    Start-Process `
        -FilePath 'powershell.exe' `
        -ArgumentList $arguments `
        -RedirectStandardOutput $restartStdout `
        -RedirectStandardError $restartStderr `
        -WindowStyle Hidden | Out-Null
}

function Get-ApprovedFinalizeFiles {
    $files = @(
        $einkRegistryProject.finalize.approvedFiles |
        ForEach-Object {
            ([string]$_).Replace('\', '/').Trim()
        } |
        Where-Object { $_ } |
        Select-Object -Unique
    )

    if ($files.Count -eq 0) {
        throw 'Finalize approved file list is empty.'
    }

    $rootPrefix = [IO.Path]::GetFullPath($repoRoot).TrimEnd('\') + '\'

    foreach ($relativePath in $files) {
        if (
            [IO.Path]::IsPathRooted($relativePath) -or
            $relativePath -match '(^|/)\.\.(/|$)' -or
            $relativePath -eq '.'
        ) {
            throw "Unsafe finalize path: $relativePath"
        }

        $fullPath = [IO.Path]::GetFullPath(
            (Join-Path $repoRoot $relativePath)
        )

        if (-not $fullPath.StartsWith(
            $rootPrefix,
            [StringComparison]::OrdinalIgnoreCase
        )) {
            throw "Finalize path escaped workspace: $relativePath"
        }
    }

    @($files | Sort-Object)
}

function Get-ApprovedFilesFingerprint {
    $builder = New-Object Text.StringBuilder

    foreach ($relativePath in Get-ApprovedFinalizeFiles) {
        $fullPath = Join-Path $repoRoot $relativePath
        $sha = if (Test-Path -LiteralPath $fullPath -PathType Leaf) {
            Get-Sha256Hex -Path $fullPath
        }
        else {
            'MISSING'
        }
        [void]$builder.AppendLine("$relativePath|$sha")
    }

    Get-TextSha256 -Text $builder.ToString()
}

function Get-BurnVerificationState {
    if ($script:BurnVerificationOverride) {
        return $script:BurnVerificationOverride
    }

    Read-Utf8JsonFile -Path $burnVerificationStatePath
}

function Get-OwnerFinalizeState {
    Read-Utf8JsonFile -Path $ownerFinalizeStatePath
}

function Set-BurnVerificationState {
    param(
        [Parameter(Mandatory=$true)]
        $Candidate,

        [bool]$Simulated = $false
    )

    if ($Simulated -and -not $AcceptanceMode) {
        throw 'Simulated burn verification is forbidden in production mode.'
    }

    $repo = Get-RepoState
    $record = [ordered]@{
        schema = 'eink-control-center-burn-verification-v1'
        taskId = [string]$einkRegistryProject.finalize.taskId
        status = 'SPI_BURN_VERIFIED'
        simulated = [bool]$Simulated
        verifiedUtc = [DateTime]::UtcNow.ToString('o')
        branch = [string]$repo.Branch
        head = [string]$repo.Head
        workspaceFingerprint = Get-WorkspaceFingerprint
        approvedFilesFingerprint = Get-ApprovedFilesFingerprint
        artifactPath = [string]$Candidate.Path
        artifactSha256 = ([string]$Candidate.Sha256).ToUpperInvariant()
        prepareAttemptId = [string]$Candidate.AttemptId
    }

    Write-Utf8JsonFile -Path $burnVerificationStatePath -Value $record
    $record
}

function Get-ValidBurnVerification {
    param(
        [Parameter(Mandatory=$true)]
        $RepoState
    )

    $record = Get-BurnVerificationState

    if (
        -not $record -or
        [string]$record.status -ne 'SPI_BURN_VERIFIED' -or
        ([bool]$record.simulated -and -not $AcceptanceMode) -or
        [string]$record.taskId -ne [string]$einkRegistryProject.finalize.taskId -or
        [string]$record.branch -ne [string]$RepoState.Branch -or
        [string]$record.head -ne [string]$RepoState.Head
    ) {
        return $null
    }

    $artifactPath = [string]$record.artifactPath

    if (-not (Test-Path -LiteralPath $artifactPath -PathType Leaf)) {
        return $null
    }

    $actualSha = Get-Sha256Hex -Path $artifactPath

    if (
        $actualSha -ne (
            [string]$record.artifactSha256
        ).ToUpperInvariant() -or
        (Get-WorkspaceFingerprint) -ne (
            [string]$record.workspaceFingerprint
        ).ToUpperInvariant() -or
        (Get-ApprovedFilesFingerprint) -ne (
            [string]$record.approvedFilesFingerprint
        ).ToUpperInvariant()
    ) {
        return $null
    }

    $record
}

function Initialize-AcceptanceBurnFixture {
    if (-not $AcceptanceMode) {
        return
    }

    $fixture = Read-Utf8JsonFile -Path $AcceptanceFixturePath

    if (
        -not $fixture -or
        [string]$fixture.schema -ne 'eink-control-center-post-burn-fixture-v1' -or
        -not [bool]$fixture.simulated -or
        -not [bool]$fixture.autoBindCurrentWorkspace
    ) {
        throw 'Invalid isolated post-burn acceptance fixture.'
    }

    $artifactPath = [IO.Path]::GetFullPath([string]$fixture.artifactPath)
    $workspacePrefix = [IO.Path]::GetFullPath($repoRoot).TrimEnd('\') + '\'

    if (-not $artifactPath.StartsWith(
        $workspacePrefix,
        [StringComparison]::OrdinalIgnoreCase
    )) {
        throw 'Acceptance artifact must stay inside the isolated workspace.'
    }

    if (-not (Test-Path -LiteralPath $artifactPath -PathType Leaf)) {
        throw 'Acceptance artifact is missing.'
    }

    $candidate = [PSCustomObject]@{
        Path = $artifactPath
        Sha256 = Get-Sha256Hex -Path $artifactPath
        AttemptId = 'SIMULATED_POST_BURN_FIXTURE'
    }

    $script:BurnVerificationOverride = Set-BurnVerificationState `
        -Candidate $candidate `
        -Simulated $true

    Set-LastLog `
        -Action 'ACCEPTANCE_FIXTURE' `
        -Result 'SPI_BURN_VERIFIED' `
        -Lines @(
            'SIMULATED POST-BURN FIXTURE ACTIVE.',
            'No hardware command was executed.',
            'Production port 5175 rejects this mode.'
        )
}

function Save-OwnerEvidence {
    param(
        [Parameter(Mandatory=$true)]
        [string]$Decision,

        [Parameter(Mandatory=$true)]
        [string]$AttemptId,

        $Body
    )

    $evidenceDir = Join-Path $ownerFinalizeRoot (
        'evidence\' + $AttemptId
    )
    [void](New-Item -ItemType Directory -Path $evidenceDir -Force)

    $items = @($Body.evidence)

    if ($items.Count -gt 8) {
        throw 'Owner evidence exceeds the 8-file limit.'
    }

    $saved = @()
    $totalBytes = 0L

    for ($i = 0; $i -lt $items.Count; $i++) {
        $item = $items[$i]
        $base64 = [string]$item.dataBase64

        if ([string]::IsNullOrWhiteSpace($base64)) {
            continue
        }

        try {
            $bytes = [Convert]::FromBase64String($base64)
        }
        catch {
            throw 'Owner evidence contains invalid base64.'
        }

        $totalBytes += $bytes.Length

        if ($bytes.Length -gt 10MB -or $totalBytes -gt 25MB) {
            throw 'Owner evidence exceeds the safe size limit.'
        }

        $originalName = [IO.Path]::GetFileName([string]$item.filename)

        if ([string]::IsNullOrWhiteSpace($originalName)) {
            $originalName = "evidence-$i.bin"
        }

        $safeName = $originalName -replace '[^A-Za-z0-9._-]', '_'
        $storedName = ('{0:D2}-{1}' -f ($i + 1), $safeName)
        $storedPath = Join-Path $evidenceDir $storedName
        [IO.File]::WriteAllBytes($storedPath, $bytes)

        $saved += [ordered]@{
            filename = $originalName
            mime = [string]$item.mime
            size = [int64]$bytes.Length
            sha256 = Get-Sha256Hex -Path $storedPath
            storedPath = $storedPath
        }
    }

    $feedback = ([string]$Body.feedback).Trim()

    if ([string]::IsNullOrWhiteSpace($feedback) -and $saved.Count -eq 0) {
        throw "$Decision requires Owner feedback or evidence."
    }

    [ordered]@{
        feedback = $feedback
        files = $saved
        evidenceDir = $evidenceDir
    }
}

function New-ValidatedStateBackup {
    param(
        [Parameter(Mandatory=$true)]
        [string]$AttemptId,

        [Parameter(Mandatory=$true)]
        $OwnerEvidence
    )

    $timestamp = Get-Date -Format 'yyyyMMdd_HHmmss'
    $backupDir = Join-Path $ownerFinalizeRoot (
        "validated\${timestamp}_$AttemptId"
    )
    $filesRoot = Join-Path $backupDir 'files'
    [void](New-Item -ItemType Directory -Path $filesRoot -Force)

    $manifestFiles = @()

    foreach ($relativePath in Get-ApprovedFinalizeFiles) {
        $sourcePath = Join-Path $repoRoot $relativePath

        if (-not (Test-Path -LiteralPath $sourcePath -PathType Leaf)) {
            throw "Approved task file is missing: $relativePath"
        }

        $destinationPath = Join-Path $filesRoot $relativePath
        $destinationParent = Split-Path -Parent $destinationPath
        [void](New-Item -ItemType Directory -Path $destinationParent -Force)
        [IO.File]::Copy($sourcePath, $destinationPath, $true)

        $manifestFiles += [ordered]@{
            path = $relativePath
            size = [int64](Get-Item -LiteralPath $sourcePath).Length
            sha256 = Get-Sha256Hex -Path $sourcePath
        }
    }

    $repo = Get-RepoState
    $manifest = [ordered]@{
        schema = 'eink-control-center-validated-backup-v1'
        taskId = [string]$einkRegistryProject.finalize.taskId
        createdUtc = [DateTime]::UtcNow.ToString('o')
        branch = [string]$repo.Branch
        headBeforeFinalize = [string]$repo.Head
        workspaceFingerprint = Get-WorkspaceFingerprint
        ownerEvidence = $OwnerEvidence
        approvedFiles = $manifestFiles
    }

    Write-Utf8JsonFile `
        -Path (Join-Path $backupDir 'validated-state.json') `
        -Value $manifest

    $backupDir
}

function Open-FinalizePullRequest {
    param(
        [Parameter(Mandatory=$true)]
        [string]$Branch
    )

    if ($AcceptanceMode) {
        return [PSCustomObject]@{
            Url = 'https://example.invalid/eink-harness-acceptance/pull/1'
            State = 'OPEN'
        }
    }

    $title = 'EINK Harness Control Center v0.3 Finalize'
    $body = (
        'Owner PHYSICAL PASS verified after SPI_BURN_VERIFIED. ' +
        'Validated state was backed up and only approved task files were staged. ' +
        'This PR is intentionally left open for Owner review; no auto-merge.'
    )
    $result = Invoke-NativeText `
        -FilePath 'gh' `
        -Arguments @(
            'pr', 'create',
            '--base', [string]$einkRegistryProject.finalize.baseBranch,
            '--head', $Branch,
            '--title', $title,
            '--body', $body
        )

    if ($result.ExitCode -ne 0) {
        throw ('PR creation failed: ' + ($result.Output -join ' '))
    }

    $url = @(
        $result.Output |
        Where-Object { $_ -match '^https://github\.com/.+/pull/\d+$' }
    ) | Select-Object -Last 1

    if ([string]::IsNullOrWhiteSpace([string]$url)) {
        throw 'PR creation did not return a GitHub PR URL.'
    }

    [PSCustomObject]@{
        Url = [string]$url
        State = 'OPEN'
    }
}

function Invoke-PhysicalFailAction {
    param($Body)

    if ($script:Busy) {
        return Get-ControlStatus
    }

    $repo = Get-RepoState
    $burn = Get-ValidBurnVerification -RepoState $repo

    if (-not $burn) {
        Set-LastLog -Action 'PHYSICAL_FAIL' -Result 'BLOCKED' -Lines @(
            'BLOCKED: SPI_BURN_VERIFIED_REQUIRED'
        )
        return Get-ControlStatus
    }

    $attemptId = [Guid]::NewGuid().ToString('N')

    try {
        $ownerEvidence = Save-OwnerEvidence `
            -Decision 'PHYSICAL FAIL' `
            -AttemptId $attemptId `
            -Body $Body

        $record = [ordered]@{
            schema = 'eink-control-center-owner-finalize-v1'
            taskId = [string]$einkRegistryProject.finalize.taskId
            decision = 'PHYSICAL_FAIL'
            resolved = $false
            state = 'UNRESOLVED'
            recordedUtc = [DateTime]::UtcNow.ToString('o')
            branch = [string]$repo.Branch
            head = [string]$repo.Head
            burnVerification = $burn
            feedback = [string]$ownerEvidence.feedback
            evidence = @($ownerEvidence.files)
            commitSha = ''
            prUrl = ''
            prState = ''
        }

        Write-Utf8JsonFile -Path $ownerFinalizeStatePath -Value $record
        Set-LastLog -Action 'PHYSICAL_FAIL' -Result 'PHYSICAL_FAIL' -Lines @(
            'OWNER PHYSICAL FAIL RECORDED.',
            'Task remains unresolved.',
            'No stage, commit, push, PR, burn, or merge was performed.'
        )
    }
    catch {
        Set-LastLog -Action 'PHYSICAL_FAIL' -Result 'BLOCKED' -Lines @(
            "EXCEPTION: $($_.Exception.Message)"
        )
    }

    Get-ControlStatus
}

function Invoke-PhysicalPassAction {
    param($Body)

    if ($script:Busy) {
        return Get-ControlStatus
    }

    $repoBefore = Get-RepoState
    $burn = Get-ValidBurnVerification -RepoState $repoBefore

    if (-not $burn) {
        Set-LastLog -Action 'PHYSICAL_PASS' -Result 'BLOCKED' -Lines @(
            'BLOCKED: SPI_BURN_VERIFIED_REQUIRED'
        )
        return Get-ControlStatus
    }

    if (@($repoBefore.StagedFiles).Count -gt 0) {
        Set-LastLog -Action 'PHYSICAL_PASS' -Result 'BLOCKED' -Lines @(
            'BLOCKED: PREEXISTING_STAGED_FILES'
        )
        return Get-ControlStatus
    }

    if ([string]$repoBefore.Branch -eq [string]$einkRegistryProject.finalize.baseBranch) {
        Set-LastLog -Action 'PHYSICAL_PASS' -Result 'BLOCKED' -Lines @(
            'BLOCKED: FINALIZE_BRANCH_MUST_NOT_BE_BASE_BRANCH'
        )
        return Get-ControlStatus
    }

    $approved = @(Get-ApprovedFinalizeFiles)
    $outsideTracked = @(
        $repoBefore.DirtyTrackedFiles |
        ForEach-Object { ([string]$_).Replace('\', '/') } |
        Where-Object { $approved -notcontains $_ }
    )

    if ($outsideTracked.Count -gt 0) {
        Set-LastLog -Action 'PHYSICAL_PASS' -Result 'BLOCKED' -Lines @(
            'BLOCKED: TRACKED_CHANGES_OUTSIDE_APPROVED_SCOPE',
            ($outsideTracked -join ', ')
        )
        return Get-ControlStatus
    }

    $script:Busy = $true
    $attemptId = [Guid]::NewGuid().ToString('N')

    try {
        $ownerEvidence = Save-OwnerEvidence `
            -Decision 'PHYSICAL PASS' `
            -AttemptId $attemptId `
            -Body $Body

        $backupPath = New-ValidatedStateBackup `
            -AttemptId $attemptId `
            -OwnerEvidence $ownerEvidence

        $addResult = Invoke-Git -Arguments (
            @('add', '--') + $approved
        )

        if ($addResult.ExitCode -ne 0) {
            throw ('Exact staging failed: ' + ($addResult.Output -join ' '))
        }

        $staged = @((Get-RepoState).StagedFiles | Sort-Object)
        $outsideStaged = @($staged | Where-Object { $approved -notcontains $_ })

        if ($staged.Count -eq 0 -or $outsideStaged.Count -gt 0) {
            throw 'Exact staging safety verification failed.'
        }

        $commitResult = Invoke-Git -Arguments @(
            'commit',
            '-m',
            'feat: finalize EINK Harness Control Center v0.3'
        )

        if ($commitResult.ExitCode -ne 0) {
            throw ('Commit failed: ' + ($commitResult.Output -join ' '))
        }

        $repoAfterCommit = Get-RepoState
        $commitScopeResult = Invoke-Git -Arguments @(
            'diff-tree',
            '--no-commit-id',
            '--name-only',
            '-r',
            'HEAD'
        )
        $commitFiles = @(
            $commitScopeResult.Output |
            Where-Object {
                $_ -and
                $_ -notmatch '^(warning|hint):'
            } |
            Sort-Object
        )

        if (
            $commitScopeResult.ExitCode -ne 0 -or
            @($commitFiles | Where-Object { $approved -notcontains $_ }).Count -gt 0
        ) {
            throw 'Committed file scope escaped the approved task list; push blocked.'
        }

        $pushResult = Invoke-Git -Arguments @(
            'push',
            '-u',
            'origin',
            [string]$repoAfterCommit.Branch
        )

        if ($pushResult.ExitCode -ne 0) {
            throw ('Push failed: ' + ($pushResult.Output -join ' '))
        }

        $pr = Open-FinalizePullRequest -Branch $repoAfterCommit.Branch
        $record = [ordered]@{
            schema = 'eink-control-center-owner-finalize-v1'
            taskId = [string]$einkRegistryProject.finalize.taskId
            decision = 'PHYSICAL_PASS'
            resolved = $true
            state = 'OPEN_PR'
            recordedUtc = [DateTime]::UtcNow.ToString('o')
            branch = [string]$repoAfterCommit.Branch
            headBeforeFinalize = [string]$repoBefore.Head
            commitSha = [string]$repoAfterCommit.Head
            prUrl = [string]$pr.Url
            prState = [string]$pr.State
            backupPath = $backupPath
            burnVerification = $burn
            feedback = [string]$ownerEvidence.feedback
            evidence = @($ownerEvidence.files)
            approvedFiles = $approved
            autoMerge = $false
        }

        Write-Utf8JsonFile -Path $ownerFinalizeStatePath -Value $record
        Set-LastLog -Action 'PHYSICAL_PASS' -Result 'OPEN_PR' -Lines @(
            'OWNER PHYSICAL PASS RECORDED.',
            "BACKUP: $backupPath",
            "COMMIT: $($repoAfterCommit.Head)",
            "PR: $($pr.Url)",
            '[OPEN PR]',
            'AUTO_MERGE: DISABLED'
        )
    }
    catch {
        Set-LastLog -Action 'PHYSICAL_PASS' -Result 'BLOCKED' -Lines @(
            "EXCEPTION: $($_.Exception.Message)",
            'AUTO_MERGE: DISABLED'
        )
    }
    finally {
        $script:Busy = $false
    }

    Get-ControlStatus
}

function Get-PrepareTrustState {
    if ($script:PrepareTrustFailureOverride) {
        return $script:PrepareTrustFailureOverride
    }

    Read-Utf8JsonFile -Path $prepareTrustStatePath
}

function Set-PrepareTrustState {
    param(
        [Parameter(Mandatory=$true)]
        [string]$Status,

        [Parameter(Mandatory=$true)]
        [string]$AttemptId,

        [hashtable]$Data = @{}
    )

    if (-not (Test-Path -LiteralPath $prepareEvidenceRoot -PathType Container)) {
        [void](
            New-Item `
                -ItemType Directory `
                -Path $prepareEvidenceRoot `
                -Force
        )
    }

    $record = [ordered]@{
        schema = 'eink-control-center-prepare-trust-v1'
        attemptId = $AttemptId
        status = $Status
        startedUtc = [DateTime]::UtcNow.ToString('o')
        completedUtc = if ($Status -eq 'RUNNING') {
            $null
        }
        else {
            [DateTime]::UtcNow.ToString('o')
        }
        branch = ''
        head = ''
        workspaceFingerprint = ''
        taskId = ''
        approvedFiles = @()
        approvedFilesFingerprint = ''
        manifestPath = ''
        lockPath = ''
        evidenceDir = ''
        packedSha256 = ''
        reason = ''
        durable = $false
    }

    $previous = Get-PrepareTrustState

    if (
        $previous -and
        [string]$previous.attemptId -eq $AttemptId
    ) {
        foreach ($property in $previous.PSObject.Properties) {
            if ($record.Contains($property.Name)) {
                $record[$property.Name] = $property.Value
            }
        }

        $record['status'] = $Status

        if ($Status -ne 'RUNNING') {
            $record['completedUtc'] = [DateTime]::UtcNow.ToString('o')
        }
    }

    foreach ($key in $Data.Keys) {
        if ($record.Contains($key)) {
            $record[$key] = $Data[$key]
        }
    }

    $record['durable'] = $true

    try {
        [IO.File]::WriteAllText(
            $prepareTrustStatePath,
            ($record | ConvertTo-Json -Depth 8),
            [Text.UTF8Encoding]::new($false)
        )

        $script:PrepareTrustFailureOverride = $null
    }
    catch {
        $record['status'] = 'FAIL'
        $record['reason'] = 'PREPARE_TRUST_STATE_WRITE_FAILED_BURN_DISABLED'
        $record['durable'] = $false
        $record['completedUtc'] = [DateTime]::UtcNow.ToString('o')
        $script:PrepareTrustFailureOverride = [PSCustomObject]$record
    }

    return [PSCustomObject]$record
}

function Initialize-PrepareTrustState {
    $trust = Get-PrepareTrustState

    if ($trust -and [string]$trust.status -eq 'RUNNING') {
        [void](
            Set-PrepareTrustState `
                -Status 'TIMEOUT' `
                -AttemptId ([string]$trust.attemptId) `
                -Data @{
                    reason = 'PREVIOUS_HUB_ENDED_BEFORE_PREPARE_COMPLETED'
                }
        )

        Set-LastLog `
            -Action 'PREPARE_TEST' `
            -Result 'BLOCKED' `
            -Lines @(
                'LATEST_PREPARE: TIMEOUT',
                'Burn remains disabled until a new prepare-test PASS.'
            )

        return
    }

    if (-not $trust) {
        $legacyDirs = @(
            Get-ChildItem `
                -LiteralPath $prepareEvidenceRoot `
                -Directory `
                -ErrorAction SilentlyContinue
        )

        if ($legacyDirs.Count -gt 0) {
            [void](
                Set-PrepareTrustState `
                    -Status 'STALE_REJECTED' `
                    -AttemptId ('legacy-' + [Guid]::NewGuid().ToString('N')) `
                    -Data @{
                        reason = 'LATEST_PREPARE_TRUST_STATE_MISSING_NO_FALLBACK'
                    }
            )

            Set-LastLog `
                -Action 'PREPARE_TEST' `
                -Result 'BLOCKED' `
                -Lines @(
                    'LATEST_PREPARE: STALE_REJECTED',
                    'Older prepare artifacts are not eligible for burn.',
                    'Run a new prepare-test and require PASS.'
                )
        }
    }
}

function Set-PrepareAttemptFailure {
    param(
        [Parameter(Mandatory=$true)]
        [string]$AttemptId,

        [Parameter(Mandatory=$true)]
        [string]$Reason
    )

    [void](
        Set-PrepareTrustState `
            -Status 'FAIL' `
            -AttemptId $AttemptId `
            -Data @{
                reason = $Reason
            }
    )
}

function Get-LatestPrepareCandidate {
    param(
        [Parameter(Mandatory=$true)]
        $RepoState
    )

    if ($script:AcceptancePrepareCandidate) { return $script:AcceptancePrepareCandidate }
    $trust = Get-PrepareTrustState

    if (
        -not $trust -or
        [string]$trust.status -ne 'PASS'
    ) {
        return $null
    }

    $manifestPath = [string]$trust.manifestPath
    $lockPath = [string]$trust.lockPath

    if (
        [string]::IsNullOrWhiteSpace($manifestPath) -or
        [string]::IsNullOrWhiteSpace($lockPath) -or
        -not (Test-Path -LiteralPath $manifestPath -PathType Leaf) -or
        -not (Test-Path -LiteralPath $lockPath -PathType Leaf)
    ) {
        return $null
    }

    $evidenceParent = Split-Path -Parent $manifestPath
    $evidenceDir = [IO.Path]::GetFullPath($evidenceParent)
    $trustedEvidenceDir = [IO.Path]::GetFullPath(
        [string]$trust.evidenceDir
    )
    $fullLockPath = [IO.Path]::GetFullPath($lockPath)
    $expectedLockPath = Join-Path $evidenceDir 'control-center-lock.json'
    $fullExpectedLockPath = [IO.Path]::GetFullPath($expectedLockPath)

    if (
        -not $evidenceDir.Equals(
            $trustedEvidenceDir,
            [StringComparison]::OrdinalIgnoreCase
        ) -or
        -not $fullLockPath.Equals(
            $fullExpectedLockPath,
            [StringComparison]::OrdinalIgnoreCase
        )
    ) {
        return $null
    }

    $manifest = Read-Utf8JsonFile -Path $manifestPath
    $lock = Read-Utf8JsonFile -Path $lockPath
    $currentApprovedFiles = @(Get-ApprovedFinalizeFiles)
    $currentApprovedFilesFingerprint = Get-ApprovedFilesFingerprint
    $trustedApprovedFiles = @(
        $trust.approvedFiles |
        ForEach-Object { ([string]$_).Replace('\', '/').Trim() } |
        Sort-Object
    )
    $lockedApprovedFiles = @(
        $lock.approvedFiles |
        ForEach-Object { ([string]$_).Replace('\', '/').Trim() } |
        Sort-Object
    )

    if (
        -not $manifest -or
        -not $lock -or
        [string]$manifest.nextState -ne 'OWNER_BURN_CONFIRMATION_REQUIRED' -or
        [string]$trust.taskId -ne
            [string]$einkRegistryProject.finalize.taskId -or
        [string]$lock.taskId -ne
            [string]$einkRegistryProject.finalize.taskId -or
        ($trustedApprovedFiles -join "`n") -ne
            ($currentApprovedFiles -join "`n") -or
        ($lockedApprovedFiles -join "`n") -ne
            ($currentApprovedFiles -join "`n") -or
        ([string]$trust.approvedFilesFingerprint).ToUpperInvariant() -ne
            $currentApprovedFilesFingerprint -or
        ([string]$lock.approvedFilesFingerprint).ToUpperInvariant() -ne
            $currentApprovedFilesFingerprint
    ) {
        return $null
    }

    if (
        [string]$trust.branch -ne [string]$RepoState.Branch -or
        [string]$trust.head -ne [string]$RepoState.Head -or
        [string]$lock.branch -ne [string]$RepoState.Branch -or
        [string]$lock.head -ne [string]$RepoState.Head
    ) {
        return $null
    }

    $packedPath = [string]$manifest.packed.path

    if (-not (Test-Path -LiteralPath $packedPath -PathType Leaf)) {
        return $null
    }

    $packedFile = Get-Item -LiteralPath $packedPath

    if ($packedFile.Length -ne [int64]$profile.artifactPolicy.packedSpiBytes) {
        return $null
    }

    $actualSha = Get-Sha256Hex -Path $packedPath
    $expectedSha = ([string]$manifest.packed.sha256).ToUpperInvariant()

    if (
        $actualSha -ne $expectedSha -or
        ([string]$lock.packedSha256).ToUpperInvariant() -ne $actualSha -or
        ([string]$trust.packedSha256).ToUpperInvariant() -ne $actualSha
    ) {
        return $null
    }

    $currentFingerprint = Get-WorkspaceFingerprint

    if (
        ([string]$lock.workspaceFingerprint).ToUpperInvariant() -ne $currentFingerprint -or
        ([string]$trust.workspaceFingerprint).ToUpperInvariant() -ne $currentFingerprint
    ) {
        return $null
    }

    return [PSCustomObject]@{
        Path = $packedPath
        Size = [int64]$packedFile.Length
        Sha256 = $actualSha
        Manifest = $manifestPath
        EvidenceDir = $evidenceDir
        WorkspaceFingerprint = $currentFingerprint
        AttemptId = [string]$trust.attemptId
        TaskId = [string]$einkRegistryProject.finalize.taskId
        BuildTimestamp = if (-not [string]::IsNullOrWhiteSpace([string]$manifest.createdUtc)) { [string]$manifest.createdUtc } else { [string]$trust.completedUtc }
    }
}

function Get-FriendlyTaskTitle {
    param([Parameter(Mandatory=$true)][string]$TaskId)
    $text = $TaskId -replace '^EINK-', '' -replace '-\d+$', '' -replace '-', ' '
    $culture = [Globalization.CultureInfo]::GetCultureInfo('en-US')
    $culture.TextInfo.ToTitleCase($text.ToLowerInvariant())
}

function Initialize-EinkBrainStore {
    [void](New-Item -ItemType Directory -Path $brainRoot -Force)
}

function Read-EinkBrainCurrentTask {
    if (-not (Test-Path -LiteralPath $brainCurrentTaskPath -PathType Leaf)) {
        return $null
    }

    Read-Utf8JsonFile -Path $brainCurrentTaskPath
}

function Append-EinkBrainHistory {
    param(
        [Parameter(Mandatory=$true)]
        $Record
    )

    Initialize-EinkBrainStore

    $line = (
        $Record |
        ConvertTo-Json -Depth 8 -Compress
    ) + [Environment]::NewLine

    [IO.File]::AppendAllText(
        $brainHistoryPath,
        $line,
        [Text.UTF8Encoding]::new($false)
    )
}

function Get-EinkBrainHistory {
    if (-not (Test-Path -LiteralPath $brainHistoryPath -PathType Leaf)) {
        return @()
    }

    $records = @()

    foreach ($line in @(
        [IO.File]::ReadAllLines(
            $brainHistoryPath,
            [Text.Encoding]::UTF8
        )
    )) {
        if ([string]::IsNullOrWhiteSpace($line)) {
            continue
        }

        try {
            $records += ($line | ConvertFrom-Json)
        }
        catch {
            throw 'EINK Brain history contains invalid JSONL.'
        }
    }

    $seen = @{}
    $recent = @()

    for ($i = $records.Count - 1; $i -ge 0; $i--) {
        $record = $records[$i]
        $taskId = [string]$record.taskId

        if ([string]::IsNullOrWhiteSpace($taskId)) {
            continue
        }

        if (-not $seen.ContainsKey($taskId)) {
            $seen[$taskId] = $true
            $recent += $record
        }
    }

    $recent
}

function Get-EinkBrainHistoryCount {
    if (-not (Test-Path -LiteralPath $brainHistoryPath -PathType Leaf)) {
        return 0
    }

    @(
        [IO.File]::ReadAllLines(
            $brainHistoryPath,
            [Text.Encoding]::UTF8
        ) |
        Where-Object { -not [string]::IsNullOrWhiteSpace($_) }
    ).Count
}

function Get-EinkBrainStatus {
    Initialize-EinkBrainStore

    $currentTask = Read-EinkBrainCurrentTask
    $recentTasks = @(Get-EinkBrainHistory | Select-Object -First 20)

    [ordered]@{
        version = '0.4'
        persistent = $true
        executionEnabled = $false
        mutationPolicy = 'MEMORY_ONLY'
        storeRoot = $brainRoot
        currentTask = $currentTask
        recentTasks = $recentTasks
        historyCount = Get-EinkBrainHistoryCount
    }
}

function Invoke-EinkBrainCreateAction {
    param(
        [Parameter(Mandatory=$true)]
        $Body
    )

    $request = ([string]$Body.request).Trim()

    if ([string]::IsNullOrWhiteSpace($request)) {
        throw 'Brain task request is empty.'
    }

    if ($request.Length -gt 12000) {
        throw 'Brain task request exceeds 12000 characters.'
    }

    Initialize-EinkBrainStore

    $repo = Get-RepoState
    $now = [DateTime]::UtcNow.ToString('o')
    $taskId = 'EINK-BRAIN-' +
        (Get-Date -Format 'yyyyMMdd-HHmmss') +
        '-' +
        ([Guid]::NewGuid().ToString('N').Substring(0,6)).ToUpperInvariant()

    $record = [ordered]@{
        schema = 'eink-brain-task-v1'
        taskId = $taskId
        request = $request
        event = 'CREATE'
        status = 'READY'
        createdUtc = $now
        updatedUtc = $now
        resumeCount = 0
        branchAtCreate = [string]$repo.Branch
        headAtCreate = [string]$repo.Head
    }

    Write-Utf8JsonFile `
        -Path $brainCurrentTaskPath `
        -Value $record

    Append-EinkBrainHistory -Record $record

    Set-LastLog `
        -Action 'BRAIN_CREATE' `
        -Result 'PASS' `
        -Lines @(
            'EINK BRAIN TASK CREATED.',
            "TASK_ID: $taskId",
            'STATE: READY',
            'EXECUTION: DISABLED',
            'NO BUILD / BURN / GIT MUTATION PERFORMED.'
        )

    Get-ControlStatus
}

function Invoke-EinkBrainResumeAction {
    param(
        [Parameter(Mandatory=$true)]
        $Body
    )

    $taskId = ([string]$Body.taskId).Trim()

    if ([string]::IsNullOrWhiteSpace($taskId)) {
        throw 'Brain resume taskId is empty.'
    }

    $selected = @(
        Get-EinkBrainHistory |
        Where-Object { [string]$_.taskId -eq $taskId } |
        Select-Object -First 1
    )

    if ($selected.Count -ne 1) {
        throw 'Brain task was not found in persistent history.'
    }

    $source = $selected[0]
    $repo = Get-RepoState
    $now = [DateTime]::UtcNow.ToString('o')

    $record = [ordered]@{
        schema = 'eink-brain-task-v1'
        taskId = [string]$source.taskId
        request = [string]$source.request
        event = 'RESUME'
        status = 'READY'
        createdUtc = [string]$source.createdUtc
        updatedUtc = $now
        resumeCount = ([int]$source.resumeCount + 1)
        branchAtCreate = [string]$source.branchAtCreate
        headAtCreate = [string]$source.headAtCreate
        resumedOnBranch = [string]$repo.Branch
        resumedOnHead = [string]$repo.Head
    }

    Write-Utf8JsonFile `
        -Path $brainCurrentTaskPath `
        -Value $record

    Append-EinkBrainHistory -Record $record

    Set-LastLog `
        -Action 'BRAIN_RESUME' `
        -Result 'PASS' `
        -Lines @(
            'EINK BRAIN TASK RESUMED.',
            "TASK_ID: $taskId",
            "RESUME_COUNT: $($record.resumeCount)",
            'STATE: READY',
            'EXECUTION: DISABLED',
            'NO BUILD / BURN / GIT MUTATION PERFORMED.'
        )

    Get-ControlStatus
}
function Get-ControlStatus {

    $burnRuntime = Sync-BurnRuntimeState
    $repo = Get-RepoState
    $trust = Get-PrepareTrustState
    $candidate = Get-LatestPrepareCandidate -RepoState $repo
    $burnVerification = Get-ValidBurnVerification -RepoState $repo
    $ownerFinalize = Get-OwnerFinalizeState
    $ownerFinalizeCurrent = if (
        $ownerFinalize -and
        [string]$ownerFinalize.taskId -eq [string]$einkRegistryProject.finalize.taskId -and
        [string]$ownerFinalize.branch -eq [string]$repo.Branch -and
        (
            (
                [string]$ownerFinalize.state -eq 'OPEN_PR' -and
                [string]$ownerFinalize.commitSha -eq [string]$repo.Head
            ) -or
            (
                [string]$ownerFinalize.decision -eq 'PHYSICAL_FAIL' -and
                [string]$ownerFinalize.head -eq [string]$repo.Head
            )
        )
    ) {
        $ownerFinalize
    }
    else {
        $null
    }

    $burnRunning = [bool]($burnRuntime -and $burnRuntime.Running)
    $recoveryRequired = [bool]($script:BurnRecoveryRequired -or ($burnRuntime -and [string]$burnRuntime.Record.status -eq 'RECOVERY_REQUIRED'))
    $preEraseBackup = Get-PreEraseBackupStatus
    $state = if ($recoveryRequired) {
        'RECOVERY_REQUIRED'
    }
    elseif ($script:Busy -or $burnRunning) {
        'RUNNING'
    }
    elseif ($candidate -and $burnRuntime -and [string]$burnRuntime.Record.status -eq 'FAILED_SAFE') {
        'READY_TO_BURN'
    }
    elseif (
        $ownerFinalizeCurrent -and
        [string]$ownerFinalizeCurrent.state -eq 'OPEN_PR'
    ) {
        'OPEN_PR'
    }
    elseif (
        $ownerFinalizeCurrent -and
        [string]$ownerFinalizeCurrent.decision -eq 'PHYSICAL_FAIL' -and
        -not [bool]$ownerFinalizeCurrent.resolved
    ) {
        'PHYSICAL_FAIL'
    }
    elseif ($burnVerification) {
        'SPI_BURN_VERIFIED'
    }
    elseif (
        $script:LastResult -eq 'BLOCKED' -or
        (
            $trust -and
            [string]$trust.status -notin @('PASS')
        )
    ) {
        'BLOCKED'
    }
    elseif ($candidate) {
        'READY_TO_BURN'
    }
    else {
        'IDLE'
    }

    [ordered]@{
        projectId = 'eink'
        projectName = 'EINK / Clock'
        version = '0.4'
        url = "http://127.0.0.1:$Port/"
        branch = $repo.Branch
        head = $repo.Head
        state = $state
        busy = [bool]($script:Busy -or $burnRunning)
        trackedDirtyCount = @($repo.TrackedStatus).Count
        stagedCount = @($repo.StagedFiles).Count
        untrackedCount = @($repo.Untracked).Count
        brain = (Get-EinkBrainStatus)
        readyToBurn = [bool]($candidate -and -not $script:Busy -and -not $burnRunning -and -not $recoveryRequired)
        recovery = [ordered]@{
            required = $recoveryRequired
            target = 'CURRENT_ARTIFACT'
            targetLabel = 'Portrait Minute Fly'
            writeEnabled = [bool]($recoveryRequired -and $candidate -and $preEraseBackup.valid -and -not $script:Busy -and -not $burnRunning)
            normalBackupSkipped = $true
            eraseSkipped = $true
            preEraseBackup = $preEraseBackup
        }
        physicalReviewEnabled = [bool](
            $burnVerification -and
            -not $script:Busy
        )
        burnVerification = if ($burnVerification) {
            [ordered]@{
                status = [string]$burnVerification.status
                verifiedUtc = [string]$burnVerification.verifiedUtc
                artifactSha256 = [string]$burnVerification.artifactSha256
                simulated = [bool]$burnVerification.simulated
            }
        }
        else {
            $null
        }
        ownerFinalize = if ($ownerFinalizeCurrent) {
            [ordered]@{
                taskId = [string]$ownerFinalizeCurrent.taskId
                decision = [string]$ownerFinalizeCurrent.decision
                resolved = [bool]$ownerFinalizeCurrent.resolved
                state = [string]$ownerFinalizeCurrent.state
                recordedUtc = [string]$ownerFinalizeCurrent.recordedUtc
                feedback = [string]$ownerFinalizeCurrent.feedback
                evidenceCount = @($ownerFinalizeCurrent.evidence).Count
                backupPath = [string]$ownerFinalizeCurrent.backupPath
                commitSha = [string]$ownerFinalizeCurrent.commitSha
                prUrl = [string]$ownerFinalizeCurrent.prUrl
                prState = [string]$ownerFinalizeCurrent.prState
            }
        }
        else {
            $null
        }
        prepareTrust = if ($trust) {
            [ordered]@{
                attemptId = [string]$trust.attemptId
                status = [string]$trust.status
                startedUtc = [string]$trust.startedUtc
                completedUtc = [string]$trust.completedUtc
                reason = [string]$trust.reason
            }
        }
        else {
            $null
        }
        artifact = if ($candidate) {
            [ordered]@{
                title = Get-FriendlyTaskTitle -TaskId $candidate.TaskId
                taskId = $candidate.TaskId
                buildTimestamp = $candidate.BuildTimestamp
                path = $candidate.Path
                size = $candidate.Size
                sha256 = $candidate.Sha256
                manifest = $candidate.Manifest
            }
        }
        else {
            $null
        }
        lastAction = $script:LastAction
        lastResult = $script:LastResult
        lastLog = ($script:LastLog -join "`n")
        burnProgress = if ($burnRuntime) {
            $isRecoveryProgress = [string]$burnRuntime.Record.operation -eq 'RECOVERY_WRITE'
            $phaseNames = if ($isRecoveryProgress) {
                @('RECOVERY_PREFLIGHT','RECOVERY_WRITE','RECOVERY_READBACK','RECOVERY_SHA_VERIFY')
            }
            else {
                @('HARDWARE_PREFLIGHT','SPI_BACKUP','ERASE','WRITE','READBACK','SHA_VERIFY')
            }
            $phaseName = if ($burnRuntime.Phase) { [string]$burnRuntime.Phase.phase } elseif ($isRecoveryProgress) { 'RECOVERY_PREFLIGHT' } else { 'HARDWARE_PREFLIGHT' }
            $phaseIndex = [Math]::Max(0, [Array]::IndexOf($phaseNames, $phaseName))
            [ordered]@{
                attemptId = [string]$burnRuntime.Record.attemptId
                workerPid = [int]$burnRuntime.Record.pid
                workerStatus = [string]$burnRuntime.Record.status
                phase = $phaseName
                phaseStatus = if ($burnRuntime.Phase) { [string]$burnRuntime.Phase.status } else { 'STARTING' }
                reason = if ($burnRuntime.Phase) { [string]$burnRuntime.Phase.reason } else { '' }
                destructiveStarted = if ($burnRuntime.Phase) { [bool]$burnRuntime.Phase.destructiveStarted } else { $false }
                updatedUtc = if ($burnRuntime.Phase) { [string]$burnRuntime.Phase.updatedUtc } else { [string]$burnRuntime.Record.createdUtc }
                percent = [int](($phaseIndex * 100) / $phaseNames.Count)
                phases = $phaseNames
            }
        }
        else { $null }
        lifecycle = [ordered]@{
            state = 'RUNNING'
            pid = [int]$PID
            processStartUtc = $serverStartUtc
            processStartTicks = [int64]$serverStartTicks
            lockPath = $runtimeLockPath
        }
        sessionToken = $sessionToken
    }
}

function Get-ProjectStatus {
    param(
        [Parameter(Mandatory=$true)]
        [string]$ProjectId
    )

    $project = Get-RegistryProject -ProjectId $ProjectId

    if (-not $project) {
        return $null
    }

    switch ([string]$project.adapter) {
        'eink' {
            $status = Get-ControlStatus
            $status['adapter'] = 'eink'
            $status['readOnly'] = $false
            $status['available'] = $true
            $status['actions'] = @($project.actions)
            return $status
        }

        'harness-core' {
            return Get-ElectronicStatus -Project $project
        }

        default {
            return [ordered]@{
                projectId = [string]$project.id
                projectName = [string]$project.name
                version = '0.2'
                adapter = [string]$project.adapter
                readOnly = $true
                available = $false
                state = 'ADAPTER_UNAVAILABLE'
                actions = @()
                sessionToken = $sessionToken
            }
        }
    }
}

function Get-HubStatus {
    $projects = @(
        foreach ($project in @($projectRegistry.projects)) {
            [ordered]@{
                id = [string]$project.id
                name = [string]$project.name
                adapter = [string]$project.adapter
                brainOptional = [bool]$project.brainOptional
                actions = @($project.actions)
            }
        }
    )

    [ordered]@{
        hubId = 'harness-control-center'
        name = 'Harness Control Center'
        version = '0.4'
        bind = "127.0.0.1:$Port"
        defaultProjectId = 'eink'
        projects = $projects
        lifecycle = [ordered]@{
            state = 'RUNNING'
            pid = [int]$PID
            processStartUtc = $serverStartUtc
            processStartTicks = [int64]$serverStartTicks
            lockPath = $runtimeLockPath
        }
        sessionToken = $sessionToken
    }
}

function Set-LastLog {
    param(
        [string]$Action,
        [string]$Result,
        [string[]]$Lines
    )

    $script:LastAction = $Action
    $script:LastResult = $Result
    $script:LastLog = @($Lines)
}

function Invoke-PrepareAction {
    $activeBurn = Sync-BurnRuntimeState
    if ($script:Busy -or ($activeBurn -and $activeBurn.Running)) {
        return Get-ControlStatus
    }

    $script:Busy = $true
    $attemptId = [Guid]::NewGuid().ToString('N')

    try {
        Set-LastLog `
            -Action 'PREPARE_TEST' `
            -Result 'RUNNING' `
            -Lines @(
                'Starting EINK prepare-test...',
                'Build + pack + verify only.',
                'No SPI burn will be performed.'
            )

        $repoAtStart = Get-RepoState
        $approvedFilesAtStart = @(Get-ApprovedFinalizeFiles)
        $approvedFilesFingerprintAtStart = Get-ApprovedFilesFingerprint

        $trustStart = Set-PrepareTrustState `
            -Status 'RUNNING' `
            -AttemptId $attemptId `
            -Data @{
                branch = [string]$repoAtStart.Branch
                head = [string]$repoAtStart.Head
                taskId = [string]$einkRegistryProject.finalize.taskId
                approvedFiles = $approvedFilesAtStart
                approvedFilesFingerprint = $approvedFilesFingerprintAtStart
                reason = 'PREPARE_IN_PROGRESS'
            }

        if (-not [bool]$trustStart.durable) {
            throw 'PREPARE_TRUST_STATE_NOT_DURABLE_BURN_DISABLED'
        }

        $beforeFingerprint = Get-WorkspaceFingerprint

        $trustFingerprint = Set-PrepareTrustState `
            -Status 'RUNNING' `
            -AttemptId $attemptId `
            -Data @{
                workspaceFingerprint = $beforeFingerprint
            }

        if (-not [bool]$trustFingerprint.durable) {
            throw 'PREPARE_TRUST_FINGERPRINT_NOT_DURABLE_BURN_DISABLED'
        }

        $result = Invoke-NativeText `
            -FilePath 'powershell.exe' `
            -Arguments @(
                '-NoProfile',
                '-ExecutionPolicy',
                'Bypass',
                '-File',
                $prepareScript,
                'prepare-test'
            )

        $output = @($result.Output)

        if (
            $result.ExitCode -ne 0 -or
            -not ($output -match '^EINK HARNESS: PASS$') -or
            -not ($output -match '^NEXT_STATE: OWNER_BURN_CONFIRMATION_REQUIRED$')
        ) {
            Set-PrepareAttemptFailure `
                -AttemptId $attemptId `
                -Reason 'HARNESS_PREPARE_FAILED'

            Set-LastLog `
                -Action 'PREPARE_TEST' `
                -Result 'BLOCKED' `
                -Lines $output

            return
        }

        $afterFingerprint = Get-WorkspaceFingerprint
        $approvedFilesAfter = @(Get-ApprovedFinalizeFiles)
        $approvedFilesFingerprintAfter = Get-ApprovedFilesFingerprint

        if (
            $beforeFingerprint -ne $afterFingerprint -or
            ($approvedFilesAtStart -join "`n") -ne
                ($approvedFilesAfter -join "`n") -or
            $approvedFilesFingerprintAtStart -ne
                $approvedFilesFingerprintAfter
        ) {
            Set-PrepareAttemptFailure `
                -AttemptId $attemptId `
                -Reason 'SOURCE_CHANGED_DURING_PREPARE'

            Set-LastLog `
                -Action 'PREPARE_TEST' `
                -Result 'BLOCKED' `
                -Lines (
                    $output +
                    'BLOCKED: SOURCE_CHANGED_DURING_PREPARE'
                )

            return
        }

        $manifestLine = @(
            $output |
            Where-Object {
                $_ -match '^MANIFEST:\s+.+$'
            }
        ) | Select-Object -Last 1

        if (-not $manifestLine) {
            Set-PrepareAttemptFailure `
                -AttemptId $attemptId `
                -Reason 'MANIFEST_NOT_FOUND'

            Set-LastLog `
                -Action 'PREPARE_TEST' `
                -Result 'BLOCKED' `
                -Lines (
                    $output +
                    'BLOCKED: MANIFEST_NOT_FOUND'
                )

            return
        }

        $manifestPath = (
            $manifestLine -replace '^MANIFEST:\s+', ''
        ).Trim()

        if (-not (Test-Path -LiteralPath $manifestPath -PathType Leaf)) {
            Set-PrepareAttemptFailure `
                -AttemptId $attemptId `
                -Reason 'MANIFEST_FILE_MISSING'

            Set-LastLog `
                -Action 'PREPARE_TEST' `
                -Result 'BLOCKED' `
                -Lines (
                    $output +
                    'BLOCKED: MANIFEST_FILE_MISSING'
                )

            return
        }

        $manifest = Get-Content -LiteralPath $manifestPath -Raw | ConvertFrom-Json

        $packedPath = [string]$manifest.packed.path

        if (-not (Test-Path -LiteralPath $packedPath -PathType Leaf)) {
            Set-PrepareAttemptFailure `
                -AttemptId $attemptId `
                -Reason 'PACKED_FILE_MISSING'

            Set-LastLog `
                -Action 'PREPARE_TEST' `
                -Result 'BLOCKED' `
                -Lines (
                    $output +
                    'BLOCKED: PACKED_FILE_MISSING'
                )

            return
        }

        $packedSha = Get-Sha256Hex -Path $packedPath

        if (
            $packedSha -ne
            ([string]$manifest.packed.sha256).ToUpperInvariant()
        ) {
            Set-PrepareAttemptFailure `
                -AttemptId $attemptId `
                -Reason 'PACKED_SHA_CHANGED'

            Set-LastLog `
                -Action 'PREPARE_TEST' `
                -Result 'BLOCKED' `
                -Lines (
                    $output +
                    'BLOCKED: PACKED_SHA_CHANGED'
                )

            return
        }

        $repo = Get-RepoState

        $lock = [ordered]@{
            schema = 'eink-control-center-lock-v1'
            createdUtc = [DateTime]::UtcNow.ToString('o')
            branch = $repo.Branch
            head = $repo.Head
            workspaceFingerprint = $afterFingerprint
            taskId = [string]$einkRegistryProject.finalize.taskId
            approvedFiles = $approvedFilesAfter
            approvedFilesFingerprint = $approvedFilesFingerprintAfter
            packedSha256 = $packedSha
            packedPath = $packedPath
            nextState = 'OWNER_BURN_CONFIRMATION_REQUIRED'
        }

        $lockPath = Join-Path (
            Split-Path -Parent $manifestPath
        ) 'control-center-lock.json'

        [IO.File]::WriteAllText(
            $lockPath,
            ($lock | ConvertTo-Json -Depth 8),
            [Text.UTF8Encoding]::new($false)
        )

        $passTrust = Set-PrepareTrustState `
            -Status 'PASS' `
            -AttemptId $attemptId `
            -Data @{
                branch = [string]$repo.Branch
                head = [string]$repo.Head
                workspaceFingerprint = $afterFingerprint
                taskId = [string]$einkRegistryProject.finalize.taskId
                approvedFiles = $approvedFilesAfter
                approvedFilesFingerprint = $approvedFilesFingerprintAfter
                manifestPath = $manifestPath
                lockPath = $lockPath
                evidenceDir = (Split-Path -Parent $manifestPath)
                packedSha256 = $packedSha
                reason = 'PREPARE_PASS_LOCKED_ARTIFACT'
            }

        if (
            -not [bool]$passTrust.durable -or
            [string]$passTrust.status -ne 'PASS'
        ) {
            throw 'PREPARE_PASS_TRUST_NOT_DURABLE_BURN_DISABLED'
        }

        Set-LastLog `
            -Action 'PREPARE_TEST' `
            -Result 'PASS' `
            -Lines $output
    }
    catch {
        Set-PrepareAttemptFailure `
            -AttemptId $attemptId `
            -Reason ('EXCEPTION: ' + $_.Exception.Message)

        Set-LastLog `
            -Action 'PREPARE_TEST' `
            -Result 'BLOCKED' `
            -Lines @(
                "EXCEPTION: $($_.Exception.Message)"
            )
    }
    finally {
        $script:Busy = $false
    }

    Get-ControlStatus
}

function Get-ExactStashRef {
    param(
        [Parameter(Mandatory=$true)]
        [string]$Label
    )

    $result = Invoke-Git -Arguments @(
        'stash',
        'list',
        '--format=%gd|%s'
    )

    if ($result.ExitCode -ne 0) {
        return $null
    }

    $matches = @(
        $result.Output |
        Where-Object {
            $_ -and $_.Contains($Label)
        }
    )

    if ($matches.Count -ne 1) {
        return $null
    }

    ($matches[0].Split('|', 2)[0]).Trim()
}

function Invoke-BurnAction {
    param(
        [Parameter(Mandatory=$true)]
        $Body
    )

    $existingBurn = Sync-BurnRuntimeState
    if ($script:Busy -or ($existingBurn -and $existingBurn.Running)) {
        return Get-ControlStatus
    }
    if ($script:BurnRecoveryRequired -or ($existingBurn -and [string]$existingBurn.Record.status -eq 'RECOVERY_REQUIRED')) {
        Set-LastLog -Action 'SPI_BURN' -Result 'BLOCKED' -Lines @(
            'BLOCKED: RECOVERY_REQUIRED',
            'Normal fresh-backup/erase burn is forbidden during recovery.'
        )
        return Get-ControlStatus
    }

    $repoBefore = Get-RepoState
    $candidate = Get-LatestPrepareCandidate -RepoState $repoBefore

    if (-not $candidate) {
        Set-LastLog `
            -Action 'SPI_BURN' `
            -Result 'BLOCKED' `
            -Lines @(
                'BLOCKED: NO_VALID_LOCKED_ARTIFACT'
            )

        return Get-ControlStatus
    }

    if ([string]$Body.confirm -ne 'BURN') {
        Set-LastLog `
            -Action 'SPI_BURN' `
            -Result 'BLOCKED' `
            -Lines @(
                'BLOCKED: OWNER_CONFIRMATION_REQUIRED'
            )

        return Get-ControlStatus
    }

    $requestedSha = (
        [string]$Body.sha256
    ).Trim().ToUpperInvariant()

    if ($requestedSha -ne $candidate.Sha256) {
        Set-LastLog `
            -Action 'SPI_BURN' `
            -Result 'BLOCKED' `
            -Lines @(
                'BLOCKED: UI_ARTIFACT_SHA_MISMATCH'
            )

        return Get-ControlStatus
    }

    if (@($repoBefore.StagedFiles).Count -gt 0) {
        Set-LastLog `
            -Action 'SPI_BURN' `
            -Result 'BLOCKED' `
            -Lines @(
                'BLOCKED: STAGED_CHANGES_EXIST',
                'Control Center will not rewrite an existing Git index.'
            )

        return Get-ControlStatus
    }

    try {
        Set-LastLog `
            -Action 'SPI_BURN' `
            -Result 'RUNNING' `
            -Lines @(
                'Owner destructive confirmation received.',
                "Artifact SHA256: $($candidate.Sha256)",
                'HARDWARE_PREFLIGHT will run before backup/erase/write.',
                'No destructive command is allowed before preflight PASS.'
            )
        $worker = Start-EinkBurnWorker -Candidate $candidate -RepoState $repoBefore
        $script:LastLog += @(
            "BURN_WORKER_PID: $($worker.pid)",
            'PHASE: HARDWARE_PREFLIGHT'
        )
    }
    catch {
        Set-LastLog `
            -Action 'SPI_BURN' `
            -Result 'BLOCKED' `
            -Lines (
                $script:LastLog +
                "EXCEPTION: $($_.Exception.Message)"
            )
    }
    Get-ControlStatus
}

function Invoke-RecoveryArmAction {
    $existingBurn = Sync-BurnRuntimeState
    $recoveryRequired = [bool]($script:BurnRecoveryRequired -or ($existingBurn -and [string]$existingBurn.Record.status -eq 'RECOVERY_REQUIRED'))
    $repo = Get-RepoState
    $candidate = Get-LatestPrepareCandidate -RepoState $repo
    $backupStatus = Get-PreEraseBackupStatus
    if ($script:Busy -or ($existingBurn -and $existingBurn.Running) -or
        -not $recoveryRequired -or -not $candidate -or -not $backupStatus.valid) {
        return [ordered]@{ armed=$false; reason='RECOVERY_NOT_ELIGIBLE' }
    }
    $challenge = New-RecoveryOwnerChallenge -ArtifactSha256 $candidate.Sha256
    [ordered]@{
        armed = $true
        ownerChallenge = $challenge.challenge
        expiresUtc = $challenge.expiresUtc
        artifactSha256 = $challenge.artifactSha256
        target = 'CURRENT_ARTIFACT'
    }
}

function Invoke-RecoveryWriteAction {
    param(
        [Parameter(Mandatory=$true)]
        $Body
    )
    $existingBurn = Sync-BurnRuntimeState
    if ($script:Busy -or ($existingBurn -and $existingBurn.Running)) {
        return Get-ControlStatus
    }
    $recoveryRequired = [bool]($script:BurnRecoveryRequired -or ($existingBurn -and [string]$existingBurn.Record.status -eq 'RECOVERY_REQUIRED'))
    if (-not $recoveryRequired) {
        Set-LastLog -Action 'SPI_RECOVERY_WRITE' -Result 'BLOCKED' -Lines @('BLOCKED: RECOVERY_STATE_REQUIRED')
        return Get-ControlStatus
    }
    $repoBefore = Get-RepoState
    $candidate = Get-LatestPrepareCandidate -RepoState $repoBefore
    if (-not $candidate) {
        Set-LastLog -Action 'SPI_RECOVERY_WRITE' -Result 'BLOCKED' -Lines @('BLOCKED: FRESH_PREPARE_LOCK_REQUIRED')
        return Get-ControlStatus
    }
    $backupStatus = Get-PreEraseBackupStatus
    if (-not $backupStatus.valid) {
        Set-LastLog -Action 'SPI_RECOVERY_WRITE' -Result 'BLOCKED' -Lines @(
            'BLOCKED: IMMUTABLE_PRE_ERASE_BACKUP_INVALID',
            "REASON: $($backupStatus.reason)"
        )
        return Get-ControlStatus
    }
    $ownerChallenge = [string]$Body.ownerChallenge
    if (-not (Test-AndConsumeRecoveryOwnerChallenge -Challenge $ownerChallenge -ArtifactSha256 $candidate.Sha256)) {
        Set-LastLog -Action 'SPI_RECOVERY_WRITE' -Result 'BLOCKED' -Lines @('BLOCKED: RECOVERY_OWNER_CONFIRMATION_REQUIRED')
        return Get-ControlStatus
    }
    $requestedSha = ([string]$Body.sha256).Trim().ToUpperInvariant()
    if ($requestedSha -ne $candidate.Sha256) {
        Set-LastLog -Action 'SPI_RECOVERY_WRITE' -Result 'BLOCKED' -Lines @('BLOCKED: RECOVERY_ARTIFACT_SHA_MISMATCH')
        return Get-ControlStatus
    }
    if (@($repoBefore.StagedFiles).Count -gt 0) {
        Set-LastLog -Action 'SPI_RECOVERY_WRITE' -Result 'BLOCKED' -Lines @('BLOCKED: STAGED_CHANGES_EXIST')
        return Get-ControlStatus
    }
    try {
        Set-LastLog -Action 'SPI_RECOVERY_WRITE' -Result 'RUNNING' -Lines @(
            'Owner confirmed controlled recovery WRITE.',
            'Recovery target: Portrait Minute Fly.',
            "Artifact SHA256: $($candidate.Sha256)",
            "Immutable rollback SHA256: $preEraseBackupSha256",
            'Normal fresh backup: SKIPPED.',
            'Erase: SKIPPED.',
            'Recovery path: hardware preflight -> WRITE -> full READBACK -> SHA verify.'
        )
        $worker = Start-EinkBurnWorker -Candidate $candidate -RepoState $repoBefore -RecoveryWrite -RecoveryChallenge $ownerChallenge
        $script:LastLog += @(
            "RECOVERY_WORKER_PID: $($worker.pid)",
            'PHASE: RECOVERY_PREFLIGHT'
        )
    }
    catch {
        $script:BurnRecoveryRequired = $true
        Set-LastLog -Action 'SPI_RECOVERY_WRITE' -Result 'RECOVERY_REQUIRED' -Lines @("EXCEPTION: $($_.Exception.Message)")
    }
    Get-ControlStatus
}

function Read-HttpRequest {
    param(
        [Parameter(Mandatory=$true)]
        [Net.Sockets.TcpClient]$Client
    )

    $Client.ReceiveTimeout = 5000
    $Client.SendTimeout = 5000
    $stream = $Client.GetStream()
    $stream.ReadTimeout = 5000
    $stream.WriteTimeout = 5000
    $headerBuffer = New-Object 'Collections.Generic.List[byte]'
    $delimiter = [byte[]](13, 10, 13, 10)
    $matched = 0

    while ($matched -lt $delimiter.Length) {
        $value = $stream.ReadByte()

        if ($value -lt 0) {
            return $null
        }

        $byte = [byte]$value
        $headerBuffer.Add($byte)

        if ($headerBuffer.Count -gt 65536) {
            throw 'HTTP request headers exceed the safe limit.'
        }

        if ($byte -eq $delimiter[$matched]) {
            $matched++
        }
        elseif ($byte -eq $delimiter[0]) {
            $matched = 1
        }
        else {
            $matched = 0
        }
    }

    $headerLength = $headerBuffer.Count - $delimiter.Length
    $headerText = [Text.Encoding]::ASCII.GetString(
        $headerBuffer.ToArray(),
        0,
        $headerLength
    )
    $headerLines = @($headerText -split "`r`n")
    $requestLine = if ($headerLines.Count -gt 0) {
        $headerLines[0]
    }
    else {
        ''
    }

    if ([string]::IsNullOrWhiteSpace($requestLine)) {
        return $null
    }

    $parts = $requestLine.Split(' ')

    if ($parts.Count -lt 2) {
        return $null
    }

    $method = $parts[0].ToUpperInvariant()
    $path = $parts[1].Split('?')[0]

    $headers = @{}

    foreach ($line in @($headerLines | Select-Object -Skip 1)) {
        if ([string]::IsNullOrWhiteSpace($line)) { continue }

        $separator = $line.IndexOf(':')

        if ($separator -le 0) {
            continue
        }

        $name = $line.Substring(0, $separator).Trim().ToLowerInvariant()
        $value = $line.Substring($separator + 1).Trim()

        $headers[$name] = $value
    }

    $body = ''

    $contentLength = 0

    if ($headers.ContainsKey('content-length')) {
        [void][int]::TryParse(
            [string]$headers['content-length'],
            [ref]$contentLength
        )
    }

    if ($contentLength -lt 0 -or $contentLength -gt 80MB) {
        throw 'HTTP request body exceeds the safe limit.'
    }

    if ($contentLength -gt 0) {
        $buffer = New-Object byte[] $contentLength
        $total = 0

        while ($total -lt $contentLength) {
            $read = $stream.Read(
                $buffer,
                $total,
                $contentLength - $total
            )

            if ($read -le 0) {
                break
            }

            $total += $read
        }

        if ($total -ne $contentLength) {
            throw 'HTTP request body ended before Content-Length bytes were received.'
        }

        $utf8Strict = New-Object Text.UTF8Encoding($false, $true)
        $body = $utf8Strict.GetString($buffer)
    }

    [PSCustomObject]@{
        Method = $method
        Path = $path
        Headers = $headers
        Body = $body
    }
}

function Write-HttpResponse {
    param(
        [Parameter(Mandatory=$true)]
        [Net.Sockets.TcpClient]$Client,

        [int]$StatusCode = 200,

        [string]$ContentType = 'application/json; charset=utf-8',

        [string]$Body = ''
    )

    $reason = switch ($StatusCode) {
        200 { 'OK' }
        400 { 'Bad Request' }
        403 { 'Forbidden' }
        404 { 'Not Found' }
        405 { 'Method Not Allowed' }
        409 { 'Conflict' }
        500 { 'Internal Server Error' }
        default { 'OK' }
    }

    $bodyBytes = [Text.Encoding]::UTF8.GetBytes($Body)

    $headers = @(
        "HTTP/1.1 $StatusCode $reason",
        "Content-Type: $ContentType",
        "Content-Length: $($bodyBytes.Length)",
        'Connection: close',
        'Cache-Control: no-store',
        'X-Content-Type-Options: nosniff',
        "Content-Security-Policy: default-src 'self'; script-src 'unsafe-inline'; style-src 'unsafe-inline'; connect-src 'self'; img-src 'none'; frame-ancestors 'none'",
        '',
        ''
    ) -join "`r`n"

    $headerBytes = [Text.Encoding]::ASCII.GetBytes($headers)

    $stream = $Client.GetStream()

    $stream.Write(
        $headerBytes,
        0,
        $headerBytes.Length
    )

    if ($bodyBytes.Length -gt 0) {
        $stream.Write(
            $bodyBytes,
            0,
            $bodyBytes.Length
        )
    }

    $stream.Flush()
}

function Write-Json {
    param(
        [Parameter(Mandatory=$true)]
        [Net.Sockets.TcpClient]$Client,

        [int]$StatusCode = 200,

        [Parameter(Mandatory=$true)]
        $Value
    )

    Write-HttpResponse `
        -Client $Client `
        -StatusCode $StatusCode `
        -ContentType 'application/json; charset=utf-8' `
        -Body (
            $Value |
            ConvertTo-Json -Depth 10 -Compress
        )
}

function Test-WriteAuthorization {
    param(
        [Parameter(Mandatory=$true)]
        $Request
    )

    if (-not $Request.Headers.ContainsKey('content-type')) {
        return $false
    }

    if (
        -not (
            [string]$Request.Headers['content-type']
        ).StartsWith(
            'application/json',
            [StringComparison]::OrdinalIgnoreCase
        )
    ) {
        return $false
    }

    if (-not $Request.Headers.ContainsKey($writeTokenHeaderKey)) {
        return $false
    }

    return (
        [string]$Request.Headers[$writeTokenHeaderKey] -eq
        $sessionToken
    )
}

$registryIds = @(
    $projectRegistry.projects |
    ForEach-Object { [string]$_.id }
)

if (
    $registryIds.Count -eq 0 -or
    @($registryIds | Select-Object -Unique).Count -ne $registryIds.Count
) {
    throw 'Harness Hub project registry contains missing or duplicate ids.'
}

$einkRegistryProject = Get-RegistryProject -ProjectId 'eink'

if (
    -not $einkRegistryProject -or
    [string]$einkRegistryProject.adapter -ne 'eink' -or
    (
        -not $AcceptanceMode -and
        -not [IO.Path]::GetFullPath(
            [string]$einkRegistryProject.workspace
        ).Equals(
            [IO.Path]::GetFullPath($repoRoot),
            [StringComparison]::OrdinalIgnoreCase
        )
    )
) {
    throw 'EINK registry workspace does not match the running repository.'
}

$activeFinalizeTask = Read-Utf8JsonFile -Path $activeFinalizeTaskPath
if ($activeFinalizeTask) {
    $einkRegistryProject.finalize = $activeFinalizeTask
}

if (
    [string]::IsNullOrWhiteSpace(
        [string]$einkRegistryProject.finalize.taskId
    ) -or
    [string]$einkRegistryProject.finalize.baseBranch -ne 'main' -or
    @(Get-ApprovedFinalizeFiles).Count -eq 0
) {
    throw 'EINK active finalize profile is invalid.'
}

Initialize-PrepareTrustState
Initialize-EinkBrainStore
Initialize-AcceptanceBurnFixture

if ($BurnSafetyAcceptance) {
    $packed = [IO.Path]::GetFullPath($BurnSafetyPackedBin)
    if (-not (Test-Path -LiteralPath $packed -PathType Leaf)) {
        throw 'Burn safety acceptance packed BIN is missing.'
    }
    $repoForFixture = Get-RepoState
    $script:AcceptancePrepareCandidate = [pscustomobject]@{
        Path = $packed
        Size = [int64](Get-Item -LiteralPath $packed).Length
        Sha256 = Get-Sha256Hex -Path $packed
        Manifest = 'BURN_SAFETY_ACCEPTANCE'
        EvidenceDir = $runtimeRoot
        WorkspaceFingerprint = Get-WorkspaceFingerprint
        AttemptId = 'BURN_SAFETY_ACCEPTANCE'
        TaskId = [string]$einkRegistryProject.finalize.taskId
        BuildTimestamp = [DateTime]::UtcNow.ToString('o')
    }
    [void](Invoke-BurnAction -Body @{
        confirm = 'BURN'
        sha256 = $script:AcceptancePrepareCandidate.Sha256
    })
    $deadline = [DateTime]::UtcNow.AddSeconds(45)
    do {
        Start-Sleep -Milliseconds 100
        $runtime = Sync-BurnRuntimeState
    } while ($runtime -and $runtime.Running -and [DateTime]::UtcNow -lt $deadline)
    if ($runtime -and $runtime.Running) {
        throw 'Burn safety acceptance worker exceeded its bounded deadline.'
    }
    $status = Get-ControlStatus
    if ($status.state -ne 'READY_TO_BURN' -or
        -not $status.readyToBurn -or
        $status.burnProgress.reason -ne 'BOARD_NOT_CONNECTED' -or
        $status.burnProgress.destructiveStarted) {
        throw 'Burn safety acceptance did not return safely to READY_TO_BURN.'
    }
    Write-Output ('BURN_SAFETY_ACCEPTANCE_JSON:' + ($status | ConvertTo-Json -Depth 12 -Compress))
    exit 0
}

if (-not $BurnSafetyAcceptance -and
    (-not [string]::IsNullOrWhiteSpace($BurnSafetyProfilePath) -or
     -not [string]::IsNullOrWhiteSpace($BurnSafetyPackedBin))) {
    throw 'Burn safety fixture parameters require -BurnSafetyAcceptance.'
}

if (
    $FeedbackTransportAcceptance -and
    (
        $AcceptanceMode -or
        $Port -eq 5175 -or
        -not $NoBrowser
    )
) {
    throw 'Feedback transport acceptance requires production workspace, a non-production port, and -NoBrowser.'
}

if ($BurnPlanAcceptance) {
    if (
        $AcceptanceMode -or
        -not $NoBrowser -or
        [string]::IsNullOrWhiteSpace($BurnPlanPackedBin)
    ) {
        throw 'Burn PLAN acceptance requires production workspace, -NoBrowser, and an explicit packed BIN.'
    }

    $planResult = Invoke-EinkSpiBurnScript `
        -Mode 'Plan' `
        -PackedBin $BurnPlanPackedBin

    $planResult.Output | ForEach-Object { Write-Output $_ }

    if (
        $planResult.ExitCode -ne 0 -or
        -not ($planResult.Output -match '^EINK HARNESS: PASS$') -or
        -not ($planResult.Output -match '^ACTION: SPI-BURN-PLAN$') -or
        -not ($planResult.Output -match '^NEXT_STATE: OWNER_BURN_CONFIRMATION_REQUIRED$')
    ) {
        exit 1
    }

    exit 0
}

if (
    -not [string]::IsNullOrWhiteSpace($BurnPlanPackedBin)
) {
    throw 'Burn PLAN artifact parameter requires -BurnPlanAcceptance.'
}

$url = "http://127.0.0.1:$Port/"

$existingRuntimeLock = Read-Utf8JsonFile -Path $runtimeLockPath
if (
    $existingRuntimeLock -and
    [int]$existingRuntimeLock.pid -ne [int]$PID -and
    (Test-ServerLifecycleLockProcess -Lock $existingRuntimeLock)
) {
    throw 'A tracked Harness Control Center process already owns this port.'
}

$listener = New-Object Net.Sockets.TcpListener(
    [Net.IPAddress]::Loopback,
    $Port
)
$listener.Server.SetSocketOption(
    [Net.Sockets.SocketOptionLevel]::Socket,
    [Net.Sockets.SocketOptionName]::ReuseAddress,
    $true
)
$script:ListenerClosed = $false

function Stop-ControlCenterListener {
    param([string]$Reason = 'SHUTDOWN')

    if ($script:ListenerClosed) {
        return
    }
    Write-AcceptanceLifecycleTrace `
        -Phase 'LISTENER_STOP_BEGIN' `
        -Detail "REASON=$Reason"
    $listener.Stop()
    $script:ListenerClosed = $true
    Write-AcceptanceLifecycleTrace `
        -Phase 'LISTENER_STOP_PASS' `
        -Detail "REASON=$Reason"
}

try {
    $listener.Start()
    Write-ServerLifecycleLock
}
catch {
    Write-Output 'HARNESS CONTROL CENTER: BLOCKED'
    Write-Output "REASON: PORT_BIND_FAILED_$Port"
    Write-Output $_.Exception.Message
    exit 1
}

Write-Output 'HARNESS CONTROL CENTER: PASS'
Write-Output "URL: $url"
Write-Output 'BIND: 127.0.0.1 ONLY'
Write-Output 'NEXT_STATE: CONTROL_CENTER_RUNNING'

if (-not $NoBrowser) {
    Start-Process $url
}

try {
    while (-not $script:StopRequested) {
        Write-AcceptanceLifecycleTrace -Phase 'ACCEPT_WAIT_BEGIN'
        $client = $listener.AcceptTcpClient()
        Write-AcceptanceLifecycleTrace -Phase 'ACCEPT_WAIT_PASS'

        try {
            Write-AcceptanceLifecycleTrace -Phase 'HTTP_READ_BEGIN'
            $request = Read-HttpRequest -Client $client
            Write-AcceptanceLifecycleTrace -Phase 'HTTP_READ_PASS' -Detail "$($request.Method) $($request.Path)"

            if (-not $request) {
                Write-Json `
                    -Client $client `
                    -StatusCode 400 `
                    -Value @{
                        error = 'BAD_REQUEST'
                    }

                continue
            }

            $hostHeader = if (
                $request.Headers.ContainsKey('host')
            ) {
                [string]$request.Headers['host']
            }
            else {
                ''
            }

            if ($hostHeader -ne "127.0.0.1:$Port") {
                Write-Json `
                    -Client $client `
                    -StatusCode 403 `
                    -Value @{
                        error = 'HOST_REJECTED'
                    }

                continue
            }

            if (
                $request.Method -eq 'GET' -and
                $request.Path -eq '/'
            ) {
                $html = [IO.File]::ReadAllText(
                    $indexPath,
                    [Text.Encoding]::UTF8
                )

                Write-HttpResponse `
                    -Client $client `
                    -StatusCode 200 `
                    -ContentType 'text/html; charset=utf-8' `
                    -Body $html

                continue
            }

            if (
                $request.Method -eq 'GET' -and
                $request.Path -eq '/api/status'
            ) {
                Write-AcceptanceLifecycleTrace -Phase 'STATUS_ROUTE_BEGIN'
                Write-Json `
                    -Client $client `
                    -StatusCode 200 `
                    -Value (
                        Get-HubStatus
                    )
                Write-AcceptanceLifecycleTrace -Phase 'STATUS_ROUTE_PASS'

                continue
            }

            if (
                $request.Method -eq 'GET' -and
                $request.Path -match '^/api/projects/([a-z0-9-]+)/status$'
            ) {
                $projectId = [string]$Matches[1]
                $projectStatus = Get-ProjectStatus -ProjectId $projectId

                if (-not $projectStatus) {
                    Write-Json `
                        -Client $client `
                        -StatusCode 404 `
                        -Value @{
                            error = 'PROJECT_NOT_FOUND'
                        }

                    continue
                }

                Write-Json `
                    -Client $client `
                    -StatusCode 200 `
                    -Value $projectStatus

                continue
            }

            if (
                $request.Method -eq 'POST' -and
                $request.Path -match '^/api/projects/([a-z0-9-]+)/actions/([a-z0-9-]+)$'
            ) {
                $projectId = [string]$Matches[1]
                $actionId = [string]$Matches[2]
                $project = Get-RegistryProject -ProjectId $projectId

                if (-not $project) {
                    Write-Json `
                        -Client $client `
                        -StatusCode 404 `
                        -Value @{
                            error = 'PROJECT_NOT_FOUND'
                        }

                    continue
                }

                if (
                    -not (
                        Test-ProjectActionAllowed `
                            -Project $project `
                            -ActionId $actionId `
                            -Method 'POST'
                    )
                ) {
                    Write-Json `
                        -Client $client `
                        -StatusCode 403 `
                        -Value @{
                            error = 'ACTION_NOT_ALLOWED'
                        }

                    continue
                }

                if (-not (Test-WriteAuthorization -Request $request)) {
                    Write-Json `
                        -Client $client `
                        -StatusCode 403 `
                        -Value @{
                            error = 'WRITE_AUTH_REQUIRED'
                        }

                    continue
                }

                if ([string]$project.adapter -eq 'harness-core') {
                    try {
                        $body = if (
                            [string]::IsNullOrWhiteSpace($request.Body)
                        ) {
                            @{}
                        }
                        else {
                            $request.Body | ConvertFrom-Json
                        }
                    }
                    catch {
                        Write-Json `
                            -Client $client `
                            -StatusCode 400 `
                            -Value @{
                                error = 'INVALID_JSON'
                            }

                        continue
                    }

                    $result = Invoke-ElectronicCoreAction `
                        -Project $project `
                        -ActionId $actionId `
                        -Body $body

                    Write-Json `
                        -Client $client `
                        -StatusCode 200 `
                        -Value $result

                    continue
                }

                if (
                    [string]$project.adapter -eq 'eink' -and
                    $actionId -eq 'prepare'
                ) {
                    Write-Json `
                        -Client $client `
                        -StatusCode 200 `
                        -Value (Invoke-PrepareAction)

                    continue
                }

                if (
                    [string]$project.adapter -eq 'eink' -and
                    $actionId -in @('brain-create', 'brain-resume')
                ) {
                    try {
                        $body = if (
                            [string]::IsNullOrWhiteSpace($request.Body)
                        ) {
                            @{}
                        }
                        else {
                            $request.Body | ConvertFrom-Json
                        }
                    }
                    catch {
                        Write-Json `
                            -Client $client `
                            -StatusCode 400 `
                            -Value @{
                                error = 'INVALID_JSON'
                            }

                        continue
                    }

                    $value = if ($actionId -eq 'brain-create') {
                        Invoke-EinkBrainCreateAction -Body $body
                    }
                    else {
                        Invoke-EinkBrainResumeAction -Body $body
                    }

                    Write-Json `
                        -Client $client `
                        -StatusCode 200 `
                        -Value $value

                    continue
                }
                if (
                    [string]$project.adapter -eq 'eink' -and
                    $actionId -eq 'burn'
                ) {
                    try {
                        $body = if (
                            [string]::IsNullOrWhiteSpace($request.Body)
                        ) {
                            @{}
                        }
                        else {
                            $request.Body | ConvertFrom-Json
                        }
                    }
                    catch {
                        Write-Json `
                            -Client $client `
                            -StatusCode 400 `
                            -Value @{
                                error = 'INVALID_JSON'
                            }

                        continue
                    }

                    Write-Json `
                        -Client $client `
                        -StatusCode 200 `
                        -Value $(
                            if ([string]$body.mode -eq 'RECOVERY_ARM') {
                                Invoke-RecoveryArmAction
                            }
                            elseif ([string]$body.mode -eq 'RECOVERY_WRITE') {
                                Invoke-RecoveryWriteAction -Body $body
                            }
                            else {
                                Invoke-BurnAction -Body $body
                            }
                        )

                    continue
                }

                if (
                    [string]$project.adapter -eq 'eink' -and
                    $actionId -in @('physical-pass', 'physical-fail')
                ) {
                    try {
                        $body = if (
                            [string]::IsNullOrWhiteSpace($request.Body)
                        ) {
                            @{}
                        }
                        else {
                            $request.Body | ConvertFrom-Json
                        }
                    }
                    catch {
                        Write-Json `
                            -Client $client `
                            -StatusCode 400 `
                            -Value @{
                                error = 'INVALID_JSON'
                            }

                        continue
                    }

                    if ($FeedbackTransportAcceptance) {
                        $feedback = [string]$body.feedback
                        $evidence = @($body.evidence)
                        $accepted = (
                            -not [string]::IsNullOrWhiteSpace($feedback) -or
                            $evidence.Count -gt 0
                        )

                        Write-Json `
                            -Client $client `
                            -StatusCode 200 `
                            -Value ([ordered]@{
                                action = $actionId
                                receivedFeedback = $feedback
                                evidenceCount = $evidence.Count
                                accepted = $accepted
                            })

                        $script:StopRequested = $true
                        continue
                    }

                    $value = if ($actionId -eq 'physical-pass') {
                        Invoke-PhysicalPassAction -Body $body
                    }
                    else {
                        Invoke-PhysicalFailAction -Body $body
                    }

                    Write-Json `
                        -Client $client `
                        -StatusCode 200 `
                        -Value $value

                    continue
                }

                Write-Json `
                    -Client $client `
                    -StatusCode 403 `
                    -Value @{
                        error = 'ACTION_NOT_IMPLEMENTED'
                    }

                continue
            }

            if (
                $request.Method -eq 'POST' -and
                $request.Path -eq '/api/lifecycle/start'
            ) {
                if (-not (Test-WriteAuthorization -Request $request)) {
                    Write-Json -Client $client -StatusCode 403 -Value @{
                        error = 'WRITE_AUTH_REQUIRED'
                    }
                    continue
                }

                Write-Json -Client $client -StatusCode 200 -Value @{
                    result = 'ALREADY_RUNNING'
                    pid = [int]$PID
                    processStartUtc = $serverStartUtc
                    processStartTicks = [int64]$serverStartTicks
                }
                continue
            }

            if (
                $request.Method -eq 'POST' -and
                $request.Path -eq '/api/lifecycle/restart'
            ) {
                if (-not (Test-WriteAuthorization -Request $request)) {
                    Write-Json -Client $client -StatusCode 403 -Value @{
                        error = 'WRITE_AUTH_REQUIRED'
                    }
                    continue
                }

                Stop-ControlCenterListener `
                    -Reason 'RESTART_BEFORE_REPLACEMENT'
                Start-ControlCenterReplacement
                Write-AcceptanceLifecycleTrace -Phase 'RESTART_REPLACEMENT_LAUNCHED'
                Write-Json -Client $client -StatusCode 200 -Value @{
                    result = 'RESTARTING'
                    pid = [int]$PID
                    processStartUtc = $serverStartUtc
                    processStartTicks = [int64]$serverStartTicks
                }
                $script:StopRequested = $true
                Write-AcceptanceLifecycleTrace -Phase 'RESTART_STOP_REQUESTED'
                break
            }

            if (
                $request.Method -eq 'POST' -and
                $request.Path -in @('/api/lifecycle/stop', '/api/shutdown')
            ) {
                if (-not (Test-WriteAuthorization -Request $request)) {
                    Write-Json -Client $client -StatusCode 403 -Value @{
                        error = 'WRITE_AUTH_REQUIRED'
                    }
                    continue
                }

                Write-Json -Client $client -StatusCode 200 -Value @{
                    result = 'STOPPING'
                    pid = [int]$PID
                    processStartUtc = $serverStartUtc
                    processStartTicks = [int64]$serverStartTicks
                }
                $script:StopRequested = $true
                Write-AcceptanceLifecycleTrace -Phase 'STOP_REQUESTED'
                break
            }

            if (
                $request.Method -eq 'POST' -and
                $request.Path -eq '/api/prepare'
            ) {
                if (-not (Test-WriteAuthorization -Request $request)) {
                    Write-Json `
                        -Client $client `
                        -StatusCode 403 `
                        -Value @{
                            error = 'WRITE_AUTH_REQUIRED'
                        }

                    continue
                }

                $result = Invoke-PrepareAction

                Write-Json `
                    -Client $client `
                    -StatusCode 200 `
                    -Value $result

                continue
            }

            if (
                $request.Method -eq 'POST' -and
                $request.Path -eq '/api/burn'
            ) {
                if (-not (Test-WriteAuthorization -Request $request)) {
                    Write-Json `
                        -Client $client `
                        -StatusCode 403 `
                        -Value @{
                            error = 'WRITE_AUTH_REQUIRED'
                        }

                    continue
                }

                try {
                    $body = if (
                        [string]::IsNullOrWhiteSpace($request.Body)
                    ) {
                        @{}
                    }
                    else {
                        $request.Body | ConvertFrom-Json
                    }
                }
                catch {
                    Write-Json `
                        -Client $client `
                        -StatusCode 400 `
                        -Value @{
                            error = 'INVALID_JSON'
                        }

                    continue
                }

                $result = Invoke-BurnAction -Body $body

                Write-Json `
                    -Client $client `
                    -StatusCode 200 `
                    -Value $result

                continue
            }

            Write-Json `
                -Client $client `
                -StatusCode 404 `
                -Value @{
                    error = 'NOT_FOUND'
                }
        }
        catch {
            try {
                Write-Json `
                    -Client $client `
                    -StatusCode 500 `
                    -Value @{
                        error = 'SERVER_EXCEPTION'
                        message = $_.Exception.Message
                    }
            }
            catch {
            }
        }
        finally {
            Write-AcceptanceLifecycleTrace -Phase 'CLIENT_CLOSE_BEGIN'
            $client.Close()
            Write-AcceptanceLifecycleTrace -Phase 'CLIENT_CLOSE_PASS'
        }
    }
}
finally {
    try {
        Stop-ControlCenterListener -Reason 'FINALLY'
    }
    finally {
        Remove-OwnServerLifecycleLock
        Write-AcceptanceLifecycleTrace -Phase 'LOCK_REMOVE_PASS'
    }
}

Write-Output 'HARNESS CONTROL CENTER: STOPPED'
