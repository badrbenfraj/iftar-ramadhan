import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:iftar_mobile/core/theme/app_theme.dart';
import 'package:iftar_mobile/features/auth/presentation/auth_controller.dart';
import 'package:iftar_mobile/features/people/domain/fasting_person.dart';
import 'package:iftar_mobile/features/people/presentation/person_form_page.dart';
import 'package:iftar_mobile/l10n/app_localizations.dart';

import '../support/app_harness.dart';
import '../support/fakes.dart';
import '../support/fonts.dart';

void main() {
  setUpAll(loadAppFonts);

  late FakePeopleRepository repo;
  late GoRouter router;

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

  Future<void> pumpRouter(WidgetTester tester, {required String start}) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    router = GoRouter(
      initialLocation: '/home',
      routes: [
        GoRoute(path: '/home', builder: (_, _) => const Scaffold(body: Text('home-marker'))),
        GoRoute(path: '/people', builder: (_, _) => const Scaffold(body: Text('people-marker'))),
        GoRoute(
          path: '/add',
          builder: (_, _) => AddPersonPage(scanCardId: (_) async => 215),
        ),
        GoRoute(
          path: '/people/:id/edit',
          builder: (_, state) => EditPersonPage(personId: int.parse(state.pathParameters['id']!)),
        ),
      ],
    );
    addTearDown(router.dispose);
    await tester.pumpWidget(ProviderScope(
      overrides: testOverrides(repo),
      retry: (_, _) => null,
      child: MaterialApp.router(
        theme: AppTheme.light(),
        locale: const Locale('en'),
        supportedLocales: AppLocalizations.supportedLocales,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        routerConfig: router,
      ),
    ));
    await tester.pumpAndSettle();
    // The app's auth gate has resolved the session before any page opens.
    await ProviderScope.containerOf(tester.element(find.text('home-marker')))
        .read(authControllerProvider.future);
    unawaited(router.push<void>(start));
    await tester.pumpAndSettle();
  }

  Finder input(String label) => find.descendant(
    of: find.ancestor(of: find.text(label), matching: find.byType(Column)).first,
    matching: find.byType(TextFormField),
  );

  testWidgets('editing saves once, pops back and confirms', (tester) async {
    await pumpRouter(tester, start: '/people/142/edit');
    expect(find.widgetWithText(TextFormField, 'Fatma'), findsOneWidget);
    // The person's own CIN is not a duplicate.
    expect(find.text(en.openExistingRecord), findsNothing);

    await tester.enterText(input(en.firstName), 'Fatima');
    await tester.ensureVisible(find.text(en.updatePerson));
    await tester.pumpAndSettle();
    await tester.tap(find.text(en.updatePerson));
    await tester.pumpAndSettle();

    expect(repo.updateCalls, 1);
    expect(repo.people[142]?.firstName, 'Fatima');
    expect(repo.people[142]?.cin, '08123812');
    expect(find.text('home-marker'), findsOneWidget);
    expect(find.text(en.personUpdated), findsOneWidget);
  });

  testWidgets('a plain add-save goes to the people list', (tester) async {
    await pumpRouter(tester, start: '/add');
    await tester.tap(find.text(en.scanCard));
    await tester.pumpAndSettle();
    await tester.enterText(input(en.firstName), 'Nour');
    await tester.enterText(input(en.lastName), 'Saidi');
    await tester.ensureVisible(find.text(en.saveAndHandOver));
    await tester.pumpAndSettle();
    await tester.tap(find.text(en.saveAndHandOver));
    await tester.pumpAndSettle();

    expect(repo.createCalls, 1);
    expect(find.text('people-marker'), findsOneWidget);
  });
}
