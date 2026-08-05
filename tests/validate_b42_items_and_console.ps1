$projectRoot = Split-Path -Parent $PSScriptRoot
$clothesPath = Join-Path $projectRoot '42.20\media\scripts\ParadiseZ_Clothes.txt'
$consolePath = Join-Path $projectRoot '42.20\media\lua\client\Dev\DBG\ParadiseDev_Console.lua'
$guidTablePath = Join-Path $projectRoot '42.20\media\fileGuidTable.xml'

$clothes = Get-Content -LiteralPath $clothesPath -Raw
$console = Get-Content -LiteralPath $consolePath -Raw

if ($clothes -notmatch '(?s)item\s+TurtBag\s*\{.*?ItemType\s*=\s*base:container,') {
    throw 'TurtBag must use B42 ItemType = base:container.'
}

$firstFunction = $console.IndexOf('function ')
$preFunction = if ($firstFunction -ge 0) { $console.Substring(0, $firstFunction) } else { $console }
if ($preFunction -match 'playUISound\s*\(') {
    throw 'ParadiseDev_Console must not play UI sounds while the Lua file is loading.'
}

if (-not (Test-Path -LiteralPath $guidTablePath)) {
    throw 'Custom clothing needs media/fileGuidTable.xml for B42 ClothingItem asset lookup.'
}

$guidTable = Get-Content -LiteralPath $guidTablePath -Raw
$requiredClothingAssets = @(
    'Tshirt_ParadiseZ', 'Jacket_TheRange', 'Jacket_JimAdmin',
    'HoodieDOWN_ParadiseZ', 'HoodieUP_ParadiseZ',
    'HoodieDOWN_Punisher', 'HoodieUP_Punisher', 'HoodieDOWN_NF', 'HoodieUP_NF',
    'Hat_BalaclavaGhost', 'TurtBag', 'TurtBag_LHand', 'TurtBag_RHand'
)
foreach ($asset in $requiredClothingAssets) {
    $path = "<path>media/clothing/clothingItems/$asset.xml</path>"
    if (-not $guidTable.Contains($path)) {
        throw "Missing B42 clothing GUID mapping for $asset."
    }
}

Write-Output 'B42 item and console static checks passed.'
