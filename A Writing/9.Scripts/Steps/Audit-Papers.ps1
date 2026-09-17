#requires -Version 5.1
<#
    Audit-Papers.ps1
    Reads the tree and reports. It changes nothing, ever - there is no -Apply.

    It answers one question: is there two of something where there should be one?

      A  SAME FILE TWICE      identical content (SHA256) in more than one place.
                              A copy in 2.Source or 8.PreviousVersions that is
                              byte-for-byte the live master is not a source or a
                              previous version. It is a second copy.

      B  TWO OF A THING       two files in one paper folder whose names reduce to
                              the same thing once the slot prefixes (Background-,
                              Notes-, Pres-, Briefing-), the version suffixes
                              (-previous, -new, -merged, -v2, a trailing date)
                              and the difference between _ - and case are taken
                              off. SLE_Excise_Diagnostic.docx beside
                              SLE-ExciseDiagnostic.docx is the case this catches.
                              A .qmd beside its own .docx is the convention and
                              is never reported.

      C  STRAY AT THE ROOT    a file at the top of a paper folder that is not the
                              master. The master is <Core>.qmd, <Core>.docx,
                              <Core>.pdf, <Core>.bib or a README. Everything else
                              belongs in a slot, and the report says which.

      D  MACHINERY IN CONTENT .ps1, .bat, .cmd or a reorganise log anywhere under
                              a paper folder. Scripts live in the scripts folder.

    Nothing here is automatically wrong. An audit finds candidates; you decide.
    Sections 9.Archive and 4.ExternalPapers are read for A and D only - an
    archive is allowed to hold several versions of one thing, that is its job.

    Usage
        Run\Audit-Papers.bat
        Reports\_AuditReport.txt  and  _AuditReport.csv
#>

$ErrorActionPreference = 'Stop'

$Slots      = @('1.Presentation','2.Source','3.BackgroundPapers','4.ExternalPapers',
                '5.Notes','6.Reserved','7.Reserved','8.PreviousVersions','9.Archive')
$SkipDirs   = @('media','images','_site','.quarto','_freeze','papers','node_modules',
                'Run','Engine','Steps','Reference','Reports')
# Read for duplicates, but not judged for "two of a thing" - keeping several
# versions of one document is what these two folders are for.
$LenientIn  = @('9.Archive','4.ExternalPapers')
$MasterExt  = @('.qmd','.docx','.pdf','.bib','.tex')

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
function Row($kind, $paper, $detail, $path) {
    $rows.Add([pscustomobject]@{ Finding=$kind; Paper=$paper; Detail=$detail; Path=$path }) | Out-Null
}

Log ('=== Audit papers   {0} ===' -f (Get-Date -Format 'yyyy-MM-dd HH:mm'))
Log ('Base : {0}' -f $base)
Log 'Report only. Nothing is moved, renamed or removed.'
Log ''

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

function Find-PaperFolders([string]$root) {
    $found = New-Object System.Collections.Generic.List[object]
    $stack = New-Object System.Collections.Stack
    foreach ($d in (Get-ChildItem -LiteralPath $root -Directory -EA SilentlyContinue)) {
        if ($d.Name -match '[.\s_-]*Scripts$' -or $d.Name -match 'Website$') { continue }
        if ($d.Name -match '^\d+[A-Za-z]?[.\s_-]+Overview$') { continue }
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
            # A folder holding slots is a paper folder even with no master yet -
            # unless it also holds numbered papers, which makes it a section that
            # happens to own an archive.
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
                if ($SkipDirs -notcontains $s.Name) { $stack.Push($s) }
            }
        }
    }
    return $found
}

$papers = @(Find-PaperFolders $base | Sort-Object FullName)
Log ('{0} paper folder(s) read.' -f $papers.Count)
Log ''

# ------------------------------------------------------------- the reducer --
# Everything that makes two names for one document look different.

function Reduce-Stem([string]$name) {
    $s = [System.IO.Path]::GetFileNameWithoutExtension($name)
    $s = $s -replace '^(Background|Notes|Pres|Briefing|Presentation|WP\d*)[-_. ]+', ''
    $s = $s -replace '[-_. ](previous|new|merged|old|final|clean|draft|copy)$', ''
    $s = $s -replace '[-_. ]\d{4}-\d{2}-\d{2}([-_. ].*)?$', ''      # -2026-09-17-new
    $s = $s -replace '[-_. ]?v?\d+([._]\d+)*$', ''                   # v0.2, _v1.11, -2
    $s = $s -replace '[^A-Za-z0-9]', ''
    return $s.ToLower()
}

# ---------------------------------------------------------------- A and D ----

Log '--- A  the same file in more than one place'
$byHash = @{}
$machinery = New-Object System.Collections.Generic.List[object]

foreach ($p in $papers) {
    $rel = $p.FullName.Substring($base.Length).TrimStart('\','/')
    foreach ($f in (Get-ChildItem -LiteralPath $p.FullName -File -Recurse -EA SilentlyContinue)) {
        if ($f.Directory.Name -eq 'media' -or $f.Directory.Name -eq 'images') { continue }
        if ($f.Extension.ToLower() -in @('.ps1','.bat','.cmd') -or $f.Name -eq '_ReorganizeLog.txt') {
            $machinery.Add([pscustomobject]@{ Paper=$rel; File=$f }) | Out-Null
        }
        if ($f.Length -lt 512) { continue }      # READMEs and stubs match each other for dull reasons
        try { $h = (Get-FileHash -LiteralPath $f.FullName -Algorithm SHA256).Hash } catch { continue }
        if (-not $byHash.ContainsKey($h)) { $byHash[$h] = New-Object System.Collections.Generic.List[object] }
        $byHash[$h].Add([pscustomobject]@{ Paper=$rel; File=$f }) | Out-Null
    }
}

$dupSets = 0
foreach ($h in $byHash.Keys) {
    # .ToArray() rather than @(...): wrapping a generic List in the array
    # subexpression operator is not reliable across PowerShell builds.
    $set = $byHash[$h].ToArray()
    if ($set.Count -lt 2) { continue }
    $dupSets++
    Log ('   {0}   ({1:N0} KB, {2} copies)' -f $set[0].File.Name, ($set[0].File.Length / 1KB), $set.Count)
    $shown = 0
    foreach ($e in $set) {
        $r = $e.File.FullName.Substring($base.Length).TrimStart('\','/')
        if ($shown -lt 8) { Log ('       {0}' -f $r); $shown++ }
        Row 'same file twice' $e.Paper ('{0} copies of identical content' -f $set.Count) $r
    }
    if ($set.Count -gt 8) { Log ('       ... and {0} more - see the .csv' -f ($set.Count - 8)) }
}
if ($dupSets -eq 0) { Log '   none' }
Log ''

# ------------------------------------------------------------------- B -------

Log '--- B  two of a thing in one paper folder'
$twoOf = 0
foreach ($p in $papers) {
    $rel = $p.FullName.Substring($base.Length).TrimStart('\','/')
    $files = @(Get-ChildItem -LiteralPath $p.FullName -File -Recurse -EA SilentlyContinue |
               Where-Object {
                   $_.Directory.Name -ne 'media' -and $_.Directory.Name -ne 'images' -and
                   ($LenientIn -notcontains $_.Directory.Name) -and
                   ($_.FullName -notmatch '[\\/](9\.Archive|4\.ExternalPapers)[\\/]')
               })
    $paperStem = Reduce-Stem ((Core-Name $p.Name) + '.x')
    $groups = $files | Group-Object { Reduce-Stem $_.Name }
    foreach ($g in $groups) {
        if ($g.Count -lt 2) { continue }
        # The master's own lifecycle - .qmd and .docx at the root, the imported
        # copy in 2.Source, dated copies in 8.PreviousVersions - is the
        # convention, not a duplicate. Where a "previous version" is in fact
        # byte-for-byte the current one, A says so.
        if ($g.Name -eq $paperStem) { continue }
        # a .qmd, its .docx, its .pdf and its .tex are one document in four forms
        $exts = @($g.Group | ForEach-Object { $_.Extension.ToLower() } | Select-Object -Unique)
        if ($g.Count -eq $exts.Count) { continue }
        $twoOf++
        Log ('   {0}' -f $rel)
        Log ('       "{0}" appears as:' -f $g.Name)
        foreach ($f in ($g.Group | Sort-Object FullName)) {
            $r = $f.FullName.Substring($base.Length).TrimStart('\','/')
            Log ('         {0,-9} {1}' -f ('{0:N0}KB' -f ($f.Length / 1KB)), $r)
            Row 'two of a thing' $rel ('reduces to "{0}"' -f $g.Name) $r
        }
    }
}
if ($twoOf -eq 0) { Log '   none' }
Log ''

# ------------------------------------------------------------------- C -------

Log '--- C  files at a paper root that are not the master'
function Suggest-Slot([System.IO.FileInfo]$f) {
    $n = $f.Name
    if ($n -match '^(Pres|Briefing)[-_. ]' -or $f.Extension -eq '.pptx') { return '1.Presentation' }
    if ($n -match '^Background[-_. ]')                                   { return '3.BackgroundPapers' }
    if ($n -match '^Notes[-_. ]' -or $f.Extension -eq '.txt')            { return '5.Notes' }
    if ($f.Extension -in @('.xlsx','.xls','.xlsm','.csv','.zip','.dta')) { return '2.Source' }
    return '2.Source'
}

$stray = 0
foreach ($p in $papers) {
    $rel  = $p.FullName.Substring($base.Length).TrimStart('\','/')
    $core = Core-Name $p.Name
    foreach ($f in (Get-ChildItem -LiteralPath $p.FullName -File -EA SilentlyContinue)) {
        $stem = [System.IO.Path]::GetFileNameWithoutExtension($f.Name)
        if ($stem -eq $core) { continue }
        if ($f.Name -match '^README\.md$') { continue }
        if ($f.Name -match '^\d+\.0[.\s_-]') { continue }   # a section overview belongs at a section root
        $slot = Suggest-Slot $f
        Log ('   {0}\{1}' -f $rel, $f.Name)
        Log ('       -> {0}\' -f $slot)
        Row 'stray at the paper root' $rel ('belongs in ' + $slot) ($rel + '\' + $f.Name)
        $stray++
    }
}
if ($stray -eq 0) { Log '   none' }
Log ''

# ------------------------------------------------------------------- D -------

Log '--- D  scripts and logs inside the papers'
if ($machinery.Count -eq 0) { Log '   none' }
foreach ($m in $machinery) {
    $r = $m.File.FullName.Substring($base.Length).TrimStart('\','/')
    Log ('   {0}' -f $r)
    Row 'machinery in content' $m.Paper 'a script or log inside a paper folder' $r
}
Log ''

# ---------------------------------------------------------------- finish -----

Log '================================================================'
Log ('Same file twice: {0} set(s).  Two of a thing: {1}.  Stray at a root: {2}.  Machinery: {3}.' -f `
     $dupSets, $twoOf, $stray, $machinery.Count)
Log ''
Log 'Nothing was changed. Read the list, decide what should go, and move or'
Log 'delete it in Explorer - or say which ones and a script can be written.'

$txt = Join-Path $reportDir '_AuditReport.txt'
$csv = Join-Path $reportDir '_AuditReport.csv'
$log | Set-Content -LiteralPath $txt -Encoding UTF8
$rows | Export-Csv -LiteralPath $csv -NoTypeInformation -Encoding UTF8
Write-Host ''
Write-Host ('Report : {0}' -f $txt)
Write-Host ('         {0}' -f $csv)
