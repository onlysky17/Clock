[CmdletBinding()]
param([string]$PackagePath = 'D:\EINK\Clock\_incoming\D12C_SPI_FINAL_2026-07-22')

$ErrorActionPreference = 'Stop'
$RepoRoot = (git rev-parse --show-toplevel).Trim() -replace '\\','/'
if ($RepoRoot -ne 'D:/EINK/Clock') { throw "Wrong repo: $RepoRoot" }
$PackagePath = (Resolve-Path -LiteralPath $PackagePath).Path
$Required = @(
    'D12C_RAW_ble_app_peripheral_585.bin',
    'D12C_ble_app_peripheral_585.axf',
    'D12C_FINAL_PACKED_256KB.bin',
    'D12C_GOLDEN_BASE_256KB.bin',
    'D12C_MANIFEST_SHA256.txt',
    'verify-d12c-package.ps1',
    'README_D12C_SPI_BURN.txt'
)
foreach ($Name in $Required) {
    if (-not (Test-Path -LiteralPath (Join-Path $PackagePath $Name) -PathType Leaf)) { throw "Missing $Name" }
}

$Manifest = Get-Content -LiteralPath (Join-Path $PackagePath 'D12C_MANIFEST_SHA256.txt') -Raw
foreach ($Needle in @(
    'D12B_MERGE 1bbf42d22c108556ac9fbea4cd7558d895364a77',
    'BUILD Code=43568 RO=3592 RW=552 ZI=22936 Errors=0 Warnings=0',
    'READY FOR OWNER SPI PHYSICAL GATE - NOT YET BURNED',
    'https://onlysky17.github.io/Clock/test.html'
)) {
    if ($Manifest -notmatch [regex]::Escape($Needle)) { throw "Manifest missing $Needle" }
}

$Verify = & powershell.exe -NoProfile -ExecutionPolicy Bypass -File (Join-Path $PackagePath 'verify-d12c-package.ps1') -PackagePath $PackagePath
if (($Verify -join "`n") -notmatch 'D12C package verify PASS') { throw 'Package verify failed' }

$Golden = Get-FileHash (Join-Path $PackagePath 'D12C_GOLDEN_BASE_256KB.bin') -Algorithm SHA256
$Packed = Get-FileHash (Join-Path $PackagePath 'D12C_FINAL_PACKED_256KB.bin') -Algorithm SHA256
if ($Golden.Hash -eq $Packed.Hash) { throw 'Packed image equals golden' }
$Bytes = [IO.File]::ReadAllBytes((Join-Path $PackagePath 'D12C_FINAL_PACKED_256KB.bin'))
if (-not ($Bytes | Where-Object { $_ -ne 0xFF } | Select-Object -First 1)) { throw 'Packed image is all FF' }

$SdkObjects = 'D:\EINK\DA14585_SDK_6.0.22.1401\projects\target_apps\ble_examples\HINK213_CLOCK_22_BASE\Keil_5\out_DA14585\Objects'
if ((Get-FileHash (Join-Path $SdkObjects 'ble_app_peripheral_585.bin') -Algorithm SHA256).Hash -ne '845ABEEED290B361C58C86CC0B4394A2F1FBAC2B62F9AF6AE92935B11C93B188') { throw 'SDK raw hash mismatch' }
$Symdef = Get-Content -LiteralPath (Join-Path $SdkObjects 'ble_app_peripheral_585_symdef.txt') -Raw
if ($Symdef -match 'sfont16|asc2_1608|Font16|font16') { throw 'Legacy font symbol present' }

$Tracked = git ls-files
foreach ($Name in $Required) {
    if ($Tracked -contains "_incoming/D12C_SPI_FINAL_2026-07-22/$Name") { throw "Artifact tracked: $Name" }
}
$Status = git status --short --untracked-files=all
foreach ($Line in $Status) {
    if ($Line -match '^\s*(M|A|D|\?\?)\s+(firmware/|web/|test\.html)') { throw "Runtime source changed: $Line" }
}

Write-Host 'TASK D12C SPI final smoke PASS'
