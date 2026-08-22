[CmdletBinding()]
param(
    [ValidateRange(1024, 65535)]
    [int]$Port = 5175,

    [switch]$NoBrowser,

    [ValidateRange(0, 2147483647)]
    [int]$RestartFromPid = 0,

    [ValidateRange(0, 9223372036854775807)]
    [int64]$RestartFromStartTicks = 0,

    [string]$RestartFromExecutablePath = ''
)

$ErrorActionPreference = 'Stop'

$repoRoot = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path
$serverPath = Join-Path $repoRoot 'tools\harness\control-center\server.ps1'
$runtimeRoot = Join-Path $repoRoot '_incoming\EINK_HARNESS_CONTROL_CENTER_RUNTIME'
$runtimeLockPath = Join-Path $runtimeRoot ("server-$Port.json")
$url = "http://127.0.0.1:$Port/"
$lifecycleDeadlineSec = 30

if (-not (Test-Path -LiteralPath $serverPath -PathType Leaf)) {
    Write-Output 'HARNESS CONTROL CENTER: BLOCKED'
    Write-Output 'REASON: SERVER_SCRIPT_MISSING'
    exit 1
}

function Read-ServerLock {
    if (-not (Test-Path -LiteralPath $runtimeLockPath -PathType Leaf)) {
        return $null
    }

    try {
        [IO.File]::ReadAllText(
            $runtimeLockPath,
            [Text.Encoding]::UTF8
        ) | ConvertFrom-Json
    }
    catch {
        $null
    }
}

function Test-TrackedProcessIdentity {
    param(
        $Lock,
        [int]$ExpectedPid = 0,
        [int64]$ExpectedStartTicks = 0
    )

    if (
        -not $Lock -or
        [string]$Lock.schema -ne 'eink-control-center-server-lock-v1' -or
        [int]$Lock.port -ne $Port -or
        [string]$Lock.scriptPath -ne [IO.Path]::GetFullPath($serverPath) -or
        [string]$Lock.repoRoot -ne [IO.Path]::GetFullPath($repoRoot) -or
        ($ExpectedPid -gt 0 -and [int]$Lock.pid -ne $ExpectedPid) -or
        (
            $ExpectedStartTicks -gt 0 -and
            [int64]$Lock.processStartTicks -ne $ExpectedStartTicks
        )
    ) {
        return $false
    }

    try {
        $process = Get-Process -Id ([int]$Lock.pid) -ErrorAction Stop
        return (
            $process.StartTime.ToUniversalTime().Ticks -eq
                [int64]$Lock.processStartTicks -and
            [IO.Path]::GetFullPath($process.Path) -eq
                [IO.Path]::GetFullPath([string]$Lock.executablePath)
        )
    }
    catch {
        return $false
    }
}

function Get-ControlCenterStatus {
    try {
        $status = Invoke-RestMethod `
            -Uri ($url + 'api/status') `
            -Method Get `
            -DisableKeepAlive `
            -TimeoutSec 15

        if (
            [string]$status.hubId -eq 'harness-control-center' -and
            [string]$status.version -eq '0.3' -and
            @($status.projects.id) -contains 'eink'
        ) {
            return $status
        }
    }
    catch {
    }

    $null
}

function Open-ControlCenter {
    if (-not $NoBrowser) {
        Start-Process $url
    }
}

function Write-LifecyclePhase {
    param(
        [Parameter(Mandatory=$true)][string]$Phase,
        [string]$State = 'PASS',
        [string]$Detail = ''
    )

    Write-Output ('LIFECYCLE {0} {1} {2} {3}' -f (
        (Get-Date).ToUniversalTime().ToString('o'),
        $Phase,
        $State,
        $Detail
    )).TrimEnd()
}

function Test-LoopbackPortBindable {
    param([switch]$AllowTimeWaitReuse)

    $probe = New-Object Net.Sockets.Socket(
        [Net.Sockets.AddressFamily]::InterNetwork,
        [Net.Sockets.SocketType]::Stream,
        [Net.Sockets.ProtocolType]::Tcp
    )
    try {
        if ($AllowTimeWaitReuse) {
            $probe.SetSocketOption(
                [Net.Sockets.SocketOptionLevel]::Socket,
                [Net.Sockets.SocketOptionName]::ReuseAddress,
                $true
            )
        }
        else {
            $probe.ExclusiveAddressUse = $true
        }
        $probe.Bind((New-Object Net.IPEndPoint(
            [Net.IPAddress]::Loopback,
            $Port
        )))
        return $true
    }
    catch {
        return $false
    }
    finally {
        try { $probe.Close() } catch { }
        try { $probe.Dispose() } catch { }
    }
}

function Test-LoopbackListenerPresent {
    @(
        [Net.NetworkInformation.IPGlobalProperties]::GetIPGlobalProperties().GetActiveTcpListeners() |
        Where-Object {
            $_.Port -eq $Port -and
            (
                $_.Address.Equals([Net.IPAddress]::Loopback) -or
                $_.Address.Equals([Net.IPAddress]::Any)
            )
        }
    ).Count -gt 0
}

function Get-RestartTargetState {
    param(
        [Parameter(Mandatory=$true)][int]$TargetPid,
        [Parameter(Mandatory=$true)][int64]$TargetStartTicks,
        [Parameter(Mandatory=$true)][string]$TargetExecutablePath
    )

    try {
        $process = Get-Process -Id $TargetPid -ErrorAction Stop
        if (
            $process.StartTime.ToUniversalTime().Ticks -eq
                $TargetStartTicks -and
            [IO.Path]::GetFullPath($process.Path) -eq
                [IO.Path]::GetFullPath($TargetExecutablePath)
        ) {
            return 'MATCH'
        }
        return 'MISMATCH'
    }
    catch [Microsoft.PowerShell.Commands.ProcessCommandException] {
        return 'MISSING'
    }
    catch {
        if (Get-Process -Id $TargetPid -ErrorAction SilentlyContinue) {
            return 'MISMATCH'
        }
        return 'MISSING'
    }
}

function Stop-ExactReplacementProcess {
    param(
        [Parameter(Mandatory=$true)]$Process,
        [Parameter(Mandatory=$true)][int64]$StartTicks,
        [Parameter(Mandatory=$true)][string]$ExecutablePath
    )

    try {
        $running = Get-Process -Id $Process.Id -ErrorAction Stop
        if (
            $running.StartTime.ToUniversalTime().Ticks -ne $StartTicks -or
            [IO.Path]::GetFullPath($running.Path) -ne
                [IO.Path]::GetFullPath($ExecutablePath)
        ) {
            throw 'Replacement cleanup identity mismatch.'
        }
        Stop-Process -Id $running.Id -Force
        $running.WaitForExit(5000)
        Write-LifecyclePhase `
            -Phase 'REPLACEMENT_CLEANUP' `
            -Detail "PID=$($running.Id)"
    }
    catch [Microsoft.PowerShell.Commands.ProcessCommandException] {
    }
}

$restartIdentityPartCount = 0
if ($RestartFromPid -gt 0) { $restartIdentityPartCount++ }
if ($RestartFromStartTicks -gt 0) { $restartIdentityPartCount++ }
if (-not [string]::IsNullOrWhiteSpace($RestartFromExecutablePath)) {
    $restartIdentityPartCount++
}
if ($restartIdentityPartCount -notin @(0, 3)) {
    throw 'Restart identity requires PID, process start time, and executable path.'
}

$verifiedRestartTargetExited = $false
if ($RestartFromPid -gt 0) {
    $restartLock = Read-ServerLock
    $restartProcessExists = $null -ne (
        Get-Process -Id $RestartFromPid -ErrorAction SilentlyContinue
    )

    if (
        (
            $restartLock -and
            -not (Test-TrackedProcessIdentity `
                -Lock $restartLock `
                -ExpectedPid $RestartFromPid `
                -ExpectedStartTicks $RestartFromStartTicks
            )
        ) -or
        (
            $restartProcessExists -and
            (Get-RestartTargetState `
                -TargetPid $RestartFromPid `
                -TargetStartTicks $RestartFromStartTicks `
                -TargetExecutablePath $RestartFromExecutablePath) -ne
                    'MATCH'
        )
    ) {
        Write-Output 'HARNESS CONTROL CENTER: BLOCKED'
        Write-Output 'REASON: RESTART_PROCESS_IDENTITY_MISMATCH'
        exit 1
    }

    $oldExitWatch = [Diagnostics.Stopwatch]::StartNew()
    $backoffMs = 50
    $restartTargetState = 'MATCH'
    while ($oldExitWatch.Elapsed.TotalSeconds -lt $lifecycleDeadlineSec) {
        $restartTargetState = Get-RestartTargetState `
            -TargetPid $RestartFromPid `
            -TargetStartTicks $RestartFromStartTicks `
            -TargetExecutablePath $RestartFromExecutablePath
        if ($restartTargetState -eq 'MISSING') {
            break
        }
        if ($restartTargetState -ne 'MATCH') {
            Write-Output 'HARNESS CONTROL CENTER: BLOCKED'
            Write-Output 'REASON: RESTART_PROCESS_IDENTITY_MISMATCH'
            exit 1
        }
        Start-Sleep -Milliseconds $backoffMs
        $backoffMs = [Math]::Min(500, $backoffMs * 2)
    }

    if ($restartTargetState -ne 'MISSING') {
        Write-Output 'HARNESS CONTROL CENTER: BLOCKED'
        Write-Output 'REASON: PREVIOUS_SERVER_DID_NOT_EXIT'
        Write-LifecyclePhase `
            -Phase 'OLD_EXIT' `
            -State 'TIMEOUT' `
            -Detail "ELAPSED_MS=$($oldExitWatch.ElapsedMilliseconds)"
        exit 1
    }
    Write-LifecyclePhase `
        -Phase 'OLD_EXIT' `
        -Detail "PID=$RestartFromPid ELAPSED_MS=$($oldExitWatch.ElapsedMilliseconds)"

    $portWatch = [Diagnostics.Stopwatch]::StartNew()
    $portBindable = $false
    $backoffMs = 50
    while ($portWatch.Elapsed.TotalSeconds -lt $lifecycleDeadlineSec) {
        if (
            -not (Test-LoopbackListenerPresent) -and
            (Test-LoopbackPortBindable -AllowTimeWaitReuse)
        ) {
            $portBindable = $true
            break
        }
        Start-Sleep -Milliseconds $backoffMs
        $backoffMs = [Math]::Min(500, $backoffMs * 2)
    }
    if (-not $portBindable) {
        Write-Output 'HARNESS CONTROL CENTER: BLOCKED'
        Write-Output 'REASON: PREVIOUS_SERVER_PORT_NOT_BINDABLE'
        Write-LifecyclePhase `
            -Phase 'PORT_FREE' `
            -State 'TIMEOUT' `
            -Detail "ELAPSED_MS=$($portWatch.ElapsedMilliseconds)"
        exit 1
    }
    Write-LifecyclePhase `
        -Phase 'PORT_FREE' `
        -Detail "ELAPSED_MS=$($portWatch.ElapsedMilliseconds)"
    $verifiedRestartTargetExited = $true
}

$existingStatus = if ($verifiedRestartTargetExited) {
    $null
}
else {
    Get-ControlCenterStatus
}
$existingLock = Read-ServerLock
$existingIdentityValid = Test-TrackedProcessIdentity -Lock $existingLock

if ($existingStatus) {
    if (
        -not $existingIdentityValid -or
        [int]$existingStatus.lifecycle.pid -ne [int]$existingLock.pid -or
        [int64]$existingStatus.lifecycle.processStartTicks -ne
            [int64]$existingLock.processStartTicks
    ) {
        Write-Output 'HARNESS CONTROL CENTER: BLOCKED'
        Write-Output 'REASON: UNTRUSTED_EXISTING_PROCESS'
        exit 1
    }

    Open-ControlCenter
    Write-Output 'HARNESS CONTROL CENTER: PASS'
    Write-Output 'RESULT: ALREADY_RUNNING'
    Write-Output "URL: $url"
    Write-Output "SERVER_PID: $($existingLock.pid)"
    exit 0
}

if ($existingIdentityValid) {
    Write-Output 'HARNESS CONTROL CENTER: BLOCKED'
    Write-Output 'REASON: TRACKED_SERVER_NOT_RESPONDING'
    exit 1
}

if ($existingLock) {
    Remove-Item -LiteralPath $runtimeLockPath -Force -ErrorAction SilentlyContinue
}

if (
    -not $verifiedRestartTargetExited -and
    -not (Test-LoopbackPortBindable)
) {
    Write-Output 'HARNESS CONTROL CENTER: BLOCKED'
    Write-Output 'REASON: UNTRUSTED_PORT_IN_USE'
    exit 1
}

$arguments = @(
    '-NoProfile',
    '-ExecutionPolicy',
    'Bypass',
    '-File',
    "`"$serverPath`"",
    '-Port',
    [string]$Port,
    '-NoBrowser'
)

if (-not (Test-Path -LiteralPath $runtimeRoot -PathType Container)) {
    [void](New-Item -ItemType Directory -Path $runtimeRoot -Force)
}
$serverStdout = Join-Path $runtimeRoot ("server-$Port.stdout.log")
$serverStderr = Join-Path $runtimeRoot ("server-$Port.stderr.log")
Remove-Item -LiteralPath $serverStdout -Force -ErrorAction SilentlyContinue
Remove-Item -LiteralPath $serverStderr -Force -ErrorAction SilentlyContinue

$process = Start-Process `
    -FilePath 'powershell.exe' `
    -ArgumentList $arguments `
    -RedirectStandardOutput $serverStdout `
    -RedirectStandardError $serverStderr `
    -WindowStyle Hidden `
    -PassThru

$replacementStartTicks = 0
$replacementExecutablePath = ''
$readyStatus = $null
$readyLock = $null
$startupWatch = [Diagnostics.Stopwatch]::StartNew()
$startupDeadline = [DateTime]::UtcNow.AddSeconds($lifecycleDeadlineSec)

try {
    $process.Refresh()
    if ($process.HasExited) {
        throw 'Replacement process exited immediately.'
    }
    $replacementStartTicks = $process.StartTime.ToUniversalTime().Ticks
    $replacementExecutablePath = $process.Path
    Write-LifecyclePhase `
        -Phase 'REPLACEMENT_STARTED' `
        -Detail "PID=$($process.Id) ELAPSED_MS=$($startupWatch.ElapsedMilliseconds)"

    $backoffMs = 50
    while ([DateTime]::UtcNow -lt $startupDeadline) {
        $process.Refresh()
        if ($process.HasExited) {
            throw 'Replacement process exited before lock readiness.'
        }
        $candidateLock = Read-ServerLock
        if (
            $candidateLock -and
            [int]$candidateLock.pid -eq $process.Id -and
            [int64]$candidateLock.processStartTicks -eq
                $replacementStartTicks -and
            [IO.Path]::GetFullPath([string]$candidateLock.executablePath) -eq
                [IO.Path]::GetFullPath($replacementExecutablePath) -and
            (Test-TrackedProcessIdentity `
                -Lock $candidateLock `
                -ExpectedPid $process.Id `
                -ExpectedStartTicks $replacementStartTicks)
        ) {
            $readyLock = $candidateLock
            break
        }
        Start-Sleep -Milliseconds $backoffMs
        $backoffMs = [Math]::Min(500, $backoffMs * 2)
    }
    if (-not $readyLock) {
        throw 'REPLACEMENT_LOCK_TIMEOUT'
    }
    Write-LifecyclePhase `
        -Phase 'LOCK_READY' `
        -Detail "PID=$($process.Id) ELAPSED_MS=$($startupWatch.ElapsedMilliseconds)"

    $backoffMs = 50
    while ([DateTime]::UtcNow -lt $startupDeadline) {
        $readyStatus = Get-ControlCenterStatus
        if (
            $readyStatus -and
            [int]$readyStatus.lifecycle.pid -eq $process.Id -and
            [int64]$readyStatus.lifecycle.processStartTicks -eq
                $replacementStartTicks
        ) {
            break
        }
        $readyStatus = $null
        Start-Sleep -Milliseconds $backoffMs
        $backoffMs = [Math]::Min(500, $backoffMs * 2)
    }
    if (-not $readyStatus) {
        throw 'REPLACEMENT_STATUS_TIMEOUT'
    }
    Write-LifecyclePhase `
        -Phase 'STATUS_READY' `
        -Detail "PID=$($process.Id) ELAPSED_MS=$($startupWatch.ElapsedMilliseconds)"
}
catch {
    $failurePhase = if (-not $readyLock) {
        'LOCK_READY'
    }
    else {
        'STATUS_READY'
    }
    Write-LifecyclePhase `
        -Phase $failurePhase `
        -State 'FAIL' `
        -Detail "PID=$($process.Id) ELAPSED_MS=$($startupWatch.ElapsedMilliseconds) ERROR=$($_.Exception.Message)"
    if (
        $replacementStartTicks -gt 0 -and
        -not [string]::IsNullOrWhiteSpace($replacementExecutablePath)
    ) {
        Stop-ExactReplacementProcess `
            -Process $process `
            -StartTicks $replacementStartTicks `
            -ExecutablePath $replacementExecutablePath
    }
    $failedLock = Read-ServerLock
    if (
        $failedLock -and
        [int]$failedLock.pid -eq $process.Id -and
        [int64]$failedLock.processStartTicks -eq $replacementStartTicks
    ) {
        Remove-Item -LiteralPath $runtimeLockPath -Force
    }
    Write-Output 'HARNESS CONTROL CENTER: BLOCKED'
    Write-Output "REASON: $failurePhase"
    Write-Output "PROCESS_ID: $($process.Id)"
    exit 1
}

Open-ControlCenter

Write-Output 'HARNESS CONTROL CENTER: PASS'
Write-Output "URL: $url"
Write-Output "SERVER_PID: $($process.Id)"
Write-Output 'WINDOW: HIDDEN'
Write-Output 'BIND: 127.0.0.1 ONLY'
Write-Output 'NEXT_STATE: CONTROL_CENTER_RUNNING'
