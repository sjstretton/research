#requires -Version 5.1
<#
    Publish-Site.ps1
    Everything between "the PDFs exist" and "the site is live and correct".

      1  PUBLISH   each <paper>\2.Source\<Name>.pdf is copied to
                    <n>.Website\papers\<Name>.pdf, the folder _quarto.yml
                    already declares as a resource, so no site config changes.
                    A paper that only ever existed as a loose PDF is published
                    from that instead.

      2  INDEX     research.qmd lives in the website folder; a Word copy is
                    written into the Overview folder as ResearchOverview.docx.

      3  RENDER    quarto render runs in the website folder.

      4  CHECK     every papers/*.pdf link in research.qmd is checked twice:
                    that the file exists in the website folder, and that it
                    actually landed in _site. Any paper with a PDF but no link,
                    or a link but no PDF, is listed.

    Nothing is deleted. Run Build-Pdfs.ps1 first, or use Master-Website.bat
    which runs both in order.

    Switches
        -Apply          actually publish and render
        -SkipRender     publish and check, but do not run quarto
#>

param(
    [switch]$Apply,
    [switch]$SkipRender,
    [ValidateSet('docx', 'pdf')][string]$Prefer = 'docx',
    [switch]$NoFixLinks
)

$ErrorActionPreference = 'Stop'

$WebFolderPattern = '^\d+[A-Za-z]?[.\s_-]+Website$'
# The folder that holds the finished overview material - the Word copy of the
# research page, the tracker, the CV extract, the deck. It is a destination, not
# a section: nothing in it is published, and the Word index is written into it.
$OverviewFolderPattern = '^\d+[A-Za-z]?[.\s_-]+Overview$'
$PdfSubfolder     = 'papers'
# Used only for the Word copy of the index: relative links work on the site but
# are dead in a .docx, so they are made absolute on the way out.
$SiteUrl          = 'https://climatefiscalfinance.org'
$SlotSource       = '2.Source'
$ExcludeThemes    = @('scripts', 'website', 'overview', 'additional')

function Norm([string]$n) { return (($n -replace '[^A-Za-z0-9]', '').ToLower()) }

# A theme is excluded if its normalised name CONTAINS any of these words, not
# only if it equals one. "6.Additional" holds the books, the
# philosophy and politics essays and the retained papers: it is a container, not
# a section, and an exact-match list would have walked straight into it.
function Is-ExcludedTheme([string]$name) {
    $n = Norm ($name -replace '^\d+(\.\d+)*[A-Za-z]?[.\s_-]+', '')
    foreach ($w in $ExcludeThemes) { if ($n -like ('*' + $w + '*')) { return $true } }
    return $false
}


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

$base = Find-WritingRoot $PSScriptRoot
if (-not $base) { Write-Host 'Could not find "A Writing".'; return }

$web = Get-ChildItem -LiteralPath $base -Directory | Where-Object { $_.Name -match $WebFolderPattern } | Select-Object -First 1
if (-not $web) { Write-Host 'No Website folder found at the root of A Writing.'; return }
$webDir = $web.FullName
$pdfDir = Join-Path $webDir $PdfSubfolder

$ovw = Get-ChildItem -LiteralPath $base -Directory |
       Where-Object { $_.Name -match $OverviewFolderPattern } | Select-Object -First 1
$ovwDir = if ($ovw) { $ovw.FullName } else { $base }

# Reports go to <scripts root>\Reports. The scripts root is the folder above
# this one when that folder holds Engine\ - which is what marks it.
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

$mode = if ($Apply) { 'APPLY' } else { 'PREVIEW' }
Log ('=== Publish site  [{0}]   {1} ===' -f $mode, (Get-Date -Format 'yyyy-MM-dd HH:mm'))
Log ('Website : {0}' -f $webDir)
Log ''

# --- 1  publish ---------------------------------------------------------------

Log '--- publish'
if ($Apply -and -not (Test-Path -LiteralPath $pdfDir)) { New-Item -ItemType Directory -Path $pdfDir -Force | Out-Null }

# Every paper is published, wherever it sits. The convention is that
# The website's papers\ folder holds the .docx of every paper in the tree, not only the ones
# research.qmd links to - the books, the philosophy and politics essays and the
# retained papers all get a URL even though nothing on the research page points
# at them. So the search is recursive rather than one level deep: the container
# 6.Additional holds sections which hold papers, and a fixed depth
# would miss every one of them.
#
# A folder is a paper folder when it holds a file named after itself. The slot
# subfolders and the build output are never descended into.

$SkipDirs = @('1.Presentation', '2.Source', '3.BackgroundPapers', '4.ExternalPapers',
              '5.Notes', '6.Reserved', '7.Reserved', '8.PreviousVersions', '9.Archive',
              'media', '_site', '.quarto', '_freeze', 'papers', 'node_modules',
              'Run', 'Engine', 'Steps', 'Reference', 'Reports')

function Find-PaperFolders([string]$root) {
    $found = New-Object System.Collections.Generic.List[object]
    $stack = New-Object System.Collections.Stack
    foreach ($d in (Get-ChildItem -LiteralPath $root -Directory -EA SilentlyContinue)) {
        if ($d.Name -match '[.\s_-]*Scripts$' -or $d.Name -match 'Website$') { continue }
        $stack.Push($d)
    }
    while ($stack.Count -gt 0) {
        $d = $stack.Pop()
        if ($SkipDirs -contains $d.Name) { continue }
        # The Overview folder holds finished deliverables - the tracker, the CV
        # extract, the deck - so it is never a paper itself. A numbered paper
        # folder parked inside it still is one, so we descend rather than skip.
        if ($d.Name -match $OverviewFolderPattern) {
            foreach ($s in (Get-ChildItem -LiteralPath $d.FullName -Directory -EA SilentlyContinue)) {
                if ($SkipDirs -notcontains $s.Name) { $stack.Push($s) }
            }
            continue
        }
        $core = Core-Name $d.Name
        $isPaper = $false
        foreach ($e in @('.docx', '.pdf', '.qmd')) {
            if (Test-Path -LiteralPath (Join-Path $d.FullName ($core + $e))) { $isPaper = $true; break }
        }
        if (-not $isPaper) {
            $loose = @(Get-ChildItem -LiteralPath $d.FullName -File -Filter '*.pdf' -EA SilentlyContinue)
            $subs  = @(Get-ChildItem -LiteralPath $d.FullName -Directory -EA SilentlyContinue |
                       Where-Object { $SkipDirs -notcontains $_.Name })
            if ($loose.Count -eq 1 -and $subs.Count -eq 0) { $isPaper = $true }
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

$paperFolders = @(Find-PaperFolders $base | Sort-Object FullName)

# A section overview is not a paper folder: it is a single Word file named
# <n>.0.<Name>.docx sitting at the top of the section it describes. Those are
# collected separately and published under the same name the folder used to
# publish under, so the addresses did not change when they were flattened.
function Find-LooseOverviews([string]$root) {
    $found = New-Object System.Collections.Generic.List[object]
    $stack = New-Object System.Collections.Stack
    foreach ($d in (Get-ChildItem -LiteralPath $root -Directory -EA SilentlyContinue)) {
        if ($d.Name -match '[.\s_-]*Scripts$' -or $d.Name -match 'Website$') { continue }
        $stack.Push($d)
    }
    while ($stack.Count -gt 0) {
        $d = $stack.Pop()
        if ($SkipDirs -contains $d.Name) { continue }
        $isOverviewFolder = ($d.Name -match $OverviewFolderPattern)
        foreach ($f in $(if ($isOverviewFolder) { @() } else { Get-ChildItem -LiteralPath $d.FullName -File -EA SilentlyContinue })) {
            if ($f.Name -match '^\d+\.0[.\s_-]' -and $f.Extension.ToLower() -in @('.docx', '.pdf')) {
                $found.Add($f) | Out-Null
            }
        }
        foreach ($s in (Get-ChildItem -LiteralPath $d.FullName -Directory -EA SilentlyContinue)) {
            if ($SkipDirs -notcontains $s.Name) { $stack.Push($s) }
        }
    }
    return $found
}
$looseOverviews = @(Find-LooseOverviews $base | Sort-Object FullName)

# What gets published, per paper, first match wins:
#   <paper>\<Core>.docx          the master Word file - the normal case
#   <paper>\2.Source\<Core>.pdf  a PDF built earlier, if PDFs are preferred
#   <paper>\<single>.pdf         a paper that only ever existed as a PDF
# $Prefer decides whether .docx or .pdf is tried first. Whatever is published,
# the link check below and the link rewrite use the extension that was actually
# copied, so research.qmd and the site cannot drift apart.

$copied = 0; $published = @{}; $missing = @()
foreach ($p in $paperFolders) {
    $t = [pscustomobject]@{ Name = (Split-Path -Leaf (Split-Path -Parent $p.FullName)) }
    $core = Core-Name $p.Name
    $docx = Join-Path $p.FullName "$core.docx"
    $pdf  = Join-Path $p.FullName (Join-Path $SlotSource "$core.pdf")

    $order = if ($Prefer -eq 'pdf') { @($pdf, $docx) } else { @($docx, $pdf) }
    $src = $null
    foreach ($cand in $order) {
        if (Test-Path -LiteralPath $cand) { $src = $cand; break }
    }
    if (-not $src) {
        $loose = @(Get-ChildItem -LiteralPath $p.FullName -File -Filter '*.pdf' -EA SilentlyContinue)
        if ($loose.Count -eq 1) {
            $src = $loose[0].FullName
            Log ('    (PDF-only paper: {0})' -f $loose[0].Name)
        }
    }
    if (-not $src) {
        $missing += ('{0}\{1}' -f $t.Name, $p.Name)
        $rows.Add([pscustomobject]@{ Theme=$t.Name; Paper=$p.Name; Master=$core; Ext=''; Published=$false }) | Out-Null
        continue
    }

    $ext  = [System.IO.Path]::GetExtension($src).ToLower()
    $dst  = Join-Path $pdfDir ($core + $ext)
    $need = $true
    if (Test-Path -LiteralPath $dst) {
        $need = (Get-Item -LiteralPath $src).LastWriteTimeUtc -gt (Get-Item -LiteralPath $dst).LastWriteTimeUtc
    }
    if ($need) {
        if ($Apply) { Copy-Item -LiteralPath $src -Destination $dst -Force }
        Log ('    -> papers\{0}{1}' -f $core, $ext)
        $copied++
    }
    # A paper that used to be published in the other format leaves a stale
    # file behind, and a stale file is worse than a missing one.
    $other = if ($ext -eq '.pdf') { '.docx' } else { '.pdf' }
    $stale = Join-Path $pdfDir ($core + $other)
    if (Test-Path -LiteralPath $stale) {
        Log ('    stale  : papers\{0}{1} is no longer the published form' -f $core, $other)
        if ($Apply) { Remove-Item -LiteralPath $stale -Force -EA SilentlyContinue }
    }

    $published[$core] = $ext
    $rows.Add([pscustomobject]@{ Theme=$t.Name; Paper=$p.Name; Master=$core; Ext=$ext; Published=$true }) | Out-Null
}
foreach ($f in $looseOverviews) {
    $core = Core-Name ([System.IO.Path]::GetFileNameWithoutExtension($f.Name))
    $ext  = $f.Extension.ToLower()
    $dst  = Join-Path $pdfDir ($core + $ext)
    $need = $true
    if (Test-Path -LiteralPath $dst) {
        $need = $f.LastWriteTimeUtc -gt (Get-Item -LiteralPath $dst).LastWriteTimeUtc
    }
    if ($need) {
        if ($Apply) { Copy-Item -LiteralPath $f.FullName -Destination $dst -Force }
        Log ('    -> papers\{0}{1}   (section overview)' -f $core, $ext)
        $copied++
    }
    $published[$core] = $ext
    $rows.Add([pscustomobject]@{
        Theme=(Split-Path -Leaf $f.DirectoryName); Paper=$f.Name; Master=$core; Ext=$ext; Published=$true }) | Out-Null
}

Log ('{0} file(s) copied, {1} paper(s) published in total.' -f $copied, $published.Count)
Log ''

# --- 1a  the papers folder mirrors what is published --------------------------
# A paper that leaves a section - retired to 9.AdditionalPapers, or moved into a
# container that is no longer scanned - leaves its published file behind. Nothing
# links to it and nothing removes it, so the folder silently accumulates. Every
# file in papers\ that this run did not publish goes to the Recycle Bin.

if (Test-Path -LiteralPath $pdfDir) {
    $orphaned = @(Get-ChildItem -LiteralPath $pdfDir -File -EA SilentlyContinue |
                  Where-Object { -not $published.ContainsKey([System.IO.Path]::GetFileNameWithoutExtension($_.Name)) })
    if ($orphaned.Count -eq 0) {
        Log '--- papers folder'
        Log '    nothing stale'
    } else {
        Log '--- papers folder'
        $onWindows = if (Test-Path Variable:\IsWindows) { $IsWindows } else { $true }
        if ($onWindows) { Add-Type -AssemblyName Microsoft.VisualBasic -ErrorAction SilentlyContinue }
        $canRecycle = $onWindows -and ($null -ne ('Microsoft.VisualBasic.FileIO.FileSystem' -as [type]))
        foreach ($o in $orphaned) {
            Log ('    STALE  : {0}   (no paper publishes this any more)' -f $o.Name)
            if ($Apply) {
                try {
                    if ($canRecycle) {
                        [Microsoft.VisualBasic.FileIO.FileSystem]::DeleteFile(
                            $o.FullName,
                            [Microsoft.VisualBasic.FileIO.UIOption]::OnlyErrorDialogs,
                            [Microsoft.VisualBasic.FileIO.RecycleOption]::SendToRecycleBin)
                    } else {
                        Remove-Item -LiteralPath $o.FullName -Force
                    }
                } catch {
                    Log ('    FAILED : {0}   ({1})' -f $o.Name, $_.Exception.Message)
                }
            }
        }
        Log ('    {0} stale file(s){1}' -f $orphaned.Count, $(if ($Apply) { ' sent to the Recycle Bin' } else { ' would be removed' }))
    }
}
Log ''

# --- 1b  point research.qmd at what was actually published --------------------
# The links used to be maintained by hand and the extension had to match the
# published file exactly. Now the publish step decides the extension and this
# rewrites the links to agree, so the two cannot drift. Only the target inside
# ](papers/...) is touched; the prose around it is left alone.

$srcQmd = Join-Path $webDir 'research.qmd'
$relinked = 0
if ((Test-Path -LiteralPath $srcQmd) -and -not $NoFixLinks -and $published.Count -gt 0) {
    Log '--- link targets'
    $txt = Get-Content -LiteralPath $srcQmd -Raw -Encoding UTF8
    $new = [regex]::Replace($txt, '\]\(papers/([^)/]+)\.(pdf|docx)\)', {
        param($m)
        $stem = $m.Groups[1].Value
        $was  = '.' + $m.Groups[2].Value
        if ($published.ContainsKey($stem)) { $is = $published[$stem] } else { $is = $was }
        return ('](papers/' + $stem + $is + ')')
    })
    # "(PDF)" in the link label would be wrong for a Word file, so the label is
    # made format-neutral wherever it appears.
    $new = $new -replace '\[Read the paper \((PDF|Word|DOCX)\) ', '[Read the paper '
    if ($new -ne $txt) {
        $changed = @()
        foreach ($k in $published.Keys) {
            $other = if ($published[$k] -eq '.pdf') { '.docx' } else { '.pdf' }
            if ($txt -match ('\]\(papers/' + [regex]::Escape($k) + [regex]::Escape($other) + '\)')) { $changed += $k }
        }
        foreach ($c in ($changed | Sort-Object)) { Log ('    relinked : {0} -> {1}' -f $c, $published[$c]) }
        $relinked = $changed.Count
        if ($Apply) {
            [System.IO.File]::WriteAllText($srcQmd, $new, (New-Object System.Text.UTF8Encoding($false)))
            Log ('    research.qmd updated ({0} link(s) repointed, labels made format-neutral)' -f $relinked)
        } else {
            Log ('    would update research.qmd ({0} link(s) repointed)' -f $relinked)
        }
    } else {
        Log '    already correct'
    }
    Log ''
}

# --- 2  index -----------------------------------------------------------------

Log '--- research index'
$oldQmd = Join-Path $base 'research.qmd'
if ((Test-Path -LiteralPath $oldQmd) -and (Test-Path -LiteralPath $srcQmd)) {
    $arch = Join-Path $reportDir 'research-qmd-superseded.txt'
    if ($Apply) { Move-Item -LiteralPath $oldQmd -Destination $arch -Force }
    Log '    the old research.qmd at the root of A Writing was superseded - moved to _Reports\'
}
if (-not (Test-Path -LiteralPath $srcQmd)) {
    Log ('    NOTE: {0}\research.qmd is missing - put it there first.' -f $web.Name)
} else {
    $pandoc = (Get-Command pandoc -EA SilentlyContinue).Source
    if (-not $pandoc) {
        $roots = @('C:\Program Files\Quarto')
        if ($env:LOCALAPPDATA) { $roots = @((Join-Path $env:LOCALAPPDATA 'Programs\Quarto')) + $roots }
        foreach ($r in $roots) {
            if (Test-Path -LiteralPath $r -ErrorAction SilentlyContinue) {
                $h = Get-ChildItem -LiteralPath $r -Filter pandoc.exe -Recurse -EA SilentlyContinue | Select-Object -First 1
                if ($h) { $pandoc = $h.FullName; break }
            }
        }
    }
    if (-not $pandoc) {
        Log '    pandoc not found - ResearchOverview.docx not written'
    } else {
        $docxOut = Join-Path $ovwDir 'ResearchOverview.docx'
        if ($Apply) {
            # research.qmd links relatively, which is right for the site and
            # useless in Word. The Word copy is built from a temporary version
            # with the links made absolute; research.qmd itself is untouched.
            $tempRoot = $env:TEMP
            if (-not $tempRoot) { $tempRoot = [System.IO.Path]::GetTempPath() }
            $tmpQmd = Join-Path $tempRoot ('research-abs-' + [guid]::NewGuid().ToString('N') + '.qmd')
            $body = Get-Content -LiteralPath $srcQmd -Raw -Encoding UTF8
            $body = $body -replace '\]\(papers/', ('](' + $SiteUrl + '/papers/')
            [System.IO.File]::WriteAllText($tmpQmd, $body, (New-Object System.Text.UTF8Encoding($false)))
            try {
                & $pandoc $tmpQmd '-f' 'markdown' '-t' 'docx' '-o' $docxOut
            } finally {
                Remove-Item -LiteralPath $tmpQmd -Force -EA SilentlyContinue
            }
        }
        $where = if ($ovw) { $ovw.Name + '\ResearchOverview.docx' } else { 'ResearchOverview.docx at the root of A Writing' }
        Log ('    {0} written, links pointing at {1}' -f $where, $SiteUrl)

        # The Word index used to be called Research.docx and used to live at the
        # root. If that copy is still there it is now two generations old.
        $stale = Join-Path $base 'Research.docx'
        if ($ovw -and (Test-Path -LiteralPath $stale)) {
            Log ('    BIN    : Research.docx at the root - superseded by {0}' -f $where)
            if ($Apply) {
                $onWindows = if (Test-Path Variable:\IsWindows) { $IsWindows } else { $true }
                if ($onWindows) { Add-Type -AssemblyName Microsoft.VisualBasic -ErrorAction SilentlyContinue }
                if ($onWindows -and ($null -ne ('Microsoft.VisualBasic.FileIO.FileSystem' -as [type]))) {
                    [Microsoft.VisualBasic.FileIO.FileSystem]::DeleteFile(
                        $stale,
                        [Microsoft.VisualBasic.FileIO.UIOption]::OnlyErrorDialogs,
                        [Microsoft.VisualBasic.FileIO.RecycleOption]::SendToRecycleBin)
                } else {
                    Remove-Item -LiteralPath $stale -Force -EA SilentlyContinue
                }
            }
        }
    }
}
Log ''

# --- 3  render ----------------------------------------------------------------

Log '--- render'
$quarto = (Get-Command quarto -EA SilentlyContinue).Source
if (-not $quarto) {
    $qroots = @('C:\Program Files\Quarto\bin')
    if ($env:LOCALAPPDATA) { $qroots = @((Join-Path $env:LOCALAPPDATA 'Programs\Quarto\bin')) + $qroots }
    foreach ($r in $qroots) {
        # plain concatenation: Join-Path throws if the drive does not exist
        $c = $r.TrimEnd('\') + '\quarto.cmd'
        if (Test-Path -LiteralPath $c -ErrorAction SilentlyContinue) { $quarto = $c; break }
    }
}
$rendered = $false
if (-not $quarto) {
    Log '    quarto not found on PATH - render skipped. Run render.bat in the website folder.'
} elseif ($SkipRender) {
    Log '    render skipped (-SkipRender)'
} elseif (-not $Apply) {
    Log '    would run: quarto render'
} else {
    Push-Location -LiteralPath $webDir
    try {
        $out = & $quarto render 2>&1
        Log ('    quarto render: exit {0}' -f $LASTEXITCODE)
        foreach ($l in ($out | Select-Object -Last 12)) { Log ('      {0}' -f $l) }
        $rendered = ($LASTEXITCODE -eq 0)
    } finally { Pop-Location }
}
Log ''

# --- 4  check -----------------------------------------------------------------

Log '--- link check'
$bad = 0; $linked = @()
if (-not (Test-Path -LiteralPath $srcQmd)) {
    Log '    no research.qmd to check'
} else {
    $txt   = Get-Content -LiteralPath $srcQmd -Raw -Encoding UTF8
    $links = @([regex]::Matches($txt, '\(([^)]*papers/[^)]+\.(?:pdf|docx))\)') | ForEach-Object { $_.Groups[1].Value } | Select-Object -Unique)
    foreach ($l in $links) {
        $linked += [System.IO.Path]::GetFileNameWithoutExtension($l)
        $here  = Join-Path $webDir ($l -replace '/', '\')
        $inSite = Join-Path $webDir (Join-Path '_site' ($l -replace '/', '\'))
        $stem = [System.IO.Path]::GetFileNameWithoutExtension($l)
        if (-not (Test-Path -LiteralPath $here)) {
            if (-not $Apply -and $published.ContainsKey($stem)) {
                Log ('    to publish   : {0}' -f $l)
            } else {
                Log ('    MISSING FILE : {0}' -f $l); $bad++
            }
        } elseif ($Apply -and $rendered -and -not (Test-Path -LiteralPath $inSite)) {
            Log ('    NOT IN _site : {0}' -f $l); $bad++
        } else {
            Log ('    ok           : {0}' -f $l)
        }
    }
    Log ('{0} link(s) checked, {1} broken.' -f $links.Count, $bad)

    # published but never linked, and linked but never published
    $orphan = @($published.Keys | Where-Object { $linked -notcontains $_ } | Sort-Object)
    if ($orphan.Count -gt 0) {
        Log ''
        Log 'Published for a URL but not linked from the research page - expected:'
        Log 'the convention is that every paper gets a file in papers\, whether or'
        Log 'not the research page lists it.'
        foreach ($o in $orphan) { Log ('    {0}{1}' -f $o, $published[$o]) }
    }
}

if ($missing.Count -gt 0) {
    Log ''
    Log 'Nothing to publish - no .docx and no .pdf:'
    foreach ($m in $missing) { Log ('    {0}' -f $m) }
}

Log ''
Log '================================================================'
Log ('Published {0}, links broken {1}, papers with nothing to publish {2}' -f $published.Count, $bad, $missing.Count)
Log '=== Done ==='

$sfx = if ($Apply) { '' } else { '-preview' }
$log  | Set-Content -LiteralPath (Join-Path $reportDir "_SiteReport$sfx.txt") -Encoding UTF8
$rows | Export-Csv  -LiteralPath (Join-Path $reportDir "_SiteIndex$sfx.csv") -NoTypeInformation -Encoding UTF8
Write-Host ''
Write-Host ('Report : {0}' -f (Join-Path $reportDir "_SiteReport$sfx.txt"))
if (-not $Apply) { Write-Host ''; Write-Host 'PREVIEW only. Run Run\Master-Website.bat to apply.' }
