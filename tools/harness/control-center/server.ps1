[CmdletBinding()]
param(
    [ValidateRange(1024, 65535)]
    [int]$Port = 5175,

    [switch]$NoBrowser
)

$ErrorActionPreference = 'Stop'

$repoRoot = (
    Resolve-Path (
        Join-Path $PSScriptRoot '..\..\..'
    )
).Path

Set-Location $repoRoot

$profilePath = Join-Path $repoRoot 'tools\harness\eink-profile.json'
$indexPath   = Join-Path $PSScriptRoot 'index.html'
$registryPath = Join-Path $PSScriptRoot 'projects.json'
$prepareScript = Join-Path $repoRoot 'scripts\eink.ps1'
$burnScript    = Join-Path $repoRoot 'scripts\eink-spi-burn.ps1'
$prepareEvidenceRoot = Join-Path $repoRoot '_incoming\EINK_HARNESS_PREPARE_TEST'
$prepareTrustStatePath = Join-Path $prepareEvidenceRoot 'control-center-prepare-state.json'

$profile = [IO.File]::ReadAllText(
    $profilePath,
    [Text.Encoding]::UTF8
) | ConvertFrom-Json

if (-not (Test-Path -LiteralPath $registryPath -PathType Leaf)) {
    throw 'Harness Hub project registry is missing.'
}

$projectRegistry = [IO.File]::ReadAllText(
    $registryPath,
    [Text.Encoding]::UTF8
) | ConvertFrom-Json

if ([int]$projectRegistry.version -ne 2) {
    throw 'Unsupported Harness Hub project registry version.'
}

$sessionToken = [Guid]::NewGuid().ToString('N')
$writeTokenHeaderName = 'X-Eink-Control-Token'
$writeTokenHeaderKey = $writeTokenHeaderName.ToLowerInvariant()

$script:Busy = $false
$script:StopRequested = $false
$script:LastAction = 'START'
$script:LastResult = 'IDLE'
$script:PrepareTrustFailureOverride = $null
$script:LastLog = @(
    'Harness Control Center Multiproject v0.2 started.',
    'Waiting for action.'
)

function Invoke-NativeText {
    param(
        [Parameter(Mandatory=$true)]
        [string]$FilePath,

        [Parameter(Mandatory=$true)]
        [string[]]$Arguments
    )

    $previous = $ErrorActionPreference

    try {
        $ErrorActionPreference = 'Continue'

        $output = @(
            & $FilePath @Arguments 2>&1 |
            ForEach-Object { $_.ToString() }
        )

        $exitCode = $LASTEXITCODE
    }
    finally {
        $ErrorActionPreference = $previous
    }

    [PSCustomObject]@{
        ExitCode = $exitCode
        Output = $output
    }
}

function Invoke-Git {
    param(
        [Parameter(Mandatory=$true)]
        [string[]]$Arguments
    )

    Invoke-NativeText -FilePath 'git' -Arguments $Arguments
}

function Get-Sha256Hex {
    param(
        [Parameter(Mandatory=$true)]
        [string]$Path
    )

    $stream = $null
    $sha = $null

    try {
        $stream = [IO.File]::OpenRead($Path)
        $sha = [Security.Cryptography.SHA256]::Create()
        $bytes = $sha.ComputeHash($stream)

        (
            [BitConverter]::ToString($bytes)
        ).Replace('-', '').ToUpperInvariant()
    }
    finally {
        if ($sha) {
            $sha.Dispose()
        }

        if ($stream) {
            $stream.Dispose()
        }
    }
}

function Get-TextSha256 {
    param(
        [Parameter(Mandatory=$true)]
        [string]$Text
    )

    $sha = [Security.Cryptography.SHA256]::Create()

    try {
        $bytes = [Text.Encoding]::UTF8.GetBytes($Text)
        $hash = $sha.ComputeHash($bytes)

        (
            [BitConverter]::ToString($hash)
        ).Replace('-', '').ToUpperInvariant()
    }
    finally {
        $sha.Dispose()
    }
}

function Read-Utf8JsonFile {
    param(
        [Parameter(Mandatory=$true)]
        [string]$Path
    )

    if (-not (Test-Path -LiteralPath $Path -PathType Leaf)) {
        return $null
    }

    try {
        return (
            [IO.File]::ReadAllText(
                $Path,
                [Text.Encoding]::UTF8
            ) | ConvertFrom-Json
        )
    }
    catch {
        return $null
    }
}

function Get-Utf8TextTail {
    param(
        [Parameter(Mandatory=$true)]
        [string]$Path,

        [int]$MaxLines = 40,

        [int]$MaxChars = 8000
    )

    if (-not (Test-Path -LiteralPath $Path -PathType Leaf)) {
        return ''
    }

    try {
        $lines = [IO.File]::ReadAllLines(
            $Path,
            [Text.Encoding]::UTF8
        )

        if ($lines.Length -eq 0) {
            return ''
        }

        $start = [Math]::Max(0, $lines.Length - $MaxLines)
        $text = ($lines[$start..($lines.Length - 1)] -join "`n")

        if ($text.Length -gt $MaxChars) {
            return $text.Substring($text.Length - $MaxChars)
        }

        return $text
    }
    catch {
        return "Unable to read log: $($_.Exception.Message)"
    }
}

function Get-RegistryProject {
    param(
        [Parameter(Mandatory=$true)]
        [string]$ProjectId
    )

    @(
        $projectRegistry.projects |
        Where-Object {
            [string]$_.id -eq $ProjectId
        }
    ) | Select-Object -First 1
}

function Test-ProjectActionAllowed {
    param(
        [Parameter(Mandatory=$true)]
        $Project,

        [Parameter(Mandatory=$true)]
        [string]$ActionId,

        [Parameter(Mandatory=$true)]
        [string]$Method
    )

    foreach ($action in @($Project.actions)) {
        if (
            [string]$action.id -eq $ActionId -and
            [string]$action.method -eq $Method
        ) {
            return $true
        }
    }

    return $false
}

function Get-ElectronicFileStatus {
    param(
        [Parameter(Mandatory=$true)]
        $Project
    )

    $workspace = [IO.Path]::GetFullPath([string]$Project.workspace)
    $harnessRoot = Join-Path $workspace '.harness'

    if (-not (Test-Path -LiteralPath $harnessRoot -PathType Container)) {
        return [ordered]@{
            projectId = [string]$Project.id
            projectName = [string]$Project.name
            version = '0.2'
            adapter = [string]$Project.adapter
            readOnly = $true
            available = $false
            state = 'PLUGIN_UNAVAILABLE'
            message = 'Optional Harness Brain plugin is not available.'
            actions = @()
            sessionToken = $sessionToken
        }
    }

    $projectConfig = Read-Utf8JsonFile (
        Join-Path $harnessRoot 'project.json'
    )
    $state = Read-Utf8JsonFile (
        Join-Path $harnessRoot 'state.json'
    )
    $runtime = Read-Utf8JsonFile (
        Join-Path $harnessRoot 'runtime.json'
    )
    $queue = Read-Utf8JsonFile (
        Join-Path $harnessRoot 'queue.json'
    )

    $taskRoot = Join-Path $harnessRoot 'tasks'
    $taskFiles = if (Test-Path -LiteralPath $taskRoot -PathType Container) {
        @(
            Get-ChildItem -LiteralPath $taskRoot -File -Filter '*.json' |
            Sort-Object LastWriteTime -Descending |
            Select-Object -First 12
        )
    }
    else {
        @()
    }

    $tasks = @(
        foreach ($taskFile in $taskFiles) {
            $task = Read-Utf8JsonFile $taskFile.FullName

            if (-not $task) {
                continue
            }

            [ordered]@{
                taskId = [string]$task.task_id
                objective = [string]$task.objective
                createdAt = [string]$task.created_at
                modifiedAt = $taskFile.LastWriteTime.ToString('o')
                fileName = $taskFile.Name
            }
        }
    )

    $runRoot = Join-Path $harnessRoot 'runs'
    $runDirs = if (Test-Path -LiteralPath $runRoot -PathType Container) {
        @(
            Get-ChildItem -LiteralPath $runRoot -Directory |
            Sort-Object Name -Descending |
            Select-Object -First 12
        )
    }
    else {
        @()
    }

    $runs = @(
        foreach ($runDir in $runDirs) {
            $oracleSnapshotPath = Join-Path (
                Join-Path $runDir.FullName 'oracle-lock'
            ) 'snapshot.json'

            [ordered]@{
                runId = $runDir.Name
                modifiedAt = $runDir.LastWriteTime.ToString('o')
                oracleLocked = [bool](
                    Test-Path -LiteralPath $oracleSnapshotPath -PathType Leaf
                )
                validationLog = Get-Utf8TextTail `
                    -Path (Join-Path $runDir.FullName 'validation.stdout.log') `
                    -MaxLines 8 `
                    -MaxChars 1800
            }
        }
    )

    $agentRoot = Join-Path $harnessRoot 'agent-packets'
    $agentFiles = if (Test-Path -LiteralPath $agentRoot -PathType Container) {
        @(
            Get-ChildItem -LiteralPath $agentRoot -File |
            Sort-Object LastWriteTime -Descending |
            Select-Object -First 10
        )
    }
    else {
        @()
    }

    $agentRuns = @(
        foreach ($agentFile in $agentFiles) {
            [ordered]@{
                id = $agentFile.BaseName
                fileName = $agentFile.Name
                size = [int64]$agentFile.Length
                modifiedAt = $agentFile.LastWriteTime.ToString('o')
                preview = Get-Utf8TextTail `
                    -Path $agentFile.FullName `
                    -MaxLines 10 `
                    -MaxChars 2200
            }
        }
    )

    $latestRun = $runDirs | Select-Object -First 1
    $oracleSnapshot = $null
    $liveLogParts = New-Object Collections.Generic.List[string]

    if ($latestRun) {
        $oracleSnapshot = Read-Utf8JsonFile (
            Join-Path (
                Join-Path $latestRun.FullName 'oracle-lock'
            ) 'snapshot.json'
        )

        foreach ($logName in @(
            'validation.stdout.log',
            'validation.stderr.log'
        )) {
            $logPath = Join-Path $latestRun.FullName $logName
            $tail = Get-Utf8TextTail `
                -Path $logPath `
                -MaxLines 35 `
                -MaxChars 5500

            if (-not [string]::IsNullOrWhiteSpace($tail)) {
                $liveLogParts.Add("[$($latestRun.Name) / $logName]")
                $liveLogParts.Add($tail)
            }
        }
    }

    $brainGlobalRoot = ''

    if ($projectConfig -and $projectConfig.brain) {
        $brainGlobalRoot = [string]$projectConfig.brain.global_root
    }

    $brainLogPath = if ([string]::IsNullOrWhiteSpace($brainGlobalRoot)) {
        ''
    }
    else {
        Join-Path $brainGlobalRoot 'logs\harness-control.log'
    }

    if (-not [string]::IsNullOrWhiteSpace($brainLogPath)) {
        $brainTail = Get-Utf8TextTail `
            -Path $brainLogPath `
            -MaxLines 30 `
            -MaxChars 5500

        if (-not [string]::IsNullOrWhiteSpace($brainTail)) {
            $liveLogParts.Add('[Harness Brain / harness-control.log]')
            $liveLogParts.Add($brainTail)
        }
    }

    [ordered]@{
        projectId = [string]$Project.id
        projectName = [string]$Project.name
        version = '0.2'
        adapter = [string]$Project.adapter
        readOnly = $true
        available = $true
        workspace = $workspace
        branch = [string]$projectConfig.branch
        head = [string]$projectConfig.head
        state = if ($state) {
            [string]$state.state
        }
        else {
            'UNKNOWN'
        }
        currentTask = if ($state) {
            [ordered]@{
                taskId = [string]$state.taskId
                runId = [string]$state.runId
                result = [string]$state.result
                nextAction = [string]$state.nextAction
                ownerIntentStatus = [string]$state.ownerIntentStatus
                visualMachineGate = [string]$state.visualMachineGate
                agentResult = [string]$state.agentResult
                agentSummary = [string]$state.agentSummary
                completedAt = [string]$state.completedAt
            }
        }
        else {
            $null
        }
        runtime = $runtime
        queue = $queue
        tasks = $tasks
        runs = $runs
        agentRuns = $agentRuns
        oracle = [ordered]@{
            locked = [bool](
                $state -and [bool]$state.oracleLocked
            )
            snapshot = $oracleSnapshot
        }
        brain = [ordered]@{
            optional = $true
            enabled = [bool](
                $projectConfig -and
                $projectConfig.brain -and
                [bool]$projectConfig.brain.enabled
            )
            harnessBuild = [string]$projectConfig.harness_build
            logAvailable = [bool](
                -not [string]::IsNullOrWhiteSpace($brainLogPath) -and
                (Test-Path -LiteralPath $brainLogPath -PathType Leaf)
            )
        }
        liveLog = ($liveLogParts -join "`n`n")
        actions = @()
        sessionToken = $sessionToken
    }
}

function Invoke-HarnessCoreRequest {
    param(
        [Parameter(Mandatory=$true)]
        $Project,

        [Parameter(Mandatory=$true)]
        [ValidateSet('GET', 'POST')]
        [string]$Method,

        [Parameter(Mandatory=$true)]
        [string]$Route,

        $Body = $null,

        [int]$TimeoutSec = 10
    )

    $baseUrl = ([string]$Project.core.baseUrl).TrimEnd('/')

    if (
        $baseUrl -ne 'http://127.0.0.1:5174' -or
        -not $Route.StartsWith('/')
    ) {
        throw 'Harness Core endpoint is not an approved local route.'
    }

    $parameters = @{
        Uri = $baseUrl + $Route
        Method = $Method
        TimeoutSec = $TimeoutSec
    }

    if ($Method -eq 'POST') {
        $parameters.ContentType = 'application/json'
        $parameters.Body = if ($null -eq $Body) {
            '{}'
        }
        else {
            $Body | ConvertTo-Json -Depth 20 -Compress
        }
    }

    try {
        return Invoke-RestMethod @parameters
    }
    catch {
        $message = $_.Exception.Message
        $response = $_.Exception.Response

        if ($response) {
            try {
                $reader = New-Object IO.StreamReader(
                    $response.GetResponseStream(),
                    [Text.Encoding]::UTF8
                )

                try {
                    $responseBody = $reader.ReadToEnd()
                    $errorObject = $responseBody | ConvertFrom-Json

                    if (-not [string]::IsNullOrWhiteSpace([string]$errorObject.error)) {
                        $message = [string]$errorObject.error
                    }
                }
                finally {
                    $reader.Dispose()
                }
            }
            catch {
            }
        }

        throw "ELECTRIC_HARNESS_CORE: $message"
    }
}

function Convert-CoreEvidenceReferences {
    param($Evidence)

    @(
        foreach ($item in @($Evidence)) {
            $assetId = [string]$item.assetId

            if ([string]::IsNullOrWhiteSpace($assetId)) {
                continue
            }

            [ordered]@{
                assetId = $assetId
                kind = [string]$item.kind
                mime = [string]$item.mime
                filename = [string]$item.filename
                size = [int64]$item.size
                note = [string]$item.note
                taskId = [string]$item.taskId
                projectId = [string]$item.projectId
                derivedFrom = [string]$item.derivedFrom
                timestampSec = $item.timestampSec
                groupId = [string]$item.groupId
                derivativeType = [string]$item.derivativeType
                at = [string]$item.at
            }
        }
    )
}

function Start-ElectronicHarnessCore {
    param(
        [Parameter(Mandatory=$true)]
        $Project
    )

    try {
        [void](
            Invoke-HarnessCoreRequest `
                -Project $Project `
                -Method 'GET' `
                -Route '/api/state' `
                -TimeoutSec 2
        )

        return [ordered]@{
            ok = $true
            alreadyRunning = $true
        }
    }
    catch {
    }

    $scriptPath = [IO.Path]::GetFullPath(
        [string]$Project.core.script
    )
    $workingDirectory = [IO.Path]::GetFullPath(
        [string]$Project.core.workingDirectory
    )

    if (
        $scriptPath -ne 'D:\Private\APP\Electronic\tools\ElectricHarness\harness-core.mjs' -or
        $workingDirectory -ne 'D:\Private\APP\Electronic' -or
        -not (Test-Path -LiteralPath $scriptPath -PathType Leaf) -or
        -not (Test-Path -LiteralPath $workingDirectory -PathType Container)
    ) {
        throw 'Electronic Harness Core launch profile is invalid.'
    }

    $process = Start-Process `
        -FilePath 'node.exe' `
        -ArgumentList @(
            $scriptPath,
            'serve'
        ) `
        -WorkingDirectory $workingDirectory `
        -WindowStyle Hidden `
        -PassThru

    for ($i = 0; $i -lt 30; $i++) {
        Start-Sleep -Milliseconds 250

        try {
            $state = Invoke-HarnessCoreRequest `
                -Project $Project `
                -Method 'GET' `
                -Route '/api/state' `
                -TimeoutSec 1

            return [ordered]@{
                ok = $true
                alreadyRunning = $false
                processId = $process.Id
                buildId = [string]$state.buildId
            }
        }
        catch {
        }
    }

    throw 'Electronic Harness Core did not become ready on 127.0.0.1:5174.'
}

function Get-ElectronicStatus {
    param(
        [Parameter(Mandatory=$true)]
        $Project
    )

    try {
        $core = Invoke-HarnessCoreRequest `
            -Project $Project `
            -Method 'GET' `
            -Route '/api/state' `
            -TimeoutSec 4

        if (
            [string]$core.project.id -ne
            [string]$Project.core.projectId
        ) {
            throw (
                'Core active project mismatch. Expected=' +
                [string]$Project.core.projectId +
                ' Actual=' +
                [string]$core.project.id
            )
        }

        $brainStatus = Invoke-HarnessCoreRequest `
            -Project $Project `
            -Method 'GET' `
            -Route '/api/brain/status' `
            -TimeoutSec 6

        return [ordered]@{
            projectId = [string]$Project.id
            projectName = [string]$Project.name
            version = '0.2'
            adapter = 'harness-core'
            readOnly = [bool]$Project.readOnly
            paused = [bool]$Project.paused
            available = $true
            coreOnline = $true
            coreBuildId = [string]$core.buildId
            state = [string]$core.state.state
            status = $core.status
            busy = [bool]$core.busy
            phase = $core.phase
            runReservation = $core.runReservation
            currentTask = [ordered]@{
                taskId = [string]$core.state.taskId
                runId = [string]$core.state.runId
                result = [string]$core.state.result
                nextAction = [string]$core.state.nextAction
                ownerIntentStatus = [string]$core.ownerIntentStatus
                visualMachineGate = [string]$core.selfHeal.visualMachineGate
                agentResult = [string]$core.state.agentResult
                agentSummary = [string]$core.state.agentSummary
                validationCommand = [string]$core.state.validationCommand
                validationExitCode = $core.state.validationExitCode
                completedAt = [string]$core.state.completedAt
            }
            taskSpec = $core.task
            recentTasks = @($core.recentTasks)
            strategy = $core.selfHeal.strategy
            progress = [ordered]@{
                status = $core.status
                phase = $core.phase
                attempt = $core.selfHeal.attempt
                validationMetrics = $core.selfHeal.validationMetrics
                bestFailedCount = $core.selfHeal.bestFailedCount
                visualFailureRepeatCount = $core.selfHeal.visualFailureRepeatCount
                ownerRejectionStreak = $core.selfHeal.ownerRejectionStreak
            }
            runtime = [ordered]@{
                profile = $core.project.runtime
                appUrl = [string]$core.appUrl
                managedRuntimePid = $core.process.managedRuntimePid
                process = $core.process
                gate = $core.selfHeal.runtimeGate
            }
            oracle = [ordered]@{
                locked = [bool]$core.selfHeal.oracleLocked
                ownerContract = $core.task.owner_visual_contract
                visualMachineGate = [string]$core.selfHeal.visualMachineGate
            }
            brain = [ordered]@{
                optional = $true
                enabled = [bool]$core.project.brain.enabled
                supervisor = $core.supervisor
                status = $brainStatus
                root = [string]$core.brain.root
            }
            costQuota = $brainStatus.costGuard
            history = @($core.brain.history)
            memory = @($core.brain.memory)
            skills = @($core.brain.skills)
            evidence = Convert-CoreEvidenceReferences `
                -Evidence $core.storedEvidence
            liveLog = (@($core.logs) -join "`n")
            updater = [ordered]@{
                projectRediscoverApi = $true
                coreRestartApi = $true
                softwareUpdateApi = $false
            }
            actions = @($Project.actions)
            sessionToken = $sessionToken
        }
    }
    catch {
        $fallback = Get-ElectronicFileStatus -Project $Project
        $fallback['version'] = '0.2'
        $fallback['adapter'] = 'harness-core'
        $fallback['readOnly'] = $true
        $fallback['paused'] = [bool]$Project.paused
        $fallback['available'] = $false
        $fallback['coreOnline'] = $false
        $fallback['coreError'] = $_.Exception.Message
        $fallback['actions'] = @(
            $Project.actions |
            Where-Object {
                [string]$_.id -eq 'core-start'
            }
        )
        return $fallback
    }
}

function Invoke-ElectronicCoreAction {
    param(
        [Parameter(Mandatory=$true)]
        $Project,

        [Parameter(Mandatory=$true)]
        [string]$ActionId,

        $Body
    )

    if ($ActionId -eq 'core-start') {
        return Start-ElectronicHarnessCore -Project $Project
    }

    $coreState = Invoke-HarnessCoreRequest `
        -Project $Project `
        -Method 'GET' `
        -Route '/api/state' `
        -TimeoutSec 4

    if (
        [string]$coreState.project.id -ne
        [string]$Project.core.projectId
    ) {
        throw 'Electronic action blocked because Harness Core has another active project.'
    }

    switch ($ActionId) {
        'task-create' {
            $request = [string]$Body.request

            if ([string]::IsNullOrWhiteSpace($request)) {
                throw 'Task request is empty.'
            }

            return Invoke-HarnessCoreRequest `
                -Project $Project `
                -Method 'POST' `
                -Route '/api/task/create' `
                -Body ([ordered]@{
                    request = $request.Trim()
                    evidence = Convert-CoreEvidenceReferences `
                        -Evidence $Body.evidence
                }) `
                -TimeoutSec 30
        }

        'evidence-upload' {
            $base64 = [string]$Body.dataBase64

            if (
                [string]::IsNullOrWhiteSpace($base64) -or
                $base64.Length -gt 72MB
            ) {
                throw 'Evidence payload is empty or exceeds the Core upload limit.'
            }

            return Invoke-HarnessCoreRequest `
                -Project $Project `
                -Method 'POST' `
                -Route '/api/evidence/upload' `
                -Body ([ordered]@{
                    filename = ([string]$Body.filename).Substring(
                        0,
                        [Math]::Min(240, ([string]$Body.filename).Length)
                    )
                    mime = ([string]$Body.mime).Substring(
                        0,
                        [Math]::Min(120, ([string]$Body.mime).Length)
                    )
                    dataBase64 = $base64
                    note = [string]$Body.note
                    taskId = [string]$Body.taskId
                    derivedFrom = [string]$Body.derivedFrom
                    timestampSec = $Body.timestampSec
                    groupId = [string]$Body.groupId
                    derivativeType = [string]$Body.derivativeType
                }) `
                -TimeoutSec 120
        }

        'task-run' {
            return Invoke-HarnessCoreRequest `
                -Project $Project `
                -Method 'POST' `
                -Route '/api/task/run' `
                -Body @{
                    taskId = [string]$Body.taskId
                } `
                -TimeoutSec 10
        }

        'task-recover' {
            return Invoke-HarnessCoreRequest `
                -Project $Project `
                -Method 'POST' `
                -Route '/api/task/recover' `
                -Body @{
                    taskId = [string]$Body.taskId
                } `
                -TimeoutSec 20
        }

        'task-cancel' {
            return Invoke-HarnessCoreRequest `
                -Project $Project `
                -Method 'POST' `
                -Route '/api/task/cancel' `
                -Body @{} `
                -TimeoutSec 10
        }

        'review-fail' {
            $feedback = [string]$Body.feedback

            if ([string]::IsNullOrWhiteSpace($feedback)) {
                throw 'FAIL requires Owner feedback.'
            }

            return Invoke-HarnessCoreRequest `
                -Project $Project `
                -Method 'POST' `
                -Route '/api/review' `
                -Body ([ordered]@{
                    decision = 'FAIL'
                    feedback = $feedback.Trim()
                    evidence = Convert-CoreEvidenceReferences `
                        -Evidence $Body.evidence
                }) `
                -TimeoutSec 900
        }

        'review-pass' {
            return Invoke-HarnessCoreRequest `
                -Project $Project `
                -Method 'POST' `
                -Route '/api/review' `
                -Body @{
                    decision = 'PASS'
                    feedback = ''
                    evidence = @()
                } `
                -TimeoutSec 900
        }

        'skill-promote' {
            return Invoke-HarnessCoreRequest `
                -Project $Project `
                -Method 'POST' `
                -Route '/api/skills/promote' `
                -Body ([ordered]@{
                    taskId = [string]$Body.taskId
                    name = [string]$Body.name
                    instruction = [string]$Body.instruction
                }) `
                -TimeoutSec 120
        }

        'project-rediscover' {
            return Invoke-HarnessCoreRequest `
                -Project $Project `
                -Method 'POST' `
                -Route '/api/project/rediscover' `
                -Body @{} `
                -TimeoutSec 30
        }

        'core-restart' {
            return Invoke-HarnessCoreRequest `
                -Project $Project `
                -Method 'POST' `
                -Route '/api/core/restart' `
                -Body @{} `
                -TimeoutSec 10
        }

        default {
            throw 'Electronic action is not implemented.'
        }
    }
}

function Get-WorkspaceFingerprint {
    $headResult = Invoke-Git -Arguments @(
        'rev-parse',
        'HEAD'
    )

    if ($headResult.ExitCode -ne 0) {
        throw 'Unable to resolve HEAD.'
    }

    $head = $headResult.Output[-1].Trim()

    $diffResult = Invoke-Git -Arguments @(
        'diff',
        '--binary',
        'HEAD',
        '--'
    )

    if ($diffResult.ExitCode -ne 0) {
        throw 'Unable to generate workspace diff.'
    }

    $untrackedResult = Invoke-Git -Arguments @(
        'ls-files',
        '--others',
        '--exclude-standard',
        '--',
        'firmware/active/HINK213_CLOCK_22_BASE'
    )

    if ($untrackedResult.ExitCode -ne 0) {
        throw 'Unable to enumerate untracked firmware files.'
    }

    $builder = New-Object Text.StringBuilder

    [void]$builder.AppendLine("HEAD=$head")
    [void]$builder.AppendLine('=== TRACKED DIFF ===')

    foreach ($line in $diffResult.Output) {
        [void]$builder.AppendLine($line)
    }

    [void]$builder.AppendLine('=== UNTRACKED FIRMWARE ===')

    foreach ($relativePath in @($untrackedResult.Output | Sort-Object)) {
        if ([string]::IsNullOrWhiteSpace($relativePath)) {
            continue
        }

        $absolutePath = Join-Path $repoRoot $relativePath

        if (-not (Test-Path -LiteralPath $absolutePath -PathType Leaf)) {
            continue
        }

        $fileHash = Get-Sha256Hex -Path $absolutePath
        [void]$builder.AppendLine("$relativePath|$fileHash")
    }

    Get-TextSha256 -Text $builder.ToString()
}

function Get-RepoState {
    $branchResult = Invoke-Git -Arguments @(
        'branch',
        '--show-current'
    )

    $headResult = Invoke-Git -Arguments @(
        'rev-parse',
        'HEAD'
    )

    $statusResult = Invoke-Git -Arguments @(
        'status',
        '--porcelain=v1',
        '--untracked-files=normal'
    )

    $stagedResult = Invoke-Git -Arguments @(
        'diff',
        '--cached',
        '--name-only'
    )

    $dirtyResult = Invoke-Git -Arguments @(
        'diff',
        '--name-only'
    )

    $branch = if (
        $branchResult.ExitCode -eq 0 -and
        $branchResult.Output.Count -gt 0
    ) {
        $branchResult.Output[-1].Trim()
    }
    else {
        ''
    }

    $head = if (
        $headResult.ExitCode -eq 0 -and
        $headResult.Output.Count -gt 0
    ) {
        $headResult.Output[-1].Trim()
    }
    else {
        ''
    }

    $statusLines = @($statusResult.Output)

    $untracked = @(
        $statusLines |
        Where-Object { $_.StartsWith('?? ') }
    )

    $trackedStatus = @(
        $statusLines |
        Where-Object {
            $_ -and
            -not $_.StartsWith('?? ')
        }
    )

    [PSCustomObject]@{
        Branch = $branch
        Head = $head
        TrackedStatus = $trackedStatus
        DirtyTrackedFiles = @(
            $dirtyResult.Output |
            Where-Object { $_ }
        )
        StagedFiles = @(
            $stagedResult.Output |
            Where-Object { $_ }
        )
        Untracked = $untracked
    }
}

function Get-PrepareTrustState {
    if ($script:PrepareTrustFailureOverride) {
        return $script:PrepareTrustFailureOverride
    }

    Read-Utf8JsonFile -Path $prepareTrustStatePath
}

function Set-PrepareTrustState {
    param(
        [Parameter(Mandatory=$true)]
        [string]$Status,

        [Parameter(Mandatory=$true)]
        [string]$AttemptId,

        [hashtable]$Data = @{}
    )

    if (-not (Test-Path -LiteralPath $prepareEvidenceRoot -PathType Container)) {
        [void](
            New-Item `
                -ItemType Directory `
                -Path $prepareEvidenceRoot `
                -Force
        )
    }

    $record = [ordered]@{
        schema = 'eink-control-center-prepare-trust-v1'
        attemptId = $AttemptId
        status = $Status
        startedUtc = [DateTime]::UtcNow.ToString('o')
        completedUtc = if ($Status -eq 'RUNNING') {
            $null
        }
        else {
            [DateTime]::UtcNow.ToString('o')
        }
        branch = ''
        head = ''
        workspaceFingerprint = ''
        manifestPath = ''
        lockPath = ''
        evidenceDir = ''
        packedSha256 = ''
        reason = ''
        durable = $false
    }

    $previous = Get-PrepareTrustState

    if (
        $previous -and
        [string]$previous.attemptId -eq $AttemptId
    ) {
        foreach ($property in $previous.PSObject.Properties) {
            if ($record.Contains($property.Name)) {
                $record[$property.Name] = $property.Value
            }
        }

        $record['status'] = $Status

        if ($Status -ne 'RUNNING') {
            $record['completedUtc'] = [DateTime]::UtcNow.ToString('o')
        }
    }

    foreach ($key in $Data.Keys) {
        if ($record.Contains($key)) {
            $record[$key] = $Data[$key]
        }
    }

    $record['durable'] = $true

    try {
        [IO.File]::WriteAllText(
            $prepareTrustStatePath,
            ($record | ConvertTo-Json -Depth 8),
            [Text.UTF8Encoding]::new($false)
        )

        $script:PrepareTrustFailureOverride = $null
    }
    catch {
        $record['status'] = 'FAIL'
        $record['reason'] = 'PREPARE_TRUST_STATE_WRITE_FAILED_BURN_DISABLED'
        $record['durable'] = $false
        $record['completedUtc'] = [DateTime]::UtcNow.ToString('o')
        $script:PrepareTrustFailureOverride = [PSCustomObject]$record
    }

    return [PSCustomObject]$record
}

function Initialize-PrepareTrustState {
    $trust = Get-PrepareTrustState

    if ($trust -and [string]$trust.status -eq 'RUNNING') {
        [void](
            Set-PrepareTrustState `
                -Status 'TIMEOUT' `
                -AttemptId ([string]$trust.attemptId) `
                -Data @{
                    reason = 'PREVIOUS_HUB_ENDED_BEFORE_PREPARE_COMPLETED'
                }
        )

        Set-LastLog `
            -Action 'PREPARE_TEST' `
            -Result 'BLOCKED' `
            -Lines @(
                'LATEST_PREPARE: TIMEOUT',
                'Burn remains disabled until a new prepare-test PASS.'
            )

        return
    }

    if (-not $trust) {
        $legacyDirs = @(
            Get-ChildItem `
                -LiteralPath $prepareEvidenceRoot `
                -Directory `
                -ErrorAction SilentlyContinue
        )

        if ($legacyDirs.Count -gt 0) {
            [void](
                Set-PrepareTrustState `
                    -Status 'STALE_REJECTED' `
                    -AttemptId ('legacy-' + [Guid]::NewGuid().ToString('N')) `
                    -Data @{
                        reason = 'LATEST_PREPARE_TRUST_STATE_MISSING_NO_FALLBACK'
                    }
            )

            Set-LastLog `
                -Action 'PREPARE_TEST' `
                -Result 'BLOCKED' `
                -Lines @(
                    'LATEST_PREPARE: STALE_REJECTED',
                    'Older prepare artifacts are not eligible for burn.',
                    'Run a new prepare-test and require PASS.'
                )
        }
    }
}

function Set-PrepareAttemptFailure {
    param(
        [Parameter(Mandatory=$true)]
        [string]$AttemptId,

        [Parameter(Mandatory=$true)]
        [string]$Reason
    )

    [void](
        Set-PrepareTrustState `
            -Status 'FAIL' `
            -AttemptId $AttemptId `
            -Data @{
                reason = $Reason
            }
    )
}

function Get-LatestPrepareCandidate {
    param(
        [Parameter(Mandatory=$true)]
        $RepoState
    )

    $trust = Get-PrepareTrustState

    if (
        -not $trust -or
        [string]$trust.status -ne 'PASS'
    ) {
        return $null
    }

    $manifestPath = [string]$trust.manifestPath
    $lockPath = [string]$trust.lockPath

    if (
        [string]::IsNullOrWhiteSpace($manifestPath) -or
        [string]::IsNullOrWhiteSpace($lockPath) -or
        -not (Test-Path -LiteralPath $manifestPath -PathType Leaf) -or
        -not (Test-Path -LiteralPath $lockPath -PathType Leaf)
    ) {
        return $null
    }

    $evidenceParent = Split-Path -Parent $manifestPath
    $evidenceDir = [IO.Path]::GetFullPath($evidenceParent)
    $trustedEvidenceDir = [IO.Path]::GetFullPath(
        [string]$trust.evidenceDir
    )
    $fullLockPath = [IO.Path]::GetFullPath($lockPath)
    $expectedLockPath = Join-Path $evidenceDir 'control-center-lock.json'
    $fullExpectedLockPath = [IO.Path]::GetFullPath($expectedLockPath)

    if (
        -not $evidenceDir.Equals(
            $trustedEvidenceDir,
            [StringComparison]::OrdinalIgnoreCase
        ) -or
        -not $fullLockPath.Equals(
            $fullExpectedLockPath,
            [StringComparison]::OrdinalIgnoreCase
        )
    ) {
        return $null
    }

    $manifest = Read-Utf8JsonFile -Path $manifestPath
    $lock = Read-Utf8JsonFile -Path $lockPath

    if (
        -not $manifest -or
        -not $lock -or
        [string]$manifest.nextState -ne 'OWNER_BURN_CONFIRMATION_REQUIRED'
    ) {
        return $null
    }

    if (
        [string]$trust.branch -ne [string]$RepoState.Branch -or
        [string]$trust.head -ne [string]$RepoState.Head -or
        [string]$lock.branch -ne [string]$RepoState.Branch -or
        [string]$lock.head -ne [string]$RepoState.Head
    ) {
        return $null
    }

    $packedPath = [string]$manifest.packed.path

    if (-not (Test-Path -LiteralPath $packedPath -PathType Leaf)) {
        return $null
    }

    $packedFile = Get-Item -LiteralPath $packedPath

    if ($packedFile.Length -ne [int64]$profile.artifactPolicy.packedSpiBytes) {
        return $null
    }

    $actualSha = Get-Sha256Hex -Path $packedPath
    $expectedSha = ([string]$manifest.packed.sha256).ToUpperInvariant()

    if (
        $actualSha -ne $expectedSha -or
        ([string]$lock.packedSha256).ToUpperInvariant() -ne $actualSha -or
        ([string]$trust.packedSha256).ToUpperInvariant() -ne $actualSha
    ) {
        return $null
    }

    $currentFingerprint = Get-WorkspaceFingerprint

    if (
        ([string]$lock.workspaceFingerprint).ToUpperInvariant() -ne $currentFingerprint -or
        ([string]$trust.workspaceFingerprint).ToUpperInvariant() -ne $currentFingerprint
    ) {
        return $null
    }

    return [PSCustomObject]@{
        Path = $packedPath
        Size = [int64]$packedFile.Length
        Sha256 = $actualSha
        Manifest = $manifestPath
        EvidenceDir = $evidenceDir
        WorkspaceFingerprint = $currentFingerprint
        AttemptId = [string]$trust.attemptId
    }
}

function Get-ControlStatus {
    $repo = Get-RepoState
    $trust = Get-PrepareTrustState
    $candidate = Get-LatestPrepareCandidate -RepoState $repo

    $state = if ($script:Busy) {
        'RUNNING'
    }
    elseif ($script:LastResult -eq 'SPI_BURN_VERIFIED') {
        'SPI_BURN_VERIFIED'
    }
    elseif (
        $script:LastResult -eq 'BLOCKED' -or
        (
            $trust -and
            [string]$trust.status -notin @('PASS')
        )
    ) {
        'BLOCKED'
    }
    elseif ($candidate) {
        'READY_TO_BURN'
    }
    else {
        'IDLE'
    }

    [ordered]@{
        projectId = 'eink'
        projectName = 'EINK / Clock'
        version = '0.2'
        url = "http://127.0.0.1:$Port/"
        branch = $repo.Branch
        head = $repo.Head
        state = $state
        busy = [bool]$script:Busy
        trackedDirtyCount = @($repo.TrackedStatus).Count
        stagedCount = @($repo.StagedFiles).Count
        untrackedCount = @($repo.Untracked).Count
        readyToBurn = [bool]($candidate -and -not $script:Busy)
        prepareTrust = if ($trust) {
            [ordered]@{
                attemptId = [string]$trust.attemptId
                status = [string]$trust.status
                startedUtc = [string]$trust.startedUtc
                completedUtc = [string]$trust.completedUtc
                reason = [string]$trust.reason
            }
        }
        else {
            $null
        }
        artifact = if ($candidate) {
            [ordered]@{
                path = $candidate.Path
                size = $candidate.Size
                sha256 = $candidate.Sha256
                manifest = $candidate.Manifest
            }
        }
        else {
            $null
        }
        lastAction = $script:LastAction
        lastResult = $script:LastResult
        lastLog = ($script:LastLog -join "`n")
        sessionToken = $sessionToken
    }
}

function Get-ProjectStatus {
    param(
        [Parameter(Mandatory=$true)]
        [string]$ProjectId
    )

    $project = Get-RegistryProject -ProjectId $ProjectId

    if (-not $project) {
        return $null
    }

    switch ([string]$project.adapter) {
        'eink' {
            $status = Get-ControlStatus
            $status['adapter'] = 'eink'
            $status['readOnly'] = $false
            $status['available'] = $true
            $status['actions'] = @($project.actions)
            return $status
        }

        'harness-core' {
            return Get-ElectronicStatus -Project $project
        }

        default {
            return [ordered]@{
                projectId = [string]$project.id
                projectName = [string]$project.name
                version = '0.2'
                adapter = [string]$project.adapter
                readOnly = $true
                available = $false
                state = 'ADAPTER_UNAVAILABLE'
                actions = @()
                sessionToken = $sessionToken
            }
        }
    }
}

function Get-HubStatus {
    $projects = @(
        foreach ($project in @($projectRegistry.projects)) {
            [ordered]@{
                id = [string]$project.id
                name = [string]$project.name
                adapter = [string]$project.adapter
                brainOptional = [bool]$project.brainOptional
                actions = @($project.actions)
            }
        }
    )

    [ordered]@{
        hubId = 'harness-control-center'
        name = 'Harness Control Center'
        version = '0.2'
        bind = "127.0.0.1:$Port"
        defaultProjectId = 'eink'
        projects = $projects
        sessionToken = $sessionToken
    }
}

function Set-LastLog {
    param(
        [string]$Action,
        [string]$Result,
        [string[]]$Lines
    )

    $script:LastAction = $Action
    $script:LastResult = $Result
    $script:LastLog = @($Lines)
}

function Invoke-PrepareAction {
    if ($script:Busy) {
        return Get-ControlStatus
    }

    $script:Busy = $true
    $attemptId = [Guid]::NewGuid().ToString('N')

    try {
        Set-LastLog `
            -Action 'PREPARE_TEST' `
            -Result 'RUNNING' `
            -Lines @(
                'Starting EINK prepare-test...',
                'Build + pack + verify only.',
                'No SPI burn will be performed.'
            )

        $repoAtStart = Get-RepoState

        $trustStart = Set-PrepareTrustState `
            -Status 'RUNNING' `
            -AttemptId $attemptId `
            -Data @{
                branch = [string]$repoAtStart.Branch
                head = [string]$repoAtStart.Head
                reason = 'PREPARE_IN_PROGRESS'
            }

        if (-not [bool]$trustStart.durable) {
            throw 'PREPARE_TRUST_STATE_NOT_DURABLE_BURN_DISABLED'
        }

        $beforeFingerprint = Get-WorkspaceFingerprint

        $trustFingerprint = Set-PrepareTrustState `
            -Status 'RUNNING' `
            -AttemptId $attemptId `
            -Data @{
                workspaceFingerprint = $beforeFingerprint
            }

        if (-not [bool]$trustFingerprint.durable) {
            throw 'PREPARE_TRUST_FINGERPRINT_NOT_DURABLE_BURN_DISABLED'
        }

        $result = Invoke-NativeText `
            -FilePath 'powershell.exe' `
            -Arguments @(
                '-NoProfile',
                '-ExecutionPolicy',
                'Bypass',
                '-File',
                $prepareScript,
                'prepare-test'
            )

        $output = @($result.Output)

        if (
            $result.ExitCode -ne 0 -or
            -not ($output -match '^EINK HARNESS: PASS$') -or
            -not ($output -match '^NEXT_STATE: OWNER_BURN_CONFIRMATION_REQUIRED$')
        ) {
            Set-PrepareAttemptFailure `
                -AttemptId $attemptId `
                -Reason 'HARNESS_PREPARE_FAILED'

            Set-LastLog `
                -Action 'PREPARE_TEST' `
                -Result 'BLOCKED' `
                -Lines $output

            return
        }

        $afterFingerprint = Get-WorkspaceFingerprint

        if ($beforeFingerprint -ne $afterFingerprint) {
            Set-PrepareAttemptFailure `
                -AttemptId $attemptId `
                -Reason 'SOURCE_CHANGED_DURING_PREPARE'

            Set-LastLog `
                -Action 'PREPARE_TEST' `
                -Result 'BLOCKED' `
                -Lines (
                    $output +
                    'BLOCKED: SOURCE_CHANGED_DURING_PREPARE'
                )

            return
        }

        $manifestLine = @(
            $output |
            Where-Object {
                $_ -match '^MANIFEST:\s+.+$'
            }
        ) | Select-Object -Last 1

        if (-not $manifestLine) {
            Set-PrepareAttemptFailure `
                -AttemptId $attemptId `
                -Reason 'MANIFEST_NOT_FOUND'

            Set-LastLog `
                -Action 'PREPARE_TEST' `
                -Result 'BLOCKED' `
                -Lines (
                    $output +
                    'BLOCKED: MANIFEST_NOT_FOUND'
                )

            return
        }

        $manifestPath = (
            $manifestLine -replace '^MANIFEST:\s+', ''
        ).Trim()

        if (-not (Test-Path -LiteralPath $manifestPath -PathType Leaf)) {
            Set-PrepareAttemptFailure `
                -AttemptId $attemptId `
                -Reason 'MANIFEST_FILE_MISSING'

            Set-LastLog `
                -Action 'PREPARE_TEST' `
                -Result 'BLOCKED' `
                -Lines (
                    $output +
                    'BLOCKED: MANIFEST_FILE_MISSING'
                )

            return
        }

        $manifest = Get-Content -LiteralPath $manifestPath -Raw | ConvertFrom-Json

        $packedPath = [string]$manifest.packed.path

        if (-not (Test-Path -LiteralPath $packedPath -PathType Leaf)) {
            Set-PrepareAttemptFailure `
                -AttemptId $attemptId `
                -Reason 'PACKED_FILE_MISSING'

            Set-LastLog `
                -Action 'PREPARE_TEST' `
                -Result 'BLOCKED' `
                -Lines (
                    $output +
                    'BLOCKED: PACKED_FILE_MISSING'
                )

            return
        }

        $packedSha = Get-Sha256Hex -Path $packedPath

        if (
            $packedSha -ne
            ([string]$manifest.packed.sha256).ToUpperInvariant()
        ) {
            Set-PrepareAttemptFailure `
                -AttemptId $attemptId `
                -Reason 'PACKED_SHA_CHANGED'

            Set-LastLog `
                -Action 'PREPARE_TEST' `
                -Result 'BLOCKED' `
                -Lines (
                    $output +
                    'BLOCKED: PACKED_SHA_CHANGED'
                )

            return
        }

        $repo = Get-RepoState

        $lock = [ordered]@{
            schema = 'eink-control-center-lock-v1'
            createdUtc = [DateTime]::UtcNow.ToString('o')
            branch = $repo.Branch
            head = $repo.Head
            workspaceFingerprint = $afterFingerprint
            packedSha256 = $packedSha
            packedPath = $packedPath
            nextState = 'OWNER_BURN_CONFIRMATION_REQUIRED'
        }

        $lockPath = Join-Path (
            Split-Path -Parent $manifestPath
        ) 'control-center-lock.json'

        [IO.File]::WriteAllText(
            $lockPath,
            ($lock | ConvertTo-Json -Depth 8),
            [Text.UTF8Encoding]::new($false)
        )

        $passTrust = Set-PrepareTrustState `
            -Status 'PASS' `
            -AttemptId $attemptId `
            -Data @{
                branch = [string]$repo.Branch
                head = [string]$repo.Head
                workspaceFingerprint = $afterFingerprint
                manifestPath = $manifestPath
                lockPath = $lockPath
                evidenceDir = (Split-Path -Parent $manifestPath)
                packedSha256 = $packedSha
                reason = 'PREPARE_PASS_LOCKED_ARTIFACT'
            }

        if (
            -not [bool]$passTrust.durable -or
            [string]$passTrust.status -ne 'PASS'
        ) {
            throw 'PREPARE_PASS_TRUST_NOT_DURABLE_BURN_DISABLED'
        }

        Set-LastLog `
            -Action 'PREPARE_TEST' `
            -Result 'PASS' `
            -Lines $output
    }
    catch {
        Set-PrepareAttemptFailure `
            -AttemptId $attemptId `
            -Reason ('EXCEPTION: ' + $_.Exception.Message)

        Set-LastLog `
            -Action 'PREPARE_TEST' `
            -Result 'BLOCKED' `
            -Lines @(
                "EXCEPTION: $($_.Exception.Message)"
            )
    }
    finally {
        $script:Busy = $false
    }

    Get-ControlStatus
}

function Get-ExactStashRef {
    param(
        [Parameter(Mandatory=$true)]
        [string]$Label
    )

    $result = Invoke-Git -Arguments @(
        'stash',
        'list',
        '--format=%gd|%s'
    )

    if ($result.ExitCode -ne 0) {
        return $null
    }

    $matches = @(
        $result.Output |
        Where-Object {
            $_ -and $_.Contains($Label)
        }
    )

    if ($matches.Count -ne 1) {
        return $null
    }

    ($matches[0].Split('|', 2)[0]).Trim()
}

function Invoke-BurnAction {
    param(
        [Parameter(Mandatory=$true)]
        $Body
    )

    if ($script:Busy) {
        return Get-ControlStatus
    }

    $repoBefore = Get-RepoState
    $candidate = Get-LatestPrepareCandidate -RepoState $repoBefore

    if (-not $candidate) {
        Set-LastLog `
            -Action 'SPI_BURN' `
            -Result 'BLOCKED' `
            -Lines @(
                'BLOCKED: NO_VALID_LOCKED_ARTIFACT'
            )

        return Get-ControlStatus
    }

    if ([string]$Body.confirm -ne 'BURN') {
        Set-LastLog `
            -Action 'SPI_BURN' `
            -Result 'BLOCKED' `
            -Lines @(
                'BLOCKED: OWNER_CONFIRMATION_REQUIRED'
            )

        return Get-ControlStatus
    }

    $requestedSha = (
        [string]$Body.sha256
    ).Trim().ToUpperInvariant()

    if ($requestedSha -ne $candidate.Sha256) {
        Set-LastLog `
            -Action 'SPI_BURN' `
            -Result 'BLOCKED' `
            -Lines @(
                'BLOCKED: UI_ARTIFACT_SHA_MISMATCH'
            )

        return Get-ControlStatus
    }

    if (@($repoBefore.StagedFiles).Count -gt 0) {
        Set-LastLog `
            -Action 'SPI_BURN' `
            -Result 'BLOCKED' `
            -Lines @(
                'BLOCKED: STAGED_CHANGES_EXIST',
                'Control Center will not rewrite an existing Git index.'
            )

        return Get-ControlStatus
    }

    $script:Busy = $true

    $stashRef = $null
    $originalDirty = @($repoBefore.DirtyTrackedFiles | Sort-Object)

    try {
        Set-LastLog `
            -Action 'SPI_BURN' `
            -Result 'RUNNING' `
            -Lines @(
                'Owner destructive confirmation received.',
                "Artifact SHA256: $($candidate.Sha256)",
                'Preparing clean tracked transaction...',
                'Untracked files will not be touched.'
            )

        if ($originalDirty.Count -gt 0) {
            $label = 'eink-control-center-burn-' + (
                Get-Date -Format 'yyyyMMdd_HHmmss'
            )

            $stashArgs = @(
                'stash',
                'push',
                '-m',
                $label,
                '--'
            ) + $originalDirty

            $stashResult = Invoke-Git -Arguments $stashArgs

            if ($stashResult.ExitCode -ne 0) {
                throw 'Unable to preserve tracked source changes before burn.'
            }

            $stashRef = Get-ExactStashRef -Label $label

            if (-not $stashRef) {
                throw 'Unable to resolve temporary burn stash.'
            }

            $afterStash = Get-RepoState

            if (
                @($afterStash.TrackedStatus).Count -ne 0 -or
                @($afterStash.StagedFiles).Count -ne 0
            ) {
                throw 'Tracked tree did not become clean before burn.'
            }
        }

        $burnResult = Invoke-NativeText `
            -FilePath 'powershell.exe' `
            -Arguments @(
                '-NoProfile',
                '-ExecutionPolicy',
                'Bypass',
                '-File',
                $burnScript,
                '-PackedBin',
                $candidate.Path,
                '-Mode',
                'Burn',
                '-ExpectedPackedSha256',
                $candidate.Sha256,
                '-ConfirmToken',
                [string]$profile.spiBurn.confirmationToken
            )

        $burnLines = @($burnResult.Output)

        if (
            $burnResult.ExitCode -ne 0 -or
            -not ($burnLines -match '^EINK HARNESS: PASS$') -or
            -not ($burnLines -match '^NEXT_STATE: SPI_BURN_VERIFIED$')
        ) {
            Set-LastLog `
                -Action 'SPI_BURN' `
                -Result 'BLOCKED' `
                -Lines $burnLines
        }
        else {
            Set-LastLog `
                -Action 'SPI_BURN' `
                -Result 'SPI_BURN_VERIFIED' `
                -Lines $burnLines
        }
    }
    catch {
        Set-LastLog `
            -Action 'SPI_BURN' `
            -Result 'BLOCKED' `
            -Lines (
                $script:LastLog +
                "EXCEPTION: $($_.Exception.Message)"
            )
    }
    finally {
        if ($stashRef) {
            $restore = Invoke-Git -Arguments @(
                'stash',
                'apply',
                $stashRef
            )

            if ($restore.ExitCode -eq 0) {
                $restored = @(
                    (
                        Get-RepoState
                    ).DirtyTrackedFiles |
                    Sort-Object
                )

                $difference = @(
                    Compare-Object `
                        -ReferenceObject $originalDirty `
                        -DifferenceObject $restored
                )

                if ($difference.Count -eq 0) {
                    $drop = Invoke-Git -Arguments @(
                        'stash',
                        'drop',
                        $stashRef
                    )

                    if ($drop.ExitCode -eq 0) {
                        $script:LastLog +=
                            'SOURCE_RESTORE: PASS'
                    }
                    else {
                        $script:LastLog +=
                            "WARNING: STASH_DROP_FAILED: $stashRef"
                    }
                }
                else {
                    $script:LastResult = 'BLOCKED'
                    $script:LastLog += @(
                        'BLOCKED: SOURCE_RESTORE_SCOPE_MISMATCH',
                        "STASH_PRESERVED: $stashRef"
                    )
                }
            }
            else {
                $script:LastResult = 'BLOCKED'
                $script:LastLog += @(
                    'BLOCKED: SOURCE_RESTORE_FAILED',
                    "STASH_PRESERVED: $stashRef"
                )
            }
        }

        $script:Busy = $false
    }

    Get-ControlStatus
}

function Read-HttpRequest {
    param(
        [Parameter(Mandatory=$true)]
        [Net.Sockets.TcpClient]$Client
    )

    $stream = $Client.GetStream()

    $reader = New-Object IO.StreamReader(
        $stream,
        [Text.Encoding]::UTF8,
        $false,
        4096,
        $true
    )

    $requestLine = $reader.ReadLine()

    if ([string]::IsNullOrWhiteSpace($requestLine)) {
        return $null
    }

    $parts = $requestLine.Split(' ')

    if ($parts.Count -lt 2) {
        return $null
    }

    $method = $parts[0].ToUpperInvariant()
    $path = $parts[1].Split('?')[0]

    $headers = @{}

    while ($true) {
        $line = $reader.ReadLine()

        if ($null -eq $line -or $line.Length -eq 0) {
            break
        }

        $separator = $line.IndexOf(':')

        if ($separator -le 0) {
            continue
        }

        $name = $line.Substring(0, $separator).Trim().ToLowerInvariant()
        $value = $line.Substring($separator + 1).Trim()

        $headers[$name] = $value
    }

    $body = ''

    $contentLength = 0

    if ($headers.ContainsKey('content-length')) {
        [void][int]::TryParse(
            [string]$headers['content-length'],
            [ref]$contentLength
        )
    }

    if ($contentLength -gt 0) {
        $buffer = New-Object char[] $contentLength
        $total = 0

        while ($total -lt $contentLength) {
            $read = $reader.Read(
                $buffer,
                $total,
                $contentLength - $total
            )

            if ($read -le 0) {
                break
            }

            $total += $read
        }

        $body = New-Object string(
            $buffer,
            0,
            $total
        )
    }

    [PSCustomObject]@{
        Method = $method
        Path = $path
        Headers = $headers
        Body = $body
    }
}

function Write-HttpResponse {
    param(
        [Parameter(Mandatory=$true)]
        [Net.Sockets.TcpClient]$Client,

        [int]$StatusCode = 200,

        [string]$ContentType = 'application/json; charset=utf-8',

        [string]$Body = ''
    )

    $reason = switch ($StatusCode) {
        200 { 'OK' }
        400 { 'Bad Request' }
        403 { 'Forbidden' }
        404 { 'Not Found' }
        405 { 'Method Not Allowed' }
        409 { 'Conflict' }
        500 { 'Internal Server Error' }
        default { 'OK' }
    }

    $bodyBytes = [Text.Encoding]::UTF8.GetBytes($Body)

    $headers = @(
        "HTTP/1.1 $StatusCode $reason",
        "Content-Type: $ContentType",
        "Content-Length: $($bodyBytes.Length)",
        'Connection: close',
        'Cache-Control: no-store',
        'X-Content-Type-Options: nosniff',
        "Content-Security-Policy: default-src 'self'; script-src 'unsafe-inline'; style-src 'unsafe-inline'; connect-src 'self'; img-src 'none'; frame-ancestors 'none'",
        '',
        ''
    ) -join "`r`n"

    $headerBytes = [Text.Encoding]::ASCII.GetBytes($headers)

    $stream = $Client.GetStream()

    $stream.Write(
        $headerBytes,
        0,
        $headerBytes.Length
    )

    if ($bodyBytes.Length -gt 0) {
        $stream.Write(
            $bodyBytes,
            0,
            $bodyBytes.Length
        )
    }

    $stream.Flush()
}

function Write-Json {
    param(
        [Parameter(Mandatory=$true)]
        [Net.Sockets.TcpClient]$Client,

        [int]$StatusCode = 200,

        [Parameter(Mandatory=$true)]
        $Value
    )

    Write-HttpResponse `
        -Client $Client `
        -StatusCode $StatusCode `
        -ContentType 'application/json; charset=utf-8' `
        -Body (
            $Value |
            ConvertTo-Json -Depth 10 -Compress
        )
}

function Test-WriteAuthorization {
    param(
        [Parameter(Mandatory=$true)]
        $Request
    )

    if (-not $Request.Headers.ContainsKey('content-type')) {
        return $false
    }

    if (
        -not (
            [string]$Request.Headers['content-type']
        ).StartsWith(
            'application/json',
            [StringComparison]::OrdinalIgnoreCase
        )
    ) {
        return $false
    }

    if (-not $Request.Headers.ContainsKey($writeTokenHeaderKey)) {
        return $false
    }

    return (
        [string]$Request.Headers[$writeTokenHeaderKey] -eq
        $sessionToken
    )
}

$registryIds = @(
    $projectRegistry.projects |
    ForEach-Object { [string]$_.id }
)

if (
    $registryIds.Count -eq 0 -or
    @($registryIds | Select-Object -Unique).Count -ne $registryIds.Count
) {
    throw 'Harness Hub project registry contains missing or duplicate ids.'
}

$einkRegistryProject = Get-RegistryProject -ProjectId 'eink'

if (
    -not $einkRegistryProject -or
    [string]$einkRegistryProject.adapter -ne 'eink' -or
    -not [IO.Path]::GetFullPath(
        [string]$einkRegistryProject.workspace
    ).Equals(
        [IO.Path]::GetFullPath($repoRoot),
        [StringComparison]::OrdinalIgnoreCase
    )
) {
    throw 'EINK registry workspace does not match the running repository.'
}

Initialize-PrepareTrustState

$url = "http://127.0.0.1:$Port/"

$listener = New-Object Net.Sockets.TcpListener(
    [Net.IPAddress]::Loopback,
    $Port
)

try {
    $listener.Start()
}
catch {
    Write-Output 'HARNESS CONTROL CENTER: BLOCKED'
    Write-Output "REASON: PORT_BIND_FAILED_$Port"
    Write-Output $_.Exception.Message
    exit 1
}

Write-Output 'HARNESS CONTROL CENTER: PASS'
Write-Output "URL: $url"
Write-Output 'BIND: 127.0.0.1 ONLY'
Write-Output 'NEXT_STATE: CONTROL_CENTER_RUNNING'

if (-not $NoBrowser) {
    Start-Process $url
}

try {
    while (-not $script:StopRequested) {
        $client = $listener.AcceptTcpClient()

        try {
            $request = Read-HttpRequest -Client $client

            if (-not $request) {
                Write-Json `
                    -Client $client `
                    -StatusCode 400 `
                    -Value @{
                        error = 'BAD_REQUEST'
                    }

                continue
            }

            $hostHeader = if (
                $request.Headers.ContainsKey('host')
            ) {
                [string]$request.Headers['host']
            }
            else {
                ''
            }

            if ($hostHeader -ne "127.0.0.1:$Port") {
                Write-Json `
                    -Client $client `
                    -StatusCode 403 `
                    -Value @{
                        error = 'HOST_REJECTED'
                    }

                continue
            }

            if (
                $request.Method -eq 'GET' -and
                $request.Path -eq '/'
            ) {
                $html = [IO.File]::ReadAllText(
                    $indexPath,
                    [Text.Encoding]::UTF8
                )

                Write-HttpResponse `
                    -Client $client `
                    -StatusCode 200 `
                    -ContentType 'text/html; charset=utf-8' `
                    -Body $html

                continue
            }

            if (
                $request.Method -eq 'GET' -and
                $request.Path -eq '/api/status'
            ) {
                Write-Json `
                    -Client $client `
                    -StatusCode 200 `
                    -Value (
                        Get-HubStatus
                    )

                continue
            }

            if (
                $request.Method -eq 'GET' -and
                $request.Path -match '^/api/projects/([a-z0-9-]+)/status$'
            ) {
                $projectId = [string]$Matches[1]
                $projectStatus = Get-ProjectStatus -ProjectId $projectId

                if (-not $projectStatus) {
                    Write-Json `
                        -Client $client `
                        -StatusCode 404 `
                        -Value @{
                            error = 'PROJECT_NOT_FOUND'
                        }

                    continue
                }

                Write-Json `
                    -Client $client `
                    -StatusCode 200 `
                    -Value $projectStatus

                continue
            }

            if (
                $request.Method -eq 'POST' -and
                $request.Path -match '^/api/projects/([a-z0-9-]+)/actions/([a-z0-9-]+)$'
            ) {
                $projectId = [string]$Matches[1]
                $actionId = [string]$Matches[2]
                $project = Get-RegistryProject -ProjectId $projectId

                if (-not $project) {
                    Write-Json `
                        -Client $client `
                        -StatusCode 404 `
                        -Value @{
                            error = 'PROJECT_NOT_FOUND'
                        }

                    continue
                }

                if (
                    -not (
                        Test-ProjectActionAllowed `
                            -Project $project `
                            -ActionId $actionId `
                            -Method 'POST'
                    )
                ) {
                    Write-Json `
                        -Client $client `
                        -StatusCode 403 `
                        -Value @{
                            error = 'ACTION_NOT_ALLOWED'
                        }

                    continue
                }

                if (-not (Test-WriteAuthorization -Request $request)) {
                    Write-Json `
                        -Client $client `
                        -StatusCode 403 `
                        -Value @{
                            error = 'WRITE_AUTH_REQUIRED'
                        }

                    continue
                }

                if ([string]$project.adapter -eq 'harness-core') {
                    try {
                        $body = if (
                            [string]::IsNullOrWhiteSpace($request.Body)
                        ) {
                            @{}
                        }
                        else {
                            $request.Body | ConvertFrom-Json
                        }
                    }
                    catch {
                        Write-Json `
                            -Client $client `
                            -StatusCode 400 `
                            -Value @{
                                error = 'INVALID_JSON'
                            }

                        continue
                    }

                    $result = Invoke-ElectronicCoreAction `
                        -Project $project `
                        -ActionId $actionId `
                        -Body $body

                    Write-Json `
                        -Client $client `
                        -StatusCode 200 `
                        -Value $result

                    continue
                }

                if (
                    [string]$project.adapter -eq 'eink' -and
                    $actionId -eq 'prepare'
                ) {
                    Write-Json `
                        -Client $client `
                        -StatusCode 200 `
                        -Value (Invoke-PrepareAction)

                    continue
                }

                if (
                    [string]$project.adapter -eq 'eink' -and
                    $actionId -eq 'burn'
                ) {
                    try {
                        $body = if (
                            [string]::IsNullOrWhiteSpace($request.Body)
                        ) {
                            @{}
                        }
                        else {
                            $request.Body | ConvertFrom-Json
                        }
                    }
                    catch {
                        Write-Json `
                            -Client $client `
                            -StatusCode 400 `
                            -Value @{
                                error = 'INVALID_JSON'
                            }

                        continue
                    }

                    Write-Json `
                        -Client $client `
                        -StatusCode 200 `
                        -Value (Invoke-BurnAction -Body $body)

                    continue
                }

                Write-Json `
                    -Client $client `
                    -StatusCode 403 `
                    -Value @{
                        error = 'ACTION_NOT_IMPLEMENTED'
                    }

                continue
            }

            if (
                $request.Method -eq 'POST' -and
                $request.Path -eq '/api/prepare'
            ) {
                if (-not (Test-WriteAuthorization -Request $request)) {
                    Write-Json `
                        -Client $client `
                        -StatusCode 403 `
                        -Value @{
                            error = 'WRITE_AUTH_REQUIRED'
                        }

                    continue
                }

                $result = Invoke-PrepareAction

                Write-Json `
                    -Client $client `
                    -StatusCode 200 `
                    -Value $result

                continue
            }

            if (
                $request.Method -eq 'POST' -and
                $request.Path -eq '/api/burn'
            ) {
                if (-not (Test-WriteAuthorization -Request $request)) {
                    Write-Json `
                        -Client $client `
                        -StatusCode 403 `
                        -Value @{
                            error = 'WRITE_AUTH_REQUIRED'
                        }

                    continue
                }

                try {
                    $body = if (
                        [string]::IsNullOrWhiteSpace($request.Body)
                    ) {
                        @{}
                    }
                    else {
                        $request.Body | ConvertFrom-Json
                    }
                }
                catch {
                    Write-Json `
                        -Client $client `
                        -StatusCode 400 `
                        -Value @{
                            error = 'INVALID_JSON'
                        }

                    continue
                }

                $result = Invoke-BurnAction -Body $body

                Write-Json `
                    -Client $client `
                    -StatusCode 200 `
                    -Value $result

                continue
            }

            if (
                $request.Method -eq 'POST' -and
                $request.Path -eq '/api/shutdown'
            ) {
                if (-not (Test-WriteAuthorization -Request $request)) {
                    Write-Json `
                        -Client $client `
                        -StatusCode 403 `
                        -Value @{
                            error = 'WRITE_AUTH_REQUIRED'
                        }

                    continue
                }

                Write-Json `
                    -Client $client `
                    -StatusCode 200 `
                    -Value @{
                        result = 'STOPPING'
                    }

                $script:StopRequested = $true
                continue
            }

            Write-Json `
                -Client $client `
                -StatusCode 404 `
                -Value @{
                    error = 'NOT_FOUND'
                }
        }
        catch {
            try {
                Write-Json `
                    -Client $client `
                    -StatusCode 500 `
                    -Value @{
                        error = 'SERVER_EXCEPTION'
                        message = $_.Exception.Message
                    }
            }
            catch {
            }
        }
        finally {
            $client.Close()
        }
    }
}
finally {
    $listener.Stop()
}

Write-Output 'HARNESS CONTROL CENTER: STOPPED'
