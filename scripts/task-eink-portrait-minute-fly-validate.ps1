$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest

$repoRoot = (
    Resolve-Path (Join-Path $PSScriptRoot '..')
).Path

$sourceRelative = 'firmware/active/HINK213_CLOCK_22_BASE/src/user_custs1_impl.c'
$layoutRelative = 'firmware/active/HINK213_CLOCK_22_BASE/src/hink_profile_v2.inc'
$epdSourceRelative = 'firmware/active/HINK213_CLOCK_22_BASE/src/epd/epd.c'
$epdHeaderRelative = 'firmware/active/HINK213_CLOCK_22_BASE/src/epd/epd.h'
$sourcePath = Join-Path $repoRoot $sourceRelative

function Assert-Contains {
    param(
        [Parameter(Mandatory=$true)][string]$Text,
        [Parameter(Mandatory=$true)][string]$Pattern,
        [Parameter(Mandatory=$true)][string]$Message
    )

    if ($Text -notmatch $Pattern) {
        throw $Message
    }
}

function Assert-Unchanged {
    param([Parameter(Mandatory=$true)][string]$RelativePath)

    if (-not (Test-Path -LiteralPath (Join-Path $repoRoot $RelativePath) -PathType Leaf)) {
        throw "Protected baseline is missing: $RelativePath"
    }

    & git -C $repoRoot diff --quiet -- $RelativePath
    if ($LASTEXITCODE -ne 0) {
        throw "Protected baseline changed: $RelativePath"
    }
}

if (-not (Test-Path -LiteralPath $sourcePath -PathType Leaf)) {
    throw "Canonical firmware source is missing: $sourceRelative"
}

Assert-Unchanged -RelativePath $layoutRelative
Assert-Unchanged -RelativePath $epdSourceRelative
Assert-Unchanged -RelativePath $epdHeaderRelative

$source = [IO.File]::ReadAllText($sourcePath, [Text.Encoding]::UTF8)

Assert-Contains $source '#define\s+HINK_EPD_FULL_REFRESH_MINUTES\s+5UL' `
    'The 5-minute FULL policy changed.'
Assert-Contains $source '\(refresh_minute\s*%\s*HINK_EPD_FULL_REFRESH_MINUTES\)\s*==\s*0UL' `
    'FULL refresh is not tied to real 5-minute wall-clock boundaries.'
Assert-Contains $source 'HINK_CLOCK_PROFILE_CLASSIC\)\s*\|\|\s*\r?\n\s*\(hink_clock_profile\s*==\s*HINK_CLOCK_PROFILE_WEEKLY' `
    'Classic and Weekly are not both eligible for the guarded FLY path.'
Assert-Contains $source 'epd_update_mode\s*\(use_fly\s*\?\s*UPDATE_FLY\s*:\s*UPDATE_FULL\s*\)' `
    'The refresh mode is not selected between canonical UPDATE_FLY and UPDATE_FULL.'
Assert-Contains $source 'hink_d2_draw_current_framebuffer\s*\(\s*\)\s*;\s*\r?\n\s*\r?\n\s*if\s*\(!hink_d2_start_epd_refresh\s*\(\s*\)\)' `
    'The scheduled render does not redraw the full framebuffer before refresh.'

if ($source -match 'hink_portrait_ordinary_minute|hink_d2_complete_without_display_refresh') {
    throw 'Classic ordinary-minute display refresh is still bypassed.'
}

$forbidden = @(
    'UPDATE_FAST',
    'UPDATE_DIFF',
    'epd_screen_update_fast_logical_rect',
    'epd_screen_update_diff',
    'epd_vendor_partial_prepare',
    'epd_vendor_partial_trigger'
)

foreach ($token in $forbidden) {
    if ($source.Contains($token)) {
        throw "Forbidden local/experimental refresh token found: $token"
    }
}

Write-Output 'EINK-PORTRAIT-MINUTE-FLY-001 VALIDATION: PASS'
Write-Output 'CLASSIC_LAYOUT: UNCHANGED'
Write-Output 'ORDINARY_MINUTE: FULL_FRAME_UPDATE_FLY'
Write-Output 'FIVE_MINUTE_BOUNDARY: UPDATE_FULL'
Write-Output 'WEEKLY_POLICY: UNCHANGED'
Write-Output 'LOCAL_PARTIAL_EXPERIMENTS: ABSENT'
