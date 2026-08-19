[CmdletBinding()]
param()

$ErrorActionPreference = 'Stop'
$repoRoot = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path
$expectedBranch = 'task-d/eink-web-premium-ui-v2-clock-card'
$firmware = Join-Path $repoRoot 'firmware\active\HINK213_CLOCK_22_BASE\src\user_custs1_impl.c'
$renderer = Join-Path $repoRoot 'firmware\active\HINK213_CLOCK_22_BASE\src\hink_profile_v2.inc'
$webBridge = Join-Path $repoRoot 'web\clock-app\device-target-preview.js'
$buildScript = Join-Path $repoRoot 'scripts\eink.ps1'

function Assert-True {
    param([bool]$Condition, [string]$Message)
    if (-not $Condition) { throw "FAIL: $Message" }
    Write-Host "PASS: $Message" -ForegroundColor Green
}

function Assert-Contains {
    param([string]$Text, [string]$Needle, [string]$Message)
    Assert-True -Condition $Text.Contains($Needle) -Message $Message
}

Push-Location $repoRoot
try {
    $top = (& git rev-parse --show-toplevel 2>$null).Trim()
    Assert-True -Condition ($LASTEXITCODE -eq 0 -and ([IO.Path]::GetFullPath($top) -eq [IO.Path]::GetFullPath($repoRoot))) -Message 'workspace is D:\EINK\Clock Git root'

    $branch = (& git branch --show-current).Trim()
    Assert-True -Condition ($branch -eq $expectedBranch) -Message "branch is $expectedBranch"

    $dirty = @(& git status --short --untracked-files=no)
    Assert-True -Condition ($dirty.Count -eq 0) -Message 'tracked working tree is clean'

    Assert-True -Condition (Test-Path -LiteralPath $firmware) -Message 'canonical firmware source exists'
    Assert-True -Condition (Test-Path -LiteralPath $renderer) -Message 'profile v2 renderer include exists'
    Assert-True -Condition (Test-Path -LiteralPath $webBridge) -Message 'web device-apply bridge exists'

    $fw = Get-Content -LiteralPath $firmware -Raw
    $inc = Get-Content -LiteralPath $renderer -Raw
    $web = Get-Content -LiteralPath $webBridge -Raw

    Assert-Contains $fw '#define HINK_CLOCK_PROFILE_CLASSIC    0x03U' 'firmware profile 3 = Clock Classic'
    Assert-Contains $fw '#define HINK_CLOCK_PROFILE_WEEKLY     0x04U' 'firmware profile 4 = Weekly'
    Assert-Contains $fw '#define HINK_CLOCK_PROFILE_MAX        HINK_CLOCK_PROFILE_WEEKLY' 'profile range persists through Weekly'
    Assert-Contains $fw '(value == 15U) || (value == 30U)' 'cadence 15/30 is accepted'
    Assert-Contains $fw '#include "hink_profile_v2.inc"' 'profile v2 renderer is compiled into canonical source'
    Assert-Contains $fw 'hink_v2_draw_clock_classic' 'Clock Classic render dispatch is wired'
    Assert-Contains $fw 'hink_v2_draw_weekly' 'Weekly render dispatch is wired'

    Assert-Contains $inc 'static void hink_v2_draw_clock_classic' 'Clock Classic firmware renderer exists'
    Assert-Contains $inc 'static void hink_v2_draw_weekly' 'Weekly firmware renderer exists'
    Assert-Contains $inc 'hink_d3c_lunar_from_solar' 'Weekly renderer uses firmware lunar calendar'

    Assert-Contains $web 'const CLASSIC_PROFILE_ID=3;' 'web applies Clock Classic as profile 3'
    Assert-Contains $web 'const WEEK_PROFILE_ID=4;' 'web applies Weekly as profile 4'
    Assert-Contains $web 'selectedRefreshMinutes=cadence;' 'web forwards selected Classic cadence'
    Assert-Contains $web 'await d2ApplyClockPreferences();' 'Clock Classic applies cadence before profile'
    Assert-Contains $web 'runD2Flow(d2ApplyClockProfile)' 'Weekly applies profile through D2 flow'

    Write-Host "`n=== CANONICAL KEIL BUILD ===" -ForegroundColor Cyan
    & powershell.exe -NoProfile -ExecutionPolicy Bypass -File $buildScript build
    if ($LASTEXITCODE -ne 0) { throw "FAIL: canonical build exited $LASTEXITCODE" }

    $raw = 'D:\EINK\DA14585_SDK_6.0.22.1401\projects\target_apps\ble_examples\HINK213_CLOCK_22_BASE\Keil_5\out_DA14585\Objects\ble_app_peripheral_585.bin'
    Assert-True -Condition (Test-Path -LiteralPath $raw) -Message 'raw firmware BIN exists after build'
    $item = Get-Item -LiteralPath $raw
    Assert-True -Condition ($item.Length -gt 0 -and $item.Length -le 65528) -Message "raw firmware size is packable ($($item.Length) bytes)"
    $hash = (Get-FileHash -LiteralPath $raw -Algorithm SHA256).Hash

    Write-Host "`nDISPLAY PROFILES V2: SOURCE + BUILD PASS" -ForegroundColor Green
    Write-Host "RAW_BIN: $raw"
    Write-Host "RAW_SIZE: $($item.Length)"
    Write-Host "RAW_SHA256: $hash"
    Write-Host 'NEXT_STATE: PACK_TEST_ARTIFACT'
}
finally {
    Pop-Location
}
