[CmdletBinding()]
param()

$ErrorActionPreference = 'Stop'
$repoRoot = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path
$runnerPath = Join-Path $repoRoot 'scripts\eink-spi-backup.ps1'
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
$config = $profile.spiBackup

Test-Gate 'profile version is 0.4' { [string]$profile.version -eq '0.4' }
Test-Gate 'SmartSnippets CLI configured' { -not [string]::IsNullOrWhiteSpace([string]$config.smartSnippetsCli) }
Test-Gate 'DA14585 chip configured' { [string]$config.chip -eq 'DA14585-00' }
Test-Gate 'SPI GPIO contract configured' {
    [string]$config.clk -eq 'P0_0' -and
    [string]$config.cs -eq 'P0_3' -and
    [string]$config.miso -eq 'P0_5' -and
    [string]$config.mosi -eq 'P0_6'
}
Test-Gate 'full SPI range configured' {
    [string]$config.offset -eq '0x00000' -and
    [string]$config.length -eq '0x40000' -and
    [string]$config.max -eq '0x40000' -and
    [int64]$config.expectedBytes -eq 262144
}
Test-Gate 'runner launches SmartSnippets via Start-Process' { $runner -match '(?s)Start-Process.*smartSnippetsCli' }
Test-Gate 'runner command is read-only' { $runner -match "'-cmd',\s*'read'" }
Test-Gate 'runner has destructive-argument guard' { $runner -match 'DESTRUCTIVE_ARGUMENT_GUARD' }
Test-Gate 'runner performs two independent reads' {
    $runner -match 'BOARD1_SPI_READ1\.bin' -and $runner -match 'BOARD1_SPI_READ2\.bin'
}
Test-Gate 'runner requires size and hash equality' {
    $runner -match 'expectedBytes' -and $runner -match 'SPI_BACKUP_HASH_MISMATCH'
}
Test-Gate 'runner uses .NET SHA256' {
    $runner -match 'System\.Security\.Cryptography\.SHA256' -and $runner -notmatch 'Get-FileHash'
}
Test-Gate 'runner emits verified next state' { $runner -match 'NEXT_STATE: SPI_BACKUP_VERIFIED' }

Write-Output "EINK HARNESS V0.4 SMOKE: $passed PASS / $failed FAIL"
if ($failed -ne 0) { exit 1 }
exit 0
