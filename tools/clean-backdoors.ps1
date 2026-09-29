<#
    FiveM backdoor CLEANER - removes only CONFIRMED backdoor patterns, with a full backup.

    1) Dry run first (changes nothing, shows what it would do):
        powershell -ExecutionPolicy Bypass -File .\clean-backdoors.ps1 -Path "C:\FXServer\resources"

    2) Then really clean (stop the server first):
        powershell -ExecutionPolicy Bypass -File .\clean-backdoors.ps1 -Path "C:\FXServer\resources" -Apply

    Optional: -BlockHosts  also blocks the known backdoor sites in the Windows hosts file
              (PowerShell must be opened as Administrator).

    What it does with -Apply:
      * Moves whole backdoor files (hidden loaders, XOR / base64 loaders, files calling known
        backdoor hosts) to a quarantine folder next to "resources" (same folder structure).
      * Removes the fxmanifest.lua lines that load those files.
      * Removes one-line injected loaders from normal Lua files
        (e.g. PerformHttpRequest('https://...', function(e, d) load(d)() end)).
      * Every changed file is copied to the quarantine folder BEFORE it is edited.
    Anything it is not sure about is only listed as MANUAL - open those files yourself.
    Undo: copy the files back from the quarantine folder.
#>
param(
    [string]$Path = ".\resources",
    [switch]$Apply,
    [switch]$BlockHosts
)

$ErrorActionPreference = 'Stop'
if (-not (Test-Path $Path)) { Write-Host "Folder not found: $Path" -ForegroundColor Red; exit 1 }
$root = (Resolve-Path $Path).Path.TrimEnd('\', '/')
$stamp = Get-Date -Format 'yyyyMMdd-HHmmss'
$quarantine = Join-Path (Split-Path $root -Parent) ("_quarantine\" + $stamp)
$utf8 = New-Object System.Text.UTF8Encoding($false)   # no BOM (FiveM reads the files as plain UTF-8)

$badHosts = 'steaxscripts|9ns1\.com|cipher-panel|ciphercheats|miausass|blum-panel|fivem-backdoor'
$actions = New-Object System.Collections.ArrayList
$manual = New-Object System.Collections.ArrayList

function Rel($p) { return $p.Substring($root.Length).TrimStart('\', '/') }

function Backup($file) {
    $dest = Join-Path $quarantine (Rel $file)
    New-Item -ItemType Directory -Force -Path (Split-Path $dest -Parent) | Out-Null
    Copy-Item -LiteralPath $file -Destination $dest -Force
}

function Read-Text($file) { return [System.IO.File]::ReadAllText($file) }
function Write-Text($file, $text) { [System.IO.File]::WriteAllText($file, $text, $utf8) }

function Balanced($line) {
    $o = ([regex]::Matches($line, '\(')).Count; $c = ([regex]::Matches($line, '\)')).Count
    return $o -eq $c -and $o -gt 0
}

# -- 1. Find whole backdoor files -------------------------------------------
$skip = '[\\/](\.git|node_modules)[\\/]'
$all = Get-ChildItem -Path $root -Recurse -File -Force -ErrorAction SilentlyContinue | Where-Object { $_.FullName -notmatch $skip }
$code = $all | Where-Object { $_.Extension -in '.js', '.lua', '.mjs', '.cjs' }
Write-Host ("Checking {0} code files..." -f $code.Count) -ForegroundColor Cyan

$badFiles = @{}
foreach ($f in $code) {
    $isJs = $f.Extension -ne '.lua'
    $text = ''
    try { $text = Read-Text $f.FullName } catch { continue }
    $reason = $null
    if ($f.Name.StartsWith('.')) { $reason = 'hidden script file' }
    elseif ($isJs -and $text -match 'fromCharCode\([^)]*\^' -and $text -match '\beval\s*\(') { $reason = 'XOR-encrypted code run with eval' }
    elseif ($isJs -and $text -match "Buffer\.from\(\s*['""]aHR0c" -and $text -match '\beval\s*\(|new\s+Function') { $reason = 'base64-hidden downloader' }
    elseif ($isJs -and $text -match 'new\s+Function\s*\([^)]*\)\s*\(\s*global') { $reason = 'runs downloaded code with server access' }
    elseif ($text -match '(\d{2,3}\s*,\s*){400,}' -and $text -match 'fromCharCode|string\.char' -and $text -match '\beval\s*\(|\bload\s*\(|loadstring') { $reason = 'code hidden in a number array' }
    elseif ($isJs -and $text -match $badHosts -and $text -match "require\(\s*['""]https?['""]" -and $text -match '\beval\s*\(|new\s+Function') {
        # a JS downloader built around a backdoor host = the whole file is the backdoor
        # (Lua files are never removed whole for this: only the injected line goes, see step 3)
        if (($text -split "`n").Count -le 60) { $reason = 'JS downloader for a known backdoor host' }
    }
    if ($reason) { $badFiles[$f.FullName] = $reason }
}

foreach ($k in $badFiles.Keys) { [void]$actions.Add([pscustomobject]@{ Kind = 'QUARANTINE'; File = (Rel $k); Detail = $badFiles[$k] }) }

# -- 2. fxmanifest lines that load those files -----------------------------
$manifestEdits = @{}
foreach ($m in ($all | Where-Object { $_.Name -in 'fxmanifest.lua', '__resource.lua' })) {
    $resDir = $m.DirectoryName
    $text = Read-Text $m.FullName
    $nl = if ($text -match "`r`n") { "`r`n" } else { "`n" }
    $lines = $text -split "`r?`n"
    $keep = New-Object System.Collections.ArrayList
    $changed = $false
    foreach ($l in $lines) {
        $drop = $false
        foreach ($ref in [regex]::Matches($l, "['""]([^'""]+\.(js|lua))['""]")) {
            $target = Join-Path $resDir ($ref.Groups[1].Value -replace '/', '\')
            $target2 = Join-Path $resDir $ref.Groups[1].Value
            $hit = $badFiles.ContainsKey($target) -or $badFiles.ContainsKey($target2)
            if (-not $hit) { continue }
            if ($l -match "^\s*['""][^'""]+['""]\s*,?\s*(--.*)?$" -or $l -match "^\s*(server_script|shared_script|client_script)s?\s*['""][^'""]+['""]\s*$") {
                $drop = $true
            } else {
                [void]$manual.Add([pscustomobject]@{ File = (Rel $m.FullName); Detail = "remove '$($ref.Groups[1].Value)' from this line by hand: $($l.Trim())" })
            }
        }
        if ($drop) { $changed = $true; [void]$actions.Add([pscustomobject]@{ Kind = 'MANIFEST'; File = (Rel $m.FullName); Detail = "remove line: $($l.Trim())" }) }
        else { [void]$keep.Add($l) }
    }
    if ($changed) { $manifestEdits[$m.FullName] = ($keep -join $nl) }
}

# -- 3. One-line loaders injected into normal Lua files --------------------
$injectEdits = @{}
foreach ($f in ($code | Where-Object { $_.Extension -eq '.lua' -and -not $badFiles.ContainsKey($_.FullName) })) {
    $text = Read-Text $f.FullName
    if ($text -notmatch 'PerformHttpRequest' -and $text -notmatch $badHosts) { continue }
    $nl = if ($text -match "`r`n") { "`r`n" } else { "`n" }
    $lines = $text -split "`r?`n"
    $keep = New-Object System.Collections.ArrayList
    $changed = $false
    for ($i = 0; $i -lt $lines.Count; $i++) {
        $l = $lines[$i]
        $isLoader = $l -match 'PerformHttpRequest' -and $l -match '\b(load|loadstring)\s*\(' -and (Balanced $l)
        $isHost = $l -match $badHosts
        if ($isLoader -or ($isHost -and (Balanced $l) -and $l -match 'PerformHttpRequest')) {
            $changed = $true
            [void]$actions.Add([pscustomobject]@{ Kind = 'INJECTED'; File = ("{0}:{1}" -f (Rel $f.FullName), ($i + 1)); Detail = ($l.Trim() -replace '^(.{120}).*', '$1...') })
        } else {
            if ($isHost) { [void]$manual.Add([pscustomobject]@{ File = ("{0}:{1}" -f (Rel $f.FullName), ($i + 1)); Detail = 'backdoor host inside a bigger block of code - remove it by hand' }) }
            [void]$keep.Add($l)
        }
    }
    if ($changed) { $injectEdits[$f.FullName] = ($keep -join $nl) }
}

# -- 4. Things we never touch automatically --------------------------------
foreach ($f in $code | Where-Object { -not $badFiles.ContainsKey($_.FullName) -and $_.Extension -ne '.lua' -and $_.FullName -notmatch '[\\/](html|ui|web|nui)[\\/]' }) {
    $text = Read-Text $f.FullName
    if ($text -match $badHosts) { [void]$manual.Add([pscustomobject]@{ File = (Rel $f.FullName); Detail = 'big JS file mentioning a backdoor host - check it by hand' }) }
}

# -- Output / apply ---------------------------------------------------------
Write-Host ''
Write-Host ("===== AUTOMATIC ({0}) =====" -f $actions.Count) -ForegroundColor Red
foreach ($a in $actions) { Write-Host ("  [{0}] {1}" -f $a.Kind, $a.File) -ForegroundColor Red; Write-Host ("        {0}" -f $a.Detail) }
Write-Host ''
Write-Host ("===== MANUAL - check these yourself ({0}) =====" -f $manual.Count) -ForegroundColor Yellow
foreach ($x in $manual) { Write-Host ("  {0}" -f $x.File) -ForegroundColor Yellow; Write-Host ("        {0}" -f $x.Detail) }

if (-not $Apply) {
    Write-Host ''
    Write-Host 'DRY RUN - nothing was changed. Run again with -Apply to clean (stop the server first).' -ForegroundColor Cyan
} elseif ($actions.Count -gt 0) {
    New-Item -ItemType Directory -Force -Path $quarantine | Out-Null
    foreach ($k in $manifestEdits.Keys) { Backup $k; Write-Text $k $manifestEdits[$k] }
    foreach ($k in $injectEdits.Keys) { Backup $k; Write-Text $k $injectEdits[$k] }
    foreach ($k in $badFiles.Keys) {
        $dest = Join-Path $quarantine (Rel $k)
        New-Item -ItemType Directory -Force -Path (Split-Path $dest -Parent) | Out-Null
        Move-Item -LiteralPath $k -Destination $dest -Force
    }
    ($actions | ForEach-Object { "[{0}] {1}  --  {2}" -f $_.Kind, $_.File, $_.Detail }) | Set-Content -LiteralPath (Join-Path $quarantine 'cleaned.txt') -Encoding UTF8
    Write-Host ''
    Write-Host "Cleaned. Backup + removed files are in: $quarantine" -ForegroundColor Green
} else {
    Write-Host 'Nothing to clean automatically.' -ForegroundColor Green
}

if ($BlockHosts) {
    $hostsFile = "$env:SystemRoot\System32\drivers\etc\hosts"
    $block = @('steaxscripts.com', 'www.steaxscripts.com', 'r.9ns1.com', '9ns1.com', 'cipher-panel.me', 'ciphercheats.com')
    try {
        $current = Get-Content -LiteralPath $hostsFile -ErrorAction Stop
        $add = $block | Where-Object { $h = $_; -not ($current -match "\s$([regex]::Escape($h))\s*$") } | ForEach-Object { "0.0.0.0 $_" }
        if ($add) { Add-Content -LiteralPath $hostsFile -Value $add; Write-Host "Blocked in hosts file: $($add -join ', ')" -ForegroundColor Green }
        else { Write-Host 'Hosts file already blocks these sites.' -ForegroundColor Green }
    } catch { Write-Host 'Could not edit the hosts file - open PowerShell as Administrator for -BlockHosts.' -ForegroundColor Yellow }
}
