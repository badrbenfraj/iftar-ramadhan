# Fusion App Redesign (Spec 1) Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Ship the "Maghrib light" redesign of the Flutter volunteer app, with all the app-only UX improvements, in English, French, and Arabic (RTL), day and night.

**Architecture:**
1. **Foundations first:** fonts, color tokens as a `ThemeExtension`, gen-l10n, settings for language and theme, text utilities, and ornament widgets.
2. **Then each screen**, migrated one at a time, starting from the shell.
3. **Scan flow after that:** it gains an `Identifying` state fed by the cached people list, plus Find-without-card and Session-summary routes.
4. **Cleanup last:** a final task removes the legacy color aliases and runs a layout matrix test (every screen × 3 languages × 2 themes).

Every task leaves the app compiling and the test suite green.

**Tech Stack:** Flutter (Docker image `ghcr.io/cirruslabs/flutter:stable`, ≥ 3.32), Riverpod 3, go_router 17, `flutter_localizations` + gen-l10n, `intl`, `mobile_scanner` 7, `flutter_secure_storage` 11.

**Spec:** [docs/superpowers/specs/2026-10-01-fusion-app-redesign-design.md](../specs/2026-10-01-fusion-app-redesign-design.md). The visual reference is [the fusion prototype](../specs/assets/2026-10-01-fusion-prototype.html). Read both before starting.

## Global Constraints

- **Run Flutter only through Docker, from `apps/mobile`, in Git Bash.** Define this once per shell:
  ```bash
  fl() { MSYS_NO_PATHCONV=1 docker run --rm -v "$(pwd -W)":/app -v iftar_pub_cache:/root/.pub-cache -w /app ghcr.io/cirruslabs/flutter:stable flutter "$@"; }
  ```
  Then `fl test`, `fl analyze`, and `fl gen-l10n`.
- **Line endings are LF.** When scripting edits with Windows Python, open files with `newline=''`.
- **Commit only your task's files, with an explicit pathspec:**
  ```bash
  git add <files> && git commit -m "<type>: <summary>" -m "Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>" -- <files>
  ```
  The working tree may hold other staged work, so never run a bare `git commit -a` or `git add -A`.
- **Languages:** `ar`, `fr`, `en`. The default is the device language if it's supported, else **Arabic**.
- **Every user-visible string goes through `AppLocalizations`.** The only exceptions:
  - The Tunisian status words `خذا` / `ما خذاش` (`MealStatusWords`).
  - The app name and hadith (`brand.dart`).
  - The native language names (`languageNames`).
- **Digits are always Western (0–9)**, in every language. Use `formatTime`, `formatDate`, and `latinDigits`.
- **Letter-spacing is 0 for Arabic text.** Use `labelTracking(context)`.
- **Bidi:**
  - Names use `isolate()`.
  - IDs, times, CIN fragments, and "87 / 214" use `ltr()`.
  - Paddings use the directional APIs (`EdgeInsetsDirectional`, `AlignmentDirectional`, `PositionedDirectional`).
- **Colors:**
  - Semantic colors come from `context.colors` (`IftarColors`).
  - Sky and band colors come from `AppPalette`.
  - No new uses of `AppColors`, which is removed in Task 20.
- **The aesthetic rules from spec §3.1:**
  - Teal/mint means serve or act.
  - Gold is ornament only, never a button fill.
  - Clay means already served or an error.
  - Status is never color alone: always an icon plus a word.
- **The scan safety invariants (spec §6.4) and their existing tests must keep passing:**
  - `acceptsScans`.
  - The 4 s duplicate window.
  - The own-confirmation window.
  - The 1.6 s resume.
- **No new pub dependencies** beyond `flutter_localizations` (SDK). Fonts are assets.
- **Layout:** no overflow at 360×760 logical px and text scale 1.3, in any language or theme.
- **Animations that loop** (the checking seal) keep `pumpAndSettle` from settling. Use `pump()` in tests that show them.

## Review Focus

These inputs are implied by the spec but easy to miss. Each one gets a test in the task named.

1. **Very long names** (e.g. "Mohamed Ali Ben Abdelkader Trabelsi"). They must ellipsize in list rows and the scan sheet, with no overflow, in Arabic and French. *Tests: Task 11 (row), Task 17 (sheet), Task 20 (all screens).*
2. **A person with 0 single and 0 family meals** (legacy data). The hand-over tiles show "none" twice and nothing crashes. *Test: Task 7.*
3. **Already served with no timestamp** (`takenAt == null`). The note falls back to the version without a time. *Test: Task 17.*
4. **A Find query with case, accents, and spaces** (`"  HEDI "` must match "Hédi"). *Tests: Task 15 (widget and domain).*
5. **An unparseable statistics day label** from the server. It shows the raw label and doesn't crash. *Test: Task 5.*

## File map

| File | Responsibility | Task |
|---|---|---|
| `tool/fetch_fonts.py`, `assets/fonts/*` | Bundled Readex Pro and Aref Ruqaa (OFL) | 1 |
| `lib/core/theme/app_colors.dart` | `AppPalette` (sky and bands), legacy `AppColors` aliases (temporary), spacing and radii | 2 |
| `lib/core/theme/iftar_colors.dart` | `IftarColors` ThemeExtension (day and night), `context.colors` | 2 |
| `lib/core/theme/app_theme.dart` | `AppTheme.light()` / `dark()` with an explicit `ColorScheme` | 2 |
| `l10n.yaml`, `lib/l10n/app_{en,fr,ar}.arb` | Strings; generated `app_localizations*.dart` | 3 |
| `lib/core/settings/locale_resolution.dart` | `resolveAppLocale`, `supportedLanguageCodes`, `languageNames` | 3 |
| `lib/core/settings/settings_storage.dart`, `settings_controller.dart` | Persisted locale and `ThemeMode` | 4 |
| `lib/core/utils/formatters.dart` | Western-digit date and time, `isolate`, `ltr`, `latinDigits` | 5 |
| `lib/core/utils/masking.dart`, `ramadan.dart`, `typography.dart` | `maskCin`, `ramadanDay`, `labelTracking` | 5 |
| `lib/core/widgets/khatam.dart`, `night_sky.dart`, `arch_window.dart`, `seal.dart` | Ornaments | 6 |
| `lib/core/widgets/status_chip.dart`, `hand_over_tiles.dart`, `meal_stepper.dart` | Data widgets | 7 |
| `lib/core/network/failure_text.dart` | `AppFailure` → localized text | 7 |
| `lib/shell/home_shell.dart` | Sky bottom bar and scan button | 8 |
| `lib/features/auth/presentation/*` | Welcome, Login, Register, Splash | 9, 10 |
| `lib/features/people/presentation/people_filter.dart` | Filter enum, pure filter and count functions | 11 |
| `lib/features/people/domain/person_lookup.dart` | `findByCin` | 13 |
| `lib/features/scan/presentation/viewfinder.dart` | Arch viewfinder painter (shared by scan and card-ID sheet) | 13 |
| `lib/features/scan/presentation/card_id_scanner.dart` | Read-ID scanner for Add | 13 |
| `lib/features/scan/presentation/scan_controller.dart` | `ScanIdentifying`, `noCard`, `pickWithoutCard`, session stats | 14 |
| `lib/features/scan/presentation/find_person_page.dart` | `/find` | 15 |
| `lib/features/scan/presentation/session_summary_page.dart` | `/summary` | 16 |
| `lib/features/scan/presentation/scan_result_panel.dart`, `scan_page.dart` | Band and seal verdicts | 17 |
| `lib/features/statistics/*` | Presets | 18 |
| `lib/features/profile/presentation/profile_page.dart` | Language and appearance settings | 19 |

---

### Task 0: Prerequisites (no code)

**Files:** none.

- [ ] **Step 1: Wait for the parallel backend session to finish.** It's fixing the "fake meal yesterday" bug in this same checkout (`apps/backend`). Don't start until it reports done, so the baseline commit doesn't capture half-edited backend files.

- [ ] **Step 2: STOP and ask the user how to commit the migration baseline.** `main` currently holds hundreds of uncommitted, staged files: the whole monorepo migration, including `apps/mobile`. Every task below commits files inside `apps/mobile`, so they need a baseline commit first. Ask the user to choose:
  - (a) They commit the baseline themselves.
  - (b) You commit it on a new branch after they review `git status`.

  Proceed only with their answer. For (b):
  ```bash
  cd /c/Users/bbenfraj/projects/iftar-ramadhan
  git switch -c feat/fusion-redesign
  git status --short | head -50   # show the user before committing
  git commit -m "chore: monorepo migration baseline (Flutter app, Nest backend)" -m "Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
  ```
  If they choose (a), still create the branch with `git switch -c feat/fusion-redesign` after their commit.

- [ ] **Step 3: Check the toolchain.**
  ```bash
  cd /c/Users/bbenfraj/projects/iftar-ramadhan/apps/mobile
  docker info > /dev/null && echo docker-ok
  fl --version
  ```
  Expected: `docker-ok`, and Flutter **3.32 or newer**. Older versions generate l10n into a synthetic package, which this plan doesn't use. If it's older, stop and report.

- [ ] **Step 4: Establish a green baseline.**
  ```bash
  fl pub get
  fl test
  fl analyze
  ```
  Expected: all tests pass. Record any analyzer infos that already exist so later tasks don't get blamed for them.

---

### Task 1: Bundle the fonts

**Files:**
- Create: `apps/mobile/tool/fetch_fonts.py`
- Create: `apps/mobile/assets/fonts/ReadexPro-{300,400,500,600,700}.ttf`, `ArefRuqaa-{400,700}.ttf`, `OFL-ReadexPro.txt`, `OFL-ArefRuqaa.txt`
- Modify: `apps/mobile/pubspec.yaml`, the `flutter:` section
- Test: `apps/mobile/test/theme/fonts_test.dart`

**Interfaces:**
- Produces: font families `ReadexPro` (weights 300–700) and `ArefRuqaa` (400, 700), referenced as `AppTheme.fontFamily` / `AppTheme.brandFont` in Task 2.

- [ ] **Step 1: Write the failing test** `test/theme/fonts_test.dart`:
  ```dart
  import 'package:flutter/services.dart';
  import 'package:flutter_test/flutter_test.dart';

  void main() {
    TestWidgetsFlutterBinding.ensureInitialized();

    const files = [
      'assets/fonts/ReadexPro-300.ttf',
      'assets/fonts/ReadexPro-400.ttf',
      'assets/fonts/ReadexPro-500.ttf',
      'assets/fonts/ReadexPro-600.ttf',
      'assets/fonts/ReadexPro-700.ttf',
      'assets/fonts/ArefRuqaa-400.ttf',
      'assets/fonts/ArefRuqaa-700.ttf',
    ];

    test('bundled fonts are present and are TrueType', () async {
      for (final path in files) {
        final data = await rootBundle.load(path);
        expect(data.lengthInBytes, greaterThan(20000), reason: path);
        final magic = data.getUint32(0);
        // 0x00010000 = TrueType outlines, 0x74727565 = 'true' (Apple).
        expect(magic == 0x00010000 || magic == 0x74727565, isTrue, reason: path);
      }
    });
  }
  ```

- [ ] **Step 2: Run it to verify it fails.**
  Run: `fl test test/theme/fonts_test.dart`
  Expected: FAIL, because the assets can't be loaded.

- [ ] **Step 3: Get the user's OK to download the fonts.** This downloads about 1 MB from `fonts.googleapis.com` / `fonts.gstatic.com`: Readex Pro and Aref Ruqaa, both SIL OFL 1.1, plus their license files from `github.com/google/fonts`. Ask before running Step 4.

- [ ] **Step 4: Add `tool/fetch_fonts.py` and run it.**
  ```python
  """Downloads the static TTFs the app bundles (SIL OFL 1.1).

  Run from apps/mobile:  python tool/fetch_fonts.py
  """
  import pathlib
  import re
  import urllib.request

  CSS_URL = (
      "https://fonts.googleapis.com/css2"
      "?family=Readex+Pro:wght@300;400;500;600;700"
      "&family=Aref+Ruqaa:wght@400;700"
  )
  LICENSES = {
      "ReadexPro": "https://raw.githubusercontent.com/google/fonts/main/ofl/readexpro/OFL.txt",
      "ArefRuqaa": "https://raw.githubusercontent.com/google/fonts/main/ofl/arefruqaa/OFL.txt",
  }
  EXPECTED = {("ReadexPro", w) for w in ("300", "400", "500", "600", "700")} | {
      ("ArefRuqaa", w) for w in ("400", "700")
  }


  def get(url: str) -> bytes:
      # urllib's default user agent gets whole TTF files from Google Fonts
      # (browsers get unicode-range woff2 subsets instead).
      with urllib.request.urlopen(url, timeout=60) as response:
          return response.read()


  def main() -> None:
      out = pathlib.Path("assets/fonts")
      out.mkdir(parents=True, exist_ok=True)
      css = get(CSS_URL).decode("utf-8")
      seen = set()
      for block in re.findall(r"@font-face\s*\{[^}]+\}", css):
          family = re.search(r"font-family:\s*'([^']+)'", block).group(1).replace(" ", "")
          weight = re.search(r"font-weight:\s*(\d+)", block).group(1)
          url = re.search(r"url\((https://[^)]+)\)", block).group(1)
          key = (family, weight)
          if key in seen:
              raise SystemExit(
                  f"Google returned subset files for {key}; download the static "
                  "TTFs manually from fonts.google.com instead."
              )
          seen.add(key)
          data = get(url)
          if data[:4] not in (b"\x00\x01\x00\x00", b"true"):
              raise SystemExit(f"{key} is not a TrueType file (got {data[:4]!r}).")
          (out / f"{family}-{weight}.ttf").write_bytes(data)
          print(f"{family}-{weight}.ttf  {len(data) // 1024} KB")
      if seen != EXPECTED:
          raise SystemExit(f"Missing fonts: {sorted(EXPECTED - seen)}")
      for family, url in LICENSES.items():
          (out / f"OFL-{family}.txt").write_bytes(get(url))
      print("Licenses saved.")


  if __name__ == "__main__":
      main()
  ```
  Run: `python tool/fetch_fonts.py` (host Python, from `apps/mobile`).
  Expected: 7 lines like `ReadexPro-400.ttf  80 KB`, then `Licenses saved.`

- [ ] **Step 5: Register the fonts in `pubspec.yaml`.** Under the existing `flutter:` key, after `assets:`, add:
  ```yaml
    fonts:
      - family: ReadexPro
        fonts:
          - asset: assets/fonts/ReadexPro-300.ttf
            weight: 300
          - asset: assets/fonts/ReadexPro-400.ttf
            weight: 400
          - asset: assets/fonts/ReadexPro-500.ttf
            weight: 500
          - asset: assets/fonts/ReadexPro-600.ttf
            weight: 600
          - asset: assets/fonts/ReadexPro-700.ttf
            weight: 700
      - family: ArefRuqaa
        fonts:
          - asset: assets/fonts/ArefRuqaa-400.ttf
            weight: 400
          - asset: assets/fonts/ArefRuqaa-700.ttf
            weight: 700
  ```

- [ ] **Step 6: Run the test to verify it passes.**
  Run: `fl test test/theme/fonts_test.dart`
  Expected: PASS.

- [ ] **Step 7: Commit.**
  ```bash
  git add tool/fetch_fonts.py assets/fonts pubspec.yaml test/theme/fonts_test.dart
  git commit -m "feat(mobile): bundle Readex Pro and Aref Ruqaa fonts" -m "Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>" -- tool/fetch_fonts.py assets/fonts pubspec.yaml test/theme/fonts_test.dart
  ```

---

### Task 2: Color tokens and themes (day and night)

**Files:**
- Create: `lib/core/theme/iftar_colors.dart`
- Rewrite: `lib/core/theme/app_colors.dart`, `lib/core/theme/app_theme.dart`
- Test: `test/theme/contrast_test.dart`, `test/theme/theme_test.dart`

**Interfaces:**
- Produces:
  - `IftarColors` (fields below), with `IftarColors.day` and `IftarColors.night`.
  - The `BuildContext.colors` getter.
  - `AppPalette` constants: `sky`, `skyTop`, `skyMid`, `horizon`, `horizonLow`, `duskGlow`, `onSky`, `onSkyMuted`, `gold`, `goldSoft`, `mint`, `serveBand`, `serveBandNight`, `doneBand`, `pausedBand`, `systemBandNight`, `waitBand`, `skyGradient`, `bandGradient`.
  - `AppTheme.light()`, `AppTheme.dark()`, `AppTheme.fontFamily` (`'ReadexPro'`), `AppTheme.brandFont` (`'ArefRuqaa'`).
  - `AppRadii.card` (16), `sheet` (26), `button` (14), `field` (14), `chip` (10), `pill` (50).
  - `AppSpacing` (unchanged).
  - The legacy `AppColors.*` names keep compiling until Task 20.

- [ ] **Step 1: Write the failing tests.**

  `test/theme/contrast_test.dart`:
  ```dart
  import 'package:flutter/painting.dart';
  import 'package:flutter_test/flutter_test.dart';
  import 'package:iftar_mobile/core/theme/app_colors.dart';
  import 'package:iftar_mobile/core/theme/iftar_colors.dart';

  double contrast(Color a, Color b) {
    final la = a.computeLuminance();
    final lb = b.computeLuminance();
    final hi = la > lb ? la : lb;
    final lo = la > lb ? lb : la;
    return (hi + 0.05) / (lo + 0.05);
  }

  void main() {
    const white = Color(0xFFFFFFFF);
    for (final (name, c) in [('day', IftarColors.day), ('night', IftarColors.night)]) {
      group('$name: text pairs pass WCAG AA (4.5:1)', () {
        final pairs = <String, (Color, Color)>{
          'ink on page': (c.ink, c.page),
          'inkMuted on page': (c.inkMuted, c.page),
          'inkMuted on surface': (c.inkMuted, c.surface),
          'inkMuted on tile': (c.inkMuted, c.tile),
          'onAct on act': (c.onAct, c.act),
          'actInk on actSoft': (c.actInk, c.actSoft),
          'actInk on surface': (c.actInk, c.surface),
          'clayInk on claySoft': (c.clayInk, c.claySoft),
          'clay on surface': (c.clay, c.surface),
          'onClay on clay': (c.onClay, c.clay),
          'goldInk on page': (c.goldInk, c.page),
          'goldInk on warnSoft': (c.goldInk, c.warnSoft),
          'chipInk on chip': (c.chipInk, c.chip),
          'white on serveBand': (white, c.serveBand),
          'onSky on systemBand': (AppPalette.onSky, c.systemBand),
        };
        pairs.forEach((label, pair) {
          test(label, () {
            expect(contrast(pair.$1, pair.$2), greaterThanOrEqualTo(4.5));
          });
        });
      });
    }

    group('sky surfaces', () {
      final pairs = <String, (Color, Color)>{
        'onSky on sky': (AppPalette.onSky, AppPalette.sky),
        'onSky on horizon': (AppPalette.onSky, AppPalette.horizon),
        'onSkyMuted on skyMid': (AppPalette.onSkyMuted, AppPalette.skyMid),
        'onSkyMuted on horizon': (AppPalette.onSkyMuted, AppPalette.horizon),
        'gold on sky': (AppPalette.gold, AppPalette.sky),
        'gold on skyMid': (AppPalette.gold, AppPalette.skyMid),
        'sky on mint': (AppPalette.sky, AppPalette.mint),
        'white on pausedBand': (white, AppPalette.pausedBand),
        'white on doneBand': (white, AppPalette.doneBand),
        'onSky on waitBand': (AppPalette.onSky, AppPalette.waitBand),
      };
      pairs.forEach((label, pair) {
        test(label, () {
          expect(contrast(pair.$1, pair.$2), greaterThanOrEqualTo(4.5));
        });
      });
      test('gold blessing on doneBand passes AA for large text (3:1)', () {
        expect(contrast(AppPalette.gold, AppPalette.doneBand), greaterThanOrEqualTo(3));
      });
    });
  }
  ```

  `test/theme/theme_test.dart`:
  ```dart
  import 'package:flutter/material.dart';
  import 'package:flutter_test/flutter_test.dart';
  import 'package:iftar_mobile/core/theme/app_theme.dart';
  import 'package:iftar_mobile/core/theme/iftar_colors.dart';

  void main() {
    test('both themes carry IftarColors and the bundled font', () {
      for (final theme in [AppTheme.light(), AppTheme.dark()]) {
        expect(theme.extension<IftarColors>(), isNotNull);
        expect(theme.textTheme.bodyMedium?.fontFamily, AppTheme.fontFamily);
        expect(theme.colorScheme.primary, theme.extension<IftarColors>()!.act);
      }
      expect(AppTheme.light().brightness, Brightness.light);
      expect(AppTheme.dark().brightness, Brightness.dark);
      expect(AppTheme.dark().extension<IftarColors>(), IftarColors.night);
    });
  }
  ```

- [ ] **Step 2: Run them to verify they fail.**
  Run: `fl test test/theme`
  Expected: FAIL to compile, because `iftar_colors.dart` and `AppPalette` don't exist.

- [ ] **Step 3: Create `lib/core/theme/iftar_colors.dart`.**
  ```dart
  import 'package:flutter/material.dart';

  /// Semantic colors that differ between the day and night themes
  /// (spec §3.1). Read them with `context.colors`.
  @immutable
  class IftarColors extends ThemeExtension<IftarColors> {
    const IftarColors({
      required this.page,
      required this.surface,
      required this.line,
      required this.tile,
      required this.ink,
      required this.inkMuted,
      required this.act,
      required this.onAct,
      required this.actInk,
      required this.actSoft,
      required this.clay,
      required this.onClay,
      required this.clayInk,
      required this.claySoft,
      required this.goldInk,
      required this.warnSoft,
      required this.chip,
      required this.chipInk,
      required this.serveBand,
      required this.systemBand,
    });

    final Color page;
    final Color surface;
    final Color line;
    final Color tile;
    final Color ink;
    final Color inkMuted;

    /// Primary actions on light surfaces ("serve or act").
    final Color act;
    final Color onAct;
    final Color actInk;
    final Color actSoft;

    /// "Already served" and errors. Never alarm red.
    final Color clay;
    final Color onClay;
    final Color clayInk;
    final Color claySoft;

    /// Gold-colored text on light surfaces.
    final Color goldInk;
    final Color warnSoft;

    /// ID chips.
    final Color chip;
    final Color chipInk;

    /// Scan verdict bands that change with the theme.
    final Color serveBand;
    final Color systemBand;

    static const day = IftarColors(
      page: Color(0xFFF6F1E7),
      surface: Color(0xFFFFFCF6),
      line: Color(0xFFE3D9C6),
      tile: Color(0xFFF1EBDF),
      ink: Color(0xFF1A2038),
      inkMuted: Color(0xFF5D6377),
      act: Color(0xFF0D6B62),
      onAct: Color(0xFFFFFFFF),
      actInk: Color(0xFF0A5049),
      actSoft: Color(0xFFDCEEE8),
      clay: Color(0xFFA8432A),
      onClay: Color(0xFFFFFFFF),
      clayInk: Color(0xFF7E2F1D),
      claySoft: Color(0xFFF5E2D8),
      goldInk: Color(0xFF86621A),
      warnSoft: Color(0xFFF3EBD6),
      chip: Color(0xFFF1E3BF),
      chipInk: Color(0xFF1A2038),
      serveBand: Color(0xFF0D6B62),
      systemBand: Color(0xFF121A3A),
    );

    static const night = IftarColors(
      page: Color(0xFF0E1530),
      surface: Color(0xFF18213F),
      line: Color(0xFF2A3560),
      tile: Color(0xFF1F2949),
      ink: Color(0xFFF1EADB),
      inkMuted: Color(0xFFA9B0C6),
      act: Color(0xFF43CEBB),
      onAct: Color(0xFF121A3A),
      actInk: Color(0xFF86E3D4),
      actSoft: Color(0xFF123E48),
      clay: Color(0xFFE8957A),
      onClay: Color(0xFF121A3A),
      clayInk: Color(0xFFF0A68D),
      claySoft: Color(0xFF3A2632),
      goldInk: Color(0xFFD6A645),
      warnSoft: Color(0xFF2B2A33),
      chip: Color(0xFF2A3055),
      chipInk: Color(0xFFF1E3BF),
      serveBand: Color(0xFF0F7A70),
      systemBand: Color(0xFF2A3563),
    );

    @override
    IftarColors copyWith() => this;

    /// Day and night are distinct palettes; snapping halfway is enough.
    @override
    IftarColors lerp(covariant IftarColors? other, double t) =>
        other == null || t < 0.5 ? this : other;
  }

  extension IftarColorsContext on BuildContext {
    IftarColors get colors =>
        Theme.of(this).extension<IftarColors>() ?? IftarColors.day;
  }
  ```

- [ ] **Step 4: Rewrite `lib/core/theme/app_colors.dart`.**
  ```dart
  import 'package:flutter/material.dart';

  /// "Maghrib light" sky and band colors, identical in both themes.
  /// Theme-dependent colors live in `IftarColors` (`context.colors`).
  abstract final class AppPalette {
    static const skyTop = Color(0xFF0E1530);
    static const sky = Color(0xFF121A3A);
    static const skyMid = Color(0xFF1D2754);
    static const horizon = Color(0xFF3A3566);
    static const horizonLow = Color(0xFF5A4560);
    static const duskGlow = Color(0xFFE8A86B);
    static const onSky = Color(0xFFF3EBDD);
    static const onSkyMuted = Color(0xFFA8AEC8);
    static const gold = Color(0xFFD6A645);
    static const goldSoft = Color(0xFFF1E3BF);
    static const mint = Color(0xFF43CEBB);

    // Scan verdict bands. White text, except the gold blessing on doneBand.
    static const serveBand = Color(0xFF0D6B62);
    static const serveBandNight = Color(0xFF0F7A70);
    static const doneBand = Color(0xFF0A5049);
    static const pausedBand = Color(0xFFA8432A);
    static const systemBandNight = Color(0xFF2A3563);
    static const waitBand = Color(0xFF2A3360);

    /// Full-screen sky: Welcome, Login header, Summary.
    static const skyGradient = LinearGradient(
      begin: Alignment.topCenter,
      end: Alignment.bottomCenter,
      colors: [skyTop, skyMid, horizon, horizonLow],
      stops: [0, 0.55, 0.86, 1],
    );

    /// Header bands on the main tabs.
    static const bandGradient = LinearGradient(
      begin: Alignment.topCenter,
      end: Alignment.bottomCenter,
      colors: [skyTop, skyMid],
    );
  }

  /// Legacy names from the first Flutter theme, re-pointed at the new
  /// palette so unmigrated screens keep compiling. Removed in Task 20; don't
  /// add new uses.
  abstract final class AppColors {
    static const teal = Color(0xFF0D6B62);
    static const tealShade = Color(0xFF0A5049);
    static const tealTint = Color(0xFFDCEEE8);
    static const tealDeep = Color(0xFF0A5049);
    static const night = AppPalette.sky;
    static const nightMid = AppPalette.skyMid;
    static const nightGlow = AppPalette.horizon;
    static const gold = AppPalette.gold;
    static const goldSoft = AppPalette.goldSoft;
    static const goldDeep = Color(0xFF86621A);
    static const ivory = Color(0xFFF6F1E7);
    static const surface = Color(0xFFFFFCF6);
    static const outline = Color(0xFFE3D9C6);
    static const ink = Color(0xFF1A2038);
    static const inkMuted = Color(0xFF5D6377);
    static const success = Color(0xFF0D6B62);
    static const successSoft = Color(0xFFDCEEE8);
    static const danger = Color(0xFFA8432A);
    static const dangerSoft = Color(0xFFF5E2D8);
    static const warning = Color(0xFF86621A);
    static const warningSoft = Color(0xFFF3EBD6);
    static const nightGradient = AppPalette.skyGradient;
  }

  /// Spacing scale (4-pt grid) shared by all screens.
  abstract final class AppSpacing {
    static const xs = 4.0;
    static const sm = 8.0;
    static const md = 12.0;
    static const lg = 16.0;
    static const xl = 24.0;
    static const xxl = 32.0;
    static const gutter = 20.0;
  }

  abstract final class AppRadii {
    static const pill = 50.0;
    static const card = 16.0;
    static const sheet = 26.0;
    static const button = 14.0;
    static const field = 14.0;
    static const chip = 10.0;
  }
  ```

- [ ] **Step 5: Rewrite `lib/core/theme/app_theme.dart`.**
  ```dart
  import 'package:flutter/material.dart';

  import 'app_colors.dart';
  import 'iftar_colors.dart';

  abstract final class AppTheme {
    static const fontFamily = 'ReadexPro';
    static const brandFont = 'ArefRuqaa';

    static ThemeData light() => _build(IftarColors.day, Brightness.light);
    static ThemeData dark() => _build(IftarColors.night, Brightness.dark);

    static ThemeData _build(IftarColors c, Brightness brightness) {
      // Explicit scheme: fromSeed would derive mint-grey containers that
      // clash with the warm palette in pickers, dialogs and menus.
      final scheme = ColorScheme(
        brightness: brightness,
        primary: c.act,
        onPrimary: c.onAct,
        primaryContainer: c.actSoft,
        onPrimaryContainer: c.actInk,
        secondary: AppPalette.gold,
        onSecondary: AppPalette.sky,
        secondaryContainer: c.chip,
        onSecondaryContainer: c.chipInk,
        tertiary: AppPalette.sky,
        onTertiary: AppPalette.onSky,
        error: c.clay,
        onError: c.onClay,
        errorContainer: c.claySoft,
        onErrorContainer: c.clayInk,
        surface: c.surface,
        onSurface: c.ink,
        onSurfaceVariant: c.inkMuted,
        surfaceContainerLowest: c.surface,
        surfaceContainerLow: c.surface,
        surfaceContainer: c.page,
        surfaceContainerHigh: c.tile,
        surfaceContainerHighest: c.tile,
        outline: c.line,
        outlineVariant: c.line,
        inverseSurface: AppPalette.sky,
        onInverseSurface: AppPalette.onSky,
        surfaceTint: Colors.transparent,
      );

      final base = ThemeData(
        useMaterial3: true,
        colorScheme: scheme,
        fontFamily: fontFamily,
        scaffoldBackgroundColor: c.page,
        extensions: [c],
      );
      final text = base.textTheme.apply(bodyColor: c.ink, displayColor: c.ink);
      final buttonShape = RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadii.button),
      );
      OutlineInputBorder border(Color color, [double width = 1]) =>
          OutlineInputBorder(
            borderRadius: BorderRadius.circular(AppRadii.field),
            borderSide: BorderSide(color: color, width: width),
          );
      const buttonText = TextStyle(
        fontFamily: fontFamily,
        fontSize: 15.5,
        fontWeight: FontWeight.w500,
      );

      return base.copyWith(
        textTheme: text.copyWith(
          headlineSmall: text.headlineSmall?.copyWith(fontWeight: FontWeight.w500),
          titleLarge: text.titleLarge?.copyWith(
            fontSize: 22,
            fontWeight: FontWeight.w500,
          ),
          titleMedium: text.titleMedium?.copyWith(fontWeight: FontWeight.w500),
        ),
        appBarTheme: AppBarTheme(
          backgroundColor: c.page,
          foregroundColor: c.ink,
          elevation: 0,
          scrolledUnderElevation: 0.5,
          centerTitle: false,
          titleTextStyle: TextStyle(
            fontFamily: fontFamily,
            color: c.ink,
            fontSize: 20,
            fontWeight: FontWeight.w500,
          ),
        ),
        cardTheme: CardThemeData(
          color: c.surface,
          elevation: 0,
          margin: EdgeInsets.zero,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadii.card),
            side: BorderSide(color: c.line),
          ),
        ),
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: c.surface,
          contentPadding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.lg,
            vertical: 14,
          ),
          border: border(c.line),
          enabledBorder: border(c.line),
          focusedBorder: border(c.act, 1.6),
          errorBorder: border(c.clay),
          focusedErrorBorder: border(c.clay, 1.6),
          labelStyle: TextStyle(color: c.inkMuted),
          hintStyle: TextStyle(color: c.inkMuted),
          errorStyle: TextStyle(color: c.clay),
        ),
        filledButtonTheme: FilledButtonThemeData(
          style: FilledButton.styleFrom(
            backgroundColor: c.act,
            foregroundColor: c.onAct,
            disabledBackgroundColor: c.act.withValues(alpha: 0.4),
            disabledForegroundColor: c.onAct,
            minimumSize: const Size.fromHeight(52),
            shape: buttonShape,
            textStyle: buttonText,
          ),
        ),
        outlinedButtonTheme: OutlinedButtonThemeData(
          style: OutlinedButton.styleFrom(
            foregroundColor: c.ink,
            minimumSize: const Size.fromHeight(52),
            shape: buttonShape,
            side: BorderSide(color: c.line),
            textStyle: buttonText,
          ),
        ),
        textButtonTheme: TextButtonThemeData(
          style: TextButton.styleFrom(
            foregroundColor: c.actInk,
            minimumSize: const Size(44, 44),
            textStyle: const TextStyle(
              fontFamily: fontFamily,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
        floatingActionButtonTheme: const FloatingActionButtonThemeData(
          backgroundColor: AppPalette.mint,
          foregroundColor: AppPalette.sky,
          shape: CircleBorder(),
          elevation: 0,
        ),
        snackBarTheme: SnackBarThemeData(
          behavior: SnackBarBehavior.floating,
          backgroundColor: AppPalette.sky,
          contentTextStyle: const TextStyle(
            fontFamily: fontFamily,
            color: AppPalette.onSky,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadii.button),
            side: BorderSide(color: AppPalette.gold.withValues(alpha: 0.35)),
          ),
        ),
        dialogTheme: DialogThemeData(
          backgroundColor: c.surface,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        ),
        bottomSheetTheme: BottomSheetThemeData(
          backgroundColor: c.page,
          showDragHandle: true,
          shape: const RoundedRectangleBorder(
            borderRadius: BorderRadius.vertical(
              top: Radius.circular(AppRadii.sheet),
            ),
          ),
        ),
        progressIndicatorTheme: ProgressIndicatorThemeData(color: c.act),
        dividerTheme: DividerThemeData(color: c.line, space: 1),
        switchTheme: SwitchThemeData(
          trackColor: WidgetStateProperty.resolveWith(
            (states) =>
                states.contains(WidgetState.selected) ? c.act : c.line,
          ),
          thumbColor: const WidgetStatePropertyAll(Colors.white),
          trackOutlineColor: const WidgetStatePropertyAll(Colors.transparent),
        ),
      );
    }
  }
  ```

- [ ] **Step 6: Run the tests, then the whole suite.**
  Run: `fl test test/theme && fl test`
  Expected: PASS. Existing screens compile through the legacy `AppColors` aliases, and their colors shift to the new palette.

- [ ] **Step 7: Commit.**
  ```bash
  git add lib/core/theme test/theme/contrast_test.dart test/theme/theme_test.dart
  git commit -m "feat(mobile): Maghrib light color tokens, day and night themes" -m "Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>" -- lib/core/theme test/theme/contrast_test.dart test/theme/theme_test.dart
  ```

---

### Task 3: Localization infrastructure (gen-l10n, en/fr/ar)

**Files:**
- Create: `l10n.yaml`, `lib/l10n/app_en.arb`, `lib/l10n/app_fr.arb`, `lib/l10n/app_ar.arb`, plus the generated `lib/l10n/app_localizations*.dart`
- Create: `lib/core/settings/locale_resolution.dart`
- Create: `test/support/app_harness.dart`, `test/l10n/arb_completeness_test.dart`, `test/core/locale_resolution_test.dart`
- Modify: `pubspec.yaml`, `lib/app.dart`, `lib/main.dart`, `test/presentation/widgets_test.dart` (harness only)

**Interfaces:**
- Produces:
  - `AppLocalizations` (import `package:iftar_mobile/l10n/app_localizations.dart`), with every key below. Getter and method names equal the ARB keys.
  - `lookupAppLocalizations(Locale)`.
  - `resolveAppLocale(Locale? chosen, Iterable<Locale>? device) → Locale`, `supportedLanguageCodes`, `languageNames`.
  - The test helper `localizedApp(Widget child, {overrides, locale, night})`.

- [ ] **Step 1: Write the failing tests.**

  `test/core/locale_resolution_test.dart`:
  ```dart
  import 'package:flutter/widgets.dart';
  import 'package:flutter_test/flutter_test.dart';
  import 'package:iftar_mobile/core/settings/locale_resolution.dart';

  void main() {
    test('a saved choice wins over the device', () {
      expect(
        resolveAppLocale(const Locale('fr'), const [Locale('en', 'US')]),
        const Locale('fr'),
      );
    });

    test('first supported device language is used', () {
      expect(
        resolveAppLocale(null, const [Locale('de'), Locale('fr', 'TN')]),
        const Locale('fr'),
      );
    });

    test('falls back to Arabic when nothing is supported', () {
      expect(resolveAppLocale(null, const [Locale('de')]), const Locale('ar'));
      expect(resolveAppLocale(null, null), const Locale('ar'));
      expect(resolveAppLocale(const Locale('it'), null), const Locale('ar'));
    });
  }
  ```

  `test/l10n/arb_completeness_test.dart`:
  ```dart
  import 'dart:convert';
  import 'dart:io';

  import 'package:flutter_test/flutter_test.dart';

  Map<String, dynamic> _arb(String code) =>
      jsonDecode(File('lib/l10n/app_$code.arb').readAsStringSync())
          as Map<String, dynamic>;

  Set<String> _keys(Map<String, dynamic> arb) =>
      arb.keys.where((k) => !k.startsWith('@')).toSet();

  void main() {
    // Arabic hides the translated meaning under Arabic text (spec §4.1, §4.6).
    const intentionallyEmpty = {
      'ar': {'hadithMeaning', 'blessingMeaning'},
    };
    final english = _arb('en');

    for (final code in ['fr', 'ar']) {
      test('$code has exactly the English keys', () {
        expect(_keys(_arb(code)), _keys(english));
      });

      test('$code has no empty strings except intentional ones', () {
        final arb = _arb(code);
        final empty = _keys(arb)
            .where((k) => (arb[k] as String).trim().isEmpty)
            .toSet();
        expect(empty, intentionallyEmpty[code] ?? <String>{});
      });
    }
  }
  ```

- [ ] **Step 2: Run them to verify they fail.**
  Run: `fl test test/core/locale_resolution_test.dart test/l10n`
  Expected: FAIL, because the files don't exist.

- [ ] **Step 3: Add the dependency and generator flag to `pubspec.yaml`.**
  ```yaml
  dependencies:
    flutter_localizations:
      sdk: flutter
  ```
  Add that under `dependencies:`, next to `flutter:`. Then, under the top-level `flutter:` key:
  ```yaml
  flutter:
    generate: true
  ```
  Keep `uses-material-design`, `assets`, and `fonts` as they are.

- [ ] **Step 4: Create `l10n.yaml`** in `apps/mobile`:
  ```yaml
  arb-dir: lib/l10n
  template-arb-file: app_en.arb
  output-localization-file: app_localizations.dart
  output-class: AppLocalizations
  nullable-getter: false
  ```

- [ ] **Step 5: Create `lib/l10n/app_en.arb`.** This is the template; metadata is needed only for placeholders.
  ```json
  {
    "@@locale": "en",
    "appTitle": "إفطار صائم",
    "appSubtitle": "Iftar distribution for volunteers",
    "hadithMeaning": "Whoever gives iftar to a fasting person shares in their reward",
    "blessingMeaning": "May God accept it",
    "signIn": "Sign in",
    "createVolunteerAccount": "Create volunteer account",
    "welcomeBack": "Welcome back",
    "loginLead": "Sign in to serve tonight in your region.",
    "registerTitle": "Join the volunteers",
    "registerLead": "Each volunteer serves one region.",
    "username": "Username",
    "password": "Password",
    "fullName": "Name",
    "email": "Email",
    "region": "Region",
    "chooseRegion": "Choose your region",
    "loadingRegions": "Loading regions…",
    "regionsFailed": "Could not load regions",
    "showPassword": "Show password",
    "hidePassword": "Hide password",
    "usernameRequired": "Username is required.",
    "passwordRequired": "Password is required.",
    "nameRequired": "Name is required.",
    "emailRequired": "Email is required.",
    "emailInvalid": "Enter a valid email address.",
    "passwordTooShort": "Use at least 6 characters.",
    "regionRequired": "Region is required.",
    "newVolunteerCreateAccount": "New volunteer? Create an account",
    "haveAccountSignIn": "Already a volunteer? Sign in",
    "accountCreated": "Account created. You can sign in now.",
    "signUp": "Create account",
    "errLoginFailed": "Wrong username or password.",
    "errAccountDisabled": "This account has been disabled.",
    "errNetwork": "No internet connection. Check your network and try again.",
    "errTimeout": "The server is taking too long to respond. Try again.",
    "errSessionExpired": "Your session has expired. Please sign in again.",
    "errForbidden": "You are not allowed to perform this action.",
    "errNotFound": "Not found.",
    "errServer": "Something went wrong on the server. Try again in a moment.",
    "errUnknown": "Unexpected error. Try again.",
    "errNoRegion": "Your account has no region assigned. Ask an administrator.",
    "errUsernameTaken": "Username or email is already in use.",
    "titleOffline": "You are offline",
    "titleSlow": "The server is slow",
    "titleServerError": "Server error",
    "titleSignedOut": "Signed out",
    "titleNotFound": "Not found",
    "titleGenericError": "Something went wrong",
    "tryAgain": "Try again",
    "retry": "Retry",
    "cancel": "Cancel",
    "save": "Save",
    "edit": "Edit",
    "back": "Back",
    "loading": "Fetching data",
    "increase": "Increase",
    "decrease": "Decrease",
    "navPeople": "People",
    "navAdd": "Add",
    "navStats": "Stats",
    "navProfile": "Profile",
    "navScan": "Scan a card",
    "ramadanDay": "Ramadan {day}",
    "@ramadanDay": {"placeholders": {"day": {"type": "int"}}},
    "peopleTitle": "Fasting people",
    "peopleCount": "{total} registered · {served} served today",
    "@peopleCount": {"placeholders": {"total": {"type": "int"}, "served": {"type": "int"}}},
    "searchPeople": "Search by name, ID, or CIN",
    "clearSearch": "Clear search",
    "filterAll": "All",
    "filterWaiting": "Waiting",
    "filterServed": "Served",
    "noPeopleTitle": "No fasting people yet",
    "noPeopleMessage": "Add the first person to start distributing meals.",
    "addPerson": "Add person",
    "everyoneServed": "Everyone has been served tonight.",
    "noMatch": "No one matches “{query}”.",
    "@noMatch": {"placeholders": {"query": {"type": "String"}}},
    "searchTip": "Search by name, ID, CIN, or phone.",
    "offlineLastList": "Offline. Showing the last loaded list.",
    "mealSingleCount": "{count} single",
    "@mealSingleCount": {"placeholders": {"count": {"type": "int"}}},
    "mealFamilyCount": "{count} family",
    "@mealFamilyCount": {"placeholders": {"count": {"type": "int"}}},
    "servedTooltip": "Served today",
    "notServedTooltip": "Not served yet today",
    "portions": "{count, plural, =1{1 portion} other{{count} portions}}",
    "@portions": {"placeholders": {"count": {"type": "int"}}},
    "addTitle": "New person",
    "addSubtitle": "Scan the card first, it fills the ID",
    "editTitle": "Edit person",
    "cardId": "Card ID",
    "scanCard": "Scan",
    "cardRead": "Card read: #{id}",
    "@cardRead": {"placeholders": {"id": {"type": "int"}}},
    "cardScanTitle": "Scan the card",
    "cardInvalid": "This code isn’t a card ID.",
    "idRequired": "Scan or type the card ID",
    "idInvalid": "The card ID must be a positive whole number",
    "idTaken": "This card ID is already registered",
    "firstName": "First name",
    "lastName": "Last name",
    "firstNameRequired": "Add a first name",
    "lastNameRequired": "Add a last name",
    "cinLabel": "CIN (8 digits)",
    "cinLength": "The CIN has 8 digits",
    "duplicateCin": "Same CIN as {name} (#{id}). Is this the same person?",
    "@duplicateCin": {"placeholders": {"name": {"type": "String"}, "id": {"type": "int"}}},
    "openExistingRecord": "Open existing record",
    "mealsEachEvening": "Meals each evening",
    "singleMeal": "Single meal",
    "familyMeal": "Family meal",
    "handsOverEachEvening": "Hands over {count, plural, =1{1 portion} other{{count} portions}} each evening",
    "@handsOverEachEvening": {"placeholders": {"count": {"type": "int"}}},
    "mealsAtLeastOne": "Choose at least one meal",
    "hereNow": "Here now",
    "hereNowSubtitle": "Hand over tonight’s meal and record it",
    "optionalFields": "Phone and notes (optional)",
    "phone": "Phone",
    "notes": "Notes",
    "saveAndHandOver": "Save and hand over",
    "saveAndAddAnother": "Save and add another",
    "updatePerson": "Update person details",
    "deletePerson": "Delete person",
    "deleteTitle": "Delete this person?",
    "deleteBody": "{name} will be removed from the fasting people list.",
    "@deleteBody": {"placeholders": {"name": {"type": "String"}}},
    "delete": "Delete",
    "personSaved": "{name} saved.",
    "@personSaved": {"placeholders": {"name": {"type": "String"}}},
    "personSavedHandOver": "{name} saved. Hand over {count, plural, =1{1 portion} other{{count} portions}}.",
    "@personSavedHandOver": {"placeholders": {"name": {"type": "String"}, "count": {"type": "int"}}},
    "personUpdated": "Person updated.",
    "personDeleted": "{name} deleted.",
    "@personDeleted": {"placeholders": {"name": {"type": "String"}}},
    "detailsTitle": "Person details",
    "identity": "Identity",
    "meals": "Meals",
    "identifier": "Card ID",
    "cinShortLabel": "CIN",
    "lastMeal": "Last meal: {date}",
    "@lastMeal": {"placeholders": {"date": {"type": "String"}}},
    "mealToday": "Tonight",
    "confirmMeal": "Confirm meal",
    "alreadyServedToday": "Already served today",
    "mealHistory": "Meal history ({count})",
    "@mealHistory": {"placeholders": {"count": {"type": "int"}}},
    "mealHistoryTitle": "Meals taken by {name}",
    "@mealHistoryTitle": {"placeholders": {"name": {"type": "String"}}},
    "noMealsYet": "No meals taken yet.",
    "mealConfirmed": "Meal confirmed.",
    "alreadyCollected": "Already collected today.",
    "alreadyCollectedAt": "Already collected today at {time}.",
    "@alreadyCollectedAt": {"placeholders": {"time": {"type": "String"}}},
    "editContact": "Edit phone and comment",
    "contactTitle": "Phone and comment",
    "comment": "Comment",
    "scanTitle": "Scan card",
    "servedTonight": "{count} served tonight",
    "@servedTonight": {"placeholders": {"count": {"type": "int"}}},
    "torchOn": "Turn torch on",
    "torchOff": "Turn torch off",
    "closeScanner": "Close scanner",
    "scanHint": "Hold the card inside the arch",
    "findNoCard": "Find someone without a card",
    "findNoCardSubtitle": "Search by name, CIN, or phone",
    "checkingStatus": "Checking tonight’s status…",
    "lookingUp": "Looking up #{id}…",
    "@lookingUp": {"placeholders": {"id": {"type": "int"}}},
    "notServedTonight": "Not served tonight",
    "handOver": "Hand over",
    "none": "none",
    "confirmHandOver": "Confirm hand-over",
    "confirming": "Confirming…",
    "skip": "Skip",
    "details": "Details",
    "noCardCheck": "No card: ask for the CIN ending in {digits}",
    "@noCardCheck": {"placeholders": {"digits": {"type": "String"}}},
    "servedLine": "Served {name} · {count, plural, =1{1 portion} other{{count} portions}}",
    "@servedLine": {"placeholders": {"name": {"type": "String"}, "count": {"type": "int"}}},
    "alreadyServedTonight": "Already served tonight",
    "alreadyServedNote": "Nothing to hand over. Kindly let them know it was collected at {time}.",
    "@alreadyServedNote": {"placeholders": {"time": {"type": "String"}}},
    "alreadyServedNoteNoTime": "Nothing to hand over. Kindly let them know it was already collected tonight.",
    "scanNextCard": "Scan next card",
    "history": "History",
    "unknownCardTitle": "Card #{id} isn’t registered",
    "@unknownCardTitle": {"placeholders": {"id": {"type": "int"}}},
    "unknownCardMessage": "Nobody has this card in {region}.",
    "@unknownCardMessage": {"placeholders": {"region": {"type": "String"}}},
    "registerThisCard": "Register this card",
    "scanAgain": "Scan again",
    "invalidCodeTitle": "This code can’t be read",
    "invalidCodeMessage": "It isn’t an Iftar Saem card, or it’s damaged.",
    "notConfirmedYet": "Not confirmed yet",
    "dontHandOverYet": "Don’t hand over until it’s confirmed",
    "notConfirmedExplanation": "The meal isn’t confirmed until the server answers. Retry, and don’t serve twice.",
    "cameraOffTitle": "Camera access is off",
    "cameraOffMessage": "Allow camera access for this app in your phone settings to scan cards. You can still find people without a card.",
    "cameraUnavailableTitle": "Camera unavailable",
    "cameraUnavailableMessage": "The camera could not be started. You can still find people without a card.",
    "sealServe": "Can be served",
    "sealServed": "Already served",
    "sealChecking": "Checking",
    "sealProblem": "Needs attention",
    "sealDone": "Served",
    "findTitle": "Without a card",
    "findSearchHint": "Name, CIN, ID, or phone",
    "findMinChars": "Type 2 letters or a number. Results come from this phone.",
    "findLookUpId": "Look up card #{id}",
    "@findLookUpId": {"placeholders": {"id": {"type": "int"}}},
    "summaryKicker": "Tonight",
    "summaryServedByYou": "iftars served by you",
    "summaryDetail": "{family} family · {single} single · {portions} portions",
    "@summaryDetail": {"placeholders": {"family": {"type": "int"}, "single": {"type": "int"}, "portions": {"type": "int"}}},
    "backToPeople": "Back to people",
    "keepScanning": "Keep scanning",
    "statsTitle": "Statistics",
    "presetTonight": "Tonight",
    "presetWeek": "This week",
    "presetRamadan": "Ramadan",
    "presetCustom": "Custom",
    "ofPeopleServed": "of {count} people served",
    "@ofPeopleServed": {"placeholders": {"count": {"type": "int"}}},
    "peopleServed": "people served",
    "figPortions": "portions",
    "figSingle": "single",
    "figFamily": "family portions",
    "customDates": "Custom dates",
    "fromDate": "From",
    "toDate": "To",
    "apply": "Apply",
    "rangeInvalid": "The start date must be on or before the end date.",
    "byDay": "By day",
    "noStats": "No meals recorded in this period.",
    "profileTitle": "Profile",
    "ramadanKareem": "Ramadan Kareem",
    "noRegion": "No region",
    "settings": "Settings",
    "language": "Language",
    "appearance": "Appearance",
    "appearanceSystem": "System",
    "appearanceDay": "Day",
    "appearanceNight": "Night",
    "dataSection": "Data",
    "exportList": "Export fasting persons list",
    "exportFailed": "Could not create the file.",
    "logout": "Log out",
    "logoutTitle": "Log out?",
    "logoutBody": "You will need to sign in again to scan cards."
  }
  ```

- [ ] **Step 6: Create `lib/l10n/app_fr.arb`** with the same keys. Placeholder metadata isn't needed.
  ```json
  {
    "@@locale": "fr",
    "appTitle": "إفطار صائم",
    "appSubtitle": "Distribution d’iftar pour bénévoles",
    "hadithMeaning": "Celui qui donne l’iftar à un jeûneur partage sa récompense",
    "blessingMeaning": "Qu’Allah l’accepte",
    "signIn": "Se connecter",
    "createVolunteerAccount": "Créer un compte bénévole",
    "welcomeBack": "Bon retour",
    "loginLead": "Connectez-vous pour servir ce soir dans votre région.",
    "registerTitle": "Rejoindre les bénévoles",
    "registerLead": "Chaque bénévole sert une région.",
    "username": "Nom d’utilisateur",
    "password": "Mot de passe",
    "fullName": "Nom",
    "email": "E-mail",
    "region": "Région",
    "chooseRegion": "Choisissez votre région",
    "loadingRegions": "Chargement des régions…",
    "regionsFailed": "Impossible de charger les régions",
    "showPassword": "Afficher le mot de passe",
    "hidePassword": "Masquer le mot de passe",
    "usernameRequired": "Le nom d’utilisateur est obligatoire.",
    "passwordRequired": "Le mot de passe est obligatoire.",
    "nameRequired": "Le nom est obligatoire.",
    "emailRequired": "L’e-mail est obligatoire.",
    "emailInvalid": "Saisissez une adresse e-mail valide.",
    "passwordTooShort": "Au moins 6 caractères.",
    "regionRequired": "La région est obligatoire.",
    "newVolunteerCreateAccount": "Nouveau bénévole ? Créer un compte",
    "haveAccountSignIn": "Déjà bénévole ? Se connecter",
    "accountCreated": "Compte créé. Vous pouvez vous connecter.",
    "signUp": "Créer le compte",
    "errLoginFailed": "Nom d’utilisateur ou mot de passe incorrect.",
    "errAccountDisabled": "Ce compte a été désactivé.",
    "errNetwork": "Pas de connexion internet. Vérifiez votre réseau et réessayez.",
    "errTimeout": "Le serveur met trop de temps à répondre. Réessayez.",
    "errSessionExpired": "Votre session a expiré. Reconnectez-vous.",
    "errForbidden": "Vous n’êtes pas autorisé à faire cette action.",
    "errNotFound": "Introuvable.",
    "errServer": "Un problème est survenu sur le serveur. Réessayez dans un instant.",
    "errUnknown": "Erreur inattendue. Réessayez.",
    "errNoRegion": "Aucune région n’est attribuée à votre compte. Contactez un administrateur.",
    "errUsernameTaken": "Ce nom d’utilisateur ou cet e-mail est déjà utilisé.",
    "titleOffline": "Vous êtes hors ligne",
    "titleSlow": "Le serveur est lent",
    "titleServerError": "Erreur du serveur",
    "titleSignedOut": "Déconnecté",
    "titleNotFound": "Introuvable",
    "titleGenericError": "Un problème est survenu",
    "tryAgain": "Réessayer",
    "retry": "Réessayer",
    "cancel": "Annuler",
    "save": "Enregistrer",
    "edit": "Modifier",
    "back": "Retour",
    "loading": "Chargement des données",
    "increase": "Augmenter",
    "decrease": "Diminuer",
    "navPeople": "Personnes",
    "navAdd": "Ajouter",
    "navStats": "Stats",
    "navProfile": "Profil",
    "navScan": "Scanner une carte",
    "ramadanDay": "Ramadan {day}",
    "peopleTitle": "Personnes inscrites",
    "peopleCount": "{total} inscrits · {served} servis aujourd’hui",
    "searchPeople": "Rechercher par nom, n° ou CIN",
    "clearSearch": "Effacer la recherche",
    "filterAll": "Tous",
    "filterWaiting": "En attente",
    "filterServed": "Servis",
    "noPeopleTitle": "Aucune personne inscrite",
    "noPeopleMessage": "Ajoutez la première personne pour commencer la distribution.",
    "addPerson": "Ajouter une personne",
    "everyoneServed": "Tout le monde a été servi ce soir.",
    "noMatch": "Personne ne correspond à « {query} ».",
    "searchTip": "Recherchez par nom, n°, CIN ou téléphone.",
    "offlineLastList": "Hors ligne. Affichage de la dernière liste chargée.",
    "mealSingleCount": "{count, plural, =1{1 individuel} other{{count} individuels}}",
    "mealFamilyCount": "{count, plural, =1{1 famille} other{{count} familles}}",
    "servedTooltip": "Servi aujourd’hui",
    "notServedTooltip": "Pas encore servi aujourd’hui",
    "portions": "{count, plural, =1{1 portion} other{{count} portions}}",
    "addTitle": "Nouvelle personne",
    "addSubtitle": "Scannez d’abord la carte, elle remplit le n°",
    "editTitle": "Modifier la personne",
    "cardId": "N° de carte",
    "scanCard": "Scanner",
    "cardRead": "Carte lue : n° {id}",
    "cardScanTitle": "Scannez la carte",
    "cardInvalid": "Ce code n’est pas un n° de carte.",
    "idRequired": "Scannez ou saisissez le n° de carte",
    "idInvalid": "Le n° de carte doit être un nombre entier positif",
    "idTaken": "Ce n° de carte est déjà inscrit",
    "firstName": "Prénom",
    "lastName": "Nom",
    "firstNameRequired": "Ajoutez un prénom",
    "lastNameRequired": "Ajoutez un nom",
    "cinLabel": "CIN (8 chiffres)",
    "cinLength": "La CIN compte 8 chiffres",
    "duplicateCin": "Même CIN que {name} (n° {id}). Est-ce la même personne ?",
    "openExistingRecord": "Ouvrir la fiche existante",
    "mealsEachEvening": "Repas chaque soir",
    "singleMeal": "Repas individuel",
    "familyMeal": "Repas famille",
    "handsOverEachEvening": "Remet {count, plural, =1{1 portion} other{{count} portions}} chaque soir",
    "mealsAtLeastOne": "Choisissez au moins un repas",
    "hereNow": "Présent maintenant",
    "hereNowSubtitle": "Remettre le repas de ce soir et l’enregistrer",
    "optionalFields": "Téléphone et notes (facultatif)",
    "phone": "Téléphone",
    "notes": "Notes",
    "saveAndHandOver": "Enregistrer et remettre",
    "saveAndAddAnother": "Enregistrer et ajouter",
    "updatePerson": "Mettre à jour",
    "deletePerson": "Supprimer la personne",
    "deleteTitle": "Supprimer cette personne ?",
    "deleteBody": "{name} sera retiré de la liste des personnes inscrites.",
    "delete": "Supprimer",
    "personSaved": "{name} enregistré.",
    "personSavedHandOver": "{name} enregistré. Remettez {count, plural, =1{1 portion} other{{count} portions}}.",
    "personUpdated": "Personne mise à jour.",
    "personDeleted": "{name} supprimé.",
    "detailsTitle": "Détails de la personne",
    "identity": "Identité",
    "meals": "Repas",
    "identifier": "N° de carte",
    "cinShortLabel": "CIN",
    "lastMeal": "Dernier repas : {date}",
    "mealToday": "Ce soir",
    "confirmMeal": "Confirmer le repas",
    "alreadyServedToday": "Déjà servi aujourd’hui",
    "mealHistory": "Historique des repas ({count})",
    "mealHistoryTitle": "Repas reçus par {name}",
    "noMealsYet": "Aucun repas reçu pour l’instant.",
    "mealConfirmed": "Repas confirmé.",
    "alreadyCollected": "Déjà retiré aujourd’hui.",
    "alreadyCollectedAt": "Déjà retiré aujourd’hui à {time}.",
    "editContact": "Modifier le téléphone et le commentaire",
    "contactTitle": "Téléphone et commentaire",
    "comment": "Commentaire",
    "scanTitle": "Scanner la carte",
    "servedTonight": "{count} servis ce soir",
    "torchOn": "Allumer la lampe",
    "torchOff": "Éteindre la lampe",
    "closeScanner": "Fermer le scanner",
    "scanHint": "Placez la carte dans l’arche",
    "findNoCard": "Trouver une personne sans carte",
    "findNoCardSubtitle": "Par nom, CIN ou téléphone",
    "checkingStatus": "Vérification du statut de ce soir…",
    "lookingUp": "Recherche du n° {id}…",
    "notServedTonight": "Pas encore servi ce soir",
    "handOver": "À remettre",
    "none": "aucun",
    "confirmHandOver": "Confirmer la remise",
    "confirming": "Confirmation…",
    "skip": "Passer",
    "details": "Détails",
    "noCardCheck": "Sans carte : demandez la CIN finissant par {digits}",
    "servedLine": "Servi : {name} · {count, plural, =1{1 portion} other{{count} portions}}",
    "alreadyServedTonight": "Déjà servi ce soir",
    "alreadyServedNote": "Rien à remettre. Indiquez-lui avec douceur que le repas a été retiré à {time}.",
    "alreadyServedNoteNoTime": "Rien à remettre. Indiquez-lui avec douceur que le repas a déjà été retiré ce soir.",
    "scanNextCard": "Carte suivante",
    "history": "Historique",
    "unknownCardTitle": "La carte n° {id} n’est pas inscrite",
    "unknownCardMessage": "Personne n’a cette carte à {region}.",
    "registerThisCard": "Inscrire cette carte",
    "scanAgain": "Scanner à nouveau",
    "invalidCodeTitle": "Ce code est illisible",
    "invalidCodeMessage": "Ce n’est pas une carte Iftar Saem, ou elle est abîmée.",
    "notConfirmedYet": "Pas encore confirmé",
    "dontHandOverYet": "Ne remettez rien avant la confirmation",
    "notConfirmedExplanation": "Le repas n’est confirmé que lorsque le serveur répond. Réessayez, et ne servez pas deux fois.",
    "cameraOffTitle": "L’accès à la caméra est désactivé",
    "cameraOffMessage": "Autorisez l’accès à la caméra dans les réglages du téléphone pour scanner les cartes. Vous pouvez toujours trouver une personne sans carte.",
    "cameraUnavailableTitle": "Caméra indisponible",
    "cameraUnavailableMessage": "La caméra n’a pas pu démarrer. Vous pouvez toujours trouver une personne sans carte.",
    "sealServe": "Peut être servi",
    "sealServed": "Déjà servi",
    "sealChecking": "Vérification",
    "sealProblem": "À vérifier",
    "sealDone": "Servi",
    "findTitle": "Sans carte",
    "findSearchHint": "Nom, CIN, n° ou téléphone",
    "findMinChars": "Tapez 2 lettres ou un numéro. Les résultats viennent du téléphone.",
    "findLookUpId": "Chercher la carte n° {id}",
    "summaryKicker": "Ce soir",
    "summaryServedByYou": "iftars servis par vous",
    "summaryDetail": "{family} famille · {single} individuel · {portions} portions",
    "backToPeople": "Retour à la liste",
    "keepScanning": "Continuer à scanner",
    "statsTitle": "Statistiques",
    "presetTonight": "Ce soir",
    "presetWeek": "Cette semaine",
    "presetRamadan": "Ramadan",
    "presetCustom": "Personnalisé",
    "ofPeopleServed": "sur {count} personnes servies",
    "peopleServed": "personnes servies",
    "figPortions": "portions",
    "figSingle": "individuels",
    "figFamily": "portions famille",
    "customDates": "Dates personnalisées",
    "fromDate": "Du",
    "toDate": "Au",
    "apply": "Appliquer",
    "rangeInvalid": "La date de début doit précéder ou égaler la date de fin.",
    "byDay": "Par jour",
    "noStats": "Aucun repas enregistré sur cette période.",
    "profileTitle": "Profil",
    "ramadanKareem": "Ramadan Kareem",
    "noRegion": "Aucune région",
    "settings": "Réglages",
    "language": "Langue",
    "appearance": "Apparence",
    "appearanceSystem": "Système",
    "appearanceDay": "Jour",
    "appearanceNight": "Nuit",
    "dataSection": "Données",
    "exportList": "Exporter la liste des personnes",
    "exportFailed": "Impossible de créer le fichier.",
    "logout": "Se déconnecter",
    "logoutTitle": "Se déconnecter ?",
    "logoutBody": "Vous devrez vous reconnecter pour scanner les cartes."
  }
  ```

- [ ] **Step 7: Create `lib/l10n/app_ar.arb`.**
  ```json
  {
    "@@locale": "ar",
    "appTitle": "إفطار صائم",
    "appSubtitle": "توزيع الإفطار للمتطوّعين",
    "hadithMeaning": "",
    "blessingMeaning": "",
    "signIn": "تسجيل الدخول",
    "createVolunteerAccount": "إنشاء حساب متطوّع",
    "welcomeBack": "مرحباً بعودتك",
    "loginLead": "سجّل الدخول للتوزيع الليلة في منطقتك.",
    "registerTitle": "انضمّ إلى المتطوّعين",
    "registerLead": "كل متطوّع يوزّع في منطقة واحدة.",
    "username": "اسم المستخدم",
    "password": "كلمة المرور",
    "fullName": "الاسم",
    "email": "البريد الإلكتروني",
    "region": "المنطقة",
    "chooseRegion": "اختر منطقتك",
    "loadingRegions": "جارٍ تحميل المناطق…",
    "regionsFailed": "تعذّر تحميل المناطق",
    "showPassword": "إظهار كلمة المرور",
    "hidePassword": "إخفاء كلمة المرور",
    "usernameRequired": "اسم المستخدم مطلوب.",
    "passwordRequired": "كلمة المرور مطلوبة.",
    "nameRequired": "الاسم مطلوب.",
    "emailRequired": "البريد الإلكتروني مطلوب.",
    "emailInvalid": "أدخل بريداً إلكترونياً صحيحاً.",
    "passwordTooShort": "6 أحرف على الأقل.",
    "regionRequired": "المنطقة مطلوبة.",
    "newVolunteerCreateAccount": "متطوّع جديد؟ أنشئ حساباً",
    "haveAccountSignIn": "لديك حساب؟ سجّل الدخول",
    "accountCreated": "تم إنشاء الحساب. يمكنك تسجيل الدخول الآن.",
    "signUp": "إنشاء الحساب",
    "errLoginFailed": "اسم المستخدم أو كلمة المرور غير صحيحة.",
    "errAccountDisabled": "تم تعطيل هذا الحساب.",
    "errNetwork": "لا يوجد اتصال بالإنترنت. تحقّق من الشبكة وأعد المحاولة.",
    "errTimeout": "الخادم يتأخر في الرد. أعد المحاولة.",
    "errSessionExpired": "انتهت الجلسة. سجّل الدخول من جديد.",
    "errForbidden": "غير مسموح لك بهذا الإجراء.",
    "errNotFound": "غير موجود.",
    "errServer": "حدث خطأ في الخادم. أعد المحاولة بعد قليل.",
    "errUnknown": "خطأ غير متوقع. أعد المحاولة.",
    "errNoRegion": "لا توجد منطقة مرتبطة بحسابك. تواصل مع المشرف.",
    "errUsernameTaken": "اسم المستخدم أو البريد مستعمل من قبل.",
    "titleOffline": "أنت غير متصل",
    "titleSlow": "الخادم بطيء",
    "titleServerError": "خطأ في الخادم",
    "titleSignedOut": "تم تسجيل الخروج",
    "titleNotFound": "غير موجود",
    "titleGenericError": "حدث خطأ",
    "tryAgain": "أعد المحاولة",
    "retry": "إعادة المحاولة",
    "cancel": "إلغاء",
    "save": "حفظ",
    "edit": "تعديل",
    "back": "رجوع",
    "loading": "جارٍ تحميل البيانات",
    "increase": "زيادة",
    "decrease": "إنقاص",
    "navPeople": "الصائمون",
    "navAdd": "إضافة",
    "navStats": "إحصائيات",
    "navProfile": "حسابي",
    "navScan": "مسح بطاقة",
    "ramadanDay": "{day} رمضان",
    "peopleTitle": "الصائمون",
    "peopleCount": "{total} مسجّلاً · {served} استلموا اليوم",
    "searchPeople": "ابحث بالاسم أو الرقم أو ب.ت.و",
    "clearSearch": "مسح البحث",
    "filterAll": "الكل",
    "filterWaiting": "في الانتظار",
    "filterServed": "استلموا",
    "noPeopleTitle": "لا يوجد صائمون بعد",
    "noPeopleMessage": "أضف أول شخص لبدء التوزيع.",
    "addPerson": "إضافة شخص",
    "everyoneServed": "استلم الجميع الليلة.",
    "noMatch": "لا أحد يطابق «{query}».",
    "searchTip": "ابحث بالاسم أو الرقم أو ب.ت.و أو الهاتف.",
    "offlineLastList": "دون اتصال. تُعرض آخر قائمة محمّلة.",
    "mealSingleCount": "{count} فردية",
    "mealFamilyCount": "{count} عائلية",
    "servedTooltip": "استلم اليوم",
    "notServedTooltip": "لم يستلم بعد اليوم",
    "portions": "{count, plural, =1{حصة واحدة} =2{حصتان} few{{count} حصص} other{{count} حصة}}",
    "addTitle": "شخص جديد",
    "addSubtitle": "امسح البطاقة أولاً، فهي تملأ الرقم",
    "editTitle": "تعديل الشخص",
    "cardId": "رقم البطاقة",
    "scanCard": "مسح",
    "cardRead": "تمت قراءة البطاقة: {id}",
    "cardScanTitle": "امسح البطاقة",
    "cardInvalid": "هذا الرمز ليس رقم بطاقة.",
    "idRequired": "امسح رقم البطاقة أو اكتبه",
    "idInvalid": "رقم البطاقة يجب أن يكون عدداً صحيحاً موجباً",
    "idTaken": "رقم البطاقة هذا مسجّل من قبل",
    "firstName": "الاسم",
    "lastName": "اللقب",
    "firstNameRequired": "أضف الاسم",
    "lastNameRequired": "أضف اللقب",
    "cinLabel": "ب.ت.و (8 أرقام)",
    "cinLength": "رقم ب.ت.و يتكوّن من 8 أرقام",
    "duplicateCin": "نفس رقم ب.ت.و لـ {name} (رقم {id}). هل هو الشخص نفسه؟",
    "openExistingRecord": "فتح الملف الموجود",
    "mealsEachEvening": "الوجبات كل مساء",
    "singleMeal": "وجبة فردية",
    "familyMeal": "وجبة عائلية",
    "handsOverEachEvening": "يستلم {count, plural, =1{حصة واحدة} =2{حصتين} few{{count} حصص} other{{count} حصة}} كل مساء",
    "mealsAtLeastOne": "اختر وجبة واحدة على الأقل",
    "hereNow": "حاضر الآن",
    "hereNowSubtitle": "تسليم وجبة الليلة وتسجيلها",
    "optionalFields": "الهاتف والملاحظات (اختياري)",
    "phone": "الهاتف",
    "notes": "ملاحظات",
    "saveAndHandOver": "حفظ وتسليم",
    "saveAndAddAnother": "حفظ وإضافة آخر",
    "updatePerson": "تحديث المعطيات",
    "deletePerson": "حذف الشخص",
    "deleteTitle": "حذف هذا الشخص؟",
    "deleteBody": "سيُحذف {name} من قائمة الصائمين.",
    "delete": "حذف",
    "personSaved": "تم حفظ {name}.",
    "personSavedHandOver": "تم حفظ {name}. سلّمه {count, plural, =1{حصة واحدة} =2{حصتين} few{{count} حصص} other{{count} حصة}}.",
    "personUpdated": "تم تحديث المعطيات.",
    "personDeleted": "تم حذف {name}.",
    "detailsTitle": "تفاصيل الشخص",
    "identity": "الهوية",
    "meals": "الوجبات",
    "identifier": "رقم البطاقة",
    "cinShortLabel": "ب.ت.و",
    "lastMeal": "آخر وجبة: {date}",
    "mealToday": "الليلة",
    "confirmMeal": "تأكيد الوجبة",
    "alreadyServedToday": "استلم اليوم",
    "mealHistory": "سجل الوجبات ({count})",
    "mealHistoryTitle": "الوجبات التي استلمها {name}",
    "noMealsYet": "لا توجد وجبات بعد.",
    "mealConfirmed": "تم تأكيد الوجبة.",
    "alreadyCollected": "استلم اليوم.",
    "alreadyCollectedAt": "استلم اليوم على الساعة {time}.",
    "editContact": "تعديل الهاتف والملاحظة",
    "contactTitle": "الهاتف والملاحظة",
    "comment": "ملاحظة",
    "scanTitle": "مسح البطاقة",
    "servedTonight": "{count} استلموا الليلة",
    "torchOn": "تشغيل المصباح",
    "torchOff": "إطفاء المصباح",
    "closeScanner": "إغلاق الماسح",
    "scanHint": "ضع البطاقة داخل القوس",
    "findNoCard": "البحث عن شخص بلا بطاقة",
    "findNoCardSubtitle": "بالاسم أو ب.ت.و أو الهاتف",
    "checkingStatus": "جارٍ التحقق من حالة الليلة…",
    "lookingUp": "جارٍ البحث عن {id}…",
    "notServedTonight": "لم يستلم الليلة",
    "handOver": "يُسلَّم له",
    "none": "لا شيء",
    "confirmHandOver": "تأكيد التسليم",
    "confirming": "جارٍ التأكيد…",
    "skip": "تخطّي",
    "details": "التفاصيل",
    "noCardCheck": "بلا بطاقة: اطلب رقم ب.ت.و المنتهي بـ {digits}",
    "servedLine": "تم التسليم: {name} · {count, plural, =1{حصة واحدة} =2{حصتان} few{{count} حصص} other{{count} حصة}}",
    "alreadyServedTonight": "استلم الليلة",
    "alreadyServedNote": "لا شيء للتسليم. أخبره بلطف أنه استلم على الساعة {time}.",
    "alreadyServedNoteNoTime": "لا شيء للتسليم. أخبره بلطف أنه استلم الليلة.",
    "scanNextCard": "البطاقة التالية",
    "history": "السجل",
    "unknownCardTitle": "البطاقة رقم {id} غير مسجّلة",
    "unknownCardMessage": "لا أحد يحمل هذه البطاقة في {region}.",
    "registerThisCard": "تسجيل هذه البطاقة",
    "scanAgain": "إعادة المسح",
    "invalidCodeTitle": "تعذّرت قراءة هذا الرمز",
    "invalidCodeMessage": "ليست بطاقة إفطار صائم، أو أنها تالفة.",
    "notConfirmedYet": "لم يُؤكَّد بعد",
    "dontHandOverYet": "لا تسلّم قبل التأكيد",
    "notConfirmedExplanation": "لا تُؤكَّد الوجبة إلا بعد رد الخادم. أعد المحاولة، ولا تسلّم مرتين.",
    "cameraOffTitle": "الوصول إلى الكاميرا معطّل",
    "cameraOffMessage": "اسمح لهذا التطبيق باستعمال الكاميرا من إعدادات الهاتف لمسح البطاقات. يمكنك دائماً البحث عن شخص بلا بطاقة.",
    "cameraUnavailableTitle": "الكاميرا غير متاحة",
    "cameraUnavailableMessage": "تعذّر تشغيل الكاميرا. يمكنك دائماً البحث عن شخص بلا بطاقة.",
    "sealServe": "يمكن التسليم",
    "sealServed": "استلم",
    "sealChecking": "جارٍ التحقق",
    "sealProblem": "يحتاج انتباهاً",
    "sealDone": "تم التسليم",
    "findTitle": "بلا بطاقة",
    "findSearchHint": "الاسم أو ب.ت.و أو الرقم أو الهاتف",
    "findMinChars": "اكتب حرفين أو رقماً. النتائج من هذا الهاتف.",
    "findLookUpId": "البحث عن البطاقة {id}",
    "summaryKicker": "الليلة",
    "summaryServedByYou": "إفطاراً قدّمتَه",
    "summaryDetail": "{family} عائلية · {single} فردية · {portions} حصة",
    "backToPeople": "العودة إلى القائمة",
    "keepScanning": "مواصلة المسح",
    "statsTitle": "الإحصائيات",
    "presetTonight": "الليلة",
    "presetWeek": "هذا الأسبوع",
    "presetRamadan": "رمضان",
    "presetCustom": "مخصّص",
    "ofPeopleServed": "من {count} شخصاً استلموا",
    "peopleServed": "شخصاً استلموا",
    "figPortions": "حصة",
    "figSingle": "فردية",
    "figFamily": "حصص عائلية",
    "customDates": "تواريخ مخصّصة",
    "fromDate": "من",
    "toDate": "إلى",
    "apply": "تطبيق",
    "rangeInvalid": "تاريخ البداية يجب أن يسبق تاريخ النهاية أو يساويه.",
    "byDay": "حسب اليوم",
    "noStats": "لا توجد وجبات مسجّلة في هذه الفترة.",
    "profileTitle": "حسابي",
    "ramadanKareem": "رمضان كريم",
    "noRegion": "بلا منطقة",
    "settings": "الإعدادات",
    "language": "اللغة",
    "appearance": "المظهر",
    "appearanceSystem": "حسب الهاتف",
    "appearanceDay": "نهار",
    "appearanceNight": "ليل",
    "dataSection": "البيانات",
    "exportList": "تصدير قائمة الصائمين",
    "exportFailed": "تعذّر إنشاء الملف.",
    "logout": "تسجيل الخروج",
    "logoutTitle": "تسجيل الخروج؟",
    "logoutBody": "ستحتاج إلى تسجيل الدخول من جديد لمسح البطاقات."
  }
  ```

- [ ] **Step 8: Create `lib/core/settings/locale_resolution.dart`.**
  ```dart
  import 'package:flutter/widgets.dart';

  /// Languages the app ships, in picker order.
  const supportedLanguageCodes = ['ar', 'fr', 'en'];

  /// Native names, never translated.
  const languageNames = {'ar': 'العربية', 'fr': 'Français', 'en': 'English'};

  /// The volunteer's choice wins, then the first supported device language,
  /// then Arabic (spec §1, confirmed at review).
  Locale resolveAppLocale(Locale? chosen, Iterable<Locale>? device) {
    if (chosen != null && supportedLanguageCodes.contains(chosen.languageCode)) {
      return Locale(chosen.languageCode);
    }
    for (final locale in device ?? const <Locale>[]) {
      if (supportedLanguageCodes.contains(locale.languageCode)) {
        return Locale(locale.languageCode);
      }
    }
    return const Locale('ar');
  }
  ```

- [ ] **Step 9: Generate the localizations and wire them in.**
  Run: `fl pub get && fl gen-l10n`
  Expected: `lib/l10n/app_localizations.dart`, `app_localizations_en.dart`, `_fr.dart`, and `_ar.dart` are created, with no errors.

  Replace `lib/app.dart`:
  ```dart
  import 'package:flutter/material.dart';
  import 'package:flutter_riverpod/flutter_riverpod.dart';
  import 'package:intl/intl.dart';

  import 'core/router/app_router.dart';
  import 'core/settings/locale_resolution.dart';
  import 'core/theme/app_theme.dart';
  import 'l10n/app_localizations.dart';

  class IftarApp extends ConsumerWidget {
    const IftarApp({super.key});

    @override
    Widget build(BuildContext context, WidgetRef ref) {
      return MaterialApp.router(
        onGenerateTitle: (context) => AppLocalizations.of(context).appTitle,
        debugShowCheckedModeBanner: false,
        theme: AppTheme.light(),
        darkTheme: AppTheme.dark(),
        themeMode: ThemeMode.light,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        localeListResolutionCallback: (device, _) =>
            resolveAppLocale(null, device),
        builder: (context, child) {
          // Dates follow the UI language; digits stay Western (formatters.dart).
          Intl.defaultLocale = Localizations.localeOf(context).languageCode;
          return child!;
        },
        routerConfig: ref.watch(routerProvider),
      );
    }
  }
  ```

  In `lib/main.dart`, load date symbols before `runApp`:
  ```dart
  import 'package:flutter/material.dart';
  import 'package:flutter/services.dart';
  import 'package:flutter_riverpod/flutter_riverpod.dart';
  import 'package:intl/date_symbol_data_local.dart';

  import 'app.dart';

  Future<void> main() async {
    WidgetsFlutterBinding.ensureInitialized();
    await initializeDateFormatting();
    await SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
    runApp(
      ProviderScope(
        // Riverpod 3 retries failing providers by default; network errors are
        // surfaced to the volunteer with an explicit "Try again" instead.
        retry: (_, _) => null,
        child: const IftarApp(),
      ),
    );
  }
  ```

- [ ] **Step 10: Create the test harness** `test/support/app_harness.dart`:
  ```dart
  import 'package:flutter/material.dart';
  import 'package:flutter_riverpod/flutter_riverpod.dart';
  import 'package:flutter_riverpod/misc.dart' show Override;
  import 'package:iftar_mobile/core/theme/app_theme.dart';
  import 'package:iftar_mobile/l10n/app_localizations.dart';

  /// A themed, localized app around [child] for widget tests.
  Widget localizedApp(
    Widget child, {
    List<Override> overrides = const [],
    Locale locale = const Locale('en'),
    bool night = false,
  }) => ProviderScope(
    overrides: overrides,
    retry: (_, _) => null,
    child: MaterialApp(
      theme: night ? AppTheme.dark() : AppTheme.light(),
      locale: locale,
      supportedLocales: AppLocalizations.supportedLocales,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      home: child,
    ),
  );

  /// Strings for assertions, e.g. `en.signIn`.
  final en = lookupAppLocalizations(const Locale('en'));
  final ar = lookupAppLocalizations(const Locale('ar'));
  ```
  In `test/presentation/widgets_test.dart`:
  - Delete the local `_app` function and its now-unused imports (`flutter_riverpod`, `misc.dart`, `app_theme.dart`).
  - Add `import '../support/app_harness.dart';`.
  - Replace every `_app(` call with `localizedApp(`. The parameters are the same.

- [ ] **Step 11: Run the tests.**
  Run: `fl test`
  Expected: PASS, including the new locale and ARB tests, plus the existing widget tests under the new harness.

- [ ] **Step 12: Commit.**
  ```bash
  git add l10n.yaml pubspec.yaml lib/l10n lib/core/settings/locale_resolution.dart lib/app.dart lib/main.dart test/support/app_harness.dart test/l10n test/core/locale_resolution_test.dart test/presentation/widgets_test.dart
  git commit -m "feat(mobile): en/fr/ar localization with Arabic fallback" -m "Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>" -- l10n.yaml pubspec.yaml lib/l10n lib/core/settings/locale_resolution.dart lib/app.dart lib/main.dart test/support/app_harness.dart test/l10n test/core/locale_resolution_test.dart test/presentation/widgets_test.dart
  ```

---

### Task 4: Persisted language and appearance settings

**Files:**
- Create: `lib/core/settings/settings_storage.dart`, `lib/core/settings/settings_controller.dart`
- Modify: `lib/app.dart`
- Test: `test/core/settings_controller_test.dart`

**Interfaces:**
- Consumes: `resolveAppLocale` from Task 3.
- Produces:
  - `AppSettings({Locale? locale, ThemeMode themeMode})`.
  - `settingsControllerProvider` (an `AsyncNotifierProvider<SettingsController, AppSettings>`), with `setLocale(Locale?)` and `setThemeMode(ThemeMode)`.
  - `settingsStorageProvider`, and `MemorySettingsStorage` for tests.

- [ ] **Step 1: Write the failing test** `test/core/settings_controller_test.dart`:
  ```dart
  import 'package:flutter/material.dart';
  import 'package:flutter_riverpod/flutter_riverpod.dart';
  import 'package:flutter_test/flutter_test.dart';
  import 'package:iftar_mobile/core/settings/settings_controller.dart';
  import 'package:iftar_mobile/core/settings/settings_storage.dart';

  void main() {
    late MemorySettingsStorage storage;

    ProviderContainer container() => ProviderContainer.test(
      overrides: [settingsStorageProvider.overrideWithValue(storage)],
    );

    setUp(() => storage = MemorySettingsStorage());

    test('defaults: device language, system appearance', () async {
      final settings = await container().read(settingsControllerProvider.future);
      expect(settings.locale, isNull);
      expect(settings.themeMode, ThemeMode.system);
    });

    test('choices persist across restarts', () async {
      final first = container();
      await first.read(settingsControllerProvider.future);
      await first.read(settingsControllerProvider.notifier).setLocale(const Locale('fr'));
      await first.read(settingsControllerProvider.notifier).setThemeMode(ThemeMode.dark);

      final restarted = await container().read(settingsControllerProvider.future);
      expect(restarted.locale, const Locale('fr'));
      expect(restarted.themeMode, ThemeMode.dark);
    });

    test('clearing the language returns to the device default', () async {
      final c = container();
      await c.read(settingsControllerProvider.future);
      await c.read(settingsControllerProvider.notifier).setLocale(const Locale('ar'));
      await c.read(settingsControllerProvider.notifier).setLocale(null);
      expect(storage.values.containsKey(SettingsController.localeKey), isFalse);
      expect(c.read(settingsControllerProvider).value!.locale, isNull);
    });
  }
  ```

- [ ] **Step 2: Run it to verify it fails.**
  Run: `fl test test/core/settings_controller_test.dart`
  Expected: FAIL to compile.

- [ ] **Step 3: Create `lib/core/settings/settings_storage.dart`.**
  ```dart
  import 'package:flutter_secure_storage/flutter_secure_storage.dart';

  /// Small key-value store for preferences. Separate keys from the session,
  /// so logging out keeps the volunteer's language.
  abstract interface class SettingsStorage {
    Future<String?> read(String key);

    /// A null [value] deletes the key.
    Future<void> write(String key, String? value);
  }

  class SecureSettingsStorage implements SettingsStorage {
    SecureSettingsStorage([FlutterSecureStorage? storage])
      : _storage = storage ?? const FlutterSecureStorage();

    final FlutterSecureStorage _storage;

    @override
    Future<String?> read(String key) => _storage.read(key: key);

    @override
    Future<void> write(String key, String? value) => value == null
        ? _storage.delete(key: key)
        : _storage.write(key: key, value: value);
  }

  class MemorySettingsStorage implements SettingsStorage {
    final Map<String, String> values = {};

    @override
    Future<String?> read(String key) async => values[key];

    @override
    Future<void> write(String key, String? value) async {
      if (value == null) {
        values.remove(key);
      } else {
        values[key] = value;
      }
    }
  }
  ```

- [ ] **Step 4: Create `lib/core/settings/settings_controller.dart`.**
  ```dart
  import 'package:flutter/material.dart';
  import 'package:flutter_riverpod/flutter_riverpod.dart';

  import 'settings_storage.dart';

  class AppSettings {
    const AppSettings({this.locale, this.themeMode = ThemeMode.system});

    /// Null = follow the device (Arabic if unsupported).
    final Locale? locale;
    final ThemeMode themeMode;

    AppSettings copyWith({Locale? Function()? locale, ThemeMode? themeMode}) =>
        AppSettings(
          locale: locale == null ? this.locale : locale(),
          themeMode: themeMode ?? this.themeMode,
        );
  }

  class SettingsController extends AsyncNotifier<AppSettings> {
    static const localeKey = 'settings.locale';
    static const themeModeKey = 'settings.themeMode';

    SettingsStorage get _storage => ref.read(settingsStorageProvider);

    @override
    Future<AppSettings> build() async {
      final code = await _storage.read(localeKey);
      final mode = await _storage.read(themeModeKey);
      return AppSettings(
        locale: code == null ? null : Locale(code),
        themeMode: ThemeMode.values.firstWhere(
          (m) => m.name == mode,
          orElse: () => ThemeMode.system,
        ),
      );
    }

    AppSettings get _current => state.value ?? const AppSettings();

    Future<void> setLocale(Locale? locale) async {
      state = AsyncData(_current.copyWith(locale: () => locale));
      await _storage.write(localeKey, locale?.languageCode);
    }

    Future<void> setThemeMode(ThemeMode mode) async {
      state = AsyncData(_current.copyWith(themeMode: mode));
      await _storage.write(themeModeKey, mode.name);
    }
  }

  final settingsStorageProvider = Provider<SettingsStorage>(
    (_) => SecureSettingsStorage(),
  );

  final settingsControllerProvider =
      AsyncNotifierProvider<SettingsController, AppSettings>(
        SettingsController.new,
      );
  ```

- [ ] **Step 5: Apply the settings in `lib/app.dart`.** Add `import 'core/settings/settings_controller.dart';`. At the top of `build`, add:
  ```dart
  final settings =
      ref.watch(settingsControllerProvider).value ?? const AppSettings();
  ```
  Then:
  - Replace `themeMode: ThemeMode.light` with `themeMode: settings.themeMode`.
  - Add `locale: settings.locale` before `localizationsDelegates`.

- [ ] **Step 6: Run the tests.**
  Run: `fl test`
  Expected: PASS.

- [ ] **Step 7: Commit.**
  ```bash
  git add lib/core/settings lib/app.dart test/core/settings_controller_test.dart
  git commit -m "feat(mobile): persist language and appearance settings" -m "Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>" -- lib/core/settings lib/app.dart test/core/settings_controller_test.dart
  ```

---

### Task 5: Text utilities (digits, bidi, masking, Ramadan day, typography)

**Files:**
- Modify: `lib/core/utils/formatters.dart`, `lib/core/config/app_config.dart`, `lib/features/statistics/domain/statistics.dart`, `config/development.json`
- Create: `lib/core/utils/masking.dart`, `lib/core/utils/ramadan.dart`, `lib/core/utils/typography.dart`
- Test: `test/core/text_utils_test.dart`; add one test to `test/domain/domain_rules_test.dart`

**Interfaces:**
- Produces:
  - `latinDigits(String) → String`.
  - `formatTime(DateTime) → 'HH:mm'`, always Western digits.
  - `formatDate(DateTime)`, localized via `Intl.defaultLocale`, Western digits.
  - `ltr(String) → String` (LRI…PDI), and the existing `isolate()` (FSI…PDI).
  - `maskCin(String?) → String?` (e.g. `'••••• 812'`) and `cinLastDigits(String?) → String?`.
  - `ramadanDay(DateTime? start, DateTime now) → int?` (1–30).
  - `AppConfig.ramadanStart` (`DateTime?`, from `--dart-define RAMADAN_START`).
  - `labelTracking(BuildContext, [double tracking = 1.2]) → double`, which is 0 for Arabic.
  - `DailyStatistics.date` (`DateTime?`, parsed from the server label).

- [ ] **Step 1: Write the failing tests** `test/core/text_utils_test.dart`:
  ```dart
  import 'package:flutter_test/flutter_test.dart';
  import 'package:iftar_mobile/core/utils/formatters.dart';
  import 'package:iftar_mobile/core/utils/masking.dart';
  import 'package:iftar_mobile/core/utils/ramadan.dart';
  import 'package:intl/date_symbol_data_local.dart';
  import 'package:intl/intl.dart';

  void main() {
    setUpAll(initializeDateFormatting);
    tearDown(() => Intl.defaultLocale = null);

    test('Arabic-Indic and Persian digits become Western', () {
      expect(latinDigits('١٢:٣٠'), '12:30');
      expect(latinDigits('۰۹ مارس'), '09 مارس');
      expect(latinDigits('Mar 5, 2025'), 'Mar 5, 2025');
    });

    test('times are HH:mm with Western digits in every language', () {
      Intl.defaultLocale = 'ar';
      expect(formatTime(DateTime(2025, 3, 5, 7, 5)), '07:05');
    });

    test('dates never contain Arabic-Indic digits', () {
      for (final locale in ['ar', 'fr', 'en']) {
        Intl.defaultLocale = locale;
        final text = formatDate(DateTime(2025, 3, 5));
        expect(RegExp('[٠-٩۰-۹]').hasMatch(text), isFalse, reason: '$locale: $text');
        expect(text, contains('2025'), reason: locale);
      }
    });

    test('ltr and isolate wrap text in Unicode isolates', () {
      expect(ltr('87 / 214'), '⁦87 / 214⁩');
      expect(isolate('نجوى'), '⁨نجوى⁩');
    });

    test('CIN is masked to its last three digits', () {
      expect(maskCin('08123812'), '••••• 812');
      expect(cinLastDigits('08123812'), '812');
      expect(maskCin(null), isNull);
      expect(maskCin('12'), isNull);
    });

    test('Ramadan day counts from the configured first day', () {
      final start = DateTime(2027, 2, 8);
      expect(ramadanDay(start, DateTime(2027, 2, 8, 18)), 1);
      expect(ramadanDay(start, DateTime(2027, 2, 21, 23, 59)), 14);
      expect(ramadanDay(start, DateTime(2027, 3, 9)), 30);
      expect(ramadanDay(start, DateTime(2027, 3, 10)), isNull);
      expect(ramadanDay(start, DateTime(2027, 2, 7)), isNull);
      expect(ramadanDay(null, DateTime(2027, 2, 9)), isNull);
    });
  }
  ```
  Append to `test/domain/domain_rules_test.dart`, inside the `StatsPeriod` group:
  ```dart
  test('day labels parse to dates; unparseable labels stay null', () {
    final ok = DailyStatistics.fromJson({'date': 'Mon Mar 03 2025', 'statistics': {}});
    expect(ok.date, DateTime(2025, 3, 3));
    final odd = DailyStatistics.fromJson({'date': '2025-W10', 'statistics': {}});
    expect(odd.date, isNull);
    expect(odd.label, '2025-W10');
  });
  ```

- [ ] **Step 2: Run them to verify they fail.**
  Run: `fl test test/core/text_utils_test.dart test/domain/domain_rules_test.dart`
  Expected: FAIL to compile.

- [ ] **Step 3: Update `lib/core/utils/formatters.dart`.** Replace the whole file:
  ```dart
  import 'package:intl/intl.dart';

  /// Arabic-Indic (٠–٩) and Persian (۰–۹) digits → 0–9. The app shows
  /// Western digits in every language (spec §5).
  String latinDigits(String text) {
    final out = StringBuffer();
    for (final rune in text.runes) {
      if (rune >= 0x0660 && rune <= 0x0669) {
        out.writeCharCode(0x30 + rune - 0x0660);
      } else if (rune >= 0x06F0 && rune <= 0x06F9) {
        out.writeCharCode(0x30 + rune - 0x06F0);
      } else {
        out.writeCharCode(rune);
      }
    }
    return out.toString();
  }

  String _two(int n) => n.toString().padLeft(2, '0');

  /// Localized "Mar 3, 2025" (follows `Intl.defaultLocale`).
  String formatDate(DateTime date) =>
      latinDigits(DateFormat.yMMMd().format(date));

  /// "18:42", always 24-hour with Western digits.
  String formatTime(DateTime date) => '${_two(date.hour)}:${_two(date.minute)}';

  String formatDateTime(DateTime date) =>
      '${formatDate(date)} · ${formatTime(date)}';

  /// `YYYY-MM-DD`, the day format sent to the statistics API.
  String formatDayKey(DateTime date) =>
      '${date.year.toString().padLeft(4, '0')}-'
      '${_two(date.month)}-'
      '${_two(date.day)}';

  DateTime dateOnly(DateTime date) => DateTime(date.year, date.month, date.day);

  bool isSameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;

  /// Wraps user text (often Arabic names) in a first-strong isolate so it
  /// doesn't reorder the surrounding sentence.
  String isolate(String text) => '⁨$text⁩';

  /// Wraps IDs, times, CIN fragments and counts in a left-to-right isolate,
  /// so "87 / 214" or "#0142" never flip inside Arabic text.
  String ltr(String text) => '⁦$text⁩';
  ```

- [ ] **Step 4: Create `lib/core/utils/masking.dart`.**
  ```dart
  /// "••••• 812": enough to check a card holder, not enough to copy the CIN
  /// (spec §4.6). Screens used in public show only this.
  String? maskCin(String? cin) {
    final digits = cinLastDigits(cin);
    return digits == null ? null : '••••• $digits';
  }

  String? cinLastDigits(String? cin) {
    final value = cin?.trim();
    if (value == null || value.length < 3) return null;
    return value.substring(value.length - 3);
  }
  ```

- [ ] **Step 5: Create `lib/core/utils/ramadan.dart`.**
  ```dart
  /// Day of Ramadan (1–30) for [now], counted from the season's official first
  /// day ([start], set at build time). Null when not configured or out of range.
  int? ramadanDay(DateTime? start, DateTime now) {
    if (start == null) return null;
    // UTC dates avoid daylight-saving off-by-one in `inDays`.
    final first = DateTime.utc(start.year, start.month, start.day);
    final today = DateTime.utc(now.year, now.month, now.day);
    final day = today.difference(first).inDays + 1;
    return day >= 1 && day <= 30 ? day : null;
  }
  ```

- [ ] **Step 6: Create `lib/core/utils/typography.dart`.**
  ```dart
  import 'package:flutter/widgets.dart';

  /// Letter-spacing for small labels; 0 for Arabic, whose joins break
  /// when letters are spaced (spec §3.2).
  double labelTracking(BuildContext context, [double tracking = 1.2]) =>
      Localizations.localeOf(context).languageCode == 'ar' ? 0 : tracking;
  ```

- [ ] **Step 7: Add `ramadanStart` to `lib/core/config/app_config.dart`.** Replace the class:
  ```dart
  /// Build-time configuration, injected with
  /// `--dart-define-from-file=config/<env>.json` (see `config/`).
  class AppConfig {
    const AppConfig({
      required this.apiBaseUrl,
      required this.environment,
      this.ramadanStart,
    });

    factory AppConfig.fromEnvironment() {
      const ramadan = String.fromEnvironment('RAMADAN_START');
      return AppConfig(
        apiBaseUrl: const String.fromEnvironment(
          'API_BASE_URL',
          defaultValue: 'https://vps-ca2a6790.vps.ovh.net/api/v1',
        ),
        environment: const String.fromEnvironment(
          'APP_ENV',
          defaultValue: 'production',
        ),
        ramadanStart: ramadan.isEmpty ? null : DateTime.tryParse(ramadan),
      );
    }

    /// Base URL including the `/api/v1` prefix, without a trailing slash.
    final String apiBaseUrl;

    /// `development` or `production`.
    final String environment;

    /// Official first day of this season's Ramadan (release checklist).
    final DateTime? ramadanStart;

    bool get isProduction => environment == 'production';
  }
  ```
  In `config/development.json`, add `"RAMADAN_START": "2027-02-08"`. That's a development estimate. Production gets the official date at release.

- [ ] **Step 8: Add `date` to `DailyStatistics`** in `lib/features/statistics/domain/statistics.dart`. Add `import 'package:intl/intl.dart';`, then inside the class, after `label`:
  ```dart
  /// The label as a date ("Mon Mar 03 2025"), or null if the server sent
  /// something else. Screens fall back to [label].
  DateTime? get date =>
      DateFormat('EEE MMM dd yyyy', 'en_US').tryParse(label);
  ```

- [ ] **Step 9: Run the tests.**
  Run: `fl test`
  Expected: PASS.

- [ ] **Step 10: Commit.**
  ```bash
  git add lib/core/utils lib/core/config/app_config.dart lib/features/statistics/domain/statistics.dart config/development.json test/core/text_utils_test.dart test/domain/domain_rules_test.dart
  git commit -m "feat(mobile): western digits, bidi isolates, CIN masking, Ramadan day" -m "Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>" -- lib/core/utils lib/core/config/app_config.dart lib/features/statistics/domain/statistics.dart config/development.json test/core/text_utils_test.dart test/domain/domain_rules_test.dart
  ```

---

### Task 6: Ornaments (8-point star, sky, arch window, seal)

**Files:**
- Create: `lib/core/widgets/khatam.dart`, `lib/core/widgets/arch_window.dart`, `lib/core/widgets/seal.dart`
- Rewrite: `lib/core/widgets/night_sky.dart` (adds `SkyBand`; keeps the `NightSky` API and adds `dusk` and `pattern`)
- Test: `test/presentation/ornaments_test.dart`

**Interfaces:**
- Produces:
  - `khatamPath(Offset center, double radius) → Path` (16 vertices).
  - `KhatamPatternPainter({Color color, double opacity, double tile})`.
  - `NightSky({child, showMoon = true, starCount = 28, borderRadius, dusk = false, pattern = false})`.
  - `SkyBand({required Widget child, EdgeInsetsGeometry padding})`.
  - `ArchWindow({required Widget child, double width = 212, double height = 282})`.
  - `enum SealKind { serve, served, problem, checking, done }`.
  - `Seal(SealKind kind, {required String semanticLabel, double size = 44})`.

- [ ] **Step 1: Write the failing test** `test/presentation/ornaments_test.dart`:
  ```dart
  import 'package:flutter/material.dart';
  import 'package:flutter_test/flutter_test.dart';
  import 'package:iftar_mobile/core/widgets/arch_window.dart';
  import 'package:iftar_mobile/core/widgets/khatam.dart';
  import 'package:iftar_mobile/core/widgets/night_sky.dart';
  import 'package:iftar_mobile/core/widgets/seal.dart';

  import '../support/app_harness.dart';

  void main() {
    test('the 8-point star fits inside its radius', () {
      final bounds = khatamPath(const Offset(50, 50), 20).getBounds();
      expect(bounds.width, closeTo(40, 0.01));
      expect(bounds.height, closeTo(40, 0.01));
      expect(bounds.center, const Offset(50, 50));
    });

    testWidgets('seals are labelled for screen readers', (tester) async {
      await tester.pumpWidget(localizedApp(const Scaffold(
        body: Row(children: [
          Seal(SealKind.serve, semanticLabel: 'Can be served'),
          Seal(SealKind.served, semanticLabel: 'Already served'),
          Seal(SealKind.problem, semanticLabel: 'Needs attention'),
          Seal(SealKind.done, semanticLabel: 'Served'),
          Seal(SealKind.checking, semanticLabel: 'Checking'),
        ]),
      )));
      await tester.pump(const Duration(milliseconds: 300)); // pulse is looping
      for (final label in ['Can be served', 'Already served', 'Needs attention', 'Served', 'Checking']) {
        expect(find.bySemanticsLabel(label), findsOneWidget);
      }
      expect(tester.takeException(), isNull);
    });

    testWidgets('sky band, night sky and arch window render their child', (tester) async {
      await tester.pumpWidget(localizedApp(const Scaffold(
        body: Column(children: [
          SkyBand(child: Text('band')),
          SizedBox(height: 120, child: NightSky(dusk: true, pattern: true, child: Text('sky'))),
          ArchWindow(child: Text('arch')),
        ]),
      )));
      expect(find.text('band'), findsOneWidget);
      expect(find.text('sky'), findsOneWidget);
      expect(find.text('arch'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  }
  ```

- [ ] **Step 2: Run it to verify it fails.**
  Run: `fl test test/presentation/ornaments_test.dart`
  Expected: FAIL to compile.

- [ ] **Step 3: Create `lib/core/widgets/khatam.dart`.**
  ```dart
  import 'dart:math' as math;

  import 'package:flutter/widgets.dart';

  import '../theme/app_colors.dart';

  /// Outline of the 8-point star (two overlapping squares, the khatam /
  /// Rub el Hizb motif): 16 vertices, outer points on [radius].
  Path khatamPath(Offset center, double radius) {
    // Inner vertices sit where the squares' edges cross: r·cos45°/cos22.5°.
    final inner = radius * 0.7654;
    final path = Path();
    for (var i = 0; i < 16; i++) {
      final angle = -math.pi / 2 + i * math.pi / 8;
      final r = i.isEven ? radius : inner;
      final point = Offset(
        center.dx + r * math.cos(angle),
        center.dy + r * math.sin(angle),
      );
      if (i == 0) {
        path.moveTo(point.dx, point.dy);
      } else {
        path.lineTo(point.dx, point.dy);
      }
    }
    return path..close();
  }

  /// Tiled star pattern, faint gold on sky surfaces (spec §3.3).
  class KhatamPatternPainter extends CustomPainter {
    const KhatamPatternPainter({
      this.color = AppPalette.gold,
      this.opacity = 0.17,
      this.tile = 44,
    });

    final Color color;
    final double opacity;
    final double tile;

    @override
    void paint(Canvas canvas, Size size) {
      final paint = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1
        ..color = color.withValues(alpha: opacity);
      for (var y = tile / 2; y < size.height + tile; y += tile) {
        for (var x = tile / 2; x < size.width + tile; x += tile) {
          final c = Offset(x, y);
          canvas
            ..drawPath(khatamPath(c, tile * 0.32), paint)
            ..drawCircle(c, 3, paint);
        }
      }
    }

    @override
    bool shouldRepaint(covariant KhatamPatternPainter old) =>
        old.color != color || old.opacity != opacity || old.tile != tile;
  }
  ```

- [ ] **Step 4: Rewrite `lib/core/widgets/night_sky.dart`.**
  ```dart
  import 'dart:math' as math;

  import 'package:flutter/material.dart';

  import '../theme/app_colors.dart';
  import 'khatam.dart';

  /// Full sky: indigo gradient, optional dusk glow at the horizon, stars,
  /// crescent and pattern. Used on Welcome, Login, Splash and Summary.
  class NightSky extends StatelessWidget {
    const NightSky({
      super.key,
      this.child,
      this.showMoon = true,
      this.starCount = 28,
      this.borderRadius,
      this.dusk = false,
      this.pattern = false,
    });

    final Widget? child;
    final bool showMoon;
    final int starCount;
    final BorderRadius? borderRadius;
    final bool dusk;
    final bool pattern;

    @override
    Widget build(BuildContext context) {
      return ClipRRect(
        borderRadius: borderRadius ?? BorderRadius.zero,
        child: DecoratedBox(
          decoration: const BoxDecoration(gradient: AppPalette.skyGradient),
          child: CustomPaint(
            painter: _SkyPainter(
              showMoon: showMoon,
              starCount: starCount,
              dusk: dusk,
              pattern: pattern,
            ),
            child: child,
          ),
        ),
      );
    }
  }

  /// Header band at the top of the main tabs: night gradient with the star
  /// pattern, safe-area aware, ivory text and icons.
  class SkyBand extends StatelessWidget {
    const SkyBand({
      super.key,
      required this.child,
      this.padding = const EdgeInsetsDirectional.fromSTEB(20, 4, 20, 18),
    });

    final Widget child;
    final EdgeInsetsGeometry padding;

    @override
    Widget build(BuildContext context) {
      return DecoratedBox(
        decoration: const BoxDecoration(gradient: AppPalette.bandGradient),
        child: CustomPaint(
          painter: const KhatamPatternPainter(),
          child: SafeArea(
            bottom: false,
            child: Padding(
              padding: padding,
              child: DefaultTextStyle.merge(
                style: const TextStyle(color: AppPalette.onSky),
                child: IconTheme.merge(
                  data: const IconThemeData(color: AppPalette.onSky),
                  child: child,
                ),
              ),
            ),
          ),
        ),
      );
    }
  }

  class _SkyPainter extends CustomPainter {
    _SkyPainter({
      required this.showMoon,
      required this.starCount,
      required this.dusk,
      required this.pattern,
    });

    final bool showMoon;
    final int starCount;
    final bool dusk;
    final bool pattern;

    @override
    void paint(Canvas canvas, Size size) {
      final rect = Offset.zero & size;
      if (dusk) {
        canvas.drawRect(
          rect,
          Paint()
            ..shader = RadialGradient(
              center: const Alignment(0, 1.25),
              radius: 0.95,
              colors: [
                AppPalette.duskGlow.withValues(alpha: 0.42),
                AppPalette.duskGlow.withValues(alpha: 0),
              ],
            ).createShader(rect),
        );
      }
      if (pattern) const KhatamPatternPainter().paint(canvas, size);

      // Deterministic "random" so the sky doesn't jump between rebuilds.
      final random = math.Random(1447);
      final star = Paint();
      for (var i = 0; i < starCount; i++) {
        final dx = random.nextDouble() * size.width;
        final dy = random.nextDouble() * size.height * 0.6;
        final r = 0.6 + random.nextDouble() * 1.2;
        star.color = AppPalette.onSky.withValues(
          alpha: 0.3 + random.nextDouble() * 0.5,
        );
        canvas.drawCircle(Offset(dx, dy), r, star);
      }

      if (showMoon) {
        final radius = math.min(size.width, size.height) * 0.08;
        final center = Offset(size.width * 0.84, size.height * 0.14);
        canvas.drawCircle(
          center,
          radius * 1.4,
          Paint()
            ..color = AppPalette.gold.withValues(alpha: 0.18)
            ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 14),
        );
        final moon = Path()
          ..addOval(Rect.fromCircle(center: center, radius: radius));
        final bite = Path()
          ..addOval(
            Rect.fromCircle(
              center: center.translate(radius * 0.45, -radius * 0.25),
              radius: radius * 0.88,
            ),
          );
        canvas.drawPath(
          Path.combine(PathOperation.difference, moon, bite),
          Paint()..color = AppPalette.gold,
        );
      }
    }

    @override
    bool shouldRepaint(covariant _SkyPainter old) =>
        old.showMoon != showMoon ||
        old.starCount != starCount ||
        old.dusk != dusk ||
        old.pattern != pattern;
  }
  ```

- [ ] **Step 5: Create `lib/core/widgets/arch_window.dart`.**
  ```dart
  import 'package:flutter/material.dart';

  import '../theme/app_colors.dart';
  import 'khatam.dart';

  /// Round-topped "Tunisian door" window with a double gold hairline and the
  /// star pattern inside (Welcome, spec §4.1).
  class ArchWindow extends StatelessWidget {
    const ArchWindow({
      super.key,
      required this.child,
      this.width = 212,
      this.height = 282,
    });

    final Widget child;
    final double width;
    final double height;

    @override
    Widget build(BuildContext context) {
      final outer = BorderRadius.vertical(
        top: Radius.circular(width / 2),
        bottom: const Radius.circular(10),
      );
      final inner = BorderRadius.vertical(
        top: Radius.circular(width / 2 - 7),
        bottom: const Radius.circular(6),
      );
      return SizedBox(
        width: width,
        height: height,
        child: DecoratedBox(
          decoration: ShapeDecoration(
            shape: RoundedRectangleBorder(
              borderRadius: outer,
              side: BorderSide(color: AppPalette.gold.withValues(alpha: 0.55)),
            ),
          ),
          child: Padding(
            padding: const EdgeInsets.all(7),
            child: DecoratedBox(
              decoration: ShapeDecoration(
                shape: RoundedRectangleBorder(
                  borderRadius: inner,
                  side: BorderSide(
                    color: AppPalette.gold.withValues(alpha: 0.18),
                  ),
                ),
              ),
              child: ClipRRect(
                borderRadius: inner,
                child: CustomPaint(
                  painter: const KhatamPatternPainter(opacity: 0.12),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 14),
                    child: Center(child: child),
                  ),
                ),
              ),
            ),
          ),
        ),
      );
    }
  }
  ```

- [ ] **Step 6: Create `lib/core/widgets/seal.dart`.**
  ```dart
  import 'package:flutter/material.dart';

  import '../theme/app_colors.dart';
  import 'khatam.dart';

  enum SealKind { serve, served, problem, checking, done }

  /// The 8-point star that carries a scan verdict, readable before any word
  /// (spec §3.3).
  class Seal extends StatelessWidget {
    const Seal(
      this.kind, {
      super.key,
      required this.semanticLabel,
      this.size = 44,
    });

    final SealKind kind;
    final String semanticLabel;
    final double size;

    @override
    Widget build(BuildContext context) {
      final (Color fill, IconData? glyph, Color? glyphColor) = switch (kind) {
        SealKind.serve => (Colors.white, Icons.check_rounded, AppPalette.serveBand),
        SealKind.served => (Colors.white, Icons.schedule_rounded, AppPalette.pausedBand),
        SealKind.problem => (AppPalette.gold, Icons.priority_high_rounded, AppPalette.sky),
        SealKind.done => (AppPalette.gold, Icons.check_rounded, AppPalette.doneBand),
        SealKind.checking => (AppPalette.gold, null, null),
      };
      final star = CustomPaint(
        painter: _StarPainter(color: fill, outline: kind == SealKind.checking),
        child: SizedBox.square(
          dimension: size,
          child: glyph == null
              ? null
              : Center(child: Icon(glyph, size: size * 0.42, color: glyphColor)),
        ),
      );
      return Semantics(
        label: semanticLabel,
        image: true,
        excludeSemantics: true,
        child: kind == SealKind.checking ? _Pulse(child: star) : star,
      );
    }
  }

  class _StarPainter extends CustomPainter {
    const _StarPainter({required this.color, required this.outline});

    final Color color;
    final bool outline;

    @override
    void paint(Canvas canvas, Size size) {
      canvas.drawPath(
        khatamPath(size.center(Offset.zero), size.shortestSide / 2 * 0.98),
        Paint()
          ..color = color
          ..style = outline ? PaintingStyle.stroke : PaintingStyle.fill
          ..strokeWidth = 1.8,
      );
    }

    @override
    bool shouldRepaint(covariant _StarPainter old) =>
        old.color != color || old.outline != outline;
  }

  /// Slow fade while the server is checking; still when animations are off.
  class _Pulse extends StatefulWidget {
    const _Pulse({required this.child});

    final Widget child;

    @override
    State<_Pulse> createState() => _PulseState();
  }

  class _PulseState extends State<_Pulse> with SingleTickerProviderStateMixin {
    late final AnimationController _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    );

    @override
    void didChangeDependencies() {
      super.didChangeDependencies();
      if (MediaQuery.disableAnimationsOf(context)) {
        _controller.stop();
      } else if (!_controller.isAnimating) {
        _controller.repeat(reverse: true);
      }
    }

    @override
    void dispose() {
      _controller.dispose();
      super.dispose();
    }

    @override
    Widget build(BuildContext context) => FadeTransition(
      opacity: Tween<double>(begin: 1, end: 0.45).animate(_controller),
      child: widget.child,
    );
  }
  ```

- [ ] **Step 7: Run the tests.**
  Run: `fl test`
  Expected: PASS. Existing users of `NightSky` (profile, people header, statistics, auth) compile, because the old constructor parameters are unchanged.

- [ ] **Step 8: Commit.**
  ```bash
  git add lib/core/widgets/khatam.dart lib/core/widgets/night_sky.dart lib/core/widgets/arch_window.dart lib/core/widgets/seal.dart test/presentation/ornaments_test.dart
  git commit -m "feat(mobile): khatam pattern, sky band, arch window and verdict seal" -m "Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>" -- lib/core/widgets/khatam.dart lib/core/widgets/night_sky.dart lib/core/widgets/arch_window.dart lib/core/widgets/seal.dart test/presentation/ornaments_test.dart
  ```

---

### Task 7: Data widgets, localized failures, state views

**Files:**
- Modify: `lib/core/network/app_failure.dart`, `lib/features/auth/data/auth_repository.dart`, `lib/features/auth/presentation/auth_controller.dart`, `lib/features/auth/presentation/login_page.dart` (one line)
- Create: `lib/core/network/failure_text.dart`, `lib/core/widgets/status_chip.dart`, `lib/core/widgets/hand_over_tiles.dart`, `lib/core/widgets/meal_stepper.dart`
- Rewrite: `lib/core/widgets/state_views.dart`
- Test: `test/core/failure_text_test.dart`, `test/presentation/data_widgets_test.dart`

**Interfaces:**
- Consumes: `AppLocalizations` (Task 3), `context.colors` (Task 2), and `ltr` / `isolate` / `formatTime` (Task 5).
- Produces:
  - `failureText(AppLocalizations, AppFailure) → String` and `failureTitle(AppLocalizations, AppFailure) → String`.
  - The failure classes `InvalidCredentialsFailure` and `AccountDisabledFailure` (subclasses of `UnauthorizedFailure`).
  - `ConflictFailure.usernameTaken`, `AppStateFailure.noRegion` (code constants), and `AppStateFailure.code`.
  - `AuthController.lastSignOutFailure` (`AppFailure?`), which replaces `lastSignOutReason`.
  - `MealStatusWords.taken` / `.notTaken`.
  - `StatusChip({required FastingPerson person, DateTime? now})`.
  - `HandOverTiles({required FastingPerson person})`.
  - `MealStepper({required String label, required String caption, required int value, required ValueChanged<int> onChanged, int min = 0, int max = 9})`.
  - Localized `LoadingView`, `ErrorView`, `EmptyView`, and `showAppSnackBar`.

- [ ] **Step 1: Write the failing tests.**

  `test/core/failure_text_test.dart`:
  ```dart
  import 'package:flutter_test/flutter_test.dart';
  import 'package:iftar_mobile/core/network/app_failure.dart';
  import 'package:iftar_mobile/core/network/failure_text.dart';

  import '../support/app_harness.dart';

  void main() {
    final cases = <(AppFailure, String)>[
      (const InvalidCredentialsFailure(), en.errLoginFailed),
      (const AccountDisabledFailure(), en.errAccountDisabled),
      (const UnauthorizedFailure(), en.errSessionExpired),
      (const NetworkFailure(), en.errNetwork),
      (const TimeoutFailure(), en.errTimeout),
      (const ForbiddenFailure(), en.errForbidden),
      (const NotFoundFailure(), en.errNotFound),
      (const MealAlreadyTakenFailure(), en.alreadyCollected),
      (const ConflictFailure('x', code: ConflictFailure.usernameTaken), en.errUsernameTaken),
      (const ConflictFailure('Card 12 exists'), 'Card 12 exists'),
      (const ValidationFailure('Phone must be 8 digits'), 'Phone must be 8 digits'),
      (const ServerFailure(statusCode: 500), en.errServer),
      (const AppStateFailure('x', code: AppStateFailure.noRegion), en.errNoRegion),
      (const AppStateFailure('Something specific'), 'Something specific'),
      (const UnknownFailure(), en.errUnknown),
    ];

    for (final (failure, expected) in cases) {
      test('${failure.runtimeType} → "$expected"', () {
        expect(failureText(en, failure), expected);
      });
    }

    test('Arabic text is used in Arabic', () {
      expect(failureText(ar, const NetworkFailure()), ar.errNetwork);
      expect(ar.errNetwork, isNot(en.errNetwork));
    });

    test('titles for full-screen errors', () {
      expect(failureTitle(en, const NetworkFailure()), en.titleOffline);
      expect(failureTitle(en, const ForbiddenFailure()), en.titleGenericError);
    });
  }
  ```

  `test/presentation/data_widgets_test.dart`:
  ```dart
  import 'package:flutter/material.dart';
  import 'package:flutter_test/flutter_test.dart';
  import 'package:iftar_mobile/core/network/app_failure.dart';
  import 'package:iftar_mobile/core/utils/formatters.dart';
  import 'package:iftar_mobile/core/widgets/hand_over_tiles.dart';
  import 'package:iftar_mobile/core/widgets/meal_stepper.dart';
  import 'package:iftar_mobile/core/widgets/state_views.dart';
  import 'package:iftar_mobile/core/widgets/status_chip.dart';
  import 'package:iftar_mobile/features/people/domain/fasting_person.dart';

  import '../support/app_harness.dart';
  import '../support/fakes.dart';

  void main() {
    testWidgets('status chip pairs an icon with the Tunisian word and time', (tester) async {
      await tester.pumpWidget(localizedApp(Scaffold(
        body: Column(children: [
          StatusChip(person: person(1), now: testNow),
          StatusChip(person: person(2, takenToday: true), now: testNow),
        ]),
      )));
      expect(find.text(isolate(MealStatusWords.notTaken)), findsOneWidget);
      // person(takenToday) was served 20 minutes before 18:30.
      expect(find.text('${isolate(MealStatusWords.taken)} ${ltr('18:10')}'), findsOneWidget);
      expect(find.byIcon(Icons.radio_button_unchecked_rounded), findsOneWidget);
      expect(find.byIcon(Icons.check_rounded), findsOneWidget);
    });

    testWidgets('hand-over tiles show counts and portions', (tester) async {
      // person(): 2 single meals, 1 family meal.
      await tester.pumpWidget(localizedApp(Scaffold(body: HandOverTiles(person: person(1)))));
      expect(find.text(ltr('1')), findsOneWidget);
      expect(find.text(ltr('2')), findsOneWidget);
      expect(find.text(en.portions(4)), findsOneWidget);
      expect(find.text(en.portions(2)), findsOneWidget);
    });

    testWidgets('a person with no meals set shows "none" twice', (tester) async {
      const nobody = FastingPerson(
        id: 9,
        firstName: 'A',
        lastName: 'B',
        singleMeal: 0,
        familyMeal: 0,
      );
      await tester.pumpWidget(localizedApp(const Scaffold(body: HandOverTiles(person: nobody))));
      expect(find.text(en.none), findsNWidgets(2));
      expect(tester.takeException(), isNull);
    });

    testWidgets('meal stepper stays within bounds', (tester) async {
      var value = 9;
      await tester.pumpWidget(localizedApp(StatefulBuilder(
        builder: (context, setState) => Scaffold(
          body: MealStepper(
            label: 'Single meal',
            caption: '1 portion',
            value: value,
            onChanged: (v) => setState(() => value = v),
          ),
        ),
      )));
      await tester.tap(find.byTooltip(en.decrease));
      await tester.pump();
      expect(value, 8);
      await tester.tap(find.byTooltip(en.increase));
      await tester.pump();
      await tester.tap(find.byTooltip(en.increase)); // at max: disabled
      await tester.pump();
      expect(value, 9);
    });

    testWidgets('error view localizes the failure', (tester) async {
      await tester.pumpWidget(localizedApp(Scaffold(
        body: ErrorView(failure: const NetworkFailure(), onRetry: () {}),
      )));
      expect(find.text(en.titleOffline), findsOneWidget);
      expect(find.text(en.errNetwork), findsOneWidget);
      expect(find.text(en.tryAgain), findsOneWidget);
    });
  }
  ```

- [ ] **Step 2: Run them to verify they fail.**
  Run: `fl test test/core/failure_text_test.dart test/presentation/data_widgets_test.dart`
  Expected: FAIL to compile.

- [ ] **Step 3: Extend `lib/core/network/app_failure.dart`.**
  - After `UnauthorizedFailure`, add:
    ```dart
    /// 401 on login: wrong username or password.
    final class InvalidCredentialsFailure extends UnauthorizedFailure {
      const InvalidCredentialsFailure() : super('Wrong username or password.');
    }

    /// The account exists but an administrator disabled it.
    final class AccountDisabledFailure extends UnauthorizedFailure {
      const AccountDisabledFailure() : super('This account has been disabled.');
    }
    ```
  - In `ConflictFailure`, add `static const usernameTaken = 'USERNAME_TAKEN';`.
  - Replace `AppStateFailure` with:
    ```dart
    /// A precondition of the app itself (e.g. the account has no region).
    final class AppStateFailure extends AppFailure {
      const AppStateFailure(super.message, {this.code});

      static const noRegion = 'NO_REGION';

      final String? code;
    }
    ```

- [ ] **Step 4: Throw the typed failures.**
  - In `lib/features/auth/data/auth_repository.dart` `login`:
    - Replace the whole `on UnauthorizedFailure catch (e) { … }` block with:
      ```dart
      } on UnauthorizedFailure catch (e) {
        throw e.message.toLowerCase().contains('disabled')
            ? const AccountDisabledFailure()
            : const InvalidCredentialsFailure();
      }
      ```
    - Replace `throw const UnauthorizedFailure('This account has been disabled.');` with `throw const AccountDisabledFailure();`.
    - In `register`, replace `throw const ConflictFailure('Username or email is already in use');` with:
      ```dart
      throw const ConflictFailure(
        'Username or email is already in use',
        code: ConflictFailure.usernameTaken,
      );
      ```
  - In `lib/features/auth/presentation/auth_controller.dart`:
    - Replace `String? lastSignOutReason;` with `AppFailure? lastSignOutFailure;`.
    - In `build`, make the listener call `_signOut(reason: const UnauthorizedFailure())`.
    - `login` sets `lastSignOutFailure = null;`.
    - Change `_signOut({String? reason})` to `_signOut({AppFailure? reason})`, and inside it use `lastSignOutFailure = reason;`.
    - In `regionOf`, throw:
      ```dart
      throw const AppStateFailure(
        'Your account has no region assigned. Ask an administrator.',
        code: AppStateFailure.noRegion,
      );
      ```
  - In `lib/features/auth/presentation/login_page.dart` `initState`, change the assignment to `_error = ref.read(authControllerProvider.notifier).lastSignOutFailure?.message;`. Task 10 localizes it properly.

  Verify nothing else uses the old name:
  ```bash
  grep -rn lastSignOutReason lib test
  ```
  Expected: no output.

- [ ] **Step 5: Create `lib/core/network/failure_text.dart`.**
  ```dart
  import '../../l10n/app_localizations.dart';
  import 'app_failure.dart';

  /// The volunteer-facing message for [failure], in the UI language. Server
  /// validation and conflict messages are already human text and pass through.
  String failureText(AppLocalizations l, AppFailure failure) => switch (failure) {
    InvalidCredentialsFailure() => l.errLoginFailed,
    AccountDisabledFailure() => l.errAccountDisabled,
    UnauthorizedFailure() => l.errSessionExpired,
    NetworkFailure() => l.errNetwork,
    TimeoutFailure() => l.errTimeout,
    ForbiddenFailure() => l.errForbidden,
    NotFoundFailure() => l.errNotFound,
    MealAlreadyTakenFailure() => l.alreadyCollected,
    ConflictFailure(code: ConflictFailure.usernameTaken) => l.errUsernameTaken,
    ConflictFailure(:final message) => message,
    ValidationFailure(:final message) => message,
    ServerFailure() => l.errServer,
    AppStateFailure(code: AppStateFailure.noRegion) => l.errNoRegion,
    AppStateFailure(:final message) => message,
    UnknownFailure() => l.errUnknown,
  };

  /// Short title for full-screen error views.
  String failureTitle(AppLocalizations l, AppFailure failure) => switch (failure) {
    NetworkFailure() => l.titleOffline,
    TimeoutFailure() => l.titleSlow,
    ServerFailure() => l.titleServerError,
    UnauthorizedFailure() => l.titleSignedOut,
    NotFoundFailure() => l.titleNotFound,
    _ => l.titleGenericError,
  };
  ```

- [ ] **Step 6: Rewrite `lib/core/widgets/state_views.dart`.**
  ```dart
  import 'package:flutter/material.dart';

  import '../../l10n/app_localizations.dart';
  import '../network/app_failure.dart';
  import '../network/failure_text.dart';
  import '../theme/app_colors.dart';
  import '../theme/iftar_colors.dart';

  /// Centered spinner with an optional caption.
  class LoadingView extends StatelessWidget {
    const LoadingView({super.key, this.message});

    final String? message;

    @override
    Widget build(BuildContext context) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox.square(
              dimension: 36,
              child: CircularProgressIndicator(strokeWidth: 3),
            ),
            if (message != null) ...[
              const SizedBox(height: AppSpacing.md),
              Text(
                message!,
                style: TextStyle(color: context.colors.actInk, fontSize: 14),
              ),
            ],
          ],
        ),
      );
    }
  }

  /// Full-area error with an icon picked from the failure type and a retry.
  class ErrorView extends StatelessWidget {
    const ErrorView({super.key, required this.failure, this.onRetry});

    final AppFailure failure;
    final VoidCallback? onRetry;

    @override
    Widget build(BuildContext context) {
      final l = AppLocalizations.of(context);
      final icon = switch (failure) {
        NetworkFailure() => Icons.wifi_off_rounded,
        TimeoutFailure() => Icons.hourglass_empty_rounded,
        ServerFailure() => Icons.cloud_off_rounded,
        UnauthorizedFailure() => Icons.lock_outline_rounded,
        NotFoundFailure() => Icons.search_off_rounded,
        _ => Icons.error_outline_rounded,
      };
      return EmptyView(
        icon: icon,
        title: failureTitle(l, failure),
        message: failureText(l, failure),
        action: onRetry == null
            ? null
            : OutlinedButton.icon(
                onPressed: onRetry,
                icon: const Icon(Icons.refresh_rounded),
                label: Text(l.tryAgain),
              ),
      );
    }
  }

  class EmptyView extends StatelessWidget {
    const EmptyView({
      super.key,
      required this.icon,
      required this.title,
      this.message,
      this.action,
    });

    final IconData icon;
    final String title;
    final String? message;
    final Widget? action;

    @override
    Widget build(BuildContext context) {
      final c = context.colors;
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.xxl),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(AppSpacing.lg),
                decoration: BoxDecoration(color: c.chip, shape: BoxShape.circle),
                child: Icon(icon, size: 32, color: c.chipInk),
              ),
              const SizedBox(height: AppSpacing.lg),
              Text(
                title,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.titleMedium,
              ),
              if (message != null) ...[
                const SizedBox(height: AppSpacing.sm),
                Text(
                  message!,
                  textAlign: TextAlign.center,
                  style: TextStyle(color: c.inkMuted),
                ),
              ],
              if (action != null) ...[
                const SizedBox(height: AppSpacing.xl),
                SizedBox(width: 220, child: action),
              ],
            ],
          ),
        ),
      );
    }
  }

  /// Snackbar after actions (save, delete, confirm...). Errors use clay.
  void showAppSnackBar(
    BuildContext context,
    String message, {
    bool isError = false,
  }) {
    final c = context.colors;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(
            message,
            style: isError ? TextStyle(color: c.onClay) : null,
          ),
          backgroundColor: isError ? c.clay : null,
        ),
      );
  }
  ```

- [ ] **Step 7: Create `lib/core/widgets/status_chip.dart`.**
  ```dart
  import 'package:flutter/material.dart';

  import '../../features/people/domain/fasting_person.dart';
  import '../../l10n/app_localizations.dart';
  import '../theme/iftar_colors.dart';
  import '../utils/formatters.dart';

  /// Tunisian pickup words, kept in every language (spec §5).
  abstract final class MealStatusWords {
    static const taken = 'خذا';
    static const notTaken = 'ما خذاش';
  }

  /// "○ ما خذاش" or "✓ خذا 18:12": an icon and a word, never color alone.
  class StatusChip extends StatelessWidget {
    const StatusChip({super.key, required this.person, this.now});

    final FastingPerson person;
    final DateTime? now;

    @override
    Widget build(BuildContext context) {
      final c = context.colors;
      final l = AppLocalizations.of(context);
      final taken = person.isMealTakenToday(now);
      final at = person.lastTakenMeal;
      final text = taken
          ? '${isolate(MealStatusWords.taken)}'
                '${at == null ? '' : ' ${ltr(formatTime(at))}'}'
          : isolate(MealStatusWords.notTaken);
      final fg = taken ? c.clayInk : c.actInk;
      return Semantics(
        label: taken ? l.servedTooltip : l.notServedTooltip,
        child: Container(
          padding: const EdgeInsetsDirectional.fromSTEB(7, 2, 9, 2),
          decoration: BoxDecoration(
            color: taken ? c.claySoft : c.actSoft,
            borderRadius: BorderRadius.circular(999),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                taken ? Icons.check_rounded : Icons.radio_button_unchecked_rounded,
                size: 13,
                color: fg,
              ),
              const SizedBox(width: 4),
              Text(
                text,
                style: TextStyle(
                  fontSize: 11.5,
                  fontWeight: FontWeight.w500,
                  color: fg,
                ),
              ),
            ],
          ),
        ),
      );
    }
  }
  ```

- [ ] **Step 8: Create `lib/core/widgets/hand_over_tiles.dart`.**
  ```dart
  import 'package:flutter/material.dart';

  import '../../features/people/domain/fasting_person.dart';
  import '../../l10n/app_localizations.dart';
  import '../theme/iftar_colors.dart';
  import '../utils/formatters.dart';

  /// "What to hand over": the largest thing on the scan sheet (spec §4.6).
  class HandOverTiles extends StatelessWidget {
    const HandOverTiles({super.key, required this.person});

    final FastingPerson person;

    @override
    Widget build(BuildContext context) {
      final l = AppLocalizations.of(context);
      return Row(
        children: [
          Expanded(
            child: _Tile(
              count: person.familyMeal,
              label: l.familyMeal,
              caption: person.familyMeal > 0
                  ? l.portions(person.familyMeal * 4)
                  : l.none,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: _Tile(
              count: person.singleMeal,
              label: l.singleMeal,
              caption: person.singleMeal > 0 ? l.portions(person.singleMeal) : l.none,
            ),
          ),
        ],
      );
    }
  }

  class _Tile extends StatelessWidget {
    const _Tile({required this.count, required this.label, required this.caption});

    final int count;
    final String label;
    final String caption;

    @override
    Widget build(BuildContext context) {
      final c = context.colors;
      return Opacity(
        opacity: count == 0 ? 0.42 : 1,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
          decoration: BoxDecoration(
            color: c.tile,
            borderRadius: BorderRadius.circular(14),
          ),
          child: Row(
            children: [
              Text(
                ltr('$count'),
                style: TextStyle(
                  fontSize: 30,
                  fontWeight: FontWeight.w600,
                  height: 1,
                  color: c.ink,
                  fontFeatures: const [FontFeature.tabularFigures()],
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(label, maxLines: 2, style: const TextStyle(fontSize: 12, height: 1.3)),
                    Text(caption, style: TextStyle(fontSize: 11, color: c.inkMuted)),
                  ],
                ),
              ),
            ],
          ),
        ),
      );
    }
  }
  ```

- [ ] **Step 9: Create `lib/core/widgets/meal_stepper.dart`.**
  ```dart
  import 'package:flutter/material.dart';

  import '../../l10n/app_localizations.dart';
  import '../theme/iftar_colors.dart';
  import '../utils/formatters.dart';

  /// − value + with 44 px targets; buttons disable at the bounds.
  class MealStepper extends StatelessWidget {
    const MealStepper({
      super.key,
      required this.label,
      required this.caption,
      required this.value,
      required this.onChanged,
      this.min = 0,
      this.max = 9,
    });

    final String label;
    final String caption;
    final int value;
    final ValueChanged<int> onChanged;
    final int min;
    final int max;

    @override
    Widget build(BuildContext context) {
      final c = context.colors;
      final l = AppLocalizations.of(context);
      final style = IconButton.styleFrom(
        minimumSize: const Size.square(44),
        side: BorderSide(color: c.line),
      );
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 10),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(label, style: const TextStyle(fontSize: 14.5)),
                  Text(caption, style: TextStyle(fontSize: 11.5, color: c.inkMuted)),
                ],
              ),
            ),
            IconButton.outlined(
              style: style,
              tooltip: l.decrease,
              icon: const Icon(Icons.remove_rounded),
              onPressed: value > min ? () => onChanged(value - 1) : null,
            ),
            SizedBox(
              width: 44,
              child: Semantics(
                liveRegion: true,
                label: '$label $value',
                child: Text(
                  ltr('$value'),
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w600),
                ),
              ),
            ),
            IconButton.outlined(
              style: style,
              tooltip: l.increase,
              icon: const Icon(Icons.add_rounded),
              onPressed: value < max ? () => onChanged(value + 1) : null,
            ),
          ],
        ),
      );
    }
  }
  ```

- [ ] **Step 10: Run the tests.**
  Run: `fl test`
  Expected: PASS, including `scan_controller_test` ("account without region"). It still finds an `AppStateFailure`.

- [ ] **Step 11: Commit.**
  ```bash
  git add lib/core/network lib/core/widgets/state_views.dart lib/core/widgets/status_chip.dart lib/core/widgets/hand_over_tiles.dart lib/core/widgets/meal_stepper.dart lib/features/auth test/core/failure_text_test.dart test/presentation/data_widgets_test.dart
  git commit -m "feat(mobile): localized failures, status chip, hand-over tiles, meal stepper" -m "Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>" -- lib/core/network lib/core/widgets/state_views.dart lib/core/widgets/status_chip.dart lib/core/widgets/hand_over_tiles.dart lib/core/widgets/meal_stepper.dart lib/features/auth test/core/failure_text_test.dart test/presentation/data_widgets_test.dart
  ```

---

### Task 8: Bottom bar and scan button

**Files:**
- Rewrite: `lib/shell/home_shell.dart`
- Test: `test/presentation/nav_test.dart`

**Interfaces:**
- Produces:
  - `AppBottomNav({required int currentIndex, required ValueChanged<int> onSelect})`.
  - `ScanButton({required VoidCallback onPressed})`.
  - `HomeShell` (same constructor as today).

- [ ] **Step 1: Write the failing test** `test/presentation/nav_test.dart`:
  ```dart
  import 'package:flutter/material.dart';
  import 'package:flutter_test/flutter_test.dart';
  import 'package:iftar_mobile/shell/home_shell.dart';

  import '../support/app_harness.dart';

  void main() {
    testWidgets('tabs are labelled in the UI language and report taps', (tester) async {
      var selected = -1;
      var scanned = false;
      Widget nav(Locale locale) => localizedApp(
        Scaffold(
          floatingActionButton: ScanButton(onPressed: () => scanned = true),
          bottomNavigationBar: AppBottomNav(currentIndex: 0, onSelect: (i) => selected = i),
        ),
        locale: locale,
      );

      await tester.pumpWidget(nav(const Locale('en')));
      for (final label in [en.navPeople, en.navAdd, en.navStats, en.navProfile]) {
        expect(find.text(label), findsOneWidget);
      }
      await tester.tap(find.text(en.navStats));
      expect(selected, 2);
      await tester.tap(find.byTooltip(en.navScan));
      expect(scanned, isTrue);

      await tester.pumpWidget(nav(const Locale('ar')));
      await tester.pumpAndSettle();
      expect(find.text(ar.navPeople), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  }
  ```

- [ ] **Step 2: Run it to verify it fails.**
  Run: `fl test test/presentation/nav_test.dart`
  Expected: FAIL, because `AppBottomNav` and `ScanButton` are undefined.

- [ ] **Step 3: Rewrite `lib/shell/home_shell.dart`.**
  ```dart
  import 'package:flutter/material.dart';
  import 'package:go_router/go_router.dart';

  import '../core/theme/app_colors.dart';
  import '../l10n/app_localizations.dart';

  /// Tabs on a sky-colored bar, with the raised mint scan button docked in the
  /// middle (spec §4.11).
  class HomeShell extends StatelessWidget {
    const HomeShell({super.key, required this.navigationShell});

    final StatefulNavigationShell navigationShell;

    void _go(int index) => navigationShell.goBranch(
      index,
      initialLocation: index == navigationShell.currentIndex,
    );

    @override
    Widget build(BuildContext context) {
      final keyboardOpen = MediaQuery.viewInsetsOf(context).bottom > 0;
      return Scaffold(
        body: navigationShell,
        extendBody: true,
        // Hidden while typing, as in the Ionic app.
        floatingActionButton: keyboardOpen
            ? null
            : ScanButton(onPressed: () => context.push('/scan')),
        floatingActionButtonLocation: FloatingActionButtonLocation.centerDocked,
        bottomNavigationBar: keyboardOpen
            ? null
            : AppBottomNav(
                currentIndex: navigationShell.currentIndex,
                onSelect: _go,
              ),
      );
    }
  }

  class AppBottomNav extends StatelessWidget {
    const AppBottomNav({
      super.key,
      required this.currentIndex,
      required this.onSelect,
    });

    final int currentIndex;
    final ValueChanged<int> onSelect;

    static const _icons = [
      Icons.format_list_bulleted_rounded,
      Icons.person_add_alt_1_outlined,
      Icons.insert_chart_outlined_rounded,
      Icons.person_outline_rounded,
    ];

    @override
    Widget build(BuildContext context) {
      final l = AppLocalizations.of(context);
      final labels = [l.navPeople, l.navAdd, l.navStats, l.navProfile];
      return BottomAppBar(
        color: AppPalette.sky,
        height: 72,
        padding: EdgeInsets.zero,
        child: Row(
          children: [
            for (var i = 0; i < labels.length; i++) ...[
              if (i == 2) const SizedBox(width: 84),
              Expanded(
                child: _TabButton(
                  icon: _icons[i],
                  label: labels[i],
                  selected: currentIndex == i,
                  onTap: () => onSelect(i),
                ),
              ),
            ],
          ],
        ),
      );
    }
  }

  class _TabButton extends StatelessWidget {
    const _TabButton({
      required this.icon,
      required this.label,
      required this.selected,
      required this.onTap,
    });

    final IconData icon;
    final String label;
    final bool selected;
    final VoidCallback onTap;

    @override
    Widget build(BuildContext context) {
      final color = selected ? AppPalette.gold : AppPalette.onSkyMuted;
      return Semantics(
        selected: selected,
        button: true,
        label: label,
        excludeSemantics: true,
        child: InkResponse(
          onTap: onTap,
          radius: 36,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, color: color),
              const SizedBox(height: 3),
              Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: color,
                  fontSize: 10.5,
                  fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
                ),
              ),
            ],
          ),
        ),
      );
    }
  }

  /// 62 px mint circle in a 6 px sky ring; no gold ring (spec §4.11).
  class ScanButton extends StatelessWidget {
    const ScanButton({super.key, required this.onPressed});

    final VoidCallback onPressed;

    @override
    Widget build(BuildContext context) {
      final label = AppLocalizations.of(context).navScan;
      return Container(
        padding: const EdgeInsets.all(6),
        decoration: const BoxDecoration(color: AppPalette.sky, shape: BoxShape.circle),
        child: Tooltip(
          message: label,
          child: Material(
            color: AppPalette.mint,
            shape: const CircleBorder(),
            child: InkWell(
              customBorder: const CircleBorder(),
              onTap: onPressed,
              child: const SizedBox.square(
                dimension: 62,
                child: Icon(Icons.qr_code_scanner_rounded, size: 28, color: AppPalette.sky),
              ),
            ),
          ),
        ),
      );
    }
  }
  ```

- [ ] **Step 4: Run the tests.**
  Run: `fl test`
  Expected: PASS.

- [ ] **Step 5: Commit.**
  ```bash
  git add lib/shell/home_shell.dart test/presentation/nav_test.dart
  git commit -m "feat(mobile): sky tab bar with mint scan button" -m "Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>" -- lib/shell/home_shell.dart test/presentation/nav_test.dart
  ```

---

### Task 9: Welcome (language picker, arch window, logo kept) and Splash

**Files:**
- Rewrite: `lib/features/auth/presentation/welcome_page.dart`
- Modify: `lib/core/widgets/brand.dart` (remove `BrandTitle`; add `hadithText`)
- Test: `test/presentation/welcome_test.dart`

**Interfaces:**
- Consumes: `NightSky(dusk:)`, `ArchWindow` (Task 6), `settingsControllerProvider` (Task 4), `supportedLanguageCodes` / `languageNames` (Task 3), `BrandLogo` (existing).
- Produces: `WelcomePage`, `SplashPage` (same names), and `hadithText`.

- [ ] **Step 1: Write the failing test** `test/presentation/welcome_test.dart`:
  ```dart
  import 'package:flutter/material.dart';
  import 'package:flutter_test/flutter_test.dart';
  import 'package:iftar_mobile/core/settings/settings_controller.dart';
  import 'package:iftar_mobile/core/settings/settings_storage.dart';
  import 'package:iftar_mobile/features/auth/presentation/welcome_page.dart';

  import '../support/app_harness.dart';

  void main() {
    late MemorySettingsStorage storage;
    setUp(() => storage = MemorySettingsStorage());

    Widget app(Locale locale) => localizedApp(
      const WelcomePage(),
      locale: locale,
      overrides: [settingsStorageProvider.overrideWithValue(storage)],
    );

    testWidgets('offers the three languages and both actions', (tester) async {
      await tester.pumpWidget(app(const Locale('en')));
      for (final name in ['English', 'Français', 'العربية']) {
        expect(find.text(name), findsOneWidget);
      }
      expect(find.text(en.signIn), findsOneWidget);
      expect(find.text(en.createVolunteerAccount), findsOneWidget);
      expect(find.text(en.hadithMeaning), findsOneWidget);
      expect(find.bySemanticsLabel('Ramadan Kareem'), findsOneWidget); // logo kept
    });

    testWidgets('picking a language saves it', (tester) async {
      await tester.pumpWidget(app(const Locale('en')));
      await tester.tap(find.text('Français'));
      await tester.pump();
      expect(storage.values[SettingsController.localeKey], 'fr');
    });

    testWidgets('Arabic hides the translated hadith line', (tester) async {
      await tester.pumpWidget(app(const Locale('ar')));
      expect(find.text(en.hadithMeaning), findsNothing);
      expect(find.text(ar.signIn), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  }
  ```

- [ ] **Step 2: Run it to verify it fails.**
  Run: `fl test test/presentation/welcome_test.dart`
  Expected: FAIL. The page has no language picker yet.

- [ ] **Step 3: Update `lib/core/widgets/brand.dart`.**
  - Delete the whole `BrandTitle` class. Welcome was its only user; check with `grep -rn BrandTitle lib test`.
  - Add, above `BrandLogo`:
    ```dart
    /// "Whoever gives iftar to a fasting person shares in their reward."
    /// Shown in Arabic in every language; its meaning is translated (spec §4.1).
    const hadithText = 'من فطّر صائماً كان له مثل أجره';
    ```

- [ ] **Step 4: Rewrite `lib/features/auth/presentation/welcome_page.dart`.**
  ```dart
  import 'package:flutter/material.dart';
  import 'package:flutter_riverpod/flutter_riverpod.dart';
  import 'package:go_router/go_router.dart';

  import '../../../core/settings/locale_resolution.dart';
  import '../../../core/settings/settings_controller.dart';
  import '../../../core/theme/app_colors.dart';
  import '../../../core/theme/app_theme.dart';
  import '../../../core/widgets/arch_window.dart';
  import '../../../core/widgets/brand.dart';
  import '../../../core/widgets/night_sky.dart';
  import '../../../l10n/app_localizations.dart';

  /// Landing screen: always night (spec §4.1).
  class WelcomePage extends StatelessWidget {
    const WelcomePage({super.key});

    @override
    Widget build(BuildContext context) {
      final l = AppLocalizations.of(context);
      return Scaffold(
        backgroundColor: AppPalette.sky,
        body: NightSky(
          starCount: 40,
          dusk: true,
          child: SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 28),
              child: Column(
                children: [
                  const SizedBox(height: 8),
                  const _LanguagePicker(),
                  const Spacer(flex: 2),
                  ArchWindow(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const BrandLogo(width: 168),
                        const SizedBox(height: 12),
                        const Text(
                          hadithText,
                          textAlign: TextAlign.center,
                          textDirection: TextDirection.rtl,
                          style: TextStyle(
                            fontFamily: AppTheme.brandFont,
                            fontSize: 17,
                            height: 1.5,
                            color: AppPalette.onSky,
                          ),
                        ),
                        if (l.hadithMeaning.isNotEmpty) ...[
                          const SizedBox(height: 6),
                          Text(
                            l.hadithMeaning,
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              fontSize: 11.5,
                              color: AppPalette.onSkyMuted,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    l.appTitle,
                    style: const TextStyle(
                      fontFamily: AppTheme.brandFont,
                      fontSize: 32,
                      height: 1.2,
                      color: AppPalette.gold,
                    ),
                  ),
                  Text(
                    l.appSubtitle,
                    textAlign: TextAlign.center,
                    style: const TextStyle(fontSize: 12.5, color: AppPalette.onSkyMuted),
                  ),
                  const Spacer(flex: 3),
                  FilledButton(
                    style: FilledButton.styleFrom(
                      backgroundColor: AppPalette.mint,
                      foregroundColor: AppPalette.sky,
                    ),
                    onPressed: () => context.push('/login'),
                    child: Text(l.signIn),
                  ),
                  const SizedBox(height: 12),
                  OutlinedButton(
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppPalette.onSky,
                      side: BorderSide(color: AppPalette.onSky.withValues(alpha: 0.35)),
                    ),
                    onPressed: () => context.push('/register'),
                    child: Text(l.createVolunteerAccount),
                  ),
                  const SizedBox(height: 24),
                ],
              ),
            ),
          ),
        ),
      );
    }
  }

  /// Three pills; the language is the first choice a volunteer makes.
  class _LanguagePicker extends ConsumerWidget {
    const _LanguagePicker();

    static const _order = ['en', 'fr', 'ar'];

    @override
    Widget build(BuildContext context, WidgetRef ref) {
      assert(_order.every(supportedLanguageCodes.contains));
      final current = Localizations.localeOf(context).languageCode;
      return Wrap(
        spacing: 6,
        children: [
          for (final code in _order)
            Semantics(
              button: true,
              selected: code == current,
              child: InkWell(
                borderRadius: BorderRadius.circular(999),
                onTap: () => ref
                    .read(settingsControllerProvider.notifier)
                    .setLocale(Locale(code)),
                child: Container(
                  constraints: const BoxConstraints(minHeight: 36),
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                  decoration: BoxDecoration(
                    color: code == current
                        ? AppPalette.gold
                        : AppPalette.onSky.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(999),
                    border: Border.all(
                      color: code == current
                          ? AppPalette.gold
                          : AppPalette.onSky.withValues(alpha: 0.22),
                    ),
                  ),
                  child: Text(
                    languageNames[code]!,
                    style: TextStyle(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w500,
                      color: code == current ? AppPalette.sky : AppPalette.onSky,
                    ),
                  ),
                ),
              ),
            ),
        ],
      );
    }
  }

  /// Shown while the stored session is restored at startup.
  class SplashPage extends StatelessWidget {
    const SplashPage({super.key});

    @override
    Widget build(BuildContext context) {
      return const Scaffold(
        backgroundColor: AppPalette.sky,
        body: NightSky(
          starCount: 40,
          dusk: true,
          child: Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                BrandLogo(width: 220),
                SizedBox(height: 32),
                SizedBox.square(
                  dimension: 28,
                  child: CircularProgressIndicator(strokeWidth: 2.5, color: AppPalette.gold),
                ),
              ],
            ),
          ),
        ),
      );
    }
  }
  ```

- [ ] **Step 5: Run the tests.**
  Run: `fl test`
  Expected: PASS.

- [ ] **Step 6: Commit.**
  ```bash
  git add lib/features/auth/presentation/welcome_page.dart lib/core/widgets/brand.dart test/presentation/welcome_test.dart
  git commit -m "feat(mobile): night welcome with language picker, arch window and logo" -m "Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>" -- lib/features/auth/presentation/welcome_page.dart lib/core/widgets/brand.dart test/presentation/welcome_test.dart
  ```

---

### Task 10: Login and Register (sky header, paper form, localized)

**Files:**
- Rewrite: `lib/features/auth/presentation/auth_scaffold.dart`, `lib/core/widgets/pill_text_field.dart`
- Modify: `lib/features/auth/presentation/login_page.dart`, `lib/features/auth/presentation/register_page.dart`
- Test: `test/presentation/login_test.dart`; update the login test in `test/presentation/widgets_test.dart`

**Interfaces:**
- Consumes: `failureText` (Task 7), `NightSky` (Task 6), `BrandLogo`.
- Produces:
  - `AuthScaffold({required String title, String? lead, required Widget child, String? switchLabel, VoidCallback? onSwitch})`.
  - `FormErrorBanner(String message)`.
  - `PillTextField`, same parameters, restyled.

- [ ] **Step 1: Write the failing test** `test/presentation/login_test.dart`:
  ```dart
  import 'package:flutter/material.dart';
  import 'package:flutter_test/flutter_test.dart';
  import 'package:iftar_mobile/core/network/app_failure.dart';
  import 'package:iftar_mobile/features/auth/data/auth_repository.dart';
  import 'package:iftar_mobile/features/auth/domain/user.dart';
  import 'package:iftar_mobile/features/auth/presentation/login_page.dart';

  import '../support/app_harness.dart';

  class _RejectingAuthRepository implements AuthRepository {
    @override
    Future<User?> restoreSession() async => null;

    @override
    Future<User> login(String username, String password) async =>
        throw const InvalidCredentialsFailure();

    @override
    Future<User> fetchProfile() => throw UnimplementedError();

    @override
    Future<void> register({
      required String name,
      required String username,
      required String email,
      required String password,
      required int regionId,
    }) => throw UnimplementedError();

    @override
    Future<void> logout() async {}
  }

  void main() {
    testWidgets('wrong credentials show a localized message', (tester) async {
      await tester.pumpWidget(localizedApp(
        const LoginPage(),
        overrides: [authRepositoryProvider.overrideWithValue(_RejectingAuthRepository())],
      ));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextFormField).at(0), 'sami');
      await tester.enterText(find.byType(TextFormField).at(1), 'secret');
      await tester.tap(find.text(en.signIn));
      await tester.pumpAndSettle();
      expect(find.text(en.errLoginFailed), findsOneWidget);
    });

    testWidgets('login renders in Arabic without overflow', (tester) async {
      await tester.pumpWidget(localizedApp(
        const LoginPage(),
        locale: const Locale('ar'),
        overrides: [authRepositoryProvider.overrideWithValue(_RejectingAuthRepository())],
      ));
      await tester.pumpAndSettle();
      expect(find.text(ar.welcomeBack), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  }
  ```
  If `AuthRepository.register` has different parameter names in `lib/features/auth/data/auth_repository.dart`, copy its exact signature into the fake.

  In `test/presentation/widgets_test.dart`, in the login test, replace `await tester.tap(find.text('Login'));` with `await tester.tap(find.text(en.signIn));`.

- [ ] **Step 2: Run them to verify they fail.**
  Run: `fl test test/presentation/login_test.dart test/presentation/widgets_test.dart`
  Expected: FAIL, because the button still says "Login" and errors aren't localized.

- [ ] **Step 3: Rewrite `lib/features/auth/presentation/auth_scaffold.dart`.**
  ```dart
  import 'package:flutter/material.dart';

  import '../../../core/theme/app_colors.dart';
  import '../../../core/theme/app_theme.dart';
  import '../../../core/theme/iftar_colors.dart';
  import '../../../core/widgets/brand.dart';
  import '../../../core/widgets/night_sky.dart';
  import '../../../l10n/app_localizations.dart';

  /// Sky with the logo on top, the form on paper below (spec §4.2).
  class AuthScaffold extends StatelessWidget {
    const AuthScaffold({
      super.key,
      required this.title,
      required this.child,
      this.lead,
      this.switchLabel,
      this.onSwitch,
    });

    final String title;
    final String? lead;
    final Widget child;
    final String? switchLabel;
    final VoidCallback? onSwitch;

    @override
    Widget build(BuildContext context) {
      final l = AppLocalizations.of(context);
      final c = context.colors;
      final top = MediaQuery.paddingOf(context).top;
      return Scaffold(
        backgroundColor: c.page,
        body: CustomScrollView(
          slivers: [
            SliverToBoxAdapter(
              child: SizedBox(
                height: 250 + top,
                child: NightSky(
                  dusk: true,
                  pattern: true,
                  starCount: 14,
                  child: Stack(
                    children: [
                      Positioned.fill(
                        top: top,
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const BrandLogo(width: 150),
                            const SizedBox(height: 6),
                            Text(
                              l.appTitle,
                              style: const TextStyle(
                                fontFamily: AppTheme.brandFont,
                                fontSize: 28,
                                height: 1.2,
                                color: AppPalette.gold,
                              ),
                            ),
                            Text(
                              l.appSubtitle,
                              style: const TextStyle(fontSize: 12.5, color: AppPalette.onSkyMuted),
                            ),
                          ],
                        ),
                      ),
                      if (Navigator.of(context).canPop())
                        PositionedDirectional(
                          start: 8,
                          top: top + 4,
                          child: BackButton(color: AppPalette.onSky, onPressed: () => Navigator.of(context).maybePop()),
                        ),
                    ],
                  ),
                ),
              ),
            ),
            SliverToBoxAdapter(
              child: Transform.translate(
                offset: const Offset(0, -28),
                child: Container(
                  decoration: BoxDecoration(
                    color: c.page,
                    borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
                  ),
                  padding: const EdgeInsets.fromLTRB(24, 26, 24, 8),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text(
                        title,
                        style: TextStyle(fontSize: 24, fontWeight: FontWeight.w500, color: c.ink),
                      ),
                      if (lead != null) ...[
                        const SizedBox(height: 2),
                        Text(lead!, style: TextStyle(fontSize: 13, color: c.inkMuted)),
                      ],
                      const SizedBox(height: 18),
                      child,
                      if (switchLabel != null)
                        TextButton(onPressed: onSwitch, child: Text(switchLabel!)),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      );
    }
  }

  /// Inline error above the submit button of auth forms.
  class FormErrorBanner extends StatelessWidget {
    const FormErrorBanner(this.message, {super.key});

    final String message;

    @override
    Widget build(BuildContext context) {
      final c = context.colors;
      return Container(
        padding: const EdgeInsets.all(AppSpacing.md),
        decoration: BoxDecoration(
          color: c.claySoft,
          borderRadius: BorderRadius.circular(AppRadii.field),
        ),
        child: Row(
          children: [
            Icon(Icons.error_outline_rounded, color: c.clayInk),
            const SizedBox(width: AppSpacing.sm),
            Expanded(child: Text(message, style: TextStyle(color: c.clayInk))),
          ],
        ),
      );
    }
  }
  ```

- [ ] **Step 4: Rewrite `lib/core/widgets/pill_text_field.dart`.** It keeps the same parameters, but uses the theme's input style (radius 14, hairline border) instead of pills and shadows.
  ```dart
  import 'package:flutter/material.dart';

  import '../theme/app_colors.dart';
  import '../theme/iftar_colors.dart';

  /// Auth-form field: leading icon, theme border, 16 px bottom gap.
  class PillTextField extends StatelessWidget {
    const PillTextField({
      super.key,
      required this.controller,
      required this.hint,
      this.icon,
      this.validator,
      this.obscureText = false,
      this.keyboardType,
      this.textInputAction,
      this.autofillHints,
      this.onSubmitted,
      this.suffix,
      this.enabled = true,
    });

    final TextEditingController controller;
    final String hint;
    final IconData? icon;
    final FormFieldValidator<String>? validator;
    final bool obscureText;
    final TextInputType? keyboardType;
    final TextInputAction? textInputAction;
    final Iterable<String>? autofillHints;
    final ValueChanged<String>? onSubmitted;
    final Widget? suffix;
    final bool enabled;

    @override
    Widget build(BuildContext context) {
      return Padding(
        padding: const EdgeInsets.only(bottom: AppSpacing.lg),
        child: TextFormField(
          controller: controller,
          validator: validator,
          obscureText: obscureText,
          keyboardType: keyboardType,
          textInputAction: textInputAction,
          autofillHints: autofillHints,
          onFieldSubmitted: onSubmitted,
          enabled: enabled,
          style: const TextStyle(fontSize: 15),
          decoration: InputDecoration(
            hintText: hint,
            prefixIcon: icon == null
                ? null
                : Icon(icon, color: context.colors.inkMuted, size: 20),
            suffixIcon: suffix,
          ),
        ),
      );
    }
  }
  ```

- [ ] **Step 5: Localize `lib/features/auth/presentation/login_page.dart`.**
  - Add the imports `../../../core/network/failure_text.dart`, `../../../core/theme/iftar_colors.dart`, and `../../../l10n/app_localizations.dart`. Remove the `app_colors.dart` import if it's now unused.
  - Replace `String? _error;` with `AppFailure? _failure;`. In `initState`, use `_failure = ref.read(authControllerProvider.notifier).lastSignOutFailure;`.
  - In `_submit`: set `_failure = null` before the call, and in the catch use `on AppFailure catch (e) { if (mounted) setState(() => _failure = e); }`.
  - Replace `build` with:
    ```dart
    @override
    Widget build(BuildContext context) {
      final l = AppLocalizations.of(context);
      return AuthScaffold(
        title: l.welcomeBack,
        lead: l.loginLead,
        switchLabel: l.newVolunteerCreateAccount,
        onSwitch: () => context.pushReplacement('/register'),
        child: AutofillGroup(
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                PillTextField(
                  controller: _username,
                  hint: l.username,
                  icon: Icons.person_outline_rounded,
                  textInputAction: TextInputAction.next,
                  autofillHints: const [AutofillHints.username],
                  validator: (v) =>
                      (v == null || v.trim().isEmpty) ? l.usernameRequired : null,
                ),
                PillTextField(
                  controller: _password,
                  hint: l.password,
                  icon: Icons.lock_outline_rounded,
                  obscureText: _obscure,
                  textInputAction: TextInputAction.done,
                  autofillHints: const [AutofillHints.password],
                  onSubmitted: (_) => _submit(),
                  suffix: IconButton(
                    tooltip: _obscure ? l.showPassword : l.hidePassword,
                    icon: Icon(
                      _obscure ? Icons.visibility_outlined : Icons.visibility_off_outlined,
                      color: context.colors.inkMuted,
                    ),
                    onPressed: () => setState(() => _obscure = !_obscure),
                  ),
                  validator: (v) => (v == null || v.isEmpty) ? l.passwordRequired : null,
                ),
                if (_failure != null) FormErrorBanner(failureText(l, _failure!)),
                const SizedBox(height: 16),
                FilledButton(
                  onPressed: _submitting ? null : _submit,
                  child: _submitting
                      ? SizedBox.square(
                          dimension: 22,
                          child: CircularProgressIndicator(
                            strokeWidth: 2.5,
                            color: context.colors.onAct,
                          ),
                        )
                      : Text(l.signIn),
                ),
              ],
            ),
          ),
        ),
      );
    }
    ```

- [ ] **Step 6: Localize `lib/features/auth/presentation/register_page.dart`.**
  - Same import changes. Replace `String? _error` with `AppFailure? _failure`, set the same way as in login.
  - `AuthScaffold(title: l.registerTitle, lead: l.registerLead, switchLabel: l.haveAccountSignIn, onSwitch: () => context.pushReplacement('/login'), ...)`.
  - Hints: `l.fullName`, `l.username`, `l.email`, `l.password`.
  - Validators: `l.nameRequired`, `l.usernameRequired`; the email validator returns `l.emailRequired` or `l.emailInvalid`; the password validator returns `l.passwordRequired` or `l.passwordTooShort`.
  - The submit button text is `l.signUp`. The spinner color is `context.colors.onAct`.
  - On success: `showAppSnackBar(context, l.accountCreated);`.
  - Error banner: `if (_failure != null) FormErrorBanner(failureText(l, _failure!))`.
  - In `_RegionPicker`:
    - Hint: `regions.isLoading ? l.loadingRegions : regions.hasError ? l.regionsFailed : l.chooseRegion`.
    - Validator: `v == null ? l.regionRequired : null`.
    - Retry tooltip: `l.retry`.
    - Delete the `DecoratedBox` shadow wrapper and the custom `pill` borders. Keep only:
      ```dart
      decoration: InputDecoration(
        prefixIcon: Icon(Icons.location_on_outlined, color: context.colors.inkMuted, size: 20),
        suffixIcon: regions.hasError
            ? IconButton(
                tooltip: l.retry,
                icon: const Icon(Icons.refresh_rounded),
                onPressed: onRetry,
              )
            : null,
      ),
      ```
    - Get `l` with `final l = AppLocalizations.of(context);` at the top of `_RegionPicker.build`.

- [ ] **Step 7: Run the tests.**
  Run: `fl test`
  Expected: PASS.

- [ ] **Step 8: Commit.**
  ```bash
  git add lib/features/auth/presentation lib/core/widgets/pill_text_field.dart test/presentation/login_test.dart test/presentation/widgets_test.dart
  git commit -m "feat(mobile): sky-and-paper login and register, localized errors" -m "Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>" -- lib/features/auth/presentation lib/core/widgets/pill_text_field.dart test/presentation/login_test.dart test/presentation/widgets_test.dart
  ```

---

### Task 11: People list (sky header, filters, status chips)

**Files:**
- Create: `lib/features/people/presentation/people_filter.dart`
- Rewrite: `lib/features/people/presentation/people_list_page.dart`
- Test: `test/domain/people_filter_test.dart`; update the people-list test in `test/presentation/widgets_test.dart`; add `test/presentation/people_list_test.dart`

**Interfaces:**
- Consumes: `SkyBand` (Task 6), `StatusChip` (Task 7), `ramadanDay` and `ltr` (Task 5), `clockProvider`, `appConfigProvider`.
- Produces:
  - `enum PeopleFilter { all, waiting, served }`.
  - `PeopleCounts countPeople(Iterable<FastingPerson>, DateTime now)`, a record `({int total, int waiting, int served})`.
  - `List<FastingPerson> applyPeopleFilter(Iterable<FastingPerson>, {required PeopleFilter filter, required String query, required DateTime now})`.
  - `peopleFilterProvider`, with `select(PeopleFilter)`.

- [ ] **Step 1: Write the failing tests.**

  `test/domain/people_filter_test.dart`:
  ```dart
  import 'package:flutter_test/flutter_test.dart';
  import 'package:iftar_mobile/features/people/presentation/people_filter.dart';

  import '../support/fakes.dart';

  void main() {
    final people = [
      person(1, first: 'Najwa', last: 'Chalbi'),
      person(2, first: 'Aziza', last: 'Ouerghi', takenToday: true),
      person(3, first: 'Najib', last: 'Saidi'),
    ];

    test('counts waiting and served tonight', () {
      final c = countPeople(people, testNow);
      expect((c.total, c.waiting, c.served), (3, 2, 1));
    });

    test('filters combine with the search query', () {
      List<int> ids(PeopleFilter f, String q) => [
        for (final p in applyPeopleFilter(people, filter: f, query: q, now: testNow)) p.id,
      ];
      expect(ids(PeopleFilter.all, ''), [1, 2, 3]);
      expect(ids(PeopleFilter.waiting, ''), [1, 3]);
      expect(ids(PeopleFilter.served, ''), [2]);
      expect(ids(PeopleFilter.waiting, 'naj'), [1, 3]);
      expect(ids(PeopleFilter.served, 'naj'), isEmpty);
    });
  }
  ```

  `test/presentation/people_list_test.dart`:
  ```dart
  import 'package:flutter/material.dart';
  import 'package:flutter_test/flutter_test.dart';
  import 'package:iftar_mobile/features/people/presentation/people_list_page.dart';

  import '../support/app_harness.dart';
  import '../support/fakes.dart';

  void main() {
    testWidgets('Waiting and Served filters narrow the list', (tester) async {
      final repo = FakePeopleRepository([
        person(1, first: 'Najwa', last: 'Chalbi'),
        person(2, first: 'Aziza', last: 'Ouerghi', takenToday: true),
      ]);
      await tester.pumpWidget(localizedApp(const PeopleListPage(), overrides: testOverrides(repo)));
      await tester.pumpAndSettle();

      await tester.tap(find.text(en.filterWaiting));
      await tester.pumpAndSettle();
      expect(find.text('Najwa Chalbi'), findsOneWidget);
      expect(find.text('Aziza Ouerghi'), findsNothing);

      await tester.tap(find.text(en.filterServed));
      await tester.pumpAndSettle();
      expect(find.text('Najwa Chalbi'), findsNothing);
      expect(find.text('Aziza Ouerghi'), findsOneWidget);

      await tester.tap(find.text(en.filterAll));
      await tester.pumpAndSettle();
    });

    testWidgets('everyone served shows a calm empty state', (tester) async {
      final repo = FakePeopleRepository([person(2, takenToday: true)]);
      await tester.pumpWidget(localizedApp(const PeopleListPage(), overrides: testOverrides(repo)));
      await tester.pumpAndSettle();
      await tester.tap(find.text(en.filterWaiting));
      await tester.pumpAndSettle();
      expect(find.text(en.everyoneServed), findsOneWidget);
      await tester.tap(find.text(en.filterAll));
      await tester.pumpAndSettle();
    });

    testWidgets('very long names ellipsize in Arabic at 360 px', (tester) async {
      tester.view.physicalSize = const Size(1080, 2280);
      tester.view.devicePixelRatio = 3;
      addTearDown(tester.view.reset);
      final repo = FakePeopleRepository([
        person(1, first: 'Mohamed Ali Ben Abdelkader', last: 'Trabelsi El Kairouani'),
      ]);
      await tester.pumpWidget(localizedApp(
        const PeopleListPage(),
        locale: const Locale('ar'),
        overrides: testOverrides(repo),
      ));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    });
  }
  ```
  Each test that changes the filter switches it back to `all`, because `peopleFilterProvider` lives for the whole `ProviderScope` and each test has its own scope anyway.

  In `test/presentation/widgets_test.dart`, update the people-list test:
  - `find.text('List of fasting people')` becomes `find.text(en.peopleTitle)`.
  - `find.textContaining('No match')` becomes `find.textContaining('No one matches')`.

- [ ] **Step 2: Run them to verify they fail.**
  Run: `fl test test/domain/people_filter_test.dart test/presentation/people_list_test.dart test/presentation/widgets_test.dart`
  Expected: FAIL.

- [ ] **Step 3: Create `lib/features/people/presentation/people_filter.dart`.**
  ```dart
  import 'package:flutter_riverpod/flutter_riverpod.dart';

  import '../domain/fasting_person.dart';

  enum PeopleFilter { all, waiting, served }

  typedef PeopleCounts = ({int total, int waiting, int served});

  PeopleCounts countPeople(Iterable<FastingPerson> people, DateTime now) {
    var served = 0;
    var total = 0;
    for (final p in people) {
      total++;
      if (p.isMealTakenToday(now)) served++;
    }
    return (total: total, waiting: total - served, served: served);
  }

  List<FastingPerson> applyPeopleFilter(
    Iterable<FastingPerson> people, {
    required PeopleFilter filter,
    required String query,
    required DateTime now,
  }) => [
    for (final p in people)
      if (p.matches(query) &&
          switch (filter) {
            PeopleFilter.all => true,
            PeopleFilter.waiting => !p.isMealTakenToday(now),
            PeopleFilter.served => p.isMealTakenToday(now),
          })
        p,
  ];

  class PeopleFilterController extends Notifier<PeopleFilter> {
    @override
    PeopleFilter build() => PeopleFilter.all;

    void select(PeopleFilter filter) => state = filter;
  }

  final peopleFilterProvider =
      NotifierProvider<PeopleFilterController, PeopleFilter>(
        PeopleFilterController.new,
      );
  ```

- [ ] **Step 4: Rewrite `lib/features/people/presentation/people_list_page.dart`.**
  ```dart
  import 'package:flutter/material.dart';
  import 'package:flutter_riverpod/flutter_riverpod.dart';
  import 'package:go_router/go_router.dart';

  import '../../../core/network/app_failure.dart';
  import '../../../core/network/failure_text.dart';
  import '../../../core/providers.dart';
  import '../../../core/theme/app_colors.dart';
  import '../../../core/theme/iftar_colors.dart';
  import '../../../core/utils/formatters.dart';
  import '../../../core/utils/ramadan.dart';
  import '../../../core/widgets/night_sky.dart';
  import '../../../core/widgets/state_views.dart';
  import '../../../core/widgets/status_chip.dart';
  import '../../../l10n/app_localizations.dart';
  import '../domain/fasting_person.dart';
  import 'people_controller.dart';
  import 'people_filter.dart';

  class PeopleListPage extends ConsumerStatefulWidget {
    const PeopleListPage({super.key});

    @override
    ConsumerState<PeopleListPage> createState() => _PeopleListPageState();
  }

  class _PeopleListPageState extends ConsumerState<PeopleListPage> {
    late final TextEditingController _search = TextEditingController(
      text: ref.read(peopleSearchQueryProvider),
    );

    @override
    void dispose() {
      _search.dispose();
      super.dispose();
    }

    Future<void> _refresh() async {
      try {
        await ref.read(peopleListProvider.notifier).refresh();
      } on AppFailure catch (e) {
        if (!mounted) return;
        final l = AppLocalizations.of(context);
        showAppSnackBar(
          context,
          e is NetworkFailure ? l.offlineLastList : failureText(l, e),
          isError: true,
        );
      }
    }

    @override
    Widget build(BuildContext context) {
      final l = AppLocalizations.of(context);
      final people = ref.watch(peopleListProvider);
      final query = ref.watch(peopleSearchQueryProvider);
      final filter = ref.watch(peopleFilterProvider);
      final now = ref.watch(clockProvider)();
      final day = ramadanDay(ref.watch(appConfigProvider).ramadanStart, now);

      return Scaffold(
        body: RefreshIndicator(
          onRefresh: _refresh,
          edgeOffset: 200,
          child: CustomScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            slivers: [
              SliverToBoxAdapter(
                child: _Header(
                  ramadanDay: day,
                  counts: people.hasValue ? countPeople(people.value!, now) : null,
                  controller: _search,
                  onQueryChanged: ref.read(peopleSearchQueryProvider.notifier).update,
                ),
              ),
              if (people.hasValue && people.value!.isNotEmpty)
                SliverToBoxAdapter(
                  child: _FilterRow(
                    counts: countPeople(people.value!, now),
                    selected: filter,
                    onSelect: ref.read(peopleFilterProvider.notifier).select,
                  ),
                ),
              ...switch (people) {
                AsyncData(:final value) => _listSlivers(l, value, query, filter, now),
                AsyncError(:final error) when !people.hasValue => [
                  SliverFillRemaining(
                    hasScrollBody: false,
                    child: ErrorView(
                      failure: toAppFailure(error),
                      onRetry: () => ref.invalidate(peopleListProvider),
                    ),
                  ),
                ],
                _ when people.hasValue => _listSlivers(l, people.value!, query, filter, now),
                _ => [
                  SliverFillRemaining(
                    hasScrollBody: false,
                    child: LoadingView(message: l.loading),
                  ),
                ],
              },
              const SliverToBoxAdapter(child: SizedBox(height: 96)),
            ],
          ),
        ),
      );
    }

    List<Widget> _listSlivers(
      AppLocalizations l,
      List<FastingPerson> all,
      String query,
      PeopleFilter filter,
      DateTime now,
    ) {
      if (all.isEmpty) {
        return [
          SliverFillRemaining(
            hasScrollBody: false,
            child: EmptyView(
              icon: Icons.groups_2_outlined,
              title: l.noPeopleTitle,
              message: l.noPeopleMessage,
              action: FilledButton.icon(
                onPressed: () => context.go('/add'),
                icon: const Icon(Icons.person_add_alt_1_rounded),
                label: Text(l.addPerson),
              ),
            ),
          ),
        ];
      }
      final filtered = applyPeopleFilter(all, filter: filter, query: query, now: now);
      if (filtered.isEmpty) {
        final noQuery = query.trim().isEmpty;
        return [
          SliverFillRemaining(
            hasScrollBody: false,
            child: EmptyView(
              icon: noQuery ? Icons.nightlight_round : Icons.search_off_rounded,
              title: noQuery && filter == PeopleFilter.waiting
                  ? l.everyoneServed
                  : l.noMatch(isolate(query.trim())),
              message: noQuery ? null : l.searchTip,
            ),
          ),
        ];
      }
      return [
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(14, 10, 14, 0),
          sliver: SliverList.separated(
            itemCount: filtered.length,
            separatorBuilder: (_, _) => const SizedBox(height: 10),
            itemBuilder: (context, i) => _PersonTile(
              person: filtered[i],
              now: now,
              onTap: () => context.push('/people/${filtered[i].id}'),
            ),
          ),
        ),
      ];
    }
  }

  class _Header extends StatelessWidget {
    const _Header({
      required this.ramadanDay,
      required this.counts,
      required this.controller,
      required this.onQueryChanged,
    });

    final int? ramadanDay;
    final PeopleCounts? counts;
    final TextEditingController controller;
    final ValueChanged<String> onQueryChanged;

    @override
    Widget build(BuildContext context) {
      final l = AppLocalizations.of(context);
      final counts = this.counts;
      return SkyBand(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (ramadanDay != null)
              Row(
                children: [
                  const Icon(Icons.nightlight_round, size: 14, color: AppPalette.gold),
                  const SizedBox(width: 6),
                  Text(
                    l.ramadanDay(ramadanDay!),
                    style: const TextStyle(fontSize: 12, color: AppPalette.gold),
                  ),
                ],
              ),
            const SizedBox(height: 4),
            Text(
              l.peopleTitle,
              style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w500),
            ),
            if (counts != null) ...[
              const SizedBox(height: 2),
              Text(
                l.peopleCount(counts.total, counts.served),
                style: const TextStyle(fontSize: 13, color: AppPalette.onSkyMuted),
              ),
              const SizedBox(height: 10),
              ClipRRect(
                borderRadius: BorderRadius.circular(3),
                child: LinearProgressIndicator(
                  value: counts.total == 0 ? 0 : counts.served / counts.total,
                  minHeight: 3,
                  color: AppPalette.mint,
                  backgroundColor: AppPalette.onSky.withValues(alpha: 0.14),
                ),
              ),
            ],
            const SizedBox(height: 14),
            TextField(
              controller: controller,
              onChanged: onQueryChanged,
              textInputAction: TextInputAction.search,
              decoration: InputDecoration(
                hintText: l.searchPeople,
                prefixIcon: const Icon(Icons.search_rounded),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(AppRadii.field),
                  borderSide: BorderSide.none,
                ),
                suffixIcon: ListenableBuilder(
                  listenable: controller,
                  builder: (context, _) => controller.text.isEmpty
                      ? const SizedBox.shrink()
                      : IconButton(
                          tooltip: l.clearSearch,
                          icon: const Icon(Icons.close_rounded),
                          onPressed: () {
                            controller.clear();
                            onQueryChanged('');
                          },
                        ),
                ),
              ),
            ),
          ],
        ),
      );
    }
  }

  class _FilterRow extends StatelessWidget {
    const _FilterRow({required this.counts, required this.selected, required this.onSelect});

    final PeopleCounts counts;
    final PeopleFilter selected;
    final ValueChanged<PeopleFilter> onSelect;

    @override
    Widget build(BuildContext context) {
      final l = AppLocalizations.of(context);
      final items = [
        (PeopleFilter.all, l.filterAll, counts.total),
        (PeopleFilter.waiting, l.filterWaiting, counts.waiting),
        (PeopleFilter.served, l.filterServed, counts.served),
      ];
      return Padding(
        padding: const EdgeInsetsDirectional.fromSTEB(14, 12, 14, 2),
        child: Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final (filter, label, count) in items)
              _FilterChip(
                label: label,
                count: count,
                selected: filter == selected,
                onTap: () => onSelect(filter),
              ),
          ],
        ),
      );
    }
  }

  class _FilterChip extends StatelessWidget {
    const _FilterChip({
      required this.label,
      required this.count,
      required this.selected,
      required this.onTap,
    });

    final String label;
    final int count;
    final bool selected;
    final VoidCallback onTap;

    @override
    Widget build(BuildContext context) {
      final c = context.colors;
      final fg = selected ? AppPalette.onSky : c.inkMuted;
      return Semantics(
        button: true,
        selected: selected,
        child: InkWell(
          borderRadius: BorderRadius.circular(999),
          onTap: onTap,
          child: Container(
            constraints: const BoxConstraints(minHeight: 36),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
            decoration: BoxDecoration(
              color: selected ? AppPalette.sky : c.surface,
              border: Border.all(color: selected ? AppPalette.sky : c.line),
              borderRadius: BorderRadius.circular(999),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(label, style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w500, color: fg)),
                const SizedBox(width: 6),
                Text(
                  ltr('$count'),
                  style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600, color: fg),
                ),
              ],
            ),
          ),
        ),
      );
    }
  }

  class _PersonTile extends StatelessWidget {
    const _PersonTile({required this.person, required this.now, required this.onTap});

    final FastingPerson person;
    final DateTime now;
    final VoidCallback onTap;

    @override
    Widget build(BuildContext context) {
      final c = context.colors;
      final l = AppLocalizations.of(context);
      final meals = [
        if (person.singleMeal > 0) l.mealSingleCount(person.singleMeal),
        if (person.familyMeal > 0) l.mealFamilyCount(person.familyMeal),
      ].join(' · ');
      return Card(
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                Container(
                  constraints: const BoxConstraints(minWidth: 50),
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 6),
                  decoration: BoxDecoration(
                    color: c.chip,
                    borderRadius: BorderRadius.circular(AppRadii.chip),
                  ),
                  child: Text(
                    ltr(person.id.toString().padLeft(4, '0')),
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: c.chipInk,
                      fontFeatures: const [FontFeature.tabularFigures()],
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        person.fullName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w500),
                      ),
                      const SizedBox(height: 3),
                      Row(
                        children: [
                          StatusChip(person: person, now: now),
                          const SizedBox(width: 6),
                          Flexible(
                            child: Text(
                              meals,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(fontSize: 12, color: c.inkMuted),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                Icon(Icons.chevron_right_rounded, color: c.inkMuted),
              ],
            ),
          ),
        ),
      );
    }
  }
  ```

- [ ] **Step 5: Run the tests.**
  Run: `fl test`
  Expected: PASS.

- [ ] **Step 6: Commit.**
  ```bash
  git add lib/features/people/presentation/people_filter.dart lib/features/people/presentation/people_list_page.dart test/domain/people_filter_test.dart test/presentation/people_list_test.dart test/presentation/widgets_test.dart
  git commit -m "feat(mobile): people list with sky header, waiting/served filters" -m "Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>" -- lib/features/people/presentation/people_filter.dart lib/features/people/presentation/people_list_page.dart test/domain/people_filter_test.dart test/presentation/people_list_test.dart test/presentation/widgets_test.dart
  ```

---

### Task 12: Person details, meal history, contact editor

**Files:**
- Modify: `lib/features/people/presentation/person_details_page.dart`, `lib/features/people/presentation/person_widgets.dart` (`showMealHistory`, `showContactEditor`; `MealAllotment` stays until Task 15), `lib/core/widgets/info_tile.dart`
- Test: `test/presentation/person_details_test.dart`

**Interfaces:**
- Consumes: `StatusChip`, `failureText`, `labelTracking`, `ltr`, `isolate`.
- Produces: localized `PersonDetailsPage`, `showMealHistory`, and `showContactEditor` (same signatures); `InfoTile` and `InfoCard` with theme colors.

- [ ] **Step 1: Write the failing test** `test/presentation/person_details_test.dart`:
  ```dart
  import 'package:flutter/material.dart';
  import 'package:flutter_test/flutter_test.dart';
  import 'package:iftar_mobile/features/people/presentation/person_details_page.dart';

  import '../support/app_harness.dart';
  import '../support/fakes.dart';

  void main() {
    testWidgets('an eligible person can be served from details', (tester) async {
      final repo = FakePeopleRepository([person(101)]);
      await tester.pumpWidget(localizedApp(
        const PersonDetailsPage(personId: 101),
        overrides: testOverrides(repo),
      ));
      await tester.pumpAndSettle();
      expect(find.text(en.detailsTitle), findsOneWidget);
      await tester.tap(find.text(en.confirmMeal));
      await tester.pumpAndSettle();
      expect(find.text(en.mealConfirmed), findsOneWidget);
      expect(repo.confirmCalls, 1);
    });

    testWidgets('already served today cannot be served again', (tester) async {
      final repo = FakePeopleRepository([person(102, takenToday: true)]);
      await tester.pumpWidget(localizedApp(
        const PersonDetailsPage(personId: 102),
        overrides: testOverrides(repo),
      ));
      await tester.pumpAndSettle();
      final button = tester.widget<FilledButton>(
        find.ancestor(of: find.text(en.alreadyServedToday), matching: find.byType(FilledButton)),
      );
      expect(button.onPressed, isNull);
    });
  }
  ```
  `FilledButton.icon` creates a `FilledButton` subclass, so `find.byType(FilledButton)` matches it. If it doesn't, use `find.bySubtype<FilledButton>()`.

- [ ] **Step 2: Run it to verify it fails.**
  Run: `fl test test/presentation/person_details_test.dart`
  Expected: FAIL. The strings are still "Person Details" and "Confirm Meal".

- [ ] **Step 3: Restyle `lib/core/widgets/info_tile.dart`.** Replace every `AppColors.*` reference:
  - Icon: `context.colors.goldInk`.
  - Label: `context.colors.inkMuted`.
  - `InfoCard` title: style `TextStyle(color: context.colors.goldInk, fontSize: 12, letterSpacing: labelTracking(context, 1.1), fontWeight: FontWeight.w600)`.

  Add the imports `../theme/iftar_colors.dart` and `../utils/typography.dart`. Keep `../theme/app_colors.dart` for `AppSpacing`.

- [ ] **Step 4: Localize `lib/features/people/presentation/person_widgets.dart`.**
  - Add `import '../../../l10n/app_localizations.dart';` and `import '../../../core/theme/iftar_colors.dart';`.
  - In `showMealHistory`'s builder, get `final l = AppLocalizations.of(context);`. Then:
    - The empty state text is `l.noMealsYet`.
    - The header is `l.mealHistoryTitle(isolate(person.fullName))`.
    - The row leading icon color is `context.colors.goldInk`.
    - The trailing text is `Text(ltr(formatTime(date)), style: TextStyle(color: context.colors.inkMuted))`.
  - In `showContactEditor`, wrap the `AlertDialog` creation with `final l = AppLocalizations.of(context);` inside the builder. Then:
    - Title: `l.contactTitle`.
    - Field labels: `l.phone` and `l.comment`.
    - Buttons: `l.cancel` and `l.save`.

- [ ] **Step 5: Localize `lib/features/people/presentation/person_details_page.dart`.**
  - Add the imports `failure_text.dart`, `iftar_colors.dart`, `status_chip.dart`, and `app_localizations.dart`. Remove the `meal_status_badge.dart` import.
  - Snackbars in `_confirm`:
    - Success: `l.mealConfirmed`.
    - `MealAlreadyTakenFailure`: `e.takenAt == null ? l.alreadyCollected : l.alreadyCollectedAt(ltr(formatTime(e.takenAt!)))`.
    - Other `AppFailure`s: `failureText(l, e)`.

    Get `l` at the start of `_confirm` with `final l = AppLocalizations.of(context);`.
  - `AppBar`: `title: Text(l.detailsTitle)`. The edit action label is `l.edit`.
  - Replace the two `InfoCard`s in `_body`:
    ```dart
    InfoCard(
      title: l.identity,
      children: [
        InfoTile(label: l.identifier, value: ltr('${person.id}')),
        if (person.cin != null) InfoTile(label: l.cinShortLabel, value: person.cin),
        InfoTile(label: l.firstName, value: person.firstName),
        InfoTile(label: l.lastName, value: person.lastName),
        InfoTile(label: l.phone, value: phone, trailing: taken ? null : _editIcon(l, person)),
        InfoTile(label: l.comment, value: comment, trailing: taken ? null : _editIcon(l, person)),
      ],
    ),
    const SizedBox(height: AppSpacing.lg),
    InfoCard(
      title: l.meals,
      children: [
        InfoTile(label: l.singleMeal, value: ltr('${person.singleMeal}')),
        InfoTile(label: l.familyMeal, value: ltr('${person.familyMeal}')),
        InfoTile(
          label: l.mealToday,
          trailing: StatusChip(person: person),
          value: person.lastTakenMeal == null ? null : l.lastMeal(formatDate(person.lastTakenMeal!)),
          onTap: () => showMealHistory(context, person),
        ),
      ],
    ),
    ```
  - Confirm button label: `Text(taken ? l.alreadyServedToday : l.confirmMeal)`. The spinner color is `context.colors.onAct`.
  - History button: `Text(l.mealHistory(person.takenMeals.length))`.
  - `_editIcon(AppLocalizations l, FastingPerson person)` uses `tooltip: l.editContact` and icon color `context.colors.actInk`.
  - `_body` needs `l`: add `final l = AppLocalizations.of(context);` as its first line.

- [ ] **Step 6: Run the tests.**
  Run: `fl test`
  Expected: PASS.

- [ ] **Step 7: Commit.**
  ```bash
  git add lib/features/people/presentation/person_details_page.dart lib/features/people/presentation/person_widgets.dart lib/core/widgets/info_tile.dart test/presentation/person_details_test.dart
  git commit -m "feat(mobile): localized person details, history and contact editor" -m "Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>" -- lib/features/people/presentation/person_details_page.dart lib/features/people/presentation/person_widgets.dart lib/core/widgets/info_tile.dart test/presentation/person_details_test.dart
  ```

---

### Task 13: Add person (scan to fill ID, steppers, duplicate CIN, add another)

**Files:**
- Create: `lib/features/people/domain/person_lookup.dart`, `lib/features/scan/presentation/viewfinder.dart`, `lib/features/scan/presentation/card_id_scanner.dart`
- Rewrite: `lib/features/people/presentation/person_form_page.dart`
- Modify: `test/support/fakes.dart` (implement `create`)
- Test: `test/domain/person_lookup_test.dart`, `test/presentation/person_form_test.dart`

**Interfaces:**
- Consumes: `MealStepper` (Task 7), `SkyBand` (Task 6), `QrPayload` (existing), and `PersonRules` (existing, unchanged).
- Produces:
  - `findByCin(Iterable<FastingPerson>, String cin, {int? excludeId}) → FastingPerson?`.
  - `ArchViewfinderPainter(Color color)`, plus `ArchViewfinderPainter.windowFor(Size) → Rect`.
  - `showCardIdScanner(BuildContext) → Future<int?>`.
  - `typedef CardIdScanner = Future<int?> Function(BuildContext)`.
  - `AddPersonPage({int? initialId, CardIdScanner? scanCardId})`, and `PersonForm({FastingPerson? person, int? initialId, CardIdScanner? scanCardId})`.

- [ ] **Step 1: Write the failing tests.**

  `test/domain/person_lookup_test.dart`:
  ```dart
  import 'package:flutter_test/flutter_test.dart';
  import 'package:iftar_mobile/features/people/domain/fasting_person.dart';
  import 'package:iftar_mobile/features/people/domain/person_lookup.dart';

  void main() {
    const a = FastingPerson(id: 1, firstName: 'A', lastName: 'A', singleMeal: 1, familyMeal: 0, cin: '08123812');
    const b = FastingPerson(id: 2, firstName: 'B', lastName: 'B', singleMeal: 1, familyMeal: 0);

    test('finds another person with the same 8-digit CIN', () {
      expect(findByCin([a, b], '08123812'), a);
      expect(findByCin([a, b], ' 08123812 '), a);
    });

    test('ignores partial CINs and the person being edited', () {
      expect(findByCin([a, b], '0812381'), isNull);
      expect(findByCin([a, b], '08123812', excludeId: 1), isNull);
      expect(findByCin([a, b], '99999999'), isNull);
    });
  }
  ```

  `test/presentation/person_form_test.dart`:
  ```dart
  import 'package:flutter/material.dart';
  import 'package:flutter_test/flutter_test.dart';
  import 'package:iftar_mobile/core/utils/formatters.dart';
  import 'package:iftar_mobile/features/people/domain/fasting_person.dart';
  import 'package:iftar_mobile/features/people/presentation/person_form_page.dart';

  import '../support/app_harness.dart';
  import '../support/fakes.dart';

  void main() {
    late FakePeopleRepository repo;

    setUp(() {
      repo = FakePeopleRepository([
        const FastingPerson(
          id: 142,
          firstName: 'Fatma',
          lastName: 'Trabelsi',
          cin: '08123812',
          singleMeal: 0,
          familyMeal: 1,
        ),
      ]);
    });

    Future<void> pump(WidgetTester tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 3;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(localizedApp(
        AddPersonPage(scanCardId: (_) async => 215),
        overrides: testOverrides(repo),
      ));
      await tester.pumpAndSettle();
    }

    Finder field(String label) => find.ancestor(
      of: find.text(label),
      matching: find.byType(Column),
    ).first;

    testWidgets('scanning the card fills its ID', (tester) async {
      await pump(tester);
      await tester.tap(find.text(en.scanCard));
      await tester.pumpAndSettle();
      expect(find.widgetWithText(TextFormField, '215'), findsOneWidget);
      expect(find.text(en.cardRead(215)), findsOneWidget);
    });

    testWidgets('an already-registered CIN is flagged before saving', (tester) async {
      await pump(tester);
      await tester.enterText(find.descendant(of: field(en.cinLabel), matching: find.byType(TextFormField)), '08123812');
      await tester.pumpAndSettle();
      expect(find.text(en.duplicateCin(isolate('Fatma Trabelsi'), 142)), findsOneWidget);
      expect(find.text(en.openExistingRecord), findsOneWidget);
    });

    testWidgets('steppers update the hand-over line', (tester) async {
      await pump(tester);
      expect(find.text(en.handsOverEachEvening(1)), findsOneWidget); // default: 1 single
      final familyIncrease = find.descendant(
        of: find.ancestor(of: find.text(en.familyMeal), matching: find.byType(Row)).first,
        matching: find.byTooltip(en.increase),
      );
      await tester.tap(familyIncrease);
      await tester.pump();
      expect(find.text(en.handsOverEachEvening(5)), findsOneWidget);
    });

    testWidgets('save and add another stays on a cleared form', (tester) async {
      await pump(tester);
      await tester.tap(find.text(en.scanCard));
      await tester.pumpAndSettle();
      await tester.enterText(find.descendant(of: field(en.firstName), matching: find.byType(TextFormField)), 'Nour');
      await tester.enterText(find.descendant(of: field(en.lastName), matching: find.byType(TextFormField)), 'Saidi');
      await tester.dragUntilVisible(find.text(en.saveAndAddAnother), find.byType(ListView), const Offset(0, -200));
      await tester.tap(find.text(en.saveAndAddAnother));
      await tester.pumpAndSettle();

      expect(repo.people[215]?.fullName, 'Nour Saidi');
      expect(repo.people[215]?.isMealTakenToday(testNow), isTrue); // "Here now" defaults on
      expect(find.text(en.personSavedHandOver(isolate('Nour Saidi'), 1)), findsOneWidget);
      expect(find.widgetWithText(TextFormField, 'Nour'), findsNothing);
      expect(find.widgetWithText(TextFormField, '215'), findsNothing);
    });
  }
  ```

- [ ] **Step 2: Implement `create` in `test/support/fakes.dart`.** Replace the `create` override:
  ```dart
  int createCalls = 0;

  @override
  Future<FastingPerson> create(int regionId, PersonDraft draft) async {
    createCalls++;
    if (people.containsKey(draft.id)) throw const ConflictFailure('exists');
    final cin = draft.cin?.trim();
    final p = FastingPerson(
      id: draft.id,
      firstName: draft.firstName.trim(),
      lastName: draft.lastName.trim(),
      cin: (cin == null || cin.isEmpty) ? null : cin,
      singleMeal: draft.singleMeal,
      familyMeal: draft.familyMeal,
      lastTakenMeal: draft.cameToday ? testNow : null,
      mealTakenTodayFromServer: draft.cameToday,
      takenMeals: draft.cameToday ? [testNow] : const [],
      region: testRegion,
    );
    people[p.id] = p;
    return p;
  }
  ```

- [ ] **Step 3: Run the tests to verify they fail.**
  Run: `fl test test/domain/person_lookup_test.dart test/presentation/person_form_test.dart`
  Expected: FAIL to compile, because `person_lookup.dart` and `AddPersonPage.scanCardId` don't exist.

- [ ] **Step 4: Create `lib/features/people/domain/person_lookup.dart`.**
  ```dart
  import 'fasting_person.dart';

  /// Another registered person with this CIN, if any. Advisory only: it sees
  /// the volunteer's region (the cached list), not the whole database.
  FastingPerson? findByCin(
    Iterable<FastingPerson> people,
    String cin, {
    int? excludeId,
  }) {
    final value = cin.trim();
    if (value.length != 8) return null;
    for (final p in people) {
      if (p.id != excludeId && p.cin?.trim() == value) return p;
    }
    return null;
  }
  ```

- [ ] **Step 5: Create `lib/features/scan/presentation/viewfinder.dart`.**
  ```dart
  import 'package:flutter/material.dart';

  import '../../../core/theme/app_colors.dart';

  /// Dimmed camera with a round-topped arch window and a gold diamond at the
  /// apex (spec §4.6). [color] reflects the scan state.
  class ArchViewfinderPainter extends CustomPainter {
    ArchViewfinderPainter(this.color);

    final Color color;

    static Rect windowFor(Size size) {
      final width = size.shortestSide * 0.42;
      return Rect.fromCenter(
        center: Offset(size.width / 2, size.height * 0.36),
        width: width,
        height: width * 1.1,
      );
    }

    @override
    void paint(Canvas canvas, Size size) {
      final window = windowFor(size);
      final arch = RRect.fromRectAndCorners(
        window,
        topLeft: Radius.circular(window.width / 2),
        topRight: Radius.circular(window.width / 2),
        bottomLeft: const Radius.circular(16),
        bottomRight: const Radius.circular(16),
      );
      canvas
        ..drawPath(
          Path.combine(
            PathOperation.difference,
            Path()..addRect(Offset.zero & size),
            Path()..addRRect(arch),
          ),
          Paint()..color = const Color(0x7A060914),
        )
        ..drawRRect(
          arch,
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = 2.5
            ..color = color,
        );
      final apex = Offset(window.center.dx, window.top);
      const d = 4.5;
      canvas.drawPath(
        Path()
          ..moveTo(apex.dx, apex.dy - d)
          ..lineTo(apex.dx + d, apex.dy)
          ..lineTo(apex.dx, apex.dy + d)
          ..lineTo(apex.dx - d, apex.dy)
          ..close(),
        Paint()..color = AppPalette.gold,
      );
    }

    @override
    bool shouldRepaint(covariant ArchViewfinderPainter old) => old.color != color;
  }
  ```

- [ ] **Step 6: Create `lib/features/scan/presentation/card_id_scanner.dart`.**
  ```dart
  import 'package:flutter/material.dart';
  import 'package:mobile_scanner/mobile_scanner.dart';

  import '../../../core/theme/app_colors.dart';
  import '../../../l10n/app_localizations.dart';
  import '../domain/qr_payload.dart';
  import 'viewfinder.dart';

  typedef CardIdScanner = Future<int?> Function(BuildContext context);

  /// Full-screen camera that reads a blank card's ID for registration.
  Future<int?> showCardIdScanner(BuildContext context) =>
      Navigator.of(context, rootNavigator: true).push<int>(
        MaterialPageRoute(
          fullscreenDialog: true,
          builder: (_) => const CardIdScannerPage(),
        ),
      );

  class CardIdScannerPage extends StatefulWidget {
    const CardIdScannerPage({super.key});

    @override
    State<CardIdScannerPage> createState() => _CardIdScannerPageState();
  }

  class _CardIdScannerPageState extends State<CardIdScannerPage> {
    final _camera = MobileScannerController(
      formats: const [BarcodeFormat.qrCode],
      detectionSpeed: DetectionSpeed.noDuplicates,
    );
    bool _done = false;
    bool _invalid = false;

    @override
    void dispose() {
      _camera.dispose();
      super.dispose();
    }

    void _onDetect(BarcodeCapture capture) {
      if (_done) return;
      for (final barcode in capture.barcodes) {
        final payload = QrPayload.parse(barcode.rawValue);
        if (payload is PersonQr) {
          _done = true;
          Navigator.of(context).pop(payload.personId);
          return;
        }
      }
      if (!_invalid) setState(() => _invalid = true);
    }

    @override
    Widget build(BuildContext context) {
      final l = AppLocalizations.of(context);
      return Scaffold(
        backgroundColor: Colors.black,
        body: Stack(
          fit: StackFit.expand,
          children: [
            MobileScanner(controller: _camera, onDetect: _onDetect),
            IgnorePointer(
              child: CustomPaint(
                painter: ArchViewfinderPainter(
                  _invalid ? AppPalette.gold : AppPalette.onSky,
                ),
              ),
            ),
            SafeArea(
              child: Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.all(8),
                    child: Row(
                      children: [
                        IconButton.filled(
                          style: IconButton.styleFrom(
                            backgroundColor: Colors.black45,
                            foregroundColor: AppPalette.onSky,
                            minimumSize: const Size.square(44),
                          ),
                          tooltip: l.cancel,
                          icon: const Icon(Icons.close_rounded),
                          onPressed: () => Navigator.of(context).pop(),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          l.cardScanTitle,
                          style: const TextStyle(
                            color: AppPalette.onSky,
                            fontSize: 16,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const Spacer(),
                  Padding(
                    padding: const EdgeInsets.all(24),
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.5),
                        borderRadius: BorderRadius.circular(999),
                        border: Border.all(color: AppPalette.gold.withValues(alpha: 0.45)),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                        child: Text(
                          _invalid ? l.cardInvalid : l.scanHint,
                          style: const TextStyle(color: AppPalette.onSky),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      );
    }
  }
  ```

- [ ] **Step 7: Rewrite `lib/features/people/presentation/person_form_page.dart`.**
  ```dart
  import 'package:flutter/material.dart';
  import 'package:flutter/services.dart';
  import 'package:flutter_riverpod/flutter_riverpod.dart';
  import 'package:go_router/go_router.dart';

  import '../../../core/network/app_failure.dart';
  import '../../../core/network/failure_text.dart';
  import '../../../core/theme/app_colors.dart';
  import '../../../core/theme/iftar_colors.dart';
  import '../../../core/utils/formatters.dart';
  import '../../../core/widgets/meal_stepper.dart';
  import '../../../core/widgets/night_sky.dart';
  import '../../../core/widgets/state_views.dart';
  import '../../../l10n/app_localizations.dart';
  import '../../auth/presentation/auth_controller.dart';
  import '../../scan/presentation/card_id_scanner.dart';
  import '../data/people_repository.dart';
  import '../domain/fasting_person.dart';
  import '../domain/person_draft.dart';
  import '../domain/person_lookup.dart';
  import 'people_controller.dart';

  /// Add tab (spec §4.5).
  class AddPersonPage extends StatelessWidget {
    const AddPersonPage({super.key, this.initialId, this.scanCardId});

    final int? initialId;
    final CardIdScanner? scanCardId;

    @override
    Widget build(BuildContext context) {
      final l = AppLocalizations.of(context);
      return Scaffold(
        body: Column(
          children: [
            SkyBand(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 4),
                  Text(l.addTitle, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w500)),
                  Text(l.addSubtitle, style: const TextStyle(fontSize: 13, color: AppPalette.onSkyMuted)),
                ],
              ),
            ),
            Expanded(
              child: PersonForm(
                key: ValueKey(initialId),
                initialId: initialId,
                scanCardId: scanCardId,
              ),
            ),
          ],
        ),
      );
    }
  }

  /// Edit screen.
  class EditPersonPage extends ConsumerWidget {
    const EditPersonPage({super.key, required this.personId});

    final int personId;

    @override
    Widget build(BuildContext context, WidgetRef ref) {
      final person = ref.watch(personDetailsProvider(personId));
      return Scaffold(
        appBar: AppBar(title: Text(AppLocalizations.of(context).editTitle)),
        body: switch (person) {
          AsyncData(:final value) => PersonForm(person: value),
          AsyncError(:final error) => ErrorView(
            failure: toAppFailure(error),
            onRetry: () => ref.invalidate(personDetailsProvider(personId)),
          ),
          _ => const LoadingView(),
        },
      );
    }
  }

  class PersonForm extends ConsumerStatefulWidget {
    const PersonForm({super.key, this.person, this.initialId, this.scanCardId});

    /// Null when creating.
    final FastingPerson? person;
    final int? initialId;

    /// Injectable for tests; defaults to the camera sheet.
    final CardIdScanner? scanCardId;

    bool get isEdit => person != null;

    @override
    ConsumerState<PersonForm> createState() => _PersonFormState();
  }

  class _PersonFormState extends ConsumerState<PersonForm> {
    final _formKey = GlobalKey<FormState>();
    final _idFocus = FocusNode();
    late final _id = TextEditingController(
      text: '${widget.person?.id ?? widget.initialId ?? ''}',
    );
    late final _cin = TextEditingController(text: widget.person?.cin ?? '');
    late final _firstName = TextEditingController(text: widget.person?.firstName ?? '');
    late final _lastName = TextEditingController(text: widget.person?.lastName ?? '');
    late final _phone = TextEditingController(text: widget.person?.phone ?? '');
    late final _comment = TextEditingController(text: widget.person?.comment ?? '');
    late int _single = widget.person?.singleMeal ?? 1;
    late int _family = widget.person?.familyMeal ?? 0;
    late bool _showOptional =
        widget.person?.phone != null || widget.person?.comment != null;
    bool _cameToday = true;
    bool _submitting = false;
    bool _mealsInvalid = false;
    String? _idServerError;

    List<TextEditingController> get _controllers =>
        [_id, _cin, _firstName, _lastName, _phone, _comment];

    @override
    void dispose() {
      for (final c in _controllers) {
        c.dispose();
      }
      _idFocus.dispose();
      super.dispose();
    }

    Future<void> _scanId() async {
      final scanner = widget.scanCardId ?? showCardIdScanner;
      final id = await scanner(context);
      if (id == null || !mounted) return;
      setState(() {
        _id.text = '$id';
        _idServerError = null;
      });
      showAppSnackBar(context, AppLocalizations.of(context).cardRead(id));
    }

    void _resetForNext() {
      _formKey.currentState!.reset();
      for (final c in _controllers) {
        c.clear();
      }
      setState(() {
        _single = 1;
        _family = 0;
        _cameToday = true;
        _showOptional = false;
        _mealsInvalid = false;
      });
      _idFocus.requestFocus();
    }

    Future<void> _submit({bool addAnother = false}) async {
      FocusScope.of(context).unfocus();
      final l = AppLocalizations.of(context);
      final meals = PersonRules.normalizeMeals('$_single', '$_family');
      setState(() {
        _mealsInvalid = meals == null;
        _idServerError = null;
      });
      final valid = _formKey.currentState!.validate();
      if (!valid || meals == null) return;

      final draft = PersonDraft(
        id: int.parse(_id.text.trim()),
        firstName: _firstName.text,
        lastName: _lastName.text,
        cin: _cin.text,
        phone: _phone.text,
        comment: _comment.text,
        singleMeal: meals.single,
        familyMeal: meals.family,
        cameToday: _cameToday,
      );

      setState(() => _submitting = true);
      try {
        final region = regionOf(ref.read(authControllerProvider));
        final repo = ref.read(peopleRepositoryProvider);
        final saved = widget.isEdit
            ? await repo.update(region, draft)
            : await repo.create(region.id, draft);
        ref.read(peopleListProvider.notifier).upsert(saved);
        if (widget.isEdit) ref.invalidate(personDetailsProvider(saved.id));
        if (!mounted) return;
        final name = isolate(saved.fullName);
        showAppSnackBar(
          context,
          widget.isEdit
              ? l.personUpdated
              : draft.cameToday
              ? l.personSavedHandOver(name, saved.totalPortions)
              : l.personSaved(name),
        );
        if (widget.isEdit) {
          context.pop();
        } else {
          _resetForNext();
          if (!addAnother) context.go('/people');
        }
      } on MealAlreadyTakenFailure catch (e) {
        if (mounted) showAppSnackBar(context, failureText(l, e), isError: true);
      } on ConflictFailure {
        setState(() => _idServerError = l.idTaken);
        _formKey.currentState!.validate();
      } on AppFailure catch (e) {
        if (mounted) showAppSnackBar(context, failureText(l, e), isError: true);
      } finally {
        if (mounted) setState(() => _submitting = false);
      }
    }

    Future<void> _delete() async {
      final l = AppLocalizations.of(context);
      final person = widget.person!;
      final c = context.colors;
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: Text(l.deleteTitle),
          content: Text(l.deleteBody(isolate(person.fullName))),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: Text(l.cancel),
            ),
            FilledButton(
              style: FilledButton.styleFrom(
                backgroundColor: c.clay,
                foregroundColor: c.onClay,
                minimumSize: const Size(96, 44),
              ),
              onPressed: () => Navigator.pop(context, true),
              child: Text(l.delete),
            ),
          ],
        ),
      );
      if (confirmed != true) return;

      setState(() => _submitting = true);
      try {
        final region = regionOf(ref.read(authControllerProvider));
        await ref.read(peopleRepositoryProvider).delete(region.id, person.id);
        ref.read(peopleListProvider.notifier).remove(person.id);
        if (!mounted) return;
        showAppSnackBar(context, l.personDeleted(isolate(person.fullName)));
        context.go('/people');
      } on AppFailure catch (e) {
        if (mounted) showAppSnackBar(context, failureText(l, e), isError: true);
      } finally {
        if (mounted) setState(() => _submitting = false);
      }
    }

    @override
    Widget build(BuildContext context) {
      final l = AppLocalizations.of(context);
      final c = context.colors;
      final digitsOnly = [FilteringTextInputFormatter.digitsOnly];

      Widget labeled(String label, Widget field) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsetsDirectional.only(start: 2, bottom: 6),
            child: Text(label, style: TextStyle(fontSize: 12.5, color: c.inkMuted)),
          ),
          field,
        ],
      );

      return Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsetsDirectional.fromSTEB(20, 16, 20, 120),
          children: [
            labeled(
              l.cardId,
              TextFormField(
                controller: _id,
                focusNode: _idFocus,
                enabled: !widget.isEdit,
                keyboardType: TextInputType.number,
                inputFormatters: digitsOnly,
                textDirection: TextDirection.ltr,
                decoration: InputDecoration(
                  prefixIcon: const Icon(Icons.badge_outlined, size: 20),
                  suffixIcon: widget.isEdit
                      ? null
                      : Padding(
                          padding: const EdgeInsetsDirectional.only(end: 6),
                          child: TextButton.icon(
                            onPressed: _scanId,
                            icon: const Icon(Icons.qr_code_scanner_rounded, size: 18),
                            label: Text(l.scanCard),
                          ),
                        ),
                ),
                validator: (v) {
                  if (_idServerError != null) return _idServerError;
                  if (PersonRules.validateId(v) == null) return null;
                  return (v?.trim() ?? '').isEmpty ? l.idRequired : l.idInvalid;
                },
              ),
            ),
            const SizedBox(height: 14),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: labeled(
                    l.firstName,
                    TextFormField(
                      controller: _firstName,
                      textInputAction: TextInputAction.next,
                      validator: (v) =>
                          (v == null || v.trim().isEmpty) ? l.firstNameRequired : null,
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: labeled(
                    l.lastName,
                    TextFormField(
                      controller: _lastName,
                      textInputAction: TextInputAction.next,
                      validator: (v) =>
                          (v == null || v.trim().isEmpty) ? l.lastNameRequired : null,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            labeled(
              l.cinLabel,
              TextFormField(
                controller: _cin,
                keyboardType: TextInputType.number,
                inputFormatters: [
                  FilteringTextInputFormatter.digitsOnly,
                  LengthLimitingTextInputFormatter(PersonRules.cinLength),
                ],
                textDirection: TextDirection.ltr,
                validator: (v) => PersonRules.validateCin(v) == null ? null : l.cinLength,
              ),
            ),
            _DuplicateCinWarning(controller: _cin, excludeId: widget.person?.id),
            const SizedBox(height: 18),
            labeled(
              l.mealsEachEvening,
              Card(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 14),
                  child: Column(
                    children: [
                      MealStepper(
                        label: l.singleMeal,
                        caption: l.portions(1),
                        value: _single,
                        onChanged: (v) => setState(() {
                          _single = v;
                          _mealsInvalid = false;
                        }),
                      ),
                      const Divider(),
                      MealStepper(
                        label: l.familyMeal,
                        caption: l.portions(4),
                        value: _family,
                        onChanged: (v) => setState(() {
                          _family = v;
                          _mealsInvalid = false;
                        }),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsetsDirectional.only(start: 2, top: 8),
              child: Text(
                l.handsOverEachEvening(_single + _family * 4),
                style: TextStyle(fontSize: 12.5, color: c.goldInk),
              ),
            ),
            if (_mealsInvalid)
              Padding(
                padding: const EdgeInsetsDirectional.only(start: 2, top: 6),
                child: Text(l.mealsAtLeastOne, style: TextStyle(color: c.clay)),
              ),
            if (!widget.isEdit) ...[
              const SizedBox(height: 14),
              Card(
                child: SwitchListTile(
                  value: _cameToday,
                  onChanged: (v) => setState(() => _cameToday = v),
                  title: Text(l.hereNow),
                  subtitle: Text(l.hereNowSubtitle),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(AppRadii.card),
                  ),
                ),
              ),
            ],
            const SizedBox(height: 8),
            InkWell(
              onTap: () => setState(() => _showOptional = !_showOptional),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 2),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(l.optionalFields, style: TextStyle(color: c.actInk, fontSize: 14)),
                    ),
                    Icon(
                      _showOptional ? Icons.expand_less_rounded : Icons.expand_more_rounded,
                      color: c.actInk,
                    ),
                  ],
                ),
              ),
            ),
            if (_showOptional) ...[
              labeled(
                l.phone,
                TextFormField(
                  controller: _phone,
                  keyboardType: TextInputType.phone,
                  textDirection: TextDirection.ltr,
                ),
              ),
              const SizedBox(height: 12),
              labeled(
                l.notes,
                TextFormField(controller: _comment, minLines: 1, maxLines: 3),
              ),
            ],
            const SizedBox(height: 22),
            FilledButton(
              onPressed: _submitting ? null : _submit,
              child: _submitting
                  ? SizedBox.square(
                      dimension: 22,
                      child: CircularProgressIndicator(strokeWidth: 2.5, color: c.onAct),
                    )
                  : Text(
                      widget.isEdit
                          ? l.updatePerson
                          : _cameToday
                          ? l.saveAndHandOver
                          : l.save,
                    ),
            ),
            if (!widget.isEdit)
              TextButton(
                onPressed: _submitting ? null : () => _submit(addAnother: true),
                child: Text(l.saveAndAddAnother),
              ),
            if (widget.isEdit) ...[
              const SizedBox(height: 12),
              OutlinedButton.icon(
                style: OutlinedButton.styleFrom(
                  foregroundColor: c.clay,
                  side: BorderSide(color: c.clay),
                ),
                onPressed: _submitting ? null : _delete,
                icon: const Icon(Icons.delete_outline_rounded),
                label: Text(l.deletePerson),
              ),
            ],
          ],
        ),
      );
    }
  }

  /// Advisory duplicate check against the cached region list (spec §4.5).
  class _DuplicateCinWarning extends ConsumerWidget {
    const _DuplicateCinWarning({required this.controller, this.excludeId});

    final TextEditingController controller;
    final int? excludeId;

    @override
    Widget build(BuildContext context, WidgetRef ref) {
      final people = ref.watch(peopleListProvider).value ?? const <FastingPerson>[];
      return ListenableBuilder(
        listenable: controller,
        builder: (context, _) {
          final duplicate = findByCin(people, controller.text, excludeId: excludeId);
          if (duplicate == null) return const SizedBox.shrink();
          final l = AppLocalizations.of(context);
          final c = context.colors;
          return Container(
            margin: const EdgeInsets.only(top: 8),
            padding: const EdgeInsets.fromLTRB(12, 10, 12, 4),
            decoration: BoxDecoration(
              color: c.claySoft,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  l.duplicateCin(isolate(duplicate.fullName), duplicate.id),
                  style: TextStyle(color: c.clayInk, fontSize: 12.5),
                ),
                TextButton(
                  style: TextButton.styleFrom(foregroundColor: c.clayInk, padding: EdgeInsets.zero),
                  onPressed: () => context.push('/people/${duplicate.id}'),
                  child: Text(l.openExistingRecord),
                ),
              ],
            ),
          );
        },
      );
    }
  }
  ```
  `FilledButton(onPressed: _submitting ? null : _submit, …)` works because `_submit`'s only parameter is optional and named, so it's assignable to `VoidCallback`.

- [ ] **Step 8: Run the tests.**
  Run: `fl test`
  Expected: PASS. The router's `/add?id=` still passes `initialId`.

- [ ] **Step 9: Commit.**
  ```bash
  git add lib/features/people/domain/person_lookup.dart lib/features/scan/presentation/viewfinder.dart lib/features/scan/presentation/card_id_scanner.dart lib/features/people/presentation/person_form_page.dart test/support/fakes.dart test/domain/person_lookup_test.dart test/presentation/person_form_test.dart
  git commit -m "feat(mobile): register by scanning the card, meal steppers, duplicate CIN, add another" -m "Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>" -- lib/features/people/domain/person_lookup.dart lib/features/scan/presentation/viewfinder.dart lib/features/scan/presentation/card_id_scanner.dart lib/features/people/presentation/person_form_page.dart test/support/fakes.dart test/domain/person_lookup_test.dart test/presentation/person_form_test.dart
  ```

---

### Task 14: Scan controller (instant identify, find-without-card entry, session stats)

**Files:**
- Modify: `lib/features/scan/presentation/scan_controller.dart`
- Modify: `lib/features/scan/presentation/scan_page.dart` and `scan_result_panel.dart` (only the exhaustive switches; Task 17 rewrites both)
- Modify: `test/support/fakes.dart` (adds `getGate`)
- Test: append to `test/presentation/scan_controller_test.dart`

**Interfaces:**
- Consumes: `peopleListProvider` (cached list).
- Produces:
  - `ScanIdentifying(FastingPerson person, {bool noCard = false})`.
  - `ScanLookingUp(int personId, {bool noCard = false})`.
  - `ScanReady(person, {phone, comment, bool noCard = false})`.
  - `ScanState.singleMeals` and `.familyMeals`.
  - `ScanController.pickWithoutCard(int personId)`.

  All existing names and behaviors stay.

- [ ] **Step 1: Add a gate to the fake.** In `FakePeopleRepository` (`test/support/fakes.dart`), add the field `Completer<void>? getGate;` and the import `dart:async`. Make `get` start with:
  ```dart
  final gate = getGate;
  if (gate != null) {
    getGate = null;
    await gate.future;
  }
  ```

- [ ] **Step 2: Write the failing tests.** Append to `test/presentation/scan_controller_test.dart` inside `main()`. Also add the imports `dart:async` and `package:iftar_mobile/features/people/presentation/people_controller.dart`.
  ```dart
  group('instant identify from the phone list', () {
    test('a cached person shows their name first, then the server verdict', () async {
      await container.read(peopleListProvider.future); // prime the cache
      final seen = <ScanStatus>[];
      container.listen(
        scanControllerProvider.select((s) => s.status),
        (_, next) => seen.add(next),
      );
      await controller().onDetected('101');
      expect(seen.first, isA<ScanIdentifying>());
      expect((seen.first as ScanIdentifying).person.fullName, 'Najwa Chalbi');
      expect(seen.last, isA<ScanReady>());
    });

    test('a person not on the phone goes through looking up', () async {
      final seen = <ScanStatus>[];
      container.listen(
        scanControllerProvider.select((s) => s.status),
        (_, next) => seen.add(next),
      );
      await controller().onDetected('101');
      expect(seen.first, isA<ScanLookingUp>());
      expect(seen.last, isA<ScanReady>());
    });

    test('cards are ignored while identifying', () async {
      await container.read(peopleListProvider.future);
      final gate = Completer<void>();
      repo.getGate = gate;
      final pending = controller().onDetected('101');
      expect(state().status, isA<ScanIdentifying>());
      expect(state().acceptsScans, isFalse);
      await controller().onDetected('102');
      gate.complete();
      await pending;
      expect((state().status as ScanReady).person.id, 101);
    });
  });

  test('picking someone without a card asks for the CIN check', () async {
    await controller().pickWithoutCard(101);
    final status = state().status;
    expect(status, isA<ScanReady>());
    expect((status as ScanReady).noCard, isTrue);
    controller().editContact(phone: '22123456', comment: '');
    expect((state().status as ScanReady).noCard, isTrue, reason: 'kept on edit');
  });

  test('session stats count the meals handed over', () async {
    await controller().onDetected('101'); // person(): 2 single, 1 family
    await controller().confirm();
    expect(state().servedCount, 1);
    expect(state().singleMeals, 2);
    expect(state().familyMeals, 1);
  });
  ```

- [ ] **Step 3: Run them to verify they fail.**
  Run: `fl test test/presentation/scan_controller_test.dart`
  Expected: FAIL to compile, because `ScanIdentifying`, `pickWithoutCard`, and `singleMeals` don't exist.

- [ ] **Step 4: Update `lib/features/scan/presentation/scan_controller.dart`.**
  - Replace `ScanLookingUp` and add `ScanIdentifying` right after it:
    ```dart
    /// Not on this phone yet: only the ID is known while the server answers.
    final class ScanLookingUp extends ScanStatus {
      const ScanLookingUp(this.personId, {this.noCard = false});
      final int personId;
      final bool noCard;
    }

    /// On this phone: name and meals show now while tonight's status is
    /// checked with the server (spec §6.3). Display only, never a verdict.
    final class ScanIdentifying extends ScanStatus {
      const ScanIdentifying(this.person, {this.noCard = false});
      final FastingPerson person;
      final bool noCard;
    }
    ```
  - Replace `ScanReady`:
    ```dart
    /// Eligible: has not collected today. Holds pending phone/comment edits.
    final class ScanReady extends ScanStatus {
      const ScanReady(this.person, {this.phone, this.comment, this.noCard = false});
      final FastingPerson person;
      final String? phone;
      final String? comment;

      /// Found without a card: the volunteer checks the CIN's last digits.
      final bool noCard;
    }
    ```
  - Replace `ScanState`:
    ```dart
    class ScanState {
      const ScanState({
        this.status = const ScanIdle(),
        this.servedCount = 0,
        this.singleMeals = 0,
        this.familyMeals = 0,
      });

      final ScanStatus status;

      /// Meals confirmed from this device since the scanner was opened.
      final int servedCount;

      /// Meals handed over this session, for the closing summary.
      final int singleMeals;
      final int familyMeals;

      /// Whether a new camera detection should be processed right now.
      /// Busy or pending-decision states ignore the camera, so a volunteer never
      /// loses an unconfirmed person by accidentally scanning another card.
      bool get acceptsScans => switch (status) {
        ScanIdle() ||
        ScanInvalidCode() ||
        ScanNotFound() ||
        ScanAlreadyTaken() ||
        ScanConfirmed() => true,
        ScanFailed(:final duringConfirm) => !duringConfirm,
        ScanLookingUp() || ScanIdentifying() || ScanReady() || ScanConfirming() => false,
      };

      ScanState copyWith({
        ScanStatus? status,
        int? servedCount,
        int? singleMeals,
        int? familyMeals,
      }) => ScanState(
        status: status ?? this.status,
        servedCount: servedCount ?? this.servedCount,
        singleMeals: singleMeals ?? this.singleMeals,
        familyMeals: familyMeals ?? this.familyMeals,
      );
    }
    ```
  - In `ScanController`, add the `_busy` getter and `pickWithoutCard`, and make `submitManual` use `_busy`:
    ```dart
    bool get _busy => switch (state.status) {
      ScanLookingUp() || ScanIdentifying() || ScanConfirming() => true,
      _ => false,
    };

    /// Manual ID (damaged card) — also used by "Look up card #N" in Find.
    Future<void> submitManual(String input) async {
      if (_busy) return;
      _lastRaw = input.trim();
      _lastSeenAt = _now();
      await _handle(input);
    }

    /// "Find someone without a card" (spec §4.7): same flow, plus the CIN check.
    Future<void> pickWithoutCard(int personId) async {
      if (_busy) return;
      _resumeTimer?.cancel();
      _confirmMayHaveReachedServer = false;
      _lastRaw = '$personId';
      _lastSeenAt = _now();
      await _lookup(personId, noCard: true);
    }
    ```
  - Replace `_lookup` and `_stillLookingUp`, and add `_cached`:
    ```dart
    Future<void> _lookup(int personId, {bool noCard = false}) async {
      final cached = _cached(personId);
      _set(
        cached == null
            ? ScanLookingUp(personId, noCard: noCard)
            : ScanIdentifying(cached, noCard: noCard),
      );
      try {
        final region = requireRegion(ref);
        final person = await ref
            .read(peopleRepositoryProvider)
            .get(region.id, personId);
        if (!_stillLookingUp(personId)) return;
        ref.read(peopleListProvider.notifier).upsert(person);
        // The verdict always comes from the server response.
        _set(
          person.isMealTakenToday(_now())
              ? ScanAlreadyTaken(person, person.lastTakenMeal)
              : ScanReady(person, noCard: noCard),
        );
      } on NotFoundFailure {
        if (_stillLookingUp(personId)) _set(ScanNotFound(personId));
      } catch (e) {
        if (_stillLookingUp(personId)) {
          _set(ScanFailed(toAppFailure(e), personId: personId));
        }
      }
    }

    FastingPerson? _cached(int id) {
      for (final p in ref.read(peopleListProvider).value ?? const <FastingPerson>[]) {
        if (p.id == id) return p;
      }
      return null;
    }

    bool _stillLookingUp(int id) =>
        ref.mounted &&
        switch (state.status) {
          ScanLookingUp(:final personId) => personId == id,
          ScanIdentifying(:final person) => person.id == id,
          _ => false,
        };
    ```
  - Make `editContact` keep the flag:
    ```dart
    void editContact({required String phone, required String comment}) {
      if (state.status case ScanReady(:final person, :final noCard)) {
        _set(ScanReady(person, phone: phone, comment: comment, noCard: noCard));
      }
    }
    ```
  - In `_onConfirmed`, replace the `state = state.copyWith(...)` call with:
    ```dart
    state = state.copyWith(
      status: ScanConfirmed(person),
      servedCount: state.servedCount + 1,
      singleMeals: state.singleMeals + person.singleMeal,
      familyMeals: state.familyMeals + person.familyMeal,
    );
    ```

- [ ] **Step 5: Keep the exhaustive switches compiling.** Task 17 replaces both files, so these are minimal patches.
  - In `scan_page.dart` `_hapticsFor`, change the last case to `case ScanIdle() || ScanLookingUp() || ScanIdentifying() || ScanConfirming():`.
  - In `scan_result_panel.dart`:
    - In `_keyFor`, add `ScanIdentifying(:final person) => 'ready-${person.id}',`.
    - In `_content`, add:
      ```dart
      case ScanIdentifying(:final person):
        return _PersonPanel(
          person: person,
          tone: _Tone.neutral,
          headline: 'Checking…',
          busy: true,
        );
      ```

- [ ] **Step 6: Run the tests.**
  Run: `fl test`
  Expected: PASS. All the old controller tests (the safety invariants) are unchanged and green.

- [ ] **Step 7: Commit.**
  ```bash
  git add lib/features/scan/presentation test/support/fakes.dart test/presentation/scan_controller_test.dart
  git commit -m "feat(mobile): identify instantly from the cached list; find-without-card entry; session stats" -m "Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>" -- lib/features/scan/presentation test/support/fakes.dart test/presentation/scan_controller_test.dart
  ```

---

### Task 15: Find without a card (`/find`)

**Files:**
- Create: `lib/features/scan/presentation/find_person_page.dart`
- Modify: `lib/core/router/app_router.dart` (route), `lib/features/people/domain/fasting_person.dart` (accent-insensitive `matches`), `test/support/app_harness.dart` (router harness)
- Test: `test/presentation/find_person_test.dart`; add one test to `test/domain/domain_rules_test.dart`

**Interfaces:**
- Consumes: `peopleListProvider`, `StatusChip`, `maskCin`, and `SkyBand`.
- Produces:
  - `FindPersonPage`, which pops with `int?` (the chosen person ID).
  - The route `/find` on the root navigator.
  - The harness function `localizedRouterApp(GoRouter router, {overrides, locale})`.

- [ ] **Step 1: Write the failing tests.**
  - In `test/domain/domain_rules_test.dart`, add to the `FastingPerson` group:
    ```dart
    test('search ignores case, accents and surrounding spaces', () {
      final p = FastingPerson.fromJson({...json, 'firstName': 'Hédi', 'lastName': 'Jlassi'});
      expect(p.matches('  HEDI '), isTrue);
      expect(p.matches('jlassi hédi'), isTrue);
      expect(p.matches('hadi'), isFalse);
    });
    ```
  - Add to `test/support/app_harness.dart` (plus the import `package:go_router/go_router.dart`):
    ```dart
    Widget localizedRouterApp(
      GoRouter router, {
      List<Override> overrides = const [],
      Locale locale = const Locale('en'),
    }) => ProviderScope(
      overrides: overrides,
      retry: (_, _) => null,
      child: MaterialApp.router(
        routerConfig: router,
        theme: AppTheme.light(),
        locale: locale,
        supportedLocales: AppLocalizations.supportedLocales,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
      ),
    );
    ```
  - Create `test/presentation/find_person_test.dart`:
    ```dart
    import 'package:flutter/material.dart';
    import 'package:flutter_test/flutter_test.dart';
    import 'package:go_router/go_router.dart';
    import 'package:iftar_mobile/features/scan/presentation/find_person_page.dart';

    import '../support/app_harness.dart';
    import '../support/fakes.dart';

    void main() {
      late int? picked;

      GoRouter router() => GoRouter(
        routes: [
          GoRoute(
            path: '/',
            builder: (context, _) => Scaffold(
              body: Center(
                child: TextButton(
                  onPressed: () async => picked = await context.push<int>('/find'),
                  child: const Text('open'),
                ),
              ),
            ),
          ),
          GoRoute(path: '/find', builder: (_, _) => const FindPersonPage()),
        ],
      );

      final repo = FakePeopleRepository([
        person(201, first: 'Hédi', last: 'Jlassi'),
        person(58, first: 'Fatma', last: 'Ben Ali'),
      ]);

      setUp(() => picked = null);

      testWidgets('finds by name ignoring case and accents', (tester) async {
        await tester.pumpWidget(localizedRouterApp(router(), overrides: testOverrides(repo)));
        await tester.tap(find.text('open'));
        await tester.pumpAndSettle();
        expect(find.text(en.findMinChars), findsOneWidget);

        await tester.enterText(find.byType(TextField), '  HEDI ');
        await tester.pumpAndSettle();
        await tester.tap(find.text('Hédi Jlassi'));
        await tester.pumpAndSettle();
        expect(picked, 201);
      });

      testWidgets('a card number not on the phone can still be looked up', (tester) async {
        await tester.pumpWidget(localizedRouterApp(router(), overrides: testOverrides(repo)));
        await tester.tap(find.text('open'));
        await tester.pumpAndSettle();
        await tester.enterText(find.byType(TextField), '777');
        await tester.pumpAndSettle();
        await tester.tap(find.text(en.findLookUpId(777)));
        await tester.pumpAndSettle();
        expect(picked, 777);
      });
    }
    ```

- [ ] **Step 2: Run them to verify they fail.**
  Run: `fl test test/presentation/find_person_test.dart test/domain/domain_rules_test.dart`
  Expected: FAIL.

- [ ] **Step 3: Make the search accent-insensitive** in `lib/features/people/domain/fasting_person.dart`. Replace `matches`, and add `_fold`:
  ```dart
  /// Search by ID, names in any order, CIN or phone; case-, accent- and
  /// space-insensitive ("  HEDI " finds "Hédi").
  bool matches(String query) {
    final q = _fold(query.trim());
    if (q.isEmpty) return true;
    return '$id'.contains(q) ||
        _fold(fullName).contains(q) ||
        _fold('$lastName $firstName').contains(q) ||
        (cin?.toLowerCase().contains(q) ?? false) ||
        (phone?.replaceAll(' ', '').contains(q.replaceAll(' ', '')) ?? false);
  }

  static String _fold(String text) {
    const from = 'àâäáãåçéèêëíìîïñóòôöõúùûüýÿ';
    const to = 'aaaaaaceeeeiiiinooooouuuuyy';
    final out = StringBuffer();
    for (final ch in text.toLowerCase().split('')) {
      final i = from.indexOf(ch);
      out.write(i < 0 ? ch : to[i]);
    }
    return out.toString();
  }
  ```

- [ ] **Step 4: Create `lib/features/scan/presentation/find_person_page.dart`.**
  ```dart
  import 'package:flutter/material.dart';
  import 'package:flutter_riverpod/flutter_riverpod.dart';
  import 'package:go_router/go_router.dart';

  import '../../../core/providers.dart';
  import '../../../core/theme/app_colors.dart';
  import '../../../core/theme/iftar_colors.dart';
  import '../../../core/utils/formatters.dart';
  import '../../../core/utils/masking.dart';
  import '../../../core/widgets/night_sky.dart';
  import '../../../core/widgets/state_views.dart';
  import '../../../core/widgets/status_chip.dart';
  import '../../../l10n/app_localizations.dart';
  import '../../people/domain/fasting_person.dart';
  import '../../people/presentation/people_controller.dart';

  /// "Without a card" (spec §4.7). Searches the phone's list, so it works
  /// offline; pops with the chosen person ID.
  class FindPersonPage extends ConsumerStatefulWidget {
    const FindPersonPage({super.key});

    @override
    ConsumerState<FindPersonPage> createState() => _FindPersonPageState();
  }

  class _FindPersonPageState extends ConsumerState<FindPersonPage> {
    final _query = TextEditingController();

    @override
    void dispose() {
      _query.dispose();
      super.dispose();
    }

    @override
    Widget build(BuildContext context) {
      final l = AppLocalizations.of(context);
      final c = context.colors;
      final people = ref.watch(peopleListProvider).value ?? const <FastingPerson>[];
      final now = ref.watch(clockProvider)();
      final q = _query.text.trim();
      final digits = RegExp(r'^\d+$').hasMatch(q);
      final ready = q.length >= 2 || digits;
      final results = ready ? [for (final p in people) if (p.matches(q)) p] : const <FastingPerson>[];
      final typedId = digits ? int.tryParse(q) : null;
      final offerLookUp =
          typedId != null && typedId > 0 && !results.any((p) => p.id == typedId);

      return Scaffold(
        body: Column(
          children: [
            SkyBand(
              padding: const EdgeInsetsDirectional.fromSTEB(8, 4, 20, 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      IconButton(
                        tooltip: l.back,
                        color: AppPalette.onSky,
                        icon: const BackButtonIcon(),
                        onPressed: () => context.pop(),
                      ),
                      Text(l.findTitle, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w500)),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Padding(
                    padding: const EdgeInsetsDirectional.only(start: 12),
                    child: TextField(
                      controller: _query,
                      autofocus: true,
                      onChanged: (_) => setState(() {}),
                      textInputAction: TextInputAction.search,
                      decoration: InputDecoration(
                        hintText: l.findSearchHint,
                        prefixIcon: const Icon(Icons.search_rounded),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(AppRadii.field),
                          borderSide: BorderSide.none,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: !ready
                  ? Padding(
                      padding: const EdgeInsets.all(20),
                      child: Text(l.findMinChars, style: TextStyle(color: c.inkMuted)),
                    )
                  : ListView(
                      padding: const EdgeInsets.all(14),
                      children: [
                        if (offerLookUp)
                          Card(
                            child: ListTile(
                              leading: Icon(Icons.badge_outlined, color: c.actInk),
                              title: Text(l.findLookUpId(typedId)),
                              onTap: () => context.pop(typedId),
                            ),
                          ),
                        for (final p in results) ...[
                          _ResultRow(person: p, now: now, onTap: () => context.pop(p.id)),
                          const SizedBox(height: 10),
                        ],
                        if (results.isEmpty && !offerLookUp)
                          EmptyView(icon: Icons.search_off_rounded, title: l.noMatch(isolate(q))),
                      ],
                    ),
            ),
          ],
        ),
      );
    }
  }

  class _ResultRow extends StatelessWidget {
    const _ResultRow({required this.person, required this.now, required this.onTap});

    final FastingPerson person;
    final DateTime now;
    final VoidCallback onTap;

    @override
    Widget build(BuildContext context) {
      final c = context.colors;
      final l = AppLocalizations.of(context);
      final masked = maskCin(person.cin);
      return Card(
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                Container(
                  constraints: const BoxConstraints(minWidth: 50),
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(color: c.chip, borderRadius: BorderRadius.circular(AppRadii.chip)),
                  child: Text(
                    ltr(person.id.toString().padLeft(4, '0')),
                    textAlign: TextAlign.center,
                    style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13, color: c.chipInk),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        person.fullName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w500),
                      ),
                      const SizedBox(height: 3),
                      Row(
                        children: [
                          StatusChip(person: person, now: now),
                          if (masked != null) ...[
                            const SizedBox(width: 6),
                            Flexible(
                              child: Text(
                                '${l.cinShortLabel} ${ltr(masked)}',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(fontSize: 12, color: c.inkMuted),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ],
                  ),
                ),
                Icon(Icons.chevron_right_rounded, color: c.inkMuted),
              ],
            ),
          ),
        ),
      );
    }
  }
  ```

- [ ] **Step 5: Register the route** in `lib/core/router/app_router.dart`. Import `find_person_page.dart` and add a root-level route after `/scan`:
  ```dart
  GoRoute(
    path: '/find',
    parentNavigatorKey: _rootKey,
    builder: (_, _) => const FindPersonPage(),
  ),
  ```

- [ ] **Step 6: Run the tests.**
  Run: `fl test`
  Expected: PASS.

- [ ] **Step 7: Commit.**
  ```bash
  git add lib/features/scan/presentation/find_person_page.dart lib/core/router/app_router.dart lib/features/people/domain/fasting_person.dart test/support/app_harness.dart test/presentation/find_person_test.dart test/domain/domain_rules_test.dart
  git commit -m "feat(mobile): find someone without a card (accent-insensitive, offline)" -m "Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>" -- lib/features/scan/presentation/find_person_page.dart lib/core/router/app_router.dart lib/features/people/domain/fasting_person.dart test/support/app_harness.dart test/presentation/find_person_test.dart test/domain/domain_rules_test.dart
  ```

---

### Task 16: Session summary (`/summary`)

**Files:**
- Create: `lib/features/scan/presentation/session_summary_page.dart`
- Modify: `lib/core/router/app_router.dart`, `lib/core/widgets/brand.dart` (adds `blessingText`)
- Test: `test/presentation/session_summary_test.dart`

**Interfaces:**
- Produces:
  - `SessionSummary({required int served, required int singleMeals, required int familyMeals})`, with `portions`.
  - `SessionSummaryPage({required SessionSummary summary})`.
  - The route `/summary`, which takes `extra: SessionSummary` and redirects to `/people` otherwise.
  - `blessingText` (`'تقبّل الله'`).

- [ ] **Step 1: Write the failing test** `test/presentation/session_summary_test.dart`:
  ```dart
  import 'package:flutter_test/flutter_test.dart';
  import 'package:iftar_mobile/core/utils/formatters.dart';
  import 'package:iftar_mobile/core/widgets/brand.dart';
  import 'package:iftar_mobile/features/scan/presentation/session_summary_page.dart';

  import '../support/app_harness.dart';
  import '../support/fakes.dart';

  void main() {
    const summary = SessionSummary(served: 3, singleMeals: 2, familyMeals: 1);

    test('portions count a family meal as four', () {
      expect(summary.portions, 6);
    });

    testWidgets('shows what the volunteer gave tonight and a blessing', (tester) async {
      await tester.pumpWidget(localizedApp(
        const SessionSummaryPage(summary: summary),
        overrides: testOverrides(FakePeopleRepository([])),
      ));
      expect(find.text(ltr('3')), findsOneWidget);
      expect(find.text(en.summaryServedByYou), findsOneWidget);
      expect(find.text(en.summaryDetail(1, 2, 6)), findsOneWidget);
      expect(find.text(blessingText), findsOneWidget);
      expect(find.text(en.backToPeople), findsOneWidget);
      expect(find.text(en.keepScanning), findsOneWidget);
    });
  }
  ```

- [ ] **Step 2: Run it to verify it fails.**
  Run: `fl test test/presentation/session_summary_test.dart`
  Expected: FAIL to compile.

- [ ] **Step 3: Add to `lib/core/widgets/brand.dart`:**
  ```dart
  /// "May God accept it", said after each confirmed iftar (spec §4.6, §4.8).
  const blessingText = 'تقبّل الله';
  ```

- [ ] **Step 4: Create `lib/features/scan/presentation/session_summary_page.dart`.**
  ```dart
  import 'package:flutter/material.dart';
  import 'package:flutter_riverpod/flutter_riverpod.dart';
  import 'package:go_router/go_router.dart';

  import '../../../core/providers.dart';
  import '../../../core/theme/app_colors.dart';
  import '../../../core/theme/app_theme.dart';
  import '../../../core/utils/formatters.dart';
  import '../../../core/utils/ramadan.dart';
  import '../../../core/widgets/brand.dart';
  import '../../../core/widgets/night_sky.dart';
  import '../../../l10n/app_localizations.dart';

  class SessionSummary {
    const SessionSummary({
      required this.served,
      required this.singleMeals,
      required this.familyMeals,
    });

    final int served;
    final int singleMeals;
    final int familyMeals;

    int get portions => singleMeals + familyMeals * 4;
  }

  /// Shown when the volunteer closes the scanner after serving (spec §4.8).
  class SessionSummaryPage extends ConsumerWidget {
    const SessionSummaryPage({super.key, required this.summary});

    final SessionSummary summary;

    @override
    Widget build(BuildContext context, WidgetRef ref) {
      final l = AppLocalizations.of(context);
      final day = ramadanDay(
        ref.watch(appConfigProvider).ramadanStart,
        ref.watch(clockProvider)(),
      );
      return Scaffold(
        backgroundColor: AppPalette.sky,
        body: NightSky(
          dusk: true,
          pattern: true,
          starCount: 24,
          child: SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 30),
              child: Column(
                children: [
                  const Spacer(),
                  Text(
                    day == null ? l.summaryKicker : '${l.summaryKicker} · ${l.ramadanDay(day)}',
                    style: const TextStyle(fontSize: 12.5, color: AppPalette.gold),
                  ),
                  Text(
                    ltr('${summary.served}'),
                    style: const TextStyle(
                      fontSize: 110,
                      fontWeight: FontWeight.w300,
                      height: 0.95,
                      color: AppPalette.onSky,
                    ),
                  ),
                  Text(
                    l.summaryServedByYou,
                    style: const TextStyle(fontSize: 15, color: AppPalette.onSky),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    l.summaryDetail(summary.familyMeals, summary.singleMeals, summary.portions),
                    textAlign: TextAlign.center,
                    style: const TextStyle(fontSize: 13, color: AppPalette.onSkyMuted),
                  ),
                  const SizedBox(height: 22),
                  const Text(
                    blessingText,
                    textDirection: TextDirection.rtl,
                    style: TextStyle(
                      fontFamily: AppTheme.brandFont,
                      fontSize: 46,
                      color: AppPalette.gold,
                    ),
                  ),
                  if (l.blessingMeaning.isNotEmpty)
                    Text(
                      l.blessingMeaning,
                      style: const TextStyle(fontSize: 13, color: AppPalette.onSkyMuted),
                    ),
                  const Spacer(),
                  FilledButton(
                    style: FilledButton.styleFrom(
                      backgroundColor: AppPalette.mint,
                      foregroundColor: AppPalette.sky,
                    ),
                    onPressed: () => context.go('/people'),
                    child: Text(l.backToPeople),
                  ),
                  const SizedBox(height: 12),
                  OutlinedButton(
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppPalette.onSky,
                      side: BorderSide(color: AppPalette.onSky.withValues(alpha: 0.35)),
                    ),
                    onPressed: () => context.go('/scan'),
                    child: Text(l.keepScanning),
                  ),
                  const SizedBox(height: 24),
                ],
              ),
            ),
          ),
        ),
      );
    }
  }
  ```

- [ ] **Step 5: Register the route** in `app_router.dart`. Import `session_summary_page.dart` and add it after `/find`:
  ```dart
  GoRoute(
    path: '/summary',
    parentNavigatorKey: _rootKey,
    redirect: (_, state) => state.extra is SessionSummary ? null : '/people',
    builder: (_, state) => SessionSummaryPage(summary: state.extra! as SessionSummary),
  ),
  ```

- [ ] **Step 6: Run the tests.**
  Run: `fl test`
  Expected: PASS.

- [ ] **Step 7: Commit.**
  ```bash
  git add lib/features/scan/presentation/session_summary_page.dart lib/core/router/app_router.dart lib/core/widgets/brand.dart test/presentation/session_summary_test.dart
  git commit -m "feat(mobile): end-of-session summary with blessing" -m "Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>" -- lib/features/scan/presentation/session_summary_page.dart lib/core/router/app_router.dart lib/core/widgets/brand.dart test/presentation/session_summary_test.dart
  ```

---

### Task 17: Scan screen (band and seal verdicts, arch viewfinder, find bar, summary on close)

**Files:**
- Rewrite: `lib/features/scan/presentation/scan_result_panel.dart`, `lib/features/scan/presentation/scan_page.dart`
- Delete: `lib/core/widgets/meal_status_badge.dart`, and `MealAllotment` in `lib/features/people/presentation/person_widgets.dart`
- Test: rewrite the `scan result panel` group in `test/presentation/widgets_test.dart`

**Interfaces:**
- Consumes:
  - From Task 14: the scan states and controller methods.
  - From Task 6: `Seal`.
  - From Task 7: `HandOverTiles` and `StatusChip` (`MealStatusWords`).
  - From Task 13: `ArchViewfinderPainter`.
  - From Task 15: `/find`.
  - From Task 16: `/summary` and `SessionSummary`.
  - `blessingText`, `maskCin`, `cinLastDigits`, `failureText`, `failureTitle`, `showContactEditor`, `showMealHistory`.
- Produces: `ScanResultPanel({required ScanStatus status, required VoidCallback onFindWithoutCard})`. The `onManualEntry` parameter is gone.

- [ ] **Step 1: Rewrite the panel tests.** In `test/presentation/widgets_test.dart`:
  - Replace the `meal_status_badge.dart` import with `package:iftar_mobile/core/widgets/status_chip.dart`.
  - Add the imports `package:iftar_mobile/core/utils/formatters.dart` and `package:iftar_mobile/features/people/domain/fasting_person.dart`.
  - Replace the whole `group('scan result panel', …)` with:
  ```dart
  group('scan result panel', () {
    Future<void> pumpPanel(
      WidgetTester tester,
      ScanStatus status, {
      Locale locale = const Locale('en'),
    }) => tester.pumpWidget(
      localizedApp(
        Scaffold(
          body: Align(
            alignment: Alignment.bottomCenter,
            child: ScanResultPanel(status: status, onFindWithoutCard: () {}),
          ),
        ),
        locale: locale,
        overrides: testOverrides(FakePeopleRepository([])),
      ),
    );

    testWidgets('eligible: teal seal, Tunisian word, quantities, one tap', (tester) async {
      await pumpPanel(tester, ScanReady(person(101)));
      expect(find.text(MealStatusWords.notTaken), findsOneWidget);
      expect(find.text(en.notServedTonight), findsOneWidget);
      expect(find.text('Najwa Chalbi'), findsOneWidget);
      expect(find.text(en.portions(4)), findsOneWidget); // 1 family meal
      expect(find.text(en.confirmHandOver), findsOneWidget);
      expect(find.bySemanticsLabel(en.sealServe), findsOneWidget);
    });

    testWidgets('already served: clay stop, time, and no serve action', (tester) async {
      await pumpPanel(tester, ScanAlreadyTaken(person(102, takenToday: true), DateTime(2025, 3, 5, 18, 10)));
      expect(find.text(MealStatusWords.taken), findsOneWidget);
      expect(find.text(en.alreadyServedTonight), findsOneWidget);
      expect(find.text(ltr('18:10')), findsOneWidget);
      expect(find.text(en.alreadyServedNote(ltr('18:10'))), findsOneWidget);
      expect(find.text(en.scanNextCard), findsOneWidget);
      expect(find.text(en.confirmHandOver), findsNothing);
    });

    testWidgets('already served without a timestamp still reads well', (tester) async {
      await pumpPanel(tester, ScanAlreadyTaken(person(102, takenToday: true), null));
      expect(find.text(en.alreadyServedNoteNoTime), findsOneWidget);
    });

    testWidgets('invalid and unknown codes each offer a next step', (tester) async {
      await pumpPanel(tester, const ScanInvalidCode('hello'));
      expect(find.text(en.invalidCodeTitle), findsOneWidget);
      expect(find.text(en.findNoCard), findsOneWidget);

      await pumpPanel(tester, const ScanNotFound(77));
      await tester.pumpAndSettle();
      expect(find.text(en.unknownCardTitle(77)), findsOneWidget);
      expect(find.text(en.registerThisCard), findsOneWidget);
    });

    testWidgets('failed confirmation says not to hand over yet', (tester) async {
      await pumpPanel(
        tester,
        ScanFailed(const NetworkFailure(), personId: 101, person: person(101)),
      );
      expect(find.text(en.notConfirmedYet), findsOneWidget);
      expect(find.text(en.dontHandOverYet), findsOneWidget);
      expect(find.textContaining(en.notConfirmedExplanation), findsOneWidget);
      expect(find.text(en.retry), findsOneWidget);
    });

    testWidgets('identifying shows the name and the CIN check before the verdict', (tester) async {
      const p = FastingPerson(
        id: 142,
        firstName: 'Fatma',
        lastName: 'Trabelsi',
        cin: '08123812',
        singleMeal: 0,
        familyMeal: 1,
      );
      await pumpPanel(tester, const ScanIdentifying(p, noCard: true));
      await tester.pump(const Duration(milliseconds: 300)); // seal pulse loops
      expect(find.text('Fatma Trabelsi'), findsOneWidget);
      expect(find.text(en.noCardCheck(ltr('812'))), findsOneWidget);
      expect(find.text(en.confirmHandOver), findsNothing);
    });

    testWidgets('every state fits 360×760 in Arabic at 1.3× text', (tester) async {
      tester.view.physicalSize = const Size(1080, 2280);
      tester.view.devicePixelRatio = 3;
      tester.platformDispatcher.textScaleFactorTestValue = 1.3;
      addTearDown(() {
        tester.view.reset();
        tester.platformDispatcher.clearTextScaleFactorTestValue();
      });
      final long = person(9, first: 'Mohamed Ali Ben Abdelkader', last: 'Trabelsi El Kairouani');
      final states = <ScanStatus>[
        const ScanIdle(),
        const ScanLookingUp(9),
        ScanIdentifying(long, noCard: true),
        ScanReady(long, noCard: true),
        ScanConfirming(long),
        ScanConfirmed(long),
        ScanAlreadyTaken(long, DateTime(2025, 3, 5, 18, 10)),
        const ScanNotFound(77),
        const ScanInvalidCode('x'),
        ScanFailed(const NetworkFailure(), personId: 9),
        ScanFailed(const NetworkFailure(), personId: 9, person: long),
      ];
      for (final status in states) {
        await pumpPanel(tester, status, locale: const Locale('ar'));
        await tester.pump(const Duration(milliseconds: 300));
        expect(tester.takeException(), isNull, reason: '$status');
      }
    });
  });
  ```

- [ ] **Step 2: Run them to verify they fail.**
  Run: `fl test test/presentation/widgets_test.dart`
  Expected: FAIL. The panel still has `onManualEntry` and the old strings.

- [ ] **Step 3: Rewrite `lib/features/scan/presentation/scan_result_panel.dart`.**
  ```dart
  import 'package:flutter/material.dart';
  import 'package:flutter_riverpod/flutter_riverpod.dart';
  import 'package:go_router/go_router.dart';

  import '../../../core/network/failure_text.dart';
  import '../../../core/theme/app_colors.dart';
  import '../../../core/theme/app_theme.dart';
  import '../../../core/theme/iftar_colors.dart';
  import '../../../core/utils/formatters.dart';
  import '../../../core/utils/masking.dart';
  import '../../../core/widgets/brand.dart';
  import '../../../core/widgets/hand_over_tiles.dart';
  import '../../../core/widgets/seal.dart';
  import '../../../core/widgets/status_chip.dart';
  import '../../../l10n/app_localizations.dart';
  import '../../auth/presentation/auth_controller.dart';
  import '../../people/domain/fasting_person.dart';
  import '../../people/presentation/person_widgets.dart';
  import 'scan_controller.dart';

  /// Bottom of the scan screen. The band and seal give the verdict at a
  /// glance; the body says what to do next (spec §4.6).
  class ScanResultPanel extends ConsumerWidget {
    const ScanResultPanel({
      super.key,
      required this.status,
      required this.onFindWithoutCard,
    });

    final ScanStatus status;
    final VoidCallback onFindWithoutCard;

    @override
    Widget build(BuildContext context, WidgetRef ref) {
      return AnimatedSwitcher(
        duration: const Duration(milliseconds: 220),
        switchInCurve: Curves.easeOutCubic,
        transitionBuilder: (child, animation) => SlideTransition(
          position: Tween(begin: const Offset(0, 0.12), end: Offset.zero).animate(animation),
          child: FadeTransition(opacity: animation, child: child),
        ),
        child: KeyedSubtree(
          key: ValueKey(_keyFor(status)),
          child: _content(context, ref),
        ),
      );
    }

    /// Identifying → Ready keeps the same key so the sheet updates in place.
    static String _keyFor(ScanStatus s) => switch (s) {
      ScanIdle() => 'idle',
      ScanLookingUp(:final personId) => 'lookup-$personId',
      ScanIdentifying(:final person) => 'ready-${person.id}',
      ScanReady(:final person) => 'ready-${person.id}',
      ScanConfirming(:final person) => 'ready-${person.id}',
      ScanConfirmed(:final person) => 'done-${person.id}',
      ScanAlreadyTaken(:final person) => 'taken-${person.id}',
      ScanNotFound(:final personId) => 'missing-$personId',
      ScanInvalidCode(:final raw) => 'invalid-$raw',
      ScanFailed(:final personId) => 'failed-$personId',
    };

    Widget _content(BuildContext context, WidgetRef ref) {
      final l = AppLocalizations.of(context);
      final c = context.colors;
      final controller = ref.read(scanControllerProvider.notifier);
      final problem = Seal(SealKind.problem, semanticLabel: l.sealProblem);
      final checking = Seal(SealKind.checking, semanticLabel: l.sealChecking);

      switch (status) {
        case ScanIdle():
          return _FindBar(onTap: onFindWithoutCard);

        case ScanLookingUp(:final personId):
          return _Sheet(
            band: _Band(color: AppPalette.waitBand, seal: checking, title: l.lookingUp(personId), small: true),
            children: const [_WaitBar()],
          );

        case ScanIdentifying(:final person, :final noCard):
          return _Sheet(
            band: _Band(
              color: AppPalette.waitBand,
              seal: checking,
              title: person.fullName,
              subtitle: l.checkingStatus,
              small: true,
            ),
            children: [
              _PersonMeta(person),
              _Label(l.handOver),
              HandOverTiles(person: person),
              if (noCard) _NoCardCheck(person),
              const _WaitBar(),
            ],
          );

        case ScanReady(:final person, :final phone, :final comment, :final noCard):
          return _ready(
            context,
            controller,
            person,
            phone: phone ?? person.phone,
            comment: comment ?? person.comment,
            noCard: noCard,
            busy: false,
          );

        case ScanConfirming(:final person):
          return _ready(
            context,
            controller,
            person,
            phone: person.phone,
            comment: person.comment,
            noCard: false,
            busy: true,
          );

        case ScanConfirmed(:final person):
          return _DoneBand(person: person);

        case ScanAlreadyTaken(:final person, :final takenAt):
          final time = takenAt == null ? null : ltr(formatTime(takenAt));
          return _Sheet(
            background: c.claySoft,
            band: _Band(
              color: AppPalette.pausedBand,
              seal: Seal(SealKind.served, semanticLabel: l.sealServed),
              title: MealStatusWords.taken,
              subtitle: l.alreadyServedTonight,
              trailing: time,
            ),
            children: [
              _Name(person),
              _PersonMeta(person),
              Padding(
                padding: const EdgeInsets.only(top: 10),
                child: Text(
                  time == null ? l.alreadyServedNoteNoTime : l.alreadyServedNote(time),
                  style: TextStyle(fontSize: 13, color: c.clayInk),
                ),
              ),
              const SizedBox(height: 16),
              FilledButton.icon(
                style: FilledButton.styleFrom(
                  backgroundColor: AppPalette.sky,
                  foregroundColor: AppPalette.onSky,
                ),
                onPressed: controller.scanNext,
                icon: const Icon(Icons.qr_code_scanner_rounded),
                label: Text(l.scanNextCard),
              ),
              _Links([
                (l.history, () => showMealHistory(context, person)),
                (l.details, () => context.push('/people/${person.id}')),
              ]),
            ],
          );

        case ScanNotFound(:final personId):
          final region = ref.read(authControllerProvider).value?.region?.name ?? '';
          return _Sheet(
            band: _Band(
              color: c.systemBand,
              seal: problem,
              title: l.unknownCardTitle(personId),
              subtitle: l.unknownCardMessage(region),
              small: true,
            ),
            children: [
              FilledButton.icon(
                onPressed: () => context.go('/add?id=$personId'),
                icon: const Icon(Icons.person_add_alt_1_rounded),
                label: Text(l.registerThisCard),
              ),
              _Links([(l.scanAgain, controller.scanNext)]),
            ],
          );

        case ScanInvalidCode():
          return _Sheet(
            band: _Band(
              color: c.systemBand,
              seal: problem,
              title: l.invalidCodeTitle,
              subtitle: l.invalidCodeMessage,
              small: true,
            ),
            children: [
              OutlinedButton.icon(
                onPressed: onFindWithoutCard,
                icon: const Icon(Icons.search_rounded),
                label: Text(l.findNoCard),
              ),
              _Links([(l.scanAgain, controller.scanNext)]),
            ],
          );

        case ScanFailed(:final failure, :final person, :final duringConfirm):
          if (duringConfirm) {
            return _Sheet(
              band: _Band(
                color: c.systemBand,
                seal: problem,
                title: l.notConfirmedYet,
                subtitle: l.dontHandOverYet,
                small: true,
              ),
              children: [
                if (person != null) ...[_Name(person), _PersonMeta(person)],
                Padding(
                  padding: const EdgeInsets.only(top: 10),
                  child: Text(
                    '${failureText(l, failure)} ${l.notConfirmedExplanation}',
                    style: TextStyle(fontSize: 13, color: c.ink),
                  ),
                ),
                const SizedBox(height: 14),
                FilledButton.icon(
                  onPressed: controller.retry,
                  icon: const Icon(Icons.refresh_rounded),
                  label: Text(l.retry),
                ),
                _Links([(l.skip, controller.scanNext)]),
              ],
            );
          }
          return _Sheet(
            band: _Band(
              color: c.systemBand,
              seal: problem,
              title: failureTitle(l, failure),
              subtitle: failureText(l, failure),
              small: true,
            ),
            children: [
              FilledButton.icon(
                onPressed: controller.retry,
                icon: const Icon(Icons.refresh_rounded),
                label: Text(l.retry),
              ),
              _Links([(l.cancel, controller.scanNext)]),
            ],
          );
      }
    }

    Widget _ready(
      BuildContext context,
      ScanController controller,
      FastingPerson person, {
      required String? phone,
      required String? comment,
      required bool noCard,
      required bool busy,
    }) {
      final l = AppLocalizations.of(context);
      final c = context.colors;
      return _Sheet(
        band: _Band(
          color: c.serveBand,
          seal: Seal(SealKind.serve, semanticLabel: l.sealServe),
          title: MealStatusWords.notTaken,
          subtitle: l.notServedTonight,
        ),
        children: [
          _Name(person),
          _PersonMeta(person),
          _Label(l.handOver),
          HandOverTiles(person: person),
          if (noCard) _NoCardCheck(person),
          if (!busy)
            _ContactLine(
              phone: phone,
              comment: comment,
              onEdit: () async {
                final result = await showContactEditor(context, phone: phone, comment: comment);
                if (result != null) {
                  controller.editContact(phone: result.phone, comment: result.comment);
                }
              },
            ),
          const SizedBox(height: 14),
          FilledButton.icon(
            onPressed: busy ? null : controller.confirm,
            icon: busy
                ? SizedBox.square(
                    dimension: 18,
                    child: CircularProgressIndicator(strokeWidth: 2.2, color: c.onAct),
                  )
                : const Icon(Icons.check_rounded),
            label: Text(busy ? l.confirming : l.confirmHandOver),
          ),
          _Links([
            (l.skip, busy ? null : controller.scanNext),
            (l.details, busy ? null : () => context.push('/people/${person.id}')),
          ]),
        ],
      );
    }
  }

  class _Sheet extends StatelessWidget {
    const _Sheet({required this.band, this.children = const [], this.background});

    final Widget band;
    final List<Widget> children;
    final Color? background;

    @override
    Widget build(BuildContext context) {
      return Container(
        width: double.infinity,
        clipBehavior: Clip.antiAlias,
        decoration: BoxDecoration(
          color: background ?? context.colors.surface,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(AppRadii.sheet)),
        ),
        child: SafeArea(
          top: false,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              band,
              if (children.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.fromLTRB(18, 14, 18, 12),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: children,
                  ),
                ),
            ],
          ),
        ),
      );
    }
  }

  class _Band extends StatelessWidget {
    const _Band({
      required this.color,
      required this.seal,
      required this.title,
      this.subtitle,
      this.trailing,
      this.small = false,
    });

    final Color color;
    final Widget seal;
    final String title;
    final String? subtitle;
    final String? trailing;
    final bool small;

    @override
    Widget build(BuildContext context) {
      return ColoredBox(
        color: color,
        child: Padding(
          padding: const EdgeInsetsDirectional.fromSTEB(18, 14, 18, 14),
          child: Row(
            children: [
              seal,
              const SizedBox(width: 12),
              Expanded(
                // Screen readers announce each new verdict (spec §8).
                child: Semantics(
                  liveRegion: true,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: small ? 19 : 24,
                          fontWeight: small ? FontWeight.w500 : FontWeight.w600,
                          height: 1.15,
                        ),
                      ),
                      if (subtitle != null)
                        Text(
                          subtitle!,
                          style: TextStyle(color: Colors.white.withValues(alpha: 0.92), fontSize: 12.5),
                        ),
                    ],
                  ),
                ),
              ),
              if (trailing != null)
                Text(
                  trailing!,
                  style: const TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.w500),
                ),
            ],
          ),
        ),
      );
    }
  }

  class _DoneBand extends StatelessWidget {
    const _DoneBand({required this.person});

    final FastingPerson person;

    @override
    Widget build(BuildContext context) {
      final l = AppLocalizations.of(context);
      return Container(
        width: double.infinity,
        decoration: const BoxDecoration(
          color: AppPalette.doneBand,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsetsDirectional.fromSTEB(18, 16, 18, 18),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Seal(SealKind.done, semanticLabel: l.sealDone),
                const SizedBox(width: 12),
                Expanded(
                  child: Semantics(
                    liveRegion: true,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          blessingText,
                          textDirection: TextDirection.rtl,
                          style: TextStyle(
                            fontFamily: AppTheme.brandFont,
                            fontSize: 30,
                            height: 1.15,
                            color: AppPalette.gold,
                          ),
                        ),
                        Text(
                          l.servedLine(isolate(person.fullName), person.totalPortions),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(color: Colors.white, fontSize: 12.5),
                        ),
                        if (l.blessingMeaning.isNotEmpty)
                          Text(
                            l.blessingMeaning,
                            style: TextStyle(color: Colors.white.withValues(alpha: 0.75), fontSize: 12.5),
                          ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }
  }

  class _FindBar extends StatelessWidget {
    const _FindBar({required this.onTap});

    final VoidCallback onTap;

    @override
    Widget build(BuildContext context) {
      final l = AppLocalizations.of(context);
      final c = context.colors;
      return Material(
        color: c.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsetsDirectional.fromSTEB(20, 18, 20, 22),
              child: Row(
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(color: c.actSoft, shape: BoxShape.circle),
                    child: Icon(Icons.search_rounded, color: c.actInk),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(l.findNoCard, style: const TextStyle(fontSize: 14.5, fontWeight: FontWeight.w500)),
                        Text(l.findNoCardSubtitle, style: TextStyle(fontSize: 12, color: c.inkMuted)),
                      ],
                    ),
                  ),
                  Icon(Icons.chevron_right_rounded, color: c.inkMuted),
                ],
              ),
            ),
          ),
        ),
      );
    }
  }

  class _Name extends StatelessWidget {
    const _Name(this.person);

    final FastingPerson person;

    @override
    Widget build(BuildContext context) => Text(
      person.fullName,
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      style: const TextStyle(fontSize: 19, fontWeight: FontWeight.w500),
    );
  }

  class _PersonMeta extends StatelessWidget {
    const _PersonMeta(this.person);

    final FastingPerson person;

    @override
    Widget build(BuildContext context) {
      final l = AppLocalizations.of(context);
      final masked = maskCin(person.cin);
      return Text(
        [
          ltr('#${person.id}'),
          if (masked != null) '${l.cinShortLabel} ${ltr(masked)}',
        ].join(' · '),
        style: TextStyle(fontSize: 12.5, color: context.colors.inkMuted),
      );
    }
  }

  class _Label extends StatelessWidget {
    const _Label(this.text);

    final String text;

    @override
    Widget build(BuildContext context) => Padding(
      padding: const EdgeInsets.only(top: 12, bottom: 6),
      child: Text(text, style: TextStyle(fontSize: 12, color: context.colors.inkMuted)),
    );
  }

  class _NoCardCheck extends StatelessWidget {
    const _NoCardCheck(this.person);

    final FastingPerson person;

    @override
    Widget build(BuildContext context) {
      final digits = cinLastDigits(person.cin);
      if (digits == null) return const SizedBox.shrink();
      final c = context.colors;
      return Container(
        margin: const EdgeInsets.only(top: 10),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        decoration: BoxDecoration(color: c.warnSoft, borderRadius: BorderRadius.circular(10)),
        child: Row(
          children: [
            Icon(Icons.badge_outlined, size: 16, color: c.goldInk),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                AppLocalizations.of(context).noCardCheck(ltr(digits)),
                style: TextStyle(fontSize: 12.5, color: c.goldInk),
              ),
            ),
          ],
        ),
      );
    }
  }

  class _ContactLine extends StatelessWidget {
    const _ContactLine({required this.phone, required this.comment, required this.onEdit});

    final String? phone;
    final String? comment;
    final VoidCallback onEdit;

    @override
    Widget build(BuildContext context) {
      final c = context.colors;
      final text = [
        if (phone != null && phone!.isNotEmpty) ltr(phone!),
        if (comment != null && comment!.isNotEmpty) comment!,
      ].join(' · ');
      return Semantics(
        button: true,
        label: AppLocalizations.of(context).editContact,
        child: InkWell(
          onTap: onEdit,
          child: Padding(
            padding: const EdgeInsets.only(top: 10),
            child: Row(
              children: [
                Icon(Icons.phone_outlined, size: 15, color: c.inkMuted),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    text,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(fontSize: 12.5, color: c.inkMuted),
                  ),
                ),
                Icon(Icons.edit_rounded, size: 15, color: c.actInk),
              ],
            ),
          ),
        ),
      );
    }
  }

  class _WaitBar extends StatelessWidget {
    const _WaitBar();

    @override
    Widget build(BuildContext context) {
      final c = context.colors;
      return Container(
        margin: const EdgeInsets.only(top: 14),
        height: 52,
        decoration: BoxDecoration(
          border: Border.all(color: c.line),
          borderRadius: BorderRadius.circular(AppRadii.button),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const SizedBox.square(dimension: 16, child: CircularProgressIndicator(strokeWidth: 2)),
            const SizedBox(width: 10),
            Flexible(
              child: Text(
                AppLocalizations.of(context).checkingStatus,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(fontSize: 14, color: c.inkMuted),
              ),
            ),
          ],
        ),
      );
    }
  }

  class _Links extends StatelessWidget {
    const _Links(this.links);

    final List<(String, VoidCallback?)> links;

    @override
    Widget build(BuildContext context) => Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: [
        for (final (label, onTap) in links)
          Flexible(child: TextButton(onPressed: onTap, child: Text(label))),
      ],
    );
  }
  ```

- [ ] **Step 4: Rewrite `lib/features/scan/presentation/scan_page.dart`.**
  ```dart
  import 'package:flutter/material.dart';
  import 'package:flutter/services.dart';
  import 'package:flutter_riverpod/flutter_riverpod.dart';
  import 'package:go_router/go_router.dart';
  import 'package:mobile_scanner/mobile_scanner.dart';

  import '../../../core/providers.dart';
  import '../../../core/theme/app_colors.dart';
  import '../../../l10n/app_localizations.dart';
  import '../../people/domain/fasting_person.dart';
  import '../../people/presentation/people_controller.dart';
  import '../../people/presentation/people_filter.dart';
  import 'scan_controller.dart';
  import 'scan_result_panel.dart';
  import 'session_summary_page.dart';
  import 'viewfinder.dart';

  /// Continuous QR scanner for a volunteer serving a queue: the camera stays
  /// open, each card resolves to a clear verdict, and one tap confirms.
  class ScanPage extends ConsumerStatefulWidget {
    const ScanPage({super.key});

    @override
    ConsumerState<ScanPage> createState() => _ScanPageState();
  }

  class _ScanPageState extends ConsumerState<ScanPage> {
    final _camera = MobileScannerController(
      formats: const [BarcodeFormat.qrCode],
      detectionSpeed: DetectionSpeed.normal,
      detectionTimeoutMs: 300,
    );

    @override
    void dispose() {
      _camera.dispose();
      super.dispose();
    }

    void _onDetect(BarcodeCapture capture) {
      for (final barcode in capture.barcodes) {
        final raw = barcode.rawValue;
        if (raw != null) {
          ref.read(scanControllerProvider.notifier).onDetected(raw);
          return;
        }
      }
    }

    Future<void> _findWithoutCard() async {
      final id = await context.push<int>('/find');
      if (id != null && mounted) {
        await ref.read(scanControllerProvider.notifier).pickWithoutCard(id);
      }
    }

    void _close() {
      final scan = ref.read(scanControllerProvider);
      if (scan.servedCount > 0) {
        context.pushReplacement(
          '/summary',
          extra: SessionSummary(
            served: scan.servedCount,
            singleMeals: scan.singleMeals,
            familyMeals: scan.familyMeals,
          ),
        );
      } else if (context.canPop()) {
        context.pop();
      } else {
        context.go('/people');
      }
    }

    void _hapticsFor(ScanStatus status) {
      switch (status) {
        case ScanReady():
          HapticFeedback.selectionClick();
        case ScanConfirmed():
          HapticFeedback.mediumImpact();
        case ScanAlreadyTaken():
          HapticFeedback.heavyImpact();
          HapticFeedback.vibrate();
        case ScanInvalidCode() || ScanNotFound() || ScanFailed():
          HapticFeedback.vibrate();
        case ScanIdle() || ScanLookingUp() || ScanIdentifying() || ScanConfirming():
          break;
      }
    }

    @override
    Widget build(BuildContext context) {
      ref.listen(
        scanControllerProvider.select((s) => s.status),
        (_, next) => _hapticsFor(next),
      );
      final l = AppLocalizations.of(context);
      final scan = ref.watch(scanControllerProvider);
      final now = ref.watch(clockProvider)();
      // Watching the list also keeps it loaded for instant identify.
      final people = ref.watch(peopleListProvider).value ?? const <FastingPerson>[];
      final servedTonight = countPeople(people, now).served;
      final frameColor = switch (scan.status) {
        ScanReady() || ScanConfirming() => AppPalette.mint,
        ScanAlreadyTaken() => const Color(0xFFE8957A),
        ScanIdentifying() || ScanLookingUp() || ScanInvalidCode() || ScanFailed() => AppPalette.gold,
        ScanNotFound() => AppPalette.onSkyMuted,
        _ => AppPalette.onSky,
      };

      return Scaffold(
        backgroundColor: Colors.black,
        body: Stack(
          fit: StackFit.expand,
          children: [
            MobileScanner(
              controller: _camera,
              onDetect: _onDetect,
              errorBuilder: (context, error) =>
                  _CameraUnavailable(error: error, onFind: _findWithoutCard),
            ),
            ValueListenableBuilder<MobileScannerState>(
              valueListenable: _camera,
              builder: (context, camera, _) {
                final available = camera.error == null;
                final showHint = scan.status is ScanIdle || scan.status is ScanConfirmed;
                return Stack(
                  fit: StackFit.expand,
                  children: [
                    if (available)
                      IgnorePointer(
                        child: TweenAnimationBuilder<Color?>(
                          tween: ColorTween(end: frameColor),
                          duration: const Duration(milliseconds: 250),
                          builder: (_, color, _) => CustomPaint(
                            painter: ArchViewfinderPainter(color ?? frameColor),
                          ),
                        ),
                      ),
                    SafeArea(
                      bottom: false,
                      child: Column(
                        children: [
                          _TopBar(camera: _camera, servedTonight: servedTonight, onClose: _close),
                          const Spacer(),
                          if (available && showHint)
                            Padding(
                              padding: const EdgeInsets.only(bottom: 12),
                              child: _HintPill(l.scanHint),
                            ),
                          if (available || scan.status is! ScanIdle)
                            ScanResultPanel(status: scan.status, onFindWithoutCard: _findWithoutCard),
                        ],
                      ),
                    ),
                  ],
                );
              },
            ),
          ],
        ),
      );
    }
  }

  class _TopBar extends StatelessWidget {
    const _TopBar({required this.camera, required this.servedTonight, required this.onClose});

    final MobileScannerController camera;
    final int servedTonight;
    final VoidCallback onClose;

    @override
    Widget build(BuildContext context) {
      final l = AppLocalizations.of(context);
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
        child: Row(
          children: [
            _RoundIcon(icon: Icons.close_rounded, tooltip: l.closeScanner, onPressed: onClose),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    l.scanTitle,
                    style: const TextStyle(color: AppPalette.onSky, fontSize: 15, fontWeight: FontWeight.w500),
                  ),
                  Text(
                    l.servedTonight(servedTonight),
                    style: const TextStyle(color: AppPalette.gold, fontSize: 11.5),
                  ),
                ],
              ),
            ),
            ValueListenableBuilder<MobileScannerState>(
              valueListenable: camera,
              builder: (context, value, _) {
                if (value.torchState == TorchState.unavailable) return const SizedBox.shrink();
                final on = value.torchState == TorchState.on;
                return _RoundIcon(
                  icon: on ? Icons.flash_on_rounded : Icons.flash_off_rounded,
                  tooltip: on ? l.torchOff : l.torchOn,
                  active: on,
                  onPressed: camera.toggleTorch,
                );
              },
            ),
          ],
        ),
      );
    }
  }

  class _RoundIcon extends StatelessWidget {
    const _RoundIcon({
      required this.icon,
      required this.tooltip,
      required this.onPressed,
      this.active = false,
    });

    final IconData icon;
    final String tooltip;
    final VoidCallback onPressed;
    final bool active;

    @override
    Widget build(BuildContext context) => IconButton.filled(
      tooltip: tooltip,
      onPressed: onPressed,
      style: IconButton.styleFrom(
        backgroundColor: active ? AppPalette.gold : Colors.black.withValues(alpha: 0.4),
        foregroundColor: active ? AppPalette.sky : AppPalette.onSky,
        minimumSize: const Size.square(44),
        side: BorderSide(color: AppPalette.onSky.withValues(alpha: 0.18)),
      ),
      icon: Icon(icon),
    );
  }

  class _HintPill extends StatelessWidget {
    const _HintPill(this.text);

    final String text;

    @override
    Widget build(BuildContext context) => DecoratedBox(
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: AppPalette.gold.withValues(alpha: 0.45)),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.nightlight_round, size: 14, color: AppPalette.gold),
            const SizedBox(width: 6),
            Text(text, style: const TextStyle(color: AppPalette.onSky, fontSize: 12.5)),
          ],
        ),
      ),
    );
  }

  class _CameraUnavailable extends StatelessWidget {
    const _CameraUnavailable({required this.error, required this.onFind});

    final MobileScannerException error;
    final VoidCallback onFind;

    @override
    Widget build(BuildContext context) {
      final l = AppLocalizations.of(context);
      final denied = error.errorCode == MobileScannerErrorCode.permissionDenied;
      return ColoredBox(
        color: AppPalette.sky,
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(32),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.no_photography_outlined, size: 48, color: AppPalette.gold),
                const SizedBox(height: 16),
                Text(
                  denied ? l.cameraOffTitle : l.cameraUnavailableTitle,
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: AppPalette.onSky, fontSize: 18, fontWeight: FontWeight.w500),
                ),
                const SizedBox(height: 8),
                Text(
                  denied ? l.cameraOffMessage : l.cameraUnavailableMessage,
                  textAlign: TextAlign.center,
                  style: TextStyle(color: AppPalette.onSky.withValues(alpha: 0.8)),
                ),
                const SizedBox(height: 24),
                FilledButton.icon(
                  style: FilledButton.styleFrom(
                    backgroundColor: AppPalette.mint,
                    foregroundColor: AppPalette.sky,
                  ),
                  onPressed: onFind,
                  icon: const Icon(Icons.search_rounded),
                  label: Text(l.findNoCard),
                ),
              ],
            ),
          ),
        ),
      );
    }
  }
  ```

- [ ] **Step 5: Delete the old widgets.**
  - Delete `lib/core/widgets/meal_status_badge.dart`.
  - Delete the `MealAllotment` class from `lib/features/people/presentation/person_widgets.dart`.
  - Then check that nothing still references them:
    ```bash
    grep -rn "MealStatusBadge\|MealAllotment\|onManualEntry" lib test
    ```
    Expected: no output.

- [ ] **Step 6: Run the tests.**
  Run: `fl test`
  Expected: PASS, including the Arabic 1.3× fit test for all 11 states.

- [ ] **Step 7: Commit.**
  ```bash
  git rm -q lib/core/widgets/meal_status_badge.dart
  git add lib/features/scan/presentation/scan_result_panel.dart lib/features/scan/presentation/scan_page.dart lib/features/people/presentation/person_widgets.dart test/presentation/widgets_test.dart
  git commit -m "feat(mobile): band-and-seal scan verdicts, arch viewfinder, find bar, summary on close" -m "Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>" -- lib/core/widgets/meal_status_badge.dart lib/features/scan/presentation/scan_result_panel.dart lib/features/scan/presentation/scan_page.dart lib/features/people/presentation/person_widgets.dart test/presentation/widgets_test.dart
  ```

---

### Task 18: Statistics presets

**Files:**
- Modify: `lib/features/statistics/domain/statistics.dart` (adds `StatsPreset` and `presetRange`)
- Create: `lib/features/statistics/presentation/statistics_controller.dart`
- Rewrite: `lib/features/statistics/presentation/statistics_page.dart`
- Test: `test/presentation/statistics_test.dart`

**Interfaces:**
- Consumes: `StatsPeriod` (existing, unchanged), `appConfigProvider.ramadanStart`, `statisticsRepositoryProvider`, and `DailyStatistics.date` (Task 5).
- Produces:
  - `enum StatsPreset { tonight, week, ramadan, custom }`.
  - `presetRange(StatsPreset, DateTime now, {DateTime? ramadanStart, DateTime? customFrom, DateTime? customTo})`.
  - `StatisticsState {preset, from, to, AsyncValue<List<DailyStatistics>> result}`.
  - `StatisticsController`, with `select(StatsPreset)`, `setCustom(DateTime, DateTime) → Future<bool>`, and `refresh()`.
  - `statisticsControllerProvider`.

- [ ] **Step 1: Write the failing test** `test/presentation/statistics_test.dart`:
  ```dart
  import 'package:flutter_riverpod/flutter_riverpod.dart';
  import 'package:flutter_test/flutter_test.dart';
  import 'package:iftar_mobile/core/config/app_config.dart';
  import 'package:iftar_mobile/core/providers.dart';
  import 'package:iftar_mobile/core/utils/formatters.dart';
  import 'package:iftar_mobile/features/auth/presentation/auth_controller.dart';
  import 'package:iftar_mobile/features/statistics/data/statistics_repository.dart';
  import 'package:iftar_mobile/features/statistics/domain/statistics.dart';
  import 'package:iftar_mobile/features/statistics/presentation/statistics_controller.dart';
  import 'package:iftar_mobile/features/statistics/presentation/statistics_page.dart';

  import '../support/app_harness.dart';
  import '../support/fakes.dart';

  class FakeStatisticsRepository implements StatisticsRepository {
    final calls = <(DateTime, DateTime)>[];

    @override
    Future<List<DailyStatistics>> fetch(int regionId, DateTime from, DateTime to) async {
      calls.add((from, to));
      return [
        DailyStatistics.fromJson({
          'date': 'Wed Mar 05 2025',
          'statistics': {'persons': 3, 'totalPersons': 9, 'singleMeal': 2, 'familyMeal': 4, 'totalMeals': 6},
        }),
      ];
    }
  }

  void main() {
    late FakeStatisticsRepository stats;
    setUp(() => stats = FakeStatisticsRepository());

    Future<ProviderContainer> container({DateTime? ramadanStart}) async {
      final c = ProviderContainer.test(overrides: [
        ...testOverrides(FakePeopleRepository([])),
        statisticsRepositoryProvider.overrideWithValue(stats),
        appConfigProvider.overrideWithValue(
          AppConfig(apiBaseUrl: 'http://test', environment: 'test', ramadanStart: ramadanStart),
        ),
      ]);
      await c.read(authControllerProvider.future);
      c.listen(statisticsControllerProvider, (_, _) {});
      await pumpEventQueue();
      return c;
    }

    test('tonight loads at once; another preset loads on tap, no validate step', () async {
      final c = await container();
      expect(stats.calls.single, (DateTime(2025, 3, 5), DateTime(2025, 3, 5)));
      await c.read(statisticsControllerProvider.notifier).select(StatsPreset.week);
      expect(stats.calls.last, (DateTime(2025, 3, 2), DateTime(2025, 3, 8)));
      expect(c.read(statisticsControllerProvider).result.value, hasLength(1));
    });

    test('Ramadan counts from the configured first day', () async {
      final c = await container(ramadanStart: DateTime(2025, 3, 1));
      await c.read(statisticsControllerProvider.notifier).select(StatsPreset.ramadan);
      expect(stats.calls.last, (DateTime(2025, 3, 1), DateTime(2025, 3, 5)));
    });

    test('an inverted custom range is rejected without fetching', () async {
      final c = await container();
      final ok = await c
          .read(statisticsControllerProvider.notifier)
          .setCustom(DateTime(2025, 3, 8), DateTime(2025, 3, 2));
      expect(ok, isFalse);
      expect(stats.calls, hasLength(1));
    });

    testWidgets('page shows the hero number, figures and a localized day', (tester) async {
      await tester.pumpWidget(localizedApp(
        const StatisticsPage(),
        overrides: [
          ...testOverrides(FakePeopleRepository([])),
          statisticsRepositoryProvider.overrideWithValue(stats),
        ],
      ));
      await tester.pumpAndSettle();
      expect(find.text(ltr('3')), findsOneWidget);
      expect(find.text(en.ofPeopleServed(9)), findsOneWidget);
      expect(find.text(en.presetRamadan), findsNothing); // not configured
      expect(find.text(formatDate(DateTime(2025, 3, 5))), findsOneWidget);
    });
  }
  ```

- [ ] **Step 2: Run it to verify it fails.**
  Run: `fl test test/presentation/statistics_test.dart`
  Expected: FAIL to compile.

- [ ] **Step 3: Add presets to `lib/features/statistics/domain/statistics.dart`.** Add this after `StatsPeriod`:
  ```dart
  /// What the Statistics screen offers (spec §4.9). Applying a preset fetches
  /// immediately; there is no "Validate Period" step.
  enum StatsPreset { tonight, week, ramadan, custom }

  ({DateTime from, DateTime to}) presetRange(
    StatsPreset preset,
    DateTime now, {
    DateTime? ramadanStart,
    DateTime? customFrom,
    DateTime? customTo,
  }) => switch (preset) {
    StatsPreset.tonight => StatsPeriod.daily.rangeFor(now),
    StatsPreset.week => StatsPeriod.weekly.rangeFor(now),
    StatsPreset.ramadan => (from: dateOnly(ramadanStart ?? now), to: dateOnly(now)),
    StatsPreset.custom => StatsPeriod.custom.rangeFor(
      now,
      customFrom: customFrom,
      customTo: customTo,
    ),
  };
  ```

- [ ] **Step 4: Create `lib/features/statistics/presentation/statistics_controller.dart`.**
  ```dart
  import 'dart:async';

  import 'package:flutter_riverpod/flutter_riverpod.dart';

  import '../../../core/providers.dart';
  import '../../../core/utils/formatters.dart';
  import '../../auth/presentation/auth_controller.dart';
  import '../data/statistics_repository.dart';
  import '../domain/statistics.dart';

  class StatisticsState {
    const StatisticsState({
      required this.preset,
      required this.from,
      required this.to,
      this.result = const AsyncLoading(),
    });

    final StatsPreset preset;
    final DateTime from;
    final DateTime to;
    final AsyncValue<List<DailyStatistics>> result;

    StatisticsState copyWith({
      StatsPreset? preset,
      DateTime? from,
      DateTime? to,
      AsyncValue<List<DailyStatistics>>? result,
    }) => StatisticsState(
      preset: preset ?? this.preset,
      from: from ?? this.from,
      to: to ?? this.to,
      result: result ?? this.result,
    );
  }

  class StatisticsController extends Notifier<StatisticsState> {
    int _request = 0;

    DateTime _now() => ref.read(clockProvider)();

    @override
    StatisticsState build() {
      // Start over when a different volunteer/region signs in.
      ref.watch(authControllerProvider.select((a) => a.value?.region?.id));
      final range = presetRange(StatsPreset.tonight, _now());
      scheduleMicrotask(_fetch);
      return StatisticsState(preset: StatsPreset.tonight, from: range.from, to: range.to);
    }

    Future<void> select(StatsPreset preset) async {
      if (preset == StatsPreset.custom) return;
      final range = presetRange(
        preset,
        _now(),
        ramadanStart: ref.read(appConfigProvider).ramadanStart,
      );
      state = state.copyWith(preset: preset, from: range.from, to: range.to);
      await _fetch();
    }

    /// Returns false (and fetches nothing) when [from] is after [to].
    Future<bool> setCustom(DateTime from, DateTime to) async {
      if (dateOnly(from).isAfter(dateOnly(to))) return false;
      state = state.copyWith(
        preset: StatsPreset.custom,
        from: dateOnly(from),
        to: dateOnly(to),
      );
      await _fetch();
      return true;
    }

    Future<void> refresh() => _fetch();

    Future<void> _fetch() async {
      final request = ++_request;
      state = state.copyWith(result: const AsyncLoading());
      final result = await AsyncValue.guard(() {
        final region = requireRegion(ref);
        return ref
            .read(statisticsRepositoryProvider)
            .fetch(region.id, state.from, state.to);
      });
      // Ignore answers to older requests (quick preset taps).
      if (ref.mounted && request == _request) {
        state = state.copyWith(result: result);
      }
    }
  }

  final statisticsControllerProvider =
      NotifierProvider<StatisticsController, StatisticsState>(
        StatisticsController.new,
      );
  ```

- [ ] **Step 5: Rewrite `lib/features/statistics/presentation/statistics_page.dart`.** The old controller code in this file is removed.
  ```dart
  import 'package:flutter/material.dart';
  import 'package:flutter_riverpod/flutter_riverpod.dart';

  import '../../../core/network/app_failure.dart';
  import '../../../core/providers.dart';
  import '../../../core/theme/app_colors.dart';
  import '../../../core/theme/iftar_colors.dart';
  import '../../../core/utils/formatters.dart';
  import '../../../core/utils/ramadan.dart';
  import '../../../core/widgets/night_sky.dart';
  import '../../../core/widgets/state_views.dart';
  import '../../../l10n/app_localizations.dart';
  import '../domain/statistics.dart';
  import 'statistics_controller.dart';

  class StatisticsPage extends ConsumerWidget {
    const StatisticsPage({super.key});

    @override
    Widget build(BuildContext context, WidgetRef ref) {
      final l = AppLocalizations.of(context);
      final stats = ref.watch(statisticsControllerProvider);
      final controller = ref.read(statisticsControllerProvider.notifier);
      final config = ref.watch(appConfigProvider);
      final day = ramadanDay(config.ramadanStart, ref.watch(clockProvider)());
      final days = stats.result.value;
      final served = days == null ? 0 : StatisticsSummary(days).persons;
      final presets = [
        (StatsPreset.tonight, l.presetTonight),
        (StatsPreset.week, l.presetWeek),
        if (config.ramadanStart != null) (StatsPreset.ramadan, l.presetRamadan),
      ];

      return Scaffold(
        body: RefreshIndicator(
          onRefresh: controller.refresh,
          edgeOffset: 220,
          child: ListView(
            padding: EdgeInsets.zero,
            children: [
              SkyBand(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (day != null)
                      Row(
                        children: [
                          const Icon(Icons.nightlight_round, size: 14, color: AppPalette.gold),
                          const SizedBox(width: 6),
                          Text(l.ramadanDay(day), style: const TextStyle(fontSize: 12, color: AppPalette.gold)),
                        ],
                      ),
                    const SizedBox(height: 4),
                    Text(l.statsTitle, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w500)),
                    const SizedBox(height: 10),
                    Text(
                      ltr('$served'),
                      style: const TextStyle(fontSize: 56, fontWeight: FontWeight.w300, height: 1),
                    ),
                    Text(
                      stats.preset == StatsPreset.tonight && days != null && days.isNotEmpty
                          ? l.ofPeopleServed(days.last.totalPersons)
                          : l.peopleServed,
                      style: const TextStyle(fontSize: 13, color: AppPalette.onSkyMuted),
                    ),
                    const SizedBox(height: 12),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        for (final (preset, label) in presets)
                          _PresetChip(
                            label: label,
                            selected: stats.preset == preset,
                            onTap: () => controller.select(preset),
                          ),
                        if (stats.preset == StatsPreset.custom)
                          _PresetChip(label: l.presetCustom, selected: true, onTap: () {}),
                      ],
                    ),
                  ],
                ),
              ),
              switch (stats.result) {
                AsyncError(:final error) => Padding(
                  padding: const EdgeInsets.only(top: 24),
                  child: ErrorView(failure: toAppFailure(error), onRetry: controller.refresh),
                ),
                AsyncData(:final value) => _Results(
                  days: value,
                  onCustom: () => _pickCustom(context, ref, stats),
                ),
                _ => const Padding(
                  padding: EdgeInsets.only(top: 48),
                  child: LoadingView(),
                ),
              },
              const SizedBox(height: 110),
            ],
          ),
        ),
      );
    }

    Future<void> _pickCustom(BuildContext context, WidgetRef ref, StatisticsState stats) {
      var from = stats.from;
      var to = stats.to;
      var invalid = false;
      return showModalBottomSheet<void>(
        context: context,
        builder: (sheetContext) => StatefulBuilder(
          builder: (sheetContext, setSheetState) {
            final l = AppLocalizations.of(sheetContext);
            Future<void> pick({required bool start}) async {
              final picked = await showDatePicker(
                context: sheetContext,
                initialDate: start ? from : to,
                firstDate: DateTime(2020),
                lastDate: DateTime(2100),
              );
              if (picked != null) setSheetState(() => start ? from = picked : to = picked);
            }

            return Padding(
              padding: const EdgeInsetsDirectional.fromSTEB(20, 0, 20, 24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(l.customDates, style: Theme.of(sheetContext).textTheme.titleMedium),
                  ListTile(
                    leading: const Icon(Icons.event_rounded),
                    title: Text(l.fromDate),
                    trailing: Text(formatDate(from)),
                    onTap: () => pick(start: true),
                  ),
                  ListTile(
                    leading: const Icon(Icons.event_available_rounded),
                    title: Text(l.toDate),
                    trailing: Text(formatDate(to)),
                    onTap: () => pick(start: false),
                  ),
                  if (invalid)
                    Text(l.rangeInvalid, style: TextStyle(color: sheetContext.colors.clay)),
                  const SizedBox(height: 12),
                  FilledButton(
                    onPressed: () async {
                      final ok = await ref
                          .read(statisticsControllerProvider.notifier)
                          .setCustom(from, to);
                      if (!sheetContext.mounted) return;
                      if (ok) {
                        Navigator.of(sheetContext).pop();
                      } else {
                        setSheetState(() => invalid = true);
                      }
                    },
                    child: Text(l.apply),
                  ),
                ],
              ),
            );
          },
        ),
      );
    }
  }

  class _PresetChip extends StatelessWidget {
    const _PresetChip({required this.label, required this.selected, required this.onTap});

    final String label;
    final bool selected;
    final VoidCallback onTap;

    @override
    Widget build(BuildContext context) => Semantics(
      button: true,
      selected: selected,
      child: InkWell(
        borderRadius: BorderRadius.circular(999),
        onTap: onTap,
        child: Container(
          constraints: const BoxConstraints(minHeight: 36),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          decoration: BoxDecoration(
            color: selected ? AppPalette.gold : AppPalette.onSky.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(999),
            border: Border.all(
              color: selected ? AppPalette.gold : AppPalette.onSky.withValues(alpha: 0.2),
            ),
          ),
          child: Text(
            label,
            style: TextStyle(
              fontSize: 12.5,
              fontWeight: FontWeight.w500,
              color: selected ? AppPalette.sky : AppPalette.onSky,
            ),
          ),
        ),
      ),
    );
  }

  class _Results extends StatelessWidget {
    const _Results({required this.days, required this.onCustom});

    final List<DailyStatistics> days;
    final VoidCallback onCustom;

    @override
    Widget build(BuildContext context) {
      final l = AppLocalizations.of(context);
      final c = context.colors;
      final summary = StatisticsSummary(days);
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.all(14),
            child: Row(
              children: [
                Expanded(child: _Figure(value: summary.totalMeals, label: l.figPortions)),
                const SizedBox(width: 10),
                Expanded(child: _Figure(value: summary.singleMeal, label: l.figSingle)),
                const SizedBox(width: 10),
                Expanded(child: _Figure(value: summary.familyMeal, label: l.figFamily)),
              ],
            ),
          ),
          Align(
            alignment: AlignmentDirectional.centerStart,
            child: Padding(
              padding: const EdgeInsetsDirectional.only(start: 6),
              child: TextButton.icon(
                onPressed: onCustom,
                icon: const Icon(Icons.date_range_rounded),
                label: Text(l.customDates),
              ),
            ),
          ),
          if (days.isEmpty)
            EmptyView(icon: Icons.insights_rounded, title: l.noStats)
          else ...[
            Padding(
              padding: const EdgeInsetsDirectional.fromSTEB(16, 4, 16, 6),
              child: Text(l.byDay, style: TextStyle(fontSize: 12, color: c.inkMuted)),
            ),
            for (final day in days) _DayRow(day: day),
          ],
        ],
      );
    }
  }

  class _Figure extends StatelessWidget {
    const _Figure({required this.value, required this.label});

    final int value;
    final String label;

    @override
    Widget build(BuildContext context) => Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(ltr('$value'), style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w600)),
            Text(
              label,
              maxLines: 2,
              style: TextStyle(fontSize: 11.5, color: context.colors.inkMuted),
            ),
          ],
        ),
      ),
    );
  }

  class _DayRow extends StatelessWidget {
    const _DayRow({required this.day});

    final DailyStatistics day;

    @override
    Widget build(BuildContext context) {
      final c = context.colors;
      final date = day.date;
      return Card(
        margin: const EdgeInsetsDirectional.fromSTEB(14, 0, 14, 8),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              SizedBox(
                width: 96,
                child: Text(
                  date == null ? day.label : formatDate(date),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontSize: 12.5, color: c.inkMuted),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(6),
                  child: LinearProgressIndicator(
                    value: day.totalPersons == 0 ? 0 : day.persons / day.totalPersons,
                    minHeight: 8,
                    color: AppPalette.gold,
                    backgroundColor: c.tile,
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Text(
                ltr('${day.totalMeals}'),
                style: const TextStyle(
                  fontWeight: FontWeight.w600,
                  fontFeatures: [FontFeature.tabularFigures()],
                ),
              ),
            ],
          ),
        ),
      );
    }
  }
  ```

- [ ] **Step 6: Run the tests.**
  Run: `fl test`
  Expected: PASS. The existing `StatsPeriod` domain tests are unchanged.

- [ ] **Step 7: Commit.**
  ```bash
  git add lib/features/statistics test/presentation/statistics_test.dart
  git commit -m "feat(mobile): statistics presets that apply instantly" -m "Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>" -- lib/features/statistics test/presentation/statistics_test.dart
  ```

---

### Task 19: Profile (language and appearance settings)

**Files:**
- Rewrite: `lib/features/profile/presentation/profile_page.dart`
- Test: `test/presentation/profile_test.dart`

**Interfaces:**
- Consumes: `settingsControllerProvider` and `AppSettings` (Task 4), `languageNames` (Task 3), `InfoCard` / `InfoTile` (Task 12), `failureText`.
- Produces: `ProfilePage` (same name).

- [ ] **Step 1: Write the failing test** `test/presentation/profile_test.dart`:
  ```dart
  import 'package:flutter/material.dart';
  import 'package:flutter_test/flutter_test.dart';
  import 'package:iftar_mobile/core/settings/settings_controller.dart';
  import 'package:iftar_mobile/core/settings/settings_storage.dart';
  import 'package:iftar_mobile/features/profile/presentation/profile_page.dart';

  import '../support/app_harness.dart';
  import '../support/fakes.dart';

  void main() {
    testWidgets('language and appearance are chosen from Profile', (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 3;
      addTearDown(tester.view.reset);
      final storage = MemorySettingsStorage();
      await tester.pumpWidget(localizedApp(
        const ProfilePage(),
        overrides: [
          ...testOverrides(FakePeopleRepository([])),
          settingsStorageProvider.overrideWithValue(storage),
        ],
      ));
      await tester.pumpAndSettle();

      await tester.tap(find.text(en.language));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Français'));
      await tester.pumpAndSettle();
      expect(storage.values[SettingsController.localeKey], 'fr');

      await tester.tap(find.text(en.appearance));
      await tester.pumpAndSettle();
      await tester.tap(find.text(en.appearanceNight));
      await tester.pumpAndSettle();
      expect(storage.values[SettingsController.themeModeKey], 'dark');
    });
  }
  ```

- [ ] **Step 2: Run it to verify it fails.**
  Run: `fl test test/presentation/profile_test.dart`
  Expected: FAIL. There's no Language row yet.

- [ ] **Step 3: Rewrite `lib/features/profile/presentation/profile_page.dart`.**
  ```dart
  import 'package:flutter/material.dart';
  import 'package:flutter_riverpod/flutter_riverpod.dart';

  import '../../../core/network/app_failure.dart';
  import '../../../core/network/failure_text.dart';
  import '../../../core/providers.dart';
  import '../../../core/settings/locale_resolution.dart';
  import '../../../core/settings/settings_controller.dart';
  import '../../../core/theme/app_colors.dart';
  import '../../../core/theme/iftar_colors.dart';
  import '../../../core/widgets/info_tile.dart';
  import '../../../core/widgets/night_sky.dart';
  import '../../../core/widgets/state_views.dart';
  import '../../../l10n/app_localizations.dart';
  import '../../auth/presentation/auth_controller.dart';
  import '../../people/presentation/people_controller.dart';
  import '../data/export_service.dart';

  class ProfilePage extends ConsumerStatefulWidget {
    const ProfilePage({super.key});

    @override
    ConsumerState<ProfilePage> createState() => _ProfilePageState();
  }

  class _ProfilePageState extends ConsumerState<ProfilePage> {
    bool _exporting = false;

    Future<void> _export() async {
      final l = AppLocalizations.of(context);
      setState(() => _exporting = true);
      try {
        await ref.read(peopleListProvider.notifier).refresh();
        final people = ref.read(peopleListProvider).value ?? const [];
        await ref.read(exportServiceProvider).sharePeople(people);
      } on AppFailure catch (e) {
        if (mounted) showAppSnackBar(context, failureText(l, e), isError: true);
      } catch (_) {
        if (mounted) showAppSnackBar(context, l.exportFailed, isError: true);
      } finally {
        if (mounted) setState(() => _exporting = false);
      }
    }

    Future<void> _logout() async {
      final l = AppLocalizations.of(context);
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: Text(l.logoutTitle),
          content: Text(l.logoutBody),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context, false), child: Text(l.cancel)),
            FilledButton(
              style: FilledButton.styleFrom(minimumSize: const Size(96, 44)),
              onPressed: () => Navigator.pop(context, true),
              child: Text(l.logout),
            ),
          ],
        ),
      );
      if (confirmed == true) {
        await ref.read(authControllerProvider.notifier).logout();
      }
    }

    Future<void> _pickLanguage(String current) => showModalBottomSheet<void>(
      context: context,
      builder: (sheet) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (final code in const ['en', 'fr', 'ar'])
              ListTile(
                title: Text(languageNames[code]!),
                trailing: code == current
                    ? Icon(Icons.check_rounded, color: sheet.colors.actInk)
                    : null,
                onTap: () {
                  ref.read(settingsControllerProvider.notifier).setLocale(Locale(code));
                  Navigator.pop(sheet);
                },
              ),
          ],
        ),
      ),
    );

    Future<void> _pickAppearance(ThemeMode current) {
      final l = AppLocalizations.of(context);
      return showModalBottomSheet<void>(
        context: context,
        builder: (sheet) => SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              for (final mode in ThemeMode.values)
                ListTile(
                  title: Text(_modeLabel(l, mode)),
                  trailing: mode == current
                      ? Icon(Icons.check_rounded, color: sheet.colors.actInk)
                      : null,
                  onTap: () {
                    ref.read(settingsControllerProvider.notifier).setThemeMode(mode);
                    Navigator.pop(sheet);
                  },
                ),
            ],
          ),
        ),
      );
    }

    static String _modeLabel(AppLocalizations l, ThemeMode mode) => switch (mode) {
      ThemeMode.system => l.appearanceSystem,
      ThemeMode.light => l.appearanceDay,
      ThemeMode.dark => l.appearanceNight,
    };

    @override
    Widget build(BuildContext context) {
      final l = AppLocalizations.of(context);
      final c = context.colors;
      final user = ref.watch(authControllerProvider).value;
      if (user == null) return const SizedBox.shrink();
      final env = ref.watch(appConfigProvider);
      final settings = ref.watch(settingsControllerProvider).value ?? const AppSettings();
      final language = Localizations.localeOf(context).languageCode;
      final chevron = Icon(Icons.chevron_right_rounded, color: c.inkMuted);

      return Scaffold(
        body: ListView(
          padding: EdgeInsets.zero,
          children: [
            SkyBand(
              padding: const EdgeInsetsDirectional.fromSTEB(20, 16, 20, 24),
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 30,
                    backgroundColor: AppPalette.gold,
                    child: Text(
                      user.initials,
                      style: const TextStyle(color: AppPalette.sky, fontSize: 20, fontWeight: FontWeight.w600),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          user.name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w500),
                        ),
                        Text(
                          '${l.ramadanKareem} · ${user.region?.name ?? l.noRegion}',
                          style: const TextStyle(fontSize: 13, color: AppPalette.gold),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(AppSpacing.lg),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  InfoCard(
                    title: l.profileTitle,
                    children: [
                      InfoTile(label: l.fullName, value: user.name),
                      InfoTile(label: l.username, value: user.username),
                      InfoTile(label: l.region, value: user.region?.name),
                      InfoTile(label: l.email, value: user.email),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.lg),
                  InfoCard(
                    title: l.settings,
                    children: [
                      InfoTile(
                        icon: Icons.translate_rounded,
                        label: l.language,
                        value: languageNames[language],
                        trailing: chevron,
                        onTap: () => _pickLanguage(language),
                      ),
                      InfoTile(
                        icon: Icons.dark_mode_outlined,
                        label: l.appearance,
                        value: _modeLabel(l, settings.themeMode),
                        trailing: chevron,
                        onTap: () => _pickAppearance(settings.themeMode),
                      ),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.lg),
                  InfoCard(
                    title: l.dataSection,
                    children: [
                      InfoTile(
                        icon: Icons.table_view_rounded,
                        label: l.exportList,
                        showPlaceholder: false,
                        trailing: _exporting
                            ? const SizedBox.square(
                                dimension: 20,
                                child: CircularProgressIndicator(strokeWidth: 2.5),
                              )
                            : Icon(Icons.ios_share_rounded, color: c.actInk),
                        onTap: _exporting ? null : _export,
                      ),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.xl),
                  OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      foregroundColor: c.clay,
                      side: BorderSide(color: c.clay),
                    ),
                    onPressed: _logout,
                    icon: const Icon(Icons.logout_rounded),
                    label: Text(l.logout),
                  ),
                  if (!env.isProduction) ...[
                    const SizedBox(height: AppSpacing.lg),
                    Text(
                      '${env.environment} · ${env.apiBaseUrl}',
                      textAlign: TextAlign.center,
                      textDirection: TextDirection.ltr,
                      style: TextStyle(color: c.inkMuted, fontSize: 12),
                    ),
                  ],
                  const SizedBox(height: 96),
                ],
              ),
            ),
          ],
        ),
      );
    }
  }
  ```

- [ ] **Step 4: Run the tests.**
  Run: `fl test`
  Expected: PASS.

- [ ] **Step 5: Commit.**
  ```bash
  git add lib/features/profile/presentation/profile_page.dart test/presentation/profile_test.dart
  git commit -m "feat(mobile): language and appearance settings in profile" -m "Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>" -- lib/features/profile/presentation/profile_page.dart test/presentation/profile_test.dart
  ```

---

### Task 20: Cleanup, RTL audit, layout matrix, final verification

**Files:**
- Modify: `lib/core/theme/app_colors.dart` (remove `AppColors`), `lib/core/widgets/brand.dart` (localized logo label), and any file still using `AppColors`, hardcoded strings, or left/right paddings
- Test: `test/presentation/layout_matrix_test.dart`

- [ ] **Step 1: Write the layout matrix test** `test/presentation/layout_matrix_test.dart`:
  ```dart
  import 'package:flutter/material.dart';
  import 'package:flutter_test/flutter_test.dart';
  import 'package:iftar_mobile/core/settings/settings_controller.dart';
  import 'package:iftar_mobile/core/settings/settings_storage.dart';
  import 'package:iftar_mobile/features/auth/presentation/login_page.dart';
  import 'package:iftar_mobile/features/auth/presentation/register_page.dart';
  import 'package:iftar_mobile/features/auth/presentation/welcome_page.dart';
  import 'package:iftar_mobile/features/people/presentation/people_list_page.dart';
  import 'package:iftar_mobile/features/people/presentation/person_details_page.dart';
  import 'package:iftar_mobile/features/people/presentation/person_form_page.dart';
  import 'package:iftar_mobile/features/profile/presentation/profile_page.dart';
  import 'package:iftar_mobile/features/scan/presentation/session_summary_page.dart';
  import 'package:iftar_mobile/features/statistics/data/statistics_repository.dart';
  import 'package:iftar_mobile/features/statistics/presentation/statistics_page.dart';

  import '../support/app_harness.dart';
  import '../support/fakes.dart';
  import 'statistics_test.dart' show FakeStatisticsRepository;

  void main() {
    final screens = <String, Widget>{
      'welcome': const WelcomePage(),
      'login': const LoginPage(),
      'register': const RegisterPage(),
      'people': const PeopleListPage(),
      'add': const AddPersonPage(),
      'details': const PersonDetailsPage(personId: 101),
      'stats': const StatisticsPage(),
      'profile': const ProfilePage(),
      'summary': const SessionSummaryPage(
        summary: SessionSummary(served: 42, singleMeals: 20, familyMeals: 22),
      ),
    };

    for (final locale in const [Locale('en'), Locale('fr'), Locale('ar')]) {
      for (final night in [false, true]) {
        for (final entry in screens.entries) {
          testWidgets('${entry.key} fits 360×760 at 1.3× · ${locale.languageCode} · ${night ? 'night' : 'day'}', (tester) async {
            tester.view.physicalSize = const Size(1080, 2280);
            tester.view.devicePixelRatio = 3;
            tester.platformDispatcher.textScaleFactorTestValue = 1.3;
            addTearDown(() {
              tester.view.reset();
              tester.platformDispatcher.clearTextScaleFactorTestValue();
            });
            await tester.pumpWidget(localizedApp(
              entry.value,
              locale: locale,
              night: night,
              overrides: [
                ...testOverrides(FakePeopleRepository([
                  person(101, first: 'Mohamed Ali Ben Abdelkader', last: 'Trabelsi'),
                  person(102, takenToday: true),
                ])),
                statisticsRepositoryProvider.overrideWithValue(FakeStatisticsRepository()),
                settingsStorageProvider.overrideWithValue(MemorySettingsStorage()),
                regionsProvider.overrideWith((ref) async => [testRegion]),
              ],
            ));
            await tester.pumpAndSettle();
            expect(tester.takeException(), isNull);
          });
        }
      }
    }
  }
  ```
  `regionsProvider` is exported from `register_page.dart`, so the register screen doesn't call the network.

- [ ] **Step 2: Run it.**
  Run: `fl test test/presentation/layout_matrix_test.dart`
  Expected: PASS for all 54 cases. For any failure, fix the overflowing widget, using `Flexible` / `Expanded`, `maxLines` with ellipsis, or `Wrap`, then re-run. Don't relax the test.

- [ ] **Step 3: Remove the legacy `AppColors` class** from `lib/core/theme/app_colors.dart`, then list every remaining use:
  ```bash
  fl analyze 2>&1 | grep -i "AppColors" ; grep -rn "AppColors\." lib test
  ```
  Replace each one with a semantic token:

  | Legacy | Replacement |
  |---|---|
  | `AppColors.teal`, `success` | `context.colors.act` |
  | `tealDeep`, `tealShade` | `context.colors.actInk` |
  | `tealTint`, `successSoft` | `context.colors.actSoft` |
  | `night`, `nightMid`, `nightGlow` | `AppPalette.sky`, `skyMid`, `horizon` |
  | `gold`, `goldSoft` | `AppPalette.gold`, `AppPalette.goldSoft` |
  | `goldDeep`, `warning` | `context.colors.goldInk` |
  | `ivory` | `context.colors.page` |
  | `surface` | `context.colors.surface` |
  | `outline` | `context.colors.line` |
  | `ink`, `inkMuted` | `context.colors.ink`, `context.colors.inkMuted` |
  | `danger`, `dangerSoft` | `context.colors.clay`, `context.colors.claySoft` |
  | `warningSoft` | `context.colors.warnSoft` |
  | `nightGradient` | `AppPalette.skyGradient` |

  Expected after the fixes: `grep -rn "AppColors\." lib test` prints nothing.

- [ ] **Step 4: Localize the logo label.** In `lib/core/widgets/brand.dart` `BrandLogo.build`, use `label: AppLocalizations.of(context).ramadanKareem` (import `../../l10n/app_localizations.dart`).

- [ ] **Step 5: Audit for hardcoded strings.**
  ```bash
  grep -rnE "Text\('[A-Za-z]|(label|tooltip|hintText|title|message): '[A-Za-z]" lib --include=*.dart | grep -v "lib/l10n/"
  ```
  Expected: no hits. Native language names come from `languageNames`. Move anything else into the ARB files (all three), then re-run `fl gen-l10n` and the ARB completeness test.

- [ ] **Step 6: Audit for RTL.**
  ```bash
  grep -rnE "EdgeInsets\.(only|fromLTRB)\(|Alignment\.(centerLeft|centerRight|topLeft|topRight|bottomLeft|bottomRight)|Positioned\((left|right)" lib --include=*.dart
  ```
  For each hit:
  - **Symmetric values** (same left and right): fine.
  - **Different left/right values**: convert to `EdgeInsetsDirectional.only(start:, end:)` or `fromSTEB`, `AlignmentDirectional.centerStart` / `centerEnd`, or `PositionedDirectional(start:, end:)`.
  - **Intentionally physical**: the camera viewfinder, the moon position, and `AuthScaffold`'s symmetric `fromLTRB(24, 26, 24, 8)` are fine.

- [ ] **Step 7: Run the full verification.**
  ```bash
  fl gen-l10n && fl analyze && fl test
  ```
  Expected:
  - `No issues found!`, or only the infos recorded as already existing in Task 0.
  - All tests pass.

- [ ] **Step 8: Optional, but recommended before handing over: build a debug APK** to confirm the fonts and assets bundle on Android. The first build takes about 17 minutes over the bind mount.
  ```bash
  fl build apk --debug --dart-define-from-file=config/development.json
  ```
  Expected: `✓ Built build/app/outputs/flutter-apk/app-debug.apk`. Install it on a phone and check Welcome in Arabic: the Ruqaa calligraphy should render and the layout should be mirrored.

- [ ] **Step 9: Commit.**
  ```bash
  git add -u lib test && git add test/presentation/layout_matrix_test.dart
  git commit -m "chore(mobile): drop legacy colors, RTL audit, layout matrix across en/fr/ar × day/night" -m "Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>" -- lib test
  ```

---

## Spec coverage (self-review)

| Spec section | Task(s) |
|---|---|
| §1 Success criteria 1–8 | 14, 17 (1, 2); 17 (3); 15 (4); 13 (5); 20 (6); 2 (7); all tasks (8) |
| §3.1 Color tokens | 2 |
| §3.2 Typography (bundled fonts, Ruqaa only for brand and blessing, Arabic tracking 0) | 1, 2, 5, 9, 16, 17 |
| §3.3 Shape, ornaments, seal, motion, haptics | 2, 6, 17 |
| §4.1 Welcome (language picker, logo kept, hadith) | 9 |
| §4.2 Login / Register | 10 |
| §4.3 People list (filters, chips, empty states, pull to refresh) | 11 |
| §4.4 Details and edit | 12, 13 |
| §4.5 Add person | 13 |
| §4.6 Scan (all states, viewfinder colors, no manual-ID dialog) | 14, 17 |
| §4.7 Find without a card | 15 |
| §4.8 Session summary | 16, 17 |
| §4.9 Statistics presets | 18 |
| §4.10 Profile settings | 19 |
| §4.11 Bottom navigation | 8 |
| §5 Localization (ARB, fallback, Tunisian words, Western digits, RTL, bidi) | 3, 5, 7, 20 |
| §6.2 Settings | 4 |
| §6.3 Instant identify | 14 |
| §6.4 Safety invariants | 14 (existing tests kept green) |
| §6.5 People filter | 11 |
| §6.6 Add form (`findByCin`, card-ID scanner) | 13 |
| §6.7 Ramadan day | 5 |
| §7 Error handling | 7, 10, 17 |
| §8 Accessibility. Verdicts are announced through `Semantics(liveRegion: true)` on the band, which avoids the deprecated `SemanticsService.announce` | 6, 7, 17, 20 |
| §9 Testing | every task; matrix in 20 |

## Execution notes

- **Tasks are sequential.** Tasks 14–17 depend on each other in that order: controller, then Find, then Summary, then the scan screen.
- **Translations and the hadith wording** need a native-speaker review before release (spec §10). This plan doesn't block on it.
- **Release checklist:** set `RAMADAN_START` in `config/production.json` to the official first day of Ramadan before each season's build.
