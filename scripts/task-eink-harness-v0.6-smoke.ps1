[CmdletBinding()]
param()

$ErrorActionPreference = 'Stop'
$repoRoot = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path
$runnerPath = Join-Path $repoRoot 'scripts\eink-device-validate.ps1'
$profilePath = Join-Path $repoRoot 'tools\harness\eink-profile.json'

$passed = 0
$failed = 0

function Test-Gate {
    param(
        [Parameter(Mandatory = $true)][string]$Name,
        [Parameter(Mandatory = $true)][scriptblock]$Check
    )
    try {
        if (& $Check) {
            Write-Output "PASS: $Name"
            $script:passed++
        }
        else {
            Write-Output "FAIL: $Name"
            $script:failed++
        }
    }
    catch {
        Write-Output "FAIL: $Name ($($_.Exception.Message))"
        $script:failed++
    }
}

$runner = Get-Content -LiteralPath $runnerPath -Raw
$profile = Get-Content -LiteralPath $profilePath -Raw | ConvertFrom-Json

Test-Gate 'profile version is 0.6' { [string]$profile.version -eq '0.6' }
Test-Gate 'device validation evidence root configured' { -not [string]::IsNullOrWhiteSpace([string]$profile.deviceValidation.evidenceRoot) }
Test-Gate 'canonical web URL preserved' { [string]$profile.deviceValidation.canonicalWebUrl -eq 'https://onlysky17.github.io/Clock/test.html' }
Test-Gate 'requires prior SPI burn evidence directory' { $runner -match 'BurnEvidenceDir' -and $runner -match 'SPI_READBACK\.bin' }
Test-Gate 'requires exact 262144-byte readback evidence' { [int64]$profile.deviceValidation.expectedSpiBytes -eq 262144 -and $runner -match 'BURN_READBACK_SIZE_' }
Test-Gate 'workspace mismatch emits canonical stop text' { $runner -match "SAI PROJECT/WORKSPACE" }
Test-Gate 'tracked dirty tree blocks validation' { $runner -match 'DIRTY_TRACKED_TREE' }
Test-Gate 'cold boot remains explicit Owner gate' { $runner -match 'COLD_BOOT_NOT_APPROVED' -and $runner -match 'Type PASS only if Board #1 cold-boots normally' }
Test-Gate 'BLE remains explicit Owner gate' { $runner -match 'BLE_NOT_APPROVED' -and $runner -match 'Web Bluetooth' }
Test-Gate 'physical e-ink visual remains explicit Owner gate' { $runner -match 'VISUAL_NOT_APPROVED' -and $runner -match 'YOU approve the physical e-ink visual result' }
Test-Gate 'device evidence summary is persisted' { $runner -match 'device-validation\.txt' -and $runner -match 'WriteAllLines' }
Test-Gate 'no reburn is invoked' { $runner -notmatch 'eink-spi-burn\.ps1' -and $runner -notmatch "-cmd', 'write" -and $runner -notmatch "-cmd', 'erase" }
Test-Gate 'final verified state explicit' { $runner -match 'NEXT_STATE: DEVICE_VALIDATION_VERIFIED' }

Write-Output "EINK HARNESS V0.6 SMOKE: $passed PASS / $failed FAIL"
if ($failed -gt 0) { exit 1 }
exit 0
