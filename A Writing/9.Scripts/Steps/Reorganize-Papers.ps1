#requires -Version 5.1
<#
    Reorganize-Papers.ps1        v2
    Applies the standard paper-folder layout across "A Writing".

    LAYOUT (a slot is created only if something goes into it)
        <CoreName>.<ext>        the core paper, alone at root
        <CoreName>.bib          its bibliography
        1.Presentation          briefing papers (BP), slides, abstracts, summaries
        2.Source                other formats, data, spreadsheets, images
        3.BackgroundPapers      other WP / unprefixed papers in the same folder
        4.ExternalPapers        other people's work
        5.Notes                 notes, comments, outlines
        9.Archive               superseded drafts and old spreadsheet versions

        Slot folders are matched ignoring spaces and punctuation, so an older
        "1. Presentation" or "1_Presentation" is reused; new ones use the form above.
        (6, 7, 8 reserved)

    CORE PAPER RULE
        A core paper is prefixed WP, or has no prefix at all.
        BP is a briefing paper and is never core - it goes to 1.Presentation,
        in every format it exists in (docx, pdf, Canva export).
        Ties break: WP beats unprefixed beats everything else; then .qmd,
        .docx, .tex; then highest version, then newest, then largest.
        When a guess is made it is flagged, and the runners-up go to
        3.BackgroundPapers.
        When the candidates look like DIFFERENT papers rather than versions
        of one, nothing at root is touched and the folder is flagged.

    SAFETY
        Nothing is deleted. Nothing is overwritten. No format is converted.
        Re-running is a no-op.

    WHERE THINGS LIVE
        A Writing\
            research.qmd                  left alone
            0.Overview\  1..5 themes\  6.Additional\  7.Website\
            9.Scripts\                    everything to do with organising
                Preview-Rename.bat / Run-Rename.bat / Rename-Folders.ps1
                Preview-Reorganize.bat / Run-Reorganize.bat / Reorganize-Papers.ps1
                Tidy-Scripts.bat / Tidy-Scripts.ps1
                _CoreFiles.txt
                _PaperFolderLayout.md
                _PaperIndex.csv           the index - one row per paper folder
                _to_delete\
                _Scripts\                 reports, superseded copies

        "A Writing" is located by looking for numbered folders, not by name,
        and theme folders are discovered rather than listed, so folders can be
        renamed or renumbered without editing anything here.

    USAGE
        Preview-Reorganize.bat    dry run, writes report and CSV only
        Run-Reorganize.bat        applies it
#>

param(
    [switch]$Apply
)

$ErrorActionPreference = 'Stop'

# --- settings ---------------------------------------------------------------
# Images live in 2.Source per the agreed layout. This rewrites image paths in
# .qmd/.md so renders keep working. Set to $false to leave images\ at root.
$MoveImagesIntoSource = $true

# Theme folders are discovered, not listed, so renaming or renumbering them
# changes nothing here. A numbered folder at the root of A Writing is a theme
# unless its name is one of these - those hold loose files or the machinery.
$ThemeExclude = @('overview','scripts','website','additional','organise','organize','todelete','maintenanceandreference')

# Excluded if the normalised name CONTAINS one of those words, not only if it
# equals one - "6.Additional" is a container of sections, not a
# section, and has to be skipped whole.
function Is-ExcludedTheme([string]$name) {
    $n = Norm-Folder ($name -replace '^\d+(\.\d+)*[A-Za-z]?[.\s_-]+', '')
    foreach ($w in $ThemeExclude) { if ($n -like ('*' + $w + '*')) { return $true } }
    return $false
}

function Norm-Folder([string]$n) { return (($n -replace '[^A-Za-z0-9]','').ToLower()) }

# A copy parked in _superseded or _Scripts must not run - it would treat its own
# folder as "A Writing" and start building a structure inside the bin.
if ($PSScriptRoot -match '[\\/](_superseded|_Scripts)([\\/]|$)') {
    Write-Host ''
    Write-Host 'This is an old copy of the script, kept only for reference.'
    Write-Host 'Run the live one instead - the folder holding the .bat files.'
    Write-Host ''
    Write-Host 'Press Enter to close...'
    [void](Read-Host)
    return
}

# Find "A Writing" by looking for the theme folders rather than by name, so the
# scripts can be moved or their folder renamed without breaking anything.
function Find-WritingRoot([string]$start) {
    $d = $start
    for ($i = 0; $i -lt 4; $i++) {
        $hit = @(Get-ChildItem -LiteralPath $d -Directory -ErrorAction SilentlyContinue |
                 Where-Object { $_.Name -match '^\d+[A-Za-z]?[.\s_-]' })
        if ($hit.Count -ge 3) { return $d }
        $p = Split-Path -Parent $d
        if (-not $p -or $p -eq $d) { break }
        $d = $p
    }
    return $null
}

$base = Find-WritingRoot $PSScriptRoot
if (-not $base) {
    Write-Host ''
    Write-Host 'Could not find the numbered theme folders from here.'
    Write-Host "from: $PSScriptRoot"
    Write-Host 'Put these scripts in "A Writing" or in a folder directly inside it.'
    Write-Host ''
    Write-Host 'Press Enter to close...'
    [void](Read-Host)
    return
}

# A theme holds papers, so it holds folders. A numbered folder at the root with
# no subfolders at all is a paper in its own right - 8.GeoprosperityIntro, say -
# and reorganising its files into slots would be wrong.
function Is-LonePaper([string]$full) {
    $subs = @(Get-ChildItem -LiteralPath $full -Directory -EA SilentlyContinue)
    if ($subs.Count -gt 0) { return $false }
    return @(Get-ChildItem -LiteralPath $full -File -EA SilentlyContinue).Count -gt 0
}

$Themes = @(Get-ChildItem -LiteralPath $base -Directory |
            Where-Object { $_.Name -match '^\d+[A-Za-z]?[.\s_-]' -and
                           -not (Is-ExcludedTheme $_.Name) -and
                           -not (Is-LonePaper $_.FullName) } |
            Sort-Object Name | ForEach-Object { $_.Name })

# Whatever the scripts' own folder is called, that is where housekeeping goes.
# The script now lives in a subfolder of the scripts folder, so step up to it
# rather than treating the subfolder name as a folder at the root of A Writing.
if ($PSScriptRoot -eq $base) {
    $found = @(Get-ChildItem -LiteralPath $base -Directory -EA SilentlyContinue |
               Where-Object { $_.Name -match '[.\s_-]*Scripts$' } | Select-Object -First 1)
    if ($found.Count -gt 0) { $organiseDir = $found[0].FullName }
    else { $organiseDir = Join-Path $base '9.Scripts' }
} else {
    $parent = Split-Path -Parent $PSScriptRoot
    if ($parent -and (Split-Path -Leaf $parent) -match 'Scripts') { $organiseDir = $parent }
    else { $organiseDir = $PSScriptRoot }
}
$OrganiseFolder = Split-Path -Leaf $organiseDir

$SlotPresentation = '1.Presentation'
$SlotSource       = '2.Source'
$SlotBackground   = '3.BackgroundPapers'
$SlotExternal     = '4.ExternalPapers'
$SlotNotes        = '5.Notes'
$SlotArchive      = '9.Archive'
$Slots = @($SlotPresentation,$SlotSource,$SlotBackground,$SlotExternal,$SlotNotes,$SlotArchive)

$CorePriority = @('.qmd','.docx','.tex')
$ImageExt     = @('.png','.jpg','.jpeg','.gif','.svg','.webp','.bmp','.tif','.tiff','.emf')
$DataExt      = @('.xlsx','.xls','.xlsm','.csv','.tsv','.dta','.parquet','.json','.zip')

$scriptsDir = Join-Path $organiseDir 'Reports'

# Housekeeping that belongs in the scripts folder, not at the root of A Writing.
$OrganiseFiles = '^(Reorganize-Papers\.ps1|Preview-Reorganize\.bat|Run-Reorganize\.bat|' +
                 '_CoreFiles\.txt|_PaperFolderLayout\.md|_ReorganizeReport.*\.txt|' +
                 '_ReorganizeLog\.txt|cleanup\.ps1|renumber\.ps1|_deletion-list\.md|' +
                 '_reorganisation-checklist\.md)$'
$OrganiseDirs  = '^(_to_delete|_Scripts|_superseded|_archive)$'
# Left at the root of A Writing on purpose.
$KeepAtRoot    = '^(_PaperIndex\.csv|research\.qmd)$'

$report    = New-Object System.Collections.Generic.List[string]
$rows      = New-Object System.Collections.Generic.List[object]
$flags     = New-Object System.Collections.Generic.List[string]
$review    = New-Object System.Collections.Generic.List[string]
$moveCount = 0

# The index lives wherever it already is - beside the scripts, or at the root
# of A Writing. Default to beside the scripts.
$refDir = Join-Path $organiseDir 'Reference'
if (-not (Test-Path -LiteralPath $refDir)) { $refDir = $organiseDir }
$csvPath = Join-Path $refDir '_PaperIndex.csv'
if (-not (Test-Path -LiteralPath $csvPath)) {
    $atRoot = Join-Path $base '_PaperIndex.csv'
    if (Test-Path -LiteralPath $atRoot) { $csvPath = $atRoot }
}

# Previous index, so the original filename and the original confidence are not
# lost once a core has been renamed.
$prev = @{}
$prevCsv = $csvPath
if (Test-Path -LiteralPath $prevCsv) {
    try {
        foreach ($r in (Import-Csv -LiteralPath $prevCsv)) {
            $prev[("{0}|{1}" -f $r.Theme, $r.PaperFolder)] = $r
        }
    } catch { }
}

function Log($msg) { $report.Add([string]$msg) | Out-Null; Write-Host $msg }
function Blank()   { Log '' }

# Returns the path to a slot inside a paper folder. If the slot already exists
# under an older spelling ("1. Presentation"), that folder is used; otherwise
# the canonical space-free name is used for anything new.
function Slot-Path([string]$pp, [string]$slot) {
    $want = Norm-Folder $slot
    $hit = @(Get-ChildItem -LiteralPath $pp -Directory -ErrorAction SilentlyContinue |
             Where-Object { (Norm-Folder $_.Name) -eq $want })
    if ($hit.Count -gt 0) { return $hit[0].FullName }
    return (Join-Path $pp $slot)
}

function Is-Slot([string]$name) {
    $n = Norm-Folder $name
    foreach ($s in $Slots) { if ((Norm-Folder $s) -eq $n) { return $true } }
    return $false
}

# ---------------------------------------------------------------------------
# Naming helpers
# ---------------------------------------------------------------------------

function Get-CamelName([string]$folderName) {
    # Strip the number prefix whether it is "1.1 Name", "1.1_Name" or "1.1-Name"
    $n = $folderName -replace '^\s*\d+(\.\d+)*[A-Za-z]?[.\s_-]+', ''
    $words = $n -split '[^A-Za-z0-9]+' | Where-Object { $_ -ne '' }
    $out = ''
    foreach ($w in $words) {
        if ($w -cmatch '^[A-Z0-9]+$' -or $w -cmatch '^[A-Z]{2,}' -or $w -cmatch '[A-Z].*[A-Z]') {
            $out += $w
        } else {
            $out += $w.Substring(0,1).ToUpper() + $w.Substring(1).ToLower()
        }
    }
    return $out
}

function Normalize([string]$s) { return (($s -replace '[^A-Za-z0-9]', '').ToLower()) }

$StopWords = @('and','the','for','with','from','under','note','notes','paper','papers',
               'final','clean','copy','draft','version','short','shorter','longer','original')

function Get-Tokens([string]$text) {
    $parts = [regex]::Matches($text, '([A-Z]+(?![a-z])|[A-Z][a-z]+|[a-z]+|[0-9]+)') |
             ForEach-Object { $_.Value.ToLower() }
    return @($parts | Where-Object { $_.Length -ge 4 -and $_ -notin $StopWords })
}

function Shares-Token([string]$a, [string]$b) {
    $ta = Get-Tokens $a
    foreach ($t in (Get-Tokens $b)) { if ($ta -contains $t) { return $true } }
    return $false
}

# Returns BP / WP / OTHER / NONE.  -cmatch: these prefixes are case SENSITIVE.
function Get-Prefix([string]$stem) {
    if ($stem -cmatch '^BP\d*[a-z]?\s*[-_\s]')                                   { return 'BP' }
    if ($stem -cmatch '^WP\d*[a-z]?\s*[-_\s]')                                   { return 'WP' }
    if ($stem -match  '(WorkingPaper|Working[_\s]Paper|FullPaper|Full[_\s]Paper)') { return 'WP' }
    if ($stem -cmatch '^[A-Z]{1,3}\d*[a-z]?[-_\s]')                              { return 'OTHER' }
    return 'NONE'
}

# WP-number, so WP3-Original and WP3-Shorter are recognised as one paper
function Get-PrefixId([string]$stem) {
    if ($stem -cmatch '^((BP|WP)\d*)') { return $Matches[1].ToUpper() }
    return $null
}

# Higher is more likely to be the current version.
function Get-RecencyHint([string]$stem) {
    $s = 0
    if ($stem -match '(?i)(original|\bold\b|backup|superseded|archive|draft)') { $s -= 2 }
    if ($stem -match '(?i)(final|current|revised|latest|updated|\bnew\b)')     { $s += 1 }
    return $s
}

function Get-VersionValue([string]$stem) {
    $m = [regex]::Match($stem, '[vV](\d+)(?:[._](\d+))?')
    if (-not $m.Success) {
        $m2 = [regex]::Match($stem, '(?<![\d.])(\d{1,2})[._](\d{1,2})(?![\d])')
        if ($m2.Success) { return [double]("$($m2.Groups[1].Value).$($m2.Groups[2].Value)") }
        return 0.0
    }
    $maj = [double]$m.Groups[1].Value
    $min = 0.0
    if ($m.Groups[2].Success) { $min = [double]("0." + $m.Groups[2].Value.PadLeft(2,'0')) }
    return $maj + $min
}

$Qualifiers = @('final','clean','copy','backup','original','draft','old','older',
                'peer','review','peerreview','master','shorter','short','longer','new','v')

function Get-Family([string]$stem) {
    $s = $stem -replace '[vV]\d+([._]\d+)*', ' '
    $s = $s -replace '\b(19|20)\d{2}\b', ' '
    $words = $s -split '[^A-Za-z0-9]+' | Where-Object { $_ -ne '' }
    $keep = @()
    foreach ($w in $words) {
        $lw = $w.ToLower()
        if ($Qualifiers -contains $lw) { continue }
        if ($lw -match '^\d+$') { continue }
        $keep += $lw
    }
    return ($keep -join '')
}

# ---------------------------------------------------------------------------
# Moving
# ---------------------------------------------------------------------------

function Move-Safe([string]$from, [string]$to, [string]$why) {
    $rel = $to.Substring($base.Length).TrimStart('\','/')
    if ((Resolve-Path -LiteralPath $from -ErrorAction SilentlyContinue) -and
        ([System.IO.Path]::GetFullPath($from) -eq [System.IO.Path]::GetFullPath($to))) { return $false }
    if (Test-Path -LiteralPath $to) { Log ("    SKIP exists  : {0}" -f $rel); return $false }
    $script:moveCount++
    if ($Apply) {
        $parent = Split-Path -Parent $to
        if (-not (Test-Path -LiteralPath $parent)) { New-Item -ItemType Directory -Path $parent -Force | Out-Null }
        Move-Item -LiteralPath $from -Destination $to
    }
    Log ("    {0}  ->  {1}   [{2}]" -f (Split-Path -Leaf $from), $rel, $why)
    return $true
}

# ---------------------------------------------------------------------------
# Classification
# ---------------------------------------------------------------------------

function Classify-File([System.IO.FileInfo]$f, [string]$coreStem, [string]$coreName) {
    $stem = [System.IO.Path]::GetFileNameWithoutExtension($f.Name)
    $ext  = $f.Extension.ToLower()
    $pfx  = Get-Prefix $stem

    if ($coreStem -and (Normalize $stem) -eq (Normalize $coreStem)) {
        return @($SlotSource, 'other format of the core paper', "$coreName$ext")
    }

    # Briefing papers, in whatever format they exist in.
    if ($pfx -eq 'BP') { return @($SlotPresentation, 'briefing paper (BP)', $null) }
    if ($stem -match '(Brief|Abstract|Summary|Presentation|Slides|Poster|Canva|Deck)') {
        return @($SlotPresentation, 'brief / abstract / summary', $null)
    }
    if ($ext -in @('.pptx','.ppt','.key')) { return @($SlotPresentation, 'slides', $null) }

    if ($ext -in $ImageExt) { return @($SlotSource, 'image', $null) }
    if ($ext -in $DataExt)  { return @($SlotSource, 'data', $null) }

    if ($ext -in @('.txt','.md','.msg','.eml')) { return @($SlotNotes, 'note', $null) }

    if ($ext -eq '.pdf') {
        if ($stem -match '^[A-Z][A-Za-z-]+((\s*&\s*|,\s*)[A-Z][A-Za-z-]+)*[_\s-]+(19|20)\d\d' -or $stem -match '_(19|20)\d\d_') {
            return @($SlotExternal, 'external paper (author-year name)', $null)
        }
        if ($coreName -and (Shares-Token $stem $coreName)) { return @($SlotSource, 'pdf of this paper', $null) }
        return @($SlotExternal, 'pdf unrelated to this paper', $null)
    }

    if ($ext -in @('.tex','.qmd','.rmd')) { return @($SlotSource, 'other source file', $null) }
    if ($ext -in @('.docx','.doc','.odt')) {
        return @($SlotBackground, "other paper in this folder (prefix: $pfx)", $null)
    }
    if ($ext -in @('.r','.py','.do','.jl','.m','.sh')) { return @($SlotSource, 'analysis script', $null) }

    return @($null, 'unclassified - left in place', $null)
}

function Classify-Folder([string]$name) {
    if (Is-Slot $name)                                    { return @($null,'already a slot') }
    if ($name -eq '_Scripts')                             { return @($null,'scripts') }
    if ($name -match '^(images?|figures?|figs?|assets|media|graphics)$') {
        if ($MoveImagesIntoSource) { return @($SlotSource,'images') }
        return @($null,'images kept at root - referenced by relative path')
    }
    if ($name -match '^(Archive|Old|Older|OlderVersions|Old Versions|Earlier|Earlier version|Earlier Versions|Backup|Backup Versions|Superseded|Previous|Tracked Changes)') {
        return @($SlotArchive,'superseded material')
    }
    if ($name -match '^(Related|External|Literature|Refs|References|Other Authors|Country Examples)') {
        return @($SlotExternal,'other people''s papers')
    }
    if ($name -match '^(Notes?|Comments?|Outline)') { return @($SlotNotes,'notes') }
    if ($name -match '^(Data|Figures|Spreadsheets|Workbooks|Code|Scripts)') { return @($SlotSource,'data / code') }
    if ($name -match '^(Background|Related Papers|Core|Formatted|Other|Additional|Supporting)') {
        return @($SlotBackground,'background material')
    }
    return @($null,'unrecognised - left in place')
}

# ---------------------------------------------------------------------------
# Path repointing
# ---------------------------------------------------------------------------

function Repoint-Text([string]$filePath, [hashtable]$replacements, [string]$label) {
    if (-not (Test-Path -LiteralPath $filePath)) { return }
    $txt = Get-Content -LiteralPath $filePath -Raw -Encoding UTF8
    $orig = $txt
    foreach ($k in $replacements.Keys) { $txt = [regex]::Replace($txt, $k, $replacements[$k]) }
    if ($txt -ne $orig) {
        if ($Apply) { [System.IO.File]::WriteAllText($filePath, $txt, (New-Object System.Text.UTF8Encoding($false))) }
        Log ("    path fixed in {0}   [{1}]" -f (Split-Path -Leaf $filePath), $label)
        $review.Add(("    {0}   [{1}]" -f $filePath.Substring($base.Length).TrimStart('\','/'), $label)) | Out-Null
    }
}

# ---------------------------------------------------------------------------
# Per-folder work
# ---------------------------------------------------------------------------

function Process-Subfolders([string]$pp) {
    foreach ($d in (Get-ChildItem -LiteralPath $pp -Directory)) {
        $res = Classify-Folder $d.Name
        $slot = $res[0]; $why = $res[1]
        if (-not $slot) { Log ("    LEFT DIR: {0}\   [{1}]" -f $d.Name, $why); continue }
        $destRoot = Slot-Path $pp $slot
        if ($why -eq 'images') { $destRoot = Join-Path $destRoot $d.Name }   # keep images\ as a folder
        foreach ($child in (Get-ChildItem -LiteralPath $d.FullName -Force)) {
            $target = $destRoot
            $note   = $why
            # Data and images belong in 2.Source wherever they were found,
            # except inside an archive, where the whole folder stays together.
            if (($slot -in @($SlotBackground, $SlotExternal)) -and ($child -is [System.IO.FileInfo])) {
                $ce = $child.Extension.ToLower()
                if (($ce -in $DataExt) -or ($ce -in $ImageExt)) {
                    $target = Slot-Path $pp $SlotSource
                    $note   = 'data / image'
                }
            }
            Move-Safe $child.FullName (Join-Path $target $child.Name) ("from {0}\ - {1}" -f $d.Name, $note) | Out-Null
        }
        if ($Apply -and (Test-Path -LiteralPath $d.FullName) -and -not (Get-ChildItem -LiteralPath $d.FullName -Force)) {
            Remove-Item -LiteralPath $d.FullName -Force
            Log ("    removed empty dir: {0}\" -f $d.Name)
        }
    }
}

function Archive-OldDataVersions([string]$pp) {
    $src = Slot-Path $pp $SlotSource
    $pool = @()
    $pool += @(Get-ChildItem -LiteralPath $pp -File | Where-Object { $_.Extension.ToLower() -in $DataExt })
    if (Test-Path -LiteralPath $src) {
        $pool += @(Get-ChildItem -LiteralPath $src -File | Where-Object { $_.Extension.ToLower() -in $DataExt })
    }
    if ($pool.Count -lt 2) { return }
    $groups = $pool | Group-Object { (Get-Family $_.BaseName) + $_.Extension.ToLower() }
    foreach ($g in $groups) {
        if ($g.Count -lt 2) { continue }
        $sorted = $g.Group | Sort-Object @{E={Get-VersionValue $_.BaseName};D=$true},
                                         @{E={$_.LastWriteTimeUtc};D=$true},
                                         @{E={$_.Length};D=$true}
        $keep = $sorted[0]
        Log ("    data family '{0}': keeping {1}" -f $g.Name, $keep.Name)
        foreach ($old in ($sorted | Select-Object -Skip 1)) {
            Move-Safe $old.FullName (Join-Path (Slot-Path $pp $SlotArchive) $old.Name) 'superseded version of a data file' | Out-Null
        }
    }
}

function Tidy-Debris([string]$pp) {
    foreach ($slot in @('', $SlotNotes, $SlotSource, $SlotBackground)) {
        $sd = if ($slot -eq '') { $pp } else { Slot-Path $pp $slot }
        if (-not (Test-Path -LiteralPath $sd)) { continue }
        foreach ($f in (Get-ChildItem -LiteralPath $sd -File)) {
            if ($f.Name -match '^(Reorganize-.*\.(ps1|bat)|_Reorganize(Log|Report)\.txt|_PaperIndex\.csv)$') {
                Move-Safe $f.FullName (Join-Path (Slot-Path $pp $SlotArchive) $f.Name) 'leftover from an earlier run' | Out-Null
            } elseif ($f.BaseName -match '(EarlyDraft|OldDraft|OldVersion|Superseded)') {
                Move-Safe $f.FullName (Join-Path (Slot-Path $pp $SlotArchive) $f.Name) 'superseded draft' | Out-Null
            }
        }
    }
}

function Setup-OrganiseFolder {
    # Sweeps the root of A Writing into the scripts folder: the scripts, their
    # outputs, and holding folders like _to_delete. Theme folders, the paper
    # index and research.qmd stay put.
    Log ("--- {0}" -f $OrganiseFolder)
    if (-not (Test-Path -LiteralPath $organiseDir)) {
        if ($Apply) { New-Item -ItemType Directory -Path $organiseDir -Force | Out-Null }
        Log ("    CREATE DIR   : {0}\" -f $OrganiseFolder)
    }

    foreach ($f in (Get-ChildItem -LiteralPath $base -File -Force)) {
        if ($f.Name -match $KeepAtRoot) { Log ("    KEPT AT ROOT : {0}" -f $f.Name); continue }
        if ($f.Name -notmatch $OrganiseFiles) { Log ("    LEFT         : {0}" -f $f.Name); continue }
        $dest = Join-Path $organiseDir $f.Name
        if (Test-Path -LiteralPath $dest) {
            # A newer copy is already in place; park the stale one rather than
            # losing either of them.
            $dest = Join-Path (Join-Path $scriptsDir '_superseded') $f.Name
            Move-Safe $f.FullName $dest 'superseded copy from the root' | Out-Null
        } else {
            Move-Safe $f.FullName $dest ('housekeeping belongs in {0}' -f $OrganiseFolder) | Out-Null
        }
    }

    foreach ($d in (Get-ChildItem -LiteralPath $base -Directory -Force)) {
        if ($d.Name -eq $OrganiseFolder) { continue }
        if ($d.Name -notmatch $OrganiseDirs) { continue }
        $dest = Join-Path $organiseDir $d.Name
        if (Test-Path -LiteralPath $dest) {
            foreach ($child in (Get-ChildItem -LiteralPath $d.FullName -Force)) {
                Move-Safe $child.FullName (Join-Path $dest $child.Name) ("merged into {0}\{1}\" -f $OrganiseFolder, $d.Name) | Out-Null
            }
            if ($Apply -and -not (Get-ChildItem -LiteralPath $d.FullName -Force)) {
                Remove-Item -LiteralPath $d.FullName -Force
                Log ("    removed empty dir: {0}\" -f $d.Name)
            }
        } else {
            Move-Safe $d.FullName $dest ('holding folder belongs in {0}' -f $OrganiseFolder) | Out-Null
        }
    }
    Blank
}

function Get-Override([string]$paperPath) {
    $ovPath = Join-Path $organiseDir '_CoreFiles.txt'
    if (-not (Test-Path -LiteralPath $ovPath)) { $ovPath = Join-Path $base '_CoreFiles.txt' }
    if (-not (Test-Path -LiteralPath $ovPath)) { return $null }
    $rel = $paperPath.Substring($base.Length).TrimStart('\','/')
    foreach ($line in (Get-Content -LiteralPath $ovPath)) {
        if ($line -match '^\s*#' -or $line.Trim() -eq '') { continue }
        $parts = $line -split '\|'
        if ($parts.Count -lt 2) { continue }
        if ((Normalize $parts[0].Trim()) -eq (Normalize $rel)) { return $parts[1].Trim() }
    }
    return $null
}

# ---------------------------------------------------------------------------
# Main
# ---------------------------------------------------------------------------

Log ("=== Reorganize Papers v2   {0} ===" -f (Get-Date -Format 'yyyy-MM-dd HH:mm'))
Log ("Base : {0}" -f $base)
Log ("Mode : {0}" -f $(if ($Apply) { 'APPLY - files will be moved' } else { 'PREVIEW - nothing will be changed' }))
Blank

Setup-OrganiseFolder

foreach ($theme in $Themes) {
    $themePath = Join-Path $base $theme
    if (-not (Test-Path -LiteralPath $themePath)) { Log ("THEME MISSING: {0}" -f $theme); continue }
    Log ("################ {0}" -f $theme)

    foreach ($paper in (Get-ChildItem -LiteralPath $themePath -Directory | Sort-Object Name)) {
        $pp = $paper.FullName
        Blank
        Log ("--- {0}" -f $paper.Name)

        $coreName  = Get-CamelName $paper.Name
        $rootFiles = @(Get-ChildItem -LiteralPath $pp -File)

        # ---------------- choose the core paper -------------------------------
        $core = $null; $confidence = 'none'; $flagNote = ''; $runnersUp = @(); $briefingsOnly = $false

        $ov = Get-Override $pp
        if ($ov) {
            $core = $rootFiles | Where-Object { $_.Name -eq $ov } | Select-Object -First 1
            if ($core) { $confidence = 'override' }
        }

        if (-not $core) {
            $cands = @($rootFiles | Where-Object {
                ($CorePriority -contains $_.Extension.ToLower()) -and
                ((Get-Prefix $_.BaseName) -ne 'BP') -and
                ($_.BaseName -notmatch '(?i)(guide|readme|checklist|questions|outline|_notes|\bnotes\b)')
            })

            if ($cands.Count -eq 0) {
                # Nothing qualifies. If the only paper-like files are briefing
                # papers, that is not ambiguity - there simply is no WP here,
                # and the BPs can be filed with confidence.
                $bps = @($rootFiles | Where-Object {
                    ($CorePriority -contains $_.Extension.ToLower()) -and ((Get-Prefix $_.BaseName) -eq 'BP')
                })
                if ($bps.Count -gt 0) {
                    $briefingsOnly = $true
                    $confidence = 'briefings-only'
                    $flagNote = 'only briefing papers here, no WP or unprefixed paper: ' +
                                (($bps | ForEach-Object { $_.Name }) -join ' | ')
                }
            }
            elseif ($cands.Count -eq 1) {
                $core = $cands[0]; $confidence = 'confident'
            }
            elseif ($cands.Count -gt 1) {
                $rankPfx = @{ 'WP' = 0; 'NONE' = 1; 'OTHER' = 2 }
                $best = ($cands | ForEach-Object { $rankPfx[(Get-Prefix $_.BaseName)] } | Measure-Object -Minimum).Minimum
                $cands = @($cands | Where-Object { $rankPfx[(Get-Prefix $_.BaseName)] -eq $best })

                if ($cands.Count -gt 1) {
                    $bestExt = ($cands | ForEach-Object { $CorePriority.IndexOf($_.Extension.ToLower()) } | Measure-Object -Minimum).Minimum
                    $cands = @($cands | Where-Object { $CorePriority.IndexOf($_.Extension.ToLower()) -eq $bestExt })
                }

                if ($cands.Count -eq 1) {
                    $core = $cands[0]; $confidence = 'confident'
                } else {
                    # versions of one paper, or different papers?
                    $related = $false
                    for ($i = 0; $i -lt $cands.Count -and -not $related; $i++) {
                        for ($j = $i + 1; $j -lt $cands.Count; $j++) {
                            $pi = Get-PrefixId $cands[$i].BaseName
                            $pj = Get-PrefixId $cands[$j].BaseName
                            if (($pi -and $pi -eq $pj) -or (Shares-Token $cands[$i].BaseName $cands[$j].BaseName)) { $related = $true; break }
                        }
                    }
                    if ($related) {
                        $sorted = $cands | Sort-Object @{E={Get-VersionValue $_.BaseName};D=$true},
                                                       @{E={Get-RecencyHint $_.BaseName};D=$true},
                                                       @{E={$_.LastWriteTimeUtc};D=$true},
                                                       @{E={$_.Length};D=$true}
                        $core = $sorted[0]; $confidence = 'guessed'
                        $runnersUp = @($sorted | Select-Object -Skip 1)
                        $flagNote = "guessed between: " + (($sorted | ForEach-Object { $_.Name }) -join ' | ')
                    } else {
                        $confidence = 'separate-papers'
                        $flagNote = "look like different papers, not versions: " + (($cands | ForEach-Object { $_.Name }) -join ' | ')
                    }
                }
            }
        }

        # ---------------- no core: tidy subfolders only -----------------------
        if (-not $core) {
            if ($confidence -eq 'none') {
                $flagNote = 'no .qmd / .docx / .tex at folder root'
            }
            if ($briefingsOnly) { Log ("    NO CORE PAPER - filing the briefing papers anyway") }
            else                { Log ("    NO CORE ({0}) - root files left alone" -f $confidence) }
            Log ("    {0}" -f $flagNote)
            $flags.Add(("{0}\{1}  [{2}]" -f $theme, $paper.Name, $confidence)) | Out-Null
            $flags.Add(("    {0}" -f $flagNote)) | Out-Null
            $flags.Add('') | Out-Null
            if ($briefingsOnly) {
                foreach ($f in $rootFiles) {
                    if ($f.Extension.ToLower() -eq '.bib') { continue }
                    $res = Classify-File $f '' ''
                    $slot = $res[0]; $why = $res[1]
                    if (-not $slot) { Log ("    LEFT: {0}   [{1}]" -f $f.Name, $why); continue }
                    Move-Safe $f.FullName (Join-Path (Slot-Path $pp $slot) $f.Name) $why | Out-Null
                }
            }
            Process-Subfolders $pp
            Archive-OldDataVersions $pp
            Tidy-Debris $pp
            # A folder already filed on an earlier run looks empty at root now;
            # keep what that run concluded rather than downgrading it.
            $p2 = $prev[("{0}|{1}" -f $theme, $paper.Name)]
            $conf2 = $confidence; $note2 = $flagNote
            if ($p2 -and $p2.Confidence -and $p2.Confidence -ne 'none' -and $confidence -eq 'none') {
                $conf2 = $p2.Confidence
                if ($p2.Notes) { $note2 = $p2.Notes }
            }
            $status = switch ($conf2) {
                'separate-papers' { 'SPLIT THE FOLDER - several different papers' }
                'briefings-only'  { 'Briefing papers filed - no core paper exists' }
                default           { 'NO PAPER FOUND - tell me which file is the core' }
            }
            $present2 = @()
            foreach ($s in $Slots) { if (Test-Path -LiteralPath (Slot-Path $pp $s)) { $present2 += $s.Substring(0,1) } }
            $rows.Add([pscustomobject]@{
                Theme=$theme; PaperFolder=$paper.Name; Status=$status; CoreFile=''; CoreFormat=''
                OriginalFile=''; OriginalPrefix=''; Confidence=$conf2; Bibliography=''
                OtherFormats=''; Slots=($present2 -join ' '); Files=(@(Get-ChildItem -LiteralPath $pp -File -Recurse).Count)
                CoreModified=''; Notes=$note2
            }) | Out-Null
            continue
        }

        $coreStem = $core.BaseName
        $coreExt  = $core.Extension.ToLower()
        $corePfx  = Get-Prefix $coreStem
        Log ("    core ({0}, {1}): {2}   ->   {3}{4}" -f $confidence, $corePfx, $core.Name, $coreName, $coreExt)
        if ($flagNote) {
            Log ("    FLAG: {0}" -f $flagNote)
            $flags.Add(("{0}\{1}  [{2}]" -f $theme, $paper.Name, $confidence)) | Out-Null
            $flags.Add(("    chose  : {0}" -f $core.Name)) | Out-Null
            $flags.Add(("    {0}" -f $flagNote)) | Out-Null
            $flags.Add('') | Out-Null
        }

        # ---------------- bibliography ----------------------------------------
        $bibs = @($rootFiles | Where-Object { $_.Extension.ToLower() -eq '.bib' })
        $oldBibName = $null; $newBibName = ''
        if ($bibs.Count -eq 1) {
            $oldBibName = $bibs[0].Name
            $newBibName = "$coreName.bib"
            Move-Safe $bibs[0].FullName (Join-Path $pp $newBibName) 'bibliography, kept at root beside the core' | Out-Null
        } elseif ($bibs.Count -gt 1) {
            Log ("    NOTE: {0} .bib files at root - left alone" -f $bibs.Count)
        }

        # ---------------- the core itself -------------------------------------
        $coreTarget = Join-Path $pp ("{0}{1}" -f $coreName, $coreExt)
        Move-Safe $core.FullName $coreTarget 'core paper, stays at root' | Out-Null

        # ---------------- runners-up ------------------------------------------
        foreach ($r in $runnersUp) {
            Move-Safe $r.FullName (Join-Path (Slot-Path $pp $SlotBackground) $r.Name) 'runner-up to the core paper' | Out-Null
        }

        # ---------------- every other root file --------------------------------
        foreach ($f in $rootFiles) {
            if ($f.FullName -eq $core.FullName) { continue }
            if ($f.Extension.ToLower() -eq '.bib') { continue }
            if ($runnersUp | Where-Object { $_.FullName -eq $f.FullName }) { continue }
            $res = Classify-File $f $coreStem $coreName
            $slot = $res[0]; $why = $res[1]; $rename = $res[2]
            if (-not $slot) { Log ("    LEFT: {0}   [{1}]" -f $f.Name, $why); continue }
            $destName = if ($rename) { $rename } else { $f.Name }
            Move-Safe $f.FullName (Join-Path (Slot-Path $pp $slot) $destName) $why | Out-Null
        }

        Process-Subfolders $pp
        Archive-OldDataVersions $pp
        Tidy-Debris $pp

        # ---------------- repoint bibliography and image paths -----------------
        $coreNow = Join-Path $pp ("{0}{1}" -f $coreName, $coreExt)
        if ($newBibName) {
            $rep = @{}
            foreach ($b in @($oldBibName, $newBibName) | Where-Object { $_ }) {
                $rep['(?<![\w/\.])(\.\./)?' + [regex]::Escape($b)] = $newBibName
            }
            Repoint-Text $coreNow $rep 'bibliography'
            $srcDir = Slot-Path $pp $SlotSource
            if (Test-Path -LiteralPath $srcDir) {
                $rep2 = @{}
                foreach ($b in @($oldBibName, $newBibName) | Where-Object { $_ }) {
                    $rep2['(?<![\w/\.])(\.\./)?' + [regex]::Escape($b)] = '../' + $newBibName
                }
                foreach ($sf in (Get-ChildItem -LiteralPath $srcDir -File | Where-Object { $_.Extension -match '^\.(tex|qmd|rmd)$' })) {
                    Repoint-Text $sf.FullName $rep2 'bibliography'
                }
            }
        }
        if ($MoveImagesIntoSource -and (Test-Path -LiteralPath (Join-Path (Slot-Path $pp $SlotSource) 'images'))) {
            # pandoc accepts a percent-encoded space; flagged for review either way
            $imgRel = (Split-Path -Leaf (Slot-Path $pp $SlotSource)) + '/images/'
            if ($imgRel -match ' ') { $imgRel = $imgRel -replace ' ', '%20' }
            $rep3 = @{ '(?<![\w/])(\./)?images/' = $imgRel }
            if ($coreExt -in @('.qmd','.rmd')) { Repoint-Text $coreNow $rep3 'image paths - CHECK THE RENDER' }
            elseif ($coreExt -eq '.tex') {
                if ($imgRel -match '%20') {
                    Log '    NOTE: the Source folder name contains a space, so LaTeX image paths were NOT rewritten. Run Run\Master-All.bat, or set \graphicspath by hand.'
                } else {
                    Repoint-Text $coreNow $rep3 'image paths - CHECK THE RENDER'
                }
                if ($imgRel -match '%20') {
                    $review.Add(("    {0}   [tex image paths need a manual \graphicspath]" -f $coreNow.Substring($base.Length).TrimStart('\','/'))) | Out-Null
                }
            }
        }

        # ---------------- CSV row ----------------------------------------------
        $present = @()
        foreach ($s in $Slots) { if (Test-Path -LiteralPath (Slot-Path $pp $s)) { $present += $s.Substring(0,1) } }
        $others = @()
        $srcDir = Slot-Path $pp $SlotSource
        if (Test-Path -LiteralPath $srcDir) {
            $others = @(Get-ChildItem -LiteralPath $srcDir -File |
                        Where-Object { $_.BaseName -eq $coreName } |
                        ForEach-Object { $_.Extension.TrimStart('.') })
        }
        # Carry forward what an earlier run recorded, so a rename does not erase it.
        $p = $prev[("{0}|{1}" -f $theme, $paper.Name)]
        $origFile = $core.Name
        $origPfx  = $corePfx
        $conf     = $confidence
        $note     = $flagNote
        if ($p -and $p.OriginalFile) {
            $origFile = $p.OriginalFile
            if ($p.OriginalPrefix) { $origPfx = $p.OriginalPrefix }
            if ($p.CoreFile -eq "$coreName$coreExt" -and $p.Confidence) { $conf = $p.Confidence }
            if (-not $note -and $p.Notes) { $note = $p.Notes }
        }
        $status = switch ($conf) {
            'guessed'  { 'CHECK - core was guessed between versions' }
            'override' { 'Pinned by _CoreFiles.txt' }
            default    { 'Structured' }
        }

        $rows.Add([pscustomobject]@{
            Theme          = $theme
            PaperFolder    = $paper.Name
            Status         = $status
            CoreFile       = "$coreName$coreExt"
            CoreFormat     = $coreExt.TrimStart('.')
            OriginalFile   = $origFile
            OriginalPrefix = $origPfx
            Confidence     = $conf
            Bibliography   = $newBibName
            OtherFormats   = ($others -join ' ')
            Slots          = ($present -join ' ')
            Files          = (@(Get-ChildItem -LiteralPath $pp -File -Recurse).Count)
            CoreModified   = $core.LastWriteTime.ToString('yyyy-MM-dd')
            Notes          = $note
        }) | Out-Null
    }
    Blank
}

# ---------------------------------------------------------------------------
Blank
Log '================================================================'
Log ("Paper folders indexed : {0}" -f $rows.Count)
Log ("Core identified       : {0}" -f (@($rows | Where-Object { $_.CoreFile -ne '' }).Count))
Log ("Moves {0} : {1}" -f $(if ($Apply) { 'performed' } else { 'planned  ' }), $moveCount)
Blank

if ($review.Count -gt 0) {
    Log 'CHECK THESE RENDERS - a path inside the file was rewritten:'
    foreach ($r in $review) { Log $r }
    Blank
}
if ($flags.Count -gt 0) {
    Log 'FLAGGED - guessed, or needs you to decide.'
    Log 'To pin a core file, put a line in _CoreFiles.txt beside this script:'
    Log '    1. Climate and Fiscal Policy\1.2 Feebates and Output-Based Rebating | WP6- PowerSectorFeebates.docx'
    Blank
    foreach ($f in $flags) { Log $f }
}
Log '=== Done ==='

if (-not (Test-Path -LiteralPath $scriptsDir)) { New-Item -ItemType Directory -Path $scriptsDir -Force | Out-Null }
$reportPath = Join-Path $scriptsDir ('_ReorganizeReport{0}.txt' -f $(if ($Apply) { '' } else { '-preview' }))
$report | Set-Content -LiteralPath $reportPath -Encoding UTF8
$rows | Export-Csv -LiteralPath $csvPath -NoTypeInformation -Encoding UTF8

Write-Host ''
Write-Host "Report : $reportPath"
Write-Host "Index  : $csvPath"
if (-not $Apply) {
    Write-Host ''
    Write-Host 'This was a PREVIEW. Nothing was changed.'
    Write-Host 'Read the report and the CSV, then run Run-Reorganize.bat.'
}
Write-Host ''
Write-Host 'Press Enter to close...'
[void](Read-Host)
