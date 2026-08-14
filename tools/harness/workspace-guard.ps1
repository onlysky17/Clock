[CmdletBinding()]
param(
    [string]$ProfilePath = (Join-Path $PSScriptRoot 'eink-profile.json'),
    [switch]$AllowDirtyTrackedTree
)

$ErrorActionPreference = 'Stop'

function Invoke-GitText {
    param([string[]]$Arguments)
    $text = & git @Arguments 2>$null
    if ($LASTEXITCODE -ne 0) { return $null }
    return ($text -join "`n").Trim()
}

$profile = Get-Content -LiteralPath $ProfilePath -Raw | ConvertFrom-Json
$expectedWorkspace = [IO.Path]::GetFullPath($profile.workspace.canonicalPath).TrimEnd('\')
$actualWorkspace = [IO.Path]::GetFullPath((Get-Location).Path).TrimEnd('\')
$errors = [System.Collections.Generic.List[string]]::new()
$message = $null

if (-not [string]::Equals($actualWorkspace, $expectedWorkspace, [StringComparison]::OrdinalIgnoreCase)) {
    $errors.Add('WRONG_WORKSPACE')
    $message = 'SAI PROJECT/WORKSPACE'
}

$gitRoot = Invoke-GitText @('rev-parse', '--show-toplevel')
if ($null -eq $gitRoot -or -not [string]::Equals(([IO.Path]::GetFullPath($gitRoot).TrimEnd('\')), $expectedWorkspace, [StringComparison]::OrdinalIgnoreCase)) {
    $errors.Add('WRONG_GIT_ROOT')
    if ($null -eq $message) { $message = 'SAI PROJECT/WORKSPACE' }
}

$branch = Invoke-GitText @('branch', '--show-current')
if ($branch -ne $profile.workspace.defaultBranch) { $errors.Add('WRONG_BRANCH') }

$head = Invoke-GitText @('rev-parse', 'HEAD')
$originMain = Invoke-GitText @('rev-parse', 'origin/main')
if ($profile.workspace.requireHeadEqualsOriginMain -and ($null -eq $head -or $null -eq $originMain -or $head -ne $originMain)) {
    $errors.Add('HEAD_DRIFT')
}

$originUrl = Invoke-GitText @('remote', 'get-url', 'origin')
if ($originUrl -ne $profile.workspace.origin) { $errors.Add('WRONG_REMOTE') }

$statusLines = & git status --porcelain=v1 --untracked-files=all 2>$null
$trackedEntries = @($statusLines | Where-Object { $_ -and -not $_.StartsWith('?? ') })
$untrackedEntries = @($statusLines | Where-Object { $_ -and $_.StartsWith('?? ') })
if ($profile.workspace.requireCleanTrackedTree -and -not $AllowDirtyTrackedTree -and $trackedEntries.Count -gt 0) {
    $errors.Add('DIRTY_TRACKED_TREE')
}

$result = [ordered]@{
    result = if ($errors.Count -eq 0) { 'PASS' } else { 'FAIL' }
    message = $message
    errors = @($errors)
    workspace = $actualWorkspace
    expected_workspace = $expectedWorkspace
    git_root = $gitRoot
    branch = $branch
    head = $head
    origin_main = $originMain
    origin = $originUrl
    tracked_entries = @($trackedEntries)
    untracked_count = $untrackedEntries.Count
    untracked_entries = @($untrackedEntries)
}

$result | ConvertTo-Json -Depth 5
if ($errors.Count -gt 0) { exit 1 }
