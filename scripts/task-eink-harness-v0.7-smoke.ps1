[CmdletBinding()]
param()

$ErrorActionPreference = 'Stop'

$repoRoot = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path
$profilePath = Join-Path $repoRoot 'tools\harness\eink-profile.json'
$runnerPath = Join-Path $repoRoot 'scripts\eink-release.ps1'
$deviceValidationPath = Join-Path $repoRoot 'scripts\eink-device-validate.ps1'
$reproPath = Join-Path $repoRoot 'scripts\eink-build-repro-check.ps1'

$profile = Get-Content -LiteralPath $profilePath -Raw | ConvertFrom-Json
$runner = Get-Content -LiteralPath $runnerPath -Raw
$deviceValidation = Get-Content -LiteralPath $deviceValidationPath -Raw
$repro = if (Test-Path -LiteralPath $reproPath) { Get-Content -LiteralPath $reproPath -Raw } else { '' }

$passed = 0
$failed = 0

function Gate {
    param([string]$Name, [bool]$Condition)
    if ($Condition) {
        Write-Output "PASS: $Name"
        $script:passed++
    }
    else {
        Write-Output "FAIL: $Name"
        $script:failed++
    }
}

Gate 'profile version is 0.7' ([string]$profile.version -eq '0.7')
Gate 'release evidence root configured' (-not [string]::IsNullOrWhiteSpace([string]$profile.releasePipeline.evidenceRoot))
Gate 'release packed root configured' (-not [string]::IsNullOrWhiteSpace([string]$profile.releasePipeline.packedRoot))
Gate 'Plan and Release modes exist' ($runner.Contains("ValidateSet('Plan', 'Release')"))
Gate 'workspace mismatch emits canonical stop text' ($runner.Contains('SAI PROJECT/WORKSPACE'))
Gate 'tracked dirty tree blocks release' ($runner.Contains('DIRTY_TRACKED_TREE'))
Gate 'build is composed from proven harness action' ($runner.Contains("Join-Path `$PSScriptRoot 'eink.ps1'") -and $runner.Contains("@('build')"))
Gate 'packer is composed from canonical profile path' ($runner.Contains('toolchain.packerScript'))
Gate 'packed image must be exact configured SPI size' ($runner.Contains('artifactPolicy.packedSpiBytes'))
Gate 'burn Plan runs before any destructive action' ($runner.Contains("'-Mode', 'Plan'") -and $runner.Contains('OWNER_BURN_CONFIRMATION_REQUIRED'))
Gate 'Plan mode exits before destructive Owner gate' ($runner.Contains("if (`$Mode -eq 'Plan')"))
Gate 'destructive confirmation is bound to exact packed SHA' ($runner.Contains('destructivePhrasePrefix') -and $runner.Contains('$packedHash') -and $runner.Contains('HASH_BOUND_DESTRUCTIVE_CONFIRMATION_REQUIRED'))
Gate 'burn reuses guarded v0.5 runner' ($runner.Contains('eink-spi-burn.ps1') -and $runner.Contains("'-Mode', 'Burn'"))
Gate 'burn still requires exact expected packed SHA' ($runner.Contains("'-ExpectedPackedSha256', `$packedHash"))
Gate 'device validation is composed by release runner' ($runner.Contains('eink-device-validate.ps1'))
Gate 'device validation explicitly requires power cycle' ($deviceValidation.Contains('STEP 1/3 - POWER CYCLE') -and $deviceValidation.Contains('OFF -> wait -> ON'))
Gate 'device validation proves reboot with BLE reconnect' ($deviceValidation.Contains('STEP 2/3 - PROVE FIRMWARE BOOTED AFTER POWER CYCLE') -and $deviceValidation.Contains('reconnects by BLE and responds'))
Gate 'device validation proves real e-ink refresh' ($deviceValidation.Contains('STEP 3/3 - PROVE THE PHYSICAL E-INK CAN REFRESH') -and $deviceValidation.Contains('previously stored static frame does not count'))
Gate 'device validation console guidance is ASCII-safe' (-not ($deviceValidation.ToCharArray() | Where-Object { [int][char]$_ -gt 127 }))
Gate 'release does not auto-approve owner device gates' (-not ($runner -match "eink-device-validate\.ps1'.*'-.*PASS"))
Gate 'build reproducibility checker exists' (-not [string]::IsNullOrWhiteSpace($repro))
Gate 'repro checker performs two build snapshots' ($repro.Contains('BUILD 1/2') -and $repro.Contains('BUILD 2/2') -and $repro.Contains('build-1.bin') -and $repro.Contains('build-2.bin'))
Gate 'repro checker is non-destructive' (-not ($repro -match '(?i)eink-spi-burn|SmartSnippets|\bBurn\b'))
Gate 'repro checker blocks hash mismatch' ($repro.Contains('NONDETERMINISTIC_RAW_FIRMWARE') -and $repro.Contains('BUILD_REPRODUCIBILITY_BLOCKED'))
Gate 'release evidence summary is persisted' ($runner.Contains('release-validation.txt'))
Gate 'no GUI fallback or retry loop' (-not ($runner -match '(?i)SmartSnippets GUI|retry|Start-Sleep'))
Gate 'final release verified state explicit' ($runner.Contains('NEXT_STATE: RELEASE_VALIDATION_VERIFIED'))

Write-Output "EINK HARNESS V0.7 SMOKE: $passed PASS / $failed FAIL"
if ($failed -gt 0) { exit 1 }
exit 0
