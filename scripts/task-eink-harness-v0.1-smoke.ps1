[CmdletBinding()]
param()

$ErrorActionPreference = 'Stop'
$repoRoot = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path
$expectedRoot = 'D:\EINK\Clock'
if (-not [string]::Equals($repoRoot.TrimEnd('\'), $expectedRoot, [StringComparison]::OrdinalIgnoreCase)) {
    throw 'SAI PROJECT/WORKSPACE'
}

$guard = Join-Path $repoRoot 'tools\harness\workspace-guard.ps1'
$artifactPolicy = Join-Path $repoRoot 'tools\harness\artifact-policy.ps1'
$taskState = Join-Path $repoRoot 'tools\harness\task-state.ps1'
$expectedPaths = @(
    'scripts/task-eink-harness-v0.1-smoke.ps1',
    'tools/harness/artifact-policy.ps1',
    'tools/harness/eink-profile.json',
    'tools/harness/task-state.ps1',
    'tools/harness/workspace-guard.ps1'
)

$tempRoot = Join-Path ([IO.Path]::GetTempPath()) ('eink-harness-' + [guid]::NewGuid().ToString('N'))
New-Item -ItemType Directory -Path $tempRoot | Out-Null
try {
    Push-Location $repoRoot
    $guardText = & $guard
    if ($LASTEXITCODE -ne 0) { throw 'Workspace guard failed.' }
    $guardResult = $guardText | ConvertFrom-Json
    if ($guardResult.result -ne 'PASS') { throw 'Workspace guard did not report PASS.' }

    $underLimit = Join-Path $tempRoot 'raw-65528.bin'
    $overLimit = Join-Path $tempRoot 'raw-65529.bin'
    [IO.File]::WriteAllBytes($underLimit, (New-Object byte[] 65528))
    [IO.File]::WriteAllBytes($overLimit, (New-Object byte[] 65529))

    $underText = & $artifactPolicy -RawBinPath $underLimit
    if ($LASTEXITCODE -ne 0) { throw 'Under-limit artifact was rejected.' }
    $underResult = $underText | ConvertFrom-Json

    $overText = & $artifactPolicy -RawBinPath $overLimit
    $overExit = $LASTEXITCODE
    $overResult = $overText | ConvertFrom-Json
    if ($overExit -eq 0 -or -not ($overResult.errors -contains 'RAW_BIN_EXCEEDS_65528')) {
        throw 'Over-limit artifact was not blocked with RAW_BIN_EXCEEDS_65528.'
    }

    $validText = & $taskState -Action Validate -State NEW
    if ($LASTEXITCODE -ne 0) { throw 'Known state was rejected.' }
    $validResult = $validText | ConvertFrom-Json

    $invalidText = & $taskState -Action Validate -State NOT_A_REAL_STATE
    $invalidExit = $LASTEXITCODE
    $invalidResult = $invalidText | ConvertFrom-Json
    if ($invalidExit -eq 0 -or -not ($invalidResult.errors -contains 'INVALID_STATE')) {
        throw 'Invalid state was accepted.'
    }

    $status = & git status --porcelain=v1 --untracked-files=all
    $actualPaths = @($status | ForEach-Object { $_.Substring(3).Replace('\', '/') } | Sort-Object)
    $scopeMatches = (@(Compare-Object -ReferenceObject ($expectedPaths | Sort-Object) -DifferenceObject $actualPaths).Count -eq 0)
    if (-not $scopeMatches) { throw 'Harness smoke found files outside the intended five-file scope.' }

    [ordered]@{
        result = 'PASS'
        workspace_case = 'PASS'
        artifact_under_limit_case = 'PASS'
        artifact_over_limit_case = 'PASS'
        state_valid_case = 'PASS'
        state_invalid_case = 'PASS'
        intended_paths = $expectedPaths
    } | ConvertTo-Json -Depth 3
} finally {
    Pop-Location
    if (Test-Path -LiteralPath $tempRoot) { Remove-Item -LiteralPath $tempRoot -Recurse -Force }
}
