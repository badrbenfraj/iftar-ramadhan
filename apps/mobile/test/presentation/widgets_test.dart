import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:iftar_mobile/core/network/app_failure.dart';
import 'package:iftar_mobile/core/utils/formatters.dart';
import 'package:iftar_mobile/core/widgets/brand.dart';
import 'package:iftar_mobile/core/widgets/status_chip.dart';
import 'package:iftar_mobile/features/auth/presentation/auth_controller.dart';
import 'package:iftar_mobile/features/auth/presentation/login_page.dart';
import 'package:iftar_mobile/features/people/domain/fasting_person.dart';
import 'package:iftar_mobile/features/people/presentation/people_list_page.dart';
import 'package:iftar_mobile/features/scan/presentation/scan_controller.dart';
import 'package:iftar_mobile/features/scan/presentation/scan_result_panel.dart';
import 'package:iftar_mobile/l10n/app_localizations.dart';

import '../support/app_harness.dart';
import '../support/fakes.dart';
import '../support/fonts.dart';

void main() {
  testWidgets('login validates required fields before calling the API', (
    tester,
  ) async {
    await tester.pumpWidget(localizedApp(const LoginPage()));
    await tester.tap(find.text(en.signIn));
    await tester.pump();
    expect(find.text('Username is required.'), findsOneWidget);
    expect(find.text('Password is required.'), findsOneWidget);
  });

  group('scan result panel', () {
    setUpAll(loadAppFonts);

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

    void phone(WidgetTester tester, {double textScale = 1}) {
      tester.view.physicalSize = const Size(1080, 2280);
      tester.view.devicePixelRatio = 3;
      tester.platformDispatcher.textScaleFactorTestValue = textScale;
      addTearDown(() {
        tester.view.reset();
        tester.platformDispatcher.clearTextScaleFactorTestValue();
      });
    }

    const withCin = FastingPerson(
      id: 142,
      firstName: 'Fatma',
      lastName: 'Trabelsi',
      cin: '08123812',
      singleMeal: 0,
      familyMeal: 1,
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
      expect(find.text(en.alreadyServedTonight), findsOneWidget);
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
      await pumpPanel(tester, const ScanIdentifying(withCin, noCard: true));
      await tester.pump(const Duration(milliseconds: 300)); // seal pulse loops
      expect(find.text('Fatma Trabelsi'), findsOneWidget);
      expect(find.text(en.noCardCheck(ltr('812'))), findsOneWidget);
      expect(find.text(en.confirmHandOver), findsNothing);
    });

    testWidgets('the CIN check stays on screen from ready through confirming and failure', (tester) async {
      final check = find.text(en.noCardCheck(ltr('812')));
      await pumpPanel(tester, const ScanReady(withCin, noCard: true));
      expect(check, findsOneWidget);
      await pumpPanel(tester, const ScanConfirming(withCin, noCard: true));
      await tester.pump(const Duration(milliseconds: 300));
      expect(check, findsOneWidget);
      await pumpPanel(
        tester,
        const ScanFailed(NetworkFailure(), personId: 142, person: withCin, noCard: true),
      );
      await tester.pump(const Duration(milliseconds: 300));
      expect(check, findsOneWidget);
    });

    testWidgets('no card and no CIN on file says to check another document', (tester) async {
      const noCin = FastingPerson(id: 5, firstName: 'Sami', lastName: 'Gharbi', singleMeal: 1, familyMeal: 0);
      const shortCin = FastingPerson(id: 6, firstName: 'Sami', lastName: 'Gharbi', cin: '12', singleMeal: 1, familyMeal: 0);
      for (final p in [noCin, shortCin]) {
        await pumpPanel(tester, ScanReady(p, noCard: true));
        await tester.pump(const Duration(milliseconds: 400));
        expect(find.text(en.noCinOnFile), findsOneWidget, reason: '${p.cin}');
      }
      await pumpPanel(tester, const ScanReady(noCin));
      await tester.pump(const Duration(milliseconds: 400));
      expect(find.text(en.noCinOnFile), findsNothing, reason: 'a card scan needs no CIN check');
    });

    testWidgets('switching person never shows both verdicts at once', (tester) async {
      final a = person(1, first: 'Aziza', last: 'Ouerghi', takenToday: true);
      final b = person(2, first: 'Najwa', last: 'Chalbi');
      await pumpPanel(tester, ScanAlreadyTaken(a, testNow));
      await tester.pump(const Duration(milliseconds: 400));
      await pumpPanel(tester, ScanReady(b));
      for (var ms = 0; ms <= 300; ms += 20) {
        final both = find.text(MealStatusWords.taken).evaluate().isNotEmpty &&
            find.text(MealStatusWords.notTaken).evaluate().isNotEmpty;
        expect(both, isFalse, reason: 'both verdicts visible at +${ms}ms');
        expect(find.text('Aziza Ouerghi').evaluate().isNotEmpty && find.text('Najwa Chalbi').evaluate().isNotEmpty, isFalse);
        await tester.pump(const Duration(milliseconds: 20));
      }
      expect(find.text(MealStatusWords.notTaken), findsOneWidget);
    });

    testWidgets('a card scan shows no CIN check', (tester) async {
      await pumpPanel(tester, const ScanReady(withCin));
      expect(find.text(en.noCardCheck(ltr('812'))), findsNothing);
    });

    testWidgets('picking without a card shows the last 3 digits of the CIN', (tester) async {
      final repo = FakePeopleRepository([withCin]);
      await tester.pumpWidget(
        localizedApp(
          Consumer(
            builder: (context, ref, _) => Scaffold(
              body: Align(
                alignment: Alignment.bottomCenter,
                child: ScanResultPanel(
                  status: ref.watch(scanControllerProvider).status,
                  onFindWithoutCard: () {},
                ),
              ),
            ),
          ),
          overrides: testOverrides(repo),
        ),
      );
      final container = ProviderScope.containerOf(tester.element(find.byType(Scaffold)));
      await container.read(authControllerProvider.future);
      await container.read(scanControllerProvider.notifier).pickWithoutCard(142);
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pump(const Duration(milliseconds: 300));
      expect(container.read(scanControllerProvider).status, isA<ScanReady>());
      expect(find.text(en.noCardCheck(ltr('812'))), findsOneWidget);
      expect(find.text(en.confirmHandOver), findsOneWidget);
    });

    for (final locale in [const Locale('ar'), const Locale('fr')]) {
      testWidgets('a very long name ellipsizes without overflow (${locale.languageCode})', (tester) async {
        phone(tester, textScale: 1.3);
        final long = person(9, first: 'Mohamed Ali Ben Abdelkader', last: 'Trabelsi');
        for (final status in <ScanStatus>[
          ScanReady(long),
          ScanFailed(const NetworkFailure(), personId: 9, person: long),
          ScanAlreadyTaken(long, null),
        ]) {
          await pumpPanel(tester, status, locale: locale);
          await tester.pump(const Duration(milliseconds: 300));
          expect(tester.takeException(), isNull, reason: '$status');
        }
        await pumpPanel(tester, ScanReady(long), locale: locale);
        await tester.pump(const Duration(milliseconds: 500)); // old sheet leaves
        final name = tester.widget<Text>(find.textContaining('Mohamed Ali Ben Abdelkader'));
        expect(name.overflow, TextOverflow.ellipsis);
        expect(name.maxLines, 1);
      });
    }

    for (final scale in [1.3, 2.0]) {
      for (final locale in [const Locale('en'), const Locale('ar')]) {
        testWidgets('real fonts at ${scale}x in ${locale.languageCode}: verdicts fit 360×760', (tester) async {
          phone(tester, textScale: scale);
          final l = lookupAppLocalizations(locale);
          final long = person(9, first: 'Mohamed Ali Ben Abdelkader', last: 'Trabelsi');
          final cases = <(ScanStatus, List<String>)>[
            (ScanReady(long, noCard: true), [MealStatusWords.notTaken, l.confirmHandOver]),
            (
              ScanAlreadyTaken(long, DateTime(2025, 3, 5, 18, 10)),
              [MealStatusWords.taken, l.scanNextCard],
            ),
            (ScanConfirmed(long), [blessingText]),
            (
              ScanFailed(const NetworkFailure(), personId: 9, person: long),
              [l.notConfirmedYet, l.retry],
            ),
          ];
          for (final (status, texts) in cases) {
            await pumpPanel(tester, status, locale: locale);
            await tester.pump(const Duration(milliseconds: 400));
            expect(tester.takeException(), isNull, reason: '$status');
            for (final t in texts) {
              expect(find.text(t), findsOneWidget, reason: '$status: $t');
              final r = tester.getRect(find.text(t));
              expect(
                const Rect.fromLTWH(0, 0, 360, 760).contains(r.topLeft) &&
                    const Rect.fromLTWH(0, 0, 360, 760).contains(r.bottomRight - const Offset(0.01, 0.01)),
                isTrue,
                reason: '$status: "$t" must be fully on screen, was $r',
              );
            }
          }
        });
      }
    }

    testWidgets('every state fits 360×760 in Arabic at 1.3× text', (tester) async {
      phone(tester, textScale: 1.3);
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
        const ScanFailed(NetworkFailure(), personId: 9),
        ScanFailed(const NetworkFailure(), personId: 9, person: long),
      ];
      for (final status in states) {
        await pumpPanel(tester, status, locale: const Locale('ar'));
        await tester.pump(const Duration(milliseconds: 300));
        expect(tester.takeException(), isNull, reason: '$status');
      }
    });
  });

  testWidgets('people list shows counts and filters by search', (tester) async {
    final repo = FakePeopleRepository([
      person(1, first: 'Najwa', last: 'Chalbi'),
      person(2, first: 'Aziza', last: 'Ouerghi', takenToday: true),
    ]);
    await tester.pumpWidget(
      localizedApp(const PeopleListPage(), overrides: testOverrides(repo)),
    );
    await tester.pumpAndSettle();

    expect(find.text(en.peopleTitle), findsOneWidget);
    expect(find.text(en.peopleCount(ltr('2'), ltr('1'))), findsOneWidget);
    expect(find.text(isolate('Najwa Chalbi')), findsOneWidget);
    expect(find.text(isolate('Aziza Ouerghi')), findsOneWidget);

    await tester.enterText(find.byType(TextField), 'aziza');
    await tester.pumpAndSettle();
    expect(find.text(isolate('Najwa Chalbi')), findsNothing);
    expect(find.text(isolate('Aziza Ouerghi')), findsOneWidget);

    await tester.enterText(find.byType(TextField), 'nobody');
    await tester.pumpAndSettle();
    expect(find.textContaining('No one matches'), findsOneWidget);
  });
}
