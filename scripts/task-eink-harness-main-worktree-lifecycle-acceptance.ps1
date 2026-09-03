[CmdletBinding()]
param()

$ErrorActionPreference = 'Stop'

$sourceRoot = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path
$modulePath = Join-Path $sourceRoot 'tools\harness\main-worktree-lifecycle.ps1'
$launcherPath = Join-Path $sourceRoot 'scripts\eink-control-center.ps1'
$serverPath = Join-Path $sourceRoot 'tools\harness\control-center\server.ps1'
$executorPath = Join-Path $sourceRoot 'tools\harness\compiled-task-executor.ps1'
$runRoot = Join-Path ([IO.Path]::GetTempPath()) (
    'eink-main-worktree-lifecycle-' + [Guid]::NewGuid().ToString('N')
)

function Assert-True {
    param(
        [Parameter(Mandatory=$true)][bool]$Condition,
        [Parameter(Mandatory=$true)][string]$Name
    )
    if (-not $Condition) { throw "ASSERT_FAIL: $Name" }
    Write-Output "$Name`: PASS"
}

function Invoke-FixtureGit {
    param(
        [Parameter(Mandatory=$true)][string]$Root,
        [Parameter(Mandatory=$true)][string[]]$Arguments,
        [switch]$AllowFailure
    )
    $previous = $ErrorActionPreference
    try {
        $ErrorActionPreference = 'Continue'
        $output = @(& git -c ("safe.directory={0}" -f ([IO.Path]::GetFullPath($Root))) -C $Root @Arguments 2>&1 | ForEach-Object { $_.ToString() })
        $result = [pscustomobject]@{ ExitCode = [int]$LASTEXITCODE; Output = @($output) }
        if (-not $AllowFailure -and $result.ExitCode -ne 0) {
            throw "FIXTURE_GIT_FAILED: git $($Arguments -join ' ')`n$($result.Output -join "`n")"
        }
        $result
    }
    finally {
        $ErrorActionPreference = $previous
    }
}

function Get-FixtureGitValue {
    param(
        [Parameter(Mandatory=$true)][string]$Root,
        [Parameter(Mandatory=$true)][string[]]$Arguments
    )
    $result = Invoke-FixtureGit -Root $Root -Arguments $Arguments
    if ($result.Output.Count -eq 0) { throw 'FIXTURE_GIT_VALUE_MISSING' }
    ([string]$result.Output[-1]).Trim()
}

function Write-FixtureText {
    param(
        [Parameter(Mandatory=$true)][string]$Path,
        [Parameter(Mandatory=$true)][string]$Text
    )
    $parent = Split-Path -Parent $Path
    if (-not (Test-Path -LiteralPath $parent -PathType Container)) {
        [void](New-Item -ItemType Directory -Path $parent -Force)
    }
    [IO.File]::WriteAllText($Path, $Text, [Text.UTF8Encoding]::new($false))
}

function Add-OriginCommit {
    param(
        [Parameter(Mandatory=$true)][string]$PublisherRoot,
        [Parameter(Mandatory=$true)][string]$Label
    )
    [IO.File]::AppendAllText(
        (Join-Path $PublisherRoot 'docs\main.txt'),
        "$Label`n",
        [Text.UTF8Encoding]::new($false)
    )
    [void](Invoke-FixtureGit -Root $PublisherRoot -Arguments @('add','--','docs/main.txt'))
    [void](Invoke-FixtureGit -Root $PublisherRoot -Arguments @('commit','-m',"test: $Label"))
    [void](Invoke-FixtureGit -Root $PublisherRoot -Arguments @('push','origin','main'))
    Get-FixtureGitValue -Root $PublisherRoot -Arguments @('rev-parse','HEAD')
}

function Get-WorktreeBranch {
    param([Parameter(Mandatory=$true)][string]$Root)
    $result = Invoke-FixtureGit -Root $Root -Arguments @('branch','--show-current')
    if ($result.Output.Count -eq 0) { return '' }
    ([string]$result.Output[-1]).Trim()
}

$realStatusBefore = @(& git -C $sourceRoot status --short)
$realBranchBefore = (& git -C $sourceRoot branch --show-current).Trim()
$realHeadBefore = (& git -C $sourceRoot rev-parse HEAD).Trim()

try {
    foreach ($file in @($modulePath,$launcherPath,$serverPath,$executorPath)) {
        $tokens = $null
        $errors = $null
        [void][Management.Automation.Language.Parser]::ParseFile(
            $file,
            [ref]$tokens,
            [ref]$errors
        )
        Assert-True ($errors.Count -eq 0) ("POWERSHELL_PARSE_" + [IO.Path]::GetFileName($file).ToUpperInvariant())
    }

    . $modulePath
    . $executorPath

    $moduleSource = [IO.File]::ReadAllText($modulePath, [Text.Encoding]::UTF8)
    $launcherSource = [IO.File]::ReadAllText($launcherPath, [Text.Encoding]::UTF8)
    $serverSource = [IO.File]::ReadAllText($serverPath, [Text.Encoding]::UTF8)
    $executorSource = [IO.File]::ReadAllText($executorPath, [Text.Encoding]::UTF8)
    Assert-True ($launcherSource.Contains('Invoke-EinkHarnessMainWorktreeLifecycle')) 'START_RECONCILE_WIRED'
    Assert-True ($serverSource.Contains('HARNESS_SERVER_MUST_RUN_FROM_CANONICAL_WORKTREE')) 'CANONICAL_SERVER_ENFORCED'
    Assert-True ($serverSource -match 'Invoke-EinkHarnessMainWorktreeLifecycle[\s\S]+SAFE_SWITCH_MAIN_FAILED') 'POST_MERGE_RECONCILE_BEFORE_SWITCH'
    Assert-True ($executorSource.Contains('Invoke-EinkHarnessMainWorktreeLifecycle')) 'EXECUTOR_PREFLIGHT_RECONCILE_WIRED'
    Assert-True (-not (($moduleSource + $launcherSource) -match 'reset\s+--hard|clean\s+-|push\s+--force')) 'FORBIDDEN_GIT_OPERATIONS_ABSENT'

    $origin = Join-Path $runRoot 'origin.git'
    $canonical = Join-Path $runRoot 'Clock'
    $runtime = $canonical + '_HARNESS_RUNTIME'
    $publisher = Join-Path $runRoot 'publisher'
    $userWorktree = Join-Path $runRoot 'owner-worktree'
    [void](New-Item -ItemType Directory -Path $runRoot -Force)
    [void](& git init --bare $origin 2>&1)
    [void](New-Item -ItemType Directory -Path $canonical -Force)
    [void](Invoke-FixtureGit -Root $canonical -Arguments @('init','-b','main'))
    [void](Invoke-FixtureGit -Root $canonical -Arguments @('config','user.name','EINK Acceptance'))
    [void](Invoke-FixtureGit -Root $canonical -Arguments @('config','user.email','eink-acceptance@example.invalid'))
    Write-FixtureText -Path (Join-Path $canonical 'docs\main.txt') -Text "base`n"
    Write-FixtureText -Path (Join-Path $canonical 'docs\lifecycle.txt') -Text "lifecycle`n"
    Write-FixtureText -Path (Join-Path $canonical '.gitignore') -Text "/_incoming/`n"
    [void](Invoke-FixtureGit -Root $canonical -Arguments @('add','--','.gitignore','docs/main.txt','docs/lifecycle.txt'))
    [void](Invoke-FixtureGit -Root $canonical -Arguments @('commit','-m','test: base'))
    [void](Invoke-FixtureGit -Root $canonical -Arguments @('remote','add','origin',$origin))
    [void](Invoke-FixtureGit -Root $canonical -Arguments @('push','-u','origin','main'))
    [void](Invoke-FixtureGit -Root $canonical -Arguments @('switch','-c','task/lifecycle-fixture'))
    [void](Invoke-FixtureGit -Root $canonical -Arguments @('worktree','add',$runtime,'main'))
    Write-FixtureText -Path (Join-Path $runtime 'owner-untracked.txt') -Text 'preserve'

    $first = Invoke-EinkHarnessMainWorktreeLifecycle `
        -RepoRoot $canonical `
        -FetchOrigin `
        -AllowLegacyReservedRuntimeAdoption
    Assert-True $first.Passed 'START_LIFECYCLE_PASS'
    Assert-True $first.RuntimeOwned 'RUNTIME_OWNERSHIP_PROVEN'
    Assert-True $first.RuntimeDetached 'RUNTIME_MAIN_DETACHED'
    Assert-True ((Get-WorktreeBranch -Root $runtime) -eq '') 'RUNTIME_NO_LONG_TERM_MAIN'
    Assert-True (Test-Path -LiteralPath $first.OwnerMarkerPath -PathType Leaf) 'OWNER_MARKER_PERSISTED'
    Assert-True (Test-Path -LiteralPath (Join-Path $runtime 'owner-untracked.txt') -PathType Leaf) 'RUNTIME_UNTRACKED_PRESERVED'

    $previousPreference = $ErrorActionPreference
    try {
        $ErrorActionPreference = 'Continue'
        $cloneOutput = @(& git clone -b main $origin $publisher 2>&1 | ForEach-Object { $_.ToString() })
        $cloneExitCode = [int]$LASTEXITCODE
    }
    finally {
        $ErrorActionPreference = $previousPreference
    }
    if ($cloneExitCode -ne 0) {
        throw "FIXTURE_CLONE_FAILED`n$($cloneOutput -join "`n")"
    }
    [void](Invoke-FixtureGit -Root $publisher -Arguments @('config','user.name','EINK Acceptance'))
    [void](Invoke-FixtureGit -Root $publisher -Arguments @('config','user.email','eink-acceptance@example.invalid'))
    $advancedHead = Add-OriginCommit -PublisherRoot $publisher -Label 'origin advance one'
    [void](Invoke-FixtureGit -Root $runtime -Arguments @('switch','main'))
    $beforeRuntimeHead = Get-FixtureGitValue -Root $runtime -Arguments @('rev-parse','HEAD')
    Assert-True ($beforeRuntimeHead -ne $advancedHead) 'STALE_RUNTIME_FIXTURE_CONFIRMED'

    $second = Invoke-EinkHarnessMainWorktreeLifecycle `
        -RepoRoot $canonical `
        -FetchOrigin `
        -AllowLegacyReservedRuntimeAdoption
    Assert-True $second.RuntimeDetached 'RESTART_RELEASES_RUNTIME_MAIN'
    Assert-True ($second.MainHead -eq $advancedHead) 'STALE_MAIN_RECONCILED_FF_ONLY'
    Assert-True ((Get-WorktreeBranch -Root $runtime) -eq '') 'RUNTIME_DETACHED_AFTER_ORIGIN_ADVANCE'
    Assert-True (Test-Path -LiteralPath (Join-Path $runtime 'owner-untracked.txt') -PathType Leaf) 'NO_UNTRACKED_DELETION_AFTER_RECONCILE'

    [void](Invoke-FixtureGit -Root $canonical -Arguments @('switch','main'))
    $compiledHead = Get-FixtureGitValue -Root $canonical -Arguments @('rev-parse','HEAD')
    $allowed = @('docs/lifecycle.txt')
    $taskId = 'EINK-BRAIN-LIFECYCLE-ACCEPTANCE'
    $contract = [pscustomobject][ordered]@{
        schema = 'eink-task-contract-v1'
        compilerVersion = 'acceptance'
        compilerPolicy = 'MAIN_WORKTREE_LIFECYCLE_ACCEPTANCE'
        taskId = $taskId
        sourceRequest = 'Update exact lifecycle fixture documentation.'
        projectId = 'eink'
        workspace = [IO.Path]::GetFullPath($canonical)
        taskClass = 'HARNESS'
        riskLevel = 'LOW'
        hardwareIntent = $false
        visualIntent = $false
        requiresClassificationReview = $false
        requiredCapabilities = @('repo.edit')
        candidateFileScopes = @('docs/**')
        allowedFiles = $allowed
        exactScopeSha256 = Get-EinkExecutorSha256Text -Text ($allowed -join "`n")
        exactFilesRequiredBeforeExecution = $true
        forbiddenActions = @('git.add-all','git.auto-merge','hardware.burn-without-owner')
        ownerGates = @('OWNER_RUN_COMPILED_CONFIRMATION','OWNER_MERGE')
        acceptanceCriteria = @('git diff --check')
        executionEnabled = $false
        executionEligible = $true
        ownerExecutionRequired = $true
        executionState = 'OWNER_RUN_REQUIRED'
        allowDirtyTrackedTree = $false
        resumeExistingEvidence = $false
        autoMerge = $false
        featureBranch = Get-EinkExecutorFeatureBranchName -TaskId $taskId
        compiledUtc = [DateTime]::UtcNow.ToString('o')
        compiledFromBranch = 'main'
        compiledFromHead = $compiledHead
    }
    $contract | Add-Member contractSha256 (Get-EinkExecutorContractSha256 -Contract $contract)
    $task = [pscustomobject][ordered]@{
        schema = 'eink-brain-task-v1'
        taskId = $taskId
        request = [string]$contract.sourceRequest
        status = 'COMPILED'
        contract = $contract
    }
    $execution = Invoke-EinkCompiledTaskExecutor `
        -RepoRoot $canonical `
        -Task $task `
        -ExpectedContractSha256 $contract.contractSha256 `
        -EvidenceRoot (Join-Path $canonical '_incoming\executor') `
        -AcceptanceMode `
        -AcceptanceScenario 'IMPLEMENT_ALLOWED'
    Write-Output ('FEATURE_EXECUTION_RESULT: ' + ($execution | ConvertTo-Json -Depth 6 -Compress))
    Assert-True $execution.Passed 'FEATURE_EXECUTION_PASS'
    Assert-True ($execution.State -eq 'OWNER_MERGE_REQUIRED') 'FEATURE_EXECUTION_STOPS_OWNER_MERGE'
    Assert-True ($execution.Reason -ne 'STALE_MAIN') 'FEATURE_EXECUTION_NOT_BLOCKED_BY_RUNTIME'
    Assert-True ($execution.AgentInvocations -eq 0) 'ACCEPTANCE_NO_EXTERNAL_AGENT'

    [void](Invoke-FixtureGit -Root $canonical -Arguments @('switch','task/lifecycle-fixture'))
    [void](Invoke-FixtureGit -Root $runtime -Arguments @('switch','main'))
    $postMergeHead = Add-OriginCommit -PublisherRoot $publisher -Label 'origin advance two'
    Assert-True ($postMergeHead -match '^[0-9a-f]{40}$') 'POST_MERGE_PR_MERGED_VERIFIED_FIXTURE'
    $postMergeLifecycle = Invoke-EinkHarnessMainWorktreeLifecycle `
        -RepoRoot $canonical `
        -FetchOrigin `
        -AllowLegacyReservedRuntimeAdoption
    Assert-True (@($postMergeLifecycle.Log) -contains 'FETCH_ORIGIN: PASS') 'POST_MERGE_FETCH_ORIGIN'
    Assert-True $postMergeLifecycle.RuntimeDetached 'POST_MERGE_RUNTIME_RELEASED'
    $postMergeSwitch = Invoke-FixtureGit -Root $canonical -Arguments @('switch','main')
    Assert-True ($postMergeSwitch.ExitCode -eq 0) 'POST_MERGE_SWITCH_MAIN'
    $postMergePull = Invoke-FixtureGit -Root $canonical -Arguments @('pull','--ff-only','origin','main')
    Assert-True ($postMergePull.ExitCode -eq 0) 'POST_MERGE_PULL_FF_ONLY'
    Assert-True ((Get-FixtureGitValue -Root $canonical -Arguments @('rev-parse','HEAD')) -eq $postMergeHead) 'POST_MERGE_HEAD_EQUALS_ORIGIN_MAIN'

    [void](Invoke-FixtureGit -Root $canonical -Arguments @('switch','task/lifecycle-fixture'))
    [void](Invoke-FixtureGit -Root $canonical -Arguments @('worktree','add',$userWorktree,'main'))
    $userHeadBefore = Get-FixtureGitValue -Root $userWorktree -Arguments @('rev-parse','HEAD')
    [void](Add-OriginCommit -PublisherRoot $publisher -Label 'origin advance three')
    $userBlock = ''
    try {
        [void](Invoke-EinkHarnessMainWorktreeLifecycle `
            -RepoRoot $canonical `
            -FetchOrigin `
            -AllowLegacyReservedRuntimeAdoption)
    }
    catch { $userBlock = $_.Exception.Message }
    Assert-True ($userBlock -eq 'MAIN_HELD_BY_UNMANAGED_WORKTREE') 'USER_OWNED_MAIN_WORKTREE_BLOCKED_NOT_CHANGED'
    Assert-True ((Get-WorktreeBranch -Root $userWorktree) -eq 'main') 'USER_WORKTREE_BRANCH_UNTOUCHED'
    Assert-True ((Get-FixtureGitValue -Root $userWorktree -Arguments @('rev-parse','HEAD')) -eq $userHeadBefore) 'USER_WORKTREE_HEAD_UNTOUCHED'

    Assert-True ($serverSource.Contains('AUTO_MERGE: NOT PERFORMED')) 'NO_AUTO_MERGE_PRESERVED'
    Assert-True (-not (($moduleSource + $launcherSource) -match 'J-Link|SPI_ERASE|eink-spi-burn')) 'NO_HARDWARE_LIFECYCLE_ADDED'

    $diffCheck = Invoke-FixtureGit -Root $sourceRoot -Arguments @('diff','--check')
    Assert-True ($diffCheck.ExitCode -eq 0) 'GIT_DIFF_CHECK'
}
finally {
    if (Test-Path -LiteralPath $runRoot -PathType Container) {
        Remove-Item -LiteralPath $runRoot -Recurse -Force
    }
    $realStatusAfter = @(& git -C $sourceRoot status --short)
    $realBranchAfter = (& git -C $sourceRoot branch --show-current).Trim()
    $realHeadAfter = (& git -C $sourceRoot rev-parse HEAD).Trim()
    Assert-True (($realStatusAfter -join "`n") -eq ($realStatusBefore -join "`n")) 'REAL_WORKTREE_STATUS_PRESERVED'
    Assert-True ($realBranchAfter -eq $realBranchBefore) 'REAL_BRANCH_PRESERVED'
    Assert-True ($realHeadAfter -eq $realHeadBefore) 'REAL_HEAD_PRESERVED'
}

Write-Output 'EINK HARNESS MAIN WORKTREE LIFECYCLE ACCEPTANCE: PASS'
