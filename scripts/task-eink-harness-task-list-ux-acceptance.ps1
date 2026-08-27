[CmdletBinding()]
param()

$ErrorActionPreference = 'Stop'

$repoRoot = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path
$serverPath = Join-Path $repoRoot 'tools\harness\control-center\server.ps1'
$indexPath = Join-Path $repoRoot 'tools\harness\control-center\index.html'
$registryPath = Join-Path $repoRoot 'tools\harness\control-center\projects.json'
$runtimeRoot = Join-Path $repoRoot '_incoming\EINK_HARNESS_CONTROL_CENTER_RUNTIME'
$acceptanceRoot = Join-Path $repoRoot '_incoming\EINK_HARNESS_TASK_LIST_UX_ACCEPTANCE'
$runRoot = Join-Path $acceptanceRoot ([Guid]::NewGuid().ToString('N'))
$brainRoot = Join-Path $runRoot 'brain'
$currentPath = Join-Path $brainRoot 'current-task.json'
$historyPath = Join-Path $brainRoot 'history.jsonl'

function Assert-True {
    param(
        [Parameter(Mandatory=$true)][bool]$Condition,
        [Parameter(Mandatory=$true)][string]$Name
    )
    if (-not $Condition) { throw "ASSERT_FAIL: $Name" }
    Write-Output "$Name`: PASS"
}

function Write-Utf8Json {
    param([string]$Path, $Value)
    [IO.File]::WriteAllText(
        $Path,
        ($Value | ConvertTo-Json -Depth 12),
        [Text.UTF8Encoding]::new($false)
    )
}

function Append-Utf8JsonLine {
    param([string]$Path, $Value)
    [IO.File]::AppendAllText(
        $Path,
        (($Value | ConvertTo-Json -Depth 12 -Compress) + [Environment]::NewLine),
        [Text.UTF8Encoding]::new($false)
    )
}

function New-TaskRecord {
    param(
        [string]$TaskId,
        [string]$Status,
        [string]$Event = 'STATE'
    )
    [pscustomobject][ordered]@{
        schema = 'eink-brain-task-v1'
        taskId = $TaskId
        request = "Fixture request for $TaskId"
        event = $Event
        status = $Status
        createdUtc = '2026-08-27T00:00:00.0000000Z'
        updatedUtc = '2026-08-27T00:01:00.0000000Z'
        resumeCount = 0
        branchAtCreate = 'task/fixture'
        headAtCreate = '1111111111111111111111111111111111111111'
        exactFiles = @('docs/agent/CURRENT_STATE.md')
        contract = [ordered]@{
            schema = 'eink-task-contract-v1'
            taskId = $TaskId
            contractSha256 = ('A' * 64)
            exactScopeSha256 = ('B' * 64)
            allowedFiles = @('docs/agent/CURRENT_STATE.md')
            executionEligible = $false
            ownerExecutionRequired = $true
        }
        evidence = @(
            [ordered]@{
                kind = 'validation'
                result = 'PASS'
                path = '_incoming/fixture/evidence.json'
            }
        )
        audit = [ordered]@{
            source = 'task-list-ux-acceptance'
            immutable = $true
        }
    }
}

function Get-FreePort {
    $listener = [Net.Sockets.TcpListener]::new([Net.IPAddress]::Loopback, 0)
    $listener.Start()
    try { ([Net.IPEndPoint]$listener.LocalEndpoint).Port }
    finally { $listener.Stop() }
}

function Invoke-BrainAction {
    param(
        [int]$Port,
        [string]$Token,
        [string]$Action,
        $Body = @{}
    )
    Invoke-RestMethod `
        -Uri "http://127.0.0.1:$Port/api/projects/eink/actions/$Action" `
        -Method Post `
        -Headers @{ 'X-Eink-Control-Token' = $Token } `
        -ContentType 'application/json; charset=utf-8' `
        -Body ($Body | ConvertTo-Json -Depth 12 -Compress) `
        -TimeoutSec 15
}

function Get-DirectorySnapshot {
    param([string]$Root)
    if (-not (Test-Path -LiteralPath $Root)) { return '' }
    $fullRoot = [IO.Path]::GetFullPath($Root)
    @(
        Get-ChildItem -LiteralPath $Root -File -Recurse |
        Sort-Object FullName |
        ForEach-Object {
            $relative = $_.FullName.Substring($fullRoot.Length).TrimStart('\')
            $hash = (Get-FileHash -Algorithm SHA256 -LiteralPath $_.FullName).Hash
            "$relative|$($_.Length)|$hash"
        }
    ) -join "`n"
}

$realBranchBefore = (& git -C $repoRoot branch --show-current).Trim()
$realHeadBefore = (& git -C $repoRoot rev-parse HEAD).Trim()
$realStatusBefore = @(& git -C $repoRoot status --porcelain=v1 --untracked-files=all) -join "`n"
$productionBrainRoot = Join-Path $repoRoot '_incoming\EINK_HARNESS_BRAIN'
$productionBrainBefore = Get-DirectorySnapshot -Root $productionBrainRoot
$port = Get-FreePort
$process = $null
$token = ''

try {
    [void](New-Item -ItemType Directory -Path $brainRoot -Force)

    $closed = New-TaskRecord -TaskId 'EINK-TERMINAL-CLOSED' -Status 'CLOSED'
    $completed = New-TaskRecord -TaskId 'EINK-TERMINAL-COMPLETED' -Status 'COMPLETED'
    $nonTerminalStatuses = @(
        'COMPILED',
        'EXECUTING',
        'BLOCKED',
        'WAITING_OWNER',
        'OWNER_MERGE_REQUIRED',
        'READY'
    )
    $nonTerminal = @(
        foreach ($status in $nonTerminalStatuses) {
            New-TaskRecord -TaskId "EINK-NONTERMINAL-$status" -Status $status
        }
    )

    Write-Utf8Json -Path $currentPath -Value $closed
    foreach ($record in @($closed, $completed) + $nonTerminal) {
        Append-Utf8JsonLine -Path $historyPath -Value $record
    }
    $initialHistoryLines = [IO.File]::ReadAllLines($historyPath, [Text.Encoding]::UTF8)

    $stdout = Join-Path $runRoot 'server.stdout.log'
    $stderr = Join-Path $runRoot 'server.stderr.log'
    $arguments = @(
        '-NoProfile',
        '-ExecutionPolicy',
        'Bypass',
        '-File',
        "`"$serverPath`"",
        '-Port',
        [string]$port,
        '-NoBrowser',
        '-BrainAcceptanceRoot',
        "`"$brainRoot`""
    )
    $process = Start-Process `
        -FilePath 'powershell.exe' `
        -ArgumentList $arguments `
        -WindowStyle Hidden `
        -RedirectStandardOutput $stdout `
        -RedirectStandardError $stderr `
        -PassThru

    $hub = $null
    for ($i = 0; $i -lt 80; $i++) {
        Start-Sleep -Milliseconds 150
        if ($process.HasExited) { break }
        try {
            $hub = Invoke-RestMethod -Uri "http://127.0.0.1:$port/api/status" -TimeoutSec 2
            if ($hub.sessionToken) { break }
        }
        catch {}
    }
    if (-not $hub -or -not $hub.sessionToken) {
        $errorText = if (Test-Path -LiteralPath $stderr) {
            Get-Content -LiteralPath $stderr -Raw
        } else { '' }
        throw "ACCEPTANCE_SERVER_START_FAILED: $errorText"
    }
    $token = [string]$hub.sessionToken

    $status = Invoke-RestMethod -Uri "http://127.0.0.1:$port/api/projects/eink/status" -TimeoutSec 5
    Assert-True (@($status.brain.recentTasks).Count -eq 8) 'INITIAL_ACTIVE_TASKS_VISIBLE'
    Assert-True (@($status.brain.archivedTasks).Count -eq 0) 'INITIAL_ARCHIVED_TASKS_EMPTY'

    foreach ($state in $nonTerminalStatuses) {
        $blocked = Invoke-BrainAction `
            -Port $port `
            -Token $token `
            -Action 'brain-archive-arm' `
            -Body @{ taskId = "EINK-NONTERMINAL-$state" }
        Assert-True (
            -not [bool]$blocked.armed -and [string]$blocked.reason -eq 'TASK_NOT_TERMINAL'
        ) "NON_TERMINAL_ARCHIVE_BLOCKED_$state"
    }

    $closedArm = Invoke-BrainAction -Port $port -Token $token -Action 'brain-archive-arm' -Body @{ taskId = $closed.taskId }
    Assert-True ([bool]$closedArm.armed -and $closedArm.challenge) 'CLOSED_ARCHIVE_ARMED'

    $invalidConfirmation = Invoke-BrainAction `
        -Port $port `
        -Token $token `
        -Action 'brain-archive' `
        -Body @{ taskId = $closed.taskId }
    Assert-True (
        @($invalidConfirmation.brain.recentTasks.taskId) -contains $closed.taskId
    ) 'OWNER_CONFIRMATION_REQUIRED'

    $closedArm = Invoke-BrainAction -Port $port -Token $token -Action 'brain-archive-arm' -Body @{ taskId = $closed.taskId }
    $closedResult = Invoke-BrainAction `
        -Port $port `
        -Token $token `
        -Action 'brain-archive' `
        -Body @{ taskId = $closed.taskId; ownerChallenge = $closedArm.challenge }
    Assert-True (
        @($closedResult.brain.recentTasks.taskId) -notcontains $closed.taskId
    ) 'ARCHIVED_CLOSED_EXCLUDED_FROM_ACTIVE'
    Assert-True (
        @($closedResult.brain.archivedTasks.taskId) -contains $closed.taskId
    ) 'ARCHIVED_CLOSED_VISIBLE_IN_ARCHIVE'

    $completedArm = Invoke-BrainAction -Port $port -Token $token -Action 'brain-archive-arm' -Body @{ taskId = $completed.taskId }
    $completedResult = Invoke-BrainAction `
        -Port $port `
        -Token $token `
        -Action 'brain-archive' `
        -Body @{ taskId = $completed.taskId; ownerChallenge = $completedArm.challenge }
    Assert-True (
        @($completedResult.brain.recentTasks.taskId) -notcontains $completed.taskId -and
        @($completedResult.brain.archivedTasks.taskId) -contains $completed.taskId
    ) 'COMPLETED_ARCHIVE_PASS'

    $closedArchived = @(
        $completedResult.brain.archivedTasks |
        Where-Object { [string]$_.taskId -eq $closed.taskId }
    )[0]
    Assert-True (
        [string]$closedArchived.contract.contractSha256 -eq ('A' * 64) -and
        [string]$closedArchived.evidence[0].path -eq '_incoming/fixture/evidence.json' -and
        [bool]$closedArchived.audit.immutable
    ) 'ARCHIVED_AUDIT_CONTRACT_EVIDENCE_PRESERVED'

    $historyLines = [IO.File]::ReadAllLines($historyPath, [Text.Encoding]::UTF8)
    Assert-True (
        $historyLines.Count -eq ($initialHistoryLines.Count + 2)
    ) 'ARCHIVE_APPEND_ONLY_HISTORY'
    Assert-True (
        $historyLines[0] -eq $initialHistoryLines[0]
    ) 'ORIGINAL_HISTORY_RECORD_UNCHANGED'

    $createResult = Invoke-BrainAction `
        -Port $port `
        -Token $token `
        -Action 'brain-create' `
        -Body @{
            request = 'Documentation task for task-list UX acceptance.'
            exactFiles = @('docs/agent/CURRENT_STATE.md')
            resumeExistingEvidence = $false
        }
    $createdId = [string]$createResult.brain.currentTask.taskId
    Assert-True (-not [string]::IsNullOrWhiteSpace($createdId)) 'CREATE_CURRENT_TASK_SET'
    Assert-True (
        [string]$createResult.brain.recentTasks[0].taskId -eq $createdId
    ) 'CREATE_NEW_TASK_FIRST_ACTIVE'
    Assert-True (
        @($createResult.brain.archivedTasks).Count -eq 2
    ) 'CREATE_PRESERVES_ARCHIVED_TASKS'

    $serverText = [IO.File]::ReadAllText($serverPath, [Text.Encoding]::UTF8)
    $indexText = [IO.File]::ReadAllText($indexPath, [Text.Encoding]::UTF8)
    $registry = Get-Content -LiteralPath $registryPath -Raw -Encoding UTF8 | ConvertFrom-Json
    $actions = @($registry.projects[0].actions.id)
    Assert-True (
        $actions -contains 'brain-archive-arm' -and $actions -contains 'brain-archive'
    ) 'ARCHIVE_ACTION_ALLOW_LIST'
    Assert-True (
        $serverText.Contains("'CLOSED'") -and $serverText.Contains("'COMPLETED'") -and
        $serverText.Contains('TASK_NOT_TERMINAL') -and
        $serverText.Contains('Archived Brain task is read-only and cannot be compiled.')
    ) 'TERMINAL_STATE_BACKEND_GATE'
    Assert-True (
        $indexText.Contains('id="einkBrainShowArchived"') -and
        $indexText.Contains('[...activeTasks, ...archivedTasks]')
    ) 'SHOW_ARCHIVED_UI_WIRING'
    Assert-True (
        $indexText.Contains('const createdTaskId = result?.brain?.currentTask?.taskId') -and
        $indexText.Contains('$("einkBrainHistorySelect").value = createdTaskId')
    ) 'CREATE_AUTO_SELECT_UI_WIRING'
    $contractOpening = [regex]::Match(
        $indexText,
        '<details[^>]*id="einkBrainContractVisualizer"[^>]*>'
    )
    $contractSummary = 'Chi ti' + [char]0x1EBF + 't Contract'
    Assert-True (
        $contractOpening.Success -and
        $indexText.Contains("<summary>$contractSummary</summary>")
    ) 'CONTRACT_DETAILS_DISCLOSURE'
    Assert-True ($contractOpening.Value -notmatch '\sopen(?:\s|=|>)') 'CONTRACT_DETAILS_COLLAPSED_DEFAULT'
    Assert-True (
        $indexText.Contains('<details class="contract-raw">') -and
        $indexText.Contains('visualizer.open = false')
    ) 'CONTRACT_NESTED_RAW_AND_COLLAPSE_WIRING'
    foreach ($marker in @(
        'brain-create',
        'brain-resume',
        'brain-compile',
        'brain-execute-arm',
        'brain-execute',
        'RUN COMPILED TASK',
        'START HARNESS'
    )) {
        Assert-True ($indexText.Contains($marker) -or $serverText.Contains($marker)) "EXISTING_ACTION_PRESERVED_$marker"
    }

    Write-Output 'EINK HARNESS TASK-LIST UX ACCEPTANCE: PASS'
}
finally {
    if ($process -and -not $process.HasExited) {
        try {
            Invoke-RestMethod `
                -Uri "http://127.0.0.1:$port/api/lifecycle/stop" `
                -Method Post `
                -Headers @{ 'X-Eink-Control-Token' = $token } `
                -ContentType 'application/json' `
                -Body '{}' `
                -TimeoutSec 3 |
                Out-Null
        }
        catch {}
        [void]$process.WaitForExit(5000)
        if (-not $process.HasExited) {
            Stop-Process -Id $process.Id -Force
            [void]$process.WaitForExit(5000)
        }
    }

    $lockPath = Join-Path $runtimeRoot "server-$port.json"
    if (Test-Path -LiteralPath $lockPath) {
        Remove-Item -LiteralPath $lockPath -Force
    }

    $realBranchAfter = (& git -C $repoRoot branch --show-current).Trim()
    $realHeadAfter = (& git -C $repoRoot rev-parse HEAD).Trim()
    $realStatusAfter = @(& git -C $repoRoot status --porcelain=v1 --untracked-files=all) -join "`n"
    $productionBrainAfter = Get-DirectorySnapshot -Root $productionBrainRoot

    Assert-True ($realBranchAfter -eq $realBranchBefore) 'REAL_BRANCH_PRESERVED'
    Assert-True ($realHeadAfter -eq $realHeadBefore) 'REAL_HEAD_PRESERVED'
    Assert-True ($realStatusAfter -eq $realStatusBefore) 'REAL_WORKTREE_STATUS_PRESERVED'
    Assert-True ($productionBrainAfter -eq $productionBrainBefore) 'PRODUCTION_BRAIN_STORE_UNCHANGED'

    if (Test-Path -LiteralPath $runRoot) {
        $resolvedRun = [IO.Path]::GetFullPath($runRoot)
        $resolvedAcceptance = [IO.Path]::GetFullPath($acceptanceRoot).TrimEnd('\') + '\'
        if (-not $resolvedRun.StartsWith($resolvedAcceptance, [StringComparison]::OrdinalIgnoreCase)) {
            throw 'REFUSING_UNSAFE_ACCEPTANCE_CLEANUP'
        }
        Remove-Item -LiteralPath $resolvedRun -Recurse -Force
    }
}
