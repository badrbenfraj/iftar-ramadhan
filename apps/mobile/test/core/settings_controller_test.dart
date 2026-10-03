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
