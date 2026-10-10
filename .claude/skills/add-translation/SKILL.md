---
name: add-translation
description: Add, rename or remove user-facing text in the Flutter app (apps/mobile) in English, French and Arabic. Use for any new label, message or screen text — never hard-code strings in widgets.
---

# Adding app text (EN / FR / AR)

All text lives in `apps/mobile/lib/l10n/`:

| File | Notes |
|---|---|
| `app_en.arb` | Template. Holds the `@key` metadata (placeholders). |
| `app_fr.arb` | French. Keys only, no `@key` entries. |
| `app_ar.arb` | Arabic (right-to-left). Keys only. |

## Steps

1. Add the same key to all three files, next to related keys (keep the order
   aligned across files). Use camelCase; sections end in `Section`
   (`dataSection`, `aboutSection`).
2. Placeholders: `"greeting": "Hello {name}"` plus, in `app_en.arb` only,
   `"@greeting": {"placeholders": {"name": {"type": "String"}}}`.
3. Remove keys that are no longer used from all three files.
4. Check the three files are still valid JSON, then regenerate and analyze with
   the `flutter-docker` skill (`flutter gen-l10n && flutter analyze`). Commit the
   `.arb` files and the regenerated `app_localizations*.dart` files.
5. Use it in a widget: `final l = AppLocalizations.of(context);` then
   `l.myKey` / `l.greeting(name)`.

## Right-to-left (Arabic)

Wrap dynamic values from `lib/core/utils/formatters.dart` so they display
correctly inside Arabic text:

- `ltr(value)` for things that are always left-to-right: usernames, emails,
  phone numbers, versions, URLs.
- `isolate(value)` for names and free text that may be in either script.

Write natural Arabic and French, not word-for-word translations. If unsure of a
term, ask rather than guess: volunteers read these on the street at Iftar time.
