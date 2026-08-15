[CmdletBinding()]
param()

$ErrorActionPreference = 'Stop'
$repoRoot = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path
$runnerPath = Join-Path $repoRoot 'scripts\eink-spi-burn.ps1'
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
            $script:passed++
            Write-Output "PASS: $Name"
        }
        else {
            $script:failed++
            Write-Output "FAIL: $Name"
        }
    }
    catch {
        $script:failed++
        Write-Output "FAIL: $Name - $($_.Exception.Message)"
    }
}

$runner = Get-Content -LiteralPath $runnerPath -Raw
$profile = Get-Content -LiteralPath $profilePath -Raw | ConvertFrom-Json
$burn = $profile.spiBurn

Test-Gate 'profile version is 0.5' { [string]$profile.version -eq '0.5' }
Test-Gate 'burn requires exact 262144-byte packed image' { [int64]$burn.expectedBytes -eq 262144 }
Test-Gate 'explicit confirmation token configured' { [string]$burn.confirmationToken -eq 'BURN-BOARD1-SPI' }
Test-Gate 'Plan mode exists and is non-destructive' {
    $runner -match "ValidateSet\('Plan', 'Burn'\)" -and
    $runner -match 'OWNER_BURN_CONFIRMATION_REQUIRED'
}
Test-Gate 'expected packed SHA is mandatory before Burn' {
    $runner -match 'EXPECTED_PACKED_SHA256_MISMATCH' -and
    [bool]$burn.requireExpectedPackedSha256
}
Test-Gate 'destructive token is mandatory before Burn' { $runner -match 'DESTRUCTIVE_CONFIRMATION_REQUIRED' }
Test-Gate 'fresh backup required in same Burn run' {
    $runner -match 'eink-spi-backup\.ps1' -and
    $runner -match 'SPI_BACKUP_VERIFIED' -and
    [bool]$burn.requireFreshBackup
}
Test-Gate 'erase uses official SPI erase command with verify' {
    $runner -match "'-cmd', 'erase', '-verify', '-y'"
}
Test-Gate 'write uses official SPI write command with verify' {
    $runner -match "'-cmd', 'write'" -and
    $runner -match "'-verify'"
}
Test-Gate 'write is fixed to offset 0 and max 0x40000 via profile' {
    [string]$burn.offset -eq '0x00000' -and [string]$burn.max -eq '0x40000'
}
Test-Gate 'independent full readback required' {
    $runner -match "'-cmd', 'read'" -and
    $runner -match 'SPI_READBACK\.bin' -and
    $runner -match 'SPI_READBACK_SIZE_'
}
Test-Gate 'readback SHA must equal packed SHA' { $runner -match 'SPI_READBACK_HASH_MISMATCH' }
Test-Gate 'runner uses .NET SHA256 only' {
    $runner -match 'System\.Security\.Cryptography\.SHA256' -and $runner -notmatch 'Get-FileHash'
}
Test-Gate 'no GUI fallback or retry loop' {
    $runner -notmatch '(?i)SmartSnippets GUI|Start-Sleep.*retry|for\s*\(.*retry|while\s*\('
}
Test-Gate 'final verified state is explicit' { $runner -match 'NEXT_STATE: SPI_BURN_VERIFIED' }

Write-Output "EINK HARNESS V0.5 SMOKE: $passed PASS / $failed FAIL"
if ($failed -ne 0) { exit 1 }
exit 0
