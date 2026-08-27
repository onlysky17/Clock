[CmdletBinding()]
param()

$ErrorActionPreference = 'Stop'

function Get-EinkExecutorSha256Text {
    param(
        [Parameter(Mandatory=$true)]
        [AllowEmptyString()]
        [string]$Text
    )

    $sha = [Security.Cryptography.SHA256]::Create()
    try {
        $bytes = [Text.Encoding]::UTF8.GetBytes($Text)
        ([BitConverter]::ToString($sha.ComputeHash($bytes))).Replace('-', '')
    }
    finally {
        $sha.Dispose()
    }
}

function Get-EinkExecutorContractSha256 {
    param([Parameter(Mandatory=$true)]$Contract)

    $unsigned = [ordered]@{}
    foreach ($property in $Contract.PSObject.Properties) {
        if ($property.Name -ne 'contractSha256') {
            $unsigned[$property.Name] = $property.Value
        }
    }

    Get-EinkExecutorSha256Text -Text (
        $unsigned | ConvertTo-Json -Depth 12 -Compress
    )
}

function Invoke-EinkExecutorNative {
    param(
        [Parameter(Mandatory=$true)][string]$FilePath,
        [Parameter(Mandatory=$true)][string[]]$Arguments,
        [Parameter(Mandatory=$true)][string]$WorkingDirectory
    )

    $previous = $ErrorActionPreference
    Push-Location $WorkingDirectory
    try {
        $ErrorActionPreference = 'Continue'
        $output = @(
            & $FilePath @Arguments 2>&1 |
            ForEach-Object { $_.ToString() }
        )
        $exitCode = $LASTEXITCODE
    }
    finally {
        $ErrorActionPreference = $previous
        Pop-Location
    }

    [pscustomobject]@{
        ExitCode = [int]$exitCode
        Output = @($output)
    }
}

function Get-EinkExecutorGit {
    param(
        [Parameter(Mandatory=$true)][string]$RepoRoot,
        [Parameter(Mandatory=$true)][string[]]$Arguments
    )

    Invoke-EinkExecutorNative `
        -FilePath 'git' `
        -Arguments $Arguments `
        -WorkingDirectory $RepoRoot
}

function Get-EinkExecutorFeatureBranchName {
    param([Parameter(Mandatory=$true)][string]$TaskId)

    $slug = $TaskId.Trim().ToLowerInvariant()
    $slug = [regex]::Replace($slug, '[^a-z0-9]+', '-')
    $slug = $slug.Trim('-')
    if ([string]::IsNullOrWhiteSpace($slug)) {
        throw 'TASK_ID_BRANCH_SLUG_EMPTY'
    }
    if ($slug.Length -gt 80) {
        $slug = $slug.Substring(0, 80).TrimEnd('-')
    }

    "task/$slug"
}

function Get-EinkExecutorGitValue {
    param(
        [Parameter(Mandatory=$true)][string]$RepoRoot,
        [Parameter(Mandatory=$true)][string[]]$Arguments,
        [Parameter(Mandatory=$true)][string]$FailureReason
    )

    $result = Get-EinkExecutorGit -RepoRoot $RepoRoot -Arguments $Arguments
    if ($result.ExitCode -ne 0 -or @($result.Output).Count -eq 0) {
        throw $FailureReason
    }
    ([string]$result.Output[-1]).Trim()
}

function Test-EinkExecutorGitRef {
    param(
        [Parameter(Mandatory=$true)][string]$RepoRoot,
        [Parameter(Mandatory=$true)][string]$Ref
    )

    $result = Get-EinkExecutorGit -RepoRoot $RepoRoot -Arguments @(
        'show-ref', '--verify', '--quiet', $Ref
    )
    $result.ExitCode -eq 0
}

function Assert-EinkExecutorTaskBranchMetadata {
    param(
        [Parameter(Mandatory=$true)][string]$RepoRoot,
        [Parameter(Mandatory=$true)][string]$Branch,
        [Parameter(Mandatory=$true)][string]$TaskId,
        [Parameter(Mandatory=$true)][string]$ContractSha256,
        [Parameter(Mandatory=$true)][string]$CompiledFromHead
    )

    $expected = [ordered]@{
        einkTaskId = $TaskId
        einkContractSha256 = $ContractSha256
        einkCompiledFromHead = $CompiledFromHead
    }
    foreach ($entry in $expected.GetEnumerator()) {
        $value = Get-EinkExecutorGit -RepoRoot $RepoRoot -Arguments @(
            'config', '--local', '--get', "branch.$Branch.$($entry.Key)"
        )
        if (
            $value.ExitCode -ne 0 -or
            @($value.Output).Count -eq 0 -or
            -not ([string]$value.Output[-1]).Trim().Equals(
                [string]$entry.Value,
                [StringComparison]::OrdinalIgnoreCase
            )
        ) {
            throw 'TASK_BRANCH_COLLISION'
        }
    }
}

function Set-EinkExecutorTaskBranchMetadata {
    param(
        [Parameter(Mandatory=$true)][string]$RepoRoot,
        [Parameter(Mandatory=$true)][string]$Branch,
        [Parameter(Mandatory=$true)][string]$TaskId,
        [Parameter(Mandatory=$true)][string]$ContractSha256,
        [Parameter(Mandatory=$true)][string]$CompiledFromHead
    )

    $values = [ordered]@{
        einkTaskId = $TaskId
        einkContractSha256 = $ContractSha256
        einkCompiledFromHead = $CompiledFromHead
    }
    foreach ($entry in $values.GetEnumerator()) {
        $set = Get-EinkExecutorGit -RepoRoot $RepoRoot -Arguments @(
            'config', '--local', "branch.$Branch.$($entry.Key)", [string]$entry.Value
        )
        if ($set.ExitCode -ne 0) { throw 'TASK_BRANCH_METADATA_WRITE_FAILED' }
    }
}

function ConvertTo-EinkExecutorFiles {
    param(
        [Parameter(Mandatory=$true)][string]$RepoRoot,
        [Parameter(Mandatory=$true)]$Values
    )

    $rootPrefix = [IO.Path]::GetFullPath($RepoRoot).TrimEnd('\') + '\'
    $result = @()

    foreach ($value in @($Values)) {
        $relative = ([string]$value).Replace('\', '/').Trim()
        if ([string]::IsNullOrWhiteSpace($relative)) { continue }

        if (
            [IO.Path]::IsPathRooted($relative) -or
            $relative -eq '.' -or
            $relative -match '(^|/)\.\.(/|$)' -or
            $relative.IndexOfAny([char[]]'*?') -ge 0
        ) {
            throw "UNSAFE_EXACT_FILE: $relative"
        }

        $absolute = [IO.Path]::GetFullPath((Join-Path $RepoRoot $relative))
        if (-not $absolute.StartsWith(
            $rootPrefix,
            [StringComparison]::OrdinalIgnoreCase
        )) {
            throw "EXACT_FILE_ESCAPED_WORKSPACE: $relative"
        }

        if (
            $relative -eq 'scripts/task-eink-partial-ghosting-fast-validate.ps1' -or
            $relative.StartsWith('bk-13-08-26/', [StringComparison]::OrdinalIgnoreCase)
        ) {
            throw "HISTORICAL_FILE_FORBIDDEN: $relative"
        }

        $result += $relative
    }

    @($result | Select-Object -Unique | Sort-Object)
}

function Test-EinkExecutorHistoricalUntracked {
    param([string]$StatusLine)

    if (-not $StatusLine.StartsWith('?? ')) { return $false }
    $path = $StatusLine.Substring(3).Replace('\', '/')
    return (
        $path -eq 'bk-13-08-26/' -or
        $path.StartsWith('bk-13-08-26/', [StringComparison]::OrdinalIgnoreCase) -or
        $path -eq 'scripts/task-eink-partial-ghosting-fast-validate.ps1'
    )
}

function Get-EinkExecutorRepoStatus {
    param([Parameter(Mandatory=$true)][string]$RepoRoot)

    $root = Get-EinkExecutorGit -RepoRoot $RepoRoot -Arguments @(
        'rev-parse', '--show-toplevel'
    )
    $branch = Get-EinkExecutorGit -RepoRoot $RepoRoot -Arguments @(
        'branch', '--show-current'
    )
    $head = Get-EinkExecutorGit -RepoRoot $RepoRoot -Arguments @(
        'rev-parse', 'HEAD'
    )
    $status = Get-EinkExecutorGit -RepoRoot $RepoRoot -Arguments @(
        'status', '--porcelain=v1', '--untracked-files=all'
    )
    $staged = Get-EinkExecutorGit -RepoRoot $RepoRoot -Arguments @(
        'diff', '--cached', '--name-only'
    )

    foreach ($result in @($root, $branch, $head, $status, $staged)) {
        if ($result.ExitCode -ne 0) {
            throw 'REPOSITORY_INSPECTION_FAILED'
        }
    }

    $lines = @($status.Output | Where-Object { $_ -match '^.{2} ' })
    $branchName = if (@($branch.Output).Count -gt 0) {
        ([string]$branch.Output[-1]).Trim()
    }
    else { '' }
    [pscustomobject]@{
        Root = $root.Output[-1].Trim()
        Branch = $branchName
        Head = $head.Output[-1].Trim()
        Status = $lines
        Tracked = @($lines | Where-Object { -not $_.StartsWith('?? ') })
        Untracked = @($lines | Where-Object { $_.StartsWith('?? ') })
        Staged = @($staged.Output | Where-Object { $_ })
    }
}

function Get-EinkExecutorChangedFiles {
    param([Parameter(Mandatory=$true)][string]$RepoRoot)

    $status = Get-EinkExecutorRepoStatus -RepoRoot $RepoRoot
    @(
        foreach ($line in $status.Status) {
            $path = $line.Substring(3).Trim().Replace('\', '/')
            if ($path -match ' -> ') {
                $path = ($path -split ' -> ')[-1]
            }
            if (-not (Test-EinkExecutorHistoricalUntracked -StatusLine $line)) {
                $path
            }
        }
    ) | Select-Object -Unique | Sort-Object
}

function Assert-EinkExecutorScope {
    param(
        [Parameter(Mandatory=$true)][string]$RepoRoot,
        [Parameter(Mandatory=$true)][string[]]$AllowedFiles,
        [switch]$RequireChange
    )

    $changed = @(Get-EinkExecutorChangedFiles -RepoRoot $RepoRoot)
    $outside = @($changed | Where-Object { $AllowedFiles -notcontains $_ })

    if ($outside.Count -gt 0) {
        throw ('SCOPE_DRIFT: ' + ($outside -join ', '))
    }
    if ($RequireChange -and $changed.Count -eq 0) {
        throw 'NO_IMPLEMENTATION_CHANGE'
    }

    $changed
}

function Invoke-EinkExecutorValidation {
    param(
        [Parameter(Mandatory=$true)][string]$RepoRoot,
        [Parameter(Mandatory=$true)][string[]]$AllowedFiles
    )

    $evidence = @()
    foreach ($path in $AllowedFiles) {
        if ($path -notmatch '^scripts/task-[^/]+.*\.(ps1|mjs)$') { continue }
        if ($path -match '(?i)(burn|flash|spi|jlink|recovery)') {
            throw "HARDWARE_VALIDATION_FORBIDDEN: $path"
        }
        $absolute = Join-Path $RepoRoot $path
        if (-not (Test-Path -LiteralPath $absolute -PathType Leaf)) {
            throw "VALIDATION_FILE_MISSING: $path"
        }

        $result = if ($path.EndsWith('.ps1', [StringComparison]::OrdinalIgnoreCase)) {
            Invoke-EinkExecutorNative `
                -FilePath 'powershell.exe' `
                -Arguments @('-NoProfile','-ExecutionPolicy','Bypass','-File',$absolute) `
                -WorkingDirectory $RepoRoot
        }
        else {
            Invoke-EinkExecutorNative `
                -FilePath 'node' `
                -Arguments @($absolute) `
                -WorkingDirectory $RepoRoot
        }

        if ($result.ExitCode -ne 0) {
            throw "VALIDATION_FAILED: $path`n$($result.Output -join "`n")"
        }
        $evidence += "VALIDATION_PASS: $path"
    }

    $diffCheck = Get-EinkExecutorGit -RepoRoot $RepoRoot -Arguments @(
        'diff', '--check'
    )
    if ($diffCheck.ExitCode -ne 0) {
        throw ('GIT_DIFF_CHECK_FAILED: ' + ($diffCheck.Output -join ' '))
    }
    $evidence += 'GIT_DIFF_CHECK: PASS'
    $evidence
}

function Copy-EinkExecutorFiles {
    param(
        [Parameter(Mandatory=$true)][string]$SourceRoot,
        [Parameter(Mandatory=$true)][string]$DestinationRoot,
        [Parameter(Mandatory=$true)][string[]]$Files
    )

    foreach ($relative in $Files) {
        $source = Join-Path $SourceRoot $relative
        if (-not (Test-Path -LiteralPath $source -PathType Leaf)) {
            throw "FILE_DELETION_NOT_SUPPORTED: $relative"
        }
        $destination = Join-Path $DestinationRoot $relative
        $parent = Split-Path -Parent $destination
        if (-not (Test-Path -LiteralPath $parent -PathType Container)) {
            [void](New-Item -ItemType Directory -Path $parent -Force)
        }
        [IO.File]::Copy($source, $destination, $true)
    }
}

function Invoke-EinkExecutorCodex {
    param(
        [Parameter(Mandatory=$true)][string]$Worktree,
        [Parameter(Mandatory=$true)]$Contract,
        [Parameter(Mandatory=$true)][string[]]$AllowedFiles,
        [Parameter(Mandatory=$true)][string]$EvidenceDir,
        [ValidateRange(60,3600)][int]$TimeoutSec = 1800
    )

    $codex = Get-Command 'codex.cmd' -ErrorAction Stop
    $promptPath = Join-Path $EvidenceDir 'agent-prompt.txt'
    $stdoutPath = Join-Path $EvidenceDir 'agent.stdout.log'
    $stderrPath = Join-Path $EvidenceDir 'agent.stderr.log'
    $lastMessagePath = Join-Path $EvidenceDir 'agent-final.txt'
    $exact = $AllowedFiles -join "`n- "
    $prompt = @"
Execute this compiled EINK Task Contract in the isolated worktree.

TASK ID: $($Contract.taskId)
CONTRACT SHA256: $($Contract.contractSha256)
TASK CLASS: $($Contract.taskClass)

OWNER REQUEST:
$($Contract.sourceRequest)

EXACT WRITABLE FILES:
- $exact

Rules:
- Modify only the exact writable files above.
- Do not stage, commit, push, create a PR, merge, burn, flash, or access hardware.
- Never use git add ., git add -A, git commit -a, git reset --hard, git clean, or force push.
- Run focused validation where safe, but leave all Git publication to the Harness executor.
- Stop immediately if the task requires a file outside exact scope.
"@
    [IO.File]::WriteAllText($promptPath, $prompt, [Text.UTF8Encoding]::new($false))

    $command = '"{0}" exec -C "{1}" --sandbox workspace-write --ephemeral --color never -o "{2}" - < "{3}"' -f (
        $codex.Source.Replace('"',''),
        $Worktree.Replace('"',''),
        $lastMessagePath.Replace('"',''),
        $promptPath.Replace('"','')
    )
    $process = Start-Process `
        -FilePath 'cmd.exe' `
        -ArgumentList @('/d','/s','/c',('"' + $command + '"')) `
        -WorkingDirectory $Worktree `
        -WindowStyle Hidden `
        -RedirectStandardOutput $stdoutPath `
        -RedirectStandardError $stderrPath `
        -PassThru

    if (-not $process.WaitForExit($TimeoutSec * 1000)) {
        Stop-Process -Id $process.Id -Force
        [void]$process.WaitForExit(5000)
        throw 'CODEX_EXECUTION_TIMEOUT'
    }
    if ($process.ExitCode -ne 0) {
        $stderr = if (Test-Path -LiteralPath $stderrPath) {
            [IO.File]::ReadAllText($stderrPath, [Text.Encoding]::UTF8)
        } else { '' }
        throw "CODEX_EXECUTION_FAILED: $stderr"
    }
}

function Invoke-EinkCompiledTaskExecutor {
    param(
        [Parameter(Mandatory=$true)][string]$RepoRoot,
        [Parameter(Mandatory=$true)]$Task,
        [Parameter(Mandatory=$true)][string]$ExpectedContractSha256,
        [Parameter(Mandatory=$true)][string]$EvidenceRoot,
        [switch]$AcceptanceMode,
        [ValidateSet('IMPLEMENT_ALLOWED','SCOPE_DRIFT','RESUME_EXISTING','')]
        [string]$AcceptanceScenario = '',
        [scriptblock]$OnState
    )

    $resolvedRepoRoot = [IO.Path]::GetFullPath($RepoRoot).TrimEnd('\')
    $resolvedEvidenceRoot = [IO.Path]::GetFullPath($EvidenceRoot).TrimEnd('\')
    $incomingPrefix = [IO.Path]::GetFullPath(
        (Join-Path $resolvedRepoRoot '_incoming')
    ).TrimEnd('\') + '\'
    if (-not $resolvedEvidenceRoot.StartsWith(
        $incomingPrefix,
        [StringComparison]::OrdinalIgnoreCase
    )) {
        throw 'EXECUTOR_EVIDENCE_ROOT_OUTSIDE_WORKSPACE'
    }
    if (
        -not $AcceptanceMode -and
        -not $resolvedRepoRoot.Equals(
            'D:\EINK\Clock',
            [StringComparison]::OrdinalIgnoreCase
        )
    ) {
        throw 'WRONG_WORKSPACE'
    }

    $log = New-Object 'Collections.Generic.List[string]'
    $agentInvocations = 0
    $worktree = ''
    $state = 'BLOCKED'
    $commitSha = ''
    $prUrl = ''
    $evidenceDir = Join-Path $EvidenceRoot (
        ([string]$Task.taskId) + '-' + [Guid]::NewGuid().ToString('N')
    )
    [void](New-Item -ItemType Directory -Path $evidenceDir -Force)

    function Publish-State([string]$Name, [string]$Detail = '') {
        $line = if ($Detail) { "$Name`: $Detail" } else { $Name }
        $log.Add($line)
        if ($OnState) { & $OnState $Name @($log) }
    }

    try {
        Publish-State 'EXECUTION_START'
        if ([string]$Task.status -ne 'COMPILED') {
            throw 'TASK_NOT_COMPILED'
        }
        $contract = $Task.contract
        if (-not $contract) { throw 'CONTRACT_MISSING' }
        $expected = $ExpectedContractSha256.Trim().ToUpperInvariant()
        $stored = ([string]$contract.contractSha256).Trim().ToUpperInvariant()
        $actual = Get-EinkExecutorContractSha256 -Contract $contract
        if ($expected -ne $stored -or $actual -ne $stored) {
            throw 'CONTRACT_SHA_MISMATCH'
        }
        if (-not [bool]$contract.executionEligible -or
            -not [bool]$contract.ownerExecutionRequired) {
            throw 'CONTRACT_EXECUTION_NOT_ELIGIBLE'
        }
        if ([bool]$contract.autoMerge) { throw 'AUTO_MERGE_FORBIDDEN' }
        if ([bool]$contract.hardwareIntent) {
            throw 'OWNER_HARDWARE_GATE_REQUIRED'
        }

        $allowed = @(ConvertTo-EinkExecutorFiles `
            -RepoRoot $RepoRoot `
            -Values $contract.allowedFiles)
        if ($allowed.Count -eq 0) { throw 'EXACT_FILES_REQUIRED' }
        $scopeSha = Get-EinkExecutorSha256Text -Text ($allowed -join "`n")
        if (-not $scopeSha.Equals(
            ([string]$contract.exactScopeSha256).Trim(),
            [StringComparison]::OrdinalIgnoreCase
        )) {
            throw 'EXACT_SCOPE_SHA_MISMATCH'
        }

        Publish-State 'PREFLIGHT'
        $repo = Get-EinkExecutorRepoStatus -RepoRoot $RepoRoot
        $canonical = [IO.Path]::GetFullPath([string]$contract.workspace)
        if (-not [IO.Path]::GetFullPath($repo.Root).Equals(
            $canonical,
            [StringComparison]::OrdinalIgnoreCase
        )) {
            throw 'WRONG_WORKSPACE'
        }
        if ($repo.Staged.Count -gt 0) { throw 'PREEXISTING_STAGED_FILES' }
        if ($repo.Tracked.Count -gt 0 -and -not [bool]$contract.allowDirtyTrackedTree) {
            throw 'DIRTY_TRACKED_TREE'
        }
        $unknownUntracked = @(
            $repo.Untracked |
            Where-Object { -not (Test-EinkExecutorHistoricalUntracked $_) }
        )
        if ($unknownUntracked.Count -gt 0) {
            throw ('UNAPPROVED_UNTRACKED_FILES: ' + ($unknownUntracked -join ', '))
        }
        $resume = [bool]$contract.resumeExistingEvidence -or
            $AcceptanceScenario -eq 'RESUME_EXISTING'
        $compiledBranch = [string]$contract.compiledFromBranch
        $compiledHead = [string]$contract.compiledFromHead
        $taskBranch = Get-EinkExecutorFeatureBranchName -TaskId ([string]$contract.taskId)
        $automaticFeatureBranch = $compiledBranch -eq 'main'
        if (
            $contract.PSObject.Properties.Name -contains 'featureBranch' -and
            [string]$contract.featureBranch -ne $taskBranch
        ) {
            throw 'TASK_BRANCH_CONTRACT_MISMATCH'
        }

        if ($automaticFeatureBranch) {
            $mainHead = Get-EinkExecutorGitValue `
                -RepoRoot $RepoRoot `
                -Arguments @('rev-parse','--verify','refs/heads/main') `
                -FailureReason 'MAIN_REF_MISSING'
            $originMainHead = Get-EinkExecutorGitValue `
                -RepoRoot $RepoRoot `
                -Arguments @('rev-parse','--verify','refs/remotes/origin/main') `
                -FailureReason 'ORIGIN_MAIN_REF_MISSING'
            if (
                $mainHead -ne $originMainHead -or
                $compiledHead -ne $mainHead
            ) {
                throw 'STALE_MAIN'
            }

            $localTaskRef = "refs/heads/$taskBranch"
            $remoteTaskRef = "refs/remotes/origin/$taskBranch"
            $localTaskExists = Test-EinkExecutorGitRef `
                -RepoRoot $RepoRoot `
                -Ref $localTaskRef
            $remoteTaskExists = Test-EinkExecutorGitRef `
                -RepoRoot $RepoRoot `
                -Ref $remoteTaskRef

            if ($repo.Branch -eq 'main') {
                if ($repo.Head -ne $compiledHead) { throw 'COMPILED_SOURCE_DRIFT' }
                if ($localTaskExists) {
                    Assert-EinkExecutorTaskBranchMetadata `
                        -RepoRoot $RepoRoot `
                        -Branch $taskBranch `
                        -TaskId ([string]$contract.taskId) `
                        -ContractSha256 $stored `
                        -CompiledFromHead $compiledHead
                    $switch = Get-EinkExecutorGit -RepoRoot $RepoRoot -Arguments @(
                        'switch', $taskBranch
                    )
                    if ($switch.ExitCode -ne 0) { throw 'TASK_BRANCH_SWITCH_FAILED' }
                }
                else {
                    if ($remoteTaskExists) { throw 'TASK_BRANCH_COLLISION' }
                    $switch = Get-EinkExecutorGit -RepoRoot $RepoRoot -Arguments @(
                        'switch','-c',$taskBranch
                    )
                    if ($switch.ExitCode -ne 0) { throw 'TASK_BRANCH_CREATE_FAILED' }
                    Set-EinkExecutorTaskBranchMetadata `
                        -RepoRoot $RepoRoot `
                        -Branch $taskBranch `
                        -TaskId ([string]$contract.taskId) `
                        -ContractSha256 $stored `
                        -CompiledFromHead $compiledHead
                }
                $repo = Get-EinkExecutorRepoStatus -RepoRoot $RepoRoot
            }
            elseif ($repo.Branch -eq $taskBranch) {
                if (-not $localTaskExists) { throw 'UNEXPECTED_GIT_STATE' }
                Assert-EinkExecutorTaskBranchMetadata `
                    -RepoRoot $RepoRoot `
                    -Branch $taskBranch `
                    -TaskId ([string]$contract.taskId) `
                    -ContractSha256 $stored `
                    -CompiledFromHead $compiledHead
            }
            else {
                throw 'UNEXPECTED_GIT_STATE'
            }

            $taskHead = Get-EinkExecutorGitValue `
                -RepoRoot $RepoRoot `
                -Arguments @('rev-parse','--verify',$localTaskRef) `
                -FailureReason 'TASK_BRANCH_REF_MISSING'
            if ($remoteTaskExists) {
                $remoteTaskHead = Get-EinkExecutorGitValue `
                    -RepoRoot $RepoRoot `
                    -Arguments @('rev-parse','--verify',$remoteTaskRef) `
                    -FailureReason 'TASK_REMOTE_REF_INSPECTION_FAILED'
                if ($remoteTaskHead -ne $taskHead) { throw 'TASK_BRANCH_COLLISION' }
            }
            if (-not $resume -and $taskHead -ne $compiledHead) {
                throw 'TASK_BRANCH_HEAD_DRIFT'
            }
            if ($resume -and $taskHead -eq $compiledHead) {
                throw 'RESUME_EVIDENCE_COMMIT_REQUIRED'
            }
            Publish-State 'FEATURE_BRANCH_READY' $taskBranch
        }
        elseif (
            $repo.Branch -ne $compiledBranch -or
            $repo.Head -ne $compiledHead -or
            $repo.Branch -eq 'main'
        ) {
            throw 'COMPILED_SOURCE_DRIFT'
        }

        if ($resume) {
            Publish-State 'EXECUTING' 'RESUME_EXISTING_EVIDENCE'
            $scopeArguments = if ($automaticFeatureBranch) {
                $ancestor = Get-EinkExecutorGit -RepoRoot $RepoRoot -Arguments @(
                    'merge-base','--is-ancestor',$compiledHead,$repo.Head
                )
                if ($ancestor.ExitCode -ne 0) { throw 'RESUME_EVIDENCE_HISTORY_MISMATCH' }
                @('diff','--name-only',"$compiledHead..$($repo.Head)")
            }
            else {
                @('diff-tree','--no-commit-id','--name-only','-r','HEAD')
            }
            $scope = Get-EinkExecutorGit -RepoRoot $RepoRoot -Arguments $scopeArguments
            if ($scope.ExitCode -ne 0) { throw 'RESUME_SCOPE_INSPECTION_FAILED' }
            $commitFiles = @($scope.Output | Where-Object { $_ } | Sort-Object)
            $outside = @($commitFiles | Where-Object { $allowed -notcontains $_ })
            if ($commitFiles.Count -eq 0 -or $outside.Count -gt 0) {
                throw 'RESUME_EVIDENCE_SCOPE_MISMATCH'
            }
            $commitSha = $repo.Head
            $log.Add('IMPLEMENTATION: SKIPPED_EXISTING_EVIDENCE')
        }
        else {
            Publish-State 'EXECUTING'
            $worktree = Join-Path $evidenceDir 'worktree'
            $add = Get-EinkExecutorGit -RepoRoot $RepoRoot -Arguments @(
                'worktree','add','--detach',$worktree,$repo.Head
            )
            if ($add.ExitCode -ne 0) {
                throw ('ISOLATED_WORKTREE_CREATE_FAILED: ' + ($add.Output -join ' '))
            }

            if ($AcceptanceMode) {
                $first = Join-Path $worktree $allowed[0]
                [IO.File]::AppendAllText(
                    $first,
                    "`n# executor acceptance mutation`n",
                    [Text.UTF8Encoding]::new($false)
                )
                if ($AcceptanceScenario -eq 'SCOPE_DRIFT') {
                    [IO.File]::WriteAllText(
                        (Join-Path $worktree 'outside-scope.txt'),
                        'blocked',
                        [Text.UTF8Encoding]::new($false)
                    )
                }
            }
            else {
                $agentInvocations++
                Invoke-EinkExecutorCodex `
                    -Worktree $worktree `
                    -Contract $contract `
                    -AllowedFiles $allowed `
                    -EvidenceDir $evidenceDir
            }

            $worktreeState = Get-EinkExecutorRepoStatus -RepoRoot $worktree
            if ($worktreeState.Head -ne $repo.Head) {
                throw 'AGENT_GIT_COMMIT_FORBIDDEN'
            }
            if ($worktreeState.Staged.Count -gt 0) {
                throw 'AGENT_STAGING_FORBIDDEN'
            }
            $changed = @(Assert-EinkExecutorScope `
                -RepoRoot $worktree `
                -AllowedFiles $allowed `
                -RequireChange)
            [void](Invoke-EinkExecutorValidation `
                -RepoRoot $worktree `
                -AllowedFiles $allowed)
            Copy-EinkExecutorFiles `
                -SourceRoot $worktree `
                -DestinationRoot $RepoRoot `
                -Files $changed

            [void](Assert-EinkExecutorScope `
                -RepoRoot $RepoRoot `
                -AllowedFiles $allowed `
                -RequireChange)
        }

        Publish-State 'VALIDATING'
        $validation = @(Invoke-EinkExecutorValidation `
            -RepoRoot $RepoRoot `
            -AllowedFiles $allowed)
        foreach ($line in $validation) { $log.Add($line) }

        if ([bool]$contract.visualIntent) {
            $state = 'PAUSED_OWNER_ACTION'
            Publish-State 'WAITING_OWNER' 'OWNER_UI_VISUAL_PASS_REQUIRED'
        }
        elseif (-not $resume) {
            $add = Get-EinkExecutorGit -RepoRoot $RepoRoot -Arguments (
                @('add','--') + $allowed
            )
            if ($add.ExitCode -ne 0) { throw 'EXACT_STAGE_FAILED' }
            $afterStage = Get-EinkExecutorRepoStatus -RepoRoot $RepoRoot
            $outsideStaged = @($afterStage.Staged | Where-Object { $allowed -notcontains $_ })
            if ($afterStage.Staged.Count -eq 0 -or $outsideStaged.Count -gt 0) {
                throw 'EXACT_STAGE_SCOPE_MISMATCH'
            }

            $message = "feat: execute $($contract.taskId)"
            $commit = Get-EinkExecutorGit -RepoRoot $RepoRoot -Arguments @(
                'commit','-m',$message
            )
            if ($commit.ExitCode -ne 0) {
                throw ('COMMIT_FAILED: ' + ($commit.Output -join ' '))
            }
            $commitSha = (Get-EinkExecutorRepoStatus -RepoRoot $RepoRoot).Head
        }

        if ($state -ne 'PAUSED_OWNER_ACTION') {
            if (-not $AcceptanceMode) {
                $current = Get-EinkExecutorRepoStatus -RepoRoot $RepoRoot
                $push = Get-EinkExecutorGit -RepoRoot $RepoRoot -Arguments @(
                    'push','-u','origin',$current.Branch
                )
                if ($push.ExitCode -ne 0) {
                    throw ('PUSH_FAILED: ' + ($push.Output -join ' '))
                }
                Publish-State 'PUSHED'

                $body = @"
## Compiled Task

- Task: `$($contract.taskId)`
- Contract SHA256: `$stored`
- Exact files: $($allowed.Count)
- Auto-merge: disabled

## Validation

$($validation -join "`n")

## Owner Gate

This PR is intentionally open. Owner merge is required.
"@
                $pr = Invoke-EinkExecutorNative `
                    -FilePath 'gh' `
                    -Arguments @(
                        'pr','create','--base','main','--head',$current.Branch,
                        '--title',"$($contract.taskId): compiled task execution",
                        '--body',$body
                    ) `
                    -WorkingDirectory $RepoRoot
                if ($pr.ExitCode -ne 0) {
                    throw ('PR_CREATE_FAILED: ' + ($pr.Output -join ' '))
                }
                $prUrl = @(
                    $pr.Output | Where-Object {
                        $_ -match '^https://github\.com/.+/pull/\d+$'
                    }
                ) | Select-Object -Last 1
                if (-not $prUrl) { throw 'PR_URL_MISSING' }
            }
            else {
                Publish-State 'PUSHED' 'ACCEPTANCE_SIMULATED'
                $prUrl = 'https://example.invalid/eink-compiled-executor/pull/1'
            }

            $state = 'OWNER_MERGE_REQUIRED'
            Publish-State 'OWNER_MERGE_REQUIRED'
            $log.Add('AUTO_MERGE: DISABLED')
        }

        [pscustomobject]@{
            Passed = $true
            State = $state
            CommitSha = $commitSha
            PrUrl = [string]$prUrl
            AllowedFiles = $allowed
            AgentInvocations = $agentInvocations
            EvidenceDir = $evidenceDir
            Log = @($log)
        }
    }
    catch {
        $reason = $_.Exception.Message
        $log.Add("BLOCKED: $reason")
        if ($OnState) { & $OnState 'BLOCKED' @($log) }
        [pscustomobject]@{
            Passed = $false
            State = 'BLOCKED'
            Reason = $reason
            CommitSha = $commitSha
            PrUrl = ''
            AllowedFiles = @()
            AgentInvocations = $agentInvocations
            EvidenceDir = $evidenceDir
            Log = @($log)
        }
    }
    finally {
        if (-not [string]::IsNullOrWhiteSpace($worktree)) {
            [void](Get-EinkExecutorGit -RepoRoot $RepoRoot -Arguments @(
                'worktree','remove','--force',$worktree
            ))
        }
    }
}
