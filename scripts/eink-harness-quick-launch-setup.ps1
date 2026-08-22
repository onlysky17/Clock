[CmdletBinding()]
param(
    [switch]$Uninstall,
    [switch]$AcceptanceMode,
    [switch]$SkipRegistry,
    [string]$InstallRoot = ''
)

$ErrorActionPreference = 'Stop'
$repoRoot = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path
$sourcePath = Join-Path $repoRoot 'tools\harness\quick-launch\native-host.cs'
$extensionPath = Join-Path $repoRoot 'tools\harness\quick-launch\extension'
$hostName = 'com.eink.harness'
$extensionId = 'bnkeegfocdpoljgaadmaciipdlfcmnkm'
$defaultInstallRoot = Join-Path $env:LOCALAPPDATA 'EINKHarnessNative'

if ([string]::IsNullOrWhiteSpace($InstallRoot)) { $InstallRoot = $defaultInstallRoot }
$InstallRoot = [IO.Path]::GetFullPath($InstallRoot)
$defaultInstallRoot = [IO.Path]::GetFullPath($defaultInstallRoot)

if ($AcceptanceMode) {
    $tempPrefix = [IO.Path]::GetFullPath([IO.Path]::GetTempPath()).TrimEnd('\') + '\'
    if (-not $InstallRoot.StartsWith($tempPrefix, [StringComparison]::OrdinalIgnoreCase)) {
        throw 'Acceptance install root must remain under the system temporary directory.'
    }
}
elseif (-not $InstallRoot.Equals($defaultInstallRoot, [StringComparison]::OrdinalIgnoreCase)) {
    throw 'Production install root is fixed and cannot be overridden.'
}

$chromeKey = 'HKCU:\Software\Google\Chrome\NativeMessagingHosts\' + $hostName
$edgeKey = 'HKCU:\Software\Microsoft\Edge\NativeMessagingHosts\' + $hostName

if ($Uninstall) {
    if (-not $SkipRegistry) {
        foreach ($key in @($chromeKey, $edgeKey)) {
            if (Test-Path -LiteralPath $key) { Remove-Item -LiteralPath $key -Recurse -Force }
        }
    }
    if (Test-Path -LiteralPath $InstallRoot -PathType Container) {
        Remove-Item -LiteralPath $InstallRoot -Recurse -Force
    }
    Write-Output 'EINK HARNESS QUICK LAUNCH: UNINSTALLED'
    exit 0
}

$requiredFiles = @(
    $sourcePath,
    (Join-Path $extensionPath 'manifest.json'),
    (Join-Path $extensionPath 'background.js'),
    (Join-Path $extensionPath 'popup.html'),
    (Join-Path $extensionPath 'icon.png')
)
foreach ($required in $requiredFiles) {
    if (-not (Test-Path -LiteralPath $required -PathType Leaf)) {
        throw "Required quick-launch file missing: $required"
    }
}

[void](New-Item -ItemType Directory -Path $InstallRoot -Force)
$hostExe = Join-Path $InstallRoot 'eink-harness-native.exe'
$hostManifest = Join-Path $InstallRoot ($hostName + '.json')
$compiler = Join-Path $env:WINDIR 'Microsoft.NET\Framework64\v4.0.30319\csc.exe'
if (-not (Test-Path -LiteralPath $compiler -PathType Leaf)) {
    $compiler = Join-Path $env:WINDIR 'Microsoft.NET\Framework\v4.0.30319\csc.exe'
}
if (-not (Test-Path -LiteralPath $compiler -PathType Leaf)) {
    throw 'Microsoft .NET Framework C# compiler was not found.'
}

if (Test-Path -LiteralPath $hostExe -PathType Leaf) { Remove-Item -LiteralPath $hostExe -Force }
& $compiler /nologo /target:exe /optimize+ "/out:$hostExe" /reference:System.Web.Extensions.dll $sourcePath
if ($LASTEXITCODE -ne 0 -or -not (Test-Path -LiteralPath $hostExe -PathType Leaf)) {
    throw 'Native host compilation failed.'
}

$manifest = [ordered]@{
    name = $hostName
    description = 'EINK Harness lifecycle native messaging host'
    path = $hostExe
    type = 'stdio'
    allowed_origins = @("chrome-extension://$extensionId/")
}
[IO.File]::WriteAllText(
    $hostManifest,
    ($manifest | ConvertTo-Json -Depth 4),
    (New-Object Text.UTF8Encoding($false))
)

if (-not $SkipRegistry) {
    foreach ($key in @($chromeKey, $edgeKey)) {
        [void](New-Item -Path $key -Force)
        Set-Item -LiteralPath $key -Value $hostManifest
    }
}

Write-Output 'EINK HARNESS QUICK LAUNCH: INSTALLED'
Write-Output "EXTENSION_ID: $extensionId"
Write-Output "EXTENSION_FOLDER: $extensionPath"
Write-Output "NATIVE_HOST: $hostExe"
if ($SkipRegistry) {
    Write-Output 'REGISTRY: SKIPPED (ACCEPTANCE MODE)'
}
else {
    Write-Output 'REGISTERED: CHROME + EDGE (CURRENT USER)'
}
