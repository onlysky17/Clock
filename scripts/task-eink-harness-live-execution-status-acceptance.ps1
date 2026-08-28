[CmdletBinding()]
param()

$ErrorActionPreference = 'Stop'
$repoRoot = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path
$serverPath = Join-Path $repoRoot 'tools\harness\control-center\server.ps1'
$workerPath = Join-Path $repoRoot 'tools\harness\compiled-task-worker.ps1'
$executorPath = Join-Path $repoRoot 'tools\harness\compiled-task-executor.ps1'
$indexPath = Join-Path $repoRoot 'tools\harness\control-center\index.html'
$acceptanceRoot = Join-Path ([IO.Path]::GetTempPath()) 'EINK_HARNESS_LIVE_STATUS_ACCEPTANCE'
$runRoot = Join-Path $acceptanceRoot ([Guid]::NewGuid().ToString('N'))
$workspace = Join-Path $runRoot 'workspace'
$brainRoot = Join-Path $workspace '_incoming\brain'
$currentTaskPath = Join-Path $brainRoot 'current-task.json'
$historyPath = Join-Path $brainRoot 'history.jsonl'
$fixturePath = Join-Path $workspace '_incoming\post-burn-fixture.json'
$port = 0
$server = $null
$token = ''

function Assert-True {
    param([Parameter(Mandatory=$true)][bool]$Condition,[Parameter(Mandatory=$true)][string]$Name)
    if (-not $Condition) { throw "ASSERT_FAIL: $Name" }
    Write-Output "$Name`: PASS"
}

function Write-Utf8Json {
    param([Parameter(Mandatory=$true)][string]$Path,[Parameter(Mandatory=$true)]$Value)
    $parent = Split-Path -Parent $Path
    if (-not (Test-Path -LiteralPath $parent -PathType Container)) {
        [void](New-Item -ItemType Directory -Path $parent -Force)
    }
    [IO.File]::WriteAllText($Path,($Value | ConvertTo-Json -Depth 12),[Text.UTF8Encoding]::new($false))
}

function Get-FreePort {
    $listener = [Net.Sockets.TcpListener]::new([Net.IPAddress]::Loopback,0)
    $listener.Start()
    try { ([Net.IPEndPoint]$listener.LocalEndpoint).Port }
    finally { $listener.Stop() }
}

function Invoke-FixtureGit {
    param([Parameter(Mandatory=$true)][string[]]$Arguments)
    $previous = $ErrorActionPreference
    try {
        $ErrorActionPreference = 'Continue'
        $output = @(& git -C $workspace @Arguments 2>&1 | ForEach-Object { $_.ToString() })
        $exitCode = $LASTEXITCODE
    }
    finally { $ErrorActionPreference = $previous }
    if ($exitCode -ne 0) { throw "FIXTURE_GIT_FAILED: $($Arguments -join ' ')`n$($output -join "`n")" }
    @($output)
}

function New-CompiledTask {
    param([Parameter(Mandatory=$true)][string]$TaskId)
    $head = ([string]@(Invoke-FixtureGit @('rev-parse','HEAD'))[-1]).Trim()
    $branch = ([string]@(Invoke-FixtureGit @('branch','--show-current'))[-1]).Trim()
    $allowed = @('docs/live-status-fixture.md')
    $contract = [pscustomobject][ordered]@{
        schema = 'eink-task-contract-v1'
        compilerVersion = '0.7.0'
        compilerPolicy = 'DETERMINISTIC_HEURISTIC_V1_WITH_EXACT_SCOPE'
        taskId = $TaskId
        sourceRequest = 'Exercise live execution status transport.'
        projectId = 'eink'
        workspace = [IO.Path]::GetFullPath($workspace)
        taskClass = 'HARNESS'
        riskLevel = 'MEDIUM'
        hardwareIntent = $false
        visualIntent = $false
        requiresClassificationReview = $false
        requiredCapabilities = @('workspace.verify','repo.edit','validation.smoke')
        candidateFileScopes = @('docs/**')
        allowedFiles = $allowed
        exactScopeSha256 = Get-EinkExecutorSha256Text -Text ($allowed -join "`n")
        exactFilesRequiredBeforeExecution = $true
        forbiddenActions = @('git.add-all','git.auto-merge','hardware.burn-without-owner')
        ownerGates = @('OWNER_RUN_COMPILED_CONFIRMATION','OWNER_MERGE')
        acceptanceCriteria = @('Live status must remain queryable.')
        executionEnabled = $false
        executionEligible = $true
        ownerExecutionRequired = $true
        executionState = 'OWNER_RUN_REQUIRED'
        allowDirtyTrackedTree = $false
        resumeExistingEvidence = $false
        autoMerge = $false
        compiledUtc = [DateTime]::UtcNow.ToString('o')
        compiledFromBranch = $branch
        compiledFromHead = $head
    }
    $contract | Add-Member -NotePropertyName contractSha256 -NotePropertyValue (Get-EinkExecutorContractSha256 -Contract $contract)
    [pscustomobject][ordered]@{
        schema = 'eink-brain-task-v1'
        taskId = $TaskId
        request = [string]$contract.sourceRequest
        event = 'COMPILE'
        status = 'COMPILED'
        createdUtc = [DateTime]::UtcNow.ToString('o')
        updatedUtc = [DateTime]::UtcNow.ToString('o')
        resumeCount = 0
        contract = $contract
    }
}

function Start-AcceptanceServer {
    $stdout = Join-Path $runRoot ("server-$([Guid]::NewGuid().ToString('N')).stdout.log")
    $stderr = Join-Path $runRoot ("server-$([Guid]::NewGuid().ToString('N')).stderr.log")
    $arguments = @(
        '-NoProfile','-ExecutionPolicy','Bypass','-File',"`"$serverPath`"",
        '-Port',[string]$port,'-NoBrowser','-AcceptanceMode',
        '-AcceptanceWorkspace',"`"$workspace`"",
        '-AcceptanceFixturePath',"`"$fixturePath`"",
        '-BrainAcceptanceRoot',"`"$brainRoot`"",
        '-ExecutorAcceptance'
    )
    $processStart = [Diagnostics.ProcessStartInfo]::new()
    $processStart.FileName = 'powershell.exe'
    $processStart.Arguments = $arguments -join ' '
    $processStart.UseShellExecute = $true
    $processStart.WindowStyle = [Diagnostics.ProcessWindowStyle]::Hidden
    $process = [Diagnostics.Process]::Start($processStart)
    $hub = $null
    for ($i=0;$i -lt 100;$i++) {
        Start-Sleep -Milliseconds 100
        if ($process.HasExited) { break }
        try {
            $hub = Invoke-RestMethod -Uri "http://127.0.0.1:$port/api/status" -TimeoutSec 2
            if ($hub.sessionToken) { break }
        } catch {}
    }
    if (-not $hub -or -not $hub.sessionToken) {
        $errorText = if (Test-Path -LiteralPath $stderr) { Get-Content -LiteralPath $stderr -Raw } else { '' }
        throw "ACCEPTANCE_SERVER_START_FAILED: $errorText"
    }
    [pscustomobject]@{ Process=$process; Token=[string]$hub.sessionToken }
}

function Stop-AcceptanceServer {
    param($Instance)
    if (-not $Instance -or $Instance.Process.HasExited) { return }
    try {
        Invoke-RestMethod -Uri "http://127.0.0.1:$port/api/lifecycle/stop" -Method Post `
            -Headers @{ 'X-Eink-Control-Token'=[string]$Instance.Token } -ContentType 'application/json' -Body '{}' -TimeoutSec 3 | Out-Null
    } catch {}
    [void]$Instance.Process.WaitForExit(5000)
    if (-not $Instance.Process.HasExited) {
        Stop-Process -Id $Instance.Process.Id -Force
        [void]$Instance.Process.WaitForExit(3000)
    }
}

function Invoke-BrainAction {
    param([Parameter(Mandatory=$true)][string]$Action,[Parameter(Mandatory=$true)]$Body)
    Invoke-RestMethod -Uri "http://127.0.0.1:$port/api/projects/eink/actions/$Action" -Method Post `
        -Headers @{ 'X-Eink-Control-Token'=$token } -ContentType 'application/json; charset=utf-8' `
        -Body ($Body | ConvertTo-Json -Depth 12 -Compress) -TimeoutSec 10
}

function Get-EinkStatus {
    Invoke-RestMethod -Uri "http://127.0.0.1:$port/api/projects/eink/status" -TimeoutSec 3
}

$realHead = (& git -C $repoRoot rev-parse HEAD).Trim()
$realStatus = @(& git -C $repoRoot status --porcelain=v1 --untracked-files=all) -join "`n"

try {
    [void](New-Item -ItemType Directory -Path (Join-Path $workspace 'tools\harness') -Force)
    [void](New-Item -ItemType Directory -Path (Join-Path $workspace 'docs') -Force)
    Copy-Item -LiteralPath $executorPath -Destination (Join-Path $workspace 'tools\harness\compiled-task-executor.ps1')
    Copy-Item -LiteralPath $workerPath -Destination (Join-Path $workspace 'tools\harness\compiled-task-worker.ps1')
    Copy-Item -LiteralPath (Join-Path $repoRoot 'tools\harness\eink-profile.json') -Destination (Join-Path $workspace 'tools\harness\eink-profile.json')
    [IO.File]::WriteAllText((Join-Path $workspace 'docs\live-status-fixture.md'),'fixture',[Text.UTF8Encoding]::new($false))
    [IO.File]::WriteAllText((Join-Path $workspace '.gitignore'),"/_incoming/`n",[Text.UTF8Encoding]::new($false))
    [void](Invoke-FixtureGit @('init','-b','task/live-status'))
    [void](Invoke-FixtureGit @('config','user.name','EINK Acceptance'))
    [void](Invoke-FixtureGit @('config','user.email','eink-acceptance@example.invalid'))
    [void](Invoke-FixtureGit @('add','--','.gitignore','docs/live-status-fixture.md','tools/harness/compiled-task-executor.ps1','tools/harness/compiled-task-worker.ps1','tools/harness/eink-profile.json'))
    [void](Invoke-FixtureGit @('commit','-m','test: live status fixture'))

    . $executorPath
    $task = New-CompiledTask -TaskId 'EINK-LIVE-STATUS-ACCEPTANCE'
    Write-Utf8Json -Path $currentTaskPath -Value $task
    [IO.File]::AppendAllText($historyPath,(($task | ConvertTo-Json -Depth 12 -Compress)+[Environment]::NewLine),[Text.UTF8Encoding]::new($false))
    $artifact = Join-Path $workspace '_incoming\fixture.bin'
    [IO.File]::WriteAllBytes($artifact,[byte[]](0..31))
    Write-Utf8Json -Path $fixturePath -Value ([ordered]@{
        schema='eink-control-center-post-burn-fixture-v1'; simulated=$true; autoBindCurrentWorkspace=$true; artifactPath=$artifact
    })

    $port = Get-FreePort
    $server = Start-AcceptanceServer
    $token = [string]$server.Token
    $authority = [ordered]@{
        taskId=[string]$task.taskId
        contractSha256=[string]$task.contract.contractSha256
        exactScopeSha256=[string]$task.contract.exactScopeSha256
    }

    $mismatchArm = Invoke-BrainAction -Action 'brain-execute-arm' -Body $authority
    $mismatch = Invoke-BrainAction -Action 'brain-execute' -Body ([ordered]@{
        taskId=$authority.taskId; contractSha256=$authority.contractSha256; exactScopeSha256=('F'*64); ownerChallenge=$mismatchArm.challenge
    })
    Assert-True ([string]$mismatch.lastResult -eq 'BLOCKED') 'EXACT_SCOPE_MISMATCH_STILL_BLOCKED'
    $replay = Invoke-BrainAction -Action 'brain-execute' -Body ([ordered]@{
        taskId=$authority.taskId; contractSha256=$authority.contractSha256; exactScopeSha256=$authority.exactScopeSha256; ownerChallenge=$mismatchArm.challenge
    })
    Assert-True ([string]$replay.lastResult -eq 'BLOCKED') 'OWNER_CHALLENGE_FAILED_ATTEMPT_CONSUMED'

    $arm = Invoke-BrainAction -Action 'brain-execute-arm' -Body $authority
    Assert-True ([bool]$arm.armed -and $arm.challenge) 'OWNER_CHALLENGE_ARMED_ONCE'
    $timer = [Diagnostics.Stopwatch]::StartNew()
    $started = Invoke-BrainAction -Action 'brain-execute' -Body ([ordered]@{
        taskId=$authority.taskId; contractSha256=$authority.contractSha256; exactScopeSha256=$authority.exactScopeSha256
        ownerChallenge=$arm.challenge; acceptanceScenario='LIVE_STATUS'
    })
    $timer.Stop()
    Assert-True ($timer.Elapsed.TotalSeconds -lt 2.0) 'EXECUTE_REQUEST_RETURNS_WITHOUT_MONOPOLIZING_LOOP'
    Assert-True ([bool]$started.brain.execution.active -and [string]$started.brain.execution.state -in @('STARTING','PREFLIGHT')) 'DEDICATED_WORKER_ACTIVE'

    $statusTimer = [Diagnostics.Stopwatch]::StartNew()
    $activeStatus = Get-EinkStatus
    $statusTimer.Stop()
    if (-not [bool]$activeStatus.brain.execution.active) {
        Write-Output ('ACTIVE_STATUS_DIAGNOSTIC: ' + ($activeStatus.brain.execution | ConvertTo-Json -Depth 8 -Compress))
    }
    Assert-True ($statusTimer.Elapsed.TotalSeconds -lt 3.0 -and [bool]$activeStatus.brain.execution.active) 'STATUS_QUERYABLE_DURING_ACTIVE_WORKER'
    $duplicate = Invoke-BrainAction -Action 'brain-execute-arm' -Body $authority
    Assert-True (-not [bool]$duplicate.armed -and [string]$duplicate.reason -eq 'HARNESS_BUSY') 'DUPLICATE_WORKER_LAUNCH_BLOCKED'

    Stop-AcceptanceServer -Instance $server
    $server = Start-AcceptanceServer
    $token = [string]$server.Token
    $reloaded = Get-EinkStatus
    Assert-True ([bool]$reloaded.brain.execution.active -and [string]$reloaded.brain.execution.taskId -eq $authority.taskId) 'RELOAD_RECOVERS_PERSISTED_ACTIVE_EXECUTION'

    $seen = New-Object 'Collections.Generic.HashSet[string]'
    $terminal = $null
    for ($i=0;$i -lt 60;$i++) {
        $sample = Get-EinkStatus
        [void]$seen.Add([string]$sample.brain.execution.state)
        if (-not [bool]$sample.brain.execution.active -and [string]$sample.brain.execution.state -eq 'WAITING OWNER') {
            $terminal = $sample
            break
        }
        Start-Sleep -Milliseconds 150
    }
    Assert-True ($seen.Contains('PREFLIGHT') -or $seen.Contains('EXECUTING')) 'PERSISTED_PHASES_SURFACED_TO_STATUS'
    Assert-True ($terminal -and [string]$terminal.brain.execution.prUrl -match '^https://example\.invalid/') 'OWNER_MERGE_REQUIRED_EXPOSES_PR'
    Assert-True (-not [bool]$terminal.brain.execution.active) 'OWNER_MERGE_REQUIRED_STOPS_ACTIVE_POLLING'

    $blockedTask = New-CompiledTask -TaskId 'EINK-LIVE-STATUS-BLOCKED'
    Write-Utf8Json -Path $currentTaskPath -Value $blockedTask
    $blockedAuthority = [ordered]@{
        taskId=[string]$blockedTask.taskId
        contractSha256=[string]$blockedTask.contract.contractSha256
        exactScopeSha256=[string]$blockedTask.contract.exactScopeSha256
    }
    $blockedArm = Invoke-BrainAction -Action 'brain-execute-arm' -Body $blockedAuthority
    [void](Invoke-BrainAction -Action 'brain-execute' -Body ([ordered]@{
        taskId=$blockedAuthority.taskId; contractSha256=$blockedAuthority.contractSha256
        exactScopeSha256=$blockedAuthority.exactScopeSha256; ownerChallenge=$blockedArm.challenge
        acceptanceScenario='BLOCKED_TERMINAL'
    }))
    $blockedTerminal = $null
    for ($i=0;$i -lt 40;$i++) {
        $sample = Get-EinkStatus
        if ([string]$sample.brain.execution.state -eq 'BLOCKED') { $blockedTerminal=$sample; break }
        Start-Sleep -Milliseconds 150
    }
    Assert-True ($blockedTerminal -and [string]$blockedTerminal.brain.execution.reason -eq 'ACCEPTANCE_BLOCKED_REASON') 'BLOCKED_SURFACES_ACTUAL_REASON'
    Assert-True (-not [bool]$blockedTerminal.brain.execution.active) 'BLOCKED_STOPS_ACTIVE_POLLING'

    $index = [IO.File]::ReadAllText($indexPath,[Text.Encoding]::UTF8)
    $serverText = [IO.File]::ReadAllText($serverPath,[Text.Encoding]::UTF8)
    foreach ($state in @('ARMING','STARTING','PREFLIGHT','BRANCH READY','EXECUTING','VALIDATING','PUSHED','WAITING OWNER','BLOCKED','COMPLETE')) {
        Assert-True ($index.Contains($state) -or $serverText.Contains($state)) ("UI_STATE_MAPPING_" + ($state -replace ' ','_'))
    }
    Assert-True ($index.Contains('localExecutionState = "ARMING"') -and $index.Contains('syncExecutionPolling')) 'ARMING_AND_AUTOMATIC_POLLING_UI_WIRED'
    Assert-True ($index.Contains('if (!shouldPoll && polling)') -and $index.Contains('execution.prUrl')) 'TERMINAL_POLL_STOP_AND_PR_UI_WIRED'

    Assert-True ((& git -C $repoRoot rev-parse HEAD).Trim() -eq $realHead) 'REAL_HEAD_PRESERVED'
    Assert-True ((@(& git -C $repoRoot status --porcelain=v1 --untracked-files=all) -join "`n") -eq $realStatus) 'REAL_WORKTREE_STATUS_PRESERVED'
    Write-Output 'EINK HARNESS LIVE EXECUTION STATUS ACCEPTANCE: PASS'
}
finally {
    if ($server) { Stop-AcceptanceServer -Instance $server }
    if (Test-Path -LiteralPath $runRoot) {
        $resolvedRun = [IO.Path]::GetFullPath($runRoot)
        $prefix = [IO.Path]::GetFullPath($acceptanceRoot).TrimEnd('\') + '\'
        if (-not $resolvedRun.StartsWith($prefix,[StringComparison]::OrdinalIgnoreCase)) {
            throw 'REFUSING_UNSAFE_ACCEPTANCE_CLEANUP'
        }
        Remove-Item -LiteralPath $runRoot -Recurse -Force
    }
}
