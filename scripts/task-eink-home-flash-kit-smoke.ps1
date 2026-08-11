[CmdletBinding()]
param()

$ErrorActionPreference = "Stop"

$scriptRoot = Split-Path -Parent $MyInvocation.MyCommand.Path
$repoRoot = [System.IO.Path]::GetFullPath((Join-Path $scriptRoot ".."))
$kitScript = Join-Path $repoRoot "scripts\eink-home-flash.ps1"
$kitDoc = Join-Path $repoRoot "docs\firmware\EINK_MULTI_BOARD_HOME_FLASH_KIT.md"

function Assert-True {
    param(
        [Parameter(Mandatory = $true)][bool]$Condition,
        [Parameter(Mandatory = $true)][string]$Message
    )

    if (-not $Condition) {
        throw $Message
    }
}

Assert-True (Test-Path -LiteralPath $kitScript -PathType Leaf) "Missing kit script: $kitScript"
Assert-True (Test-Path -LiteralPath $kitDoc -PathType Leaf) "Missing kit documentation: $kitDoc"

$scriptText = Get-Content -LiteralPath $kitScript -Raw
$docText = Get-Content -LiteralPath $kitDoc -Raw

Assert-True ($scriptText -match 'ValidateSet\("VerifyEnv", "Pack"\)') "Only verified VerifyEnv and Pack modes may be exposed"
Assert-True ($scriptText -notmatch 'Start-Process|Invoke-Item|explorer\.exe|ShellExecute') "Kit must remain headless"
Assert-True ($scriptText -notmatch 'Mode\s*-eq\s*["''](?:Burn|Verify|All)["'']') "Unsupported burn/verify/all modes found"
Assert-True ($scriptText -match 'pack-hink\.ps1') "Kit must reuse the canonical packer"
Assert-True ($scriptText -match 'artifact-policy\.ps1') "Kit must reuse the harness artifact policy"
Assert-True ($scriptText -match '65528') "Raw BIN limit must remain 65528 bytes"
Assert-True ($scriptText -match '262144') "Packed BIN size must remain 262144 bytes"
Assert-True ($scriptText -match 'HINK213-CLOCK') "Canonical BLE name must be explicit"
Assert-True ($scriptText -match 'Get-FileHash') "SHA256 verification must be present"
Assert-True ($docText -match 'DA14585') "Compatibility contract must name DA14585"
Assert-True ($docText -match 'HINK213') "Compatibility contract must name HINK213"
Assert-True ($docText -match 'SmartSnippets') "Owner burn/verify tool must be documented"
Assert-True ($docText -match 'OWNER_GATE') "Physical gates must be explicit"
Assert-True ($docText -notmatch 'PHYSICAL PASS') "Documentation must not claim physical PASS"

& powershell.exe -NoProfile -ExecutionPolicy Bypass -File $kitScript -Mode VerifyEnv
if ($LASTEXITCODE -ne 0) {
    throw "VerifyEnv failed with exit code $LASTEXITCODE"
}

$sdkRaw = "D:\EINK\DA14585_SDK_6.0.22.1401\projects\target_apps\ble_examples\HINK213_CLOCK_22_BASE\Keil_5\out_DA14585\Objects\ble_app_peripheral_585.bin"
$dryRunOut = Join-Path $repoRoot ("_incoming\EINK_HOME_FLASH_KIT_DRY_RUN_{0}.bin" -f [Guid]::NewGuid().ToString("N"))

Assert-True (Test-Path -LiteralPath $sdkRaw -PathType Leaf) "Known SDK raw BIN is missing: $sdkRaw"
Assert-True (-not (Test-Path -LiteralPath $dryRunOut)) "Dry-run output path already exists: $dryRunOut"

& powershell.exe -NoProfile -ExecutionPolicy Bypass -File $kitScript `
    -Mode Pack `
    -RawBinPath $sdkRaw `
    -OutputPath $dryRunOut `
    -DryRun
if ($LASTEXITCODE -ne 0) {
    throw "Pack dry-run failed with exit code $LASTEXITCODE"
}

Assert-True (-not (Test-Path -LiteralPath $dryRunOut)) "Pack dry-run unexpectedly wrote an output file: $dryRunOut"

Write-Host "EINK HOME FLASH KIT SMOKE PASS"
