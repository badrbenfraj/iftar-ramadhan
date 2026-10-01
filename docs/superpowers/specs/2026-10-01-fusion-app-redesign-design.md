# Spec 1: App redesign, "Maghrib light" fusion (UI + app-only UX)

- **Date:** 2026-10-01
- **Status:** Approved 2026-10-01 (Arabic fallback language, logo kept)
- **Scope:** `apps/mobile` (Flutter). No backend changes.
- **Companion spec:** [Spec 2, serving safety](2026-10-01-serving-safety-backend-design.md) (Undo, served-by, offline serving). It builds on this one.
- **Reference prototype:** [assets/2026-10-01-fusion-prototype.html](assets/2026-10-01-fusion-prototype.html). Open it in a browser. It's interactive and switches between English, French, and Arabic, day and night. When this document and the prototype disagree, **this document wins**.

---

## 1. Intent

### What the user asked for
- A UI that is "calm, classy, appealing" and carries Ramadan's calm and spiritual energy.
- The best possible UX, which matters most. UI and UX are built together, not visuals last.
- Translation in the new design.
- A fusion of the "Maghrib light" palette and screens (welcome, login, people list) with the UX prototype flows.

### Decisions confirmed at review
- **Languages:** English, French, and Arabic. Arabic is right to left (RTL).
- **Default language:** the device language if it's one of the three, otherwise **Arabic** (confirmed).
- **Logo:** the existing "رمضان كريم" calligraphy logo (`assets/images/ramadan.png`) **stays** on Welcome and Login (confirmed).

### Assumptions
- **Users:** volunteers serving a queue at dusk, with one hand on the phone and the other handing over food. Bright sun before maghrib, low light after. Mobile data is unreliable. Some volunteers are older or less used to apps.
- **Dignity:** the beneficiary may see the screen, so nothing reads as "denied" or alarming.

### Success criteria
1. **One glance, one tap:** the scan verdict shows in under 1 s for anyone in the phone's list. Serving takes one tap.
2. **Never lose a person, never serve twice.** The existing safety rules stay unchanged (§6.4).
3. **No dead ends:** every scan outcome offers a next step.
4. **A person without a card can be served in at most 3 taps**, plus 2 or more typed characters.
5. **Registering a person takes under 45 s, with zero card-ID typos** (the ID is scanned).
6. **Every screen works in en, fr, and ar, day and night,** with no overflow at 360×760 and at text scale 1.3.
7. **WCAG AA contrast** for every text pair in both themes.
8. **The 6 existing test files stay green.**

---

## 2. Scope

### In scope
| Area | Change |
|---|---|
| Design system | New palette (day + night), bundled fonts, shapes, ornaments, semantic color tokens |
| Localization | gen-l10n with ARB files for `en`, `fr`, `ar`. RTL layout, bidi rules, Western digits |
| Welcome | Night sky, arch window, crescent, dusk glow, **language picker** |
| Login / Register | Sky header and paper form (restyle only; same fields and API) |
| People list | Night header band, progress line, **All / Waiting / Served filters**, status chips with icons |
| Person details / edit | Restyle (behavior unchanged) |
| Add person | **Scan card to fill ID**, meal **steppers**, **duplicate-CIN warning**, **"Save and add another"**, optional fields collapsed |
| Scan | **Instant identify from cache**, seal and band verdicts, hand-over tiles, masked CIN, blessing on confirm, **find without a card**, **session summary** |
| Statistics | **Instant presets** (Tonight / This week / Ramadan), custom dates secondary |
| Profile | Restyle, plus **Language** and **Appearance** (System / Day / Night) settings |

### Out of scope (Spec 2)
- Undo after confirm
- Recording and showing who served a meal
- Serving offline, sync, and conflicts
- Persisting the people list to disk for offline restarts
- Server-side duplicate-CIN rule

### Out of scope (later, not specced)
- **Maghrib (sunset) time in the header.** It needs region coordinates and an agreed calculation method that matches Tunisia's official times. The prototype shows it; v1 doesn't.
- Any change to `apps/legacy-ionic`.

---

## 3. Design language

### 3.1 Color tokens

Implement the tokens as a `ThemeExtension<IftarColors>` with a day and a night instance. Screens read semantic names, never raw hex.

| Token | Day | Night | Use |
|---|---|---|---|
| `sky` | `#121A3A` | `#121A3A` | Header bands, nav bar, welcome and summary backgrounds |
| `skyMid` / `horizon` | `#1D2754` / `#3A3566` | same | Sky gradient stops |
| `duskGlow` | `#E8A86B` | same | Decoration only (radial glow at the bottom of the sky) |
| `onSky` | `#F3EBDD` | same | Text on sky (14.4:1) |
| `onSkyMuted` | `#A8AEC8` | same | Secondary text on sky (6.5:1 on `skyMid`) |
| `gold` | `#D6A645` | `#D6A645` | Moon, pattern, selected tab, highlights on sky (7.6:1) |
| `goldInk` | `#86621A` | `#D6A645` | Gold-colored text on light surfaces (4.9:1) |
| `mint` | `#43CEBB` | `#43CEBB` | Actions on sky surfaces: scan button, welcome "Sign in" (text `sky`, 8.7:1) |
| `page` | `#F6F1E7` | `#0E1530` | Screen background |
| `surface` | `#FFFCF6` | `#18213F` | Cards, sheets, inputs |
| `line` | `#E3D9C6` | `#2A3560` | Card borders, dividers |
| `tile` | `#F1EBDF` | `#1F2949` | Hand-over tiles, bar tracks |
| `ink` / `inkMuted` | `#1A2038` / `#5D6377` | `#F1EADB` / `#A9B0C6` | Text (14.3:1 / 5.3:1 day; 13.2:1 / 7.3:1 night) |
| `act` / `onAct` | `#0D6B62` / `#FFFFFF` | `#43CEBB` / `#121A3A` | Primary actions on light surfaces (6.4:1 / 8.1:1) |
| `actInk` / `actSoft` | `#0A5049` / `#DCEEE8` | `#86E3D4` / `#123E48` | "Not served" chip, links (7.7:1 on soft) |
| `clay` / `clayInk` / `claySoft` | `#A8432A` / `#7E2F1D` / `#F5E2D8` | `#E8957A` / `#F0A68D` / `#3A2632` | "Already served" and errors (white on clay 6.0:1; ink on soft 7.3:1) |
| `chip` / `chipInk` | `#F1E3BF` / `#1A2038` | `#2A3055` / `#F1E3BF` | ID chips |

Rules:
- **Teal/mint means "serve or act."** Gold means light and ornament, never a button fill. Clay means already served or an error, never alarm red. Indigo is structure.
- **Status is never conveyed by color alone.** Every status pairs an icon and a word.
- Build `ColorScheme` explicitly. Don't use `fromSeed`, which derives mint-grey container colors that clash with the warm palette in date pickers, dialogs, and menus.

### 3.2 Typography
| Role | Family | Size / weight | Notes |
|---|---|---|---|
| Brand / blessing | **Aref Ruqaa** | 40–56 / 400–700 | Only for "إفطار صائم", the hadith, and "تقبّل الله". Never for labels or data |
| Display (stats number, summary) | Readex Pro | 56–110 / 300 | Tabular figures |
| Title | Readex Pro | 22 / 500 | Screen titles |
| Verdict word | Readex Pro | 24 / 600 | "ما خذاش" / "خذا" in the scan band |
| Body | Readex Pro | 15–16 / 400 | |
| Label / caption | Readex Pro | 12–13 / 500 / 400 | |

- **Fonts are bundled** in `apps/mobile/assets/fonts/` (SIL OFL 1.1, license files included). No runtime download, so they work offline.
- **Letter-spacing is 0 for Arabic text.** Spaced-out Arabic breaks its joins.

### 3.3 Shape, ornament, motion
- **Radii:** card 16, sheet top 26, button 14 (no longer stadium-shaped), input 14, ID chip 10, status chip pill.
- **Arch:** the welcome window (round top) and the scan viewfinder (round top with a gold diamond at the apex).
- **Ornaments:**
  - The 8-point-star (khatam) pattern at about 17% gold opacity on header bands and the welcome window.
  - A crescent and a few stars on Welcome, Login, and Summary only.
  - The dusk glow on Welcome, Login, and Summary.
- **Seal:** an 8-point star carrying the scan verdict.
  - White star with a teal check: serve.
  - White star with a clay clock: already served.
  - Gold star with "!": system issue.
  - Pulsing gold outline: checking.
  - Gold star with a teal-ink check: confirmed.
- **Motion:** sheets 200–250 ms ease-out, the seal pulses while checking, and the confirmed progress bar runs for 1.6 s. Respect `MediaQuery.disableAnimations`.
- **Haptics:** keep the current per-state mapping (`scan_page.dart`, `_hapticsFor`).

---

## 4. Screens and flows

Route table changes are marked **new**. Everything else keeps its current route.

### 4.1 Welcome (`/welcome`)
- A night sky gradient with the dusk glow, crescent, and stars.
- **Language picker** at the top: three pills (English, Français, العربية). Choosing one applies immediately and persists.
- The arch window holds:
  - **The existing "رمضان كريم" logo** (`BrandLogo`, `ramadan.png` tinted gold, about 170 px wide).
  - The hadith "من فطّر صائماً كان له مثل أجره" in Aref Ruqaa, ivory.
  - A translated meaning line, hidden in Arabic.
- Below the arch: the app name "إفطار صائم" in Aref Ruqaa, gold, about 32 px. Then the subtitle "Iftar distribution for volunteers" (translated).
- Buttons: "Sign in" (mint, sky-colored text) and "Create volunteer account" (outline on sky).
- **Content check before release:** a qualified person verifies the hadith wording.

### 4.2 Login (`/login`) and Register (`/register`)
- **Login layout:**
  - The top 250 px is sky with the pattern, crescent, a back button, and the **"رمضان كريم" logo** (gold, about 150 px wide), with the app name in Aref Ruqaa below it.
  - Below, a paper sheet overlapping the sky by 28 px.
  - Title "Welcome back" and a one-line lead.
- **Login fields:**
  - Username and password, each with a leading icon.
  - The password field has a show/hide toggle.
- **Login behavior:**
  - Errors show as one plain sentence in a clay-soft box. Map the existing `AppFailure` messages to l10n keys.
  - The primary button is "Sign in", using the `act` color.
  - A text link reads "New volunteer? Create an account".
- **Register:** same layout, same fields as today (including the region dropdown).

### 4.3 People list (`/people`)
- **Header band** (sky with pattern):
  - A meta line: moon icon plus "Ramadan {n}" when configured (§6.7).
  - The title.
  - A count line: "{total} registered · {served} served today".
  - A mint progress line showing served/total.
  - The search field (surface color), searching by name, ID, or CIN.
- **Filter chips** below the band:
  - All, Waiting, and Served, each with a count.
  - Filtering is client-side over the cached list.
  - The selected chip uses `sky` with `onSky` text.
- **Rows:** surface cards with a `line` border. Each row has:
  - The ID chip (4-digit padded, LTR).
  - The name (ellipsis if too long).
  - A second line: status chip plus meal summary.
  - A trailing chevron (mirrored in RTL).
- **Status chip:**
  - Not served: `actSoft` background, open-circle icon, "ما خذاش".
  - Served: `claySoft` background, check icon, "خذا" and the time.
- **Empty states:**
  - Waiting filter with nobody waiting: "Everyone has been served tonight."
  - A search with no match: "No one matches “{q}”."
- **Pull to refresh** stays.

### 4.4 Person details and edit (`/people/:id`, `/people/:id/edit`)
- Restyled with the new tokens and l10n.
- The full CIN shows here, because this is the authorized edit context.
- "Confirm meal" stays, styled as the `act` button. The meal history sheet is restyled.

### 4.5 Add person (`/add`)
Header band: "New person", with the subtitle "Scan the card first, it fills the ID". Fields, in order:
1. **Card ID:**
   - A numeric field with a trailing **Scan** button.
   - Scan opens a full-screen scanner sheet in "read ID" mode. It reuses `MobileScanner` and `QrPayload.parse`, fills the field, and shows a toast "Card read: #215".
   - An invalid code shows an inline error.
2. **First name / last name:** two columns.
3. **CIN (8 digits):**
   - When 8 digits match a person in the cached list, an inline clay-soft warning appears: "Same CIN as {name} (#{id}). Is this the same person?"
   - The warning links to "Open existing record" (`/people/:id`).
   - It doesn't block saving.
4. **Meals each evening:**
   - Two steppers, Single (1 portion) and Family (4 portions).
   - Range 0–9; defaults Single 1, Family 0.
   - A live line below: "Hands over {n} portions each evening".
   - Validation: at least one meal (the existing `PersonRules.mealsError`).
5. **Here now:** a switch (= `cameToday`), default on. Subtitle: "Hand over tonight's meal and record it".
6. **Phone and notes (optional):** collapsed by default.

Actions:
- **Primary:** "Save and hand over" when Here now is on, otherwise "Save". After saving, go to `/people` and show a toast: "{name} saved. Hand over {n} portions."
- **Secondary:** "Save and add another". It stays on the form, clears it, keeps the toast, and focuses the Card ID field.
- **A server ID conflict** shows as today, on the Card ID field.

### 4.6 Scan (`/scan`)
**Layout:**
- **Camera area, on top:**
  - Status bar.
  - Top bar: close, "Scan card" with "{n} served tonight" (from the cached list), and the torch.
  - Arch viewfinder, colored by state.
  - Hint pill: "Hold the card inside the arch".
- **Bottom sheet**, which depends on the state.
- **The manual-ID keyboard dialog is removed.** "Find without a card" (§4.7) also accepts an ID.

| State | Band / seal | Content | Actions |
|---|---|---|---|
| Idle | none | Find bar: search icon, "Find someone without a card", subtitle "Search by name, CIN, or phone" | Tap opens §4.7 |
| **Identifying** (new, in cache) | `wait` band, pulsing outline seal, the person's **name** and "Checking tonight's status…" | Masked CIN, hand-over tiles, dashed "Checking…" bar (no confirm button) | none (scans ignored) |
| Looking up (not in cache) | `wait` band, "Looking up #{id}…" | none | none |
| Ready | `serve` band (teal), white seal with check, **"ما خذاش"** + "Not served tonight" | Name, masked CIN, "Hand over" tiles (family count and portions, single count and portions; zero tiles dimmed), contact line with edit (existing `showContactEditor`). No-card flow adds a gold note: "No card: ask for the CIN ending in {d}" | **Confirm hand-over** (`act`), Skip, Details |
| Confirming | same as Ready | button shows spinner and "Confirming…" | none |
| Confirmed | done band (`#0A5049`), gold seal with check, **"تقبّل الله"** (Ruqaa, gold), "Served {name} · {portions}", translated meaning (hidden in ar), 1.6 s progress bar | camera live behind | none (resumes automatically, as today) |
| Already taken | `paused` band (clay), white seal with clock, **"خذا"** + "Already served tonight", **time** at the end | Name, masked CIN, note "Nothing to hand over. Kindly let them know it was collected at {t}." | **Scan next card** (sky button), History, Details. **No serve action anywhere** |
| Not found | `system` band, gold seal "!", "Card #{id} isn't registered" + "Nobody has this card in {region}." | none | **Register this card** (`/add?id=`), Scan again |
| Invalid code | `system` band, "This code can't be read" | none | **Find without a card**, Scan again |
| Failed (lookup) | `system` band, translated failure title | message | Retry, Cancel |
| Failed (during confirm) | `system` band, **"Not confirmed yet"** + "Don't hand over until it's confirmed" | the existing "retry, do not serve twice" explanation | **Retry**, Skip |

**Viewfinder color:**
- Teal/mint: Ready or Confirming.
- Clay: Already taken.
- Gold: Identifying, Invalid, or Failed.
- Ivory: Idle or Confirmed.

### 4.7 Find without a card (new: `/scan/find`)
- Header band with back and "Without a card". The search field autofocuses.
- **Input:** 2 or more characters. Matches name (case- and accent-insensitive), CIN, phone (digits only), or ID, over the cached list. Below 2 characters, show the hint "Type 2 letters. Results come from this phone…".
- **Rows:** ID chip, name, status chip, masked CIN ("••• 812").
- **Tapping a row** returns to `/scan` and runs the Identifying flow with `noCard: true`. The Ready state then shows the CIN check note.

### 4.8 Session summary (new: `/scan/summary`)
- Shown when the scanner is closed and at least one meal was confirmed this session. Otherwise closing goes back as today.
- On a full sky background:
  - "Tonight · Ramadan {n}".
  - The served count in large type, with "iftars served by you".
  - "{f} family · {s} single · {p} portions".
  - "تقبّل الله" in Ruqaa, and its meaning.
- Buttons: "Back to people" (mint) and "Keep scanning".

### 4.9 Statistics (`/stats`)
- **Header band:**
  - Meta line, title "Statistics".
  - A large served number with "of {n} people served".
  - **Preset chips:** Tonight, This week, Ramadan. Ramadan shows only when `RAMADAN_START` is configured.
- **Presets apply immediately.** No "Validate Period" step. Ranges:
  - Tonight: today..today.
  - This week: Sunday..Saturday of the current week. This is the existing, tested `StatsPeriod.weekly` behavior from the Ionic app.
  - Ramadan: start..today.
- **Below the band:**
  - Three figure cards: portions, single, family.
  - "Custom dates" opens the existing from/to pickers in a bottom sheet.
  - "Last nights" lists one card per day with a gold bar and its value.
- **Uses the existing endpoint:** `GET /fastings/statistics/:region?start&end`.

### 4.10 Profile (`/profile`)
- Restyled, plus two new settings rows:
  - **Language:** English, Français, العربية.
  - **Appearance:** System, Day, Night.
- Both persist and apply immediately.
- Export and logout stay.

### 4.11 Bottom navigation
- A sky-colored bar with People, Add, the scan button, Stats, and Profile.
- The selected tab is gold.
- **Scan button:**
  - A 62 px mint circle with a sky-colored icon.
  - It's raised and surrounded by a 6 px sky ring, with no gold ring.
- The bar hides while the keyboard is open, as today.

---

## 5. Localization

- **Tooling:** `flutter_localizations` plus `gen-l10n`.
  - `apps/mobile/l10n.yaml`.
  - ARB files in `lib/l10n/app_en.arb` (template), `app_fr.arb`, `app_ar.arb`.
  - The generated `AppLocalizations`.
- **Every user-visible string** goes through `AppLocalizations`, including failure messages mapped from `AppFailure`.
- **Tunisian words** ("ما خذاش", "خذا") are constants, never translated. Their meaning is translated beside them.
- **Formatting locales:** `en`, `fr_TN`, and `ar_TN` for dates and numbers.
  - **Digits are always Western (0–9)**, including in Arabic.
  - If a formatter would emit Arabic-Indic digits, force the `latn` numbering. A unit test covers this.
- **RTL rules:**
  - Use directional APIs (`EdgeInsetsDirectional`, `AlignmentDirectional`, `PositionedDirectional`). Remove existing `left`/`right` paddings.
  - Mirror directional icons (back, chevrons). Don't mirror timelines or the logo.
- **Bidi:**
  - Names use the existing `isolate()` helper.
  - IDs, CIN fragments, phone numbers, times, and "87 / 214" use a new `ltr()` helper: LRI…PDI wrapping.
- **Translation workflow:** the draft fr/ar strings come from the prototype. **A native speaker must review them before release**, especially the Arabic, and the abbreviation "ب.ت.و" for CIN.

---

## 6. Architecture

### 6.1 New and changed files (indicative)
```
lib/
  l10n/app_en.arb, app_fr.arb, app_ar.arb          (new)
  core/theme/iftar_colors.dart                      (new: ThemeExtension, day/night)
  core/theme/app_theme.dart                         (rewrite: light() + dark(), explicit ColorScheme)
  core/theme/app_colors.dart                        (reduced to raw palette constants)
  core/settings/settings_controller.dart            (new: locale + ThemeMode, persisted)
  core/settings/settings_storage.dart               (new: keys in flutter_secure_storage)
  core/utils/text_direction.dart                    (new: ltr(); move isolate() here)
  core/utils/masking.dart                           (new: maskCin)
  core/utils/ramadan.dart                           (new: ramadanDay(), from AppConfig)
  core/widgets/sky_band.dart, khatam_pattern.dart, arch_frame.dart,
               seal.dart, status_chip.dart, hand_over_tiles.dart,
               meal_stepper.dart, filter_chips.dart          (new)
  core/widgets/night_sky.dart, brand.dart           (update)
  shell/home_shell.dart                             (new nav style)
  features/scan/presentation/scan_controller.dart   (Identifying state, session stats, noCard)
  features/scan/presentation/scan_result_panel.dart (rewrite to band/seal layout)
  features/scan/presentation/find_person_page.dart  (new)
  features/scan/presentation/session_summary_page.dart (new)
  features/scan/presentation/card_id_scanner_sheet.dart (new, used by Add)
  features/people/presentation/people_filter.dart   (new: filter enum + pure function)
  features/people/presentation/person_form_page.dart (steppers, scan ID, dupe, add-another)
  features/statistics/presentation/statistics_page.dart (presets)
  features/profile/presentation/profile_page.dart   (language + appearance)
  app.dart                                          (localizations, locale, themeMode, dark theme)
assets/fonts/ReadexPro-*.ttf, ArefRuqaa-*.ttf, OFL.txt (new)
```

### 6.2 Settings
- `SettingsController` (Riverpod `Notifier`) holds `Locale?` and `ThemeMode`.
  - It loads from `SettingsStorage` at startup, before the first frame, alongside the session restore.
  - A null locale means "device default if supported, else `ar`".
- `MaterialApp.router` reads `locale`, `themeMode`, `theme: AppTheme.light()`, and `darkTheme: AppTheme.dark()`.

### 6.3 Instant identify (scan)

Flow for a scanned card:

```
camera → onDetected(raw) → QrPayload.parse
   ├─ invalid → ScanInvalidCode
   └─ personId
        ├─ cached = peopleList.value?.byId(personId)
        │    ├─ found     → ScanIdentifying(cached)   ← shows name + tiles now
        │    └─ not found → ScanLookingUp(personId)   ← as today
        └─ repo.get(region, personId)  (always: tonight's status is server truth)
             ├─ ok, taken today → ScanAlreadyTaken(person, lastTakenMeal)
             ├─ ok, not taken   → ScanReady(person, noCard: flag)
             ├─ 404             → ScanNotFound
             └─ error           → ScanFailed
```

- Cached data is used **only for display.** The verdict always comes from the server response, as today.
- `ScanIdentifying` is "busy": `acceptsScans == false`, like `ScanLookingUp`.
- `pickWithoutCard(personId)` enters the same flow with `noCard: true`. It's the entry point from §4.7.
- `ScanState` gains session stats (`servedCount`, `singleMeals`, `familyMeals`) for the summary.

### 6.4 Safety invariants (unchanged, must keep their tests)
- New detections are ignored while a decision is pending (`acceptsScans`).
- The same code is ignored within the 4 s duplicate window.
- A 409 right after a failed confirm is treated as our own confirmation (the own-confirmation window).
- Confirmed resumes scanning after 1.6 s.

### 6.5 People filter
- `PeopleFilter { all, waiting, served }` plus a pure function `applyPeopleFilter(list, filter, query)`. It's unit-tested.
- Counts come from the same function.

### 6.6 Add form
- **Duplicate CIN:** a pure function `findByCin(list, cin)` over the cached list. It only sees the volunteer's own region. This is advisory only; the server-side rule is a Spec 2 follow-up.
- **Card-ID scanner sheet:** returns `int?`. It's reused by any future flow that needs to read a card.

### 6.7 Ramadan day
- `AppConfig` gains an optional `RAMADAN_START` (ISO date, `--dart-define`).
- `ramadanDay(today)` returns 1–30 when configured and in range, otherwise null. The UI hides the line on null.
- Volunteers see the season's official start, set at build time. We don't compute the Hijri date, because computed calendars can differ by a day from Tunisia's official sighting.

---

## 7. Error handling

| Situation | User sees | Next step |
|---|---|---|
| Login fails | One translated sentence in the form error box | Edit the fields and sign in again |
| People list fails to load | Existing error view, restyled and translated | Retry |
| Scan lookup network error | `system` band: "No connection" or "Server error" | Retry / Cancel |
| Confirm network error | "Not confirmed yet. Don't hand over until it's confirmed." | Retry (safe; own-confirmation logic) |
| Unknown card | "Card #{id} isn't registered" | Register this card / Scan again |
| Unreadable code | "This code can't be read" | Find without a card / Scan again |
| Card-ID scan in Add fails | Inline error under Card ID | Scan again or type the ID |
| Camera permission denied | Existing fallback screen, restyled; button "Find without a card" | Settings / Find |

---

## 8. Accessibility
- Every text pair in §3.1 passes WCAG AA, in both themes.
- Touch targets are at least 44 px (scan and forms are 48–54 px).
- Status always pairs an icon and a word. The verdict also uses distinct seal glyphs, which hold up for red–green color blindness and in grayscale.
- `Semantics` labels on the seal, chips, steppers, the scan button, and the language pills. Verdict changes are announced with `SemanticsService.announce`.
- Layout survives text scale 1.3 without overflow, and 2.0 with scrolling.
- Animations respect `disableAnimations`.

---

## 9. Testing
- **Unit:**
  - `ScanController`:
    - Identifying from cache leads to Ready or Already taken.
    - A person not in the cache goes to Looking up.
    - Scans are ignored while Identifying.
    - The `noCard` flag carries through.
    - Session stats increase on confirm.
  - `applyPeopleFilter`, `findByCin`, `maskCin`, `ramadanDay`, and meal-stepper bounds.
  - Western digits in the `ar_TN` date and number formatting.
- **l10n completeness:** a test loads the three ARB files and asserts identical key sets, with no empty values except intentional ones (the Arabic blessing meaning).
- **Widget:**
  - Each scan state renders in `en` and `ar` (RTL) at 360×760 and text scale 1.3 without overflow.
  - People filter chips.
  - Add form: validation, duplicate warning, "Save and add another".
  - Welcome language picker persists its choice.
- **Existing:** the 6 test files keep passing. Update `widgets_test.dart` where widgets move.
- **Manual field check before release:**
  - Sunlight readability.
  - One-handed scanning.
  - Grayscale and color-blindness simulation.
  - Arabic review by a native speaker.

---

## 10. Risks and open questions
| Item | Mitigation / owner |
|---|---|
| Translation quality (fr/ar drafts) | Native-speaker review before release |
| Hadith wording on Welcome | Verified by a qualified person, or replaced |
| `RAMADAN_START` must be set each season | Add to the release checklist |
| Bundled font size (~0.5–1 MB) | Acceptable; subset later if needed |
| Downloading font files into the repo | Done during implementation with the user's go-ahead (source: Google Fonts, OFL) |

---

## 11. Acceptance checklist
- [ ] All screens in §4 match the prototype's layout and the tokens in §3, day and night.
- [ ] en / fr / ar switch at runtime from Welcome and Profile, and persist. Arabic is fully RTL.
- [ ] A cached person's name shows within one frame of the scan. The verdict comes only from the server.
- [ ] Find without a card serves a person in 3 taps or fewer.
- [ ] Add: scanning a card fills the ID; the duplicate-CIN warning shows; "Save and add another" keeps the volunteer on the form.
- [ ] Statistics presets apply without a validate step.
- [ ] The session summary shows after closing the scanner with at least one serve.
- [ ] No overflow at 360×760 or text scale 1.3 in any language.
- [ ] The safety invariants in §6.4 still hold (tests green).
- [ ] The existing and new tests pass in the Docker Flutter image.
