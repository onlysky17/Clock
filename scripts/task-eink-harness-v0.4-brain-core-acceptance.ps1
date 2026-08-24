[CmdletBinding()]
param()

$ErrorActionPreference = 'Stop'

$repoRoot = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path
$serverPath = Join-Path $repoRoot 'tools\harness\control-center\server.ps1'
$productionBrainRoot = Join-Path $repoRoot '_incoming\EINK_HARNESS_BRAIN'
$runtimeRoot = Join-Path $repoRoot '_incoming\EINK_HARNESS_CONTROL_CENTER_RUNTIME'

function Assert-True {
    param(
        [bool]$Condition,
        [string]$Message
    )

    if (-not $Condition) {
        throw $Message
    }
}

function Get-TreeSnapshot {
    $head = (& git -C $repoRoot rev-parse HEAD).Trim()
    $status = @(
        & git -C $repoRoot status --porcelain=v1 --untracked-files=all
    ) -join "`n"

    [ordered]@{
        head = $head
        status = $status
    }
}

function Get-DirectorySnapshot {
    param([string]$Root)

    if (-not (Test-Path -LiteralPath $Root)) {
        return ''
    }

    $rootFull = [IO.Path]::GetFullPath($Root)

    @(
        Get-ChildItem -LiteralPath $Root -File -Recurse |
        Sort-Object FullName |
        ForEach-Object {
            $relative = $_.FullName.Substring($rootFull.Length).TrimStart('\')
            $hash = (Get-FileHash -Algorithm SHA256 -LiteralPath $_.FullName).Hash
            "$relative|$($_.Length)|$hash"
        }
    ) -join "`n"
}

function Get-FreePort {
    $probe = New-Object Net.Sockets.TcpListener(
        [Net.IPAddress]::Loopback,
        0
    )

    $probe.Start()

    try {
        ([Net.IPEndPoint]$probe.LocalEndpoint).Port
    }
    finally {
        $probe.Stop()
    }
}

function Invoke-BrainPost {
    param(
        [int]$Port,
        [string]$Token,
        [string]$Action,
        $Body
    )

    Invoke-RestMethod `
        -Uri "http://127.0.0.1:$Port/api/projects/eink/actions/$Action" `
        -Method Post `
        -Headers @{
            'X-Eink-Control-Token' = $Token
        } `
        -ContentType 'application/json; charset=utf-8' `
        -Body ($Body | ConvertTo-Json -Depth 8 -Compress) `
        -TimeoutSec 10
}

function Start-BrainAcceptanceServer {
    param(
        [int]$Port,
        [string]$BrainRoot,
        [string]$Cycle
    )

    New-Item -ItemType Directory -Force -Path $BrainRoot | Out-Null

    $stdout = Join-Path $BrainRoot "server-$Cycle.stdout.log"
    $stderr = Join-Path $BrainRoot "server-$Cycle.stderr.log"

    $arguments = (
        '-NoProfile -ExecutionPolicy Bypass ' +
        "-File `"$serverPath`" " +
        "-Port $Port -NoBrowser " +
        "-BrainAcceptanceRoot `"$BrainRoot`""
    )

    $process = Start-Process `
        -FilePath 'powershell.exe' `
        -ArgumentList $arguments `
        -WindowStyle Hidden `
        -PassThru `
        -RedirectStandardOutput $stdout `
        -RedirectStandardError $stderr

    $hub = $null

    for ($i = 0; $i -lt 80; $i++) {
        Start-Sleep -Milliseconds 150

        if ($process.HasExited) {
            break
        }

        try {
            $hub = Invoke-RestMethod `
                -Uri "http://127.0.0.1:$Port/api/status" `
                -TimeoutSec 2

            if ($hub.sessionToken) {
                break
            }
        }
        catch {
        }
    }

    if (-not $hub -or [string]::IsNullOrWhiteSpace([string]$hub.sessionToken)) {
        $errorText = if (Test-Path $stderr) {
            Get-Content -LiteralPath $stderr -Raw
        }
        else {
            ''
        }

        throw "Acceptance server did not start. $errorText"
    }

    [pscustomobject]@{
        Process = $process
        Token = [string]$hub.sessionToken
    }
}

function Stop-BrainAcceptanceServer {
    param(
        [int]$Port,
        [string]$Token,
        $Process
    )

    if ($Process -and -not $Process.HasExited) {
        try {
            Invoke-RestMethod `
                -Uri "http://127.0.0.1:$Port/api/lifecycle/stop" `
                -Method Post `
                -Headers @{
                    'X-Eink-Control-Token' = $Token
                } `
                -ContentType 'application/json' `
                -Body '{}' `
                -TimeoutSec 3 |
                Out-Null
        }
        catch {
        }

        for ($i = 0; $i -lt 40; $i++) {
            if ($Process.HasExited) {
                break
            }

            Start-Sleep -Milliseconds 100
            $Process.Refresh()
        }

        if (-not $Process.HasExited) {
            Stop-Process -Id $Process.Id -Force
            [void]$Process.WaitForExit(5000)
        }
    }

    $lockPath = Join-Path $runtimeRoot "server-$Port.json"

    if (Test-Path -LiteralPath $lockPath) {
        Remove-Item -LiteralPath $lockPath -Force
    }
}

Set-Location $repoRoot

$beforeTree = Get-TreeSnapshot
$beforeProductionBrain = Get-DirectorySnapshot -Root $productionBrainRoot

$port = Get-FreePort
Assert-True ($port -ne 5175) 'Acceptance selected production port.'

$acceptanceRoot = Join-Path $repoRoot (
    '_incoming\EINK_HARNESS_BRAIN_ACCEPTANCE\' +
    [Guid]::NewGuid().ToString('N')
)

$running = $null
$utf8TaskOne = [Text.Encoding]::UTF8.GetString(
    [Convert]::FromBase64String(
        'VGFzayB0aOG7rSBuZ2hp4buHbSBz4buRIG3hu5l0OiBnaeG7ryBuZ3V5w6puIGZpcm13YXJlIHbDoCBjaOG7iSBsxrB1IHnDqnUgY+G6p3UgdGnhur9uZyBWaeG7h3Qu'
    )
)

$utf8TaskTwo = [Text.Encoding]::UTF8.GetString(
    [Convert]::FromBase64String(
        'VGFzayB0aOG7rSBuZ2hp4buHbSBz4buRIGhhaToga2nhu4NtIHRyYSBwZXJzaXN0ZW50IGhpc3Rvcnkgc2F1IHJlc3RhcnQgSGFybmVzcy4='
    )
)

try {
    Write-Output 'PHASE START_1 BEGIN'

    $running = Start-BrainAcceptanceServer `
        -Port $port `
        -BrainRoot $acceptanceRoot `
        -Cycle 'one'

    Write-Output 'PHASE START_1 PASS'

    # Missing token must be rejected.
    Write-Output 'PHASE AUTH BEGIN'

    $blocked = $false

    try {
        Invoke-WebRequest `
            -Uri "http://127.0.0.1:$port/api/projects/eink/actions/brain-create" `
            -Method Post `
            -UseBasicParsing `
            -ContentType 'application/json; charset=utf-8' `
            -Body '{"request":"blocked"}' `
            -TimeoutSec 5 |
            Out-Null
    }
    catch {
        try {
            $blocked = ([int]$_.Exception.Response.StatusCode -eq 403)
        }
        catch {
            $blocked = $false
        }
    }

    Assert-True $blocked 'Brain write without token was not blocked.'

    Write-Output 'PHASE AUTH PASS'

    # Create task 1.
    Write-Output 'PHASE CREATE BEGIN'

    $task1Result = Invoke-BrainPost `
        -Port $port `
        -Token $running.Token `
        -Action 'brain-create' `
        -Body @{
            request = $utf8TaskOne
        }

    $task1 = [string]$task1Result.brain.currentTask.taskId

    Assert-True (-not [string]::IsNullOrWhiteSpace($task1)) 'Task 1 was not created.'

    # Create task 2.
    $task2Result = Invoke-BrainPost `
        -Port $port `
        -Token $running.Token `
        -Action 'brain-create' `
        -Body @{
            request = $utf8TaskTwo
        }

    $task2 = [string]$task2Result.brain.currentTask.taskId

    Assert-True (-not [string]::IsNullOrWhiteSpace($task2)) 'Task 2 was not created.'
    Assert-True ($task1 -ne $task2) 'Brain generated duplicate task IDs.'
    Assert-True ([int]$task2Result.brain.historyCount -eq 2) 'History did not append both CREATE events.'

    $decodedRequests = @(
        $task2Result.brain.recentTasks |
        ForEach-Object { [string]$_.request }
    )

    Assert-True (
        $decodedRequests -contains $utf8TaskOne
    ) 'Brain history corrupted UTF-8 task one.'

    Assert-True (
        $decodedRequests -contains $utf8TaskTwo
    ) 'Brain history corrupted UTF-8 task two.'

    Write-Output 'PHASE CREATE PASS'

    # Stop first server.
    Stop-BrainAcceptanceServer `
        -Port $port `
        -Token $running.Token `
        -Process $running.Process

    $running = $null

    # Restart same source and same persistence root.
    Write-Output 'PHASE RESTART_PERSISTENCE BEGIN'

    $running = Start-BrainAcceptanceServer `
        -Port $port `
        -BrainRoot $acceptanceRoot `
        -Cycle 'two'

    $afterRestart = Invoke-RestMethod `
        -Uri "http://127.0.0.1:$port/api/projects/eink/status" `
        -TimeoutSec 5

    Assert-True (
        [string]$afterRestart.brain.currentTask.taskId -eq $task2
    ) 'Current Brain task did not survive server restart.'

    Assert-True (
        [int]$afterRestart.brain.historyCount -eq 2
    ) 'Brain history changed unexpectedly across restart.'

    Write-Output 'PHASE RESTART_PERSISTENCE PASS'

    # Resume older task.
    Write-Output 'PHASE RESUME BEGIN'

    $resumeResult = Invoke-BrainPost `
        -Port $port `
        -Token $running.Token `
        -Action 'brain-resume' `
        -Body @{
            taskId = $task1
        }

    Assert-True (
        [string]$resumeResult.brain.currentTask.taskId -eq $task1
    ) 'Older Brain task was not resumed.'

    Assert-True (
        [int]$resumeResult.brain.currentTask.resumeCount -eq 1
    ) 'Brain resumeCount was not incremented.'

    Assert-True (
        [int]$resumeResult.brain.historyCount -eq 3
    ) 'RESUME was not appended to history.'

    Write-Output 'PHASE RESUME PASS'

    $currentPath = Join-Path $acceptanceRoot 'current-task.json'
    $historyPath = Join-Path $acceptanceRoot 'history.jsonl'

    Assert-True (
        (Test-Path -LiteralPath $currentPath -PathType Leaf)
    ) 'Persistent current-task.json is missing.'

    Assert-True (
        (Test-Path -LiteralPath $historyPath -PathType Leaf)
    ) 'Append-only history.jsonl is missing.'

    $historyLines = @(
        Get-Content -LiteralPath $historyPath |
        Where-Object { -not [string]::IsNullOrWhiteSpace($_) }
    )

    Assert-True (
        $historyLines.Count -eq 3
    ) 'Persistent history line count mismatch.'

    Stop-BrainAcceptanceServer `
        -Port $port `
        -Token $running.Token `
        -Process $running.Process

    $running = $null

    if (Test-Path -LiteralPath $acceptanceRoot) {
        Remove-Item -LiteralPath $acceptanceRoot -Recurse -Force
    }

    $afterTree = Get-TreeSnapshot
    $afterProductionBrain = Get-DirectorySnapshot -Root $productionBrainRoot

    Assert-True (
        $beforeTree.head -eq $afterTree.head
    ) 'Brain acceptance changed Git HEAD.'

    Assert-True (
        $beforeTree.status -eq $afterTree.status
    ) 'Brain acceptance changed workspace Git state.'

    Assert-True (
        $beforeProductionBrain -eq $afterProductionBrain
    ) 'Isolated acceptance changed production Brain storage.'

    Write-Output 'WRITE_TOKEN_REQUIRED: PASS'
    Write-Output 'UTF8_NATURAL_LANGUAGE_INTAKE: PASS'
    Write-Output 'PERSISTENT_CURRENT_TASK: PASS'
    Write-Output 'APPEND_ONLY_HISTORY: PASS'
    Write-Output 'RESTART_SURVIVAL: PASS'
    Write-Output 'RESUME_PREVIOUS_TASK: PASS'
    Write-Output 'PRODUCTION_BRAIN_STATE: UNCHANGED'
    Write-Output 'GIT_MUTATION: NONE'
    Write-Output 'FIRMWARE_BUILD_BURN: NOT PERFORMED'
    Write-Output 'EINK-HARNESS-V0.4-BRAIN-CORE: PASS'
}
finally {
    if ($running) {
        Stop-BrainAcceptanceServer `
            -Port $port `
            -Token $running.Token `
            -Process $running.Process
    }

    if (Test-Path -LiteralPath $acceptanceRoot) {
        Remove-Item -LiteralPath $acceptanceRoot -Recurse -Force
    }

    $lockPath = Join-Path $runtimeRoot "server-$port.json"

    if (Test-Path -LiteralPath $lockPath) {
        Remove-Item -LiteralPath $lockPath -Force
    }
}