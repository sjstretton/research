# Steps

The scripts that do the work. `Engine\Run-All.ps1` and `Engine\Run-Website.ps1`
call them; you do not run them directly.

Order matters, because each assumes the one before it has settled:

1. `Rename-Folders.ps1` — folder names to `<number>.CamelCase`
2. `Sync-Masters.ps1` — retires a `.docx` or PDF older than its `.qmd` master
3. `Convert-Documents.ps1` — gives every paper both a `.qmd` and a `.docx`
4. `Publish-Site.ps1` — copy to the site, render, check every link
5. `Publish-Ftp.ps1` — upload `_site` to the web server (called by `End-Day.ps1`)

Three more are in the workflow only with `-Full`, from `Run\Organise.bat`:
`Reorganize-Papers.ps1` (files into the standard slots, rebuilds
`Reference\_PaperIndex.csv`), `Rename-Files.ps1` (filename convention, flattens
`media\media\`) and `Repair-Encoding.ps1` (undoes double-encoded UTF-8).

`Build-Pdfs.ps1` builds a PDF per paper, each in its own killable process. The
site publishes Word files, so it runs only with `Run-Website.ps1 -Pdf`.

`Publish-Ftp.ps1` reads its credentials from `Reference\_ftp.txt`, which
`.gitignore` excludes, and falls back to the website folder's own `deploy.bat`
when that file is not there.

`ConvertOne-Pdf.ps1` converts exactly one document and exits. `Build-Pdfs.ps1`
launches one copy per paper. That separation is what makes a per-document
timeout possible: a Word COM call cannot be interrupted from inside PowerShell,
so the only way to limit it is to run it in a process that can be killed.

`Push-Repo.ps1` is the GitHub part: commit, pull with `--rebase --autostash`,
push. `End-Day.ps1` calls it for its step 2 and `Run\Push-Repo.bat` runs it on
its own, so there is one copy of that logic. It never force-pushes, and it
stops on a conflict rather than resolving one.

`Verify-Setup.ps1` is the pre-flight check, run from `Run\Final-Check.bat`. It
has no `-Apply`: it reads the tree, the site, the scripts folder, the tools and
the repository, and marks every line OK, NOTE or PROBLEM.

`Flatten-Overviews.ps1` is not part of that order and is not called by the
engine. It is run by hand from `Run\Flatten-Overviews.bat` when a section
overview still exists as a folder rather than as the single `<n>.0.<Name>.docx`
that belongs at the top of its section. It searches the tree, so renaming or
renumbering a section changes nothing, and it is a no-op once there is nothing
left to flatten.

`Audit-Papers.ps1` is not part of that order either, and has no `-Apply`. Run it
from `Run\Audit-Papers.bat` to see where the same file sits in two places, where
one document exists under two names, what is loose at a paper root and which
scripts have ended up inside the content. It writes
`Reports\_AuditReport.txt` and `.csv` and touches nothing.

`Purge-Strays.ps1` is the acting half of the audit, run from
`Run\Purge-Strays.bat`. It bins scripts that ended up inside papers, files in
`2.Source` belonging to some other document, byte-identical copies within one
paper, and the losing side of two names for one document; it moves loose files
at a paper root into their slot, and removes folders left empty. The slot order
decides which copy survives: the paper root, then `2.Source`,
`1.Presentation`, `3.BackgroundPapers`, `5.Notes`, `4.ExternalPapers`,
`8.PreviousVersions`, `9.Archive`. Pass `-AcrossPapers` to also dedupe a file
held identically by two different papers; by default that is left alone.
