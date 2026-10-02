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
import 'package:iftar_mobile/l10n/app_localizations.dart';

import '../support/app_harness.dart';
import '../support/fakes.dart';
import '../support/fonts.dart';
import 'statistics_test.dart' show FakeStatisticsRepository;

/// A screen and one string it must show once it has rendered.
typedef _Screen = ({Widget page, String Function(AppLocalizations) marker});

/// Viewport (logical size) and text scale combinations.
typedef _Viewport = ({String name, Size size, double scale});

void main() {
  setUpAll(loadAppFonts);

  final screens = <String, _Screen>{
    'welcome': (page: const WelcomePage(), marker: (l) => l.signIn),
    'login': (page: const LoginPage(), marker: (l) => l.welcomeBack),
    'register': (page: const RegisterPage(), marker: (l) => l.registerTitle),
    'people': (page: const PeopleListPage(), marker: (l) => l.peopleTitle),
    'add': (page: const AddPersonPage(), marker: (l) => l.addTitle),
    'details': (
      page: const PersonDetailsPage(personId: 101),
      marker: (l) => l.detailsTitle,
    ),
    'stats': (page: const StatisticsPage(), marker: (l) => l.statsTitle),
    'profile': (page: const ProfilePage(), marker: (l) => l.ramadanKareem),
    'summary': (
      page: const SessionSummaryPage(
        summary: SessionSummary(served: 42, singleMeals: 20, familyMeals: 22),
      ),
      marker: (l) => l.summaryServedByYou,
    ),
  };

  const viewports = <_Viewport>[
    (name: '360x760 @1.3x', size: Size(360, 760), scale: 1.3),
    (name: '360x760 @2.0x', size: Size(360, 760), scale: 2.0),
    (name: '320x568 @1.0x', size: Size(320, 568), scale: 1.0),
  ];

  for (final viewport in viewports) {
    for (final locale in const [Locale('en'), Locale('fr'), Locale('ar')]) {
      for (final night in [false, true]) {
        for (final entry in screens.entries) {
          testWidgets(
            '${entry.key} fits ${viewport.name} · ${locale.languageCode} · '
            '${night ? 'night' : 'day'}',
            (tester) async {
              tester.view.physicalSize = viewport.size * 3;
              tester.view.devicePixelRatio = 3;
              tester.platformDispatcher.textScaleFactorTestValue = viewport.scale;
              addTearDown(() {
                tester.view.reset();
                tester.platformDispatcher.clearTextScaleFactorTestValue();
              });
              await tester.pumpWidget(
                localizedApp(
                  entry.value.page,
                  locale: locale,
                  night: night,
                  overrides: [
                    ...testOverrides(
                      FakePeopleRepository([
                        person(
                          101,
                          first: 'Mohamed Ali Ben Abdelkader',
                          last: 'Trabelsi',
                        ),
                        person(102, takenToday: true),
                      ]),
                    ),
                    statisticsRepositoryProvider.overrideWithValue(
                      FakeStatisticsRepository(),
                    ),
                    settingsStorageProvider.overrideWithValue(
                      MemorySettingsStorage(),
                    ),
                    regionsProvider.overrideWith((ref) async => [testRegion]),
                  ],
                ),
              );
              await tester.pumpAndSettle();
              expect(tester.takeException(), isNull);
              final l = lookupAppLocalizations(locale);
              expect(
                find.textContaining(entry.value.marker(l), findRichText: true),
                findsWidgets,
                reason: '${entry.key} did not render its expected heading',
              );
            },
          );
        }
      }
    }
  }
}
