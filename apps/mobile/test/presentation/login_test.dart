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
