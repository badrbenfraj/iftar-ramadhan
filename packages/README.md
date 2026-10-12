# packages/

## card-sheet

The printable QR cards. Organizers don't use this folder: they print the
pages they need from the ready-made PDF on the `/download` page
(`apps/backend/assets/cards/iftar-cards-1-2000.pdf`, cards 1–2000, 25 per A4
page). Every region uses the same numbers, so one PDF serves them all.

`card-sheet/index.html` is how that PDF is made. It is plain HTML with a
vendored QR library (`qrcode.js`, qrcode-generator 1.4.4, MIT): open it in a
browser, enter From and To, and Print → Save as PDF (A4, scale 100%). To
regenerate the committed PDF from Git Bash on Windows:

```bash
"/c/Program Files (x86)/Microsoft/Edge/Application/msedge.exe" --headless --disable-gpu --no-pdf-header-footer \
  --print-to-pdf="$(pwd -W)/apps/backend/assets/cards/iftar-cards-1-2000.pdf" \
  "file:///$(pwd -W)/packages/card-sheet/index.html?from=1&to=2000"
```

A different range (for example 2001–4000) needs a new file name and a new
link in `apps/backend/src/app-release/download-page.ts`.

## Shared Dart packages

There are none yet: there is only one Dart application (`apps/mobile`) and the
backend is TypeScript, so a shared package would add indirection without any
reuse. Candidates if a second Dart client appears (e.g. an admin/dashboard
app):

- `iftar_domain`: `FastingPerson`, `PersonRules`, `QrPayload`, `StatsPeriod`
  (today in `apps/mobile/lib/features/*/domain`, already free of Flutter imports)
- `iftar_api`: the Dio client, `AppFailure` mapping and repositories
