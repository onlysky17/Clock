[CmdletBinding()]
param()

$ErrorActionPreference = 'Stop'

$repoRoot = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path
$serverPath = Join-Path $repoRoot 'tools\harness\control-center\server.ps1'
$runtimeRoot = Join-Path $repoRoot '_incoming\EINK_HARNESS_CONTROL_CENTER_RUNTIME'
$productionBrainRoot = Join-Path $repoRoot '_incoming\EINK_HARNESS_BRAIN'

function Assert-True {
    param(
        [bool]$Condition,
        [string]$Message
    )

    if (-not $Condition) {
        throw $Message
    }
}

function Get-FreePort {
    $listener = New-Object Net.Sockets.TcpListener(
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

function Get-TreeSnapshot {
    [ordered]@{
        head = (& git -C $repoRoot rev-parse HEAD).Trim()
        status = @(
            & git -C $repoRoot status --porcelain=v1 --untracked-files=all
        ) -join "`n"
    }
}

function Get-DirectorySnapshot {
    param([string]$Root)

    if (-not (Test-Path -LiteralPath $Root)) {
        return ''
    }

    $fullRoot = [IO.Path]::GetFullPath($Root)

    @(
        Get-ChildItem -LiteralPath $Root -File -Recurse |
        Sort-Object FullName |
        ForEach-Object {
            $relative = $_.FullName.Substring(
                $fullRoot.Length
            ).TrimStart('\')

            $hash = (
                Get-FileHash -Algorithm SHA256 -LiteralPath $_.FullName
            ).Hash

            "$relative|$($_.Length)|$hash"
        }
    ) -join "`n"
}

function Invoke-BrainAction {
    param(
        [int]$Port,
        [string]$Token,
        [string]$Action,
        $Body = @{}
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

function Start-AcceptanceServer {
    param(
        [int]$Port,
        [string]$BrainRoot,
        [string]$Cycle
    )

    New-Item -ItemType Directory -Force -Path $BrainRoot |
        Out-Null

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

    if (
        -not $hub -or
        [string]::IsNullOrWhiteSpace([string]$hub.sessionToken)
    ) {
        $errorText = if (Test-Path $stderr) {
            Get-Content -LiteralPath $stderr -Raw
        }
        else {
            ''
        }

        throw "Acceptance server failed to start. $errorText"
    }

    Assert-True (
        [string]$hub.version -eq '0.5'
    ) 'Acceptance server is not v0.5.'

    [pscustomobject]@{
        Process = $process
        Token = [string]$hub.sessionToken
    }
}

function Stop-AcceptanceServer {
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
            $Process.Refresh()

            if ($Process.HasExited) {
                break
            }

            Start-Sleep -Milliseconds 100
        }

        if (-not $Process.HasExited) {
            Stop-Process -Id $Process.Id -Force
            [void]$Process.WaitForExit(5000)
        }
    }

    $lock = Join-Path $runtimeRoot "server-$Port.json"

    if (Test-Path -LiteralPath $lock) {
        Remove-Item -LiteralPath $lock -Force
    }
}

Set-Location $repoRoot

$beforeTree = Get-TreeSnapshot
$beforeProductionBrain = Get-DirectorySnapshot -Root $productionBrainRoot

$port = Get-FreePort
Assert-True ($port -ne 5175) 'Acceptance selected production port.'

$root = Join-Path $repoRoot (
    '_incoming\EINK_HARNESS_V0.5_COMPILER_ACCEPTANCE\' +
    [Guid]::NewGuid().ToString('N')
)

$running = $null

$harnessRequest = [Text.Encoding]::UTF8.GetString(
    [Convert]::FromBase64String(
        'VGjDqm0gbsO6dCBjaG8gSGFybmVzcyBDb250cm9sIENlbnRlciB2w6Aga2nhu4NtIHRyYSBnaWFvIGRp4buHbiwgY2jGsGEgdGjhu7FjIHRoaS4='
    )
)

$firmwareRequest = [Text.Encoding]::UTF8.GetString(
    [Convert]::FromBase64String(
        'xJDhu5VpIGtpbSBwaMO6dCB0csOqbiDEkeG7k25nIGjhu5MgRUlOSyB2w6AgbuG6oXAgU1BJIMSR4buDIGtp4buDbSB0cmEgdGjhuq10Lg=='
    )
)

$generalRequest = [Text.Encoding]::UTF8.GetString(
    [Convert]::FromBase64String(
        'WOG7rSBsw70gecOqdSBj4bqndSDEkeG6t2MgYmnhu4d0IGNoxrBhIHBow6JuIGxv4bqhaS4='
    )
)

$clockTextRequest = [Text.Encoding]::UTF8.GetString(
    [Convert]::FromBase64String(
        'xJDhu5VpIGPDonUgbsOzaSBkxrDhu5tpIMSR4buTbmcgaOG7kyB0aMOgbmggY8OidSBuZ+G6r24gaMahbiwgY2jGsGEgdGjhu7FjIHRoaSBnw6wu'
    )
)

try {
    Write-Output 'PHASE START BEGIN'

    $running = Start-AcceptanceServer `
        -Port $port `
        -BrainRoot $root `
        -Cycle 'one'

    Write-Output 'PHASE START PASS'

    # ---------------------------------------------------------
    # TOKEN GATE
    # ---------------------------------------------------------

    Write-Output 'PHASE AUTH BEGIN'

    $blocked = $false

    try {
        Invoke-WebRequest `
            -Uri "http://127.0.0.1:$port/api/projects/eink/actions/brain-compile" `
            -Method Post `
            -UseBasicParsing `
            -ContentType 'application/json' `
            -Body '{}' `
            -TimeoutSec 5 |
            Out-Null
    }
    catch {
        try {
            $blocked = (
                [int]$_.Exception.Response.StatusCode -eq 403
            )
        }
        catch {
            $blocked = $false
        }
    }

    Assert-True $blocked 'Compiler write without token was not blocked.'

    Write-Output 'PHASE AUTH PASS'

    # ---------------------------------------------------------
    # HARNESS / VISUAL CONTRACT
    # ---------------------------------------------------------

    Write-Output 'PHASE HARNESS_CONTRACT BEGIN'

    $created = Invoke-BrainAction `
        -Port $port `
        -Token $running.Token `
        -Action 'brain-create' `
        -Body @{
            request = $harnessRequest
        }

    Assert-True (
        [int]$created.brain.historyCount -eq 1
    ) 'Harness CREATE event missing.'

    $compiled = Invoke-BrainAction `
        -Port $port `
        -Token $running.Token `
        -Action 'brain-compile'

    $contract = $compiled.brain.currentTask.contract

    Assert-True (
        [string]$compiled.brain.currentTask.status -eq 'COMPILED'
    ) 'Harness task did not enter COMPILED state.'

    Assert-True (
        [string]$contract.schema -eq 'eink-task-contract-v1'
    ) 'Task Contract schema mismatch.'

    Assert-True (
        [string]$contract.taskClass -eq 'HARNESS'
    ) 'Harness request classification mismatch.'

    Assert-True (
        [string]$contract.riskLevel -eq 'MEDIUM'
    ) 'Harness risk mismatch.'

    Assert-True (
        @($contract.requiredCapabilities) -contains 'repo.edit'
    ) 'Harness repo.edit capability missing.'

    Assert-True (
        @($contract.ownerGates) -contains 'OWNER_UI_VISUAL_PASS'
    ) 'Harness visual Owner gate missing.'

    Assert-True (
        [bool]$contract.exactFilesRequiredBeforeExecution
    ) 'Exact-file execution gate missing.'

    Assert-True (
        @($contract.allowedFiles).Count -eq 0
    ) 'Compiler incorrectly authorized exact files.'

    Assert-True (
        -not [bool]$contract.executionEnabled
    ) 'Compiler unexpectedly enabled execution.'

    Assert-True (
        [int]$compiled.brain.historyCount -eq 2
    ) 'COMPILE event was not appended.'

    Assert-True (
        [string]$compiled.brain.currentTask.request -eq $harnessRequest
    ) 'UTF-8 task request changed during compile.'

    Assert-True (
        [string]$contract.contractSha256 -match '^[0-9A-F]{64}$'
    ) 'Contract SHA256 invalid.'

    Write-Output 'PHASE HARNESS_CONTRACT PASS'

    # ---------------------------------------------------------
    # RESTART / RECONSTRUCT COMPILED TASK
    # ---------------------------------------------------------

    Write-Output 'PHASE RESTART_COMPILED BEGIN'

    Stop-AcceptanceServer `
        -Port $port `
        -Token $running.Token `
        -Process $running.Process

    $running = $null

    $running = Start-AcceptanceServer `
        -Port $port `
        -BrainRoot $root `
        -Cycle 'two'

    $afterRestart = Invoke-RestMethod `
        -Uri "http://127.0.0.1:$port/api/projects/eink/status" `
        -TimeoutSec 5

    Assert-True (
        [string]$afterRestart.brain.currentTask.status -eq 'COMPILED'
    ) 'Compiled task did not survive restart.'

    Assert-True (
        [string]$afterRestart.brain.currentTask.contract.contractSha256 -eq
        [string]$contract.contractSha256
    ) 'Compiled contract changed across restart.'

    Assert-True (
        [int]$afterRestart.brain.historyCount -eq 2
    ) 'History changed unexpectedly across restart.'

    Write-Output 'PHASE RESTART_COMPILED PASS'

    # ---------------------------------------------------------
    # REAL VIETNAMESE CLOCK TEXT REQUEST
    # ---------------------------------------------------------

    Write-Output 'PHASE CLOCK_TEXT_CONTRACT BEGIN'

    [void](Invoke-BrainAction `
        -Port $port `
        -Token $running.Token `
        -Action 'brain-create' `
        -Body @{
            request = $clockTextRequest
        })

    $clockTextCompiled = Invoke-BrainAction `
        -Port $port `
        -Token $running.Token `
        -Action 'brain-compile'

    $clockTextContract = $clockTextCompiled.brain.currentTask.contract

    Assert-True (
        [string]$clockTextContract.sourceRequest -eq $clockTextRequest
    ) 'Clock text UTF-8 request changed.'

    Assert-True (
        [string]$clockTextContract.taskClass -eq 'FIRMWARE'
    ) 'Vietnamese clock text request was not classified as FIRMWARE.'

    Assert-True (
        [string]$clockTextContract.riskLevel -eq 'MEDIUM'
    ) 'Non-hardware clock text task should be MEDIUM risk.'

    Assert-True (
        -not [bool]$clockTextContract.hardwareIntent
    ) 'Clock text-only task incorrectly detected hardware intent.'

    Assert-True (
        [bool]$clockTextContract.visualIntent
    ) 'Visible clock saying was not detected as visual intent.'

    Assert-True (
        @($clockTextContract.ownerGates) -contains
        'OWNER_UI_VISUAL_PASS'
    ) 'Clock text task is missing Owner visual gate.'

    Assert-True (
        @($clockTextContract.requiredCapabilities) -contains
        'firmware.build'
    ) 'Clock text firmware capability set is incomplete.'

    Assert-True (
        [bool]$clockTextContract.exactFilesRequiredBeforeExecution
    ) 'Clock text task bypassed exact-file requirement.'

    Assert-True (
        @($clockTextContract.allowedFiles).Count -eq 0
    ) 'Compiler incorrectly authorized clock text files.'

    Assert-True (
        -not [bool]$clockTextContract.executionEnabled
    ) 'Clock text compiler unexpectedly enabled execution.'

    Write-Output 'PHASE CLOCK_TEXT_CONTRACT PASS'

    # ---------------------------------------------------------
    # FIRMWARE + HARDWARE INTENT
    # ---------------------------------------------------------

    Write-Output 'PHASE FIRMWARE_CONTRACT BEGIN'

    [void](Invoke-BrainAction `
        -Port $port `
        -Token $running.Token `
        -Action 'brain-create' `
        -Body @{
            request = $firmwareRequest
        })

    $firmwareCompiled = Invoke-BrainAction `
        -Port $port `
        -Token $running.Token `
        -Action 'brain-compile'

    $firmwareContract = $firmwareCompiled.brain.currentTask.contract

    Assert-True (
        [string]$firmwareContract.taskClass -eq 'FIRMWARE'
    ) 'Firmware classification mismatch.'

    Assert-True (
        [string]$firmwareContract.riskLevel -eq 'HIGH'
    ) 'Hardware-intent firmware task was not HIGH risk.'

    Assert-True (
        [bool]$firmwareContract.hardwareIntent
    ) 'SPI intent was not detected.'

    Assert-True (
        @($firmwareContract.requiredCapabilities) -contains 'firmware.build'
    ) 'Firmware build capability missing.'

    Assert-True (
        @($firmwareContract.requiredCapabilities) -contains 'spi.backup'
    ) 'SPI backup capability missing.'

    Assert-True (
        @($firmwareContract.ownerGates) -contains 'OWNER_BURN_CONFIRMATION'
    ) 'Owner burn confirmation gate missing.'

    Assert-True (
        @($firmwareContract.ownerGates) -contains 'OWNER_PHYSICAL_PASS'
    ) 'Owner physical PASS gate missing.'

    Assert-True (
        @($firmwareContract.forbiddenActions) -contains
        'hardware.burn-without-owner'
    ) 'Burn-without-owner prohibition missing.'

    Write-Output 'PHASE FIRMWARE_CONTRACT PASS'

    # ---------------------------------------------------------
    # GENERAL MUST REMAIN BLOCKED
    # ---------------------------------------------------------

    Write-Output 'PHASE GENERAL_CONTRACT BEGIN'

    [void](Invoke-BrainAction `
        -Port $port `
        -Token $running.Token `
        -Action 'brain-create' `
        -Body @{
            request = $generalRequest
        })

    $generalCompiled = Invoke-BrainAction `
        -Port $port `
        -Token $running.Token `
        -Action 'brain-compile'

    $generalContract = $generalCompiled.brain.currentTask.contract

    Assert-True (
        [string]$generalContract.taskClass -eq 'GENERAL'
    ) 'General classification mismatch.'

    Assert-True (
        [bool]$generalContract.requiresClassificationReview
    ) 'GENERAL task was not marked for review.'

    Assert-True (
        @($generalContract.forbiddenActions) -contains
        'execution.before-classification-review'
    ) 'GENERAL execution block missing.'

    Write-Output 'PHASE GENERAL_CONTRACT PASS'

    Stop-AcceptanceServer `
        -Port $port `
        -Token $running.Token `
        -Process $running.Process

    $running = $null

    if (Test-Path -LiteralPath $root) {
        Remove-Item -LiteralPath $root -Recurse -Force
    }

    $afterTree = Get-TreeSnapshot
    $afterProductionBrain = Get-DirectorySnapshot -Root $productionBrainRoot

    Assert-True (
        $beforeTree.head -eq $afterTree.head
    ) 'Compiler acceptance changed Git HEAD.'

    Assert-True (
        $beforeTree.status -eq $afterTree.status
    ) 'Compiler acceptance changed Git worktree.'

    Assert-True (
        $beforeProductionBrain -eq $afterProductionBrain
    ) 'Compiler acceptance changed production Brain state.'

    Write-Output 'WRITE_TOKEN_REQUIRED: PASS'
    Write-Output 'TYPED_TASK_CONTRACT: PASS'
    Write-Output 'CAPABILITY_SEAMS: PASS'
    Write-Output 'CANDIDATE_SCOPE_NOT_AUTHORIZATION: PASS'
    Write-Output 'FORBIDDEN_ACTIONS: PASS'
    Write-Output 'OWNER_GATES: PASS'
    Write-Output 'UTF8_CLASSIFICATION: PASS'
    Write-Output 'COMPILE_EVENT_APPEND_ONLY: PASS'
    Write-Output 'RESTART_RECONSTRUCTABILITY: PASS'
    Write-Output 'GENERAL_EXECUTION_BLOCK: PASS'
    Write-Output 'PRODUCTION_BRAIN_STATE: UNCHANGED'
    Write-Output 'GIT_MUTATION: NONE'
    Write-Output 'FIRMWARE_BUILD_BURN: NOT PERFORMED'
    Write-Output 'EINK-HARNESS-V0.5-TASK-COMPILER: PASS'
}
finally {
    if ($running) {
        Stop-AcceptanceServer `
            -Port $port `
            -Token $running.Token `
            -Process $running.Process
    }

    if (Test-Path -LiteralPath $root) {
        Remove-Item -LiteralPath $root -Recurse -Force
    }

    $lock = Join-Path $runtimeRoot "server-$port.json"

    if (Test-Path -LiteralPath $lock) {
        Remove-Item -LiteralPath $lock -Force
    }
}