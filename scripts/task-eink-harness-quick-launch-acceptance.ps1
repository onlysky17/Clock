[CmdletBinding()]
param()

$ErrorActionPreference = 'Stop'
$repoRoot = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path
$setupPath = Join-Path $repoRoot 'scripts\eink-harness-quick-launch-setup.ps1'
$extensionRoot = Join-Path $repoRoot 'tools\harness\quick-launch\extension'
$runtimeRoot = Join-Path $repoRoot '_incoming\EINK_HARNESS_CONTROL_CENTER_RUNTIME'
$productionStatusUrl = 'http://127.0.0.1:5175/api/projects/eink/status'
$portProbe = New-Object Net.Sockets.TcpListener([Net.IPAddress]::Loopback, 0)
$portProbe.Start()
$testPort = ([Net.IPEndPoint]$portProbe.LocalEndpoint).Port
$portProbe.Stop()
if ($testPort -eq 5175) { throw 'Temporary port selection returned the production port.' }
$testUrl = "http://127.0.0.1:$testPort/"
$acceptRoot = Join-Path ([IO.Path]::GetTempPath()) ('EINK_HARNESS_QUICK_LAUNCH_' + [Guid]::NewGuid().ToString('N'))
$hostExe = Join-Path $acceptRoot 'eink-harness-native.exe'

function Assert-True {
    param([bool]$Condition, [string]$Message)
    if (-not $Condition) { throw $Message }
}

function Get-Sha256Hex {
    param([string]$Path)
    $stream = [IO.File]::OpenRead($Path)
    try {
        $sha = [Security.Cryptography.SHA256]::Create()
        try { ([BitConverter]::ToString($sha.ComputeHash($stream))).Replace('-', '') }
        finally { $sha.Dispose() }
    }
    finally { $stream.Dispose() }
}

function Read-SharedBytes {
    param([string]$Path)
    $stream = New-Object IO.FileStream(
        $Path,
        [IO.FileMode]::Open,
        [IO.FileAccess]::Read,
        ([IO.FileShare]::ReadWrite -bor [IO.FileShare]::Delete)
    )
    try {
        $buffer = New-Object byte[] ([int]$stream.Length)
        $offset = 0
        while ($offset -lt $buffer.Length) {
            $read = $stream.Read($buffer, $offset, $buffer.Length - $offset)
            if ($read -le 0) { throw 'Native response ended unexpectedly.' }
            $offset += $read
        }
        $buffer
    }
    finally { $stream.Dispose() }
}

function Get-ProductionRecoverySnapshot {
    $burnPath = Join-Path $runtimeRoot 'burn-5175.json'
    $activeTaskPath = Join-Path $repoRoot '_incoming\EINK_HARNESS_CONTROL_CENTER_FINALIZE\active-task.json'
    $verificationPath = Join-Path $repoRoot '_incoming\EINK_HARNESS_CONTROL_CENTER_FINALIZE\burn-verification-state.json'
    $burnRecord = Get-Content -LiteralPath $burnPath -Raw | ConvertFrom-Json
    $apiStatus = try { Invoke-RestMethod -Uri $productionStatusUrl -TimeoutSec 2 } catch { $null }
    [ordered]@{
        durableState = [string]$burnRecord.status
        productionOnline = [bool]($null -ne $apiStatus)
        apiState = if ($apiStatus) { [string]$apiStatus.state } else { 'OFFLINE' }
        burnRuntimeSha256 = Get-Sha256Hex $burnPath
        activeTaskSha256 = Get-Sha256Hex $activeTaskPath
        verificationSha256 = Get-Sha256Hex $verificationPath
    }
}

function Invoke-NativeAction {
    param(
        [hashtable]$Message,
        [string[]]$HostArguments = @('--port', [string]$testPort),
        [switch]$BrowserInvocation
    )
    $json = $Message | ConvertTo-Json -Compress
    $body = [Text.Encoding]::UTF8.GetBytes($json)
    $frame = New-Object byte[] (4 + $body.Length)
    [BitConverter]::GetBytes([int]$body.Length).CopyTo($frame, 0)
    $body.CopyTo($frame, 4)
    $id = [Guid]::NewGuid().ToString('N')
    $stdin = Join-Path $acceptRoot ($id + '.stdin.bin')
    $stdout = Join-Path $acceptRoot ($id + '.stdout.bin')
    $stderr = Join-Path $acceptRoot ($id + '.stderr.log')
    [IO.File]::WriteAllBytes($stdin, $frame)
    $oldAcceptance = [Environment]::GetEnvironmentVariable('EINK_HARNESS_ACCEPTANCE_001')
    [Environment]::SetEnvironmentVariable(
        'EINK_HARNESS_ACCEPTANCE_001',
        $(if ($BrowserInvocation) { $null } else { '1' })
    )
    try {
        $process = Start-Process -FilePath $hostExe -ArgumentList $HostArguments -WindowStyle Hidden -PassThru -RedirectStandardInput $stdin -RedirectStandardOutput $stdout -RedirectStandardError $stderr
        $completed = $process.WaitForExit(95000)
        if (-not $completed) {
            $current = Get-Process -Id $process.Id -ErrorAction SilentlyContinue
            if ($current -and $current.StartTime.ToUniversalTime().Ticks -eq $process.StartTime.ToUniversalTime().Ticks) {
                Stop-Process -Id $process.Id -Force
            }
            $process.Dispose()
            throw 'Native bridge action timed out.'
        }
        $process.Dispose()
    }
    finally {
        [Environment]::SetEnvironmentVariable('EINK_HARNESS_ACCEPTANCE_001', $oldAcceptance)
    }
    $responseBytes = Read-SharedBytes $stdout
    Assert-True ($responseBytes.Length -ge 4) 'Native bridge returned no framed response.'
    $length = [BitConverter]::ToInt32($responseBytes, 0)
    Assert-True ($length -gt 0 -and $length -eq ($responseBytes.Length - 4)) 'Native response framing is invalid.'
    [Text.Encoding]::UTF8.GetString($responseBytes, 4, $length) | ConvertFrom-Json
}

function Stop-TestServerExactly {
    $lockPath = Join-Path $runtimeRoot ("server-$testPort.json")
    if (-not (Test-Path -LiteralPath $lockPath)) { return }
    $lock = Get-Content -LiteralPath $lockPath -Raw | ConvertFrom-Json
    try {
        $process = Get-Process -Id ([int]$lock.pid) -ErrorAction Stop
        if (
            $process.StartTime.ToUniversalTime().Ticks -eq [int64]$lock.processStartTicks -and
            [IO.Path]::GetFullPath($process.Path) -eq [IO.Path]::GetFullPath([string]$lock.executablePath) -and
            [IO.Path]::GetFullPath([string]$lock.scriptPath) -eq [IO.Path]::GetFullPath((Join-Path $repoRoot 'tools\harness\control-center\server.ps1'))
        ) {
            Stop-Process -Id $process.Id -Force
            [void]$process.WaitForExit(5000)
        }
    }
    catch [Microsoft.PowerShell.Commands.ProcessCommandException] { }
    if (Test-Path -LiteralPath $lockPath) {
        $current = Get-Content -LiteralPath $lockPath -Raw | ConvertFrom-Json
        if ([int]$current.pid -eq [int]$lock.pid -and [int64]$current.processStartTicks -eq [int64]$lock.processStartTicks) {
            Remove-Item -LiteralPath $lockPath -Force
        }
    }
}

$before = $null
try {
    $manifest = Get-Content -LiteralPath (Join-Path $extensionRoot 'manifest.json') -Raw | ConvertFrom-Json
    Assert-True ([string]$manifest.name -eq 'EINK Harness') 'Extension name mismatch.'
    Assert-True (@($manifest.permissions) -contains 'nativeMessaging') 'nativeMessaging permission missing.'
    Assert-True (@($manifest.host_permissions).Count -eq 1 -and [string]$manifest.host_permissions[0] -eq 'http://127.0.0.1:5175/*') 'Extension host permission is not loopback-only.'
    $publicKey = [Convert]::FromBase64String([string]$manifest.key)
    $keySha = [Security.Cryptography.SHA256]::Create()
    try { $keyHash = $keySha.ComputeHash($publicKey) } finally { $keySha.Dispose() }
    $extensionId = -join ($keyHash[0..15] | ForEach-Object {
        [char](97 + ($_ -shr 4))
        [char](97 + ($_ -band 15))
    })
    Assert-True ($extensionId -eq 'bnkeegfocdpoljgaadmaciipdlfcmnkm') 'Extension key does not produce the registered extension id.'
    & node --check (Join-Path $extensionRoot 'background.js')
    Assert-True ($LASTEXITCODE -eq 0) 'Extension JavaScript syntax failed.'

    $before = Get-ProductionRecoverySnapshot
    Assert-True (-not [string]::IsNullOrWhiteSpace([string]$before.durableState)) 'Production state snapshot was unavailable before acceptance.'

    & $setupPath -AcceptanceMode -SkipRegistry -InstallRoot $acceptRoot
    Assert-True (Test-Path -LiteralPath $hostExe -PathType Leaf) 'Acceptance native host was not compiled.'
    $nativeManifest = Get-Content -LiteralPath (Join-Path $acceptRoot 'com.eink.harness.json') -Raw | ConvertFrom-Json
    Assert-True ([string]$nativeManifest.path -eq $hostExe) 'Native host manifest executable path mismatch.'
    Assert-True (@($nativeManifest.allowed_origins).Count -eq 1 -and [string]$nativeManifest.allowed_origins[0] -eq "chrome-extension://$extensionId/") 'Native host origin allow-list mismatch.'

    Write-Output 'PHASE HOST_ARGUMENTS BEGIN'
    $chromeOrigin = "chrome-extension://$extensionId/"
    $originOnly = Invoke-NativeAction @{ action = 'STATUS' } -HostArguments @($chromeOrigin) -BrowserInvocation
    Assert-True ($originOnly.reason -notmatch 'HOST_ARGUMENTS_BLOCKED') 'Chrome origin-only invocation was blocked.'
    $withParent = Invoke-NativeAction @{ action = 'STATUS' } -HostArguments @($chromeOrigin, '--parent-window=12345') -BrowserInvocation
    Assert-True ($withParent.reason -notmatch 'HOST_ARGUMENTS_BLOCKED') 'Legitimate Chrome parent-window invocation was blocked.'
    $audit = Get-Content -LiteralPath (Join-Path $acceptRoot 'native-host-last-invocation.json') -Raw | ConvertFrom-Json
    Assert-True ($audit.mode -eq 'CHROME_NATIVE_MESSAGING' -and $audit.origin -eq $chromeOrigin -and $audit.parentWindow -eq '12345' -and [int]$audit.argumentCount -eq 2) 'Chrome argv audit mismatch.'
    $badOrigin = Invoke-NativeAction @{ action = 'STATUS' } -HostArguments @('chrome-extension://aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa/') -BrowserInvocation
    Assert-True (-not $badOrigin.ok -and $badOrigin.reason -eq 'HOST_ERROR_HOST_ARGUMENTS_BLOCKED') 'Unknown extension origin was not blocked.'
    $badParent = Invoke-NativeAction @{ action = 'STATUS' } -HostArguments @($chromeOrigin, '--parent-window=C:\Windows\cmd.exe') -BrowserInvocation
    Assert-True (-not $badParent.ok -and $badParent.reason -eq 'HOST_ERROR_HOST_ARGUMENTS_BLOCKED') 'Arbitrary parent-window value was not blocked.'
    $extraArgument = Invoke-NativeAction @{ action = 'STATUS' } -HostArguments @($chromeOrigin, '--parent-window=0', '--run=cmd.exe') -BrowserInvocation
    Assert-True (-not $extraArgument.ok -and $extraArgument.reason -eq 'HOST_ERROR_HOST_ARGUMENTS_BLOCKED') 'Unknown host argument was not blocked.'
    Write-Output 'PHASE HOST_ARGUMENTS PASS'

    Write-Output 'PHASE STATUS_OFFLINE BEGIN'
    $offline = Invoke-NativeAction @{ action = 'STATUS' }
    Assert-True ($offline.ok -and $offline.state -eq 'OFFLINE') 'Initial temporary port was not offline.'
    Write-Output 'PHASE STATUS_OFFLINE PASS'

    Write-Output 'PHASE ALLOW_LIST BEGIN'
    $pathAttack = Invoke-NativeAction @{ action = 'START'; path = 'C:\Windows\System32\cmd.exe' }
    Assert-True (-not $pathAttack.ok -and $pathAttack.reason -eq 'INVALID_SCHEMA') 'Arbitrary path was not blocked.'
    $actionAttack = Invoke-NativeAction @{ action = 'RUN' }
    Assert-True (-not $actionAttack.ok -and $actionAttack.reason -eq 'ACTION_NOT_ALLOWED') 'Arbitrary action was not blocked.'
    Write-Output 'PHASE ALLOW_LIST PASS'

    Write-Output 'PHASE START BEGIN'
    $started = Invoke-NativeAction @{ action = 'START' }
    Write-Output ('START_RESPONSE=' + ($started | ConvertTo-Json -Compress))
    Assert-True ($started.ok -and $started.state -eq 'ONLINE') 'Offline-to-start-to-online failed.'
    $firstPid = [int]$started.pid
    $firstProcess = Get-Process -Id $firstPid -ErrorAction Stop
    Assert-True ($firstProcess.MainWindowHandle -eq 0) 'Started Harness has a visible window.'
    Write-Output 'PHASE START PASS'

    Write-Output 'PHASE DUPLICATE_START BEGIN'
    $duplicate = Invoke-NativeAction @{ action = 'START' }
    Assert-True ($duplicate.ok -and [int]$duplicate.pid -eq $firstPid -and $duplicate.duplicatePrevented) 'Duplicate start was not prevented.'
    Write-Output 'PHASE DUPLICATE_START PASS'

    Write-Output 'PHASE OPEN BEGIN'
    $opened = Invoke-NativeAction @{ action = 'OPEN' }
    Assert-True ($opened.ok -and $opened.state -eq 'ONLINE' -and $opened.open -and $opened.url -eq $testUrl) 'Online open approval failed.'
    Write-Output 'PHASE OPEN PASS'

    Write-Output 'PHASE RESTART BEGIN'
    $restarted = Invoke-NativeAction @{ action = 'RESTART' }
    Assert-True ($restarted.ok -and $restarted.state -eq 'ONLINE' -and [int]$restarted.pid -ne $firstPid) 'Exact restart failed.'
    Assert-True (-not (Get-Process -Id $firstPid -ErrorAction SilentlyContinue)) 'Old exact PID survived restart.'
    $replacement = Get-Process -Id ([int]$restarted.pid) -ErrorAction Stop
    Assert-True ($replacement.MainWindowHandle -eq 0) 'Replacement Harness has a visible window.'
    Write-Output 'PHASE RESTART PASS'

    Write-Output 'PHASE STOP BEGIN'
    $stopped = Invoke-NativeAction @{ action = 'STOP' }
    Assert-True ($stopped.ok -and $stopped.state -eq 'OFFLINE') 'Exact stop failed.'
    Assert-True (-not (Get-Process -Id ([int]$restarted.pid) -ErrorAction SilentlyContinue)) 'Stopped exact PID is still alive.'
    Write-Output 'PHASE STOP PASS'

    $after = Get-ProductionRecoverySnapshot
    Assert-True (($before | ConvertTo-Json -Compress) -eq ($after | ConvertTo-Json -Compress)) 'Production recovery state changed during temporary-port acceptance.'

    Write-Output 'SYNTAX: PASS'
    Write-Output 'NATIVE_ALLOW_LIST: PASS'
    Write-Output 'CHROME_HOST_ARGUMENTS: PASS'
    Write-Output 'ARBITRARY_ACTION_PATH: BLOCKED'
    Write-Output 'DUPLICATE_START_PREVENTION: PASS'
    Write-Output 'HIDDEN_WINDOW: PASS'
    Write-Output 'RESTART_STOP_EXACT_PID: PASS'
    Write-Output 'OFFLINE_START_ONLINE_OPEN: PASS'
    Write-Output 'ONLINE_FOCUS_OPEN_CONTRACT: PASS'
    Write-Output 'PRODUCTION_RECOVERY_STATE: UNCHANGED'
    Write-Output 'EINK-HARNESS-QUICK-LAUNCH-001: PASS'
}
finally {
    Stop-TestServerExactly
    if (Test-Path -LiteralPath $acceptRoot) {
        & $setupPath -Uninstall -AcceptanceMode -SkipRegistry -InstallRoot $acceptRoot | Out-Null
    }
}
