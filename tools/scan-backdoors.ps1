<#
    FiveM backdoor scanner (read-only: it deletes nothing, it only reports).

    Usage (PowerShell, in the folder that contains "resources"):
        powershell -ExecutionPolicy Bypass -File .\scan-backdoors.ps1 -Path "C:\FXServer\server-data\resources"

    Options:
        -Path   the resources folder to scan (default: .\resources)
        -Days   also list code files changed in the last N days (default 14)
        -Report where to save the report (default: .\backdoor-report.txt)

    HIGH   = almost certainly malicious, remove / fix now
    MEDIUM = suspicious, open the file and look
    LOW    = for your information (external URLs, recently changed files)
#>
param(
    [string]$Path = ".\resources",
    [int]$Days = 14,
    [string]$Report = ".\backdoor-report.txt"
)

$ErrorActionPreference = 'SilentlyContinue'
if (-not (Test-Path $Path)) { Write-Host "Folder not found: $Path" -ForegroundColor Red; exit 1 }
$root = (Resolve-Path $Path).Path
$findings = New-Object System.Collections.ArrayList

function Add-Finding($level, $file, $line, $reason, $snippet) {
    if ($snippet -and $snippet.Length -gt 140) { $snippet = $snippet.Substring(0, 140) + '...' }
    [void]$findings.Add([pscustomobject]@{ Level = $level; File = $file.Replace($root, '').TrimStart('\', '/'); Line = $line; Reason = $reason; Snippet = $snippet })
}

# Known backdoor hosts / markers (seen in leaked "free" scripts)
$badHosts = @('steaxscripts', '9ns1\.com', 'cipher-panel', 'ciphercheats', 'miausass', 'blum-panel', 'fivem-backdoor')

# Per-line rules: level, regex, reason, which files
$rules = @(
    @('HIGH',   ($badHosts -join '|'), 'Known backdoor host / marker', 'all'),
    @('HIGH',   'Buffer\.from\(\s*[''"]aHR0c', 'Base64-hidden http(s) URL or module (typical loader)', 'js'),
    @('HIGH',   'require\(\s*(Buffer|atob|String\.fromCharCode)', 'require() of a hidden module name', 'js'),
    @('HIGH',   'new\s+Function\s*\([^)]*\)\s*\(\s*global', 'Runs downloaded code with access to the server (new Function(global))', 'js'),
    @('HIGH',   'eval\(\s*[a-zA-Z_$][\w$]*\s*\+\s*[''"] ?[''"]\s*\)', 'eval() of a decoded / downloaded string', 'js'),
    @('HIGH',   'String\.fromCharCode\([^)]*\^', 'XOR-decoded code (obfuscated payload)', 'js'),
    @('HIGH',   'require\(\s*[''"](child_process|net|dgram)[''"]', 'Can run programs / open raw connections on the machine', 'js'),
    @('HIGH',   'os\.execute|io\.popen', 'Runs system commands', 'lua'),
    @('HIGH',   '(\\x[0-9a-fA-F]{2}){20,}', 'Long hex-escaped string (obfuscated Lua)', 'lua'),
    @('HIGH',   '(\\\d{2,3}){30,}', 'Long decimal-escaped string (obfuscated Lua)', 'lua'),
    @('HIGH',   'GetConvar\(\s*[''"](sv_licenseKey|rcon_password|steam_webApiKey|sv_tebexSecret)', 'Reads a server secret (license key / rcon / tebex)', 'all'),
    @('HIGH',   'add_principal|add_ace', 'Gives someone admin / ACE permissions from code', 'all'),
    @('MEDIUM', 'PerformHttpRequest[\s\S]*\bload\s*\(|\bload\s*\(\s*[a-zA-Z_]*[Bb]ody', 'Downloads something and loads it as code', 'lua'),
    @('MEDIUM', '\bloadstring\s*\(|assert\s*\(\s*load\s*\(', 'Runs a string as Lua code', 'lua'),
    @('MEDIUM', '\beval\s*\(', 'eval() in server-side JS', 'js'),
    @('MEDIUM', 'https?\.(get|request)\s*\(', 'Server JS downloads something from the internet', 'js'),
    @('MEDIUM', '_G\s*\[\s*string\.char|string\.char\(\s*\d+\s*,\s*\d+\s*,\s*\d+\s*,\s*\d+', 'Hidden global / function name built from char codes', 'lua'),
    @('MEDIUM', 'GetConvar\(\s*[''"]mysql_connection_string', 'Reads the database password', 'all'),
    @('LOW',    'PerformHttpRequest\s*\(\s*[''"]https?://(?!discord(app)?\.com/api/webhooks)', 'Sends data to an external site (check the URL)', 'lua')
)

$skipDirs = '\\(\.git|node_modules)\\|/(\.git|node_modules)/'
$files = Get-ChildItem -Path $root -Recurse -File -Force | Where-Object { $_.FullName -notmatch $skipDirs }
$code = $files | Where-Object { $_.Extension -in '.lua', '.js' }
Write-Host ("Scanning {0} code files in {1} ..." -f $code.Count, $root) -ForegroundColor Cyan

foreach ($f in $code) {
    $isJs = $f.Extension -eq '.js'
    $inUi = $f.FullName -match '[\\/](html|ui|web|nui|dist[\\/]ui)[\\/]' -and $isJs
    $isMin = $f.Name -match '\.min\.js$'
    $lines = Get-Content -LiteralPath $f.FullName
    if ($null -eq $lines) { continue }
    if ($lines -is [string]) { $lines = @($lines) }
    for ($i = 0; $i -lt $lines.Count; $i++) {
        $l = $lines[$i]
        if (-not $l) { continue }
        foreach ($r in $rules) {
            $scope = $r[3]
            if ($scope -eq 'js' -and -not $isJs) { continue }
            if ($scope -eq 'lua' -and $isJs) { continue }
            # browser-side UI code is sandboxed: only the strong JS signatures matter there
            if ($inUi -and $r[0] -ne 'HIGH') { continue }
            if ($isMin -and $r[0] -eq 'MEDIUM') { continue }
            if ($l -match $r[1]) { Add-Finding $r[0] $f.FullName ($i + 1) $r[2] $l.Trim() }
        }
        if (-not $isMin -and -not $inUi -and $l.Length -gt 4000) {
            Add-Finding 'MEDIUM' $f.FullName ($i + 1) ("Very long line ({0} chars) - obfuscated code?" -f $l.Length) ''
        }
    }
    # a whole file that is one big number array decoded with XOR / charcodes
    $raw = ($lines -join "`n")
    if ($raw -match '(\d{2,3}\s*,\s*){400,}' -and $raw -match 'fromCharCode|string\.char') {
        Add-Finding 'HIGH' $f.FullName 0 'File hides code in a big number array and decodes it' ''
    }
}

# Hidden files (name starts with a dot) - the laundromat / cd_dispatch backdoors used html/.vig.js / .lpt.js
foreach ($f in $files) {
    if ($f.Name.StartsWith('.') -and $f.Extension -in '.js', '.lua', '.ts', '.mjs', '.cjs') {
        Add-Finding 'HIGH' $f.FullName 0 'Hidden script file' ''
    }
}

# fxmanifest checks: hidden files loaded, JS loaded as server/shared script from odd folders
$manifests = $files | Where-Object { $_.Name -in 'fxmanifest.lua', '__resource.lua' }
foreach ($m in $manifests) {
    $lines = Get-Content -LiteralPath $m.FullName
    if ($lines -is [string]) { $lines = @($lines) }
    $section = ''
    for ($i = 0; $i -lt $lines.Count; $i++) {
        $l = $lines[$i]
        if ($l -match '^\s*(server_scripts?|shared_scripts?|client_scripts?|files|ui_page)') { $section = $Matches[1] }
        foreach ($ref in [regex]::Matches($l, '[''"]([^''"]+)[''"]')) {
            $p = $ref.Groups[1].Value
            if ($p -match '(^|/)\.[^/]+\.(js|lua)$') { Add-Finding 'HIGH' $m.FullName ($i + 1) "Manifest loads a hidden file: $p" $l.Trim() }
            elseif ($section -match '^(server|shared)' -and $p -match '\.js$' -and $p -match '(^|/)(html|ui|web|nui|stream|images?)/') {
                Add-Finding 'HIGH' $m.FullName ($i + 1) "Server/shared script loaded from a UI/asset folder: $p" $l.Trim()
            }
            elseif ($section -match '^shared' -and $p -match '\.js$') {
                Add-Finding 'MEDIUM' $m.FullName ($i + 1) "JS file loaded as shared script (runs on the SERVER too): $p" $l.Trim()
            }
        }
    }
}

# Recently changed code (malware often drops / edits files after it gets in)
$since = (Get-Date).AddDays(-$Days)
$recent = $code | Where-Object { $_.LastWriteTime -gt $since } | Sort-Object LastWriteTime -Descending
foreach ($f in ($recent | Select-Object -First 60)) {
    Add-Finding 'LOW' $f.FullName 0 ("Changed {0:yyyy-MM-dd HH:mm}" -f $f.LastWriteTime) ''
}

# ---- output ----
$order = @{ HIGH = 0; MEDIUM = 1; LOW = 2 }
$sorted = $findings | Sort-Object @{ Expression = { $order[$_.Level] } }, File, Line -Unique
$out = New-Object System.Collections.ArrayList
[void]$out.Add("FiveM backdoor scan - $root - $(Get-Date -Format 'yyyy-MM-dd HH:mm')")
[void]$out.Add('')
foreach ($lvl in 'HIGH', 'MEDIUM', 'LOW') {
    $group = @($sorted | Where-Object { $_.Level -eq $lvl })
    $color = @{ HIGH = 'Red'; MEDIUM = 'Yellow'; LOW = 'Gray' }[$lvl]
    Write-Host ''
    Write-Host ("===== {0} ({1}) =====" -f $lvl, $group.Count) -ForegroundColor $color
    [void]$out.Add(("===== {0} ({1}) =====" -f $lvl, $group.Count))
    foreach ($x in $group) {
        $loc = if ($x.Line -gt 0) { "{0}:{1}" -f $x.File, $x.Line } else { $x.File }
        Write-Host ("  {0}" -f $loc) -ForegroundColor $color
        Write-Host ("      {0}" -f $x.Reason)
        [void]$out.Add("  $loc")
        [void]$out.Add("      $($x.Reason)")
        if ($x.Snippet) { Write-Host ("      > {0}" -f $x.Snippet) -ForegroundColor DarkGray; [void]$out.Add("      > $($x.Snippet)") }
    }
}
$out | Set-Content -LiteralPath $Report -Encoding UTF8
Write-Host ''
Write-Host "Report saved to $Report" -ForegroundColor Cyan
$high = @($sorted | Where-Object { $_.Level -eq 'HIGH' }).Count
if ($high -gt 0) { Write-Host "$high HIGH finding(s): stop the server and clean these first." -ForegroundColor Red }
else { Write-Host 'No HIGH findings.' -ForegroundColor Green }
