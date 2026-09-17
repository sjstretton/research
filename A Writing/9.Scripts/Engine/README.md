# Engine

The orchestrators.

- `Start-Day.ps1` — fetch and pull from GitHub. Commits nothing. Run it first.
- `End-Day.ps1` — the workflow, then commit / pull / push, then upload `_site`. Run it last. A failed workflow stops the upload; a git conflict stops the push and says what to do.
- `Run-All.ps1` — the five steps in dependency order, or eight with `-Full`. Steps 1–3 are structural: if one fails the run stops rather than letting the next act on a half-moved tree. Steps 4–7 are recorded and the run carries on.
- `Run-Website.ps1` — `Build-Pdfs` then `Publish-Site`. `Run-All` calls this as its step 7, so there is one copy of that logic.
- `Tidy-Scripts.ps1` — the spring clean. Enforces the five-folder layout and sends everything else to the Recycle Bin.

All of them write a transcript to `Reports\`.
