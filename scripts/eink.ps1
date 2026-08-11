[CmdletBinding()]
param(
    [Parameter(Position = 0)]
    [ValidateSet('status', 'sync', 'next', 'closeout', 'home-verify')]
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
    param([switch]$StrictMain)

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

        $result = Invoke-ChildPowerShell -ScriptPath $guardScript -Arguments @('-ProfilePath', $activeProfile)
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
}
