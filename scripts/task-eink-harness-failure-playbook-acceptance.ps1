[CmdletBinding()]
param()

$ErrorActionPreference = 'Stop'

$repoRoot = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path

$playbookPath = Join-Path $repoRoot 'docs\agent\ASSISTANT_FAILURE_PLAYBOOK.md'
$agentsPath   = Join-Path $repoRoot 'AGENTS.md'
$executorPath = Join-Path $repoRoot 'tools\harness\compiled-task-executor.ps1'

function Assert-True {
    param(
        [Parameter(Mandatory=$true)][bool]$Condition,
        [Parameter(Mandatory=$true)][string]$Name
    )

    if (-not $Condition) {
        throw "ASSERT_FAIL: $Name"
    }

    Write-Host "$Name`: PASS"
}

foreach ($path in @($playbookPath, $agentsPath, $executorPath)) {
    Assert-True (Test-Path -LiteralPath $path -PathType Leaf) `
        ("FILE_PRESENT_" + [IO.Path]::GetFileName($path).ToUpperInvariant())
}

$playbook = [IO.File]::ReadAllText(
    $playbookPath,
    [Text.Encoding]::UTF8
)

$agents = [IO.File]::ReadAllText(
    $agentsPath,
    [Text.Encoding]::UTF8
)

$executor = [IO.File]::ReadAllText(
    $executorPath,
    [Text.Encoding]::UTF8
)

$requiredPatterns = @(
    'PS-FINALLY-EXIT',
    'CONFLICT-STAGED-BEFORE-CLEAN',
    'DETACHED-HEAD-ACCEPTANCE',
    'WORKTREE-REGISTRY-MISMATCH',
    'STALE-ACCEPTANCE',
    'TEMP-FIXTURE-RESTORE',
    'POWERSHELL-COMMAND-QUALITY',
    'WINPS-CHILD-EXITCODE',
    'DIAGNOSE-BEFORE-MUTATE'
)

foreach ($pattern in $requiredPatterns) {
    Assert-True ($playbook.Contains($pattern)) `
        ("PLAYBOOK_PATTERN_" + $pattern)
}

Assert-True (
    $agents.Contains('## Failure Playbook Gate') -and
    $agents.Contains('docs/agent/ASSISTANT_FAILURE_PLAYBOOK.md') -and
    $agents.Contains('mandatory execution context')
) 'AGENTS_PLAYBOOK_GATE'

Assert-True (
    $executor.Contains(
        "`$failurePlaybookPath = Join-Path `$Worktree 'docs\agent\ASSISTANT_FAILURE_PLAYBOOK.md'"
    )
) 'EXECUTOR_RESOLVES_PLAYBOOK_FROM_WORKTREE'

Assert-True (
    $executor.Contains("throw 'FAILURE_PLAYBOOK_MISSING'")
) 'EXECUTOR_BLOCKS_MISSING_PLAYBOOK'

Assert-True (
    $executor.Contains("throw 'FAILURE_PLAYBOOK_EMPTY'")
) 'EXECUTOR_BLOCKS_EMPTY_PLAYBOOK'

Assert-True (
    $executor.Contains('FAILURE PLAYBOOK (MANDATORY):') -and
    $executor.Contains('$failurePlaybook')
) 'EXECUTOR_INJECTS_PLAYBOOK_IN_AGENT_PROMPT'

$promptGate = [regex]::Match(
    $executor,
    'FAILURE PLAYBOOK \(MANDATORY\):[\s\S]{0,200}\$failurePlaybook[\s\S]{0,300}Rules:'
)

Assert-True $promptGate.Success `
    'PLAYBOOK_INJECTED_BEFORE_EXECUTION_RULES'

$tokens = $null
$errors = $null

[void][Management.Automation.Language.Parser]::ParseFile(
    $executorPath,
    [ref]$tokens,
    [ref]$errors
)

Assert-True (@($errors).Count -eq 0) `
    'POWERSHELL_PARSE_EXECUTOR'

Write-Host 'FAILURE_PLAYBOOK_ACCEPTANCE: PASS'