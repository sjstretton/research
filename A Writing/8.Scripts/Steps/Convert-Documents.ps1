#requires -Version 5.1
<#
    Convert-Documents.ps1
    Gives every document in "A Writing" both a .qmd and a .docx.

    RULES
      - every .docx that has no sibling .qmd  ->  a .qmd is made from it
      - every .md   that has no sibling .qmd  ->  a .qmd is made from it
      - every .qmd  that has no sibling .docx ->  a .docx is made from it
      - .tex is a source format, not a document. A .tex is converted only if
        its paper folder has no .qmd anywhere. LaTeX stays where it is,
        in 2.Source.

    ZERO FORMATTING
      Word styling, fonts, colours, text boxes, section breaks and raw HTML
      are all dropped. What survives is headings, paragraphs, lists, tables,
      emphasis, footnotes and links - the content, not the presentation.

    NOT TOUCHED
      9.Archive, 4.ExternalPapers, 2.Source, the website and Overview folders,
      anything starting with _ or . , README files, and files sitting loose
      at the root of A Writing.

    SAFETY
      Nothing is overwritten and nothing is deleted. A file that already has
      its pair is skipped. Re-running is a no-op. Each conversion is
      independent - one failure does not stop the rest.

    USAGE
        Preview-Convert.bat    dry run; writes the report and a CSV
        Run\Master-All.bat        does it
#>

param(
    [switch]$Apply,
    [switch]$NoMedia,          # drop images instead of extracting them
    [int]$MaxMB = 0            # skip sources larger than this (0 = no limit)
)

$ErrorActionPreference = 'Stop'

# --- what counts -------------------------------------------------------------
# The website folder and the Overview folder hold finished output, not sources:
# nothing in either gets a .qmd. Matched by shape, so renumbering them is safe.
$ExcludeTopPattern = '^\d+[A-Za-z]?[.\s_-]+(Website|Overview)$'   # plus the scripts folder itself
$ExcludeDirs = @('9.Archive','4.ExternalPapers','2.Source','media')
$SkipNames   = '^(README|_.*)$'                     # README.md, _PaperIndex.csv...

# --- locate "A Writing" ------------------------------------------------------
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
    Write-Host ''
    Write-Host 'Could not find "A Writing" from here.'
    Write-Host "  $PSScriptRoot"
    Write-Host ''; Write-Host 'Press Enter to close...'; [void](Read-Host); return
}
$myFolder = if ($PSScriptRoot -eq $base) { '' } else { Split-Path -Leaf $PSScriptRoot }
Set-Location -LiteralPath $base

# --- find pandoc -------------------------------------------------------------
function Find-Pandoc {
    $c = Get-Command pandoc -ErrorAction SilentlyContinue
    if ($c) { return $c.Source }
    $roots = @(
        (Join-Path $env:LOCALAPPDATA 'Programs\Quarto'),
        'C:\Program Files\Quarto',
        'C:\Program Files\RStudio\resources\app\bin\quarto',
        (Join-Path $env:LOCALAPPDATA 'Pandoc')
    ) | Where-Object { $_ -and (Test-Path -LiteralPath $_) }
    foreach ($r in $roots) {
        $hit = Get-ChildItem -LiteralPath $r -Filter 'pandoc.exe' -Recurse -ErrorAction SilentlyContinue |
               Select-Object -First 1
        if ($hit) { return $hit.FullName }
    }
    return $null
}

$pandoc = Find-Pandoc
if (-not $pandoc) {
    Write-Host ''
    Write-Host 'Pandoc was not found. It does the conversion.'
    Write-Host ''
    Write-Host 'Quarto bundles it, so if you have Quarto installed this script'
    Write-Host 'normally finds it. Otherwise install pandoc with:'
    Write-Host ''
    Write-Host '    winget install --id JohnMacFarlane.Pandoc'
    Write-Host ''
    Write-Host 'then run this again.'
    Write-Host ''; Write-Host 'Press Enter to close...'; [void](Read-Host); return
}

# --- pandoc options ----------------------------------------------------------
# Strip everything that carries presentation rather than content.
$mdFlavour = 'markdown' +
             '-raw_html' + '-raw_tex' +
             '-native_divs' + '-native_spans' + '-bracketed_spans' + '-fenced_divs' +
             '-header_attributes' + '-link_attributes' + '-inline_code_attributes' +
             '-fenced_code_attributes' + '-smart'

$report  = New-Object System.Collections.Generic.List[string]
$rows    = New-Object System.Collections.Generic.List[object]
function Log($m) { $report.Add([string]$m) | Out-Null; Write-Host $m }
function Blank() { Log '' }

Log ("=== Convert documents   {0} ===" -f (Get-Date -Format 'yyyy-MM-dd HH:mm'))
Log ("Base   : {0}" -f $base)
Log ("Pandoc : {0}" -f $pandoc)
Log ("Mode   : {0}" -f $(if ($Apply) { 'APPLY - files will be written' } else { 'PREVIEW - nothing will be written' }))
Log ("Media  : {0}" -f $(if ($NoMedia) { 'dropped' } else { 'extracted to media\ beside the .qmd' }))
Blank

# --- collect candidates ------------------------------------------------------
function In-Scope([System.IO.FileInfo]$f) {
    $rel = $f.FullName.Substring($base.Length).TrimStart('\','/')
    $parts = $rel -split '[\\/]'
    if ($parts.Count -lt 2) { return $false }                 # loose at the root
    if ($parts[0] -match $ExcludeTopPattern) { return $false }
    if ($myFolder -and $parts[0] -eq $myFolder) { return $false }
    foreach ($p in $parts[0..($parts.Count - 2)]) {
        if ($ExcludeDirs -contains $p) { return $false }
        if ($p -match '^[_.]') { return $false }
    }
    if ($f.BaseName -match $SkipNames) { return $false }
    return $true
}

$all = @(Get-ChildItem -LiteralPath $base -File -Recurse -ErrorAction SilentlyContinue |
         Where-Object { $_.Extension.ToLower() -in @('.docx','.md','.qmd','.tex') } |
         Where-Object { In-Scope $_ } |
         # A section overview is a Word document by design - <n>.0.<Name>.docx at
         # the top of its section. Pairing it with a .qmd would put a second file
         # beside it, which is the thing flattening them was meant to end.
         Where-Object { $_.Name -notmatch '^\d+\.0[.\s_-]' })

# paper folder = the folder two levels below base, used for the .tex rule
function Paper-Folder([string]$full) {
    $rel = $full.Substring($base.Length).TrimStart('\','/')
    $p = $rel -split '[\\/]'
    if ($p.Count -ge 3) { return (Join-Path $base (Join-Path $p[0] $p[1])) }
    return (Join-Path $base $p[0])
}

$byFolderStem = @{}
foreach ($f in $all) {
    $k = ($f.DirectoryName + '|' + $f.BaseName).ToLower()
    if (-not $byFolderStem.ContainsKey($k)) { $byFolderStem[$k] = @{} }
    $byFolderStem[$k][$f.Extension.ToLower()] = $f
}

$jobs = @()      # @{ Src; Dst; Kind }
foreach ($k in $byFolderStem.Keys) {
    $set = $byFolderStem[$k]
    $any = ($set.Values | Select-Object -First 1)
    $dir = $any.DirectoryName

    # --- .qmd from .docx / .md -------------------------------------------
    if (-not $set.ContainsKey('.qmd')) {
        $src = $null
        if     ($set.ContainsKey('.docx')) { $src = $set['.docx'] }
        elseif ($set.ContainsKey('.md'))   { $src = $set['.md'] }
        elseif ($set.ContainsKey('.tex')) {
            # only if this paper folder has no .qmd at all
            $pf = Paper-Folder $any.FullName
            $hasQmd = @(Get-ChildItem -LiteralPath $pf -Filter '*.qmd' -Recurse -ErrorAction SilentlyContinue).Count
            if ($hasQmd -eq 0) { $src = $set['.tex'] }
        }
        if ($src) {
            $jobs += [pscustomobject]@{
                Src = $src.FullName
                Dst = (Join-Path $dir ($src.BaseName + '.qmd'))
                Kind = ($src.Extension.TrimStart('.').ToLower() + ' -> qmd')
                Bytes = $src.Length
            }
        }
    }

    # --- .docx from .qmd ---------------------------------------------------
    if (-not $set.ContainsKey('.docx')) {
        $q = $null
        if ($set.ContainsKey('.qmd')) { $q = $set['.qmd'] }
        if ($q) {
            $jobs += [pscustomobject]@{
                Src = $q.FullName
                Dst = (Join-Path $dir ($q.BaseName + '.docx'))
                Kind = 'qmd -> docx'
                Bytes = $q.Length
            }
        } else {
            # a .qmd we are about to create - queue it as a second pass
            $pending = $jobs | Where-Object { $_.Kind -like '* -> qmd' -and (Split-Path -Parent $_.Dst) -eq $dir }
            foreach ($p in $pending) {
                if ([System.IO.Path]::GetFileNameWithoutExtension($p.Dst).ToLower() -eq $any.BaseName.ToLower()) {
                    $jobs += [pscustomobject]@{
                        Src = $p.Dst
                        Dst = (Join-Path $dir ($any.BaseName + '.docx'))
                        Kind = 'qmd -> docx (new)'
                        Bytes = 0
                    }
                }
            }
        }
    }
}

# order: make every .qmd first, then every .docx
$jobs = @($jobs | Sort-Object @{E = { if ($_.Kind -like '* -> qmd') { 0 } else { 1 } } }, Src)

if ($MaxMB -gt 0) {
    $before = $jobs.Count
    $jobs = @($jobs | Where-Object { $_.Bytes -le ($MaxMB * 1MB) })
    if ($jobs.Count -lt $before) { Log ("Skipping {0} sources larger than {1} MB." -f ($before - $jobs.Count), $MaxMB) }
}

Log ("{0} conversions to do." -f $jobs.Count)
Blank

# --- run ---------------------------------------------------------------------
$ok = 0; $skip = 0; $fail = 0
foreach ($j in $jobs) {
    $relSrc = $j.Src.Substring($base.Length).TrimStart('\','/')
    $relDst = $j.Dst.Substring($base.Length).TrimStart('\','/')

    if (Test-Path -LiteralPath $j.Dst) {
        Log ("    SKIP exists : {0}" -f $relDst); $skip++
        $rows.Add([pscustomobject]@{ Source=$relSrc; Target=$relDst; Kind=$j.Kind; Result='skipped-exists'; Note='' }) | Out-Null
        continue
    }
    if (-not (Test-Path -LiteralPath $j.Src)) {
        if (-not $Apply) {
            Log ("    (would make {0}  ->  {1})" -f $relSrc, $relDst)
            $rows.Add([pscustomobject]@{ Source=$relSrc; Target=$relDst; Kind=$j.Kind; Result='planned'; Note='source created earlier in this run' }) | Out-Null
            continue
        }
        Log ("    MISSING src : {0}" -f $relSrc); $fail++
        $rows.Add([pscustomobject]@{ Source=$relSrc; Target=$relDst; Kind=$j.Kind; Result='failed'; Note='source not found' }) | Out-Null
        continue
    }

    $dir  = Split-Path -Parent $j.Src
    $sName = Split-Path -Leaf $j.Src
    $dName = Split-Path -Leaf $j.Dst
    $ext  = [System.IO.Path]::GetExtension($j.Src).ToLower()

    $args = @()
    if ($j.Kind -like '* -> qmd') {
        $from = switch ($ext) { '.docx' { 'docx' } '.tex' { 'latex' } default { 'markdown' } }
        $args = @($sName, '-f', $from, '-t', $mdFlavour, '--wrap=none',
                  '--markdown-headings=atx', '-s', '-o', $dName)
        if ($ext -eq '.docx') {
            if ($NoMedia) { $args += @('--strip-comments') }
            else          { $args += @('--strip-comments', '--extract-media=.') }
        }
    } else {
        $args = @($sName, '-f', 'markdown', '-t', 'docx', '-o', $dName)
    }

    # Images are referenced relative to wherever the document was first written,
    # which is not always the folder it now sits in - a .qmd in 8.PreviousVersions
    # still points at 2.Source\images\. Give pandoc the places to look.
    $ds = [System.IO.Path]::DirectorySeparatorChar
    $ps = [System.IO.Path]::PathSeparator
    $rp = @('.', 'media', '..',
            ('..' + $ds + '2.Source'),
            ('..' + $ds + '2.Source' + $ds + 'images'),
            ('..' + $ds + '2.Source' + $ds + 'media'),
            '2.Source',
            ('2.Source' + $ds + 'images'),
            ('2.Source' + $ds + 'media')) -join $ps
    $args += ('--resource-path=' + $rp)

    if (-not $Apply) {
        Log ("    would convert : {0}   [{1}]" -f $relDst, $j.Kind)
        $rows.Add([pscustomobject]@{ Source=$relSrc; Target=$relDst; Kind=$j.Kind; Result='planned'; Note='' }) | Out-Null
        continue
    }

    Push-Location -LiteralPath $dir
    try {
        # pandoc writes [WARNING] lines to stderr - a missing image, say. With
        # ErrorActionPreference set to Stop those warnings were raised as
        # terminating errors and killed conversions that had otherwise worked.
        # Success is decided by the exit code and the file, not by stderr.
        $prevEAP = $ErrorActionPreference
        $ErrorActionPreference = 'Continue'
        $err = & $pandoc @args 2>&1
        $code = $LASTEXITCODE
        $ErrorActionPreference = $prevEAP

        $lines = @($err | ForEach-Object { [string]$_ })
        if ($code -ne 0 -or -not (Test-Path -LiteralPath $j.Dst)) {
            throw (($lines -join ' ').Trim())
        }
        $warned = @($lines | Where-Object { $_ -match '\[WARNING\]' })
        $note = ''
        if ($warned.Count -gt 0) {
            $note = ('{0} warning(s), first: {1}' -f $warned.Count,
                     (($warned[0] -replace '\s+', ' ')))
            if ($note.Length -gt 160) { $note = $note.Substring(0, 160) }
        }

        # Give a new .qmd a minimal YAML header if pandoc did not write one.
        if ($j.Kind -like '* -> qmd') {
            $txt = Get-Content -LiteralPath $j.Dst -Raw -Encoding UTF8
            if ($txt -notmatch '^\s*---\r?\n') {
                $stem = [System.IO.Path]::GetFileNameWithoutExtension($j.Dst)
                $head = "---`ntitle: `"$stem`"`n"
                $bib  = Join-Path $dir ($stem + '.bib')
                if (Test-Path -LiteralPath $bib) { $head += "bibliography: $stem.bib`n" }
                $head += "---`n`n"
                [System.IO.File]::WriteAllText($j.Dst, $head + $txt, (New-Object System.Text.UTF8Encoding($false)))
            }
        }
        if ($note) { Log ("    made : {0}   [{1}]   ({2})" -f $relDst, $j.Kind, $note) }
        else        { Log ("    made : {0}   [{1}]" -f $relDst, $j.Kind) }
        $rows.Add([pscustomobject]@{ Source=$relSrc; Target=$relDst; Kind=$j.Kind; Result='created'; Note=$note }) | Out-Null
        $ok++
    } catch {
        $msg = ($_.Exception.Message -replace '\s+', ' ')
        if ($msg.Length -gt 200) { $msg = $msg.Substring(0,200) }
        Log ("    FAILED : {0}   ({1})" -f $relDst, $msg)
        $rows.Add([pscustomobject]@{ Source=$relSrc; Target=$relDst; Kind=$j.Kind; Result='failed'; Note=$msg }) | Out-Null
        $fail++
        if (Test-Path -LiteralPath $j.Dst) { Remove-Item -LiteralPath $j.Dst -Force -ErrorAction SilentlyContinue }
    } finally {
        Pop-Location
    }
}

Blank
Log '================================================================'
Log ("Created : {0}" -f $ok)
Log ("Skipped : {0}   (pair already there)" -f $skip)
Log ("Failed  : {0}" -f $fail)
Blank
if ($fail -gt 0) {
    Log 'Failures are listed above and in the CSV. The usual causes are a file'
    Log 'open in Word, or a .docx that is really a renamed .doc - resave it as'
    Log '.docx in Word and run this again.'
    Blank
}
Log 'Nothing was overwritten. Re-running only picks up what is still missing.'
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
$suffix = if ($Apply) { '' } else { '-preview' }
$report | Set-Content -LiteralPath (Join-Path $outDir "_ConvertReport$suffix.txt") -Encoding UTF8
$rows   | Export-Csv  -LiteralPath (Join-Path $outDir "_ConvertIndex$suffix.csv") -NoTypeInformation -Encoding UTF8

Write-Host ''
Write-Host ("Report : {0}" -f (Join-Path $outDir "_ConvertReport$suffix.txt"))
Write-Host ("CSV    : {0}" -f (Join-Path $outDir "_ConvertIndex$suffix.csv"))
if (-not $Apply) {
    Write-Host ''
    Write-Host 'This was a PREVIEW. Nothing was written.'
    Write-Host 'Read the CSV, then run Run\Master-All.bat.'
}
Write-Host ''
Write-Host 'Press Enter to close...'
[void](Read-Host)
