$ErrorActionPreference = 'Stop'

$repoRoot = Split-Path -Parent $PSScriptRoot
$runnerPath = Join-Path $repoRoot 'scripts\eink.ps1'
$profilePath = Join-Path $repoRoot 'tools\harness\eink-profile.json'
$guardPath = Join-Path $repoRoot 'tools\harness\workspace-guard.ps1'

$runner = Get-Content -LiteralPath $runnerPath -Raw
$profile = Get-Content -LiteralPath $profilePath -Raw | ConvertFrom-Json
$guard = Get-Content -LiteralPath $guardPath -Raw
$argumentBlock = [regex]::Match(
    $runner,
    '(?s)\$processArguments\s*=\s*@\((.*?)\)\s*try'
).Groups[1].Value
$checks = [ordered]@{
    build_command = $runner -match "ValidateSet\([^\)]*'build'"
    dirty_tree_build_opt_in = $runner -match 'Invoke-WorkspaceGuard\s+-AllowDirtyTrackedTree' -and $guard -match '\[switch\]\$AllowDirtyTrackedTree' -and $guard -match '-not\s+\$AllowDirtyTrackedTree'
    manual_launch_parity = $runner -match 'Start-Process' -and $runner -match '-ArgumentList\s+\$processArguments' -and $runner -match '-Wait' -and $runner -match '-PassThru'
    exact_keil_arguments = $argumentBlock -match "'-j0'" -and $argumentBlock -match "'-r'" -and $argumentBlock -match 'toolchain\.projectFile' -and $argumentBlock -match "'-t'" -and $argumentBlock -match 'toolchain\.target' -and $argumentBlock -match "'-o'" -and $argumentBlock -match '\$buildLog'
    manual_launch_context = $runner -notmatch 'ProcessStartInfo|WorkingDirectory|CreateNoWindow|WindowStyle|UseShellExecute'
    bootstrap_and_evidence = $runner -match 'bootstrapScript' -and $profile.toolchain.buildEvidenceRoot -eq 'D:\EINK\Clock\_incoming\EINK_HARNESS_BUILD'
    strict_result_gates = $runner -match 'BUILD_ERRORS_OR_WARNINGS' -and $runner -match 'RAW_BIN_STALE' -and $runner -match 'KEIL_TOOLCHAIN_UNSUPPORTED' -and $runner -match 'KEIL_COMPILER_NOT_CONFIRMED' -and $runner -match 'BUILD_RESULT_MISSING' -and $runner -match 'rawBinMaxBytes'
    canonical_raw_limit_path = $runner -match '\$profile\.artifactPolicy\.rawBinMaxBytes' -and $runner -notmatch '\$profile\.artifacts\.rawBinMaxBytes'
    dotnet_sha256 = $runner -match '\[System\.Security\.Cryptography\.SHA256\]::Create\(\)' -and $runner -match '\[System\.IO\.File\]::OpenRead' -and $runner -match '\[System\.BitConverter\]::ToString' -and $runner -match '\.Dispose\(\)' -and $runner -notmatch 'Get-FileHash|Convert\.ToHexString'
    verified_output = $runner -match 'RAW_SHA256:' -and $runner -match 'RAW_FIRMWARE_VERIFIED'
    canonical_profile = $profile.version -eq '0.3' -and
        $profile.toolchain.keilCli -eq 'D:\Keil_v5_AC6\UV4\UV4.exe' -and
        $profile.toolchain.compilerVersion -eq 'V6.24' -and
        $profile.toolchain.target -eq 'DA14585'
    no_gui_or_flash = $runner -notmatch '(?i)Invoke-Item|explorer\.exe|ShellExecute|UseShellExecute|pack-hink|(?:-Mode\s+Burn)|(?:\bburn\b)'
}

$failed = @($checks.GetEnumerator() | Where-Object { -not $_.Value })
foreach ($check in $checks.GetEnumerator()) {
    Write-Output ("{0}: {1}" -f $check.Key, $(if ($check.Value) { 'PASS' } else { 'FAIL' }))
}
if ($failed.Count -gt 0) {
    exit 1
}

Write-Output ("EINK Harness v0.3 smoke PASS: {0} gates" -f $checks.Count)
