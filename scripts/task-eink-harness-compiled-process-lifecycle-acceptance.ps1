[CmdletBinding()]
param()

$ErrorActionPreference = 'Stop'
$repoRoot = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path
$executorPath = Join-Path $repoRoot 'tools\harness\compiled-task-executor.ps1'
$workerPath = Join-Path $repoRoot 'tools\harness\compiled-task-worker.ps1'
$serverPath = Join-Path $repoRoot 'tools\harness\control-center\server.ps1'
$profilePath = Join-Path $repoRoot 'tools\harness\eink-profile.json'
$acceptanceRoot = Join-Path ([IO.Path]::GetTempPath()) 'eink-compiled-process-lifecycle-acceptance'
$runRoot = Join-Path $acceptanceRoot ([Guid]::NewGuid().ToString('N'))
$workspace = Join-Path $runRoot 'workspace'
$brainRoot = Join-Path $workspace '_incoming\brain'
$currentTaskPath = Join-Path $brainRoot 'current-task.json'
$historyPath = Join-Path $brainRoot 'history.jsonl'
$fixturePath = Join-Path $workspace '_incoming\post-burn-fixture.json'
$runtimeRoot = Join-Path $workspace '_incoming\EINK_HARNESS_CONTROL_CENTER_RUNTIME'
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
    $allowed = @('docs/lifecycle-fixture.md')
    $contract = [pscustomobject][ordered]@{
        schema='eink-task-contract-v1'; compilerVersion='0.7.0'
        compilerPolicy='DETERMINISTIC_HEURISTIC_V1_WITH_EXACT_SCOPE'; taskId=$TaskId
        sourceRequest='Exercise compiled process lifecycle.'; projectId='eink'
        workspace=[IO.Path]::GetFullPath($workspace); taskClass='HARNESS'; riskLevel='MEDIUM'
        hardwareIntent=$false; visualIntent=$false; requiresClassificationReview=$false
        requiredCapabilities=@('workspace.verify','repo.edit','validation.smoke')
        candidateFileScopes=@('docs/**'); allowedFiles=$allowed
        exactScopeSha256=Get-EinkExecutorSha256Text -Text ($allowed -join "`n")
        exactFilesRequiredBeforeExecution=$true
        forbiddenActions=@('git.add-all','git.auto-merge','hardware.burn-without-owner')
        ownerGates=@('OWNER_RUN_COMPILED_CONFIRMATION','OWNER_MERGE')
        acceptanceCriteria=@('Process lifecycle must remain deterministic.')
        executionEnabled=$false; executionEligible=$true; ownerExecutionRequired=$true
        executionState='OWNER_RUN_REQUIRED'; allowDirtyTrackedTree=$false
        resumeExistingEvidence=$false; autoMerge=$false
        compiledUtc=[DateTime]::UtcNow.ToString('o'); compiledFromBranch='task/lifecycle'
        compiledFromHead=$head
    }
    $contract | Add-Member -NotePropertyName contractSha256 -NotePropertyValue (Get-EinkExecutorContractSha256 -Contract $contract)
    [pscustomobject][ordered]@{
        schema='eink-brain-task-v1'; taskId=$TaskId; request=[string]$contract.sourceRequest
        event='COMPILE'; status='COMPILED'; createdUtc=[DateTime]::UtcNow.ToString('o')
        updatedUtc=[DateTime]::UtcNow.ToString('o'); resumeCount=0; contract=$contract
    }
}

function Start-AcceptanceServer {
    $stdout = Join-Path $runRoot 'server.stdout.log'
    $stderr = Join-Path $runRoot 'server.stderr.log'
    $arguments = @(
        '-NoProfile','-ExecutionPolicy','Bypass','-File',("`"$serverPath`""),
        '-Port',[string]$port,'-NoBrowser','-AcceptanceMode',
        '-AcceptanceWorkspace',("`"$workspace`""),
        '-AcceptanceFixturePath',("`"$fixturePath`""),
        '-BrainAcceptanceRoot',("`"$brainRoot`""),'-ExecutorAcceptance'
    )
    $processStart=[Diagnostics.ProcessStartInfo]::new()
    $processStart.FileName='powershell.exe'
    $processStart.Arguments=$arguments -join ' '
    $processStart.UseShellExecute=$false
    $processStart.CreateNoWindow=$true
    $processStart.RedirectStandardOutput=$true
    $processStart.RedirectStandardError=$true
    $process=[Diagnostics.Process]::new();$process.StartInfo=$processStart
    if(-not $process.Start()){throw 'ACCEPTANCE_SERVER_PROCESS_START_FAILED'}
    $stdoutRead=$process.StandardOutput.ReadToEndAsync()
    $stderrRead=$process.StandardError.ReadToEndAsync()
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
        $errorText = if($process.HasExited){[string]$stderrRead.Result}else{''}
        throw "ACCEPTANCE_SERVER_START_FAILED: $errorText"
    }
    [pscustomobject]@{Process=$process;Token=[string]$hub.sessionToken;StdoutRead=$stdoutRead;StderrRead=$stderrRead;StdoutPath=$stdout;StderrPath=$stderr}
}

function Stop-AcceptanceServer {
    param($Instance)
    if (-not $Instance -or $Instance.Process.HasExited) { return }
    try {
        Invoke-RestMethod -Uri "http://127.0.0.1:$port/api/lifecycle/stop" -Method Post `
            -Headers @{ 'X-Eink-Control-Token'=[string]$Instance.Token } `
            -ContentType 'application/json' -Body '{}' -TimeoutSec 3 | Out-Null
    } catch {}
    [void]$Instance.Process.WaitForExit(5000)
    if (-not $Instance.Process.HasExited) {
        Stop-Process -Id $Instance.Process.Id -Force
        [void]$Instance.Process.WaitForExit(3000)
    }
    if($Instance.Process.HasExited){
        [IO.File]::WriteAllText([string]$Instance.StdoutPath,[string]$Instance.StdoutRead.Result,[Text.UTF8Encoding]::new($false))
        [IO.File]::WriteAllText([string]$Instance.StderrPath,[string]$Instance.StderrRead.Result,[Text.UTF8Encoding]::new($false))
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

function Invoke-ChildFixture {
    param([Parameter(Mandatory=$true)][string]$Name,[Parameter(Mandatory=$true)][string]$CommandLine)
    $root = Join-Path $runRoot ("child-$Name")
    [void](New-Item -ItemType Directory -Path $root -Force)
    Invoke-EinkExecutorTrackedChild -CommandLine $CommandLine -WorkingDirectory $root `
        -StdoutPath (Join-Path $root 'stdout.log') -StderrPath (Join-Path $root 'stderr.log') `
        -ExitCodePath (Join-Path $root 'exit-code.txt') -TimeoutSec 10
}

$realHead = (& git -C $repoRoot rev-parse HEAD).Trim()
$realStatus = @(& git -C $repoRoot status --porcelain=v1 --untracked-files=all) -join "`n"

try {
    [void](New-Item -ItemType Directory -Path (Join-Path $workspace 'tools\harness') -Force)
    [void](New-Item -ItemType Directory -Path (Join-Path $workspace 'docs') -Force)
    Copy-Item -LiteralPath $executorPath -Destination (Join-Path $workspace 'tools\harness\compiled-task-executor.ps1')
    Copy-Item -LiteralPath $workerPath -Destination (Join-Path $workspace 'tools\harness\compiled-task-worker.ps1')
    Copy-Item -LiteralPath $profilePath -Destination (Join-Path $workspace 'tools\harness\eink-profile.json')
    [IO.File]::WriteAllText((Join-Path $workspace 'docs\lifecycle-fixture.md'),'fixture',[Text.UTF8Encoding]::new($false))
    [IO.File]::WriteAllText((Join-Path $workspace '.gitignore'),"/_incoming/`n",[Text.UTF8Encoding]::new($false))
    [void](Invoke-FixtureGit @('init','-b','task/lifecycle'))
    [void](Invoke-FixtureGit @('config','user.name','EINK Acceptance'))
    [void](Invoke-FixtureGit @('config','user.email','eink-acceptance@example.invalid'))
    [void](Invoke-FixtureGit @('add','--','.gitignore','docs/lifecycle-fixture.md','tools/harness/compiled-task-executor.ps1','tools/harness/compiled-task-worker.ps1','tools/harness/eink-profile.json'))
    [void](Invoke-FixtureGit @('commit','-m','test: lifecycle fixture'))

    . $executorPath
    foreach ($path in @($executorPath,$serverPath,$PSCommandPath)) {
        $tokens=$null; $errors=$null
        [void][Management.Automation.Language.Parser]::ParseFile($path,[ref]$tokens,[ref]$errors)
        Assert-True (@($errors).Count -eq 0) ("POWERSHELL_PARSE_" + [IO.Path]::GetFileName($path).ToUpperInvariant())
    }

    $comspec = [Environment]::GetEnvironmentVariable('ComSpec')
    if ([string]::IsNullOrWhiteSpace($comspec)) { $comspec='cmd.exe' }
    $zero = Invoke-ChildFixture -Name 'zero' -CommandLine ('"{0}" /d /s /c "echo CHILD_STDOUT& echo CHILD_STDERR 1>&2& exit /b 0"' -f $comspec)
    Assert-True ($zero.Passed -and $zero.ExitCode -eq 0) 'CHILD_EXIT_ZERO'
    Assert-True ((Get-Content -Raw -LiteralPath (Join-Path $runRoot 'child-zero\stdout.log')) -match 'CHILD_STDOUT') 'CHILD_STDOUT_PRESERVED'
    Assert-True ((Get-Content -Raw -LiteralPath (Join-Path $runRoot 'child-zero\stderr.log')) -match 'CHILD_STDERR') 'CHILD_STDERR_PRESERVED'
    $seven = Invoke-ChildFixture -Name 'seven' -CommandLine ('"{0}" /d /s /c "exit /b 7"' -f $comspec)
    Assert-True (-not $seven.Passed -and $seven.ExitCode -eq 7) 'CHILD_NONZERO_EXIT_PRESERVED'
    $timer=[Diagnostics.Stopwatch]::StartNew()
    $delayed = Invoke-ChildFixture -Name 'delayed' -CommandLine ('"{0}" -NoProfile -Command "Start-Sleep -Milliseconds 750; exit 0"' -f ([Diagnostics.Process]::GetCurrentProcess().MainModule.FileName))
    $timer.Stop()
    Assert-True ($delayed.Passed -and $timer.ElapsedMilliseconds -ge 650) 'DELAYED_CHILD_COMPLETION_WAITED'
    $missingReason=''; $invalidReason=''
    try { [void](Get-EinkExecutorChildExitCode -ExitCodePath (Join-Path $runRoot 'missing.txt')) } catch { $missingReason=$_.Exception.Message }
    $invalidPath=Join-Path $runRoot 'invalid.txt'; [IO.File]::WriteAllText($invalidPath,'not-an-integer',[Text.Encoding]::ASCII)
    try { [void](Get-EinkExecutorChildExitCode -ExitCodePath $invalidPath) } catch { $invalidReason=$_.Exception.Message }
    Assert-True ($missingReason -eq 'CODEX_EXECUTION_FAILED: CHILD_EXIT_CODE_MISSING') 'MISSING_EXIT_DETERMINISTIC'
    Assert-True ($invalidReason -eq 'CODEX_EXECUTION_FAILED: CHILD_EXIT_CODE_INVALID: not-an-integer') 'INVALID_EXIT_DETERMINISTIC'
    $executorText=[IO.File]::ReadAllText($executorPath,[Text.Encoding]::UTF8)
    Assert-True (-not $executorText.Contains('agent-child.cmd') -and -not $executorText.Contains('$process.ExitCode')) 'NO_FRAGILE_OR_NULLABLE_AUTHORITATIVE_EXIT'
    Assert-True ($executorText.Contains('--sandbox workspace-write') -and -not $executorText.Contains(' exec --model ')) 'CODEX_DEFAULT_MODEL_AND_SANDBOX_PRESERVED'

    $task=New-CompiledTask -TaskId 'EINK-LIFECYCLE-VALID'
    Write-Utf8Json -Path $currentTaskPath -Value $task
    [IO.File]::AppendAllText($historyPath,(($task|ConvertTo-Json -Depth 12 -Compress)+[Environment]::NewLine),[Text.UTF8Encoding]::new($false))
    $artifact=Join-Path $workspace '_incoming\fixture.bin'; [IO.File]::WriteAllBytes($artifact,[byte[]](0..31))
    Write-Utf8Json -Path $fixturePath -Value ([ordered]@{schema='eink-control-center-post-burn-fixture-v1';simulated=$true;autoBindCurrentWorkspace=$true;artifactPath=$artifact})
    $port=Get-FreePort; $server=Start-AcceptanceServer; $token=[string]$server.Token
    $authority=[ordered]@{taskId=$task.taskId;contractSha256=$task.contract.contractSha256;exactScopeSha256=$task.contract.exactScopeSha256}
    $arm=Invoke-BrainAction -Action 'brain-execute-arm' -Body $authority
    $started=Invoke-BrainAction -Action 'brain-execute' -Body ([ordered]@{taskId=$authority.taskId;contractSha256=$authority.contractSha256;exactScopeSha256=$authority.exactScopeSha256;ownerChallenge=$arm.challenge;acceptanceScenario='LIVE_STATUS'})
    Assert-True ([bool]$started.brain.execution.active -and [string]$started.brain.execution.state -ne 'BLOCKED') 'NO_FALSE_BLOCK_DURING_VALID_STARTUP'
    $runtimePath=Join-Path $runtimeRoot ("compiled-task-$port.json")
    $runtime=Get-Content -Raw -LiteralPath $runtimePath | ConvertFrom-Json
    Assert-True ([int]$runtime.pid -gt 0 -and [int64]$runtime.processStartTicks -gt 0 -and -not [string]::IsNullOrWhiteSpace([string]$runtime.executablePath)) 'WORKER_IDENTITY_PERSISTED'
    Assert-True (-not [string]::IsNullOrWhiteSpace([string]$runtime.startupGraceUntilUtc)) 'WORKER_STARTUP_GRACE_PERSISTED'
    Assert-True ([string]$runtime.stdoutPath -and [string]$runtime.stderrPath -and (Test-Path -LiteralPath $runtime.stdoutPath) -and (Test-Path -LiteralPath $runtime.stderrPath)) 'WORKER_STREAM_EVIDENCE_PATHS_EXIST'
    $terminal=$null
    for($i=0;$i -lt 70;$i++){
        $sample=Get-EinkStatus
        if(-not [bool]$sample.brain.execution.active -and [string]$sample.brain.execution.state -eq 'WAITING OWNER'){$terminal=$sample;break}
        Start-Sleep -Milliseconds 150
    }
    Assert-True ($null -ne $terminal -and [string]$terminal.brain.execution.prUrl -match '^https://example\.invalid/') 'WORKER_TERMINAL_SNAPSHOT_PRESERVED'

    $badTask=New-CompiledTask -TaskId 'EINK-LIFECYCLE-STDERR'
    Write-Utf8Json -Path $currentTaskPath -Value $badTask
    $badAuthority=[ordered]@{taskId=$badTask.taskId;contractSha256=$badTask.contract.contractSha256;exactScopeSha256=$badTask.contract.exactScopeSha256}
    $badArm=Invoke-BrainAction -Action 'brain-execute-arm' -Body $badAuthority
    $badTask.status='DRAFT'; Write-Utf8Json -Path $currentTaskPath -Value $badTask
    [void](Invoke-BrainAction -Action 'brain-execute' -Body ([ordered]@{taskId=$badAuthority.taskId;contractSha256=$badAuthority.contractSha256;exactScopeSha256=$badAuthority.exactScopeSha256;ownerChallenge=$badArm.challenge;acceptanceScenario='LIVE_STATUS'}))
    $badRuntime=$null; $workerError=''
    for($i=0;$i -lt 60;$i++){
        [void](Get-EinkStatus)
        $badRuntime=Get-Content -Raw -LiteralPath $runtimePath | ConvertFrom-Json
        if(Test-Path -LiteralPath $badRuntime.stderrPath){
            try{$workerError=[IO.File]::ReadAllText([string]$badRuntime.stderrPath,[Text.Encoding]::UTF8)}catch{$workerError=''}
        }
        if($workerError -match 'TASK_NOT_COMPILED'){break}
        Start-Sleep -Milliseconds 150
    }
    Assert-True ($workerError -match 'TASK_NOT_COMPILED') 'WORKER_STDERR_ACTUALLY_CAPTURED'

    Assert-True ((& git -C $repoRoot rev-parse HEAD).Trim() -eq $realHead) 'REAL_HEAD_PRESERVED'
    Assert-True ((@(& git -C $repoRoot status --porcelain=v1 --untracked-files=all) -join "`n") -eq $realStatus) 'REAL_WORKTREE_STATUS_PRESERVED'
    Write-Output 'EINK HARNESS COMPILED PROCESS LIFECYCLE ACCEPTANCE: PASS'
}
finally {
    if($server){Stop-AcceptanceServer -Instance $server}
    if(Test-Path -LiteralPath $runRoot){
        $resolved=[IO.Path]::GetFullPath($runRoot);$prefix=[IO.Path]::GetFullPath($acceptanceRoot).TrimEnd('\')+'\'
        if(-not $resolved.StartsWith($prefix,[StringComparison]::OrdinalIgnoreCase)){throw 'REFUSING_UNSAFE_ACCEPTANCE_CLEANUP'}
        Remove-Item -LiteralPath $runRoot -Recurse -Force
    }
}
