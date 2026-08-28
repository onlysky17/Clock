[CmdletBinding()]
param()

$ErrorActionPreference = 'Stop'

$repoRoot = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path
$indexPath = Join-Path $repoRoot 'tools\harness\control-center\index.html'

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

Assert-True (Test-Path -LiteralPath $indexPath -PathType Leaf) `
    'INDEX_PRESENT'

$html = [IO.File]::ReadAllText(
    $indexPath,
    [Text.Encoding]::UTF8
)

Assert-True ($html.Contains('EINK OWNER UI CLEANUP V1')) `
    'OWNER_UI_MARKER'

$criticalIds = @(
    'einkBrainRequest',
    'einkBrainExactFilesInput',
    'einkBrainCreateButton',
    'einkBrainCompileButton',
    'einkBrainRunButton',
    'einkBrainHistorySelect',
    'einkBrainResumeButton',
    'einkBrainArchiveButton',
    'einkBrainExecutionStatus',
    'einkBrainExecutionLog',
    'einkBrainCurrentId',
    'einkBrainCurrentStatus',
    'einkBrainContractVisualizer',
    'prepareButton',
    'burnButton',
    'startHarnessButton',
    'restartHarnessButton',
    'refreshButton',
    'stopButton'
)

foreach ($id in $criticalIds) {
    $count = [regex]::Matches(
        $html,
        'id="' + [regex]::Escape($id) + '"'
    ).Count

    Assert-True ($count -eq 1) `
        ("ID_UNIQUE_" + $id)
}

Assert-True (
    $html.Contains('classList.add("eink-primary-actions")') -and
    $html.Contains('CREATE TASK') -and
    $html.Contains('COMPILE TASK') -and
    $html.Contains('RUN COMPILED TASK')
) 'PRIMARY_FLOW_CREATE_COMPILE_RUN'

Assert-True (
    $html.Contains('Tác vụ phụ / lịch sử') -and
    $html.Contains('eink-secondary-tools')
) 'SECONDARY_ACTIONS_COLLAPSED'

Assert-True (
    $html.Contains('Chi tiết kỹ thuật') -and
    $html.Contains('eink-tech-details')
) 'TECHNICAL_DETAILS_COLLAPSED'

Assert-True (
    $html.Contains('lines.slice(-8)') -and
    $html.Contains('einkBrainExecutionLogFull') -and
    $html.Contains('Mở log đầy đủ')
) 'EXECUTION_LOG_COMPACT_WITH_FULL_LOG'

Assert-True (
    $html.Contains('contract.hardwareIntent === true') -and
    $html.Contains('"einkHardwarePhysicalGate"') -and
    $html.Contains('"einkHardwareArtifactPanel"') -and
    $html.Contains('node.classList.toggle("hidden", !hardwareIntent)')
) 'HARDWARE_VISIBILITY_FOLLOWS_CONTRACT'

Assert-True (
    $html.Contains('einkOwnerNextAction') -and
    $html.Contains('"ĐANG CHẠY"') -and
    $html.Contains('"OWNER MERGE"') -and
    $html.Contains('"CHECK GATE"')
) 'OWNER_NEXT_ACTION_PRESENT'

$scriptMatch = [regex]::Match(
    $html,
    '(?s)<script>(.*)</script>'
)

Assert-True $scriptMatch.Success `
    'INLINE_SCRIPT_FOUND'

$tmpJs = Join-Path $env:TEMP (
    'eink-ui-cleanup-acceptance-' +
    [Guid]::NewGuid().ToString('N') +
    '.js'
)

try {
    [IO.File]::WriteAllText(
        $tmpJs,
        $scriptMatch.Groups[1].Value,
        [Text.UTF8Encoding]::new($false)
    )

    & node --check $tmpJs

    Assert-True ($LASTEXITCODE -eq 0) `
        'INLINE_JS_PARSE'
}
finally {
    Remove-Item -LiteralPath $tmpJs `
        -Force `
        -ErrorAction SilentlyContinue
}

& git -C $repoRoot diff --check

Assert-True ($LASTEXITCODE -eq 0) `
    'GIT_DIFF_CHECK'

$status = @(
    & git -C $repoRoot status --porcelain=v1 --untracked-files=all
)

Assert-True ($LASTEXITCODE -eq 0) `
    'GIT_STATUS_READ'

$allowed = @(
    'tools/harness/control-center/index.html',
    'scripts/task-eink-harness-ui-cleanup-acceptance.ps1',
    'scripts/task-eink-partial-ghosting-fast-validate.ps1'
)

$unexpected = @()

foreach ($line in $status) {
    if ($line.Length -lt 4) { continue }

    $path = $line.Substring(3).Replace('\', '/')

    if ($path -match ' -> ') {
        $path = ($path -split ' -> ')[-1]
    }

    if ($path.StartsWith('bk-13-08-26/')) {
        continue
    }

    if ($allowed -notcontains $path) {
        $unexpected += $path
    }
}

Assert-True ($unexpected.Count -eq 0) `
    'EXACT_TASK_SCOPE'

Write-Host 'EINK_UI_CLEANUP_ACCEPTANCE: PASS'