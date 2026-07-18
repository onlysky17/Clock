param(
    [switch]$AllowDirty
)

$ErrorActionPreference = "Stop"

$RepoRoot = "D:\EINK\Clock"
$CanonicalSource = "D:\EINK\Clock\firmware\active\HINK213_CLOCK_22_BASE"
$SdkRoot = "D:\EINK\DA14585_SDK_6.0.22.1401"
$SdkProject = "D:\EINK\DA14585_SDK_6.0.22.1401\projects\target_apps\ble_examples\HINK213_CLOCK_22_BASE"
$CanonicalWebUrl = "https://onlysky17.github.io/Clock/test.html"
$RequiredScripts = @(
    "tools\bootstrap-hink213-clock22-base.ps1",
    "tools\sync-hink213-source.ps1",
    "tools\pack-hink.ps1"
)

$failures = New-Object System.Collections.Generic.List[string]

function Add-Check {
    param(
        [string]$Name,
        [bool]$Ok,
        [string]$Detail
    )

    if ($Ok) {
        Write-Host ("[PASS] {0}: {1}" -f $Name, $Detail)
    } else {
        Write-Host ("[FAIL] {0}: {1}" -f $Name, $Detail)
        $failures.Add(("{0}: {1}" -f $Name, $Detail)) | Out-Null
    }
}

function Invoke-Git {
    param([string[]]$GitArgs)

    $output = & git @GitArgs 2>&1
    return @{
        ExitCode = $LASTEXITCODE
        Output = ($output -join "`n").Trim()
    }
}

Write-Host "EINK AUTO PREFLIGHT"
Write-Host ("Workspace: {0}" -f (Get-Location).Path)
Write-Host ""

$repo = Invoke-Git -GitArgs @("rev-parse", "--show-toplevel")
$isGitRepo = $repo.ExitCode -eq 0
Add-Check "Git repo" $isGitRepo $repo.Output

if ($isGitRepo) {
    $actualRoot = $repo.Output.Replace("/", "\")
    Add-Check "Repo path" ($actualRoot -ieq $RepoRoot) $repo.Output
} else {
    Add-Check "Repo path" $false "not a Git repository"
}

$branch = Invoke-Git -GitArgs @("branch", "--show-current")
Add-Check "Branch" ($branch.ExitCode -eq 0 -and $branch.Output.Length -gt 0) $branch.Output

$head = Invoke-Git -GitArgs @("rev-parse", "HEAD")
$originMain = Invoke-Git -GitArgs @("rev-parse", "origin/main")
$headOk = $head.ExitCode -eq 0
$originOk = $originMain.ExitCode -eq 0
Add-Check "HEAD" $headOk $head.Output
Add-Check "origin/main" $originOk $originMain.Output
if ($headOk -and $originOk -and $branch.Output -eq "main") {
    Add-Check "HEAD equals origin/main on main" ($head.Output -eq $originMain.Output) ("HEAD={0}; origin/main={1}" -f $head.Output, $originMain.Output)
} elseif ($headOk -and $originOk) {
    $baseCheck = Invoke-Git -GitArgs @("merge-base", "--is-ancestor", "origin/main", "HEAD")
    Add-Check "Branch contains origin/main" ($baseCheck.ExitCode -eq 0) ("HEAD={0}; origin/main={1}" -f $head.Output, $originMain.Output)
} else {
    Add-Check "HEAD/origin relationship" $false ("HEAD={0}; origin/main={1}" -f $head.Output, $originMain.Output)
}

$status = Invoke-Git -GitArgs @("status", "--short", "--untracked-files=all")
$statusOk = $status.ExitCode -eq 0
$treeClean = $statusOk -and $status.Output.Length -eq 0
if ($treeClean) {
    Add-Check "Working tree" $true "clean"
} elseif ($statusOk -and $AllowDirty) {
    Write-Host "[WARN] Working tree is dirty and -AllowDirty was provided."
    Write-Host "[WARN] Use -AllowDirty only for foundation creation/review or explicit Owner-approved exceptions."
    Write-Host $status.Output
    Add-Check "Working tree" $true "dirty allowed by explicit -AllowDirty"
} elseif ($statusOk) {
    Add-Check "Working tree" $false ("dirty; rerun only with -AllowDirty if Owner explicitly approved this exception. Status:`n{0}" -f $status.Output)
} else {
    Add-Check "Working tree" $false $status.Output
}

Add-Check "Canonical source" (Test-Path -LiteralPath $CanonicalSource -PathType Container) $CanonicalSource
Add-Check "SDK root" (Test-Path -LiteralPath $SdkRoot -PathType Container) $SdkRoot
Add-Check "SDK project" (Test-Path -LiteralPath $SdkProject -PathType Container) $SdkProject

foreach ($script in $RequiredScripts) {
    Add-Check ("Required script {0}" -f $script) (Test-Path -LiteralPath (Join-Path $RepoRoot $script) -PathType Leaf) $script
}

$docFiles = Get-ChildItem -LiteralPath (Join-Path $RepoRoot "docs") -Recurse -File -ErrorAction SilentlyContinue
$urlMatches = @()
foreach ($file in $docFiles) {
    $match = Select-String -LiteralPath $file.FullName -SimpleMatch $CanonicalWebUrl -ErrorAction SilentlyContinue
    if ($match) {
        $urlMatches += $file.FullName.Replace($RepoRoot + "\", "")
    }
}
Add-Check "Canonical web URL in docs/rules" ($urlMatches.Count -gt 0) $(if ($urlMatches.Count -gt 0) { ($urlMatches | Select-Object -Unique | Sort-Object) -join ", " } else { $CanonicalWebUrl })

Write-Host ""
if ($failures.Count -eq 0) {
    Write-Host "EINK AUTO PREFLIGHT PASS"
    exit 0
}

Write-Host "Failures:"
foreach ($failure in $failures) {
    Write-Host ("- {0}" -f $failure)
}
Write-Host "EINK AUTO PREFLIGHT FAIL"
exit 1
