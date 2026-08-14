[CmdletBinding()]
param(
    [Parameter(Position = 0)]
    [ValidateSet('status', 'sync', 'next', 'closeout', 'home-verify', 'build')]
    [string]$Action = 'status',

    [switch]$DryRun,

    [Parameter(DontShow = $true)]
    [string]$HomeFlashScriptPath
)

$ErrorActionPreference = 'Stop'

$repoRoot = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path
$guardScript = Join-Path $repoRoot 'tools\harness\workspace-guard.ps1'
$taskStateScript = Join-Path $repoRoot 'tools\harness\task-state.ps1'
$profilePath = Join-Path $repoRoot 'tools\harness\eink-profile.json'
$nextActionPath = Join-Path $repoRoot 'docs\agent\NEXT_ACTION.md'

if ([string]::IsNullOrWhiteSpace($HomeFlashScriptPath)) {
    $HomeFlashScriptPath = Join-Path $repoRoot 'scripts\eink-home-flash.ps1'
}

function Invoke-ChildPowerShell {
    param(
        [Parameter(Mandatory = $true)]
        [string]$ScriptPath,

        [string[]]$Arguments = @()
    )

    $commandArguments = @('-NoProfile', '-ExecutionPolicy', 'Bypass', '-File', $ScriptPath) + $Arguments
    $output = @(& powershell.exe @commandArguments 2>&1 | ForEach-Object { $_.ToString() })
    return [pscustomobject]@{
        ExitCode = $LASTEXITCODE
        Output = $output
    }
}

function Invoke-GitCommand {
    param(
        [Parameter(Mandatory = $true)]
        [string[]]$Arguments
    )

    # Windows PowerShell 5.1 may promote normal native stderr output
    # (for example git fetch progress) to NativeCommandError when
    # ErrorActionPreference is Stop and stderr is merged with stdout.
    #
    # Treat the native process exit code as the source of truth.
    $previousErrorActionPreference = $ErrorActionPreference

    try {
        $ErrorActionPreference = 'Continue'

        $output = @(
            & git @Arguments 2>&1 |
                ForEach-Object { $_.ToString() }
        )

        $exitCode = $LASTEXITCODE
    }
    finally {
        $ErrorActionPreference = $previousErrorActionPreference
    }

    return [pscustomobject]@{
        ExitCode = $exitCode
        Output = $output
    }
}

function ConvertFrom-JsonOutput {
    param([string[]]$Output)

    if ($Output.Count -eq 0) {
        return $null
    }

    try {
        return (($Output -join [Environment]::NewLine) | ConvertFrom-Json)
    }
    catch {
        return $null
    }
}

function Get-CurrentBranch {
    $result = Invoke-GitCommand -Arguments @('branch', '--show-current')
    if ($result.ExitCode -ne 0 -or $result.Output.Count -eq 0) {
        return ''
    }

    return $result.Output[-1].Trim()
}

function New-RunnerGuardProfile {
    param([string]$Branch)

    $profile = Get-Content -LiteralPath $profilePath -Raw | ConvertFrom-Json
    $profile.workspace.defaultBranch = $Branch
    $profile.workspace.requireHeadEqualsOriginMain = $false

    $temporaryPath = [System.IO.Path]::GetTempFileName()
    [System.IO.File]::WriteAllText(
        $temporaryPath,
        ($profile | ConvertTo-Json -Depth 16),
        [System.Text.UTF8Encoding]::new($false)
    )
    return $temporaryPath
}

function Invoke-WorkspaceGuard {
    param(
        [switch]$StrictMain,
        [switch]$AllowDirtyTrackedTree
    )

    $activeProfile = $profilePath
    $temporaryProfile = $null

    try {
        if (-not $StrictMain) {
            $branch = Get-CurrentBranch
            if ([string]::IsNullOrWhiteSpace($branch)) {
                return [pscustomobject]@{
                    ExitCode = 1
                    Data = $null
                    Raw = @('Unable to determine the current branch.')
                }
            }
            $temporaryProfile = New-RunnerGuardProfile -Branch $branch
            $activeProfile = $temporaryProfile
        }

        $guardArguments = @('-ProfilePath', $activeProfile)
        if ($AllowDirtyTrackedTree) {
            $guardArguments += '-AllowDirtyTrackedTree'
        }
        $result = Invoke-ChildPowerShell -ScriptPath $guardScript -Arguments $guardArguments
        return [pscustomobject]@{
            ExitCode = $result.ExitCode
            Data = ConvertFrom-JsonOutput -Output $result.Output
            Raw = $result.Output
        }
    }
    finally {
        if ($temporaryProfile -and (Test-Path -LiteralPath $temporaryProfile)) {
            Remove-Item -LiteralPath $temporaryProfile -Force
        }
    }
}

function Get-GuardBlockReason {
    param($Guard)

    if ($Guard.Data -and @($Guard.Data.tracked_entries).Count -gt 0) {
        return 'DIRTY_TRACKED_TREE'
    }
    if ($Guard.Data -and @($Guard.Data.errors) -match 'origin/main') {
        return 'MAIN_NOT_SYNCED'
    }
    if ($Guard.Data -and @($Guard.Data.errors) -match 'workspace|Git root|origin') {
        return 'WORKSPACE_GUARD_FAILED'
    }
    return 'WORKSPACE_GUARD_FAILED'
}

function Assert-TaskState {
    param([string]$State)

    $result = Invoke-ChildPowerShell -ScriptPath $taskStateScript -Arguments @(
        '-Action', 'Validate',
        '-State', $State
    )
    return ($result.ExitCode -eq 0)
}

function Write-Result {
    param(
        [Parameter(Mandatory = $true)]
        [ValidateSet('PASS', 'BLOCKED')]
        [string]$Result,

        [Parameter(Mandatory = $true)]
        [string]$ActionName,

        [string]$Branch = '-',
        [string]$Head = '-',
        [string]$NextState = '-',
        [string]$Reason = '',
        [string]$Detail = ''
    )

    Write-Output "EINK HARNESS: $Result"
    Write-Output "ACTION: $ActionName"
    Write-Output "BRANCH: $Branch"
    Write-Output "HEAD: $Head"
    if ($Reason) {
        Write-Output "REASON: $Reason"
    }
    if ($Detail) {
        Write-Output $Detail
    }
    Write-Output "NEXT_STATE: $NextState"
}

function Get-NextActionSummary {
    $content = Get-Content -LiteralPath $nextActionPath -Raw
    $match = [regex]::Match(
        $content,
        '(?ms)^## Next Canonical Action\s*\r?\n(?<body>.*?)(?=^## |\z)'
    )

    if (-not $match.Success) {
        return [pscustomobject]@{
            IsUnresolved = $true
            Summary = 'UNRESOLVED - requires Owner selection.'
        }
    }

    $lines = @($match.Groups['body'].Value -split '\r?\n' | ForEach-Object { $_.Trim() } | Where-Object { $_ })
    $summary = if ($lines.Count -gt 0) { $lines[0] } else { 'UNRESOLVED - requires Owner selection.' }
    return [pscustomobject]@{
        IsUnresolved = ($match.Groups['body'].Value -match '(?i)\bUNRESOLVED\b')
        Summary = $summary
    }
}

function Invoke-SyncImplementation {
    param([switch]$WhatIfOnly)

    $initialGuard = Invoke-WorkspaceGuard
    if ($initialGuard.ExitCode -ne 0) {
        return [pscustomobject]@{
            Passed = $false
            Reason = Get-GuardBlockReason -Guard $initialGuard
            Guard = $initialGuard
        }
    }

    if ($WhatIfOnly) {
        $strictGuard = Invoke-WorkspaceGuard -StrictMain
        return [pscustomobject]@{
            Passed = ($strictGuard.ExitCode -eq 0)
            Reason = if ($strictGuard.ExitCode -eq 0) { 'ALREADY_CURRENT_DRY_RUN' } else { Get-GuardBlockReason -Guard $strictGuard }
            Guard = $strictGuard
        }
    }

    foreach ($gitArguments in @(
        @('fetch', 'origin'),
        @('switch', 'main'),
        @('pull', '--ff-only', 'origin', 'main')
    )) {
        $gitResult = Invoke-GitCommand -Arguments $gitArguments
        if ($gitResult.ExitCode -ne 0) {
            return [pscustomobject]@{
                Passed = $false
                Reason = 'GIT_SYNC_FAILED'
                Guard = $initialGuard
            }
        }
    }

    $finalGuard = Invoke-WorkspaceGuard -StrictMain
    return [pscustomobject]@{
        Passed = ($finalGuard.ExitCode -eq 0)
        Reason = if ($finalGuard.ExitCode -eq 0) { 'SYNCED' } else { Get-GuardBlockReason -Guard $finalGuard }
        Guard = $finalGuard
    }
}

function Write-BuildFailure {
    param([Parameter(Mandatory = $true)][string]$Reason)

    Write-Output 'EINK HARNESS: BLOCKED'
    Write-Output 'ACTION: BUILD'
    Write-Output "REASON: $Reason"
}

function Test-BuildGuard {
    param([Parameter(Mandatory = $true)]$Guard)

    if ($Guard.ExitCode -eq 0) {
        return $true
    }

    $errors = @($Guard.Data.errors)
    return ($errors.Count -eq 1 -and [string]$errors[0] -eq 'DIRTY_TRACKED_TREE')
}

function Invoke-BuildImplementation {
    $guard = Invoke-WorkspaceGuard -AllowDirtyTrackedTree
    if (-not (Test-BuildGuard -Guard $guard)) {
        Write-BuildFailure -Reason (Get-GuardBlockReason -Guard $guard)
        return 1
    }

    $profile = Get-Content -LiteralPath $ProfilePath -Raw | ConvertFrom-Json
    $toolchain = $profile.toolchain
    $requiredPaths = @(
        [string]$toolchain.sdkPath,
        [string]$toolchain.canonicalSource,
        (Join-Path $RepoRoot ([string]$toolchain.bootstrapScript)),
        [string]$toolchain.keilCli,
        [string]$toolchain.toolsIni,
        [string]$toolchain.compilerExecutable,
        [string]$toolchain.projectFile
    )

    foreach ($requiredPath in $requiredPaths) {
        if ([string]::IsNullOrWhiteSpace($requiredPath) -or -not (Test-Path -LiteralPath $requiredPath)) {
            Write-BuildFailure -Reason "MISSING_DEPENDENCY: $requiredPath"
            return 1
        }
    }

    $toolsIniText = Get-Content -LiteralPath ([string]$toolchain.toolsIni) -Raw
    if ($toolsIniText -notmatch 'DEFAULT_ARMCC_VERSION_AC6\s*=\s*"V6\.24"' -or
        $toolsIniText -notmatch 'ARMCCPATH0') {
        Write-BuildFailure -Reason 'KEIL_TOOLCHAIN_MISMATCH'
        return 1
    }

    $projectText = Get-Content -LiteralPath ([string]$toolchain.projectFile) -Raw
    if ($projectText -notmatch '<TargetName>DA14585</TargetName>' -or
        $projectText -notmatch 'V6\.24') {
        Write-BuildFailure -Reason 'KEIL_PROJECT_MISMATCH'
        return 1
    }

    $bootstrapPath = Join-Path $RepoRoot ([string]$toolchain.bootstrapScript)
    $bootstrap = Invoke-ChildPowerShell -ScriptPath $bootstrapPath -Arguments @()
    if ($bootstrap.ExitCode -ne 0) {
        Write-BuildFailure -Reason 'BOOTSTRAP_FAILED'
        return 1
    }

    $stamp = Get-Date -Format 'yyyyMMdd_HHmmss'
    $evidenceDir = Join-Path ([string]$toolchain.buildEvidenceRoot) $stamp
    [void](New-Item -ItemType Directory -Path $evidenceDir -Force)
    $buildLog = Join-Path $evidenceDir 'keil-build.log'
    $buildStartedUtc = [DateTime]::UtcNow

    $processArguments = @(
        '-j0',
        '-r', "`"$([string]$toolchain.projectFile)`"",
        '-t', "`"$([string]$toolchain.target)`"",
        '-o', "`"$buildLog`""
    )
    try {
        $process = Start-Process `
            -FilePath ([string]$toolchain.keilCli) `
            -ArgumentList $processArguments `
            -Wait `
            -PassThru
    }
    catch {
        Write-BuildFailure -Reason 'KEIL_PROCESS_EXCEPTION'
        return 1
    }

    if ($null -ne $process.ExitCode -and $process.ExitCode -ne 0) {
        Write-BuildFailure -Reason "KEIL_EXIT_$($process.ExitCode)"
        return 1
    }
    if (-not (Test-Path -LiteralPath $buildLog -PathType Leaf)) {
        Write-BuildFailure -Reason 'BUILD_LOG_MISSING'
        return 1
    }

    $buildText = Get-Content -LiteralPath $buildLog -Raw
    if ($buildText -match '(?i)not supported by Toolchain') {
        Write-BuildFailure -Reason 'KEIL_TOOLCHAIN_UNSUPPORTED'
        return 1
    }

    if ($buildText -match '(?i)ArmCC|CreateProcess|Target not created') {
        Write-BuildFailure -Reason 'BUILD_LOG_FATAL'
        return 1
    }

    $compilerMarker = "Using Compiler '$([string]$toolchain.compilerVersion)'"
    if ($buildText.IndexOf($compilerMarker, [System.StringComparison]::OrdinalIgnoreCase) -lt 0) {
        Write-BuildFailure -Reason 'KEIL_COMPILER_NOT_CONFIRMED'
        return 1
    }
    $resultMatch = [regex]::Match($buildText, '(\d+)\s+Error\(s\),\s+(\d+)\s+Warning\(s\)\.')
    if (-not $resultMatch.Success -or
        [int]$resultMatch.Groups[1].Value -ne 0 -or
        [int]$resultMatch.Groups[2].Value -ne 0) {
        Write-BuildFailure -Reason 'BUILD_ERRORS_OR_WARNINGS'
        return 1
    }

    $rawBin = [string]$toolchain.rawBin
    if (-not (Test-Path -LiteralPath $rawBin -PathType Leaf)) {
        Write-BuildFailure -Reason 'RAW_BIN_MISSING'
        return 1
    }
    $rawFile = Get-Item -LiteralPath $rawBin
    if ($rawFile.LastWriteTimeUtc -lt $buildStartedUtc.AddSeconds(-2)) {
        Write-BuildFailure -Reason 'RAW_BIN_STALE'
        return 1
    }
    if ($rawFile.Length -le 0 -or $rawFile.Length -gt [int64]$profile.artifactPolicy.rawBinMaxBytes) {
        Write-BuildFailure -Reason "RAW_BIN_SIZE_$($rawFile.Length)"
        return 1
    }

    $rawStream = $null
    $sha256 = $null
    try {
        $rawStream = [System.IO.File]::OpenRead($rawBin)
        $sha256 = [System.Security.Cryptography.SHA256]::Create()
        $rawHashBytes = $sha256.ComputeHash($rawStream)
        $rawHash = ([System.BitConverter]::ToString($rawHashBytes)).Replace('-', '').ToUpperInvariant()
    }
    finally {
        if ($null -ne $sha256) {
            $sha256.Dispose()
        }
        if ($null -ne $rawStream) {
            $rawStream.Dispose()
        }
    }
    Write-Output 'EINK HARNESS: PASS'
    Write-Output 'ACTION: BUILD'
    Write-Output "TARGET: $($toolchain.target)"
    Write-Output "COMPILER: $($toolchain.compilerVersion)"
    Write-Output "RAW_BIN: $rawBin"
    Write-Output "RAW_SIZE: $($rawFile.Length)"
    Write-Output "RAW_SHA256: $rawHash"
    Write-Output "BUILD_LOG: $buildLog"
    Write-Output 'NEXT_STATE: RAW_FIRMWARE_VERIFIED'
    return 0
}

$actionName = $Action.ToUpperInvariant()

switch ($Action) {
    'status' {
        $guard = Invoke-WorkspaceGuard
        if ($guard.ExitCode -ne 0) {
            Write-Result -Result BLOCKED -ActionName $actionName -Reason (Get-GuardBlockReason -Guard $guard) -NextState BLOCKED
            exit 1
        }

        if (-not (Assert-TaskState -State 'WORKSPACE_VERIFIED')) {
            Write-Result -Result BLOCKED -ActionName $actionName -Branch $guard.Data.branch -Head $guard.Data.head -Reason 'TASK_STATE_INVALID' -NextState BLOCKED
            exit 1
        }

        $next = Get-NextActionSummary
        $nextState = if ($next.IsUnresolved) { 'PAUSED_OWNER_ACTION' } else { 'TASK_SELECTED' }
        Write-Result -Result PASS -ActionName $actionName -Branch $guard.Data.branch -Head $guard.Data.head -NextState $nextState -Detail "DIRTY_TRACKED: $(@($guard.Data.tracked_entries).Count); UNTRACKED: $($guard.Data.untracked_count)"
        exit 0
    }

    'sync' {
        $syncResult = Invoke-SyncImplementation -WhatIfOnly:$DryRun
        if (-not $syncResult.Passed) {
            $branch = if ($syncResult.Guard.Data) { $syncResult.Guard.Data.branch } else { Get-CurrentBranch }
            $head = if ($syncResult.Guard.Data) { $syncResult.Guard.Data.head } else { '-' }
            Write-Result -Result BLOCKED -ActionName $actionName -Branch $branch -Head $head -Reason $syncResult.Reason -NextState BLOCKED
            exit 1
        }

        Write-Result -Result PASS -ActionName $actionName -Branch $syncResult.Guard.Data.branch -Head $syncResult.Guard.Data.head -NextState WORKSPACE_VERIFIED -Detail "SYNC_RESULT: $($syncResult.Reason)"
        exit 0
    }

    'next' {
        $guard = Invoke-WorkspaceGuard
        if ($guard.ExitCode -ne 0) {
            Write-Result -Result BLOCKED -ActionName $actionName -Reason (Get-GuardBlockReason -Guard $guard) -NextState BLOCKED
            exit 1
        }

        $next = Get-NextActionSummary
        if ($next.IsUnresolved) {
            if (-not (Assert-TaskState -State 'PAUSED_OWNER_ACTION')) {
                Write-Result -Result BLOCKED -ActionName $actionName -Branch $guard.Data.branch -Head $guard.Data.head -Reason 'TASK_STATE_INVALID' -NextState BLOCKED
                exit 1
            }
            Write-Result -Result BLOCKED -ActionName $actionName -Branch $guard.Data.branch -Head $guard.Data.head -Reason 'OWNER_SELECTION_REQUIRED' -NextState PAUSED_OWNER_ACTION -Detail "NEXT_ACTION: $($next.Summary)"
            exit 2
        }

        if (-not (Assert-TaskState -State 'TASK_SELECTED')) {
            Write-Result -Result BLOCKED -ActionName $actionName -Branch $guard.Data.branch -Head $guard.Data.head -Reason 'TASK_STATE_INVALID' -NextState BLOCKED
            exit 1
        }
        Write-Result -Result PASS -ActionName $actionName -Branch $guard.Data.branch -Head $guard.Data.head -NextState TASK_SELECTED -Detail "NEXT_ACTION: $($next.Summary)"
        exit 0
    }

    'closeout' {
        $guard = Invoke-WorkspaceGuard
        if ($guard.ExitCode -ne 0) {
            Write-Result -Result BLOCKED -ActionName $actionName -Reason (Get-GuardBlockReason -Guard $guard) -NextState BLOCKED
            exit 1
        }

        $sourceBranch = $guard.Data.branch
        $sourceHead = $guard.Data.head
        $syncResult = Invoke-SyncImplementation -WhatIfOnly:$DryRun
        if (-not $syncResult.Passed) {
            Write-Result -Result BLOCKED -ActionName $actionName -Branch $sourceBranch -Head $sourceHead -Reason $syncResult.Reason -NextState BLOCKED
            exit 1
        }

        if ($sourceBranch -eq 'main') {
            Write-Result -Result BLOCKED -ActionName $actionName -Branch $syncResult.Guard.Data.branch -Head $syncResult.Guard.Data.head -Reason 'MERGE_EVIDENCE_REQUIRED' -NextState WORKSPACE_VERIFIED
            exit 2
        }

        $ancestor = Invoke-GitCommand -Arguments @('merge-base', '--is-ancestor', $sourceHead, 'main')
        if ($ancestor.ExitCode -ne 0) {
            Write-Result -Result BLOCKED -ActionName $actionName -Branch $syncResult.Guard.Data.branch -Head $syncResult.Guard.Data.head -Reason 'MERGE_NOT_PROVABLE' -NextState OWNER_MERGE_REQUIRED
            exit 2
        }

        if (-not (Assert-TaskState -State 'CLOSED')) {
            Write-Result -Result BLOCKED -ActionName $actionName -Branch $syncResult.Guard.Data.branch -Head $syncResult.Guard.Data.head -Reason 'TASK_STATE_INVALID' -NextState BLOCKED
            exit 1
        }
        Write-Result -Result PASS -ActionName $actionName -Branch $syncResult.Guard.Data.branch -Head $syncResult.Guard.Data.head -NextState CLOSED -Detail "MERGED_SOURCE_HEAD: $sourceHead"
        exit 0
    }

    'home-verify' {
        $guard = Invoke-WorkspaceGuard
        if ($guard.ExitCode -ne 0) {
            Write-Result -Result BLOCKED -ActionName $actionName -Reason (Get-GuardBlockReason -Guard $guard) -NextState BLOCKED
            exit 1
        }

        $verifyResult = Invoke-ChildPowerShell -ScriptPath $HomeFlashScriptPath -Arguments @('-Mode', 'VerifyEnv')
        if ($verifyResult.ExitCode -ne 0) {
            $lastLine = if ($verifyResult.Output.Count -gt 0) { $verifyResult.Output[-1] } else { 'Environment verification failed.' }
            Write-Result -Result BLOCKED -ActionName $actionName -Branch $guard.Data.branch -Head $guard.Data.head -Reason 'HOME_ENV_VERIFY_FAILED' -NextState BLOCKED -Detail "DETAIL: $lastLine"
            exit 1
        }

        Write-Result -Result PASS -ActionName $actionName -Branch $guard.Data.branch -Head $guard.Data.head -NextState WORKSPACE_VERIFIED -Detail 'HOME_VERIFY: PASS'
        exit 0
    }
    'build' {
        $buildResult = @(Invoke-BuildImplementation)
        if ($buildResult.Count -eq 0) {
            Write-BuildFailure -Reason 'BUILD_RESULT_MISSING'
            exit 1
        }
        if ($buildResult.Count -gt 1) {
            $buildResult[0..($buildResult.Count - 2)] | Write-Output
        }
        exit [int]$buildResult[-1]
    }
}
