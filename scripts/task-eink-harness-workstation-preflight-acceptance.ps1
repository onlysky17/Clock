[CmdletBinding()]
param()

$ErrorActionPreference = 'Stop'

$repoRoot = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path
$executorPath = Join-Path $repoRoot 'tools\harness\compiled-task-executor.ps1'
$serverPath = Join-Path $repoRoot 'tools\harness\control-center\server.ps1'
$runRoot = Join-Path (
    [IO.Path]::GetTempPath()
) ("eink-workstation-preflight-" + [Guid]::NewGuid().ToString('N'))
$fixtureRoot = Join-Path $runRoot 'repo'
$codexRoot = Join-Path $runRoot 'codex'
$codexPath = Join-Path $codexRoot 'codex.cmd'
$authPath = Join-Path $codexRoot 'auth.txt'
$configPath = Join-Path $codexRoot 'config.toml'
$ghPath = Join-Path $codexRoot 'gh.cmd'
$ghAuthPath = Join-Path $codexRoot 'gh-auth.txt'
$emptyGlobalGitConfig = Join-Path $runRoot 'empty-global.gitconfig'
$previousGlobalGitConfig = [Environment]::GetEnvironmentVariable(
    'GIT_CONFIG_GLOBAL',
    'Process'
)

function Assert-True {
    param(
        [Parameter(Mandatory=$true)][bool]$Condition,
        [Parameter(Mandatory=$true)][string]$Name
    )
    if (-not $Condition) { throw "ASSERT_FAIL: $Name" }
    Write-Output "$Name`: PASS"
}

function Invoke-FixtureGit {
    param([Parameter(Mandatory=$true)][string[]]$Arguments)

    $result = Invoke-EinkExecutorNative `
        -FilePath 'git' `
        -Arguments $Arguments `
        -WorkingDirectory $fixtureRoot
    if ($result.ExitCode -ne 0) {
        throw "FIXTURE_GIT_FAILED: git $($Arguments -join ' ')"
    }
    @($result.Output)
}

function Set-FixtureText {
    param(
        [Parameter(Mandatory=$true)][string]$Path,
        [Parameter(Mandatory=$true)][AllowEmptyString()][string]$Value
    )
    [IO.File]::WriteAllText($Path, $Value, [Text.UTF8Encoding]::new($false))
}

function Set-HealthyFixture {
    Set-FixtureText -Path $authPath -Value 'ready'
    Set-FixtureText -Path $ghAuthPath -Value 'ready'
    Set-FixtureText -Path $configPath -Value "model = `"gpt-5.6-sol`"`n"
    [void](Invoke-FixtureGit @('config','--local','user.name','EINK Acceptance'))
    [void](Invoke-FixtureGit @('config','--local','user.email','eink-acceptance@example.invalid'))
    [void](Invoke-FixtureGit @('config','--local','core.longpaths','true'))
}

function Invoke-PrerequisiteCheck {
    param(
        [string]$CommandPath = $codexPath,
        [string]$GhPath = $ghPath
    )
    Test-EinkExecutorWorkstationPrerequisites `
        -RepoRoot $fixtureRoot `
        -CodexCommandPath $CommandPath `
        -CodexConfigPath $configPath `
        -GhCommandPath $GhPath
}

function Assert-BlockedCase {
    param(
        [Parameter(Mandatory=$true)]$Result,
        [Parameter(Mandatory=$true)][string]$Code,
        [Parameter(Mandatory=$true)][string]$Name
    )
    $passed = (
        -not $Result.Ready -and
        $Result.Code -eq $Code -and
        $Result.Reason -match '^BLOCKED_PREREQUISITE: [A-Z0-9_]+ - .+\.$'
    )
    if (-not $passed) {
        Write-Output ("ACTUAL_RESULT: " + ($Result | ConvertTo-Json -Compress))
    }
    Assert-True $passed $Name
}

$realStatusBefore = @(& git -C $repoRoot status --short --untracked-files=all)
$realHeadBefore = (& git -C $repoRoot rev-parse HEAD).Trim()

try {
    [void](New-Item -ItemType Directory -Path $fixtureRoot -Force)
    [void](New-Item -ItemType Directory -Path $codexRoot -Force)
    Set-FixtureText -Path $emptyGlobalGitConfig -Value ''
    [Environment]::SetEnvironmentVariable(
        'GIT_CONFIG_GLOBAL',
        $emptyGlobalGitConfig,
        'Process'
    )

    . $executorPath
    Set-FixtureText -Path $codexPath -Value @'
@echo off
setlocal EnableDelayedExpansion
if /I "%~1"=="login" if /I "%~2"=="status" (
    set /p EINK_AUTH=<"%~dp0auth.txt"
    if /I "!EINK_AUTH!"=="ready" (
        echo Logged in
        exit /b 0
    )
    echo Not logged in
    exit /b 1
)
exit /b 2
'@
    Set-FixtureText -Path $ghPath -Value @'
@echo off
setlocal EnableDelayedExpansion
if /I "%~1"=="auth" if /I "%~2"=="status" (
    set /p EINK_GH_AUTH=<"%~dp0gh-auth.txt"
    if /I "!EINK_GH_AUTH!"=="ready" (
        echo Logged in to github.com
        exit /b 0
    )
    echo Not logged in to github.com
    exit /b 1
)
exit /b 2
'@
    [void](Invoke-FixtureGit @('init','-b','main'))
    Set-HealthyFixture

    Assert-BlockedCase `
        -Result (Invoke-PrerequisiteCheck -CommandPath (Join-Path $runRoot 'missing-codex.cmd')) `
        -Code 'CODEX_COMMAND_UNAVAILABLE' `
        -Name 'MISSING_CODEX_COMMAND_BLOCKED'

    Set-HealthyFixture
    Set-FixtureText -Path $authPath -Value 'missing'
    Assert-BlockedCase `
        -Result (Invoke-PrerequisiteCheck) `
        -Code 'CODEX_AUTHENTICATION_UNAVAILABLE' `
        -Name 'MISSING_CODEX_AUTHENTICATION_BLOCKED'

    Set-HealthyFixture
    Assert-BlockedCase `
        -Result (Invoke-PrerequisiteCheck -GhPath (Join-Path $runRoot 'missing-gh.cmd')) `
        -Code 'GH_COMMAND_UNAVAILABLE' `
        -Name 'MISSING_GH_COMMAND_BLOCKED'

    Set-HealthyFixture
    Set-FixtureText -Path $ghAuthPath -Value 'missing'
    Assert-BlockedCase `
        -Result (Invoke-PrerequisiteCheck) `
        -Code 'GH_AUTHENTICATION_UNAVAILABLE' `
        -Name 'MISSING_GH_AUTHENTICATION_BLOCKED'

    Set-HealthyFixture
    Set-FixtureText -Path $configPath -Value "model = `"gpt-5.5`"`n"
    Assert-BlockedCase `
        -Result (Invoke-PrerequisiteCheck) `
        -Code 'CODEX_DEFAULT_MODEL_NOT_GPT_5_6_SOL' `
        -Name 'WRONG_CODEX_DEFAULT_MODEL_BLOCKED'

    Set-HealthyFixture
    [void](Invoke-FixtureGit @('config','--local','--unset-all','user.name'))
    Assert-BlockedCase `
        -Result (Invoke-PrerequisiteCheck) `
        -Code 'GIT_AUTHOR_NAME_MISSING' `
        -Name 'MISSING_GIT_AUTHOR_NAME_BLOCKED'

    Set-HealthyFixture
    [void](Invoke-FixtureGit @('config','--local','--unset-all','user.email'))
    Assert-BlockedCase `
        -Result (Invoke-PrerequisiteCheck) `
        -Code 'GIT_AUTHOR_EMAIL_MISSING' `
        -Name 'MISSING_GIT_AUTHOR_EMAIL_BLOCKED'

    Set-HealthyFixture
    [void](Invoke-FixtureGit @('config','--local','core.longpaths','false'))
    Assert-BlockedCase `
        -Result (Invoke-PrerequisiteCheck) `
        -Code 'GIT_CORE_LONGPATHS_NOT_TRUE' `
        -Name 'GIT_LONGPATHS_FALSE_BLOCKED'

    Set-HealthyFixture
    $healthy = Invoke-PrerequisiteCheck
    Assert-True (
        $healthy.Ready -and
        [string]::IsNullOrWhiteSpace($healthy.Reason)
    ) 'HEALTHY_WORKSTATION_CONTINUES'

    $executor = [IO.File]::ReadAllText($executorPath, [Text.Encoding]::UTF8)
    $executorFunction = [regex]::Match(
        $executor,
        'function Invoke-EinkCompiledTaskExecutor[\s\S]+$'
    ).Value
    Assert-True (
        $executorFunction.IndexOf('Test-EinkExecutorWorkstationPrerequisites') -ge 0 -and
        $executorFunction.IndexOf('Test-EinkExecutorWorkstationPrerequisites') -lt
            $executorFunction.IndexOf("'switch','-c',`$taskBranch")
    ) 'EXECUTOR_PREFLIGHT_BEFORE_TASK_BRANCH_MUTATION'

    $server = [IO.File]::ReadAllText($serverPath, [Text.Encoding]::UTF8)
    Assert-True (
        $server -match "-Event 'BLOCKED_PREREQUISITE'" -and
        $server -match 'Test-EinkExecutorWorkstationPrerequisites'
    ) 'CONTROL_CENTER_SURFACES_BLOCKED_PREREQUISITE'
}
finally {
    [Environment]::SetEnvironmentVariable(
        'GIT_CONFIG_GLOBAL',
        $previousGlobalGitConfig,
        'Process'
    )
    if (Test-Path -LiteralPath $runRoot -PathType Container) {
        [IO.Directory]::Delete($runRoot, $true)
    }
}

$realStatusAfter = @(& git -C $repoRoot status --short --untracked-files=all)
$realHeadAfter = (& git -C $repoRoot rev-parse HEAD).Trim()
Assert-True ($realHeadAfter -eq $realHeadBefore) 'REAL_REPOSITORY_HEAD_UNCHANGED'
$expectedStatus = @(
    ' M tools/harness/compiled-task-executor.ps1',
    ' M tools/harness/control-center/server.ps1',
    '?? scripts/task-eink-harness-workstation-preflight-acceptance.ps1'
)
Assert-True (
    (@($realStatusAfter) -join "`n") -eq ($expectedStatus -join "`n") -or
    (@($realStatusAfter) -join "`n") -eq (@($realStatusBefore) -join "`n")
) 'REAL_REPOSITORY_SCOPE_PRESERVED'

Write-Output 'EINK HARNESS WORKSTATION PREFLIGHT ACCEPTANCE: PASS'
