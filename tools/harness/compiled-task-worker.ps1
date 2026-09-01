[CmdletBinding()]
param(
    [Parameter(Mandatory=$true)][string]$RepoRoot,
    [Parameter(Mandatory=$true)][string]$CurrentTaskPath,
    [Parameter(Mandatory=$true)][string]$HistoryPath,
    [Parameter(Mandatory=$true)][string]$EvidenceRoot,
    [Parameter(Mandatory=$true)][string]$ExpectedTaskId,
    [Parameter(Mandatory=$true)][string]$ExpectedContractSha256,
    [Parameter(Mandatory=$true)][string]$ExpectedExactScopeSha256,
    [Parameter(Mandatory=$true)][string]$AttemptId,
    [switch]$PublicationResume,
    [switch]$AcceptanceMode,
    [ValidateSet('','LIVE_STATUS','BLOCKED_TERMINAL','OWNER_MERGE_REQUIRED_TERMINAL')]
    [string]$AcceptanceScenario = ''
)

$ErrorActionPreference = 'Stop'

$resolvedRepoRoot = [IO.Path]::GetFullPath($RepoRoot).TrimEnd('\')
$executorScript = Join-Path $resolvedRepoRoot 'tools\harness\compiled-task-executor.ps1'
if (-not (Test-Path -LiteralPath $executorScript -PathType Leaf)) {
    throw 'COMPILED_TASK_EXECUTOR_MISSING'
}
. $executorScript

function Read-WorkerJson {
    param([Parameter(Mandatory=$true)][string]$Path)
    if (-not (Test-Path -LiteralPath $Path -PathType Leaf)) { return $null }
    [IO.File]::ReadAllText($Path, [Text.Encoding]::UTF8) | ConvertFrom-Json
}

function Write-WorkerJsonAtomic {
    param(
        [Parameter(Mandatory=$true)][string]$Path,
        [Parameter(Mandatory=$true)]$Value
    )
    $parent = Split-Path -Parent $Path
    if (-not (Test-Path -LiteralPath $parent -PathType Container)) {
        [void](New-Item -ItemType Directory -Path $parent -Force)
    }
    $temporary = Join-Path $parent ('.' + [IO.Path]::GetFileName($Path) + '.' + [Guid]::NewGuid().ToString('N') + '.tmp')
    try {
        [IO.File]::WriteAllText(
            $temporary,
            ($Value | ConvertTo-Json -Depth 12),
            [Text.UTF8Encoding]::new($false)
        )
        Move-Item -LiteralPath $temporary -Destination $Path -Force
    }
    finally {
        if (Test-Path -LiteralPath $temporary -PathType Leaf) {
            Remove-Item -LiteralPath $temporary -Force
        }
    }
}

function Get-WorkerTaskStatus {
    param([Parameter(Mandatory=$true)][string]$Phase)
    switch ($Phase) {
        'PUSHED' { 'PUSHED' }
        'OWNER_MERGE_REQUIRED' { 'OWNER_MERGE_REQUIRED' }
        'WAITING_OWNER' { 'PAUSED_OWNER_ACTION' }
        'BLOCKED' { 'BLOCKED' }
        default { 'EXECUTING' }
    }
}

$task = Read-WorkerJson -Path $CurrentTaskPath
$contractSha = $ExpectedContractSha256.Trim().ToUpperInvariant()
$scopeSha = $ExpectedExactScopeSha256.Trim().ToUpperInvariant()
$startedUtc = [DateTime]::UtcNow.ToString('o')

function Write-ExecutionSnapshot {
    param(
        [Parameter(Mandatory=$true)][string]$Phase,
        [Parameter(Mandatory=$true)][string]$Status,
        [string[]]$Log = @(),
        [string]$Reason = '',
        [string]$CommitSha = '',
        [string]$PrUrl = '',
        $Result = $null,
        [switch]$AppendHistory
    )
    $record = [ordered]@{}
    foreach ($property in $task.PSObject.Properties) {
        $record[$property.Name] = $property.Value
    }
    $record['event'] = $Phase
    $record['status'] = $Status
    $record['updatedUtc'] = [DateTime]::UtcNow.ToString('o')
    $record['execution'] = [ordered]@{
        attemptId = $AttemptId
        active = $Status -in @('EXECUTING','PUSHED')
        phase = $Phase
        reason = $Reason
        contractSha256 = $contractSha
        exactScopeSha256 = $scopeSha
        workerPid = [int]$PID
        startedUtc = $startedUtc
        commitSha = $CommitSha
        prUrl = $PrUrl
        log = @($Log)
        autoMerge = $false
    }
    if ($Result) {
        $record.execution['passed'] = [bool]$Result.Passed
        $record.execution['state'] = [string]$Result.State
        $record.execution['exactFiles'] = @($Result.AllowedFiles)
        $record.execution['agentInvocations'] = [int]$Result.AgentInvocations
        $record.execution['evidenceDir'] = [string]$Result.EvidenceDir
        if ($Result.PSObject.Properties.Name -contains 'ImplementationEvidence') {
            $record.execution['implementationEvidence'] = $Result.ImplementationEvidence
        }
    }
    Write-WorkerJsonAtomic -Path $CurrentTaskPath -Value $record
    if ($AppendHistory) {
        [IO.File]::AppendAllText(
            $HistoryPath,
            (($record | ConvertTo-Json -Depth 12 -Compress) + [Environment]::NewLine),
            [Text.UTF8Encoding]::new($false)
        )
    }
}

try {
    if (-not $task) { throw 'TASK_MISSING' }
    if ($PublicationResume) {
        if ([string]$task.status -ne 'PAUSED_OWNER_ACTION') {
            throw 'PUBLICATION_RESUME_WRONG_STATE'
        }
    }
    elseif ([string]$task.status -ne 'COMPILED') { throw 'TASK_NOT_COMPILED' }
    if ([string]$task.taskId -ne $ExpectedTaskId.Trim()) { throw 'TASK_ID_MISMATCH' }
    if (-not $task.contract) { throw 'CONTRACT_MISSING' }
    if (
        ([string]$task.contract.contractSha256).Trim().ToUpperInvariant() -ne $contractSha -or
        (Get-EinkExecutorContractSha256 -Contract $task.contract) -ne $contractSha
    ) { throw 'CONTRACT_SHA_MISMATCH' }
    if (
        ([string]$task.contract.exactScopeSha256).Trim().ToUpperInvariant() -ne $scopeSha -or
        (Get-EinkExecutorSha256Text -Text (@($task.contract.allowedFiles) -join "`n")) -ne $scopeSha
    ) { throw 'EXACT_SCOPE_SHA_MISMATCH' }

    $startPhase = if ($PublicationResume) { 'PUBLICATION_RESUME_START' } else { 'EXECUTION_START' }
    Write-ExecutionSnapshot -Phase $startPhase -Status 'EXECUTING' -Log @($startPhase)

    if ($PublicationResume) {
        $onPublicationState = {
            param($phase, $lines)
            Write-ExecutionSnapshot `
                -Phase ([string]$phase) `
                -Status (Get-WorkerTaskStatus -Phase ([string]$phase)) `
                -Log @($lines)
        }
        $publicationResult = Invoke-EinkCompiledTaskPublicationResume `
            -RepoRoot $resolvedRepoRoot `
            -Task $task `
            -ExpectedTaskId $ExpectedTaskId `
            -ExpectedContractSha256 $contractSha `
            -ExpectedExactScopeSha256 $scopeSha `
            -AcceptanceMode:$AcceptanceMode `
            -OnState $onPublicationState
        Write-ExecutionSnapshot `
            -Phase ([string]$publicationResult.State) `
            -Status ([string]$publicationResult.State) `
            -Reason ([string]$publicationResult.Reason) `
            -CommitSha ([string]$publicationResult.CommitSha) `
            -PrUrl ([string]$publicationResult.PrUrl) `
            -Log @($publicationResult.Log) `
            -Result $publicationResult `
            -AppendHistory
        if (-not $publicationResult.Passed) { exit 1 }
        exit 0
    }

    if ($AcceptanceMode -and $AcceptanceScenario) {
        Start-Sleep -Milliseconds 700
        Write-ExecutionSnapshot -Phase 'PREFLIGHT' -Status 'EXECUTING' -Log @('EXECUTION_START','PREFLIGHT')
        if ($AcceptanceScenario -eq 'LIVE_STATUS') {
            Start-Sleep -Milliseconds 3000
            Write-ExecutionSnapshot -Phase 'EXECUTING' -Status 'EXECUTING' -Log @('EXECUTION_START','PREFLIGHT','EXECUTING')
            Start-Sleep -Milliseconds 1200
        }
        if ($AcceptanceScenario -eq 'BLOCKED_TERMINAL') {
            Write-ExecutionSnapshot -Phase 'BLOCKED' -Status 'BLOCKED' -Reason 'ACCEPTANCE_BLOCKED_REASON' -Log @('PREFLIGHT','BLOCKED: ACCEPTANCE_BLOCKED_REASON') -AppendHistory
            exit 0
        }
        $acceptanceResult = [pscustomobject]@{
            Passed = $true
            State = 'OWNER_MERGE_REQUIRED'
            Reason = ''
            CommitSha = '1111111111111111111111111111111111111111'
            PrUrl = 'https://example.invalid/eink-live-execution/pull/1'
            AllowedFiles = @($task.contract.allowedFiles)
            AgentInvocations = 0
            EvidenceDir = Join-Path $EvidenceRoot $AttemptId
            Log = @('PREFLIGHT','EXECUTING','VALIDATING','PUSHED','OWNER_MERGE_REQUIRED','AUTO_MERGE: DISABLED')
        }
        Write-ExecutionSnapshot -Phase 'OWNER_MERGE_REQUIRED' -Status 'OWNER_MERGE_REQUIRED' -Log @($acceptanceResult.Log) -CommitSha $acceptanceResult.CommitSha -PrUrl $acceptanceResult.PrUrl -Result $acceptanceResult -AppendHistory
        exit 0
    }

    $onState = {
        param($phase, $lines)
        Write-ExecutionSnapshot `
            -Phase ([string]$phase) `
            -Status (Get-WorkerTaskStatus -Phase ([string]$phase)) `
            -Log @($lines)
    }
    $result = Invoke-EinkCompiledTaskExecutor `
        -RepoRoot $resolvedRepoRoot `
        -Task $task `
        -ExpectedContractSha256 $contractSha `
        -EvidenceRoot $EvidenceRoot `
        -OnState $onState

    $finalPhase = if ([string]$result.State -eq 'PAUSED_OWNER_ACTION') {
        'WAITING_OWNER'
    } else { [string]$result.State }
    Write-ExecutionSnapshot `
        -Phase $finalPhase `
        -Status ([string]$result.State) `
        -Reason ([string]$result.Reason) `
        -CommitSha ([string]$result.CommitSha) `
        -PrUrl ([string]$result.PrUrl) `
        -Log @($result.Log) `
        -Result $result `
        -AppendHistory
}
catch {
    $reason = $_.Exception.Message
    if ($task) {
        Write-ExecutionSnapshot `
            -Phase 'BLOCKED' `
            -Status 'BLOCKED' `
            -Reason $reason `
            -Log @("BLOCKED: $reason") `
            -AppendHistory
    }
    Write-Error $reason
    exit 1
}
