[CmdletBinding()]
param()

$ErrorActionPreference = 'Stop'

$expectedRoot = 'D:\EINK\Clock'
$expectedBranch = 'task-d/fw-autonomous-clock-ble-disconnect-001'
$expectedOrigin = 'https://github.com/onlysky17/Clock.git'
$sourceRel = 'firmware/active/HINK213_CLOCK_22_BASE/src/user_peripheral.c'

function Stop-Fix([string]$Reason) {
    Write-Output 'EINK FW FIX: BLOCKED'
    Write-Output "REASON: $Reason"
    exit 1
}

$root = (& git rev-parse --show-toplevel 2>$null).Trim() -replace '/', '\'
if ($root -ne $expectedRoot) {
    Write-Output 'SAI PROJECT/WORKSPACE'
    exit 1
}

$branch = (& git branch --show-current 2>$null).Trim()
if ($branch -ne $expectedBranch) { Stop-Fix "WRONG_BRANCH: $branch" }

$origin = (& git remote get-url origin 2>$null).Trim()
if ($origin -ne $expectedOrigin) { Stop-Fix "WRONG_REMOTE: $origin" }

$trackedDirty = @(& git status --porcelain=v1 --untracked-files=all | Where-Object { $_ -and -not $_.StartsWith('?? ') })
if ($trackedDirty.Count -gt 0) {
    $trackedDirty | ForEach-Object { Write-Output "DIRTY: $_" }
    Stop-Fix 'DIRTY_TRACKED_TREE'
}

$source = Join-Path $expectedRoot $sourceRel
if (-not (Test-Path -LiteralPath $source -PathType Leaf)) { Stop-Fix 'SOURCE_MISSING' }

# Byte-preserving ASCII replacement: do not recode the existing Chinese/comment bytes.
$bytes = [System.IO.File]::ReadAllBytes($source)
$ascii = [System.Text.Encoding]::ASCII
$oldText = "`tapp_easy_gap_undirected_advertise_with_timeout_start(user_default_hnd_conf.advertise_period, NULL);"
$newText = @"
`tif (hink_d2_dedicated_clock_active())
`t{
`t`t/* FW-AUTONOMOUS-CLOCK-001: keep D2 clock independent from BLE lifecycle.
`t`t * Timed advertising consumes an app_easy_timer; D2 already owns a periodic
`t`t * minute timer. Continuous connectable advertising avoids timer-slot
`t`t * contention after disconnect while preserving reconnectability. */
`t`tapp_easy_gap_undirected_advertise_start();
`t}
`telse
`t{
`t`tapp_easy_gap_undirected_advertise_with_timeout_start(user_default_hnd_conf.advertise_period, NULL);
`t}
"@
$old = $ascii.GetBytes($oldText)
$new = $ascii.GetBytes($newText.TrimEnd("`r", "`n"))

function Find-Sequence([byte[]]$Haystack, [byte[]]$Needle, [int]$Start = 0) {
    for ($i = $Start; $i -le $Haystack.Length - $Needle.Length; $i++) {
        $match = $true
        for ($j = 0; $j -lt $Needle.Length; $j++) {
            if ($Haystack[$i + $j] -ne $Needle[$j]) { $match = $false; break }
        }
        if ($match) { return $i }
    }
    return -1
}

$first = Find-Sequence $bytes $old 0
if ($first -lt 0) { Stop-Fix 'PATCH_ANCHOR_NOT_FOUND' }
$second = Find-Sequence $bytes $old ($first + $old.Length)
if ($second -ge 0) { Stop-Fix 'PATCH_ANCHOR_NOT_UNIQUE' }

$out = New-Object byte[] ($bytes.Length - $old.Length + $new.Length)
[Array]::Copy($bytes, 0, $out, 0, $first)
[Array]::Copy($new, 0, $out, $first, $new.Length)
[Array]::Copy($bytes, $first + $old.Length, $out, $first + $new.Length, $bytes.Length - ($first + $old.Length))
[System.IO.File]::WriteAllBytes($source, $out)

Write-Output 'PATCH: FW-AUTONOMOUS-CLOCK-001 applied'
Write-Output 'BEHAVIOR: BLE disconnect must not stop D2 periodic clock refresh'
Write-Output 'BUILD: starting canonical harness build'

& (Join-Path $expectedRoot 'scripts\eink.ps1') build
if ($LASTEXITCODE -ne 0) { Stop-Fix 'BUILD_FAILED' }

& git diff --check -- $sourceRel
if ($LASTEXITCODE -ne 0) { Stop-Fix 'DIFF_CHECK_FAILED' }

$diff = (& git diff -- $sourceRel | Out-String)
if ($diff -notmatch 'FW-AUTONOMOUS-CLOCK-001' -or
    $diff -notmatch 'app_easy_gap_undirected_advertise_start\(\)' -or
    $diff -notmatch 'app_easy_gap_undirected_advertise_with_timeout_start') {
    Stop-Fix 'EXPECTED_DIFF_NOT_FOUND'
}

# Remove this temporary applicator from the final branch diff.
$selfRel = 'scripts/apply-fw-autonomous-clock-001.ps1'
Remove-Item -LiteralPath $PSCommandPath -Force

& git add -- $sourceRel $selfRel
if ($LASTEXITCODE -ne 0) { Stop-Fix 'EXACT_STAGE_FAILED' }

$staged = @(& git diff --cached --name-only)
if ($staged.Count -ne 2 -or $staged -notcontains $sourceRel -or $staged -notcontains $selfRel) {
    $staged | ForEach-Object { Write-Output "STAGED: $_" }
    Stop-Fix 'UNEXPECTED_STAGE_SET'
}

& git commit -m 'fix: keep autonomous clock alive after BLE disconnect'
if ($LASTEXITCODE -ne 0) { Stop-Fix 'COMMIT_FAILED' }

& git push origin HEAD:$expectedBranch
if ($LASTEXITCODE -ne 0) { Stop-Fix 'PUSH_FAILED' }

Write-Output 'EINK FW FIX: BUILD PASS / COMMITTED / PUSHED'
Write-Output "BRANCH: $expectedBranch"
Write-Output 'NEXT_STATE: OWNER_HARDWARE_TEST_REQUIRED'
