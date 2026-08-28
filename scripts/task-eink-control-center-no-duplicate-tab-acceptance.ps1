[CmdletBinding()]
param()

$ErrorActionPreference = 'Stop'

$repoRoot = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path
$launcherPath = Join-Path $repoRoot 'scripts\eink-control-center.ps1'

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

Assert-True `
    (Test-Path -LiteralPath $launcherPath -PathType Leaf) `
    'LAUNCHER_PRESENT'

$text = [IO.File]::ReadAllText(
    $launcherPath,
    [Text.Encoding]::UTF8
)

$tokens = $null
$errors = $null

[void][Management.Automation.Language.Parser]::ParseFile(
    $launcherPath,
    [ref]$tokens,
    [ref]$errors
)

Assert-True `
    (@($errors).Count -eq 0) `
    'LAUNCHER_PARSER'

Assert-True `
    ($text.Contains('function Open-ControlCenter')) `
    'OPEN_FUNCTION_PRESERVED'

Assert-True `
    ($text.Contains('if (-not $NoBrowser)')) `
    'NO_BROWSER_GUARD_PRESERVED'

Assert-True `
    ($text.Contains('Start-Process $url')) `
    'BROWSER_START_PRESERVED'

Assert-True `
    ($text.Contains("Write-Output 'RESULT: ALREADY_RUNNING'")) `
    'ALREADY_RUNNING_RESULT_PRESERVED'

$existingStart = $text.IndexOf('if ($existingStatus) {')
$existingEnd = $text.IndexOf(
    'if ($existingIdentityValid)',
    $existingStart
)

Assert-True `
    ($existingStart -ge 0 -and $existingEnd -gt $existingStart) `
    'ALREADY_RUNNING_BLOCK_FOUND'

$existingBlock = $text.Substring(
    $existingStart,
    $existingEnd - $existingStart
)

Assert-True `
    (-not $existingBlock.Contains('Open-ControlCenter')) `
    'ALREADY_RUNNING_DOES_NOT_OPEN_BROWSER'

$lastOpen = $text.LastIndexOf('Open-ControlCenter')

Assert-True `
    ($lastOpen -gt $existingEnd) `
    'NEW_SERVER_STILL_OPENS_BROWSER'

$openCount = [regex]::Matches(
    $text,
    '\bOpen-ControlCenter\b'
).Count

Assert-True `
    ($openCount -eq 2) `
    'OPEN_CONTROL_CENTER_REFERENCE_COUNT'

& git -C $repoRoot diff --check

Assert-True `
    ($LASTEXITCODE -eq 0) `
    'GIT_DIFF_CHECK'

$status = @(
    & git -C $repoRoot status --porcelain=v1 --untracked-files=all
)

$allowed = @(
    'scripts/eink-control-center.ps1',
    'scripts/task-eink-control-center-no-duplicate-tab-acceptance.ps1',
    'scripts/task-eink-partial-ghosting-fast-validate.ps1'
)

$unexpected = @()

foreach ($line in $status) {
    if ($line.Length -lt 4) {
        continue
    }

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

Assert-True `
    ($unexpected.Count -eq 0) `
    'EXACT_TASK_SCOPE'

Write-Host 'EINK_NO_DUPLICATE_TAB_ACCEPTANCE: PASS'