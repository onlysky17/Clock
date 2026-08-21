[CmdletBinding()]
param()

$ErrorActionPreference = 'Stop'

$repo = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path
$sourceRel = 'firmware/active/HINK213_CLOCK_22_BASE/src/user_custs1_impl.c'
$profileRel = 'firmware/active/HINK213_CLOCK_22_BASE/src/hink_profile_v2.inc'
$epdRel = 'firmware/active/HINK213_CLOCK_22_BASE/src/epd/epd.c'
$epdHRel = 'firmware/active/HINK213_CLOCK_22_BASE/src/epd/epd.h'

$source = [IO.File]::ReadAllText((Join-Path $repo $sourceRel))
$profile = [IO.File]::ReadAllText((Join-Path $repo $profileRel))
$epd = [IO.File]::ReadAllText((Join-Path $repo $epdRel))
$epdH = [IO.File]::ReadAllText((Join-Path $repo $epdHRel))

& git -C $repo diff --quiet -- $epdRel $epdHRel
if ($LASTEXITCODE -ne 0) {
    throw 'epd.c/epd.h are not restored to canonical HEAD'
}

$classicStart = $profile.IndexOf('static void hink_v2_draw_clock_classic(')
$classicEnd = $profile.IndexOf('static uint16_t hink_v2_day_of_year(', $classicStart)
if ($classicStart -lt 0 -or $classicEnd -le $classicStart) {
    throw 'Cannot isolate Portrait Analog renderer'
}
$classic = $profile.Substring($classicStart, $classicEnd - $classicStart)

foreach ($token in @(
    'int cx = 61;',
    'int cy = 72;',
    'hink_v2_circle(cx, cy, 51, BLACK);',
    'for (hour = 1U; hour <= 12U; hour++)',
    'for (minute = 0U; minute < 60U; minute++)',
    'hink_v2_line(31, 134, 90, 134, BLACK);',
    'draw_text(22, 143, date_buf, BLACK);',
    'hink_d9a_draw_lunar(37, 163, lunar_valid, lm, ld);',
    'hink_v2_draw_daily_saying(local_day);',
    'Hands: hour short/thick, minute long/thin. No seconds on e-ink.'
)) {
    if (-not $classic.Contains($token)) {
        throw "Missing portrait renderer token: $token"
    }
}

foreach ($rejected in @(
    'hink_d7a_draw_hhmm(',
    'hink_v2_clock_title(',
    'DONG HO KIM'
)) {
    if ($classic.Contains($rejected) -or
        (($rejected -ne 'hink_d7a_draw_hhmm(') -and $profile.Contains($rejected))) {
        throw "Rejected digital/title token remains in portrait path: $rejected"
    }
}

foreach ($token in @(
    'scr_mode = (scr_mode & ~0x03) | ROTATE_0;',
    'fb_w = EPD_FRAME_WIDTH;',
    'fb_h = EPD_FRAME_HEIGHT;',
    'scr_mode = (scr_mode & ~0x03) | ROTATE_3;',
    'fb_w = EPD_FRAME_HEIGHT;',
    'fb_h = EPD_FRAME_WIDTH;',
    '#define HINK_EPD_FULL_REFRESH_MINUTES 5UL',
    'static uint8_t hink_portrait_ordinary_minute(void)',
    '(hink_clock_profile == HINK_CLOCK_PROFILE_CLASSIC)',
    '((refresh_minute % HINK_EPD_FULL_REFRESH_MINUTES) != 0UL)',
    'hink_d2_complete_without_display_refresh();',
    'hink_v2_draw_clock_classic(draw_hour, m, local_day, sy, sm, sd, sw,',
    'epd_update_mode(use_fly ? UPDATE_FLY : UPDATE_FULL);',
    '(hink_clock_profile == HINK_CLOCK_PROFILE_WEEKLY)',
    'hink_v2_draw_weekly(local_day, h, m, sy, sm, sd, sw,'
)) {
    if (-not $source.Contains($token)) {
        throw "Missing portrait policy/orientation token: $token"
    }
}

$sayingsStart = $profile.IndexOf('static const char * const hink_v2_daily_sayings[] = {')
$sayingsEnd = $profile.IndexOf('};', $sayingsStart)
if ($sayingsStart -lt 0 -or $sayingsEnd -le $sayingsStart) {
    throw 'Cannot isolate built-in daily sayings'
}
$sayingsBlock = $profile.Substring($sayingsStart, $sayingsEnd - $sayingsStart)
$sayings = @([regex]::Matches($sayingsBlock, '"([A-Z |]+)"') | ForEach-Object {
    $_.Groups[1].Value
})

if ($sayings.Count -lt 30 -or $sayings.Count -gt 60) {
    throw "Daily saying count must be 30..60; found $($sayings.Count)"
}

foreach ($saying in $sayings) {
    if ($saying -cnotmatch '^[A-Z ]+(\|[A-Z ]+){0,2}$') {
        throw "Saying is not ASCII-safe or exceeds three pre-wrapped lines: $saying"
    }
    foreach ($line in @($saying.Split('|'))) {
        if ($line.Length -eq 0 -or $line.Length -gt 18) {
            throw "Saying line must be 1..18 characters: $line"
        }
    }
}

foreach ($token in @(
    '#define HINK_V2_SAYING_LINE_CHARS 18U',
    '#define HINK_V2_SAYING_LINE_COUNT 3U',
    'local_day % (sizeof(hink_v2_daily_sayings) /',
    'draw_text(x, (uint8_t)(190U + (row * 14U)), line, BLACK);'
)) {
    if (-not $profile.Contains($token)) {
        throw "Missing deterministic daily-saying token: $token"
    }
}

$refreshStart = $source.IndexOf('static uint8_t hink_d2_start_epd_refresh(void)')
$refreshEnd = $source.IndexOf('#include "hink_profile_v2.inc"', $refreshStart)
if ($refreshStart -lt 0 -or $refreshEnd -le $refreshStart) {
    throw 'Cannot isolate EPD refresh policy'
}
$refresh = $source.Substring($refreshStart, $refreshEnd - $refreshStart)

if ($refresh.Contains('UPDATE_FAST') -or
    $refresh.Contains('epd_screen_update_fast_logical_rect')) {
    throw 'Portrait refresh path still contains UPDATE_FAST/local-gate refresh'
}

foreach ($rejected in @(
    'epd_screen_update_fast_logical_rect',
    'epd_screen_update_diff',
    'UPDATE_DIFF',
    'epd_vendor_partial_prepare',
    'epd_vendor_partial_trigger'
)) {
    if ($source.Contains($rejected) -or $epd.Contains($rejected) -or $epdH.Contains($rejected)) {
        throw "Rejected partial/local refresh API remains: $rejected"
    }
}

$epdHeader = Join-Path $repo $epdHRel
$headerText = [IO.File]::ReadAllText($epdHeader)
if (-not $headerText.Contains('#define EPD_FRAME_WIDTH   122') -or
    -not $headerText.Contains('#define EPD_FRAME_HEIGHT  250')) {
    throw 'Physical/logical portrait geometry constants changed unexpectedly'
}

$v6Checkpoint = Join-Path $repo '_incoming/EINK_PARTIAL_REFRESH_PHYSICAL_FAIL/V6_PHYSICAL_FAIL_20260821_092919/V6_PHYSICAL_FAIL.md'
if (-not (Test-Path -LiteralPath $v6Checkpoint -PathType Leaf)) {
    throw 'V6 physical-fail checkpoint missing'
}
$v6Evidence = [IO.File]::ReadAllText($v6Checkpoint)
if (-not $v6Evidence.Contains('Physical result: FAIL') -or
    -not $v6Evidence.Contains('9A87178B66C28A81C531E84ABA694CFB25281E622C8A496BB39FCA8EFDD8F5FD')) {
    throw 'V6 physical-fail evidence is incomplete'
}

Write-Output 'EINK CLOCK PORTRAIT ANALOG V2: PASS'
Write-Output 'V6 PARTIAL/LOCAL REFRESH: PHYSICAL FAIL RECORDED AND REMOVED'
Write-Output 'PORTRAIT ROTATION: ROTATE_0'
Write-Output 'LOGICAL GEOMETRY: 122x250'
Write-Output 'ANALOG: CENTER 61,72 RADIUS 51, HOURS 1..12, NO SECONDS'
Write-Output 'SOLAR DATE: 22,143'
Write-Output 'LUNAR DATE: 37,163'
Write-Output "DAILY SAYINGS: $($sayings.Count), ASCII, DETERMINISTIC local_day MOD COUNT"
Write-Output 'PROVERB BLOCK: CENTERED, MAX 3 LINES AT Y=190/204/218'
Write-Output 'DIGITAL HH:MM: REMOVED FROM CLASSIC'
Write-Output 'DONG HO KIM TITLE: REMOVED'
Write-Output 'CLASSIC ORDINARY MINUTES: NO DISPLAY REFRESH'
Write-Output 'CLASSIC FULL POLICY: 00/05/10/15/20/25/30/35/40/45/50/55'
Write-Output 'WEEKLY: CANONICAL ROTATE_3 + UPDATE_FLY PRESERVED'
