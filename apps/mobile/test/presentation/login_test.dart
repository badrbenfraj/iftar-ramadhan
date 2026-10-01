import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:iftar_mobile/core/network/app_failure.dart';
import 'package:iftar_mobile/core/widgets/night_sky.dart';
import 'package:iftar_mobile/features/auth/data/auth_repository.dart';
import 'package:iftar_mobile/features/auth/domain/user.dart';
import 'package:iftar_mobile/features/auth/presentation/auth_scaffold.dart';
import 'package:iftar_mobile/features/auth/presentation/login_page.dart';
import 'package:iftar_mobile/features/auth/presentation/register_page.dart';
import 'package:iftar_mobile/l10n/app_localizations.dart';

import '../support/app_harness.dart';
import '../support/fonts.dart';

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

final _overrides = [
  authRepositoryProvider.overrideWithValue(_RejectingAuthRepository()),
  regionsProvider.overrideWith(
    (ref) async => const [
      Region(id: 1, name: 'Tunis'),
      Region(id: 2, name: 'Sfax'),
    ],
  ),
];

/// Pumps [page] on a 360x760 phone at text [scale], with the logo decoded
/// so it takes its real height.
Future<void> _pumpPhone(
  WidgetTester tester,
  Widget page,
  String code, {
  double scale = 1.3,
}) async {
  tester.view.physicalSize = const Size(360, 760);
  tester.view.devicePixelRatio = 1;
  tester.platformDispatcher.textScaleFactorTestValue = scale;
  addTearDown(tester.view.reset);
  addTearDown(tester.platformDispatcher.clearAllTestValues);
  await tester.runAsync(() async {
    final done = Completer<void>();
    const AssetImage('assets/images/ramadan.png')
        .resolve(ImageConfiguration(devicePixelRatio: 1, bundle: rootBundle))
        .addListener(ImageStreamListener((_, _) => done.complete()));
    await done.future;
  });
  await tester.pumpWidget(
    localizedApp(page, locale: Locale(code), overrides: _overrides),
  );
  await tester.pumpAndSettle();
}

/// Effective letter-spacing of the rendered [text].
double _tracking(WidgetTester tester, String text) {
  final paragraph = tester.renderObject<RenderParagraph>(find.text(text));
  return paragraph.text.style?.letterSpacing ?? 0;
}

/// Index, among [stack]'s children, of the child that contains [target].
int _stackChildIndex(WidgetTester tester, Finder stack, Finder target) {
  final stackElement = tester.element(stack);
  Element child = tester.element(target);
  tester.element(target).visitAncestorElements((ancestor) {
    if (identical(ancestor, stackElement)) return false;
    child = ancestor;
    return true;
  });
  return (stackElement.widget as Stack).children.indexOf(child.widget);
}

Future<void> _failSignIn(WidgetTester tester) async {
  await tester.pumpWidget(localizedApp(const LoginPage(), overrides: _overrides));
  await tester.pumpAndSettle();
  await tester.enterText(find.byType(TextFormField).at(0), 'sami');
  await tester.enterText(find.byType(TextFormField).at(1), 'secret');
  await tester.tap(find.text(en.signIn));
  await tester.pumpAndSettle();
}

void main() {
  setUpAll(loadAppFonts);

  testWidgets('wrong credentials show a localized message', (tester) async {
    await _failSignIn(tester);
    expect(find.text(en.errLoginFailed), findsOneWidget);
  });

  testWidgets('the sign-in error is announced as a live region', (
    tester,
  ) async {
    final semantics = tester.ensureSemantics();
    await _failSignIn(tester);
    final node = tester.getSemantics(find.text(en.errLoginFailed));
    expect(node.label, contains(en.errLoginFailed));
    expect(node.flagsCollection.isLiveRegion, isTrue);
    semantics.dispose();
  });

  testWidgets('fields keep their accessible name after typing', (
    tester,
  ) async {
    final semantics = tester.ensureSemantics();
    await tester.pumpWidget(
      localizedApp(const LoginPage(), overrides: _overrides),
    );
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextFormField).at(0), 'sami');
    await tester.pumpAndSettle();
    final node = tester.getSemantics(find.byType(TextField).at(0));
    expect(node.label, contains(en.username));
    semantics.dispose();
  });

  testWidgets('the paper sheet rises 28 px over the sky and paints above it', (
    tester,
  ) async {
    await _pumpPhone(tester, const LoginPage(), 'en', scale: 1);
    final sky = find.byType(NightSky);
    final sheet = find.byKey(AuthScaffold.sheetKey);
    final skyRect = tester.getRect(sky);
    final sheetRect = tester.getRect(sheet);
    expect(sheetRect.top, moreOrLessEquals(skyRect.bottom - 28));

    // One Stack holds both, the sheet after the sky, so it paints on top.
    final skyStacks = find.ancestor(of: sky, matching: find.byType(Stack));
    expect(skyStacks, findsWidgets);
    final stack = skyStacks.first;
    expect(find.ancestor(of: sheet, matching: stack), findsOneWidget);
    expect(
      _stackChildIndex(tester, stack, sheet),
      greaterThan(_stackChildIndex(tester, stack, sky)),
    );
  });

  testWidgets('Arabic labels, title and lead are not letter-spaced', (
    tester,
  ) async {
    await _pumpPhone(tester, const LoginPage(), 'ar');
    for (final text in [
      ar.username,
      ar.password,
      ar.welcomeBack,
      ar.loginLead,
    ]) {
      expect(_tracking(tester, text), 0, reason: text);
    }
  });

  testWidgets('login renders in Arabic without overflow', (tester) async {
    await _pumpPhone(tester, const LoginPage(), 'ar');
    expect(find.text(ar.welcomeBack), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  for (final code in ['ar', 'fr']) {
    testWidgets('register renders in $code without overflow', (tester) async {
      await _pumpPhone(tester, const RegisterPage(), code);
      final l = lookupAppLocalizations(Locale(code));
      expect(find.text(l.registerTitle), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  }
}
