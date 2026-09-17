#requires -Version 5.1
<#
    Purge-Strays.ps1
    What Audit-Papers.ps1 reports, this one acts on. It is deliberately
    aggressive: where there are two of something it keeps one and bins the rest
    rather than asking. The Recycle Bin is the safety net and it is a good one -
    nothing here is gone until you empty it.

    THE SLOT ORDER decides which copy survives. Lower wins:

        the paper root       the master itself
        2.Source             what the master was made from
        1.Presentation       decks and briefings
        3.BackgroundPapers   the supporting papers
        5.Notes              loose notes
        4.ExternalPapers     other people's work
        8.PreviousVersions   superseded drafts
        9.Archive            everything retired

    WHAT IT DOES, in this order

      1  MACHINERY      .ps1, .bat, .cmd and _ReorganizeLog.txt anywhere under a
                        paper folder go to the Recycle Bin. Scripts live in the
                        scripts folder; one that ran inside a paper has run.

      2  FOREIGN SOURCE 2.Source holds what this paper was made from, nothing
                        else. A file there named after some other document is
                        binned when a copy already exists elsewhere in the paper,
                        and moved to 8.PreviousVersions when it does not.

      3  SAME FILE      identical content (SHA256) in two places inside one paper
                        folder: the copy in the lower slot stays, the others go.
                        A "previous version" that is byte-for-byte the current
                        master is not a previous version.
                        Across two different papers, nothing is touched - a
                        background paper is allowed to sit in both - unless
                        -AcrossPapers is passed.

      4  TWO OF A THING two names for one document in one paper folder, once the
                        slot prefixes, the version suffixes and the difference
                        between _ - and case are taken off. The whole losing set
                        goes together, so a .docx and its .qmd are never split.
                        Best is: lowest slot, then newest, then largest.
                        The master's own lifecycle - the root .qmd and .docx, the
                        copy in 2.Source, dated drafts in 8.PreviousVersions - is
                        never touched here. Rule 3 handles those.

      5  STRAY AT ROOT  a file at the top of a paper folder that is not the
                        master is moved into the slot it belongs in, or binned if
                        that slot already holds the same file.

      6  EMPTY FOLDERS  any folder left with nothing in it goes.

    NOT TOUCHED  media\ and images\, the website folder, the scripts folder, the
                 Overview folder, and any file whose name starts with _ or .

    Preview first. Run\Purge-Strays.bat shows the whole list and asks.

    Switches
        -Apply          do it
        -AcrossPapers   also dedupe identical files held by two different papers
#>

param(
    [switch]$Apply,
    [switch]$AcrossPapers
)

$ErrorActionPreference = 'Stop'

$Slots     = @('1.Presentation','2.Source','3.BackgroundPapers','4.ExternalPapers',
               '5.Notes','6.Reserved','7.Reserved','8.PreviousVersions','9.Archive')
$SkipDirs  = @('media','images','_site','.quarto','_freeze','papers','node_modules',
               'Run','Engine','Steps','Reference','Reports')
$MasterExt = @('.qmd','.docx','.pdf','.bib','.tex')

$Rank = @{
    ''                   = 0
    '2.Source'           = 1
    '1.Presentation'     = 2
    '3.BackgroundPapers' = 3
    '5.Notes'            = 4
    '6.Reserved'         = 5
    '7.Reserved'         = 5
    '4.ExternalPapers'   = 6
    '8.PreviousVersions' = 7
    '9.Archive'          = 8
}

# ------------------------------------------------------------------ setup ----

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

$base = Find-WritingRoot $PSScriptRoot
if (-not $base) { Write-Host 'Could not find "A Writing".'; return }

function Get-ReportDir([string]$here) {
    $up = Split-Path -Parent $here
    if ($up -and (Test-Path -LiteralPath (Join-Path $up 'Engine'))) { $d = Join-Path $up 'Reports' }
    else { $d = Join-Path $here 'Reports' }
    if (-not (Test-Path -LiteralPath $d)) { New-Item -ItemType Directory -Path $d -Force | Out-Null }
    return $d
}
$reportDir = Get-ReportDir $PSScriptRoot

$log  = New-Object System.Collections.Generic.List[string]
$rows = New-Object System.Collections.Generic.List[object]
function Log($m) { $log.Add([string]$m) | Out-Null; Write-Host $m }

$onWindows = if (Test-Path Variable:\IsWindows) { $IsWindows } else { $true }
if ($onWindows) { Add-Type -AssemblyName Microsoft.VisualBasic -ErrorAction SilentlyContinue }
$canRecycle = $onWindows -and ($null -ne ('Microsoft.VisualBasic.FileIO.FileSystem' -as [type]))
$fallback   = Join-Path $base '_Purged'

$gone   = New-Object 'System.Collections.Generic.HashSet[string]'
$binned = 0; $moved = 0; $failed = 0

function Rel([string]$full) { return $full.Substring($base.Length).TrimStart('\','/') }

function Bin-It([string]$path, [string]$why, [string]$paper) {
    $r = Rel $path
    Log ('   BIN  : {0}' -f $r)
    Log ('          {0}' -f $why)
    $rows.Add([pscustomobject]@{ Action='bin'; Paper=$paper; Why=$why; Path=$r; To='' }) | Out-Null
    $script:gone.Add($path) | Out-Null
    if (-not $Apply) { $script:binned++; return }
    try {
        if ($canRecycle) {
            [Microsoft.VisualBasic.FileIO.FileSystem]::DeleteFile(
                $path,
                [Microsoft.VisualBasic.FileIO.UIOption]::OnlyErrorDialogs,
                [Microsoft.VisualBasic.FileIO.RecycleOption]::SendToRecycleBin)
        } else {
            if (-not (Test-Path -LiteralPath $fallback)) { New-Item -ItemType Directory -Path $fallback -Force | Out-Null }
            $dest = Join-Path $fallback ((Split-Path -Leaf $path) + '-' + [guid]::NewGuid().ToString('N').Substring(0,6))
            Move-Item -LiteralPath $path -Destination $dest
        }
        $script:binned++
    } catch {
        Log ('   FAILED: {0}   ({1})' -f $r, $_.Exception.Message)
        $script:failed++
    }
}

function Move-It([string]$path, [string]$destDir, [string]$why, [string]$paper) {
    $leaf = Split-Path -Leaf $path
    $dest = Join-Path $destDir $leaf
    if (Test-Path -LiteralPath $dest) {
        Bin-It $path ($why + ' - and ' + (Split-Path -Leaf $destDir) + '\ already holds it') $paper
        return
    }
    Log ('   MOVE : {0}' -f (Rel $path))
    Log ('     ->   {0}\   [{1}]' -f (Split-Path -Leaf $destDir), $why)
    $rows.Add([pscustomobject]@{ Action='move'; Paper=$paper; Why=$why; Path=(Rel $path); To=(Rel $dest) }) | Out-Null
    $script:gone.Add($path) | Out-Null
    if (-not $Apply) { $script:moved++; return }
    try {
        if (-not (Test-Path -LiteralPath $destDir)) { New-Item -ItemType Directory -Path $destDir -Force | Out-Null }
        Move-Item -LiteralPath $path -Destination $dest
        $script:moved++
    } catch {
        Log ('   FAILED: {0}   ({1})' -f (Rel $path), $_.Exception.Message)
        $script:failed++
    }
}

# ------------------------------------------------------------ paper folders --

function Core-Name([string]$n) {
    $t = $n -replace '^\s*\d+(\.\d+)*[A-Za-z]?[.\s_-]+', ''
    $w = $t -split '[^A-Za-z0-9]+' | Where-Object { $_ -ne '' }
    $o = ''
    foreach ($x in $w) {
        if ($x -cmatch '^[A-Z0-9]+$' -or $x -cmatch '^[A-Z]{2,}' -or $x -cmatch '[A-Z].*[A-Z]') { $o += $x }
        else { $o += $x.Substring(0,1).ToUpper() + $x.Substring(1).ToLower() }
    }
    return $o
}

# The slot prefix a filename carries, or '' - Background-X and X are the same
# document under two names, but Notes-X and Pres-X are a note and a deck.
function Prefix-Of([string]$name) {
    $s = [System.IO.Path]::GetFileNameWithoutExtension($name)
    if ($s -match '^(Background|Notes|Pres|Briefing|Presentation|WP\d*)[-_. ]+') { return $Matches[1] }
    return ''
}

function Reduce-Stem([string]$name) {
    $s = [System.IO.Path]::GetFileNameWithoutExtension($name)
    $s = $s -replace '^(Background|Notes|Pres|Briefing|Presentation|WP\d*)[-_. ]+', ''
    $s = $s -replace '[-_. ](previous|new|merged|old|final|clean|draft|copy)$', ''
    $s = $s -replace '[-_. ]\d{4}-\d{2}-\d{2}([-_. ].*)?$', ''
    $s = $s -replace '[-_. ]?v?\d+([._]\d+)*$', ''
    $s = $s -replace '[^A-Za-z0-9]', ''
    return $s.ToLower()
}

function Find-PaperFolders([string]$root) {
    $found = New-Object System.Collections.Generic.List[object]
    $stack = New-Object System.Collections.Stack
    foreach ($d in (Get-ChildItem -LiteralPath $root -Directory -EA SilentlyContinue)) {
        if ($d.Name -match '[.\s_-]*Scripts$' -or $d.Name -match 'Website$') { continue }
        if ($d.Name -match '^\d+[A-Za-z]?[.\s_-]+Overview$') { continue }
        if ($d.Name -match '^[_.]') { continue }
        $stack.Push($d)
    }
    while ($stack.Count -gt 0) {
        $d = $stack.Pop()
        if ($SkipDirs -contains $d.Name -or $Slots -contains $d.Name) { continue }
        $core = Core-Name $d.Name
        $isPaper = $false
        foreach ($e in $MasterExt) {
            if (Test-Path -LiteralPath (Join-Path $d.FullName ($core + $e))) { $isPaper = $true; break }
        }
        if (-not $isPaper) {
            $hasSlot = @(Get-ChildItem -LiteralPath $d.FullName -Directory -EA SilentlyContinue |
                         Where-Object { $Slots -contains $_.Name }).Count -gt 0
            $hasPapers = @(Get-ChildItem -LiteralPath $d.FullName -Directory -EA SilentlyContinue |
                           Where-Object { $_.Name -match '^\d+\.\d+[.\s_-]' }).Count -gt 0
            if ($hasSlot -and -not $hasPapers) { $isPaper = $true }
        }
        if ($isPaper) {
            $found.Add($d) | Out-Null
        } else {
            foreach ($s in (Get-ChildItem -LiteralPath $d.FullName -Directory -EA SilentlyContinue)) {
                if ($SkipDirs -notcontains $s.Name -and $s.Name -notmatch '^[_.]') { $stack.Push($s) }
            }
        }
    }
    return $found
}

$papers = @(Find-PaperFolders $base | Sort-Object FullName)

$mode = if ($Apply) { 'APPLY' } else { 'PREVIEW' }
Log ('=== Purge strays  [{0}]   {1} ===' -f $mode, (Get-Date -Format 'yyyy-MM-dd HH:mm'))
Log ('Base : {0}' -f $base)
Log ('{0} paper folder(s).  Across-paper duplicates: {1}' -f $papers.Count, $(if ($AcrossPapers) { 'also purged' } else { 'left alone' }))
if (-not $canRecycle) { Log 'Recycle Bin unavailable - items move to _Purged\ instead.' }
Log ''

# Slot of a file relative to its paper folder; '' means the paper root.
function Slot-Of([System.IO.FileInfo]$f, [string]$paperFull) {
    $rel = $f.FullName.Substring($paperFull.Length).TrimStart('\','/')
    $parts = $rel -split '[\\/]'
    if ($parts.Count -lt 2) { return '' }
    return $parts[0]
}
function Rank-Of([string]$slot) { if ($Rank.ContainsKey($slot)) { return $Rank[$slot] } else { return 9 } }

function Live-Files([string]$paperFull) {
    return @(Get-ChildItem -LiteralPath $paperFull -File -Recurse -Force -EA SilentlyContinue |
             Where-Object {
                 -not $gone.Contains($_.FullName) -and
                 $_.FullName -notmatch '[\\/](media|images)[\\/]' -and
                 $_.Name -notmatch '^[_.]' })
}

# ------------------------------------------------------------ 1  machinery ---

Log '--- 1  scripts and logs inside the papers'
$n1 = 0
foreach ($p in $papers) {
    foreach ($f in (Get-ChildItem -LiteralPath $p.FullName -File -Recurse -Force -EA SilentlyContinue)) {
        if ($gone.Contains($f.FullName)) { continue }
        if ($f.Extension.ToLower() -in @('.ps1','.bat','.cmd') -or $f.Name -eq '_ReorganizeLog.txt') {
            Bin-It $f.FullName 'a script or log inside a paper folder' (Rel $p.FullName)
            $n1++
        }
    }
}
if ($n1 -eq 0) { Log '   none' }
Log ''

# --------------------------------------------------------- 2  foreign source -

Log '--- 2  files in 2.Source that are not this paper'
$n2 = 0
foreach ($p in $papers) {
    $src = Join-Path $p.FullName '2.Source'
    if (-not (Test-Path -LiteralPath $src)) { continue }
    $paperStem = Reduce-Stem ((Core-Name $p.Name) + '.x')
    foreach ($f in (Get-ChildItem -LiteralPath $src -File -EA SilentlyContinue)) {
        if ($gone.Contains($f.FullName)) { continue }
        if ($f.Name -match '^[_.]') { continue }
        if ((Reduce-Stem $f.Name) -eq $paperStem) { continue }
        # is the same document already held somewhere else in this paper?
        $stem = Reduce-Stem $f.Name
        $elsewhere = @(Live-Files $p.FullName | Where-Object {
                          $_.FullName -ne $f.FullName -and (Reduce-Stem $_.Name) -eq $stem })
        if ($elsewhere.Count -gt 0) {
            Bin-It $f.FullName 'not this paper, and already held elsewhere in the folder' (Rel $p.FullName)
        } else {
            Move-It $f.FullName (Join-Path $p.FullName '8.PreviousVersions') 'not this paper' (Rel $p.FullName)
        }
        $n2++
    }
}
if ($n2 -eq 0) { Log '   none' }
Log ''

# ------------------------------------------------------------ 3  same file ---

Log '--- 3  the same file twice'
$n3 = 0
foreach ($p in $papers) {
    $byHash = @{}
    foreach ($f in (Live-Files $p.FullName)) {
        if ($f.Length -lt 512) { continue }
        try { $h = (Get-FileHash -LiteralPath $f.FullName -Algorithm SHA256).Hash } catch { continue }
        if (-not $byHash.ContainsKey($h)) { $byHash[$h] = New-Object System.Collections.Generic.List[object] }
        $byHash[$h].Add($f) | Out-Null
    }
    foreach ($h in $byHash.Keys) {
        $set = $byHash[$h].ToArray()
        if ($set.Count -lt 2) { continue }
        $sorted = $set | Sort-Object @{ E = { Rank-Of (Slot-Of $_ $p.FullName) } },
                                    @{ E = { $_.LastWriteTime }; Descending = $true },
                                    @{ E = { $_.Name.Length } }
        $keep = $sorted[0]
        Log ('   keep : {0}' -f (Rel $keep.FullName))
        foreach ($f in ($sorted | Select-Object -Skip 1)) {
            Bin-It $f.FullName ('identical to ' + (Rel $keep.FullName)) (Rel $p.FullName)
            $n3++
        }
    }
}
if ($n3 -eq 0) { Log '   none' }
Log ''

if ($AcrossPapers) {
    Log '--- 3b  the same file held by two different papers'
    $byHash = @{}
    foreach ($p in $papers) {
        foreach ($f in (Live-Files $p.FullName)) {
            if ($f.Length -lt 512) { continue }
            try { $h = (Get-FileHash -LiteralPath $f.FullName -Algorithm SHA256).Hash } catch { continue }
            if (-not $byHash.ContainsKey($h)) { $byHash[$h] = New-Object System.Collections.Generic.List[object] }
            $byHash[$h].Add([pscustomobject]@{ P = $p; F = $f }) | Out-Null
        }
    }
    $n3b = 0
    foreach ($h in $byHash.Keys) {
        $set = $byHash[$h].ToArray()
        if ($set.Count -lt 2) { continue }
        $sorted = $set | Sort-Object @{ E = { Rank-Of (Slot-Of $_.F $_.P.FullName) } },
                                    @{ E = { $_.F.FullName } }
        $keep = $sorted[0]
        Log ('   keep : {0}' -f (Rel $keep.F.FullName))
        foreach ($e in ($sorted | Select-Object -Skip 1)) {
            Bin-It $e.F.FullName ('identical to ' + (Rel $keep.F.FullName)) (Rel $e.P.FullName)
            $n3b++
        }
    }
    if ($n3b -eq 0) { Log '   none' }
    Log ''
}

# -------------------------------------------------------- 4  two of a thing --

Log '--- 4  two names for one document'
$n4 = 0
foreach ($p in $papers) {
    $paperStem = Reduce-Stem ((Core-Name $p.Name) + '.x')
    $files = @(Live-Files $p.FullName | Where-Object { $_.FullName -notmatch '[\\/](9\.Archive|4\.ExternalPapers)[\\/]' })

    # One document often grew a longer name: StandardizedTwoStage beside
    # StandardizedTwoStageClimateProjectFinance. Inside one paper folder, a
    # reduced name that is the start of another is the same document, provided
    # the shorter one is long enough not to be a coincidence.
    $canon = @{}
    foreach ($f in $files) {
        $k = Reduce-Stem $f.Name
        if (-not $canon.ContainsKey($k)) { $canon[$k] = $k }
    }
    foreach ($a in @($canon.Keys)) {
        foreach ($b in @($canon.Keys)) {
            if ($a -eq $b) { continue }
            if ($a.Length -lt 12 -or $b.Length -lt 12) { continue }
            if ($b.StartsWith($a) -and $canon[$b] -ne $a) { $canon[$b] = $canon[$a] }
        }
    }
    function Key-Of([System.IO.FileInfo]$f) {
        $k = Reduce-Stem $f.Name
        while ($canon.ContainsKey($k) -and $canon[$k] -ne $k) { $k = $canon[$k] }
        return $k
    }

    foreach ($g in ($files | Group-Object { Key-Of $_ })) {
        if ($g.Count -lt 2) { continue }
        if ($g.Name -eq $paperStem) { continue }          # the master's own lifecycle
        if ($g.Name.Length -lt 8) { continue }            # too short to be more than a coincidence
        # Two different slot prefixes means two different artefacts about one
        # subject - a note and a deck - and both are wanted.
        $pfx = @($g.Group | ForEach-Object { Prefix-Of $_.Name } | Where-Object { $_ -ne '' } | Select-Object -Unique)
        if ($pfx.Count -gt 1) { continue }
        # one variant = one actual filename stem, whatever its extensions
        $variants = $g.Group | Group-Object { [System.IO.Path]::GetFileNameWithoutExtension($_.Name) }
        if ($variants.Count -lt 2) { continue }           # just a .docx and its .qmd
        $scored = $variants | ForEach-Object {
            [pscustomobject]@{
                Stem  = $_.Name
                Files = $_.Group
                Rank  = ($_.Group | ForEach-Object { Rank-Of (Slot-Of $_ $p.FullName) } | Measure-Object -Minimum).Minimum
                When  = ($_.Group | ForEach-Object { $_.LastWriteTime } | Measure-Object -Maximum).Maximum
                Size  = ($_.Group | Measure-Object -Property Length -Sum).Sum
            }
        }
        $best = $scored | Sort-Object Rank, @{ E = 'When'; Descending = $true }, @{ E = 'Size'; Descending = $true } |
                Select-Object -First 1
        Log ('   keep : {0}   ({1} file(s) under "{2}")' -f $best.Stem, $best.Files.Count, $g.Name)
        foreach ($v in ($scored | Where-Object { $_.Stem -ne $best.Stem })) {
            foreach ($f in $v.Files) {
                Bin-It $f.FullName ('the same document as ' + $best.Stem) (Rel $p.FullName)
                $n4++
            }
        }
    }
}
if ($n4 -eq 0) { Log '   none' }
Log ''

# ------------------------------------------------------ 5  stray at the root --

Log '--- 5  loose files at a paper root'
function Suggest-Slot([System.IO.FileInfo]$f) {
    $n = $f.Name
    if ($n -match '^(Pres|Briefing)[-_. ]' -or $f.Extension.ToLower() -eq '.pptx') { return '1.Presentation' }
    if ($n -match '^Background[-_. ]')                                             { return '3.BackgroundPapers' }
    if ($n -match '^Notes[-_. ]' -or $f.Extension.ToLower() -eq '.txt')            { return '5.Notes' }
    return '2.Source'
}
$n5 = 0
foreach ($p in $papers) {
    $core = Core-Name $p.Name
    foreach ($f in (Get-ChildItem -LiteralPath $p.FullName -File -EA SilentlyContinue)) {
        if ($gone.Contains($f.FullName)) { continue }
        if ($f.Name -match '^[_.]') { continue }
        if ([System.IO.Path]::GetFileNameWithoutExtension($f.Name) -eq $core) { continue }
        if ($f.Name -match '^README\.md$') { continue }
        if ($f.Name -match '^\d+\.0[.\s_-]') { continue }
        Move-It $f.FullName (Join-Path $p.FullName (Suggest-Slot $f)) 'not the master' (Rel $p.FullName)
        $n5++
    }
}
if ($n5 -eq 0) { Log '   none' }
Log ''

# ------------------------------------------------------------- 6  empties -----

Log '--- 6  folders left empty'
$n6 = 0
if ($Apply) {
    for ($pass = 0; $pass -lt 4; $pass++) {
        $any = $false
        foreach ($p in $papers) {
            $dirs = @(Get-ChildItem -LiteralPath $p.FullName -Directory -Recurse -Force -EA SilentlyContinue |
                      Sort-Object { $_.FullName.Length } -Descending)
            foreach ($d in $dirs) {
                if (-not (Test-Path -LiteralPath $d.FullName)) { continue }
                $kids = @(Get-ChildItem -LiteralPath $d.FullName -Force -EA SilentlyContinue)
                if ($kids.Count -ne 0) { continue }
                Log ('   BIN  : {0}\' -f (Rel $d.FullName))
                $rows.Add([pscustomobject]@{ Action='bin'; Paper=(Rel $p.FullName); Why='empty folder'; Path=(Rel $d.FullName); To='' }) | Out-Null
                try {
                    if ($canRecycle) {
                        [Microsoft.VisualBasic.FileIO.FileSystem]::DeleteDirectory(
                            $d.FullName,
                            [Microsoft.VisualBasic.FileIO.UIOption]::OnlyErrorDialogs,
                            [Microsoft.VisualBasic.FileIO.RecycleOption]::SendToRecycleBin)
                    } else {
                        Remove-Item -LiteralPath $d.FullName -Force -Recurse
                    }
                    $n6++; $any = $true
                } catch {
                    Log ('   FAILED: {0}   ({1})' -f (Rel $d.FullName), $_.Exception.Message)
                    $failed++
                }
            }
        }
        if (-not $any) { break }
    }
} else {
    Log '   listed on the real run - what is empty depends on what goes above'
}
if ($n6 -eq 0 -and $Apply) { Log '   none' }
Log ''

# ---------------------------------------------------------------- finish ------

Log '================================================================'
Log ('Binned {0}, moved {1}, empty folders removed {2}, failed {3}.' -f $binned, $moved, $n6, $failed)
if ($failed -gt 0) { Log 'A failure is usually a file open in Word. Close it and run again.' }
if ($Apply) {
    Log ''
    if ($canRecycle) { Log 'Everything binned is in the Recycle Bin until you empty it.' }
    else { Log ('Everything binned is in {0}.' -f $fallback) }
    Log 'Run Run\Master-Website.bat next to republish.'
} else {
    Log ''
    Log 'PREVIEW only - nothing was changed.'
}

$sfx = if ($Apply) { '' } else { '-preview' }
$txt = Join-Path $reportDir ("_PurgeReport$sfx.txt")
$csv = Join-Path $reportDir ("_PurgeReport$sfx.csv")
$log | Set-Content -LiteralPath $txt -Encoding UTF8
$rows | Export-Csv -LiteralPath $csv -NoTypeInformation -Encoding UTF8
Write-Host ''
Write-Host ('Report : {0}' -f $txt)
Write-Host ('         {0}' -f $csv)
