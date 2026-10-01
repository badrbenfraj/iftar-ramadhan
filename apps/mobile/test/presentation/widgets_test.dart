import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:iftar_mobile/core/network/app_failure.dart';
import 'package:iftar_mobile/core/widgets/meal_status_badge.dart';
import 'package:iftar_mobile/features/auth/presentation/login_page.dart';
import 'package:iftar_mobile/features/people/presentation/people_list_page.dart';
import 'package:iftar_mobile/features/scan/presentation/scan_controller.dart';
import 'package:iftar_mobile/features/scan/presentation/scan_result_panel.dart';

import '../support/app_harness.dart';
import '../support/fakes.dart';

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
    Future<void> pumpPanel(WidgetTester tester, ScanStatus status) =>
        tester.pumpWidget(
          localizedApp(
            Scaffold(
              body: Align(
                alignment: Alignment.bottomCenter,
                child: ScanResultPanel(status: status, onManualEntry: () {}),
              ),
            ),
          ),
        );

    testWidgets(
      'eligible person shows meals, green badge and one-tap confirm',
      (tester) async {
        await pumpPanel(tester, ScanReady(person(101)));
        expect(find.text('Can collect today'), findsOneWidget);
        expect(find.text('Najwa Chalbi'), findsOneWidget);
        expect(find.text(MealStatusBadge.notTakenLabel), findsOneWidget);
        expect(find.text('Confirm & scan next'), findsOneWidget);
      },
    );

    testWidgets('already collected shows a stop state without confirm', (
      tester,
    ) async {
      final p = person(102, takenToday: true);
      await pumpPanel(
        tester,
        ScanAlreadyTaken(p, DateTime(2025, 3, 5, 18, 10)),
      );
      expect(find.text('Already collected today at 18:10'), findsOneWidget);
      expect(find.text(MealStatusBadge.takenLabel), findsOneWidget);
      expect(find.text('Confirm & scan next'), findsNothing);
      expect(find.text('Scan next'), findsOneWidget);
    });

    testWidgets('invalid and unknown codes are distinguished', (tester) async {
      await pumpPanel(tester, const ScanInvalidCode('hello'));
      expect(find.text('Invalid QR code'), findsOneWidget);

      await pumpPanel(tester, const ScanNotFound(77));
      await tester.pumpAndSettle();
      expect(find.text('Person #77 not found'), findsOneWidget);
      expect(find.text('Register'), findsOneWidget);
    });

    testWidgets('failed confirmation warns not to serve twice', (tester) async {
      await pumpPanel(
        tester,
        ScanFailed(const NetworkFailure(), personId: 101, person: person(101)),
      );
      expect(find.text('No connection'), findsOneWidget);
      expect(find.textContaining('do not serve twice'), findsOneWidget);
      expect(find.text('Retry'), findsOneWidget);
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

    expect(find.text('List of fasting people'), findsOneWidget);
    expect(find.text('2 registered · 1 served today'), findsOneWidget);
    expect(find.text('Najwa Chalbi'), findsOneWidget);
    expect(find.text('Aziza Ouerghi'), findsOneWidget);

    await tester.enterText(find.byType(TextField), 'aziza');
    await tester.pumpAndSettle();
    expect(find.text('Najwa Chalbi'), findsNothing);
    expect(find.text('Aziza Ouerghi'), findsOneWidget);

    await tester.enterText(find.byType(TextField), 'nobody');
    await tester.pumpAndSettle();
    expect(find.textContaining('No match'), findsOneWidget);
  });
}
