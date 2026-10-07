import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:iftar_mobile/core/config/app_config.dart';
import 'package:iftar_mobile/core/network/app_failure.dart';
import 'package:iftar_mobile/core/network/failure_text.dart';
import 'package:iftar_mobile/core/providers.dart';
import 'package:iftar_mobile/core/settings/settings_controller.dart';
import 'package:iftar_mobile/core/settings/settings_storage.dart';
import 'package:iftar_mobile/core/utils/formatters.dart';
import 'package:iftar_mobile/features/auth/domain/user.dart';
import 'package:iftar_mobile/features/auth/presentation/auth_controller.dart';
import 'package:iftar_mobile/features/people/data/people_repository.dart';
import 'package:iftar_mobile/features/people/domain/fasting_person.dart';
import 'package:iftar_mobile/features/profile/data/export_service.dart';
import 'package:iftar_mobile/features/profile/presentation/profile_page.dart';

import '../support/app_harness.dart';
import '../support/fakes.dart';
import '../support/fonts.dart';
import '../support/storage.dart';

class _SpyAuth extends FakeAuthController {
  static int logouts = 0;

  @override
  Future<void> logout() async => logouts++;
}

class _FailingExport extends ExportService {
  _FailingExport(this.error);

  final Object error;

  @override
  Future<void> sharePeople(List<FastingPerson> people) async => throw error;
}

void main() {
  setUpAll(loadAppFonts);

  late MemorySettingsStorage storage;

  setUp(() {
    storage = MemorySettingsStorage();
    _SpyAuth.logouts = 0;
  });

  void phone(WidgetTester tester, {double scale = 1, double inset = 0}) {
    tester.view.physicalSize = const Size(360, 760);
    tester.view.devicePixelRatio = 1;
    tester.view.padding = FakeViewPadding(bottom: inset);
    tester.view.viewPadding = FakeViewPadding(bottom: inset);
    addTearDown(tester.view.reset);
    tester.platformDispatcher.textScaleFactorTestValue = scale;
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
  }

  Future<void> pumpProfile(
    WidgetTester tester, {
    MemorySettingsStorage? settings,
    Locale locale = const Locale('en'),
    bool night = false,
    List<Override> extra = const [],
    User? user = testUser,
  }) async {
    await tester.pumpWidget(localizedApp(
      const ProfilePage(),
      locale: locale,
      night: night,
      overrides: [
        ...testOverrides(FakePeopleRepository([]), user: user),
        settingsStorageProvider.overrideWithValue(settings ?? storage),
        ...extra,
      ],
    ));
    await tester.pumpAndSettle();
  }

  ProviderContainer containerOf(WidgetTester tester) =>
      ProviderScope.containerOf(tester.element(find.byType(ProfilePage)));

  testWidgets('language and appearance are chosen from Profile', (tester) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    await pumpProfile(tester);

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

  testWidgets('a storage failure keeps the choice and shows a localized snackbar', (tester) async {
    phone(tester);
    await pumpProfile(tester, settings: ThrowingWriteStorage());

    await tester.tap(find.text(en.language));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Français'));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    expect(containerOf(tester).read(settingsControllerProvider).value!.locale, const Locale('fr'));
    expect(find.text(en.errUnknown), findsOneWidget);

    await tester.tap(find.text(en.appearance));
    await tester.pumpAndSettle();
    await tester.tap(find.text(en.appearanceNight));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    expect(containerOf(tester).read(settingsControllerProvider).value!.themeMode, ThemeMode.dark);
    expect(find.text(en.errUnknown), findsOneWidget);
  });

  testWidgets('the account card shows the region name in an isolate', (tester) async {
    phone(tester);
    await pumpProfile(tester);
    expect(find.text(en.region), findsOneWidget);
    expect(find.text(isolate(testRegion.name)), findsOneWidget);
    expect(find.text('${en.ramadanKareem} · ${isolate(testRegion.name)}'), findsOneWidget);
  });

  testWidgets('a volunteer without a region shows a dash and the no-region line', (tester) async {
    phone(tester);
    const noRegion = User(
      id: 3,
      name: 'Vol Two',
      username: 'vol2',
      email: 'vol2@example.com',
      roles: ['USER'],
      isAccountDisabled: false,
    );
    await pumpProfile(tester, user: noRegion);
    expect(find.text('${en.ramadanKareem} · ${en.noRegion}'), findsOneWidget);
    expect(find.text('—'), findsOneWidget);
  });

  group('language and appearance options', () {
    testWidgets('are native names, selectable, 48 tall, and mark the current one', (tester) async {
      final handle = tester.ensureSemantics();
      phone(tester);
      await pumpProfile(tester);
      await tester.tap(find.text(en.language));
      await tester.pumpAndSettle();

      // The Language row already shows the current name; the sheet's options come last.
      Matcher option(String label, {required bool selected}) => matchesSemantics(
        label: label,
        isButton: true,
        isSelected: selected,
        hasSelectedState: true,
        hasTapAction: true,
        hasFocusAction: true,
        isFocusable: true,
      );
      expect(tester.getSemantics(find.text('English').last), option('English', selected: true));
      expect(tester.getSemantics(find.text('Français').last), option('Français', selected: false));
      expect(tester.getSemantics(find.text('العربية').last), option('العربية', selected: false));
      for (final name in ['English', 'Français', 'العربية']) {
        final box = find.ancestor(of: find.text(name).last, matching: find.byType(InkWell));
        expect(tester.getSize(box.first).height, greaterThanOrEqualTo(48));
      }
      handle.dispose();
    });

    testWidgets('appearance options expose the selected state too', (tester) async {
      final handle = tester.ensureSemantics();
      phone(tester);
      await pumpProfile(tester);
      await tester.tap(find.text(en.appearance));
      await tester.pumpAndSettle();
      expect(
        tester.getSemantics(find.text(en.appearanceSystem).last),
        matchesSemantics(
          label: en.appearanceSystem,
          isButton: true,
          isSelected: true,
          hasSelectedState: true,
          hasTapAction: true,
          hasFocusAction: true,
          isFocusable: true,
        ),
      );
      for (final label in [en.appearanceDay, en.appearanceNight]) {
        final box = find.ancestor(of: find.text(label).last, matching: find.byType(InkWell));
        expect(tester.getSize(box.first).height, greaterThanOrEqualTo(48));
      }
      handle.dispose();
    });

    testWidgets('the settings rows are at least 48 tall', (tester) async {
      phone(tester);
      await pumpProfile(tester);
      for (final label in [en.language, en.appearance, en.exportList]) {
        final row = find.ancestor(of: find.text(label), matching: find.byType(InkWell));
        expect(tester.getSize(row.first).height, greaterThanOrEqualTo(48), reason: label);
      }
    });

    testWidgets('Arabic shows native names, never translated', (tester) async {
      phone(tester);
      await pumpProfile(tester, locale: const Locale('ar'));
      await tester.tap(find.text(ar.language));
      await tester.pumpAndSettle();
      expect(find.text('English'), findsOneWidget);
      expect(find.text('Français'), findsOneWidget);
      expect(find.text('العربية'), findsWidgets);
    });
  });

  group('kept behavior', () {
    testWidgets('logout asks first, then signs out', (tester) async {
      phone(tester);
      await tester.pumpWidget(localizedApp(
        const ProfilePage(),
        overrides: [
          authControllerProvider.overrideWith(_SpyAuth.new),
          peopleRepositoryProvider.overrideWithValue(FakePeopleRepository([])),
          clockProvider.overrideWithValue(() => testNow),
          settingsStorageProvider.overrideWithValue(storage),
        ],
      ));
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text(en.logout));
      await tester.pumpAndSettle();
      await tester.tap(find.text(en.logout));
      await tester.pumpAndSettle();
      expect(find.text(en.logoutTitle), findsOneWidget);
      expect(_SpyAuth.logouts, 0);

      await tester.tap(find.text(en.cancel));
      await tester.pumpAndSettle();
      expect(_SpyAuth.logouts, 0);

      await tester.tap(find.text(en.logout));
      await tester.pumpAndSettle();
      await tester.tap(find.descendant(of: find.byType(AlertDialog), matching: find.text(en.logout)));
      await tester.pumpAndSettle();
      expect(_SpyAuth.logouts, 1);
    });

    testWidgets('the environment line shows outside production', (tester) async {
      phone(tester);
      await pumpProfile(tester, extra: [
        appConfigProvider.overrideWithValue(
          const AppConfig(apiUrl: 'http://10.0.2.2:3000', environment: 'development'),
        ),
      ]);
      await tester.dragUntilVisible(
        find.text('development · http://10.0.2.2:3000/api/v1'),
        find.byType(ListView),
        const Offset(0, -200),
      );
      expect(find.text('development · http://10.0.2.2:3000/api/v1'), findsOneWidget);
    });

    testWidgets('the environment line is hidden in production', (tester) async {
      phone(tester);
      await pumpProfile(tester, extra: [
        appConfigProvider.overrideWithValue(
          const AppConfig(apiUrl: 'https://x', environment: 'production'),
        ),
      ]);
      await tester.drag(find.byType(ListView), const Offset(0, -5000));
      await tester.pumpAndSettle();
      expect(find.textContaining('https://x/api/v1'), findsNothing);
    });

    testWidgets('a failed export is reported in the UI language', (tester) async {
      phone(tester);
      await pumpProfile(tester, extra: [
        exportServiceProvider.overrideWithValue(_FailingExport(StateError('disk'))),
      ]);
      await tester.ensureVisible(find.text(en.exportList));
      await tester.tap(find.text(en.exportList));
      await tester.pumpAndSettle();
      expect(find.text(en.exportFailed), findsOneWidget);
    });

    testWidgets('a failed export with an app failure uses its localized text', (tester) async {
      phone(tester);
      await pumpProfile(tester, extra: [
        exportServiceProvider.overrideWithValue(_FailingExport(const NetworkFailure())),
      ]);
      await tester.ensureVisible(find.text(en.exportList));
      await tester.tap(find.text(en.exportList));
      await tester.pumpAndSettle();
      expect(find.text(failureText(en, const NetworkFailure())), findsOneWidget);
    });
  });

  for (final inset in [34.0, 0.0]) {
    testWidgets('Logout clears the 72 px bar and the docked button at inset $inset', (tester) async {
      phone(tester, inset: inset);
      await pumpProfile(tester);
      await tester.drag(find.byType(ListView), const Offset(0, -5000));
      await tester.pumpAndSettle();
      final bottom = tester.getBottomLeft(find.byWidgetPredicate((w) => w is OutlinedButton)).dy;
      expect(760 - bottom, greaterThanOrEqualTo(72 + inset + 40));
    });
  }

  for (final locale in [const Locale('en'), const Locale('ar')]) {
    for (final scale in [1.3, 2.0]) {
      for (final night in [false, true]) {
        final name = '360x760, text $scale, ${locale.languageCode}, ${night ? 'night' : 'day'}';
        final l = locale.languageCode == 'ar' ? ar : en;
        testWidgets('lays out at $name', (tester) async {
          phone(tester, scale: scale);
          await pumpProfile(tester, locale: locale, night: night);
          expect(find.text(isolate(testUser.name)), findsWidgets);
          expect(find.text(l.profileTitle.toUpperCase()), findsOneWidget);
          await tester.dragUntilVisible(
            find.text(l.language),
            find.byType(ListView),
            const Offset(0, -150),
          );
          expect(find.text(l.language), findsOneWidget);
          await tester.dragUntilVisible(
            find.text(l.exportList),
            find.byType(ListView),
            const Offset(0, -150),
          );
          expect(find.text(l.exportList), findsOneWidget);
          await tester.drag(find.byType(ListView), const Offset(0, -5000));
          await tester.pumpAndSettle();
          expect(find.text(l.logout), findsOneWidget);
          expect(tester.takeException(), isNull);
        });
      }
    }
  }
}
