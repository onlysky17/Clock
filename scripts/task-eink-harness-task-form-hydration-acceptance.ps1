[CmdletBinding()]
param()

$ErrorActionPreference = 'Stop'

$repoRoot = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path
$indexPath = Join-Path $repoRoot 'tools\harness\control-center\index.html'
$serverPath = Join-Path $repoRoot 'tools\harness\control-center\server.ps1'
$productionBrainRoot = Join-Path $repoRoot '_incoming\EINK_HARNESS_BRAIN'
$acceptanceRoot = Join-Path $repoRoot '_incoming\EINK_HARNESS_TASK_FORM_HYDRATION_ACCEPTANCE'
$runRoot = Join-Path $acceptanceRoot ([Guid]::NewGuid().ToString('N'))
$brainRoot = Join-Path $runRoot 'brain'

function Assert-True {
    param(
        [Parameter(Mandatory=$true)][bool]$Condition,
        [Parameter(Mandatory=$true)][string]$Name
    )

    if (-not $Condition) {
        throw "ASSERT_FAIL: $Name"
    }
    Write-Output "$Name`: PASS"
}

function Get-FreeLoopbackPort {
    $listener = [Net.Sockets.TcpListener]::new(
        [Net.IPAddress]::Loopback,
        0
    )
    $listener.Start()
    try {
        ([Net.IPEndPoint]$listener.LocalEndpoint).Port
    }
    finally {
        $listener.Stop()
    }
}

function Get-FileSha256OrMissing {
    param([Parameter(Mandatory=$true)][string]$Path)

    if (-not (Test-Path -LiteralPath $Path -PathType Leaf)) {
        return 'MISSING'
    }

    $sha = [Security.Cryptography.SHA256]::Create()
    $stream = [IO.File]::OpenRead($Path)
    try {
        [BitConverter]::ToString(
            $sha.ComputeHash($stream)
        ).Replace('-','')
    }
    finally {
        $stream.Dispose()
        $sha.Dispose()
    }
}

function Invoke-BrainAction {
    param(
        [Parameter(Mandatory=$true)][int]$Port,
        [Parameter(Mandatory=$true)][string]$Token,
        [Parameter(Mandatory=$true)][string]$Action,
        [Parameter(Mandatory=$true)]$Body
    )

    Invoke-RestMethod `
        -Uri "http://127.0.0.1:$Port/api/projects/eink/actions/$Action" `
        -Method Post `
        -Headers @{ 'X-Eink-Control-Token' = $Token } `
        -ContentType 'application/json; charset=utf-8' `
        -Body ($Body | ConvertTo-Json -Depth 8) `
        -TimeoutSec 10
}

$realStatusBefore = @(& git -C $repoRoot status --short --untracked-files=all)
$realBranchBefore = (@(& git -C $repoRoot branch --show-current) -join '').Trim()
$realHeadBefore = (& git -C $repoRoot rev-parse HEAD).Trim()
$productionCurrentPath = Join-Path $productionBrainRoot 'current-task.json'
$productionHistoryPath = Join-Path $productionBrainRoot 'history.jsonl'
$productionCurrentBefore = Get-FileSha256OrMissing -Path $productionCurrentPath
$productionHistoryBefore = Get-FileSha256OrMissing -Path $productionHistoryPath
$serverPowerShell = $null
$serverAsync = $null

try {
    [void](New-Item -ItemType Directory -Path $brainRoot -Force)

    foreach ($path in @($serverPath, $PSCommandPath)) {
        $tokens = $null
        $errors = $null
        [void][Management.Automation.Language.Parser]::ParseFile(
            $path,
            [ref]$tokens,
            [ref]$errors
        )
        Assert-True (@($errors).Count -eq 0) (
            'POWERSHELL_PARSE_' +
            [IO.Path]::GetFileName($path).ToUpperInvariant()
        )
    }

    $index = [IO.File]::ReadAllText($indexPath, [Text.Encoding]::UTF8)
    $scripts = @(
        [regex]::Matches(
            $index,
            '<script[^>]*>([\s\S]*?)</script>',
            [Text.RegularExpressions.RegexOptions]::IgnoreCase
        ) | ForEach-Object { $_.Groups[1].Value }
    )
    Assert-True ($scripts.Count -gt 0) 'INLINE_SCRIPT_PRESENT'
    $inlinePath = Join-Path $runRoot 'control-center-inline.js'
    [IO.File]::WriteAllText(
        $inlinePath,
        ($scripts -join "`n"),
        [Text.UTF8Encoding]::new($false)
    )
    $parseOutput = @(& node --check $inlinePath 2>&1)
    Assert-True ($LASTEXITCODE -eq 0) 'INLINE_JAVASCRIPT_PARSE'

    Assert-True (
        $index.Contains('function hydrateEinkBrainTaskForm') -and
        $index.Contains('function hydrateEinkBrainCurrentTask') -and
        $index.Contains('function hydrateEinkBrainSelectedTask')
    ) 'HYDRATION_HELPERS_PRESENT'
    Assert-True (
        $index.Contains('(!force && einkBrainFormDirty)') -and
        $index.Contains('einkBrainFormDirty = true;')
    ) 'OWNER_DRAFT_PRESERVED_FROM_BACKGROUND_RENDER'
    Assert-True (
        $index.Contains('getEinkBrainTaskExactFiles(task).join("\n")')
    ) 'EXACT_FILES_ONE_PATH_PER_LINE'
    Assert-True (
        $index -match 'hydrateEinkBrainTaskForm[\s\S]*resizeEinkBrainRequest\(\);'
    ) 'REQUEST_AUTOGROW_AFTER_HYDRATION'
    Assert-True (
        $index -notmatch '\$\("einkBrainRequest"\)\.value\s*=\s*""' -and
        $index -notmatch '\$\("einkBrainExactFilesInput"\)\.value\s*=\s*""'
    ) 'CREATE_NO_LONGER_CLEARS_TASK_FORM'
    Assert-True (
        $index -match 'brain-create[\s\S]{0,1600}hydrateEinkBrainCurrentTask\(result, \{ force: true \}\)'
    ) 'CREATE_HYDRATES_AUTHORITATIVE_CURRENT_TASK'
    Assert-True (
        $index -match 'einkBrainHistorySelect"\)\.addEventListener\("change"[\s\S]{0,500}hydrateEinkBrainSelectedTask'
    ) 'SELECT_HYDRATES_SELECTED_TASK'
    Assert-True (
        $index -match 'brain-resume[\s\S]{0,500}hydrateEinkBrainCurrentTask\(result, \{ force: true \}\)'
    ) 'RESUME_HYDRATES_RESUMED_TASK'
    Assert-True (
        $index.Contains('async function refresh({ hydrateCurrentTask = false } = {})') -and
        $index.Contains('refresh({ hydrateCurrentTask: true });') -and
        $index.Contains('if (!einkBrainFormInitialized)')
    ) 'REFRESH_AND_INITIAL_LOAD_HYDRATION'
    Assert-True (
        $index -match 'window\.setInterval\(\(\) => \{[\s\S]{0,200}refresh\(\);'
    ) 'BACKGROUND_POLLING_DOES_NOT_FORCE_HYDRATION'

    $port = Get-FreeLoopbackPort
    $serverPowerShell = [PowerShell]::Create()
    [void]$serverPowerShell.AddScript({
        param($Server, $Port, $BrainRoot)
        & $Server `
            -Port $Port `
            -NoBrowser `
            -BrainAcceptanceRoot $BrainRoot
    }).AddArgument($serverPath).AddArgument($port).AddArgument($brainRoot)
    $serverAsync = $serverPowerShell.BeginInvoke()

    $hub = $null
    for ($attempt = 0; $attempt -lt 60; $attempt++) {
        Start-Sleep -Milliseconds 200
        if ($serverAsync.IsCompleted) { break }
        try {
            $hub = Invoke-RestMethod `
                -Uri "http://127.0.0.1:$port/api/status" `
                -TimeoutSec 2
            if ($hub.sessionToken) { break }
        }
        catch {}
    }
    if (-not $hub -or -not $hub.sessionToken) {
        $errors = @($serverPowerShell.Streams.Error | ForEach-Object {
            $_.ToString()
        }) -join "`n"
        throw "HYDRATION_ACCEPTANCE_SERVER_START_FAILED: $errors"
    }

    $requestA = "HARNESS hydration fixture A`nSecond line A"
    $filesA = @(
        'tools/harness/control-center/index.html',
        'scripts/task-eink-harness-task-form-hydration-acceptance.ps1'
    )
    $createA = Invoke-BrainAction `
        -Port $port `
        -Token ([string]$hub.sessionToken) `
        -Action 'brain-create' `
        -Body @{ request = $requestA; exactFiles = $filesA }
    $taskA = $createA.brain.currentTask
    Assert-True (
        [string]$taskA.request -eq $requestA -and
        @($taskA.exactFiles).Count -eq 2
    ) 'CREATE_RESPONSE_PERSISTS_FORM_DATA'

    $requestB = "HARNESS hydration fixture B`nSecond line B"
    $filesB = @('tools/harness/control-center/index.html')
    $createB = Invoke-BrainAction `
        -Port $port `
        -Token ([string]$hub.sessionToken) `
        -Action 'brain-create' `
        -Body @{ request = $requestB; exactFiles = $filesB }
    $taskB = $createB.brain.currentTask
    Assert-True ([string]$taskB.request -eq $requestB) 'SECOND_TASK_CREATE_PASS'

    $status = Invoke-RestMethod `
        -Uri "http://127.0.0.1:$port/api/projects/eink/status" `
        -TimeoutSec 5
    Assert-True (
        [string]$status.brain.currentTask.taskId -eq [string]$taskB.taskId -and
        [string]$status.brain.currentTask.request -eq $requestB -and
        @($status.brain.currentTask.exactFiles).Count -eq 1
    ) 'REFRESH_CURRENT_AUTHORITATIVE_DATA'

    $historyA = @(
        $status.brain.recentTasks |
        Where-Object { [string]$_.taskId -eq [string]$taskA.taskId }
    )
    Assert-True (
        $historyA.Count -eq 1 -and
        [string]$historyA[0].request -eq $requestA -and
        @($historyA[0].exactFiles).Count -eq 2
    ) 'SELECTED_HISTORY_TASK_HAS_HYDRATION_DATA'

    $resumeA = Invoke-BrainAction `
        -Port $port `
        -Token ([string]$hub.sessionToken) `
        -Action 'brain-resume' `
        -Body @{ taskId = [string]$taskA.taskId }
    Assert-True (
        [string]$resumeA.brain.currentTask.taskId -eq [string]$taskA.taskId -and
        [string]$resumeA.brain.currentTask.request -eq $requestA -and
        @($resumeA.brain.currentTask.exactFiles).Count -eq 2
    ) 'RESUME_RESPONSE_PRESERVES_HYDRATION_DATA'

    $shutdown = Invoke-RestMethod `
        -Uri "http://127.0.0.1:$port/api/shutdown" `
        -Method Post `
        -Headers @{ 'X-Eink-Control-Token' = [string]$hub.sessionToken } `
        -ContentType 'application/json' `
        -Body '{}' `
        -TimeoutSec 5
    Assert-True ([string]$shutdown.result -eq 'STOPPING') 'ISOLATED_SERVER_STOP'
    [void]$serverPowerShell.EndInvoke($serverAsync)
    $serverAsync = $null

    Assert-True (
        (Get-FileSha256OrMissing -Path $productionCurrentPath) -eq
            $productionCurrentBefore -and
        (Get-FileSha256OrMissing -Path $productionHistoryPath) -eq
            $productionHistoryBefore
    ) 'PRODUCTION_BRAIN_STORE_UNCHANGED'
    Assert-True (
        ((@(& git -C $repoRoot status --short --untracked-files=all)) -join "`n") -eq
            ($realStatusBefore -join "`n")
    ) 'REAL_WORKTREE_STATUS_PRESERVED'
    Assert-True (
        ((@(& git -C $repoRoot branch --show-current) -join '').Trim()) -eq
            $realBranchBefore
    ) 'REAL_BRANCH_PRESERVED'
    Assert-True (
        ((& git -C $repoRoot rev-parse HEAD).Trim()) -eq $realHeadBefore
    ) 'REAL_HEAD_PRESERVED'

    Write-Output 'EINK HARNESS TASK FORM HYDRATION ACCEPTANCE: PASS'
}
finally {
    if ($serverPowerShell) {
        if ($serverAsync -and -not $serverAsync.IsCompleted) {
            $serverPowerShell.Stop()
        }
        $serverPowerShell.Dispose()
    }

    if (Test-Path -LiteralPath $runRoot) {
        $resolvedRun = [IO.Path]::GetFullPath($runRoot)
        $resolvedAcceptance = [IO.Path]::GetFullPath(
            $acceptanceRoot
        ).TrimEnd('\') + '\'
        if (-not $resolvedRun.StartsWith(
            $resolvedAcceptance,
            [StringComparison]::OrdinalIgnoreCase
        )) {
            throw 'REFUSING_UNSAFE_HYDRATION_ACCEPTANCE_CLEANUP'
        }
        Remove-Item -LiteralPath $resolvedRun -Recurse -Force
    }
}
