$ErrorActionPreference = 'Stop'

$repoRoot = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path
$harness = Join-Path $repoRoot 'scripts\eink.ps1'
$profilePath = Join-Path $repoRoot 'tools\harness\eink-profile.json'

$tokens = $null
$parseErrors = $null

[System.Management.Automation.Language.Parser]::ParseFile(
    $harness,
    [ref]$tokens,
    [ref]$parseErrors
) | Out-Null

if (@($parseErrors).Count -gt 0) {
    throw ('PowerShell parse failed: ' + (@($parseErrors) -join '; '))
}

$text = Get-Content -LiteralPath $harness -Raw

foreach ($marker in @(
    "'prepare-test'",
    'Invoke-PrepareTestImplementation',
    'EINK_HARNESS_PREPARE_TEST',
    'HINK213_CLOCK_READY.bin',
    'OWNER_BURN_CONFIRMATION_REQUIRED',
    'PACKER_VALIDATION: HEADER_CRC_LAYOUT_PASS',
    'PAYLOAD_BYTE_MATCH: PASS'
)) {
    if ($text.IndexOf($marker, [System.StringComparison]::Ordinal) -lt 0) {
        throw "Missing prepare-test marker: $marker"
    }
}

$profile = Get-Content -LiteralPath $profilePath -Raw | ConvertFrom-Json

if ([string]$profile.version -ne '0.7') {
    throw "Expected profile version 0.7, got $($profile.version)"
}

if (@($profile.automation.automatic) -notcontains 'prepare_test_build_pack_verify') {
    throw 'Profile does not declare prepare_test_build_pack_verify'
}

Write-Output 'EINK PREPARE-TEST SMOKE: PASS'
Write-Output 'ACTION: BUILD + PACK + VERIFY ONLY'
Write-Output 'DESTRUCTIVE_BURN: NOT PERFORMED'
exit 0