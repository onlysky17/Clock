[CmdletBinding()]
param()

$ErrorActionPreference = 'Stop'

$repoRoot = (
    Resolve-Path (Join-Path $PSScriptRoot '..')
).Path
$modulePath = Join-Path $repoRoot 'tools\harness\compiled-task-executor.ps1'
$serverPath = Join-Path $repoRoot 'tools\harness\control-center\server.ps1'
$indexPath = Join-Path $repoRoot 'tools\harness\control-center\index.html'
$registryPath = Join-Path $repoRoot 'tools\harness\control-center\projects.json'
$acceptanceRoot = Join-Path ([IO.Path]::GetTempPath()) 'eink-compiled-task-executor-acceptance'
$runRoot = Join-Path $acceptanceRoot ([Guid]::NewGuid().ToString('N'))

function Assert-True {
    param([Parameter(Mandatory=$true)][bool]$Condition, [Parameter(Mandatory=$true)][string]$Name)
    if (-not $Condition) { throw "ASSERT_FAIL: $Name" }
    Write-Output "$Name`: PASS"
}

function Invoke-GitFixture {
    param([Parameter(Mandatory=$true)][string]$Root, [Parameter(Mandatory=$true)][string[]]$Arguments)
    $previous = $ErrorActionPreference
    Push-Location $Root
    try {
        $ErrorActionPreference = 'Continue'
        $output = @(& git @Arguments 2>&1 | ForEach-Object { $_.ToString() })
        if ($LASTEXITCODE -ne 0) {
            throw "GIT_FIXTURE_FAILED: git $($Arguments -join ' ')`n$($output -join "`n")"
        }
        @($output)
    }
    finally {
        $ErrorActionPreference = $previous
        Pop-Location
    }
}

function New-FixtureRepo {
    param([Parameter(Mandatory=$true)][string]$Name)
    $root = Join-Path $runRoot $Name
    [void](New-Item -ItemType Directory -Path (Join-Path $root 'docs') -Force)
    [IO.File]::WriteAllText(
        (Join-Path $root 'docs\executor-fixture.md'),
        "# Executor fixture`n",
        [Text.UTF8Encoding]::new($false)
    )
    [IO.File]::WriteAllText(
        (Join-Path $root '.gitignore'),
        "/_incoming/`n",
        [Text.UTF8Encoding]::new($false)
    )
    [void](Invoke-GitFixture -Root $root -Arguments @('init','-b','task/executor-fixture'))
    [void](Invoke-GitFixture -Root $root -Arguments @('config','user.name','EINK Acceptance'))
    [void](Invoke-GitFixture -Root $root -Arguments @('config','user.email','eink-acceptance@example.invalid'))
    [void](Invoke-GitFixture -Root $root -Arguments @('add','--','.gitignore','docs/executor-fixture.md'))
    [void](Invoke-GitFixture -Root $root -Arguments @('commit','-m','test: fixture base'))

    [void](New-Item -ItemType Directory -Path (Join-Path $root 'bk-13-08-26') -Force)
    [IO.File]::WriteAllText(
        (Join-Path $root 'bk-13-08-26\preserved.bin'),
        'historical',
        [Text.UTF8Encoding]::new($false)
    )
    [void](New-Item -ItemType Directory -Path (Join-Path $root 'scripts') -Force)
    [IO.File]::WriteAllText(
        (Join-Path $root 'scripts\task-eink-partial-ghosting-fast-validate.ps1'),
        '# historical',
        [Text.UTF8Encoding]::new($false)
    )
    $root
}

function New-ContractTask {
    param(
        [Parameter(Mandatory=$true)][string]$Root,
        [string]$TaskId = 'EINK-EXECUTOR-ACCEPTANCE',
        [switch]$Resume,
        [string]$Workspace = ''
    )
    $headOutput = @(Invoke-GitFixture -Root $Root -Arguments @('rev-parse','HEAD'))
    $branchOutput = @(Invoke-GitFixture -Root $Root -Arguments @('branch','--show-current'))
    $head = ([string]$headOutput[-1]).Trim()
    $branch = ([string]$branchOutput[-1]).Trim()
    $workspaceValue = if ($Workspace) { $Workspace } else { $Root }
    $allowed = @('docs/executor-fixture.md')
    $contract = [pscustomobject][ordered]@{
        schema = 'eink-task-contract-v1'
        compilerVersion = '0.6.0'
        compilerPolicy = 'DETERMINISTIC_HEURISTIC_V1_WITH_EXACT_SCOPE'
        taskId = $TaskId
        sourceRequest = 'Update the exact fixture documentation file.'
        projectId = 'eink'
        workspace = [IO.Path]::GetFullPath($workspaceValue)
        taskClass = 'DOCS'
        riskLevel = 'LOW'
        hardwareIntent = $false
        visualIntent = $false
        requiresClassificationReview = $false
        requiredCapabilities = @('workspace.verify','repo.edit','git.reviewed-stage','git.commit-push-pr')
        candidateFileScopes = @('docs/**')
        allowedFiles = $allowed
        exactScopeSha256 = Get-EinkExecutorSha256Text -Text ($allowed -join "`n")
        exactFilesRequiredBeforeExecution = $true
        forbiddenActions = @('git.add-all','git.auto-merge','hardware.burn-without-owner')
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
        compiledFromBranch = $branch
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

function Invoke-FixtureExecutor {
    param(
        [Parameter(Mandatory=$true)][string]$Root,
        [Parameter(Mandatory=$true)]$Task,
        [string]$Scenario = 'IMPLEMENT_ALLOWED',
        [string]$ExpectedSha = ''
    )
    $sha = if ($ExpectedSha) { $ExpectedSha } else { [string]$Task.contract.contractSha256 }
    Invoke-EinkCompiledTaskExecutor `
        -RepoRoot $Root `
        -Task $Task `
        -ExpectedContractSha256 $sha `
        -EvidenceRoot (Join-Path $Root '_incoming\executor') `
        -AcceptanceMode `
        -AcceptanceScenario $Scenario
}

function Import-ActualChallengeFunctions {
    $tokens = $null
    $errors = $null
    $ast = [Management.Automation.Language.Parser]::ParseFile(
        $serverPath,
        [ref]$tokens,
        [ref]$errors
    )
    if ($errors.Count -gt 0) { throw 'SERVER_PARSE_FAILED' }
    $names = @(
        'Get-TextSha256',
        'New-ExecutorOwnerChallenge',
        'Test-AndConsumeExecutorOwnerChallenge'
    )
    foreach ($name in $names) {
        $definition = @(
            $ast.FindAll({ param($node) $node -is [Management.Automation.Language.FunctionDefinitionAst] -and $node.Name -eq $name }, $true)
        )
        if ($definition.Count -ne 1) { throw "FUNCTION_EXTRACTION_FAILED: $name" }
        $scriptScoped = $definition[0].Extent.Text -replace (
            '^function\s+' + [regex]::Escape($name)
        ), ("function script:" + $name)
        Invoke-Expression $scriptScoped
    }
}

$realBefore = @(& git -C $repoRoot status --short)
$realBranchBefore = (@(& git -C $repoRoot branch --show-current) -join '').Trim()
$realHeadBefore = (& git -C $repoRoot rev-parse HEAD).Trim()

try {
    [void](New-Item -ItemType Directory -Path $runRoot -Force)
    . $modulePath

    $tokens = $null
    $errors = $null
    foreach ($path in @($modulePath, $serverPath)) {
        [void][Management.Automation.Language.Parser]::ParseFile($path,[ref]$tokens,[ref]$errors)
        Assert-True ($errors.Count -eq 0) ("POWERSHELL_PARSE_" + [IO.Path]::GetFileName($path).ToUpperInvariant())
        $errors = $null
    }

    $server = [IO.File]::ReadAllText($serverPath, [Text.Encoding]::UTF8)
    $index = [IO.File]::ReadAllText($indexPath, [Text.Encoding]::UTF8)
    $registry = Get-Content -LiteralPath $registryPath -Raw -Encoding UTF8 | ConvertFrom-Json
    $actionIds = @($registry.projects[0].actions | ForEach-Object { [string]$_.id })
    Assert-True ($actionIds -contains 'brain-execute-arm' -and $actionIds -contains 'brain-execute') 'EXECUTOR_ACTION_ALLOW_LIST'
    Assert-True ($server -match "'brain-execute-arm'" -and $server -match 'Invoke-EinkBrainExecuteAction -Body \$body') 'EXECUTOR_BACKEND_ROUTES'
    Assert-True ($index -match 'id="einkBrainRunButton"' -and $index -match 'brain-execute-arm' -and $index -match 'brain-execute') 'RUN_COMPILED_TASK_UI_WIRING'
    Assert-True ($index -match 'id="startHarnessButton"' -and $index -match 'START HARNESS') 'START_HARNESS_SERVICE_ACTION_PRESERVED'
    $runHandlerMatch = [regex]::Match(
        $index,
        '\$\("einkBrainRunButton"\)\.addEventListener[\s\S]+?\n    \}\);'
    )
    Assert-True ($runHandlerMatch.Success) 'RUN_HANDLER_EXTRACTED'
    Assert-True (
        $runHandlerMatch.Value -match 'ownerChallenge:\s*armed\.challenge'
    ) 'OWNER_CHALLENGE_UI_TRANSPORT'
    Assert-True (
        $runHandlerMatch.Value -notmatch '\bcommand\s*:' -and
        $runHandlerMatch.Value -notmatch '\bpath\s*:'
    ) 'BROWSER_ARBITRARY_COMMAND_PATH_BLOCKED'
    Assert-True ($server -match 'TASK_ID_MISMATCH' -and $server -match 'OWNER_EXECUTION_CONFIRMATION_REQUIRED') 'SERVER_AUTHORITY_GATES'
    Assert-True (
        [IO.File]::ReadAllText($modulePath) -match 'HARDWARE_VALIDATION_FORBIDDEN'
    ) 'HARDWARE_VALIDATION_EXECUTION_BLOCKED'

    Import-ActualChallengeFunctions
    $script:ExecutorChallengeHash = ''
    $script:ExecutorChallengeExpiresUtc = [DateTime]::MinValue
    $script:ExecutorChallengeTaskId = ''
    $script:ExecutorChallengeContractSha = ''
    $script:ExecutorChallengeScopeSha = ''
    $taskId = 'EINK-ONE-TIME-GATE'
    $contractSha = 'A' * 64
    $scopeSha = 'B' * 64
    $armed = New-ExecutorOwnerChallenge -TaskId $taskId -ContractSha256 $contractSha -ExactScopeSha256 $scopeSha
    Assert-True (-not (Test-AndConsumeExecutorOwnerChallenge -Challenge $armed.challenge -TaskId $taskId -ContractSha256 $contractSha -ExactScopeSha256 ('C' * 64))) 'OWNER_GATE_SCOPE_MISMATCH_BLOCKED'
    Assert-True (-not (Test-AndConsumeExecutorOwnerChallenge -Challenge $armed.challenge -TaskId $taskId -ContractSha256 $contractSha -ExactScopeSha256 $scopeSha)) 'OWNER_GATE_FAILED_ATTEMPT_CONSUMED'
    $armed = New-ExecutorOwnerChallenge -TaskId $taskId -ContractSha256 $contractSha -ExactScopeSha256 $scopeSha
    Assert-True (Test-AndConsumeExecutorOwnerChallenge -Challenge $armed.challenge -TaskId $taskId -ContractSha256 $contractSha -ExactScopeSha256 $scopeSha) 'OWNER_GATE_VALID_ONCE'
    Assert-True (-not (Test-AndConsumeExecutorOwnerChallenge -Challenge $armed.challenge -TaskId $taskId -ContractSha256 $contractSha -ExactScopeSha256 $scopeSha)) 'OWNER_GATE_REPLAY_BLOCKED'

    $normalRoot = New-FixtureRepo -Name 'normal'
    $historicalBefore = Get-FileHash -Algorithm SHA256 -LiteralPath (Join-Path $normalRoot 'bk-13-08-26\preserved.bin')
    $normal = Invoke-FixtureExecutor -Root $normalRoot -Task (New-ContractTask -Root $normalRoot)
    if (-not $normal.Passed) {
        Write-Output ("NORMAL_RESULT: " + ($normal | ConvertTo-Json -Depth 8 -Compress))
    }
    Assert-True ($normal.Passed -and $normal.State -eq 'OWNER_MERGE_REQUIRED') 'NORMAL_REPO_ONLY_OWNER_MERGE_REQUIRED'
    Assert-True ([string]$normal.PrUrl -match '^https://example\.invalid/') 'PR_CREATION_ACCEPTANCE_SIMULATED'
    Assert-True (@($normal.Log) -contains 'AUTO_MERGE: DISABLED') 'NO_AUTO_MERGE'
    Assert-True ($normal.AgentInvocations -eq 0) 'ACCEPTANCE_NO_EXTERNAL_AGENT'
    $historicalAfter = Get-FileHash -Algorithm SHA256 -LiteralPath (Join-Path $normalRoot 'bk-13-08-26\preserved.bin')
    Assert-True ($historicalBefore.Hash -eq $historicalAfter.Hash) 'HISTORICAL_UNTRACKED_PRESERVED'

    $shaRoot = New-FixtureRepo -Name 'sha-mismatch'
    $shaResult = Invoke-FixtureExecutor -Root $shaRoot -Task (New-ContractTask -Root $shaRoot) -ExpectedSha ('F' * 64)
    Assert-True (-not $shaResult.Passed -and $shaResult.Reason -eq 'CONTRACT_SHA_MISMATCH') 'CONTRACT_SHA_MISMATCH_BLOCKED'

    $wrongRoot = New-FixtureRepo -Name 'wrong-workspace'
    $wrongTask = New-ContractTask -Root $wrongRoot -Workspace (Join-Path $runRoot 'not-the-repo')
    $wrong = Invoke-FixtureExecutor -Root $wrongRoot -Task $wrongTask
    Assert-True (-not $wrong.Passed -and $wrong.Reason -eq 'WRONG_WORKSPACE') 'WRONG_WORKSPACE_BLOCKED'

    $dirtyRoot = New-FixtureRepo -Name 'dirty'
    $dirtyTask = New-ContractTask -Root $dirtyRoot
    [IO.File]::AppendAllText((Join-Path $dirtyRoot 'docs\executor-fixture.md'), "dirty`n")
    $dirty = Invoke-FixtureExecutor -Root $dirtyRoot -Task $dirtyTask
    Assert-True (-not $dirty.Passed -and $dirty.Reason -eq 'DIRTY_TRACKED_TREE') 'DIRTY_TRACKED_TREE_BLOCKED'

    $sourceDriftRoot = New-FixtureRepo -Name 'source-drift'
    $sourceDriftTask = New-ContractTask -Root $sourceDriftRoot
    [void](Invoke-GitFixture -Root $sourceDriftRoot -Arguments @('commit','--allow-empty','-m','test: unexpected head'))
    $sourceDrift = Invoke-FixtureExecutor -Root $sourceDriftRoot -Task $sourceDriftTask
    Assert-True (-not $sourceDrift.Passed -and $sourceDrift.Reason -eq 'COMPILED_SOURCE_DRIFT') 'UNEXPECTED_GIT_STATE_BLOCKED'

    $mainRoot = New-FixtureRepo -Name 'main-branch'
    [void](Invoke-GitFixture -Root $mainRoot -Arguments @('branch','-m','main'))
    $mainRemote = Join-Path $runRoot 'main-branch-origin.git'
    [void](Invoke-GitFixture -Root $runRoot -Arguments @('init','--bare',$mainRemote))
    [void](Invoke-GitFixture -Root $mainRoot -Arguments @('remote','add','origin',$mainRemote))
    [void](Invoke-GitFixture -Root $mainRoot -Arguments @('push','-u','origin','main'))
    $mainTask = New-ContractTask -Root $mainRoot
    $mainBranch = Get-EinkExecutorFeatureBranchName -TaskId ([string]$mainTask.taskId)
    $mainResult = Invoke-FixtureExecutor -Root $mainRoot -Task $mainTask
    Assert-True ($mainResult.Passed -and $mainResult.State -eq 'OWNER_MERGE_REQUIRED') 'CLEAN_SYNCED_MAIN_OWNER_MERGE_REQUIRED'
    $mainBranchOutput = @(Invoke-GitFixture -Root $mainRoot -Arguments @('branch','--show-current'))
    Assert-True (([string]$mainBranchOutput[-1]).Trim() -eq $mainBranch) 'MAIN_ENTERED_DETERMINISTIC_TASK_BRANCH'
    Assert-True (@($mainResult.Log) -contains ("FEATURE_BRANCH_READY: " + $mainBranch)) 'MAIN_FEATURE_BRANCH_TRANSITION_RECORDED'

    $stateRoot = New-FixtureRepo -Name 'not-compiled'
    $stateTask = New-ContractTask -Root $stateRoot
    $stateTask.status = 'READY'
    $notCompiled = Invoke-FixtureExecutor -Root $stateRoot -Task $stateTask
    Assert-True (-not $notCompiled.Passed -and $notCompiled.Reason -eq 'TASK_NOT_COMPILED') 'NON_COMPILED_TASK_BLOCKED'

    $driftRoot = New-FixtureRepo -Name 'scope-drift'
    $drift = Invoke-FixtureExecutor -Root $driftRoot -Task (New-ContractTask -Root $driftRoot) -Scenario 'SCOPE_DRIFT'
    Assert-True (-not $drift.Passed -and $drift.Reason -match '^SCOPE_DRIFT:') 'EXACT_SCOPE_DRIFT_BLOCKED'
    Assert-True (-not (Test-Path -LiteralPath (Join-Path $driftRoot 'outside-scope.txt'))) 'SCOPE_DRIFT_NOT_COPIED_TO_PRIMARY'

    $resumeRoot = New-FixtureRepo -Name 'resume'
    [IO.File]::AppendAllText((Join-Path $resumeRoot 'docs\executor-fixture.md'), "`nExisting validated implementation.`n")
    [void](Invoke-GitFixture -Root $resumeRoot -Arguments @('add','--','docs/executor-fixture.md'))
    [void](Invoke-GitFixture -Root $resumeRoot -Arguments @('commit','-m','feat: existing implementation'))
    $resumeHeadOutput = @(Invoke-GitFixture -Root $resumeRoot -Arguments @('rev-parse','HEAD'))
    $resumeHead = ([string]$resumeHeadOutput[-1]).Trim()
    $resume = Invoke-FixtureExecutor -Root $resumeRoot -Task (New-ContractTask -Root $resumeRoot -Resume) -Scenario 'RESUME_EXISTING'
    Assert-True ($resume.Passed -and $resume.State -eq 'OWNER_MERGE_REQUIRED') 'RESUME_EXISTING_EVIDENCE_PASS'
    Assert-True ($resume.AgentInvocations -eq 0 -and $resume.CommitSha -eq $resumeHead) 'RESUME_SKIPS_IMPLEMENTATION'

    $worktreeLines = @(Invoke-GitFixture -Root $normalRoot -Arguments @('worktree','list','--porcelain'))
    Assert-True (@($worktreeLines | Where-Object { $_ -match [regex]::Escape($runRoot + '\') }).Count -eq 0) 'NO_ORPHAN_EXECUTOR_WORKTREE'

    $forbiddenInvocations = @(
        "@('add','.')",
        "@('add','-A')",
        "@('commit','-a')",
        "@('reset','--hard')",
        "@('clean'",
        "@('merge'"
    )
    foreach ($needle in $forbiddenInvocations) {
        Assert-True (-not ([IO.File]::ReadAllText($modulePath) -like "*$needle*")) ("FORBIDDEN_INVOCATION_ABSENT_" + ($needle -replace '[^A-Za-z0-9]','_'))
    }

    $realAfter = @(& git -C $repoRoot status --short)
    Assert-True ((@($realBefore) -join "`n") -eq (@($realAfter) -join "`n")) 'REAL_WORKTREE_STATUS_PRESERVED'
    Assert-True ((@(& git -C $repoRoot branch --show-current) -join '').Trim() -eq $realBranchBefore) 'REAL_BRANCH_PRESERVED'
    Assert-True ((& git -C $repoRoot rev-parse HEAD).Trim() -eq $realHeadBefore) 'REAL_HEAD_PRESERVED'

    Write-Output 'EINK HARNESS COMPILED TASK EXECUTOR ACCEPTANCE: PASS'
}
finally {
    if (Test-Path -LiteralPath $runRoot) {
        $resolvedRun = [IO.Path]::GetFullPath($runRoot)
        $resolvedAcceptance = [IO.Path]::GetFullPath($acceptanceRoot).TrimEnd('\') + '\'
        if (-not $resolvedRun.StartsWith($resolvedAcceptance, [StringComparison]::OrdinalIgnoreCase)) {
            throw 'REFUSING_UNSAFE_ACCEPTANCE_CLEANUP'
        }
        Remove-Item -LiteralPath $resolvedRun -Recurse -Force
    }
}
