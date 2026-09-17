# Steps

The scripts that do the work. `Engine\Run-All.ps1` and `Engine\Run-Website.ps1`
call them; you do not run them directly.

Order matters, because each assumes the one before it has settled:

1. `Rename-Folders.ps1` — folder names to `<number>.CamelCase`
2. `Reorganize-Papers.ps1` — files into the standard slots, rebuilds `Reference\_PaperIndex.csv`
3. `Rename-Files.ps1` — filename convention, flattens `media\`
4. `Repair-Encoding.ps1` — undoes double-encoded UTF-8 in text files
5. `Sync-Masters.ps1` — retires a `.docx` or PDF older than its `.qmd` master
6. `Convert-Documents.ps1` — gives every paper both a `.qmd` and a `.docx`
7. `Build-Pdfs.ps1` — a PDF per paper, each in its own killable process
8. `Publish-Site.ps1` — copy to the site, render, check every link

`ConvertOne-Pdf.ps1` converts exactly one document and exits. `Build-Pdfs.ps1`
launches one copy per paper. That separation is what makes a per-document
timeout possible: a Word COM call cannot be interrupted from inside PowerShell,
so the only way to limit it is to run it in a process that can be killed.

`Flatten-Overviews.ps1` is not part of that order and is not called by the
engine. It is run by hand from `Run\Flatten-Overviews.bat` when a section
overview still exists as a folder rather than as the single `<n>.0.<Name>.docx`
that belongs at the top of its section. It searches the tree, so renaming or
renumbering a section changes nothing, and it is a no-op once there is nothing
left to flatten.
