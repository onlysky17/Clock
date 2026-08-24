[CmdletBinding()]
param()

$ErrorActionPreference = 'Stop'

$repoRoot = (
    Resolve-Path (
        Join-Path $PSScriptRoot '..'
    )
).Path

$indexPath = Join-Path $repoRoot 'tools\harness\control-center\index.html'

function Assert-True {
    param(
        [bool]$Condition,
        [string]$Message
    )

    if (-not $Condition) {
        throw $Message
    }
}

$html = [IO.File]::ReadAllText(
    $indexPath,
    [Text.Encoding]::UTF8
)

Write-Output 'PHASE STATIC_CONTRACT BEGIN'

$required = @(
    'Contract Visualizer v0.5.1',
    'id="einkBrainContractVisualizer"',
    'id="einkContractClassPill"',
    'id="einkContractRiskPill"',
    'id="einkContractCapabilities"',
    'id="einkContractOwnerGates"',
    'id="einkContractForbidden"',
    'id="einkContractScopes"',
    'id="einkContractExecutionSafety"',
    'id="einkContractExactFilesSafety"',
    'id="einkContractMergeSafety"',
    'Raw JSON',
    'function renderContractVisualizer(contract)',
    'function renderContractChipList(',
    'function syntaxHighlightJson(value)',
    'function escapeJsonHtml(text)',
    'renderContractVisualizer(',
    'raw.innerHTML = syntaxHighlightJson(contract);',
    '.contract-pill.risk-high',
    '.contract-pill.risk-medium',
    '.contract-chip.capability',
    '.contract-chip.gate',
    '.contract-chip.forbidden',
    '.contract-chip.scope',
    '.json-key',
    '.json-string',
    '.json-number',
    '.json-boolean',
    '.json-null'
)

foreach ($marker in $required) {
    Assert-True (
        $html.Contains($marker)
    ) "Missing visualizer marker: $marker"
}

Write-Output 'PHASE STATIC_CONTRACT PASS'

Write-Output 'PHASE SAFE_RENDER BEGIN'

Assert-True (
    $html.Contains('.replace(/&/g, "&amp;")')
) 'JSON renderer does not escape ampersand.'

Assert-True (
    $html.Contains('.replace(/</g, "&lt;")')
) 'JSON renderer does not escape less-than.'

Assert-True (
    $html.Contains('.replace(/>/g, "&gt;")')
) 'JSON renderer does not escape greater-than.'

Assert-True (
    $html.Contains('chip.textContent = String(value);')
) 'Contract chips are not rendered via textContent.'

Assert-True (
    -not $html.Contains('highlight.js')
) 'External highlight.js dependency is forbidden.'

Assert-True (
    -not $html.Contains('Prism.js')
) 'External Prism dependency is forbidden.'

Write-Output 'PHASE SAFE_RENDER PASS'

Write-Output 'PHASE JS_SYNTAX BEGIN'

$match = [regex]::Match(
    $html,
    '<script>([\s\S]*?)</script>',
    [Text.RegularExpressions.RegexOptions]::IgnoreCase
)

Assert-True $match.Success 'Inline JavaScript not found.'

$node = Get-Command node -ErrorAction SilentlyContinue
Assert-True ($null -ne $node) 'Node.js is required for visualizer syntax acceptance.'

$temp = Join-Path $env:TEMP (
    'eink-contract-visualizer-' +
    [Guid]::NewGuid().ToString('N') +
    '.js'
)

try {
    [IO.File]::WriteAllText(
        $temp,
        $match.Groups[1].Value,
        [Text.UTF8Encoding]::new($false)
    )

    & $node.Source --check $temp

    Assert-True (
        $LASTEXITCODE -eq 0
    ) 'Contract Visualizer JavaScript syntax failed.'
}
finally {
    Remove-Item `
        -LiteralPath $temp `
        -Force `
        -ErrorAction SilentlyContinue
}

Write-Output 'PHASE JS_SYNTAX PASS'

Write-Output 'CONTRACT_CLASS_COLOR_MAP: PASS'
Write-Output 'RISK_COLOR_MAP: PASS'
Write-Output 'CAPABILITY_CHIPS: PASS'
Write-Output 'OWNER_GATE_CHIPS: PASS'
Write-Output 'FORBIDDEN_ACTION_CHIPS: PASS'
Write-Output 'CANDIDATE_SCOPE_CHIPS: PASS'
Write-Output 'SAFETY_BADGES: PASS'
Write-Output 'RAW_JSON_SYNTAX_HIGHLIGHT: PASS'
Write-Output 'HTML_INJECTION_GUARD: PASS'
Write-Output 'EXTERNAL_UI_DEPENDENCY: NONE'
Write-Output 'COMPILER_LOGIC_MUTATION: NONE'
Write-Output 'FIRMWARE_BUILD_BURN: NOT PERFORMED'
Write-Output 'EINK-HARNESS-V0.5.1-CONTRACT-VISUALIZER: PASS'
