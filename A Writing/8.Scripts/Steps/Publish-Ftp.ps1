#requires -Version 5.1
<#
    Publish-Ftp.ps1
    Uploads the rendered site - the website folder's _site\ - to the web server.

    CREDENTIALS
    It looks for Reference\_ftp.txt first. One setting per line:

        host     = ftp.example.com
        user     = someone
        password = ********
        remote   = /public_html
        protocol = ftp            (ftp, ftps or sftp - ftp if left out)

    That file is never committed: the repository's .gitignore excludes it.

    If _ftp.txt is not there it falls back to the website folder's own
    deploy.bat, which holds the same details inline. That works, but the
    password then lives in a file inside the repository, so moving it into
    _ftp.txt - and changing it on the server, because the old one is in the
    history - is worth ten minutes.

    It uses WinSCP, which deploy.bat already uses. WinSCP's "synchronize remote"
    uploads what changed and deletes what is no longer there, so the server ends
    up matching _site exactly.

    Nothing local is changed. -WhatIf asks WinSCP to list the transfers without
    making them.

    Usage
        called by Engine\End-Day.ps1, or on its own:
        powershell -File Steps\Publish-Ftp.ps1 -Apply
#>

[CmdletBinding()]
param(
    [switch]$Apply,
    [switch]$WhatIf
)

$ErrorActionPreference = 'Continue'

$me      = Split-Path -Parent $MyInvocation.MyCommand.Path      # ...\Steps
$scripts = Split-Path -Parent $me                                # ...\<n>.Scripts
$base    = Split-Path -Parent $scripts                           # ...\A Writing

function Find-WritingRoot([string]$s) {
    $d = $s
    for ($i = 0; $i -lt 4; $i++) {
        $n = @(Get-ChildItem -LiteralPath $d -Directory -EA SilentlyContinue |
               Where-Object { $_.Name -match '^\d+[A-Za-z]?[.\s_-]' }).Count
        if ($n -ge 3) { return $d }
        $p = Split-Path -Parent $d; if (-not $p -or $p -eq $d) { break }; $d = $p
    }
    return $null
}
$found = Find-WritingRoot $me
if ($found) { $base = $found }

$web = Get-ChildItem -LiteralPath $base -Directory -EA SilentlyContinue |
       Where-Object { $_.Name -match '^\d+[A-Za-z]?[.\s_-]+Website$' } | Select-Object -First 1
if (-not $web) { Write-Host '   no Website folder at the root of A Writing'; exit 1 }

$site = Join-Path $web.FullName '_site'
if (-not (Test-Path -LiteralPath $site)) {
    Write-Host ('   {0}\_site does not exist - render the site first.' -f $web.Name)
    exit 1
}
$pages = @(Get-ChildItem -LiteralPath $site -File -Recurse -EA SilentlyContinue)
Write-Host ('   source : {0}   ({1} file(s))' -f $site, $pages.Count)

# --- WinSCP -------------------------------------------------------------------

$winscp = $null
foreach ($c in @('C:\Program Files (x86)\WinSCP\WinSCP.com',
                 'C:\Program Files\WinSCP\WinSCP.com')) {
    if (Test-Path -LiteralPath $c) { $winscp = $c; break }
}
if (-not $winscp) {
    $cmd = Get-Command WinSCP.com -EA SilentlyContinue
    if ($cmd) { $winscp = $cmd.Source }
}
if (-not $winscp) {
    Write-Host '   WinSCP not found. Install it, or put WinSCP.com on PATH.'
    exit 1
}
Write-Host ('   winscp : {0}' -f $winscp)

# --- credentials --------------------------------------------------------------

$cred = Join-Path (Join-Path $scripts 'Reference') '_ftp.txt'
$cfg  = @{}
if (Test-Path -LiteralPath $cred) {
    foreach ($line in (Get-Content -LiteralPath $cred -EA SilentlyContinue)) {
        if ($line -match '^\s*#') { continue }
        if ($line -match '^\s*([A-Za-z]+)\s*=\s*(.+?)\s*$') { $cfg[$Matches[1].ToLower()] = $Matches[2] }
    }
}

$haveCfg = $cfg.ContainsKey('host') -and $cfg.ContainsKey('user') -and $cfg.ContainsKey('password')

if (-not $haveCfg) {
    $deploy = Join-Path $web.FullName 'deploy.bat'
    if (-not (Test-Path -LiteralPath $deploy)) {
        Write-Host ''
        Write-Host ('   No credentials. Write them into {0}' -f $cred)
        Write-Host '   as host / user / password / remote, one per line.'
        exit 1
    }
    Write-Host ''
    Write-Host ('   Reference\_ftp.txt not found - falling back to {0}\deploy.bat' -f $web.Name)
    Write-Host '   (that file holds the password inline and is inside the repository;'
    Write-Host '    moving it to Reference\_ftp.txt is worth doing)'
    if (-not $Apply) { Write-Host '   PREVIEW - deploy.bat not run.'; exit 0 }
    Push-Location -LiteralPath $web.FullName
    try {
        & cmd.exe /c ('"' + $deploy + '"')
        $rc = $LASTEXITCODE
    } finally { Pop-Location }
    if ($rc -eq 0) { Write-Host '   deploy.bat finished.' } else { Write-Host ('   deploy.bat exited {0}' -f $rc) }
    exit $rc
}

$proto  = if ($cfg.ContainsKey('protocol')) { $cfg['protocol'] } else { 'ftp' }
$remote = if ($cfg.ContainsKey('remote'))   { $cfg['remote']   } else { '/public_html' }
Write-Host ('   target : {0}://{1}{2}   as {3}' -f $proto, $cfg['host'], $remote, $cfg['user'])

# WinSCP wants its own URL escaping for anything odd in a password.
function Esc([string]$s) {
    $out = ''
    foreach ($ch in $s.ToCharArray()) {
        if ($ch -match '[A-Za-z0-9._~-]') { $out += $ch }
        else { $out += ('%{0:X2}' -f [int][char]$ch) }
    }
    return $out
}

$open = ('open {0}://{1}:{2}@{3}/' -f $proto, (Esc $cfg['user']), (Esc $cfg['password']), $cfg['host'])
$sync = if ($WhatIf) {
    ('synchronize remote -preview "{0}" "{1}"' -f $site, $remote)
} else {
    ('synchronize remote "{0}" "{1}"' -f $site, $remote)
}

if (-not $Apply) {
    Write-Host ''
    Write-Host '   PREVIEW - nothing uploaded. Run with -Apply.'
    exit 0
}

# The password is passed to WinSCP as an argument and is never written to a log
# or echoed here. /log is deliberately not set for the same reason.
$wsArgs = @(
    '/command',
    ('"' + $open.Replace('"','""') + '"'),
    '"option batch abort"',
    '"option confirm off"',
    ('"' + $sync.Replace('"','""') + '"'),
    '"exit"'
) -join ' '

$p = Start-Process -FilePath $winscp -ArgumentList $wsArgs -NoNewWindow -Wait -PassThru
if ($p.ExitCode -eq 0) {
    Write-Host ''
    Write-Host '   uploaded.'
} else {
    Write-Host ''
    Write-Host ('   WinSCP exited {0} - nothing was uploaded, or only part of it was.' -f $p.ExitCode)
}
exit $p.ExitCode
