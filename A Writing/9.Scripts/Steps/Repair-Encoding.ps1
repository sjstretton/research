#requires -Version 5.1
<#
    Repair-Encoding.ps1
    Undoes double-encoded UTF-8 in the converted text files.

    WHAT WENT WRONG
    The conversion pass wrote each new .qmd, then re-read it to add the YAML
    header. PowerShell 5.1's Get-Content reads a UTF-8 file as ANSI unless you
    say otherwise, so every non-ASCII character came back as its individual
    bytes and was written out again as UTF-8. An em dash became "a-euro-" and
    a curly quote became "a-TM". The text is intact underneath; the bytes were
    encoded twice.

        wrong:  countries â€" the very places
        right:  countries — the very places

    The scripts now read with -Encoding UTF8, so it will not happen again.
    This repairs what is already on disk.

    HOW IT WORKS
    Round-trip each file: read as UTF-8, write back through Windows-1252, read
    again as UTF-8. That reverses the damage exactly. A file is only rewritten
    when the round-trip succeeds AND the telltale sequences disappear, so a
    clean file is never touched and a file with genuine Windows-1252 content is
    left alone rather than corrupted.

    SAFETY  Nothing is deleted. Each file is checked before and after; a file
    that does not improve is left exactly as it was. Re-running is a no-op.

    USAGE
        Preview-RepairEncoding.bat
        Run\Master-All.bat
#>

param([switch]$Apply)

$ErrorActionPreference = 'Stop'
$Exts = @('.qmd','.md','.tex','.txt','.bib','.rmd')

function Find-WritingRoot([string]$s) {
    $d = $s
    for ($i=0; $i -lt 4; $i++) {
        $n = @(Get-ChildItem -LiteralPath $d -Directory -EA SilentlyContinue |
               Where-Object { $_.Name -match '^\d+[A-Za-z]?[.\s_-]' }).Count
        if ($n -ge 3) { return $d }
        $p = Split-Path -Parent $d; if (-not $p -or $p -eq $d) { break }; $d = $p
    }
    return $null
}
$base = Find-WritingRoot $PSScriptRoot
if (-not $base) { Write-Host ''; Write-Host 'Could not find "A Writing".'; Read-Host; return }

$utf8  = New-Object System.Text.UTF8Encoding($false)
$cp1252 = [System.Text.Encoding]::GetEncoding(1252)

# the sequences double encoding leaves behind
# NOTE: [char] + [char] adds the code points in PowerShell, so each pair is
# built as a string explicitly.
$telltale = @(
    [string]::Concat([char]0x00E2, [char]0x20AC),   # "a-euro" - the start of most of them
    [string]::Concat([char]0x00C3, [char]0x00A2),
    [string]::Concat([char]0x00C3, [char]0x00A9),
    [string]::Concat([char]0x00C3, [char]0x00B6),
    [string]::Concat([char]0x00C3, [char]0x00BC),
    [string]::Concat([char]0x00C2, [char]0x00A0),
    [string]::Concat([char]0x00C2, [char]0x00B0)
)
function Count-Telltale([string]$t) {
    $n = 0
    foreach ($s in $telltale) {
        $i = 0
        while (($i = $t.IndexOf($s, $i)) -ge 0) { $n++; $i += $s.Length }
    }
    return $n
}

$report = New-Object System.Collections.Generic.List[string]
function Log($m) { $report.Add([string]$m) | Out-Null; Write-Host $m }

Log ("=== Repair encoding   {0} ===" -f (Get-Date -Format 'yyyy-MM-dd HH:mm'))
Log ("Base : {0}" -f $base)
Log ("Mode : {0}" -f $(if ($Apply) { 'APPLY' } else { 'PREVIEW - nothing will be written' }))
Log ''

# The scripts folder is excluded outright. Its own run transcript is open and
# locked while this runs - reading it used to abort the whole step - and nothing
# in there is content that needs repairing anyway. Build output is skipped too.
# The scripts folder's number changes, so match it by name rather than by
# number: 9.Scripts, 11.Scripts, Scripts - all excluded.
$skip = '[\\/](\d*[.\s_-]*Scripts|_site|\.quarto|_freeze|node_modules)[\\/]'
$files = @(Get-ChildItem -LiteralPath $base -File -Recurse -EA SilentlyContinue |
           Where-Object { $Exts -contains $_.Extension.ToLower() -and $_.FullName -notmatch $skip })

$fixed = 0; $clean = 0; $left = 0; $locked = 0; $totalBefore = 0; $totalAfter = 0
foreach ($f in $files) {
    # A file open in Word or held by another process is skipped, not fatal.
    try   { $txt = [System.IO.File]::ReadAllText($f.FullName, $utf8) }
    catch { Log ("    LOCKED: {0}   (open elsewhere - skipped)" -f $f.Name); $locked++; continue }
    $before = Count-Telltale $txt
    if ($before -eq 0) { $clean++; continue }
    $totalBefore += $before

    # Text can be mangled more than once. Round-trip up to three times and keep
    # whichever pass came out cleanest - a single pass can leave the count
    # unchanged and the second still fix it, so stopping at the first
    # non-improvement misses the doubly encoded files.
    $cur    = $txt
    $round  = $null
    $after  = $before
    $passes = 0
    for ($k = 1; $k -le 3; $k++) {
        try { $cur = $utf8.GetString($cp1252.GetBytes($cur)) } catch { break }
        $n = Count-Telltale $cur
        if ($n -lt $after) { $round = $cur; $after = $n; $passes = $k }
        if ($n -eq 0) { break }
    }

    if ($null -eq $round) { Log ("    LEFT  : {0}   ({1} bad sequences, not reversible)" -f $f.Name, $before); $left++; continue }

    $rel = $f.FullName.Substring($base.Length).TrimStart('\','/')
    if ($Apply) {
        try { [System.IO.File]::WriteAllText($f.FullName, $round, $utf8) }
        catch { Log ("    LOCKED: {0}   (could not write - skipped)" -f $rel); $locked++; continue }
    }
    Log ("    fixed : {0}   ({1} bad sequences -> {2}, {3} pass(es))" -f $rel, $before, $after, $passes)
    $totalAfter += $after
    $fixed++
}

Log ''
Log '================================================================'
Log ("Files {0} : {1}" -f $(if ($Apply) { 'repaired' } else { 'to repair' }), $fixed)
Log ("Already clean       : {0}" -f $clean)
Log ("Left alone          : {0}" -f $left)
Log ("Locked, skipped     : {0}" -f $locked)
Log ("Bad sequences {0} : {1} -> {2}" -f $(if ($Apply) { 'removed ' } else { 'found   ' }), $totalBefore, $totalAfter)
Log ''
Log 'The .docx files are unaffected - the damage was only in the converted text.'
Log 'Rebuild them by deleting the .docx and re-running Run\Master-All.bat, or leave'
Log 'them: Word never saw the mangled characters.'
Log '=== Done ==='

# Reports go to <scripts root>\Reports. The scripts root is the folder above
# this one when that folder holds Engine\ - which is what marks it.
function Get-ReportDir([string]$here) {
    $up = Split-Path -Parent $here
    if ($up -and (Test-Path -LiteralPath (Join-Path $up 'Engine'))) { $d = Join-Path $up 'Reports' }
    else { $d = Join-Path $here 'Reports' }
    if (-not (Test-Path -LiteralPath $d)) { New-Item -ItemType Directory -Path $d -Force | Out-Null }
    return $d
}
$outDir = Get-ReportDir $PSScriptRoot
$sfx = if ($Apply) { '' } else { '-preview' }
$report | Set-Content -LiteralPath (Join-Path $outDir "_EncodingReport$sfx.txt") -Encoding UTF8

Write-Host ''
if (-not $Apply) { Write-Host 'PREVIEW only. Run Run\Master-All.bat to apply.'; Write-Host '' }
Write-Host 'Press Enter to close...'
[void](Read-Host)
