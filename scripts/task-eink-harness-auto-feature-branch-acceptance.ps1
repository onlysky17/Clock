[CmdletBinding()]
param()

$ErrorActionPreference = 'Stop'

$repoRoot = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path
$executorPath = Join-Path $repoRoot 'tools\harness\compiled-task-executor.ps1'
$serverPath = Join-Path $repoRoot 'tools\harness\control-center\server.ps1'
$indexPath = Join-Path $repoRoot 'tools\harness\control-center\index.html'
$acceptanceRoot = Join-Path ([IO.Path]::GetTempPath()) 'eink-auto-branch-acceptance'
$runRoot = Join-Path $acceptanceRoot ([Guid]::NewGuid().ToString('N').Substring(0, 12))

function Assert-True {
    param(
        [Parameter(Mandatory=$true)][bool]$Condition,
        [Parameter(Mandatory=$true)][string]$Name
    )
    if (-not $Condition) { throw "ASSERT_FAIL: $Name" }
    Write-Output "$Name`: PASS"
}

function Get-FreeLoopbackPort {
    $listener = [Net.Sockets.TcpListener]::new([Net.IPAddress]::Loopback, 0)
    $listener.Start()
    try { ([Net.IPEndPoint]$listener.LocalEndpoint).Port }
    finally { $listener.Stop() }
}

function Invoke-FixtureGit {
    param(
        [Parameter(Mandatory=$true)][string]$Root,
        [Parameter(Mandatory=$true)][string[]]$Arguments
    )
    $previous = $ErrorActionPreference
    Push-Location $Root
    try {
        $ErrorActionPreference = 'Continue'
        $output = @(& git @Arguments 2>&1 | ForEach-Object { $_.ToString() })
        if ($LASTEXITCODE -ne 0) {
            throw "FIXTURE_GIT_FAILED: git $($Arguments -join ' ')`n$($output -join "`n")"
        }
        @($output)
    }
    finally {
        $ErrorActionPreference = $previous
        Pop-Location
    }
}

function Get-FixtureGitValue {
    param(
        [Parameter(Mandatory=$true)][string]$Root,
        [Parameter(Mandatory=$true)][string[]]$Arguments
    )
    $output = @(Invoke-FixtureGit -Root $Root -Arguments $Arguments)
    ([string]$output[-1]).Trim()
}

function New-FixtureRepo {
    param([Parameter(Mandatory=$true)][string]$Name)

    $root = Join-Path $runRoot $Name
    $remote = Join-Path $runRoot "$Name-origin.git"
    [void](New-Item -ItemType Directory -Path (Join-Path $root 'docs') -Force)
    [IO.File]::WriteAllText(
        (Join-Path $root 'docs\fixture.md'),
        "# Automatic feature branch fixture`n",
        [Text.UTF8Encoding]::new($false)
    )
    [IO.File]::WriteAllText(
        (Join-Path $root '.gitignore'),
        "/_incoming/`n",
        [Text.UTF8Encoding]::new($false)
    )
    [void](Invoke-FixtureGit -Root $root -Arguments @('init','-b','main'))
    [void](Invoke-FixtureGit -Root $root -Arguments @('config','user.name','EINK Acceptance'))
    [void](Invoke-FixtureGit -Root $root -Arguments @('config','user.email','eink-acceptance@example.invalid'))
    [void](Invoke-FixtureGit -Root $root -Arguments @('add','--','.gitignore','docs/fixture.md'))
    [void](Invoke-FixtureGit -Root $root -Arguments @('commit','-m','test: fixture base'))
    [void](Invoke-FixtureGit -Root $runRoot -Arguments @('init','--bare',$remote))
    [void](Invoke-FixtureGit -Root $root -Arguments @('remote','add','origin',$remote))
    [void](Invoke-FixtureGit -Root $root -Arguments @('push','-u','origin','main'))
    $root
}

function New-FixtureTask {
    param(
        [Parameter(Mandatory=$true)][string]$Root,
        [string]$TaskId = 'EINK-AUTO-BRANCH-ACCEPTANCE',
        [switch]$Resume
    )

    $head = Get-FixtureGitValue -Root $Root -Arguments @('rev-parse','HEAD')
    $workspace = Get-FixtureGitValue -Root $Root -Arguments @('rev-parse','--show-toplevel')
    $allowed = @('docs/fixture.md')
    $contract = [pscustomobject][ordered]@{
        schema = 'eink-task-contract-v1'
        compilerVersion = '0.6.0'
        compilerPolicy = 'DETERMINISTIC_HEURISTIC_V1_WITH_EXACT_SCOPE'
        taskId = $TaskId
        featureBranchPolicy = 'AUTO_TASK_SCOPED_FROM_SYNCED_MAIN_V1'
        featureBranch = Get-EinkExecutorFeatureBranchName -TaskId $TaskId
        sourceRequest = 'Update the exact fixture documentation file.'
        projectId = 'eink'
        workspace = [IO.Path]::GetFullPath($workspace)
        taskClass = 'HARNESS'
        riskLevel = 'LOW'
        hardwareIntent = $false
        visualIntent = $false
        requiresClassificationReview = $false
        requiredCapabilities = @('workspace.verify','repo.edit','git.reviewed-stage')
        candidateFileScopes = @('docs/**')
        allowedFiles = $allowed
        exactScopeSha256 = Get-EinkExecutorSha256Text -Text ($allowed -join "`n")
        exactFilesRequiredBeforeExecution = $true
        forbiddenActions = @('git.add-all','git.auto-merge')
        ownerGates = @('OWNER_RUN_COMPILED_CONFIRMATION','OWNER_MERGE')
        acceptanceCriteria = @('git diff --check must pass.')
        executionEnabled = $false
        executionEligible = $true
        ownerExecutionRequired = $true
        executionState = 'OWNER_RUN_REQUIRED'
        allowDirtyTrackedTree = $false
        resumeExistingEvidence = [bool]$Resume
        autoMerge = $false
        compiledUtc = [DateTime]::UtcNow.ToString('o')
        compiledFromBranch = 'main'
        compiledFromHead = $head
    }
    $contract | Add-Member -NotePropertyName contractSha256 -NotePropertyValue (
        Get-EinkExecutorContractSha256 -Contract $contract
    )
    [pscustomobject][ordered]@{
        schema = 'eink-brain-task-v1'
        taskId = $TaskId
        request = [string]$contract.sourceRequest
        status = 'COMPILED'
        contract = $contract
    }
}

function Set-FixtureTaskBranchMetadata {
    param(
        [Parameter(Mandatory=$true)][string]$Root,
        [Parameter(Mandatory=$true)]$Task
    )
    $branch = [string]$Task.contract.featureBranch
    [void](Invoke-FixtureGit -Root $Root -Arguments @('config','--local',"branch.$branch.einkTaskId",[string]$Task.taskId))
    [void](Invoke-FixtureGit -Root $Root -Arguments @('config','--local',"branch.$branch.einkContractSha256",[string]$Task.contract.contractSha256))
    [void](Invoke-FixtureGit -Root $Root -Arguments @('config','--local',"branch.$branch.einkCompiledFromHead",[string]$Task.contract.compiledFromHead))
}

function Invoke-FixtureExecutor {
    param(
        [Parameter(Mandatory=$true)][string]$Root,
        [Parameter(Mandatory=$true)]$Task,
        [string]$ExpectedSha = ''
    )
    $sha = if ($ExpectedSha) { $ExpectedSha } else { [string]$Task.contract.contractSha256 }
    Invoke-EinkCompiledTaskExecutor `
        -RepoRoot $Root `
        -Task $Task `
        -ExpectedContractSha256 $sha `
        -EvidenceRoot (Join-Path $Root '_incoming\executor') `
        -AcceptanceMode `
        -AcceptanceScenario $(if ([bool]$Task.contract.resumeExistingEvidence) { 'RESUME_EXISTING' } else { 'IMPLEMENT_ALLOWED' })
}

$realStatusBefore = @(& git -C $repoRoot status --short)
$realBranchBefore = (@(& git -C $repoRoot branch --show-current) -join '').Trim()
$realHeadBefore = (& git -C $repoRoot rev-parse HEAD).Trim()

try {
    [void](New-Item -ItemType Directory -Path $runRoot -Force)
    . $executorPath

    foreach ($path in @($executorPath, $serverPath, $PSCommandPath)) {
        $tokens = $null
        $errors = $null
        [void][Management.Automation.Language.Parser]::ParseFile(
            $path,
            [ref]$tokens,
            [ref]$errors
        )
        Assert-True (@($errors).Count -eq 0) ("POWERSHELL_PARSE_" + [IO.Path]::GetFileName($path).ToUpperInvariant())
    }

    $index = [IO.File]::ReadAllText($indexPath, [Text.Encoding]::UTF8)
    $server = [IO.File]::ReadAllText($serverPath, [Text.Encoding]::UTF8)
    Assert-True ($server.Contains('AUTO_TASK_SCOPED_FROM_SYNCED_MAIN_V1')) 'CONTRACT_FEATURE_BRANCH_POLICY'
    Assert-True ($server.Contains("reason = 'STALE_MAIN'")) 'OWNER_ARM_STALE_MAIN_GATE'
    Assert-True ($index -match '#einkBrainRequest\s*\{[\s\S]*height:\s*280px;[\s\S]*max-height:\s*min\(65vh, 640px\)') 'TASK_REQUEST_LARGE_RESPONSIVE_DEFAULT'
    Assert-True ($index -match 'textarea\s*\{[\s\S]*resize:\s*vertical') 'TASK_REQUEST_MANUAL_RESIZE'
    Assert-True ($index -match 'function resizeEinkBrainRequest[\s\S]*scrollHeight[\s\S]*maxHeight[\s\S]*overflowY') 'TASK_REQUEST_AUTOGROW_MAX_SCROLL'
    Assert-True ($index -match 'einkBrainRequest"\)\.addEventListener\("input"[\s\S]*resizeEinkBrainRequest') 'TASK_REQUEST_INPUT_AUTOGROW_BINDING'
    Assert-True ($index -match 'einkBrainRequest"\)\.value = "";\s*resizeEinkBrainRequest\(\{ reset: true \}\)') 'TASK_REQUEST_CREATE_RESET'
    Assert-True ($index -match 'createButton\.disabled = !!data\?\.busy') 'CREATE_TASK_BUSY_STATE_RESET'

    $normalRoot = New-FixtureRepo -Name 'clean-main'
    $normalTask = New-FixtureTask -Root $normalRoot
    $normal = Invoke-FixtureExecutor -Root $normalRoot -Task $normalTask
    if (-not $normal.Passed) {
        Write-Output ('CLEAN_MAIN_RESULT: ' + ($normal | ConvertTo-Json -Depth 8 -Compress))
    }
    Assert-True ($normal.Passed -and $normal.State -eq 'OWNER_MERGE_REQUIRED') 'CLEAN_SYNCED_MAIN_EXECUTES'
    Assert-True ((Get-FixtureGitValue -Root $normalRoot -Arguments @('branch','--show-current')) -eq [string]$normalTask.contract.featureBranch) 'DETERMINISTIC_TASK_BRANCH_CHECKED_OUT'
    Assert-True (@($normal.Log) -contains ("FEATURE_BRANCH_READY: " + [string]$normalTask.contract.featureBranch)) 'FEATURE_BRANCH_TRANSITION_RECORDED'
    Assert-True (@($normal.Log) -contains 'AUTO_MERGE: DISABLED') 'OWNER_MERGE_GATE_PRESERVED'

    $dirtyRoot = New-FixtureRepo -Name 'dirty-main'
    $dirtyTask = New-FixtureTask -Root $dirtyRoot
    [IO.File]::AppendAllText((Join-Path $dirtyRoot 'docs\fixture.md'), "dirty`n")
    $dirty = Invoke-FixtureExecutor -Root $dirtyRoot -Task $dirtyTask
    Assert-True (-not $dirty.Passed -and $dirty.Reason -eq 'DIRTY_TRACKED_TREE') 'DIRTY_MAIN_BLOCKED'
    Assert-True ((Get-FixtureGitValue -Root $dirtyRoot -Arguments @('branch','--show-current')) -eq 'main') 'DIRTY_MAIN_BRANCH_UNCHANGED'

    $staleRoot = New-FixtureRepo -Name 'stale-main'
    $staleTask = New-FixtureTask -Root $staleRoot
    $staleParent = Get-FixtureGitValue -Root $staleRoot -Arguments @('rev-parse','HEAD')
    $staleTree = Get-FixtureGitValue -Root $staleRoot -Arguments @('rev-parse','HEAD^{tree}')
    $staleRemoteHead = Get-FixtureGitValue -Root $staleRoot -Arguments @(
        'commit-tree',$staleTree,'-p',$staleParent,'-m','test: remote main advanced'
    )
    [void](Invoke-FixtureGit -Root $staleRoot -Arguments @('update-ref','refs/remotes/origin/main',$staleRemoteHead))
    $stale = Invoke-FixtureExecutor -Root $staleRoot -Task $staleTask
    Assert-True (-not $stale.Passed -and $stale.Reason -eq 'STALE_MAIN') 'STALE_MAIN_BLOCKED'

    $collisionRoot = New-FixtureRepo -Name 'branch-collision'
    $collisionTask = New-FixtureTask -Root $collisionRoot
    [void](Invoke-FixtureGit -Root $collisionRoot -Arguments @(
        'branch',[string]$collisionTask.contract.featureBranch
    ))
    $collision = Invoke-FixtureExecutor -Root $collisionRoot -Task $collisionTask
    Assert-True (-not $collision.Passed -and $collision.Reason -eq 'TASK_BRANCH_COLLISION') 'UNRELATED_BRANCH_COLLISION_BLOCKED'

    $existingRoot = New-FixtureRepo -Name 'existing-task-branch'
    $existingTask = New-FixtureTask -Root $existingRoot
    [void](Invoke-FixtureGit -Root $existingRoot -Arguments @(
        'switch','-c',[string]$existingTask.contract.featureBranch
    ))
    Set-FixtureTaskBranchMetadata -Root $existingRoot -Task $existingTask
    $existing = Invoke-FixtureExecutor -Root $existingRoot -Task $existingTask
    Assert-True ($existing.Passed -and $existing.State -eq 'OWNER_MERGE_REQUIRED') 'VALID_EXISTING_TASK_BRANCH_CONTINUES'

    $resumeRoot = New-FixtureRepo -Name 'resume-task-branch'
    $resumeTask = New-FixtureTask -Root $resumeRoot -Resume
    [void](Invoke-FixtureGit -Root $resumeRoot -Arguments @(
        'switch','-c',[string]$resumeTask.contract.featureBranch
    ))
    Set-FixtureTaskBranchMetadata -Root $resumeRoot -Task $resumeTask
    [IO.File]::AppendAllText((Join-Path $resumeRoot 'docs\fixture.md'), "Existing reviewed evidence.`n")
    [void](Invoke-FixtureGit -Root $resumeRoot -Arguments @('add','--','docs/fixture.md'))
    [void](Invoke-FixtureGit -Root $resumeRoot -Arguments @('commit','-m','feat: reviewed task evidence'))
    $resumeHead = Get-FixtureGitValue -Root $resumeRoot -Arguments @('rev-parse','HEAD')
    $resume = Invoke-FixtureExecutor -Root $resumeRoot -Task $resumeTask
    Assert-True ($resume.Passed -and $resume.CommitSha -eq $resumeHead) 'VALID_COMMITTED_TASK_RESUME'

    $scopeRoot = New-FixtureRepo -Name 'scope-sha'
    $scopeTask = New-FixtureTask -Root $scopeRoot
    $scopeTask.contract.exactScopeSha256 = 'F' * 64
    $scopeTask.contract.contractSha256 = Get-EinkExecutorContractSha256 -Contract $scopeTask.contract
    $scope = Invoke-FixtureExecutor -Root $scopeRoot -Task $scopeTask
    Assert-True (-not $scope.Passed -and $scope.Reason -eq 'EXACT_SCOPE_SHA_MISMATCH') 'EXACT_SCOPE_DRIFT_BLOCKED'

    $contractRoot = New-FixtureRepo -Name 'contract-sha'
    $contractTask = New-FixtureTask -Root $contractRoot
    $contract = Invoke-FixtureExecutor -Root $contractRoot -Task $contractTask -ExpectedSha ('0' * 64)
    Assert-True (-not $contract.Passed -and $contract.Reason -eq 'CONTRACT_SHA_MISMATCH') 'CONTRACT_MISMATCH_BLOCKED'

    $controlRoot = Join-Path $runRoot 'control-center-smoke'
    $sourceGitDir = (& git -C $repoRoot rev-parse --git-dir).Trim()
    [void](Invoke-FixtureGit -Root $runRoot -Arguments @(
        '-c',"safe.directory=$sourceGitDir",
        '-c',"safe.directory=$repoRoot",
        'clone','--quiet',$repoRoot,$controlRoot
    ))
    foreach ($relative in @(
        'tools\harness\compiled-task-executor.ps1',
        'tools\harness\control-center\index.html',
        'tools\harness\control-center\server.ps1'
    )) {
        [IO.File]::Copy(
            (Join-Path $repoRoot $relative),
            (Join-Path $controlRoot $relative),
            $true
        )
    }
    $smokeRoot = Join-Path $controlRoot '_incoming\auto-branch-control-center-smoke'
    [void](New-Item -ItemType Directory -Path $smokeRoot -Force)
    $artifactPath = Join-Path $smokeRoot 'simulated-packed.bin'
    [IO.File]::WriteAllText(
        $artifactPath,
        'simulated acceptance artifact',
        [Text.UTF8Encoding]::new($false)
    )
    $fixturePath = Join-Path $smokeRoot 'fixture.json'
    [IO.File]::WriteAllText(
        $fixturePath,
        ([ordered]@{
            schema = 'eink-control-center-post-burn-fixture-v1'
            simulated = $true
            autoBindCurrentWorkspace = $true
            artifactPath = $artifactPath
        } | ConvertTo-Json -Depth 5),
        [Text.UTF8Encoding]::new($false)
    )
    $port = Get-FreeLoopbackPort
    $smokeServer = Join-Path $controlRoot 'tools\harness\control-center\server.ps1'
    $serverPowerShell = $null
    $serverAsync = $null
    try {
        $serverPowerShell = [PowerShell]::Create()
        [void]$serverPowerShell.AddScript({
            param($Server, $Port, $Workspace, $Fixture)
            & $Server `
                -Port $Port `
                -NoBrowser `
                -AcceptanceMode `
                -AcceptanceWorkspace $Workspace `
                -AcceptanceFixturePath $Fixture
        }).AddArgument($smokeServer).AddArgument($port).AddArgument(
            $controlRoot
        ).AddArgument($fixturePath)
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
            throw "CONTROL_CENTER_ACCEPTANCE_START_FAILED: $errors"
        }
        Assert-True ([string]$hub.hubId -eq 'harness-control-center') 'CONTROL_CENTER_STATUS_SMOKE'
        $page = Invoke-WebRequest `
            -Uri "http://127.0.0.1:$port/" `
            -UseBasicParsing `
            -TimeoutSec 3
        Assert-True (
            $page.StatusCode -eq 200 -and
            $page.Content.Contains('Harness Control Center')
        ) 'CONTROL_CENTER_PAGE_SMOKE'
        $shutdown = Invoke-RestMethod `
            -Uri "http://127.0.0.1:$port/api/shutdown" `
            -Method Post `
            -Headers @{ 'X-Eink-Control-Token' = [string]$hub.sessionToken } `
            -ContentType 'application/json' `
            -Body '{}' `
            -TimeoutSec 3
        Assert-True ([string]$shutdown.result -eq 'STOPPING') 'CONTROL_CENTER_SHUTDOWN_SMOKE'
        [void]$serverPowerShell.EndInvoke($serverAsync)
        $serverAsync = $null
    }
    finally {
        if ($serverPowerShell) {
            if ($serverAsync -and -not $serverAsync.IsCompleted) {
                $serverPowerShell.Stop()
            }
            $serverPowerShell.Dispose()
        }
    }

    $realStatusAfter = @(& git -C $repoRoot status --short)
    Assert-True ((@($realStatusBefore) -join "`n") -eq (@($realStatusAfter) -join "`n")) 'REAL_WORKTREE_STATUS_PRESERVED'
    Assert-True ((@(& git -C $repoRoot branch --show-current) -join '').Trim() -eq $realBranchBefore) 'REAL_BRANCH_PRESERVED'
    Assert-True ((& git -C $repoRoot rev-parse HEAD).Trim() -eq $realHeadBefore) 'REAL_HEAD_PRESERVED'

    Write-Output 'EINK HARNESS AUTO FEATURE BRANCH ACCEPTANCE: PASS'
}
finally {
    if (Test-Path -LiteralPath $runRoot) {
        $resolvedRun = [IO.Path]::GetFullPath($runRoot)
        $resolvedAcceptance = [IO.Path]::GetFullPath($acceptanceRoot).TrimEnd('\') + '\'
        if (-not $resolvedRun.StartsWith(
            $resolvedAcceptance,
            [StringComparison]::OrdinalIgnoreCase
        )) {
            throw 'REFUSING_UNSAFE_ACCEPTANCE_CLEANUP'
        }
        Remove-Item -LiteralPath $resolvedRun -Recurse -Force
    }
}
