[CmdletBinding()]
param()

$ErrorActionPreference = 'Stop'

$repoRoot = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path
$serverPath = Join-Path $repoRoot 'tools\harness\control-center\server.ps1'
$productionBrainRoot = Join-Path $repoRoot '_incoming\EINK_HARNESS_BRAIN'
$runtimeRoot = Join-Path $repoRoot '_incoming\EINK_HARNESS_CONTROL_CENTER_RUNTIME'
$acceptanceRoot = Join-Path $repoRoot '_incoming\EINK_HARNESS_COMPILER_NEGATION_ACCEPTANCE'
$runRoot = Join-Path $acceptanceRoot ([Guid]::NewGuid().ToString('N'))
$brainRoot = Join-Path $runRoot 'brain'

function Assert-True {
    param(
        [Parameter(Mandatory=$true)][bool]$Condition,
        [Parameter(Mandatory=$true)][string]$Name
    )

    if (-not $Condition) {
        throw "ASSERT_FAIL: $Name"
    }
    Write-Output "$Name`: PASS"
}

function Get-FreeLoopbackPort {
    $listener = [Net.Sockets.TcpListener]::new(
        [Net.IPAddress]::Loopback,
        0
    )
    $listener.Start()
    try {
        ([Net.IPEndPoint]$listener.LocalEndpoint).Port
    }
    finally {
        $listener.Stop()
    }
}

function Get-DirectorySha256 {
    param([Parameter(Mandatory=$true)][string]$Root)

    if (-not (Test-Path -LiteralPath $Root -PathType Container)) {
        return 'MISSING'
    }

    $lines = @(
        Get-ChildItem -LiteralPath $Root -File -Recurse |
        Sort-Object FullName |
        ForEach-Object {
            $relative = $_.FullName.Substring($Root.Length).TrimStart('\')
            "$relative|$($_.Length)|$((Get-FileHash -Algorithm SHA256 -LiteralPath $_.FullName).Hash)"
        }
    ) -join "`n"

    $sha = [Security.Cryptography.SHA256]::Create()
    try {
        [BitConverter]::ToString(
            $sha.ComputeHash([Text.Encoding]::UTF8.GetBytes($lines))
        ).Replace('-','')
    }
    finally {
        $sha.Dispose()
    }
}

function Invoke-BrainAction {
    param(
        [Parameter(Mandatory=$true)][int]$Port,
        [Parameter(Mandatory=$true)][string]$Token,
        [Parameter(Mandatory=$true)][string]$Action,
        [Parameter(Mandatory=$true)]$Body
    )

    Invoke-RestMethod `
        -Uri "http://127.0.0.1:$Port/api/projects/eink/actions/$Action" `
        -Method Post `
        -Headers @{ 'X-Eink-Control-Token' = $Token } `
        -ContentType 'application/json; charset=utf-8' `
        -Body ($Body | ConvertTo-Json -Depth 8 -Compress) `
        -TimeoutSec 10
}

function Get-CompiledContract {
    param(
        [Parameter(Mandatory=$true)][int]$Port,
        [Parameter(Mandatory=$true)][string]$Token,
        [Parameter(Mandatory=$true)][string]$Request
    )

    [void](Invoke-BrainAction `
        -Port $Port `
        -Token $Token `
        -Action 'brain-create' `
        -Body @{ request = $Request })

    (Invoke-BrainAction `
        -Port $Port `
        -Token $Token `
        -Action 'brain-compile' `
        -Body @{}).brain.currentTask.contract
}

$realStatusBefore = @(& git -C $repoRoot status --short --untracked-files=all)
$realBranchBefore = (@(& git -C $repoRoot branch --show-current) -join '').Trim()
$realHeadBefore = (& git -C $repoRoot rev-parse HEAD).Trim()
$productionBrainBefore = Get-DirectorySha256 -Root $productionBrainRoot
$serverPowerShell = $null
$serverAsync = $null
$port = $null

try {
    [void](New-Item -ItemType Directory -Path $brainRoot -Force)

    foreach ($path in @($serverPath, $PSCommandPath)) {
        $tokens = $null
        $errors = $null
        [void][Management.Automation.Language.Parser]::ParseFile(
            $path,
            [ref]$tokens,
            [ref]$errors
        )
        Assert-True (@($errors).Count -eq 0) (
            'POWERSHELL_PARSE_' +
            [IO.Path]::GetFileName($path).ToUpperInvariant()
        )
    }

    $port = Get-FreeLoopbackPort
    Assert-True ($port -ne 5175) 'ISOLATED_TEST_PORT'

    $serverPowerShell = [PowerShell]::Create()
    [void]$serverPowerShell.AddScript({
        param($Server, $Port, $BrainRoot)
        & $Server `
            -Port $Port `
            -NoBrowser `
            -BrainAcceptanceRoot $BrainRoot
    }).AddArgument($serverPath).AddArgument($port).AddArgument($brainRoot)
    $serverAsync = $serverPowerShell.BeginInvoke()

    $hub = $null
    for ($attempt = 0; $attempt -lt 60; $attempt++) {
        Start-Sleep -Milliseconds 200
        if ($serverAsync.IsCompleted) { break }
        try {
            $hub = Invoke-RestMethod `
                -Uri "http://127.0.0.1:$port/api/status" `
                -TimeoutSec 2
            if ($hub.sessionToken) { break }
        }
        catch {}
    }
    if (-not $hub -or -not $hub.sessionToken) {
        $errors = @($serverPowerShell.Streams.Error | ForEach-Object {
            $_.ToString()
        }) -join "`n"
        throw "NEGATION_ACCEPTANCE_SERVER_START_FAILED: $errors"
    }

    $khong = [Text.Encoding]::UTF8.GetString(
        [Convert]::FromBase64String('S2jDtG5n')
    )
    $nap = [Text.Encoding]::UTF8.GetString(
        [Convert]::FromBase64String('buG6oXA=')
    )

    $negatedCases = [ordered]@{
        EN_NO_HARDWARE = 'Control Center task. No hardware.'
        EN_NO_FLASH = 'Control Center task. No flash.'
        EN_NO_BURN = 'Control Center task. No burn.'
        EN_NO_FIRMWARE = 'No firmware.'
        EN_NO_FLASH_UI = 'No flash, only edit Control Center UI'
        EN_DO_NOT_BURN = 'Do not burn; only change harness executor'
        VI_NO_HARDWARE = "Harness task. $khong dung hardware."
        VI_NO_FLASH = "Harness task. $khong flash."
        VI_NO_BURN = "Harness task. $khong burn."
        VI_NO_FIRMWARE = "$khong firmware."
        VI_NO_NAP = "Harness task. $khong $nap firmware."
    }

    foreach ($case in $negatedCases.GetEnumerator()) {
        $contract = Get-CompiledContract `
            -Port $port `
            -Token ([string]$hub.sessionToken) `
            -Request ([string]$case.Value)
        Assert-True (
            -not [bool]$contract.hardwareIntent
        ) ("NEGATED_$($case.Key)_HARDWARE_FALSE")
        Assert-True (
            [string]$contract.riskLevel -ne 'HIGH'
        ) ("NEGATED_$($case.Key)_RISK_NOT_HIGH")
    }

    $positiveCases = [ordered]@{
        EN_FIRMWARE_FLASH = 'Update firmware and flash board'
        EN_BURN_BOARD = 'Burn the image to the board'
        VI_FIRMWARE_NAP = "Cap nhat firmware va $nap board"
        MIXED_MANUAL_FLASH = 'Do not flash automatically, but prepare firmware for manual flash'
    }

    foreach ($case in $positiveCases.GetEnumerator()) {
        $contract = Get-CompiledContract `
            -Port $port `
            -Token ([string]$hub.sessionToken) `
            -Request ([string]$case.Value)
        Assert-True (
            [bool]$contract.hardwareIntent
        ) ("POSITIVE_$($case.Key)_HARDWARE_TRUE")
        Assert-True (
            [string]$contract.riskLevel -eq 'HIGH'
        ) ("POSITIVE_$($case.Key)_RISK_HIGH")
    }

    $negativeHarness = Get-CompiledContract `
        -Port $port `
        -Token ([string]$hub.sessionToken) `
        -Request 'No flash, only edit Control Center UI'
    Assert-True (
        [string]$negativeHarness.taskClass -eq 'HARNESS'
    ) 'NEGATED_HARNESS_TASK_CLASS_PRESERVED'
    Assert-True (
        @($negativeHarness.candidateFileScopes) -join '|' -eq
        'tools/harness/**|scripts/eink-*.ps1|scripts/task-eink-harness-*.ps1|docs/agent/**'
    ) 'NEGATED_HARNESS_CANDIDATE_SCOPE_PRESERVED'
    Assert-True (
        @($negativeHarness.ownerGates) -notcontains 'OWNER_BURN_CONFIRMATION'
    ) 'NEGATED_HARNESS_NO_BURN_GATE'

    $positiveFirmware = Get-CompiledContract `
        -Port $port `
        -Token ([string]$hub.sessionToken) `
        -Request 'Update firmware and flash board'
    Assert-True (
        [string]$positiveFirmware.taskClass -eq 'FIRMWARE'
    ) 'POSITIVE_FIRMWARE_TASK_CLASS_PRESERVED'
    Assert-True (
        @($positiveFirmware.ownerGates) -contains 'OWNER_BURN_CONFIRMATION'
    ) 'POSITIVE_FIRMWARE_BURN_GATE_PRESERVED'
    Assert-True (
        [string]$positiveFirmware.compilerVersion -eq '0.6.1' -and
        [string]$positiveFirmware.compilerPolicy -eq
            'DETERMINISTIC_HEURISTIC_V1_NEGATION_AWARE_WITH_EXACT_SCOPE'
    ) 'NEGATION_AWARE_COMPILER_VERSION'

    $shutdown = Invoke-RestMethod `
        -Uri "http://127.0.0.1:$port/api/shutdown" `
        -Method Post `
        -Headers @{ 'X-Eink-Control-Token' = [string]$hub.sessionToken } `
        -ContentType 'application/json' `
        -Body '{}' `
        -TimeoutSec 5
    Assert-True ([string]$shutdown.result -eq 'STOPPING') 'ISOLATED_SERVER_STOP'
    [void]$serverPowerShell.EndInvoke($serverAsync)
    $serverAsync = $null

    Assert-True (
        (Get-DirectorySha256 -Root $productionBrainRoot) -eq
            $productionBrainBefore
    ) 'PRODUCTION_BRAIN_STORE_UNCHANGED'
    Assert-True (
        ((@(& git -C $repoRoot status --short --untracked-files=all)) -join "`n") -eq
            ($realStatusBefore -join "`n")
    ) 'REAL_WORKTREE_STATUS_PRESERVED'
    Assert-True (
        ((@(& git -C $repoRoot branch --show-current) -join '').Trim()) -eq
            $realBranchBefore
    ) 'REAL_BRANCH_PRESERVED'
    Assert-True (
        ((& git -C $repoRoot rev-parse HEAD).Trim()) -eq $realHeadBefore
    ) 'REAL_HEAD_PRESERVED'

    Write-Output 'EINK HARNESS COMPILER NEGATION ACCEPTANCE: PASS'
}
finally {
    if ($serverPowerShell) {
        if ($serverAsync -and -not $serverAsync.IsCompleted) {
            $serverPowerShell.Stop()
        }
        $serverPowerShell.Dispose()
    }

    if ($port) {
        $lockPath = Join-Path $runtimeRoot "server-$port.json"
        if (Test-Path -LiteralPath $lockPath -PathType Leaf) {
            Remove-Item -LiteralPath $lockPath -Force
        }
    }

    if (Test-Path -LiteralPath $runRoot) {
        $resolvedRun = [IO.Path]::GetFullPath($runRoot)
        $resolvedAcceptance = [IO.Path]::GetFullPath(
            $acceptanceRoot
        ).TrimEnd('\') + '\'
        if (-not $resolvedRun.StartsWith(
            $resolvedAcceptance,
            [StringComparison]::OrdinalIgnoreCase
        )) {
            throw 'REFUSING_UNSAFE_COMPILER_NEGATION_ACCEPTANCE_CLEANUP'
        }
        Remove-Item -LiteralPath $resolvedRun -Recurse -Force
    }
}
