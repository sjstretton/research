#requires -Version 5.1
<#
    ConvertOne-Pdf.ps1
    Turns exactly one .docx into one .pdf, then exits.

    It is meant to be launched as a separate process by Build-Pdfs.ps1, one
    process per document. That is the whole point: a Word COM call cannot be
    interrupted from inside PowerShell, so the only way to put a time limit on
    a conversion is to run it somewhere that can be killed.

    Two further precautions, both aimed at the way Word hangs rather than fails:

      - the document is copied to a local temp folder first. Files under
        OneDrive can be cloud-only placeholders, can be locked mid-sync, and
        carry a mark-of-the-web that puts Word into Protected View. Any of
        those can stall an invisible Word indefinitely.
      - Documents.Open is called with every prompt-producing argument set:
        no conversion confirmation, no encoding dialog, a dummy password so
        an encrypted file fails instead of asking, and no repair attempt.

    Exit codes:  0 built   1 failed (reason on stdout)
#>

param(
    [Parameter(Mandatory = $true)][string]$Docx,
    [Parameter(Mandatory = $true)][string]$Pdf
)

$ErrorActionPreference = 'Stop'

$tempRoot = $env:TEMP
if (-not $tempRoot) { $tempRoot = [System.IO.Path]::GetTempPath() }
$tmp = Join-Path $tempRoot ('pdfbuild-' + [guid]::NewGuid().ToString('N'))
New-Item -ItemType Directory -Path $tmp -Force | Out-Null

$localDocx = Join-Path $tmp ([System.IO.Path]::GetFileName($Docx))
$localPdf  = Join-Path $tmp ([System.IO.Path]::GetFileNameWithoutExtension($Docx) + '.pdf')

$word = $null
$doc  = $null
try {
    Copy-Item -LiteralPath $Docx -Destination $localDocx -Force
    try { Unblock-File -LiteralPath $localDocx -ErrorAction SilentlyContinue } catch { }

    $word = New-Object -ComObject Word.Application
    $word.Visible       = $false
    $word.DisplayAlerts = 0                       # wdAlertsNone
    try { $word.AutomationSecurity = 3 } catch { }  # force-disable macros
    try { $word.Options.UpdateLinksAtOpen = $false } catch { }
    try { $word.Options.ConfirmConversions = $false } catch { }
    try { $word.Options.SaveNormalPrompt = $false } catch { }

    # FileName, ConfirmConversions, ReadOnly, AddToRecentFiles,
    # PasswordDocument, PasswordTemplate, Revert, WritePasswordDocument,
    # WritePasswordTemplate, Format, Encoding, Visible, OpenAndRepair,
    # DocumentDirection, NoEncodingDialog
    $doc = $word.Documents.Open(
        $localDocx, $false, $true, $false,
        'no-password', 'no-password', $false, '',
        '', 0, 0, $false, $false,
        0, $true)

    $doc.ExportAsFixedFormat($localPdf, 17)       # 17 = wdExportFormatPDF
    $doc.Close(0)                                  # 0 = wdDoNotSaveChanges
    $doc = $null
    $word.Quit(0)
    $word = $null

    if (-not (Test-Path -LiteralPath $localPdf)) { throw 'Word reported no error but produced no PDF' }

    $outDir = Split-Path -Parent $Pdf
    if (-not (Test-Path -LiteralPath $outDir)) { New-Item -ItemType Directory -Path $outDir -Force | Out-Null }
    Copy-Item -LiteralPath $localPdf -Destination $Pdf -Force

    Write-Output ('OK {0}' -f (Get-Item -LiteralPath $Pdf).Length)
    exit 0
}
catch {
    Write-Output ('ERR ' + ($_.Exception.Message -replace '\s+', ' '))
    exit 1
}
finally {
    if ($doc)  { try { $doc.Close(0) }  catch { } }
    if ($word) { try { $word.Quit(0) } catch { } }
    try { [GC]::Collect(); [GC]::WaitForPendingFinalizers() } catch { }
    try { Remove-Item -LiteralPath $tmp -Recurse -Force -ErrorAction SilentlyContinue } catch { }
}
