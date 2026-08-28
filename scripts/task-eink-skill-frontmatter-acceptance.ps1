[CmdletBinding()]
param()

$ErrorActionPreference = 'Stop'

$repoRoot = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path
$skillPath = Join-Path $repoRoot '.codex\skills\eink-automatic\SKILL.md'

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
    (Test-Path -LiteralPath $skillPath -PathType Leaf) `
    'SKILL_PRESENT'

$lines = [IO.File]::ReadAllLines(
    $skillPath,
    [Text.Encoding]::UTF8
)

Assert-True `
    ($lines.Count -ge 6) `
    'SKILL_NOT_TRUNCATED'

Assert-True `
    ($lines[0].Trim() -eq '---') `
    'FRONTMATTER_START'

$closingIndex = -1

for ($i = 1; $i -lt $lines.Count; $i++) {
    if ($lines[$i].Trim() -eq '---') {
        $closingIndex = $i
        break
    }
}

Assert-True `
    ($closingIndex -gt 1) `
    'FRONTMATTER_END'

$frontmatter = @(
    $lines[1..($closingIndex - 1)]
)

$nameLine = @(
    $frontmatter |
    Where-Object { $_ -match '^\s*name\s*:\s*' }
)

$descriptionLine = @(
    $frontmatter |
    Where-Object { $_ -match '^\s*description\s*:\s*' }
)

Assert-True `
    ($nameLine.Count -eq 1) `
    'NAME_FIELD_UNIQUE'

Assert-True `
    ($descriptionLine.Count -eq 1) `
    'DESCRIPTION_FIELD_UNIQUE'

$name = (
    $nameLine[0] -replace '^\s*name\s*:\s*', ''
).Trim()

$description = (
    $descriptionLine[0] -replace '^\s*description\s*:\s*', ''
).Trim()

Assert-True `
    ($name -eq 'eink-automatic') `
    'NAME_VALID'

Assert-True `
    (-not [string]::IsNullOrWhiteSpace($description)) `
    'DESCRIPTION_VALID'

$body = @(
    $lines[($closingIndex + 1)..($lines.Count - 1)]
) -join "`n"

Assert-True `
    ($body.Contains('# EINK Automatic Workflow')) `
    'ORIGINAL_BODY_PRESERVED'

Assert-True `
    ($body.Contains('## Start Every Task With The Gate')) `
    'ORIGINAL_GATE_PRESERVED'

$frontmatterStartCount = @(
    $lines | Where-Object { $_.Trim() -eq '---' }
).Count

Assert-True `
    ($frontmatterStartCount -ge 2) `
    'FRONTMATTER_DELIMITERS_PRESENT'

& git -C $repoRoot diff --check

Assert-True `
    ($LASTEXITCODE -eq 0) `
    'GIT_DIFF_CHECK'

$status = @(
    & git -C $repoRoot status --porcelain=v1 --untracked-files=all
)

$allowed = @(
    '.codex/skills/eink-automatic/SKILL.md',
    'scripts/task-eink-skill-frontmatter-acceptance.ps1',
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

Write-Host 'EINK_SKILL_FRONTMATTER_ACCEPTANCE: PASS'