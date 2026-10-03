import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:iftar_mobile/core/network/app_failure.dart';
import 'package:iftar_mobile/core/settings/settings_controller.dart';
import 'package:iftar_mobile/core/settings/settings_storage.dart';

import '../support/storage.dart';

/// Reads wait for [gate], like a slow keychain at startup.
class _SlowReadStorage extends MemorySettingsStorage {
  final gate = Completer<void>();

  @override
  Future<String?> read(String key) async {
    await gate.future;
    return super.read(key);
  }
}

void main() {
  test('a choice made before the load finishes is not overwritten by it', () async {
    final storage = _SlowReadStorage()..values[SettingsController.localeKey] = 'ar';
    final c = ProviderContainer.test(
      overrides: [settingsStorageProvider.overrideWithValue(storage)],
    );
    final pending = c.read(settingsControllerProvider.notifier).setLocale(const Locale('fr'));
    storage.gate.complete();
    await pending;

    expect(c.read(settingsControllerProvider).value!.locale, const Locale('fr'));
    expect(storage.values[SettingsController.localeKey], 'fr');
  });

  test('a theme chosen before the load finishes is kept too', () async {
    final storage = _SlowReadStorage();
    final c = ProviderContainer.test(
      overrides: [settingsStorageProvider.overrideWithValue(storage)],
    );
    final pending = c.read(settingsControllerProvider.notifier).setThemeMode(ThemeMode.dark);
    storage.gate.complete();
    await pending;

    expect(c.read(settingsControllerProvider).value!.themeMode, ThemeMode.dark);
    expect(storage.values[SettingsController.themeModeKey], 'dark');
  });

  test('two choices made before the load finishes both stick', () async {
    final storage = _SlowReadStorage();
    final c = ProviderContainer.test(
      overrides: [settingsStorageProvider.overrideWithValue(storage)],
    );
    final notifier = c.read(settingsControllerProvider.notifier);
    final first = notifier.setLocale(const Locale('fr'));
    final second = notifier.setThemeMode(ThemeMode.dark);
    storage.gate.complete();
    await Future.wait([first, second]);

    final settings = c.read(settingsControllerProvider).value!;
    expect(settings.locale, const Locale('fr'));
    expect(settings.themeMode, ThemeMode.dark);
  });

  test('a failing write keeps the choice, throws nothing, and reports the failure', () async {
    final c = ProviderContainer.test(
      overrides: [settingsStorageProvider.overrideWithValue(ThrowingWriteStorage())],
    );
    await c.read(settingsControllerProvider.future);
    final notifier = c.read(settingsControllerProvider.notifier);

    final localeFailure = await notifier.setLocale(const Locale('fr'));
    final themeFailure = await notifier.setThemeMode(ThemeMode.dark);

    expect(localeFailure, isA<UnknownFailure>());
    expect(themeFailure, isA<UnknownFailure>());
    final settings = c.read(settingsControllerProvider).value!;
    expect(settings.locale, const Locale('fr'));
    expect(settings.themeMode, ThemeMode.dark);
  });

  test('a successful write reports no failure', () async {
    final c = ProviderContainer.test(
      overrides: [settingsStorageProvider.overrideWithValue(MemorySettingsStorage())],
    );
    expect(await c.read(settingsControllerProvider.notifier).setLocale(const Locale('en')), isNull);
  });
}
