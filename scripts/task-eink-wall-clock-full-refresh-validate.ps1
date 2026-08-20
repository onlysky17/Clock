$ErrorActionPreference = 'Stop'

$repo = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path
$src = Join-Path $repo 'firmware\active\HINK213_CLOCK_22_BASE\src\user_custs1_impl.c'

$text = [IO.File]::ReadAllText($src)

foreach ($needle in @(
    '#define HINK_EPD_FULL_REFRESH_MINUTES 5UL',
    'uint32_t refresh_minute = hink_auto_local_minute_key();',
    'refresh_minute % HINK_EPD_FULL_REFRESH_MINUTES',
    '!wall_clock_full',
    'use_fly ? UPDATE_FLY : UPDATE_FULL',
    'HINK_CLOCK_PROFILE_CLASSIC',
    'HINK_CLOCK_PROFILE_WEEKLY'
)) {
    if (-not $text.Contains($needle)) {
        throw "Missing marker: $needle"
    }
}

foreach ($needle in @(
    'HINK_EPD_FLY_MAINTENANCE_LIMIT',
    'hink_epd_fly_count',
    'Keep ten fly updates between maintenance full refreshes'
)) {
    if ($text.Contains($needle)) {
        throw "Old relative policy remains: $needle"
    }
}

function RefreshMode(
    [int]$minute,
    [bool]$first,
    [bool]$baselineReady
) {
    if ($first -or -not $baselineReady) {
        return 'FULL'
    }

    if (($minute % 5) -eq 0) {
        return 'FULL'
    }

    return 'FLY'
}

$cases = @(
    @{ Minute = 18; First = $true;  Ready = $false; Expected = 'FULL' },
    @{ Minute = 19; First = $false; Ready = $true;  Expected = 'FLY'  },
    @{ Minute = 20; First = $false; Ready = $true;  Expected = 'FULL' },
    @{ Minute = 21; First = $false; Ready = $true;  Expected = 'FLY'  },
    @{ Minute = 22; First = $false; Ready = $true;  Expected = 'FLY'  },
    @{ Minute = 23; First = $false; Ready = $true;  Expected = 'FLY'  },
    @{ Minute = 24; First = $false; Ready = $true;  Expected = 'FLY'  },
    @{ Minute = 25; First = $false; Ready = $true;  Expected = 'FULL' },
    @{ Minute = 29; First = $false; Ready = $true;  Expected = 'FLY'  },
    @{ Minute = 30; First = $false; Ready = $true;  Expected = 'FULL' },
    @{ Minute = 55; First = $false; Ready = $true;  Expected = 'FULL' },
    @{ Minute = 0;  First = $false; Ready = $true;  Expected = 'FULL' }
)

foreach ($case in $cases) {
    $actual = RefreshMode `
        -minute $case.Minute `
        -first $case.First `
        -baselineReady $case.Ready

    if ($actual -ne $case.Expected) {
        throw "Minute $($case.Minute): expected $($case.Expected), got $actual"
    }
}

Write-Output 'EINK WALL-CLOCK FULL REFRESH POLICY: PASS'
Write-Output '11:18 SYNC/APPLY -> FULL BASELINE'
Write-Output '11:19 -> FLY'
Write-Output '11:20 -> FULL'
Write-Output '11:21 -> FLY'
Write-Output '11:22 -> FLY'
Write-Output '11:23 -> FLY'
Write-Output '11:24 -> FLY'
Write-Output '11:25 -> FULL'
Write-Output '11:29 -> FLY'
Write-Output '11:30 -> FULL'
Write-Output 'BOUNDARIES: 00/05/10/15/20/25/30/35/40/45/50/55'
exit 0