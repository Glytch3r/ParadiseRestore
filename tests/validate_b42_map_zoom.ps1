$ErrorActionPreference = 'Stop'

$root = Split-Path -Parent $PSScriptRoot
$patchPath = Join-Path $root '42.20\media\lua\client\Dev\patch\ParadiseDev_Map.lua'

if (-not (Test-Path -LiteralPath $patchPath)) {
    throw "Missing map zoom patch: $patchPath"
}

$lines = Get-Content -LiteralPath $patchPath
$source = $lines -join "`n"

if ($lines.Count -lt 2 -or $lines[0] -ne 'ParadiseDev = ParadiseDev or {}') {
    throw 'The ParadiseDev table must be declared on line 1.'
}

if ($lines[1] -ne 'ParadiseDev.PlayerMapMaxZoom = ParadiseDev.PlayerMapMaxZoom or 18') {
    throw 'PlayerMapMaxZoom must remain the editable line-2 setting.'
}

$required = @(
    'function ISWorldMap:instantiate()',
    'self.mapAPI:setMaxZoom(tonumber(ParadiseDev.PlayerMapMaxZoom) or 18)',
    'if not isMapAdmin() then'
)

foreach ($text in $required) {
    if (-not $source.Contains($text)) {
        throw "Missing required map zoom behavior: $text"
    }
}

Write-Output 'B42 map zoom patch static checks passed.'
