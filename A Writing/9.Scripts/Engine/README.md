# Engine

The orchestrators.

- `Run-All.ps1` — the eight steps in dependency order. Steps 1–3 are structural: if one fails the run stops rather than letting the next act on a half-moved tree. Steps 4–7 are recorded and the run carries on.
- `Run-Website.ps1` — `Build-Pdfs` then `Publish-Site`. `Run-All` calls this as its step 7, so there is one copy of that logic.
- `Tidy-Scripts.ps1` — the spring clean. Enforces the five-folder layout and sends everything else to the Recycle Bin.

All three write a transcript to `Reports\`.
