# Run

The only files you double-click.

**Every day**

- `Start-Day.bat` — first thing: fetch and pull from GitHub so this copy is current. Commits nothing.
- `End-Day.bat` — last thing: the full workflow, then commit / pull / push, then upload `_site` to the web server. In that order, because the site has to be built before it is committed and committed before it goes live.

**When you need them**

- `Master-All.bat` — the workflow on its own, without the git and FTP steps: folder names, stale derivatives, convert, website, tidy.
- `Master-Website.bat` — PDFs and website only. This is the one to use after editing papers.
- `Preview-All.bat`, `Preview-Website.bat` — the same two, reporting without changing anything.
- `Organise.bat` — `Master-All` with the three structural steps put back (Reorganize-Papers, Rename-Files, Repair-Encoding). After importing a batch of new material, not otherwise.
- `Spring-Clean.bat` — puts the scripts folder back to its five folders and bins the rest. It asks first.
- `Push-Repo.bat` — the GitHub part on its own: commit, pull, push. What `End-Day` runs for step 2.
- `Final-Check.bat` — reads the tree, the site, the scripts folder, the tools and the repository and says whether anything will break. Changes nothing.
- `Audit-Papers.bat` — reads the paper folders and reports duplicates, twins and files in the wrong place. It changes nothing.
- `Purge-Strays.bat` — acts on what the audit found. Deliberately aggressive: where there are two of something it keeps one and bins the rest, and moves loose files into their slot. Previews, then asks you to type PURGE. Everything removed is in the Recycle Bin.

Nothing else in the scripts folder is meant to be run by hand.
