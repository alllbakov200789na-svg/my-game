param([Parameter(Mandatory=$true)][string]$LuauDirectory)
$ErrorActionPreference = 'Stop'
$gameRoot = Split-Path -Parent $PSScriptRoot
$compilerPath = Join-Path $LuauDirectory 'luau-compile.exe'
$runtimePath = Join-Path $LuauDirectory 'luau.exe'
if (-not (Test-Path -LiteralPath $compilerPath)) { throw 'luau-compile.exe not found' }
if (-not (Test-Path -LiteralPath $runtimePath)) { throw 'luau.exe not found' }
$reportLines = [System.Collections.Generic.List[string]]::new()
Push-Location $gameRoot
try {
    node tools/build.mjs
    if ($LASTEXITCODE -ne 0) { throw 'Build failed' }
    node tools/test-bundle.mjs
    if ($LASTEXITCODE -ne 0) { throw 'Test generation failed' }
    $scriptFiles = Get-ChildItem -LiteralPath 'src' -Recurse -Filter '*.lua'
    foreach ($scriptFile in $scriptFiles) {
        $compileText = & $compilerPath $scriptFile.FullName 2>&1
        if ($LASTEXITCODE -ne 0) { throw "Compilation failed: $($scriptFile.FullName) $compileText" }
    }
    $reportLines.Add("PASS Luau 0.744 syntax compilation: $($scriptFiles.Count) source files")
    foreach ($spec in @('tests/core.spec.lua','tests/boundaries.generated.lua','tests/movement.generated.lua')) {
        $testText = & $runtimePath $spec 2>&1
        if ($LASTEXITCODE -ne 0) { throw "Tests failed: $testText" }
        foreach ($line in $testText) { $reportLines.Add([string]$line) }
    }
    [xml]$placeDocument = Get-Content -LiteralPath 'JujutsuCursedSurvival.rbxlx' -Raw
    $scriptNodes = $placeDocument.SelectNodes('//Item[@class="Script" or @class="LocalScript" or @class="ModuleScript"]')
    if ($scriptNodes.Count -ne $scriptFiles.Count) { throw 'Embedded script count mismatch' }
    foreach ($sourceFile in $scriptFiles) {
        $scriptName = $sourceFile.Name -replace '\.(server|client)\.lua$|\.lua$',''
        $found = @($scriptNodes | Where-Object { $_.SelectSingleNode('Properties/string[@name="Name"]').InnerText -eq $scriptName })
        if ($found.Count -ne 1) { throw "Duplicate or missing script $scriptName" }
        $embedded = $found[0].SelectSingleNode('Properties/ProtectedString[@name="Source"]').InnerText.Replace("`r`n","`n").Trim()
        $disk = (Get-Content -LiteralPath $sourceFile.FullName -Raw).Replace("`r`n","`n").Trim()
        if ($embedded -ne $disk) { throw "Source mismatch: $scriptName" }
    }
    $reportLines.Add('PASS XML is well formed and all embedded script sources match disk')
    foreach ($mapId in @('ShibuyaCity','SorcererAcademy','CursedDistrict')) {
        [xml]$map = Get-Content -LiteralPath "assets/Maps/$mapId.rbxmx" -Raw
        $seals = $map.SelectNodes('//Item[@class="Folder"][Properties/string[@name="Name"]="Objectives"]/Item')
        $spawns = $map.SelectNodes('//Item[@class="Folder"][Properties/string[@name="Name"]="SpawnPoints"]/Item')
        $destroyables = $map.SelectNodes('//Item[@class="Folder"][Properties/string[@name="Name"]="Destructibles"]/Item')
        if ($seals.Count -ne 3 -or $spawns.Count -ne 16 -or $destroyables.Count -lt 6) { throw "Incomplete map $mapId" }
        $reportLines.Add("PASS static map structure $mapId : 3 seals, 16 spawns, $($destroyables.Count) destroyables")
    }
    $handlerCount = (Get-ChildItem src -Recurse -Filter '*.lua' | Select-String -Pattern 'Marketplace.ProcessReceipt\s*=').Count
    if ($handlerCount -ne 1) { throw 'Receipt handler is not unique' }
    $reportLines.Add('PASS exactly one ProcessReceipt assignment')
    $reportLines.Add('NOT RUN Roblox Engine, Studio Output, multi-client integration, live DataStore, live purchases, device emulation, performance')
    $reportLines | Set-Content -LiteralPath 'docs/AUTOMATED-RESULTS.txt' -Encoding utf8
    $reportLines
}
finally { Pop-Location }
