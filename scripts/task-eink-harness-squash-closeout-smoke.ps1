[CmdletBinding()]
param()

$ErrorActionPreference = 'Stop'

$repoRoot = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path
$runnerPath = Join-Path $repoRoot 'scripts\eink.ps1'

function Assert-True {
    param(
        [bool]$Condition,
        [string]$Message
    )

    if (-not $Condition) {
        throw $Message
    }
}

Assert-True (Test-Path -LiteralPath $runnerPath -PathType Leaf) 'Missing canonical runner.'

$tokens = $null
$parseErrors = $null
[void][System.Management.Automation.Language.Parser]::ParseFile(
    $runnerPath,
    [ref]$tokens,
    [ref]$parseErrors
)
Assert-True (@($parseErrors).Count -eq 0) ('Runner parse error: ' + (@($parseErrors) -join '; '))

$runnerSource = Get-Content -LiteralPath $runnerPath -Raw

Assert-True ($runnerSource -match '\[string\]\$SourceHead') 'Missing SourceHead merge evidence parameter.'
Assert-True ($runnerSource -match '\[string\]\$MergeCommit') 'Missing MergeCommit merge evidence parameter.'
Assert-True ($runnerSource -match 'MERGE_EVIDENCE_REQUIRED') 'Missing explicit-evidence gate.'
Assert-True ($runnerSource -match 'MERGE_EVIDENCE_INVALID') 'Missing invalid-evidence rejection.'
Assert-True ($runnerSource -match 'MERGE_NOT_IN_MAIN') 'Missing merge ancestry rejection.'
Assert-True ($runnerSource -match 'MERGE_TREE_MISMATCH') 'Missing squash tree mismatch rejection.'
Assert-True ($runnerSource -match 'SQUASH_TREE_MATCH') 'Missing squash tree-match success evidence.'
Assert-True ($runnerSource -match 'merge-base.*--is-ancestor.*sourceHead.*main') 'Normal merge ancestry path was not preserved.'

$sourceHead = '1991723f3b8eb73cb9bceb8057413d2a7f73d787'
$mergeCommit = '103307f06eb7ba10d92a291a51ea9e68765af90b'

$resolvedSource = (& git -C $repoRoot rev-parse --verify "$sourceHead^{commit}").Trim()
Assert-True ($LASTEXITCODE -eq 0 -and $resolvedSource -eq $sourceHead) 'Known source-head fixture is unavailable.'

$resolvedMerge = (& git -C $repoRoot rev-parse --verify "$mergeCommit^{commit}").Trim()
Assert-True ($LASTEXITCODE -eq 0 -and $resolvedMerge -eq $mergeCommit) 'Known squash-merge fixture is unavailable.'

& git -C $repoRoot merge-base --is-ancestor $mergeCommit main
Assert-True ($LASTEXITCODE -eq 0) 'Known squash merge is not in main.'

$sourceTree = (& git -C $repoRoot rev-parse "$sourceHead^{tree}").Trim()
$mergeTree = (& git -C $repoRoot rev-parse "$mergeCommit^{tree}").Trim()
Assert-True ($sourceTree -eq $mergeTree) 'Known PR #170 squash trees are not equivalent.'

$parentCommit = (& git -C $repoRoot rev-parse "$mergeCommit^").Trim()
$parentTree = (& git -C $repoRoot rev-parse "$parentCommit^{tree}").Trim()
Assert-True ($sourceTree -ne $parentTree) 'Mismatch fixture unexpectedly matches the source tree.'

$badCommit = '0000000000000000000000000000000000000000'
$previousPreference = $ErrorActionPreference
try {
    $ErrorActionPreference = 'Continue'
    & git -C $repoRoot cat-file -e "$badCommit^{commit}" 2>$null
    $badExit = $LASTEXITCODE
}
finally {
    $ErrorActionPreference = $previousPreference
}
Assert-True ($badExit -ne 0) 'Invalid merge evidence fixture was unexpectedly accepted by git.'

Write-Output 'EINK HARNESS SQUASH CLOSEOUT SMOKE: PASS'
Write-Output 'POWERSHELL_PARSE: PASS'
Write-Output 'EXPLICIT_EVIDENCE_PARAMETERS: PASS'
Write-Output 'NORMAL_MERGE_PATH_PRESERVED: PASS'
Write-Output 'SQUASH_MERGE_IN_MAIN: PASS'
Write-Output 'SQUASH_TREE_EQUIVALENCE: PASS'
Write-Output 'TREE_MISMATCH_FIXTURE: PASS'
Write-Output 'INVALID_EVIDENCE_FIXTURE: PASS'
