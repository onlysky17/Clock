[CmdletBinding()]
param(
    [ValidateSet('Validate', 'Transition', 'ManualFallback')]
    [string]$Action = 'Validate',
    [string]$State,
    [string]$From,
    [string]$To,
    [string]$TaskId,
    [int]$Sequence,
    [string]$Purpose,
    [string]$Command
)

$ErrorActionPreference = 'Stop'
$states = @(
    'NEW', 'WORKSPACE_VERIFIED', 'CONTEXT_VERIFIED', 'SCOPE_LOCKED', 'EXECUTING', 'SOURCE_VERIFIED',
    'OWNER_BUILD_REQUIRED', 'BUILD_VERIFIED', 'ARTIFACT_VERIFIED', 'OWNER_FLASH_REQUIRED', 'FLASH_VERIFIED',
    'OWNER_COLD_BOOT_REQUIRED', 'COLD_BOOT_VERIFIED', 'OWNER_BLE_REQUIRED', 'BLE_VERIFIED',
    'OWNER_VISUAL_REQUIRED', 'OWNER_DEVICE_PASS', 'GIT_CLOSEOUT_READY', 'PUSHED', 'OWNER_MERGE_REQUIRED',
    'CLOSED', 'PAUSED_QUOTA', 'PAUSED_OWNER_ACTION', 'BLOCKED_WRONG_WORKSPACE', 'BLOCKED_GIT_DRIFT',
    'BLOCKED_DIRTY_TREE', 'BLOCKED_SCOPE_EXPANSION', 'BLOCKED_VALIDATION', 'BLOCKED_ARTIFACT_SIZE',
    'BLOCKED_BUILD', 'BLOCKED_DEVICE', 'BLOCKED_OWNER_REJECTED'
)
$ordered = @('NEW', 'WORKSPACE_VERIFIED', 'CONTEXT_VERIFIED', 'SCOPE_LOCKED', 'EXECUTING', 'SOURCE_VERIFIED',
    'OWNER_BUILD_REQUIRED', 'BUILD_VERIFIED', 'ARTIFACT_VERIFIED', 'OWNER_FLASH_REQUIRED', 'FLASH_VERIFIED',
    'OWNER_COLD_BOOT_REQUIRED', 'COLD_BOOT_VERIFIED', 'OWNER_BLE_REQUIRED', 'BLE_VERIFIED',
    'OWNER_VISUAL_REQUIRED', 'OWNER_DEVICE_PASS', 'GIT_CLOSEOUT_READY', 'PUSHED', 'OWNER_MERGE_REQUIRED', 'CLOSED')

function Write-Result {
    param([System.Collections.IDictionary]$Payload, [bool]$Success)
    $Payload | ConvertTo-Json -Depth 4
    if ($Success) { exit 0 }
    exit 1
}

if ($Action -eq 'ManualFallback') {
    $valid = -not [string]::IsNullOrWhiteSpace($TaskId) -and $Sequence -gt 0 -and -not [string]::IsNullOrWhiteSpace($Purpose) -and -not [string]::IsNullOrWhiteSpace($Command)
    Write-Result ([ordered]@{
        result = if ($valid) { 'PASS' } else { 'FAIL' }
        mode = 'MANUAL_POWERSHELL'
        taskId = $TaskId
        sequence = $Sequence
        purpose = $Purpose
        command = $Command
        expectedEvidence = @('path', 'size_bytes', 'exit_code')
        errors = if ($valid) { @() } else { @('MANUAL_FALLBACK_FIELDS_REQUIRED') }
    }) $valid
}

if ($Action -eq 'Validate') {
    $valid = $states -contains $State
    Write-Result ([ordered]@{
        result = if ($valid) { 'PASS' } else { 'FAIL' }
        state = $State
        valid = $valid
        errors = if ($valid) { @() } else { @('INVALID_STATE') }
    }) $valid
}

$validFrom = $states -contains $From
$validTo = $states -contains $To
$allowed = $false
if ($validFrom -and $validTo) {
    if ($To -like 'PAUSED_*' -or $To -like 'BLOCKED_*') {
        $allowed = $From -ne 'CLOSED'
    } else {
        $fromIndex = [array]::IndexOf($ordered, $From)
        $toIndex = [array]::IndexOf($ordered, $To)
        $allowed = $fromIndex -ge 0 -and $toIndex -eq ($fromIndex + 1)
    }
}
Write-Result ([ordered]@{
    result = if ($allowed) { 'PASS' } else { 'FAIL' }
    from = $From
    to = $To
    allowed = $allowed
    errors = if ($allowed) { @() } else { @('INVALID_TRANSITION') }
}) $allowed
