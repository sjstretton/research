#requires -Version 5.1
<#
    Rename-Files.ps1
    Puts every filename into the naming convention, and does the housekeeping
    that goes with it.

    CONVENTION
        <PaperName>.qmd / .docx / .bib     the main document, at the paper root,
                                           capitalised, no prefix
        1.Presentation\   Pres-<Name>      slide decks
                          Briefing-<Name>  briefing papers, abstracts, summaries
        3.BackgroundPapers\ Background-<Name>
        5.Notes\          Notes-<Name>
        2.Source\         <PaperName>.<ext>   derivatives share the master stem

    The master (.qmd) and every derivative (.docx, .pdf, .tex) that shares its
    stem are renamed together, so a document never loses its pair.

    <Name> is CamelCase with spaces and punctuation removed. A leading working
    reference - BP-, WP7-, B3a-, A3-, F2- - is dropped, and a word that just
    repeats the prefix (Brief, Presentation, Notes) is dropped too.

    HOUSEKEEPING
      - a .bib at the paper root is renamed to match the master, and the
        bibliography: / \addbibresource line is rewritten to follow it
      - pandoc's doubled media\media\ folders are flattened to media\, and
        image paths in the .qmd are rewritten
      - loose .txt and .md at a paper root move into 5.Notes

    NOT TOUCHED
      4.ExternalPapers and 9.Archive - other people's names, and the bin.
      the website folder, the scripts folder, media\, images\, README files.

    SAFETY
      Nothing is deleted. A rename whose target exists is skipped and reported.
      Re-running is a no-op.

    USAGE
        Preview-RenameFiles.bat
        Run-RenameFiles.bat
#>

param([switch]$Apply)

$ErrorActionPreference = 'Stop'

$SlotPres = '1.Presentation'
$SlotSrc  = '2.Source'
$SlotBack = '3.BackgroundPapers'
$SlotExt  = '4.ExternalPapers'
$SlotNote = '5.Notes'
$SlotArch = '9.Archive'

# Kept empty: the website, Overview and Additional folders are excluded by the
# normalised-name test where the themes are chosen, which survives renumbering.
$ExcludeTop  = @()
$LeaveAlone  = @($SlotExt, $SlotArch, 'media', 'images', '_site', '.quarto')
$TextExt     = @('.qmd','.rmd','.md','.tex')

function Norm([string]$n) { return (($n -replace '[^A-Za-z0-9]','').ToLower()) }

function Find-WritingRoot([string]$start) {
    $d = $start
    for ($i = 0; $i -lt 4; $i++) {
        $n = @(Get-ChildItem -LiteralPath $d -Directory -ErrorAction SilentlyContinue |
               Where-Object { $_.Name -match '^\d+[A-Za-z]?[.\s_-]' }).Count
        if ($n -ge 3) { return $d }
        $p = Split-Path -Parent $d
        if (-not $p -or $p -eq $d) { break }
        $d = $p
    }
    return $null
}

$base = Find-WritingRoot $PSScriptRoot
if (-not $base) {
    Write-Host ''; Write-Host 'Could not find "A Writing" from here.'
    Write-Host ''; Write-Host 'Press Enter to close...'; [void](Read-Host); return
}
$myFolder = if ($PSScriptRoot -eq $base) { '' } else { Split-Path -Leaf $PSScriptRoot }
Set-Location -LiteralPath $base

$report = New-Object System.Collections.Generic.List[string]
$rows   = New-Object System.Collections.Generic.List[object]
function Log($m) { $report.Add([string]$m) | Out-Null; Write-Host $m }
function Blank() { Log '' }

# --- naming ------------------------------------------------------------------
function To-Camel([string]$text) {
    $words = $text -split '[^A-Za-z0-9]+' | Where-Object { $_ -ne '' }
    $out = ''
    foreach ($w in $words) {
        if ($w -cmatch '^[A-Z0-9]+$' -or $w -cmatch '^[A-Z]{2,}' -or $w -cmatch '[A-Z].*[A-Z]') { $out += $w }
        else { $out += $w.Substring(0,1).ToUpper() + $w.Substring(1).ToLower() }
    }
    return $out
}

function Core-Name([string]$paperFolderName) {
    return (To-Camel ($paperFolderName -replace '^\s*\d+(\.\d+)*[A-Za-z]?[.\s_-]+', ''))
}

# words that merely repeat the prefix, per category
$Redundant = @{
    'Briefing-'   = @('brief','briefs','briefing','briefingpaper','bp')
    'Pres-'       = @('presentation','presentations','pres','slides','slide','deck')
    'Notes-'      = @('notes','note')
    'Background-' = @('background','backgroundpaper','backgroundpapers')
}

function Body-Name([string]$stem, [string]$prefix, [string]$core) {
    # drop a leading working reference: BP-, WP7-, B3a-, A3-, F2-, WP1_
    $s = $stem -creplace '^[A-Z]{1,3}\d*[a-z]?\s*[-_.\s]+', ''
    if ($s.Trim() -eq '') { $s = $stem }
    $words = $s -split '[^A-Za-z0-9]+' | Where-Object { $_ -ne '' }
    if ($prefix -and $Redundant.ContainsKey($prefix)) {
        $drop = $Redundant[$prefix]
        # only strip a repeat word at the very start or the very end
        while ($words.Count -gt 1 -and ($drop -contains $words[0].ToLower()))  { $words = $words[1..($words.Count-1)] }
        while ($words.Count -gt 1 -and ($drop -contains $words[-1].ToLower())) { $words = $words[0..($words.Count-2)] }
    }
    $body = To-Camel ($words -join ' ')
    if ($body -eq '') { $body = $core }
    return $body
}

$plan = @()   # From, To, Why
function Plan([string]$from, [string]$to, [string]$why) {
    if ($from -ceq $to) { return }
    $script:plan += [pscustomobject]@{ From = $from; To = $to; Why = $why }
}

# --- walk the paper folders --------------------------------------------------
$themes = @(Get-ChildItem -LiteralPath $base -Directory |
            Where-Object { $_.Name -match '^\d+[A-Za-z]?[.\s_-]' -and
                           $ExcludeTop -notcontains $_.Name -and
                           $_.Name -ne $myFolder -and
                           (Norm ($_.Name -replace '^\d+(\.\d+)*[A-Za-z]?[.\s_-]+','')) -notin
                             @('scripts','website','overview','additional') })

Log ("=== Rename files   {0} ===" -f (Get-Date -Format 'yyyy-MM-dd HH:mm'))
Log ("Base : {0}" -f $base)
Log ("Mode : {0}" -f $(if ($Apply) { 'APPLY' } else { 'PREVIEW - nothing will be changed' }))
Blank

foreach ($theme in $themes) {
    foreach ($paper in (Get-ChildItem -LiteralPath $theme.FullName -Directory | Sort-Object Name)) {
        $pp   = $paper.FullName
        $core = Core-Name $paper.Name
        Log ("--- {0}\{1}   (master: {2})" -f $theme.Name, $paper.Name, $core)

        # ---- flatten media\media -----------------------------------------
        foreach ($m in (Get-ChildItem -LiteralPath $pp -Directory -Recurse -Filter 'media' -ErrorAction SilentlyContinue)) {
            $inner = Join-Path $m.FullName 'media'
            if (Test-Path -LiteralPath $inner) {
                foreach ($f in (Get-ChildItem -LiteralPath $inner -File)) {
                    Plan $f.FullName (Join-Path $m.FullName $f.Name) 'flatten media\media'
                }
            }
        }

        # ---- group files by (folder, stem) --------------------------------
        $files = @(Get-ChildItem -LiteralPath $pp -File -Recurse -ErrorAction SilentlyContinue |
                   Where-Object {
                       $rel = $_.FullName.Substring($pp.Length).TrimStart('\','/')
                       $segs = $rel -split '[\\/]'
                       $bad = $false
                       if ($segs.Count -gt 1) {
                           foreach ($s in $segs[0..($segs.Count-2)]) {
                               if ($LeaveAlone -contains $s -or $s -match '^[_.]') { $bad = $true }
                           }
                       }
                       (-not $bad) -and ($_.BaseName -notmatch '^(README|_)')
                   })

        $groups = $files | Group-Object { $_.DirectoryName + '|' + $_.BaseName }

        # How many distinct documents sit at the paper root? If more than one,
        # none of them can safely be called the master.
        $rootGroups = @($groups | Where-Object {
            $_.Group[0].DirectoryName -eq $pp -and $_.Group[0].Extension -ne '.bib'
        })
        foreach ($g in $groups) {
            $first = $g.Group[0]
            $dir   = $first.DirectoryName
            $stem  = $first.BaseName
            $relDir = $dir.Substring($pp.Length).TrimStart('\','/')
            $slot  = if ($relDir -eq '') { '' } else { ($relDir -split '[\\/]')[0] }

            $newStem = $null; $why = ''; $moveTo = $dir

            switch ($slot) {
                '' {
                    if ($first.Extension -eq '.bib') { $newStem = $core; $why = 'bibliography follows the master' }
                    elseif ((Norm $stem) -eq (Norm $core)) { $newStem = $core; $why = 'master' }
                    elseif ($first.Extension -in @('.txt','.md')) {
                        $newStem = 'Notes-' + (Body-Name $stem 'Notes-' $core)
                        $moveTo = Join-Path $pp $SlotNote
                        $why = 'loose note moved to 5.Notes'
                    }
                    elseif ($rootGroups.Count -le 1) { $newStem = $core; $why = 'sits at the paper root, so it is the master' }
                    else {
                        Log ("    LEFT : {0}   ({1} documents at the paper root - which is the master?)" -f $first.Name, $rootGroups.Count)
                        $newStem = $null
                    }
                }
                $SlotPres {
                    $isDeck = ($g.Group | Where-Object { $_.Extension -in @('.pptx','.ppt','.key') }).Count -gt 0
                    $pfx = if ($isDeck) { 'Pres-' } else { 'Briefing-' }
                    $newStem = $pfx + (Body-Name $stem $pfx $core); $why = 'presentation folder'
                }
                $SlotBack { $newStem = 'Background-' + (Body-Name $stem 'Background-' $core); $why = 'background paper' }
                $SlotNote { $newStem = 'Notes-'      + (Body-Name $stem 'Notes-' $core);      $why = 'note' }
                $SlotSrc  {
                    # derivatives share the master stem, but only when unambiguous
                    foreach ($f in $g.Group) {
                        $same = @($files | Where-Object { $_.DirectoryName -eq $dir -and $_.Extension -eq $f.Extension })
                        if ($same.Count -eq 1) { Plan $f.FullName (Join-Path $dir ($core + $f.Extension)) 'derivative follows the master' }
                        else { Log ("    LEFT : {0}   (several {1} files in 2.Source)" -f $f.Name, $f.Extension) }
                    }
                    continue
                }
                default { $newStem = $null }
            }

            if ($newStem) {
                foreach ($f in $g.Group) {
                    Plan $f.FullName (Join-Path $moveTo ($newStem + $f.Extension)) $why
                }
            }
        }
    }
}

# --- execute -----------------------------------------------------------------
Blank
Log '--- renames'
$done = 0; $skipped = 0; $failed = 0
$renamed = @{}      # old leaf -> new leaf, for reference rewriting
foreach ($p in $plan) {
    $relF = $p.From.Substring($base.Length).TrimStart('\','/')
    $relT = $p.To.Substring($base.Length).TrimStart('\','/')
    if (-not (Test-Path -LiteralPath $p.From)) { continue }
    if ((Test-Path -LiteralPath $p.To) -and ($p.To -cne $p.From)) {
        Log ("    SKIP exists : {0}  ->  {1}" -f $relF, (Split-Path -Leaf $p.To)); $skipped++
        $rows.Add([pscustomobject]@{From=$relF;To=$relT;Why=$p.Why;Result='skipped-exists'}) | Out-Null
        continue
    }
    $renamed[(Split-Path -Leaf $p.From)] = (Split-Path -Leaf $p.To)
    if ($Apply) {
        try {
            $parent = Split-Path -Parent $p.To
            if (-not (Test-Path -LiteralPath $parent)) { New-Item -ItemType Directory -Path $parent -Force | Out-Null }
            Move-Item -LiteralPath $p.From -Destination $p.To
        } catch {
            Log ("    FAILED : {0}   ({1})" -f $relF, $_.Exception.Message); $failed++
            $rows.Add([pscustomobject]@{From=$relF;To=$relT;Why=$p.Why;Result='failed'}) | Out-Null
            continue
        }
    }
    Log ("    {0}  ->  {1}   [{2}]" -f $relF, (Split-Path -Leaf $p.To), $p.Why)
    $rows.Add([pscustomobject]@{From=$relF;To=$relT;Why=$p.Why;Result=$(if($Apply){'renamed'}else{'planned'})}) | Out-Null
    $done++
}

# --- rewrite what the files point at ----------------------------------------
Blank
Log '--- references'
$touched = 0
$pairs = @()
foreach ($k in $renamed.Keys) {
    if ($k -ceq $renamed[$k]) { continue }
    $pairs += [pscustomobject]@{ Pattern = '(?<![\w/\\.-])' + [regex]::Escape($k) + '(?![\w.-])'; Replace = $renamed[$k] }
}
$pairs += [pscustomobject]@{ Pattern = '(?<![\w/])media/media/'; Replace = 'media/' }
$pairs += [pscustomobject]@{ Pattern = '(?<![\w\\])media\\media\\'; Replace = 'media\' }

foreach ($f in (Get-ChildItem -LiteralPath $base -File -Recurse -ErrorAction SilentlyContinue |
                Where-Object { $TextExt -contains $_.Extension.ToLower() })) {
    if ($myFolder -and $f.FullName.StartsWith((Join-Path $base $myFolder))) { continue }
    $txt = Get-Content -LiteralPath $f.FullName -Raw -Encoding UTF8
    if ([string]::IsNullOrEmpty($txt)) { continue }
    $orig = $txt
    foreach ($p in $pairs) { $txt = [regex]::Replace($txt, $p.Pattern, $p.Replace) }
    if ($txt -ne $orig) {
        if ($Apply) { [System.IO.File]::WriteAllText($f.FullName, $txt, (New-Object System.Text.UTF8Encoding($false))) }
        Log ("    rewritten : {0}" -f $f.FullName.Substring($base.Length).TrimStart('\','/'))
        $touched++
    }
}
if ($touched -eq 0) { Log '    nothing needed rewriting' }

# --- remove the now-empty media\media shells ---------------------------------
if ($Apply) {
    foreach ($d in (Get-ChildItem -LiteralPath $base -Directory -Recurse -Filter 'media' -ErrorAction SilentlyContinue)) {
        if ((Split-Path -Leaf (Split-Path -Parent $d.FullName)) -eq 'media' -and
            -not (Get-ChildItem -LiteralPath $d.FullName -Force)) {
            Remove-Item -LiteralPath $d.FullName -Force
            Log ("    removed empty : {0}" -f $d.FullName.Substring($base.Length).TrimStart('\','/'))
        }
    }
}

Blank
Log '================================================================'
Log ("Renamed {0} : {1}" -f $(if ($Apply) { '' } else { '(planned)' }), $done)
Log ("Skipped (target exists) : {0}" -f $skipped)
Log ("Failed                  : {0}" -f $failed)
Log ("Files with references rewritten : {0}" -f $touched)
Blank
Log 'Nothing was deleted. Re-running is a no-op.'
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
$report | Set-Content -LiteralPath (Join-Path $outDir "_RenameFilesReport$sfx.txt") -Encoding UTF8
$rows   | Export-Csv  -LiteralPath (Join-Path $outDir "_RenameFilesIndex$sfx.csv") -NoTypeInformation -Encoding UTF8

Write-Host ''
Write-Host ("Report : {0}" -f (Join-Path $outDir "_RenameFilesReport$sfx.txt"))
Write-Host ("CSV    : {0}" -f (Join-Path $outDir "_RenameFilesIndex$sfx.csv"))
if (-not $Apply) { Write-Host ''; Write-Host 'PREVIEW only. Read the CSV, then run Run-RenameFiles.bat.' }
Write-Host ''
Write-Host 'Press Enter to close...'
[void](Read-Host)
