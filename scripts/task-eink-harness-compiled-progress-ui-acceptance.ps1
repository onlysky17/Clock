[CmdletBinding()]
param()

$ErrorActionPreference = 'Stop'
$repoRoot = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path
$indexPath = Join-Path $repoRoot 'tools\harness\control-center\index.html'
$tempJs = Join-Path ([IO.Path]::GetTempPath()) (
    'eink-compiled-progress-ui-' + [Guid]::NewGuid().ToString('N') + '.js'
)

function Assert-True {
    param(
        [Parameter(Mandatory=$true)][bool]$Condition,
        [Parameter(Mandatory=$true)][string]$Name
    )
    if (-not $Condition) { throw "ASSERT_FAIL: $Name" }
    Write-Output "$Name`: PASS"
}

Assert-True (Test-Path -LiteralPath $indexPath -PathType Leaf) 'INDEX_PRESENT'
$html = [IO.File]::ReadAllText($indexPath, [Text.Encoding]::UTF8)

foreach ($id in @(
    'einkBrainExecutionProgress',
    'einkBrainExecutionProgressPercent',
    'einkBrainExecutionProgressPhase',
    'einkBrainExecutionProgressTrack',
    'einkBrainExecutionProgressFill',
    'einkBrainExecutionProgressReason'
)) {
    Assert-True (
        [regex]::Matches($html, 'id="' + [regex]::Escape($id) + '"').Count -eq 1
    ) ("ID_UNIQUE_" + $id)
}

$executionSection = [regex]::Match(
    $html,
    '(?s)<section id="einkBrainExecutionStatus".*?</section>'
)
Assert-True (
    $executionSection.Success -and
    $executionSection.Value.Contains('einkBrainExecutionProgress')
) 'PROGRESS_VISIBLE_IN_CURRENT_BRAIN_EXECUTION'

Assert-True (
    $html.Contains('role="progressbar"') -and
    $html.Contains('aria-valuemin="0"') -and
    $html.Contains('aria-valuemax="100"')
) 'PROGRESS_ACCESSIBLE'

$logic = [regex]::Match(
    $html,
    '(?s)// EINK_COMPILED_PROGRESS_LOGIC_START(.*?)// EINK_COMPILED_PROGRESS_LOGIC_END'
)
Assert-True $logic.Success 'PROGRESS_LOGIC_FOUND'
Assert-True (
    $logic.Value -cnotmatch '\b(?:setTimeout|setInterval)\s*\(|\bDate\s*\(|\bDate\.now|localExecutionState'
) 'NO_FAKE_TIME_OR_OPTIMISTIC_PROGRESS'
Assert-True (
    $html.Contains('stateNode.textContent = visibleState;') -and
    $html.Contains('stateNode.className = "compiled-execution-state";')
) 'AUTHORITATIVE_STATUS_BADGE_PRESERVED'

$tests = @'
const assert = (condition, name) => {
  if (!condition) throw new Error(`ASSERT_FAIL: ${name}`);
  console.log(`${name}: PASS`);
};
const view = (phase, state = phase, log = [], reason = "") =>
  resolveEinkCompiledProgress(
    { persistedPhase: phase, state, log, reason },
    { status: phase, contract: {} }
  );
const expected = {
  READY: 0, CREATED: 0, COMPILED: 10, OWNER_RUN_REQUIRED: 10,
  EXECUTION_START: 15, PREFLIGHT: 20, FEATURE_BRANCH_READY: 35,
  EXECUTING: 55, VALIDATING: 75, PUSHED: 90,
  OWNER_MERGE_REQUIRED: 95, WAITING_OWNER: 95, COMPLETE: 100, PASS: 100
};
Object.entries(expected).forEach(([phase, percentage]) => {
  assert(view(phase).percentage === percentage, `PHASE_${phase}_${percentage}`);
});
const prerequisite = view(
  "PREFLIGHT",
  "PREFLIGHT",
  ["EXECUTION_START", "PREFLIGHT", "WORKSTATION_PREREQUISITES: PASS"]
);
assert(prerequisite.percentage === 25, "WORKSTATION_PREREQUISITES_PASS_25");
const blocked = view(
  "BLOCKED",
  "BLOCKED",
  ["EXECUTION_START", "PREFLIGHT", "WORKSTATION_PREREQUISITES: PASS", "EXECUTING"],
  "VALIDATION_FAILED"
);
assert(blocked.percentage === 55, "BLOCKED_FREEZES_LATEST_SUCCESS");
assert(blocked.mode === "blocked", "BLOCKED_RED_MODE");
assert(blocked.reason === "VALIDATION_FAILED", "BLOCKED_REASON_SURFACED");
const blockedAfterPass = view("BLOCKED", "BLOCKED", ["PASS"], "LATE_FAILURE");
assert(blockedAfterPass.percentage !== 100, "BLOCKED_NEVER_FALSE_100");
assert(view("EXECUTING").mode === "running", "RUNNING_BLUE_MODE");
assert(view("WAITING_OWNER").mode === "waiting", "WAITING_OWNER_YELLOW_MODE");
assert(view("COMPLETE").mode === "pass", "COMPLETE_GREEN_MODE");
assert(view("READY").mode === "idle", "READY_GRAY_MODE");
const closed = resolveEinkCompiledProgress(
  { persistedPhase: "CLOSED", state: "COMPLETE", log: [] },
  { status: "CLOSED", contract: {} }
);
assert(closed.percentage === 100 && closed.mode === "pass", "CLOSED_EXPOSED_AS_COMPLETE_100");
const compiledOwnerGate = resolveEinkCompiledProgress(
  { persistedPhase: "COMPILED", state: "COMPILED", log: [] },
  { status: "COMPILED", contract: { executionState: "OWNER_RUN_REQUIRED" } }
);
assert(compiledOwnerGate.percentage === 10 && compiledOwnerGate.mode === "waiting", "OWNER_RUN_REQUIRED_10_WAITING");
'@

try {
    [IO.File]::WriteAllText(
        $tempJs,
        $logic.Groups[1].Value + [Environment]::NewLine + $tests,
        [Text.UTF8Encoding]::new($false)
    )
    & node $tempJs
    Assert-True ($LASTEXITCODE -eq 0) 'PROGRESS_BEHAVIOR'
}
finally {
    Remove-Item -LiteralPath $tempJs -Force -ErrorAction SilentlyContinue
}

$scriptMatch = [regex]::Match($html, '(?s)<script>(.*)</script>')
Assert-True $scriptMatch.Success 'INLINE_SCRIPT_FOUND'
try {
    [IO.File]::WriteAllText(
        $tempJs,
        $scriptMatch.Groups[1].Value,
        [Text.UTF8Encoding]::new($false)
    )
    & node --check $tempJs
    Assert-True ($LASTEXITCODE -eq 0) 'INLINE_JS_PARSE'
}
finally {
    Remove-Item -LiteralPath $tempJs -Force -ErrorAction SilentlyContinue
}

& git -C $repoRoot diff --check
Assert-True ($LASTEXITCODE -eq 0) 'GIT_DIFF_CHECK'

$changed = @(
    & git -C $repoRoot status --porcelain=v1 --untracked-files=all |
        ForEach-Object {
            if ($_.Length -ge 4) {
                $path = $_.Substring(3).Replace('\', '/')
                if ($path -match ' -> ') { $path = ($path -split ' -> ')[-1] }
                $path
            }
        }
)
$allowed = @(
    'scripts/task-eink-harness-compiled-progress-ui-acceptance.ps1',
    'tools/harness/control-center/index.html'
)
Assert-True (@($changed | Where-Object { $allowed -notcontains $_ }).Count -eq 0) `
    'EXACT_TASK_SCOPE'

Write-Output 'EINK_HARNESS_COMPILED_PROGRESS_UI_ACCEPTANCE: PASS'
