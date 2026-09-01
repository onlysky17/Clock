[CmdletBinding()]
param()

$ErrorActionPreference = 'Stop'
$repoRoot = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path
$executorPath = Join-Path $repoRoot 'tools\harness\compiled-task-executor.ps1'
$workerPath = Join-Path $repoRoot 'tools\harness\compiled-task-worker.ps1'
$serverPath = Join-Path $repoRoot 'tools\harness\control-center\server.ps1'
$indexPath = Join-Path $repoRoot 'tools\harness\control-center\index.html'
$acceptanceRoot = Join-Path ([IO.Path]::GetTempPath()) 'eink-pub'
$runRoot = Join-Path $acceptanceRoot ([Guid]::NewGuid().ToString('N'))

function Assert-True {
    param([Parameter(Mandatory=$true)][bool]$Condition,[Parameter(Mandatory=$true)][string]$Name)
    if (-not $Condition) { throw "ASSERT_FAIL: $Name" }
    Write-Output "$Name`: PASS"
}

function Invoke-FixtureGit {
    param([Parameter(Mandatory=$true)][string]$Root,[Parameter(Mandatory=$true)][string[]]$Arguments)
    $previous = $ErrorActionPreference
    Push-Location $Root
    try {
        $ErrorActionPreference = 'Continue'
        $output = @(& git @Arguments 2>&1 | ForEach-Object { $_.ToString() })
        $exitCode = $LASTEXITCODE
    }
    finally {
        $ErrorActionPreference = $previous
        Pop-Location
    }
    if ($exitCode -ne 0) { throw "FIXTURE_GIT_FAILED: $($Arguments -join ' ')`n$($output -join "`n")" }
    @($output)
}

function New-PublicationFixture {
    param([Parameter(Mandatory=$true)][string]$Name)
    $root = Join-Path $runRoot $Name
    [void](New-Item -ItemType Directory -Path (Join-Path $root 'docs') -Force)
    [void](New-Item -ItemType Directory -Path (Join-Path $root 'scripts') -Force)
    [IO.File]::WriteAllText((Join-Path $root '.gitignore'),"/_incoming/`n",[Text.UTF8Encoding]::new($false))
    [IO.File]::WriteAllText((Join-Path $root 'docs\publication-fixture.md'),"# Publication fixture`n",[Text.UTF8Encoding]::new($false))
    $validation = @'
$ErrorActionPreference = 'Stop'
$root = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path
$counter = Join-Path $root '_incoming\publication-validation-count.txt'
$parent = Split-Path -Parent $counter
if (-not (Test-Path -LiteralPath $parent -PathType Container)) {
    [void](New-Item -ItemType Directory -Path $parent -Force)
}
$count = if (Test-Path -LiteralPath $counter -PathType Leaf) {
    [int]([IO.File]::ReadAllText($counter,[Text.Encoding]::UTF8).Trim())
} else { 0 }
[IO.File]::WriteAllText($counter,[string]($count + 1),[Text.UTF8Encoding]::new($false))
Write-Output 'PUBLICATION FIXTURE VALIDATION: PASS'
'@
    [IO.File]::WriteAllText((Join-Path $root 'scripts\task-eink-publication-fixture-acceptance.ps1'),$validation,[Text.UTF8Encoding]::new($false))
    [void](Invoke-FixtureGit -Root $root -Arguments @('init','-b','task/publication-fixture'))
    [void](Invoke-FixtureGit -Root $root -Arguments @('config','user.name','EINK Acceptance'))
    [void](Invoke-FixtureGit -Root $root -Arguments @('config','user.email','eink-acceptance@example.invalid'))
    [void](Invoke-FixtureGit -Root $root -Arguments @('add','--','.gitignore','docs/publication-fixture.md','scripts/task-eink-publication-fixture-acceptance.ps1'))
    [void](Invoke-FixtureGit -Root $root -Arguments @('commit','-m','test: publication fixture base'))
    $root
}

function New-CompiledVisualTask {
    param([Parameter(Mandatory=$true)][string]$Root)
    $head = ([string]@(Invoke-FixtureGit -Root $Root -Arguments @('rev-parse','HEAD'))[-1]).Trim()
    $branch = ([string]@(Invoke-FixtureGit -Root $Root -Arguments @('branch','--show-current'))[-1]).Trim()
    $allowed = @('docs/publication-fixture.md','scripts/task-eink-publication-fixture-acceptance.ps1')
    $contract = [pscustomobject][ordered]@{
        schema = 'eink-task-contract-v1'
        compilerVersion = '0.7.0'
        compilerPolicy = 'DETERMINISTIC_HEURISTIC_V1_WITH_EXACT_SCOPE'
        taskId = 'EINK-PUB-ACCEPTANCE'
        sourceRequest = 'Exercise Owner-gated publication continuation.'
        projectId = 'eink'
        workspace = [IO.Path]::GetFullPath($Root)
        taskClass = 'HARNESS'
        riskLevel = 'MEDIUM'
        hardwareIntent = $false
        visualIntent = $true
        requiresClassificationReview = $false
        requiredCapabilities = @('repo.edit','validation.smoke','git.reviewed-stage','git.commit-push-pr')
        candidateFileScopes = @('docs/**','scripts/**')
        allowedFiles = $allowed
        exactScopeSha256 = Get-EinkExecutorSha256Text -Text ($allowed -join "`n")
        exactFilesRequiredBeforeExecution = $true
        forbiddenActions = @('git.add-all','git.auto-merge','hardware.burn-without-owner')
        ownerGates = @('OWNER_RUN_COMPILED_CONFIRMATION','OWNER_UI_VISUAL_PASS','OWNER_PUBLICATION_CONFIRMATION','OWNER_MERGE')
        acceptanceCriteria = @('Validation rerun and exact publication are required.')
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
        taskId = [string]$contract.taskId
        request = [string]$contract.sourceRequest
        event = 'COMPILE'
        status = 'COMPILED'
        contract = $contract
    }
}

function New-PausedFixtureTask {
    param([Parameter(Mandatory=$true)][string]$Root)
    $task = New-CompiledVisualTask -Root $Root
    $initial = Invoke-EinkCompiledTaskExecutor `
        -RepoRoot $Root `
        -Task $task `
        -ExpectedContractSha256 ([string]$task.contract.contractSha256) `
        -EvidenceRoot (Join-Path $Root '_incoming\initial') `
        -AcceptanceMode `
        -AcceptanceScenario 'IMPLEMENT_ALLOWED'
    if (-not $initial.Passed -or $initial.State -ne 'PAUSED_OWNER_ACTION') {
        throw ('INITIAL_PAUSE_FAILED: ' + ($initial | ConvertTo-Json -Depth 10 -Compress))
    }
    $task.status = 'PAUSED_OWNER_ACTION'
    $task.event = 'WAITING_OWNER'
    $task | Add-Member -Force -NotePropertyName execution -NotePropertyValue ([pscustomobject][ordered]@{
        attemptId = 'initial-attempt'
        active = $false
        phase = 'WAITING_OWNER'
        state = 'PAUSED_OWNER_ACTION'
        passed = $true
        contractSha256 = [string]$task.contract.contractSha256
        exactScopeSha256 = [string]$task.contract.exactScopeSha256
        exactFiles = @($initial.AllowedFiles)
        agentInvocations = [int]$initial.AgentInvocations
        evidenceDir = [string]$initial.EvidenceDir
        implementationEvidence = $initial.ImplementationEvidence
        log = @($initial.Log)
        autoMerge = $false
    })
    $task
}

function Invoke-PublicationFixture {
    param(
        [Parameter(Mandatory=$true)][string]$Root,
        [Parameter(Mandatory=$true)]$Task,
        [string]$TaskId = '',
        [string]$ContractSha = '',
        [string]$ScopeSha = ''
    )
    Invoke-EinkCompiledTaskPublicationResume `
        -RepoRoot $Root `
        -Task $Task `
        -ExpectedTaskId $(if ($TaskId) { $TaskId } else { [string]$Task.taskId }) `
        -ExpectedContractSha256 $(if ($ContractSha) { $ContractSha } else { [string]$Task.contract.contractSha256 }) `
        -ExpectedExactScopeSha256 $(if ($ScopeSha) { $ScopeSha } else { [string]$Task.contract.exactScopeSha256 }) `
        -AcceptanceMode
}

function Import-PublicationChallengeFunctions {
    $tokens = $null
    $errors = $null
    $ast = [Management.Automation.Language.Parser]::ParseFile($serverPath,[ref]$tokens,[ref]$errors)
    if ($errors.Count -gt 0) { throw 'SERVER_PARSE_FAILED' }
    foreach ($name in @('Get-TextSha256','New-PublicationOwnerChallenge','Test-AndConsumePublicationOwnerChallenge')) {
        $definition = @($ast.FindAll({ param($node) $node -is [Management.Automation.Language.FunctionDefinitionAst] -and $node.Name -eq $name },$true))
        if ($definition.Count -ne 1) { throw "FUNCTION_EXTRACTION_FAILED: $name" }
        $scriptScoped = $definition[0].Extent.Text -replace ('^function\s+' + [regex]::Escape($name)),("function script:" + $name)
        Invoke-Expression $scriptScoped
    }
}

$realHeadBefore = (& git -C $repoRoot rev-parse HEAD).Trim()
$realStatusBefore = @(& git -C $repoRoot status --porcelain=v1 --untracked-files=all) -join "`n"

try {
    [void](New-Item -ItemType Directory -Path $runRoot -Force)
    . $executorPath
    foreach ($path in @($executorPath,$workerPath,$serverPath,$PSCommandPath)) {
        $tokens = $null
        $errors = $null
        [void][Management.Automation.Language.Parser]::ParseFile($path,[ref]$tokens,[ref]$errors)
        Assert-True ($errors.Count -eq 0) ("POWERSHELL_PARSE_" + [IO.Path]::GetFileName($path).ToUpperInvariant())
    }

    $serverText = [IO.File]::ReadAllText($serverPath,[Text.Encoding]::UTF8)
    $workerText = [IO.File]::ReadAllText($workerPath,[Text.Encoding]::UTF8)
    $executorText = [IO.File]::ReadAllText($executorPath,[Text.Encoding]::UTF8)
    $indexText = [IO.File]::ReadAllText($indexPath,[Text.Encoding]::UTF8)
    Assert-True ($serverText.Contains("'brain-publication-arm'") -and $serverText.Contains("'brain-publication-resume'")) 'PUBLICATION_BACKEND_ROUTES'
    Assert-True ($indexText.Contains('id="einkBrainPublicationButton"') -and $indexText.Contains('APPROVE VALIDATED PUBLICATION')) 'MINIMAL_OWNER_APPROVAL_CONTROL'
    Assert-True ($indexText.Contains('Task ID: ${authority.taskId}') -and $indexText.Contains('Contract SHA: ${authority.contractSha256}') -and $indexText.Contains('Exact files (${exactFiles.length})')) 'CONFIRMATION_SHOWS_BOUND_AUTHORITY'
    Assert-True ($indexText.Contains('paused validated task preserved and nothing published')) 'OWNER_CANCEL_PRESERVES_PAUSE'
    $publicationHandler = [regex]::Match($indexText,'\$\("einkBrainPublicationButton"\)\.addEventListener[\s\S]+?\n    \}\);').Value
    Assert-True ($publicationHandler.IndexOf('window.confirm') -lt $publicationHandler.IndexOf('brain-publication-arm')) 'CANCEL_MINTS_NO_APPROVAL_TOKEN'
    Assert-True ($serverText.Contains('$publicationStarting') -and $serverText.Contains("'PUBLICATION_RESUME'")) 'PUBLICATION_STARTUP_RACE_GUARDED'
    Assert-True ($serverText.Contains('Invoke-EinkBrainCreateAction') -and $serverText.Contains('Invoke-EinkBrainCompileAction') -and $serverText.Contains('Invoke-EinkBrainExecuteAction')) 'CREATE_COMPILE_INITIAL_RUN_PRESERVED'

    Import-PublicationChallengeFunctions
    $script:PublicationChallengeHash = ''
    $script:PublicationChallengeExpiresUtc = [DateTime]::MinValue
    $script:PublicationChallengeTaskId = ''
    $script:PublicationChallengeContractSha = ''
    $script:PublicationChallengeScopeSha = ''
    $script:PublicationChallengeFilesSha = ''
    $gateTask = 'EINK-PUBLICATION-GATE'
    $gateContract = 'A' * 64
    $gateScope = 'B' * 64
    $gateFiles = @('one.txt','two.txt')

    foreach ($case in @(
        @{ Name='WRONG_TASK_REJECTED'; Task='WRONG'; Contract=$gateContract; Scope=$gateScope; Files=$gateFiles },
        @{ Name='WRONG_CONTRACT_REJECTED'; Task=$gateTask; Contract=('C'*64); Scope=$gateScope; Files=$gateFiles },
        @{ Name='WRONG_SCOPE_REJECTED'; Task=$gateTask; Contract=$gateContract; Scope=('D'*64); Files=$gateFiles },
        @{ Name='WRONG_FILES_REJECTED'; Task=$gateTask; Contract=$gateContract; Scope=$gateScope; Files=@('one.txt') }
    )) {
        $armed = New-PublicationOwnerChallenge -TaskId $gateTask -ContractSha256 $gateContract -ExactScopeSha256 $gateScope -AllowedFiles $gateFiles
        $valid = Test-AndConsumePublicationOwnerChallenge -Challenge $armed.challenge -TaskId $case.Task -ContractSha256 $case.Contract -ExactScopeSha256 $case.Scope -AllowedFiles $case.Files
        Assert-True (-not $valid) $case.Name
        Assert-True (-not (Test-AndConsumePublicationOwnerChallenge -Challenge $armed.challenge -TaskId $gateTask -ContractSha256 $gateContract -ExactScopeSha256 $gateScope -AllowedFiles $gateFiles)) ($case.Name + '_TOKEN_CONSUMED')
    }
    $stale = New-PublicationOwnerChallenge -TaskId $gateTask -ContractSha256 $gateContract -ExactScopeSha256 $gateScope -AllowedFiles $gateFiles
    $script:PublicationChallengeExpiresUtc = [DateTime]::UtcNow.AddSeconds(-1)
    Assert-True (-not (Test-AndConsumePublicationOwnerChallenge -Challenge $stale.challenge -TaskId $gateTask -ContractSha256 $gateContract -ExactScopeSha256 $gateScope -AllowedFiles $gateFiles)) 'STALE_APPROVAL_REJECTED'
    $once = New-PublicationOwnerChallenge -TaskId $gateTask -ContractSha256 $gateContract -ExactScopeSha256 $gateScope -AllowedFiles $gateFiles
    Assert-True (Test-AndConsumePublicationOwnerChallenge -Challenge $once.challenge -TaskId $gateTask -ContractSha256 $gateContract -ExactScopeSha256 $gateScope -AllowedFiles $gateFiles) 'VALID_APPROVAL_ACCEPTED_ONCE'
    Assert-True (-not (Test-AndConsumePublicationOwnerChallenge -Challenge $once.challenge -TaskId $gateTask -ContractSha256 $gateContract -ExactScopeSha256 $gateScope -AllowedFiles $gateFiles)) 'REPLAYED_APPROVAL_REJECTED'

    $wrongStateRoot = New-PublicationFixture -Name 'wrong-state'
    $wrongStateTask = New-CompiledVisualTask -Root $wrongStateRoot
    $wrongState = Invoke-PublicationFixture -Root $wrongStateRoot -Task $wrongStateTask
    Assert-True (-not $wrongState.Passed -and $wrongState.Reason -eq 'PUBLICATION_RESUME_WRONG_STATE') 'WRONG_STATE_REJECTED'

    $missingRoot = New-PublicationFixture -Name 'missing-evidence'
    $missingTask = New-PausedFixtureTask -Root $missingRoot
    $missingTask.execution.implementationEvidence = $null
    $missing = Invoke-PublicationFixture -Root $missingRoot -Task $missingTask
    Assert-True (-not $missing.Passed -and $missing.Reason -eq 'VALIDATED_IMPLEMENTATION_EVIDENCE_MISSING') 'MISSING_VALIDATED_IMPLEMENTATION_EVIDENCE_REJECTED'

    $wrongAuthorityRoot = New-PublicationFixture -Name 'wrong-authority'
    $wrongAuthorityTask = New-PausedFixtureTask -Root $wrongAuthorityRoot
    Assert-True ((Invoke-PublicationFixture -Root $wrongAuthorityRoot -Task $wrongAuthorityTask -TaskId 'WRONG').Reason -eq 'TASK_ID_MISMATCH') 'EXECUTOR_WRONG_TASK_REJECTED'
    Assert-True ((Invoke-PublicationFixture -Root $wrongAuthorityRoot -Task $wrongAuthorityTask -ContractSha ('E'*64)).Reason -eq 'CONTRACT_SHA_MISMATCH') 'EXECUTOR_WRONG_CONTRACT_REJECTED'
    Assert-True ((Invoke-PublicationFixture -Root $wrongAuthorityRoot -Task $wrongAuthorityTask -ScopeSha ('F'*64)).Reason -eq 'EXACT_SCOPE_SHA_MISMATCH') 'EXECUTOR_WRONG_SCOPE_REJECTED'

    $scopeDriftRoot = New-PublicationFixture -Name 'scope-drift'
    $scopeDriftTask = New-PausedFixtureTask -Root $scopeDriftRoot
    [IO.File]::WriteAllText((Join-Path $scopeDriftRoot 'outside-scope.txt'),'drift',[Text.UTF8Encoding]::new($false))
    $scopeDrift = Invoke-PublicationFixture -Root $scopeDriftRoot -Task $scopeDriftTask
    Assert-True (-not $scopeDrift.Passed -and $scopeDrift.Reason -match '^SCOPE_DRIFT:') 'SCOPE_DRIFT_REJECTED'

    $diffDriftRoot = New-PublicationFixture -Name 'diff-drift'
    $diffDriftTask = New-PausedFixtureTask -Root $diffDriftRoot
    [IO.File]::AppendAllText((Join-Path $diffDriftRoot 'docs\publication-fixture.md'),"Owner-review drift`n",[Text.UTF8Encoding]::new($false))
    $diffDrift = Invoke-PublicationFixture -Root $diffDriftRoot -Task $diffDriftTask
    Assert-True (-not $diffDrift.Passed -and $diffDrift.Reason -eq 'VALIDATED_IMPLEMENTATION_DIFF_DRIFT') 'VALIDATED_DIFF_DRIFT_REJECTED'

    $validRoot = New-PublicationFixture -Name 'valid'
    $validTask = New-PausedFixtureTask -Root $validRoot
    $validationBefore = [int]([IO.File]::ReadAllText((Join-Path $validRoot '_incoming\publication-validation-count.txt'),[Text.Encoding]::UTF8).Trim())
    $headBefore = ([string]@(Invoke-FixtureGit -Root $validRoot -Arguments @('rev-parse','HEAD'))[-1]).Trim()
    $valid = Invoke-PublicationFixture -Root $validRoot -Task $validTask
    $validationAfter = [int]([IO.File]::ReadAllText((Join-Path $validRoot '_incoming\publication-validation-count.txt'),[Text.Encoding]::UTF8).Trim())
    $headAfter = ([string]@(Invoke-FixtureGit -Root $validRoot -Arguments @('rev-parse','HEAD'))[-1]).Trim()
    Assert-True ($valid.Passed -and $valid.State -eq 'OWNER_MERGE_REQUIRED') 'VALID_CONTINUATION_TERMINAL_OWNER_MERGE_REQUIRED'
    Assert-True ([int]$valid.AgentInvocations -eq 0) 'NO_SECOND_CODEX_EXECUTION'
    Assert-True ($workerText.Contains('Invoke-EinkCompiledTaskPublicationResume')) 'PUBLICATION_WORKER_MODE_WIRED'
    Assert-True ($validationAfter -eq ($validationBefore + 1) -and @($valid.Log) -contains 'VALIDATION_RERUN_PASS') 'VALIDATION_COMMAND_RERUN'
    Assert-True (@($valid.Log | Where-Object { $_ -match '^SCOPE_RECHECKED:' }).Count -eq 1) 'SCOPE_RECHECK_RECORDED'
    Assert-True (@($valid.Log | Where-Object { $_ -match '^EXACT_STAGE_INSPECTED:' }).Count -eq 1) 'EXACT_STAGE_INSPECTED'
    Assert-True ($headAfter -ne $headBefore -and $valid.CommitSha -eq $headAfter) 'EXISTING_VALIDATED_CHANGES_COMMITTED'
    Assert-True (@($valid.Log | Where-Object { $_ -match '^PUSHED:' }).Count -eq 1 -and $valid.PrUrl -match '^https://example\.invalid/') 'PUSH_AND_PR_TRANSITION'
    Assert-True (@($valid.Log) -contains 'AUTO_MERGE: DISABLED') 'NO_AUTO_MERGE'
    Assert-True ((@(& git -C $validRoot status --porcelain=v1 --untracked-files=all) -join '') -eq '') 'PUBLISHED_FIXTURE_TREE_CLEAN'
    Assert-True ($executorText -notmatch "@\('merge'" -and $executorText -notmatch "push.+--force") 'NO_MERGE_OR_FORCE_PUSH_INVOCATION'

    Assert-True ((& git -C $repoRoot rev-parse HEAD).Trim() -eq $realHeadBefore) 'REAL_HEAD_PRESERVED'
    Assert-True ((@(& git -C $repoRoot status --porcelain=v1 --untracked-files=all) -join "`n") -eq $realStatusBefore) 'REAL_WORKTREE_STATUS_PRESERVED'
    Write-Output 'EINK HARNESS OWNER-GATED PUBLICATION RESUME ACCEPTANCE: PASS'
}
finally {
    if (Test-Path -LiteralPath $runRoot -PathType Container) {
        $resolvedRun = [IO.Path]::GetFullPath($runRoot)
        $prefix = [IO.Path]::GetFullPath($acceptanceRoot).TrimEnd('\') + '\'
        if (-not $resolvedRun.StartsWith($prefix,[StringComparison]::OrdinalIgnoreCase)) {
            throw 'REFUSING_UNSAFE_ACCEPTANCE_CLEANUP'
        }
        Remove-Item -LiteralPath $runRoot -Recurse -Force
    }
}
